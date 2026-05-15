Exploratory Sweeps And Candidate Promotion
================

The examples assume the usual vignette setup:

``` r
library(ledgr)
library(dplyr)
```

# Sweep Is Exploration

`ledgr_sweep()` is the lightweight exploration surface. It evaluates a
`ledgr_param_grid()` against a `ledgr_experiment()` and returns a
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

grid <- ledgr_param_grid(
  conservative = list(qty = 10, threshold = 0.010, sma_n = 20),
  moderate     = list(qty = 10, threshold = 0.005, sma_n = 20),
  fast         = list(qty = 20, threshold = 0.005, sma_n = 10)
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

# Parameter Grids And Feature Factories

`ledgr_param_grid()` stores candidate labels and parameter lists. Named
entries become sweep row labels. Unnamed entries receive stable
`grid_<hash>` labels derived from canonical params JSON. These labels
identify sweep candidates; they are not committed run IDs.

Indicator parameters are ordinary sweep parameters when the experiment
uses a feature factory:

``` r
features <- function(params) {
  list(
    ledgr_ind_sma(params$sma_n),
    ledgr_ind_rsi(params$rsi_n)
  )
}

grid <- ledgr_param_grid(
  sma20_rsi14 = list(sma_n = 20, rsi_n = 14, threshold = 0.010, qty = 10),
  sma50_rsi14 = list(sma_n = 50, rsi_n = 14, threshold = 0.010, qty = 10),
  sma50_rsi21 = list(sma_n = 50, rsi_n = 21, threshold = 0.005, qty = 10)
)
```

Each row stores both `params` and `feature_fingerprints`: the requested
parameters and the resolved feature identities actually used by that
candidate.

# Precompute Larger Grids

`precomputed_features` is optional. For small grids, `ledgr_sweep()` can
compute features internally. When the grid has more than 20 combinations
and no precomputed feature payload is supplied, ledgr warns and suggests
`ledgr_precompute_features()`.

Precompute resolves candidate-specific feature factories, deduplicates
shared indicator definitions by fingerprint, and validates the payload
against the snapshot, universe, scoring range, feature engine version,
and grid labels.

# Failure Rows

By default `stop_on_error = FALSE`. Candidate-level failures become rows
with:

- `status = "FAILED"`
- `error_class`
- `error_msg`
- metric columns set to `NA`

Use `stop_on_error = TRUE` when debugging a single failing candidate and
you want ledgr to rethrow the first failure.

Contract errors still abort before or during the sweep. Invalid grids,
invalid precomputed feature payloads, including snapshot-hash
mismatches, and Tier 3 strategy preflight failures are not candidate
results.

# Seeds, Provenance, And Promotion Context

When `seed` is supplied to `ledgr_sweep()`, each candidate receives a
stable `execution_seed` derived from the master seed, the candidate
label, and the candidate params. `ledgr_promote()` forwards that exact
seed into `ledgr_run()` so a promoted same-snapshot candidate can
reproduce the selected sweep result.

Each row also carries compact `provenance`, including snapshot hash,
strategy hash, feature-set hash, master seed, seed contract, and
evaluation scope. Provenance records what ran. It does not prove that
your selection process was out-of-sample.

Promoted runs write durable promotion context. You can inspect it later:

``` r
context <- ledgr_promotion_context(test_run)
context$selected_candidate
context$source_sweep

ledgr_run_promotion_context(test_exp, "momentum_locked_test")
ledgr_run_info(test_exp$snapshot, "momentum_locked_test")$promotion_context
```

The context stores a compact selected-candidate record, source-sweep
metadata, and the filtered/sorted candidate-summary view that was passed
to `ledgr_candidate()`. It does not store full ledger rows, full equity
curves, or a complete sweep artifact.

For result inspection after promotion, use the normal run tools such as
`summary(test_run)`, `ledgr_compute_metrics(test_run)`, and
`ledgr_compare_runs()`. See
`vignette("metrics-and-accounting", package = "ledgr")` for the event,
fills, equity, and metric views.

# Explicit Non-Goals

v0.1.8 sweep mode does not ship:

- automatic ranking, objectives, or `ledgr_tune()`
- parallel sweep execution
- walk-forward, PBO, or CSCV helpers
- risk-layer insertion
- public cost-model factories
- paper/live trading adapters
- intraday-specific support
- `ledgr_save_sweep()` or full sweep artifact persistence

The full sweep-artifact idea is deferred. v0.1.8 stores selection
context on promoted runs instead.
