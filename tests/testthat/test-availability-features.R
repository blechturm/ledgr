testthat::test_that("strict features expose whole-feed gaps and recover by window", {
  snapshot <- availability_runtime_fixture(days = 5L, bar_days = c(1L, 2L, 4L, 5L))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    history <- if (is.null(ctx$state_prev$history)) list() else ctx$state_prev$history
    values <- c(
      sma = ctx$feature("AAA", "sma_2"),
      ret = ctx$feature("AAA", "return_1")
    )
    history[[length(history) + 1L]] <- ifelse(is.na(values), "NA", format(values, digits = 17))
    list(targets = ctx$hold(), state_update = list(history = history))
  }
  exp <- ledgr_experiment(
    snapshot,
    strategy,
    features = list(ledgr_ind_sma(2), ledgr_ind_returns(1)),
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero()
  )
  ledgr_feature_cache_clear()
  bt <- ledgr_run(exp)
  on.exit(close(bt), add = TRUE)
  encoded <- do.call(rbind, availability_last_state(bt)$history)
  values <- apply(encoded, 2L, function(x) suppressWarnings(as.numeric(x)))
  # Day 3 has no bar, so the strict window stays unmet on days 3 and 4. The
  # fifth session restores a complete two-bar window (104, 105) and both
  # features recover.
  testthat::expect_equal(values[, "sma"], c(NA, 101.5, NA, NA, 104.5))
  testthat::expect_equal(values[, "ret"], c(NA, 1 / 101, NA, NA, 1 / 104))
  cache_keys <- ls(ledgr:::.ledgr_feature_cache_registry, all.names = TRUE)
  testthat::expect_length(cache_keys, 2L)

  cached <- ledgr_run(exp)
  on.exit(close(cached), add = TRUE)
  testthat::expect_identical(
    availability_last_state(cached)$history,
    availability_last_state(bt)$history
  )
  testthat::expect_identical(
    ls(ledgr:::.ledgr_feature_cache_registry, all.names = TRUE),
    cache_keys
  )
})

testthat::test_that("strict scalar series and active identity contracts agree", {
  bars <- data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3,
    instrument_id = "AAA",
    open = 100:103,
    high = 101:104,
    low = 99:102,
    close = 100:103,
    volume = 1000,
    gap_type = c("OBSERVED", "OBSERVED", "MISSING_EXPECTED_SESSION", "OBSERVED"),
    is_synthetic = FALSE
  )
  bars[3L, c("open", "high", "low", "close", "volume")] <- NA_real_
  sma <- ledgr_ind_sma(2)
  dense_sma <- sma
  dense_sma$gap_contract <- NULL
  testthat::expect_equal(
    ledgr_compute_feature_series_strict(bars, sma),
    c(NA, 100.5, NA, NA)
  )
  testthat::expect_identical(
    ledgr_indicator_fingerprint(sma),
    ledgr_indicator_fingerprint(dense_sma)
  )
  testthat::expect_identical(
    ledgr_feature_engine_version(),
    ledgr_feature_engine_version(FALSE)
  )
  testthat::expect_false(identical(
    ledgr_feature_engine_version(),
    ledgr_feature_engine_version(TRUE)
  ))

  disagreeing <- ledgr_indicator(
    "disagreeing",
    function(window) mean(window$close),
    requires_bars = 2,
    series_fn = function(bars, params) rep(0, nrow(bars)),
    gap_contract = "strict_window"
  )
  testthat::expect_error(
    ledgr_compute_feature_series_strict(bars[1:2, , drop = FALSE], disagreeing),
    class = "ledgr_indicator_gap_parity"
  )
})

testthat::test_that("unsupported active indicators fail during experiment validation", {
  snapshot <- availability_runtime_fixture()
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  unsupported <- ledgr_indicator(
    "unsupported",
    function(window) mean(window$close),
    requires_bars = 2
  )
  testthat::expect_error(
    ledgr_experiment(
      snapshot,
      function(ctx, params) stop("strategy should not run"),
      features = list(unsupported),
      valuation_policy = ledgr_valuation_stale(1),
      cost_model = ledgr_cost_zero()
    ),
    class = "ledgr_indicator_gap_unsupported"
  )
})

testthat::test_that("future facts isolate cache identity without changing earlier features", {
  future_status <- ledgr_facts_trading_status(data.frame(
    instrument_id = "AAA",
    effective_from = as.POSIXct("2020-02-01", tz = "UTC"),
    knowledge_time = as.POSIXct("2020-02-01", tz = "UTC"),
    status = "halted",
    source = "future",
    precedence = 1L
  ))
  snapshots <- list(
    availability_runtime_fixture(),
    availability_runtime_fixture(status = future_status)
  )
  on.exit(lapply(snapshots, ledgr_snapshot_close), add = TRUE)
  strategy <- function(ctx, params) {
    history <- if (is.null(ctx$state_prev$history)) list() else ctx$state_prev$history
    value <- ctx$feature("AAA", "sma_2")
    history[[length(history) + 1L]] <- if (is.na(value)) "NA" else format(value, digits = 17)
    list(targets = ctx$hold(), state_update = list(history = history))
  }
  ledgr_feature_cache_clear()
  runs <- lapply(snapshots, function(snapshot) {
    ledgr_run(ledgr_experiment(
      snapshot,
      strategy,
      features = list(ledgr_ind_sma(2)),
      valuation_policy = ledgr_valuation_stale(1),
      cost_model = ledgr_cost_zero()
    ))
  })
  on.exit(lapply(runs, close), add = TRUE)
  testthat::expect_identical(
    availability_last_state(runs[[1L]])$history,
    availability_last_state(runs[[2L]])$history
  )
  testthat::expect_length(
    ls(ledgr:::.ledgr_feature_cache_registry, all.names = TRUE),
    2L
  )
})
