ledgr_bars_per_year_from_pulses <- function(pulses_posix) {
  if (length(pulses_posix) < 2L) {
    return(252)
  }
  diffs <- as.numeric(diff(pulses_posix), units = "secs")
  snap_to_frequency(stats::median(diffs, na.rm = TRUE))
}

ledgr_metrics_from_equity_fills <- function(equity,
                                            fills,
                                            bars_per_year = 252,
                                            risk_free_rate = 0,
                                            metric_kernel = NULL) {
  if (!is.null(metric_kernel)) {
    bars_per_year <- metric_kernel$bars_per_year
    rf_period_return <- metric_kernel$rf_period_return
  } else {
    rf_period_return <- compute_rf_period_return(risk_free_rate, bars_per_year)
  }
  equity_values <- equity$equity
  total_return <- if (length(equity_values) == 0L ||
      !is.finite(equity_values[[1]]) ||
      equity_values[[1]] == 0) {
    NA_real_
  } else {
    equity_values[[length(equity_values)]] / equity_values[[1]] - 1
  }

  returns <- compute_period_returns(equity_values)
  closed <- ledgr_closed_trade_rows(fills)
  n_trades <- nrow(closed)
  win_rate <- if (n_trades == 0L) {
    NA_real_
  } else {
    mean(closed$realized_pnl > 0, na.rm = TRUE)
  }
  avg_trade <- if (n_trades == 0L) {
    NA_real_
  } else {
    mean(closed$realized_pnl, na.rm = TRUE)
  }

  list(
    total_return = total_return,
    annualized_return = compute_annualized_return(equity, bars_per_year),
    volatility = compute_annualized_volatility(returns, bars_per_year),
    sharpe_ratio = compute_sharpe_ratio(
      returns,
      bars_per_year = bars_per_year,
      rf_period_return = rf_period_return
    ),
    max_drawdown = compute_max_drawdown(equity_values),
    n_trades = n_trades,
    win_rate = win_rate,
    avg_trade = avg_trade,
    time_in_market = compute_time_in_market(equity)
  )
}
