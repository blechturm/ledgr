# Checker for the feature-accessor lookup spike (spike_protocol.md section 6).
#
#   1. rerun the deterministic parity phase into a scratch directory;
#   2. diff fixture.csv, conformance.csv and parity.csv line by line against
#      the recorded evidence; validate the measured CSVs (every attempt pairs
#      both arms in alternating order with one kept pair per repetition,
#      timing_summary.csv recomputed from the kept pairs, every kept pair run
#      with under one other busy core and no other R process, width and
#      attribution coverage); confirm the recorded Git
#      baseline is HEAD or an ancestor and the seamed production files are unchanged;
#   3. guard package scope: no tracked or untracked change under R, src, tests,
#      NAMESPACE, DESCRIPTION, man or inst/design.
#
# Usage, from the repository root:
#   Rscript dev/spikes/feature-accessor-lookup/spike_checker.R [--skip-rerun] [--gut shifted]
# --gut shifted reruns with every instrument mapped to its neighbour's feature
# row; the diff must fail. Exit status is non-zero on any failure.

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, default) { i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[[i + 1L]] }
spike_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo_root <- normalizePath(file.path(spike_dir, "..", "..", ".."), winslash = "/")
evidence <- file.path(spike_dir, "evidence")
gut <- arg_value("--gut", "none")
scratch <- tempfile("feature_accessor_lookup_rerun_")

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

if (!("--skip-rerun" %in% args)) {
  status <- system2(file.path(R.home("bin"), "Rscript"), c(shQuote(file.path(spike_dir, "spike_runner.R")),
    "--phase", "parity", "--out", shQuote(scratch), "--gut", gut), stdout = FALSE, stderr = FALSE)
  note(identical(status, 0L), sprintf("parity rerun completed (gut = %s)", gut))
  for (name in c("fixture.csv", "conformance.csv", "parity.csv")) {
    recorded <- readLines(file.path(evidence, name), warn = FALSE)
    rerun <- if (file.exists(file.path(scratch, name))) readLines(file.path(scratch, name), warn = FALSE) else character()
    same <- identical(recorded, rerun)
    note(same, sprintf("%s matches the rerun", name))
    if (!same) {
      n <- max(length(recorded), length(rerun)); length(recorded) <- n; length(rerun) <- n
      i <- which(is.na(recorded) | is.na(rerun) | recorded != rerun)
      for (j in utils::head(i, 4L)) cat(sprintf("    line %d\n      recorded: %s\n      rerun:    %s\n", j,
        substr(recorded[[j]], 1L, 220L), substr(rerun[[j]], 1L, 220L)))
    }
  }
  unlink(scratch, recursive = TRUE, force = TRUE)
}

paired_ok <- function(d) {
  per_pair <- split(d, paste(d$instruments, d$workflow, d$rep, d$attempt))
  first <- d[d$position == 1L, ]
  kept <- d[d$kept %in% TRUE, ]
  all(vapply(per_pair, function(x) nrow(x) == 2L && setequal(x$arm, c("base", "prepared")) && length(unique(x$kept)) == 1L, logical(1))) &&
    all(first$arm == ifelse(first$rep %% 2L == 1L, "base", "prepared")) && all(d$elapsed_s > 0) &&
    all(table(paste(kept$instruments, kept$workflow, kept$rep)) == 2L)
}
load_gate <- function(d, label) {
  k <- d[d$kept %in% TRUE, ]
  note(all(is.finite(d$other_cpu_cores)) && all(d$other_cpu_cores >= 0) &&
    all(k$other_cpu_cores < 1) && all(k$other_r_processes == 0L),
    sprintf("every kept %s pair ran with under one other busy core and no other R process (kept max %.2f cores)",
      label, max(k$other_cpu_cores)))
  cat(sprintf("[INFO] %s: %d of %d observations discarded under the load rule and re-measured\n",
    label, sum(!d$kept), nrow(d)))
}
timing <- read_ev("timing.csv")
note(paired_ok(timing), "timing.csv: every attempt pairs both arms in alternating order, one kept pair per repetition")
source(file.path(spike_dir, "summarise_timing.R"), local = TRUE)
recomputed <- tempfile(fileext = ".csv")
utils::write.csv(summarise_timing(timing), recomputed, row.names = FALSE)
note(identical(readLines(recomputed), readLines(file.path(evidence, "timing_summary.csv"))),
  "timing_summary.csv is reproduced from the kept pairs in timing.csv")
# Load gate on kept pairs: CPU used by every other process during each timed observation,
# as average busy cores, and other R processes present at its end (same rule as the runner).
width <- read_ev("width_scaling.csv")
load_gate(timing, "release-shape")
load_gate(width, "width")
note(paired_ok(width) && setequal(unique(width$instruments), c(10L, 50L, 150L)),
  "width_scaling.csv covers 10, 50 and 150 instruments")
alloc <- read_ev("allocation.csv")
note(setequal(unique(alloc$instruments), c(10L, 50L, 150L, 500L)) && setequal(unique(alloc$arm), c("base", "prepared")),
  "allocation.csv (allocation probe) covers both arms at 10, 50, 150 and 500 instruments")
attribution <- read_ev("attribution.csv")
note(setequal(unique(paste(attribution$workflow, attribution$arm)),
  c("ledgr_run base", "ledgr_run prepared", "ledgr_sweep base", "ledgr_sweep prepared")) && all(attribution$sampled_seconds > 0),
  "attribution.csv covers both arms of run and sweep")

env <- read_ev("environment.csv")
env_value <- function(k) env$value[env$key == k]
note(identical(attr(git("merge-base", "--is-ancestor", env_value("git_head"), "HEAD"), "status"), NULL),
  "recorded git_head is HEAD or one of its ancestors")
note(identical(env_value("blob_runtime_projection"), git("rev-parse", "HEAD:R/runtime-projection.R")[[1L]]) &&
  identical(env_value("blob_feature_alias_map"), git("rev-parse", "HEAD:R/feature-alias-map.R")[[1L]]) &&
  identical(env_value("blob_pulse_context"), git("rev-parse", "HEAD:R/pulse-context.R")[[1L]]),
  "recorded blobs of the accessor source files match HEAD")
note(identical(env_value("gut"), "none"), "recorded evidence was produced without a gut")

changed <- git("status", "--porcelain", "--untracked-files=all", "--", "R", "src", "tests",
  "NAMESPACE", "DESCRIPTION", "man", "inst/design")
note(length(changed) == 0L, "package scope unchanged (R, src, tests, NAMESPACE, DESCRIPTION, man, inst/design)")
if (length(changed)) cat(paste0("    ", changed), sep = "\n")

cat(sprintf("\nspike_checker: %d failure(s)\n", length(failures)))
if (length(failures)) { cat(paste0("  - ", failures), sep = "\n"); quit(status = 1L) }
quit(status = 0L)
