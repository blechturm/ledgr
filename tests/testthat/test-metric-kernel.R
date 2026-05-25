ledgr_kernel_has_reference_state <- function(x) {
  if (is.environment(x) || is.function(x) || inherits(x, "externalptr")) {
    return(TRUE)
  }
  if (is.list(x)) {
    return(any(vapply(x, ledgr_kernel_has_reference_state, logical(1))))
  }
  FALSE
}

testthat::test_that("metric kernel is a serialization-safe plain list", {
  context <- ledgr_metric_us_equity(
    risk_free_rate = ledgr_risk_free_rate(0.04, label = "manual 4pct"),
    bars_per_day = 390L
  )

  kernel <- ledgr:::ledgr_metric_kernel(context = context)

  testthat::expect_type(kernel, "list")
  testthat::expect_false(is.object(kernel))
  testthat::expect_named(
    kernel,
    c(
      "metric_context",
      "metric_context_hash",
      "metric_context_version",
      "bars_per_year",
      "rf_period_return",
      "calendar"
    )
  )
  testthat::expect_equal(kernel$bars_per_year, 252 * 390)
  testthat::expect_equal(
    kernel$rf_period_return,
    (1 + 0.04)^(1 / (252 * 390)) - 1,
    tolerance = 1e-15
  )
  testthat::expect_identical(kernel$metric_context_version, 1L)
  testthat::expect_identical(kernel$metric_context$risk_free_rate$label, "manual 4pct")
  testthat::expect_false(ledgr_kernel_has_reference_state(kernel))

  json <- jsonlite::toJSON(kernel, auto_unbox = TRUE, null = "null")
  testthat::expect_type(jsonlite::fromJSON(json, simplifyVector = FALSE), "list")
})

testthat::test_that("single-run metrics use stored context by default and support ephemeral overrides", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  bars <- data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:5,
    instrument_id = "AAA",
    open = c(100, 101, 103, 102, 105, 106),
    high = c(100, 101, 103, 102, 105, 106),
    low = c(100, 101, 103, 102, 105, 106),
    close = c(100, 101, 103, 102, 105, 106),
    volume = 1,
    stringsAsFactors = FALSE
  )
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- 1
    targets
  }
  stored_context <- ledgr_metric_context(
    risk_free_rate = ledgr_risk_free_rate(0.04, label = "stored policy")
  )
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    universe = "AAA",
    opening = ledgr_opening(cash = 1000),
    metric_context = stored_context
  )
  bt <- ledgr_run(exp, run_id = "metric-context-run")
  on.exit(close(bt), add = TRUE)

  stored_metrics <- ledgr_compute_metrics(bt)
  zero_metrics <- ledgr_compute_metrics(bt, risk_free_rate = 0)
  explicit_metrics <- ledgr_compute_metrics(
    bt,
    metric_context = ledgr_metric_context(risk_free_rate = 0.02)
  )

  testthat::expect_s3_class(stored_metrics, "ledgr_metrics")
  testthat::expect_equal(ledgr_metric_context(stored_metrics)$risk_free_rate$annual_rate, 0.04)
  testthat::expect_equal(ledgr_metric_context(zero_metrics)$risk_free_rate$annual_rate, 0)
  testthat::expect_equal(ledgr_metric_context(explicit_metrics)$risk_free_rate$annual_rate, 0.02)
  testthat::expect_equal(ledgr_metric_context(bt)$risk_free_rate$annual_rate, 0.04)
  testthat::expect_false(isTRUE(all.equal(
    stored_metrics$sharpe_ratio,
    zero_metrics$sharpe_ratio,
    tolerance = 1e-12
  )))
  testthat::expect_false(isTRUE(all.equal(
    stored_metrics$sharpe_ratio,
    explicit_metrics$sharpe_ratio,
    tolerance = 1e-12
  )))
  testthat::expect_error(
    ledgr_compute_metrics(
      bt,
      metric_context = ledgr_metric_context(risk_free_rate = 0.01),
      risk_free_rate = 0.02
    ),
    class = "ledgr_invalid_args"
  )
  testthat::expect_error(
    ledgr_compute_metrics(bt, risk_free_rate = -1),
    "risk_free_rate",
    class = "ledgr_invalid_args"
  )
})

testthat::test_that("summary discloses risk-free rate and annualization assumptions", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- 1
    targets
  }
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    universe = "AAA",
    metric_context = ledgr_metric_context(
      risk_free_rate = ledgr_risk_free_rate(0.04, label = "stored policy")
    )
  )
  bt <- ledgr_run(exp, run_id = "metric-summary-context")
  on.exit(close(bt), add = TRUE)

  stored_out <- utils::capture.output(summary(bt))
  testthat::expect_true(any(grepl("Risk-Free Rate:      4.00% annual (stored policy)", stored_out, fixed = TRUE)))
  testthat::expect_true(any(grepl("Annualization:       252 periods/year (US equity daily)", stored_out, fixed = TRUE)))

  override_out <- utils::capture.output(summary(bt, risk_free_rate = 0))
  testthat::expect_true(any(grepl("Risk-Free Rate:      0.00% annual", override_out, fixed = TRUE)))
})
