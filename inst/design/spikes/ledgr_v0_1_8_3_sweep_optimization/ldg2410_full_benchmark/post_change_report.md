# v0.1.8.3 Post-Change Sweep Optimization Report

**Generated:** 2026-05-25T21:43:23Z
**Git HEAD:** `01205c1`
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
| smoke_3_candidates | sweep_plain | 3 | 2 | 126 | 252 | single | default | 2 | 0.915 | 0.915 | 0.45 | 1.38 |
| smoke_3_candidates | precompute | 3 | 2 | 126 | 252 | single | default | 2 | 0.080 | 0.080 | 0.05 | 0.11 |
| smoke_3_candidates | sweep_precomputed | 3 | 2 | 126 | 252 | single | default | 2 | 0.490 | 0.490 | 0.47 | 0.51 |
| smoke_3_candidates | run_loop | 3 | 2 | 126 | 252 | single | default | 2 | 4.785 | 4.785 | 3.90 | 5.67 |
| reference_50_candidates | sweep_plain | 50 | 4 | 252 | 1008 | single | default | 2 | 17.330 | 17.330 | 17.31 | 17.35 |
| reference_50_candidates | precompute | 50 | 4 | 252 | 1008 | single | default | 2 | 0.295 | 0.295 | 0.29 | 0.30 |
| reference_50_candidates | sweep_precomputed | 50 | 4 | 252 | 1008 | single | default | 2 | 17.210 | 17.210 | 17.14 | 17.28 |
| wider_feature_payload | sweep_plain | 10 | 12 | 504 | 6048 | wide | default | 2 | 18.125 | 18.125 | 18.00 | 18.25 |
| wider_feature_payload | precompute | 10 | 12 | 504 | 6048 | wide | default | 2 | 0.770 | 0.770 | 0.76 | 0.78 |
| wider_feature_payload | sweep_precomputed | 10 | 12 | 504 | 6048 | wide | default | 2 | 18.630 | 18.630 | 18.60 | 18.66 |
| persistent_comparison | sweep_plain | 5 | 4 | 252 | 1008 | single | default | 2 | 1.835 | 1.835 | 1.83 | 1.84 |
| persistent_comparison | run_loop | 5 | 4 | 252 | 1008 | single | default | 2 | 7.920 | 7.920 | 7.79 | 8.05 |
| metric_context_non_default | sweep_plain | 5 | 4 | 252 | 1008 | single | non_default_us_equity_rf_0.03 | 2 | 1.845 | 1.845 | 1.83 | 1.86 |
| metric_context_non_default | precompute | 5 | 4 | 252 | 1008 | single | non_default_us_equity_rf_0.03 | 2 | 0.115 | 0.115 | 0.11 | 0.12 |
| metric_context_non_default | sweep_precomputed | 5 | 4 | 252 | 1008 | single | non_default_us_equity_rf_0.03 | 2 | 1.870 | 1.870 | 1.87 | 1.87 |

## Interpretation Notes

- Post-change measurements must use the same workload definitions as the baseline.
- Compare this report with `baseline_report.md` before making performance claims.
- If the scoped optimization does not improve the reference workload, document why it still ships or defer/revert the change.

## LDG-2108B Split Check

LDG-2108B estimated fold-core work at about 64% of measured sweep wall time and post-candidate reconstruction at about 31%-33%. In this v0.1.8.3 Post-Change Rprof sample, `ledgr_execute_fold()` accounts for about 63.9% of total sampled time on the reference workload.

That means the old phase split should not be treated as current without remeasurement. Fold/context work still dominates, while the direct post-candidate reconstruction share is not reproduced at the same magnitude by this sampling report. LDG-2408/LDG-2409 should therefore use the post-change report to confirm whether summary reconstruction remains the right optimized slice.

## Post-Fold Reconstruction Share

`ledgr_equity_from_events()` accounts for about NA% of sampled reference-workload time, and `ledgr_fills_from_events()` accounts for about 27%. Their simple summed share is about 27%.

This sum is a diagnostic upper-bound style number, not an additive phase timer: Rprof total percentages can overlap through call stacks. It is still useful as the baseline watch point for LDG-2408 and LDG-2409.

## Profile Top Frames

| profile | frame | total.time | total.pct | self.time | self.pct |
| --- | --- | --- | --- | --- | --- |
| by_total | "withCallingHandlers" | 12.56 | 100.00 | 0.09 | 0.72 |
| by_total | "suppressWarnings" | 12.56 | 100.00 | 0.01 | 0.08 |
| by_total | "ledgr_sweep" | 12.56 | 100.00 | 0.00 | 0.00 |
| by_total | "main" | 12.56 | 100.00 | 0.00 | 0.00 |
| by_total | "profile_reference_workload" | 12.56 | 100.00 | 0.00 | 0.00 |
| by_total | "doTryCatch" | 12.38 | 98.57 | 0.22 | 1.75 |
| by_total | "tryCatch" | 12.38 | 98.57 | 0.20 | 1.59 |
| by_total | "tryCatchOne" | 12.38 | 98.57 | 0.18 | 1.43 |
| by_total | "tryCatchList" | 12.38 | 98.57 | 0.08 | 0.64 |
| by_total | "ledgr_sweep_run_candidate" | 12.18 | 96.97 | 0.01 | 0.08 |
| by_total | "ledgr_execute_fold" | 8.02 | 63.85 | 0.00 | 0.00 |
| by_total | "fn" | 6.79 | 54.06 | 0.69 | 5.49 |
| by_total | "output_handler$run_transaction" | 6.79 | 54.06 | 0.00 | 0.00 |
| by_total | "ledgr_fills_from_events" | 3.39 | 26.99 | 0.12 | 0.96 |
| by_total | "data.frame" | 2.14 | 17.04 | 0.26 | 2.07 |
| by_total | "ledgr_update_fast_pulse_context_helpers" | 1.64 | 13.06 | 0.45 | 3.58 |
| by_total | "as.data.frame" | 1.49 | 11.86 | 0.11 | 0.88 |
| by_total | "[" | 1.48 | 11.78 | 0.06 | 0.48 |
| by_total | "FUN" | 1.27 | 10.11 | 0.18 | 1.43 |
| by_total | "setdiff" | 1.27 | 10.11 | 0.15 | 1.19 |
