# RFC Seed: Grid-Level Feature Artifacts And Wide Runtime Views

**Status:** Design seed - response required before synthesis or ticket cut.
**Date:** 2026-05-25
**Author:** Codex
**Inputs:**

- `rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md` - accepted
  v0.1.8.x sweep optimization arc.
- `rfc_active_parameterized_feature_aliases_v0_1_8_x_synthesis.md` - accepted
  v0.1.8.4 active-alias and parameterized-feature design.
- `inst/design/ledgr_v0_1_8_3_spec_packet/v0_1_8_3_spec.md` - current
  performance release spec.
- LDG-2402 - v0.1.8.2 baseline measurement and hot-path profile.
- LDG-2403 - persistent-versus-memory accounting parity gate.
- Maintainer discussion on precomputed wide feature backing, parameterized
  indicator sweeps, ML training exports, and DuckDB artifact roles.

---

## 1. Problem Statement

The v0.1.8.3 baseline confirms that ledgr is paying substantial R-side fold
overhead. The accepted optimization synthesis already names eager
`features_wide` construction as a measured cost: the fold may build wide feature
payloads on every pulse even when the strategy uses only scalar feature access.

The tempting narrow fix is laziness:

```text
do not build ctx$features_wide until strategy code reads it
```

That is directionally right for the hot loop, but it is not the whole design.
Future ledgr surfaces will need full wide feature artifacts:

- ML training-frame exports;
- feature inspection and diagnostics;
- parameterized indicator sweeps;
- active alias provenance;
- benchmark and selection-integrity reports;
- reproducible research artifacts.

The actual design question is therefore larger than "make
`ctx$features_wide` lazy":

> Should ledgr introduce a grid-level concrete feature artifact/library, with
> candidate-level alias views into it, and use that as the shared substrate for
> sweeps, active aliases, runtime pulse context, and future ML exports?

This seed proposes the design space. It is not binding implementation scope for
v0.1.8.3 until a response and synthesis decide what, if anything, moves into the
current packet.

---

## 2. Core Distinction

There are two different "wide feature" products.

### Research Artifact

A full wide table over many timestamps, instruments, and concrete feature IDs:

```text
ts_utc | instrument_id | sma_10 | sma_20 | rsi_14 | ...
```

This is useful for:

- ML training and scoring exports;
- visual inspection;
- leak checks;
- joins to labels, benchmark returns, calendars, and instrument metadata;
- durable research artifacts;
- candidate diagnostics.

It is allowed to be DuckDB-backed, persisted, queried, pivoted, exported, and
versioned.

### Runtime Pulse View

A current-pulse view exposed through `ctx`:

```r
ctx$feature("AAA", "sma_20")
ctx$features("AAA")
ctx$features_wide
```

This is inside the fold hot loop. It should be derived from precomputed backing
data using cheap row/index views. It should not query DuckDB per pulse, rebuild
the full wide table per pulse, or reshape feature payloads repeatedly.

The same concrete feature values can back both products, but their
materialization policy should differ.

---

## 3. Parameterized Sweep Example

Active aliases make the feature-artifact question unavoidable. Consider:

```r
features <- ledgr_feature_map(
  fast = ledgr_ind_sma(ledgr_param("fast_n")),
  slow = ledgr_ind_sma(ledgr_param("slow_n"))
)

grid <- ledgr_grid_cross(
  fast_n = c(10L, 20L, 50L),
  slow_n = c(100L, 200L)
)
```

The concrete feature values needed by the grid are:

```text
sma_10
sma_20
sma_50
sma_100
sma_200
```

They should be computed once as a grid-level concrete feature library, not once
per candidate.

Each candidate then needs only an alias view:

```text
candidate fast_n=20, slow_n=100:
  fast -> sma_20
  slow -> sma_100

candidate fast_n=50, slow_n=200:
  fast -> sma_50
  slow -> sma_200
```

The strategy-facing interface remains candidate-specific:

```r
strategy <- function(ctx, params) {
  x <- ctx$features("AAA")
  if (x[["fast"]] > x[["slow"]]) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    return(targets)
  }
  ctx$flat()
}
```

The storage and runtime substrate should not duplicate a full candidate-specific
wide table for every grid row when candidates share concrete feature values.

---

## 4. Proposed Conceptual Model

The target model has four layers.

### 4.1 Grid-Level Concrete Feature Library

Before sweep execution, ledgr materializes the union of concrete features needed
by the grid:

```text
feature library =
  snapshot hash
  scoring/warmup range
  universe
  concrete feature declarations
  concrete feature IDs
  concrete feature fingerprints
  feature-engine version
  feature values
```

This layer is concrete-only. It does not know strategy aliases such as `fast`
or `slow` except as provenance from authored declarations.

### 4.2 Candidate Alias Views

Each candidate stores a view into the concrete library:

```text
candidate id | alias | concrete feature id | parameter provenance
```

For active aliases, this is the resolved alias map accepted by
`rfc_active_parameterized_feature_aliases_v0_1_8_x_synthesis.md`.

### 4.3 Runtime Projection

The fold core receives an in-memory runtime projection:

```text
concrete feature matrices
alias -> feature matrix mapping
instrument -> row index
pulse_idx
feature_id -> matrix index
```

The pulse context updates `pulse_idx` per pulse. Feature accessors read the
current value by pointer/index. `ctx$features_wide` becomes a current-pulse view
over the same backing data, not a recomputation of the backing data.

### 4.4 Research / Export Artifact

DuckDB may store or derive long and wide artifacts for inspection and ML:

```text
feature_values_long:
  ts_utc
  instrument_id
  feature_id
  feature_fingerprint
  feature_value

feature_values_wide:
  ts_utc
  instrument_id
  sma_10
  sma_20
  rsi_14
  ...

candidate_alias_map:
  candidate_id
  alias
  feature_id
  param_name
  param_value
```

This artifact layer can use SQL pivots, joins, filters, and export formats. The
runtime fold should consume an in-memory projection of it, not issue SQL calls
per pulse.

---

## 5. DuckDB Role

DuckDB is a good fit for the artifact layer:

- long-to-wide pivots;
- joining bars, features, labels, instruments, calendars, and future
  point-in-time data;
- exporting CSV/Parquet evidence;
- constructing ML training frames;
- filtering candidate windows and selection views;
- storing provenance-rich research artifacts.

DuckDB is not a good fit for per-pulse strategy access:

- the baseline reference workload executes thousands of pulses;
- DBI round trips per pulse would dominate small scalar reads;
- strategies need current-row scalar/vector access, not relational query
  planning;
- `ledgr_run()` and `ledgr_sweep()` must keep sharing the same no-lookahead
  fold semantics.

Recommended direction:

```text
DuckDB artifact / cache
  -> R in-memory runtime projection
  -> pulse context row/index access
```

Avoid:

```text
pulse -> DBI query -> current feature values
```

---

## 6. Identity And Provenance Questions

A synthesis must decide the exact identity surfaces. Candidate model:

```text
concrete_feature_library_hash:
  snapshot hash
  universe
  scoring/warmup range
  concrete feature fingerprints
  feature-engine version

alias_map_hash:
  candidate alias -> concrete feature id
  parameter reference provenance

artifact_hash:
  feature library hash
  artifact schema/version
  storage format and canonical ordering
```

This should compose with the accepted active-alias decision:

- `feature_set_hash` remains concrete-feature-only.
- `alias_map_hash` tracks strategy-facing alias provenance.
- `config_hash` includes the resolved alias map because aliases are execution
  interface.
- concrete feature fingerprints do not change.

Open question: should a future durable feature artifact have its own hash
separate from `feature_set_hash`, or is the feature library hash sufficient?

---

## 7. `ctx$features_wide` Semantics

The first optimization should not change the public meaning of
`ctx$features_wide`.

Open implementation choices:

1. **Eager current-row materialization from precomputed backing**
   Build the current-row wide view each pulse from matrices and stable column
   metadata. This is simpler but still allocates per pulse.

2. **Lazy current-row materialization from precomputed backing**
   Install a context binding that materializes the current-row wide view only
   if strategy code reads `ctx$features_wide`.

3. **Reusable mutable row shell**
   Reuse one data-frame-like object and update its values per pulse. This may
   be fastest but risks state leaks if user code stores the object.

Conservative preference for a first response:

```text
precompute backing data once;
materialize current-row wide views lazily or cheaply;
do not reuse mutable public objects unless tests prove no state leakage.
```

The most important constraint is that the fold no longer recomputes feature
values or reshapes the full feature payload on every pulse.

---

## 8. Relationship To v0.1.8.3

The current v0.1.8.3 spec targets:

- typed memory events;
- single-pass sweep summary reconstruction;
- post-change measurement and residual hot-path report;
- routed auditr fixes.

The baseline now suggests that fold-context overhead is the larger lever. The
maintainer is considering expanding v0.1.8.3 to include all R-level hot-path
optimizations.

This RFC seed suggests three possible scopes.

### Narrow v0.1.8.3

Keep current ticket cut:

```text
typed events + single-pass summary only
```

Feature artifact design remains future work.

### Medium v0.1.8.3

Add R-level runtime payload optimization:

```text
fast context
precomputed feature backing
cheap/lazy current-pulse wide view
no durable feature artifact API
no public ML export API
```

This likely belongs in the current performance release if response/synthesis
agree that it can be implemented without altering public feature semantics.

### Broad Future Cycle

Introduce a durable feature-artifact surface:

```text
grid-level feature library
DuckDB-backed long/wide artifact
candidate alias maps into the library
ML/training-frame export hooks
artifact hashes and persistence policy
```

This likely belongs after active aliases and parameter-grid helper work, not in
v0.1.8.3.

Seed recommendation:

```text
Medium now, broad later.
```

Use v0.1.8.3 to stop doing avoidable R work inside the fold. Use v0.1.8.4+
active aliases and later ML/export design to introduce durable grid-level
feature artifacts.

---

## 9. Non-Goals For This RFC

This seed does not propose:

- a second execution engine;
- SQL execution of strategy logic;
- per-pulse DuckDB feature lookup;
- automatic winner selection or ranking;
- public ML training-frame API;
- point-in-time external data semantics;
- benchmark-relative metrics;
- compiled fold-core work;
- a new indicator fingerprint family;
- changing `ctx$features_wide` from a field to a function without a separate
  public-context decision.

---

## 10. Questions For Response

1. Is the four-layer model correct: concrete feature library, candidate alias
   view, runtime projection, research/export artifact?
2. Should v0.1.8.3 expand to the medium scope, or should all feature-artifact
   work wait until active aliases?
3. Should `ctx$features_wide` be lazily materialized from precomputed backing,
   eagerly materialized as a cheap current-row view, or redesigned later?
4. Should DuckDB-backed wide artifacts be designed now as an internal cache, or
   deferred until a public ML/export artifact API exists?
5. What hash surfaces are required beyond `feature_set_hash` and
   `alias_map_hash`?
6. How should precomputed feature libraries interact with
   `ledgr_precompute_features()` and existing feature cache keys?
7. For parameterized indicator sweeps, should ledgr compute the concrete
   feature union across the whole grid before candidate execution?
8. What tests must pin the no-duplication property: same concrete feature used
   by multiple candidates is computed once and viewed many times?
9. What tests must pin pulse-context behavior so optimized wide views cannot
   leak mutable state across pulses?
10. Should this RFC chain produce a v0.1.8.3 spec amendment, a v0.1.8.4
    active-alias amendment, or a later architecture note?

---

## 11. Suggested Next Step

Write a response that takes positions on:

- v0.1.8.3 scope: narrow, medium, or broad;
- runtime `ctx$features_wide` materialization policy;
- DuckDB role and non-role;
- grid-level concrete feature union for parameterized sweeps;
- hash/provenance surfaces;
- test surfaces for state leakage and duplicate feature computation.

If the response accepts the medium v0.1.8.3 scope, amend the v0.1.8.3 spec and
ticket packet before opening the remaining optimization tickets.
