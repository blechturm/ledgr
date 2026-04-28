ledgr_experiment_store_schema_version <- 106L

ledgr_experiment_store_table_exists <- function(con, table_name) {
  DBI::dbGetQuery(
    con,
    "
    SELECT COUNT(*) AS n
    FROM information_schema.tables
    WHERE table_schema = 'main'
      AND table_name = ?
    ",
    params = list(table_name)
  )$n[[1]] > 0
}

ledgr_experiment_store_columns <- function(con, table_name) {
  DBI::dbGetQuery(
    con,
    "
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'main'
      AND table_name = ?
    ORDER BY ordinal_position
    ",
    params = list(table_name)
  )$column_name
}

ledgr_experiment_store_has_artifacts <- function(con) {
  known_tables <- c(
    "runs",
    "ledger_events",
    "features",
    "equity_curve",
    "snapshots",
    "snapshot_bars",
    "snapshot_instruments",
    "run_provenance",
    "run_telemetry",
    "run_tags",
    "ledgr_schema_metadata"
  )
  any(vapply(known_tables, function(table_name) ledgr_experiment_store_table_exists(con, table_name), logical(1)))
}

ledgr_experiment_store_add_column <- function(con, table_name, column_name, sql_def) {
  if (column_name %in% ledgr_experiment_store_columns(con, table_name)) {
    return(invisible(FALSE))
  }
  DBI::dbExecute(
    con,
    sprintf("ALTER TABLE %s ADD COLUMN %s %s", table_name, column_name, sql_def)
  )
  invisible(TRUE)
}

ledgr_experiment_store_add_execution_mode_column <- function(con, table_name) {
  ok <- tryCatch(
    {
      ledgr_experiment_store_add_column(
        con,
        table_name,
        "execution_mode",
        "TEXT CHECK (execution_mode IS NULL OR execution_mode IN ('audit_log','db_live'))"
      )
      TRUE
    },
    error = function(e) FALSE
  )
  if (!isTRUE(ok)) {
    ledgr_experiment_store_add_column(con, table_name, "execution_mode", "TEXT")
  }
  invisible(TRUE)
}

ledgr_experiment_store_ensure_run_telemetry_columns <- function(con) {
  if (!ledgr_experiment_store_table_exists(con, "run_telemetry")) {
    return(invisible(FALSE))
  }
  ledgr_experiment_store_add_column(con, "run_telemetry", "persist_features", "BOOLEAN")
  invisible(TRUE)
}

ledgr_experiment_store_version <- function(con) {
  if (!ledgr_experiment_store_table_exists(con, "ledgr_schema_metadata")) {
    return(0L)
  }
  row <- DBI::dbGetQuery(
    con,
    "
    SELECT value
    FROM ledgr_schema_metadata
    WHERE key = 'experiment_store_schema_version'
    "
  )
  if (nrow(row) == 0L) {
    return(0L)
  }
  version <- suppressWarnings(as.integer(row$value[[1]]))
  if (length(version) != 1L || is.na(version)) {
    rlang::abort(
      "Experiment store schema version is not a valid integer.",
      class = "ledgr_invalid_schema_version"
    )
  }
  version
}

ledgr_experiment_store_assert_supported <- function(con) {
  version <- ledgr_experiment_store_version(con)
  if (version > ledgr_experiment_store_schema_version) {
    rlang::abort(
      sprintf(
        "This DuckDB file uses ledgr experiment-store schema version %s, but this ledgr build supports only %s.",
        version,
        ledgr_experiment_store_schema_version
      ),
      class = "ledgr_future_schema_version"
    )
  }
  invisible(version)
}

ledgr_experiment_store_check_schema <- function(con, write = FALSE, inform = FALSE) {
  version <- ledgr_experiment_store_assert_supported(con)
  if (!isTRUE(write)) {
    return(invisible(list(
      schema_version = version,
      is_legacy = version < ledgr_experiment_store_schema_version
    )))
  }
  if (version < ledgr_experiment_store_schema_version) {
    ledgr_experiment_store_migrate(con, from_version = version, inform = inform)
  }
  ledgr_experiment_store_ensure_run_telemetry_columns(con)
  invisible(list(schema_version = ledgr_experiment_store_schema_version, is_legacy = FALSE))
}

ledgr_experiment_store_migrate <- function(con, from_version = NULL, simulate_failure = FALSE, inform = TRUE) {
  if (is.null(from_version)) {
    from_version <- ledgr_experiment_store_assert_supported(con)
  } else if (from_version > ledgr_experiment_store_schema_version) {
    ledgr_experiment_store_assert_supported(con)
  }

  if (from_version >= ledgr_experiment_store_schema_version) {
    return(invisible(FALSE))
  }

  DBI::dbWithTransaction(con, {
    DBI::dbExecute(
      con,
      "
      CREATE TABLE IF NOT EXISTS ledgr_schema_metadata (
        key TEXT NOT NULL PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at_utc TIMESTAMP NOT NULL
      )
      "
    )

    if (ledgr_experiment_store_table_exists(con, "runs")) {
      ledgr_experiment_store_add_column(con, "runs", "label", "TEXT")
      ledgr_experiment_store_add_column(con, "runs", "archived", "BOOLEAN")
      ledgr_experiment_store_add_column(con, "runs", "archived_at_utc", "TIMESTAMP")
      ledgr_experiment_store_add_column(con, "runs", "archive_reason", "TEXT")
      ledgr_experiment_store_add_execution_mode_column(con, "runs")
      ledgr_experiment_store_add_column(con, "runs", "schema_version", "INTEGER")
      DBI::dbExecute(con, "UPDATE runs SET archived = FALSE WHERE archived IS NULL")
      DBI::dbExecute(
        con,
        "UPDATE runs SET schema_version = ? WHERE schema_version IS NULL",
        params = list(ledgr_experiment_store_schema_version)
      )
    }

    DBI::dbExecute(
      con,
      "
      -- run_provenance and run_telemetry are populated by later v0.1.5
      -- tickets. LDG-801 creates them up front so v0.1.4 stores migrate once.
      CREATE TABLE IF NOT EXISTS run_provenance (
        run_id TEXT NOT NULL PRIMARY KEY,
        strategy_type TEXT,
        strategy_source TEXT,
        strategy_source_hash TEXT,
        strategy_source_capture_method TEXT,
        strategy_params_json TEXT,
        strategy_params_hash TEXT,
        reproducibility_level TEXT,
        ledgr_version TEXT,
        R_version TEXT,
        dependency_versions_json TEXT,
        created_at_utc TIMESTAMP
      )
      "
    )

    DBI::dbExecute(
      con,
      "
      -- See run_provenance note above: LDG-801 owns schema, later tickets own
      -- writers.
      CREATE TABLE IF NOT EXISTS run_telemetry (
        run_id TEXT NOT NULL PRIMARY KEY,
        status TEXT,
        execution_mode TEXT CHECK (execution_mode IS NULL OR execution_mode IN ('audit_log','db_live')),
        elapsed_sec DOUBLE,
        pulse_count INTEGER,
        persist_features BOOLEAN,
        feature_cache_hits INTEGER,
        feature_cache_misses INTEGER,
        updated_at_utc TIMESTAMP
      )
      "
    )

    DBI::dbExecute(
      con,
      "
      -- Mutable run metadata. Tags are deliberately outside run identity and
      -- do not affect comparison or extraction semantics.
      CREATE TABLE IF NOT EXISTS run_tags (
        run_id TEXT NOT NULL,
        tag TEXT NOT NULL,
        created_at_utc TIMESTAMP NOT NULL,
        PRIMARY KEY (run_id, tag)
      )
      "
    )

    if (ledgr_experiment_store_table_exists(con, "runs")) {
      DBI::dbExecute(
        con,
        "
        INSERT INTO run_provenance (
          run_id,
          strategy_type,
          strategy_source,
          strategy_source_hash,
          strategy_source_capture_method,
          strategy_params_json,
          strategy_params_hash,
          reproducibility_level,
          ledgr_version,
          R_version,
          dependency_versions_json,
          created_at_utc
        )
        SELECT
          r.run_id,
          'legacy',
          NULL,
          NULL,
          'legacy_pre_provenance',
          NULL,
          NULL,
          'legacy',
          NULL,
          NULL,
          NULL,
          COALESCE(r.created_at_utc, CURRENT_TIMESTAMP)
        FROM runs r
        LEFT JOIN run_provenance p ON p.run_id = r.run_id
        WHERE p.run_id IS NULL
        "
      )
    }

    if (isTRUE(simulate_failure)) {
      rlang::abort(
        "Simulated experiment-store migration failure.",
        class = "ledgr_schema_migration_simulated_failure"
      )
    }

    # The schema version marker is deliberately written last. A failed
    # transaction must leave the store classified as the previous schema.
    DBI::dbExecute(
      con,
      "
      INSERT OR REPLACE INTO ledgr_schema_metadata (key, value, updated_at_utc)
      VALUES ('experiment_store_schema_version', ?, ?)
      ",
      params = list(
        as.character(ledgr_experiment_store_schema_version),
        as.POSIXct(Sys.time(), tz = "UTC")
      )
    )
  })

  if (isTRUE(inform)) {
    rlang::inform(
      sprintf(
        "Upgraded ledgr experiment-store schema from version %s to %s.",
        from_version,
        ledgr_experiment_store_schema_version
      ),
      class = "ledgr_schema_migrated"
    )
  }
  invisible(TRUE)
}
