# R117 - CUT 28 GATE

The block calls `ledgr:::ledgr_strategy_state_apply_values(previous, update,
declaration, axis, patch)` five times, on states from the retained
`ledgr_strategy_state_defaults`. Deletion-readiness seed v2 Section 4.5
merges `ledgr_strategy_state_apply_values` with `lean_state_apply`'s patch
path, `ledgr_strategy_state_field` and `ledgr_strategy_state_validate_value`
into one state apply. That happens in Cut 28, so its signature does not
exist yet. Cut 28 must provide the merged state apply first.

The remap to apply then: if the merged signature keeps
`(previous, update, declaration, axis, patch)`, the calls stay as they are.
Otherwise only the call sites are updated. The distinction between a helper
patch and a raw replacement, and the expected states and refusals, are
unchanged.
