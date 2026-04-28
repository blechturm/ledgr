legacy_v014_store <- function(con) {
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
      status TEXT NOT NULL CHECK (status IN ('CREATED','RUNNING','DONE','FAILED')),
      error_msg TEXT
    )
    "
  )
  DBI::dbExecute(
    con,
    "
    INSERT INTO runs (
      run_id, created_at_utc, engine_version, config_json, config_hash,
      data_hash, snapshot_id, status, error_msg
    ) VALUES (
      'legacy-run', TIMESTAMP '2020-01-01 00:00:00', '0.1.4',
      '{}', 'config-hash', 'window-hash', 'legacy-snapshot', 'DONE', NULL
    )
    "
  )

  DBI::dbExecute(
    con,
    "
    CREATE TABLE ledger_events (
      event_id TEXT NOT NULL PRIMARY KEY,
      run_id TEXT NOT NULL,
      ts_utc TIMESTAMP NOT NULL,
      event_type TEXT NOT NULL CHECK (event_type IN ('FILL','FEE','CASHFLOW')),
      instrument_id TEXT,
      side TEXT CHECK (side IN ('BUY','SELL')),
      qty DOUBLE,
      price DOUBLE,
      fee DOUBLE,
      meta_json TEXT,
      event_seq INTEGER NOT NULL,
      UNIQUE(run_id, event_seq)
    )
    "
  )
  DBI::dbExecute(
    con,
    "
    INSERT INTO ledger_events (
      event_id, run_id, ts_utc, event_type, instrument_id, side,
      qty, price, fee, meta_json, event_seq
    ) VALUES (
      'legacy-run_00000001', 'legacy-run', TIMESTAMP '2020-01-02 00:00:00',
      'FILL', 'AAA', 'BUY', 1, 101, 0, '{}', 1
    )
    "
  )

  DBI::dbExecute(
    con,
    "
    CREATE TABLE features (
      run_id TEXT NOT NULL,
      instrument_id TEXT NOT NULL,
      ts_utc TIMESTAMP NOT NULL,
      feature_name TEXT NOT NULL,
      feature_value DOUBLE,
      PRIMARY KEY (run_id, instrument_id, ts_utc, feature_name)
    )
    "
  )
  DBI::dbExecute(
    con,
    "
    INSERT INTO features (run_id, instrument_id, ts_utc, feature_name, feature_value)
    VALUES ('legacy-run', 'AAA', TIMESTAMP '2020-01-01 00:00:00', 'sma_2', 100)
    "
  )

  DBI::dbExecute(
    con,
    "
    CREATE TABLE equity_curve (
      run_id TEXT NOT NULL,
      ts_utc TIMESTAMP NOT NULL,
      cash DOUBLE,
      positions_value DOUBLE,
      equity DOUBLE,
      realized_pnl DOUBLE,
      unrealized_pnl DOUBLE,
      PRIMARY KEY (run_id, ts_utc)
    )
    "
  )
  DBI::dbExecute(
    con,
    "
    INSERT INTO equity_curve (
      run_id, ts_utc, cash, positions_value, equity, realized_pnl, unrealized_pnl
    ) VALUES (
      'legacy-run', TIMESTAMP '2020-01-02 00:00:00', 899, 101, 1000, 0, 0
    )
    "
  )
}

testthat::test_that("read-only experiment-store inspection does not mutate legacy stores", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  legacy_v014_store(con)

  before <- DBI::dbGetQuery(
    con,
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main' ORDER BY table_name"
  )$table_name

  out <- ledgr:::ledgr_experiment_store_check_schema(con, write = FALSE)

  after <- DBI::dbGetQuery(
    con,
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main' ORDER BY table_name"
  )$table_name

  testthat::expect_true(out$is_legacy)
  testthat::expect_identical(after, before)
  testthat::expect_false("ledgr_schema_metadata" %in% after)
})

testthat::test_that("write-triggered migration is additive and preserves v0.1.4 rows", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  legacy_v014_store(con)

  testthat::expect_message(
    ledgr_create_schema(con),
    "Upgraded ledgr experiment-store schema"
  )
  testthat::expect_true(ledgr_validate_schema(con))

  version <- DBI::dbGetQuery(
    con,
    "SELECT value FROM ledgr_schema_metadata WHERE key = 'experiment_store_schema_version'"
  )$value[[1]]
  testthat::expect_identical(as.integer(version), ledgr:::ledgr_experiment_store_schema_version)

  testthat::expect_identical(
    DBI::dbGetQuery(con, "SELECT status FROM runs WHERE run_id = 'legacy-run'")$status[[1]],
    "DONE"
  )
  testthat::expect_identical(
    DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id = 'legacy-run'")$n[[1]],
    1
  )
  testthat::expect_identical(
    DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM features WHERE run_id = 'legacy-run'")$n[[1]],
    1
  )
  testthat::expect_identical(
    DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM equity_curve WHERE run_id = 'legacy-run'")$n[[1]],
    1
  )
  legacy_provenance <- DBI::dbGetQuery(
    con,
    "SELECT reproducibility_level, strategy_source_capture_method FROM run_provenance WHERE run_id = 'legacy-run'"
  )
  testthat::expect_identical(legacy_provenance$reproducibility_level[[1]], "legacy")
  testthat::expect_identical(legacy_provenance$strategy_source_capture_method[[1]], "legacy_pre_provenance")

  runs_cols <- DBI::dbGetQuery(
    con,
    "
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'main'
      AND table_name = 'runs'
    "
  )$column_name
  testthat::expect_true(all(c("label", "archived", "execution_mode", "schema_version") %in% runs_cols))
  testthat::expect_true("run_tags" %in% DBI::dbGetQuery(
    con,
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main'"
  )$table_name)
})

testthat::test_that("future experiment-store schemas fail before downgrade or mutation", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbExecute(
    con,
    "
    CREATE TABLE ledgr_schema_metadata (
      key TEXT NOT NULL PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at_utc TIMESTAMP NOT NULL
    )
    "
  )
  DBI::dbExecute(
    con,
    "
    INSERT INTO ledgr_schema_metadata (key, value, updated_at_utc)
    VALUES ('experiment_store_schema_version', '999', TIMESTAMP '2026-01-01 00:00:00')
    "
  )

  testthat::expect_error(
    ledgr_create_schema(con),
    class = "ledgr_future_schema_version"
  )

  tables <- DBI::dbGetQuery(
    con,
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main' ORDER BY table_name"
  )$table_name
  testthat::expect_identical(tables, "ledgr_schema_metadata")
})

testthat::test_that("failed migration leaves the previous schema marker and old rows readable", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  legacy_v014_store(con)
  DBI::dbExecute(
    con,
    "
    CREATE TABLE ledgr_schema_metadata (
      key TEXT NOT NULL PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at_utc TIMESTAMP NOT NULL
    )
    "
  )
  DBI::dbExecute(
    con,
    "
    INSERT INTO ledgr_schema_metadata (key, value, updated_at_utc)
    VALUES ('experiment_store_schema_version', '104', TIMESTAMP '2026-01-01 00:00:00')
    "
  )

  testthat::expect_error(
    ledgr:::ledgr_experiment_store_migrate(con, simulate_failure = TRUE),
    class = "ledgr_schema_migration_simulated_failure"
  )

  version <- ledgr:::ledgr_experiment_store_version(con)
  testthat::expect_identical(version, 104L)
  tables <- DBI::dbGetQuery(
    con,
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main'"
  )$table_name
  testthat::expect_false("run_provenance" %in% tables)
  testthat::expect_false("run_telemetry" %in% tables)
  testthat::expect_false("run_tags" %in% tables)
  testthat::expect_identical(
    DBI::dbGetQuery(con, "SELECT status FROM runs WHERE run_id = 'legacy-run'")$status[[1]],
    "DONE"
  )
})

testthat::test_that("runs.execution_mode rejects values outside v0.1.5 modes when supported", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  DBI::dbExecute(
    con,
    "
    INSERT INTO runs (
      run_id, created_at_utc, engine_version, config_json, config_hash,
      data_hash, status, error_msg
    ) VALUES (
      'run-mode-check', TIMESTAMP '2020-01-01 00:00:00', '0.1.5',
      '{}', 'config-hash', 'data-hash', 'DONE', NULL
    )
    "
  )

  rejected <- tryCatch(
    {
      DBI::dbExecute(
        con,
        "UPDATE runs SET execution_mode = 'other' WHERE run_id = 'run-mode-check'"
      )
      FALSE
    },
    error = function(e) TRUE
  )
  if (!isTRUE(rejected)) {
    testthat::skip("DuckDB build does not support ADD COLUMN CHECK constraints.")
  }

  testthat::expect_error(
    DBI::dbExecute(
      con,
      "UPDATE runs SET execution_mode = 'other' WHERE run_id = 'run-mode-check'"
    )
  )
  testthat::expect_error(
    DBI::dbExecute(
      con,
      "UPDATE runs SET execution_mode = 'db_live' WHERE run_id = 'run-mode-check'"
    ),
    NA
  )
})

testthat::test_that("execution_mode values are constrained to v0.1.5 values in schema-owned telemetry", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  testthat::expect_error(
    DBI::dbExecute(
      con,
      "
      INSERT INTO run_telemetry (run_id, status, execution_mode)
      VALUES ('run-bad-mode', 'DONE', 'other')
      "
    )
  )

  testthat::expect_error(
    DBI::dbExecute(
      con,
      "
      INSERT INTO run_telemetry (run_id, status, execution_mode)
      VALUES ('run-good-mode', 'DONE', 'audit_log')
      "
    ),
    NA
  )
})
