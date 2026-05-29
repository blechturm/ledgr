# v0.1.8.6 Batch Plan

**Status:** Review batching plan for the v0.1.8.6 feature-projection and
benchmark cycle.
**Scope:** Groups the v0.1.8.6 tickets into implementation/review batches.

v0.1.8.6 is a measured setup-performance and storage-boundary release. The
review posture is different from v0.1.8.5: this cycle is not primarily
editorial. Reviewers should focus on parity, measurement validity, source
guarding, and keeping conditional storage/provenance work from blocking the
ready 5.0/5.1 materialization wins.

Global review standards:

- The implementation order is binding: 5.0 cache-key dedup before 5.1
  schema-only `feature_table`, with separate remeasurement after each.
- Measurements must run against current source, not an installed stale package.
- Benchmark output must separate phase timing from headline throughput.
- Do not conflate `security_bars_sec` with `feature_cells_sec`.
- LEAN / QuantConnect comparisons are allowed only as caveated side-by-side
  throughput comparisons, not equivalence or speed-ranking claims.
- Events remain the source of truth; optimization must preserve event-stream
  and LDG-2403 accounting parity.
- `ctx$feature_table` remains a plain data.frame field. No active binding,
  source inference, strategy capability hint, or public deprecation ships in
  this cycle.
- Typed persistent event columns are conditional. They ship only if the
  storage/schema gate explicitly accepts them after measurement.
- Snapshot administration and research-loop helper implementation is gated on
  an accepted RFC/spec decision and must not block 5.0/5.1.
- Auditr-report bugfix intake is deferred to the next version after auditr
  prompt fixes.

---

## Batch 0: Scope And Packet Alignment

Tickets:

- `LDG-2445` Packet Alignment And v0.1.8.6 Planning State

Purpose:

Finalize the active packet and make the v0.1.8.6 scope unambiguous before
runtime or benchmark work starts. This batch prevents the cycle from becoming a
general performance, storage, auditr, or roadmap cleanup bucket.

Review focus:

- `v0_1_8_6_spec.md`, `v0_1_8_6_tickets.md`, and `tickets.yml` agree.
- README, roadmap, and AGENTS point to v0.1.8.6 as the active packet.
- Auditr-report bugfix intake is explicitly deferred.
- The packet starts with 5.0 -> 5.1 -> remeasure -> benchmarks before storage
  decisions.
- Target risk, parallel dispatch, walk-forward, cost/liquidity, OMS, broad
  collapse adoption, and public benchmark dashboards remain deferred.

---

## Batch 1: Feature Cache-Key Deduplication

Tickets:

- `LDG-2446` Feature Cache-Key Deduplication

Purpose:

Remove redundant feature cache-key work without changing feature identity. This
is the cheap, high-value Direction 5.0 work from the accepted synthesis.

Review focus:

- `ledgr_feature_def_fingerprint(def)` is computed once per resolved concrete
  feature definition in the precompute/execution scope.
- `ledgr_feature_engine_version()` is computed once per precompute/execution
  scope.
- Memoization is scoped to the precompute/run assembly; it is not global and not
  persisted.
- `ledgr_feature_cache_key()` remains the canonical parity reference.
- Cache keys are byte-identical before and after dedup for scalar,
  multi-output, parameterized, and explicit-fingerprint definitions.
- Fingerprint-stability pins remain green.
- Feature cache schema, feature identity, persisted artifacts, and public APIs
  do not change.
- The post-change measurement records the effect on `t_pre`.

---

## Batch 2: Schema-Only Feature Table Default

Tickets:

- `LDG-2447` Schema-Only Feature Table Default

Purpose:

Stop building the full-panel long `feature_table` by default while preserving
strategy-facing behavior and parity. This is Direction 5.1 from the accepted
synthesis.

Review focus:

- Default runtime construction builds `features_wide` plus a zero-row,
  schema-preserving `feature_table`.
- Full-panel long is available only through explicit internal opt-in for tests,
  debugging, or compatibility paths that truly need it.
- Feature inspection builds only the current pulse's long shape on demand.
- The non-fast context path does not rebuild full long rows by default.
- `ctx$feature_table` remains a plain data.frame field.
- Existing `features_wide`, `feature()`, and `features()` behavior is
  unchanged.
- Schema-only-default and full-long-enabled runs produce identical event
  streams.
- LDG-2403 accounting parity remains green for both paths.
- The post-change measurement records the effect on `gap_viewbuild` or
  equivalent view-build timing.
- No public `feature_table` deprecation warning ships.

---

## Batch 3: Structured Benchmark Suite

Tickets:

- `LDG-2448` Structured Benchmark Suite And LEAN Reference

Purpose:

Turn the ad hoc feature-payload spike into a repeatable local benchmark suite
with named scenarios, current-source guards, machine-readable outputs, and a
small LEAN-comparable subset.

Review focus:

- Initial scenarios exist:
  `baseline_single_run`, `pulse_loop_empty`, `wide_panel_no_features`,
  `feature_read_score`, `feature_turnover`, `indicator_payload`,
  `sweep_memory_summary`, and `persistent_replay`.
- Synthetic or package-owned data is used.
- The suite refuses or clearly marks stale installed-package runs.
- Warmup/repeat behavior is explicit, with the first run skipped or marked.
- Results are machine-readable and include scenario parameters and environment
  metadata.
- Phase metrics are recorded; DPS is not the only result.
- `security_bars_sec` and `feature_cells_sec` are separate metrics.
- `dev/bench/lean_reference.csv` includes retrieval provenance through its
  sidecar metadata file.
- `feature_read_score` is measured as a ledgr-only scenario, not treated as
  LEAN-comparable.
- Documentation and output use caveated side-by-side comparison language, not
  LEAN parity or speed-ranking language.

---

## Batch 4: Width Sweep And Storage Decision

Tickets:

- `LDG-2449` Two-Mode Width Sweep And Storage Decision
- `LDG-2450` Conditional Storage And Typed Event Column Gate

Purpose:

Run the required two-mode instrument x feature width sweep and decide whether
any storage/schema work belongs in v0.1.8.6. This batch is a measurement and
decision gate first; implementation follows only if explicitly accepted.

Review focus:

- Width sweep runs in both modes:
  - read/score mode: feature access and scoring, no fills;
  - turnover mode: representative fills/events and reconstruction.
- Output separates feature-access scaling from fill/event/replay scaling.
- No width-invariance or storage-need claim appears before this sweep is
  recorded.
- The DuckDB feature-storage decision is recorded as implement, defer, or
  reject-for-now with evidence.
- If typed persistent event columns are accepted, follow-up implementation
  tickets name nullable-column migration and old/new/mixed replay parity gates.
- If typed persistent event columns are deferred, no persistent event schema
  change ships in v0.1.8.6.
- DuckDB SQL `json_extract` does not ship as a partial replay patch unless a
  separate release-blocking defect requires it.
- LDG-2410 typed memory events remain distinct from persistent-store typed
  columns.

---

## Batch 5: Fast Wide-View Manifestation

Tickets:

- `LDG-2453` Fast Wide-View DataFrame Manifestation

Purpose:

Apply the narrow, parity-preserving wide-view manifestation optimization found
during the Batch 4 review. This is not the primitive-only fold-core contract
redesign; it keeps `ctx$features_wide` as a data.frame and only makes that
data.frame cheaper to build from primitive projection columns.

Review focus:

- `ctx$features_wide` remains a plain data.frame with unchanged columns, values,
  and row order.
- No active binding, helper-only contract, matrix-canonical surface, or
  primitive-only fold-core redesign ships in this batch.
- The implementation uses primitive lists/matrices internally and stamps
  data.frames at the boundary without adding a collapse dependency.
- The old all-pulse wide data.frame plus `split.data.frame()` path is removed
  from default projection pulse-view construction.
- Event-stream parity, feature inspection, and mutation-leak fixtures remain
  green.
- Isolated view-build timing is remeasured at the largest Batch 4 grid.

---

## Batch 6: Cold Setup And Residual Profiling

Tickets:

- `LDG-2454` Cold Setup And Residual Phase Profiling

Purpose:

Record a diagnostic-only attribution of the remaining cold `t_pre` and broad
residual costs after the materialization fixes. This batch explains the next
optimization target; it does not optimize it.

Review focus:

- The current LDG-2453 wide-view manifestation work has been reviewed before
  this profiling is executed.
- Profiling uses current source and a representative cold benchmark shape.
- The result attributes the dominant `t_pre` cost to named code paths and
  records cold/warm cache state.
- The broad residual is attributed as far as the current hooks permit,
  separating feature view materialization from post-fold finalization/read-back
  where possible.
- Any temporary or retained timing hook is read-only and does not change fold
  behavior, event streams, snapshots, schemas, or public strategy surfaces.
- No optimization, storage/schema work, primitive-only fold-core redesign,
  active-binding surface, or collapse dependency is introduced in this batch.

---

## Batch 7: Drop Intermediate Wide-Matrix Allocation

Tickets:

- `LDG-2455` Drop Intermediate Wide-Matrix Allocation

Purpose:

Run the narrow follow-up optimization suggested by Batch 5 review after LDG-2454
has attributed the remaining setup/residual costs. LDG-2454 showed this is not
the dominant residual, so this batch is a cheap cleanup attempt rather than a
headline-bottleneck fix.

Review focus:

- LDG-2454 profiling is recorded before this optimization starts.
- `ctx$features_wide` remains a plain data.frame with unchanged columns, values,
  row order, and row names.
- Default pulse-view construction slices directly from
  `projection$feature_values` rather than building an all-pulse
  `feature_wide_values` matrix first.
- Full-long `feature_table = "full"` behavior remains intact.
- No matrix-canonical strategy surface, active binding, primitive-only fold-core
  redesign, public API change, storage/schema change, or collapse dependency
  ships in this batch.
- Event-stream parity, feature inspection, and pulse-context fixtures remain
  green.
- Isolated view-build timing is remeasured at the largest Batch 4 grid.

---

## Batch 8: Performance Attribution Closeout

Tickets:

- `LDG-2456` Performance Attribution Closeout

Purpose:

Name and own the remaining wall-clock gaps after LDG-2455 without optimizing
them. This is a diagnostic closeout gate: the release story should say which
large buckets remain, how they were measured, and which future lane owns them.

Review focus:

- The method uses differential toggles and `Rprof`, not new phase hooks or
  runtime behavior changes.
- The full attribution matrix runs at `100 instruments x 252 pulses x 50
  features`; the large-shape confirmation runs at least read/score cold with
  `persist_features = TRUE/FALSE`.
- `Rprof` output is used for function-level attribution and percentages, not
  uncalibrated absolute wall-clock seconds.
- The bucket table separates expected interpreter/GC/DBI/profiling overhead
  from genuinely unexplained-and-nameable time.
- Every bucket above `10%` of wall time or above `1s` is named and assigned an
  owner category.
- The genuinely unexplained-and-nameable remainder is below the threshold, or
  the maintainer explicitly marks it as a release-blocking attribution gap.
- No optimization, public API change, schema change, primitive-only fold-core
  redesign, phase-telemetry hook, or storage implementation ships in this
  batch.

---

## Batch 9: Snapshot/Provenance And Helper RFC Gate

Tickets:

- `LDG-2451` Snapshot Administration And Research-Loop Helper RFC Gate

Purpose:

Route snapshot administration, ETL provenance, sweep-review helper, and
promotion-recovery-summary helper work through the required design gate. This
batch may start during the cycle, but it must not block Batch 1 or Batch 2.

Review focus:

- An accepted RFC/spec decision exists before implementation tickets are cut.
- Engine-computed metadata, user-supplied descriptive metadata, and lifecycle
  state remain separated.
- `snapshot_hash` does not depend on mutable user metadata.
- Sweep-review helper design exposes the ranking rule and does not pick a
  winner silently.
- Promotion-recovery summary distinguishes stored facts from interpretation and
  recovery limitations.
- No automatic winner-picking, statistical validation, walk-forward, or
  production deployment approval helper is introduced.
- If the RFC/spec decision does not land in time, this batch defers without
  blocking the release's mandatory materialization and benchmark work.

---

## Batch 10: Release Gate

Tickets:

- `LDG-2452` v0.1.8.6 Release Gate And Closeout

Purpose:

Verify the shipped v0.1.8.6 work, close the packet, and record final
accept/defer/reject outcomes for conditional work.

Review focus:

- All ticket statuses are completed or explicitly deferred with rationale.
- `tickets.yml` and `v0_1_8_6_tickets.md` agree.
- Separate post-5.0 and post-5.1 measurements are recorded.
- Structured benchmark outputs and the two-mode width sweep are recorded.
- The late fast wide-view manifestation ticket is either accepted with parity
  evidence or explicitly reverted/deferred.
- The cold setup/residual profiling diagnostic is recorded or explicitly
  deferred with maintainer rationale.
- The intermediate wide-matrix allocation follow-up is either accepted with
  parity evidence or explicitly deferred with maintainer rationale.
- The performance attribution closeout names and owns all remaining large speed
  gaps, or records a maintainer disposition for any unresolved attribution gap.
- The storage/schema decision is recorded.
- Snapshot/provenance/helper work is either backed by accepted implementation
  tickets or explicitly deferred.
- No auditr-report findings are required for closeout.
- NEWS describes shipped behavior only and makes no LEAN parity claim.
- README/pkgdown/docs are updated only for shipped behavior and accepted
  benchmark outputs.
- Required targeted tests, full tests, package checks, and benchmark smoke or
  record reviews pass or have maintainer-recorded disposition.
- `cycle_retrospective.md` or an equivalent closeout note records outcomes,
  carry-forward items, benchmark decisions, and any RFC-cycle deviations.

---

## Recommended Execution Order

```text
Batch 0
  -> Batch 1
      -> Batch 2
          -> Batch 3
              -> Batch 4
                  -> Batch 5
                      -> Batch 6
                          -> Batch 7
                              -> Batch 8
                                  -> Batch 10

Batch 9 may start after Batch 0, but it does not block Batches 1-8.
```

Batch 1 and Batch 2 are the mandatory shippable spine. Batch 3 provides the
repeatable measurement framework. Batch 4 uses that framework to make the
storage decision. Batch 5 is a late narrow optimization that preserves the
current `features_wide` contract while making boundary manifestation cheaper.
Batch 6 is a diagnostic-only profiling pass that should run after the current
manifestation optimization is reviewed. Batch 7 is the immediate narrow
follow-up for dropping the intermediate wide-matrix allocation if LDG-2454
confirms it remains worthwhile. Batch 8 is the diagnostic attribution closeout
gate for remaining speed gaps. Batch 9 is a design gate that can ship only if
its RFC/spec decision lands cleanly; otherwise it defers. Batch 10 closes the
packet after the mandatory spine and all accepted gates are resolved.
