#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[[1L]]), winslash = "/")
source(file.path(dirname(script_path), "common.R"), local = globalenv())
opt <- e0_parse_args(commandArgs(trailingOnly = TRUE), list(
  `package-root` = ".", against = file.path(dirname(script_path), "evidence", "smoke"),
  `scratch-dir` = tempdir()
))
.libPaths(e0_lib_paths())
scratch <- normalizePath(opt$`scratch-dir`, winslash = "/", mustWork = TRUE)
actual <- file.path(scratch, paste0("history-e0-gut-", Sys.getpid()))
rscript <- e0_rscript()

run_status <- system2(rscript, c(
  file.path(dirname(script_path), "run_spike.R"), "--preset", "smoke",
  "--package-root", normalizePath(opt$`package-root`, winslash = "/"),
  "--out-dir", actual, "--gut", "omit-bars-by-id"
))
if (!run_status %in% c(0L, 1L)) stop("Gutted runner failed unexpectedly.", call. = FALSE)
check_status <- system2(rscript, c(
  file.path(dirname(script_path), "check_spike.R"),
  "--against", normalizePath(opt$against, winslash = "/"),
  "--actual", actual, "--package-root",
  normalizePath(opt$`package-root`, winslash = "/"), "--scratch-dir", scratch
))
if (identical(check_status, 0L)) {
  stop("Checker accepted a staged payload without bars_by_id.", call. = FALSE)
}
cat("HISTORY_E0_GUT_OK omitted=bars_by_id checker_status=", check_status, "\n", sep = "")
