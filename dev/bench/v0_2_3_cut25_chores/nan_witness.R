# Cut 25 (LDG-3269, cut review 25 R3): the independent tests must fail when
# the post-warmup NaN refusal is removed from
# ledgr_normalize_feature_series_output(). Loads the tree, replaces the
# function in the namespace with or without (--fault=none) that refusal, and
# runs test-indicator-evidence.R (LTB-0567) and test-features.R.
#
#   Rscript nan_witness.R --source=<tree> --fault=<none|no_nan_refusal>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), argv, value = TRUE)[[1L]])
  tree <- arg("source")
  fault <- arg("fault")
  pkgload::load_all(tree, quiet = TRUE, compile = FALSE, helpers = TRUE)
  ns <- asNamespace("ledgr")
  if (identical(fault, "no_nan_refusal")) {
    f <- ns$ledgr_normalize_feature_series_output
    b <- as.list(body(f))
    drop <- vapply(b, function(e) grepl("NaN outside the warmup period", paste(deparse(e), collapse = " "), fixed = TRUE),
                   logical(1))
    stopifnot(sum(drop) == 1L)
    body(f) <- as.call(b[!drop])
    unlockBinding("ledgr_normalize_feature_series_output", ns)
    assign("ledgr_normalize_feature_series_output", f, envir = ns)
  } else if (!identical(fault, "none")) {
    stop("unknown fault")
  }
  cat("fault", fault, "\n")
  failed <- 0L
  for (file in c("test-indicator-evidence.R", "test-features.R")) {
    r <- testthat::test_file(file.path(tree, "tests", "testthat", file), reporter = "silent",
                             package = "ledgr", load_package = "none")
    for (res in r) {
      bad <- Filter(function(e) !inherits(e, c("expectation_success", "expectation_skip")), res$results)
      failed <- failed + length(bad)
      if (length(bad)) {
        cat(sprintf("FAIL | %s | %s | failed %d\n", file, res$test, length(bad)))
        for (e in utils::head(bad, 2L)) cat("   NOT OK:", substr(gsub("\\s+", " ", conditionMessage(e)), 1L, 160L), "\n")
      }
    }
  }
  cat(if (failed > 0L) "WITNESS FAIL" else "WITNESS PASS", "\n")
})
