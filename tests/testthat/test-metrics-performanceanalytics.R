testthat::test_that("optional PerformanceAnalytics parity matches aligned ledgr metric definitions", {
  testthat::skip_if_not_installed("PerformanceAnalytics")
  testthat::skip_if_not_installed("xts")

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

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- 1
    targets
  }

  bt <- ledgr_backtest(
    data = bars,
    strategy = strategy,
    initial_cash = 1000,
    db_path = db_path,
    run_id = "pa-parity"
  )
  on.exit(close(bt), add = TRUE)

  risk_free_rate <- 0.02
  scale <- 252
  metrics <- ledgr_compute_metrics(bt, risk_free_rate = risk_free_rate)
  equity <- ledgr_results(bt, what = "equity")
  equity_values <- as.numeric(equity$equity)
  period_returns <- equity_values[-1] / equity_values[-length(equity_values)] - 1
  pa_returns <- xts::xts(period_returns, order.by = as.Date(equity$ts_utc[-1]))
  rf_period_return <- (1 + risk_free_rate)^(1 / scale) - 1

  testthat::expect_equal(
    metrics$annualized_return,
    as.numeric(PerformanceAnalytics::Return.annualized(pa_returns, scale = scale, geometric = TRUE)),
    tolerance = 1e-10
  )
  testthat::expect_equal(
    metrics$volatility,
    as.numeric(PerformanceAnalytics::StdDev.annualized(pa_returns, scale = scale)),
    tolerance = 1e-10
  )
  testthat::expect_equal(
    metrics$sharpe_ratio,
    as.numeric(PerformanceAnalytics::SharpeRatio.annualized(
      pa_returns,
      Rf = rf_period_return,
      scale = scale,
      geometric = FALSE
    )),
    tolerance = 1e-10
  )
})

testthat::test_that("PerformanceAnalytics remains optional parity evidence only", {
  root <- testthat::test_path("..", "..")
  description_path <- file.path(root, "DESCRIPTION")
  namespace_path <- file.path(root, "NAMESPACE")
  contracts_path <- file.path(root, "inst", "design", "contracts.md")
  testthat::skip_if_not(
    file.exists(description_path) && file.exists(namespace_path) && file.exists(contracts_path),
    "source package metadata not available during installed-package tests"
  )
  description <- read.dcf(description_path)
  imports <- unlist(strsplit(description[, "Imports"], "[,\n]"))
  imports <- trimws(imports)
  suggests <- unlist(strsplit(description[, "Suggests"], "[,\n]"))
  suggests <- trimws(suggests)
  namespace <- paste(readLines(namespace_path, warn = FALSE), collapse = "\n")
  contracts <- paste(readLines(contracts_path, warn = FALSE), collapse = "\n")

  testthat::expect_true("PerformanceAnalytics" %in% suggests)
  testthat::expect_false("PerformanceAnalytics" %in% imports)
  testthat::expect_no_match(namespace, "PerformanceAnalytics", fixed = TRUE)
  testthat::expect_match(contracts, "Optional PerformanceAnalytics parity tests are external evidence only", fixed = TRUE)
  testthat::expect_match(contracts, "must not redefine ledgr's\\s+owned metric formulas")
  testthat::expect_match(contracts, "runtime dependency", fixed = TRUE)
})
