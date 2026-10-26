args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("Usage: check_record.R <record_dir>", call. = FALSE)
record_dir <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
fail <- function(message) stop(message, call. = FALSE)
files <- list.files(record_dir, pattern = "^pair[0-9]+_[12]_(manual|scheduled)_summary[.]csv$", full.names = TRUE)
if (length(files) != 6L) fail("Record must contain six arm summaries.")
rows <- do.call(rbind, lapply(files, utils::read.csv, stringsAsFactors = FALSE))
rows <- rows[order(rows$pair, rows$order_in_pair), , drop = FALSE]
if (!identical(sort(unique(rows$pair)), 1:3)) fail("Record must contain three pairs.")
if (!identical(as.character(rows$arm), c("manual", "scheduled", "scheduled", "manual", "manual", "scheduled"))) {
  fail("Arm order is not the registered alternating order.")
}
if (any(rows$status != "DONE")) fail("Every arm must finish DONE.")
if (length(unique(rows$snapshot_hash)) != 1L || length(unique(rows$strategy_source_hash)) != 1L) {
  fail("Snapshot or inner strategy source identity differs across arms.")
}
manual <- rows$arm == "manual"
scheduled <- rows$arm == "scheduled"
if (any(rows$decision_pulse_count[manual] != rows$pulse_count[manual]) ||
    any(rows$scheduled_skip_count[manual] != 0L)) {
  fail("Manual arms must invoke the strategy on every pulse without scheduled skips.")
}
if (any(rows$decision_pulse_count[scheduled] != rows$due_count[scheduled]) ||
    any(rows$decision_pulse_count[scheduled] + rows$scheduled_skip_count[scheduled] !=
      rows$pulse_count[scheduled])) {
  fail("Scheduled decision and skip counts do not partition the pulse axis.")
}
if (any(!is.na(rows$schedule_hash[manual])) ||
    any(is.na(rows$schedule_hash[scheduled])) ||
    length(unique(rows$schedule_hash[scheduled])) != 1L) {
  fail("Authored schedule identity is absent or inconsistent.")
}
parity <- c("fills_hash", "ledger_hash", "equity_hash", "positions_hash", "lots_hash", "state_hash", "due_diagnostics_hash", "final_equity", "due_count")
for (field in parity) {
  if (length(unique(rows[[field]])) != 1L) fail(paste("Economic or carried-state parity failed:", field))
}
due_files <- list.files(record_dir, pattern = "_due_dates[.]csv$", full.names = TRUE)
if (length(due_files) != 6L) fail("Record must contain six literal due-date files.")
due <- lapply(due_files, utils::read.csv, stringsAsFactors = FALSE)
due_key <- vapply(due, function(x) paste(x$due_date, collapse = ";"), "")
if (length(unique(due_key)) != 1L) fail("Literal due dates differ across arms.")
if (any(rows$arm == "scheduled" & rows$off_scheduled_skip_rows != rows$scheduled_skip_count)) {
  fail("Scheduled off-date diagnostics do not reconcile with skip counts.")
}
if (any(rows$arm == "manual" & rows$off_scheduled_skip_rows != 0L)) {
  fail("Manual arm unexpectedly recorded scheduled skips.")
}
ratios <- vapply(1:3, function(pair) {
  block <- rows[rows$pair == pair, , drop = FALSE]
  block$elapsed_s[block$arm == "scheduled"] / block$elapsed_s[block$arm == "manual"]
}, 0)
median_ratio <- stats::median(ratios)
manual_median <- stats::median(rows$elapsed_s[rows$arm == "manual"])
scheduled_median <- stats::median(rows$elapsed_s[rows$arm == "scheduled"])
summary <- data.frame(
  pairs = 3L,
  manual_median_s = manual_median,
  scheduled_median_s = scheduled_median,
  absolute_saving_s = manual_median - scheduled_median,
  median_within_pair_ratio = median_ratio,
  recovered_lower_bound_share = (manual_median - scheduled_median) / 14.17,
  gate = 0.90,
  passed = median_ratio <= 0.90,
  stringsAsFactors = FALSE
)
utils::write.csv(summary, file.path(record_dir, "check_summary.csv"), row.names = FALSE)
if (!isTRUE(summary$passed)) fail(sprintf("Scheduler ratio %.3f exceeds 0.90.", median_ratio))
cat(sprintf("LEDGR_SCHEDULER_H1_OK pairs=3 ratio=%.3f saving=%.2fs\n", median_ratio, summary$absolute_saving_s))
