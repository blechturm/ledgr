testthat::test_that("ledgr_backtest S3 methods return tidy outputs", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snap <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  one_leg <- function(ctx, params) c(TEST_A = 100)

  bt <- ledgr_backtest(
    snapshot = snap,
    strategy = one_leg,
    universe = "TEST_A",
    start = "2020-01-01",
    end = "2020-01-15",
    db_path = db_path,
  cost_model = ledgr_cost_zero()
  )

  out_print <- capture.output(print(bt))
  testthat::expect_true(any(grepl("ledgr Backtest Results", out_print)))
  testthat::expect_true(any(grepl("Run ID", out_print)))

  out_summary <- capture.output(summary(bt))
  testthat::expect_true(any(grepl("ledgr Backtest Summary", out_summary)))
  testthat::expect_true(any(grepl("Total Return", out_summary)))

  eq <- as_tibble(bt, "equity")
  testthat::expect_s3_class(eq, "tbl_df")
  testthat::expect_true(all(c("running_max", "drawdown") %in% names(eq)))

  returns <- as_tibble(bt, "returns")
  testthat::expect_s3_class(returns, "tbl_df")
  testthat::expect_identical(names(returns), c("ts_utc", "equity", "period_return"))
  testthat::expect_s3_class(returns$ts_utc, "POSIXct")
  testthat::expect_equal(returns$equity, eq$equity)
  testthat::expect_true(is.na(returns$period_return[[1L]]))
  testthat::expect_equal(returns$period_return[-1L], ledgr:::compute_period_returns(eq$equity))

  retained_returns <- ledgr:::ledgr_sweep_retained_returns_from_equity(
    eq[, c("ts_utc", "equity")],
    candidate_id = "candidate-1",
    candidate_row = 1L
  )
  testthat::expect_equal(returns$ts_utc, retained_returns$ts_utc)
  testthat::expect_equal(returns$equity, retained_returns$equity)
  testthat::expect_equal(returns$period_return, retained_returns$period_return)

  returns_result <- ledgr_results(bt, what = "returns")
  testthat::expect_s3_class(returns_result, "ledgr_result_returns")
  testthat::expect_s3_class(returns_result, "ledgr_result_table")
  testthat::expect_identical(tibble::as_tibble(returns_result), returns)

  fills <- as_tibble(bt, "fills")
  testthat::expect_s3_class(fills, "tbl_df")
  testthat::expect_true("realized_pnl" %in% names(fills))

  trades <- as_tibble(bt, type = "trades")
  testthat::expect_s3_class(trades, "tbl_df")

  ledger <- as_tibble(bt, "ledger")
  testthat::expect_s3_class(ledger, "tbl_df")
  testthat::expect_true("event_seq" %in% names(ledger))

  bench <- ledgr_backtest_bench(bt)
  testthat::expect_s3_class(bench, "tbl_df")
  testthat::expect_true(all(c("component", "mean", "median", "p99") %in% names(bench)))

  testthat::expect_error(
    ledgr_compute_metrics(bt, metrics = "advanced"),
    class = "ledgr_invalid_args"
  )
  testthat::expect_error(
    ledgr_backtest_bench(list()),
    class = "ledgr_invalid_backtest"
  )
  testthat::expect_error(
    ledgr:::ledgr_backtest_open(list()),
    class = "ledgr_invalid_backtest"
  )
  testthat::expect_error(
    ledgr:::close.ledgr_backtest(list(), cost_model = ledgr_cost_zero()),
    class = "ledgr_invalid_backtest"
  )

  bt_without_telemetry <- ledgr:::new_ledgr_backtest("missing-telemetry", db_path, config = bt$config)
  testthat::expect_error(
    ledgr_backtest_bench(bt_without_telemetry),
    class = "ledgr_invalid_args"
  )
  testthat::expect_error(as_tibble(bt, "unknown"))
  metrics_err <- rlang::catch_cnd(ledgr_results(bt, what = "metrics"))
  testthat::expect_s3_class(metrics_err, "ledgr_invalid_result_table")
  testthat::expect_match(conditionMessage(metrics_err), "ledgr_compute_metrics", fixed = TRUE)
  feature_err <- rlang::catch_cnd(ledgr_results(bt, what = "features"))
  testthat::expect_s3_class(feature_err, "ledgr_invalid_result_table")
  testthat::expect_match(conditionMessage(feature_err), "ledgr_pulse_snapshot", fixed = TRUE)
  testthat::expect_match(conditionMessage(feature_err), "ledgr_pulse_features", fixed = TRUE)
  testthat::expect_error(ledgr:::summary.ledgr_backtest(list(), cost_model = ledgr_cost_zero()), class = "ledgr_invalid_backtest")

  testthat::expect_error(close(bt), NA)
})

testthat::test_that("summary surfaces impossible warmup diagnostics without changing results", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  ts <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:9
  bars <- data.frame(
    ts_utc = ts,
    instrument_id = "AAA",
    open = 100 + seq_along(ts),
    high = 101 + seq_along(ts),
    low = 99 + seq_along(ts),
    close = 100 + seq_along(ts),
    volume = 1000,
    stringsAsFactors = FALSE
  )
  features <- list(ledgr_ind_sma(20))
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    value <- ctx$feature("AAA", "sma_20")
    if (is.finite(value)) {
      targets["AAA"] <- 1
    }
    targets
  }

  bt <- ledgr_backtest(
    data = bars,
    strategy = strategy,
    features = features,
    db_path = db_path,
    run_id = "warmup-diagnostic-run",
  cost_model = ledgr_cost_zero()
  )
  on.exit(close(bt), add = TRUE)

  diagnostics <- ledgr:::ledgr_backtest_warmup_diagnostics(bt)
  testthat::expect_s3_class(diagnostics, "ledgr_warmup_diagnostics")
  testthat::expect_equal(nrow(diagnostics), 1L)
  testthat::expect_identical(diagnostics$feature_id[[1]], "sma_20")
  testthat::expect_identical(diagnostics$instrument_id[[1]], "AAA")
  testthat::expect_identical(diagnostics$required_bars[[1]], 20L)
  testthat::expect_identical(diagnostics$available_bars[[1]], 10L)

  fills_before <- ledgr_results(bt, what = "fills")
  trades_before <- ledgr_results(bt, what = "trades")
  metrics_before <- ledgr_compute_metrics(bt)
  opened <- ledgr:::ledgr_backtest_read_connection(bt)
  on.exit(opened$close(), add = TRUE)
  run_before <- DBI::dbGetQuery(
    opened$con,
    "SELECT status, config_hash, snapshot_id FROM runs WHERE run_id = ?",
    params = list(bt$run_id)
  )

  out <- utils::capture.output(summary(bt))
  testthat::expect_true(any(grepl("Warmup Diagnostics", out, fixed = TRUE)))
  testthat::expect_true(any(grepl("sma_20", out, fixed = TRUE)))
  testthat::expect_true(any(grepl("AAA", out, fixed = TRUE)))
  testthat::expect_true(any(grepl("required bars 20", out, fixed = TRUE)))
  testthat::expect_true(any(grepl("available bars 10", out, fixed = TRUE)))

  testthat::expect_equal(ledgr_results(bt, what = "fills"), fills_before)
  testthat::expect_equal(ledgr_results(bt, what = "trades"), trades_before)
  testthat::expect_equal(ledgr_compute_metrics(bt), metrics_before)
  run_after <- DBI::dbGetQuery(
    opened$con,
    "SELECT status, config_hash, snapshot_id FROM runs WHERE run_id = ?",
    params = list(bt$run_id)
  )
  testthat::expect_equal(run_after, run_before)
  testthat::expect_equal(nrow(trades_before), 0L)

  broken_diagnostic_bt <- bt
  broken_diagnostic_bt$config$backtest$start_ts_utc <- "not-a-timestamp"
  testthat::expect_error(utils::capture.output(summary(broken_diagnostic_bt)), NA)
})

testthat::test_that("warmup diagnostic matching handles uneven instrument sample counts", {
  feature_contracts <- tibble::tibble(
    feature_id = c("sma_20", "return_5"),
    required_bars = c(20L, 6L),
    stable_after = c(20L, 6L)
  )
  bar_counts <- tibble::tibble(
    instrument_id = c("AAA", "BBB"),
    available_bars = c(10L, 25L)
  )

  diagnostics <- ledgr:::ledgr_warmup_diagnostics_from_counts(feature_contracts, bar_counts)
  testthat::expect_s3_class(diagnostics, "ledgr_warmup_diagnostics")
  testthat::expect_equal(nrow(diagnostics), 1L)
  testthat::expect_identical(diagnostics$feature_id[[1]], "sma_20")
  testthat::expect_identical(diagnostics$instrument_id[[1]], "AAA")
})
