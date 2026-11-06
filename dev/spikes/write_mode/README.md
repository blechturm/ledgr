# Write-mode probe, 2026-11-06

**Question.** ledgr has two durable write modes: `audit_log` (the default)
buffers events in memory and writes them later; `db_live` inserts every
fill into DuckDB during P4. Both run inside the run's one transaction. Do
they write identical stores, and what does each cost? The answer decides
whether `db_live` can be retired for one in-memory write path (response
review D6, `inst/design/rfc/rfc_lean_core_pulse_plumbing_v0_2_3_response_review.md`).
**Kill condition:** if the stores differ, the modes are not interchangeable
and retiring one needs a behavior decision first.

**Outcome: green.** Identical stores on both workloads. `db_live` makes a
fill-heavy run 21 times slower (195 against 9.4 s) to save about 34 MB of
R heap.

## What ran

- `run.R` builds both snapshots once, then for each workload and mode
  starts `worker.R` in its own R process (one round, two timed runs after a
  warm-up, High performance plan, P-core affinity).
- `worker.R` copies the sealed snapshot to a private file, so both modes can
  use the same run ID, builds the workload's experiment with
  `execution_mode` set, records the fold's `t_loop`, the run's wall time,
  the R heap's peak during the run (`gc()` max used, reset before the run)
  and the process's peak working set, and saves the ledger, equity and
  diagnostics tables of its first run.
- `check.R` reruns with one repetition, diffs `parity.csv`, checks the
  timing rows, requires identical stores and guards package scope.

Pinned tree `d5b3a151`. The workloads are the WS16 entry workloads
(`dev/bench/v0_2_3_ws16_entry/workloads.R`) with `execution_mode` added.

## Result

Medians of two runs (`evidence/timing.csv`):

| | momentum, audit_log | momentum, db_live | fill-heavy, audit_log | fill-heavy, db_live |
| --- | ---: | ---: | ---: | ---: |
| fold loop, us per pulse | 1,796 | 3,452 | 5,996 | 153,544 |
| whole `ledgr_run()`, s | 1.9 | 2.7 | 9.4 | 195.4 |
| R heap peak during the run, MB | 127 | 127 | 231 | 198 |
| process peak working set, MB | 404 | 405 | 1,084 | 998 |

Parity (`evidence/parity.csv`): the ledger (296 and 67,725 rows), equity
(504 and 1,260) and diagnostics (2,500 and 699,040) tables are identical
between the modes.

## What was learned about the package

- `db_live` costs about 2.7 ms per fill: one DuckDB insert per fill. On
  fill-heavy that is 95 percent of the run.
- It buys nothing a reader can see. The whole run is one transaction
  (`R/fold-engine.R:2059`), so per-fill rows are invisible to other
  connections until the commit, and a failure rolls them back.
- Its only benefit is memory: about 34 MB less R heap and 85 MB less
  working set on fill-heavy, because events are not buffered. Compact fill
  records (seven values per fill, `dev/spikes/fold_plumbing/lean.R`) would
  hold the same 67,725 fills in about 4 MB.

## What the spike leaves out

Failure paths (both modes roll back the same transaction; not exercised
here), checkpoints, sweeps (which use the memory sink, not these modes) and
any external reader during a run.
