# LDG-3274: close slice 5

Cut 26 decisions 7 to 10 on the final code. The lean sources are final at
`bc628409` (nothing under `dev/lean_core/*.R` changes after it). Pin: the
installed library d5b3a151 (`C:/Users/maxth/ledgr-wt/pin-lib-d5b3a151`).
`run_close.R` runs every parity step as a fresh Rscript from a directory
outside any ledgr source package. It follows Cut 21's recipe
(`evidence/cut21/ldg3248/COMMANDS.md`).

    Rscript run_close.R --lib=<pin> --dumps=<scratch dir> --steps=<step,...>

The batch-one and inert steps run the workloads frozen in that mode. The
pin dumps for the reach cross-checks are large and stay outside the tree.

## Retained guards (decision 7)

`coverage_scan.txt` lists the lean coverage refusals at `bc628409`:
- the checkpoint control: an entry key, `loop.R:73`, or a non-default
  value, `:84`;
- `db_live`, non-buffered execution: `:80`;
- pulses outside the prepared axis: `:96`.

Lines 65 and 534 are the generic raise and the callback check. Both
checkpoint witnesses keep their frozen refusal rows, 10000L and NULL
control keys refused before the first pulse (`gate_debug*.csv`,
`witness_checkpoint_control` and `witness_checkpoint_null`: lean 0,
refused `a checkpoint_every control`, PASS against the frozen rows).

## Freeze changes, gate, batch one, inert (decision 8 and 10)

`loop_freeze_changes.R` and `.csv` (commit `bc628409`) make three kinds of
change:
- update the gate rows of the eight workloads whose path changed:
  dense_cost (12 lean folds), dense_risk_features (6),
  avail_terminal_resume (5), avail_incomplete (6), failures (6),
  witness_sweep_workers (2), walk_forward (10), witness_walk_forward (6);
  each refused column empties;
- add the 24 slice-5 workloads in gate mode;
- add the capacity and worker witnesses in batch-one mode, and the worker
  witnesses in inert mode.

Every count comes from final-code execution (`evidence/ldg3272`,
`evidence/ldg3273`). The checkpoint rows are unchanged.

| run | result |
| --- | --- |
| `gate_debug0`, `gate_debug1` | 227 workloads, 3,452 tables, 0 different; PASS 222, PASS* 5 (`s3_sched_none` as before, and the four compiled-refusal witnesses that stop before any fold); frozen paths 227 of 227 checked |
| `batch1_debug0`, `batch1_debug1` | 67 workloads, 914 tables, 0 different, PASS 67; 67 of 67 frozen paths checked |
| `inert_debug0`, `inert_debug1` | 36 workloads, 485 tables, 0 different, PASS* 36 (inert hooks count no fold); 36 of 36 frozen paths checked |
| `slice{2,3,4}_reach_cross` | 26, 41 and 92 checks, all ok, on the debug-0 gate's pin dumps |

Worker records (`*_workers.csv`): 37 records over 15 workloads in each
gate run, and 25 records over 9 workloads in each batch-one and inert run.
Every record is from `pin-lib-d5b3a151/ledgr`, every envelope entry is the
lean envelope, the hooks are `harness` (gate and batch one) or `inert`
(inert), with no store call, no worker fault and no WORKER verdict.

## Variants and the restored-refusal signal (decision 8)

`loop_variants.R` now passes the approved freeze, with its changes, to
every child run. A restored coverage refusal (`restored_variant()` in
`loop_parity.R`) is CAUGHT on the `restored` signal only when all of these
hold:
- its marker inside the refusal branch was reached;
- the execution path differs from the frozen row;
- every refusal new against the frozen row matches the intended one;
- no table differs.

This comparison is separate from the store and sink path predicate, and a
restored refusal may be CAUGHT with zero lean folds.

| run | result |
| --- | --- |
| `variants_debug0.log` | 149 manifest rows, 87 variants, 0 failures; the negative controls `control_unrelated`, `control_unreached` and `control_wrong_store_path` fail closed as before, `control_unrelated_refusal` (a restored edit refusing for another reason, on `s5_compiled_lots`) is UNRELATED and `control_unreached_refusal` (on `crossover_3x40`, which never selects the compiled model) is UNREACHED, each with status 1 |
| `variants_debug1.log` | 103 manifest rows, 52 variants, 0 failures |

Decision 8's additions, each CAUGHT with debug off and on:
- the worker variants (`evidence/ldg3273`): worker_lean_not_installed,
  worker_record_dropped, worker_record_duplicated,
  worker_backstop_rerun_skipped, worker_rng_restore_skipped,
  worker_wrong_build;
- the worker-local faults: worker_terminal_write, worker_capacity_lowered,
  worker_hold_signal, and store_execute, write_in_loop and expand_whole on
  `witness_sweep_workers`;
- compiled_dispatch_skipped and compiled_event_kinds_skipped;
- compiled_selector_refused on `s5_compiled_lots`, `s5_compiled_costs` and
  `dense_cost`, with identical tables and the path differing from the
  freeze;
- walk_forward_refused on `walk_forward`, `witness_walk_forward`,
  `s5_walk_forward_costs` and `s5_walk_forward_workers`, with identical
  tables and the path differing from the freeze;
- capacity_late on `s5_compiled_capacity_over`, at the normal bound and at
  batch one.

`cost_columns_short` on `s5_workers_sizing` runs with debug on only: it is
the debug-only check firing in a worker. Two workers_guard_off rows were
retired in LDG-3273.

## Other suites (decision 10)

| file | result |
| --- | --- |
| `witness.log`, `witness/` | hashed-frame witness: PASS |
| `loop_dispatch.csv`, `.log` | every case `ok` (both predicate sides as established; the two outside-guarantee inputs refused by the debug comparator), as at Cut 21 |
| `plan_parity_debug0.csv`, `_debug1.csv` | 427 tables, 0 different |
| `cut18_witness.csv` | 145 cases x 2 debug settings, 0 differ; manifest missing 0, unlisted 0 |
| `fifo_check.log` | see below |

## Lines (decision 9)

`lines.csv` (`cut19_lines.R --base=2bd1a33e --final=bc628409`) gives
production lines:
- `loop.R` 993 to 997, at or below 1,000. The compiled and restart checks
  are deleted, and the E stage gains the two admission calls.
- `loop_harness.R` 177 to 165.
- Total production 2,665 to 2,657 (-8). Debug lines are unchanged (206).

`lines_harness.csv` counts non-blank, non-comment code lines, harness,
workload and witness, reported beside the production count:

| file | role | before | after | change |
| --- | --- | ---: | ---: | ---: |
| `loop_workers.R` | harness | 0 | 163 | +163 |
| `load.R` | harness | 43 | 103 | +60 |
| `loop_workloads_slice5.R` | workload | 0 | 509 | +509 |
| `loop_parity.R` | workload | 548 | 659 | +111 |
| `feature_bridge.R` | witness | 0 | 199 | +199 |
| `loop_freeze_changes.R` | witness | 200 | 235 | +35 |
| `loop_variants.R` | witness | 81 | 87 | +6 |
| `loop_workloads.R` | workload | 559 | 557 | -2 |
