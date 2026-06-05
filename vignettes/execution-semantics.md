# Execution Semantics


<style>
.ledgr-diagram {
  margin: 1.25rem auto 1.5rem auto;
  text-align: center;
}
&#10;.ledgr-diagram .mermaid {
  display: inline-block;
  max-width: 100%;
}
&#10;.ledgr-diagram .mermaid svg {
  display: block;
  height: auto !important;
  margin-left: auto;
  margin-right: auto;
}
&#10;.ledgr-execution-diagram .mermaid svg {
  max-width: 920px !important;
}
</style>

This article explains what happens after a strategy returns target
holdings. It is about fill timing and ledger state, not strategy design
or validation.

## Prerequisites

``` r
library(ledgr)
library(dplyr)
data("ledgr_demo_bars", package = "ledgr")
```

## The Short Version

ledgr strategies emit desired holdings at each pulse. They do not emit
orders. The fold core compares the desired target to current state,
creates the required position delta, and fills that delta at the next
bar’s open.

<div class="ledgr-diagram ledgr-execution-diagram">

``` mermaid
%%{init: {"theme": "base", "flowchart": {"nodeSpacing": 22, "rankSpacing": 24, "curve": "linear"}, "themeVariables": {"fontFamily": "system-ui, -apple-system, Segoe UI, sans-serif", "fontSize": "22px", "primaryColor": "#f8fafc", "primaryTextColor": "#1f2937", "primaryBorderColor": "#64748b", "lineColor": "#64748b", "tertiaryColor": "#eef2ff", "tertiaryTextColor": "#1f2937", "tertiaryBorderColor": "#64748b"}}}%%

flowchart LR
  pulse["Pulse t data"]
  target["Strategy target"]
  delta["Target delta"]
  fill["Next-open fill<br/>at t + 1"]
  ledger["Ledger state"]

  pulse --> target --> delta --> fill --> ledger
```

</div>

That one-bar delay is the no-lookahead boundary. The strategy can react
to the current pulse, but it cannot fill at a price from the same pulse.

## Targets Are Holdings

Returning `10` means “I want to hold 10 units”, not “buy 10 units every
bar.” If the current position already equals the target, there is no new
fill.

``` r
bars <- ledgr_demo_bars |>
  filter(
    instrument_id == "DEMO_01",
    between(ts_utc, ledgr_utc("2018-01-01"), ledgr_utc("2018-01-10"))
  )

demo_qty <- 10

hold_then_flat <- function(ctx, params) {
  targets <- ctx$flat()
  ts <- ledgr_utc(ctx$ts_utc)
  if (ts >= ledgr_utc("2018-01-03") && ts < ledgr_utc("2018-01-08")) {
    targets["DEMO_01"] <- demo_qty
  }
  targets
}

bt <- ledgr_backtest(
  data = bars,
  strategy = hold_then_flat,
  initial_cash = 10000,
  run_id = "execution_target_holdings"
)

ledgr_results(bt, what = "fills") |>
  select(ts_utc, instrument_id, side, qty, price, fee)
```

    # A tibble: 2 x 6
      ts_utc     instrument_id side    qty price   fee
      <date>     <chr>         <chr> <dbl> <dbl> <dbl>
    1 2018-01-04 DEMO_01       BUY      10  54.7     0
    2 2018-01-09 DEMO_01       SELL     10  52.9     0

The strategy asked for a position across several pulses, but only
position changes created fills: one opening fill and one closing fill.

## Next-Open Fill Timing

The signal pulse and execution pulse are different. The target changes
on one bar; the fill uses the next bar’s open.

``` r
signal_rows <- bars |>
  filter(ts_utc %in% c(ledgr_utc("2018-01-03"), ledgr_utc("2018-01-04"))) |>
  select(ts_utc, open, close)

fills <- ledgr_results(bt, what = "fills") |>
  select(ts_utc, side, qty, price)

signal_rows
```

    # A tibble: 2 x 3
      ts_utc               open close
      <dttm>              <dbl> <dbl>
    1 2018-01-03 00:00:00  53.8  54.5
    2 2018-01-04 00:00:00  54.7  54.0

``` r
fills
```

    # A tibble: 2 x 4
      ts_utc     side    qty price
      <date>     <chr> <dbl> <dbl>
    1 2018-01-04 BUY      10  54.7
    2 2018-01-09 SELL     10  52.9

The opening fill occurs at the next available bar after the strategy
changed target. That is why a strategy should treat `ctx$close(id)` and
feature values as pulse-known information, not as executable prices.

## Costs Are Part Of The Fill

> [!IMPORTANT]
>
> ### Public cost API
>
> The stable public transaction-cost model API is planned for v0.1.9.x /
> v0.2.0. The example below documents fill behavior for readers
> inspecting execution results. Do not treat this list interface as the
> stable public cost API.

The fill model shown here is the next-open model with spread and fixed
commission fields.

``` r
cost_bt <- ledgr_backtest(
  data = bars,
  strategy = hold_then_flat,
  initial_cash = 10000,
  run_id = "execution_cost_example",
  fill_model = list(type = "next_open", spread_bps = 5, commission_fixed = 1)
)

ledgr_results(cost_bt, what = "fills") |>
  select(ts_utc, side, qty, price, fee)
```

    # A tibble: 2 x 5
      ts_utc     side    qty price   fee
      <date>     <chr> <dbl> <dbl> <dbl>
    1 2018-01-04 BUY      10  54.7     1
    2 2018-01-09 SELL     10  52.9     1

## Final-Bar Targets Cannot Fill

A target change on the final pulse is valid strategy output, but there
is no later bar where ledgr can simulate the next-open fill. ledgr warns
and leaves the ledger unchanged for that final target change. See
`?LEDGR_LAST_BAR_NO_FILL` for the stable warning-code contract.

``` r
final_bar_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  if (ledgr_utc(ctx$ts_utc) == ledgr_utc("2018-01-10")) {
    targets["DEMO_01"] <- demo_qty
  }
  targets
}

last_bar_warning <- FALSE
final_bar_bt <- withCallingHandlers(
  ledgr_backtest(
    data = bars,
    strategy = final_bar_strategy,
    initial_cash = 10000,
    run_id = "execution_final_bar_warning"
  ),
  warning = function(w) {
    if (grepl("LEDGR_LAST_BAR_NO_FILL", conditionMessage(w), fixed = TRUE)) {
      last_bar_warning <<- TRUE
      invokeRestart("muffleWarning")
    }
  }
)

last_bar_warning
```

    [1] TRUE

``` r
ledgr_results(final_bar_bt, what = "fills")
```

    # A tibble: 0 x 9
    # i 9 variables: event_seq <int>, ts_utc <date>, instrument_id <chr>, side <chr>,
    #   qty <dbl>, price <dbl>, fee <dbl>, realized_pnl <dbl>, action <chr>

If that final target matters, extend the snapshot by one executable bar
and run again. Do not suppress the warning and treat the missing fill as
a completed trade.

## Warmup Gates Belong In The Strategy

> [!NOTE]
>
> ### Definition
>
> Warmup is the early part of a feature series where an indicator has
> not yet seen enough history to produce a usable value. For example, a
> 20-bar moving average is not usable on the first bar of a snapshot.

Feature warmup is not an execution rule. The strategy decides whether a
feature vector is usable. Different strategies may want different warmup
behavior, so ledgr exposes warmup state instead of silently imposing a
trading rule. For active aliases, `passed_warmup()` is the standard
guard:

``` r
values <- ctx$features("DEMO_01")
targets <- ctx$flat()

if (passed_warmup(values) && values[["fast"]] > values[["slow"]]) {
  targets["DEMO_01"] <- params$qty
}

targets
```

`passed_warmup()` keeps the rule inactive while mapped features are
still ordinary early `NA`. A typo in an alias or a feature that can
never become usable is a different problem; ledgr should fail or report
diagnostics rather than silently treating missing features as no signal.

## Zero Fills And Zero Trades Mean Different Things

Zero fills means no execution occurred. Non-empty fills with zero trades
means the run opened or adjusted a position but did not close a round
trip inside the sample.

``` r
ledgr_results(bt, what = "fills") |>
  select(ts_utc, side, qty, price)
```

    # A tibble: 2 x 4
      ts_utc     side    qty price
      <date>     <chr> <dbl> <dbl>
    1 2018-01-04 BUY      10  54.7
    2 2018-01-09 SELL     10  52.9

``` r
ledgr_results(bt, what = "trades") |>
  select(any_of(c("entry_ts_utc", "exit_ts_utc", "entry_ts", "exit_ts", "qty", "pnl", "realized_pnl")))
```

    # A tibble: 1 x 2
        qty realized_pnl
      <dbl>        <dbl>
    1    10        -17.3

Start with fills when debugging execution. Trades are derived from
filled round trips, not from target changes.

## Where Next

- For strategy authoring and `passed_warmup()` patterns, read
  `vignette("strategy-development", package = "ledgr")`.
- For feature maps and warmup diagnostics, read
  `vignette("indicators", package = "ledgr")`.
- For ledger, fills, trades, equity, and metrics, read
  `vignette("metrics-and-accounting", package = "ledgr")`.
- For candidate sweeps and promotion context, read
  `vignette("sweeps", package = "ledgr")`.
