# Cut 19 evidence: commands

From the package root, pin library `<pin>` (d5b3a151), on the final lean
code (fc0a0b8c; the harness as committed with these proofs). `<dump>` is a
local directory of the pin's tables, written by the debug-off gate and read
by the reach cross-check; it is not committed.

| file | command |
| --- | --- |
| proofs/loop_gate_debug0.csv | `Rscript dev/lean_core/parity/loop_parity.R --lib=<pin> --debug=0 --out=<file> --freeze=dev/lean_core/parity/loop_freeze.csv --dump=<dump>` |
| proofs/loop_gate_debug1.csv | `Rscript dev/lean_core/parity/loop_parity.R --lib=<pin> --debug=1 --out=<file> --freeze=dev/lean_core/parity/loop_freeze.csv` |
| proofs/loop_batch1.csv, loop_batch1_debug1.csv | `Rscript dev/lean_core/parity/loop_parity.R --lib=<pin> --debug=<0/1> --batch-rows=1 --workloads=<B1> --out=<file> --freeze=dev/lean_core/parity/loop_freeze.csv` |
| proofs/loop_inert.csv, loop_inert_debug1.csv | `Rscript dev/lean_core/parity/loop_parity.R --lib=<pin> --debug=<0/1> --inert=1 --workloads=<IN> --out=<file> --freeze=dev/lean_core/parity/loop_freeze.csv` |
| proofs/variants/ | `Rscript dev/lean_core/parity/loop_variants.R --lib=<pin> --out=dev/lean_core/parity/evidence/cut19/proofs/variants --debug=<0/1>` |
| proofs/loop_dispatch.csv | `Rscript dev/lean_core/parity/loop_dispatch.R --lib=<pin> --out=<file>` |
| proofs/plan_parity_debug0.csv, plan_parity_debug1.csv | `Rscript dev/lean_core/parity/plan_parity.R --lib=<pin> --debug=<0/1> --out=<file>` |
| proofs/cut18_witness_final.csv | `Rscript dev/lean_core/parity/cut18_witness.R --lib=<pin> --out=<file>` |
| proofs/slice3_reach_cross.csv | `Rscript dev/lean_core/parity/slice3_reach_cross.R --lib=<pin> --dump=<dump> --out=<file>` |
| FIFO check (log only) | `Rscript dev/lean_core/parity/fifo_check.R --lib=<pin> --captures=<LDG-3213 captures> --tests=<LDG-3213 test captures> --scratch=<dir>` |
| lines.csv | `Rscript dev/lean_core/parity/cut19_lines.R --base=bdeea449 --final=fc0a0b8c --out=<file>` |
| frozen_moves.csv | `Rscript dev/lean_core/parity/cut19_moves.R --base=bdeea449 --out=<file>` |

`<B1>`: crossover_3x40, final_pulse_trades, reconciliation_stop,
s2_sizing_batch, s3_mixed_transition, s3_multi_stop, sell_buy_same_pulse,
tight_cash, witness_capacity, witness_max_pulses, witness_nonfinite,
witness_prefix_reads, witness_prefix_reads_sweep, witness_state_container,
witness_state_refusal, witness_sweep, witness_zero_pulses.

`<IN>`: crossover_3x40, reconciliation_stop, s2_sizing_rebalance,
s3_freeze_exit, tight_cash, witness_surface_seeded, witness_sweep,
witness_zero_pulses.

frozen_moves.csv: the effective freeze (loop_freeze.csv with
loop_freeze_changes.csv applied in order) at bdeea449 against the working
tree; a path is `lean_folds | refused | backstop`, `(absent)` a row that
did not exist.

The reach cross-check refuses a missing dump: run against a dump directory
with one slice-3 workload removed, it exits 1.

Timing record cut19-loop-1 (dev/bench/timing/records/cut19-loop-1/), under
the High performance plan with P-core affinity:
`pcore.ps1 <log> dev/bench/timing/runner.R --protocol=dev/bench/timing/protocols/cut19-loop-1 --base=d5b3a151 --candidate=d5b3a151 --label=ws37-final --candidate-overlay=dev/lean_core,dev/bench/v0_2_3_lean_tuning_profile/descriptors.R,dev/spikes/r_floor/fixture.R`,
then `Rscript dev/bench/timing/check.R --protocol=dev/bench/timing/protocols/cut19-loop-1 --record=dev/bench/timing/records/cut19-loop-1/ws37-final/attempt-1`;
the Balanced plan restored afterwards.

Paired comparisons (timing/cmp1-3; High performance plan, P-core affinity
through `pcore.ps1`, Balanced restored afterwards):
`loop_shortcuts.R --lib=<pin> --mode=compare --base=bdeea449 --candidate=<fc0a0b8c | worktree> --rounds=7 --shapes=10x7200,20x23400,500x1260,slice2_10x7200 --out=<dir>`;
cmp1 on fc0a0b8c, cmp2 on the working tree with the s3 environment only,
cmp3 with the decision-row fix as well (the identity files hold each arm's
source hashes).

Frame-binding experiment (s3env/): `stages.R <shape> <rounds> <commitA> <commitB>`
times P1-P5 per pulse on both arms, alternating; an arm `<commit>+dummy`
adds twelve `NULL` bindings after `nd <- 0L`, and `stages_top.R` with
`<commit>+dummytop` adds them at the envelope's first line. `ebind.R
<commitA> <commitB|file>` lists the names bound at the envelope body's top
level. `frame_demo.R` is the scratch demonstration of lookups through a plain
and a hashed frame. The probes read the pinned library at the scratchpad path
recorded in them.

Cheap proofs of the refactor (s3env/s3env*_gate0/1, _b1, v_*): `loop_parity.R`
with `--workloads=<the 37 slice-3 workloads and 17 slice-1/2 and witness
workloads>` and `--freeze`, debug 0 and 1; batch one on s3_mixed_transition
and s3_multi_stop; each moved or touched variant with `--mutation=<name>
--workloads=<its workload>`.
