# R147: finding (not mechanical, skip half)

The block [WS4a F4.27 empty plan] has two halves.

The empty-plan half is mechanical. It reaches the planner only through the
helper `ws4b_test_build_pulse_plan`, which is row R194. R194's patch
retargets that helper to `lean_plan_pulse`. The mutation is a FILL kind on an
empty plan.

The skip half is not mechanical:

- It calls `ledgr_fold_scheduled_skip_plan(fold_state, ...)` at runtime and
  checks the returned batch: expected cash equal to the fold cash, no kind,
  no rows.
- It then rebuilds that function with a `+ 1` mutant through `body<-` and
  checks the control fails.

The lean core has no skip-plan object. A skipped pulse passes
`batch = NULL`, and `lean_p5_commit` reconciles it with
`expected <- if (is.null(batch)) cash else batch$expected_final_cash`. That
statement is inside a closure of `lean_fold_envelope_plain`, so a test cannot
call or rebind it.

The inventory's remap ("inject the +1 mutant there") can therefore be only
one of two things:

- a source-text anchor on `lean_p5_commit`. That turns a behavioural check
  (a returned batch compared with the fold cash) into a text check. This
  weakens what the block detects.
- a runtime seam into P5. That belongs to the Cut 28 design item, the
  lean-injection rows and the test-seam convention.

Recommendation: split the row. The empty-plan half follows R194. The skip
half moves to the Cut 28 seam item, as a runtime observation that a skipped
pulse's reconciliation uses the fold cash, with the `+1` mutant injected
through the seam.

## Resolution (row review F4, 2026-11-28)

The row is now a,b. The empty-plan half (b) goes through R194. The skip half
(a) is in cut28_design_item.md, with the +1 mutant injected at P5's skip
reconciliation.
