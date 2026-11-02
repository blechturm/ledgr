# Hot-path bans (macro plan rule 17): banned calls in package code that can
# run per pulse equal the committed baseline, scanned by tools/hot-path-bans.R.

ledgr_hot_path_scanner <- function() {
  scanner <- new.env(parent = globalenv())
  sys.source(file.path(ledgr_test_source_root(), "tools", "hot-path-bans.R"), envir = scanner)
  scanner
}

# ledgr-test-profile: fast
testthat::test_that("[LTB-0546] banned calls in per-pulse package code equal the committed baseline", {
  root <- ledgr_test_source_root()
  scanner <- ledgr_hot_path_scanner()
  scan <- scanner$ledgr_hot_path_scan(root)
  testthat::expect_true("ledgr_fold_stage_decide" %in% attr(scan, "roots"))
  testthat::expect_gt(nrow(scan), 0L)
  if (ledgr_test_checkout_context(root)) {
    baseline <- utils::read.csv(scanner$ledgr_hot_path_baseline_path(root), stringsAsFactors = FALSE)
    diff <- scanner$ledgr_hot_path_diff(scan, baseline)
    testthat::expect_identical(diff, character(), info = paste(
      "Remove the call, or run Rscript tools/hot-path-bans.R --write and justify the new row in review."
    ))
  }
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0547] a banned call reached from a fold stage is counted and an unreached one is not", {
  scanner <- ledgr_hot_path_scanner()
  root <- tempfile("ledgr-hot-path-")
  dir.create(file.path(root, "R"), recursive = TRUE)
  writeLines(c(
    "ledgr_fold_stage_observe_settle <- function(x) {",
    "  local_helper <- function(y) unique(y)",
    "  handler <- list(write = function(y) yyjsonr::write_json_str(y))",
    "  helper(x); local_helper(x); handler$write(x)",
    "  vapply(list(x), match, integer(1), table = 1)",
    "}",
    "helper <- function(x) x %in% 1",
    "setup_only <- function(x) match(x, 1)"
  ), file.path(root, "R", "probe.R"))
  scan <- scanner$ledgr_hot_path_scan(root)
  row <- function(node, call) sum(scan$count[scan$node == node & scan$call == call])
  testthat::expect_identical(row("ledgr_fold_stage_observe_settle", "match"), 1L)
  testthat::expect_identical(row("helper", "%in%"), 1L)
  testthat::expect_identical(row("ledgr_fold_stage_observe_settle/local_helper", "unique"), 1L)
  testthat::expect_identical(row("ledgr_fold_stage_observe_settle$write", "write_json_str"), 1L)
  testthat::expect_identical(row("setup_only", "match"), 0L)
  # One added call is reported against the baseline.
  grown <- scan
  grown$count[grown$node == "helper"] <- 2L
  testthat::expect_match(scanner$ledgr_hot_path_diff(grown, scan), "helper %in%: baseline 1, now 2", fixed = TRUE)
})
