# Stage 1 probe (integrator): walk-forward on the shared fixture (full status
# coverage). Description only: prints fold status, test-run windows, the
# final-pulse diagnostics and the carried opening state; asserts nothing.
#
# Cases
#   W1 carry   anchored folds (3 weeks train, 2 weeks test), carry_test_state
#   W2 flat    same folds, flat_test_state
#   W3 resume  W1 interrupted after one completed fold, then rerun
#   W4 gapbar  anchored folds (10 days, 7 days) so test 2 opens on s14, where
#              FFF (held) has no bar; carry_test_state; then the same call again
#
#   sh dev/audit/pit_universe/run_low.sh dev/audit/pit_universe/probes/I_walk_forward.R <log>
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all("C:/tmp/ws22-b", quiet = TRUE, compile = FALSE))
source("C:/Users/maxth/Documents/GitHub/ledgr/dev/audit/pit_universe/fixture.R")
options(width = 200, warn = 1)

iso <- function(x) format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
say <- function(case, ...) cat(sprintf("[%s] %s\n", case, paste0(...)))
err <- function(e) paste("ERROR", class(e)[[1L]], "-", conditionMessage(e))

fx <- pit_audit_fixture("announcement", status_coverage = "full")
close_at <- function(k) pit_audit_at(fx$sessions[k], if (k == 30L) "13:00:00" else "16:00:00")
db <- file.path(tempdir(), "I_wf.duckdb")
snap <- pit_audit_snapshot(fx, db_path = db)
strategy <- function(ctx, params) {
  t <- ctx$hold()
  ids <- ctx$tradable()
  # qty on even calendar days, qty + 1 on odd ones, so every pulse (the
  # window's last included) carries an actionable target.
  if (length(ids)) t[ids] <- params$qty + as.integer(substr(ctx$ts_utc, 9, 10)) %% 2L
  t
}
exp <- ledgr_experiment(snap, strategy, universe = ledgr_universe_members(fx$universe_id),
                        valuation_policy = ledgr_valuation_stale(3), cost_model = ledgr_cost_zero(),
                        opening = ledgr_opening(cash = 1e5))
grid <- ledgr_param_grid(q5 = list(qty = 5), q10 = list(qty = 10))
rule <- ledgr_rule_argmax("sharpe_ratio")
end <- iso(close_at(40))

report <- function(case, wf) {
  if (inherits(wf, "error")) return(say(case, err(wf)))
  say(case, "status ", wf$status, "; folds ", nrow(wf$folds), " (", paste(wf$folds$status, collapse = ","), ")")
  for (i in seq_len(nrow(wf$folds))) {
    rid <- wf$folds$test_run_id[[i]]
    if (is.na(rid) || !nzchar(rid)) { say(case, "fold ", i, ": no test run"); next }
    bt <- tryCatch(ledgr_run_open(snap, rid), error = function(e) e)
    if (inherits(bt, "error")) { say(case, "fold ", i, " test run ", rid, ": open ", err(bt)); next }
    eq <- ledgr_results(bt, "equity"); d <- ledgr_results(bt, "diagnostics"); led <- ledgr_results(bt, "ledger")
    comp <- ledgr_run_completion(bt)
    open_ev <- led[led$event_type == "CASHFLOW" & grepl("opening", led$meta_json %||% ""), ]
    say(case, "fold ", i, " test ", bt$config$backtest$start_ts_utc, " .. ", bt$config$backtest$end_ts_utc,
        "; status ", comp$completion_status, " stop ", comp$stop_reason, "; pulses ", nrow(eq),
        "; first/last equity ts ", iso(min(eq$ts_utc)), " / ", iso(max(eq$ts_utc)),
        "; final_pulse_no_execution ", sum(d$reason_code %in% "final_pulse_no_execution"),
        "; opening positions ", if (length(bt$config$opening$positions)) paste(names(bt$config$opening$positions), unlist(bt$config$opening$positions), sep = "=", collapse = ",") else "none",
        "; final equity ", format(tail(eq$equity, 1), nsmall = 2))
    close(bt)
  }
}

# W1 / W2
folds <- ledgr_folds_anchored("2021-03-01", end, train_window_initial = "3 weeks", test_window = "2 weeks")
say("W0 folds", length(folds), " folds; test windows ", paste(vapply(folds, function(f) paste(iso(f$test_start), iso(f$test_end), sep = ".."), ""), collapse = " | "))
wf1 <- tryCatch(ledgr_walk_forward(exp, grid, folds, rule, seed = 1L, opening_state_policy = "carry_test_state"), error = function(e) e)
report("W1 carry", wf1)
wf2 <- tryCatch(suppressWarnings(ledgr_walk_forward(exp, grid, folds, rule, seed = 1L, opening_state_policy = "flat_test_state")), error = function(e) e)
report("W2 flat", wf2)
if (!inherits(wf1, "error") && !inherits(wf2, "error"))
  say("W1/W2", "session_id differs: ", !identical(wf1$session_id, wf2$session_id),
      "; fold 1 test run equal final equity: ", identical(wf1$folds$test_run_id[[1]], wf2$folds$test_run_id[[1]]))

# W3 interrupted after one completed fold, then rerun with the same call
grid3 <- ledgr_param_grid(q7 = list(qty = 7), q10 = list(qty = 10))
options(ledgr.walk_forward_interrupt_after_completed_folds = 1L)
wf3a <- tryCatch(ledgr_walk_forward(exp, grid3, folds, rule, seed = 3L), error = function(e) e,
                 interrupt = function(e) structure(class = c("probe_interrupt", "error", "condition"),
                                                   list(message = conditionMessage(e), call = NULL)))
options(ledgr.walk_forward_interrupt_after_completed_folds = NULL)
report("W3 first", wf3a)
wf3b <- tryCatch(ledgr_walk_forward(exp, grid3, folds, rule, seed = 3L), error = function(e) e)
report("W3 rerun", wf3b)
if (!inherits(wf3b, "error")) {
  con <- DBI::dbConnect(duckdb::duckdb(), db, read_only = TRUE)
  ses <- DBI::dbGetQuery(con, "SELECT session_id FROM walk_forward_sessions")
  DBI::dbDisconnect(con, shutdown = TRUE)
  say("W3", "sessions stored ", nrow(ses), "; rerun session_id among them: ", wf3b$session_id %in% ses$session_id)
}

# W4 carried holding without a bar on the next test window's first pulse
folds4 <- ledgr_folds_anchored("2021-03-01", end, train_window_initial = "10 days", test_window = "7 days")
say("W4 folds", length(folds4), " folds; test windows ", paste(vapply(folds4, function(f) paste(iso(f$test_start), iso(f$test_end), sep = ".."), ""), collapse = " | "))
wf4 <- tryCatch(ledgr_walk_forward(exp, grid, folds4, rule, seed = 4L), error = function(e) e)
report("W4 gapbar", wf4)
if (!inherits(wf4, "error")) {
  say("W4 folds", "selection_source ", paste(wf4$folds$selection_source %||% NA, collapse = ","))
  con <- DBI::dbConnect(duckdb::duckdb(), db, read_only = TRUE)
  for (rid in wf4$folds$test_run_id[!is.na(wf4$folds$test_run_id) & nzchar(wf4$folds$test_run_id)]) {
    st <- DBI::dbGetQuery(con, "SELECT status FROM runs WHERE run_id = ?", params = list(rid))$status
    cr <- DBI::dbGetQuery(con, "SELECT * FROM run_completion WHERE run_id = ?", params = list(rid))
    eq <- DBI::dbGetQuery(con, "SELECT ts_utc, equity FROM equity_curve WHERE run_id = ? ORDER BY ts_utc", params = list(rid))
    dg <- DBI::dbGetQuery(con, "SELECT ts_utc, instrument_id, stage, outcome, reason_code FROM run_diagnostics WHERE run_id = ? AND stage IN ('valuation') ORDER BY diagnostic_seq", params = list(rid))
    say("W4 tables", rid, ": status ", st, "; completion ", if (nrow(cr)) paste(names(cr), vapply(cr[1, ], function(v) paste(format(v), collapse = ";"), ""), sep = "=", collapse = " ") else "none",
        "; equity rows ", nrow(eq), " (NA equity ", sum(is.na(eq$equity)), "); valuation diagnostics ",
        paste(dg$instrument_id, dg$outcome, dg$reason_code, sep = ":", collapse = " "))
  }
  DBI::dbDisconnect(con, shutdown = TRUE)
}
wf4b <- tryCatch(ledgr_walk_forward(exp, grid, folds4, rule, seed = 4L), error = function(e) e)
report("W4 rerun", wf4b)

ledgr_snapshot_close(snap)
