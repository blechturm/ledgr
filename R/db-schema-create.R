#' Create ledgr DuckDB schema (v0.1.0)
#'
#' Creates all required v0.1.0 tables. Safe to call multiple times.
#'
#' @param con A DBI connection to DuckDB.
#' @return Invisibly returns `TRUE` on success.
#' @export
ledgr_create_schema <- function(con) {
  if (!DBI::dbIsValid(con)) {
    stop("`con` must be a valid DBI connection.", call. = FALSE)
  }

  ddl <- c(
    "
    CREATE TABLE IF NOT EXISTS runs (
      run_id TEXT NOT NULL PRIMARY KEY,
      created_at_utc TIMESTAMP NOT NULL,
      status TEXT NOT NULL CHECK (status IN ('CREATED','RUNNING','COMPLETED','FAILED')),
      config_hash TEXT NOT NULL,
      data_hash TEXT NOT NULL,
      engine_version TEXT NOT NULL,
      seed INTEGER NOT NULL,
      initial_cash DOUBLE NOT NULL
    )
    ",
    "
    CREATE TABLE IF NOT EXISTS ledger_events (
      event_id TEXT NOT NULL PRIMARY KEY,
      run_id TEXT NOT NULL,
      ts_utc TIMESTAMP NOT NULL,
      event_type TEXT NOT NULL,
      instrument_id TEXT,
      qty DOUBLE,
      price DOUBLE,
      cash_delta DOUBLE,
      event_seq INTEGER NOT NULL,
      UNIQUE(run_id, event_seq)
    )
    ",
    "
    CREATE TABLE IF NOT EXISTS equity_curve (
      run_id TEXT NOT NULL,
      ts_utc TIMESTAMP NOT NULL,
      cash DOUBLE NOT NULL,
      gross_exposure DOUBLE NOT NULL,
      net_exposure DOUBLE NOT NULL,
      equity DOUBLE NOT NULL,
      PRIMARY KEY (run_id, ts_utc)
    )
    ",
    "
    CREATE TABLE IF NOT EXISTS bars (
      instrument_id TEXT NOT NULL,
      ts_utc TIMESTAMP NOT NULL,
      open DOUBLE NOT NULL,
      high DOUBLE NOT NULL,
      low DOUBLE NOT NULL,
      close DOUBLE NOT NULL,
      volume DOUBLE NOT NULL,
      PRIMARY KEY (instrument_id, ts_utc)
    )
    "
  )

  DBI::dbWithTransaction(con, {
    for (sql in ddl) {
      DBI::dbExecute(con, sql)
    }
  })

  invisible(TRUE)
}

