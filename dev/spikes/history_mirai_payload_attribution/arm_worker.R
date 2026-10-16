#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[[1L]]), winslash = "/")
source(file.path(dirname(script_path), "common.R"), local = globalenv())
opt <- e0_parse_args(args, list(
  arm = "A", preset = "smoke", `package-root` = ".",
  `out-dir` = tempfile("e0-arm-"), gut = "none"
))
arm <- toupper(opt$arm)
if (!arm %in% c("A", "B", "C")) stop("`arm` must be A, B or C.", call. = FALSE)
package_root <- normalizePath(opt$`package-root`, winslash = "/", mustWork = TRUE)
out_dir <- normalizePath(opt$`out-dir`, winslash = "/", mustWork = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

e0_load_ledgr(package_root)
spec <- e0_spec(opt$preset)
fixture <- e0_fixture(spec, file.path(out_dir, "fixture"))
on.exit({
  try(ledgr_snapshot_close(fixture$snapshot), silent = TRUE)
  try(unlink(fixture$db_path), silent = TRUE)
}, add = TRUE)
snapshot_info <- ledgr_snapshot_info(fixture$snapshot)

warm_grid <- ledgr_param_grid(
  warmup = list(
    n = spec$candidate_n[[1L]], lookback = spec$lookback, invested = 0.95
  )
)
warm_start <- proc.time()[["elapsed"]]
warm_result <- ledgr_sweep(
  fixture$experiment, warm_grid, seed = 1601L, workers = 1L
)
warmup_sec <- proc.time()[["elapsed"]] - warm_start
if (!identical(warm_result$status, "DONE")) {
  stop("Common warm-up sweep failed.", call. = FALSE)
}
rm(warm_result)
invisible(gc())

capture <- new.env(parent = emptyenv())
capture$stage_sec <- 0
capture$stage_cleanup_sec <- 0
capture$pid_probe_sec <- 0
capture$submit_sec <- 0
capture$collect_sec <- 0
capture$daemon_pids <- integer()
capture$daemon_pid_path <- file.path(out_dir, "daemon_pids.csv")
capture$retention <- list()
capture$reconstruction <- data.frame(
  candidate_id = character(), exact = logical(), field_order_exact = logical(),
  missing_fields = character(), extra_fields = character(),
  stringsAsFactors = FALSE
)

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
if (arm %in% c("B", "C")) {
  replacement <- if (identical(arm, "B")) {
    function(tasks, workers, ...) e0_parallel_eval_current(tasks, workers, capture)
  } else {
    function(tasks, workers, ...) {
      e0_parallel_eval_staged(tasks, workers, capture, gut = opt$gut)
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
}

workers <- if (identical(arm, "A")) 1L else spec$workers
pre_point <- e0_memory_point("before_sweep")
start_epoch <- as.numeric(Sys.time())
start_elapsed <- proc.time()[["elapsed"]]
error <- NULL
out <- tryCatch(
  ledgr_sweep(
    fixture$experiment,
    fixture$grid,
    seed = 1601L,
    workers = workers
  ),
  error = function(e) {
    error <<- e
    NULL
  }
)
end_elapsed <- proc.time()[["elapsed"]]
end_epoch <- as.numeric(Sys.time())
post_point <- e0_memory_point("after_sweep")

tasks <- capture$tasks
if (!is.null(tasks)) {
  e0_write_csv(e0_payload_map(tasks), file.path(out_dir, "payload_map.csv"))
  e0_write_csv(
    e0_payload_summary(tasks, workers), file.path(out_dir, "payload_summary.csv")
  )
}
retention <- if (is.data.frame(capture$retention)) {
  rbind(pre_point, capture$retention, post_point)
} else {
  rbind(pre_point, post_point)
}
e0_write_csv(retention, file.path(out_dir, "retention.csv"))
e0_write_csv(
  data.frame(pid = as.integer(capture$daemon_pids)),
  file.path(out_dir, "daemon_pids.csv")
)
e0_write_csv(capture$reconstruction, file.path(out_dir, "reconstruction.csv"))

if (!is.null(out)) {
  identity <- e0_result_identity(out, arm)
} else {
  identity <- data.frame(
    arm = character(), candidate_id = character(), status = character(),
    final_equity = character(), total_return = character(), n_trades = integer(),
    execution_seed = integer(), snapshot_hash = character(),
    strategy_hash = character(), reproduction_key_hash = character(),
    stringsAsFactors = FALSE
  )
}
e0_write_csv(identity, file.path(out_dir, "result_identity.csv"))

meta <- data.frame(
  arm = arm,
  preset = spec$preset,
  process_id = Sys.getpid(),
  workers = workers,
  n_instruments = spec$n_inst,
  n_bars = nrow(fixture$inputs$bars),
  n_pulses = sum(fixture$inputs$sessions$status == "open"),
  n_candidates = length(spec$candidate_n),
  lookback = spec$lookback,
  start_epoch = start_epoch,
  end_epoch = end_epoch,
  sweep_wall_sec = end_elapsed - start_elapsed,
  warmup_sec = warmup_sec,
  stage_sec = capture$stage_sec,
  pid_probe_sec = capture$pid_probe_sec,
  submit_sec = capture$submit_sec,
  collect_sec = capture$collect_sec,
  stage_cleanup_sec = capture$stage_cleanup_sec,
  snapshot_hash = snapshot_info$snapshot_hash[[1L]],
  status = if (is.null(error)) "DONE" else "FAILED",
  error_class = if (is.null(error)) "" else paste(class(error), collapse = ";"),
  error_message = if (is.null(error)) "" else conditionMessage(error),
  gut = opt$gut,
  stringsAsFactors = FALSE
)
e0_write_csv(meta, file.path(out_dir, "arm_meta.csv"))

if (!is.null(error)) {
  message("E0 arm ", arm, " failed: ", conditionMessage(error))
  quit(status = 1L)
}
message("E0 arm ", arm, " complete in ", sprintf("%.3f", meta$sweep_wall_sec), " s")
