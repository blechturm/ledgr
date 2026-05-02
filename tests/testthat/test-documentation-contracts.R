ledgr_test_source_vignette <- function(file) {
  path <- testthat::test_path("..", "..", "vignettes", file)
  testthat::skip_if_not(file.exists(path), sprintf("source vignette not available during installed-package tests: %s", file))
  path
}

testthat::test_that("strategy docs show feature ID discovery before feature lookup", {
  strategy_doc <- readLines(ledgr_test_source_vignette("strategy-development.Rmd"), warn = FALSE)
  ttr_doc <- readLines(ledgr_test_source_vignette("ttr-indicators.Rmd"), warn = FALSE)

  first_strategy_feature_id <- grep("ledgr_feature_id", strategy_doc)[[1]]
  first_strategy_lookup <- grep("\\$feature\\([^)]*\"", strategy_doc)[[1]]
  testthat::expect_lt(first_strategy_feature_id, first_strategy_lookup)

  first_ttr_feature_id <- grep("ledgr_feature_id", ttr_doc)[[1]]
  first_ttr_lookup <- grep("\\$feature\\([^)]*\"", ttr_doc)[[1]]
  testthat::expect_lt(first_ttr_feature_id, first_ttr_lookup)
})

testthat::test_that("TTR docs include compact multi-output ID references", {
  ttr_doc <- paste(readLines(ledgr_test_source_vignette("ttr-indicators.Rmd"), warn = FALSE), collapse = "\n")

  testthat::expect_match(ttr_doc, "ttr_bbands_20_up", fixed = TRUE)
  testthat::expect_match(ttr_doc, "ttr_macd_12_26_9_false_macd", fixed = TRUE)
  testthat::expect_match(ttr_doc, "ttr_macd_12_26_9_signal", fixed = TRUE)
  testthat::expect_match(ttr_doc, "ledgr_feature_id()", fixed = TRUE)
})
