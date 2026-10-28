# Strategy grammar: cold read v2

## 1. 60/40, rebalanced monthly

Hold 60% SPY and 40% AGG; reset the mix at each month end.

```r
sixty_forty <- function(ctx, params) {
  ledgr_target_rebalance(c(SPY = 0.6, AGG = 0.4), ctx)
}
month_end <- ledgr_schedule_month_end()
opening <- ledgr_opening(cash = 100000)
experiment <- ledgr_experiment4(snapshot, strategy = sixty_forty, schedule = month_end,
  universe = c("SPY", "AGG"), opening = opening, cost_model = ledgr_cost_zero())
result <- ledgr_run(experiment)
```

## 2. Trend filter

Hold SPY while its close exceeds its 200-session average; otherwise cash, including while the average is unknown.

```r
features <- ledgr_feature_map(average = ledgr_ind_sma(200))
trend <- function(ctx, params) {
  if (!isTRUE(ctx$close[["SPY"]] > ctx$average[["SPY"]])) return(ctx$flat())
  ledgr_target_rebalance(c(SPY = 1), ctx)
}
opening <- ledgr_opening(cash = 100000)
experiment <- ledgr_experiment4(snapshot, strategy = trend, features = features,
  universe = "SPY", opening = opening, cost_model = ledgr_cost_zero())
result <- ledgr_run(experiment)
```

## 3. Top-decile momentum

Each month, buy the highest-return tenth of buyable stocks, skipping the most recent month. Weight them equally using 98% of equity. Sell index leavers.

```r
eleven_month_return <- ledgr_ind_returns(231)
skip_month_return <- ledgr_ind_lag(eleven_month_return, 21)
features <- ledgr_feature_map(skip_month_return = skip_month_return)
momentum <- function(ctx, params) {
  ledgr_select_top(ctx$skip_month_return, fraction = params$decile,
    within = ctx$buyable, partial = "allow") |>
    ledgr_weight_equal() |>
    ledgr_target_rebalance(ctx, index_leavers = "sell", invest_fraction = params$invest)
}
params <- list(decile = 0.1, invest = 0.98)
month_end <- ledgr_schedule_month_end()
opening <- ledgr_opening(cash = 100000)
experiment <- ledgr_experiment4(snapshot, strategy = momentum, features = features,
  universe = ledgr_universe_members("stocks"), schedule = month_end,
  opening = opening, cost_model = ledgr_cost_zero())
result <- ledgr_run(experiment, params = params)
```

## 4. A sleeve beside gold

Each month, put 20% of total equity into SPY and 20% into AGG. Keep the inherited gold quantity unchanged.

```r
sleeves <- function(ctx, params) {
  ledgr_target_rebalance(c(SPY = 0.2, AGG = 0.2), ctx,
    keep = ctx$universe == "GLD", capital_base = "total_equity")
}
month_end <- ledgr_schedule_month_end()
opening <- ledgr_opening(cash = 100000, positions = c(GLD = 400), cost_basis = c(GLD = 100))
experiment <- ledgr_experiment4(snapshot, strategy = sleeves, schedule = month_end,
  universe = c("SPY", "AGG", "GLD"), opening = opening, cost_model = ledgr_cost_zero())
result <- ledgr_run(experiment)
```

## 5. RSI-2 mean reversion

Hold at most five stocks. Buy the most oversold candidates above their 200-session average, with each slot using one fifth of 98% of total equity. Sell when RSI exceeds 70 or the close exceeds the five-session average.

```r
features <- ledgr_feature_map(rsi_2 = ledgr_ind_rsi(2),
  sma_200 = ledgr_ind_sma(200), sma_5 = ledgr_ind_sma(5))
connors <- function(ctx, params) {
  sell <- ctx$held & (ctx$rsi_2 > params$exit_rsi | ctx$close > ctx$sma_5)
  candidates <- ctx$buyable & !ctx$held & ctx$rsi_2 < params$entry_rsi & ctx$close > ctx$sma_200
  candidates[is.na(candidates)] <- FALSE
  free <- max(0, params$slots - sum(ctx$held & !sell))
  buy <- ledgr_select_lowest(ctx$rsi_2, free, within = candidates, partial = "allow")
  ledgr_target_adjust(ctx, weights = ledgr_weight_each(buy, 1 / params$slots),
    exit = sell, invest_fraction = params$invest)
}
params <- list(entry_rsi = 10, exit_rsi = 70, slots = 5, invest = 0.98)
opening <- ledgr_opening(cash = 100000)
experiment <- ledgr_experiment4(snapshot, strategy = connors, features = features,
  universe = ledgr_universe_members("stocks"), opening = opening, cost_model = ledgr_cost_zero())
result <- ledgr_run(experiment, params = params)
```

## 6. Trailing stop with a cooldown

Enter SPY at 20% of total equity. Sell when its close falls 5% below the highest close observed while held. After the exit fills, wait five further open sessions before deciding to enter again.

```r
trailing_stop <- function(ctx, params) {
  sell <- ctx$held & ctx$close < 0.95 * ctx$peak_since_entry
  buy <- ctx$buyable & !ctx$held & ctx$days_since_exit >= params$wait
  ledgr_target_adjust(ctx, weights = ledgr_weight_each(buy, 0.2), exit = sell)
}
params <- list(wait = 5)
opening <- ledgr_opening(cash = 100000, positions = c(SPY = 100), cost_basis = c(SPY = 100))
experiment <- ledgr_experiment4(snapshot, strategy = trailing_stop, universe = "SPY",
  opening = opening, cost_model = ledgr_cost_zero())
result <- ledgr_run(experiment, params = params)
```
