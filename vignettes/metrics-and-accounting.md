# The Accounting Model


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

After a run you want to know what actually happened: what filled, which
positions closed, how equity moved, and where the summary numbers come
from. ledgr records a backtest as accounting evidence first and summary
metrics second, and this article reads it in that order:

<div class="ledgr-diagram ledgr-accounting-hierarchy">

```mermaid

flowchart TB
  ledger["ledger events<br/>source of truth"]
  fills["fills<br/>execution rows"]
  trades["trades<br/>closing fills"]
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
| What adjacent-period returns produced the metrics? | `ledgr_results(bt, what = "returns")` | classed tibble |
| What executed? | `ledgr_results(bt, what = "fills")` | classed tibble |
| What closed quantity? | `ledgr_results(bt, what = "trades")` | classed tibble |
| What did the event ledger record? | `ledgr_results(bt, what = "ledger")` | classed tibble |
| How do stored runs compare? | `ledgr_run_compare(snapshot, run_ids = ...)` | classed comparison tibble |
| What did a sweep candidate summarize? | `ledgr_sweep()` result rows | classed sweep tibble |
| What context was stored by promotion? | `ledgr_promotion_context(bt)` or `ledgr_run_promotion_context()` | nested list |
| Why was an availability-aware action blocked or stopped? | `ledgr_results(bt, what = "diagnostics")` | classed tibble |
| What could an availability-aware strategy see? | `ledgr_results(bt, what = "availability")` | classed tibble |

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

Use a five-bar in-memory example so the accounting can be checked by
hand. OHLC values are equal per bar so the example focuses on accounting
arithmetic; real bars use the same code with ordinary intra-bar
movement. The examples use the same canonical workflow as a research
project: snapshot -\> `ledgr_experiment()` -\> `ledgr_run()`.

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

snapshot <- ledgr_snapshot_from_df(bars)
exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = one_day_strategy,
  opening = ledgr_opening(cash = 1000),
  cost_model = ledgr_cost_zero()
)
bt <- ledgr_run(exp, run_id = "accounting_example")
```

The strategy asks to hold one share on the first pulse and then returns
to flat. In these examples, decisions fill at the next open. The buy
therefore fills on the second bar, and the exit fills on the third bar.

## Timing And Cost

Timing and cost are separate execution steps. The timing model decides
which bar a target change fills on; the cost model then resolves the
fill price and the explicit fee. The spread convention, fee order and
cost chains are taught in
`vignette("risk-and-cost", package = "ledgr")`.

## Ledger Events

A **ledger event** is the append-only accounting record written when
execution changes cash, positions, or run state. Fills, trades, equity,
and metrics are derived views over ledger-backed evidence. The ledger is
the most literal view; the friendlier result tables below are derived
from these events.

The ledger is one wide typed table, returned exactly as stored. Common
columns identify the event and its execution terms. `cash_delta` and
`position_delta` are the effects that accounting applies. `source` and
`source_fact_id` identify opening, corporate-action, and terminal
postings. The remaining evidence columns describe cash entitlements and
disposition policy or mark provenance; they are typed missing values
when they do not apply to that event kind. There is no JSON accounting
envelope to unpack.

``` r
ledger <- ledgr_results(bt, what = "ledger")
ledger
#> # A tibble: 2 x 31
#>   event_id    run_id ts_utc     event_type instrument_id side    qty price   fee event_seq
#>   <chr>       <chr>  <date>     <chr>      <chr>         <chr> <dbl> <dbl> <dbl>     <int>
#> 1 accounting~ accou~ 2020-01-02 FILL       AAA           BUY       1   101     0         1
#> 2 accounting~ accou~ 2020-01-03 FILL       AAA           SELL      1   105     0         2
#> # i 21 more variables: cash_delta <dbl>, position_delta <dbl>, source <chr>,
#> #   source_fact_id <chr>, entitled_quantity <dbl>, gross_cash_per_parent_unit <dbl>,
#> #   amount_policy_id <chr>, posting_policy_id <chr>, late_arrival <lgl>,
#> #   affected_marked_exposure <dbl>, terminal_event <chr>, matched_label <chr>,
#> #   disposition_policy_id <chr>, disposition_choice <chr>, disposition_basis <chr>,
#> #   mark_source <chr>, mark_source_ts_utc <dttm>, mark_age <int>, haircut_fraction <dbl>,
#> #   position_before <dbl>, realized_model_pnl <dbl>
```

## Fills And Trades

A **fill** is an execution row: direction, quantity, price, fee, and
action. A **trade** is the subset of fill evidence that closes quantity
and realizes P&L. `what = "fills"` returns execution fill rows. Opening
and closing fills both appear here.

``` r
fills <- ledgr_results(bt, what = "fills")
fills
#> # A tibble: 2 x 10
#>   event_seq ts_utc     recording_pulse_ts_utc instrument_id side    qty price   fee
#>       <int> <date>     <dttm>                 <chr>         <chr> <dbl> <dbl> <dbl>
#> 1         1 2020-01-02 2020-01-02 00:00:00    AAA           BUY       1   101     0
#> 2         2 2020-01-03 2020-01-03 00:00:00    AAA           SELL      1   105     0
#> # i 2 more variables: realized_pnl <dbl>, action <chr>
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
#> # A tibble: 1 x 10
#>   event_seq ts_utc     recording_pulse_ts_utc instrument_id side    qty price   fee
#>       <int> <date>     <dttm>                 <chr>         <chr> <dbl> <dbl> <dbl>
#> 1         2 2020-01-03 2020-01-03 00:00:00    AAA           SELL      1   105     0
#> # i 2 more variables: realized_pnl <dbl>, action <chr>
```

This run has two fill rows but one closed trade row: the opening buy
closes nothing, so it is not a trade. Counting fills as trades would
count it too.

## Equity Rows

An **equity row** values the portfolio at one timestamp. It combines
cash, current position value, and total equity, including open-position
exposure. The equity curve records portfolio state through time.

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

``` r
ggplot2::ggplot(equity, ggplot2::aes(x = ts_utc, y = equity)) +
  ggplot2::geom_line(linewidth = 0.8, color = "#1f77b4") +
  ggplot2::labs(
    title = "Equity curve",
    x = NULL,
    y = "Equity"
  ) +
  ggplot2::theme_minimal(base_size = 12)
```

![](metrics-and-accounting_files/figure-commonmark/equity-curve-plot-1.png)

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

`ledgr_results()` returns the seven result views listed under Inspection
Surfaces: `equity`, `returns`, `fills`, `trades`, `ledger`,
`diagnostics` and `availability`. Some are stored, others are derived
from the ledger or reconstructed on request. There is no
`what = "metrics"` result table. Use `summary(bt)` for printed
interpretation, or `ledgr_compute_metrics(bt)` when you need the named
metric values in code.

This small example uses `bars_per_year <- 252` because the bars are
daily. ledgr detects bar frequency for `ledgr_compute_metrics()` and
snaps common cadences, such as daily and weekly, to standard
annualization constants. Use the detected value if you need an external
calculation to match ledgr exactly on non-daily data.

> [!TIP]
>
> ### Try it
>
> Change `bars_per_year` in the recompute chunk from `252` to `365`. Which
> metrics change? Why does `total_return` stay the same?


## Zero Trades Can Be Correct

A flat strategy produces no fills and no closed trades. The result
tables still keep their schemas, so downstream code can rely on the same
column names.

``` r
flat_strategy <- function(ctx, params) ctx$flat()

flat_exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = flat_strategy,
  opening = ledgr_opening(cash = 1000),
  cost_model = ledgr_cost_zero()
)
flat_bt <- ledgr_run(flat_exp, run_id = "flat_accounting_example")

ledgr_results(flat_bt, what = "fills")
#> # A tibble: 0 x 10
#> # i 10 variables: event_seq <int>, ts_utc <date>, recording_pulse_ts_utc <dttm>,
#> #   instrument_id <chr>, side <chr>, qty <dbl>, price <dbl>, fee <dbl>,
#> #   realized_pnl <dbl>, action <chr>
ledgr_results(flat_bt, what = "trades")
#> # A tibble: 0 x 10
#> # i 10 variables: event_seq <int>, ts_utc <date>, recording_pulse_ts_utc <dttm>,
#> #   instrument_id <chr>, side <chr>, qty <dbl>, price <dbl>, fee <dbl>,
#> #   realized_pnl <dbl>, action <chr>
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

open_exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = open_only_strategy,
  opening = ledgr_opening(cash = 1000),
  cost_model = ledgr_cost_zero()
)
open_bt <- ledgr_run(open_exp, run_id = "open_accounting_example")

ledgr_results(open_bt, what = "fills")
#> # A tibble: 1 x 10
#>   event_seq ts_utc     recording_pulse_ts_utc instrument_id side    qty price   fee
#>       <int> <date>     <dttm>                 <chr>         <chr> <dbl> <dbl> <dbl>
#> 1         1 2020-01-02 2020-01-02 00:00:00    AAA           BUY       1   101     0
#> # i 2 more variables: realized_pnl <dbl>, action <chr>
ledgr_results(open_bt, what = "trades")
#> # A tibble: 0 x 10
#> # i 10 variables: event_seq <int>, ts_utc <date>, recording_pulse_ts_utc <dttm>,
#> #   instrument_id <chr>, side <chr>, qty <dbl>, price <dbl>, fee <dbl>,
#> #   realized_pnl <dbl>, action <chr>
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
for execution, so ledgr records `final_pulse_no_execution` and leaves
the ledger unchanged for that target change.

``` r
final_bar_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  if (ledgr_utc(ctx$ts_utc) == ledgr_utc("2020-01-05")) {
    targets["AAA"] <- 1
  }
  targets
}

final_bar_exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = final_bar_strategy,
  opening = ledgr_opening(cash = 1000),
  cost_model = ledgr_cost_zero()
)
final_bar_bt <- ledgr_run(final_bar_exp, run_id = "final_bar_accounting_example")

ledgr_results(final_bar_bt, what = "fills")
#> # A tibble: 0 x 10
#> # i 10 variables: event_seq <int>, ts_utc <date>, recording_pulse_ts_utc <dttm>,
#> #   instrument_id <chr>, side <chr>, qty <dbl>, price <dbl>, fee <dbl>,
#> #   realized_pnl <dbl>, action <chr>
ledgr_results(final_bar_bt, what = "diagnostics")
#> # A tibble: 12 x 22
#>    run_id diagnostic_seq ts_utc     instrument_id stage outcome reason_code reasons target
#>    <chr>           <int> <date>     <chr>         <chr> <chr>   <chr>       <chr>    <dbl>
#>  1 final~              1 2020-01-01 ""            sizi~ unavai~ sizing_int~ raw_qu~     NA
#>  2 final~              2 2020-01-01 "AAA"         deci~ record~ decision_r~ decisi~      0
#>  3 final~              3 2020-01-01 ""            reco~ reconc~ affordabil~ afford~     NA
#>  4 final~              4 2020-01-02 "AAA"         deci~ record~ decision_r~ decisi~      0
#>  5 final~              5 2020-01-02 ""            reco~ reconc~ affordabil~ afford~     NA
#>  6 final~              6 2020-01-03 "AAA"         deci~ record~ decision_r~ decisi~      0
#>  7 final~              7 2020-01-03 ""            reco~ reconc~ affordabil~ afford~     NA
#>  8 final~              8 2020-01-04 "AAA"         deci~ record~ decision_r~ decisi~      0
#>  9 final~              9 2020-01-04 ""            reco~ reconc~ affordabil~ afford~     NA
#> 10 final~             10 2020-01-05 "AAA"         deci~ record~ decision_r~ decisi~      1
#> 11 final~             11 2020-01-05 "AAA"         exec~ no_fill final_puls~ final_~      1
#> 12 final~             12 2020-01-05 ""            reco~ reconc~ affordabil~ afford~     NA
#> # i 13 more variables: quantity <dbl>, price <dbl>, mark_source <chr>, mark_age <int>,
#> #   decision_ts_utc <dttm>, execution_ts_utc <dttm>, event_seq <int>,
#> #   target_before_risk <dbl>, target_after_risk <dbl>, position_before <dbl>,
#> #   position_after <dbl>, feature_identity_json <chr>, detail_json <chr>
```

## Where Next

- `vignette("risk-and-cost", package = "ledgr")` declares cost and risk
  policy and shows what each changes in a fill.
- `vignette("metric-contexts-and-conventions", package = "ledgr")`
  covers metric contexts, annualization, and diagnostics.
- `vignette("execution-semantics", package = "ledgr")` explains why
  fills happen on the next bar and why the final decision bar cannot
  fill.
