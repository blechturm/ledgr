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
    "change the bundle prefix",
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

testthat::test_that("ledgr_feature_map duplicate bundle aliases suggest prefix changes", {
  testthat::skip_if_not_installed("TTR")

  bundle <- ledgr_ind_ttr_outputs("BBands", input = "close", outputs = c("dn", "up"), prefix = "same", n = 20)
  err <- rlang::catch_cnd(ledgr_feature_map(left = bundle, right = bundle))
  testthat::expect_s3_class(err, "ledgr_invalid_feature_map")
  testthat::expect_match(conditionMessage(err), "generated feature ID", fixed = TRUE)
  testthat::expect_match(conditionMessage(err), "change the bundle prefix", fixed = TRUE)
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

  exp_list <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    features = feature_list,
    cost_model = ledgr_cost_zero()
  )
  exp_map <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    features = feature_map,
    cost_model = ledgr_cost_zero()
  )

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

  exp <- ledgr_experiment(snapshot = snapshot, strategy = strategy, features = feature_fn, cost_model = ledgr_cost_zero())
  features <- ledgr_experiment_materialize_features(exp, list(lookback = 3))

  testthat::expect_identical(exp$features_mode, "function")
  testthat::expect_true(is.list(features))
  testthat::expect_false(inherits(features, "ledgr_feature_map"))
  testthat::expect_identical(ledgr_feature_id(features), "return_3")
})

testthat::test_that("parameterized feature maps resolve with concrete feature params", {
  features <- ledgr_feature_map(
    fast = ledgr_ind_sma(ledgr_param("fast_n")),
    baseline = ledgr_ind_sma(20)
  )

  testthat::expect_s3_class(features, "ledgr_feature_map")
  testthat::expect_error(ledgr_feature_id(features), class = "ledgr_unresolved_feature_id")

  params <- ledgr_parameters(features)
  testthat::expect_identical(params$param_name, "fast_n")
  testthat::expect_identical(params$alias, "fast")
  testthat::expect_identical(params$argument, "n")

  resolved <- ledgr:::ledgr_resolve_feature_map(features, feature_params = list(fast_n = 10L))
  testthat::expect_identical(
    ledgr_feature_id(resolved),
    c(fast = "sma_10", baseline = "sma_20")
  )
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) ctx$flat()
  exp <- ledgr_experiment(snapshot = snapshot, strategy = strategy, features = features, cost_model = ledgr_cost_zero())
  materialized <- ledgr:::ledgr_experiment_materialize_features(exp, list(fast_n = 10L))
  testthat::expect_identical(ledgr_feature_id(materialized), c("sma_10", "sma_20"))
  testthat::expect_error(
    ledgr:::ledgr_resolve_feature_map(features, feature_params = list()),
    class = "ledgr_param_missing"
  )
  testthat::expect_error(
    ledgr:::ledgr_resolve_feature_map(features, feature_params = list(fast_n = c(10L, 20L))),
    class = "ledgr_param_non_scalar"
  )
})

testthat::test_that("feature map print shows unresolved parameterized entries", {
  features <- ledgr_feature_map(
    fast = ledgr_ind_sma(ledgr_param("fast_n")),
    baseline = ledgr_ind_sma(20)
  )

  printed <- utils::capture.output(print(features))
  testthat::expect_true(any(grepl("fast -> <unresolved>", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("baseline -> sma_20", printed, fixed = TRUE)))
})

testthat::test_that("parameter introspection reports duplicated references as separate rows", {
  features <- ledgr_feature_map(
    fast = ledgr_ind_sma(ledgr_param("n")),
    slow = ledgr_ind_ema(ledgr_param("n"))
  )

  params <- ledgr_parameters(features)
  testthat::expect_identical(params$param_name, c("n", "n"))
  testthat::expect_identical(params$alias, c("fast", "slow"))
  testthat::expect_identical(params$argument, c("n", "n"))
})

testthat::test_that("feature maps are copied into experiments at construction", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    ctx$flat()
  }
  features <- ledgr_feature_map(signal = ledgr_ind_sma(2))

  exp <- ledgr_experiment(snapshot = snapshot, strategy = strategy, features = features, cost_model = ledgr_cost_zero())
  features$indicators[[1]] <- ledgr_ind_returns(3)
  features$feature_ids[["signal"]] <- "return_3"

  materialized <- ledgr_experiment_materialize_features(exp, list())
  testthat::expect_identical(ledgr_feature_id(materialized), "sma_2")
  testthat::expect_identical(exp$features$feature_ids, c(signal = "sma_2"))
})

testthat::test_that("feature maps preserve concrete feature-set identity while aliases affect config hash", {
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

  exp_list <- ledgr_experiment(snapshot = snapshot, strategy = strategy, features = feature_list, cost_model = ledgr_cost_zero())
  exp_map <- ledgr_experiment(snapshot = snapshot, strategy = strategy, features = feature_map, cost_model = ledgr_cost_zero())

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
    timing_model = exp_list$timing_model,
    cost_model_hash = exp_list$cost_model_hash,
    cost_plan_json = exp_list$cost_plan_json,
    db_path = snapshot$db_path,
    opening = exp_list$opening,
    seed = NULL
  )
  feature_map_result <- ledgr_experiment_materialize_feature_result(exp_map, list(), feature_params = list())
  cfg_map <- ledgr_config(
    snapshot = snapshot,
    universe = exp_map$universe,
    strategy = exp_map$strategy,
    backtest = ledgr_backtest_config(
      start = snapshot$metadata$start_date,
      end = snapshot$metadata$end_date,
      initial_cash = exp_map$opening$cash
    ),
    features = feature_map_result$features,
    alias_map = feature_map_result$alias_map,
    persist_features = exp_map$persist_features,
    execution_mode = exp_map$execution_mode,
    timing_model = exp_map$timing_model,
    cost_model_hash = exp_map$cost_model_hash,
    cost_plan_json = exp_map$cost_plan_json,
    db_path = snapshot$db_path,
    opening = exp_map$opening,
    seed = NULL
  )

  list_fingerprints <- vapply(cfg_list$features$defs, `[[`, character(1), "fingerprint")
  map_fingerprints <- vapply(cfg_map$features$defs, `[[`, character(1), "fingerprint")
  testthat::expect_identical(
    ledgr_feature_set_hash(list_fingerprints),
    ledgr_feature_set_hash(map_fingerprints)
  )
  testthat::expect_false(identical(config_hash(cfg_map), config_hash(cfg_list)))
  testthat::expect_match(cfg_map$alias_map_hash, "^[0-9a-f]{64}$")
})
