# R093 - CUT 28 GATE

The block calls `ledgr:::ledgr_apply_risk_step_max_weight(c(AAA = 50, BBB = 0),
list(args = list(max_weight = 0.1)), list(equity = 0, close = c(AAA = 10,
BBB = NA_real_)))` directly. Deletion-readiness seed v2 Section 4.3 merges it
into the one risk application in R/risk-model.R. The current
`lean_risk_apply` (checks.R) is not that merge: it returns NULL where the
package refuses and leaves the refusals to the pin's path. Cut 28 must
provide the merged risk application with its max_weight step first.

The remap to apply then: the merged entry, called on the max_weight 0.1 step
with the same targets, equity 0 and price vector `c(AAA = 10, BBB = NA)`.
The oracle `c(AAA = 0, BBB = 0)` stays. So does the property this block also
pins: a zero target with an NA close does not refuse (merge rule 3, a
verbatim move). Witness: treating every NA close as invalid, whether or not
the target is zero, must fail the block.
