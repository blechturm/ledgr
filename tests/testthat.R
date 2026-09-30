# This file is part of the standard setup for testthat.
# It is recommended that you do not modify it.
#
# Where should you do additional test configuration?
# Learn more about the roles of various files in:
# * https://r-pkgs.org/testing-design.html#sec-tests-files-overview
# * https://testthat.r-lib.org/articles/special-files.html

library(testthat)
library(ledgr)

source("test-control-plane.R", local = TRUE)
# R CMD check runs the fast profile. tools/check-coverage.R sets
# LEDGR_TEST_PROFILES = "fast,review" so coverage counts every ordinary block.
profiles <- strsplit(Sys.getenv("LEDGR_TEST_PROFILES", unset = "fast"), ",", fixed = TRUE)[[1L]]
for (profile in trimws(profiles)) {
  ledgr_test_run_profile(
    root = ledgr_test_source_root(normalizePath(".", winslash = "/")),
    profile = profile,
    mode = "ordinary",
    reporter = "summary",
    census_path = file.path(tempdir(), sprintf("ledgr-check-census-%s.csv", profile)),
    load_package = "none"
  )
}
