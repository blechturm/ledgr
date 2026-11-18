# Protocol cut22-feature-1

The Cut 22 timing record (decision 3a): the feature path, base against
candidate, each arm its own installed package (`--base` and `--candidate`
are immutable commits, no candidate overlay). One protocol serves every
comparison of the cut: the A/A record, the matched-arm record of each speed
unit, candidate 5's timing bound and the final package against the
immutable cut base `b33e01d7`. The pin `d5b3a151` is the semantic oracle
only (dev/feature_parity/), never a timing arm. Eight alternating
fresh-process pairs per cell (the harness floor).

## Cells

| cell | path | shape | reps | bound |
| --- | --- | --- | ---: | ---: |
| `run_10x7200` | run | 10 x 7,200 | 24 | 1.02 |
| `sweep_10x7200` | sweep | 10 x 7,200 | 12 | 1.02 |
| `run_500x1260` | run | 500 x 1,260 | 6 | 1.02 |
| `sweep_500x1260` | sweep | 500 x 1,260 | 3 | 1.02 |
| `run_1166x252` | run | 1,166 x 252 | 4 | 1.02 |
| `sweep_1166x252` | sweep | 1,166 x 252 | 2 | 1.02 |

The fixture is the r_floor shape (`ledgr_sim_bars()`, seed 20260530, closes
at 21:00 UTC, rounded to 8 digits), sealed in the slot's work directory and
reopened with `verify = TRUE`; the experiment is a fixed basket (bar-native
clock). Run features: TTR SMA 5 and 10 (the published crossover). Sweep
features: TTR SMA 3, 5, 8, 12, 20 and 40 (the sweep map's union).

## Clock `feature`

Endpoints: from the first call of a preparation to the return of the
projection, for `reps` preparations back to back, timed with `Sys.time()`
(about 1.5 us resolution on this host; `proc.time()` ticks in 20 ms
steps). Each preparation is the package's own sequence, with the
production engine-version work inside the clock:

- run (`ledgr_run_fold_impl`): `ledgr_feature_engine_version()`,
  `ledgr_history_compute_feature_series()` over the experiment's
  definitions named by ID from the calculation start to the last session,
  `ledgr_projection_from_feature_matrix()`;
- sweep (implicit `ledgr_sweep()`): `ledgr_history_precompute_payload()`
  over the unique definitions named by fingerprint, then
  `ledgr_projection_from_payload()` with `ledgr_feature_engine_version()`.

Outside the clock: process start, library load, fixture, sealing,
substrate and definition preparation, one untimed warm-up preparation
(which also fills the package's catalogue and TTR caches; nothing is cached
across preparations otherwise), then `gc()`. Garbage collection inside the
batch is part of the measured cost. The installed packages are
byte-compiled; the workload closures are not compiled. Raw observations,
the plan, host probes and exact commands are kept by the shared harness in
each record's attempt folder; failed attempts are kept.

`reps` was frozen before any comparison from a calibration of the cut base
(3 calls per cell, not a record: 0.29, 0.60, 0.79, 1.82, 1.10 and 2.43 s per
call in the order of the table) so that the faster arm's batch lasts about
three seconds or more after the expected savings.

## Work string

Shape, path, reps, the number of definitions and a digest of the logical
result: the projection's value matrices, indexed planes, instrument and
pulse indexes and formatted axis, with the declared engine marker removed
(decision 3a). The payload's physical shape is not part of it, so both
arms of every record must return the same string; a changed value, axis or
plane changes it.

## Records and keep rules (decision 3a)

- **A/A** first, on the cut base against itself without an overlay: it
  establishes the host's noise on each cell. Noise larger than a unit's
  margin makes that unit inconclusive, not kept.
- **Unit records**: matched arms that differ only by the unit, with every
  prerequisite edit identical. Target cells, named here before any
  comparison:
  - unit 1 (format the axis once): `run_10x7200`, `sweep_10x7200`;
  - unit 4 (admission slices only the required fields): `sweep_500x1260`,
    `sweep_1166x252`;
  - unit 2+3 (narrowed input treatment and the TTR per-call overhead):
    `run_500x1260`, `sweep_500x1260`, `run_1166x252`, `sweep_1166x252`.

  A speed unit is kept only if every target cell's candidate median is
  faster than its base median and every measured cell stays within the 1.02
  bound (check.R CHECK PASS).
- **Candidate 5** (matrices only) has no speed target: every measured cell
  within 1.02, and the memory rule below.
- **Final**: the final package against the cut base `b33e01d7` on all six
  cells, every cell within 1.02.

## Candidate 5 memory (declared before running)

Measured outside this harness by `dev/feature_parity/memory.R` (LDG-3252),
in fresh child processes, matched arms differing only by candidate 5:

- object bytes: `utils::object.size()` and the serialized length
  (`length(serialize(x, NULL))`) of the whole `ledgr_precompute_features()`
  object on the 500 x 1,260 and 1,166 x 252 sweep fixtures (the six sweep
  definitions, a two-candidate grid);
- peak R heap: sequential sweep feature preparation (the sweep path above,
  one worker), fixtures prepared before the phase, `gc(reset = TRUE)`, the
  preparation with its projection retained at the end, then `gc()`'s
  max-used Ncells and Vcells in bytes; memory target cells 500x1260 and
  1166x252; 8 fresh children per arm and cell, alternating; median compared;
  sensitivity validated by an extra live 8 MiB allocation inside the phase.
  The metric is peak R heap, not process memory.

Both reductions must hold on every memory cell: fewer object bytes and a
lower median peak R heap. Unchanged or increased memory fails; unresolved
noise is inconclusive.

## Launch

The runner installs its arms into `tempdir()`; the launch wrapper
`dev/feature_parity/timing_launch.R` points `TMPDIR`, `TMP` and `TEMP` at a
scratch directory outside AppData/Local/Temp before starting the runner, so
no arm library is created there. Under the High performance plan and
`dev/bench/v0_2_3_lean_tuning_profile/pcore.ps1` (affinity 0xFFFF):

    powershell -NoProfile -ExecutionPolicy Bypass -File dev/bench/v0_2_3_lean_tuning_profile/pcore.ps1 <log>
      dev/feature_parity/timing_launch.R --tmp=<scratch> dev/bench/timing/runner.R
      --protocol=dev/bench/timing/protocols/cut22-feature-1 --base=<commit> --candidate=<commit> --label=<name>
