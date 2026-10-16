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
gut <- file.path(scratch, paste0("history-e1-gut-", Sys.getpid()))
dir.create(gut, recursive = TRUE, showWarnings = FALSE)
status <- system2(e0_rscript(), c(
  file.path(dirname(script_path), "arm_worker.R"), "--arm", "D_REBUILD",
  "--preset", "smoke", "--package-root",
  normalizePath(opt$`package-root`, winslash = "/"), "--out-dir",
  file.path(gut, "gutted-arm"), "--verify", "true", "--gut",
  "omit-runtime-projection"
), stdout = TRUE, stderr = TRUE)
if (is.null(attr(status, "status")) || attr(status, "status") == 0L ||
    !any(grepl("E1_TASK_RECONSTRUCTION_MISSING fields=runtime_projection", status,
               fixed = TRUE))) {
  stop("Gutted runner did not fail at the exact omitted field.", call. = FALSE)
}

# The registered checker must also reject the corresponding evidence claim.
copy <- file.path(gut, "evidence")
dir.create(copy, recursive = TRUE)
invisible(file.copy(list.files(opt$against, full.names = TRUE), copy, recursive = TRUE))
recon <- utils::read.csv(file.path(copy, "reconstruction.csv"), stringsAsFactors = FALSE)
recon$exact[recon$arm == "D_REBUILD" & recon$candidate_id == "candidate_01"] <- FALSE
recon$mismatched_fields[recon$arm == "D_REBUILD" & recon$candidate_id == "candidate_01"] <- "runtime_projection"
utils::write.csv(recon, file.path(copy, "reconstruction.csv"), row.names = FALSE, na = "")
output <- system2(e0_rscript(), c(
  file.path(dirname(script_path), "check_spike.R"), "--against",
  normalizePath(opt$against, winslash = "/"), "--actual", copy,
  "--package-root", normalizePath(opt$`package-root`, winslash = "/"),
  "--scratch-dir", scratch
), stdout = TRUE, stderr = TRUE)
checker_status <- attr(output, "status") %||% 0L
if (checker_status == 0L ||
    !any(grepl("reconstruction.csv differs", output, fixed = TRUE))) {
  stop("Checker missed the gutted reconstruction evidence.", call. = FALSE)
}
cat("HISTORY_E1_GUT_OK omitted=runtime_projection checker_status=", checker_status, "\n", sep = "")
