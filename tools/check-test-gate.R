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
diagnostics <- vector("list", length(summary_paths))
records <- do.call(rbind, lapply(seq_along(summary_paths), function(path_index) {
  path <- summary_paths[[path_index]]
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
  if (!all(census_required %in% names(census_record))) {
    ledgr_test_abort(
      sprintf("Run %s census is missing required columns: %s.", index,
              paste(setdiff(census_required, names(census_record)), collapse = ", ")),
      "ledgr_test_timing_invalid"
    )
  }
  if (anyNA(census_record[, c("profile", "key"), drop = FALSE])) {
    ledgr_test_abort(
      sprintf("Run %s census has a missing profile or block key in %s.", index, basename(census)),
      "ledgr_test_timing_invalid"
    )
  }
  duplicate <- which(duplicated(census_record$key))
  if (length(duplicate) > 0L) {
    ledgr_test_abort(
      sprintf("Run %s census duplicates block key %s.", index,
              census_record$key[[duplicate[[1L]]]]),
      "ledgr_test_timing_invalid"
    )
  }
  if (nrow(census_record) != record$expected_blocks[[1L]]) {
    ledgr_test_abort(
      sprintf(
        "Run %s expected-block census mismatch: summary=%d, %s=%d.",
        index, record$expected_blocks[[1L]], basename(census), nrow(census_record)
      ),
      "ledgr_test_timing_invalid"
    )
  }
  bad_profile <- which(census_record$profile != record$profile[[1L]])
  if (length(bad_profile) > 0L) {
    ledgr_test_abort(
      sprintf("Run %s census profile mismatch at block %s.", index,
              census_record$key[[bad_profile[[1L]]]]),
      "ledgr_test_timing_invalid"
    )
  }
  observed_executed <- sum(!is.na(census_record$status))
  if (observed_executed != record$executed_blocks[[1L]]) {
    ledgr_test_abort(
      sprintf(
        "Run %s executed-block summary mismatch: summary=%d, %s records=%d.",
        index, record$executed_blocks[[1L]], basename(census), observed_executed
      ),
      "ledgr_test_timing_invalid"
    )
  }
  observed_skipped <- sum(census_record$status == "skipped", na.rm = TRUE)
  if (observed_skipped != record$skipped_blocks[[1L]]) {
    ledgr_test_abort(
      sprintf("Run %s skipped-block summary mismatch in %s.", index, basename(census)),
      "ledgr_test_timing_invalid"
    )
  }
  observed_failed <- sum(census_record$status %in% failure_status, na.rm = TRUE)
  if (observed_failed != record$failed_blocks[[1L]]) {
    ledgr_test_abort(
      sprintf("Run %s failed-block summary mismatch in %s.", index, basename(census)),
      "ledgr_test_timing_invalid"
    )
  }
  diagnostics[[path_index]] <<- list(
    index = index,
    census = census,
    first_key = if (nrow(census_record) > 0L) census_record$key[[1L]] else basename(census),
    failures = census_record[census_record$status %in% failure_status &
                               !is.na(census_record$status), , drop = FALSE],
    missing = census_record[is.na(census_record$status), , drop = FALSE]
  )
  record
}))
profile_mismatch <- which(records$profile != profile)
if (length(profile_mismatch) > 0L) {
  row <- profile_mismatch[[1L]]
  ledgr_test_abort(
    sprintf(
      "Run %s profile mismatch: recorded %s, requested %s; first block %s.",
      diagnostics[[row]]$index, records$profile[[row]], profile,
      diagnostics[[row]]$first_key
    ),
    "ledgr_test_timing_invalid"
  )
}
mode_mismatch <- which(records$mode != mode)
if (length(mode_mismatch) > 0L) {
  row <- mode_mismatch[[1L]]
  ledgr_test_abort(
    sprintf(
      "Run %s mode mismatch: recorded %s, requested %s; first block %s.",
      diagnostics[[row]]$index, records$mode[[row]], mode,
      diagnostics[[row]]$first_key
    ),
    "ledgr_test_timing_invalid"
  )
}
failed_run <- which(records$failed_blocks != 0L)
if (length(failed_run) > 0L) {
  row <- failed_run[[1L]]
  first <- diagnostics[[row]]$failures[1L, , drop = FALSE]
  ledgr_test_abort(
    sprintf(
      "Run %s has %d non-passing block(s); first is %s with status %s.",
      diagnostics[[row]]$index, records$failed_blocks[[row]],
      first$key[[1L]], first$status[[1L]]
    ),
    "ledgr_test_timing_invalid"
  )
}
execution_mismatch <- which(records$executed_blocks != records$expected_blocks)
if (length(execution_mismatch) > 0L) {
  row <- execution_mismatch[[1L]]
  missing <- diagnostics[[row]]$missing
  reference <- if (nrow(missing) > 0L) missing$key[[1L]] else basename(diagnostics[[row]]$census)
  ledgr_test_abort(
    sprintf(
      "Run %s executed/expected mismatch: executed=%d, expected=%d; first missing block or census %s.",
      diagnostics[[row]]$index, records$executed_blocks[[row]],
      records$expected_blocks[[row]], reference
    ),
    "ledgr_test_timing_invalid"
  )
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
