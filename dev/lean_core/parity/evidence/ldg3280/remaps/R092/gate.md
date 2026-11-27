# R092 - CUT 28 GATE

The block calls `ledgr:::ledgr_apply_risk_step_max_weight(c(AAA = -50),
list(args = list(max_weight = 0.1)), list(equity = 1000, close = c(AAA = 10)))`
directly. Deletion-readiness seed v2 Section 4.3 merges that function, with
`ledgr_apply_risk_plan` and the other step functions, into one risk
application in R/risk-model.R (steps compiled once by `lean_risk_steps`,
applied per pulse, prices passed as an argument). The current candidate
function is not that merge: `lean_risk_apply` (checks.R) returns NULL where
the package refuses, and `lean_risk_targets` then falls back to the pin. So
the merged signature does not exist yet. Cut 28 must provide the merged risk
application with its max_weight step first.

The remap to apply then: call the merged entry on the steps compiled from
`ledgr_risk_max_weight(0.1)`, with targets `c(AAA = -50)`, equity 1000 and
the price vector `c(AAA = 10)`. Keep `expect_equal(out, c(AAA = -10))`. If
the merged function returns plain doubles in axis order, re-attach the
instrument names at the call site and only there. The oracle does not
change. Witness: dropping `sign(out[nz]) *` from the cap line must fail the
block.
