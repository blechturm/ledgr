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

The examples use `dplyr` and `tibble` for data preparation and compact
display. They are suggested packages used by the vignettes, not part of
the experiment store contract.

``` r
library(ledgr)
library(dplyr)
library(tibble)
data("ledgr_demo_bars", package = "ledgr")
```

## Create A Durable Snapshot

Market data and derived data have different lifecycle rules in ledgr. A
sealed snapshot freezes the real market-data input and its hash. If you
need more instruments, more dates, corrected bars, or tick-derived bars,
create a new snapshot. Indicators, runs, labels, tags, comparisons, and
telemetry are derived from sealed market data and can be added later
without mutating the snapshot.

This vignette uses `tempfile()` so it can run without writing into your
project directory. For real research, use a stable path such as
`"research.duckdb"` and a snapshot ID you will recognize later.

``` r
db_path <- tempfile("ledgr_store_", fileext = ".duckdb")

bars <- ledgr_demo_bars |>
  filter(
    instrument_id %in% c("DEMO_01", "DEMO_02"),
    between(
      ts_utc,
      ledgr::ledgr_utc("2019-01-01"),
      ledgr::ledgr_utc("2019-06-30")
    )
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

If your market data starts in CSV, seal the CSV into the same kind of
durable store. The CSV must contain at least `instrument_id`, `ts_utc`,
`open`, `high`, `low`, and `close`.

``` r
snapshot <- ledgr_snapshot_from_csv(
  "data/daily_bars.csv",
  db_path = "research.duckdb",
  snapshot_id = "eod_2019_h1"
)
```

In any later session, recover the handle without re-sealing the data:

``` r
snapshot <- ledgr_snapshot_load("research.duckdb", snapshot_id = "eod_2019_h1")
```

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
ledgr_run_list(snapshot)
#> # ledgr run list
#> # A tibble: 2 x 8
#>   run_id label tags  status final_equity total_return execution_mode reproducibility_level
#>   <chr>  <chr> <lgl> <chr>         <dbl> <chr>        <chr>          <chr>
#> 1 trend~ <NA>  NA    DONE         10042. +0.4%        audit_log      tier_1
#> 2 trend~ <NA>  NA    DONE         10125. +1.3%        audit_log      tier_1
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

ledgr_run_list(snapshot)
#> # ledgr run list
#> # A tibble: 2 x 8
#>   run_id label tags  status final_equity total_return execution_mode reproducibility_level
#>   <chr>  <chr> <chr> <chr>         <dbl> <chr>        <chr>          <chr>
#> 1 trend~ Base~ base~ DONE         10042. +0.4%        audit_log      tier_1
#> 2 trend~ <NA>  larg~ DONE         10125. +1.3%        audit_log      tier_1
#>
#> # i Full identity and telemetry columns remain available on this tibble.
#> # i Inspect one run with ledgr_run_info(snapshot, run_id).
```

Tags and labels do not alter snapshot hashes, strategy hashes, parameter
hashes, config hashes, or result artifacts.

The returned objects are still tibbles. When you need a custom view,
convert to a tibble and select the columns you want.

``` r
ledgr_run_list(snapshot) |>
  as_tibble() |>
  select(run_id, label, tags, status, final_equity, execution_mode)
#> # A tibble: 2 x 6
#>   run_id       label             tags               status final_equity execution_mode
#>   <chr>        <chr>             <chr>              <chr>         <dbl> <chr>
#> 1 trend_qty_5  Baseline quantity baseline, trend    DONE         10042. audit_log
#> 2 trend_qty_15 <NA>              larger-size, trend DONE         10125. audit_log
```

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
#> Config Hash:     256af9881754ae7c9b5e8fdc6be25b9c07a092ff5bc68f916162c285d4f7e404
#> Strategy Hash:   c413dd07662e72e003890ed30da11b77113c505d17f99e99dbe701e7485e5236
#> Params Hash:     f1bc254d9d195c0cff7056644ba06c2ba5968db959e689837a76853dd47990ae
#> Reproducibility: tier_1
#> Execution Mode:  audit_log
#> Elapsed Sec:     2.18
#> Persist Features:TRUE
#> Cache Hits:      0
#> Cache Misses:    2
```

`ledgr_run_info()` is the detailed metadata view. It includes execution
mode, compact telemetry, status, identity hashes, and reproducibility
tier.

``` r
ledgr_compare_runs(snapshot, run_ids = c("trend_qty_5", "trend_qty_15"))
#> # ledgr comparison
#> # A tibble: 2 x 9
#>   run_id       label final_equity total_return sharpe_ratio max_drawdown n_trades win_rate
#>   <chr>        <chr>        <dbl> <chr>               <dbl> <chr>           <int> <chr>
#> 1 trend_qty_5  Base~       10042. +0.4%               0.838 -0.5%              12 25.0%
#> 2 trend_qty_15 <NA>        10125. +1.3%               0.851 -1.5%              12 25.0%
#> # i 1 more variable: reproducibility_level <chr>
#>
#> # i Full identity and telemetry columns remain available on this tibble.
#> # i Inspect one run with ledgr_run_info(snapshot, run_id).
```

Comparison is read-only and does not rerun strategies. `n_trades` counts
closed, realised trade observations, not every fill. A run can have
fills but no closed trades yet, in which case win rate is not defined.

## Inspect Stored Strategy Source

Completed runs keep strategy provenance in the experiment store. This is
one of the most useful audit artifacts: you can inspect the source text
that produced a run without reopening the backtest handle and without
rerunning the strategy. The full trust and tier model lives in
`vignette("reproducibility", package = "ledgr")`; this section shows the
store workflow.

Use `trust = FALSE` for safe inspection. It returns stored source text,
parameters, hashes, dependency metadata, and warnings without parsing,
evaluating, or executing the source.

``` r
stored_strategy <- ledgr_extract_strategy(snapshot, "trend_qty_5", trust = FALSE)
stored_strategy
#> ledgr Extracted Strategy
#> ========================
#>
#> Run ID:          trend_qty_5
#> Reproducibility: tier_1
#> Source Hash:     c413dd07662e72e003890ed30da11b77113c505d17f99e99dbe701e7485e5236
#> Params Hash:     f1bc254d9d195c0cff7056644ba06c2ba5968db959e689837a76853dd47990ae
#> Hash Verified:   TRUE
#> Trust:           FALSE
#> Source Available:TRUE
```

The source text is just data in this mode.

``` r
writeLines(stored_strategy$strategy_source_text)
#> function (ctx, params)
#> {
#>     targets <- ctx$flat()
#>     for (id in ctx$universe) {
#>         sma <- ctx$feature(id, "sma_20")
#>         if (is.finite(sma) && ctx$close(id) > sma) {
#>             targets[id] <- params$qty
#>         }
#>     }
#>     targets
#> }
```

Hash verification proves stored-text identity, not code safety. Use
`trust = TRUE` only when you already trust the experiment store and
intentionally want ledgr to parse and evaluate the stored text into a
function object. Legacy/pre-provenance runs remain inspectable through
`ledgr_run_info()` and stored result tables, but their strategy function
cannot be recovered from provenance alone.

## Reopen A Completed Run In A Later Session

`ledgr_run_open()` reconstructs a completed run handle from stored
artifacts. It does not recompute the strategy. This is useful when you
want full result tables or plots after restarting R.

``` r
reopened <- ledgr_run_open(snapshot, "trend_qty_5")
summary(reopened)
#> ledgr Backtest Summary
#> ======================
#>
#> Performance Metrics:
#>   Total Return:        0.42%
#>   Annualized Return:   0.82%
#>   Max Drawdown:        -0.50%
#>
#> Risk Metrics:
#>   Volatility (annual): 0.98%
#>   Sharpe Ratio:        0.838
#>
#> Trade Statistics:
#>   Total Trades:        12
#>   Win Rate:            25.00%
#>   Avg Trade:           $3.48
#>
#> Exposure:
#>   Time in Market:      66.67%
tail(ledgr_results(reopened, what = "equity"), 3)
#> # A tibble: 3 x 6
#>   ts_utc     equity   cash positions_value running_max drawdown
#>   <date>      <dbl>  <dbl>           <dbl>       <dbl>    <dbl>
#> 1 2019-06-26 10042. 10042.               0      10067. -0.00251
#> 2 2019-06-27 10042. 10042.               0      10067. -0.00251
#> 3 2019-06-28 10042. 10042.               0      10067. -0.00251
close(reopened)
```

Only completed runs can be reopened. Failed or incomplete runs remain
inspectable through `ledgr_run_info()`.

## Archive Without Deleting

``` r
snapshot <- snapshot |>
  ledgr_run_archive("trend_qty_15", reason = "larger position kept for reference")

ledgr_run_list(snapshot)
#> # ledgr run list
#> # A tibble: 1 x 8
#>   run_id label tags  status final_equity total_return execution_mode reproducibility_level
#>   <chr>  <chr> <chr> <chr>         <dbl> <chr>        <chr>          <chr>
#> 1 trend~ Base~ base~ DONE         10042. +0.4%        audit_log      tier_1
#>
#> # i Full identity and telemetry columns remain available on this tibble.
#> # i Inspect one run with ledgr_run_info(snapshot, run_id).
```

Archiving hides a run from default listings without deleting artifacts.

## Bridge A Low-Level CSV Import

The high-level CSV helper above is the normal path. The lower-level path
is useful when you want to create the snapshot row, import one or more
CSV files, inspect the sealed metadata, and then load the sealed
artifact in a separate step.

The order is important:

1.  create the snapshot envelope;
2.  import bars into that CREATED snapshot;
3.  seal it to validate bars and write the snapshot hash;
4.  load it with `verify = TRUE`;
5.  pass the loaded snapshot to `ledgr_experiment()` and `ledgr_run()`.

``` r
csv_db_path <- tempfile("ledgr_csv_bridge_", fileext = ".duckdb")
csv_bars_path <- tempfile("ledgr_csv_bars_", fileext = ".csv")

csv_bars <- bars |>
  filter(ts_utc <= ledgr::ledgr_utc("2019-01-15")) |>
  mutate(ts_utc = format(ts_utc, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))

utils::write.csv(csv_bars, csv_bars_path, row.names = FALSE)

csv_con <- ledgr_db_init(csv_db_path)
csv_snapshot_id <- ledgr_snapshot_create(
  csv_con,
  snapshot_id = "csv_bridge_snapshot",
  meta = list(description = "low-level CSV bridge demo")
)

ledgr_snapshot_import_bars_csv(
  csv_con,
  csv_snapshot_id,
  bars_csv_path = csv_bars_path,
  instruments_csv_path = NULL,
  auto_generate_instruments = TRUE
)

csv_hash <- ledgr_snapshot_seal(csv_con, csv_snapshot_id)
csv_info <- ledgr_snapshot_info(csv_con, csv_snapshot_id)
DBI::dbDisconnect(csv_con, shutdown = TRUE)

csv_hash
#> [1] "e80b4f4f7df20364e904804ebddd0626da16fc7fc0b5bde8f452e93fa3e733ff"
csv_info |>
  select(
    snapshot_id,
    status,
    snapshot_hash,
    bar_count,
    instrument_count,
    start_date,
    end_date,
    meta_json
  )
#> # A tibble: 1 x 8
#>   snapshot_id         status snapshot_hash  bar_count instrument_count start_date end_date
#>   <chr>               <chr>  <chr>              <int>            <int> <chr>      <chr>
#> 1 csv_bridge_snapshot SEALED e80b4f4f7df20~        22                2 2019-01-0~ 2019-01~
#> # i 1 more variable: meta_json <chr>
```

`bar_count` and `instrument_count` are live counts from the sealed
snapshot tables. The raw `meta_json` is envelope metadata on the
snapshot row; seal-time metadata inside it uses `n_bars` and
`n_instruments`. Snapshot identity does not come from that metadata.
`snapshot_hash` identifies the normalized bars and instruments only, so
adding a human description to `meta_json` does not change the artifact
hash.

Load the sealed snapshot before constructing the experiment. This is the
same handle you would use in a later R session.

``` r
csv_snapshot <- ledgr_snapshot_load(
  csv_db_path,
  snapshot_id = csv_snapshot_id,
  verify = TRUE
)

csv_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  targets["DEMO_01"] <- params$qty
  targets
}

csv_exp <- ledgr_experiment(
  snapshot = csv_snapshot,
  strategy = csv_strategy,
  opening = ledgr_opening(cash = 10000)
)

csv_bt <- ledgr_run(csv_exp, params = list(qty = 1), run_id = "csv_bridge_run")
tail(ledgr_results(csv_bt, what = "equity"), 3)
#> # A tibble: 3 x 6
#>   ts_utc     equity  cash positions_value running_max  drawdown
#>   <date>      <dbl> <dbl>           <dbl>       <dbl>     <dbl>
#> 1 2019-01-11  9997. 9909.            88.4       10000 -0.000311
#> 2 2019-01-14  9996. 9909.            87.6       10000 -0.000388
#> 3 2019-01-15  9996. 9909.            87.0       10000 -0.000445
```

`ledgr_run()` and `ledgr_run_open()` return live handles for durable run
artifacts. The artifacts are already durable when a run completes, and
ordinary result inspection opens and closes read connections per
operation. Use `close(bt)` as explicit resource cleanup in long
sessions, tests, explicit-open workflows, and lazy result cursors. Close
snapshot handles when the workflow is finished.

``` r
close(bt_small)
close(bt_large)
ledgr_snapshot_close(csv_snapshot)
ledgr_snapshot_close(snapshot)
unlink(csv_bars_path)
```

## What’s Next?

For fills, trades, equity rows, and metric definitions, read
`vignette("metrics-and-accounting", package = "ledgr")`. For strategy
authoring, read `vignette("strategy-development", package = "ledgr")`.
