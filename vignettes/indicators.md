Indicators And Feature IDs
================

``` r
library(ledgr)
library(dplyr)
data("ledgr_demo_bars", package = "ledgr")
```

Indicators are how ledgr turns sealed market data into pulse-time
features. This article teaches the runtime shape first, then the
accessor APIs.

The central model is:

> ledgr computes feature contracts into pulse-known data; the accessors
> are different views into that same pulse.

That model is the same for built-in ledgr indicators, TTR-backed
indicators, and custom indicators.

## Start With Built-In Features

Use two demo instruments and two built-in features. The economic idea
will be small on purpose:

> Own an instrument only when its recent return is positive enough and
> today's close is above its moving average.

That rule needs one momentum feature and one trend feature. A feature
map gives readable aliases to your R code while preserving ledgr's exact
engine feature IDs.

``` r
features <- ledgr_feature_map(
  ret_5 = ledgr_ind_returns(5),
  sma_10 = ledgr_ind_sma(10)
)
```

There are two names in play:

- the **alias** is the readable name you choose, such as `ret_5` or
  `sma_10`;
- the **feature ID** is ledgr's stable engine name, such as `return_5`
  or `sma_10`.

Use aliases when you write strategy logic with `ctx$features()`. Use
feature IDs when you need the explicit engine contract, for example with
`ctx$feature()` or when inspecting stored feature metadata.

The same idea works for crossover rules. An SMA crossover registers two
separate indicators: one short moving average and one long moving
average. The economic meaning is "fast trend above slow trend" rather
than "close above one trend line." Each moving average has its own
feature ID, warmup, and stored values.

``` r
crossover_features <- ledgr_feature_map(
  sma_fast = ledgr_ind_sma(10),
  sma_slow = ledgr_ind_sma(30)
)

ledgr_feature_contracts(crossover_features)
#> # A tibble: 2 × 5
#>   alias    feature_id source requires_bars stable_after
#>   <chr>    <chr>      <chr>          <int>        <int>
#> 1 sma_fast sma_10     ledgr             10           10
#> 2 sma_slow sma_30     ledgr             30           30
```

In a strategy, the crossover condition is just a comparison of the two
mapped aliases after warmup:

``` r
x <- ctx$features(id, crossover_features)
if (passed_warmup(x) && x[["sma_fast"]] > x[["sma_slow"]]) {
  targets[id] <- params$qty
}
```

## Inspect One Pulse

Create a small sealed snapshot and inspect one decision pulse before
running a full backtest. This keeps the runtime data visible before the
article introduces more metadata.

``` r
bars <- ledgr_demo_bars |>
  filter(
    instrument_id %in% c("DEMO_01", "DEMO_02"),
    between(
      ts_utc,
      ledgr_utc("2019-01-01"),
      ledgr_utc("2019-06-30")
    )
  )

snapshot <- ledgr_snapshot_from_df(
  bars,
  snapshot_id = paste0("indicators-vignette-", Sys.getpid())
)

pulse <- ledgr_pulse_snapshot(
  snapshot,
  universe = c("DEMO_01", "DEMO_02"),
  ts_utc = ledgr_utc("2019-03-01"),
  features = features
)
```

At this timestamp, ledgr has computed the same two features for each
instrument in the universe. The long pulse view shows that directly: one
row per instrument and feature. Without a feature map, `alias` is `NA`.
With the map, rows are filtered to the mapped features and aliases are
filled.

``` r
ledgr_pulse_features(pulse, features)
#> # A tibble: 4 × 5
#>   ts_utc              instrument_id feature_id feature_value alias
#>   <dttm>              <chr>         <chr>              <dbl> <chr>
#> 1 2019-03-01 00:00:00 DEMO_01       return_5         0.0853  ret_5
#> 2 2019-03-01 00:00:00 DEMO_01       sma_10          99.8     sma_10
#> 3 2019-03-01 00:00:00 DEMO_02       return_5         0.00402 ret_5
#> 4 2019-03-01 00:00:00 DEMO_02       sma_10          68.2     sma_10
```

The wide pulse view is useful for debugging and future model-style
workflows. It contains one OHLCV block and one feature block for each
instrument. OHLCV columns use `{instrument_id}__ohlcv_{field}`. Feature
columns use `{instrument_id}__feature_{feature_id}`. A feature map can
filter and order feature columns, but it does not rename wide columns to
aliases.

``` r
ledgr_pulse_wide(pulse, features)
#> # A tibble: 1 × 17
#>   ts_utc                cash equity DEMO_01__ohlcv_open DEMO_01__ohlcv_high
#>   <dttm>               <dbl>  <dbl>               <dbl>               <dbl>
#> 1 2019-03-01 00:00:00 100000 100000                103.                107.
#> # ℹ 12 more variables: DEMO_01__ohlcv_low <dbl>, DEMO_01__ohlcv_close <dbl>,
#> #   DEMO_01__ohlcv_volume <dbl>, DEMO_01__feature_return_5 <dbl>,
#> #   DEMO_01__feature_sma_10 <dbl>, DEMO_02__ohlcv_open <dbl>, DEMO_02__ohlcv_high <dbl>,
#> #   DEMO_02__ohlcv_low <dbl>, DEMO_02__ohlcv_close <dbl>, DEMO_02__ohlcv_volume <dbl>,
#> #   DEMO_02__feature_return_5 <dbl>, DEMO_02__feature_sma_10 <dbl>
```

`ledgr_pulse_features()` and `ledgr_pulse_wide()` work on interactive
pulse snapshots and on the `ctx` object inside an ordinary strategy
function. They are inspection views over the same pulse-known data used
by `ctx$feature()` and `ctx$features()`.

## Access Features In A Strategy

The long and wide pulse views are useful when you want to inspect the
computed data, compare instruments, or think in model-like rows. They
are not always the clearest shape for strategy code. A strategy often
wants to ask a smaller question: "what are the current values for this
instrument?"

That is why ledgr also exposes the same pulse data through scalar and
mapped accessors. The table views and the accessors are not competing
APIs; they are different views over the same pulse-known data.

The explicit scalar accessor is useful when you want to show or debug
one value. It uses the engine ID, not the alias:

``` r
ids <- ledgr_feature_id(features)
pulse$feature("DEMO_01", ids[["ret_5"]])
#> [1] 0.08531877
```

Mapped access returns a named numeric vector keyed by alias for one
instrument at one pulse:

``` r
x <- pulse$features("DEMO_01", features)
x
#>       ret_5      sma_10
#>  0.08531877 99.79637070
passed_warmup(x)
#> [1] TRUE
```

Inside a strategy, loop over `ctx$universe` so the rule works for every
instrument in the run.

Read the body economically:

- start from `ctx$flat()`, so the default desired state is no positions;
- inspect each instrument's current mapped features;
- skip the instrument while either feature is still in warmup;
- buy `params$qty` only when recent return is above the threshold and
  price is above the moving average;
- because the strategy starts flat on every pulse, an instrument is sold
  when the condition stops being true.

``` r
strategy <- function(ctx, params) {
  targets <- ctx$flat()

  for (id in ctx$universe) {
    x <- ctx$features(id, features)

    if (
      passed_warmup(x) &&
        x[["ret_5"]] > params$min_return &&
        ctx$close(id) > x[["sma_10"]]
    ) {
      targets[id] <- params$qty
    }
  }

  targets
}
```

That pattern keeps the signal logic readable:

- `features` is where feature identity and aliases live.
- `ctx$features()` reads the current mapped values for one instrument.
- `passed_warmup()` is the warmup gate for the mapped feature vector.
- The condition after the warmup gate is the economic rule.
- The strategy still returns ordinary target quantities.

## Run The Example

The experiment registers the indicator objects. ledgr computes those
features for every instrument at each pulse, then gives the strategy
only the pulse-time values.

``` r
exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = strategy,
  features = features,
  opening = ledgr_opening(cash = 10000)
)

run_id <- paste0("indicators-demo-", Sys.getpid())

bt <- exp |>
  ledgr_run(params = list(min_return = 0, qty = 10), run_id = run_id)
#> Warning: LEDGR_LAST_BAR_NO_FILL

ledgr_results(bt, what = "fills")
#> # A tibble: 39 × 9
#>    event_seq ts_utc     instrument_id side    qty price   fee realized_pnl action
#>        <int> <date>     <chr>         <chr> <dbl> <dbl> <dbl>        <dbl> <chr>
#>  1         1 2019-01-23 DEMO_01       BUY      10  88.0     0         0    OPEN
#>  2         2 2019-01-30 DEMO_02       BUY      10  71.1     0         0    OPEN
#>  3         3 2019-02-01 DEMO_02       SELL     10  69.3     0       -17.9  CLOSE
#>  4         4 2019-02-06 DEMO_01       SELL     10  92.9     0        49.3  CLOSE
#>  5         5 2019-02-13 DEMO_01       BUY      10  93.9     0         0    OPEN
#>  6         6 2019-02-19 DEMO_02       BUY      10  68.7     0         0    OPEN
#>  7         7 2019-02-25 DEMO_02       SELL     10  67.5     0       -12.2  CLOSE
#>  8         8 2019-03-08 DEMO_02       BUY      10  68.9     0         0    OPEN
#>  9         9 2019-03-11 DEMO_01       SELL     10 106.      0       123.   CLOSE
#> 10        10 2019-03-11 DEMO_02       SELL     10  68.0     0        -9.18 CLOSE
#> # ℹ 29 more rows

close(pulse)
close(bt)
ledgr_snapshot_close(snapshot)
```

## Read The Feature Contracts

After you have seen the feature values at a pulse, the contract table is
easier to read. The feature contracts are what ledgr will compute for
every instrument in the run. `alias` is for your strategy code.
`feature_id` is the stable engine ID. Warmup metadata tells you when a
known feature may still be `NA`.

``` r
ledgr_feature_contracts(features)
#> # A tibble: 2 × 5
#>   alias  feature_id source requires_bars stable_after
#>   <chr>  <chr>      <chr>          <int>        <int>
#> 1 ret_5  return_5   ledgr              6            6
#> 2 sma_10 sma_10     ledgr             10           10
```

Plain lists remain valid too. For a named list, names become aliases in
the contract table. For an unnamed list, `alias` is `NA`.

``` r
plain_features <- list(ledgr_ind_returns(5), ledgr_ind_sma(10))
ledgr_feature_contracts(plain_features)
#> # A tibble: 2 × 5
#>   alias feature_id source requires_bars stable_after
#>   <chr> <chr>      <chr>          <int>        <int>
#> 1 <NA>  return_5   ledgr              6            6
#> 2 <NA>  sma_10     ledgr             10           10
```

## Parameter Grids Register Every Needed Feature

If a parameter grid changes a lookback, register every lookback variant
before the run. ledgr does not create indicators dynamically from
`params`; the run only computes the feature contracts registered on the
experiment.

``` r
swept_features <- ledgr_feature_map(
  ret_5 = ledgr_ind_returns(5),
  ret_10 = ledgr_ind_returns(10),
  ret_20 = ledgr_ind_returns(20)
)

feature_ids <- ledgr_feature_id(swept_features)

parameterized_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  feature_id <- feature_ids[[paste0("ret_", params$lookback)]]

  for (id in ctx$universe) {
    ret <- ctx$feature(id, feature_id)
    if (is.finite(ret) && ret > params$min_return) {
      targets[id] <- params$qty
    }
  }

  targets
}

grid <- ledgr_param_grid(
  lookback = c(5, 10, 20),
  min_return = 0,
  qty = 10
)
```

The important rule is that the feature set covers the whole grid:
`lookback = 20` means `return_20` must already be registered. A missing
feature ID is an unknown-feature error, not warmup. The alias names in
`swept_features` must also match the lookup key pattern used by the
strategy, here `paste0("ret_", params$lookback)`. In short, all feature
parameter values must be registered before `ledgr_run()`; do not create
`ledgr_ind_returns(params$lookback)` lazily inside the strategy.

## TTR-Backed Indicators

`ledgr_ind_ttr()` is the adapter for supported indicators from the
suggested `TTR` package. TTR stays outside the core engine:

``` text
TTR -> ledgr_ind_ttr() -> ledgr_indicator -> deterministic pulse engine
```

The engine sees a normal `ledgr_indicator`. That means TTR-backed
indicators follow the same feature-ID, warmup, and pulse-view rules as
built-in indicators. The examples below are skipped when `TTR` is not
installed. In your own project, install TTR before creating TTR-backed
indicators:

``` r
install.packages("TTR")
```

``` r
ttr_features <- ledgr_feature_map(
  ret_5 = ledgr_ind_returns(5),
  ttr_rsi = ledgr_ind_ttr("RSI", input = "close", n = 14),
  bb_up = ledgr_ind_ttr("BBands", input = "close", output = "up", n = 20),
  macd = ledgr_ind_ttr(
    "MACD",
    input = "close",
    output = "macd",
    nFast = 12,
    nSlow = 26,
    nSig = 9,
    percent = FALSE
  ),
  macd_signal = ledgr_ind_ttr(
    "MACD",
    input = "close",
    output = "signal",
    nFast = 12,
    nSlow = 26,
    nSig = 9,
    percent = FALSE
  )
)

ledgr_feature_contracts(ttr_features)
#> # A tibble: 5 × 5
#>   alias       feature_id                    source requires_bars stable_after
#>   <chr>       <chr>                         <chr>          <int>        <int>
#> 1 ret_5       return_5                      ledgr              6            6
#> 2 ttr_rsi     ttr_rsi_14                    TTR               15           15
#> 3 bb_up       ttr_bbands_20_up              TTR               20           20
#> 4 macd        ttr_macd_12_26_9_false_macd   TTR               34           34
#> 5 macd_signal ttr_macd_12_26_9_false_signal TTR               34           34
ledgr_feature_id(ttr_features)
#>                           ret_5                         ttr_rsi
#>                      "return_5"                    "ttr_rsi_14"
#>                           bb_up                            macd
#>              "ttr_bbands_20_up"   "ttr_macd_12_26_9_false_macd"
#>                     macd_signal
#> "ttr_macd_12_26_9_false_signal"
```

This mixed feature map combines a built-in return feature with
TTR-backed RSI, BBands, and MACD features. The examples produce IDs such
as `return_5`, `ttr_rsi_14`, `ttr_bbands_20_up`,
`ttr_macd_12_26_9_false_macd`, and `ttr_macd_12_26_9_false_signal`.

RSI is a common mean-reversion input. One compact rule is: buy when RSI
is below 30, then return to flat when the condition is no longer true.
The experiment registers the RSI indicator before the run; the strategy
only reads the pulse-time value.

``` r
rsi_features <- ledgr_feature_map(
  rsi_14 = ledgr_ind_ttr("RSI", input = "close", n = 14)
)

rsi_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  for (id in ctx$universe) {
    x <- ctx$features(id, rsi_features)
    if (passed_warmup(x) && x[["rsi_14"]] < params$oversold) {
      targets[id] <- params$qty
    }
  }
  targets
}

rsi_snapshot <- ledgr_snapshot_from_df(
  bars,
  snapshot_id = paste0("rsi-vignette-", Sys.getpid())
)

rsi_exp <- ledgr_experiment(
  snapshot = rsi_snapshot,
  strategy = rsi_strategy,
  features = rsi_features,
  opening = ledgr_opening(cash = 10000)
)

rsi_bt <- ledgr_run(
  rsi_exp,
  params = list(oversold = 30, qty = 10),
  run_id = paste0("rsi-demo-", Sys.getpid())
)

ledgr_results(rsi_bt, what = "fills")
#> # A tibble: 10 × 9
#>    event_seq ts_utc     instrument_id side    qty price   fee realized_pnl action
#>        <int> <date>     <chr>         <chr> <dbl> <dbl> <dbl>        <dbl> <chr>
#>  1         1 2019-01-22 DEMO_01       BUY      10  87.2     0        0     OPEN
#>  2         2 2019-01-24 DEMO_01       SELL     10  89.0     0       17.9   CLOSE
#>  3         3 2019-02-12 DEMO_02       BUY      10  66.1     0        0     OPEN
#>  4         4 2019-02-14 DEMO_02       SELL     10  66.5     0        3.85  CLOSE
#>  5         5 2019-06-10 DEMO_01       BUY      10  91.2     0        0     OPEN
#>  6         6 2019-06-18 DEMO_01       SELL     10  87.7     0      -35.1   CLOSE
#>  7         7 2019-06-19 DEMO_01       BUY      10  87.3     0        0     OPEN
#>  8         8 2019-06-21 DEMO_01       SELL     10  87.3     0        0.267 CLOSE
#>  9         9 2019-06-24 DEMO_01       BUY      10  86.5     0        0     OPEN
#> 10        10 2019-06-26 DEMO_01       SELL     10  86.8     0        2.87  CLOSE
close(rsi_bt)
ledgr_snapshot_close(rsi_snapshot)
```

Some TTR functions return several columns. For those functions, choose
one column with `output` before asking ledgr for the feature ID.
`BBands` exposes `dn`, `mavg`, `up`, and `pctB`. `MACD` exposes `macd`
and `signal`; ledgr also supports a derived `histogram`.

``` r
ledgr_feature_contracts(ledgr_feature_map(
  bb_dn = ledgr_ind_ttr("BBands", input = "close", output = "dn", n = 20),
  bb_mavg = ledgr_ind_ttr("BBands", input = "close", output = "mavg", n = 20),
  bb_up = ledgr_ind_ttr("BBands", input = "close", output = "up", n = 20),
  bb_pctB = ledgr_ind_ttr("BBands", input = "close", output = "pctB", n = 20)
))
#> # A tibble: 4 × 5
#>   alias   feature_id         source requires_bars stable_after
#>   <chr>   <chr>              <chr>          <int>        <int>
#> 1 bb_dn   ttr_bbands_20_dn   TTR               20           20
#> 2 bb_mavg ttr_bbands_20_mavg TTR               20           20
#> 3 bb_up   ttr_bbands_20_up   TTR               20           20
#> 4 bb_pctB ttr_bbands_20_pctb TTR               20           20
```

The two MACD examples above use matching explicit arguments. Explicit
arguments become part of the feature ID, so combine MACD outputs in one
strategy only when their argument sets match the computation you intend.
If one MACD output uses `percent = FALSE`, the paired `signal` output
should usually set `percent = FALSE` too.

TTR warmup inference is inspectable:

``` r
ledgr_ttr_warmup_rules() |>
  select(ttr_fn, input, formula)
#> # A tibble: 18 × 3
#>    ttr_fn          input formula
#>    <chr>           <chr> <chr>
#>  1 RSI             close n + 1
#>  2 SMA             close n
#>  3 EMA             close n
#>  4 ATR             hlc   n + 1
#>  5 MACD            close nSlow + nSig - 1
#>  6 WMA             close n
#>  7 ROC             close n + 1
#>  8 momentum        close n + 1
#>  9 CCI             hlc   n
#> 10 BBands          close n
#> 11 aroon           hl    n
#> 12 DonchianChannel hl    n
#> 13 MFI             hlcv  n + 1
#> 14 CMF             hlcv  n
#> 15 runMean         close n
#> 16 runSD           close n
#> 17 runVar          close n
#> 18 runMAD          close n
```

For MACD, ledgr verifies the supported warmup rules against direct TTR
output. TTR computes the signal EMA internally even when you select only
the `macd` column. In a pulse-by-pulse backtest, all supported MACD
outputs are therefore first callable at `nSlow + nSig - 1`. The same
rule is verified for `macd`, `signal`, the derived ledgr `histogram`,
and both `percent = TRUE` and `percent = FALSE`.

To debug a TTR-backed feature at one decision time, use an active
snapshot handle, choose a timestamp late enough for the indicator
warmup, and pass the same TTR feature map to `ledgr_pulse_snapshot()`. A
completed backtest proves the run succeeded, but it does not replace the
snapshot handle needed for interactive pulse inspection.

``` r
ttr_pulse <- ledgr_pulse_snapshot(
  snapshot,
  universe = c("DEMO_01", "DEMO_02"),
  ts_utc = ledgr_utc("2019-06-03"),
  features = ttr_features
)

ledgr_pulse_features(ttr_pulse, ttr_features)
close(ttr_pulse)
```

## Troubleshoot Warmup And Zero Trades

Warmup problems are easiest to diagnose by connecting three facts:

1.  `ledgr_feature_contracts(features)` tells you how many bars each
    feature needs before it can produce a usable value.
2.  `ledgr_pulse_features(pulse, features)` shows the current
    pulse-known values for the instruments and aliases you registered.
3.  `summary(bt)` prints `Warmup Diagnostics` when a completed run has
    registered features that can never become usable for an instrument
    because available bars are below the feature contract.

Normal early warmup is temporary: a feature is `NA` near the beginning
of an instrument's sample and later becomes finite. Impossible warmup is
different: the instrument never has enough available bars for that
feature. In that case, zero trades can be a valid completed run plus a
useful diagnostic, not a failed run.

For result-table interpretation after a zero-trade run, read
`vignette("metrics-and-accounting", package = "ledgr")`.

## Unsupported Or Custom Indicators

When a TTR function is not in the warmup rules table, provide
`requires_bars` explicitly:

``` r
ledgr_ind_ttr(
  "DEMA",
  input = "close",
  n = 10,
  requires_bars = 20
)$id
#> [1] "ttr_dema_10"
```

For non-TTR sources or more specialized logic, use `ledgr_indicator()`
directly with a `series_fn`. That is the adapter escape hatch: external
logic remains at the boundary, while the engine keeps the same
deterministic indicator contract.

## What's Next?

For strategy authoring, read
`vignette("strategy-development", package = "ledgr")`. For accounting
and summary metrics, read
`vignette("metrics-and-accounting", package = "ledgr")`. For formal help
on the inspection views, see `?ledgr_feature_contracts`,
`?ledgr_pulse_features`, and `?ledgr_pulse_wide`. For TTR-specific
output names and supported warmup inference, see `?ledgr_ind_ttr` and
`?ledgr_ttr_warmup_rules`.
