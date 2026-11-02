args <- commandArgs(trailingOnly = TRUE)
suppressPackageStartupMessages(library(ledgr, lib.loc = args[[1]]))
bars <- ledgr_sim_bars(500L, 1260L, seed = 20260530L, start = "2020-01-01", instrument_prefix = "P")
bars$ts_utc <- bars$ts_utc + 21 * 3600
for (name in c("open", "high", "low", "close", "volume")) bars[[name]] <- round(bars[[name]], 8L)
saveRDS(bars, args[[2]])
cat(nrow(bars), "rows\n")
