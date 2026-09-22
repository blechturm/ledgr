make_csv_file <- function(lines, bom = FALSE) {
  path <- tempfile(fileext = ".csv")
  if (isTRUE(bom)) {
    lines[[1]] <- paste0("﻿", lines[[1]])
  }
  writeLines(lines, path, useBytes = TRUE)
  path
}

seal_from_csv <- function(lines, bom = FALSE) {
  ledgr_snapshot_from_csv(make_csv_file(lines, bom = bom))
}

read_bars <- function(snap, cols = "open, high, low, close, volume") {
  con <- ledgr_db_init(snap$db_path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbGetQuery(
    con,
    sprintf(
      "SELECT %s FROM snapshot_bars WHERE snapshot_id = ? ORDER BY instrument_id, ts_utc",
      cols
    ),
    params = list(snap$snapshot_id)
  )
}

testthat::test_that("bars CSV rounds OHLCV to 8 decimals", {
  snap <- seal_from_csv(c(
    "instrument_id,ts_utc,open,high,low,close,volume",
    "AAA,2020-01-01T00:00:00Z,1.000000001,1.000000009,1.000000001,1.000000005,10.000000009"
  ))
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  row <- read_bars(snap)
  testthat::expect_equal(nrow(row), 1L)
  testthat::expect_equal(as.numeric(row$open[[1]]), round(1.000000001, 8), tolerance = 1e-12)
  testthat::expect_equal(as.numeric(row$high[[1]]), round(1.000000009, 8), tolerance = 1e-12)
  testthat::expect_equal(as.numeric(row$close[[1]]), round(1.000000005, 8), tolerance = 1e-12)
  testthat::expect_equal(as.numeric(row$volume[[1]]), round(10.000000009, 8), tolerance = 1e-12)
})

testthat::test_that("bars CSV missing required column fails", {
  bars_csv <- make_csv_file(c(
    "instrument_id,ts_utc,open,high,low", # close missing
    "AAA,2020-01-01T00:00:00Z,1,1,1"
  ))

  testthat::expect_error(
    ledgr_snapshot_from_csv(bars_csv),
    "missing required column",
    class = "ledgr_invalid_args"
  )
})

# Changed contract, newly added evidence. The removed strict importer rejected a
# timestamp without a trailing Z; the kept surface accepts that form by design
# and normalizes it. LDG-2789 owns the full branch matrix; this block pins the
# contract change at the point where it was made.
testthat::test_that("a timestamp without a trailing Z is accepted and normalized", {
  snap <- seal_from_csv(c(
    "instrument_id,ts_utc,open,high,low,close",
    "AAA,2020-01-01T00:00:00,1,1,1,1",
    "AAA,2020-01-02T00:00:00,1,1,1,1"
  ))
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  testthat::expect_identical(snap$metadata$start_date, "2020-01-01T00:00:00Z")
  testthat::expect_identical(snap$metadata$end_date, "2020-01-02T00:00:00Z")
  testthat::expect_equal(nrow(read_bars(snap)), 2L)
})

testthat::test_that("OHLC violation fails", {
  bars_csv <- make_csv_file(c(
    "instrument_id,ts_utc,open,high,low,close",
    "AAA,2020-01-01T00:00:00Z,10,5,9,10"
  ))

  testthat::expect_error(
    ledgr_snapshot_from_csv(bars_csv),
    "OHLC violation",
    class = "ledgr_invalid_args"
  )
})

testthat::test_that("instruments are generated from the bars", {
  snap <- seal_from_csv(c(
    "instrument_id,ts_utc,open,high,low,close",
    "AAA,2020-01-01T00:00:00Z,1,1,1,1",
    "BBB,2020-01-01T00:00:00Z,2,2,2,2"
  ))
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  testthat::expect_equal(snap$metadata$n_instruments, 2L)

  con <- ledgr_db_init(snap$db_path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  n <- DBI::dbGetQuery(
    con,
    "SELECT COUNT(*) AS n FROM snapshot_instruments WHERE snapshot_id = ?",
    params = list(snap$snapshot_id)
  )$n[[1]]
  testthat::expect_equal(n, 2L)
})

testthat::test_that("UTF-8 BOM in bars CSV header is tolerated", {
  snap <- seal_from_csv(
    c(
      "instrument_id,ts_utc,open,high,low,close",
      "AAA,2020-01-01T00:00:00Z,1,1,1,1"
    ),
    bom = TRUE
  )
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  testthat::expect_equal(nrow(read_bars(snap, cols = "instrument_id")), 1L)
})

# Newly added evidence, not a migrated witness. The removed strict importer held
# a duplicate-key check of its own; the kept surface holds the same contract and
# nothing tested it here before.
#
# The message is pinned to the adapter's own check, not to any message
# containing "duplicate". The snapshot_bars primary key rejects the same rows
# one layer down, and the adapter reports that as "duplicate PKs" with the same
# condition class, so a loose match would pass with the adapter check deleted.
testthat::test_that("duplicate instrument and timestamp rows fail", {
  bars_csv <- make_csv_file(c(
    "instrument_id,ts_utc,open,high,low,close",
    "AAA,2020-01-01T00:00:00Z,1,1,1,1",
    "AAA,2020-01-01T00:00:00Z,1,1,1,1"
  ))

  testthat::expect_error(
    ledgr_snapshot_from_csv(bars_csv),
    "bars_df contains duplicate (instrument_id, ts_utc) rows",
    fixed = TRUE,
    class = "ledgr_invalid_args"
  )
})
