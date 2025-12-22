testthat::test_that("ledgr_extract_fills returns handle when above threshold", {
  test_con <- get_test_connection()
  on.exit(close_test_connection(test_con), add = TRUE)

  run_id <- "run_streaming_handle"
  n <- 6
  rows <- data.frame(
    event_id = sprintf("ev_stream_%02d", seq_len(n)),
    run_id = run_id,
    ts_utc = as.POSIXct("2020-01-01T00:00:00Z", tz = "UTC") + seq_len(n),
    event_type = rep("FILL", n),
    instrument_id = rep("TEST_A", n),
    side = rep("BUY", n),
    qty = rep(1, n),
    price = rep(100, n),
    fee = rep(0, n),
    meta_json = rep(NA_character_, n),
    event_seq = seq_len(n),
    stringsAsFactors = FALSE
  )
  DBI::dbAppendTable(test_con$con, "ledger_events", rows)

  bt <- ledgr:::new_ledgr_backtest(
    run_id = run_id,
    db_path = test_con$db_path,
    config = list(data = list(snapshot_id = "snap_streaming"))
  )

  res <- ledgr:::ledgr_extract_fills(bt, stream_threshold = 1L)
  on.exit(ledgr:::ledgr_fills_close(res), add = TRUE)
  testthat::expect_true(inherits(res, "DBIResult"))
})
