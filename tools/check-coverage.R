ledgr_coverage_attempts <- function() {
  attempts <- as.integer(Sys.getenv("LEDGR_COVERAGE_ATTEMPTS", "1"))
  if (!is.finite(attempts) || attempts < 1L) {
    stop("LEDGR_COVERAGE_ATTEMPTS must be a positive integer.", call. = FALSE)
  }
  attempts
}

ledgr_collect_coverage <- function(package_coverage = covr::package_coverage,
                                   attempts = ledgr_coverage_attempts()) {
  last_error <- NULL
  for (i in seq_len(attempts)) {
    coverage <- tryCatch(
      package_coverage(),
      error = function(e) {
        last_error <<- e
        NULL
      }
    )
    if (!is.null(coverage)) return(coverage)
    if (i < attempts) {
      message(sprintf(
        "coverage attempt %d/%d failed: %s; retrying",
        i,
        attempts,
        conditionMessage(last_error)
      ))
    }
  }
  stop(last_error)
}

ledgr_check_coverage_main <- function() {
  threshold <- as.numeric(Sys.getenv("LEDGR_COVERAGE_THRESHOLD", "80"))
  if (!is.finite(threshold) || threshold <= 0 || threshold > 100) {
    stop("LEDGR_COVERAGE_THRESHOLD must be a number in (0, 100].", call. = FALSE)
  }

  if (!requireNamespace("covr", quietly = TRUE)) {
    stop("The 'covr' package is required for coverage checks.", call. = FALSE)
  }
  for (pkg in c("DT", "htmltools")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop(sprintf("The '%s' package is required to generate coverage.html.", pkg), call. = FALSE)
    }
  }

  coverage <- ledgr_collect_coverage()
  coverage_pct <- covr::percent_coverage(coverage)

  message(sprintf("ledgr coverage: %.2f%%", coverage_pct))
  covr::report(coverage, file = "coverage.html", browse = FALSE)

  if (coverage_pct < threshold) {
    stop(
      sprintf("Coverage %.2f%% is below required threshold %.2f%%.", coverage_pct, threshold),
      call. = FALSE
    )
  }
}

if (sys.nframe() == 0L) {
  ledgr_check_coverage_main()
}
