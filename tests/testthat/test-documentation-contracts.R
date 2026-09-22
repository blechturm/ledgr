# ledgr-test-file-profile: review
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

testthat::test_that("feature documentation teaches discovery, aliases, and materialization boundaries", {
  local({
  strategy_doc <- readLines(ledgr_test_source_vignette("strategy-authoring-tools.qmd"), warn = FALSE)
  indicators_doc <- readLines(ledgr_test_source_vignette("indicators.qmd"), warn = FALSE)

  first_strategy_feature_id <- grep("ledgr_feature_id", strategy_doc)[[1]]
  first_strategy_lookup <- grep("\\$feature\\([^)]*\"", strategy_doc)[[1]]
  testthat::expect_lt(first_strategy_feature_id, first_strategy_lookup)

  first_indicator_feature_id <- grep("ledgr_feature_id", indicators_doc)[[1]]
  first_indicator_lookup <- grep("\\$feature\\([^)]*\"", indicators_doc)[[1]]
  testthat::expect_lt(first_indicator_feature_id, first_indicator_lookup)
  })

  # Also covers: feature-map docs preserve teaching order and semantic boundaries
  local({
  strategy_lines <- readLines(ledgr_test_source_vignette("strategy-authoring-tools.qmd"), warn = FALSE)
  strategy_doc <- paste(c(
    readLines(ledgr_test_source_vignette("strategy-development.qmd"), warn = FALSE),
    strategy_lines
  ), collapse = "\n")
  indicators_doc <- paste(readLines(ledgr_test_source_vignette("indicators.qmd"), warn = FALSE), collapse = "\n")
  root <- testthat::test_path("..", "..")
  feature_map_help <- paste(readLines(file.path(root, "man", "ledgr_feature_map.Rd"), warn = FALSE), collapse = "\n")
  warmup_help <- paste(readLines(file.path(root, "man", "ledgr_passed_warmup.Rd"), warn = FALSE), collapse = "\n")

  first_scalar_lookup <- grep("ctx\\$feature\\(", strategy_lines)[[1]]
  first_feature_map <- grep("ledgr_feature_map", strategy_lines)[[1]]
  testthat::expect_lt(first_scalar_lookup, first_feature_map)

  testthat::expect_match(strategy_doc, "Feature Maps For Readable Feature Access", fixed = TRUE)
  testthat::expect_match(strategy_doc, "A \\*\\*target vector\\*\\* is the strategy's requested holdings")
  testthat::expect_match(strategy_doc, "`ctx` is the \\*\\*pulse context\\*\\*")
  testthat::expect_match(strategy_doc, "pulse t state<br/>bars through t", fixed = TRUE)
  testthat::expect_match(strategy_doc, "strategy\\(ctx, params\\)")
  testthat::expect_match(strategy_doc, "Change `buy_if_up\\(\\)`")
  testthat::expect_match(strategy_doc, "`params` is the run's \\*\\*strategy configuration\\*\\*")
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
  testthat::expect_match(strategy_doc, "?ledgr_passed_warmup", fixed = TRUE)
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
  testthat::expect_match(feature_map_help, "ledgr_passed_warmup", fixed = TRUE)
  testthat::expect_match(feature_map_help, "x[[\"ret_5\"]]", fixed = TRUE)
  testthat::expect_match(warmup_help, "not a signal pipeline transformation", fixed = TRUE)
  testthat::expect_match(warmup_help, "ledgr_empty_warmup_input", fixed = TRUE)
  })

  # Also covers: feature contract check docs state factory materialization boundary
  local({
  root <- testthat::test_path("..", "..")
  help_path <- file.path(root, "man", "ledgr_feature_contract_check.Rd")
  help_exists <- file.exists(help_path)
  testthat::expect_true(help_exists, info = "feature-contract help source is required in the review lane")
  if (help_exists) {
    help <- paste(readLines(help_path, warn = FALSE), collapse = "\n")

    testthat::expect_match(help, "feature factories", ignore.case = TRUE)
    testthat::expect_match(help, "Materialize the factory first", fixed = TRUE)
    testthat::expect_match(help, "ledgr_feature_factory_requires_params", fixed = TRUE)
  }
  })
})

testthat::test_that("indicator docs include compact multi-output ID references", {
  indicators_doc <- paste(readLines(ledgr_test_source_vignette("indicators.qmd"), warn = FALSE), collapse = "\n")
  ttr_doc <- paste(readLines(ledgr_test_source_vignette("ttr-and-adapter-indicators.qmd"), warn = FALSE), collapse = "\n")
  indicator_docs <- paste(indicators_doc, ttr_doc, sep = "\n")
  ttr_help <- paste(readLines(testthat::test_path("..", "..", "man", "ledgr_ind_ttr.Rd"), warn = FALSE), collapse = "\n")

  testthat::expect_match(indicator_docs, "ttr_bbands_20_up", fixed = TRUE)
  testthat::expect_match(indicator_docs, "The MACD ID embeds the explicit arguments", fixed = TRUE)
  testthat::expect_match(indicator_docs, "built-in ledgr indicators, TTR-backed indicators")
  testthat::expect_match(indicator_docs, "SMA crossover", fixed = TRUE)
  testthat::expect_match(indicator_docs, "fast trend above slow trend", fixed = TRUE)
  testthat::expect_match(indicator_docs, "sma_fast", fixed = TRUE)
  testthat::expect_match(indicator_docs, "sma_slow", fixed = TRUE)
  testthat::expect_match(indicator_docs, "RSI is a common mean-reversion input", fixed = TRUE)
  testthat::expect_match(indicator_docs, "rsi_exp <- ledgr_experiment", fixed = TRUE)
  testthat::expect_match(indicator_docs, "rsi_bt <- ledgr_run", fixed = TRUE)
  testthat::expect_match(indicator_docs, "mixed feature map combines a built-in return feature", fixed = TRUE)
  testthat::expect_match(indicator_docs, "return_5", fixed = TRUE)
  testthat::expect_match(indicator_docs, "Native RSI", fixed = TRUE)
  testthat::expect_match(indicator_docs, "ledgr_ind_rsi\\(14\\)")
  testthat::expect_match(indicator_docs, "rsi_14", fixed = TRUE)
  testthat::expect_match(indicator_docs, "ttr_rsi_14", fixed = TRUE)
  testthat::expect_match(indicators_doc, "Feature objects appear in three registration and inspection places", fixed = TRUE)
  testthat::expect_match(indicators_doc, "The strategy context then exposes the computed values through accessors", fixed = TRUE)
  testthat::expect_match(indicators_doc, "Feature Lifecycle: From Declaration To Lookup", fixed = TRUE)
  testthat::expect_match(indicators_doc, "access<br/>ctx feature methods", fixed = TRUE)
  testthat::expect_match(indicators_doc, "declaration. Static lists and feature maps", fixed = TRUE)
  testthat::expect_match(indicators_doc, "Active-alias features are materialized for concrete", fixed = TRUE)
  testthat::expect_match(indicators_doc, "deduplicates shared indicator\\s+fingerprints")
  testthat::expect_match(indicators_doc, "Feature IDs\\s+identify values inside the pulse context")
  testthat::expect_match(indicators_doc, "A \\*\\*fingerprint\\*\\* identifies the feature definition")
  testthat::expect_no_match(indicators_doc, "\\*\\*Definition\\*\\*")
  testthat::expect_match(indicators_doc, "output-specific fingerprint", fixed = TRUE)
  testthat::expect_match(indicators_doc, "A feature-map alias never changes\\s+the underlying engine feature ID")
  testthat::expect_match(indicator_docs, "multi-output bundle helper follows the same\\s+lifecycle")
  testthat::expect_match(indicator_docs, "A \\*\\*bundle\\*\\* is an authoring convenience")
  testthat::expect_match(indicator_docs, "ledgr_ind_ttr_outputs", fixed = TRUE)
  testthat::expect_match(indicator_docs, "bbands_dn", fixed = TRUE)
  testthat::expect_match(indicator_docs, "bbands_pctb", fixed = TRUE)
  testthat::expect_match(indicator_docs, "shorter than the hand-written single-output TTR IDs", fixed = TRUE)
  testthat::expect_match(indicator_docs, "naming = c\\(up = \"ttr_bbands_20_up\"\\)")
  testthat::expect_match(indicator_docs, "prefix = NULL", fixed = TRUE)
  testthat::expect_match(indicator_docs, "Raw names are short and can collide", fixed = TRUE)
  testthat::expect_match(indicator_docs, "A single alias on the bundle argument is ignored", fixed = TRUE)
  testthat::expect_match(indicator_docs, "Control the generated feature IDs\\s+with the bundle's `prefix` argument")
  testthat::expect_match(indicator_docs, "`naming` renames selected outputs; it is not itself an output filter", fixed = TRUE)
  testthat::expect_match(indicators_doc, "ctx\\$feature\\(id, feature_id\\)")
  testthat::expect_match(indicators_doc, "ctx\\$features\\(id, feature_map\\)")
  testthat::expect_match(indicators_doc, "ledgr computes indicators\\s+into pulse-known values")
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
  testthat::expect_match(indicators_doc, "vignette(\"ttr-and-adapter-indicators\", package = \"ledgr\")", fixed = TRUE)
  testthat::expect_no_match(indicators_doc, "feature factories", ignore.case = TRUE)
  testthat::expect_match(indicators_doc, "{instrument_id}__ohlcv_{field}", fixed = TRUE)
  testthat::expect_match(indicators_doc, "{instrument_id}__feature_{feature_id}", fixed = TRUE)
  testthat::expect_match(indicator_docs, "install.packages\\(\"TTR\"\\)")
  testthat::expect_match(indicator_docs, "choose a timestamp late enough for the indicator warmup", fixed = TRUE)
  testthat::expect_match(indicator_docs, "same TTR feature map to `ledgr_pulse_snapshot()`", fixed = TRUE)
  testthat::expect_no_match(ttr_doc, "dplyr::filter", fixed = TRUE)
  testthat::expect_no_match(ttr_doc, "dplyr::between", fixed = TRUE)
  testthat::expect_match(indicator_docs, "Troubleshoot Warmup And Zero Trades", fixed = TRUE)
  testthat::expect_match(indicator_docs, "\\*\\*Warmup\\*\\* is the period before a known feature")
  testthat::expect_match(indicator_docs, "Change the scalar accessor", fixed = TRUE)
  testthat::expect_match(indicator_docs, "available bars are below the feature contract", fixed = TRUE)
  testthat::expect_match(indicator_docs, "`summary(bt)` prints `Warmup Diagnostics`", fixed = TRUE)
  testthat::expect_match(indicator_docs, "Impossible warmup is different", fixed = TRUE)
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

testthat::test_that("availability runtime and strict-feature contracts stay bound", {
  root <- testthat::test_path("..", "..")
  contracts_path <- file.path(root, "inst", "design", "contracts.md")
  testthat::skip_if_not(
    file.exists(contracts_path),
    "availability contracts unavailable during installed-package tests"
  )
  contracts <- paste(
    readLines(contracts_path, warn = FALSE),
    collapse = "\n"
  )
  testthat::expect_match(
    contracts,
    "Availability-aware execution activates when a snapshot declares membership"
  )
  testthat::expect_match(contracts, "There is no mode flag", fixed = TRUE)
  testthat::expect_match(
    contracts,
    paste0(
      "complete declared session\\s+calendar and an explicit ",
      "`ledgr_valuation_stale\\(max_sessions\\)` policy"
    )
  )
  testthat::expect_match(
    contracts,
    "character-vector universe remains a fixed basket",
    fixed = TRUE
  )
  testthat::expect_match(
    contracts,
    "`facts`,\\s+`decision_view`, `execution_view`, `history`, and `identity` operations"
  )
  testthat::expect_match(
    contracts,
    paste0(
      "decision axis preserves declared member order for character-vector universes[.]",
      "\\s+For membership-rule universes, members are ordered by C-locale stable ID"
    )
  )
  testthat::expect_match(
    contracts,
    "effective but not yet knowable cannot\\s+shadow a lower-precedence tie"
  )
  testthat::expect_match(
    contracts,
    "`ctx\\$members` and universe-aligned\\s+`ctx\\$vec\\$member`, `held`, `target_restricted`"
  )
  testthat::expect_match(
    contracts,
    "`ctx\\$state_prev\\$asset_state` as a named\\s+list keyed by stable instrument ID"
  )
  testthat::expect_match(
    contracts,
    "returned keys outside the current axis fail closed with\\s+`ledgr_invalid_strategy_state`"
  )
  testthat::expect_match(
    contracts,
    paste0(
      "compiled spot-FIFO request fails before execution with\\s+",
      "`ledgr_compiled_availability_unsupported`"
    )
  )
  testthat::expect_match(
    contracts,
    "`gap_contract = \"strict_window\"`",
    fixed = TRUE
  )
  testthat::expect_match(
    contracts,
    "Any missing required\\s+observation makes the affected window `NA_real_`"
  )
  testthat::expect_match(
    contracts,
    "Dense indicator fingerprints and feature-engine\\s+identity omit the availability declaration"
  )

  condition_doc <- paste(
    readLines(file.path(root, "man", "ledgr_condition_classes.Rd"), warn = FALSE),
    collapse = "\n"
  )
  availability_classes <- c(
    "ledgr_invalid_valuation_policy",
    "ledgr_availability_inactive",
    "ledgr_availability_sessions_required",
    "ledgr_valuation_policy_required",
    "ledgr_membership_universe_not_found",
    "ledgr_compiled_availability_unsupported",
    "ledgr_execution_timing_version_mismatch",
    "ledgr_fill_timing_not_comparable",
    "ledgr_indicator_gap_unsupported",
    "ledgr_indicator_gap_parity",
    "ledgr_invalid_strategy_state",
    "ledgr_target_sizing_unavailable",
    "ledgr_restricted_target",
    "ledgr_nonmember_exposure_increase",
    "ledgr_post_risk_inadmissible",
    "ledgr_short_exposure_unsupported",
    "ledgr_affordability_reconciliation_failed",
    "ledgr_run_terminal_evidence_invalid",
    "ledgr_incomplete_sweep_candidate",
    "ledgr_promote_incomplete_candidate",
    "ledgr_run_explanation_unavailable"
  )
  for (class in availability_classes) {
    testthat::expect_match(condition_doc, paste0("\\alias{", class, "}"), fixed = TRUE)
    testthat::expect_match(condition_doc, paste0("\\code{", class, "}"), fixed = TRUE)
  }
})



testthat::test_that("source and installed article boundaries stay explicit", {
  local({
  root <- testthat::test_path("..", "..")
  articles <- file.path(root, "vignettes", "articles")
  articles_exist <- dir.exists(articles)
  testthat::expect_true(articles_exist, info = "source articles are required in the review lane")
  if (articles_exist) {
    testthat::expect_true(file.exists(file.path(articles, "who-ledgr-is-for.qmd")))
    testthat::expect_true(file.exists(file.path(articles, "why-r.qmd")))
    testthat::expect_false(file.exists(file.path(articles, "who-ledgr-is-for.Rmd")))
    testthat::expect_false(file.exists(file.path(articles, "why-r.Rmd")))
    testthat::expect_false(file.exists(file.path(root, "vignettes", "who-ledgr-is-for.Rmd")))
    testthat::expect_false(file.exists(file.path(root, "vignettes", "why-r.Rmd")))
    testthat::expect_false(file.exists(file.path(root, "inst", "doc", "who-ledgr-is-for.Rmd")))
    testthat::expect_false(file.exists(file.path(root, "inst", "doc", "why-r.Rmd")))
  }
  })

  # Also covers: retired TTR indicator article is not installed
  local({
  root <- testthat::test_path("..", "..")
  testthat::expect_false(file.exists(file.path(root, "vignettes", "ttr-indicators.qmd")))
  testthat::expect_false(file.exists(file.path(root, "inst", "doc", "ttr-indicators.qmd")))
  testthat::expect_false(file.exists(file.path(root, "inst", "doc", "ttr-indicators.R")))
  testthat::expect_false(file.exists(file.path(root, "inst", "doc", "ttr-indicators.html")))
  })
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

testthat::test_that("public navigation avoids hidden helpers and non-runnable first paths", {
  local({
  root <- testthat::test_path("..", "..")
  paths <- c(
    file.path(root, "README.Rmd"),
    list.files(file.path(root, "vignettes"), pattern = "[.](Rmd|qmd|md)$", full.names = TRUE)
  )
  paths <- paths[file.exists(paths)]
  text <- paste(unlist(lapply(paths, readLines, warn = FALSE)), collapse = "\n")

  testthat::expect_no_match(text, "article_utc\\(")
  })

  # Also covers: first-path navigation avoids non-runnable examples
  local({
  root <- testthat::test_path("..", "..")
  pkgdown <- file.path(root, "_pkgdown.yml")
  readme <- file.path(root, "README.Rmd")
  examples_readme <- file.path(root, "inst", "examples", "README.md")
  navigation_exists <- file.exists(pkgdown) && file.exists(readme)
  testthat::expect_true(navigation_exists, info = "navigation sources are required in the review lane")
  if (navigation_exists) {
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
  }
  })
})


testthat::test_that("help pages provide browser-free paths to installed articles", {
  local({
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

  # Also covers: core help pages point to installed articles with browser-free paths
  local({
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
    ledgr_pbo = "selection-integrity",
    ledgr_min_track_record = "selection-integrity",
    ledgr_candidate = "sweeps",
    ledgr_candidate_reproduction_key = "sweeps",
    ledgr_promote = "sweeps",
    ledgr_promotion_context = "sweeps",
    ledgr_run_promotion_context = "sweeps",
    ledgr_run_info = "sweeps",
    ledgr_strategy_context = c("strategy-development", "indicators"),
    ledgr_results = "metrics-and-accounting",
    ledgr_run_compare = c("experiment-store", "metrics-and-accounting"),
    ledgr_snapshot_from_df = "experiment-store",
    ledgr_snapshot_from_csv = "experiment-store",
    ledgr_snapshot_from_yahoo = "experiment-store",
    ledgr_snapshot_create = "experiment-store",
    ledgr_snapshot_import_bars_csv = "experiment-store",
    ledgr_snapshot_seal = "experiment-store",
    ledgr_snapshot_open = "experiment-store",
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
    ledgr_signal_return = "strategy-development",
    ledgr_select_top_n = "strategy-development",
    ledgr_weight_equal = "strategy-development",
    ledgr_target_rebalance = "strategy-development",
    ledgr_feature_map = c("strategy-development", "indicators"),
    ledgr_passed_warmup = c("strategy-development", "indicators"),
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






testthat::test_that("contracts bind evidence-only business objectives and criteria", {
  root <- testthat::test_path("..", "..")
  contracts <- file.path(root, "inst", "design", "contracts.md")
  tickets <- file.path(
    root,
    "inst",
    "design",
    "ledgr_v0_1_9_7_spec_packet",
    "v0_1_9_7_tickets.md"
  )
  testthat::skip_if_not(file.exists(contracts) && file.exists(tickets), "objective contracts unavailable")
  text <- paste(readLines(contracts, warn = FALSE), collapse = "\n")
  ticket_text <- paste(readLines(tickets, warn = FALSE), collapse = "\n")

  testthat::expect_match(text, "one v1 rule: all\\s+criteria must pass")
  testthat::expect_match(text, "a stored\\s+replacement closure is never trusted as criterion authority")
  testthat::expect_match(text, "not a public third-party extension contract", fixed = TRUE)
  testthat::expect_match(text, "a deterministic\\s+`business_objective_hash` over its ordered criterion-step payloads")
  testthat::expect_match(text, "The hash is objective provenance only", fixed = TRUE)
  testthat::expect_match(text, "must\\s+not alter run, config, snapshot, sweep, candidate, promotion, session, or\\s+walk-forward identity")
  testthat::expect_match(text, "do not evaluate a sweep, rank\\s+candidates, select a winner, promote a candidate, or persist evidence")
  testthat::expect_match(text, "Positive trajectory\\s+regresses cumulative log equity on the\\s+zero-based retained-row index")
  testthat::expect_match(
    text,
    "canonical signed drawdown metric is exposed by the criterion\\s+as a positive loss magnitude"
  )
  testthat::expect_match(text, "four equal-duration bins of the\\s+sweep scoring interval")
  testthat::expect_match(text, "largest absolute\\s+`realized_pnl` share of total absolute closed-trade realized P&L")
  testthat::expect_match(text, "deterministic `trade_seq`\\s+order")
  testthat::expect_match(text, "strict-lattice operationalization of Pardo's broad\\s+parameter-plateau idea")
  testthat::expect_match(text, "Adjacency is Manhattan\\s+distance one in level-index space")
  testthat::expect_match(text, "`min_neighbors` is the only eligibility control", fixed = TRUE)
  testthat::expect_match(text, "Boundary candidates have\\s+fewer available neighbors")
  testthat::expect_match(text, "`ledgr_objective_diagnostic_threshold\\(\\)` embeds a hashed, serializable")
  testthat::expect_match(text, "`min_track_record_length` / `status`", fixed = TRUE)
  testthat::expect_match(text, "recomputes no diagnostic, and makes no\\s+profitability endorsement")
  testthat::expect_match(text, "preserve `Inf` and\\s+`-Inf` as determinate boundary evidence")
  testthat::expect_match(text, "PBO/CSCV is sweep-level evidence", fixed = TRUE)
  testthat::expect_match(ticket_text, "`min_track_record_length` / `status`", fixed = TRUE)
  testthat::expect_no_match(ticket_text, "`min_TRL`", fixed = TRUE)
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
  testthat::expect_match(text, "ledgr_signal_return()", fixed = TRUE)
  testthat::expect_match(text, "ledgr_select_top_n()", fixed = TRUE)
  testthat::expect_match(text, "ledgr_passed_warmup()", fixed = TRUE)
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

testthat::test_that("public result and helper documentation states current semantics", {
  local({
  metrics_doc <- paste(c(
    readLines(ledgr_test_source_vignette("metrics-and-accounting.qmd"), warn = FALSE),
    readLines(ledgr_test_source_vignette("metric-contexts-and-conventions.qmd"), warn = FALSE)
  ), collapse = "\n")
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
  testthat::expect_match(metrics_doc, "A \\*\\*ledger event\\*\\* is the append-only accounting record")
  testthat::expect_match(metrics_doc, "A \\*\\*fill\\*\\* is an execution row")
  testthat::expect_match(metrics_doc, "An \\*\\*equity row\\*\\* values the portfolio")
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
  testthat::expect_match(metrics_doc, "ledgr_metric_context_cadence_mismatch", fixed = TRUE)
  testthat::expect_match(metrics_doc, "warning does not change metric", fixed = TRUE)
  testthat::expect_match(metrics_doc, "not first-class intraday execution", fixed = TRUE)
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
  testthat::expect_match(backtest_help, "crosses approximately\\s+\\\\code\\{spread_bps\\}\\s+basis\\s+points before explicit fees")
  testthat::expect_match(experiment_help, "quoted bid/ask\\s+spread")
  testthat::expect_match(experiment_help, "crosses approximately\\s+\\\\code\\{spread_bps\\}\\s+basis\\s+points before explicit fees")

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
  compare_help <- paste(readLines(file.path(root, "man", "ledgr_run_compare.Rd"), warn = FALSE), collapse = "\n")
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
  testthat::expect_match(metrics_doc, "`ledgr_run_compare()` is also programmatic", fixed = TRUE)
  })

  # Also covers: helper docs state composition and whole-share target flooring
  local({
  strategy_development_doc <- paste(readLines(ledgr_test_source_vignette("strategy-development.qmd"), warn = FALSE), collapse = "\n")
  strategy_authoring_doc <- paste(readLines(ledgr_test_source_vignette("strategy-authoring-tools.qmd"), warn = FALSE), collapse = "\n")
  strategy_doc <- paste(strategy_development_doc, strategy_authoring_doc, sep = "\n")
  root <- testthat::test_path("..", "..")
  target_help <- paste(readLines(file.path(root, "man", "ledgr_target_rebalance.Rd"), warn = FALSE), collapse = "\n")
  signal_strategy_help <- paste(readLines(file.path(root, "man", "ledgr_signal_strategy.Rd"), warn = FALSE), collapse = "\n")
  signal_help <- paste(readLines(file.path(root, "man", "ledgr_signal_return.Rd"), warn = FALSE), collapse = "\n")
  select_help <- paste(readLines(file.path(root, "man", "ledgr_select_top_n.Rd"), warn = FALSE), collapse = "\n")
  target_rebalance_help <- paste(readLines(file.path(root, "man", "ledgr_target_rebalance.Rd"), warn = FALSE), collapse = "\n")
  selection_type_help <- paste(readLines(file.path(root, "man", "ledgr_selection.Rd"), warn = FALSE), collapse = "\n")
  context_help <- paste(readLines(file.path(root, "man", "ledgr_strategy_context.Rd"), warn = FALSE), collapse = "\n")

  testthat::expect_match(strategy_doc, "Execution semantics begin only at the target stage", fixed = TRUE)
  testthat::expect_match(strategy_doc, "floors to whole shares", fixed = TRUE)
  testthat::expect_match(strategy_doc, "floor\\(equity_fraction \\* ctx\\$equity / ctx\\$close\\(instrument_id\\)\\)")
  testthat::expect_match(strategy_doc, "Affordability is not automatic", fixed = TRUE)
  testthat::expect_match(strategy_doc, "does not check affordability", fixed = TRUE)
  testthat::expect_match(strategy_doc, "`risk_chain` can transform", fixed = TRUE)
  testthat::expect_match(strategy_doc, "not a cash-affordability", fixed = TRUE)
  testthat::expect_match(strategy_doc, "classed empty selection", fixed = TRUE)
  testthat::expect_match(strategy_doc, "No warning suppression is needed", fixed = TRUE)
  testthat::expect_match(strategy_doc, "Troubleshoot Helper Pipelines", fixed = TRUE)
  testthat::expect_match(strategy_doc, "signal --> selection --> weights --> target_obj --> target_vec", fixed = TRUE)
  testthat::expect_match(strategy_doc, "vignette\\(\"data-input-and-snapshots\",\\s+package = \"ledgr\"\\)")
  testthat::expect_no_match(strategy_development_doc, "\\*\\*Definition\\*\\*")
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
  testthat::expect_match(signal_help, "ledgr_signal_return(ctx, lookback = 5)", fixed = TRUE)
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
})

testthat::test_that("cost documentation contains runnable examples and the current API surface", {
  local({
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
  help_exists <- all(file.exists(help_paths))
  testthat::expect_true(help_exists, info = "cost help sources are required in the review lane")
  if (help_exists) {
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
  }
  })

  # Also covers: research-to-production vignette reflects current cost API surface
  local({
  root <- testthat::test_path("..", "..")
  qmd_candidates <- file.path(
    root,
    "vignettes",
    c("research-to-production.qmd", "research-to-production.Rmd")
  )
  qmd_paths <- qmd_candidates[file.exists(qmd_candidates)]
  md_path <- file.path(root, "vignettes", "research-to-production.md")
  docs_exist <- length(qmd_paths) > 0L && file.exists(md_path)
  testthat::expect_true(docs_exist, info = "research-to-production sources are required in the review lane")
  if (docs_exist) {
    docs <- vapply(
      c(qmd = qmd_paths[[1L]], md = md_path),
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
      testthat::expect_match(doc, "walk-forward evaluation runs over the existing sweep and run surfaces", fixed = TRUE)
      testthat::expect_match(doc, "v0\\.1\\.9\\.6[[:space:]]+shipped DSR, PBO/CSCV, MinTRL")
      testthat::expect_match(doc, "v0\\.1\\.9\\.7[[:space:]]+extends that evidence into[[:space:]]+business-objective eligibility")
      testthat::expect_match(doc, "Paper trading adapters are planned for v0.3.0", fixed = TRUE)
      testthat::expect_match(doc, "observability tooling for", fixed = TRUE)
      testthat::expect_match(doc, "small-scale live trading for v1.0.0", fixed = TRUE)
      testthat::expect_no_match(doc, "fill_model", fixed = TRUE)
      testthat::expect_no_match(doc, "commission_fixed", fixed = TRUE)
      testthat::expect_no_match(doc, "v0.1.9.4 shipped walk-forward evaluation", fixed = TRUE)
      testthat::expect_no_match(doc, "v0.1.9.4 plans walk-forward evaluation", fixed = TRUE)
      testthat::expect_no_match(doc, "later v0.1.9.x work may add selection-integrity diagnostics", fixed = TRUE)
    }
  }
  })
})

testthat::test_that("public site artifacts are current, complete, and quiet", {
  local({
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
  pkgdown_exists <- file.exists(pkgdown)
  testthat::expect_true(pkgdown_exists, info = "pkgdown config is required in the review lane")
  if (pkgdown_exists) {
    pkgdown_text <- paste(readLines(pkgdown, warn = FALSE), collapse = "\n")

    start_here <- regexpr("  - title: Start Here", pkgdown_text, fixed = TRUE)
    core_workflow <- regexpr("  - title: Core Workflow", pkgdown_text, fixed = TRUE)
    going_deeper <- regexpr("  - title: Going Deeper", pkgdown_text, fixed = TRUE)
    design <- regexpr("  - title: Design / Background", pkgdown_text, fixed = TRUE)
    testthat::expect_gt(start_here[[1]], 0)
    testthat::expect_gt(core_workflow[[1]], start_here[[1]])
    testthat::expect_gt(going_deeper[[1]], core_workflow[[1]])
    testthat::expect_gt(design[[1]], going_deeper[[1]])

    start_block <- substr(pkgdown_text, start_here[[1]], core_workflow[[1]] - 1L)
    testthat::expect_match(start_block, "articles/who-ledgr-is-for", fixed = TRUE)
    testthat::expect_match(start_block, "- quickstart", fixed = TRUE)
    testthat::expect_match(start_block, "- research-workflow", fixed = TRUE)
    testthat::expect_match(start_block, "- leakage", fixed = TRUE)
    testthat::expect_match(start_block, "- reproducibility", fixed = TRUE)
    testthat::expect_no_match(start_block, "- survivorship-bias", fixed = TRUE)

    core_block <- substr(pkgdown_text, core_workflow[[1]], going_deeper[[1]] - 1L)
    testthat::expect_match(core_block, "- data-input-and-snapshots", fixed = TRUE)
    testthat::expect_match(core_block, "- survivorship-bias", fixed = TRUE)
    testthat::expect_match(core_block, "- strategy-development", fixed = TRUE)
    testthat::expect_match(core_block, "- indicators", fixed = TRUE)
    testthat::expect_match(core_block, "- metrics-and-accounting", fixed = TRUE)
    testthat::expect_match(core_block, "- risk-and-cost", fixed = TRUE)
    testthat::expect_match(core_block, "- experiment-store", fixed = TRUE)
    testthat::expect_match(core_block, "- sweeps", fixed = TRUE)
    testthat::expect_match(core_block, "- selection-integrity", fixed = TRUE)
    testthat::expect_match(core_block, "- walk-forward", fixed = TRUE)

    deeper_block <- substr(pkgdown_text, going_deeper[[1]], design[[1]] - 1L)
    testthat::expect_match(deeper_block, "- strategy-authoring-tools", fixed = TRUE)
    testthat::expect_match(deeper_block, "- ttr-and-adapter-indicators", fixed = TRUE)
    testthat::expect_match(deeper_block, "- custom-indicators", fixed = TRUE)
    testthat::expect_match(deeper_block, "- metric-contexts-and-conventions", fixed = TRUE)
    testthat::expect_match(deeper_block, "- execution-semantics", fixed = TRUE)

    testthat::expect_no_match(text, "C:\\Users", fixed = TRUE)
    testthat::expect_no_match(text, "custom-indicators.md", fixed = TRUE)
    testthat::expect_no_match(text, "v0.1.7.2 helper layer", fixed = TRUE)
    testthat::expect_no_match(text, "current v0.1.7.6", fixed = TRUE)
    testthat::expect_no_match(text, "This vignette walks through the v0.1.7 research loop", fixed = TRUE)
    testthat::expect_no_match(text, "Sweep and tune APIs are reserved for later versions", fixed = TRUE)
    testthat::expect_no_match(text, "v0.1.8 is the experiment-first research API", fixed = TRUE)
    testthat::expect_no_match(text, "no DISPLAY variable", fixed = TRUE)
    testthat::expect_no_match(text, "Total Trades", fixed = TRUE)
    testthat::expect_false(file.exists(file.path(root, "Rprof.out")))
    testthat::expect_match(paste(readLines(file.path(root, ".gitignore"), warn = FALSE), collapse = "\n"), "Rprof.out", fixed = TRUE)
    testthat::expect_match(
      paste(readLines(file.path(root, ".gitignore"), warn = FALSE), collapse = "\n"),
      "/tests/testthat/Rplots.pdf",
      fixed = TRUE
    )
  }
  })

  # Also covers: rendered vignette artifacts are complete and quiet
  local({
  root <- testthat::test_path("..", "..")
  vignette_dir <- file.path(root, "vignettes")
  markdown <- list.files(vignette_dir, pattern = "[.]md$", full.names = TRUE)
  markdown_exists <- length(markdown) > 0L
  testthat::expect_true(markdown_exists, info = "rendered vignette Markdown is required in the review lane")
  if (markdown_exists) {
    capture_targets <- function(pattern, text) {
      matches <- regmatches(text, gregexpr(pattern, text, perl = TRUE))[[1L]]
      if (length(matches) == 1L && identical(matches, "")) {
        return(character())
      }
      sub(pattern, "\\1", matches, perl = TRUE)
    }

    image_rows <- lapply(markdown, function(path) {
      text <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
      markdown_targets <- capture_targets(
        "!\\[[^]]*\\]\\(<?([^[:space:])>]+)>?[^)]*\\)",
        text
      )
      html_targets <- capture_targets(
        "<img\\b[^>]*\\bsrc\\s*=\\s*[\"']([^\"']+)[\"'][^>]*>",
        text
      )
      targets <- c(markdown_targets, html_targets)
      targets <- targets[!grepl("^(?:[[:alpha:]][[:alnum:]+.-]*:|//|#|/)", targets, perl = TRUE)]
      if (length(targets) == 0L) {
        return(NULL)
      }
      data.frame(source = path, target = targets, stringsAsFactors = FALSE)
    })
    image_rows <- image_rows[!vapply(image_rows, is.null, logical(1))]
    images <- do.call(rbind, image_rows)
    testthat::expect_gte(nrow(images), 7L)

    resolved <- mapply(
      function(source, target) {
        target <- utils::URLdecode(sub("[?#].*$", "", target))
        file.path(dirname(source), target)
      },
      images$source,
      images$target,
      USE.NAMES = FALSE
    )
    missing <- resolved[!file.exists(resolved)]
    testthat::expect_identical(missing, character())

    rendered_text <- paste(unlist(lapply(markdown, readLines, warn = FALSE)), collapse = "\n")
    testthat::expect_no_match(
      rendered_text,
      "duckdb is storing downloaded extensions and secrets",
      fixed = TRUE
    )

    html <- list.files(file.path(root, "docs", "articles"), pattern = "[.]html$", full.names = TRUE)
    if (length(html) > 0L) {
      html_text <- paste(unlist(lapply(html, readLines, warn = FALSE)), collapse = "\n")
      testthat::expect_no_match(
        html_text,
        "duckdb is storing downloaded extensions and secrets",
        fixed = TRUE
      )
    }
  }
  })
})


testthat::test_that("release checks preserve optional-reference and platform gates", {
  local({
  root <- testthat::test_path("..", "..")
  description_path <- file.path(root, "DESCRIPTION")
  dsr_test_path <- file.path(root, "tests", "testthat", "test-validation-dsr.R")
  manual_path <- file.path(root, "dev", "manual", "verify-dsr-quantstrat.R")
  contracts_path <- file.path(root, "inst", "design", "contracts.md")
  render_path <- file.path(root, "tools", "render-vignettes-gfm.R")
  site_path <- file.path(root, "dev", "build-site.R")
  release_sources_exist <- all(
    file.exists(c(
      description_path, dsr_test_path, manual_path, contracts_path,
      render_path, site_path
    ))
  )
  testthat::expect_true(release_sources_exist, info = "release-check sources are required in the review lane")
  if (release_sources_exist) {
    description <- read.dcf(description_path)
    suggests <- trimws(unlist(strsplit(description[, "Suggests"], "[,\n]")))
    dsr_test <- paste(readLines(dsr_test_path, warn = FALSE), collapse = "\n")
    manual <- paste(readLines(manual_path, warn = FALSE), collapse = "\n")
    contracts <- paste(readLines(contracts_path, warn = FALSE), collapse = "\n")
    render <- paste(readLines(render_path, warn = FALSE), collapse = "\n")
    site <- paste(readLines(site_path, warn = FALSE), collapse = "\n")

    testthat::expect_true("pbo" %in% suggests)
    testthat::expect_false("quantstrat" %in% suggests)
    testthat::expect_no_match(dsr_test, 'skip_if_not_installed("quantstrat")', fixed = TRUE)
    testthat::expect_match(manual, 'getFromNamespace(".deflatedSharpe", "quantstrat")', fixed = TRUE)
    testthat::expect_match(contracts, "dev/manual/verify-dsr-quantstrat.R", fixed = TRUE)
    testthat::expect_match(render, 'check_only <- "--check" %in% args', fixed = TRUE)
    testthat::expect_match(render, "normalize_for_freshness", fixed = TRUE)
    testthat::expect_match(site, "duckdb_notice", fixed = TRUE)
    testthat::expect_match(site, "Rendered articles contain DuckDB", fixed = TRUE)
  }
  })

  # Also covers: release playbook records v0.1.7.6 Ubuntu and DuckDB gates
  local({
  root <- testthat::test_path("..", "..")
  playbook <- file.path(root, "inst", "design", "release_ci_playbook.md")
  playbook_exists <- file.exists(playbook)
  testthat::expect_true(playbook_exists, info = "release playbook is required in the review lane")
  if (playbook_exists) {
    text <- paste(readLines(playbook, warn = FALSE), collapse = "\n")

    testthat::expect_match(text, "Local WSL/Ubuntu DuckDB Gate", fixed = TRUE)
    testthat::expect_match(text, "test-schema-validator-side-effects.R", fixed = TRUE)
    testthat::expect_match(text, "test-schema-snapshots.R", fixed = TRUE)
    testthat::expect_match(text, "test-schema.R", fixed = TRUE)
    testthat::expect_match(text, "test-persistence-fresh-connection.R", fixed = TRUE)
    testthat::expect_match(text, "does not replace branch CI", fixed = TRUE)
    testthat::expect_match(text, "tag-triggered CI", fixed = TRUE)
    testthat::expect_match(text, "release certificate", fixed = TRUE)
  }
  })
})


testthat::test_that("package help and help-page links target installed articles", {
  local({
  root <- testthat::test_path("..", "..")
  pkg_help <- file.path(root, "man", "ledgr-package.Rd")
  pkg_help_exists <- file.exists(pkg_help)
  testthat::expect_true(pkg_help_exists, info = "package help source is required in the review lane")
  if (pkg_help_exists) {
  text <- paste(readLines(pkg_help, warn = FALSE), collapse = "\n")

  testthat::expect_match(text, "vignette(package = \"ledgr\")", fixed = TRUE)
  testthat::expect_match(text, "system.file(\"doc\", package = \"ledgr\")", fixed = TRUE)
  for (article in c(
    "quickstart",
    "research-workflow",
    "data-input-and-snapshots",
    "strategy-development",
    "strategy-authoring-tools",
    "indicators",
    "ttr-and-adapter-indicators",
    "custom-indicators",
    "metrics-and-accounting",
    "risk-and-cost",
    "metric-contexts-and-conventions",
    "execution-semantics",
    "experiment-store",
    "sweeps",
    "selection-integrity",
    "walk-forward"
  )) {
    testthat::expect_match(text, sprintf("vignette(\"%s\", package = \"ledgr\")", article), fixed = TRUE)
    testthat::expect_match(text, sprintf("system.file(\"doc\", \"%s.html\", package = \"ledgr\")", article), fixed = TRUE)
  }
  testthat::expect_no_match(text, "ttr-indicators", fixed = TRUE)
  }
  })

  # Also covers: help-page article links target installed vignettes only
  local({
  root <- testthat::test_path("..", "..")
  man_dir <- file.path(root, "man")
  vignettes_dir <- file.path(root, "vignettes")
  source_docs_exist <- dir.exists(man_dir) && dir.exists(vignettes_dir)
  testthat::expect_true(source_docs_exist, info = "help and vignette sources are required in the review lane")
  if (source_docs_exist) {

  man_text <- paste(unlist(lapply(list.files(man_dir, pattern = "[.]Rd$", full.names = TRUE), readLines, warn = FALSE)), collapse = "\n")
  linked <- unique(unlist(regmatches(
    man_text,
    gregexpr('system[.]file\\("doc", "[^"]+[.]html", package = "ledgr"\\)', man_text)
  )))
  linked_articles <- sub('^system[.]file\\("doc", "([^"]+)[.]html", package = "ledgr"\\)$', "\\1", linked)

  installed_articles <- tools::file_path_sans_ext(basename(list.files(vignettes_dir, pattern = "[.](Rmd|qmd)$", full.names = TRUE)))
  testthat::expect_true(all(linked_articles %in% installed_articles))
  testthat::expect_true("indicators" %in% installed_articles)
  testthat::expect_true("ttr-and-adapter-indicators" %in% installed_articles)
  testthat::expect_true("strategy-authoring-tools" %in% installed_articles)
  testthat::expect_true("metric-contexts-and-conventions" %in% installed_articles)
  testthat::expect_true("data-input-and-snapshots" %in% installed_articles)
  testthat::expect_true("quickstart" %in% installed_articles)
  testthat::expect_true("risk-and-cost" %in% installed_articles)
  testthat::expect_false("ttr-indicators" %in% installed_articles)
  testthat::expect_false("who-ledgr-is-for" %in% linked_articles)
  testthat::expect_false("why-r" %in% linked_articles)
  }
  })
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
  testthat::expect_match(doc, "`ledgr_sweep\\(\\)` evaluates a declared grid against a `ledgr_experiment\\(\\)`")
  testthat::expect_match(doc, "Each \\*\\*candidate\\*\\* is one row of that table")
  testthat::expect_match(doc, "Declare Parameterized Features", fixed = TRUE)
  testthat::expect_match(doc, "An \\*\\*active alias\\*\\* is a stable strategy-facing feature name")
  testthat::expect_match(doc, "Feature parameters vary the knobs exposed by a feature constructor", fixed = TRUE)
  testthat::expect_match(doc, "Only knobs declared with `ledgr_param\\(\"name\"\\)` need values in the feature grid")
  testthat::expect_match(doc, "Concrete arguments stay fixed", fixed = TRUE)
  testthat::expect_match(doc, "The strategy function itself does not change across candidates", fixed = TRUE)
  testthat::expect_match(doc, "ledgr calls the same `function\\(ctx, params\\)`")
  testthat::expect_match(doc, "ctx\\$features\\(id\\)")
  testthat::expect_match(doc, "params\\$threshold")
  testthat::expect_match(doc, "The aliases stay stable across candidates", fixed = TRUE)
  testthat::expect_match(doc, "Build The Candidate Grid", fixed = TRUE)
  testthat::expect_match(doc, "\\*\\*Feature parameters\\*\\* materialize indicators before execution")
  testthat::expect_match(doc, "\\*\\*Strategy\\s+parameters\\*\\* are passed to `strategy\\(ctx, params\\)`")
  testthat::expect_match(doc, "Use `ledgr_feature_grid()` for feature knobs", fixed = TRUE)
  testthat::expect_match(doc, "`ledgr_strategy_grid()` for strategy-code knobs", fixed = TRUE)
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
  testthat::expect_match(doc, "vignette\\(\"walk-forward\", package = \"ledgr\"\\)")
  testthat::expect_no_match(doc, "when that layer lands in\\s+v0.1.9.x")
  testthat::expect_no_match(doc, "Design note", fixed = TRUE)
  testthat::expect_no_match(doc, "v0.1.8.6 cycle", fixed = TRUE)
  testthat::expect_no_match(doc, "future sweep-review helper", fixed = TRUE)
  testthat::expect_match(doc, "Try it", fixed = TRUE)
  testthat::expect_match(doc, "This debug example uses no features", fixed = TRUE)
  testthat::expect_match(doc, "```{mermaid}", fixed = TRUE)
  testthat::expect_match(doc, "candidate rows<br/>feature params \\+ strategy params")
  testthat::expect_match(doc, "strategy reads<br/>fast and slow", fixed = TRUE)
  testthat::expect_match(doc, "execution-semantics", fixed = TRUE)
  testthat::expect_match(doc, "candidate summaries", fixed = TRUE)
  testthat::expect_match(doc, "ledgr_sweep_review(reopened_sweep, rank_by = desc(sharpe_ratio), n = 5)", fixed = TRUE)
  testthat::expect_no_match(doc, "glimpse(top_n)", fixed = TRUE)
  testthat::expect_match(doc, "ledgr_tune()", fixed = TRUE)
  testthat::expect_match(doc, "parallel sweep execution", fixed = TRUE)
  testthat::expect_match(doc, "per-fold walk-forward PBO, CPCV, DSR, or benchmark diagnostics", fixed = TRUE)
  testthat::expect_match(doc, "Save And Reopen Sweep Artifacts", fixed = TRUE)
  testthat::expect_no_match(doc, "ledgr_snapshot_split\\(")
  testthat::expect_match(doc, "ledgr_sweep_save(", fixed = TRUE)
  testthat::expect_match(doc, "Cost Models Are Fixed Inputs", fixed = TRUE)
  testthat::expect_match(doc, "does not\\s+compose cost models as another grid dimension")
  testthat::expect_match(doc, "A future `ledgr_cost_grid()`", fixed = TRUE)
  testthat::expect_no_match(doc, "not part of the v1 cost surface", fixed = TRUE)
  testthat::expect_no_match(doc, "v0.1.9.2 store", fixed = TRUE)
  testthat::expect_match(doc, "cost-grid composition such as `ledgr_cost_grid()`", fixed = TRUE)
  testthat::expect_no_match(doc, "public cost-model factories;", fixed = TRUE)

  testthat::expect_match(readme, "I want the full research loop: snapshot, sweep, promotion, reopen.", fixed = TRUE)
  testthat::expect_match(readme, "Research Workflow", fixed = TRUE)
  testthat::expect_match(readme, "exploratory sweeps and candidate promotion", fixed = TRUE)
  testthat::expect_match(readme, "Sweeps", fixed = TRUE)
  testthat::expect_match(readme, "automatic objective-based selection", fixed = TRUE)
  testthat::expect_match(readme, "The current ledgr research API is experiment-first", fixed = TRUE)
  testthat::expect_match(readme, "includes memory-backed\\s+exploratory sweep support")

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
    "## Plot The Promoted Evidence",
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
  testthat::expect_match(doc, "ledgr_run_strategy", fixed = TRUE)
  testthat::expect_match(doc, "ledgr_passed_warmup()", fixed = TRUE)
  testthat::expect_match(doc, "Reopen and recover", fixed = TRUE)
  testthat::expect_match(doc, "selected candidate", fixed = TRUE)
  testthat::expect_match(doc, "strategy parameters", fixed = TRUE)
  testthat::expect_match(doc, "feature parameters", fixed = TRUE)
  testthat::expect_match(doc, "Tier 2\\s+strategies")
  testthat::expect_match(doc, "Promotion records selection; it does not prove generalization.", fixed = TRUE)
  testthat::expect_match(doc, "Naive\\s+sweep-and-pick selection is a selection-bias risk")
  testthat::expect_match(doc, "Walk-forward\\s+evaluation is the shipped next conceptual layer")
  testthat::expect_match(doc, "vignette\\(\"walk-forward\", package = \"ledgr\"\\)")
  testthat::expect_no_match(doc, "the public roadmap places walk-forward evaluation at v0.1.9.x", fixed = TRUE)
  testthat::expect_match(doc, "When you ask \"does this strategy generalize?\"", fixed = TRUE)
  testthat::expect_match(doc, "Try it", fixed = TRUE)
  testthat::expect_match(doc, "```{mermaid}", fixed = TRUE)
  testthat::expect_match(doc, "promotion-review helper", fixed = TRUE)
  testthat::expect_no_match(doc, "future sweep-review helper", fixed = TRUE)
  testthat::expect_no_match(doc, "v0.1.8.6 cycle", fixed = TRUE)
  testthat::expect_no_match(doc, "Design note", fixed = TRUE)
  testthat::expect_match(doc, "This article is evaluated when it is rendered", fixed = TRUE)
  testthat::expect_match(doc, "file.path(tempdir(), \"ledgr_research_workflow.duckdb\")", fixed = TRUE)
  testthat::expect_match(doc, "head(ledgr_results(single_run, what = \"equity\"), 3)", fixed = TRUE)
  testthat::expect_match(doc, "info$promotion_context", fixed = TRUE)
  testthat::expect_match(doc, "About the demo data", fixed = TRUE)
  testthat::expect_match(doc, "::: {.ledgr-callout .ledgr-callout-note}", fixed = TRUE)
  testthat::expect_match(doc, "::: {.ledgr-callout .ledgr-callout-tip}", fixed = TRUE)
  testthat::expect_no_match(doc, "#| eval: false", fixed = TRUE)
  testthat::expect_match(doc, "custom_sma_strategy <- function(ctx, params)", fixed = TRUE)
  testthat::expect_match(doc, "ledgr_sweep_review(sweep, rank_by = desc(sharpe_ratio), n = 5)", fixed = TRUE)
  testthat::expect_no_match(doc, "glimpse(top_n)", fixed = TRUE)
  testthat::expect_match(doc, "review$ranked", fixed = TRUE)
  testthat::expect_no_match(doc, "dplyr::filter", fixed = TRUE)
  testthat::expect_match(doc, "vignette(\"sweeps\", package = \"ledgr\")", fixed = TRUE)
  testthat::expect_no_match(doc, "not evaluated during\\s+package vignette builds")
})


testthat::test_that("facts inspection and preparation contracts are locked", {
  root <- testthat::test_path("..", "..")
  contract_path <- file.path(root, "inst", "design", "contracts.md")
  testthat::skip_if_not(file.exists(contract_path), "design contracts unavailable")
  contract <- paste(readLines(contract_path, warn = FALSE), collapse = "\n")
  news <- paste(readLines(file.path(root, "NEWS.md"), warn = FALSE), collapse = "\n")
  description <- read.dcf(file.path(root, "DESCRIPTION"))
  namespace <- paste(readLines(file.path(root, "NAMESPACE"), warn = FALSE), collapse = "\n")
  condition_doc <- paste(
    readLines(file.path(root, "man", "ledgr_condition_classes.Rd"), warn = FALSE),
    collapse = "\n"
  )

  testthat::expect_match(
    contract,
    "Local session wall times must resolve to exactly one UTC instant",
    fixed = TRUE
  )
  testthat::expect_match(
    contract,
    "Ambiguous[[:space:]]+fall-back and nonexistent spring-forward labels fail closed"
  )
  testthat::expect_match(contract, "accepts either row-per-member evidence", fixed = TRUE)
  testthat::expect_match(contract, "Both shapes normalize to the same set", fixed = TRUE)
  testthat::expect_match(contract, "`ledgr_facts_history()` is a retrospective audit", fixed = TRUE)
  testthat::expect_match(
    contract,
    "`ledgr_facts_resolve()` is a separate decision-cutoff",
    fixed = TRUE
  )
  testthat::expect_match(contract, "true, false, and unknown states", fixed = TRUE)
  testthat::expect_match(contract, "Complete-set omission cites the set header", fixed = TRUE)
  testthat::expect_match(contract, "Neither result is a strategy context", fixed = TRUE)
  testthat::expect_match(contract, "Default fact-inspection prints are curated", fixed = TRUE)
  testthat::expect_match(contract, "session fields plus reason and a knowledge time", fixed = TRUE)
  testthat::expect_match(
    contract,
    "disclosed as coming from `$evidence`, not as a value stored in `$rows`",
    fixed = TRUE
  )
  testthat::expect_match(contract, "names omitted[[:space:]]+stored columns")
  testthat::expect_match(contract, "optional preparation adapter over an", fixed = TRUE)
  testthat::expect_match(contract, "no generation time or external pointer", fixed = TRUE)
  testthat::expect_match(contract, "assumption_reasons", fixed = TRUE)
  testthat::expect_match(news, "Added read-only fact history and cutoff resolution", fixed = TRUE)
  testthat::expect_match(news, "Added constituent-list membership input", fixed = TRUE)
  testthat::expect_match(news, "rejects ambiguous fall-back and nonexistent", fixed = TRUE)
  testthat::expect_match(news, "Curated fact-history and resolution printing", fixed = TRUE)

  suggests <- trimws(unlist(strsplit(description[, "Suggests"], "[,\n]")))
  testthat::expect_true("qlcal" %in% suggests)
  testthat::expect_no_match(namespace, "importFrom\\(qlcal")
  r_files <- list.files(file.path(root, "R"), pattern = "\\.R$", full.names = TRUE)
  qlcal_users <- basename(r_files[vapply(r_files, function(path) {
    any(grepl("qlcal::", readLines(path, warn = FALSE), fixed = TRUE))
  }, logical(1))])
  testthat::expect_identical(qlcal_users, "availability-facts.R")
  for (class in c(
    "ledgr_session_time_ambiguous", "ledgr_session_time_nonexistent",
    "ledgr_fact_ambiguous_membership_shape", "ledgr_fact_invalid_membership_list",
    "ledgr_facts_inspection_invalid_args", "ledgr_facts_scope_not_found",
    "ledgr_facts_snapshot_not_sealed", "ledgr_facts_snapshot_hash_mismatch",
    "ledgr_session_adapter_invalid", "ledgr_session_override_invalid"
  )) {
    testthat::expect_match(condition_doc, paste0("\\alias{", class, "}"), fixed = TRUE)
    testthat::expect_match(condition_doc, paste0("\\code{", class, "}"), fixed = TRUE)
  }
})

testthat::test_that("availability economics and controlled-stop contracts are locked", {
  root <- testthat::test_path("..", "..")
  path <- file.path(root, "inst", "design", "contracts.md")
  testthat::skip_if_not(file.exists(path), "design contracts unavailable")
  contract <- paste(readLines(path, warn = FALSE), collapse = "\n")
  news <- paste(readLines(file.path(root, "NEWS.md"), warn = FALSE), collapse = "\n")
  condition_doc <- paste(
    readLines(file.path(root, "man", "ledgr_condition_classes.Rd"), warn = FALSE),
    collapse = "\n"
  )

  testthat::expect_match(contract, "Unrestricted held nonmembers may also reduce", fixed = TRUE)
  testthat::expect_match(contract, "New or enlarged short exposure fails before", fixed = TRUE)
  testthat::expect_match(contract, "reserve their absolute marked exposure", fixed = TRUE)
  testthat::expect_match(contract, "Stale marks never become observed", fixed = TRUE)
  testthat::expect_match(contract, "decisions occur at declared session closes", fixed = TRUE)
  testthat::expect_match(
    contract,
    paste0(
      "resolves execution-time facts and records accepted[[:space:]]+",
      "fills and events at the next declared session opening"
    )
  )
  testthat::expect_match(contract, "Membership remains", fixed = TRUE)
  testthat::expect_match(contract, "terminal decision has no execution opportunity", fixed = TRUE)
  testthat::expect_match(
    contract,
    "Dense execution declares no independent opening clock and is unchanged.",
    fixed = TRUE
  )
  testthat::expect_match(contract, "Rejected sales fund nothing", fixed = TRUE)
  testthat::expect_match(contract, "Experiment-store schema 114", fixed = TRUE)
  testthat::expect_match(contract, "finalize as `INCOMPLETE`", fixed = TRUE)
  testthat::expect_match(contract, "record error diagnostics only after that rollback", fixed = TRUE)
  testthat::expect_match(contract, "resumed invocations append rather than replace", fixed = TRUE)
  testthat::expect_match(contract, "Experiment-store schema 115", fixed = TRUE)
  testthat::expect_match(contract, "Repeating an achieved `INCOMPLETE` run ID", fixed = TRUE)
  testthat::expect_match(contract, "exact stored equity timestamp prefix", fixed = TRUE)
  testthat::expect_match(contract, "recorded stop", fixed = TRUE)
  testthat::expect_match(contract, "performs finalization only", fixed = TRUE)
  testthat::expect_match(contract, "`ledgr_run_terminal_evidence_invalid`", fixed = TRUE)
  testthat::expect_match(contract, "prefixes may remain visible as explicitly incomplete evidence", fixed = TRUE)
  testthat::expect_match(contract, "`ledgr_incomplete_sweep_candidate`", fixed = TRUE)
  testthat::expect_match(contract, "`ledgr_promote_incomplete_candidate`", fixed = TRUE)
  testthat::expect_match(contract, "marks the fold and session `PARTIAL`", fixed = TRUE)
  testthat::expect_match(contract, "`ledgr_run_explain(bt, instrument_id, ts_utc)`", fixed = TRUE)
  testthat::expect_match(contract, "same `tibble::as_tibble()` result-table path", fixed = TRUE)
  testthat::expect_match(contract, "`ledgr_run_explanation_unavailable`", fixed = TRUE)
  testthat::expect_match(contract, "Those values are explain-time defaults, not durable", fixed = TRUE)
  testthat::expect_match(contract, "and are never persisted", fixed = TRUE)
  testthat::expect_match(
    contract,
    "`ledgr_run_info()` and `summary()` project existing terminal completion",
    fixed = TRUE
  )
  testthat::expect_match(
    contract,
    "Dense and historical runs without that evidence[[:space:]]+report it as unknown"
  )
  testthat::expect_match(
    contract,
    "`ledgr_run_list()` appends the recorded completion projection",
    fixed = TRUE
  )
  testthat::expect_match(contract, "Status does not gate real completion evidence", fixed = TRUE)
  testthat::expect_match(contract, "known-empty", fixed = TRUE)
  testthat::expect_match(contract, "achieved-prefix evidence only", fixed = TRUE)
  testthat::expect_match(
    contract,
    "follows recorded completion evidence rather than[[:space:]]+run status"
  )
  testthat::expect_match(
    contract,
    "annualized return, annualized volatility, and[[:space:]]+Sharpe ratio are withheld"
  )
  testthat::expect_match(
    contract,
    "status and any recorded completion evidence[[:space:]]+before identity and telemetry"
  )
  testthat::expect_match(contract, "labels `n_trades` as `Closed Trades`", fixed = TRUE)
  testthat::expect_match(
    contract,
    "With explicit `run_ids`, `ledgr_run_compare()` rejects every non-`DONE` run",
    fixed = TRUE
  )
  testthat::expect_match(contract, "Without `run_ids`, it silently excludes", fixed = TRUE)
  testthat::expect_match(contract, "changes the meaning of return, Sharpe", fixed = TRUE)
  explain_help <- paste(
    readLines(file.path(root, "man", "ledgr_run_explain.Rd"), warn = FALSE),
    collapse = "\n"
  )
  explain_fields <- c(
    "run_id", "ts_utc", "instrument_id", "member", "held",
    "target_restricted", "target_restriction_reason",
    "target_restriction_reasons", "feature_identity_json", "quantity",
    "target_before_risk", "target_after_risk", "execution_outcome",
    "execution_reason", "execution_reasons", "resulting_position",
    "mark_source", "mark_age", "completion_status", "complete_performance"
  )
  for (field in explain_fields) {
    testthat::expect_match(explain_help, paste0("\\code{", field, "}"), fixed = TRUE)
  }
  testthat::expect_match(explain_help, "\\code{\"no_action\"}", fixed = TRUE)
  testthat::expect_match(explain_help, "\\code{\"no_target_change\"}", fixed = TRUE)
  testthat::expect_match(explain_help, "explain-time values, not durable", fixed = TRUE)
  testthat::expect_match(news, "`ledgr_run_terminal_evidence_invalid`", fixed = TRUE)
  testthat::expect_match(news, "`ledgr_incomplete_sweep_candidate`", fixed = TRUE)
  testthat::expect_match(news, "`ledgr_promote_incomplete_candidate`", fixed = TRUE)
  testthat::expect_match(news, "`ledgr_run_explanation_unavailable`", fixed = TRUE)
  testthat::expect_match(news, "`ledgr_run_list()` now appends recorded completion", fixed = TRUE)
  testthat::expect_match(news, "Backtest summaries now follow recorded completion", fixed = TRUE)
  testthat::expect_match(news, "Run-info printing presents completion", fixed = TRUE)
  testthat::expect_match(news, "label `n_trades` as `Closed Trades`", fixed = TRUE)
  summary_help <- paste(
    readLines(file.path(root, "man", "summary.ledgr_backtest.Rd"), warn = FALSE),
    collapse = "\n"
  )
  testthat::expect_match(summary_help, "\\item Closed Trades:", fixed = TRUE)
  testthat::expect_match(
    summary_help,
    "annualized return, annualized volatility, and Sharpe ratio",
    fixed = TRUE
  )
  testthat::expect_match(news, "explicitly named non-`DONE` runs", fixed = TRUE)
  testthat::expect_match(
    news,
    "`ledgr_run_info\\(\\)` and `summary\\(\\)`[[:space:]]+now expose recorded completion bounds"
  )
  reason_codes <- c(
    "decision_recorded", "empty_public_domain", "trading_halted",
    "quotation_only", "status_unknown", "status_unknown_or_conflicting",
    "lifetime_inactive", "stale_mark_reduction", "stale_mark_pass_through",
    "restricted_target", "nonmember_exposure_increase",
    "post_risk_inadmissible", "short_exposure_unsupported",
    "insufficient_cash", "execution_bar_missing",
    "membership_changed_before_execution", "final_pulse_no_execution",
    "affordability_reconciled", "valuation_horizon_exhausted",
    "terminal_settlement_unsupported", "risk_mark_unavailable",
    "affordability_reconciliation_failed", "fold_exception"
  )
  for (code in reason_codes) {
    testthat::expect_match(contract, paste0("`", code, "`"), fixed = TRUE)
    testthat::expect_match(condition_doc, paste0("\\code{", code, "}"), fixed = TRUE)
  }
  testthat::expect_match(news, "`status_halted` to `trading_halted`", fixed = TRUE)
  testthat::expect_match(news, "`status_quotation_only` to `quotation_only`", fixed = TRUE)
})









testthat::test_that("research documentation exposes the disclaimer without broker overclaiming", {
  local({
  root <- testthat::test_path("..", "..")
  source_disclaimer_path <- file.path(root, "DISCLAIMER.md")
  installed_disclaimer_path <- file.path(root, "inst", "DISCLAIMER.md")
  workflow_candidates <- file.path(
    root,
    "vignettes",
    c("research-workflow.qmd", "research-workflow.Rmd")
  )
  workflow_paths <- workflow_candidates[file.exists(workflow_candidates)]
  workflow_path <- if (length(workflow_paths) > 0L) workflow_paths[[1L]] else NA_character_
  pkgdown_audience_path <- file.path(root, "vignettes", "articles", "who-ledgr-is-for.qmd")
  disclaimer_sources_exist <- all(
    file.exists(c(
      source_disclaimer_path, installed_disclaimer_path,
      workflow_path, pkgdown_audience_path
    ))
  )
  testthat::expect_true(
    disclaimer_sources_exist,
    info = "disclaimer sources are required in the review lane"
  )
  if (disclaimer_sources_exist) {

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
  }
  })

  # Also covers: research-to-production docs do not overclaim broker reconciliation
  local({
  root <- testthat::test_path("..", "..")
  qmd_candidates <- file.path(
    root,
    "vignettes",
    c("research-to-production.qmd", "research-to-production.Rmd")
  )
  qmd_paths <- qmd_candidates[file.exists(qmd_candidates)]
  qmd_exists <- length(qmd_paths) > 0L
  testthat::expect_true(qmd_exists, info = "research-to-production source is required in the review lane")
  if (qmd_exists) {
  doc <- paste(readLines(qmd_paths[[1L]], warn = FALSE), collapse = "\n")

  testthat::expect_no_match(doc, "No reconciliation step is needed", fixed = TRUE)
  testthat::expect_no_match(doc, "The ledger is the state", fixed = TRUE)
  testthat::expect_match(doc, "The ledger reconstructs ledgr's expected state", fixed = TRUE)
  testthat::expect_match(doc, "reconciled against broker-reported", fixed = TRUE)
  testthat::expect_match(doc, "Design Philosophy: From Research to Production", fixed = TRUE)
  testthat::expect_match(doc, "What v0.1.x Delivers Today", fixed = TRUE)
  }
  })
})

testthat::test_that("condition help exposes stable classes and final-bar behavior", {
  local({
  root <- testthat::test_path("..", "..")
  condition_path <- file.path(root, "man", "ledgr_condition_classes.Rd")
  condition_help_exists <- file.exists(condition_path)
  testthat::expect_true(condition_help_exists, info = "condition help source is required in the review lane")
  if (condition_help_exists) {
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
    "ledgr_unresolved_feature_id",
    "ledgr_metric_context_cadence_mismatch"
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
  }
  })

  # Also covers: LEDGR_LAST_BAR_NO_FILL help topic documents final-bar behavior
  local({
  root <- testthat::test_path("..", "..")
  warning_path <- file.path(root, "man", "LEDGR_LAST_BAR_NO_FILL.Rd")
  execution_candidates <- file.path(
    root,
    "vignettes",
    c("execution-semantics.qmd", "execution-semantics.Rmd")
  )
  execution_paths <- execution_candidates[file.exists(execution_candidates)]
  execution_path <- if (length(execution_paths) > 0L) execution_paths[[1L]] else NA_character_
  final_bar_sources_exist <- file.exists(warning_path) && file.exists(execution_path)
  testthat::expect_true(
    final_bar_sources_exist,
    info = "final-bar help and execution sources are required in the review lane"
  )
  if (final_bar_sources_exist) {

  warning_doc <- paste(readLines(warning_path, warn = FALSE), collapse = "\n")
  execution_doc <- paste(readLines(execution_path, warn = FALSE), collapse = "\n")

  testthat::expect_match(warning_doc, "\\alias{LEDGR_LAST_BAR_NO_FILL}", fixed = TRUE)
  testthat::expect_match(warning_doc, "No fill is emitted", fixed = TRUE)
  testthat::expect_match(warning_doc, "ledger is left", fixed = TRUE)
  testthat::expect_match(warning_doc, "candidate-row warning", fixed = TRUE)
  testthat::expect_match(warning_doc, "execution-semantics", fixed = TRUE)
  testthat::expect_match(execution_doc, "?LEDGR_LAST_BAR_NO_FILL", fixed = TRUE)
  testthat::expect_no_match(execution_doc, "v0.1.9.1 ships the public transaction-cost model API", fixed = TRUE)
  testthat::expect_no_match(execution_doc, "The stable public transaction-cost model API is planned", fixed = TRUE)
  }
  })
})




testthat::test_that("walk-forward docs state MVP workflow and caveats", {
  qmd_path <- ledgr_test_source_vignette("walk-forward.qmd")
  md_path <- file.path(testthat::test_path("..", ".."), "vignettes", "walk-forward.md")
  news_path <- file.path(testthat::test_path("..", ".."), "NEWS.md")
  testthat::skip_if_not(file.exists(qmd_path) && file.exists(md_path) && file.exists(news_path), "walk-forward docs not available")

  docs <- vapply(
    c(qmd = qmd_path, md = md_path),
    function(path) paste(readLines(path, warn = FALSE), collapse = "\n"),
    character(1)
  )
  news <- paste(readLines(news_path, warn = FALSE), collapse = "\n")

  for (doc in docs) {
    testthat::expect_match(doc, "train snapshot window -> sweep candidates -> scalar selection", fixed = TRUE)
    testthat::expect_match(doc, "ledgr_folds_rolling", fixed = TRUE)
    testthat::expect_match(doc, "ledgr_candidate", fixed = TRUE)
    testthat::expect_no_match(doc, "Design-only Workflow Sketch", fixed = TRUE)
    testthat::expect_match(doc, "Walk-forward evidence is only as survivorship-safe as the sealed\\s+snapshot and\\s+universe semantics it evaluates\\.")
    testthat::expect_match(doc, "Reproducibility and selection integrity are orthogonal.", fixed = TRUE)
    testthat::expect_match(doc, "not PBO", fixed = TRUE)
    testthat::expect_match(
      doc,
      "not independent\\s+(?:>\\s*)?observations",
      perl = TRUE
    )
    testthat::expect_match(doc, "Anchored folds grow their train window over time.", fixed = TRUE)
  }

  testthat::expect_match(news, "# ledgr 0.1.9.4", fixed = TRUE)
  testthat::expect_match(news, "train-vs-test degradation table", fixed = TRUE)
  testthat::expect_match(news, "does not add PBO", fixed = TRUE)
})


testthat::test_that("new teaching surfaces state current public boundaries", {
  quickstart_qmd <- ledgr_test_source_vignette("quickstart.qmd")
  quickstart_md <- file.path(testthat::test_path("..", ".."), "vignettes", "quickstart.md")
  risk_qmd <- ledgr_test_source_vignette("risk-and-cost.qmd")
  risk_md <- file.path(testthat::test_path("..", ".."), "vignettes", "risk-and-cost.md")
  testthat::skip_if_not(
    all(file.exists(c(quickstart_qmd, quickstart_md, risk_qmd, risk_md))),
    "Batch 8 teaching docs not available"
  )

  quickstart_docs <- vapply(
    c(qmd = quickstart_qmd, md = quickstart_md),
    function(path) paste(readLines(path, warn = FALSE), collapse = "\n"),
    character(1)
  )
  risk_docs <- vapply(
    c(qmd = risk_qmd, md = risk_md),
    function(path) paste(readLines(path, warn = FALSE), collapse = "\n"),
    character(1)
  )

  for (doc in quickstart_docs) {
    testthat::expect_match(doc, "shortest useful path from\\s+demo data to inspectable evidence")
    testthat::expect_match(doc, "cost_model = ledgr_cost_zero", fixed = TRUE)
    testthat::expect_match(doc, "ledgr_sweep", fixed = TRUE)
    testthat::expect_match(doc, "ledgr_candidate", fixed = TRUE)
    testthat::expect_match(doc, "not a\\s+validation protocol")
  }

  for (doc in risk_docs) {
    # Mental model: four questions, the layer order, and the policy adjectives.
    testthat::expect_match(doc, "what do I want to hold?", fixed = TRUE)
    testthat::expect_match(doc, "next-open timing", fixed = TRUE)
    testthat::expect_match(doc, "identity-bearing", fixed = TRUE)
    # Composable menu: step names must stay in sync with the exported surface.
    testthat::expect_match(doc, "ledgr_cost_spread_bps", fixed = TRUE)
    testthat::expect_match(doc, "ledgr_cost_fixed_fee", fixed = TRUE)
    testthat::expect_match(doc, "ledgr_cost_notional_bps_fee", fixed = TRUE)
    testthat::expect_match(doc, "ledgr_risk_long_only", fixed = TRUE)
    testthat::expect_match(doc, "ledgr_risk_max_weight", fixed = TRUE)
    testthat::expect_match(doc, "ledgr_risk_none", fixed = TRUE)
    # Cost stage-ordering rule.
    testthat::expect_match(doc, "price transforms", fixed = TRUE)
    testthat::expect_match(doc, "before fee steps", fixed = TRUE)
    # Boundaries.
    testthat::expect_match(doc, "not portfolio optimization", fixed = TRUE)
    testthat::expect_match(doc, "not liquidity or capacity", fixed = TRUE)
    testthat::expect_match(doc, "not a broker", fixed = TRUE)
    # Roadmap boundary for the future steps.
    testthat::expect_match(doc, "More steps are planned", fixed = TRUE)
    testthat::expect_no_match(doc, "production deployment", fixed = TRUE)
  }
})




testthat::test_that("v0.2.0.0 records the pre-edit wide-projection inventory", {
  root <- testthat::test_path("..", "..")
  inventory_path <- file.path(
    root,
    "inst", "design", "ledgr_v0_2_0_0_spec_packet",
    "wide_projection_store_inventory.md"
  )
  testthat::skip_if_not(
    file.exists(inventory_path),
    "source store inventory unavailable during installed-package tests"
  )
  inventory <- paste(readLines(inventory_path, warn = FALSE), collapse = "\n")

  testthat::expect_match(inventory, "recorded before the first LDG-2684", fixed = TRUE)
  testthat::expect_match(inventory, "No tracked database file exists", fixed = TRUE)
  testthat::expect_match(inventory, "No named maintainer-owned store", fixed = TRUE)
  testthat::expect_match(inventory, "None contains a saved-sweep table", fixed = TRUE)
  testthat::expect_match(inventory, "in-memory read-time projection", fixed = TRUE)
  testthat::expect_match(inventory, "No migration is promised for an unnamed artifact", fixed = TRUE)
})

testthat::test_that("v0.2.0 workflow teaching includes the survivorship journey", {
  local({
  root <- testthat::test_path("..", "..")
  paths <- file.path(
    root,
    c(
      "inst/design/contracts.md",
      "README.Rmd",
      "README.md",
      "vignettes/strategy-authoring-tools.qmd",
      "vignettes/strategy-authoring-tools.md",
      "R/run-store.R",
      "NAMESPACE"
    )
  )
  workflow_sources_exist <- all(file.exists(paths))
  testthat::expect_true(
    workflow_sources_exist,
    info = "workflow documentation sources are required in the review lane"
  )
  if (workflow_sources_exist) {
  docs <- lapply(paths, function(path) paste(readLines(path, warn = FALSE), collapse = "\n"))
  names(docs) <- c(
    "contracts", "readme_rmd", "readme", "strategy_qmd",
    "strategy", "run_store", "namespace"
  )

  testthat::expect_match(
    docs$contracts,
    "A durable `ledgr_backtest` handle is a locator",
    fixed = TRUE
  )
  testthat::expect_match(
    docs$contracts,
    "Historical configs without that field return\\s+`NA_character_`"
  )
  testthat::expect_match(
    docs$contracts,
    paste0(
      "must not infer a no-op plan, substitute current\\s+",
      "experiment state, add a top-level `risk_plan_json` field"
    )
  )
  testthat::expect_match(
    docs$contracts,
    "`target[[instrument_id]]` extracts one named quantity",
    fixed = TRUE
  )
  testthat::expect_match(
    docs$run_store,
    "`strategy_params_hash`, `feature_set_hash`, `risk_chain_hash`, `config_hash`",
    fixed = TRUE
  )
  testthat::expect_match(
    docs$readme_rmd,
    "review <- ledgr_sweep_review(sweep, rank_by = -final_equity, n = 2L)",
    fixed = TRUE
  )
  testthat::expect_match(
    docs$readme_rmd,
    "candidate <- ledgr_candidate(review$ranked, 1L)",
    fixed = TRUE
  )
  testthat::expect_match(
    docs$readme_rmd,
    "snapshot <- ledgr_snapshot_open(store_path, snapshot_id, verify = TRUE)",
    fixed = TRUE
  )
  testthat::expect_match(
    docs$readme,
    "candidate <- ledgr_candidate(review$ranked, 1L)",
    fixed = TRUE
  )
  testthat::expect_match(
    docs$strategy_qmd,
    "target_values <- c(target)\ntarget_values",
    fixed = TRUE
  )
  testthat::expect_match(
    docs$strategy,
    "target_values <- c(target)\ntarget_values\n#> DEMO_01 DEMO_02",
    fixed = TRUE
  )
  testthat::expect_match(
    docs$strategy_qmd,
    "c(pre_floor = raw_qty, target_qty = target[[\"DEMO_01\"]])",
    fixed = TRUE
  )
  testthat::expect_no_match(
    paste(docs$readme_rmd, docs$readme, docs$strategy_qmd, docs$strategy, sep = "\n"),
    "unclass(target)",
    fixed = TRUE
  )
  testthat::expect_no_match(
    paste(docs$run_store, docs$namespace, sep = "\n"),
    "ledgr_target_values",
    fixed = TRUE
  )
  }
  })

  # Also covers: survivorship article executes the public availability journey
  local({
  root <- testthat::test_path("..", "..")
  qmd_path <- file.path(root, "vignettes", "survivorship-bias.qmd")
  md_path <- file.path(root, "vignettes", "survivorship-bias.md")
  survivorship_sources_exist <- file.exists(qmd_path) && file.exists(md_path)
  testthat::expect_true(
    survivorship_sources_exist,
    info = "survivorship article sources are required in the review lane"
  )
  if (survivorship_sources_exist) {
  testthat::expect_true(file.exists(qmd_path))
  testthat::expect_true(file.exists(md_path))

  qmd_lines <- readLines(qmd_path, warn = FALSE)
  qmd <- paste(qmd_lines, collapse = "\n")
  md <- paste(readLines(md_path, warn = FALSE), collapse = "\n")
  public_calls <- c(
    "ledgr_facts_sessions", "ledgr_facts_membership_snapshots",
    "ledgr_facts_validate", "ledgr_facts_history", "ledgr_facts_resolve",
    "ledgr_snapshot_from_df", "ledgr_experiment_plan", "ledgr_run",
    "ledgr_results", "ledgr_run_explain", "ledgr_run_info", "ledgr_run_list",
    "ledgr_snapshot_open", "ledgr_run_open"
  )
  for (call in public_calls) {
    testthat::expect_match(qmd, call, fixed = TRUE)
  }

  testthat::expect_no_match(qmd, "#\\| eval: false")
  testthat::expect_no_match(qmd, "ledgr:::", fixed = TRUE)
  testthat::expect_no_match(qmd, "DBI::", fixed = TRUE)
  testthat::expect_no_match(qmd, "availability_provider", fixed = TRUE)
  testthat::expect_match(qmd, "invalid_observations = \"quarantine\"", fixed = TRUE)
  testthat::expect_match(qmd, "Survivorship Bias in Performance Studies", fixed = TRUE)
  testthat::expect_match(qmd, "The Delisting Bias in CRSP Data", fixed = TRUE)
  testthat::expect_match(qmd, "::: {.ledgr-callout .ledgr-callout-tip}", fixed = TRUE)
  testthat::expect_match(qmd, "Try it: move the valuation boundary", fixed = TRUE)
  testthat::expect_match(
    qmd,
    "Rebuild `point_in_time_experiment` with `ledgr_valuation_stale(max_sessions = 1)`",
    fixed = TRUE
  )
  testthat::expect_no_match(qmd, "max_sessions = 1` in `declare()`", fixed = TRUE)
  testthat::expect_match(
    qmd,
    "Rerun the survivor experiment with `params = list(invested = 1)`",
    fixed = TRUE
  )
  testthat::expect_no_match(
    qmd,
    "Rerun `point_in_time` with `params = list(invested = 1)`",
    fixed = TRUE
  )
  resolve_line <- grep("#| label: knowledge-resolve", qmd_lines, fixed = TRUE)[[1L]]
  history_line <- grep("#| label: knowledge-history", qmd_lines, fixed = TRUE)[[1L]]
  testthat::expect_lt(resolve_line, history_line)
  direct_resolution <- paste(
    qmd_lines[resolve_line:(history_line - 1L)],
    collapse = "\n"
  )
  testthat::expect_match(direct_resolution, "ledgr_facts_resolve(", fixed = TRUE)
  testthat::expect_match(direct_resolution, 'instruments = c("AAA", "BBB")', fixed = TRUE)
  testthat::expect_no_match(qmd, "The one answer that is always wrong", fixed = TRUE)
  testthat::expect_match(qmd, "receipt, not historical publication", fixed = TRUE)

  knowledge_start <- grep("^#\\| label: knowledge-history$", qmd_lines)[[1L]]
  compare_heading <- grep("^## Comparing Survivor and Point-in-Time Universes$",
                          qmd_lines)
  testthat::expect_length(compare_heading, 1L)
  knowledge_end <- compare_heading[[1L]] - 1L
  knowledge_section <- paste(qmd_lines[knowledge_start:knowledge_end], collapse = "\n")
  testthat::expect_match(knowledge_section, "ledgr_facts_history(", fixed = TRUE)
  testthat::expect_match(knowledge_section, "ledgr_facts_resolve(", fixed = TRUE)
  testthat::expect_no_match(knowledge_section, "ledgr_opening(", fixed = TRUE)
  testthat::expect_no_match(knowledge_section, "ledgr_run(", fixed = TRUE)
  testthat::expect_match(knowledge_section, "article-specific sensitivity analysis", fixed = TRUE)
  testthat::expect_match(knowledge_section, "#| code-fold: true", fixed = TRUE)

  experiment_line <- grep(
    "point_in_time_experiment <- ledgr_experiment(", qmd_lines, fixed = TRUE
  )[[1L]]
  wrapper_line <- grep("declare <- function(universe)", qmd_lines, fixed = TRUE)[[1L]]
  testthat::expect_lt(experiment_line, wrapper_line)
  testthat::expect_match(
    qmd,
    "group_by(recording_pulse_ts_utc)",
    fixed = TRUE
  )
  testthat::expect_match(
    qmd,
    'by = c("ts_utc" = "recording_pulse_ts_utc")',
    fixed = TRUE
  )
  testthat::expect_match(qmd, "run_inventory <- ledgr_run_list(snapshot)", fixed = TRUE)
  testthat::expect_match(qmd, "bars_input <- bars_from(prices)", fixed = TRUE)
  testthat::expect_match(md, "bars_input <- bars_from(prices)", fixed = TRUE)
  testthat::expect_no_match(
    qmd,
    "#\\| label: bars-input[[:space:]]+#\\| include: false"
  )
  testthat::expect_no_match(qmd, "26.1-point gap", fixed = TRUE)
  testthat::expect_no_match(md, "26.1-point gap", fixed = TRUE)
  for (forbidden in c(
    "inspect_session <-", "return_at <-", "common_window <-", "run_horizons <-",
    "last_common <-"
  )) {
    testthat::expect_no_match(qmd, forbidden, fixed = TRUE)
  }
  for (field in c(
    "requested_start_utc", "requested_end_utc", "achieved_start_utc",
    "achieved_end_utc", "stop_reason", "last_fully_valued_ts_utc",
    "last_executed_ts_utc", "complete_performance",
    "affected_instrument_ids"
  )) {
    testthat::expect_match(qmd, field, fixed = TRUE)
  }

  rendered_evidence <- c(
    "execution_bar_missing", "no_target_change", "stale_close",
    "valuation_horizon_exhausted", "INCOMPLETE", "#> [1] TRUE"
  )
  for (evidence in rendered_evidence) {
    testthat::expect_match(md, evidence, fixed = TRUE)
  }
  testthat::expect_match(md, "AAA\\s+FALSE\\s+omitted_from_complete_set")
  testthat::expect_match(md, "BBB\\s+TRUE\\s+member_asserted")
  testthat::expect_match(md, "2020-01-09\\s+NA\\s+NA")
  testthat::expect_match(md, "2020-01-09\\s+open\\s+14:30:00")
  testthat::expect_match(md, "2020-01-11\\s+closed\\s+<NA>")
  testthat::expect_match(md, "known early, not effective.+TRUE")
  testthat::expect_match(md, "effective and knowable.+FALSE")
  testthat::expect_match(md, "effective, not knowable.+TRUE")
  testthat::expect_match(md, "effective and now knowable.+FALSE")
  testthat::expect_match(
    md,
    "2020-01-07 14:30:00\\s+2020-01-07 21:00:00"
  )
  testthat::expect_match(md, "survivor-universe[^\\n]+DONE[^\\n]+TRUE")
  testthat::expect_match(md, "pit-universe[^\\n]+INCOMPLETE[^\\n]+FALSE")
  testthat::expect_match(md, "Completion Evidence:", fixed = TRUE)
  completion_blocks <- gregexpr("Completion Evidence:", md, fixed = TRUE)[[1L]]
  testthat::expect_identical(sum(completion_blocks > 0L), 1L)
  point_in_time_summaries <- gregexpr("summary(point_in_time)", qmd, fixed = TRUE)[[1L]]
  testthat::expect_identical(sum(point_in_time_summaries > 0L), 1L)
  testthat::expect_match(md, "Achieved-Prefix Metrics (", fixed = TRUE)
  testthat::expect_match(md, "Total Return (prefix):", fixed = TRUE)
  testthat::expect_match(md, "Max Drawdown (prefix):", fixed = TRUE)
  testthat::expect_match(
    md,
    "Annualized Return:        withheld (achieved window is shorter than requested)",
    fixed = TRUE
  )
  testthat::expect_match(md, "Closed Trades:", fixed = TRUE)
  testthat::expect_match(md, "Affected IDs:      AAA", fixed = TRUE)
  reopen_true <- gregexpr("#> [1] TRUE", md, fixed = TRUE)[[1L]]
  testthat::expect_gte(sum(reopen_true > 0L), 2L)
  testthat::expect_match(md, "ledgr_availability_validation_failed", fixed = TRUE)
  # Rendered Markdown rewraps prose, so every space must tolerate a line break.
  testthat::expect_match(
    md,
    "Inspect\\s+the\\s+prefix,\\s+correct\\s+evidence\\s+or\\s+policy"
  )
  }
  })
})
