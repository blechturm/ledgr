# Quickstart


You want the smallest useful ledgr loop before reading the tool
chapters.

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

Start with a visible rule: hold five units when the current close is
above its 20-session moving average, otherwise hold zero. The strategy
reads the whole decision axis at once.

``` r
features <- list(ledgr_ind_sma(20))

strategy <- function(ctx, params) {
  sma <- ctx$vec$feature("sma_20")
  targets <- ctx$flat()
  selected <- which(
    is.finite(sma) &
      (ctx$vec$close / sma - 1) > params$threshold
  )
  targets[selected] <- params$qty
  targets
}

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
  run_id = "quickstart_run",
  seed = 2026L
)

single_run
#> ledgr Backtest Results
#> ======================
#>
#> Run ID:                            quickstart_run
#> Period:                            2019-01-01 to 2019-06-28
#> Opening Cash:                      $10000.00
#> Final Equity:                      $10041.77
#> Total Return:                      0.42%
#> Max Drawdown:                      -0.50%
#> Closed Trades:                     12
#>
#> Corporate actions: NOT SUPPLIED - returns may omit distributions
#> Price basis: UNDECLARED - distribution double counting cannot be ruled out
#>
#> Use summary(bt) for metrics and evidence
```

If this run has no fills, impossible prices, or surprising exposure,
stop here. Sweeps amplify a setup; they do not repair it.

The printed warnings are deliberate. `Corporate actions: NOT SUPPLIED`
means this demo supplied no distribution evidence;
`Price basis: UNDECLARED` means ledgr cannot rule out dividend double
counting in the bars. That is acceptable for learning the mechanics, not
for making an equity-research claim. See
`vignette("corporate-action-cash", package = "ledgr")` for the modeled
path.

## Sweep A Tiny Grid

Vary only the strategy threshold. The feature remains the same concrete
SMA used by the single run, so each candidate is easy to explain.

``` r
grid <- ledgr_strategy_grid(
  qty = 5,
  threshold = c(0, 0.01)
)

sweep <- ledgr_sweep(exp, grid, seed = 2026L)

sweep |>
  select(candidate_id, status, total_return, sharpe_ratio, params) |>
  arrange(desc(sharpe_ratio))
#> # ledgr sweep -- sweep_c0b37f5e3d12b3d3
#> # A tibble: 2 x 5
#>   candidate_id          status total_return sharpe_ratio params
#>   <chr>                 <chr>  <chr>               <dbl> <list>
#> 1 strategy_7ccbbefd14d1 DONE   +0.5%               1.25  <named list [2]>
#> 2 strategy_86be010cf688 DONE   +0.4%               0.838 <named list [2]>
#>
#> # i 2 combinations: 2 done, 0 failed.
#> # i Retention returns: none.
#> # i Retention trades: none.
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
#> [1] "strategy_7ccbbefd14d1"
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

promoted
#> ledgr Backtest Results
#> ======================
#>
#> Run ID:                            quickstart_promoted
#> Period:                            2019-01-01 to 2019-06-28
#> Opening Cash:                      $10000.00
#> Final Equity:                      $10052.86
#> Total Return:                      0.53%
#> Max Drawdown:                      -0.53%
#> Closed Trades:                     11
#>
#> Corporate actions: NOT SUPPLIED - returns may omit distributions
#> Price basis: UNDECLARED - distribution double counting cannot be ruled out
#>
#> Use summary(bt) for metrics and evidence
```

This promotion is safe to execute here because the article uses a
temporary store. It records the selection; it does not turn the tiny
in-sample sweep into validation.

## Where Next

Read `vignette("research-workflow", package = "ledgr")` for the full
project loop, and `vignette("sweeps", package = "ledgr")` when the grid
itself is what you need to understand. Read
`vignette("walk-forward", package = "ledgr")` when you are ready to
separate train-window selection from test-window evaluation.
