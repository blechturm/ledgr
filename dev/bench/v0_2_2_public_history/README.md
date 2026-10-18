# Workstream 42 public-history scale workloads (Cut 16 LDG-3062..3064)

Vendor-neutral scale evidence for the public causal-history surface,
experiment-derived pulse inspection, availability precompute and the
continuous carry chain. No vendor row is used.

## Files

- `fixture.R`: an availability snapshot at the H1 shape (1,166 instruments by
  7,213 weekday sessions, 580 rotating complete membership sets of 600
  members, 20 labelled delistings, 40 labelled late-known ten-session
  inactive intervals, about 0.5 percent missing member bars and five cash
  dividends), adapted from `dev/bench/v0_2_2_real_data_scale/fixture.R`, plus
  a monthly equal-weight strategy and the same strategy reading
  `ledgr_history_frame()` every pulse (21 sessions) and every rebalance (252
  sessions with `drop_instruments`).
- `run_workload.R`: one workload per process against one tree, appending one
  CSV row (tree label, shape, elapsed seconds, R heap peak in MB from
  `gc()` "max used" since the workload started, note).
- `evidence/`: the recorded CSVs and the probe output described below.

## Reproduction

Both arms are loaded with `pkgload::load_all()` from a source tree compiled
once beforehand. The baseline arm is `a915ba66` exported with
`git archive --format=tar a915ba66 R src DESCRIPTION NAMESPACE data`. Each arm
builds its own snapshot, because the candidate's experiment store is schema
122 and the baseline's is schema 121.

```sh
Rscript run_workload.R <tree> <db> build <out.csv> --label=<tree>
Rscript run_workload.R <tree> <db> run_plain <out.csv> --label=<tree>
Rscript run_workload.R <tree> <db> sweep <out.csv> --label=<tree>
Rscript run_workload.R <tree> <db> walk_forward <out.csv> --folds=16 --label=<tree>
Rscript run_workload.R <tree> <db> precompute <out.csv> --label=<tree>
Rscript run_workload.R <candidate> <db> run_history <out.csv> --label=<tree>
Rscript run_workload.R <candidate> <db> inspect <out.csv> --label=<tree>
```

One workload ran at a time with no test or build alongside. The heap figure
is R's allocation high-water mark, which includes garbage awaiting
collection; it is disclosure, not the LDG-3069 private-commit gate.

## Recorded results (2026-10-17, shared host)

`evidence/scale_h1.csv` holds every row in run order and
`evidence/frame_probe_h1.txt` the read probe at 1,166 x 7,213. Another agent
was running tests on the same host, so elapsed times are disclosure only: the
candidate's identical 16-fold walk-forward took 411 s and then 212 s.

- `run_plain`, `sweep`: identical final equities on both arms; elapsed within
  host noise (133.6 vs 131.0 s; 347.0 vs 322.0 s).
- `precompute`: the baseline refuses an availability experiment with ragged
  bars (`ledgr_precompute_validate_static_coverage`); the candidate prepares
  it through the substrate in 13.3 s.
- `walk_forward` (16 carried folds): the baseline completes fold 1 and stops
  at fold 2, whose carried test run values no pulse because its window-local
  marks have no admissible mark for a held instrument without a first-pulse
  bar. The candidate completes all 16 folds.
- `run_history` (the reader strategy: 21 sessions every pulse, 252 sessions
  with `drop_instruments` and a matrix every month) costs 168.0 s against
  131.0 s for the same run without reads, about 5 ms per pulse, with the
  same final equity.
- `inspect`: three experiment-derived inspections plus a 252-session frame,
  28.1 s in total (each prepares the substrate and the payload to its
  cutoff).
