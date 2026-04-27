testthat::test_that("snapshot_load reopens an existing sealed snapshot", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  bars <- data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:2,
    instrument_id = "AAA",
    open = c(100, 101, 102),
    high = c(101, 102, 103),
    low = c(99, 100, 101),
    close = c(100, 101, 102),
    volume = 1000
  )

  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  snapshot_id <- snapshot$snapshot_id
  ledgr_snapshot_close(snapshot)

  loaded <- ledgr_snapshot_load(db_path, snapshot_id, verify = TRUE)
  on.exit(ledgr_snapshot_close(loaded), add = TRUE)

  testthat::expect_s3_class(loaded, "ledgr_snapshot")
  testthat::expect_identical(loaded$db_path, db_path)
  testthat::expect_identical(loaded$snapshot_id, snapshot_id)
  info <- ledgr_snapshot_info(loaded)
  testthat::expect_identical(info$status[[1]], "SEALED")
})

testthat::test_that("snapshot_load refuses missing and unsealed snapshots", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  testthat::expect_error(
    ledgr_snapshot_load(db_path, "snapshot_20250101_000000_abcd"),
    class = "LEDGR_SNAPSHOT_DB_NOT_FOUND"
  )

  con <- ledgr_db_init(db_path)
  on.exit(if (DBI::dbIsValid(con)) DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  snapshot_id <- "snapshot_20250101_000000_abcd"
  ledgr_snapshot_create(con, snapshot_id = snapshot_id, meta = list())
  DBI::dbDisconnect(con, shutdown = TRUE)

  testthat::expect_error(
    ledgr_snapshot_load(db_path, snapshot_id),
    class = "LEDGR_SNAPSHOT_NOT_SEALED"
  )
})
