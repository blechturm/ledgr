# ledgr v0.1.8.9 Batch Plan

**Status:** Complete.

The batch plan preserves per-lane measurement attribution. Do not merge two
headline hot-path fixes into one batch unless the maintainer explicitly waives
attribution in writing.

## Batch 0 - Packet Review And Ticket Alignment

Ticket: `LDG-2495`
Status: Complete

Goal: finalize the packet, tickets, YAML, batch plan, design index, and Claude
review loop before implementation.

Exit criteria:

- Claude approves the ticket cut or caveats are patched.
- Spec, tickets, YAML, and batch plan agree.
- Active design index points to v0.1.8.9.
- Claude review caveats are incorporated or explicitly accepted.

## Batch 1 - Fills Extractor setv

Ticket: `LDG-2496`
Status: Complete

Goal: land the shared fills extractor `setv` fix and measure it before any
other hot-path optimization lands.

Exit criteria:

- Full fill-table parity passes.
- Stream-threshold materialization works.
- Large/xlarge durable and ephemeral cells are remeasured.
- Per-lane attribution row is recorded.
- Record-scale attribution is appended.

## Batch 2 - Persistent Durable Handler setv

Ticket: `LDG-2497`
Status: Complete

Goal: land the durable output-handler pending-column `setv` fix.

Exit criteria:

- Byte-identical ledger event parity passes.
- Durable large/xlarge cells are remeasured.
- Per-lane attribution row is recorded.

## Batch 3 - Memory Output Handler setv

Ticket: `LDG-2498`
Status: Complete

Goal: land the internal memory output-handler `setv` fix without creating a
public ephemeral API or changing the `meta` list-column structure. Batch 1
review also routed the inline sweep-summary fill-buffer write site here for
patch-or-defer triage.

Exit criteria:

- Sweep candidate memory event parity passes.
- Inline sweep-summary fill-buffer site is patched with parity or explicitly
  deferred.
- Parallel/sweep artifact-count surfaces remain clean.
- Ephemeral large/xlarge cells are remeasured.
- Per-lane attribution row is recorded.

## Batch 4 - Position Valuation Vectorization

Ticket: `LDG-2499`
Status: Complete

Goal: vectorize position valuation with alignment-safe fixtures.

Exit criteria:

- Shuffled-order fixture passes.
- Multi-instrument accounting remains unchanged.
- Large/xlarge cells are remeasured.
- Per-lane attribution row is recorded.

## Batch 5 - Target Delta Vectorization

Ticket: `LDG-2500`
Status: Complete

Goal: vectorize target-delta handling separately from position valuation.

Exit criteria:

- Target validation tests remain loud and unchanged.
- Shuffled target/instrument fixture passes.
- Large/xlarge cells are remeasured.
- Per-lane attribution row is recorded.

## Batch 6 - yyjsonr And Canonical JSON v2

Ticket: `LDG-2501`
Status: Complete

Goal: drop jsonlite, add yyjsonr, version canonical JSON byte format, and
document hash/fingerprint fallout.

Exit criteria:

- No production jsonlite call sites remain.
- Canonical JSON v2 byte fixtures pass.
- `simplifyVector = FALSE` and `simplifyVector = TRUE` parity shapes are
  covered.
- Contracts, DESCRIPTION, NEWS, and tests agree.
- Per-lane attribution row is recorded.

## Batch 7 - Optional Cleanup Triage

Ticket: `LDG-2502`
Status: Complete

Goal: use the post-main-lane profile to decide whether the small cleanup lanes
belong in v0.1.8.9 or defer.

Exit criteria:

- Decision recorded for Spike 5 next-bar lookup.
- Decision recorded for Spike 3 state-position representation.
- Decision recorded for residual fills extraction robustness.
- Any landed cleanup has its own attribution row.

## Batch 8 - Measurement Closeout

Ticket: `LDG-2503`
Status: Complete

Goal: aggregate per-lane attribution, rerun the workload grid and peer
benchmark, and write the v0.1.8.8 to v0.1.8.9 closeout comparison.

Exit criteria:

- `v0_1_8_9_release_closeout.md` exists.
- Per-lane attribution table is complete.
- Full workload grid and peer benchmark are rerun or accepted caveats are
  documented.
- No public speed claim language appears.

## Batch 9 - Release Gate

Ticket: `LDG-2504`
Status: Complete

Goal: run final tests/checks, close the packet, update release notes, and
prepare merge/tag.

Exit criteria:

- Required targeted tests pass.
- Full test suite and package check pass or accepted caveats are documented.
- Release closeout is reviewed.
- Kahan-vs-cumsum attribution language is updated where needed.
- Generated local artifacts are excluded.
