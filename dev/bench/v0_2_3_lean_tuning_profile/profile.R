# Measurement before the lean tuning cut (after LDG-3219): where a whole
# committed run on the lean loop spends its time. Each shape builds its
# snapshot outside the profile, runs once to warm up, then runs `reps` times
# under Rprof with the lean loop installed (lean_loop_run, debug off). Every
# sample is assigned to the first phase marker found walking its stack from
# the leaf, so the most specific phase wins.
#
#   Rscript dev/bench/v0_2_3_lean_tuning_profile/profile.R --lib=<pinned library>
#     --shape=crossover_10x7200 --reps=3 --out=<dir>
#
# Writes <out>/<shape>_phases.csv (whole run) and <out>/<shape>_loop.csv
# (samples inside the pulse loop only), with seconds per run and per pulse.
# Rprof samples at the platform clock (about 10-16 ms here), so shares are
# estimates; the wall times beside them are measured.

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) { if (is.null(default)) stop("--", name, "= is required", call. = FALSE); return(default) }
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
source(file.path(repo, "dev/lean_core/load.R"))
lean <- lean_core_load(arg("lib"))
# Byte-compiled as the timing harness and the installed pin are, so the
# profile does not count JIT compilation of the loop closures.
for (f in ls(lean, all.names = TRUE)) if (is.function(lean[[f]])) assign(f, compiler::cmpfun(lean[[f]]), envir = lean)
ns <- asNamespace("ledgr")
source(file.path(repo, "dev/spikes/r_floor/fixture.R"))
shape <- arg("shape")
reps <- as.integer(arg("reps", "3"))
out <- arg("out")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
dims <- as.integer(strsplit(sub("^crossover_", "", shape), "x")[[1L]])

work <- file.path(tempdir(), "lean_tuning_profile")
dir.create(work, showWarnings = FALSE)
db <- file.path(work, paste0(shape, ".duckdb"))
if (file.exists(db)) unlink(db)
ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(r_floor_fixture(dims[[1L]], dims[[2L]])$bars,
  db_path = db, snapshot_id = "p", price_basis = "split_adjusted"))
snapshot <- ledgr::ledgr_snapshot_open(db, "p", verify = TRUE)
strategy <- r_floor_transition
environment(strategy) <- ns
exp <- ledgr::ledgr_experiment(snapshot, strategy,
  features = ledgr::ledgr_feature_map(
    fast = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
    slow = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
  opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero(),
  risk_chain = ledgr::ledgr_risk_none(), asset_state = list(above = FALSE, usable = FALSE))

run_once <- function(id) lean$lean_loop_run(function() {
  t0 <- proc.time()[["elapsed"]]
  close(suppressWarnings(ledgr::ledgr_run(exp, run_id = id, seed = 20260530L)))
  proc.time()[["elapsed"]] - t0
})
warm <- run_once("warm")
if (attr(warm, "lean")$lean_folds != 1L) stop("the lean loop did not run")

prof <- file.path(out, paste0(shape, ".rprof"))
Rprof(prof, interval = 0.005)
walls <- numeric(reps); loops <- numeric(reps); pubs <- numeric(reps)
for (r in seq_len(reps)) {
  walls[[r]] <- run_once(paste0("p", r))$value
  loops[[r]] <- lean$lean_loop_last_times$pulses
  pubs[[r]] <- lean$lean_loop_last_times$publish
}
Rprof(NULL)
ledgr::ledgr_snapshot_close(snapshot)

# Phase markers, most specific first within each nesting; the first marker
# met walking a stack from its leaf names the sample's phase.
phases <- c(
  ledgr_call_strategy_fn = "loop: strategy call",
  lean_lot_fill = "loop: P4 FIFO",
  ledgr_position_facts_apply = "loop: P4 position facts",
  lean_plan_pulse = "loop: P3 planner",
  lean_exec_view = "loop: P3 planner",
  lean_context = "loop: P2 context",
  lean_state_patch = "loop: P5 state",
  ledgr_strategy_state_view = "loop: P2 context",
  ledgr_fold_reconciliation_check = "loop: P5 reconciliation",
  lean_gross = "loop: P5 reconciliation",
  lean_loop_expand = "fold: expand records",
  lean_loop_publish = "fold: terminal write",
  run_loop = "loop: other",
  ledgr_fold_envelope = "fold: setup and commit",
  ledgr_history_compute_feature_series = "pre: features",
  ledgr_projection_from_feature_matrix = "pre: feature projection",
  ledgr_history_substrate_bind_features = "pre: feature projection",
  ledgr_history_substrate_for_experiment = "pre: bars substrate",
  ledgr_history_substrate = "pre: bars substrate",
  ledgr_availability_provider_from_substrate = "pre: provider",
  ledgr_experiment_materialize_feature_result = "pre: feature declarations",
  ledgr_strategy_preflight = "pre: strategy preflight",
  ledgr_run_snapshot_guard = "pre: snapshot guard",
  ledgr_run_registration = "pre: store and registration",
  ledgr_run_registration_provenance = "pre: store and registration",
  ledgr_validate_schema_once = "pre: store and registration",
  ledgr_store_open = "pre: store and registration",
  ledgr_config = "pre: config",
  ledgr_run_finalize = "post: finalise",
  ledgr_finalize_fold_telemetry = "post: telemetry",
  new_ledgr_backtest = "post: result object"
)
lines <- readLines(prof)
lines <- lines[!grepl("^sample.interval|^#", lines)]
stacks <- lapply(strsplit(lines, " ", fixed = TRUE), function(s) gsub('"', "", s))
# Two frames are named `fn`: the strategy, called by ledgr_call_strategy_fn,
# and the lean run_loop, called by the transaction through
# withCallingHandlers().
phase_of <- function(s) {
  for (j in seq_along(s)) {
    f <- s[[j]]
    nxt <- if (j < length(s)) s[[j + 1L]] else ""
    if (identical(f, "fn") && identical(nxt, "ledgr_call_strategy_fn")) return(phases[["ledgr_call_strategy_fn"]])
    if (identical(f, "fn") && identical(nxt, "withCallingHandlers") && "ledgr_fold_envelope" %in% s) {
      return(phases[["run_loop"]])
    }
    if (f %in% names(phases)) return(phases[[f]])
  }
  if ("ledgr_run" %in% s) "run: other" else "outside the run"
}
ph <- vapply(stacks, phase_of, character(1L))
ph <- ph[ph != "outside the run"]
tab <- sort(table(ph), decreasing = TRUE)
wall <- stats::median(walls)
frame <- data.frame(shape = shape, phase = names(tab), samples = as.integer(tab),
  share = round(as.numeric(tab) / sum(tab), 3), stringsAsFactors = FALSE)
frame$seconds_per_run <- round(frame$share * wall, 3)
frame$us_per_pulse <- round(1e6 * frame$seconds_per_run / dims[[2L]])
utils::write.csv(frame, file.path(out, paste0(shape, "_phases.csv")), row.names = FALSE)
cat(sprintf("%s: whole run median %.2f s (%s), pulse loop %.2f s (%.0f us/pulse), terminal write %.2f s\n",
  shape, wall, paste(sprintf("%.2f", walls), collapse = ", "), stats::median(loops),
  1e6 * stats::median(loops) / dims[[2L]], stats::median(pubs)))
print(frame[, c("phase", "samples", "share", "seconds_per_run", "us_per_pulse")], row.names = FALSE)
