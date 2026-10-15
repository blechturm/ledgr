# Workstream 38 focused re-review 1

**Mode:** Type 1 focused re-review
**Range:** `6594b6fe..87a14a91`
**Verdict:** CHANGES_REQUIRED (record only)
**Date:** 2026-10-15

F1 through F6 are resolved. Every product and detector correction holds under
mutation. F7 retains one low record defect: the closeout's stage ledger pairs
each commit with the next commit's record directory. The records themselves
are exact; only the labels are shifted. This is Workstream 38's second review
round, and the record-only correction needs no third review.

## Resolved findings

### F1. Growth shape

P4 keeps positions and cash local and writes them back once. Equity facts use
the preallocated accumulator. Restoring the environment-held element write
fails LTB-0279.

The independent rerun measured a median candidate/base ratio of 0.848 at
5,000 instruments, within about one percent of the recorded 0.8390. One
12,000-instrument pair measured 40.0 seconds candidate against 51.0 seconds
pre-WS38, ratio 0.785. The uncorrected extraction took about 72 seconds on that
shape.

### F2 and F3. Diagnostics and scalar state

Baseline `valuation` and `accounting` diagnostic stages are restored. Scalar
strategy state resumes again. Reintroducing either defect fails its new test.

### F4. Compiled position names

The record now states why the accepted `setNames()` repair exists: making the
fold return live state exposed unnamed positions from the compiled kernel.

### F5. Detector coverage

The checker catches a missing, duplicated or swapped stage, an envelope write
to cash, environment-held vector writes and an inline data frame in a returned
list. A data frame returned through a variable is caught by the runtime
LTB-0281 witness. The claims match that combined boundary.

### F6. RNG claim

The RNG claim now promises only public caller-state restoration. Removing only
the fold's own restoration can be masked by the runner and sweep restoration,
which is consistent with the narrowed claim.

## Remaining record correction

### F7. Stage-ledger labels

The records were taken on a dirty candidate immediately before the commit that
owned that boundary. Their `meta.csv` therefore names the previous commit. The
closeout table incorrectly assigned each record to that previous commit rather
than to the candidate boundary it records.

Correct mapping:

- `e4c357ee` -> `ws38-envelope`;
- `4d3ef112` -> `ws38-p1`;
- `388baab7` -> `ws38-p2`;
- `ebc19157` -> `ws38-p3`;
- `0f6bd974` -> `ws38-p4`;
- `57f1caab` -> `ws38-p5`;
- `a56ef6e8` -> `ws38-live-return` before commit and `ws38-final` after commit.

`99d31f94` and `2b1717c6` have no record of their own. Correcting the table
does not alter any exactness result.

## Disposition

Apply the record correction in place and accept Workstream 38 on the corrected
record. No product change or further independent review round is required.
