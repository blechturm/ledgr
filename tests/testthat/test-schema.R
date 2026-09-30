trace_schema_dbi_calls <- function(code) {
  calls <- new.env(parent = emptyenv())
  calls$get <- character()
  calls$execute <- character()
  callback <- function(kind, statement) {
    calls[[kind]] <- c(calls[[kind]], as.character(statement)[[1L]])
    invisible(NULL)
  }
  option_name <- "ledgr.test.schema_dbi_trace"
  prior <- options(structure(list(callback), names = option_name))
  on.exit(options(prior), add = TRUE)
  get_tracer <- quote({
    callback <- getOption("ledgr.test.schema_dbi_trace")
    if (is.function(callback)) callback("get", statement)
  })
  execute_tracer <- quote({
    callback <- getOption("ledgr.test.schema_dbi_trace")
    if (is.function(callback)) callback("execute", statement)
  })
  suppressMessages(trace(
    "dbGetQuery",
    where = asNamespace("DBI"),
    tracer = get_tracer,
    print = FALSE
  ))
  on.exit(suppressMessages(untrace(
    "dbGetQuery",
    where = asNamespace("DBI")
  )), add = TRUE)
  suppressMessages(trace(
    "dbExecute",
    where = asNamespace("DBI"),
    tracer = execute_tracer,
    print = FALSE
  ))
  on.exit(suppressMessages(untrace(
    "dbExecute",
    where = asNamespace("DBI")
  )), add = TRUE)

  force(code)
  list(get = calls$get, execute = calls$execute)
}

schema_catalogue_calls <- function(statements) {
  statements[grepl(
    "information_schema|duckdb_constraints",
    statements,
    ignore.case = TRUE
  )]
}

# The shape as plain text, so its hash depends only on the schema. Hashing
# the query results themselves serializes how DBI and duckdb built those
# vectors, which differs across R and duckdb builds with identical values.
schema_shape_text <- function(shape) {
  paste(unlist(lapply(names(shape), function(part) {
    c(part, do.call(paste, c(unname(as.list(shape[[part]])), sep = "|")))
  })), collapse = "\n")
}

schema_information_shape <- function(con) {
  list(
    tables = DBI::dbGetQuery(
      con,
      "SELECT table_name
       FROM information_schema.tables
       WHERE table_schema = 'main'
       ORDER BY table_name"
    ),
    columns = DBI::dbGetQuery(
      con,
      "SELECT table_name, column_name, data_type, is_nullable,
              ordinal_position
       FROM information_schema.columns
       WHERE table_schema = 'main'
       ORDER BY table_name, ordinal_position"
    ),
    keys = DBI::dbGetQuery(
      con,
      "SELECT tc.table_name, tc.constraint_type, kcu.column_name,
              kcu.ordinal_position
       FROM information_schema.table_constraints tc
       LEFT JOIN information_schema.key_column_usage kcu
         ON tc.constraint_catalog = kcu.constraint_catalog
        AND tc.constraint_schema = kcu.constraint_schema
        AND tc.constraint_name = kcu.constraint_name
        AND tc.table_schema = kcu.table_schema
        AND tc.table_name = kcu.table_name
       WHERE tc.table_schema = 'main'
         AND tc.constraint_type IN ('PRIMARY KEY', 'UNIQUE')
       ORDER BY tc.table_name, tc.constraint_type, kcu.ordinal_position"
    )
  )
}

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

  for (t in c("runs", "instruments", "bars", "features", "ledger_events", "equity_curve", "strategy_state", "run_promotion_context")) {
    testthat::expect_true(t %in% tables, info = sprintf("expected table %s to exist", t))
  }
})

testthat::test_that("[LTB-0039] schema catalogue work is bounded per call", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  validate_calls <- trace_schema_dbi_calls(ledgr_validate_schema(con))
  create_calls <- trace_schema_dbi_calls(ledgr_create_schema(con))

  testthat::expect_lte(
    length(schema_catalogue_calls(validate_calls$get)),
    4L
  )
  testthat::expect_lte(length(validate_calls$get), 5L)
  testthat::expect_length(validate_calls$execute, 0L)
  testthat::expect_lte(length(create_calls$get), 2L)
  testthat::expect_length(create_calls$execute, 0L)
})

testthat::test_that("[LTB-0040] schema fast path requires the exact version", {
  db_path <- tempfile(fileext = ".duckdb")
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path)
  on.exit({
    DBI::dbDisconnect(con, shutdown = TRUE)
    unlink(c(db_path, paste0(db_path, ".wal")), force = TRUE)
  }, add = TRUE)
  ledgr_create_schema(con)
  current_shape <- schema_information_shape(con)
  testthat::expect_identical(
    digest::digest(schema_shape_text(current_shape), algo = "sha256", serialize = FALSE),
    "8654cb7d2e49e6554f3ca67b221145e8438f9ade114c709a24aa75cf1bfc7c52"
  )

  DBI::dbExecute(
    con,
    "DELETE FROM ledgr_schema_metadata
     WHERE key = 'experiment_store_schema_version'"
  )
  missing_marker_calls <- trace_schema_dbi_calls(ledgr_create_schema(con))
  restored <- DBI::dbGetQuery(
    con,
    "SELECT value FROM ledgr_schema_metadata
     WHERE key = 'experiment_store_schema_version'"
  )$value[[1L]]
  testthat::expect_identical(
    as.integer(restored),
    ledgr:::ledgr_experiment_store_schema_version
  )
  testthat::expect_gt(length(missing_marker_calls$execute), 0L)
  testthat::expect_no_error(ledgr_validate_schema(con))

  DBI::dbExecute(
    con,
    "UPDATE ledgr_schema_metadata
     SET value = ?
     WHERE key = 'experiment_store_schema_version'",
    params = list(as.character(
      ledgr:::ledgr_experiment_store_schema_version - 1L
    ))
  )
  DBI::dbExecute(con, "DROP TABLE snapshot_equity_corporate_actions")
  DBI::dbExecute(con, "DROP TABLE bars")
  older_calls <- trace_schema_dbi_calls(ledgr_create_schema(con))
  tables <- DBI::dbGetQuery(
    con,
    "SELECT table_name FROM information_schema.tables
     WHERE table_schema = 'main'"
  )$table_name
  testthat::expect_true(all(c(
    "snapshot_equity_corporate_actions",
    "bars"
  ) %in% tables))
  testthat::expect_gt(length(older_calls$execute), 0L)
  testthat::expect_no_error(ledgr_validate_schema(con))
  testthat::expect_identical(schema_information_shape(con), current_shape)

  DBI::dbExecute(con, "DROP TABLE bars")
  ledgr_create_schema(con)
  testthat::expect_error(
    ledgr_validate_schema(con),
    "Missing table: bars",
    fixed = TRUE
  )
})

testthat::test_that("[LTB-0041] schema shortcut keeps its structural boundary", {
  create_source <- paste(
    readLines(testthat::test_path("..", "..", "R", "db-schema-create.R")),
    collapse = "\n"
  )
  runner_source <- paste(
    readLines(testthat::test_path("..", "..", "R", "backtest-runner.R")),
    collapse = "\n"
  )
  public_source <- paste(
    readLines(testthat::test_path("..", "..", "R", "public-api.R")),
    collapse = "\n"
  )
  marker_source <- readLines(testthat::test_path(
    "..", "..", "R", "experiment-store-schema.R"
  ))

  testthat::expect_match(
    create_source,
    paste0(
      "if \\(identical\\(\\s*",
      "as.integer\\(schema_state\\$schema_version\\),\\s*",
      "as.integer\\(ledgr_experiment_store_schema_version\\)\\s*",
      "\\)\\) \\{\\s*return\\(invisible\\(TRUE\\)\\)"
    ),
    perl = TRUE
  )
  testthat::expect_no_match(
    create_source,
    "if \\(table_exists\\([^)]*\\)\\) \\{[\\s\\S]{0,120}return\\(invisible\\(TRUE\\)\\)",
    perl = TRUE
  )
  testthat::expect_match(
    runner_source,
    "ledgr_create_schema\\(con\\)[\\s\\S]+ledgr_validate_schema_once\\(con\\)",
    perl = TRUE
  )
  testthat::expect_match(
    public_source,
    "ledgr_create_schema\\(con\\)[\\s\\S]+ledgr_validate_schema_once\\(con\\)",
    perl = TRUE
  )
  failure_line <- grep("if \\(isTRUE\\(simulate_failure\\)\\)", marker_source)
  marker_line <- grep("INSERT OR REPLACE INTO ledgr_schema_metadata", marker_source)
  testthat::expect_length(failure_line, 1L)
  testthat::expect_length(marker_line, 1L)
  testthat::expect_gt(marker_line, failure_line)
  migration_body <- paste(
    deparse(body(ledgr:::ledgr_experiment_store_migrate)),
    collapse = "\n"
  )
  testthat::expect_identical(
    digest::digest(migration_body, algo = "sha256", serialize = FALSE),
    "1b836d6b78a2c24621bb8bcc0275075c6f8ba8ab570f93af9c8d4cff8b384f10"
  )
})

testthat::test_that("schema creation is idempotent", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  testthat::expect_true(ledgr_create_schema(con))
  testthat::expect_true(ledgr_create_schema(con))
  testthat::expect_true(ledgr_validate_schema(con))
})

testthat::test_that("schema validation rejects missing tables and columns", {
  local({
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_create_schema(con)
  DBI::dbExecute(con, "DROP TABLE bars")

  testthat::expect_error(ledgr_validate_schema(con), "Missing table: bars", fixed = TRUE)
  })

  # Also covers: missing column fails validation
  local({
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

  # Also covers: missing strategy_state table fails validation
  local({
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_create_schema(con)
  DBI::dbExecute(con, "DROP TABLE strategy_state")

  testthat::expect_error(ledgr_validate_schema(con), "Missing table: strategy_state", fixed = TRUE)
  })
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

testthat::test_that("run and snapshot status constraints are enforced", {
  local({
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
        status,
        error_msg
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ",
      params = list(
        run_id,
        as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
        "0.1.0",
        "{}",
        "config-hash",
        status,
        NA_character_
      )
    )
  }

  testthat::expect_error(
    insert_runs("run-1", "INVALID")
  )
  try(DBI::dbExecute(con, "ROLLBACK"), silent = TRUE)

  for (status in c("CREATED", "RUNNING", "DONE", "FAILED")) {
    testthat::expect_error(
      insert_runs(paste0("run-", tolower(status)), status),
      NA
    )
  }
  })

  # Also covers: snapshots.status CHECK constraint is enforced
  local({
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
  try(DBI::dbExecute(con, "ROLLBACK"), silent = TRUE)

  for (status in c("CREATED", "SEALED", "FAILED")) {
    testthat::expect_error(
      insert_snapshot(paste0("snapshot-", tolower(status)), status),
      NA
    )
  }
  })
})


testthat::test_that("missing features table fails validation", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_create_schema(con)
  DBI::dbExecute(con, "DROP TABLE features")

  testthat::expect_error(ledgr_validate_schema(con), "Missing table: features", fixed = TRUE)
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
      snapshot_id TEXT,
      status TEXT NOT NULL CHECK (status IN ('CREATED','RUNNING','COMPLETED','FAILED')),
      error_msg TEXT,
      label TEXT,
      archived BOOLEAN,
      archived_at_utc TIMESTAMP,
      archive_reason TEXT,
      execution_mode TEXT,
      schema_version INTEGER,
      metric_context_json TEXT,
      metric_context_hash TEXT,
      metric_context_version INTEGER
    )
    "
  )

  testthat::expect_error(
    ledgr_validate_schema(con),
    "runs.status must enforce status values",
    fixed = TRUE
  )
})

testthat::test_that("create-side runs.status metadata parser fails loudly on unexpected expressions", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  DBI::dbExecute(
    con,
    "
    CREATE TABLE runs (
      run_id TEXT NOT NULL PRIMARY KEY,
      created_at_utc TIMESTAMP NOT NULL,
      engine_version TEXT,
      config_json TEXT,
      config_hash TEXT,
      snapshot_id TEXT,
      status TEXT NOT NULL CHECK (length(status) > 0),
      error_msg TEXT,
      label TEXT,
      archived BOOLEAN NOT NULL DEFAULT FALSE,
      archived_at_utc TIMESTAMP,
      archive_reason TEXT,
      execution_mode TEXT,
      schema_version INTEGER NOT NULL DEFAULT 108,
      metric_context_json TEXT,
      metric_context_hash TEXT,
      metric_context_version INTEGER
    )
    "
  )
  DBI::dbExecute(
    con,
    "
    INSERT INTO runs (
      run_id, created_at_utc, engine_version, config_json, config_hash,
      snapshot_id, status, error_msg, label, archived,
      archived_at_utc, archive_reason, execution_mode, schema_version,
      metric_context_json, metric_context_hash, metric_context_version
    )
    VALUES (
      'bad-check', TIMESTAMP '2020-01-01 00:00:00', '0.1.0', '{}',
      'config', NULL, 'DONE', NULL, NULL, FALSE, NULL, NULL,
      NULL, 108, NULL, NULL, NULL
    )
    "
  )

  testthat::expect_error(
    ledgr_create_schema(con),
    "Cannot interpret runs.status constraint metadata",
    fixed = TRUE
  )

  row <- DBI::dbGetQuery(con, "SELECT run_id, status FROM runs")
  testthat::expect_identical(row$run_id, "bad-check")
  testthat::expect_identical(row$status, "DONE")
})

testthat::test_that("[LTB-0130] a store's schema is validated once per session until it changes", {
  calls <- 0L
  full_validation <- ledgr:::ledgr_validate_schema
  testthat::local_mocked_bindings(
    ledgr_validate_schema = function(con) {
      calls <<- calls + 1L
      full_validation(con)
    },
    .package = "ledgr"
  )
  validations <- function(expr) {
    before <- calls
    force(expr)
    calls - before
  }
  init_and_close <- function(path) {
    con <- ledgr_db_init(path)
    DBI::dbDisconnect(con, shutdown = TRUE)
    invisible(TRUE)
  }
  store_files <- function(path) c(path, paste0(path, ".wal"))

  bars <- data.frame(
    ts_utc = rep(as.POSIXct(paste(as.Date("2026-02-02") + 0:3, "16:00:00"), tz = "UTC"), each = 2L),
    instrument_id = rep(c("AAA", "BBB"), 4L),
    open = 10, high = 10, low = 10, close = 10, volume = 1000
  )
  path <- tempfile(fileext = ".duckdb")
  second <- tempfile(fileext = ".duckdb")
  copy <- tempfile(fileext = ".duckdb")
  on.exit(unlink(c(store_files(path), store_files(second), store_files(copy)), force = TRUE), add = TRUE)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = path, snapshot_id = "validation_once")
  exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$flat(),
    opening = ledgr_opening(cash = 1000),
    cost_model = ledgr_cost_zero()
  )

  # Repeated runs and store opens against one unchanged store validate once.
  testthat::expect_identical(validations({
    for (id in c("once_1", "once_2", "once_3")) close(ledgr_run(exp, run_id = id))
    init_and_close(path)
  }), 1L)
  testthat::expect_identical(
    nrow(ledgr_run_list(snapshot)),
    3L
  )
  ledgr_snapshot_close(snapshot)

  # A byte-for-byte copy at another path is a different file and is validated.
  testthat::expect_true(file.copy(path, copy))
  testthat::expect_identical(validations(init_and_close(copy)), 1L)

  # A check constraint weakened on the same columns and keys is validated again
  # and fails.
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = copy)
  DBI::dbExecute(con, "DROP TABLE snapshot_sessions")
  DBI::dbExecute(con, "
    CREATE TABLE snapshot_sessions (
      snapshot_id TEXT NOT NULL,
      venue_id TEXT NOT NULL,
      session_date DATE NOT NULL,
      effective_from TIMESTAMP NOT NULL,
      effective_to TIMESTAMP NOT NULL,
      knowledge_time TIMESTAMP,
      status TEXT NOT NULL CHECK (status IN ('open')),
      session_open TIMESTAMP,
      session_close TIMESTAMP,
      provenance_json TEXT NOT NULL,
      PRIMARY KEY (snapshot_id, venue_id, session_date)
    )
  ")
  DBI::dbDisconnect(con, shutdown = TRUE)
  testthat::expect_identical(validations(testthat::expect_error(init_and_close(copy))), 1L)

  # A second store is validated on its own.
  testthat::expect_identical(validations(init_and_close(second)), 1L)
  testthat::expect_identical(validations(init_and_close(second)), 0L)

  # A rewritten version marker is validated again.
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = second)
  DBI::dbExecute(
    con,
    "UPDATE ledgr_schema_metadata
     SET updated_at_utc = updated_at_utc + INTERVAL 1 SECOND
     WHERE key = 'experiment_store_schema_version'"
  )
  DBI::dbDisconnect(con, shutdown = TRUE)
  testthat::expect_identical(validations(init_and_close(second)), 1L)

  # A store replaced at the same path is validated again.
  unlink(store_files(second), force = TRUE)
  testthat::expect_identical(validations(init_and_close(second)), 1L)

  # A changed catalogue is validated again, and a failing store fails on every
  # call with the same condition class.
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = second)
  DBI::dbExecute(con, "ALTER TABLE run_tags DROP COLUMN created_at_utc")
  DBI::dbDisconnect(con, shutdown = TRUE)
  failure_class <- function() class(tryCatch(init_and_close(second), error = identity))
  first_failure <- NULL
  testthat::expect_identical(validations(first_failure <- failure_class()), 1L)
  testthat::expect_true("error" %in% first_failure)
  testthat::expect_identical(validations(testthat::expect_identical(failure_class(), first_failure)), 1L)
})
