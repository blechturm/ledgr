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

schema_v114_completion_tables <- function(con) {
  ledgr_create_schema(con)
  DBI::dbExecute(con, "DROP TABLE sweep_candidates")
  DBI::dbExecute(
    con,
    "
    CREATE TABLE sweep_candidates (
      sweep_id TEXT NOT NULL,
      candidate_id TEXT NOT NULL,
      candidate_row INTEGER NOT NULL,
      status TEXT NOT NULL CHECK (status IN ('DONE','FAILED')),
      final_equity DOUBLE,
      metrics_json TEXT NOT NULL,
      total_return DOUBLE,
      annualized_return DOUBLE,
      volatility DOUBLE,
      sharpe_ratio DOUBLE,
      max_drawdown DOUBLE,
      n_trades INTEGER,
      win_rate DOUBLE,
      avg_trade DOUBLE,
      time_in_market DOUBLE,
      execution_seed INTEGER,
      error_class TEXT,
      error_msg TEXT,
      params_json TEXT NOT NULL,
      feature_params_json TEXT NOT NULL,
      warnings_json TEXT NOT NULL,
      feature_set_hash TEXT NOT NULL,
      feature_fingerprints_json TEXT NOT NULL,
      provenance_json TEXT NOT NULL,
      cost_model_hash TEXT NOT NULL,
      metric_context_hash TEXT NOT NULL,
      risk_chain_hash TEXT,
      risk_plan_json TEXT,
      PRIMARY KEY (sweep_id, candidate_row),
      UNIQUE (sweep_id, candidate_id)
    )
    "
  )
  DBI::dbExecute(
    con,
    "
    INSERT INTO sweep_candidates VALUES (
      'sweep-old', 'candidate-old', 1, 'DONE', 101,
      '{}', 0.01, 0.02, 0.03, 0.4, -0.1, 2, 0.5, 1.25, 0.2,
      11, NULL, NULL, '{}', '{}', '[]', 'feature-set', '{}', '{}',
      'cost-hash', 'metric-hash', 'risk-hash', '{}'
    )
    "
  )

  DBI::dbExecute(con, "DROP TABLE walk_forward_scores")
  DBI::dbExecute(
    con,
    "
    CREATE TABLE walk_forward_scores (
      session_id TEXT NOT NULL,
      fold_id TEXT NOT NULL,
      fold_seq INTEGER NOT NULL,
      candidate_key TEXT NOT NULL,
      candidate_label TEXT,
      params_hash TEXT NOT NULL,
      feature_params_hash TEXT NOT NULL,
      feature_set_hash TEXT NOT NULL,
      alias_map_hash TEXT NOT NULL,
      metric_context_hash TEXT NOT NULL,
      cost_model_hash TEXT NOT NULL,
      risk_chain_hash TEXT NOT NULL,
      \"window\" TEXT NOT NULL CHECK (\"window\" IN ('train','test')),
      metric_name TEXT NOT NULL,
      metric_value DOUBLE,
      n_trades INTEGER,
      status TEXT NOT NULL CHECK (status IN ('DONE','FAILED')),
      error_class TEXT,
      error_msg TEXT,
      execution_seed INTEGER,
      PRIMARY KEY (session_id, fold_seq, \"window\", candidate_key, metric_name)
    )
    "
  )
  DBI::dbExecute(
    con,
    "
    INSERT INTO walk_forward_scores VALUES (
      'session-old', 'fold-old', 1, 'candidate-old', 'Old candidate',
      'params-hash', 'feature-params-hash', 'feature-set', 'alias-hash',
      'metric-hash', 'cost-hash', 'risk-hash', 'train', 'sharpe_ratio',
      0.4, 2, 'DONE', NULL, NULL, 11
    )
    "
  )
  DBI::dbExecute(
    con,
    "
    UPDATE ledgr_schema_metadata
    SET value = '114'
    WHERE key = 'experiment_store_schema_version'
    "
  )
  invisible(TRUE)
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
  testthat::expect_true(all(c(
    "label", "archived", "execution_mode", "schema_version",
    "metric_context_json", "metric_context_hash", "metric_context_version"
  ) %in% runs_cols))
  testthat::expect_true("run_tags" %in% DBI::dbGetQuery(
    con,
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main'"
  )$table_name)
  testthat::expect_true("run_promotion_context" %in% DBI::dbGetQuery(
    con,
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main'"
  )$table_name)
})

testthat::test_that("schema 115 preserves candidate evidence and admits incomplete outcomes", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  schema_v114_completion_tables(con)

  testthat::expect_message(
    ledgr_create_schema(con),
    "Upgraded ledgr experiment-store schema from version 114 to 115"
  )

  candidate <- DBI::dbGetQuery(
    con,
    "SELECT candidate_id, status, completion_json, final_equity FROM sweep_candidates"
  )
  testthat::expect_identical(candidate$candidate_id, "candidate-old")
  testthat::expect_identical(candidate$status, "DONE")
  testthat::expect_true(is.na(candidate$completion_json[[1]]))
  testthat::expect_identical(candidate$final_equity, 101)

  score <- DBI::dbGetQuery(
    con,
    "SELECT candidate_key, status, completion_json, metric_value FROM walk_forward_scores"
  )
  testthat::expect_identical(score$candidate_key, "candidate-old")
  testthat::expect_identical(score$status, "DONE")
  testthat::expect_true(is.na(score$completion_json[[1]]))
  testthat::expect_identical(score$metric_value, 0.4)

  testthat::expect_no_error(DBI::dbExecute(
    con,
    "UPDATE sweep_candidates SET status = 'INCOMPLETE', completion_json = '{}'"
  ))
  testthat::expect_no_error(DBI::dbExecute(
    con,
    "UPDATE walk_forward_scores SET status = 'INCOMPLETE', completion_json = '{}'"
  ))
  testthat::expect_identical(ledgr:::ledgr_experiment_store_version(con), 115L)
})

testthat::test_that("failed schema 115 migration restores schema 114 candidate tables", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  schema_v114_completion_tables(con)

  testthat::expect_error(
    ledgr:::ledgr_experiment_store_migrate(
      con,
      from_version = 114L,
      simulate_failure = TRUE,
      inform = FALSE
    ),
    class = "ledgr_schema_migration_simulated_failure"
  )

  testthat::expect_identical(ledgr:::ledgr_experiment_store_version(con), 114L)
  testthat::expect_false(
    "completion_json" %in%
      ledgr:::ledgr_experiment_store_columns(con, "sweep_candidates")
  )
  testthat::expect_false(
    "completion_json" %in%
      ledgr:::ledgr_experiment_store_columns(con, "walk_forward_scores")
  )
  testthat::expect_identical(
    DBI::dbGetQuery(con, "SELECT status FROM sweep_candidates")$status,
    "DONE"
  )
  testthat::expect_identical(
    DBI::dbGetQuery(con, "SELECT status FROM walk_forward_scores")$status,
    "DONE"
  )
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
  testthat::expect_false("run_promotion_context" %in% tables)
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
      status, error_msg
    ) VALUES (
      'run-mode-check', TIMESTAMP '2020-01-01 00:00:00', '0.1.5',
      '{}', 'config-hash', 'DONE', NULL
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
