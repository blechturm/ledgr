# Shared setup for reader C probes. The shared fixture declares trading
# status only for FFF and EEE, so every other instrument resolves
# `status_unknown` and is target-restricted (observed 2026-10-10). Reader C
# probes need tradable members, so this variant adds `active` status rows
# from s1 for every instrument and closes FFF/EEE's active rows where the
# fixture's own rows begin. Everything else is the shared fixture unchanged.
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
pkgload::load_all("C:/tmp/ws22-b", quiet = TRUE, compile = FALSE)
source("C:/Users/maxth/Documents/GitHub/ledgr/dev/audit/pit_universe/fixture.R")

pit_c_iso <- function(x) format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

pit_c_fixture <- function(knowledge = "announcement", dividend_subtype = NULL) {
  fx <- pit_audit_fixture(knowledge)
  s <- fx$sessions
  open_at <- function(k) pit_audit_at(s[k], "09:30:00")
  ids <- fx$instruments$instrument_id
  others <- setdiff(ids, c("FFF", "EEE"))
  na_time <- as.POSIXct(NA, tz = "UTC")
  status <- data.frame(
    instrument_id = c(others, "FFF", "EEE", "FFF", "FFF", "EEE"),
    effective_from = c(rep(open_at(1), length(others)), open_at(1), open_at(1),
                       open_at(14), open_at(16), open_at(23)),
    effective_to = c(rep(na_time, length(others)), open_at(14), open_at(23),
                     open_at(16), na_time, na_time),
    status = c(rep("active", length(others) + 2L), "halted", "active", "quotation_only"),
    source = "audit_fixture_c",
    stringsAsFactors = FALSE
  )
  status$knowledge_time <- status$effective_from - 1
  fx$families$status <- ledgr_facts_trading_status(status, knowledge = "evidenced")
  if (!is.null(dividend_subtype)) {
    # Only the HHH dividend, under the given subtype (other actions dropped).
    close_at <- function(k) pit_c_close_at(fx, k)
    fx$families$corporate_actions <- ledgr_facts_equity_corporate_actions(data.frame(
      fact_id = "hhh-div", subtype = dividend_subtype, parent_instrument_id = "HHH",
      entitlement_time = close_at(14), effective_time = close_at(15),
      knowledge_time = open_at(1) - 1, payment_time = close_at(25),
      complete = TRUE, provenance_tier = "snapshot_bound",
      gross_cash_per_parent_unit = 1, gross_cash_validated = TRUE,
      recipient_instrument_id = NA_character_, recipient_identity_validated = FALSE,
      recipient_quantity_per_parent_unit = NA_real_, recipient_quantity_validated = FALSE,
      source = "audit_fixture_c", stringsAsFactors = FALSE
    ))
  }
  fx
}

pit_c_close_at <- function(fx, k) {
  pit_audit_at(fx$sessions[k], if (k == 30L) "13:00:00" else "16:00:00")
}

# Buys `qty` of each ID in `ids` at the decision pulse `buy_ts`, sells to zero
# the IDs in `sell` at `sell_ts`, and otherwise holds.
pit_c_strategy <- function(ctx, params) {
  targets <- ctx$hold()
  if (identical(ctx$ts_utc, params$buy_ts)) {
    for (id in params$ids) targets[[id]] <- params$qty
  }
  if (!is.null(params$sell_ts) && identical(ctx$ts_utc, params$sell_ts)) {
    for (id in params$sell) targets[[id]] <- 0
  }
  if (!is.null(params$stop_ts) && identical(ctx$ts_utc, params$stop_ts) &&
      isTRUE(getOption("probe.stop", FALSE))) {
    options(ledgr.interrupt = TRUE)
  }
  targets
}

pit_c_events <- function(db, run_id, ids = NULL) {
  con <- DBI::dbConnect(duckdb::duckdb(), db, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  ev <- DBI::dbGetQuery(con, "SELECT event_seq, ts_utc, event_type, instrument_id, side, qty, price, meta_json FROM ledger_events WHERE run_id = ? ORDER BY event_seq", params = list(run_id))
  if (!is.null(ids)) ev <- ev[ev$instrument_id %in% ids, , drop = FALSE]
  ev
}
