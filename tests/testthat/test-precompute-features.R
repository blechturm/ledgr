testthat::test_that("ledgr_precompute_features computes concrete feature payloads once", {
  bars <- ledgr_test_make_bars(c("AAA", "BBB"), as.Date("2020-01-01") + 0:7)
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    universe = c("AAA", "BBB"),
    features = list(ledgr_ind_sma(3), ledgr_ind_returns(2))
  )
  grid <- ledgr_param_grid(a = list(qty = 1), b = list(qty = 2))

  precomputed <- ledgr_precompute_features(exp, grid)

  testthat::expect_s3_class(precomputed, "ledgr_precomputed_features")
  testthat::expect_identical(precomputed$snapshot_id, snapshot$snapshot_id)
  testthat::expect_identical(precomputed$snapshot_hash, ledgr_snapshot_info(snapshot)$snapshot_hash[[1]])
  testthat::expect_identical(precomputed$universe, c("AAA", "BBB"))
  testthat::expect_equal(nrow(precomputed$feature_union), 2L)
  testthat::expect_equal(length(precomputed$payload), 2L)
  testthat::expect_equal(nrow(precomputed$candidate_features), 2L)
  testthat::expect_equal(
    names(precomputed$candidate_features),
    c(
      "candidate_label", "params_hash", "status", "error_class", "error_msg",
      "feature_ids", "feature_fingerprints", "feature_set_hash"
    )
  )
  testthat::expect_identical(precomputed$candidate_features$status, c("ok", "ok"))
  testthat::expect_identical(
    precomputed$candidate_features$feature_fingerprints[[1]],
    precomputed$candidate_features$feature_fingerprints[[2]]
  )
  testthat::expect_equal(
    sort(names(precomputed$payload)),
    sort(precomputed$feature_union$fingerprint)
  )
  testthat::expect_silent(ledgr:::ledgr_validate_precomputed_features(precomputed, exp, grid))
})

testthat::test_that("feature factories resolve per candidate and dedupe by fingerprint", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:7)
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  feature_factory <- function(params) {
    calls$n <- calls$n + 1L
    list(ledgr_ind_sma(params$n))
  }
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    universe = "AAA",
    features = feature_factory
  )
  grid <- ledgr_param_grid(a = list(n = 2), b = list(n = 2), c = list(n = 4))

  precomputed <- ledgr_precompute_features(exp, grid)

  testthat::expect_equal(calls$n, 3L)
  testthat::expect_equal(nrow(precomputed$feature_union), 2L)
  testthat::expect_match(precomputed$candidate_features$feature_set_hash[[1]], "^[0-9a-f]{64}$")
  testthat::expect_identical(
    precomputed$candidate_features$feature_set_hash[[1]],
    precomputed$candidate_features$feature_set_hash[[2]]
  )
  testthat::expect_false(identical(
    precomputed$candidate_features$feature_set_hash[[1]],
    precomputed$candidate_features$feature_set_hash[[3]]
  ))
  testthat::expect_identical(
    precomputed$candidate_features$feature_fingerprints[[1]],
    precomputed$candidate_features$feature_fingerprints[[2]]
  )
  testthat::expect_false(identical(
    precomputed$candidate_features$feature_fingerprints[[1]],
    precomputed$candidate_features$feature_fingerprints[[3]]
  ))
})

testthat::test_that("precompute separates scoring range from warmup feasibility", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:9)
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    universe = "AAA",
    features = list(ledgr_ind_sma(6))
  )
  grid <- ledgr_param_grid(a = list(qty = 1))

  precomputed <- ledgr_precompute_features(
    exp,
    grid,
    start = "2020-01-05",
    end = "2020-01-08"
  )

  testthat::expect_identical(precomputed$scoring_range$start, "2020-01-05T00:00:00Z")
  testthat::expect_identical(precomputed$scoring_range$end, "2020-01-08T00:00:00Z")
  testthat::expect_identical(precomputed$warmup_range$start, ledgr_snapshot_info(snapshot)$start_date[[1]])
  testthat::expect_equal(nrow(precomputed$warmup), 1L)
  testthat::expect_equal(precomputed$warmup$available_bars_at_scoring_start[[1]], 5L)
  testthat::expect_false(precomputed$warmup$warmup_achievable[[1]])
})

testthat::test_that("precompute aborts on static scoring coverage gaps", {
  bars <- ledgr_test_make_bars(c("AAA", "BBB"), as.Date("2020-01-01") + 0:5)
  bars <- bars[!(bars$instrument_id == "BBB" & bars$ts_utc == ledgr_utc("2020-01-03")), , drop = FALSE]
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    universe = c("AAA", "BBB"),
    features = list(ledgr_ind_returns(1))
  )
  grid <- ledgr_param_grid(a = list(qty = 1))

  testthat::expect_error(
    ledgr_precompute_features(exp, grid),
    class = "ledgr_precomputed_coverage_error"
  )
})

testthat::test_that("precomputed feature validation binds snapshot, universe, range, labels, and feature union", {
  bars <- ledgr_test_make_bars(c("AAA", "BBB"), as.Date("2020-01-01") + 0:7)
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()
  feature_factory <- function(params) list(ledgr_ind_sma(params$n))
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    universe = c("AAA", "BBB"),
    features = feature_factory
  )
  grid <- ledgr_param_grid(a = list(n = 2), b = list(n = 3))
  precomputed <- ledgr_precompute_features(exp, grid)

  changed_bars <- bars
  changed_bars$open[[1]] <- changed_bars$open[[1]] + 1
  changed_bars$high[[1]] <- changed_bars$high[[1]] + 1
  changed_bars$low[[1]] <- changed_bars$low[[1]] + 1
  changed_bars$close[[1]] <- changed_bars$close[[1]] + 1
  other_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(other_path), add = TRUE)
  other_snapshot <- ledgr_snapshot_from_df(changed_bars, db_path = other_path)
  on.exit(ledgr_snapshot_close(other_snapshot), add = TRUE)
  other_exp <- ledgr_experiment(
    snapshot = other_snapshot,
    strategy = strategy,
    universe = c("AAA", "BBB"),
    features = feature_factory
  )
  testthat::expect_error(
    ledgr:::ledgr_validate_precomputed_features(precomputed, other_exp, grid),
    class = "ledgr_precomputed_snapshot_mismatch"
  )

  one_universe_exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    universe = "AAA",
    features = feature_factory
  )
  testthat::expect_error(
    ledgr:::ledgr_validate_precomputed_features(precomputed, one_universe_exp, grid),
    class = "ledgr_precomputed_universe_mismatch"
  )

  testthat::expect_error(
    ledgr:::ledgr_validate_precomputed_features(precomputed, exp, grid, start = "2020-01-02"),
    class = "ledgr_precomputed_range_mismatch"
  )

  relabeled_grid <- ledgr_param_grid(a = list(n = 2), c = list(n = 3))
  testthat::expect_error(
    ledgr:::ledgr_validate_precomputed_features(precomputed, exp, relabeled_grid),
    class = "ledgr_precomputed_grid_mismatch"
  )

  stale_engine <- precomputed
  stale_engine$feature_engine_version <- "stale-feature-engine"
  testthat::expect_error(
    ledgr:::ledgr_validate_precomputed_features(stale_engine, exp, grid),
    class = "ledgr_precomputed_engine_mismatch"
  )

  changed_grid <- ledgr_param_grid(a = list(n = 2), b = list(n = 4))
  testthat::expect_error(
    ledgr:::ledgr_validate_precomputed_features(precomputed, exp, changed_grid),
    class = "ledgr_precomputed_feature_mismatch"
  )
})

testthat::test_that("large grids without precomputed features warn through the reserved sweep helper", {
  grid <- do.call(
    ledgr_param_grid,
    lapply(seq_len(21), function(i) list(qty = i))
  )

  testthat::expect_warning(
    ledgr:::ledgr_warn_large_grid_without_precomputed_features(grid, NULL),
    class = "ledgr_missing_precomputed_features_warning"
  )
  testthat::expect_silent(
    ledgr:::ledgr_warn_large_grid_without_precomputed_features(grid, list())
  )
})

testthat::test_that("candidate feature resolution captures candidate-specific factory failures", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:7)
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    universe = "AAA",
    features = function(params) list(ledgr_ind_sma(params$n))
  )
  grid <- ledgr_param_grid(good = list(n = 2), bad = list(n = 0), also_good = list(n = 4))

  resolved <- ledgr:::ledgr_resolve_feature_candidates(exp, grid, stop_on_error = FALSE)

  testthat::expect_equal(resolved$candidate_features$candidate_label, c("good", "bad", "also_good"))
  testthat::expect_equal(resolved$candidate_features$status, c("ok", "failed", "ok"))
  testthat::expect_identical(resolved$candidate_features$error_class[[2]], "ledgr_invalid_args")
  testthat::expect_true(is.na(resolved$candidate_features$feature_set_hash[[2]]))
  testthat::expect_match(resolved$candidate_features$feature_set_hash[[1]], "^[0-9a-f]{64}$")
  testthat::expect_match(resolved$candidate_features$feature_set_hash[[3]], "^[0-9a-f]{64}$")

  testthat::expect_error(
    ledgr:::ledgr_resolve_feature_candidates(exp, grid, stop_on_error = TRUE),
    class = "ledgr_invalid_args"
  )
})

testthat::test_that("structural feature-factory invalidity aborts before candidate resolution", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:3)
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()

  testthat::expect_error(
    ledgr_experiment(
      snapshot = snapshot,
      strategy = strategy,
      universe = "AAA",
      features = function() list(ledgr_ind_sma(2))
    ),
    class = "ledgr_invalid_experiment_features"
  )
})

testthat::test_that("feature set hashes are normalized by sorted candidate fingerprints", {
  fingerprints <- c("fff", "aaa", "fff")

  testthat::expect_identical(
    ledgr:::ledgr_feature_set_hash(fingerprints),
    ledgr:::ledgr_feature_set_hash(c("aaa", "fff"))
  )
  testthat::expect_false(identical(
    ledgr:::ledgr_feature_set_hash(fingerprints),
    ledgr:::ledgr_feature_set_hash(c("aaa", "bbb"))
  ))
  testthat::expect_error(
    ledgr:::ledgr_feature_set_hash(c("aaa", NA_character_)),
    class = "ledgr_invalid_args"
  )
})
