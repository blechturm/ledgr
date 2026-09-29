# Quickstart


You want the smallest useful ledgr loop before reading the tool
chapters.

In a few minutes you will have run one strategy on sealed demo data,
tried a small grid of variants, and kept one candidate as a run you can
reopen. That is the shortest useful path from demo data to inspectable
evidence; it is not a validation protocol and not a production
deployment path.

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
reads the whole decision axis at once. Until the average has 20 closes
to work with it does not exist, and the strategy holds nothing.

``` r
features <- list(ledgr_ind_sma(20))

strategy <- function(ctx, params) {
  sma <- ctx$vec$feature("sma_20")
  if (!ledgr_passed_warmup(sma)) return(ctx$flat())
  above <- ctx$vec$close / sma - 1 > params$threshold
  targets <- ctx$flat()
  targets[above] <- params$qty
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
  mutate(threshold = vapply(params, function(p) p$threshold, numeric(1))) |>
  select(candidate_id, threshold, status, total_return, sharpe_ratio) |>
  arrange(desc(sharpe_ratio))
#> # ledgr sweep -- sweep_35035e22d86c839f
#> # A tibble: 2 x 5
#>   candidate_id          threshold status total_return sharpe_ratio
#>   <chr>                     <dbl> <chr>  <chr>               <dbl>
#> 1 strategy_7ccbbefd14d1      0.01 DONE   +0.5%               1.25
#> 2 strategy_86be010cf688      0    DONE   +0.4%               0.838
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

Each row is one candidate: the `threshold` it ran with, its status and
its result. The Sharpe ratio is annualized from half a year of two demo
instruments, so at this size it describes the sample, not the rule. The
sweep table is evidence, not an automatic recommendation. If you rank
rows, make the ranking rule visible at the call site.

``` r
candidate <- ledgr_candidate(
  sweep |> arrange(desc(sharpe_ratio)),
  1L
)

candidate
#> ledgr_sweep_candidate
#> =====================
#> Candidate ID:     strategy_7ccbbefd14d1
#> Status:           DONE
#> Execution seed:   603352633
#> Strategy:         89fb9e6adb02
#> Snapshot hash:    6eeff5ca520c516a61e0228c5ac06d22548c9d74e4e98d1e9f71fccdd2b8a87e
#> Feature-set hash: 7f66b2149bc31cb90d63fa3a985d214ebf16cc1d3a0c698b4013ee5a4798091e
#> Evaluation scope: exploratory
#> Params:           {"qty":5.0,"threshold":0.01}
```

The candidate carries its parameters and the hashes of the inputs it ran
on, so the choice can be traced back to exactly what produced it.

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

- `vignette("data-input-and-snapshots", package = "ledgr")` seals your
  own data instead of the demo bars.
- `vignette("strategy-development", package = "ledgr")` teaches the
  strategy contract behind the rule you just ran.
- `vignette("research-workflow", package = "ledgr")` follows a research
  idea through code iterations, sweeps, and promotion.
