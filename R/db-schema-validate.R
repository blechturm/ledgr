#' Validate ledgr DuckDB schema (v0.1.0)
#'
#' Validates required tables, columns, types, NOT NULL constraints, primary
#' keys, UNIQUE(run_id, event_seq), and the `runs.status` CHECK constraint.
#'
#' @param con A DBI connection to DuckDB.
#' @return Invisibly returns `TRUE` on success.
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
        status = "TEXT",
        config_hash = "TEXT",
        data_hash = "TEXT",
        engine_version = "TEXT",
        seed = "INTEGER",
        initial_cash = "DOUBLE"
      ),
      not_null = c(
        "run_id",
        "created_at_utc",
        "status",
        "config_hash",
        "data_hash",
        "engine_version",
        "seed",
        "initial_cash"
      ),
      pk = c("run_id")
    ),
    ledger_events = list(
      columns = c(
        event_id = "TEXT",
        run_id = "TEXT",
        ts_utc = "TIMESTAMP",
        event_type = "TEXT",
        instrument_id = "TEXT",
        qty = "DOUBLE",
        price = "DOUBLE",
        cash_delta = "DOUBLE",
        event_seq = "INTEGER"
      ),
      not_null = c(
        "event_id",
        "run_id",
        "ts_utc",
        "event_type",
        "event_seq"
      ),
      pk = c("event_id"),
      unique = list(c("run_id", "event_seq"))
    ),
    equity_curve = list(
      columns = c(
        run_id = "TEXT",
        ts_utc = "TIMESTAMP",
        cash = "DOUBLE",
        gross_exposure = "DOUBLE",
        net_exposure = "DOUBLE",
        equity = "DOUBLE"
      ),
      not_null = c(
        "run_id",
        "ts_utc",
        "cash",
        "gross_exposure",
        "net_exposure",
        "equity"
      ),
      pk = c("run_id", "ts_utc")
    ),
    bars = list(
      columns = c(
        instrument_id = "TEXT",
        ts_utc = "TIMESTAMP",
        open = "DOUBLE",
        high = "DOUBLE",
        low = "DOUBLE",
        close = "DOUBLE",
        volume = "DOUBLE"
      ),
      not_null = c(
        "instrument_id",
        "ts_utc",
        "open",
        "high",
        "low",
        "close",
        "volume"
      ),
      pk = c("instrument_id", "ts_utc")
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

  check_runs_status_constraint <- function() {
    err <- tryCatch(
      DBI::dbWithTransaction(con, {
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
            "__ledgr_schema_check__",
            as.POSIXct("2000-01-01 00:00:00", tz = "UTC"),
            "INVALID",
            "x",
            "y",
            "0.0.0",
            1L,
            1.0
          )
        )
        stop(
          "Missing or incorrect CHECK constraint on runs.status (expected IN ('CREATED','RUNNING','COMPLETED','FAILED')).",
          call. = FALSE
        )
      }),
      error = function(e) e
    )

    if (is.null(err)) {
      stop(
        "Missing or incorrect CHECK constraint on runs.status (expected IN ('CREATED','RUNNING','COMPLETED','FAILED')).",
        call. = FALSE
      )
    }

    msg <- conditionMessage(err)
    if (identical(msg, "Missing or incorrect CHECK constraint on runs.status (expected IN ('CREATED','RUNNING','COMPLETED','FAILED')).")) {
      stop(msg, call. = FALSE)
    }

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

  invisible(TRUE)
}
