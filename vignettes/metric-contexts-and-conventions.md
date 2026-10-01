# Metric Contexts And Conventions


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

Your Sharpe ratio depends on assumptions: how many bars make a year, and
which risk-free rate applies. By the end of this article you can see
where ledgr stores those assumptions, how changing them moves the
metrics, and how the same context travels with runs, sweeps, and
promotions. You need it when your data is not daily US-equity bars, or
when you compare metrics across runs.

## Prerequisites

``` r
library(ledgr)
library(dplyr)
library(tibble)
```

## A Small Example Run

This companion article needs a small completed run so metric-context
examples can inspect stored assumptions. The accounting walkthrough,
result-table hierarchy, and hand recomputation live in
`vignette("metrics-and-accounting", package = "ledgr")`.

This example uses `ledgr_backtest()`, a compact in-memory entrance for
small examples. New project workflows should enter through a sealed
snapshot, `ledgr_experiment()`, and `ledgr_run()` as shown in the
Quickstart.

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
  run_id = "metric_context_example",
  cost_model = ledgr_cost_zero()
)
```

## Metric Context

Metric assumptions live in a `metric_context`. The default context is US
equity daily: zero annual risk-free rate and `252 * 1` periods per year.
Use market templates for common assumptions:

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
#> Hash:           794b69bd7f9c704447d4b0208b8420cdf132ec7bd6582eaa037bf1066133c1bb
ledgr_metric_us_equity(risk_free_rate = 0.04)
#> ledgr_metric_context
#> ====================
#> Version:        1
#> Risk-free rate: 4.0000%
#> Calendar:       US equity daily (252 days/year * 1 bars/day = 252 bars/year)
#> Hash:           247dc197ca7e63bd503d5ee7743bb2ff2e2c542ee61a698e94960964ffacffa8
ledgr_metric_us_equity(
  bars_per_day = 390L,
  risk_free_rate = ledgr_risk_free_rate(0.04, label = "policy rate")
)
#> ledgr_metric_context
#> ====================
#> Version:        1
#> Risk-free rate: 4.0000%
#> Calendar:       US equity custom bars (252 days/year * 390 bars/day = 98,280 bars/year)
#> Hash:           51b4f0993533f2d60911b811f47a2862d1aca716d5c394102aa5c86c31a55312
ledgr_metric_crypto()
#> ledgr_metric_context
#> ====================
#> Version:        1
#> Risk-free rate: 0.0000%
#> Calendar:       crypto daily (365 days/year * 1 bars/day = 365 bars/year)
#> Hash:           3a25682545962e78f29c03313dd4df14d320b0d3d1796cab38e897524506c84a
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
#> Hash:           247dc197ca7e63bd503d5ee7743bb2ff2e2c542ee61a698e94960964ffacffa8
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

When run, sweep, comparison, or walk-forward metrics see clearly
subdaily timestamps under a daily annualization context, ledgr emits the
classed warning `ledgr_metric_context_cadence_mismatch`. The warning
does not change metric values, metric recipes, stored evidence, or
identity. It is a prompt to rerun the analysis with an explicit cadence,
not first-class intraday execution support.

### Stored Context vs Sensitivity Overrides

`summary(bt)` and `ledgr_compute_metrics(bt)` use the metric context
stored with the committed run. Call-time overrides are sensitivity
checks; they do not mutate the run:

``` r
stored_run_context <- ledgr_metric_context(bt)
stored_metrics <- ledgr_compute_metrics(bt)
rf_metrics <- ledgr_compute_metrics(bt, risk_free_rate = 0.04)

ledgr_metric_context(stored_metrics)
#> ledgr_metric_context
#> ====================
#> Version:        1
#> Risk-free rate: 0.0000%
#> Calendar:       US equity daily (252 days/year * 1 bars/day = 252 bars/year)
#> Hash:           794b69bd7f9c704447d4b0208b8420cdf132ec7bd6582eaa037bf1066133c1bb
ledgr_metric_context(rf_metrics)
#> ledgr_metric_context
#> ====================
#> Version:        1
#> Risk-free rate: 4.0000%
#> Calendar:       US equity daily (252 days/year * 1 bars/day = 252 bars/year)
#> Hash:           247dc197ca7e63bd503d5ee7743bb2ff2e2c542ee61a698e94960964ffacffa8
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
#> NULL
context$risk_free_rate$source
#> [1] "manual"
context$risk_free_rate$as_of
#> NULL
ledgr_metric_context_hash(context)
#> [1] "794b69bd7f9c704447d4b0208b8420cdf132ec7bd6582eaa037bf1066133c1bb"
```

### Comparison, Sweep, And Promotion Contexts

The following snippets are fragments: they use objects from the
experiment-store and sweeps workflows, so they are not executed here.
They show where metric context is carried.

`ledgr_run_compare()` has exactly one comparison context per table. The
snapshot-first form uses the default context unless you pass one
explicitly:

``` r
comparison <- ledgr_run_compare(
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
Treasury, ECB, or central-bank adapters are not supported yet. When they
arrive, they will feed the same pulse-aligned `rf_period_return` vector
into the formula above, so the Sharpe formula stays the same.

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
#>   Closed Trades:       1
#>   Win Rate:            100.00%
#>   Avg Trade:           $4.00
#>
#> Exposure:
#>   Time in Market:      20.00%
#>
#> Execution Evidence:
#>   Fill Timing:         dense_bar_timestamp
#>
#> Corporate-Action Evidence:
#> Corporate actions: NOT SUPPLIED - returns may omit distributions
#> Price basis: UNDECLARED - distribution double counting cannot be ruled out
#>   Full policy record: ledgr_corporate_action_summary(bt)
```

The example holds one share for one bar of five, so a 0.40% gain becomes
a 28.59% annualized return and a Sharpe ratio near 8. Annualizing five
bars exaggerates everything; these figures show how the conventions are
applied, not anything about a strategy.

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
#> Hash:           794b69bd7f9c704447d4b0208b8420cdf132ec7bd6582eaa037bf1066133c1bb
```

The raw metrics object keeps attributes that record how each metric was
computed. Those attributes are part of the programmatic object, not the
printed metric table. Use named fields such as `metrics$sharpe_ratio` or
the subset above when you need a compact report.

`ledgr_run_compare()` is also programmatic: it returns a tibble-like
`ledgr_comparison` object with raw numeric metric columns for filtering
and ranking. Its print method only curates the displayed columns.
Comparison metrics are recomputed from stored equity and fill tables and
use the same closed-trade semantics as `ledgr_compute_metrics()`.

For reports, convert the comparison object and keep the raw numeric
columns. Like the snippets above, this fragment uses the
experiment-store comparison, so it is not executed here:

``` r
comparison |>
  as.data.frame() |>
  select(run_id, final_equity, total_return, sharpe_ratio, max_drawdown)
```

## Zero Trades In The Metrics

A completed run with zero closed trades reports `win_rate` and
`avg_trade` as `NA`, not zero, because there is no closed trade to
average. To find out why a run made no trades, use the checklist in
`vignette("indicators", package = "ledgr")`.

## Where Next

- `vignette("execution-semantics", package = "ledgr")` explains when and
  at what price a target fills.
- `vignette("metrics-and-accounting", package = "ledgr")` is the shorter
  accounting-first tutorial.
- `vignette("sweeps", package = "ledgr")` shows how metric contexts
  thread through parameter sweeps.
