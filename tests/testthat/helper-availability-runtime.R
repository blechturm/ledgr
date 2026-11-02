availability_runtime_fixture <- function(days = 5L,
                                         bar_days = seq_len(days),
                                         membership = NULL,
                                         status = NULL,
                                         lifetime = NULL,
                                         session_open = "09:30:00",
                                         session_close = "16:00:00") {
  dates <- as.Date("2020-01-01") + seq_len(days) - 1L
  session_family <- ledgr_facts_sessions(
    data.frame(
      session_date = dates,
      status = "open",
      session_open = session_open,
      session_close = session_close,
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
  ts <- as.POSIXct(paste(dates[bar_days], session_close), tz = "UTC")
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
    facts = facts, price_basis = "split_adjusted"
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
    "SELECT state_json FROM strategy_state WHERE run_id = ? AND state_json <> ? ORDER BY ts_utc DESC LIMIT 1",
    params = list(bt$run_id, ledgr:::ledgr_strategy_state_cursor_marker)
  )$state_json
  config <- ledgr_json_read_config(DBI::dbGetQuery(
    opened$con, "SELECT config_json FROM runs WHERE run_id = ?",
    params = list(bt$run_id)
  )$config_json[[1L]])
  declaration <- ledgr:::ledgr_strategy_state_from_identity(config$strategy_state)
  if (length(json) == 0L) {
    return(ledgr:::ledgr_strategy_state_defaults(
      declaration, config$universe$instrument_ids
    ))
  }
  ledgr:::ledgr_strategy_state_decode(json[[1L]], declaration)$values
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

availability_state_values <- function(bt) {
  rows <- availability_state_rows(bt)
  config <- availability_run_config(bt)
  declaration <- ledgr:::ledgr_strategy_state_from_identity(config$strategy_state)
  current <- ledgr:::ledgr_strategy_state_defaults(
    declaration, config$universe$instrument_ids
  )
  lapply(rows$state_json, function(json) {
    if (!identical(json, ledgr:::ledgr_strategy_state_cursor_marker)) {
      current <<- ledgr:::ledgr_strategy_state_decode(json, declaration)$values
    }
    current
  })
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
