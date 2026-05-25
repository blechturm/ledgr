# v0.1.8.3 Post-Change Sweep Optimization Report

**Generated:** 2026-05-25T20:42:05Z
**Git HEAD:** `e1820d7`
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
| smoke_3_candidates | sweep_plain | 3 | 2 | 126 | 252 | single | default | 2 | 1.190 | 1.190 | 0.77 | 1.61 |
| smoke_3_candidates | precompute | 3 | 2 | 126 | 252 | single | default | 2 | 0.100 | 0.100 | 0.06 | 0.14 |
| smoke_3_candidates | sweep_precomputed | 3 | 2 | 126 | 252 | single | default | 2 | 0.680 | 0.680 | 0.61 | 0.75 |
| smoke_3_candidates | run_loop | 3 | 2 | 126 | 252 | single | default | 2 | 5.440 | 5.440 | 4.44 | 6.44 |
| reference_50_candidates | sweep_plain | 50 | 4 | 252 | 1008 | single | default | 2 | 30.275 | 30.275 | 29.74 | 30.81 |
| reference_50_candidates | precompute | 50 | 4 | 252 | 1008 | single | default | 2 | 0.310 | 0.310 | 0.31 | 0.31 |
| reference_50_candidates | sweep_precomputed | 50 | 4 | 252 | 1008 | single | default | 2 | 30.525 | 30.525 | 30.00 | 31.05 |
| wider_feature_payload | sweep_plain | 10 | 12 | 504 | 6048 | wide | default | 2 | 33.405 | 33.405 | 33.06 | 33.75 |
| wider_feature_payload | precompute | 10 | 12 | 504 | 6048 | wide | default | 2 | 0.910 | 0.910 | 0.84 | 0.98 |
| wider_feature_payload | sweep_precomputed | 10 | 12 | 504 | 6048 | wide | default | 2 | 33.100 | 33.100 | 32.89 | 33.31 |
| persistent_comparison | sweep_plain | 5 | 4 | 252 | 1008 | single | default | 2 | 3.025 | 3.025 | 2.91 | 3.14 |
| persistent_comparison | run_loop | 5 | 4 | 252 | 1008 | single | default | 2 | 8.650 | 8.650 | 8.57 | 8.73 |
| metric_context_non_default | sweep_plain | 5 | 4 | 252 | 1008 | single | non_default_us_equity_rf_0.03 | 2 | 3.010 | 3.010 | 2.76 | 3.26 |
| metric_context_non_default | precompute | 5 | 4 | 252 | 1008 | single | non_default_us_equity_rf_0.03 | 2 | 0.135 | 0.135 | 0.13 | 0.14 |
| metric_context_non_default | sweep_precomputed | 5 | 4 | 252 | 1008 | single | non_default_us_equity_rf_0.03 | 2 | 3.300 | 3.300 | 3.08 | 3.52 |

## Baseline Comparison

| workload | path | baseline | post-change | result |
| --- | --- | ---: | ---: | ---: |
| smoke_3_candidates | sweep_plain | 1.320s | 1.190s | 1.11x faster |
| smoke_3_candidates | sweep_precomputed | 1.000s | 0.680s | 1.47x faster |
| smoke_3_candidates | run_loop | 5.245s | 5.440s | 3.7% slower |
| reference_50_candidates | sweep_plain | 45.585s | 30.275s | 1.51x faster |
| reference_50_candidates | sweep_precomputed | 45.490s | 30.525s | 1.49x faster |
| wider_feature_payload | sweep_plain | 65.360s | 33.405s | 1.96x faster |
| wider_feature_payload | sweep_precomputed | 65.345s | 33.100s | 1.97x faster |
| persistent_comparison | sweep_plain | 4.415s | 3.025s | 1.46x faster |
| persistent_comparison | run_loop | 9.420s | 8.650s | 1.09x faster |
| metric_context_non_default | sweep_plain | 4.350s | 3.010s | 1.45x faster |
| metric_context_non_default | sweep_precomputed | 4.315s | 3.300s | 1.31x faster |

## Pulse-View Object-Size Evidence

Measured with `dev/spikes/ledgr_v0_1_8_3_sweep_optimization/measure_memory.R`.
Values are `utils::object.size()` bytes.

| workload | bars views | projection | median candidate feature views | retained peak proxy |
| --- | ---: | ---: | ---: | ---: |
| reference_50_candidates | 737,904 | 205,768 | 887,504 | 1,967,800 |
| wider_feature_payload | 2,137,008 | 569,304 | 3,984,080 | 7,471,256 |
| persistent_comparison | 737,904 | 205,768 | 887,504 | 1,967,800 |

## Interpretation Notes

- Post-change measurements must use the same workload definitions as the baseline.
- Compare this report with `baseline_report.md` before making performance claims.
- If the scoped optimization does not improve the reference workload, document why it still ships or defer/revert the change.
- The reference workload now improves by about 1.5x and the wider feature
  payload by about 2x.
- Prebuilt pulse views do not create material retained-memory pressure on the
  measured workloads.

## LDG-2108B Split Check

LDG-2108B estimated fold-core work at about 64% of measured sweep wall time and post-candidate reconstruction at about 31%-33%. In this v0.1.8.3 post_change Rprof sample, `ledgr_execute_fold()` accounts for about 70.1% of total sampled time on the reference workload.

That means the old phase split should not be treated as current without remeasurement. Fold/context work still dominates, while the direct post-candidate reconstruction share is not reproduced at the same magnitude by this sampling report. LDG-2408/LDG-2409 should therefore use the post-change report to confirm whether summary reconstruction remains the right optimized slice.

## Post-Fold Reconstruction Share

`ledgr_equity_from_events()` accounts for about NA% of sampled reference-workload time, and `ledgr_fills_from_events()` accounts for about 20.6%. Their simple summed share is about 20.6%.

This sum is a diagnostic upper-bound style number, not an additive phase timer: Rprof total percentages can overlap through call stacks. It is still useful as the baseline watch point for LDG-2408 and LDG-2409.

## Profile Top Frames

| profile | frame | total.time | total.pct | self.time | self.pct |
| --- | --- | --- | --- | --- | --- |
| by_total | "withCallingHandlers" | 24.93 | 100.00 | 0.14 | 0.56 |
| by_total | "suppressWarnings" | 24.93 | 100.00 | 0.01 | 0.04 |
| by_total | "main" | 24.93 | 100.00 | 0.00 | 0.00 |
| by_total | "profile_reference_workload" | 24.93 | 100.00 | 0.00 | 0.00 |
| by_total | "ledgr_sweep" | 24.92 | 99.96 | 0.00 | 0.00 |
| by_total | "tryCatch" | 24.65 | 98.88 | 0.21 | 0.84 |
| by_total | "doTryCatch" | 24.65 | 98.88 | 0.19 | 0.76 |
| by_total | "tryCatchOne" | 24.65 | 98.88 | 0.15 | 0.60 |
| by_total | "tryCatchList" | 24.65 | 98.88 | 0.09 | 0.36 |
| by_total | "ledgr_sweep_run_candidate" | 24.31 | 97.51 | 0.01 | 0.04 |
| by_total | "ledgr_execute_fold" | 17.48 | 70.12 | 0.00 | 0.00 |
| by_total | "fn" | 15.91 | 63.82 | 1.14 | 4.57 |
| by_total | "output_handler$run_transaction" | 15.91 | 63.82 | 0.00 | 0.00 |
| by_total | "data.frame" | 5.54 | 22.22 | 0.66 | 2.65 |
| by_total | "ledgr_fills_from_events" | 5.13 | 20.58 | 0.14 | 0.56 |
| by_total | "ledgr_fill_event_row" | 4.54 | 18.21 | 0.15 | 0.60 |
| by_total | "output_handler$buffer_event" | 3.97 | 15.92 | 0.01 | 0.04 |
| by_total | "handler$append_event_rows" | 3.93 | 15.76 | 0.17 | 0.68 |
| by_total | "as.data.frame" | 3.88 | 15.56 | 0.39 | 1.56 |
| by_total | "FUN" | 3.83 | 15.36 | 0.48 | 1.93 |
