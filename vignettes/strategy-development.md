Strategy Development And Comparison
================

The examples use `dplyr` for demo-data preparation. Strategy functions
use ledgr’s pulse context rather than data-frame operations.

``` r
library(ledgr)
library(dplyr)
data("ledgr_demo_bars", package = "ledgr")
```

A ledgr strategy is an ordinary R function, but the important idea is
not the function syntax. The important idea is the pulse.

A backtest in ledgr is a sequence of decision moments. At each pulse,
ledgr shows the strategy only what could have been known at that time.
The strategy answers with desired holdings. ledgr records the decision,
applies the fill model, and moves to the next pulse.

This matters because leakage is easy. If future information enters a
historical decision, the backtest can look profitable for the wrong
reason. ledgr’s strategy interface is built to make one common mistake
harder: your strategy receives one pulse context, not the whole future.
For the broader leakage model, including feature-construction leakage
and remaining user responsibilities, see
`vignette("leakage", package = "ledgr")`.

## Wrong And Right: Leakage

The tempting vectorized pattern is to compute a future-looking column
first and then trade from it. In the example below, `lead(close)` shifts
tomorrow’s close onto today’s row. The resulting `buy_signal` looks like
an ordinary column, but it answers a question the strategy could not
have answered at today’s decision time: “will tomorrow’s close be higher
than today’s close?” Trading from that column lets the backtest use
future market data as if it were already known.

``` r
leaky_signals <- ledgr_demo_bars |>
  group_by(instrument_id) |>
  arrange(ts_utc, .by_group = TRUE) |>
  mutate(
    tomorrow_close = lead(close),
    buy_signal = tomorrow_close > close
  )
```

The ledgr version expresses the rule at one pulse. The strategy can read
the current bar for the current instrument. Later sections add
registered features to the same pulse model. The strategy has no
market-data table from which it can casually index tomorrow’s bar. That
is the same information shape a live trading strategy gets as time
passes: each pulse is a new slice of the knowable universe.

``` r
no_leak_bar_strategy <- function(ctx, params) {
  targets <- ctx$flat()

  for (id in ctx$universe) {
    if (ctx$close(id) > ctx$open(id)) {
      targets[id] <- 1
    }
  }

  targets
}
```

This removes one common source of leakage, but it does not certify that
snapshots, feature definitions, event timestamps, universe construction,
or parameter selection are causally clean.

## A Strategy That Does Nothing

The simplest economic policy is: hold cash and own no instruments.

``` r
flat_strategy <- function(ctx, params) {
  ctx$flat()
}
```

`ctx$flat()` creates a full target vector with one entry for every
instrument in the run and every value set to zero. Economically, this
means: after the next fill opportunity, hold no positions.

This is a complete ledgr strategy. It is not useful for making money,
but it is useful for understanding the contract: at every pulse, return
target holdings.

The return value is a named numeric vector. Names are instrument IDs
from `ctx$universe`, values are desired quantities. `ctx$flat()`
produces the full-universe shape with every entry at zero.

The deeper mental model is that a strategy is a **policy**, not a
sequence of orders. At each pulse, the strategy declares a desired
state: “I want to hold this many shares of each instrument.” The engine
compares that against current holdings, computes the gap, and fills
accordingly. The strategy never says “buy 3 shares”; it says “I want to
hold 3 shares.” This distinction is what keeps strategies free from
execution-state bookkeeping, and it is what makes a ledgr strategy
composable, testable, and directly readable as financial reasoning.

## What Is `ctx`?

`ctx` is the pulse context. It is the information packet ledgr gives
your strategy at one decision time.

It contains the current timestamp, current bars, current features,
current positions, cash, equity, and small helper functions for
accessing those values. It is deliberately not the full dataset.

| Expression | Meaning at one pulse |
|----|----|
| `ctx$ts_utc` | current decision timestamp |
| `ctx$universe` | instruments in the run |
| `ctx$open(id)`, `ctx$close(id)` | current bar values for one instrument |
| `ctx$feature(id, feature_id)` | current indicator value for one instrument by engine feature ID |
| `ctx$features(id, feature_map)` | mapped indicator values for one instrument by alias |
| `ctx$position(id)` | current simulated position |
| `ctx$cash`, `ctx$equity` | current simulated portfolio state |
| `ctx$flat()` | target zero positions unless changed |
| `ctx$hold()` | target current positions unless changed |

For the installed accessor reference, see `?ledgr_strategy_context`.

Use `ctx$flat()` when the strategy should be flat unless it sees a
reason to act. Use `ctx$hold()` when the strategy should keep existing
positions unless it sees a reason to change them.

For example, this policy starts from current holdings and only changes
the book when it sees an exit reason. Economically, it means: “keep what
I already own, unless today’s bar gives me a reason to leave.”

``` r
hold_unless_down <- function(ctx, params) {
  targets <- ctx$hold()

  for (id in ctx$universe) {
    if (ctx$close(id) < ctx$open(id)) {
      targets[id] <- 0
    }
  }

  targets
}
```

This loop style is fine while the mechanics are still visible. Once you
have helpers like `signal_*()` and `select_*()`, most strategy logic is
easier to express at the whole-universe level instead of one instrument
at a time.

## A First Trading Rule

Now add one small economic idea:

> If an instrument closes above its open, own one share. Otherwise own
> nothing.

This is still a teaching strategy, not investment advice. It shows how
observable data becomes a target.

``` r
buy_if_up <- function(ctx, params) {
  targets <- ctx$flat()

  for (id in ctx$universe) {
    if (ctx$close(id) > ctx$open(id)) {
      targets[id] <- 1
    }
  }

  targets
}
```

Targets are desired quantities, not orders, signals, or portfolio
weights. A target of `1` means “after the next fill opportunity, hold
one share.” A target of `0` means “hold no shares.”

In these examples, decisions fill at the next open: a decision made at
pulse `t` fills at the next available bar. That keeps the strategy from
deciding and filling on the same close.

The loop is intentionally plain because this is the first example. Once
the economic idea is clear, ledgr strategies are usually easier to read
when they use helper functions that operate on the whole universe at
once. The later sections make that transition.

## Why `params` Exists

Hard-coded constants make experiments awkward. Parameters let one
economic idea run under different assumptions.

``` r
buy_if_up_qty <- function(ctx, params) {
  targets <- ctx$flat()

  for (id in ctx$universe) {
    if (ctx$close(id) > ctx$open(id)) {
      targets[id] <- params$qty
    }
  }

  targets
}
```

Strategies use `function(ctx, params)`. `ctx` is the pulse. `params` is
the experimenter’s chosen configuration for this run. Keeping them
separate makes the strategy easier to test, compare, and store.

## Prepare A Small Experiment

Use two instruments from the offline demo data so the examples run
anywhere.

``` r
bars <- ledgr_demo_bars |>
  filter(
    instrument_id %in% c("DEMO_01", "DEMO_02"),
    between(
      ts_utc,
      ledgr::ledgr_utc("2019-01-01"),
      ledgr::ledgr_utc("2019-06-30")
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
  ts_utc = ledgr::ledgr_utc("2019-03-01"),
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

Now build the strategy logic one transformation at a time.

The economic idea:

> Rank instruments by recent return, keep the top names, split capital
> equally, and convert those weights into share quantities.

`signal_return()` is a thin helper around the same feature you inspected
above: it reads `return_N` for every instrument in the pulse and returns
one universe-wide signal object.

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
signal <- signal_return(pulse, lookback = 5)
signal
#> <ledgr_signal> [2 assets]
#> origin: return_5
#> non-NA: 2/2
#>     DEMO_01     DEMO_02
#> 0.085318770 0.004018771

selection <- select_top_n(signal, n = 1)
selection
#> <ledgr_selection> [2 assets]
#> origin: return_5
#> 1 selected
#> DEMO_01 DEMO_02
#>    TRUE   FALSE

weights <- weight_equal(selection)
weights
#> <ledgr_weights> [1 asset]
#> origin: return_5
#> non-NA: 1/1
#> DEMO_01
#>       1

target <- target_rebalance(weights, pulse, equity_fraction = 0.1)
target
#> <ledgr_target> [2 assets]
#> origin: return_5
#> non-NA: 2/2
#> DEMO_01 DEMO_02
#>      93       0
```

`target_rebalance()` sizes with current pulse equity and current close
prices, then floors to whole shares. For the selected `DEMO_01` pulse
above, 10% of equity is allocated to the one selected instrument:

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
from decision-time sizing.

The helper objects are not a second execution path. They are authoring
aids. The pipeline still ends in a `ledgr_target`, which unwraps to the
same target quantity vector the runner has always consumed.

Interactive pulse snapshots and backtest handles can be closed when you
are done inspecting them. This releases DuckDB resources in long
sessions; completed run artifacts are already durable when `ledgr_run()`
returns.

``` r
close(pulse)
```

## Turn The Idea Into A Strategy

The same transformations become an ordinary strategy function.

The full backtest replays every bar, including the earliest warmup
pulses. During those first pulses, `return_5` is `NA` for every
instrument because five prior bars do not exist yet. `select_top_n()`
treats that all-missing signal as a classed empty selection, not as a
warning. That object still carries the original universe and signal
origin. `weight_equal()` turns it into empty weights, and
`target_rebalance()` turns those weights into a flat full-universe
target.

No warning suppression is needed for ordinary early warmup. A
partial-selection warning can still appear when some signal values are
usable but fewer than `n` instruments can be selected. If a run finishes
with zero trades, inspect a late pulse before assuming the empty
selection was only early warmup.

``` r
top_return_strategy <- function(ctx, params) {
  signal <- signal_return(ctx, lookback = params$lookback)
  selection <- select_top_n(signal, n = params$n)

  weights <- weight_equal(selection)
  target_rebalance(weights, ctx, equity_fraction = params$equity_fraction)
}
```

Read it economically:

1.  `signal_return()` scores each instrument by recent return.
2.  `select_top_n()` keeps the highest scores and ignores warmup `NA`.
3.  `weight_equal()` splits the chosen allocation equally.
4.  `target_rebalance()` converts weights into floored full target
    quantities.

No helper registers indicators automatically. The experiment must say
which features exist.

The empty-selection path is intentionally an object path rather than a
condition path. It lets expected warmup and “no signal today” flow
through the same helper pipeline as an ordinary selection. Diagnostics
still belong at the pulse level: when a strategy produces no fills or no
closed trades, inspect a late pulse and confirm whether the feature
values are usable.

``` r
exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = top_return_strategy,
  features = features,
  opening = ledgr_opening(cash = 10000)
)
```

## Feature Maps For Readable Feature Access

The examples above keep the exact feature ID contract visible:
`ctx$feature(id, feature_id)` reads one registered feature for one
instrument at one pulse. That contract remains the foundation.

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
by the aliases. `passed_warmup()` is a guard for that vector: for values
returned by `ctx$features()`, it means every requested indicator is
usable at this pulse. It is not a signal pipeline transformation, and it
is not a data-quality diagnostic for arbitrary vectors. A zero-length
input is a classed error because an empty feature bundle cannot prove
warmup has passed. The specific error classes are
`ledgr_empty_warmup_input` and `ledgr_invalid_warmup_input`.

``` r
mapped_return_strategy <- function(ctx, params) {
  targets <- ctx$flat()

  for (id in ctx$universe) {
    x <- ctx$features(id, mapped_features)

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

Read that as one pulse-time decision:

1.  `ctx$features()` reads the mapped feature values for one instrument.
2.  `passed_warmup()` keeps the rule inactive until the mapped
    indicators are usable.
3.  The condition states the trading idea.
4.  The strategy still returns an ordinary target vector.

Plain `features = list(...)` remains valid. Use it when exact IDs are
clearest. Use a feature map when aliases make a feature-heavy strategy
easier to read. The modern `ledgr_experiment(features = ...)` path
accepts indicators, lists, named lists, feature maps, and feature
factories. The strategy context then uses either the exact-ID scalar
accessor `ctx$feature()` or the mapped accessor `ctx$features()`.
Lower-level and legacy helpers may be narrower; when in doubt, prefer
the experiment-first workflow.

``` r
mapped_exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = mapped_return_strategy,
  features = mapped_features,
  opening = ledgr_opening(cash = 10000)
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
#> Warning: LEDGR_LAST_BAR_NO_FILL: target changed on the final available bar, but the
#> next-open fill model requires a following bar. No fill was emitted for this target
#> change. Check the strategy's final-pulse behavior or extend the snapshot if this trade
#> should be fillable.

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

Feature-map strategies commonly close over the feature map object. That
is the single-definition pattern: one object defines aliases, registers
indicators, and drives pulse-time lookup.

This has a provenance consequence. Tier 2 is common for strategy
functions that call package helpers or depend on external symbols; the
helper-pipeline strategy below is also tier 2. Feature maps add a more
specific concern: the recovered strategy source may reference
`mapped_features`, but the alias map object itself is not recovered as a
standalone object from strategy provenance. The experiment store records
the registered feature definitions, while the human-readable alias
construction remains part of your research code. Keep the feature-map
construction code with the research record when you need to rerun the
strategy later.

## Sweeping Indicator Parameters

When a sweep changes an indicator parameter, ledgr materializes a
concrete feature set for each candidate before execution. Current
strategy code has two safe bridge patterns.

For built-in indicators, exact-ID lookup from `params` is the clearest
Tier 1 pattern:

``` r
strategy <- function(ctx, params) {
  fast_id <- ledgr_feature_id(ledgr_ind_sma(params$fast_n))
  slow_id <- ledgr_feature_id(ledgr_ind_sma(params$slow_n))

  fast <- ctx$feature("AAA", fast_id)
  slow <- ctx$feature("AAA", slow_id)

  targets <- ctx$flat()
  if (!is.na(fast) && !is.na(slow) && fast > slow) {
    targets["AAA"] <- params$qty
  }
  targets
}
```

That keeps the strategy self-contained: it uses `ctx`, `params`, and
exported ledgr helpers. Hand-built strings such as
`paste0("sma_", params$fast_n)` also work for built-ins whose ID
convention is public, but `ledgr_feature_id()` keeps the lookup tied to
the constructor.

Static feature maps remain the recommended shape when aliases do not
vary by candidate:

``` r
features <- ledgr_feature_map(
  fast = ledgr_ind_sma(20),
  slow = ledgr_ind_sma(50)
)

strategy <- function(ctx, params) {
  x <- ctx$features("AAA", features)
  ctx$flat()
}
```

Do not call an external feature factory from inside a strategy:

``` r
features <- function(params) {
  ledgr_feature_map(
    fast = ledgr_ind_sma(params$fast_n),
    slow = ledgr_ind_sma(params$slow_n)
  )
}

strategy <- function(ctx, params) {
  x <- ctx$features("AAA", features(params))
  ctx$flat()
}
```

That code reads well, but `features` is a user helper function
referenced from the strategy body. Under the current preflight contract,
external feature factory functions inside strategies are Tier 3 and
`ledgr_run()` rejects them before execution. Duplicating the
parameterized feature map inside the strategy is mechanically valid, but
it creates a drift risk between the experiment’s feature declaration and
the strategy lookup map.

The long-term UX gap is tracked in the active parameterized feature
aliases RFC. Until that API exists, use exact feature IDs for
parameterized sweeps and use feature-map aliases for static maps.

## Run One Backtest

``` r
bt_top_1 <- exp |>
  ledgr_run(
    params = list(lookback = 5, n = 1, equity_fraction = 0.1),
    run_id = "top_return_1"
  )

summary(bt_top_1)
#> ledgr Backtest Summary
#> ======================
#>
#> Performance Metrics:
#>   Total Return:        0.45%
#>   Annualized Return:   0.89%
#>   Max Drawdown:        -1.12%
#>
#> Risk Metrics:
#>   Risk-Free Rate:      0.00% annual
#>   Annualization:       252 periods/year (US equity daily)
#>   Volatility (annual): 2.02%
#>   Sharpe Ratio:        0.450
#>
#> Trade Statistics:
#>   Total Trades:        24
#>   Win Rate:            45.83%
#>   Avg Trade:           $2.15
#>
#> Exposure:
#>   Time in Market:      95.35%
```

The summary is portfolio-level: total return, max drawdown, and trade
count are computed from the completed run. In ledgr, trades are closed
round trips; the fills table can contain more rows because opening fills
and closing fills are both recorded.

The annualized volatility is high because this toy strategy switches
positions often on a tiny two-instrument demo universe. Treat it as a
warning about the example, not as a property you should expect from the
same idea on real data. The drawdown is disproportionate to the final
loss for the same reason: a small, concentrated portfolio can swing hard
during the run even if it ends roughly flat.

Do not expect a teaching strategy to be good. A weak or unattractive
result is still useful evidence: ledgr records failed ideas with the
same care as successful ones, which is part of not fooling yourself.

Inspecting trades shows the actions produced by the target decisions.

``` r
ledgr_results(bt_top_1, what = "trades")
#> # A tibble: 24 x 9
#>    event_seq ts_utc     instrument_id side    qty price   fee realized_pnl action
#>        <int> <date>     <chr>         <chr> <dbl> <dbl> <dbl>        <dbl> <chr>
#>  1         3 2019-01-14 DEMO_02       SELL     13  72.8     0       -22.5  CLOSE
#>  2         4 2019-01-18 DEMO_01       SELL     11  86.2     0       -19.0  CLOSE
#>  3         7 2019-01-21 DEMO_02       SELL     13  70.2     0       -31.5  CLOSE
#>  4         8 2019-01-25 DEMO_01       SELL      1  90.7     0         3.37 CLOSE
#>  5         9 2019-02-08 DEMO_01       SELL     10  92.6     0        52.8  CLOSE
#>  6        13 2019-02-13 DEMO_02       SELL     15  66.2     0       -14.0  CLOSE
#>  7        14 2019-02-20 DEMO_01       SELL     10  96.9     0        30.4  CLOSE
#>  8        17 2019-02-25 DEMO_02       SELL     14  67.5     0       -24.5  CLOSE
#>  9        18 2019-02-27 DEMO_01       SELL      1 100.      0         2.52 CLOSE
#> 10        19 2019-03-11 DEMO_01       SELL      9 106.      0        77.7  CLOSE
#> # i 14 more rows
```

The trade table only includes closed round trips. Small one-share rows
appear when integer sizing and price movement leave a tiny adjustment
after a previous target. Larger rows are the ordinary position exits.
`realized_pnl` is the profit or loss booked when that position closes.

If a run has zero trades, inspect fills before assuming nothing
happened:

``` r
ledgr_results(bt_top_1, what = "fills")
#> # A tibble: 50 x 9
#>    event_seq ts_utc     instrument_id side    qty price   fee realized_pnl action
#>        <int> <date>     <chr>         <chr> <dbl> <dbl> <dbl>        <dbl> <chr>
#>  1         1 2019-01-09 DEMO_02       BUY      13  74.6     0         0    OPEN
#>  2         2 2019-01-14 DEMO_01       BUY      11  87.9     0         0    OPEN
#>  3         3 2019-01-14 DEMO_02       SELL     13  72.8     0       -22.5  CLOSE
#>  4         4 2019-01-18 DEMO_01       SELL     11  86.2     0       -19.0  CLOSE
#>  5         5 2019-01-18 DEMO_02       BUY      13  72.6     0         0    OPEN
#>  6         6 2019-01-21 DEMO_01       BUY      11  87.4     0         0    OPEN
#>  7         7 2019-01-21 DEMO_02       SELL     13  70.2     0       -31.5  CLOSE
#>  8         8 2019-01-25 DEMO_01       SELL      1  90.7     0         3.37 CLOSE
#>  9         9 2019-02-08 DEMO_01       SELL     10  92.6     0        52.8  CLOSE
#> 10        10 2019-02-08 DEMO_02       BUY      14  67.2     0         0    OPEN
#> # i 40 more rows
```

Zero fills means no execution occurred. Non-empty fills with zero trades
means positions opened but did not close. `n_trades` counts closed round
trips, while the fills table shows both opening and closing execution
rows.

## Compare Parameter Variants

Now keep the economic idea fixed and change one assumption: hold the top
two instruments instead of the top one.

``` r
bt_top_2 <- exp |>
  ledgr_run(
    params = list(lookback = 5, n = 2, equity_fraction = 0.1),
    run_id = "top_return_2"
  )

ledgr_compare_runs(snapshot, run_ids = c("top_return_1", "top_return_2"))
#> # ledgr comparison
#> # A tibble: 2 x 9
#>   run_id       label final_equity total_return sharpe_ratio max_drawdown n_trades win_rate
#>   <chr>        <chr>        <dbl> <chr>               <dbl> <chr>           <int> <chr>
#> 1 top_return_1 <NA>        10045. +0.5%              0.450  -1.1%              24 45.8%
#> 2 top_return_2 <NA>        10004. +0.0%              0.0661 -1.1%               7 57.1%
#> # i 1 more variable: reproducibility_level <chr>
#>
#> # i Full identity and telemetry columns remain available on this tibble.
#> # i Inspect one run with ledgr_run_info(snapshot, run_id).
```

Comparison is most useful when the compared runs differ for a reason you
can explain. Here the reason is simple: one run concentrates the
allocation in the single strongest recent-return instrument, and the
other splits it across two.

The comparison table is not asking “which number is biggest?” in
isolation. It is asking whether the change in assumption improved the
run in ways you can defend: return, drawdown, number of closed trades,
and win rate all matter.

These runs share the same sealed data, initial cash, feature set, and
cost assumptions. That keeps the teaching example narrow. A real
comparison would also ask whether the conclusion survives different
samples, execution costs, starting capital, and parameter choices.

## Compare Against A Baseline

The flat strategy is a sanity baseline, not a market benchmark. It tells
you what the result table looks like when the strategy deliberately does
nothing, and it keeps the comparison honest: if an active strategy
cannot beat doing nothing on the same sealed data, that is valuable
information.

``` r
flat_exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = flat_strategy,
  opening = ledgr_opening(cash = 10000)
)

bt_flat <- flat_exp |>
  ledgr_run(params = list(), run_id = "flat_baseline")

ledgr_compare_runs(snapshot, run_ids = c("top_return_1", "top_return_2", "flat_baseline"))
#> # ledgr comparison
#> # A tibble: 3 x 9
#>   run_id       label final_equity total_return sharpe_ratio max_drawdown n_trades win_rate
#>   <chr>        <chr>        <dbl> <chr>               <dbl> <chr>           <int> <chr>
#> 1 top_return_1 <NA>        10045. +0.5%              0.450  -1.1%              24 45.8%
#> 2 top_return_2 <NA>        10004. +0.0%              0.0661 -1.1%               7 57.1%
#> 3 flat_baseli~ <NA>        10000  +0.0%             NA      0.0%                0 <NA>
#> # i 1 more variable: reproducibility_level <chr>
#>
#> # i Full identity and telemetry columns remain available on this tibble.
#> # i Inspect one run with ledgr_run_info(snapshot, run_id).
```

The flat baseline has no win rate because it has no closed trades. That
is not missing data; there are no wins or losses to count.

For real Yahoo snapshots, keep benchmark strategies explicit rather than
adding a hidden benchmark helper. These simple patterns are ordinary
ledgr strategies:

``` r
flat_strategy <- function(ctx, params) {
  ctx$flat()
}

buy_and_hold_strategy <- function(ctx, params) {
  targets <- ctx$hold()
  targets[params$instrument_id] <- params$qty
  targets
}

equal_weight_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  capital <- ctx$equity * params$equity_fraction / length(ctx$universe)
  for (id in ctx$universe) {
    targets[id] <- floor(capital / ctx$close(id))
  }
  targets
}

single_instrument_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  targets[params$instrument_id] <- params$qty
  targets
}
```

Use these as comparison baselines for a sealed real-data snapshot; they
are not benchmark APIs and they do not download benchmark returns.

## Troubleshoot Helper Pipelines

The helper pipeline is only an authoring layer:

``` text
ledgr_signal -> ledgr_selection -> ledgr_weights -> ledgr_target -> target vector
```

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

signal <- signal_return(pulse, lookback = 5)
selection <- select_top_n(signal, n = 1)
weights <- weight_equal(selection)
target <- target_rebalance(weights, pulse, equity_fraction = 0.1)

signal
selection
weights
target
names(target)
pulse$universe
setdiff(pulse$universe, names(target))
setdiff(names(target), pulse$universe)
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

Reusable file-level helper functions are Tier 3 unless the function can
be represented as part of the strategy artifact. Inline small allocation
logic or wrap it in an approved helper surface:

``` r
allocate_equal <- function(ctx, fraction) {
  targets <- ctx$flat()
  capital <- ctx$equity * fraction / length(ctx$universe)
  for (id in ctx$universe) targets[id] <- floor(capital / ctx$close(id))
  targets
}

bad_strategy <- function(ctx, params) {
  allocate_equal(ctx, params$equity_fraction)
}

ledgr_strategy_preflight(bad_strategy)

self_contained_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  capital <- ctx$equity * params$equity_fraction / length(ctx$universe)
  for (id in ctx$universe) targets[id] <- floor(capital / ctx$close(id))
  targets
}
```

`ledgr_signal_strategy()` is a separate explicit compatibility wrapper
for tutorial-style signal functions. It maps an inner signal function to
full target quantities using configured long/flat/short quantities. Use
it when that mapping is really the strategy contract; otherwise prefer
returning the full target vector directly. Strategy preflight reports
this wrapper as a special allowed case because it captures an inner
function and quantity settings. Tier 3 preflight failures remain hard
failures: they are not downgraded to warnings or silently accepted.
Wall-clock calls such as `Sys.time()` and global assignment with `<<-`
are Tier 3 because ledgr cannot make them reproducible execution inputs.
Resolved scalar values from the strategy closure are allowed as Tier 2,
but values that define the research question should usually live in
`params`.

A compact Tier 3 hard-failure example is an unresolved helper reference:

``` r
outside_helper <- function(ctx) ctx$flat()

tier3_strategy <- function(ctx, params) {
  outside_helper(ctx)
}

preflight <- ledgr_strategy_preflight(tier3_strategy)
preflight$tier
preflight$reason

ledgr_run(exp, params = list(), run_id = "tier3_demo")
```

`ledgr_run()` and `ledgr_sweep()` reject Tier 3 strategies before
execution. There is no force override on those public execution paths.

## When ledgr Complains

ledgr tries to fail loudly when an error would make a backtest
misleading. If a strategy returns a vector with the wrong names or
length, ledgr rejects it instead of silently treating missing
instruments as zero. If a helper reads an unregistered feature,
`ctx$feature()` reports the unknown feature ID and lists the available
IDs. If `target_rebalance()` receives negative or over-allocated
weights, it fails before turning them into target quantities.

Those errors are part of the design. They are meant to catch research
mistakes while the mistake is still small enough to understand.

## Inspect Stored Source

The experiment store lets you come back later and know exactly what code
and parameters produced a result. When you return to a six-month-old
run, this is the artifact that tells you what was actually tested, not
what you remember testing.

ledgr stores strategy provenance with the run. Inspection is read-only
by default: `trust = FALSE` returns stored text and metadata without
parsing or evaluating it.

Hash verification proves stored-text identity, not safety. That is why
the read-only path is the default.

You usually do not read the hashes yourself. They are the durable
fingerprints ledgr uses to verify that recovered source and parameters
are identical to the artifacts that produced the run.

``` r
ledgr_extract_strategy(snapshot, "top_return_1", trust = FALSE)
#> ledgr Extracted Strategy
#> ========================
#>
#> Run ID:          top_return_1
#> Reproducibility: tier_1
#> Source Hash:     a724d2475b8e5f75c6d1d0ba5c1b99e0f33cb1d88f2d93ed261a2772276cc29d
#> Params Hash:     3caea9cbe019dbfa16b53b9bbeee913bdb2f16e4c6f196e0f5a3c8332cac270c
#> Hash Verified:   TRUE
#> Trust:           FALSE
#> Source Available:TRUE
```

Use `trust = TRUE` only when you explicitly trust the experiment store
and want to recover a function object.

## Cleanup

These calls release DuckDB connections. Forgetting them in a short
interactive session is not a data-safety issue; completed run artifacts
are already durable when `ledgr_run()` returns. In long sessions and
scripts, releasing resources explicitly avoids lock and resource
warnings.

``` r
close(bt_top_1)
close(bt_top_2)
close(bt_flat)
close(bt_mapped)
ledgr_snapshot_close(snapshot)
```

## What’s Next?

If you want the formal contract, read the strategy and context sections
in `inst/design/contracts.md`. If you want the indicator story, read
`vignette("indicators", package = "ledgr")`. For formal feature-map
help, see `?ledgr_strategy_context`, `?ledgr_feature_map`, and
`?passed_warmup`. If you want the deployment story, continue with
`vignette("research-to-production", package = "ledgr")`. If you want to
inspect or compare durable runs, read
`vignette("experiment-store", package = "ledgr")`.
