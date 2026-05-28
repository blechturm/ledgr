# ledgr v0.1.8.6 Tickets

Version: v0.1.8.6
Date: 2026-05-28
Total Tickets: 8

## Ticket Organization

This packet implements the scoped v0.1.8.6 plan from `v0_1_8_6_spec.md`:
feature-projection materialization, a structured benchmark suite with a small
LEAN-comparable subset, post-fix width measurement, storage/provenance decision
gates, and research-loop helper follow-up.

The release spine is:

```text
packet alignment
  -> feature cache-key dedup
  -> schema-only feature_table default
  -> structured benchmark suite
  -> two-mode width sweep and storage decision
  -> conditional storage/schema gate
  -> snapshot/provenance and helper RFC gate
  -> release gate
```

v0.1.8.6 is not an auditr-fix release. The next auditr report is deferred until
the auditr repository prompt fixes land. It is also not a public performance
dashboard, target-risk, parallel-dispatch, walk-forward, cost/liquidity, OMS,
or broad-collapse release.

## Dependency DAG

```text
LDG-2445 Packet Alignment And v0.1.8.6 Planning State
  |-- LDG-2446 Feature Cache-Key Deduplication
  |     `-- LDG-2447 Schema-Only Feature Table Default
  |           |-- LDG-2448 Structured Benchmark Suite And LEAN Reference
  |           |     `-- LDG-2449 Two-Mode Width Sweep And Storage Decision
  |           |           `-- LDG-2450 Conditional Storage And Typed Event Column Gate
  |           `-- LDG-2451 Snapshot Administration And Research-Loop Helper RFC Gate
  `-- LDG-2452 v0.1.8.6 Release Gate And Closeout

LDG-2452 depends on LDG-2446 through LDG-2451. LDG-2450 is a decision gate:
typed persistent event columns are implemented only if storage/schema work is
explicitly accepted after LDG-2449. LDG-2451 is also a gate: implementation
tickets for snapshot administration or research-loop helpers are cut only after
the relevant RFC/spec input is accepted.
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
Status: Planned

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
Status: Planned

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
Status: Planned

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
Status: Planned

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
Status: Planned

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

### Source Reference

- `v0_1_8_6_spec.md` Sections 5 and 6
- `rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md`
- benchmark outputs from LDG-2448

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
Status: Planned

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

### Source Reference

- `v0_1_8_6_spec.md` Section 5
- `rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md`
- `R/db-schema-create.R`
- `R/ledger-writer.R`
- `R/derived-state.R`
- `R/backtest-runner.R`

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
Status: Planned

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
- Confirm no auditr-report bugfix intake was required for closeout.
- Run targeted tests, full tests, and package checks appropriate to shipped
  code changes.
- Add a cycle retrospective or closeout note.

### Acceptance Criteria

- All v0.1.8.6 tickets are completed or explicitly deferred with rationale.
- `tickets.yml` and `v0_1_8_6_tickets.md` agree on final statuses.
- Required benchmark outputs and measurement decisions are recorded.
- Release notes make no unshipped storage/schema/helper claims and no LEAN
  parity claim.
- Release checks pass according to `inst/design/release_ci_playbook.md`.

### Verification

Targeted tests, full test suite, package build/check as required by the release
playbook, benchmark smoke/record review, and manual closeout review.

### Source Reference

- `v0_1_8_6_spec.md` Sections 9-12
- `inst/design/release_ci_playbook.md`
- `NEWS.md`
- `DESCRIPTION`

### Classification

```yaml
type: release_gate
surface: release_process
scope: v0.1.8.6
```
