# R185 - CUT 28 GATE on the cost merge (row review F8)

Demonstrated on the candidate (result.csv). The patch calls
`lean_plan_pulse` with `cost_steps = NULL`, which resolves through
`ledgr_plan_resolve()`. Deletion-readiness seed v2 Section 4.4 deletes that
branch when the resolver carries its compiled steps. Cut 28 reapplies this
remap against the merged resolver, with the same fixture and oracle, and
reruns its witness.
