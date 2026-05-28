# Experiment Store


The experiment store is the DuckDB file that keeps sealed market data,
run artifacts, provenance, labels, tags, archive state, and compact
telemetry together. In real projects, put that file somewhere boring and
durable, such as `artifacts/ledgr_store.duckdb`.

``` text
sealed snapshot -> committed runs -> list / inspect / compare / reopen
```

`run_id` is immutable. Labels, tags, and archive state are mutable
metadata. The store is useful because the explanation survives the R
session: you can reopen a completed run, inspect the source provenance,
compare stored runs, and write a review from the same evidence file.

This article is about durable storage and later inspection, not strategy
design or statistical validation.

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
> ledgr is pre-CRAN. Store schemas, config hashes, provenance formats,
> and experimental APIs may change before the first CRAN release. Treat
> stores created with pre-CRAN ledgr as research artifacts for the
> version that produced them, and expect to rerun experiments after
> upgrading.

The examples use `dplyr` for data preparation and compact display. It is
a suggested package used by the vignettes, not part of the
experiment-store contract.

``` r
library(ledgr)
library(dplyr)
data("ledgr_demo_bars", package = "ledgr")
```

## Snapshot Lifecycle And Data Input

Market data and derived data have different lifecycle rules in ledgr. A
sealed snapshot freezes the real market-data input and its hash. If you
need more instruments, more dates, corrected bars, or tick-derived bars,
create a new snapshot. Indicators, runs, labels, tags, comparisons, and
telemetry are derived from sealed market data and can be added later
without mutating the snapshot.

Snapshot lifecycle anti-patterns:

- appending bars to a sealed snapshot in place;
- resealing different data under the same snapshot ID;
- deleting snapshots that stored runs still reference;
- mixing live ticks into a backtest snapshot;
- filling data gaps with undocumented synthetic corrections.

If the evidence changes, create a new snapshot. That is what makes later
comparison meaningful.

This vignette uses `tempfile()` so it can run without writing into your
project directory. For real research, use `artifacts/ledgr_store.duckdb`
and a snapshot ID you will recognize later.

``` r
db_path <- file.path(tempdir(), "ledgr_store_demo.duckdb")
if (file.exists(db_path)) {
  unlink(db_path)
}

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
`ledgr_snapshot_load(db_path, snapshot_id)`.

If your market data starts in CSV, seal the CSV into the same kind of
durable store. The CSV must contain `instrument_id`, `ts_utc`, `open`,
`high`, `low`, and `close`; `volume` is optional. ledgr imports only
those canonical bar columns. Other CSV columns are ignored and do not
become part of the sealed snapshot or its hash.

``` r
snapshot <- ledgr_snapshot_from_csv(
  "data/daily_bars.csv",
  db_path = "artifacts/ledgr_store.duckdb",
  snapshot_id = "eod_2019_h1"
)
```

In any later session, recover the handle without re-sealing the data:

``` r
snapshot <- ledgr_snapshot_load(
  "artifacts/ledgr_store.duckdb",
  snapshot_id = "eod_2019_h1"
)
```

CSV and local data validation happens while the snapshot is created and
sealed, before a strategy can run. Missing columns, unparseable
timestamps, duplicate `instrument_id`/`ts_utc` rows, and OHLC violations
are snapshot import problems. They are not strategy execution errors.

Yahoo imports follow the same lifecycle, but the adapter downloads bars
before sealing the snapshot:

``` r
snapshot <- ledgr_snapshot_from_yahoo(
  symbols = c("SPY", "QQQ"),
  from = "2019-01-01",
  to = "2019-06-30",
  db_path = "artifacts/ledgr_store.duckdb",
  snapshot_id = "yahoo_2019_h1"
)
```

The returned handle is already sealed. Calling
`ledgr_snapshot_seal(snapshot)` again is an idempotent verification
step: on a snapshot handle it returns an invisible structured list with
`$hash` and `$snapshot`; on a low-level DBI connection plus
`snapshot_id` it returns the hash string. Use
`ledgr_snapshot_info(snapshot)` to inspect `status`, `snapshot_hash`,
`bar_count`, `instrument_count`, `start_date`, `end_date`, and raw
`meta_json`. The dates are ISO UTC values. `meta_json` is envelope
metadata; snapshot identity comes from normalized bars and instruments,
not from human descriptions.

> [!WARNING]
>
> ### Yahoo data boundary
>
> Yahoo support is a convenience adapter, not a data-vendor guarantee.
> It uses `quantmod::getSymbols()` and therefore requires the suggested
> `quantmod` package and network access. Package startup or S3
> method-overwrite messages printed while quantmod loads are not ledgr
> snapshot warnings. The adapter seals the Yahoo `.Open`, `.High`,
> `.Low`, `.Close`, and `.Volume` columns as returned by quantmod; it
> does not rewrite OHLC values from Yahooâ€™s adjusted-close column. If
> your research requires split/dividend-adjusted OHLC bars, prepare
> those bars explicitly and seal them with `ledgr_snapshot_from_df()` or
> `ledgr_snapshot_from_csv()`.

``` r
yahoo_info <- ledgr_snapshot_info(snapshot)
yahoo_seal <- ledgr_snapshot_seal(snapshot)
yahoo_hash <- yahoo_seal$hash
stopifnot(identical(yahoo_info$snapshot_hash[[1]], yahoo_hash))
```

Snapshot metadata uses these public field names:

| Field | Meaning |
|----|----|
| `status` | snapshot lifecycle state, usually `SEALED` after helper creation |
| `snapshot_hash` | hash of normalized bars and instruments |
| `bar_count` | current count of rows in `snapshot_bars` |
| `instrument_count` | current count of rows in `snapshot_instruments` |
| `start_date`, `end_date` | seal-time date range parsed from metadata |
| `meta_json` | raw JSON envelope containing user metadata plus seal metadata |

Seal metadata inside `meta_json` may use internal names such as `n_bars`
and `n_instruments`. The structured columns from `ledgr_snapshot_info()`
are `bar_count` and `instrument_count`; use those names in programmatic
code.

## Backup Conventions

The store is an ordinary DuckDB file. Back it up when no ledgr process
has it open.

> [!WARNING]
>
> ### Back up closed stores
>
> Close run and snapshot handles, then copy or sync the closed store
> file. A simple project pattern is:
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
> For larger projects, use the same closed-file rule with your normal
> backup or sync tool. Do not rely on the phrase â€œordinary backup
> disciplineâ€ without a specific copy/sync pattern for the store file.

## Record Two Variants For Comparison

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
```

    # ledgr run list
    # A tibble: 2 x 8
      run_id label tags  status final_equity total_return execution_mode reproducibility_level
      <chr>  <chr> <lgl> <chr>         <dbl> <chr>        <chr>          <chr>
    1 trend~ <NA>  NA    DONE         10042. +0.4%        audit_log      tier_1
    2 trend~ <NA>  NA    DONE         10125. +1.3%        audit_log      tier_1

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
    # A tibble: 2 x 8
      run_id label tags  status final_equity total_return execution_mode reproducibility_level
      <chr>  <chr> <chr> <chr>         <dbl> <chr>        <chr>          <chr>
    1 trend~ Base~ base~ DONE         10042. +0.4%        audit_log      tier_1
    2 trend~ <NA>  larg~ DONE         10125. +1.3%        audit_log      tier_1

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

    Run ID:          trend_qty_5
    Label:           Baseline quantity
    Status:          DONE
    Archived:        FALSE
    Tags:            baseline, trend
    Snapshot:        store_demo_snapshot
    Snapshot Hash:   6eeff5ca520c516a61e0228c5ac06d22548c9d74e4e98d1e9f71fccdd2b8a87e
    Config Hash:     843e364a4ba307690fc41d99ea87eba1edb81e5e5732bcf62180aa18aba83669
    Strategy Hash:   c413dd07662e72e003890ed30da11b77113c505d17f99e99dbe701e7485e5236
    Params Hash:     f1bc254d9d195c0cff7056644ba06c2ba5968db959e689837a76853dd47990ae
    Reproducibility: tier_1
    Execution Mode:  audit_log
    Elapsed Sec:     1.86
    Persist Features:TRUE
    Cache Hits:      0
    Cache Misses:    2

`ledgr_run_info()` is the detailed metadata view. It includes execution
mode, compact telemetry, status, identity hashes, and reproducibility
tier.

Useful fields include:

| Field | Meaning |
|----|----|
| `run_id`, `status`, `label`, `tags`, `archived` | mutable and immutable run organization fields |
| `snapshot_id`, `snapshot_hash`, `data_hash` | sealed data identity |
| `strategy_source_hash`, `strategy_params_hash`, `config_hash` | strategy, parameter, and run-configuration identity |
| `reproducibility_level` | strategy preflight tier recorded with the run |
| `execution_mode`, `elapsed_sec`, `pulse_count` | execution telemetry |
| `persist_features`, `feature_cache_hits`, `feature_cache_misses` | compact feature-engine telemetry |
| `error_msg` | failure diagnostic for non-completed runs |

``` r
comparison <- ledgr_compare_runs(snapshot, run_ids = c("trend_qty_5", "trend_qty_15"))
comparison
```

    # ledgr comparison
    # A tibble: 2 x 9
      run_id       label final_equity total_return sharpe_ratio max_drawdown n_trades win_rate
      <chr>        <chr>        <dbl> <chr>               <dbl> <chr>           <int> <chr>
    1 trend_qty_5  Base~       10042. +0.4%               0.838 -0.5%              12 25.0%
    2 trend_qty_15 <NA>        10125. +1.3%               0.851 -1.5%              12 25.0%
    # i 1 more variable: reproducibility_level <chr>

    # i Full identity and telemetry columns remain available on this tibble.
    # i Inspect one run with ledgr_run_info(snapshot, run_id).

Comparison is read-only and does not rerun strategies. `n_trades` counts
closed, realised trade observations, not every fill. A run can have
fills but no closed trades yet, in which case win rate is not defined.

`ledgr_compare_runs()` starts from the durable snapshot handle because
it reads stored run artifacts. When you want the comparison to use an
experimentâ€™s metric assumptions, pass that context explicitly:

``` r
comparison <- ledgr_compare_runs(
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

    # i Full identity and telemetry columns remain available on this tibble.
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
```

    ledgr Extracted Strategy
    ========================

    Run ID:          trend_qty_5
    Reproducibility: tier_1
    Source Hash:     c413dd07662e72e003890ed30da11b77113c505d17f99e99dbe701e7485e5236
    Params Hash:     f1bc254d9d195c0cff7056644ba06c2ba5968db959e689837a76853dd47990ae
    Hash Verified:   TRUE
    Trust:           FALSE
    Source Available:TRUE

The source text is just data in this mode.

``` r
writeLines(stored_strategy$strategy_source_text)
```

    function (ctx, params)
    {
        targets <- ctx$flat()
        for (id in ctx$universe) {
            sma <- ctx$feature(id, "sma_20")
            if (is.finite(sma) && ctx$close(id) > sma) {
                targets[id] <- params$qty
            }
        }
        targets
    }

Hash verification proves stored-text identity, not code safety. Use
`trust = TRUE` only when you already trust the experiment store and
intentionally want ledgr to parse and evaluate the stored text into a
function object. Legacy/pre-provenance runs remain inspectable through
`ledgr_run_info()` and stored result tables, but their strategy function
cannot be recovered from provenance alone.

When a run ID is missing, store lookup helpers fail with class
`ledgr_run_not_found`:

``` r
ledgr_run_info(snapshot, "missing_run")
```

Trusted recovery can be used to rerun a stored strategy only after you
have decided that evaluating the stored source is acceptable:

``` r
recovered <- ledgr_extract_strategy(snapshot, "trend_qty_5", trust = TRUE)

rerun_exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = recovered$strategy_function,
  features = features,
  opening = ledgr_opening(cash = 10000)
)

ledgr_run(
  rerun_exp,
  params = recovered$strategy_params,
  run_id = "trend_qty_5_rerun"
)
```

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
      Total Trades:        12
      Win Rate:            25.00%
      Avg Trade:           $3.48

    Exposure:
      Time in Market:      66.67%

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
`ledgr_compare_runs()` use the snapshot handle and remain available
after a completed run handle is closed. Result-table helpers such as
`ledgr_results()` need a live or reopened backtest handle.

## Archive Without Deleting

``` r
snapshot <- snapshot |>
  ledgr_run_archive("trend_qty_15", reason = "larger position kept for reference")

ledgr_run_list(snapshot)
```

    # ledgr run list
    # A tibble: 1 x 8
      run_id label tags  status final_equity total_return execution_mode reproducibility_level
      <chr>  <chr> <chr> <chr>         <dbl> <chr>        <chr>          <chr>
    1 trend~ Base~ base~ DONE         10042. +0.4%        audit_log      tier_1

    # i Full identity and telemetry columns remain available on this tibble.
    # i Inspect one run with ledgr_run_info(snapshot, run_id).

Archiving hides a run from default listings without deleting artifacts.

## Current Feature Persistence Boundary

Run metadata records whether feature persistence was enabled, and pulse
inspection lets you view registered feature values at one decision time.
Public feature inspection is intentionally scoped to feature contracts,
warmup feasibility, and pulse-time feature views:

- `ledgr_feature_contracts(features)` shows declared feature
  requirements;
- `ledgr_feature_contract_check(snapshot, features)` checks whether
  those requirements are achievable in a sealed snapshot;
- `ledgr_pulse_snapshot()` plus `ledgr_pulse_features()` or
  `ledgr_pulse_wide()` inspects one pulse.

A full persisted feature-series retrieval API remains outside the
current experiment-store surface; use precompute and sweep provenance
when you need feature-set identity at sweep scale.

External point-in-time regressors are a separate future data surface.
The public roadmap keeps that work out of v0.1.8.5 and tracks it for a
later cycle so vintage semantics, lineage, ASOF lookup, and leakage
prevention can be designed explicitly rather than smuggled into CSV bars
or active aliases.

## Resource Cleanup

`ledgr_run()` and `ledgr_run_open()` return live handles for durable run
artifacts. The artifacts are already durable when a run completes, and
ordinary result inspection opens and closes read connections per
operation. Use `close(bt)` as explicit resource cleanup in long
sessions, tests, explicit-open workflows, and lazy result cursors. Close
snapshot handles when the workflow is finished.

## Task Intent Map

Use this map when you know the task but not the function name:

| Intent | Start here |
|----|----|
| Seal in-memory bars | `ledgr_snapshot_from_df()` |
| Seal a local CSV | `ledgr_snapshot_from_csv()` |
| Fetch and seal Yahoo bars | `ledgr_snapshot_from_yahoo()` |
| Control low-level CSV create/import/seal lifecycle | `?ledgr_snapshot_import_bars_csv` |
| Reopen an existing store | `ledgr_snapshot_load()` |
| List stored runs | `ledgr_run_list()` |
| Compare durable runs | `ledgr_compare_runs()` |

Yahoo data is a convenience source. The sealed snapshot is the ledgr
artifact; the remote Yahoo endpoint remains outside ledgrâ€™s
reproducibility boundary.

## Whatâ€™s Next?

For fills, trades, equity rows, and metric definitions, read
`vignette("metrics-and-accounting", package = "ledgr")`. For strategy
authoring, read `vignette("strategy-development", package = "ledgr")`.
