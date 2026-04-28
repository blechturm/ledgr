Strategy Development And Comparison
================

A ledgr strategy is a function that receives a pulse context and returns
target holdings.

``` r
library(ledgr)
```

At each pulse, ledgr gives the strategy the current observable state.
The strategy answers with a full named numeric vector: the desired
quantity for every instrument in `ctx$universe`.

## The Strategy Function

The simplest form is `function(ctx)`.

``` r
flat_strategy <- function(ctx) {
  ctx$targets()
}
```

Parameterized strategies use `function(ctx, params)`. Parameters arrive
as the second argument. There is no `ctx$params` field.

``` r
threshold_strategy <- function(ctx, params) {
  targets <- ctx$targets()
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
- `ctx$targets(default = 0)`: full target vector initialized to
  `default`;
- `ctx$current_targets()`: full target vector initialized from current
  positions.

Use `ctx$targets()` when the strategy should go flat unless it
explicitly emits a target. Use `ctx$current_targets()` when the strategy
should hold unless it explicitly changes a target.

## Targets

Targets must be full named numeric vectors. Names must exactly match
`ctx$universe`.

``` r
buy_one_if_up <- function(ctx) {
  targets <- ctx$targets()
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
  targets <- ctx$current_targets()
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
db_path <- tempfile(fileext = ".duckdb")

bars <- data.frame(
  ts_utc = rep(as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:7, 2),
  instrument_id = rep(c("AAA", "BBB"), each = 8),
  open = c(100, 101, 102, 103, 104, 103, 102, 101,
           80,  80,  81,  81,  82,  83,  82,  81),
  high = c(101, 102, 103, 104, 105, 104, 103, 102,
           81,  81,  82,  82,  83,  84,  83,  82),
  low = c(99, 100, 101, 102, 103, 102, 101, 100,
          79, 79, 80, 80, 81, 82, 81, 80),
  close = c(100, 101, 102, 103, 104, 103, 102, 101,
            80, 80, 81, 81, 82, 83, 82, 81),
  volume = 1000
)

snapshot <- ledgr_snapshot_from_df(
  bars,
  db_path = db_path,
  snapshot_id = "strategy_demo_snapshot"
)
```

``` r
pulse <- ledgr_pulse_snapshot(
  snapshot,
  universe = c("AAA", "BBB"),
  ts_utc = "2020-01-04T00:00:00Z",
  features = list(sma_3, rsi_3)
)

pulse$close("AAA")
#> [1] 103
pulse$feature("AAA", "sma_3")
#> [1] 102
pulse$current_targets()
#> AAA BBB
#>   0   0
threshold_strategy(
  pulse,
  list(threshold = c(AAA = 101, BBB = 80), qty = 1)
)
#> AAA BBB
#>   1   1
close(pulse)
```

## Compare Parameter Variants

Run related strategy variants into the same experiment store.

``` r
bt_qty_1 <- ledgr_backtest(
  snapshot = snapshot,
  strategy = threshold_strategy,
  strategy_params = list(threshold = c(AAA = 101, BBB = 80), qty = 1),
  end = "2020-01-07",
  db_path = db_path,
  run_id = "threshold_qty_1"
)

bt_qty_3 <- ledgr_backtest(
  snapshot = snapshot,
  strategy = threshold_strategy,
  strategy_params = list(threshold = c(AAA = 101, BBB = 80), qty = 3),
  end = "2020-01-07",
  db_path = db_path,
  run_id = "threshold_qty_3"
)

ledgr_compare_runs(db_path, run_ids = c("threshold_qty_1", "threshold_qty_3"))[, c(
  "run_id", "final_equity", "total_return", "n_trades", "strategy_params_hash"
)]
#> # A tibble: 2 x 5
#>   run_id          final_equity total_return n_trades strategy_params_hash
#>   <chr>                  <dbl>        <dbl>    <int> <chr>
#> 1 threshold_qty_1       100000            0        0 c9c0e58fc8eb6c19318a70ace1b640044df1~
#> 2 threshold_qty_3       100000            0        0 304fec414ddc77949e09dab9f5ce02a2b10f~
```

## Compare Different Strategies

The same comparison table also works across different strategy
functions.

``` r
bt_flat <- ledgr_backtest(
  snapshot = snapshot,
  strategy = flat_strategy,
  end = "2020-01-07",
  db_path = db_path,
  run_id = "flat"
)

ledgr_compare_runs(db_path, run_ids = c("threshold_qty_1", "flat"))[, c(
  "run_id", "final_equity", "total_return", "n_trades", "strategy_source_hash"
)]
#> # A tibble: 2 x 5
#>   run_id          final_equity total_return n_trades strategy_source_hash
#>   <chr>                  <dbl>        <dbl>    <int> <chr>
#> 1 threshold_qty_1       100000            0        0 7e92c0d24dd915b6037bbd1cb90c76264955~
#> 2 flat                  100000            0        0 3e404013b056168a274f2ecfbd6e9d06da55~
```

## Inspect Stored Source

`ledgr_extract_strategy(..., trust = FALSE)` returns stored source and
metadata without parsing or evaluating it.

``` r
extracted <- ledgr_extract_strategy(db_path, "threshold_qty_1", trust = FALSE)
extracted
#> ledgr Extracted Strategy
#> ========================
#>
#> Run ID:          threshold_qty_1
#> Reproducibility: tier_1
#> Source Hash:     7e92c0d24dd915b6037bbd1cb90c76264955c73363f045f4da2c239161f27e82
#> Params Hash:     c9c0e58fc8eb6c19318a70ace1b640044df1f6945b2cfd04715cebe20c8cb34c
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
