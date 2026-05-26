testthat::test_that("demo SMA crossover strategy is Tier 1", {
  strategy <- ledgr_demo_sma_crossover_strategy()

  preflight <- ledgr_strategy_preflight(strategy)
  testthat::expect_identical(preflight$tier, "tier_1")
  testthat::expect_true(preflight$allowed)
  testthat::expect_identical(preflight$unresolved_symbols, character())
})

testthat::test_that("demo SMA crossover strategy holds through warmup", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:5)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  features <- ledgr_feature_map(
    fast = ledgr_ind_sma(ledgr_param("fast_n")),
    slow = ledgr_ind_sma(ledgr_param("slow_n"))
  )
  pulse <- ledgr_pulse_snapshot(
    snapshot = snapshot,
    universe = "AAA",
    ts_utc = "2020-01-02T00:00:00Z",
    features = features,
    feature_params = list(fast_n = 2L, slow_n = 4L)
  )
  on.exit(close(pulse), add = TRUE)

  strategy <- ledgr_demo_sma_crossover_strategy()
  targets <- strategy(pulse, list(qty = 10, threshold = 0))

  testthat::expect_identical(targets, c(AAA = 0))
})

testthat::test_that("demo SMA crossover strategy runs and keeps qty zero baseline flat", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:7)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  features <- ledgr_feature_map(
    fast = ledgr_ind_sma(ledgr_param("fast_n")),
    slow = ledgr_ind_sma(ledgr_param("slow_n"))
  )
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = ledgr_demo_sma_crossover_strategy(),
    features = features
  )

  active <- ledgr_run(
    exp,
    feature_params = list(fast_n = 2L, slow_n = 4L),
    params = list(qty = 1, threshold = -0.001),
    run_id = "demo_sma_active"
  )
  on.exit(close(active), add = TRUE)

  flat <- ledgr_run(
    exp,
    feature_params = list(fast_n = 2L, slow_n = 4L),
    params = list(qty = 0, threshold = -0.001),
    run_id = "demo_sma_flat"
  )
  on.exit(close(flat), add = TRUE)

  testthat::expect_gt(nrow(ledgr_results(active, what = "fills")), 0L)
  testthat::expect_identical(nrow(ledgr_results(flat, what = "fills")), 0L)
})

testthat::test_that("demo SMA crossover strategy sweeps feature and strategy grids", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:7)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  features <- ledgr_feature_map(
    fast = ledgr_ind_sma(ledgr_param("fast_n")),
    slow = ledgr_ind_sma(ledgr_param("slow_n"))
  )
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = ledgr_demo_sma_crossover_strategy(),
    features = features
  )
  grid <- ledgr_grid_cross(
    features = ledgr_feature_grid(fast_n = 2L, slow_n = 4L),
    strategy = ledgr_strategy_grid(threshold = -0.001, qty = c(1, 0))
  )

  out <- ledgr_sweep(exp, grid)

  testthat::expect_true(all(out$status == "DONE"))
  testthat::expect_identical(out$params[[1]], list(threshold = -0.001, qty = 1))
  testthat::expect_identical(out$feature_params[[1]], list(fast_n = 2L, slow_n = 4L))
  testthat::expect_match(out$provenance[[1]]$alias_map_hash, "^[0-9a-f]{64}$")
})

testthat::test_that("demo SMA crossover strategy fails through active alias classes", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:5)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  no_alias_exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = ledgr_demo_sma_crossover_strategy(),
    features = list(ledgr_ind_sma(2))
  )
  testthat::expect_error(
    ledgr_run(no_alias_exp, params = list(qty = 1, threshold = 0), run_id = "demo_no_alias"),
    class = "ledgr_no_active_alias_map"
  )

  wrong_alias_exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = ledgr_demo_sma_crossover_strategy(),
    features = ledgr_feature_map(
      quick = ledgr_ind_sma(ledgr_param("fast_n")),
      slow = ledgr_ind_sma(ledgr_param("slow_n"))
    )
  )
  testthat::expect_error(
    ledgr_run(
      wrong_alias_exp,
      feature_params = list(fast_n = 2L, slow_n = 4L),
      params = list(qty = 1, threshold = 0),
      run_id = "demo_missing_fast_alias"
    ),
    class = "ledgr_unknown_active_alias"
  )
})
