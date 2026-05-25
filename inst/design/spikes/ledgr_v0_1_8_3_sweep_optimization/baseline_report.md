# v0.1.8.3 Baseline Sweep Optimization Report

**Generated:** 2026-05-25T11:06:44Z
**Git HEAD:** `f5b49d4`
**v0.1.8.2 tag:** `9d8dfc8`

## Purpose

Record reproducible timing evidence for the v0.1.8.3 single-core sweep optimization cycle.
The workloads are intentionally public-API based and are designed to be rerun before and after optimization.

## Environment

| label | r_version | platform | os | logical_cores | physical_cores |
| --- | --- | --- | --- | --- | --- |
| baseline | 4.5.2 | x86_64-w64-mingw32 | Windows | 24 | 16 |

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
| smoke_3_candidates | sweep_plain | 3 | 2 | 126 | 252 | single | default | 2 | 1.320 | 1.320 | 0.97 | 1.67 |
| smoke_3_candidates | precompute | 3 | 2 | 126 | 252 | single | default | 2 | 0.085 | 0.085 | 0.06 | 0.11 |
| smoke_3_candidates | sweep_precomputed | 3 | 2 | 126 | 252 | single | default | 2 | 1.000 | 1.000 | 0.98 | 1.02 |
| smoke_3_candidates | run_loop | 3 | 2 | 126 | 252 | single | default | 2 | 5.245 | 5.245 | 4.45 | 6.04 |
| reference_50_candidates | sweep_plain | 50 | 4 | 252 | 1008 | single | default | 2 | 45.585 | 45.585 | 45.44 | 45.73 |
| reference_50_candidates | precompute | 50 | 4 | 252 | 1008 | single | default | 2 | 0.280 | 0.280 | 0.28 | 0.28 |
| reference_50_candidates | sweep_precomputed | 50 | 4 | 252 | 1008 | single | default | 2 | 45.490 | 45.490 | 45.25 | 45.73 |
| wider_feature_payload | sweep_plain | 10 | 12 | 504 | 6048 | wide | default | 2 | 65.360 | 65.360 | 65.33 | 65.39 |
| wider_feature_payload | precompute | 10 | 12 | 504 | 6048 | wide | default | 2 | 0.785 | 0.785 | 0.78 | 0.79 |
| wider_feature_payload | sweep_precomputed | 10 | 12 | 504 | 6048 | wide | default | 2 | 65.345 | 65.345 | 65.13 | 65.56 |
| persistent_comparison | sweep_plain | 5 | 4 | 252 | 1008 | single | default | 2 | 4.415 | 4.415 | 4.32 | 4.51 |
| persistent_comparison | run_loop | 5 | 4 | 252 | 1008 | single | default | 2 | 9.420 | 9.420 | 9.42 | 9.42 |
| metric_context_non_default | sweep_plain | 5 | 4 | 252 | 1008 | single | non_default_us_equity_rf_0.03 | 2 | 4.350 | 4.350 | 4.28 | 4.42 |
| metric_context_non_default | precompute | 5 | 4 | 252 | 1008 | single | non_default_us_equity_rf_0.03 | 2 | 0.090 | 0.090 | 0.09 | 0.09 |
| metric_context_non_default | sweep_precomputed | 5 | 4 | 252 | 1008 | single | non_default_us_equity_rf_0.03 | 2 | 4.315 | 4.315 | 4.30 | 4.33 |

## Interpretation Notes

- Baseline is measured after the v0.1.8.2 release on the v0.1.8.3 planning branch.
- No v0.1.8.3 runtime optimization has landed before this baseline.
- The reference_50_candidates workload preserves the LDG-2108A/LDG-2108B benchmark lineage.
- The wider_feature_payload workload is a scaled local variant intended to expose wider feature-payload behavior without adopting the full parallelism-spike scale.

## LDG-2108B Split Check

LDG-2108B estimated fold-core work at about 64% of measured sweep wall time and post-candidate reconstruction at about 31%-33%. In this v0.1.8.3 baseline Rprof sample, `ledgr_execute_fold()` accounts for about 79.8% of total sampled time on the reference workload.

That means the old phase split should not be treated as current without remeasurement. Fold/context work still dominates, while the direct post-candidate reconstruction share is not reproduced at the same magnitude by this sampling report. LDG-2408/LDG-2409 should therefore use the post-change report to confirm whether summary reconstruction remains the right optimized slice.

## Post-Fold Reconstruction Share

The profile did not capture `ledgr_equity_from_events()` or `ledgr_fills_from_events()` in the top sampled frames. Use a targeted phase profile if post-fold reconstruction remains the optimization claim.

## Profile Top Frames

| profile | frame | total.time | total.pct | self.time | self.pct |
| --- | --- | --- | --- | --- | --- |
| by_total | "main" | 34.82 | 100.00 | 0.00 | 0.00 |
| by_total | "profile_reference_workload" | 34.82 | 100.00 | 0.00 | 0.00 |
| by_total | "withCallingHandlers" | 34.81 | 99.97 | 0.07 | 0.20 |
| by_total | "suppressWarnings" | 34.81 | 99.97 | 0.03 | 0.09 |
| by_total | "ledgr_sweep" | 34.81 | 99.97 | 0.00 | 0.00 |
| by_total | "tryCatchOne" | 34.68 | 99.60 | 0.18 | 0.52 |
| by_total | "tryCatch" | 34.68 | 99.60 | 0.17 | 0.49 |
| by_total | "doTryCatch" | 34.68 | 99.60 | 0.15 | 0.43 |
| by_total | "tryCatchList" | 34.68 | 99.60 | 0.09 | 0.26 |
| by_total | "ledgr_sweep_run_candidate" | 33.49 | 96.18 | 0.00 | 0.00 |
| by_total | "ledgr_execute_fold" | 27.78 | 79.78 | 0.00 | 0.00 |
| by_total | "fn" | 27.62 | 79.32 | 2.68 | 7.70 |
| by_total | "output_handler$run_transaction" | 27.62 | 79.32 | 0.00 | 0.00 |
| by_total | "ledgr_update_pulse_context_helpers" | 10.59 | 30.41 | 0.12 | 0.34 |
| by_total | "ledgr_attach_feature_helpers" | 9.00 | 25.85 | 0.08 | 0.23 |
| by_total | "data.frame" | 8.34 | 23.95 | 1.63 | 4.68 |
| by_total | "ledgr_features_wide" | 7.78 | 22.34 | 0.36 | 1.03 |
| by_total | "vapply" | 5.71 | 16.40 | 0.40 | 1.15 |
| by_total | "FUN" | 5.19 | 14.91 | 0.57 | 1.64 |
| by_total | "as.data.frame" | 4.58 | 13.15 | 0.51 | 1.46 |
