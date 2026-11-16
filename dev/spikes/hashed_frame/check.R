# Checker (README): (1) the fork's gate subset against the freeze with debug
# off and on (every table identical to the pin, every frozen path matched),
# diffed against the recorded evidence; (2) a gutted fork (the hashed frame's
# parent skips the call frame) must fail the gate; (3) package scope: no
# change under R, src, tests, NAMESPACE, DESCRIPTION, man or inst/design in
# the working tree (line endings ignored).
#   Rscript dev/spikes/hashed_frame/check.R --lib=<pin> --fork=<worktree dir> [--record=1] [--scratch=<dir>]
# The fork worktree is `git worktree add --detach <dir> <commit>`; this script
# copies hashed.R (or the gutted fork) into its dev/lean_core as zz_hashed.R.
args <- commandArgs(TRUE)
opt <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
root <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
lib <- opt("lib"); fork <- normalizePath(opt("fork"), winslash = "/", mustWork = TRUE)
record <- identical(opt("record"), "1")
scratch <- opt("scratch", file.path(tempdir(), "hashed_check"))
dir.create(scratch, showWarnings = FALSE, recursive = TRUE)
ev <- file.path(here, "evidence")
rscript <- file.path(R.home("bin"), "Rscript")
fails <- character()
workloads <- paste(c(readLines(file.path(here, "workloads.txt"))), collapse = ",")

install_fork <- function(text) writeLines(text, file.path(fork, "dev", "lean_core", "zz_hashed.R"))
gate <- function(debug, out, wl = workloads, freeze = TRUE) {
  status <- system2(rscript, c(file.path(fork, "dev", "lean_core", "parity", "loop_parity.R"), paste0("--lib=", lib),
    paste0("--debug=", debug), paste0("--workloads=", wl), paste0("--out=", out),
    if (freeze) paste0("--freeze=", file.path(fork, "dev", "lean_core", "parity", "loop_freeze.csv"))),
    stdout = paste0(out, ".log"), stderr = paste0(out, ".log"))
  list(status = status, rows = if (file.exists(out)) utils::read.csv(out, stringsAsFactors = FALSE) else NULL,
       log = readLines(paste0(out, ".log")))
}
keep <- c("workload", "path", "table", "debug", "lean_folds", "refused", "backstop", "identical")

# (1) The fork against the pin.
fork_text <- readLines(file.path(here, "hashed.R"))
install_fork(fork_text)
for (d in 0:1) {
  g <- gate(d, file.path(scratch, sprintf("gate_debug%d.csv", d)))
  r <- g$rows
  frozen <- grep("^frozen paths", g$log, value = TRUE)
  ok <- g$status == 0L && !is.null(r) && all(r$identical) && length(frozen) == 1L &&
    grepl("^frozen paths \\(gate, debug [01]\\): ([0-9]+) of \\1 workloads checked", frozen)
  cat(sprintf("gate debug %d: status %d, %d tables, %d different; %s\n", d, g$status, NROW(r),
              if (is.null(r)) NA else sum(!r$identical), if (length(frozen)) frozen else "no frozen-path line"))
  if (!ok) fails <- c(fails, sprintf("gate debug %d", d))
  rec <- file.path(ev, sprintf("gate_debug%d.csv", d))
  if (record && ok) utils::write.csv(r[, keep], rec, row.names = FALSE)
  if (!record) {
    if (!file.exists(rec)) fails <- c(fails, paste("no recorded", basename(rec)))
    else if (!identical(utils::read.csv(rec, stringsAsFactors = FALSE), r[, keep])) fails <- c(fails, paste("differs from", basename(rec)))
  }
}

# (2) Gutted fork: the hashed frame's parent is the lean environment, not the
# call frame, so the body cannot see its arguments. The gate must fail.
gut <- sub("new.env(hash = TRUE, parent = environment())", "new.env(hash = TRUE, parent = parent.env(environment()))",
           fork_text, fixed = TRUE)
if (identical(gut, fork_text)) stop("the gutted fork did not change hashed.R")
install_fork(gut)
g <- gate(0L, file.path(scratch, "gut_debug0.csv"), wl = "crossover_3x40,s3_gap_held", freeze = FALSE)
gut_failed <- g$status != 0L || is.null(g$rows) || !all(g$rows$identical) || any(grepl("DIFFERENT|FAIL", g$log))
cat(sprintf("gutted fork: status %d, %s\n", g$status, if (gut_failed) "fails as required" else "PASSED (checker cannot fail)"))
if (!gut_failed) fails <- c(fails, "the gutted fork passed")
install_fork(fork_text)

# (3) Package scope.
changed <- system2("git", c("-C", root, "diff", "--ignore-cr-at-eol", "--name-only", "HEAD", "--",
  "R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man", "inst/design"), stdout = TRUE)
cat("package scope:", if (length(changed)) paste(changed, collapse = ", ") else "clean", "\n")
if (length(changed)) fails <- c(fails, "package scope")

if (length(fails)) { cat("CHECK FAILED:", paste(fails, collapse = "; "), "\n"); quit(status = 1L) }
cat("CHECK PASSED\n")
