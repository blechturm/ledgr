#!/usr/bin/env Rscript

file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_path <- if (length(file_arg)) sub("^--file=", "", file_arg[[1]]) else "dev/spikes/ledgr_v0_1_8_3_sweep_optimization/summarize_results.R"
source(file.path(dirname(normalizePath(script_path, mustWork = FALSE)), "common.R"))

read_optional_csv <- function(path) {
  if (file.exists(path)) utils::read.csv(path, stringsAsFactors = FALSE) else NULL
}

main <- function() {
  args <- parse_cli()
  out_dir <- args[["out-dir"]] %||% file.path("inst", "design", "spikes", "ledgr_v0_1_8_3_sweep_optimization")
  data_dir <- file.path(out_dir, "data")

  baseline <- read_optional_csv(file.path(data_dir, "baseline_results.csv"))
  post <- read_optional_csv(file.path(data_dir, "post_change_results.csv"))
  baseline_env <- read_optional_csv(file.path(data_dir, "baseline_environment.csv"))
  post_env <- read_optional_csv(file.path(data_dir, "post_change_environment.csv"))

  lines <- c(
    "# v0.1.8.3 Sweep Optimization Summary",
    "",
    "## Available Reports",
    "",
    "- `baseline_report.md` records the pre-optimization timing baseline.",
    "- `post_change_report.md` records the same workloads after scoped optimization.",
    "- `residual_hot_path_report.md` records remaining bottlenecks and the next optimization recommendation.",
    "",
    "## Baseline Results",
    ""
  )
  if (is.null(baseline)) {
    lines <- c(lines, "_No baseline results found yet._")
  } else {
    lines <- c(lines, markdown_table(baseline[, c("scenario", "path", "reps", "median_sec", "mean_sec")]))
  }
  lines <- c(lines, "", "## Post-Change Results", "")
  if (is.null(post)) {
    lines <- c(lines, "_No post-change results found yet._")
  } else {
    lines <- c(lines, markdown_table(post[, c("scenario", "path", "reps", "median_sec", "mean_sec")]))
  }
  if (!is.null(baseline_env) || !is.null(post_env)) {
    lines <- c(lines, "", "## Environment SHAs", "")
    env_rows <- rbind(
      if (!is.null(baseline_env)) baseline_env[, c("label", "git_head_short", "git_v0_1_8_2_tag", "r_version", "platform")] else NULL,
      if (!is.null(post_env)) post_env[, c("label", "git_head_short", "git_v0_1_8_2_tag", "r_version", "platform")] else NULL
    )
    lines <- c(lines, markdown_table(env_rows))
  }
  writeLines(lines, file.path(out_dir, "summary_report.md"), useBytes = TRUE)
}

if (identical(environment(), globalenv())) {
  main()
}
