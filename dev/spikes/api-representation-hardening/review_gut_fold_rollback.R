# Final-review gut for the API hardening synthesis (2026-09-09, baseline 27a95f2).
# Question: is a periodic flush inside the fold a durable checkpoint? Three committed runs
# on the probe fixture with checkpoint_every = 2, inspected through a fresh connection.
# Run from the package root: Rscript dev/spikes/api-representation-hardening/review_gut_fold_rollback.R
#
# Recorded result:
#   A mid-fold error after a periodic flush: FAILED, ledger_events=0, strategy_state=0, equity_curve=0
#   B partial run via max_pulses = 3:         RUNNING, ledger_events=3, strategy_state=0, equity_curve=0
#   C clean full run:                         DONE,    ledger_events=7, strategy_state=0, equity_curve=8
suppressPackageStartupMessages(pkgload::load_all(".", quiet = TRUE))
ts <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:7
mk <- function(id, open, close) data.frame(instrument_id = id, ts_utc = ts, open = open, high = pmax(open, close) + 1, low = pmin(open, close) - 1, close = close, volume = 1000)
bars <- rbind(mk("AAA", 100 + 0:7, c(100, 103, 101, 105, 104, 108, 107, 110)), mk("BBB", 50 + 0:7, c(50, 49, 52, 51, 54, 53, 56, 55)))
inspect <- function(db, run_id, label) {
  con <- DBI::dbConnect(duckdb::duckdb(), db, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  q <- function(sql) DBI::dbGetQuery(con, sql, params = list(run_id))
  runs <- q("SELECT status, error_msg FROM runs WHERE run_id = ?")
  cat(sprintf("%s: status=%s | ledger_events=%d | strategy_state=%d | equity_curve=%d | features=%d | error=%s\n",
    label, runs$status[[1]],
    q("SELECT COUNT(*) AS n FROM ledger_events WHERE run_id = ?")$n,
    q("SELECT COUNT(*) AS n FROM strategy_state WHERE run_id = ?")$n,
    q("SELECT COUNT(*) AS n FROM equity_curve WHERE run_id = ?")$n,
    q("SELECT COUNT(*) AS n FROM features WHERE run_id = ?")$n,
    substr(as.character(runs$error_msg[[1]]), 1, 60)))
}
# Scenario A: strategy error at pulse 4, after one periodic flush (checkpoint_every = 2)
grow <- function(ctx, params) {
  pos <- ctx$vec$positions[[ctx$idx("AAA")]]
  if (pos >= 15) stop("injected mid-fold failure")
  t <- ctx$flat(); t["AAA"] <- pos + 5; t
}
dbA <- tempfile(fileext = ".duckdb")
snapA <- ledgr_snapshot_from_df(bars, db_path = dbA, snapshot_id = "gut")
resA <- tryCatch(suppressWarnings(ledgr_backtest(snapshot = snapA, strategy = grow, initial_cash = 10000,
  cost_model = ledgr_cost_zero(), checkpoint_every = 2L, db_path = dbA, run_id = "gut_fold_error")),
  error = function(e) { cat("A raised:", class(e)[[1]], "\n"); NULL })
ledgr_snapshot_close(snapA)
inspect(dbA, "gut_fold_error", "A mid-fold error after a periodic flush")
# Scenario B: same strategy without the error, stopped by max_pulses = 3 (partial run)
keep <- function(ctx, params) { pos <- ctx$vec$positions[[ctx$idx("AAA")]]; t <- ctx$flat(); t["AAA"] <- pos + 5; t }
dbB <- tempfile(fileext = ".duckdb")
snapB <- ledgr_snapshot_from_df(bars, db_path = dbB, snapshot_id = "gut")
resB <- tryCatch(suppressWarnings(ledgr_backtest(snapshot = snapB, strategy = keep, initial_cash = 10000,
  cost_model = ledgr_cost_zero(), checkpoint_every = 2L, db_path = dbB, run_id = "gut_partial",
  control = list(max_pulses = 3L))), error = function(e) { cat("B raised:", conditionMessage(e), "\n"); NULL })
ledgr_snapshot_close(snapB)
inspect(dbB, "gut_partial", "B partial run via max_pulses = 3")
# Scenario C: clean full run for reference
dbC <- tempfile(fileext = ".duckdb")
snapC <- ledgr_snapshot_from_df(bars, db_path = dbC, snapshot_id = "gut")
resC <- suppressWarnings(ledgr_backtest(snapshot = snapC, strategy = keep, initial_cash = 10000,
  cost_model = ledgr_cost_zero(), checkpoint_every = 2L, db_path = dbC, run_id = "gut_clean"))
close(resC); ledgr_snapshot_close(snapC)
inspect(dbC, "gut_clean", "C clean full run")
