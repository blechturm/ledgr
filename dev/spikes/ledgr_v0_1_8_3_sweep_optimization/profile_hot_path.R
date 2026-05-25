#!/usr/bin/env Rscript

file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_path <- if (length(file_arg)) sub("^--file=", "", file_arg[[1]]) else "dev/spikes/ledgr_v0_1_8_3_sweep_optimization/profile_hot_path.R"
source(file.path(dirname(normalizePath(script_path, mustWork = FALSE)), "common.R"))

main <- function() {
  args <- parse_cli()
  label <- args[["label"]] %||% "manual_profile"
  out_dir <- args[["out-dir"]] %||% file.path("inst", "design", "spikes", "ledgr_v0_1_8_3_sweep_optimization")
  data_dir <- file.path(out_dir, "data")

  profile <- profile_reference_workload(label, out_dir)
  write_csv(profile, file.path(data_dir, paste0(label, "_profile.csv")))
  print(utils::head(profile, 20L), row.names = FALSE)
  invisible(profile)
}

if (identical(environment(), globalenv())) {
  main()
}
