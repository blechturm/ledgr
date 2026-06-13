# Strategy Authoring Tools


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

After the raw `function(ctx, params) -> target vector` contract is
clear, strategy work usually shifts to repeatability: readable feature
aliases, helper-pipeline objects, one-pulse debugging, and
reproducibility preflight. This companion article focuses on those
authoring tools. For the first-pass strategy contract and leakage
boundary, read `vignette("strategy-development", package = "ledgr")`.

## Prerequisites

The examples use `dplyr` for demo-data preparation. Strategy functions
use ledgr’s pulse context rather than data-frame operations. The article
assumes basic familiarity with sealed snapshots
(`vignette("data-input-and-snapshots", package = "ledgr")`) and feature
IDs (`vignette("indicators", package = "ledgr")`).

``` r
library(ledgr)
library(dplyr)
data("ledgr_demo_bars", package = "ledgr")
```

## Prepare A Small Experiment

Use two instruments from the offline demo data so the examples run
anywhere.

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
  snapshot_id = "strategy_chapter_snapshot"
)
```

The snapshot seals the market data. That is the evidence base for the
experiment. Strategies and indicators can derive from it, but the
underlying bars do not change mid-research.

## Indicators And Feature IDs

Indicators are feature definitions. Before a strategy uses a feature,
ask ledgr for the exact ID.

``` r
features <- list(ledgr_ind_returns(5))

ledgr_feature_id(features)
#> [1] "return_5"
```

Those strings are the names used inside `ctx$feature()`. They are exact.
A typo such as `"returns_5"` is not treated as a warmup value; it is an
unknown feature and ledgr fails loudly.

Warmup is different. A known feature can be `NA` early in the sample
because there are not enough prior bars yet. Strategy code should treat
that as “no signal yet.”

## Debug One Pulse Before Running

Before running a full backtest, inspect one pulse. This is the fastest
way to understand what your strategy will see.

``` r
pulse <- ledgr_pulse_snapshot(
  snapshot,
  universe = c("DEMO_01", "DEMO_02"),
  ts_utc = ledgr_utc("2019-03-01"),
  features = features
)

pulse$ts_utc
#> [1] "2019-03-01T00:00:00Z"
pulse$universe
#> [1] "DEMO_01" "DEMO_02"
pulse$close("DEMO_01")
#> [1] 106.5053
pulse$feature("DEMO_01", "return_5")
#> [1] 0.08531877
pulse$hold()
#> DEMO_01 DEMO_02
#>       0       0
```

The scalar accessors are easiest when you are writing or debugging a
rule for one instrument. Cross-sectional rules should usually switch to
the vector accessors once the contract is clear:

``` r
pulse$idx("DEMO_01")
#> [1] 1
pulse$vec$close
#> [1] 106.50526  68.03192
pulse$vec$feature("return_5")
#> [1] 0.085318770 0.004018771
```

`ctx$idx(id)` gives the instrument’s position in `ctx$universe`. Values
in `ctx$vec$close`, `ctx$vec$positions`, and
`ctx$vec$feature(feature_id)` use that same order, so a strategy can
score the whole universe without repeating scalar lookups. By default,
`ctx$idx(id)` also fails loudly for an unknown instrument; use its
`missing` argument only when a deliberate `NA` path is part of the rule.
The vector feature accessor still uses exact engine feature IDs: warmup
for a known feature is `NA`, while an unknown feature ID fails loudly.

The same pulse can also be viewed as one wide row. This is useful when
you want to see prices, portfolio state, and computed features together.

``` r
ledgr_pulse_wide(pulse) |>
  glimpse()
#> Rows: 1
#> Columns: 15
#> $ ts_utc                    <dttm> 2019-03-01
#> $ cash                      <dbl> 1e+05
#> $ equity                    <dbl> 1e+05
#> $ DEMO_01__ohlcv_open       <dbl> 103.4069
#> $ DEMO_01__ohlcv_high       <dbl> 106.6241
#> $ DEMO_01__ohlcv_low        <dbl> 102.7549
#> $ DEMO_01__ohlcv_close      <dbl> 106.5053
#> $ DEMO_01__ohlcv_volume     <dbl> 545965
#> $ DEMO_01__feature_return_5 <dbl> 0.08531877
#> $ DEMO_02__ohlcv_open       <dbl> 67.38033
#> $ DEMO_02__ohlcv_high       <dbl> 68.56432
#> $ DEMO_02__ohlcv_low        <dbl> 67.03894
#> $ DEMO_02__ohlcv_close      <dbl> 68.03192
#> $ DEMO_02__ohlcv_volume     <dbl> 580351
#> $ DEMO_02__feature_return_5 <dbl> 0.004018771
```

The wide row and the scalar accessors are two ways of looking at the
same pulse-known data. The wide row is good for inspection and
model-like thinking. The rest of this vignette uses the non-wide
accessors because they keep the step-by-step strategy logic easier to
read.

Raw loops are the clearest way to learn the contract. Once that contract
is clear, larger strategies usually read better as a pipeline: score the
universe, select names, assign weights, then convert those weights into
target quantities.

The economic idea:

> Rank instruments by recent return, keep the top names, split capital
> equally, and convert those weights into share quantities.

`ledgr_signal_return()` is a thin helper around the same feature you
inspected above: it reads `return_N` for every instrument in the pulse
and returns one universe-wide signal object. It uses the vector accessor
`ctx$vec$feature(feature_id)` when available, then falls back to the
scalar `ctx$feature(id, feature_id)` path for compatibility.

The helper pipeline has four stages:

| Stage | Input | Output | Question answered |
|----|----|----|----|
| signal | pulse context | numeric scores with origin metadata | What looks attractive? |
| selection | signal | logical inclusion with the same origin | What should be considered? |
| weights | selection | allocation weights with the same origin | How should capital be split? |
| target | weights and context | full-universe share quantities | What should the portfolio hold? |

Execution semantics begin only at the target stage. `signal`,
`selection`, and `weights` are research objects that help author the
strategy; `target` is the ordinary full named target vector shape the
runner validates and executes.

``` r
signal <- ledgr_signal_return(pulse, lookback = 5)
signal
#> <ledgr_signal> [2 assets]
#> origin: return_5
#> non-NA: 2/2
#>     DEMO_01     DEMO_02
#> 0.085318770 0.004018771

selection <- ledgr_select_top_n(signal, n = 1)
selection
#> <ledgr_selection> [2 assets]
#> origin: return_5
#> 1 selected
#> DEMO_01 DEMO_02
#>    TRUE   FALSE

weights <- ledgr_weight_equal(selection)
weights
#> <ledgr_weights> [1 asset]
#> origin: return_5
#> non-NA: 1/1
#> DEMO_01
#>       1

target <- ledgr_target_rebalance(weights, pulse, equity_fraction = 0.1)
target
#> <ledgr_target> [2 assets]
#> origin: return_5
#> non-NA: 2/2
#> DEMO_01 DEMO_02
#>      93       0
```

`ledgr_target_rebalance()` sizes with current pulse equity and current
close prices, using `ctx$vec$close` when available, then floors to whole
shares. For the selected `DEMO_01` pulse above, 10% of equity is
allocated to the one selected instrument:

``` r
raw_qty <- weights[["DEMO_01"]] * 0.1 * pulse$equity / pulse$close("DEMO_01")
c(pre_floor = raw_qty, target_qty = unclass(target)[["DEMO_01"]])
#>  pre_floor target_qty
#>   93.89208   93.00000
```

The general weighted sizing formula is:

``` text
floor(weight * equity_fraction * ctx$equity / ctx$close(instrument_id))
```

For a raw target strategy that does not use weights, the same idea
reduces to:

``` text
floor(equity_fraction * ctx$equity / ctx$close(instrument_id))
```

Both formulas use decision-time close and current pulse equity. Fills
still occur at the configured later fill point, so fill value can drift
from decision-time sizing. Residual allocation after whole-share
flooring remains cash and is reflected in the ledger-backed equity rows.

## Turn The Idea Into A Strategy

The same transformations become an ordinary strategy function.

The full backtest replays every bar, including the earliest warmup
pulses. During those first pulses, `return_5` is `NA` for every
instrument because five prior bars do not exist yet.
`ledgr_select_top_n()` treats that all-missing signal as a classed empty
selection, not as a warning. That object still carries the original
universe and signal origin. `ledgr_weight_equal()` turns it into empty
weights, and `ledgr_target_rebalance()` turns those weights into a flat
full-universe target.

No warning suppression is needed for ordinary early warmup. A
partial-selection warning can still appear when some signal values are
usable but fewer than `n` instruments can be selected. If a run finishes
with zero trades, inspect a late pulse before assuming the empty
selection was only early warmup.

``` r
top_return_strategy <- function(ctx, params) {
  signal <- ledgr_signal_return(ctx, lookback = params$lookback)
  selection <- ledgr_select_top_n(signal, n = params$n)

  weights <- ledgr_weight_equal(selection)
  ledgr_target_rebalance(weights, ctx, equity_fraction = params$equity_fraction)
}
```

Read it economically:

1.  `ledgr_signal_return()` scores each instrument by recent return.
2.  `ledgr_select_top_n()` keeps the highest scores and ignores warmup
    `NA`.
3.  `ledgr_weight_equal()` splits the chosen allocation equally.
4.  `ledgr_target_rebalance()` converts weights into floored full target
    quantities.

No helper registers indicators automatically. The experiment must say
which features exist.

Empty selections flow through the pipeline as objects, so expected
warmup and “no signal today” look the same to your strategy. Diagnostics
still belong at the pulse level: when a strategy produces no fills or no
closed trades, inspect a late pulse and confirm whether the feature
values are usable.

``` r
exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = top_return_strategy,
  features = features,
  opening = ledgr_opening(cash = 10000),
  cost_model = ledgr_cost_zero()
)
```

## Feature Maps For Readable Feature Access

The examples above keep the exact feature ID contract visible:
`ctx$feature(id, feature_id)` reads one registered feature for one
instrument at one pulse. That contract remains the foundation.

For cross-sectional strategies, `ctx$vec$feature(feature_id)` returns
the same feature at the same pulse for every instrument in
`ctx$universe`. Warmup for a known feature remains `NA`; an unknown
feature ID fails loudly. The scalar helper stays the clearest teaching
surface, while the vector helper is the lower-overhead surface for
universe-wide scoring.

When a strategy reads several features per instrument, repeating feature
ID strings can obscure the trading idea. A feature map bundles indicator
objects with strategy-facing aliases. The same object can be registered
with the experiment and used by the strategy for pulse-time lookup.

``` r
mapped_features <- ledgr_feature_map(
  ret_5 = ledgr_ind_returns(5),
  sma_10 = ledgr_ind_sma(10)
)

ledgr_feature_id(mapped_features)
#>      ret_5     sma_10
#> "return_5"   "sma_10"
```

The strategy closes over `mapped_features`. Inside the universe loop,
`ctx$features(id, mapped_features)` returns a named numeric vector keyed
by the aliases. `ledgr_passed_warmup()` is a guard for that vector: for
values returned by `ctx$features()`, it means every requested indicator
is usable at this pulse. It is not a signal pipeline transformation, and
it is not a data-quality diagnostic for arbitrary vectors.

``` r
mapped_return_strategy <- function(ctx, params) {
  targets <- ctx$flat()

  for (id in ctx$universe) {
    x <- ctx$features(id, mapped_features)

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

Read that as one pulse-time decision:

1.  `ctx$features()` reads the mapped feature values for one instrument.
2.  `ledgr_passed_warmup()` keeps the rule inactive until the mapped
    indicators are usable.
3.  The condition states the trading idea.
4.  The strategy still returns an ordinary target vector.

Plain `features = list(...)` remains valid. Use it when exact IDs are
clearest. Use a feature map when aliases make a feature-heavy strategy
easier to read. `ledgr_experiment(features = ...)` accepts indicators,
lists, named lists, and feature maps. The strategy context then uses
either the exact-ID scalar accessor `ctx$feature()`, the exact-ID vector
accessor `ctx$vec$feature()`, or the mapped accessor `ctx$features()`.
When in doubt, prefer the experiment-first workflow.

``` r
mapped_exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = mapped_return_strategy,
  features = mapped_features,
  opening = ledgr_opening(cash = 10000),
  cost_model = ledgr_cost_zero()
)
```

Run it the same way as any other experiment. The strategy still returns
target quantities; the feature map only changes how the strategy reads
features.

``` r
bt_mapped <- mapped_exp |>
  ledgr_run(
    params = list(min_return = 0, qty = 5),
    run_id = "mapped_return"
  )

summary(bt_mapped)
#> ledgr Backtest Summary
#> ======================
#>
#> Performance Metrics:
#>   Total Return:        0.64%
#>   Annualized Return:   1.26%
#>   Max Drawdown:        -0.36%
#>
#> Risk Metrics:
#>   Risk-Free Rate:      0.00% annual
#>   Annualization:       252 periods/year (US equity daily)
#>   Volatility (annual): 0.82%
#>   Sharpe Ratio:        1.523
#>
#> Trade Statistics:
#>   Total Trades:        19
#>   Win Rate:            31.58%
#>   Avg Trade:           $3.69
#>
#> Exposure:
#>   Time in Market:      62.79%
```

Feature-map strategies commonly close over the feature map object. Keep
that construction code with the research record. The experiment store
records the registered feature definitions, but recovered strategy
source may still reference the original alias-map object by name.

## Keep Feature Declaration Outside Strategy

Do not declare or rebuild features inside a strategy:

``` r
strategy <- function(ctx, params) {
  features <- ledgr_feature_map(
    fast = ledgr_ind_sma(params$fast_n),
    slow = ledgr_ind_sma(params$slow_n)
  )
  x <- ctx$features("AAA", features)
  ctx$flat()
}
```

That code puts feature declaration inside the execution loop. Strategy
code should read pulse-known values from the context; experiment code
owns feature declaration. Duplicating a parameterized feature map inside
the strategy creates a drift risk between the experiment’s feature
declaration and the strategy lookup map.

For exploratory sweeps over indicator parameters, use active aliases and
feature grids. The canonical walkthrough is
`vignette("sweeps", package = "ledgr")`.

## Troubleshoot Helper Pipelines

The helper pipeline is only an authoring layer:

<div class="ledgr-diagram ledgr-helper-pipeline">

``` mermaid

flowchart LR
  signal["ledgr_signal"]
  selection["ledgr_selection"]
  weights["ledgr_weights"]
  target_obj["ledgr_target"]
  target_vec["target vector"]

  signal --> selection --> weights --> target_obj --> target_vec
```

</div>

Only the final target vector is executable. A strategy must return a
full named numeric target vector, or a `ledgr_target` that unwraps to
that shape. Returning a `ledgr_signal`, `ledgr_selection`,
`ledgr_weights`, unnamed numeric vector, data frame, list, or partial
target is an invalid strategy result.

Common failures usually mean one of four things:

| Symptom | Likely cause | First check |
|----|----|----|
| unknown feature ID | the indicator was not registered with the experiment | `ledgr_feature_id(features)` |
| missing target names | the strategy did not return every `ctx$universe` instrument | compare `names(target)` to `ctx$universe` |
| non-numeric or unsupported return shape | the strategy returned a helper intermediate or object-like result | make the last line a target vector |
| zero fills or zero trades | warmup, empty selection, sizing to zero, no exit, or last-bar no-fill | inspect a late pulse and the fills table |

For helper strategies, debug one pulse before rerunning the whole
experiment:

``` r
pulse <- ledgr_pulse_snapshot(
  snapshot,
  universe = c("DEMO_01", "DEMO_02"),
  ts_utc = ledgr_utc("2019-03-01"),
  features = features
)

signal <- ledgr_signal_return(pulse, lookback = 5)
selection <- ledgr_select_top_n(signal, n = 1)
weights <- ledgr_weight_equal(selection)
target <- ledgr_target_rebalance(weights, pulse, equity_fraction = 0.1)

signal
#> <ledgr_signal> [2 assets]
#> origin: return_5
#> non-NA: 2/2
#>     DEMO_01     DEMO_02
#> 0.085318770 0.004018771
selection
#> <ledgr_selection> [2 assets]
#> origin: return_5
#> 1 selected
#> DEMO_01 DEMO_02
#>    TRUE   FALSE
weights
#> <ledgr_weights> [1 asset]
#> origin: return_5
#> non-NA: 1/1
#> DEMO_01
#>       1
target
#> <ledgr_target> [2 assets]
#> origin: return_5
#> non-NA: 2/2
#> DEMO_01 DEMO_02
#>      93       0
names(target)
#> [1] "DEMO_01" "DEMO_02"
pulse$universe
#> [1] "DEMO_01" "DEMO_02"
setdiff(pulse$universe, names(target))
#> character(0)
setdiff(names(target), pulse$universe)
#> character(0)
```

If `selection` inherits from `ledgr_empty_selection`, every signal value
was missing or unusable at that pulse. Early in a run this is usually
ordinary warmup. Late in a run it points to sample length, feature
registration, or universe coverage. If `target` is full-universe but
every quantity is zero, check integer flooring, `equity_fraction`,
current close prices, and whether an empty selection flowed through
intentionally.

If `setdiff(pulse$universe, names(target))` is non-empty, the strategy
would fail target validation because it did not name every instrument.
If `setdiff(names(target), pulse$universe)` is non-empty, it emitted
targets for unknown instruments.

## Preflight Catches Non-Reproducible Strategy Code

Strategy functions are preflighted before execution. Keep strategy logic
self-contained, put research variation in `params`, and avoid hidden
session state such as unresolved helper functions or mutable globals.

`ledgr_signal_strategy()` is a separate compatibility wrapper for
tutorial-style signal functions. It explicitly maps an inner signal
function to target quantities. For the full tier model, read
`vignette("reproducibility", package = "ledgr")`.

<div class="ledgr-callout ledgr-callout-note">

**Definition**

A preflight tier is ledgr’s static reproducibility classification for a
strategy function. Tier 1 is self-contained, Tier 2 is inspectable with
user-managed environment parity, and Tier 3 is rejected before
execution.

</div>

A compact Tier 3 hard-failure example is an unresolved helper reference:

``` r
tier3_strategy <- function(ctx, params) {
  outside_helper(ctx)
}

preflight <- ledgr_strategy_preflight(tier3_strategy)
preflight$tier
#> [1] "tier_3"
preflight$reason
#> [1] "Strategy references unresolved symbol(s): outside_helper."
```

`ledgr_run()` and `ledgr_sweep()` reject Tier 3 strategies before
execution. There is no force override on those public execution paths.
\## Stored Source

ledgr stores strategy provenance with committed runs. For source
inspection, hash verification, and trust boundaries, read
`vignette("reproducibility", package = "ledgr")`.

## Cleanup

``` r
close(bt_mapped)
close(pulse)
ledgr_snapshot_close(snapshot)
```

## Where Next

- `vignette("strategy-development", package = "ledgr")` is the shorter
  first-pass strategy tutorial.
- `vignette("ttr-and-adapter-indicators", package = "ledgr")` covers
  adapter-backed indicator declarations.
- `vignette("walk-forward", package = "ledgr")` shows how strategies and
  sweeps feed the walk-forward workflow.
- `?ledgr_feature_map` and `?ledgr_passed_warmup` are the function-level
  references for mapped feature access and warmup filtering.
