PASS
Mode: focused Type 2 re-review 2 of Cut 26 revision 3, 4a9ac70f; scope is S1 and contradictions introduced by its correction. R1-R10 and accepted choices are not reopened.

**Role:** record
**Status:** accepted
**Authority:** Non-binding review record. Its disposition is recorded in Cut 26 cut_review in tickets.yml.
S1. Applied faithfully and completely: inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:9124 matches re-review 1's exact replacement text; :4608 records the finding and its correction.

No new findings.

The revised acceptance agrees with decision 3 at inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:4422-4447. It distinguishes the public durable-run refusal and the upstream availability refusal from the E-stage candidate refusals. The availability refusal escapes for either stop_on_error value and produces no candidate row; reachable E-stage refusals require both candidate-row and escaping-condition evidence. The handler-capability and non-buffered predicates retain the direct-boundary or documented-unreachability/source-comparison alternative. Decision 3's general instruction to exercise both error forms is read within these stated reachability boundaries.

This agrees with the read-only pin: C:/Users/maxth/ledgr-wt/pin-src-d5b3a151/R/sweep.R:178 refuses before worker setup, while :1505 handles candidate errors; R/backtest.R:154 refuses committed selected runs at entry; R/fold-engine.R:1741 retains the E admission helpers. The preparation-time boundary is also specified by inst/design/contracts.md:1359 (contract-availability-targets).

The replacement retains the omitted-dispatch mutation, successful native-dispatch observation, earliest-overflow/competing-failure coverage, and lowered-limit P5 capacity proof at both batch bounds. It introduces no contradiction with LDG-3272's other acceptance items or the related worker and close obligations.

Checked the d5c0b629-to-4a9ac70f tickets.yml diff, exact replacement equality, decision 3 and related acceptance items. HEAD verified as 4a9ac70ff7427bd5df9158ec698ead0482f29487; tracked worktree clean. No R was run, no tracked file edited and no commit made. This report is the only file written by this review.
