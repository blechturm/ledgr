# Workstream 30 warmup clocks (LDG-2910).
#
# Usage, from any directory:
#
#   Rscript dev/bench/v0_2_0_2_workstream30/warmup_clocks.R <tree> <arm> <out.csv>
#
# Loads the ledgr source tree <tree> and appends one row per measurement to
# <out.csv>, labelled <arm>. Run the arms in alternating order, one process
# each. Warm clock. Per-call clocks time 200,000 calls of the one-argument form
# and of the hand-built guard at axis 10, 50,000 of the hand-built guard at
# axis 500, and 5,000 and 2,000 calls of the context helpers at axes 10 and
# 500; three repetitions, median. Windows' 10 ms clock tick sets these counts.
#
# Measurements: the one-argument form on a three-feature named vector, both
# arms; and, at decision axes of 10 and 500 in a dense context and in a ragged
# one (half the axis members, one member restricted, one held nonmember), the
# hand-built guard `!anyNA(values[ctx$vec$admissible])` in both arms and the
# context form `ledgr_passed_warmup(ctx, values)` where the tree has it, with
# `ledgr_signal(ctx, values = values)` as the reference cost of the shared
# context entrance. Bytes
# are `Rprofmem()` vector allocations, the `bench::mark()` `mem_alloc` meter.

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
seconds_per_call <- function(f, calls, reps = 3L) {
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
record <- function(measure, f, calls) {
  rows[[length(rows) + 1L]] <<- data.frame(arm = arm, measure = measure, unit = "call",
    seconds = seconds_per_call(f, calls), bytes = allocated_bytes(f),
    other_r = other_r_processes(), stringsAsFactors = FALSE)
}

mapped <- c(ret_5 = 0.02, sma_10 = 101, sma_20 = 99)
record("one_argument_form", function() ledgr_passed_warmup(mapped), 200000L)

make_ctx <- function(n, ragged) {
  ids <- sprintf("I%04d", seq_len(n))
  ts <- as.POSIXct("2026-01-02 21:00:00", tz = "UTC")
  px <- 10 + seq_len(n) %% 7
  bars <- data.frame(instrument_id = ids, ts_utc = rep(ts, n), open = px, high = px, low = px,
    close = px, volume = 100, stringsAsFactors = FALSE)
  positions <- stats::setNames(numeric(n), ids)
  if (ragged) positions[[n]] <- 2
  ctx <- ns$ledgr_pulse_context(run_id = "clock", ts_utc = ts, universe = ids, bars = bars,
    features = data.frame(), positions = positions, cash = 1e6, equity = 1e6)
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
  ctx <- ns$ledgr_update_pulse_context_helpers(ctx, bars = bars, features = data.frame(),
    positions = positions, universe = ids, availability = view)
  ctx$availability_active <- TRUE
  ctx$members <- members
  ctx
}
has_context_form <- "values" %in% names(formals(ledgr_passed_warmup))
for (ragged in c(FALSE, TRUE)) for (n in c(10L, 500L)) {
  ctx <- make_ctx(n, ragged)
  values <- as.numeric(ctx$vec$close)
  calls <- if (n == 10L) 5000L else 2000L
  shape <- sprintf("%s_axis_%d", if (ragged) "ragged" else "dense", n)
  record(paste0("hand_built_", shape), function() !anyNA(values[ctx$vec$admissible]),
    if (n == 10L) 200000L else 50000L)
  record(paste0("signal_reference_", shape), function() ledgr_signal(ctx, values = values), calls)
  if (has_context_form) {
    record(paste0("context_form_", shape), function() ledgr_passed_warmup(ctx, values), calls)
  }
}

out <- do.call(rbind, rows)
utils::write.table(out, out_path, sep = ",", row.names = FALSE, col.names = !file.exists(out_path),
  append = file.exists(out_path))
cat("recorded", nrow(out), "measurements for", arm, "\n")
