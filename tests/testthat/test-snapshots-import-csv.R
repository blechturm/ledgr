make_csv_file <- function(lines, bom = FALSE) {
  path <- tempfile(fileext = ".csv")
  if (isTRUE(bom)) {
    lines[[1]] <- paste0("\ufeff", lines[[1]])
  }
  writeLines(lines, path, useBytes = TRUE)
  path
}

testthat::test_that("import instruments CSV into CREATED snapshot succeeds", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  snapshot_id <- ledgr_snapshot_create(con, snapshot_id = "snapshot_20250101_000000_abcd", meta = list())

  csv <- make_csv_file(c(
    "instrument_id,symbol,currency,asset_class,multiplier,tick_size",
    "AAA,AAA,USD,EQUITY,1,0.01",
    "BBB,BBB,USD,EQUITY,1,0.01"
  ))

  testthat::expect_true(isTRUE(ledgr_snapshot_import_instruments_csv(con, snapshot_id, csv)))

  n <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM snapshot_instruments WHERE snapshot_id = ?", params = list(snapshot_id))$n[[1]]
  testthat::expect_equal(n, 2L)
})

testthat::test_that("import bars CSV rounds OHLCV to 8 decimals", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  snapshot_id <- ledgr_snapshot_create(con, snapshot_id = "snapshot_20250101_000000_abcd", meta = list())

  bars_csv <- make_csv_file(c(
    "instrument_id,ts_utc,open,high,low,close,volume",
    "AAA,2020-01-01T00:00:00Z,1.000000001,1.000000009,1.000000001,1.000000005,10.000000009"
  ))

  testthat::expect_true(isTRUE(ledgr_snapshot_import_bars_csv(con, snapshot_id, bars_csv, instruments_csv_path = NULL, auto_generate_instruments = TRUE)))

  row <- DBI::dbGetQuery(
    con,
    "
    SELECT open, high, low, close, volume
    FROM snapshot_bars
    WHERE snapshot_id = ?
    ",
    params = list(snapshot_id)
  )
  testthat::expect_equal(nrow(row), 1L)
  testthat::expect_equal(as.numeric(row$open[[1]]), round(1.000000001, 8), tolerance = 1e-12)
  testthat::expect_equal(as.numeric(row$high[[1]]), round(1.000000009, 8), tolerance = 1e-12)
  testthat::expect_equal(as.numeric(row$close[[1]]), round(1.000000005, 8), tolerance = 1e-12)
  testthat::expect_equal(as.numeric(row$volume[[1]]), round(10.000000009, 8), tolerance = 1e-12)
})

testthat::test_that("import into SEALED snapshot is rejected", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  snapshot_id <- ledgr_snapshot_create(con, snapshot_id = "snapshot_20250101_000000_abcd", meta = list())
  DBI::dbExecute(con, "UPDATE snapshots SET status = 'SEALED' WHERE snapshot_id = ?", params = list(snapshot_id))

  bars_csv <- make_csv_file(c(
    "instrument_id,ts_utc,open,high,low,close",
    "AAA,2020-01-01T00:00:00Z,1,1,1,1"
  ))

  testthat::expect_error(
    ledgr_snapshot_import_bars_csv(con, snapshot_id, bars_csv, instruments_csv_path = NULL, auto_generate_instruments = TRUE),
    class = "LEDGR_SNAPSHOT_NOT_MUTABLE"
  )
})

testthat::test_that("bars CSV missing required column fails", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  snapshot_id <- ledgr_snapshot_create(con, snapshot_id = "snapshot_20250101_000000_abcd", meta = list())

  bars_csv <- make_csv_file(c(
    "instrument_id,ts_utc,open,high,low", # close missing
    "AAA,2020-01-01T00:00:00Z,1,1,1"
  ))

  testthat::expect_error(
    ledgr_snapshot_import_bars_csv(con, snapshot_id, bars_csv, instruments_csv_path = NULL, auto_generate_instruments = TRUE),
    class = "LEDGR_CSV_FORMAT_ERROR"
  )
})

testthat::test_that("bad timestamp (no Z) fails", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  snapshot_id <- ledgr_snapshot_create(con, snapshot_id = "snapshot_20250101_000000_abcd", meta = list())

  bars_csv <- make_csv_file(c(
    "instrument_id,ts_utc,open,high,low,close",
    "AAA,2020-01-01T00:00:00,1,1,1,1"
  ))

  testthat::expect_error(
    ledgr_snapshot_import_bars_csv(con, snapshot_id, bars_csv, instruments_csv_path = NULL, auto_generate_instruments = TRUE),
    class = "LEDGR_CSV_FORMAT_ERROR"
  )
})

testthat::test_that("OHLC violation fails", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  snapshot_id <- ledgr_snapshot_create(con, snapshot_id = "snapshot_20250101_000000_abcd", meta = list())

  bars_csv <- make_csv_file(c(
    "instrument_id,ts_utc,open,high,low,close",
    "AAA,2020-01-01T00:00:00Z,10,5,9,10"
  ))

  testthat::expect_error(
    ledgr_snapshot_import_bars_csv(con, snapshot_id, bars_csv, instruments_csv_path = NULL, auto_generate_instruments = TRUE),
    class = "LEDGR_CSV_FORMAT_ERROR"
  )
})

testthat::test_that("auto-generate instruments from bars works and can be disabled", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  snapshot_id <- ledgr_snapshot_create(con, snapshot_id = "snapshot_20250101_000000_abcd", meta = list())

  bars_csv <- make_csv_file(c(
    "instrument_id,ts_utc,open,high,low,close",
    "AAA,2020-01-01T00:00:00Z,1,1,1,1",
    "BBB,2020-01-01T00:00:00Z,2,2,2,2"
  ))

  testthat::expect_true(isTRUE(ledgr_snapshot_import_bars_csv(con, snapshot_id, bars_csv, instruments_csv_path = NULL, auto_generate_instruments = TRUE)))
  n_inst <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM snapshot_instruments WHERE snapshot_id = ?", params = list(snapshot_id))$n[[1]]
  testthat::expect_equal(n_inst, 2L)

  snapshot_id2 <- ledgr_snapshot_create(con, snapshot_id = "snapshot_20250101_000000_abce", meta = list())
  testthat::expect_error(
    ledgr_snapshot_import_bars_csv(con, snapshot_id2, bars_csv, instruments_csv_path = NULL, auto_generate_instruments = FALSE),
    class = "LEDGR_CSV_FORMAT_ERROR"
  )
})

testthat::test_that("UTF-8 BOM in bars CSV header is tolerated", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  snapshot_id <- ledgr_snapshot_create(con, snapshot_id = "snapshot_20250101_000000_abcd", meta = list())

  bars_csv <- make_csv_file(
    c(
      "instrument_id,ts_utc,open,high,low,close",
      "AAA,2020-01-01T00:00:00Z,1,1,1,1"
    ),
    bom = TRUE
  )

  testthat::expect_true(isTRUE(ledgr_snapshot_import_bars_csv(con, snapshot_id, bars_csv, instruments_csv_path = NULL, auto_generate_instruments = TRUE)))
})

