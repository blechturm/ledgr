# R106 - CUT 28 GATE

The block calls `ledgr:::ledgr_validate_strategy_targets(numeric(), "AAA",
allow_empty = TRUE)` and `(stats::setNames(numeric(), character()),
character(), allow_empty = TRUE)`. These are the empty-axis F3 cases that
deletion-readiness seed v2 Section 4.1 requires the merged validator to keep.
The validator is merged with `lean_targets` in Cut 28, and whether the merge
keeps the `allow_empty` argument is decided there. Cut 28 must provide the
merged validator first.

The remap to apply then: if `allow_empty` survives, the calls stay as they
are. Otherwise only the call site changes, to the merged way of selecting the
empty-axis behaviour. The two expected outcomes and the
`ledgr_validate_pulse_context` half stay as they are.
