# Gut demonstration for the H2 Session D indicator-history evidence.
#
# Replaces each finite-window restart value with the full-history value. The
# resulting zero deltas make every recursive output look bounded; check.R
# requires this wrong result to differ from the recorded evidence.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("usage: gut.R <ledgr_repo> <out_dir>")
repo <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
runner <- file.path(repo, "dev/spikes/history-indicator-conformance/runner.R")
status <- system2(
  file.path(R.home("bin"), "Rscript"),
  c(shQuote(runner), shQuote(repo), shQuote(args[[2L]]), "--gut")
)
quit(status = status)
