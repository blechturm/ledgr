#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("Usage: derive_record.R <record-dir>")
record <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
summary <- utils::read.csv(file.path(record, "arm_summary.csv"), stringsAsFactors = FALSE)
dirs <- c(C = "arm_c", D_SHARE = "arm_d_share", D_REBUILD = "arm_d_rebuild")
summary$in_process_parent_peak_wset <- vapply(summary$arm, function(arm) {
  x <- utils::read.csv(file.path(record, dirs[[arm]], "retention.csv"))
  max(x$wset_bytes)
}, numeric(1))
summary$in_process_parent_peak_private_commit <- vapply(summary$arm, function(arm) {
  x <- utils::read.csv(file.path(record, dirs[[arm]], "retention.csv"))
  max(x$private_commit_bytes)
}, numeric(1))

if ("tree_peak_wset_sum" %in% names(summary)) {
  summary$sampled_parent_daemons_peak_wset <- summary$tree_peak_wset_sum
  summary$tree_peak_wset_sum <- NULL
}
if ("tree_peak_private_commit_sum" %in% names(summary)) {
  summary$sampled_parent_daemons_peak_private_commit <-
    summary$tree_peak_private_commit_sum
  summary$tree_peak_private_commit_sum <- NULL
}

samples <- utils::read.csv(
  file.path(record, "process_samples.csv"), stringsAsFactors = FALSE
)
round_gaps <- vapply(summary$arm, function(arm) {
  meta <- utils::read.csv(
    file.path(record, dirs[[arm]], "arm_meta.csv"), stringsAsFactors = FALSE
  )
  x <- samples[
    samples$arm == arm & samples$epoch >= meta$start_epoch[[1L]] &
      samples$epoch <= meta$end_epoch[[1L]], , drop = FALSE
  ]
  epochs <- vapply(split(x$epoch, x$sample_id), stats::median, numeric(1))
  gaps <- if (length(epochs) > 1L) diff(epochs) else NA_real_
  c(interval = stats::median(gaps), maximum = max(gaps))
}, numeric(2))
summary$sample_round_interval_sec <- round_gaps["interval", ]
summary$max_sample_gap_sec <- round_gaps["maximum", ]
summary$effective_sample_interval_sec <- NULL
summary$peak_promise_handle_object_bytes <- NULL
summary_order <- c(
  "arm", "status", "exit_status", "n_bars", "n_instruments", "n_pulses",
  "n_candidates", "workers", "sweep_wall_sec", "warmup_sec", "share_sec",
  "stage_sec", "submit_sec", "collect_sec", "shared_regular_bytes",
  "shared_wire_bytes", "shared_region_count", "sample_round_interval_sec",
  "max_sample_gap_sec", "parent_peak_wset", "parent_peak_private_commit",
  "daemon_peak_wset_sum", "daemon_peak_private_commit_sum",
  "sampled_parent_daemons_peak_wset",
  "sampled_parent_daemons_peak_private_commit",
  "in_process_parent_peak_wset", "in_process_parent_peak_private_commit",
  "after_stage_private", "after_submit_private", "after_collect_private",
  "after_drop_promises_private", "peak_collected_result_object_bytes"
)
summary <- summary[c(summary_order, setdiff(names(summary), summary_order))]
utils::write.csv(summary, file.path(record, "arm_summary.csv"), row.names = FALSE, na = "")

verify_dirs <- c(D_SHARE = "arm_d_share_verify", D_REBUILD = "arm_d_rebuild_verify")
verify_input <- lapply(verify_dirs, function(dir) {
  meta <- utils::read.csv(file.path(record, dir, "arm_meta.csv"))
  if (nrow(meta) != 1L || !isTRUE(meta$verify[[1L]])) {
    stop("Raw verification arm is not marked `verify = TRUE`: ", dir)
  }
  reconstruction <- utils::read.csv(file.path(record, dir, "reconstruction.csv"))
  fields <- utils::read.csv(file.path(record, dir, "payload_map.csv"))$field
  list(candidates = reconstruction$candidate_id, fields = fields)
})
path <- file.path(record, "reconstruction.csv")
x <- utils::read.csv(path, stringsAsFactors = FALSE)
x$verified <- vapply(seq_len(nrow(x)), function(i) {
  arm <- x$arm[[i]]
  arm %in% names(verify_input) &&
    x$candidate_id[[i]] %in% verify_input[[arm]]$candidates
}, logical(1))
x$fields_compared <- vapply(seq_len(nrow(x)), function(i) {
  length(verify_input[[x$arm[[i]]]]$fields)
}, integer(1))
if (!all(x$verified)) stop("Aggregate reconstruction lacks raw verified input.")
x <- x[c(intersect(c("arm", "candidate_id", "exact"), names(x)),
         "verified", "fields_compared", "mismatched_fields")]
utils::write.csv(x, path, row.names = FALSE, na = "")

environment_path <- file.path(record, "environment.csv")
environment <- utils::read.csv(environment_path, stringsAsFactors = FALSE)
environment$value[environment$field == "memory_note"] <- paste(
  "Sampled population is the parent plus recorded mirai daemons, not the",
  "dispatcher; working-set sums may double-count shared pages and private",
  "commit is not PSS or unique RSS; sampled peaks are lower bounds"
)
utils::write.csv(environment, environment_path, row.names = FALSE, na = "")
