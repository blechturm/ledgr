#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[[1L]]), winslash = "/")
source(file.path(dirname(script_path), "common.R"), local = globalenv())
opt <- e0_parse_args(commandArgs(trailingOnly = TRUE), list(
  `out-dir` = tempfile("e1-lifecycle-"), summary = "", log = ""
))
.libPaths(e0_lib_paths())
out_dir <- normalizePath(opt$`out-dir`, winslash = "/", mustWork = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
rscript <- e0_rscript()
worker <- file.path(dirname(script_path), "lifecycle_worker.R")

region_absent <- function(path) {
  name <- utils::read.csv(path, stringsAsFactors = FALSE)$name[[1L]]
  tryCatch({
    mori::map_shared(name)
    FALSE
  }, error = function(e) TRUE)
}

region_present <- function(path) {
  name <- utils::read.csv(path, stringsAsFactors = FALSE)$name[[1L]]
  tryCatch({
    mapped <- mori::map_shared(name)
    present <- mori::is_shared(mapped)
    rm(mapped)
    invisible(gc())
    present
  }, error = function(e) FALSE)
}

rows <- list()
for (mode in c("success", "failure")) {
  mode_dir <- file.path(out_dir, mode)
  if (dir.exists(mode_dir)) unlink(mode_dir, recursive = TRUE, force = TRUE)
  dir.create(mode_dir, recursive = TRUE, showWarnings = FALSE)
  run <- processx::run(
    rscript, c(worker, "--mode", mode, "--out-dir", mode_dir),
    stdout = file.path(mode_dir, "worker.log"), stderr = "2>&1",
    error_on_status = FALSE
  )
  rows[[length(rows) + 1L]] <- data.frame(
    mode = mode, exit_status = run$status,
    cleanup_completed = file.exists(file.path(mode_dir, "result.csv")),
    live_mapping_before_termination = NA,
    region_absent = region_absent(file.path(mode_dir, "shared_name.csv")),
    stringsAsFactors = FALSE
  )
}

mode <- "forced_termination"
mode_dir <- file.path(out_dir, mode)
if (dir.exists(mode_dir)) unlink(mode_dir, recursive = TRUE, force = TRUE)
dir.create(mode_dir, recursive = TRUE, showWarnings = FALSE)
proc <- processx::process$new(
  rscript, c(worker, "--mode", mode, "--out-dir", mode_dir),
  stdout = file.path(mode_dir, "worker.log"), stderr = "2>&1",
  cleanup_tree = TRUE
)
deadline <- Sys.time() + 30
while (!file.exists(file.path(mode_dir, "ready")) && proc$is_alive() && Sys.time() < deadline) {
  Sys.sleep(0.1)
}
if (!file.exists(file.path(mode_dir, "ready"))) {
  proc$kill_tree()
  stop("Termination worker did not become ready.", call. = FALSE)
}
live_mapping <- region_present(file.path(mode_dir, "shared_name.csv"))
if (!live_mapping) {
  proc$kill_tree()
  stop("Shared mapping was not live before termination.", call. = FALSE)
}
proc$kill_tree()
proc$wait()
Sys.sleep(0.5)
rows[[length(rows) + 1L]] <- data.frame(
  mode = mode, exit_status = proc$get_exit_status(),
  cleanup_completed = file.exists(file.path(mode_dir, "result.csv")),
  live_mapping_before_termination = live_mapping,
  region_absent = region_absent(file.path(mode_dir, "shared_name.csv")),
  stringsAsFactors = FALSE
)
rows <- do.call(rbind, rows)
e0_write_csv(rows, file.path(out_dir, "lifecycle.csv"))
if (nzchar(opt$summary)) e0_write_csv(rows, opt$summary)
if (!all(rows$region_absent) ||
    !all(rows$cleanup_completed[rows$mode != "forced_termination"]) ||
    !isTRUE(rows$live_mapping_before_termination[rows$mode == "forced_termination"])) {
  stop("Lifecycle cleanup check failed.", call. = FALSE)
}
message <- "HISTORY_E1_LIFECYCLE_OK success failure forced_termination"
if (nzchar(opt$log)) writeLines(message, opt$log, useBytes = TRUE)
cat(message, "\n", sep = "")
