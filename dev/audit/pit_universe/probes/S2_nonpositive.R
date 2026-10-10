# Stage 2 probe (analyst): ingest guarantees against runtime assumptions, and
# refusal kinds.
#   N1 HHH close (and low) sealed as 0 on s20, held 10 from s1, stale(3):
#      seal outcome, HHH mark at s20 (equity, ctx planes), sizing helper.
#   N2 strict preset with the supported HHH dividend (held): run status,
#      completion row and retained evidence, against a terminal "refuse"
#      (research preset with held_terminal_position = "refuse", CCC held).
#
#   sh dev/audit/pit_universe/run_low.sh dev/audit/pit_universe/probes/S2_nonpositive.R <log>
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all("C:/tmp/ws22-b", quiet = TRUE, compile = FALSE))
source("C:/Users/maxth/Documents/GitHub/ledgr/dev/audit/pit_universe/fixture.R")
options(width = 200, warn = 1)
iso <- function(x) format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
fx <- pit_audit_fixture("announcement", status_coverage = "full")
close_at <- function(k) pit_audit_at(fx$sessions[k], if (k == 30L) "13:00:00" else "16:00:00")
q <- function(db, sql, ...) { con <- DBI::dbConnect(duckdb::duckdb(), db, read_only = TRUE); on.exit(DBI::dbDisconnect(con, shutdown = TRUE)); DBI::dbGetQuery(con, sql, params = list(...)) }

# ---- N1 zero close ---------------------------------------------------------------
fz <- fx
row <- which(fz$bars$instrument_id == "HHH" & fz$bars$ts_utc == close_at(20))
fz$bars$close[row] <- 0; fz$bars$low[row] <- 0
db <- tempfile(fileext = ".duckdb")
snap <- tryCatch(pit_audit_snapshot(fz, db_path = db), error = identity)
if (inherits(snap, "error")) cat("[N1] seal ERROR", conditionMessage(snap), "\n") else {
  cat("[N1] seal: accepted (HHH s20 close 0)\n")
  strategy <- function(ctx, params) {
    t <- ctx$hold()
    if (ctx$ts_utc == params$t1) t[["HHH"]] <- 10
    if (ctx$ts_utc %in% params$watch) {
      i <- match("HHH", ctx$universe)
      w <- tryCatch({ s <- ledgr_selection(ctx, where = ctx$universe == "HHH"); r <- ledgr_target_rebalance(ledgr_weight_equal(s), ctx); r[["HHH"]] }, error = function(e) paste("ERROR", class(e)[[1]]))
      options(probe.seen = c(getOption("probe.seen"), stats::setNames(sprintf("close %s priced %s risk_mark %s mark_source %s tradable %s rebalance_target %s",
                                 ctx$vec$close[[i]], ctx$vec$priced[[i]], ctx$vec$risk_mark[[i]], ctx$vec$mark_source[[i]],
                                 "HHH" %in% ctx$tradable(), w), ctx$ts_utc)))
    }
    t
  }
  exp <- ledgr_experiment(snap, strategy, universe = ledgr_universe_members(fx$universe_id), valuation_policy = ledgr_valuation_stale(3),
                          cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1e5))
  watch <- vapply(19:21, function(k) iso(close_at(k)), "")
  bt <- ledgr_run(exp, params = list(t1 = iso(close_at(1)), watch = watch), run_id = "N1")
  eq <- as.data.frame(ledgr_results(bt, "equity")); eq <- eq[iso(eq$ts_utc) %in% watch, c("ts_utc", "positions_value", "equity")]
  cat("[N1] equity s19..s21:", paste(iso(eq$ts_utc), eq$positions_value, eq$equity, collapse = " | "), "\n")
  for (w in watch) cat("[N1] ctx at", w, ":", getOption("probe.seen")[w], "\n")
  cat("[N1] status", ledgr_run_info(snap, "N1")$status, "\n")
  close(bt); ledgr_snapshot_close(snap)
}

# ---- N2 refusal kinds -----------------------------------------------------------
db2 <- tempfile(fileext = ".duckdb")
snap2 <- pit_audit_snapshot(fx, db_path = db2)
buy <- function(ctx, params) { t <- ctx$hold(); if (ctx$ts_utc == params$t1) t[[params$id]] <- 10; t }
cases <- list(
  strict_dividend = list(id = "HHH", pol = ledgr_corporate_actions_strict()),
  terminal_refuse = list(id = "CCC", pol = ledgr_corporate_actions(held_terminal_position = "refuse"))
)
for (nm in names(cases)) {
  cs <- cases[[nm]]
  exp <- ledgr_experiment(snap2, buy, universe = ledgr_universe_members(fx$universe_id), valuation_policy = ledgr_valuation_stale(3),
                          cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1e5), corporate_action_policy = cs$pol)
  r <- tryCatch(ledgr_run(exp, params = list(t1 = iso(close_at(1)), id = cs$id), run_id = nm), error = identity)
  cr <- q(db2, "SELECT intended_terminal_status, stop_reason, achieved_end_utc FROM run_completion WHERE run_id = ?", nm)
  cat(sprintf("[N2 %s] call: %s; runs.status %s; completion %s; equity rows %d; ledger rows %d; diagnostics rows %d\n", nm,
              if (inherits(r, "error")) paste("ERROR", class(r)[[1]]) else "returned",
              q(db2, "SELECT status FROM runs WHERE run_id = ?", nm)$status,
              if (nrow(cr)) paste(cr$intended_terminal_status, cr$stop_reason, iso(cr$achieved_end_utc)) else "none",
              q(db2, "SELECT COUNT(*) n FROM equity_curve WHERE run_id = ?", nm)$n,
              q(db2, "SELECT COUNT(*) n FROM ledger_events WHERE run_id = ?", nm)$n,
              q(db2, "SELECT COUNT(*) n FROM run_diagnostics WHERE run_id = ?", nm)$n))
  if (!inherits(r, "error")) close(r)
}
ledgr_snapshot_close(snap2)
