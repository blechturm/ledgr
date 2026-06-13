# Indicators And Features


<style>
.ledgr-diagram {
  margin: 1.25rem auto 1.5rem auto;
  text-align: center;
}
.ledgr-diagram .mermaid {
  display: inline-block;
  max-width: 760px;
  width: 100%;
}
.ledgr-diagram .node text,
.ledgr-diagram .edgeLabel {
  font-size: 18px !important;
}
</style>

Indicators are how ledgr turns sealed market data into pulse-time
features. This article teaches the runtime shape first, then the
accessor APIs.

<div class="ledgr-callout ledgr-callout-note">

**Definition**

An indicator is a declared feature computation. ledgr computes
indicators into pulse-known values; scalar accessors, mapped accessors,
long tables, and wide tables are different views of that same
pulse-known data.

</div>

That model is the same for built-in ledgr indicators, TTR-backed
indicators, and custom indicators.

## Prerequisites

``` r
library(ledgr)
library(dplyr)
data("ledgr_demo_bars", package = "ledgr")
```

## Start With Built-In Features

Use two demo instruments and two built-in features. The economic idea
will be small on purpose:

> Own an instrument only when its recent return is positive enough and
> today’s close is above its moving average.

That rule needs one momentum feature and one trend feature. A feature
map gives your strategy code readable aliases while preserving ledgr’s
exact engine feature IDs.

``` r
features <- ledgr_feature_map(
  ret_5 = ledgr_ind_returns(5),
  sma_10 = ledgr_ind_sma(10)
)
```

<div class="ledgr-callout ledgr-callout-note">

**Definition**

A feature ID is ledgr’s engine-facing name for a computed value. An
alias is the strategy-facing name you choose in a feature map. The alias
makes strategy code readable; the feature ID remains the durable engine
identity.

</div>

Use aliases such as `ret_5` or `sma_10` when you write strategy logic
with `ctx$features()`. Use feature IDs such as `return_5` or `sma_10`
when you need the explicit engine contract, for example with
`ctx$feature()` or when inspecting stored feature metadata.

Feature objects appear in three registration and inspection places:

| Surface | Accepted feature shape | How names are used |
|----|----|----|
| `ledgr_experiment(features = ...)` | indicator, list, named list, or feature map | registers feature definitions for the run |
| `ledgr_feature_contracts()` / `ledgr_feature_contract_check()` | static indicator, list, named list, or feature map | reports aliases and engine IDs |
| `ledgr_pulse_snapshot(features = ...)` | static list or feature map | computes pulse-known values for inspection |

The strategy context then exposes the computed values through accessors:

| Accessor | Name type | Use |
|----|----|----|
| `ctx$feature(id, feature_id)` | engine feature ID string | reads one scalar value by exact ID |
| `ctx$features(id, feature_map)` | feature map | returns a named vector keyed by alias |

The canonical workflow is: register features on `ledgr_experiment()`,
then read pulse-known values through `ctx$feature()` or `ctx$features()`
inside the strategy.

## Feature Lifecycle: From Declaration To Lookup

The feature path has five steps:

<div class="ledgr-diagram ledgr-feature-lifecycle">

``` mermaid

flowchart LR
  declare["declare<br/>indicator or map"]
  register["register<br/>experiment"]
  compute["compute<br/>pulse-known values"]
  access["access<br/>ctx feature methods"]
  decide["decide<br/>target holdings"]

  declare --> register --> compute --> access --> decide
```

</div>

1.  You declare features in any of several shapes: individual
    indicators, built-in helpers, TTR adapters, CSV/R adapters, feature
    maps, or active-alias parameterizations. All resolve to the same
    lifecycle below.
2.  `ledgr_experiment()` stores the declaration. Static lists and
    feature maps are ready immediately. Active-alias features are
    materialized for concrete feature-grid values before candidate
    execution.
3.  Optional `ledgr_precompute_features()` resolves a parameter grid,
    computes each candidate’s concrete feature set, deduplicates shared
    indicator fingerprints, and records candidate feature-set hashes.
4.  During `ledgr_run()` or `ledgr_sweep()`, the fold core computes the
    registered feature values at each pulse without looking past the
    current bar.
5.  Strategy code reads the current pulse-known values with
    `ctx$feature()` by engine feature ID, or with `ctx$features()` by
    feature-map alias.

<div class="ledgr-callout ledgr-callout-note">

**Definition**

A fingerprint identifies the feature definition, not just the name. If
the calculation, parameters, warmup rule, adapter, or selected output
changes, the fingerprint changes even when the feature ID stays
readable.

</div>

Feature IDs identify values inside the pulse context. Fingerprints
identify the feature definition used to compute those values. For
multi-output sources such as TTR `BBands` or `MACD`, each selected
output is an ordinary indicator with its own feature ID and
output-specific fingerprint.

If two feature declarations produce the same engine feature ID, ledgr
treats that as one feature name in the pulse context. Use distinct IDs
or aliases when you need to compare two different definitions. A
feature-map alias never changes the underlying engine feature ID or
fingerprint; it only gives your strategy a readable name for mapped
access.

<div class="ledgr-callout ledgr-callout-note">

**Definition**

A bundle is an authoring convenience for declaring several indicator
outputs at once. The engine receives ordinary single-output feature
definitions after the bundle is flattened.

</div>

The multi-output bundle helper follows the same lifecycle. It is not a
second feature system.

The same idea works for crossover rules. An SMA crossover registers two
separate indicators: one short moving average and one long moving
average. The economic meaning is “fast trend above slow trend” rather
than “close above one trend line.” Each moving average has its own
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
if (ledgr_passed_warmup(x) && x[["sma_fast"]] > x[["sma_slow"]]) {
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

The wide pulse view is useful for debugging and ML-style
row-per-observation workflows. It contains one OHLCV block and one
feature block for each instrument. OHLCV columns use
`{instrument_id}__ohlcv_{field}`. Feature columns use
`{instrument_id}__feature_{feature_id}`. A feature map filters and
orders feature columns, using aliases as the wide feature keys.

``` r
ledgr_pulse_wide(pulse, features)
#> # A tibble: 1 × 17
#>   ts_utc                cash equity DEMO_01__ohlcv_open DEMO_01__ohlcv_high
#>   <dttm>               <dbl>  <dbl>               <dbl>               <dbl>
#> 1 2019-03-01 00:00:00 100000 100000                103.                107.
#> # ℹ 12 more variables: DEMO_01__ohlcv_low <dbl>, DEMO_01__ohlcv_close <dbl>,
#> #   DEMO_01__ohlcv_volume <dbl>, DEMO_01__feature_ret_5 <dbl>,
#> #   DEMO_01__feature_sma_10 <dbl>, DEMO_02__ohlcv_open <dbl>, DEMO_02__ohlcv_high <dbl>,
#> #   DEMO_02__ohlcv_low <dbl>, DEMO_02__ohlcv_close <dbl>, DEMO_02__ohlcv_volume <dbl>,
#> #   DEMO_02__feature_ret_5 <dbl>, DEMO_02__feature_sma_10 <dbl>
```

`ledgr_pulse_features()` and `ledgr_pulse_wide()` work on interactive
pulse snapshots and on the `ctx` object inside an ordinary strategy
function. They are inspection views over the same pulse-known data used
by `ctx$feature()` and `ctx$features()`.

## Access Features In A Strategy

The long and wide pulse views are useful when you want to inspect the
computed data, compare instruments, or think in model-like rows. They
are not always the clearest shape for strategy code. A strategy often
wants to ask a smaller question: “what are the current values for this
instrument?”

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
ledgr_passed_warmup(x)
#> [1] TRUE
```

<div class="ledgr-callout ledgr-callout-note">

**Definition**

Warmup is the period before a known feature has enough prior bars to
produce a usable value. A warmup `NA` is not an unknown feature; it is a
known feature that is not ready yet.

</div>

<div class="ledgr-callout ledgr-callout-tip">

**Try it**

Change the scalar accessor to `pulse$feature("DEMO_01", "returns_5")`.
Why does that fail while `ids[["ret_5"]]` works?

</div>

Inside a strategy, loop over `ctx$universe` so the rule works for every
instrument in the run.

``` r
strategy <- function(ctx, params) {
  targets <- ctx$flat()

  for (id in ctx$universe) {
    x <- ctx$features(id, features)

    if (
      ledgr_passed_warmup(x) &&
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
- `ledgr_passed_warmup()` is the warmup gate for the mapped feature
  vector.
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
  opening = ledgr_opening(cash = 10000),
  cost_model = ledgr_cost_zero()
)

run_id <- paste0("indicators-demo-", Sys.getpid())

bt <- exp |>
  ledgr_run(params = list(min_return = 0, qty = 10), run_id = run_id)

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
  ret_5 = list(lookback = 5, min_return = 0, qty = 10),
  ret_10 = list(lookback = 10, min_return = 0, qty = 10),
  ret_20 = list(lookback = 20, min_return = 0, qty = 10)
)
```

The feature set must cover the whole grid: `lookback = 20` means
`return_20` must already be registered. A missing feature ID is an
unknown-feature error, not warmup. The alias names in `swept_features`
must also match the lookup key pattern used by the strategy, here
`paste0("ret_", params$lookback)`. In short, all feature parameter
values must be registered before `ledgr_run()`; do not create
`ledgr_ind_returns(params$lookback)` lazily inside the strategy.

For exploratory sweeps over ledgr-owned indicator parameters, prefer
active aliases. Declare the varying constructor arguments with
`ledgr_param()` and compose feature and strategy grids explicitly:

``` r
features <- ledgr_feature_map(
  fast = ledgr_ind_sma(ledgr_param("fast_n")),
  slow = ledgr_ind_sma(ledgr_param("slow_n"))
)

strategy <- ledgr_demo_sma_crossover_strategy()
exp <- ledgr_experiment(snapshot, strategy, features = features, cost_model = ledgr_cost_zero())

grid <- ledgr_grid_cross(
  features = ledgr_feature_grid(
    fast_n = c(10L, 20L),
    slow_n = c(40L, 80L),
    .filter = fast_n < slow_n
  ),
  strategy = ledgr_strategy_grid(threshold = c(0, 0.01), qty = 10)
)

precomputed <- ledgr_precompute_features(exp, grid)
results <- ledgr_sweep(exp, grid, precomputed_features = precomputed)
```

For single-output indicators, the feature-map alias is the
strategy-facing name returned by `ctx$features(id)`. Bundle entries are
intentionally flat; see the TTR bundle section below for how bundle
aliases differ from single-output aliases in mapped access.

For TTR-backed declarations, multi-output bundles, and adapter warmup
rules, read `vignette("ttr-and-adapter-indicators", package = "ledgr")`.

## Troubleshoot Warmup And Zero Trades

Warmup problems are easiest to diagnose by connecting four facts:

1.  `ledgr_feature_contracts(features)` tells you how many bars each
    feature needs before it can produce a usable value.
2.  `ledgr_feature_contract_check(snapshot, features)` joins those
    contracts to the actual per-instrument bar counts in the snapshot.
3.  `ledgr_pulse_features(pulse, features)` shows the current
    pulse-known values for the instruments and aliases you registered.
4.  `summary(bt)` prints `Warmup Diagnostics` when a completed run has
    registered features that can never become usable for an instrument
    because available bars are below the feature contract.

``` r
warmup_check_snapshot <- ledgr_snapshot_from_df(
  bars |>
    filter(!(instrument_id == "DEMO_02" & ts_utc > ledgr_utc("2019-01-25"))),
  snapshot_id = paste0("warmup-check-", Sys.getpid())
)

ledgr_feature_contract_check(warmup_check_snapshot, features)
#> # A tibble: 4 × 8
#>   alias  instrument_id feature_id source requires_bars stable_after available_bars
#>   <chr>  <chr>         <chr>      <chr>          <int>        <int>          <int>
#> 1 ret_5  DEMO_01       return_5   ledgr              6            6            129
#> 2 sma_10 DEMO_01       sma_10     ledgr             10           10            129
#> 3 ret_5  DEMO_02       return_5   ledgr              6            6             19
#> 4 sma_10 DEMO_02       sma_10     ledgr             10           10             19
#> # ℹ 1 more variable: warmup_achievable <lgl>

ledgr_snapshot_close(warmup_check_snapshot)
```

The `warmup_achievable` column is `FALSE` when an instrument does not
have enough available bars to satisfy a feature’s `stable_after`
contract.

Normal early warmup is temporary: a feature is `NA` near the beginning
of an instrument’s sample and later becomes finite. Impossible warmup is
different: the instrument never has enough available bars for that
feature. In that case, zero trades can be a valid completed run plus a
useful diagnostic, not a failed run.

For result-table interpretation after a zero-trade run, read
`vignette("metrics-and-accounting", package = "ledgr")`.

## Where Next

- `vignette("ttr-and-adapter-indicators", package = "ledgr")` covers TTR
  adapters and warmup verification.
- `vignette("custom-indicators", package = "ledgr")` covers
  package-native custom indicator authoring.
- `vignette("strategy-development", package = "ledgr")` uses feature
  values inside complete strategies.
