args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 6L) {
  stop(paste(
    "Usage: run_diagnostic_parity.R <ledgr_src> <snapshot> <snapshot_hash>",
    "<private_work_dir> <out_dir> <acquisition_commit>"
  ), call. = FALSE)
}

dir.create(args[[5L]], recursive = TRUE, showWarnings = FALSE)
rscript <- file.path(R.home("bin"), "Rscript.exe")
file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(file_arg) != 1L) {
  stop("Could not resolve the diagnostic runner path.", call. = FALSE)
}
script <- normalizePath(
  sub("^--file=", "", file_arg),
  winslash = "/",
  mustWork = TRUE
)
runner <- file.path(dirname(script), "run_arm.R")
arms <- c("manual", "scheduled")
commands <- character(length(arms))

for (order_in_pair in seq_along(arms)) {
  arm_args <- c(args[1:5], 1L, order_in_pair, arms[[order_in_pair]])
  commands[[order_in_pair]] <- paste(
    shQuote(rscript),
    shQuote(runner),
    paste(shQuote(arm_args), collapse = " ")
  )
  status <- system2(rscript, c(runner, arm_args), stdout = "", stderr = "")
  if (!identical(status, 0L)) {
    stop("Scheduler diagnostic arm failed: ", arms[[order_in_pair]], call. = FALSE)
  }
}

utils::write.csv(
  data.frame(
    acquisition_commit = args[[6L]],
    command = commands,
    r_version = R.version.string,
    host = Sys.info()[["nodename"]],
    stringsAsFactors = FALSE
  ),
  file.path(args[[5L]], "record_meta.csv"),
  row.names = FALSE
)
cat("LEDGR_SCHEDULER_DIAGNOSTIC_RECORD_OK\n")
