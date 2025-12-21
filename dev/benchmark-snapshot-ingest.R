if (requireNamespace("devtools", quietly = TRUE)) {
  devtools::load_all()
}

set.seed(123)

n <- 10000L
start_ts <- as.POSIXct("2020-01-01 09:30:00", tz = "UTC")
ts <- start_ts + seq.int(0L, n - 1L) * 60L

returns <- stats::rnorm(n, mean = 0.0001, sd = 0.001)
prices <- 100 * cumprod(1 + returns)
open <- prices
close <- prices * (1 + stats::rnorm(n, 0, 0.0003))
high <- pmax(open, close) * (1 + abs(stats::rnorm(n, 0, 0.0005)))
low <- pmin(open, close) * (1 - abs(stats::rnorm(n, 0, 0.0005)))

bars <- data.frame(
  ts_utc = format(ts, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  instrument_id = rep("BENCH", n),
  open = open,
  high = high,
  low = low,
  close = close,
  volume = round(stats::rnorm(n, 1000, 200)),
  stringsAsFactors = FALSE
)

# Warm up (load packages, initialize DuckDB, JIT).
warm <- ledgr_snapshot_from_df(bars[1:100, , drop = FALSE], db_path = ":memory:")
ledgr_snapshot_close(warm)

elapsed <- system.time({
  snap <- ledgr_snapshot_from_df(bars, db_path = ":memory:")
  ledgr_snapshot_close(snap)
})[["elapsed"]]

cat(sprintf("ledgr_snapshot_from_df 10,000 rows elapsed: %.3fs\n", elapsed))

if (elapsed > 1) {
  stop(sprintf("Ingest took %.3fs (> 1s)", elapsed))
}
