# How Targets Become Fills


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

You returned a target of 10 units. When does it trade, and at what
price? A backtest that fills it on the same bar you decided on can
quietly overstate your results.

This article shows how ledgr turns a target into a fill. You emit
holdings, not orders, and they fill at the next bar’s open, not the bar
you decided on. That one-bar rule is the no-lookahead boundary: it keeps
the simulation from trading on information it could not have had at
decision time.

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

``` r
library(ledgr)
library(dplyr)

data("ledgr_demo_bars", package = "ledgr")
```

## The Lie A Backtest Can Tell You

Here is a momentum rule: hold one unit whenever a bar closes above its
open. The decision uses bar `t`’s close, which ledgr treats as
pulse-known information. The only open question is *when the resulting
position fills*.

Compare two fill rules on the same signal and the same bars. One fills
at the open of the bar you decided from; the other fills at the next
bar’s open, the way ledgr does.

``` r
window <- ledgr_demo_bars |>
  filter(
    instrument_id == "DEMO_01",
    between(ts_utc, ledgr_utc("2019-01-01"), ledgr_utc("2019-06-30"))
  )

timing <- window |>
  arrange(ts_utc) |>
  mutate(
    closed_up = close > open,
    fill_same_bar = (close - open) / open,
    fill_next_open = (lead(close) - lead(open)) / lead(open)
  ) |>
  filter(closed_up, !is.na(fill_next_open))

tibble::tibble(
  fill_rule = c("same bar you decided on", "next open (what ledgr does)"),
  mean_return = c(mean(timing$fill_same_bar), mean(timing$fill_next_open)),
  win_rate = c(mean(timing$fill_same_bar > 0), mean(timing$fill_next_open > 0))
)
```

    # A tibble: 2 x 3
      fill_rule                   mean_return win_rate
      <chr>                             <dbl>    <dbl>
    1 same bar you decided on         0.00997    1
    2 next open (what ledgr does)     0.00155    0.559

Filling at the bar you decided from wins **100 percent** of the time.
That is not skill – you only ever bought bars you already knew had
closed up, so the profit was decided before the trade. A 100 percent win
rate is the signature of lookahead. The honest rule, next-open, wins
about half the time, because the next bar does not know what the last
one did.

ledgr does not allow this: a target decided on bar `t` always fills at
the open of bar `t + 1`. The rest of this article shows that rule in the
ledger.

## Targets Are Holdings, Not Orders

Returning `10` means “I want to hold 10 units”, not “buy 10 units every
bar”. If the current position already equals the target, there is no new
fill – only *changes* fill.

``` r
bars <- ledgr_demo_bars |>
  filter(
    instrument_id == "DEMO_01",
    between(ts_utc, ledgr_utc("2019-01-07"), ledgr_utc("2019-01-15"))
  )

hold_then_flat <- function(ctx, params) {
  targets <- ctx$flat()
  ts <- ledgr_utc(ctx$ts_utc)
  if (ts >= ledgr_utc("2019-01-08") && ts < ledgr_utc("2019-01-10")) {
    targets["DEMO_01"] <- 10
  }
  targets
}

bt <- ledgr_backtest(
  data = bars,
  strategy = hold_then_flat,
  initial_cash = 10000,
  run_id = "how_targets_holdings",
  cost_model = ledgr_cost_zero()
)

ledgr_results(bt, what = "fills") |>
  select(ts_utc, side, qty, price)
```

    # A tibble: 2 x 4
      ts_utc     side    qty price
      <date>     <chr> <dbl> <dbl>
    1 2019-01-09 BUY      10  88.4
    2 2019-01-11 SELL     10  88.8

The strategy asked to hold the position across two bars, but you see
only two fills: one to open the position and one to close it. The bars
in between asked for the same target, so nothing executed.

## The Fill Is At The Next Open

Look at the dates. The strategy set the target on January 8, using that
bar’s close. ledgr filled the buy at January 9’s open (88.4) – the next
bar – not at January 8’s close. When the target went flat on January 10,
the sell filled at January 11’s open.

The price you decide on is never the price you get. That is why a
strategy should read `ctx$close(id)` and feature values as pulse-known
*information*, not as executable prices. Each fill also carries a fee
set by the cost model; this article keeps costs at zero to isolate
timing (see `vignette("risk-and-cost", package = "ledgr")`).

## A Target On The Final Bar Cannot Fill

A target change on the final pulse is valid strategy output, but there
is no later bar where ledgr can simulate the next-open fill. ledgr warns
and leaves the ledger unchanged for that final target change.

``` r
final_bar_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  if (ledgr_utc(ctx$ts_utc) == ledgr_utc("2019-01-15")) {
    targets["DEMO_01"] <- 10
  }
  targets
}

final_bt <- ledgr_backtest(
  data = bars,
  strategy = final_bar_strategy,
  initial_cash = 10000,
  run_id = "how_targets_final_bar",
  cost_model = ledgr_cost_zero()
)

nrow(ledgr_results(final_bt, what = "fills"))
```

    [1] 0

The warning carries the stable code `LEDGR_LAST_BAR_NO_FILL` (see
`?LEDGR_LAST_BAR_NO_FILL`). If that final target matters, extend the
snapshot by one executable bar and run again. Do not suppress the
warning and treat the missing fill as a completed trade.

## Zero Fills And Zero Trades Are Different

Zero fills means no execution occurred. Non-empty fills with zero trades
means the run opened or adjusted a position but did not close a round
trip inside the sample.

``` r
ledgr_results(bt, what = "trades") |>
  select(ts_utc, qty, realized_pnl)
```

    # A tibble: 1 x 3
      ts_utc       qty realized_pnl
      <date>     <dbl>        <dbl>
    1 2019-01-11    10         4.10

Start with fills when you debug execution. Trades are derived from
filled round trips, not from target changes: a trade row is the
close-action fill row that realizes PnL. ledgr does not currently expose
a paired entry/exit trade table.

## Try It

<div class="ledgr-callout ledgr-callout-tip">

**Try it**

In the momentum comparison above, replace `lead(close)` and `lead(open)`
with a two-bar lead (`lead(close, 2)`, `lead(open, 2)`). Does the
next-open win rate stay near a coin flip? Then change the signal to
`close < open` (hold on down bars). Does the same-bar rule still win 100
percent of the time, and why?

</div>

## Where Next

- For warmup gating, feature maps, and `ledgr_passed_warmup()`, read
  `vignette("indicators", package = "ledgr")` and
  `vignette("strategy-development", package = "ledgr")`.
- For the cost and risk policy applied at the fill, read
  `vignette("risk-and-cost", package = "ledgr")`.
- For ledger, fills, trades, equity, and metrics, read
  `vignette("metrics-and-accounting", package = "ledgr")`.
- For why same-bar information is unsafe to trade on, read
  `vignette("leakage", package = "ledgr")`.
