suppressMessages(pkgload::load_all("C:/Users/maxth/Documents/GitHub/ledgr", quiet = TRUE, compile = FALSE))
day <- function(d) as.POSIXct(as.Date("2020-01-01") + d - 1L, tz = "UTC")
set.seed(11); n <- 3000; cl <- round(100 + cumsum(rnorm(n)), 4)
bars <- data.frame(instrument_id = "A", ts_utc = day(seq_len(n)), open = cl, high = cl + 1, low = cl - 1, close = cl, volume = 1e5)
burn <- function(ind) {
  full <- ledgr:::ledgr_compute_feature_series(bars, ind)
  late <- ledgr:::ledgr_compute_feature_series(bars[1001:n, ], ind)
  idx <- 1001:n; d <- full[idx] != late[idx - 1000] | (is.na(full[idx]) != is.na(late[idx - 1000]))
  d[is.na(d)] <- TRUE
  last_diff <- max(which(d)); c(bars_until_identical = last_diff, identical_after = all(!d[(last_diff + 1):length(d)]))
}
cat("bars after restart until bit-identical to the full-history series (then identical to the end):\n")
for (nm in c("EMA14", "RSI14", "EMA50")) {
  ind <- switch(nm, EMA14 = ledgr_ind_ttr("EMA", input = "close", n = 14L), RSI14 = ledgr_ind_ttr("RSI", input = "close", n = 14L),
                EMA50 = ledgr_ind_ttr("EMA", input = "close", n = 50L))
  r <- burn(ind); cat(sprintf("  %-6s %4d  (identical thereafter: %s)\n", nm, r[[1]], as.logical(r[[2]])))
}
