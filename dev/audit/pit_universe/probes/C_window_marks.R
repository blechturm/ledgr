# Stage 1 probe (reader C): mark lookback at a run's scoring start. An
# opening position in FFF (halted s14-s15, no bars; last bar s13 close 20)
# with the opening dated on s14, s15 or s13 (control), valuation
# ledgr_valuation_stale(5). Prints completion and the first equity rows.
#
#   sh dev/audit/pit_universe/run_low.sh dev/audit/pit_universe/probes/C_window_marks.R <log>
source("C:/Users/maxth/Documents/GitHub/ledgr/dev/audit/pit_universe/probes/C_helpers.R")

fx <- pit_c_fixture()
db <- tempfile(fileext = ".duckdb")
snapshot <- pit_audit_snapshot(fx, db_path = db)
for (k in c(13L, 14L, 15L)) {
  exp <- ledgr_experiment(snapshot, function(ctx, params) ctx$hold(),
    universe = ledgr_universe_members(fx$universe_id),
    valuation_policy = ledgr_valuation_stale(5), cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1e5, date = fx$sessions[[k]],
                            positions = c(FFF = 10), cost_basis = c(FFF = 20)))
  res <- tryCatch(ledgr_run(exp, run_id = sprintf("open_s%d", k)), error = function(e) e)
  cat(sprintf("==== opening dated s%d (%s) ====\n", k, format(fx$sessions[[k]])))
  if (inherits(res, "error")) {
    cat("  error:", class(res)[[1]], "-", conditionMessage(res), "\n")
    next
  }
  info <- ledgr_run_completion(res)
  cat("  status:", info$completion_status, " stop:", info$stop_reason,
      " requested start:", pit_c_iso(info$requested_start_utc),
      " achieved end:", pit_c_iso(info$achieved_end_utc), "\n")
  eq <- ledgr_results(res, "equity")
  cat("  equity rows:", nrow(eq), "\n")
  if (nrow(eq)) print(head(as.data.frame(eq[, c("ts_utc", "cash", "positions_value", "equity")]), 3), row.names = FALSE)
  dg <- ledgr_results(res, "diagnostics")
  dg <- dg[dg$instrument_id == "FFF", c("ts_utc", "stage", "outcome", "reason_code", "mark_source", "mark_age")]
  print(head(as.data.frame(dg), 4), row.names = FALSE)
  close(res)
  if (k == 14L) {
    reopened <- tryCatch(ledgr_run_open(snapshot, "open_s14"), error = function(e) e)
    cat("  ledgr_run_open:", if (inherits(reopened, "error")) paste(class(reopened)[[1]], conditionMessage(reopened)) else "ok", "\n")
    rerun <- tryCatch(ledgr_run(exp, run_id = "open_s14"), error = function(e) e)
    cat("  rerun same run_id:", if (inherits(rerun, "error")) paste(class(rerun)[[1]], conditionMessage(rerun)) else "ok", "\n")
    con <- DBI::dbConnect(duckdb::duckdb(), db)
    rec <- tryCatch(ledgr_state_reconstruct("open_s14", con), error = function(e) e)
    DBI::dbDisconnect(con, shutdown = TRUE)
    cat("  reconstruct:", if (inherits(rec, "error")) paste(class(rec)[[1]], conditionMessage(rec)) else "ok", "\n")
  }
}
ledgr_snapshot_close(snapshot)
