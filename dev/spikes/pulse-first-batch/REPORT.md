# Pulse-first batched execution: closeout

**Outcome: RED.** Exact outputs passed, but the charter's integration condition
did not: shared pulse-first was not at least 10% faster than strategy-first on
both a common-feature and a stateful varying-feature workload. Retain the
strategy-first engine and pursue only bounded sharing and batching changes.

## What ran

Nine correctness cases passed, and the shared-pulse gut failed C01. The final
record used two warm repetitions for eight serial shapes, up to 1,260 sessions,
500 instruments and 1,000 candidates. Two batching shapes used 1, 2 and 4 R
workers. A public dense `ledgr_sweep()` supplied context, not a cross-engine
speed ranking.

| Case | Shape (sessions x instruments x configs) | Family | naive / strategy | shared / naive | shared / strategy |
| --- | --- | --- | ---: | ---: | ---: |
| S03 | 252 x 100 x 500 | common signal | 1.027 | 0.933 | 0.958 |
| S04 | 252 x 100 x 500 | varying signal | 1.044 | 0.935 | 0.976 |
| S05 | 252 x 100 x 500 | varying stateful | 1.075 | 0.906 | 0.974 |
| S06 | 1,260 x 100 x 100 | common signal | 0.989 | 0.935 | 0.925 |
| S07 | 252 x 500 x 100 | common signal | 0.976 | 0.870 | 0.849 |
| S08 | 252 x 100 x 1,000 | common signal | 1.081 | 0.938 | 1.014 |

Loop ordering itself ranged from essentially neutral to 8% slower at useful
sizes. Sharing eliminated real work: in S03, market-view preparation fell from
126,000 to 252 operations and feature-row extraction from 126,000 to 252. Yet
context creation, strategy calls and portfolio transitions remained 126,000,
so the wall saving was only 6.7%. The wide 500-instrument case was the sole
clear integration-sized win (15.1%). The 1,000-candidate case was still 1.4%
slower overall. The benefit follows slice width, not candidate count alone.

## Memory and batching

Pulse-first must keep every portfolio live. At 500 instruments and 100
candidates, serialized live state was 1.08 MB versus 11 KB for strategy-first;
at 100 instruments and 1,000 candidates it was 2.44 MB versus 2.6 KB. Summary
outputs were identical in size and often larger than live state. Full retention
would widen the state gap, so pulse-first is not a memory optimization.

Batching did remove overhead. For 128 small candidates on two workers, batch 16
took 1.92 s versus 3.97 s for candidate-sized dispatch, but serial batched R was
still 0.82-0.86 s. For 512 stateful candidates, batch 64 took 2.10 s on two
workers and 2.07 s on four, versus 2.89 s serial. Larger batches underused the
workers. Four-worker RSS was roughly 745 MB versus 622 MB for two workers and
gave no material extra speed.

## What this says about ledgr

ledgr already captures the large invariant wins: bars matrices, static pulse
views, feature union/projection and worker-staged history data. In the serial
32-candidate contextual run, 10.50 of 11.36 seconds was candidate-engine time;
snapshot preparation was a separate 0.30 seconds. The profile points to context
refresh, date conversion, validation and fold decision work inside each
candidate, not missing sweep-wide bar preparation.

The spec may consume two bounded follow-ups:

1. cache or share immutable pulse slices where this can be done without
   changing the strategy-first ownership model, prioritizing wide universes;
2. test coarser candidate batches in the existing mirai dispatcher, with a
   minimum-work threshold and memory evidence.

Do not add a pulse-first engine. Open questions are whether production context
refresh can consume a shared immutable pulse token, and whether batching still
wins with ledgr's real task payload and failure semantics.
