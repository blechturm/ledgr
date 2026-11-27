# R118 - CUT 28 GATE

The block calls `ledgr:::ledgr_validate_strategy_targets(target, universe)`
on a `ledgr_target` and expects the unwrapped values. It also expects the
refusals for `ledgr_signal` and `ledgr_weights` inputs. Deletion-readiness
seed v2 Section 4.1 folds the unwrap step into the merged strategy-target
validator (with `lean_targets`, checks.R). That happens in Cut 28. Cut 28
must provide the merged validator first.

The remap to apply then: if the merged signature keeps `(targets, universe)`,
the calls stay as they are. Otherwise only the call sites are updated. No
test names the unwrap step, so nothing else moves. The expected values and
classes are unchanged.
