# Write-mode probe checker.
#
#   Rscript check.R --pkg=<pinned tree at d5b3a151> --scratch=<dir>
#
# Reruns run.R into a scratch directory (one round, one repetition), diffs
# parity.csv against evidence/ exactly, checks the timing table's rows,
# requires every table to be identical across modes, and guards package
# scope.

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])))
arg <- function(name) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) stop("Missing --", name, "=.", call. = FALSE)
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
pkg <- arg("pkg")
scratch <- arg("scratch")
dir.create(scratch, recursive = TRUE, showWarnings = FALSE)
evidence <- file.path(here, "evidence")
status <- system2(file.path(R.home("bin"), "Rscript"),
                  c(file.path(here, "run.R"), paste0("--pkg=", pkg), paste0("--out=", scratch),
                    "--rounds=1", "--reps=1"))
if (!identical(status, 0L)) stop("run.R failed", call. = FALSE)

problems <- character()
read <- function(dir, f) utils::read.csv(file.path(dir, f), stringsAsFactors = FALSE)
if (!identical(read(evidence, "parity.csv"), read(scratch, "parity.csv"))) problems <- c(problems, "parity.csv differs")
key <- function(d) sort(paste(d$mode, d$workload))
if (!identical(key(read(evidence, "timing.csv")), key(read(scratch, "timing.csv")))) {
  problems <- c(problems, "timing.csv rows differ")
}
if (!all(read(scratch, "parity.csv")$identical)) problems <- c(problems, "the modes wrote different stores")

repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
git <- function(...) system2("git", c("-C", repo, ...), stdout = TRUE)
if (length(git("status", "--porcelain", "--", "R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man"))) {
  problems <- c(problems, "package scope changed")
}
if (length(git("diff", "--name-only", "HEAD", "--", "inst/design"))) {
  problems <- c(problems, "tracked design files changed")
}
if (length(problems)) {
  cat(paste("FAIL:", problems), sep = "\n")
  quit(status = 1L)
}
cat("PASS: both modes write identical stores; scope clean\n")
