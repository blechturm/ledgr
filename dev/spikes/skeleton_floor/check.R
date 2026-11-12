# Checker: rerun the runner into a scratch directory, diff parity against
# the recorded evidence, check the timing table's rows, require the gutted
# skeleton to fail parity, and guard package scope.
#   Rscript dev/spikes/skeleton_floor/check.R <ledgr lib> <scratch dir>
args <- commandArgs(TRUE)
lib <- args[[1]]; scratch <- args[[2]]
here <- file.path("dev", "spikes", "skeleton_floor")
evidence <- file.path(here, "evidence")
scope <- c("R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man", "inst/design")
status <- function() system2("git", c("status", "--porcelain", "--", scope), stdout = TRUE)
read <- function(dir, f) utils::read.csv(file.path(dir, f), stringsAsFactors = FALSE)
rscript <- file.path(R.home("bin"), "Rscript")
ok_cols <- c("fills_identical", "equity_identical", "cash_identical")

before <- status()
problems <- character()
recorded <- read(evidence, "parity.csv")
shapes <- paste(unique(recorded$shape), collapse = ",")
rc <- system2(rscript, c(file.path(here, "run.R"), lib, scratch, shapes, "2"), stdout = FALSE, stderr = FALSE)
if (rc != 0L) {
  problems <- c(problems, sprintf("run.R exited %d", rc))
} else {
  fresh <- read(scratch, "parity.csv")
  if (!identical(fresh, recorded)) problems <- c(problems, "parity.csv differs from the recorded evidence")
  if (!all(as.matrix(fresh[ok_cols]))) problems <- c(problems, "a skeleton variant no longer reproduces the floor")
  keys <- c("shape", "variant")
  if (!identical(read(scratch, "timings.csv")[keys], read(evidence, "timings.csv")[keys])) {
    problems <- c(problems, "timings.csv rows differ from the recorded evidence")
  }
}
gut_dir <- file.path(scratch, "gut")
rc <- system2(rscript, c(file.path(here, "run.R"), lib, gut_dir, "3x40", "1", "same_bar_fill"), stdout = FALSE, stderr = FALSE)
if (rc != 0L) {
  problems <- c(problems, sprintf("gutted run.R exited %d", rc))
} else {
  g <- read(gut_dir, "parity.csv")
  gutted <- g$variant == "skeleton"
  if (any(as.matrix(g[gutted, ok_cols]))) problems <- c(problems, "the gutted skeleton still matches the floor")
  if (!all(as.matrix(g[!gutted, ok_cols]))) problems <- c(problems, "an intact variant fails beside the gutted one")
}
if (!identical(status(), before)) problems <- c(problems, "package scope changed during the run")

if (length(problems)) {
  cat("SKELETON_FLOOR_CHECK_FAILED\n", paste0("  ", problems, "\n"), sep = "")
  quit(status = 1L)
}
cat("SKELETON_FLOOR_CHECK_OK\n")
