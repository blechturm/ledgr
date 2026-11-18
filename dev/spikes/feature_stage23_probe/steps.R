# Feature-path step table on the cleaned code (CHARTER.md, prerequisite).
# Same fixture, paths, definitions and classifier as Cut 22's measuring step
# (dev/spikes/feature_stage1_probe/steps_clean.R), with the per-instrument
# calculation split into the parts a stage-3 direct path would replace.
#
# Run path, as ledgr_run() calls it: ledgr_history_compute_feature_series(),
#   then ledgr_projection_from_feature_matrix().
# Sweep path, as ledgr_sweep() calls it: ledgr_history_precompute_payload(),
#   then ledgr_projection_from_payload().
# Run: TTR SMA 5 and 10. Sweep: TTR SMA 3, 5, 8, 12, 20 and 40.
# A sample goes to the first step, in the order below, whose function is on
# its stack. Seconds = the step's sample share x the unprofiled median wall.
#
#   Rscript steps.R --lib=<installed ledgr> --reps=7 --out=results/steps.csv
#     [--shapes=crossover_10x7200,crossover_500x1260,crossover_1166x252]
source(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                       winslash = "/")), "common.R"))
shapes <- strsplit(arg("shapes", "crossover_10x7200,crossover_500x1260,crossover_1166x252"), ",")[[1L]]
reps <- as.integer(arg("reps", "7"))

steps <- c(
  "causality probe" = "ledgr_history_feature_causality",
  "certification" = "ledgr_feature_certify",
  "TTR raw call" = "ledgr_ttr_raw_call",
  "segment frame" = "ledgr_history_feature_frame|ledgr_history_feature_window",
  "segment other" = "ledgr_history_feature_segment",
  "required-field admission" = "ledgr_history_required_field_admission",
  "runs and terminal breaks" = "ledgr_history_feature_runs|ledgr_history_feature_terminal_breaks",
  "output carry" = "ledgr_history_output_carry",
  "calculate other" = "ledgr_history_feature_calculate",
  "input carry" = "ledgr_history_input_carry_calculation|ledgr_history_input_carry",
  "expected and terminal planes" = "ledgr_history_substrate_expected_at|ledgr_history_substrate_terminal_planes",
  "input treatment other" = "ledgr_history_feature_inputs",
  "ranges and bounds" = "ledgr_history_feature_ranges|ledgr_history_feature_bounds",
  "plane exceptions" = "ledgr_feature_plane_exceptions",
  "plane records" = "ledgr_feature_plane_records",
  "compute other" = "ledgr_history_compute_feature_series",
  "projection index planes" = "ledgr_projection_index_planes",
  "projection pulse names" = "ledgr_projection_pulse_names",
  "projection axis format (direct)" = "format.POSIXct",
  "projection other" = "ledgr_projection_from_feature_matrix|ledgr_runtime_projection",
  "projection rebuild (sweep)" = "ledgr_projection_from_payload",
  "payload split (sweep)" = "ledgr_history_precompute_payload")

profile_path <- function(f) {
  plain <- time_median(f, reps)
  prof <- file.path(work, "prof.out")
  utils::Rprof(prof, interval = 0.002)
  for (r in seq_len(reps)) f()
  utils::Rprof(NULL)
  lines <- readLines(prof)[-1L]
  lines <- lines[!grepl("^sample.interval", lines)]
  cat_of <- vapply(lines, function(s) {
    for (k in names(steps)) if (grepl(paste0("\"(ns\\$)?(", steps[[k]], ")\""), s)) return(k)
    "other"
  }, "", USE.NAMES = FALSE)
  list(plain = plain, share = table(factor(cat_of, levels = c(names(steps), "other"))) / length(cat_of),
       samples = length(cat_of))
}

rows <- list()
for (shape in shapes) {
  snapshot <- crossover_snapshot(shape)
  run_exp <- crossover_exp(snapshot, c(5, 10)); sweep_exp <- crossover_exp(snapshot, c(3, 5, 8, 12, 20, 40))
  substrate <- ns$ledgr_history_substrate_for_experiment(run_exp)
  start <- ns$ledgr_history_calculation_start(substrate)
  axis <- substrate$axis; ids <- substrate$instrument_ids
  run_defs <- defs_for(run_exp)
  sweep_defs <- defs_for(sweep_exp)
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
  version_s <- time_median(function() ns$ledgr_feature_engine_version(), reps)
  close <- t(substrate$bars$close)
  bare <- function(widths) time_median(function() for (n in widths) apply(close, 2L, TTR::SMA, n = n), reps)
  bare_run <- bare(c(5, 10)); bare_sweep <- bare(c(3, 5, 8, 12, 20, 40))
  for (path in c("run", "sweep")) {
    p <- profile_path(if (path == "run") run_path else sweep_path)
    rows[[paste(shape, path)]] <- data.frame(shape = shape, path = path, defs = if (path == "run") 2L else 6L,
      plain_wall_s = round(p$plain, 3), samples = p$samples, step = names(p$share),
      share = round(as.numeric(p$share), 3), seconds = round(as.numeric(p$share) * p$plain, 3),
      engine_version_s = round(version_s, 3), bare_ttr_s = round(if (path == "run") bare_run else bare_sweep, 3),
      stringsAsFactors = FALSE)
    cat(shape, path, "plain", round(p$plain, 3), "s\n")
  }
  ledgr::ledgr_snapshot_close(snapshot)
}
out <- do.call(rbind, rows); rownames(out) <- NULL
utils::write.csv(out, arg("out"), row.names = FALSE)
utils::write.csv(provenance(), sub("\\.csv$", "_provenance.csv", arg("out")), row.names = FALSE)
