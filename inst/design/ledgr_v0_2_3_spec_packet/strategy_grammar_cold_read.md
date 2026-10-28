# Strategy grammar: cold read

2026-10-28. Six common strategies written in the grammar as seed v1
proposes it (`rfc/rfc_strategy_authoring_api_v0_2_3_seed.md`, Section 4).
Each is adapted from an executed worked example; the adaptations on this
page are not re-run. Codex's response changes are not applied.

**How to read it.** Read top to bottom without other documents. Mark every
line where you had to stop and think, and note in a word why ("which
reader?", "what does this sell?", "jargon"). Unmarked lines count as
readable.

## 1. 60/40, rebalanced monthly

Hold 60% stocks and 40% bonds; reset the mix at each month end.

```r
sixty_forty <- function(ctx, params) {
  ledgr_target_rebalance(params$weights, ctx)
}

params <- list(weights = c(SPY = 0.6, AGG = 0.4))

experiment <- ledgr_experiment(
  snapshot,
  strategy = sixty_forty,
  params = params,
  schedule = ledgr_schedule_month_end(),
  cost_model = ledgr_cost_zero()
)
result <- ledgr_run(experiment)
```

## 2. Trend filter

Hold the S&P 500 while it trades above its 200-day average; otherwise cash.

```r
features <- ledgr_feature_map(average = ledgr_ind_sma(200))

trend <- function(ctx, params) {
  if (ctx$vec$close[["SPY"]] > ctx$vec$feature("average")[["SPY"]]) {
    ledgr_target_rebalance(c(SPY = 1), ctx)
  } else {
    ctx$flat()
  }
}

experiment <- ledgr_experiment(
  snapshot,
  strategy = trend,
  features = features,
  universe = "SPY",
  cost_model = ledgr_cost_zero()
)
```

## 3. Top-10 momentum

Each month, buy the ten stocks with the best 12-month return, skipping the
most recent month, in equal weights. Sell stocks that left the index.

```r
eleven_month_return <- ledgr_ind_returns(231)
skip_month_return <- ledgr_ind_lag(eleven_month_return, 21)
features <- ledgr_feature_map(skip_month_return = skip_month_return)

momentum <- function(ctx, params) {
  ledgr_signal_feature(ctx, "skip_month_return") |>
    ledgr_select_top(n = 10) |>
    ledgr_weight_equal() |>
    ledgr_target_rebalance(ctx, exit = !ctx$vec$member)
}

experiment <- ledgr_experiment(
  snapshot,
  strategy = momentum,
  features = features,
  schedule = ledgr_schedule_month_end(),
  cost_model = ledgr_cost_zero()
)
```

## 4. Partial sleeve beside a kept holding

Put 20% of the account into stocks and 20% into bonds; leave the gold
holding untouched.

```r
sleeves <- function(ctx, params) {
  ledgr_target_rebalance(c(SPY = 0.2, AGG = 0.2), ctx,
                         keep = "GLD", capital_base = "total_equity")
}
```

## 5. RSI-2 mean reversion

Up to five positions. Buy the most oversold stocks above their 200-day
average; sell when the RSI recovers or the price closes above its 5-day
average.

```r
features <- ledgr_feature_map(
  rsi_2 = ledgr_ind_rsi(2),
  sma_5 = ledgr_ind_sma(5),
  sma_200 = ledgr_ind_sma(200)
)

connors_rsi2 <- function(ctx, params) {
  rsi <- ledgr_signal_feature(ctx, "rsi_2")
  close <- ctx$vec$close

  exits <- ledgr_select_held(ctx,
    where = rsi > params$exit_rsi | close > ctx$vec$feature("sma_5"))
  setup <- ledgr_selection(ctx, missing = "exclude",
    where = !ctx$vec$held & rsi < params$entry_rsi &
            close > ctx$vec$feature("sma_200"))
  free <- max(0, params$slots - sum(ctx$vec$held & !exits))

  entries <- ledgr_select_lowest(rsi, free, within = setup)
  ledgr_target_adjust(ctx,
    weights = ledgr_weight_each(entries, 1 / params$slots),
    exit = exits,
    capital_base = "total_equity")
}

params <- list(slots = 5, entry_rsi = 10, exit_rsi = 70)
```

## 6. Trailing stop with a cooldown

Sell a holding once it falls 5% below its highest price since purchase.
After a stop, wait a set number of days before buying it again.

```r
trailing_stop <- function(ctx, params) {
  price <- ctx$vec$close
  memory <- ledgr_asset_state(ctx, peak = NA_real_, cooldown = 0)

  peak <- pmax(memory$peak, price, na.rm = TRUE)
  exits <- ledgr_select_held(ctx, where = price < 0.95 * peak)
  entries <- ledgr_selection(ctx,
    where = !ctx$vec$held & memory$cooldown == 0)

  memory$peak <- peak
  memory$peak[exits | !(ctx$vec$held | entries)] <- NA
  memory$cooldown <- ifelse(exits, params$wait, pmax(0, memory$cooldown - 1))

  ledgr_target_adjust(ctx,
    weights = ledgr_weight_each(entries, params$size),
    exit = exits,
    capital_base = "total_equity") |>
    ledgr_strategy_result(asset_state = memory)
}

params <- list(size = 0.2, wait = 5)
```

## Your marks

| # | Line | Why you stopped |
| --- | --- | --- |
| | | |
