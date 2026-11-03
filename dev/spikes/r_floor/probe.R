# Probe: what ledgr does for the published SMA5/10 transition crossover on a
# fixed basket, recorded on a tiny fixture before any floor code is written.
# Usage: Rscript dev/spikes/r_floor/probe.R <ledgr lib>
suppressPackageStartupMessages(library(ledgr, lib.loc = commandArgs(TRUE)[[1]]))
source(file.path("dev", "spikes", "r_floor", "fixture.R"))

fx <- r_floor_fixture(3L, 40L)
bt <- r_floor_ledgr_run(fx, "probe")
fills <- as.data.frame(ledgr_results(bt, "fills"))
equity <- as.data.frame(ledgr_results(bt, "equity"))
close(bt)

cat("fills columns:", paste(names(fills), collapse = ", "), "\n")
print(utils::head(fills[c("instrument_id", "ts_utc", "side", "qty", "price")], 6), row.names = FALSE)
cat("\nequity columns:", paste(names(equity), collapse = ", "), "\n")
print(utils::head(equity, 3), row.names = FALSE)

# Where does the first fill sit relative to its signal and which price does
# it use? Compare with the bars of that instrument.
first <- fills[1, ]
b <- fx$bars[fx$bars$instrument_id == first$instrument_id, ]
k <- match(as.numeric(first$ts_utc), as.numeric(b$ts_utc))
cat(sprintf("\nfirst fill %s at %s: price %.8f, that bar's open %.8f, close %.8f, previous close %.8f\n",
  first$instrument_id, format(first$ts_utc), first$price, b$open[k], b$close[k], b$close[k - 1L]))

# Is ledgr's SMA the same as TTR::SMA on the close series?
sma <- TTR::SMA(b$close, 5L)
cat(sprintf("TTR::SMA(close, 5) at the bar before the fill: %.10f\n", sma[k - 1L]))
cat(sprintf("equity rows %d for %d pulses; last pulse fills: %d\n", nrow(equity), 40L,
  sum(as.numeric(fills$ts_utc) > max(as.numeric(fx$bars$ts_utc)))))
