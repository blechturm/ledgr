typed_accounting_connect <- function(path) {
  DBI::dbConnect(
    duckdb::duckdb(shared_home = FALSE),
    dbdir = path,
    read_only = FALSE
  )
}

typed_accounting_disconnect <- function(con) {
  DBI::dbDisconnect(con, shutdown = TRUE)
}

typed_accounting_write_wide <- function(con, events) {
  DBI::dbWriteTable(con, "events", events, overwrite = TRUE)
  invisible(TRUE)
}

typed_accounting_read_wide <- function(con) {
  columns <- paste(DBI::dbQuoteIdentifier(con, typed_accounting_columns()), collapse = ", ")
  DBI::dbGetQuery(con, sprintf("SELECT %s FROM events ORDER BY event_seq", columns))
}

typed_accounting_write_companion <- function(con, events) {
  DBI::dbWriteTable(
    con, "events", events[typed_accounting_common_columns()], overwrite = TRUE
  )
  opening <- events$source == "opening_position" & !is.na(events$source)
  cash <- events$source == "corporate_action_cash" & !is.na(events$source)
  disposition <- events$event_type == "DISPOSITION"
  DBI::dbWriteTable(
    con, "opening_event_evidence",
    events[opening, typed_accounting_opening_columns(), drop = FALSE],
    overwrite = TRUE
  )
  DBI::dbWriteTable(
    con, "cash_event_evidence",
    events[cash, typed_accounting_cash_columns(), drop = FALSE],
    overwrite = TRUE
  )
  DBI::dbWriteTable(
    con, "disposition_event_evidence",
    events[disposition, typed_accounting_disposition_columns(), drop = FALSE],
    overwrite = TRUE
  )
  DBI::dbExecute(con, "CREATE UNIQUE INDEX opening_event_seq ON opening_event_evidence(event_seq)")
  DBI::dbExecute(con, "CREATE UNIQUE INDEX cash_event_seq ON cash_event_evidence(event_seq)")
  DBI::dbExecute(con, "CREATE UNIQUE INDEX disposition_event_seq ON disposition_event_evidence(event_seq)")
  invisible(TRUE)
}

typed_accounting_companion_sql <- function(gut = FALSE) {
  source_fact <- if (isTRUE(gut)) {
    "CAST(NULL AS VARCHAR) AS source_fact_id,"
  } else {
    "COALESCE(c.source_fact_id, d.source_fact_id) AS source_fact_id,"
  }
  paste(
    "SELECT e.* ,",
    source_fact,
    "o.cost_basis,",
    "c.entitled_quantity, c.gross_cash_per_parent_unit,",
    "c.amount_policy_id, c.posting_policy_id, c.late_arrival,",
    "COALESCE(c.affected_marked_exposure, d.affected_marked_exposure) AS affected_marked_exposure,",
    "d.terminal_event, d.matched_label, d.disposition_policy_id,",
    "d.disposition_choice, d.disposition_basis, d.mark_source,",
    "d.mark_source_ts_utc, d.mark_age, d.haircut_fraction,",
    "d.position_before, d.realized_model_pnl",
    "FROM events e",
    "LEFT JOIN opening_event_evidence o USING (event_seq)",
    "LEFT JOIN cash_event_evidence c USING (event_seq)",
    "LEFT JOIN disposition_event_evidence d USING (event_seq)",
    "ORDER BY e.event_seq"
  )
}

typed_accounting_read_companion <- function(con, gut = FALSE) {
  DBI::dbGetQuery(con, typed_accounting_companion_sql(gut = gut))
}

typed_accounting_measure <- function(layout, events, path, gut = FALSE) {
  if (file.exists(path)) unlink(path)
  con <- typed_accounting_connect(path)
  on.exit(typed_accounting_disconnect(con), add = TRUE)
  writer <- if (identical(layout, "wide")) {
    typed_accounting_write_wide
  } else {
    typed_accounting_write_companion
  }
  reader <- if (identical(layout, "wide")) {
    typed_accounting_read_wide
  } else {
    function(con) typed_accounting_read_companion(con, gut = gut)
  }
  gc(FALSE)
  write_seconds <- unname(system.time(writer(con, events))[["elapsed"]])
  gc(FALSE)
  read_time <- system.time(actual <- reader(con))
  mismatches <- typed_accounting_mismatches(events, actual)
  typed_accounting_disconnect(con)
  on.exit(NULL, add = FALSE)
  data.frame(
    layout = layout,
    rows = nrow(events),
    write_seconds = write_seconds,
    read_seconds = unname(read_time[["elapsed"]]),
    db_bytes = file.info(path)$size,
    mismatched_cells = sum(mismatches),
    stringsAsFactors = FALSE
  )
}
