# RFC Response: Feature Projection Shape, Materialization Policy, And Lookback Access

**Status:** Reviewer response - accepts the setup-bottleneck correction, accepts
5.0 and 5.1 for the next cycle, narrows 5.6 sequencing, and defers the public
lookback API until after projection materialization is simplified.
**Date:** 2026-05-28
**RFC:** `inst/design/rfc/rfc_feature_projection_shape_and_lookback_v0_1_8_x.md`
**Reviewer:** Codex

---

## 1. Overall Assessment

I accept the corrected performance reading: the current fold loop is no longer
the primary bottleneck for the measured workload. The stale-build correction is
important and should remain prominent in the synthesis. The v0.1.8.3
fast-context consolidation removed the old per-pulse `features_wide` rebuild,
and the current source evidence points at setup/materialization costs before it
points at the engine.

I also accept the ordering of the first two levers:

1. **5.0 fingerprint memoization** should land first. This is a pure internal
   dedup if implemented carefully.
2. **5.1 stop eager full-panel long materialization** should land second. The
   code already has most of the fallback shape needed for a schema-only
   `ctx$feature_table`; the non-fast helper path needs to be corrected so it
   does not quietly rebuild long rows.

I refine the remaining scope. 5.6 is real, but it is storage/schema work and
should not block 5.0/5.1. 5.4 is a useful strategy surface, but it is a new API,
not a prerequisite for fixing the measured wall-clock costs. 5.3 and 5.5 should
stay collapse-decoupled.

The seed's main overreach is the width-invariance inference. The pulse sweep
justifies the setup-bottleneck reordering, but it does not prove loop throughput
is invariant across instruments or features. That claim needs a small
instrument x feature sweep before it is used in roadmap or benchmark language.

---

## 2. Corrections And Refinements

### 2.1 Stale-build correction

Accepted. The installed-package trap explains the initial "loop bottleneck"
reading. The response and synthesis should explicitly require source-version
guards for any future performance spike.

One artifact caveat: `dev/spikes/profile-loop.R` still appears to carry stale
wording about the loop being dominated by `t_loop`. If that file remains part of
the evidence packet, update its header before synthesis or mark it as a stale
profile harness.

### 2.2 `t_pre` attribution

The redundant feature fingerprint is a real cost, but the implementation should
memoize both pieces that are currently repeated inside cache-key construction:

- `ledgr_feature_def_fingerprint(def)`
- `ledgr_feature_engine_version()`

`ledgr_feature_cache_key()` includes both. Recomputing the engine version once
per `(instrument, feature)` is unnecessary in the run-fold precompute loop.
The target should be exact key equivalence, not a new key format.

### 2.3 Width invariance

Do not claim width-invariant loop throughput yet. A strategy that scores
`ctx$features_wide` must still do work proportional to `n_inst * n_feat`, and a
strategy that trades many instruments adds fill/event work proportional to the
number of changed targets. The loop may remain cheap enough, but this is not
proven by varying pulses only.

The missing sweep should vary instruments and features at fixed pulses, with at
least two strategy modes:

- a read/score mode with no fills, to isolate context and feature access;
- a turnover mode, to include event write and replay pressure.

### 2.4 Persistent event replay

The horizon entry for DuckDB SQL replay is distinct from LDG-2410 and should
stay distinct. LDG-2410 typed the in-memory sweep event path. The persistent
run path still serializes `meta_json` on write and parses it on run read-back,
resume, and reopen.

DuckDB SQL extraction is a valid narrow replay patch. It does not remove the
write-side `canonical_json()` cost and does not remove all JSON parsing from
immediate run reconstruction unless the run read-back path is also repointed.
Typed persistent columns are the complete fix.

---

## 3. Positions By Direction

### 3.1 Direction 5.0: memoize feature fingerprints across instruments

Accept for v0.1.8.6.

This can be a drop-in dedup with no fingerprint-stability risk if the memoized
values are the exact values produced today. Do not memoize by R object address
or environment identity. Memoize by the resolved concrete feature definition
used in the precompute loop, and prove equivalence by comparing generated cache
keys against `ledgr_feature_cache_key()`.

The cache should live at precompute scope, not in a global registry:

- in `ledgr_run_fold()`, before the `for (def in feature_defs)` loop that calls
  `ledgr_feature_cache_key()` once per instrument;
- optionally in shared precompute helpers where feature-definition fingerprints
  are used repeatedly for warmup/candidate tables;
- not in the persisted feature cache registry.

Recommended implementation shape:

1. Compute `feature_engine_version <- ledgr_feature_engine_version()` once for
   the run-fold precompute.
2. Compute `feature_fingerprints[[def$id]] <- ledgr_feature_def_fingerprint(def)`
   once per concrete feature definition.
3. Route key construction through an internal helper that accepts the already
   computed `indicator_fingerprint` and `feature_engine_version`.
4. Add a test that the helper returns byte-identical keys to the current
   `ledgr_feature_cache_key()` for scalar, multi-output, parameterized, and
   explicit-fingerprint feature definitions.

This is the safest first ticket because it changes no public contract, no cache
schema, and no fingerprint value.

### 3.2 Direction 5.1: stop eager full-panel long materialization

Accept, with a narrower declaration mechanism.

Do not make this an experiment flag and do not infer it from strategy source.
Also avoid a per-strategy capability hint for the first pass; it adds contract
surface for a representation we already intend to demote. The right mechanism is
an internal construction-time view policy:

- default: build `features_wide` and a zero-row/schema-only `feature_table`;
- explicit internal opt-in: build full long `feature_table` for tests, debugging,
  and any compatibility path that truly needs it;
- inspection: compute a single-pulse long table on demand, never the full panel.

This respects the LDG-2413 non-goal. `ctx$feature_table` remains a plain
data.frame field. It is not an active binding and not a function-valued data
field. The difference is construction policy, not access-time laziness.

One important implementation warning: the non-fast context helper currently
rebuilds a pulse long table when `features` is empty and a projection is
available. 5.1 must change that behavior, otherwise schema-only long will
silently become full long on the non-fast path. The fast path already accepts
the supplied `features` object.

Keep 5.1 separate from formal deprecation. The synthesis should say:

- v0.1.8.6 changes the default materialization policy;
- `ctx$feature_table` remains present but may be schema-only unless an internal
  consumer requests full long rows;
- public deprecation of `ctx$feature_table` is a later lifecycle decision after
  documentation and usage guidance have caught up.

Tests that currently mutate or compare `ctx$feature_table` should opt into full
long views or move to `features_wide` when the behavior being tested is not
specifically long-table behavior.

### 3.3 Direction 5.2: wide as canonical decision-time surface

Accept.

The synthesis should bind this as a documentation and contract statement:
decision-time cross-sectional work uses scalar/vector accessors or
`ctx$features_wide`; long is an export, inspection, compatibility, or research
shape.

### 3.4 Direction 5.3: per-pulse long convenience

Accept only as a free function first.

Use `ledgr_features_long(ctx)` or an equivalent exported helper that melts the
current pulse from `features_wide` or projection state. Keep it base R in the
first pass. Do not add collapse for this convenience. A `ctx$features_long()`
helper can be reconsidered later, but a free function is cleaner for the
deprecation arc because it avoids adding another callable field to the context.

### 3.5 Direction 5.4: `ctx$window()` lookback

Accept the need, defer the public API until after 5.0/5.1.

First contract should be deliberately small:

- single feature per call;
- return an `n_inst x lookback` numeric matrix;
- row order is `ctx$universe`;
- columns are oldest to current;
- column names are pulse timestamps or stable positional names, decided in the
  synthesis;
- early pulses return leading `NA_real_` columns by default, not a short matrix
  and not an error.

`stable_after` should remain encoded in feature values. `ctx$window()` should
not add a second warmup contract. If a feature is not stable yet, its matrix
entries are `NA`; the caller decides whether to skip, impute, or trade flat.

The "feature vs window" line should be:

- make it a feature when the transform is scalar, reusable, and
  instrument-local, such as rolling mean, rolling volatility, RSI, or a lagged
  return;
- use `ctx$window()` when the calculation is strategy-local, multivariate,
  cross-instrument, or model-specific, such as covariance, risk parity, PCA, or
  a fitted policy state tensor.

Do not ship list returns or multi-feature tensors in the first public version.
They can be added later without breaking the matrix contract.

### 3.6 Direction 5.5: long as export/research-layer format

Accept as later work.

This belongs at the research/export boundary, not in the fold loop. Full-panel
long is useful for training, EDA, and external feature-store interchange. It
should not be rebuilt for every run by default.

### 3.7 Direction 5.6: typed persistent event columns

Accept the direction, but sequence it after 5.0/5.1 unless the packet explicitly
chooses storage work.

If implementing 5.6, prefer typed persistent columns over a SQL-only interim.
The SQL interim is acceptable only as a narrow replay acceleration because it
does not remove write-side JSON serialization and does not fully simplify the
run read-back path.

Typed-column route:

- add nullable typed columns for at least `cash_delta` and `position_delta`;
- keep `meta_json` for compatibility and less common metadata;
- write typed deltas directly from the existing fill payload;
- backfill old rows from `meta_json` during schema migration or read them through
  a compatibility fallback;
- update run read-back, resume state, and derived-state replay to prefer typed
  columns when present and fall back to JSON otherwise.

The migration cost is moderate, not trivial. Adding nullable columns is easy;
the hard part is parity across old stores, new stores, and mixed stores. The
acceptance gate must compare typed-column replay with the current JSON replay
for cash, positions, equity, fills, and resume state.

### 3.8 Direction 5.7: primitive internals and collapse

Accept.

Use primitive-internals discipline broadly. Do not add collapse as an Imports
dependency for 5.0, 5.1, 5.3, or 5.4. Collapse can remain a measured,
determinism-wrapped dependency decision for v0.1.9 work, not a blanket style
change.

---

## 4. Sequencing Recommendation

### v0.1.8.6

Primary scope:

1. Land 5.0 fingerprint/cache-key dedup.
2. Land 5.1 schema-only default for `ctx$feature_table`.
3. Remeasure after each change separately via source `load_all`.
4. Add the missing instrument x feature sweep before publishing any
   width-invariance claim.

Secondary scope if capacity remains:

- decide 5.6 design and migration shape;
- implement typed persistent columns only if the packet explicitly accepts the
  schema work;
- otherwise leave 5.6 as designed, not half-implemented.

DuckDB-backed projection work should consume the simplified projection contract
after 5.1. It should not reintroduce per-pulse DBI access or full-panel long
materialization.

### v0.1.9

Keep collapse and primitive-internals work surgical. Collapse does not gate
5.0/5.1 and should not be pulled into the fold loop just because this RFC
mentions long reshaping.

If target-risk or portfolio-risk work needs covariance windows, `ctx$window()`
can enter v0.1.9 as a small API. If not, defer it to v0.1.9.x or later.

### Later

- full-panel long export/training APIs;
- multi-feature window/tensor extensions;
- point-in-time regressor feature-store interchange;
- broader typed event metadata beyond the deltas needed for replay.

---

## 5. Answers To Open Questions

1. **5.1 gating.** Use an internal construction-time view policy. Default to
   wide plus schema-only long. Full long is explicit internal opt-in.
2. **Validator schema.** Yes. Validators should use projection feature IDs or a
   zero-row schema frame. They do not need full row data.
3. **Inspection helper.** Per-pulse on-demand long is acceptable and preferable.
   No documented inspection workflow should require a full-panel long build
   inside the fold.
4. **5.4 return shape.** First version should be single-feature
   `n_inst x lookback` matrix, oldest-to-current columns, leading `NA_real_`
   warmup columns.
5. **5.4 vs features.** Instrument-local reusable transforms are features.
   Cross-instrument, model-local, or matrix calculations use `ctx$window()`.
6. **5.3 placement.** Free function first. A ctx helper is optional later and
   should not be required for 5.1.
7. **Sequencing.** 5.0 -> 5.1 in v0.1.8.6, 5.6 only if schema work is accepted,
   5.4 only when a strategy/risk ticket needs it, collapse work in v0.1.9.
8. **Deprecation coupling.** Keep materialization policy and public deprecation
   separate. Change default construction first; deprecate later if usage stays
   absent.
9. **5.0 memoization scope.** It is a drop-in only if memoized values are exact
   current fingerprints/engine versions and exact cache-key parity is tested.
   Do not cache by object address.
10. **5.6 route.** Prefer typed DB columns if implementing the fix. Use DuckDB
    SQL extraction only as a temporary replay patch, not as the final design.

---

## 6. Required Synthesis Gates

The synthesis should bind the following gates:

- 5.0 exact cache-key parity against `ledgr_feature_cache_key()` before and
  after memoization.
- Source-version guard in all performance spikes.
- Separate remeasurement after 5.0 and after 5.1.
- Instrument x feature sweep before any benchmark claim about width-invariant
  loop throughput.
- 5.1 parity for event streams with full long enabled and with schema-only long
  default.
- A fixture proving the non-fast context path does not rebuild long rows unless
  full long is requested.
- Existing feature-table tests either opt into full long views or move to
  `features_wide`.
- 5.6 typed-column replay parity against JSON replay for old and new stores if
  typed persistent columns are implemented.

