# WS41 focused re-review 2 (Type 1), `38219a66` plus the uncommitted second correction

## Verdict: CHANGES_REQUIRED

Every product item in scope verifies. R1-R4 and the two former out-of-scope
defects are fixed, the per-instrument segment compiler and the incremental
membership cursor agree with the canonical resolvers under randomized
differentials, the sticky terminal barrier matches the maintainer decision
and the evidence record is honest. No product defect was found.

What blocks acceptance is small: two detectors that the claims rely on do not
detect the regressions they name (N1, N2), one counter is vacuous (N3), and
the correction adds a redundant `availability_active` branch to run code,
which AGENTS.md forbids (N4). N1-N3 are test patches; N4 is a one-line
product patch. Nothing here needs Type 2.

Method: the full suite once (1,114 blocks, 0 failures, one optional-package
skip); the fold-phase checker; the codebase census in check mode (all files
equal to the committed census except the `mode` and `source_commit` labels in
`metadata.csv`); YAML of `tickets.yml` and `tests/claims.yml`;
`git diff --check`; 23 source-copy mutations (daemons load the mutated
source). 18 were killed. N1, N2 and N5 name three of the five survivors. The
other two are equivalent on registered fixtures and are not findings: an ISO
start truncated to midnight on a daily close axis, and a runner given the
substrate end, which in the registered walk-forward is the last test end.
The method also used randomized differentials for segments, the membership
cursor and the terminal barrier; public-path probes for policy validation and
feature bounds; and scale probes. Probes and logs are in reviewer scratch.

## Findings

### N1 (medium): LTB-0296 does not detect a training sweep calculating past its window

`tests/testthat/test-history-substrate.R:1581-1602`. The recorder parses
`calculation_end` with `as.POSIXct()`, which truncates the ISO string
`2020-01-12T16:00:00Z` to midnight, and the block asserts only that *some*
recorded end precedes the last test end. Mutation: in `R/sweep.R:311` pass
`meta$end` instead of `range$scoring_end`. Walk-forward training sweeps then
calculate to the snapshot end (recorded ends `2020-01-13T16:00:00Z` twice;
non-NA feature cells rise from 8 to 21), which is the former out-of-scope
defect B for training. The whole of `test-history-substrate.R` still passes:
the truncated test-run end satisfies `any(end < max(test_end))`. LCL-0291's
"remove either calculation boundary" is detected (dropping the argument gives
NA), but a wrong boundary is not.

Fix: parse with `ledgr:::ledgr_history_utc()` in the recorder and assert
`all(feature_bounds$end <= max test end)`, or that the recorded ends equal the
fold windows' scoring ends.

### N2 (medium): out-of-order complete-header eligibility in the membership cursor has no registered detector

`R/availability-provider-prepared.R:80-83`. Mutation M16 updates
`latest_complete` without the `header > state$latest_complete` guard. Headers
become eligible in knowledge order but are ranked in effective order, so with
lagged knowledge an earlier-effective complete set that becomes knowable later
moves the complete-set boundary backwards and turns omitted instruments back
into members. This cursor answers every availability decision pulse. M16
survives every block in `test-history-substrate.R`,
`test-history-foundation.R`, all 20 `test-availability-*` files,
`test-pit-consistency.R`, `test-pit-input-documentation.R`,
`test-sweep-parallel.R`, `test-walk-forward-orchestrator.R`,
`test-strategy-context-projection.R` and
`test-long-window-regression-control.R`.

The reviewer's randomized differential against
`ledgr_membership_resolve_prepared()` is clean on the candidate and catches
M16 (221 mismatching steps in 60 families). It used complete, incomplete and
mixed sets with lagged knowledge and intervals, and forward, reversed,
shuffled and repeated passes on one cursor. The LTB-0291 incomplete-set check
uses same-clock headers and forward cutoffs only. The related rewind mutation
(M15, no reset on a backward cutoff) survives `test-history-substrate.R` but
is caught by `test-availability-provider-production.R` and
`test-availability-provider-witnesses.R`.

Fix: add to LTB-0291 one small mixed family whose earlier-effective complete
header is known after a later one. Query it forward, backward and forward
again on one resolver and compare with `ledgr_membership_resolve_prepared()`.

### N3 (low): the complete-set call counter in LTB-0291 is vacuous

`tests/testthat/test-history-substrate.R:398-415` counts calls to
`ledgr_membership_apply_prepared_header()`, which
`ledgr_availability_prepared_membership_from_plan()` no longer calls. Probe:
0 apply calls and 40 advance calls for the 40-set pass, so
`expect_lte(0, 80)` holds whatever the cursor does. LCL-0288's oracle claims
the counter covers complete headers. The incomplete-set counter below it is
live. Fix: count `ledgr_membership_advance_prepared_header()` there too and
expect exactly `scaling_n`.

### N4 (low): the correction adds an `availability_active` branch to run code

`R/backtest-runner.R:797-801` adds
`history_policy <- if (availability_active) ... else NULL`. AGENTS.md forbids a
new execution-mode branch in fold or run code. It is redundant:
`validate_ledgr_config()` already requires a current history identity on every
config (`R/config-validate.R:362`), so
`ledgr_history_identity_require_current(cfg$history)` can run unconditionally.
Fix: drop the conditional.

### N5 (record-only): the mixed civil-frame refusal is untested

Removing the refusal in `ledgr_fact_resolve_civil_frame()`
(`R/availability-facts.R:1163-1168`) survives `test-history-foundation.R` and
`test-history-substrate.R`. Public constructors cannot reach the state today
(`ledgr_facts()` refuses duplicate family scopes), so this is defensive code.

### N6 (record-only): interval-only membership compilation costs about 6 ms per instrument

Linear, as claimed: 3.0, 6.0 and 12.3 seconds at 500, 1,000 and 2,000
instruments by 1,000 sessions with two lagged intervals each. Each epoch and
break calls the full canonical resolver on a one-instrument data frame subset.
This is input for LDG-3069, not a defect.

## Item results

| Item | Result |
| --- | --- |
| 1 R1 unsplit bars | PASS. 800 by 1,000: 0.25-0.37 s against 7.5-8.9 s for a split+rbind variant, identical bars; the mock detector kills restored split+rbind |
| 2 R2 treatment detectors | PASS. Chained source refresh (vector and matrix), terminal plane ignoring cutoff, volume guard removed, no source clear and no age clear on an ineligible gap: all fail LTB-0292 |
| 3 R3 ladder rerun | PASS. The label hash `7cd738aaf3d0d12e` equals the SHA-256 of `git diff 38219a66 -- R tests` on the final tree |
| 4 R4 overclaim | PASS. LDG-3060 now calls non-interference structural and routes the proof |
| 5 policy validation | PASS. Strict-policy run, sweep and walk-forward (1 and 2 workers) run; mismatched substrate refuses with `ledgr_invalid_history_substrate` from run and sweep window; every normalize/identity caller supplies a policy; the LTB-0287 oracle change has a stated reason and a valid public-default witness |
| 6 feature bounds | PASS for product; N1 for the detector. Run, run window, sweep, sweep window and walk-forward always pass an exact end; in-window values equal unbounded values, the last scored pulse stays finite, out-of-window cells are NA. Availability sweeps refuse dense precomputed payloads |
| 7 per-instrument segments | PASS. About 2.6 million (observation, knowledge) checks against brute force with the shared resolvers and the prepared provider (knowledge pushed order-preservingly), plus interval-only membership against the canonical resolver: 0 mismatches; detects a start-boundary mutation; linear in instruments |
| 8 membership cursor | PASS for product; N2 and N3 for detectors. 178,794 instrument checks across 300 families and mixed query orders: 0 mismatches; `members_at` equals the resolve view |
| 9 sticky barrier | PASS. 28,926 random (cutoff, columns, instruments) requests against a prefix oracle: 0 mismatches; empty inputs return correct shapes; treatment consumes the barrier; contract wording matches v12 Section 5 |
| 10 civil re-bundle | PASS. Re-bundling is idempotent twice over with stable hashes; detection keys on the package-generated `resolved_ts_utc` field; refusal class sensible; N5 |
| 11 seven shapes | PASS with N4 and N6 noted. Per-instrument loops are linear and stated; header planes are cached between header changes; `terminal_at` prefix materialization has no product caller |
| 12 evidence | PASS. Census regenerates identically; fast records show two warning blocks per run and a clean diagnostic pass exactly as stated; review 357/357 with one skip, heavy 192/192; timings labelled host-loaded |

## Confirmation

Verdict on the third correction round: PASS.

N1-N4 were re-verified on a fresh source copy of the corrected tree. Since
the first pass of this review, the only product change is N4. The rest are
test and record changes.

- N1: LTB-0296 now parses recorded ends with `ledgr_history_utc()`. It
  requires every end to be a fold window end and every training end to be
  present. Passing `meta$end` from the sweep fails LTB-0296 (2 assertions).
- N2: the lagged mixed family in LTB-0291 fails when the
  `header > state$latest_complete` guard is removed (24 assertions). The
  rewind mutation now also fails LTB-0291 (36).
- N3: the complete-set counter counts header advances and expects exactly
  `scaling_n`. Re-advancing every eligible header on each call fails
  LTB-0291 (2).
- N4: `R/backtest-runner.R` calls
  `ledgr_history_identity_require_current(cfg$history)` unconditionally.
  There is no new `availability_active` branch.
- The unmutated copy passes `test-history-substrate.R`,
  `test-history-foundation.R`, `test-availability-provider-production.R` and
  `test-availability-provider-witnesses.R` without failure.
- The census in check mode matches the committed files except for the
  `mode` and `source_commit` labels. Its `38219a66-plus-second-correction`
  label predates this round; record-only. The fold-phase checker, YAML of
  `tickets.yml` and `tests/claims.yml`, and `git diff --check` pass.
- The record text in `tests/claims.yml` (LCL-0288, LCL-0291), `tickets.yml`
  WS41 integration evidence and the closeout accurately describes the
  changes. N5 and N6 stay record-only.
