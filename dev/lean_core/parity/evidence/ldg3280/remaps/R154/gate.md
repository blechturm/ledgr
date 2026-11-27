# R154: Cut 28 gate

[WS4a D24] "the execution view is called only from P3" sources
`tools/check-fold-phase-contract.R` and asserts on its
`ledgr_fold_phase_source_findings()`: no `ledgr_carrier_execution_view`
finding over R/, and a finding once a call is injected into P4. Amendment (5)
rebuilds that checker in Cut 28 on the lean stages' read and write sets
(stage_state.R), with an allowed-writes table. Cut 28 must provide the
rebuilt checker and its stage-name map, which must name `lean_p3_plan` and
`lean_p4_apply` instead of `ledgr_fold_stage_plan` and
`ledgr_fold_stage_apply`. Then the remap is: run the rebuilt checker's
findings over R/ for the production adapter `lean_plan_execution_view` (lean
P3 calls `ledgr_carrier_execution_view` only as its debug reference,
loop.R:819-824); assert that `lean_p3_plan` calls the adapter; and inject the
same call into `lean_p4_apply` as the control, which must produce a finding.
Until the checker exists, this remap cannot be written.
