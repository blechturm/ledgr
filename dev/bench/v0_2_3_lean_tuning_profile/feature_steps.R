# Feature-path step split, input to the feature-engine RFC seed (macro plan,
# order after Cut 20, item b). feature_split.csv gives one "machinery"
# number (the pin's feature series minus bare TTR); this splits the pin's
# run and sweep feature paths into named steps by Rprof sampling.
#
# Run path, as ledgr_run() calls it (R/backtest-runner.R:664-680):
#   ledgr_history_compute_feature_series(), then
#   ledgr_projection_from_feature_matrix().
# Sweep path, as ledgr_sweep() calls it (R/sweep.R:276-291):
#   ledgr_history_precompute_payload() (compute, then the per-instrument
#   split), then ledgr_projection_from_payload() (the rebuild).
# Features: run, SMA 5 and 10 (the published crossover); sweep, the union
# of sweep_map.R's grid, SMA 3, 5, 8, 12, 20 and 40.
#
# A sample goes to the first step, in the order of `steps` below, whose
# function is on its stack, so an outer step (the causality probe,
# certification) owns the work it repeats. Seconds = the step's sample
# share x the median wall time of the path.
#
#   Rscript dev/bench/v0_2_3_lean_tuning_profile/feature_steps.R --lib=<pinned library>
#     --shapes=crossover_10x7200,crossover_500x1260,crossover_1166x252 --reps=3 --out=<csv>

arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) { if (is.null(default)) stop("--", name, "= is required", call. = FALSE); return(default) }
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
.libPaths(c(arg("lib"), .libPaths()))
library(ledgr)
ns <- asNamespace("ledgr")
source(file.path(repo, "dev/spikes/r_floor/fixture.R"))
shapes <- strsplit(arg("shapes", "crossover_10x7200,crossover_500x1260,crossover_1166x252"), ",")[[1L]]
reps <- as.integer(arg("reps", "3"))
work <- file.path(tempdir(), "feature_steps")
dir.create(work, showWarnings = FALSE)

steps <- c(
  "causality probe" = "ledgr_history_feature_causality",
  "certification" = "ledgr_feature_certify",
  "TTR raw call" = "ledgr_ttr_raw_call",
  "segment frame" = "ledgr_history_feature_frame",
  "segment other" = "ledgr_history_feature_segment",
  "calculate other (runs, carry)" = "ledgr_history_feature_calculate",
  "input treatment" = "ledgr_history_feature_inputs",
  "ranges and bounds" = "ledgr_history_feature_ranges|ledgr_history_feature_bounds",
  "plane exceptions" = "ledgr_feature_plane_exceptions",
  "plane records" = "ledgr_feature_plane_records",
  # residuals before the wrappers that contain them (seed review F1): the
  # compute residual before the payload split, the runtime projection's own
  # work before the sweep's rebuild
  "compute other" = "ledgr_history_compute_feature_series",
  "projection index planes" = "ledgr_projection_index_planes",
  "projection pulse names" = "ledgr_projection_pulse_names",
  "projection axis format (direct)" = "format.POSIXct",
  "projection other" = "ledgr_projection_from_feature_matrix|ledgr_runtime_projection",
  "projection rebuild (sweep)" = "ledgr_projection_from_payload",
  "payload split (sweep)" = "ledgr_history_precompute_payload")

profile_path <- function(f) {
  f()
  walls <- numeric(reps)
  prof <- file.path(work, "prof.out")
  utils::Rprof(prof, interval = 0.002)
  for (r in seq_len(reps)) { t0 <- proc.time()[["elapsed"]]; f(); walls[[r]] <- proc.time()[["elapsed"]] - t0 }
  utils::Rprof(NULL)
  lines <- readLines(prof)[-1L]
  lines <- lines[!grepl("^sample.interval", lines)]
  cat_of <- vapply(lines, function(s) {
    # a call made here through ns$ is recorded as "ns$<name>"
    for (k in names(steps)) if (grepl(paste0("\"(ns\\$)?(", steps[[k]], ")\""), s)) return(k)
    "other"
  }, "", USE.NAMES = FALSE)
  share <- table(factor(cat_of, levels = c(names(steps), "other"))) / length(cat_of)
  list(wall = stats::median(walls), share = share, samples = length(cat_of))
}

sma <- function(n) ledgr::ledgr_ind_ttr("SMA", input = "close", id = paste0("sma_", n), n = as.integer(n))
defs_for <- function(exp) {
  d <- ns$ledgr_experiment_materialize_feature_result(exp, params = list(), feature_params = list())$features
  d <- lapply(d, function(x) if (inherits(x, "ledgr_indicator")) ns$ledgr_precompute_feature_def_from_indicator(x) else x)
  d
}

rows <- list()
for (shape in shapes) {
  dims <- as.integer(strsplit(sub("^crossover_", "", shape), "x")[[1L]])
  db <- file.path(work, paste0(shape, ".duckdb"))
  if (file.exists(db)) unlink(db)
  ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(r_floor_fixture(dims[[1L]], dims[[2L]])$bars,
    db_path = db, snapshot_id = "p", price_basis = "split_adjusted"))
  snapshot <- ledgr::ledgr_snapshot_open(db, "p", verify = TRUE)
  mk <- function(ns_) ledgr::ledgr_experiment(snapshot, function(ctx, params) ctx$hold(),
    features = do.call(ledgr::ledgr_feature_map, stats::setNames(lapply(ns_, sma), paste0("sma_", ns_))),
    opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero())
  exp_run <- mk(c(5, 10))
  exp_sweep <- mk(c(3, 5, 8, 12, 20, 40))
  substrate <- ns$ledgr_history_substrate_for_experiment(exp_run)
  start <- ns$ledgr_history_calculation_start(substrate)
  axis <- substrate$axis
  ids <- substrate$instrument_ids
  run_defs <- defs_for(exp_run)
  names(run_defs) <- vapply(run_defs, function(d) d$id, "")
  sweep_defs <- defs_for(exp_sweep)
  names(sweep_defs) <- vapply(sweep_defs, ns$ledgr_feature_def_fingerprint, "")
  version <- ns$ledgr_feature_engine_version()

  run_path <- function() {
    m <- ns$ledgr_history_compute_feature_series(substrate, run_defs, calculation_start = start)
    ns$ledgr_projection_from_feature_matrix(m, universe = ids, pulses_posix = axis,
      feature_engine_version = version, alias_index = NULL)
  }
  sweep_path <- function() {
    p <- ns$ledgr_history_precompute_payload(sweep_defs, substrate, calculation_start = start)
    ns$ledgr_projection_from_payload(payload = p, universe = ids, pulses_posix = axis,
      feature_engine_version = version, alias_index = NULL)
  }
  t0 <- proc.time()[["elapsed"]]; for (r in seq_len(reps)) ns$ledgr_feature_engine_version()
  version_s <- (proc.time()[["elapsed"]] - t0) / reps
  close <- t(substrate$bars$close)
  t0 <- proc.time()[["elapsed"]]
  for (r in seq_len(reps)) for (n in c(3, 5, 8, 12, 20, 40)) apply(close, 2L, TTR::SMA, n = n)
  bare_sweep_s <- (proc.time()[["elapsed"]] - t0) / reps
  for (path in c("run", "sweep")) {
    p <- profile_path(if (path == "run") run_path else sweep_path)
    rows[[paste(shape, path)]] <- data.frame(shape = shape, path = path, defs = if (path == "run") 2L else 6L,
      wall_s = round(p$wall, 3), samples = p$samples, step = names(p$share),
      share = round(as.numeric(p$share), 3), seconds = round(as.numeric(p$share) * p$wall, 3),
      engine_version_s = round(version_s, 3), bare_ttr_6_defs_s = round(bare_sweep_s, 3),
      stringsAsFactors = FALSE)
    cat(shape, path, "wall", round(p$wall, 2), "s\n")
  }
  ledgr::ledgr_snapshot_close(snapshot)
}
out <- do.call(rbind, rows)
rownames(out) <- NULL
utils::write.csv(out, arg("out"), row.names = FALSE)
