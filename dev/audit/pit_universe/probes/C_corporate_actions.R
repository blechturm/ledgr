# Stage 1 probe (reader C): corporate-action and terminal settlement as
# executed. Buys 10 each of CCC (cash acquisition $50, effective s19, last
# close 49.80 on s18), DDD (0.75 AAA per DDD, effective s25), HHH ($1
# dividend, entitlement s14 close, ex s15, paid s25) and III (0.5 JJJ spin-off,
# ex s17) at the s1 decision, then holds.
# Runs: research policy; held_terminal_position = "refuse"; strict preset;
# a one-candidate sweep of the research run (final-equity parity); and a
# snapshot whose HHH dividend uses subtype "cash_dividend".
#
#   sh dev/audit/pit_universe/run_low.sh dev/audit/pit_universe/probes/C_corporate_actions.R <log>
source("C:/Users/maxth/Documents/GitHub/ledgr/dev/audit/pit_universe/probes/C_helpers.R")

fx <- pit_c_fixture()
db <- tempfile(fileext = ".duckdb")
snapshot <- pit_audit_snapshot(fx, db_path = db)
params <- list(buy_ts = pit_c_iso(pit_c_close_at(fx, 1)), ids = c("CCC", "DDD", "HHH", "III"), qty = 10)
make_exp <- function(snap, policy) {
  ledgr_experiment(snap, pit_c_strategy,
    universe = ledgr_universe_members(fx$universe_id),
    valuation_policy = ledgr_valuation_stale(3), cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1e5), corporate_action_policy = policy)
}
report <- function(bt, dbp) {
  ev <- pit_c_events(dbp, bt$run_id)
  ev <- ev[ev$event_type != "FILL" | ev$instrument_id %in% c("AAA", "JJJ"), ]
  print(ev[, c("ts_utc", "event_type", "instrument_id", "qty", "price")], row.names = FALSE)
  for (m in ev$meta_json[ev$event_type == "DISPOSITION"]) cat("  DISPOSITION meta:", m, "\n")
  info <- ledgr_run_completion(bt)
  eq <- ledgr_results(bt, "equity")
  cat("  status:", info$completion_status, " stop:", info$stop_reason,
      " final equity:", format(eq$equity[nrow(eq)], nsmall = 2), "\n")
  fills <- ledgr_results(bt, "fills"); trades <- ledgr_results(bt, "trades")
  cat("  fills rows:", nrow(fills), " closed trades:", nrow(trades), "\n")
  cs <- ledgr_corporate_action_summary(bt)
  cat("  fidelity:", cs$corporate_action_fidelity, " gross cash:", cs$gross_cash_posted,
      " terminal proceeds:", cs$modeled_terminal_proceeds, " unsupported facts:", cs$unsupported_facts, "\n")
  if (nrow(cs$terminal_outcomes)) print(as.data.frame(cs$terminal_outcomes[, c("instrument_id", "source", "choice", "basis", "assumption", "price", "proceeds")]), row.names = FALSE)
  if (nrow(cs$omitted_value)) print(cs$omitted_value[, c("source_fact_id", "subtype", "entitled_parent_quantity", "modeled_cash_credited", "estimated_contractual_consideration", "successor_exposure_not_represented")], row.names = FALSE)
  pos <- ledgr_results(bt, "availability")
  last <- pos[pos$ts_utc == max(pos$ts_utc) & pos$held, c("instrument_id", "held")]
  cat("  held at last decision:", paste(last$instrument_id, collapse = ","), "\n")
  invisible(eq$equity[nrow(eq)])
}

cat("==== research ====\n")
bt <- ledgr_run(make_exp(snapshot, ledgr_corporate_actions_research()), params = params, run_id = "ca_research")
research_equity <- report(bt, db); close(bt)

cat("\n==== held_terminal_position = refuse ====\n")
bt <- ledgr_run(make_exp(snapshot, ledgr_corporate_actions(held_terminal_position = "refuse")), params = params, run_id = "ca_refuse")
report(bt, db); close(bt)

cat("\n==== strict preset ====\n")
res <- tryCatch(ledgr_run(make_exp(snapshot, ledgr_corporate_actions_strict()), params = params, run_id = "ca_strict"),
                error = function(e) e)
if (inherits(res, "error")) cat("  error:", paste(class(res)[1:2], collapse = "/"), "-", conditionMessage(res), "\n")
info <- ledgr_run_info(snapshot, "ca_strict")
cat("  run status:", info$status, "\n")

cat("\n==== sweep, one candidate, research policy ====\n")
sw <- ledgr_sweep(make_exp(snapshot, ledgr_corporate_actions_research()), ledgr_param_grid(only = params))
cat("  sweep status:", sw$status, " final equity:", format(sw$final_equity, nsmall = 2),
    " equals run:", identical(as.numeric(sw$final_equity), as.numeric(research_equity)), "\n")
ledgr_snapshot_close(snapshot)

cat("\n==== HHH dividend with subtype cash_dividend ====\n")
fx2 <- pit_c_fixture(dividend_subtype = "cash_dividend")
db2 <- tempfile(fileext = ".duckdb")
snap2 <- pit_audit_snapshot(fx2, db_path = db2)
bt <- ledgr_run(make_exp(snap2, ledgr_corporate_actions_research()),
                params = list(buy_ts = params$buy_ts, ids = "HHH", qty = 10), run_id = "cash_dividend")
report(bt, db2); close(bt)
ledgr_snapshot_close(snap2)
