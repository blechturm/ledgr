# LDG-3275: the pin advances to the release head

Cut 27 decision 2 (maintainer, 2026-11-27).

The pin record is the lean fold core synthesis's amendment of 2026-11-27,
"the pin advances". It gives the old pin, the range, the reason and the
toolchain.

## Builds

- **Library:** `C:/Users/maxth/ledgr-wt/pin-lib-7f65733f`, from
  `dev/feature_parity/install_arm.R --commit=7f65733f`, with
  `LEDGR_INSTALLED_FROM_COMMIT` (7f65733f). The install log is beside it.
- **Source archive:** `C:/Users/maxth/ledgr-wt/pin-src-7f65733f`, from
  `git archive 7f65733f`, with `LEDGR_SOURCE_COMMIT` (7f65733f). One
  process built its DLL with `pkgload::load_all()`. The unwind table is
  clean: `capture_crash/pdata.R` finds 4,254 entries, 0 out of order.

`dev/lean_core/load.R` names 7f65733f.
`ldg3275_old_pin_refused.txt`: `lean_core_load()` now refuses
`pin-lib-d5b3a151` ("is not the pinned build 7f65733f (marker:
d5b3a151)").

## Gate subset

`ldg3275_subset_debug0.csv`, `_debug1.csv` and their logs come from
`loop_parity.R --lib=<new pin> --freeze=loop_freeze.csv`, run from
`C:/Users/maxth/ledgr-wt/cut27-scratch/run` (outside any source package).
The workloads, one per slice plus a worker and a walk-forward workload:
- crossover_3x40;
- s2_cost_chain, s2_sizing_rebalance;
- s3_freeze_held, s3_sched_sweep;
- s4_dividend, s4_acq_fills;
- s5_workers_sizing, s5_walk_forward_workers, walk_forward;
- s5_compiled_lots.

Result, debug 0 and 1 each: 11 workloads, 180 tables, 0 different, PASS
11, 11 of 11 frozen paths checked.

The full proof matrix reruns on the new pin at the close (LDG-3283).
