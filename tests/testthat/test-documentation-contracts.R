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
  testthat::expect_match(strategy_doc, "The ledgr strategy has no object from which it can accidentally read tomorrow's\\s+close.")
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

  testthat::expect_match(summary_help, "total return", fixed = TRUE)
  testthat::expect_match(summary_help, "annualized volatility", fixed = TRUE)
  testthat::expect_match(summary_help, "time in market", fixed = TRUE)
  testthat::expect_match(summary_help, "closed trade rows", fixed = TRUE)
  testthat::expect_match(summary_help, "Warmup Diagnostics", fixed = TRUE)
  testthat::expect_match(summary_help, "metrics-and-accounting.html", fixed = TRUE)

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
    ledgr_experiment = c("strategy-development", "experiment-store"),
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
    passed_warmup = c("strategy-development", "indicators")
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
