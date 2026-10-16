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
utils::write.csv(summary, file.path(record, "arm_summary.csv"), row.names = FALSE, na = "")
