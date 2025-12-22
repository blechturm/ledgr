make_csv_file_seal <- function(lines) {
  path <- tempfile(fileext = ".csv")
  writeLines(lines, path, useBytes = TRUE)
  path
}

make_snapshot_with_data_seal <- function(con, snapshot_id) {
  ledgr_create_schema(con)
  ledgr_snapshot_create(con, snapshot_id = snapshot_id, meta = list())

  instruments_csv <- make_csv_file_seal(c(
    "instrument_id,symbol,currency,asset_class,multiplier,tick_size",
    "AAA,AAA,USD,EQUITY,1,0.01",
    "BBB,BBB,USD,EQUITY,1,0.01"
  ))

  bars_csv <- make_csv_file_seal(c(
    "instrument_id,ts_utc,open,high,low,close,volume",
    "BBB,2020-01-01T00:00:00Z,10,11,9,10.5,100",
    "AAA,2020-01-01T00:00:00Z,1,1.1,0.9,1.05,200"
  ))

  ledgr_snapshot_import_bars_csv(
    con,
    snapshot_id,
    bars_csv_path = bars_csv,
    instruments_csv_path = instruments_csv,
    auto_generate_instruments = FALSE,
    validate = "fail_fast"
  )

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

testthat::test_that("attempted import after sealing is rejected (code-level guard)", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  snapshot_id <- "snapshot_20250101_000000_abcd"
  make_snapshot_with_data_seal(con, snapshot_id)
  ledgr_snapshot_seal(con, snapshot_id)

  before <- DBI::dbGetQuery(
    con,
    "SELECT COUNT(*) AS n FROM snapshot_bars WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )$n[[1]]

  bars_csv <- make_csv_file_seal(c(
    "instrument_id,ts_utc,open,high,low,close",
    "AAA,2020-01-02T00:00:00Z,1,1,1,1"
  ))

  testthat::expect_error(
    ledgr_snapshot_import_bars_csv(con, snapshot_id, bars_csv, instruments_csv_path = NULL, auto_generate_instruments = TRUE),
    class = "LEDGR_SNAPSHOT_NOT_MUTABLE"
  )

  after <- DBI::dbGetQuery(
    con,
    "SELECT COUNT(*) AS n FROM snapshot_bars WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )$n[[1]]
  testthat::expect_equal(after, before)
})
