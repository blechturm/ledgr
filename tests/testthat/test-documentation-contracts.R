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

testthat::test_that("background articles stay pkgdown-only", {
  root <- testthat::test_path("..", "..")
  articles <- file.path(root, "vignettes", "articles")
  testthat::skip_if_not(dir.exists(articles), "source articles not available during installed-package tests")

  testthat::expect_true(file.exists(file.path(articles, "who-ledgr-is-for.Rmd")))
  testthat::expect_true(file.exists(file.path(articles, "why-r.Rmd")))
  testthat::expect_false(file.exists(file.path(root, "vignettes", "who-ledgr-is-for.Rmd")))
  testthat::expect_false(file.exists(file.path(root, "vignettes", "why-r.Rmd")))
  testthat::expect_false(file.exists(file.path(root, "inst", "doc", "who-ledgr-is-for.Rmd")))
  testthat::expect_false(file.exists(file.path(root, "inst", "doc", "why-r.Rmd")))
})

testthat::test_that("README documents noninteractive documentation discovery", {
  root <- testthat::test_path("..", "..")
  readme <- file.path(root, "README.Rmd")
  testthat::skip_if_not(file.exists(readme), "README source not available during installed-package tests")
  text <- paste(readLines(readme, warn = FALSE), collapse = "\n")

  testthat::expect_match(text, "vignette\\(package = \"ledgr\"\\)")
  testthat::expect_match(text, "system.file\\(\"doc\", package = \"ledgr\"\\)")
  testthat::expect_match(text, "noninteractive `Rscript` and agent\\s+workflows")
})

testthat::test_that("metrics and accounting docs define public result semantics", {
  metrics_doc <- paste(readLines(ledgr_test_source_vignette("metrics-and-accounting.Rmd"), warn = FALSE), collapse = "\n")
  root <- testthat::test_path("..", "..")
  summary_help <- paste(readLines(file.path(root, "man", "summary.ledgr_backtest.Rd"), warn = FALSE), collapse = "\n")
  results_help <- paste(readLines(file.path(root, "man", "ledgr_results.Rd"), warn = FALSE), collapse = "\n")

  for (term in c(
    "total_return",
    "annualized_return",
    "max_drawdown",
    "volatility",
    "n_trades",
    "win_rate",
    "avg_trade",
    "time_in_market"
  )) {
    testthat::expect_match(metrics_doc, term, fixed = TRUE)
  }

  testthat::expect_match(summary_help, "total return", fixed = TRUE)
  testthat::expect_match(summary_help, "annualized volatility", fixed = TRUE)
  testthat::expect_match(summary_help, "time in market", fixed = TRUE)
  testthat::expect_match(summary_help, "closed trade rows", fixed = TRUE)

  testthat::expect_match(results_help, "execution fill rows", fixed = TRUE)
  testthat::expect_match(results_help, "zero-row schema", fixed = TRUE)
  testthat::expect_match(results_help, "action = \"CLOSE\"", fixed = TRUE)
  testthat::expect_match(results_help, "Open positions can affect equity", fixed = TRUE)
})
