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

testthat::test_that("[LTB-0099] strategy teaching uses the shipped helper policies", {
  authoring_qmd_lines <- readLines(
    ledgr_test_source_vignette("strategy-authoring-tools.qmd"),
    warn = FALSE
  )
  authoring_qmd <- paste(authoring_qmd_lines, collapse = "\n")
  authoring_md <- paste(
    readLines(
      ledgr_test_source_vignette("strategy-authoring-tools.md"),
      warn = FALSE
    ),
    collapse = "\n"
  )
  development_qmd <- paste(
    readLines(
      ledgr_test_source_vignette("strategy-development.qmd"),
      warn = FALSE
    ),
    collapse = "\n"
  )
  root <- testthat::test_path("..", "..")
  help_files <- c(
    "ledgr_signal_feature.Rd",
    "ledgr_select_top_n.Rd",
    "ledgr_target_rebalance.Rd",
    "ledgr_selection.Rd",
    "ledgr_pulse_snapshot.Rd"
  )
  help <- vapply(help_files, function(path) {
    paste(
      readLines(file.path(root, "man", path), warn = FALSE),
      collapse = "\n"
    )
  }, character(1))

  qmd_chunk <- function(lines, label) {
    label_line <- which(trimws(lines) == paste0("#| label: ", label))
    testthat::expect_length(label_line, 1L)
    tail <- lines[seq.int(label_line + 1L, length(lines))]
    close <- which(trimws(tail) == "```")[[1L]]
    paste(lines[seq.int(label_line, label_line + close)], collapse = "\n")
  }
  trend_chunk <- qmd_chunk(authoring_qmd_lines, "trend-momentum")
  weekly_chunk <- qmd_chunk(authoring_qmd_lines, "weekly-trend-momentum")
  top_chunk <- qmd_chunk(authoring_qmd_lines, "top-momentum")
  cleanup_chunk <- qmd_chunk(authoring_qmd_lines, "cleanup")

  for (needle in c(
    'ledgr_select_top_n(short_signal, n = 2, partial = "allow")',
    'feature_signal <- ledgr_signal_feature(pulse, "return_5")',
    'ledgr_target_rebalance(keep_pulse, keep = "DEMO_04")',
    'ledgr_selection(where = rising, missing = "exclude")',
    'state_prev = list(pulses_seen = 1)',
    'weights |>\n    ledgr_target_rebalance(ctx'
  )) {
    testthat::expect_match(authoring_qmd, needle, fixed = TRUE, info = needle)
  }
  for (chunk in list(trend_chunk, weekly_chunk)) {
    testthat::expect_match(
      chunk,
      'ledgr_selection(where = rising, missing = "exclude")',
      fixed = TRUE
    )
    testthat::expect_no_match(chunk, "is.na(", fixed = TRUE)
  }
  testthat::expect_no_match(top_chunk, 'partial = "allow"', fixed = TRUE)
  testthat::expect_no_match(
    development_qmd,
    'ledgr_select_top_n(n = params$n, partial = "allow")',
    fixed = TRUE
  )
  testthat::expect_match(
    weekly_chunk,
    'exits <- ledgr_selection(ctx, where = close < trend, missing = "exclude")',
    fixed = TRUE
  )
  testthat::expect_no_match(weekly_chunk, "as.logical(exits)", fixed = TRUE)
  testthat::expect_match(cleanup_chunk, "close(keep_pulse)", fixed = TRUE)
  testthat::expect_no_match(
    authoring_qmd,
    "equity_fraction = 0.6",
    fixed = TRUE
  )
  testthat::expect_no_match(
    authoring_qmd,
    'targets[["DEMO_04"]]',
    fixed = TRUE
  )
  testthat::expect_match(
    development_qmd,
    '`ledgr_target_rebalance(..., keep = )`',
    fixed = TRUE
  )
  testthat::expect_match(
    development_qmd,
    "The weights carry only relative allocations.",
    fixed = TRUE
  )

  for (outcome in c(
    "nrow(top_momentum_fills)\n#> [1] 136",
    'nrow(ledgr_results(trend_momentum_run, what = "fills"))\n#> [1] 177',
    paste0(
      'ledgr_select_top_n(short_signal, n = 2, partial = "allow")\n',
      "#> <ledgr_selection> [4 assets]\n",
      "#> 1 selected"
    ),
    "#>       0       8       0       4",
    paste0(
      "weekly_trend_momentum(exit_pulse, weekly_params)\n",
      "#> $targets\n",
      "#> DEMO_01 DEMO_02 DEMO_03 DEMO_04\n",
      "#>       0      10       0       0\n",
      "#>\n",
      "#> $state_update\n",
      "#> $state_update$pulses_seen\n",
      "#> [1] 2"
    )
  )) {
    testthat::expect_match(authoring_md, outcome, fixed = TRUE, info = outcome)
  }

  example_needles <- c(
    "ledgr_signal_feature(ctx, \"return_5\")",
    "partial = \"allow\"",
    "keep = \"AAA\"",
    "missing = \"exclude\"",
    "state_prev = list(pulses_seen = 1)"
  )
  for (i in seq_along(help)) {
    testthat::expect_match(
      help[[i]],
      example_needles[[i]],
      fixed = TRUE,
      info = help_files[[i]]
    )
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

  # Also covers: feature-map docs preserve semantic boundaries; feature maps are
  # taught in Indicators, strategy authoring reads registered features
  local({
  strategy_doc <- paste(c(
    readLines(ledgr_test_source_vignette("strategy-development.qmd"), warn = FALSE),
    readLines(ledgr_test_source_vignette("strategy-authoring-tools.qmd"), warn = FALSE)
  ), collapse = "\n")
  leakage_doc <- paste(
    readLines(ledgr_test_source_vignette("leakage.qmd"), warn = FALSE),
    collapse = "\n"
  )
  indicators_doc <- paste(readLines(ledgr_test_source_vignette("indicators.qmd"), warn = FALSE), collapse = "\n")
  root <- testthat::test_path("..", "..")
  feature_map_help <- paste(readLines(file.path(root, "man", "ledgr_feature_map.Rd"), warn = FALSE), collapse = "\n")
  warmup_help <- paste(readLines(file.path(root, "man", "ledgr_passed_warmup.Rd"), warn = FALSE), collapse = "\n")

  testthat::expect_match(strategy_doc, "A \\*\\*target vector\\*\\* is the strategy's requested holdings")
  testthat::expect_match(strategy_doc, "`ctx` is the \\*\\*pulse context\\*\\*")
  testthat::expect_match(strategy_doc, "pulse t state<br/>bars through t", fixed = TRUE)
  testthat::expect_match(strategy_doc, "strategy\\(ctx, params\\)")
  testthat::expect_match(strategy_doc, "Change `buy_if_up\\(\\)`")
  testthat::expect_match(strategy_doc, "`params` is the run's \\*\\*strategy configuration\\*\\*")
  testthat::expect_match(leakage_doc, "## The Obvious Leak", fixed = TRUE)
  testthat::expect_match(leakage_doc, "tomorrow_close = lead\\(close\\)")
  testthat::expect_match(leakage_doc, "does not receive the full future market-data table", fixed = TRUE)
  testthat::expect_match(leakage_doc, "does not certify that the dataset, event timestamps", fixed = TRUE)
  testthat::expect_match(strategy_doc, "declared on the experiment, never inside the strategy", fixed = TRUE)
  testthat::expect_match(strategy_doc, "vignette\\(\"sweeps\", package = \"ledgr\"\\)")
  testthat::expect_no_match(strategy_doc, "feature factory", ignore.case = TRUE)
  testthat::expect_match(strategy_doc, "a call to your own function defined outside the\\s+strategy, such as `trend_momentum\\(\\)`, is rejected before the run starts")
  testthat::expect_match(strategy_doc, "returning `ctx\\$hold\\(\\)` does not guarantee that no fill occurs")
  testthat::expect_match(strategy_doc, "rising <- momentum > 0 & close > trend", fixed = TRUE)
  testthat::expect_match(
    strategy_doc,
    "targets[exits] <- 0",
    fixed = TRUE
  )
  testthat::expect_no_match(strategy_doc, "rising <- !is.na", fixed = TRUE)
  testthat::expect_match(strategy_doc, "`vignette\\(\"reproducibility\", package = \"ledgr\"\\)` explains why")
  testthat::expect_match(strategy_doc, "Test A Strategy On One Pulse", fixed = TRUE)
  testthat::expect_match(strategy_doc, "builds an inspection context for one timestamp", fixed = TRUE)
  testthat::expect_no_match(strategy_doc, "builds the same `ctx`", fixed = TRUE)
  testthat::expect_match(strategy_doc, "top_momentum(pulse, params)", fixed = TRUE)
  testthat::expect_match(indicators_doc, "The strategy still returns ordinary target quantities.", fixed = TRUE)
  testthat::expect_match(indicators_doc, "do not create `ledgr_ind_returns(params$lookback)` lazily inside the strategy", fixed = TRUE)
  testthat::expect_match(indicators_doc, "The canonical strategy workflow is: register features on", fixed = TRUE)
  testthat::expect_match(indicators_doc, "axis with `ctx$vec$feature()`", fixed = TRUE)
  testthat::expect_match(indicators_doc, "For exploratory sweeps over ledgr-owned indicator parameters", fixed = TRUE)
  testthat::expect_match(indicators_doc, "it closes over a value\\s+built from the feature map")
  testthat::expect_match(indicators_doc, "stored strategy source refers to `ids` only by name", fixed = TRUE)
  testthat::expect_match(indicators_doc, "ret_5 <- ctx$vec$feature(ids[[\"ret_5\"]])", fixed = TRUE)
  testthat::expect_no_match(indicators_doc, "for (id in ctx$universe)", fixed = TRUE)
  testthat::expect_match(indicators_doc, "ledgr_pulse_wide(pulse, features)", fixed = TRUE)
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

  # Also covers: retired article slugs are not installed
  local({
  root <- testthat::test_path("..", "..")
  for (retired in c("ttr-and-adapter-indicators")) {
    testthat::expect_false(file.exists(file.path(root, "vignettes", paste0(retired, ".qmd"))))
    testthat::expect_false(file.exists(file.path(root, "inst", "doc", paste0(retired, ".qmd"))))
    testthat::expect_false(file.exists(file.path(root, "inst", "doc", paste0(retired, ".R"))))
    testthat::expect_false(file.exists(file.path(root, "inst", "doc", paste0(retired, ".html"))))
  }
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
  checklist_doc <- paste(readLines(ledgr_test_source_vignette("indicators.qmd"), warn = FALSE), collapse = "\n")
  sweeps_doc <- paste(readLines(ledgr_test_source_vignette("sweeps.qmd"), warn = FALSE), collapse = "\n")
  cost_doc <- paste(readLines(ledgr_test_source_vignette("risk-and-cost.qmd"), warn = FALSE), collapse = "\n")
  execution_doc_last_bar <- paste(readLines(ledgr_test_source_vignette("execution-semantics.qmd"), warn = FALSE), collapse = "\n")
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
  testthat::expect_match(checklist_doc, "Diagnose A Successful Run With Zero Trades", fixed = TRUE)
  testthat::expect_match(metrics_doc, "compact helper for accounting\\s+examples")
  testthat::expect_match(metrics_doc, "snapshot -> `ledgr_experiment\\(\\)` -> `ledgr_run\\(\\)`")
  testthat::expect_match(checklist_doc, "requires_bars", fixed = TRUE)
  testthat::expect_match(checklist_doc, "stable_after", fixed = TRUE)
  testthat::expect_match(checklist_doc, "Warmup is per instrument", fixed = TRUE)
  testthat::expect_match(checklist_doc, "Warmup Diagnostics", fixed = TRUE)
  testthat::expect_match(checklist_doc, "Four Warmup-Adjacent Cases", fixed = TRUE)
  testthat::expect_match(checklist_doc, "Ordinary feature warmup", fixed = TRUE)
  testthat::expect_match(checklist_doc, "Impossible warmup", fixed = TRUE)
  testthat::expect_match(checklist_doc, "Current-bar absence", fixed = TRUE)
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
  testthat::expect_match(execution_doc_last_bar, "LEDGR_LAST_BAR_NO_FILL", fixed = TRUE)
  testthat::expect_match(checklist_doc, "ledgr_pulse_snapshot()", fixed = TRUE)
  testthat::expect_match(checklist_doc, "Ordinary feature warmup is local to the beginning of each instrument's usable\\s+sample")
  testthat::expect_match(metrics_doc, "Risk Metric Contract", fixed = TRUE)
  testthat::expect_match(metrics_doc, "sharpe_ratio", fixed = TRUE)
  testthat::expect_match(metrics_doc, "excess_return[t] = equity_return[t] - rf_period_return[t]", fixed = TRUE)
  testthat::expect_match(metrics_doc, "0.02` means two percent per year", fixed = TRUE)
  testthat::expect_match(metrics_doc, "rf_period_return = \\(1 \\+ rf_annual\\)\\^\\(1 / bars_per_year\\) - 1")
  testthat::expect_match(metrics_doc, "see `?ledgr_compute_metrics` for the exact edge-case rules", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Time-varying risk-free-rate series and real data providers", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Sortino, Calmar, Omega, information ratio", fixed = TRUE)
  testthat::expect_match(metrics_doc, "Metric assumptions live in a `metric_context`", fixed = TRUE)
  testthat::expect_match(cost_doc, "Timing, Spread, And Fees", fixed = TRUE)
  testthat::expect_match(cost_doc, "Timing and cost are separate execution steps", fixed = TRUE)
  testthat::expect_match(cost_doc, "open \\* \\(1 \\+ spread_bps / 20000\\)")
  testthat::expect_match(cost_doc, "open \\* \\(1 - spread_bps / 20000\\)")
  testthat::expect_match(cost_doc, "approximately `spread_bps` basis points before\\s+explicit fees")
  testthat::expect_match(cost_doc, "Price transforms and explicit fees are different", fixed = TRUE)
  testthat::expect_match(cost_doc, "What costs do not model", fixed = TRUE)
  for (term in c("liquidity", "financing", "taxes", "OMS", "broker reconciliation")) {
    testthat::expect_match(cost_doc, term, fixed = TRUE)
  }
  testthat::expect_match(cost_doc, "transaction-cost\\s+analysis")
  testthat::expect_match(sweeps_doc, "A committed `ledgr_run()` that requests it stops with an error.", fixed = TRUE)
  testthat::expect_match(sweeps_doc, "ledgr_unsupported_accounting_model", fixed = TRUE)
  testthat::expect_match(sweeps_doc, "ledgr_compiled_spot_fifo_unavailable", fixed = TRUE)
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
  testthat::expect_match(metrics_doc, "raw metrics object keeps attributes that record how each metric was", fixed = TRUE)
  testthat::expect_match(checklist_doc, "Timestamp checks should compare normalized UTC values", fixed = TRUE)
  testthat::expect_match(checklist_doc, "intraday_time <- format", fixed = TRUE)
  testthat::expect_match(checklist_doc, "distinguish zero signals from zero sizing", fixed = TRUE)
  testthat::expect_match(checklist_doc, "required fill fields", fixed = TRUE)
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

  testthat::expect_match(strategy_authoring_doc, "From Scores To Shares", fixed = TRUE)
  testthat::expect_match(strategy_authoring_doc, "Only the target is something ledgr executes", fixed = TRUE)
  testthat::expect_match(strategy_authoring_doc, "shares = floor(budget / chosen_close)", fixed = TRUE)
  testthat::expect_match(strategy_authoring_doc, "Choose Members With A Rule Instead Of A Rank", fixed = TRUE)
  testthat::expect_match(strategy_authoring_doc, "ledgr refuses a missing decision instead of quietly treating it as\\s+`FALSE`")
  testthat::expect_match(strategy_authoring_doc, "hold-then-edit pattern", fixed = TRUE)
  testthat::expect_match(strategy_authoring_doc, "*held nonmember*", fixed = TRUE)
  testthat::expect_match(strategy_authoring_doc, "Neither membership nor `ctx$tradable()` guarantees", fixed = TRUE)
  testthat::expect_match(strategy_doc, "Affordability is not automatic", fixed = TRUE)
  # The affordability and risk-chain facts moved to their homes in LDG-2900;
  # Strategy Basics keeps a gloss that links the home.
  execution_home <- paste(readLines(ledgr_test_source_vignette("execution-semantics.qmd"), warn = FALSE), collapse = "\n")
  risk_home <- paste(readLines(ledgr_test_source_vignette("risk-and-cost.qmd"), warn = FALSE), collapse = "\n")
  production_doc <- paste(readLines(ledgr_test_source_vignette("research-to-production.qmd"), warn = FALSE), collapse = "\n")
  testthat::expect_match(strategy_development_doc, "A dense run fills a target whether or not the account can pay\\s+for it")
  testthat::expect_match(execution_home, "Dense\\s+fills do not check cash, which can go negative")
  testthat::expect_match(risk_home, "A risk chain may reshape those quantities\\s+before any fill exists")
  testthat::expect_match(production_doc, "Affordability is not\\s+part of it")
  testthat::expect_match(strategy_doc, "returns an empty selection without a warning", fixed = TRUE)
  testthat::expect_match(strategy_authoring_doc, "Decide What A Missing Input Should Do", fixed = TRUE)
  testthat::expect_match(strategy_authoring_doc, "holding_pulse <- ledgr_pulse_snapshot", fixed = TRUE)
  testthat::expect_match(strategy_authoring_doc, "| zero, including an instrument left out of the selection | sell down to zero |", fixed = TRUE)
  testthat::expect_match(strategy_authoring_doc, "if (!ledgr_passed_warmup(ctx$vec$feature(\"sma_10\"))) return(ctx$hold())", fixed = TRUE)
  testthat::expect_match(strategy_authoring_doc, "ledgr_signal_return(lookback = 5) |>", fixed = TRUE)
  testthat::expect_match(strategy_authoring_doc, "it never\\s+registers a feature for you")
  testthat::expect_match(strategy_authoring_doc, "ledgr_run_compare(snapshot)", fixed = TRUE)
  testthat::expect_match(strategy_authoring_doc, "Give The Strategy A Memory", fixed = TRUE)
  testthat::expect_match(strategy_authoring_doc, "`ctx$state_prev$pulses_seen` is `NULL`", fixed = TRUE)
  testthat::expect_match(strategy_development_doc, "\n## Remembering Between Pulses\n", fixed = TRUE)
  testthat::expect_match(strategy_development_doc, "check each\\s+field for `NULL` before using it")
  testthat::expect_match(strategy_development_doc, "`?ledgr_strategy_context` states the full rules", fixed = TRUE)
  # Strategy Basics teaches whole-vector rules, not the scalar loop its own
  # tip calls slow, and keeps accelerator internals out of the first article.
  testthat::expect_no_match(strategy_development_doc, "for (id in ctx$universe)", fixed = TRUE)
  testthat::expect_match(
    strategy_development_doc,
    "up <- ctx$vec$close > ctx$vec$open\n  targets <- ctx$flat()\n  targets[up] <- 1",
    fixed = TRUE
  )
  testthat::expect_no_match(strategy_development_doc, "compiled_accounting_model", fixed = TRUE)
  testthat::expect_no_match(strategy_development_doc, "`signal_*()`", fixed = TRUE)
  testthat::expect_no_match(strategy_development_doc, "```{r cleanup}", fixed = TRUE)
  testthat::expect_match(strategy_development_doc, "#| label: incomplete-target", fixed = TRUE)
  testthat::expect_match(
    strategy_authoring_doc,
    "exact-ID\nfeature accessor triggers one",
    fixed = TRUE
  )
  testthat::expect_match(strategy_authoring_doc, "### Keep A Position While Rebalancing The Rest", fixed = TRUE)
  testthat::expect_no_match(strategy_authoring_doc, "This is exactly the target a backtest would receive", fixed = TRUE)
  testthat::expect_match(context_help, "carries\\s+\\\\code\\{asset_state\\}")
  testthat::expect_match(context_help, "NULL_on_first_dense_pulse", fixed = TRUE)
  testthat::expect_match(strategy_authoring_doc, "Returning a bare target keeps the previous state unchanged.", fixed = TRUE)
  testthat::expect_match(strategy_authoring_doc, "state_update = list(pulses_seen = pulses_seen + 1)", fixed = TRUE)
  testthat::expect_match(strategy_authoring_doc, "Read whole vectors, not one instrument at a time", fixed = TRUE)
  testthat::expect_match(strategy_authoring_doc, "`ledgr_scalar_accessor_loop` warning", fixed = TRUE)
  testthat::expect_no_match(strategy_authoring_doc, "The optimization manual carries the measurements", fixed = TRUE)
  testthat::expect_no_match(strategy_authoring_doc, "for (id in ctx$universe)", fixed = TRUE)
  testthat::expect_no_match(strategy_authoring_doc, "summary(bt_mapped)", fixed = TRUE)
  testthat::expect_match(strategy_doc, "vignette\\(\"data-input-and-snapshots\",\\s+package = \"ledgr\"\\)")
  testthat::expect_no_match(strategy_development_doc, "\\*\\*Definition\\*\\*")
  testthat::expect_match(strategy_doc, "ledgr_results\\(bt_first, what = \"fills\"\\)")
  testthat::expect_match(strategy_doc, "Zero fills means no execution occurred", fixed = TRUE)
  testthat::expect_match(strategy_doc, "Non-empty fills with zero trades", fixed = TRUE)
  testthat::expect_match(strategy_doc, "test the strategy on a late\\s+pulse")
  testthat::expect_match(strategy_authoring_doc, "vignette\\(\"reproducibility\", package = \"ledgr\"\\)")
  testthat::expect_match(strategy_authoring_doc, "top_momentum_run <- ledgr_experiment(", fixed = TRUE)
  testthat::expect_match(strategy_authoring_doc, "weekly_run <- ledgr_experiment(", fixed = TRUE)
  testthat::expect_match(strategy_doc, "If you want to compare variants", fixed = TRUE)
  testthat::expect_match(strategy_doc, "strategy authoring question separate", fixed = TRUE)
  testthat::expect_match(strategy_doc, "?ledgr_strategy_context", fixed = TRUE)
  testthat::expect_match(target_help, "floored to whole numbers", fixed = TRUE)
  testthat::expect_match(target_help, "allocatable equity", fixed = TRUE)
  testthat::expect_match(target_help, "held nonmembers", fixed = TRUE)
  testthat::expect_match(target_help, "floor(weight * equity_fraction * allocation_equity /", fixed = TRUE)

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
  testthat::expect_match(context_help, "\\code{ctx$vec$position}", fixed = TRUE)
  testthat::expect_match(context_help, "\\code{ctx$features(id, feature_map)}", fixed = TRUE)
  testthat::expect_match(context_help, "\\code{ctx$flat()}", fixed = TRUE)
  testthat::expect_match(context_help, "\\code{ctx$hold()}", fixed = TRUE)
  testthat::expect_match(context_help, "Feature Object Compatibility", fixed = TRUE)
  })
})

testthat::test_that("[LTB-0116] corrected articles keep their teaching claims", {
  root <- testthat::test_path("..", "..", "vignettes")
  read_article <- function(name) {
    paste(readLines(file.path(root, name), warn = FALSE), collapse = "\n")
  }

  quickstart <- read_article("quickstart.qmd")
  indicators <- read_article("indicators.qmd")
  leakage <- read_article("leakage.qmd")
  strategy_basics <- read_article("strategy-development.qmd")
  survivorship <- read_article("survivorship-bias.qmd")
  sweeps <- read_article("sweeps.qmd")
  execution <- read_article("execution-semantics.qmd")
  missing <- read_article("missing-data-and-sessions.qmd")
  adapter <- read_article("corporate-action-adapter-authoring.qmd")
  reproducibility <- read_article("reproducibility.qmd")
  custom <- read_article("custom-indicators.qmd")
  ttr <- read_article("ttr-indicators.qmd")
  walk_forward <- read_article("walk-forward.qmd")

  testthat::expect_match(quickstart, "strategy <- function(ctx, params)", fixed = TRUE)
  testthat::expect_no_match(quickstart, "ledgr_demo_sma_crossover_strategy", fixed = TRUE)
  testthat::expect_match(indicators, "ctx$vec$feature(feature_id)", fixed = TRUE)
  testthat::expect_no_match(
    indicators,
    "The canonical workflow is: register features on `ledgr_experiment()`, then read\npulse-known values through `ctx$feature()` or `ctx$features()` inside the\nstrategy.",
    fixed = TRUE
  )
  testthat::expect_match(indicators, "#| eval: !expr requireNamespace(\"TTR\"", fixed = TRUE)
  testthat::expect_match(leakage, "lead(close)", fixed = TRUE)
  testthat::expect_no_match(strategy_basics, "tomorrow_close = lead(close)", fixed = TRUE)
  testthat::expect_match(
    survivorship,
    'rebalance_dates <- c("2020-01-06", "2020-01-13")',
    fixed = TRUE
  )
  testthat::expect_match(survivorship, "availability-aware execution outcome", fixed = TRUE)
  testthat::expect_match(sweeps, "business-objective helpers", fixed = TRUE)
  testthat::expect_no_match(
    sweeps,
    "automatic ranking, objective functions, or `ledgr_tune()`",
    fixed = TRUE
  )
  testthat::expect_lt(
    regexpr("## Failure Rows And Contract Errors", sweeps, fixed = TRUE)[[1L]],
    regexpr("## Promote One Candidate", sweeps, fixed = TRUE)[[1L]]
  )
  testthat::expect_match(sweeps, "| Level | What it keeps |", fixed = TRUE)
  testthat::expect_match(execution, '"opened and still held"', fixed = TRUE)
  testthat::expect_match(execution, "select(action, realized_pnl)", fixed = TRUE)
  testthat::expect_match(execution, "select(case, positions_value, equity)", fixed = TRUE)
  testthat::expect_match(missing, "ledgr_snapshot_quarantine()", fixed = TRUE)
  testthat::expect_no_match(missing, "Two accessors are still missing", fixed = TRUE)
  testthat::expect_no_match(missing, "there is no\naccessor for them yet", fixed = TRUE)
  testthat::expect_match(missing, "retained pulse history when `ts_utc` is omitted", fixed = TRUE)
  testthat::expect_match(
    adapter,
    "include fictional-corporate-action-adapter.R",
    fixed = TRUE
  )
  testthat::expect_match(reproducibility, "dependency_versions", fixed = TRUE)
  testthat::expect_match(
    custom,
    "supports both `fn(window)` and `fn(window, params)`",
    fixed = TRUE
  )
  testthat::expect_match(custom, "fn = function(window, params)", fixed = TRUE)
  testthat::expect_match(ttr, "accept only the exact single-output\\s+`SMA\\(close, n\\)` TTR shape")
  testthat::expect_no_match(walk_forward, "answers the generalization question", fixed = TRUE)
})

testthat::test_that("[LTB-0101] pulse teaching promises the run feature path", {
  strategy_doc <- paste(
    readLines(
      ledgr_test_source_vignette("strategy-authoring-tools.qmd"),
      warn = FALSE
    ),
    collapse = "\n"
  )
  indicators_doc <- paste(
    readLines(ledgr_test_source_vignette("indicators.qmd"), warn = FALSE),
    collapse = "\n"
  )
  ttr_doc <- paste(
    readLines(
      ledgr_test_source_vignette("ttr-indicators.qmd"),
      warn = FALSE
    ),
    collapse = "\n"
  )

  testthat::expect_match(
    strategy_doc,
    "same feature path as a dense run",
    fixed = TRUE
  )
  testthat::expect_match(
    indicators_doc,
    "same feature path a dense run uses over snapshot",
    fixed = TRUE
  )
  testthat::expect_match(
    indicators_doc,
    "`stable_after`, and, for a custom indicator computed over the whole series,\\s+its `series_fn`"
  )
  testthat::expect_match(
    ttr_doc,
    "including the TTR adapter's parameters, recursive series calculation",
    fixed = TRUE
  )
})

testthat::test_that("[LTB-0103] feature-loop teaching names the actionable boundary", {
  root <- testthat::test_path("..", "..")
  strategy_doc <- paste(
    readLines(
      ledgr_test_source_vignette("strategy-authoring-tools.qmd"),
      warn = FALSE
    ),
    collapse = "\n"
  )
  context_help <- paste(
    readLines(
      file.path(root, "man", "ledgr_strategy_context.Rd"),
      warn = FALSE
    ),
    collapse = "\n"
  )

  testthat::expect_match(
    strategy_doc,
    "exact-ID\nfeature accessor triggers one",
    fixed = TRUE
  )
  testthat::expect_match(
    strategy_doc,
    "`ctx\\$features\\(id\\)` stays unrecorded: ledgr has no alias-aware\\s+whole-universe feature read yet"
  )
  testthat::expect_match(
    context_help,
    "ctx$vec$feature(feature_id)",
    fixed = TRUE
  )
  testthat::expect_match(
    context_help,
    "warning without a replacement would not be",
    fixed = TRUE
  )
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
      testthat::expect_match(doc, "cost_model_hash", fixed = TRUE)
      testthat::expect_match(doc, "cost_plan_json", fixed = TRUE)
      testthat::expect_match(doc, "walk-forward evaluation runs over the existing sweep and run surfaces", fixed = TRUE)
      testthat::expect_match(doc, "The v0.2.1.0 release line is a correctness-first research layer", fixed = TRUE)
      testthat::expect_match(doc, "DSR, PBO/CSCV, MinTRL", fixed = TRUE)
      testthat::expect_match(doc, "Paper/live execution, broker adapters, and operational observability[[:space:]]+remain")
      testthat::expect_match(doc, "no[[:space:]]+release date or operational capability is implied")
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
    building_blocks <- regexpr("  - title: Building Blocks", pkgdown_text, fixed = TRUE)
    research_workflow <- regexpr("  - title: Research Workflow", pkgdown_text, fixed = TRUE)
    pit_evidence <- regexpr("  - title: Point-In-Time Evidence", pkgdown_text, fixed = TRUE)
    going_deeper <- regexpr("  - title: Going Deeper", pkgdown_text, fixed = TRUE)
    design <- regexpr("  - title: Design / Background", pkgdown_text, fixed = TRUE)
    testthat::expect_gt(start_here[[1]], 0)
    testthat::expect_gt(building_blocks[[1]], start_here[[1]])
    testthat::expect_gt(research_workflow[[1]], building_blocks[[1]])
    testthat::expect_gt(pit_evidence[[1]], research_workflow[[1]])
    testthat::expect_gt(going_deeper[[1]], pit_evidence[[1]])
    testthat::expect_gt(design[[1]], going_deeper[[1]])

    start_block <- substr(pkgdown_text, start_here[[1]], building_blocks[[1]] - 1L)
    testthat::expect_match(start_block, "articles/who-ledgr-is-for", fixed = TRUE)
    testthat::expect_match(start_block, "- quickstart", fixed = TRUE)
    testthat::expect_no_match(start_block, "- survivorship-bias", fixed = TRUE)

    blocks_block <- substr(pkgdown_text, building_blocks[[1]], research_workflow[[1]] - 1L)
    for (article in c(
      "data-input-and-snapshots", "strategy-development", "indicators", "leakage",
      "metrics-and-accounting", "risk-and-cost", "experiment-store", "reproducibility"
    )) {
      testthat::expect_match(blocks_block, paste0("- ", article), fixed = TRUE)
    }

    research_block <- substr(
      pkgdown_text,
      research_workflow[[1]],
      pit_evidence[[1]] - 1L
    )
    testthat::expect_match(research_block, "- sweeps", fixed = TRUE)
    testthat::expect_match(research_block, "- research-workflow", fixed = TRUE)
    testthat::expect_match(research_block, "- selection-integrity", fixed = TRUE)
    testthat::expect_match(research_block, "- walk-forward", fixed = TRUE)

    pit_block <- substr(pkgdown_text, pit_evidence[[1]], going_deeper[[1]] - 1L)
    testthat::expect_match(pit_block, "- point-in-time-inputs", fixed = TRUE)
    testthat::expect_match(pit_block, "- missing-data-and-sessions", fixed = TRUE)
    testthat::expect_match(pit_block, "- corporate-action-cash", fixed = TRUE)
    testthat::expect_match(pit_block, "- survivorship-bias", fixed = TRUE)

    deeper_block <- substr(pkgdown_text, going_deeper[[1]], design[[1]] - 1L)
    testthat::expect_match(deeper_block, "- strategy-authoring-tools", fixed = TRUE)
    testthat::expect_match(deeper_block, "- ttr-indicators", fixed = TRUE)
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
    "point-in-time-inputs",
    "strategy-development",
    "strategy-authoring-tools",
    "indicators",
    "ttr-indicators",
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
  testthat::expect_no_match(text, "ttr-and-adapter-indicators", fixed = TRUE)
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
  testthat::expect_true("ttr-indicators" %in% installed_articles)
  testthat::expect_true("strategy-authoring-tools" %in% installed_articles)
  testthat::expect_true("metric-contexts-and-conventions" %in% installed_articles)
  testthat::expect_true("data-input-and-snapshots" %in% installed_articles)
  testthat::expect_true("point-in-time-inputs" %in% installed_articles)
  testthat::expect_true("quickstart" %in% installed_articles)
  testthat::expect_true("risk-and-cost" %in% installed_articles)
  testthat::expect_false("ttr-and-adapter-indicators" %in% installed_articles)
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
  testthat::expect_match(doc, "portability of the[[:space:]]+research store is not a trading system")
  testthat::expect_match(doc, "broker order state, partial fills, rejection handling", fixed = TRUE)
  testthat::expect_match(doc, "Design Philosophy: From Research to Production", fixed = TRUE)
  testthat::expect_match(doc, "What The Current Research Layer Delivers", fixed = TRUE)
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
      "vignettes/sweeps.qmd",
      "vignettes/sweeps.md",
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
    "contracts", "readme_rmd", "readme", "research_qmd", "research",
    "strategy_qmd", "strategy", "run_store", "namespace"
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
    docs$research_qmd,
    "review <- ledgr_sweep_review(reopened_sweep, rank_by = desc(sharpe_ratio), n = 5)",
    fixed = TRUE
  )
  testthat::expect_match(
    docs$research_qmd,
    "candidate <- ledgr_candidate(ranked, 1)",
    fixed = TRUE
  )
  testthat::expect_match(
    docs$readme_rmd,
    "above_trend <- function(ctx, params)",
    fixed = TRUE
  )
  testthat::expect_match(
    docs$readme_rmd,
    "snapshot <- ledgr_snapshot_open(store_path, snapshot_id, verify = TRUE)",
    fixed = TRUE
  )
  testthat::expect_match(
    docs$research,
    "candidate <- ledgr_candidate(ranked, 1)",
    fixed = TRUE
  )
  testthat::expect_no_match(docs$readme_rmd, "ledgr_sweep(", fixed = TRUE)
  testthat::expect_match(
    docs$strategy_qmd,
    "holding_pulse$hold()",
    fixed = TRUE
  )
  testthat::expect_match(
    docs$strategy,
    "`where` contains missing decisions for current members: DEMO_01, DEMO_02, DEMO_03, DEMO_04.",
    fixed = TRUE
  )
  testthat::expect_match(
    docs$strategy_qmd,
    "trend_momentum_run <- ledgr_experiment(",
    fixed = TRUE
  )
  # Rendered outcomes the article's prose depends on. A changed parameter,
  # feature or rule that moves these numbers must also revisit the prose.
  strategy_outcomes <- c(
    "nrow(top_momentum_fills)\n#> [1] 136",
    "nrow(ledgr_results(trend_momentum_run, what = \"fills\"))\n#> [1] 177",
    "#> 1 DEMO_02        25000  67.7    369    369",
    "#> 2 DEMO_03        25000  81.8    305    305",
    "#> 1 v1_ranking <NA>        11372.",
    "#> 2 v2_rule    <NA>        10874.",
    "#> 3 v3_weekly  <NA>        10577.",
    "#> 3 2019-01-30 DEMO_01       SELL     15",
    "trend_momentum(holding_pulse, params)\n#> <ledgr_target> [4 assets]\n#> non-NA: 4/4\n#> DEMO_01 DEMO_02 DEMO_03 DEMO_04\n#>       0       0       0       0",
    "holding_pulse$hold()\n#> DEMO_01 DEMO_02 DEMO_03 DEMO_04\n#>       0      40       0       0"
  )
  for (outcome in strategy_outcomes) {
    testthat::expect_match(docs$strategy, outcome, fixed = TRUE, info = outcome)
  }
  testthat::expect_match(docs$strategy, "76 69.7%", fixed = TRUE)
  testthat::expect_match(docs$strategy, "93 63.4%", fixed = TRUE)
  testthat::expect_match(docs$strategy, "36 55.6%", fixed = TRUE)
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
  testthat::expect_match(knowledge_section, "what-if for this article only", fixed = TRUE)
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

testthat::test_that("[LTB-0118] each article hands off to the next article in the reading flow", {
  root <- testthat::test_path("..", "..")
  pkgdown_path <- file.path(root, "_pkgdown.yml")
  testthat::skip_if_not(file.exists(pkgdown_path), "pkgdown config not available during installed-package tests")
  pkgdown <- readLines(pkgdown_path, warn = FALSE)
  articles_start <- grep("^articles:", pkgdown)
  articles_end <- grep("^(redirects|reference):", pkgdown)[[1L]]
  entries <- grep("^      - ", pkgdown[articles_start:articles_end], value = TRUE)
  flow <- sub("^      - ", "", entries)
  source_path <- function(entry) file.path(root, "vignettes", paste0(entry, ".qmd"))
  testthat::expect_true(all(file.exists(vapply(flow, source_path, character(1)))))

  first_handoff <- function(entry) {
    lines <- readLines(source_path(entry), warn = FALSE)
    heading <- grep("^## Where Next\\s*$", lines)
    if (length(heading) != 1L) return(NA_character_)
    body <- paste(lines[(heading + 1L):min(length(lines), heading + 12L)], collapse = " ")
    hit <- regmatches(body, regexpr('vignette\\("[a-z-]+"|[a-z-]+[.]html', body))
    if (length(hit) == 0L) return(NA_character_)
    sub("[.]html$", "", sub('^vignette\\("([a-z-]+)"$', "\\1", hit))
  }
  for (i in seq_len(length(flow) - 1L)) {
    testthat::expect_identical(
      first_handoff(flow[[i]]),
      basename(flow[[i + 1L]]),
      info = sprintf("Where Next of %s", flow[[i]])
    )
  }

  sidebar <- paste(pkgdown[seq_len(articles_start - 1L)], collapse = " ")
  sidebar_first <- regmatches(sidebar, regexpr("articles/[a-z-]+[.]html", sidebar))
  readme <- paste(readLines(file.path(root, "README.Rmd"), warn = FALSE), collapse = " ")
  learn_more <- sub(".*## Learn More", "", readme)
  readme_first <- regmatches(learn_more, regexpr("articles/[a-z-]+[.]html", learn_more))
  testthat::expect_identical(readme_first, sidebar_first)

  for (entry in flow) {
    rendered <- file.path(root, "vignettes", paste0(entry, ".md"))
    lines <- readLines(rendered, warn = FALSE)
    body <- lines[!grepl("^(#|\\s*$|<|:::|---|title:|format:|  )", lines)]
    testthat::expect_false(
      startsWith(body[[1L]], "```"),
      info = sprintf("%s opens with code before prose", entry)
    )
  }
})

# House rules 1, 4 and 6 over the README and every article source. Returns one
# message per violation, so the block can also be run against an older tree.
ledgr_doc_idiom_violations <- function(root) {
  sources <- c(
    file.path(root, "README.Rmd"),
    list.files(file.path(root, "vignettes"), pattern = "[.]qmd$", full.names = TRUE, recursive = TRUE)
  )
  disclosure <- paste(
    "ledgr has no alias-aware whole-universe feature read yet, so a strategy that",
    "reads active aliases loops over `ctx$features(id)`. With fixed feature IDs,",
    "use `ctx$vec$feature()`."
  )
  squish <- function(x) gsub("\\s+", " ", x)
  out <- character()
  for (path in sources) {
    lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
    name <- basename(path)
    old_header <- grep("^```\\{r[ ,]", lines)
    out <- c(out, sprintf("%s:%d old chunk header", name, old_header))

    opens <- grep("^```\\{r", lines)
    closes <- grep("^```\\s*$", lines)
    in_chunk <- logical(length(lines))
    for (open in opens) {
      close <- closes[closes > open][1L]
      if (!is.na(close) && close > open + 1L) in_chunk[(open + 1L):(close - 1L)] <- TRUE
    }
    code <- ifelse(in_chunk, lines, "")
    id_source <- grep(
      "(run_id|snapshot_id)\\b.*(Sys\\.getpid|Sys\\.time|Sys\\.Date|sample\\(|runif\\(|rnorm\\()",
      code
    )
    out <- c(out, sprintf("%s:%d run or snapshot ID from process, clock or random draw", name, id_source))

    loops <- grep("for \\(\\w+ in ctx\\$universe\\)", code)
    reads_aliases <- FALSE
    for (start in loops) {
      depth <- 0L
      end <- start
      for (i in start:length(code)) {
        depth <- depth + lengths(regmatches(code[[i]], gregexpr("\\{", code[[i]]))) -
          lengths(regmatches(code[[i]], gregexpr("\\}", code[[i]])))
        end <- i
        if (i > start && depth <= 0L) break
      }
      body <- code[start:end]
      if (any(grepl("ctx\\$feature\\(", body))) {
        out <- c(out, sprintf("%s:%d ctx$feature() inside a loop over ctx$universe", name, start))
      }
      if (any(grepl("ctx\\$features\\(", body))) reads_aliases <- TRUE
    }
    if (reads_aliases && !grepl(disclosure, squish(paste(lines, collapse = " ")), fixed = TRUE)) {
      out <- c(out, sprintf("%s: ctx$features(id) loop without the active-alias disclosure sentence", name))
    }
  }
  out
}

testthat::test_that("[LTB-0125] article code follows the house idioms for IDs, chunk headers and feature reads", {
  root <- testthat::test_path("..", "..")
  testthat::skip_if_not(file.exists(file.path(root, "README.Rmd")), "article sources not available during installed-package tests")
  testthat::expect_identical(ledgr_doc_idiom_violations(root), character())
})

# House rule 7: no stray console output in the rendered README or any rendered
# article. Returns one message per hit, so it can also run against an older tree.
ledgr_doc_stray_output <- function(root) {
  rendered <- c(
    file.path(root, "README.md"),
    list.files(file.path(root, "vignettes"), pattern = "[.]md$", full.names = TRUE, recursive = TRUE)
  )
  patterns <- c(
    "Attaching package",
    "The following object is masked",
    "The following objects are masked",
    "Loading required package",
    "Registered S3 method",
    "was built under R version"
  )
  out <- character()
  for (path in rendered) {
    lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
    for (pattern in patterns) {
      hit <- grep(pattern, lines, fixed = TRUE)
      out <- c(out, sprintf("%s:%d %s", basename(path), hit, pattern))
    }
  }
  out
}

testthat::test_that("[LTB-0126] no rendered article or the README shows stray console output", {
  root <- testthat::test_path("..", "..")
  testthat::skip_if_not(file.exists(file.path(root, "README.md")), "rendered articles not available during installed-package tests")
  testthat::expect_identical(ledgr_doc_stray_output(root), character())
})

# House rule 9 and style guide section 9: each shared fact is stated in its home
# article, and known contradicting phrases appear nowhere. Returns one message
# per problem, so it can also run against an older tree.
ledgr_doc_fact_home_problems <- function(root) {
  source_text <- function(slug) {
    path <- file.path(root, "vignettes", paste0(slug, ".qmd"))
    if (!file.exists(path)) return(NA_character_)
    gsub("\\s+", " ", paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = " "))
  }
  homes <- list(
    c("execution-semantics", "Dense fills do not check cash, which can go negative"),
    c("execution-semantics", "records the refusal with reason `insufficient_cash`"),
    c("execution-semantics", "`dense_bar_timestamp` means a dense run"),
    c("indicators", "| Public TTR SMA | `ledgr_ind_ttr(\"SMA\", input = \"close\", n = n)` | Supported for this exact single-output shape |"),
    c("indicators", "ledgr has no alias-aware whole-universe feature read yet, so a strategy that reads active aliases loops over `ctx$features(id)`. With fixed feature IDs, use `ctx$vec$feature()`."),
    c("sweeps", "Promotion records a choice; it does not make that choice out-of-sample."),
    c("selection-integrity", "Deflated Sharpe Ratio with effective trials"),
    c("walk-forward", "so a good walk-forward result does not prove that the rule generalizes"),
    c("point-in-time-inputs", "An experiment becomes availability-aware when its snapshot declares membership, session, trading-status or lifetime facts, or when the experiment declares a valuation policy."),
    c("corporate-action-cash", "`Corporate actions: NOT SUPPLIED` means the snapshot holds no corporate-action facts"),
    c("corporate-action-cash", "`Price basis: UNDECLARED` means the bars do not say how they were adjusted"),
    c("research-to-production", "Paper/live execution, broker adapters, and operational observability remain roadmap work."),
    c("risk-and-cost", "ledgr has no order management yet, so an intent that cannot execute at its fill opportunity is recorded as not executed rather than queued"),
    c("survivorship-bias", "`ctx$flat()` is literal, so a rule starting from it sells a departed holding at the next open."),
    c("missing-data-and-sessions", "A zero target for a halted holding is recorded as not executed and dropped, not queued.")
  )
  contradictions <- c(
    "does not implement affordability enforcement",
    "does not check affordability",
    "tests the generalization question",
    "later validation-toolkit",
    "Corporate actions, delisting cash flows",
    "Active aliases currently have no alias-aware",
    "active alias currently has no whole-universe"
  )
  out <- character()
  for (home in homes) {
    text <- source_text(home[[1L]])
    if (is.na(text) || !grepl(home[[2L]], text, fixed = TRUE)) {
      out <- c(out, sprintf("%s lacks its home statement: %s", home[[1L]], substr(home[[2L]], 1L, 60L)))
    }
  }
  sources <- c(
    file.path(root, "README.Rmd"),
    list.files(file.path(root, "vignettes"), pattern = "[.]qmd$", full.names = TRUE, recursive = TRUE)
  )
  for (path in sources) {
    text <- gsub("\\s+", " ", paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = " "))
    for (phrase in contradictions) {
      if (grepl(phrase, text, fixed = TRUE)) {
        out <- c(out, sprintf("%s contradicts a home fact: %s", basename(path), phrase))
      }
    }
  }
  out
}

testthat::test_that("[LTB-0127] each shared fact is stated in its home and contradicted nowhere", {
  root <- testthat::test_path("..", "..")
  testthat::skip_if_not(file.exists(file.path(root, "README.Rmd")), "article sources not available during installed-package tests")
  testthat::expect_identical(ledgr_doc_fact_home_problems(root), character())
})

# House rule 11 and style guide section 3: no internal shorthand a user cannot
# act on in the README or a user article, source or rendered. The one named
# exception is "accelerator" inside the compiled-accounting section of Sweeps.
ledgr_doc_maintainer_terms <- function(root) {
  documents <- c(
    file.path(root, c("README.Rmd", "README.md")),
    list.files(file.path(root, "vignettes"), pattern = "[.](qmd|md)$", full.names = TRUE, recursive = TRUE)
  )
  terms <- c(
    "fold core" = "(?i)\\bfold core\\b",
    "oracle" = "(?i)\\boracles?\\b",
    "touchpoint" = "(?i)\\btouchpoints?\\b",
    "accelerator" = "(?i)\\baccelerators?\\b",
    "legacy" = "(?i)\\blegacy\\b",
    "pre-provenance" = "(?i)\\bpre-provenance\\b",
    "parity contract" = "(?i)\\bparity contracts?\\b",
    "composable bundle" = "(?i)\\bcomposable bundles?\\b",
    "B2" = "\\bB2\\b",
    "ticket or test ID" = "\\b(LDG|LTB|LCL)-[0-9]"
  )
  out <- character()
  for (path in documents) {
    lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
    if (grepl("^sweeps[.]", basename(path))) {
      start <- grep("^## Compiled Accounting And Workers\\s*$", lines)
      if (length(start) == 1L) {
        later <- grep("^## ", lines)
        end <- later[later > start][1L]
        if (is.na(end)) end <- length(lines) + 1L
        lines[start:(end - 1L)] <- ""
      }
    }
    for (term in names(terms)) {
      hit <- grep(terms[[term]], lines, perl = TRUE)
      out <- c(out, sprintf("%s:%d %s", basename(path), hit, term))
    }
  }
  out
}

testthat::test_that("[LTB-0128] user articles use no maintainer shorthand", {
  root <- testthat::test_path("..", "..")
  testthat::skip_if_not(file.exists(file.path(root, "README.Rmd")), "article sources not available during installed-package tests")
  testthat::expect_identical(ledgr_doc_maintainer_terms(root), character())
})
