# Cut 28 design item: test seams into the lean stages

Cut 27 amendment_test_inventory (10) moves this to Cut 28 as an explicit
design item with its own review. LDG-3280 lists it here. Nothing below is
designed or decided.

## The problem

The lean stages E and P1 to P5 are closures inside
`lean_fold_envelope_plain` (dev/lean_core/loop.R), so
`local_mocked_bindings()` cannot reach them. The pin's tests injected faults
and observed values through package-level stage functions
(`ledgr_fold_stage_*`) and the carrier. The harness hooks that reach the
lean stages today (`lean_hooks`, `lean_entry`) retire at the switch
(Cut 27 decision 4). Any seam a test keeps must therefore be designed, not
inherited.

The census (census/census.md, cross-cutting finding 1) names three shapes:
1. test seams at named points inside the lean stages;
2. stage functions at package level, which tests can then mock;
3. injection through a package function the stage calls (`lean_plan_pulse`,
   `lean_lot_fill`, `ledgr_fold_plan_event_kinds`, the cost resolver, the
   output handler at the terminal transfer).

The design has to keep production free of test-only branches on the hot
path (pulse plumbing R3/R4) and must not reintroduce the harness hook seams.
A seam that is not exercised must not let a test pass vacuously.

## The rows

The inventory rows that need an injection or observation point: the 30
rows with handling `a`. R088 and R147 gained the letter in the row review
(F4). Full text is in census/inventory.csv, `target_or_authority`. R028 left
this list: its event-kind refusal is unreachable from public input and
moves to a ledger entry (row review F6, LR-29), so it is a `b,c` row.

Function names are the reference. The `loop.R:N` line numbers in the rows
were taken on cut27-dev and drift by a few lines.

### Mockable package functions after the switch

These rows inject or observe through a function that is top level in a lean
module (shape 3). At the switch it becomes a package function, so
`local_mocked_bindings()` reaches it with no production change (row review
F10).

| row | file | block | needs | function |
| --- | --- | --- | --- | --- |
| R020 | test-corporate-action-recovery.R | [LTB-0055] memory failure discards disposition artifacts | an observation of the failed candidate's in-memory commit | lean_facts_accept (facts.R) |
| R024 | test-diagnostic-decoder.R | [LTB-0554] logical diagnostics own every production read | forcing all-explicit diagnostics at certification | lean_marks_clean (marks.R) |
| R025 | test-diagnostic-decoder.R | [LTB-0556] implicit certification is exact and missing-safe | the direct half: the certification rule with the same controls | lean_marks_clean (marks.R) |
| R041 | test-fill-model.R | next-open proposal and cost resolver preserve intents | capture of P3's first fill batch | lean_plan_pulse (plan.R) |
| R042 | test-fill-model.R | next-open planning consumes the prepared open | observation of the planner's next_open argument | lean_plan_pulse (plan.R) |
| R087 | test-risk-fold.R | [LTB-0281] the b part: plan-batch, fill and rejection field sets | capture of the returned batch | lean_plan_pulse (plan.R) |
| R089 | test-risk-fold.R | [LTB-0137] a failed pulse publishes no partial fills | a second-row failure in P4's candidate computation | lean_lot_fill (fifo.R) |
| R132 | test-ws4a-carrier.R | [WS4a D7] no opening Kahan step (decision (7)) | the opening's compensation steps, with mutants built through `body<-` as the pin's D7 block does | lean_lot_opening (fifo.R) |

### Observation or injection inside a stage closure

These rows need a point inside one of the stage closures of
`lean_fold_envelope_plain`, which no mock reaches today. This is the part
Cut 28 has to design.

| row | file | block | needs |
| --- | --- | --- | --- |
| R009 | test-availability-economics.R | [LTB-0282] exception stages retain baseline labels | a context-build fault inside lean_context |
| R010 | test-availability-economics.R | prepared valuation and linear event growth | an observation of the terminal batch's growth |
| R025 | test-diagnostic-decoder.R | [LTB-0556] implicit certification is exact and missing-safe | the order half: an observation at certification in P4, before terminal expansion |
| R040 | test-fill-model.R | execution packet projects the next bar | an observation of P3's next-bar projection |
| R046 | test-history-integration.R | [LTB-0302] pulse inspection is P1/P2-only | faults in P3, P4 and P5 |
| R086 | test-risk-fold.R | same-pulse fills resolve before events | counts of cost-resolver calls and P4 fill records |
| R087 | test-risk-fold.R | [LTB-0281] the a part: stage order (decision (6)) | an observation of the stage order per pulse |
| R088 | test-risk-fold.R | [LTB-0136] logical commitment per pulse (LR-20) | the committed fill count after each P5 (`n_committed`, an envelope variable that lean_p5_commit writes) |
| R090 | test-risk-fold.R | [LTB-0280] handler faults preserve atomicity | faults in the terminal transfer (first and later batch) |
| R107 | test-strategy-context-projection.R | [LTB-0089] contexts expose only current features | the returned state per decided pulse |
| R108 | test-strategy-context-surface.R | [LTB-0091] authored surface table | the same as R107 |
| R109 | test-strategy-context-surface.R | [LTB-0119] common eligibility planes | the same as R107 |
| R113 | test-strategy-schedule.R | [LTB-0505] skips bypass only decision and plan | per-pulse observation of P1, P4 and P5 and the skip branch |
| R140 | test-ws4a-carrier.R | [WS4a D5 D21] P2 isolation | capture of P2's context and P3's execution inputs |
| R141 | test-ws4a-carrier.R | [WS4a D4] one normalization per decided pulse | a P2 window to count the merged validator's calls |
| R143 | test-ws4a-carrier.R | [WS4a O3.28] the risk plan is validated in E only | a P2 window to count validation calls |
| R147 | test-ws4a-carrier.R | [WS4a F4.27 empty plan] the skip half | that a skipped pulse reconciles against the fold cash, with the +1 mutant injected at P5's skip reconciliation (`expected <- if (is.null(batch)) cash`, lean_p5_commit) |
| R151 | test-ws4a-carrier.R | [WS4a D8] effects computed once | a P3 window to count publication-delta calls |
| R152 | test-ws4a-carrier.R | [WS4a 2.5] reused effects equal both formulas | capture of P3's batch |
| R162 | test-ws4a-carrier.R | [WS4a C13b] a candidate error leaves state unchanged | a NaN fee in P4 and state snapshots at P4 entry and error |
| R168 | test-ws4a-carrier.R | [WS4a W1] P4's write order | probe points and order mutants inside P4 |
| R171 | test-ws4a-carrier.R | [WS4a D10] one equity row per valued pulse | the equity write count, with twice and never variants |
| R172 | test-ws4a-carrier.R | [WS4a F4.49 O3.78] each stop applied once | observation of the stop sites and their rows |
| R191 | test-ws4a-carrier.R | helper ws4a_3168_capture | the P1, stop, P3 and terminal-transfer seams |

A row whose seam stays a source-text anchor instead of a runtime point is a
weakening and needs its own approval (R147's finding).

## What Cut 28 decides

- the seam shape (one of the three above, or another), with its production
  cost and its debug/production split;
- for each row: the seam point, the remapped block, and its demonstration
  that the original registered witness is still rejected (the LDG-3280
  standard: dev/lean_core/parity/remap_demo.R);
- an independent Type 1 review of the convention and the rows before the
  switch run.
