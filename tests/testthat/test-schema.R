testthat::test_that("schema can be created on an empty DuckDB", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  testthat::expect_true(ledgr_create_schema(con))
  testthat::expect_true(ledgr_validate_schema(con))
})

testthat::test_that("schema creation is idempotent", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  testthat::expect_true(ledgr_create_schema(con))
  testthat::expect_true(ledgr_create_schema(con))
  testthat::expect_true(ledgr_validate_schema(con))
})

testthat::test_that("missing table fails validation", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_create_schema(con)
  DBI::dbExecute(con, "DROP TABLE bars")

  testthat::expect_error(ledgr_validate_schema(con), "Missing table: bars", fixed = TRUE)
})

testthat::test_that("missing column fails validation", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_create_schema(con)
  DBI::dbExecute(con, "DROP TABLE runs")
  DBI::dbExecute(con, "CREATE TABLE runs (run_id TEXT PRIMARY KEY)")

  testthat::expect_error(ledgr_validate_schema(con), "Missing columns in runs:", fixed = TRUE)
})

testthat::test_that("primary key enforcement is detectable", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_create_schema(con)

  DBI::dbExecute(
    con,
    "
    INSERT INTO bars (instrument_id, ts_utc, open, high, low, close, volume)
    VALUES ('ABC', TIMESTAMP '2020-01-01 00:00:00', 1, 1, 1, 1, 100)
    "
  )

  testthat::expect_error(
    DBI::dbExecute(
      con,
      "
      INSERT INTO bars (instrument_id, ts_utc, open, high, low, close, volume)
      VALUES ('ABC', TIMESTAMP '2020-01-01 00:00:00', 1, 1, 1, 1, 100)
      "
    )
  )
})

testthat::test_that("runs.status CHECK constraint is enforced", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_create_schema(con)

  insert_runs <- function(run_id, status) {
    DBI::dbExecute(
      con,
      "
      INSERT INTO runs (
        run_id,
        created_at_utc,
        status,
        config_hash,
        data_hash,
        engine_version,
        seed,
        initial_cash
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ",
      params = list(
        run_id,
        as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
        status,
        "config-hash",
        "data-hash",
        "0.1.0",
        1L,
        1000.0
      )
    )
  }

  testthat::expect_error(
    insert_runs("run-1", "INVALID")
  )

  testthat::expect_error(
    insert_runs("run-2", "CREATED"),
    NA
  )
})

testthat::test_that("ledger_events rejects NULL run_id", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_create_schema(con)

  testthat::expect_error(
    DBI::dbExecute(
      con,
      "
      INSERT INTO ledger_events (
        event_id, run_id, ts_utc, event_type, event_seq
      ) VALUES (
        'e1', NULL, TIMESTAMP '2020-01-01 00:00:00', 'X', 1
      )
      "
    )
  )
})

testthat::test_that("ledger_events rejects NULL event_seq", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_create_schema(con)

  testthat::expect_error(
    DBI::dbExecute(
      con,
      "
      INSERT INTO ledger_events (
        event_id, run_id, ts_utc, event_type, event_seq
      ) VALUES (
        'e1', 'run-1', TIMESTAMP '2020-01-01 00:00:00', 'X', NULL
      )
      "
    )
  )
})

testthat::test_that("equity_curve rejects NULL values", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_create_schema(con)

  testthat::expect_error(
    DBI::dbExecute(
      con,
      "
      INSERT INTO equity_curve (
        run_id, ts_utc, cash, gross_exposure, net_exposure, equity
      ) VALUES (
        'run-1', TIMESTAMP '2020-01-01 00:00:00', NULL, 0, 0, 0
      )
      "
    )
  )
})

testthat::test_that("bars rejects NULL OHLCV values", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_create_schema(con)

  testthat::expect_error(
    DBI::dbExecute(
      con,
      "
      INSERT INTO bars (instrument_id, ts_utc, open, high, low, close, volume)
      VALUES ('ABC', TIMESTAMP '2020-01-01 00:00:00', NULL, 1, 1, 1, 100)
      "
    )
  )
})

testthat::test_that("validation fails if ledger_events lacks UNIQUE(run_id, event_seq)", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_create_schema(con)

  DBI::dbExecute(con, "DROP TABLE ledger_events")
  DBI::dbExecute(
    con,
    "
    CREATE TABLE ledger_events (
      event_id TEXT NOT NULL PRIMARY KEY,
      run_id TEXT NOT NULL,
      ts_utc TIMESTAMP NOT NULL,
      event_type TEXT NOT NULL,
      instrument_id TEXT,
      qty DOUBLE,
      price DOUBLE,
      cash_delta DOUBLE,
      event_seq INTEGER NOT NULL
    )
    "
  )

  testthat::expect_error(
    ledgr_validate_schema(con),
    "Missing UNIQUE constraint on ledger_events: (run_id, event_seq)",
    fixed = TRUE
  )
})

testthat::test_that("validation fails if ledger_events allows NULL run_id", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_create_schema(con)

  DBI::dbExecute(con, "DROP TABLE ledger_events")
  DBI::dbExecute(
    con,
    "
    CREATE TABLE ledger_events (
      event_id TEXT NOT NULL PRIMARY KEY,
      run_id TEXT,
      ts_utc TIMESTAMP NOT NULL,
      event_type TEXT NOT NULL,
      instrument_id TEXT,
      qty DOUBLE,
      price DOUBLE,
      cash_delta DOUBLE,
      event_seq INTEGER NOT NULL,
      UNIQUE(run_id, event_seq)
    )
    "
  )

  testthat::expect_error(
    ledgr_validate_schema(con),
    "Expected NOT NULL constraints missing for ledger_events: run_id",
    fixed = TRUE
  )
})
