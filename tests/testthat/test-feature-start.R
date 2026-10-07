# Cut 9 Workstream 19: until the joint history-start design binds causal
# hydration, every entry point starts feature state at its scoring start.

feature_start_day <- function(d) {
  as.POSIXct(paste(as.Date("2020-01-01") + d - 1L, "00:00:00"), tz = "UTC")
}

feature_start_iso <- function(d) {
  format(feature_start_day(d), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

feature_start_snapshot <- function(closes) {
  ledgr_snapshot_from_df(
    data.frame(
      instrument_id = "AAA",
      ts_utc = feature_start_day(seq_along(closes)),
      open = closes,
      high = closes + 0.5,
      low = closes - 0.5,
      close = closes,
      volume = 1000
    ),
    db_path = tempfile(fileext = ".duckdb")
  )
}

# ledgr-test-profile: review
testthat::test_that("[LTB-0196] fixed-window and recursive features restart at every scoring start", {
  # Closes 30 on days 1-5, then 6..10; every path opens or scores from day 6.
  # Restarted there, TTR's recursive EMA(3) seeds with mean(6, 7, 8) = 7 and
  # reads NA, NA, 7, 8, 9; carried from day 1 it reads 18, 12.5, 10.25, 9.625,
  # 9.8125. SMA(3) restarted reads NA, NA, 7, 8, 9; carried it reads 22,
  # 14.33, 7, 8, 9, so it differs only while the restarted SMA warms up.
  snapshot <- feature_start_snapshot(c(rep(30, 5), 6:10))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  features <- ledgr_feature_map(
    recursive = ledgr_ind_ttr("EMA", input = "close", n = 3L),
    window = ledgr_ind_sma(3L)
  )
  # Hold one share while the recursive EMA is at most 9: restarted, the
  # strategy buys on day 8, fills at the day-9 open of 9, still holds on day 10
  # (EMA 9) and ends at 1001; carrying the day-1 state it never trades.
  strategy <- function(ctx, params) {
    recursive <- ctx$feature("AAA", "ttr_ema_3")
    target <- ctx$flat()
    if (!is.na(recursive) && recursive <= 9) target[["AAA"]] <- 1
    target
  }
  dated <- ledgr_experiment(
    snapshot, strategy, features = features,
    opening = ledgr_opening(cash = 1000, date = feature_start_iso(6L)),
    cost_model = ledgr_cost_zero()
  )
  undated <- ledgr_experiment(
    snapshot, strategy, features = features,
    opening = ledgr_opening(cash = 1000),
    cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_param_grid(only = list())
  restart_final <- 1000 - 9 + 10

  run <- ledgr_run(dated, run_id = "feature-start-run")
  on.exit(close(run), add = TRUE)
  backtest <- ledgr_backtest(
    snapshot = snapshot, strategy = strategy, universe = "AAA",
    start = feature_start_iso(6L), initial_cash = 1000,
    features = list(ledgr_ind_ttr("EMA", input = "close", n = 3L), ledgr_ind_sma(3L)),
    cost_model = ledgr_cost_zero(), run_id = "feature-start-backtest"
  )
  on.exit(close(backtest), add = TRUE)
  sweep <- ledgr_sweep(dated, grid, workers = 1L, seed = 1L)
  precomputed <- ledgr_precompute_features(dated, grid)
  precomputed_sweep <- ledgr_sweep(dated, grid, precomputed_features = precomputed, workers = 1L, seed = 1L)
  promoted <- ledgr_promote(dated, ledgr_candidate(sweep, 1L), run_id = "feature-start-promote")
  on.exit(close(promoted), add = TRUE)
  window <- ledgr:::ledgr_experiment_window(undated, feature_start_iso(6L), feature_start_iso(10L))
  window_run <- ledgr:::ledgr_run_window(undated, window = window, run_id = "feature-start-window-run")
  on.exit(close(window_run), add = TRUE)
  window_sweep <- ledgr:::ledgr_sweep_window(undated, grid, window = window, workers = 1L, seed = 1L)

  final <- function(bt) {
    equity <- ledgr_results(bt, "equity")
    equity$equity[[nrow(equity)]]
  }
  finals <- c(
    run = final(run),
    backtest = final(backtest),
    sweep = sweep$final_equity[[1L]],
    precomputed_sweep = precomputed_sweep$final_equity[[1L]],
    promoted = final(promoted),
    window_run = final(window_run),
    window_sweep = window_sweep$final_equity[[1L]]
  )
  testthat::expect_identical(finals, stats::setNames(rep(restart_final, 7L), names(finals)))
  testthat::expect_identical(precomputed$warmup_range$start, feature_start_iso(6L))

  # Training on days 6-8 restarts too: its EMA first exists on day 8, so it
  # cannot fill inside the window, exactly like a test window restarting on 9.
  folds <- ledgr:::ledgr_fold_list(
    list(ledgr_fold(feature_start_iso(6L), feature_start_iso(8L),
                    feature_start_iso(9L), feature_start_iso(10L), fold_seq = 1L)),
    constructor = list(type_id = "explicit")
  )
  walk_forward <- suppressWarnings(ledgr_walk_forward(
    undated, grid, folds,
    selection_rule = ledgr_rule_argmax("annualized_return"), seed = 1L
  ))
  on.exit(lapply(walk_forward$test_runs, close), add = TRUE)
  scores <- walk_forward$scores
  train_final <- scores$metric_value[scores$window == "train" & scores$metric_name == "final_equity"][[1L]]
  testthat::expect_identical(train_final, 1000)
  testthat::expect_identical(
    ledgr:::ledgr_walk_forward_iso(walk_forward$folds$hydration_start_utc[[1L]]),
    feature_start_iso(6L)
  )
  testthat::expect_identical(final(walk_forward$test_runs[[1L]]), 1000)

  # Fixed-window witness: hold one share once SMA(3) exists. Restarted on day
  # 6 it first exists on day 8, fills at the day-9 open of 9 and ends at 1001;
  # carried from day 1 it exists on day 6, fills at 7 and would end at 1003.
  # Training on days 6-8 restarted cannot fill (1000); carried it would buy at
  # 7 and close at 8 (1001).
  sma_strategy <- function(ctx, params) {
    value <- ctx$feature("AAA", "sma_3")
    target <- ctx$flat()
    if (!is.na(value)) target[["AAA"]] <- 1
    target
  }
  sma_dated <- ledgr_experiment(
    snapshot, sma_strategy, features = features,
    opening = ledgr_opening(cash = 1000, date = feature_start_iso(6L)),
    cost_model = ledgr_cost_zero()
  )
  sma_undated <- ledgr_experiment(
    snapshot, sma_strategy, features = features,
    opening = ledgr_opening(cash = 1000),
    cost_model = ledgr_cost_zero()
  )
  sma_run <- ledgr_run(sma_dated, run_id = "feature-start-sma-run")
  on.exit(close(sma_run), add = TRUE)
  sma_precomputed <- ledgr_precompute_features(sma_dated, grid)
  sma_finals <- c(
    run = final(sma_run),
    sweep = ledgr_sweep(sma_dated, grid, workers = 1L, seed = 1L)$final_equity[[1L]],
    precomputed_sweep = ledgr_sweep(
      sma_dated, grid, precomputed_features = sma_precomputed, workers = 1L, seed = 1L
    )$final_equity[[1L]],
    window_sweep = ledgr:::ledgr_sweep_window(
      sma_undated, grid,
      window = ledgr:::ledgr_experiment_window(sma_undated, feature_start_iso(6L), feature_start_iso(10L)),
      workers = 1L, seed = 1L
    )$final_equity[[1L]]
  )
  testthat::expect_identical(sma_finals, stats::setNames(rep(1001, 4L), names(sma_finals)))
  # A payload whose scoring range matches but whose feature state starts on
  # day 1, as one built before Cut 9 would, is refused by the sweep itself.
  stale <- sma_precomputed
  stale$warmup_range$start <- feature_start_iso(1L)
  testthat::expect_error(
    ledgr_sweep(sma_dated, grid, precomputed_features = stale, workers = 1L, seed = 1L),
    "`precomputed_features` feature state starts at 2020-01-01T00:00:00Z",
    class = "ledgr_precomputed_hydration_mismatch",
    fixed = TRUE
  )
  sma_walk_forward <- suppressWarnings(ledgr_walk_forward(
    sma_undated, grid, folds,
    selection_rule = ledgr_rule_argmax("annualized_return"), seed = 1L
  ))
  on.exit(lapply(sma_walk_forward$test_runs, close), add = TRUE)
  sma_scores <- sma_walk_forward$scores
  testthat::expect_identical(
    sma_scores$metric_value[sma_scores$window == "train" & sma_scores$metric_name == "final_equity"][[1L]],
    1000
  )
})

testthat::test_that("[LTB-0197] hydration is stored as the scoring start and earlier starts refuse", {
  snapshot <- feature_start_snapshot(as.numeric(1:10))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  experiment <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$flat(),
    features = list(ledgr_ind_sma(3L)),
    opening = ledgr_opening(cash = 1000),
    cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_param_grid(only = list())

  window <- ledgr:::ledgr_experiment_window(experiment, feature_start_iso(6L), feature_start_iso(10L))
  testthat::expect_identical(window$hydration_start_utc, window$scoring_start_utc)
  fold <- ledgr_fold(feature_start_iso(4L), feature_start_iso(6L), feature_start_iso(7L), feature_start_iso(9L))
  train <- ledgr:::ledgr_experiment_window_from_fold(experiment, fold, window = "train")
  testthat::expect_identical(ledgr:::ledgr_walk_forward_iso(train$hydration_start_utc), feature_start_iso(4L))

  testthat::expect_error(
    ledgr:::ledgr_experiment_window(
      experiment, feature_start_iso(6L), feature_start_iso(10L),
      hydration_start_utc = feature_start_iso(1L)
    ),
    paste(
      "`hydration_start_utc` (2020-01-01T00:00:00Z) differs from the scoring start",
      "(2020-01-06T00:00:00Z). Feature state starts at the scoring start; hydration",
      "from earlier history is planned with the point-in-time history design. Omit",
      "`hydration_start_utc` or set it equal to `start_utc`."
    ),
    class = "ledgr_unsupported_hydration_start",
    fixed = TRUE
  )

  # Precompute never reads before its start, and a window refuses a payload
  # whose feature state starts earlier than its own.
  explicit <- ledgr_precompute_features(experiment, grid, start = feature_start_iso(6L))
  testthat::expect_identical(explicit$warmup_range$start, feature_start_iso(6L))
  full <- ledgr_precompute_features(experiment, grid)
  testthat::expect_identical(full$warmup_range$start, feature_start_iso(1L))
  testthat::expect_error(
    ledgr:::ledgr_validate_precomputed_features(full, experiment, grid, window = window),
    "`precomputed_features` feature state starts at 2020-01-01T00:00:00Z",
    class = "ledgr_precomputed_hydration_mismatch",
    fixed = TRUE
  )
  testthat::expect_true(ledgr:::ledgr_validate_precomputed_features(explicit, experiment, grid, window = window))

  # An ordinary sweep validates a payload whose scoring range matches but
  # whose feature state starts earlier, as one built before Cut 9 would, with
  # this check; LTB-0196 asserts the same refusal through ledgr_sweep().
  dated <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$flat(),
    features = list(ledgr_ind_sma(3L)),
    opening = ledgr_opening(cash = 1000, date = feature_start_iso(6L)),
    cost_model = ledgr_cost_zero()
  )
  stale <- ledgr_precompute_features(dated, grid)
  stale$warmup_range$start <- feature_start_iso(1L)
  testthat::expect_error(
    ledgr:::ledgr_validate_precomputed_features(stale, dated, grid),
    "`precomputed_features` feature state starts at 2020-01-01T00:00:00Z",
    class = "ledgr_precomputed_hydration_mismatch",
    fixed = TRUE
  )
})
