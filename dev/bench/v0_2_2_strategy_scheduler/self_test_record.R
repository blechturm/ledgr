# Failure-sensitivity check for the registered H1 record checker.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Usage: self_test_record.R <checker> <record_dir>", call. = FALSE)
checker <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
record <- normalizePath(args[[2L]], winslash = "/", mustWork = TRUE)
rscript <- file.path(R.home("bin"), "Rscript.exe")

baseline <- suppressWarnings(system2(rscript, c(checker, record), stdout = TRUE, stderr = TRUE))
if (!is.null(attr(baseline, "status")) && !identical(attr(baseline, "status"), 0L)) {
  stop("Baseline record does not pass before self-test mutations.", call. = FALSE)
}

expect_rejected <- function(name, mutate) {
  scratch <- tempfile(paste0("ws63-", name, "-"))
  dir.create(scratch)
  files <- list.files(record, full.names = TRUE)
  if (!all(file.copy(files, scratch))) stop("Could not copy record for self-test.", call. = FALSE)
  mutate(scratch)
  status <- suppressWarnings(system2(rscript, c(checker, scratch), stdout = TRUE, stderr = TRUE))
  if (is.null(attr(status, "status")) || identical(attr(status, "status"), 0L)) {
    stop("Checker accepted mutation: ", name, call. = FALSE)
  }
  unlink(scratch, recursive = TRUE, force = TRUE)
  invisible(TRUE)
}

summary_file <- function(path, arm) {
  list.files(path, pattern = paste0("_", arm, "_summary[.]csv$"), full.names = TRUE)[[1L]]
}

expect_rejected("economic-hash", function(path) {
  file <- summary_file(path, "scheduled")
  x <- utils::read.csv(file, stringsAsFactors = FALSE)
  x$fills_hash <- paste0("bad-", x$fills_hash)
  utils::write.csv(x, file, row.names = FALSE)
})
expect_rejected("decision-date", function(path) {
  file <- list.files(path, pattern = "_scheduled_due_dates[.]csv$", full.names = TRUE)[[1L]]
  x <- utils::read.csv(file, stringsAsFactors = FALSE)
  x$due_date[[1L]] <- "2099-01-01"
  utils::write.csv(x, file, row.names = FALSE)
})
expect_rejected("skip-count", function(path) {
  file <- summary_file(path, "scheduled")
  x <- utils::read.csv(file, stringsAsFactors = FALSE)
  x$scheduled_skip_count <- x$scheduled_skip_count - 1L
  utils::write.csv(x, file, row.names = FALSE)
})
expect_rejected("timing-gate", function(path) {
  files <- list.files(path, pattern = "_scheduled_summary[.]csv$", full.names = TRUE)
  for (file in files) {
    x <- utils::read.csv(file, stringsAsFactors = FALSE)
    x$elapsed_s <- x$elapsed_s * 2
    utils::write.csv(x, file, row.names = FALSE)
  }
})
cat("LEDGR_SCHEDULER_SELF_TEST_OK mutations=4\n")
