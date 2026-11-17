# LDG-3245 evidence: commands

Workstream 39's close checks on the final code (LDG-3243 and LDG-3244).
The gate, batch-one, inert, witness, moves, lines and cross-check outputs are
on 754b9889, after close review round 1's F1 fix; the variant driver ran on
f41c5088, and the variants the fix touches or adds were rerun on 754b9889's
code (`evidence/cut21/ldg3244/f1_variants/`). `<pin>` is the rebuilt pin library
`C:/Users/maxth/ledgr-wt/pin-lib-d5b3a151` (see
`evidence/cut21/ldg3243/COMMANDS.md`). Commands run from the package root.

| file | command |
| --- | --- |
| gate_debug0.csv/.log, gate_debug1.csv/.log | `Rscript dev/lean_core/parity/loop_parity.R --lib=<pin> --debug=<0/1> --freeze=dev/lean_core/parity/loop_freeze.csv --out=<file>` |
| batch1_debug0.csv/.log, batch1_debug1.csv/.log | `Rscript dev/lean_core/parity/loop_parity.R --lib=<pin> --debug=<0/1> --batch-rows=1 --workloads=<B1> --freeze=dev/lean_core/parity/loop_freeze.csv --out=<file>` |
| inert_debug0.csv/.log, inert_debug1.csv/.log | `Rscript dev/lean_core/parity/loop_parity.R --lib=<pin> --debug=<0/1> --inert=1 --workloads=<IN> --freeze=dev/lean_core/parity/loop_freeze.csv --out=<file>` |
| variants/, variants_debug0.log, variants_debug1.log | `Rscript dev/lean_core/parity/loop_variants.R --lib=<pin> --out=dev/lean_core/parity/evidence/cut21/ldg3245/variants --debug=<0/1>` |
| witness/, witness.log | `Rscript dev/lean_core/parity/hashed_frame_witness.R --lib=<pin> --out=dev/lean_core/parity/evidence/cut21/ldg3245/witness` |
| slice4_reach_cross_ws39.csv | `Rscript dev/lean_core/parity/slice4_reach_cross.R --lib=<pin> --dump=<dir> --set=ws39 --out=<file>`, where `<dir>` holds the pin dumps of `loop_parity.R --debug=0 --dump=<dir>` over the 27 workloads of the set (the pin's tables do not depend on the lean code) |
| frozen_moves.csv | `Rscript dev/lean_core/parity/evidence/cut21/ldg3245/moves.R --base=381c0d0c --out=<file>` |
| lines.csv | `Rscript dev/lean_core/parity/cut19_lines.R --base=381c0d0c --final=754b9889 --out=<file>` |
| summary | `Rscript dev/lean_core/parity/evidence/cut21/ldg3245/summarize.R` |

`<B1>`: LDG-3243's batch-one list plus LDG-3244's six:
- crossover_3x40, final_pulse_trades, reconciliation_stop;
- s2_sizing_batch, s3_mixed_transition, s3_multi_stop;
- sell_buy_same_pulse, tight_cash;
- witness_capacity, witness_max_pulses, witness_nonfinite,
  witness_prefix_reads, witness_prefix_reads_sweep,
  witness_state_container, witness_state_refusal, witness_sweep,
  witness_zero_pulses;
- s4_opening, s4_carried_lots, s4_prefix_opening_sweep;
- s4_dividend, s4_dividend_mixed, s4_dividend_skip, s4_cash_refused,
  s4_prefix_dividend_sweep, s4_carried;
- the F1 capacity witnesses: s4_capacity_block, s4_capacity_prefix,
  s4_capacity_after_fill, s4_capacity_fill, s4_capacity_after_fill_run,
  s4_capacity_fill_run.

`<IN>`: LDG-3243's inert list plus LDG-3244's five (the prefix-observer
workloads need the harness hooks, so the capacity witnesses run under inert
hooks in their plain forms):
- crossover_3x40, reconciliation_stop, s2_sizing_rebalance,
  s3_freeze_exit, tight_cash;
- witness_surface_seeded, witness_sweep, witness_zero_pulses;
- s4_carried_lots, s4_basis_unknown;
- s4_dividend, s4_dividend_mixed, s4_capacity_block,
  s4_capacity_after_fill_run, s4_capacity_fill_run.

The F1 runs in `evidence/cut21/ldg3244/`: `f1_targeted_debug*.csv`,
`f1_batch1_debug*.csv` and `f1_inert_debug*.csv` are `loop_parity.R` over the
capacity witnesses with s4_cash_overflow, the three dividend prefix workloads
and s4_dividend_mixed (inert: the five without the prefix observer), with
754b9889's lean code before its predicates were added; `f1_variants/` holds
`loop_parity.R --mutation=<m>` for capacity_check_dropped and the variants
anchored beside the change (capacity_late, commit_late,
capture_validation_deferred, captured_row_dropped, capture_lost_at_growth,
nonfill_commit_late) on their registered workloads.

The per-change proofs of LDG-3244 (targeted runs on bdeb3e69, before the
emitter moved to facts.R, the capture's capacity was reported and its block
list was detached while written) are in `evidence/cut21/ldg3244/`; the
checks above supersede them on the final code (tiered proofs).
