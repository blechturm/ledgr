args <- commandArgs(FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
here <- if (length(file_arg)) dirname(normalizePath(sub("^--file=", "", file_arg[[1L]]))) else getwd()
root <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
patterns <- c(
  accounting_preparer = "ledgr_prepare_accounting_events",
  accounting_validator = "ledgr_validate_accounting_append",
  accounting_replay = "ledgr_replay_accounting_events",
  ledger_table = "ledger_events",
  state_asof = "ledgr_state_asof",
  diagnostics_table = "run_diagnostics",
  diagnostics_implicit_table = "run_diagnostic_implicit",
  diagnostics_coverage_table = "run_diagnostic_coverage",
  diagnostics_summary_table = "run_diagnostic_summary",
  completion_table = "run_completion",
  max_pulses = "max_pulses",
  restart_symbol = "ledgr_run_restart_nonterminal"
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

surface_patterns <- c(
  producer_append = "append_event_rows(",
  producer_fill = "ledgr_fill_event_payload(",
  writer_insert = "INSERT INTO ledger_events",
  writer_append = "ledgr_store_append(con, \"ledger_events\"",
  reader_prepare = "ledgr_prepare_accounting_events(",
  reader_replay = "ledgr_replay_accounting_events(",
  writer_validate = "ledgr_validate_accounting_append(",
  ledger_reference = "ledger_events"
)
surface_files <- c(
  list.files(file.path(root, "R"), "[.]R$", recursive = TRUE, full.names = TRUE),
  list.files(file.path(root, "tests", "testthat"), "[.]R$", recursive = TRUE, full.names = TRUE),
  list.files(file.path(root, "man"), "[.]Rd$", recursive = TRUE, full.names = TRUE),
  list.files(file.path(root, "vignettes"), "[.](qmd|md|Rmd)$", recursive = TRUE, full.names = TRUE),
  file.path(root, "NEWS.md"),
  file.path(root, "inst", "design", "contracts.md")
)
surface_files <- sort(unique(surface_files[file.exists(surface_files)]), method = "radix")
surface_actual <- do.call(rbind, lapply(surface_files, function(path) {
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  rel <- substring(normalizePath(path, winslash = "/"), nchar(root) + 2L)
  rows <- lapply(names(surface_patterns), function(family) {
    count <- lengths(regmatches(text, gregexpr(surface_patterns[[family]], text, fixed = TRUE)))
    if (count == 0L) return(NULL)
    role <- if (startsWith(rel, "tests/testthat/")) {
      "test"
    } else if (startsWith(rel, "man/") || startsWith(rel, "vignettes/") ||
        rel %in% c("NEWS.md", "inst/design/contracts.md")) {
      "doc"
    } else if (startsWith(family, "producer")) {
      "producer"
    } else if (startsWith(family, "writer")) {
      "writer"
    } else if (startsWith(family, "reader")) {
      "reader"
    } else {
      "storage_reference"
    }
    data.frame(role = role, family = family, path = rel, count = count, stringsAsFactors = FALSE)
  })
  do.call(rbind, rows[!vapply(rows, is.null, logical(1))])
}))
surface_expected <- utils::read.csv(
  file.path(here, "accounting_surface_census.csv"), stringsAsFactors = FALSE
)
surface_key <- function(x) paste(x$role, x$family, x$path, as.integer(x$count), sep = "|")
if (!identical(
  sort(surface_key(surface_expected), method = "radix"),
  sort(surface_key(surface_actual), method = "radix")
)) {
  stop("accounting_surface_census.csv differs from the producer/writer/reader/test/doc scan", call. = FALSE)
}
if (!all(c("producer", "writer", "reader", "test", "doc") %in% surface_expected$role)) {
  stop("accounting surface census omits a required ownership role", call. = FALSE)
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
