testthat::test_that("ledgr_run resolves active aliases from feature_params", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:5)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  features <- ledgr_feature_map(
    fast = ledgr_ind_sma(ledgr_param("fast_n")),
    slow = ledgr_ind_sma(ledgr_param("slow_n"))
  )
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    x <- ctx$features("AAA")
    if (passed_warmup(x) && x[["fast"]] >= x[["slow"]]) {
      targets["AAA"] <- params$qty
    }
    targets
  }
  exp <- ledgr_experiment(snapshot = snapshot, strategy = strategy, features = features)

  bt <- ledgr_run(
    exp,
    params = list(qty = 1),
    feature_params = list(fast_n = 2L, slow_n = 3L),
    run_id = "active-alias-run"
  )
  on.exit(close(bt), add = TRUE)

  testthat::expect_match(bt$config$alias_map_hash, "^[0-9a-f]{64}$")
  testthat::expect_identical(
    ledgr:::ledgr_alias_map_from_json(bt$config$alias_map_json),
    c(fast = "sma_2", slow = "sma_3")
  )
  testthat::expect_identical(bt$config$strategy_params, list(qty = 1))
  testthat::expect_identical(bt$config$feature_params, list(fast_n = 2L, slow_n = 3L))
})

testthat::test_that("ctx features without active aliases fails loudly", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    ctx$features("AAA")
    ctx$flat()
  }
  exp <- ledgr_experiment(snapshot = snapshot, strategy = strategy, features = list(ledgr_ind_sma(2)))

  testthat::expect_error(
    ledgr_run(exp, run_id = "missing-active-alias-map"),
    class = "ledgr_no_active_alias_map"
  )
})

testthat::test_that("sweeps keep feature params separate from strategy params", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:5)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  features <- ledgr_feature_map(signal = ledgr_ind_sma(ledgr_param("n")))
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    x <- ctx$features("AAA")
    if (passed_warmup(x)) {
      targets["AAA"] <- params$qty
    }
    targets
  }
  exp <- ledgr_experiment(snapshot = snapshot, strategy = strategy, features = features)
  grid <- ledgr_grid_cross(
    features = ledgr_feature_grid(n = c(2L, 3L)),
    strategy = ledgr_strategy_grid(qty = c(1, 2))
  )

  out <- ledgr_sweep(exp, grid)
  candidate_features <- attr(out, "candidate_features")

  testthat::expect_true("feature_params" %in% names(out))
  testthat::expect_identical(out$params[[1]], list(qty = 1))
  testthat::expect_identical(out$feature_params[[1]], list(n = 2L))
  testthat::expect_identical(candidate_features$params[[1]], list(qty = 1))
  testthat::expect_identical(candidate_features$feature_params[[1]], list(n = 2L))
  testthat::expect_identical(candidate_features$alias_map[[1]], c(signal = "sma_2"))
  testthat::expect_identical(out$provenance[[1]]$alias_map_hash, candidate_features$alias_map_hash[[1]])
  testthat::expect_match(out$provenance[[1]]$alias_map_json, "signal", fixed = TRUE)
})

testthat::test_that("promotion replays active alias feature params", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:5)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  features <- ledgr_feature_map(signal = ledgr_ind_sma(ledgr_param("n")))
  strategy <- function(ctx, params) {
    x <- ctx$features("AAA")
    targets <- ctx$flat()
    if (passed_warmup(x)) {
      targets["AAA"] <- params$qty
    }
    targets
  }
  exp <- ledgr_experiment(snapshot = snapshot, strategy = strategy, features = features)
  grid <- ledgr_grid_cross(
    features = ledgr_feature_grid(n = 2L),
    strategy = ledgr_strategy_grid(qty = 1)
  )
  sweep <- ledgr_sweep(exp, grid)
  candidate <- ledgr_candidate(sweep, 1)

  bt <- ledgr_promote(exp, candidate, run_id = "promoted-active-alias")
  on.exit(close(bt), add = TRUE)

  testthat::expect_identical(bt$config$feature_params, list(n = 2L))
  testthat::expect_identical(bt$config$strategy_params, list(qty = 1))
  testthat::expect_identical(
    ledgr:::ledgr_alias_map_from_json(bt$config$alias_map_json),
    c(signal = "sma_2")
  )
  context <- ledgr_promotion_context(bt)
  testthat::expect_identical(
    context$selected_candidate$feature_params_json,
    as.character(canonical_json(list(n = 2L)))
  )
})

testthat::test_that("alias maps affect config identity independently of feature set identity", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) ctx$flat()

  build_config <- function(features) {
    exp <- ledgr_experiment(snapshot = snapshot, strategy = strategy, features = features)
    feature_result <- ledgr:::ledgr_experiment_materialize_feature_result(exp, list(), feature_params = list())
    ledgr:::ledgr_config(
      snapshot = snapshot,
      universe = exp$universe,
      strategy = exp$strategy,
      strategy_params = list(),
      feature_params = list(),
      backtest = ledgr:::ledgr_backtest_config(
        start = snapshot$metadata$start_date,
        end = snapshot$metadata$end_date,
        initial_cash = exp$opening$cash
      ),
      features = feature_result$features,
      alias_map = feature_result$alias_map,
      persist_features = exp$persist_features,
      execution_mode = exp$execution_mode,
      fill_model = exp$fill_model,
      db_path = snapshot$db_path,
      opening = exp$opening,
      seed = NULL
    )
  }

  cfg_fast <- build_config(ledgr_feature_map(fast = ledgr_ind_sma(2)))
  cfg_trend <- build_config(ledgr_feature_map(trend = ledgr_ind_sma(2)))
  fingerprints_fast <- vapply(cfg_fast$features$defs, `[[`, character(1), "fingerprint")
  fingerprints_trend <- vapply(cfg_trend$features$defs, `[[`, character(1), "fingerprint")

  testthat::expect_identical(
    ledgr:::ledgr_feature_set_hash(fingerprints_fast),
    ledgr:::ledgr_feature_set_hash(fingerprints_trend)
  )
  testthat::expect_false(identical(cfg_fast$alias_map_hash, cfg_trend$alias_map_hash))
  testthat::expect_false(identical(ledgr:::config_hash(cfg_fast), ledgr:::config_hash(cfg_trend)))
})
