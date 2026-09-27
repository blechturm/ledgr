# Strategy Authoring Helpers Closeout

**Status:** Agent-provisional; awaiting independent Type 1 close review.
**Date:** 2026-09-27
**Cut:** 16
**Workstream:** 23
**Tickets:** LDG-2868, LDG-2870 through LDG-2875
**Baseline:** `95936eb`
**Implementation:** `a25fe37..6714454`

## Outcome

The worked strategy no longer needs hand-written workarounds for the gaps that
opened this cut:

- LDG-2868 makes `ledgr_pulse_snapshot()` align supplied positions with current
  closes, include them in equity, accept dense `state_prev`, and print the
  corrected cash, equity, position-count and state-presence summary.
- LDG-2870 adds `ledgr_signal_feature()` as the general registered-feature
  entrance and makes availability masking common to it and
  `ledgr_signal_return()`.
- LDG-2871 makes a short ranking explicit through
  `partial = c("warn", "allow")`, retaining a warning as the default.
- LDG-2872 adds `keep` to `ledgr_target_rebalance()`, reserves kept exposure
  once, and accepts already-held nonmembers named in `keep`.
- LDG-2873 adds `missing = c("error", "exclude")` to the context entrance of
  `ledgr_selection()`, retaining strict refusal as the default.
- LDG-2874 replaces the article's manual NA guards and budget adjustment with
  those helpers, teaches signal -> selection -> weights -> target as a pipe,
  and executes the supplied-state exit branch.
- LDG-2875 records the implementation, its measured cost and the review gate.

The registered detectors are LTB-0094 through LTB-0099, with claims LCL-0094
through LCL-0099.

## Decisions And Boundaries

The maintainer scheduled this cut before the release gate so the final API and
teaching surface are audited once. `keep` lives on the rebalance helper because
that function owns positions, marks, equity and residual-capital sizing; a
post-hoc target edit could preserve quantity but could not undo oversizing.
Held nonmembers named in `keep` are accepted because they are already present
and must have their exposure reserved once.

The snapshot argument is named `cash`, not `initial_cash`, because it describes
cash held alongside the supplied positions. Dense `state_prev` completes the
one-pulse teaching technique. Strict defaults remain binding: incomplete
rankings warn, and missing selection decisions error until the author opts in.

LDG-2869 remains deferred to a later maintenance cut. Alias planes, strategy
scheduling, warning-frequency policy, helpers shared between user strategies,
defaults for absent first-pulse state, handle lifecycle and the remaining
article loops retain the routes named in the Cut 16 entry. This cut changes no
feature value, warm-up rule, experiment identity input or execution engine.

## Shape And Cost

The implementation was walked against the seven optimization shapes. It adds
no one-row frame append, full-table subset loop, elementwise timestamp parse,
per-row JSON loop, quadratic validator, environment-held scalar write, or
production loop over instruments. The new operations are vectorized
`match()`, masks, `union()`, whole-vector replacement and aligned arithmetic.
The retained `order()` is required by ranking and its tie rule.

The walk found one shape-5 issue: `ledgr_signal_feature()` validated a real
context and then delegated to a helper that validated it again. Commit
`6714454` removed the duplicate work, and LTB-0095 now counts one validation.
`canonical_json(state_prev)` runs once when an interactive dense snapshot is
built; it is not in the fold.

Warm helper clocks used fresh R 4.6.1 processes, 505 instruments and 5,000
calls, with three interleaved baseline/final pairs (`95936eb` versus
`6714454`). These are helper clocks, not end-to-end claims.

| Pipeline | Baseline seconds | Final seconds | Median change | 1,260 pulses |
| --- | --- | --- | --- | --- |
| Ranking | 4.63, 4.68, 4.65 | 5.05, 5.00, 5.09 | +0.080 ms/call | about +0.10 s |
| Rule | 1.92, 1.98, 1.89 | 2.47, 2.32, 2.38 | +0.092 ms/call | about +0.12 s |

Checksums were 490 for every ranking run and 404 for every rule run. The rule
comparison is the old explicit NA guards versus `missing = "exclude"`.

## Verification

LTB-0094 through LTB-0099 pin the corrected snapshot, admissibility masking,
partial-ranking policy, kept-position reservation, missing-decision policy and
the executed teaching. The focused strategy, context and documentation suites
pass. Both Quarto articles rendered with executed chunks; their tracked
Markdown is fresh. Help examples for the new helpers execute.

The first final-gate attempt correctly rejected LCL-0099 because the claim said
fast while its file is routed to review. The claim was corrected to the actual
lane. The clean final ordinary fast record at `6714454` contains 470 of 470
passing blocks in 88.140 seconds. Its independent checker passed the
112-second bound:

`C:/tmp/ledgr-ws23-final-fast-6714454`

`git diff --check` is clean. The excluded availability spike and the two GC
artifacts were not read, staged or modified.

## Governance

Three cut reviews plus the requested close review are four invocations over
seven completed tickets, 0.571 against the 0.5 gate. The maintainer accepted
that breach before implementation because the third review materially changed
the public UX. A focused re-review would make the historical ratio 5/7 =
0.714; it must be recorded rather than hidden.

A Type 1 PASS authorizes the maintainer to accept Workstream 23 and Cut 16. It
does not start the release gate.
