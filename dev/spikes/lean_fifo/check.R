# Checker: rerun into a scratch directory, diff parity against the recorded
# evidence, require the gutted kernel to fail, and guard package scope.
# Usage: Rscript dev/spikes/lean_fifo/check.R <ledgr lib> <scratch dir> [quickr lib]
# With a quickr library, the compiled kernel's parity is checked too.
args <- commandArgs(TRUE)
lib <- args[[1]]; scratch <- args[[2]]
here <- file.path("dev", "spikes", "lean_fifo")
scope <- c("R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man", "inst/design")
status <- function() system2("git", c("status", "--porcelain", "--", scope), stdout = TRUE)
rscript <- function(...) system2(file.path(R.home("bin"), "Rscript"), c(...), stdout = FALSE, stderr = FALSE)
before <- status(); problems <- character()

if (rscript(file.path(here, "run.R"), lib, file.path(scratch, "intact")) != 0L) {
  problems <- c(problems, "run.R exited non-zero")
} else {
  fresh <- utils::read.csv(file.path(scratch, "intact", "parity.csv"))
  if (!identical(fresh, utils::read.csv(file.path(here, "evidence", "parity.csv")))) {
    problems <- c(problems, "parity.csv differs from the recorded evidence")
  }
  if (any(fresh$blocks_differing != 0L)) problems <- c(problems, "the lean kernel differs from ledgr's")
}
if (rscript(file.path(here, "run.R"), lib, file.path(scratch, "gut"), "plain_sum") != 0L) {
  problems <- c(problems, "gutted run exited non-zero")
} else if (all(utils::read.csv(file.path(scratch, "gut", "parity.csv"))$blocks_differing == 0L)) {
  problems <- c(problems, "the gutted kernel (no Kahan step) was not detected")
}
if (length(args) >= 3L) {
  if (rscript(file.path(here, "run_quickr.R"), lib, args[[3]], file.path(scratch, "quickr")) != 0L) {
    problems <- c(problems, "run_quickr.R exited non-zero")
  } else {
    fresh <- utils::read.csv(file.path(scratch, "quickr", "parity_quickr.csv"))
    if (!identical(fresh, utils::read.csv(file.path(here, "evidence", "parity_quickr.csv")))) {
      problems <- c(problems, "parity_quickr.csv differs from the recorded evidence")
    }
    if (any(fresh$blocks_differing != 0L)) problems <- c(problems, "the quickr kernel differs from ledgr's")
  }
}
if (!identical(status(), before)) problems <- c(problems, "package scope changed during the run")
if (length(problems)) {
  cat("LEAN_FIFO_CHECK_FAILED\n", paste0("  ", problems, "\n"), sep = "")
  quit(status = 1L)
}
cat("LEAN_FIFO_CHECK_OK\n")
