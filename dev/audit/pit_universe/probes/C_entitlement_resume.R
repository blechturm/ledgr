# Stage 1 probe (reader C): corporate-action entitlement binding, fresh run
# versus a run interrupted after the pulse before the entitlement pulse and
# resumed. HHH pays a $1 ordinary_cash_dividend; entitlement is the s14 close.
# The strategy buys 10 HHH at the s13 decision, so the fill executes at the
# s14 open, before the entitlement close. A control buys at s12. Description
# only: prints HHH events and final equity of each run.
#
#   sh dev/audit/pit_universe/run_low.sh dev/audit/pit_universe/probes/C_entitlement_resume.R <log>
source("C:/Users/maxth/Documents/GitHub/ledgr/dev/audit/pit_universe/probes/C_helpers.R")

fx <- pit_c_fixture()
db <- tempfile(fileext = ".duckdb")
snapshot <- pit_audit_snapshot(fx, db_path = db)
exp <- ledgr_experiment(snapshot, pit_c_strategy,
  universe = ledgr_universe_members(fx$universe_id),
  valuation_policy = ledgr_valuation_stale(3), cost_model = ledgr_cost_zero(),
  opening = ledgr_opening(cash = 1e5))

show <- function(run_id) {
  ev <- pit_c_events(db, run_id, "HHH")
  print(ev[, c("ts_utc", "event_type", "side", "qty", "price")], row.names = FALSE)
  for (m in ev$meta_json[ev$event_type == "CASHFLOW"]) cat("  CASHFLOW meta:", m, "\n")
  bt <- ledgr_run_open(snapshot, run_id)
  eq <- ledgr_results(bt, "equity")
  cat("  status:", ledgr_run_info(snapshot, run_id)$status,
      " final equity:", format(eq$equity[nrow(eq)], nsmall = 2), "\n\n")
  close(bt)
}

for (k in c(12L, 13L)) {
  params <- list(buy_ts = pit_c_iso(pit_c_close_at(fx, k)), ids = "HHH", qty = 10,
                 stop_ts = pit_c_iso(pit_c_close_at(fx, 13)))
  fresh <- sprintf("fresh_buy_s%d", k)
  resumed <- sprintf("resumed_buy_s%d", k)
  options(probe.stop = FALSE, ledgr.interrupt = FALSE)
  close(ledgr_run(exp, params = params, run_id = fresh))
  options(probe.stop = TRUE, ledgr.interrupt = FALSE)
  close(ledgr_run(exp, params = params, run_id = resumed))
  cat(sprintf("[buy at s%d] status after soft interrupt at s13: %s\n", k,
              ledgr_run_info(snapshot, resumed)$status))
  options(probe.stop = FALSE, ledgr.interrupt = FALSE)
  close(ledgr_run(exp, params = params, run_id = resumed))
  cat(sprintf("== buy decided s%d (fill at s%d open), fresh ==\n", k, k + 1L)); show(fresh)
  cat(sprintf("== buy decided s%d, interrupted after s13 and resumed ==\n", k)); show(resumed)
}
ledgr_snapshot_close(snapshot)
