# Q7: fixed and per-cell cost of a current-product history read and a
# feature vector read, on a real pulse context from ledgr_pulse_snapshot().
suppressMessages({
  pkgload::load_all(".", quiet = TRUE, compile = FALSE)
  library(microbenchmark)
})

one_shape <- function(n_inst, n_pulse, Ls) {
  bars <- ledgr_sim_bars(n_inst, n_pulse, seed = 20260530L,
    start = "2020-01-01", instrument_prefix = "P")
  bars$ts_utc <- bars$ts_utc + 21 * 3600
  snap <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"),
    snapshot_id = paste0("q7_", n_inst), price_basis = "split_adjusted")
  features <- ledgr_feature_map(
    fast = ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L))
  ts <- sort(unique(bars$ts_utc))[as.integer(n_pulse * 0.8)]
  strategy <- function(ctx, params) ctx$hold()
  exp <- ledgr_experiment(snap, strategy, features = features,
    opening = ledgr_opening(cash = 1e7), cost_model = ledgr_cost_zero(),
    risk_chain = ledgr_risk_none())
  ctx <- ledgr_pulse_snapshot(exp, ts_utc = ts)
  on.exit(close(ctx))
  rows <- list(data.frame(n_inst = n_inst, read = "ctx$fast (feature vector)",
    median_us = median(microbenchmark(ctx$fast, times = 500L)$time) / 1000))
  for (L in Ls) {
    x <- ledgr_history_matrix(ctx, bar = "close", lookback = L)
    stopifnot(nrow(x) == L)
    rows[[length(rows) + 1L]] <- data.frame(n_inst = n_inst,
      read = sprintf("history bar close L=%d", L),
      median_us = median(microbenchmark(
        ledgr_history_matrix(ctx, bar = "close", lookback = L), times = 200L)$time) / 1000)
  }
  for (L in Ls) {
    x <- ledgr_history_matrix(ctx, feature = "fast", lookback = L)
    rows[[length(rows) + 1L]] <- data.frame(n_inst = n_inst,
      read = sprintf("history feature fast L=%d", L),
      median_us = median(microbenchmark(
        ledgr_history_matrix(ctx, feature = "fast", lookback = L), times = 200L)$time) / 1000)
  }
  do.call(rbind, rows)
}

out <- rbind(one_shape(10L, 400L, c(5L, 20L, 252L)),
             one_shape(500L, 400L, c(5L, 20L, 252L)))
out$median_us <- round(out$median_us, 1)
print(out, row.names = FALSE)
