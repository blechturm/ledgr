testthat::test_that("raw signal strings are not valid functional strategy results", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  bars <- ledgr_test_make_bars(
    instrument_ids = "AAA",
    ts_utc = c("2020-01-01", "2020-01-02", "2020-01-03")
  )

  testthat::expect_error(
    ledgr_backtest(
      data = bars,
      strategy = function(ctx) "LONG",
      universe = "AAA",
      start = "2020-01-01",
      end = "2020-01-02",
      db_path = db_path
    ),
    class = "ledgr_invalid_strategy_result"
  )
})

testthat::test_that("ledgr_signal_strategy maps scalar and named vector signals to targets", {
  ts <- "2020-01-02T00:00:00Z"
  one_ctx <- ledgr:::ledgr_pulse_context(
    run_id = "run-1",
    ts_utc = ts,
    universe = "AAA",
    bars = data.frame(instrument_id = "AAA", ts_utc = ts, close = 1, stringsAsFactors = FALSE),
    cash = 1000,
    equity = 1000
  )

  scalar <- ledgr_signal_strategy(function(ctx) "LONG", long_qty = 5)
  testthat::expect_identical(scalar(one_ctx), c(AAA = 5))

  multi_ctx <- ledgr:::ledgr_pulse_context(
    run_id = "run-2",
    ts_utc = ts,
    universe = c("AAA", "BBB"),
    bars = data.frame(
      instrument_id = c("AAA", "BBB"),
      ts_utc = c(ts, ts),
      close = c(1, 2),
      stringsAsFactors = FALSE
    ),
    cash = 1000,
    equity = 1000
  )

  vectorized <- ledgr_signal_strategy(
    function(ctx) c(AAA = "LONG", BBB = "FLAT"),
    long_qty = 2,
    flat_qty = 0
  )
  targets <- vectorized(multi_ctx)
  testthat::expect_identical(targets, c(AAA = 2, BBB = 0))
  testthat::expect_error(
    ledgr:::ledgr_validate_strategy_targets(targets, c("AAA", "BBB")),
    NA
  )
})

testthat::test_that("ledgr_signal_strategy fails loud on ambiguous or unknown signals", {
  ts <- "2020-01-02T00:00:00Z"
  ctx <- ledgr:::ledgr_pulse_context(
    run_id = "run-1",
    ts_utc = ts,
    universe = c("AAA", "BBB"),
    bars = data.frame(
      instrument_id = c("AAA", "BBB"),
      ts_utc = c(ts, ts),
      close = c(1, 2),
      stringsAsFactors = FALSE
    ),
    cash = 1000,
    equity = 1000
  )

  ambiguous <- ledgr_signal_strategy(function(ctx) "LONG")
  testthat::expect_error(
    ambiguous(ctx),
    "multi-instrument",
    class = "ledgr_invalid_strategy_result"
  )

  unknown <- ledgr_signal_strategy(function(ctx) c(AAA = "BUY", BBB = "FLAT"))
  testthat::expect_error(
    unknown(ctx),
    "Unknown signal",
    class = "ledgr_invalid_strategy_result"
  )
})

testthat::test_that("ledgr_signal_strategy runs through the data-first backtest path", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  bars <- ledgr_test_make_bars(
    instrument_ids = c("AAA", "BBB"),
    ts_utc = c("2020-01-01", "2020-01-02", "2020-01-03", "2020-01-06")
  )

  wrapped <- ledgr_signal_strategy(
    function(ctx) stats::setNames(rep("LONG", length(ctx$universe)), ctx$universe),
    long_qty = 1
  )

  bt <- ledgr_backtest(
    data = bars,
    strategy = wrapped,
    start = "2020-01-01",
    end = "2020-01-03",
    db_path = db_path
  )

  fills <- ledgr_extract_fills(bt)
  testthat::expect_s3_class(fills, "tbl_df")
  testthat::expect_true(nrow(fills) > 0)
  testthat::expect_true(all(fills$qty == 1))
})
