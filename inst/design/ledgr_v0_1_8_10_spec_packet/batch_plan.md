# ledgr v0.1.8.10 Batch Plan

**Status:** Draft.

The batch plan preserves attribution while accepting two architectural
exceptions: fold-owned FIFO accounting ships as substrate/accounting ownership,
not only as a wall-recovery lane, and the compiled hot-frame B2 path is measured
directly as a gate before any v0.1.9.x promotion decision. Events remain
canonical throughout.

## Batch 0 - Packet Review And Ticket Alignment

Ticket: `LDG-2517`
Status: Pending

Goal: finalize the packet, tickets, YAML, batch plan, design index, and review
loop before implementation.

Exit criteria:

- Ticket cut is reviewed and caveats are patched or accepted.
- Spec, tickets, YAML, and batch plan agree.
- Active design index points to v0.1.8.10.
- Event-preserving FIFO boundary is explicit.

## Batch 1 - Ephemeral Subphase Telemetry

Ticket: `LDG-2518`
Status: Pending

Goal: expose `t_engine`, `t_results`, and `t_fills_extract` for ephemeral
workload-grid rows before substantive ephemeral changes land.

Exit criteria:

- Telemetry columns appear in workload-grid output.
- `density_high_large_ephemeral` and `density_high_xlarge_ephemeral` are
  measured.
- Telemetry overhead is negligible.
- Per-lane attribution row is recorded.

## Batch 2 - Matrix-Canonical Substrate And Accessors

Ticket: `LDG-2519`
Status: Pending

Goal: land the accepted accessor RFC and the integer-indexed substrate it
consumes.

Exit criteria:

- `ctx$vec`, `ctx$idx()`, and `ctx$vec$feature(feature_id)` pass contract tests.
- Internal `state$positions` primitive representation preserves public
  snapshot semantics.
- Fill-model contract audit is complete.
- Matrix-backed next-bar lookup preserves execution-bar context.
- Large/xlarge cells are remeasured.
- Per-lane attribution row is recorded.

## Batch 3 - Fold-Owned FIFO Accounting

Ticket: `LDG-2520`
Status: Pending

Goal: move FIFO lot accounting into the fold-owned accounting state transition
while preserving the event stream and reconstruction verifier/readback path.

Exit criteria:

- Event log, equity, fills, and lot-state parity pass.
- CASHFLOW opening positions and invalid/semantic-violation cases are covered.
- Fresh ephemeral summaries may use inline facts only after parity gates pass.
- Durable readback remains compatible.
- Large/xlarge durable and ephemeral cells are remeasured.
- Per-lane attribution row records phase movement and wall impact.

## Batch 4 - yyjsonr Options Hoist

Ticket: `LDG-2521`
Status: Pending

Goal: hoist fixed yyjsonr option objects out of hot helper bodies.

Exit criteria:

- Canonical JSON v2 byte fixtures unchanged.
- Nested/config read-shape tests unchanged.
- Helper benchmark confirms options-construction recovery.
- Per-lane attribution row is recorded.

## Batch 5 - Compiled Hot Frame B2 Gate

Ticket: `LDG-2522`
Status: Pending

Goal: run the B2-first compiled hot-frame measurement gate without authorizing a
public compiled execution path.

Exit criteria:

- Sub-A language/feasibility artifact is recorded in `ledgrcore-spike`.
- Sub-B production gate uses the real ledgr fold path through an internal,
  disabled-by-default execution-spec switch.
- Pattern B, not Pattern A, is the decision-bearing measurement.
- All parity gates pass or the B2 path is parked.
- LDG-2479 xlarge ephemeral wall recovery is classified as pass, review band,
  or fail using the RFC threshold matrix.
- Per-lane attribution row records build flags, parity, wall recovery, and
  disposition.

## Batch 6 - Parked Spike Disposition

Ticket: `LDG-2523`
Status: Pending

Goal: route or close small spike outputs after the main substrate lanes land.

Exit criteria:

- Split bucket, reusable ctx env, pulse-seed mixer, and alias-map normalization
  each have a disposition.
- Any landed cleanup has targeted tests and measurement.
- Deferred work is routed to horizon.

## Batch 7 - Measurement Closeout

Ticket: `LDG-2524`
Status: Pending

Goal: aggregate attribution and write the v0.1.8.9 to v0.1.8.10 closeout.

Exit criteria:

- `v0_1_8_10_release_closeout.md` exists.
- Per-lane attribution table is complete.
- Workload grid and peer benchmark are rerun or caveats are accepted.
- B2 gate outcome is recorded without public promotion language unless a
  separate v0.1.9.x promotion ticket is cut.
- Peer and workload-grid shapes are not mixed.
- No public speed-claim language appears.

## Batch 8 - Release Gate

Ticket: `LDG-2525`
Status: Pending

Goal: run final checks, update release notes, close the packet, and prepare
merge/tag.

Exit criteria:

- Required targeted tests pass.
- Full test suite and package check pass or accepted caveats are documented.
- Release closeout is reviewed.
- NEWS and design README are updated.
- Generated local artifacts are excluded.
