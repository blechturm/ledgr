command <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", command, value = TRUE)
script <- normalizePath(sub("^--file=", "", file_arg[[1L]]), winslash = "/")
root <- dirname(script)
repo <- normalizePath(file.path(root, "..", "..", ".."), winslash = "/")

protected <- c("R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man", "inst/design")
status <- system2(
  "git",
  c("-c", paste0("safe.directory=", repo), "-C", repo, "status", "--short", "--", protected),
  stdout = TRUE,
  stderr = TRUE
)
if (length(status)) {
  stop("Package scope is dirty: ", paste(status, collapse = " | "), call. = FALSE)
}

source(file.path(root, "spike_runner.R"))
scratch <- file.path(tempdir(), "ledgr-compiler-spike-check")
unlink(scratch, recursive = TRUE, force = TRUE)
compiler_spike_main(
  c("--preset", "smoke", "--output", scratch, "--no-bench", "--verify-gut"),
  root
)

recorded_dir <- file.path(root, "results", "windows-r4.6.1")
normalize_correctness <- function(path) {
  x <- utils::read.csv(path, stringsAsFactors = FALSE, na.strings = "NA")
  x$max_abs_error <- ifelse(is.na(x$max_abs_error), NA_real_, signif(x$max_abs_error, 12L))
  x
}

actual <- normalize_correctness(file.path(scratch, "correctness.csv"))
expected <- normalize_correctness(file.path(recorded_dir, "correctness.csv"))
if (!identical(actual, expected)) {
  stop("Correctness evidence differs from the recorded CSV.", call. = FALSE)
}

status_columns <- c("compiler", "available", "version", "detail")
actual_status <- utils::read.csv(file.path(scratch, "compiler_status.csv"), stringsAsFactors = FALSE)
expected_status <- utils::read.csv(file.path(recorded_dir, "compiler_status.csv"), stringsAsFactors = FALSE)
if (!identical(actual_status[status_columns], expected_status[status_columns])) {
  stop("Compiler availability differs from the recorded CSV.", call. = FALSE)
}

gutted <- utils::read.csv(file.path(scratch, "gutted_correctness.csv"), stringsAsFactors = FALSE)
if (!any(gutted$status == "fail" & gutted$workload == "stateful" & gutted$variant == "rcpp")) {
  stop("The deliberate stateful gut did not fail.", call. = FALSE)
}

cat("PASS: rerun matches semantic evidence and the deliberate gut fails.\n")
