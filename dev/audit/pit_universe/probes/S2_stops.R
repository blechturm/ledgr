# Stage 2 probe (analyst): typed stops at the edge of a committed prefix.
#   O  opening FFF=10 dated s14 (FFF halted, no bar s14-s15), stale(5):
#      stop on the first pulse; stored equity rows, run_open, rerun.
#   P  fresh: buy FFF at s12 (fill s13 open) and AAA at s13 (fill s14 open),
#      stale(0, "refuse"): stop at s14; ledger vs equity prefix,
#      reconstruct, compute_metrics vs summary.
#   R  P interrupted at the s13 decision and resumed: the first resumed pulse
#      is the stop pulse. Equity rows and completion vs P; run_open; rerun.
#
#   sh dev/audit/pit_universe/run_low.sh dev/audit/pit_universe/probes/S2_stops.R <log>
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all("C:/tmp/ws22-b", quiet = TRUE, compile = FALSE))
source("C:/Users/maxth/Documents/GitHub/ledgr/dev/audit/pit_universe/fixture.R")
options(width = 200, warn = 1)
iso <- function(x) format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
err <- function(e) paste(class(e)[[1L]], "-", conditionMessage(e))
fx <- pit_audit_fixture("announcement", status_coverage = "full")
close_at <- function(k) pit_audit_at(fx$sessions[k], if (k == 30L) "13:00:00" else "16:00:00")
db <- file.path(tempdir(), "S2_stops.duckdb")
snap <- pit_audit_snapshot(fx, db_path = db)
q <- function(sql, ...) {
  con <- DBI::dbConnect(duckdb::duckdb(), db, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  DBI::dbGetQuery(con, sql, params = list(...))
}
stored <- function(rid) {
  eq <- q("SELECT ts_utc, cash, positions_value, equity FROM equity_curve WHERE run_id = ? ORDER BY ts_utc", rid)
  cr <- q("SELECT intended_terminal_status AS completion_status, intended_end_utc, achieved_end_utc, last_executed_ts_utc, stop_reason, complete_performance FROM run_completion WHERE run_id = ?", rid)
  sprintf("status %s; completion %s achieved_end %s last_executed %s stop %s; equity rows %d (NA %d) first..last %s..%s",
          q("SELECT status FROM runs WHERE run_id = ?", rid)$status, cr$completion_status, iso(cr$achieved_end_utc),
          iso(cr$last_executed_ts_utc), cr$stop_reason, nrow(eq), sum(is.na(eq$equity)),
          if (nrow(eq)) iso(min(eq$ts_utc)) else "-", if (nrow(eq)) iso(max(eq$ts_utc)) else "-")
}
try_open <- function(rid) { b <- tryCatch(ledgr_run_open(snap, rid), error = identity); if (inherits(b, "error")) err(b) else { close(b); "ok" } }

# ---- O: first-pulse stop -----------------------------------------------------
expO <- ledgr_experiment(snap, function(ctx, params) ctx$hold(), universe = ledgr_universe_members(fx$universe_id),
                         valuation_policy = ledgr_valuation_stale(5), cost_model = ledgr_cost_zero(),
                         opening = ledgr_opening(cash = 1e5, date = fx$sessions[[14]], positions = c(FFF = 10), cost_basis = c(FFF = 20)))
o <- tryCatch(ledgr_run(expO, run_id = "O"), error = identity)
cat("[O] run:", if (inherits(o, "error")) err(o) else "returned", "\n")
if (!inherits(o, "error")) close(o)
cat("[O] stored:", stored("O"), "\n")
cat("[O] ledgr_run_open:", try_open("O"), "\n")
r2 <- tryCatch(ledgr_run(expO, run_id = "O"), error = identity)
cat("[O] rerun same run_id:", if (inherits(r2, "error")) err(r2) else "ok", "\n")

# ---- P: fresh stop with a fill after the last valued pulse ---------------------
strategy <- function(ctx, params) {
  t <- ctx$hold()
  if (identical(ctx$ts_utc, params$fff_ts)) t[["FFF"]] <- 10
  if (identical(ctx$ts_utc, params$aaa_ts)) t[["AAA"]] <- 10
  stop_ts <- getOption("probe.stop_ts", NA_character_)
  if (!is.na(stop_ts) && identical(ctx$ts_utc, stop_ts)) options(ledgr.interrupt = TRUE)
  t
}
p <- list(fff_ts = iso(close_at(12)), aaa_ts = iso(close_at(13)))
expP <- ledgr_experiment(snap, strategy, universe = ledgr_universe_members(fx$universe_id),
                         valuation_policy = ledgr_valuation_stale(0, exhausted = "refuse"), cost_model = ledgr_cost_zero(),
                         opening = ledgr_opening(cash = 1e5))
options(probe.stop_ts = NA_character_, ledgr.interrupt = FALSE)
close(ledgr_run(expP, params = p, run_id = "P"))
cat("[P] stored:", stored("P"), "\n")
led <- q("SELECT ts_utc, event_type, instrument_id, qty, price FROM ledger_events WHERE run_id = 'P' ORDER BY event_seq")
cat("[P] ledger:", paste(iso(led$ts_utc), led$event_type, led$instrument_id, led$qty, sep = " ", collapse = " | "), "\n")
eqP <- q("SELECT cash, positions_value FROM equity_curve WHERE run_id = 'P' ORDER BY ts_utc DESC LIMIT 1")
cat("[P] last equity row cash", eqP$cash, "positions_value", eqP$positions_value,
    "; ledger cash after all events", 1e5 - sum(led$qty * led$price, na.rm = TRUE), "\n")
bt <- ledgr_run_open(snap, "P")
cm <- ledgr_compute_metrics(bt)
cat("[P] compute_metrics: ", paste(names(cm), unlist(lapply(cm, function(v) format(v, digits = 6))), sep = "=", collapse = " "), "\n")
sm <- capture.output(summary(bt))
cat("[P] summary lines:", paste(trimws(grep("Annual|Sharpe|withheld|prefix|Volatil", sm, value = TRUE)), collapse = " / "), "\n")
fl <- ledgr_results(bt, "fills")
cat("[P] fills reader rows:", nrow(fl), "instruments", paste(fl$instrument_id, collapse = ","), "\n")
close(bt)
con <- DBI::dbConnect(duckdb::duckdb(), db)
rec <- tryCatch(ledgr_state_reconstruct("P", con), error = identity)
DBI::dbDisconnect(con, shutdown = TRUE)
cat("[P] ledgr_state_reconstruct:", if (inherits(rec, "error")) err(rec) else paste("ok, rows", nrow(rec$equity_curve)), "\n")

# ---- R: resumed run whose first resumed pulse is the stop ----------------------
options(probe.stop_ts = iso(close_at(13)), ledgr.interrupt = FALSE)
close(ledgr_run(expP, params = p, run_id = "R"))
cat("[R] after interrupt:", stored("R"), "\n")
options(probe.stop_ts = NA_character_, ledgr.interrupt = FALSE)
rr <- tryCatch(ledgr_run(expP, params = p, run_id = "R"), error = identity)
cat("[R] resume:", if (inherits(rr, "error")) err(rr) else "returned", "\n")
if (!inherits(rr, "error")) close(rr)
cat("[R] stored:", stored("R"), "\n")
eqR <- q("SELECT ts_utc, equity FROM equity_curve WHERE run_id = 'R' ORDER BY ts_utc")
eqP2 <- q("SELECT ts_utc, equity FROM equity_curve WHERE run_id = 'P' ORDER BY ts_utc")
cat("[R] equity rows identical to fresh P:", identical(eqR, eqP2), "\n")
cat("[R] ledgr_run_open:", try_open("R"), "\n")
r3 <- tryCatch(ledgr_run(expP, params = p, run_id = "R"), error = identity)
cat("[R] rerun same run_id:", if (inherits(r3, "error")) err(r3) else "ok", "\n")
ledgr_snapshot_close(snap)
