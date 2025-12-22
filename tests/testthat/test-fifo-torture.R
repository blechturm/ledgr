testthat::test_that("FIFO lot engine handles stress sequences", {
  test_con <- get_test_connection()
  on.exit(close_test_connection(test_con), add = TRUE)

  run_id <- "run_fifo_torture"
  base_ts <- as.POSIXct("2020-01-01T00:00:00Z", tz = "UTC")

  rows <- data.frame(
    event_id = sprintf("ev_%02d", 1:10),
    run_id = run_id,
    ts_utc = base_ts + seq_len(10),
    event_type = rep("FILL", 10),
    instrument_id = c(
      "SEQ_A", "SEQ_A", "SEQ_A",
      "SEQ_B", "SEQ_B", "SEQ_B", "SEQ_B",
      "BTC", "ETH", "BTC"
    ),
    side = c(
      "BUY", "SELL", "BUY",
      "BUY", "BUY", "BUY", "SELL",
      "BUY", "BUY", "SELL"
    ),
    qty = c(
      100, 250, 150,
      10, 10, 10, 25,
      1, 2, 1
    ),
    price = c(
      10, 12, 11,
      10, 11, 12, 13,
      100, 50, 110
    ),
    fee = rep(0, 10),
    meta_json = rep(NA_character_, 10),
    event_seq = seq_len(10),
    stringsAsFactors = FALSE
  )

  DBI::dbAppendTable(test_con$con, "ledger_events", rows)

  bt <- ledgr:::new_ledgr_backtest(
    run_id = run_id,
    db_path = test_con$db_path,
    config = list(data = list(snapshot_id = "snap_fifo"))
  )

  fills <- ledgr:::ledgr_extract_fills(bt, stream_threshold = 100000L)

  seq_a <- fills[fills$instrument_id == "SEQ_A", , drop = FALSE]
  flip_rows <- seq_a[seq_a$side == "SELL", , drop = FALSE]
  testthat::expect_equal(nrow(flip_rows), 2L)
  testthat::expect_equal(flip_rows$action, c("CLOSE", "OPEN"))
  testthat::expect_equal(flip_rows$realized_pnl, c(200, 0))

  realized_seq_a <- seq_a$realized_pnl
  testthat::expect_equal(realized_seq_a, c(0, 200, 0, 150))

  realized_seq_b <- fills$realized_pnl[fills$instrument_id == "SEQ_B"]
  testthat::expect_equal(realized_seq_b, c(0, 0, 0, 55))

  realized_btc <- fills$realized_pnl[fills$instrument_id == "BTC"]
  realized_eth <- fills$realized_pnl[fills$instrument_id == "ETH"]
  testthat::expect_equal(realized_btc, c(0, 10))
  testthat::expect_equal(realized_eth, 0)
})
