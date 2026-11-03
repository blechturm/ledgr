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
