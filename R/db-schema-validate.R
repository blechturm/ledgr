#' Validate ledgr DuckDB schema (v0.1.0)
#'
#' Validates required tables, columns, types, primary keys, UNIQUE constraints,
#' and required behavioral constraints.
#'
#' @param con A DBI connection to DuckDB.
#' @return Invisibly returns `TRUE` on success.
#' @examples
#' db_path <- tempfile(fileext = ".duckdb")
#' con <- ledgr_db_init(db_path)
#' ledgr_validate_schema(con)
#' DBI::dbDisconnect(con, shutdown = TRUE)
#' @export
ledgr_validate_schema <- function(con) {
  if (!DBI::dbIsValid(con)) {
    stop("`con` must be a valid DBI connection.", call. = FALSE)
  }

  schema <- "main"

  required <- list(
    runs = list(
      columns = c(
        run_id = "TEXT",
        created_at_utc = "TIMESTAMP",
        engine_version = "TEXT",
        config_json = "TEXT",
        config_hash = "TEXT",
        data_hash = "TEXT",
        snapshot_id = "TEXT",
        status = "TEXT",
        error_msg = "TEXT",
        label = "TEXT",
        archived = "BOOLEAN",
        archived_at_utc = "TIMESTAMP",
        archive_reason = "TEXT",
        execution_mode = "TEXT",
        schema_version = "INTEGER"
      ),
      pk = c("run_id")
    ),
    ledgr_schema_metadata = list(
      columns = c(
        key = "TEXT",
        value = "TEXT",
        updated_at_utc = "TIMESTAMP"
      ),
      pk = c("key"),
      not_null = c("key", "value", "updated_at_utc")
    ),
    run_provenance = list(
      columns = c(
        run_id = "TEXT",
        strategy_type = "TEXT",
        strategy_source = "TEXT",
        strategy_source_hash = "TEXT",
        strategy_source_capture_method = "TEXT",
        strategy_params_json = "TEXT",
        strategy_params_hash = "TEXT",
        reproducibility_level = "TEXT",
        ledgr_version = "TEXT",
        R_version = "TEXT",
        dependency_versions_json = "TEXT",
        created_at_utc = "TIMESTAMP"
      ),
      pk = c("run_id"),
      not_null = c("run_id")
    ),
    run_telemetry = list(
      columns = c(
        run_id = "TEXT",
        status = "TEXT",
        execution_mode = "TEXT",
        elapsed_sec = "DOUBLE",
        pulse_count = "INTEGER",
        persist_features = "BOOLEAN",
        feature_cache_hits = "INTEGER",
        feature_cache_misses = "INTEGER",
        updated_at_utc = "TIMESTAMP"
      ),
      pk = c("run_id"),
      not_null = c("run_id")
    ),
    run_tags = list(
      columns = c(
        run_id = "TEXT",
        tag = "TEXT",
        created_at_utc = "TIMESTAMP"
      ),
      pk = c("run_id", "tag"),
      not_null = c("run_id", "tag", "created_at_utc")
    ),
    instruments = list(
      columns = c(
        instrument_id = "TEXT",
        symbol = "TEXT",
        currency = "TEXT",
        asset_class = "TEXT"
      ),
      pk = c("instrument_id")
    ),
    bars = list(
      columns = c(
        instrument_id = "TEXT",
        ts_utc = "TIMESTAMP",
        open = "DOUBLE",
        high = "DOUBLE",
        low = "DOUBLE",
        close = "DOUBLE",
        volume = "DOUBLE",
        gap_type = "TEXT",
        is_synthetic = "BOOLEAN"
      ),
      pk = c("instrument_id", "ts_utc")
    ),
    features = list(
      columns = c(
        run_id = "TEXT",
        instrument_id = "TEXT",
        ts_utc = "TIMESTAMP",
        feature_name = "TEXT",
        feature_value = "DOUBLE"
      ),
      pk = c("run_id", "instrument_id", "ts_utc", "feature_name")
    ),
    ledger_events = list(
      columns = c(
        event_id = "TEXT",
        run_id = "TEXT",
        ts_utc = "TIMESTAMP",
        event_type = "TEXT",
        instrument_id = "TEXT",
        side = "TEXT",
        qty = "DOUBLE",
        price = "DOUBLE",
        fee = "DOUBLE",
        meta_json = "TEXT",
        event_seq = "INTEGER"
      ),
      pk = c("event_id"),
      unique = list(c("run_id", "event_seq")),
      not_null = c("event_id", "run_id", "ts_utc", "event_type", "event_seq")
    ),
    equity_curve = list(
      columns = c(
        run_id = "TEXT",
        ts_utc = "TIMESTAMP",
        cash = "DOUBLE",
        positions_value = "DOUBLE",
        equity = "DOUBLE",
        realized_pnl = "DOUBLE",
        unrealized_pnl = "DOUBLE"
      ),
      pk = c("run_id", "ts_utc")
    ),
    strategy_state = list(
      columns = c(
        run_id = "TEXT",
        ts_utc = "TEXT",
        state_json = "TEXT"
      ),
      pk = c("run_id", "ts_utc"),
      not_null = c("run_id", "ts_utc", "state_json")
    ),
    snapshots = list(
      columns = c(
        snapshot_id = "TEXT",
        status = "TEXT",
        created_at_utc = "TIMESTAMP",
        sealed_at_utc = "TIMESTAMP",
        snapshot_hash = "TEXT",
        meta_json = "TEXT",
        error_msg = "TEXT"
      ),
      pk = c("snapshot_id"),
      not_null = c("snapshot_id", "status", "created_at_utc")
    ),
    snapshot_instruments = list(
      columns = c(
        snapshot_id = "TEXT",
        instrument_id = "TEXT",
        symbol = "TEXT",
        currency = "TEXT",
        asset_class = "TEXT",
        multiplier = "DOUBLE",
        tick_size = "DOUBLE",
        meta_json = "TEXT"
      ),
      pk = c("snapshot_id", "instrument_id"),
      not_null = c("snapshot_id", "instrument_id")
    ),
    snapshot_bars = list(
      columns = c(
        snapshot_id = "TEXT",
        instrument_id = "TEXT",
        ts_utc = "TIMESTAMP",
        open = "DOUBLE",
        high = "DOUBLE",
        low = "DOUBLE",
        close = "DOUBLE",
        volume = "DOUBLE"
      ),
      pk = c("snapshot_id", "instrument_id", "ts_utc"),
      not_null = c("snapshot_id", "instrument_id", "ts_utc", "open", "high", "low", "close")
    )
  )

  normalize_type <- function(x) {
    normalize_one <- function(one) {
      one <- toupper(trimws(one))
      one <- gsub("\\s+", " ", one)
      if (one %in% c("VARCHAR", "CHAR", "BPCHAR", "STRING")) return("TEXT")
      if (one %in% c("INTEGER", "INT", "INT4", "BIGINT", "INT8", "SMALLINT", "INT2", "UBIGINT", "UINTEGER", "USMALLINT")) return("INTEGER")
      if (one %in% c("DOUBLE", "DOUBLE PRECISION", "FLOAT", "FLOAT4", "FLOAT8", "REAL", "DECIMAL", "NUMERIC")) return("DOUBLE")
      if (one %in% c("TIMESTAMP", "TIMESTAMP WITH TIME ZONE", "TIMESTAMPTZ")) return("TIMESTAMP")
      one
    }

    vapply(x, normalize_one, character(1))
  }

  table_exists <- function(table_name) {
    q <- "
      SELECT COUNT(*) AS n
      FROM information_schema.tables
      WHERE table_schema = ?
        AND table_name = ?
    "
    DBI::dbGetQuery(con, q, params = list(schema, table_name))$n[[1]] > 0
  }

  ledgr_experiment_store_check_schema(con, write = FALSE)

  get_columns <- function(table_name) {
    q <- "
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns
      WHERE table_schema = ?
        AND table_name = ?
      ORDER BY ordinal_position
    "
    DBI::dbGetQuery(con, q, params = list(schema, table_name))
  }

  get_pk_columns <- function(table_name) {
    q <- "
      SELECT kcu.column_name
      FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu
        ON tc.constraint_name = kcu.constraint_name
       AND tc.table_schema = kcu.table_schema
       AND tc.table_name = kcu.table_name
      WHERE tc.table_schema = ?
        AND tc.table_name = ?
        AND tc.constraint_type = 'PRIMARY KEY'
      ORDER BY kcu.ordinal_position
    "
    DBI::dbGetQuery(con, q, params = list(schema, table_name))$column_name
  }

  get_unique_sets <- function(table_name) {
    q <- "
      SELECT tc.constraint_name, kcu.column_name, kcu.ordinal_position
      FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu
        ON tc.constraint_name = kcu.constraint_name
       AND tc.table_schema = kcu.table_schema
       AND tc.table_name = kcu.table_name
      WHERE tc.table_schema = ?
        AND tc.table_name = ?
        AND tc.constraint_type = 'UNIQUE'
      ORDER BY tc.constraint_name, kcu.ordinal_position
    "
    out <- DBI::dbGetQuery(con, q, params = list(schema, table_name))
    if (nrow(out) == 0) return(list())
    split(out$column_name, out$constraint_name)
  }

  check_status_constraint_metadata <- function(table_name, expected_values, label) {
    checks <- tryCatch(
      DBI::dbGetQuery(
        con,
        "
        SELECT expression
        FROM duckdb_constraints()
        WHERE table_name = ?
          AND constraint_type = 'CHECK'
        ",
        params = list(table_name)
      ),
      error = function(e) data.frame(expression = character())
    )
    expressions <- as.character(checks$expression)
    status_expr <- expressions[grepl("\\bstatus\\b\\s+IN\\s*\\(", expressions, ignore.case = TRUE)]
    if (length(status_expr) == 0L) {
      stop(
        sprintf("%s must enforce status values (%s).", label, paste(expected_values, collapse = ", ")),
        call. = FALSE
      )
    }
    values <- unique(unlist(regmatches(
      status_expr,
      gregexpr("'[^']+'", status_expr)
    )))
    values <- gsub("^'|'$", "", values)
    if (!setequal(values, expected_values)) {
      stop(
        sprintf("%s must enforce status values (%s).", label, paste(expected_values, collapse = ", ")),
        call. = FALSE
      )
    }
    invisible(TRUE)
  }

  check_runs_status_constraint <- function() {
    check_status_constraint_metadata(
      "runs",
      c("CREATED", "RUNNING", "DONE", "FAILED"),
      "runs.status"
    )
    invisible(TRUE)
  }

  check_snapshots_status_constraint <- function() {
    check_status_constraint_metadata(
      "snapshots",
      c("CREATED", "SEALED", "FAILED"),
      "snapshots.status"
    )
    invisible(TRUE)
  }

  for (table_name in names(required)) {
    if (!table_exists(table_name)) {
      stop(sprintf("Missing table: %s", table_name), call. = FALSE)
    }

    cols <- get_columns(table_name)
    present <- cols$column_name

    expected_types <- required[[table_name]]$columns
    expected_cols <- names(expected_types)
    missing_cols <- setdiff(expected_cols, present)
    if (length(missing_cols) > 0) {
      stop(
        sprintf(
          "Missing columns in %s: %s",
          table_name,
          paste(missing_cols, collapse = ", ")
        ),
        call. = FALSE
      )
    }

    present_types <- normalize_type(cols$data_type)
    names(present_types) <- cols$column_name
    for (col_name in expected_cols) {
      expected_type <- normalize_type(unname(expected_types[[col_name]]))
      actual_type <- normalize_type(unname(present_types[[col_name]]))
      if (!identical(actual_type, expected_type)) {
        stop(
          sprintf(
            "Column type mismatch: %s.%s expected %s, got %s",
            table_name,
            col_name,
            expected_type,
            actual_type
          ),
          call. = FALSE
        )
      }
    }

    if (!is.null(required[[table_name]]$not_null)) {
      expected_not_null <- required[[table_name]]$not_null
      is_nullable <- cols$is_nullable
      names(is_nullable) <- cols$column_name
      nullable_violations <- expected_not_null[unname(is_nullable[expected_not_null]) != "NO"]
      if (length(nullable_violations) > 0) {
        stop(
          sprintf(
            "Expected NOT NULL constraints missing for %s: %s",
            table_name,
            paste(nullable_violations, collapse = ", ")
          ),
          call. = FALSE
        )
      }
    }

    pk_expected <- required[[table_name]]$pk
    pk_actual <- get_pk_columns(table_name)
    if (!identical(pk_actual, pk_expected)) {
      stop(
        sprintf(
          "Primary key mismatch for %s: expected (%s), got (%s)",
          table_name,
          paste(pk_expected, collapse = ", "),
          paste(pk_actual, collapse = ", ")
        ),
        call. = FALSE
      )
    }

    if (!is.null(required[[table_name]]$unique)) {
      uniques <- get_unique_sets(table_name)
      for (u in required[[table_name]]$unique) {
        u_sorted <- sort(u)
        ok <- any(vapply(uniques, function(x) identical(sort(x), u_sorted), logical(1)))
        if (!ok) {
          stop(
            sprintf(
              "Missing UNIQUE constraint on %s: (%s)",
              table_name,
              paste(u, collapse = ", ")
            ),
            call. = FALSE
          )
        }
      }
    }
  }

  check_runs_status_constraint()
  check_snapshots_status_constraint()

  invisible(TRUE)
}
