# LDG-3219 obligation checklist

The obligations the compact-state lean loop answers to, from the accepted
text and the four close-review rounds. Behavioural obligations map to one
executable witness and the broken variants that witness must reject;
measurements and analyses map to their evidence; D3's close census
(Section 5) maps each case to a witness, a refusal with its later owner, or
an open entry. A behavioural row is done only when its witness passes and
rejects each of its variants for the signal the variant expects (the CSV's
`expect` and `signals` columns); `loop_parity.R --mutation=` runs them and
`loop_mutations.sh` runs all of them in both debug modes.

Sources: A = LDG-3219 acceptance (tickets.yml); S = interface Section 19
(19.1-19.6); D = diagnostic-records D3 synthesis; R1-R4 = close review
rounds 1-4 (C:/Users/maxth/ledgr-wt/ws30-close-out*).

## Results

| # | Obligation | Source | Witness | Broken variants it must reject |
| --- | --- | --- | --- | --- |
| 1 | Every run-store table, reader, condition, sweep result and the caller's RNG identical to the pin on every covered workload, debug off and on | A1, S19.6 | full gate, both modes | fill_price_ulp, drop_hold, hold_position |
| 2 | Contracted strategy-output refusals stay in production: targets, intent reason, state patch container and fields, replacement, reset | S19.4, R3-1, AGENTS | witness_state_container (atomic patch, run and asset field), witness_nonfinite, surface | patch_container (debug off; with debug on the per-pulse comparison calls the pin's validator) |
| 3 | Zero pulses: the pin's full return (telemetry aside) and empty evidence, on the fold's state axis and on a reordered incoming axis | S19.1, R3-5, R4-2 | witness_zero_pulses | zero_pulse_completion (completion built anyway); zero_pulse_align (first-pulse alignment on an empty run) |
| 4 | Fresh context per pulse; every public read, retained unforced fields, the read methods' values and refusals (any name) | S19.4, S19.1 | surface witnesses; debug comparison per pulse | read_fast_path (debug on only: no production witness discriminates it) |

## Coverage and backstop

| # | Obligation | Source | Witness | Broken variants |
| --- | --- | --- | --- | --- |
| 5 | Each uncovered feature refused before the first pulse, naming it, run whole on the pin | A3, S19.2 | gate refusals (recorded, not each asserted); asserted names: witness_checkpoint_control / _null, witness_walk_forward, witness_sweep_workers | entry_guard_off; workers_guard_off |
| 6 | Orchestration exclusions the fold cannot see, refused at public entry by the harness: a checkpoint_every key, walk-forward, a sweep with workers. Section 19.1 records them as obligations for whoever wires the fold in | S19.1, S19.2, R3-3, R4-3 | witness_walk_forward, witness_checkpoint_null, witness_sweep_workers | entry_guard_off; workers_guard_off |
| 7 | A missed history or sizing call aborts the whole attempt and reruns the complete workload on the pin with the caller's entry RNG state (seed or its absence, and the kinds), whether uncaught, caught by the strategy, caught then rethrown, or caught by the caller; sweeps included. The entry state is set outside the rerun workload | A2, S19.2, R1-1, R2-1, R3-2, R4-1 | witness_backstop(_sweep), witness_backstop_kind (no seed, non-default kind), witness_caught_backstop(_sweep), witness_caught_rethrow(_sweep), witness_outer_handler | backstop_off (mark ignored); rng_restore_off (rerun without restoring) |

## D3 protocol

| # | Obligation | Source | Witness | Broken variants |
| --- | --- | --- | --- | --- |
| 8 | No store statement and no terminal-sink call while pulses run, on every store path | A4, D5, R1-4, R2-4, R3-4, R4-4 | detectors silent on every gate workload | store_execute, store_bind (statement prepared before the pulses), store_query, store_append: one path each; write_in_loop (handler) |
| 9 | No hold expansion while pulses run | A4, S19.6 | hold counter zero on every gate workload | hold_in_loop |
| 10 | P5 capacity refusal on its original pulse, after earlier accepted pulses, independent of the terminal bound: class, message, stage, pulse time | D3-B, D5, R1-2 | witness_capacity at batch 1 and 65,536 | capacity_late (check removed) |
| 11 | Commitment at the pin's flush point; reads during the run see exactly the committed prefix, before each callback and at reconciliation, through a later P5 refusal | D1, S19.1, R1-2, R2-2 | witness_prefix_reads(_sweep), witness_state_refusal | commit_late |
| 12 | Terminal transfer bounded: each expansion, counted where it is built, spans one range; each table written in batches of at most the bound; durable events drained per batch | D1-2, R1-3, R4-4 | batch-one parity; append and range audit | expand_whole (whole run in one range); expand_extra (an extra whole-run expansion beside the bounded transfer) |
| 13 | A terminal fault after a completed events append rolls back every transfer | D5, R1-3, R2-3 | batch_fault | fault_before_append (a fault with no earlier events append must not count) |
| 14 | checkpoint_every: only the pin's default and no control key, NULL included | D2, R1-5 | witness_checkpoint_control, witness_checkpoint_null | entry_guard_off |

## D3 close census (D Section 5)

| Case | Disposition |
| --- | --- |
| Empty run; batch size one; a pulse spanning batches; several batches in one P5 | witnessed: witness_zero_pulses; batch-one parity (14 workloads) |
| Skips (scheduled decisions) | refused in slice 1 (schedules); owner: the slice that covers schedules |
| P1 effects then a P2/P3 stop | P2 stop: witness_nonfinite; P3 stop: reconciliation_stop. P1 non-fill effects (corporate actions, imports) refused; owner: their slice |
| Cut 13 R1 affordability stop; max_pulses | witnessed: reconciliation_stop; witness_max_pulses |
| INCOMPLETE with a zero-valued equity row | open: not separately witnessed |
| Growth | witnessed: fill-heavy and 500 x 1,260 grow past the initial record capacity (loop_memory.csv) |
| Dirty reuse | not applicable: lean records are allocated per fold and never reused (code inspection) |
| Immutable recorder captures; pre-commit leg visibility | open: prefix reads compare counts and digests, not a held capture after later pulses or leg-level visibility |
| Candidate isolation | witnessed: one-worker sweeps (witness_sweep, prefix and backstop sweeps) |
| Processing and terminal-transfer errors | witnessed: witness_nonfinite, witness_state_refusal, batch_fault. Leg-level handler exceptions: open |
| Real interrupts | open: not executed |
| Post-commit finalization recovery | pin-owned: finalization runs after the fold, unchanged; not re-witnessed |
| Nonterminal fresh restart | refused in slice 1 (restart); owner: its slice |
| Checkpoint entry restriction; store-write wrap; middle-batch rollback | rows 14, 8, 13 |

The open rows are for the maintainer: close them in this ticket or record
them in the switch cut's census, which cannot ship with any case unowned.

## Measurements and analyses (evidence, not variants)

| Obligation | Source | Evidence |
| --- | --- | --- |
| Record capacities, terminal peak and the exception-heavy case | D2, D5 | evidence/loop_memory.csv; ticket "Memory" |
| Whole-run timing against the pin, us per pulse, PMwR reference | A5 | dev/bench/timing/records/cut13-loop-1/ldg3219-gate-r1/attempt-1; ticket "Timing" |
| Rough measurement before hardening | S19.6 | the tuning profiles (dev/bench/v0_2_3_lean_tuning_profile) and the first timing record (ldg3219-gate/attempt-1) |
| Subtraction review and unused code | A6, S19.6 | ticket "Budget and subtraction" (codetools::checkUsage) |
| Five affected owners | A6, S19.6 | ticket "Rules ledger": an analysis against the code, not an executed probe |
| Module properties debug on | S19.6 | rows 1-14 run with debug on (loop_mutations_debug1.csv) |

## Code shape (consolidation, maintainer 2026-11-11)

| # | Obligation | Witness |
| --- | --- | --- |
| 15 | loop.R holds the fold only: no harness record, no witness branch; it reaches the harness through one hooks object whose default is inert | `grep lean_entry dev/lean_core/loop.R` is empty; the gate passes with inert hooks on covered workloads, and a variant loaded in that mode changes the output |
| 16 | One backstop path: a stub or the loop marks the attempt; one check at the callback boundary; lean_loop_run reruns on any mark | code inspection; row 7 |
| 17 | Variants are text patches applied at load; the tracked fold holds no variant branch | code inspection |
| 18 | Production code within budget; debug and harness reported beside it | role count at close |
