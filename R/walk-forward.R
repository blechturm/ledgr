#' Run walk-forward evaluation
#'
#' `ledgr_walk_forward()` orchestrates fold-local train sweeps, deterministic
#' scalar candidate selection, and selected-candidate test runs over the
#' existing `ledgr_sweep()` and `ledgr_run()` execution machinery.
#' The returned object carries a `degradation` table that compares the selected
#' train score to the selected test score before secondary result surfaces.
#'
#' @param exp A `ledgr_experiment`.
#' @param grid A `ledgr_param_grid`.
#' @param folds A `ledgr_fold_list`.
#' @param selection_rule A rule created by [ledgr_rule_argmax()] or
#'   [ledgr_rule_argmin()].
#' @param seed Optional master seed for deterministic per-row execution seeds.
#' @param opening_state_policy Either `"carry_test_state"` or
#'   `"flat_test_state"`. The default carries selected test-run terminal state
#'   into the next test run and requires contiguous test windows (see
#'   Details). Flat-test state is an explicit cold-start opt-in.
#' @param no_selection What a fold does when no training candidate has a
#'   finite, `DONE` selection metric. `"previous"` (the default) runs the test
#'   window with the parameters most recently selected from a training window,
#'   or, before any training window has selected, runs no test window and
#'   leaves the carried opening unchanged. `"fail"` stops the session with
#'   `ledgr_walk_forward_no_selection`. Each fold records its `selection_source`
#'   (`"train"`, `"previous"` or `"none"`), and the policy is part of the
#'   session identity.
#' @param ... Reserved for later walk-forward options.
#' @return A `ledgr_walk_forward_results` list with `folds`, `scores`,
#'   `selected`, `degradation`, and selected test-run handles.
#' @details
#' v1 walk-forward scores scalar train-window candidates, selects one candidate
#' per fold, and runs only that selected candidate on the matching test window.
#' It is not PBO, CSCV, CPCV, DSR, benchmark-relative diagnostics, OMS,
#' paper/live trading, or a selection-integrity correction. Walk-forward
#' evidence is only as survivorship-safe as the sealed snapshot and universe
#' semantics it evaluates.
#'
#' With the default `opening_state_policy = "carry_test_state"`, test windows
#' are path-dependent: each completed selected test run can seed the next test
#' opening state. Per-fold test metrics are therefore not independent. Carrying
#' needs test windows in time order that touch exactly: when a trading day lies
#' between two consecutive test windows, positions would cross it unvalued, and
#' when a test window starts before the previous one ends (overlap or reverse
#' order), it would open from that window's later state. The call refuses both
#' before running anything, with `ledgr_walk_forward_gapped_carry` or
#' `ledgr_walk_forward_overlapping_carry`. Use folds whose `step` equals
#' `test_window`, or `"flat_test_state"`, which accepts any layout.
#'
#' Rerunning a session with the same arguments reuses its finished test runs
#' as recorded and resumes a test run that an interruption left unfinished.
#' Fold boundaries on the snapshot's first or last date resolve to its first
#' or last session; a date outside the snapshot refuses. Anchored
#' fold definitions intentionally grow the train window over time, so compute
#' cost grows with later folds and larger candidate grids. `metric_diff_abs` is
#' `test_metric_value - train_metric_value`; whether a positive value indicates
#' improvement or degradation depends on the selection rule direction.
#'
#' Every training and test window starts feature state at its own start:
#' indicators warm up again inside each window and no window reads bars before
#' it. A training window shorter than a candidate's indicator warmup therefore
#' cannot trade. When no candidate trades in a training window, volatility-based
#' metrics such as `sharpe_ratio` have no finite value and the fold has no
#' selection; `no_selection` decides what happens then. Size training windows
#' well beyond the longest warmup, or select on a metric that is defined
#' without trades, to keep selections coming from training. This is
#' separate from `cold_start_distorted`, which concerns opening positions, not
#' features. Hydrating features from earlier history is planned with ledgr's
#' point-in-time history design.
#' @export
ledgr_walk_forward <- function(exp,
                               grid,
                               folds,
                               selection_rule,
                               seed = NULL,
                               opening_state_policy = c("carry_test_state", "flat_test_state"),
                               no_selection = c("previous", "fail"),
                               ...) {
  no_selection <- match.arg(no_selection)
  dots <- list(...)
  if (length(dots) > 0L) {
    rlang::abort("`...` is reserved for future walk-forward options.", class = "ledgr_invalid_args")
  }
  if (!inherits(exp, "ledgr_experiment")) {
    rlang::abort("`exp` must be a ledgr_experiment object.", class = "ledgr_invalid_args")
  }
  if (!inherits(grid, "ledgr_param_grid")) {
    rlang::abort("`grid` must be a ledgr_param_grid object.", class = "ledgr_invalid_args")
  }
  release <- ledgr_snapshot_hold(exp$snapshot)
  on.exit(release(), add = TRUE)
  folds <- ledgr_validate_fold_list(folds)
  selection_rule <- ledgr_validate_selection_rule(selection_rule)
  seed <- ledgr_seed_normalize(seed)
  opening_state_policy <- match.arg(opening_state_policy)
  opening_state_policy <- ledgr_walk_forward_opening_state_policy(opening_state_policy)
  ledgr_snapshot_ensure_handle(exp$snapshot)
  if (identical(opening_state_policy, "carry_test_state")) {
    ledgr_walk_forward_refuse_noncontiguous_carry(exp, folds)
  }
  if (identical(opening_state_policy, "flat_test_state")) {
    rlang::warn(
      paste(
        "`opening_state_policy = \"flat_test_state\"` starts every test run",
        "from the experiment opening state. This can distort chained",
        "walk-forward evaluation when positions or cash would carry between",
        "test windows."
      ),
      class = "ledgr_walk_forward_cold_start_warning"
    )
  }

  session_identity <- ledgr_walk_forward_session_identity(exp, grid, folds, selection_rule, seed, opening_state_policy, no_selection)
  session_id <- session_identity$session_id
  fold_rows <- list()
  score_rows <- list()
  fold_results <- list()
  selected_tests <- list()
  carried_opening <- exp$opening
  terminal_status <- "DONE"
  terminal_error <- NULL
  completed_folds <- 0L
  interrupt_after_completed_folds <- getOption("ledgr.walk_forward_interrupt_after_completed_folds", NULL)
  # Parameters most recently selected from a training window, for no_selection = "previous".
  previous_params_hash <- NULL

  for (fold_idx in seq_along(folds)) {
    result <- tryCatch(
      ledgr_walk_forward_eval_fold(
        exp = exp,
        grid = grid,
        fold = folds[[fold_idx]],
        selection_rule = selection_rule,
        seed = seed,
        opening_state_policy = opening_state_policy,
        session_id = session_id,
        carried_opening = carried_opening,
        no_selection = no_selection,
        previous_params_hash = previous_params_hash
      ),
      interrupt = function(e) {
        terminal_status <<- if (completed_folds > 0L) "PARTIAL" else "INTERRUPTED"
        terminal_error <<- e
        NULL
      }
    )
    if (is.null(result)) {
      break
    }
    fold_rows[[length(fold_rows) + 1L]] <- result$fold_row
    if (!is.null(result$score_rows) && nrow(result$score_rows) > 0L) {
      score_rows[[length(score_rows) + 1L]] <- result$score_rows
    }
    if (!is.null(result$selected)) {
      fold_results[[length(fold_results) + 1L]] <- result$selected
    }
    if (!is.null(result$test_run)) {
      selected_tests[[length(selected_tests) + 1L]] <- result$test_run
    }
    if (identical(result$selection_source, "train")) {
      previous_params_hash <- result$params_hash
    }
    if (identical(result$status, "DONE")) {
      completed_folds <- completed_folds + 1L
      carried_opening <- result$carried_opening
      if (is.numeric(interrupt_after_completed_folds) &&
          length(interrupt_after_completed_folds) == 1L &&
          !is.na(interrupt_after_completed_folds) &&
          completed_folds >= as.integer(interrupt_after_completed_folds)) {
        terminal_status <- "PARTIAL"
        terminal_error <- structure(
          list(message = "simulated walk-forward interrupt", call = NULL),
          class = c("interrupt", "condition")
        )
        break
      }
    } else if (identical(result$status, "PARTIAL")) {
      terminal_status <- "PARTIAL"
      terminal_error <- NULL
      break
    } else {
      terminal_status <- "FAILED"
      terminal_error <- result$error
      break
    }
  }

  fold_table <- ledgr_walk_forward_bind_rows(fold_rows)
  score_table <- ledgr_walk_forward_bind_rows(score_rows)
  if (nrow(score_table) > 0L) {
    score_table <- score_table[order(
      score_table$fold_seq,
      score_table$window,
      score_table$candidate_key,
      score_table$metric_name,
      method = "radix"
    ), , drop = FALSE]
    rownames(score_table) <- NULL
  }
  session_row <- ledgr_walk_forward_session_row(
    identity = session_identity,
    master_seed = seed,
    opening_state_policy = opening_state_policy,
    cold_start_distorted = identical(opening_state_policy, "flat_test_state"),
    selection_metric = selection_rule$metric,
    status = terminal_status,
    no_selection = no_selection
  )
  ledgr_walk_forward_write_session(exp, session_row, fold_table, score_table)

  if (!is.null(terminal_error)) {
    invisible(lapply(selected_tests, function(test_run) {
      try(close(test_run), silent = TRUE)
    }))
    stop(terminal_error)
  }

  out <- structure(
    list(
      session_id = session_id,
      status = terminal_status,
      opening_state_policy = opening_state_policy,
      no_selection = no_selection,
      cold_start_distorted = identical(opening_state_policy, "flat_test_state"),
      folds = fold_table,
      scores = ledgr_add_completion_columns(score_table),
      degradation = ledgr_walk_forward_degradation_table(
        folds = fold_table,
        scores = score_table,
        selection_metric = selection_rule$metric,
        cold_start_distorted = identical(opening_state_policy, "flat_test_state")
      ),
      selected = ledgr_walk_forward_bind_rows(fold_results),
      test_runs = selected_tests
    ),
    class = c("ledgr_walk_forward_results", "list")
  )
  ledgr_walk_forward_attach_locator(out, exp$snapshot, session_identity$snapshot_hash)
}

#' @export
print.ledgr_walk_forward_results <- function(x, ...) {
  cat("ledgr walk-forward\n")
  cat("==================\n")
  folds <- x$folds %||% tibble::tibble()
  if (nrow(folds) > 0L && "selection_source" %in% names(folds)) {
    source <- as.character(folds$selection_source)
    counts <- c(train = sum(source %in% "train"), previous = sum(source %in% "previous"), none = sum(source %in% "none"))
    cat(sprintf("Fold selections: %d from training, %d reused from an earlier fold, %d without a candidate.\n",
                counts[["train"]], counts[["previous"]], counts[["none"]]))
    if (counts[["none"]] > 0L) {
      cat(sprintf("Health warning: %d fold(s) had no candidate before any training selection and ran no test window.\n", counts[["none"]]))
    }
    if (counts[["none"]] == nrow(folds)) {
      cat("Health warning: no fold selected a candidate; this session has no test evidence.\n")
    }
  }
  degradation <- x$degradation %||% tibble::tibble()
  if (nrow(degradation) > 0L) {
    if (any(ledgr_walk_forward_has_flag(degradation$warning_flags, "short_test_window"), na.rm = TRUE)) {
      cat("Health warning: one or more test windows are shorter than 90 calendar days.\n")
    }
    if (any(ledgr_walk_forward_has_flag(degradation$warning_flags, "cold_start_distorted"), na.rm = TRUE)) {
      cat("Health warning: flat test starts distort chained walk-forward evidence.\n")
    }
    cat("\nTrain/test degradation:\n")
    core <- ledgr_walk_forward_degradation_core_columns()
    print(tibble::as_tibble(degradation)[, intersect(core, names(degradation)), drop = FALSE], ...)
    cat("\n")
  }
  cat("Session: ", x$session_id %||% "<unknown>", "\n", sep = "")
  cat("Status: ", x$status %||% "<unknown>", "\n", sep = "")
  cat("Opening state: ", x$opening_state_policy %||% "<unknown>", "\n", sep = "")
  if (isTRUE(x$cold_start_distorted)) {
    cat("Cold-start distorted: TRUE\n")
  }
  cat("Folds: ", nrow(x$folds %||% data.frame()), "\n", sep = "")
  lines <- ledgr_walk_forward_selection_lines(x$scores)
  if (length(lines) > 0L) cat(lines, sep = "\n")
  invisible(x)
}

# One count line per window over distinct fold-candidate evaluations. The
# long score table repeats each evaluation once per metric.
ledgr_walk_forward_selection_lines <- function(scores) {
  if (is.null(scores) || nrow(scores) == 0L) return(character())
  scores <- ledgr_add_completion_columns(scores)
  key <- c("fold_seq", "window", "candidate_key")
  if (!all(key %in% names(scores))) return(character())
  rows <- scores[!duplicated(as.data.frame(scores)[key]), , drop = FALSE]
  out <- character()
  for (window in intersect(c("train", "test"), unique(as.character(rows$window)))) {
    at <- as.character(rows$window) == window
    noun <- if (identical(window, "train")) "train evaluations" else "test runs"
    out <- c(out, ledgr_selection_table_lines(rows[at, , drop = FALSE], noun = noun))
  }
  out
}

ledgr_walk_forward_session_identity <- function(exp,
                                                grid,
                                                folds,
                                                selection_rule,
                                                seed,
                                                opening_state_policy,
                                                no_selection = "fail") {
  meta <- ledgr_precompute_snapshot_meta(exp$snapshot)
  metric_context <- ledgr_metric_context_resolve(exp$metric_context)
  metric_context_hash <- ledgr_metric_context_hash(metric_context)
  cost_model_hash <- exp$cost_model_hash %||% ledgr_cost_model_hash(exp$cost_model)
  risk_chain <- exp$risk_chain %||% ledgr_risk_none()
  risk_chain_hash <- exp$risk_chain_hash %||% ledgr_risk_chain_hash(risk_chain)
  # The experiment hash binds sealed content and causal history under rule 4.
  experiment_hash <- ledgr_walk_forward_experiment_hash(ledgr_walk_forward_base_config(exp, meta))
  param_grid_hash <- ledgr_walk_forward_param_grid_hash(grid)
  fold_list_hash <- ledgr_fold_list_hash(folds)
  selection_rule_hash <- selection_rule$selection_rule_hash
  session_id <- ledgr_walk_forward_session_id(
    snapshot_hash = meta$snapshot_hash,
    experiment_hash = experiment_hash,
    param_grid_hash = param_grid_hash,
    fold_list_hash = fold_list_hash,
    selection_rule_hash = selection_rule_hash,
    metric_context_hash = metric_context_hash,
    cost_model_hash = cost_model_hash,
    risk_chain_hash = risk_chain_hash,
    master_seed = seed,
    opening_state_policy = opening_state_policy,
    no_selection = no_selection
  )
  list(
    session_id = session_id,
    snapshot_hash = meta$snapshot_hash,
    experiment_hash = experiment_hash,
    param_grid_hash = param_grid_hash,
    fold_list_hash = fold_list_hash,
    selection_rule_hash = selection_rule_hash,
    metric_context_hash = metric_context_hash,
    cost_model_hash = cost_model_hash,
    risk_chain_hash = risk_chain_hash
  )
}

ledgr_walk_forward_base_config <- function(exp, meta) {
  ledgr_config(
    snapshot = exp$snapshot,
    universe = exp$universe,
    strategy = exp$strategy,
    strategy_params = list(),
    feature_params = list(),
    backtest = ledgr_backtest_config(
      start = meta$start,
      end = meta$end,
      initial_cash = exp$opening$cash
    ),
    snapshot_hash = meta$snapshot_hash,
    features = list(),
    execution_mode = exp$execution_mode,
    timing_model = exp$timing_model,
    cost_model_hash = exp$cost_model_hash,
    cost_plan_json = exp$cost_plan_json,
    risk_chain_hash = exp$risk_chain_hash,
    risk_plan_json = exp$risk_plan_json,
    db_path = exp$snapshot$db_path,
    run_id = NULL,
    opening = exp$opening,
    seed = NULL,
    compiled_accounting_model = NULL,
    availability = exp$availability,
    universe_rule = exp$universe_rule,
    valuation_policy = exp$valuation_policy,
    corporate_action_policy = exp$corporate_action_policy,
    history_policy = exp$history_policy,
    price_basis = exp$data_identity$price_basis
  )
}

ledgr_walk_forward_candidate_identities <- function(param_grid,
                                                    resolved,
                                                    strategy_hash,
                                                    metric_context_hash,
                                                    cost_model_hash,
                                                    risk_chain_hash,
                                                    master_seed,
                                                    fold_seq,
                                                    window) {
  n <- length(param_grid$params)
  rows <- vector("list", n)
  for (i in seq_len(n)) {
    feature_row <- resolved$candidate_features[i, , drop = FALSE]
    alias_map_hash <- ledgr_walk_forward_alias_map_hash_value(feature_row$alias_map_hash[[1]])
    params <- ledgr_grid_candidate_strategy_params(param_grid$params[[i]])
    feature_params <- ledgr_grid_candidate_feature_params(param_grid$params[[i]])
    params_hash <- ledgr_strategy_params_info(params)$hash
    feature_params_hash <- ledgr_strategy_params_info(feature_params)$hash
    identity <- ledgr_walk_forward_candidate_identity(
      params_hash = params_hash,
      feature_params_hash = feature_params_hash,
      strategy_hash = strategy_hash,
      feature_set_hash = as.character(feature_row$feature_set_hash[[1]]),
      alias_map_hash = alias_map_hash,
      metric_context_hash = metric_context_hash,
      cost_model_hash = cost_model_hash,
      risk_chain_hash = risk_chain_hash,
      master_seed = master_seed,
      fold_seq = fold_seq,
      window = window
    )
    rows[[i]] <- data.frame(
      candidate_key = identity$candidate_key,
      unseeded_candidate_key = identity$unseeded_candidate_key,
      params_hash = params_hash,
      feature_params_hash = feature_params_hash,
      feature_set_hash = as.character(feature_row$feature_set_hash[[1]]),
      alias_map_hash = alias_map_hash,
      metric_context_hash = metric_context_hash,
      cost_model_hash = cost_model_hash,
      risk_chain_hash = risk_chain_hash,
      strategy_hash = strategy_hash,
      execution_seed = as.integer(identity$execution_seed),
      stringsAsFactors = FALSE
    )
  }
  tibble::as_tibble(do.call(rbind, rows))
}

ledgr_walk_forward_alias_map_hash_value <- function(x) {
  if (is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)) {
    return(x)
  }
  # v0.1.9.4 keeps no-alias normalization local so Batch 3 identity helpers
  # remain strict. Move this into R/walk-forward-identity.R when extraction
  # helpers also need to construct walk-forward candidate identity.
  digest::digest(as.character(canonical_json(list())), algo = "sha256")
}

ledgr_walk_forward_test_identity <- function(train_identity, master_seed, fold_seq) {
  identity <- ledgr_walk_forward_candidate_identity(
    params_hash = train_identity$params_hash[[1]],
    feature_params_hash = train_identity$feature_params_hash[[1]],
    strategy_hash = train_identity$strategy_hash[[1]],
    feature_set_hash = train_identity$feature_set_hash[[1]],
    alias_map_hash = train_identity$alias_map_hash[[1]],
    metric_context_hash = train_identity$metric_context_hash[[1]],
    cost_model_hash = train_identity$cost_model_hash[[1]],
    risk_chain_hash = train_identity$risk_chain_hash[[1]],
    master_seed = master_seed,
    fold_seq = fold_seq,
    window = "test"
  )
  out <- train_identity
  out$candidate_key <- identity$candidate_key
  out$unseeded_candidate_key <- identity$unseeded_candidate_key
  out$execution_seed <- as.integer(identity$execution_seed)
  out
}

ledgr_walk_forward_score_wide <- function(sweep, identities) {
  out <- tibble::as_tibble(sweep)
  out$candidate_key <- identities$candidate_key
  out
}

ledgr_walk_forward_eval_fold <- function(exp,
                                         grid,
                                         fold,
                                         selection_rule,
                                         seed,
                                         opening_state_policy,
                                         session_id,
                                         carried_opening,
                                         no_selection = "fail",
                                         previous_params_hash = NULL) {
  fold <- ledgr_validate_fold(fold)
  train_window <- ledgr_experiment_window_from_fold(
    exp,
    fold,
    window = "train",
    opening_state_policy = opening_state_policy
  )
  base_test_window <- ledgr_experiment_window_from_fold(
    exp,
    fold,
    window = "test",
    opening_state_policy = opening_state_policy
  )
  train_identities <- NULL
  train_sweep <- tryCatch(
    ledgr_sweep_window(
      exp,
      grid,
      window = train_window,
      seed = seed,
      execution_seed_resolver = function(param_grid,
                                         resolved,
                                         strategy_hash,
                                         metric_context_hash,
                                         cost_model_hash,
                                         risk_chain_hash) {
        train_identities <<- ledgr_walk_forward_candidate_identities(
          param_grid = param_grid,
          resolved = resolved,
          strategy_hash = strategy_hash,
          metric_context_hash = metric_context_hash,
          cost_model_hash = cost_model_hash,
          risk_chain_hash = risk_chain_hash,
          master_seed = seed,
          fold_seq = fold$fold_seq,
          window = "train"
        )
        train_identities$execution_seed
      }
    ),
    error = function(e) e
  )
  if (inherits(train_sweep, "condition")) {
    return(ledgr_walk_forward_failed_fold_result(
      session_id = session_id,
      fold = fold,
      train_window = train_window,
      test_window = base_test_window,
      opening_state_policy = opening_state_policy,
      error = train_sweep,
      score_rows = NULL
    ))
  }

  train_scores <- ledgr_walk_forward_score_wide(train_sweep, train_identities)
  train_score_rows <- ledgr_walk_forward_score_rows(
    session_id = session_id,
    fold = fold,
    window = "train",
    scores = train_sweep,
    identities = train_identities
  )
  selected <- tryCatch(
    ledgr_selection_rule_select(selection_rule, train_scores),
    error = function(e) e
  )
  selection_source <- "train"
  if (inherits(selected, "condition")) {
    fallback <- identical(no_selection, "previous") && inherits(selected, "ledgr_walk_forward_no_selection")
    previous_idx <- if (fallback && !is.null(previous_params_hash)) {
      which(train_identities$params_hash == previous_params_hash)
    } else {
      integer()
    }
    if (fallback && is.null(previous_params_hash)) {
      # Nothing has been selected or carried yet: run no test window.
      return(ledgr_walk_forward_none_fold_result(
        session_id = session_id,
        fold = fold,
        train_window = train_window,
        test_window = base_test_window,
        opening_state_policy = opening_state_policy,
        score_rows = train_score_rows,
        carried_opening = carried_opening
      ))
    }
    if (!fallback || length(previous_idx) < 1L) {
      return(ledgr_walk_forward_failed_fold_result(
        session_id = session_id,
        fold = fold,
        train_window = train_window,
        test_window = base_test_window,
        opening_state_policy = opening_state_policy,
        error = selected,
        score_rows = train_score_rows
      ))
    }
    # Reuse the parameters most recently selected from a training window. The
    # fold names this fold's train candidate for them; its metric is not a
    # selection score, so it is reported as NA.
    selected <- ledgr_walk_forward_previous_selection(
      train_scores,
      train_identities$candidate_key[[previous_idx[[1L]]]],
      selection_rule$metric
    )
    selection_source <- "previous"
  }

  selected_idx <- which(train_scores$candidate_key == selected$candidate_key[[1]])[[1]]
  selected_train_identity <- train_identities[selected_idx, , drop = FALSE]
  selected_row <- train_sweep[selected_idx, , drop = FALSE]
  test_exp <- if (identical(opening_state_policy, "carry_test_state")) {
    ledgr_walk_forward_experiment_with_opening(exp, carried_opening)
  } else {
    exp
  }
  test_window <- ledgr_experiment_window_from_fold(
    test_exp,
    fold,
    window = "test",
    opening_state_policy = opening_state_policy
  )
  test_identity <- ledgr_walk_forward_test_identity(
    train_identity = selected_train_identity,
    master_seed = seed,
    fold_seq = fold$fold_seq
  )
  test_run_id <- ledgr_walk_forward_test_run_id(session_id, fold$fold_seq, test_identity$candidate_key)
  test_run <- tryCatch(
    ledgr_walk_forward_run_or_open(
      test_exp,
      params = selected_row$params[[1]],
      feature_params = selected_row$feature_params[[1]],
      window = test_window,
      run_id = test_run_id,
      seed = test_identity$execution_seed
    ),
    error = function(e) e
  )
  if (inherits(test_run, "condition")) {
    return(ledgr_walk_forward_failed_fold_result(
      session_id = session_id,
      fold = fold,
      train_window = train_window,
      test_window = test_window,
      opening_state_policy = opening_state_policy,
      selected_candidate_key = selected_train_identity$candidate_key[[1]],
      selection_source = selection_source,
      test_run_id = test_run_id,
      error = test_run,
      score_rows = train_score_rows
    ))
  }

  selected_at <- ledgr_normalize_ts_utc(Sys.time())
  test_scores <- ledgr_walk_forward_test_score_wide(test_run)
  test_score_rows <- ledgr_walk_forward_score_rows(
    session_id = session_id,
    fold = fold,
    window = "test",
    scores = test_scores,
    identities = test_identity
  )
  if (identical(as.character(test_scores$status[[1]]), "INCOMPLETE")) {
    return(list(
      status = "PARTIAL",
      error = NULL,
      fold_row = ledgr_walk_forward_fold_row(
        session_id = session_id,
        fold = fold,
        train_window = train_window,
        test_window = test_window,
        opening_state_policy = opening_state_policy,
        selected_candidate_key = selected_train_identity$candidate_key[[1]],
      selection_source = selection_source,
        selected_at_utc = selected_at,
        test_run_id = test_run_id,
        status = "PARTIAL"
      ),
      score_rows = rbind(train_score_rows, test_score_rows),
      selected = tibble::as_tibble(cbind(
        fold_seq = fold$fold_seq,
        selected[, c("candidate_key", "candidate_id", selection_rule$metric), drop = FALSE],
        test_run_id = test_run_id,
        selection_source = selection_source
      )),
      test_run = test_run,
      carried_opening = NULL,
      selection_source = selection_source,
      params_hash = selected_train_identity$params_hash[[1]]
    ))
  }
  if (identical(as.character(test_scores$status[[1]]), "FAILED")) {
    err <- rlang::catch_cnd(
      rlang::abort(
        as.character(test_scores$error_msg[[1]]),
        class = as.character(test_scores$error_class[[1]])
      )
    )
    return(ledgr_walk_forward_failed_fold_result(
      session_id = session_id,
      fold = fold,
      train_window = train_window,
      test_window = test_window,
      opening_state_policy = opening_state_policy,
      selected_candidate_key = selected_train_identity$candidate_key[[1]],
      selection_source = selection_source,
      selected_at_utc = selected_at,
      test_run_id = test_run_id,
      error = err,
      score_rows = rbind(train_score_rows, test_score_rows)
    ))
  }

  next_opening <- carried_opening
  if (identical(opening_state_policy, "carry_test_state")) {
    next_opening <- ledgr_walk_forward_opening_from_run(test_exp, test_run$run_id)
  }
  list(
    status = "DONE",
    error = NULL,
    fold_row = ledgr_walk_forward_fold_row(
      session_id = session_id,
      fold = fold,
      train_window = train_window,
      test_window = test_window,
      opening_state_policy = opening_state_policy,
      selected_candidate_key = selected_train_identity$candidate_key[[1]],
      selection_source = selection_source,
      selected_at_utc = selected_at,
      test_run_id = test_run_id,
      status = "DONE"
    ),
    score_rows = rbind(train_score_rows, test_score_rows),
    selected = tibble::as_tibble(cbind(
      fold_seq = fold$fold_seq,
      selected[, c("candidate_key", "candidate_id", selection_rule$metric), drop = FALSE],
      test_run_id = test_run_id,
      selection_source = selection_source
    )),
    test_run = test_run,
    carried_opening = next_opening,
    selection_source = selection_source,
    params_hash = selected_train_identity$params_hash[[1]]
  )
}

# The selected row for a previous-sourced fold: this fold's train row for the
# reused parameters, with the selection metric blanked because it was not
# used to select (it may even be a finite value on an INCOMPLETE row).
ledgr_walk_forward_previous_selection <- function(train_scores, candidate_key, metric) {
  selected <- train_scores[train_scores$candidate_key == candidate_key, , drop = FALSE]
  selected[[metric]] <- NA_real_
  selected
}

ledgr_walk_forward_failed_fold_result <- function(session_id,
                                                  fold,
                                                  train_window,
                                                  test_window,
                                                  opening_state_policy,
                                                  error,
                                                  score_rows = NULL,
                                                  selected_candidate_key = NA_character_,
                                                  selected_at_utc = ledgr_walk_forward_na_time(),
                                                  test_run_id = NA_character_,
                                                  selection_source = NA_character_) {
  list(
    status = "FAILED",
    error = error,
    fold_row = ledgr_walk_forward_fold_row(
      session_id = session_id,
      fold = fold,
      train_window = train_window,
      test_window = test_window,
      opening_state_policy = opening_state_policy,
      selected_candidate_key = selected_candidate_key,
      selected_at_utc = selected_at_utc,
      test_run_id = test_run_id,
      status = "FAILED",
      selection_source = selection_source
    ),
    score_rows = score_rows,
    selected = NULL,
    test_run = NULL,
    carried_opening = NULL,
    selection_source = selection_source
  )
}

# A fold with no selection before any training window has selected runs no
# test window and carries the opening it received. It is DONE with source none.
ledgr_walk_forward_none_fold_result <- function(session_id,
                                                fold,
                                                train_window,
                                                test_window,
                                                opening_state_policy,
                                                score_rows,
                                                carried_opening) {
  list(
    status = "DONE",
    error = NULL,
    fold_row = ledgr_walk_forward_fold_row(
      session_id = session_id,
      fold = fold,
      train_window = train_window,
      test_window = test_window,
      opening_state_policy = opening_state_policy,
      selected_candidate_key = NA_character_,
      selected_at_utc = ledgr_walk_forward_na_time(),
      test_run_id = NA_character_,
      status = "DONE",
      selection_source = "none"
    ),
    score_rows = score_rows,
    selected = NULL,
    test_run = NULL,
    carried_opening = carried_opening,
    selection_source = "none"
  )
}

ledgr_walk_forward_na_time <- function() {
  as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC")
}

ledgr_walk_forward_test_score_wide <- function(test_run) {
  terminal <- ledgr_backtest_terminal_evidence(test_run)
  metric_result <- tryCatch(
    list(metrics = ledgr_compute_metrics(test_run), equity = ledgr_results(test_run, "equity")),
    error = function(e) e
  )
  if (inherits(metric_result, "condition")) {
    status <- if (identical(terminal$status, "INCOMPLETE")) "INCOMPLETE" else "FAILED"
    return(tibble::tibble(
      candidate_id = test_run$run_id,
      status = status,
      final_equity = NA_real_,
      total_return = NA_real_,
      annualized_return = NA_real_,
      volatility = NA_real_,
      sharpe_ratio = NA_real_,
      max_drawdown = NA_real_,
      n_trades = NA_integer_,
      win_rate = NA_real_,
      avg_trade = NA_real_,
      time_in_market = NA_real_,
      error_class = ledgr_condition_class(metric_result),
      error_msg = conditionMessage(metric_result),
      completion_json = terminal$completion_json
    ))
  }
  metrics <- metric_result$metrics
  equity <- metric_result$equity
  final_equity <- if (nrow(equity) > 0L) as.numeric(equity$equity[[nrow(equity)]]) else NA_real_
  if (!is.finite(final_equity)) {
    status <- if (identical(terminal$status, "INCOMPLETE")) "INCOMPLETE" else "FAILED"
    return(tibble::tibble(
      candidate_id = test_run$run_id,
      status = status,
      final_equity = final_equity,
      total_return = NA_real_,
      annualized_return = NA_real_,
      volatility = NA_real_,
      sharpe_ratio = NA_real_,
      max_drawdown = NA_real_,
      n_trades = NA_integer_,
      win_rate = NA_real_,
      avg_trade = NA_real_,
      time_in_market = NA_real_,
      error_class = "ledgr_walk_forward_test_run_failed",
      error_msg = "Selected test run produced no usable final equity row.",
      completion_json = terminal$completion_json
    ))
  }
  tibble::tibble(
    candidate_id = test_run$run_id,
    status = terminal$status,
    final_equity = final_equity,
    total_return = as.numeric(metrics$total_return %||% NA_real_),
    annualized_return = as.numeric(metrics$annualized_return %||% NA_real_),
    volatility = as.numeric(metrics$volatility %||% NA_real_),
    sharpe_ratio = as.numeric(metrics$sharpe_ratio %||% NA_real_),
    max_drawdown = as.numeric(metrics$max_drawdown %||% NA_real_),
    n_trades = as.integer(metrics$n_trades %||% NA_integer_),
    win_rate = as.numeric(metrics$win_rate %||% NA_real_),
    avg_trade = as.numeric(metrics$avg_trade %||% NA_real_),
    time_in_market = as.numeric(metrics$time_in_market %||% NA_real_),
    error_class = NA_character_,
    error_msg = NA_character_,
    completion_json = terminal$completion_json
  )
}

ledgr_walk_forward_score_rows <- function(session_id,
                                          fold,
                                          window,
                                          scores,
                                          identities) {
  metrics <- c(
    "final_equity", "total_return", "annualized_return", "volatility",
    "sharpe_ratio", "max_drawdown", "win_rate", "avg_trade", "time_in_market"
  )
  rows <- list()
  scores <- tibble::as_tibble(scores)
  if (nrow(scores) < 1L) {
    return(tibble::tibble())
  }
  for (i in seq_len(nrow(scores))) {
    identity <- identities[min(i, nrow(identities)), , drop = FALSE]
    for (metric in metrics) {
      rows[[length(rows) + 1L]] <- data.frame(
        session_id = session_id,
        fold_id = fold$fold_id,
        fold_seq = as.integer(fold$fold_seq),
        candidate_key = identity$candidate_key[[1]],
        candidate_label = as.character(scores$candidate_id[[i]] %||% NA_character_),
        params_hash = identity$params_hash[[1]],
        feature_params_hash = identity$feature_params_hash[[1]],
        feature_set_hash = identity$feature_set_hash[[1]],
        alias_map_hash = identity$alias_map_hash[[1]],
        metric_context_hash = identity$metric_context_hash[[1]],
        cost_model_hash = identity$cost_model_hash[[1]],
        risk_chain_hash = identity$risk_chain_hash[[1]],
        window = window,
        metric_name = metric,
        metric_value = as.numeric(ledgr_walk_forward_score_value(scores, metric, i, NA_real_)),
        n_trades = as.integer(ledgr_walk_forward_score_value(scores, "n_trades", i, NA_integer_)),
        status = as.character(ledgr_walk_forward_score_value(scores, "status", i, "DONE")),
        completion_json = as.character(
          ledgr_walk_forward_score_value(scores, "completion_json", i, NA_character_)
        ),
        error_class = as.character(ledgr_walk_forward_score_value(scores, "error_class", i, NA_character_)),
        error_msg = as.character(ledgr_walk_forward_score_value(scores, "error_msg", i, NA_character_)),
        execution_seed = as.integer(identity$execution_seed[[1]]),
        stringsAsFactors = FALSE
      )
    }
  }
  ledgr_walk_forward_bind_rows(rows)
}

ledgr_walk_forward_score_value <- function(scores, column, row, default) {
  if (!column %in% names(scores)) {
    return(default)
  }
  value <- scores[[column]][[row]]
  if (is.null(value) || length(value) == 0L) {
    return(default)
  }
  value
}

ledgr_walk_forward_fold_row <- function(session_id,
                                        fold,
                                        train_window,
                                        test_window,
                                        opening_state_policy,
                                        selected_candidate_key,
                                        selected_at_utc,
                                        test_run_id,
                                        status,
                                        selection_source = NA_character_) {
  data.frame(
    session_id = session_id,
    fold_id = fold$fold_id,
    fold_seq = as.integer(fold$fold_seq),
    scheme = fold$scheme,
    train_start_utc = fold$train_start_utc,
    train_end_utc = fold$train_end_utc,
    test_start_utc = fold$test_start_utc,
    test_end_utc = fold$test_end_utc,
    hydration_start_utc = train_window$hydration_start_utc,
    train_scoring_start_utc = train_window$scoring_start_utc,
    test_scoring_start_utc = test_window$scoring_start_utc,
    opening_state_policy = opening_state_policy,
    selected_candidate_key = selected_candidate_key,
    selected_at_utc = as.POSIXct(selected_at_utc, tz = "UTC"),
    test_run_id = test_run_id,
    status = status,
    selection_source = as.character(selection_source),
    stringsAsFactors = FALSE
  )
}

ledgr_walk_forward_session_row <- function(identity,
                                           master_seed,
                                           opening_state_policy,
                                           cold_start_distorted,
                                           selection_metric = NULL,
                                           status = "DONE",
                                           no_selection = "fail") {
  data.frame(
    session_id = identity$session_id,
    snapshot_hash = identity$snapshot_hash,
    experiment_hash = identity$experiment_hash,
    param_grid_hash = identity$param_grid_hash,
    fold_list_hash = identity$fold_list_hash,
    selection_rule_hash = identity$selection_rule_hash,
    metric_context_hash = identity$metric_context_hash,
    cost_model_hash = identity$cost_model_hash,
    risk_chain_hash = identity$risk_chain_hash,
    master_seed = as.integer(master_seed %||% NA_integer_),
    opening_state_policy = opening_state_policy,
    created_at_utc = as.POSIXct(
      ledgr_normalize_ts_utc(Sys.time()),
      tz = "UTC",
      format = "%Y-%m-%dT%H:%M:%SZ"
    ),
    ledgr_version = as.character(utils::packageVersion("ledgr")),
    meta_json = as.character(canonical_json(list(
      status = status,
      cold_start_distorted = isTRUE(cold_start_distorted),
      selection_metric = selection_metric %||% NULL,
      no_selection = no_selection,
      walk_forward_schema_version = ledgr_walk_forward_schema_version,
      identity_rule_version = ledgr_identity_rule_version
    ))),
    stringsAsFactors = FALSE
  )
}

ledgr_walk_forward_bind_rows <- function(rows) {
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) < 1L) {
    return(tibble::tibble())
  }
  tibble::as_tibble(do.call(rbind, rows))
}

ledgr_walk_forward_write_session <- function(exp, session_row, fold_rows, score_rows) {
  opened <- ledgr_run_store_open(exp$snapshot$db_path)
  on.exit(ledgr_run_store_close(opened), add = TRUE)
  session_id <- session_row$session_id[[1]]
  DBI::dbWithTransaction(opened$con, {
    DBI::dbExecute(opened$con, "DELETE FROM walk_forward_scores WHERE session_id = ?", params = list(session_id))
    DBI::dbExecute(opened$con, "DELETE FROM walk_forward_folds WHERE session_id = ?", params = list(session_id))
    DBI::dbExecute(opened$con, "DELETE FROM walk_forward_sessions WHERE session_id = ?", params = list(session_id))
    DBI::dbAppendTable(opened$con, "walk_forward_sessions", session_row)
    if (nrow(fold_rows) > 0L) {
      DBI::dbAppendTable(opened$con, "walk_forward_folds", as.data.frame(fold_rows))
    }
    if (nrow(score_rows) > 0L) {
      DBI::dbAppendTable(opened$con, "walk_forward_scores", as.data.frame(score_rows))
    }
  })
  invisible(TRUE)
}

ledgr_walk_forward_test_run_id <- function(session_id, fold_seq, candidate_key) {
  paste0("wf_", substr(session_id, 1L, 12L), "_fold_", as.integer(fold_seq), "_", substr(candidate_key, 1L, 12L))
}

ledgr_walk_forward_experiment_with_opening <- function(exp, opening) {
  out <- exp
  out$opening <- opening
  out
}

ledgr_walk_forward_run_or_open <- function(exp,
                                           params,
                                           feature_params,
                                           window,
                                           run_id,
                                           seed) {
  # A finished test run (DONE or INCOMPLETE) is reused as recorded. Any other
  # existing row, such as an interrupted run left FAILED, resumes through the
  # ordinary run path with the same window, parameters and seed; that path
  # refuses a run whose configuration no longer matches.
  if (ledgr_walk_forward_run_status(exp, run_id) %in% c("DONE", "INCOMPLETE")) {
    return(ledgr_run_open(exp$snapshot, run_id))
  }
  ledgr_run_window(
    exp,
    params = params,
    feature_params = feature_params,
    window = window,
    run_id = run_id,
    seed = seed
  )
}

ledgr_walk_forward_run_status <- function(exp, run_id) {
  opened <- ledgr_run_store_open(exp$snapshot$db_path)
  on.exit(ledgr_run_store_close(opened), add = TRUE)
  row <- DBI::dbGetQuery(
    opened$con,
    "SELECT status FROM runs WHERE run_id = ? LIMIT 1",
    params = list(run_id)
  )
  if (nrow(row) == 1L) as.character(row$status[[1L]]) else NA_character_
}

ledgr_walk_forward_opening_from_run <- function(exp, run_id) {
  opened <- ledgr_run_store_open(exp$snapshot$db_path)
  on.exit(ledgr_run_store_close(opened), add = TRUE)
  state <- NULL
  if (isTRUE(exp$availability$active)) {
    equity <- ledgr_backtest_equity(opened$con, run_id)
  } else {
    state <- ledgr_state_reconstruct(run_id, opened$con)
    equity <- state$equity_curve
  }
  if (nrow(equity) < 1L) {
    return(exp$opening)
  }
  final_cash <- as.numeric(equity$cash[[nrow(equity)]])
  final_ts <- as.POSIXct(equity$ts_utc[[nrow(equity)]], tz = "UTC")
  if (isTRUE(exp$availability$active)) {
    held <- ledgr_availability_positions_asof(opened$con, run_id, final_ts)
  } else {
    positions <- state$positions
    held <- positions$qty
    names(held) <- positions$instrument_id
  }
  held <- held[is.finite(held) & abs(held) > 1e-12]
  if (length(held) < 1L) {
    return(ledgr_opening(cash = final_cash))
  }
  if (any(held < 0)) {
    rlang::abort(
      "Carry-test-state opening cannot represent short terminal positions in v1.",
      class = "ledgr_walk_forward_invalid_opening_state"
    )
  }
  lot_state <- ledgr_lot_state_asof(opened$con, run_id, exp$universe, final_ts)
  total_basis <- lot_state$cost_basis_by_inst[names(held)]
  cost_basis <- as.numeric(total_basis) / as.numeric(held)
  names(cost_basis) <- names(held)
  ledgr_opening(cash = final_cash, positions = held, cost_basis = cost_basis)
}
