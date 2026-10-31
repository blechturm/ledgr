# Scans every test file with the control plane's own scanner and reports refusals.
args <- commandArgs(TRUE)
root <- if (length(args)) args[[1L]] else "C:/Users/maxth/ledgr-wt/ws4a-impl"
source(file.path(root, "tests", "test-control-plane.R"))
files <- list.files(file.path(root, "tests", "testthat"), "^test.*\\.R$", full.names = TRUE)
bad <- 0L
for (f in files) {
  r <- tryCatch({ ledgr_test_scan_file(f); NULL }, error = function(e) conditionMessage(e))
  if (!is.null(r)) { bad <- bad + 1L; cat(basename(f), ":", r, "\n") }
}
cat("files", length(files), "refused", bad, "\n")
pre <- tryCatch({ ledgr_test_preflight(file.path(root, "tests", "testthat")); "preflight OK" }, error = function(e) conditionMessage(e))
cat(pre, "\n")
