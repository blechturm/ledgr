Exploratory Sweeps And Candidate Promotion
================

The examples assume the usual vignette setup:

``` r
library(ledgr)
library(dplyr)
```

# Sweep Is Exploration

`ledgr_sweep()` is the lightweight exploration surface. It evaluates an
executable grid against a `ledgr_experiment()` and returns a
`ledgr_sweep_results` table. It does not write candidate runs to the
experiment store and it does not choose a winner.

`ledgr_run()` is the committed artifact surface. A promoted candidate
becomes a durable run only when you explicitly select it with
`ledgr_candidate()` and call `ledgr_promote()`, which in turn calls
`ledgr_run()`.

``` text
ledgr_sweep()                 explore
ledgr_candidate()             select one row deliberately
ledgr_promote() / ledgr_run() commit an auditable run
```

Sweep results carry an `evaluation_scope` attribute that defaults to
`"exploratory"`. That label is intentional. A sweep table records what
was run; it does not prove that the selected parameters were evaluated
on held-out data.

# Normal Train/Test Discipline

The recommended workflow is:

``` text
source bars
  -> train snapshot
  -> test snapshot
  -> sweep on train snapshot
  -> select candidate and lock params
  -> evaluate the locked params on the test snapshot
```

You can create the train and test snapshots manually by filtering source
bars before calling `ledgr_snapshot_from_df()`.

``` r
split_at <- ledgr_utc("2022-01-01")

train_bars <- bars |>
  filter(ts_utc < split_at)

test_bars <- bars |>
  filter(ts_utc >= split_at)

train_snapshot <- ledgr_snapshot_from_df(train_bars)
test_snapshot  <- ledgr_snapshot_from_df(test_bars)

train_exp <- ledgr_experiment(
  snapshot = train_snapshot,
  strategy = strategy,
  features = features,
  opening = ledgr_opening(cash = 100000)
)

test_exp <- ledgr_experiment(
  snapshot = test_snapshot,
  strategy = strategy,
  features = features,
  opening = ledgr_opening(cash = 100000)
)

feature_grid <- ledgr_feature_grid(
  fast_n = c(10L, 20L),
  slow_n = c(40L, 80L),
  .filter = fast_n < slow_n
)

strategy_grid <- ledgr_strategy_grid(
  threshold = c(0.000, 0.005),
  qty = c(10, 20)
)

grid <- ledgr_grid_cross(
  features = feature_grid,
  strategy = strategy_grid
)
grid <- ledgr_grid_add_baseline(
  grid,
  flat = list(
    feature = list(fast_n = 10L, slow_n = 40L),
    strategy = list(threshold = 0, qty = 0)
  )
)

precomputed <- ledgr_precompute_features(train_exp, grid)
results <- ledgr_sweep(train_exp, grid, precomputed_features = precomputed, seed = 2026)
```

Rank explicitly with ordinary R tools. ledgr does not own objective
functions or automatic candidate ranking.

``` r
ranked <- results |>
  filter(status == "DONE") |>
  arrange(desc(sharpe_ratio))

candidate <- ledgr_candidate(ranked, 1)
```

Keep the `ledgr_sweep_results` object and its list columns intact until
after selection. Converting to `as.data.frame()` is fine for display,
but it drops the class and can remove the metadata `ledgr_candidate()`
uses to preserve filtered or sorted selection context.

The sweep table has one metric context for all candidate metrics.
Inspect it before ranking if the annualization or risk-free-rate
assumption matters:

``` r
ledgr_metric_context(results)
```

To evaluate out of sample, promote against the held-out experiment and
make the cross-snapshot choice explicit:

``` r
test_run <- ledgr_promote(
  test_exp,
  candidate,
  run_id = "momentum_locked_test",
  note = "Locked params selected from train sweep.",
  require_same_snapshot = FALSE
)
```

`require_same_snapshot = FALSE` is required because the candidate came
from the train snapshot and the committed run is intentionally executed
on the test snapshot.

# Same-Snapshot Replay Is Secondary

Sometimes you want to commit the selected candidate on the same snapshot
that produced the sweep result. That is useful for audit, diagnostics,
or comparing a single candidate against the sweep summary. It remains
in-sample.

``` r
train_run <- ledgr_promote(
  train_exp,
  candidate,
  run_id = "momentum_locked_train",
  note = "Same-snapshot replay of selected exploratory candidate."
)
```

Same-snapshot promotion is protected by default. `ledgr_promote()`
requires the candidate snapshot hash to match the target experiment
unless you deliberately set `require_same_snapshot = FALSE`.

Same-snapshot replay is the direct way to verify that a selected row is
commit-ready. Compare the sweep summary with the committed run’s result
tables and metrics:

``` r
selected_row <- candidate$row
train_metrics <- ledgr_compute_metrics(train_run)
train_equity <- ledgr_results(train_run, what = "equity")

stopifnot(isTRUE(all.equal(
  selected_row$final_equity[[1]],
  tail(train_equity$equity, 1)
)))
stopifnot(isTRUE(all.equal(
  selected_row$sharpe_ratio[[1]],
  train_metrics$sharpe_ratio
)))
```

# Feature Grids And Strategy Grids

Active-alias sweeps use two public namespaces:

``` text
feature params  -> materialize parameterized features
strategy params -> passed to strategy(ctx, params)
```

Declare parameterized indicators with `ledgr_param()` inside a feature
map:

``` r
features <- ledgr_feature_map(
  fast = ledgr_ind_sma(ledgr_param("fast_n")),
  slow = ledgr_ind_sma(ledgr_param("slow_n"))
)

strategy <- ledgr_demo_sma_crossover_strategy()
exp <- ledgr_experiment(snapshot, strategy, features = features)

feature_grid <- ledgr_feature_grid(
  fast_n = c(10L, 20L, 50L),
  slow_n = c(40L, 80L, 200L),
  .filter = fast_n < slow_n
)

strategy_grid <- ledgr_strategy_grid(
  threshold = c(0, 0.01),
  qty = c(50, 100)
)

grid <- ledgr_grid_cross(features = feature_grid, strategy = strategy_grid)
```

Use `.filter` for simple grid-shape constraints such as
`fast_n < slow_n`. Filter expressions are evaluated against the grid
columns with ordinary R operators and base helpers; they do not read run
state, feature data, or caller globals.

Each sweep row stores `feature_params`, `params`, resolved feature
fingerprints, and provenance. The concrete `feature_set_hash` describes
resolved concrete features; `alias_map_hash` describes the active alias
map. Strategies should read the alias-keyed vector with
`ctx$features(id)` and guard it with `passed_warmup()`.

`ledgr_param_grid()` remains available for legacy flat
strategy-parameter grids and exact-ID strategies. For active aliases,
prefer `ledgr_feature_grid()`, `ledgr_strategy_grid()`, and
`ledgr_grid_cross()` so feature materialization inputs are not confused
with strategy runtime parameters.

# Precompute Larger Grids

`precomputed_features` is optional. For small grids, `ledgr_sweep()` can
compute features internally. When the grid has more than 20 combinations
and no precomputed feature payload is supplied, ledgr warns and suggests
`ledgr_precompute_features()`.

Precompute resolves candidate-specific feature factories, deduplicates
shared indicator definitions by fingerprint, and validates the payload
against the snapshot, universe, scoring range, feature engine version,
and grid labels.

The precompute payload is intentionally tied to its inputs.
`ledgr_sweep()` rejects a payload built for a different snapshot hash,
universe, scoring range, grid labels, parameter hashes, feature engine
version, or resolved feature fingerprints. Recompute the payload after
changing any of those inputs.

Feature-factory failures are candidate-level when they occur while
resolving a specific candidate’s features and `stop_on_error = FALSE`.
The failed row keeps the candidate label, params, error class, and error
message so the bad combination can be inspected without losing the rest
of the sweep.

# Failure Rows

By default `stop_on_error = FALSE`. Candidate-level failures become rows
with:

- `status = "FAILED"`
- `error_class`
- `error_msg`
- `params`
- `warnings`
- `feature_fingerprints`
- `provenance`
- metric columns set to `NA`

Use `stop_on_error = TRUE` when debugging a single failing candidate and
you want ledgr to rethrow the first failure. When asserting on a
rethrown strategy failure in tests, prefer
`inherits(e, "ledgr_strategy_error")` rather than exact class-vector
equality; the original strategy error class is preserved alongside
ledgr’s generic class.

`ledgr_candidate()` rejects failed rows by default. Use
`ledgr_candidate(results, which, allow_failed = TRUE)` only for
diagnostic extraction of the failed candidate’s params, error, warnings,
and provenance. `ledgr_promote()` still rejects failed candidates;
promotion is only for committing a runnable candidate through
`ledgr_run()`.

For failed-row inspection, keep list columns intact and extract only the
field you need:

``` r
failed <- subset(as.data.frame(results), status == "FAILED")
failed$error_class
failed$error_msg
failed$params[[1]]
failed$warnings[[1]]
failed$feature_fingerprints[[1]]
failed$provenance[[1]]$feature_set_hash
```

Contract errors still abort before or during the sweep. Invalid grids,
invalid precomputed feature payloads, including snapshot-hash
mismatches, and Tier 3 strategy preflight failures are not candidate
results.

# Seeds, Provenance, And Promotion Context

When `seed` is supplied to `ledgr_sweep()`, each candidate receives a
stable `execution_seed` derived from the master seed, the candidate
label, and the candidate params. `ledgr_promote()` forwards that exact
seed into `ledgr_run()` so a promoted same-snapshot candidate can
reproduce the selected sweep result. If `seed = NULL`, row-level
`execution_seed` is `NA` and promotion does not inject a replay seed.

Each row also carries compact `provenance`, including snapshot hash,
strategy hash, feature-set hash, master seed, seed contract, and
evaluation scope. Provenance records what ran. It does not prove that
your selection process was out-of-sample.

The candidate table itself is not a full artifact store. Treat sweep
columns as candidate summaries: `run_id`, `status`, `params`,
`execution_seed`, metric columns, `feature_fingerprints`, `provenance`,
and warning/error fields are the programmatic inspection surface. Full
equity, fills, trades, and ledger rows are created only by committed
runs.

Direct CSV export of the full sweep table can fail because `params`,
`warnings`, `feature_fingerprints`, and `provenance` are list columns.
Export a flat summary instead of inventing a new helper:

``` r
results_df <- as.data.frame(results)
is_flat <- vapply(
  results_df,
  function(x) is.atomic(x) && !is.list(x),
  logical(1)
)
utils::write.csv(results_df[is_flat], "sweep_summary.csv", row.names = FALSE)
```

Keep the full in-memory object for detailed inspection, or extract
list-column fields into explicit scalar columns before writing a richer
report.

Warnings are part of candidate inspection. A candidate can finish with
warnings, including `LEDGR_LAST_BAR_NO_FILL`, when a strategy changes
target on the final available bar and there is no later bar for a
next-open fill. Inspect the row’s warning fields before promotion; after
promotion, inspect the committed run with `summary(test_run)`,
`ledgr_results(test_run, what = "fills")`, and
`ledgr_promotion_context(test_run)`. If the final-bar warning is
expected, extend the snapshot by one executable bar to verify that the
intended target would fill.

Promoted runs write durable promotion context. You can inspect it later:

``` r
context <- ledgr_promotion_context(test_run)
context$selected_candidate
context$source_sweep
ledgr_metric_context(context)
ledgr_metric_context(test_run)

ledgr_run_promotion_context(test_exp, "momentum_locked_test")
ledgr_run_info(test_exp$snapshot, "momentum_locked_test")$promotion_context
```

The context stores a compact selected-candidate record, source-sweep
metadata, and the filtered/sorted candidate-summary view that was passed
to `ledgr_candidate()`. It does not store full ledger rows, full equity
curves, or a complete sweep artifact.

The current research API is one experiment per strategy. When you
compare different strategy functions, create one `ledgr_experiment()`
for each function and compare committed runs or sweep outputs after
execution. A parameter grid varies parameters for a strategy; it does
not switch the strategy function itself.

The source sweep metric context and the committed run metric context
remain separate. Use
`ledgr_metric_context(ledgr_promotion_context(test_run))` for the
context that ranked the candidate, and `ledgr_metric_context(test_run)`
for the committed run’s default analysis context.

For result inspection after promotion, use the normal run tools such as
`summary(test_run)`, `ledgr_compute_metrics(test_run)`, and
`ledgr_compare_runs()`. See
`vignette("metrics-and-accounting", package = "ledgr")` for the event,
fills, equity, and metric views.

# Explicit Non-Goals

Current sweep mode does not ship:

- automatic ranking, objectives, or `ledgr_tune()`
- parallel sweep execution
- walk-forward, PBO, or CSCV helpers
- risk-layer insertion
- public cost-model factories
- paper/live trading adapters
- intraday-specific support
- `ledgr_save_sweep()` or full sweep artifact persistence

The full sweep-artifact idea is deferred. Current sweep mode stores
selection context on promoted runs instead.
