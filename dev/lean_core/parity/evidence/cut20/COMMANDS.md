# Cut 20 evidence: commands

From the package root, pin library `<pin>` (d5b3a151). `<dump>` is a local
directory of the pin's tables, written by the debug-off gate and read by the
reach cross-checks; it is not committed.

## LDG-3241 (ldg3241/)

| file | command |
| --- | --- |
| ldg3241/loop_gate_debug0.csv | `Rscript dev/lean_core/parity/loop_parity.R --lib=<pin> --debug=0 --freeze=dev/lean_core/parity/loop_freeze.csv --out=<file>` |
| ldg3241/witness/, witness.log | `Rscript dev/lean_core/parity/hashed_frame_witness.R --lib=<pin> --out=dev/lean_core/parity/evidence/cut20/ldg3241/witness` |
| ldg3241/reanchor/ | `Rscript dev/lean_core/parity/cut20_reanchor.R --lib=<pin> --out=dev/lean_core/parity/evidence/cut20/ldg3241/reanchor` |
| shape7.txt | `Rscript dev/lean_core/parity/cut20_shape7.R dev/lean_core/parity/evidence/cut20/shape7.txt` |
| frame census | `Rscript dev/lean_core/parity/evidence/cut19/s3env/ebind.R 6e90a881 dev/lean_core/loop.R` (140 -> 140) |

The witness writes frame_checks.csv (part A: four fault settings by two
debug settings), adapter.csv with one log and CSV per adapter run (part B),
and semantics.csv (part C).

## LDG-3242 (proofs_final/, timing/, lines.csv)

Final check set on c16b4d5b; `<freeze>` is
`dev/lean_core/parity/loop_freeze.csv`, `<p>` is `dev/lean_core/parity`.

| file | command |
| --- | --- |
| proofs_final/loop_gate_debug0.csv | `Rscript <p>/loop_parity.R --lib=<pin> --debug=0 --freeze=<freeze> --out=<file> --dump=<dump>` |
| proofs_final/loop_gate_debug1.csv | `Rscript <p>/loop_parity.R --lib=<pin> --debug=1 --freeze=<freeze> --out=<file>` |
| proofs_final/variants/ | `Rscript <p>/loop_variants.R --lib=<pin> --out=<dir> --debug=0`, then `--debug=1` |
| proofs_final/loop_batch1.csv, loop_batch1_debug1.csv | `Rscript <p>/loop_parity.R --lib=<pin> --debug=0\|1 --batch-rows=1 --workloads=<batch one> --freeze=<freeze> --out=<file>` |
| proofs_final/loop_inert.csv, loop_inert_debug1.csv | `Rscript <p>/loop_parity.R --lib=<pin> --debug=0\|1 --inert=1 --workloads=<inert list> --freeze=<freeze> --out=<file>` |
| proofs_final/loop_dispatch.csv | `Rscript <p>/loop_dispatch.R --lib=<pin> --out=<file>` |
| proofs_final/plan_parity_debug0.csv, _debug1.csv | `Rscript <p>/plan_parity.R --lib=<pin> --debug=0\|1 --out=<file>` |
| proofs_final/cut18_witness_final.csv | `Rscript <p>/cut18_witness.R --lib=<pin> --out=<file>` |
| proofs_final/slice2_reach_cross.csv, slice3_reach_cross.csv | `Rscript <p>/slice2_reach_cross.R --lib=<pin> --dump=<dump> --out=<file>` (and slice3) |
| fifo_check.R | `Rscript <p>/fifo_check.R --lib=<pin> --captures=<captures> --tests=<tests> --scratch=<dir>` (CHECK PASSED; not a committed file) |
| proofs_final/witness/ | `Rscript <p>/hashed_frame_witness.R --lib=<pin> --out=<dir>` |
| timing/compare_* | under High performance and `dev/bench/v0_2_3_lean_tuning_profile/pcore.ps1`: `Rscript <p>/loop_shortcuts.R --lib=<pin> --mode=compare --base=6e90a881 --candidate=c16b4d5b --rounds=7 --shapes=10x7200,20x23400,500x1260,slice2_10x7200 --out=<dir>` (exact command in compare_command.txt) |
| timing/keep_* | `Rscript <p>/cut20_keep.R --raw=dev/lean_core/parity/evidence/cut20/timing/compare_raw.csv --out=dev/lean_core/parity/evidence/cut20/timing` (verdict open; exit 1) |
| lines.csv | `Rscript <p>/cut19_lines.R --base=6e90a881 --final=c16b4d5b --out=<file>` (role count as in LDG-3219) |

Batch one: crossover_3x40,final_pulse_trades,reconciliation_stop,s2_sizing_batch,s3_mixed_transition,s3_multi_stop,sell_buy_same_pulse,tight_cash,witness_capacity,witness_max_pulses,witness_nonfinite,witness_prefix_reads,witness_prefix_reads_sweep,witness_state_container,witness_state_refusal,witness_sweep,witness_zero_pulses. Inert list: crossover_3x40,reconciliation_stop,s2_sizing_rebalance,s3_freeze_exit,tight_cash,witness_surface_seeded,witness_sweep,witness_zero_pulses.
Timing record cut20-loop-1
(dev/bench/timing/records/cut20-loop-1/ws38-final/attempt-1), under pcore.ps1:
`dev/bench/timing/runner.R --protocol=dev/bench/timing/protocols/cut20-loop-1 --base=d5b3a151 --candidate=d5b3a151 --label=ws38-final --candidate-overlay=dev/lean_core,dev/bench/v0_2_3_lean_tuning_profile/descriptors.R,dev/spikes/r_floor/fixture.R`,
then `Rscript dev/bench/timing/check.R --protocol=dev/bench/timing/protocols/cut20-loop-1 --record=dev/bench/timing/records/cut20-loop-1/ws38-final/attempt-1`.

## Close review round 1 corrections (review/)

| file | command |
| --- | --- |
| review/keep_refusals/ | `Rscript dev/lean_core/parity/cut20_keep_refusals.R --out=dev/lean_core/parity/evidence/cut20/review/keep_refusals` |
| review/witness/, witness.log | `Rscript dev/lean_core/parity/hashed_frame_witness.R --lib=<pin> --out=dev/lean_core/parity/evidence/cut20/review/witness` |

## Close review round 2 corrections (review/)

| file | command |
| --- | --- |
| review/witness_round2/, witness_round2.log | `Rscript dev/lean_core/parity/hashed_frame_witness.R --lib=<pin> --out=dev/lean_core/parity/evidence/cut20/review/witness_round2` |
| review/scan_gut.txt | `Rscript dev/lean_core/parity/evidence/cut20/review/scan_gut.R <round-1 witness> dev/lean_core/parity/hashed_frame_witness.R`, the round-1 witness being `git show e83cf032:dev/lean_core/parity/hashed_frame_witness.R` saved to a file |

## Close review round 3 correction (review/)

| file | command |
| --- | --- |
| review/witness_round3/, witness_round3.log | `Rscript dev/lean_core/parity/hashed_frame_witness.R --lib=<pin> --out=dev/lean_core/parity/evidence/cut20/review/witness_round3` |
| review/scan_gut.txt, scan_gut_round2.txt | `Rscript dev/lean_core/parity/evidence/cut20/review/scan_gut.R <earlier witness> dev/lean_core/parity/hashed_frame_witness.R`, the earlier witness being `git show e83cf032:...` (round 1's scan) or `git show e7627f34:...` (round 2's) of `dev/lean_core/parity/hashed_frame_witness.R`, saved to a file |
