ledgr_backtest_equity <- function(con, run_id) {
  DBI::dbGetQuery(
    con,
    "
    SELECT ts_utc, equity, cash, positions_value
    FROM equity_curve
    WHERE run_id = ?
    ORDER BY ts_utc
    ",
    params = list(run_id)
  )
}

ledgr_backtest_returns <- function(con, run_id) {
  equity <- ledgr_backtest_equity(con, run_id)
  if (!is.data.frame(equity) || nrow(equity) == 0L) {
    return(tibble::tibble(
      ts_utc = as.POSIXct(character(), tz = "UTC"),
      equity = numeric(),
      period_return = numeric()
    ))
  }

  equity_values <- as.numeric(equity$equity)
  tibble::tibble(
    ts_utc = as.POSIXct(equity$ts_utc, tz = "UTC"),
    equity = equity_values,
    period_return = c(NA_real_, compute_period_returns(equity_values))
  )
}
ledgr_empty_equity_curve <- function() {
  tibble::tibble(
    ts_utc = as.POSIXct(character(), tz = "UTC"),
    equity = numeric(),
    cash = numeric(),
    positions_value = numeric(),
    running_max = numeric(),
    drawdown = numeric()
  )
}
compute_annualized_return <- function(equity, bars_per_year) {
  if (!is.data.frame(equity) || nrow(equity) < 2) return(NA_real_)
  if (!is.numeric(bars_per_year) || length(bars_per_year) != 1 || !is.finite(bars_per_year) || bars_per_year <= 0) {
    return(NA_real_)
  }
  initial_equity <- as.numeric(equity$equity[[1]])
  final_equity <- as.numeric(equity$equity[[nrow(equity)]])
  if (!is.finite(initial_equity) || initial_equity == 0 || !is.finite(final_equity)) {
    return(NA_real_)
  }

  n_periods <- nrow(equity) - 1
  years <- n_periods / bars_per_year
  if (years <= 0) return(NA_real_)

  total_return <- (final_equity / initial_equity) - 1
  (1 + total_return)^(1 / years) - 1
}

compute_max_drawdown <- function(equity_values) {
  if (length(equity_values) < 1) return(NA_real_)
  running_max <- cummax(equity_values)
  drawdown <- (equity_values / running_max) - 1
  min(drawdown, na.rm = TRUE)
}

compute_time_in_market <- function(equity) {
  if (!is.data.frame(equity) || nrow(equity) == 0) return(NA_real_)
  mean(abs(equity$positions_value) > 1e-6)
}

ledgr_metric_sd_epsilon <- function() .Machine$double.eps

compute_period_returns <- function(equity_values) {
  equity_values <- as.numeric(equity_values)
  if (length(equity_values) < 2L) return(numeric(0))
  prev <- equity_values[-length(equity_values)]
  cur <- equity_values[-1L]
  out <- rep(NA_real_, length(cur))
  ok <- is.finite(prev) & is.finite(cur) & prev != 0
  out[ok] <- (cur[ok] / prev[ok]) - 1
  out
}

compute_rf_period_return <- function(risk_free_rate, bars_per_year) {
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

compute_annualized_volatility <- function(returns, bars_per_year) {
  returns <- as.numeric(returns)
  if (length(returns) < 2L || any(!is.finite(returns))) return(NA_real_)
  if (!is.numeric(bars_per_year) || length(bars_per_year) != 1L ||
    !is.finite(bars_per_year) || bars_per_year <= 0) {
    return(NA_real_)
  }
  sd_returns <- stats::sd(returns)
  if (!is.finite(sd_returns)) {
    return(NA_real_)
  }
  sd_returns * sqrt(bars_per_year)
}

compute_sharpe_ratio <- function(returns,
                                 bars_per_year,
                                 risk_free_rate = 0,
                                 rf_period_return = NULL) {
  returns <- as.numeric(returns)
  if (length(returns) < 2L || any(!is.finite(returns))) return(NA_real_)
  if (!is.numeric(bars_per_year) || length(bars_per_year) != 1L ||
    !is.finite(bars_per_year) || bars_per_year <= 0) {
    return(NA_real_)
  }
  if (is.null(rf_period_return)) {
    rf_period_return <- compute_rf_period_return(risk_free_rate, bars_per_year)
  }
  if (!is.numeric(rf_period_return) || length(rf_period_return) != 1L) {
    return(NA_real_)
  }
  if (!is.finite(rf_period_return)) return(NA_real_)
  excess_returns <- returns - rf_period_return
  sd_excess <- stats::sd(excess_returns)
  if (!is.finite(sd_excess) || sd_excess <= ledgr_metric_sd_epsilon()) {
    return(NA_real_)
  }
  mean(excess_returns) / sd_excess * sqrt(bars_per_year)
}

ledgr_estimate_bars_per_year <- function(bt, equity, con = NULL) {
  fallback <- 252
  if (!inherits(bt, "ledgr_backtest")) return(fallback)
  if (!is.list(bt$config) || is.null(bt$config$data$snapshot_id)) return(fallback)

  if (is.null(con)) {
    opened <- ledgr_backtest_read_connection(bt)
    con <- opened$con
    on.exit(opened$close(), add = TRUE)
  }
  snapshot_id <- bt$config$data$snapshot_id
  if (!is.null(bt$config$data) && is.list(bt$config$data) && identical(bt$config$data$source, "snapshot")) {
    run_db_path <- bt$config$db_path
    snapshot_db_path <- ledgr_snapshot_db_path_from_config(bt$config, run_db_path)
    ledgr_prepare_snapshot_source_tables(con, snapshot_db_path, run_db_path)
  }

  inst <- DBI::dbGetQuery(
    con,
    "SELECT instrument_id FROM snapshot_instruments WHERE snapshot_id = ? ORDER BY instrument_id LIMIT 1",
    params = list(snapshot_id)
  )$instrument_id[[1]]
  if (is.null(inst) || is.na(inst) || !nzchar(inst)) return(fallback)

  median_seconds <- DBI::dbGetQuery(
    con,
    "
    SELECT median(diff_seconds) AS median_diff
    FROM (
      SELECT datediff('second', LAG(ts_utc) OVER (ORDER BY ts_utc), ts_utc) AS diff_seconds
      FROM snapshot_bars
      WHERE snapshot_id = ? AND instrument_id = ?
    )
    WHERE diff_seconds IS NOT NULL
    ",
    params = list(snapshot_id, inst)
  )$median_diff[[1]]

  median_seconds <- suppressWarnings(as.numeric(median_seconds))
  if (!is.finite(median_seconds) || median_seconds <= 0) return(fallback)

  bars_per_year <- snap_to_frequency(median_seconds)
  if (!is.finite(bars_per_year) || bars_per_year <= 0) return(fallback)
  bars_per_year
}

snap_to_frequency <- function(median_seconds) {
  if (!is.numeric(median_seconds) || length(median_seconds) != 1 || !is.finite(median_seconds) || median_seconds <= 0) {
    return(NA_real_)
  }

  standard <- data.frame(
    seconds = c(60, 300, 900, 3600, 86400, 604800),
    bars_per_year = c(525600, 105120, 35040, 8760, 252, 52),
    stringsAsFactors = FALSE
  )
  raw <- (365.25 * 24 * 3600) / median_seconds
  idx <- which.min(abs(standard$seconds - median_seconds))
  distance <- abs(standard$seconds[[idx]] - median_seconds) / standard$seconds[[idx]]
  if (distance < 0.2) {
    return(standard$bars_per_year[[idx]])
  }
  message(sprintf("Frequency snap fallback to 252 (raw=%.2f).", raw))
  252
}

ledgr_metric_context_for_metrics <- function(bt,
                                             metric_context = NULL,
                                             risk_free_rate = NULL) {
  if (!is.null(metric_context) && !is.null(risk_free_rate)) {
    rlang::abort(
      "Supply either `metric_context` or `risk_free_rate`, not both.",
      class = "ledgr_invalid_args"
    )
  }
  if (!is.null(risk_free_rate)) {
    risk_free_rate <- ledgr_validate_annual_rate(risk_free_rate, "risk_free_rate")
    return(ledgr_metric_context(risk_free_rate = risk_free_rate))
  }
  if (!is.null(metric_context)) {
    return(ledgr_metric_context_resolve(metric_context))
  }
  ledgr_metric_context(bt)
}

ledgr_new_metrics <- function(values, metric_kernel) {
  context <- ledgr_metric_context_from_kernel(metric_kernel)
  structure(
    values,
    metric_context = context,
    metric_kernel = metric_kernel,
    class = c("ledgr_metrics", "list")
  )
}

ledgr_compute_metrics_internal <- function(bt,
                                           metrics = "standard",
                                           metric_context = NULL,
                                           risk_free_rate = NULL) {
  if (!inherits(bt, "ledgr_backtest")) {
    rlang::abort("`bt` must be a ledgr_backtest object.", class = "ledgr_invalid_backtest")
  }
  if (!identical(metrics, "standard")) {
    rlang::abort(
      "Only metrics = 'standard' is supported.",
      class = "ledgr_invalid_args"
    )
  }
  metric_context <- ledgr_metric_context_for_metrics(
    bt,
    metric_context = metric_context,
    risk_free_rate = risk_free_rate
  )
  metric_kernel <- ledgr_metric_kernel(context = metric_context)

  opened <- ledgr_backtest_read_connection(bt)
  con <- opened$con
  on.exit(opened$close(), add = TRUE)
  equity <- ledgr_backtest_equity(con, bt$run_id)
  equity$equity <- as.numeric(equity$equity)
  equity$positions_value <- as.numeric(equity$positions_value)
  ledgr_calendar_warn_if_inconsistent(
    metric_context$calendar,
    observed_ts_utc = equity$ts_utc,
    context = "run metrics"
  )

  fills <- ledgr_extract_fills_impl(bt, con = con)
  trades <- ledgr_closed_trade_rows(fills)

  returns <- compute_period_returns(equity$equity)
  bars_per_year <- metric_kernel$bars_per_year
  initial_equity <- if (nrow(equity) > 0) as.numeric(equity$equity[[1]]) else NA_real_
  final_equity <- if (nrow(equity) > 0) as.numeric(equity$equity[[nrow(equity)]]) else NA_real_
  total_return <- if (nrow(equity) > 0 && is.finite(initial_equity) && initial_equity != 0 && is.finite(final_equity)) {
    (final_equity / initial_equity) - 1
  } else {
    NA_real_
  }

  ledgr_new_metrics(list(
    total_return = total_return,
    annualized_return = compute_annualized_return(equity, bars_per_year),
    volatility = compute_annualized_volatility(returns, bars_per_year),
    sharpe_ratio = compute_sharpe_ratio(
      returns,
      bars_per_year,
      rf_period_return = metric_kernel$rf_period_return
    ),
    max_drawdown = compute_max_drawdown(equity$equity),
    n_trades = nrow(trades),
    win_rate = if (nrow(trades) > 0) sum(trades$realized_pnl > 0, na.rm = TRUE) / nrow(trades) else NA_real_,
    avg_trade = if (nrow(trades) > 0) mean(trades$realized_pnl, na.rm = TRUE) else NA_real_,
    time_in_market = compute_time_in_market(equity)
  ), metric_kernel = metric_kernel)
}

#' Compute an equity curve from a backtest
#'
#' @param bt A `ledgr_backtest` object.
#' @return A tibble containing equity, running maximum, and drawdown.
#' @examples
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3,
#'   instrument_id = "AAA",
#'   open = c(100, 101, 102, 103),
#'   high = c(101, 102, 103, 104),
#'   low = c(99, 100, 101, 102),
#'   close = c(100, 101, 102, 103),
#'   volume = 1000
#' )
#' strategy <- function(ctx, params) {
#'   targets <- ctx$flat()
#'   targets["AAA"] <- 1
#'   targets
#' }
#' bt <- ledgr_backtest(data = bars, strategy = strategy, initial_cash = 1000, cost_model = ledgr_cost_zero())
#' ledgr_compute_equity_curve(bt)
#' close(bt)
#' @noRd
ledgr_compute_equity_curve <- function(bt) {
  ledgr_compute_equity_curve_impl(bt)
}

ledgr_compute_equity_curve_impl <- function(bt, con = NULL) {
  if (is.null(con)) {
    opened <- ledgr_backtest_read_connection(bt)
    con <- opened$con
    on.exit(opened$close(), add = TRUE)
  }
  equity <- ledgr_backtest_equity(con, bt$run_id)
  if (nrow(equity) == 0) {
    return(ledgr_empty_equity_curve())
  }

  equity$equity <- as.numeric(equity$equity)
  equity$running_max <- cummax(equity$equity)
  equity$drawdown <- (equity$equity / equity$running_max - 1)
  tibble::as_tibble(equity)
}

#' Summarize per-pulse telemetry
#'
#' @param bt A `ledgr_backtest` object. This function does not accept a DuckDB
#'   file path; use `ledgr_run_info()` for persisted run-level telemetry.
#' @return A tibble with mean/median/p99 values per telemetry component.
#' @details
#' This is a diagnostic helper for engine profiling. It only reports detailed
#' telemetry captured for runs executed in the current R session. Timing
#' components are reported in seconds; feature-cache hit/miss rows are counts.
#' The compact telemetry persisted in durable experiment stores is available
#' through `ledgr_run_info()`.
#'
#' @examples
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:2,
#'   instrument_id = "AAA",
#'   open = c(100, 101, 102),
#'   high = c(101, 102, 103),
#'   low = c(99, 100, 101),
#'   close = c(100, 101, 102),
#'   volume = 1000
#' )
#' strategy <- function(ctx, params) {
#'   targets <- ctx$flat()
#'   targets["AAA"] <- 1
#'   targets
#' }
#' bt <- ledgr_backtest(data = bars, strategy = strategy, initial_cash = 1000, cost_model = ledgr_cost_zero())
#' ledgr_backtest_bench(bt)
#' close(bt)
#' @export
ledgr_backtest_bench <- function(bt) {
  if (!inherits(bt, "ledgr_backtest")) {
    rlang::abort("`bt` must be a ledgr_backtest object.", class = "ledgr_invalid_backtest")
  }

  telemetry <- ledgr_get_run_telemetry(bt$run_id)
  if (is.null(telemetry)) {
    rlang::abort("No telemetry found for this run_id. Run ledgr_backtest() to capture telemetry.", class = "ledgr_invalid_args")
  }

  summarize_vec <- function(x) {
    if (length(x) == 0) return(c(mean = NA_real_, median = NA_real_, p99 = NA_real_))
    c(
      mean = mean(x, na.rm = TRUE),
      median = stats::median(x, na.rm = TRUE),
      p99 = stats::quantile(x, 0.99, na.rm = TRUE, names = FALSE)
    )
  }

  components <- c(
    "t_pre",
    "t_post",
    "t_loop",
    "t_pulse",
    "t_bars",
    "t_ctx",
    "t_fill",
    "t_state",
    "t_feats",
    "t_strat",
    "t_target",
    "t_event",
    "t_exec",
    "feature_cache_hits",
    "feature_cache_misses"
  )
  out <- lapply(components, function(name) summarize_vec(telemetry[[name]]))

  tibble::tibble(
    component = components,
    mean = vapply(out, `[[`, numeric(1), "mean"),
    median = vapply(out, `[[`, numeric(1), "median"),
    p99 = vapply(out, `[[`, numeric(1), "p99")
  )
}

#' Compute standard metrics from backtest results
#'
#' @param bt A `ledgr_backtest` object. This function does not accept an equity
#'   tibble directly.
#' @param metrics Only `"standard"` is supported.
#' @param metric_context Optional metric context override for this computation.
#'   When omitted, ledgr uses the metric context stored with the run.
#' @param risk_free_rate Optional scalar annual risk-free-rate override as a
#'   decimal. For example, `0.02` means two percent per year. Supply either
#'   `metric_context` or `risk_free_rate`, not both.
#' @return A list-like `ledgr_metrics` object.
#'
#' @details
#' Standard metrics are derived from the ledger and equity curve:
#' - `total_return`: last public equity row divided by the first public equity
#'   row minus 1.
#' - `annualized_return`: geometric annualized return from the first and last
#'   public equity rows using the metric context's annualization calendar.
#' - `volatility`: annualized standard deviation of adjacent public equity-row
#'   returns.
#' - `sharpe_ratio`: annualized Sharpe ratio over adjacent public equity-row
#'   excess returns, using the metric context's scalar annual risk-free rate
#'   converted to a per-period return. Flat, constant-return, invalid, or short
#'   return series return `NA_real_`.
#' - `max_drawdown`: maximum peak-to-trough percentage decline,
#'   `min(equity / cummax(equity) - 1)`.
#' - `n_trades`: number of closed trade rows. Open-only fills do not count until
#'   a later fill closes quantity.
#' - `win_rate`: share of closed trade rows with strict realized P&L `> 0`;
#'   breakeven is not a win, and open-position gains remain in equity until
#'   closed.
#' - `avg_trade`: mean realized P&L across closed trade rows.
#' - `time_in_market`: share of equity timestamps with absolute
#'   `positions_value > 1e-6`.
#'
#' @examples
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3,
#'   instrument_id = "AAA",
#'   open = c(100, 101, 102, 103),
#'   high = c(101, 102, 103, 104),
#'   low = c(99, 100, 101, 102),
#'   close = c(100, 101, 102, 103),
#'   volume = 1000
#' )
#' strategy <- function(ctx, params) {
#'   targets <- ctx$flat()
#'   targets["AAA"] <- 1
#'   targets
#' }
#' bt <- ledgr_backtest(data = bars, strategy = strategy, initial_cash = 1000, cost_model = ledgr_cost_zero())
#' ledgr_compute_metrics(bt)
#' close(bt)
#' @export
ledgr_compute_metrics <- function(bt,
                                  metrics = "standard",
                                  metric_context = NULL,
                                  risk_free_rate = NULL) {
  ledgr_compute_metrics_internal(
    bt,
    metrics = metrics,
    metric_context = metric_context,
    risk_free_rate = risk_free_rate
  )
}

#' Print a backtest result
#'
#' @param x A `ledgr_backtest` object.
#' @param ... Unused.
#' @return The input object, invisibly.
#' @examples
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:2,
#'   instrument_id = "AAA",
#'   open = c(100, 101, 102),
#'   high = c(101, 102, 103),
#'   low = c(99, 100, 101),
#'   close = c(100, 101, 102),
#'   volume = 1000
#' )
#' strategy <- function(ctx, params) {
#'   targets <- ctx$flat()
#'   targets["AAA"] <- 1
#'   targets
#' }
#' bt <- ledgr_backtest(data = bars, strategy = strategy, initial_cash = 1000, cost_model = ledgr_cost_zero())
#' print(bt)
#' close(bt)
#' @export
print.ledgr_backtest <- function(x, ...) {
  if (!inherits(x, "ledgr_backtest")) {
    rlang::abort("`x` must be a ledgr_backtest object.", class = "ledgr_invalid_backtest")
  }

  cfg <- x$config
  universe <- cfg$universe$instrument_ids
  start <- cfg$backtest$start_ts_utc
  end <- cfg$backtest$end_ts_utc
  initial_cash <- cfg$backtest$initial_cash
  execution_mode <- if (is.list(cfg$engine) && !is.null(cfg$engine$execution_mode)) {
    cfg$engine$execution_mode
  } else {
    NA_character_
  }

  opened <- ledgr_backtest_read_connection(x)
  con <- opened$con
  on.exit(opened$close(), add = TRUE)
  final_equity <- DBI::dbGetQuery(
    con,
    "
    SELECT equity
    FROM equity_curve
    WHERE run_id = ?
    ORDER BY ts_utc DESC
    LIMIT 1
    ",
    params = list(x$run_id)
  )$equity[[1]]
  final_equity <- as.numeric(final_equity)

  pnl <- final_equity - initial_cash
  pnl_pct <- (pnl / initial_cash) * 100

  cat("ledgr Backtest Results\n")
  cat("======================\n\n")
  cat("Run ID:        ", x$run_id, "\n")
  cat("Universe:      ", paste(universe, collapse = ", "), "\n")
  cat("Date Range:    ", start, "to", end, "\n")
  cat("Execution Mode:", execution_mode, "\n")
  cat("Initial Cash:  ", sprintf("$%.2f", initial_cash), "\n")
  cat("Final Equity:  ", sprintf("$%.2f", final_equity), "\n")
  cat("P&L:           ", sprintf("$%.2f (%.2f%%)", pnl, pnl_pct), "\n\n")
  cat("Use summary(bt) for detailed metrics\n")
  cat("Use plot(bt) for equity curve visualization\n")

  invisible(x)
}

#' Summarize a backtest result
#'
#' Prints standard performance, risk, trade, and exposure metrics.
#'
#' @param object A `ledgr_backtest` object.
#' @param metrics Only `"standard"` is supported.
#' @param metric_context Optional metric context override for this summary.
#'   When omitted, ledgr uses the metric context stored with the run.
#' @param risk_free_rate Optional scalar annual risk-free-rate override as a
#'   decimal. Supply either `metric_context` or `risk_free_rate`, not both.
#' @param ... Unused.
#' @return The input `ledgr_backtest` object, invisibly. The printed values are
#'   descriptive output; use `ledgr_compute_metrics()` for a named list of the
#'   same metric values.
#'
#' @details
#' The standard summary displays:
#' - total return: last public equity row divided by the first public equity
#'   row minus 1;
#' - annualized return: geometric annualized return from the first and last
#'   public equity rows using the metric context's annualization calendar;
#' - max drawdown: maximum peak-to-trough decline,
#'   `min(equity / cummax(equity) - 1)`;
#' - annualized volatility: standard deviation of adjacent equity-row returns
#'   multiplied by `sqrt(bars_per_year)`;
#' - Sharpe ratio: annualized ratio of average period excess return to
#'   excess-return standard deviation, using the metric context's scalar annual
#'   risk-free rate converted to a per-period return;
#' - total trades: number of closed trade rows, not number of fill rows;
#' - win rate: share of closed trade rows with strict `realized_pnl > 0`;
#' - average trade: mean `realized_pnl` across closed trade rows;
#' - time in market: share of equity rows with absolute
#'   `positions_value > 1e-6`.
#'
#' If there are no closed trade rows, total trades is zero and win rate and
#' average trade are printed as not available. If registered features cannot
#' become usable because an instrument has fewer bars than the feature contract
#' requires, the summary prints a compact Warmup Diagnostics section naming the
#' feature ID, instrument ID, required bars, and available bars.
#'
#' @section Articles:
#' Metrics and accounting:
#' `vignette("metrics-and-accounting", package = "ledgr")`
#' `system.file("doc", "metrics-and-accounting.html", package = "ledgr")`
#' @examples
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3,
#'   instrument_id = "AAA",
#'   open = c(100, 101, 102, 103),
#'   high = c(101, 102, 103, 104),
#'   low = c(99, 100, 101, 102),
#'   close = c(100, 101, 102, 103),
#'   volume = 1000
#' )
#' strategy <- function(ctx, params) {
#'   targets <- ctx$flat()
#'   targets["AAA"] <- 1
#'   targets
#' }
#' bt <- ledgr_backtest(data = bars, strategy = strategy, initial_cash = 1000, cost_model = ledgr_cost_zero())
#' summary(bt)
#' close(bt)
#' @export
summary.ledgr_backtest <- function(object,
                                   metrics = "standard",
                                   metric_context = NULL,
                                   risk_free_rate = NULL,
                                   ...) {
  if (!inherits(object, "ledgr_backtest")) {
    rlang::abort("`object` must be a ledgr_backtest object.", class = "ledgr_invalid_backtest")
  }

  computed <- ledgr_compute_metrics(
    object,
    metrics = metrics,
    metric_context = metric_context,
    risk_free_rate = risk_free_rate
  )
  computed_context <- ledgr_metric_context(computed)

  cat("ledgr Backtest Summary\n")
  cat("======================\n\n")

  cat("Performance Metrics:\n")
  cat(sprintf("  Total Return:        %.2f%%\n", computed$total_return * 100))
  cat(sprintf("  Annualized Return:   %.2f%%\n", computed$annualized_return * 100))
  cat(sprintf("  Max Drawdown:        %.2f%%\n", computed$max_drawdown * 100))

  cat("\nRisk Metrics:\n")
  cat(sprintf("  Risk-Free Rate:      %s\n", ledgr_metric_summary_risk_free_display(computed_context)))
  cat(sprintf("  Annualization:       %s\n", ledgr_metric_summary_annualization_display(computed_context)))
  cat(sprintf("  Volatility (annual): %.2f%%\n", computed$volatility * 100))
  sharpe_label <- if (is.finite(computed$sharpe_ratio)) sprintf("%.3f", computed$sharpe_ratio) else "N/A"
  cat(sprintf("  Sharpe Ratio:        %s\n", sharpe_label))

  cat("\nTrade Statistics:\n")
  cat(sprintf("  Total Trades:        %d\n", computed$n_trades))
  if (computed$n_trades > 0) {
    cat(sprintf("  Win Rate:            %.2f%%\n", computed$win_rate * 100))
    cat(sprintf("  Avg Trade:           $%.2f\n", computed$avg_trade))
  } else {
    cat("  Win Rate:            N/A (no trades)\n")
    cat("  Avg Trade:           N/A (no trades)\n")
  }

  cat("\nExposure:\n")
  cat(sprintf("  Time in Market:      %.2f%%\n", computed$time_in_market * 100))

  diagnostics <- tryCatch(
    ledgr_backtest_warmup_diagnostics(object),
    error = function(e) NULL
  )
  ledgr_print_warmup_diagnostics(diagnostics)

  invisible(object)
}

ledgr_empty_warmup_diagnostics <- function() {
  out <- tibble::tibble(
    feature_id = character(),
    instrument_id = character(),
    required_bars = integer(),
    stable_after = integer(),
    available_bars = integer()
  )
  class(out) <- unique(c("ledgr_warmup_diagnostics", class(out)))
  out
}

ledgr_warmup_diagnostics_from_counts <- function(feature_contracts, bar_counts) {
  if (!is.data.frame(feature_contracts) || nrow(feature_contracts) == 0L ||
    !is.data.frame(bar_counts) || nrow(bar_counts) == 0L) {
    return(ledgr_empty_warmup_diagnostics())
  }

  required_cols <- c("feature_id", "required_bars", "stable_after")
  if (!all(required_cols %in% names(feature_contracts))) {
    rlang::abort("`feature_contracts` must include feature_id, required_bars, and stable_after.", class = "ledgr_invalid_args")
  }
  if (!all(c("instrument_id", "available_bars") %in% names(bar_counts))) {
    rlang::abort("`bar_counts` must include instrument_id and available_bars.", class = "ledgr_invalid_args")
  }

  feature_idx <- rep(seq_len(nrow(feature_contracts)), each = nrow(bar_counts))
  count_idx <- rep(seq_len(nrow(bar_counts)), times = nrow(feature_contracts))
  pairs <- data.frame(
    feature_contracts[feature_idx, required_cols, drop = FALSE],
    bar_counts[count_idx, c("instrument_id", "available_bars"), drop = FALSE],
    row.names = NULL,
    stringsAsFactors = FALSE
  )
  pairs$required_bars <- as.integer(pairs$required_bars)
  pairs$stable_after <- as.integer(pairs$stable_after)
  pairs$available_bars <- as.integer(pairs$available_bars)
  needed_bars <- pairs$stable_after
  out <- pairs[pairs$available_bars < needed_bars, , drop = FALSE]
  if (nrow(out) == 0L) {
    return(ledgr_empty_warmup_diagnostics())
  }
  out <- out[order(out$instrument_id, out$feature_id), , drop = FALSE]
  out <- tibble::as_tibble(out[, c("feature_id", "instrument_id", "required_bars", "stable_after", "available_bars"), drop = FALSE])
  class(out) <- unique(c("ledgr_warmup_diagnostics", class(out)))
  out
}

ledgr_feature_contracts_from_backtest_config <- function(bt) {
  cfg <- bt$config
  feats <- cfg$features
  if (is.null(feats) || !isTRUE(feats$enabled) || !is.list(feats$defs) || length(feats$defs) == 0L) {
    return(tibble::tibble(feature_id = character(), required_bars = integer(), stable_after = integer()))
  }
  rows <- lapply(feats$defs, function(def) {
    feature_id <- def$id
    if (is.null(feature_id)) feature_id <- def$name
    if (is.null(feature_id) || !is.character(feature_id) || length(feature_id) != 1L || is.na(feature_id) || !nzchar(feature_id)) {
      return(NULL)
    }
    required_bars <- def$requires_bars
    stable_after <- def$stable_after
    if (is.null(stable_after)) stable_after <- required_bars
    if (is.null(required_bars) || is.null(stable_after)) {
      return(NULL)
    }
    data.frame(
      feature_id = feature_id,
      required_bars = as.integer(required_bars),
      stable_after = as.integer(stable_after),
      stringsAsFactors = FALSE
    )
  })
  rows <- Filter(Negate(is.null), rows)
  if (length(rows) == 0L) {
    return(tibble::tibble(feature_id = character(), required_bars = integer(), stable_after = integer()))
  }
  tibble::as_tibble(do.call(rbind, rows))
}

ledgr_backtest_bar_counts <- function(bt, con = NULL) {
  cfg <- bt$config
  instrument_ids <- cfg$universe$instrument_ids
  if (!is.character(instrument_ids) || length(instrument_ids) == 0L) {
    return(tibble::tibble(instrument_id = character(), available_bars = integer()))
  }

  snapshot_id <- cfg$data$snapshot_id
  snapshot_db_path <- ledgr_snapshot_db_path_from_config(cfg, bt$db_path)
  use_existing <- !is.null(con) && DBI::dbIsValid(con)
  query_con <- con
  close_query <- function() invisible(FALSE)
  if (!isTRUE(use_existing)) {
    opened <- ledgr_open_duckdb_with_retry(bt$db_path)
    query_con <- opened$con
    close_query <- function() {
      suppressWarnings(try(DBI::dbDisconnect(opened$con, shutdown = TRUE), silent = TRUE))
      suppressWarnings(try(duckdb::duckdb_shutdown(opened$drv), silent = TRUE))
      invisible(TRUE)
    }
  }
  on.exit(close_query(), add = TRUE)

  start_iso <- ledgr_normalize_ts_utc(cfg$backtest$start_ts_utc)
  end_iso <- ledgr_normalize_ts_utc(cfg$backtest$end_ts_utc)
  start_str <- sub("Z$", "", sub("T", " ", start_iso))
  end_str <- sub("Z$", "", sub("T", " ", end_iso))
  ids_sql <- paste(DBI::dbQuoteString(query_con, instrument_ids), collapse = ", ")

  if (!is.null(snapshot_id) && is.character(snapshot_id) && length(snapshot_id) == 1L && !is.na(snapshot_id) && nzchar(snapshot_id)) {
    ledgr_prepare_snapshot_source_tables(query_con, snapshot_db_path, bt$db_path)
    ledgr_prepare_snapshot_runtime_views(
      query_con,
      snapshot_id = snapshot_id,
      instrument_ids = instrument_ids,
      start_ts_utc = cfg$backtest$start_ts_utc,
      end_ts_utc = cfg$backtest$end_ts_utc
    )
  }
  counts <- DBI::dbGetQuery(
    query_con,
    paste0(
      "SELECT instrument_id, COUNT(*) AS available_bars ",
      "FROM bars ",
      "WHERE instrument_id IN (", ids_sql, ") ",
      "AND ts_utc >= CAST(? AS TIMESTAMP) AND ts_utc <= CAST(? AS TIMESTAMP) ",
      "GROUP BY instrument_id"
    ),
    params = list(start_str, end_str)
  )

  out <- data.frame(instrument_id = instrument_ids, stringsAsFactors = FALSE)
  idx <- match(out$instrument_id, as.character(counts$instrument_id))
  out$available_bars <- ifelse(is.na(idx), 0L, as.integer(counts$available_bars[idx]))
  tibble::as_tibble(out)
}

ledgr_backtest_warmup_diagnostics <- function(bt, con = NULL) {
  if (!inherits(bt, "ledgr_backtest")) {
    rlang::abort("`bt` must be a ledgr_backtest object.", class = "ledgr_invalid_backtest")
  }
  feature_contracts <- ledgr_feature_contracts_from_backtest_config(bt)
  if (nrow(feature_contracts) == 0L) {
    return(ledgr_empty_warmup_diagnostics())
  }
  opened <- NULL
  query_con <- con
  if (is.null(query_con) || !DBI::dbIsValid(query_con)) {
    opened <- ledgr_backtest_read_connection(bt)
    query_con <- opened$con
    on.exit(opened$close(), add = TRUE)
  }
  bar_counts <- ledgr_backtest_bar_counts(bt, con = query_con)
  ledgr_warmup_diagnostics_from_counts(feature_contracts, bar_counts)
}

ledgr_print_warmup_diagnostics <- function(diagnostics, max_rows = 5L) {
  if (!inherits(diagnostics, "ledgr_warmup_diagnostics") || nrow(diagnostics) == 0L) {
    return(invisible(FALSE))
  }
  cat("\nWarmup Diagnostics:\n")
  shown <- utils::head(diagnostics, max_rows)
  for (i in seq_len(nrow(shown))) {
    stable_note <- ""
    if (!identical(shown$stable_after[[i]], shown$required_bars[[i]])) {
      stable_note <- sprintf(", stable after %d", shown$stable_after[[i]])
    }
    cat(sprintf(
      "  Feature `%s` for `%s` never became usable: required bars %d%s, available bars %d.\n",
      shown$feature_id[[i]],
      shown$instrument_id[[i]],
      shown$required_bars[[i]],
      stable_note,
      shown$available_bars[[i]]
    ))
  }
  remaining <- nrow(diagnostics) - nrow(shown)
  if (remaining > 0L) {
    cat(sprintf("  ... %d more warmup diagnostics omitted.\n", remaining))
  }
  invisible(TRUE)
}

#' Extract tidy backtest tables
#'
#' @param x A `ledgr_backtest` object.
#' @param what Result table to extract: `"equity"`, `"returns"`, `"fills"`,
#'   `"trades"`, or `"ledger"`.
#' @param ... Unused.
#' @param type Deprecated alias for `what`.
#' @return A tibble with the requested result table.
#' @details
#' `what = "fills"` returns execution fill rows, including opening and closing
#' actions. Fill rows include execution `side`, absolute `qty`, `price`, `fee`,
#' derived `action`, and `realized_pnl`. Opening fills have `action = "OPEN"`
#' and do not count as closed trades.
#'
#' `what = "trades"` returns closed trade rows only. This table has the same
#' zero-row schema as fills, but only rows with `action = "CLOSE"` are present.
#' It is the source for `n_trades`, `win_rate`, and `avg_trade`.
#'
#' `what = "equity"` returns the public equity curve used for return,
#' drawdown, volatility, and exposure metrics. Open positions can affect equity
#' through `positions_value` even when there are zero closed trade rows. The
#' final equity used by prints and comparisons is the last row of this table.
#'
#' `what = "returns"` returns the public equity curve as return evidence with
#' columns `ts_utc`, `equity`, and `period_return`. The first period return is
#' `NA_real_`; later rows use the same adjacent-equity return formula as
#' ledgr-owned metrics and retained sweep returns.
#'
#' `ledgr_results()` does not support `what = "metrics"`. Metrics are derived
#' from the public result tables; use `summary(bt)` for printed interpretation
#' or `ledgr_compute_metrics(bt)` for a named list.
#' `ledgr_results()` also does not support `what = "features"`; inspect feature
#' values at pulse time with `ledgr_pulse_snapshot()` and
#' `ledgr_pulse_features()` or `ledgr_pulse_wide()`.
#'
#' @section Articles:
#' Metrics and accounting:
#' `vignette("metrics-and-accounting", package = "ledgr")`
#' `system.file("doc", "metrics-and-accounting.html", package = "ledgr")`
#' @examples
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3,
#'   instrument_id = "AAA",
#'   open = c(100, 101, 102, 103),
#'   high = c(101, 102, 103, 104),
#'   low = c(99, 100, 101, 102),
#'   close = c(100, 101, 102, 103),
#'   volume = 1000
#' )
#' strategy <- function(ctx, params) {
#'   targets <- ctx$flat()
#'   targets["AAA"] <- 1
#'   targets
#' }
#' bt <- ledgr_backtest(data = bars, strategy = strategy, initial_cash = 1000, cost_model = ledgr_cost_zero())
#' tibble::as_tibble(bt, what = "trades")
#' tibble::as_tibble(bt, what = "returns")
#' tibble::as_tibble(bt, what = "equity")
#' close(bt)
#' @export
as_tibble.ledgr_backtest <- function(x, what = "equity", ..., type = NULL) {
  if (!inherits(x, "ledgr_backtest")) {
    rlang::abort("`x` must be a ledgr_backtest object.", class = "ledgr_invalid_backtest")
  }

  if (!is.null(type)) what <- type
  what <- ledgr_match_result_table(what)
  opened <- ledgr_backtest_read_connection(x)
  con <- opened$con
  on.exit(opened$close(), add = TRUE)

  switch(
    what,
    equity = {
      ledgr_compute_equity_curve_impl(x, con = con)
    },
    returns = ledgr_backtest_returns(con, x$run_id),
    fills = ledgr_extract_fills_impl(x, con = con),
    trades = ledgr_extract_trades(x, con = con),
    ledger = tibble::as_tibble(
      DBI::dbGetQuery(
        con,
        "
        SELECT *
        FROM ledger_events
        WHERE run_id = ?
        ORDER BY event_seq
        ",
        params = list(x$run_id)
      )
    )
  )
}

#' Extract ledgr result tables
#'
#' Package-prefixed convenience wrapper around `tibble::as_tibble()` for
#' backtest result tables.
#'
#' The returned object is tibble-compatible. Its print method may compact
#' all-midnight UTC timestamps for EOD output according to
#' `options(ledgr.print_ts_utc)`, but programmatic access keeps `ts_utc` as
#' POSIXct UTC.
#'
#' `what = "fills"` returns execution fill rows, including opening and closing
#' actions. Fill rows include execution `side`, absolute `qty`, `price`, `fee`,
#' derived `action`, and `realized_pnl`. Opening fills have `action = "OPEN"`
#' and do not count as closed trades.
#'
#' `what = "trades"` returns closed trade rows only. This table has the same
#' zero-row schema as fills, but only rows with `action = "CLOSE"` are present.
#' It is the source for `n_trades`, `win_rate`, and `avg_trade`.
#'
#' `what = "equity"` returns the public equity curve used for return,
#' drawdown, volatility, and exposure metrics. Open positions can affect equity
#' through `positions_value` even when there are zero closed trade rows. The
#' final equity used by prints and comparisons is the last row of this table.
#'
#' `what = "returns"` returns the public equity curve as return evidence with
#' columns `ts_utc`, `equity`, and `period_return`. The first period return is
#' `NA_real_`; later rows use the same adjacent-equity return formula as
#' ledgr-owned metrics and retained sweep returns.
#'
#' `ledgr_results()` does not support `what = "metrics"`. Metrics are derived
#' from the public result tables; use `summary(bt)` for printed interpretation
#' or `ledgr_compute_metrics(bt)` for a named list.
#' `ledgr_results()` also does not support `what = "features"`; inspect feature
#' values at pulse time with `ledgr_pulse_snapshot()` and
#' `ledgr_pulse_features()` or `ledgr_pulse_wide()`.
#'
#' @section Articles:
#' Metrics and accounting:
#' `vignette("metrics-and-accounting", package = "ledgr")`
#' `system.file("doc", "metrics-and-accounting.html", package = "ledgr")`
#'
#' @param bt A `ledgr_backtest` object.
#' @param what Result table to extract: `"equity"`, `"returns"`, `"fills"`,
#'   `"trades"`, or `"ledger"`.
#' @return A ledgr result table, which is a classed tibble with the requested
#'   result columns.
#' @examples
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3,
#'   instrument_id = "AAA",
#'   open = c(100, 101, 102, 103),
#'   high = c(101, 102, 103, 104),
#'   low = c(99, 100, 101, 102),
#'   close = c(100, 101, 102, 103),
#'   volume = 1000
#' )
#' strategy <- function(ctx, params) {
#'   targets <- ctx$flat()
#'   targets["AAA"] <- 1
#'   targets
#' }
#' bt <- ledgr_backtest(data = bars, strategy = strategy, initial_cash = 1000, cost_model = ledgr_cost_zero())
#' ledgr_results(bt, what = "trades")
#' ledgr_results(bt, what = "returns")
#' close(bt)
#' @export
ledgr_results <- function(bt, what = c("equity", "returns", "fills", "trades", "ledger")) {
  what <- ledgr_match_result_table(what)
  ledgr_result_table(tibble::as_tibble(bt, what = what), what = what)
}

ledgr_match_result_table <- function(what) {
  choices <- c("equity", "returns", "fills", "trades", "ledger")
  if (length(what) > 1L) {
    return(match.arg(what, choices))
  }
  if (!is.character(what) || length(what) != 1L || is.na(what) || !nzchar(what)) {
    rlang::abort("`what` must be one of: equity, returns, fills, trades, ledger.", class = "ledgr_invalid_result_table")
  }
  if (identical(what, "metrics")) {
    rlang::abort(
      "`ledgr_results()` does not support `what = \"metrics\"`. Use `summary(bt)` for printed interpretation or `ledgr_compute_metrics(bt)` for a named list.",
      class = "ledgr_invalid_result_table"
    )
  }
  if (identical(what, "features")) {
    rlang::abort(
      "`ledgr_results()` does not support `what = \"features\"`. Feature values are pulse-time data; inspect them with `ledgr_pulse_snapshot()` and `ledgr_pulse_features()` or `ledgr_pulse_wide()`.",
      class = "ledgr_invalid_result_table"
    )
  }
  if (!(what %in% choices)) {
    rlang::abort(
      sprintf("Unknown ledgr result table `%s`. Use one of: %s.", what, paste(choices, collapse = ", ")),
      class = "ledgr_invalid_result_table"
    )
  }
  what
}
