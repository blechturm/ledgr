# Lean Core Rules Ledger

- Status: open; owned by macro WS16 under the lean fold core synthesis
  amendment A3.
- Started: 2026-11-03, from the eleven rules in `dev/spikes/r_floor/README.md`.

Every ledgr rule that a lean-core parity failure surfaces is recorded here,
once. Before the switch cut, each entry has a disposition: **contract**
(written into `contracts.md` as intended behavior, with its rule-group
address) or **change** (changed deliberately by the maintainer, with the
recorded oracle difference and its reason). An entry with disposition
**pending** blocks the switch.

Add an entry in the workstream whose parity failure found it: what the rule
is, in one sentence of observable behavior, where it was found, and the
disposition once decided. Do not restate the rule elsewhere.

| ID | Rule | Found by | Disposition |
| --- | --- | --- | --- |
| LR-01 | A decision row's `quantity` is the current holding, not zero. | r_floor stage 2 | pending |
| LR-02 | A final-pulse request that differs from the holding writes an `execution / no_fill / final_pulse_no_execution` row with the request in `target` and the holding in `quantity`. | r_floor stage 2 | pending |
| LR-03 | The reconciliation detail books recorded cash fill by fill in event order, and expected (virtual) cash fill by fill with sells before buys, so the two can differ in the last digit on busy pulses. | r_floor stage 2 | pending |
| LR-04 | Ordered accumulations use plain double additions in event order; `cumsum()` accumulates in long double and differs in the last digit. | r_floor stage 2 | pending |
| LR-05 | The decision axis is the members in stable order, then held former members, not one sorted list. | r_floor stage 3 | pending |
| LR-06 | `buyable` follows membership, not whether the instrument has a bar at the pulse. | r_floor stage 3 | pending |
| LR-07 | `ledgr_history_matrix()` admits an instrument only with a complete lookback window, and returns no columns before one exists. | r_floor stage 3 | pending |
| LR-08 | Missing price inputs are carried for up to five sessions for features and history (history projection v11), while `ctx$close` stays `NA`; a running-sum indicator passes through the carried value. | r_floor stage 3 | pending |
| LR-09 | Stored prices are rounded to eight decimals. | r_floor stage 3 | pending |
| LR-10 | A fill at the next session's open belongs to the first decision after it. | r_floor stage 3 | pending |
| LR-11 | The fills reader reports a closing leg's own `realized_close` and zero for openings, not the book's running `event_realized`. | r_floor stage 3, second seam | pending |
| LR-12 | execution_mode, including db_live, its argument/control/config, store and reader fields, is removed; one chunked write path replaces immediate inserts. | Pulse plumbing D6, Section 5 | change: R8; config identity and store format change; physical I/O timing/visibility differences are enumerated, not called exact parity. |
| LR-13 | Internal carrier packet/data/execution/decision/view/plan/fill/rejection/publication/leg schema, alignment, dictionary, partition, value and order assertions run only in debug; malformed ledgr output may no longer refuse in production. | Response finding 2; R/fold-carrier.R:207 | change: R1-R3 and Section 4; preserve external entry and contracted economic guards; debug retains original classes. |
| LR-14 | The P3 affordability reconciliation stop, P5 cash equality and finite reconciliation values retain their production stop and refusals, with their distinct classes and original order; the reconciliation row remains. | R/fold-engine.R:110,1178,1555,1584; seed v2 misclassification | contract: Affordability And Reason Codes; Fill And Lot Validity; R3. No oracle difference authorized. |
| LR-15 | Every ledgr producer omits the generic accounting validator on write; malformed internal rows may escape and an earlier append assertion need not beat a later lot failure in production; stored-ledger reads still validate. | D4; R/output-handler.R:466,666,699,734 | change: R4; debug keeps the nonpublishing earlier-prefix assertion path; no successful/failed-state rollback guarantee is added. |
| LR-16 | Post-risk numeric/length/finiteness rechecking is debug-only; post-risk admissibility, risk-mark/equity and short-exposure policy refusals stay. | D5; R/fold-engine.R:1016 | change: R2-R3; ledgr_invalid_post_risk_targets is no longer a production module-defect detector. |
| LR-17 | Internally assembled state/stop, diagnostic segments/staging/writer blocks and equity schema/value/used-prefix assertions, including after stop installation, are debug-only; capacity and contracted P5 refusals stay. | R/fold-phase-contract.R:179,208; R/fold-carrier.R:821,970; R/availability-diagnostic-writer.R:132 | change: R1-R3; names include ledgr_internal_error and ledgr_invalid_fold_execution; debug preserves each original assertion's class. |
| LR-18 | Duplicate fill-payload input/epoch and settlement-adapter shape checks are debug-only on ledgr-owned values; imported state and applicable execution/lot economic guards stay at their named boundary. | R/backtest-runner.R:98,114; R/fold-engine.R:229 | change: R2-R3; no broad deletion of ledgr_invalid_fill_intent, ledgr_invalid_args or ledgr_lot_state_invariant by class name. |
| LR-19 | The event-buffer limit counts fill events only, cumulatively over the run, against pulses x instruments; other event kinds no longer count (today the memory sink counts every row and can refuse P1 and compiled appends before P5). | Pulse plumbing final review finding 2; maintainer decision 2026-11-06 | change: removes the memory sink's refusals on non-fill events; valid durable runs are unchanged. |
| LR-20 | `engine.checkpoint_every` is retired with `execution_mode`; the bounded output chunk replaces it. | Pulse plumbing final review finding 3; maintainer decision 2026-11-06 | change: config identity and store format, in the same switch-cut bump as LR-12. |
