# LDG-3282 coverage matrix: what the recorded oracle covers

Cut 27 decision 7: record the new pin's oracle outcomes while both cores
exist. This matrix maps every family that the lean fold core synthesis
Section 5 requires, and every deletion-readiness merge witness, to one of:
- its recording on the live pin and the checker that survives the switch; or
- a named obligation that must be complete before the oracle it needs is
  retired.

The live pin (C:/Users/maxth/ledgr-wt/pin-lib-7f65733f and pin-src-7f65733f)
stays available until every obligation below is complete.

## Inputs this matrix was built from

- LDG-3279 audit: dev/lean_core/parity/evidence/ldg3279 (contracts.md
  LR-01..11 and LR-21..23 written; final at 11b84d08).
- LDG-3280 inventory: dev/lean_core/parity/evidence/ldg3280/census/inventory.csv
  (196 rows; decisions written, row ids R001..R196). It supplies the
  accepted ledger changes LR-27 and LR-28, both drafted and pending
  approval. Neither changes a recorded table: the telemetry clocks and
  counter are not in the gate tables, and no corpus input reaches the
  staging refusal.
- LDG-3281 coverage: dev/lean_core/parity/evidence/ldg3281 (the feature
  routes, fe_bar_native and fe_declared).

LDG-3283 checks that the evidence below matches these inputs at Cut 27's
close. If any of them changes before then, this matrix and the affected
records are regenerated and the checker and its controls rerun.

## The recording

| Corpus | Recorded on the pin 7f65733f | Records (out of tree) | Checker |
| --- | --- | --- | --- |
| Gate tables: all 235 gate workloads, every path and table, in A0 canonical form, errors that escape a workload included | loop_parity.R --dump (pin arm) | pin-outcomes-7f65733f/gate/<workload>.rds | oracle_check.R |
| Direct differential cases: 145 cut18 cases (R1-R5, W4, DBG), values and normalized complete conditions (class, fields, parent, recursively) | cut18_witness.R --dump | pin-outcomes-7f65733f/cut18/cut18_pin.rds | oracle_check.R |
| FIFO captured calls: every pin ledgr_lot_apply() call of the A0, momentum and fill-heavy workloads and of the test suite, with the pin's value or condition | the recorder lot captures and fifo_capture_tests.R (captures carry the pin's results) | recaptured on 7f65733f at LDG-3283 (two test-suite captures plus the recorder) and kept beside the records | fifo_parity.R compares the lean FIFO with the captured values |

The manifest (oracle_records.csv, oracle_tables.csv) and the README in this
directory define the build, the inputs, the canonical form, the clock
exclusions, the schemas, types and order, the row counts, the digests and
the retrieval location.

## Section 5 families

Workload names are the gate's (loop_parity.R and the
loop_workloads*.R files; A0 fixtures in dev/bench/v0_2_3_output_freeze).
Every family below is recorded in the gate records unless the last column
says otherwise. Obligation O1 applies to every gate row: after the switch,
the switched package has no pin arm, so Cut 28 must supply a candidate
runner that writes gate/<workload>_lean.rds from the switched package.

| Family | Gate workloads | Recorded | Surviving checker; open obligation |
| --- | --- | --- | --- |
| WS15 (1) quiet and fill-heavy runs | crossover_3x40, crossover_10x300, crossover_10x7200, crossover_20x23400, crossover_500x1260, momentum_40x504, fill_heavy_500x1260, prep_fixture | yes | oracle_check.R; O1 |
| WS15 (2) sizing: raw, mixed, helper, guard/rounding, zero/liquidation, unavailability | s2_sizing_* (14), s3_sizing_liquidate_frozen, s3_sizing_liquidate_stale, s3_sizing_unpriced | yes | oracle_check.R; O1 |
| WS15 (3) declared sessions, restrictions, stale/frozen marks, terminal/lifetime effects, empty axes | s3_sessions_full, s3_closed_sessions, s3_no_bar_session, s3_many_gaps, s3_tail_gap, s3_freeze_*, s3_frozen_*, s3_stale_reduction, s3_risk_mark_*, s4_terminal*, s4_frozen_*, s4_halt, avail_* | yes | oracle_check.R; O1 |
| Reordered, changing and empty axes; held nonmembers | s4_membership, s4_subset, s4_no_members_held, s4_nonmember_increase, s4_reread_nonmember, s3_mixed_transition | yes | oracle_check.R; O1 |
| WS15 (4) due and skipped schedules; schedule settlements | s3_sched_* (6), s3_skip_stop, s3_skip_stop_first, s4_blocked_scheduled, s4_blocked_group, s4_dividend_skip | yes | oracle_check.R; O1 |
| WS15 (5) opening and carried lots, corporate actions, continued final fills | s4_opening, s4_opening_sessions, s4_carried, s4_carried_lots, s4_dividend*, s4_acq_*, s4_cash_*, s4_quantity_*, s4_bound_dispose, s4_basis_*, final_pulse_trades, s5_restart_opening | yes | oracle_check.R; O1 |
| WS15 (6) stop-phase INCOMPLETE prefixes, exceptions, append and flush failure, rollback, restart, publication recovery | s4_prefix_*, s4_p1_then_stop, s4_p1_complete, s4_wrap_*, s4_life_capacity_*, s4_capacity_*, reconciliation_stop, witness_error_cleanup*, witness_caught_*, witness_outer_handler, witness_nonfinite, witness_state_refusal, witness_max_pulses, witness_zero_pulses, witness_capacity, s5_recover_completion, s5_reopen_incomplete, s5_restart_*, failures, avail_incomplete, avail_terminal_resume, s3_multi_stop, s3_stop_refuse | yes | oracle_check.R; O1. D3 census open rows: see below |
| WS15 (7) and Section 5: the maintainer's private reference (Sharadar) | none (vendor data stays private) | no | O2 |
| Late-known facts and pre-scoring history | s4_dividend_late, s4_stale_facts, s4_clock_missing, s4_entitlement_missing, s4_v201_default, s4_v201_refuse, s3_prescoring_gap, s3_hist_*, s3_offset_*, s3_prefix_declared | yes | oracle_check.R; O1 |
| Restricted exit and hold | s4_restricted_target, s4_restrictions, s3_freeze_exit, s3_frozen_liquidate | yes | oracle_check.R; O1 |
| Stale, frozen, terminal valuation and corporate-action priority | s3_stale_reduction, s3_frozen_increase, s4_terminal_choices, s4_terminal_no_mark, s4_terminal_refuse, s4_terminal_unlabeled, s4_frozen_writeoff, s4_frozen_lastmark | yes | oracle_check.R; O1 |
| Exact, guarded and unavailable sizing | s2_sizing_adjust, _batch, _combo, _notice, _reasons, _rebalance, _stale, _malformed*, s3_sizing_unpriced | yes | oracle_check.R; O1 |
| Stable-ID affordability versus decision-order publication | sell_buy_same_pulse, tight_cash, s2_cost_sale_consumes, s2_cost_insufficient | yes | oracle_check.R; O1 |
| Chained costs, dust, reversals, repeated lots | s2_cost_chain, s2_cost_fixed, s2_cost_notional, s2_cost_spread, s2_cost_nonpositive_price, s5_compiled_costs, s5_compiled_lots; the FIFO corpus (streams with dust and reversals) | yes | oracle_check.R; fifo_parity.R on the captures; O1, O3 |
| Continued final fills | final_pulse_trades, s4_prefix_dividend_bought | yes | oracle_check.R; O1 |
| Seeded and unseeded RNG, caller restoration | witness_surface_seeded, witness_surface_unseeded, witness_error_cleanup_seeded, and every workload that sets the caller's RNG state at entry (the harness's entry-RNG list) | yes | oracle_check.R; O1 |
| Worker-count equivalence | witness_sweep_workers, s5_workers_* (9), s5_walk_forward_workers, fe_* (two-worker routes) | yes | oracle_check.R; O1 |
| Both execution clocks | fe_bar_native, fe_declared, s3_hist_bar_native, s3_hist_declared, dense_cost, dense_dividend_state, dense_risk_features | yes | oracle_check.R; O1 |
| The accepted A0 successor records (A0 retired as anchor, Cut 27 decision) | the eight fixtures.R workloads: avail_acquisition, avail_incomplete, avail_terminal_resume, dense_cost, dense_dividend_state, dense_risk_features, failures, walk_forward | yes | oracle_check.R; O1 |
| Features end to end (LDG-3281) | fe_bar_native, fe_declared | yes | oracle_check.R; O1 |
| The overflow refusal (LR-26) | ovf_sell_1.9, ovf_hold_1.9, ovf_sell_10, ovf_delta_then_lot, ovf_lot_then_delta | yes | oracle_check.R; O1 |
| The compiled selector (LR-25) | s5_compiled_* (9), s5_workers_compiled_refused | yes | oracle_check.R; O1 |
| Walk-forward | walk_forward, witness_walk_forward, s5_walk_forward_costs, s5_walk_forward_workers | yes | oracle_check.R; O1 |
| Risk: binding and non-binding steps, chains, equity and short refusals, marks | s2_risk_* (6), s3_risk_mark_* (2) | yes | oracle_check.R; O1 |
| Missing execution bars and sessions | s3_exec_bar_missing, s3_missing_sweep, s3_gap_held | yes | oracle_check.R; O1 |
| Strategy state, the retained context and strategy errors | witness_state_container, witness_state_refusal, witness_retained_context, s4_state_context, witness_error_custom | yes | oracle_check.R; O1 |
| Committed-prefix reads (D3-B) and record growth | witness_prefix_reads, witness_prefix_reads_sweep, s4_moves_growth, s2_sizing_growth | yes | oracle_check.R; O1 |
| Harness controls that retire at the switch: the backstop seam and the checkpoint-control refusal | witness_backstop*, witness_caught_backstop*, witness_caught_rethrow*, witness_checkpoint_* (2) | yes | oracle_check.R while the harness exists. At the switch the backstop seam retires (19.14 obligation 5) and so does the checkpoint control (LR-20). Their records stay as pin evidence and leave the O1 comparison as listed differences. |
| Close and reopen, selection and promotion, seeds and identity | s5_reopen_incomplete, s5_recover_completion, witness_sweep, s2_sizing_sweep, s3_sched_sweep, s4_facts_sweep (sweep attrs and promotion tables are part of every sweep path's tables) | yes | oracle_check.R; O1 |

## Deletion-readiness merge witnesses

The seed v2 merges (Section 4) land in Cut 28. Their witnesses are the cut18
direct cases, which are recorded:

| Merge | Witness | Recorded | Surviving checker; open obligation |
| --- | --- | --- | --- |
| Strategy targets (4.1): lean_targets into ledgr_validate_strategy_targets, the unwrap step merged | R3 (21 cases) and the signal-strategy tests | yes (cut18) | oracle_check.R; O4 |
| Sizing evidence (4.2) | R4 (31) | yes (cut18) | oracle_check.R; O4 |
| Risk (4.3): one risk application in R/risk-model.R | R1 (22); the close-shape refusal has no witness | yes (cut18) | oracle_check.R; O4, O5 |
| Cost resolution (4.4): one batch resolve in R/cost-model.R | R2 (13); the two shape refusals have no witness | yes (cut18) | oracle_check.R; O4, O5 |
| Declared state (4.5): apply, field and value checks merged | R5 (42) | yes (cut18) | oracle_check.R; O4 |
| The debug comparator and the W4 cases | DBG (6), W4 (10) | yes (cut18) | oracle_check.R; O4 |

## The FIFO, applied-row and refusal proof corpus

| Part | Today | After the switch; obligation |
| --- | --- | --- |
| Captured calls (A0, momentum, fill-heavy and the test suite) | fifo_parity.R compares the lean FIFO with the captures' pin values | the captures are the records (O3) |
| Streams, simple cases, input refusals, mutations (fifo_streams.R, fifo_simple_cases.R, fifo_mutations.csv) | compared with the pinned kernel, live | R/lot-accounting.R stays the owner for replay, import and recovery (amendment_test_inventory (7)), so the same comparison runs against the switched package's own kernel; O3 |
| Population check (two independent captures) | fifo_population.R | O3 |

## Independent checks

| Check | Where it lives today | Obligation |
| --- | --- | --- |
| Registered mutations | loop_variants (gate variants, run on the live pin at LDG-3283), cut18 mutations, FIFO mutations, plan_parity mutations | After the switch, a mutation is caught when oracle_check.R fails on the mutated candidate's outputs (shown by the `mutated` control here). O6 rehosts the variant runner on the switched package. |
| Ownership | stage_state.R (stage read and write sets); the fold-phase checker LTB-0279 | Rebuilt in Cut 28 (amendment_test_inventory (5), inventory R044 and R196) |
| No lookahead under future perturbation | No dedicated lean-core witness was found. The suite's causality tests (test-indicator-causality.R and others) run through the suite driver | O7 |
| Conservation (cash, positions equal to their lots, fee reconciliation) | P5's production reconciliation (LR-14) on every gate run; the suite's accounting tests | O7 |
| Retained-view aliasing | the gate's view workloads and the debug comparator | O1 |

## D3 census rows still open (loop_checklist.md)

| Case | Disposition |
| --- | --- |
| INCOMPLETE with a zero-valued equity row | O8 |
| Immutable recorder captures; pre-commit leg visibility | O8 |
| Leg-level handler exceptions | O8 |
| Real interrupts | O8 |

## Named obligations

Each must be complete before the oracle it needs is retired. The live pin
stays until all are complete.

- **O1, Cut 28:** a candidate runner on the switched package that writes
  gate/<workload>_lean.rds for every recorded workload, compared by
  oracle_check.R with no unlisted difference. Accepted differences are
  listed in an --accepted file naming their authority, for example the
  LR-12/LR-20 store-format changes, and the `feature_engine_version`
  digest in `sweep_attrs`, which changes when lean preparation becomes
  package code (LDG-3283, the integrated run).
- **O2, maintainer, before the switch run:** the private Sharadar reference
  runs on the live pin and the candidate. Its records stay private, and
  the result is recorded by the maintainer. Cut 27's cut review routes it
  to Cut 28.
- **O3, LDG-3283 and Cut 28:**
  - LDG-3283 recaptures the FIFO corpus on 7f65733f: two test-suite
    captures and the recorder captures, kept beside the records with their
    digests.
  - Cut 28 reruns fifo_parity.R, fifo_simple_cases.R and
    fifo_population.R against the switched package's kernel and the
    captures.
- **O4, Cut 28:** cut18_witness.R's lean calls are retargeted to the merged
  R/ functions. It dumps their outcomes, and oracle_check.R compares them
  with cut18_pin.rds.
- **O5, Cut 28 review:** the refusals without a witness (risk close-shape;
  cost proposal and context shapes) move verbatim, checked by the
  independent Type 1 review of the merges.
- **O6, Cut 28:** the gate variants are rehosted on the switched package.
  Each must make oracle_check.R fail on its workload.
- **O7, Cut 28 or the fold-core test rebuild (macro plan, the new
  fold-core suite):**
  - an invariant check on the recorded workloads: cash conservation,
    positions equal to their lots, fee reconciliation;
  - a no-lookahead check: perturbing later bars changes no earlier
    decision.
  Both run before the pin retires.
- **O8, Cut 28 switch census:** the four open D3 rows, each witnessed or
  dispositioned (owned by the switch cut since 2026-11-12).
