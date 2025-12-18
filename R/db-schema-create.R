#' Create ledgr DuckDB schema (v0.1.0)
#'
#' Creates all required v0.1.0 tables and forward-migrates older schemas.
#'
#' @param con A DBI connection to DuckDB.
#' @return Invisibly returns `TRUE` on success.
#' @export
ledgr_create_schema <- function(con) {
  if (!DBI::dbIsValid(con)) {
    stop("`con` must be a valid DBI connection.", call. = FALSE)
  }

  schema <- "main"

  normalize_type <- function(x) {
    normalize_one <- function(one) {
      one <- toupper(trimws(one))
      one <- gsub("\\s+", " ", one)
      if (one %in% c("VARCHAR", "CHAR", "BPCHAR", "STRING")) return("TEXT")
      if (one %in% c("INTEGER", "INT", "INT4", "BIGINT", "INT8", "SMALLINT", "INT2", "UBIGINT", "UINTEGER", "USMALLINT")) return("INTEGER")
      if (one %in% c("DOUBLE", "DOUBLE PRECISION", "FLOAT", "FLOAT4", "FLOAT8", "REAL", "DECIMAL", "NUMERIC")) return("DOUBLE")
      if (one %in% c("TIMESTAMP", "TIMESTAMP WITH TIME ZONE", "TIMESTAMPTZ")) return("TIMESTAMP")
      if (one %in% c("BOOLEAN", "BOOL")) return("BOOLEAN")
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

  add_column_if_missing <- function(table_name, column_name, sql_def) {
    cols <- get_columns(table_name)$column_name
    if (column_name %in% cols) return(invisible(FALSE))
    DBI::dbExecute(con, sprintf("ALTER TABLE %s ADD COLUMN %s %s", table_name, column_name, sql_def))
    invisible(TRUE)
  }

  recreate_table <- function(table_name, create_sql, insert_sql = NULL) {
    tmp <- paste0(table_name, "_new")
    DBI::dbExecute(con, sprintf("DROP TABLE IF EXISTS %s", tmp))
    DBI::dbExecute(con, gsub(paste0("CREATE TABLE IF NOT EXISTS ", table_name), paste0("CREATE TABLE ", tmp), create_sql, fixed = TRUE))
    if (!is.null(insert_sql)) {
      DBI::dbExecute(con, insert_sql)
    }
    DBI::dbExecute(con, sprintf("DROP TABLE %s", table_name))
    DBI::dbExecute(con, sprintf("ALTER TABLE %s RENAME TO %s", tmp, table_name))
    invisible(TRUE)
  }

  runs_status_allows <- function(status_value) {
    if (!table_exists("runs")) return(FALSE)

    cols <- get_columns("runs")
    required_cols <- cols$column_name[cols$is_nullable == "NO"]
    types <- normalize_type(cols$data_type)
    names(types) <- cols$column_name

    vals <- vector("list", length(required_cols))
    names(vals) <- required_cols
    for (col in required_cols) {
      t <- unname(types[[col]])
      if (col == "run_id") {
        vals[[col]] <- paste0("__ledgr_schema_check__", Sys.getpid(), "_", status_value)
      } else if (col == "status") {
        vals[[col]] <- status_value
      } else if (t == "TEXT") {
        vals[[col]] <- "x"
      } else if (t == "INTEGER") {
        vals[[col]] <- 1L
      } else if (t == "DOUBLE") {
        vals[[col]] <- 1.0
      } else if (t == "TIMESTAMP") {
        vals[[col]] <- as.POSIXct("2000-01-01 00:00:00", tz = "UTC")
      } else if (t == "BOOLEAN") {
        vals[[col]] <- FALSE
      } else {
        vals[[col]] <- "x"
      }
    }

    sql <- sprintf(
      "INSERT INTO runs (%s) VALUES (%s)",
      paste(required_cols, collapse = ", "),
      paste(rep("?", length(required_cols)), collapse = ", ")
    )

    DBI::dbExecute(con, "BEGIN TRANSACTION")
    on.exit(try(DBI::dbExecute(con, "ROLLBACK"), silent = TRUE), add = TRUE)
    ok <- tryCatch(
      {
        DBI::dbExecute(con, sql, params = unname(vals))
        TRUE
      },
      error = function(e) FALSE
    )
    ok
  }

  runs_is_compliant <- function() {
    if (!table_exists("runs")) return(FALSE)
    cols <- get_columns("runs")$column_name
    required_cols <- c(
      "run_id",
      "created_at_utc",
      "engine_version",
      "config_json",
      "config_hash",
      "data_hash",
      "status",
      "error_msg"
    )
    if (!all(required_cols %in% cols)) return(FALSE)
    if (!runs_status_allows("DONE")) return(FALSE)
    if (runs_status_allows("INVALID")) return(FALSE)
    TRUE
  }

  ddl_runs <- "
    CREATE TABLE IF NOT EXISTS runs (
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

  ddl_instruments <- "
    CREATE TABLE IF NOT EXISTS instruments (
      instrument_id TEXT NOT NULL PRIMARY KEY,
      symbol TEXT,
      currency TEXT,
      asset_class TEXT DEFAULT 'EQUITY'
    )
  "

  ddl_bars <- "
    CREATE TABLE IF NOT EXISTS bars (
      instrument_id TEXT NOT NULL,
      ts_utc TIMESTAMP NOT NULL,
      open DOUBLE NOT NULL,
      high DOUBLE NOT NULL,
      low DOUBLE NOT NULL,
      close DOUBLE NOT NULL,
      volume DOUBLE,
      gap_type TEXT NOT NULL DEFAULT 'NONE' CHECK (gap_type IN ('NONE','MISSING','SOURCE_ERROR','HOLIDAY_MISMATCH')),
      is_synthetic BOOLEAN NOT NULL DEFAULT FALSE,
      PRIMARY KEY (instrument_id, ts_utc)
    )
  "

  ddl_features <- "
    CREATE TABLE IF NOT EXISTS features (
      run_id TEXT NOT NULL,
      instrument_id TEXT NOT NULL,
      ts_utc TIMESTAMP NOT NULL,
      feature_name TEXT NOT NULL,
      feature_value DOUBLE,
      PRIMARY KEY (run_id, instrument_id, ts_utc, feature_name)
    )
  "

  ddl_ledger_events <- "
    CREATE TABLE IF NOT EXISTS ledger_events (
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

  ddl_equity_curve <- "
    CREATE TABLE IF NOT EXISTS equity_curve (
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

  DBI::dbExecute(con, ddl_instruments)
  DBI::dbExecute(con, ddl_features)
  DBI::dbExecute(con, ddl_equity_curve)

  if (!runs_is_compliant()) {
    if (table_exists("runs")) {
      old_cols <- get_columns("runs")$column_name
      if (!("run_id" %in% old_cols)) {
        stop("Cannot migrate runs table: missing required column run_id.", call. = FALSE)
      }

      expr <- function(col) {
        if (col %in% old_cols) {
          if (col == "status") return("CASE WHEN status = 'COMPLETED' THEN 'DONE' ELSE status END")
          return(col)
        }
        if (col == "created_at_utc") return("CURRENT_TIMESTAMP")
        if (col == "status") return("'CREATED'")
        "NULL"
      }

      target_cols <- c("run_id", "created_at_utc", "engine_version", "config_json", "config_hash", "data_hash", "status", "error_msg")
      insert_sql <- sprintf(
        "INSERT INTO runs_new (%s) SELECT %s FROM runs",
        paste(target_cols, collapse = ", "),
        paste(vapply(target_cols, expr, character(1)), collapse = ", ")
      )

      recreate_table("runs", ddl_runs, insert_sql = insert_sql)
    } else {
      DBI::dbExecute(con, ddl_runs)
    }
  }

  # instruments: ensure required columns exist (no destructive migration)
  add_column_if_missing("instruments", "symbol", "TEXT")
  add_column_if_missing("instruments", "currency", "TEXT")
  add_column_if_missing("instruments", "asset_class", "TEXT DEFAULT 'EQUITY'")

  # bars: recreate if volume is NOT NULL to allow NULL per spec; otherwise add missing columns
  if (!table_exists("bars")) {
    DBI::dbExecute(con, ddl_bars)
  } else {
    bars_cols <- get_columns("bars")
    if ("volume" %in% bars_cols$column_name) {
      vol_nullable <- bars_cols$is_nullable[bars_cols$column_name == "volume"][[1]]
      if (identical(vol_nullable, "NO")) {
        old_cols <- bars_cols$column_name
        expr <- function(col) {
          if (col %in% old_cols) return(col)
          if (col == "gap_type") return("'NONE'")
          if (col == "is_synthetic") return("FALSE")
          "NULL"
        }
        target_cols <- c("instrument_id", "ts_utc", "open", "high", "low", "close", "volume", "gap_type", "is_synthetic")
        insert_sql <- sprintf(
          "INSERT INTO bars_new (%s) SELECT %s FROM bars",
          paste(target_cols, collapse = ", "),
          paste(vapply(target_cols, expr, character(1)), collapse = ", ")
        )
        recreate_table("bars", ddl_bars, insert_sql = insert_sql)
      }
    }

    add_column_if_missing("bars", "volume", "DOUBLE")
    add_column_if_missing("bars", "gap_type", "TEXT NOT NULL DEFAULT 'NONE'")
    add_column_if_missing("bars", "is_synthetic", "BOOLEAN NOT NULL DEFAULT FALSE")
  }

  # features: ensure exists (no destructive migration)
  if (!table_exists("features")) {
    DBI::dbExecute(con, ddl_features)
  }

  # ledger_events: add missing columns; enforce unique+not-null semantics by recreating when needed
  if (!table_exists("ledger_events")) {
    DBI::dbExecute(con, ddl_ledger_events)
  } else {
    le_cols <- get_columns("ledger_events")
    required_not_null <- c("event_id", "run_id", "ts_utc", "event_type", "event_seq")
    needs_recreate <- any(!(required_not_null %in% le_cols$column_name)) ||
      any(le_cols$is_nullable[match(required_not_null, le_cols$column_name)] != "NO", na.rm = TRUE)
    if (needs_recreate) {
      old_cols <- le_cols$column_name
      expr <- function(col) {
        if (col %in% old_cols) return(col)
        if (col == "event_type") return("'FILL'")
        if (col == "meta_json") return("'{}'")
        "NULL"
      }
      target_cols <- c("event_id", "run_id", "ts_utc", "event_type", "instrument_id", "side", "qty", "price", "fee", "meta_json", "event_seq")
      insert_sql <- sprintf(
        "INSERT INTO ledger_events_new (%s) SELECT %s FROM ledger_events",
        paste(target_cols, collapse = ", "),
        paste(vapply(target_cols, expr, character(1)), collapse = ", ")
      )
      recreate_table("ledger_events", ddl_ledger_events, insert_sql = insert_sql)
    } else {
      add_column_if_missing("ledger_events", "side", "TEXT")
      add_column_if_missing("ledger_events", "fee", "DOUBLE")
      add_column_if_missing("ledger_events", "meta_json", "TEXT")
      add_column_if_missing("ledger_events", "event_seq", "INTEGER NOT NULL")
    }
  }

  # equity_curve: ensure required columns exist (no destructive migration)
  if (!table_exists("equity_curve")) {
    DBI::dbExecute(con, ddl_equity_curve)
  } else {
    add_column_if_missing("equity_curve", "cash", "DOUBLE")
    add_column_if_missing("equity_curve", "positions_value", "DOUBLE")
    add_column_if_missing("equity_curve", "equity", "DOUBLE")
    add_column_if_missing("equity_curve", "realized_pnl", "DOUBLE")
    add_column_if_missing("equity_curve", "unrealized_pnl", "DOUBLE")
  }

  invisible(TRUE)
}
