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

| scenario | path | reps | median_sec | mean_sec |
| --- | --- | --- | --- | --- |
| smoke_3_candidates | sweep_plain | 2 | 1.190 | 1.190 |
| smoke_3_candidates | precompute | 2 | 0.100 | 0.100 |
| smoke_3_candidates | sweep_precomputed | 2 | 0.680 | 0.680 |
| smoke_3_candidates | run_loop | 2 | 5.440 | 5.440 |
| reference_50_candidates | sweep_plain | 2 | 30.275 | 30.275 |
| reference_50_candidates | precompute | 2 | 0.310 | 0.310 |
| reference_50_candidates | sweep_precomputed | 2 | 30.525 | 30.525 |
| wider_feature_payload | sweep_plain | 2 | 33.405 | 33.405 |
| wider_feature_payload | precompute | 2 | 0.910 | 0.910 |
| wider_feature_payload | sweep_precomputed | 2 | 33.100 | 33.100 |
| persistent_comparison | sweep_plain | 2 | 3.025 | 3.025 |
| persistent_comparison | run_loop | 2 | 8.650 | 8.650 |
| metric_context_non_default | sweep_plain | 2 | 3.010 | 3.010 |
| metric_context_non_default | precompute | 2 | 0.135 | 0.135 |
| metric_context_non_default | sweep_precomputed | 2 | 3.300 | 3.300 |

## Environment SHAs

| label | git_head_short | git_v0_1_8_2_tag | r_version | platform |
| --- | --- | --- | --- | --- |
| baseline | f5b49d4 | 9d8dfc841a789a16d605c9a97cf0d36aa1c14bbc | 4.5.2 | x86_64-w64-mingw32 |
| post_change | e1820d7 | 9d8dfc841a789a16d605c9a97cf0d36aa1c14bbc | 4.5.2 | x86_64-w64-mingw32 |

## LDG-2414 Conclusion

- Reference sweep plain improved from 45.585s to 30.275s, about 1.51x faster.
- Wider feature-payload sweep plain improved from 65.360s to 33.405s, about 1.96x faster.
- Persistent run-loop improved from 9.420s to 8.650s, so the repeated `ledgr_run()` regression watch item is resolved on the persistent comparison workload.
- The residual report recommends LDG-2410 typed memory events next, with LDG-2412 single-pass summary kept conditional on the post-LDG-2410 profile.
