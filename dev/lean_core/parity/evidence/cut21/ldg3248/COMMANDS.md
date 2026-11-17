# LDG-3248 evidence: commands

Workstream 40's close checks on its final code (LDG-3246 and LDG-3247), and
the per-ticket proofs of LDG-3246 and LDG-3247 (`evidence/cut21/ldg3246/`,
`evidence/cut21/ldg3247/`). `<pin>` is the rebuilt pin library
`C:/Users/maxth/ledgr-wt/pin-lib-d5b3a151` (see
`evidence/cut21/ldg3243/COMMANDS.md`); `<p>` is `dev/lean_core/parity`.
Commands run from the package root. A workload list in angle brackets is
spelled out below the table.

| file | command |
| --- | --- |
| gate_debug0.csv/.log, gate_debug1.csv/.log | `Rscript <p>/loop_parity.R --lib=<pin> --debug=<0/1> --freeze=<p>/loop_freeze.csv --out=<file>` (debug 0 also `--dump=<dir>`, the pin dumps for the reach cross-check) |
| batch1_debug0.csv/.log, batch1_debug1.csv/.log | `Rscript <p>/loop_parity.R --lib=<pin> --debug=<0/1> --batch-rows=1 --workloads=<B1> --freeze=<p>/loop_freeze.csv --out=<file>` |
| inert_debug0.csv/.log, inert_debug1.csv/.log | `Rscript <p>/loop_parity.R --lib=<pin> --debug=<0/1> --inert=1 --workloads=<IN> --freeze=<p>/loop_freeze.csv --out=<file>` |
| variants/, variants_debug0.log, variants_debug1.log | `Rscript <p>/loop_variants.R --lib=<pin> --out=dev/lean_core/parity/evidence/cut21/ldg3248/variants --debug=<0/1>` |
| witness/, witness.log | `Rscript <p>/hashed_frame_witness.R --lib=<pin> --out=dev/lean_core/parity/evidence/cut21/ldg3248/witness` |
| loop_dispatch.csv | `Rscript <p>/loop_dispatch.R --lib=<pin> --out=<file>` |
| plan_parity_debug0.csv, plan_parity_debug1.csv | `Rscript <p>/plan_parity.R --lib=<pin> --debug=<0/1> --out=<file>` |
| cut18_witness.csv | `Rscript <p>/cut18_witness.R --lib=<pin> --out=<file>` |
| fifo_check.log | `Rscript <p>/fifo_check.R --lib=<pin> --captures=<captures> --tests=<tests> --scratch=<empty dir>`, the captures from `Rscript dev/lean_core/recorder/run.R --lib=<pin> --captures=<captures> --boundaries=lot` and the test captures from `Rscript <p>/fifo_capture_tests.R --src=<pinned source archive> --out=<tests>` (the archive: `git archive d5b3a151` with a `LEDGR_SOURCE_COMMIT` file reading d5b3a151); captures are large and not committed |
| slice4_reach_cross.csv | `Rscript <p>/slice4_reach_cross.R --lib=<pin> --dump=<dir> --set=slice4 --out=<file>`, `<dir>` the debug-0 gate's pin dumps |
| coverage_scan.txt | `git grep -n -e "lean_not_covered(" -e "lean_abort_attempt(" -- dev/lean_core/*.R` |
| frozen_moves.csv | `Rscript dev/lean_core/parity/evidence/cut21/ldg3245/moves.R --base=381c0d0c --out=<file>` |
| lines.csv | `Rscript <p>/cut19_lines.R --base=381c0d0c --final=<final commit> --out=<file>` |

`<B1>`: workstream 39's batch-one list (LDG-3245 COMMANDS.md) plus
workstream 40's eleven: s4_acq_fills, s4_moves_growth, s4_p1_complete,
s4_p1_then_stop, s4_terminal_choices, s4_subset, s4_state_context,
s4_membership, s4_v201_default, s4_bound_dispose, s4_prefix_dispose_sweep.

`<IN>`: workstream 39's inert list plus workstream 40's five: s4_v201_default,
s4_subset, s4_acq_held, s4_terminal_choices, s4_p1_then_stop.

## Timing (prepared, not run here)

The timing record and the paired comparison need the High performance power
plan and a quiet machine (`reference_timing_gate_host`): run them under
`dev/bench/v0_2_3_lean_tuning_profile/pcore.ps1` (affinity 0xFFFF), after
checking the active plan, from the package root at the final commit.

1. Timing record cut21-loop-1 (decision 13; protocol
   `dev/bench/timing/protocols/cut21-loop-1`, the pin against the final lean
   loop on Cut 15's four shapes and slice2_10x7200, eight alternating pairs,
   bound 1.0, plus the facts shape `facts_10x7200`, descriptive):

       Rscript dev/bench/timing/runner.R --protocol=dev/bench/timing/protocols/cut21-loop-1 --base=d5b3a151 --candidate=d5b3a151 --label=ws40-final --candidate-overlay=dev/lean_core,dev/bench/v0_2_3_lean_tuning_profile/descriptors.R,dev/spikes/r_floor/fixture.R
       Rscript dev/bench/timing/check.R --protocol=dev/bench/timing/protocols/cut21-loop-1 --record=dev/bench/timing/records/cut21-loop-1/ws40-final/attempt-1

2. Cut 18's paired comparison against 381c0d0c on the four comparison
   shapes under Cut 15's 5 percent rule (as LDG-3245's early comparison,
   with the final commit as candidate):

       Rscript dev/lean_core/parity/loop_shortcuts.R --lib=<pin> --mode=compare --base=381c0d0c --candidate=<final commit> --rounds=7 --shapes=10x7200,20x23400,500x1260,slice2_10x7200 --out=dev/lean_core/parity/evidence/cut21/ldg3248/timing

## Probes (unregistered)

`probes/probe_debug0.csv`, `probe_debug1.csv`, `probe_b1_debug0.csv`, `probe_b1_debug1.csv`:
`Rscript dev/lean_core/parity/evidence/cut21/ldg3248/probes/probe_runner.R --lib=<pin> --debug=<0/1> [--batch-rows=1] --workloads=p_terminal_first,p_stop_first,p_acq_first,p_many_facts,p_empty_first,p_sweep_terminal --out=<file>`
(loop_parity.R's text with `probes/probe_workloads.R` added to its workload list; no freeze).

## Close review round 2 (review2/)

The same commands with the review2 paths, on the round-2 lean code; the
batch-one list is `<B1>` plus the nine F3 witnesses s4_wrap_plan_p1,
s4_wrap_plan_p1_eq, s4_wrap_plan_p5, s4_wrap_plan_p5_eq, s4_wrap_life_p1,
s4_wrap_life_p1_eq, s4_wrap_life_p5, s4_wrap_life_p5_eq, s4_wrap_drain_run
(and the four F1 witnesses of round 1); the inert list is `<IN>` plus the
four F1 `_run` witnesses of round 1 and s4_wrap_plan_p1_run,
s4_wrap_plan_p1_eq_run, s4_wrap_plan_p5_run, s4_wrap_plan_p5_eq_run,
s4_wrap_drain_run. Variants: one loop_parity.R `--mutation=` run per line
of `review2/variants/spec.txt` (`variant|workloads|debug|batch rows`).
`review2/unregistered/inert_seam_life_debug0.csv`: the four seam-room
lifetime `_run` witnesses under inert hooks, not registered (see LDG-3248's
round-2 evidence).

F2, `review2/fifo_census/` (scripts copied there; run from a scratch
directory holding the inputs, which are large and not committed):
`fifo_census.R --src=<pinned source archive> --out=censusA.csv` and again
to `censusB.csv` (each call's digest of list(book, input) with its test
file and test, in call order); `f2_diag.R` (digests of the fresh capture
`fifo_tests/`, same recipe, to `f2_capture_keys.rds`); `f2_final.R <dir>`
(the comparison: `f2_keys.txt`, `differing_digests.csv`,
`census_ab_differing_keys.csv`); `f2_byref.R` (`byref_digest.txt`, the one
difference outside test-rng-isolation.R reproduced with the pinned package).
