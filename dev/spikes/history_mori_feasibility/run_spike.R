#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[[1L]]), winslash = "/")
source(file.path(dirname(script_path), "common.R"), local = globalenv())
opt <- e0_parse_args(commandArgs(trailingOnly = TRUE), list(
  preset = "smoke", `package-root` = ".",
  `out-dir` = tempfile("e1-run-"), gut = "none"
))
.libPaths(e0_lib_paths())
package_root <- normalizePath(opt$`package-root`, winslash = "/", mustWork = TRUE)
out_dir <- normalizePath(opt$`out-dir`, winslash = "/", mustWork = FALSE)
if (dir.exists(out_dir) && length(list.files(out_dir, all.files = TRUE, no.. = TRUE))) {
  stop("`out-dir` must be absent or empty.", call. = FALSE)
}
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
rscript <- e0_rscript()
arm_worker <- file.path(dirname(script_path), "arm_worker.R")
sample_target <- if (identical(opt$preset, "record")) 0.20 else 0.10

# Build/load the package DLL once before any measured arm, as in E0.
preflight_dir <- file.path(out_dir, "preflight")
dir.create(preflight_dir, recursive = TRUE, showWarnings = FALSE)
preflight <- processx::run(
  rscript,
  c(
    file.path(dirname(dirname(script_path)), "history_mirai_payload_attribution", "preflight_worker.R"),
    "--package-root", package_root, "--out-dir", preflight_dir
  ),
  stdout = file.path(preflight_dir, "worker.log"), stderr = "2>&1",
  error_on_status = FALSE
)
if (preflight$status != 0L) stop("DLL preflight failed.", call. = FALSE)

safe <- function(expr, default) tryCatch(expr, error = function(e) default)
sample_pids <- function(pids, root_pid, sample_id, arm) {
  rows <- lapply(unique(pids), function(pid) {
    handle <- safe(ps::ps_handle(pid), NULL)
    if (is.null(handle)) return(NULL)
    memory <- safe(ps::ps_memory_info(handle), NULL)
    if (is.null(memory)) return(NULL)
    data.frame(
      arm = arm, sample_id = sample_id, epoch = as.numeric(Sys.time()), pid = pid,
      is_parent = identical(as.integer(pid), as.integer(root_pid)),
      wset_bytes = unname(memory[["wset"]]),
      private_commit_bytes = unname(memory[["mem_private"]]),
      process_name = safe(ps::ps_name(handle), "unknown"), stringsAsFactors = FALSE
    )
  })
  rows <- Filter(Negate(is.null), rows)
  if (!length(rows)) NULL else do.call(rbind, rows)
}

run_arm <- function(arm, verify = FALSE, suffix = "") {
  key <- paste0(tolower(arm), suffix)
  arm_dir <- file.path(out_dir, paste0("arm_", key))
  dir.create(arm_dir, recursive = TRUE, showWarnings = FALSE)
  proc <- processx::process$new(
    rscript,
    c(
      arm_worker, "--arm", arm, "--preset", opt$preset,
      "--package-root", package_root, "--out-dir", arm_dir,
      "--gut", if (arm == "D_REBUILD") opt$gut else "none",
      "--verify", tolower(as.character(verify))
    ),
    stdout = file.path(arm_dir, "worker.log"), stderr = "2>&1",
    cleanup_tree = TRUE
  )
  root_pid <- proc$get_pid()
  samples <- list()
  known_pids <- root_pid
  sample_id <- 0L
  pid_file <- file.path(arm_dir, "daemon_pids.csv")
  while (proc$is_alive()) {
    if (file.exists(pid_file)) {
      known_pids <- unique(c(
        known_pids,
        safe(utils::read.csv(pid_file, stringsAsFactors = FALSE)$pid, integer())
      ))
    }
    sample_id <- sample_id + 1L
    samples[[sample_id]] <- sample_pids(known_pids, root_pid, sample_id, arm)
    Sys.sleep(sample_target)
  }
  proc$wait()
  unlink(file.path(arm_dir, "fixture"), recursive = TRUE, force = TRUE)
  rows <- Filter(Negate(is.null), samples)
  list(
    arm = arm, key = key, dir = arm_dir, status = proc$get_exit_status(),
    root_pid = root_pid,
    samples = if (length(rows)) do.call(rbind, rows) else data.frame()
  )
}

# Exact task reconstruction is a separate, unmeasured run so full expected
# tasks do not pollute the binding memory comparison.
verify_runs <- lapply(c("D_SHARE", "D_REBUILD"), run_arm, verify = TRUE, suffix = "_verify")
if (any(vapply(verify_runs, function(x) x$status != 0L, logical(1)))) {
  stop("Exact reconstruction run failed.", call. = FALSE)
}
measured <- lapply(c("C", "D_SHARE", "D_REBUILD"), run_arm)
if (any(vapply(measured, function(x) x$status != 0L, logical(1))) && opt$gut == "none") {
  stop("Measured arm failed.", call. = FALSE)
}

raw_samples <- do.call(rbind, lapply(measured, `[[`, "samples"))
e0_write_csv(raw_samples, file.path(out_dir, "process_samples.csv"))

read_arm <- function(run) {
  meta <- utils::read.csv(file.path(run$dir, "arm_meta.csv"), stringsAsFactors = FALSE)
  pids <- utils::read.csv(file.path(run$dir, "daemon_pids.csv"), stringsAsFactors = FALSE)$pid
  samples <- run$samples
  if (nrow(samples)) {
    samples$role <- ifelse(
      samples$is_parent, "parent",
      ifelse(samples$pid %in% pids, "daemon", "dispatcher_or_other")
    )
  }
  list(
    meta = meta, samples = samples,
    retention = utils::read.csv(file.path(run$dir, "retention.csv"), stringsAsFactors = FALSE)
  )
}
data <- lapply(measured, read_arm)

peak_sum <- function(samples, column, role = NULL, from = -Inf, to = Inf) {
  if (!nrow(samples)) return(NA_real_)
  keep <- samples$epoch >= from & samples$epoch <= to
  if (!is.null(role)) keep <- keep & samples$role %in% role
  part <- samples[keep, , drop = FALSE]
  if (!nrow(part)) return(NA_real_)
  max(tapply(part[[column]], part$sample_id, sum, na.rm = TRUE), na.rm = TRUE)
}
point <- function(retention, label, column) {
  x <- retention[[column]][retention$label == label]
  if (length(x)) x[[1L]] else NA_real_
}

summary_rows <- lapply(seq_along(measured), function(i) {
  run <- measured[[i]]
  d <- data[[i]]
  meta <- d$meta
  s <- d$samples
  from <- meta$start_epoch[[1L]]
  to <- meta$end_epoch[[1L]]
  epochs <- if (nrow(s)) sort(unique(s$epoch[s$epoch >= from & s$epoch <= to])) else numeric()
  r <- d$retention
  data.frame(
    arm = run$arm, status = meta$status[[1L]], exit_status = run$status,
    n_bars = meta$n_bars[[1L]], n_instruments = meta$n_instruments[[1L]],
    n_pulses = meta$n_pulses[[1L]], n_candidates = meta$n_candidates[[1L]],
    workers = meta$workers[[1L]], sweep_wall_sec = meta$sweep_wall_sec[[1L]],
    warmup_sec = meta$warmup_sec[[1L]], share_sec = meta$share_sec[[1L]],
    stage_sec = meta$stage_sec[[1L]], submit_sec = meta$submit_sec[[1L]],
    collect_sec = meta$collect_sec[[1L]],
    shared_regular_bytes = meta$shared_regular_bytes[[1L]],
    shared_wire_bytes = meta$shared_wire_bytes[[1L]],
    shared_region_count = meta$shared_region_count[[1L]],
    effective_sample_interval_sec = if (length(epochs) > 1L) stats::median(diff(epochs)) else NA_real_,
    max_sample_gap_sec = if (length(epochs) > 1L) max(diff(epochs)) else NA_real_,
    parent_peak_wset = peak_sum(s, "wset_bytes", "parent", from, to),
    parent_peak_private_commit = peak_sum(s, "private_commit_bytes", "parent", from, to),
    daemon_peak_wset_sum = peak_sum(s, "wset_bytes", "daemon", from, to),
    daemon_peak_private_commit_sum = peak_sum(s, "private_commit_bytes", "daemon", from, to),
    tree_peak_wset_sum = peak_sum(s, "wset_bytes", NULL, from, to),
    tree_peak_private_commit_sum = peak_sum(s, "private_commit_bytes", NULL, from, to),
    in_process_parent_peak_wset = max(r$wset_bytes),
    in_process_parent_peak_private_commit = max(r$private_commit_bytes),
    after_stage_private = point(r, "after_stage", "private_commit_bytes"),
    after_submit_private = point(r, "after_submit", "private_commit_bytes"),
    after_collect_private = max(r$private_commit_bytes[grepl("^after_collect_", r$label)], na.rm = TRUE),
    after_drop_promises_private = point(r, "after_drop_promises_gc", "private_commit_bytes"),
    peak_promise_handle_object_bytes = max(r$promise_handle_object_bytes),
    peak_collected_result_object_bytes = max(r$collected_result_object_bytes),
    stringsAsFactors = FALSE
  )
})
arm_summary <- do.call(rbind, summary_rows)
e0_write_csv(arm_summary, file.path(out_dir, "arm_summary.csv"))

identities <- do.call(rbind, lapply(measured, function(run) {
  utils::read.csv(
    file.path(run$dir, "result_identity.csv"), stringsAsFactors = FALSE,
    colClasses = "character"
  )
}))
e0_write_csv(identities, file.path(out_dir, "result_identity.csv"))

transfer <- do.call(rbind, lapply(measured, function(run) {
  x <- utils::read.csv(file.path(run$dir, "result_transfer.csv"), stringsAsFactors = FALSE)
  cbind(arm = run$arm, x, stringsAsFactors = FALSE)
}))
e0_write_csv(transfer, file.path(out_dir, "result_transfer.csv"))

shared_state <- do.call(rbind, lapply(measured[2:3], function(run) {
  x <- utils::read.csv(file.path(run$dir, "shared_state.csv"), stringsAsFactors = FALSE)
  cbind(arm = run$arm, x, stringsAsFactors = FALSE)
}))
e0_write_csv(shared_state, file.path(out_dir, "shared_state.csv"))

reconstruction <- do.call(rbind, lapply(verify_runs, function(run) {
  x <- utils::read.csv(file.path(run$dir, "reconstruction.csv"), stringsAsFactors = FALSE)
  cbind(arm = run$arm, x, stringsAsFactors = FALSE)
}))
e0_write_csv(reconstruction, file.path(out_dir, "reconstruction.csv"))

payload <- utils::read.csv(file.path(measured[[1L]]$dir, "payload_map.csv"), stringsAsFactors = FALSE)
e0_write_csv(payload, file.path(out_dir, "payload_map.csv"))
payload_summary <- utils::read.csv(
  file.path(measured[[1L]]$dir, "payload_summary.csv"), stringsAsFactors = FALSE
)
e0_write_csv(payload_summary, file.path(out_dir, "payload_summary.csv"))

# Lifecycle runs are independent so deliberate interruption cannot contaminate
# the binding arm processes.
life_dir <- file.path(out_dir, "lifecycle")
life <- processx::run(
  rscript,
  c(file.path(dirname(script_path), "run_lifecycle.R"), "--out-dir", life_dir),
  stdout = file.path(out_dir, "lifecycle.log"), stderr = "2>&1",
  error_on_status = FALSE
)
if (life$status != 0L) stop("Lifecycle probe failed.", call. = FALSE)
file.copy(file.path(life_dir, "lifecycle.csv"), file.path(out_dir, "lifecycle.csv"))

environment <- data.frame(
  field = c(
    "created_at_utc", "R", "platform", "mirai", "mori", "ps", "processx",
    "sample_target_sec", "memory_note", "gut"
  ),
  value = c(
    format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), R.version.string,
    R.version$platform, as.character(utils::packageVersion("mirai")),
    as.character(utils::packageVersion("mori")), as.character(utils::packageVersion("ps")),
    as.character(utils::packageVersion("processx")), sample_target,
    paste(
      "Windows working-set sums may double-count shared pages; private commit",
      "is not PSS or unique RSS; sampled peaks are lower bounds"
    ), opt$gut
  ), stringsAsFactors = FALSE
)
e0_write_csv(environment, file.path(out_dir, "environment.csv"))

cat("HISTORY_E1_RUN_OK preset=", opt$preset, " arms=3 candidates=4\n", sep = "")
