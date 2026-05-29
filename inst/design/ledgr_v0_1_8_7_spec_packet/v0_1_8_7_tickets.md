# ledgr v0.1.8.7 Tickets

Version: v0.1.8.7
Date: 2026-05-29
Total Tickets: 10

## Ticket Organization

This packet implements the scoped v0.1.8.7 plan from `v0_1_8_7_spec.md`:
Optimization Round 2 plus explicit legacy execution cleanup. The cycle removes
raw `bars` execution, R6 strategy execution, and run-time `data_hash` identity
from modern execution; then it lands the measured hot-path lanes behind parity
and re-profile gates.

The release spine is:

```text
packet alignment
  -> legacy execution cleanup
  -> ADR 0004 dependency/function-strategy cleanup
  -> collapse deterministic wrapper
  -> B0 event buffer/emission
  -> R/A representation and setup cleanup
  -> C reconstruction/read-back cleanup
  -> run-artifact materialization policy
  -> post-lane benchmark and attribution
  -> release gate
```

v0.1.8.7 is not a compiled-core, parallel-dispatch, durable identity redesign,
matrix-canonical public surface, target-risk, walk-forward, cost/liquidity, OMS,
or public benchmark-dashboard release. Sweep crossover remains an open benchmark
target, not a claim.

## Dependency DAG

```text
LDG-2458 Packet Alignment And v0.1.8.7 Planning State
  |-- LDG-2459 Legacy Execution Cleanup
  |     `-- LDG-2462 B0 Event Buffer And Emission
  |           `-- LDG-2463 Representation And Setup Cleanup
  |                 `-- LDG-2464 Reconstruction And Read-Back Cleanup
  |                       `-- LDG-2465 Run-Artifact Materialization Policy
  |                             `-- LDG-2466 Post-Lane Benchmark And Attribution
  |
  `-- LDG-2460 ADR 0004 Dependency And Function-Strategy Cleanup
        `-- LDG-2461 Collapse Deterministic Wrapper
              `-- LDG-2464 Reconstruction And Read-Back Cleanup

LDG-2467 v0.1.8.7 Release Gate And Closeout
  depends on LDG-2458 through LDG-2466.
```

LDG-2462 may use `collapse::setv()` only as value-neutral event-buffer write
machinery. Value-bearing collapse operations wait for LDG-2461.

## Priority Levels

- P0: Scope gate, contract gate, legacy removal, or release gate.
- P1: Primary v0.1.8.7 optimization, benchmark, and materialization-policy work.
- P2: Follow-up cleanup or measurement work that is useful but not release
  critical.

---

## LDG-2458: Packet Alignment And v0.1.8.7 Planning State

Priority: P0
Effort: S
Dependencies: none
Status: Completed

### Description

Finalize the v0.1.8.7 planning packet and make the active-version state
unambiguous across the design index, roadmap, horizon, AGENTS notes, spec,
ticket file, and machine-readable ticket metadata.

### Tasks

- Keep `v0_1_8_7_spec.md`, `v0_1_8_7_tickets.md`, and `tickets.yml`
  synchronized.
- Confirm `inst/design/README.md`, `inst/design/ledgr_roadmap.md`,
  `inst/design/horizon.md`, and `AGENTS.md` all point to the v0.1.8.7 packet as
  active.
- Confirm the packet explicitly scopes legacy execution cleanup: raw `bars`,
  R6 strategies, and run-time `data_hash` identity are removed from modern
  execution.
- Confirm the packet explicitly defers compiled core, parallel dispatch,
  durable identity byte redesign, matrix-canonical public surface, target risk,
  walk-forward, cost/liquidity, OMS, and peer-crossover claims.

### Acceptance Criteria

- Spec, ticket markdown, and `tickets.yml` agree on ticket IDs, dependencies,
  statuses, priorities, and scope.
- README, roadmap, horizon, and AGENTS active-packet language agrees with the
  spec.
- No deferred milestone is accidentally promoted by active-packet text.
- The release spine is clear enough to cut review batches.
- Stale-scope `rg` checks and a diff review are recorded as the empirical
  packet-alignment evidence.

### Verification

Manual packet review and `rg` checks for stale active-packet, legacy-path, and
deferred-scope language.

Completion note (2026-05-29): Committed the v0.1.8.7 planning baseline in
`51c30cb` and rechecked the active packet across the spec, tickets, batch plan,
design index, roadmap, horizon, and AGENTS notes. Stale horizon references were
updated so v0.1.8.7 remains the single-core pure-R optimization and legacy
cleanup window, parallel dispatch stays deferred to v0.1.8.8, and compiled/FFI
work remains deferred. `rg` stale-scope checks and diff review were used as the
packet-alignment evidence.

### Source Reference

- `v0_1_8_7_spec.md`
- `inst/design/rfc/rfc_optimization_round_v0_1_8_7_synthesis.md`
- `inst/design/README.md`
- `inst/design/ledgr_roadmap.md`
- `inst/design/horizon.md`
- `AGENTS.md`

### Classification

```yaml
type: governance
surface: design_packet
scope: v0.1.8.7
```

---

## LDG-2459: Legacy Execution Cleanup

Priority: P0
Effort: L
Dependencies: LDG-2458
Status: Completed

### Description

Remove pre-snapshot execution gunk from modern execution. All run/sweep entry
points must reach the fold only through sealed snapshot-backed configs. Raw
mutable `bars` execution and run-time `data_hash` identity stop being
compatibility obligations.

### Tasks

- Add a fail-loud guard before fold entry for configs without
  `data.source = "snapshot"` and `data.snapshot_id`.
- Preserve `ledgr_backtest()` data-frame convenience only if it immediately
  converts the input to a sealed snapshot before execution.
- Remove `ledgr_run_data_subset_hash()` recomputation from sealed
  snapshot-backed run/resume identity.
- Replace modern run/resume identity with `config_hash`, stored `snapshot_id`,
  verified `snapshot_hash`, ordered `instrument_ids`, and inclusive selector
  bounds (`ts_utc >= start_ts`, `ts_utc <= end_ts`).
- Decide and implement the schema/API treatment of `runs.data_hash`,
  `ledgr_data_hash()`, and snapshot-adapter `data_hash` metadata: delete them
  or mark them archival/historical.
- Update docs, vignettes, and tests that still teach `data_hash` as modern
  sealed-run identity.

### Acceptance Criteria

- Raw/non-snapshot execution fails before runtime views or fold state are
  constructed.
- Snapshot-backed execution and resume no longer depend on per-run value
  rehashing.
- Snapshot tampering is still caught by `snapshot_hash` verification.
- Selector identity preserves the existing inclusive boundary semantics.
- No modern execution, resume, replay, sweep, or promotion path consults an
  archival `data_hash` field if one remains.

### Verification

Targeted snapshot/run/resume tests, tamper tests, raw-path failure tests, schema
tests if schema changes, and documentation grep checks for stale `data_hash`
identity language.

Completion note (2026-05-29): Removed the legacy raw-`bars` execution path from
modern config validation (`data.source = "snapshot"` and `data.snapshot_id` are
required before fold entry), removed run-time data-subset rehashing from
run/resume, deleted `runs.data_hash` from the modern schema, deleted the
exported `ledgr_data_hash()` helper and its man page, and removed snapshot
adapter `data_hash` metadata. `ledgr_backtest()` keeps data-frame convenience
by sealing the input into a snapshot before execution. Old-store migration still
tolerates historical `data_hash` columns only long enough to rewrite them out.
Verification run: targeted schema/snapshot/public API/raw-path/runner/resume
tests passed; `test_local()` ran for 10 minutes without failures before timing
out near the tail, and the remaining strategy/sweep tail tests passed
separately. Grep checks show no modern R/NAMESPACE/man/vignette data-hash
identity surface remains; remaining `data_hash` hits are migration fixtures,
the explicit deleted-helper contract note, and unrelated indicator-adapter
metadata.

### Source Reference

- `v0_1_8_7_spec.md`, Section 4
- `inst/design/audits/v0_1_8_7_data_subset_hash_review_request_response.md`
- `inst/design/audits/v0_1_8_7_representation_site_enumeration.md`

### Classification

```yaml
type: contract_cleanup
surface: execution_identity
scope: legacy_execution_removal
```

---

## LDG-2460: ADR 0004 Dependency And Function-Strategy Cleanup

Priority: P0
Effort: M
Dependencies: LDG-2458
Status: Completed

### Description

Implement ADR 0004's dependency and interface cleanup: drop `cli`, drop `R6`,
keep `tibble`, add `collapse`, and consolidate built-in/reference strategies on
the function strategy contract.

### Tasks

- Remove `cli` from package imports and stale roxygen/import declarations.
- Remove `R6` from package imports.
- Migrate built-in/reference strategies and strategy-key resolution away from
  R6 classes.
- Remove R6-specific replay/mutation semantics.
- Keep `tibble` as the public tidy result signal.
- Add `collapse` as an import/dependency for the v0.1.8.7 hot-path lanes.
- Ensure static/function-strategy checks apply uniformly to direct run, sweep,
  and replay paths.

### Acceptance Criteria

- `DESCRIPTION` and `NAMESPACE` no longer import `cli` or `R6`.
- Dependency/import grep output proves `cli` and `R6` are gone and `collapse`
  is present.
- Built-in/reference strategies are function-based.
- Direct run and replay execute the same function strategy contract.
- Tests that depended on `LedgrStrategy` or R6 mutation behavior are migrated to
  function-based equivalents or removed as obsolete.
- `tibble` result surfaces remain intact.

### Verification

Dependency grep, namespace checks, targeted strategy/replay/preflight tests, and
standard package load checks.

### Completion Notes

Completed in Batch 2. `cli` and `R6` were removed from package imports and
generated namespace declarations; `collapse` is now an imported dependency for
the v0.1.8.7 hot-path lanes. Built-in/reference strategies now resolve to
plain `function(ctx, params)` helpers (`hold_zero`, `echo`, `ts_rule`,
`state_prev`) and the legacy `$on_pulse`/R6 strategy object path is rejected
instead of stored as Tier 2 provenance. Targeted strategy, provenance, runner,
sweep parity, sweep, API export, dependency, namespace, and package-load checks
passed.

### Source Reference

- `v0_1_8_7_spec.md`, Section 5
- `inst/design/adr/0004-dependency-footprint-and-strategy-interface.md`

### Classification

```yaml
type: dependency_cleanup
surface: strategy_interface
scope: adr_0004
```

---

## LDG-2461: Collapse Deterministic Wrapper

Priority: P0
Effort: M
Dependencies: LDG-2460
Status: Planned

### Description

Add the deterministic wrapper required before any value-bearing `collapse`
operation lands. The wrapper must pin relevant `collapse` global state and
restore caller settings on both normal and error exits.

### Tasks

- Implement `ledgr_with_collapse_deterministic()` or the agreed internal helper.
- Pin at least `nthreads = 1L`, `na.rm = FALSE`, `sort = TRUE`, and
  `stable.algo = TRUE`.
- Inspect host-exposed `set_collapse()` fields (`remove`, `digits`, `stub`,
  `verbose`, `mask`) and either pin them or document why they are irrelevant for
  the used operations.
- Add hostile-setting fixtures that mutate at least `nthreads`, `na.rm`, `sort`,
  and `stable.algo`.
- Prove settings restore on normal exit and error exit.

### Acceptance Criteria

- Caller collapse settings are restored after success and failure.
- Hostile caller settings cannot affect wrapper-scoped value-bearing outputs.
- The wrapper is available before any value-bearing reconstruction/metric
  collapse operation is introduced.
- Value-neutral `setv` use is documented as requiring event-stream parity but
  not floating-point parity.

### Verification

Targeted deterministic-wrapper tests, hostile-setting tests, and error-path
restore tests.

### Source Reference

- `v0_1_8_7_spec.md`, Section 10
- `inst/design/collapse_optimization_map.md`
- `dev/spikes/spike-reconstruction-collapse.md`

### Classification

```yaml
type: determinism_gate
surface: collapse_integration
scope: wrapper
```

---

## LDG-2462: B0 Event Buffer And Emission

Priority: P1
Effort: L
Dependencies: LDG-2459, LDG-2460
Status: Completed

### Description

Land the surface-preserving event-buffer/emission fix. Replace worst-case event
buffer preallocation with realistic sizing/growth and optionally use
`collapse::setv()` for value-neutral in-place writes if the real run supports
it.

### Tasks

- Replace default `n_inst * n_pulses` event-buffer allocation with realistic
  sizing / grow-by-doubling.
- Capture the pre-change turnover baseline, or cite an already-recorded
  current-source baseline that is still valid for this branch.
- Use defaults around initial capacity 1024, 2x growth, and hard cap at the
  worst-case ceiling unless profiling justifies adjustment.
- Apply equivalent event-surface discipline to durable `handler$buffer_event`
  and sweep `append_event_row_list`.
- Optionally use direct primitive columns and/or `collapse::setv(col, i, v,
  vind1 = TRUE)` if measured value justifies it.
- Preserve event ids, event order, timestamps, `meta_json`, and DB-backed vs
  memory-backed event surfaces.
- If `meta_json` serialization is deferred, keep per-row canonical JSON with
  `vapply(meta_list, canonical_json, character(1))`; do not serialize one JSON
  array for the column.
- Re-profile the LDG-2457 turnover workload after the change.

### Acceptance Criteria

- Durable run and memory sweep event streams are byte-identical to the current
  surface for representative workloads.
- Event ids remain byte-identical.
- `meta_json` remains per-row canonical JSON.
- POSIXct class and `tzone` are preserved across durable and memory events.
- Real-run re-profile records the B0 effect and compares it to the expected
  high-turnover wall range.
- The B0 closeout includes a before/after current-source timing table or an
  explicit maintainer disposition if the benchmark could not be rerun.

### Verification

Event-stream parity tests, sweep parity tests, turnover benchmark re-profile,
and matched peer benchmark rerun if practical.

### Completion Notes

Completed in Batch 3. Durable and memory event handlers now initialize event
buffers at `min(1024, max_events)` and grow by doubling up to the hard
worst-case cap supplied by the fold. The event surface remains unchanged:
event IDs, event order, POSIXct UTC timestamps, per-row canonical `meta_json`,
and typed memory-event attributes are preserved. No `collapse::setv()` path was
introduced in this batch; the B0 win came from right-sizing/growth alone.

Verification included durable buffer growth/cap tests, memory buffer growth
tests, runner tests, sweep parity, sweep tests, and backtest-wrapper parity.
Post-B0 current-source benchmark rows were recorded under the updated local CPU
power profile:

- durable `peer_sma_crossover` (`500 x 1260 x 2`, one measured iteration):
  wall 32.91s, pre 1.50s, loop 20.87s, residual 10.54s, 13,355 events.
- one-candidate `peer_sma_crossover_sweep`: wall 30.67s, 6,585 fills.

The old LDG-2457 pre-B0 profile is retained as mechanism evidence, not a direct
wall-time comparison after the local power-profile change. Its durable
`handler$buffer_event` self-time was 137.08s / 72.43% of sampled R time. The
post-B0 profiled durable pass under the updated local power profile recorded
`handler$buffer_event` at 1.50s / 3.49%,
with the remaining top self-time now in `rbind`, `format.POSIXlt`, `sprintf`,
and strategy callback work. That confirms B0 removed the intended buffer
bottleneck and leaves Lane R/C costs for later batches.

### Source Reference

- `v0_1_8_7_spec.md`, Section 6
- `inst/design/audits/fold_path_hotpath_audit.md`
- `dev/spikes/spike-event-buffer-rewrite.md`
- `dev/spikes/spike-event-buffer-factorial.md`

### Classification

```yaml
type: optimization
surface: event_emission
scope: b0_buffer
```

---

## LDG-2463: Representation And Setup Cleanup

Priority: P1
Effort: L
Dependencies: LDG-2462
Status: Planned

### Description

Remove addressable timestamp/string and setup waste without touching durable
identity bytes. This combines Lane R and Lane A because both target hot-path
representation leakage while keeping durable hashes fenced.

### Tasks

- Reject sub-second timestamp input at snapshot seal/ingest.
- Capture the post-B0 setup/representation baseline before changing this lane,
  or cite an already-recorded current-source baseline.
- Carry trusted whole-second POSIXct values through hot paths instead of
  repeatedly formatting/parsing them.
- Remove per-pulse/per-fill normalization where the value is already sealed and
  trusted.
- Preserve current observable whole-second timestamp bytes in durable events,
  memory events, equity rows, replay, and reopen.
- Preserve exact event-id strings.
- Hoist run-level timestamp normalization out of per-key cache loops.
- Replace JSON+SHA session-local feature cache keys with an unambiguous
  length-prefixed composite string if implementation stays deterministic and
  collision-free at the string-encoding level.
- Keep `canonical_json()`, snapshot hashes, feature fingerprints, strategy/config
  identity hashes, and provenance bytes unchanged.
- Re-profile after the change and distinguish R/A effects from B0 effects.

### Acceptance Criteria

- Daily, minute, and second-resolution timestamp parity fixtures remain green
  across durable events, memory events, equity, replay, and reopen.
- Sub-second inputs fail clearly at seal/ingest.
- Durable hash/fingerprint pins remain green.
- Feature-cache behavior remains deterministic within a run/session.
- No durable identity bytes change.
- Post-change timing records the setup/representation effect.
- The closeout includes a before/after current-source timing table separating
  setup/representation effects from B0 effects.

### Verification

Timestamp parity tests, sub-second rejection tests, hash/fingerprint pin tests,
feature-cache tests, event-id parity tests, and current-source re-profile.

### Source Reference

- `v0_1_8_7_spec.md`, Sections 7 and 8
- `inst/design/audits/v0_1_8_7_representation_site_enumeration.md`
- `inst/design/audits/fold_path_hotpath_audit.md`

### Classification

```yaml
type: optimization
surface: representation_and_setup
scope: lane_r_a
```

---

## LDG-2464: Reconstruction And Read-Back Cleanup

Priority: P1
Effort: L
Dependencies: LDG-2461, LDG-2463
Status: Planned

### Description

Rewrite read-back reconstruction hot spots behind real-ledgr parity fixtures.
This is primarily a result-materialization/read-back improvement, not a
headline run-wall claim.

### Tasks

- Rewrite `ledgr_fills_from_events()` away from per-row `data.frame()` plus
  `do.call(rbind, rows)`.
- Prefer preallocated columns and primitive column access such as `.subset2`.
- Use `collapse::rowbind`, `fcumsum(x, g)`, or grouped operations only inside
  the deterministic wrapper when value-bearing.
- Preserve CASHFLOW-before-fill handling, FIFO lot-state progression, close/open
  split row ordering, event ordering, column order, classes, and `event_seq`.
- Cover DB-backed and memory-backed event tables.
- Capture pre-change read-back timing, or cite an already-recorded
  current-source baseline.
- Record read-back timing after the change.

### Acceptance Criteria

- `ledgr_results(..., "fills")` is byte-/value-equivalent to current behavior
  for real ledgr event semantics.
- Sweep summary parity remains green where helpers are shared.
- Hostile `collapse` settings cannot change value-bearing reconstruction
  outputs.
- Timing is reported as read-back/materialization improvement, not as primary
  run-wall speed.
- The closeout includes before/after read-back timing.

### Verification

Focused fills reconstruction tests, sweep summary tests, hostile-collapse
fixtures, DB-backed vs memory-backed parity, and read-back timing.

### Source Reference

- `v0_1_8_7_spec.md`, Section 9
- `dev/spikes/spike-reconstruction-collapse.md`
- `inst/design/collapse_optimization_map.md`

### Classification

```yaml
type: optimization
surface: reconstruction
scope: lane_c_readback
```

---

## LDG-2465: Run-Artifact Materialization Policy

Priority: P1
Effort: M
Dependencies: LDG-2464
Status: Planned

### Description

Formalize the fast/slow artifact split. Evaluation and sweep paths should avoid
durable heavy artifacts by default while retaining the compact reproduction key
needed to materialize or promote later.

### Tasks

- Identify which heavy artifacts are avoided by fast/evaluation paths and which
  compact result records remain.
- Store or verify the reproduction key needed for later materialization:
  snapshot identity, selector, strategy/config identity, feature definitions or
  fingerprints, engine version, seed/RNG metadata where applicable, and
  candidate parameters.
- Add or adjust materialization/promotion helpers so users can explicitly pay
  the durable artifact cost later.
- Prove ephemeral result vs promoted/materialized result parity for reported
  metrics and covered event/equity surfaces.
- Record timing or artifact-size evidence for fast/evaluation vs
  materialized/promotion paths.
- Update docs so durable heavy artifacts are not implied to be free or always
  produced by the fast path.

### Acceptance Criteria

- Sweep/evaluation results can be promoted or materialized without requiring
  the user to reconstruct the experiment manually.
- Materialized artifacts are reproducible from the stored key.
- Ephemeral result vs promoted/materialized result parity is proven for the
  covered surfaces.
- Documentation clearly distinguishes fast/evaluation paths from
  promotion/inspection paths.
- The closeout includes empirical timing or artifact-size evidence for the
  fast/slow split.

### Verification

Promotion/materialization tests, sweep result tests, parity tests, and docs grep
for stale artifact assumptions.

### Source Reference

- `v0_1_8_7_spec.md`, Section 11
- `inst/design/rfc/rfc_optimization_round_v0_1_8_7_synthesis.md`

### Classification

```yaml
type: artifact_policy
surface: sweep_and_promotion
scope: fast_slow_materialization
```

---

## LDG-2466: Post-Lane Benchmark And Attribution

Priority: P1
Effort: M
Dependencies: LDG-2465
Status: Planned

### Description

Rerun the benchmark and attribution suite after the major lanes land. The goal
is to report what moved, compare measured changes against bounded expectations,
and keep peer comparisons honest.

### Tasks

- Rerun current-source benchmark scenarios relevant to B0, R/A, C, and artifact
  policy.
- Rerun the matched local peer benchmark for the SMA crossover shape.
- Record wall time, phase timings where available, security-bars/sec,
  feature-cells/sec where applicable, events/sec, dimensions, event counts, and
  environment metadata.
- Compare measured B0/R/C changes against the synthesis ranges:
  B0 high-turnover about 1.7x-1.9x if the buffer work is removed; R turnover
  about 1.05x-1.15x unless profiling says otherwise; C as read-back/materializer
  improvement.
- Keep LEAN/Ziplime/vendor rows caveated as orientation unless locally matched.
- Do not claim sweep crossover unless multi-candidate same-host measurements
  support it.

### Acceptance Criteria

- Benchmark outputs are current-source guarded and machine-readable where
  practical.
- The attribution names remaining large buckets and assigns ownership or
  accepted-overhead status.
- Peer comparison language states timing-boundary differences and comparable
  scope.
- Release notes can cite the results without implying public benchmark or peer
  superiority claims.

### Verification

Benchmark record review, attribution-table review, current-source guard review,
and manual comparability review.

### Source Reference

- `v0_1_8_7_spec.md`, Section 12
- `dev/bench/run_benchmarks.R`
- `dev/bench/peer_sweep_three_way.R`
- `dev/bench/peer_sweep_verify.R`

### Classification

```yaml
type: benchmark
surface: dev_bench
scope: post_lane_attribution
```

---

## LDG-2467: v0.1.8.7 Release Gate And Closeout

Priority: P0
Effort: M
Dependencies: LDG-2458, LDG-2459, LDG-2460, LDG-2461, LDG-2462, LDG-2463, LDG-2464, LDG-2465, LDG-2466
Status: Planned

### Description

Close the v0.1.8.7 cycle only after the legacy paths are removed/fail-loud, the
accepted hot-path lanes are implemented or explicitly deferred by maintainer
decision, and parity, benchmark, documentation, and package checks are complete.

### Tasks

- Confirm all ticket statuses in `v0_1_8_7_tickets.md` and `tickets.yml`
  agree.
- Confirm no legacy raw `bars`, R6 strategy, or run-time `data_hash` path remains
  load-bearing for modern execution.
- Run targeted parity tests for snapshot, event-stream, timestamp, feature
  cache, reconstruction, sweep, and artifact materialization surfaces.
- Run full local tests and package checks appropriate for a release gate.
- Review docs/vignettes for stale legacy identity or R6/raw-bars language.
- Update NEWS/release notes, cycle retrospective, and active-packet pointers as
  needed.
- Record benchmark and attribution results in the packet.

### Acceptance Criteria

- All scoped tickets are completed or explicitly deferred with maintainer
  rationale.
- Full verification required by the release gate is green or exceptions are
  documented and accepted.
- README, roadmap, AGENTS, horizon, and packet docs agree on release state.
- Release notes state speed results honestly and preserve peer-comparison
  caveats.

### Verification

Targeted tests, full test suite, package checks, benchmark record review,
documentation review, and manual closeout review.

### Source Reference

- `v0_1_8_7_spec.md`
- `v0_1_8_7_tickets.md`
- `tickets.yml`

### Classification

```yaml
type: release_gate
surface: release_process
scope: v0.1.8.7
```
