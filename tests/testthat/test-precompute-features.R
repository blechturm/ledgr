# ledgr-test-profile: heavy_protocol
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
    features = list(ledgr_ind_sma(3), ledgr_ind_returns(2)),
    cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_grid_named(a = list(strategy = list(qty = 1)), b = list(strategy = list(qty = 2)))

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
      "feature_params", "params", "feature_ids", "feature_fingerprints",
      "feature_set_hash", "alias_map", "alias_map_json", "alias_map_hash",
      "alias_map_version"
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
  testthat::expect_s3_class(precomputed$projection, "ledgr_runtime_projection")
  testthat::expect_identical(precomputed$projection$feature_engine_version, ledgr:::ledgr_feature_engine_version())
  testthat::expect_null(precomputed$projection$alias_index)
  testthat::expect_true(all(is.na(precomputed$candidate_features$alias_map_json)))
  testthat::expect_true(all(is.na(precomputed$candidate_features$alias_map_hash)))
  testthat::expect_identical(names(precomputed$projection$instrument_index), c("AAA", "BBB"))
  testthat::expect_equal(unname(precomputed$projection$instrument_index), c(1L, 2L))
  testthat::expect_equal(length(precomputed$projection$pulse_index), 8L)
  testthat::expect_equal(
    sort(names(precomputed$projection$feature_values)),
    sort(precomputed$feature_union$feature_id)
  )
  first_payload <- precomputed$payload[[precomputed$candidate_features$feature_fingerprints[[1]][[1]]]]
  first_matrix <- precomputed$projection$feature_values[[first_payload$feature_id]]
  testthat::expect_equal(dim(first_matrix), c(2L, 8L))
  testthat::expect_equal(unname(first_matrix["AAA", ]), as.numeric(first_payload$values$AAA))
  sma_id <- ledgr_feature_id(ledgr_ind_sma(3))
  testthat::expect_true(is.na(precomputed$projection$feature_values[[sma_id]]["AAA", 1]))
  testthat::expect_silent(ledgr:::ledgr_validate_precomputed_features(precomputed, exp, grid))
})

# ledgr-test-profile: heavy_protocol
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
    features = feature_factory,
    cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_grid_named(a = list(strategy = list(n = 2)), b = list(strategy = list(n = 2)), c = list(strategy = list(n = 4)))

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

# ledgr-test-profile: heavy_protocol
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
    features = list(ledgr_ind_sma(6)),
    cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_grid_named(a = list(strategy = list(qty = 1)))

  precomputed <- ledgr_precompute_features(
    exp,
    grid,
    start = "2020-01-05",
    end = "2020-01-08"
  )

  testthat::expect_identical(precomputed$scoring_range$start, "2020-01-05T00:00:00Z")
  testthat::expect_identical(precomputed$scoring_range$end, "2020-01-08T00:00:00Z")
  # Dense feature state starts at the scoring start, so only the day-5 bar is
  # available there. LDG-3064 retired the separate warm-up start field.
  testthat::expect_null(precomputed$warmup_range)
  testthat::expect_equal(nrow(precomputed$warmup), 1L)
  testthat::expect_equal(precomputed$warmup$available_bars_at_scoring_start[[1]], 1L)
  testthat::expect_false(precomputed$warmup$warmup_achievable[[1]])
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("windowed sweeps validate precomputed scoring and hydration coverage", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:7)
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  feature <- ledgr_indicator(
    id = "custom_close",
    fn = function(window) tail(window$close, 1),
    requires_bars = 1L,
    stable_after = 1L
  )
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    if (ctx$feature("AAA", "custom_close") > params$threshold) {
      targets[["AAA"]] <- params$qty
    }
    targets
  }
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    universe = "AAA",
    features = list(feature),
    cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_grid_named(low = list(strategy = list(qty = 1, threshold = 103)), high = list(strategy = list(qty = 2, threshold = 106)))
  window <- ledgr:::ledgr_experiment_window(exp, "2020-01-04", "2020-01-08")

  # A dense payload whose feature state starts before the window refuses;
  # one starting at the window reproduces the unprecomputed window sweep.
  # LDG-3064 retired the hydration class; the dense start is the scoring start.
  full_precomputed <- ledgr_precompute_features(exp, grid)
  exact_precomputed <- ledgr_precompute_features(exp, grid, start = "2020-01-04", end = "2020-01-08")
  testthat::expect_error(
    ledgr:::ledgr_sweep_window(exp, grid, window = window, precomputed_features = full_precomputed, seed = 101L),
    class = "ledgr_precomputed_range_mismatch"
  )
  plain_window <- ledgr:::ledgr_sweep_window(exp, grid, window = window, seed = 101L)
  exact_window <- ledgr:::ledgr_sweep_window(exp, grid, window = window, precomputed_features = exact_precomputed, seed = 101L)
  metric_cols <- c("candidate_id", "status", "final_equity", "total_return", "n_trades")
  testthat::expect_identical(
    as.data.frame(stats::setNames(lapply(metric_cols, function(col) plain_window[[col]]), metric_cols)),
    as.data.frame(stats::setNames(lapply(metric_cols, function(col) exact_window[[col]]), metric_cols))
  )

  short_scoring <- ledgr_precompute_features(exp, grid, start = "2020-01-05", end = "2020-01-08")
  testthat::expect_error(
    ledgr:::ledgr_validate_precomputed_features(short_scoring, exp, grid, window = window),
    class = "ledgr_precomputed_range_mismatch"
  )

  earlier_start <- exact_precomputed
  earlier_start$scoring_range$start <- "2020-01-03T00:00:00Z"
  testthat::expect_error(
    ledgr:::ledgr_validate_precomputed_features(earlier_start, exp, grid, window = window),
    class = "ledgr_precomputed_range_mismatch"
  )
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("runtime projection flattens bundle outputs to concrete feature IDs", {
  testthat::skip_if_not_installed("TTR")
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:30)
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  bundle <- ledgr_ind_ttr_outputs("BBands", input = "close", outputs = c("dn", "up"), n = 5)
  strategy <- function(ctx, params) ctx$flat()
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    universe = "AAA",
    features = list(bundle),
    cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_grid_named(a = list(strategy = list(qty = 1)))

  precomputed <- ledgr_precompute_features(exp, grid)
  expected_ids <- unname(ledgr_feature_id(bundle))

  testthat::expect_equal(sort(names(precomputed$projection$feature_values)), sort(expected_ids))
  testthat::expect_equal(sort(precomputed$feature_union$feature_id), sort(expected_ids))
})

# ledgr-test-profile: heavy_protocol
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
    features = list(ledgr_ind_returns(1)),
    cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_grid_named(a = list(strategy = list(qty = 1)))

  testthat::expect_error(
    ledgr_precompute_features(exp, grid),
    class = "ledgr_precomputed_coverage_error"
  )
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("precomputed feature validation binds snapshot, universe, range, labels, and feature union", {
  bars <- ledgr_test_make_bars(c("AAA", "BBB"), as.Date("2020-01-01") + 0:4)
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
    features = feature_factory,
    cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_grid_named(a = list(strategy = list(n = 2)), b = list(strategy = list(n = 3)))
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
    features = feature_factory,
    cost_model = ledgr_cost_zero()
  )
  testthat::expect_error(
    ledgr:::ledgr_validate_precomputed_features(precomputed, other_exp, grid),
    class = "ledgr_precomputed_snapshot_mismatch"
  )

  one_universe_exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    universe = "AAA",
    features = feature_factory,
    cost_model = ledgr_cost_zero()
  )
  testthat::expect_error(
    ledgr:::ledgr_validate_precomputed_features(precomputed, one_universe_exp, grid),
    class = "ledgr_precomputed_universe_mismatch"
  )

  testthat::expect_error(
    ledgr:::ledgr_validate_precomputed_features(precomputed, exp, grid, start = "2020-01-02"),
    class = "ledgr_precomputed_range_mismatch"
  )

  relabeled_grid <- ledgr_grid_named(a = list(strategy = list(n = 2)), c = list(strategy = list(n = 3)))
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

  changed_grid <- ledgr_grid_named(a = list(strategy = list(n = 2)), b = list(strategy = list(n = 4)))
  testthat::expect_error(
    ledgr:::ledgr_validate_precomputed_features(precomputed, exp, changed_grid),
    class = "ledgr_precomputed_feature_mismatch"
  )
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("precomputed features refuse after a direct capture changes", {
  make_indicator <- function(scale) {
    ledgr_indicator(
      id = "captured_scale",
      fn = function(window) tail(window$close, 1L) * scale,
      series_fn = function(bars, params) bars$close * scale,
      requires_bars = 1L
    )
  }
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:5)
  snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    target <- ctx$flat()
    value <- ctx$feature("AAA", "captured_scale")
    if (is.finite(value) && value > params$threshold) target[["AAA"]] <- 1
    target
  }
  experiment <- function(scale) {
    ledgr_experiment(
      snapshot,
      strategy,
      features = list(make_indicator(scale)),
      cost_model = ledgr_cost_zero()
    )
  }
  grid <- ledgr_grid_named(one = list(strategy = list(threshold = 0)))
  original <- experiment(1)
  changed <- experiment(2)
  precomputed <- ledgr_precompute_features(original, grid)

  local({
    executed <- FALSE
    testthat::local_mocked_bindings(
      ledgr_execute_fold = function(...) {
        executed <<- TRUE
        stop("candidate executed")
      },
      .package = "ledgr"
    )
    testthat::expect_error(
      ledgr_sweep(changed, grid, precomputed_features = precomputed),
      class = "ledgr_precomputed_feature_mismatch"
    )
    testthat::expect_false(executed)
  })

  rebuilt <- ledgr_precompute_features(changed, grid)
  with_precompute <- ledgr_sweep(changed, grid, precomputed_features = rebuilt)
  fresh <- ledgr_sweep(changed, grid)
  testthat::expect_identical(with_precompute$status, fresh$status)
  testthat::expect_identical(with_precompute$final_equity, fresh$final_equity)
  testthat::expect_identical(with_precompute$n_trades, fresh$n_trades)
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("precomputed candidates stay bound when captured windows are permuted", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:29)
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  windows <- c(fast = 5, slow = 20)
  strategy <- function(ctx, params) {
    target <- ctx$flat()
    value <- ctx$feature("AAA", "trend")
    if (is.finite(value)) target[["AAA"]] <- 1
    target
  }
  exp <- ledgr_experiment(
    snapshot,
    strategy,
    features = function(params) {
      ledgr_feature_map(trend = ledgr_ind_sma(windows[[params$speed]]))
    },
    cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_grid_named(
    fast = list(strategy = list(speed = "fast")),
    slow = list(strategy = list(speed = "slow"))
  )
  precomputed <- ledgr_precompute_features(exp, grid)
  original_union <- sort(precomputed$feature_union$fingerprint, method = "radix")

  windows <- c(fast = 20, slow = 5)
  con <- ledgr:::get_connection(snapshot)
  count_rows <- function(table) {
    if (!DBI::dbExistsTable(con, table)) {
      return(0L)
    }
    DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM %s", table))$n[[1L]]
  }
  runs_before <- count_rows("runs")
  fills_before <- count_rows("fills")
  local({
    executed <- FALSE
    testthat::local_mocked_bindings(
      ledgr_execute_fold = function(...) {
        executed <<- TRUE
        stop("candidate executed")
      },
      .package = "ledgr"
    )

    testthat::expect_error(
      ledgr_sweep(exp, grid, precomputed_features = precomputed),
      class = "ledgr_precomputed_feature_mismatch"
    )
    testthat::expect_false(executed)
    testthat::expect_identical(count_rows("runs"), runs_before)
    testthat::expect_identical(count_rows("fills"), fills_before)
  })

  rebuilt <- ledgr_precompute_features(exp, grid)
  testthat::expect_identical(
    sort(rebuilt$feature_union$fingerprint, method = "radix"),
    original_union
  )
  testthat::expect_identical(
    rebuilt$candidate_features$feature_fingerprints[[1L]],
    precomputed$candidate_features$feature_fingerprints[[2L]]
  )
  testthat::expect_identical(
    rebuilt$candidate_features$feature_fingerprints[[2L]],
    precomputed$candidate_features$feature_fingerprints[[1L]]
  )
  stale_alias <- rebuilt
  stale_alias$candidate_features$alias_map_hash[[1L]] <- strrep("0", 64L)
  testthat::expect_error(
    ledgr:::ledgr_validate_precomputed_features(stale_alias, exp, grid),
    class = "ledgr_precomputed_feature_mismatch"
  )
  with_precompute <- ledgr_sweep(exp, grid, precomputed_features = rebuilt)
  fresh <- ledgr_sweep(exp, grid)
  testthat::expect_identical(with_precompute$status, fresh$status)
  testthat::expect_identical(with_precompute$final_equity, fresh$final_equity)
  testthat::expect_identical(with_precompute$n_trades, fresh$n_trades)

  nm <- c("fast", "slow")
  alias_strategy <- function(ctx, params) {
    target <- ctx$flat()
    value <- ctx$feature("AAA", "fast")
    if (is.finite(value) && ctx$close("AAA") > value) target[["AAA"]] <- 1
    target
  }
  alias_exp <- ledgr_experiment(
    snapshot,
    alias_strategy,
    features = function(params) {
      indicators <- list(ledgr_ind_sma(5), ledgr_ind_sma(20))
      names(indicators) <- nm
      do.call(ledgr_feature_map, indicators)
    },
    cost_model = ledgr_cost_zero()
  )
  alias_precomputed <- ledgr_precompute_features(alias_exp, grid)
  testthat::expect_identical(
    alias_precomputed$candidate_features$feature_fingerprints[[1L]],
    alias_precomputed$candidate_features$feature_fingerprints[[2L]]
  )
  testthat::expect_silent(
    ledgr:::ledgr_validate_precomputed_features(alias_precomputed, alias_exp, grid)
  )

  nm <- c("slow", "fast")
  alias_current <- ledgr:::ledgr_precompute_resolve_grid(
    alias_exp,
    grid
  )$candidate_features
  testthat::expect_identical(
    alias_current$feature_fingerprints,
    alias_precomputed$candidate_features$feature_fingerprints
  )
  testthat::expect_identical(
    alias_current$alias_map_hash,
    alias_precomputed$candidate_features$alias_map_hash
  )
  testthat::expect_false(identical(
    alias_current$alias_map_json,
    alias_precomputed$candidate_features$alias_map_json
  ))

  runs_before_alias_refusal <- count_rows("runs")
  fills_before_alias_refusal <- count_rows("fills")
  local({
    executed <- FALSE
    testthat::local_mocked_bindings(
      ledgr_execute_fold = function(...) {
        executed <<- TRUE
        stop("candidate executed")
      },
      .package = "ledgr"
    )

    testthat::expect_error(
      ledgr_sweep(alias_exp, grid, precomputed_features = alias_precomputed),
      class = "ledgr_precomputed_feature_mismatch"
    )
    testthat::expect_false(executed)
    testthat::expect_identical(count_rows("runs"), runs_before_alias_refusal)
    testthat::expect_identical(count_rows("fills"), fills_before_alias_refusal)
  })

  alias_rebuilt <- ledgr_precompute_features(alias_exp, grid)
  alias_with_precompute <- ledgr_sweep(
    alias_exp,
    grid,
    precomputed_features = alias_rebuilt
  )
  alias_fresh <- ledgr_sweep(alias_exp, grid)
  testthat::expect_identical(alias_with_precompute$status, alias_fresh$status)
  testthat::expect_identical(
    alias_with_precompute$final_equity,
    alias_fresh$final_equity
  )
  testthat::expect_identical(alias_with_precompute$n_trades, alias_fresh$n_trades)

  reordered_grid <- ledgr_grid_named(
    slow = list(strategy = list(speed = "slow")),
    fast = list(strategy = list(speed = "fast"))
  )
  reordered_precomputed <- ledgr_precompute_features(alias_exp, reordered_grid)
  testthat::expect_silent(ledgr:::ledgr_validate_precomputed_features(
    reordered_precomputed,
    alias_exp,
    reordered_grid
  ))
  reordered_with_precompute <- ledgr_sweep(
    alias_exp,
    reordered_grid,
    precomputed_features = reordered_precomputed
  )
  reordered_fresh <- ledgr_sweep(alias_exp, reordered_grid)
  testthat::expect_identical(
    reordered_with_precompute$final_equity,
    reordered_fresh$final_equity
  )
  testthat::expect_identical(
    reordered_with_precompute$n_trades,
    reordered_fresh$n_trades
  )

  parameterized_exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$flat(),
    features = ledgr_feature_map(
      signal = ledgr_ind_sma(ledgr_param("n"))
    ),
    cost_model = ledgr_cost_zero()
  )
  parameterized_grid <- ledgr_grid_named(
    short = list(feature = list(n = 5L)),
    long = list(feature = list(n = 20L))
  )
  parameterized_precomputed <- ledgr_precompute_features(
    parameterized_exp,
    parameterized_grid
  )
  testthat::expect_silent(ledgr:::ledgr_validate_precomputed_features(
    parameterized_precomputed,
    parameterized_exp,
    parameterized_grid
  ))
})

testthat::test_that("large grids without precomputed features warn through the reserved sweep helper", {
  grid <- ledgr:::ledgr_executable_grid_normalize(data.frame(qty = seq_len(21)))

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
    features = function(params) list(ledgr_ind_sma(params$n)),
    cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_grid_named(good = list(strategy = list(n = 2)), bad = list(strategy = list(n = 0)), also_good = list(strategy = list(n = 4)))

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
      features = function() list(ledgr_ind_sma(2)),
      cost_model = ledgr_cost_zero()
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

# ledgr-test-profile: heavy_protocol
testthat::test_that("future-only bar changes preserve eligible feature prefixes", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  changed <- bars
  future_rows <- 4:5
  changed[future_rows, c("open", "high", "low", "close")] <-
    changed[future_rows, c("open", "high", "low", "close")] + 100

  make_precomputed <- function(input, path, snapshot_id) {
    snapshot <- ledgr_snapshot_from_df(input, db_path = path, snapshot_id = snapshot_id)
    on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
    exp <- ledgr_experiment(
      snapshot,
      function(ctx, params) ctx$flat(),
      features = list(ledgr_ind_sma(3)),
      cost_model = ledgr_cost_zero()
    )
    ledgr_precompute_features(exp, ledgr_grid_named(only = list(strategy = list(qty = 0))))
  }

  first_path <- tempfile(fileext = ".duckdb")
  second_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(c(first_path, second_path)), add = TRUE)
  first <- make_precomputed(bars, first_path, "causal-prefix-a")
  second <- make_precomputed(changed, second_path, "causal-prefix-b")
  feature_id <- ledgr_feature_id(ledgr_ind_sma(3))
  first_values <- first$projection$feature_values[[feature_id]]["AAA", ]
  second_values <- second$projection$feature_values[[feature_id]]["AAA", ]

  testthat::expect_false(identical(first$snapshot_hash, second$snapshot_hash))
  testthat::expect_identical(first_values[1:3], second_values[1:3])
  testthat::expect_false(identical(first_values[4:5], second_values[4:5]))
})
