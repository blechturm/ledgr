ledgr_wfo_bars <- function() {
  dates <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:11
  data.frame(
    ts_utc = dates,
    instrument_id = "AAA",
    open = 100 + seq_along(dates),
    high = 101 + seq_along(dates),
    low = 99 + seq_along(dates),
    close = 100 + seq_along(dates),
    volume = 1000,
    stringsAsFactors = FALSE
  )
}

ledgr_wfo_strategy <- function(ctx, params) {
  target <- ctx$flat()
  if (ctx$close("AAA") >= params$threshold) {
    target["AAA"] <- params$qty
  }
  target
}

ledgr_wfo_exp <- function(opening = ledgr_opening(cash = 10000),
                          strategy = ledgr_wfo_strategy) {
  snapshot <- ledgr_snapshot_from_df(ledgr_wfo_bars())
  exp <- ledgr_experiment(
    snapshot,
    strategy,
    opening = opening,
    cost_model = ledgr_cost_zero()
  )
  list(snapshot = snapshot, exp = exp)
}

ledgr_wfo_folds <- function() {
  ledgr:::ledgr_fold_list(
    list(
      ledgr_fold("2020-01-01", "2020-01-04", "2020-01-05", "2020-01-07", fold_seq = 1L),
      ledgr_fold("2020-01-04", "2020-01-07", "2020-01-08", "2020-01-10", fold_seq = 2L)
    ),
    constructor = list(type_id = "explicit")
  )
}

ledgr_wfo_grid <- function() {
  ledgr_param_grid(
    trade = list(qty = 1, threshold = 101),
    idle = list(qty = 0, threshold = 999)
  )
}

ledgr_wfo_candidate_failure_strategy <- function(ctx, params) {
  if (isTRUE(params$fail)) {
    rlang::abort("candidate failed", class = "ledgr_test_candidate_failure")
  }
  target <- ctx$flat()
  if (ctx$close("AAA") >= params$threshold) {
    target["AAA"] <- params$qty
  }
  target
}

ledgr_wfo_test_failure_strategy <- function(ctx, params) {
  if (as.POSIXct(ctx$ts_utc, tz = "UTC") >= as.POSIXct("2020-01-05", tz = "UTC")) {
    rlang::abort("selected test run failed", class = "ledgr_test_run_failure")
  }
  target <- ctx$flat()
  if (ctx$close("AAA") >= params$threshold) {
    target["AAA"] <- params$qty
  }
  target
}

ledgr_wfo_interrupt_strategy <- function(ctx, params) {
  if (as.POSIXct(ctx$ts_utc, tz = "UTC") >= as.POSIXct("2020-01-08", tz = "UTC")) {
    cond <- structure(
      list(message = "simulated interrupt", call = NULL),
      class = c("interrupt", "condition")
    )
    stop(cond)
  }
  target <- ctx$flat()
  if (ctx$close("AAA") >= params$threshold) {
    target["AAA"] <- params$qty
  }
  target
}

testthat::test_that("walk-forward orchestrates train sweeps, selected test runs, and persisted happy-path rows", {
  fx <- ledgr_wfo_exp()
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)

  wf <- ledgr_walk_forward(
    fx$exp,
    grid = ledgr_wfo_grid(),
    folds = ledgr_wfo_folds(),
    selection_rule = ledgr_select_argmax("sharpe_ratio"),
    seed = 101L
  )
  on.exit(lapply(wf$test_runs, close), add = TRUE)

  testthat::expect_s3_class(wf, "ledgr_walk_forward_results")
  testthat::expect_match(wf$session_id, "^[0-9a-f]{64}$")
  testthat::expect_identical(wf$opening_state_policy, "carry_test_state")
  testthat::expect_false(wf$cold_start_distorted)
  testthat::expect_equal(nrow(wf$folds), 2L)
  testthat::expect_equal(length(wf$test_runs), 2L)
  testthat::expect_true(all(wf$folds$status == "DONE"))
  testthat::expect_true(all(!is.na(wf$folds$selected_candidate_key)))
  testthat::expect_true(all(!is.na(wf$folds$test_run_id)))

  scores <- wf$scores
  testthat::expect_true(all(c("train", "test") %in% unique(scores$window)))
  testthat::expect_equal(
    sum(scores$window == "train" & scores$metric_name == "sharpe_ratio"),
    4L
  )
  testthat::expect_equal(
    sum(scores$window == "test" & scores$metric_name == "sharpe_ratio"),
    2L
  )
  testthat::expect_true(all(!is.na(scores$execution_seed)))

  selected <- wf$selected
  testthat::expect_equal(nrow(selected), 2L)
  testthat::expect_true(all(selected$candidate_id == "trade"))

  opened <- ledgr:::ledgr_run_store_open(fx$exp$snapshot$db_path)
  on.exit(ledgr:::ledgr_run_store_close(opened), add = TRUE)
  session_rows <- DBI::dbGetQuery(
    opened$con,
    "SELECT session_id, opening_state_policy FROM walk_forward_sessions WHERE session_id = ?",
    params = list(wf$session_id)
  )
  fold_rows <- DBI::dbGetQuery(
    opened$con,
    "SELECT fold_seq, selected_candidate_key, test_run_id, status FROM walk_forward_folds WHERE session_id = ? ORDER BY fold_seq",
    params = list(wf$session_id)
  )
  score_rows <- DBI::dbGetQuery(
    opened$con,
    "SELECT DISTINCT fold_seq, \"window\", status FROM walk_forward_scores WHERE session_id = ? ORDER BY fold_seq, \"window\"",
    params = list(wf$session_id)
  )

  testthat::expect_equal(nrow(session_rows), 1L)
  testthat::expect_identical(session_rows$opening_state_policy[[1]], "carry_test_state")
  testthat::expect_equal(nrow(fold_rows), 2L)
  testthat::expect_true(all(fold_rows$status == "DONE"))
  testthat::expect_equal(nrow(score_rows), 4L)
  testthat::expect_true(all(score_rows$status == "DONE"))
})

testthat::test_that("walk-forward derives fold/window candidate seeds and preserves deterministic session identity", {
  fx <- ledgr_wfo_exp()
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)

  wf <- ledgr_walk_forward(
    fx$exp,
    grid = ledgr_wfo_grid(),
    folds = ledgr_wfo_folds(),
    selection_rule = ledgr_select_argmax("sharpe_ratio"),
    seed = 202L
  )
  on.exit(lapply(wf$test_runs, close), add = TRUE)

  train_score <- wf$scores[
    wf$scores$fold_seq == 1L &
      wf$scores$window == "train" &
      wf$scores$metric_name == "sharpe_ratio" &
      wf$scores$candidate_label == "trade",
    ,
    drop = FALSE
  ]
  strategy_hash <- ledgr:::ledgr_strategy_source_info(fx$exp$strategy)$hash
  train_unseeded_key <- ledgr:::ledgr_walk_forward_candidate_key(
    params_hash = train_score$params_hash[[1]],
    feature_params_hash = train_score$feature_params_hash[[1]],
    strategy_hash = strategy_hash,
    feature_set_hash = train_score$feature_set_hash[[1]],
    alias_map_hash = train_score$alias_map_hash[[1]],
    metric_context_hash = train_score$metric_context_hash[[1]],
    cost_model_hash = train_score$cost_model_hash[[1]],
    risk_chain_hash = train_score$risk_chain_hash[[1]],
    execution_seed = NA_integer_
  )
  expected_train_seed <- ledgr:::ledgr_walk_forward_execution_seed(
    master_seed = 202L,
    fold_seq = 1L,
    window = "train",
    candidate_key = train_unseeded_key
  )
  testthat::expect_identical(train_score$execution_seed[[1]], expected_train_seed)

  test_score <- wf$scores[
    wf$scores$fold_seq == 1L &
      wf$scores$window == "test" &
      wf$scores$metric_name == "sharpe_ratio",
    ,
    drop = FALSE
  ]
  expected_test_seed <- ledgr:::ledgr_walk_forward_execution_seed(
    master_seed = 202L,
    fold_seq = 1L,
    window = "test",
    candidate_key = ledgr:::ledgr_walk_forward_candidate_key(
      params_hash = test_score$params_hash[[1]],
      feature_params_hash = test_score$feature_params_hash[[1]],
      strategy_hash = strategy_hash,
      feature_set_hash = test_score$feature_set_hash[[1]],
      alias_map_hash = test_score$alias_map_hash[[1]],
      metric_context_hash = test_score$metric_context_hash[[1]],
      cost_model_hash = test_score$cost_model_hash[[1]],
      risk_chain_hash = test_score$risk_chain_hash[[1]],
      execution_seed = NA_integer_
    )
  )
  testthat::expect_identical(test_score$execution_seed[[1]], expected_test_seed)
})

testthat::test_that("walk-forward reruns reopen deterministic test runs and replace session rows", {
  fx <- ledgr_wfo_exp()
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)

  wf_first <- ledgr_walk_forward(
    fx$exp,
    grid = ledgr_wfo_grid(),
    folds = ledgr_wfo_folds(),
    selection_rule = ledgr_select_argmax("sharpe_ratio"),
    seed = 404L
  )
  run_ids <- wf_first$folds$test_run_id
  selected <- wf_first$folds$selected_candidate_key
  lapply(wf_first$test_runs, close)

  opened <- ledgr:::ledgr_run_store_open(fx$exp$snapshot$db_path)
  runs_before <- DBI::dbGetQuery(
    opened$con,
    sprintf(
      "SELECT COUNT(*) AS n FROM runs WHERE run_id IN (%s)",
      paste(DBI::dbQuoteString(opened$con, run_ids), collapse = ", ")
    )
  )$n[[1]]
  events_before <- DBI::dbGetQuery(
    opened$con,
    sprintf(
      "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id IN (%s)",
      paste(DBI::dbQuoteString(opened$con, run_ids), collapse = ", ")
    )
  )$n[[1]]
  ledgr:::ledgr_run_store_close(opened)

  wf_second <- ledgr_walk_forward(
    fx$exp,
    grid = ledgr_wfo_grid(),
    folds = ledgr_wfo_folds(),
    selection_rule = ledgr_select_argmax("sharpe_ratio"),
    seed = 404L
  )
  on.exit(lapply(wf_second$test_runs, close), add = TRUE)

  testthat::expect_identical(wf_second$session_id, wf_first$session_id)
  testthat::expect_identical(wf_second$folds$selected_candidate_key, selected)
  testthat::expect_identical(wf_second$folds$test_run_id, run_ids)

  opened <- ledgr:::ledgr_run_store_open(fx$exp$snapshot$db_path)
  on.exit(ledgr:::ledgr_run_store_close(opened), add = TRUE)
  counts <- DBI::dbGetQuery(
    opened$con,
    "SELECT
       (SELECT COUNT(*) FROM walk_forward_sessions WHERE session_id = ?) AS sessions,
       (SELECT COUNT(*) FROM walk_forward_folds WHERE session_id = ?) AS folds,
       (SELECT COUNT(*) FROM walk_forward_scores WHERE session_id = ?) AS scores",
    params = list(wf_second$session_id, wf_second$session_id, wf_second$session_id)
  )
  runs_after <- DBI::dbGetQuery(
    opened$con,
    sprintf(
      "SELECT COUNT(*) AS n FROM runs WHERE run_id IN (%s)",
      paste(DBI::dbQuoteString(opened$con, run_ids), collapse = ", ")
    )
  )$n[[1]]
  events_after <- DBI::dbGetQuery(
    opened$con,
    sprintf(
      "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id IN (%s)",
      paste(DBI::dbQuoteString(opened$con, run_ids), collapse = ", ")
    )
  )$n[[1]]

  testthat::expect_equal(counts$sessions[[1]], 1)
  testthat::expect_equal(counts$folds[[1]], nrow(wf_second$folds))
  testthat::expect_equal(counts$scores[[1]], nrow(wf_second$scores))
  testthat::expect_equal(runs_after, runs_before)
  testthat::expect_equal(events_after, events_before)
})

testthat::test_that("flat-test state is explicit and marked cold-start distorted", {
  fx <- ledgr_wfo_exp()
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)

  wf <- NULL
  testthat::expect_warning(
    wf <- ledgr_walk_forward(
      fx$exp,
      grid = ledgr_wfo_grid(),
      folds = ledgr_wfo_folds(),
      selection_rule = ledgr_select_argmax("sharpe_ratio"),
      seed = 303L,
      opening_state_policy = "flat_test_state"
    ),
    class = "ledgr_walk_forward_cold_start_warning"
  )

  testthat::expect_identical(wf$opening_state_policy, "flat_test_state")
  on.exit(lapply(wf$test_runs, close), add = TRUE)
  testthat::expect_true(wf$cold_start_distorted)
  opened <- ledgr:::ledgr_run_store_open(fx$exp$snapshot$db_path)
  on.exit(ledgr:::ledgr_run_store_close(opened), add = TRUE)
  session <- DBI::dbGetQuery(
    opened$con,
    "SELECT opening_state_policy, meta_json FROM walk_forward_sessions WHERE session_id = ?",
    params = list(wf$session_id)
  )
  testthat::expect_identical(session$opening_state_policy[[1]], "flat_test_state")
  testthat::expect_match(session$meta_json[[1]], "cold_start_distorted", fixed = TRUE)
})

testthat::test_that("walk-forward preserves failed train candidate score rows while selecting survivors", {
  fx <- ledgr_wfo_exp(strategy = ledgr_wfo_candidate_failure_strategy)
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)

  wf <- ledgr_walk_forward(
    fx$exp,
    grid = ledgr_param_grid(
      trade = list(qty = 1, threshold = 101, fail = FALSE),
      broken = list(qty = 1, threshold = 101, fail = TRUE)
    ),
    folds = ledgr_fold_list(
      list(ledgr_fold("2020-01-01", "2020-01-04", "2020-01-05", "2020-01-07", fold_seq = 1L)),
      constructor = list(type_id = "explicit")
    ),
    selection_rule = ledgr_select_argmax("sharpe_ratio"),
    seed = 505L
  )
  on.exit(lapply(wf$test_runs, close), add = TRUE)

  failed_rows <- wf$scores[
    wf$scores$window == "train" &
      wf$scores$candidate_label == "broken" &
      wf$scores$metric_name == "sharpe_ratio",
    ,
    drop = FALSE
  ]
  testthat::expect_equal(nrow(failed_rows), 1L)
  testthat::expect_identical(failed_rows$status[[1]], "FAILED")
  testthat::expect_identical(failed_rows$error_class[[1]], "ledgr_strategy_error")
  testthat::expect_identical(wf$folds$status[[1]], "DONE")
  testthat::expect_identical(wf$selected$candidate_id[[1]], "trade")
})

testthat::test_that("walk-forward persists no-selection failure evidence", {
  fx <- ledgr_wfo_exp(strategy = ledgr_wfo_candidate_failure_strategy)
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)

  testthat::expect_error(
    ledgr_walk_forward(
      fx$exp,
      grid = ledgr_param_grid(broken = list(qty = 1, threshold = 101, fail = TRUE)),
      folds = ledgr_fold_list(
        list(ledgr_fold("2020-01-01", "2020-01-04", "2020-01-05", "2020-01-07", fold_seq = 1L)),
        constructor = list(type_id = "explicit")
      ),
      selection_rule = ledgr_select_argmax("sharpe_ratio"),
      seed = 606L
    ),
    class = "ledgr_walk_forward_no_selection"
  )

  opened <- ledgr:::ledgr_run_store_open(fx$exp$snapshot$db_path)
  on.exit(ledgr:::ledgr_run_store_close(opened), add = TRUE)
  session <- DBI::dbGetQuery(opened$con, "SELECT meta_json FROM walk_forward_sessions")
  folds <- DBI::dbGetQuery(opened$con, "SELECT status, selected_at_utc FROM walk_forward_folds")
  scores <- DBI::dbGetQuery(
    opened$con,
    "SELECT DISTINCT status, error_class FROM walk_forward_scores"
  )

  testthat::expect_equal(nrow(session), 1L)
  testthat::expect_match(session$meta_json[[1]], "\"status\":\"FAILED\"", fixed = TRUE)
  testthat::expect_identical(folds$status[[1]], "FAILED")
  testthat::expect_true(is.na(folds$selected_at_utc[[1]]))
  testthat::expect_true(all(scores$status == "FAILED"))
  testthat::expect_true("ledgr_strategy_error" %in% scores$error_class)
})

testthat::test_that("walk-forward test-run failure preserves train rows and fails the session", {
  fx <- ledgr_wfo_exp(strategy = ledgr_wfo_test_failure_strategy)
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)

  testthat::expect_error(
    ledgr_walk_forward(
      fx$exp,
      grid = ledgr_param_grid(trade = list(qty = 1, threshold = 101)),
      folds = ledgr_fold_list(
        list(ledgr_fold("2020-01-01", "2020-01-04", "2020-01-05", "2020-01-07", fold_seq = 1L)),
        constructor = list(type_id = "explicit")
      ),
      selection_rule = ledgr_select_argmax("sharpe_ratio"),
      seed = 707L
    ),
    class = "ledgr_test_run_failure"
  )

  opened <- ledgr:::ledgr_run_store_open(fx$exp$snapshot$db_path)
  on.exit(ledgr:::ledgr_run_store_close(opened), add = TRUE)
  session <- DBI::dbGetQuery(opened$con, "SELECT meta_json FROM walk_forward_sessions")
  folds <- DBI::dbGetQuery(opened$con, "SELECT status, test_run_id FROM walk_forward_folds")
  scores <- DBI::dbGetQuery(
    opened$con,
    "SELECT DISTINCT \"window\", status FROM walk_forward_scores"
  )

  testthat::expect_match(session$meta_json[[1]], "\"status\":\"FAILED\"", fixed = TRUE)
  testthat::expect_identical(folds$status[[1]], "FAILED")
  testthat::expect_true(nzchar(folds$test_run_id[[1]]))
  testthat::expect_identical(unique(scores$window), "train")
  testthat::expect_true(all(scores$status == "DONE"))
})

testthat::test_that("walk-forward interrupt after a completed fold persists a partial session", {
  fx <- ledgr_wfo_exp(strategy = ledgr_wfo_interrupt_strategy)
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)

  err <- tryCatch(
    ledgr_walk_forward(
      fx$exp,
      grid = ledgr_param_grid(trade = list(qty = 1, threshold = 101)),
      folds = ledgr_wfo_folds(),
      selection_rule = ledgr_select_argmax("sharpe_ratio"),
      seed = 808L
    ),
    interrupt = function(e) e
  )
  testthat::expect_s3_class(err, "interrupt")

  opened <- ledgr:::ledgr_run_store_open(fx$exp$snapshot$db_path)
  on.exit(ledgr:::ledgr_run_store_close(opened), add = TRUE)
  session <- DBI::dbGetQuery(opened$con, "SELECT meta_json FROM walk_forward_sessions")
  folds <- DBI::dbGetQuery(opened$con, "SELECT fold_seq, status FROM walk_forward_folds ORDER BY fold_seq")
  score_windows <- DBI::dbGetQuery(
    opened$con,
    "SELECT DISTINCT fold_seq, \"window\" FROM walk_forward_scores ORDER BY fold_seq, \"window\""
  )

  testthat::expect_match(session$meta_json[[1]], "\"status\":\"PARTIAL\"", fixed = TRUE)
  testthat::expect_equal(nrow(folds), 1L)
  testthat::expect_identical(folds$status[[1]], "DONE")
  testthat::expect_identical(unique(score_windows$fold_seq), 1L)
  testthat::expect_true(all(c("train", "test") %in% score_windows$window))
})
