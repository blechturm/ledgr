# LDG-3272: walk-forward, the restart routes and the compiled selector

Cut 26 decisions 3, 4 and 6. Pin: the installed library d5b3a151
(`C:/Users/maxth/ledgr-wt/pin-lib-d5b3a151`) and its source
(`C:/Users/maxth/ledgr-wt/pin-src-d5b3a151`).

## What changed

- `dev/lean_core/loop.R`: the compiled-FIFO and restart coverage checks are
  deleted (a comment says why restart cannot fire: every fold invocation
  starts at pulse one, `R/run-resume.R:55`); the E stage calls the pin's two
  selector admission checks where the pin's envelope calls them, then runs
  the lean R FIFO.
- `dev/lean_core/loop_harness.R`: the walk-forward entry refusal, its
  recorder (`lean_walk_forward`, `lean_entry$walk_forward`) and its package
  binding are deleted.
- `dev/lean_core/parity/loop_workloads.R`: the registered walk-forward
  refusal is removed. `loop_workloads_slice5.R` (new) holds the 15 slice-5
  workloads and their reach predicates; `loop_parity.R` sources it.
- `loop_variant_changes.csv`: the two `entry_guard_off` rows on
  `witness_walk_forward` are retired with their reason (the refusal they
  disabled no longer exists; the checkpoint rows stay).
- The pulse-plumbing synthesis gains "Amendment: the compiled selector (Cut
  26, 2026-11-26)" with local notices under its D3-A R9 and the skeleton
  synthesis's R9; the rules ledger gains LR-25.

## Source comparison: the retained admission checks

The pin, `R/fold-engine.R:1741-1748` (inside `ledgr_fold_envelope`, after the
valuation state and before `init_buffers()`):

    if (use_compiled_spot_fifo) {
      ledgr_require_compiled_spot_fifo_dispatch(execution, output_handler)
      if (!is.null(corporate_action_plan)) {
        ledgr_require_compiled_spot_fifo_event_kinds(
          corporate_action_plan$event_kinds()
        )
      }
    }

The lean E stage, `dev/lean_core/loop.R` (after the marks state and the
execution epochs, before `init_buffers()`):

    if (identical(ledgr_normalize_compiled_accounting_model(execution$compiled_accounting_model), "spot_fifo")) {
      ledgr_require_compiled_spot_fifo_dispatch(execution, output_handler)
      if (!is.null(execution$corporate_action_plan)) {
        ledgr_require_compiled_spot_fifo_event_kinds(execution$corporate_action_plan$event_kinds())
      }
    }

The same two package functions, the same arguments (the pin's
`use_compiled_spot_fifo` is `identical(ledgr_normalize_compiled_accounting_model(...), "spot_fifo")`,
`R/fold-engine.R:1714-1717`; its `corporate_action_plan` is
`execution$corporate_action_plan`), before the first pulse.

## Predicates witnessed by public workloads

| predicate | witness | result on the pin (both arms identical) |
| --- | --- | --- |
| public durable refusal, `ledgr_run` entry (`R/backtest.R:148-164`), not an E check | `s5_compiled_durable` | `ledgr_compiled_spot_fifo_unavailable`; no run row |
| availability-active upstream refusal (`R/sweep.R:176-182`), before candidate evaluation | `s5_compiled_availability` | `ledgr_compiled_availability_unsupported` escapes with stop_on_error FALSE and TRUE; no candidate row |
| E event-kind refusal | `s5_compiled_event_kinds` (corporate facts only) | FAILED candidate row (FALSE) and the escaping condition (TRUE), `ledgr_compiled_spot_fifo_unavailable`, CASHFLOW |
| E dispatch refusal, missing native routine | `s5_compiled_missing_native` (test-only seam: `ledgr_cpp_spot_fifo_batch` bound to NULL) | FAILED candidate row and the escaping condition, "Compiled spot-FIFO accelerator is unavailable on this install." |

## Predicates publicly unreachable

- **Output handler without compiled batch append**
  (`R/compiled-spot-fifo.R:69`): every output handler is built by
  `ledgr_output_handler()`, which defines `append_compiled_spot_batch`
  (`R/output-handler.R:715`), so no public run reaches it.
- **Non-buffered run** (`R/compiled-spot-fifo.R:58`): sweep candidates are
  always `event_mode = "buffered"` (`R/sweep.R:1755`); a public durable run
  selecting the selector is refused at `ledgr_run` entry; and the lean
  coverage check refuses a non-buffered fold (db_live) before the E stage.

Both calls stay in the lean E stage by the source comparison above.

## The compiled adapter's refusals and the lean FIFO

`ledgr_run_compiled_spot_fifo_batch()` (`R/compiled-spot-fifo.R:158-250`):

| refusal | kind | in the lean loop |
| --- | --- | --- |
| a fill side other than BUY or SELL (`ledgr_compiled_spot_fifo_invalid_input`) | internal shape: the planner emits sides +1 and -1 only | unreachable; not reproduced |
| the native kernel's type, length and index checks (`src/spot_fifo.cpp:64-118, :172`) | internal shape: the adapter builds every vector | unreachable; not reproduced |
| the native kernel's fill checks (finite quantity, price and timestamp, quantity and price above zero, fee at or above zero; `src/spot_fifo.cpp:175-184`) | preconditions the planner's fills already meet | unreachable; not reproduced |
| on suspicion (an error, a non-finite output or an overflow bound), the canonical oracle's earliest refusal (`ledgr_fold_fill_candidate()`), or a native error at an earlier or the same row | product refusal: the canonical lot rules | the lean FIFO raises the canonical refusals (FIFO parity suites, `dev/lean_core/parity/fifo_*`; rules ledger LR-21, LR-22); public witness `s5_compiled_overflow`: an opening basis near the double range and a large buy, the pin's native batch called, `ledgr_invalid_lot_fill` in both arms, as a row and escaping |

## Capacity (LR-19, D3-B)

`s5_compiled_capacity_at` (limit 9 fill events: the run completes) and
`s5_compiled_capacity_over` (limit 8: the last fill pulse refuses with
`ledgr_event_buffer_capacity_exceeded`) lower the pin's handler buffers and
the lean loop's fill-only limit seam; each reads the committed prefix before
every strategy call (`lw_prefix_reads`). The prefix rows, the refusal class
and message, and the public tables are identical in both arms, at the normal
bound and at batch bound one (`capacity_batch1_debug*.csv`). No
compiled append-boundary difference appeared on these witnesses, so none is
attributed to LR-19/D3-B.

## Restart routes

| route | workload | pin tables | folds |
| --- | --- | --- | --- |
| fresh replacement after FAILED without completion evidence | `s5_restart_plain`, `s5_restart_opening` (openings), both seeded with a day-3 draw | attempt 1 FAILED (0 events; the 2 opening CASHFLOW rows), attempt 2 DONE with 4 fills (2 openings plus 4 fills), no duplicate event_seq | two |
| fresh replacement after a RUNNING max_pulses attempt | `s5_restart_running` (the same limited config twice: `max_pulses` is in the config identity, so another control is refused as a config_hash mismatch) | both attempts RUNNING with the same 4 events, no duplicates, no condition | 1 then 2 |
| achieved INCOMPLETE reopen | `s5_reopen_incomplete`, replay-forbidden strategy | INCOMPLETE twice, tables unchanged | 1 then 1: no fold, no strategy call |
| completion recovery after a terminal-finalization fault | `s5_recover_completion` (`ledgr_run_finalize` faulted on attempt 1), replay-forbidden | the second invocation finalizes INCOMPLETE | 1 then 1 |

Pin tables for each route are in `pin_tables/` (`dump.R`).

## Proofs

`targeted_debug0.csv`, `targeted_debug1.csv` (306 tables, 0 different, 14 PASS and 4 PASS* each): the 15 slice-5 workloads plus
walk_forward, witness_walk_forward and dense_cost; `capacity_batch1_debug*.csv` (15 tables, 0 different); `wf_costs_predicate_debug*.csv`: s5_walk_forward_costs rerun after its predicate (both folds DONE, fills with fees) was added.
