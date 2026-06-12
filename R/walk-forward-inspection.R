#' Inspect a persisted walk-forward session
#'
#' These helpers reopen compact walk-forward evidence from the experiment store
#' without recomputing, rerunning, or mutating stored artifacts.
#'
#' @param snapshot A sealed `ledgr_snapshot` locating the experiment store.
#' @param session_id Walk-forward session identifier.
#' @return `ledgr_walk_forward_open()` returns a
#'   `ledgr_walk_forward_results` list. Reopened sessions do not rehydrate live
#'   backtest objects in `test_runs`; that field contains linked test `run_id`
#'   strings. The reopened object includes the same programmatic `degradation`
#'   table fields used by print. `ledgr_walk_forward_scores()` and
#'   `ledgr_walk_forward_folds()` return tibbles.
#' @export
ledgr_walk_forward_open <- function(snapshot, session_id) {
  data <- ledgr_walk_forward_read_session(snapshot, session_id, verify_runs = TRUE)
  selected <- ledgr_walk_forward_selected_from_rows(data$folds, data$scores, data$meta$selection_metric %||% NULL)
  structure(
    list(
      session_id = data$session$session_id[[1]],
      status = data$status,
      opening_state_policy = data$session$opening_state_policy[[1]],
      cold_start_distorted = isTRUE(data$meta$cold_start_distorted),
      folds = data$folds,
      scores = data$scores,
      degradation = ledgr_walk_forward_degradation_table(
        folds = data$folds,
        scores = data$scores,
        selection_metric = data$meta$selection_metric %||% NULL,
        cold_start_distorted = isTRUE(data$meta$cold_start_distorted)
      ),
      selected = selected,
      test_runs = as.list(as.character(data$folds$test_run_id[
        !is.na(data$folds$test_run_id) &
          nzchar(as.character(data$folds$test_run_id)) &
          as.character(data$folds$status) == "DONE"
      ]))
    ),
    class = c("ledgr_walk_forward_results", "list")
  )
}

#' @rdname ledgr_walk_forward_open
#' @export
ledgr_walk_forward_scores <- function(snapshot, session_id) {
  ledgr_walk_forward_read_session(snapshot, session_id, verify_runs = TRUE)$scores
}

#' @rdname ledgr_walk_forward_open
#' @export
ledgr_walk_forward_folds <- function(snapshot, session_id) {
  ledgr_walk_forward_read_session(snapshot, session_id, verify_runs = TRUE)$folds
}

#' Extract a promotion-ready candidate from a walk-forward session
#'
#' @param snapshot A sealed `ledgr_snapshot` locating the experiment store.
#' @param session_id Walk-forward session identifier.
#' @param fold_seq Integer fold sequence to extract, or `"latest"`.
#' @param selection_rationale Optional plain-text rationale. Required when
#'   `fold_seq = "latest"`.
#' @return A `ledgr_sweep_candidate` object accepted by [ledgr_promote()].
#' @export
ledgr_walk_forward_extract_candidate <- function(snapshot,
                                                 session_id,
                                                 fold_seq,
                                                 selection_rationale = NULL) {
  if (missing(fold_seq)) {
    rlang::abort("`fold_seq` is required.", class = "ledgr_invalid_args")
  }
  data <- ledgr_walk_forward_read_session(snapshot, session_id, verify_runs = TRUE)
  rationale <- ledgr_walk_forward_selection_rationale(selection_rationale)
  fold_seq <- ledgr_walk_forward_resolve_extract_fold(data$folds, fold_seq, rationale)
  fold <- data$folds[data$folds$fold_seq == fold_seq, , drop = FALSE]
  if (nrow(fold) != 1L ||
      !identical(as.character(fold$status[[1]]), "DONE") ||
      ledgr_walk_forward_is_missing_text(fold$selected_candidate_key[[1]]) ||
      ledgr_walk_forward_is_missing_text(fold$test_run_id[[1]])) {
    rlang::abort(
      sprintf("Walk-forward fold %s does not contain a completed selected candidate.", fold_seq),
      class = "ledgr_walk_forward_candidate_not_found"
    )
  }

  train_rows <- data$scores[
    data$scores$fold_seq == fold_seq &
      data$scores$window == "train" &
      data$scores$candidate_key == fold$selected_candidate_key[[1]],
    ,
    drop = FALSE
  ]
  test_rows <- data$scores[
    data$scores$fold_seq == fold_seq &
      data$scores$window == "test",
    ,
    drop = FALSE
  ]
  if (nrow(train_rows) < 1L || nrow(test_rows) < 1L) {
    rlang::abort(
      sprintf("Walk-forward fold %s is missing selected train or test score rows.", fold_seq),
      class = "ledgr_walk_forward_candidate_not_found"
    )
  }

  run <- ledgr_walk_forward_read_run_config_from_snapshot(snapshot, fold$test_run_id[[1]])
  cfg <- run$config
  cost_identity <- ledgr_walk_forward_config_cost_identity(cfg)
  risk_identity <- ledgr_walk_forward_config_risk_identity(cfg)
  ledgr_walk_forward_verify_run_identity(
    session = data$session,
    run = run,
    cost_identity = cost_identity,
    risk_identity = risk_identity
  )

  selection_metric <- data$meta$selection_metric %||% NULL
  train_metric <- ledgr_walk_forward_metric_value(train_rows, selection_metric)
  test_metric <- ledgr_walk_forward_metric_value(test_rows, selection_metric)
  test_metrics <- ledgr_walk_forward_metric_values(test_rows)
  train_metrics <- ledgr_walk_forward_metric_values(train_rows)
  test_seed <- ledgr_walk_forward_first_non_missing_integer(test_rows$execution_seed)
  if (is.na(test_seed)) {
    test_seed <- as.integer(cfg$engine$seed %||% NA_integer_)
  }

  candidate_id <- as.character(train_rows$candidate_label[[1]])
  if (ledgr_walk_forward_is_missing_text(candidate_id)) {
    candidate_id <- sprintf("fold_%s_candidate", fold_seq)
  }
  strategy_hash <- ledgr_walk_forward_config_strategy_hash(cfg)
  feature_fingerprints <- ledgr_walk_forward_config_feature_fingerprints(cfg)
  provenance <- list(
    provenance_version = "ledgr_walk_forward_candidate_v1",
    snapshot_hash = data$session$snapshot_hash[[1]],
    strategy_hash = strategy_hash,
    feature_set_hash = train_rows$feature_set_hash[[1]],
    alias_map_hash = train_rows$alias_map_hash[[1]],
    alias_map_version = cfg$alias_map_version %||% NA_integer_,
    cost_model_hash = cost_identity$cost_model_hash,
    cost_plan_json = cost_identity$cost_plan_json,
    risk_chain_hash = risk_identity$risk_chain_hash,
    risk_plan_json = risk_identity$risk_plan_json,
    master_seed = as.integer(data$session$master_seed[[1]]),
    seed_contract = "ledgr_walk_forward_seed_v1",
    evaluation_scope = "walk_forward",
    walk_forward = list(
      session_id = data$session$session_id[[1]],
      fold_id = fold$fold_id[[1]],
      fold_seq = fold_seq,
      train_candidate_key = fold$selected_candidate_key[[1]],
      test_run_id = fold$test_run_id[[1]],
      selection_metric = selection_metric,
      selected_train_metric_value = train_metric,
      selected_test_metric_value = test_metric,
      selection_rationale = rationale
    )
  )

  candidate_row <- tibble::tibble(
    candidate_id = candidate_id,
    candidate_row = as.integer(fold_seq),
    status = "DONE",
    final_equity = as.numeric(test_metrics$final_equity %||% NA_real_),
    total_return = as.numeric(test_metrics$total_return %||% NA_real_),
    annualized_return = as.numeric(test_metrics$annualized_return %||% NA_real_),
    volatility = as.numeric(test_metrics$volatility %||% NA_real_),
    sharpe_ratio = as.numeric(test_metrics$sharpe_ratio %||% NA_real_),
    max_drawdown = as.numeric(test_metrics$max_drawdown %||% NA_real_),
    n_trades = as.integer(test_rows$n_trades[[1]] %||% NA_integer_),
    win_rate = as.numeric(test_metrics$win_rate %||% NA_real_),
    avg_trade = as.numeric(test_metrics$avg_trade %||% NA_real_),
    time_in_market = as.numeric(test_metrics$time_in_market %||% NA_real_),
    execution_seed = as.integer(test_seed),
    params = list(cfg$strategy_params %||% list()),
    feature_params = list(cfg$feature_params %||% list()),
    warnings = list(character()),
    feature_fingerprints = list(feature_fingerprints),
    risk_chain_hash = risk_identity$risk_chain_hash,
    provenance = list(provenance)
  )
  attr(candidate_row, "sweep_id") <- data$session$session_id[[1]]
  attr(candidate_row, "snapshot_id") <- ledgr_run_store_snapshot_id(snapshot)
  attr(candidate_row, "snapshot_hash") <- data$session$snapshot_hash[[1]]
  attr(candidate_row, "scoring_range") <- list(
    start = fold$train_scoring_start_utc[[1]],
    end = fold$train_end_utc[[1]]
  )
  attr(candidate_row, "universe") <- cfg$universe$instrument_ids %||% character()
  attr(candidate_row, "master_seed") <- as.integer(data$session$master_seed[[1]])
  attr(candidate_row, "seed_contract") <- "ledgr_walk_forward_seed_v1"
  attr(candidate_row, "evaluation_scope") <- "walk_forward"
  attr(candidate_row, "strategy_hash") <- strategy_hash
  attr(candidate_row, "feature_union") <- feature_fingerprints
  attr(candidate_row, "feature_union_hash") <- cfg$features$feature_set_hash %||% train_rows$feature_set_hash[[1]]
  attr(candidate_row, "feature_engine_version") <- ledgr_feature_engine_version()
  attr(candidate_row, "metric_context_hash") <- data$session$metric_context_hash[[1]]
  attr(candidate_row, "metric_context_version") <- as.integer(run$metric_context_version %||% NA_integer_)
  attr(candidate_row, "cost_model_hash") <- cost_identity$cost_model_hash
  attr(candidate_row, "cost_plan_json") <- cost_identity$cost_plan_json
  attr(candidate_row, "risk_chain_hash") <- risk_identity$risk_chain_hash
  attr(candidate_row, "risk_plan_json") <- risk_identity$risk_plan_json
  attr(candidate_row, "walk_forward_train_metrics") <- train_metrics
  attr(candidate_row, "walk_forward_test_metrics") <- test_metrics
  class(candidate_row) <- c("ledgr_sweep_results", class(candidate_row))

  ledgr_candidate(candidate_row, which = 1L)
}

ledgr_walk_forward_read_session <- function(snapshot, session_id, verify_runs = TRUE) {
  ledgr_walk_forward_validate_snapshot(snapshot)
  if (!is.character(session_id) || length(session_id) != 1L || is.na(session_id) || !nzchar(session_id)) {
    rlang::abort("`session_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  opened <- ledgr_run_store_open(ledgr_run_store_snapshot_path(snapshot))
  on.exit(ledgr_run_store_close(opened), add = TRUE)
  ledgr_experiment_store_check_schema(opened$con, write = FALSE)

  session <- DBI::dbGetQuery(
    opened$con,
    "SELECT * FROM walk_forward_sessions WHERE session_id = ?",
    params = list(session_id)
  )
  if (nrow(session) != 1L) {
    rlang::abort(sprintf("Walk-forward session not found: %s", session_id), class = "ledgr_walk_forward_session_not_found")
  }
  ledgr_walk_forward_verify_snapshot_hash(snapshot, session$snapshot_hash[[1]])
  meta <- ledgr_walk_forward_parse_session_meta(session$meta_json[[1]])
  folds <- tibble::as_tibble(DBI::dbGetQuery(
    opened$con,
    "SELECT * FROM walk_forward_folds WHERE session_id = ? ORDER BY fold_seq",
    params = list(session_id)
  ))
  scores <- tibble::as_tibble(DBI::dbGetQuery(
    opened$con,
    "SELECT * FROM walk_forward_scores WHERE session_id = ? ORDER BY fold_seq, \"window\", candidate_key, metric_name",
    params = list(session_id)
  ))
  if (isTRUE(verify_runs) && nrow(folds) > 0L) {
    ledgr_walk_forward_verify_linked_runs(opened$con, snapshot, session, folds)
  }
  list(
    session = tibble::as_tibble(session),
    folds = folds,
    scores = scores,
    meta = meta,
    status = as.character(meta$status %||% NA_character_)
  )
}

ledgr_walk_forward_read_run_config_from_snapshot <- function(snapshot, run_id) {
  opened <- ledgr_run_store_open(ledgr_run_store_snapshot_path(snapshot))
  on.exit(ledgr_run_store_close(opened), add = TRUE)
  ledgr_experiment_store_check_schema(opened$con, write = FALSE)
  ledgr_walk_forward_read_run_config(opened$con, snapshot, run_id)
}

ledgr_walk_forward_validate_snapshot <- function(snapshot) {
  if (!inherits(snapshot, "ledgr_snapshot")) {
    rlang::abort("`snapshot` must be a ledgr_snapshot object.", class = "ledgr_invalid_args")
  }
}

ledgr_walk_forward_verify_snapshot_hash <- function(snapshot, expected_hash) {
  meta <- ledgr_precompute_snapshot_meta(snapshot)
  if (!identical(meta$snapshot_hash, as.character(expected_hash))) {
    rlang::abort(
      "Walk-forward session snapshot hash does not match `snapshot`.",
      class = "ledgr_walk_forward_snapshot_hash_mismatch"
    )
  }
}

ledgr_walk_forward_parse_session_meta <- function(meta_json) {
  if (!is.character(meta_json) || length(meta_json) != 1L || is.na(meta_json) || !nzchar(meta_json)) {
    rlang::abort("Walk-forward session meta_json is missing.", class = "ledgr_walk_forward_invalid_session")
  }
  meta <- tryCatch(
    ledgr_json_read_nested(meta_json),
    error = function(e) {
      rlang::abort("Walk-forward session meta_json is invalid.", class = "ledgr_walk_forward_invalid_session", parent = e)
    }
  )
  if (!identical(meta$walk_forward_schema_version, ledgr_walk_forward_schema_version)) {
    rlang::abort("Walk-forward session schema version is not supported.", class = "ledgr_walk_forward_invalid_session")
  }
  meta
}

ledgr_walk_forward_read_run_config <- function(con, snapshot, run_id) {
  row <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT run_id, status, config_json, metric_context_hash,",
      "metric_context_version FROM runs WHERE run_id = ? AND snapshot_id = ?"
    ),
    params = list(run_id, ledgr_run_store_snapshot_id(snapshot))
  )
  if (nrow(row) != 1L) {
    rlang::abort(sprintf("Linked walk-forward run not found: %s", run_id), class = "ledgr_walk_forward_invalid_session")
  }
  if (!identical(as.character(row$status[[1]]), "DONE")) {
    rlang::abort(sprintf("Linked walk-forward run '%s' is not complete.", run_id), class = "ledgr_walk_forward_invalid_session")
  }
  cfg <- tryCatch(
    ledgr_json_read_config(row$config_json[[1]]),
    error = function(e) {
      rlang::abort(sprintf("Linked walk-forward run '%s' has invalid config_json.", run_id), class = "ledgr_walk_forward_invalid_session", parent = e)
    }
  )
  cfg$db_path <- ledgr_run_store_snapshot_path(snapshot)
  if (is.list(cfg$alias_map_order) && length(cfg$alias_map_order) == 0L) {
    cfg$alias_map_order <- character()
  }
  cfg <- ledgr_config_normalize_risk_identity(cfg)
  class(cfg) <- unique(c("ledgr_config", class(cfg)))
  tryCatch(
    validate_ledgr_config(cfg),
    error = function(e) {
      rlang::abort(sprintf("Linked walk-forward run '%s' has invalid config_json.", run_id), class = "ledgr_walk_forward_invalid_session", parent = e)
    }
  )
  list(
    run_id = row$run_id[[1]],
    status = row$status[[1]],
    config = cfg,
    metric_context_hash = row$metric_context_hash[[1]],
    metric_context_version = as.integer(row$metric_context_version[[1]])
  )
}

ledgr_walk_forward_verify_linked_runs <- function(con, snapshot, session, folds) {
  test_runs <- folds$test_run_id[
    !is.na(folds$test_run_id) &
      nzchar(as.character(folds$test_run_id)) &
      as.character(folds$status) == "DONE"
  ]
  for (run_id in unique(as.character(test_runs))) {
    run <- ledgr_walk_forward_read_run_config(con, snapshot, run_id)
    ledgr_walk_forward_verify_run_identity(
      session = session,
      run = run,
      cost_identity = ledgr_walk_forward_config_cost_identity(run$config),
      risk_identity = ledgr_walk_forward_config_risk_identity(run$config)
    )
  }
  invisible(TRUE)
}

ledgr_walk_forward_verify_run_identity <- function(session, run, cost_identity, risk_identity) {
  if (!identical(cost_identity$cost_model_hash, session$cost_model_hash[[1]])) {
    rlang::abort("Linked walk-forward run cost identity does not match session identity.", class = "ledgr_walk_forward_invalid_session")
  }
  if (!identical(risk_identity$risk_chain_hash, session$risk_chain_hash[[1]])) {
    rlang::abort("Linked walk-forward run risk identity does not match session identity.", class = "ledgr_walk_forward_invalid_session")
  }
  metric_hash <- as.character(run$metric_context_hash %||% NA_character_)
  if (!identical(metric_hash, as.character(session$metric_context_hash[[1]]))) {
    rlang::abort("Linked walk-forward run metric identity does not match session identity.", class = "ledgr_walk_forward_invalid_session")
  }
  invisible(TRUE)
}

ledgr_walk_forward_config_cost_identity <- function(cfg) {
  cost_hash <- cfg$cost_model$cost_model_hash
  cost_plan <- cfg$cost_model$cost_plan_json
  ledgr_cost_plan_reconstruct(cost_plan)
  # The stored cost_plan_json is the durable byte identity. Reconstructing a
  # singleton cost model can normalize it to a chain-shaped runtime model, so
  # validate by hashing the canonicalized stored bytes rather than the model.
  canonical_plan <- as.character(canonical_json(cost_plan))
  if (!identical(digest::digest(canonical_plan, algo = "sha256"), cost_hash)) {
    rlang::abort("Linked walk-forward run cost identity does not match cost_plan_json.", class = "ledgr_walk_forward_invalid_session")
  }
  list(cost_model_hash = cost_hash, cost_plan_json = canonical_plan)
}

ledgr_walk_forward_config_risk_identity <- function(cfg) {
  risk_hash <- cfg$risk_chain$risk_chain_hash
  risk_plan <- cfg$risk_chain$risk_plan_json
  risk <- ledgr_risk_plan_reconstruct(risk_plan)
  canonical_plan <- ledgr_risk_plan_json(risk)
  if (!identical(canonical_plan, as.character(canonical_json(risk_plan))) ||
      !identical(ledgr_risk_chain_hash(risk), risk_hash)) {
    rlang::abort("Linked walk-forward run risk identity does not match risk_plan_json.", class = "ledgr_walk_forward_invalid_session")
  }
  list(risk_chain_hash = risk_hash, risk_plan_json = canonical_plan)
}

ledgr_walk_forward_selected_from_rows <- function(folds, scores, selection_metric = NULL) {
  if (nrow(folds) < 1L || nrow(scores) < 1L) {
    return(tibble::tibble())
  }
  selected <- folds[as.character(folds$status) == "DONE", , drop = FALSE]
  if (nrow(selected) < 1L) {
    return(tibble::tibble())
  }
  rows <- lapply(seq_len(nrow(selected)), function(i) {
    fold <- selected[i, , drop = FALSE]
    score <- scores[
      scores$fold_seq == fold$fold_seq[[1]] &
        scores$window == "train" &
        scores$candidate_key == fold$selected_candidate_key[[1]],
      ,
      drop = FALSE
    ]
    label <- if (nrow(score) > 0L) as.character(score$candidate_label[[1]]) else NA_character_
    out <- data.frame(
      fold_seq = as.integer(fold$fold_seq[[1]]),
      candidate_key = as.character(fold$selected_candidate_key[[1]]),
      candidate_id = label,
      test_run_id = as.character(fold$test_run_id[[1]]),
      stringsAsFactors = FALSE
    )
    if (!is.null(selection_metric) && !ledgr_walk_forward_is_missing_text(selection_metric)) {
      out[[as.character(selection_metric)]] <- ledgr_walk_forward_metric_value(score, selection_metric)
      out <- out[, c("fold_seq", "candidate_key", "candidate_id", as.character(selection_metric), "test_run_id"), drop = FALSE]
    }
    out
  })
  tibble::as_tibble(do.call(rbind, rows))
}

ledgr_walk_forward_degradation_table <- function(folds,
                                                 scores,
                                                 selection_metric,
                                                 cold_start_distorted = FALSE) {
  folds <- tibble::as_tibble(folds)
  scores <- tibble::as_tibble(scores)
  if (nrow(folds) < 1L || nrow(scores) < 1L ||
      is.null(selection_metric) || ledgr_walk_forward_is_missing_text(selection_metric)) {
    return(tibble::tibble(
      fold_seq = integer(),
      train_window = character(),
      test_window = character(),
      selected_candidate = character(),
      selection_metric = character(),
      train_metric_value = numeric(),
      test_metric_value = numeric(),
      metric_diff_abs = numeric(),
      metric_diff_pct = numeric(),
      warning_flags = character()
    ))
  }
  rows <- lapply(seq_len(nrow(folds)), function(i) {
    fold <- folds[i, , drop = FALSE]
    selected_key <- as.character(fold$selected_candidate_key[[1]])
    train_rows <- scores[
      scores$fold_seq == fold$fold_seq[[1]] &
        scores$window == "train" &
        scores$candidate_key == selected_key,
      ,
      drop = FALSE
    ]
    test_rows <- scores[
      scores$fold_seq == fold$fold_seq[[1]] &
        scores$window == "test",
      ,
      drop = FALSE
    ]
    train_value <- ledgr_walk_forward_metric_value(train_rows, selection_metric)
    test_value <- ledgr_walk_forward_metric_value(test_rows, selection_metric)
    diff_abs <- test_value - train_value
    diff_pct <- if (is.finite(train_value) && abs(train_value) > .Machine$double.eps) {
      diff_abs / abs(train_value)
    } else {
      NA_real_
    }
    test_days <- as.numeric(difftime(
      as.POSIXct(fold$test_end_utc[[1]], tz = "UTC"),
      as.POSIXct(fold$test_start_utc[[1]], tz = "UTC"),
      units = "days"
    ))
    flags <- character()
    if (is.finite(test_days) && test_days < 90) {
      flags <- c(flags, "short_test_window")
    }
    if (isTRUE(cold_start_distorted)) {
      flags <- c(flags, "cold_start_distorted")
    }
    candidate <- if (nrow(train_rows) > 0L) as.character(train_rows$candidate_label[[1]]) else NA_character_
    data.frame(
      fold_seq = as.integer(fold$fold_seq[[1]]),
      train_window = sprintf("%s/%s", ledgr_walk_forward_iso(fold$train_start_utc[[1]]), ledgr_walk_forward_iso(fold$train_end_utc[[1]])),
      test_window = sprintf("%s/%s", ledgr_walk_forward_iso(fold$test_start_utc[[1]]), ledgr_walk_forward_iso(fold$test_end_utc[[1]])),
      selected_candidate = candidate,
      selection_metric = as.character(selection_metric),
      train_metric_value = as.numeric(train_value),
      test_metric_value = as.numeric(test_value),
      metric_diff_abs = as.numeric(diff_abs),
      metric_diff_pct = as.numeric(diff_pct),
      # Keep storage/export scalar; use ledgr_walk_forward_has_flag() for membership.
      warning_flags = paste(flags, collapse = ","),
      stringsAsFactors = FALSE
    )
  })
  tibble::as_tibble(do.call(rbind, rows))
}

ledgr_walk_forward_selection_rationale <- function(x) {
  if (is.null(x)) return(NULL)
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    rlang::abort("`selection_rationale` must be NULL or a character scalar.", class = "ledgr_invalid_args")
  }
  x <- trimws(x)
  if (!nzchar(x)) return(NULL)
  x
}

ledgr_walk_forward_resolve_extract_fold <- function(folds, fold_seq, selection_rationale) {
  if (is.character(fold_seq) && length(fold_seq) == 1L && identical(fold_seq, "latest")) {
    if (is.null(selection_rationale)) {
      rlang::abort(
        "`selection_rationale` is required when `fold_seq = \"latest\"`.",
        class = "ledgr_walk_forward_latest_without_rationale"
      )
    }
    eligible <- folds[
      as.character(folds$status) == "DONE" &
        !is.na(folds$selected_candidate_key) &
        nzchar(as.character(folds$selected_candidate_key)),
      ,
      drop = FALSE
    ]
    if (nrow(eligible) < 1L) {
      rlang::abort("No completed walk-forward fold is available for latest extraction.", class = "ledgr_walk_forward_candidate_not_found")
    }
    return(max(as.integer(eligible$fold_seq)))
  }
  if (!is.numeric(fold_seq) || length(fold_seq) != 1L || is.na(fold_seq) ||
      !is.finite(fold_seq) || fold_seq != as.integer(fold_seq) || fold_seq < 1L) {
    rlang::abort("`fold_seq` must be a positive integer or \"latest\".", class = "ledgr_invalid_args")
  }
  as.integer(fold_seq)
}

ledgr_walk_forward_metric_values <- function(rows) {
  out <- as.list(rows$metric_value)
  names(out) <- as.character(rows$metric_name)
  out
}

ledgr_walk_forward_metric_value <- function(rows, metric) {
  if (is.null(metric) || ledgr_walk_forward_is_missing_text(metric)) {
    return(NA_real_)
  }
  idx <- which(as.character(rows$metric_name) == as.character(metric))
  if (length(idx) < 1L) return(NA_real_)
  as.numeric(rows$metric_value[[idx[[1L]]]])
}

ledgr_walk_forward_first_non_missing_integer <- function(x) {
  x <- as.integer(x)
  x <- x[!is.na(x)]
  if (length(x) < 1L) return(NA_integer_)
  x[[1L]]
}

ledgr_walk_forward_is_missing_text <- function(x) {
  is.null(x) || length(x) != 1L || is.na(x) || !nzchar(as.character(x))
}

ledgr_walk_forward_has_flag <- function(warning_flags, flag) {
  vapply(warning_flags, function(x) {
    if (ledgr_walk_forward_is_missing_text(x)) return(FALSE)
    flag %in% strsplit(as.character(x), ",", fixed = TRUE)[[1L]]
  }, logical(1))
}

ledgr_walk_forward_config_strategy_hash <- function(cfg) {
  hash <- cfg$strategy$provenance$strategy_source_hash %||% NA_character_
  if (ledgr_walk_forward_is_missing_text(hash)) {
    hash <- cfg$strategy$provenance$strategy_hash %||% NA_character_
  }
  as.character(hash)
}

ledgr_walk_forward_config_feature_fingerprints <- function(cfg) {
  defs <- cfg$features$defs %||% list()
  if (length(defs) < 1L) return(character())
  out <- vapply(defs, function(def) as.character(def$fingerprint %||% NA_character_), character(1))
  out[!is.na(out) & nzchar(out)]
}
