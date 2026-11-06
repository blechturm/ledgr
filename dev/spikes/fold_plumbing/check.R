# Fold plumbing spike checker.
#
#   Rscript check.R --pkg=<ledgr source tree at d5b3a151> --scratch=<dir>
#
# Reruns run.R into a scratch directory with one timing repetition, diffs
# every structural CSV against evidence/ exactly, checks that the timing and
# allocation tables have the same rows, that the gutted path and the
# reference recorder fail while every other skeleton matches the real run,
# and that the package scope is untouched.

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
rscript <- file.path(R.home("bin"), "Rscript")
status <- system2(rscript, c(file.path(here, "run.R"), paste0("--pkg=", pkg), paste0("--out=", scratch), "--reps=1"))
if (!identical(status, 0L)) stop("run.R failed", call. = FALSE)

problems <- character()
read <- function(dir, f) utils::read.csv(file.path(dir, f), stringsAsFactors = FALSE)
for (f in c("parity.csv", "check_census.csv", "sizes.csv", "reads_per_call.csv")) {
  if (!identical(read(evidence, f), read(scratch, f))) problems <- c(problems, paste(f, "differs"))
}
for (f in c("timing.csv", "alloc.csv")) {
  key <- function(d) sort(paste(d[[1L]], d[[2L]]))
  if (!identical(key(read(evidence, f)), key(read(scratch, f)))) problems <- c(problems, paste(f, "rows differ"))
}
parity <- read(scratch, "parity.csv")
expected_fail <- grepl("gut|by_reference", parity$variant) & parity$output %in% c("events", "decision_per_pulse")
if (!all(parity$identical == !expected_fail)) problems <- c(problems, "a parity row has the wrong outcome")

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
cat("PASS: structural evidence reproduced; gutted path and reference recorder fail; scope clean\n")
