# 1998-2026 Sharadar run (LDG-2976)

Records the first end-to-end ledgr run on the private Sharadar S&P lake.
Outputs here are aggregates only; the snapshot itself stays under the
private data root.

## Cut 15 schema-120 rebuild (LDG-3055)

`ws39_record.R` is the fresh-only Cut 15 route. It refuses an existing work
directory, builds through the public `ledgr.sharadar` adapter, performs an
explicit cold rule-3 verification, and runs full-membership and dynamic
membership probes against the same native snapshot identity. The
full-membership probe uses `universe = NULL`; because this snapshot declares
availability facts, it intentionally runs on the availability provider rather
than the legacy dense-only runner. This is the macro plan's accepted meaning of
a dense universe after Cut 15.

From the ledgr source tree, with `SHARADAR_DATA_ROOT` already naming the guarded
private root:

```powershell
$work = Join-Path $env:SHARADAR_DATA_ROOT "experiments/LDG-3055-schema120"
Rscript dev/bench/v0_2_2_sharadar_run/ws39_record.R . <ledgr-research> $work dev/bench/v0_2_2_sharadar_run/evidence/ws39_schema120
```

`$work` must not exist. The worker never opens, migrates, or deletes a prior
store. Snapshot and logs remain under the private root; the evidence directory
receives aggregate CSVs only. Read-only SQL is limited to aggregate inspection
of the newly built current store: current format markers, the LFB-021 lifetime
count, and absence of the schema-119 feature-persistence surfaces.

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
