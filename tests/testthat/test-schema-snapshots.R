testthat::test_that("v0.1.1 snapshot tables exist after schema creation", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_create_schema(con)
  testthat::expect_true(ledgr_validate_schema(con))

  tables <- DBI::dbGetQuery(
    con,
    "
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'main'
    "
  )$table_name

  for (t in c("snapshots", "snapshot_instruments", "snapshot_bars")) {
    testthat::expect_true(t %in% tables, info = sprintf("expected table %s to exist", t))
  }
})

testthat::test_that("schema creation remains idempotent with snapshot tables", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  testthat::expect_true(ledgr_create_schema(con))
  testthat::expect_true(ledgr_create_schema(con))
  testthat::expect_true(ledgr_validate_schema(con))
})

testthat::test_that("schema creation refuses a non-empty unmarked store", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  # Simulate a v0.1.0-era runs table (no snapshot_id).
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
      status TEXT NOT NULL CHECK (status IN ('CREATED','RUNNING','DONE','FAILED')),
      error_msg TEXT
    )
    "
  )
  DBI::dbExecute(
    con,
    "
    INSERT INTO runs (run_id, created_at_utc, engine_version, config_json, config_hash, data_hash, status, error_msg)
    VALUES ('old-run', TIMESTAMP '2020-01-01 00:00:00', '0.1.0', '{}', 'h1', 'd1', 'DONE', NULL)
    "
  )

  testthat::expect_error(
    ledgr_create_schema(con),
    class = "ledgr_store_rebuild_required"
  )
  row <- DBI::dbGetQuery(con, "SELECT run_id, data_hash FROM runs")
  testthat::expect_identical(row$run_id, "old-run")
  testthat::expect_identical(row$data_hash, "d1")
})

testthat::test_that("snapshots.status enum and PK/NOT NULL constraints are enforced", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_create_schema(con)

  testthat::expect_error(
    DBI::dbExecute(
      con,
      "
      INSERT INTO snapshots (snapshot_id, status, created_at_utc)
      VALUES ('s1', 'INVALID', TIMESTAMP '2020-01-01 00:00:00')
      "
    )
  )
  try(DBI::dbExecute(con, "ROLLBACK"), silent = TRUE)

  testthat::expect_error(
    DBI::dbExecute(
      con,
      "
      INSERT INTO snapshots (snapshot_id, status, created_at_utc)
      VALUES ('s1', 'CREATED', TIMESTAMP '2020-01-01 00:00:00')
      "
    ),
    NA
  )

  # PK on snapshots.
  testthat::expect_error(
    DBI::dbExecute(
      con,
      "
      INSERT INTO snapshots (snapshot_id, status, created_at_utc)
      VALUES ('s1', 'CREATED', TIMESTAMP '2020-01-01 00:00:00')
      "
    )
  )
  try(DBI::dbExecute(con, "ROLLBACK"), silent = TRUE)

  # NOT NULL enforcement on snapshot_bars OHLC columns.
  testthat::expect_error(
    DBI::dbExecute(
      con,
      "
      INSERT INTO snapshot_bars (snapshot_id, instrument_id, ts_utc, open, high, low, close, volume)
      VALUES ('s1', 'AAA', TIMESTAMP '2020-01-01 00:00:00', 1, 1, 1, NULL, 1)
      "
    )
  )
  try(DBI::dbExecute(con, "ROLLBACK"), silent = TRUE)

  # PK enforcement on snapshot_bars.
  DBI::dbExecute(
    con,
    "
    INSERT INTO snapshot_bars (snapshot_id, instrument_id, ts_utc, open, high, low, close, volume)
    VALUES ('s1', 'AAA', TIMESTAMP '2020-01-01 00:00:00', 1, 1, 1, 1, 1)
    "
  )
  testthat::expect_error(
    DBI::dbExecute(
      con,
      "
      INSERT INTO snapshot_bars (snapshot_id, instrument_id, ts_utc, open, high, low, close, volume)
      VALUES ('s1', 'AAA', TIMESTAMP '2020-01-01 00:00:00', 1, 1, 1, 1, 1)
      "
    )
  )
})
