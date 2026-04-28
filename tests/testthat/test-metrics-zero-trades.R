testthat::test_that("metrics handle zero-trade backtests", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snap <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  zero_strategy <- function(ctx, params) {
    stats::setNames(rep(0, length(ctx$universe)), ctx$universe)
  }

  bt <- ledgr_backtest(
    snapshot = snap,
    strategy = zero_strategy,
    universe = c("TEST_A", "TEST_B"),
    start = "2020-01-01",
    end = "2020-01-10",
    initial_cash = 1000
  )

  fills <- ledgr:::ledgr_extract_fills(bt)
  testthat::expect_equal(nrow(fills), 0L)

  metrics <- ledgr:::ledgr_compute_metrics(bt)
  testthat::expect_equal(metrics$n_trades, 0L)
  testthat::expect_true(is.na(metrics$win_rate))
  testthat::expect_true(is.na(metrics$avg_trade))
  testthat::expect_true(is.finite(metrics$total_return))
})
