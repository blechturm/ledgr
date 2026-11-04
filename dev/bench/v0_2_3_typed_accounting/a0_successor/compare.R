# Compare the schema-125 successor record with the immutable schema-124
# record at 0d6c0b11. Product results stay exact. The comparator normalizes
# only the accepted storage transition: accounting JSON becomes typed ledger
# columns, runs carry schema 125 rather than 124, and two formerly zero
# INCOMPLETE annualized returns become typed missing.
# Usage: Rscript compare.R --base=<dir> --candidate=<dir>

args <- commandArgs(trailingOnly = TRUE)
arg <- function(name) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (!length(hit)) stop(sprintf("missing --%s", name), call. = FALSE)
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
base <- normalizePath(arg("base"), winslash = "/")
candidate <- normalizePath(arg("candidate"), winslash = "/")
read_manifest <- function(path) {
  utils::read.csv(file.path(path, "manifest.csv"), colClasses = "character")
}
verify_manifest <- function(path, manifest) {
  actual <- list.files(path, recursive = TRUE, all.files = FALSE, no.. = TRUE)
  actual <- gsub("\\\\", "/", actual)
  actual <- sort(setdiff(actual, "manifest.csv"), method = "radix")
  expected <- sort(gsub("\\\\", "/", manifest$file), method = "radix")
  if (!identical(actual, expected)) {
    stop(sprintf("successor A0 manifest file set is stale: %s", path), call. = FALSE)
  }
  located <- file.path(path, manifest$file)
  bytes <- vapply(located, function(file) sprintf("%d", as.integer(file.size(file))), character(1))
  hashes <- vapply(located, digest::digest, character(1), algo = "sha256", file = TRUE)
  if (!identical(unname(bytes), manifest$bytes) ||
      !identical(unname(hashes), manifest$sha256)) {
    stop(sprintf("successor A0 manifest hashes are stale: %s", path), call. = FALSE)
  }
  invisible(TRUE)
}
read_record <- function(root, file) {
  utils::read.csv(
    file.path(root, file), colClasses = "character", na.strings = "NA",
    check.names = FALSE
  )
}

base_manifest <- read_manifest(base)
candidate_manifest <- read_manifest(candidate)
verify_manifest(base, base_manifest)
verify_manifest(candidate, candidate_manifest)
if (!identical(base_manifest$file, candidate_manifest$file)) {
  stop("successor A0 file sets differ", call. = FALSE)
}

annualized_files <- c(
  "avail_incomplete/sweep_w1/sweep.csv",
  "avail_incomplete/sweep_w2/sweep.csv"
)
event_files <- grep(
  "(^|/)(ledger_events|memory_events)[.]csv$", base_manifest$file,
  value = TRUE
)
run_files <- grep("(^|/)runs[.]csv$", base_manifest$file, value = TRUE)
fold_files <- "walk_forward/walk_forward/wf_folds.csv"
allowed <- c(annualized_files, event_files, run_files, fold_files)
changed <- base_manifest$file[base_manifest$sha256 != candidate_manifest$sha256]
unexpected <- setdiff(changed, allowed)
if (length(unexpected) > 0L) {
  stop(sprintf(
    "unexpected successor A0 changes: %s",
    paste(unexpected, collapse = ", ")
  ), call. = FALSE)
}

# The old arm stores accounting in meta_json. The new arm publishes these
# columns directly. Normalize both to the schema-125 semantic surface; do not
# compare the old memory-only derived columns, which are independently pinned
# by memory_fills.csv and were never durable ledger columns.
accounting_columns <- c(
  "cash_delta", "position_delta", "source", "source_fact_id",
  "entitled_quantity", "gross_cash_per_parent_unit", "amount_policy_id",
  "posting_policy_id", "late_arrival", "affected_marked_exposure",
  "terminal_event", "matched_label", "disposition_policy_id",
  "disposition_choice", "disposition_basis", "mark_source",
  "mark_source_ts_utc", "mark_age", "haircut_fraction", "position_before",
  "realized_model_pnl"
)
common_columns <- c(
  "event_id", "run_id", "ts_utc", "event_type", "instrument_id", "side",
  "qty", "price", "fee", "event_seq"
)
numeric_columns <- c(
  "qty", "price", "fee", "cash_delta", "position_delta",
  "entitled_quantity", "gross_cash_per_parent_unit",
  "affected_marked_exposure", "haircut_fraction", "position_before",
  "realized_model_pnl"
)
integer_columns <- c("event_seq", "mark_age")
logical_columns <- "late_arrival"
column_name <- function(df, name) {
  hit <- grep(paste0("^", name, ":"), names(df), value = TRUE)
  if (length(hit) != 1L) NA_character_ else hit
}
typed_value <- function(df, name) {
  hit <- column_name(df, name)
  if (is.na(hit)) rep(NA_character_, nrow(df)) else df[[hit]]
}
json_value <- function(meta, name) {
  vapply(meta, function(row) {
    value <- row[[name]]
    if (is.null(value) || length(value) == 0L || is.na(value[[1L]])) {
      return(NA_character_)
    }
    as.character(value[[1L]])
  }, character(1))
}
normalize_number <- function(x) {
  out <- rep(NA_character_, length(x))
  keep <- !is.na(x)
  if (any(keep)) {
    value <- suppressWarnings(as.numeric(x[keep]))
    if (anyNA(value)) stop("successor A0 accounting contains a non-numeric value", call. = FALSE)
    out[keep] <- vapply(value, function(v) sprintf("%.17g", v), character(1))
  }
  out
}
normalize_integer <- function(x) {
  out <- rep(NA_character_, length(x))
  keep <- !is.na(x)
  if (any(keep)) {
    value <- suppressWarnings(as.numeric(x[keep]))
    if (anyNA(value) || any(value != trunc(value))) {
      stop("successor A0 accounting contains a non-integer value", call. = FALSE)
    }
    out[keep] <- sprintf("%.0f", value)
  }
  out
}
normalize_logical <- function(x) {
  out <- toupper(x)
  out[is.na(x)] <- NA_character_
  bad <- !is.na(out) & !out %in% c("TRUE", "FALSE")
  if (any(bad)) stop("successor A0 accounting contains a non-logical value", call. = FALSE)
  out
}
normalize_events <- function(df, old) {
  if (old) {
    meta_name <- column_name(df, "meta_json")
    if (is.na(meta_name)) {
      if (nrow(df) > 0L) stop("schema-124 A0 events omit meta_json", call. = FALSE)
      meta <- list()
    } else {
      meta <- lapply(df[[meta_name]], function(value) {
        if (is.na(value)) list() else jsonlite::fromJSON(value, simplifyVector = FALSE)
      })
    }
  }
  values <- lapply(c(common_columns, accounting_columns), function(name) {
    if (!old || name %in% common_columns) typed_value(df, name) else json_value(meta, name)
  })
  names(values) <- c(common_columns, accounting_columns)
  for (name in numeric_columns) values[[name]] <- normalize_number(values[[name]])
  for (name in integer_columns) values[[name]] <- normalize_integer(values[[name]])
  for (name in logical_columns) values[[name]] <- normalize_logical(values[[name]])
  as.data.frame(values, stringsAsFactors = FALSE, check.names = FALSE)
}
for (file in event_files) {
  before <- normalize_events(read_record(base, file), old = TRUE)
  after <- normalize_events(read_record(candidate, file), old = FALSE)
  if (!identical(before, after)) {
    stop(sprintf("%s changes accounting semantics", file), call. = FALSE)
  }
}

# Store identity is deliberately unchanged; only the required schema marker
# moves atomically from 124 to 125.
for (file in run_files) {
  before <- read_record(base, file)
  after <- read_record(candidate, file)
  schema <- column_name(before, "schema_version")
  if (is.na(schema) || !identical(names(before), names(after)) ||
      !all(before[[schema]] == "124") || !all(after[[schema]] == "125")) {
    stop(sprintf("%s does not contain the atomic 124-to-125 marker change", file), call. = FALSE)
  }
  before[[schema]] <- after[[schema]]
  if (!identical(before, after)) stop(sprintf("%s changes beyond schema_version", file), call. = FALSE)
}

# selected_at_utc is a documented wall-clock field. It is ignored only here;
# every other fold cell remains byte-identical.
before_fold <- read_record(base, fold_files)
after_fold <- read_record(candidate, fold_files)
selected <- column_name(before_fold, "selected_at_utc")
if (is.na(selected) || !identical(names(before_fold), names(after_fold))) {
  stop("walk-forward fold record shape changed", call. = FALSE)
}
before_fold[[selected]] <- after_fold[[selected]]
if (!identical(before_fold, after_fold)) stop("walk-forward folds changed", call. = FALSE)

for (file in annualized_files) {
  before <- read_record(base, file)
  after <- read_record(candidate, file)
  annualized <- column_name(before, "annualized_return")
  other <- names(before) != annualized
  if (!identical(names(before), names(after)) || is.na(annualized) ||
      nrow(before) != 2L || !identical(before[other], after[other])) {
    stop(sprintf("%s differs outside the accepted field", file), call. = FALSE)
  }
  if (!identical(before[[annualized]], c("0", "0")) ||
      !identical(after[[annualized]], c(NA_character_, NA_character_))) {
    stop(sprintf("%s does not contain the accepted values", file), call. = FALSE)
  }
}
cat(sprintf(
  paste0(
    "successor A0 compare: PASS (281 files; %d typed event files; ",
    "%d schema markers; four accepted annualized_return cells)\n"
  ),
  length(event_files), length(run_files)
))
