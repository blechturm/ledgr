# WS41 focused re-review 1 (Type 1), `d1e9f04d..38219a66`

## Verdict: CHANGES_REQUIRED

The corrections close most of F1-F10. One correction introduced a new scale
regression, four treatment detectors still miss their mutations, the fixture
ladder predates the corrections and one evidence line still overclaims. The
review was originally returned in-session as report-only; this file records it
under the M2 rule.

Method: the 33 focused suites, the fold-phase checker, the codebase census in
check mode, YAML, `git diff --check`, and 26 source-copy mutations of
`38219a66` (daemons load the mutated source, so parallel blocks stay
meaningful).

## Findings

### R1 (high): the F2 correction splits and rebinds the bars on every sweep and walk-forward build

`ledgr_history_substrate_for_experiment()` fetched one query result,
`ledgr_precompute_fetch_bars()` split it per instrument and the correction
immediately `do.call(rbind)`ed it back. At 800 instruments by 1,000 sessions
the build rose from 1.21 to 9.91 seconds, 5.88 seconds of it in `rbind`; the
execution-path reviewer measured 259 seconds for the rebind alone at 3,000 by
2,000. Fix: pass the unsplit query frame to `ledgr_history_substrate()`.

### R2 (medium): four claimed treatment detections still survive mutation

LTB-0292 passes with a refreshed chained source timestamp, a terminal plane
that ignores its knowledge cutoff, the explicit volume guard removed (the test
used the default `carry_allowed`) and no source clearing on an ineligible gap
inside the age bound. Fix: four literal assertions. Output carry leaking the
input-carried flag also survives; it was not part of F9 and is record-only.

### R3 (medium): the fixture ladder does not cover the corrected tree

The candidate label changed from `precommit_worktree` to `7dcd9968` without a
re-measurement, and the corrections changed membership replay, run feature
preparation and sweep substrate construction. Fix: rerun the ladder on the
final tree.

### R4 (low): one residual overclaim

LDG-3060 evidence line 4 still says LTB-0292 shows no change to membership,
trading, valuation or execution planes; the block has no such assertion. The
routing to LDG-3066 and LDG-3062/LDG-3063 is otherwise correct.

## Item results

| Item | Result |
| --- | --- |
| F1 complete-set replay | PASS; 0.50 s on the 580 by 1,200 by 6,961 probe under load; restoring full replay fails LTB-0291 |
| F2 observation planes | semantics PASS; placeholder observed fails LTB-0291 (3); R1 blocks |
| F3 docs narrowed | PASS apart from R4 |
| F4/F9 detectors | partial; R2 |
| F5 scoring-start mask | PASS; removing it fails exactly five LTB-0296 assertions |
| F6 descriptor key | PASS; every component but version fails LTB-0294, and version is enforced by the substrate version check |
| F7 transport record | PASS; serialized 125,898 against 49,994 (two invariant copies), ratio 0.397, package_head 9c1e352e |
| F8 task fields and per-fold staging | PASS; moving `exp` into tasks fails LTB-0295, forced sequential folds fail LTB-0296; RSS, re-staging and `seed = NULL` are in LDG-3069 acceptance |
| F10 frame reuse | PASS apart from R1 |

## Timing evidence

Both correction fast records are honestly labelled misses. Per block against
the pre-review record, the first correction run is 2.0 percent slower in
availability files and 2.1 percent slower elsewhere with no block more than
0.5 seconds slower; the retry is 19 and 15.5 percent slower across the board.
This indicates host variability rather than a product regression; the two
misses still need maintainer disposition.

## Out of scope, routed for the maintainer

1. High: a supplied substrate was validated against the default policy because
   the runner passed the always-NULL `cfg$history_policy` and
   `ledgr_history_policy_normalize(NULL)` defaulted. A `price_carry = NULL`
   walk-forward refused, and a strict experiment ran on a carry-5 substrate.
2. High: `ledgr_history_compute_feature_series()` had no end bound, so every
   walk-forward fold computed features to the shared substrate's global end
   (reviewer: 2.4 times slower than pre-cut, 6.7 times the needed cells).
