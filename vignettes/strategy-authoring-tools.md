# Strategy Authoring Tools


After the raw `function(ctx, params) -> target vector` contract is
clear, strategy work shifts to composing decisions you can inspect: read
current state, derive weights, turn them into complete intent, and debug
one pulse before running. This companion article teaches that workflow
together with feature aliases. For the first-pass strategy contract and
leakage boundary, read
`vignette("strategy-development", package = "ledgr")`.

## Choose An Authoring Path

At each pulse, strategy code reads current state, makes a decision from
pulse-known inputs, and returns complete portfolio intent. Two paths
cover most strategies:

| Path | Use it when | Authoring result | Executable result |
|----|----|----|----|
| derive weights, then rebalance | this pulse constructs a member allocation | relative weights over current investment members | complete quantities from `ledgr_target_rebalance()` |
| hold, then edit | existing quantities should remain unless this pulse changes them | a copy from `ctx$hold()` with named edits | the edited complete target |

The **decision axis** is `ctx$universe`: every instrument for which the
strategy must return intent. **Current investment members** are the
instruments eligible to enter selection and weighting. In an
availability-aware run, the decision axis can also include a held
nonmember needed for valuation or disposition. It stays out of ranking
and weighting. Neither membership nor `ctx$tradable()` promises
execution at the next open.

Both paths finish with one named quantity for every instrument on the
decision axis. The introductory target-vector contract and the
difference between `ctx$flat()` and `ctx$hold()` live in
`vignette("strategy-development", package = "ledgr")`.

> [!WARNING]
>
> ### Reserve a kept member before sizing the rest
>
> Do not size against the full budget and then restore a current member’s
> position. If two `DEMO_02` shares consume 40% of NAV, allocate only the
> remaining 60%, then restore that named quantity:
>
> ``` r
> targets <- ledgr_target_rebalance(weights, ctx, equity_fraction = 0.6)
> targets[["DEMO_02"]] <- ctx$position("DEMO_02")
> ```
>
> The value `0.6` is the strategy’s explicit budget decision, not a magic
> default. Held *nonmembers* are reserved automatically; kept current
> members are not. With NAV 100, two shares marked at 20 consume 40 and
> leave 60 for the rest of the book. At a price of 10, weight 1 over that
> residual budget targets six shares; weight 0.6 targets three. A strategy
> intending 60% of total NAV in the new allocation therefore uses residual
> weight 1, not 0.6.


## Prerequisites

The examples use `dplyr` for demo-data preparation. Strategy functions
use ledgr’s pulse context rather than data-frame operations. The article
assumes basic familiarity with sealed snapshots
(`vignette("data-input-and-snapshots", package = "ledgr")`) and feature
IDs (`vignette("indicators", package = "ledgr")`).

``` r
library(ledgr)
library(dplyr)
library(tibble)
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
in `ctx$vec$close`, `ctx$vec$position`, and
`ctx$vec$feature(feature_id)` use that same order, so a strategy can
inspect the decision axis without repeating scalar lookups. By default,
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
same pulse-known data. The rest of this article uses vector accessors
because they keep cross-sectional strategy logic both readable and
inexpensive.

## Derive Weights, Then Rebalance In Context

A helper pipeline produces a relative allocation. Keep that research
object separate from the economic conversion into share quantities:

``` r
equal_weights <- pulse |>
  ledgr_selection() |>
  ledgr_weight_equal()

equal_target <- ledgr_target_rebalance(
  equal_weights,
  pulse,
  equity_fraction = 0.1
)

equal_weights
#> <ledgr_weights> [2 assets]
#> non-NA: 2/2
#> DEMO_01 DEMO_02
#>     0.5     0.5
equal_target
#> <ledgr_target> [2 assets]
#> non-NA: 2/2
#> DEMO_01 DEMO_02
#>      46      73
```

The repeated `pulse` is meaningful. Weights say how to divide an
allocation; the current context supplies equity, prices, positions, and
the complete decision axis needed to express that allocation as
quantities.

`ledgr_selection(ctx)` selects current investment members. In a dense
run that is the full decision axis. In an availability-aware run,
`ctx$universe` can also contain a held nonmember needed for valuation or
disposition. That nonmember does not enter ranking or weighting; the
rebalance reserves its marked exposure and preserves its quantity. The
member set defines who can enter the allocation; it is not a promise of
execution at the next open.

## Hold, Then Edit

Use hold-and-edit when most quantities should remain unchanged. State
can decide which edit applies, but the strategy still returns complete
intent:

``` r
stateful_entry_exit <- function(ctx, params) {
  targets <- ctx$hold()
  id <- params$instrument_id
  phase <- ctx$state_prev$phase
  if (is.null(phase)) phase <- "waiting"

  if (phase == "waiting" && ctx$close(id) < params$entry_below) {
    targets[[id]] <- 1
    phase <- "holding"
  } else if (
    phase == "holding" &&
      ctx$position(id) > 0 &&
      ctx$close(id) > params$exit_above
  ) {
    targets[[id]] <- 0
    phase <- "done"
  }

  list(targets = targets, state_update = list(phase = phase))
}

stateful_exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = stateful_entry_exit,
  opening = ledgr_opening(
    cash = 10000,
    positions = c(DEMO_02 = 2),
    cost_basis = c(DEMO_02 = 180)
  ),
  cost_model = ledgr_cost_zero()
)
stateful_run <- ledgr_run(
  stateful_exp,
  params = list(
    instrument_id = "DEMO_01",
    entry_below = 90,
    exit_above = 91
  )
)

ledgr_results(stateful_run, what = "fills") |>
  select(ts_utc, instrument_id, side, qty)
#> # A tibble: 2 x 4
#>   ts_utc     instrument_id side    qty
#>   <date>     <chr>         <chr> <dbl>
#> 1 2019-01-07 DEMO_01       BUY       1
#> 2 2019-01-25 DEMO_01       SELL      1

close(stateful_run)
```

`DEMO_01` enters below 90 and exits above 91. The state prevents a later
re-entry, while `ctx$hold()` preserves the two opening `DEMO_02` shares
without special-case code. Returning hold does not bypass a risk chain
or guarantee that no fill occurs. It states portfolio intent at this
decision; downstream rules still apply.

## Make Missing And Zero Intent Explicit

Five cases look similar in compact code and mean different things. This
example keeps an existing `DEMO_02` position so hold is visibly
different from zero. It also injects one missing value deliberately; the
sealed data itself is unchanged.

``` r
momentum_with_hold_guard <- function(ctx, params) {
  scores <- ctx$vec$feature(paste0("return_", params$lookback))
  if (anyNA(scores)) return(ctx$hold())

  weights <- ctx |>
    ledgr_signal(values = scores) |>
    ledgr_select_top_n(params$n) |>
    ledgr_weight_equal()

  ledgr_target_rebalance(
    weights,
    ctx,
    equity_fraction = params$equity_fraction
  )
}

warmup_pulse <- ledgr_pulse_snapshot(
  snapshot,
  universe = c("DEMO_01", "DEMO_02"),
  ts_utc = min(bars$ts_utc),
  features = features,
  positions = c(DEMO_01 = 0, DEMO_02 = 3)
)

prices_with_gap <- pulse$vec$close
prices_with_gap[[2L]] <- NA_real_

bare_predicate_error <- tryCatch(
  {
    ledgr_selection(pulse, where = prices_with_gap > 0)
    NA_character_
  },
  error = function(err) class(err)[[1L]]
)

guarded_selection <- ledgr_selection(
  pulse,
  where = !is.na(prices_with_gap) & prices_with_gap > 0
)

missing_score_target <- ledgr_signal(
  pulse,
  values = setNames(c(0.2, NA_real_), pulse$universe)
) |>
  ledgr_select_top_n(1) |>
  ledgr_weight_equal() |>
  ledgr_target_rebalance(pulse, equity_fraction = 0.1)

explicit_zero_target <- ledgr_weights(
  c(DEMO_01 = 1, DEMO_02 = 0),
  universe = pulse$universe
) |>
  ledgr_target_rebalance(pulse, equity_fraction = 0.1)

omitted_target <- ledgr_weights(
  c(DEMO_01 = 1),
  universe = pulse$universe
) |>
  ledgr_target_rebalance(pulse, equity_fraction = 0.1)

hold_target <- momentum_with_hold_guard(
  warmup_pulse,
  list(lookback = 5, n = 1, equity_fraction = 0.1)
)

show_target <- function(x) {
  paste(paste(names(x), c(x), sep = "="), collapse = ", ")
}

intent_cases <- tibble(
  input = c(
    "missing logical decision",
    "missing numeric score",
    "explicit zero weight",
    "omitted weight",
    "hold during warmup"
  ),
  meaning = c(
    "not a decision; guard it explicitly",
    "exclude that score from ranking",
    "validate the name and request zero",
    "leave that member unallocated",
    "preserve every current quantity"
  ),
  resulting_target = c(
    paste0(
      "error: ", bare_predicate_error, "; guarded: ",
      names(guarded_selection)[unclass(guarded_selection)]
    ),
    show_target(missing_score_target),
    show_target(explicit_zero_target),
    show_target(omitted_target),
    show_target(hold_target)
  )
)

knitr::kable(intent_cases)
```

| input | meaning | resulting_target |
|:---|:---|:---|
| missing logical decision | not a decision; guard it explicitly | error: ledgr_invalid_strategy_type; guarded: DEMO_01 |
| missing numeric score | exclude that score from ranking | DEMO_01=93, DEMO_02=0 |
| explicit zero weight | validate the name and request zero | DEMO_01=93, DEMO_02=0 |
| omitted weight | leave that member unallocated | DEMO_01=93, DEMO_02=0 |
| hold during warmup | preserve every current quantity | DEMO_01=0, DEMO_02=3 |

``` r
close(warmup_pulse)
```

The guarded logical form turns the missing comparison into an explicit
exclusion. A missing score is already understood by ranking. Exact zero
and omission both produce zero here, but zero records a deliberate
choice and is dropped before price lookup. Hold is different: it keeps
the three `DEMO_02` shares. If missing input should pause the whole
rebalance, return hold as the warmup guard does.

## Read Planes, Not One Instrument At A Time

`ctx$vec$close` returns the aligned vector the engine already prepared
for this pulse. `ctx$close(id)` validates and looks up one instrument.
Use the scalar form after singling out an instrument; do not call it
once for every member.

> [!WARNING]
>
> ### Read the plane for cross-sectional work
>
> `ctx$close(id)`, `ctx$feature(id, feature_id)`, and `ctx$position(id)`
> are for asking about one instrument you have already singled out.
> Reaching for them inside `vapply()`, `sapply()`, or a `for` loop over
> `ctx$universe` is the most expensive common strategy-authoring habit.
> When you want a value for everyone, read `ctx$vec$close`,
> `ctx$vec$feature()`, or `ctx$vec$position` once. For universes of at
> least 100 instruments, ledgr emits one `ledgr_scalar_accessor_loop`
> warning per run when one scalar accessor reaches a decision-axis call
> count in a pulse. The warning names the vector plane to use; it is
> diagnostic only and changes no target, fill, result, or run identity.


The optimization manual carries the measurements behind this rule.
Strategy authors only need the rule: use a plane for a cross-section and
a scalar for a chosen instrument.

## Turn The Idea Into A Strategy

The same transformations become an ordinary strategy function.

The full backtest replays every bar, including the earliest warmup
pulses. During those first pulses, `return_5` is `NA` for every
instrument because five prior bars do not exist yet.
`ledgr_select_top_n()` treats that all-missing signal as a classed empty
selection, not as a warning. That object still carries the member set
and signal origin. `ledgr_weight_equal()` turns it into empty weights,
and `ledgr_target_rebalance()` turns those weights into a flat target
over the decision axis.

No warning suppression is needed for ordinary early warmup. A
partial-selection warning can still appear when some signal values are
usable but fewer than `n` instruments can be selected. If a run finishes
with zero trades, inspect a late pulse before assuming the empty
selection was only early warmup.

``` r
top_return_strategy <- function(ctx, params) {
  weights <- ctx |>
    ledgr_signal_return(lookback = params$lookback) |>
    ledgr_select_top_n(n = params$n) |>
    ledgr_weight_equal()

  ledgr_target_rebalance(
    weights,
    ctx,
    equity_fraction = params$equity_fraction
  )
}
```

Read it economically:

1.  The pipeline scores current investment members by recent return.
2.  It keeps the highest scores, ignores warmup `NA`, and derives equal
    weights.
3.  The final call applies those weights in the current context and
    returns floored, complete target quantities.

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

top_return_run <- ledgr_run(
  exp,
  params = list(lookback = 5, n = 1, equity_fraction = 0.1),
  run_id = "top_return"
)

ledgr_results(top_return_run, what = "fills") |>
  select(ts_utc, instrument_id, side, qty) |>
  slice_head(n = 4)
#> # A tibble: 4 x 4
#>   ts_utc     instrument_id side    qty
#>   <date>     <chr>         <chr> <dbl>
#> 1 2019-01-09 DEMO_02       BUY      13
#> 2 2019-01-14 DEMO_01       BUY      11
#> 3 2019-01-14 DEMO_02       SELL     13
#> 4 2019-01-18 DEMO_01       SELL     11
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
decision-axis inspection.

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
by the aliases. `ledgr_passed_warmup()` is a guard for that vector. For
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
#> Execution Evidence:
#>   Fill Timing:         dense_bar_timestamp
#>   Timing Version:      N/A
#>
#>
#> Corporate-Action Evidence:
#> Corporate actions: NOT SUPPLIED - returns may omit distributions
#> Price basis: UNDECLARED - distribution double counting cannot be ruled out
#>   Setting cash_amount:              gross
#>   Identity cash_amount:             ledgr.corporate_action.cash_amount.gross.v001
#>   Setting cash_posting:             effective_close
#>   Identity cash_posting:            ledgr.corporate_action.cash_posting.effective_close.v001
#>   Setting held_terminal_position:   last_permissible
#>   Identity held_terminal_position:  ledgr.corporate_action.held_terminal_position.last_permissible.v001
#>   Setting unsupported_quantity:     report_only
#>   Identity unsupported_quantity:    ledgr.corporate_action.unsupported_quantity.report_only.v001
#>   Exercised choices:
#>     cash_amount.gross: 0
#>     cash_amount.refuse: 0
#>     cash_posting.effective_close: 0
#>     cash_posting.next_open: 0
#>     cash_posting.refuse: 0
#>     held_terminal_position.last_permissible: 0
#>     held_terminal_position.last_mark: 0
#>     held_terminal_position.refuse: 0
#>     unsupported_quantity.report_only: 0
#>     unsupported_quantity.refuse: 0
#>   Refusal reasons:
#>     none declared: 0
#>   Late arrivals:               0
#>   Affected marked exposure:    0
#>   Gross cash posted:           0
#>   Modeled terminal proceeds:   0
#>   Positions disposed:          0
#>   Realized model P&L:          0
#>   Unsupported facts:           0
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
#>   Closed Trades:       19
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

## Check Target Names Before A Full Run

When a hand-written target fails validation, compare its names with the
decision axis before rerunning the experiment:

``` r
setdiff(pulse$universe, names(equal_target))
#> character(0)
setdiff(names(equal_target), pulse$universe)
#> character(0)
```

An empty first result means no instrument is missing. An empty second
result means no unknown instrument was added. For invalid return shapes,
strategy preflight tiers, stored source, hash verification, and trust
boundaries, use the canonical guide: read
`vignette("reproducibility", package = "ledgr")`.

## Cleanup

``` r
close(bt_mapped)
close(top_return_run)
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
