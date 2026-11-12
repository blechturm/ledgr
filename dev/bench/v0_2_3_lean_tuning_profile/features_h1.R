# Feature-cost split on the private H1 store (LDG-3221, Cut 14 R5): real
# point-in-time data (membership universe, declared sessions, gaps,
# terminals). Measurement only; the classification below is not a
# production dispatch rule.
#
#   Rscript dev/bench/v0_2_3_lean_tuning_profile/features_h1.R --lib=<pinned library>
#     --state=<build-state.json> --reps=5 --out=<csv>
#
# Run only by the private input's authorized executor. Every output (the
# CSV, the console, error text) is aggregates only: counts, seconds and pass
# flags, never an instrument identifier, value or per-instrument record. The
# snapshot copy is deleted at the end; no profile dump is written.
#
# Features: the portable split's declared SMA5/SMA10 (ledgr_ind_ttr). On the
# pinned production path (ledgr_history_compute_feature_series) and its
# calculation bounds, an instrument is simple when it has one feature range
# (no lifetime knowledge restart), no terminal-asserted column, no
# policy-carried price input and exactly one usable input run of expected,
# finite closes inside the bounds. For the simple instruments it compares:
# - the pin's per-instrument path (treated inputs, the shared calculation and
#   the evidence exceptions; ledgr_history_feature_inputs/_calculate and
#   ledgr_feature_plane_exceptions), and
# - bare TTR::SMA over each run's closes,
# after checking that bare TTR reproduces the pin's full-run values and NA
# placement on every simple instrument (a mismatch fails the script). Full
# H1 pin time (all instruments, causality checks and evidence records) is
# reported separately. Work bare TTR omits: input treatment and the
# expected-session mask, warm-up and segment evidence, output-carry and
# reason planes, the causality probe, definition certification.

arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) { if (is.null(default)) stop("--", name, "= is required", call. = FALSE); return(default) }
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
source(file.path(repo, "dev/lean_core/load.R"))
lean <- lean_core_load(arg("lib"))
ns <- asNamespace("ledgr")
state <- jsonlite::read_json(arg("state"), simplifyVector = TRUE)
reps <- as.integer(arg("reps", "5"))
work <- file.path(tempdir(), "features_h1")
dir.create(work, showWarnings = FALSE)
on.exit(unlink(work, recursive = TRUE), add = TRUE)
quiet <- function(expr) tryCatch(expr, error = function(e) stop("features_h1: ", class(e)[[1L]], call. = FALSE))
store <- file.path(work, "h1.duckdb")
if (!file.copy(state$snapshot_path, store, overwrite = TRUE)) stop("could not copy the sealed snapshot", call. = FALSE)
snapshot <- quiet(ledgr::ledgr_snapshot_open(store, state$snapshot_id, verify = TRUE))
now <- function() proc.time()[["elapsed"]]
timed <- function(f) { f(); stats::median(vapply(seq_len(reps), function(r) { gc(); t0 <- now(); f(); now() - t0 }, 0)) }

features <- ledgr::ledgr_feature_map(
  fast = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
  slow = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L))
exp <- quiet(ledgr::ledgr_experiment(snapshot, function(ctx, params) ctx$hold(), features = features,
  universe = ledgr::ledgr_universe_members(state$universe_id), valuation_policy = ledgr::ledgr_valuation_stale(5L),
  cost_model = ledgr::ledgr_cost_zero(), opening = ledgr::ledgr_opening(cash = 1e6)))
substrate <- quiet(ns$ledgr_history_substrate_for_experiment(exp))
defs <- quiet(ns$ledgr_experiment_materialize_feature_result(exp, params = list(), feature_params = list())$features)
defs <- lapply(defs, function(d) if (inherits(d, "ledgr_indicator")) ns$ledgr_precompute_feature_def_from_indicator(d) else d)
names(defs) <- vapply(defs, function(d) d$id, "")
start <- ns$ledgr_history_calculation_start(substrate)
bounds <- ns$ledgr_history_feature_bounds(substrate, start, NULL)
n_inst <- length(substrate$instrument_ids)
cutoff_end <- substrate$axis[[bounds$to]]

# Full-H1 pin time and values.
full <- quiet(ns$ledgr_history_compute_feature_series(substrate, defs, calculation_start = start))
full_s <- timed(function() ns$ledgr_history_compute_feature_series(substrate, defs, calculation_start = start))

# Classification on the production bounds and inputs.
reason <- character(n_inst)
run_from <- run_to <- integer(n_inst)
for (i in seq_len(n_inst)) {
  ranges <- ns$ledgr_history_feature_ranges(substrate, i, bounds$from, bounds$to)
  if (length(ranges$start) != 1L) { reason[[i]] <- "several feature ranges"; next }
  inputs <- ns$ledgr_history_feature_inputs(substrate, i, bounds$to, cutoff_end)
  if (any(inputs$terminal_asserted)) { reason[[i]] <- "terminal"; next }
  if (any(inputs$carried$close)) { reason[[i]] <- "carried input"; next }
  available <- inputs$expected & is.finite(inputs$treated$close)
  runs <- ns$ledgr_history_feature_runs(available)
  if (length(runs$starts) == 0L) { reason[[i]] <- "no usable input"; next }
  if (length(runs$starts) > 1L) { reason[[i]] <- "several input runs"; next }
  run_from[[i]] <- runs$starts[[1L]]
  run_to[[i]] <- runs$ends[[1L]]
  reason[[i]] <- "simple"
}
simple <- which(reason == "simple")

# Exactness first: bare TTR over each simple instrument's whole input run
# (the pin may warm up before the calculation start) reproduces the pin's
# values and NA placement inside the bounds; outside them the pin has none.
keep_cols <- seq.int(bounds$from, bounds$to)
bare_row <- function(i, n) {
  v <- rep(NA_real_, ncol(full[[1L]]))
  x <- as.numeric(substrate$bars$close[i, run_from[[i]]:run_to[[i]]])
  if (length(x) >= n) v[run_from[[i]]:run_to[[i]]] <- TTR::SMA(x, n = n)
  v
}
mismatch <- 0L
for (i in simple) {
  ok <- TRUE
  for (f in list(list("fast", 5L), list("slow", 10L))) {
    pin <- as.numeric(full[[f[[1L]]]][i, ])
    ok <- ok && identical(bare_row(i, f[[2L]])[keep_cols], pin[keep_cols]) && all(is.na(pin[-keep_cols]))
  }
  if (!ok) mismatch <- mismatch + 1L
}
if (mismatch > 0L) stop(sprintf("features_h1: bare TTR differs from the pin on %d of %d simple instruments", mismatch,
                                length(simple)), call. = FALSE)

# The same simple rows and interval, both arms by the same method.
certified <- lapply(defs, ns$ledgr_feature_certify)
output_carry <- substrate$history_policy$output_carry
pin_simple <- function() for (i in simple) {
  inputs <- ns$ledgr_history_feature_inputs(substrate, i, bounds$to, cutoff_end)
  keep <- seq.int(bounds$from, bounds$to)
  cache <- new.env(hash = TRUE, parent = emptyenv())
  for (cert in certified) {
    calculated <- ns$ledgr_history_feature_calculate(cert, inputs, bounds$from, output_carry, cache)
    ns$ledgr_feature_plane_exceptions(cert, inputs, calculated, bounds$from, keep)
  }
}
# The same calculation bare_row() checked: each SMA under its own length guard.
bare_simple <- function() for (i in simple) {
  x <- as.numeric(substrate$bars$close[i, run_from[[i]]:run_to[[i]]])
  if (length(x) >= 5L) TTR::SMA(x, n = 5L)
  if (length(x) >= 10L) TTR::SMA(x, n = 10L)
}
run_length <- run_to[simple] - run_from[simple] + 1L
pin_simple_s <- timed(pin_simple)
bare_simple_s <- timed(bare_simple)
ledgr::ledgr_snapshot_close(snapshot)

tab <- table(factor(reason, levels = c("simple", "several feature ranges", "terminal", "carried input",
                                       "no usable input", "several input runs")))
out <- data.frame(
  instruments = n_inst, sessions = length(substrate$axis), calc_from = bounds$from, calc_to = bounds$to,
  simple = length(simple), simple_share = round(length(simple) / n_inst, 3),
  excluded_several_ranges = tab[["several feature ranges"]], excluded_terminal = tab[["terminal"]],
  excluded_carried_input = tab[["carried input"]], excluded_no_usable_input = tab[["no usable input"]],
  excluded_several_runs = tab[["several input runs"]],
  simple_runs_under_5 = sum(run_length < 5L), simple_runs_5_to_9 = sum(run_length >= 5L & run_length < 10L),
  values_identical_on_simple = TRUE, reps = reps,
  full_h1_pin_s = round(full_s, 3), simple_pin_path_s = round(pin_simple_s, 3), simple_bare_ttr_s = round(bare_simple_s, 3),
  simple_pin_us_per_instrument = round(1e6 * pin_simple_s / max(1L, length(simple))),
  simple_bare_us_per_instrument = round(1e6 * bare_simple_s / max(1L, length(simple))),
  stringsAsFactors = FALSE)
utils::write.csv(out, arg("out"), row.names = FALSE)
print(t(out))
