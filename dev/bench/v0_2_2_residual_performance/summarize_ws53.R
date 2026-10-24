# Derive the compact Workstream 53 summary from the committed aggregate rows.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) {
  stop("Usage: summarize_ws53.R <evidence_dir>", call. = FALSE)
}
root <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
steps <- utils::read.csv(file.path(root, "steps.csv"), stringsAsFactors = FALSE)
steps$arm <- sub("_r[123]$", "", steps$tag)
value_median <- function(x) stats::median(as.numeric(x))
rows <- lapply(split(steps, steps$arm), function(x) {
  data.frame(
    arm = x$arm[[1L]],
    repeats = nrow(x),
    elapsed_s = value_median(x$elapsed_s),
    parent_private_mib = value_median(x$parent_peak_private_mib),
    tree_private_mib = value_median(x$parent_plus_daemon_peak_private_mib),
    stringsAsFactors = FALSE
  )
})
summary <- do.call(rbind, rows)
summary <- summary[order(summary$arm), , drop = FALSE]
utils::write.csv(summary, file.path(root, "arm_summary.csv"), row.names = FALSE)

phase_rows <- lapply(steps$tag, function(tag) {
  markers <- utils::read.csv(
    file.path(root, paste0(tag, "__markers.csv")),
    stringsAsFactors = FALSE
  )
  sample_path <- file.path(root, "samples", paste0(tag, ".csv.gz"))
  samples <- utils::read.csv(gzfile(sample_path), stringsAsFactors = FALSE)
  start_label <- if ("run_start" %in% markers$label) "run_start" else "sweep_start"
  end_label <- if ("run_end" %in% markers$label) "run_end" else "sweep_end"
  start <- markers$epoch[markers$label == start_label][[1L]]
  end <- markers$epoch[markers$label == end_label][[1L]]
  bounds <- list(
    setup = c(-Inf, start),
    engine = c(start, end),
    result = c(end, Inf)
  )
  do.call(rbind, lapply(names(bounds), function(phase) {
    rows <- samples$epoch >= bounds[[phase]][[1L]] & samples$epoch <= bounds[[phase]][[2L]]
    part <- samples[rows, , drop = FALSE]
    r_part <- part[part$role %in% c("parent", "daemon"), , drop = FALSE]
    tree_private <- if (nrow(r_part)) {
      max(tapply(r_part$private_bytes, r_part$sample_id, sum)) / 2^20
    } else {
      NA_real_
    }
    data.frame(
      tag = tag,
      phase = phase,
      parent_private_mib = if (nrow(part[part$is_parent, , drop = FALSE])) {
        max(part$private_bytes[part$is_parent]) / 2^20
      } else {
        NA_real_
      },
      tree_private_mib = tree_private,
      stringsAsFactors = FALSE
    )
  }))
})
phase_memory <- do.call(rbind, phase_rows)
utils::write.csv(phase_memory, file.path(root, "phase_memory.csv"), row.names = FALSE)
phase_memory$arm <- sub("_r[123]$", "", phase_memory$tag)
phase_summary <- do.call(rbind, lapply(
  split(phase_memory, list(phase_memory$arm, phase_memory$phase), drop = TRUE),
  function(x) data.frame(
    arm = x$arm[[1L]],
    phase = x$phase[[1L]],
    repeats = nrow(x),
    parent_private_mib = stats::median(x$parent_private_mib, na.rm = TRUE),
    tree_private_mib = stats::median(x$tree_private_mib, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
))
phase_summary <- phase_summary[order(phase_summary$arm, phase_summary$phase), , drop = FALSE]
utils::write.csv(phase_summary, file.path(root, "phase_summary.csv"), row.names = FALSE)

worker <- utils::read.csv(
  file.path(root, "workers", "worker_scaling.csv"),
  stringsAsFactors = FALSE
)
utils::write.csv(
  worker[, c(
    "tag", "workers", "elapsed_s", "effective_interval_s",
    "parent_peak_private_mib", "parent_plus_daemon_peak_private_mib",
    "daemons_seen"
  )],
  file.path(root, "worker_summary.csv"),
  row.names = FALSE
)
cat("WS53_SUMMARY_OK\n")
