# RFC Seed: Pulse Context Data Model Consolidation

**Status:** Design seed - response required before synthesis or LDG-2413
rescope.
**Date:** 2026-05-25
**Author:** Codex
**Inputs:**

- `inst/design/rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md`
  - accepted v0.1.8.3 optimization arc.
- `inst/design/rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`
  - accepted runtime projection and fast-context scope amendment.
- `inst/design/ledgr_v0_1_8_3_spec_packet/v0_1_8_3_spec.md`
  - active v0.1.8.3 spec packet.
- `inst/design/ledgr_v0_1_8_3_spec_packet/v0_1_8_3_tickets.md`
  - active ticket packet, especially LDG-2411 and LDG-2413.
- LDG-2402 baseline measurement, LDG-2409 projection checkpoint, and
  LDG-2411 fast-context B1 checkpoint.
- Maintainer discussion on whether the pulse-context data structure has become
  over-complicated and whether the fold should instead consume row-per-pulse
  static context slices.

---

## 1. Problem Statement

v0.1.8.3 has now implemented two pieces of the accepted optimization plan:

1. runtime projection over concrete feature matrices;
2. fast-context B1 helper-closure reuse.

The result is directionally correct but modest. LDG-2411 turned the LDG-2409
projection regression into a small net improvement, but the residual profile
still shows substantial R object churn around:

- per-pulse `ctx$bars` data-frame construction/mutation;
- per-pulse `ctx$feature_table` long-form data-frame materialization;
- per-pulse `ctx$features_wide` current-row data-frame materialization;
- `data.frame()` / `as.data.frame()` allocation and garbage collection.

This suggests that the fold is still paying to rebuild public data-frame views
from already-indexed matrices on every pulse. The current LDG-2413 wording
frames B2 as "index-backed/list-backed context proxies." That may be too small.
The deeper question is whether ledgr's pulse-context data model has accreted too
many representations of the same static data.

This RFC asks whether LDG-2413 should be rescoped from a narrow proxy patch into
a pulse-context data model consolidation.

---

## 2. Current Data Shapes

The fold currently has several representations of the same bars and feature
values.

### Bars

```text
bars_by_id:
  list keyed by instrument_id
  each entry is a per-instrument data.frame from the snapshot
  lifecycle: setup / legacy fallback / post-fold uses

bars_mat:
  list of matrices for open, high, low, close, volume, gap_type, is_synthetic
  each matrix is shaped [instrument_idx, pulse_idx]
  lifecycle: fold truth for indexed bar access and mark-to-market

bars_df / ctx$bars:
  data.frame shaped [instrument rows x OHLCV columns]
  lifecycle: rebuilt or mutated for every pulse
  purpose: public strategy-facing field
```

### Features

```text
run_feature_matrix:
  list of matrices keyed by feature_id
  each matrix is shaped [instrument_idx, pulse_idx]
  lifecycle: legacy fold representation and projection construction input

runtime_projection$feature_values:
  list of matrices keyed by feature_id
  each matrix is shaped [instrument_idx, pulse_idx]
  lifecycle: current fold truth for projection-backed scalar access

features_df / ctx$feature_table:
  long-form data.frame with columns:
    instrument_id, ts_utc, feature_name, feature_value
  lifecycle: rebuilt or refilled for every pulse
  purpose: public strategy-facing field and legacy inspection surface

ctx$features_wide:
  wide data.frame with columns:
    instrument_id, ts_utc, <feature_id_1>, <feature_id_2>, ...
  lifecycle: materialized for every pulse
  purpose: public strategy-facing wide feature field
```

### Helpers And State

Fast-context B1 already moved helper closures in the right direction:

```text
lookup env:
  mutated per pulse with bars, positions, universe
  captured by bar/open/high/low/close/volume/position/flat/hold closures

feature_state env:
  mutated per pulse with pulse_idx
  captured by projection-backed ctx$feature() and ctx$features() closures
```

The remaining waste is not scalar accessor lookup. The remaining waste is the
eager public view materialization around data frames.

---

## 3. Important Constraint: The Fold Is Stateful

A tempting expression of the desired shape is:

```r
dat <- tibble::tibble(
  time_index = 1:3,
  ctx_list = list(ctx1, ctx2, ctx3),
  params = list(params1, params2, params3),
  result = NA
)

dat <- dat |>
  dplyr::mutate(
    result = purrr::pmap(
      list(ctx = ctx_list, params = params),
      \(ctx, params) strategy(ctx, params)
    )
  )
```

This is a useful mental model for row-per-pulse static context slices, but it
cannot be the literal fold implementation. A backtest fold is stateful:

```text
result at pulse t
  -> fills and costs
  -> cash, positions, lots, realized/unrealized PnL
  -> ctx at pulse t + 1
```

Rows are not independent. The fold must remain an imperative state transition:

```r
state <- initial_state

for (pulse_idx in seq_along(pulses)) {
  static <- static_pulse_views[[pulse_idx]]
  ctx <- ledgr_make_ctx(static, state, helpers)
  result <- strategy(ctx, params)
  state <- ledgr_apply_strategy_result(result, state, static)
}
```

The design question is therefore not "can ledgr vectorize the fold with
`pmap()`?" The answer is no. The design question is:

> Can ledgr prebuild or lazily expose the static half of `ctx`, so the
> imperative fold loop stops rebuilding data-frame views every pulse?

---

## 4. Static Pulse Data Versus Dynamic Fold State

The pulse context should be understood as the merge of two layers.

### Static Pulse Data

Known before strategy execution begins:

```text
ts_utc
universe
bars for this pulse
feature_table for this pulse
features_wide for this pulse
projection-backed feature values for this pulse
calendar/snapshot identity fields already present in execution config
```

This layer can be precomputed, indexed, cached, buffered, or represented as a
view.

### Execution Metadata

Stable for a run or candidate, but not itself pulse data:

```text
run_id
seed
execution config identity
strategy and parameter identity
metric kernel / metric context identity
```

These fields should be attached to `ctx` without driving pulse-view
materialization. `safety_state` is currently always `"GREEN"` and behaves like
metadata in v0.1.8.3, but it should remain near the dynamic layer because future
risk/order/liquidity policy work may make it stateful.

### Dynamic Fold State

Known only while the fold runs:

```text
cash
equity
positions
state_prev
current targets / hold targets
safety_state
fills, orders, costs, lots, and ledger events
future risk/order/liquidity policy state
```

This layer cannot be precomputed across pulses because it depends on prior
strategy decisions.

---

## 5. Candidate Designs

### Option A: Keep LDG-2413 Narrow

Keep the current LDG-2413 framing and replace selected data-frame construction
with cheaper list-backed or index-backed structures where parity permits.

Advantages:

- smallest change;
- aligns with current accepted spec language;
- low public API risk.

Disadvantages:

- may optimize within an over-complicated structure;
- likely leaves `ctx$feature_table`, `ctx$bars`, or `ctx$features_wide`
  materialization paths intact;
- performance ceiling may remain low.

### Option B: Prebuilt Static Pulse Views

Build static context views once before the fold loop:

```r
pulse_views <- list(
  bars = vector("list", n_pulses),
  feature_table = vector("list", n_pulses),
  features_wide = vector("list", n_pulses)
)
```

Then the hot loop plucks:

```r
ctx$bars <- pulse_views$bars[[pulse_idx]]
ctx$feature_table <- pulse_views$feature_table[[pulse_idx]]
ctx$features_wide <- pulse_views$features_wide[[pulse_idx]]
```

Advantages:

- removes data-frame construction from the hot loop;
- removes garbage-collection pressure from the strategy execution loop rather
  than merely rearranging code. Building views once during setup is materially
  different from allocating and discarding data frames on every pulse;
- preserves public context field schemas;
- keeps the fold imperative and shared between `ledgr_run()` and
  `ledgr_sweep()`;
- easy to parity-test against the current fold;
- likely changes the v0.1.8.3 performance story from a small improvement to a
  meaningful one if the current `data.frame()` / `as.data.frame()` profile share
  is real.

Disadvantages:

- increases peak memory because every pulse view may be retained, but the
  expected v0.1.8.3 scale is bounded. A rough reference-workload estimate
  with 4 instruments, 252 pulses, and 5 features is under 1 MB per candidate
  if all three views are retained, and about 6-8 MB for 50 candidates if bars
  views are shared and feature views are candidate-specific. Larger
  parallelism-spike-style workloads may put the raw numeric payload for a
  `[250 instruments x 2520 pulses x 50 features]` feature projection around
  240 MiB before data-frame overhead, so LDG-2413 must measure object sizes
  rather than assume memory is free;
- candidate-specific feature subsets may duplicate views across sweep
  candidates unless carefully shared;
- strategy mutation of a captured context view requires explicit state-leak
  tests.

### Option C: Lazy View Objects

Expose `ctx$bars`, `ctx$feature_table`, and `ctx$features_wide` as lightweight
S3 view objects backed by `bars_mat` and `runtime_projection`.

Advantages:

- avoids materializing views unless strategy code actually reads them;
- best long-term performance shape for strategies that use scalar accessors;
- aligns with future DuckDB-backed / block-buffered projection backends.

Disadvantages:

- wins only when strategies rarely read `ctx$bars`, `ctx$feature_table`, or
  `ctx$features_wide`. If strategies do read these fields, Option B serves the
  access cheaply while Option C pays proxy dispatch and compatibility costs;
- highest API-compatibility risk;
- must emulate enough data-frame behavior to be safe;
- could surprise users who rely on exact `data.frame` internals;
- current v0.1.8.3 spec explicitly avoids active-binding/lazy context fields.

Option C should be measurement-driven. If post-LDG-2413 usage data or residual
profiles show that most strategies never read the public data-frame fields,
lazy view objects become the next serious design. Without that evidence, Option
B is the safer first implementation because it preserves exact field behavior.

### Option D: Literal Row-Wise `pmap()` Fold

Represent the fold as a tibble with `ctx_list`, `params`, and `result`, then
compute results row-wise.

Recommendation: reject as an execution model.

The tibble/list-column shape is useful for explaining static pulse slices, but
the fold is path-dependent. A literal `pmap()` implementation would either be
incorrect or would hide a stateful loop inside the mapped function, losing the
clarity it was meant to add.

---

## 6. Recommended Seed Position

The preferred direction for review is Option B as the next implementation step,
with Option C reserved for a later RFC if Option B does not provide enough
headroom.

In other words, rescope LDG-2413 from:

```text
Fast Context B2 Index-Backed Context Proxies
```

to:

```text
Fast Context B2 Prebuilt Static Pulse Views
```

The first implementation should:

- keep `ctx$bars`, `ctx$feature_table`, and `ctx$features_wide` as data frames;
- build those views outside the pulse hot loop where parity permits;
- keep `ctx$feature()` and `ctx$features()` projection-backed through B1;
- preserve the state-leak invariant for public data-frame views. Under prebuilt
  views, "fresh" means each `pulse_idx` has a distinct view object, and strategy
  mutation of a captured view cannot affect another pulse, another candidate,
  or a later revisit of the same pulse view;
- preserve schemas, column ordering, types, `ts_utc`, and missing-value
  behavior;
- keep the same fold core for `ledgr_run()` and `ledgr_sweep()`;
- audit `ctx$feature_table` usage before implementation. If it is only used by
  validators, inspection helpers, and tests, LDG-2413 should consider removing
  or deferring long-form feature-table materialization rather than prebuilding
  a field real strategies do not read;
- delete the redundant `run_feature_matrix` active representation once the
  projection path and parity fallback no longer require it;
- record memory overhead and wall-clock impact in the LDG-2414 residual report.

If prebuilt views make memory pressure unacceptable or fail state-leak parity,
LDG-2413 should fall back to the current narrower B2 proxy scope or explicitly
defer with measurement evidence.

The expected stakes are large enough to justify the rescope. The current
LDG-2411 checkpoint has the reference workload around 43s. A narrow B2 proxy may
only shave a few seconds. If prebuilt views remove most hot-loop data-frame
allocation, the plausible target is closer to 30s. The exact number must be
measured, but the difference is the difference between "modestly faster" and
"materially faster."

---

## 7. Candidate-Specific Versus Sweep-Shared Views

This is the main implementation tension.

Bars are naturally sweep-shared:

```text
same snapshot + same universe + same pulses -> same ctx$bars views
```

Feature views may be candidate-specific:

```text
candidate A: sma_10, sma_50
candidate B: sma_20, sma_200
```

The runtime projection can hold the grid-level union, but public
`ctx$features_wide` should not silently expose features outside the candidate's
declared feature set. Therefore the first implementation should prefer
candidate-specific feature views unless a shared-union view can preserve the
exact current schema.

There are three possible feature-view sharing policies:

```text
candidate-specific full materialization:
  safest parity path; each candidate gets exactly its declared feature columns

grid-union materialization plus per-candidate column selection:
  better memory reuse when candidates share many features; requires careful
  schema and state-leak tests so extra union columns never leak into ctx

lazy candidate-specific column views:
  lowest allocation when fields are unused; belongs to a later lazy-view RFC
  unless v0.1.8.3 measurements force it
```

Recommended first-pass policy:

```text
bars views:
  built once per fold setup from bars_mat

feature_table / features_wide views:
  built per candidate from runtime_projection restricted to candidate feature_ids
```

This may not be the final architecture, but it is the safest path for
v0.1.8.3.

v0.1.8.4 active aliases will revisit this layer. Once aliases such as
`fast -> sma_20` are active, candidate views may need alias-named columns even
when the backing projection is concrete-feature keyed. The v0.1.8.3 design
should therefore keep prebuilt-view construction candidate-aware, so alias
resolution can be inserted at setup time without changing the fold core.

---

## 8. DuckDB Role

DuckDB can produce the long-form table the maintainer described:

```text
time_index | instrument_id | ts_utc | feature_name | feature_value
```

It can also back durable feature libraries, out-of-core projections, and
pulse-block buffered runtime windows in a later cycle.

That is not required for v0.1.8.3. The current runtime projection already holds
R-memory matrices. The next bottleneck is not SQL query speed; it is repeated R
object construction inside the fold loop.

v0.1.8.3 should keep DuckDB out of the pulse hot loop. A future DuckDB-backed
projection can implement the same interface by loading pulse blocks into memory:

```text
DuckDB feature storage
  -> load pulse block [i:j]
  -> expose in-memory views inside the block
  -> no DBI per pulse
```

---

## 9. Verification Requirements

Before implementation, run a usage audit for public feature-table access:

```text
rg -n "ctx\\$feature_table|feature_table" R tests vignettes inst/examples
```

If `ctx$feature_table` is only used by validators, inspection helpers, and
tests, the response should decide whether LDG-2413 still needs to prebuild it.
If documented strategies read it, preserve it as a prebuilt data-frame view.

Any accepted implementation must add tests for:

- bit-exact fold parity between current projection+B1 and prebuilt-view mode;
- persistent-versus-memory accounting parity still passing;
- `ctx$bars` schema, column order, column types, and `ts_utc` behavior;
- `ctx$feature_table` schema, row ordering, missing values, and feature IDs;
- `ctx$features_wide` schema, column order, missing values, and feature IDs;
- state-leak safety when strategy code captures and mutates `ctx$features_wide`
  or `ctx$bars` from one pulse;
- candidate-specific feature-set restriction in sweeps;
- `ledgr_run()` single-candidate overhead, to guard against per-run setup
  regression;
- LDG-2402 reference workload timing and profile deltas versus the LDG-2411
  checkpoint;
- peak memory or at least object-size accounting for the prebuilt view bundle.

The state-leak test is load-bearing. If views are shared across candidates or
pulses, a strategy must not be able to mutate one pulse or candidate's public
context view and corrupt a later pulse, another candidate, or a future use of
the same prebuilt view.

---

## 10. Open Questions For Review

1. Should LDG-2413 be rescoped to prebuilt static pulse views, or should it
   remain a narrow list-backed proxy ticket?
2. Should `ctx$feature_table` remain an eager public data-frame field, become a
   prebuilt view, become lazy, or be marked for future deprecation after the
   usage audit?
3. Should `ctx$bars` be prebuilt per pulse or remain a mutable data frame
   refreshed inside the loop?
4. Should `ctx$features_wide` be prebuilt per pulse, or should v0.1.8.3 retain
   fresh materialization and defer laziness?
5. Is candidate-specific feature view construction acceptable for v0.1.8.3, or
   must the first implementation share grid-union views across sweep
   candidates?
6. What memory ceiling should trigger fallback from prebuilt views to the
   narrower B2 proxy path?
7. Can `run_feature_matrix` be deleted as an active fold representation in
   LDG-2413, retaining only the projection-backed path and any narrowly scoped
   parity fixture needed by tests?
8. Does the current public context contract require exact `data.frame` objects,
   or is a data-frame-compatible S3 view acceptable before CRAN?

---

## 11. Non-Goals

This RFC does not propose:

- a second execution engine;
- a sweep-only fast path;
- literal `pmap()` or vectorized strategy execution;
- DuckDB calls inside the per-pulse hot loop;
- active aliases or alias-map identity in v0.1.8.3;
- public ML training-frame export APIs;
- compiled C/C++/Rust fold kernels;
- weakening snapshot, no-lookahead, FIFO accounting, metric-context, or
  execution-seed contracts.

---

## 12. Expected Follow-Up If Accepted

If the response and synthesis accept the recommended direction:

1. Run and record the `ctx$feature_table` usage audit so the LDG-2413 scope
   does not preserve unused long-form materialization by default.
2. Amend `rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`
   or add a short superseding synthesis note for LDG-2413.
3. Amend `v0_1_8_3_spec.md` to name prebuilt static pulse views as the B2
   implementation target.
4. Rescope LDG-2413 in `v0_1_8_3_tickets.md` and `tickets.yml`.
5. Run the prebuilt-view implementation behind parity tests before removing any
   legacy projection fallback.
6. Delete redundant `run_feature_matrix` plumbing where projection parity tests
   prove it is no longer needed.
7. Measure wall-clock, profile shares, and object sizes against the LDG-2411
   checkpoint before deciding whether typed memory events and single-pass
   summary remain in the current release cut.
