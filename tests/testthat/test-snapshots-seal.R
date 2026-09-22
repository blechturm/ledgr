make_snapshot_with_data_seal <- function(con, snapshot_id) {
  ledgr_create_schema(con)
  ledgr_snapshot_create(con, snapshot_id = snapshot_id, meta = list())

  instruments <- data.frame(
    instrument_id = c("AAA", "BBB"),
    symbol = c("AAA", "BBB"),
    currency = "USD",
    asset_class = "EQUITY",
    multiplier = 1,
    tick_size = 0.01,
    stringsAsFactors = FALSE
  )

  bars <- data.frame(
    instrument_id = c("BBB", "AAA"),
    ts_utc = "2020-01-01T00:00:00Z",
    open = c(10, 1),
    high = c(11, 1.1),
    low = c(9, 0.9),
    close = c(10.5, 1.05),
    volume = c(100, 200),
    stringsAsFactors = FALSE
  )

  ledgr_test_fill_snapshot(con, snapshot_id, bars, instruments)

  invisible(TRUE)
}

testthat::test_that("successful seal flips status and stores hash + sealed_at_utc", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  snapshot_id <- "snapshot_20250101_000000_abcd"
  make_snapshot_with_data_seal(con, snapshot_id)

  expected_hash <- ledgr:::ledgr_snapshot_hash(con, snapshot_id, chunk_size = 1)
  got_hash <- ledgr_snapshot_seal(con, snapshot_id)

  testthat::expect_equal(got_hash, expected_hash)

  row <- DBI::dbGetQuery(
    con,
    "SELECT status, sealed_at_utc, snapshot_hash, error_msg FROM snapshots WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )
  testthat::expect_equal(row$status[[1]], "SEALED")
  testthat::expect_false(is.na(row$sealed_at_utc[[1]]))
  testthat::expect_equal(row$snapshot_hash[[1]], expected_hash)
  testthat::expect_true(is.na(row$error_msg[[1]]))
})

testthat::test_that("sealing twice returns stored hash and does not change it", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  snapshot_id <- "snapshot_20250101_000000_abcd"
  make_snapshot_with_data_seal(con, snapshot_id)

  h1 <- ledgr_snapshot_seal(con, snapshot_id)
  h_again <- ledgr_snapshot_seal(con, snapshot_id)
  testthat::expect_equal(h_again, h1)

  h2 <- DBI::dbGetQuery(
    con,
    "SELECT snapshot_hash FROM snapshots WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )$snapshot_hash[[1]]
  testthat::expect_equal(h1, h2)
})

testthat::test_that("empty snapshot cannot be sealed", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  snapshot_id <- ledgr_snapshot_create(con, snapshot_id = "snapshot_20250101_000000_abcd", meta = list())

  testthat::expect_error(ledgr_snapshot_seal(con, snapshot_id), class = "LEDGR_SNAPSHOT_EMPTY")

  row <- DBI::dbGetQuery(
    con,
    "SELECT status, sealed_at_utc, snapshot_hash FROM snapshots WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )
  testthat::expect_equal(row$status[[1]], "CREATED")
  testthat::expect_true(is.na(row$sealed_at_utc[[1]]))
  testthat::expect_true(is.na(row$snapshot_hash[[1]]))
})

testthat::test_that("seal rejects bars that reference missing snapshot instruments", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  snapshot_id <- "snapshot_20250101_000000_abcd"
  make_snapshot_with_data_seal(con, snapshot_id)

  DBI::dbAppendTable(
    con,
    "snapshot_bars",
    data.frame(
      snapshot_id = snapshot_id,
      instrument_id = "ZZZ",
      ts_utc = as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
      open = 1,
      high = 1,
      low = 1,
      close = 1,
      volume = 1,
      stringsAsFactors = FALSE
    )
  )

  testthat::expect_error(
    ledgr_snapshot_seal(con, snapshot_id),
    class = "LEDGR_SNAPSHOT_REFERENTIAL_INTEGRITY"
  )

  row <- DBI::dbGetQuery(
    con,
    "SELECT status, sealed_at_utc, snapshot_hash, error_msg FROM snapshots WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )
  testthat::expect_equal(row$status[[1]], "CREATED")
  testthat::expect_true(is.na(row$sealed_at_utc[[1]]))
  testthat::expect_true(is.na(row$snapshot_hash[[1]]))
  testthat::expect_true(is.na(row$error_msg[[1]]))
})

testthat::test_that("seal rejects sub-second snapshot bar timestamps", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  snapshot_id <- "snapshot_20250101_000000_abcd"
  make_snapshot_with_data_seal(con, snapshot_id)

  DBI::dbExecute(
    con,
    "
    UPDATE snapshot_bars
    SET ts_utc = CAST('2020-01-01 00:00:00.250' AS TIMESTAMP)
    WHERE snapshot_id = ? AND instrument_id = 'AAA'
    ",
    params = list(snapshot_id)
  )

  testthat::expect_error(
    ledgr_snapshot_seal(con, snapshot_id),
    class = "LEDGR_SNAPSHOT_SUBSECOND_TS"
  )

  row <- DBI::dbGetQuery(
    con,
    "SELECT status, sealed_at_utc, snapshot_hash, error_msg FROM snapshots WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )
  testthat::expect_equal(row$status[[1]], "CREATED")
  testthat::expect_true(is.na(row$sealed_at_utc[[1]]))
  testthat::expect_true(is.na(row$snapshot_hash[[1]]))
  testthat::expect_true(is.na(row$error_msg[[1]]))
})

testthat::test_that("seal rejects invalid OHLC rows without marking snapshot FAILED", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  snapshot_id <- "snapshot_20250101_000000_abcd"
  make_snapshot_with_data_seal(con, snapshot_id)

  DBI::dbExecute(
    con,
    "
    UPDATE snapshot_bars
    SET high = low - 1
    WHERE snapshot_id = ? AND instrument_id = 'AAA'
    ",
    params = list(snapshot_id)
  )

  testthat::expect_error(
    ledgr_snapshot_seal(con, snapshot_id),
    class = "LEDGR_SNAPSHOT_OHLC_INVALID"
  )

  row <- DBI::dbGetQuery(
    con,
    "SELECT status, sealed_at_utc, snapshot_hash, error_msg FROM snapshots WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )
  testthat::expect_equal(row$status[[1]], "CREATED")
  testthat::expect_true(is.na(row$sealed_at_utc[[1]]))
  testthat::expect_true(is.na(row$snapshot_hash[[1]]))
  testthat::expect_true(is.na(row$error_msg[[1]]))
})

testthat::test_that("seal rejects low values above the OHLC bounds", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  snapshot_id <- "snapshot_20250101_000000_abcd"
  make_snapshot_with_data_seal(con, snapshot_id)

  DBI::dbExecute(
    con,
    "
    UPDATE snapshot_bars
    SET low = high + 1
    WHERE snapshot_id = ? AND instrument_id = 'BBB'
    ",
    params = list(snapshot_id)
  )

  testthat::expect_error(
    ledgr_snapshot_seal(con, snapshot_id),
    class = "LEDGR_SNAPSHOT_OHLC_INVALID"
  )
})

testthat::test_that("hashing error during seal marks snapshot FAILED with no partial seal", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  snapshot_id <- "snapshot_20250101_000000_abcd"
  make_snapshot_with_data_seal(con, snapshot_id)

  ns <- asNamespace("ledgr")
  original <- get("ledgr_snapshot_hash", envir = ns, inherits = FALSE)
  unlockBinding("ledgr_snapshot_hash", ns)
  assign(
    "ledgr_snapshot_hash",
    function(...) rlang::abort("forced hash failure", class = "ledgr_test_forced_error"),
    envir = ns
  )
  lockBinding("ledgr_snapshot_hash", ns)
  on.exit(
    {
      unlockBinding("ledgr_snapshot_hash", ns)
      assign("ledgr_snapshot_hash", original, envir = ns)
      lockBinding("ledgr_snapshot_hash", ns)
    },
    add = TRUE
  )

  testthat::expect_error(ledgr_snapshot_seal(con, snapshot_id), class = "LEDGR_SNAPSHOT_SEAL_FAILED")

  row <- DBI::dbGetQuery(
    con,
    "SELECT status, sealed_at_utc, snapshot_hash, error_msg FROM snapshots WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )
  testthat::expect_equal(row$status[[1]], "FAILED")
  testthat::expect_true(is.na(row$sealed_at_utc[[1]]))
  testthat::expect_true(is.na(row$snapshot_hash[[1]]))
  testthat::expect_true(is.character(row$error_msg[[1]]) && nzchar(row$error_msg[[1]]))
})
