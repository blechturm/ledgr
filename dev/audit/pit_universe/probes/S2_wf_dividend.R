# Stage 2 probe (analyst): a dividend whose entitlement is the last pulse of a
# walk-forward test window, under carry_test_state. HHH: entitlement s14
# close (Thu 2021-03-18), effective s15 close. Rolling folds (train 7 days,
# test and step 11 days from 2021-03-01): test 1 = 2021-03-08..2021-03-18
# (s6..s14), test 2 = 2021-03-19..2021-03-29 (s15..s21), contiguous.
# The strategy holds HHH at qty from the first pulse. Prints the HHH
# CASHFLOW rows of each test run under effective_close and next_open, and a
# single ledgr_run() over the whole snapshot as the reference.
#
#   sh dev/audit/pit_universe/run_low.sh dev/audit/pit_universe/probes/S2_wf_dividend.R <log>
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all("C:/tmp/ws22-b", quiet = TRUE, compile = FALSE))
source("C:/Users/maxth/Documents/GitHub/ledgr/dev/audit/pit_universe/fixture.R")
options(width = 200, warn = 1)
iso <- function(x) format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
fx <- pit_audit_fixture("announcement", status_coverage = "full")
snap <- pit_audit_snapshot(fx, db_path = file.path(tempdir(), "S2_wf_div.duckdb"))
strategy <- function(ctx, params) { t <- ctx$hold(); if ("HHH" %in% ctx$tradable()) t[["HHH"]] <- params$qty; t }
folds <- ledgr_folds_rolling(start = "2021-03-01", end = "2021-03-29T23:59:59Z", train_window = "7 days",
                             test_window = "11 days", step = "11 days")
cat("[folds]", paste(vapply(folds, function(f) paste(iso(f$test_start), iso(f$test_end), sep = ".."), ""), collapse = " | "), "\n")
hhh_cash <- function(bt) {
  l <- ledgr_results(bt, "ledger"); l <- l[l$event_type == "CASHFLOW" & l$instrument_id == "HHH" & grepl("corporate_action_cash", l$meta_json), ]
  if (!nrow(l)) "none" else paste(iso(l$ts_utc), collapse = ",")
}
for (posting in c("effective_close", "next_open")) {
  exp <- ledgr_experiment(snap, strategy, universe = ledgr_universe_members(fx$universe_id),
                          valuation_policy = ledgr_valuation_stale(3), cost_model = ledgr_cost_zero(),
                          opening = ledgr_opening(cash = 1e5),
                          corporate_action_policy = ledgr_corporate_actions(cash_posting = posting))
  wf <- tryCatch(ledgr_walk_forward(exp, ledgr_param_grid(q10 = list(qty = 10), q20 = list(qty = 20)), folds,
                                    ledgr_rule_argmax("annualized_return"), seed = 1L, opening_state_policy = "carry_test_state"),
                 error = identity)
  if (inherits(wf, "error")) { cat(sprintf("[%s] walk-forward ERROR %s - %s\n", posting, class(wf)[[1]], conditionMessage(wf))); next }
  for (i in seq_len(nrow(wf$folds))) {
    rid <- wf$folds$test_run_id[[i]]
    bt <- ledgr_run_open(snap, rid)
    eq <- ledgr_results(bt, "equity")
    pos <- bt$config$opening$positions
    cat(sprintf("[%s] fold %d test %s..%s opening %s; HHH CASHFLOW %s; first/last equity %s / %s\n", posting, i,
                iso(min(eq$ts_utc)), iso(max(eq$ts_utc)),
                if (length(pos)) paste(names(pos), unlist(pos), sep = "=", collapse = ",") else "none",
                hhh_cash(bt), format(eq$equity[[1]], nsmall = 2), format(tail(eq$equity, 1), nsmall = 2)))
    close(bt)
  }
  ref <- ledgr_run(exp, params = list(qty = 10), run_id = paste0("ref_", posting))
  cat(sprintf("[%s] reference single run HHH CASHFLOW %s\n", posting, hhh_cash(ref)))
  close(ref)
}
ledgr_snapshot_close(snap)
