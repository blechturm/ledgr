args <- commandArgs(trailingOnly = TRUE)

value_arg <- function(name, default = NULL) {
  prefix <- paste0("--", name, "=")
  hit <- args[startsWith(args, prefix)]
  if (length(hit) == 0L) return(default)
  sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}

script_arg <- grep("^--file=", commandArgs(), value = TRUE)
script <- normalizePath(sub("^--file=", "", script_arg[[1L]]), winslash = "/")
root <- normalizePath(file.path(dirname(script), ".."), winslash = "/")
source(file.path(root, "tests", "test-control-plane.R"), local = TRUE)
profile <- value_arg("profile", "fast")
mode <- value_arg("mode", "ordinary")
records_dir <- value_arg("records")
if (!identical(profile, "fast")) stop("Only fast has a timing gate.")
if (!mode %in% c("ordinary", "cran")) stop("Unknown gate mode.")
if (is.null(records_dir) || !dir.exists(records_dir)) stop("Gate records are missing.")

gates <- yaml::read_yaml(file.path(root, "tests", "test-gates.yml"))
bound <- if (identical(mode, "ordinary")) {
  gates$ordinary_fast_max_seconds
} else {
  gates$cran_fast_max_seconds
}
if (is.null(bound) || !is.numeric(bound) || length(bound) != 1L) {
  stop("The selected gate has no preregistered bound.")
}

summary_paths <- sort(list.files(
  records_dir,
  pattern = "^run-[123]-summary[.]csv$",
  full.names = TRUE
))
if (length(summary_paths) == 0L) stop("No timing summaries were recorded.")
records <- do.call(rbind, lapply(summary_paths, function(path) {
  record <- utils::read.csv(path, stringsAsFactors = FALSE)
  required <- c(
    "profile", "mode", "elapsed_seconds", "expected_blocks",
    "executed_blocks", "skipped_blocks", "failed_blocks"
  )
  if (nrow(record) != 1L || !all(required %in% names(record))) {
    ledgr_test_abort("Test timing summary is malformed.", "ledgr_test_timing_invalid")
  }
  index <- sub("^run-([123])-summary[.]csv$", "\\1", basename(path))
  census <- file.path(records_dir, sprintf("run-%s-census.csv", index))
  if (!file.exists(census)) {
    ledgr_test_abort("Timing evidence lacks its reconciled census.", "ledgr_test_timing_invalid")
  }
  census_record <- utils::read.csv(census, stringsAsFactors = FALSE)
  census_required <- c("profile", "key", "status")
  failure_status <- c("failed", "error", "warning")
  if (!all(census_required %in% names(census_record)) ||
      nrow(census_record) != record$expected_blocks[[1L]] ||
      nrow(census_record) != record$executed_blocks[[1L]] ||
      anyNA(census_record[, census_required, drop = FALSE]) ||
      anyDuplicated(census_record$key) ||
      any(census_record$profile != record$profile[[1L]]) ||
      sum(census_record$status == "skipped") != record$skipped_blocks[[1L]] ||
      sum(census_record$status %in% failure_status) != record$failed_blocks[[1L]]) {
    ledgr_test_abort(
      "Test timing census does not match its summary.",
      "ledgr_test_timing_invalid"
    )
  }
  record
}))
if (any(records$profile != profile) || any(records$mode != mode) ||
    any(records$failed_blocks != 0L) ||
    any(records$executed_blocks != records$expected_blocks)) {
  ledgr_test_abort("Test timing summaries do not show a passing census.", "ledgr_test_timing_invalid")
}

median_seconds <- ledgr_test_gate_decide(
  records$elapsed_seconds,
  bound,
  gates$confirmation_runs_above_bound
)
records$bound_seconds <- bound
records$median_seconds <- median_seconds
records$gate_passed <- TRUE
utils::write.csv(records, file.path(records_dir, "gate-record.csv"), row.names = FALSE)
cat(sprintf(
  "LEDGR_TEST_GATE_OK mode=%s runs=%d median=%.3f bound=%.3f\n",
  mode, nrow(records), median_seconds, bound
))
