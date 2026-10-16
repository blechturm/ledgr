#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[[1L]]), winslash = "/")
source(file.path(dirname(script_path), "common.R"), local = globalenv())
opt <- e0_parse_args(commandArgs(trailingOnly = TRUE), list(
  preset = "smoke", `package-root` = ".",
  `out-dir` = tempfile("e0-run-"), gut = "none"
))
.libPaths(e0_lib_paths())
for (pkg in c("processx", "ps")) {
  if (!requireNamespace(pkg, quietly = TRUE)) stop("Package required: ", pkg)
}
package_root <- normalizePath(opt$`package-root`, winslash = "/", mustWork = TRUE)
out_dir <- normalizePath(opt$`out-dir`, winslash = "/", mustWork = FALSE)
if (dir.exists(out_dir) && length(list.files(out_dir, all.files = TRUE, no.. = TRUE))) {
  stop("`out-dir` must be absent or empty.", call. = FALSE)
}
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
worker <- file.path(dirname(script_path), "arm_worker.R")
preflight_worker <- file.path(dirname(script_path), "preflight_worker.R")
rscript <- e0_rscript()
sample_target <- if (identical(opt$preset, "record")) 0.20 else 0.10

preflight_dir <- file.path(out_dir, "preflight")
dir.create(preflight_dir, recursive = TRUE, showWarnings = FALSE)
preflight_log <- file.path(preflight_dir, "worker.log")
preflight_started <- as.numeric(Sys.time())
preflight <- processx::run(
  rscript,
  c(
    preflight_worker, "--package-root", package_root,
    "--out-dir", preflight_dir
  ),
  stdout = preflight_log, stderr = "2>&1", error_on_status = FALSE
)
preflight_ended <- as.numeric(Sys.time())
if (!identical(preflight$status, 0L)) {
  stop("Compiled-DLL preflight failed; see ", preflight_log, call. = FALSE)
}
preflight_meta <- utils::read.csv(
  file.path(preflight_dir, "preflight.csv"), stringsAsFactors = FALSE
)
preflight_meta$process_elapsed_sec <- preflight_ended - preflight_started
e0_write_csv(preflight_meta, file.path(out_dir, "preflight.csv"))

safe <- function(expr, default) tryCatch(expr, error = function(e) default)

sample_pids <- function(pids, root_pid, sample_id, arm) {
  rows <- lapply(unique(pids), function(pid) {
    handle <- safe(ps::ps_handle(pid), NULL)
    if (is.null(handle)) return(NULL)
    memory <- safe(ps::ps_memory_info(handle), NULL)
    if (is.null(memory)) return(NULL)
    data.frame(
      arm = arm,
      sample_id = sample_id,
      epoch = as.numeric(Sys.time()),
      pid = pid,
      is_parent = identical(as.integer(pid), as.integer(root_pid)),
      wset_bytes = unname(memory[["wset"]]),
      private_commit_bytes = unname(memory[["mem_private"]]),
      process_name = safe(ps::ps_name(handle), "unknown"),
      stringsAsFactors = FALSE
    )
  })
  rows <- Filter(Negate(is.null), rows)
  if (!length(rows)) NULL else do.call(rbind, rows)
}

run_arm <- function(arm) {
  arm_dir <- file.path(out_dir, paste0("arm_", tolower(arm)))
  dir.create(arm_dir, recursive = TRUE, showWarnings = FALSE)
  log_path <- file.path(arm_dir, "worker.log")
  arm_gut <- if (identical(arm, "C")) opt$gut else "none"
  proc <- processx::process$new(
    rscript,
    c(
      worker, "--arm", arm, "--preset", opt$preset,
      "--package-root", package_root, "--out-dir", arm_dir,
      "--gut", arm_gut
    ),
    stdout = log_path,
    stderr = "2>&1",
    cleanup_tree = TRUE
  )
  root_pid <- proc$get_pid()
  started <- as.numeric(Sys.time())
  samples <- list()
  sample_id <- 0L
  known_pids <- root_pid
  live_pid_file <- file.path(arm_dir, "daemon_pids.csv")
  while (proc$is_alive()) {
    if (file.exists(live_pid_file)) {
      daemon_pids <- safe(
        utils::read.csv(live_pid_file, stringsAsFactors = FALSE)$pid,
        integer()
      )
      known_pids <- unique(c(known_pids, daemon_pids))
    }
    sample_id <- sample_id + 1L
    samples[[sample_id]] <- sample_pids(known_pids, root_pid, sample_id, arm)
    Sys.sleep(sample_target)
  }
  proc$wait()
  ended <- as.numeric(Sys.time())
  fixture_dir <- file.path(arm_dir, "fixture")
  if (dir.exists(fixture_dir)) {
    unlink(fixture_dir, recursive = TRUE, force = TRUE)
  }
  rows <- Filter(Negate(is.null), samples)
  list(
    arm = arm,
    root_pid = root_pid,
    exit_status = proc$get_exit_status(),
    process_elapsed_sec = ended - started,
    samples = if (length(rows)) do.call(rbind, rows) else data.frame(),
    arm_dir = arm_dir
  )
}

runs <- lapply(c("A", "B", "C"), run_arm)
raw_samples <- do.call(rbind, lapply(runs, `[[`, "samples"))
e0_write_csv(raw_samples, file.path(out_dir, "process_samples.csv"))

read_arm <- function(run) {
  meta <- utils::read.csv(file.path(run$arm_dir, "arm_meta.csv"), stringsAsFactors = FALSE)
  daemon_file <- file.path(run$arm_dir, "daemon_pids.csv")
  daemon_pids <- if (file.exists(daemon_file)) {
    utils::read.csv(daemon_file, stringsAsFactors = FALSE)$pid
  } else integer()
  samples <- run$samples
  if (nrow(samples)) {
    samples$role <- ifelse(
      samples$is_parent, "parent",
      ifelse(samples$pid %in% daemon_pids, "daemon", "dispatcher_or_other")
    )
  }
  retention <- utils::read.csv(
    file.path(run$arm_dir, "retention.csv"), stringsAsFactors = FALSE
  )
  list(meta = meta, samples = samples, daemon_pids = daemon_pids, retention = retention)
}
arm_data <- lapply(runs, read_arm)

peak_sum <- function(samples, column, role = NULL, from = -Inf, to = Inf) {
  if (!nrow(samples)) return(NA_real_)
  keep <- samples$epoch >= from & samples$epoch <= to
  if (!is.null(role)) keep <- keep & samples$role %in% role
  part <- samples[keep, , drop = FALSE]
  if (!nrow(part)) return(NA_real_)
  sums <- tapply(part[[column]], part$sample_id, sum, na.rm = TRUE)
  max(sums, na.rm = TRUE)
}

peak_one <- function(samples, column, role, from, to) {
  part <- samples[
    samples$epoch >= from & samples$epoch <= to & samples$role == role,
    , drop = FALSE
  ]
  if (!nrow(part)) return(NA_real_)
  max(part[[column]], na.rm = TRUE)
}

summaries <- lapply(seq_along(runs), function(i) {
  run <- runs[[i]]
  data <- arm_data[[i]]
  meta <- data$meta
  s <- data$samples
  from <- meta$start_epoch[[1L]]
  to <- meta$end_epoch[[1L]]
  sample_epochs <- if (nrow(s)) {
    sort(tapply(s$epoch, s$sample_id, min))
  } else numeric()
  interval <- if (length(sample_epochs) > 1L) {
    stats::median(diff(sample_epochs))
  } else NA_real_
  sweep_epochs <- sample_epochs[sample_epochs >= from & sample_epochs <= to]
  sweep_blackout <- if (length(sweep_epochs)) {
    max(diff(c(from, sweep_epochs, to)))
  } else {
    to - from
  }
  daemon_epochs <- if (nrow(s)) {
    unique(s$epoch[s$role == "daemon" & s$epoch >= from & s$epoch <= to])
  } else {
    numeric()
  }
  daemon_blackout <- if (length(daemon_epochs)) {
    max(diff(c(from, sort(daemon_epochs), to)))
  } else {
    NA_real_
  }
  retention <- data$retention
  point <- function(label, column = "private_commit_bytes") {
    value <- retention[[column]][retention$label == label]
    if (length(value)) value[[1L]] else NA_real_
  }
  phase_baseline <- if (run$arm == "C") point("after_stage") else point("before_submit")
  after_submit <- point("after_submit")
  data.frame(
    arm = run$arm,
    status = meta$status[[1L]],
    exit_status = run$exit_status,
    n_bars = meta$n_bars[[1L]],
    n_instruments = meta$n_instruments[[1L]],
    n_pulses = meta$n_pulses[[1L]],
    n_candidates = meta$n_candidates[[1L]],
    workers = meta$workers[[1L]],
    sweep_wall_sec = meta$sweep_wall_sec[[1L]],
    warmup_sec = meta$warmup_sec[[1L]],
    process_elapsed_sec = run$process_elapsed_sec,
    stage_sec = meta$stage_sec[[1L]],
    pid_probe_sec = meta$pid_probe_sec[[1L]],
    submit_sec = meta$submit_sec[[1L]],
    collect_sec = meta$collect_sec[[1L]],
    stage_cleanup_sec = meta$stage_cleanup_sec[[1L]],
    sample_count = length(unique(s$sample_id)),
    effective_sample_interval_sec = interval,
    max_sample_gap_sec = if (length(sample_epochs) > 1L) max(diff(sample_epochs)) else NA_real_,
    sweep_max_blackout_sec = sweep_blackout,
    daemon_max_blackout_sec = daemon_blackout,
    in_process_parent_peak_wset = max(retention$wset_bytes),
    in_process_parent_peak_private_commit = max(retention$private_commit_bytes),
    parent_before_sweep_private = point("before_sweep"),
    parent_before_stage_private = point("before_stage"),
    parent_after_stage_private = point("after_stage"),
    parent_after_submit_private = after_submit,
    parent_stage_private_delta = point("after_stage") - point("before_stage"),
    parent_submit_private_delta = after_submit - phase_baseline,
    parent_total_to_after_submit_private_delta = after_submit - point("before_sweep"),
    sweep_parent_peak_wset = peak_one(s, "wset_bytes", "parent", from, to),
    sweep_parent_peak_private_commit = peak_one(
      s, "private_commit_bytes", "parent", from, to
    ),
    sweep_daemon_peak_wset_sum = peak_sum(s, "wset_bytes", "daemon", from, to),
    sweep_daemon_peak_private_commit_sum = peak_sum(
      s, "private_commit_bytes", "daemon", from, to
    ),
    sweep_tree_peak_wset_sum = peak_sum(s, "wset_bytes", NULL, from, to),
    sweep_tree_peak_private_commit_sum = peak_sum(
      s, "private_commit_bytes", NULL, from, to
    ),
    whole_tree_peak_wset_sum = peak_sum(s, "wset_bytes"),
    whole_tree_peak_private_commit_sum = peak_sum(s, "private_commit_bytes"),
    stringsAsFactors = FALSE
  )
})
arm_summary <- do.call(rbind, summaries)
e0_write_csv(arm_summary, file.path(out_dir, "arm_summary.csv"))

identities <- do.call(rbind, lapply(runs, function(run) {
  utils::read.csv(
    file.path(run$arm_dir, "result_identity.csv"),
    stringsAsFactors = FALSE,
    colClasses = "character"
  )
}))
e0_write_csv(identities, file.path(out_dir, "result_identity.csv"))

payload_by_arm <- do.call(rbind, lapply(runs, function(run) {
  x <- utils::read.csv(
    file.path(run$arm_dir, "payload_map.csv"), stringsAsFactors = FALSE
  )
  cbind(arm = run$arm, x, stringsAsFactors = FALSE)
}))
b_map <- payload_by_arm[payload_by_arm$arm == "B", names(payload_by_arm) != "arm"]
c_map <- payload_by_arm[payload_by_arm$arm == "C", names(payload_by_arm) != "arm"]
a_map <- payload_by_arm[payload_by_arm$arm == "A", names(payload_by_arm) != "arm"]
rownames(a_map) <- NULL
rownames(b_map) <- NULL
rownames(c_map) <- NULL
if (!identical(a_map, b_map)) stop("Sequential and current payload maps differ.")
if (!identical(b_map, c_map)) stop("Current and staged payload maps differ.")
e0_write_csv(payload_by_arm, file.path(out_dir, "payload_map_by_arm.csv"))
e0_write_csv(b_map, file.path(out_dir, "payload_map.csv"))
payload_summary_b <- utils::read.csv(
  file.path(runs[[2L]]$arm_dir, "payload_summary.csv"), stringsAsFactors = FALSE
)
e0_write_csv(payload_summary_b, file.path(out_dir, "payload_summary.csv"))

shape <- unique(arm_summary[c(
  "n_bars", "n_instruments", "n_pulses", "n_candidates"
)])
if (nrow(shape) != 1L) stop("Fixture shape changed between arms.", call. = FALSE)
shape$preset <- opt$preset
shape$requested_workers <- e0_spec(opt$preset)$workers
e0_write_csv(shape, file.path(out_dir, "fixture_shape.csv"))

environment <- data.frame(
  field = c(
    "created_at_utc", "R", "platform", "mirai", "ps", "processx",
    "sample_target_sec", "memory_note", "gut"
  ),
  value = c(
    format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    R.version.string, R.version$platform,
    as.character(utils::packageVersion("mirai")),
    as.character(utils::packageVersion("ps")),
    as.character(utils::packageVersion("processx")),
    sample_target,
    paste(
      "Windows working-set sums may double-count shared pages;",
      "private commit is additive committed private bytes, not unique resident bytes"
    ),
    opt$gut
  ),
  stringsAsFactors = FALSE
)
e0_write_csv(environment, file.path(out_dir, "environment.csv"))

bad <- vapply(runs, function(x) !identical(x$exit_status, 0L), logical(1))
if (any(bad) && identical(opt$gut, "none")) {
  stop("One or more arms failed; see worker logs.", call. = FALSE)
}
message("E0 ", opt$preset, " run written to ", out_dir)
