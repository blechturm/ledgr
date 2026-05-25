# RFC Synthesis: Grid-Level Feature Artifacts And Runtime Projection

**Status:** Accepted synthesis - binding amendment for the v0.1.8.3
optimization packet and the v0.1.8.4 active-alias ticket cut.
**Date:** 2026-05-25
**Author:** Codex
**Thread:**

- `inst/design/rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x.md`
- `inst/design/rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_response.md`
- `inst/design/rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md`
- `inst/design/rfc/rfc_active_parameterized_feature_aliases_v0_1_8_x_synthesis.md`
- `inst/design/ledgr_v0_1_8_3_spec_packet/v0_1_8_3_spec.md`
- `inst/design/ledgr_v0_1_8_3_spec_packet/v0_1_8_3_tickets.md`
- `inst/design/ledgr_v0_1_8_3_spec_packet/tickets.yml`
- LDG-2402 performance protocol and v0.1.8.2 baseline.
- LDG-2403 persistent-versus-memory accounting parity gate.

---

## 1. Decision Summary

The grid-level feature artifacts RFC reframes a narrow optimization idea into a
larger execution design: ledgr should stop treating current-pulse wide feature
views as objects rebuilt inside the fold and instead introduce an internal
runtime projection over a grid-level concrete feature library.

This synthesis accepts that direction with a narrow implementation boundary:

- v0.1.8.3 should expand from typed memory events plus single-pass summary
  reconstruction to the full R-level fold/runtime optimization arc.
- v0.1.8.3 implements the concrete feature library and runtime projection.
- v0.1.8.3 does not implement active aliases, alias-map identity, durable
  feature artifacts, ML training exports, public parameter-grid helpers,
  parallel dispatch, or compiled kernels.
- v0.1.8.4 active aliases must inherit the grid-level concrete-feature-union
  decision so parameterized sweeps do not compute the same concrete feature
  once per candidate.

The key implementation decision is that both `ledgr_run()` and `ledgr_sweep()`
must consume the same internal projection shape. A committed run is the
one-candidate case; a sweep is the grid-union case. This preserves the shared
fold-core contract and avoids creating a sweep-only fast path.

---

## 2. Accepted Layer Model

Accept the four-layer model from the RFC thread:

```text
1. concrete feature library
2. candidate alias views
3. runtime projection
4. research / export artifact
```

Only layers 1 and 3 are in v0.1.8.3 scope.

### Layer 1: Concrete Feature Library

The concrete feature library is the resolved union of concrete features needed
by execution:

- for `ledgr_run()`: one candidate's concrete features;
- for `ledgr_sweep()`: the union of all concrete features required by the
  candidate grid.

It is internal vocabulary in v0.1.8.3. It does not introduce a public
`ledgr_feature_library()` API, stored artifact schema, or user-facing hash.

### Layer 2: Candidate Alias Views

Candidate alias views are active-alias work and belong to v0.1.8.4. v0.1.8.3
may reserve an internal NULL extension point on the projection so v0.1.8.4 can
attach a per-candidate alias index without re-plumbing the fold.

That reservation has no schema, no serialization, no hash, no provenance
record, and no behavior in v0.1.8.3.

### Layer 3: Runtime Projection

The runtime projection is the v0.1.8.3 performance surface. It converts the
concrete feature library into integer-indexed matrices consumed by the fold.
The projection is an implementation detail pinned by parity tests, not a new
identity surface.

### Layer 4: Research / Export Artifact

Durable long/wide feature artifacts, DuckDB-backed research tables, ML training
frames, and prediction/export workflows are deferred to a later ML/export RFC.
They should be recorded in `inst/design/horizon.md` so the design memory is not
lost, but they are not v0.1.8.3 or v0.1.8.4 implementation scope.

---

## 3. Precompute Contract

`ledgr_precompute_features()` remains the single feature precompute path.
Do not introduce a second feature engine or a parallel precompute API.

The first projection implementation should use a named list of matrices:

```text
feature_values:
  named list keyed by concrete feature_id
  each entry is a numeric matrix shaped [instrument_idx, pulse_idx]
  missing values are NA_real_

instrument_index:
  instrument_id -> integer instrument_idx

pulse_index:
  pulse identity -> integer pulse_idx

feature_engine_version:
  unchanged; carried through the projection for cache and parity checks

alias_index:
  NULL in v0.1.8.3
```

Per-pulse scalar feature access becomes:

```r
feature_values[[feature_id]][instrument_index[[instrument_id]], pulse_idx]
```

This shape is intentionally not a two-axis wide table with instruments stacked
into rows. The purpose is to remove per-pulse string matching, long-to-wide
reshape, and intermediate data-frame construction from the fold hot path.

Dense-matrix missingness is part of the contract. Any `(instrument, feature,
pulse)` slot where the current accessor path would return `NA` or not find a
valid value must contain `NA_real_`, not zero or a carried-forward value. This
covers warmup periods, absent feature values, and any future sparse instrument
coverage within the current per-instrument feature model.

Bundle outputs are flattened before projection. Each bundle output appears as
an ordinary concrete single-output `feature_id`, per the existing
`ledgr_indicator_bundle` flattening contract; the projection must not introduce
nested bundle structures.

The v0.1.8.3 projection supports the current per-instrument feature model only.
Market-level or universe-level feature shapes would need a separate future
projection contract.

Projection memory grows as `features * instruments * pulses`. Current and
near-term EOD workloads fit comfortably in R memory, including the local
v0.1.8.3 measurement workloads.

The projection should be designed as a thin internal interface, not as raw
storage reached directly throughout the fold. The v0.1.8.3 implementation is an
R-memory backend over list-of-matrices storage. A future cycle may add a
DuckDB-backed backend of the same interface for memory scaling, persistence,
parallel worker sharing, and layer 4 research/export artifacts. The fold should
not depend on the projection's concrete representation.

When out-of-core projection becomes necessary, the natural design is
pulse-block buffering over DuckDB-backed feature storage shared with the
deferred layer 4 artifact. DBI should fire at block boundaries, not pulse
boundaries, preserving the no-per-pulse-DBI runtime rule.

A 3D array can be reconsidered later as an internal optimization, but the
v0.1.8.3 ticket cut should pin the list-of-matrices shape unless profiling or
implementation evidence forces an amendment before work starts.

`ledgr_run()` must call the same projection builder as `ledgr_sweep()`. The
only difference is the size of the concrete feature library.

Introducing the projection does not bump `feature_engine_version`. It changes
runtime access to already-computed values, not feature computation or concrete
feature identity.

---

## 4. Runtime Context Policy

The runtime projection should become the backing store for feature access
inside the shared fold. Public context behavior remains source-compatible.

### Feature Access

`ctx$feature()` and related helpers should read from the projection through
pre-resolved integer indices. Feature values observed by strategy code must be
bit-exact equal to the current table/accessor path on the reference workloads.

### ctx$features_wide

`ctx$features_wide` should become a fresh current-pulse wide view materialized
from the projection. It must not expose a reusable mutable row shell.
The schema, column ordering, types, and `ts_utc` handling must remain
byte-identical to the current accessor path on reference workloads.

Rejected first-pass designs:

- active-binding laziness for `ctx$features_wide`;
- changing `ctx$features_wide` from a field to a function;
- reusing one mutable public data object across pulses.

The state-leak contract is explicit: if a strategy captures
`ctx$features_wide` at pulse `t`, later fold work for pulse `t+1` must not
mutate the captured object.

### Fast Context And Pulse-Context Data Model

Fast context B1 is part of the expanded v0.1.8.3 R-level optimization arc:

- B1: initialize lookup environments and helper closures once per candidate;
  mutate pulse-specific scalar values per pulse.

B1 must be gated by projection parity and state-leak tests before activation.

The accepted pulse-context data model consolidation synthesis supersedes this
document's original B2 proxy framing for v0.1.8.3 implementation. LDG-2413 now
targets prebuilt static pulse views for `ctx$bars`, `ctx$feature_table`, and
`ctx$features_wide`, while preserving public data-frame field semantics. That
work must follow the pulse-context synthesis rather than the narrower
index-backed/list-backed proxy language here.

---

## 5. Identity And Hashing

v0.1.8.3 must not add a new identity surface for the projection.

Rules:

- `feature_set_hash` remains unchanged and concrete-feature-only.
- Concrete feature fingerprints remain byte-identical for non-parameterized
  declarations.
- `config_hash` is unchanged by v0.1.8.3 projection work.
- The runtime projection has no hash.
- `feature_library_hash` is not introduced in v0.1.8.3.
- `alias_map_hash` remains v0.1.8.4 active-alias scope.

Projection correctness is enforced by parity tests, not by persistent hash
identity. Introduce a future `feature_library_hash` only when a non-performance
consumer, such as durable feature artifacts or ML exports, needs to reference a
library as a stored object.

---

## 6. Active-Alias Amendment

The active parameterized feature aliases synthesis remains accepted, but its
runtime resolution language needs an amendment before v0.1.8.4 ticket cut.

The correct model is:

```text
authored feature declarations
  -> per-candidate alias maps
  -> grid-level union of concrete features
  -> one computed concrete feature library
  -> runtime projection
  -> per-candidate alias index over the projection
```

That preserves both halves of the contract:

- alias identity is per candidate and belongs to v0.1.8.4 `alias_map_hash`,
  `config_hash`, and sweep/run provenance;
- concrete feature computation is grid-level and deduplicated across
  candidates.

The projection may carry a derived runtime alias index in v0.1.8.4, but it is
not the storage layer for alias maps and it has no hash.

The v0.1.8.4 flow should be explicit: resolve the alias map at sweep/run start,
persist it to the `alias_map_json` / `alias_map_hash` provenance surfaces from
the active-alias synthesis, derive a per-candidate `alias_index`, then attach
that derived index to the projection at fold setup.

---

## 7. DuckDB Boundary

DuckDB remains a static preparation, persistence, and cache layer. It is not the
per-pulse runtime engine for v0.1.8.3.

Accepted boundary:

```text
snapshot / DuckDB / feature precompute
  -> in-memory R projection
  -> integer-indexed fold access
```

No per-pulse DBI traffic is allowed. DuckDB-backed long/wide feature artifacts
belong to the deferred research/export artifact design, not to the v0.1.8.3
runtime optimization.

The deferred layer 4 research artifact is the future DuckDB-backed feature
storage substrate. When out-of-core runtime projection becomes necessary, it
should be a buffered window over that storage, not a separate DuckDB schema.
This couples layer 3 scaling to the layer 4 design while keeping v0.1.8.3's
runtime fold in memory.

DuckDB-implemented indicator computation is also out of scope. The authoritative
indicator extension surface remains `series_fn()` / TTR / custom R functions.
SQL-native built-in indicators may be reconsidered later as an opt-in fast path
with parity tests against the R implementation, but that requires a separate
RFC because it affects feature identity, determinism, and mixed-engine
execution.

---

## 8. Required Verification

The expanded v0.1.8.3 ticket cut must require these tests:

- `ledgr_precompute_features()` emits the projection shape, indices, and
  feature-engine version metadata.
- Existing `tests/testthat/test-fingerprint-stability.R` pins remain unchanged.
- `ledgr_run()` and `ledgr_sweep()` consume the same internal projection shape;
  `ledgr_run()` is the one-candidate case.
- `ledgr_run()` wall-clock does not materially regress on a single-candidate
  baseline after projection activation.
- Projection-vs-table parity: values reaching strategy code through
  matrix-index access match the current accessor path.
- Projection missingness parity: warmup and absent values observed through the
  projection are `NA_real_` wherever the current accessor path returns `NA` or
  no value.
- Bundle projection parity: multi-output bundle values appear as flat concrete
  feature IDs and match current flattened bundle outputs.
- No-duplication parity: one concrete feature used by N candidates is computed
  once across the sweep, not N times.
- State-leak parity: `ctx$features_wide` captured at pulse `t` is not mutated
  by pulse `t+1`.
- `ctx$features_wide` schema parity: columns, types, ordering, and `ts_utc`
  presence match the current accessor path on reference workloads.
- LDG-2403 accounting parity remains green, including realized and unrealized
  PnL.
- Metric-context parity remains green, including non-default risk-free rate
  propagation through `metric_kernel`.
- Fast-context activation produces bit-exact equivalent outputs to the current
  implementation on the reference workload.
- The post-change report reruns the LDG-2402 protocol and reports fold share,
  allocation/GC pressure where practical, speedup, regressions, and remaining
  hot spots.

There is no fixed numeric speedup target. The evidence gate remains: measured
improvement on the target workload, no correctness drift, no material
`ledgr_run()` regression, and a documented residual hot-path report.

---

## 9. Implementation Sequencing

Recommended v0.1.8.3 sequence:

```text
1. Amend v0.1.8.3 spec and tickets.
2. Extend ledgr_precompute_features() to emit the projection.
3. Consume projection in the shared ledgr_run()/ledgr_sweep() fold.
4. Add projection-vs-table, state-leak, and shared-run/sweep parity gates.
5. Add fast context B1 after projection parity is green.
6. Add pulse-context data model consolidation / prebuilt static pulse views.
7. Rerun LDG-2402 protocol and publish residual report for the LDG-2410 /
   LDG-2412 maintainer decision.
8. Add typed memory events if retained.
9. Add single-pass summary reconstruction if retained.
```

Ticket cut may merge or split these steps, but it must preserve these
dependency edges:

- projection before typed memory events;
- projection before fast context;
- projection/state-leak parity before fast-context activation;
- LDG-2403 accounting parity before typed events and after each accounting-path
  rewrite;
- post-LDG-2413 measurement before deciding whether typed memory events and
  single-pass summary reconstruction remain in v0.1.8.3.

B1 is sequenced before single-pass summary because LDG-2402 points to fold
setup churn as the larger immediate lever, while single-pass summary touches
accounting reconstruction and should land after the projection-backed fold path
is stable. `ledgr_sweep_run_candidate()` is the expected convergence point for
projection setup, pulse-context view setup, typed memory events, and single-pass
reconstruction; avoid independent refactors of that boundary.

---

## 10. Required Document Updates

Before implementation expands beyond the current v0.1.8.3 spec:

1. Amend `inst/design/ledgr_v0_1_8_3_spec_packet/v0_1_8_3_spec.md` to state
   that v0.1.8.3 is now the full R-level fold/runtime optimization release.
2. Amend `inst/design/ledgr_v0_1_8_3_spec_packet/v0_1_8_3_tickets.md` and
   `tickets.yml` to add projection and fast-context tickets, and update
   dependencies for typed events and single-pass summary reconstruction.
3. Amend
   `inst/design/rfc/rfc_active_parameterized_feature_aliases_v0_1_8_x_synthesis.md`
   so v0.1.8.4 active aliases inherit the grid-level concrete-feature-union
   decision, specifically tightening the current section 3 step 6 language
   that says `ledgr_sweep()` resolves once per candidate.
4. Add a horizon entry for deferred research/export feature artifacts and ML
   training-frame design.
5. Update `inst/design/README.md` to index this synthesis and summarize its
   v0.1.8.3/v0.1.8.4 implications.

Do not treat this synthesis as permission for quiet ticket drift. The spec and
ticket amendments are part of the design change.

---

## 11. Non-Goals

The following remain out of scope for v0.1.8.3:

- active alias lookup via `ctx$features("AAA")`;
- alias-map storage, schema, hash, or provenance;
- `alias_map_hash` and related `config_hash` changes;
- `ledgr_parameters(features)` introspection;
- public parameter-grid helpers;
- candidate ranking or tuning DSLs;
- public ML training-frame/export APIs;
- DuckDB-backed precompute storage, out-of-core projection, and long/wide
  research artifacts;
- DuckDB-implemented indicator computation;
- `feature_library_hash`;
- projection hash;
- second feature precompute engine;
- active-binding lazy `ctx$features_wide`;
- field-to-function context API changes;
- target-risk chain;
- parallel sweep dispatch;
- Rcpp, Rust, Fortran, or other compiled fold kernels;
- compatibility shims for pre-CRAN development artifacts.

These exclusions preserve the boundary between the v0.1.8.3 R-level
optimization release, the v0.1.8.4 active-alias release, and later research
artifact / ML / compiled-core work.
