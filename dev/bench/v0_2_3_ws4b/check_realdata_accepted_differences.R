#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) {
  stop("usage: check_realdata_accepted_differences.R <reference> <sweep-rerun> <walk-forward-rerun>")
}

reference <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
sweep_rerun <- normalizePath(args[[2L]], winslash = "/", mustWork = TRUE)
walk_forward_rerun <- normalizePath(args[[3L]], winslash = "/", mustWork = TRUE)

read_table <- function(path) {
  utils::read.csv(path, colClasses = "character", check.names = FALSE)
}

same_except <- function(reference_path, candidate_path, dropped,
                        reference_only = character(), candidate_only = character()) {
  reference_table <- read_table(reference_path)
  candidate_table <- read_table(candidate_path)
  if (!identical(setdiff(names(reference_table), names(candidate_table)), reference_only) ||
      !identical(setdiff(names(candidate_table), names(reference_table)), candidate_only)) {
    return(FALSE)
  }
  shared <- setdiff(
    intersect(names(reference_table), names(candidate_table)),
    dropped
  )
  identical(reference_table[shared], candidate_table[shared])
}

checks <- c(
  sweep = same_except(
    file.path(reference, "w4_sweep", "r1", "sweep_candidates.csv"),
    file.path(sweep_rerun, "sweep_candidates.csv"),
    "diagnostics",
    candidate_only = "diagnostics"
  ),
  walk_forward_folds = same_except(
    file.path(reference, "w4_wf", "r1", "wf_folds.csv"),
    file.path(walk_forward_rerun, "wf_folds.csv"),
    c("session_id", "test_run_id")
  ),
  walk_forward_scores = same_except(
    file.path(reference, "w4_wf", "r1", "wf_scores.csv"),
    file.path(walk_forward_rerun, "wf_scores.csv"),
    c("session_id", "candidate_label")
  )
)

cat(sprintf("%s=%s\n", names(checks), checks))
if (!all(checks)) quit(status = 1L)
cat("WS4B_REALDATA_ACCEPTED_DIFFERENCES_OK\n")
