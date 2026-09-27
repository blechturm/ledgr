# Checker for the fill-event block-write spike (spike_protocol.md section 6).
#
#   1. rerun the deterministic parity phase into a scratch directory;
#   2. diff fixture.csv and parity.csv line by line against the recorded
#      evidence; validate the measured CSVs (every repetition carries both arms
#      in alternating order, timing_summary.csv is recomputed from timing.csv,
#      attribution.csv covers both arms of both workflows); confirm the recorded
#      Git baseline and the three seamed production files are the ones checked out;
#   3. guard package scope: no tracked or untracked change under R, src, tests,
#      NAMESPACE, DESCRIPTION, man or inst/design.
#
# Usage, from the repository root:
#   Rscript dev/spikes/fill-event-block-write/spike_checker.R [--skip-rerun] [--gut misorder]
# --gut misorder reruns with staged columns written out of event_seq order; the
# diff must fail. Exit status is non-zero on any failure.

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, default) { i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[[i + 1L]] }
script_path <- local({
  f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  normalizePath(sub("^--file=", "", f[[1L]]), winslash = "/")
})
spike_dir <- dirname(script_path)
repo_root <- normalizePath(file.path(spike_dir, "..", "..", ".."), winslash = "/")
evidence <- file.path(spike_dir, "evidence")
gut <- arg_value("--gut", "none")
scratch <- tempfile("fill_event_block_write_rerun_")

failures <- character()
note <- function(ok, what) {
  cat(sprintf("[%s] %s\n", if (isTRUE(ok)) "PASS" else "FAIL", what))
  if (!isTRUE(ok)) failures <<- c(failures, what)
  invisible(isTRUE(ok))
}
git <- function(...) {
  old <- Sys.getenv("HOME"); on.exit(Sys.setenv(HOME = old), add = TRUE)
  if (nzchar(Sys.getenv("USERPROFILE"))) Sys.setenv(HOME = Sys.getenv("USERPROFILE"))
  suppressWarnings(system2("git", c("-C", shQuote(repo_root), ...), stdout = TRUE, stderr = FALSE))
}
read_ev <- function(name) utils::read.csv(file.path(evidence, name), stringsAsFactors = FALSE)

# 1-2. Rerun and diff the deterministic evidence.
if (!("--skip-rerun" %in% args)) {
  status <- system2(file.path(R.home("bin"), "Rscript"), c(shQuote(file.path(spike_dir, "spike_runner.R")),
    "--phase", "parity", "--out", shQuote(scratch), "--gut", gut), stdout = FALSE, stderr = FALSE)
  note(identical(status, 0L), sprintf("parity rerun completed (gut = %s)", gut))
  for (name in c("fixture.csv", "parity.csv")) {
    recorded <- readLines(file.path(evidence, name), warn = FALSE)
    rerun <- if (file.exists(file.path(scratch, name))) readLines(file.path(scratch, name), warn = FALSE) else character()
    same <- identical(recorded, rerun)
    note(same, sprintf("%s matches the rerun", name))
    if (!same) {
      n <- max(length(recorded), length(rerun)); length(recorded) <- n; length(rerun) <- n
      i <- which(is.na(recorded) | is.na(rerun) | recorded != rerun)
      for (j in utils::head(i, 4L)) cat(sprintf("    line %d\n      recorded: %s\n      rerun:    %s\n", j, recorded[[j]], rerun[[j]]))
    }
  }
  unlink(scratch, recursive = TRUE, force = TRUE)
}

# 2. Measured evidence.
timing <- read_ev("timing.csv")
per_rep <- split(timing, paste(timing$workflow, timing$rep))
note(all(vapply(per_rep, function(d) nrow(d) == 2L && setequal(d$arm, c("base", "block")), logical(1))),
  "every timed repetition carries exactly one base and one block observation")
first <- timing[timing$position == 1L, ]
note(all(first$arm == ifelse(first$rep %% 2L == 1L, "base", "block")), "arm order alternates by repetition")
note(all(timing$elapsed_s > 0) && all(timing$gc_s >= 0), "elapsed times are positive and GC times non-negative")
source(file.path(spike_dir, "summarise_timing.R"), local = TRUE)
recomputed <- tempfile(fileext = ".csv")
utils::write.csv(summarise_timing(timing), recomputed, row.names = FALSE)
note(identical(readLines(recomputed), readLines(file.path(evidence, "timing_summary.csv"))),
  "timing_summary.csv is reproduced from timing.csv")
attribution <- read_ev("attribution.csv")
note(setequal(unique(paste(attribution$workflow, attribution$arm)),
  c("ledgr_run base", "ledgr_run block", "ledgr_sweep base", "ledgr_sweep block")) && all(attribution$sampled_seconds > 0),
  "attribution.csv covers both arms of both workflows")

width <- read_ev("width_scaling.csv")
width_rep <- split(width, paste(width$instruments, width$workflow, width$rep))
note(all(vapply(width_rep, function(d) nrow(d) == 2L && setequal(d$arm, c("base", "block")), logical(1))) &&
  all(width$elapsed_s > 0), "width_scaling.csv (follow-up probe) pairs both arms in every repetition")
hot <- read_ev("hotspots.csv")
note(setequal(unique(hot$workload), c("ledgr_run", "ledgr_sweep", "ledgr_sweep_compiled_spot_fifo")) &&
  all(hot$sampled_seconds > 0), "hotspots.csv (follow-up probe) covers run, sweep and compiled sweep")

env <- read_ev("environment.csv")
env_value <- function(k) env$value[env$key == k]
note(identical(attr(git("merge-base", "--is-ancestor", env_value("git_head"), "HEAD"), "status"), NULL),
  "recorded git_head is HEAD or one of its ancestors")
note(identical(env_value("blob_fold_engine"), git("rev-parse", "HEAD:R/fold-engine.R")[[1L]]) &&
  identical(env_value("blob_sweep"), git("rev-parse", "HEAD:R/sweep.R")[[1L]]) &&
  identical(env_value("blob_backtest_runner"), git("rev-parse", "HEAD:R/backtest-runner.R")[[1L]]),
  "recorded blobs of the three seamed production files match HEAD")
note(identical(env_value("gut"), "none"), "recorded evidence was produced without a gut")

# 3. Package scope.
changed <- git("status", "--porcelain", "--untracked-files=all", "--", "R", "src", "tests",
  "NAMESPACE", "DESCRIPTION", "man", "inst/design")
note(length(changed) == 0L, "package scope unchanged (R, src, tests, NAMESPACE, DESCRIPTION, man, inst/design)")
if (length(changed)) cat(paste0("    ", changed), sep = "\n")

cat(sprintf("\nspike_checker: %d failure(s)\n", length(failures)))
if (length(failures)) { cat(paste0("  - ", failures), sep = "\n"); quit(status = 1L) }
quit(status = 0L)
