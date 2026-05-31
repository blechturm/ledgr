# ledgr v0.1.8.9 Tickets

Version: v0.1.8.9
Date: 2026-05-31
Total Tickets: 10

## Ticket Organization

This packet implements the scoped v0.1.8.9 plan from `v0_1_8_9_spec.md`:
single-core hot-path optimization, yyjsonr dependency consolidation, canonical
JSON byte-format v2, per-lane measurement attribution, and a v0.1.8.8 to
v0.1.8.9 closeout benchmark comparison.

The release spine is:

```text
packet alignment
  -> fills extractor setv
     -> persistent durable handler setv
        -> memory output handler setv
           -> position valuation vectorize
              -> target-delta vectorize
                 -> yyjsonr / canonical JSON v2 migration
                    -> optional cleanup triage
                       -> measurement closeout benchmark suite
                          -> release gate
```

v0.1.8.9 is not a second execution engine, compiled-core, target-risk,
walk-forward, OMS, public cost/liquidity, public benchmark, or public
ephemeral-fast-path release. Sequential `ledgr_run()` and `ledgr_sweep()` stay
the reference execution surfaces. The release preserves the v0.1.8.8
parallel/resume/snapshot/event contracts while removing measured R-idiom debt.

Ticket IDs start at `LDG-2495` because `LDG-2480` through `LDG-2494` were used
by the pre-RFC v0.1.8.9 spike round.

## Dependency DAG

```text
LDG-2495 Packet Alignment And v0.1.8.9 Ticket Cut
  `-- LDG-2496 Fills Extractor setv
        `-- LDG-2497 Persistent Durable Handler setv
              `-- LDG-2498 Memory Output Handler setv
                    `-- LDG-2499 Position Valuation Vectorize
                          `-- LDG-2500 Target Delta Vectorize
                                `-- LDG-2501 yyjsonr And Canonical JSON v2
                                      `-- LDG-2502 Optional Cleanup Triage
                                            `-- LDG-2503 Per-Lane Measurement And Benchmark Closeout
                                                  `-- LDG-2504 v0.1.8.9 Release Gate And Closeout
```

The sequence is intentional. Each headline lane must land with its own
before/after attribution table row before the next lane starts. This preserves
the v0.1.8.7 measurement discipline and prevents one bundled wall-time delta
from hiding an under-delivering hot-path fix.

## Priority Levels

- P0: Packet alignment, identity-format migration, measurement attribution,
  or release gate.
- P1: Primary measured hot-path optimization lane.
- P2: Conditional cleanup or robustness work that may defer if the post-main
  profile does not justify it.

---

## LDG-2495: Packet Alignment And v0.1.8.9 Ticket Cut

Priority: P0
Effort: S
Dependencies: none
Status: Completed

### Description

Finalize the v0.1.8.9 spec packet and make the active-version state
unambiguous across the design index, spec, ticket file, machine-readable
ticket metadata, batch plan, and Claude review loop.

### Tasks

- Keep `v0_1_8_9_spec.md`, `v0_1_8_9_tickets.md`, `tickets.yml`, and
  `batch_plan.md` synchronized.
- Confirm `inst/design/README.md` points to the v0.1.8.9 packet as active.
- Confirm the packet explicitly defers `ledgrcore`, target risk,
  walk-forward, public cost/liquidity, OMS, public benchmark claims, public
  ephemeral fast path, and memory-handler `meta_json` refactor.
- Confirm the source inputs include the approved spike synthesis and all
  fourteen spike logs.
- Confirm stale Round 1 spike-log recommendations have correction headers or
  are not treated as implementation scope.
- Submit the spec/tickets/batch plan to Claude for review before implementation
  starts.

### Acceptance Criteria

- Spec, ticket markdown, `tickets.yml`, and batch plan agree on ticket IDs,
  dependencies, priorities, statuses, and scope.
- Design README active-packet language points to v0.1.8.9.
- No implementation tickets are missing a measurement gate.
- No deferred milestone is accidentally promoted by active-packet text.
- Ticket dependencies form the intended sequential DAG.
- Claude ticket-cut review feedback is patched into the packet or explicitly
  accepted by the maintainer.
- Claude ticket-cut review feedback is either patched into the packet or
  recorded as accepted caveats with maintainer sign-off.

### Verification

Manual packet review, `rg` checks for stale version/scope text, YAML review,
and Claude peer-review response.

### Completion Note

Completed 2026-05-31. Claude returned "Approve With Caveats"; all caveats were
patched into the spec, ticket markdown, `tickets.yml`, and batch plan. The
review outcome is recorded in `ticket_cut_review_closeout.md`.

### Source Reference

- `v0_1_8_9_spec.md`
- `ticket_cut_review_closeout.md`
- `inst/design/README.md`
- `inst/design/spikes/ledgr_v0_1_8_9_optimization_round_spike/architecture_synthesis.md`

### Classification

```yaml
type: governance
surface: design_packet
scope: v0.1.8.9
```

---

## LDG-2496: Fills Extractor setv

Priority: P1
Effort: M
Dependencies: LDG-2495
Status: In Progress

### Description

Replace base-R per-row writes in `ledgr_fill_row_buffer_add()` with
`collapse::setv`, preserving the chunked extractor architecture used by
`ledgr_results(bt, "fills")`. This is the largest measured durable recovery
lane from Spike 12.

### Tasks

- Replace the column writes in `R/fold-reconstruction.R`'s fill row buffer
  append helper with `collapse::setv(..., vind1 = TRUE)`.
- Preserve the public `ledgr_results(bt, "fills")` surface.
- Preserve fill classification, side, price, quantity, fee, realized PnL,
  event sequence, and timestamps.
- Add full-output fill parity tests for representative fixtures.
- Verify rows above the streaming threshold materialize with correct row
  counts.
- Measure this lane before starting `LDG-2497`.
- Record one per-lane attribution table row for this ticket.

### Acceptance Criteria

- Full fill-table parity holds, not only sampled-row parity.
- Event/equity parity remains within existing gates.
- `ledgr_results(bt, "fills")` handles xlarge-scale rows without the old
  workload-grid row-count fallback, or a narrowed residual issue is documented.
- High-density large and xlarge durable cells record before/after
  `fills_extract_sec` and per-fill extraction metrics.
- High-density large and xlarge ephemeral cells are measured because the hot
  function is shared.
- No value-bearing collapse reduction is introduced.

### Verification

Targeted reconstruction/fills tests, xlarge-ish fixture test above
`stream_threshold`, workload-grid large/xlarge rerun for durable and ephemeral
cells, and per-lane attribution review.

### Implementation Note

Implementation review approved 2026-05-31. The code change and targeted tests
are ready to commit. The per-lane attribution row remains open until
record-scale large/xlarge durable and ephemeral reruns are appended to
`per_lane_attribution.md`; `LDG-2497` must not start before that measurement
gate is closed.

### Source Reference

- `v0_1_8_9_spec.md`, Workstream C
- `dev/spikes/spike-fills-reconstruction-scaling.md`
- `dev/spikes/spike-chunked-extractor-wall-recovery.md`
- `per_lane_attribution.md`
- `R/fold-reconstruction.R`
- `R/backtest.R`

### Classification

```yaml
type: optimization
surface: fills_extraction
scope: fill_row_buffer_setv
```

---

## LDG-2497: Persistent Durable Handler setv

Priority: P1
Effort: M
Dependencies: LDG-2496
Status: Pending

### Description

Replace base-R per-row writes into the persistent durable handler's
`pending_cols` buffers with `collapse::setv`, preserving existing buffered
flush and `DBI::dbAppendTable` semantics. This is the Spike 11 durable output
lane and replaces Spike 4 for default durable runs.

### Tasks

- Replace atomic pending-column writes in the persistent durable handler with
  `collapse::setv(..., vind1 = TRUE)`.
- Preserve flush boundaries, row order, event sequence continuity, timestamps,
  metadata bytes, and `DBI::dbAppendTable` behavior.
- Add parity tests covering all affected pending columns.
- Confirm live-mode per-row insert behavior is not silently changed by this
  ticket.
- Measure this lane after `LDG-2496` and before `LDG-2498`.
- Record one per-lane attribution table row for this ticket.

### Acceptance Criteria

- Byte-identical ledger events for representative durable runs before and
  after the change.
- `ledgr_run()` output semantics do not change.
- Final-bar no-fill warning behavior remains unchanged.
- High-density large and xlarge durable grid cells record before/after
  handler recovery and `t_loop_sec`/wall-share deltas.
- No durable artifact schema change.

### Verification

Durable run parity tests, audit-log equivalence tests, ledger-writer tests,
large/xlarge durable workload-grid rerun, and per-lane attribution review.

### Source Reference

- `v0_1_8_9_spec.md`, Workstream B.1
- `dev/spikes/spike-persistent-handler-buffer.md`
- `R/backtest-runner.R`

### Classification

```yaml
type: optimization
surface: durable_output_handler
scope: pending_cols_setv
```

---

## LDG-2498: Memory Output Handler setv

Priority: P1
Effort: M
Dependencies: LDG-2497
Status: Pending

### Description

Replace base-R per-row writes in the memory output handler's atomic event
columns with `collapse::setv`, preserving the existing in-memory event schema
and keeping the `meta` list-column to `meta_json` refactor deferred. Batch 1
review also found the same per-row inline fill-buffer write pattern in
`ledgr_sweep_summary_from_ordered_events()`; this ticket must either patch that
site with its own attribution row or record an explicit deferral before
closing.

### Tasks

- Replace atomic memory-handler event-column writes with
  `collapse::setv(..., vind1 = TRUE)`.
- Patch or explicitly defer the inline sweep-summary fill-buffer writes in
  `ledgr_sweep_summary_from_ordered_events()`.
- Preserve the `meta` list-column behavior.
- Preserve sweep candidate output, warning/error association, and result
  ordering.
- Confirm workers/candidates still do not write durable heavy artifacts.
- Measure this lane after `LDG-2497` and before `LDG-2499`.
- Record one per-lane attribution table row for this ticket.

### Acceptance Criteria

- Byte-identical in-memory event records for representative sweep candidates
  before and after the change.
- Sweep-summary inline fill-buffer parity is either byte-identical after a
  patch or explicitly deferred with rationale.
- Sequential and parallel sweep candidate parity remains unchanged.
- No new public ephemeral execution API.
- No worker/candidate durable writes are introduced.
- High-density large and xlarge ephemeral grid cells record before/after
  memory-handler recovery.
- Residual `meta` list-column cost is documented as deferred v0.1.8.10 polish.

### Verification

Sweep parity tests, parallel sweep tests if available locally, artifact-count
tests, ephemeral workload-grid large/xlarge rerun, and per-lane attribution
review.

### Source Reference

- `v0_1_8_9_spec.md`, Workstream B.2
- `dev/spikes/spike-memory-output-handler-growth.md`
- `R/sweep.R`
- `R/fold-reconstruction.R`

### Classification

```yaml
type: optimization
surface: memory_output_handler
scope: event_cols_setv
```

---

## LDG-2499: Position Valuation Vectorize

Priority: P1
Effort: S
Dependencies: LDG-2498
Status: Pending

### Description

Vectorize the per-pulse position valuation path while preserving instrument
alignment and public strategy semantics. This is the Spike 1 per-pulse lane.

### Tasks

- Replace the per-instrument interpreted position valuation loop with an
  alignment-safe vectorized path.
- Preserve named instrument alignment explicitly; do not rely on accidental
  vector order.
- Add tests with shuffled instrument/position order.
- Preserve equity, cash, positions value, and drawdown outputs.
- Measure this lane after `LDG-2498` and before `LDG-2500`.
- Record one per-lane attribution table row for this ticket.

### Acceptance Criteria

- Byte-identical fills and equity for deterministic fixtures.
- Shuffled-order fixtures prove alignment safety.
- Multi-instrument accounting identity remains unchanged.
- High-density large and xlarge grid cells record before/after engine-share
  deltas.
- No public API or strategy contract change.

### Verification

Fold-engine tests, multi-instrument accounting tests, sweep/run parity tests,
large/xlarge workload-grid rerun, and per-lane attribution review.

### Source Reference

- `v0_1_8_9_spec.md`, Workstream D
- `dev/spikes/spike-position-valuation-vectorize.md`
- `R/fold-engine.R`

### Classification

```yaml
type: optimization
surface: fold_engine_per_pulse
scope: position_valuation_vectorize
```

---

## LDG-2500: Target Delta Vectorize

Priority: P1
Effort: M
Dependencies: LDG-2499
Status: Pending

### Description

Vectorize target-delta computation so the fold iterates over real position
deltas rather than every target name wherever possible. This is the Spike 2
per-pulse lane and is intentionally separate from `LDG-2499` for attribution
and bisection.

### Tasks

- Compute target deltas through an alignment-safe vectorized path.
- Iterate only actionable deltas where behavior permits.
- Preserve full named numeric target-vector requirements.
- Preserve unknown-instrument and malformed-target failures.
- Preserve the rule that missing strategy targets are not silently treated as
  zero.
- Measure this lane after `LDG-2499` and before `LDG-2501`.
- Record one per-lane attribution table row for this ticket.

### Acceptance Criteria

- Byte-identical fills and equity for deterministic fixtures.
- Shuffled target/instrument order fixtures prove alignment safety.
- Unknown instrument targets still fail loudly.
- Missing, unnamed, duplicate, NA, or malformed targets still fail according
  to the existing contract.
- High-density large and xlarge grid cells record before/after engine-share
  deltas.

### Verification

Strategy target validation tests, fold-engine tests, sweep/run parity tests,
large/xlarge workload-grid rerun, and per-lane attribution review.

### Source Reference

- `v0_1_8_9_spec.md`, Workstream D
- `dev/spikes/spike-target-delta-vectorize.md`
- `R/fold-engine.R`

### Classification

```yaml
type: optimization
surface: fold_engine_per_pulse
scope: target_delta_vectorize
```

---

## LDG-2501: yyjsonr And Canonical JSON v2

Priority: P0
Effort: L
Dependencies: LDG-2500
Status: Pending

### Description

Drop jsonlite from ledgr's production dependency surface, adopt yyjsonr for
JSON reads/writes, and intentionally version the canonical JSON byte format.
This is a pre-CRAN identity-format migration with explicit hash and
fingerprint fallout.

### Tasks

- Replace jsonlite read/write call sites across `R/` with yyjsonr
  equivalents.
- Verify yyjsonr parity for `simplifyVector = FALSE` metadata shapes and
  `simplifyVector = TRUE` config/strategy/provenance shapes.
- Remove jsonlite from `DESCRIPTION` Imports and add `yyjsonr (>= 0.1.22)`.
- Update `inst/design/contracts.md` to name yyjsonr and the canonical write
  options.
- Regenerate the hard-coded `config_hash()` literal in
  `tests/testthat/test-sweep-parity.R`.
- Add canonical JSON byte-format v2 fixture tests with stored expected bytes.
- Update NEWS / release notes for hash invalidation and strategy provenance
  fingerprint changes.
- Audit production source with `rg "jsonlite|fromJSON|toJSON"`.
- Measure this lane after `LDG-2500` and before `LDG-2502`.
- Record one per-lane attribution table row for this ticket.

### Acceptance Criteria

- No production jsonlite call sites remain.
- `DESCRIPTION`, contracts, tests, and NEWS agree on yyjsonr.
- Canonical JSON byte-format v2 fixtures fail loudly on formatting drift.
- `simplifyVector = FALSE` and `simplifyVector = TRUE` read parity are both
  covered.
- Config hashes, snapshot hashes, strategy fingerprints, reproduction keys,
  and strategy provenance fingerprints change only where expected.
- Release notes clearly state that pre-v0.1.8.9 hashes do not match
  v0.1.8.9 hashes.

### Verification

Canonical JSON tests, hash/fingerprint tests, jsonlite grep audit, package
load, targeted config/snapshot/provenance tests, full test suite after fixture
regeneration, large/xlarge workload-grid sanity run if measurable, and
per-lane attribution review.

### Source Reference

- `v0_1_8_9_spec.md`, Workstream E
- `dev/spikes/spike-yyjsonr-readpath-parity.md`
- `dev/spikes/spike-yyjsonr-write-byte-identity.md`
- `R/config-canonical-json.R`
- `tests/testthat/test-sweep-parity.R`
- `inst/design/contracts.md`

### Classification

```yaml
type: dependency_migration
surface: canonical_json
scope: yyjsonr_and_byte_format_v2
```

---

## LDG-2502: Optional Cleanup Triage

Priority: P2
Effort: M
Dependencies: LDG-2501
Status: Pending

### Description

Decide, based on the post-main-lane profile, whether to land the smaller
cleanup/robustness lanes in v0.1.8.9 or defer them. This ticket covers
per-fill next-bar extraction, residual fills extraction robustness, and the
small `state$positions` representation lane from Spike 3. It does not
authorize unrelated optimization work. The Kahan-vs-cumsum attribution
language correction is mandatory release-gate work and is intentionally not
owned by this conditional P2 ticket.

### Tasks

- Re-profile after `LDG-2496` through `LDG-2501`.
- Decide whether Spike 5 next-bar matrix lookup still clears the v0.1.8.9
  threshold.
- Decide whether Spike 3 `state$positions` / `intvec_id_map` still clears the
  v0.1.8.9 threshold or explicitly defer it to v0.1.8.10+.
- Decide whether the fills extraction row-count fallback persists after
  `LDG-2496`; if yes, cut or perform a focused robustness fix.
- If any cleanup is implemented, measure it as its own per-lane attribution
  row.
- If cleanup is deferred, record the deferral in the release closeout and
  horizon.

### Acceptance Criteria

- The post-main-lane profile is reviewed before any cleanup implementation.
- No cleanup lane lands without its own measurement row.
- Next-open fill timing and final-bar no-fill semantics remain unchanged.
- Any persistent fills extraction robustness issue is narrowed and documented.
- Spike 3 disposition is recorded explicitly rather than silently dropped.
- Deferred items are recorded explicitly rather than silently dropped.

### Verification

Profile review, targeted fill timing tests if Spike 5 lands, fills extraction
robustness tests if needed, Spike 3 disposition review, and per-lane
attribution review.

### Source Reference

- `v0_1_8_9_spec.md`, Workstream F
- `dev/spikes/spike-next-bar-extraction.md`
- `dev/spikes/spike-state-positions-representation.md`
- `dev/spikes/spike-fills-extract-xlarge-breakdown.md`
- `dev/spikes/spike-duckdb-equity-roundtrip.md`

### Classification

```yaml
type: cleanup_triage
surface: fold_and_reconstruction
scope: optional_small_lanes
```

---

## LDG-2503: Per-Lane Measurement And Benchmark Closeout

Priority: P0
Effort: L
Dependencies: LDG-2496, LDG-2497, LDG-2498, LDG-2499, LDG-2500, LDG-2501, LDG-2502
Status: Pending

### Description

Aggregate the per-lane attribution table and run the round-closeout benchmark
suite comparing v0.1.8.8 and v0.1.8.9 headline figures. This is the
measurement verdict for the release, not a public performance claim.

### Tasks

- Confirm every headline lane has a before/after attribution row.
- Re-run the full LDG-2479 workload grid on post-v0.1.8.9 source.
- Re-run the LDG-2476 peer benchmark on post-v0.1.8.9 source.
- Compare v0.1.8.8 and v0.1.8.9 for wall time, within-run shares,
  per-fill engine cost, per-fill extraction cost, parity status, warnings, and
  failures.
- Include required headline rows: `density_high_xlarge_durable`,
  `density_high_large_durable`, `density_high_xlarge_ephemeral`, low-density
  regression cells, and ledgr vs Backtrader xlarge ratio.
- Write `v0_1_8_9_release_closeout.md`.
- Update horizon with residual v0.1.8.10 and v0.2.x targets.

### Acceptance Criteria

- Closeout artifact exists under the v0.1.8.9 spec packet.
- Closeout includes the per-lane attribution table.
- Closeout compares v0.1.8.8 and v0.1.8.9 headline figures using the same
  workload definitions.
- Within-run share is treated as the load-bearing claim; wall-to-wall deltas
  are caveated as local-host/current-source.
- No public speed ranking or hosted benchmark claim is made.
- Residual Backtrader gap is interpreted as input to the future `ledgrcore`
  decision, not as v0.1.8.9 scope.

### Verification

Workload-grid result review, peer benchmark result review, closeout review,
horizon diff review, and manual parity/claim-language review.

### Source Reference

- `v0_1_8_9_spec.md`, Measurement Gates
- `dev/bench/notes/workload_grid_baseline_closeout.md`
- `inst/design/ledgr_v0_1_8_8_spec_packet/peer_benchmark_parity_closeout.md`
- `inst/design/horizon.md`

### Classification

```yaml
type: measurement_closeout
surface: benchmark_suite
scope: v0.1.8.8_to_v0.1.8.9_comparison
```

---

## LDG-2504: v0.1.8.9 Release Gate And Closeout

Priority: P0
Effort: M
Dependencies: LDG-2495, LDG-2496, LDG-2497, LDG-2498, LDG-2499, LDG-2500, LDG-2501, LDG-2502, LDG-2503
Status: Pending

### Description

Run the v0.1.8.9 release gate, close the packet, and prepare the branch for
merge and tag. This gate requires the per-lane measurement closeout from
`LDG-2503`.

### Tasks

- Confirm all required tickets are complete or explicitly deferred.
- Confirm ticket markdown and `tickets.yml` statuses agree.
- Run targeted tests for fold, reconstruction, output-handler, sweep,
  parallel, resume, and canonical JSON changes.
- Run full test suite.
- Run package build and check.
- Review `v0_1_8_9_release_closeout.md`.
- Review NEWS/release notes for canonical JSON byte-format v2 and hash
  invalidation.
- Update parity attribution language from "DuckDB float round-trip" to "Kahan
  compensated summation vs naive cumsum" where applicable.
- Update roadmap, horizon, design README, and active-packet references as
  appropriate.
- Ensure generated local artifacts are not committed.

### Acceptance Criteria

- Required tests and checks pass or have documented accepted caveats.
- Event-stream parity and fill-table parity gates pass.
- Sequential/parallel and resume contracts remain unchanged.
- canonical JSON byte-format v2 is documented and tested.
- jsonlite has been removed from production dependencies.
- Kahan-vs-cumsum attribution replaces stale DuckDB-noise language in release
  documentation, parity comments, and closeout text.
- Workload-grid and peer-benchmark closeout artifacts exist and are
  honestly caveated.
- Release notes do not make public speed claims.
- The release branch is ready for merge and tag.

### Verification

Targeted tests, full tests, package build/check, release closeout review,
NEWS review, documentation grep for stale attribution language, documentation
index review, and manual release checklist.

### Source Reference

- `v0_1_8_9_spec.md`
- `v0_1_8_9_tickets.md`
- `tickets.yml`
- `batch_plan.md`
- `v0_1_8_9_release_closeout.md`

### Classification

```yaml
type: release_gate
surface: release_process
scope: v0.1.8.9
```
