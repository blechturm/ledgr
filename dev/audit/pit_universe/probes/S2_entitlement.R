# Stage 2 probe (analyst): dividend entitlement on the fresh run, the resumed
# run and the sweep, under cash_posting "effective_close" and "next_open".
#
# Fixture HHH: $1 ordinary_cash_dividend, entitlement_time = s14 close,
# effective_time = s15 close (the fixture's mapping; the vignette
# corporate-action-cash.qmd calls the entitlement time the ex-dividend
# boundary). Cases, both with fills at the s14 open (entitlement session):
#   BUY   buy 10 HHH at the s13 decision (fill s14 open)
#   SELL  buy 10 HHH at s1 (fill s2 open), sell to 0 at s13 (fill s14 open)
# Each case runs fresh, interrupted at the s13 decision and resumed, and (for
# next_open) interrupted at s14 and resumed; plus a one-candidate sweep.
# Prints the HHH CASHFLOW entitled quantity, cash and final equity.
#
#   sh dev/audit/pit_universe/run_low.sh dev/audit/pit_universe/probes/S2_entitlement.R <log>
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all("C:/tmp/ws22-b", quiet = TRUE, compile = FALSE))
source("C:/Users/maxth/Documents/GitHub/ledgr/dev/audit/pit_universe/fixture.R")
options(width = 200, warn = 1)
iso <- function(x) format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
fx <- pit_audit_fixture("announcement", status_coverage = "full")
close_at <- function(k) pit_audit_at(fx$sessions[k], if (k == 30L) "13:00:00" else "16:00:00")
db <- file.path(tempdir(), "S2_entitlement.duckdb")
snap <- pit_audit_snapshot(fx, db_path = db)

strategy <- function(ctx, params) {
  t <- ctx$hold()
  if (!is.null(params$buy_ts) && identical(ctx$ts_utc, params$buy_ts)) t[["HHH"]] <- 10
  if (!is.null(params$sell_ts) && identical(ctx$ts_utc, params$sell_ts)) t[["HHH"]] <- 0
  stop_ts <- getOption("probe.stop_ts", NA_character_)
  if (!is.na(stop_ts) && identical(ctx$ts_utc, stop_ts)) options(ledgr.interrupt = TRUE)
  t
}
cases <- list(
  BUY = list(buy_ts = iso(close_at(13))),
  SELL = list(buy_ts = iso(close_at(1)), sell_ts = iso(close_at(13)))
)
hhh_cash <- function(run_id) {
  con <- DBI::dbConnect(duckdb::duckdb(), db, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  ev <- DBI::dbGetQuery(con, "SELECT ts_utc, meta_json FROM ledger_events WHERE run_id = ? AND event_type = 'CASHFLOW' AND instrument_id = 'HHH'", params = list(run_id))
  if (!nrow(ev)) return("no HHH CASHFLOW")
  m <- lapply(ev$meta_json, jsonlite::fromJSON)
  paste0("CASHFLOW at ", iso(ev$ts_utc), " entitled_quantity=", vapply(m, `[[`, 0, "entitled_quantity"),
         " cash=", vapply(m, `[[`, 0, "cash_delta"), collapse = "; ")
}
final_eq <- function(run_id) {
  bt <- ledgr_run_open(snap, run_id); on.exit(close(bt))
  e <- ledgr_results(bt, "equity"); format(tail(e$equity, 1), nsmall = 2)
}
for (posting in c("effective_close", "next_open")) {
  exp <- ledgr_experiment(snap, strategy, universe = ledgr_universe_members(fx$universe_id),
                          valuation_policy = ledgr_valuation_stale(3), cost_model = ledgr_cost_zero(),
                          opening = ledgr_opening(cash = 1e5),
                          corporate_action_policy = ledgr_corporate_actions(cash_posting = posting))
  for (nm in names(cases)) {
    p <- cases[[nm]]
    tag <- sprintf("%s %s", posting, nm)
    options(probe.stop_ts = NA_character_, ledgr.interrupt = FALSE)
    fresh <- paste0("fresh_", posting, "_", nm)
    close(ledgr_run(exp, params = p, run_id = fresh))
    cat(sprintf("[%s] fresh: %s; final equity %s\n", tag, hhh_cash(fresh), final_eq(fresh)))
    stops <- if (identical(posting, "next_open")) c(13L, 14L) else 13L
    for (k in stops) {
      rid <- sprintf("resumed_%s_%s_s%d", posting, nm, k)
      options(probe.stop_ts = iso(close_at(k)), ledgr.interrupt = FALSE)
      close(ledgr_run(exp, params = p, run_id = rid))
      st1 <- ledgr_run_info(snap, rid)$status
      options(probe.stop_ts = NA_character_, ledgr.interrupt = FALSE)
      close(ledgr_run(exp, params = p, run_id = rid))
      cat(sprintf("[%s] interrupted at s%d (status %s) then resumed: %s; final equity %s\n",
                  tag, k, st1, hhh_cash(rid), final_eq(rid)))
    }
    options(probe.stop_ts = NA_character_, ledgr.interrupt = FALSE)
    sw <- ledgr_sweep(exp, ledgr_param_grid(c1 = p))
    cat(sprintf("[%s] sweep final equity %s\n", tag, format(sw$final_equity[[1]], nsmall = 2)))
  }
}
ledgr_snapshot_close(snap)
