testthat::test_that("ledgr_feature_map carries aliases, indicators, and feature IDs", {
  sma <- ledgr_ind_sma(2)
  ret <- ledgr_ind_returns(3)

  features <- ledgr_feature_map(sma_fast = sma, ret_short = ret)

  testthat::expect_s3_class(features, "ledgr_feature_map")
  testthat::expect_identical(features$aliases, c("sma_fast", "ret_short"))
  testthat::expect_identical(names(features$indicators), c("sma_fast", "ret_short"))
  testthat::expect_identical(
    features$feature_ids,
    c(sma_fast = "sma_2", ret_short = "return_3")
  )
  testthat::expect_identical(ledgr_feature_id(features), features$feature_ids)

  printed <- utils::capture.output(print(features))
  testthat::expect_true(any(grepl("ledgr_feature_map", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("sma_fast -> sma_2", printed, fixed = TRUE)))
})

testthat::test_that("ledgr_feature_map validates aliases and mapped values", {
  sma <- ledgr_ind_sma(2)

  testthat::expect_error(
    ledgr_feature_map(),
    class = "ledgr_invalid_feature_map"
  )
  testthat::expect_error(
    ledgr_feature_map(sma),
    class = "ledgr_invalid_feature_map"
  )
  testthat::expect_error(
    do.call(ledgr_feature_map, stats::setNames(list(sma), "")),
    class = "ledgr_invalid_feature_map"
  )
  testthat::expect_error(
    do.call(ledgr_feature_map, stats::setNames(list(sma), NA_character_)),
    class = "ledgr_invalid_feature_map"
  )
  testthat::expect_error(
    do.call(ledgr_feature_map, stats::setNames(list(sma, ledgr_ind_returns(2)), c("x", "x"))),
    class = "ledgr_invalid_feature_map"
  )
  testthat::expect_error(
    do.call(ledgr_feature_map, stats::setNames(list(sma), "not valid")),
    class = "ledgr_invalid_feature_map"
  )
  testthat::expect_error(
    ledgr_feature_map(sma = "bad"),
    class = "ledgr_invalid_feature_map"
  )
})

testthat::test_that("ledgr_feature_map rejects duplicate resolved feature IDs", {
  testthat::expect_error(
    ledgr_feature_map(a = ledgr_ind_sma(2), b = ledgr_ind_sma(2)),
    "Duplicate feature IDs are not allowed: sma_2",
    fixed = TRUE,
    class = "ledgr_duplicate_feature_id"
  )
})

testthat::test_that("ledgr_experiment accepts feature maps and preserves list behavior", {
  bars <- ledgr_test_make_bars(c("AAA", "BBB"), as.Date("2020-01-01") + 0:4)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    ctx$flat()
  }
  sma <- ledgr_ind_sma(2)
  ret <- ledgr_ind_returns(3)
  feature_list <- list(sma, ret)
  feature_map <- ledgr_feature_map(sma_alias = sma, ret_alias = ret)

  exp_list <- ledgr_experiment(snapshot = snapshot, strategy = strategy, features = feature_list)
  exp_map <- ledgr_experiment(snapshot = snapshot, strategy = strategy, features = feature_map)

  testthat::expect_identical(exp_list$features_mode, "list")
  testthat::expect_identical(exp_map$features_mode, "feature_map")
  testthat::expect_identical(
    ledgr_feature_id(ledgr_experiment_materialize_features(exp_map, list())),
    ledgr_feature_id(feature_list)
  )
  testthat::expect_identical(
    ledgr_feature_id(ledgr_experiment_materialize_features(exp_list, list())),
    ledgr_feature_id(feature_list)
  )
})

testthat::test_that("feature maps returned by feature functions materialize to indicator lists", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    ctx$flat()
  }
  feature_fn <- function(params) {
    ledgr_feature_map(ret = ledgr_ind_returns(params$lookback))
  }

  exp <- ledgr_experiment(snapshot = snapshot, strategy = strategy, features = feature_fn)
  features <- ledgr_experiment_materialize_features(exp, list(lookback = 3))

  testthat::expect_identical(exp$features_mode, "function")
  testthat::expect_true(is.list(features))
  testthat::expect_false(inherits(features, "ledgr_feature_map"))
  testthat::expect_identical(ledgr_feature_id(features), "return_3")
})

testthat::test_that("feature maps are copied into experiments at construction", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    ctx$flat()
  }
  features <- ledgr_feature_map(signal = ledgr_ind_sma(2))

  exp <- ledgr_experiment(snapshot = snapshot, strategy = strategy, features = features)
  features$indicators[[1]] <- ledgr_ind_returns(3)
  features$feature_ids[["signal"]] <- "return_3"

  materialized <- ledgr_experiment_materialize_features(exp, list())
  testthat::expect_identical(ledgr_feature_id(materialized), "sma_2")
  testthat::expect_identical(exp$features$feature_ids, c(signal = "sma_2"))
})

testthat::test_that("feature maps preserve feature-related config hash identity", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    ctx$flat()
  }
  sma <- ledgr_ind_sma(2)
  ret <- ledgr_ind_returns(3)
  feature_list <- list(sma, ret)
  feature_map <- ledgr_feature_map(sma_alias = sma, ret_alias = ret)

  exp_list <- ledgr_experiment(snapshot = snapshot, strategy = strategy, features = feature_list)
  exp_map <- ledgr_experiment(snapshot = snapshot, strategy = strategy, features = feature_map)

  cfg_list <- ledgr_config(
    snapshot = snapshot,
    universe = exp_list$universe,
    strategy = exp_list$strategy,
    backtest = ledgr_backtest_config(
      start = snapshot$metadata$start_date,
      end = snapshot$metadata$end_date,
      initial_cash = exp_list$opening$cash
    ),
    features = ledgr_experiment_materialize_features(exp_list, list()),
    persist_features = exp_list$persist_features,
    execution_mode = exp_list$execution_mode,
    fill_model = exp_list$fill_model,
    db_path = snapshot$db_path,
    opening = exp_list$opening,
    seed = NULL
  )
  cfg_map <- ledgr_config(
    snapshot = snapshot,
    universe = exp_map$universe,
    strategy = exp_map$strategy,
    backtest = ledgr_backtest_config(
      start = snapshot$metadata$start_date,
      end = snapshot$metadata$end_date,
      initial_cash = exp_map$opening$cash
    ),
    features = ledgr_experiment_materialize_features(exp_map, list()),
    persist_features = exp_map$persist_features,
    execution_mode = exp_map$execution_mode,
    fill_model = exp_map$fill_model,
    db_path = snapshot$db_path,
    opening = exp_map$opening,
    seed = NULL
  )

  testthat::expect_identical(config_hash(cfg_map), config_hash(cfg_list))
})
