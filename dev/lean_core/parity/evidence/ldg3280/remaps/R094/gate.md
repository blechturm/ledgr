# R094 - CUT 28 GATE

The block compiles `ledgr_risk_max_weight(0.1)` with
`ledgr_risk_plan_compile`, which is retained. It then expects
`ledgr:::ledgr_apply_risk_plan(targets, risk_plan, ctx)` to refuse with
`ledgr_invalid_risk_context` when a nonzero target has an NA close.
Deletion-readiness seed v2 Section 4.3 merges `ledgr_apply_risk_plan` into
one risk application that takes the price vector as an argument and raises
the three `ledgr_invalid_risk_context` refusals in place. Today the
candidate does not raise this refusal itself: `lean_risk_apply` returns NULL
and `lean_risk_targets` hands the case to the pin's `ledgr_apply_risk_plan`.
Cut 28 must provide the merged entry and its signature first.

The remap to apply then: the merged entry, called on the compiled steps with
targets `c(AAA = 1, BBB = 0)`, equity 1000 and prices `c(NA, NA)`. Keep
`class = "ledgr_invalid_risk_context"` unchanged. Witness: removing the
in-place price refusal must fail the block.
