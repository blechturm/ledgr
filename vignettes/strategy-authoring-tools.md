# Strategy Authoring Tools


`vignette("strategy-development", package = "ledgr")` showed the
contract: a strategy is a function of `ctx` and `params` that returns
the holdings you want after the next fill. That is enough to run a first
idea. It is not yet enough to trust one. Before you spend a backtest on
a strategy, you want to see what it decides on a single day, know
exactly how a ranking became a number of shares, choose what happens
when an input is missing, and sometimes let today’s decision depend on
yesterday’s.

This article builds one momentum strategy three times. Each version
fixes a problem the previous one showed:

1.  rank the instruments and hold the top two;
2.  hold only the instruments that are actually rising;
3.  rebalance once a week, but exit a position early when it breaks its
    trend.

By the end you will have tested each version on one pulse, checked its
share sizing by hand, run all three, and compared how often they trade.

## Set Up

``` r
library(ledgr)
library(dplyr)
library(tibble)
data("ledgr_demo_bars", package = "ledgr")
```

The examples use four instruments from the offline demo data for the
first half of 2019.

``` r
instruments <- c("DEMO_01", "DEMO_02", "DEMO_03", "DEMO_04")

bars <- ledgr_demo_bars |>
  filter(
    instrument_id %in% instruments,
    between(ts_utc, ledgr_utc("2019-01-01"), ledgr_utc("2019-06-30"))
  )

snapshot <- ledgr_snapshot_from_df(
  bars,
  snapshot_id = "strategy_authoring_snapshot"
)

features <- list(ledgr_ind_returns(5), ledgr_ind_sma(10))
ledgr_feature_id(features)
#> [1] "return_5" "sma_10"
```

The strategies read two registered features: the 5-day return, used as
momentum, and the 10-day simple moving average, used as a trend line.
Features are declared on the experiment, never inside the strategy.
`vignette("indicators", package = "ledgr")` covers feature IDs, warmup,
and readable aliases.

## Test A Strategy On One Pulse

The first version is the plainest momentum rule: every day, hold the two
instruments with the highest 5-day return, using half of the account.

``` r
top_momentum <- function(ctx, params) {
  weights <- ctx |>
    ledgr_signal_return(lookback = 5) |>
    ledgr_select_top_n(params$n) |>
    ledgr_weight_equal()

  weights |>
    ledgr_target_rebalance(ctx, equity_fraction = params$invested)
}

params <- list(n = 2, invested = 0.5)
```

The next section takes that pipeline apart. First, check what it
decides. `ledgr_pulse_snapshot()` builds an inspection context for one
timestamp. Its cash, positions, and equity follow the same rules as the
`ctx` a dense backtest passes in; equity is cash plus the current value
of the supplied positions. You can therefore call the strategy yourself.
Start by looking at the inputs:

``` r
pulse <- ledgr_pulse_snapshot(
  snapshot,
  universe = instruments,
  ts_utc = ledgr_utc("2019-03-12"),
  features = features
)

tibble(
  instrument_id = pulse$universe,
  close = pulse$vec$close,
  momentum = pulse$vec$feature("return_5"),
  trend = pulse$vec$feature("sma_10")
)
#> # A tibble: 4 x 4
#>   instrument_id close momentum trend
#>   <chr>         <dbl>    <dbl> <dbl>
#> 1 DEMO_01       106.   -0.0123 106.
#> 2 DEMO_02        67.7   0.0359  67.0
#> 3 DEMO_03        81.8  -0.0114  83.1
#> 4 DEMO_04       107.   -0.0238 109.
```

Each `ctx$vec` value is a plain vector in the order of `ctx$universe`,
which is why the four columns line up. Now ask the strategy for its
decision:

``` r
top_momentum(pulse, params)
#> <ledgr_target> [4 assets]
#> origin: return_5
#> non-NA: 4/4
#> DEMO_01 DEMO_02 DEMO_03 DEMO_04
#>       0     369     305       0
```

On 12 March the strategy wants `DEMO_02` and `DEMO_03`, the two highest
5-day returns, and nothing else. This is exactly the target a backtest
would receive at this pulse. Calling a strategy on a pulse is the
fastest way to catch a wrong feature ID, a reversed comparison, or an
unexpected position size before you run months of bars.

> [!TIP]
>
> ### Read whole vectors, not one instrument at a time
>
> `ctx$vec$close` and `ctx$vec$feature()` return one value per instrument
> in a single read. The scalar forms `ctx$close(id)`,
> `ctx$feature(id, feature_id)`, and `ctx$position(id)` are for an
> instrument you have already singled out. Calling them in a loop over
> `ctx$universe` repeats per-instrument work at every pulse and is the
> most common way to make a strategy slow. For universes of at least 100
> instruments, ledgr emits one `ledgr_scalar_accessor_loop` warning per
> run that names the vector to use; the warning changes no result.


## From Scores To Shares

`top_momentum()` is a chain of small objects. Build it on the pulse one
step at a time:

``` r
signal <- ledgr_signal_return(pulse, lookback = 5)
signal
#> <ledgr_signal> [4 assets]
#> origin: return_5
#> non-NA: 4/4
#>     DEMO_01     DEMO_02     DEMO_03     DEMO_04
#> -0.01229707  0.03585798 -0.01136937 -0.02381160

selection <- ledgr_select_top_n(signal, n = 2)
selection
#> <ledgr_selection> [4 assets]
#> origin: return_5
#> 2 selected
#> DEMO_01 DEMO_02 DEMO_03 DEMO_04
#>   FALSE    TRUE    TRUE   FALSE

weights <- ledgr_weight_equal(selection)
weights
#> <ledgr_weights> [2 assets]
#> origin: return_5
#> non-NA: 2/2
#> DEMO_02 DEMO_03
#>     0.5     0.5
```

The default warns when fewer than `n` finite scores are available. That
makes an unexpectedly short ranking visible. Opt out only when selecting
fewer names is an intended policy:

``` r
short_signal <- ledgr_signal(c(
  DEMO_01 = 0.02,
  DEMO_02 = NA_real_,
  DEMO_03 = NA_real_,
  DEMO_04 = NA_real_
))

tryCatch(
  ledgr_select_top_n(short_signal, n = 2),
  warning = conditionMessage
)
#> [1] "Only 1 available signal value(s); selecting all available instruments. If this short selection is intentional, use `partial = \"allow\"`."
ledgr_select_top_n(short_signal, n = 2, partial = "allow")
#> <ledgr_selection> [4 assets]
#> 1 selected
#> DEMO_01 DEMO_02 DEMO_03 DEMO_04
#>    TRUE   FALSE   FALSE   FALSE
```

`ledgr_signal_return()` reads the registered `return_5` feature; it
never registers a feature for you. Use `ledgr_signal_feature()` for
another registered feature. Use `ledgr_signal(ctx, values = ...)` only
when you have already transformed the values into a genuinely custom
score.

| Object | What it holds | Made by |
|----|----|----|
| signal | one score per instrument | `ledgr_signal_return()`, `ledgr_signal_feature()` |
| selection | `TRUE` or `FALSE`: which instruments are chosen | `ledgr_select_top_n()`, `ledgr_selection()` |
| weights | each chosen instrument’s share of the budget | `ledgr_weight_equal()`, `ledgr_weights()` |
| target | whole-share quantities for every instrument | `ledgr_target_rebalance()` |

Only the target is something ledgr executes. The other three are working
objects: returning a signal, selection, or weights from a strategy is an
error.

Weights are relative. `0.5` means “half of the budget”, not a number of
shares. The weights say how to divide a budget. They do not contain the
budget, current prices, or current holdings. Turning them into shares
therefore needs the current `ctx` again:

``` r
target <- weights |>
  ledgr_target_rebalance(pulse, equity_fraction = 0.5)
target
#> <ledgr_target> [4 assets]
#> origin: return_5
#> non-NA: 4/4
#> DEMO_01 DEMO_02 DEMO_03 DEMO_04
#>       0     369     305       0
```

You can reproduce that sizing yourself. Each chosen instrument receives
`weight * equity_fraction * equity` in cash, divided by its current
close and rounded down to whole shares:

``` r
chosen <- names(weights)
chosen_close <- pulse$vec$close[match(chosen, pulse$universe)]

tibble(
  instrument_id = chosen,
  budget = as.numeric(weights) * 0.5 * pulse$equity,
  close = chosen_close,
  shares = floor(budget / chosen_close),
  target = as.numeric(target[chosen])
)
#> # A tibble: 2 x 5
#>   instrument_id budget close shares target
#>   <chr>          <dbl> <dbl>  <dbl>  <dbl>
#> 1 DEMO_02        25000  67.7    369    369
#> 2 DEMO_03        25000  81.8    305    305
```

The remainder left by rounding stays in cash. Every instrument that was
not chosen gets a target of zero, so a rebalance sells anything it no
longer wants.

> [!WARNING]
>
> ### Keeping one position while rebalancing the rest
>
> Name a position in `keep` when you want to preserve it while rebalancing
> the rest. ledgr keeps its current quantity, reserves its marked exposure
> once, and sizes the new weights from the capital that remains. This
> pulse holds four shares of `DEMO_04` and has 600 in cash. Keeping
> `DEMO_04` leaves that 600 for the new position:
>
> ``` r
> keep_pulse <- ledgr_pulse_snapshot(
>   snapshot,
>   universe = instruments,
>   ts_utc = ledgr_utc("2019-03-12"),
>   features = features,
>   cash = 600,
>   positions = c(DEMO_04 = 4)
> )
> keep_weights <- ledgr_weights(c(DEMO_02 = 1), universe = instruments)
> keep_weights |>
>   ledgr_target_rebalance(keep_pulse, keep = "DEMO_04")
> #> <ledgr_target> [4 assets]
> #> non-NA: 4/4
> #> DEMO_01 DEMO_02 DEMO_03 DEMO_04
> #>       0       8       0       4
> ```
>
> `equity_fraction` applies to that remaining capital. Do not shrink it by
> hand to make room for the kept position; doing both would shrink the
> remaining budget a second time and underinvest the account.


## Run The First Version

``` r
top_momentum_run <- ledgr_experiment(
  snapshot = snapshot,
  strategy = top_momentum,
  features = features,
  opening = ledgr_opening(cash = 10000),
  cost_model = ledgr_cost_zero()
) |>
  ledgr_run(params = params, run_id = "v1_ranking")

top_momentum_fills <- ledgr_results(top_momentum_run, what = "fills")
nrow(top_momentum_fills)
#> [1] 136

top_momentum_fills |>
  select(ts_utc, instrument_id, side, qty) |>
  slice_head(n = 6)
#> # A tibble: 6 x 4
#>   ts_utc     instrument_id side    qty
#>   <date>     <chr>         <chr> <dbl>
#> 1 2019-01-09 DEMO_02       BUY      33
#> 2 2019-01-09 DEMO_03       BUY      30
#> 3 2019-01-10 DEMO_02       SELL     33
#> 4 2019-01-10 DEMO_04       BUY      25
#> 5 2019-01-11 DEMO_02       BUY      33
#> 6 2019-01-11 DEMO_03       SELL     30
```

Nothing trades during the first week. Until five prior bars exist, every
5-day return is `NA`; ranking skips missing scores, finds nothing to
choose, and returns an empty selection without a warning, so the target
is all zeros. After warmup, the strategy trades almost every day because
the two highest returns keep changing. Each decision fills at the next
open, so a fill’s date is the pulse after the decision.

If a whole run finishes with no fills, test the strategy on a late
pulse. A feature that never warms up looks exactly like this first week,
only it never ends.

When you run this yourself, R also prints a `LEDGR_LAST_BAR_NO_FILL`
warning. The strategy changed its target on the final bar, and there is
no later open at which to fill it. Expect it at the end of most samples;
`?LEDGR_LAST_BAR_NO_FILL` explains when it matters.

## Choose Members With A Rule Instead Of A Rank

The pulse test already showed a weakness. On 12 March the first version
bought `DEMO_03` even though its 5-day return was negative and its price
was below its 10-day average. A ranking always picks two names, even
when both are falling.

A better rule: hold every instrument that is rising, meaning positive
momentum and a close above its trend, and split the budget equally among
however many qualify. That is a yes-or-no decision per instrument, so it
goes into `ledgr_selection(ctx, where = ...)` instead of a ranking.
Written directly, the rule fails at the start of the sample:

``` r
first_pulse <- ledgr_pulse_snapshot(
  snapshot,
  universe = instruments,
  ts_utc = min(bars$ts_utc),
  features = features
)

rising <- first_pulse$vec$feature("return_5") > 0 &
  first_pulse$vec$close > first_pulse$vec$feature("sma_10")
rising
#> [1] NA NA NA NA

tryCatch(
  ledgr_selection(first_pulse, where = rising),
  error = conditionMessage
)
#> [1] "`where` contains missing decisions for current members: DEMO_01, DEMO_02, DEMO_03, DEMO_04. Use `missing = \"exclude\"` to treat them as not selected; a rebalance then targets those instruments to zero."
```

At the first pulse neither feature has enough history, so every
comparison is `NA`. ledgr refuses a missing decision instead of quietly
treating it as `FALSE`, because “not chosen” and “could not tell” are
different statements.

Ranking treated missing values differently. In `top_momentum()` a
missing score was simply left out of the ranking. A missing number means
“no score”; a missing `TRUE`/`FALSE` means “no decision”, and the
strategy has to resolve it. Here, “not rising” is the right answer when
any input is missing, including the close:

``` r
trend_momentum <- function(ctx, params) {
  momentum <- ctx$vec$feature("return_5")
  trend <- ctx$vec$feature("sma_10")
  close <- ctx$vec$close
  rising <- momentum > 0 & close > trend

  weights <- ctx |>
    ledgr_selection(where = rising, missing = "exclude") |>
    ledgr_weight_equal()

  weights |>
    ledgr_target_rebalance(ctx, equity_fraction = params$invested)
}

trend_momentum(first_pulse, params)
#> <ledgr_target> [4 assets]
#> non-NA: 4/4
#> DEMO_01 DEMO_02 DEMO_03 DEMO_04
#>       0       0       0       0
trend_momentum(pulse, params)
#> <ledgr_target> [4 assets]
#> non-NA: 4/4
#> DEMO_01 DEMO_02 DEMO_03 DEMO_04
#>       0     739       0       0
```

The first pulse now selects nothing. `missing = "exclude"` is the
deliberate policy: an unknown decision counts as not selected. On 12
March the rule keeps only `DEMO_02` and gives it the whole invested half
of the account.

``` r
trend_momentum_run <- ledgr_experiment(
  snapshot = snapshot,
  strategy = trend_momentum,
  features = features,
  opening = ledgr_opening(cash = 10000),
  cost_model = ledgr_cost_zero()
) |>
  ledgr_run(params = params, run_id = "v2_rule")

nrow(ledgr_results(trend_momentum_run, what = "fills"))
#> [1] 177
```

The rule trades even more than the ranking did. It stopped buying
falling instruments, but every time an instrument starts or stops
rising, the equal split changes, and the rebalance resizes every
position to its new share, often by a share or two. The third version
deals with that churn.

## Decide What A Missing Input Should Do

Both versions go flat while their inputs warm up. That was harmless
above because the account started in cash. It is not harmless when you
start with existing holdings:

``` r
holding_pulse <- ledgr_pulse_snapshot(
  snapshot,
  universe = instruments,
  ts_utc = min(bars$ts_utc),
  features = features,
  positions = c(DEMO_01 = 0, DEMO_02 = 40, DEMO_03 = 0, DEMO_04 = 0)
)

trend_momentum(holding_pulse, params)
#> <ledgr_target> [4 assets]
#> non-NA: 4/4
#> DEMO_01 DEMO_02 DEMO_03 DEMO_04
#>       0       0       0       0
holding_pulse$hold()
#> DEMO_01 DEMO_02 DEMO_03 DEMO_04
#>       0      40       0       0
```

`trend_momentum()` returns zero for `DEMO_02`, which would sell all 40
shares on the first day only because the features have not warmed up.
`ctx$hold()` returns the current quantities, which means “change
nothing”. What a strategy returns for an instrument is always a quantity
to hold after the next fill:

| The strategy returns | Meaning |
|----|----|
| the current quantity, as `ctx$hold()` does | keep the position |
| zero, including an instrument left out of the selection | sell down to zero |
| a positive number | hold that many shares |

These are requests. If the experiment has a `risk_chain`, it still
applies, so returning `ctx$hold()` does not guarantee that no fill
occurs.

If missing input should pause the strategy rather than empty it, say so
explicitly. `ledgr_passed_warmup()` is `TRUE` only when every value it
is given is present, so the guard is one line at the top of the
strategy:

``` r
if (!ledgr_passed_warmup(ctx$vec$feature("sma_10"))) return(ctx$hold())
```

The third version uses it.

## Give The Strategy A Memory

`trend_momentum()` still decides from scratch every day, so it trades
whenever an instrument crosses its trend line. Suppose you want to
rebalance only every fifth pulse, roughly once a week on daily bars, but
still exit a position early if it drops below its trend. The strategy
then needs to remember something between pulses: how many pulses have
passed.

Strategy state is that memory:

- Instead of a bare target, return
  `list(targets = ..., state_update = ...)`. `state_update` is a list of
  plain data you choose: numbers, strings, logical values, and lists of
  them.
- At the next pulse, that list arrives as `ctx$state_prev`. On the first
  pulse there is nothing to remember yet, so
  `ctx$state_prev$pulses_seen` is `NULL`.
- Returning a bare target keeps the previous state unchanged.
- ledgr stores the state with the run but does not interpret it. The
  names inside it are yours.
- State records decisions, not fills. A target returned at one pulse
  fills at the next open.

``` r
weekly_trend_momentum <- function(ctx, params) {
  pulses_seen <- ctx$state_prev$pulses_seen
  if (is.null(pulses_seen)) pulses_seen <- 0

  momentum <- ctx$vec$feature("return_5")
  trend <- ctx$vec$feature("sma_10")
  close <- ctx$vec$close

  if (!ledgr_passed_warmup(trend)) {
    targets <- ctx$hold()
  } else if (pulses_seen %% params$every == 0) {
    rising <- momentum > 0 & close > trend
    weights <- ctx |>
      ledgr_selection(where = rising, missing = "exclude") |>
      ledgr_weight_equal()
    targets <- weights |>
      ledgr_target_rebalance(ctx, equity_fraction = params$invested)
  } else {
    targets <- ctx$hold()
    targets[which(close < trend)] <- 0
  }

  list(targets = targets, state_update = list(pulses_seen = pulses_seen + 1))
}

weekly_params <- list(invested = 0.5, every = 5)
```

`pulses_seen` counts pulses. While the trend line is still warming up,
the strategy holds. On every fifth pulse it rebalances with the rule
from the second version. In between, it starts from `ctx$hold()`, keeps
every position, and changes one thing: an instrument that closed below
its trend is set to zero. An instrument without a close is neither
bought nor sold. That is the hold-then-edit pattern: start from what you
own and change only what today’s evidence justifies.

You might be tempted to call `trend_momentum()` from inside
`weekly_trend_momentum()` instead of repeating the rule. Don’t: ledgr
only runs self-contained strategies, and a call to your own function
defined outside the strategy, such as `trend_momentum()`, is rejected
before the run starts. `vignette("reproducibility", package = "ledgr")`
explains why.

Calling the strategy on the study pulse shows the shape it returns.
There is no previous state, so `pulses_seen` starts at zero and this is
a rebalance pulse:

``` r
weekly_trend_momentum(pulse, weekly_params)
#> $targets
#> <ledgr_target> [4 assets]
#> non-NA: 4/4
#> DEMO_01 DEMO_02 DEMO_03 DEMO_04
#>       0     739       0       0
#>
#> $state_update
#> $state_update$pulses_seen
#> [1] 1
```

Supply previous state and holdings to test the other branch without
running a backtest. Here `pulses_seen = 1` makes this a holding pulse;
the strategy keeps the book except for a position whose close broke
below its trend:

``` r
exit_pulse <- ledgr_pulse_snapshot(
  snapshot,
  universe = instruments,
  ts_utc = ledgr_utc("2019-03-12"),
  features = features,
  positions = c(DEMO_02 = 10, DEMO_03 = 10),
  state_prev = list(pulses_seen = 1)
)

weekly_trend_momentum(exit_pulse, weekly_params)
#> $targets
#> DEMO_01 DEMO_02 DEMO_03 DEMO_04
#>       0      10       0       0
#>
#> $state_update
#> $state_update$pulses_seen
#> [1] 2
```

Now run it and compare the three versions:

``` r
weekly_run <- ledgr_experiment(
  snapshot = snapshot,
  strategy = weekly_trend_momentum,
  features = features,
  opening = ledgr_opening(cash = 10000),
  cost_model = ledgr_cost_zero()
) |>
  ledgr_run(params = weekly_params, run_id = "v3_weekly")

ledgr_run_compare(snapshot)
#> # ledgr comparison
#> # A tibble: 3 x 9
#>   run_id     label final_equity total_return sharpe_ratio max_drawdown n_trades win_rate
#>   <chr>      <chr>        <dbl> <chr>               <dbl> <chr>           <int> <chr>
#> 1 v1_ranking <NA>        11372. +13.7%               2.63 -4.2%              76 69.7%
#> 2 v2_rule    <NA>        10874. +8.7%                1.88 -3.7%              93 63.4%
#> 3 v3_weekly  <NA>        10577. +5.8%                1.46 -3.3%              36 55.6%
#> # i 1 more variable: reproducibility_level <chr>
#>
#> # i Fill timing comparable: yes (same_timing_convention).
#> # i Full identity and telemetry columns remain available on this tibble.
#> # i Inspect one run with ledgr_run_info(snapshot, run_id).
```

`ledgr_run_compare()` summarizes every run stored with the snapshot.
`n_trades` counts sales that close earlier purchases, fully or in part;
purchases alone are not counted, so it is smaller than the number of
fills.

Each change did what it was designed to do: the rule stopped buying
falling instruments, and the schedule cut the number of trades by more
than half. That is not evidence that the weekly version is a better
strategy; in this sample the plain ranking even finished with the most
equity. Three variants of one idea on four instruments over six months
say nothing reliable about performance.
`vignette("research-workflow", package = "ledgr")` covers how to compare
candidates without fooling yourself.

> [!TIP]
>
> ### Try it
>
> Run `weekly_trend_momentum()` with `every = 1`. It should reproduce
> `trend_momentum()` fill for fill. Why? Checks like this are a cheap way
> to confirm that a rewrite changed only what you meant to change.


The fills show both kinds of pulse:

``` r
ledgr_results(weekly_run, what = "fills") |>
  select(ts_utc, instrument_id, side, qty) |>
  slice_head(n = 8)
#> # A tibble: 8 x 4
#>   ts_utc     instrument_id side    qty
#>   <date>     <chr>         <chr> <dbl>
#> 1 2019-01-23 DEMO_01       BUY      28
#> 2 2019-01-23 DEMO_04       BUY      25
#> 3 2019-01-30 DEMO_01       SELL     15
#> 4 2019-01-30 DEMO_02       BUY      17
#> 5 2019-01-30 DEMO_03       BUY      16
#> 6 2019-01-30 DEMO_04       SELL     13
#> 7 2019-02-01 DEMO_02       SELL     17
#> 8 2019-02-04 DEMO_04       SELL     12
```

Purchases happen only after rebalance pulses, because between them the
strategy can only keep or exit. On 30 January two more instruments
qualified, so the budget was split four ways instead of two: `DEMO_01`
and `DEMO_04` were cut roughly in half to make room for `DEMO_02` and
`DEMO_03`. The sales on 1 and 4 February are early exits: those
instruments closed below their trend between rebalances.

## In Availability-Aware Runs

Everything above uses a dense panel, where every instrument can be
selected at every pulse. In an availability-aware run, the set of
instruments you may invest in changes over time;
`vignette("survivorship-bias", package = "ledgr")` shows one end to end.
Four things then work differently:

- `ctx$universe` can include an instrument you still hold but may no
  longer select, a *held nonmember*. `ctx$members` lists the instruments
  that are currently eligible.
- `ledgr_selection()`, `ledgr_signal()`, and `ledgr_select_top_n()`
  choose only among members. Values you supply for held nonmembers are
  ignored, not ranked. `ledgr_signal_return()` and
  `ledgr_signal_feature()` also mark scores of target-inadmissible
  members as missing. A score you build yourself with
  `ledgr_signal(ctx, values = ...)` deliberately bypasses that
  convenience mask.
- `ledgr_target_rebalance()` keeps each held nonmember’s quantity and
  reserves its value before sizing, so weights apply to what remains.
  With equity 100 and a held nonmember worth 40, weight 1 allocates 60,
  and weight 0.6 allocates 36. If your weights are fractions of total
  equity, for example from an optimizer, convert them first: 60% of
  total equity is weight 1 here.
- `ctx$state_prev` also carries `asset_state`, one entry per instrument
  in `ctx$universe` for state that belongs to that instrument. An
  instrument that leaves the universe loses its entry;
  `vignette("strategy-development",   package = "ledgr")` states the
  rules.

Neither membership nor `ctx$tradable()` guarantees that an order fills
at the next open.

## Cleanup

``` r
close(top_momentum_run)
close(trend_momentum_run)
close(weekly_run)
close(pulse)
close(first_pulse)
close(holding_pulse)
close(keep_pulse)
close(exit_pulse)
ledgr_snapshot_close(snapshot)
```

## Where Next

- `vignette("strategy-development", package = "ledgr")` covers the
  strategy contract, `ctx$flat()` and `ctx$hold()`, and a first run.
- `vignette("indicators", package = "ledgr")` covers feature IDs,
  warmup, and feature maps with readable aliases.
- `vignette("sweeps", package = "ledgr")` compares parameter values such
  as `invested` and `every` systematically.
- `vignette("reproducibility", package = "ledgr")` explains preflight
  tiers and why strategies must be self-contained.
- `vignette("survivorship-bias", package = "ledgr")` runs an
  availability-aware strategy end to end.
