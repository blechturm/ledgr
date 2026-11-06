# Append-validator spike checker.
#
#   Rscript check.R --pkg=<ledgr source tree at d5b3a151> --scratch=<dir>
#
# Reruns run.R into a scratch directory with one timing repetition, diffs
# parity.csv against evidence/ exactly, checks the timing table has the
# same rows, requires every arm to match the pinned check except the gutted
# R arm on `evidence_on_fill`, and guards package scope.

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
                  c(file.path(here, "run.R"), paste0("--pkg=", pkg), paste0("--out=", scratch), "--reps=1"))
if (!identical(status, 0L)) stop("run.R failed", call. = FALSE)

problems <- character()
read <- function(dir, f) utils::read.csv(file.path(dir, f), stringsAsFactors = FALSE)
if (!identical(read(evidence, "parity.csv"), read(scratch, "parity.csv"))) problems <- c(problems, "parity.csv differs")
key <- function(d) sort(paste(d$rows, d$arm))
if (!identical(key(read(evidence, "timing.csv")), key(read(scratch, "timing.csv")))) {
  problems <- c(problems, "timing.csv rows differ")
}
p <- read(scratch, "parity.csv")
expect <- !(p$arm == "r_gut_no_evidence_rule" & p$case == "evidence_on_fill")
if (!all(p$matches_pinned == expect)) problems <- c(problems, "a parity row has the wrong outcome")

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
cat("PASS: parity reproduced; gutted arm differs only on evidence_on_fill; scope clean\n")
