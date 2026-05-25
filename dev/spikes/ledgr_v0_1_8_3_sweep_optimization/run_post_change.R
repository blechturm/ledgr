#!/usr/bin/env Rscript

file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_path <- if (length(file_arg)) sub("^--file=", "", file_arg[[1]]) else "dev/spikes/ledgr_v0_1_8_3_sweep_optimization/run_post_change.R"
source(file.path(dirname(normalizePath(script_path, mustWork = FALSE)), "common.R"))

main <- function() {
  args <- parse_cli()
  out_dir <- args[["out-dir"]] %||% file.path("inst", "design", "spikes", "ledgr_v0_1_8_3_sweep_optimization")
  data_dir <- file.path(out_dir, "data")
  workloads <- args[["workloads"]] %||% NULL
  reps <- args[["reps"]] %||% NULL

  results <- run_measurement(
    label = "post_change",
    out_dir = out_dir,
    workload_names = workloads,
    reps_override = reps
  )
  env <- environment_info("post_change")
  versions <- package_versions()

  profile <- NULL
  if (!identical(args[["profile"]], "false")) {
    message("Running reference Rprof profile...")
    profile <- profile_reference_workload("post_change", out_dir)
    write_csv(profile, file.path(data_dir, "post_change_profile.csv"))
  }

  write_csv(results, file.path(data_dir, "post_change_results.csv"))
  write_csv(env, file.path(data_dir, "post_change_environment.csv"))
  write_csv(versions, file.path(data_dir, "post_change_package_versions.csv"))

  notes <- c(
    "- Post-change measurements must use the same workload definitions as the baseline.",
    "- Compare this report with `baseline_report.md` before making performance claims.",
    "- If the scoped optimization does not improve the reference workload, document why it still ships or defer/revert the change."
  )
  write_measurement_report(
    label = "Post-Change",
    report_path = file.path(out_dir, "post_change_report.md"),
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
