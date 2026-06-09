# Metrics And Accounting


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

ledgr records a backtest as accounting evidence first and summary
metrics second.

The useful reading order is:

<div class="ledgr-diagram ledgr-accounting-hierarchy">

``` mermaid

flowchart TB
  ledger["ledger events<br/>source of truth"]
  fills["fills<br/>execution rows"]
  trades["trades<br/>closed round trips"]
  equity["equity rows<br/>portfolio value"]
  metrics["summary metrics<br/>formulas over results"]

  ledger --> fills
  fills --> trades
  ledger --> equity
  trades --> metrics
  equity --> metrics
```

</div>

1.  ledger events say what actually filled;
2.  fills are execution rows derived from those events;
3.  trades are only the fill rows that close quantity;
4.  equity rows value the portfolio through time;
5.  summary metrics are formulas over those public result tables.

That order matters. A strategy can open a position without closing it.
That run has fills and equity exposure, but zero closed trades. In that
case `n_trades = 0` and `win_rate = NA` are correct, not missing data.

## Prerequisites

``` r
library(ledgr)
library(dplyr)
library(tibble)
```

## Inspection Surfaces

Use the narrowest inspection surface that answers the question:

| Question | Public surface | Shape |
|----|----|----|
| What happened at a glance? | `print(bt)` | printed run header with final equity |
| What are the standard metrics? | `summary(bt)` | printed interpretation; returns `bt` invisibly |
| What metric values can code consume? | `ledgr_compute_metrics(bt)` | list-like `ledgr_metrics` object with raw numeric values |
| What rows value the portfolio? | `ledgr_results(bt, what = "equity")` | classed tibble |
| What executed? | `ledgr_results(bt, what = "fills")` | classed tibble |
| What closed quantity? | `ledgr_results(bt, what = "trades")` | classed tibble |
| What did the event ledger record? | `ledgr_results(bt, what = "ledger")` | classed tibble |
| How do stored runs compare? | `ledgr_compare_runs(snapshot, run_ids = ...)` | classed comparison tibble |
| What did a sweep candidate summarize? | `ledgr_sweep()` result rows | classed sweep tibble |
| What context was stored by promotion? | `ledgr_promotion_context(bt)` or `ledgr_run_promotion_context()` | nested list |

The result-table helpers return structured objects. Their print methods
may format timestamps for readability, but `as_tibble()` gives raw
columns for programmatic use. The stable programming contract is the
column meaning, not the number of rows: a valid run can have zero fills,
zero closed trades, or a final open position.

Two things are not in the standard result tables.

`final_equity` is not a field in the `ledgr_compute_metrics()` list.
Read it from the last equity row, from `print(bt)`, from comparison
rows, or from sweep rows.

There is no committed `ledgr_results(bt, what = "features")` table.
Feature values are inspected at pulse time with `ledgr_pulse_snapshot()`
or through sweep/precompute provenance, not through a persisted
feature-result table accessor.

Metric assumptions are inspectable through `ledgr_metric_context()`. Use
it on a backtest, `ledgr_metrics` object, comparison table, sweep result
table, or promotion context to see the risk-free-rate and annualization
context that produced that surface.

## A Tiny Run

Use a five-bar in-memory fixture so the accounting can be checked by
hand. OHLC values are equal per bar so the example focuses on accounting
arithmetic; real bars use the same code with ordinary intra-bar
movement. This article uses `ledgr_backtest()` as a compact fixture
helper for accounting examples. The canonical research workflow remains:
snapshot -\> `ledgr_experiment()` -\> `ledgr_run()`.

``` r
bars <- data.frame(
  ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:4,
  instrument_id = "AAA",
  open = c(100, 101, 105, 106, 106),
  high = c(100, 101, 105, 106, 106),
  low = c(100, 101, 105, 106, 106),
  close = c(100, 101, 105, 106, 106),
  volume = 1
)

one_day_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  if (ledgr_utc(ctx$ts_utc) == ledgr_utc("2020-01-01")) {
    targets["AAA"] <- 1
  }
  targets
}

bt <- ledgr_backtest(
  data = bars,
  strategy = one_day_strategy,
  initial_cash = 1000,
  run_id = "accounting_example",
  cost_model = ledgr_cost_zero()
)
```

The strategy asks to hold one share on the first pulse and then returns
to flat. In these examples, decisions fill at the next open. The buy
therefore fills on the second bar, and the exit fills on the third bar.

## Timing, Spread, And Fees

Timing and cost are separate execution steps. `ledgr_timing_next_open()`
decides where a target change can fill: the next available open after
the strategy decision. A cost model then resolves the proposed fill
price and explicit fee. Strategies do not receive cost state, and cost
models do not change side, quantity, instrument, or execution timestamp.

`ledgr_cost_spread_bps()` uses a quoted bid/ask-spread convention. A buy
crosses half the quoted spread above the reference open:
`open * (1 + spread_bps / 20000)`. A sell crosses half below it:
`open * (1 - spread_bps / 20000)`. For the same reference price, a
buy/sell round trip therefore crosses approximately `spread_bps` basis
points before explicit fees.

``` r
spread_bps <- 25
reference_price <- 100
buy_cross <- reference_price * (1 + spread_bps / 20000)
sell_cross <- reference_price * (1 - spread_bps / 20000)
round_trip_bps <- (buy_cross - sell_cross) / reference_price * 10000
round(round_trip_bps, 6)
#> [1] 25
```

Price transforms and explicit fees are different.
`ledgr_cost_spread_bps()` changes the fill price.
`ledgr_cost_fixed_fee()` and `ledgr_cost_notional_bps_fee()` add values
to the fill `fee` column after any price transforms have resolved.

Target risk, timing, and cost are separate layers. A `risk_chain` can
transform validated strategy target quantities before fill proposals
exist. The timing model decides which bar is used for execution. The
cost model then adjusts price and fee on the accepted fill proposal; it
does not decide whether a target is affordable or liquid.

``` r
example_cost_model <- ledgr_cost_chain(
  ledgr_cost_spread_bps(25),
  ledgr_cost_fixed_fee(0.50),
  ledgr_cost_notional_bps_fee(1)
)

ledgr_cost_steps(example_cost_model)
ledgr_cost_describe(example_cost_model)
```

<div class="ledgr-callout ledgr-callout-important">

**What costs do not model**

Cost models are deterministic research assumptions over accepted fill
proposals. They do not implement liquidity or capacity limits, financing,
transaction-cost analysis, taxes, OMS lifecycle behavior, or broker
reconciliation. Those are separate future layers, not hidden behavior in
the cost API.

</div>

## Ledger Events

> [!NOTE]
>
> ### Definition
>
> A ledger event is the append-only accounting record written when
> execution changes cash, positions, or run state. Fills, trades,
> equity, and metrics are derived views over ledger-backed evidence.

The ledger is the most literal view. The friendlier result tables below
are derived from these events.

``` r
ledger <- ledgr_results(bt, what = "ledger")
ledger
#> # A tibble: 2 x 11
#>   event_id    run_id ts_utc     event_type instrument_id side    qty price   fee meta_json
#>   <chr>       <chr>  <date>     <chr>      <chr>         <chr> <dbl> <dbl> <dbl> <chr>
#> 1 accounting~ accou~ 2020-01-02 FILL       AAA           BUY       1   101     0 "{\"cash~
#> 2 accounting~ accou~ 2020-01-03 FILL       AAA           SELL      1   105     0 "{\"cash~
#> # i 1 more variable: event_seq <int>
```

## Fills And Trades

> [!NOTE]
>
> ### Definition
>
> A fill is an execution row: direction, quantity, price, fee, and
> action. A trade is the subset of fill evidence that closes quantity
> and realizes P&L.

`what = "fills"` returns execution fill rows. Opening and closing fills
both appear here.

``` r
fills <- ledgr_results(bt, what = "fills")
fills
#> # A tibble: 2 x 9
#>   event_seq ts_utc     instrument_id side    qty price   fee realized_pnl action
#>       <int> <date>     <chr>         <chr> <dbl> <dbl> <dbl>        <dbl> <chr>
#> 1         1 2020-01-02 AAA           BUY       1   101     0            0 OPEN
#> 2         2 2020-01-03 AAA           SELL      1   105     0            4 CLOSE
```

The important columns are:

| Column         | Meaning                                      |
|----------------|----------------------------------------------|
| `side`         | execution direction, such as `BUY` or `SELL` |
| `qty`          | absolute fill quantity                       |
| `price`        | fill price                                   |
| `fee`          | execution fee charged on the fill            |
| `action`       | whether the fill opened or closed quantity   |
| `realized_pnl` | profit or loss booked by closing quantity    |

`what = "trades"` keeps only closed trade rows. That is the table used
by `n_trades`, `win_rate`, and `avg_trade`.

``` r
trades <- ledgr_results(bt, what = "trades")
trades
#> # A tibble: 1 x 9
#>   event_seq ts_utc     instrument_id side    qty price   fee realized_pnl action
#>       <int> <date>     <chr>         <chr> <dbl> <dbl> <dbl>        <dbl> <chr>
#> 1         2 2020-01-03 AAA           SELL      1   105     0            4 CLOSE
```

This run has two fill rows but one closed trade row. Counting fills as
trades would double-count the round trip.

## Equity Rows

> [!NOTE]
>
> ### Definition
>
> An equity row values the portfolio at one timestamp. It combines cash,
> current position value, and total equity, including open-position
> exposure.

The equity curve records portfolio state through time.

``` r
equity <- ledgr_results(bt, what = "equity")
equity
#> # A tibble: 5 x 6
#>   ts_utc     equity  cash positions_value running_max drawdown
#>   <date>      <dbl> <dbl>           <dbl>       <dbl>    <dbl>
#> 1 2020-01-01   1000  1000               0        1000        0
#> 2 2020-01-02   1000   899             101        1000        0
#> 3 2020-01-03   1004  1004               0        1004        0
#> 4 2020-01-04   1004  1004               0        1004        0
#> 5 2020-01-05   1004  1004               0        1004        0
```

Open positions affect `positions_value` and therefore equity even before
any trade closes. Realized P&L belongs to closed quantity; open-position
gains and losses stay in the equity curve until a closing fill realizes
them.

## Recompute The Metrics

The summary metrics can be recomputed from public result tables.

``` r
equity_values <- equity$equity
period_returns <- equity_values[-1] / equity_values[-length(equity_values)] - 1
bars_per_year <- 252
rf_annual <- 0
rf_period_return <- (1 + rf_annual)^(1 / bars_per_year) - 1
excess_returns <- period_returns - rf_period_return

metric_check <- tibble(
  total_return =
    equity_values[length(equity_values)] / equity_values[1] - 1,
  annualized_return =
    (1 + total_return)^(
      1 / ((length(equity_values) - 1) / bars_per_year)
    ) - 1,
  volatility =
    sd(period_returns) * sqrt(bars_per_year),
  sharpe_ratio =
    mean(excess_returns) / sd(excess_returns) * sqrt(bars_per_year),
  max_drawdown =
    min(equity_values / cummax(equity_values) - 1),
  n_trades =
    nrow(trades),
  win_rate =
    if (nrow(trades) > 0) mean(trades$realized_pnl > 0) else NA_real_,
  avg_trade =
    if (nrow(trades) > 0) mean(trades$realized_pnl) else NA_real_,
  time_in_market =
    mean(abs(equity$positions_value) > 1e-6)
)

metric_check
#> # A tibble: 1 x 9
#>   total_return annualized_return volatility sharpe_ratio max_drawdown n_trades win_rate
#>          <dbl>             <dbl>      <dbl>        <dbl>        <dbl>    <int>    <dbl>
#> 1      0.00400             0.286     0.0317         7.94            0        1        1
#> # i 2 more variables: avg_trade <dbl>, time_in_market <dbl>
```

Those are the same definitions used by `summary(bt)` and
`ledgr_compute_metrics(bt)`. The first public equity row is the initial
equity for return calculations. Max drawdown is the maximum
peak-to-trough decline in the public equity rows. Time in market is the
share of equity rows with absolute `positions_value > 1e-6`.

`ledgr_results()` returns persisted result tables: `equity`, `fills`,
`trades`, or `ledger`. There is no `what = "metrics"` result table. Use
`summary(bt)` for printed interpretation, or `ledgr_compute_metrics(bt)`
when you need the named metric values in code.

This small example uses `bars_per_year <- 252` because the bars are
daily. ledgr detects bar frequency for `ledgr_compute_metrics()` and
snaps common cadences, such as daily and weekly, to standard
annualization constants. Use the detected value if you need an external
calculation to match ledgr exactly on non-daily data.

> [!TIP]
>
> ### Try it
>
> Change `bars_per_year` in the recompute chunk from `252` to `365`.
> Which metrics change? Why does `total_return` stay the same?

## Metric Context

Metric assumptions now live in a `metric_context`. The default context
is US equity daily: zero annual risk-free rate and `252 * 1` periods per
year. Use market templates for common assumptions:

> [!NOTE]
>
> ### Definition
>
> A metric context is the assumption object behind metrics: risk-free
> rate, calendar, annualization, and reserved provider slots. It makes
> metric assumptions inspectable instead of hidden in summary output.

### Common Contexts

``` r
ledgr_metric_us_equity()
#> ledgr_metric_context
#> ====================
#> Version:        1
#> Risk-free rate: 0.0000%
#> Calendar:       US equity daily (252 days/year * 1 bars/day = 252 bars/year)
#> Hash:           1487b5dc681c0d58b0a4cf3ecd59421e51cd830d628be466949d55b02b788c00
ledgr_metric_us_equity(risk_free_rate = 0.04)
#> ledgr_metric_context
#> ====================
#> Version:        1
#> Risk-free rate: 4.0000%
#> Calendar:       US equity daily (252 days/year * 1 bars/day = 252 bars/year)
#> Hash:           d711f43b0bf4c715224a505d9311df44fef2657f6d2817cd11344e63db70ccd7
ledgr_metric_us_equity(
  bars_per_day = 390L,
  risk_free_rate = ledgr_risk_free_rate(0.04, label = "policy rate")
)
#> ledgr_metric_context
#> ====================
#> Version:        1
#> Risk-free rate: 4.0000%
#> Calendar:       US equity custom bars (252 days/year * 390 bars/day = 98,280 bars/year)
#> Hash:           df3891aee6212ecb6925fb9facdee28b929cc04c448758931767199ef613e1cd
ledgr_metric_crypto()
#> ledgr_metric_context
#> ====================
#> Version:        1
#> Risk-free rate: 0.0000%
#> Calendar:       crypto daily (365 days/year * 1 bars/day = 365 bars/year)
#> Hash:           291e10efec438bd4d550d936adc7441853d4be5d56d48e1d561e72835fc1bfed
```

A scalar shorthand is accepted when only the annual risk-free rate
changes:

``` r
ledgr_metric_context(0.04)
#> ledgr_metric_context
#> ====================
#> Version:        1
#> Risk-free rate: 4.0000%
#> Calendar:       US equity daily (252 days/year * 1 bars/day = 252 bars/year)
#> Hash:           d711f43b0bf4c715224a505d9311df44fef2657f6d2817cd11344e63db70ccd7
```

Use an explicit context when the calendar matters:

``` r
intraday_context <- ledgr_metric_context(
  calendar = ledgr_calendar_us_equity(bars_per_day = 390L),
  risk_free_rate = ledgr_risk_free_rate(0.04, label = "manual assumption")
)
```

The full constructor fields are `risk_free_rate`, `calendar`,
`benchmark`, `market_factor`, and `mar`. The provider fields
`benchmark`, `market_factor`, and `mar` are reserved and must be `NULL`;
they exist so future benchmark and provider designs have an explicit
home instead of changing metric semantics later.

Intraday work should set `calendar` explicitly. For example, US equity
minute bars use `ledgr_calendar_us_equity(bars_per_day = 390L)`. ledgr
does not infer that policy from ticker symbols, file names, or provider
names.

### Stored Context vs Sensitivity Overrides

`summary(bt)` and `ledgr_compute_metrics(bt)` use the metric context
stored with the committed run. Call-time overrides are sensitivity
checks; they do not mutate the run:

``` r
stored_run_context <- ledgr_metric_context(bt)
stored_metrics <- ledgr_compute_metrics(bt)
zero_rf_metrics <- ledgr_compute_metrics(bt, risk_free_rate = 0)

ledgr_metric_context(stored_metrics)
#> ledgr_metric_context
#> ====================
#> Version:        1
#> Risk-free rate: 0.0000%
#> Calendar:       US equity daily (252 days/year * 1 bars/day = 252 bars/year)
#> Hash:           1487b5dc681c0d58b0a4cf3ecd59421e51cd830d628be466949d55b02b788c00
ledgr_metric_context(zero_rf_metrics)
#> ledgr_metric_context
#> ====================
#> Version:        1
#> Risk-free rate: 0.0000%
#> Calendar:       US equity daily (252 days/year * 1 bars/day = 252 bars/year)
#> Hash:           1487b5dc681c0d58b0a4cf3ecd59421e51cd830d628be466949d55b02b788c00
identical( # confirm the override did not mutate the stored context on `bt`
  ledgr_metric_context_hash(stored_run_context),
  ledgr_metric_context_hash(ledgr_metric_context(bt))
)
#> [1] TRUE
```

Metric-context hashes include the metric-context version, annual
risk-free rate, risk-free source, risk-free `as_of`, and calendar
annualization and source fields. Human display labels are stored for
inspection but do not change the hash. If the print output is too
compact for a report, inspect the nested object directly:

``` r
context <- ledgr_metric_context(bt)
context$risk_free_rate$label
context$risk_free_rate$source
context$risk_free_rate$as_of
ledgr_metric_context_hash(context)
```

### Comparison, Sweep, And Promotion Contexts

The following snippets use objects from the experiment-store and sweeps
workflows. They show where metric context is carried, not a complete
runnable example.

`ledgr_compare_runs()` has exactly one comparison context per table. The
snapshot-first form uses the default context unless you pass one
explicitly:

``` r
comparison <- ledgr_compare_runs(
  snapshot,
  run_ids = c("trend_qty_5", "trend_qty_15"),
  metric_context = ledgr_metric_context(exp)
)

ledgr_metric_context(comparison)
```

Sweep result tables also have exactly one metric context. Promotion
context keeps that source sweep context separate from the committed
run’s own context:

``` r
results <- ledgr_sweep(train_exp, grid)
candidate <- ledgr_candidate(results, 1)
test_run <- ledgr_promote(test_exp, candidate, require_same_snapshot = FALSE)

ledgr_metric_context(results)
ledgr_metric_context(ledgr_promotion_context(test_run))
ledgr_metric_context(test_run)
```

This distinction matters for train/test work: the source sweep context
explains how a candidate was ranked, while the committed run context
explains the default analysis assumptions stored with the promoted run.

## Risk Metric Contract

The standard metric contract includes `sharpe_ratio` as ledgr’s first
risk-adjusted metric. It is computed from the same public equity rows as
volatility, not from hidden runner state and not from an external
metrics package.

The return series is still the adjacent public equity-row return:

``` text
equity_return[t] = equity[t] / equity[t - 1] - 1
```

Sharpe-style metrics use period excess returns:

``` text
excess_return[t] = equity_return[t] - rf_period_return[t]
sharpe_ratio = mean(excess_return) / sd(excess_return) * sqrt(bars_per_year)
```

The first risk-free-rate provider is a scalar annual rate expressed as a
decimal, so `0.02` means two percent per year. The default is `0`. ledgr
converts that scalar annual rate to a per-period return with the same
`bars_per_year` used for annualized return and volatility:

``` text
rf_period_return = (1 + rf_annual)^(1 / bars_per_year) - 1
```

Time-varying risk-free-rate series and real data providers such as FRED,
Treasury, ECB, or central-bank adapters are deferred to later
metric-context provider work. Future providers must feed the same
pulse-aligned `rf_period_return` vector into the formula above; they
must not create a separate Sharpe formula branch.

Sharpe returns `NA_real_` for short samples, flat equity, or near-zero
volatility; see `?ledgr_compute_metrics` for the exact edge-case rules.

Other risk-adjusted or benchmark-relative metrics are deferred to v0.2.x
benchmark context work: Sortino, Calmar, Omega, information ratio,
alpha/beta, benchmark-relative metrics, VaR, and tail-risk metrics.

``` r
summary(bt)
#> ledgr Backtest Summary
#> ======================
#>
#> Performance Metrics:
#>   Total Return:        0.40%
#>   Annualized Return:   28.59%
#>   Max Drawdown:        0.00%
#>
#> Risk Metrics:
#>   Risk-Free Rate:      0.00% annual
#>   Annualization:       252 periods/year (US equity daily)
#>   Volatility (annual): 3.17%
#>   Sharpe Ratio:        7.937
#>
#> Trade Statistics:
#>   Total Trades:        1
#>   Win Rate:            100.00%
#>   Avg Trade:           $4.00
#>
#> Exposure:
#>   Time in Market:      20.00%
```

`summary(bt)` is a print-oriented view. It returns the backtest handle
invisibly, not a metrics object. Use `ledgr_compute_metrics()` for
scripted workflows:

``` r
metrics <- ledgr_compute_metrics(bt)
metrics[c("total_return", "sharpe_ratio", "n_trades", "win_rate")]
#> $total_return
#> [1] 0.004
#>
#> $sharpe_ratio
#> [1] 7.937254
#>
#> $n_trades
#> [1] 1
#>
#> $win_rate
#> [1] 1
ledgr_metric_context(metrics)
#> ledgr_metric_context
#> ====================
#> Version:        1
#> Risk-free rate: 0.0000%
#> Calendar:       US equity daily (252 days/year * 1 bars/day = 252 bars/year)
#> Hash:           1487b5dc681c0d58b0a4cf3ecd59421e51cd830d628be466949d55b02b788c00
```

The raw metrics object keeps metric-kernel attributes for provenance.
Those attributes are part of the programmatic object, not the printed
metric table. Use named fields such as `metrics$sharpe_ratio` or the
subset above when you need a compact report.

`ledgr_compare_runs()` is also programmatic: it returns a tibble-like
`ledgr_comparison` object with raw numeric metric columns for filtering
and ranking. Its print method only curates the displayed columns.
Comparison metrics are recomputed from stored equity and fill tables and
use the same closed-trade semantics as `ledgr_compute_metrics()`.

For reports, convert the comparison object and keep the raw numeric
columns:

``` r
comparison |>
  as.data.frame() |>
  select(run_id, final_equity, total_return, sharpe_ratio, max_drawdown)
```

## Zero Trades Can Be Correct

A flat strategy produces no fills and no closed trades. The result
tables still keep their schemas, so downstream code can rely on the same
column names.

``` r
flat_strategy <- function(ctx, params) ctx$flat()

flat_bt <- ledgr_backtest(
  data = bars,
  strategy = flat_strategy,
  initial_cash = 1000,
  run_id = "flat_accounting_example",
  cost_model = ledgr_cost_zero()
)

ledgr_results(flat_bt, what = "fills")
#> # A tibble: 0 x 9
#> # i 9 variables: event_seq <int>, ts_utc <date>, instrument_id <chr>, side <chr>,
#> #   qty <dbl>, price <dbl>, fee <dbl>, realized_pnl <dbl>, action <chr>
ledgr_results(flat_bt, what = "trades")
#> # A tibble: 0 x 9
#> # i 9 variables: event_seq <int>, ts_utc <date>, instrument_id <chr>, side <chr>,
#> #   qty <dbl>, price <dbl>, fee <dbl>, realized_pnl <dbl>, action <chr>
ledgr_compute_metrics(flat_bt)[c("n_trades", "win_rate", "avg_trade")]
#> $n_trades
#> [1] 0
#>
#> $win_rate
#> [1] NA
#>
#> $avg_trade
#> [1] NA
```

`win_rate` and `avg_trade` are `NA` because there are no closed trade
rows to evaluate. That is different from a zero percent win rate, which
would mean there were trades and none of them were profitable.

## Open Positions And Final-Bar Targets

An open-only run is also valid. It has an opening fill and equity
exposure, but no closed trade rows. The unrealized result belongs in
equity, not in `realized_pnl`.

``` r
open_only_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  targets["AAA"] <- 1
  targets
}

open_bt <- ledgr_backtest(
  data = bars,
  strategy = open_only_strategy,
  initial_cash = 1000,
  run_id = "open_accounting_example",
  cost_model = ledgr_cost_zero()
)

ledgr_results(open_bt, what = "fills")
#> # A tibble: 1 x 9
#>   event_seq ts_utc     instrument_id side    qty price   fee realized_pnl action
#>       <int> <date>     <chr>         <chr> <dbl> <dbl> <dbl>        <dbl> <chr>
#> 1         1 2020-01-02 AAA           BUY       1   101     0            0 OPEN
ledgr_results(open_bt, what = "trades")
#> # A tibble: 0 x 9
#> # i 9 variables: event_seq <int>, ts_utc <date>, instrument_id <chr>, side <chr>,
#> #   qty <dbl>, price <dbl>, fee <dbl>, realized_pnl <dbl>, action <chr>
ledgr_compute_metrics(open_bt)[c("n_trades", "win_rate", "avg_trade")]
#> $n_trades
#> [1] 0
#>
#> $win_rate
#> [1] NA
#>
#> $avg_trade
#> [1] NA
```

A final-bar target under a next-open fill model can also be valid
research input while producing no fill. There is no later bar available
for execution, so ledgr warns and leaves the ledger unchanged for that
last target change.

``` r
final_bar_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  if (ledgr_utc(ctx$ts_utc) == ledgr_utc("2020-01-05")) {
    targets["AAA"] <- 1
  }
  targets
}

final_bar_bt <- ledgr_backtest(
  data = bars,
  strategy = final_bar_strategy,
  initial_cash = 1000,
  run_id = "final_bar_accounting_example",
  cost_model = ledgr_cost_zero()
)

ledgr_results(final_bar_bt, what = "fills")
#> # A tibble: 0 x 9
#> # i 9 variables: event_seq <int>, ts_utc <date>, instrument_id <chr>, side <chr>,
#> #   qty <dbl>, price <dbl>, fee <dbl>, realized_pnl <dbl>, action <chr>
```

## Diagnose A Successful Run With Zero Trades

A completed run with zero trades is not automatically wrong. It means
ledgr accepted the strategy outputs and the ledger reached the end of
the sample, but no closed round trips were recorded.

Use this checklist before changing the strategy:

1.  Start with `summary(bt)`. If `Total Trades` is zero, `win_rate` and
    `avg_trade` should be `NA`, not zero. If a registered feature can
    never become usable because the sample is too short, `summary(bt)`
    also prints a `Warmup Diagnostics` note with the feature ID,
    instrument ID, required bars, and available bars.
2.  Inspect `ledgr_results(bt, what = "fills")`. Empty fills mean
    nothing ever executed. Non-empty fills with empty trades mean
    positions opened but did not close.
3.  Confirm the feature IDs with `ledgr_feature_id(features)`. A helper
    such as `signal_return(ctx, lookback = 60)` reads `return_60`; that
    indicator must be registered before the run.
4.  Compare feature contracts with sample length before assuming the
    strategy is broken. `ledgr_feature_contracts(features)` shows
    `requires_bars` and `stable_after`. If an instrument has fewer
    available bars than a feature’s `requires_bars`, that feature cannot
    become usable for that instrument.
5.  Inspect a late pulse with `ledgr_pulse_snapshot()`. If the feature
    is still `NA` for every instrument near the end of the sample, the
    issue is no longer ordinary early warmup. Check the lookback length,
    sample length, universe, and feature registration.
6.  If the helper pipeline returns a `ledgr_empty_selection` on a late
    diagnostic pulse, inspect the signal values directly. Ordinary early
    warmup should have passed by then; a late all-missing signal usually
    points to sample length, universe, or feature-registration issues.

Timestamp checks should compare normalized UTC values, not local string
representations:

``` r
target_ts <- ledgr_utc("2020-01-05T00:00:00Z")
ledgr_utc(ctx$ts_utc) == target_ts

intraday_time <- format(ledgr_utc(ctx$ts_utc), "%H:%M:%S", tz = "UTC")
intraday_time >= "14:30:00" && intraday_time <= "21:00:00"
```

If fills are empty, distinguish zero signals from zero sizing. In your
own run, use the same snapshot, universe, timestamp, features, strategy,
and params you are debugging:

``` r
pulse <- ledgr_pulse_snapshot(
  snapshot,
  universe = ...,
  ts_utc = ...,
  features = features
)
target <- strategy(pulse, params)
target
all(target == 0)
```

Custom fill-model contract errors are different from zero-trade
outcomes; see the fill-model reference documentation for the required
fill fields.

### Four Warmup-Adjacent Cases

Warmup is per instrument. One instrument can have a usable value while
another is still `NA` because it has fewer bars or a different data
history.

Ordinary feature warmup is local to the beginning of each instrument’s
usable sample. A known feature is `NA` for early pulses, then becomes
usable once the feature contract has enough bars.

Impossible warmup is different: every value for an instrument/feature
remains `NA` because the instrument never reaches the feature contract.
That is the case reported by the `Warmup Diagnostics` note in
`summary(bt)`.

Current-bar absence is a third failure mode. If ledgr cannot construct
the pulse sequence because a current bar is absent for an instrument in
the requested universe, the run fails before strategy evaluation for
that incomplete pulse; this is a pulse construction error, not a feature
warmup value.

A final-bar target is separate from warmup. Under the next-open fill
model, there is no later bar available to fill a target emitted on the
last pulse, so ledgr reports `LEDGR_LAST_BAR_NO_FILL` and leaves the
ledger unchanged for that target change.

### Compiled Accounting Fails Closed

Default execution uses the canonical R accounting path:
`compiled_accounting_model = NULL`. The scoped `"spot_fifo"` accelerator
is an ephemeral sweep opt-in for supported spot-FIFO workloads;
committed durable runs fail closed if you request it there. Unsupported
model names raise `ledgr_unsupported_accounting_model`. Missing compiled
support raises `ledgr_compiled_spot_fifo_unavailable`.

Those classes are the stable top-level conditions to assert on in tests.
The accelerator does not broaden ledgr's accounting model into futures,
margin, broker reconciliation, or derivative accounting.

## Cleanup

Closing handles releases DuckDB resources in long sessions. It is not
data safety ceremony; completed run artifacts are already durable when
the run returns.

``` r
close(bt)
close(flat_bt)
close(open_bt)
close(final_bar_bt)
```

## Where Next

- For strategy authoring, read
  `vignette("strategy-development", package = "ledgr")`.
- For indicators, feature IDs, and warmup, read
  `vignette("indicators", package = "ledgr")`.
- For durable run inspection, read
  `vignette("experiment-store", package = "ledgr")`.
- For the target-holding and next-open fill timing contract, read
  `vignette("execution-semantics", package = "ledgr")`.
