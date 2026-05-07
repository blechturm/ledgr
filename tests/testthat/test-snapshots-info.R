testthat::test_that("ledgr_snapshot_info returns required columns and counts", {
  db_path <- tempfile(fileext = ".duckdb")
  con <- ledgr_db_init(db_path)
  drv <- attr(con, "ledgr_duckdb_drv")
  on.exit(suppressWarnings(try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE)), add = TRUE)
  on.exit(suppressWarnings(try(duckdb::duckdb_shutdown(drv), silent = TRUE)), add = TRUE)

  snapshot_id <- ledgr_snapshot_create(con, snapshot_id = "snapshot_20250101_000000_abcd", meta = list(a = 1))

  info0 <- ledgr_snapshot_info(con, snapshot_id)
  testthat::expect_s3_class(info0, "tbl_df")
  testthat::expect_equal(
    names(info0),
    c(
      "snapshot_id",
      "status",
      "created_at_utc",
      "sealed_at_utc",
      "snapshot_hash",
      "bar_count",
      "instrument_count",
      "start_date",
      "end_date",
      "meta_json",
      "error_msg"
    )
  )
  testthat::expect_equal(info0$status[[1]], "CREATED")
  testthat::expect_true(grepl("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$", info0$created_at_utc[[1]]))
  testthat::expect_true(is.na(info0$sealed_at_utc[[1]]))
  testthat::expect_true(is.na(info0$snapshot_hash[[1]]))
  testthat::expect_equal(info0$bar_count[[1]], 0L)
  testthat::expect_equal(info0$instrument_count[[1]], 0L)
  testthat::expect_true(is.na(info0$start_date[[1]]))
  testthat::expect_true(is.na(info0$end_date[[1]]))

  instruments_csv <- tempfile(fileext = ".csv")
  writeLines(
    c(
      "instrument_id,symbol,currency,asset_class,multiplier,tick_size",
      "AAA,AAA,USD,EQUITY,1,0.01"
    ),
    instruments_csv,
    useBytes = TRUE
  )
  bars_csv <- tempfile(fileext = ".csv")
  writeLines(
    c(
      "instrument_id,ts_utc,open,high,low,close,volume",
      "AAA,2020-01-01T00:00:00Z,1,1,1,1,1"
    ),
    bars_csv,
    useBytes = TRUE
  )
  ledgr_snapshot_import_bars_csv(
    con,
    snapshot_id,
    bars_csv_path = bars_csv,
    instruments_csv_path = instruments_csv,
    auto_generate_instruments = FALSE,
    validate = "fail_fast"
  )

  ledgr_snapshot_seal(con, snapshot_id)

  info1 <- ledgr_snapshot_info(con, snapshot_id)
  testthat::expect_s3_class(info1, "tbl_df")
  testthat::expect_equal(info1$status[[1]], "SEALED")
  testthat::expect_true(grepl("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$", info1$sealed_at_utc[[1]]))
  testthat::expect_true(is.character(info1$snapshot_hash[[1]]) && nzchar(info1$snapshot_hash[[1]]))
  testthat::expect_equal(info1$bar_count[[1]], 1L)
  testthat::expect_equal(info1$instrument_count[[1]], 1L)
  testthat::expect_equal(info1$start_date[[1]], "2020-01-01T00:00:00Z")
  testthat::expect_equal(info1$end_date[[1]], "2020-01-01T00:00:00Z")
})

testthat::test_that("ledgr_snapshot_info errors with LEDGR_SNAPSHOT_NOT_FOUND", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  testthat::expect_error(
    ledgr_snapshot_info(con, "missing"),
    class = "LEDGR_SNAPSHOT_NOT_FOUND"
  )
})
