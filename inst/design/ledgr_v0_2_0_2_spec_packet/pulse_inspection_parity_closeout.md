# Pulse Inspection Parity Closeout

**Status:** Agent-provisional; awaiting the Type 1 close review.
**Date:** 2026-09-28
**Cut:** 17
**Workstream:** 24
**Tickets:** LDG-2876 through LDG-2878
**Baseline:** `2000332`
**Implementation:** `15aaaba` and `0d1948e`, plus this closeout record.

## Outcome

Interactive pulse inspection now computes registered features through the
same dense feature engine as a real run. The former pulse-only implementation,
which truncated history to `requires_bars` and called `fn(window)` without
parameters, is gone. Exact-ID scalar feature loops now join the existing
slow-access warning when a whole-universe replacement exists.

LDG-2869 did not join this cut. Alias-aware whole-universe feature access also
remains deferred to the feature-engine RFC. The release gate waits for
maintainer acceptance of this workstream through its Workstream 24 dependency.

## Parity And Warning Evidence

LCL-0100 and LTB-0100 compare a public pulse against values observed inside a
public `ledgr_run()` at the same timestamp. The matrix covers:

- built-in SMA;
- an indicator with `series_fn`;
- `fn(window)`;
- `fn(window, params)` with `stable_after` greater than `requires_bars`; and
- recursive TTR RSI when TTR is installed.

Two instruments carry different price paths. The parameterized and series
routes also have literal terminal values of 40, so parity cannot be satisfied
only by both paths returning the same accidental value. Restoring the exact
pre-cut pulse implementation from `2000332` makes LTB-0100 error when the
parameterized indicator's `params` argument is missing.

LCL-0102 and LTB-0102 run the real fold over a 100-instrument axis. One hundred
exact-ID `ctx$feature()` reads emit one `ledgr_scalar_accessor_loop` condition
with accessor `feature`, count 100 and vector form
`ctx$vec$feature(feature_id)`. Ninety-nine reads emit none. One hundred mapped
`ctx$features()` reads emit none. Warned and suppressed runs have identical
fills and equity. Replacing the new wrapper with the original unrecorded
accessor fails LTB-0102 on the missing warning.

Mapped alias bundles stay outside the warning because there is no alias-aware
whole-universe accessor to recommend. That boundary moves only after the
feature-engine RFC chooses and ships such an accessor. LCL-0101 and LCL-0103
pin the corresponding article and help statements in the review lane.

## Shape And Cost

The seven-shape walk found no new scale-amplifying collection operation.

1. Pulse results are preallocated vectors manifested as one frame at the
   inspection boundary; there is no one-row-frame accumulation.
2. Snapshot history is queried once and split once by instrument; the feature
   loop indexes those groups and never rescans the full table by ID.
3. No timestamp is formatted or parsed element by element.
4. No JSON is parsed or encoded.
5. Pulse inspection delegates to the run feature engine instead of
   recomputing a second rule. Each declared feature is still deliberately
   computed once per requested instrument.
6. No validator or pairwise search was added.
7. Feature-warning recording uses the existing environment state. Its named
   count vector is bounded by the fixed accessor vocabulary, not by events,
   instruments or pulses, so the small base subassignment cannot become a
   data-scale copied buffer. The wrapper adds one O(1) record call only when
   the user chooses a scalar exact-ID read.

The pulse clock is interactive wall time around one warm
`ledgr_pulse_snapshot()` at 100 instruments and 2,000 bars per instrument.
Three
runs changed from 0.67/0.54/0.55 seconds (median 0.55) to
0.39/0.25/0.26 seconds (median 0.26). It is not a release gate.

The warning clock is warm wall time around a single-candidate memory sweep at
2,000 instruments and 30 pulses, with one exact-ID feature read per instrument
and pulse. Alternating fresh processes gave:

| Arm | Seconds | Median |
| --- | --- | --- |
| Before `15aaaba` | 2.000, 2.040, 2.060 | 2.040 |
| After LDG-2877 | 2.240, 2.310, 2.350 | 2.310 |

The deliberate recording cost is therefore 0.270 seconds at this shape. This
is an effect clock, not a performance gate.

## Verification

The final ordinary fast profile selected and passed 472 of 472 blocks in
96.220 seconds. The independent checker returned `LEDGR_TEST_GATE_OK` against
the 112-second bound. Records are at:

`C:/Users/maxth/ledgr-research/.tmp/ws24-fast-final`

The first full run caught mixed fast and review blocks under LCL-0100 and
LCL-0102. The registry was split into LCL-0100 through LCL-0103 without moving
any block. Two subsequent test executions passed every assertion but could not
persist their census in temporary record directories; neither was a package
failure. The final record uses the explicit writable research workspace.

Focused feature, pulse-context, scalar-warning, documentation and control-plane
suites pass. All four claims resolve to their registered blocks and actual
profiles. The three pulse-teaching article pairs are fresh, YAML parses and
`git diff --check` is clean.

## Governance

This closeout is agent-provisional. The requested Type 1 close review is the
first review invocation over three completed tickets, a projected ratio of
`1 / 3 = 0.333` against the 0.5 gate. Maintainer acceptance, not this draft,
closes Workstream 24 and Cut 17 and unblocks Workstream 15.
