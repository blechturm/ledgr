# Workstream 31 per-call clocks (LDG-2915).
#
# Usage, from any directory:
#
#   Rscript dev/bench/v0_2_0_2_workstream31/connection_clocks.R <tree> <arm> <out.csv>
#
# Loads the ledgr source tree <tree> and appends one row per measurement to
# <out.csv>, labelled <arm>. Run the arms in alternating order, one process
# each. Warm clock: each measured call runs once untimed first.
#
# Measurements, on the small pipeline of connection_census.R (two instruments,
# four pulses, flat strategy): `ledgr_experiment()`, `ledgr_run()`,
# `summary()` of a run, and `ledgr_sweep()` of a two-candidate grid, each the
# median of 20 calls. Every call starts from a closed snapshot, the state a
# session is in after `ledgr_experiment()`. `sweep_repeat` times sweeps without
# closing the snapshot between them: the earlier code left the snapshot's
# connection open after a sweep, so its repeats skipped an open. Bytes are
# `Rprofmem()` vector allocations of one further call.

args <- commandArgs(trailingOnly = TRUE)
tree <- args[[1L]]; arm <- args[[2L]]; out_path <- args[[3L]]
suppressMessages(pkgload::load_all(tree, quiet = TRUE, compile = FALSE))

allocated_bytes <- function(f) {
  path <- tempfile()
  Rprofmem(path, threshold = 0)
  f()
  Rprofmem(NULL)
  lines <- readLines(path, warn = FALSE)
  sum(as.numeric(sub(" :.*$", "", lines[grepl("^[0-9]+ :", lines)])))
}
other_r_processes <- function() {
  listing <- tryCatch(utils::read.csv(text = system2("tasklist", c("/FO", "CSV"), stdout = TRUE)),
    error = function(e) NULL)
  if (is.null(listing)) return(NA_integer_)
  sum(grepl("^(R|Rscript|Rterm)\\.exe$", listing[[1L]], ignore.case = TRUE)) - 1L
}

bars <- data.frame(
  ts_utc = rep(as.POSIXct(paste(as.Date("2026-02-02") + 0:3, "16:00:00"), tz = "UTC"), each = 2L),
  instrument_id = rep(c("AAA", "BBB"), 4L),
  open = 10, high = 10, low = 10, close = 10, volume = 1000
)
db_path <- tempfile(fileext = ".duckdb")
snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path, snapshot_id = "clock")
strategy <- function(ctx, params) ctx$flat()
grid <- ledgr_param_grid(a = list(), b = list())
make_exp <- function() {
  ledgr_experiment(snapshot, strategy, opening = ledgr_opening(cash = 1000), cost_model = ledgr_cost_zero())
}
exp <- make_exp()
bt <- suppressWarnings(ledgr_run(exp, run_id = "clock_summary"))
close(bt)
run_id <- 0L

calls <- list(
  experiment = function() make_exp(),
  run = function() {
    run_id <<- run_id + 1L
    close(suppressWarnings(ledgr_run(exp, run_id = sprintf("clock_%03d", run_id))))
  },
  summary = function() utils::capture.output(summary(bt)),
  sweep = function() suppressWarnings(ledgr_sweep(exp, grid))
)
from_closed <- function(f) function() {
  ledgr_snapshot_close(snapshot)
  f()
}
timed <- function(f, before = function() NULL, n = 20L) {
  before()
  f()
  stats::median(vapply(seq_len(n), function(i) {
    before()
    start <- proc.time()[["elapsed"]]
    f()
    proc.time()[["elapsed"]] - start
  }, numeric(1)))
}
close_snapshot <- function() ledgr_snapshot_close(snapshot)

rows <- lapply(names(calls), function(name) {
  f <- calls[[name]]
  data.frame(arm = arm, measure = name, seconds = timed(f, before = close_snapshot),
    bytes = allocated_bytes(from_closed(f)), other_r = other_r_processes())
})
rows[[length(rows) + 1L]] <- data.frame(arm = arm, measure = "sweep_repeat",
  seconds = timed(calls$sweep), bytes = allocated_bytes(calls$sweep), other_r = other_r_processes())
ledgr_snapshot_close(snapshot)
out <- do.call(rbind, rows)
utils::write.table(out, out_path, sep = ",", row.names = FALSE, col.names = !file.exists(out_path),
  append = file.exists(out_path))
cat("recorded", nrow(out), "measurements for", arm, "\n")
