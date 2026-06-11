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
#' @param selection_rule A rule created by [ledgr_select_argmax()] or
#'   [ledgr_select_argmin()].
#' @param seed Optional master seed for deterministic per-row execution seeds.
#' @param opening_state_policy Either `"carry_test_state"` or
#'   `"flat_test_state"`. The default carries selected test-run terminal state
#'   into the next test run. Flat-test state is an explicit cold-start opt-in.
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
#' opening state. Per-fold test metrics are therefore not independent. Anchored
#' fold definitions intentionally grow the train window over time, so compute
#' cost grows with later folds and larger candidate grids. `metric_diff_abs` is
#' `test_metric_value - train_metric_value`; whether a positive value indicates
#' improvement or degradation depends on the selection rule direction.
#' @export
ledgr_walk_forward <- function(exp,
                               grid,
                               folds,
                               selection_rule,
                               seed = NULL,
                               opening_state_policy = c("carry_test_state", "flat_test_state"),
                               ...) {
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
  folds <- ledgr_validate_fold_list(folds)
  selection_rule <- ledgr_validate_selection_rule(selection_rule)
  seed <- ledgr_seed_normalize(seed)
  opening_state_policy <- match.arg(opening_state_policy)
  opening_state_policy <- ledgr_walk_forward_opening_state_policy(opening_state_policy)
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

  session_identity <- ledgr_walk_forward_session_identity(exp, grid, folds, selection_rule, seed, opening_state_policy)
  session_id <- session_identity$session_id
  fold_rows <- list()
  score_rows <- list()
  fold_results <- list()
  selected_tests <- list()
  carried_opening <- exp$opening
  terminal_status <- "DONE"
  terminal_error <- NULL
  completed_folds <- 0L

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
        carried_opening = carried_opening
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
    if (identical(result$status, "DONE")) {
      completed_folds <- completed_folds + 1L
      carried_opening <- result$carried_opening
    } else {
      terminal_status <- "FAILED"
      terminal_error <- result$error
      break
    }
  }

  fold_table <- ledgr_walk_forward_bind_rows(fold_rows)
  score_table <- ledgr_walk_forward_bind_rows(score_rows)
  session_row <- ledgr_walk_forward_session_row(
    identity = session_identity,
    master_seed = seed,
    opening_state_policy = opening_state_policy,
    cold_start_distorted = identical(opening_state_policy, "flat_test_state"),
    selection_metric = selection_rule$metric,
    status = terminal_status
  )
  ledgr_walk_forward_write_session(exp, session_row, fold_table, score_table)

  if (!is.null(terminal_error)) {
    stop(terminal_error)
  }

  out <- structure(
    list(
      session_id = session_id,
      status = terminal_status,
      opening_state_policy = opening_state_policy,
      cold_start_distorted = identical(opening_state_policy, "flat_test_state"),
      folds = fold_table,
      scores = score_table,
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
  out
}

#' @export
print.ledgr_walk_forward_results <- function(x, ...) {
  cat("ledgr walk-forward\n")
  cat("==================\n")
  degradation <- x$degradation %||% tibble::tibble()
  if (nrow(degradation) > 0L) {
    if (any(ledgr_walk_forward_has_flag(degradation$warning_flags, "short_test_window"), na.rm = TRUE)) {
      cat("Health warning: one or more test windows are shorter than 90 calendar days.\n")
    }
    if (any(ledgr_walk_forward_has_flag(degradation$warning_flags, "cold_start_distorted"), na.rm = TRUE)) {
      cat("Health warning: flat test starts distort chained walk-forward evidence.\n")
    }
    cat("\nTrain/test degradation:\n")
    print(degradation, ...)
    cat("\n")
  }
  cat("Session: ", x$session_id %||% "<unknown>", "\n", sep = "")
  cat("Status: ", x$status %||% "<unknown>", "\n", sep = "")
  cat("Opening state: ", x$opening_state_policy %||% "<unknown>", "\n", sep = "")
  if (isTRUE(x$cold_start_distorted)) {
    cat("Cold-start distorted: TRUE\n")
  }
  cat("Folds: ", nrow(x$folds %||% data.frame()), "\n", sep = "")
  invisible(x)
}

ledgr_walk_forward_session_identity <- function(exp,
                                                grid,
                                                folds,
                                                selection_rule,
                                                seed,
                                                opening_state_policy) {
  meta <- ledgr_precompute_snapshot_meta(exp$snapshot)
  metric_context <- ledgr_metric_context_resolve(exp$metric_context)
  metric_context_hash <- ledgr_metric_context_hash(metric_context)
  cost_model_hash <- exp$cost_model_hash %||% ledgr_cost_model_hash(exp$cost_model)
  risk_chain <- exp$risk_chain %||% ledgr_risk_none()
  risk_chain_hash <- exp$risk_chain_hash %||% ledgr_risk_chain_hash(risk_chain)
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
    opening_state_policy = opening_state_policy
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
    features = list(),
    persist_features = exp$persist_features,
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
    compiled_accounting_model = NULL
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
                                         carried_opening) {
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
  if (inherits(selected, "condition")) {
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
      selected_at_utc = selected_at,
      test_run_id = test_run_id,
      status = "DONE"
    ),
    score_rows = rbind(train_score_rows, test_score_rows),
    selected = tibble::as_tibble(cbind(
      fold_seq = fold$fold_seq,
      selected[, c("candidate_key", "candidate_id", selection_rule$metric), drop = FALSE],
      test_run_id = test_run_id
    )),
    test_run = test_run,
    carried_opening = next_opening
  )
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
                                                  test_run_id = NA_character_) {
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
      status = "FAILED"
    ),
    score_rows = score_rows,
    selected = NULL,
    test_run = NULL,
    carried_opening = NULL
  )
}

ledgr_walk_forward_na_time <- function() {
  as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC")
}

ledgr_walk_forward_test_score_wide <- function(test_run) {
  metric_result <- tryCatch(
    list(metrics = ledgr_compute_metrics(test_run), equity = ledgr_results(test_run, "equity")),
    error = function(e) e
  )
  if (inherits(metric_result, "condition")) {
    return(tibble::tibble(
      candidate_id = test_run$run_id,
      status = "FAILED",
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
      error_msg = conditionMessage(metric_result)
    ))
  }
  metrics <- metric_result$metrics
  equity <- metric_result$equity
  final_equity <- if (nrow(equity) > 0L) as.numeric(equity$equity[[nrow(equity)]]) else NA_real_
  if (!is.finite(final_equity)) {
    return(tibble::tibble(
      candidate_id = test_run$run_id,
      status = "FAILED",
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
      error_msg = "Selected test run produced no usable final equity row."
    ))
  }
  tibble::tibble(
    candidate_id = test_run$run_id,
    status = "DONE",
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
    error_msg = NA_character_
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
                                        status) {
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
    selected_at_utc = selected_at_utc,
    test_run_id = test_run_id,
    status = status,
    stringsAsFactors = FALSE
  )
}

ledgr_walk_forward_session_row <- function(identity,
                                           master_seed,
                                           opening_state_policy,
                                           cold_start_distorted,
                                           selection_metric = NULL,
                                           status = "DONE") {
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
    created_at_utc = as.POSIXct(ledgr_normalize_ts_utc(Sys.time()), tz = "UTC"),
    ledgr_version = as.character(utils::packageVersion("ledgr")),
    meta_json = as.character(canonical_json(list(
      status = status,
      cold_start_distorted = isTRUE(cold_start_distorted),
      selection_metric = selection_metric %||% NULL,
      walk_forward_schema_version = ledgr_walk_forward_schema_version
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
  ledgr_experiment_store_check_schema(opened$con, write = TRUE)
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
  if (ledgr_walk_forward_run_exists(exp, run_id)) {
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

ledgr_walk_forward_run_exists <- function(exp, run_id) {
  opened <- ledgr_run_store_open(exp$snapshot$db_path)
  on.exit(ledgr_run_store_close(opened), add = TRUE)
  if (!ledgr_experiment_store_table_exists(opened$con, "runs")) {
    return(FALSE)
  }
  row <- DBI::dbGetQuery(
    opened$con,
    "SELECT run_id FROM runs WHERE run_id = ? LIMIT 1",
    params = list(run_id)
  )
  nrow(row) == 1L
}

ledgr_walk_forward_opening_from_run <- function(exp, run_id) {
  opened <- ledgr_run_store_open(exp$snapshot$db_path)
  on.exit(ledgr_run_store_close(opened), add = TRUE)
  state <- ledgr_state_reconstruct(run_id, opened$con)
  equity <- state$equity_curve
  if (nrow(equity) < 1L) {
    return(exp$opening)
  }
  final_cash <- as.numeric(equity$cash[[nrow(equity)]])
  positions <- state$positions
  held <- positions$qty
  names(held) <- positions$instrument_id
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
  final_ts <- as.POSIXct(equity$ts_utc[[nrow(equity)]], tz = "UTC")
  lot_state <- ledgr_lot_state_asof(opened$con, run_id, exp$universe, final_ts)
  total_basis <- lot_state$cost_basis_by_inst[names(held)]
  cost_basis <- as.numeric(total_basis) / as.numeric(held)
  names(cost_basis) <- names(held)
  ledgr_opening(cash = final_cash, positions = held, cost_basis = cost_basis)
}
