# Pulse View Construction Spike

Reps: 3

Fixture: v0.1.8.3 reference workload shape, 50 candidates, 4 instruments, 252 pulses, single feature mode.

## Package Availability

- data.table: TRUE
- collapse: TRUE
- dplyr: TRUE
- tidyr: TRUE
- tibble: TRUE

## Equality Checks

| comparison | equal | error |
| --- | --- | --- |
| base_feature_table | TRUE | NA |
| base_features_wide | TRUE | NA |
| data_table_df_feature_table | TRUE | NA |
| data_table_df_features_wide | TRUE | NA |
| collapse_feature_table | TRUE | NA |
| collapse_features_wide | TRUE | NA |
| tidyr_feature_table | TRUE | NA |
| tidyr_features_wide | TRUE | NA |

## Timings

| label | ok | reps | median_sec | mean_sec | min_sec | max_sec | object_mb | error |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| current_bars_once | TRUE | 3 | 0.14 | 0.147 | 0.14 | 0.16 | 0.704 | NA |
| base_split_bars_once | TRUE | 3 | 0.04 | 0.040 | 0.03 | 0.05 | 0.704 | NA |
| current_features_50_candidate | TRUE | 3 | 8.03 | 8.857 | 7.40 | 11.14 | 42.320 | NA |
| base_split_features_50_candidate | TRUE | 3 | 1.96 | 1.980 | 1.95 | 2.03 | 42.320 | NA |
| data_table_df_features_50_candidate | TRUE | 3 | 6.27 | 6.353 | 6.14 | 6.65 | 42.320 | NA |
| data_table_native_features_50_candidate | TRUE | 3 | 5.06 | 5.267 | 5.03 | 5.71 | 56.932 | NA |
| collapse_features_50_candidate | TRUE | 3 | 0.68 | 0.687 | 0.67 | 0.71 | 42.320 | NA |
| tidyr_features_50_candidate | TRUE | 3 | 3.64 | 3.637 | 3.63 | 3.64 | 42.320 | NA |
| current_features_union_once | TRUE | 3 | 0.15 | 0.160 | 0.15 | 0.18 | 1.185 | NA |
| base_split_features_union_once | TRUE | 3 | 0.04 | 0.043 | 0.04 | 0.05 | 1.185 | NA |
| data_table_df_features_union_once | TRUE | 3 | 0.11 | 0.117 | 0.11 | 0.13 | 1.185 | NA |
| data_table_native_features_union_once | TRUE | 3 | 0.10 | 0.097 | 0.09 | 0.10 | 1.546 | NA |
| collapse_features_union_once | TRUE | 3 | 0.01 | 0.010 | 0.00 | 0.02 | 1.185 | NA |
| tidyr_features_union_once | TRUE | 3 | 0.08 | 0.080 | 0.08 | 0.08 | 1.185 | NA |

## Interpretation

The current helper path constructs many small data.frames. The split/nest candidates build one indexed table and split by pulse index.
A production dependency decision should compare base split against package-backed variants after preserving the public data-frame schema.
