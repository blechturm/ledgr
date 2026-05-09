ledgr_metric_oracle_rf_period_return <- function(risk_free_rate, bars_per_year) {
  if (!is.numeric(risk_free_rate) || length(risk_free_rate) != 1L ||
    !is.finite(risk_free_rate) || risk_free_rate <= -1) {
    return(NA_real_)
  }
  if (!is.numeric(bars_per_year) || length(bars_per_year) != 1L ||
    !is.finite(bars_per_year) || bars_per_year <= 0) {
    return(NA_real_)
  }
  (1 + risk_free_rate)^(1 / bars_per_year) - 1
}

ledgr_metric_oracle_sharpe <- function(period_returns, bars_per_year, risk_free_rate = 0) {
  period_returns <- as.numeric(period_returns)
  if (length(period_returns) < 2L || any(!is.finite(period_returns))) {
    return(NA_real_)
  }
  rf_period_return <- ledgr_metric_oracle_rf_period_return(risk_free_rate, bars_per_year)
  if (!is.finite(rf_period_return)) return(NA_real_)
  excess_returns <- period_returns - rf_period_return
  sd_excess <- stats::sd(excess_returns)
  if (!is.finite(sd_excess) || sd_excess <= .Machine$double.eps) {
    return(NA_real_)
  }
  mean(excess_returns) / sd_excess * sqrt(bars_per_year)
}

ledgr_metric_oracle <- function(bt, bars_per_year = 252, risk_free_rate = 0) {
  equity <- tibble::as_tibble(ledgr_results(bt, what = "equity"))
  trades <- tibble::as_tibble(ledgr_results(bt, what = "trades"))

  eq <- as.numeric(equity$equity)
  pos_value <- as.numeric(equity$positions_value)
  initial_equity <- if (length(eq) > 0L) eq[[1]] else NA_real_
  final_equity <- if (length(eq) > 0L) eq[[length(eq)]] else NA_real_
  total_return <- if (length(eq) > 0L && is.finite(initial_equity) && initial_equity != 0 && is.finite(final_equity)) {
    final_equity / initial_equity - 1
  } else {
    NA_real_
  }

  annualized_return <- NA_real_
  if (length(eq) >= 2L && is.finite(total_return) && is.finite(bars_per_year) && bars_per_year > 0) {
    years <- (length(eq) - 1L) / bars_per_year
    if (years > 0) {
      annualized_return <- (1 + total_return)^(1 / years) - 1
    }
  }

  period_returns <- numeric()
  if (length(eq) > 1L) {
    prev <- eq[-length(eq)]
    cur <- eq[-1L]
    period_returns <- rep(NA_real_, length(cur))
    ok <- is.finite(prev) & is.finite(cur) & prev != 0
    period_returns[ok] <- cur[ok] / prev[ok] - 1
  }

  running_max <- cummax(eq)
  drawdown <- eq / running_max - 1
  max_drawdown <- if (length(drawdown) > 0L) suppressWarnings(min(drawdown, na.rm = TRUE)) else NA_real_
  if (is.infinite(max_drawdown)) max_drawdown <- NA_real_

  n_trades <- nrow(trades)
  realized <- as.numeric(trades$realized_pnl)

  list(
    total_return = total_return,
    annualized_return = annualized_return,
    volatility = if (length(period_returns) > 1L && all(is.finite(period_returns))) {
      sd_returns <- stats::sd(period_returns)
      if (is.finite(sd_returns)) sd_returns * sqrt(bars_per_year) else NA_real_
    } else {
      NA_real_
    },
    sharpe_ratio = ledgr_metric_oracle_sharpe(period_returns, bars_per_year, risk_free_rate = risk_free_rate),
    max_drawdown = max_drawdown,
    n_trades = as.integer(n_trades),
    win_rate = if (n_trades > 0L) sum(realized > 0, na.rm = TRUE) / n_trades else NA_real_,
    avg_trade = if (n_trades > 0L) mean(realized, na.rm = TRUE) else NA_real_,
    time_in_market = if (length(pos_value) > 0L) mean(abs(pos_value) > 1e-6) else NA_real_
  )
}

ledgr_expect_metric_list_equal <- function(actual, expected) {
  for (name in names(expected)) {
    if (is.na(expected[[name]])) {
      testthat::expect_true(is.na(actual[[name]]), info = name)
    } else if (identical(name, "n_trades")) {
      testthat::expect_identical(as.integer(actual[[name]]), expected[[name]], info = name)
    } else {
      testthat::expect_equal(actual[[name]], expected[[name]], tolerance = 1e-10, info = name)
    }
  }
}

ledgr_metric_bars <- function(prices, instrument_id = "AAA", start = "2020-01-01") {
  ts <- as.POSIXct(start, tz = "UTC") + 86400 * (seq_along(prices) - 1L)
  data.frame(
    ts_utc = ts,
    instrument_id = instrument_id,
    open = prices,
    high = prices,
    low = prices,
    close = prices,
    volume = 1,
    stringsAsFactors = FALSE
  )
}

ledgr_metric_fixture <- function(name) {
  day <- function(n) ledgr_utc(as.POSIXct("2020-01-01", tz = "UTC") + 86400 * (n - 1L))

  switch(
    name,
    flat = list(
      bars = ledgr_metric_bars(c(100, 101, 102, 103, 104)),
      strategy = function(ctx, params) ctx$flat(),
      initial_cash = 1000
    ),
    open_only = list(
      bars = ledgr_metric_bars(c(100, 101, 105, 110, 108)),
      strategy = function(ctx, params) {
        targets <- ctx$flat()
        targets["AAA"] <- 2
        targets
      },
      initial_cash = 1000
    ),
    profit_roundtrip = list(
      bars = ledgr_metric_bars(c(100, 101, 105, 106, 106)),
      strategy = function(ctx, params) {
        targets <- ctx$flat()
        if (ledgr_utc(ctx$ts_utc) == day(1)) targets["AAA"] <- 1
        targets
      },
      initial_cash = 1000
    ),
    loss_roundtrip = list(
      bars = ledgr_metric_bars(c(100, 105, 101, 101, 101)),
      strategy = function(ctx, params) {
        targets <- ctx$flat()
        if (ledgr_utc(ctx$ts_utc) == day(1)) targets["AAA"] <- 1
        targets
      },
      initial_cash = 1000
    ),
    multi_instrument = {
      bars <- rbind(
        ledgr_metric_bars(c(100, 101, 103, 103, 103), "AAA"),
        ledgr_metric_bars(c(50, 52, 49, 49, 49), "BBB")
      )
      list(
        bars = bars,
        strategy = function(ctx, params) {
          targets <- ctx$flat()
          if (ledgr_utc(ctx$ts_utc) == day(1)) {
            targets["AAA"] <- 1
            targets["BBB"] <- 2
          }
          targets
        },
        initial_cash = 1000
      )
    },
    final_bar_no_fill = list(
      bars = ledgr_metric_bars(c(100, 101, 102, 103, 104)),
      strategy = function(ctx, params) {
        targets <- ctx$flat()
        if (ledgr_utc(ctx$ts_utc) == day(5)) targets["AAA"] <- 1
        targets
      },
      initial_cash = 1000,
      expect_warning = TRUE
    ),
    helper_flooring = list(
      bars = ledgr_metric_bars(c(100, 101, 101, 101, 101)),
      strategy = function(ctx, params) {
        weights <- ledgr_weights(c(AAA = 1))
        target_rebalance(weights, ctx, equity_fraction = 0.255)
      },
      initial_cash = 1000
    ),
    stop(sprintf("Unknown metric fixture: %s", name), call. = FALSE)
  )
}

ledgr_run_metric_fixture <- function(name) {
  fixture <- ledgr_metric_fixture(name)
  db_path <- tempfile(fileext = ".duckdb")
  bt_expr <- quote(ledgr_backtest(
    data = fixture$bars,
    strategy = fixture$strategy,
    initial_cash = fixture$initial_cash,
    db_path = db_path,
    run_id = paste0("metric-", name)
  ))
  bt <- if (isTRUE(fixture$expect_warning)) {
    warned <- FALSE
    value <- withCallingHandlers(
      eval(bt_expr),
      warning = function(w) {
        if (grepl("LEDGR_LAST_BAR_NO_FILL", conditionMessage(w), fixed = TRUE)) {
          warned <<- TRUE
          invokeRestart("muffleWarning")
        }
      }
    )
    testthat::expect_true(warned)
    value
  } else {
    eval(bt_expr)
  }
  list(bt = bt, db_path = db_path)
}

testthat::test_that("standard metrics match independent public-table oracles", {
  fixtures <- c(
    "flat",
    "open_only",
    "profit_roundtrip",
    "loss_roundtrip",
    "multi_instrument",
    "final_bar_no_fill",
    "helper_flooring"
  )

  for (fixture_name in fixtures) {
    local({
      name <- fixture_name
      run <- ledgr_run_metric_fixture(name)
      bt <- run$bt
      on.exit(close(bt), add = TRUE)
      on.exit(unlink(run$db_path), add = TRUE)

      # The deterministic fixtures use daily bars; ledgr's current estimator
      # snaps that cadence to the standard 252-bar trading-year constant.
      expected <- ledgr_metric_oracle(bt, bars_per_year = 252)
      actual <- ledgr_compute_metrics(bt)

      ledgr_expect_metric_list_equal(actual, expected)

      fills <- tibble::as_tibble(ledgr_results(bt, what = "fills"))
      trades <- tibble::as_tibble(ledgr_results(bt, what = "trades"))
      testthat::expect_identical(actual$n_trades, as.integer(nrow(trades)), info = name)
      testthat::expect_false(identical(actual$n_trades, as.integer(nrow(fills))) && nrow(fills) != nrow(trades), info = name)
    })
  }
})

testthat::test_that("summary, comparison, and run-list metrics use the same definitions", {
  run <- ledgr_run_metric_fixture("multi_instrument")
  bt <- run$bt
  on.exit(close(bt), add = TRUE)
  on.exit(unlink(run$db_path), add = TRUE)
  snapshot <- ledgr_test_snapshot_for_run(run$db_path, bt)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  expected <- ledgr_metric_oracle(bt, bars_per_year = 252)
  actual <- ledgr_compute_metrics(bt)
  cmp <- ledgr_compare_runs(snapshot, run_ids = bt$run_id)
  listed <- ledgr_run_list(snapshot)
  listed <- listed[match(bt$run_id, listed$run_id), , drop = FALSE]

  testthat::expect_equal(cmp$total_return[[1]], expected$total_return, tolerance = 1e-10)
  testthat::expect_equal(cmp$annualized_return[[1]], expected$annualized_return, tolerance = 1e-10)
  testthat::expect_equal(cmp$volatility[[1]], expected$volatility, tolerance = 1e-10)
  testthat::expect_equal(cmp$sharpe_ratio[[1]], expected$sharpe_ratio, tolerance = 1e-10)
  testthat::expect_equal(cmp$max_drawdown[[1]], expected$max_drawdown, tolerance = 1e-10)
  testthat::expect_identical(cmp$n_trades[[1]], expected$n_trades)
  testthat::expect_equal(cmp$win_rate[[1]], expected$win_rate, tolerance = 1e-10)
  testthat::expect_equal(cmp$avg_trade[[1]], expected$avg_trade, tolerance = 1e-10)
  testthat::expect_equal(cmp$time_in_market[[1]], expected$time_in_market, tolerance = 1e-10)

  testthat::expect_equal(listed$total_return[[1]], actual$total_return, tolerance = 1e-10)
  testthat::expect_equal(listed$max_drawdown[[1]], actual$max_drawdown, tolerance = 1e-10)
  testthat::expect_identical(listed$n_trades[[1]], actual$n_trades)
  testthat::expect_false("annualized_return" %in% names(listed))
  testthat::expect_false("volatility" %in% names(listed))
  testthat::expect_false("sharpe_ratio" %in% names(listed))
  testthat::expect_false("avg_trade" %in% names(listed))
  testthat::expect_false("time_in_market" %in% names(listed))
})

testthat::test_that("sharpe ratio uses geometric scalar risk-free conversion", {
  run <- ledgr_run_metric_fixture("multi_instrument")
  bt <- run$bt
  on.exit(close(bt), add = TRUE)
  on.exit(unlink(run$db_path), add = TRUE)

  expected_zero <- ledgr_metric_oracle(bt, bars_per_year = 252, risk_free_rate = 0)
  expected_rf <- ledgr_metric_oracle(bt, bars_per_year = 252, risk_free_rate = 0.02)
  actual_zero <- ledgr_compute_metrics(bt, risk_free_rate = 0)
  actual_rf <- ledgr_compute_metrics(bt, risk_free_rate = 0.02)

  testthat::expect_equal(actual_zero$sharpe_ratio, expected_zero$sharpe_ratio, tolerance = 1e-10)
  testthat::expect_equal(actual_rf$sharpe_ratio, expected_rf$sharpe_ratio, tolerance = 1e-10)
  testthat::expect_false(isTRUE(all.equal(actual_zero$sharpe_ratio, actual_rf$sharpe_ratio, tolerance = 1e-12)))

  summary_out <- capture.output(summary(bt, risk_free_rate = 0.02))
  testthat::expect_true(any(grepl("Sharpe Ratio", summary_out, fixed = TRUE)))
  testthat::expect_error(
    ledgr_compute_metrics(bt, risk_free_rate = -1),
    class = "ledgr_invalid_args"
  )
})

testthat::test_that("sharpe ratio edge cases return NA instead of Inf", {
  testthat::expect_true(is.na(ledgr:::compute_sharpe_ratio(numeric(0), 252)))
  testthat::expect_true(is.na(ledgr:::compute_sharpe_ratio(0.01, 252)))
  testthat::expect_true(is.na(ledgr:::compute_sharpe_ratio(c(0, 0, 0), 252)))
  testthat::expect_true(is.na(ledgr:::compute_sharpe_ratio(c(0.01, 0.01, 0.01), 252)))
  testthat::expect_true(is.na(ledgr:::compute_sharpe_ratio(c(0.01, NA_real_, 0.02), 252)))
  testthat::expect_true(is.na(ledgr:::compute_sharpe_ratio(c(0.01, 0.02, 0.03), NA_real_)))
  testthat::expect_true(is.na(ledgr:::compute_sharpe_ratio(c(0.01, 0.02, 0.03), 252, risk_free_rate = -1)))
})

testthat::test_that("zero-row trade metrics are explicit", {
  run <- ledgr_run_metric_fixture("flat")
  bt <- run$bt
  on.exit(close(bt), add = TRUE)
  on.exit(unlink(run$db_path), add = TRUE)

  metrics <- ledgr_compute_metrics(bt)
  trades <- ledgr_results(bt, what = "trades")

  testthat::expect_identical(nrow(trades), 0L)
  testthat::expect_identical(metrics$n_trades, 0L)
  testthat::expect_true(is.na(metrics$win_rate))
  testthat::expect_true(is.na(metrics$avg_trade))
  testthat::expect_true(is.na(metrics$sharpe_ratio))
})
