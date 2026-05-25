# RFC Response: Grid-Level Feature Artifacts And Wide Runtime Views

**Status:** Reviewer response - accepts the four-layer model, rejects durable
artifacts now, and supports a formal v0.1.8.3 scope expansion for the R-level
optimization arc.
**Date:** 2026-05-25
**RFC:** `inst/design/rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x.md`
**Reviewer:** Codex

---

## Overall Assessment

The seed correctly reframes the question. The narrow "make `ctx$features_wide`
lazy" patch is not the design; the design is whether ledgr commits to a
grid-level concrete feature library with candidate-level alias views into it,
and uses that library as the shared substrate for sweeps, active aliases,
runtime pulse context, and future research/export artifacts.

The four-layer model is the right target architecture:

```text
1. grid-level concrete feature library
2. candidate alias views
3. runtime projection
4. research / export artifact
```

This composes cleanly with the accepted active-alias synthesis: the existing
"authored declaration -> resolved alias map -> concrete feature" layering is
preserved, and the runtime projection layer fills a gap that the active-alias
synthesis left implicit.

The seed's main weakness is its "Medium now, broad later" scope recommendation.
The Medium scope as defined imports fast-context work that the current v0.1.8.3
spec explicitly excludes, and the Broad scope mixes a real near-term need
(grid-level concrete-feature-union for parameterized sweeps) with deferrable
work (durable research artifacts, public ML export API). The recommended
response is to redraw the boundary by changing what v0.1.8.3 covers, not by
quietly stretching the existing cut.

---

## Maintainer Intent

Per maintainer direction recorded on 2026-05-25, v0.1.8.3 should cover the full
R-level fold and payload optimization arc, not only typed memory events and
single-pass summary reconstruction. The justification is empirical and
intent-driven:

- LDG-2402 baseline measured `ledgr_execute_fold()` at about 79.8% of sampled
  time on the reference workload. This is sampling evidence, not a full phase
  decomposition: the baseline report itself notes that post-fold reconstruction
  did not surface in the top sampled frames and recommends a targeted phase
  profile if that remains the claim. The sampled fold share is sufficient to
  motivate scope expansion; it is not sufficient to retire the typed-events /
  single-pass slice without further measurement.
- The original sequencing argument for deferring fast-context work was that the
  sweep contract was not yet stable. v0.1.8.0 through v0.1.8.2 closed that.
  The deferral premise no longer holds.
- Maintainer intent is to land the full R-level optimization arc in one cycle
  rather than spread it across three patch releases.

Therefore the response treats expanded v0.1.8.3 as the working assumption and
focuses on what that scope should and should not contain.

---

## Accepted Positions

### 1. Four-Layer Model

Accept the seed's four-layer separation. For v0.1.8.3, only layers 1 and 3 are
implemented. Layer 2 is acknowledged in the architecture but not built:

```text
layer 1: grid-level concrete feature library
  produced by extending ledgr_precompute_features()
  no new public function

layer 2: candidate alias views
  designed and implemented in v0.1.8.4 (active aliases)
  v0.1.8.3 reserves an internal NULL extension point on the projection so
  v0.1.8.4 can attach a per-candidate index map without re-plumbing the fold
  no alias-map storage, schema, hash, or provenance lands in v0.1.8.3

layer 3: runtime projection
  in-memory matrices plus instrument and feature integer indices
  consumed by the fold via matrix-index access
  fresh current-row views materialized from this backing

layer 4: research / export artifact
  deferred to a later ML/export RFC
  not part of v0.1.8.3 or v0.1.8.4
```

The alias-map boundary is load-bearing. Alias maps are execution interface:
they belong to `alias_map_hash`, `config_hash`, sweep/run provenance, and the
v0.1.8.4 active-alias design. The runtime projection is a perf detail with no
hash. Storing alias maps on the projection in v0.1.8.3 would either pre-decide
schema and identity semantics that belong to v0.1.8.4, or split alias-map
ownership across two layers. Neither is acceptable.

### 2. ledgr_precompute_features() Is The Extension Point

There must be one feature precompute path. `ledgr_precompute_features()`
already resolves the union of concrete features required by a candidate grid
and emits an ordered payload. v0.1.8.3 extends that helper to additionally
emit a projection consumable by the fold:

```text
feature_values:
  named list keyed by feature_id
  each entry is a matrix shaped [instrument_idx, pulse_idx]
  or, equivalently, a single 3D array shaped [feature_idx, instrument_idx, pulse_idx]
  the chosen shape must be pinned in the ticket cut and held by tests

instrument_index:
  instrument_id (character) -> instrument_idx (integer)

pulse_index:
  pulse identity (ts_utc or equivalent) -> pulse_idx (integer)

feature_engine_version:
  unchanged; round-trips into the projection so cache reuse checks still work
```

The shape pin matters. A two-axis "wide table" projection
(`feature_values[ts_utc, feature_id]` with instruments stacked) would
recreate the reshape costs the RFC is trying to remove. The intended access
pattern is constant-time integer indexing for the current pulse and
instrument, with no string lookup and no reshape inside the fold.

Do not introduce a second precompute API. Do not duplicate ordering,
fingerprint, or feature-engine-version logic.

`ledgr_run()` must use the same internal projection builder. In the committed-run
case the feature library is a degenerate one-candidate projection; in the sweep
case the feature library is the grid-level union. This preserves the shared fold
core contract and prevents a sweep-only optimized feature access path from
becoming a second execution engine.

The projection may carry a reserved NULL slot for the v0.1.8.4 alias index
map. That slot is structural reservation only; it has no schema, no
serialization, no hash, and is not read by the fold in v0.1.8.3.

### 3. Runtime Projection Is Central

The runtime projection layer is the actual perf lever, not laziness of
`ctx$features_wide`. The fold consumes:

```text
feature_values:        list of per-feature [instrument_idx, pulse_idx] matrices
                       (or one 3D array; ticket cut pins the shape)
instrument_index:      instrument_id -> instrument_idx
pulse_index:           pulse identity -> pulse_idx
current pulse_idx:     scalar, updated per pulse by the fold
```

Per-pulse feature access for instrument `inst` and feature `fid` becomes:

```r
feature_values[[fid]][instrument_index[[inst]], current_pulse_idx]
```

This is constant-time integer indexing into preallocated matrices. There is no
string lookup over a feature data.frame inside the hot loop, no reshape from
long to wide, and no per-pulse construction of intermediate frames. This is
what unlocks the fold-cost drop that the LDG-2402 sampling baseline implies.

`ctx$features_wide` becomes a fresh current-row view derived from the matrices
on read (Section 4 below); it is never the storage layer.

For v0.1.8.3 the projection has no alias dimension. Active aliases in v0.1.8.4
attach a per-candidate alias-index map (e.g. `alias_index[alias] -> feature_idx`)
to the projection, but that map is derived from the persisted/provenance alias
map stored at sweep and run identity surfaces. The projection holds only the
runtime index; it does not own the alias map.

### 4. ctx$features_wide Materialization Policy

Adopt Section 7 option 1, materially refined:

```text
precompute concrete feature backing once per sweep
build a fresh current-row wide view per pulse from the matrices
do not reuse mutable public objects across pulses
defer active-binding laziness until a later cycle if profiling justifies it
```

Section 7 option 3 (reusable mutable row shell) is rejected for the first pass.
It carries a quiet correctness risk: any strategy that captures
`ctx$features_wide` into a local variable across pulses would silently see
mutated values. Closing that risk requires either preflight rejection of such
captures (out of scope) or per-pulse copy-on-read (defeats the point).

Option 2 (lazy materialization via active bindings) is deferred. Once the
projection exists and per-pulse construction is a cheap matrix-row read,
laziness becomes a smaller win than the seed implies, and the public API
question can be revisited on real post-change evidence.

### 5. DuckDB Role

DuckDB remains a static preparation and cache engine, not the sweep runtime.
The recommended direction holds:

```text
DuckDB / snapshot / precompute cache
  -> R in-memory runtime projection
  -> pulse context matrix-index access
```

There is no per-pulse DBI traffic. There is no DuckDB-backed feature artifact
for v0.1.8.3. A future ML/export RFC can revisit DuckDB-backed long/wide
artifact tables with their own provenance design.

### 6. Hash Surfaces

For v0.1.8.3:

- `feature_set_hash`: unchanged. Concrete-feature-only. Fingerprint stability
  pins must continue to pass.
- `config_hash`: unchanged for v0.1.8.3.
- runtime projection: no hash. The projection is an implementation detail. Pin
  it with parity tests instead.
- `feature_library_hash`: not introduced in v0.1.8.3. It has no non-perf
  consumer yet. Introduce it only when a durable artifact or ML export surface
  needs to reference it.
- `alias_map_hash`: per the active-alias synthesis, added in v0.1.8.4.

Open question Q5 ("hash surfaces beyond `feature_set_hash` and
`alias_map_hash`") is answered: none in v0.1.8.3.

### 7. Terminology Pin

Adopt the following names in code, design notes, and tests:

| term            | scope                                                    | hash                               |
|-----------------|----------------------------------------------------------|------------------------------------|
| `feature_set`   | per-experiment, declared (may contain `ledgr_param()`)   | `feature_set_hash`, concrete-only  |
| `feature_library` | per-sweep, resolved union across all candidates        | none for v0.1.8.3                  |
| `alias_map`     | per-candidate, declared alias -> concrete feature        | `alias_map_hash`, v0.1.8.4         |
| `projection`    | per-sweep runtime, in-memory matrices plus indices       | none; parity-tested                |

`feature_library` is internal vocabulary only for v0.1.8.3. It does not appear
in user-facing function names or stored artifact schemas.

### 8. Active-Alias Synthesis Amendment Required

The active-alias synthesis at
`inst/design/rfc/rfc_active_parameterized_feature_aliases_v0_1_8_x_synthesis.md`
section 3 step 6 currently reads:

> `ledgr_sweep()` resolves once per candidate using that candidate's concrete
> params.

Taken literally, this implies per-candidate concrete-feature precompute, which
duplicates work whenever candidates share concrete feature values. That is
exactly the case the seed's parameterized sweep example exposes.

Amend the synthesis before the v0.1.8.4 ticket cut to bind:

- per-candidate alias resolution is correct;
- concrete-feature resolution is unioned across the grid and computed once;
- the union is produced by the extended `ledgr_precompute_features()` from
  v0.1.8.3;
- alias maps are stored in sweep/run identity and provenance (`alias_map_hash`,
  `config_hash`, persisted alias-map records) per the existing synthesis;
- at execution time, the runtime projection carries a derived alias-to-index
  map for cheap pulse access, sourced from the persisted alias map. The
  projection is not the storage layer for the alias map and has no hash.

Without this amendment, v0.1.8.4 either re-implements grid-level precompute or
inherits a wasteful per-candidate path. With the amendment, the v0.1.8.3
projection has a clean place to attach a per-candidate alias-index map without
expanding v0.1.8.3 scope to include alias-map identity or provenance.

---

## Required Verification Surfaces

The v0.1.8.3 ticket cut must require tests for:

- `ledgr_precompute_features()` emits matrices, indices, and a stable
  feature-engine version field that round-trips into the projection.
- Existing fingerprint stability pins
  (`tests/testthat/test-fingerprint-stability.R`) continue to pass; the
  projection must not perturb concrete feature fingerprints.
- Projection-vs-table parity: feature values reaching the strategy via
  matrix-index access are bit-exact equal to feature values reaching the
  strategy via the current accessor path on the reference workload.
- No-duplication parity: a concrete feature used by N candidates is computed
  once across the sweep, not N times.
- State-leak parity: `ctx$features_wide` captured at pulse `t` must not be
  mutated by the fold's pulse `t+1` work. Concrete assertion shape (no extra
  tooling required):

  ```r
  observed <- new.env(parent = emptyenv())
  observed$first <- NULL
  observed$second <- NULL
  strategy <- function(ctx, params) {
    if (is.null(observed$first)) {
      observed$first <- ctx$features_wide
    } else if (is.null(observed$second)) {
      observed$second <- ctx$features_wide
    }
    ctx$flat()
  }
  ledgr_run(...)
  snapshot_of_first <- observed$first
  observed$second[1, "sma_10"] <- -999     # mutate the second view
  testthat::expect_identical(observed$first, snapshot_of_first)
  ```

  This pins "no shared mutable storage between successive `ctx$features_wide`
  values" without needing address-introspection tooling. The same fixture
  works for the matrix-backed list returned by `ctx$features()`.
- LDG-2403 accounting parity tests continue to pass on the new fold path.
- Sweep parity tests continue to cover persistent-vs-memory reconstruction
  including realized/unrealized PnL columns.
- Metric-context regression: non-default risk-free rate continues to flow
  through `metric_kernel` after the fold rework.
- Fast-context activation (`use_fast_context`) is gated on the parity tests
  above and must produce bit-exact equivalent outputs to the current
  implementation on the reference workload.
- `ledgr_run()` and `ledgr_sweep()` both consume the same internal projection
  shape. The committed-run path is the one-candidate case and must not retain a
  separate table-access feature path after projection activation.

The post-change measurement (LDG-2410) should additionally report:

- fold percentage of sampled time, compared to the LDG-2402 baseline;
- allocation/GC pressure if tooling is reliable;
- which slice dominates after the change, to inform the v0.1.8.4 cut.

There is no fixed numeric speedup target. The gate remains the existing
evidence-based formulation: measured improvement on the target workload, no
correctness drift, no `ledgr_run()` regression, documented remaining hot
spots.

---

## Recommended Scope Boundaries

In scope for the expanded v0.1.8.3:

```text
typed memory events
single-pass summary reconstruction
ledgr_precompute_features() as the feature-library/projection extension point
runtime projection layer (matrices + indices, consumed by the shared
  ledgr_run()/ledgr_sweep() fold)
fast context B1 (lookup/closure init once per candidate, mutate per pulse)
fast context B2 (list-backed bars/features proxy structures)
current-row features_wide materialization policy (fresh view from backing)
projection and state-leak parity tests
post-change measurement and residual hot-path report
reserved internal NULL extension point on the projection for the v0.1.8.4
  alias-index map (no schema, no hash, no serialization in v0.1.8.3)
```

Out of scope for v0.1.8.3 (some moved into v0.1.8.4 explicitly):

```text
alias-map storage, schema, persistence, or hash         -> v0.1.8.4
alias_map_hash and config_hash changes                  -> v0.1.8.4
ctx$features("AAA") active-alias lookup                 -> v0.1.8.4
ledgr_parameters(features) introspection                -> v0.1.8.4
public ML training-frame or export API                  -> future ML RFC
DuckDB-backed long/wide research artifacts              -> future ML RFC
feature_library_hash introduction                       -> only when a
                                                           non-perf consumer
                                                           exists
projection hash                                         -> never (impl detail)
second feature engine or parallel precompute path       -> never
lazy ctx$features_wide via active bindings              -> deferred
field-to-function change for public context fields      -> deferred
public parameter-grid helpers                           -> v0.1.8.5
candidate ranking, winner selection, tuning DSL         -> later UX work
target-risk chain                                       -> v0.1.9
parallel sweep dispatch                                 -> later
compiled / Rcpp / Rust kernels                          -> later
```

The non-scope list is the discipline that prevents the expanded v0.1.8.3 from
sliding into v0.1.8.4 active-alias work or into ML/export territory.

---

## Sequencing Notes

Within the expanded v0.1.8.3 cycle, the recommended order is:

```text
1. ledgr_precompute_features() extension (projection emission, shape tests,
   and no-duplication tests)
2. runtime projection consumption in the shared fold core, with
   projection-vs-table and state-leak parity tests in the same acceptance gate
3a. typed memory events
3b. fast context B1 (in parallel with 3a after the projection gate is green)
4. single-pass summary reconstruction
5. fast context B2
6. post-change measurement and residual report
```

Why projection-first:

- typed events and single-pass summary should consume the projection's
  `pulse_idx` and shared concrete-feature backing, not invent their own;
- if typed events land before the projection, parts of the typed-event work
  must be redone once projection arrives;
- B1 closure reuse depends on stable per-candidate fold setup, which the
  projection provides.

The above is a sequencing recommendation, not a ticket ordering. Ticket cut
should preserve the dependency edges (projection before typed events, projection
before fast context, projection/state-leak tests before fast-context activation,
all parity tests before release gate) and may merge or split individual tickets
as needed.

---

## Required Documents

Before the expanded v0.1.8.3 ticket cut:

1. Amendment to `inst/design/ledgr_v0_1_8_3_spec_packet/v0_1_8_3_spec.md`
   updating Section 1 (Thesis), Section 3 (Out of Scope), and Section 3a (new
   In-Scope arc) to reflect the expanded R-level optimization scope, citing
   LDG-2402 baseline evidence as the justification.
2. New tickets for the projection extension, runtime projection consumption,
   fast context B1, and fast context B2. Projection/state-leak parity tests are
   acceptance criteria for the projection-consumption ticket, not a late
   follow-up. Existing typed-event and single-pass tickets keep their identity
   but pick up an additional dependency on the projection ticket.
3. Amendment to
   `inst/design/rfc/rfc_active_parameterized_feature_aliases_v0_1_8_x_synthesis.md`
   binding grid-level concrete-feature-union as the resolution model for
   parameterized sweeps, so v0.1.8.4 does not need to re-decide this.
4. `horizon.md` entry for the deferred research/export artifact and ML export
   RFC, so the rejected Broad scope items are not lost.

Do not open the new tickets until items 1, 2, and 3 are written and reviewed.
Quiet ticket drift on top of the existing v0.1.8.3 cut is the failure mode this
response is trying to prevent.

---

## Recommended Synthesis Positions

The synthesis should likely accept:

1. The four-layer model, with layer 4 deferred to a later RFC.
2. v0.1.8.3 expanded to cover the full R-level optimization arc, justified by
   LDG-2402 baseline.
3. `ledgr_precompute_features()` as the single feature precompute path,
   extended to emit projection inputs.
4. Runtime projection layer central, parity-tested, no hash.
5. `ctx$features_wide` materialized as a fresh current-row view from the
   projection; no mutable shells; laziness deferred.
6. DuckDB as cache and preparation layer only; no per-pulse traffic.
7. No `feature_library_hash` and no projection hash in v0.1.8.3.
8. Terminology pin: `feature_set`, `feature_library`, `alias_map`,
   `projection`.
9. Active-alias synthesis amendment binding grid-level concrete-feature-union
   for parameterized sweeps.
10. Verification surfaces enumerated above are required, not optional.
11. Pre-CRAN compatibility policy permits breaking development artifacts; no
    migration shims.
12. Durable research/export artifacts parked in `horizon.md` and a future ML
    RFC.

---

## Non-Goals Confirmed

- No alias-map storage, schema, persistence, or hash work in v0.1.8.3. Alias
  maps are execution interface and belong to the v0.1.8.4 active-alias design.
- No public ML training-frame or export API in v0.1.8.3 or v0.1.8.4.
- No DuckDB-backed long/wide research artifacts in v0.1.8.3 or v0.1.8.4.
- No second feature precompute path.
- No `feature_library_hash` until a non-perf consumer exists.
- No projection hash; projection is an implementation detail pinned by parity
  tests.
- No lazy `ctx$features_wide` via active bindings in this cycle.
- No field-to-function change for public context fields in this cycle.
- No `ctx$features("AAA")` active-alias lookup in v0.1.8.3.
- No parameter-grid helpers, candidate ranking, or winner selection in this
  cycle.
- No target-risk, parallel dispatch, or compiled kernel work in this cycle.
- No migration burden for pre-CRAN development artifacts.
