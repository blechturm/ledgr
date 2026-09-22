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

testthat::test_that("current documentation artifacts, links, and optional boundaries are sound", {
  root <- testthat::test_path("..", "..")
  required_paths <- file.path(
    root,
    c(
      "_pkgdown.yml", "README.Rmd", "README.md", "man", "vignettes",
      "inst/design/ledgr_v0_1_7_7_spec_packet/ledgr.svg",
      "man/figures/logo.svg"
    )
  )
  required_exist <- file.exists(required_paths) | dir.exists(required_paths)
  testthat::expect_true(
    all(required_exist),
    info = paste("missing current documentation artifact:", required_paths[!required_exist])
  )

  if (all(required_exist)) {
    package_logo <- file.path(root, "man", "figures", "logo.svg")
    testthat::expect_lt(file.info(package_logo)$size, 500 * 1024)

    man_paths <- list.files(
      file.path(root, "man"),
      pattern = "[.]Rd$",
      full.names = TRUE
    )
    source_paths <- list.files(
      file.path(root, "vignettes"),
      pattern = "[.](Rmd|qmd)$",
      full.names = TRUE
    )
    rendered_paths <- list.files(
      file.path(root, "vignettes"),
      pattern = "[.]md$",
      full.names = TRUE
    )
    testthat::expect_gt(length(man_paths), 0L)
    testthat::expect_gt(length(source_paths), 0L)
    testthat::expect_gt(length(rendered_paths), 0L)

    man_text <- paste(
      unlist(lapply(man_paths, readLines, warn = FALSE)),
      collapse = "\n"
    )
    linked <- unique(unlist(regmatches(
      man_text,
      gregexpr(
        'system[.]file\\("doc", "[^"]+[.]html", package = "ledgr"\\)',
        man_text
      )
    )))
    linked_articles <- sub(
      '^system[.]file\\("doc", "([^"]+)[.]html", package = "ledgr"\\)$',
      "\\1",
      linked
    )
    source_articles <- tools::file_path_sans_ext(basename(source_paths))
    rendered_articles <- tools::file_path_sans_ext(basename(rendered_paths))
    testthat::expect_gt(length(linked_articles), 0L)
    testthat::expect_true(all(linked_articles %in% source_articles))
    testthat::expect_true(all(linked_articles %in% rendered_articles))

    capture_targets <- function(pattern, text) {
      matches <- regmatches(text, gregexpr(pattern, text, perl = TRUE))[[1L]]
      if (length(matches) == 1L && identical(matches, "")) return(character())
      sub(pattern, "\\1", matches, perl = TRUE)
    }
    image_rows <- lapply(rendered_paths, function(path) {
      text <- paste(
        readLines(path, warn = FALSE, encoding = "UTF-8"),
        collapse = "\n"
      )
      targets <- c(
        capture_targets(
          "!\\[[^]]*\\]\\(<?([^[:space:])>]+)>?[^)]*\\)",
          text
        ),
        capture_targets(
          "<img\\b[^>]*\\bsrc\\s*=\\s*[\"']([^\"']+)[\"'][^>]*>",
          text
        )
      )
      targets <- targets[
        !grepl("^(?:[[:alpha:]][[:alnum:]+.-]*:|//|#|/)", targets, perl = TRUE)
      ]
      if (length(targets) == 0L) return(NULL)
      data.frame(source = path, target = targets, stringsAsFactors = FALSE)
    })
    image_rows <- image_rows[!vapply(image_rows, is.null, logical(1))]
    testthat::expect_gt(length(image_rows), 0L)
    if (length(image_rows) > 0L) {
      images <- do.call(rbind, image_rows)
      resolved <- mapply(
        function(source, target) {
          target <- utils::URLdecode(sub("[?#].*$", "", target))
          file.path(dirname(source), target)
        },
        images$source,
        images$target,
        USE.NAMES = FALSE
      )
      testthat::expect_identical(resolved[!file.exists(resolved)], character())
    }

    public_paths <- c(
      rendered_paths,
      list.files(
        file.path(root, "docs", "articles"),
        pattern = "[.]html$",
        full.names = TRUE
      )
    )
    public_text <- paste(
      unlist(lapply(public_paths, readLines, warn = FALSE)),
      collapse = "\n"
    )
    testthat::expect_no_match(
      public_text,
      "duckdb is storing downloaded extensions and secrets",
      fixed = TRUE
    )
  }

  boundary_paths <- file.path(root, c("DESCRIPTION", "NAMESPACE", "R"))
  boundary_exist <- file.exists(boundary_paths) | dir.exists(boundary_paths)
  testthat::expect_true(
    all(boundary_exist),
    info = paste(
      "missing optional-dependency boundary input:",
      boundary_paths[!boundary_exist]
    )
  )
  if (all(boundary_exist)) {
    description <- read.dcf(file.path(root, "DESCRIPTION"))
    namespace <- paste(
      readLines(file.path(root, "NAMESPACE"), warn = FALSE),
      collapse = "\n"
    )
    suggests <- trimws(unlist(strsplit(description[, "Suggests"], "[,\n]")))
    testthat::expect_true("qlcal" %in% suggests)
    testthat::expect_no_match(namespace, "importFrom\\(qlcal")
    r_files <- list.files(file.path(root, "R"), pattern = "[.]R$", full.names = TRUE)
    qlcal_users <- basename(r_files[vapply(r_files, function(path) {
      any(grepl("qlcal::", readLines(path, warn = FALSE), fixed = TRUE))
    }, logical(1))])
    testthat::expect_identical(qlcal_users, "availability-facts.R")
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
