# Workstream 38 scaled all-fill clock.
# Usage: Rscript fold_phase_all_fill.R <package-root> [instruments] [pulses]

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L) {
  stop("Usage: fold_phase_all_fill.R <package-root> [instruments] [pulses]")
}
root <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
n_instruments <- if (length(args) >= 2L) as.integer(args[[2L]]) else 5000L
n_pulses <- if (length(args) >= 3L) as.integer(args[[3L]]) else 8L
stopifnot(n_instruments >= 5000L, n_pulses >= 2L)

suppressPackageStartupMessages(pkgload::load_all(
  root,
  quiet = TRUE,
  export_all = FALSE,
  helpers = FALSE,
  compile = FALSE
))
instrument_ids <- sprintf("I%05d", seq_len(n_instruments))
timestamps <- as.POSIXct("2020-01-01", tz = "UTC") +
  86400 * (seq_len(n_pulses) - 1L)
bars <- data.frame(
  ts_utc = rep(timestamps, each = n_instruments),
  instrument_id = rep(instrument_ids, times = n_pulses),
  open = 10,
  high = 11,
  low = 9,
  close = 10,
  volume = 1e6,
  stringsAsFactors = FALSE
)
snapshot <- ledgr_snapshot_from_df(
  bars,
  db_path = tempfile(fileext = ".duckdb")
)
on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
strategy <- function(ctx, params) {
  targets <- ctx$flat()
  day <- as.integer(substr(ctx$ts_utc, 9L, 10L))
  targets[] <- if (day %% 2L == 1L) 1 else 0
  targets
}
experiment <- ledgr_experiment(
  snapshot,
  strategy,
  cost_model = ledgr_cost_zero(),
  opening = ledgr_opening(cash = 1e9)
)
gc()
elapsed <- system.time(
  ledgr_sweep(experiment, ledgr_param_grid(candidate = list()))
)[["elapsed"]]
cat(sprintf(
  "LEDGR_FOLD_ALL_FILL instruments=%d pulses=%d elapsed=%.2f\n",
  n_instruments,
  n_pulses,
  elapsed
))
