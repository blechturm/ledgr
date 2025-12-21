test_that("ledgr_snapshot_from_df creates a sealed snapshot", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snap <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  expect_s3_class(snap, "ledgr_snapshot")
  expect_true(file.exists(snap$db_path))
  expect_equal(snap$metadata$n_bars, 732L)
  expect_equal(snap$metadata$n_instruments, 2L)
  expect_equal(snap$metadata$start_date, "2020-01-01T00:00:00Z")
  expect_equal(snap$metadata$end_date, "2020-12-31T00:00:00Z")

  con <- ledgr_db_init(snap$db_path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  info <- ledgr_snapshot_info(con, snap$snapshot_id)
  meta <- jsonlite::fromJSON(info$meta_json[[1]], simplifyVector = TRUE)
  expect_equal(meta$data_hash, snap$metadata$data_hash)
})

test_that("ledgr_snapshot_from_df validates required columns", {
  bad <- test_bars
  bad$close <- NULL
  expect_error(ledgr_snapshot_from_df(bad), "bars_df missing required column")
})

test_that("ledgr_snapshot_from_df validates snapshot_id format", {
  expect_error(
    ledgr_snapshot_from_df(test_bars, snapshot_id = "bad_id"),
    "snapshot_YYYYmmdd_HHMMSS_XXXX"
  )
})

test_that("ledgr_snapshot_from_csv delegates to df adapter", {
  csv_path <- tempfile(fileext = ".csv")
  on.exit(unlink(csv_path), add = TRUE)
  utils::write.csv(test_bars, csv_path, row.names = FALSE)

  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snap <- ledgr_snapshot_from_csv(csv_path, db_path = db_path)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  expect_s3_class(snap, "ledgr_snapshot")
  expect_true(file.exists(snap$db_path))
})

test_that("ledgr_snapshot_from_yahoo works offline with CSV fixture", {
  skip_if_not_installed("quantmod")

  fixture_path <- system.file("testdata", "yahoo_mock.csv", package = "ledgr")
  if (!nzchar(fixture_path)) {
    skip("Yahoo mock fixture not found.")
  }

  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snap <- ledgr_snapshot_from_yahoo(
    symbols = "yahoo_mock",
    from = "2020-01-01",
    to = "2020-01-05",
    db_path = db_path,
    src = "csv",
    dir = dirname(fixture_path)
  )
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  expect_s3_class(snap, "ledgr_snapshot")
  expect_equal(snap$metadata$n_bars, 5L)
  expect_equal(snap$metadata$n_instruments, 1L)
})

test_that("ledgr_yahoo_extract_bars uses named columns", {
  skip_if_not_installed("xts")

  dates <- as.Date(c("2020-01-01", "2020-01-02"))
  x <- xts::xts(
    x = cbind(
      AAPL.Open = c(100, 101),
      AAPL.High = c(102, 103),
      AAPL.Low = c(99, 100),
      AAPL.Close = c(101, 102),
      AAPL.Volume = c(1000, 1100),
      AAPL.Adjusted = c(101, 102)
    ),
    order.by = dates
  )

  out <- ledgr:::ledgr_yahoo_extract_bars(x, "AAPL")
  expect_equal(nrow(out), 2)
  expect_equal(out$instrument_id[[1]], "AAPL")
  expect_equal(out$ts_utc[[1]], "2020-01-01T00:00:00Z")
})

test_that("ledgr_snapshot_from_yahoo requires quantmod", {
  if (requireNamespace("quantmod", quietly = TRUE)) {
    skip("quantmod installed; missing-package path not exercised")
  }
  expect_error(
    ledgr_snapshot_from_yahoo(symbols = "AAPL", from = "2020-01-01", to = "2020-01-02"),
    "quantmod package required"
  )
})
