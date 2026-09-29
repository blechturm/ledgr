# Experiment Store


Every committed run is stored with its evidence. By the end of this
article you can find your runs again, label and compare them, see what
produced each one, and reopen them in a later session. For snapshot
creation and data-input boundaries, read
`vignette("data-input-and-snapshots", package = "ledgr")`.

> [!NOTE]
>
> ### Running this yourself
>
> This article is evaluated when rendered. It writes to temporary DuckDB
> stores so package builds and local previews do not leave project
> artifacts behind. In real work, use a project-local path such as
> `artifacts/ledgr_store.duckdb`.


> [!WARNING]
>
> ### Pre-CRAN compatibility
>
> ledgr is pre-CRAN. Store schemas, config hashes, provenance formats, and
> experimental APIs may change before the first CRAN release. Treat stores
> created with pre-CRAN ledgr as research artifacts for the version that
> produced them, and expect to rerun experiments after upgrading.


The examples use `dplyr` for data preparation and compact display. It is
a suggested package used by the vignettes, not part of the
experiment-store contract.

``` r
library(ledgr)
library(dplyr)
data("ledgr_demo_bars", package = "ledgr")
```

## Temporary Snapshot Setup

This article uses a small snapshot in a temporary store from
`ledgr_temp_store()`, so the store examples are self-contained. A real
project passes a persistent path, so its runs outlive the R session. The
full snapshot lifecycle is covered in
`vignette("data-input-and-snapshots", package = "ledgr")`.

``` r
db_path <- ledgr_temp_store(file.path(tempdir(), "ledgr_store_demo.duckdb"))

bars <- ledgr_demo_bars |>
  filter(
    instrument_id %in% c("DEMO_01", "DEMO_02"),
    between(
      ts_utc,
      ledgr_utc("2019-01-01"),
      ledgr_utc("2019-06-30")
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
`ledgr_snapshot_open(db_path, snapshot_id)`.

## Record Two Variants For Comparison

``` r
features <- list(ledgr_ind_sma(20))

trend_strategy <- function(ctx, params) {
  above <- ctx$vec$close > ledgr_signal_feature(ctx, "sma_20")
  ctx |>
    ledgr_selection(where = above, missing = "exclude") |>
    ledgr_target_quantity(ctx, params$qty)
}

exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = trend_strategy,
  features = features,
  opening = ledgr_opening(cash = 10000),
  cost_model = ledgr_cost_zero()
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
```

    # ledgr run list
    # A tibble: 2 x 10
      run_id       label tags  status final_equity total_return complete_performance
      <chr>        <chr> <lgl> <chr>         <dbl> <chr>        <lgl>
    1 trend_qty_5  <NA>  NA    DONE         10042. +0.4%        NA
    2 trend_qty_15 <NA>  NA    DONE         10125. +1.3%        NA
      achieved_end_utc execution_mode reproducibility_level
      <dttm>           <chr>          <chr>
    1 NA               audit_log      tier_1
    2 NA               audit_log      tier_1

    # i INCOMPLETE metrics describe the achieved prefix only.
    # i Full identity and telemetry columns remain available on this tibble.
    # i Inspect one run with ledgr_run_info(snapshot, run_id).

Use labels and tags for mutable human-facing organization.

``` r
snapshot <- snapshot |>
  ledgr_run_label("trend_qty_5", "Baseline quantity") |>
  ledgr_run_tag("trend_qty_5", c("baseline", "trend")) |>
  ledgr_run_tag("trend_qty_15", c("trend", "larger-size"))

ledgr_run_list(snapshot)
```

    # ledgr run list
    # A tibble: 2 x 10
      run_id       label             tags               status final_equity total_return
      <chr>        <chr>             <chr>              <chr>         <dbl> <chr>
    1 trend_qty_5  Baseline quantity baseline, trend    DONE         10042. +0.4%
    2 trend_qty_15 <NA>              larger-size, trend DONE         10125. +1.3%
      complete_performance achieved_end_utc execution_mode reproducibility_level
      <lgl>                <dttm>           <chr>          <chr>
    1 NA                   NA               audit_log      tier_1
    2 NA                   NA               audit_log      tier_1

    # i INCOMPLETE metrics describe the achieved prefix only.
    # i Full identity and telemetry columns remain available on this tibble.
    # i Inspect one run with ledgr_run_info(snapshot, run_id).

Tags and labels do not alter snapshot hashes, strategy hashes, parameter
hashes, config hashes, or result artifacts.

The returned objects are still tibbles. When you need a custom view,
convert to a tibble and select the columns you want.

``` r
ledgr_run_list(snapshot) |>
  as_tibble() |>
  select(run_id, label, tags, status, final_equity, execution_mode)
```

    # A tibble: 2 x 6
      run_id       label             tags               status final_equity execution_mode
      <chr>        <chr>             <chr>              <chr>         <dbl> <chr>
    1 trend_qty_5  Baseline quantity baseline, trend    DONE         10042. audit_log
    2 trend_qty_15 <NA>              larger-size, trend DONE         10125. audit_log

## Inspect And Compare

``` r
info <- ledgr_run_info(snapshot, "trend_qty_5")
info
```

    ledgr Run Info
    ==============

    Run ID:           trend_qty_5
    Label:            Baseline quantity
    Status:           DONE
    Archived:         FALSE
    Tags:             baseline, trend
    Snapshot:         store_demo_snapshot
    Snapshot Hash:    6eeff5ca520c516a61e0228c5ac06d22548c9d74e4e98d1e9f71fccdd2b8a87e
    Feature Set Hash: 7f66b2149bc31cb90d63fa3a985d214ebf16cc1d3a0c698b4013ee5a4798091e
    Risk Chain Hash:  71863d276abfadf01e5451b8feb3ae38690b42c350db22b2740bf990358c0a11
    Config Hash:      20f271989efdb9ba34fca1b21a2e691aca3160d33fa117590b54084cbae8139c
    Strategy Hash:    2e232e77ee059fecf01d125877ea3b9bca61e6a484825fd059ddd3d50985f3fc
    Params Hash:      69e7ad01d1e85237d7f1593f9505f7c45d29bb55766b05abe6c067f0324ba47e
    Reproducibility:  tier_1
    Execution Mode:   audit_log
    Fill Timing:      dense_bar_timestamp
    Timing Version:   N/A
    Elapsed Sec:      0.920
    Persist Features: TRUE
    Cache Hits:       0
    Cache Misses:     2

`ledgr_run_info()` is the detailed metadata view. It includes execution
mode, compact telemetry, status, identity hashes, and reproducibility
tier.

Useful fields include:

| Field | Meaning |
|----|----|
| `run_id`, `status`, `label`, `tags`, `archived` | mutable and immutable run organization fields |
| `snapshot_id`, `snapshot_hash` | sealed data identity |
| `strategy_source_hash`, `strategy_params_hash`, `config_hash` | strategy, parameter, and run-configuration identity |
| `reproducibility_level` | strategy preflight tier recorded with the run |
| `execution_mode`, `elapsed_sec`, `pulse_count` | execution telemetry |
| `persist_features`, `feature_cache_hits`, `feature_cache_misses` | compact feature-engine telemetry |
| `error_msg` | failure diagnostic for non-completed runs |

``` r
comparison <- ledgr_run_compare(snapshot, run_ids = c("trend_qty_5", "trend_qty_15"))
comparison
```

    # ledgr comparison
    # A tibble: 2 x 9
      run_id       label final_equity total_return sharpe_ratio max_drawdown n_trades win_rate
      <chr>        <chr>        <dbl> <chr>               <dbl> <chr>           <int> <chr>
    1 trend_qty_5  Base~       10042. +0.4%               0.838 -0.5%              12 25.0%
    2 trend_qty_15 <NA>        10125. +1.3%               0.851 -1.5%              12 25.0%
    # i 1 more variable: reproducibility_level <chr>

    # i Fill timing comparable: yes (same_timing_convention).
    # i Full identity and telemetry columns remain available on this tibble.
    # i Inspect one run with ledgr_run_info(snapshot, run_id).

Comparison is read-only and does not rerun strategies. `n_trades` counts
closed, realised trade observations, not every fill. A run can have
fills but no closed trades yet, in which case win rate is not defined.

`ledgr_run_compare()` starts from the durable snapshot handle because it
reads stored run artifacts. When you want the comparison to use an
experiment’s metric assumptions, pass that context explicitly:

``` r
exp_comparison <- ledgr_run_compare(
  snapshot,
  run_ids = c("trend_qty_5", "trend_qty_15"),
  metric_context = ledgr_metric_context(exp)
)
```

The printed comparison formats some columns for reading. Programmatic
code gets raw numeric columns from the tibble:

``` r
comparison |>
  select(run_id, final_equity, total_return, sharpe_ratio, max_drawdown, n_trades)
```

    # ledgr comparison
    # A tibble: 2 x 6
      run_id       final_equity total_return sharpe_ratio max_drawdown n_trades
      <chr>               <dbl> <chr>               <dbl> <chr>           <int>
    1 trend_qty_5        10042. +0.4%               0.838 -0.5%              12
    2 trend_qty_15       10125. +1.3%               0.851 -1.5%              12

    # i Fill timing comparable: yes (same_timing_convention).
    # i Inspect one run with ledgr_run_info(snapshot, run_id).

For report writing, coerce the comparison to a data frame or tibble
before formatting percentages yourself:

``` r
comparison_report <- comparison |>
  as_tibble() |>
  select(run_id, final_equity, total_return, sharpe_ratio, max_drawdown)

comparison_report
```

    # A tibble: 2 x 5
      run_id       final_equity total_return sharpe_ratio max_drawdown
      <chr>               <dbl>        <dbl>        <dbl>        <dbl>
    1 trend_qty_5        10042.      0.00418        0.838     -0.00499
    2 trend_qty_15       10125.      0.0125         0.851     -0.0148

After selecting a run, reopen it and inspect the underlying result
tables rather than parsing the printed comparison:

``` r
best_run_id <- comparison |>
  arrange(desc(total_return)) |>
  pull(run_id) |>
  first()

best_bt <- ledgr_run_open(snapshot, best_run_id)
tail(ledgr_results(best_bt, what = "equity"), 3)
```

    # A tibble: 3 x 6
      ts_utc     equity   cash positions_value running_max drawdown
      <date>      <dbl>  <dbl>           <dbl>       <dbl>    <dbl>
    1 2019-06-26 10125. 10125.               0      10201. -0.00743
    2 2019-06-27 10125. 10125.               0      10201. -0.00743
    3 2019-06-28 10125. 10125.               0      10201. -0.00743

``` r
close(best_bt)
```

## Inspect Stored Strategy Source

Completed runs keep strategy provenance in the experiment store: the
source text, parameters, hashes and dependency metadata that produced
each run. `ledgr_run_strategy(snapshot, run_id, trust = FALSE)` reads
them without executing anything;
`vignette("reproducibility", package = "ledgr")` teaches that reader and
when trusted recovery is appropriate.

When a run ID is missing, store lookup helpers fail with class
`ledgr_run_not_found`, so code can tell a typo from other store errors:

``` r
tryCatch(
  ledgr_run_info(snapshot, "missing_run"),
  ledgr_run_not_found = function(error) class(error)[[1]]
)
```

    [1] "ledgr_run_not_found"

## Reopen A Completed Run In A Later Session

`ledgr_run_open()` reconstructs a completed run handle from stored
artifacts. It does not recompute the strategy. This is useful when you
want full result tables or plots after restarting R.

``` r
reopened <- ledgr_run_open(snapshot, "trend_qty_5")
summary(reopened)
```

    ledgr Backtest Summary
    ======================

    Performance Metrics:
      Total Return:        0.42%
      Annualized Return:   0.82%
      Max Drawdown:        -0.50%

    Risk Metrics:
      Risk-Free Rate:      0.00% annual
      Annualization:       252 periods/year (US equity daily)
      Volatility (annual): 0.98%
      Sharpe Ratio:        0.838

    Trade Statistics:
      Closed Trades:       12
      Win Rate:            25.00%
      Avg Trade:           $3.48

    Exposure:
      Time in Market:      66.67%

    Execution Evidence:
      Fill Timing:         dense_bar_timestamp

    Corporate-Action Evidence:
    Corporate actions: NOT SUPPLIED - returns may omit distributions
    Price basis: UNDECLARED - distribution double counting cannot be ruled out
      Full policy record: ledgr_corporate_action_summary(bt)

``` r
tail(ledgr_results(reopened, what = "equity"), 3)
```

    # A tibble: 3 x 6
      ts_utc     equity   cash positions_value running_max drawdown
      <date>      <dbl>  <dbl>           <dbl>       <dbl>    <dbl>
    1 2019-06-26 10042. 10042.               0      10067. -0.00251
    2 2019-06-27 10042. 10042.               0      10067. -0.00251
    3 2019-06-28 10042. 10042.               0      10067. -0.00251

``` r
close(reopened)
```

Only completed runs can be reopened. Failed or incomplete runs remain
inspectable through `ledgr_run_info()`.

Store-level helpers such as `ledgr_run_info()`, `ledgr_run_list()`, and
`ledgr_run_compare()` use the snapshot handle and remain available after
a completed run handle is closed. Result-table helpers such as
`ledgr_results()` need a live or reopened backtest handle.

## Recovery

Most ledgr recovery workflows should start with the high-level store
helpers above:

- use `ledgr_snapshot_open()` to reopen the sealed snapshot store;
- use `ledgr_run_open()` to reopen a completed run handle;
- use `ledgr_run_info()` and `ledgr_run_strategy()` to inspect stored
  metadata and strategy provenance.

The lower-level recovery pair remains public for restart inspection and
maintainer workflows that need to work directly against the store
connection.

`ledgr_db_init(db_path)` opens a DBI connection to a ledgr DuckDB store
and ensures the ledgr schema exists. In normal workflows, ordinary users
usually do not need it because snapshot and run helpers open, verify,
and close the required connections for their own operations.

`ledgr_state_reconstruct(run_id, con)` reconstructs ledgr’s expected
simulated state for one stored run from ledger-backed evidence. It
returns reconstructed state artifacts such as positions, cash, equity,
fills, and trades from the stored run records. It is useful when you are
inspecting a restart boundary, debugging stored evidence, or building a
low-level tool that already owns a DBI connection.

``` r
con <- ledgr_db_init(db_path)
state <- ledgr_state_reconstruct("trend_qty_5", con)
DBI::dbDisconnect(con, shutdown = TRUE)

names(state)
```

    [1] "positions"    "cash"         "pnl"          "equity_curve"

This pair is intentionally not a broker or migration layer. It does not
perform broker reconciliation, prove live restart safety, migrate old
schemas, repair a sealed snapshot, or recover strategy dependencies that
were never captured in the run provenance. Treat it as low-level
inspection over ledgr’s own stored evidence, not as an escape hatch
around the sealed-data and provenance contracts.

## Archive Without Deleting

``` r
snapshot <- snapshot |>
  ledgr_run_archive("trend_qty_15", reason = "larger position kept for reference")

ledgr_run_list(snapshot)
```

    # ledgr run list
    # A tibble: 1 x 10
      run_id      label             tags            status final_equity total_return
      <chr>       <chr>             <chr>           <chr>         <dbl> <chr>
    1 trend_qty_5 Baseline quantity baseline, trend DONE         10042. +0.4%
      complete_performance achieved_end_utc execution_mode reproducibility_level
      <lgl>                <dttm>           <chr>          <chr>
    1 NA                   NA               audit_log      tier_1

    # i INCOMPLETE metrics describe the achieved prefix only.
    # i Full identity and telemetry columns remain available on this tibble.
    # i Inspect one run with ledgr_run_info(snapshot, run_id).

Archiving hides a run from default listings without deleting artifacts.

## Back Up A Closed Store

The experiment store is an ordinary DuckDB file. Back it up only after
every run and snapshot handle using it has been closed.

> [!WARNING]
>
> ### Back up closed stores
>
> Close live handles, then copy or sync the store with the rest of the
> project’s research artifacts.
>
> ``` r
> dir.create("backups", showWarnings = FALSE)
> file.copy(
>   "artifacts/ledgr_store.duckdb",
>   file.path("backups", paste0("ledgr_store_", Sys.Date(), ".duckdb")),
>   overwrite = TRUE
> )
> ```
>
> Do not copy a file while another ledgr process has it open. For a larger
> project, keep the same closed-file rule and use your normal versioned
> backup or sync system.


## Resource Cleanup

`ledgr_run()` and `ledgr_run_open()` return live handles for durable run
artifacts. The artifacts are already durable when a run completes, and
ordinary result inspection opens and closes read connections per
operation. Use `close(bt)` as explicit resource cleanup in long
sessions, tests, and explicit-open workflows. Close snapshot handles
when the workflow is finished.

## Where Next

- `vignette("reproducibility", package = "ledgr")` explains what a
  stored run can and cannot reproduce, and the strategy tiers.
- `vignette("metrics-and-accounting", package = "ledgr")` covers fills,
  trades, equity rows, and metric definitions.
- `vignette("data-input-and-snapshots", package = "ledgr")` covers
  snapshot creation and sealed-data boundaries.
