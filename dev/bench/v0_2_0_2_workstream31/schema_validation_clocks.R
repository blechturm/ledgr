# Workstream 31 schema-validation clocks (LDG-2916).
#
# Usage, from any directory:
#
#   Rscript dev/bench/v0_2_0_2_workstream31/schema_validation_clocks.R <tree> <arm> <out.csv>
#
# Loads the ledgr source tree <tree> and appends one row per measurement to
# <out.csv>, labelled <arm>. Run the arms in alternating order, one process
# each. Warm clock: the first run and the first open are not timed.
#
# Measurements: the wall time of one small `ledgr_run()` (two instruments, four
# pulses, flat strategy) repeated against one store, the median over 20 runs;
# and one `ledgr_db_init()` open-and-close of that store, the median over 20.
# Bytes are `Rprofmem()` vector allocations of one further run.

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
exp <- ledgr_experiment(
  snapshot,
  function(ctx, params) ctx$flat(),
  opening = ledgr_opening(cash = 1000),
  cost_model = ledgr_cost_zero()
)
run_id <- 0L
run_once <- function() {
  run_id <<- run_id + 1L
  close(suppressWarnings(ledgr_run(exp, run_id = sprintf("clock_%03d", run_id))))
}
open_once <- function() {
  con <- ledgr_db_init(db_path)
  DBI::dbDisconnect(con, shutdown = TRUE)
}
timed <- function(f, n = 20L) {
  f()
  stats::median(vapply(seq_len(n), function(i) {
    start <- proc.time()[["elapsed"]]
    f()
    proc.time()[["elapsed"]] - start
  }, numeric(1)))
}

rows <- list(
  data.frame(arm = arm, measure = "small_run", seconds = timed(run_once),
    bytes = allocated_bytes(run_once), other_r = other_r_processes()),
  data.frame(arm = arm, measure = "db_init_open_close", seconds = timed(open_once),
    bytes = allocated_bytes(open_once), other_r = other_r_processes())
)
ledgr_snapshot_close(snapshot)
out <- do.call(rbind, rows)
utils::write.table(out, out_path, sep = ",", row.names = FALSE, col.names = !file.exists(out_path),
  append = file.exists(out_path))
cat("recorded", nrow(out), "measurements for", arm, "\n")
