# v0.1.8.3 Post-Change Sweep Optimization Report

**Generated:** 2026-05-25T21:09:01Z
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
| reference_50_candidates | sweep_plain | 50 | 4 | 252 | 1008 | single | default | 1 | 20.94 | 20.94 | 20.94 | 20.94 |
| reference_50_candidates | precompute | 50 | 4 | 252 | 1008 | single | default | 1 | 0.39 | 0.39 | 0.39 | 0.39 |
| reference_50_candidates | sweep_precomputed | 50 | 4 | 252 | 1008 | single | default | 1 | 19.97 | 19.97 | 19.97 | 19.97 |
| persistent_comparison | sweep_plain | 5 | 4 | 252 | 1008 | single | default | 1 | 2.39 | 2.39 | 2.39 | 2.39 |
| persistent_comparison | run_loop | 5 | 4 | 252 | 1008 | single | default | 1 | 14.57 | 14.57 | 14.57 | 14.57 |

## Interpretation Notes

- Post-change measurements must use the same workload definitions as the baseline.
- Compare this report with `baseline_report.md` before making performance claims.
- If the scoped optimization does not improve the reference workload, document why it still ships or defer/revert the change.

## LDG-2108B Split Check

LDG-2108B estimated fold-core work at about 64% of measured sweep wall time and post-candidate reconstruction at about 31%-33%. In this v0.1.8.3 Post-Change Rprof sample, `ledgr_execute_fold()` accounts for about 63.1% of total sampled time on the reference workload.

That means the old phase split should not be treated as current without remeasurement. Fold/context work still dominates, while the direct post-candidate reconstruction share is not reproduced at the same magnitude by this sampling report. LDG-2408/LDG-2409 should therefore use the post-change report to confirm whether summary reconstruction remains the right optimized slice.

## Post-Fold Reconstruction Share

`ledgr_equity_from_events()` accounts for about NA% of sampled reference-workload time, and `ledgr_fills_from_events()` accounts for about 28.3%. Their simple summed share is about 28.3%.

This sum is a diagnostic upper-bound style number, not an additive phase timer: Rprof total percentages can overlap through call stacks. It is still useful as the baseline watch point for LDG-2408 and LDG-2409.

## Profile Top Frames

| profile | frame | total.time | total.pct | self.time | self.pct |
| --- | --- | --- | --- | --- | --- |
| by_total | "profile_reference_workload" | 17.09 | 100.00 | 0.01 | 0.06 |
| by_total | "main" | 17.09 | 100.00 | 0.00 | 0.00 |
| by_total | "withCallingHandlers" | 17.08 | 99.94 | 0.10 | 0.59 |
| by_total | "suppressWarnings" | 17.08 | 99.94 | 0.03 | 0.18 |
| by_total | "ledgr_sweep" | 17.08 | 99.94 | 0.00 | 0.00 |
| by_total | "tryCatchOne" | 16.88 | 98.77 | 0.18 | 1.05 |
| by_total | "tryCatch" | 16.88 | 98.77 | 0.15 | 0.88 |
| by_total | "doTryCatch" | 16.88 | 98.77 | 0.11 | 0.64 |
| by_total | "tryCatchList" | 16.88 | 98.77 | 0.07 | 0.41 |
| by_total | "ledgr_sweep_run_candidate" | 16.58 | 97.02 | 0.00 | 0.00 |
| by_total | "ledgr_execute_fold" | 10.79 | 63.14 | 0.00 | 0.00 |
| by_total | "fn" | 9.03 | 52.84 | 1.52 | 8.89 |
| by_total | "output_handler$run_transaction" | 9.03 | 52.84 | 0.00 | 0.00 |
| by_total | "ledgr_fills_from_events" | 4.84 | 28.32 | 0.14 | 0.82 |
| by_total | "data.frame" | 2.88 | 16.85 | 0.39 | 2.28 |
| by_total | "[" | 2.65 | 15.51 | 0.11 | 0.64 |
| by_total | "ledgr_update_fast_pulse_context_helpers" | 2.10 | 12.29 | 0.67 | 3.92 |
| by_total | "lapply" | 1.87 | 10.94 | 0.13 | 0.76 |
| by_total | "as.data.frame" | 1.85 | 10.83 | 0.29 | 1.70 |
| by_total | "FUN" | 1.84 | 10.77 | 0.16 | 0.94 |
