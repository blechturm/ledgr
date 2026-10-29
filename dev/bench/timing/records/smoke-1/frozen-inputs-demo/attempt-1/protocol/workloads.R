# Protocol smoke-1 (LDG-3155): the harness's example protocol. Not timing
# evidence. measure.R sources this file after loading the arm's ledgr, so it
# may use only ledgr's public API as both arms export it.
#
# small_dense: 10 instruments x 250 sessions of deterministic prices (no
# RNG). The strategy buys 10 of every instrument when flat and goes flat when
# holding, so it trades on every pulse. Clocks, as.numeric(Sys.time()):
#   cold - from just before ledgr_snapshot_from_df() to just after the first
#          run's close(): snapshot creation, sealing and one committed run;
#   warm - from just after that to just after a second run's close() on the
#          same open snapshot.
# Work is both runs' trade counts, read untimed from ledgr_run_list().

small_dense <- function(args, work_dir) {
  ids <- sprintf("S%02d", 1:10)
  days <- 250L
  ts <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * (seq_len(days) - 1L)
  px <- as.vector(outer(seq_len(days), seq_along(ids), function(d, j) 100 + 5 * sin(d / 7 + j)))
  bars <- data.frame(instrument_id = rep(ids, each = days), ts_utc = rep(ts, length(ids)), open = px,
    high = px * 1.01, low = px * 0.99, close = px, volume = 1e5, stringsAsFactors = FALSE)
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    if (all(ctx$hold() == 0)) targets[] <- params$qty
    targets
  }
  db_path <- file.path(work_dir, sprintf("smoke_%d.duckdb", Sys.getpid()))

  t0 <- as.numeric(Sys.time())
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path, snapshot_id = "smoke_small_dense")
  exp <- ledgr_experiment(snapshot, strategy, opening = ledgr_opening(cash = 1e6),
    cost_model = ledgr_cost_spread_bps(5))
  close(ledgr_run(exp, params = list(qty = 10), run_id = "cold"))
  t1 <- as.numeric(Sys.time())
  close(ledgr_run(exp, params = list(qty = 10), run_id = "warm"))
  t2 <- as.numeric(Sys.time())

  runs <- as.data.frame(ledgr_run_list(snapshot))
  work <- paste(runs$n_trades[match(c("cold", "warm"), runs$run_id)], collapse = ";")
  ledgr_snapshot_close(snapshot)
  list(seconds = c(cold = t1 - t0, warm = t2 - t1), work = work)
}
# edited during the window
