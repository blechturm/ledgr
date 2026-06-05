testthat::test_that("feature and strategy grids build deterministic cross products", {
  features <- ledgr_feature_grid(
    fast_n = c(10L, 20L),
    slow_n = c(40L, 80L),
    .filter = fast_n < slow_n
  )
  strategy <- ledgr_strategy_grid(
    threshold = c(0, 0.01),
    qty = 100L
  )

  testthat::expect_s3_class(features, "ledgr_feature_grid")
  testthat::expect_false(inherits(features, "ledgr_param_grid"))
  testthat::expect_s3_class(strategy, "ledgr_strategy_grid")
  testthat::expect_s3_class(strategy, "ledgr_param_grid")
  testthat::expect_length(features$params, 4L)
  testthat::expect_length(strategy$params, 2L)
  testthat::expect_identical(features$params[[1]], list(fast_n = 10L, slow_n = 40L))
  testthat::expect_identical(strategy$params[[2]], list(threshold = 0.01, qty = 100L))

  again <- ledgr_feature_grid(
    fast_n = c(10L, 20L),
    slow_n = c(40L, 80L),
    .filter = fast_n < slow_n
  )
  testthat::expect_identical(features$labels, again$labels)
})

testthat::test_that("grid filters are deliberately narrow", {
  threshold <- 10L
  testthat::expect_error(
    ledgr_feature_grid(fast_n = c(5L, 20L), .filter = fast_n > threshold),
    class = "ledgr_grid_filter_invalid"
  )
  testthat::expect_error(
    ledgr_feature_grid(fast_n = c(5L, 20L), .filter = ledgr_param("x")),
    class = "ledgr_grid_filter_invalid"
  )
  testthat::expect_error(
    ledgr_feature_grid(fast_n = c(5L, 20L), .filter = c(TRUE, NA)),
    class = "ledgr_grid_filter_invalid"
  )
  filtered <- ledgr_feature_grid(fast_n = c(-5L, 20L), .filter = abs(fast_n) > 10L)
  testthat::expect_identical(filtered$params, list(list(fast_n = 20L)))
  in_filter <- ledgr_feature_grid(fast_n = c(5L, 10L, 20L), .filter = fast_n %in% c(10L, 20L))
  testthat::expect_identical(
    vapply(in_filter$params, `[[`, integer(1), "fast_n"),
    c(10L, 20L)
  )
  exp_filter <- ledgr_strategy_grid(threshold = c(0, 1), .filter = exp(threshold) > 1)
  testthat::expect_identical(exp_filter$params, list(list(threshold = 1)))
})

testthat::test_that("grid helpers reject invalid columns and duplicate generated labels", {
  testthat::expect_error(
    ledgr_feature_grid(),
    class = "ledgr_invalid_grid"
  )
  testthat::expect_error(
    ledgr_feature_grid(n = list(1L, 2L)),
    class = "ledgr_invalid_grid"
  )
  testthat::expect_error(
    ledgr_strategy_grid(n = c(1L, 1L)),
    class = "ledgr_duplicate_grid_labels"
  )
})

testthat::test_that("feature grid accepts intentional NA values", {
  grid <- ledgr_feature_grid(n = c(10L, NA_integer_, 20L))

  testthat::expect_length(grid$params, 3L)
  testthat::expect_identical(grid$params[[1]]$n, 10L)
  testthat::expect_true(is.na(grid$params[[2]]$n))
  testthat::expect_identical(grid$params[[3]]$n, 20L)
})

testthat::test_that("grid_cross composes namespaces and handles omitted sides", {
  features <- ledgr_feature_grid(fast_n = c(10L, 20L))
  strategy <- ledgr_strategy_grid(fast_n = c(1L, 2L), qty = 100L)
  grid <- ledgr_grid_cross(features = features, strategy = strategy)

  testthat::expect_s3_class(grid, "ledgr_executable_grid")
  testthat::expect_s3_class(grid, "ledgr_param_grid")
  testthat::expect_length(grid$params, 4L)
  testthat::expect_true(grepl("/", grid$labels[[1]], fixed = TRUE))
  testthat::expect_identical(grid$params[[1]]$feature_params, list(fast_n = 10L))
  testthat::expect_identical(grid$params[[1]]$strategy_params, list(fast_n = 1L, qty = 100L))

  feature_only <- ledgr_grid_cross(features = features)
  strategy_only <- ledgr_grid_cross(strategy = strategy)
  testthat::expect_identical(feature_only$params[[1]]$strategy_params, list())
  testthat::expect_identical(strategy_only$params[[1]]$feature_params, list())
  testthat::expect_true(all(grepl("/strategy_empty$", feature_only$labels)))
  testthat::expect_true(all(grepl("^features_empty/", strategy_only$labels)))
  testthat::expect_error(
    ledgr_grid_cross(),
    class = "ledgr_invalid_executable_grid"
  )
})

testthat::test_that("grid_cross accepts legacy param grids as strategy side", {
  features <- ledgr_feature_grid(n = c(10L, 20L))
  strategy <- ledgr_param_grid(a = list(qty = 1L), b = list(qty = 2L))
  grid <- ledgr_grid_cross(features = features, strategy = strategy)

  testthat::expect_s3_class(grid, "ledgr_executable_grid")
  testthat::expect_identical(grid$params[[1]]$strategy_params, list(qty = 1L))
})

testthat::test_that("named executable grids and baselines preserve explicit labels", {
  grid <- ledgr_grid_named(
    conservative = list(
      feature = list(fast_n = 10L, slow_n = 80L),
      strategy = list(threshold = 0.01, qty = 50L)
    ),
    aggressive = list(
      feature = list(fast_n = 50L, slow_n = 200L),
      strategy = list(threshold = 0, qty = 200L)
    )
  )

  testthat::expect_s3_class(grid, "ledgr_executable_grid")
  testthat::expect_identical(grid$labels, c("conservative", "aggressive"))
  testthat::expect_identical(grid$params[[1]]$feature_params, list(fast_n = 10L, slow_n = 80L))
  testthat::expect_identical(grid$params[[1]]$strategy_params, list(threshold = 0.01, qty = 50L))

  with_baseline <- ledgr_grid_add_baseline(
    grid,
    flat = list(feature = list(fast_n = 10L, slow_n = 40L), strategy = list(threshold = 0, qty = 0L)),
    flat_alt = list(strategy = list(threshold = 1, qty = 0L))
  )
  testthat::expect_identical(with_baseline$labels, c("conservative", "aggressive", "flat", "flat_alt"))
  testthat::expect_identical(with_baseline$params[[4]]$feature_params, list())
  testthat::expect_error(
    ledgr_grid_add_baseline(grid, conservative = list(strategy = list(qty = 0L))),
    class = "ledgr_duplicate_executable_grid_labels"
  )

  duplicate_args <- list(a = list(strategy = list(qty = 1L)), a = list(strategy = list(qty = 2L)))
  testthat::expect_error(
    do.call(ledgr_grid_named, duplicate_args),
    class = "ledgr_duplicate_executable_grid_labels"
  )
})

testthat::test_that("executable grids feed feature params to feature resolution", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) ctx$flat()
  features <- ledgr_feature_map(signal = ledgr_ind_sma(ledgr_param("fast_n")))
  exp <- ledgr_experiment(snapshot = snapshot, strategy = strategy, features = features, cost_model = ledgr_cost_zero())
  grid <- ledgr_grid_cross(
    features = ledgr_feature_grid(fast_n = c(2L, 3L)),
    strategy = ledgr_strategy_grid(qty = 100L)
  )

  resolved <- ledgr:::ledgr_resolve_feature_candidates(exp, grid, stop_on_error = TRUE)
  testthat::expect_identical(resolved$candidate_features$feature_ids[[1]], "sma_2")
  testthat::expect_identical(resolved$candidate_features$feature_ids[[2]], "sma_3")
})
