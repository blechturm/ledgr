Getting Started with ledgr
================

This vignette walks through the v0.1.7 research loop:

1.  start from deterministic demo bars;
2.  seal them into a snapshot;
3.  define an experiment;
4.  run one or more parameter sets;
5.  inspect the event-derived results;
6.  reopen and compare stored runs.

## Data And Snapshot

``` r
library(ledgr)
library(dplyr)
#> 
#> Attaching package: 'dplyr'
#> The following objects are masked from 'package:stats':
#> 
#>     filter, lag
#> The following objects are masked from 'package:base':
#> 
#>     intersect, setdiff, setequal, union
library(tibble)
data("ledgr_demo_bars", package = "ledgr")
```

`ledgr_demo_bars` is bundled with the package so examples do not need
local files or network access.

``` r
bars <- ledgr_demo_bars |>
  filter(
    instrument_id %in% c("DEMO_01", "DEMO_02"),
    between(ts_utc, ledgr_utc("2019-01-01"), ledgr_utc("2019-06-30"))
  )

bars |>
  slice_head(n = 6)
#> # A tibble: 6 x 7
#>   ts_utc              instrument_id  open  high   low close volume
#>   <dttm>              <chr>         <dbl> <dbl> <dbl> <dbl>  <dbl>
#> 1 2019-01-01 00:00:00 DEMO_01        89.7  91.8  89.7  91.5 468600
#> 2 2019-01-02 00:00:00 DEMO_01        91.5  91.6  91.0  91.3 438315
#> 3 2019-01-03 00:00:00 DEMO_01        91.3  92.1  89.6  90.5 576390
#> 4 2019-01-04 00:00:00 DEMO_01        90.7  91.1  89.5  89.8 458921
#> 5 2019-01-07 00:00:00 DEMO_01        89.7  90.1  89.2  89.2 597429
#> 6 2019-01-08 00:00:00 DEMO_01        88.9  89.4  88.3  88.6 396353
```

Create a sealed snapshot. This is the immutable input artifact for all
runs in the experiment.

``` r
snapshot <- ledgr_snapshot_from_df(bars)
snapshot
#> ledgr_snapshot
#> ==============
#> Bars:         258
#> Instruments:  2
#> Date Range:   2019-01-01T00:00:00Z to 2019-06-28T00:00:00Z
#> Database:     C:\Users\maxth\AppData\Local\Temp\RtmpMDvGcZ\ledgr_dcc055b3159c.duckdb
#> Snapshot ID:  snapshot_20260430_054425_49b6
#> Connection:  Closed (opens on-demand)
```

For durable work, pass a stable `db_path` at snapshot creation. After
that, normal run and store operations use the snapshot handle.

## Strategy Contract

A v0.1.7 strategy is `function(ctx, params)`. `ctx` is the pulse
context; it contains only state observable at the current decision
point. `params` is the JSON-safe parameter list passed to `ledgr_run()`.

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

Targets are desired holdings, not signals. A return value like
`c(DEMO_01 = 10, DEMO_02 = 0)` means “hold 10 units of `DEMO_01` and 0
units of `DEMO_02`.” The names must match `ctx$universe`.

Use `ctx$flat()` when each pulse should restate the whole portfolio from
flat. Use `ctx$hold()` when a rule should keep current positions unless
it emits a new target.

## Experiment And Run

Indicators are feature definitions. Ask ledgr for the feature IDs before
using them in `ctx$feature()`.

``` r
features <- list(ledgr_ind_sma(20))
ledgr_feature_id(features)
#> [1] "sma_20"
```

Bundle the reusable parts into an experiment. Construction validates the
snapshot, strategy, features, opening state, universe, and execution
options; it does not execute the strategy.

``` r
exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = strategy,
  features = features,
  opening = ledgr_opening(cash = 10000)
)

exp
#> ledgr_experiment
#> ================
#> Snapshot ID: snapshot_20260430_054425_49b6
#> Database:    C:\Users\maxth\AppData\Local\Temp\RtmpMDvGcZ\ledgr_dcc055b3159c.duckdb
#> Universe:    2 instruments
#> Features:    1 fixed
#> Opening:     cash=10000, positions=0
#> Mode:        audit_log
```

Run one parameter set.

``` r
bt <- exp |>
  ledgr_run(params = list(qty = 10), run_id = "getting_started_qty_10")

bt
#> ledgr Backtest Results
#> ======================
#>
#> Run ID:         getting_started_qty_10
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

A backtest handle points to stored run artifacts and may own DuckDB
resources while it is live. The artifacts are already durable;
`close(bt)` is deterministic cleanup for scripts, tests, and long
sessions.

``` r
on.exit(close(bt), add = TRUE)
```

## Inspect Results

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
#>   Total Trades:        24
#>   Win Rate:            12.50%
#>   Avg Trade:           $3.48
#>
#> Exposure:
#>   Time in Market:      65.12%
```

Results are derived views over recorded events.

``` r
ledgr_results(bt, what = "trades")
#> # A tibble: 24 x 9
#>    event_seq ts_utc     instrument_id side    qty price   fee realized_pnl action
#>        <int> <date>     <chr>         <chr> <dbl> <dbl> <dbl>        <dbl> <chr>
#>  1         1 2019-01-29 DEMO_01       BUY      10  91.9     0         0    OPEN
#>  2         2 2019-02-19 DEMO_02       BUY      10  68.7     0         0    OPEN
#>  3         3 2019-02-25 DEMO_02       SELL     10  67.5     0       -12.2  CLOSE
#>  4         4 2019-03-04 DEMO_02       BUY      10  68.0     0         0    OPEN
#>  5         5 2019-03-05 DEMO_02       SELL     10  65.3     0       -26.8  CLOSE
#>  6         6 2019-03-08 DEMO_02       BUY      10  68.9     0         0    OPEN
#>  7         7 2019-03-12 DEMO_02       SELL     10  67.1     0       -18.4  CLOSE
#>  8         8 2019-03-13 DEMO_02       BUY      10  67.4     0         0    OPEN
#>  9         9 2019-03-19 DEMO_02       SELL     10  67.5     0         1.26 CLOSE
#> 10        10 2019-03-20 DEMO_01       SELL     10 101.      0        96.1  CLOSE
#> # i 14 more rows
tail(ledgr_results(bt, what = "equity"), 4)
#> # A tibble: 4 x 6
#>   ts_utc     equity  cash positions_value running_max drawdown
#>   <date>      <dbl> <dbl>           <dbl>       <dbl>    <dbl>
#> 1 2019-06-25 10030. 8394.           1637.      10899.  -0.0797
#> 2 2019-06-26 10031. 8394.           1637.      10899.  -0.0796
#> 3 2019-06-27 10032. 8394.           1638.      10899.  -0.0796
#> 4 2019-06-28 10685. 9069.           1616.      10899.  -0.0196
```

The ledger is the source of truth.

``` r
head(ledgr_results(bt, what = "ledger"), 6)
#> # A tibble: 6 x 11
#>   event_id    run_id ts_utc     event_type instrument_id side    qty price   fee meta_json
#>   <chr>       <chr>  <date>     <chr>      <chr>         <chr> <dbl> <dbl> <dbl> <chr>
#> 1 getting_st~ getti~ 2019-01-29 FILL       DEMO_01       BUY      10  91.9     0 "{\"cash~
#> 2 getting_st~ getti~ 2019-02-19 FILL       DEMO_02       BUY      10  68.7     0 "{\"cash~
#> 3 getting_st~ getti~ 2019-02-25 FILL       DEMO_02       SELL     10  67.5     0 "{\"cash~
#> 4 getting_st~ getti~ 2019-03-04 FILL       DEMO_02       BUY      10  68.0     0 "{\"cash~
#> 5 getting_st~ getti~ 2019-03-05 FILL       DEMO_02       SELL     10  65.3     0 "{\"cash~
#> 6 getting_st~ getti~ 2019-03-08 FILL       DEMO_02       BUY      10  68.9     0 "{\"cash~
#> # i 1 more variable: event_seq <int>
```

## Debug One Pulse

`ledgr_pulse_snapshot()` builds the same pulse context a strategy sees
at a single timestamp. It is useful for explaining one decision without
rerunning an entire experiment.

``` r
pulse <- ledgr_pulse_snapshot(
  snapshot = snapshot,
  universe = c("DEMO_01", "DEMO_02"),
  ts_utc = "2019-03-01T00:00:00Z",
  features = features
)

pulse$close("DEMO_01")
#> [1] 106.5053
pulse$feature("DEMO_01", "sma_20")
#> [1] 96.84177
strategy(pulse, list(qty = 10))
#> DEMO_01 DEMO_02
#>      10      10
close(pulse)
```

## Compare Variants

Run a second parameter set into the same snapshot-backed store.

``` r
bt_qty_20 <- exp |>
  ledgr_run(params = list(qty = 20), run_id = "getting_started_qty_20")

ledgr_compare_runs(snapshot, run_ids = c("getting_started_qty_10", "getting_started_qty_20"))
#> # ledgr comparison
#> # A tibble: 2 x 8
#>   run_id                 label final_equity total_return max_drawdown n_trades win_rate
#>   <chr>                  <chr>        <dbl> <chr>        <chr>           <int> <chr>
#> 1 getting_started_qty_10 <NA>        10685. +6.9%        -13.5%             12 25.0%
#> 2 getting_started_qty_20 <NA>        11370. +13.7%       -25.3%             12 25.0%
#> # i 1 more variable: reproducibility_level <chr>
#>
#> # i Full identity and telemetry columns remain available on this tibble.
#> # i Inspect one run with ledgr_run_info(snapshot, run_id).
```

## Durable Store Workflow

Use a stable DuckDB path for research you want to keep.

``` r
artifact_db <- tempfile("ledgr_getting_started_", fileext = ".duckdb")
durable_snapshot <- ledgr_snapshot_from_df(
  bars,
  db_path = artifact_db,
  snapshot_id = "getting_started_snapshot"
)

durable_exp <- ledgr_experiment(
  snapshot = durable_snapshot,
  strategy = strategy,
  features = features,
  opening = ledgr_opening(cash = 10000)
)

durable_bt <- durable_exp |>
  ledgr_run(params = list(qty = 10), run_id = "durable_qty_10")

close(durable_bt)
ledgr_snapshot_close(durable_snapshot)

reloaded <- ledgr_snapshot_load(artifact_db, "getting_started_snapshot", verify = TRUE)
ledgr_run_list(reloaded)
#> # ledgr run list
#> # A tibble: 1 x 8
#>   run_id label tags  status final_equity total_return execution_mode reproducibility_level
#>   <chr>  <chr> <chr> <chr>         <dbl> <chr>        <chr>          <chr>
#> 1 durab~ <NA>  <NA>  DONE         10685. +6.9%        audit_log      tier_1
#>
#> # i Full identity and telemetry columns remain available on this tibble.
#> # i Inspect one run with ledgr_run_info(snapshot, run_id).
ledgr_run_info(reloaded, "durable_qty_10")
#> ledgr Run Info
#> ==============
#>
#> Run ID:          durable_qty_10
#> Label:           NA
#> Status:          DONE
#> Archived:        FALSE
#> Tags:            NA
#> Snapshot:        getting_started_snapshot
#> Snapshot Hash:   6eeff5ca520c516a61e0228c5ac06d22548c9d74e4e98d1e9f71fccdd2b8a87e
#> Config Hash:     f093b88f9381df691ba7d17a0b66487817b005ece1d323cab97cdef2315227c5
#> Strategy Hash:   c413dd07662e72e003890ed30da11b77113c505d17f99e99dbe701e7485e5236
#> Params Hash:     21625933895037a59ea8f5c0e5163b9205596490add264c97c747ac4fe9c87b7
#> Reproducibility: tier_1
#> Execution Mode:  audit_log
#> Elapsed Sec:     1.23
#> Persist Features:TRUE
#> Cache Hits:      2
#> Cache Misses:    0
ledgr_snapshot_close(reloaded)
```

`ledgr_snapshot_load()` is the new-session resumption path. Store APIs
such as `ledgr_run_list()`, `ledgr_run_info()`, `ledgr_compare_runs()`,
`ledgr_run_label()`, and `ledgr_run_archive()` operate on the snapshot
handle.

## Scope

v0.1.7 is a research release. It does not provide live trading, broker
integrations, short-selling semantics, or parameter sweep execution.
Sweep and tune APIs are reserved for later versions.

``` r
close(bt)
close(bt_qty_20)
ledgr_snapshot_close(snapshot)
```
