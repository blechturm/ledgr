# RFC Synthesis: Feature Projection Shape, Materialization Policy, And Lookback Access

**Status:** Accepted synthesis - binding planning direction for v0.1.8.6
feature-projection materialization work and later lookback/export/storage
follow-ups. Final review accepted with no blocking issues.
**Date:** 2026-05-28
**Author:** Codex
**Thread:**

- `inst/design/rfc/rfc_feature_projection_shape_and_lookback_v0_1_8_x.md`
- `inst/design/rfc/rfc_feature_projection_shape_and_lookback_v0_1_8_x_response.md`
- `inst/design/rfc/rfc_feature_projection_shape_and_lookback_v0_1_8_x_seed_v2.md`
- `inst/design/rfc/rfc_pulse_context_data_model_consolidation_v0_1_8_3_synthesis.md`
- `inst/design/rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`
- `inst/design/rfc/rfc_collapse_primitive_internals_v0_1_9_synthesis.md`
- `dev/spikes/spike-feature-payload-dps.R`
- `dev/spikes/profile-loop.R`

This synthesis uses no "v1" shorthand for a feature implementation. Bound work
is assigned to named roadmap windows: v0.1.8.6, v0.1.9, or later.

---

## 1. Decision Summary

The corrected current-source performance frame is accepted. The initial
catastrophic reading was caused by profiling an installed v0.1.8.0 build rather
than the current source. Against the current source, the fold loop is not the
dominant measured bottleneck for the spike workload; setup/materialization work
is.

This synthesis binds the v2 direction:

- v0.1.8.6 first removes redundant feature cache-key work (Direction 5.0).
- v0.1.8.6 then stops building the full-panel long `feature_table` by default
  (Direction 5.1).
- `ctx$features_wide` and projection-backed scalar/vector accessors are the
  canonical decision-time surfaces (Direction 5.2).
- A per-pulse long convenience may ship as a free function, base R only, after
  the default long build is removed (Direction 5.3).
- `ctx$window()` is accepted as a needed lookback primitive but is not part of
  the immediate 5.0/5.1 materialization fix; it enters v0.1.9 only if
  target-risk or portfolio-risk work needs covariance windows (Direction 5.4).
- Full-panel long export/training surfaces are deferred to a later research
  layer (Direction 5.5).
- Typed persistent event columns are accepted as the complete persistent replay
  fix, but they are implemented in v0.1.8.6 only if storage/schema work is
  explicitly accepted for the packet (Direction 5.6).
- Primitive-internals discipline is accepted broadly; the collapse dependency
  remains surgical and does not gate 5.0, 5.1, 5.3, or 5.4 (Direction 5.7).

The v1 width-invariance inference is withdrawn. A pulse-only sweep is enough to
justify the setup-bottleneck ordering, but not enough to claim loop throughput
is invariant across instruments or features.

---

## 2. Code Evidence Bound Into This Synthesis

The synthesis binds these code facts for final-review verification:

- `ledgr_run_fold()` calls `ledgr_feature_cache_key()` inside the per-feature,
  per-instrument loop ([R/backtest-runner.R:1214](../../../R/backtest-runner.R)).
  `ledgr_feature_cache_key()` recomputes both
  `ledgr_feature_def_fingerprint(feature_def)` and
  `ledgr_feature_engine_version()` in each key
  ([R/feature-cache.R:94-95](../../../R/feature-cache.R)).
- `ledgr_projection_pulse_views()` allocates both `feature_table` and
  `features_wide` views ([R/runtime-projection.R:233-234](../../../R/runtime-projection.R))
  and builds/splits the long `feature_table` for all pulses
  ([R/runtime-projection.R:276-287](../../../R/runtime-projection.R)).
- The fold already tolerates absent `feature_table` views by falling back to a
  schema-shaped empty frame ([R/fold-core.R:99-108](../../../R/fold-core.R)),
  but the non-fast helper path currently rebuilds long rows when `features` is
  empty and a projection is present
  ([R/pulse-context.R:233-235](../../../R/pulse-context.R)).
- The persistent buffered output handler is already column-primitive at the R
  boundary, but its persisted event columns still include only `meta_json` for
  deltas ([R/backtest-runner.R:362-485](../../../R/backtest-runner.R)).
- The `ledger_events` schema has `meta_json` but no typed `cash_delta` or
  `position_delta` columns
  ([R/db-schema-create.R:194-208](../../../R/db-schema-create.R)).
- The direct ledger writer computes `cash_delta` and `position_delta`, places
  them in `meta_json`, and inserts only the current schema columns
  ([R/ledger-writer.R:66-86](../../../R/ledger-writer.R),
  [R/ledger-writer.R:101-131](../../../R/ledger-writer.R)).
- Persistent replay paths parse `meta_json` for cash and position deltas
  ([R/derived-state.R:25-37](../../../R/derived-state.R),
  [R/derived-state.R:69-76](../../../R/derived-state.R)), and the immediate run
  read-back does the same
  ([R/backtest-runner.R:1335-1391](../../../R/backtest-runner.R)).
- The in-memory sweep path is already the LDG-2410-style typed event path:
  it stores `cash_delta` and `position_delta` in event columns and attaches
  typed metadata to ordered events
  ([R/sweep.R:710-723](../../../R/sweep.R),
  [R/sweep.R:812-814](../../../R/sweep.R)).

These facts are consistent with the predecessor syntheses: LDG-2413 kept public
context fields as fields rather than active bindings; the grid-level projection
synthesis established the list-of-matrices runtime projection; and the collapse
synthesis makes collapse conditional on measured value and determinism gates.

---

## 3. Bound Positions By Direction

### Direction 5.0 - Feature cache-key memoization

**Accepted for v0.1.8.6. First implementation step.**

Hoist both repeated cache-key components out of the per-(instrument, feature)
loop:

- `ledgr_feature_def_fingerprint(def)`
- `ledgr_feature_engine_version()`

Memoization is precompute-scoped, not global and not part of the persisted
feature-cache registry. It must be keyed by the resolved concrete feature
definition used for execution, not by R object address or environment identity.

**Gate:** exact cache-key parity against `ledgr_feature_cache_key()` before and
after memoization, covering scalar, multi-output, parameterized, and
explicit-fingerprint feature definitions. This is a pure dedup: no public
contract change, no cache schema change, and no fingerprint-value change.

### Direction 5.1 - Stop eager full-panel long materialization

**Accepted for v0.1.8.6. Second implementation step.**

Use an internal construction-time view policy:

- default: build `features_wide` plus a zero-row/schema-only `feature_table`;
- explicit internal opt-in: build full long `feature_table` for tests,
  debugging, and compatibility paths that truly need it;
- inspection: compute a single-pulse long table on demand, never the full panel.

Rejected mechanisms for this cycle:

- experiment-level flag;
- strategy-source inference;
- per-strategy capability hint.

This preserves the LDG-2413 non-goal. `ctx$feature_table` remains a plain
data.frame field, not an active binding and not a function-valued data field.
The change is construction policy, not access-time laziness.

**Gate:** full-long-enabled and schema-only-default runs produce identical event
streams on reference workloads. Add a fixture proving the non-fast context path
does not rebuild long rows unless full long is requested. Existing tests that
depend on long rows must either opt into full long or move to `features_wide`.

This does not deprecate `ctx$feature_table`. Public deprecation is a later
lifecycle decision after documentation and usage guidance have caught up.

### Direction 5.2 - Wide as canonical decision-time surface

**Accepted as a contract/documentation position.**

Decision-time cross-sectional strategy work uses one of:

- `ctx$feature(id, name)`;
- `ctx$features(id, map)`;
- `ctx$features_wide`.

Long is an export, inspection, compatibility, or research shape. It is not the
default runtime strategy surface.

### Direction 5.3 - Per-pulse long convenience

**Accepted as a free function, not a ctx helper, in the first pass.**

The first convenience is `ledgr_features_long(ctx)` or equivalent: exported,
base R, current pulse only, backed by `features_wide` or projection state. No
collapse import is authorized by this direction. A future ctx helper may be
reconsidered only after the `ctx$feature_table` lifecycle is clearer.

**Gate:** public schema parity with the current per-pulse long shape when full
long is requested, and no full-panel materialization.

### Direction 5.4 - Lookback primitive

**Accepted as a needed API; deferred from the immediate 5.0/5.1 work.**

If it enters v0.1.9 because target-risk or portfolio-risk needs covariance
windows, the first contract is:

- single feature per call;
- return an `n_inst x lookback` numeric matrix;
- rows are in `ctx$universe` order;
- columns are oldest to current;
- early pulses return leading `NA_real_` columns, not a short matrix and not an
  error;
- `stable_after` remains encoded in feature values, so the window adds no
  second warmup contract;
- no list returns and no multi-feature tensors in the first public version.

**Gate:** no-lookahead fixtures proving a window at pulse `t` reads no feature
column greater than `t`, plus parity on warmup/NA behavior.

`ctx$window()` is for strategy-local, cross-instrument, multivariate, or matrix
calculations such as covariance, risk parity, PCA, and policy state. Reusable
instrument-local scalar transforms remain features.

### Direction 5.5 - Long as export/research-layer format

**Accepted as later work.**

Full-panel long is a research/export/training shape, not a fold-loop runtime
shape. It belongs in a separate research-layer or feature-store API cycle.

### Direction 5.6 - Typed persistent event columns

**Accepted direction; conditional v0.1.8.6 storage work.**

Typed persistent columns are the complete fix. DuckDB SQL extraction from
`meta_json` is only a replay patch: it does not remove write-side JSON
serialization and does not fully simplify immediate run read-back.

If v0.1.8.6 explicitly accepts storage/schema work, add nullable typed columns
for at least:

- `cash_delta`;
- `position_delta`.

Keep `meta_json` for compatibility and less common metadata. New writes prefer
typed deltas; old stores are migrated or read through JSON fallback. Run
read-back, resume state, and derived-state replay prefer typed columns when
present and fall back to JSON otherwise.

**Gate:** typed-column replay parity against JSON replay for cash, positions,
equity, fills, and resume state across old, new, and mixed stores.

If storage/schema work is not explicitly accepted, leave 5.6 designed and do
not ship a half-implemented SQL-only replay patch under this RFC.

### Direction 5.7 - Primitive internals and collapse

**Accepted as a rule.**

Primitive-internals discipline applies broadly. Collapse remains conditional,
measured, and determinism-wrapped under the v0.1.9 collapse synthesis. No
collapse Imports dependency is authorized for 5.0, 5.1, 5.3, or 5.4. Typed
persistent columns come before any new collapse import.

---

## 4. Binding Sequencing

### v0.1.8.6 primary path

1. Land 5.0 feature cache-key dedup.
2. Land 5.1 schema-only `feature_table` default plus the non-fast-path fix.
3. Remeasure after 5.0 and after 5.1 separately via source `load_all`.
4. Run the instrument x feature sweep before any width-invariance or benchmark
   claim enters roadmap or public-facing language.

DuckDB-backed projection/storage work consumes the simplified projection
contract after 5.1. It must preserve the no-per-pulse-DBI boundary from the
predecessor syntheses and must not reintroduce full-panel long materialization.

### v0.1.8.6 conditional storage path

5.6 may land in v0.1.8.6 only if storage/schema work is explicitly accepted in
the packet. If accepted, implement typed persistent columns, not a SQL-only
interim as the final shape. If not accepted, leave 5.6 as a designed follow-up.

### v0.1.9

Collapse remains surgical and gated by the primitive-internals synthesis.
`ctx$window()` enters v0.1.9 only if target-risk or portfolio-risk work needs
covariance windows. Otherwise it moves to a later API cycle.

### Later

Later cycles own full-panel long export/training APIs, multi-feature/tensor
window extensions, PIT feature-store interchange, and broader typed event
metadata.

---

## 5. Synthesis Gates

The following gates are binding for ticket cut:

- 5.0 exact cache-key parity, covering both the feature-definition fingerprint
  and feature-engine version.
- Source-version guards in performance spikes; `load_all` source runs are the
  measurement default.
- Separate remeasurement after 5.0 and after 5.1.
- Instrument x feature sweep before any width-invariance or benchmark claim.
  The sweep must include a read/score/no-fill mode and a turnover mode.
- 5.1 event-stream parity for full-long-enabled vs schema-only-default runs.
- A non-fast context fixture proving long rows are not rebuilt unless full long
  is requested.
- Existing feature-table tests either opt into full long views or move to
  `features_wide`.
- 5.4 no-lookahead and warmup/NA fixtures if `ctx$window()` is pulled into the
  implementation window.
- 5.6 typed-column replay parity against JSON replay across old, new, and mixed
  stores if typed persistent columns are implemented.
- Existing fingerprint-stability pins and LDG-2403 accounting parity remain
  green after each result-affecting change.

---

## 6. Open Questions Promoted To Spec-Cut

These are within-window implementation decisions for the spec/ticket writer, not
future RFC obligations:

1. **`ctx$window()` column naming.** If `ctx$window()` enters v0.1.9, choose
   pulse timestamp column names or stable positional names.
2. **Full-long opt-in surface for 5.1.** Choose the exact internal mechanism:
   function argument, policy enum, or internal sentinel. It must remain
   construction-time and internal.

---

## 7. Future Obligations Recorded

These are separate later design or implementation obligations:

- **5.4 multi-feature/tensor windows.** Multi-feature matrices, tensors, or
  list returns require a follow-up API decision after the single-feature matrix
  contract exists.
- **5.5 export/training APIs.** Full-panel long feature exports, ML training
  frames, and tidy research-layer tools require a separate research/export API
  cycle.
- **PIT interchange.** Point-in-time regressor and feature-store interchange
  belongs with the later PIT/data-provider track.
- **Broader typed event metadata.** Typed persistent `cash_delta` and
  `position_delta` are the first replay columns; broader event metadata needs a
  later event-schema decision if it becomes load-bearing.

---

## 8. Post-Synthesis Horizon Entry

The following entry should be added to `inst/design/horizon.md` after final
review accepts this synthesis.

```markdown
### 2026-05-28 [optimization] Feature projection shape post-v0.1.8.x direction

The accepted synthesis
`rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md` binds the
next feature-projection materialization direction: v0.1.8.6 first removes
redundant cache-key fingerprint work, then stops building full-panel long
`ctx$feature_table` rows by default. Wide/projection-backed accessors are the
decision-time surface; long becomes inspection/export/research shape. This entry
uses no feature "v1" shorthand; work is assigned to v0.1.8.6, v0.1.9, or later.

#### Lookback and portfolio windows

- `ctx$window()` is accepted as the causal lookback primitive, but enters
  v0.1.9 only if target-risk or portfolio-risk work needs covariance windows.
- First public shape, when cut, is single-feature `n_inst x lookback` matrix
  with leading `NA_real_` warmup columns.
- Multi-feature/tensor/list window shapes are future API work after the first
  matrix contract exists.

#### Long research/export layer

- Runtime long `ctx$feature_table` is not the training-frame surface.
- Full-panel long feature export, ML training frames, and tidy EDA helpers need
  a separate research/export API cycle.
- PIT regressor and feature-store interchange belong with the later PIT/data
  provider track.

#### Persistent event schema and replay

- LDG-2410 typed memory events are complete and memory-scoped.
- Typed persistent columns for `cash_delta` and `position_delta` are the
  persistent counterpart and are preferred over a DuckDB-SQL-only replay patch
  if storage/schema work is accepted.
- Broader typed event metadata remains future event-schema work.

#### DuckDB-backed projection and storage

- v0.1.8.6 DuckDB/storage work should consume the simplified projection
  contract after schema-only `feature_table` is in place.
- DuckDB must remain a block/storage boundary, not a per-pulse runtime query
  engine.
- No future storage path should reintroduce full-panel long materialization by
  default.

#### Collapse and primitive internals

- Primitive-internals discipline applies broadly.
- No collapse Imports dependency is authorized by the feature-projection
  materialization directions.
- Collapse remains governed by
  `rfc_collapse_primitive_internals_v0_1_9_synthesis.md`: measured hot frames,
  deterministic wrapper, and parity gates only.

#### Promoted roadmap hooks

- v0.1.8.6: feature cache-key dedup for feature-definition fingerprint and
  feature-engine version.
- v0.1.8.6: schema-only `ctx$feature_table` default plus non-fast-path rebuild
  fix.
- v0.1.8.6: post-5.0/post-5.1 remeasurement and instrument x feature sweep.
- v0.1.8.6, if storage/schema work is explicitly accepted: typed persistent
  `cash_delta` and `position_delta` columns.
- v0.1.9, only if target-risk/portfolio-risk needs it: single-feature
  `ctx$window()` matrix API.
- Later: multi-feature/tensor windows.
- Later: full-panel long export/training APIs and PIT feature-store
  interchange.
- Later: broader typed event metadata beyond replay deltas.

#### Immediate cross-cycle obligations

- The v0.1.8.6 spec packet must cut 5.0 before 5.1 and remeasure after each.
- The v0.1.8.6 spec packet must not publish width-invariance or benchmark
  claims until an instrument x feature sweep runs in read/score and turnover
  modes.
- The v0.1.8.6 spec packet must decide whether storage/schema work is in scope
  before cutting any 5.6 typed persistent column ticket.
- If 5.6 is deferred, the packet should record it as designed future storage
  work, not as an incomplete SQL-only patch.

This entry does not authorize any of the above by itself; it records the
post-synthesis direction and deferrals. Concrete work remains governed by the
accepted synthesis and the relevant spec packets.
```

---

## 9. Cycle Stage Note

Stages run: research input (external QuantConnect benchmark plus local spike),
seed v1, response, response review, seed v2, and synthesis. Maintainer
decisions were skipped because no product-level binary choice was escalated.
Final review is pending. The horizon entry is drafted in this synthesis and
should be applied only after final review accepts the artifact.
