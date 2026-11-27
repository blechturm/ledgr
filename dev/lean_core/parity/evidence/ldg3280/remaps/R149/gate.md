# R149: Cut 28 gate

[WS4a D1 planners] scans a named set of planner functions for banned calls
and allows one named loop for each: `ledgr_cost_model_resolve = "for (step in
steps)"`. The inventory target scans `lean_p3_plan` and the plan.R planners
"plus the merged cost resolve". Deletion-readiness seed v2, Section 4.4,
merges `ledgr_cost_model_resolve()` with `lean_cost_resolve()` into one batch
resolve in R/cost-model.R. It also deletes `ledgr_plan_resolve()`, which is
in the scanned set today. Cut 28 must create that merged function. Its name
and its step loop then become the scanned entry and the allowed loop. Then
the remap is:

- replace `ledgr_fold_stage_plan` with `lean_p3_plan`;
- replace `ledgr_fold_build_availability_pulse_plan` with `lean_plan_pulse`;
- replace `ledgr_plan_groups` with `lean_plan_groups`;
- replace `ledgr_plan_affordability` with `lean_plan_affordability`, whose
  allowed loop stays `for (idx in priority)`;
- replace `ledgr_carrier_execution_view` with `lean_plan_execution_view`,
  whose allowed `.POSIXct` stays;
- replace `ledgr_cost_model_resolve` and `ledgr_plan_resolve` with the
  merged resolve, with its allowed loop;
- add `lean_stage_plan`;
- keep the banned list and the seven injections.

A remap today would have to name `lean_cost_resolve`, a function that Cut 28
replaces.
