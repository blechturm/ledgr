# The checker must reject a candidate that restores a transient SHA-256 seal.

.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
scratch <- tempfile("history-manifestation-gut-")
dir.create(scratch)
on.exit(unlink(scratch, recursive = TRUE, force = TRUE), add = TRUE)

commit <- Sys.getenv("LEDGR_PRODUCT_COMMIT")
if (!nzchar(commit)) stop("Set LEDGR_PRODUCT_COMMIT before running the gut demo.")
rscript <- file.path(R.home("bin"), "Rscript.exe")
old_commit <- Sys.getenv("LEDGR_PRODUCT_COMMIT", unset = NA_character_)
old_gut <- Sys.getenv("LEDGR_HISTORY_SPIKE_GUT", unset = NA_character_)
Sys.setenv(LEDGR_PRODUCT_COMMIT = commit, LEDGR_HISTORY_SPIKE_GUT = "hash")
on.exit({
  if (is.na(old_commit)) Sys.unsetenv("LEDGR_PRODUCT_COMMIT") else
    Sys.setenv(LEDGR_PRODUCT_COMMIT = old_commit)
  if (is.na(old_gut)) Sys.unsetenv("LEDGR_HISTORY_SPIKE_GUT") else
    Sys.setenv(LEDGR_HISTORY_SPIKE_GUT = old_gut)
}, add = TRUE)
runner <- processx::run(
  rscript,
  c("dev/spikes/history-manifestation/spike_runner.R", scratch),
  timeout = 120000,
  error_on_status = FALSE,
  echo = FALSE
)
if (!identical(runner$status, 0L)) stop("Gutted runner failed before checking.")
Sys.unsetenv("LEDGR_HISTORY_SPIKE_GUT")
checker <- processx::run(
  rscript,
  c("dev/spikes/history-manifestation/spike_checker.R", scratch, "--check-only"),
  timeout = 30000,
  error_on_status = FALSE,
  echo = FALSE
)
if (identical(checker$status, 0L)) {
  stop("Checker accepted the restored transient SHA-256 seal.")
}
cat("HISTORY_MANIFESTATION_GUT_DETECTED path=transient_sha256\n")
