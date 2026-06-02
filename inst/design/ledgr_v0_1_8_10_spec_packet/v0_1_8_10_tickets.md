# ledgr v0.1.8.10 Tickets

Version: v0.1.8.10
Date: 2026-06-02
Total Tickets: 9

## Ticket Organization

This packet implements the scoped v0.1.8.10 plan from
`v0_1_8_10_spec.md`: ephemeral subphase telemetry, matrix-canonical fold
substrate, accepted strategy accessors, event-preserving fold-owned FIFO
accounting, yyjsonr options hoisting, compiled hot-frame B2 measurement gate,
and measurement closeout.

The release spine is:

```text
packet alignment
  -> ephemeral subphase telemetry
     -> matrix-canonical substrate and accessors
        -> fold-owned FIFO accounting and inline state capture
           -> yyjsonr options hoist
              -> compiled hot frame B2 gate
                 -> parked spike disposition
                    -> measurement closeout
                       -> release gate
```

Ticket IDs start at `LDG-2517` because `LDG-2505` through `LDG-2516` were
used by the v0.1.8.10 spike round.

## Dependency DAG

```text
LDG-2517 Packet Alignment And v0.1.8.10 Ticket Cut
  `-- LDG-2518 Ephemeral Subphase Telemetry
        `-- LDG-2519 Matrix-Canonical Substrate And Accessors
              `-- LDG-2520 Fold-Owned FIFO Accounting And Inline State Capture
                    `-- LDG-2521 yyjsonr Options Hoist
                          `-- LDG-2522 Compiled Hot Frame B2 Gate
                                `-- LDG-2523 Parked Spike Disposition
                                      `-- LDG-2524 Measurement Closeout
                                            `-- LDG-2525 v0.1.8.10 Release Gate
```

## Priority Levels

- P0: packet alignment, telemetry attribution, accounting parity, B2 gate,
  measurement closeout, or release gate.
- P1: primary substrate implementation lane.
- P2: small cleanup or disposition work that may defer if not justified.

---

## LDG-2517: Packet Alignment And v0.1.8.10 Ticket Cut

Priority: P0
Effort: S
Dependencies: none
Status: Completed

### Description

Finalize the v0.1.8.10 spec packet and align the design index, tickets,
machine-readable metadata, batch plan, and review loop before implementation
starts.

### Tasks

- Keep `v0_1_8_10_spec.md`, `v0_1_8_10_tickets.md`, `tickets.yml`, and
  `batch_plan.md` synchronized.
- Confirm `inst/design/README.md` points to v0.1.8.10 as active.
- Confirm the packet binds event-preserving fold-owned FIFO accounting and does
  not authorize event-log elision.
- Confirm the packet binds the B2 measurement gate without authorizing public
  compiled execution or durable compiled integration.
- Confirm non-scope remains deferred.
- Submit the ticket cut for review and patch caveats before implementation.

### Acceptance Criteria

- Spec, tickets, YAML, and batch plan agree on IDs, dependencies, priorities,
  statuses, and scope.
- No implementation ticket is missing a parity or measurement gate.
- Review feedback is patched or explicitly accepted.

### Verification

Manual packet review, stale-scope `rg` checks, YAML review, and peer-review
response.

### Completion Note (2026-06-02)

Batch 0 completed as packet-alignment work. The spec, ticket markdown, ticket
YAML, batch plan, and design README now agree on v0.1.8.10 as the active packet.
The packet explicitly binds event-preserving fold-owned FIFO accounting, keeps
events canonical, scopes the B2 compiled hot-frame work as a measurement gate
only, and keeps public compiled promotion / durable compiled integration
deferred. Stale-scope scans found no old Ticket 5 / pre-B2 non-scope wording
after the B2 RFC alignment.

### Source Reference

- `v0_1_8_10_spec.md`
- `inst/design/spikes/ledgr_v0_1_8_10_optimization_round_spike/architecture_synthesis.md`
- `inst/design/spikes/ledgr_v0_1_8_10_optimization_round_spike/codex_substrate_decision_review.md`
- `inst/design/rfc/rfc_compiled_hot_frame_b2_v0_1_9_x_synthesis.md`
- `inst/design/rfc/rfc_compiled_hot_frame_b2_v0_1_9_x_final_review.md`

### Classification

```yaml
type: governance
surface: design_packet
scope: v0.1.8.10
```

---

## LDG-2518: Ephemeral Subphase Telemetry

Priority: P0
Effort: S
Dependencies: LDG-2517
Status: In Review

### Description

Expose sweep-row subphase telemetry for ephemeral workload-grid rows so future
ephemeral attribution has durable-like phase visibility.

### Tasks

- Add `t_engine`, `t_results`, and `t_fills_extract` fields to sweep
  telemetry.
- Add timing snapshots around fold execution and summary/reconstruction in
  `ledgr_sweep_candidate_execute()`.
- Extend workload-grid CSV output with the new subphase columns.
- Verify overhead is negligible.
- Rerun at least `density_high_large_ephemeral` and
  `density_high_xlarge_ephemeral`.

### Acceptance Criteria

- Ephemeral workload-grid rows include non-NA engine/results/fills-extract
  subphase columns.
- Existing telemetry consumers still work.
- No behavioral changes to sweep results, artifacts, warnings, or errors.
- Attribution row is recorded before `LDG-2519` starts.

### Verification

Sweep telemetry tests, workload-grid smoke, large/xlarge ephemeral rerun, and
per-lane attribution review.

### Review Note

Batch 1 code is staged for Claude review before commit. Targeted verification
currently covers `tests/testthat/test-sweep.R`,
`tests/testthat/test-sweep-parallel.R`, and a tiny workload-grid sweep probe
that exercises `engine_sec`, `results_sec`, and `fills_extract_sec`.
Large/xlarge ephemeral reruns remain the post-review attribution gate.

### Source Reference

- `dev/spikes/spike-ephemeral-subphase-telemetry.md`
- `R/sweep.R`

### Classification

```yaml
type: telemetry
surface: sweep_workload_grid
scope: ephemeral_subphase_attribution
```

---

## LDG-2519: Matrix-Canonical Substrate And Accessors

Priority: P1
Effort: L
Dependencies: LDG-2518
Status: In Review

### Description

Implement the accepted strategy callback contract addendum and the R-side
substrate it consumes: integer instrument indexing, primitive internal
positions, `ctx$vec`, `ctx$idx()`, bulk feature reads, and matrix-backed
next-bar lookup preserving fill-model context.

### Tasks

- Add an `id_to_idx` map at execution-spec or fold setup.
- Convert internal `state$positions` to a primitive numeric vector while
  preserving public `ctx$positions` snapshot semantics.
- Add `ctx$idx(id, missing = c("error", "na"))`.
- Add `ctx$vec` OHLCV, positions, and `ctx$vec$feature(feature_id)`.
- Preserve scalar helper contracts.
- Replace per-fill data-frame next-bar row extraction with matrix-backed
  scalar lookup plus minimal execution-bar construction.
- Audit the fill-model contract and cost-resolver context.
- Update contracts and strategy guide docs.

### Acceptance Criteria

- `ctx$vec` and `ctx$idx()` match the accessor RFC synthesis.
- Unknown-id behavior is error-by-default with `missing = "na"` opt-in.
- Existing scalar helpers and strategy fixtures pass unchanged.
- Shuffled-order tests prove name/index alignment.
- Fill proposal preserves `instrument_id`, `ts_utc`, `open`, optional OHLCV,
  final-bar `NO_FILL`, and cost-resolver context shape.
- Helper Pass 1 consumes `ctx$vec` internally where applicable, with no new
  public helper Pass 2 surface.
- Large/xlarge durable and ephemeral rows are remeasured.
- Attribution row is recorded before `LDG-2520` starts.

### Verification

Pulse-context accessor tests, execution-spec tests, fill-model tests,
strategy-contract tests, strategy helper tests, workload-grid rerun, and
per-lane attribution review.

### Review Note

Batch 2 code and targeted verification are staged for review. The implementation
adds execution-spec `id_to_idx`, primitive internal fold positions with public
named `ctx$positions` snapshots preserved, `ctx$idx()`, `ctx$vec`, bulk vector
feature reads, matrix-backed next-bar scalar lookup, and helper Pass 1
`ctx$vec` consumption. Large/xlarge workload-grid reruns remain the
post-review attribution gate before completion.

### Source Reference

- `dev/spikes/spike-state-positions-primitive.md`
- `dev/spikes/spike-integer-indexed-accessors.md`
- `dev/spikes/spike-next-bar-matrix-lookup.md`
- `inst/design/rfc/rfc_strategy_callback_contract_addendum_v0_1_8_10_synthesis.md`
- `inst/design/rfc/rfc_strategy_authoring_helpers_v0_1_8_x_synthesis.md`
- `R/fold-engine.R`
- `R/pulse-context.R`
- `R/fill-model.R`

### Classification

```yaml
type: substrate
surface: fold_engine_and_strategy_context
scope: matrix_canonical_accessors
```

---

## LDG-2520: Fold-Owned FIFO Accounting And Inline State Capture

Priority: P0
Effort: XL
Dependencies: LDG-2519
Status: In Review

### Description

Move FIFO lot accounting into the fold core as event-preserving accounting
ownership. Emit typed accounting facts to output handlers and allow fresh
ephemeral sweeps to use inline equity/fill/accounting facts while preserving
the event log and reconstruction verifier path.

### Tasks

- Add `lot_state` to fold state.
- Apply FIFO lot accounting after fill resolution and before output-handler
  accounting fact emission.
- Emit per-fill realized PnL, cost basis, OPEN/CLOSE split facts, and
  per-pulse equity facts needed by fresh ephemeral summaries.
- Preserve event rows and materialized event output.
- Keep reconstruction as verifier/fallback/readback.
- Add parity fixtures for opening positions, CASHFLOW metadata, invalid sides,
  BUY_TO_COVER while long, SELL_SHORT while short, and malformed meta.
- Verify strategy callbacks cannot observe same-pulse post-fill lot state.
- Rerun workload-grid large/xlarge durable and ephemeral cells.

### Acceptance Criteria

- Event log parity holds for representative durable and ephemeral runs.
- Equity time-series parity holds against reconstruction.
- Fill table parity holds, including OPEN/CLOSE split rows.
- Cumulative `event_realized` and `event_cost_basis` match reconstruction.
- Opening-position / CASHFLOW branch is covered.
- Invalid-side, BUY_TO_COVER-while-long, SELL_SHORT-while-short, malformed-meta,
  and rejected-fill fixtures match durable extraction (Round-3 substrate gate
  #6).
- Durable readback and `ledgr_extract_fills_impl()` remain compatible.
- Fresh ephemeral summary path can bypass reconstruction only when parity gates
  pass.
- Attribution row reports both subphase movement and wall recovery.

### Verification

FIFO torture tests, sweep parity tests, backtest wrapper tests, durable
readback tests, opening-position fixtures, invalid-side fixtures, workload-grid
rerun, and per-lane attribution review.

### Review Note

Batch 3 code and targeted verification are staged for review. The
implementation adds fold-owned `lot_state`, applies FIFO accounting after fill
resolution, records typed accounting/equity/fill facts on the memory output
handler without changing materialized event rows, uses inline facts for fresh
ephemeral sweep summaries, and keeps durable reconstruction/readback paths
compatible. Large/xlarge workload-grid reruns remain the post-review
attribution gate before completion.

### Source Reference

- `dev/spikes/spike-inline-equity-accumulation.md`
- `dev/spikes/spike-inline-lot-state.md`
- `dev/spikes/spike-fold-time-lot-accounting.md`
- `inst/design/spikes/ledgr_v0_1_8_10_optimization_round_spike/codex_substrate_decision_review.md`
- `R/fold-engine.R`
- `R/lot-accounting.R`
- `R/fold-reconstruction.R`
- `R/sweep.R`

### Classification

```yaml
type: substrate
surface: fold_core_accounting
scope: event_preserving_fifo_lot_state
```

---

## LDG-2521: yyjsonr Options Hoist

Priority: P1
Effort: S
Dependencies: LDG-2520
Status: In Review

### Description

Hoist fixed yyjsonr read/write option construction out of hot helper bodies.

### Tasks

- Hoist `opts_read_json` for nested reads.
- Hoist `opts_read_json` for config reads.
- Hoist `opts_write_json` for canonical JSON v2 writes.
- Preserve canonical byte output and read-shape behavior.
- Measure read/reopen direction.

### Acceptance Criteria

- Canonical JSON v2 byte fixture tests pass unchanged.
- Nested and config read-shape tests pass unchanged.
- No hash/fingerprint fixture changes are introduced.
- Read-path helper benchmark confirms the option-construction recovery.
- Attribution row is recorded before `LDG-2522` starts.

### Verification

Canonical JSON tests, config tests, fingerprint tests, yyjson helper benchmark,
package load check, and per-lane attribution review.

### Review Note

Batch 4 code and targeted verification are staged for review. The
implementation hoists fixed nested-read, config-read, and canonical-v2-write
yyjsonr option objects out of helper bodies. Canonical byte-format and
read-shape tests pass unchanged. A 50k metadata-payload helper benchmark
measured old inline options at 1.10s versus the hoisted helper at 0.12s
(9.17x speedup).

### Source Reference

- `dev/spikes/spike-yyjsonr-read-recovery.md`
- `R/config-canonical-json.R`

### Classification

```yaml
type: optimization
surface: canonical_json_helpers
scope: yyjsonr_options_hoist
```

---

## LDG-2522: Compiled Hot Frame B2 Gate

Priority: P0
Effort: XL
Dependencies: LDG-2521
Status: Completed

### Description

Run the accepted B2-first compiled hot-frame measurement gate without
authorizing public compiled execution. The gate has two sub-artifacts: Sub-A in
`ledgrcore-spike` for language/feasibility and Sub-B in ledgr `dev/bench/` for
the production decision-bearing Pattern B measurement. Sub-B is a spot-asset
FIFO fill-batch accelerator gate, not a general compiled fold-core or
derivatives-accounting gate.

### Tasks

- Record or consume the Sub-A `ledgrcore-spike` artifact: language choice,
  build flags, small-fixture parity, and cross-platform parity smoke.
- Add an internal, unexported `compiled_accounting_model` execution-spec enum
  for the Sub-B measurement path. In v0.1.8.10 the closed set is `NULL` and
  `"spot_fifo"`: `NULL` means canonical R fold, `"spot_fifo"` means the
  internal spot-asset FIFO fill-batch accelerator.
- Validate `compiled_accounting_model` at execution-spec construction and at
  dispatch. Unsupported values must fail closed with a named
  unsupported-accounting-model error; no silent compiled fallback is allowed
  once a compiled model is requested.
- Route the real ledgr fold path to Pattern B only when
  `compiled_accounting_model == "spot_fifo"`.
- Measure Pattern B on the LDG-2479 `density_high_xlarge_ephemeral` production
  cell.
- Preserve Pattern A as parity/debug staging only; do not use Pattern A timing
  for pass/fail disposition.
- Record build flags, toolchain behavior, parity outcome, wall recovery, and
  pass / review-band / fail disposition.

### Acceptance Criteria

- Sub-B uses the real fold path; benchmark-only alternate fold engines,
  instrumented copies, and `assignInNamespace` swaps are not accepted.
- `compiled_accounting_model` defaults to `NULL`, and explicit `NULL` is
  equivalent to the default canonical R fold path.
- `"spot_fifo"` is the only v0.1.8.10 compiled accounting model; unsupported
  strings such as `"futures_margin"` fail fast with a named error before any
  compiled work runs.
- Pattern B owns spot-asset post-resolution fill-batch work only: fresh
  BUY/SELL FIFO lot-state transition, cash and positions mutation, event row
  value construction, and typed event accumulation.
- R remains owner of strategy execution, ctx construction, target validation,
  target risk, next-open proposal, cost resolution, features, equity, metrics,
  durable persistence, and replay.
- The spot-FIFO kernel must not be extended to derivatives, margin, options, or
  other accounting models in this ticket. Future accounting models require
  separate model values, RFC scope, and parity gates.
- Parity covers the Round-3 substrate gates plus B2 fresh/replay side semantics:
  event log, equity, fills, lot state, opening-position/CASHFLOW, invalid and
  semantic-violation fixtures, durable readback compatibility, no strategy
  lookahead, fresh BUY/SELL, and replay alias preservation.
- Outcome matrix is applied:
  `>= 30s` wall recovery plus all parity gates pass means pass;
  `15s <= recovery < 30s` plus all parity gates pass means review band;
  `< 15s` or any parity failure means fail/park.
- Pattern B build does not use `-ffast-math` or `-funsafe-math-optimizations`;
  if an optimization profile breaks parity, fall back to the fastest
  parity-preserving build profile per B2 RFC D9.
- No public compiled execution path, default compiled mode, durable compiled
  integration, or non-spot-FIFO compiled accounting model is enabled by this
  ticket.
- Attribution row is recorded before `LDG-2523` starts.

### Verification

Sub-A artifact review, compiled spot-FIFO fill-batch parity tests,
`compiled_accounting_model` validator tests, unsupported-accounting-model
fail-closed tests, production internal dispatch tests, LDG-2479 xlarge
ephemeral B2 benchmark, cross-platform parity smoke, and per-lane attribution
review.

### Completion Note (2026-06-02)

Batch 5 was approved in review and committed. The implementation adds an
internal cpp11 spot-FIFO batch kernel behind the closed
`compiled_accounting_model = NULL | "spot_fifo"` execution-spec enum. Default
and explicit `NULL` remain the canonical R fold; unsupported accounting models
fail closed. Targeted execution-spec and sweep dispatch tests pass, and the full
local test suite passed. The LDG-2479 `density_high_xlarge_ephemeral` record
cell measured 327.02s wall / 293.94s engine on the canonical R path versus
65.86s wall / 32.92s engine on the Pattern B `"spot_fifo"` path, with zero
failures and the same 66,280 fills in both passes. The scoped B2 gate is a pass
by the RFC threshold matrix. Local compiled artifacts are ignored and excluded
from package builds; the committed lane is source-only.

### Source Reference

- `inst/design/rfc/rfc_compiled_hot_frame_b2_v0_1_9_x_maintainer_decisions.md`
- `inst/design/rfc/rfc_compiled_hot_frame_b2_v0_1_9_x_synthesis.md`
- `inst/design/rfc/rfc_compiled_hot_frame_b2_v0_1_9_x_final_review.md`
- `R/fold-engine.R`
- `R/fill-model.R`
- `R/backtest-runner.R`
- `R/sweep.R`
- `R/lot-accounting.R`

### Classification

```yaml
type: measurement_gate
surface: compiled_hot_frame_b2
scope: pattern_b_production_gate
```

---

## LDG-2523: Parked Spike Disposition

Priority: P2
Effort: M
Dependencies: LDG-2522
Status: Completed

### Description

Record final dispositions for small or parked v0.1.8.10 spike outputs and land
only those whose post-main-lane profile justifies implementation.

### Tasks

- Revisit split/gsplit reconstruction bucket after `LDG-2520`.
- Revisit reusable pulse-context env only if helper-attachment profile remains
  material.
- Keep pulse-seed mixer parked unless per-pulse profile changes.
- Confirm alias-map normalization is covered by bulk feature reads.
- Record all dispositions in `per_lane_attribution.md` and horizon if needed.

### Acceptance Criteria

- Every parked spike has an explicit disposition.
- Any landed cleanup has tests and a measurement row.
- Deferred items are routed to horizon with version/window.

### Verification

Post-main-lane profile review, targeted tests if any cleanup lands, and
attribution/disposition review.

### Completion Note (2026-06-02)

Batch 6 completed as documentation/disposition work. No cleanup landed, so
targeted tests and fresh measurements are not applicable. The
post-main-lane disposition table in `per_lane_attribution.md` records:

- Spike 2 split/gsplit reconstruction bucket parked as fallback-only
  B1/collapse-doctrine cleanup if reconstruction becomes hot again.
- Spike 4 reusable ctx env parked; future work should profile helper
  attachment rather than public ctx env reuse.
- Spike 8 pulse-seed mixer parked below threshold; future implementation would
  need explicit cross-platform determinism parity.
- Spike 9 alias-map normalization has no standalone ticket: `ctx$vec$feature()`
  covers the hot cross-sectional pattern, while legacy `ctx$features()` alias
  behavior remains supported and alias-map vector interactions remain future
  feature-engine extension work.

### Source Reference

- `dev/spikes/spike-reconstruction-split-bucket.md`
- `dev/spikes/spike-pulse-context-env-reuse.md`
- `dev/spikes/spike-pulse-seed-mixer.md`
- `dev/spikes/spike-alias-map-normalize.md`

### Classification

```yaml
type: cleanup_triage
surface: fold_and_reconstruction
scope: parked_spike_disposition
```

---

## LDG-2524: Measurement Closeout

Priority: P0
Effort: L
Dependencies: LDG-2518, LDG-2519, LDG-2520, LDG-2521, LDG-2522, LDG-2523
Status: Pending

### Description

Aggregate per-lane attribution, rerun workload-grid and peer benchmarks, and
write the v0.1.8.9 to v0.1.8.10 closeout comparison.

### Tasks

- Complete `per_lane_attribution.md`.
- Rerun workload-grid record preset after all lanes land.
- Rerun repo-local peer benchmark.
- Write `v0_1_8_10_release_closeout.md`.
- Keep workload-grid and peer-benchmark shape comparisons separate.
- Record B2 gate outcome without authorizing public compiled execution unless a
  separate v0.1.9.x promotion ticket is cut.

### Acceptance Criteria

- Closeout cites source CSVs and exact rows.
- Within-run subphase shares are reported where available.
- Peer benchmark remains local-host/current-source only.
- Residual/deferred items are routed.
- B2 pass / review-band / fail disposition is explicit.
- B2 is framed as a spot-asset FIFO fill-batch accelerator; closeout language
  must not describe it as a general compiled fold core or derivatives-capable
  accounting engine.
- If B2 disposition is review-band or fail, a horizon entry routes the
  ephemeral wall attribution spike to v0.1.9.x as the next diagnostic path.
- No generated benchmark artifacts are committed unless explicitly scoped.

### Verification

Per-lane ledger review, workload-grid rerun, peer-benchmark rerun, closeout
review, and claim-language review.

### Source Reference

- `per_lane_attribution.md`
- `v0_1_8_10_spec.md`
- `inst/design/ledgr_v0_1_8_9_spec_packet/v0_1_8_9_release_closeout.md`

### Classification

```yaml
type: measurement_closeout
surface: benchmark_suite
scope: v0.1.8.9_to_v0.1.8.10_comparison
```

---

## LDG-2525: v0.1.8.10 Release Gate

Priority: P0
Effort: M
Dependencies: LDG-2517, LDG-2518, LDG-2519, LDG-2520, LDG-2521, LDG-2522, LDG-2523, LDG-2524
Status: Pending

### Description

Run final release checks, close the packet, update release notes, and prepare
the v0.1.8.10 merge/tag.

### Tasks

- Run targeted tests for all touched surfaces.
- Run full test suite.
- Build package.
- Run `R CMD check --no-manual --no-build-vignettes`.
- Update NEWS.
- Confirm design README active/completed language.
- Confirm generated artifacts are excluded.
- Record release-gate caveats if any.

### Acceptance Criteria

- Required targeted tests pass.
- Full suite and package check pass, or maintainer-accepted caveats are
  documented.
- Release closeout exists and is reviewed.
- NEWS accurately frames the release as substrate/accounting/telemetry work.
- NEWS/closeout do not imply public compiled promotion unless a separate
  v0.1.9.x promotion ticket is cut.
- Main branch/tag prep is unambiguous.

### Verification

Targeted tests, full tests, package build, package check, NEWS review, design
index review, git status review.

### Source Reference

- `v0_1_8_10_release_closeout.md`
- `NEWS.md`
- `inst/design/release_ci_playbook.md`

### Classification

```yaml
type: release_gate
surface: release_process
scope: v0.1.8.10
```
