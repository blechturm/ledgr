ledgr_wf_test_bars <- function() {
  dates <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:9
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

ledgr_wf_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  if (ctx$close("AAA") >= params$threshold) {
    targets["AAA"] <- params$qty
  }
  targets
}

ledgr_wf_final_bar_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  if (identical(ctx$ts_utc, params$entry_ts)) {
    targets["AAA"] <- params$qty
  }
  targets
}

ledgr_wf_norm_table <- function(x) {
  out <- tibble::as_tibble(x)
  for (col in intersect(c("run_id", "event_id"), names(out))) {
    out[[col]] <- NULL
  }
  if ("ts_utc" %in% names(out)) {
    out$ts_utc <- vapply(out$ts_utc, ledgr:::ledgr_normalize_ts_utc, character(1))
  }
  out
}

ledgr_wf_sweep_cols <- function(x, cols) {
  as.data.frame(
    stats::setNames(lapply(cols, function(col) x[[col]]), cols),
    stringsAsFactors = FALSE
  )
}

testthat::test_that("walk-forward fold constructor validates and hashes canonical fields", {
  fold <- ledgr_fold(
    train_start = "2020-01-01",
    train_end = "2020-01-05",
    test_start = "2020-01-06",
    test_end = "2020-01-08"
  )
  same <- ledgr_fold(
    train_start = as.POSIXct("2020-01-01", tz = "UTC"),
    train_end = as.POSIXct("2020-01-05", tz = "UTC"),
    test_start = as.POSIXct("2020-01-06", tz = "UTC"),
    test_end = as.POSIXct("2020-01-08", tz = "UTC")
  )
  changed <- ledgr_fold(
    train_start = "2020-01-01",
    train_end = "2020-01-05",
    test_start = "2020-01-06",
    test_end = "2020-01-09"
  )

  testthat::expect_s3_class(fold, "ledgr_fold")
  testthat::expect_s3_class(fold$train_start_utc, "POSIXct")
  testthat::expect_identical(fold$fold_seq, 1L)
  testthat::expect_identical(fold$scheme, "rolling")
  testthat::expect_null(fold$gap_value)
  testthat::expect_null(fold$gap_unit)
  testthat::expect_match(fold$fold_id, "^[0-9a-f]{64}$")
  testthat::expect_identical(fold$fold_id, same$fold_id)
  testthat::expect_false(identical(fold$fold_id, changed$fold_id))

  payload <- ledgr:::ledgr_fold_payload(fold)
  testthat::expect_identical(
    names(payload),
    c(
      "scheme", "train_start_utc", "train_end_utc", "test_start_utc",
      "test_end_utc", "gap_value", "gap_unit", "fold_seq",
      "fold_schema_version"
    )
  )

  testthat::expect_error(
    ledgr_fold("2020-01-01", "2020-01-05", "2020-01-05", "2020-01-08"),
    class = "ledgr_walk_forward_invalid_fold_window"
  )
  testthat::expect_error(
    ledgr_fold("2020-01-01", "2020-01-05", "2020-01-06", "2020-01-08", gap = "1 day"),
    class = "ledgr_walk_forward_gap_not_supported"
  )
  testthat::expect_error(
    ledgr_fold("2020-01-01", "2020-01-05", "2020-01-06", "2020-01-08", fold_seq = 0),
    class = "ledgr_walk_forward_invalid_fold_window"
  )
})

testthat::test_that("rolling and anchored fold lists preserve full train windows", {
  rolling <- ledgr_folds_rolling(
    start = "2020-01-01",
    end = "2020-01-20",
    train_window = "5 days",
    test_window = "3 days",
    step = "3 days"
  )
  anchored <- ledgr_folds_anchored(
    start = "2020-01-01",
    end = "2020-01-20",
    train_window_initial = "5 days",
    test_window = "3 days",
    step = "3 days"
  )

  testthat::expect_s3_class(rolling, "ledgr_fold_list")
  testthat::expect_s3_class(anchored, "ledgr_fold_list")
  testthat::expect_gte(length(rolling), 2L)
  testthat::expect_gte(length(anchored), 2L)
  testthat::expect_match(ledgr:::ledgr_fold_list_hash(rolling), "^[0-9a-f]{64}$")
  testthat::expect_identical(
    ledgr:::ledgr_fold_list_hash(rolling),
    attr(rolling, "fold_list_hash", exact = TRUE)
  )

  testthat::expect_identical(ledgr:::ledgr_walk_forward_iso(rolling[[1]]$train_start_utc), "2020-01-01T00:00:00Z")
  testthat::expect_identical(ledgr:::ledgr_walk_forward_iso(rolling[[1]]$train_end_utc), "2020-01-05T23:59:59Z")
  testthat::expect_identical(ledgr:::ledgr_walk_forward_iso(rolling[[2]]$train_start_utc), "2020-01-04T00:00:00Z")
  testthat::expect_identical(ledgr:::ledgr_walk_forward_iso(rolling[[2]]$train_end_utc), "2020-01-08T23:59:59Z")

  testthat::expect_identical(ledgr:::ledgr_walk_forward_iso(anchored[[1]]$train_start_utc), "2020-01-01T00:00:00Z")
  testthat::expect_identical(ledgr:::ledgr_walk_forward_iso(anchored[[1]]$train_end_utc), "2020-01-05T23:59:59Z")
  testthat::expect_identical(ledgr:::ledgr_walk_forward_iso(anchored[[2]]$train_start_utc), "2020-01-01T00:00:00Z")
  testthat::expect_identical(ledgr:::ledgr_walk_forward_iso(anchored[[2]]$train_end_utc), "2020-01-08T23:59:59Z")

  explicit_ab <- ledgr:::ledgr_fold_list(
    list(
      ledgr_fold("2020-01-01", "2020-01-05", "2020-01-06", "2020-01-08", fold_seq = 1L),
      ledgr_fold("2020-01-04", "2020-01-08", "2020-01-09", "2020-01-11", fold_seq = 2L)
    ),
    constructor = list(type_id = "explicit")
  )
  explicit_ba <- ledgr:::ledgr_fold_list(
    list(
      ledgr_fold("2020-01-04", "2020-01-08", "2020-01-09", "2020-01-11", fold_seq = 1L),
      ledgr_fold("2020-01-01", "2020-01-05", "2020-01-06", "2020-01-08", fold_seq = 2L)
    ),
    constructor = list(type_id = "explicit")
  )
  testthat::expect_false(identical(
    ledgr:::ledgr_fold_list_hash(explicit_ab),
    ledgr:::ledgr_fold_list_hash(explicit_ba)
  ))

  explicit_ab_other_constructor <- ledgr:::ledgr_fold_list(
    list(
      ledgr_fold("2020-01-01", "2020-01-05", "2020-01-06", "2020-01-08", fold_seq = 1L),
      ledgr_fold("2020-01-04", "2020-01-08", "2020-01-09", "2020-01-11", fold_seq = 2L)
    ),
    constructor = list(type_id = "explicit_alt")
  )
  testthat::expect_false(identical(
    ledgr:::ledgr_fold_list_hash(explicit_ab),
    ledgr:::ledgr_fold_list_hash(explicit_ab_other_constructor)
  ))

  testthat::expect_identical(
    ledgr:::ledgr_walk_forward_period("1 quarter", "`quarter`")$label,
    "3 months"
  )

  testthat::expect_error(
    ledgr_folds_rolling(
      start = "2020-01-01",
      end = "2020-01-05",
      train_window = "1 year",
      test_window = "3 months"
    ),
    class = "ledgr_walk_forward_invalid_fold_window"
  )
})

testthat::test_that("experiment windows validate pulse coverage and derive fold windows", {
  bars <- ledgr_wf_test_bars()
  snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(snapshot, ledgr_wf_strategy, cost_model = ledgr_cost_zero())
  fold <- ledgr_fold("2020-01-02", "2020-01-04", "2020-01-05", "2020-01-07")

  train <- ledgr:::ledgr_experiment_window_from_fold(exp, fold, window = "train")
  test <- ledgr:::ledgr_experiment_window_from_fold(exp, fold, window = "test")

  testthat::expect_s3_class(train, "ledgr_experiment_window")
  testthat::expect_identical(ledgr:::ledgr_walk_forward_iso(train$hydration_start_utc), "2020-01-01T00:00:00Z")
  testthat::expect_identical(ledgr:::ledgr_walk_forward_iso(train$scoring_start_utc), "2020-01-02T00:00:00Z")
  testthat::expect_identical(ledgr:::ledgr_walk_forward_iso(train$scoring_end_utc), "2020-01-04T00:00:00Z")
  testthat::expect_identical(ledgr:::ledgr_walk_forward_iso(train$execution_start_utc), "2020-01-02T00:00:00Z")
  testthat::expect_identical(ledgr:::ledgr_walk_forward_iso(test$scoring_start_utc), "2020-01-05T00:00:00Z")
  testthat::expect_identical(ledgr:::ledgr_walk_forward_iso(test$scoring_end_utc), "2020-01-07T00:00:00Z")

  testthat::expect_error(
    ledgr:::ledgr_experiment_window(exp, "2020-01-02", "2020-01-02"),
    class = "ledgr_walk_forward_invalid_fold_window"
  )
  testthat::expect_error(
    ledgr:::ledgr_experiment_window(exp, "2019-12-31", "2020-01-03"),
    class = "ledgr_walk_forward_invalid_fold_window"
  )
})

testthat::test_that("windowed run and sweep match equivalent sliced snapshots", {
  bars <- ledgr_wf_test_bars()
  window_rows <- bars[bars$ts_utc >= as.POSIXct("2020-01-02", tz = "UTC") &
    bars$ts_utc <= as.POSIXct("2020-01-06", tz = "UTC"), , drop = FALSE]

  snapshot_full <- ledgr_snapshot_from_df(bars)
  snapshot_slice <- ledgr_snapshot_from_df(window_rows)
  on.exit(ledgr_snapshot_close(snapshot_full), add = TRUE)
  on.exit(ledgr_snapshot_close(snapshot_slice), add = TRUE)

  exp_full <- ledgr_experiment(snapshot_full, ledgr_wf_strategy, cost_model = ledgr_cost_zero())
  exp_slice <- ledgr_experiment(snapshot_slice, ledgr_wf_strategy, cost_model = ledgr_cost_zero())
  window <- ledgr:::ledgr_experiment_window(exp_full, "2020-01-02", "2020-01-06")
  params <- list(qty = 1, threshold = 103)

  run_window <- ledgr:::ledgr_run_window(exp_full, params = params, window = window, run_id = "wf-window-run", seed = 11L)
  run_direct <- ledgr_run(exp_slice, params = params, run_id = "wf-direct-run", seed = 11L)
  on.exit(close(run_window), add = TRUE)
  on.exit(close(run_direct), add = TRUE)

  testthat::expect_equal(
    ledgr_wf_norm_table(ledgr_results(run_window, "fills")),
    ledgr_wf_norm_table(ledgr_results(run_direct, "fills")),
    tolerance = 1e-10
  )
  testthat::expect_equal(
    ledgr_wf_norm_table(ledgr_results(run_window, "equity")),
    ledgr_wf_norm_table(ledgr_results(run_direct, "equity")),
    tolerance = 1e-10
  )
  testthat::expect_equal(
    ledgr_compute_metrics(run_window),
    ledgr_compute_metrics(run_direct),
    tolerance = 1e-10
  )

  grid <- ledgr_param_grid(
    low = list(qty = 1, threshold = 102),
    high = list(qty = 2, threshold = 105)
  )
  sweep_window <- ledgr:::ledgr_sweep_window(exp_full, grid, window = window, seed = 22L)
  sweep_direct <- ledgr_sweep(exp_slice, grid, seed = 22L)
  metric_cols <- c("candidate_id", "status", "final_equity", "total_return", "n_trades")
  testthat::expect_equal(
    ledgr_wf_sweep_cols(sweep_window, metric_cols),
    ledgr_wf_sweep_cols(sweep_direct, metric_cols),
    tolerance = 1e-10
  )
  testthat::expect_identical(attr(sweep_window, "scoring_range")$start, "2020-01-02T00:00:00Z")
  testthat::expect_identical(attr(sweep_window, "scoring_range")$end, "2020-01-06T00:00:00Z")
})

testthat::test_that("windowed execution preserves final-bar no-fill semantics at scoring_end", {
  bars <- ledgr_wf_test_bars()
  snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(snapshot, ledgr_wf_final_bar_strategy, cost_model = ledgr_cost_zero())
  window <- ledgr:::ledgr_experiment_window(exp, "2020-01-02", "2020-01-04")

  run <- NULL
  testthat::expect_warning(
    run <- ledgr:::ledgr_run_window(
      exp,
      params = list(qty = 1, entry_ts = "2020-01-04T00:00:00Z"),
      window = window,
      run_id = "wf-final-bar-no-fill",
      seed = 33L
    ),
    "LEDGR_LAST_BAR_NO_FILL"
  )
  on.exit(close(run), add = TRUE)
  testthat::expect_identical(ledgr_compute_metrics(run)$n_trades, 0L)
  testthat::expect_equal(nrow(ledgr_results(run, "fills")), 0)
})

testthat::test_that("walk-forward Batch 1 does not add a pulse loop to fold engine", {
  fold_engine_path <- testthat::test_path("..", "..", "R", "fold-engine.R")
  testthat::skip_if_not(
    file.exists(fold_engine_path),
    "fold-engine source file is unavailable in this test layout"
  )
  fold_engine <- readLines(fold_engine_path, warn = FALSE)
  testthat::expect_false(any(grepl("walk_forward|walk-forward", fold_engine)))
})
