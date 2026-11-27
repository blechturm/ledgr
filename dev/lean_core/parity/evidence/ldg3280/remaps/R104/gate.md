# R104 - CUT 28 GATE

The block calls `ledgr:::ledgr_validate_strategy_targets(targets, c("AAA",
"BBB"))` directly. It also calls the kept `ledgr_signal_strategy` and
`ledgr_pulse_context`. Deletion-readiness seed v2 Section 4.1 merges the
validator with `lean_targets` (checks.R): the lean accept paths become its
first branch, and the axis predicate becomes an optional argument. The
current function is the pin's unmerged validator, and the merged signature
is set in Cut 28. Cut 28 must provide the merged validator first.

The remap to apply then: if the merged signature keeps `(targets, universe)`
as its leading arguments, the call stays as it is. Otherwise only the call
site is updated (the universe is passed positionally or by its new name).
Inputs, expected values and refusal classes are unchanged.
