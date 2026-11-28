# R087 - CUT 28 GATE (the b part; row review F5)

Block: test-risk-fold.R "[LTB-0281] the envelope calls five typed stage
packets in order". Decision (6) splits it: the stage order is an a part (the
Cut 28 design item), the observe, decide, apply and commit packet field sets
retire (c), and the plan-batch, fill and rejection field sets stay (this b
part).

The b part captures the batch the planner returns inside a running fold. The
pin wraps `ledgr_fold_stage_plan` with `local_mocked_bindings()`. On lean the
batch comes from `lean_plan_pulse` (plan.R), called by `lean_p3_plan`. Today
that function lives in the candidate environment, which
`local_mocked_bindings(.package = "ledgr")` does not reach. A direct call
would replace the block's three-pulse fold fixture with a new one, which is
not a remap. So this part is shown at Cut 28, once `lean_plan_pulse` is a
package function.

The remap to apply then: wrap `lean_plan_pulse` with the block's own capture
function, keep the fold run and its fixture, take the last returned batch,
and keep the four frozen name lists (`names(batch)`, `names(batch$fill)`,
`names(batch$rejection)`) unchanged. plan.R's `lean_plan_result` and
`lean_plan_groups` already build these names. Witness: renaming one fill
field in `lean_plan_groups` must fail the block.
