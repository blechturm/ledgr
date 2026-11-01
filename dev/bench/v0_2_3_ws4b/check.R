args <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(if (length(args)) args[[1L]] else ".", winslash = "/")

differences <- utils::read.csv(
  file.path(root, "dev/bench/v0_2_3_ws4b/expected_differences.csv"),
  colClasses = "character", na.strings = character()
)
if (!identical(differences$decision, c("1", "2", "3", "4", "5", "9")) ||
    anyDuplicated(differences$surface) || any(!nzchar(differences$detector))) {
  stop("WS4B_EXPECTED_DIFFERENCE_RECORD_INVALID", call. = FALSE)
}
claims <- readLines(file.path(root, "tests/claims.yml"), warn = FALSE)
for (detector in differences$detector) {
  if (!any(grepl(detector, claims, fixed = TRUE))) {
    stop(sprintf("WS4B_DETECTOR_MISSING %s", detector), call. = FALSE)
  }
}

scanner <- new.env(parent = baseenv())
sys.source(file.path(root, "tools/codebase-structure.R"), envir = scanner)
sites <- scanner$ledgr_mode_branch_scan(root)
owners <- utils::read.csv(
  file.path(root, "dev/bench/v0_2_3_ws4b/mode_branch_disposition.csv"),
  colClasses = "character", na.strings = character(), check.names = FALSE
)
site_keys <- unique(paste(sites$file, sites$owner, sep = "::"))
owner_keys <- unique(paste(owners$file, owners[["function"]], sep = "::"))
missing <- setdiff(site_keys, owner_keys)
if (length(missing)) {
  stop(sprintf("WS4B_UNOWNED_MODE_BRANCH %s", paste(missing, collapse = ",")), call. = FALSE)
}

.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
pkgload::load_all(root, compile = FALSE, quiet = TRUE)
result <- testthat::test_file(
  file.path(root, "tests/testthat/test-one-execution-path.R"),
  reporter = "silent"
)
bad <- vapply(result, function(context) {
  any(vapply(context$results, function(x) {
    inherits(x, c("expectation_failure", "expectation_error"))
  }, logical(1)))
}, logical(1))
if (any(bad)) stop("WS4B_SEMANTIC_WITNESS_FAILED", call. = FALSE)
cat("WS4B_CONTROL_OK decisions=6 unowned_mode_rows=0\n")
