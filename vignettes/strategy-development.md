Strategy Development And Comparison
================

A ledgr strategy is a function that receives a pulse context and returns
target holdings.

``` r
library(ledgr)
library(dplyr)
data("ledgr_demo_bars", package = "ledgr")
```

At each pulse, ledgr gives the strategy the current observable state.
The strategy answers with a full named numeric vector: the desired
quantity for every instrument in `ctx$universe`.

## The Strategy Function

The simplest form is `function(ctx, params)`.

``` r
flat_strategy <- function(ctx, params) {
  ctx$flat()
}
```

Parameterized strategies use `function(ctx, params)`. Parameters arrive
as the second argument. There is no `ctx$params` field.

``` r
threshold_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  for (id in ctx$universe) {
    if (ctx$close(id) > params$threshold[[id]]) {
      targets[id] <- params$qty
    }
  }
  targets
}
```

## What Is `ctx`?

`ctx` is the pulse context. It represents one decision point. The main
fields and helpers are:

- `ctx$ts_utc`: current pulse timestamp;
- `ctx$universe`: character vector of instrument IDs;
- `ctx$bars`: current OHLCV rows;
- `ctx$features`: long feature table at the current pulse;
- `ctx$features_wide`: wide feature table for scanning;
- `ctx$positions`: current position vector;
- `ctx$cash`: current simulated cash;
- `ctx$equity`: current simulated equity;
- `ctx$open(id)`, `ctx$high(id)`, `ctx$low(id)`, `ctx$close(id)`,
  `ctx$volume(id)`: scalar OHLCV accessors;
- `ctx$position(id)`: current quantity for one instrument;
- `ctx$feature(id, name)`: feature lookup;
- `ctx$flat(default = 0)`: full target vector initialized to `default`;
- `ctx$hold()`: full target vector initialized from current positions.

Use `ctx$flat()` when the strategy should go flat unless it explicitly
emits a target. Use `ctx$hold()` when the strategy should hold unless it
explicitly changes a target.

## Targets

Targets must be full named numeric vectors. Names must exactly match
`ctx$universe`.

``` r
buy_one_if_up <- function(ctx, params) {
  targets <- ctx$flat()
  if (ctx$close("AAA") > ctx$open("AAA")) {
    targets["AAA"] <- 1
  }
  targets
}
```

v0.1.x is long-only. Negative targets are outside the supported public
workflow until explicit shorting semantics are specified.

The default fill model is next-open: a target decided at pulse `t` fills
at the next available bar. A target change on the final pulse cannot
fill.

## Indicators And Feature IDs

Built-in indicators are ordinary `ledgr_indicator` objects.

``` r
sma_3 <- ledgr_ind_sma(3)
ret_1 <- ledgr_ind_returns(1)
ledgr_feature_id(list(sma_3, ret_1))
#> [1] "sma_3"    "return_1"
```

TTR indicators use `ledgr_ind_ttr()`.

``` r
rsi_3 <- ledgr_ind_ttr("RSI", input = "close", n = 3)
bb_up <- ledgr_ind_ttr("BBands", input = "close", output = "up", n = 3)
ledgr_feature_id(list(rsi_3, bb_up))
#> [1] "ttr_rsi_3"       "ttr_bbands_3_up"
```

Feature IDs are exact strings. Ask ledgr for them before writing
`ctx$feature()` calls.

Feature values can be `NA` during warmup. Unknown feature IDs fail
loudly; warmup `NA` for known features is normal.

``` r
rsi_strategy <- function(ctx, params) {
  targets <- ctx$hold()
  rsi <- ctx$feature("AAA", "ttr_rsi_3")
  if (is.na(rsi)) return(targets)

  if (rsi < params$buy_below) {
    targets["AAA"] <- params$qty
  } else if (rsi > params$sell_above) {
    targets["AAA"] <- 0
  }
  targets
}
```

## Debug One Pulse

`ledgr_pulse_snapshot()` freezes the context at one timestamp so you can
inspect what a strategy saw.

``` r
bars <- ledgr_demo_bars |>
  filter(
    instrument_id %in% c("DEMO_01", "DEMO_02"),
    between(ts_utc, ledgr_utc("2019-01-01"), ledgr_utc("2019-04-30"))
  )

snapshot <- ledgr_snapshot_from_df(
  bars,
  snapshot_id = "strategy_demo_snapshot"
)
```

``` r
pulse <- ledgr_pulse_snapshot(
  snapshot,
  universe = c("DEMO_01", "DEMO_02"),
  ts_utc = "2019-03-01T00:00:00Z",
  features = list(sma_3, rsi_3)
)

pulse$close("DEMO_01")
#> [1] 106.5053
pulse$feature("DEMO_01", "sma_3")
#> [1] 103.9883
pulse$hold()
#> DEMO_01 DEMO_02
#>       0       0
threshold_strategy(
  pulse,
  list(threshold = c(DEMO_01 = 55, DEMO_02 = 75), qty = 1)
)
#> DEMO_01 DEMO_02
#>       1       0
close(pulse)
```

## Compare Parameter Variants

Run related strategy variants through one experiment.

``` r
exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = threshold_strategy,
  opening = ledgr_opening(cash = 10000)
)

bt_qty_1 <- exp |>
  ledgr_run(
    params = list(threshold = c(DEMO_01 = 55, DEMO_02 = 75), qty = 1),
    run_id = "threshold_qty_1"
  )

bt_qty_3 <- exp |>
  ledgr_run(
    params = list(threshold = c(DEMO_01 = 55, DEMO_02 = 75), qty = 3),
    run_id = "threshold_qty_3"
  )

ledgr_compare_runs(snapshot, run_ids = c("threshold_qty_1", "threshold_qty_3"))
#> # ledgr comparison
#> # A tibble: 2 x 8
#>   run_id          label final_equity total_return max_drawdown n_trades win_rate
#>   <chr>           <chr>        <dbl> <chr>        <chr>           <int> <chr>
#> 1 threshold_qty_1 <NA>        10084. +0.8%        -0.8%               0 <NA>
#> 2 threshold_qty_3 <NA>        10251. +2.5%        -2.4%               0 <NA>
#> # i 1 more variable: reproducibility_level <chr>
#>
#> # i Full identity and telemetry columns remain available on this tibble.
#> # i Inspect one run with ledgr_run_info(snapshot, run_id).
```

## Compare Different Strategies

The same comparison table also works across different strategy
functions.

``` r
flat_exp <- ledgr_experiment(
  snapshot,
  strategy = flat_strategy,
  opening = ledgr_opening(cash = 10000)
)

bt_flat <- flat_exp |>
  ledgr_run(params = list(), run_id = "flat")

ledgr_compare_runs(snapshot, run_ids = c("threshold_qty_1", "flat"))
#> # ledgr comparison
#> # A tibble: 2 x 8
#>   run_id          label final_equity total_return max_drawdown n_trades win_rate
#>   <chr>           <chr>        <dbl> <chr>        <chr>           <int> <chr>
#> 1 threshold_qty_1 <NA>        10084. +0.8%        -0.8%               0 <NA>
#> 2 flat            <NA>        10000  +0.0%        0.0%                0 <NA>
#> # i 1 more variable: reproducibility_level <chr>
#>
#> # i Full identity and telemetry columns remain available on this tibble.
#> # i Inspect one run with ledgr_run_info(snapshot, run_id).
```

## Inspect Stored Source

`ledgr_extract_strategy(..., trust = FALSE)` returns stored source and
metadata without parsing or evaluating it.

``` r
extracted <- ledgr_extract_strategy(snapshot, "threshold_qty_1", trust = FALSE)
extracted
#> ledgr Extracted Strategy
#> ========================
#>
#> Run ID:          threshold_qty_1
#> Reproducibility: tier_1
#> Source Hash:     afbf00a42940c4bc95ec6c46d5eb886aa7c2d6c1546eaf875e918880ee6abf36
#> Params Hash:     49fb6f889a174d502c0c6060bced4c8244a3d11631b8e480743e228657da5e6d
#> Hash Verified:   TRUE
#> Trust:           FALSE
#> Source Available:TRUE
```

Use `trust = TRUE` only when you explicitly trust the experiment store
and want to recover a function object. Hash verification proves
stored-text identity, not safety.

``` r
close(bt_qty_1)
close(bt_qty_3)
close(bt_flat)
close(snapshot)
```
