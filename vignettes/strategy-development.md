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

This matters because leakage is easy. If a strategy accidentally sees
tomorrow’s price while deciding today’s trade, the backtest can look
profitable for the wrong reason. ledgr’s strategy interface is built to
make that mistake harder: your strategy receives one pulse context, not
the whole future.

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
| `ctx$feature(id, name)` | current indicator value for one instrument |
| `ctx$position(id)` | current simulated position |
| `ctx$cash`, `ctx$equity` | current simulated portfolio state |
| `ctx$flat()` | target zero positions unless changed |
| `ctx$hold()` | target current positions unless changed |

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
    between(ts_utc, ledgr_utc("2019-01-01"), ledgr_utc("2019-06-30"))
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
| signal | pulse context | numeric scores | What looks attractive? |
| selection | signal | logical inclusion | What should be considered? |
| weights | selection | allocation weights | How should capital be split? |
| target | weights and context | share quantities | What should the portfolio hold? |

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
warns when a signal has no usable values; that warning is useful during
pulse debugging, but expected during a full run. The strategy suppresses
that specific warmup noise while still returning an empty selection,
empty weights, and a flat target.

The warning exists because an empty selection can mean either “normal
warmup” or “my signal is broken.” The helper cannot know which one is
true, so it warns and lets the strategy decide how to handle that case.

``` r
top_return_strategy <- function(ctx, params) {
  signal <- signal_return(ctx, lookback = params$lookback)
  selection <- suppressWarnings(select_top_n(signal, n = params$n))

  weights <- weight_equal(selection)
  target_rebalance(weights, ctx, equity_fraction = params$equity_fraction)
}
```

Read it economically:

1.  `signal_return()` scores each instrument by recent return.
2.  `select_top_n()` keeps the highest scores and ignores warmup `NA`.
3.  `weight_equal()` splits the chosen allocation equally.
4.  `target_rebalance()` converts weights into full target quantities.

No helper registers indicators automatically. The experiment must say
which features exist.

``` r
exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = top_return_strategy,
  features = features,
  opening = ledgr_opening(cash = 10000)
)
```

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
#>   Total Return:        -0.41%
#>   Annualized Return:   -0.81%
#>   Max Drawdown:        -18.26%
#>
#> Risk Metrics:
#>   Volatility (annual): 93.23%
#>
#> Trade Statistics:
#>   Total Trades:        24
#>   Win Rate:            45.83%
#>   Avg Trade:           $2.15
#>
#> Exposure:
#>   Time in Market:      78.29%
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
#> # A tibble: 2 x 8
#>   run_id       label final_equity total_return max_drawdown n_trades win_rate
#>   <chr>        <chr>        <dbl> <chr>        <chr>           <int> <chr>
#> 1 top_return_1 <NA>         9959. -0.4%        -18.3%             24 45.8%
#> 2 top_return_2 <NA>         9999. -0.0%        -1.2%               7 57.1%
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
#> # A tibble: 3 x 8
#>   run_id        label final_equity total_return max_drawdown n_trades win_rate
#>   <chr>         <chr>        <dbl> <chr>        <chr>           <int> <chr>
#> 1 top_return_1  <NA>         9959. -0.4%        -18.3%             24 45.8%
#> 2 top_return_2  <NA>         9999. -0.0%        -1.2%               7 57.1%
#> 3 flat_baseline <NA>        10000  +0.0%        0.0%                0 <NA>
#> # i 1 more variable: reproducibility_level <chr>
#>
#> # i Full identity and telemetry columns remain available on this tibble.
#> # i Inspect one run with ledgr_run_info(snapshot, run_id).
```

The flat baseline has no win rate because it has no closed trades. That
is not missing data; there are no wins or losses to count.

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
#> Reproducibility: tier_2
#> Source Hash:     3fea0cd657f5bb33baf0f7939e8091258abcaad27c48b6f261bbc3039733d9aa
#> Params Hash:     3caea9cbe019dbfa16b53b9bbeee913bdb2f16e4c6f196e0f5a3c8332cac270c
#> Hash Verified:   TRUE
#> Trust:           FALSE
#> Source Available:TRUE
#>
#> Warnings:
#> - This run is tier_2; recovered source may depend on external state or not be executable by itself.
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
ledgr_snapshot_close(snapshot)
```

## What’s Next?

If you want the formal contract, read the strategy and context sections
in `inst/design/contracts.md`. If you want the deployment story,
continue with `vignette("research-to-production", package = "ledgr")`.
If you want to inspect or compare durable runs, read
`vignette("experiment-store", package = "ledgr")`.
