# LDG-3245: summarises the close-check outputs in this folder (gate, batch one,
# inert, variants) and prints each run's frozen-path line and verdict counts.
#   Rscript dev/lean_core/parity/evidence/cut21/ldg3245/summarize.R
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
for (f in sort(list.files(here, pattern = "^(gate|batch1|inert)_debug[01][.]log$", full.names = TRUE))) {
  x <- readLines(f)
  cat(basename(f), "|", grep("^frozen paths", x, value = TRUE), "|", utils::tail(x, 1L), "\n")
}
for (f in sort(list.files(here, pattern = "^(gate|batch1|inert)_debug[01][.]csv$", full.names = TRUE))) {
  x <- utils::read.csv(f, stringsAsFactors = FALSE)
  cat(basename(f), length(unique(x$workload)), "workloads,", nrow(x), "tables,", sum(!x$identical), "different\n")
}
for (d in 0:1) {
  f <- file.path(here, "variants", sprintf("loop_mutations_debug%d.csv", d))
  if (!file.exists(f)) { cat("missing", f, "\n"); next }
  x <- utils::read.csv(f, stringsAsFactors = FALSE)
  v <- unique(x[, intersect(c("mutation", "workload", "batch_rows", "verdict"), names(x))])
  cat(sprintf("variants debug %d: %d rows; verdicts %s\n", d, nrow(v), paste(names(table(v$verdict)), table(v$verdict), collapse = ", ")))
  new <- v[v$mutation %in% c("post_omitted", "post_cash_not_installed", "captured_row_dropped", "captured_row_duplicated",
    "corporate_rows_after_fills", "fill_seq_contiguous", "capture_validation_deferred", "nonfill_commit_late",
    "capture_lost_at_growth", "nonfill_block_unsplit", "fill_price_ulp", "valuation_stop_counts_pulse",
    "affected_contribution_dropped", "frozen_opening_ignored"), ]
  print(new, row.names = FALSE)
}
