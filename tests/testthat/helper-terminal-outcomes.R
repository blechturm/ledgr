# Shared fixtures for the terminal-outcome and terminal-reporting blocks.

terminal_outcome_day <- function(day, time = "16:00:00") {
  as.POSIXct(paste(as.Date("2020-01-01") + day - 1L, time), tz = "UTC")
}

# One session per element of each close vector; NA means no bar that session.
terminal_outcome_snapshot <- function(closes, lifetime = NULL, corporate = NULL) {
  days <- length(closes[[1L]])
  dates <- as.Date("2020-01-01") + seq_len(days) - 1L
  sessions <- ledgr_facts_sessions(
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
  families <- list(sessions)
  if (!is.null(lifetime)) families <- c(families, list(lifetime))
  if (!is.null(corporate)) families <- c(families, list(corporate))
  bars <- do.call(rbind, lapply(names(closes), function(id) {
    close <- closes[[id]]
    keep <- which(!is.na(close))
    if (length(keep) == 0L) return(NULL)
    data.frame(
      ts_utc = terminal_outcome_day(keep),
      instrument_id = id,
      open = close[keep],
      high = close[keep] + 1,
      low = close[keep] - 1,
      close = close[keep],
      volume = 1000,
      stringsAsFactors = FALSE
    )
  }))
  ledgr_snapshot_from_df(
    bars,
    instruments_df = data.frame(instrument_id = names(closes)),
    facts = do.call(ledgr_facts, families),
    price_basis = "split_adjusted"
  )
}

terminal_outcome_lifetime <- function(id, day, label = "bankruptcy") {
  at <- terminal_outcome_day(day)
  ledgr_facts_lifetime(data.frame(
    instrument_id = id,
    effective_from = at,
    knowledge_time = at - 1,
    assertion = "known_inactive",
    terminal_event = label,
    stringsAsFactors = FALSE
  ))
}

terminal_outcome_acquisition <- function(id, day, fact_id = "acquisition-1") {
  at <- terminal_outcome_day(day)
  ledgr_facts_equity_corporate_actions(data.frame(
    fact_id = fact_id,
    subtype = "cash_acquisition",
    parent_instrument_id = id,
    entitlement_time = at,
    effective_time = at,
    knowledge_time = terminal_outcome_day(1L),
    complete = TRUE,
    provenance_tier = "snapshot_bound",
    gross_cash_validated = FALSE,
    recipient_identity_validated = FALSE,
    recipient_quantity_validated = FALSE,
    source = "terminal_outcome_fixture",
    stringsAsFactors = FALSE
  ))
}

terminal_outcome_experiment <- function(snapshot,
                                        strategy = function(ctx, params) ctx$hold(),
                                        policy = ledgr_corporate_actions_research(),
                                        valuation = ledgr_valuation_stale(1),
                                        positions = c(AAA = 2)) {
  ledgr_experiment(
    snapshot,
    strategy,
    opening = ledgr_opening(
      cash = 1000,
      positions = positions,
      cost_basis = stats::setNames(rep(100, length(positions)), names(positions))
    ),
    valuation_policy = valuation,
    corporate_action_policy = policy,
    cost_model = ledgr_cost_zero()
  )
}

terminal_outcome_tables <- function(bt) {
  opened <- ledgr_test_open_duckdb(bt$db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  query <- function(sql) DBI::dbGetQuery(opened$con, sql, params = list(bt$run_id))
  list(
    run = query("SELECT status, config_json FROM runs WHERE run_id = ?"),
    completion = query("SELECT * FROM run_completion WHERE run_id = ?"),
    diagnostics = query("SELECT * FROM run_diagnostics WHERE run_id = ? ORDER BY diagnostic_seq"),
    events = query("SELECT * FROM ledger_events WHERE run_id = ? ORDER BY event_seq"),
    equity = query("SELECT * FROM equity_curve WHERE run_id = ? ORDER BY ts_utc")
  )
}

terminal_outcome_dispositions <- function(tables) {
  events <- tables$events[tables$events$event_type == "DISPOSITION", , drop = FALSE]
  if (nrow(events) == 0L) return(list())
  lapply(seq_len(nrow(events)), function(i) {
    c(
      list(
        ts_utc = as.POSIXct(events$ts_utc[[i]], tz = "UTC"),
        instrument_id = events$instrument_id[[i]],
        price = events$price[[i]],
        qty = events$qty[[i]]
      ),
      ledgr:::ledgr_json_read_nested(events$meta_json[[i]])
    )
  })
}

terminal_outcome_trace <- function(tables, id) {
  d <- tables$diagnostics
  d[d$stage == "decision" & d$instrument_id == id, , drop = FALSE]
}

