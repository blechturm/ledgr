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
  "--out-dir", actual, "--gut", "omit-runtime-projection"
))
if (!identical(run_status, 0L)) stop("Gutted runner failed unexpectedly.", call. = FALSE)
meta <- utils::read.csv(file.path(actual, "arm_c", "arm_meta.csv"), stringsAsFactors = FALSE)
expected_error <- "E0_STAGED_RECONSTRUCTION_MISMATCH omitted=runtime_projection"
if (!identical(meta$status[[1L]], "FAILED") ||
    !identical(meta$error_message[[1L]], expected_error)) {
  stop("Gut did not trigger the exact staged-reconstruction failure.", call. = FALSE)
}
reconstruction <- utils::read.csv(
  file.path(actual, "arm_c", "reconstruction.csv"), stringsAsFactors = FALSE
)
if (any(reconstruction$exact) ||
    !all(reconstruction$missing_fields == "runtime_projection") ||
    !all(is.na(reconstruction$extra_fields) | reconstruction$extra_fields == "")) {
  stop("Gut reconstruction inventory did not name the omitted field.", call. = FALSE)
}
check_output <- system2(rscript, c(
  file.path(dirname(script_path), "check_spike.R"),
  "--against", normalizePath(opt$against, winslash = "/"),
  "--actual", actual, "--package-root",
  normalizePath(opt$`package-root`, winslash = "/"), "--scratch-dir", scratch
), stdout = TRUE, stderr = TRUE)
check_status <- attr(check_output, "status")
if (is.null(check_status)) check_status <- 0L
if (identical(check_status, 0L) ||
    !any(grepl("result_identity[.]csv differs", check_output, fixed = FALSE))) {
  stop("Checker missed the staged runtime_projection omission.", call. = FALSE)
}
cat(
  "HISTORY_E0_GUT_OK omitted=runtime_projection checker_status=",
  check_status, "\n", sep = ""
)
