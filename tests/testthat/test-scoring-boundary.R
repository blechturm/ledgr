# Cut 9 Workstream 18: every entry point evaluates, executes and records
# results from the declared scoring start. Feature-free strategies isolate the
# boundary from feature-start semantics, which Workstream 19 owns.

scoring_boundary_day <- function(d) {
  as.POSIXct(paste(as.Date("2020-01-01") + d - 1L, "00:00:00"), tz = "UTC")
}

scoring_boundary_iso <- function(d) {
  format(scoring_boundary_day(d), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

scoring_boundary_snapshot <- function() {
  ledgr_snapshot_from_df(
    data.frame(
      instrument_id = "AAA",
      ts_utc = scoring_boundary_day(1:10),
      open = as.numeric(1:10),
      high = 1:10 + 0.5,
      low = 1:10 - 0.5,
      close = as.numeric(1:10),
      volume = 1000
    ),
    db_path = tempfile(fileext = ".duckdb")
  )
}

scoring_boundary_equity <- function(x) {
  data.frame(
    ts_utc = as.Date(x$ts_utc),
    equity = as.numeric(x$equity)
  )
}

# ledgr-test-profile: review
testthat::test_that("[LTB-0192] run, backtest, sweep, promotion and walk-forward share the scoring start", {
  snapshot <- scoring_boundary_snapshot()
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  always_long <- function(ctx, params) {
    target <- ctx$flat()
    target[["AAA"]] <- 1
    target
  }
  dated <- ledgr_experiment(
    snapshot,
    always_long,
    opening = ledgr_opening(cash = 1000, date = scoring_boundary_iso(6L)),
    cost_model = ledgr_cost_zero()
  )
  undated <- ledgr_experiment(
    snapshot,
    always_long,
    opening = ledgr_opening(cash = 1000),
    cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_param_grid(only = list())
  retain <- ledgr_sweep_retention(returns = "completed")

  # Day 6 decides, day 7 fills at open 7, day 10 closes at 10.
  expected <- data.frame(
    ts_utc = as.Date("2020-01-01") + 5:9,
    equity = c(1000, 1000, 1001, 1002, 1003)
  )
  run <- ledgr_run(dated, run_id = "scoring-boundary-run")
  on.exit(close(run), add = TRUE)
  testthat::expect_identical(scoring_boundary_equity(ledgr_results(run, "equity")), expected)

  backtest <- ledgr_backtest(
    snapshot = snapshot, strategy = always_long, universe = "AAA",
    start = scoring_boundary_iso(6L), initial_cash = 1000,
    cost_model = ledgr_cost_zero(), run_id = "scoring-boundary-backtest"
  )
  on.exit(close(backtest), add = TRUE)
  testthat::expect_identical(scoring_boundary_equity(ledgr_results(backtest, "equity")), expected)

  sweep <- ledgr_sweep(dated, grid, retain = retain, workers = 1L, seed = 1L)
  testthat::expect_identical(attr(sweep, "scoring_range")$start, scoring_boundary_iso(6L))
  testthat::expect_identical(scoring_boundary_equity(ledgr_sweep_returns(sweep)), expected)
  testthat::expect_identical(sweep$final_equity[[1L]], 1003)

  precomputed <- ledgr_precompute_features(dated, grid)
  testthat::expect_identical(precomputed$scoring_range$start, scoring_boundary_iso(6L))
  precomputed_sweep <- ledgr_sweep(
    dated, grid, precomputed_features = precomputed,
    retain = retain, workers = 1L, seed = 1L
  )
  testthat::expect_identical(scoring_boundary_equity(ledgr_sweep_returns(precomputed_sweep)), expected)

  promoted <- ledgr_promote(dated, ledgr_candidate(sweep, 1L), run_id = "scoring-boundary-promote")
  on.exit(close(promoted), add = TRUE)
  testthat::expect_identical(scoring_boundary_equity(ledgr_results(promoted, "equity")), expected)

  window <- ledgr:::ledgr_experiment_window(undated, scoring_boundary_iso(6L), scoring_boundary_iso(10L))
  window_sweep <- ledgr:::ledgr_sweep_window(undated, grid, window = window, retain = retain, workers = 1L, seed = 1L)
  testthat::expect_identical(scoring_boundary_equity(ledgr_sweep_returns(window_sweep)), expected)

  folds <- ledgr:::ledgr_fold_list(
    list(ledgr_fold(scoring_boundary_iso(6L), scoring_boundary_iso(8L),
                    scoring_boundary_iso(9L), scoring_boundary_iso(10L), fold_seq = 1L)),
    constructor = list(type_id = "explicit")
  )
  walk_forward <- suppressWarnings(ledgr_walk_forward(
    undated, grid, folds,
    selection_rule = ledgr_rule_argmax("sharpe_ratio"), seed = 1L
  ))
  on.exit(lapply(walk_forward$test_runs, close), add = TRUE)
  scores <- walk_forward$scores
  train_score <- function(metric) {
    scores$metric_value[scores$window == "train" & scores$metric_name == metric][[1L]]
  }
  # Training over days 6-8: fill at open 7, close 8; held on two of three pulses.
  testthat::expect_identical(train_score("final_equity"), 1001)
  testthat::expect_equal(train_score("time_in_market"), 2 / 3, tolerance = 1e-12)
  test_equity <- ledgr_results(walk_forward$test_runs[[1L]], "equity")
  testthat::expect_identical(as.Date(min(test_equity$ts_utc)), as.Date("2020-01-09"))
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0193] a dated availability sweep executes and values like a run", {
  snapshot <- terminal_outcome_snapshot(list(
    AAA = c(1, 2, 3, 4, 5, 6, 7, NA, 9, 10)
  ))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  experiment <- ledgr_experiment(
    snapshot,
    function(ctx, params) {
      target <- ctx$hold()
      target[["AAA"]] <- 2
      target
    },
    opening = ledgr_opening(
      cash = 1000,
      date = "2020-01-06",
      positions = c(AAA = 1),
      cost_basis = c(AAA = 1)
    ),
    valuation_policy = ledgr_valuation_stale(2L),
    cost_model = ledgr_cost_zero()
  )
  run <- ledgr_run(experiment, run_id = "scoring-boundary-availability")
  on.exit(close(run), add = TRUE)
  run_equity <- scoring_boundary_equity(ledgr_results(run, "equity"))
  # Day 6 decides; the next session opens at 7, so one more share costs 7.
  # Day 8 has no bar and is valued at the stale day-7 close.
  testthat::expect_identical(run_equity$ts_utc, as.Date("2020-01-01") + 5:9)
  testthat::expect_identical(run_equity$equity, c(1006, 1007, 1007, 1011, 1013))
  fills <- ledgr_results(run, "fills")
  testthat::expect_identical(nrow(fills), 1L)
  testthat::expect_identical(as.numeric(fills$price), 7)

  sweep <- ledgr_sweep(
    experiment,
    ledgr_param_grid(only = list()),
    retain = ledgr_sweep_retention(returns = "completed"),
    workers = 1L,
    seed = 1L
  )
  testthat::expect_identical(sweep$status[[1L]], "DONE")
  testthat::expect_identical(scoring_boundary_equity(ledgr_sweep_returns(sweep)), run_equity)
})

testthat::test_that("[LTB-0194] a distinct execution start refuses before execution", {
  snapshot <- scoring_boundary_snapshot()
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  experiment <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$flat(),
    opening = ledgr_opening(cash = 1000),
    cost_model = ledgr_cost_zero()
  )
  testthat::expect_error(
    ledgr:::ledgr_experiment_window(
      experiment, scoring_boundary_iso(6L), scoring_boundary_iso(10L),
      execution_start_utc = scoring_boundary_iso(7L)
    ),
    paste(
      "`execution_start_utc` (2020-01-07T00:00:00Z) differs from the scoring start",
      "(2020-01-06T00:00:00Z). Execution starts at the scoring start; omit",
      "`execution_start_utc` or set it equal to `start_utc`."
    ),
    class = "ledgr_unsupported_execution_start",
    fixed = TRUE
  )
  same <- ledgr:::ledgr_experiment_window(
    experiment, scoring_boundary_iso(6L), scoring_boundary_iso(10L),
    execution_start_utc = scoring_boundary_iso(6L)
  )
  testthat::expect_identical(same$execution_start_utc, same$scoring_start_utc)
})
