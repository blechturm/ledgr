# 1998-2026 Sharadar run (LDG-2976)

Records the first end-to-end ledgr run on the private Sharadar S&P lake.
Outputs here are aggregates only; the snapshot itself stays under the
private data root.

```sh
Rscript dev/bench/v0_2_2_sharadar_run/run_record.R . <ledgr-research> \
  E:/ledgr-data/sharadar/experiments/LDG-2976 dev/bench/v0_2_2_sharadar_run/evidence/run1 [stage ...]
```

- `run_record.R` runs each stage in its own R process and samples the
  child's peak resident memory; it writes `stages.csv`.
- `stage.R` is one stage: `build`, `census`, `momentum`, `equal_weight`,
  `sweep`, `walk_forward`, `profile_momentum`, `profile_equal_weight`.
- `probe_diagnostic_append.R` times the sweep memory handler's diagnostic
  append with real 4,096-row chunks as the table grows (finding F4).
- `probe_sweep_cost.R` profiles one run against a one-candidate sweep on a
  copy of the snapshot (not yet run).
- `review_probes/` holds the synthetic probes of the 2026-10-08
  research-cycle review (findings F1 to F13 in the Cut 11 amendment). They
  build a 1,000 x 1,500 availability fixture with `build.R` and write their
  databases to the working directory.

`evidence/run1` is the first record (ledgr dfde5b3, adapter 6be0b99).
Two harness defects are known there: a diagnostic reason named `1` in the
stage JSON is jsonlite naming the empty `reason_code` of plain fills, and
the sweep stage's exit status 1 came from editing `stage.R` while it ran,
after the sweep had finished and recorded. `walk_forward_first_date_refused.json`
is stop S1. `evidence/run1_followup` holds the walk-forward rerun from
1998-01-05 and the phase profiles.
