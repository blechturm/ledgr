# ledgr v0.1.8.10 Batch Plan

**Status:** Completed.

The batch plan preserves attribution while accepting two architectural
exceptions: fold-owned FIFO accounting ships as substrate/accounting ownership,
not only as a wall-recovery lane, and the compiled hot-frame B2 path is measured
directly as a gate before the scoped LDG-2526 memory-backed sweep opt-in.
Events remain canonical throughout.

## Batch 0 - Packet Review And Ticket Alignment

Ticket: `LDG-2517`
Status: Completed

Goal: finalize the packet, tickets, YAML, batch plan, design index, and review
loop before implementation.

Exit criteria:

- Ticket cut is reviewed and caveats are patched or accepted.
- Spec, tickets, YAML, and batch plan agree.
- Active design index points to v0.1.8.10.
- Event-preserving FIFO boundary is explicit.

## Batch 1 - Ephemeral Subphase Telemetry

Ticket: `LDG-2518`
Status: Completed

Goal: expose `t_engine`, `t_results`, and `t_fills_extract` for ephemeral
workload-grid rows before substantive ephemeral changes land.

Exit criteria:

- Telemetry columns appear in workload-grid output.
- `density_high_large_ephemeral` and `density_high_xlarge_ephemeral` are
  measured.
- Telemetry overhead is negligible.
- Per-lane attribution row is recorded.

Review note:

- Code and targeted verification are staged for Claude review. Large/xlarge
  ephemeral record measurements remain the post-review attribution gate.

## Batch 2 - Matrix-Canonical Substrate And Accessors

Ticket: `LDG-2519`
Status: Completed

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
Status: Completed

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
Status: Completed

Goal: hoist fixed yyjsonr option objects out of hot helper bodies.

Exit criteria:

- Canonical JSON v2 byte fixtures unchanged.
- Nested/config read-shape tests unchanged.
- Helper benchmark confirms options-construction recovery.
- Per-lane attribution row is recorded.

## Batch 5 - Compiled Hot Frame B2 Gate

Ticket: `LDG-2522`
Status: Completed

Goal: run the B2-first spot-asset FIFO fill-batch measurement gate without
authorizing default compiled execution, durable compiled integration, or a
general compiled accounting engine.

Exit criteria:

- Sub-A language/feasibility artifact is recorded in `ledgrcore-spike`.
- Sub-B production gate uses the real ledgr fold path through a closed,
  disabled-by-default `compiled_accounting_model` enum.
- `compiled_accounting_model` is closed in this batch: `NULL` means canonical
  R fold, `"spot_fifo"` means the internal spot-asset FIFO accelerator, and
  unsupported values fail closed with a named error.
- Pattern B, not Pattern A, is the decision-bearing measurement.
- All parity gates pass or the B2 path is parked.
- LDG-2479 xlarge ephemeral wall recovery is classified as pass, review band,
  or fail using the RFC threshold matrix.
- Per-lane attribution row records build flags, parity, wall recovery, and
  disposition using scoped spot-FIFO language, not general compiled fold-core
  language.

Review note:

- Code, targeted tests, full test suite, smoke benchmark plumbing, and the
  LDG-2479 xlarge ephemeral Pattern B record pass are staged for review. One
  canonical R record pass measured 327.02s wall / 293.94s engine; one
  `compiled_accounting_model = "spot_fifo"` pass measured 65.86s wall / 32.92s
  engine with zero failures and the same 66,280 fills. The scoped B2 outcome
  passed the RFC matrix.

Completion note:

- Peer review approved the scoped B2 gate. The committed lane is source-only:
  local compiled artifacts are ignored and excluded from package builds. The
  lane is a spot-asset FIFO fill-batch accelerator gate; LDG-2526 handles the
  later memory-backed sweep public opt-in without default or durable promotion.

## Batch 6 - Parked Spike Disposition

Ticket: `LDG-2523`
Status: Completed

Goal: route or close small spike outputs after the main substrate lanes land.

Exit criteria:

- Split bucket, reusable ctx env, pulse-seed mixer, and alias-map normalization
  each have a disposition.
- Any landed cleanup has targeted tests and measurement.
- Deferred work is routed to horizon.

Completion note:

- Batch 6 is documentation/disposition only. No cleanup landed. The four parked
  spike outputs now have explicit post-main-lane dispositions in
  `per_lane_attribution.md`; targeted tests and fresh measurements are not
  applicable because no R or C++ code changed.

## Batch 7 - Measurement Closeout

Ticket: `LDG-2524`
Status: Completed

Goal: aggregate attribution and write the v0.1.8.9 to v0.1.8.10 closeout.

Exit criteria:

- `v0_1_8_10_release_closeout.md` exists.
- Per-lane attribution table is complete.
- Workload grid and peer benchmark are rerun or caveats are accepted.
- B2 gate outcome is recorded and scoped public opt-in promotion is handed to
  LDG-2526 without default, durable, or general compiled-core claims.
- Peer and workload-grid shapes are not mixed.
- No public speed-claim language appears.

Completion note:

- `v0_1_8_10_release_closeout.md` was reviewed and committed. The canonical workload
  record is `ledgr_bench_record_20260602T155628Z`; the seed-matched B2
  xlarge-ephemeral gate record is `ledgr_bench_record_20260602T162911Z`; the
  peer record is `peer_benchmark_record_20260602T162318Z`.

## Batch 8 - B2 Public Opt-In Promotion

Ticket: `LDG-2526`
Status: Completed

Goal: expose the measured B2 spot-FIFO accelerator as an explicit public
opt-in for memory-backed sweep execution while preserving canonical R as the
default and keeping durable compiled integration deferred.

Exit criteria:

- `ledgr_sweep(..., compiled_accounting_model = "spot_fifo")` reaches the
  scoped spot-FIFO path and matches canonical R on a FIFO fixture.
- `compiled_accounting_model = NULL` remains the default canonical R path.
- Unsupported values fail closed with `ledgr_unsupported_accounting_model`.
- `ledgr_run(..., compiled_accounting_model = "spot_fifo")` fails closed for
  committed durable runs with a user-facing durable-deferral message.
- Benchmark harnesses pass the public sweep argument directly instead of
  setting the internal option.
- Documentation and closeout language name the memory-backed sweep opt-in
  without implying default promotion, durable compiled integration, non-spot
  accounting support, CRAN readiness, or a general compiled fold core.
- macOS parity is verified or routed to horizon.

## Batch 9 - Release Gate

Ticket: `LDG-2525`
Status: Completed

Goal: run final checks, update release notes, close the packet, and prepare
merge/tag.

Exit criteria:

- Required targeted tests pass.
- Full test suite and package check pass or accepted caveats are documented.
- Release closeout is reviewed.
- NEWS and design README are updated.
- B2 public opt-in scope is reviewed and default behavior remains canonical R.
- Generated local artifacts are excluded.

Completion note:

- Batch 9 bumped package metadata to `0.1.8.10`, closed the packet status in
  ticket markdown/YAML and the design index, verified release-note language for
  the scoped memory-backed sweep B2 opt-in, and prepared the branch for the
  release playbook merge/tag sequence. Targeted sweep/backtest/accounting
  tests, the full local suite, CI-equivalent warning-strict `rcmdcheck`, the
  local pkgdown build, and the WSL DuckDB-sensitive gate passed. The remaining
  local check caveat is one accepted NOTE for two long design-spike file paths.
