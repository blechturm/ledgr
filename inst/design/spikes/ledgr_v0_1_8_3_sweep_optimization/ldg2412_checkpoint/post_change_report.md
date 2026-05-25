# v0.1.8.3 Post-Change Sweep Optimization Report

**Generated:** 2026-05-25T21:59:21Z
**Git HEAD:** `ac09d75`
**v0.1.8.2 tag:** `9d8dfc8`

## Purpose

Record reproducible timing evidence for the v0.1.8.3 single-core sweep optimization cycle.
The workloads are intentionally public-API based and are designed to be rerun before and after optimization.

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
| reference_50_candidates | sweep_plain | 50 | 4 | 252 | 1008 | single | default | 2 | 13.220 | 13.220 | 13.13 | 13.31 |
| reference_50_candidates | precompute | 50 | 4 | 252 | 1008 | single | default | 2 | 0.315 | 0.315 | 0.30 | 0.33 |
| reference_50_candidates | sweep_precomputed | 50 | 4 | 252 | 1008 | single | default | 2 | 12.945 | 12.945 | 12.56 | 13.33 |
| wider_feature_payload | sweep_plain | 10 | 12 | 504 | 6048 | wide | default | 2 | 12.130 | 12.130 | 11.59 | 12.67 |
| wider_feature_payload | precompute | 10 | 12 | 504 | 6048 | wide | default | 2 | 0.830 | 0.830 | 0.77 | 0.89 |
| wider_feature_payload | sweep_precomputed | 10 | 12 | 504 | 6048 | wide | default | 2 | 12.055 | 12.055 | 11.59 | 12.52 |
| persistent_comparison | sweep_plain | 5 | 4 | 252 | 1008 | single | default | 2 | 1.350 | 1.350 | 1.32 | 1.38 |
| persistent_comparison | run_loop | 5 | 4 | 252 | 1008 | single | default | 2 | 8.875 | 8.875 | 7.70 | 10.05 |

## Interpretation Notes

- Post-change measurements must use the same workload definitions as the baseline.
- Compare this report with `baseline_report.md` before making performance claims.
- If the scoped optimization does not improve the reference workload, document why it still ships or defer/revert the change.

## LDG-2108B Split Check

LDG-2108B estimated fold-core work at about 64% of measured sweep wall time and post-candidate reconstruction at about 31%-33%. In this v0.1.8.3 Post-Change Rprof sample, `ledgr_execute_fold()` accounts for about 84.6% of total sampled time on the reference workload.

That means the old phase split should not be treated as current without remeasurement. Fold/context work still dominates, while the direct post-candidate reconstruction share is not reproduced at the same magnitude by this sampling report. LDG-2408/LDG-2409 should therefore use the post-change report to confirm whether summary reconstruction remains the right optimized slice.

## Post-Fold Reconstruction Share

The profile did not capture `ledgr_equity_from_events()` or `ledgr_fills_from_events()` in the top sampled frames. Use a targeted phase profile if post-fold reconstruction remains the optimization claim.

## Profile Top Frames

| profile | frame | total.time | total.pct | self.time | self.pct |
| --- | --- | --- | --- | --- | --- |
| by_total | "withCallingHandlers" | 9.85 | 100.00 | 0.07 | 0.71 |
| by_total | "suppressWarnings" | 9.85 | 100.00 | 0.03 | 0.30 |
| by_total | "ledgr_sweep" | 9.85 | 100.00 | 0.00 | 0.00 |
| by_total | "main" | 9.85 | 100.00 | 0.00 | 0.00 |
| by_total | "profile_reference_workload" | 9.85 | 100.00 | 0.00 | 0.00 |
| by_total | "doTryCatch" | 9.67 | 98.17 | 0.15 | 1.52 |
| by_total | "tryCatch" | 9.67 | 98.17 | 0.14 | 1.42 |
| by_total | "tryCatchOne" | 9.67 | 98.17 | 0.10 | 1.02 |
| by_total | "tryCatchList" | 9.67 | 98.17 | 0.07 | 0.71 |
| by_total | "ledgr_sweep_run_candidate" | 9.36 | 95.03 | 0.00 | 0.00 |
| by_total | "ledgr_execute_fold" | 8.33 | 84.57 | 0.00 | 0.00 |
| by_total | "fn" | 7.06 | 71.68 | 0.91 | 9.24 |
| by_total | "output_handler$run_transaction" | 7.06 | 71.68 | 0.00 | 0.00 |
| by_total | "ledgr_update_fast_pulse_context_helpers" | 1.42 | 14.42 | 0.55 | 5.58 |
| by_total | "output_handler$write_fill_events" | 1.34 | 13.60 | 0.01 | 0.10 |
| by_total | "[" | 1.29 | 13.10 | 0.04 | 0.41 |
| by_total | "[.data.frame" | 1.23 | 12.49 | 0.29 | 2.94 |
| by_total | "FUN" | 1.19 | 12.08 | 0.13 | 1.32 |
| by_total | "ledgr_projection_pulse_views" | 1.11 | 11.27 | 0.00 | 0.00 |
| by_total | "ledgr_split_pulse_data_frame" | 1.10 | 11.17 | 0.07 | 0.71 |
