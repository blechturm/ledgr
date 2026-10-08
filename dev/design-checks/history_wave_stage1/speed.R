suppressMessages(pkgload::load_all("C:/Users/maxth/Documents/GitHub/ledgr", quiet = TRUE, compile = FALSE))
day <- function(d) as.POSIXct(as.Date("1994-01-03") + d - 1L, tz = "UTC")
set.seed(3); n <- 8000; cl <- round(100 + cumsum(rnorm(n)), 4)
bars <- data.frame(instrument_id = "A", ts_utc = day(seq_len(n)), open = cl, high = cl + 1, low = cl - 1, close = cl, volume = 1e5)
t1 <- function(expr) { g <- gc(FALSE); s <- proc.time()[["elapsed"]]; force(expr); proc.time()[["elapsed"]] - s }
ema <- ledgr_ind_ttr("EMA", input = "close", n = 20L)
rsi <- ledgr_ind_ttr("RSI", input = "close", n = 14L)
sma_ttr <- ledgr_ind_ttr("SMA", input = "close", n = 20L)
reps <- 50
cat(sprintf("full-history series, one instrument, 8,000 bars (mean of %d):\n", reps))
for (nm in c("ema", "rsi", "sma_ttr")) {
  ind <- get(nm)
  el <- t1(for (i in seq_len(reps)) ledgr:::ledgr_compute_feature_series(bars, ind)) / reps
  cat(sprintf("  %-8s %.2f ms  -> x 1,200 instruments = %.1f s\n", nm, 1000 * el, el * 1200))
}
cat("today's strict per-window path, TTR SMA(20), 2,000 bars (one run):\n")
el <- t1(ledgr:::ledgr_compute_feature_series_strict_scalar(bars[1:2000, ], sma_ttr))
cat(sprintf("  %.2f s for 2,000 bars -> 8,000 bars ~ %.1f s per instrument -> x 1,200 = %.0f min\n", el, el * 4, el * 4 * 1200 / 60))
