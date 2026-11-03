args <- commandArgs(FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
here <- if (length(file_arg)) dirname(normalizePath(sub("^--file=", "", file_arg[[1L]]))) else getwd()
root <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
patterns <- c(
  accounting_preparer = "ledgr_prepare_accounting_events",
  accounting_replay = "ledgr_replay_accounting_events",
  ledger_table = "ledger_events",
  state_asof = "ledgr_state_asof",
  diagnostics_table = "run_diagnostics",
  strategy_state_table = "strategy_state",
  completion_table = "run_completion",
  interrupt_option = "ledgr.interrupt",
  max_pulses = "max_pulses",
  resume_symbol = "ledgr_run_resume"
)
expected <- utils::read.csv(file.path(here, "source_census.csv"), stringsAsFactors = FALSE)
actual <- do.call(rbind, lapply(names(patterns), function(family) {
  files <- sort(list.files(file.path(root, "R"), "[.]R$", full.names = TRUE))
  rows <- lapply(files, function(path) {
    text <- paste(readLines(path, warn = FALSE), collapse = "\n")
    count <- lengths(regmatches(text, gregexpr(patterns[[family]], text, fixed = TRUE)))
    if (count == 0L) return(NULL)
    data.frame(family = family, path = paste0("R/", basename(path)), count = count, stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}))
rownames(expected) <- NULL
rownames(actual) <- NULL
key <- function(x) paste(x$family, x$path, as.integer(x$count), sep = "|")
if (!identical(sort(key(expected), method = "radix"), sort(key(actual), method = "radix"))) {
  stop("source_census.csv differs from the production source scan", call. = FALSE)
}
accounting <- utils::read.csv(file.path(here, "accounting_field_map.csv"), stringsAsFactors = FALSE)
diagnostic <- utils::read.csv(file.path(here, "diagnostic_field_map.csv"), stringsAsFactors = FALSE)
required_accounting <- c(
  "event_id", "run_id", "ts_utc", "event_type", "instrument_id", "side", "qty", "price", "fee",
  "cash_delta", "position_delta", "source", "source_fact_id", "entitled_quantity",
  "gross_cash_per_parent_unit", "amount_policy_id", "posting_policy_id", "late_arrival",
  "affected_marked_exposure", "terminal_event", "matched_label", "disposition_policy_id",
  "disposition_choice", "disposition_basis", "mark_source", "mark_source_ts_utc", "mark_age",
  "haircut_fraction", "position_before", "realized_model_pnl"
)
required_diagnostic <- c(
  "run_id", "diagnostic_seq", "ts_utc", "instrument_id", "stage", "outcome", "reason_code",
  "reasons", "target", "quantity", "price", "mark_source", "mark_age", "decision_ts_utc",
  "execution_ts_utc", "event_seq", "target_before_risk", "target_after_risk", "position_before",
  "position_after", "feature_identity_json", "detail_json"
)
if (!identical(accounting$field, required_accounting)) stop("accounting field map is incomplete or reordered", call. = FALSE)
if (!identical(diagnostic$field, required_diagnostic)) stop("diagnostic field map is incomplete or reordered", call. = FALSE)
if (any(!nzchar(accounting$derivation)) || any(!nzchar(diagnostic$derivation))) stop("a mapped field lacks a derivation", call. = FALSE)
manifest <- utils::read.csv(file.path(root, "dev/bench/v0_2_3_output_freeze/records/manifest.csv"), colClasses = "character")
for (i in seq_len(nrow(manifest))) {
  path <- file.path(root, "dev/bench/v0_2_3_output_freeze/records", manifest$file[[i]])
  if (!file.exists(path) || !identical(digest::digest(file = path, algo = "sha256"), manifest$sha256[[i]])) {
    stop(sprintf("frozen baseline differs at %s", manifest$file[[i]]), call. = FALSE)
  }
}
cat(sprintf("cut11 baseline: PASS (%d seams, %d accounting fields, %d diagnostic fields, %d frozen files); private gate OPEN\n", nrow(expected), nrow(accounting), nrow(diagnostic), nrow(manifest)))
