# v0.1.8.3 Sweep Optimization Summary

## Available Reports

- `baseline_report.md` records the pre-optimization timing baseline.
- `post_change_report.md` records the post-LDG-2413 measurement used by
  LDG-2414 to decide whether LDG-2410 and LDG-2412 should remain in scope.
- `ldg2410_full_benchmark/post_change_report.md` records the typed memory-event
  checkpoint.
- `ldg2412_checkpoint/post_change_report.md` records the final single-pass
  summary checkpoint.
- `ldg2412_persistent_recheck/post_change_report.md` records the 5-rep
  persistent `run_loop` variance recheck.
- `residual_hot_path_report.md` records the final bottleneck analysis and
  release-gate disposition.

## Baseline Results

| scenario | path | reps | median_sec |
| --- | --- | ---: | ---: |
| smoke_3_candidates | sweep_plain | 2 | 1.320 |
| smoke_3_candidates | precompute | 2 | 0.085 |
| smoke_3_candidates | sweep_precomputed | 2 | 1.000 |
| smoke_3_candidates | run_loop | 2 | 5.245 |
| reference_50_candidates | sweep_plain | 2 | 45.585 |
| reference_50_candidates | precompute | 2 | 0.280 |
| reference_50_candidates | sweep_precomputed | 2 | 45.490 |
| wider_feature_payload | sweep_plain | 2 | 65.360 |
| wider_feature_payload | precompute | 2 | 0.785 |
| wider_feature_payload | sweep_precomputed | 2 | 65.345 |
| persistent_comparison | sweep_plain | 2 | 4.415 |
| persistent_comparison | run_loop | 2 | 9.420 |
| metric_context_non_default | sweep_plain | 2 | 4.350 |
| metric_context_non_default | precompute | 2 | 0.090 |
| metric_context_non_default | sweep_precomputed | 2 | 4.315 |

## Final v0.1.8.3 Results

| scenario | path | reps | median_sec | speedup vs baseline |
| --- | --- | ---: | ---: | ---: |
| reference_50_candidates | sweep_plain | 2 | 13.220 | 3.45x |
| reference_50_candidates | precompute | 2 | 0.315 | 0.89x |
| reference_50_candidates | sweep_precomputed | 2 | 12.945 | 3.51x |
| wider_feature_payload | sweep_plain | 2 | 12.130 | 5.39x |
| wider_feature_payload | precompute | 2 | 0.830 | 0.95x |
| wider_feature_payload | sweep_precomputed | 2 | 12.055 | 5.42x |
| persistent_comparison | sweep_plain | 2 | 1.350 | 3.27x |
| persistent_comparison | run_loop | 5 | 7.960 | 1.18x |

The final persistent `run_loop` number uses the 5-rep
`ldg2412_persistent_recheck` median. The two-rep LDG-2412 checkpoint reported
8.875s with a wide 7.70s-10.05s range; the 5-rep recheck confirmed that as
variance.

## Environment SHAs

| label | git_head_short | git_v0_1_8_2_tag | r_version | platform |
| --- | --- | --- | --- | --- |
| baseline | f5b49d4 | 9d8dfc841a789a16d605c9a97cf0d36aa1c14bbc | 4.5.2 | x86_64-w64-mingw32 |
| post-LDG-2413 | e1820d7 | 9d8dfc841a789a16d605c9a97cf0d36aa1c14bbc | 4.5.2 | x86_64-w64-mingw32 |
| post-LDG-2410 | ac09d75 | 9d8dfc841a789a16d605c9a97cf0d36aa1c14bbc | 4.5.2 | x86_64-w64-mingw32 |
| post-LDG-2412 | ac09d75 + working tree | 9d8dfc841a789a16d605c9a97cf0d36aa1c14bbc | 4.5.2 | x86_64-w64-mingw32 |

## Optimization Arc

| state | reference sweep_plain | speedup vs baseline |
| --- | ---: | ---: |
| LDG-2402 baseline | 45.585s | 1.00x |
| LDG-2411 fast context checkpoint | 43.245s | 1.05x |
| LDG-2413 prebuilt views | 30.275s | 1.51x |
| LDG-2410 typed memory events | 17.330s | 2.63x |
| LDG-2412 single-pass summary | 13.220s | 3.45x |

## Closeout Conclusion

- v0.1.8.3 delivers 3.45x on the reference sweep workload.
- v0.1.8.3 delivers 5.39x on the wider feature-payload workload.
- The persistent `ledgr_run()` loop is also faster than baseline after the
  buffered-write fix and 5-rep variance recheck.
- Post-fold summary reconstruction is no longer a top sampled frame.
- The next implementation step is LDG-2415 release gating, not another
  optimization ticket.
