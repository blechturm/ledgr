testthat::test_that("schema can be created on an empty DuckDB", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  testthat::expect_true(ledgr_create_schema(con))
  testthat::expect_true(ledgr_validate_schema(con))

  tables <- DBI::dbGetQuery(
    con,
    "
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'main'
    "
  )$table_name

  for (t in c("runs", "instruments", "bars", "features", "ledger_events", "equity_curve", "strategy_state")) {
    testthat::expect_true(t %in% tables, info = sprintf("expected table %s to exist", t))
  }
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
  DBI::dbExecute(
    con,
    "
    CREATE TABLE runs (
      run_id TEXT PRIMARY KEY,
      created_at_utc TIMESTAMP NOT NULL,
      status TEXT NOT NULL CHECK (status IN ('CREATED','RUNNING','DONE','FAILED'))
    )
    "
  )

  testthat::expect_error(ledgr_validate_schema(con), "Missing columns in runs:", fixed = TRUE)
})

testthat::test_that("bars primary key enforcement is detectable", {
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
        status,
        NA_character_
      )
    )
  }

  testthat::expect_error(
    insert_runs("run-1", "INVALID")
  )

  testthat::expect_error(
    insert_runs("run-2", "DONE"),
    NA
  )
})

testthat::test_that("snapshots.status CHECK constraint is enforced", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_create_schema(con)

  insert_snapshot <- function(snapshot_id, status) {
    DBI::dbExecute(
      con,
      "
      INSERT INTO snapshots (
        snapshot_id,
        status,
        created_at_utc,
        sealed_at_utc,
        snapshot_hash,
        meta_json,
        error_msg
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ",
      params = list(
        snapshot_id,
        status,
        as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
        NA,
        NA_character_,
        "{}",
        NA_character_
      )
    )
  }

  testthat::expect_error(
    insert_snapshot("snapshot-1", "OPEN")
  )

  testthat::expect_error(
    insert_snapshot("snapshot-2", "SEALED"),
    NA
  )
})

testthat::test_that("missing features table fails validation", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_create_schema(con)
  DBI::dbExecute(con, "DROP TABLE features")

  testthat::expect_error(ledgr_validate_schema(con), "Missing table: features", fixed = TRUE)
})

testthat::test_that("missing strategy_state table fails validation", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_create_schema(con)
  DBI::dbExecute(con, "DROP TABLE strategy_state")

  testthat::expect_error(ledgr_validate_schema(con), "Missing table: strategy_state", fixed = TRUE)
})

testthat::test_that("strategy_state primary key prevents duplicates", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_create_schema(con)

  DBI::dbExecute(
    con,
    "
    INSERT INTO strategy_state (run_id, ts_utc, state_json)
    VALUES ('run-1', '2020-01-01T00:00:00Z', '{}')
    "
  )

  testthat::expect_error(
    DBI::dbExecute(
      con,
      "
      INSERT INTO strategy_state (run_id, ts_utc, state_json)
      VALUES ('run-1', '2020-01-01T00:00:00Z', '{}')
      "
    )
  )
})

testthat::test_that("features primary key prevents duplicates", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_create_schema(con)

  DBI::dbExecute(
    con,
    "
    INSERT INTO features (run_id, instrument_id, ts_utc, feature_name, feature_value)
    VALUES ('run-1', 'ABC', TIMESTAMP '2020-01-01 00:00:00', 'sma_2', 1.0)
    "
  )

  testthat::expect_error(
    DBI::dbExecute(
      con,
      "
      INSERT INTO features (run_id, instrument_id, ts_utc, feature_name, feature_value)
      VALUES ('run-1', 'ABC', TIMESTAMP '2020-01-01 00:00:00', 'sma_2', 2.0)
      "
    )
  )
})

testthat::test_that("ledger_events enforces uniqueness of (run_id, event_seq)", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_create_schema(con)

  DBI::dbExecute(
    con,
    "
    INSERT INTO ledger_events (event_id, run_id, ts_utc, event_type, event_seq)
    VALUES ('run-1_00000001', 'run-1', TIMESTAMP '2020-01-02 00:00:00', 'FILL', 1)
    "
  )

  testthat::expect_error(
    DBI::dbExecute(
      con,
      "
      INSERT INTO ledger_events (event_id, run_id, ts_utc, event_type, event_seq)
      VALUES ('run-1_00000002', 'run-1', TIMESTAMP '2020-01-02 00:00:00', 'FILL', 1)
      "
    )
  )
})

testthat::test_that("upgrade path: old runs schema is migrated and COMPLETED is mapped to DONE", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  DBI::dbExecute(
    con,
    "
    CREATE TABLE runs (
      run_id TEXT NOT NULL PRIMARY KEY,
      created_at_utc TIMESTAMP NOT NULL,
      status TEXT NOT NULL CHECK (status IN ('CREATED','RUNNING','COMPLETED','FAILED'))
    )
    "
  )
  DBI::dbExecute(
    con,
    "
    INSERT INTO runs (run_id, created_at_utc, status)
    VALUES ('old-run', TIMESTAMP '2020-01-01 00:00:00', 'COMPLETED')
    "
  )

  testthat::expect_true(ledgr_create_schema(con))
  testthat::expect_true(ledgr_validate_schema(con))

  status <- DBI::dbGetQuery(con, "SELECT status FROM runs WHERE run_id = 'old-run'")$status[[1]]
  testthat::expect_identical(status, "DONE")
})

testthat::test_that("validator fails if runs.status does not accept DONE", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_create_schema(con)

  DBI::dbExecute(con, "DROP TABLE runs")
  DBI::dbExecute(
    con,
    "
    CREATE TABLE runs (
      run_id TEXT NOT NULL PRIMARY KEY,
      created_at_utc TIMESTAMP NOT NULL,
      engine_version TEXT,
      config_json TEXT,
      config_hash TEXT,
      data_hash TEXT,
      snapshot_id TEXT,
      status TEXT NOT NULL CHECK (status IN ('CREATED','RUNNING','COMPLETED','FAILED')),
      error_msg TEXT,
      label TEXT,
      archived BOOLEAN,
      archived_at_utc TIMESTAMP,
      archive_reason TEXT,
      execution_mode TEXT,
      schema_version INTEGER
    )
    "
  )

  testthat::expect_error(
    ledgr_validate_schema(con),
    "runs.status must enforce status values",
    fixed = TRUE
  )
})
