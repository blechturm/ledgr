# ledgr v0.1.8.6 Tickets

Version: v0.1.8.6
Date: 2026-05-28
Total Tickets: 13

## Ticket Organization

This packet implements the scoped v0.1.8.6 plan from `v0_1_8_6_spec.md`:
feature-projection materialization, a structured benchmark suite with a small
LEAN-comparable subset, post-fix width measurement, storage/provenance decision
gates, performance attribution, and the v0.1.8.7 optimization handoff. The
snapshot/provenance and research-loop helper gate is explicitly deferred.

The release spine is:

```text
packet alignment
  -> feature cache-key dedup
  -> schema-only feature_table default
  -> structured benchmark suite
  -> two-mode width sweep and storage decision
  -> conditional storage/schema gate
  -> fast wide-view data.frame manifestation
  -> cold setup/residual profiling diagnostic
  -> drop intermediate wide-matrix allocation if profiling confirms value
  -> performance attribution closeout
  -> matched local peer benchmark
  -> snapshot/provenance and helper RFC gate deferred
  -> release gate
```

v0.1.8.6 is not an auditr-fix release. The next auditr report is deferred until
the auditr repository prompt fixes land. It is also not a public performance
dashboard, target-risk, parallel-dispatch, walk-forward, cost/liquidity, OMS,
or broad-collapse release.

## Dependency DAG

```text
LDG-2445 Packet Alignment And v0.1.8.6 Planning State
  `-- LDG-2446 Feature Cache-Key Deduplication
        `-- LDG-2447 Schema-Only Feature Table Default
              |-- LDG-2448 Structured Benchmark Suite And LEAN Reference
              |     `-- LDG-2449 Two-Mode Width Sweep And Storage Decision
              |           `-- LDG-2450 Conditional Storage And Typed Event Column Gate
              `-- LDG-2451 Snapshot Administration And Research-Loop Helper RFC Gate

LDG-2452 v0.1.8.6 Release Gate And Closeout
  depends on LDG-2446 through LDG-2451 and LDG-2453 through LDG-2457.

LDG-2453 Fast Wide-View DataFrame Manifestation
  depends on LDG-2449 and is a late materialization follow-up before closeout.

LDG-2454 Cold Setup And Residual Phase Profiling
  depends on LDG-2453 and is a diagnostic-only ticket before closeout.

LDG-2455 Drop Intermediate Wide-Matrix Allocation
  depends on LDG-2454 and runs immediately after the profiling diagnostic.

LDG-2456 Performance Attribution Closeout
  depends on LDG-2455 and is a measurement/docs-only closeout gate.

LDG-2457 Matched Local Peer Benchmark
  depends on LDG-2456 and is the final performance-comparison ticket before
  release closeout.

LDG-2450 is a decision gate: typed persistent event columns are implemented
only if storage/schema work is explicitly accepted after LDG-2449. LDG-2451 is
deferred by maintainer decision: snapshot administration and research-loop
helpers are parked in `inst/design/horizon.md` for a later RFC/spec cycle.
```

## Priority Levels

- P0: Scope gate, packet synchronization, release gate, or parity-preserving
  runtime change.
- P1: Primary v0.1.8.6 materialization, benchmark, and measurement work.
- P2: Conditional decision work or gated follow-up planning.

---

## LDG-2445: Packet Alignment And v0.1.8.6 Planning State

Priority: P0
Effort: S
Dependencies: none
Status: Completed

### Description

Finalize the v0.1.8.6 planning packet and make the active-version state
unambiguous across the design index, roadmap, AGENTS notes, spec, ticket file,
and machine-readable ticket metadata.

### Tasks

- Keep `v0_1_8_6_spec.md`, `v0_1_8_6_tickets.md`, and `tickets.yml`
  synchronized.
- Confirm `inst/design/README.md`, `inst/design/ledgr_roadmap.md`, and
  `AGENTS.md` all point to the v0.1.8.6 packet as active.
- Confirm auditr-report bugfix intake is deferred to the next version.
- Confirm v0.1.8.6 scope starts with 5.0 then 5.1, followed by remeasurement
  and benchmarks before storage decisions.
- Confirm no implementation scope is granted to target risk, parallel dispatch,
  walk-forward, cost/liquidity, OMS, broad collapse adoption, or public
  benchmark dashboards.

### Acceptance Criteria

- Spec, ticket markdown, and `tickets.yml` agree on ticket IDs, dependencies,
  statuses, and scope.
- README, roadmap, and AGENTS active-packet language agrees with the spec.
- Auditr-report bugfix intake is explicitly deferred in the spec and planning
  docs.
- No deferred milestone is accidentally promoted by the active packet text.

### Verification

Manual packet review and `rg` checks for stale active-packet/auditr language.

### Source Reference

- `v0_1_8_6_spec.md`
- `inst/design/README.md`
- `inst/design/ledgr_roadmap.md`
- `AGENTS.md`

### Classification

```yaml
type: governance
surface: design_packet
scope: v0.1.8.6
```

---

## LDG-2446: Feature Cache-Key Deduplication

Priority: P0
Effort: M
Dependencies: LDG-2445
Status: Completed

### Description

Deduplicate feature cache-key construction by hoisting repeated feature
definition fingerprint and feature-engine-version work out of the
per-(instrument, feature) precompute loop. This is Direction 5.0 from the
accepted feature-projection synthesis.

### Tasks

- Locate the per-(instrument, feature) `ledgr_feature_cache_key()` call in the
  feature precompute path.
- Compute each resolved concrete feature definition fingerprint once per
  precompute/execution scope.
- Compute `ledgr_feature_engine_version()` once per precompute/execution scope.
- Reuse the hoisted values when building per-instrument cache keys.
- Keep `ledgr_feature_cache_key()` as the canonical parity reference.
- Add parity fixtures for scalar, multi-output, parameterized, and
  explicit-fingerprint feature definitions.
- Remeasure the current-source feature-payload spike after the change.

### Acceptance Criteria

- Cache keys are byte-identical before and after dedup across representative
  feature definitions.
- Existing fingerprint-stability pins remain green.
- The feature cache schema, feature identity, persisted artifacts, and public
  APIs do not change.
- The post-change measurement records the effect on `t_pre`.

### Verification

Targeted feature-cache/fingerprint tests, relevant feature precompute tests,
and current-source spike remeasurement via `pkgload::load_all(".")` or an
equivalent source guard.

Completion note:

- Targeted tests passed:
  `test-feature-cache.R`, `test-precompute-features.R`, and
  `test-fingerprint-stability.R`.
- The run path hoists the per-feature fingerprint and feature-engine version
  used by session-cache keys; the sweep-precompute path also hoists the
  feature-engine version reused by the projection and precomputed payload
  metadata.
- Current-source spike remeasurement, 100 instruments x 126 pulses x 20
  features, `iters = 1`: `t_pre = 2.02s`, `warm_t_pre = 2.64s`,
  `t_loop = 0.49s`, `t_wall = 7.87s`. The accepted RFC baseline for the same
  shape recorded `t_pre ~ 6.27s`.

### Source Reference

- `v0_1_8_6_spec.md` Section 3
- `rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md`
- `R/backtest-runner.R`
- `R/feature-cache.R`

### Classification

```yaml
type: optimization
surface: feature_precompute
scope: cache_key_dedup
```

---

## LDG-2447: Schema-Only Feature Table Default

Priority: P0
Effort: L
Dependencies: LDG-2446
Status: Completed

### Description

Stop eager full-panel long `feature_table` materialization by default while
preserving a schema-only `ctx$feature_table` field, explicit internal full-long
opt-in, single-pulse inspection support, and event-stream parity. This is
Direction 5.1 from the accepted feature-projection synthesis.

### Tasks

- Add an internal construction-time view policy for feature pulse views.
- Make the default runtime path build `features_wide` plus a zero-row,
  schema-preserving `feature_table`.
- Add explicit internal opt-in for full-panel long `feature_table` where tests,
  debugging, or compatibility paths truly require it.
- Update feature inspection to build only the current pulse's long shape on
  demand.
- Fix the non-fast pulse-context helper path so it does not rebuild long rows
  when the default schema-only feature table is present.
- Update tests that truly require long rows to opt in or move to
  `features_wide`.
- Remeasure the current-source feature-payload spike after the change.

### Acceptance Criteria

- Schema-only-default and full-long-enabled runs produce identical event
  streams on reference workloads.
- LDG-2403 accounting parity remains green for schema-only and full-long paths.
- `ctx$feature_table` remains a plain data.frame field, not an active binding
  or function-valued replacement.
- `features_wide`, `feature()`, and `features()` behavior is unchanged.
- The non-fast context path does not rebuild full long rows by default.
- No public `feature_table` deprecation warning ships in this release.
- The post-change measurement records the effect on `gap_viewbuild` or
  equivalent view-build timing.

### Verification

Targeted runtime-projection and pulse-context tests, event-stream parity tests,
LDG-2403 accounting parity tests, feature-inspection tests, and current-source
spike remeasurement.

Completion note:

- Targeted tests passed:
  `test-pulse-context-accessors.R`, `test-feature-inspection.R`,
  `test-sweep.R`, `test-sweep-parity.R`, `test-backtest-wrapper.R`, and
  `test-indicator-tools.R`.
- Default `ledgr_projection_pulse_views()` now emits schema-only
  `feature_table` rows; full-long remains available through the explicit
  internal `feature_table = "full"` opt-in.
- Non-fast and fast runtime contexts keep `ctx$feature_table` as a plain
  zero-row data.frame by default while `ctx$feature()`, `ctx$features()`,
  `ctx$features_wide`, `ledgr_pulse_features()`, and `ledgr_pulse_wide()`
  continue to read current-pulse feature values.
- `test-pulse-context-accessors.R` includes a direct non-fast attach-path
  regression fixture: a projection plus schema-only `feature_table` leaves
  `ctx$feature_table` at zero rows, while scalar/wide accessors and
  single-pulse inspection still recover feature values on demand.
- Current-source spike remeasurement, 100 instruments x 504 pulses x 20
  features, `iters = 1`: `t_pre = 2.48s`, `gap_viewbuild = 9.50s`,
  `t_loop = 4.11s`, `t_wall = 16.09s`, `peak_mb = 371.6`. The broad
  `gap_viewbuild` metric includes post-run/wrapper work and was noisy at this
  size.
- Equivalent isolated view-build timing on the same 100 x 504 x 20 projection:
  schema-only `ledgr_projection_pulse_views()` = 0.26s, full-long opt-in =
  0.47s; first-pulse long rows = 0 vs 2000.

### Source Reference

- `v0_1_8_6_spec.md` Section 4
- `rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md`
- `R/runtime-projection.R`
- `R/fold-core.R`
- `R/pulse-context.R`
- `R/feature-inspection.R`

### Classification

```yaml
type: optimization
surface: runtime_projection
scope: feature_table_materialization
```

---

## LDG-2448: Structured Benchmark Suite And LEAN Reference

Priority: P1
Effort: L
Dependencies: LDG-2447
Status: Completed

### Description

Turn the ad hoc feature-payload spike into a small, repeatable benchmark suite
with stable named scenarios, current-source guards, warmup/repeat behavior,
machine-readable outputs, phase-level metrics, and a small LEAN-comparable
subset.

### Tasks

- Add a local benchmark runner under `dev/bench/` or another design-approved
  development location.
- Implement stable named scenarios:
  `baseline_single_run`, `pulse_loop_empty`, `wide_panel_no_features`,
  `feature_read_score`, `feature_turnover`, `indicator_payload`,
  `sweep_memory_summary`, and `persistent_replay`.
- Use synthetic or package-owned data only.
- Add a current-source guard so the benchmark cannot silently measure an
  installed stale package.
- Add warmup/repeat behavior; skip or clearly mark the first run.
- Emit machine-readable results with scenario parameters and environment
  metadata.
- Emit phase metrics, not only a DPS headline.
- Maintain `dev/bench/fetch_lean_reference.R`, `dev/bench/lean_reference.csv`,
  and the provenance sidecar used for the LEAN baseline.
- Report `security_bars_sec` and `feature_cells_sec` separately where
  applicable.

### Acceptance Criteria

- The benchmark suite runs from current source.
- Results are machine-readable and include scenario parameters, environment
  metadata, git SHA when available, branch, R version, platform, and timestamp.
- The QC/LEAN-comparable subset reports `security_bars_sec`, wall-clock time,
  dimensions, and explicit comparability notes.
- `feature_read_score` is measured but not treated as LEAN-comparable.
- The LEAN baseline includes retrieval provenance, including source URL,
  retrieval timestamp, and page hash.
- Benchmark documentation does not claim LEAN equivalence or speed ranking.

### Verification

Run the benchmark suite in a small/smoke configuration, inspect generated
machine-readable outputs, and manually review comparability notes.

Completion note:

- Added `dev/bench/run_benchmarks.R`, a current-source-guarded local benchmark
  runner with explicit warmup/repeat behavior and stable named scenarios:
  `baseline_single_run`, `pulse_loop_empty`, `wide_panel_no_features`,
  `feature_read_score`, `feature_turnover`, `indicator_payload`,
  `sweep_memory_summary`, and `persistent_replay`.
- Added `dev/bench/README.md` and `dev/bench/results/.gitignore`. Generated
  benchmark outputs are local artifacts and are not committed by default.
- The runner emits raw per-iteration CSV, scenario summary CSV, environment
  metadata JSON, combined JSON result payload, compact Markdown summary, and a
  LEAN side-by-side CSV when `dev/bench/lean_reference.csv` is present.
- Output separates `security_bars_sec` from `feature_cells_sec`, records
  scenario dimensions and environment metadata, labels wall-minus-pre-minus-loop
  timing as the broad `t_residual_sec` rather than isolated view-build time,
  and keeps `feature_read_score` as a ledgr-only scenario outside the
  LEAN-comparable subset.
- Smoke verification passed:
  `Rscript dev/bench/run_benchmarks.R --preset smoke --repeats 1 --warmup 1`.
  The smoke run produced machine-readable outputs under `dev/bench/results/`
  and an eight-row LEAN side-by-side file for the comparable/partial scenarios.

### Source Reference

- `v0_1_8_6_spec.md` Section 6
- `dev/spikes/spike-feature-payload-dps.R`
- `dev/spikes/profile-loop.R`
- `dev/bench/fetch_lean_reference.R`
- `dev/bench/lean_reference.csv`

### Classification

```yaml
type: benchmark
surface: dev_bench
scope: structured_suite
```

---

## LDG-2449: Two-Mode Width Sweep And Storage Decision

Priority: P1
Effort: M
Dependencies: LDG-2448
Status: Completed

### Description

Run the post-5.0/post-5.1 instrument x feature width sweep in two modes and
record the storage/projection decision before any width-invariance or storage
need claim.

### Tasks

- Add width-sweep coverage to the structured benchmark suite.
- Implement read/score mode: strategies read and score features but produce no
  fills.
- Implement turnover mode: strategies generate representative fills/events and
  exercise reconstruction paths.
- Record `security_bars_sec`, `feature_cells_sec`, phase timings, events/sec,
  memory where measurable, and warning/failure counts.
- Compare post-fix results against the pre-fix/current-source baseline.
- Decide whether DuckDB-backed feature storage should be implemented, deferred,
  or rejected for now.
- Record the decision in the spec packet, benchmark output, or a design note
  referenced from the packet.

### Acceptance Criteria

- Both read/score and turnover modes run successfully.
- The output separates feature-access scaling from fill/event/replay scaling.
- No width-invariance claim is made before this sweep is recorded.
- The DuckDB storage decision is explicitly recorded with evidence.
- If storage work is not accepted, Direction 5.6 remains designed future work
  rather than being implemented through the back door.

### Verification

Run the two-mode width sweep at the agreed small and stress dimensions, inspect
machine-readable results, and manually review the storage decision note.

Completion note:

- Added `dev/bench/run_width_sweep.R`, a two-mode width-sweep runner that
  reuses the structured benchmark source guard and output conventions.
- Modes are explicit:
  - `read_score`: feature access and scoring with no fills;
  - `turnover`: feature access/scoring plus representative fills and persistent
    replay/read-back timing.
- Smoke verification passed:
  `Rscript dev/bench/run_width_sweep.R --preset smoke --repeats 1 --warmup 1`.
- Record-dimension verification passed:
  `Rscript dev/bench/run_width_sweep.R --preset record --repeats 1 --warmup 1`.
  Outputs were written to:
  `dev/bench/results/ledgr_width_sweep_record_20260528T215404Z_*`.
- Largest recorded grid was 500 instruments x 252 pulses x 50 features:
  - read/score: `t_wall = 75.13s`, `t_pre = 38.79s`,
    `t_residual = 33.83s`, `t_loop = 2.51s`,
    `security_bars_sec = 1677`, `feature_cells_sec = 83855`;
  - turnover: `t_wall = 65.86s`, `t_pre = 29.79s`,
    `t_residual = 32.80s`, `t_loop = 3.27s`,
    `replay = 0.98s`, `security_bars_sec = 1913`,
    `feature_cells_sec = 95657`.
- Isolated schema-vs-full-long view timing at the same largest grid:
  schema-only `ledgr_projection_pulse_views()` = `0.33s`; full-long opt-in =
  `2.44s`; full-long rows = `6,300,000`.
- The output separates feature-access scaling from fill/event/replay scaling.
  No width-invariance claim is made; the recorded loop cost grows with width
  but remains much smaller than setup/residual wall time at these dimensions.
- The generated storage decision file records DuckDB-backed feature storage as
  deferred for v0.1.8.6.
- Post-review runner tightenings normalize decision values to `deferred`, add
  the full-long row count and schema-vs-full timing ratio to the generated
  rationale, use median isolated view timings for record runs, and keep
  generated run IDs readable beyond two-digit iteration numbers.
- A same-snapshot cold/hot probe at 100 instruments x 252 pulses x 50 features
  confirmed that fresh width-sweep grid cells pay cold setup: cache misses
  dropped from `5000` to `0` on the warm run, but `t_pre` only moved from
  `5.28s` to `4.36s`, so feature-cache hits reduce but do not explain the
  remaining setup cost.

### Source Reference

- `v0_1_8_6_spec.md` Sections 5 and 6
- `rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md`
- benchmark outputs from LDG-2448
- `dev/bench/run_width_sweep.R`

### Classification

```yaml
type: benchmark
surface: feature_projection
scope: width_sweep_storage_decision
```

---

## LDG-2450: Conditional Storage And Typed Event Column Gate

Priority: P2
Effort: M
Dependencies: LDG-2449
Status: Completed

### Description

Use the LDG-2449 evidence to decide whether v0.1.8.6 accepts any storage/schema
work. Typed persistent event columns are implemented only if storage/schema
work is explicitly accepted; otherwise Direction 5.6 remains a designed
follow-up.

### Tasks

- Review LDG-2449 storage/projection decision evidence.
- Decide whether typed persistent event columns are in v0.1.8.6 scope.
- If accepted, cut or expand implementation tickets with nullable typed column
  migration, old/new/mixed replay parity, and immediate read-back parity.
- If not accepted, record the deferral and do not ship DuckDB SQL
  `json_extract` as a partial replay patch unless a separate release-blocking
  defect requires it.
- Keep LDG-2410 memory-event work distinct from this persistent-store decision.

### Acceptance Criteria

- The packet records an explicit accept/defer/reject decision for storage/schema
  work.
- If typed persistent event columns are accepted, follow-up implementation
  tickets name migration and replay parity gates.
- If deferred, no persistent event schema change ships in v0.1.8.6.
- The release notes accurately reflect the final decision.

### Verification

Manual decision-record review and, if implementation is accepted, targeted
persistent replay/migration tests named by the follow-up tickets.

Completion note:

- Storage/schema implementation is deferred for v0.1.8.6 based on the
  LDG-2449 width-sweep decision record.
- No DuckDB-backed feature projection, persistent event schema migration,
  typed persistent event columns, or DuckDB SQL `json_extract` replay patch
  ships in this batch.
- Direction 5.6 remains accepted design follow-up, distinct from the completed
  LDG-2410 typed in-memory event representation.
- The record sweep reported no warnings or failures and persistent replay at
  the largest turnover grid was `0.98s`; this does not justify pulling a
  storage/schema migration into the current release.

### Source Reference

- `v0_1_8_6_spec.md` Section 5
- `rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md`
- `R/db-schema-create.R`
- `R/ledger-writer.R`
- `R/derived-state.R`
- `R/backtest-runner.R`
- `dev/bench/results/ledgr_width_sweep_record_20260528T215404Z_storage_decision.csv`

### Classification

```yaml
type: decision_gate
surface: persistent_events
scope: typed_columns
```

---

## LDG-2451: Snapshot Administration And Research-Loop Helper RFC Gate

Priority: P2
Effort: M
Dependencies: LDG-2447
Status: Deferred

### Description

Route snapshot administration, ETL provenance, sweep-review helper, and
promotion-recovery-summary helper work through the required RFC/spec gate.
These helpers must not block the mandatory 5.0/5.1 materialization work.

### Tasks

- Start or update the RFC cycle for snapshot administration and ETL provenance
  metadata.
- Include research-loop helper surfaces in the same decision path where they
  depend on snapshot/run metadata.
- Preserve the separation between engine-computed metadata, user-supplied
  descriptive metadata, and lifecycle state.
- Preserve `snapshot_hash` independence from mutable user metadata.
- Decide whether implementation tickets land in v0.1.8.6 or defer to a later
  packet.
- If accepted, cut follow-up tickets for the exact APIs, schema changes,
  migrations, docs, and tests.

### Acceptance Criteria

- The packet contains or references an accepted RFC/spec decision before any
  implementation ticket is opened for this workstream.
- If deferred, the release can still close after the materialization and
  benchmark work.
- Any accepted helper design exposes ranking/recovery limits rather than hiding
  them.
- No automatic winner-picking, statistical validation, walk-forward, or
  production deployment approval helper is introduced.

### Verification

RFC-cycle review and manual packet review. Implementation tests are named only
after this gate accepts concrete implementation scope.

### Source Reference

- `v0_1_8_6_spec.md` Section 7
- `inst/design/horizon.md` snapshot administration and research-loop entries
- `rfc_research_workflow_artifact_topology_v0_1_8_x_synthesis.md`

### Classification

```yaml
type: design_gate
surface: snapshot_provenance
scope: rfc_routing
```

### Deferral Note

Deferred by maintainer decision on 2026-05-29. Snapshot administration, ETL
provenance metadata, sweep-review helpers, and promotion-recovery-summary
helpers are useful but not needed to close the v0.1.8.6 materialization,
benchmark, and attribution cycle. The work is parked in `inst/design/horizon.md`
for a later RFC/spec cycle, likely v0.2.0 where it can align with broader
snapshot lineage, point-in-time data, and research-workflow surfaces.

---

## LDG-2453: Fast Wide-View DataFrame Manifestation

Priority: P1
Effort: S
Dependencies: LDG-2449
Status: Completed

### Description

Replace the remaining eager wide-view `as.data.frame()` / `cbind()` /
full-panel `split.data.frame()` path with internal primitive list stamping.
This keeps the current `ctx$features_wide` data.frame contract intact while
manifesting those data.frames more cheaply from already-materialized projection
matrices. This is the narrow, parity-preserving materialization optimization
found during LDG-2449 review; it is not the broader primitive-only fold-core
contract redesign.

### Tasks

- Add an internal helper that stamps a named equal-length column list into a
  data.frame with compact row names.
- Use it for single-pulse projection `features_wide` construction.
- Use it for default pulse-view `features_wide` construction, avoiding the
  all-pulse data.frame plus `split.data.frame()` path.
- Preserve column names, row order, column values, and plain data.frame output.
- Keep the broader primitive-only fold-core / matrix-canonical strategy surface
  as follow-up design work.
- Remeasure isolated schema/full-long view construction at the largest
  LDG-2449 grid.

### Acceptance Criteria

- Existing `ctx$features_wide` behavior remains a plain data.frame.
- Existing feature accessor, inspection, sweep, and event-stream parity tests
  remain green.
- The schema-only/full-long event streams remain identical.
- The optimization introduces no collapse dependency and no public API change.
- Isolated view-build timing improves or is at least no worse at the largest
  LDG-2449 grid.

### Verification

Targeted pulse-context, feature-inspection, sweep, sweep-parity, and
backtest-wrapper tests plus isolated view-build remeasurement.

Completion note:

- Added internal `ledgr_fast_data_frame()` list-stamping helper in
  `R/runtime-projection.R`.
- `ledgr_projection_features_wide()` now stamps the per-pulse wide data.frame
  from primitive columns instead of using `as.data.frame()` / `cbind()`.
- `ledgr_projection_pulse_views()` now builds each per-pulse `features_wide`
  frame directly from the projection matrix and stamps it, avoiding the
  all-pulse wide data.frame plus `split.data.frame()` path.
- Targeted tests passed:
  `test-pulse-context-accessors.R`, `test-sweep.R`,
  `test-sweep-parity.R`, `test-feature-inspection.R`, and
  `test-backtest-wrapper.R`.
- Isolated largest-grid view timing, 500 instruments x 252 pulses x 50
  features, `repeats = 3`: schema-only `ledgr_projection_pulse_views()` =
  `0.19s`; full-long opt-in = `1.15s`; full-long rows = `6,300,000`.
  The previous LDG-2449 record for the same grid was `0.33s` schema-only and
  `2.44s` full-long.
- Width-sweep smoke verification also passed after the optimization:
  `Rscript dev/bench/run_width_sweep.R --preset smoke --repeats 1 --warmup 1`.

### Source Reference

- `v0_1_8_6_spec.md` Sections 4-6
- `rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md`
- `R/runtime-projection.R`
- `dev/bench/run_width_sweep.R`

### Classification

```yaml
type: optimization
surface: runtime_projection
scope: wide_view_manifestation
```

---

## LDG-2454: Cold Setup And Residual Phase Profiling

Priority: P1
Effort: S
Dependencies: LDG-2453
Status: Completed

### Description

Add a diagnostic-only profiling pass for the remaining cold setup and broad
residual costs after the materialization fixes. This ticket exists to explain
where `t_pre` and `t_residual_sec` are spent before the next optimization
decision. It must not ship a behavior change, public API change, schema change,
or new optimization.

### Tasks

- Profile a representative cold benchmark shape after LDG-2453 is reviewed.
- Attribute the dominant `t_pre` cost to named code paths, such as cache-key
  construction/lookup, feature compute/cache behavior, projection
  materialization, or other measured setup work.
- Attribute the broad residual cost to named code paths, at least separating
  feature view materialization from post-fold finalization/read-back when the
  current hooks make that possible.
- Record the profiling method, representative dimensions, cold/warm cache
  state, and headline attribution in the packet.
- Keep raw generated profiler outputs out of git unless they are intentionally
  reduced into a tracked summary.
- Do not optimize any hotspot as part of this ticket.

### Acceptance Criteria

- The profiling run uses current source, not an installed stale package.
- The ticket records whether the remaining dominant cost is `t_pre`,
  residual, or both, with named code paths and caveats.
- Any telemetry/timing hook added for diagnosis is read-only, internal, and
  does not affect fold results, snapshots, event streams, or public strategy
  surfaces.
- Event-stream parity and targeted materialization tests remain green if any
  read-only timing hook is added.
- No storage/schema, primitive-only fold-core, active-binding, or collapse
  dependency work ships under this ticket.

### Verification

Current-source profiler or read-only phase-timer run, targeted tests if code
hooks are added, and manual review of the recorded attribution.

Completion note:

- Ran current-source profiling via `pkgload::load_all()` guard from
  `dev/bench/run_width_sweep.R` / `dev/bench/run_benchmarks.R`.
- Representative shape: 100 instruments x 252 pulses x 50 features
  (`1,260,000` feature cells), read/score strategy, synthetic package-owned
  bars, same sealed snapshot for cold/warm comparisons.
- No code hook was added; no behavior, API, snapshot, ledger, or schema change
  shipped under this ticket.
- Cold profiled run with `persist_features = TRUE`: wall `20.80s` under
  `Rprof`, `t_pre = 5.83s`, broad residual `14.17s`, `t_loop = 0.80s`,
  feature cache `0` hits / `5,000` misses.
- Unprofiled timing matrix:

  ```text
  mode                   wall    t_pre  residual  t_loop  hits  misses
  persist_features cold  15.47s  5.55s     9.14s   0.78s     0    5000
  persist_features warm  14.21s  4.62s     9.15s   0.44s  5000       0
  no-persist cold         8.32s  5.50s     2.36s   0.46s     0    5000
  no-persist warm         7.53s  4.62s     2.41s   0.50s  5000       0
  ```

- Cold-to-warm cache reuse removes only about `0.9s` of `t_pre` at this shape.
  The feature cache avoids feature computation, but the remaining `t_pre`
  is dominated by cache-key construction/lookup and projection setup rather
  than feature series computation.
- The broad residual is dominated by work outside the fold loop:
  `persist_features = TRUE` adds about `6.8s` residual at this shape, primarily
  the post-fold `features` table write path in `R/backtest-runner.R`
  (`DBI::dbWithTransaction()` / `dbAppendTable()` around the per-instrument
  feature persistence loop). Pre-run config/provenance/strategy-preflight work
  is also visible in the profile, especially priority-package and symbol-tier
  checks in `R/strategy-preflight.R`.
- Isolated feature-view construction is no longer the dominant residual after
  LDG-2453: at this shape, schema-only `ledgr_projection_pulse_views()` median
  was `0.12s` and full-long opt-in was `0.36s`. The LDG-2453 largest-grid
  measurement remains `0.19s` schema-only and `1.15s` full-long at
  500 instruments x 252 pulses x 50 features.
- Attribution conclusion: after LDG-2453, the next large measured overheads are
  persistent feature writes and pre-run strategy/config preflight, not the
  fold loop and not default feature-view construction. LDG-2455 remains
  scheduled as the immediate narrow matrix-allocation follow-up, but this
  diagnostic shows it is an incremental materialization cleanup rather than the
  dominant remaining bottleneck.

### Source Reference

- `v0_1_8_6_spec.md` Sections 6 and 10
- `dev/bench/README.md`
- `dev/bench/run_benchmarks.R`
- `dev/bench/run_width_sweep.R`
- `R/backtest-runner.R`
- `R/fold-core.R`
- `R/runtime-projection.R`

### Classification

```yaml
type: diagnostic
surface: benchmark_telemetry
scope: cold_setup_residual_profile
```

---

## LDG-2455: Drop Intermediate Wide-Matrix Allocation

Priority: P1
Effort: S
Dependencies: LDG-2454
Status: Completed

### Description

LDG-2454 showed that feature-view construction is no longer the dominant
remaining residual, but the remaining all-pulse `feature_wide_values` matrix is
still an avoidable allocation in the default pulse-view path. Remove it if the
direct-slice implementation stays cheap and parity-preserving. The optimized
path should slice the canonical projection matrices directly per pulse and
stamp the same `ctx$features_wide` data.frames as today.

This is still the narrow, contract-preserving materialization lane. It is not
the v0.1.8.7 primitive-only fold-core contract redesign.

### Tasks

- Use the LDG-2454 profiling output to keep this as a narrow cleanup rather
  than a claimed dominant-bottleneck fix.
- Replace the all-pulse wide matrix allocation in default pulse-view
  construction with direct per-pulse slices from `projection$feature_values`.
- Preserve `ctx$features_wide` as a plain data.frame with identical columns,
  values, row order, and row names.
- Keep the full-long `feature_table = "full"` opt-in behavior intact.
- Do not introduce matrix-canonical strategy surfaces, active bindings, or a
  primitive-only fold-core redesign in this ticket.
- Remeasure isolated schema/full-long view construction at the largest
  LDG-2449 grid.

### Acceptance Criteria

- Existing `ctx$features_wide` fixtures remain value-identical.
- Schema-only/full-long event streams remain identical.
- Feature inspection, sweep, and pulse-context tests remain green.
- The optimization reduces or does not worsen isolated default pulse-view
  construction at the largest LDG-2449 grid.
- No public API, snapshot, ledger, storage schema, or collapse dependency
  change ships under this ticket.

### Verification

Targeted pulse-context, feature-inspection, sweep, sweep-parity, and
backtest-wrapper tests plus isolated view-build remeasurement.

Completion note:

- Removed the default-path all-pulse `feature_wide_values` matrix allocation
  from `ledgr_projection_pulse_views()`. The wide-view builder now slices the
  canonical `projection$feature_values` matrices directly per pulse and stamps
  the same plain `ctx$features_wide` data.frames.
- Added a shared internal column-list helper for single-pulse and pulse-view
  wide construction, with pre-resolved feature matrices in the all-pulse path
  to avoid repeated named lookups.
- Added a multi-feature pulse-view fixture proving prebuilt
  `features_wide[[pulse_idx]]` matches `ledgr_projection_features_wide()` for
  each pulse.
- No matrix-canonical strategy surface, active binding, public API change,
  storage/schema change, or collapse dependency shipped under this ticket.
- Targeted verification passed:
  `test-pulse-context-accessors.R`, `test-feature-inspection.R`,
  `test-sweep-parity.R`, `test-sweep.R`, and `test-backtest-wrapper.R`.
- Isolated largest-grid view timing after the change, current source,
  500 instruments x 252 pulses x 50 features, `repeats = 5`: schema-only
  `ledgr_projection_pulse_views()` = `0.19s`; full-long opt-in = `1.14s`;
  full-long rows = `6,300,000`. The LDG-2453 reference was `0.19s`
  schema-only and `1.15s` full-long at the same grid.

### Source Reference

- `v0_1_8_6_spec.md` Sections 4-6
- `R/runtime-projection.R`
- `dev/bench/run_width_sweep.R`

### Classification

```yaml
type: optimization
surface: runtime_projection
scope: wide_view_matrix_allocation
```

---

## LDG-2456: Performance Attribution Closeout

Priority: P1
Effort: S
Dependencies: LDG-2455
Status: Completed

### Description

Produce the final v0.1.8.6 diagnostic attribution of remaining wall-clock
runtime gaps after the accepted materialization fixes. This ticket names and
owns the remaining large buckets; it does not optimize them and does not add
new phase hooks to the run path.

The method is differential measurement plus profiling:

- use clean toggles where they exist, especially `persist_features = TRUE/FALSE`
  and cold versus warm feature-cache state;
- use with-features versus no-features shapes where useful to separate feature
  setup/projection pressure from bare fold scaffolding;
- use the existing isolated schema/full-long view timing for view-build cost;
- use `Rprof` function attribution for `t_pre` internals that do not have a
  clean toggle, reporting percentages against the profiled run and
  cross-checking against unprofiled toggle walls.

`Rprof` may inflate absolute runtime, so this ticket must not present Rprof
self-times as direct wall-clock seconds unless they are separately calibrated.
It may use Rprof to name the large functions responsible for a bucket.

### Tasks

- Run the full attribution matrix at `100 instruments x 252 pulses x 50
  features`, including cold/warm and `persist_features = TRUE/FALSE`.
- Run a reduced scale confirmation at the largest representative grid, at
  minimum read/score cold with `persist_features = TRUE/FALSE`.
- Record isolated view-build timing from the current source after LDG-2455.
- Profile the representative cold setup path with `Rprof` and identify the
  dominant function-level `t_pre` contributors.
- Produce a bucket table with columns:
  `shape`, `mode`, `bucket`, `measurement_method`, `evidence`, `wall_share`,
  `owner`, and `next_action`.
- Split expected runtime overhead, such as interpreter, GC, DBI, and profiling
  overhead, from genuinely unexplained-and-nameable time.
- Assign every large named bucket to an owner category:
  `accepted_overhead`, `v0.1.8.7_artifact_policy`,
  `v0.1.8.7_cache_key_lane`, `v0.1.8.7_primitive_contract`, or
  `release_blocker_if_unexplained`.
- Record machine/environment metadata or point to benchmark outputs that do.

### Acceptance Criteria

- For both the small diagnostic shape and the reduced large-shape confirmation,
  every bucket above `10%` of wall time or above `1s` is named to a code path,
  measured toggle, or expected overhead class.
- The genuinely unexplained-and-nameable remainder is below `10%` of wall time
  or below `1s`, or the ticket explicitly marks it as a release-blocking
  unresolved performance attribution gap.
- Persistent feature-write tax, feature-compute cache benefit, default
  feature-view construction, and remaining `t_pre` setup cost are each
  represented as separate rows.
- The owner column routes each large bucket to an accepted overhead class or a
  concrete future lane; no row says only "slow" or "unknown" without a next
  action.
- No runtime behavior, public API, schema, snapshot, event stream, or strategy
  surface changes ship under this ticket.

### Verification

Manual benchmark/profiling review, current-source guard confirmation, and
ticket-note review. Targeted tests are required only if supporting scripts are
changed.

Completion note:

- Ran current-source attribution from the v0.1.8.6 branch after LDG-2455.
  The measurement script was temporary and wrote ignored local artifacts under
  `dev/bench/results/`:
  `ldg2456_attribution_matrix_20260529T090917Z.csv`,
  `ldg2456_isolated_views_20260529T090917Z.csv`, and
  `ldg2456_rprof_by_total_20260529T090917Z.csv`.
- No runtime behavior, public API, schema, snapshot, event-stream, strategy
  surface, phase-telemetry hook, or optimization change shipped under this
  ticket.
- Small diagnostic shape, `100 instruments x 252 pulses x 50 features`,
  read/score mode:

  ```text
  persist cache  wall   t_pre  residual  t_loop
  TRUE    cold   15.44   5.86      8.90    0.68
  TRUE    warm   13.80   4.59      8.65    0.56
  FALSE   cold    7.50   4.91      2.18    0.41
  FALSE   warm    6.93   4.29      2.23    0.41
  ```

- No-feature baseline at `100 instruments x 252 pulses x 0 features`,
  `persist_features = FALSE`: wall `2.41s`, `t_pre = 0.09s`, residual
  `2.04s`, `t_loop = 0.28s`.
- Reduced large-shape confirmation, `500 instruments x 252 pulses x 50
  features`, cold read/score mode:

  ```text
  persist  wall   t_pre  residual  t_loop  bars/sec  feature-cells/sec
  TRUE     58.30  25.64     30.27    2.39      2161            108062
  FALSE    36.27  26.94      7.03    2.30      3474            173697
  ```

- Isolated default view construction is no longer a large bucket after
  LDG-2453/LDG-2455:

  ```text
  shape              schema_view  full_long_view  full_long_rows
  100 x 252 x 50          0.13s          0.25s        1,260,000
  500 x 252 x 50          0.19s          1.57s        6,300,000
  ```

- Representative cold Rprof run, `100 x 252 x 50`, `persist_features = TRUE`:
  profiled wall `12.59s`, `t_pre = 5.29s`, residual `6.81s`, `t_loop = 0.49s`.
  Rprof is used only for function-level attribution. The largest relevant
  total-time entries were `DBI::dbWithTransaction` / `dbAppendTable` in the
  persistent feature-write path, and `ledgr_feature_cache_key_from_parts`
  with nested `digest::digest`, `canonical_json`, and
  `ledgr_normalize_ts_utc` in the setup/cache-key path. Rprof also showed
  snapshot construction because the temporary profiler wrapped the full
  measurement helper; that entry is not counted as `ledgr_run()` wall time.
- Bucket ownership:

  | shape | bucket | method | evidence | owner | next action |
  | --- | --- | --- | --- | --- | --- |
  | `100 x 252 x 50` | persistent feature-write residual tax | `persist_features` TRUE/FALSE toggle | residual `8.90s` vs `2.18s`; delta `6.72s` | `v0.1.8.7_artifact_policy` | RFC the fast/sweep ephemeral path vs durable promotion/materialization path |
  | `500 x 252 x 50` | persistent feature-write residual tax | `persist_features` TRUE/FALSE toggle | residual `30.27s` vs `7.03s`; delta `23.24s` | `v0.1.8.7_artifact_policy` | same artifact materialization policy lane |
  | `100 x 252 x 50` | feature compute cache benefit | same-snapshot cold/warm toggle | `persist_features = FALSE` `t_pre` `4.91s` -> `4.29s`; benefit `0.62s` | `accepted_overhead` | cache helps, but it is not the dominant setup cost |
  | `100 x 252 x 50` | remaining feature setup/cache-key/projection cost | no-feature baseline plus Rprof | no-feature `t_pre = 0.09s`; feature `t_pre = 4.91s`; Rprof names `ledgr_feature_cache_key_from_parts` and nested JSON/hash/timestamp normalization; projection materialization rides in this setup bucket | `v0.1.8.7_cache_key_lane` | hoist trusted run-level timestamp normalization and replace session-local JSON+hash lookup keys if accepted; revisit projection materialization under primitive-contract work if it remains visible |
  | `500 x 252 x 50` | remaining feature setup/cache-key/projection cost | large cold confirmation | `t_pre = 26.94s` with `persist_features = FALSE`, `74%` of wall | `v0.1.8.7_cache_key_lane` | same cache-key/setup lane, measured at production-like width |
  | `100 x 252 x 50` | default feature-view construction | isolated view timing | schema-only view `0.13s`, below threshold | `accepted_overhead` | no release blocker; primitive-only fold-core redesign remains separate v0.1.8.7 design work |
  | `500 x 252 x 50` | default feature-view construction | isolated view timing | schema-only view `0.19s`, below threshold | `accepted_overhead` | no release blocker |
  | read/score shapes | fold loop without trading | telemetry | `0.41s` small no-persist, `2.30s` large no-persist | `accepted_overhead` | non-trading loop is not the current wall-clock bottleneck |
  | turnover shape from fold hot-path audit | event-emission loop cost | trade-vs-flat differential plus Rprof | representative 200 instruments x 504 pulses x 2 SMA features: `t_loop` `1.04s` flat -> `13.39s` turnover on 2099 fills; profiler names per-fill emission work (`format.POSIXlt`, payload/event construction, buffer_event accessor work) | `v0.1.8.7_primitive_contract` | use `inst/design/audits/fold_path_hotpath_audit.md` as the RFC input for Lane B event emission; keep buffer-copy claim corrected per peer review |
  | both shapes | baseline runner/interpreter/DBI overhead | no-feature baseline and residual remainder | no-feature residual `2.04s`; remaining no-persist residual `2.18s` small / `7.03s` large after view timing is expected wrapper/DBI/interpreter work | `accepted_overhead` | track in future profiling only if it grows after cache-key/artifact-policy fixes |

- The genuinely unexplained-and-nameable remainder is below the LDG-2456 gate
  after assigning the large buckets above. Remaining time is either named to
  accepted overhead classes or routed to v0.1.8.7 artifact-policy,
  cache-key, or primitive-contract lanes. No release-blocking unresolved
  attribution gap remains.

### Source Reference

- `dev/bench/README.md`
- `dev/bench/run_benchmarks.R`
- `dev/bench/run_width_sweep.R`
- `inst/design/audits/fold_path_hotpath_audit.md`
- `inst/design/architecture/fold_core_trust_boundary.md`

### Classification

```yaml
type: diagnostic
surface: benchmark_telemetry
scope: performance_attribution_closeout
```

---

## LDG-2457: Matched Local Peer Benchmark

Priority: P1
Effort: M
Dependencies: LDG-2456
Status: Completed

### Description

Run a same-machine, matched-workload peer benchmark before v0.1.8.7 design work
starts. "Fair" here means at least locally comparable: ledgr and the peer engine
run on this host, over the same synthetic workload, with an explicit timing
boundary and the same headline units. The scraped Ziplime/Zipline/Backtrader
reference may define the workload shape and orientation, but it remains
`orientation_only` until a local run exists.

The baseline workload is the event-driven SMA crossover shape captured by the
peer reference: 500 assets, five years of daily bars, and a simple SMA crossover
strategy. VectorBT remains excluded from the matched event-driven comparison
because it is a vectorized engine category mismatch.

The local development host is an Intel Core i9-12900K desktop system. That is
plausibly the same broad single-core class as the Apple M3 host used by the
published Ziplime README figures, but not identical hardware. The M3 context
supports order-of-magnitude orientation only; it does not promote scraped rows
from `orientation_only` to `local_matched`.

### Tasks

- Keep scraped vendor/published numbers labeled `orientation_only`; do not feed
  them into local comparable ratios.
- Run the ledgr `peer_sma_crossover` record shape from current source.
- Add or run local peer scripts for the available event-driven Python peers
  (Ziplime/Polars, Zipline or Zipline-reloaded, and Backtrader where
  installable in this workspace).
- Use deterministic synthetic data shared across engines or generated by a
  shared seed and identical OHLC/volume rules.
- Record the timing boundary explicitly:
  data generation/load, indicator construction, strategy execution, result
  materialization, and teardown must either be included for every engine or
  excluded for every engine.
- Report `security_bars_sec`, wall-clock seconds, dimensions, engine/package
  versions, Python/R versions, OS, CPU model, CPU comparability note, git SHA,
  and whether each row is `local_matched`, `orientation_only`, or `not_run`.
- If a peer cannot be installed or run locally, record the exact blocker and do
  not include that peer in a local matched ratio.
- Write a compact markdown/CSV/JSON summary under the benchmark result
  convention, and record the tracked summary in this packet or its closeout
  note.

### Acceptance Criteria

- The ledgr matched scenario runs at the record shape from current source.
- At least one event-driven Python peer runs locally under the same timing
  boundary, or the maintainer records that local peer execution is blocked and
  accepts deferring a local comparable comparison row.
- Any row used for a ledgr-to-peer comparison ratio is marked `local_matched`
  and was run on the same host during this ticket.
- Vendor/published Ziplime reference rows remain `orientation_only` and are not
  described as local comparable results.
- All headline throughput uses `security_bars_sec`; feature-cell units are not
  used for peer comparison.
- The release notes may mention the matched benchmark only with the exact
  caveats above and must not claim broad framework parity or a speed ranking
  beyond the measured local rows.

### Verification

Benchmark smoke/record review, current-source guard confirmation, peer-run
provenance review, and manual comparability review.

### Source Reference

- `dev/bench/README.md`
- `dev/bench/run_benchmarks.R`
- `dev/bench/fetch_ziplime_reference.R`
- `dev/bench/ziplime_reference.csv`

### Classification

```yaml
type: benchmark
surface: dev_bench
scope: matched_peer_comparison
```

### Completion Note

Completed 2026-05-29 on the local Intel Core i9-12900K Windows host.

Tracked summary:

| engine | status | host scope | wall sec | security_bars_sec | notes |
| --- | --- | --- | ---: | ---: | --- |
| ledgr durable run | local matched durable | same host | 313.42 | 2,010 | `peer_sma_crossover`, 500 assets x 1,260 daily bars, 2 SMA features, current-source `record` preset, `persist_features = FALSE`; writes durable run artifacts |
| ledgr one-candidate sweep | local matched ephemeral | same host | 381.46 | 1,652 | `peer_sma_crossover_sweep`, same dimensions and SMA features, current-source `record` preset; no durable per-candidate ledger, but current sweep orchestration is slower at this one-candidate shape |
| Backtrader | local matched orientation | same host | 114.46 | 5,504 | Same synthetic dimensions and SMA-crossover shape; data generation/feed construction excluded; timed boundary is `cerebro.run(runonce = TRUE, preload = TRUE)` |
| Ziplime/Polars | not run | same host unavailable | NA | NA | Local install attempt for `ziplime` in the disposable peer venv timed out after 124s before the package was installed |
| Zipline-reloaded | not run | same host unavailable | NA | NA | `pip install --dry-run zipline-reloaded` resolved packages, but no local run was completed in this ticket; Backtrader supplies the accepted same-host peer row |
| Published Ziplime/Zipline/Backtrader rows | orientation only | Apple M3 reference host | see `dev/bench/ziplime_reference.csv` | NA | Vendor/self-reported source rows remain orientation-only and are not used for local matched ratios |

Local ratio, using only same-host rows and `security_bars_sec`:

- durable ledgr run / Backtrader throughput: `2010 / 5504 = 0.37x`.
- Backtrader / durable ledgr run throughput: `5504 / 2010 = 2.74x`.
- ephemeral one-candidate ledgr sweep / Backtrader throughput:
  `1652 / 5504 = 0.30x`.
- Backtrader / ephemeral one-candidate ledgr sweep throughput:
  `5504 / 1652 = 3.33x`.

Generated result artifacts are under the ignored benchmark-results convention:

- `dev/bench/results/ledgr_bench_record_20260529T101029Z_summary.csv`
- `dev/bench/results/ledgr_bench_record_20260529T101029Z_results.json`
- `dev/bench/results/ledgr_bench_record_20260529T103637Z_summary.csv`
- `dev/bench/results/ledgr_bench_record_20260529T103637Z_results.json`
- `dev/bench/results/backtrader_peer_sma_crossover_local_20260529T101029Z.csv`
- `dev/bench/results/backtrader_peer_sma_crossover_local_20260529T101029Z.json`
- `dev/bench/results/backtrader_peer_sma_crossover_local_20260529T101029Z.md`

The comparison is intentionally narrow: one local event-driven Python peer row
on one synthetic SMA-crossover workload. It is suitable as a same-host
orientation point, not as broad framework parity or a general speed ranking.
The durable ledgr row is not boundary-symmetric with Backtrader because ledgr
writes durable ledger/equity artifacts to DuckDB while the Backtrader row holds
results in memory. The one-candidate sweep row is the closer in-memory
comparison, but it is slower than the durable run on this shape; the
persistence asymmetry therefore does not explain the peer gap by itself.

Follow-up decomposition on the same shape confirms that the peer gap is owned by
the v0.1.8.7 event-emission lane, not by SMA feature computation:

| ledgr mode | profiled wall sec | t_pre sec | t_loop sec | residual sec | dominant sampled R cost |
| --- | ---: | ---: | ---: | ---: | --- |
| durable run | 295.07 | 3.05 | 257.14 | 34.88 | `handler$buffer_event`, 137.08s self / 72.43% of sampled R time |
| one-candidate sweep | 384.40 | NA | NA | NA | `append_event_row_list`, 201.37s self / 81.72% of sampled R time |

Rprof samples R execution time and does not sum to elapsed wall time, so these
percentages should be read as attribution, not absolute wall accounting. The
result is still decisive: both durable and sweep peer rows spend their sampled
R time primarily appending/buffering fill events. That matches
`inst/design/audits/fold_path_hotpath_audit.md` Finding 1 and keeps the fix
lane in v0.1.8.7: primitive event buffers / typed event emission, followed by
timestamp and payload cleanup. The SMA feature path is small on this workload
(`t_pre` around 3s in the durable run).

Handoff: this result is the empirical priority input for v0.1.8.7
"Optimization Round 2" in `inst/design/ledgr_roadmap.md`, governed by
`inst/design/adr/0004-dependency-footprint-and-strategy-interface.md`. The next
cycle remains RFC-first and prioritizes the event-emission/buffering lane before
parallel dispatch; parallel dispatch stays deferred to v0.1.8.8.

---

## LDG-2452: v0.1.8.6 Release Gate And Closeout

Priority: P0
Effort: M
Dependencies:
  - LDG-2446
  - LDG-2447
  - LDG-2448
  - LDG-2449
  - LDG-2450
  - LDG-2451
  - LDG-2453
  - LDG-2454
  - LDG-2455
  - LDG-2456
  - LDG-2457
Status: Planned

### Description

Close v0.1.8.6 only after the materialization, benchmark, measurement, and
decision gates are complete, tickets and YAML are synchronized, docs are
updated, and release checks pass.

### Tasks

- Confirm all tickets and `tickets.yml` statuses are synchronized.
- Confirm the spec reflects final accept/defer/reject outcomes for storage and
  snapshot/helper work.
- Update `DESCRIPTION` and `NEWS.md` at release closeout.
- Update README/pkgdown/docs only for shipped behavior and accepted benchmark
  outputs.
- Record benchmark outputs or their location in the packet/retrospective.
- Record cold setup/residual profiling output or its maintainer disposition.
- Record performance attribution closeout output or its maintainer
  disposition.
- Record matched local peer benchmark output or its maintainer disposition.
- Confirm the v0.1.8.7 Optimization Round 2 handoff is explicit: the three
  hot-path lanes, fold-core primitive contract, run-artifact materialization
  policy, ADR 0004 dependency decisions, and LDG-2457 peer-benchmark
  remeasurement gate are recorded as next-cycle RFC-first work, while parallel
  dispatch remains deferred to v0.1.8.8.
- Confirm no auditr-report bugfix intake was required for closeout.
- Run targeted tests, full tests, and package checks appropriate to shipped
  code changes.
- Add a cycle retrospective or closeout note.

### Acceptance Criteria

- All v0.1.8.6 tickets are completed or explicitly deferred with rationale.
- `tickets.yml` and `v0_1_8_6_tickets.md` agree on final statuses.
- Required benchmark outputs and measurement decisions are recorded.
- Remaining speed gaps above the LDG-2456 threshold are named and owned, or
  explicitly accepted/deferred by the maintainer.
- Any peer-comparison claim is backed by `local_matched` same-host rows, while
  scraped vendor numbers remain labeled `orientation_only`.
- v0.1.8.7 follow-up ownership is recorded without granting v0.1.8.7
  implementation scope inside the v0.1.8.6 release gate.
- Release notes make no unshipped storage/schema/helper claims and no LEAN
  parity claim.
- Release checks pass according to `inst/design/release_ci_playbook.md`.

### Verification

Targeted tests, full test suite, package build/check as required by the release
playbook, benchmark smoke/record review, and manual closeout review.

### Source Reference

- `v0_1_8_6_spec.md` Sections 9-12
- `inst/design/release_ci_playbook.md`
- `inst/design/ledgr_roadmap.md` v0.1.8.7 Optimization Round section
- `inst/design/adr/0004-dependency-footprint-and-strategy-interface.md`
- `NEWS.md`
- `DESCRIPTION`

### Classification

```yaml
type: release_gate
surface: release_process
scope: v0.1.8.6
```
