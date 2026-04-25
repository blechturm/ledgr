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

coverage <- covr::package_coverage()
coverage_pct <- covr::percent_coverage(coverage)

message(sprintf("ledgr coverage: %.2f%%", coverage_pct))
covr::report(coverage, file = "coverage.html", browse = FALSE)

if (coverage_pct < threshold) {
  stop(
    sprintf("Coverage %.2f%% is below required threshold %.2f%%.", coverage_pct, threshold),
    call. = FALSE
  )
}
