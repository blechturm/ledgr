insert_test_run <- function(con, run_id) {
  DBI::dbExecute(
    con,
    "
    INSERT INTO runs (
      run_id,
      created_at_utc,
      engine_version,
      config_json,
      config_hash,
      data_hash,
      status,
      error_msg
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ",
    params = list(
      run_id,
      as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
      "0.1.0",
      "{}",
      "config-hash",
      "data-hash",
      "CREATED",
      NA_character_
    )
  )
}

parse_meta <- function(x) {
  jsonlite::fromJSON(x, simplifyVector = TRUE)
}

testthat::test_that("BUY fill writes a correct FILL ledger event", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  run_id <- "run-ledger-1"
  insert_test_run(con, run_id)

  fill <- ledgr:::ledgr_fill_next_open(
    desired_qty_delta = 2,
    next_bar = list(instrument_id = "AAA", ts_utc = "2020-01-02T00:00:00Z", open = 100),
    spread_bps = 10,
    commission_fixed = 1.25
  )

  res <- ledgr:::ledgr_write_fill_events(con, run_id, fill, event_seq_start = 1L)
  testthat::expect_identical(res$status, "WROTE")
  testthat::expect_identical(res$event_id, "run-ledger-1_00000001")
  testthat::expect_identical(res$event_seq, 1L)
  testthat::expect_identical(res$next_event_seq, 2L)

  row <- DBI::dbGetQuery(
    con,
    "
    SELECT *
    FROM ledger_events
    WHERE run_id = ?
    ORDER BY event_seq
    ",
    params = list(run_id)
  )
  testthat::expect_equal(nrow(row), 1L)
  testthat::expect_identical(row$event_type[[1]], "FILL")
  testthat::expect_identical(row$instrument_id[[1]], "AAA")
  testthat::expect_identical(row$side[[1]], "BUY")
  testthat::expect_equal(row$qty[[1]], 2)
  testthat::expect_equal(row$price[[1]], round(100 * (1 + 10 / 10000), 8))
  testthat::expect_equal(row$fee[[1]], 1.25)

  meta <- parse_meta(row$meta_json[[1]])
  testthat::expect_equal(meta$commission_fixed, 1.25)
  testthat::expect_equal(meta$position_delta, 2)
  testthat::expect_equal(meta$cash_delta, -(2 * row$price[[1]] + 1.25))
})

testthat::test_that("SELL fill writes correct deltas", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  run_id <- "run-ledger-2"
  insert_test_run(con, run_id)

  fill <- ledgr:::ledgr_fill_next_open(
    desired_qty_delta = -3,
    next_bar = list(instrument_id = "AAA", ts_utc = "2020-01-02T00:00:00Z", open = 100),
    spread_bps = 10,
    commission_fixed = 2
  )

  ledgr:::ledgr_write_fill_events(con, run_id, fill, event_seq_start = 1L)

  row <- DBI::dbGetQuery(con, "SELECT * FROM ledger_events WHERE run_id = ?", params = list(run_id))
  testthat::expect_equal(nrow(row), 1L)
  testthat::expect_identical(row$side[[1]], "SELL")
  testthat::expect_equal(row$qty[[1]], 3)
  testthat::expect_equal(row$fee[[1]], 2)

  meta <- parse_meta(row$meta_json[[1]])
  testthat::expect_equal(meta$position_delta, -3)
  testthat::expect_equal(meta$cash_delta, +(3 * row$price[[1]] - 2))
})

testthat::test_that("event_seq increments across multiple writes", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  run_id <- "run-ledger-3"
  insert_test_run(con, run_id)

  fill1 <- ledgr:::ledgr_fill_next_open(
    desired_qty_delta = 1,
    next_bar = list(instrument_id = "AAA", ts_utc = "2020-01-02T00:00:00Z", open = 10),
    spread_bps = 0,
    commission_fixed = 0
  )
  fill2 <- ledgr:::ledgr_fill_next_open(
    desired_qty_delta = -1,
    next_bar = list(instrument_id = "AAA", ts_utc = "2020-01-03T00:00:00Z", open = 12),
    spread_bps = 0,
    commission_fixed = 0
  )

  r1 <- ledgr:::ledgr_write_fill_events(con, run_id, fill1, event_seq_start = 1L)
  r2 <- ledgr:::ledgr_write_fill_events(con, run_id, fill2, event_seq_start = r1$next_event_seq)

  testthat::expect_identical(r2$event_seq, 2L)

  seqs <- DBI::dbGetQuery(con, "SELECT event_seq FROM ledger_events WHERE run_id = ? ORDER BY event_seq", params = list(run_id))$event_seq
  testthat::expect_identical(as.integer(seqs), c(1L, 2L))
})

testthat::test_that("fill_none is a no-op (no ledger rows written)", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  run_id <- "run-ledger-4"
  insert_test_run(con, run_id)

  before <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id = ?", params = list(run_id))$n[[1]]

  none <- structure(list(status = "NO_FILL"), class = "ledgr_fill_none")
  res <- ledgr:::ledgr_write_fill_events(con, run_id, none, event_seq_start = 1L)
  testthat::expect_identical(res$status, "NO_OP")

  after <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id = ?", params = list(run_id))$n[[1]]
  testthat::expect_identical(before, after)
})

testthat::test_that("append-only: duplicate (run_id, event_seq) fails and does not add a row", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  run_id <- "run-ledger-5"
  insert_test_run(con, run_id)

  fill <- ledgr:::ledgr_fill_next_open(
    desired_qty_delta = 1,
    next_bar = list(instrument_id = "AAA", ts_utc = "2020-01-02T00:00:00Z", open = 10),
    spread_bps = 0,
    commission_fixed = 0
  )

  ledgr:::ledgr_write_fill_events(con, run_id, fill, event_seq_start = 1L)
  before <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id = ?", params = list(run_id))$n[[1]]

  testthat::expect_error(
    ledgr:::ledgr_write_fill_events(con, run_id, fill, event_seq_start = 1L)
  )

  after <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id = ?", params = list(run_id))$n[[1]]
  testthat::expect_identical(before, after)
})

testthat::test_that("transactionality: failed insert leaves no partial row", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  run_id <- "run-ledger-6"
  insert_test_run(con, run_id)

  fill <- ledgr:::ledgr_fill_next_open(
    desired_qty_delta = 1,
    next_bar = list(instrument_id = "AAA", ts_utc = "2020-01-02T00:00:00Z", open = 10),
    spread_bps = 0,
    commission_fixed = 0
  )

  testthat::expect_error(
    ledgr:::ledgr_write_fill_events(con, run_id, fill, event_seq_start = 0L),
    "event_seq_start",
    fixed = TRUE
  )
  n <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id = ?", params = list(run_id))$n[[1]]
  testthat::expect_identical(n, 0)
})

