# LDG-3243 evidence: commands

From the package root, on the lean code of 0c6b88f9 (the harness as committed
there). `<pin>` is the pin d5b3a151.

Pin library. Two libraries hold the pin:
- The original: `scratchpad/ws16/lib-d5b3a151`. Part of it was deleted at
  19:34 on 2026-11-16 (`NAMESPACE`, most of `Meta/`, `data/Rdata.rdb`,
  `help/`), and it no longer loads.
- The rebuild: `C:/Users/maxth/ledgr-wt/pin-lib-d5b3a151`, installed with
  `R CMD INSTALL` from the clean worktree `C:/Users/maxth/ledgr-wt/pin-src-d5b3a151`
  (detached at d5b3a151).

`C:/Users/maxth/ledgr-wt/pin_compare.R` compares the original's surviving
code database with the rebuilt namespace. The 2,098 common objects have
identical bodies and formals ("common 2098 differing 0"). The only objects
that are not common are the four native-routine symbols created at load and
three namespace internals. The targeted and variant runs below ran on the
original before the deletion; the gate, batch-one and inert runs ran on the
rebuild.

| file | library | command |
| --- | --- | --- |
| targeted_debug1.csv | original, before 19:34 | `Rscript dev/lean_core/parity/loop_parity.R --lib=<pin> --debug=1 --workloads=s4_opening,s4_opening_sessions,s4_carried,s4_carried_lots,s4_basis_unknown,s4_basis_known,s4_prefix_opening_sweep,s4_prefix_opening_run --out=<file>` |
| variant_frozen_opening_ignored_debug0.csv | original, before 19:34 | `Rscript dev/lean_core/parity/loop_parity.R --lib=<pin> --debug=0 --mutation=frozen_opening_ignored --workloads=s4_carried_lots --out=<file>` |
| gate_debug0.csv, gate_debug1.csv | rebuild | `Rscript dev/lean_core/parity/loop_parity.R --lib=<pin> --debug=<0/1> --freeze=dev/lean_core/parity/loop_freeze.csv --out=<file>` |
| batch1_debug0.csv, batch1_debug1.csv | rebuild | `Rscript dev/lean_core/parity/loop_parity.R --lib=<pin> --debug=<0/1> --batch-rows=1 --workloads=<B1> --freeze=dev/lean_core/parity/loop_freeze.csv --out=<file>` |
| inert_debug0.csv, inert_debug1.csv | rebuild | `Rscript dev/lean_core/parity/loop_parity.R --lib=<pin> --debug=<0/1> --inert=1 --workloads=<IN> --freeze=dev/lean_core/parity/loop_freeze.csv --out=<file>` |
| lines.csv | - | `Rscript dev/lean_core/parity/cut19_lines.R --base=381c0d0c --final=0c6b88f9 --out=<file>` |

`<B1>`: Cut 19's batch-one list plus s4_opening, s4_carried_lots and
s4_prefix_opening_sweep:
- crossover_3x40, final_pulse_trades, reconciliation_stop;
- s2_sizing_batch, s3_mixed_transition, s3_multi_stop;
- sell_buy_same_pulse, tight_cash;
- witness_capacity, witness_max_pulses, witness_nonfinite,
  witness_prefix_reads, witness_prefix_reads_sweep,
  witness_state_container, witness_state_refusal, witness_sweep,
  witness_zero_pulses.

`<IN>`: Cut 19's inert list plus s4_carried_lots and s4_basis_unknown:
- crossover_3x40, reconciliation_stop, s2_sizing_rebalance,
  s3_freeze_exit, tight_cash;
- witness_surface_seeded, witness_sweep, witness_zero_pulses.

The targeted run's lean code differs from 0c6b88f9 in two places only. Both
came later and change no lean behaviour:
- a header comment in `loop.R`;
- the `frozen_opening_ignored` variant definition in the harness.

Superseded: a debug-1 gate on the original library finished at 19:37:57,
after the deletion. It is not used as evidence. Its execution paths equal
the rebuild's on all 119 workloads.
