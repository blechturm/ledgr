ledgr_test_source_vignette <- function(file) {
  path <- testthat::test_path("..", "..", "vignettes", file)
  testthat::skip_if_not(file.exists(path), sprintf("source vignette not available during installed-package tests: %s", file))
  path
}

testthat::test_that("README and package docs use the package-visible logo asset", {
  root <- testthat::test_path("..", "..")
  source_logo <- file.path(root, "inst", "design", "ledgr_v0_1_7_7_spec_packet", "ledgr.svg")
  package_logo <- file.path(root, "man", "figures", "logo.svg")
  pkgdown_css_path <- file.path(root, "pkgdown", "extra.css")
  readme_rmd_path <- file.path(root, "README.Rmd")
  readme_md_path <- file.path(root, "README.md")
  testthat::skip_if_not(
    file.exists(source_logo) && file.exists(package_logo) && file.exists(pkgdown_css_path) && file.exists(readme_rmd_path) && file.exists(readme_md_path),
    "source README/logo files not available during installed-package tests"
  )
  pkgdown_css <- paste(readLines(pkgdown_css_path, warn = FALSE), collapse = "\n")
  readme_rmd <- paste(readLines(readme_rmd_path, warn = FALSE), collapse = "\n")
  readme_md <- paste(readLines(readme_md_path, warn = FALSE), collapse = "\n")

  testthat::expect_true(file.exists(source_logo))
  testthat::expect_true(file.exists(package_logo))
  testthat::expect_lt(file.info(package_logo)$size, 500 * 1024)
  testthat::expect_match(readme_rmd, 'src="man/figures/logo.svg"', fixed = TRUE)
  testthat::expect_match(readme_md, 'src="man/figures/logo.svg"', fixed = TRUE)
  testthat::expect_match(readme_rmd, 'class="ledgr-readme-logo"', fixed = TRUE)
  testthat::expect_match(readme_md, 'class="ledgr-readme-logo"', fixed = TRUE)
  testthat::expect_no_match(readme_rmd, "<style>", fixed = TRUE)
  testthat::expect_no_match(readme_md, "<style>", fixed = TRUE)
  testthat::expect_match(pkgdown_css, ".template-home .ledgr-readme-logo", fixed = TRUE)
  readme_rmd_logo <- grep("logo.svg", strsplit(readme_rmd, "\n", fixed = TRUE)[[1]], value = TRUE)
  readme_md_logo <- grep("logo.svg", strsplit(readme_md, "\n", fixed = TRUE)[[1]], value = TRUE)
  testthat::expect_no_match(paste(readme_rmd_logo, collapse = "\n"), "C:/|C:\\\\")
  testthat::expect_no_match(paste(readme_md_logo, collapse = "\n"), "C:/|C:\\\\")

  pkgdown_home <- file.path(root, "docs", "index.html")
  if (file.exists(pkgdown_home)) {
    home <- paste(readLines(pkgdown_home, warn = FALSE), collapse = "\n")
    testthat::expect_match(home, "logo.svg", fixed = TRUE)
    testthat::expect_match(home, 'href="extra.css"', fixed = TRUE)
    testthat::expect_match(home, 'class="ledgr-readme-logo"', fixed = TRUE)
    home_logo <- grep("logo.svg", strsplit(home, "\n", fixed = TRUE)[[1]], value = TRUE)
    testthat::expect_no_match(paste(home_logo, collapse = "\n"), "C:/|C:\\\\")
  }
})

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
  testthat::expect_match(indicators_doc, "built-in ledgr indicators, TTR-backed indicators")
  testthat::expect_match(indicators_doc, "SMA crossover", fixed = TRUE)
  testthat::expect_match(indicators_doc, "fast trend above slow trend", fixed = TRUE)
  testthat::expect_match(indicators_doc, "sma_fast", fixed = TRUE)
  testthat::expect_match(indicators_doc, "sma_slow", fixed = TRUE)
  testthat::expect_match(indicators_doc, "RSI is a common mean-reversion input", fixed = TRUE)
  testthat::expect_match(indicators_doc, "rsi_exp <- ledgr_experiment", fixed = TRUE)
  testthat::expect_match(indicators_doc, "rsi_bt <- ledgr_run", fixed = TRUE)
  testthat::expect_match(indicators_doc, "mixed feature map combines a built-in return feature", fixed = TRUE)
  testthat::expect_match(indicators_doc, "return_5", fixed = TRUE)
  testthat::expect_match(indicators_doc, "ttr_rsi_14", fixed = TRUE)
  testthat::expect_match(indicators_doc, "ledgr computes feature contracts into pulse-known data", fixed = TRUE)
  testthat::expect_match(indicators_doc, "ledgr_feature_contracts", fixed = TRUE)
  testthat::expect_match(indicators_doc, "ledgr_pulse_features", fixed = TRUE)
  testthat::expect_match(indicators_doc, "ledgr_pulse_wide", fixed = TRUE)
  testthat::expect_match(indicators_doc, "Parameter Grids Register Every Needed Feature", fixed = TRUE)
  testthat::expect_match(indicators_doc, "ledgr_ind_returns\\(5\\)")
  testthat::expect_match(indicators_doc, "ledgr_ind_returns\\(10\\)")
  testthat::expect_match(indicators_doc, "ledgr_ind_returns\\(20\\)")
  testthat::expect_match(indicators_doc, "params\\$lookback")
  testthat::expect_match(indicators_doc, "register every lookback variant before\\s+the run")
  testthat::expect_match(indicators_doc, "all feature parameter values must be registered before `ledgr_run\\(\\)`")
  testthat::expect_match(indicators_doc, "A missing feature\\s+ID is an unknown-feature error, not warmup.")
  testthat::expect_match(indicators_doc, "{instrument_id}__ohlcv_{field}", fixed = TRUE)
  testthat::expect_match(indicators_doc, "{instrument_id}__feature_{feature_id}", fixed = TRUE)
  testthat::expect_match(indicators_doc, "install.packages\\(\"TTR\"\\)")
  testthat::expect_match(indicators_doc, "choose a timestamp late enough for the indicator warmup", fixed = TRUE)
  testthat::expect_match(indicators_doc, "same TTR feature map to `ledgr_pulse_snapshot()`", fixed = TRUE)
  testthat::expect_match(indicators_doc, "Troubleshoot Warmup And Zero Trades", fixed = TRUE)
  testthat::expect_match(indicators_doc, "available bars are below the feature contract", fixed = TRUE)
  testthat::expect_match(indicators_doc, "`summary(bt)` prints `Warmup Diagnostics`", fixed = TRUE)
  testthat::expect_match(indicators_doc, "Impossible warmup is different", fixed = TRUE)
  testthat::expect_match(ttr_help, "\\code{BBands} exposes \\code{dn}, \\code{mavg}, \\code{up}, and", fixed = TRUE)
  testthat::expect_match(ttr_help, "\\code{pctB}", fixed = TRUE)
  testthat::expect_match(ttr_help, "requires the suggested \\code{TTR} package", fixed = TRUE)
  testthat::expect_match(indicators_doc, "ledgr_feature_id", fixed = TRUE)
})

testthat::test_that("helper docs state composition and whole-share target flooring", {
  strategy_doc <- paste(readLines(ledgr_test_source_vignette("strategy-development.Rmd"), warn = FALSE), collapse = "\n")
  root <- testthat::test_path("..", "..")
  target_help <- paste(readLines(file.path(root, "man", "target_rebalance.Rd"), warn = FALSE), collapse = "\n")
  signal_strategy_help <- paste(readLines(file.path(root, "man", "ledgr_signal_strategy.Rd"), warn = FALSE), collapse = "\n")
  signal_help <- paste(readLines(file.path(root, "man", "signal_return.Rd"), warn = FALSE), collapse = "\n")
  select_help <- paste(readLines(file.path(root, "man", "select_top_n.Rd"), warn = FALSE), collapse = "\n")
  target_rebalance_help <- paste(readLines(file.path(root, "man", "target_rebalance.Rd"), warn = FALSE), collapse = "\n")
  selection_type_help <- paste(readLines(file.path(root, "man", "ledgr_selection.Rd"), warn = FALSE), collapse = "\n")

  testthat::expect_match(strategy_doc, "Execution semantics begin only at the target stage", fixed = TRUE)
  testthat::expect_match(strategy_doc, "floors to whole shares", fixed = TRUE)
  testthat::expect_match(strategy_doc, "signal origin and non-missing count", fixed = TRUE)
  testthat::expect_match(strategy_doc, "There is no `warn_empty = FALSE` argument", fixed = TRUE)
  testthat::expect_match(target_help, "floored to whole numbers", fixed = TRUE)
  testthat::expect_match(target_help, "floor(weight * equity_fraction * equity /", fixed = TRUE)

  testthat::expect_match(signal_strategy_help, "called as \\code{fn(ctx)}", fixed = TRUE)
  testthat::expect_match(signal_strategy_help, "not \\code{params}", fixed = TRUE)
  testthat::expect_match(signal_strategy_help, "\\verb{function(ctx, params)}", fixed = TRUE)
  testthat::expect_match(signal_strategy_help, "vignette(\"strategy-development\", package = \"ledgr\")", fixed = TRUE)
  testthat::expect_match(signal_help, "\\examples{", fixed = TRUE)
  testthat::expect_match(signal_help, "signal_return(ctx, lookback = 5)", fixed = TRUE)
  testthat::expect_match(signal_help, "register every concrete \\verb{return_<lookback>} feature before", fixed = TRUE)
  testthat::expect_match(signal_help, "\\code{ledgr_ind_returns(5)}", fixed = TRUE)
  testthat::expect_match(select_help, "\\code{ledgr_empty_selection}", fixed = TRUE)
  testthat::expect_match(select_help, "\\code{ledgr_partial_selection}", fixed = TRUE)
  testthat::expect_match(target_rebalance_help, "\\code{ledgr_invalid_target_price}", fixed = TRUE)
  testthat::expect_match(target_rebalance_help, "\\code{ledgr_negative_weights}", fixed = TRUE)
  testthat::expect_match(target_rebalance_help, "\\code{ledgr_levered_weights}", fixed = TRUE)
  testthat::expect_match(selection_type_help, "vignette(\"strategy-development\", package = \"ledgr\")", fixed = TRUE)
})

testthat::test_that("feature-map docs preserve teaching order and semantic boundaries", {
  strategy_lines <- readLines(ledgr_test_source_vignette("strategy-development.Rmd"), warn = FALSE)
  strategy_doc <- paste(strategy_lines, collapse = "\n")
  indicators_doc <- paste(readLines(ledgr_test_source_vignette("indicators.Rmd"), warn = FALSE), collapse = "\n")
  root <- testthat::test_path("..", "..")
  feature_map_help <- paste(readLines(file.path(root, "man", "ledgr_feature_map.Rd"), warn = FALSE), collapse = "\n")
  warmup_help <- paste(readLines(file.path(root, "man", "passed_warmup.Rd"), warn = FALSE), collapse = "\n")

  first_scalar_lookup <- grep("ctx\\$feature\\(", strategy_lines)[[1]]
  first_feature_map <- grep("ledgr_feature_map", strategy_lines)[[1]]
  testthat::expect_lt(first_scalar_lookup, first_feature_map)

  testthat::expect_match(strategy_doc, "Feature Maps For Readable Feature Access", fixed = TRUE)
  testthat::expect_match(strategy_doc, "Wrong And Right: Leakage", fixed = TRUE)
  testthat::expect_match(strategy_doc, "tomorrow_close = lead\\(close\\)")
  testthat::expect_match(strategy_doc, "market-data table from which it can\\s+casually index tomorrow's bar")
  testthat::expect_match(strategy_doc, "does not certify that\\s+snapshots, feature definitions, event timestamps")
  testthat::expect_match(strategy_doc, "The strategy still returns an ordinary target vector.", fixed = TRUE)
  testthat::expect_match(strategy_doc, "Plain `features = list(...)` remains valid.", fixed = TRUE)
  testthat::expect_match(strategy_doc, "bt_mapped <- mapped_exp", fixed = TRUE)
  testthat::expect_match(strategy_doc, "Tier 2 is common for strategy functions", fixed = TRUE)
  testthat::expect_match(strategy_doc, "helper-pipeline strategy\\s+below is also tier 2")
  testthat::expect_match(strategy_doc, "alias map object itself\\s+is not recovered")
  testthat::expect_match(strategy_doc, "?ledgr_feature_map", fixed = TRUE)
  testthat::expect_match(strategy_doc, "?passed_warmup", fixed = TRUE)
  testthat::expect_match(strategy_doc, "zero-length input is a classed error", fixed = TRUE)
  testthat::expect_match(strategy_doc, "ledgr_empty_warmup_input", fixed = TRUE)
  testthat::expect_match(strategy_doc, "Debug One Pulse Before Running", fixed = TRUE)
  testthat::expect_match(strategy_doc, "ledgr_pulse_wide(pulse)", fixed = TRUE)
  testthat::expect_match(strategy_doc, "glimpse()", fixed = TRUE)
  testthat::expect_match(strategy_doc, "two ways of looking at the same\\s+pulse-known data")
  testthat::expect_match(indicators_doc, "feature map gives\\s+readable aliases")
  testthat::expect_match(indicators_doc, "feature_id` is the stable engine ID")
  testthat::expect_match(indicators_doc, "Mapped access returns a named numeric vector keyed by alias")
  testthat::expect_match(indicators_doc, "Feature columns use")
  testthat::expect_match(indicators_doc, "The table views and the accessors are not competing APIs", fixed = TRUE)
  testthat::expect_match(indicators_doc, "uses the engine ID, not the alias", fixed = TRUE)
  testthat::expect_match(indicators_doc, "vignette(\"strategy-development\", package = \"ledgr\")", fixed = TRUE)
  testthat::expect_match(feature_map_help, "Plain lists remain valid", fixed = TRUE)
  testthat::expect_match(feature_map_help, "keyed by alias", fixed = TRUE)
  testthat::expect_match(feature_map_help, "ctx$features", fixed = TRUE)
  testthat::expect_match(feature_map_help, "passed_warmup", fixed = TRUE)
  testthat::expect_match(feature_map_help, "x[[\"ret_5\"]]", fixed = TRUE)
  testthat::expect_match(warmup_help, "not a signal pipeline transformation", fixed = TRUE)
  testthat::expect_match(warmup_help, "ledgr_empty_warmup_input", fixed = TRUE)
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

testthat::test_that("retired TTR indicator article is not installed", {
  root <- testthat::test_path("..", "..")
  testthat::expect_false(file.exists(file.path(root, "vignettes", "ttr-indicators.Rmd")))
  testthat::expect_false(file.exists(file.path(root, "inst", "doc", "ttr-indicators.Rmd")))
  testthat::expect_false(file.exists(file.path(root, "inst", "doc", "ttr-indicators.R")))
  testthat::expect_false(file.exists(file.path(root, "inst", "doc", "ttr-indicators.html")))
})

testthat::test_that("README documents noninteractive documentation discovery", {
  root <- testthat::test_path("..", "..")
  readme <- file.path(root, "README.Rmd")
  testthat::skip_if_not(file.exists(readme), "README source not available during installed-package tests")
  text <- paste(readLines(readme, warn = FALSE), collapse = "\n")

  testthat::expect_match(text, "vignette\\(package = \"ledgr\"\\)")
  testthat::expect_match(text, "system.file\\(\"doc\", package = \"ledgr\"\\)")
  testthat::expect_match(text, "noninteractive `Rscript` and agent\\s+workflows")
  testthat::expect_match(text, "The setup is not overhead. The setup is the audit trail.", fixed = TRUE)
})

testthat::test_that("visible docs avoid hidden article helpers", {
  root <- testthat::test_path("..", "..")
  paths <- c(
    file.path(root, "README.Rmd"),
    list.files(file.path(root, "vignettes"), pattern = "[.](Rmd|md)$", full.names = TRUE)
  )
  paths <- paths[file.exists(paths)]
  text <- paste(unlist(lapply(paths, readLines, warn = FALSE)), collapse = "\n")

  testthat::expect_no_match(text, "article_utc\\(")
})

testthat::test_that("first-path navigation avoids non-runnable examples", {
  root <- testthat::test_path("..", "..")
  pkgdown <- file.path(root, "_pkgdown.yml")
  readme <- file.path(root, "README.Rmd")
  testthat::skip_if_not(file.exists(pkgdown) && file.exists(readme), "navigation sources unavailable")
  text <- paste(
    paste(readLines(pkgdown, warn = FALSE), collapse = "\n"),
    paste(readLines(readme, warn = FALSE), collapse = "\n"),
    sep = "\n"
  )

  testthat::expect_no_match(text, "examples/README", fixed = TRUE)
  testthat::expect_no_match(text, "non-executable development artifacts", fixed = TRUE)
})

testthat::test_that("help-page article sections include browser-free installed paths", {
  root <- testthat::test_path("..", "..")
  man_dir <- file.path(root, "man")
  testthat::skip_if_not(dir.exists(man_dir), "man pages not available during installed-package tests")

  paths <- list.files(man_dir, pattern = "[.]Rd$", full.names = TRUE)
  for (path in paths) {
    text <- paste(readLines(path, warn = FALSE), collapse = "\n")
    linked <- unique(unlist(regmatches(
      text,
      gregexpr('vignette\\("[^"]+", package = "ledgr"\\)', text)
    )))
    if (length(linked) == 0L) next
    articles <- sub('^vignette\\("([^"]+)", package = "ledgr"\\)$', "\\1", linked)
    for (article in articles) {
      testthat::expect_match(
        text,
        sprintf('system.file("doc", "%s.html", package = "ledgr")', article),
        fixed = TRUE,
        info = basename(path)
      )
    }
  }
})

testthat::test_that("pkgdown reference lists v0.1.7.4 helper exports", {
  root <- testthat::test_path("..", "..")
  pkgdown <- file.path(root, "_pkgdown.yml")
  testthat::skip_if_not(file.exists(pkgdown), "pkgdown config unavailable")
  text <- paste(readLines(pkgdown, warn = FALSE), collapse = "\n")

  for (fn in c(
    "ledgr_feature_map",
    "passed_warmup",
    "ledgr_feature_contracts",
    "ledgr_pulse_features",
    "ledgr_pulse_wide"
  )) {
    testthat::expect_match(text, paste0("- ", fn), fixed = TRUE)
  }
})

testthat::test_that("NEWS summarizes delivered v0.1.7.4 scope", {
  root <- testthat::test_path("..", "..")
  news <- file.path(root, "NEWS.md")
  testthat::skip_if_not(file.exists(news), "NEWS source unavailable")
  text <- paste(readLines(news, warn = FALSE), collapse = "\n")
  start <- regexpr("# ledgr 0[.]1[.]7[.]4", text)
  end <- regexpr("# ledgr 0[.]1[.]7[.]3", text)
  testthat::expect_true(start > 0L)
  testthat::expect_true(end > start)
  section <- substr(text, start, end - 1L)

  testthat::expect_no_match(section, "Planned:", fixed = TRUE)
  testthat::expect_match(section, "Added feature-map authoring UX", fixed = TRUE)
  testthat::expect_match(section, "Added feature-inspection views", fixed = TRUE)
  testthat::expect_match(section, "Fixed the low-level CSV snapshot create/import/seal workflow", fixed = TRUE)
  testthat::expect_match(section, "stale retired\\s+`ttr-indicators` artifacts")
})

testthat::test_that("NEWS summarizes delivered v0.1.7.5 scope", {
  root <- testthat::test_path("..", "..")
  news <- file.path(root, "NEWS.md")
  testthat::skip_if_not(file.exists(news), "NEWS source unavailable")
  text <- paste(readLines(news, warn = FALSE), collapse = "\n")
  start <- regexpr("# ledgr 0[.]1[.]7[.]5", text)
  end <- regexpr("# ledgr 0[.]1[.]7[.]4", text)
  testthat::expect_true(start > 0L)
  testthat::expect_true(end > start)
  section <- substr(text, start, end - 1L)

  testthat::expect_no_match(section, "Planned:", fixed = TRUE)
  testthat::expect_match(section, "Hardened the TTR adapter", fixed = TRUE)
  testthat::expect_match(section, "MACD warmup boundary", fixed = TRUE)
  testthat::expect_match(section, "warmup diagnostic", fixed = TRUE)
  testthat::expect_match(section, "schema validation probes", fixed = TRUE)
  testthat::expect_match(section, "closed-trade example", fixed = TRUE)
  testthat::expect_match(section, "low-level CSV snapshot bridge", fixed = TRUE)
  testthat::expect_match(section, "feature-map aliases distinct from engine\\s+feature IDs")
  testthat::expect_match(section, "connects to R finance ecosystem packages", fixed = TRUE)
  testthat::expect_no_match(tolower(section), "talib", fixed = TRUE)
})

testthat::test_that("NEWS summarizes delivered v0.1.7.6 persistence scope", {
  root <- testthat::test_path("..", "..")
  news <- file.path(root, "NEWS.md")
  testthat::skip_if_not(file.exists(news), "NEWS source unavailable")
  text <- paste(readLines(news, warn = FALSE), collapse = "\n")
  start <- regexpr("# ledgr 0[.]1[.]7[.]6", text)
  end <- regexpr("# ledgr 0[.]1[.]7[.]5", text)
  testthat::expect_true(start > 0L)
  testthat::expect_true(end > start)
  section <- substr(text, start, end - 1L)

  testthat::expect_no_match(section, "Planned:", fixed = TRUE)
  testthat::expect_match(section, "DuckDB persistence architecture review", fixed = TRUE)
  testthat::expect_match(section, "runtime validators remain read-only", fixed = TRUE)
  testthat::expect_match(section, "`runs.status` and `snapshots.status`", fixed = TRUE)
  testthat::expect_match(section, "fresh-connection persistence tests", fixed = TRUE)
  testthat::expect_match(section, "local WSL/Ubuntu DuckDB gate", fixed = TRUE)
  testthat::expect_match(section, "auditr retrospective", fixed = TRUE)
  testthat::expect_no_match(tolower(section), "talib", fixed = TRUE)
})

testthat::test_that("release playbook preserves v0.1.7.4 post-mortem guardrails", {
  root <- testthat::test_path("..", "..")
  playbook <- file.path(root, "inst", "design", "release_ci_playbook.md")
  testthat::skip_if_not(file.exists(playbook), "release playbook unavailable")
  text <- paste(readLines(playbook, warn = FALSE), collapse = "\n")

  testthat::expect_match(text, "gh run view <run-id> --repo blechturm/ledgr --log-failed", fixed = TRUE)
  testthat::expect_match(text, "Remote CI logs define the initial scope", fixed = TRUE)
  testthat::expect_match(text, "ROLLBACK", fixed = TRUE)
  testthat::expect_match(text, "DuckDB Constraint Probe Rule", fixed = TRUE)
  testthat::expect_match(text, "Stop Rule", fixed = TRUE)
  testthat::expect_match(text, "stop and request review", fixed = TRUE)
})

testthat::test_that("release playbook records v0.1.7.6 Ubuntu and DuckDB gates", {
  root <- testthat::test_path("..", "..")
  playbook <- file.path(root, "inst", "design", "release_ci_playbook.md")
  testthat::skip_if_not(file.exists(playbook), "release playbook unavailable")
  text <- paste(readLines(playbook, warn = FALSE), collapse = "\n")

  testthat::expect_match(text, "Local WSL/Ubuntu DuckDB Gate", fixed = TRUE)
  testthat::expect_match(text, "test-schema-validator-side-effects.R", fixed = TRUE)
  testthat::expect_match(text, "test-schema-snapshots.R", fixed = TRUE)
  testthat::expect_match(text, "test-schema.R", fixed = TRUE)
  testthat::expect_match(text, "test-persistence-fresh-connection.R", fixed = TRUE)
  testthat::expect_match(text, "does not replace branch CI", fixed = TRUE)
  testthat::expect_match(text, "tag-triggered CI", fixed = TRUE)
  testthat::expect_match(text, "release certificate", fixed = TRUE)
})

testthat::test_that("contracts record v0.1.7.5 TTR warmup and adapter boundaries", {
  root <- testthat::test_path("..", "..")
  contracts <- file.path(root, "inst", "design", "contracts.md")
  testthat::skip_if_not(file.exists(contracts), "contracts source unavailable")
  text <- paste(readLines(contracts, warn = FALSE), collapse = "\n")

  testthat::expect_match(text, "Derived outputs such as MACD `histogram`", fixed = TRUE)
  testthat::expect_match(text, "aligned warmup `NA_real_` values", fixed = TRUE)
  testthat::expect_match(text, "without\\s+calling `series_fn\\(\\)` when `nrow\\(bars\\) < stable_after`")
  testthat::expect_match(text, "Warmup and zero-trade diagnostics", fixed = TRUE)
  testthat::expect_match(text, "connects to the R finance ecosystem through adapters", fixed = TRUE)
  testthat::expect_no_match(tolower(text), "talib", fixed = TRUE)
})

testthat::test_that("contracts record v0.1.7.6 persistence boundaries", {
  root <- testthat::test_path("..", "..")
  contracts <- file.path(root, "inst", "design", "contracts.md")
  testthat::skip_if_not(file.exists(contracts), "contracts source unavailable")
  text <- paste(readLines(contracts, warn = FALSE), collapse = "\n")

  testthat::expect_match(text, "Cross-connection read-back is part of the persistence contract", fixed = TRUE)
  testthat::expect_match(text, "completed\\s+runs and their `ledger_events`, `features`, and `equity_curve` rows")
  testthat::expect_match(text, "Runtime schema creation and validation must be read-only", fixed = TRUE)
  testthat::expect_match(text, "must\\s+not prove constraints by writing invalid probe rows")
  testthat::expect_match(text, "must fail loudly rather than mutate user rows", fixed = TRUE)
  testthat::expect_match(text, "labels, archives, and tags promise\\s+immediate fresh-connection visibility")
  testthat::expect_match(text, "Best-effort checkpointing is reserved for cleanup paths", fixed = TRUE)
  testthat::expect_match(text, "create/import/seal followed by `ledgr_snapshot_load\\(verify = TRUE\\)`")
})

testthat::test_that("contracts record v0.1.7.7 risk metric boundary", {
  root <- testthat::test_path("..", "..")
  contracts <- file.path(root, "inst", "design", "contracts.md")
  testthat::skip_if_not(file.exists(contracts), "contracts source unavailable")
  text <- paste(readLines(contracts, warn = FALSE), collapse = "\n")

  testthat::expect_match(text, "standard\\s+metric set ships `sharpe_ratio`")
  testthat::expect_match(text, "excess_return[t] = equity_return[t] - rf_period_return[t]", fixed = TRUE)
  testthat::expect_match(text, "0.02` means two percent per year", fixed = TRUE)
  testthat::expect_match(text, "\\(1 \\+ rf_annual\\)\\^\\(1 / bars_per_year\\) - 1")
  testthat::expect_match(text, "Time-varying risk-free-rate series and real data providers", fixed = TRUE)
  testthat::expect_match(text, "FRED", fixed = TRUE)
  testthat::expect_match(text, "must not silently assume daily bars", fixed = TRUE)
  testthat::expect_match(text, "Infinite Sharpe values\\s+must not\\s+be emitted silently")
  testthat::expect_match(text, "Sortino, Calmar, Omega, information ratio", fixed = TRUE)
})

testthat::test_that("contracts record v0.1.7.8 strategy preflight boundary", {
  root <- testthat::test_path("..", "..")
  contracts <- file.path(root, "inst", "design", "contracts.md")
  testthat::skip_if_not(file.exists(contracts), "contracts source unavailable")
  text <- paste(readLines(contracts, warn = FALSE), collapse = "\n")

  testthat::expect_match(text, "ledgr_v0_1_7_8_spec_packet", fixed = TRUE)
  testthat::expect_match(text, "Strategy preflight classifies functional strategies before execution", fixed = TRUE)
  testthat::expect_match(text, "Tier 3\\s+is a classed error by default")
  testthat::expect_match(text, "must not be\\s+accepted silently or downgraded to warning-only behavior")
  testthat::expect_match(text, "v0.1.7.8 does not\\s+implement a single-run override")
  testthat::expect_match(text, "forced Tier 3 runs must still record `tier_3` in provenance", fixed = TRUE)
  testthat::expect_match(text, "Priority: base", fixed = TRUE)
  testthat::expect_match(text, "Priority: recommended", fixed = TRUE)
  testthat::expect_match(text, "not from\\s+a hand-maintained package-name allowlist")
  testthat::expect_match(text, "Package-qualified calls to packages outside the active R distribution", fixed = TRUE)
  testthat::expect_match(text, "resolved non-function closure objects", fixed = TRUE)
  testthat::expect_match(text, "Ledgr's exported public namespace is Tier 1-compatible", fixed = TRUE)
  testthat::expect_match(text, "signal_return()", fixed = TRUE)
  testthat::expect_match(text, "select_top_n()", fixed = TRUE)
  testthat::expect_match(text, "passed_warmup()", fixed = TRUE)
  testthat::expect_match(text, "Static analysis is not a proof of semantic reproducibility", fixed = TRUE)
  testthat::expect_match(text, "codetools::findGlobals()", fixed = TRUE)
  testthat::expect_match(text, "closures that\\s+mutate captured environments")
  testthat::expect_match(text, "minimum `ledgr_strategy_preflight` result contract", fixed = TRUE)
  for (field in c("tier", "allowed", "reason", "unresolved_symbols", "package_dependencies", "notes")) {
    testthat::expect_match(text, field, fixed = TRUE)
  }
  testthat::expect_match(text, "`allowed` is\\s+`TRUE` for `tier_1` and `tier_2`, and `FALSE` for `tier_3`")
  testthat::expect_match(text, "Future sweep mode inherits the v0.1.7.8 preflight semantics", fixed = TRUE)
})

testthat::test_that("contracts record v0.1.8 fold-core and output-handler boundary", {
  root <- testthat::test_path("..", "..")
  contracts <- file.path(root, "inst", "design", "contracts.md")
  testthat::skip_if_not(file.exists(contracts), "contracts source unavailable")
  text <- paste(readLines(contracts, warn = FALSE), collapse = "\n")

  testthat::expect_match(text, "fold-core/output-handler boundary", fixed = TRUE)
  testthat::expect_match(text, "The fold core is the deterministic per-pulse\\s+execution engine")
  testthat::expect_match(text, "pulse calendar order", fixed = TRUE)
  testthat::expect_match(text, "context construction", fixed = TRUE)
  testthat::expect_match(text, "strategy invocation", fixed = TRUE)
  testthat::expect_match(text, "target validation", fixed = TRUE)
  testthat::expect_match(text, "fill timing", fixed = TRUE)
  testthat::expect_match(text, "final-bar no-fill\\s+behavior")
  testthat::expect_match(text, "canonical in-memory event\\s+stream")
  testthat::expect_match(text, "The output handler is the persistence or accumulation layer", fixed = TRUE)
  testthat::expect_match(text, "`ledger_events`", fixed = TRUE)
  testthat::expect_match(text, "`features`", fixed = TRUE)
  testthat::expect_match(text, "`strategy_state`", fixed = TRUE)
  testthat::expect_match(text, "`equity_curve`", fixed = TRUE)
  testthat::expect_match(text, "Future `ledgr_run\\(\\)` and `ledgr_sweep\\(\\)` must call the same fold core")
  testthat::expect_match(text, "Sweep\\s+mode may use a cheaper output handler")
  testthat::expect_match(text, "must not change\\s+strategy semantics")
  testthat::expect_match(text, "event-stream meaning", fixed = TRUE)
  testthat::expect_match(text, "Strategy preflight runs before entering the fold core", fixed = TRUE)
  testthat::expect_match(text, "Tier 3 strategies must stop before any fold execution or output\\s+handler side effects")
})

testthat::test_that("roadmap preserves v0.1.7.6 to v0.1.8 sequencing", {
  root <- testthat::test_path("..", "..")
  roadmap <- file.path(root, "inst", "design", "ledgr_roadmap.md")
  testthat::skip_if_not(file.exists(roadmap), "roadmap unavailable")
  text <- paste(readLines(roadmap, warn = FALSE), collapse = "\n")

  for (version in c("0[.]1[.]7[.]6", "0[.]1[.]7[.]7", "0[.]1[.]7[.]8", "0[.]1[.]7[.]9", "0[.]1[.]8", "0[.]1[.]8[.]1")) {
    testthat::expect_match(text, paste0("## v", version))
  }
  testthat::expect_match(text, "DuckDB Persistence Architecture Review", fixed = TRUE)
  testthat::expect_match(text, "Risk Metrics Contract", fixed = TRUE)
  testthat::expect_match(text, "Strategy Reproducibility Preflight", fixed = TRUE)
  testthat::expect_match(text, "Lightweight Parameter Sweep Mode", fixed = TRUE)
  testthat::expect_match(text, "Reference Data And Risk-Free Rate Adapters", fixed = TRUE)
  testthat::expect_match(text, "They are not\\s+roadmap drivers and must not block this metric milestone or v0.1.8")
})

testthat::test_that("README and package help state adapter positioning", {
  root <- testthat::test_path("..", "..")
  readme <- file.path(root, "README.Rmd")
  pkg_help <- file.path(root, "man", "ledgr-package.Rd")
  testthat::skip_if_not(file.exists(readme) && file.exists(pkg_help), "README or package help unavailable")
  readme_text <- paste(readLines(readme, warn = FALSE), collapse = "\n")
  help_text <- paste(readLines(pkg_help, warn = FALSE), collapse = "\n")

  testthat::expect_match(readme_text, "ledgr connects to the R finance ecosystem through adapters.", fixed = TRUE)
  testthat::expect_match(readme_text, "## Ecosystem", fixed = TRUE)
  testthat::expect_match(readme_text, "data -> pulse -> decision -> fill -> ledger event -> portfolio\\s+state")
  testthat::expect_match(readme_text, "ledgr owns", fixed = TRUE)
  testthat::expect_match(readme_text, "Other packages can own", fixed = TRUE)
  testthat::expect_match(readme_text, "all-in-one charting or\\s+array-backtesting package")
  testthat::expect_match(readme_text, "adapter boundary to be explicit", fixed = TRUE)
  testthat::expect_no_match(tolower(readme_text), "talib", fixed = TRUE)

  testthat::expect_match(help_text, "\\section{Ecosystem}", fixed = TRUE)
  testthat::expect_match(help_text, "connects to the R finance ecosystem through adapters", fixed = TRUE)
  testthat::expect_match(help_text, "canonical\\s+execution path remains unchanged")
  testthat::expect_match(help_text, "not intended to replace every finance package", fixed = TRUE)
  testthat::expect_match(help_text, "Who ledgr is for", fixed = TRUE)
  testthat::expect_no_match(tolower(help_text), "talib", fixed = TRUE)
})

testthat::test_that("auditr harness discovery bug is recorded externally", {
  root <- testthat::test_path("..", "..")
  triage <- file.path(root, "inst", "design", "ledgr_v0_1_7_4_spec_packet", "ledgr_triage_report.md")
  testthat::skip_if_not(file.exists(triage), "triage report unavailable")
  text <- paste(readLines(triage, warn = FALSE), collapse = "\n")

  testthat::expect_match(text, "External Follow-Ups", fixed = TRUE)
  testthat::expect_match(text, "DOC_DISCOVERY.R", fixed = TRUE)
  testthat::expect_match(text, "n = Inf", fixed = TRUE)
  testthat::expect_match(text, "not a ledgr package API requirement", fixed = TRUE)
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
  testthat::expect_match(metrics_doc, "compact fixture helper for accounting\\s+examples")
  testthat::expect_match(metrics_doc, "snapshot -> `ledgr_experiment\\(\\)` -> `ledgr_run\\(\\)`")
  testthat::expect_match(metrics_doc, "requires_bars", fixed = TRUE)
  testthat::expect_match(metrics_doc, "stable_after", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Warmup is per instrument", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Warmup Diagnostics", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Three Warmup-Adjacent Cases", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Ordinary feature warmup", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Impossible warmup", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Current-bar absence", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Ledger Events", fixed = TRUE)
  testthat::expect_match(metrics_doc, "append-only accounting record", fixed = TRUE)
  testthat::expect_match(metrics_doc, "what = \"metrics\"", fixed = TRUE)
  testthat::expect_match(metrics_doc, "There is no `what = \"metrics\"` result table", fixed = TRUE)
  testthat::expect_match(metrics_doc, "LEDGR_LAST_BAR_NO_FILL", fixed = TRUE)
  testthat::expect_match(metrics_doc, "ledgr_pulse_snapshot()", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Ordinary feature warmup is local to the beginning of each instrument's usable\\s+sample")
  testthat::expect_match(metrics_doc, "Risk Metric Contract", fixed = TRUE)
  testthat::expect_match(metrics_doc, "sharpe_ratio", fixed = TRUE)
  testthat::expect_match(metrics_doc, "excess_return[t] = equity_return[t] - rf_period_return[t]", fixed = TRUE)
  testthat::expect_match(metrics_doc, "0.02` means two percent per year", fixed = TRUE)
  testthat::expect_match(metrics_doc, "rf_period_return = \\(1 \\+ rf_annual\\)\\^\\(1 / bars_per_year\\) - 1")
  testthat::expect_match(metrics_doc, "sd\\(excess_return\\) <= .Machine\\$double.eps")
  testthat::expect_match(metrics_doc, "Time-varying risk-free-rate series and real data providers", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Sortino, Calmar, Omega, information ratio", fixed = TRUE)

  testthat::expect_match(summary_help, "total return", fixed = TRUE)
  testthat::expect_match(summary_help, "annualized volatility", fixed = TRUE)
  testthat::expect_match(summary_help, "Sharpe ratio", fixed = TRUE)
  testthat::expect_match(summary_help, "risk_free_rate", fixed = TRUE)
  testthat::expect_match(summary_help, "time in market", fixed = TRUE)
  testthat::expect_match(summary_help, "closed trade rows", fixed = TRUE)
  testthat::expect_match(summary_help, "Warmup Diagnostics", fixed = TRUE)
  testthat::expect_match(summary_help, "metrics-and-accounting.html", fixed = TRUE)
  compare_help <- paste(readLines(file.path(root, "man", "ledgr_compare_runs.Rd"), warn = FALSE), collapse = "\n")
  testthat::expect_match(compare_help, "raw numeric values for ranking", fixed = TRUE)
  testthat::expect_match(compare_help, "formatted percentages are a print-only concern", fixed = TRUE)
  testthat::expect_match(compare_help, "default risk-free rate of", fixed = TRUE)
  testthat::expect_match(compare_help, "\\code{0}", fixed = TRUE)
  testthat::expect_match(compare_help, "non-zero risk-free rate", fixed = TRUE)

  testthat::expect_match(results_help, "execution fill rows", fixed = TRUE)
  testthat::expect_match(results_help, "zero-row schema", fixed = TRUE)
  testthat::expect_match(results_help, "action = \"CLOSE\"", fixed = TRUE)
  testthat::expect_match(results_help, "Open positions can affect equity", fixed = TRUE)
  testthat::expect_match(results_help, "does not support \\code{what = \"metrics\"}", fixed = TRUE)
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
    ledgr_experiment = c("strategy-development", "experiment-store", "reproducibility"),
    ledgr_backtest = c("strategy-development", "metrics-and-accounting"),
    ledgr_results = "metrics-and-accounting",
    ledgr_compare_runs = c("experiment-store", "metrics-and-accounting"),
    ledgr_snapshot_from_df = "experiment-store",
    ledgr_snapshot_from_csv = "experiment-store",
    ledgr_snapshot_from_yahoo = "experiment-store",
    ledgr_snapshot_create = "experiment-store",
    ledgr_snapshot_import_bars_csv = "experiment-store",
    ledgr_snapshot_seal = "experiment-store",
    ledgr_snapshot_load = "experiment-store",
    ledgr_snapshot_info = "experiment-store",
    ledgr_feature_id = "indicators",
    ledgr_feature_contracts = "indicators",
    ledgr_ind_returns = "indicators",
    ledgr_ind_ttr = "indicators",
    ledgr_pulse_features = "indicators",
    ledgr_pulse_wide = "indicators",
    ledgr_signal_strategy = "strategy-development",
    ledgr_signal = "strategy-development",
    ledgr_selection = "strategy-development",
    ledgr_weights = "strategy-development",
    ledgr_target = "strategy-development",
    signal_return = "strategy-development",
    select_top_n = "strategy-development",
    weight_equal = "strategy-development",
    target_rebalance = "strategy-development",
    ledgr_feature_map = c("strategy-development", "indicators"),
    passed_warmup = c("strategy-development", "indicators"),
    ledgr_strategy_preflight = "reproducibility"
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

testthat::test_that("experiment-store docs show the low-level CSV bridge", {
  doc <- paste(readLines(ledgr_test_source_vignette("experiment-store.Rmd"), warn = FALSE), collapse = "\n")
  root <- testthat::test_path("..", "..")
  info_help <- paste(readLines(file.path(root, "man", "ledgr_snapshot_info.Rd"), warn = FALSE), collapse = "\n")

  testthat::expect_match(doc, "Bridge A Low-Level CSV Import", fixed = TRUE)
  testthat::expect_match(doc, "ledgr_snapshot_create", fixed = TRUE)
  testthat::expect_match(doc, "ledgr_snapshot_import_bars_csv", fixed = TRUE)
  testthat::expect_match(doc, "ledgr_snapshot_seal", fixed = TRUE)
  testthat::expect_match(doc, "ledgr_snapshot_load\\(\\s*csv_db_path,\\s+snapshot_id = csv_snapshot_id,\\s+verify = TRUE")
  testthat::expect_match(doc, "ledgr_experiment", fixed = TRUE)
  testthat::expect_match(doc, "ledgr_run", fixed = TRUE)
  testthat::expect_match(doc, "seal-time\\s+metadata inside it uses `n_bars` and `n_instruments`")
  testthat::expect_match(doc, "Snapshot identity does not\\s+come from that metadata")
  testthat::expect_match(info_help, "start_date, end_date", fixed = TRUE)
  testthat::expect_match(info_help, "Metadata is not part of \\code{snapshot_hash}", fixed = TRUE)
})

testthat::test_that("provenance docs teach safe stored-strategy inspection", {
  root <- testthat::test_path("..", "..")
  readme_path <- file.path(root, "README.Rmd")
  extract_path <- file.path(root, "man", "ledgr_extract_strategy.Rd")
  testthat::skip_if_not(
    file.exists(readme_path) && file.exists(extract_path),
    "source README/help files not available during installed-package tests"
  )
  readme <- paste(readLines(readme_path, warn = FALSE), collapse = "\n")
  exp_doc <- paste(readLines(ledgr_test_source_vignette("experiment-store.Rmd"), warn = FALSE), collapse = "\n")
  extract_help <- paste(readLines(extract_path, warn = FALSE), collapse = "\n")

  testthat::expect_match(readme, "ledgr_extract_strategy\\(snapshot, \"readme_sma_20\", trust = FALSE\\)")
  testthat::expect_match(readme, "without rerunning or evaluating the\\s+strategy source")
  testthat::expect_match(exp_doc, "Inspect Stored Strategy Source", fixed = TRUE)
  testthat::expect_match(exp_doc, "without parsing,\\s+evaluating, or executing the source")
  testthat::expect_match(exp_doc, "Hash verification proves stored-text identity, not code safety", fixed = TRUE)
  testthat::expect_match(exp_doc, "Legacy/pre-provenance runs", fixed = TRUE)
  testthat::expect_match(extract_help, "trust = FALSE", fixed = TRUE)
  testthat::expect_match(extract_help, "trust = TRUE", fixed = TRUE)
  testthat::expect_match(extract_help, "not a code-safety guarantee", fixed = TRUE)
  testthat::expect_match(extract_help, "legacy/pre-provenance runs", ignore.case = TRUE)
  for (article in c("experiment-store", "strategy-development", "reproducibility")) {
    testthat::expect_match(extract_help, sprintf("vignette(\"%s\", package = \"ledgr\")", article), fixed = TRUE)
    testthat::expect_match(extract_help, sprintf("system.file(\"doc\", \"%s.html\", package = \"ledgr\")", article), fixed = TRUE)
  }
})

testthat::test_that("reproducibility article teaches provenance tiers and safe extraction", {
  doc <- paste(readLines(ledgr_test_source_vignette("reproducibility.Rmd"), warn = FALSE), collapse = "\n")
  root <- testthat::test_path("..", "..")
  pkgdown <- paste(readLines(file.path(root, "_pkgdown.yml"), warn = FALSE), collapse = "\n")
  exp_doc <- paste(readLines(ledgr_test_source_vignette("experiment-store.Rmd"), warn = FALSE), collapse = "\n")
  experiment_help <- paste(readLines(file.path(root, "man", "ledgr_experiment.Rd"), warn = FALSE), collapse = "\n")
  preflight_help <- paste(readLines(file.path(root, "man", "ledgr_strategy_preflight.Rd"), warn = FALSE), collapse = "\n")

  testthat::expect_match(pkgdown, "- reproducibility", fixed = TRUE)
  testthat::expect_match(doc, "sealed snapshot", fixed = TRUE)
  testthat::expect_match(doc, "strategy function", fixed = TRUE)
  testthat::expect_match(doc, "strategy parameters", fixed = TRUE)
  testthat::expect_match(doc, "registered feature definitions", fixed = TRUE)
  testthat::expect_no_match(doc, "AAA", fixed = TRUE)
  testthat::expect_match(doc, "stored strategy source", ignore.case = TRUE)
  testthat::expect_match(doc, "trust = FALSE", fixed = TRUE)
  testthat::expect_match(doc, "without parsing, evaluating, or\\s+executing")
  testthat::expect_match(doc, "Hash verification proves stored-text identity, not code safety", fixed = TRUE)
  testthat::expect_match(doc, "Tier 1", fixed = TRUE)
  testthat::expect_match(doc, "Tier 2", fixed = TRUE)
  testthat::expect_match(doc, "Tier 3", fixed = TRUE)
  testthat::expect_match(doc, "There is no\\s+`force = TRUE`\\s+override")
  testthat::expect_match(doc, "renv", fixed = TRUE)
  testthat::expect_match(doc, "Docker", fixed = TRUE)
  testthat::expect_match(doc, "github.com/ropensci/rix", fixed = TRUE)
  testthat::expect_match(doc, "github.com/nbafrank/uvr", fixed = TRUE)
  testthat::expect_match(exp_doc, "vignette\\(\"reproducibility\", package =\\s+\"ledgr\"\\)")
  testthat::expect_match(experiment_help, "vignette(\"reproducibility\", package = \"ledgr\")", fixed = TRUE)
  testthat::expect_match(preflight_help, "vignette(\"reproducibility\", package = \"ledgr\")", fixed = TRUE)
})

testthat::test_that("leakage article teaches boundaries without overclaiming", {
  doc <- paste(readLines(ledgr_test_source_vignette("leakage.Rmd"), warn = FALSE), collapse = "\n")
  strategy_doc <- paste(readLines(ledgr_test_source_vignette("strategy-development.Rmd"), warn = FALSE), collapse = "\n")
  root <- testthat::test_path("..", "..")
  pkgdown <- paste(readLines(file.path(root, "_pkgdown.yml"), warn = FALSE), collapse = "\n")

  testthat::expect_match(pkgdown, "- leakage", fixed = TRUE)
  testthat::expect_match(doc, "lead\\(close\\)")
  testthat::expect_match(doc, "quantile\\(ret_5, 0.75")
  testthat::expect_match(doc, "pulse context", fixed = TRUE)
  testthat::expect_match(doc, "registered indicators", ignore.case = TRUE)
  testthat::expect_match(doc, "series_fn", fixed = TRUE)
  testthat::expect_match(doc, "does not certify that the dataset", fixed = TRUE)
  testthat::expect_match(doc, "survivorship-biased universe", ignore.case = TRUE)
  testthat::expect_match(doc, "research-loop leakage", ignore.case = TRUE)
  testthat::expect_match(doc, "prior training sample", fixed = TRUE)
  testthat::expect_match(doc, "Scalar indicator history", fixed = TRUE)
  testthat::expect_match(doc, "Vectorized feature output", fixed = TRUE)
  testthat::expect_match(doc, "custom-indicators.html", fixed = TRUE)
  testthat::expect_no_match(doc, "Tier 3 strategy dependency", fixed = TRUE)
  testthat::expect_no_match(doc, "forthcoming documentation", fixed = TRUE)
  testthat::expect_false(grepl("ledgr_check_no_lookahead", doc, fixed = TRUE))
  testthat::expect_match(strategy_doc, "vignette\\(\"leakage\", package = \"ledgr\"\\)")
  testthat::expect_false(grepl("has no object from which it can accidentally read tomorrow", strategy_doc, fixed = TRUE))
})

testthat::test_that("custom indicator article replaces stale placeholders", {
  root <- testthat::test_path("..", "..")
  custom_rmd <- file.path(root, "vignettes", "custom-indicators.Rmd")
  custom_md <- file.path(root, "vignettes", "custom-indicators.md")
  interactive_md <- file.path(root, "vignettes", "interactive-strategy-development.md")
  pkgdown <- paste(readLines(file.path(root, "_pkgdown.yml"), warn = FALSE), collapse = "\n")

  testthat::expect_true(file.exists(custom_rmd))
  testthat::expect_true(file.exists(custom_md))
  testthat::expect_false(file.exists(interactive_md))
  testthat::expect_match(pkgdown, "- custom-indicators", fixed = TRUE)

  doc <- paste(readLines(custom_rmd, warn = FALSE), collapse = "\n")
  rendered <- paste(readLines(custom_md, warn = FALSE), collapse = "\n")

  for (text in list(doc, rendered)) {
    testthat::expect_no_match(text, "Full content in v0.1.3", fixed = TRUE)
  }

  testthat::expect_match(doc, "ledgr_indicator", fixed = TRUE)
  testthat::expect_match(doc, "fn\\(window, params\\)")
  testthat::expect_match(doc, "series_fn\\(bars, params\\)")
  testthat::expect_match(doc, "requires_bars", fixed = TRUE)
  testthat::expect_match(doc, "stable_after", fixed = TRUE)
  testthat::expect_match(doc, "NA_real_", fixed = TRUE)
  testthat::expect_match(doc, "post-warmup `NA`, `NaN`, and infinite values are errors", fixed = TRUE)
  testthat::expect_match(doc, "fingerprint", ignore.case = TRUE)
  testthat::expect_match(doc, "Output validation proves shape and value validity", fixed = TRUE)
  testthat::expect_match(doc, "does not prove causal\\s+correctness")
  testthat::expect_match(doc, "ledgr_adapter_r", fixed = TRUE)
  testthat::expect_match(doc, "ledgr_adapter_csv", fixed = TRUE)
  testthat::expect_match(doc, "The CSV values must already respect the simulated decision times", fixed = TRUE)
  testthat::expect_match(doc, "Unknown feature IDs fail loudly", fixed = TRUE)
})

testthat::test_that("snapshot Yahoo and seal docs state lifecycle boundaries", {
  root <- testthat::test_path("..", "..")
  yahoo_path <- file.path(root, "man", "ledgr_snapshot_from_yahoo.Rd")
  seal_path <- file.path(root, "man", "ledgr_snapshot_seal.Rd")
  testthat::skip_if_not(file.exists(yahoo_path) && file.exists(seal_path), "man pages not available during installed-package tests")
  yahoo_help <- paste(readLines(yahoo_path, warn = FALSE), collapse = "\n")
  seal_help <- paste(readLines(seal_path, warn = FALSE), collapse = "\n")

  testthat::expect_match(yahoo_help, "returned handle is already sealed", fixed = TRUE)
  testthat::expect_match(yahoo_help, "quantmod may emit harmless", fixed = TRUE)
  testthat::expect_match(yahoo_help, "S3 method-overwrite messages", fixed = TRUE)
  testthat::expect_match(yahoo_help, "stderr", fixed = TRUE)
  testthat::expect_match(seal_help, "idempotent", fixed = TRUE)
  testthat::expect_match(seal_help, "Already sealed snapshots return their existing hash", fixed = TRUE)
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
