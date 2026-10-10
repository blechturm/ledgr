# Stage 2 challenger probe (judged-consistent item PIT-04-003, "not probed"):
# POSIXct session times are not checked against their session_date. Case:
# 5 New York weekdays; the 2021-03-02 row's open and close are POSIXct
# instants on 2021-03-03 (a vendor off-by-one), equal to the 2021-03-03
# row's own times. Bars at each intended close. Prints whether the facts
# seal, the run pulses, and the run status.
#
#   sh dev/audit/pit_universe/run_low.sh dev/audit/pit_universe/probes/S2C_session_posix.R <log>
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all("C:/tmp/ws22-b", quiet = TRUE, compile = FALSE))
options(width = 200, warn = 1)
iso <- function(x) format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
err <- function(e) paste(class(e)[[1L]], "-", conditionMessage(e))
days <- as.Date(c("2021-03-01", "2021-03-02", "2021-03-03", "2021-03-04", "2021-03-05"))
at <- function(d, hms) as.POSIXct(paste(d, hms), tz = "America/New_York")
open <- do.call(c, lapply(days, at, hms = "09:30:00")); close <- do.call(c, lapply(days, at, hms = "16:00:00"))
open[[2]] <- open[[3]]; close[[2]] <- close[[3]]
sessions <- data.frame(session_date = days, status = "open", session_open = open, session_close = close)
bars <- data.frame(instrument_id = "AAA", ts_utc = do.call(c, lapply(days, at, hms = "16:00:00")),
                   open = 10, high = 10, low = 10, close = 10, volume = 1)
attr(bars$ts_utc, "tzone") <- "UTC"
f <- tryCatch(ledgr_facts_sessions(sessions, venue_id = "XNYS", timezone = "America/New_York", knowledge = "assume_effective"), error = identity)
if (inherits(f, "error")) { cat("[sessions] constructor ERROR", err(f), "\n"); quit(save = "no") }
cat("[sessions] constructor accepted\n")
snap <- tryCatch(ledgr_snapshot_from_df(bars, data.frame(instrument_id = "AAA"), db_path = tempfile(fileext = ".duckdb"),
                                        facts = ledgr_facts(f), price_basis = "split_adjusted"), error = identity)
if (inherits(snap, "error")) { cat("[seal] ERROR", err(snap), "\n"); quit(save = "no") }
cat("[seal] accepted\n")
exp <- ledgr_experiment(snap, function(ctx, params) ctx$hold(), universe = "AAA", valuation_policy = ledgr_valuation_stale(1),
                        cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1e4))
bt <- tryCatch(ledgr_run(exp, run_id = "r"), error = identity)
if (inherits(bt, "error")) {
  cat("[run] ERROR", err(bt), "\n")
  ledgr_snapshot_close(snap)
  snap <- ledgr_snapshot_open(snap$db_path, snap$snapshot_id)
  cat("[run] stored status", tryCatch(ledgr_run_info(snap, "r")$status, error = err), "\n")
  exp <- ledgr_experiment(snap, function(ctx, params) ctx$hold(), universe = "AAA", valuation_policy = ledgr_valuation_stale(1),
                          cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1e4))
  sw <- tryCatch(ledgr_sweep(exp, ledgr_param_grid(a = list())), error = identity)
  cat("[sweep]", if (inherits(sw, "error")) err(sw) else paste("status", sw$status[[1]]), "\n")
} else {
  eq <- ledgr_results(bt, "equity")
  cat("[run] status", ledgr_run_info(snap, "r")$status, "; pulses", paste(iso(eq$ts_utc), collapse = ","), "\n")
  close(bt)
}
ledgr_snapshot_close(snap)
