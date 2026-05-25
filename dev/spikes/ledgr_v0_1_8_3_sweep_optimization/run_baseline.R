#!/usr/bin/env Rscript

file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_path <- if (length(file_arg)) sub("^--file=", "", file_arg[[1]]) else "dev/spikes/ledgr_v0_1_8_3_sweep_optimization/run_baseline.R"
source(file.path(dirname(normalizePath(script_path, mustWork = FALSE)), "common.R"))

main <- function() {
  args <- parse_cli()
  out_dir <- args[["out-dir"]] %||% file.path("inst", "design", "spikes", "ledgr_v0_1_8_3_sweep_optimization")
  data_dir <- file.path(out_dir, "data")
  workloads <- args[["workloads"]] %||% NULL
  reps <- args[["reps"]] %||% NULL

  results <- run_measurement(
    label = "baseline",
    out_dir = out_dir,
    workload_names = workloads,
    reps_override = reps
  )
  env <- environment_info("baseline")
  versions <- package_versions()

  profile <- NULL
  if (!identical(args[["profile"]], "false")) {
    message("Running reference Rprof profile...")
    profile <- profile_reference_workload("baseline", out_dir)
    write_csv(profile, file.path(data_dir, "baseline_profile.csv"))
  }

  write_csv(results, file.path(data_dir, "baseline_results.csv"))
  write_csv(env, file.path(data_dir, "baseline_environment.csv"))
  write_csv(versions, file.path(data_dir, "baseline_package_versions.csv"))

  notes <- c(
    "- Baseline is measured after the v0.1.8.2 release on the v0.1.8.3 planning branch.",
    "- No v0.1.8.3 runtime optimization has landed before this baseline.",
    "- The `reference_50_candidates` workload preserves the LDG-2108A/LDG-2108B benchmark lineage.",
    "- The `wider_feature_payload` workload is a scaled local variant intended to expose wider feature-payload behavior without adopting the full parallelism-spike scale."
  )
  write_measurement_report(
    label = "Baseline",
    report_path = file.path(out_dir, "baseline_report.md"),
    results = results,
    env = env,
    versions = versions,
    profile = profile,
    notes = notes
  )

  invisible(results)
}

if (identical(environment(), globalenv())) {
  main()
}
