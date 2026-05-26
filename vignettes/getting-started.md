Getting Started with ledgr
================

This vignette walks through the current experiment-first research loop:

1.  start from deterministic demo bars;
2.  seal them into a snapshot;
3.  define an experiment;
4.  run one or more parameter sets;
5.  inspect the event-derived results;
6.  reopen and compare stored runs.

## Data And Snapshot

The examples use `dplyr` and `tibble` for data preparation and compact
display. They are suggested packages used by the vignettes, not part of
the strategy contract.

``` r
library(ledgr)
library(dplyr)
library(tibble)
data("ledgr_demo_bars", package = "ledgr")
```

`ledgr_demo_bars` is bundled with the package so examples do not need
local files or network access.

``` r
bars <- ledgr_demo_bars |>
  filter(
    instrument_id %in% c("DEMO_01", "DEMO_02"),
    between(
      ts_utc,
      ledgr::ledgr_utc("2019-01-01"),
      ledgr::ledgr_utc("2019-06-30")
    )
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
#> Database:     <temporary DuckDB path>
#> Snapshot ID:  snapshot_20260526_134914_6652
#> Connection:  Closed (opens on-demand)
```

For durable work, pass a stable `db_path` at snapshot creation. After
that, normal run and store operations use the snapshot handle.

## Strategy Contract

A ledgr strategy is `function(ctx, params)`. `ctx` is the pulse context;
it contains only state observable at the current decision point.
`params` is the JSON-safe strategy-parameter list passed to
`ledgr_run()`.

The first example uses the demo SMA-crossover strategy fixture. It is a
teaching fixture, not an investment recommendation. The feature
declarations stay explicit so the active-alias model is visible: feature
parameters materialize indicators, while strategy parameters are the
only values the strategy reads from `params`.

``` r
features <- ledgr_feature_map(
  fast = ledgr_ind_sma(ledgr_param("fast_n")),
  slow = ledgr_ind_sma(ledgr_param("slow_n"))
)

strategy <- ledgr_demo_sma_crossover_strategy()
ledgr_strategy_preflight(strategy)
#> ledgr Strategy Preflight
#> =========================
#>
#> Tier:    tier_1
#> Allowed: TRUE
#> Reason:  Strategy is self-contained under ledgr's static preflight rules.
```

Targets are desired holdings, not signals. A return value like
`c(DEMO_01 = 10, DEMO_02 = 0)` means “hold 10 units of `DEMO_01` and 0
units of `DEMO_02`.” The names must match `ctx$universe`.

Use `ctx$flat()` when each pulse should restate the whole portfolio from
flat. Use `ctx$hold()` when a rule should keep current positions unless
it emits a new target.

## Experiment And Run

Indicators are feature definitions. In an active-alias feature map,
aliases such as `fast` and `slow` are the strategy-facing names returned
by `ctx$features(id)`. The concrete feature IDs are resolved from
`feature_params` before the run starts.

``` r
ledgr_parameters(features)
#> # A tibble: 2 x 4
#>   param_name alias argument constructor
#>   <chr>      <chr> <chr>    <chr>
#> 1 fast_n     fast  n        ledgr_ind_sma
#> 2 slow_n     slow  n        ledgr_ind_sma
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
#> Snapshot ID: snapshot_20260526_134914_6652
#> Database:    <temporary DuckDB path>
#> Universe:    2 instruments
#> Features:    2 mapped
#> Opening:     cash=10000, positions=0
#> Mode:        audit_log
#> Metrics:     US equity daily (252 days/year * 1 bars/day = 252 bars/year)
```

Run one parameter set.

``` r
bt <- exp |>
  ledgr_run(
    feature_params = list(fast_n = 10L, slow_n = 40L),
    params = list(qty = 10, threshold = 0),
    run_id = "getting_started_sma_crossover"
  )

bt
#> ledgr Backtest Results
#> ======================
#>
#> Run ID:         getting_started_sma_crossover
#> Universe:       DEMO_01, DEMO_02
#> Date Range:     2019-01-01T00:00:00Z to 2019-06-28T00:00:00Z
#> Execution Mode: audit_log
#> Initial Cash:   $10000.00
#> Final Equity:   $10106.83
#> P&L:            $106.83 (1.07%)
#>
#> Use summary(bt) for detailed metrics
#> Use plot(bt) for equity curve visualization
```

A backtest handle points to stored run artifacts. The artifacts are
already durable when `ledgr_run()` returns, and ordinary result
inspection opens and closes read connections per operation. Use
`close(bt)` as explicit resource cleanup in long sessions, tests,
explicit-open workflows, and lazy result cursors.

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
#>   Total Return:        1.07%
#>   Annualized Return:   2.11%
#>   Max Drawdown:        -0.76%
#>
#> Risk Metrics:
#>   Risk-Free Rate:      0.00% annual
#>   Annualization:       252 periods/year (US equity daily)
#>   Volatility (annual): 1.56%
#>   Sharpe Ratio:        1.349
#>
#> Trade Statistics:
#>   Total Trades:        2
#>   Win Rate:            100.00%
#>   Avg Trade:           $53.41
#>
#> Exposure:
#>   Time in Market:      59.69%
```

Results are derived views over recorded events.

``` r
ledgr_results(bt, what = "trades")
#> # A tibble: 2 x 9
#>   event_seq ts_utc     instrument_id side    qty price   fee realized_pnl action
#>       <int> <date>     <chr>         <chr> <dbl> <dbl> <dbl>        <dbl> <chr>
#> 1         3 2019-04-23 DEMO_01       SELL     10 102.      0         27.4 CLOSE
#> 2         4 2019-06-13 DEMO_02       SELL     10  76.5     0         79.4 CLOSE
tail(ledgr_results(bt, what = "equity"), 4)
#> # A tibble: 4 x 6
#>   ts_utc     equity   cash positions_value running_max drawdown
#>   <date>      <dbl>  <dbl>           <dbl>       <dbl>    <dbl>
#> 1 2019-06-25 10107. 10107.               0      10173. -0.00655
#> 2 2019-06-26 10107. 10107.               0      10173. -0.00655
#> 3 2019-06-27 10107. 10107.               0      10173. -0.00655
#> 4 2019-06-28 10107. 10107.               0      10173. -0.00655
```

The ledger is the source of truth.

``` r
head(ledgr_results(bt, what = "ledger"), 6)
#> # A tibble: 4 x 11
#>   event_id    run_id ts_utc     event_type instrument_id side    qty price   fee meta_json
#>   <chr>       <chr>  <date>     <chr>      <chr>         <chr> <dbl> <dbl> <dbl> <chr>
#> 1 getting_st~ getti~ 2019-02-26 FILL       DEMO_01       BUY      10  98.9     0 "{\"cash~
#> 2 getting_st~ getti~ 2019-03-29 FILL       DEMO_02       BUY      10  68.5     0 "{\"cash~
#> 3 getting_st~ getti~ 2019-04-23 FILL       DEMO_01       SELL     10 102.      0 "{\"cash~
#> 4 getting_st~ getti~ 2019-06-13 FILL       DEMO_02       SELL     10  76.5     0 "{\"cash~
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
  features = features,
  feature_params = list(fast_n = 10L, slow_n = 40L)
)

pulse$close("DEMO_01")
#> [1] 106.5053
pulse$features("DEMO_01")
#>     fast     slow
#> 99.79637 93.26325
strategy(pulse, list(qty = 10, threshold = 0))
#> DEMO_01 DEMO_02
#>      10       0
close(pulse)
```

## Compare Variants

Run a second parameter set into the same snapshot-backed store.

``` r
bt_qty_20 <- exp |>
  ledgr_run(
    feature_params = list(fast_n = 10L, slow_n = 40L),
    params = list(qty = 20, threshold = 0),
    run_id = "getting_started_sma_crossover_qty_20"
  )

ledgr_compare_runs(
  snapshot,
  run_ids = c("getting_started_sma_crossover", "getting_started_sma_crossover_qty_20")
)
#> # ledgr comparison
#> # A tibble: 2 x 9
#>   run_id       label final_equity total_return sharpe_ratio max_drawdown n_trades win_rate
#>   <chr>        <chr>        <dbl> <chr>               <dbl> <chr>           <int> <chr>
#> 1 getting_sta~ <NA>        10107. +1.1%                1.35 -0.8%               2 100.0%
#> 2 getting_sta~ <NA>        10214. +2.1%                1.36 -1.5%               2 100.0%
#> # i 1 more variable: reproducibility_level <chr>
#>
#> # i Full identity and telemetry columns remain available on this tibble.
#> # i Inspect one run with ledgr_run_info(snapshot, run_id).
```

## Durable Store Workflow

Use a stable DuckDB path for research you want to keep. The vignette
uses `tempfile()` so it does not leave files in your project; in real
work, replace that with a project path such as `"research.duckdb"`.

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
  ledgr_run(
    feature_params = list(fast_n = 10L, slow_n = 40L),
    params = list(qty = 10, threshold = 0),
    run_id = "durable_sma_crossover"
  )

close(durable_bt)
ledgr_snapshot_close(durable_snapshot)

reloaded <- ledgr_snapshot_load(artifact_db, "getting_started_snapshot", verify = TRUE)
ledgr_run_list(reloaded)
#> # ledgr run list
#> # A tibble: 1 x 8
#>   run_id label tags  status final_equity total_return execution_mode reproducibility_level
#>   <chr>  <chr> <lgl> <chr>         <dbl> <chr>        <chr>          <chr>
#> 1 durab~ <NA>  NA    DONE         10107. +1.1%        audit_log      tier_1
#>
#> # i Full identity and telemetry columns remain available on this tibble.
#> # i Inspect one run with ledgr_run_info(snapshot, run_id).
ledgr_run_info(reloaded, "durable_sma_crossover")
#> ledgr Run Info
#> ==============
#>
#> Run ID:          durable_sma_crossover
#> Label:           NA
#> Status:          DONE
#> Archived:        FALSE
#> Tags:            NA
#> Snapshot:        getting_started_snapshot
#> Snapshot Hash:   6eeff5ca520c516a61e0228c5ac06d22548c9d74e4e98d1e9f71fccdd2b8a87e
#> Config Hash:     29835f105ce59230cab61558c9c25241491f58a394a4d5b5f46c04c49aad3df4
#> Strategy Hash:   ca593cc1c3490b0ee6e80ef46b1daa2ebffc75eb73a4cc27c37dd05f9f6c5832
#> Params Hash:     b2317c0ea4148a068bc8f4a5afd40eded1c37f52a1d7b115f9f6838a7d084732
#> Reproducibility: tier_1
#> Execution Mode:  audit_log
#> Elapsed Sec:     1.01
#> Persist Features:TRUE
#> Cache Hits:      4
#> Cache Misses:    0
ledgr_snapshot_close(reloaded)
```

`ledgr_snapshot_load()` is the new-session resumption path. Store APIs
such as `ledgr_run_list()`, `ledgr_run_info()`, `ledgr_compare_runs()`,
`ledgr_run_label()`, and `ledgr_run_archive()` operate on the snapshot
handle.

## Scope

ledgr is currently a research package. It provides sealed snapshots,
experiment-first backtests, durable run metadata, result inspection,
comparison tables, and sequential exploratory sweeps. It does not
provide live trading, broker integrations, short-selling semantics,
automatic ranking, walk-forward/PBO/CSCV helpers, paper trading, or
parallel sweep execution.

``` r
close(bt)
close(bt_qty_20)
ledgr_snapshot_close(snapshot)
```

## What’s Next?

For strategy authoring, read
`vignette("strategy-development", package = "ledgr")`. For indicators
and feature IDs, read `vignette("indicators", package = "ledgr")`. For
durable run inspection, read
`vignette("experiment-store", package = "ledgr")`. For exploratory
parameter sweeps and candidate promotion, read
`vignette("sweeps", package = "ledgr")`.
