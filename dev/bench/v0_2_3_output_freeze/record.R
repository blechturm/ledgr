# A0 recorder: runs every workload through both output handlers on the current
# tree and writes canonical records plus manifest.csv.
#
# Usage: Rscript record.R [--out=<dir>] [--pkg=<package root>]
#   --out defaults to records/ next to this script.

local({
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  here <- if (length(file_arg)) dirname(sub("^--file=", "", file_arg[[1L]])) else getwd()
  source(file.path(here, "lib.R"))
})
a0_load()
here <- a0_script_dir()
out_dir <- a0_arg("out", file.path(here, "records"))
work_dir <- file.path(tempdir(), "a0_record_work")

if (dir.exists(out_dir)) {
  old <- list.files(out_dir, recursive = TRUE, full.names = TRUE)
  invisible(file.remove(old))
}
results <- a0_run_all(work_dir)
manifest <- a0_write_records(results$tables, out_dir)
total <- sum(as.numeric(manifest$bytes))
cat(sprintf("a0 record: %d files, %.1f KB in %s\n", nrow(manifest), total / 1024, out_dir))
if (total > 10 * 1024^2) {
  cat("STOP: records exceed 10 MB\n")
  quit(status = 2L)
}
