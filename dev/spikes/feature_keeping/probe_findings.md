# Feature-keeping pre-charter probe

**Date:** 2026-10-14  
**Tree:** `f262e77a`  
**Status:** executed input; binds nothing

## Question exercised

Does ledgr currently have a sound and usable reason to retain computed feature
values between runs, either in the session feature cache or in the durable
`features` table?

The probe uses only public package construction and result APIs. It creates one
sealed three-instrument snapshot and a custom indicator whose `series_fn`
depends on a captured environment value. Three otherwise identical runs use
capture values 1, 2 and 2. The cache is warm for the second run and explicitly
cleared before the third.

## Observed behavior

| Run | Captured value | Fills | Cache hits | Cache misses |
| --- | ---: | ---: | ---: | ---: |
| cold | 1 | 0 | 0 | 3 |
| warm | 2 | 0 | 3 | 0 |
| cleared | 2 | 3 | 0 | 3 |

The warm run is stale. `ledgr_feature_def_fingerprint()` fingerprints function
bodies with `include_captures = FALSE`, so changing the captured value does not
change the cache key. The cache reports three hits and silently reuses the old
values. Clearing it changes the economic result.

The same run persists feature rows because `persist_features = TRUE`, but
`ledgr_results(bt, "features")` refuses with `ledgr_invalid_result_table` and
directs the caller to `ledgr_pulse_snapshot()` plus the pulse feature readers.
Those readers recompute current pulse-time values; they do not consume the
durable run table. This agrees with the Result Contract's closed result set and
with research finding LFB-028: persisted declared rows are not a coherent
signal-to-selection-to-weight evidence chain.

## Consequence for the spike

The cache still has a real best case: a repeated expensive run in one process.
The spike must measure that benefit, walk-forward retention, an engine-version
key change, same-content snapshots under two IDs, and retained memory. The
captured-value case is a mandatory correctness gate and already fails on the
current implementation.

Persistence has no named public consumer, so it cannot meet the macro plan's
retention condition as implemented. The spike measures its write cost and
confirms output parity, but does not invent a reader or treat LFB-028 as a
reason to keep the current table.

Recorded outputs are `evidence/probe/runs.csv` and
`evidence/probe/feature_reader.txt`. The runnable probe is `probe.R`.
