Experiment Store
================

The experiment store is a durable DuckDB file that keeps sealed market
data, run metadata, result artifacts, provenance, and compact telemetry
together.

The basic workflow is:

``` text
sealed snapshot -> many runs -> list / inspect / compare / reopen
```

`run_id` is the immutable experiment key. Labels, tags, and archive
state are mutable metadata layered on top of that key.

## Create One Store

Use one durable `db_path` for the snapshot and all runs you want to
compare.

``` r
library(ledgr)

db_path <- tempfile(fileext = ".duckdb")

bars <- data.frame(
  ts_utc = rep(as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:6, 2),
  instrument_id = rep(c("AAA", "BBB"), each = 7),
  open = c(100, 101, 102, 103, 104, 105, 106,
           80,  80,  81,  81,  82,  83,  83),
  high = c(101, 102, 103, 104, 105, 106, 107,
           81,  81,  82,  82,  83,  84,  84),
  low = c(99, 100, 101, 102, 103, 104, 105,
          79, 79, 80, 80, 81, 82, 82),
  close = c(100, 101, 102, 103, 104, 105, 106,
            80, 80, 81, 81, 82, 83, 83),
  volume = 1000
)

snapshot <- ledgr_snapshot_from_df(
  bars,
  db_path = db_path,
  snapshot_id = "demo_snapshot"
)
```

The snapshot is sealed. Reusing it means each run is evaluated against
the same data artifact.

## Run Variants

Here two parameter sets use the same strategy function and the same
snapshot.

``` r
trend_strategy <- function(ctx, params) {
  targets <- ctx$targets()
  for (id in ctx$universe) {
    if (ctx$close(id) > params$threshold[[id]]) {
      targets[id] <- params$qty
    }
  }
  targets
}

bt_small <- ledgr_backtest(
  snapshot = snapshot,
  strategy = trend_strategy,
  strategy_params = list(threshold = c(AAA = 101, BBB = 80), qty = 1),
  db_path = db_path,
  run_id = "trend_small"
)

bt_large <- ledgr_backtest(
  snapshot = snapshot,
  strategy = trend_strategy,
  strategy_params = list(threshold = c(AAA = 102, BBB = 81), qty = 3),
  db_path = db_path,
  run_id = "trend_large"
)
```

## List Runs

`ledgr_run_list()` is the discovery view. It is read-only.

``` r
ledgr_run_list(db_path)[, c(
  "run_id", "label", "tags", "status", "final_equity", "total_return",
  "execution_mode", "reproducibility_level"
)]
#> # A tibble: 2 x 8
#>   run_id label tags  status final_equity total_return execution_mode reproducibility_level
#>   <chr>  <chr> <chr> <chr>         <dbl>        <dbl> <chr>          <chr>
#> 1 trend~ <NA>  <NA>  DONE         100005    0.0000500 audit_log      tier_1
#> 2 trend~ <NA>  <NA>  DONE         100255    0.00255   audit_log      tier_1
```

`run_id` should be stable and script-friendly. Use labels for human
names.

``` r
ledgr_run_label(db_path, "trend_small", "Lower threshold, one share")
#> ledgr Run Info
#> ==============
#>
#> Run ID:          trend_small
#> Label:           Lower threshold, one share
#> Status:          DONE
#> Archived:        FALSE
#> Tags:            NA
#> Snapshot:        demo_snapshot
#> Snapshot Hash:   c64c19dceb5b5f4e274ad0b73189cb2c6b7beee5e7c54e636c2256e66eb4fe24
#> Config Hash:     cbafb2862d3dda3fa49a32a48d9933ce8c30d034bf395ee99cfd6cd8b4d71ced
#> Strategy Hash:   7e92c0d24dd915b6037bbd1cb90c76264955c73363f045f4da2c239161f27e82
#> Params Hash:     c9c0e58fc8eb6c19318a70ace1b640044df1f6945b2cfd04715cebe20c8cb34c
#> Reproducibility: tier_1
#> Execution Mode:  audit_log
#> Elapsed Sec:     1.71
#> Persist Features:TRUE
#> Cache Hits:      0
#> Cache Misses:    0
ledgr_run_tag(db_path, "trend_small", c("baseline", "trend"))
#> ledgr Run Info
#> ==============
#>
#> Run ID:          trend_small
#> Label:           Lower threshold, one share
#> Status:          DONE
#> Archived:        FALSE
#> Tags:            baseline, trend
#> Snapshot:        demo_snapshot
#> Snapshot Hash:   c64c19dceb5b5f4e274ad0b73189cb2c6b7beee5e7c54e636c2256e66eb4fe24
#> Config Hash:     cbafb2862d3dda3fa49a32a48d9933ce8c30d034bf395ee99cfd6cd8b4d71ced
#> Strategy Hash:   7e92c0d24dd915b6037bbd1cb90c76264955c73363f045f4da2c239161f27e82
#> Params Hash:     c9c0e58fc8eb6c19318a70ace1b640044df1f6945b2cfd04715cebe20c8cb34c
#> Reproducibility: tier_1
#> Execution Mode:  audit_log
#> Elapsed Sec:     1.71
#> Persist Features:TRUE
#> Cache Hits:      0
#> Cache Misses:    0
ledgr_run_tag(db_path, "trend_large", c("trend", "higher-size"))
#> ledgr Run Info
#> ==============
#>
#> Run ID:          trend_large
#> Label:           NA
#> Status:          DONE
#> Archived:        FALSE
#> Tags:            higher-size, trend
#> Snapshot:        demo_snapshot
#> Snapshot Hash:   c64c19dceb5b5f4e274ad0b73189cb2c6b7beee5e7c54e636c2256e66eb4fe24
#> Config Hash:     5848665167afb2de32572195eb7d7783976d809afffccc3dc4886cb078546c20
#> Strategy Hash:   7e92c0d24dd915b6037bbd1cb90c76264955c73363f045f4da2c239161f27e82
#> Params Hash:     778613d18461ba161bdadf9a616484075e13a4c86c49b2576b91f6dac42efbde
#> Reproducibility: tier_1
#> Execution Mode:  audit_log
#> Elapsed Sec:     1.13
#> Persist Features:TRUE
#> Cache Hits:      0
#> Cache Misses:    0

ledgr_run_list(db_path)[, c("run_id", "label", "tags")]
#> # A tibble: 2 x 3
#>   run_id      label                      tags
#>   <chr>       <chr>                      <chr>
#> 1 trend_small Lower threshold, one share baseline, trend
#> 2 trend_large <NA>                       higher-size, trend
```

Tags are mutable grouping metadata. They do not change identity hashes,
stored artifacts, strategy provenance, or comparison semantics.

## Inspect One Run

`ledgr_run_info()` gives the detailed metadata for one run.

``` r
info <- ledgr_run_info(db_path, "trend_small")
info
#> ledgr Run Info
#> ==============
#>
#> Run ID:          trend_small
#> Label:           Lower threshold, one share
#> Status:          DONE
#> Archived:        FALSE
#> Tags:            baseline, trend
#> Snapshot:        demo_snapshot
#> Snapshot Hash:   c64c19dceb5b5f4e274ad0b73189cb2c6b7beee5e7c54e636c2256e66eb4fe24
#> Config Hash:     cbafb2862d3dda3fa49a32a48d9933ce8c30d034bf395ee99cfd6cd8b4d71ced
#> Strategy Hash:   7e92c0d24dd915b6037bbd1cb90c76264955c73363f045f4da2c239161f27e82
#> Params Hash:     c9c0e58fc8eb6c19318a70ace1b640044df1f6945b2cfd04715cebe20c8cb34c
#> Reproducibility: tier_1
#> Execution Mode:  audit_log
#> Elapsed Sec:     1.71
#> Persist Features:TRUE
#> Cache Hits:      0
#> Cache Misses:    0
```

Important fields:

- `execution_mode`: how the run wrote artifacts, for example `audit_log`
  or `db_live`;
- `elapsed_sec`, `pulse_count`, and cache counts: compact telemetry
  retained after the R session ends;
- `reproducibility_level`: whether ledgr captured enough strategy
  metadata for source inspection or recovery;
- `strategy_source_hash` and `strategy_params_hash`: identity metadata
  for the strategy and parameters.

Older stores may contain legacy/pre-provenance runs. ledgr reads them,
but the provenance fields can be missing.

## Compare Runs

`ledgr_compare_runs()` builds on stored run metadata and result
artifacts. It does not rerun strategies.

``` r
ledgr_compare_runs(db_path, run_ids = c("trend_small", "trend_large"))[, c(
  "run_id", "final_equity", "total_return", "max_drawdown",
  "n_trades", "win_rate", "strategy_params_hash"
)]
#> # A tibble: 2 x 7
#>   run_id     final_equity total_return max_drawdown n_trades win_rate strategy_params_hash
#>   <chr>             <dbl>        <dbl>        <dbl>    <int>    <dbl> <chr>
#> 1 trend_sma~       100005    0.0000500      0              0       NA c9c0e58fc8eb6c19318~
#> 2 trend_lar~       100255    0.00255       -0.00249        0       NA 778613d18461ba161bd~
```

This is the lightweight comparison surface in v0.1.6. Parameter sweeps
are future scope.

## Reopen A Completed Run

`ledgr_run_open()` returns a normal `ledgr_backtest` handle over
existing artifacts. It does not recompute the run.

``` r
reopened <- ledgr_run_open(db_path, "trend_small")
summary(reopened)
#> ledgr Backtest Summary
#> ======================
#>
#> Performance Metrics:
#>   Total Return:        0.01%
#>   Annualized Return:   0.21%
#>   Max Drawdown:        0.00%
#>
#> Risk Metrics:
#>   Volatility (annual): 0.02%
#>
#> Trade Statistics:
#>   Total Trades:        2
#>   Win Rate:            0.00%
#>   Avg Trade:           $0.00
#>
#> Exposure:
#>   Time in Market:      57.14%
ledgr_results(reopened, what = "equity")
#> # A tibble: 7 x 6
#>   ts_utc              equity   cash positions_value running_max drawdown
#>   <dttm>               <dbl>  <dbl>           <dbl>       <dbl>    <dbl>
#> 1 2020-01-01 00:00:00 100000 100000               0      100000        0
#> 2 2020-01-02 00:00:00 100000 100000               0      100000        0
#> 3 2020-01-03 00:00:00 100000 100000               0      100000        0
#> 4 2020-01-04 00:00:00 100000  99816             184      100000        0
#> 5 2020-01-05 00:00:00 100002  99816             186      100002        0
#> 6 2020-01-06 00:00:00 100004  99816             188      100004        0
#> 7 2020-01-07 00:00:00 100005  99816             189      100005        0
close(reopened)
```

Only completed runs can be opened. Failed or incomplete runs should be
inspected with `ledgr_run_info()`.

## Archive Instead Of Delete

Archiving hides a run from the default list but keeps the artifacts
available.

``` r
ledgr_run_archive(db_path, "trend_large", reason = "superseded by smaller baseline")
#> ledgr Run Info
#> ==============
#>
#> Run ID:          trend_large
#> Label:           NA
#> Status:          DONE
#> Archived:        TRUE
#> Tags:            higher-size, trend
#> Snapshot:        demo_snapshot
#> Snapshot Hash:   c64c19dceb5b5f4e274ad0b73189cb2c6b7beee5e7c54e636c2256e66eb4fe24
#> Config Hash:     5848665167afb2de32572195eb7d7783976d809afffccc3dc4886cb078546c20
#> Strategy Hash:   7e92c0d24dd915b6037bbd1cb90c76264955c73363f045f4da2c239161f27e82
#> Params Hash:     778613d18461ba161bdadf9a616484075e13a4c86c49b2576b91f6dac42efbde
#> Reproducibility: tier_1
#> Execution Mode:  audit_log
#> Elapsed Sec:     1.13
#> Persist Features:TRUE
#> Cache Hits:      0
#> Cache Misses:    0

ledgr_run_list(db_path)[, c("run_id", "archived")]
#> # A tibble: 1 x 2
#>   run_id      archived
#>   <chr>       <lgl>
#> 1 trend_small FALSE
ledgr_run_list(db_path, include_archived = TRUE)[, c("run_id", "archived", "archive_reason")]
#> # A tibble: 2 x 3
#>   run_id      archived archive_reason
#>   <chr>       <lgl>    <chr>
#> 1 trend_small FALSE    <NA>
#> 2 trend_large TRUE     superseded by smaller baseline
```

Archive is non-destructive and idempotent. Hard delete is not a v0.1.6
API.

``` r
close(bt_small)
close(bt_large)
close(snapshot)
```
