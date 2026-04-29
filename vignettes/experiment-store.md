Experiment Store
================

The experiment store is the DuckDB file behind a sealed snapshot. It
keeps market data, run artifacts, provenance, labels, tags, archive
state, and compact telemetry together.

``` text
snapshot handle -> run experiments -> list / inspect / compare / reopen
```

`run_id` is immutable. Labels, tags, and archive state are mutable
metadata.

``` r
library(ledgr)
data("ledgr_demo_bars", package = "ledgr")
```

## Create A Durable Snapshot

``` r
db_path <- tempfile("ledgr_store_", fileext = ".duckdb")

bars <- subset(
  ledgr_demo_bars,
  instrument_id %in% c("DEMO_01", "DEMO_02") &
    ts_utc >= as.POSIXct("2019-01-01", tz = "UTC") &
    ts_utc <= as.POSIXct("2019-06-30", tz = "UTC")
)

snapshot <- ledgr_snapshot_from_df(
  bars,
  db_path = db_path,
  snapshot_id = "store_demo_snapshot"
)
```

After snapshot creation, store operations take `snapshot`, not
`db_path`. In a new R session, recover the handle with
`ledgr_snapshot_load(db_path, snapshot_id)`.

## Run Variants

``` r
features <- list(ledgr_ind_sma(20))

trend_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  for (id in ctx$universe) {
    sma <- ctx$feature(id, "sma_20")
    if (is.finite(sma) && ctx$close(id) > sma) {
      targets[id] <- params$qty
    }
  }
  targets
}

exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = trend_strategy,
  features = features,
  opening = ledgr_opening(cash = 10000)
)

bt_small <- exp |>
  ledgr_run(params = list(qty = 5), run_id = "trend_qty_5")

bt_large <- exp |>
  ledgr_run(params = list(qty = 15), run_id = "trend_qty_15")
```

## Discover Runs

`ledgr_run_list()` is the store discovery view.

``` r
ledgr_run_list(snapshot)[
  c("run_id", "label", "tags", "status", "final_equity", "execution_mode")
]
#> # ledgr run list
#> # A tibble: 2 x 6
#>   run_id       label tags  status final_equity execution_mode
#>   <chr>        <chr> <chr> <chr>         <dbl> <chr>
#> 1 trend_qty_5  <NA>  <NA>  DONE         10343. audit_log
#> 2 trend_qty_15 <NA>  <NA>  DONE         11028. audit_log
#>
#> # i Full identity and telemetry columns remain available on this tibble.
#> # i Inspect one run with ledgr_run_info(snapshot, run_id).
```

Use labels and tags for mutable human-facing organization.

``` r
snapshot <- snapshot |>
  ledgr_run_label("trend_qty_5", "Baseline quantity") |>
  ledgr_run_tag("trend_qty_5", c("baseline", "trend")) |>
  ledgr_run_tag("trend_qty_15", c("trend", "larger-size"))

ledgr_run_list(snapshot)[c("run_id", "label", "tags")]
#> # ledgr run list
#> # A tibble: 2 x 3
#>   run_id       label             tags
#>   <chr>        <chr>             <chr>
#> 1 trend_qty_5  Baseline quantity baseline, trend
#> 2 trend_qty_15 <NA>              larger-size, trend
#>
#> # i Full identity and telemetry columns remain available on this tibble.
#> # i Inspect one run with ledgr_run_info(snapshot, run_id).
```

Tags and labels do not alter snapshot hashes, strategy hashes, parameter
hashes, config hashes, or result artifacts.

## Inspect And Compare

``` r
info <- ledgr_run_info(snapshot, "trend_qty_5")
info
#> ledgr Run Info
#> ==============
#>
#> Run ID:          trend_qty_5
#> Label:           Baseline quantity
#> Status:          DONE
#> Archived:        FALSE
#> Tags:            baseline, trend
#> Snapshot:        store_demo_snapshot
#> Snapshot Hash:   6eeff5ca520c516a61e0228c5ac06d22548c9d74e4e98d1e9f71fccdd2b8a87e
#> Config Hash:     00e240f9e094fa1ce4e1d453635c72db237a085384f6f297bdfceeee3a12f455
#> Strategy Hash:   c413dd07662e72e003890ed30da11b77113c505d17f99e99dbe701e7485e5236
#> Params Hash:     f1bc254d9d195c0cff7056644ba06c2ba5968db959e689837a76853dd47990ae
#> Reproducibility: tier_1
#> Execution Mode:  audit_log
#> Elapsed Sec:     1.19
#> Persist Features:TRUE
#> Cache Hits:      2
#> Cache Misses:    0
```

`ledgr_run_info()` is the detailed metadata view. It includes execution
mode, compact telemetry, status, identity hashes, and reproducibility
tier.

``` r
ledgr_compare_runs(snapshot, run_ids = c("trend_qty_5", "trend_qty_15"))[
  c("run_id", "final_equity", "total_return", "max_drawdown", "n_trades", "win_rate")
]
#> # ledgr comparison
#> # A tibble: 2 x 6
#>   run_id       final_equity total_return max_drawdown n_trades win_rate
#>   <chr>               <dbl> <chr>        <chr>           <int> <chr>
#> 1 trend_qty_5        10343. +3.4%        -7.0%              12 25.0%
#> 2 trend_qty_15       11028. +10.3%       -19.6%             12 25.0%
#>
#> # i Full identity and telemetry columns remain available on this tibble.
#> # i Inspect one run with ledgr_run_info(snapshot, run_id).
```

Comparison is read-only and does not rerun strategies.

## Reopen A Completed Run

``` r
reopened <- ledgr_run_open(snapshot, "trend_qty_5")
summary(reopened)
#> ledgr Backtest Summary
#> ======================
#>
#> Performance Metrics:
#>   Total Return:        3.43%
#>   Annualized Return:   6.86%
#>   Max Drawdown:        -7.00%
#>
#> Risk Metrics:
#>   Volatility (annual): 27.29%
#>
#> Trade Statistics:
#>   Total Trades:        24
#>   Win Rate:            12.50%
#>   Avg Trade:           $1.74
#>
#> Exposure:
#>   Time in Market:      65.12%
tail(ledgr_results(reopened, what = "equity"), 3)
#> # A tibble: 3 x 6
#>   ts_utc              equity  cash positions_value running_max drawdown
#>   <dttm>               <dbl> <dbl>           <dbl>       <dbl>    <dbl>
#> 1 2019-06-26 00:00:00 10016. 9197.            819.      10450.  -0.0415
#> 2 2019-06-27 00:00:00 10016. 9197.            819.      10450.  -0.0415
#> 3 2019-06-28 00:00:00 10343. 9535.            808.      10450.  -0.0102
close(reopened)
```

Only completed runs can be reopened. Failed or incomplete runs remain
inspectable through `ledgr_run_info()`.

## Archive Without Deleting

``` r
snapshot <- snapshot |>
  ledgr_run_archive("trend_qty_15", reason = "larger position kept for reference")

ledgr_run_list(snapshot)[c("run_id", "status", "archived", "archive_reason")]
#> # ledgr run list
#> # A tibble: 1 x 2
#>   run_id      status
#>   <chr>       <chr>
#> 1 trend_qty_5 DONE
#>
#> # i Full identity and telemetry columns remain available on this tibble.
#> # i Inspect one run with ledgr_run_info(snapshot, run_id).
```

Archiving hides a run from default listings without deleting artifacts.

``` r
close(bt_small)
close(bt_large)
ledgr_snapshot_close(snapshot)
```
