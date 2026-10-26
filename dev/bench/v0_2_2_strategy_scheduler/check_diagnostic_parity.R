# Check one untimed manual/scheduled pair for every diagnostic retained on a
# scheduled skip. The timing record remains separate and unchanged.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) {
  stop("Usage: check_diagnostic_parity.R <record_dir>", call. = FALSE)
}
record_dir <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
fail <- function(message) stop(message, call. = FALSE)

summary_files <- list.files(
  record_dir,
  pattern = "^pair1_[12]_(manual|scheduled)_summary[.]csv$",
  full.names = TRUE
)
if (length(summary_files) != 2L) {
  fail("Diagnostic parity record must contain one manual and one scheduled summary.")
}
rows <- do.call(rbind, lapply(summary_files, utils::read.csv, stringsAsFactors = FALSE))
rows <- rows[order(rows$order_in_pair), , drop = FALSE]
if (!identical(as.character(rows$arm), c("manual", "scheduled"))) {
  fail("Diagnostic parity arms must be ordered manual, scheduled.")
}
required <- c(
  "retained_off_diagnostics_hash",
  "retained_off_diagnostic_rows",
  "due_diagnostic_rows",
  "off_scheduled_skip_rows"
)
if (!all(required %in% names(rows))) {
  fail("Diagnostic parity summaries lack the retained off-date evidence.")
}
parity <- c(
  "fills_hash", "ledger_hash", "equity_hash", "positions_hash", "lots_hash",
  "state_hash", "due_diagnostics_hash", "due_diagnostic_rows",
  "retained_off_diagnostics_hash", "retained_off_diagnostic_rows",
  "final_equity", "due_count"
)
for (field in parity) {
  if (length(unique(rows[[field]])) != 1L) {
    fail(paste("Diagnostic parity failed:", field))
  }
}
if (rows$due_diagnostic_rows[[1L]] <= 0L) {
  fail("Diagnostic parity record has an empty decision-date diagnostic set.")
}
scheduled <- rows$arm == "scheduled"
if (rows$off_scheduled_skip_rows[scheduled] != rows$scheduled_skip_count[scheduled]) {
  fail("Scheduled skip diagnostics do not reconcile with the compiled skip count.")
}
if (rows$off_scheduled_skip_rows[!scheduled] != 0L) {
  fail("Manual diagnostic parity arm unexpectedly recorded scheduled skips.")
}

count_files <- list.files(
  record_dir,
  pattern = "^pair1_[12]_(manual|scheduled)_off_diagnostic_counts[.]csv$",
  full.names = TRUE
)
if (length(count_files) != 2L) {
  fail("Diagnostic parity record must contain two reason-count files.")
}
counts <- do.call(rbind, lapply(count_files, utils::read.csv, stringsAsFactors = FALSE))
retained <- counts[!counts$stage %in% c("decision", "risk"), , drop = FALSE]
count_key <- function(arm) {
  x <- retained[retained$arm == arm, c("stage", "outcome", "reason_code", "n"), drop = FALSE]
  x <- x[order(x$stage, x$outcome, x$reason_code), , drop = FALSE]
  rownames(x) <- NULL
  x
}
if (!identical(count_key("manual"), count_key("scheduled"))) {
  fail("Retained off-date diagnostic reason counts differ between arms.")
}
removed_manual <- counts$arm == "manual" & counts$stage %in% c("decision", "risk")
if (!any(removed_manual) || sum(counts$n[removed_manual]) <= 0L) {
  fail("Manual arm does not evidence the expected explicit-hold decision/risk rows.")
}

due_files <- list.files(
  record_dir,
  pattern = "^pair1_[12]_(manual|scheduled)_due_dates[.]csv$",
  full.names = TRUE
)
if (length(due_files) != 2L) fail("Diagnostic parity record lacks literal due dates.")
due <- lapply(due_files, utils::read.csv, stringsAsFactors = FALSE)
due_key <- vapply(due, function(x) paste(x$due_date, collapse = ";"), "")
if (length(unique(due_key)) != 1L) fail("Diagnostic parity due dates differ.")

cat(sprintf(
  "LEDGR_SCHEDULER_DIAGNOSTIC_PARITY_OK retained_rows=%d manual_decision_risk_rows=%d\n",
  rows$retained_off_diagnostic_rows[[1L]],
  sum(counts$n[removed_manual])
))
