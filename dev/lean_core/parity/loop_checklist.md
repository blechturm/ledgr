# LDG-3219 obligation checklist

Every obligation the compact-state lean loop answers to, from the accepted
text and the three close-review rounds, mapped to one executable witness
and to the broken variant that witness must reject. Written before the
consolidation code (maintainer, 2026-11-11: fix and consolidate). A row is
done only when its witness passes on the code and rejects its broken
variant; `loop_parity.R --mutation=` runs the variants.

Sources: A = LDG-3219 acceptance (tickets.yml); S = interface Section 19
(19.1-19.6); D = diagnostic-records D3 synthesis (Sections 1-3, 5, D3-B);
R1-R3 = close review rounds 1-3 (C:/Users/maxth/ledgr-wt/ws30-close-out*).

## Results

| # | Obligation | Source | Witness | Broken variant it must reject |
| --- | --- | --- | --- | --- |
| 1 | Every run-store table, reader, condition, sweep result and the caller's RNG identical to the pin on every covered workload, debug off and on | A1, S19.6 | full gate, both modes | fill_price_ulp, drop_hold, hold_position |
| 2 | Contracted strategy-output refusals stay in production: targets, intent reason, state patch container and fields, replacement, reset | S19.4, R3-1, AGENTS | witness_state_container (atomic patch, run and asset field), witness_nonfinite, surface | patch_container (fast path skips the list check) |
| 3 | Zero pulses: the pin's empty result (DONE, processed 0, no completion evidence) | S19.1, R3-5 | witness_zero_pulses (validated spec at the envelope) | zero_pulse_completion (completion row built anyway) |
| 4 | Fresh context per pulse; every public read, retained unforced fields, the read methods' values and refusals (any name) | S19.4, S19.1 | surface witnesses; debug comparison per pulse | read_fast_path (a malformed name taken on the fast path) |

## Coverage and backstop

| # | Obligation | Source | Witness | Broken variant |
| --- | --- | --- | --- | --- |
| 5 | Each uncovered feature refused before the first pulse, naming it, run on the pin; none runs partly | A3, S19.2 | gate refusals; witness_checkpoint_control / _null; witness_walk_forward | entry_guard_off (entry refusals ignored) |
| 6 | Walk-forward refused at entry | S19.2, R3-3 | witness_walk_forward | entry_guard_off |
| 7 | A missed history or sizing call aborts the whole attempt and reruns the complete workload on the pin with the entry RNG, whether uncaught, caught by the strategy, caught then rethrown, or caught by the caller around the workload; sweeps included | A2, S19.2, R1-1, R2-1, R3-2 | witness_backstop(_sweep), witness_caught_backstop(_sweep), witness_caught_rethrow(_sweep), witness_outer_handler | backstop_off (the attempt mark ignored) |

## D3 protocol

| # | Obligation | Source | Witness | Broken variant |
| --- | --- | --- | --- | --- |
| 8 | No store statement and no terminal-sink call while pulses run | A4, D Section 5, R1-4, R2-4, R3-4 | detectors silent on every gate workload | store_in_loop (dbExecute, ledgr_store_append, a prepared dbBind insert on a scratch store); write_in_loop (handler) |
| 9 | No hold expansion while pulses run | A4, S19.6 | hold counter zero on every gate workload | hold_in_loop |
| 10 | P5 capacity refusal on its original pulse, before reconciliation, independent of the terminal bound | D3-B, R1-2 | witness_capacity at batch 1 and 65,536 | capacity_late (check moved to the terminal transfer) |
| 11 | Commitment at the pin's flush point; reads during the run see exactly the committed prefix, before each callback and at reconciliation, through a later P5 refusal | D Section 1, S19.1, R1-2, R2-2 | witness_prefix_reads(_sweep), witness_state_refusal | commit_late (commitment after state validation) |
| 12 | Terminal transfer bounded: ranges expanded one at a time, each table written in batches of at most the bound, durable events drained per batch | D Sections 1-2, R1-3 | batch-one parity on 12 workloads; append audit | expand_whole (whole run expanded before batching) |
| 13 | A terminal fault after a completed events append rolls back every transfer | D Section 5, R1-3, R2-3 | batch_fault | fault_before_append (fault before any events append must not count as the witness) |
| 14 | checkpoint_every: only the pin's default and no control key, NULL included | D Section 2, R1-5 | witness_checkpoint_control, witness_checkpoint_null | entry_guard_off |

## Code shape (consolidation, maintainer 2026-11-11)

| # | Obligation | Witness |
| --- | --- | --- |
| 15 | loop.R holds the fold only: no harness record, no witness branch; it reaches the harness through one hooks object whose default is inert | `grep lean_entry dev/lean_core/loop.R` is empty; the gate passes with the inert hooks (no harness installed) on a covered workload |
| 16 | One backstop path: a stub or the loop marks the attempt; one check at the callback boundary; lean_loop_run reruns on any mark | code inspection; rows 7 |
| 17 | Mutations and witness faults applied from the harness, except the two that must act inside the loop, which use the hooks' per-pulse point | code inspection; rows 8, 9, 13 |
| 18 | Production code within budget; debug, hooks and harness reported beside it | role count at close |
