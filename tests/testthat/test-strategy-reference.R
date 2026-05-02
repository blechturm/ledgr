testthat::test_that("signal_return reads registered return features", {
  ts <- ledgr_utc("2020-01-03")
  bars <- data.frame(
    ts_utc = rep(ts, 2),
    instrument_id = c("AAA", "BBB"),
    open = c(100, 100),
    high = c(100, 100),
    low = c(100, 100),
    close = c(100, 100),
    volume = c(1000, 1000)
  )
  features <- data.frame(
    ts_utc = rep(ts, 2),
    instrument_id = c("AAA", "BBB"),
    feature_name = rep("return_2", 2),
    feature_value = c(0.02, NA_real_)
  )
  ctx <- ledgr:::ledgr_pulse_context(
    "helper-run",
    ts,
    c("AAA", "BBB"),
    bars,
    features = features,
    cash = 1000,
    equity = 1000
  )

  signal <- signal_return(ctx, lookback = 2)
  testthat::expect_s3_class(signal, "ledgr_signal")
  testthat::expect_identical(as.numeric(signal), c(0.02, NA_real_))
  testthat::expect_identical(names(signal), c("AAA", "BBB"))

  testthat::expect_error(
    signal_return(ctx, lookback = 3),
    class = "ledgr_unknown_feature_id"
  )
})

testthat::test_that("select_top_n handles NA, partial, empty, and ties", {
  signal <- ledgr_signal(c(BBB = 0.3, AAA = 0.3, CCC = NA_real_, DDD = 0.1))

  selected <- select_top_n(signal, 2)
  testthat::expect_s3_class(selected, "ledgr_selection")
  testthat::expect_identical(unclass(selected), c(BBB = TRUE, AAA = TRUE, CCC = FALSE, DDD = FALSE))

  testthat::expect_warning(
    partial <- select_top_n(signal, 4),
    class = "ledgr_partial_selection"
  )
  testthat::expect_identical(unclass(partial), c(BBB = TRUE, AAA = TRUE, CCC = FALSE, DDD = TRUE))

  empty_signal <- ledgr_signal(c(AAA = NA_real_, BBB = NA_real_))
  testthat::expect_warning(
    empty <- select_top_n(empty_signal, 1),
    class = "ledgr_empty_selection"
  )
  testthat::expect_s3_class(empty, "ledgr_selection")
  testthat::expect_identical(length(empty), 0L)
})

testthat::test_that("weight_equal creates long-only equal weights", {
  selection <- ledgr_selection(c(AAA = TRUE, BBB = FALSE, CCC = TRUE))
  weights <- weight_equal(selection)

  testthat::expect_s3_class(weights, "ledgr_weights")
  testthat::expect_identical(unclass(weights), c(AAA = 0.5, CCC = 0.5))

  empty <- weight_equal(ledgr_selection(c(AAA = FALSE, BBB = FALSE)))
  testthat::expect_s3_class(empty, "ledgr_weights")
  testthat::expect_identical(length(empty), 0L)
})

testthat::test_that("target_rebalance builds full-universe targets and rejects invalid weights", {
  ts <- ledgr_utc("2020-01-03")
  bars <- data.frame(
    ts_utc = rep(ts, 3),
    instrument_id = c("AAA", "BBB", "CCC"),
    open = c(100, 50, 25),
    high = c(100, 50, 25),
    low = c(100, 50, 25),
    close = c(100, 50, NA),
    volume = c(1000, 1000, 1000)
  )
  ctx <- ledgr:::ledgr_pulse_context(
    "helper-run",
    ts,
    c("AAA", "BBB", "CCC"),
    bars,
    cash = 1000,
    equity = 1000
  )

  target <- target_rebalance(ledgr_weights(c(AAA = 0.5, BBB = 0.25)), ctx)
  testthat::expect_s3_class(target, "ledgr_target")
  testthat::expect_identical(unclass(target), c(AAA = 5, BBB = 5, CCC = 0))

  empty <- target_rebalance(ledgr_weights(numeric()), ctx)
  testthat::expect_identical(unclass(empty), c(AAA = 0, BBB = 0, CCC = 0))

  testthat::expect_warning(
    bad_price <- target_rebalance(ledgr_weights(c(CCC = 0.25)), ctx),
    class = "ledgr_invalid_target_price"
  )
  testthat::expect_identical(unclass(bad_price), c(AAA = 0, BBB = 0, CCC = 0))

  testthat::expect_error(
    target_rebalance(ledgr_weights(c(AAA = -0.1)), ctx),
    class = "ledgr_negative_weights"
  )
  testthat::expect_error(
    target_rebalance(ledgr_weights(c(AAA = 0.8, BBB = 0.3)), ctx),
    class = "ledgr_levered_weights"
  )
  testthat::expect_error(
    target_rebalance(ledgr_weights(c(ZZZ = 0.1)), ctx),
    class = "ledgr_invalid_strategy_helper"
  )
})

testthat::test_that("reference helper pipeline runs through ledgr_run", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  bars <- data.frame(
    ts_utc = rep(ledgr_utc(c("2020-01-01", "2020-01-02", "2020-01-03", "2020-01-04")), each = 2),
    instrument_id = rep(c("AAA", "BBB"), 4),
    open = c(100, 100, 105, 99, 110, 98, 115, 97),
    high = c(100, 100, 105, 99, 110, 98, 115, 97),
    low = c(100, 100, 105, 99, 110, 98, 115, 97),
    close = c(100, 100, 105, 99, 110, 98, 115, 97),
    volume = rep(1000, 8)
  )
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    signal <- signal_return(ctx, lookback = params$lookback)
    selection <- suppressWarnings(select_top_n(signal, params$n))
    weights <- weight_equal(selection)
    target_rebalance(weights, ctx, equity_fraction = params$equity_fraction)
  }
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    features = list(ledgr_ind_returns(1)),
    opening = ledgr_opening(cash = 1000)
  )
  bt <- ledgr_run(exp, params = list(lookback = 1, n = 1, equity_fraction = 0.5), run_id = "helper-reference")
  on.exit(close(bt), add = TRUE)

  fills <- ledgr_results(bt, what = "fills")
  testthat::expect_gt(nrow(fills), 0L)
  testthat::expect_true(all(fills$instrument_id %in% c("AAA", "BBB")))
})

testthat::test_that("no sweep or tune APIs are exported with strategy helpers", {
  exports <- getNamespaceExports("ledgr")
  testthat::expect_false(any(c("ledgr_sweep", "ledgr_tune", "ledgr_precompute_features") %in% exports))
})
