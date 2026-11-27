# R175 - CUT 28 GATE

helper-fixtures.R `ledgr_test_next_open_fill` calls two fold-carrier
functions. `ledgr_plan_groups` maps mechanically today to `lean_plan_groups`
(plan.R), which has the same signature and field set. `ledgr_plan_resolve`
does not: deletion-readiness seed v2 Section 4.4 deletes it and merges
`ledgr_cost_model_resolve` with `lean_cost_resolve` into one batch resolve in
R/cost-model.R that runs on steps the resolver carries. Cut 28 must provide
that merged resolve and its signature first. It must also decide whether
`ledgr_plan_refuse_inputs` (fold-engine.R, which only this helper reaches)
stays in R/. If it moves, its refusal order must move with it, because the
input refusals in test-fill-model.R depend on it.

The remap to apply then:
- `ledgr:::ledgr_plan_groups(...)` becomes `ledgr:::lean_plan_groups(...)`
  with the same arguments (after the switch it may be renamed in R/);
- `ledgr:::ledgr_plan_resolve(resolver, side, qty, open)` becomes the merged
  resolve, called on the steps of the same `ledgr_cost_resolver_from_model()`
  resolver;
- the effects from `ledgr_fill_publication_deltas` stay as they are.

Inventory issue found here, which applies beyond this row: the planner
helpers that rows R180 (`availability_plan`) and R185
(`ledgr_test_dense_plan`) remap to `lean_plan_pulse` also reach
`ledgr_plan_resolve`. They get there through `lean_plan_pulse`'s
`cost_steps = NULL` branch (plan.R), the dead non-package-resolver branch
that deletion-readiness 4.4 deletes. Their demonstrated remaps hold only
until that deletion, so their resolver argument follows this gate. R180's
fixture resolver is a closure that leaves prices unrounded, so the merged
resolve must either still accept a resolver closure or R180 becomes a
fixture finding at Cut 28.

Evidence required: the returned fill group is `identical()` to the pin's for
every fixture call at the 41 call sites, so the oracles of the dependent
blocks are untouched.
