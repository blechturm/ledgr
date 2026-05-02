
# ledgr

ledgr is an event-sourced systematic trading research framework for R.

In v0.1.x, ledgr focuses on deterministic research: sealed market-data
snapshots, experiment-first backtests, durable run metadata, strategy
provenance, comparison tables, and low-code TTR indicators. Paper
trading and live trading adapters are planned for later releases and are
not available in the current package.

Most backtesting tools compute results directly from price arrays. ledgr
records each decision and state change as an immutable event, then
derives trades, equity, and metrics from that ledger.

``` text
sealed snapshot -> experiment -> run -> event ledger -> results
```

For the longer design arc, see the
[`research-to-production`](https://blechturm.github.io/ledgr/articles/research-to-production.html)
article on the pkgdown site.

Not sure whether ledgr fits your workflow? Start with [Who ledgr is
for](https://blechturm.github.io/ledgr/articles/who-ledgr-is-for.html).

## Install

``` r
if (!requireNamespace("pak", quietly = TRUE)) install.packages("pak")
pak::pak("blechturm/ledgr")
```

The README uses `dplyr` and `tibble` for compact example output. They
are suggested packages for documentation and examples; ledgr strategies
themselves use the pulse context shown below.

``` r
library(ledgr)
library(dplyr)
library(tibble)
data("ledgr_demo_bars", package = "ledgr")
```

## First Experiment

Use the bundled demo bars for a first run. They are deterministic and
require no network access.

``` r
bars <- ledgr_demo_bars |>
  filter(
    instrument_id %in% c("DEMO_01", "DEMO_02"),
    between(ts_utc, ledgr_utc("2019-01-01"), ledgr_utc("2019-06-30"))
  )

bars |>
  slice_head(n = 4)
#> # A tibble: 4 x 7
#>   ts_utc              instrument_id  open  high   low close volume
#>   <dttm>              <chr>         <dbl> <dbl> <dbl> <dbl>  <dbl>
#> 1 2019-01-01 00:00:00 DEMO_01        89.7  91.8  89.7  91.5 468600
#> 2 2019-01-02 00:00:00 DEMO_01        91.5  91.6  91.0  91.3 438315
#> 3 2019-01-03 00:00:00 DEMO_01        91.3  92.1  89.6  90.5 576390
#> 4 2019-01-04 00:00:00 DEMO_01        90.7  91.1  89.5  89.8 458921
```

Create a sealed snapshot. A snapshot is the immutable data artifact
every run uses.

``` r
snapshot <- ledgr_snapshot_from_df(bars)
```

Strategies receive a pulse context `ctx` and a parameter list `params`.
They return target holdings: a named numeric vector with one desired
quantity per instrument.

``` r
strategy <- function(ctx, params) {
  targets <- ctx$flat()

  for (id in ctx$universe) {
    sma <- ctx$feature(id, "sma_20")
    if (is.finite(sma) && ctx$close(id) > sma) {
      targets[id] <- params$qty
    }
  }

  targets
}
```

Bundle the snapshot, strategy, indicators, starting state, and execution
options into an experiment. Construction validates the object; it does
not run the strategy or write run artifacts.

``` r
features <- list(ledgr_ind_sma(20))

exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = strategy,
  features = features,
  opening = ledgr_opening(cash = 10000)
)

exp
#> ledgr_experiment
#> ================
#> Snapshot ID: snapshot_20260502_114721_f472
#> Database:    C:\Users\maxth\AppData\Local\Temp\RtmpKib8eC\ledgr_1663833449e2.duckdb
#> Universe:    2 instruments
#> Features:    1 fixed
#> Opening:     cash=10000, positions=0
#> Mode:        audit_log
```

Run the experiment with explicit parameters.

``` r
bt <- exp |>
  ledgr_run(params = list(qty = 10), run_id = "readme_sma_20")

bt
#> ledgr Backtest Results
#> ======================
#>
#> Run ID:         readme_sma_20
#> Universe:       DEMO_01, DEMO_02
#> Date Range:     2019-01-01T00:00:00Z to 2019-06-28T00:00:00Z
#> Execution Mode: audit_log
#> Initial Cash:   $10000.00
#> Final Equity:   $10685.17
#> P&L:            $685.17 (6.85%)
#>
#> Use summary(bt) for detailed metrics
#> Use plot(bt) for equity curve visualization
```

Inspect result views. These are derived from the recorded event ledger.

``` r
summary(bt)
#> ledgr Backtest Summary
#> ======================
#>
#> Performance Metrics:
#>   Total Return:        6.85%
#>   Annualized Return:   13.94%
#>   Max Drawdown:        -13.51%
#>
#> Risk Metrics:
#>   Volatility (annual): 54.72%
#>
#> Trade Statistics:
#>   Total Trades:        12
#>   Win Rate:            25.00%
#>   Avg Trade:           $6.96
#>
#> Exposure:
#>   Time in Market:      65.12%
ledgr_results(bt, what = "trades")
#> # A tibble: 12 x 9
#>    event_seq ts_utc     instrument_id side    qty price   fee realized_pnl action
#>        <int> <date>     <chr>         <chr> <dbl> <dbl> <dbl>        <dbl> <chr>
#>  1         3 2019-02-25 DEMO_02       SELL     10  67.5     0       -12.2  CLOSE
#>  2         5 2019-03-05 DEMO_02       SELL     10  65.3     0       -26.8  CLOSE
#>  3         7 2019-03-12 DEMO_02       SELL     10  67.1     0       -18.4  CLOSE
#>  4         9 2019-03-19 DEMO_02       SELL     10  67.5     0         1.26 CLOSE
#>  5        10 2019-03-20 DEMO_01       SELL     10 101.      0        96.1  CLOSE
#>  6        13 2019-03-27 DEMO_01       SELL     10 105.      0        -2.88 CLOSE
#>  7        15 2019-04-05 DEMO_01       SELL     10 103.      0       -21.2  CLOSE
#>  8        17 2019-04-15 DEMO_01       SELL     10 104.      0       -18.6  CLOSE
#>  9        19 2019-04-18 DEMO_01       SELL     10 103.      0       -17.4  CLOSE
#> 10        21 2019-05-16 DEMO_01       SELL     10 101.      0        -9.67 CLOSE
#> 11        22 2019-06-03 DEMO_02       SELL     10  79.8     0       128.   CLOSE
#> 12        24 2019-06-05 DEMO_02       SELL     10  79.3     0       -14.6  CLOSE
```

## Compare Runs

Run another parameter set against the same experiment and compare stored
results. Comparison reads existing artifacts; it does not recompute
strategies.

``` r
bt_qty_20 <- exp |>
  ledgr_run(params = list(qty = 20), run_id = "readme_sma_20_qty_20")

ledgr_compare_runs(snapshot, run_ids = c("readme_sma_20", "readme_sma_20_qty_20"))
#> # ledgr comparison
#> # A tibble: 2 x 8
#>   run_id               label final_equity total_return max_drawdown n_trades win_rate
#>   <chr>                <chr>        <dbl> <chr>        <chr>           <int> <chr>
#> 1 readme_sma_20        <NA>        10685. +6.9%        -13.5%             12 25.0%
#> 2 readme_sma_20_qty_20 <NA>        11370. +13.7%       -25.3%             12 25.0%
#> # i 1 more variable: reproducibility_level <chr>
#>
#> # i Full identity and telemetry columns remain available on this tibble.
#> # i Inspect one run with ledgr_run_info(snapshot, run_id).
```

## Durable Research

For durable research, create the snapshot in a project DuckDB file:

``` r
snapshot <- ledgr_snapshot_from_df(bars, db_path = "research.duckdb")
```

In a later R session, reopen the sealed snapshot and continue from the
snapshot handle:

``` r
snapshot <- ledgr_snapshot_load("research.duckdb", snapshot_id = "my_snapshot")
ledgr_run_list(snapshot)
ledgr_run_info(snapshot, "readme_sma_20")
```

After snapshot creation or loading, normal experiment-store operations
take the snapshot handle rather than a raw database path.

## Scope

v0.1.7 is the experiment-first research API. It does not ship parameter
sweep execution, broker adapters, paper trading, live trading, or
short-selling semantics. Those are separate roadmap items with different
state and safety requirements.

`ledgr_run()` returns a live handle. The run artifacts are already
durable when the run finishes. Most result inspection opens and closes
its own read connection; explicit `close(bt)` is resource cleanup for
long sessions, explicit opens, and lazy result cursors.

``` r
close(bt)
close(bt_qty_20)
ledgr_snapshot_close(snapshot)
```

## Documentation

``` r
help(package = "ledgr")
utils::packageDescription("ledgr")[c("Package", "Version", "Title")]
vignette(package = "ledgr")
system.file("doc", package = "ledgr")
system.file("doc", "strategy-development.html", package = "ledgr")
```

The `system.file()` calls are useful in noninteractive `Rscript` and
agent workflows where opening pkgdown in a browser is not the first
step. The pkgdown-only background articles are on the website, while
installed vignettes focus on package workflows.

Design packets are in `inst/design/`, including the current v0.1.7.2
packet.
