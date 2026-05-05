Metrics And Accounting
================

ledgr records a backtest as accounting evidence first and summary
metrics second.

The useful reading order is:

1.  ledger events say what actually filled;
2.  fills are execution rows derived from those events;
3.  trades are only the fill rows that close quantity;
4.  equity rows value the portfolio through time;
5.  summary metrics are formulas over those public result tables.

That order matters. A strategy can open a position without closing it.
That run has fills and equity exposure, but zero closed trades. In that
case `n_trades = 0` and `win_rate = NA` are correct, not missing data.

``` r
library(ledgr)
library(dplyr)
library(tibble)
```

## A Tiny Run

Use a five-bar in-memory fixture so the accounting can be checked by
hand. This article uses `ledgr_backtest()` as a compact fixture helper
for accounting examples. The canonical research workflow remains:
snapshot -\> `ledgr_experiment()` -\> `ledgr_run()`.

``` r
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
```

The strategy asks to hold one share on the first pulse and then returns
to flat. In these examples, decisions fill at the next open. The buy
therefore fills on the second bar, and the exit fills on the third bar.

## Fills And Trades

`what = "fills"` returns execution fill rows. Opening and closing fills
both appear here.

``` r
fills <- ledgr_results(bt, what = "fills")
fills
#> # A tibble: 2 x 9
#>   event_seq ts_utc     instrument_id side    qty price   fee realized_pnl action
#>       <int> <date>     <chr>         <chr> <dbl> <dbl> <dbl>        <dbl> <chr>
#> 1         1 2020-01-02 AAA           BUY       1   101     0            0 OPEN
#> 2         2 2020-01-03 AAA           SELL      1   105     0            4 CLOSE
```

The important columns are:

| Column         | Meaning                                      |
|----------------|----------------------------------------------|
| `side`         | execution direction, such as `BUY` or `SELL` |
| `qty`          | absolute fill quantity                       |
| `price`        | fill price                                   |
| `fee`          | execution fee charged on the fill            |
| `action`       | whether the fill opened or closed quantity   |
| `realized_pnl` | profit or loss booked by closing quantity    |

`what = "trades"` keeps only closed trade rows. That is the table used
by `n_trades`, `win_rate`, and `avg_trade`.

``` r
trades <- ledgr_results(bt, what = "trades")
trades
#> # A tibble: 1 x 9
#>   event_seq ts_utc     instrument_id side    qty price   fee realized_pnl action
#>       <int> <date>     <chr>         <chr> <dbl> <dbl> <dbl>        <dbl> <chr>
#> 1         2 2020-01-03 AAA           SELL      1   105     0            4 CLOSE
```

This run has two fill rows but one closed trade row. Counting fills as
trades would double-count the round trip.

## Equity Rows

The equity curve records portfolio state through time. It combines cash,
current position value, and equity.

``` r
equity <- ledgr_results(bt, what = "equity")
equity
#> # A tibble: 5 x 6
#>   ts_utc     equity  cash positions_value running_max drawdown
#>   <date>      <dbl> <dbl>           <dbl>       <dbl>    <dbl>
#> 1 2020-01-01   1000  1000               0        1000        0
#> 2 2020-01-02   1000   899             101        1000        0
#> 3 2020-01-03   1004  1004               0        1004        0
#> 4 2020-01-04   1004  1004               0        1004        0
#> 5 2020-01-05   1004  1004               0        1004        0
```

Open positions affect `positions_value` and therefore equity even before
any trade closes. Realized P&L belongs to closed quantity; open-position
gains and losses stay in the equity curve until a closing fill realizes
them.

## Recompute The Metrics

The summary metrics can be recomputed from public result tables.

``` r
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
#> # A tibble: 1 x 8
#>   total_return annualized_return volatility max_drawdown n_trades win_rate avg_trade
#>          <dbl>             <dbl>      <dbl>        <dbl>    <int>    <dbl>     <dbl>
#> 1      0.00400             0.286     0.0317            0        1        1         4
#> # i 1 more variable: time_in_market <dbl>
```

Those are the same definitions used by `summary(bt)` and
`ledgr_compute_metrics(bt)`. The first public equity row is the initial
equity for return calculations. Max drawdown is the maximum
peak-to-trough decline in the public equity rows. Time in market is the
share of equity rows with absolute `positions_value > 1e-6`.

This small example uses `bars_per_year <- 252` because the bars are
daily. ledgr detects bar frequency for `ledgr_compute_metrics()` and
snaps common cadences, such as daily and weekly, to standard
annualization constants. Use the detected value if you need an external
calculation to match ledgr exactly on non-daily data.

``` r
summary(bt)
#> ledgr Backtest Summary
#> ======================
#>
#> Performance Metrics:
#>   Total Return:        0.40%
#>   Annualized Return:   28.59%
#>   Max Drawdown:        0.00%
#>
#> Risk Metrics:
#>   Volatility (annual): 3.17%
#>
#> Trade Statistics:
#>   Total Trades:        1
#>   Win Rate:            100.00%
#>   Avg Trade:           $4.00
#>
#> Exposure:
#>   Time in Market:      20.00%
```

## Zero Trades Can Be Correct

A flat strategy produces no fills and no closed trades. The result
tables still keep their schemas, so downstream code can rely on the same
column names.

``` r
flat_strategy <- function(ctx, params) ctx$flat()

flat_bt <- ledgr_backtest(
  data = bars,
  strategy = flat_strategy,
  initial_cash = 1000,
  run_id = "flat_accounting_example"
)

ledgr_results(flat_bt, what = "fills")
#> # A tibble: 0 x 9
#> # i 9 variables: event_seq <int>, ts_utc <date>, instrument_id <chr>, side <chr>,
#> #   qty <dbl>, price <dbl>, fee <dbl>, realized_pnl <dbl>, action <chr>
ledgr_results(flat_bt, what = "trades")
#> # A tibble: 0 x 9
#> # i 9 variables: event_seq <int>, ts_utc <date>, instrument_id <chr>, side <chr>,
#> #   qty <dbl>, price <dbl>, fee <dbl>, realized_pnl <dbl>, action <chr>
ledgr_compute_metrics(flat_bt)[c("n_trades", "win_rate", "avg_trade")]
#> $n_trades
#> [1] 0
#>
#> $win_rate
#> [1] NA
#>
#> $avg_trade
#> [1] NA
```

`win_rate` and `avg_trade` are `NA` because there are no closed trade
rows to evaluate. That is different from a zero percent win rate, which
would mean there were trades and none of them were profitable.

## Open Positions And Final-Bar Targets

An open-only run is also valid. It has an opening fill and equity
exposure, but no closed trade rows. The unrealized result belongs in
equity, not in `realized_pnl`.

``` r
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
#> # A tibble: 1 x 9
#>   event_seq ts_utc     instrument_id side    qty price   fee realized_pnl action
#>       <int> <date>     <chr>         <chr> <dbl> <dbl> <dbl>        <dbl> <chr>
#> 1         1 2020-01-02 AAA           BUY       1   101     0            0 OPEN
ledgr_results(open_bt, what = "trades")
#> # A tibble: 0 x 9
#> # i 9 variables: event_seq <int>, ts_utc <date>, instrument_id <chr>, side <chr>,
#> #   qty <dbl>, price <dbl>, fee <dbl>, realized_pnl <dbl>, action <chr>
ledgr_compute_metrics(open_bt)[c("n_trades", "win_rate", "avg_trade")]
#> $n_trades
#> [1] 0
#>
#> $win_rate
#> [1] NA
#>
#> $avg_trade
#> [1] NA
```

A final-bar target under a next-open fill model can also be valid
research input while producing no fill. There is no later bar available
for execution, so ledgr warns and leaves the ledger unchanged for that
last target change.

``` r
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
#> [1] TRUE
ledgr_results(final_bar_bt, what = "fills")
#> # A tibble: 0 x 9
#> # i 9 variables: event_seq <int>, ts_utc <date>, instrument_id <chr>, side <chr>,
#> #   qty <dbl>, price <dbl>, fee <dbl>, realized_pnl <dbl>, action <chr>
```

## Diagnose A Successful Run With Zero Trades

A completed run with zero trades is not automatically wrong. It means
ledgr accepted the strategy outputs and the ledger reached the end of
the sample, but no closed round trips were recorded.

Use this checklist before changing the strategy:

1.  Start with `summary(bt)`. If `Total Trades` is zero, `win_rate` and
    `avg_trade` should be `NA`, not zero.
2.  Inspect `ledgr_results(bt, what = "fills")`. Empty fills mean
    nothing ever executed. Non-empty fills with empty trades mean
    positions opened but did not close.
3.  Confirm the feature IDs with `ledgr_feature_id(features)`. A helper
    such as `signal_return(ctx, lookback = 60)` reads `return_60`; that
    indicator must be registered before the run.
4.  Inspect a late pulse with `ledgr_pulse_snapshot()`. If the feature
    is still `NA` for every instrument near the end of the sample, the
    issue is no longer ordinary early warmup. Check the lookback length,
    sample length, universe, and feature registration.
5.  If the strategy suppresses `ledgr_empty_selection` warnings during a
    full run, rerun the same helper pipeline on the diagnostic pulse
    without suppression. The warning message reports the signal origin
    and non-missing count.

Expected warmup is local to the beginning of a run. A signal that has
zero usable values over the whole sample is a different condition, even
though both appear as `NA` feature values at a single pulse.

## Cleanup

Closing handles releases DuckDB resources in long sessions. It is not
data safety ceremony; completed run artifacts are already durable when
the run returns.

``` r
close(bt)
close(flat_bt)
close(open_bt)
close(final_bar_bt)
```

## What’s Next?

For strategy authoring, read
`vignette("strategy-development", package = "ledgr")`. For indicators,
feature IDs, and warmup, read
`vignette("indicators", package = "ledgr")`. For durable run inspection,
read `vignette("experiment-store", package = "ledgr")`.
