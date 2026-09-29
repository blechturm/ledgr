# Workstream 30 strategy-helper clocks (LDG-2908 with LDG-2912, and later
# helper tickets).
#
# Usage, from any directory:
#
#   Rscript dev/bench/v0_2_0_2_workstream30/helper_clocks.R <tree> <arm> <out.csv>
#
# Loads the ledgr source tree <tree> and appends one row per measurement to
# <out.csv>, labelled <arm>. Run the arms in alternating order, one process
# each. Warm clock: every timed call is preceded by warm-up calls. Per-call
# clocks time 5,000 calls at axis 10 and 2,000 at axis 500, so the 10 ms
# elapsed-clock tick on this platform resolves to 2 to 5 microseconds.
#
# Per-call measurements, at decision axes of 10 and 500 instruments, in a
# dense context and in a ragged availability context (half the axis members,
# one member target-restricted, one held nonmember):
#   signal_return, signal_values, selection_default, selection_where,
#   selection_ids, top_n, target_quantity, rebalance.
# Per-pulse measurements: a dense run (100 x 250) and an availability run
# (50 x 120) whose strategy is
#   ctx |> ledgr_selection(where = ledgr_signal_return(ctx, 1) > 0,
#                          missing = "exclude") |> ledgr_target_quantity(ctx, 1)
#
# Bytes are vector allocations recorded by `Rprofmem()`, the meter
# `bench::mark()` reports as `mem_alloc`.

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
  stats::median(vapply(seq_len(reps), function(r) {
    start <- proc.time()[["elapsed"]]
    for (i in seq_len(calls)) f()
    (proc.time()[["elapsed"]] - start) / calls
  }, numeric(1)))
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

make_ctx <- function(n, ragged) {
  ids <- sprintf("I%04d", seq_len(n))
  ts <- as.POSIXct("2026-01-02 21:00:00", tz = "UTC")
  px <- 10 + seq_len(n) %% 7
  bars <- data.frame(instrument_id = ids, ts_utc = rep(ts, n), open = px, high = px, low = px,
    close = px, volume = 100, stringsAsFactors = FALSE)
  features <- data.frame(instrument_id = ids, ts_utc = rep(ts, n), feature_name = "return_5",
    feature_value = ((seq_len(n) * 37) %% 11 - 5) / 100, stringsAsFactors = FALSE)
  positions <- stats::setNames(numeric(n), ids)
  if (ragged) positions[[n]] <- 2
  ctx <- ns$ledgr_pulse_context(run_id = "clock", ts_utc = ts, universe = ids, bars = bars,
    features = features, positions = positions, cash = 1e6, equity = 1e6)
  if (!ragged) return(ctx)
  members <- ids[seq_len(n %/% 2L)]
  restricted <- ids == members[[1L]]
  view <- list(
    member = stats::setNames(ids %in% members, ids),
    held = stats::setNames(positions != 0, ids),
    target_restricted = stats::setNames(restricted, ids),
    target_restriction_reason = stats::setNames(ifelse(restricted, "halted", ""), ids),
    priced = stats::setNames(rep(TRUE, n), ids),
    mark_age = stats::setNames(rep(0L, n), ids),
    risk_mark = stats::setNames(px, ids),
    mark_source = stats::setNames(rep("current_close", n), ids))
  ctx <- ns$ledgr_update_pulse_context_helpers(ctx, bars = bars, features = features,
    positions = positions, universe = ids, availability = view)
  ctx$availability_active <- TRUE
  ctx$members <- members
  ctx
}

for (ragged in c(FALSE, TRUE)) for (n in c(10L, 500L)) {
  ctx <- make_ctx(n, ragged)
  feat <- ctx$vec$feature("return_5")
  sig <- ledgr_signal_return(ctx, lookback = 5)
  sel <- ledgr_selection(ctx, where = feat > 0, missing = "exclude")
  weights <- ledgr_weight_equal(sel)
  some_ids <- ctx$universe[seq_len(min(5L, n))]
  calls <- list(
    signal_return = function() ledgr_signal_return(ctx, lookback = 5),
    signal_values = function() ledgr_signal(ctx, values = feat),
    selection_default = function() ledgr_selection(ctx),
    selection_where = function() ledgr_selection(ctx, where = feat > 0, missing = "exclude"),
    selection_ids = function() ledgr_selection(ctx, ids = some_ids),
    top_n = function() ledgr_select_top_n(sig, 5, partial = "allow"),
    target_quantity = function() ledgr_target_quantity(sel, ctx, 10),
    rebalance = function() ledgr_target_rebalance(weights, ctx)
  )
  for (name in names(calls)) {
    f <- calls[[name]]
    record(sprintf("%s_%s_axis_%d", name, if (ragged) "ragged" else "dense", n),
      seconds_per_call(f, if (n == 10L) 5000L else 2000L, reps = 3L), allocated_bytes(f), "call")
  }
}

make_bars <- function(n_ids, n_days) {
  ids <- sprintf("I%03d", seq_len(n_ids))
  days <- as.POSIXct("2020-01-01 16:00:00", tz = "UTC") + 86400 * (seq_len(n_days) - 1L)
  grid <- expand.grid(instrument_id = ids, ts_utc = days, KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  grid$close <- 100 + (seq_len(nrow(grid)) %% 7L)
  grid$open <- grid$close; grid$high <- grid$close + 1; grid$low <- grid$close - 1; grid$volume <- 1000
  list(ids = ids, days = days, bars = grid)
}
pipeline <- function(ctx, params) {
  ctx |>
    ledgr_selection(where = ledgr_signal_return(ctx, lookback = 1) > 0, missing = "exclude") |>
    ledgr_target_quantity(ctx, 1)
}
time_run <- function(exp, pulses) {
  run_once <- function() close(suppressWarnings(ledgr_run(exp)))
  run_once()
  seconds <- stats::median(vapply(1:3, function(i) {
    start <- proc.time()[["elapsed"]]
    run_once()
    proc.time()[["elapsed"]] - start
  }, numeric(1))) / pulses
  c(seconds = seconds, bytes = allocated_bytes(run_once) / pulses)
}
features <- list(ledgr_ind_returns(1))
dense <- make_bars(100L, 250L)
dense_exp <- ledgr_experiment(ledgr_snapshot_from_df(dense$bars, db_path = tempfile(fileext = ".duckdb")),
  pipeline, features = features, cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1e6))
m <- time_run(dense_exp, 250L)
record("dense_pipeline_run", m[["seconds"]], m[["bytes"]], "pulse")

avail <- make_bars(50L, 120L)
sessions <- ledgr_facts_sessions(data.frame(session_date = as.Date(avail$days), status = "open",
  session_open = "09:30:00", session_close = "16:00:00",
  knowledge_time = as.POSIXct("2019-12-31", tz = "UTC"), source = "clock", stringsAsFactors = FALSE),
  venue_id = "CLOCK", timezone = "UTC")
membership <- ledgr_facts_membership_intervals(data.frame(instrument_id = avail$ids,
  effective_from = avail$days[[1L]], member = TRUE, source = "clock", stringsAsFactors = FALSE),
  universe_id = "clock", knowledge = "assume_effective")
avail_exp <- ledgr_experiment(
  ledgr_snapshot_from_df(avail$bars, instruments_df = data.frame(instrument_id = avail$ids),
    facts = ledgr_facts(sessions, membership), db_path = tempfile(fileext = ".duckdb")),
  pipeline, features = features, universe = ledgr_universe_members("clock"),
  valuation_policy = ledgr_valuation_stale(2L), cost_model = ledgr_cost_zero(),
  opening = ledgr_opening(cash = 1e6))
m <- time_run(avail_exp, 120L)
record("availability_pipeline_run", m[["seconds"]], m[["bytes"]], "pulse")

out <- do.call(rbind, rows)
utils::write.table(out, out_path, sep = ",", row.names = FALSE, col.names = !file.exists(out_path),
  append = file.exists(out_path))
cat("recorded", nrow(out), "measurements for", arm, "\n")
