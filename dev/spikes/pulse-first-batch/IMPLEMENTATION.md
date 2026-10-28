# Implementation and current-sweep analysis

## What ledgr already shares

The public sweep is strategy-first at the fold boundary, but it is not naive.
`ledgr_sweep()` prepares snapshot metadata, bars and candidate feature
definitions before candidate evaluation. Dense bars are converted once to
`bars_mat`; static pulse views are built once; the union of requested features
is computed once; and the runtime feature projection is prepared or sliced
once. Parallel history sweeps remove invariant fields from candidate tasks and
stage that payload once per worker.

The probe traced a two-candidate, six-pulse sweep and observed 12 calls to
`ledgr_fold_stage_decide()`: each candidate still owns a complete fold. That is
the remaining strategy-first seam, not evidence that bars and features are
wholly recomputed per candidate.

| Scope | Current examples | Experimental treatment |
| --- | --- | --- |
| Sweep invariant | snapshot facts, axis, bars matrices, feature union and projection | prepared once in every arm |
| Pulse invariant | one row of open/close data; one row per unique lookback | repeated in both strategy-first and naive pulse-first; shared only in the shared arm |
| Candidate specific | parameters, selected feature row, context wrapper, target | one operation per candidate-pulse |
| Portfolio dependent | cash, positions, pending target, drawdown, fills | isolated mutable environment per candidate |

The current production references are `R/sweep.R:312-423` for feature and bar
preparation, `R/sweep.R:1248-1385` for task construction and worker staging,
and `R/sweep.R:1826-1880` for candidate fold execution.

## The three hypotheses

1. **Loop order:** strategy-first versus naive pulse-first. Both repeat market
   and feature-row lookup, and both receive the same pre-normalized parameter
   lists. This isolates ordering and memory locality.
2. **Shared computation:** naive pulse-first versus shared pulse-first. The
   latter prepares the market view once per pulse and extracts each unique
   feature row once per pulse. Context construction, strategy evaluation and
   accounting remain candidate-specific.
3. **Worker dispatch:** candidate-sized batches versus worker-level batches.
   Each worker receives the prepared invariant once, then traverses all pulses
   for each assigned batch. Workers never synchronize per pulse.

All arms call `pfb_execute_pulse()`. Decisions at close become pending targets,
which fill at the following open; the final session creates no new target.
Thus loop comparisons do not contain independent accounting implementations.

## Measurement boundaries

`generation_sec` and `preparation_sec` precede candidate evaluation. The serial
record separates candidate initialization, the pulse loop and result
collection, and reports explicit work counters. `state_bytes` is the serialized
live state: one portfolio for strategy-first and all portfolios for pulse-first.
The R heap column is R's peak-used statistic after a reset, not process RSS.

Parallel records include daemon initialization, dispatch, wait/collection,
merge, staged serialized bytes and sampled parent-plus-child RSS. On Windows,
every worker is a separate R process; the staged invariant is therefore copied.

The public ledgr context records reusable snapshot creation separately. Its
warm clock begins at `ledgr_sweep()` and materializes the sweep result. For a
serial sweep, candidate-engine and candidate-result sums plus the residual can
be compared with wall time. Under parallelism those candidate sums overlap and
must not be subtracted from wall time.

## Limits

This is a deliberately small accounting subset: dense data, no corporate
actions, no availability changes and one proportional fee. Exact public ledgr
parity is demonstrated only for the constant-target subset. The spike cannot
claim that a replacement loop is ledgr-equivalent, and it proposes none.

The batching harness stages a simplified prepared object, not ledgr's full
history substrate. Its parallel timings answer whether coarser tasks can reduce
R-process dispatch overhead; they are not a drop-in forecast for production.
