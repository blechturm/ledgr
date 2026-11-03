# Checker: rerun into a scratch directory, diff parity against the recorded
# evidence, check the timing table's shape, and guard package scope.
# Usage: Rscript dev/spikes/r_floor/check.R <ledgr lib> <scratch dir>
args <- commandArgs(TRUE)
lib <- args[[1]]; scratch <- args[[2]]
here <- file.path("dev", "spikes", "r_floor")
evidence <- file.path(here, "evidence")
scope <- c("R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man", "inst/design")
status <- function() system2("git", c("status", "--porcelain", "--", scope), stdout = TRUE)

before <- status()
recorded <- utils::read.csv(file.path(evidence, "parity.csv"), stringsAsFactors = FALSE)
shapes <- paste(unique(recorded$shape), collapse = ",")
rc <- system2(file.path(R.home("bin"), "Rscript"),
              c(file.path(here, "run.R"), lib, scratch, shapes), stdout = FALSE, stderr = FALSE)
problems <- character()
if (rc != 0L) problems <- c(problems, sprintf("runner exited %d", rc))
if (file.exists(file.path(scratch, "parity.csv"))) {
  fresh <- utils::read.csv(file.path(scratch, "parity.csv"), stringsAsFactors = FALSE)
  if (!identical(fresh, recorded)) problems <- c(problems, "parity.csv differs from the recorded evidence")
  if (!all(fresh$fills_identical & fresh$equity_identical & fresh$cash_identical)) {
    problems <- c(problems, "the floor no longer reproduces ledgr's fills, equity or cash")
  }
  timings <- utils::read.csv(file.path(scratch, "timings.csv"))
  shape_ok <- identical(timings[c("shape", "variant")],
    utils::read.csv(file.path(evidence, "timings.csv"))[c("shape", "variant")])
  if (!shape_ok) problems <- c(problems, "timings.csv rows differ from the recorded evidence")
} else {
  problems <- c(problems, "no parity.csv was written")
}
if (!identical(status(), before)) problems <- c(problems, "package scope changed during the run")

if (length(problems)) {
  cat("R_FLOOR_CHECK_FAILED\n", paste0("  ", problems, "\n"), sep = "")
  quit(status = 1L)
}
cat("R_FLOOR_CHECK_OK\n")
