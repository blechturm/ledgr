testthat::test_that("strategy helper value types validate shape and print", {
  signal <- ledgr_signal(c(BBB = 0.2, AAA = NA_real_), universe = c("AAA", "BBB"), origin = "test_signal")
  selection <- ledgr_selection(c(AAA = TRUE, BBB = FALSE), universe = c("AAA", "BBB"))
  empty_selection <- ledgr_selection(logical())
  weights <- ledgr_weights(c(AAA = 0.5, BBB = 0.5), universe = c("AAA", "BBB"))
  empty_weights <- ledgr_weights(numeric())
  target <- ledgr_target(c(BBB = 2, AAA = 1), universe = c("AAA", "BBB"), origin = "test_target")

  testthat::expect_s3_class(signal, "ledgr_signal")
  testthat::expect_s3_class(selection, "ledgr_selection")
  testthat::expect_s3_class(empty_selection, "ledgr_selection")
  testthat::expect_s3_class(weights, "ledgr_weights")
  testthat::expect_s3_class(empty_weights, "ledgr_weights")
  testthat::expect_s3_class(target, "ledgr_target")

  testthat::expect_output(print(signal), "<ledgr_signal>", fixed = TRUE)
  testthat::expect_output(print(selection), "<ledgr_selection>", fixed = TRUE)
  testthat::expect_output(print(weights), "<ledgr_weights>", fixed = TRUE)
  testthat::expect_output(print(target), "<ledgr_target>", fixed = TRUE)

  testthat::expect_error(
    ledgr_signal(c(AAA = Inf)),
    class = "ledgr_invalid_strategy_type"
  )
  testthat::expect_error(
    ledgr_signal(c(0.2, 0.5)),
    class = "ledgr_invalid_strategy_type"
  )
  testthat::expect_error(
    ledgr_selection(c(AAA = NA)),
    class = "ledgr_invalid_strategy_type"
  )
  testthat::expect_error(
    ledgr_weights(c(AAA = NA_real_)),
    class = "ledgr_invalid_strategy_type"
  )
  testthat::expect_error(
    ledgr_target(c(AAA = 1), universe = c("AAA", "BBB")),
    "missing instruments: BBB",
    fixed = TRUE,
    class = "ledgr_invalid_strategy_type"
  )
})

testthat::test_that("ledgr_target unwraps through the strategy target validator", {
  universe <- c("AAA", "BBB")
  target <- ledgr_target(c(BBB = 2, AAA = 1), universe = universe)

  out <- ledgr:::ledgr_validate_strategy_targets(target, universe)
  testthat::expect_identical(out, c(AAA = 1, BBB = 2))
  testthat::expect_false(inherits(out, "ledgr_target"))

  testthat::expect_error(
    ledgr:::ledgr_validate_strategy_targets(ledgr_signal(c(AAA = 1, BBB = 2)), universe),
    "must not return `ledgr_signal` directly",
    fixed = TRUE,
    class = "ledgr_invalid_strategy_result"
  )
  testthat::expect_error(
    ledgr:::ledgr_validate_strategy_targets(ledgr_weights(c(AAA = 0.5, BBB = 0.5)), universe),
    "must not return `ledgr_weights` directly",
    fixed = TRUE,
    class = "ledgr_invalid_strategy_result"
  )
})

testthat::test_that("functional strategies may return ledgr_target", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  bars <- ledgr_test_make_bars(
    instrument_ids = c("AAA", "BBB"),
    ts_utc = c("2020-01-01", "2020-01-02", "2020-01-03")
  )
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    ledgr_target(c(AAA = params$qty, BBB = 0), universe = ctx$universe)
  }
  exp <- ledgr_experiment(snapshot = snapshot, strategy = strategy)
  bt <- ledgr_run(exp, params = list(qty = 1), run_id = "target-return-run")
  on.exit(close(bt), add = TRUE)

  fills <- ledgr_results(bt, what = "fills")
  testthat::expect_true(nrow(fills) > 0L)
  testthat::expect_true(all(fills$instrument_id == "AAA"))
})

testthat::test_that("intermediate strategy helper types fail when returned directly", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  bars <- ledgr_test_make_bars(
    instrument_ids = c("AAA", "BBB"),
    ts_utc = c("2020-01-01", "2020-01-02", "2020-01-03")
  )
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  make_exp <- function(strategy) ledgr_experiment(snapshot = snapshot, strategy = strategy)

  testthat::expect_error(
    ledgr_run(
      make_exp(function(ctx, params) ledgr_signal(c(AAA = 1, BBB = 2), universe = ctx$universe)),
      run_id = "bad-signal-return"
    ),
    "must not return `ledgr_signal` directly",
    fixed = TRUE,
    class = "ledgr_invalid_strategy_result"
  )
  testthat::expect_error(
    ledgr_run(
      make_exp(function(ctx, params) ledgr_selection(c(AAA = TRUE, BBB = FALSE), universe = ctx$universe)),
      run_id = "bad-selection-return"
    ),
    "must not return `ledgr_selection` directly",
    fixed = TRUE,
    class = "ledgr_invalid_strategy_result"
  )
  testthat::expect_error(
    ledgr_run(
      make_exp(function(ctx, params) ledgr_weights(c(AAA = 0.5, BBB = 0.5), universe = ctx$universe)),
      run_id = "bad-weights-return"
    ),
    "must not return `ledgr_weights` directly",
    fixed = TRUE,
    class = "ledgr_invalid_strategy_result"
  )
})
