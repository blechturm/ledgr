# ledgr Sweep Mode -- UX Design

**Status:** Accepted proposal. Decisions ready for v0.1.8 ticket cut.
**Scope:** User-facing API, object model, failure semantics, parity contract,
and parallelism guidance for sweep mode. `ledgr_tune()` explicitly deferred
(see Version Assignment).

---

## Mental Model

The research workflow has two distinct phases:

```
ledgr_sweep()              explore     lightweight, no durable run artifact
ledgr_run() / ledgr_tune() commit      durable, full provenance, auditable
```

Sweep produces a candidate summary table. The user picks candidates from it and
commits them deliberately with `ledgr_run()`. Sweep results are never
auto-promoted to the experiment store. A sweep result may carry in-memory
candidate identity metadata needed to promote, rerun, or reject a candidate
deliberately; that metadata is not a durable experiment-store provenance record.

## Evaluation Discipline

Sweep mode makes parameter selection fast and easy. That creates a second
leakage risk that is distinct from no-lookahead strategy execution:

```text
full snapshot -> sweep -> pick best params -> ledgr_run() on the same full
snapshot -> report the committed run
```

That workflow produces a legitimate ledgr artifact, but it is still an
in-sample artifact. The provenance trail records what ran; it does not prove
that the selected parameters were evaluated on data held out from development.

The intended sweep discipline is:

```text
source bars
  -> train snapshot
  -> test snapshot
  -> sweep on train snapshot
  -> lock selected params
  -> optionally commit selected params on the train snapshot
  -> evaluate locked params on the test snapshot with ledgr_run()
```

The first v0.1.8 sweep documentation must teach this as the normal promotion
path. Sweep is for exploration. A held-out snapshot is for evaluation.

### Future Split-Snapshot Helper

A future helper may make the convention explicit:

```r
splits <- ledgr_snapshot_split(
  bars,
  split_date = "2020-01-01",
  train_snapshot_id = "momentum_train",
  test_snapshot_id = "momentum_test",
  db_path = "research/momentum.duckdb"
)

train_snapshot <- splits$train
test_snapshot <- splits$test
```

The exact surface is intentionally not locked here. The minimum design intent
is:

- derive both snapshots from the same source bars;
- seal both snapshots independently;
- preserve snapshot provenance and parent/source metadata where possible;
- make the train/test role visible in snapshot metadata or run provenance;
- keep the promoted test run tied to locked params selected before evaluation.

This helper is not part of v0.1.7.9 and is not required for the first sweep
implementation. Users can already create train and test snapshots manually by
filtering bars before snapshot creation. The helper is a UX layer around that
discipline.

### Walk-Forward Deferred

Walk-forward analysis belongs after sweep mode exists. It depends on the sweep
fold core, parameter-grid execution, feature precomputation, and a clear result
shape for repeated train/evaluate windows.

v0.1.8 should not ship a walk-forward API. It should document the simpler
train/sweep/evaluate workflow first and leave rolling or expanding
walk-forward analysis for a later milestone.

---

## v0.1.8 API Surface

### `ledgr_param_grid()`

Typed grid constructor. Returns a `ledgr_param_grid` object. Names become
result identifiers in sweep output.

```r
# Named -- user-supplied labels (preferred)
ledgr_param_grid(
  conservative = list(threshold = 0.010, qty = 10, sma_n = 20),
  moderate     = list(threshold = 0.005, qty = 10, sma_n = 20),
  aggressive   = list(threshold = 0.002, qty = 20, sma_n = 10)
)

# Unnamed -- labels generated as grid_<short_hash> of canonical params JSON
ledgr_param_grid(
  list(threshold = 0.010, qty = 10, sma_n = 20),
  list(threshold = 0.005, qty = 10, sma_n = 20)
)
```

**Identity contract:** Auto-generated labels are derived from a stable
short hash of the canonical JSON of the params list. The same params always
produce the same label across sessions. User-supplied names are stored verbatim.
Names must be unique within a grid; duplicates are a loud error.

When promoting a sweep result to a committed run, the user must supply an
explicit `run_id` to `ledgr_run()`. The sweep label is not the run ID.

### `ledgr_precompute_features()`

Computes shared feature series for a param grid. Returns a typed
`ledgr_precomputed_features` object.

```r
features <- ledgr_precompute_features(exp, param_grid)

# With explicit date range (optional -- defaults to full snapshot range)
features <- ledgr_precompute_features(
  exp,
  param_grid,
  start = "2016-01-01",
  end   = "2021-12-31"
)
```

**Object contract.** The returned object carries:

- `snapshot_hash` -- validated against the experiment snapshot at sweep time
- `universe` -- instruments covered
- `start`, `end` -- date range covered (derived from snapshot if not supplied)
- `indicator_fingerprints` -- one per unique indicator configuration computed
- `feature_engine_version` -- ledgr version used to compute features

`ledgr_sweep()` fails loudly if the feature object does not match the
experiment snapshot, universe, or date range of the requested sweep.

**Date range defaults.** When `start` and `end` are omitted,
`ledgr_precompute_features()` covers the full sealed snapshot range. A sweep
may use the same range or a narrower sub-range; it must fail if the requested
pulse range or warmup requirements are not covered by the feature object.

When `start` and `end` are supplied, they define the scoring/pulse range. The
precompute step must also cover the warmup lookback range needed before `start`
for every requested indicator. The exact v0.1.8 surface can expose this as
implicit lookback extension or as explicit metadata, but it must not confuse the
first scored pulse with the first bar needed for feature warmup.

**Indicator deduplication.** When `features` in `ledgr_experiment()` is
already a concrete list of indicators or a feature map, the precompute step
computes that fixed feature set once and reuses it across all candidates. When
`features` is `function(params) list(...)`, the precompute step evaluates it for
every unique indicator configuration across the param grid and deduplicates by
fingerprint. Parameter combinations that share the same indicators (e.g.
`sma_n = 20` appearing in multiple param rows) pay the compute cost once.

### `ledgr_sweep()`

Runs a fast exploratory sweep over a param grid. No DuckDB writes. Returns a
`ledgr_sweep_results` object.

```r
results <- exp |>
  ledgr_sweep(
    param_grid,
    precomputed_features = features,  # recommended; optional for small grids
    stop_on_error        = FALSE       # default
  )
```

**`precomputed_features` is optional.** When omitted, `ledgr_sweep()` computes
features internally per run. This is acceptable for small exploratory grids.
When the grid exceeds 20 combinations and no precomputed features are supplied,
ledgr emits a warning:

```
Warning: Grid has 48 combinations and no precomputed features were supplied.
Use ledgr_precompute_features(exp, param_grid) to compute shared feature series once.
```

The threshold of 20 is a heuristic; the exact value is decided at
implementation time.

**Failure handling.** By default (`stop_on_error = FALSE`), a strategy error
in one combination does not abort the sweep. The failed combination appears as
a result row with:

- `status = "FAILED"`
- `error_class` -- the R condition class of the error
- `error_msg` -- the error message
- All metric columns (`final_equity`, `total_return`, etc.) set to `NA`

With `stop_on_error = TRUE`, the first error aborts the sweep and re-throws the
condition. This is primarily the sequential debugging path. In future parallel
execution, at least one non-failing candidate may complete before an error is
observed and propagated by the worker framework; "first error" ordering is not
guaranteed across workers.

`stop_on_error` controls candidate-level execution failures. Contract
validation errors are not candidates: invalid parameter grids, snapshot
mismatches, universe mismatches, and invalid or mismatched precomputed feature
objects always abort the sweep before candidate evaluation.

**Parallelism.** `ledgr_sweep()` respects a `future` plan if one has been set
by the user. Sequential by default. ledgr takes no hard dependency on future,
mori, or furrr. See the Advanced Parallelism section.

---

## `ledgr_sweep_results` Object

A `tbl_df` subclass. Fully composable with dplyr. The print method shows a
curated summary with the same formatting conventions as `ledgr_comparison`.

**Columns:**

| Column | Type | Notes |
|---|---|---|
| `run_id` | chr | Name from `ledgr_param_grid()` or auto-hash label |
| `status` | chr | `"DONE"` or `"FAILED"` |
| `final_equity` | dbl | NA on failure |
| `total_return` | dbl | Ratio; printed as % |
| `max_drawdown` | dbl | Ratio; printed as % |
| `n_trades` | int | NA on failure |
| `win_rate` | dbl | Ratio; printed as %; NA on failure |
| `error_class` | chr | NA on success |
| `error_msg` | chr | NA on success |
| `params` | list | The full params list for each combination |
| `warnings` | list | Candidate-level warning conditions and non-fatal ledgr interpretation warnings |
| `feature_fingerprints` | list | Feature identities required by this candidate; varies for feature factories and is constant for concrete feature lists/maps |

**Object metadata:** The result object also carries in-memory identity metadata
as attributes, not repeated visible columns: snapshot id/hash, strategy source
hash or preflight identity, strategy preflight result, opening state, execution
assumptions, evaluation scope, and RNG contract. These attributes are promotion
and audit aids for the current R session; they are not durable experiment-store
provenance.

**Print output:**

```
# ledgr sweep -- momentum.duckdb
# 48 combinations: 46 done, 2 failed

# A tibble: 48 x 12
  run_id             status  final_equity   return  drawdown  n_trades  win_rate
  <chr>              <chr>          <dbl>   <chr>    <chr>       <int>    <chr>
1 conservative       DONE          105420   +5.4%    -8.1%        143     54%
2 moderate           DONE          112300  +12.3%   -11.2%        201     54%
3 grid_3a7f2c1e      DONE          108930   +8.9%   -12.4%        287     51%
4 grid_9b1d4e8a      FAILED            NA      NA       NA         NA      NA
...

# i Rows are in parameter-grid order; rank explicitly with dplyr when needed.
# i Promote a candidate: exp |> ledgr_run(params = ..., run_id = "...")
# i Extract params:      results |> filter(run_id == "conservative") |> pull(params) |> first()
# i Failed rows:         results |> filter(status == "FAILED")
# i Hidden columns:      params, warnings, feature_fingerprints, error_class, error_msg
```

**Promoting a candidate to a committed run:**

```r
winner <- results |>
  filter(status == "DONE") |>
  arrange(desc(total_return)) |>
  slice(1) |>
  pull(params) |>
  first()

bt <- exp |> ledgr_run(params = winner, run_id = "momentum_v1")
```

When following the train/test discipline, the committed evaluation run uses a
test-snapshot experiment rather than the sweep's train-snapshot experiment:

```r
bt_test <- test_exp |> ledgr_run(params = winner, run_id = "momentum_v1_test")
```

---

## Parity Contract

> Sweep mode may remove persistence.
> Sweep mode may not change execution semantics.

Both `ledgr_run()` and `ledgr_sweep()` call the same internal fold core
(`ledgr_run_fold()`, private). The only difference is the output handler:
persistence writes to DuckDB; sweep accumulates an in-memory summary.

**What must be identical for the same inputs:**

- Final equity, cash, and positions
- Trade list and fill list (event sequence, not just counts)
- Equity curve at each pulse
- Fill timing (next-open fill model, final-bar no-fill rule)
- Warmup behaviour (NA features before `stable_after`)
- Fee and commission calculation
- Long-only enforcement
- Random draws (same `seed` argument, same pulse-level seed derivation)

This parity is enforced by CI, not by convention. A dedicated parity test suite
runs the same strategy and params through both paths and compares the above
quantities exactly on the same R version and platform. Cross-platform numeric
behaviour may be documented separately if BLAS, CPU, or dependency differences
make bit-for-bit equality unrealistic. Any same-platform divergence is a CI
failure.

**Boundary:** Sweep does not produce durable run provenance, DuckDB run
artifacts, or persisted telemetry. Sweep may retain in-memory candidate
identity metadata such as params, snapshot identity, feature identity, strategy
preflight classification, and execution assumptions so a candidate can be
promoted to a committed `ledgr_run()` deliberately. That identity metadata is
not a substitute for the durable provenance created by the committed run.

---

## Full Workflow Reference

```r
library(ledgr)

# -- Define -------------------------------------------------------------------

snapshot <- ledgr_demo_bars |>
  ledgr_snapshot_from_df(db_path = "research/momentum.duckdb")

momentum <- function(ctx, params) {
  targets <- ctx$hold()
  for (id in ctx$universe) {
    sma <- ctx$feature(id, paste0("sma_", params$sma_n))
    if (is.finite(sma) && ctx$close(id) > sma * (1 + params$threshold)) {
      targets[id] <- params$qty
    }
    if (is.finite(sma) && ctx$close(id) < sma) {
      targets[id] <- 0
    }
  }
  targets
}

exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = momentum,
  features = function(params) list(
    ledgr_ind_sma(params$sma_n),
    ledgr_ind_returns(1)
  ),
  opening = ledgr_opening(cash = 100000)
)

# -- Sweep -- large exploratory grid -----------------------------------------

param_grid <- ledgr_param_grid(
  list(threshold = 0.010, qty = 10, sma_n = 20),
  list(threshold = 0.005, qty = 10, sma_n = 20),
  list(threshold = 0.010, qty = 10, sma_n = 10),
  list(threshold = 0.005, qty = 10, sma_n = 10),
  # ... many more ...
)

features <- ledgr_precompute_features(exp, param_grid)

results <- exp |> ledgr_sweep(param_grid, precomputed_features = features)

results |> filter(status == "DONE") |> arrange(desc(total_return))

# -- Commit candidates --------------------------------------------------------

bt <- exp |>
  ledgr_run(
    params = list(threshold = 0.005, qty = 10, sma_n = 20),
    run_id = "momentum_v1"
  )

snapshot <- snapshot |>
  ledgr_run_label("momentum_v1", "Slow SMA moderate -- sweep winner") |>
  ledgr_run_tag("momentum_v1",  c("production", "sweep_v1"))

snapshot |> ledgr_run_info("momentum_v1")
```

---

## Advanced Parallelism (Post-v0.1.8 Documentation)

The following pattern is the intended high-performance path but uses young
ecosystem APIs. It is documented as optional guidance, not first-release user
docs. Verify against current package APIs before publication.

```r
future::plan(future.mirai::mirai_multisession, workers = 8)

# Zero-copy shared features across workers (mori)
features <- mori::share(ledgr_precompute_features(exp, param_grid))

results <- exp |> ledgr_sweep(param_grid, precomputed_features = features)
```

ledgr takes no hard dependency on future, mori, or furrr. `ledgr_sweep()`
respects a future plan if set; the feature object is passed transparently to
workers because mori objects are indistinguishable from plain R objects at
the API boundary.

---

## `ledgr_tune()` -- Explicitly Deferred

`ledgr_tune()` persists every grid member as a named experiment-store run.
It is useful when you want full provenance for a small set of named variants
without sweeping first.

It is deferred from v0.1.8 for two reasons:

1. The recommended path (sweep then `ledgr_run()` candidates) covers the
   primary use case without it.
2. The internal design question -- whether `ledgr_tune()` loops over
   `ledgr_run()` or calls the same fold core as `ledgr_sweep()` -- should be
   resolved after sweep mode is shipped and the fold core is stable.

The fold core/output-handler split planned for v0.1.8 likely resolves the
second question: `ledgr_tune()` would call the same fold core with a persistence
output handler, making each candidate semantically equivalent to `ledgr_run()`.
The API remains deferred until sweep is shipped and the use case is proven.

`ledgr_tune()` appears in the earlier UX decisions document as part of the
`ledgr_experiment()` API. Its implementation is held until after v0.1.8.

---

## Version Assignment

### v0.1.8 -- Sweep Mode (first milestone)

- `ledgr_param_grid()` with named and auto-hash labeling
- `ledgr_precompute_features()` with full typed object contract
- `ledgr_sweep()` with `stop_on_error = FALSE` default, future-compatible
- `ledgr_sweep_results` S3 print method
- Failure rows with `status`, `error_class`, `error_msg`
- `params`, `warnings`, and `feature_fingerprints` list columns for candidate
  promotion and interpretation
- In-memory result metadata for snapshot identity, strategy preflight, opening
  state, execution assumptions, evaluation scope, and RNG contract
- Parity test suite (strict CI gate)
- Warning when grid > threshold and features not precomputed
- No `ledgr_tune()` in this milestone

### v0.1.9 and beyond

`ledgr_tune()` is considered once the fold core is stable and there is a
demonstrated use case for "persist every named grid member." Portfolio
optimisation vignette (v0.1.9) uses `ledgr_sweep()` + `ledgr_run()`.

---

## Open Questions (resolve before ticket cut)

1. **Warning threshold for missing precompute** -- 20 combinations is a
   heuristic. Decide the final value and whether it is user-configurable via
   an option.

2. **`ledgr_precompute_features()` range semantics** -- confirm that omitted
   `start`/`end` covers the full snapshot range, and supplied `start`/`end`
   define the scoring/pulse range while the precompute object separately covers
   required warmup lookback bars before `start`.

3. **Auto-hash label stability across R versions** -- `grid_<short_hash>` must
   be stable. Canonical JSON serialization via `jsonlite::toJSON()` with sorted
   keys is the proposed approach. Verify stability across platforms.

4. **`ledgr_tune()` internal design** -- confirm that the v0.1.8 fold
   core/output-handler split makes a persistence-output-handler tune path
   semantically equivalent to repeated `ledgr_run()` calls.
