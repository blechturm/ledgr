# LDG-3271: the worker launch boundary (Cut 26 decision 2)

## The gap

`ledgr_parallel_ledgr_source_path()` (R/parallel-workers.R:244-262, the
same in the pin d5b3a151) makes every sweep worker `pkgload::load_all()` the
working directory when the parent's ledgr is an installed library and the
working directory is a ledgr source package. The lean harness compares the
installed pin with the lean loop over it and was run from worktree roots, so
the A0 workloads' worker sweeps (`sweep_w2`,
dev/bench/v0_2_3_output_freeze/lib.R:489) loaded that worktree's source in
both arms. Those tables were compared, but they were not a pin comparison of
the worker path. The lean loop refused worker sweeps, so no lean claim rested
on them. `witness_sweep_workers` changes directory itself and loaded the pin.

## The repair

`dev/lean_core/load.R` gains three harness helpers:
- `lean_harness_workdir(control)`: moves the working directory to a fresh
  directory outside any source package, or to `control` (the source-package
  control);
- `lean_worker_origin_install(declared)`: wraps the pin's worker setup in
  either arm; each worker the pin starts writes its own ledgr namespace
  origin to its own file; `read()` returns, per arm, the setups, the workers
  started, the reports and whether every origin equals the declared build;
- `lean_declared_origin(lib)`: the declared build and its label (installed
  pin: `<lib>/ledgr`; source pin: the archive itself).

Each worker-starting runner resolves its path arguments first, sources its
helpers, then moves and installs the recorder:
- `parity/loop_parity.R` (and `loop_variants.R`, whose children are
  loop_parity.R runs; the driver passes absolute paths): a WORKER verdict
  when either arm's workers report another build; `--workdir=<dir>` is the
  control. Columns `workers_pinned` and `workers_lean`.
- `parity/plan_parity.R`: the same check, a WORKER line and a failing exit,
  `--workdir=` control, `workers_*` columns.
- `recorder/run.R`: prints whether the capture runs on the installed pin or
  a source pin; a worker on another build stops the capture with WORKER;
  `--workdir=` control. The `--src` child loads the source pin and is
  labelled so.

No package code changes.

## Evidence

- `controls.txt`: from the worktree root (a source package), each runner on
  avail_incomplete passes with every worker on the pin; with
  `--workdir=<worktree>` each fails with WORKER (the workers report the
  worktree).
- `worker_records_inventory.csv` (`inventory.R`): the 89 committed CSVs with
  sweep_w2 tables. 42 are A0 harness records, which load the source tree by
  design. 47 are lean-harness records: 37 demonstrably launched from the
  repository root (their committed commands start the runner by a relative
  script path), 10 with no recorded launch directory (unknown). None is
  changed.
- `gate_debug0.csv`, `gate_debug1.csv` (`.log` beside): the full gate on the
  unchanged lean core under the repaired launch, against `loop_freeze.csv`:
  203 workloads, 3,136 tables, 0 different, PASS 202 and PASS* 1
  (`s3_sched_none`, as before), every frozen path checked, with debug off
  and on. The six workloads with worker sweeps (dense_cost,
  dense_risk_features, avail_terminal_resume, avail_incomplete, failures,
  witness_sweep_workers) now compare the pin's workers in both arms: every
  run reports 2 of 2 workers on `pin-lib-d5b3a151/ledgr` per arm. No path
  changed (the lean loop still refused worker sweeps).
- `variants/` and `variants_driver.log`: `loop_variants.R` from outside the
  tree: 205 manifest rows, 80 variants, 0 failures; the three negative
  controls fail closed as expected.
