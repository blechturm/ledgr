# Stage 1 probe (reader C): valuation stop, freeze, and reconstruction.
# FFF is halted s14-s15 with no bars and reopens s16 at 14 (from 20).
# Case A: exhausted = "refuse", max_sessions = 0; hold FFF from s1 and buy
#   AAA at the s13 decision, so a fill (s14 open) is committed before the
#   s14 stop. Prints completion, equity tail, events after the last valued
#   pulse, and what ledgr_state_reconstruct() does.
# Case B: exhausted = "freeze", max_sessions = 0; same strategy. Prints the
#   valuation summary, frozen diagnostics, and reconstruct-vs-stored equity.
#
#   sh dev/audit/pit_universe/run_low.sh dev/audit/pit_universe/probes/C_reconstruct_stop.R <log>
source("C:/Users/maxth/Documents/GitHub/ledgr/dev/audit/pit_universe/probes/C_helpers.R")

fx <- pit_c_fixture()
db <- tempfile(fileext = ".duckdb")
snapshot <- pit_audit_snapshot(fx, db_path = db)
s1 <- pit_c_iso(pit_c_close_at(fx, 1))
s13 <- pit_c_iso(pit_c_close_at(fx, 13))
strategy <- function(ctx, params) {
  targets <- ctx$hold()
  if (identical(ctx$ts_utc, params$t1)) targets[["FFF"]] <- 10
  if (identical(ctx$ts_utc, params$t2)) targets[["AAA"]] <- 10
  targets
}
params <- list(t1 = s1, t2 = s13)

reconstruct <- function(run_id) {
  con <- DBI::dbConnect(duckdb::duckdb(), db)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  stored <- DBI::dbGetQuery(con, "SELECT ts_utc, equity FROM equity_curve WHERE run_id = ? ORDER BY ts_utc", params = list(run_id))
  out <- tryCatch(ledgr_state_reconstruct(run_id, con), error = function(e) e)
  if (inherits(out, "error")) {
    cat("  reconstruct ERROR:", class(out)[[1]], "-", conditionMessage(out), "\n")
  } else {
    re <- out$equity_curve
    cat("  reconstruct rows:", nrow(re), " stored rows:", nrow(stored),
        " identical equity:", identical(as.numeric(re$equity), as.numeric(stored$equity)), "\n")
  }
}

for (exhausted in c("refuse", "freeze")) {
  run_id <- paste0("stop_", exhausted)
  exp <- ledgr_experiment(snapshot, strategy,
    universe = ledgr_universe_members(fx$universe_id),
    valuation_policy = ledgr_valuation_stale(0, exhausted = exhausted),
    cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1e5))
  bt <- ledgr_run(exp, params = params, run_id = run_id)
  cat("==== exhausted =", exhausted, "====\n")
  comp <- ledgr_run_completion(bt)
  cat("  status:", comp$completion_status, " stop:", comp$stop_reason,
      " last valued:", pit_c_iso(comp$last_fully_valued_ts_utc),
      " last executed:", pit_c_iso(comp$last_executed_ts_utc),
      " affected:", paste(comp$affected_instrument_ids, collapse = ","), "\n")
  eq <- ledgr_results(bt, "equity")
  cat("  equity rows:", nrow(eq), " last equity ts:", pit_c_iso(eq$ts_utc[nrow(eq)]), "\n")
  ev <- pit_c_events(db, run_id)
  late <- ev[as.POSIXct(ev$ts_utc, tz = "UTC") > comp$last_fully_valued_ts_utc, ]
  cat("  events after last valued pulse:", nrow(late), "\n")
  if (nrow(late)) print(late[, c("ts_utc", "event_type", "instrument_id", "side", "qty", "price")], row.names = FALSE)
  dg <- ledgr_results(bt, "diagnostics")
  v <- dg[dg$stage == "valuation" | (dg$instrument_id == "FFF" & dg$stage == "decision" &
          as.POSIXct(dg$ts_utc, tz = "UTC") >= pit_c_close_at(fx, 13) &
          as.POSIXct(dg$ts_utc, tz = "UTC") <= pit_c_close_at(fx, 17)), ]
  print(as.data.frame(v[, c("ts_utc", "instrument_id", "stage", "outcome", "reason_code", "price", "mark_source", "mark_age")]), row.names = FALSE)
  if (identical(exhausted, "freeze")) {
    vs <- ledgr_valuation_summary(bt)
    cat("  valuation_state:", vs$valuation_state, " frozen sessions:", vs$frozen_instrument_sessions,
        " longest freeze:", vs$longest_freeze_sessions, "\n")
    av <- ledgr_results(bt, "availability")
    print(as.data.frame(av[av$instrument_id == "FFF" & av$ts_utc >= pit_c_close_at(fx, 13) &
                             av$ts_utc <= pit_c_close_at(fx, 17),
                           c("ts_utc", "held", "target_restricted", "target_restriction_reasons", "priced", "mark_source", "mark_age")]), row.names = FALSE)
    ex <- ledgr_run_explain(bt, "FFF", pit_c_close_at(fx, 14))
    cat("  explain FFF s14: mark_source", ex$mark_source, "age", ex$mark_age, "restricted", ex$target_restricted, "\n")
  }
  close(bt)
  reconstruct(run_id)
  cat("\n")
}
ledgr_snapshot_close(snapshot)
