ledgr_test_source_vignette <- function(file) {
  root <- testthat::test_path("..", "..", "vignettes")
  candidates <- file.path(root, file)
  if (grepl("[.]Rmd$", file)) {
    candidates <- c(candidates, file.path(root, sub("[.]Rmd$", ".qmd", file)))
  }
  if (grepl("[.]qmd$", file)) {
    candidates <- c(candidates, file.path(root, sub("[.]qmd$", ".Rmd", file)))
  }
  existing <- candidates[file.exists(candidates)]
  testthat::skip_if_not(length(existing) > 0, sprintf("source vignette not available during installed-package tests: %s", file))
  path <- existing[[1]]
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
  strategy_doc <- readLines(ledgr_test_source_vignette("strategy-development.qmd"), warn = FALSE)
  indicators_doc <- readLines(ledgr_test_source_vignette("indicators.qmd"), warn = FALSE)

  first_strategy_feature_id <- grep("ledgr_feature_id", strategy_doc)[[1]]
  first_strategy_lookup <- grep("\\$feature\\([^)]*\"", strategy_doc)[[1]]
  testthat::expect_lt(first_strategy_feature_id, first_strategy_lookup)

  first_indicator_feature_id <- grep("ledgr_feature_id", indicators_doc)[[1]]
  first_indicator_lookup <- grep("\\$feature\\([^)]*\"", indicators_doc)[[1]]
  testthat::expect_lt(first_indicator_feature_id, first_indicator_lookup)
})

testthat::test_that("indicator docs include compact multi-output ID references", {
  indicators_doc <- paste(readLines(ledgr_test_source_vignette("indicators.qmd"), warn = FALSE), collapse = "\n")
  ttr_help <- paste(readLines(testthat::test_path("..", "..", "man", "ledgr_ind_ttr.Rd"), warn = FALSE), collapse = "\n")

  testthat::expect_match(indicators_doc, "ttr_bbands_20_up", fixed = TRUE)
  testthat::expect_match(indicators_doc, "The MACD ID embeds the explicit arguments", fixed = TRUE)
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
  testthat::expect_match(indicators_doc, "Native RSI", fixed = TRUE)
  testthat::expect_match(indicators_doc, "ledgr_ind_rsi\\(14\\)")
  testthat::expect_match(indicators_doc, "rsi_14", fixed = TRUE)
  testthat::expect_match(indicators_doc, "ttr_rsi_14", fixed = TRUE)
  testthat::expect_match(indicators_doc, "Feature objects appear in three registration and inspection places", fixed = TRUE)
  testthat::expect_match(indicators_doc, "The strategy context then exposes the computed values through accessors", fixed = TRUE)
  testthat::expect_match(indicators_doc, "Feature Lifecycle: From Declaration To Lookup", fixed = TRUE)
  testthat::expect_match(indicators_doc, "declare<br/>indicator or map", fixed = TRUE)
  testthat::expect_match(indicators_doc, "access<br/>ctx feature methods", fixed = TRUE)
  testthat::expect_match(indicators_doc, "declaration. Static lists and feature maps", fixed = TRUE)
  testthat::expect_match(indicators_doc, "Active-alias features are materialized for concrete", fixed = TRUE)
  testthat::expect_match(indicators_doc, "deduplicates shared indicator\\s+fingerprints")
  testthat::expect_match(indicators_doc, "Feature IDs identify values inside the pulse context", fixed = TRUE)
  testthat::expect_match(indicators_doc, "Fingerprints identify the\\s+feature definition")
  testthat::expect_match(indicators_doc, "output-specific fingerprint", fixed = TRUE)
  testthat::expect_match(indicators_doc, "A feature-map alias never changes\\s+the underlying engine feature ID")
  testthat::expect_match(indicators_doc, "The multi-output bundle helper follows the same lifecycle", fixed = TRUE)
  testthat::expect_match(indicators_doc, "A bundle is an authoring convenience", fixed = TRUE)
  testthat::expect_match(indicators_doc, "ledgr_ind_ttr_outputs", fixed = TRUE)
  testthat::expect_match(indicators_doc, "bbands_dn", fixed = TRUE)
  testthat::expect_match(indicators_doc, "bbands_pctb", fixed = TRUE)
  testthat::expect_match(indicators_doc, "shorter than the hand-written single-output TTR IDs", fixed = TRUE)
  testthat::expect_match(indicators_doc, "naming = c\\(up = \"ttr_bbands_20_up\"\\)")
  testthat::expect_match(indicators_doc, "prefix = NULL", fixed = TRUE)
  testthat::expect_match(indicators_doc, "Raw names are short and can collide", fixed = TRUE)
  testthat::expect_match(indicators_doc, "A single alias on the bundle argument is ignored", fixed = TRUE)
  testthat::expect_match(indicators_doc, "Control the generated feature IDs\\s+with the bundle's `prefix` argument")
  testthat::expect_match(indicators_doc, "`naming` renames selected outputs; it is not itself an output filter", fixed = TRUE)
  testthat::expect_match(indicators_doc, "ctx\\$feature\\(id, feature_id\\)")
  testthat::expect_match(indicators_doc, "ctx\\$features\\(id, feature_map\\)")
  testthat::expect_match(indicators_doc, "ledgr computes indicators into\\s+pulse-known values")
  testthat::expect_match(indicators_doc, "ledgr_feature_contracts", fixed = TRUE)
  testthat::expect_match(indicators_doc, "ledgr_feature_contract_check", fixed = TRUE)
  testthat::expect_match(indicators_doc, "warmup_achievable", fixed = TRUE)
  testthat::expect_match(indicators_doc, "ledgr_pulse_features", fixed = TRUE)
  testthat::expect_match(indicators_doc, "ledgr_pulse_wide", fixed = TRUE)
  testthat::expect_match(indicators_doc, "Parameter Grids Register Every Needed Feature", fixed = TRUE)
  testthat::expect_match(indicators_doc, "ledgr_ind_returns\\(5\\)")
  testthat::expect_match(indicators_doc, "ledgr_ind_returns\\(10\\)")
  testthat::expect_match(indicators_doc, "ledgr_ind_returns\\(20\\)")
  testthat::expect_match(indicators_doc, "ret_5 = list\\(lookback = 5, min_return = 0, qty = 10\\)")
  testthat::expect_no_match(indicators_doc, "lookback = c\\(5, 10, 20\\)")
  testthat::expect_match(indicators_doc, "params\\$lookback")
  testthat::expect_match(indicators_doc, "register every lookback variant before\\s+the run")
  testthat::expect_match(indicators_doc, "all feature parameter values must be registered before `ledgr_run\\(\\)`")
  testthat::expect_match(indicators_doc, "A missing feature\\s+ID is an unknown-feature error,\\s+not warmup")
  testthat::expect_match(indicators_doc, "prefer active\\s+aliases")
  testthat::expect_match(indicators_doc, "ledgr_feature_grid", fixed = TRUE)
  testthat::expect_match(indicators_doc, "ledgr_strategy_grid", fixed = TRUE)
  testthat::expect_match(indicators_doc, "Bundle entries are intentionally flat", fixed = TRUE)
  testthat::expect_match(indicators_doc, "TTR bundle section below", fixed = TRUE)
  testthat::expect_no_match(indicators_doc, "feature factories", ignore.case = TRUE)
  testthat::expect_match(indicators_doc, "{instrument_id}__ohlcv_{field}", fixed = TRUE)
  testthat::expect_match(indicators_doc, "{instrument_id}__feature_{feature_id}", fixed = TRUE)
  testthat::expect_match(indicators_doc, "install.packages\\(\"TTR\"\\)")
  testthat::expect_match(indicators_doc, "choose a timestamp late enough for the indicator warmup", fixed = TRUE)
  testthat::expect_match(indicators_doc, "same TTR feature map to `ledgr_pulse_snapshot()`", fixed = TRUE)
  testthat::expect_match(indicators_doc, "Troubleshoot Warmup And Zero Trades", fixed = TRUE)
  testthat::expect_match(indicators_doc, "Warmup is the period before a known feature", fixed = TRUE)
  testthat::expect_match(indicators_doc, "Change the scalar accessor", fixed = TRUE)
  testthat::expect_match(indicators_doc, "available bars are below the feature contract", fixed = TRUE)
  testthat::expect_match(indicators_doc, "`summary(bt)` prints `Warmup Diagnostics`", fixed = TRUE)
  testthat::expect_match(indicators_doc, "Impossible warmup is different", fixed = TRUE)
  testthat::expect_match(ttr_help, "\\code{BBands} exposes \\code{dn}, \\code{mavg}, \\code{up}, and", fixed = TRUE)
  testthat::expect_match(ttr_help, "\\code{pctB}", fixed = TRUE)
  testthat::expect_match(ttr_help, "ledgr_ind_ttr_outputs", fixed = TRUE)
  ttr_outputs_help <- paste(readLines(testthat::test_path("..", "..", "man", "ledgr_ind_ttr_outputs.Rd"), warn = FALSE), collapse = "\n")
  testthat::expect_match(ttr_outputs_help, "ledgr_indicator_bundle", fixed = TRUE)
  testthat::expect_match(ttr_outputs_help, "prefix", fixed = TRUE)
  testthat::expect_match(ttr_outputs_help, "does not filter outputs", fixed = TRUE)
  testthat::expect_match(ttr_outputs_help, "shorter than equivalent hand-written", fixed = TRUE)
  testthat::expect_match(ttr_outputs_help, "vignette(\"indicators\", package = \"ledgr\")", fixed = TRUE)
  testthat::expect_match(ttr_help, "requires the suggested \\code{TTR} package", fixed = TRUE)
  testthat::expect_match(indicators_doc, "ledgr_feature_id", fixed = TRUE)
})

testthat::test_that("helper docs state composition and whole-share target flooring", {
  strategy_doc <- paste(readLines(ledgr_test_source_vignette("strategy-development.qmd"), warn = FALSE), collapse = "\n")
  root <- testthat::test_path("..", "..")
  target_help <- paste(readLines(file.path(root, "man", "target_rebalance.Rd"), warn = FALSE), collapse = "\n")
  signal_strategy_help <- paste(readLines(file.path(root, "man", "ledgr_signal_strategy.Rd"), warn = FALSE), collapse = "\n")
  signal_help <- paste(readLines(file.path(root, "man", "signal_return.Rd"), warn = FALSE), collapse = "\n")
  select_help <- paste(readLines(file.path(root, "man", "select_top_n.Rd"), warn = FALSE), collapse = "\n")
  target_rebalance_help <- paste(readLines(file.path(root, "man", "target_rebalance.Rd"), warn = FALSE), collapse = "\n")
  selection_type_help <- paste(readLines(file.path(root, "man", "ledgr_selection.Rd"), warn = FALSE), collapse = "\n")
  context_help <- paste(readLines(file.path(root, "man", "ledgr_strategy_context.Rd"), warn = FALSE), collapse = "\n")

  testthat::expect_match(strategy_doc, "Execution semantics begin only at the target stage", fixed = TRUE)
  testthat::expect_match(strategy_doc, "floors to whole shares", fixed = TRUE)
  testthat::expect_match(strategy_doc, "floor\\(equity_fraction \\* ctx\\$equity / ctx\\$close\\(instrument_id\\)\\)")
  testthat::expect_match(strategy_doc, "Affordability is not automatic", fixed = TRUE)
  testthat::expect_match(strategy_doc, "does not check affordability", fixed = TRUE)
  testthat::expect_match(strategy_doc, "target-risk layer is the home", fixed = TRUE)
  testthat::expect_match(strategy_doc, "classed empty selection", fixed = TRUE)
  testthat::expect_match(strategy_doc, "No warning suppression is needed", fixed = TRUE)
  testthat::expect_match(strategy_doc, "Troubleshoot Helper Pipelines", fixed = TRUE)
  testthat::expect_match(strategy_doc, "signal --> selection --> weights --> target_obj --> target_vec", fixed = TRUE)
  testthat::expect_match(strategy_doc, "Only the final target vector is executable", fixed = TRUE)
  testthat::expect_match(strategy_doc, "Returning\\s+a `ledgr_signal`, `ledgr_selection`, `ledgr_weights`")
  testthat::expect_match(strategy_doc, "zero fills or zero trades", fixed = TRUE)
  testthat::expect_match(strategy_doc, "ledgr_results\\(bt_top_1, what = \"fills\"\\)")
  testthat::expect_match(strategy_doc, "Zero fills means no execution occurred", fixed = TRUE)
  testthat::expect_match(strategy_doc, "Non-empty fills with zero trades", fixed = TRUE)
  testthat::expect_match(strategy_doc, "inspect a late pulse", fixed = TRUE)
  testthat::expect_match(strategy_doc, "setdiff\\(pulse\\$universe, names\\(target\\)\\)")
  testthat::expect_match(strategy_doc, "Strategy functions are preflighted before execution", fixed = TRUE)
  testthat::expect_match(strategy_doc, "`ledgr_signal_strategy\\(\\)` is a separate compatibility\\s+wrapper")
  testthat::expect_match(strategy_doc, "A preflight tier is ledgr's static reproducibility classification", fixed = TRUE)
  testthat::expect_match(strategy_doc, "For the full tier model, read", fixed = TRUE)
  testthat::expect_match(strategy_doc, "compact Tier 3 hard-failure example", fixed = TRUE)
  testthat::expect_match(strategy_doc, "outside_helper", fixed = TRUE)
  testthat::expect_match(strategy_doc, "preflight\\$reason")
  testthat::expect_match(strategy_doc, "There is no force override", fixed = TRUE)
  testthat::expect_match(strategy_doc, "If you want to compare variants", fixed = TRUE)
  testthat::expect_match(strategy_doc, "strategy authoring question separate", fixed = TRUE)
  testthat::expect_match(strategy_doc, "?ledgr_strategy_context", fixed = TRUE)
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
  testthat::expect_match(select_help, "without warning", fixed = TRUE)
  testthat::expect_match(select_help, "\\code{ledgr_partial_selection}", fixed = TRUE)
  testthat::expect_match(target_rebalance_help, "\\code{ledgr_invalid_target_price}", fixed = TRUE)
  testthat::expect_match(target_rebalance_help, "\\code{ledgr_negative_weights}", fixed = TRUE)
  testthat::expect_match(target_rebalance_help, "\\code{ledgr_levered_weights}", fixed = TRUE)
  testthat::expect_match(selection_type_help, "vignette(\"strategy-development\", package = \"ledgr\")", fixed = TRUE)
  testthat::expect_match(context_help, "\\code{ctx$feature(id, feature_id)}", fixed = TRUE)
  testthat::expect_match(context_help, "\\code{ctx$idx(id)}", fixed = TRUE)
  testthat::expect_match(context_help, "\\code{ctx$vec$feature(feature_id)}", fixed = TRUE)
  testthat::expect_match(context_help, "\\code{ctx$vec$positions}", fixed = TRUE)
  testthat::expect_match(context_help, "\\code{ctx$features(id, feature_map)}", fixed = TRUE)
  testthat::expect_match(context_help, "\\code{ctx$flat()}", fixed = TRUE)
  testthat::expect_match(context_help, "\\code{ctx$hold()}", fixed = TRUE)
  testthat::expect_match(context_help, "Feature Object Compatibility", fixed = TRUE)
})

testthat::test_that("feature-map docs preserve teaching order and semantic boundaries", {
  strategy_lines <- readLines(ledgr_test_source_vignette("strategy-development.qmd"), warn = FALSE)
  strategy_doc <- paste(strategy_lines, collapse = "\n")
  indicators_doc <- paste(readLines(ledgr_test_source_vignette("indicators.qmd"), warn = FALSE), collapse = "\n")
  root <- testthat::test_path("..", "..")
  feature_map_help <- paste(readLines(file.path(root, "man", "ledgr_feature_map.Rd"), warn = FALSE), collapse = "\n")
  warmup_help <- paste(readLines(file.path(root, "man", "passed_warmup.Rd"), warn = FALSE), collapse = "\n")

  first_scalar_lookup <- grep("ctx\\$feature\\(", strategy_lines)[[1]]
  first_feature_map <- grep("ledgr_feature_map", strategy_lines)[[1]]
  testthat::expect_lt(first_scalar_lookup, first_feature_map)

  testthat::expect_match(strategy_doc, "Feature Maps For Readable Feature Access", fixed = TRUE)
  testthat::expect_match(strategy_doc, "A target vector is the strategy's requested holdings", fixed = TRUE)
  testthat::expect_match(strategy_doc, "`ctx` is the pulse context", fixed = TRUE)
  testthat::expect_match(strategy_doc, "pulse t state<br/>bars through t", fixed = TRUE)
  testthat::expect_match(strategy_doc, "strategy\\(ctx, params\\)")
  testthat::expect_match(strategy_doc, "Change `buy_if_up\\(\\)`")
  testthat::expect_match(strategy_doc, "`params` is the run's strategy configuration", fixed = TRUE)
  testthat::expect_match(strategy_doc, "Wrong And Right: Leakage", fixed = TRUE)
  testthat::expect_match(strategy_doc, "tomorrow_close = lead\\(close\\)")
  testthat::expect_match(strategy_doc, "market-data table from which it can\\s+casually index tomorrow's bar")
  testthat::expect_match(strategy_doc, "does not certify that\\s+snapshots, feature definitions, event timestamps")
  testthat::expect_match(strategy_doc, "The strategy still returns an ordinary target vector.", fixed = TRUE)
  testthat::expect_match(strategy_doc, "Plain `features = list(...)` remains valid.", fixed = TRUE)
  testthat::expect_match(strategy_doc, "Do not declare or rebuild features inside a strategy", fixed = TRUE)
  testthat::expect_match(strategy_doc, "Strategy code\\s+should read pulse-known values from the context")
  testthat::expect_match(strategy_doc, "For exploratory sweeps over indicator parameters", fixed = TRUE)
  testthat::expect_match(strategy_doc, "vignette\\(\"sweeps\", package = \"ledgr\"\\)")
  testthat::expect_no_match(strategy_doc, "feature factory", ignore.case = TRUE)
  testthat::expect_match(strategy_doc, "bt_mapped <- mapped_exp", fixed = TRUE)
  testthat::expect_match(strategy_doc, "Keep that\\s+construction code with the research record")
  testthat::expect_match(strategy_doc, "recovered strategy source may still\\s+reference the original alias-map object by name")
  testthat::expect_match(strategy_doc, "read\\s+`vignette\\(\"reproducibility\", package = \"ledgr\"\\)`")
  testthat::expect_match(strategy_doc, "?ledgr_feature_map", fixed = TRUE)
  testthat::expect_match(strategy_doc, "?passed_warmup", fixed = TRUE)
  testthat::expect_match(strategy_doc, "Debug One Pulse Before Running", fixed = TRUE)
  testthat::expect_match(strategy_doc, "ledgr_pulse_wide(pulse)", fixed = TRUE)
  testthat::expect_match(strategy_doc, "glimpse()", fixed = TRUE)
  testthat::expect_match(strategy_doc, "two ways of looking at the same\\s+pulse-known data")
  testthat::expect_match(indicators_doc, "feature map gives\\s+your strategy code readable aliases")
  testthat::expect_match(indicators_doc, "feature_id` is the stable engine ID")
  testthat::expect_match(indicators_doc, "Mapped access returns a named numeric vector keyed by alias")
  testthat::expect_match(indicators_doc, "Feature columns\\s+use")
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

  testthat::expect_true(file.exists(file.path(articles, "who-ledgr-is-for.qmd")))
  testthat::expect_true(file.exists(file.path(articles, "why-r.qmd")))
  testthat::expect_false(file.exists(file.path(articles, "who-ledgr-is-for.Rmd")))
  testthat::expect_false(file.exists(file.path(articles, "why-r.Rmd")))
  testthat::expect_false(file.exists(file.path(root, "vignettes", "who-ledgr-is-for.Rmd")))
  testthat::expect_false(file.exists(file.path(root, "vignettes", "why-r.Rmd")))
  testthat::expect_false(file.exists(file.path(root, "inst", "doc", "who-ledgr-is-for.Rmd")))
  testthat::expect_false(file.exists(file.path(root, "inst", "doc", "why-r.Rmd")))
})

testthat::test_that("retired TTR indicator article is not installed", {
  root <- testthat::test_path("..", "..")
  testthat::expect_false(file.exists(file.path(root, "vignettes", "ttr-indicators.qmd")))
  testthat::expect_false(file.exists(file.path(root, "inst", "doc", "ttr-indicators.qmd")))
  testthat::expect_false(file.exists(file.path(root, "inst", "doc", "ttr-indicators.R")))
  testthat::expect_false(file.exists(file.path(root, "inst", "doc", "ttr-indicators.html")))
})

testthat::test_that("README documents public documentation discovery", {
  root <- testthat::test_path("..", "..")
  readme <- file.path(root, "README.Rmd")
  testthat::skip_if_not(file.exists(readme), "README source not available during installed-package tests")
  text <- paste(readLines(readme, warn = FALSE), collapse = "\n")

  testthat::expect_match(text, "vignette\\(package = \"ledgr\"\\)")
  testthat::expect_match(text, "https://blechturm.github.io/ledgr/", fixed = TRUE)
  testthat::expect_no_match(text, "system.file(\"doc\"", fixed = TRUE)
  testthat::expect_no_match(text, "Design packets are in", fixed = TRUE)
  testthat::expect_match(text, "The setup is not overhead. The setup is the audit trail.", fixed = TRUE)
  testthat::expect_match(text, "Pre-CRAN Compatibility", fixed = TRUE)
  testthat::expect_match(text, "without backward compatibility or a deprecation cycle", fixed = TRUE)
  testthat::expect_match(text, "Once ledgr is released on CRAN", fixed = TRUE)
})

testthat::test_that("visible docs avoid hidden article helpers", {
  root <- testthat::test_path("..", "..")
  paths <- c(
    file.path(root, "README.Rmd"),
    list.files(file.path(root, "vignettes"), pattern = "[.](Rmd|qmd|md)$", full.names = TRUE)
  )
  paths <- paths[file.exists(paths)]
  text <- paste(unlist(lapply(paths, readLines, warn = FALSE)), collapse = "\n")

  testthat::expect_no_match(text, "article_utc\\(")
})

testthat::test_that("first-path navigation avoids non-runnable examples", {
  root <- testthat::test_path("..", "..")
  pkgdown <- file.path(root, "_pkgdown.yml")
  readme <- file.path(root, "README.Rmd")
  examples_readme <- file.path(root, "inst", "examples", "README.md")
  testthat::skip_if_not(file.exists(pkgdown) && file.exists(readme), "navigation sources unavailable")
  text <- paste(
    paste(readLines(pkgdown, warn = FALSE), collapse = "\n"),
    paste(readLines(readme, warn = FALSE), collapse = "\n"),
    sep = "\n"
  )

  testthat::expect_no_match(text, "examples/README", fixed = TRUE)
  testthat::expect_no_match(text, "non-executable development artifacts", fixed = TRUE)
  if (file.exists(examples_readme)) {
    examples_text <- paste(readLines(examples_readme, warn = FALSE), collapse = "\n")
    testthat::expect_match(examples_text, "not a user-facing first-run path", fixed = TRUE)
    testthat::expect_match(examples_text, "vignette\\(package = \"ledgr\"\\)")
    testthat::expect_no_match(examples_text, "no implementations yet", fixed = TRUE)
  }
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

testthat::test_that("v0.1.9.1 release surfaces record cost API state without future claims", {
  root <- testthat::test_path("..", "..")
  doc_paths <- list(
    news = file.path(root, "NEWS.md"),
    roadmap = file.path(root, "inst", "design", "ledgr_roadmap.md"),
    design_index = file.path(root, "inst", "design", "README.md"),
    rfc_index = file.path(root, "inst", "design", "rfc", "README.md"),
    horizon = file.path(root, "inst", "design", "horizon.md"),
    batch_plan = file.path(root, "inst", "design", "ledgr_v0_1_9_1_spec_packet", "batch_plan.md"),
    tickets = file.path(root, "inst", "design", "ledgr_v0_1_9_1_spec_packet", "v0_1_9_1_tickets.md"),
    tickets_yml = file.path(root, "inst", "design", "ledgr_v0_1_9_1_spec_packet", "tickets.yml")
  )
  testthat::skip_if_not(all(file.exists(unlist(doc_paths))), "source release-surface docs not available during installed-package tests")

  news <- paste(readLines(doc_paths$news, warn = FALSE), collapse = "\n")
  roadmap <- paste(readLines(doc_paths$roadmap, warn = FALSE), collapse = "\n")
  design_index <- paste(readLines(doc_paths$design_index, warn = FALSE), collapse = "\n")
  rfc_index <- paste(readLines(doc_paths$rfc_index, warn = FALSE), collapse = "\n")
  horizon <- paste(readLines(doc_paths$horizon, warn = FALSE), collapse = "\n")
  batch_plan <- paste(readLines(doc_paths$batch_plan, warn = FALSE), collapse = "\n")
  tickets <- paste(readLines(doc_paths$tickets, warn = FALSE), collapse = "\n")
  tickets_yml <- paste(readLines(doc_paths$tickets_yml, warn = FALSE), collapse = "\n")

  start <- regexpr("# ledgr 0[.]1[.]9[.]1", news)
  end <- regexpr("# ledgr 0[.]1[.]8[.]11", news)
  testthat::expect_true(start > 0L)
  testthat::expect_true(end > start)
  section <- substr(news, start, end - 1L)

  for (term in c(
    "public transaction-cost API",
    "ledgr_cost_chain()",
    "ledgr_timing_next_open()",
    "cost_model_hash",
    "cost_plan_json",
    "fill_model",
    "timing_model",
    "required `cost_model`",
    "ledgr_cost_zero()",
    "commission_fixed",
    "fee",
    "THEME-004",
    "feature_set_hash",
    "fixed experiment inputs in v1"
  )) {
    testthat::expect_match(section, term, fixed = TRUE)
  }
  testthat::expect_match(section, "Sweep artifact persistence, target risk, and\\s+walk-forward remain future v0.1.9.x packets")

  testthat::expect_match(roadmap, "**Latest completed packet:** `inst/design/ledgr_v0_1_9_1_spec_packet/`", fixed = TRUE)
  testthat::expect_match(roadmap, "| v0.1.9.1 | Done | Public transaction-cost model API", fixed = TRUE)
  testthat::expect_match(roadmap, "v0.1.9.2 | Planned", fixed = TRUE)
  testthat::expect_match(roadmap, "v0.1.9.3 | Planned", fixed = TRUE)
  testthat::expect_match(roadmap, "v0.1.9.4 | Planned", fixed = TRUE)

  testthat::expect_match(design_index, "Latest completed release packet:** `v0.1.9.1`", fixed = TRUE)
  testthat::expect_match(design_index, "Current active packet:** None", fixed = TRUE)
  testthat::expect_match(design_index, "manual/identity_contract.qmd", fixed = TRUE)
  testthat::expect_match(design_index, "rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md", fixed = TRUE)
  testthat::expect_match(design_index, "v0.1.9.1 packet is complete", fixed = TRUE)

  testthat::expect_match(rfc_index, "v0.1.9.1 implements the first public transaction-cost API", fixed = TRUE)
  testthat::expect_match(rfc_index, "../manual/identity_contract.qmd", fixed = TRUE)
  testthat::expect_match(rfc_index, "Liquidity, quantity mutation, broker templates, and function-valued user models remain downstream", fixed = TRUE)

  resolved_pos <- regexpr("\n## Resolved\n", horizon, fixed = TRUE)[[1]]
  cost_pos <- regexpr("v0.1.9.1 cost-API spec-cut decisions", horizon, fixed = TRUE)[[1]]
  sweep_pos <- regexpr("v0.1.9.2 sweep artifact persistence RFC cycle scheduled", horizon, fixed = TRUE)[[1]]
  wf_pos <- regexpr("v0.1.9.4 walk-forward Section 17 gate-row obligations", horizon, fixed = TRUE)[[1]]
  testthat::expect_gt(cost_pos, resolved_pos)
  testthat::expect_gt(sweep_pos, 0L)
  testthat::expect_lt(sweep_pos, resolved_pos)
  testthat::expect_gt(wf_pos, 0L)
  testthat::expect_lt(wf_pos, resolved_pos)

  testthat::expect_match(batch_plan, "## Batch 7 - Release Surfaces", fixed = TRUE)
  testthat::expect_match(batch_plan, "Status: Completed", fixed = TRUE)
  for (id in c("LDG-2570", "LDG-2571", "LDG-2572", "LDG-2573")) {
    ticket_start <- regexpr(paste0("## ", id), tickets, fixed = TRUE)
    testthat::expect_true(ticket_start > 0L)
    ticket_section <- substr(tickets, ticket_start, min(nchar(tickets), ticket_start + 1200L))
    testthat::expect_match(ticket_section, "Status: Completed", fixed = TRUE)
    testthat::expect_match(tickets_yml, paste0("id: \"", id, "\""), fixed = TRUE)
  }

  testthat::expect_match(batch_plan, "## Batch 8 - Release Gate", fixed = TRUE)
  batch8_start <- regexpr("## Batch 8 - Release Gate", batch_plan, fixed = TRUE)
  testthat::expect_true(batch8_start > 0L)
  batch8_section <- substr(batch_plan, batch8_start, min(nchar(batch_plan), batch8_start + 2000L))
  testthat::expect_match(batch8_section, "Status: Completed", fixed = TRUE)
  testthat::expect_match(batch8_section, "R CMD check --no-manual --no-build-vignettes ledgr_0.1.9.1.tar.gz", fixed = TRUE)

  release_gate_start <- regexpr("## LDG-2574: v0.1.9.1 Release Gate", tickets, fixed = TRUE)
  testthat::expect_true(release_gate_start > 0L)
  release_gate_section <- substr(tickets, release_gate_start, min(nchar(tickets), release_gate_start + 2500L))
  testthat::expect_match(release_gate_section, "Status: Completed", fixed = TRUE)
  testthat::expect_match(release_gate_section, "Completion note (2026-06-05):", fixed = TRUE)
  testthat::expect_match(tickets_yml, "id: \"LDG-2574\"", fixed = TRUE)
  testthat::expect_match(tickets_yml, "status: \"completed\"", fixed = TRUE)
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

testthat::test_that("contracts record strategy preflight boundary", {
  root <- testthat::test_path("..", "..")
  contracts <- file.path(root, "inst", "design", "contracts.md")
  testthat::skip_if_not(file.exists(contracts), "contracts source unavailable")
  text <- paste(readLines(contracts, warn = FALSE), collapse = "\n")

  testthat::expect_match(text, "ledgr_v0_1_8_spec_packet", fixed = TRUE)
  testthat::expect_match(text, "Strategy preflight classifies functional strategies before execution", fixed = TRUE)
  testthat::expect_match(text, "Tier 3\\s+is a classed error")
  testthat::expect_match(text, "must not be\\s+accepted silently or downgraded\\s+to warning-only behavior")
  testthat::expect_match(text, "Current public APIs do not\\s+include a force override")
  testthat::expect_match(text, "forced Tier 3\\s+runs must still record `tier_3` in provenance")
  testthat::expect_match(text, "Priority: base", fixed = TRUE)
  testthat::expect_match(text, "Priority: recommended", fixed = TRUE)
  testthat::expect_match(text, "not from\\s+a hand-maintained package-name allowlist")
  testthat::expect_match(text, "Package-qualified calls to packages outside the active R distribution", fixed = TRUE)
  testthat::expect_match(text, "resolved immutable non-function closure objects", fixed = TRUE)
  testthat::expect_match(text, "Forbidden nondeterministic calls", fixed = TRUE)
  testthat::expect_match(text, "Sys.time()", fixed = TRUE)
  testthat::expect_match(text, "Sys.getenv()", fixed = TRUE)
  testthat::expect_match(text, "fail before `ledgr_run()` or `ledgr_sweep()` creates execution artifacts", fixed = TRUE)
  testthat::expect_match(text, "Ledgr's exported public namespace is Tier 1-compatible", fixed = TRUE)
  testthat::expect_match(text, "signal_return()", fixed = TRUE)
  testthat::expect_match(text, "select_top_n()", fixed = TRUE)
  testthat::expect_match(text, "passed_warmup()", fixed = TRUE)
  testthat::expect_match(text, "Static analysis is not a proof of semantic reproducibility", fixed = TRUE)
  testthat::expect_match(text, "codetools::findGlobals()", fixed = TRUE)
  testthat::expect_match(text, "closures that mutate captured", fixed = TRUE)
  testthat::expect_match(text, "minimum `ledgr_strategy_preflight` result contract", fixed = TRUE)
  for (field in c("tier", "allowed", "reason", "unresolved_symbols", "package_dependencies", "notes")) {
    testthat::expect_match(text, field, fixed = TRUE)
  }
  testthat::expect_match(text, "`allowed` is `TRUE` for\\s+`tier_1` and `tier_2`, and `FALSE` for `tier_3`")
  testthat::expect_match(text, "Sweep mode inherits the public preflight semantics", fixed = TRUE)
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
  testthat::expect_match(text, "`ledgr_run\\(\\)` and `ledgr_sweep\\(\\)` must call the same fold core")
  testthat::expect_match(text, "Sweep\\s+mode may use a cheaper output handler")
  testthat::expect_match(text, "must not change\\s+strategy semantics")
  testthat::expect_match(text, "event-stream meaning", fixed = TRUE)
  testthat::expect_match(text, "Strategy preflight runs before entering the fold core", fixed = TRUE)
  testthat::expect_match(text, "Tier 3 strategies must stop before any fold execution or output handler\\s+side\\s+effects")
})

testthat::test_that("roadmap preserves v0.1.7.6 to v0.1.8 milestone sequencing", {
  root <- testthat::test_path("..", "..")
  roadmap <- file.path(root, "inst", "design", "ledgr_roadmap.md")
  testthat::skip_if_not(file.exists(roadmap), "roadmap unavailable")
  text <- paste(readLines(roadmap, warn = FALSE), collapse = "\n")

  for (version in c("0[.]1[.]7[.]6", "0[.]1[.]7[.]7", "0[.]1[.]7[.]8", "0[.]1[.]7[.]9", "0[.]1[.]8", "0[.]1[.]8[.]1")) {
    testthat::expect_match(text, paste0("\\| v", version, " \\|"))
  }
  testthat::expect_match(text, "DuckDB persistence architecture review", fixed = TRUE)
  testthat::expect_match(text, "Risk metrics contract", fixed = TRUE)
  testthat::expect_match(text, "Strategy reproducibility preflight", fixed = TRUE)
  testthat::expect_match(text, "Lightweight parameter sweep mode", fixed = TRUE)
  testthat::expect_match(text, "Metric context, risk-free-rate, and indicator codebase Phase 2 cleanup", fixed = TRUE)
  testthat::expect_match(text, "Completed milestones are not expanded here", fixed = TRUE)
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
  metrics_doc <- paste(readLines(ledgr_test_source_vignette("metrics-and-accounting.qmd"), warn = FALSE), collapse = "\n")
  root <- testthat::test_path("..", "..")
  backtest_help <- paste(readLines(file.path(root, "man", "ledgr_backtest.Rd"), warn = FALSE), collapse = "\n")
  experiment_help <- paste(readLines(file.path(root, "man", "ledgr_experiment.Rd"), warn = FALSE), collapse = "\n")
  compute_help <- paste(readLines(file.path(root, "man", "ledgr_compute_metrics.Rd"), warn = FALSE), collapse = "\n")
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
  testthat::expect_match(metrics_doc, "Four Warmup-Adjacent Cases", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Ordinary feature warmup", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Impossible warmup", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Current-bar absence", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Ledger Events", fixed = TRUE)
  testthat::expect_match(metrics_doc, "ledger events<br/>source of truth", fixed = TRUE)
  testthat::expect_match(metrics_doc, "summary metrics<br/>formulas over results", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Inspection Surfaces", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Use the narrowest inspection surface", fixed = TRUE)
  testthat::expect_match(metrics_doc, "append-only accounting record", fixed = TRUE)
  testthat::expect_match(metrics_doc, "A ledger event is the append-only accounting record", fixed = TRUE)
  testthat::expect_match(metrics_doc, "A fill is an execution row", fixed = TRUE)
  testthat::expect_match(metrics_doc, "An equity row values the portfolio", fixed = TRUE)
  testthat::expect_match(metrics_doc, "what = \"metrics\"", fixed = TRUE)
  testthat::expect_match(metrics_doc, "There is no `what = \"metrics\"` result table", fixed = TRUE)
  testthat::expect_match(metrics_doc, "There is no committed `ledgr_results(bt, what = \"features\")`", fixed = TRUE)
  testthat::expect_match(metrics_doc, "`final_equity` is not a field in the `ledgr_compute_metrics()` list", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Metric assumptions are inspectable through `ledgr_metric_context()`", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Change `bars_per_year`", fixed = TRUE)
  testthat::expect_match(metrics_doc, "A metric context is the assumption object behind metrics", fixed = TRUE)
  testthat::expect_match(metrics_doc, "default context is US\\s+equity daily")
  testthat::expect_match(metrics_doc, "ledgr_metric_us_equity\\(risk_free_rate = 0.04\\)")
  testthat::expect_match(metrics_doc, "ledgr_calendar_us_equity\\(bars_per_day = 390L\\)")
  testthat::expect_match(metrics_doc, "A scalar shorthand is accepted", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Call-time overrides are sensitivity checks", fixed = TRUE)
  testthat::expect_match(metrics_doc, "stored_run_context <- ledgr_metric_context(bt)", fixed = TRUE)
  testthat::expect_match(metrics_doc, "ledgr_metric_context_hash\\(stored_run_context\\)")
  testthat::expect_match(metrics_doc, "The full constructor fields are `risk_free_rate`, `calendar`, `benchmark`,", fixed = TRUE)
  testthat::expect_match(metrics_doc, "provider fields `benchmark`,", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Intraday work should set `calendar` explicitly", fixed = TRUE)
  testthat::expect_match(metrics_doc, "display labels are stored for inspection", fixed = TRUE)
  testthat::expect_match(metrics_doc, "do not change the", fixed = TRUE)
  testthat::expect_match(metrics_doc, "calendar annualization and source\\s+fields")
  testthat::expect_match(metrics_doc, "confirm the override did not mutate the stored context", fixed = TRUE)
  testthat::expect_match(metrics_doc, "context$risk_free_rate$source", fixed = TRUE)
  testthat::expect_match(metrics_doc, "exactly one comparison context per table", fixed = TRUE)
  testthat::expect_match(metrics_doc, "source sweep context explains\\s+how a candidate was ranked")
  testthat::expect_match(metrics_doc, "For reports, convert the comparison object", fixed = TRUE)
  testthat::expect_match(metrics_doc, "LEDGR_LAST_BAR_NO_FILL", fixed = TRUE)
  testthat::expect_match(metrics_doc, "ledgr_pulse_snapshot()", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Ordinary feature warmup is local to the beginning of each instrument's usable\\s+sample")
  testthat::expect_match(metrics_doc, "Risk Metric Contract", fixed = TRUE)
  testthat::expect_match(metrics_doc, "sharpe_ratio", fixed = TRUE)
  testthat::expect_match(metrics_doc, "excess_return[t] = equity_return[t] - rf_period_return[t]", fixed = TRUE)
  testthat::expect_match(metrics_doc, "0.02` means two percent per year", fixed = TRUE)
  testthat::expect_match(metrics_doc, "rf_period_return = \\(1 \\+ rf_annual\\)\\^\\(1 / bars_per_year\\) - 1")
  testthat::expect_match(metrics_doc, "see `?ledgr_compute_metrics` for the exact edge-case rules", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Time-varying risk-free-rate series and real data providers", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Sortino, Calmar, Omega, information ratio", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Metric assumptions now live in a `metric_context`", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Timing, Spread, And Fees", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Timing and cost are separate execution steps", fixed = TRUE)
  testthat::expect_match(metrics_doc, "open \\* \\(1 \\+ spread_bps / 20000\\)")
  testthat::expect_match(metrics_doc, "open \\* \\(1 - spread_bps / 20000\\)")
  testthat::expect_match(metrics_doc, "approximately `spread_bps` basis points before\\s+explicit fees")
  testthat::expect_match(metrics_doc, "Price transforms and explicit fees are different", fixed = TRUE)
  testthat::expect_match(metrics_doc, "What costs do not model", fixed = TRUE)
  for (term in c("liquidity", "financing", "taxes", "OMS", "broker reconciliation")) {
    testthat::expect_match(metrics_doc, term, fixed = TRUE)
  }
  testthat::expect_match(metrics_doc, "transaction-cost\\s+analysis")
  testthat::expect_match(metrics_doc, "Compiled Accounting Fails Closed", fixed = TRUE)
  testthat::expect_match(metrics_doc, "ledgr_unsupported_accounting_model", fixed = TRUE)
  testthat::expect_match(metrics_doc, "ledgr_compiled_spot_fifo_unavailable", fixed = TRUE)
  testthat::expect_no_match(metrics_doc, "full spread adjustment on\\s+each fill leg")
  testthat::expect_no_match(metrics_doc, "`2 \\* spread_bps` basis points before fixed commissions")

  testthat::expect_match(backtest_help, "quoted bid/ask\\s+spread")
  testthat::expect_match(backtest_help, "crosses approximately\\s+\\\\code\\{spread_bps\\} basis points before explicit fees")
  testthat::expect_match(experiment_help, "quoted bid/ask\\s+spread")
  testthat::expect_match(experiment_help, "crosses approximately \\\\code\\{spread_bps\\} basis points before explicit fees")

  testthat::expect_match(summary_help, "total return", fixed = TRUE)
  testthat::expect_match(summary_help, "annualized volatility", fixed = TRUE)
  testthat::expect_match(summary_help, "Sharpe ratio", fixed = TRUE)
  testthat::expect_match(summary_help, "metric context stored with the run", fixed = TRUE)
  testthat::expect_match(summary_help, "annualization calendar", fixed = TRUE)
  testthat::expect_match(summary_help, "risk_free_rate", fixed = TRUE)
  testthat::expect_match(summary_help, "time in market", fixed = TRUE)
  testthat::expect_match(summary_help, "closed trade rows", fixed = TRUE)
  testthat::expect_match(summary_help, "Warmup Diagnostics", fixed = TRUE)
  testthat::expect_match(summary_help, "metrics-and-accounting.html", fixed = TRUE)
  testthat::expect_match(compute_help, "list-like \\code{ledgr_metrics} object", fixed = TRUE)
  testthat::expect_match(compute_help, "metric context stored with the run", fixed = TRUE)
  testthat::expect_match(compute_help, "Supply either", fixed = TRUE)
  testthat::expect_match(compute_help, "\\code{metric_context} or \\code{risk_free_rate}, not both.", fixed = TRUE)
  compare_help <- paste(readLines(file.path(root, "man", "ledgr_compare_runs.Rd"), warn = FALSE), collapse = "\n")
  testthat::expect_match(compare_help, "raw numeric values for ranking", fixed = TRUE)
  testthat::expect_match(compare_help, "formatted percentages are a print-only concern", fixed = TRUE)
  testthat::expect_match(compare_help, "metric_context", fixed = TRUE)
  testthat::expect_match(compare_help, "exactly one metric context", fixed = TRUE)
  testthat::expect_match(compare_help, "ledgr_metric_context(comparison)", fixed = TRUE)
  testthat::expect_match(compare_help, "final_equity", fixed = TRUE)

  testthat::expect_match(results_help, "execution fill rows", fixed = TRUE)
  testthat::expect_match(results_help, "zero-row schema", fixed = TRUE)
  testthat::expect_match(results_help, "action = \"CLOSE\"", fixed = TRUE)
  testthat::expect_match(results_help, "Open positions can affect equity", fixed = TRUE)
  testthat::expect_match(results_help, "final equity used by prints and comparisons", fixed = TRUE)
  testthat::expect_match(results_help, "does not support \\code{what = \"metrics\"}", fixed = TRUE)
  testthat::expect_match(results_help, "does not support \\code{what = \"features\"}", fixed = TRUE)
  testthat::expect_match(results_help, "ledgr_pulse_features", fixed = TRUE)
  testthat::expect_match(metrics_doc, "print-oriented view", fixed = TRUE)
  testthat::expect_match(metrics_doc, "returns the backtest handle\\s+invisibly")
  testthat::expect_match(metrics_doc, "raw metrics object keeps metric-kernel attributes", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Timestamp checks should compare normalized UTC values", fixed = TRUE)
  testthat::expect_match(metrics_doc, "intraday_time <- format", fixed = TRUE)
  testthat::expect_match(metrics_doc, "distinguish zero signals from zero sizing", fixed = TRUE)
  testthat::expect_match(metrics_doc, "required fill fields", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Use `ledgr_compute_metrics\\(\\)` for scripted")
  testthat::expect_match(metrics_doc, "`ledgr_compare_runs()` is also programmatic", fixed = TRUE)
})

testthat::test_that("cost API help pages contain runnable reference examples", {
  root <- testthat::test_path("..", "..")
  help_paths <- file.path(
    root,
    "man",
    c(
      "ledgr_cost_spread_bps.Rd",
      "ledgr_cost_steps.Rd",
      "ledgr_timing_next_open.Rd",
      "ledgr_run.Rd"
    )
  )
  testthat::skip_if_not(all(file.exists(help_paths)), "source help pages not available during installed-package tests")

  cost_help <- paste(readLines(help_paths[[1]], warn = FALSE), collapse = "\n")
  steps_help <- paste(readLines(help_paths[[2]], warn = FALSE), collapse = "\n")
  timing_help <- paste(readLines(help_paths[[3]], warn = FALSE), collapse = "\n")
  run_help <- paste(readLines(help_paths[[4]], warn = FALSE), collapse = "\n")

  for (term in c(
    "ledgr_cost_spread_bps(5)",
    "ledgr_cost_fixed_fee(1)",
    "ledgr_cost_notional_bps_fee(2)",
    "ledgr_cost_zero()",
    "ledgr_cost_chain",
    "ledgr_cost_steps(cost)",
    "ledgr_cost_describe(cost)",
    "try(ledgr_backtest(data = bars, strategy = strategy), silent = TRUE)",
    "cost_model = zero"
  )) {
    testthat::expect_match(cost_help, term, fixed = TRUE)
  }
  testthat::expect_match(steps_help, "ledgr_cost_notional_bps_fee(2)", fixed = TRUE)
  testthat::expect_match(steps_help, "ledgr_cost_steps(cost)", fixed = TRUE)
  testthat::expect_match(steps_help, "ledgr_cost_describe(cost)", fixed = TRUE)
  testthat::expect_match(timing_help, "timing <- ledgr_timing_next_open()", fixed = TRUE)
  testthat::expect_match(timing_help, "timing$type_id", fixed = TRUE)
  testthat::expect_match(run_help, "cost_model = ledgr_cost_zero()", fixed = TRUE)
})

testthat::test_that("public site polish avoids stale public artifacts", {
  root <- testthat::test_path("..", "..")
  pkgdown <- file.path(root, "_pkgdown.yml")
  public_paths <- c(
    file.path(root, "README.Rmd"),
    file.path(root, "README.md"),
    list.files(file.path(root, "vignettes"), pattern = "[.](Rmd|qmd|md)$", full.names = TRUE),
    list.files(file.path(root, "vignettes", "articles"), pattern = "[.](Rmd|qmd)$", full.names = TRUE)
  )
  public_paths <- public_paths[file.exists(public_paths)]
  text <- paste(unlist(lapply(public_paths, readLines, warn = FALSE)), collapse = "\n")
  testthat::skip_if_not(file.exists(pkgdown), "pkgdown config unavailable during installed-package tests")
  pkgdown_text <- paste(readLines(pkgdown, warn = FALSE), collapse = "\n")

  start_here <- regexpr("  - title: Start Here", pkgdown_text, fixed = TRUE)
  core_workflow <- regexpr("  - title: Core Workflow", pkgdown_text, fixed = TRUE)
  design <- regexpr("  - title: Design / Background", pkgdown_text, fixed = TRUE)
  testthat::expect_gt(start_here[[1]], 0)
  testthat::expect_gt(core_workflow[[1]], start_here[[1]])
  testthat::expect_gt(design[[1]], core_workflow[[1]])

  start_block <- substr(pkgdown_text, start_here[[1]], core_workflow[[1]] - 1L)
  testthat::expect_match(start_block, "articles/who-ledgr-is-for", fixed = TRUE)
  testthat::expect_match(start_block, "- research-workflow", fixed = TRUE)
  testthat::expect_match(start_block, "- leakage", fixed = TRUE)
  testthat::expect_match(start_block, "- reproducibility", fixed = TRUE)

  core_block <- substr(pkgdown_text, core_workflow[[1]], design[[1]] - 1L)
  testthat::expect_match(core_block, "- strategy-development", fixed = TRUE)
  testthat::expect_match(core_block, "- indicators", fixed = TRUE)
  testthat::expect_match(core_block, "- custom-indicators", fixed = TRUE)
  testthat::expect_match(core_block, "- execution-semantics", fixed = TRUE)
  testthat::expect_match(core_block, "- metrics-and-accounting", fixed = TRUE)
  testthat::expect_match(core_block, "- experiment-store", fixed = TRUE)
  testthat::expect_match(core_block, "- sweeps", fixed = TRUE)

  testthat::expect_no_match(text, "C:\\Users", fixed = TRUE)
  testthat::expect_no_match(text, "custom-indicators.md", fixed = TRUE)
  testthat::expect_no_match(text, "v0.1.7.2 helper layer", fixed = TRUE)
  testthat::expect_no_match(text, "current v0.1.7.6", fixed = TRUE)
  testthat::expect_no_match(text, "This vignette walks through the v0.1.7 research loop", fixed = TRUE)
  testthat::expect_no_match(text, "Sweep and tune APIs are reserved for later versions", fixed = TRUE)
  testthat::expect_no_match(text, "v0.1.8 is the experiment-first research API", fixed = TRUE)
  testthat::expect_no_match(text, "no DISPLAY variable", fixed = TRUE)
  testthat::expect_false(file.exists(file.path(root, "Rprof.out")))
  testthat::expect_match(paste(readLines(file.path(root, ".gitignore"), warn = FALSE), collapse = "\n"), "Rprof.out", fixed = TRUE)
})

testthat::test_that("package help exposes an installed-documentation spine", {
  root <- testthat::test_path("..", "..")
  pkg_help <- file.path(root, "man", "ledgr-package.Rd")
  testthat::skip_if_not(file.exists(pkg_help), "package help source not available during installed-package tests")
  text <- paste(readLines(pkg_help, warn = FALSE), collapse = "\n")

  testthat::expect_match(text, "vignette(package = \"ledgr\")", fixed = TRUE)
  testthat::expect_match(text, "system.file(\"doc\", package = \"ledgr\")", fixed = TRUE)
  for (article in c("research-workflow", "strategy-development", "metrics-and-accounting", "execution-semantics", "experiment-store", "sweeps", "indicators", "custom-indicators")) {
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
    ledgr_param_grid = "sweeps",
    ledgr_precompute_features = "sweeps",
    ledgr_sweep = "sweeps",
    ledgr_candidate = "sweeps",
    ledgr_candidate_reproduction_key = "sweeps",
    ledgr_promote = "sweeps",
    ledgr_promotion_context = "sweeps",
    ledgr_run_promotion_context = "sweeps",
    ledgr_run_info = "sweeps",
    ledgr_strategy_context = c("strategy-development", "indicators"),
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
    ledgr_feature_contract_check = "indicators",
    ledgr_ind_returns = "indicators",
    ledgr_ind_sma = "indicators",
    ledgr_ind_ema = "indicators",
    ledgr_ind_rsi = "indicators",
    ledgr_ind_ttr = "indicators",
    ledgr_ind_ttr_outputs = "indicators",
    ledgr_adapter_r = c("indicators", "custom-indicators"),
    ledgr_adapter_csv = c("indicators", "custom-indicators"),
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
  expected$ledgr_calendar <- "metrics-and-accounting"
  expected$ledgr_metric_context <- "metrics-and-accounting"
  expected$ledgr_risk_free_rate <- "metrics-and-accounting"

  for (page in names(expected)) {
    path <- file.path(man_dir, paste0(page, ".Rd"))
    text <- paste(readLines(path, warn = FALSE), collapse = "\n")
    for (article in expected[[page]]) {
      testthat::expect_match(text, sprintf("vignette(\"%s\", package = \"ledgr\")", article), fixed = TRUE, info = page)
      testthat::expect_match(text, sprintf("system.file(\"doc\", \"%s.html\", package = \"ledgr\")", article), fixed = TRUE, info = page)
    }
  }
})

testthat::test_that("metric context help pages disclose calendar defaults and provider non-scope", {
  root <- testthat::test_path("..", "..")
  man_dir <- file.path(root, "man")
  testthat::skip_if_not(dir.exists(man_dir), "man pages not available during installed-package tests")

  calendar_help <- paste(readLines(file.path(man_dir, "ledgr_calendar.Rd"), warn = FALSE), collapse = "\n")
  context_help <- paste(readLines(file.path(man_dir, "ledgr_metric_context.Rd"), warn = FALSE), collapse = "\n")
  rf_help <- paste(readLines(file.path(man_dir, "ledgr_risk_free_rate.Rd"), warn = FALSE), collapse = "\n")

  testthat::expect_match(calendar_help, "trading_days_per_year \\* bars_per_day")
  testthat::expect_match(calendar_help, "ledgr_calendar_us_equity\\(bars_per_day = 390L\\)")
  testthat::expect_match(calendar_help, "ledgr_calendar_crypto()", fixed = TRUE)
  testthat::expect_match(context_help, "metric-assumption object", fixed = TRUE)
  testthat::expect_match(context_help, "A numeric\\s+scalar first argument is treated as \\\\code\\{risk_free_rate\\}")
  testthat::expect_match(context_help, "\\\\code\\{risk_free_rate\\}, \\\\code\\{calendar\\}, \\\\code\\{benchmark\\}")
  testthat::expect_match(context_help, "\\\\code\\{benchmark\\}: reserved for future benchmark-return providers")
  testthat::expect_match(context_help, "\\\\code\\{market_factor\\}: reserved for future market-factor providers")
  testthat::expect_match(context_help, "\\\\code\\{mar\\}: reserved for future minimum-acceptable-return providers")
  testthat::expect_match(context_help, "Human display labels are stored for\\s+inspection but do not enter the hash")
  testthat::expect_match(context_help, "calendar\\s+annualization and source fields")
  testthat::expect_match(context_help, "ledgr_metric_context\\(x\\)\\$risk_free_rate")
  testthat::expect_match(context_help, "ledgr_metric_us_equity", fixed = TRUE)
  testthat::expect_match(context_help, "ledgr_metric_crypto", fixed = TRUE)
  testthat::expect_match(rf_help, "not a provider adapter", fixed = TRUE)
  testthat::expect_match(rf_help, "annual risk-free rate", fixed = TRUE)
})

testthat::test_that("sweep docs teach exploratory discipline and non-goals", {
  doc <- paste(readLines(ledgr_test_source_vignette("sweeps.qmd"), warn = FALSE), collapse = "\n")
  readme <- paste(readLines(file.path(testthat::test_path("..", ".."), "README.Rmd"), warn = FALSE), collapse = "\n")
  root <- testthat::test_path("..", "..")
  sweep_help <- paste(readLines(file.path(root, "man", "ledgr_sweep.Rd"), warn = FALSE), collapse = "\n")
  candidate_help <- paste(readLines(file.path(root, "man", "ledgr_candidate.Rd"), warn = FALSE), collapse = "\n")
  key_help <- paste(readLines(file.path(root, "man", "ledgr_candidate_reproduction_key.Rd"), warn = FALSE), collapse = "\n")
  promote_help <- paste(readLines(file.path(root, "man", "ledgr_promote.Rd"), warn = FALSE), collapse = "\n")
  precompute_help <- paste(readLines(file.path(root, "man", "ledgr_precompute_features.Rd"), warn = FALSE), collapse = "\n")
  promotion_help <- paste(readLines(file.path(root, "man", "ledgr_promotion_context.Rd"), warn = FALSE), collapse = "\n")

  testthat::expect_match(doc, "Sweep Is Exploration", fixed = TRUE)
  testthat::expect_match(doc, "does not choose a winner", fixed = TRUE)
  testthat::expect_match(doc, "A sweep is an evaluated candidate table over a declared grid", fixed = TRUE)
  testthat::expect_match(doc, "A sweep usually contains many candidates", fixed = TRUE)
  testthat::expect_match(doc, "Declare Parameterized Features", fixed = TRUE)
  testthat::expect_match(doc, "An active alias is a stable strategy-facing feature name", fixed = TRUE)
  testthat::expect_match(doc, "Feature parameters vary the knobs exposed by a feature constructor", fixed = TRUE)
  testthat::expect_match(doc, "Only knobs declared with `ledgr_param\\(\"name\"\\)` need values in the feature grid")
  testthat::expect_match(doc, "Concrete arguments stay fixed", fixed = TRUE)
  testthat::expect_match(doc, "The strategy function itself does not change across candidates", fixed = TRUE)
  testthat::expect_match(doc, "ledgr calls the same `function\\(ctx, params\\)`")
  testthat::expect_match(doc, "ctx\\$features\\(id\\)")
  testthat::expect_match(doc, "params\\$threshold")
  testthat::expect_match(doc, "The aliases stay stable across candidates", fixed = TRUE)
  testthat::expect_match(doc, "Build The Candidate Grid", fixed = TRUE)
  testthat::expect_match(doc, "Feature parameters materialize indicators before execution", fixed = TRUE)
  testthat::expect_match(doc, "Strategy parameters\\s+are passed to `strategy\\(ctx, params\\)`")
  testthat::expect_match(doc, "knobs in your own strategy code", fixed = TRUE)
  testthat::expect_match(doc, "The `.filter` expression is a structural grid constraint", fixed = TRUE)
  testthat::expect_match(doc, "Mind the combinatorial explosion", fixed = TRUE)
  testthat::expect_match(doc, "more than 20 combinations", fixed = TRUE)
  testthat::expect_match(doc, "status = \"FAILED\"", fixed = TRUE)
  testthat::expect_match(doc, "allow_failed = TRUE", fixed = TRUE)
  testthat::expect_match(doc, "`ledgr_promote()` still rejects failed", fixed = TRUE)
  testthat::expect_match(doc, "ledgr_grid_cross", fixed = TRUE)
  testthat::expect_no_match(doc, "Legacy flat grids", fixed = TRUE)
  testthat::expect_no_match(doc, "feature-factory", fixed = TRUE)
  testthat::expect_no_match(doc, "feature factory", ignore.case = TRUE)
  testthat::expect_no_match(doc, "Build Train And Test Snapshots", fixed = TRUE)
  testthat::expect_no_match(doc, "require_same_snapshot = FALSE", fixed = TRUE)
  testthat::expect_match(doc, "Use the failed row as an interactive debugging handle", fixed = TRUE)
  testthat::expect_match(doc, "vignette(\"strategy-development\", package = \"ledgr\")", fixed = TRUE)
  testthat::expect_match(doc, "Contract errors still abort before a candidate table exists", fixed = TRUE)
  testthat::expect_match(doc, "execution_seed", fixed = TRUE)
  testthat::expect_match(doc, "Promote One Candidate", fixed = TRUE)
  testthat::expect_match(doc, "Promotion replays one selected candidate", fixed = TRUE)
  testthat::expect_match(doc, "What A Sweep Does Not Prove", fixed = TRUE)
  testthat::expect_match(doc, "when that layer lands in\\s+v0.1.9.x")
  testthat::expect_match(doc, "Design note", fixed = TRUE)
  testthat::expect_match(doc, "v0.1.8.6 cycle", fixed = TRUE)
  testthat::expect_match(doc, "sweep-review helper", fixed = TRUE)
  testthat::expect_match(doc, "Try it", fixed = TRUE)
  testthat::expect_match(doc, "This debug example uses no features", fixed = TRUE)
  testthat::expect_match(doc, "```{mermaid}", fixed = TRUE)
  testthat::expect_match(doc, "candidate rows<br/>feature params \\+ strategy params")
  testthat::expect_match(doc, "strategy reads<br/>fast and slow", fixed = TRUE)
  testthat::expect_match(doc, "execution-semantics", fixed = TRUE)
  testthat::expect_match(doc, "candidate summaries", fixed = TRUE)
  testthat::expect_match(doc, "glimpse(top_n)", fixed = TRUE)
  testthat::expect_match(doc, "ledgr_tune()", fixed = TRUE)
  testthat::expect_match(doc, "parallel sweep execution", fixed = TRUE)
  testthat::expect_match(doc, "walk-forward, PBO, or CSCV", fixed = TRUE)
  testthat::expect_match(doc, "full sweep artifact persistence", fixed = TRUE)
  testthat::expect_no_match(doc, "ledgr_snapshot_split\\(")
  testthat::expect_match(doc, "ledgr_save_sweep()", fixed = TRUE)
  testthat::expect_match(doc, "Cost Models Are Fixed Inputs", fixed = TRUE)
  testthat::expect_match(doc, "does not\\s+compose cost models as another grid dimension")
  testthat::expect_match(doc, "A future `ledgr_cost_grid()`", fixed = TRUE)
  testthat::expect_match(doc, "not part of the v1 cost surface", fixed = TRUE)
  testthat::expect_match(doc, "cost-grid composition such as `ledgr_cost_grid()`", fixed = TRUE)
  testthat::expect_no_match(doc, "public cost-model factories;", fixed = TRUE)

  testthat::expect_match(readme, "I want the full research loop: snapshot, sweep, promotion, reopen.", fixed = TRUE)
  testthat::expect_match(readme, "Research Workflow", fixed = TRUE)
  testthat::expect_match(readme, "exploratory sweeps and candidate promotion", fixed = TRUE)
  testthat::expect_match(readme, "Sweeps", fixed = TRUE)
  testthat::expect_match(readme, "does not ship automatic ranking", fixed = TRUE)
  testthat::expect_match(readme, "The current ledgr research API is experiment-first", fixed = TRUE)
  testthat::expect_match(readme, "includes sequential\\s+exploratory sweep support")

  for (help in list(sweep_help, candidate_help, key_help, promote_help, precompute_help, promotion_help)) {
    testthat::expect_match(help, "vignette(\"sweeps\", package = \"ledgr\")", fixed = TRUE)
    testthat::expect_match(help, "system.file(\"doc\", \"sweeps.html\", package = \"ledgr\")", fixed = TRUE)
  }
  testthat::expect_match(sweep_help, "does not rank candidates", fixed = TRUE)
  testthat::expect_match(sweep_help, "candidate feature-set hash", fixed = TRUE)
  testthat::expect_match(sweep_help, "Compatibility note: old\\s+feature-factory experiments use a flat")
  testthat::expect_match(sweep_help, "allow_failed = TRUE", fixed = TRUE)
  testthat::expect_match(sweep_help, "inherits\\(e, \"ledgr_strategy_error\"\\)")
  testthat::expect_match(sweep_help, "more than 20 combinations", fixed = TRUE)
  testthat::expect_match(promote_help, "require_same_snapshot = FALSE", fixed = TRUE)
  testthat::expect_match(candidate_help, "execution_seed", fixed = TRUE)
  testthat::expect_match(key_help, "compact reproduction key", fixed = TRUE)
  testthat::expect_match(key_help, "not durable run artifacts", fixed = TRUE)
  testthat::expect_match(precompute_help, "feature engine version", fixed = TRUE)
  testthat::expect_match(promotion_help, "not a full sweep artifact", fixed = TRUE)
})

testthat::test_that("feature contract check docs state factory materialization boundary", {
  root <- testthat::test_path("..", "..")
  help_path <- file.path(root, "man", "ledgr_feature_contract_check.Rd")
  testthat::skip_if_not(file.exists(help_path), "man page source unavailable during installed-package tests")
  help <- paste(readLines(help_path, warn = FALSE), collapse = "\n")

  testthat::expect_match(help, "feature factories", ignore.case = TRUE)
  testthat::expect_match(help, "Materialize the factory first", fixed = TRUE)
  testthat::expect_match(help, "ledgr_feature_factory_requires_params", fixed = TRUE)
})

testthat::test_that("execution semantics article pins target and fill timing contract", {
  doc <- paste(readLines(ledgr_test_source_vignette("execution-semantics.qmd"), warn = FALSE), collapse = "\n")
  pkgdown <- paste(readLines(file.path(testthat::test_path("..", ".."), "_pkgdown.yml"), warn = FALSE), collapse = "\n")

  testthat::expect_match(doc, "Targets Are Holdings", fixed = TRUE)
  testthat::expect_match(doc, "not \"buy 10 units every bar", fixed = TRUE)
  testthat::expect_match(doc, "Next-Open Fill Timing", fixed = TRUE)
  testthat::expect_match(doc, "one-bar delay is the no-lookahead boundary", fixed = TRUE)
  testthat::expect_match(doc, "Costs Are Part Of The Fill", fixed = TRUE)
  testthat::expect_match(doc, "Public cost API", fixed = TRUE)
  testthat::expect_match(doc, "Final-Bar Targets Cannot Fill", fixed = TRUE)
  testthat::expect_match(doc, "LEDGR_LAST_BAR_NO_FILL", fixed = TRUE)
  testthat::expect_match(doc, "Warmup Gates Belong In The Strategy", fixed = TRUE)
  testthat::expect_match(doc, "passed_warmup()", fixed = TRUE)
  testthat::expect_match(doc, "Zero Fills And Zero Trades Mean Different Things", fixed = TRUE)
  testthat::expect_match(doc, "vignette(\"sweeps\", package = \"ledgr\")", fixed = TRUE)
  testthat::expect_match(pkgdown, "- execution-semantics", fixed = TRUE)
})

testthat::test_that("research workflow article pins canonical workflow and validation caveats", {
  doc <- paste(readLines(ledgr_test_source_vignette("research-workflow.qmd"), warn = FALSE), collapse = "\n")

  required_sections <- c(
    "## Project Topology",
    "## Fix The Evidence: Seal A Snapshot",
    "## Declare The Experiment Boundary",
    "## Choose The Strategy",
    "## Sanity-Check One Run",
    "## Compare Declared Candidates",
    "## Inspect Before You Promote",
    "## Commit The Selection With A Note",
    "## Reopen The Artifact",
    "## What Promotion Does Not Prove",
    "## Write The Human Research Note",
    "## Next Layer: Walk-Forward Evaluation",
    "## Where Next"
  )

  for (section in required_sections) {
    testthat::expect_match(doc, section, fixed = TRUE)
  }

  report_items <- c(
    "hypothesis and data window",
    "snapshot hash and data-source assumptions",
    "feature and strategy declarations",
    "candidate grid summary",
    "candidate ranking rule",
    "top-N candidate table",
    "issue and failure review",
    "equity and drawdown plots",
    "promotion note",
    "reason for rejecting alternatives",
    "selection caveat: promoted candidate is not statistically validated by promotion itself"
  )

  for (item in report_items) {
    testthat::expect_match(doc, item, fixed = TRUE)
  }

  testthat::expect_match(doc, "The loop is deliberately short:", fixed = TRUE)
  testthat::expect_match(doc, "Reopen and recover", fixed = TRUE)
  testthat::expect_match(doc, "artifacts/ledgr_store.duckdb", fixed = TRUE)
  testthat::expect_match(doc, "artifacts/*.duckdb", fixed = TRUE)
  testthat::expect_match(doc, "ledgr_demo_bars", fixed = TRUE)
  testthat::expect_match(doc, "ledgr_feature_map", fixed = TRUE)
  testthat::expect_match(doc, "ledgr_feature_grid", fixed = TRUE)
  testthat::expect_match(doc, "ledgr_strategy_grid", fixed = TRUE)
  testthat::expect_match(doc, "ledgr_grid_cross", fixed = TRUE)
  testthat::expect_match(doc, "ledgr_promote", fixed = TRUE)
  testthat::expect_match(doc, "ledgr_run_open", fixed = TRUE)
  testthat::expect_match(doc, "ledgr_extract_strategy", fixed = TRUE)
  testthat::expect_match(doc, "passed_warmup()", fixed = TRUE)
  testthat::expect_match(doc, "Reopen and recover", fixed = TRUE)
  testthat::expect_match(doc, "selected candidate", fixed = TRUE)
  testthat::expect_match(doc, "strategy parameters", fixed = TRUE)
  testthat::expect_match(doc, "feature parameters", fixed = TRUE)
  testthat::expect_match(doc, "Tier 2\\s+strategies")
  testthat::expect_match(doc, "Promotion records selection; it does not prove generalization.", fixed = TRUE)
  testthat::expect_match(doc, "Naive\\s+sweep-and-pick selection is a selection-bias risk")
  testthat::expect_match(doc, "walk-forward and\\s+out-of-sample evaluation as the next conceptual layer")
  testthat::expect_match(doc, "the public roadmap places walk-forward evaluation at v0.1.9.x", fixed = TRUE)
  testthat::expect_match(doc, "When you ask \"does this strategy generalize?\"", fixed = TRUE)
  testthat::expect_match(doc, "Try it", fixed = TRUE)
  testthat::expect_match(doc, "```{mermaid}", fixed = TRUE)
  testthat::expect_match(doc, "API gap", fixed = TRUE)
  testthat::expect_match(doc, "v0.1.8.6 cycle", fixed = TRUE)
  testthat::expect_match(doc, "Design note", fixed = TRUE)
  testthat::expect_match(doc, "This article is evaluated when it is rendered", fixed = TRUE)
  testthat::expect_match(doc, "file.path(tempdir(), \"ledgr_research_workflow.duckdb\")", fixed = TRUE)
  testthat::expect_match(doc, "head(ledgr_results(single_run, what = \"equity\"), 3)", fixed = TRUE)
  testthat::expect_match(doc, "info$promotion_context", fixed = TRUE)
  testthat::expect_match(doc, "About the demo data", fixed = TRUE)
  testthat::expect_match(doc, "::: {.ledgr-callout .ledgr-callout-note}", fixed = TRUE)
  testthat::expect_match(doc, "::: {.ledgr-callout .ledgr-callout-tip}", fixed = TRUE)
  testthat::expect_no_match(doc, "#| eval: false", fixed = TRUE)
  testthat::expect_match(doc, "custom_sma_strategy <- function(ctx, params)", fixed = TRUE)
  testthat::expect_match(doc, "glimpse(top_n)", fixed = TRUE)
  testthat::expect_match(doc, "as_tibble()", fixed = TRUE)
  testthat::expect_no_match(doc, "dplyr::filter", fixed = TRUE)
  testthat::expect_match(doc, "vignette(\"sweeps\", package = \"ledgr\")", fixed = TRUE)
  testthat::expect_no_match(doc, "not evaluated during\\s+package vignette builds")
})

testthat::test_that("experiment-store routes low-level CSV bridge to roxygen", {
  doc <- paste(readLines(ledgr_test_source_vignette("experiment-store.qmd"), warn = FALSE), collapse = "\n")
  root <- testthat::test_path("..", "..")
  info_help <- paste(readLines(file.path(root, "man", "ledgr_snapshot_info.Rd"), warn = FALSE), collapse = "\n")
  csv_help <- paste(readLines(file.path(root, "man", "ledgr_snapshot_import_bars_csv.Rd"), warn = FALSE), collapse = "\n")

  testthat::expect_match(doc, "artifacts/ledgr_store.duckdb", fixed = TRUE)
  testthat::expect_match(doc, "Backup Conventions", fixed = TRUE)
  testthat::expect_match(doc, "Back up closed stores", fixed = TRUE)
  testthat::expect_match(doc, "file.copy\\(")
  testthat::expect_match(doc, "ordinary backup discipline", fixed = TRUE)
  testthat::expect_match(doc, "Pre-CRAN compatibility", fixed = TRUE)
  testthat::expect_match(doc, "`volume` is optional", fixed = TRUE)
  testthat::expect_match(doc, "Other CSV columns are ignored", fixed = TRUE)
  testthat::expect_match(doc, "do not become part of the sealed\\s+snapshot or its hash")
  testthat::expect_match(doc, "appending bars to a sealed snapshot in place", fixed = TRUE)
  testthat::expect_match(doc, "resealing different data under the same snapshot ID", fixed = TRUE)
  testthat::expect_match(doc, "deleting snapshots that stored runs still reference", fixed = TRUE)
  testthat::expect_match(doc, "mixing live ticks into a backtest snapshot", fixed = TRUE)
  testthat::expect_match(doc, "undocumented synthetic corrections", fixed = TRUE)
  testthat::expect_no_match(doc, "Bridge A Low-Level CSV Import", fixed = TRUE)
  testthat::expect_no_match(doc, "advanced import material", fixed = TRUE)
  testthat::expect_match(doc, "Snapshot Lifecycle And Data Input", fixed = TRUE)
  testthat::expect_match(doc, "ledgr_snapshot_from_yahoo", fixed = TRUE)
  testthat::expect_match(doc, "The returned handle is already sealed", fixed = TRUE)
  testthat::expect_match(doc, "idempotent verification step", fixed = TRUE)
  testthat::expect_match(doc, "yahoo_seal <- ledgr_snapshot_seal\\(snapshot\\)")
  testthat::expect_match(doc, "yahoo_hash <- yahoo_seal\\$hash")
  testthat::expect_match(doc, "returns an\\s+invisible structured list with `\\$hash` and `\\$snapshot`")
  testthat::expect_match(doc, "CSV and local data validation happens while the snapshot is created and sealed", fixed = TRUE)
  testthat::expect_match(doc, "They are not strategy execution errors", fixed = TRUE)
  testthat::expect_match(doc, "Snapshot metadata uses these public field names", fixed = TRUE)
  testthat::expect_match(doc, "`bar_count` | current count of rows in `snapshot_bars`", fixed = TRUE)
  testthat::expect_match(doc, "`instrument_count` | current count of rows in `snapshot_instruments`", fixed = TRUE)
  testthat::expect_match(doc, "The structured columns from `ledgr_snapshot_info\\(\\)` are\\s+`bar_count` and `instrument_count`")
  testthat::expect_match(doc, "Useful fields include", fixed = TRUE)
  testthat::expect_match(doc, "raw numeric columns", fixed = TRUE)
  testthat::expect_match(doc, "metric_context = ledgr_metric_context\\(exp\\)")
  testthat::expect_match(doc, "For report writing, coerce the comparison", fixed = TRUE)
  testthat::expect_match(doc, "best_run_id", fixed = TRUE)
  testthat::expect_match(doc, "ledgr_run_not_found", fixed = TRUE)
  testthat::expect_match(doc, "trend_qty_5_rerun", fixed = TRUE)
  testthat::expect_match(doc, "Current Feature Persistence Boundary", fixed = TRUE)
  testthat::expect_match(doc, "full persisted feature-series retrieval API remains outside", fixed = TRUE)
  testthat::expect_match(doc, "External point-in-time regressors", fixed = TRUE)
  testthat::expect_match(doc, "vintage semantics", fixed = TRUE)
  testthat::expect_match(doc, "ledgr_snapshot_import_bars_csv", fixed = TRUE)
  testthat::expect_match(doc, "Control low-level CSV create/import/seal lifecycle", fixed = TRUE)
  testthat::expect_match(doc, "Task Intent Map", fixed = TRUE)
  testthat::expect_match(doc, "Fetch and seal Yahoo bars", fixed = TRUE)
  testthat::expect_match(doc, "remote Yahoo endpoint remains outside ledgr's reproducibility boundary", fixed = TRUE)
  testthat::expect_match(csv_help, "Low-level CSV lifecycle", fixed = TRUE)
  testthat::expect_match(csv_help, "Most users should prefer", fixed = TRUE)
  testthat::expect_match(csv_help, "ledgr_snapshot_from_csv", fixed = TRUE)
  testthat::expect_match(csv_help, "ledgr_snapshot_create", fixed = TRUE)
  testthat::expect_match(csv_help, "ledgr_snapshot_import_bars_csv", fixed = TRUE)
  testthat::expect_match(csv_help, "ledgr_snapshot_seal", fixed = TRUE)
  testthat::expect_match(csv_help, "ledgr_snapshot_info", fixed = TRUE)
  testthat::expect_match(csv_help, "ledgr_snapshot_load(..., verify = TRUE)", fixed = TRUE)
  testthat::expect_match(csv_help, "ledgr_experiment", fixed = TRUE)
  testthat::expect_match(csv_help, "ledgr_run", fixed = TRUE)
  testthat::expect_match(csv_help, "bar_count", fixed = TRUE)
  testthat::expect_match(csv_help, "instrument_count", fixed = TRUE)
  testthat::expect_match(csv_help, "meta_json", fixed = TRUE)
  testthat::expect_match(csv_help, "n_bars", fixed = TRUE)
  testthat::expect_match(csv_help, "n_instruments", fixed = TRUE)
  testthat::expect_match(csv_help, "Extra columns", fixed = TRUE)
  testthat::expect_match(csv_help, "ignored", fixed = TRUE)
  testthat::expect_match(csv_help, "canonical bar columns are persisted and hashed", fixed = TRUE)
  testthat::expect_match(csv_help, "Snapshot\\s+identity does not come from that metadata")
  testthat::expect_match(csv_help, "CSV and OHLC errors are import/seal errors", fixed = TRUE)
  testthat::expect_match(info_help, "start_date, end_date", fixed = TRUE)
  testthat::expect_match(info_help, "ledgr_snapshot_info\\(snapshot\\)")
  testthat::expect_match(info_help, "n_bars", fixed = TRUE)
  testthat::expect_match(info_help, "n_instruments", fixed = TRUE)
  testthat::expect_match(info_help, "Metadata is not part of \\code{snapshot_hash}", fixed = TRUE)
  testthat::expect_false(grepl("Snapshot info \\(v0\\.1\\.1\\)", info_help))
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
  exp_doc <- paste(readLines(ledgr_test_source_vignette("experiment-store.qmd"), warn = FALSE), collapse = "\n")
  extract_help <- paste(readLines(extract_path, warn = FALSE), collapse = "\n")

  testthat::expect_match(readme, "ledgr_extract_strategy\\(snapshot, \"readme_sma_crossover\", trust = FALSE\\)")
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
  doc <- paste(readLines(ledgr_test_source_vignette("reproducibility.qmd"), warn = FALSE), collapse = "\n")
  root <- testthat::test_path("..", "..")
  pkgdown <- paste(readLines(file.path(root, "_pkgdown.yml"), warn = FALSE), collapse = "\n")
  exp_doc <- paste(readLines(ledgr_test_source_vignette("experiment-store.qmd"), warn = FALSE), collapse = "\n")
  experiment_help <- paste(readLines(file.path(root, "man", "ledgr_experiment.Rd"), warn = FALSE), collapse = "\n")
  preflight_help <- paste(readLines(file.path(root, "man", "ledgr_strategy_preflight.Rd"), warn = FALSE), collapse = "\n")

  testthat::expect_match(pkgdown, "- reproducibility", fixed = TRUE)
  testthat::expect_match(doc, "Evidence is not validation", fixed = TRUE)
  testthat::expect_match(doc, "Provenance records what ran", fixed = TRUE)
  testthat::expect_match(doc, "does not prove that a selected strategy will\\s+generalize")
  testthat::expect_match(doc, "not statistical validation of the\\s+selection rule")
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
  testthat::expect_match(doc, "Tier 1: Self-Contained", fixed = TRUE)
  testthat::expect_match(doc, "Tier 1 means ledgr can inspect the strategy", fixed = TRUE)
  testthat::expect_match(doc, "Tier 2", fixed = TRUE)
  testthat::expect_match(doc, "Tier 2: Inspectable With User-Managed Environment", fixed = TRUE)
  testthat::expect_match(doc, "Tier 2 means ledgr can inspect and run the strategy", fixed = TRUE)
  testthat::expect_match(doc, "Tier 3", fixed = TRUE)
  testthat::expect_match(doc, "Tier 3: Rejected External State", fixed = TRUE)
  testthat::expect_match(doc, "Tier 3 means the strategy depends on external state", fixed = TRUE)
  testthat::expect_match(doc, "::: {.ledgr-callout .ledgr-callout-important}", fixed = TRUE)
  testthat::expect_match(doc, "There is no\\s+`force = TRUE`\\s+override")
  testthat::expect_match(doc, "ledgr_run\\(\\)` or `ledgr_sweep\\(\\)")
  testthat::expect_match(doc, "do.call\\(\"Sys.time\", list\\(\\)\\)")
  testthat::expect_match(doc, "attr\\(ctx, \"secret\"\\) <- 1")
  testthat::expect_match(doc, "Recommended-R functions such as `stats::median()` remain Tier", fixed = TRUE)
  testthat::expect_match(doc, "Ambient strategy RNG calls such as `runif(1)`", fixed = TRUE)
  testthat::expect_match(doc, "custom-indicator RNG restrictions", fixed = TRUE)
  testthat::expect_match(doc, "Captured mutable environments may be classified as Tier 2", fixed = TRUE)
  testthat::expect_match(doc, "Do not treat that classification as approval", fixed = TRUE)
  testthat::expect_match(doc, "ledgr_strategy_tier3", fixed = TRUE)
  testthat::expect_match(doc, "ledgr_strategy_preflight_error", fixed = TRUE)
  testthat::expect_match(doc, "renv", fixed = TRUE)
  testthat::expect_match(doc, "Docker", fixed = TRUE)
  testthat::expect_match(doc, "github.com/ropensci/rix", fixed = TRUE)
  testthat::expect_match(doc, "github.com/nbafrank/uvr", fixed = TRUE)
  testthat::expect_match(exp_doc, "vignette\\(\"reproducibility\", package =\\s+\"ledgr\"\\)")
  testthat::expect_match(experiment_help, "vignette(\"reproducibility\", package = \"ledgr\")", fixed = TRUE)
  testthat::expect_match(preflight_help, "vignette(\"reproducibility\", package = \"ledgr\")", fixed = TRUE)
  testthat::expect_match(preflight_help, "do.call\\(\\\"Sys.time\\\", list\\(\\)\\)")
  testthat::expect_match(preflight_help, "attr\\(ctx, \\\"secret\\\"\\) <- 1")
  testthat::expect_match(preflight_help, "Ambient strategy RNG calls", fixed = TRUE)
})

testthat::test_that("leakage article teaches boundaries without overclaiming", {
  doc <- paste(readLines(ledgr_test_source_vignette("leakage.qmd"), warn = FALSE), collapse = "\n")
  strategy_doc <- paste(readLines(ledgr_test_source_vignette("strategy-development.qmd"), warn = FALSE), collapse = "\n")
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
  testthat::expect_no_match(strategy_doc, "ctx\\$equity\\(\\)")
  testthat::expect_false(grepl("has no object from which it can accidentally read tomorrow", strategy_doc, fixed = TRUE))
})

testthat::test_that("research-to-production docs do not overclaim broker reconciliation", {
  doc <- paste(readLines(ledgr_test_source_vignette("research-to-production.qmd"), warn = FALSE), collapse = "\n")

  testthat::expect_no_match(doc, "No reconciliation step is needed", fixed = TRUE)
  testthat::expect_no_match(doc, "The ledger is the state", fixed = TRUE)
  testthat::expect_match(doc, "The ledger reconstructs ledgr's expected state", fixed = TRUE)
  testthat::expect_match(doc, "reconciled against broker-reported", fixed = TRUE)
  testthat::expect_match(doc, "Design Philosophy: From Research to Production", fixed = TRUE)
  testthat::expect_match(doc, "What v0.1.x Delivers Today", fixed = TRUE)
})

testthat::test_that("custom indicator article replaces stale placeholders", {
  root <- testthat::test_path("..", "..")
  custom_qmd <- file.path(root, "vignettes", "custom-indicators.qmd")
  custom_md <- file.path(root, "vignettes", "custom-indicators.md")
  interactive_md <- file.path(root, "vignettes", "interactive-strategy-development.md")
  pkgdown_path <- file.path(root, "_pkgdown.yml")
  testthat::skip_if_not(
    file.exists(custom_qmd) && file.exists(custom_md) && file.exists(pkgdown_path),
    "source custom-indicator docs unavailable during installed-package tests"
  )
  pkgdown <- paste(readLines(pkgdown_path, warn = FALSE), collapse = "\n")

  testthat::expect_true(file.exists(custom_qmd))
  testthat::expect_true(file.exists(custom_md))
  testthat::expect_false(file.exists(file.path(root, "vignettes", "custom-indicators.Rmd")))
  testthat::expect_false(file.exists(interactive_md))
  testthat::expect_match(pkgdown, "- custom-indicators", fixed = TRUE)

  doc <- paste(readLines(custom_qmd, warn = FALSE), collapse = "\n")
  rendered <- paste(readLines(custom_md, warn = FALSE), collapse = "\n")

  for (text in list(doc, rendered)) {
    testthat::expect_no_match(text, "Full content in v0.1.3", fixed = TRUE)
  }

  testthat::expect_match(doc, "ledgr_indicator", fixed = TRUE)
  testthat::expect_match(doc, "fn\\(window, params\\)")
  testthat::expect_match(doc, "series_fn\\(bars, params\\)")
  testthat::expect_match(doc, "uses\\s+`series_fn` for full-series feature computation")
  testthat::expect_match(doc, "They should be equivalent after warmup", fixed = TRUE)
  testthat::expect_match(doc, "sides = 1", fixed = TRUE)
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
  testthat::expect_match(doc, "summary\\(custom_bt\\)")
  testthat::expect_match(doc, "ledgr_results\\(custom_bt, what = \"fills\"\\)")
  testthat::expect_match(doc, "ledgr_results\\(custom_bt, what = \"trades\"\\)")
  testthat::expect_match(doc, "does\\s+not change the strategy return contract")
  testthat::expect_no_match(doc, "ctx\\$feature\\(\"AAA\"")
  testthat::expect_match(doc, "for \\(id in ctx\\$universe\\)")
})

testthat::test_that("snapshot Yahoo and seal docs state lifecycle boundaries", {
  root <- testthat::test_path("..", "..")
  yahoo_path <- file.path(root, "man", "ledgr_snapshot_from_yahoo.Rd")
  seal_path <- file.path(root, "man", "ledgr_snapshot_seal.Rd")
  testthat::skip_if_not(file.exists(yahoo_path) && file.exists(seal_path), "man pages not available during installed-package tests")
  yahoo_help <- paste(readLines(yahoo_path, warn = FALSE), collapse = "\n")
  seal_help <- paste(readLines(seal_path, warn = FALSE), collapse = "\n")

  testthat::expect_match(yahoo_help, "returned handle is already sealed", fixed = TRUE)
  testthat::expect_match(yahoo_help, "ledgr_snapshot_seal(snapshot)", fixed = TRUE)
  testthat::expect_match(yahoo_help, "idempotent verification", fixed = TRUE)
  testthat::expect_match(yahoo_help, "quantmod may emit harmless", fixed = TRUE)
  testthat::expect_match(yahoo_help, "S3 method-overwrite messages", fixed = TRUE)
  testthat::expect_match(yahoo_help, "stderr", fixed = TRUE)
  testthat::expect_match(seal_help, "idempotent", fixed = TRUE)
  testthat::expect_match(seal_help, "Already sealed snapshots return their existing hash", fixed = TRUE)
  testthat::expect_match(seal_help, "returns an invisible list with \\\\code\\{\\$hash\\} and \\\\code\\{\\$snapshot\\}")
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

  installed_articles <- tools::file_path_sans_ext(basename(list.files(vignettes_dir, pattern = "[.](Rmd|qmd)$", full.names = TRUE)))
  testthat::expect_true(all(linked_articles %in% installed_articles))
  testthat::expect_true("indicators" %in% installed_articles)
  testthat::expect_false("ttr-indicators" %in% installed_articles)
  testthat::expect_false("who-ledgr-is-for" %in% linked_articles)
  testthat::expect_false("why-r" %in% linked_articles)
})

testthat::test_that("formal disclaimer is available at the installed vignette link target", {
  root <- testthat::test_path("..", "..")
  source_disclaimer_path <- file.path(root, "DISCLAIMER.md")
  installed_disclaimer_path <- file.path(root, "inst", "DISCLAIMER.md")
  workflow_path <- ledgr_test_source_vignette("research-workflow.qmd")
  pkgdown_audience_path <- file.path(root, "vignettes", "articles", "who-ledgr-is-for.qmd")
  testthat::skip_if_not(
    file.exists(source_disclaimer_path) && file.exists(workflow_path) && file.exists(pkgdown_audience_path),
    "source disclaimer files not available during installed-package tests"
  )

  source_disclaimer <- paste(readLines(source_disclaimer_path, warn = FALSE), collapse = "\n")
  installed_disclaimer <- paste(readLines(installed_disclaimer_path, warn = FALSE), collapse = "\n")
  workflow <- paste(readLines(workflow_path, warn = FALSE), collapse = "\n")
  pkgdown_audience <- paste(readLines(pkgdown_audience_path, warn = FALSE), collapse = "\n")

  testthat::expect_true(file.exists(installed_disclaimer_path))
  testthat::expect_identical(installed_disclaimer, source_disclaimer)
  testthat::expect_match(workflow, "[disclaimer](../DISCLAIMER.md)", fixed = TRUE)
  testthat::expect_match(pkgdown_audience, "https://github.com/blechturm/ledgr/blob/main/DISCLAIMER.md", fixed = TRUE)
  testthat::expect_no_match(pkgdown_audience, "[disclaimer](../../DISCLAIMER.md)", fixed = TRUE)
  testthat::expect_match(source_disclaimer, "not\\s+investment advice")
})

testthat::test_that("v0.1.9.1 condition classes have discoverable help aliases", {
  root <- testthat::test_path("..", "..")
  condition_path <- file.path(root, "man", "ledgr_condition_classes.Rd")
  testthat::skip_if_not(file.exists(condition_path), "condition help topic not available during installed-package tests")
  doc <- paste(readLines(condition_path, warn = FALSE), collapse = "\n")

  classes <- c(
    "ledgr_legacy_fill_model_shape",
    "ledgr_legacy_config_shape",
    "ledgr_cost_model_unspecified",
    "ledgr_invalid_cost_chain_order",
    "ledgr_invalid_cost_model",
    "ledgr_invalid_timing_model",
    "ledgr_invalid_fill_proposal",
    "ledgr_invalid_fill_context",
    "ledgr_run_not_found",
    "ledgr_unresolved_feature_id"
  )
  for (class in classes) {
    testthat::expect_match(doc, paste0("\\alias{", class, "}"), fixed = TRUE)
    testthat::expect_match(doc, class, fixed = TRUE)
  }

  testthat::expect_match(doc, "stable top-level condition classes", fixed = TRUE)
  testthat::expect_match(doc, "assert on these", fixed = TRUE)
  testthat::expect_match(doc, "does not translate the legacy shape", fixed = TRUE)
  testthat::expect_match(doc, "ledgr_cost_zero", fixed = TRUE)
  testthat::expect_match(doc, "price-transform steps before explicit-fee steps", fixed = TRUE)
  testthat::expect_no_match(doc, "deprecat", ignore.case = TRUE)
})

testthat::test_that("LEDGR_LAST_BAR_NO_FILL help topic documents final-bar behavior", {
  root <- testthat::test_path("..", "..")
  warning_path <- file.path(root, "man", "LEDGR_LAST_BAR_NO_FILL.Rd")
  execution_path <- ledgr_test_source_vignette("execution-semantics.qmd")
  testthat::skip_if_not(file.exists(warning_path), "final-bar warning help topic not available during installed-package tests")

  warning_doc <- paste(readLines(warning_path, warn = FALSE), collapse = "\n")
  execution_doc <- paste(readLines(execution_path, warn = FALSE), collapse = "\n")

  testthat::expect_match(warning_doc, "\\alias{LEDGR_LAST_BAR_NO_FILL}", fixed = TRUE)
  testthat::expect_match(warning_doc, "No fill is emitted", fixed = TRUE)
  testthat::expect_match(warning_doc, "ledger is left", fixed = TRUE)
  testthat::expect_match(warning_doc, "candidate-row warning", fixed = TRUE)
  testthat::expect_match(warning_doc, "execution-semantics", fixed = TRUE)
  testthat::expect_match(execution_doc, "?LEDGR_LAST_BAR_NO_FILL", fixed = TRUE)
})

testthat::test_that("research-to-production vignette reflects v0.1.9.1 cost API surface", {
  qmd_path <- ledgr_test_source_vignette("research-to-production.qmd")
  md_path <- file.path(testthat::test_path("..", ".."), "vignettes", "research-to-production.md")
  testthat::skip_if_not(file.exists(qmd_path) && file.exists(md_path), "research-to-production docs not available")

  docs <- vapply(
    c(qmd = qmd_path, md = md_path),
    function(path) paste(readLines(path, warn = FALSE), collapse = "\n"),
    character(1)
  )

  for (doc in docs) {
    testthat::expect_match(doc, "timing_model", fixed = TRUE)
    testthat::expect_match(doc, "cost_model", fixed = TRUE)
    testthat::expect_match(doc, "ledgr_cost_zero", fixed = TRUE)
    testthat::expect_match(doc, "ledgr_cost_spread_bps", fixed = TRUE)
    testthat::expect_match(doc, "quoted-spread convention", fixed = TRUE)
    testthat::expect_match(doc, "cost_model_hash", fixed = TRUE)
    testthat::expect_match(doc, "cost_plan_json", fixed = TRUE)
    testthat::expect_no_match(doc, "fill_model", fixed = TRUE)
    testthat::expect_no_match(doc, "commission_fixed", fixed = TRUE)
  }
})
