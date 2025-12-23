# ledgr v0.1.2: Engine-only benchmark (reuses sealed snapshot)
devtools::load_all()

library(tictoc)
library(tibble)

# 1) Build snapshot once
n_rows <- 100000
set.seed(42)
base <- 50000 + cumsum(rnorm(n_rows))
df_bench <- tibble(
  instrument_id = "BTC",
  ts_utc = format(
    seq(as.POSIXct("2025-01-01", tz = "UTC"), by = "min", length.out = n_rows),
    "%Y-%m-%dT%H:%M:%SZ"
  ),
  open = base,
  close = base + rnorm(n_rows, 0, 0.5),
  high = pmax(open, close) + 0.1,
  low = pmin(open, close) - 0.1,
  volume = 1000
)

tic("snapshot_build")
snap <- ledgr_snapshot_from_df(df_bench)
ledgr_snapshot_seal(snap)
toc()

# 2) Backtest loop only (reused snapshot)
strategy_bench <- function(ctx) {
  if (ctx$bars$close > 50000) return(c(BTC = 1.0))
  c(BTC = 0.0)
}

tic("backtest_run")
bt <- ledgr_backtest(
  snapshot = snap,
  strategy = strategy_bench,
  universe = "BTC",
  control = list(execution_mode = "audit_log")
)
toc()

# 3) Telemetry + sanity check
cat("\n--- ENGINE TELEMETRY ---\n")
print(ledgr:::ledgr_backtest_bench(bt))

eq <- ledgr_compute_equity_curve(bt)
if (nrow(eq) == n_rows) {
  message("SUCCESS: Equity curve fully reconstructed.")
} else {
  warning("FAILURE: Equity curve length mismatch!")
}

# 4) Optional: R6 strategy benchmark for comparison
if (requireNamespace("R6", quietly = TRUE)) {
  StratR6 <- R6::R6Class(
    "StratR6",
    public = list(
      on_pulse = function(ctx) {
        if (ctx$bars$close > 50000) return(c(BTC = 1.0))
        c(BTC = 0.0)
      }
    )
  )

  strategy_r6 <- StratR6$new()

  tic("backtest_run_r6")
  bt_r6 <- ledgr_backtest(
    snapshot = snap,
    strategy = strategy_r6,
    universe = "BTC",
    control = list(execution_mode = "audit_log")
  )
  toc()

  cat("\n--- ENGINE TELEMETRY (R6) ---\n")
  print(ledgr:::ledgr_backtest_bench(bt_r6))

  eq_r6 <- ledgr_compute_equity_curve(bt_r6)
  if (nrow(eq_r6) == n_rows) {
    message("SUCCESS: R6 equity curve fully reconstructed.")
  } else {
    warning("FAILURE: R6 equity curve length mismatch!")
  }
}
