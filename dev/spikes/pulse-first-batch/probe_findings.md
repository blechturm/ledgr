# Probe Findings

The public two-candidate, six-session dense sweep completed both candidates
and entered `ledgr_fold_stage_decide()` 12 times: exactly once per candidate
and pulse. The sweep therefore remains strategy-first at the fold boundary.

This does not mean that all market work is repeated. Source inspection after
the probe found that `ledgr_sweep_impl()` prepares the snapshot, `bars_mat`,
static bar views, the feature union and the runtime projection before it builds
candidate tasks. Parallel sweeps stage those invariant fields once per worker.
Each candidate nevertheless constructs its own fold execution, context,
strategy result, pulse plan, accounting transitions and retained result.

The concrete opportunity is narrower than "share the market": test whether a
pulse-first loop can reuse the already-prepared pulse slice and reduce repeated
context/index work without sharing mutable portfolio state. The prerequisite
is exact equality between two loop orders using one accounting function. The
spike stops short of an integration recommendation if equality fails or if the
optimized pulse-first loop does not improve both representative strategy
families by at least 10 percent at 100 or more configurations under identical
retention.
