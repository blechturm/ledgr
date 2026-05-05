## ----setup, include=FALSE---------------------------------------------------------------
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")
options(width = 90)
options(cli.unicode = FALSE)
default_output_hook <- knitr::knit_hooks$get("output")
knitr::knit_hooks$set(
  output = function(x, options) {
    default_output_hook(gsub("[ \t]+(?=\n)", "", x, perl = TRUE), options)
  }
)


## ----library, message=FALSE-------------------------------------------------------------
library(ledgr)
library(dplyr)
library(tibble)


## ----run--------------------------------------------------------------------------------
bars <- data.frame(
  ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:4,
  instrument_id = "AAA",
  open = c(100, 101, 105, 106, 106),
  high = c(100, 101, 105, 106, 106),
  low = c(100, 101, 105, 106, 106),
  close = c(100, 101, 105, 106, 106),
  volume = 1
)

one_day_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  if (ledgr_utc(ctx$ts_utc) == ledgr_utc("2020-01-01")) {
    targets["AAA"] <- 1
  }
  targets
}

bt <- ledgr_backtest(
  data = bars,
  strategy = one_day_strategy,
  initial_cash = 1000,
  run_id = "accounting_example"
)


## ----fills------------------------------------------------------------------------------
fills <- ledgr_results(bt, what = "fills")
fills


## ----trades-----------------------------------------------------------------------------
trades <- ledgr_results(bt, what = "trades")
trades


## ----equity-----------------------------------------------------------------------------
equity <- ledgr_results(bt, what = "equity")
equity


## ----recompute--------------------------------------------------------------------------
equity_values <- equity$equity
period_returns <- equity_values[-1] / equity_values[-length(equity_values)] - 1
bars_per_year <- 252

metric_check <- tibble(
  total_return =
    equity_values[length(equity_values)] / equity_values[1] - 1,
  annualized_return =
    (1 + total_return)^(
      1 / ((length(equity_values) - 1) / bars_per_year)
    ) - 1,
  volatility =
    sd(period_returns) * sqrt(bars_per_year),
  max_drawdown =
    min(equity_values / cummax(equity_values) - 1),
  n_trades =
    nrow(trades),
  win_rate =
    if (nrow(trades) > 0) mean(trades$realized_pnl > 0) else NA_real_,
  avg_trade =
    if (nrow(trades) > 0) mean(trades$realized_pnl) else NA_real_,
  time_in_market =
    mean(abs(equity$positions_value) > 1e-6)
)

metric_check


## ----summary----------------------------------------------------------------------------
summary(bt)


## ----flat-------------------------------------------------------------------------------
flat_strategy <- function(ctx, params) ctx$flat()

flat_bt <- ledgr_backtest(
  data = bars,
  strategy = flat_strategy,
  initial_cash = 1000,
  run_id = "flat_accounting_example"
)

ledgr_results(flat_bt, what = "fills")
ledgr_results(flat_bt, what = "trades")
ledgr_compute_metrics(flat_bt)[c("n_trades", "win_rate", "avg_trade")]


## ----open-only--------------------------------------------------------------------------
open_only_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  targets["AAA"] <- 1
  targets
}

open_bt <- ledgr_backtest(
  data = bars,
  strategy = open_only_strategy,
  initial_cash = 1000,
  run_id = "open_accounting_example"
)

ledgr_results(open_bt, what = "fills")
ledgr_results(open_bt, what = "trades")
ledgr_compute_metrics(open_bt)[c("n_trades", "win_rate", "avg_trade")]


## ----final-bar-no-fill------------------------------------------------------------------
final_bar_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  if (ledgr_utc(ctx$ts_utc) == ledgr_utc("2020-01-05")) {
    targets["AAA"] <- 1
  }
  targets
}

warned <- FALSE
final_bar_bt <- withCallingHandlers(
  ledgr_backtest(
    data = bars,
    strategy = final_bar_strategy,
    initial_cash = 1000,
    run_id = "final_bar_accounting_example"
  ),
  warning = function(w) {
    if (grepl("LEDGR_LAST_BAR_NO_FILL", conditionMessage(w), fixed = TRUE)) {
      warned <<- TRUE
      invokeRestart("muffleWarning")
    }
  }
)

warned
ledgr_results(final_bar_bt, what = "fills")


## ----cleanup----------------------------------------------------------------------------
close(bt)
close(flat_bt)
close(open_bt)
close(final_bar_bt)

