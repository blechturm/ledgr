# Pulse-first batched execution spike

This spike asks one question: can ledgr improve dense-sweep throughput by
sharing the remaining per-pulse work across candidates, without introducing a
second execution engine?

The cheaper prerequisite is exact semantic parity between loop orders while
using one strategy and accounting implementation. Nine correctness cases cover
next-open execution, fees, stateful strategies, batch partitions, workers,
candidate isolation and a minimal public `ledgr_run()` comparison.

The kill condition is: do not recommend pulse-first integration unless the
shared arm preserves exact outputs and is at least 10% faster than
strategy-first on both a common-feature case and a stateful varying-feature
case. The recorded result hits neither half of that performance condition.

## Reproduce

From the ledgr repository root:

```powershell
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" `
  dev/spikes/pulse-first-batch/spike_runner.R `
  --preset smoke `
  --output C:/tmp/pulse-first-smoke `
  --repo .

& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" `
  dev/spikes/pulse-first-batch/spike_checker.R `
  --repo . `
  --record dev/spikes/pulse-first-batch/results/windows-r4.6.1
```

The registered record used `--preset record`; it takes roughly five minutes on
the recorded Windows host. It covers representative, not Cartesian, points of
the requested 252/1,260-session, 10/100/500-instrument and
10/100/500/1,000-candidate ranges.

## Evidence

- `results/windows-r4.6.1/correctness.csv`: normal fork, all cases pass.
- `results/windows-r4.6.1/gutted_correctness.csv`: the shared-pulse mutation is
  detected by C01.
- `serial_benchmarks.csv`: loop-order and shared-work arms.
- `parallel_benchmarks.csv`: worker and batch-size arms.
- `ledgr_baseline.csv`: public `ledgr_sweep()` context, with cold snapshot
  preparation separate from warm sweep wall time.
- `*_profile.csv`: sampling profiles; percentages are useful, but Windows
  sampling resolution makes their absolute totals non-binding.

The standalone harness retains summary results for timing. The correctness
lane uses full per-session cash, positions, equity and fills. All loop variants
use the same target and portfolio-transition functions.
