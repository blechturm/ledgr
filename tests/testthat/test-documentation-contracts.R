ledgr_test_source_vignette <- function(file) {
  path <- testthat::test_path("..", "..", "vignettes", file)
  testthat::skip_if_not(file.exists(path), sprintf("source vignette not available during installed-package tests: %s", file))
  path
}

testthat::test_that("strategy docs show feature ID discovery before feature lookup", {
  strategy_doc <- readLines(ledgr_test_source_vignette("strategy-development.Rmd"), warn = FALSE)
  indicators_doc <- readLines(ledgr_test_source_vignette("indicators.Rmd"), warn = FALSE)

  first_strategy_feature_id <- grep("ledgr_feature_id", strategy_doc)[[1]]
  first_strategy_lookup <- grep("\\$feature\\([^)]*\"", strategy_doc)[[1]]
  testthat::expect_lt(first_strategy_feature_id, first_strategy_lookup)

  first_indicator_feature_id <- grep("ledgr_feature_id", indicators_doc)[[1]]
  first_indicator_lookup <- grep("\\$feature\\([^)]*\"", indicators_doc)[[1]]
  testthat::expect_lt(first_indicator_feature_id, first_indicator_lookup)
})

testthat::test_that("indicator docs include compact multi-output ID references", {
  indicators_doc <- paste(readLines(ledgr_test_source_vignette("indicators.Rmd"), warn = FALSE), collapse = "\n")
  ttr_help <- paste(readLines(testthat::test_path("..", "..", "man", "ledgr_ind_ttr.Rd"), warn = FALSE), collapse = "\n")

  testthat::expect_match(indicators_doc, "ttr_bbands_20_up", fixed = TRUE)
  testthat::expect_match(indicators_doc, "ttr_macd_12_26_9_false_macd", fixed = TRUE)
  testthat::expect_match(indicators_doc, "ttr_macd_12_26_9_false_signal", fixed = TRUE)
  testthat::expect_match(indicators_doc, "built-in ledgr indicators and TTR-backed indicators", fixed = TRUE)
  testthat::expect_match(indicators_doc, "Warmup `NA` is expected", fixed = TRUE)
  testthat::expect_match(ttr_help, "\\code{BBands} exposes \\code{dn}, \\code{mavg}, \\code{up}, and", fixed = TRUE)
  testthat::expect_match(ttr_help, "\\code{pctB}", fixed = TRUE)
  testthat::expect_match(indicators_doc, "ledgr_feature_id()", fixed = TRUE)
})

testthat::test_that("helper docs state composition and whole-share target flooring", {
  strategy_doc <- paste(readLines(ledgr_test_source_vignette("strategy-development.Rmd"), warn = FALSE), collapse = "\n")
  root <- testthat::test_path("..", "..")
  target_help <- paste(readLines(file.path(root, "man", "target_rebalance.Rd"), warn = FALSE), collapse = "\n")
  signal_strategy_help <- paste(readLines(file.path(root, "man", "ledgr_signal_strategy.Rd"), warn = FALSE), collapse = "\n")

  testthat::expect_match(strategy_doc, "Execution semantics begin only at the target stage", fixed = TRUE)
  testthat::expect_match(strategy_doc, "floors to whole shares", fixed = TRUE)
  testthat::expect_match(strategy_doc, "signal origin and non-missing count", fixed = TRUE)
  testthat::expect_match(strategy_doc, "There is no `warn_empty = FALSE` argument", fixed = TRUE)
  testthat::expect_match(target_help, "floored to whole numbers", fixed = TRUE)
  testthat::expect_match(target_help, "floor(weight * equity_fraction * equity /", fixed = TRUE)

  testthat::expect_match(signal_strategy_help, "called as \\code{fn(ctx)}", fixed = TRUE)
  testthat::expect_match(signal_strategy_help, "not \\code{params}", fixed = TRUE)
  testthat::expect_match(signal_strategy_help, "\\verb{function(ctx, params)}", fixed = TRUE)
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
  testthat::expect_match(metrics_doc, "Diagnose A Successful Run With Zero Trades", fixed = TRUE)
  testthat::expect_match(metrics_doc, "ledgr_pulse_snapshot()", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Expected warmup is local to the beginning of a run", fixed = TRUE)

  testthat::expect_match(summary_help, "total return", fixed = TRUE)
  testthat::expect_match(summary_help, "annualized volatility", fixed = TRUE)
  testthat::expect_match(summary_help, "time in market", fixed = TRUE)
  testthat::expect_match(summary_help, "closed trade rows", fixed = TRUE)

  testthat::expect_match(results_help, "execution fill rows", fixed = TRUE)
  testthat::expect_match(results_help, "zero-row schema", fixed = TRUE)
  testthat::expect_match(results_help, "action = \"CLOSE\"", fixed = TRUE)
  testthat::expect_match(results_help, "Open positions can affect equity", fixed = TRUE)
})

testthat::test_that("package help exposes an installed-documentation spine", {
  root <- testthat::test_path("..", "..")
  pkg_help <- file.path(root, "man", "ledgr-package.Rd")
  testthat::skip_if_not(file.exists(pkg_help), "package help source not available during installed-package tests")
  text <- paste(readLines(pkg_help, warn = FALSE), collapse = "\n")

  testthat::expect_match(text, "vignette(package = \"ledgr\")", fixed = TRUE)
  testthat::expect_match(text, "system.file(\"doc\", package = \"ledgr\")", fixed = TRUE)
  for (article in c("getting-started", "strategy-development", "metrics-and-accounting", "experiment-store", "indicators")) {
    testthat::expect_match(text, sprintf("vignette(\"%s\", package = \"ledgr\")", article), fixed = TRUE)
    testthat::expect_match(text, sprintf("system.file(\"doc\", \"%s.html\", package = \"ledgr\")", article), fixed = TRUE)
  }
  testthat::expect_no_match(text, "ttr-indicators", fixed = TRUE)
})

testthat::test_that("core help pages point to installed articles with browser-free paths", {
  root <- testthat::test_path("..", "..")
  man_dir <- file.path(root, "man")
  testthat::skip_if_not(dir.exists(man_dir), "man pages not available during installed-package tests")

  expected <- list(
    ledgr_run = c("strategy-development", "metrics-and-accounting"),
    ledgr_experiment = c("strategy-development", "experiment-store"),
    ledgr_backtest = c("strategy-development", "metrics-and-accounting"),
    ledgr_results = "metrics-and-accounting",
    ledgr_compare_runs = c("experiment-store", "metrics-and-accounting"),
    ledgr_snapshot_from_df = "experiment-store",
    ledgr_snapshot_from_csv = "experiment-store",
    ledgr_snapshot_from_yahoo = "experiment-store",
    ledgr_feature_id = "indicators",
    ledgr_ind_returns = "indicators",
    ledgr_ind_ttr = "indicators",
    signal_return = "strategy-development",
    select_top_n = "strategy-development",
    weight_equal = "strategy-development",
    target_rebalance = "strategy-development"
  )

  for (page in names(expected)) {
    path <- file.path(man_dir, paste0(page, ".Rd"))
    text <- paste(readLines(path, warn = FALSE), collapse = "\n")
    for (article in expected[[page]]) {
      testthat::expect_match(text, sprintf("vignette(\"%s\", package = \"ledgr\")", article), fixed = TRUE, info = page)
      testthat::expect_match(text, sprintf("system.file(\"doc\", \"%s.html\", package = \"ledgr\")", article), fixed = TRUE, info = page)
    }
  }
})

testthat::test_that("help-page article links target installed vignettes only", {
  root <- testthat::test_path("..", "..")
  man_dir <- file.path(root, "man")
  vignettes_dir <- file.path(root, "vignettes")
  testthat::skip_if_not(dir.exists(man_dir) && dir.exists(vignettes_dir), "source docs not available during installed-package tests")

  man_text <- paste(unlist(lapply(list.files(man_dir, pattern = "[.]Rd$", full.names = TRUE), readLines, warn = FALSE)), collapse = "\n")
  linked <- unique(unlist(regmatches(
    man_text,
    gregexpr('system[.]file\\("doc", "[^"]+[.]html", package = "ledgr"\\)', man_text)
  )))
  linked_articles <- sub('^system[.]file\\("doc", "([^"]+)[.]html", package = "ledgr"\\)$', "\\1", linked)

  installed_articles <- tools::file_path_sans_ext(basename(list.files(vignettes_dir, pattern = "[.]Rmd$", full.names = TRUE)))
  testthat::expect_true(all(linked_articles %in% installed_articles))
  testthat::expect_true("indicators" %in% installed_articles)
  testthat::expect_false("ttr-indicators" %in% installed_articles)
  testthat::expect_false("who-ledgr-is-for" %in% linked_articles)
  testthat::expect_false("why-r" %in% linked_articles)
})
