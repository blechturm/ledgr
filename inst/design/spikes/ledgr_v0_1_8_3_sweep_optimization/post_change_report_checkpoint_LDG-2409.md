# v0.1.8.3 LDG-2409 Projection Checkpoint Report

**Generated:** 2026-05-25T15:49:08Z
**Git HEAD:** `806ef00`
**v0.1.8.2 tag:** `9d8dfc8`

## Purpose

Record interim timing evidence after LDG-2408/LDG-2409 and before the remaining
v0.1.8.3 optimization tickets. This is not the final LDG-2414 post-change
report. It exists to decide whether Fast Context B1 or typed memory events are
the next measured slice.

The workloads are intentionally public-API based and are designed to be rerun
before and after optimization.

## Environment

| label | r_version | platform | os | logical_cores | physical_cores |
| --- | --- | --- | --- | --- | --- |
| post_change | 4.5.2 | x86_64-w64-mingw32 | Windows | 24 | 16 |

## Package Versions

| package | version |
| --- | --- |
| ledgr | 0.1.8.2 |
| pkgload | 1.4.1 |
| testthat | 3.3.1 |
| duckdb | 1.4.3 |
| DBI | 1.2.3 |
| tibble | 3.3.0 |

## Workload Results

| scenario | path | n_candidates | n_instruments | n_days | n_bars | feature_mode | metric_context | reps | median_sec | mean_sec | min_sec | max_sec |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| reference_50_candidates | sweep_plain | 50 | 4 | 252 | 1008 | single | default | 2 | 47.835 | 47.835 | 43.82 | 51.85 |
| reference_50_candidates | precompute | 50 | 4 | 252 | 1008 | single | default | 2 | 0.340 | 0.340 | 0.34 | 0.34 |
| reference_50_candidates | sweep_precomputed | 50 | 4 | 252 | 1008 | single | default | 2 | 43.235 | 43.235 | 43.22 | 43.25 |
| persistent_comparison | sweep_plain | 5 | 4 | 252 | 1008 | single | default | 2 | 4.255 | 4.255 | 4.25 | 4.26 |
| persistent_comparison | run_loop | 5 | 4 | 252 | 1008 | single | default | 2 | 10.420 | 10.420 | 9.45 | 11.39 |

## Interpretation Notes

- Post-change measurements must use the same workload definitions as the baseline.
- Compare this report with `baseline_report.md` before making performance claims.
- If the scoped optimization does not improve the reference workload, document why it still ships or defer/revert the change.
- Checkpoint conclusion: Fast Context B1 should land before typed memory events
  because helper churn remains the dominant measured fold slice after
  projection parity landed.

## LDG-2108B Split Check

LDG-2108B estimated fold-core work at about 64% of measured sweep wall time and post-candidate reconstruction at about 31%-33%. In this v0.1.8.3 baseline Rprof sample, `ledgr_execute_fold()` accounts for about 80.4% of total sampled time on the reference workload.

That means the old phase split should not be treated as current without remeasurement. Fold/context work still dominates, while the direct post-candidate reconstruction share is not reproduced at the same magnitude by this sampling report. LDG-2408/LDG-2409 should therefore use the post-change report to confirm whether summary reconstruction remains the right optimized slice.

## Post-Fold Reconstruction Share

`ledgr_equity_from_events()` accounts for about NA% of sampled reference-workload time, and `ledgr_fills_from_events()` accounts for about 13.7%. Their simple summed share is about 13.7%.

This sum is a diagnostic upper-bound style number, not an additive phase timer: Rprof total percentages can overlap through call stacks. It is still useful as the baseline watch point for LDG-2408 and LDG-2409.

## Profile Top Frames

| profile | frame | total.time | total.pct | self.time | self.pct |
| --- | --- | --- | --- | --- | --- |
| by_total | "withCallingHandlers" | 30.30 | 100.00 | 0.11 | 0.36 |
| by_total | "suppressWarnings" | 30.30 | 100.00 | 0.03 | 0.10 |
| by_total | "ledgr_sweep" | 30.30 | 100.00 | 0.01 | 0.03 |
| by_total | "main" | 30.30 | 100.00 | 0.00 | 0.00 |
| by_total | "profile_reference_workload" | 30.30 | 100.00 | 0.00 | 0.00 |
| by_total | "doTryCatch" | 30.13 | 99.44 | 0.20 | 0.66 |
| by_total | "tryCatchOne" | 30.13 | 99.44 | 0.17 | 0.56 |
| by_total | "tryCatch" | 30.13 | 99.44 | 0.13 | 0.43 |
| by_total | "tryCatchList" | 30.13 | 99.44 | 0.08 | 0.26 |
| by_total | "ledgr_sweep_run_candidate" | 29.94 | 98.81 | 0.00 | 0.00 |
| by_total | "ledgr_execute_fold" | 24.36 | 80.40 | 0.00 | 0.00 |
| by_total | "fn" | 24.22 | 79.93 | 2.06 | 6.80 |
| by_total | "output_handler$run_transaction" | 24.22 | 79.93 | 0.00 | 0.00 |
| by_total | "data.frame" | 9.32 | 30.76 | 1.59 | 5.25 |
| by_total | "ledgr_update_pulse_context_helpers" | 7.98 | 26.34 | 0.09 | 0.30 |
| by_total | "ledgr_attach_feature_helpers" | 6.15 | 20.30 | 0.30 | 0.99 |
| by_total | "as.data.frame" | 5.36 | 17.69 | 0.63 | 2.08 |
| by_total | "ledgr_projection_features_wide" | 4.86 | 16.04 | 0.29 | 0.96 |
| by_total | "ledgr_fills_from_events" | 4.15 | 13.70 | 0.14 | 0.46 |
| by_total | "ledgr_fill_event_row" | 3.73 | 12.31 | 0.11 | 0.36 |
