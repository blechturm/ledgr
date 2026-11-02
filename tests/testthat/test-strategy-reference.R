testthat::test_that("ledgr_signal_return reads registered return features", {
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

  signal <- ledgr_signal_return(ctx, lookback = 2)
  testthat::expect_s3_class(signal, "ledgr_signal")
  testthat::expect_identical(as.numeric(signal), c(0.02, NA_real_))
  testthat::expect_identical(names(signal), c("AAA", "BBB"))

  testthat::expect_error(
    ledgr_signal_return(ctx, lookback = 3),
    class = "ledgr_unknown_context_field"
  )
})

testthat::test_that("[LTB-0096] ledgr_select_top makes short rankings explicit", {
  score <- c(BBB = 0.3, AAA = 0.3, CCC = NA_real_, DDD = 0.1)

  selected <- ledgr_select_top(score, n = 2)
  testthat::expect_identical(selected, c("AAA", "BBB"))
  testthat::expect_identical(ledgr_select_top(score, n = 4), c("AAA", "BBB", "DDD"))
  testthat::expect_identical(
    ledgr_select_top(score, fraction = 0.5),
    c("AAA", "BBB")
  )

  empty <- ledgr_select_top(c(AAA = NA_real_, BBB = NA_real_), n = 1)
  testthat::expect_identical(empty, character())

  weights <- ledgr_weight_equal(empty)
  testthat::expect_identical(weights, stats::setNames(numeric(), character()))

  ts <- ledgr_utc("2020-01-03")
  bars <- data.frame(
    ts_utc = rep(ts, 2),
    instrument_id = c("AAA", "BBB"),
    open = c(100, 50),
    high = c(100, 50),
    low = c(100, 50),
    close = c(100, 50),
    volume = c(1000, 1000)
  )
  ctx <- ledgr:::ledgr_pulse_context(
    "helper-run",
    ts,
    c("AAA", "BBB"),
    bars,
    cash = 1000,
    equity = 1000
  )
  target <- ledgr_target_rebalance(ctx, weights = weights, invest_fraction = 0.5)
  testthat::expect_s3_class(target, "ledgr_target")
  testthat::expect_identical(as.numeric(target), c(0, 0))
  testthat::expect_identical(names(target), c("AAA", "BBB"))
  testthat::expect_identical(attr(target, "origin")$invest_fraction, 0.5)
})

testthat::test_that("ledgr_weight_equal creates long-only equal weights", {
  selection <- c("AAA", "CCC")
  weights <- ledgr_weight_equal(selection)

  testthat::expect_identical(weights, c(AAA = 0.5, CCC = 0.5))

  empty <- ledgr_weight_equal(character())
  testthat::expect_identical(empty, stats::setNames(numeric(), character()))
})

testthat::test_that("ledgr_target_rebalance builds full-universe targets and rejects invalid weights", {
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

  target <- ledgr_target_rebalance(ctx, weights = c(AAA = 0.5, BBB = 0.25))
  testthat::expect_s3_class(target, "ledgr_target")
  testthat::expect_identical(stats::setNames(as.numeric(target), names(target)), c(AAA = 5, BBB = 5, CCC = 0))

  empty <- ledgr_target_rebalance(ctx)
  testthat::expect_identical(stats::setNames(as.numeric(empty), names(empty)), c(AAA = 0, BBB = 0, CCC = 0))

  testthat::expect_no_warning(
    bad_price <- ledgr_target_rebalance(ctx, weights = c(CCC = 0.25))
  )
  testthat::expect_identical(as.numeric(bad_price), c(0, 0, 0))
  testthat::expect_identical(names(bad_price), c("AAA", "BBB", "CCC"))
  testthat::expect_identical(attr(bad_price, "sizing_skipped", exact = TRUE), "CCC")

  testthat::expect_error(
    ledgr_target_rebalance(ctx, weights = c(AAA = -0.1)),
    class = "ledgr_invalid_strategy_type"
  )
  testthat::expect_error(
    ledgr_target_rebalance(ctx, weights = c(AAA = 0.8, BBB = 0.3)),
    class = "ledgr_invalid_strategy_type"
  )
  testthat::expect_error(
    ledgr_target_rebalance(ctx, weights = c(ZZZ = 0.1)),
    class = "ledgr_invalid_strategy_type"
  )
})

testthat::test_that("[LTB-0066] strategy helpers consume only vector accessors", {
  ts <- ledgr_utc("2020-01-03")
  bars <- data.frame(
    ts_utc = rep(ts, 2),
    instrument_id = c("AAA", "BBB"),
    open = c(100, 50),
    high = c(100, 50),
    low = c(100, 50),
    close = c(100, 50),
    volume = c(1000, 1000)
  )
  features <- data.frame(
    ts_utc = rep(ts, 2),
    instrument_id = c("AAA", "BBB"),
    feature_name = rep("return_2", 2),
    feature_value = c(0.02, 0.01)
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
  signal <- ledgr_signal_return(ctx, lookback = 2)
  weights <- ledgr_weight_equal(ledgr_select_top(signal, n = 1))
  target <- ledgr_target_rebalance(ctx, weights = weights, invest_fraction = 0.5)

  testthat::expect_identical(as.numeric(signal), c(0.02, 0.01))
  testthat::expect_identical(as.numeric(target), c(5, 0))
  testthat::expect_identical(names(target), c("AAA", "BBB"))

  empty <- ledgr_target_rebalance(ctx)
  all_names <- ledgr_target_rebalance(
    ctx,
    weights = c(AAA = 0.5, BBB = 0.5)
  )
  testthat::expect_identical(as.numeric(empty), c(0, 0))
  testthat::expect_identical(as.numeric(all_names), c(5, 10))
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("[LTB-0092] context helper pipeline agrees across run and sweep", {
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
    signal <- ledgr_signal(
      ctx,
      values = ctx[[paste0("return_", params$lookback)]]
    )
    selection <- ledgr_select_top(signal, n = params$n)
    weights <- ledgr_weight_equal(selection)
    ledgr_target_rebalance(ctx, weights = weights, invest_fraction = params$equity_fraction)
  }
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    features = list(ledgr_ind_returns(2)),
    opening = ledgr_opening(cash = 1000),
    cost_model = ledgr_cost_zero()
  )
  bt <- ledgr_run(exp, params = list(lookback = 2, n = 1, equity_fraction = 0.5), run_id = "helper-reference")
  on.exit(close(bt), add = TRUE)
  sweep <- ledgr_sweep(
    exp,
    ledgr_grid_named(candidate = list(strategy = list(
      lookback = 2,
      n = 1,
      equity_fraction = 0.5
    )))
  )

  fills <- ledgr_results(bt, what = "fills")
  equity <- ledgr_results(bt, what = "equity")
  testthat::expect_gt(nrow(fills), 0L)
  testthat::expect_true(all(fills$instrument_id %in% c("AAA", "BBB")))
  testthat::expect_identical(sweep$status, "DONE")
  testthat::expect_equal(
    sweep$final_equity[[1L]],
    equity$equity[[nrow(equity)]],
    tolerance = 1e-12
  )
})

testthat::test_that("tune execution API is not exported with strategy helpers", {
  exports <- getNamespaceExports("ledgr")
  testthat::expect_true("ledgr_sweep" %in% exports)
  testthat::expect_false("ledgr_tune" %in% exports)
})
