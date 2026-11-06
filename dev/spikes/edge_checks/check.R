# Edge-checks spike checker.
#
#   Rscript check.R --pkg=<pinned tree at d5b3a151> --scratch=<dir>
#
# Reruns run.R into a scratch directory (one round, one repetition), diffs
# patches.csv, parity.csv and edge.csv against evidence/ exactly, checks
# the timing table's rows, requires the gut tree to differ from the pin and
# the edge tree to match it, and guards package scope.

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
                  c(file.path(here, "run.R"), paste0("--pkg=", pkg), paste0("--trees=", file.path(scratch, "trees")),
                    paste0("--out=", file.path(scratch, "out")), "--rounds=1", "--reps=1"))
if (!identical(status, 0L)) stop("run.R failed", call. = FALSE)

problems <- character()
read <- function(dir, f) utils::read.csv(file.path(dir, f), stringsAsFactors = FALSE)
got <- file.path(scratch, "out")
for (f in c("patches.csv", "parity.csv", "edge.csv")) {
  if (!identical(read(evidence, f), read(got, f))) problems <- c(problems, paste(f, "differs"))
}
key <- function(d) sort(paste(d$tree, d$workload))
if (!identical(key(read(evidence, "timing.csv")), key(read(got, "timing.csv")))) {
  problems <- c(problems, "timing.csv rows differ")
}
p <- read(got, "parity.csv")
if (!all(p$identical_to_pinned[p$tree == "edge"]) || all(p$identical_to_pinned[p$tree == "gut"])) {
  problems <- c(problems, "parity outcome wrong")
}

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
cat("PASS: edge tree matches the pin, gut tree differs, edge refusals kept, scope clean\n")
