ledgr_metric_context_table_bars <- function() {
  data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:5,
    instrument_id = "AAA",
    open = c(100, 101, 103, 102, 105, 106),
    high = c(100, 101, 103, 102, 105, 106),
    low = c(100, 101, 103, 102, 105, 106),
    close = c(100, 101, 103, 102, 105, 106),
    volume = 1,
    stringsAsFactors = FALSE
  )
}

testthat::test_that("comparison tables carry exactly one metric context", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  snapshot <- ledgr_snapshot_from_df(ledgr_metric_context_table_bars(), db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    universe = "AAA",
    opening = ledgr_opening(cash = 1000),
    metric_context = ledgr_metric_context(risk_free_rate = 0.04),
  cost_model = ledgr_cost_zero()
  )
  bt_a <- ledgr_run(exp, params = list(qty = 1), run_id = "compare-context-a")
  on.exit(close(bt_a), add = TRUE)
  bt_b <- ledgr_run(exp, params = list(qty = 2), run_id = "compare-context-b")
  on.exit(close(bt_b), add = TRUE)

  default_cmp <- ledgr_compare_runs(snapshot, run_ids = c("compare-context-a", "compare-context-b"))
  explicit_cmp <- ledgr_compare_runs(
    snapshot,
    run_ids = c("compare-context-a", "compare-context-b"),
    metric_context = ledgr_metric_context(exp)
  )

  testthat::expect_s3_class(default_cmp, "ledgr_comparison")
  testthat::expect_equal(ledgr_metric_context(default_cmp)$risk_free_rate$annual_rate, 0)
  testthat::expect_equal(ledgr_metric_context(explicit_cmp)$risk_free_rate$annual_rate, 0.04)
  testthat::expect_false(isTRUE(all.equal(
    default_cmp$sharpe_ratio,
    explicit_cmp$sharpe_ratio,
    tolerance = 1e-12
  )))
})

testthat::test_that("comparison tables fail loudly for mixed observed cadences", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  snapshot <- ledgr_snapshot_from_df(ledgr_metric_context_table_bars(), db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  exp <- ledgr_experiment(snapshot = snapshot, strategy = strategy, universe = "AAA", cost_model = ledgr_cost_zero())
  bt_a <- ledgr_run(exp, params = list(qty = 1), run_id = "mixed-daily")
  on.exit(close(bt_a), add = TRUE)
  bt_b <- ledgr_run(exp, params = list(qty = 2), run_id = "mixed-hourly")
  on.exit(close(bt_b), add = TRUE)

  con <- get_connection(snapshot)
  DBI::dbExecute(
    con,
    "
    UPDATE equity_curve AS e
    SET ts_utc = shifted.new_ts
    FROM (
      SELECT
        run_id,
        ts_utc AS old_ts,
        CAST('2020-01-01 00:00:00' AS TIMESTAMP) +
          (row_number() OVER (ORDER BY ts_utc) - 1) * INTERVAL 1 HOUR AS new_ts
      FROM equity_curve
      WHERE run_id = 'mixed-hourly'
    ) shifted
    WHERE e.run_id = shifted.run_id
      AND e.ts_utc = shifted.old_ts
    "
  )

  testthat::expect_error(
    ledgr_compare_runs(snapshot, run_ids = c("mixed-daily", "mixed-hourly")),
    "mixed observed bar cadences",
    class = "ledgr_mixed_metric_cadence"
  )
})

testthat::test_that("sweep and promotion disclose source sweep metric context separately", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  snapshot <- ledgr_snapshot_from_df(ledgr_metric_context_table_bars(), db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  sweep_exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    universe = "AAA",
    opening = ledgr_opening(cash = 1000),
    metric_context = ledgr_metric_context(
      risk_free_rate = ledgr_risk_free_rate(0.04, label = "source sweep")
    ),
  cost_model = ledgr_cost_zero()
  )
  run_exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    universe = "AAA",
    opening = ledgr_opening(cash = 1000),
    metric_context = ledgr_metric_context(
      risk_free_rate = ledgr_risk_free_rate(0.01, label = "committed run")
    ),
  cost_model = ledgr_cost_zero()
  )

  results <- ledgr_sweep(sweep_exp, ledgr_param_grid(a = list(qty = 1), b = list(qty = 2)), seed = 123L)
  testthat::expect_s3_class(results, "ledgr_sweep_results")
  testthat::expect_equal(ledgr_metric_context(results)$risk_free_rate$annual_rate, 0.04)
  testthat::expect_identical(attr(results, "metric_context_hash"), ledgr_metric_context_hash(ledgr_metric_context(results)))

  selection <- results[c(2, 1), ]
  candidate <- ledgr_candidate(selection, 1)
  testthat::expect_equal(candidate$sweep_meta$metric_context$risk_free_rate$annual_rate, 0.04)

  promoted <- ledgr_promote(run_exp, candidate, run_id = "promoted-metric-context")
  on.exit(close(promoted), add = TRUE)
  promotion_context <- ledgr_promotion_context(promoted)

  testthat::expect_s3_class(promotion_context, "ledgr_promotion_context")
  testthat::expect_equal(ledgr_metric_context(promoted)$risk_free_rate$annual_rate, 0.01)
  testthat::expect_equal(ledgr_metric_context(promotion_context)$risk_free_rate$annual_rate, 0.04)
  testthat::expect_identical(promotion_context$source_sweep$metric_context$risk_free_rate$label, "source sweep")
})
