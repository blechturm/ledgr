# Probe: does ledgr value and fill at vendor-carried zero-volume bars?
# AAA trades normally for 3 sessions, then has 6 flat zero-volume sessions at
# the carried close of 100 (a halt as a dense vendor represents it), then
# resumes at 1. The strategy buys 10 on pulse 1 and targets 0 on pulse 5,
# i.e. during the carried stretch.
# Rscript dev/spikes/terminal-outcomes/carried_price_probe.R <ledgr_repo>
args <- commandArgs(TRUE)
suppressMessages(pkgload::load_all(args[[1L]], quiet = TRUE, compile = FALSE))
days <- as.POSIXct("2024-01-02 21:00:00", tz = "UTC") + 86400 * c(0, 1, 2, 3, 6, 7, 8, 9, 10, 13)
close <- c(100, 101, 100, 100, 100, 100, 100, 100, 100, 1)
volume <- c(1e5, 1e5, 1e5, 0, 0, 0, 0, 0, 0, 5e6)
bars <- rbind(
  data.frame(ts_utc = days, instrument_id = "AAA", open = close, high = close, low = close,
             close = close, volume = volume),
  data.frame(ts_utc = days, instrument_id = "BBB", open = 50, high = 50, low = 50, close = 50, volume = 1e5))
snap <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"), snapshot_id = "carried")
strategy <- function(ctx, params) {
  n <- if (is.null(ctx$state_prev$n)) 1L else ctx$state_prev$n + 1L
  t <- ctx$hold()
  if (n == 1L) t[["AAA"]] <- 10
  if (n == 5L) t[["AAA"]] <- 0
  list(targets = t, state_update = list(n = n))
}
bt <- ledgr_run(ledgr_experiment(snap, strategy, cost_model = ledgr_cost_zero(),
                                 opening = ledgr_opening(cash = 10000)), run_id = "carried")
fills <- ledgr_results(bt, "fills")
print(fills[, intersect(c("ts_utc", "instrument_id", "side", "qty", "price"), names(fills))])
eq <- ledgr_results(bt, "equity")
print(eq[, intersect(c("ts_utc", "equity", "positions_value"), names(eq))])
cat("status:", ledgr_run_info(snap, bt$run_id)$status, "\n")
close(bt); ledgr_snapshot_close(snap)
