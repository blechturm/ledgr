# v0.1.8.3 Sweep Optimization Summary

## Available Reports

- `baseline_report.md` records the pre-optimization timing baseline.
- `post_change_report.md` records the same workloads after scoped optimization.
- `residual_hot_path_report.md` records remaining bottlenecks and the next optimization recommendation.

## Baseline Results

| scenario | path | reps | median_sec | mean_sec |
| --- | --- | --- | --- | --- |
| smoke_3_candidates | sweep_plain | 2 | 1.320 | 1.320 |
| smoke_3_candidates | precompute | 2 | 0.085 | 0.085 |
| smoke_3_candidates | sweep_precomputed | 2 | 1.000 | 1.000 |
| smoke_3_candidates | run_loop | 2 | 5.245 | 5.245 |
| reference_50_candidates | sweep_plain | 2 | 45.585 | 45.585 |
| reference_50_candidates | precompute | 2 | 0.280 | 0.280 |
| reference_50_candidates | sweep_precomputed | 2 | 45.490 | 45.490 |
| wider_feature_payload | sweep_plain | 2 | 65.360 | 65.360 |
| wider_feature_payload | precompute | 2 | 0.785 | 0.785 |
| wider_feature_payload | sweep_precomputed | 2 | 65.345 | 65.345 |
| persistent_comparison | sweep_plain | 2 | 4.415 | 4.415 |
| persistent_comparison | run_loop | 2 | 9.420 | 9.420 |
| metric_context_non_default | sweep_plain | 2 | 4.350 | 4.350 |
| metric_context_non_default | precompute | 2 | 0.090 | 0.090 |
| metric_context_non_default | sweep_precomputed | 2 | 4.315 | 4.315 |

## Post-Change Results

_No post-change results found yet._

## Environment SHAs

| label | git_head_short | git_v0_1_8_2_tag | r_version | platform |
| --- | --- | --- | --- | --- |
| baseline | f5b49d4 | 9d8dfc841a789a16d605c9a97cf0d36aa1c14bbc | 4.5.2 | x86_64-w64-mingw32 |
