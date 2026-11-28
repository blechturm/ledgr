# R091 - CUT 28 GATE (row review F5)

Block: test-risk-fold.R "long-only risk step leaves compliant targets
unchanged". It calls `ledgr:::ledgr_apply_risk_step_long_only()` directly.
Deletion-readiness seed v2 Section 4.3 merges that function, with the other
risk steps, into one risk application in R/risk-model.R, as for its siblings
R092 to R094. The merged signature does not exist yet.

The remap to apply then: call the merged entry's long-only step on the same
non-negative targets and keep the oracle (targets unchanged). If Cut 28 keeps
the function and its signature, the block is unchanged. Witness: a long-only
step that also zeroes positive targets must fail the block.
