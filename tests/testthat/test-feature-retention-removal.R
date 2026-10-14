# ledgr-test-file-profile: fast

testthat::test_that("deleted feature-retention surfaces cannot return", {
  root <- normalizePath(testthat::test_path("..", ".."), winslash = "/")
  r_files <- list.files(file.path(root, "R"), pattern = "[.]R$", full.names = TRUE)
  source <- paste(vapply(r_files, function(path) {
    paste(readLines(path, warn = FALSE), collapse = "\n")
  }, character(1)), collapse = "\n")
  deleted <- c(
    "\\.ledgr_feature_cache_registry",
    "ledgr_feature_cache_(clear|key|get|set)",
    "feature_cache_(hits|misses)",
    "persist_features",
    "features\\$persist",
    "CREATE TABLE features"
  )
  for (pattern in deleted) {
    testthat::expect_false(grepl(pattern, source, perl = TRUE), info = pattern)
  }

  namespace <- paste(readLines(file.path(root, "NAMESPACE"), warn = FALSE), collapse = "\n")
  testthat::expect_false(grepl("ledgr_feature_cache", namespace, fixed = TRUE))
  testthat::expect_false(file.exists(file.path(root, "man", "ledgr_feature_cache_clear.Rd")))
  pkgdown <- paste(readLines(file.path(root, "_pkgdown.yml"), warn = FALSE), collapse = "\n")
  testthat::expect_false(grepl("ledgr_feature_cache_clear", pkgdown, fixed = TRUE))

  current_doc_paths <- c(
    file.path(root, "_pkgdown.yml"),
    file.path(root, "README.md"),
    file.path(root, "README.Rmd"),
    file.path(root, "inst", "design", "contracts.md"),
    file.path(root, "tests", "claims.yml"),
    list.files(file.path(root, "man"), pattern = "[.]Rd$", full.names = TRUE),
    list.files(
      file.path(root, "vignettes"),
      pattern = "[.](Rmd|qmd|md)$",
      full.names = TRUE,
      recursive = TRUE
    )
  )
  current_docs <- paste(vapply(current_doc_paths, function(path) {
    paste(readLines(path, warn = FALSE), collapse = "\n")
  }, character(1)), collapse = "\n")
  retired_current_claims <- c(
    "ledgr_feature_cache_clear",
    "ledgr_clear_feature_cache",
    "feature_cache_hits",
    "feature_cache_misses",
    "persist_features",
    "Persisted feature rows"
  )
  for (claim in retired_current_claims) {
    testthat::expect_false(grepl(claim, current_docs, fixed = TRUE), info = claim)
  }

  news <- paste(readLines(file.path(root, "NEWS.md"), warn = FALSE), collapse = "\n")
  testthat::expect_match(news, "Removed the process-local feature cache", fixed = TRUE)
  testthat::expect_match(news, "`ledgr_clear_feature_cache()` | `ledgr_feature_cache_clear()`", fixed = TRUE)
  testthat::expect_match(news, "session-local feature cache JSON+hash keys", fixed = TRUE)
  testthat::expect_match(news, "feature-cache hit/miss counts", fixed = TRUE)
  testthat::expect_match(news, "Added a session-scoped feature cache", fixed = TRUE)

  testthat::expect_false("persist_features" %in% names(formals(ledgr_experiment)))
  testthat::expect_false("persist_features" %in% names(formals(ledgr_backtest)))
  testthat::expect_error(
    ledgr_experiment(persist_features = TRUE),
    "unused argument"
  )
  testthat::expect_error(
    ledgr_backtest(persist_features = TRUE),
    "unused argument"
  )
})

testthat::test_that("changed captures recompute values and repeated captures stay exact", {
  bars <- data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3,
    instrument_id = "AAA",
    open = 100:103,
    high = 101:104,
    low = 99:102,
    close = 100:103,
    volume = 1000,
    stringsAsFactors = FALSE
  )
  snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    value <- ctx$feature("AAA", "captured_value")
    if (is.finite(value) && value > params$threshold) targets[["AAA"]] <- 1
    targets
  }
  make_experiment <- function(scale) {
    ledgr_indicator_remove("captured_value", missing_ok = TRUE)
    indicator <- ledgr_indicator(
      id = "captured_value",
      fn = function(window) tail(window$close, 1L) * scale,
      series_fn = function(series, params) series$close * scale,
      requires_bars = 1L
    )
    ledgr_experiment(
      snapshot,
      strategy,
      features = list(indicator),
      cost_model = ledgr_cost_zero()
    )
  }
  run <- function(scale, run_id) {
    result <- ledgr_run(
      make_experiment(scale),
      params = list(threshold = 150),
      run_id = run_id
    )
    on.exit(close(result), add = TRUE)
    stored <- DBI::dbGetQuery(
      ledgr:::get_connection(snapshot),
      "SELECT config_json FROM runs WHERE run_id = ?",
      params = list(run_id)
    )
    stored_config <- ledgr:::ledgr_json_read_config(stored$config_json[[1L]])
    testthat::expect_false("persist" %in% names(result$config$features))
    testthat::expect_false("persist" %in% names(stored_config$features))
    list(
      fills = ledgr_results(result, "fills")[
        c("ts_utc", "instrument_id", "side", "qty", "price")
      ],
      equity = ledgr_results(result, "equity")[
        c("ts_utc", "cash", "positions_value", "equity")
      ],
      config_hash = ledgr_run_info(snapshot, run_id)$config_hash[[1L]]
    )
  }

  one <- run(1, "captured-one")
  two_a <- run(2, "captured-two-a")
  two_b <- run(2, "captured-two-b")

  testthat::expect_identical(nrow(one$fills), 0L)
  testthat::expect_gt(nrow(two_a$fills), 0L)
  testthat::expect_false(identical(one$config_hash, two_a$config_hash))
  testthat::expect_identical(two_a$config_hash, two_b$config_hash)
  testthat::expect_identical(two_a$fills, two_b$fills)
  testthat::expect_identical(two_a$equity, two_b$equity)
})
