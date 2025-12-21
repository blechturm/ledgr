test_that("ledgr_snapshot opens and closes connections lazily", {
  test_con <- get_test_connection()
  on.exit(close_test_connection(test_con), add = TRUE)

  DBI::dbAppendTable(
    test_con$con,
    "snapshot_bars",
    data.frame(
      snapshot_id = "snap_1",
      instrument_id = "TEST_A",
      ts_utc = as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
      open = 100,
      high = 101,
      low = 99,
      close = 100.5,
      volume = 1000,
      stringsAsFactors = FALSE
    )
  )

  close_test_connection(test_con)

  snap <- ledgr:::new_ledgr_snapshot(
    db_path = test_con$db_path,
    snapshot_id = "snap_1",
    metadata = list(
      n_bars = 1L,
      n_instruments = 1L,
      start_date = "2020-01-01T00:00:00Z",
      end_date = "2020-01-01T00:00:00Z"
    )
  )

  expect_true(is.null(snap$.state$con))

  con1 <- ledgr:::get_connection(snap)
  expect_true(DBI::dbIsValid(con1))

  ledgr_snapshot_close(snap)
  expect_false(DBI::dbIsValid(con1))

  con2 <- ledgr:::get_connection(snap)
  expect_true(DBI::dbIsValid(con2))

  ledgr_snapshot_close(snap)
})

test_that("ledgr_snapshot print and summary produce output", {
  test_con <- get_test_connection()
  on.exit(close_test_connection(test_con), add = TRUE)

  DBI::dbAppendTable(
    test_con$con,
    "snapshot_bars",
    data.frame(
      snapshot_id = "snap_2",
      instrument_id = "TEST_A",
      ts_utc = as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
      open = 100,
      high = 101,
      low = 99,
      close = 100.5,
      volume = 1000,
      stringsAsFactors = FALSE
    )
  )

  close_test_connection(test_con)

  snap <- ledgr:::new_ledgr_snapshot(
    db_path = test_con$db_path,
    snapshot_id = "snap_2",
    metadata = list(
      n_bars = 1L,
      n_instruments = 1L,
      start_date = "2020-01-01T00:00:00Z",
      end_date = "2020-01-01T00:00:00Z"
    )
  )

  output <- capture.output(print(snap))
  expect_true(any(grepl("ledgr_snapshot", output)))

  summary_out <- capture.output(summary(snap))
  expect_true(any(grepl("Per-Instrument Summary", summary_out)))
})
