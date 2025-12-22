testthat::test_that("ledgr_backtest is equivalent to ledgr_run for functional strategies", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snap <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  universe <- c("TEST_A", "TEST_B")
  config <- ledgr:::ledgr_config(
    snapshot = snap,
    universe = universe,
    strategy = test_strategy,
    backtest = ledgr:::ledgr_backtest_config(start = "2020-01-01", end = "2020-12-31", initial_cash = 100000),
    db_path = db_path
  )
  result_direct <- ledgr:::ledgr_run(config)

  result_wrapper <- ledgr_backtest(
    snapshot = snap,
    strategy = test_strategy,
    universe = universe,
    start = "2020-01-01",
    end = "2020-12-31",
    initial_cash = 100000,
    db_path = db_path
  )

  con <- ledgr:::get_connection(snap)
  events1 <- get_ledger_events(con, result_direct$run_id)
  events2 <- get_ledger_events(con, result_wrapper$run_id)

  compare_cols <- c("event_seq", "ts_utc", "event_type", "instrument_id", "side", "qty", "price", "fee", "meta_json")
  testthat::expect_equal(nrow(events1), nrow(events2))
  testthat::expect_identical(events1[, compare_cols], events2[, compare_cols])

  eq1 <- get_final_equity(con, result_direct$run_id)
  eq2 <- get_final_equity(con, result_wrapper$run_id)
  testthat::expect_equal(eq1, eq2, tolerance = 1e-10)
})
