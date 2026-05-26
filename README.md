
# ledgr

<img src="man/figures/logo.svg" align="right" alt="ledgr logo" width="160" class="ledgr-readme-logo" />

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

ledgr connects to the R finance ecosystem through adapters.

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
    between(ts_utc, ledgr::ledgr_utc("2019-01-01"), ledgr::ledgr_utc("2019-06-30"))
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
every run uses. The setup is not overhead. The setup is the audit trail.

``` r
snapshot <- ledgr_snapshot_from_df(bars)
```

First-contact examples use the demo SMA-crossover strategy fixture. It
is a small teaching strategy, not an investment recommendation. The
feature map stays explicit so the two namespaces are visible:
`feature_params` materialize indicators, while `params` are the values
the strategy reads at each pulse.

``` r
features <- ledgr_feature_map(
  fast = ledgr_ind_sma(ledgr_param("fast_n")),
  slow = ledgr_ind_sma(ledgr_param("slow_n"))
)

strategy <- ledgr_demo_sma_crossover_strategy()
```

Bundle the snapshot, strategy, indicators, starting state, and execution
options into an experiment. Construction validates the object; it does
not run the strategy or write run artifacts.

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
#> Snapshot ID: snapshot_20260526_141220_0614
#> Database:    <temporary DuckDB path>
#> Universe:    2 instruments
#> Features:    2 mapped
#> Opening:     cash=10000, positions=0
#> Mode:        audit_log
#> Metrics:     US equity daily (252 days/year * 1 bars/day = 252 bars/year)
```

Run the experiment with explicit parameters.

``` r
bt <- exp |>
  ledgr_run(
    feature_params = list(fast_n = 10L, slow_n = 40L),
    params = list(qty = 10, threshold = 0),
    run_id = "readme_sma_crossover"
  )

bt
#> ledgr Backtest Results
#> ======================
#>
#> Run ID:         readme_sma_crossover
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

Inspect result views. These are derived from the recorded event ledger.

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
ledgr_results(bt, what = "trades")
#> # A tibble: 2 x 9
#>   event_seq ts_utc     instrument_id side    qty price   fee realized_pnl action
#>       <int> <date>     <chr>         <chr> <dbl> <dbl> <dbl>        <dbl> <chr>
#> 1         3 2019-04-23 DEMO_01       SELL     10 102.      0         27.4 CLOSE
#> 2         4 2019-06-13 DEMO_02       SELL     10  76.5     0         79.4 CLOSE
```

## Compare Runs

Run another parameter set against the same experiment and compare stored
results. Comparison reads existing artifacts; it does not recompute
strategies.

``` r
bt_qty_20 <- exp |>
  ledgr_run(
    feature_params = list(fast_n = 10L, slow_n = 40L),
    params = list(qty = 20, threshold = 0),
    run_id = "readme_sma_crossover_qty_20"
  )

ledgr_compare_runs(snapshot, run_ids = c("readme_sma_crossover", "readme_sma_crossover_qty_20"))
#> # ledgr comparison
#> # A tibble: 2 x 9
#>   run_id       label final_equity total_return sharpe_ratio max_drawdown n_trades win_rate
#>   <chr>        <chr>        <dbl> <chr>               <dbl> <chr>           <int> <chr>
#> 1 readme_sma_~ <NA>        10107. +1.1%                1.35 -0.8%               2 100.0%
#> 2 readme_sma_~ <NA>        10214. +2.1%                1.36 -1.5%               2 100.0%
#> # i 1 more variable: reproducibility_level <chr>
#>
#> # i Full identity and telemetry columns remain available on this tibble.
#> # i Inspect one run with ledgr_run_info(snapshot, run_id).
```

## Explore A Sweep

Use `ledgr_sweep()` for lightweight exploration. Active-alias sweeps
keep feature parameters and strategy parameters separate, then compose
them into an executable grid. Sweep results are candidate summaries, not
committed run artifacts, and ledgr does not rank candidates
automatically.

``` r
feature_grid <- ledgr_feature_grid(
  fast_n = c(10L, 20L),
  slow_n = c(40L, 80L),
  .filter = fast_n < slow_n
)

strategy_grid <- ledgr_strategy_grid(
  threshold = c(0, 0.01),
  qty = c(10, 20)
)

grid <- ledgr_grid_cross(features = feature_grid, strategy = strategy_grid)
precomputed <- ledgr_precompute_features(exp, grid)
results <- ledgr_sweep(exp, grid, precomputed_features = precomputed, seed = 2026)

candidate <- results |>
  filter(status == "DONE") |>
  arrange(desc(sharpe_ratio)) |>
  ledgr_candidate(1)

bt_promoted <- ledgr_promote(
  exp,
  candidate,
  run_id = "readme_promoted_sweep_candidate",
  note = "Same-snapshot replay of an exploratory candidate."
)
```

Same-snapshot replay is useful for audit and debugging, but it remains
in-sample. For evaluation, sweep on a manually created train snapshot,
lock the selected params with `ledgr_candidate()`, and promote against a
held-out test snapshot with `require_same_snapshot = FALSE`. The
[`sweeps`](https://blechturm.github.io/ledgr/articles/sweeps.html)
article shows that train/sweep/test discipline and explains
`execution_seed`, row-level provenance, promotion context, failure rows,
and deferred sweep artifact persistence.

Stored strategy provenance is inspectable without rerunning or
evaluating the strategy source. Use the default `trust = FALSE` path for
safe source and metadata inspection:

``` r
stored_strategy <- ledgr_extract_strategy(snapshot, "readme_sma_crossover", trust = FALSE)
source_lines <- strsplit(stored_strategy$strategy_source_text, "\n", fixed = TRUE)[[1]]
cat(paste(c(head(source_lines, 8), "..."), collapse = "\n"))
#> function (ctx, params)
#> {
#>     qty <- params$qty
#>     threshold <- params$threshold
#>     if (is.null(qty) || length(qty) != 1L || !is.numeric(qty) || is.na(qty) || !is.finite(qty)) {
#>         stop(structure(list(message = "`params$qty` must be a finite numeric scalar."), class = c("ledgr_invalid_demo_strategy_params", "ledgr_invalid_strategy_params", "simpleError", "error", "condition")))
#>     }
#>     if (is.null(threshold) || length(threshold) != 1L || !is.numeric(threshold) || is.na(threshold) || !is.finite(threshold)) {
#> ...
```

Hash verification proves stored-text identity, not code safety. Use
`trust = TRUE` only when you already trust the store and intentionally
want to recover a function object.

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
ledgr_run_info(snapshot, "readme_sma_crossover")
```

After snapshot creation or loading, normal experiment-store operations
take the snapshot handle rather than a raw database path.

## Ecosystem

ledgr connects to the R finance ecosystem through adapters. The core is
narrow by design:
`data -> pulse -> decision -> fill -> ledger event -> portfolio state`.
Everything outside that sequence, such as data vendors, indicators,
charting, and analytics, can be provided by packages that already do
those things well.

| ledgr owns | Other packages can own |
|----|----|
| sealed snapshots and hashes | market-data acquisition |
| pulse construction and no-lookahead contexts | indicator calculations through adapters |
| target validation, fills, and ledger events | charting and visualization |
| run identity, provenance, and result reconstruction | downstream analytics and reporting |

This posture is deliberate. If you want an all-in-one charting or
array-backtesting package, ledgr may not be the shortest path. Choose
ledgr when you want the audit trail and adapter boundary to be explicit.

## Scope

The current ledgr research API is experiment-first and includes
sequential exploratory sweep support. It does not ship automatic
ranking, `ledgr_tune()`, parallel sweep, walk-forward/PBO/CSCV helpers,
full sweep artifact persistence, broker adapters, paper trading, live
trading, or short-selling semantics. Those are separate roadmap items
with different state and safety requirements.

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

Start with the pkgdown site for the full article set:
<https://blechturm.github.io/ledgr/>.

Installed package help remains available from R:

``` r
help(package = "ledgr")
vignette(package = "ledgr")
```

## Pre-CRAN Compatibility

ledgr is not yet on CRAN. Until the first CRAN release, stored
artifacts, database schemas, config hashes, provenance formats, and
experimental APIs may change without backward compatibility or a
deprecation cycle. Treat pre-CRAN ledgr as a research/development
package and expect to rerun experiments after upgrading. Once ledgr is
released on CRAN, the project will define an explicit compatibility and
deprecation policy.
