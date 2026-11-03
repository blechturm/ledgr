# Record the current tree through the successor A0 harness.
# Usage: Rscript record.R --pkg=<package-root> --out=<record-dir>

file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
here <- dirname(sub("^--file=", "", file_arg[[1L]]))
source(file.path(here, "lib.R"))
successor_load()
out_dir <- a0_arg("out", file.path(here, "records", "candidate"))
work_dir <- file.path(tempdir(), "a0_successor_work")
if (dir.exists(out_dir)) {
  old <- list.files(out_dir, recursive = TRUE, full.names = TRUE)
  invisible(file.remove(old))
}
results <- a0_run_all(work_dir)
manifest <- a0_write_records(results$tables, out_dir)
cat(sprintf("successor A0 record: %d files in %s\n", nrow(manifest), out_dir))
