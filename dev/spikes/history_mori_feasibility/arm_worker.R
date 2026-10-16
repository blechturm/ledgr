#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[[1L]]), winslash = "/")
source(file.path(dirname(script_path), "common.R"), local = globalenv())
source(file.path(dirname(script_path), "evaluators.R"), local = globalenv())
opt <- e0_parse_args(args, list(
  arm = "C", preset = "smoke", `package-root` = ".",
  `out-dir` = tempfile("e1-arm-"), gut = "none", verify = "false"
))
arm <- toupper(opt$arm)
if (!arm %in% c("C", "D_SHARE", "D_REBUILD")) {
  stop("`arm` must be C, D_SHARE, or D_REBUILD.", call. = FALSE)
}
verify <- identical(tolower(opt$verify), "true")
package_root <- normalizePath(opt$`package-root`, winslash = "/", mustWork = TRUE)
out_dir <- normalizePath(opt$`out-dir`, winslash = "/", mustWork = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

e0_load_ledgr(package_root)
.libPaths(e0_lib_paths())
if (!requireNamespace("mori", quietly = TRUE)) stop("mori is required.")
spec <- e0_spec(opt$preset)
fixture <- e0_fixture(spec, file.path(out_dir, "fixture"))
on.exit({
  try(ledgr_snapshot_close(fixture$snapshot), silent = TRUE)
  try(unlink(fixture$db_path), silent = TRUE)
}, add = TRUE)
snapshot_info <- ledgr_snapshot_info(fixture$snapshot)

warm_grid <- ledgr_param_grid(
  warmup = list(n = spec$candidate_n[[1L]], lookback = spec$lookback, invested = 0.95)
)
warm_start <- proc.time()[["elapsed"]]
warm_result <- ledgr_sweep(fixture$experiment, warm_grid, seed = 1601L, workers = 1L)
warmup_sec <- proc.time()[["elapsed"]] - warm_start
stopifnot(identical(warm_result$status, "DONE"))
rm(warm_result)
invisible(gc())

capture <- new.env(parent = emptyenv())
capture$stage_sec <- 0
capture$share_sec <- 0
capture$pid_probe_sec <- 0
capture$submit_sec <- 0
capture$collect_sec <- 0
capture$daemon_pids <- integer()
capture$daemon_pid_path <- file.path(out_dir, "daemon_pids.csv")
capture$retention <- data.frame()
capture$transfer <- data.frame()
capture$shared_state <- e1_empty_shared_state()
capture$reconstruction <- data.frame(
  candidate_id = character(), exact = logical(), mismatched_fields = character(),
  stringsAsFactors = FALSE
)
capture$shared_wire_bytes <- 0
capture$shared_regular_bytes <- 0
capture$mori_fields <- character()
capture$rebuild_fields <- character()
capture$shared_names <- character()

ns <- asNamespace("ledgr")
task_name <- "ledgr_sweep_candidate_tasks"
task_original <- get(task_name, envir = ns, inherits = FALSE)
unlockBinding(task_name, ns)
assign(task_name, function(...) {
  tasks <- task_original(...)
  capture$tasks <- tasks
  tasks
}, envir = ns)
lockBinding(task_name, ns)
on.exit({
  unlockBinding(task_name, ns)
  assign(task_name, task_original, envir = ns)
  lockBinding(task_name, ns)
}, add = TRUE)

parallel_name <- "ledgr_sweep_eval_candidate_tasks_parallel"
parallel_original <- get(parallel_name, envir = ns, inherits = FALSE)
replacement <- if (identical(arm, "C")) {
  function(tasks, workers, ...) e1_parallel_eval_c(tasks, workers, capture)
} else {
  function(tasks, workers, ...) {
    e1_parallel_eval_mori(
      tasks, workers, capture, mode = arm, verify = verify, gut = opt$gut
    )
  }
}
unlockBinding(parallel_name, ns)
assign(parallel_name, replacement, envir = ns)
lockBinding(parallel_name, ns)
on.exit({
  unlockBinding(parallel_name, ns)
  assign(parallel_name, parallel_original, envir = ns)
  lockBinding(parallel_name, ns)
}, add = TRUE)

pre_point <- e1_memory_point("before_sweep")
start_epoch <- as.numeric(Sys.time())
start_elapsed <- proc.time()[["elapsed"]]
error <- NULL
out <- tryCatch(
  ledgr_sweep(
    fixture$experiment, fixture$grid, seed = 1601L, workers = spec$workers
  ),
  error = function(e) {
    error <<- e
    NULL
  }
)
end_elapsed <- proc.time()[["elapsed"]]
end_epoch <- as.numeric(Sys.time())
post_point <- e1_memory_point("after_sweep")

tasks <- capture$tasks
e0_write_csv(e0_payload_map(tasks), file.path(out_dir, "payload_map.csv"))
e0_write_csv(
  e0_payload_summary(tasks, spec$workers), file.path(out_dir, "payload_summary.csv")
)
retention <- if (nrow(capture$retention)) {
  rbind(pre_point, capture$retention, post_point)
} else rbind(pre_point, post_point)
e0_write_csv(retention, file.path(out_dir, "retention.csv"))
e0_write_csv(data.frame(pid = capture$daemon_pids), file.path(out_dir, "daemon_pids.csv"))
e0_write_csv(capture$transfer, file.path(out_dir, "result_transfer.csv"))
e0_write_csv(capture$shared_state, file.path(out_dir, "shared_state.csv"))
e0_write_csv(capture$reconstruction, file.path(out_dir, "reconstruction.csv"))

identity <- if (is.null(out)) {
  data.frame(
    arm = character(), candidate_id = character(), status = character(),
    final_equity = character(), total_return = character(), n_trades = integer(),
    execution_seed = integer(), snapshot_hash = character(),
    strategy_hash = character(), reproduction_key_hash = character(),
    stringsAsFactors = FALSE
  )
} else e1_result_identity(out, arm)
e0_write_csv(identity, file.path(out_dir, "result_identity.csv"))

meta <- data.frame(
  arm = arm, preset = spec$preset, verify = verify, process_id = Sys.getpid(),
  workers = spec$workers, n_instruments = spec$n_inst,
  n_bars = nrow(fixture$inputs$bars),
  n_pulses = sum(fixture$inputs$sessions$status == "open"),
  n_candidates = length(spec$candidate_n), lookback = spec$lookback,
  start_epoch = start_epoch, end_epoch = end_epoch,
  sweep_wall_sec = end_elapsed - start_elapsed, warmup_sec = warmup_sec,
  share_sec = capture$share_sec, stage_sec = capture$stage_sec,
  pid_probe_sec = capture$pid_probe_sec, submit_sec = capture$submit_sec,
  collect_sec = capture$collect_sec,
  shared_regular_bytes = capture$shared_regular_bytes,
  shared_wire_bytes = capture$shared_wire_bytes,
  shared_region_count = length(capture$shared_names),
  mori_fields = paste(capture$mori_fields, collapse = ";"),
  rebuild_fields = paste(capture$rebuild_fields, collapse = ";"),
  snapshot_hash = snapshot_info$snapshot_hash[[1L]],
  status = if (is.null(error)) "DONE" else "FAILED",
  error_class = if (is.null(error)) "" else paste(class(error), collapse = ";"),
  error_message = if (is.null(error)) "" else conditionMessage(error),
  gut = opt$gut, stringsAsFactors = FALSE
)
e0_write_csv(meta, file.path(out_dir, "arm_meta.csv"))

if (!is.null(error)) {
  message("E1 arm ", arm, " failed: ", conditionMessage(error))
  quit(status = 1L)
}
message("E1 arm ", arm, " complete in ", sprintf("%.3f", meta$sweep_wall_sec), " s")
