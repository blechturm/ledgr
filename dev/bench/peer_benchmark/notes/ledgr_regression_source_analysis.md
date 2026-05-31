# ledgr Peer Benchmark Regression Source Analysis

Created: 2026-05-31  
Scope: LDG-2476 follow-up investigation after the 500 x 1260 scale check

This note explains why the current peer benchmark looked like a large ledgr
regression against the v0.1.8.7 closeout row.

## Finding

The apparent 9x ledgr regression is primarily a workload mismatch, not a broad
fold-core regression.

The old v0.1.8.7/current-source matched row used the shared
`peer_sma_crossover` workload:

- 500 instruments x 1260 bars
- SMA 20/50 continuous target semantics
- 13,355 fills
- current-source rerun wall: 30.75s
- current-source rerun loop: 18.89s

The current apples-to-apples peer record used a different workload:

- 500 instruments x 1260 bars
- SMA 5/10 crossover-event semantics
- 68,324 fills
- ledgr_ttr_canonical reported core: 240.64s

That is about 5.1x more fills/events. The old and new rows were not measuring
the same turnover pressure.

## Current-Source A/B

Diagnostic artifacts:

- `dev/bench/results/ledgr_regression_continuous_20260531T101455Z.csv`
- `dev/bench/results/ledgr_regression_continuous_20_50_20260531T101945Z.csv`
- `dev/bench/results/ledgr_regression_ab_20260531T100925Z_current_state_update.duckdb`

| Row | Shape | Strategy | Fills | Run s | t_loop s | Fills extract s | Strategy-state rows | State JSON bytes |
| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| old-shape rerun | 500 x 1260 | SMA 20/50 continuous target | 13,355 | 31.60 | 20.14 | 6.75 | 0 | 0 |
| current peer no-state control | 500 x 1260 | SMA 5/10 continuous target | 68,324 | 138.33 | 121.85 | 82.28 | 0 | 0 |
| current peer stateful crossover | 500 x 1260 | SMA 5/10 crossover with `state_update` | 68,324 | 153.67 | not extracted in CSV | not extracted in CSV | 1,260 | 10,281,316 |

Interpretation:

- Re-running the old-shape style on current source lands at 31.60s, matching
  the 30.75s current-source row in the closeout. That rules out a broad
  fold-core regression for the historical workload.
- Moving from SMA 20/50 to SMA 5/10 raises fills from 13,355 to 68,324 and
  raises loop time from about 20s to about 122s. The hot cost scales with
  event/fill turnover.
- `state_update` adds real overhead, but it is not the dominant factor in the
  large result. The stateful crossover run wrote 1,260 strategy-state rows and
  about 10.3 MB of state JSON; its run time was 153.67s versus 138.33s for the
  5/10 no-state continuous control.
- The peer benchmark's reported core includes fill materialization. On the
  5/10 control, `ledgr_results(bt, "fills")` alone took 82.28s for 68,324
  fills. That is outside the fold loop but inside the current peer harness
  boundary.

## Conclusion

The regression is not "fold core got 9x slower." The largest causes are:

1. The benchmark changed from the old 20/50 continuous-target workload to a
   much higher-turnover 5/10 crossover-event workload.
2. The current peer harness includes canonical fills extraction in the reported
   core boundary; that read-back is expensive at 68k fills.
3. Persisted crossover `state_update` adds measurable overhead, but it is a
   secondary cost relative to fill/event turnover and fills reconstruction.

The actionable performance lanes are therefore event/fill throughput and
fills read-back reconstruction, not the generic pulse fold loop.

## Optimization Targets Revealed

Ordered by current evidence and likely impact:

1. **Fills read-back reconstruction.** `ledgr_results(bt, "fills")` took 6.75s
   for 13,355 fills and 82.28s for 68,324 fills. That is worse than linear
   scaling and is the clearest post-run bottleneck exposed by this analysis.
2. **Fill/event throughput during the run.** Moving from 13,355 to 68,324 fills
   raised fold-loop time from about 20s to about 122s. The run path is strongly
   fill-volume sensitive.
3. **Data ingestion and snapshot creation.** Snapshot creation for the 500 x
   1260 shape is about 12s before the fold starts. The peer benchmark's
   boundary correctly includes this ingestion cost, so CSV parsing, validation,
   DuckDB insert, sealing, and hash work are visible optimization targets.
4. **Strategy-state persistence.** The crossover `state_update` path wrote
   1,260 rows and about 10.3 MB of JSON. It added measurable overhead, but it is
   secondary to fill/event volume and fills read-back on this workload.
5. **Target/state vector copying.** The benchmark strategy is vectorized now,
   but the engine still scans target vectors, computes deltas, and carries named
   state/position surfaces every pulse. This is a lower-confidence target than
   fill reconstruction and event throughput, but it is consistent with the
   previous fold-loop diagnostics.

Feature precompute is not a lead target on this SMA workload: `t_pre` remains
around 0.9s in the old-shape and no-state control rows.
