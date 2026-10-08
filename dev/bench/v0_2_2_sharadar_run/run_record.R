# LDG-2976 parent: runs each stage of the 1998-2026 Sharadar run in its own
# R process, sampling the child's resident memory, and writes stages.csv.
#
#   Rscript dev/bench/v0_2_2_sharadar_run/run_record.R <ledgr_repo> <adapter_repo> <work_dir> <out_dir> [stage ...]
#
# Aggregate outputs only. <work_dir> holds the snapshot and must be under the
# private data root.
args <- commandArgs(trailingOnly = TRUE)
ledgr_repo <- normalizePath(args[[1L]], winslash = "/")
adapter_repo <- normalizePath(args[[2L]], winslash = "/")
work_dir <- args[[3L]]
out_dir <- args[[4L]]
stages <- if (length(args) > 4L) args[-(1:4)] else
  c("build", "census", "momentum", "equal_weight", "sweep", "walk_forward")
root <- normalizePath(Sys.getenv("SHARADAR_DATA_ROOT", "E:/ledgr-data/sharadar"), winslash = "/")
if (!startsWith(normalizePath(work_dir, winslash = "/", mustWork = FALSE), root)) {
  stop("work_dir must be under the private data root ", root, call. = FALSE)
}
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(work_dir, recursive = TRUE, showWarnings = FALSE)
rscript <- file.path(R.home("bin"), "Rscript")
script <- file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]))), "stage.R")
rows <- list()
for (stage in stages) {
  t0 <- Sys.time()
  log_file <- file.path(work_dir, paste0(stage, ".log"))
  p <- processx::process$new(rscript, c(script, stage, ledgr_repo, adapter_repo, work_dir, out_dir),
                             stdout = log_file, stderr = "2>&1")
  peak <- 0
  while (p$is_alive()) {
    rss <- tryCatch(ps::ps_memory_info(ps::ps_handle(p$get_pid()))[["rss"]], error = function(e) NA_real_)
    if (is.finite(rss)) peak <- max(peak, rss)
    Sys.sleep(0.5)
  }
  rows[[length(rows) + 1L]] <- data.frame(
    stage = stage, exit_status = p$get_exit_status(),
    elapsed_s = round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1),
    peak_rss_mib = round(peak / 2^20), stringsAsFactors = FALSE)
  cat(sprintf("%-13s exit %d  %7.1f s  peak %5d MiB\n", stage, p$get_exit_status(),
              rows[[length(rows)]]$elapsed_s, rows[[length(rows)]]$peak_rss_mib))
  utils::write.csv(do.call(rbind, rows), file.path(out_dir, "stages.csv"), row.names = FALSE)
}
