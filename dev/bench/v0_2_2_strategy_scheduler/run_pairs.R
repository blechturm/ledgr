args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 6L) {
  stop(paste(
    "Usage: run_pairs.R <ledgr_src> <snapshot> <snapshot_hash>",
    "<private_work_dir> <out_dir> <acquisition_commit>"
  ), call. = FALSE)
}
dir.create(args[[5L]], recursive = TRUE, showWarnings = FALSE)
rscript <- file.path(R.home("bin"), "Rscript.exe")
file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(file_arg) != 1L) stop("Could not resolve the benchmark runner path.", call. = FALSE)
script <- normalizePath(sub("^--file=", "", file_arg), winslash = "/", mustWork = TRUE)
runner <- file.path(dirname(script), "run_arm.R")
orders <- list(c("manual", "scheduled"), c("scheduled", "manual"), c("manual", "scheduled"))
commands <- character(length(orders) * 2L)
command_index <- 0L
for (pair in seq_along(orders)) {
  for (order_in_pair in 1:2) {
    arm <- orders[[pair]][[order_in_pair]]
    arm_args <- c(args[1:5], pair, order_in_pair, arm)
    command_index <- command_index + 1L
    commands[[command_index]] <- paste(
      shQuote(rscript),
      shQuote(runner),
      paste(shQuote(arm_args), collapse = " ")
    )
    status <- system2(rscript, c(runner, arm_args), stdout = "", stderr = "")
    if (!identical(status, 0L)) stop("Scheduler H1 arm failed: ", arm, " pair ", pair, call. = FALSE)
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
cat("LEDGR_SCHEDULER_PAIRS_OK\n")
