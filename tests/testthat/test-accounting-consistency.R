testthat::test_that("equity curve state is reconstructed from ledger fills", {
  bars <- data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:5,
    instrument_id = "AAA",
    open = c(100, 101, 102, 103, 104, 105),
    high = c(101, 102, 103, 104, 105, 106),
    low = c(99, 100, 101, 102, 103, 104),
    close = c(100, 101, 102, 103, 104, 105),
    volume = 1000
  )

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- if (ctx$close("AAA") == 100) 1 else 0
    targets
  }

  for (mode in c("audit_log", "db_live")) local({
    bt <- ledgr_backtest(
      data = bars,
      strategy = strategy,
      initial_cash = 1000,
      execution_mode = mode
    )
    on.exit(close(bt))

    fills <- ledgr_results(bt, what = "fills")
    trades <- ledgr_results(bt, what = "trades")
    equity <- ledgr_results(bt, what = "equity")
    metrics <- ledgr_compute_metrics(bt)

    testthat::expect_equal(fills$side, c("BUY", "SELL"), info = mode)
    testthat::expect_equal(fills$qty, c(1, 1), info = mode)
    testthat::expect_equal(fills$price, c(101, 102), info = mode)
    testthat::expect_equal(nrow(trades), 1L, info = mode)
    testthat::expect_equal(trades$realized_pnl[[1]], 1, info = mode)

    signed_qty <- ifelse(fills$side == "BUY", fills$qty, -fills$qty)
    testthat::expect_equal(sum(signed_qty), 0, info = mode)

    final_equity <- equity[nrow(equity), , drop = FALSE]
    testthat::expect_equal(final_equity$cash[[1]], 1001, info = mode)
    testthat::expect_equal(final_equity$positions_value[[1]], 0, info = mode)
    testthat::expect_equal(final_equity$equity[[1]], 1001, info = mode)
    testthat::expect_equal(metrics$total_return, 0.001, tolerance = 1e-12, info = mode)

    close(bt)
  })
})
