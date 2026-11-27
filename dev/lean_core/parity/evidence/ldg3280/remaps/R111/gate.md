# R111 - CUT 28 GATE

The block calls `ledgr:::ledgr_validate_strategy_targets(x, universe)` four
times:
- a valid, reordered vector;
- unnamed;
- an extra name;
- a non-finite value.

These are R3 refusal witnesses that deletion-readiness seed v2 Section 4.1
says the merged strategy-target validator must keep verbatim. The merge
(with `lean_targets`, checks.R) happens in Cut 28, so its signature does not
exist yet. Cut 28 must provide the merged validator first.

The remap to apply then: if the merged signature keeps `(targets, universe)`
as its leading arguments, the four calls stay as they are. Otherwise only the
call sites are updated. The messages and classes are unchanged.
