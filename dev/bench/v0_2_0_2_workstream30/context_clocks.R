# Workstream 30 context-construction clocks.
#
# Usage, from any directory:
#
#   Rscript dev/bench/v0_2_0_2_workstream30/context_clocks.R <tree> <arm> <out.csv>
#
# Loads the ledgr source tree <tree> and appends one row per measurement to
# <out.csv>, labelled <arm>. Run the two arms in alternating order, one process
# each, so machine drift falls on both. Warm clock: every measured call is
# preceded by warm-up calls, so the JIT has compiled the code it times.
#
# Measurements:
# - refresh_axis_<n>: one dense per-pulse context refresh
#   (`ledgr_refresh_pulse_context_lookup()`), which rebuilds `ctx$vec`, at
#   decision axes of 10 and 500 instruments; seconds and bytes per call.
# - dense_run: `ledgr_run()` over 100 instruments x 250 sessions on the dense
#   fast-context path, strategy `ctx$flat()`; median of three runs, seconds
#   and bytes per pulse.
# - availability_run: `ledgr_run()` over 50 instruments x 120 sessions with
#   declared sessions and membership, strategy `ctx$flat()`; per pulse.
#
# Bytes are vector allocations recorded by `Rprofmem()`, the meter
# `bench::mark()` reports as `mem_alloc`; small vectors served from R's page
# pool are not individually recorded.

args <- commandArgs(trailingOnly = TRUE)
tree <- args[[1L]]; arm <- args[[2L]]; out_path <- args[[3L]]
suppressMessages(pkgload::load_all(tree, quiet = TRUE, compile = FALSE, export_all = TRUE))
ns <- asNamespace("ledgr")

allocated_bytes <- function(f) {
  path <- tempfile()
  Rprofmem(path, threshold = 0)
  f()
  Rprofmem(NULL)
  lines <- readLines(path, warn = FALSE)
  sum(as.numeric(sub(" :.*$", "", lines[grepl("^[0-9]+ :", lines)])))
}
seconds_per_call <- function(f, calls, reps = 5L) {
  for (i in seq_len(max(3L, calls %/% 10L))) f()
  times <- vapply(seq_len(reps), function(r) {
    start <- proc.time()[["elapsed"]]
    for (i in seq_len(calls)) f()
    (proc.time()[["elapsed"]] - start) / calls
  }, numeric(1))
  stats::median(times)
}
other_r_processes <- function() {
  listing <- tryCatch(utils::read.csv(text = system2("tasklist", c("/FO", "CSV"), stdout = TRUE)),
    error = function(e) NULL)
  if (is.null(listing)) return(NA_integer_)
  sum(grepl("^(R|Rscript|Rterm)\\.exe$", listing[[1L]], ignore.case = TRUE)) - 1L
}

rows <- list()
record <- function(measure, seconds, bytes, unit) {
  rows[[length(rows) + 1L]] <<- data.frame(arm = arm, measure = measure, unit = unit,
    seconds = seconds, bytes = bytes, other_r = other_r_processes(), stringsAsFactors = FALSE)
}

dense_context <- function(n) {
  ids <- sprintf("I%04d", seq_len(n))
  ts <- as.POSIXct("2026-01-02 21:00:00", tz = "UTC")
  bars <- data.frame(instrument_id = ids, ts_utc = rep(ts, n), open = 10, high = 10, low = 10,
    close = 10, volume = 100, stringsAsFactors = FALSE)
  ns$ledgr_pulse_context(run_id = "clock", ts_utc = ts, universe = ids, bars = bars,
    features = data.frame(), positions = stats::setNames(numeric(n), ids), cash = 1, equity = 1)
}
for (n in c(10L, 500L)) {
  ctx <- dense_context(n)
  refresh <- function() ns$ledgr_refresh_pulse_context_lookup(ctx)
  record(sprintf("refresh_axis_%d", n), seconds_per_call(refresh, if (n == 10L) 2000L else 400L),
    allocated_bytes(refresh), "call")
}

make_bars <- function(n_ids, n_days) {
  ids <- sprintf("I%03d", seq_len(n_ids))
  days <- as.POSIXct("2020-01-01 16:00:00", tz = "UTC") + 86400 * (seq_len(n_days) - 1L)
  grid <- expand.grid(instrument_id = ids, ts_utc = days, KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  grid$close <- 100 + (seq_len(nrow(grid)) %% 7L)
  grid$open <- grid$close; grid$high <- grid$close + 1; grid$low <- grid$close - 1; grid$volume <- 1000
  list(ids = ids, days = days, bars = grid)
}
time_run <- function(exp, pulses) {
  run_once <- function() close(ledgr_run(exp))
  run_once()
  seconds <- stats::median(vapply(1:3, function(i) {
    start <- proc.time()[["elapsed"]]
    run_once()
    proc.time()[["elapsed"]] - start
  }, numeric(1))) / pulses
  c(seconds = seconds, bytes = allocated_bytes(run_once) / pulses)
}

dense <- make_bars(100L, 250L)
dense_snapshot <- ledgr_snapshot_from_df(dense$bars, db_path = tempfile(fileext = ".duckdb"))
dense_exp <- ledgr_experiment(dense_snapshot, function(ctx, params) ctx$flat(), cost_model = ledgr_cost_zero())
m <- time_run(dense_exp, 250L)
record("dense_run", m[["seconds"]], m[["bytes"]], "pulse")

avail <- make_bars(50L, 120L)
sessions <- ledgr_facts_sessions(data.frame(session_date = as.Date(avail$days), status = "open",
  session_open = "09:30:00", session_close = "16:00:00",
  knowledge_time = as.POSIXct("2019-12-31", tz = "UTC"), source = "clock", stringsAsFactors = FALSE),
  venue_id = "CLOCK", timezone = "UTC")
membership <- ledgr_facts_membership_intervals(data.frame(instrument_id = avail$ids,
  effective_from = avail$days[[1L]], member = TRUE, source = "clock", stringsAsFactors = FALSE),
  universe_id = "clock", knowledge = "assume_effective")
avail_snapshot <- ledgr_snapshot_from_df(avail$bars, instruments_df = data.frame(instrument_id = avail$ids),
  facts = ledgr_facts(sessions, membership), db_path = tempfile(fileext = ".duckdb"))
avail_exp <- ledgr_experiment(avail_snapshot, function(ctx, params) ctx$flat(),
  universe = ledgr_universe_members("clock"), valuation_policy = ledgr_valuation_stale(2L),
  cost_model = ledgr_cost_zero())
m <- time_run(avail_exp, 120L)
record("availability_run", m[["seconds"]], m[["bytes"]], "pulse")

out <- do.call(rbind, rows)
utils::write.table(out, out_path, sep = ",", row.names = FALSE, col.names = !file.exists(out_path),
  append = file.exists(out_path))
cat("recorded", nrow(out), "measurements for", arm, "\n")
