# Failure-sensitivity check for the untimed diagnostic parity record.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) {
  stop("Usage: self_test_diagnostic_parity.R <checker> <record_dir>", call. = FALSE)
}
checker <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
record <- normalizePath(args[[2L]], winslash = "/", mustWork = TRUE)
rscript <- file.path(R.home("bin"), "Rscript.exe")

run_check <- function(path) {
  suppressWarnings(system2(rscript, c(checker, path), stdout = TRUE, stderr = TRUE))
}
baseline <- run_check(record)
if (!is.null(attr(baseline, "status")) && !identical(attr(baseline, "status"), 0L)) {
  stop("Diagnostic parity baseline does not pass.", call. = FALSE)
}

expect_rejected <- function(name, mutate) {
  scratch <- tempfile(paste0("ws63-diagnostic-", name, "-"))
  dir.create(scratch)
  files <- list.files(record, full.names = TRUE)
  if (!all(file.copy(files, scratch))) stop("Could not copy parity record.", call. = FALSE)
  mutate(scratch)
  result <- run_check(scratch)
  if (is.null(attr(result, "status")) || identical(attr(result, "status"), 0L)) {
    stop("Diagnostic parity checker accepted mutation: ", name, call. = FALSE)
  }
  unlink(scratch, recursive = TRUE, force = TRUE)
}

expect_rejected("retained-row", function(path) {
  file <- list.files(path, pattern = "_scheduled_off_diagnostic_counts[.]csv$", full.names = TRUE)[[1L]]
  x <- utils::read.csv(file, stringsAsFactors = FALSE)
  retained <- which(!x$stage %in% c("decision", "risk"))[[1L]]
  x$n[[retained]] <- x$n[[retained]] - 1L
  utils::write.csv(x, file, row.names = FALSE)
})
expect_rejected("retained-hash", function(path) {
  file <- list.files(path, pattern = "_scheduled_summary[.]csv$", full.names = TRUE)[[1L]]
  x <- utils::read.csv(file, stringsAsFactors = FALSE)
  x$retained_off_diagnostics_hash <- paste0("bad-", x$retained_off_diagnostics_hash)
  utils::write.csv(x, file, row.names = FALSE)
})

cat("LEDGR_SCHEDULER_DIAGNOSTIC_PARITY_SELF_TEST_OK mutations=2\n")
