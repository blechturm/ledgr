#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
out <- if (length(args) >= 1L) args[[1L]] else tempfile(fileext = ".csv")

.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
arm_lib <- Sys.getenv("LEDGR_ARM_LIB", unset = "")
if (nzchar(arm_lib)) {
  .libPaths(c(arm_lib, .libPaths()))
  library(ledgr)
} else {
  pkgload::load_all(".", quiet = TRUE)
}
source(
  file.path("dev", "bench", "timing", "protocols", "ws4a-timing-1", "workloads.R"),
  local = TRUE
)

profile_one <- function(producer) {
  work_dir <- tempfile(paste0("ws4b-phase-", producer, "-"))
  dir.create(work_dir, recursive = TRUE)
  on.exit(unlink(work_dir, recursive = TRUE, force = TRUE), add = TRUE)

  fixture <- ws4a_fixture(producer, "nofill", work_dir)
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)

  run_id <- paste0("ws4b-phase-", producer)
  started <- proc.time()[["elapsed"]]
  bt <- suppressWarnings(ledgr_run(
    fixture$exp,
    params = ws4a_params("nofill"),
    run_id = run_id
  ))
  elapsed <- proc.time()[["elapsed"]] - started
  on.exit(close(bt), add = TRUE)

  bench <- as.data.frame(ledgr_backtest_bench(bt))
  bench$producer <- producer
  bench$source <- if (nzchar(arm_lib)) "installed_arm" else "candidate_worktree"
  bench$elapsed_sec <- elapsed
  bench[, c("source", "producer", "component", "mean", "median", "p99", "elapsed_sec")]
}

result <- rbind(profile_one("dense"), profile_one("availability"))
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(result, out, row.names = FALSE, na = "")
cat(normalizePath(out, winslash = "/", mustWork = TRUE), "\n")
