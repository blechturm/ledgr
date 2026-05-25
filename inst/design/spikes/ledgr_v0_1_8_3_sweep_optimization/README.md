# ledgr v0.1.8.3 Sweep Optimization Spike

**Status:** Active measurement protocol for LDG-2402.
**Runtime scripts:** `dev/spikes/ledgr_v0_1_8_3_sweep_optimization/`
**Ticket:** `LDG-2402`

## Purpose

This spike records the empirical baseline and comparison protocol for the
v0.1.8.3 single-core sweep optimization cycle.

The protocol is deliberately public-API based. It measures the current sweep
surface before typed memory events and single-pass summary reconstruction land,
then reruns the same workloads after the scoped optimization.

## Workloads

The script-defined workloads are:

- `smoke`: small script-health workload with a persistent run-loop comparison.
- `reference`: 50-candidate EOD workload preserving the LDG-2108A/LDG-2108B
  benchmark lineage.
- `wider`: scaled local wider-feature workload that exercises feature-payload
  behavior without adopting the full parallelism-spike scale.
- `persistent`: explicit committed-run versus sweep comparison workload.
- `metric_context`: non-default metric-context workload proving metric
  assumptions stay threaded through candidate summaries.

## Commands

Run the full baseline:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/spikes/ledgr_v0_1_8_3_sweep_optimization/run_baseline.R
```

Run a quick baseline smoke check:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/spikes/ledgr_v0_1_8_3_sweep_optimization/run_baseline.R --workloads=smoke --profile=false --reps=1
```

Run the post-change comparison after optimization:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/spikes/ledgr_v0_1_8_3_sweep_optimization/run_post_change.R
```

Rebuild the summary report from existing CSV artifacts:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/spikes/ledgr_v0_1_8_3_sweep_optimization/summarize_results.R
```

## Files

- `baseline_report.md`: pre-optimization baseline evidence.
- `post_change_report.md`: post-optimization evidence, created later.
- `residual_hot_path_report.md`: remaining bottlenecks and next-slice
  recommendation, created later.
- `summary_report.md`: compact cross-report summary.
- `data/`: small CSV timing/environment artifacts produced by the scripts.
