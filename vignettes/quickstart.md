# Quickstart


You want the smallest useful ledgr loop before reading the tool chapters.

This quickstart creates a sealed snapshot, runs one strategy, sweeps a
small grid, and extracts one candidate for review. It is not a
validation protocol and it is not a production deployment path. It is
the shortest useful path from demo data to inspectable evidence.

## Load A Small Dataset

``` r
library(ledgr)
library(dplyr)

data("ledgr_demo_bars", package = "ledgr")
```

Use two demo instruments over the first half of 2019. The code writes to
a temporary DuckDB store so the rendered article leaves no project
artifacts behind.

``` r
store_path <- tempfile(fileext = ".duckdb")

bars <- ledgr_demo_bars |>
  filter(
    instrument_id %in% c("DEMO_01", "DEMO_02"),
    between(ts_utc, ledgr_utc("2019-01-01"), ledgr_utc("2019-06-30"))
  )

snapshot <- ledgr_snapshot_from_df(
  bars,
  db_path = store_path,
  snapshot_id = "quickstart_demo"
)
```

## Declare The Experiment

The strategy reads stable aliases named `fast` and `slow`. The concrete
SMA windows can vary later in the sweep.

``` r
features <- ledgr_feature_map(
  fast = ledgr_ind_sma(ledgr_param("fast_n")),
  slow = ledgr_ind_sma(ledgr_param("slow_n"))
)

strategy <- ledgr_demo_sma_crossover_strategy()

exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = strategy,
  features = features,
  opening = ledgr_opening(cash = 10000),
  cost_model = ledgr_cost_zero()
)
```

`cost_model = ledgr_cost_zero()` is explicit. If you want modeled costs,
use a cost model such as `ledgr_cost_spread_bps()` or
`ledgr_cost_notional_bps_fee()` rather than hiding costs inside the
strategy.

## Run One Case

Run one ordinary parameter set before sweeping. This catches setup
mistakes while the result is still easy to inspect.

``` r
single_run <- ledgr_run(
  exp,
  params = list(qty = 5, threshold = 0),
  feature_params = list(fast_n = 5L, slow_n = 20L),
  run_id = "quickstart_run",
  seed = 2026L
)

summary(single_run)
#> ledgr Backtest Summary
#> ======================
#>
#> Performance Metrics:
#>   Total Return:        0.24%
#>   Annualized Return:   0.47%
#>   Max Drawdown:        -0.53%
#>
#> Risk Metrics:
#>   Risk-Free Rate:      0.00% annual
#>   Annualization:       252 periods/year (US equity daily)
#>   Volatility (annual): 0.87%
#>   Sharpe Ratio:        0.546
#>
#> Trade Statistics:
#>   Total Trades:        6
#>   Win Rate:            33.33%
#>   Avg Trade:           $4.01
#>
#> Exposure:
#>   Time in Market:      67.44%
head(ledgr_results(single_run, what = "fills"), 3)
#> # A tibble: 3 x 9
#>   event_seq ts_utc     instrument_id side    qty price   fee realized_pnl action
#>       <int> <date>     <chr>         <chr> <dbl> <dbl> <dbl>        <dbl> <chr>
#> 1         1 2019-01-29 DEMO_01       BUY       5  91.9     0          0   OPEN
#> 2         2 2019-02-22 DEMO_02       BUY       5  69.5     0          0   OPEN
#> 3         3 2019-02-28 DEMO_02       SELL      5  67.3     0        -11.1 CLOSE
```

If this run has no fills, impossible prices, or surprising exposure,
stop here. Sweeps amplify a setup; they do not repair it.

## Sweep A Tiny Grid

Build feature parameters and strategy parameters separately, then cross
them into candidate rows.

``` r
feature_grid <- ledgr_feature_grid(
  fast_n = c(5L, 10L),
  slow_n = c(20L, 40L),
  .filter = fast_n < slow_n
)

strategy_grid <- ledgr_strategy_grid(
  qty = 5,
  threshold = c(0, 0.01)
)

grid <- ledgr_grid_cross(features = feature_grid, strategy = strategy_grid)

sweep <- ledgr_sweep(exp, grid, seed = 2026L)

sweep |>
  select(candidate_id, status, total_return, sharpe_ratio) |>
  arrange(desc(sharpe_ratio))
#> # ledgr sweep -- sweep_011dd398bf9e0a3d
#> # A tibble: 8 x 4
#>   candidate_id                               status sharpe_ratio total_return
#>   <chr>                                      <chr>         <dbl> <chr>
#> 1 feature_9a29b31dae19/strategy_7ccbbefd14d1 DONE          3.08  +1.1%
#> 2 feature_6ff6fe3a1d38/strategy_7ccbbefd14d1 DONE          2.13  +0.8%
#> 3 feature_af0f94c90243/strategy_7ccbbefd14d1 DONE          2.06  +0.7%
#> 4 feature_af0f94c90243/strategy_86be010cf688 DONE          1.80  +0.8%
#> 5 feature_6ff6fe3a1d38/strategy_86be010cf688 DONE          1.38  +0.6%
#> 6 feature_fa560ccbec9f/strategy_86be010cf688 DONE          1.34  +0.5%
#> 7 feature_fa560ccbec9f/strategy_7ccbbefd14d1 DONE          1.30  +0.5%
#> 8 feature_9a29b31dae19/strategy_86be010cf688 DONE          0.546 +0.2%
#>
#> # i 8 combinations: 8 done, 0 failed.
#> # i Retention returns: none.
#> # i Snapshot hash: 6eeff5ca520c516a61e0228c5ac06d22548c9d74e4e98d1e9f71fccdd2b8a87e.
#> # i Cost model hash: 4011132b5979fc370e524ebbc525ac7f4158b4de43639ec985f4c90969b4b9d0.
#> # i Metric context hash: 794b69bd7f9c704447d4b0208b8420cdf132ec7bd6582eaa037bf1066133c1bb.
#> # i Saved artifact: not saved.
#> # i Rows are printed in their current table order; rank or arrange explicitly before selecting candidates.
```

The sweep table is evidence, not an automatic recommendation. If you
rank rows, make the ranking rule visible at the call site.

``` r
candidate <- ledgr_candidate(
  sweep |> arrange(desc(sharpe_ratio)),
  1L
)

candidate$candidate_id
#> [1] "feature_9a29b31dae19/strategy_7ccbbefd14d1"
```

Promotion is the step that turns one selected candidate into a durable
run. In a real project, use a deliberate `run_id` and a note that
explains why this row was selected.

``` r
promoted <- ledgr_promote(
  exp,
  candidate,
  run_id = "quickstart_promoted",
  note = "Highest Sharpe ratio in the tiny demo sweep."
)
```

## Where Next

Read `vignette("research-workflow", package = "ledgr")` for the full
project loop. Read `vignette("sweeps", package = "ledgr")` when the grid
itself is the thing you need to understand. Read
`vignette("walk-forward", package = "ledgr")` when you are ready to
separate train-window selection from test-window evaluation.
