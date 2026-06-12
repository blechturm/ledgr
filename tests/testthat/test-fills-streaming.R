testthat::test_that("ledgr_run_fills returns handle when above threshold", {
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

  res <- ledgr:::ledgr_run_fills(bt, stream_threshold = 1L)
  on.exit(ledgr:::ledgr_fills_close(res), add = TRUE)
  testthat::expect_true(inherits(res, "ledgr_fills_cursor"))
})

testthat::test_that("borrowed fill extraction stays eager above threshold", {
  test_con <- get_test_connection()
  on.exit(close_test_connection(test_con), add = TRUE)

  run_id <- "run_streaming_borrowed_eager"
  n <- 6L
  rows <- data.frame(
    event_id = sprintf("ev_borrowed_%02d", seq_len(n)),
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
    config = list(data = list(snapshot_id = "snap_streaming_borrowed"))
  )

  res <- ledgr:::ledgr_extract_fills_impl(bt, con = test_con$con, stream_threshold = 1L)
  testthat::expect_false(inherits(res, "ledgr_fills_cursor"))
  testthat::expect_s3_class(res, "tbl_df")
  testthat::expect_identical(nrow(res), n)
  testthat::expect_identical(res$event_seq, seq_len(n))

  requested_lazy <- ledgr:::ledgr_extract_fills_impl(
    bt,
    lazy = TRUE,
    con = test_con$con,
    stream_threshold = 1L
  )
  testthat::expect_false(inherits(requested_lazy, "ledgr_fills_cursor"))
  testthat::expect_identical(nrow(requested_lazy), n)
})

testthat::test_that("fill row buffer preserves full schema across growth", {
  ts <- as.POSIXct("2020-01-01T00:00:00Z", tz = "UTC") + c(1, 2, 3)
  buffer <- ledgr:::ledgr_fill_row_buffer(1L)

  ledgr:::ledgr_fill_row_buffer_add(
    buffer, 1L, ts[[1]], "AAA", "BUY", 10, 100.5, 0.25, 0, "OPEN"
  )
  ledgr:::ledgr_fill_row_buffer_add(
    buffer, 2L, ts[[2]], "AAA", "SELL", 4, 101.25, 0, 3, "CLOSE"
  )
  ledgr:::ledgr_fill_row_buffer_add(
    buffer, 3L, ts[[3]], "BBB", "BAD", NA_real_, NA_real_, NA_real_,
    NA_real_, NA_character_
  )

  out <- ledgr:::ledgr_fill_row_buffer_data_frame(buffer)
  expected <- data.frame(
    event_seq = as.integer(c(1, 2, 3)),
    ts_utc = ts,
    instrument_id = c("AAA", "AAA", "BBB"),
    side = c("BUY", "SELL", "BAD"),
    qty = c(10, 4, NA_real_),
    price = c(100.5, 101.25, NA_real_),
    fee = c(0.25, 0, NA_real_),
    realized_pnl = c(0, 3, NA_real_),
    action = c("OPEN", "CLOSE", NA_character_),
    stringsAsFactors = FALSE
  )

  testthat::expect_identical(names(out), names(expected))
  testthat::expect_identical(out$event_seq, expected$event_seq)
  testthat::expect_identical(out$ts_utc, expected$ts_utc)
  testthat::expect_identical(out$instrument_id, expected$instrument_id)
  testthat::expect_identical(out$side, expected$side)
  testthat::expect_equal(out$qty, expected$qty)
  testthat::expect_equal(out$price, expected$price)
  testthat::expect_equal(out$fee, expected$fee)
  testthat::expect_equal(out$realized_pnl, expected$realized_pnl)
  testthat::expect_identical(out$action, expected$action)
})

testthat::test_that("materialized and lazy fill extraction return identical rows", {
  test_con <- get_test_connection()
  on.exit(close_test_connection(test_con), add = TRUE)

  run_id <- "run_streaming_materialized_parity"
  base_ts <- as.POSIXct("2020-01-01T00:00:00Z", tz = "UTC")
  rows <- data.frame(
    event_id = sprintf("ev_stream_parity_%02d", 1:6),
    run_id = run_id,
    ts_utc = base_ts + seq_len(6),
    event_type = rep("FILL", 6),
    instrument_id = c("AAA", "AAA", "AAA", "BBB", "BBB", "BBB"),
    side = c("BUY", "SELL", "BUY", "BUY", "SELL", "BUY"),
    qty = c(10, 4, 3, 2, 1, 4),
    price = c(100, 110, 105, 50, 55, 53),
    fee = c(0, 0.5, 0, 0, 0.25, 0),
    meta_json = rep(NA_character_, 6),
    event_seq = seq_len(6),
    stringsAsFactors = FALSE
  )
  DBI::dbAppendTable(test_con$con, "ledger_events", rows)

  bt <- ledgr:::new_ledgr_backtest(
    run_id = run_id,
    db_path = test_con$db_path,
    config = list(data = list(snapshot_id = "snap_streaming_parity"))
  )

  materialized <- ledgr:::ledgr_run_fills(bt, stream_threshold = 100000L)
  cursor <- ledgr:::ledgr_run_fills(bt, stream_threshold = 1L)
  on.exit(ledgr:::ledgr_fills_close(cursor), add = TRUE)
  lazy <- tibble::as_tibble(DBI::dbFetch(cursor$res))

  testthat::expect_identical(names(lazy), names(materialized))
  testthat::expect_identical(nrow(lazy), nrow(materialized))
  testthat::expect_identical(lazy$event_seq, materialized$event_seq)
  testthat::expect_equal(lazy$ts_utc, materialized$ts_utc)
  testthat::expect_identical(lazy$instrument_id, materialized$instrument_id)
  testthat::expect_identical(lazy$side, materialized$side)
  testthat::expect_equal(lazy$qty, materialized$qty)
  testthat::expect_equal(lazy$price, materialized$price)
  testthat::expect_equal(lazy$fee, materialized$fee)
  testthat::expect_equal(lazy$realized_pnl, materialized$realized_pnl)
  testthat::expect_identical(lazy$action, materialized$action)
})

testthat::test_that("fill extraction stays correct above a non-trivial stream threshold", {
  test_con <- get_test_connection()
  on.exit(close_test_connection(test_con), add = TRUE)

  run_id <- "run_streaming_threshold_parity"
  n <- 220L
  base_ts <- as.POSIXct("2020-01-01T00:00:00Z", tz = "UTC")
  rows <- data.frame(
    event_id = sprintf("ev_threshold_%03d", seq_len(n)),
    run_id = run_id,
    ts_utc = base_ts + seq_len(n),
    event_type = rep("FILL", n),
    instrument_id = rep(c("AAA", "BBB"), length.out = n),
    side = rep(c("BUY", "SELL"), length.out = n),
    qty = rep(1, n),
    price = 100 + seq_len(n) * 0.01,
    fee = rep(0, n),
    meta_json = rep(NA_character_, n),
    event_seq = seq_len(n),
    stringsAsFactors = FALSE
  )
  DBI::dbAppendTable(test_con$con, "ledger_events", rows)

  bt <- ledgr:::new_ledgr_backtest(
    run_id = run_id,
    db_path = test_con$db_path,
    config = list(data = list(snapshot_id = "snap_streaming_threshold"))
  )

  materialized <- ledgr:::ledgr_run_fills(bt, stream_threshold = 100000L)
  cursor <- ledgr:::ledgr_run_fills(bt, stream_threshold = 100L)
  on.exit(ledgr:::ledgr_fills_close(cursor), add = TRUE)
  lazy <- tibble::as_tibble(DBI::dbFetch(cursor$res))

  testthat::expect_true(inherits(cursor, "ledgr_fills_cursor"))
  testthat::expect_identical(nrow(lazy), nrow(materialized))
  testthat::expect_identical(lazy$event_seq, materialized$event_seq)
  testthat::expect_equal(lazy$ts_utc, materialized$ts_utc)
  testthat::expect_identical(lazy$instrument_id, materialized$instrument_id)
  testthat::expect_identical(lazy$side, materialized$side)
  testthat::expect_equal(lazy$qty, materialized$qty)
  testthat::expect_equal(lazy$price, materialized$price)
  testthat::expect_equal(lazy$fee, materialized$fee)
  testthat::expect_equal(lazy$realized_pnl, materialized$realized_pnl)
  testthat::expect_identical(lazy$action, materialized$action)
})
