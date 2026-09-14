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
      execution_mode = mode,
    cost_model = ledgr_cost_zero()
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

testthat::test_that("reversal fee projection conserves source economics in both directions", {
  test_con <- get_test_connection()
  on.exit(close_test_connection(test_con), add = TRUE)

  run_id <- "run_reversal_fee_projection"
  rows <- data.frame(
    event_id = paste0("reversal_fee_", 1:3),
    run_id = run_id,
    ts_utc = as.POSIXct("2020-01-01T00:00:00Z", tz = "UTC") + 1:3,
    event_type = "FILL",
    instrument_id = "AAA",
    side = c("BUY", "SELL", "BUY"),
    qty = c(4, 10, 9),
    price = c(10, 12, 11),
    fee = c(1, 3, 6),
    meta_json = NA_character_,
    event_seq = 1:3,
    stringsAsFactors = FALSE
  )
  DBI::dbAppendTable(test_con$con, "ledger_events", rows)

  bt <- ledgr:::new_ledgr_backtest(
    run_id = run_id,
    db_path = test_con$db_path,
    config = list(data = list(snapshot_id = "snap_reversal_fee"))
  )
  on.exit(close(bt), add = TRUE)
  fills <- ledgr_run_fills(bt)
  trades <- fills[fills$action == "CLOSE", , drop = FALSE]

  event_2 <- fills[fills$event_seq == 2L, , drop = FALSE]
  event_3 <- fills[fills$event_seq == 3L, , drop = FALSE]
  testthat::expect_identical(event_2$action, c("CLOSE", "OPEN"))
  testthat::expect_identical(event_3$action, c("CLOSE", "OPEN"))
  testthat::expect_equal(event_2$qty, c(4, 6))
  testthat::expect_equal(event_3$qty, c(6, 3))
  testthat::expect_equal(event_2$fee, c(1.2, 1.8), tolerance = 1e-12)
  testthat::expect_equal(event_3$fee, c(4, 2), tolerance = 1e-12)

  projected_fee <- vapply(
    split(fills$fee, fills$event_seq),
    sum,
    numeric(1)
  )
  testthat::expect_equal(unname(projected_fee), rows$fee, tolerance = 1e-12)

  signed_qty <- ifelse(fills$side == "BUY", fills$qty, -fills$qty)
  cash_delta <- ifelse(
    fills$side == "BUY",
    -(fills$qty * fills$price + fills$fee),
    fills$qty * fills$price - fills$fee
  )
  testthat::expect_equal(sum(signed_qty), 3)
  testthat::expect_equal(1000 + sum(cash_delta), 971, tolerance = 1e-12)
  testthat::expect_equal(3 * event_3$price[[2]], 33)
  testthat::expect_equal(trades$realized_pnl, c(8, 6))
  testthat::expect_identical(nrow(trades), 2L)
  testthat::expect_equal(mean(trades$realized_pnl > 0), 1)
  testthat::expect_equal(mean(trades$realized_pnl), 7)
})
