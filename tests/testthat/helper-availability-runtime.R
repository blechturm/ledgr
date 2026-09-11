availability_runtime_fixture <- function(days = 5L,
                                         bar_days = seq_len(days),
                                         membership = NULL,
                                         status = NULL,
                                         lifetime = NULL) {
  dates <- as.Date("2020-01-01") + seq_len(days) - 1L
  session_family <- ledgr_facts_sessions(
    data.frame(
      session_date = dates,
      status = "open",
      session_open = "09:30:00",
      session_close = "16:00:00",
      knowledge_time = as.POSIXct(dates, tz = "UTC") - 1,
      stringsAsFactors = FALSE
    ),
    venue_id = "XNYS"
  )
  families <- list(session_family)
  if (!is.null(membership)) families <- c(families, list(membership))
  if (!is.null(status)) families <- c(families, list(status))
  if (!is.null(lifetime)) families <- c(families, list(lifetime))
  facts <- do.call(ledgr_facts, families)
  ts <- as.POSIXct(paste(dates[bar_days], "16:00:00"), tz = "UTC")
  bars <- data.frame(
    ts_utc = ts,
    instrument_id = "AAA",
    open = 100 + bar_days,
    high = 101 + bar_days,
    low = 99 + bar_days,
    close = 100 + bar_days,
    volume = 1000,
    stringsAsFactors = FALSE
  )
  ledgr_snapshot_from_df(
    bars,
    instruments_df = data.frame(instrument_id = "AAA"),
    facts = facts
  )
}

availability_last_state <- function(bt) {
  opened <- ledgr_open_duckdb_with_retry(bt$db_path)
  on.exit({
    DBI::dbDisconnect(opened$con, shutdown = TRUE)
    duckdb::duckdb_shutdown(opened$drv)
  }, add = TRUE)
  json <- DBI::dbGetQuery(
    opened$con,
    "SELECT state_json FROM strategy_state WHERE run_id = ? ORDER BY ts_utc DESC LIMIT 1",
    params = list(bt$run_id)
  )$state_json[[1L]]
  ledgr_json_read_nested(json)
}

availability_state_rows <- function(bt) {
  opened <- ledgr_open_duckdb_with_retry(bt$db_path)
  on.exit({
    DBI::dbDisconnect(opened$con, shutdown = TRUE)
    duckdb::duckdb_shutdown(opened$drv)
  }, add = TRUE)
  DBI::dbGetQuery(
    opened$con,
    "SELECT ts_utc, state_json FROM strategy_state WHERE run_id = ? ORDER BY ts_utc",
    params = list(bt$run_id)
  )
}

availability_run_config <- function(bt) {
  opened <- ledgr_open_duckdb_with_retry(bt$db_path)
  on.exit({
    DBI::dbDisconnect(opened$con, shutdown = TRUE)
    duckdb::duckdb_shutdown(opened$drv)
  }, add = TRUE)
  json <- DBI::dbGetQuery(
    opened$con,
    "SELECT config_json FROM runs WHERE run_id = ?",
    params = list(bt$run_id)
  )$config_json[[1L]]
  ledgr_json_read_config(json)
}
