# LDG-2951 current-tree baseline

This same-commit calibration was recorded on 2026-10-04 before any production
edit. Both arms resolve to `e3c31f12382a17e6b586c22c93f0ddd3bd475ecf`.
The checker at `eb1fe87` passed the complete record.

The registered fixture contains 1,514 sessions, 600 physical instruments, 500
members, 12 membership sets, 908,400 bars and three returns features. The two
unmarked five-pair calibrations reproduced near one:

| persistence | peak RSS ratio | elapsed ratio |
| --- | ---: | ---: |
| off | 1.0008 | 1.0071 |
| on | 1.0002 | 1.0036 |

Every same-commit ratio lies inside the preregistered 0.95 to 1.05 calibration
band. Separate marked runs retain phase timestamps and heap peaks. Separate
oracle runs match completion, equity, fills, trades, diagnostics, decoded
strategy state, persisted feature rows and availability output; the dense
witness matches as well. The mutation self-test changes the normalized equity
hash and is rejected.

The record used R 4.6.1, DuckDB 1.5.6.9000 and collapse 2.1.8. The first two
attempts failed before fixture construction because the wrong library resolved
DuckDB 1.5.2. Two later fixture attempts exposed and corrected benchmark-only
table-selection defects. A fifth run was stopped after its 20-minute controller
ceiling; its partial rows are not evidence. None of those directories is
included here.

## Source liveness before the candidate

The six candidate releases and their last production reads in
`ledgr_run_fold()` are:

| object | last production read | retained replacement or consumer |
| --- | --- | --- |
| `bars_all` | `split(bars_all, bars_all$instrument_id)` | aligned `bars_by_id`, `bars_mat` |
| `raw_bars_by_id` | per-instrument alignment loop | aligned `bars_by_id` |
| `bars_cols_by_id` | loop filling `bars_mat` | `bars_mat`, `static_bars_views` |
| aligned `bars_by_id` | per-definition feature loop | `runtime_projection`; execution field remains an empty list |
| `run_feature_series` | loop filling `run_feature_matrix` | `run_feature_matrix` |
| `run_feature_matrix` | `ledgr_projection_from_feature_matrix()` | `runtime_projection` |

The later runner and finalizer read `bars_mat`, `static_bars_views`,
`runtime_projection`, fold state and persistence inputs. A repository search
finds no later production read of the six intermediates. The candidate must
release each immediately after the read named above and must not replace any
retained object or alter the execution-spec field set.
