# The three full-suite non-passes of LDG-3261, run against the cut base's
# installed library: they come from the host's packages (duckdb 2.0.1 since
# 2026-11-24; mirai needing nanonext >= 1.10.4), not from workstream 43.
lib <- "C:/Users/maxth/ledgr-wt/cut24-scratch/libs/base-ea580bc6"
.libPaths(c(lib, .libPaths()))
suppressPackageStartupMessages(library(ledgr))
for (f in c("test-schema-current.R", "test-strategy-schedule.R")) {
  r <- as.data.frame(testthat::test_file(file.path("C:/Users/maxth/ledgr-wt/ws43/tests/testthat", f),
                                         reporter = "silent", package = "ledgr"))
  cat(f, ": tests", nrow(r), "failed", sum(r$failed > 0), "errors", sum(r$error), "\n")
  print(r[r$failed > 0 | r$error, "test"])
}
