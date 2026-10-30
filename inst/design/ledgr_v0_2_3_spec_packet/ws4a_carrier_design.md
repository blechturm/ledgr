# WS4a Carrier Design Note (LDG-3162)

- Status: revision 4, accepted design gate. Revision 2 applies
  `ws4a_design_review_1.md` F1-F13; revision 3 applies
  `ws4a_design_review_1_rereview_1.md` N1-N5; revision 4 applies
  `ws4a_design_review_1_rereview_2.md` (PASS_AFTER_PATCHES) N6, N7, O1 and
  O2 verbatim, by maintainer disposition of the third correction round
  (2026-10-30), with no further review.
- Author: Claude, 2026-10-30. Plain-language companion:
  [ws4a_overview.md](ws4a_overview.md).
- Base: `release/v0.2.3`; `R/` and `src/` identical to `953338df`.
- Authority: the accepted synthesis
  (`../rfc/rfc_typed_fold_carrier_v0_2_3_synthesis.md`, "Synthesis") binds
  the design; cut 5 in `tickets.yml` ("Cut") binds order, oracles and gates.
  This note applies them and adds no design. It pins what Synthesis Section
  7 leaves to the cut (code assignments, locators, pulse capacity, detector
  names). It is the implementation checklist; LDG-3163 has completed the
  base records indexed by its ticket evidence and
  dev/bench/v0_2_3_ws4a/records/.
- File aliases: `fe` `R/fold-engine.R`, `ae` `R/availability-economics.R`,
  `ap` `R/availability-provider.R`, `app`
  `R/availability-provider-prepared.R`, `oh` `R/output-handler.R`, `la`
  `R/lot-accounting.R`, `csf` `R/compiled-spot-fifo.R`, `br`
  `R/backtest-runner.R`, `lw` `R/ledger-writer.R`, `adw`
  `R/availability-diagnostic-writer.R`, `fpc` `R/fold-phase-contract.R`,
  `rf` `R/run-finalize.R`, `to` `R/terminal-outcomes.R`, `cas`
  `R/corporate-action-settlement.R`, `hs` `R/history-substrate.R`, `ar`
  `R/accounting-replay.R`, `bf` `R/backtest-fills.R`, `wf`
  `R/walk-forward.R`, `sw` `R/sweep.R`, `feb` `R/fold-event-buffer.R`.
  Test files are `tests/testthat/<name>`.

## 1. Consumer census (scope a)

One row per edge. "Via" is `direct` or the named adapter. Transitional
adapters have one remover. Permanent boundary helpers: `ledgr_carrier_import_state()`
(E import), the P2 input and return helpers, the publication helpers and the
result helpers. Transitional: `ledgr_carrier_provider_view()` (provider and
valuation outputs into the packet; remover WS4b),
`ledgr_carrier_execution_view()` (P3 execution view; remover WS4b),
`ledgr_carrier_settlement_state()` (corporate-action and disposition state
in and out; remover WS8, the non-fill accounting boundary; WS4b removes only
the provider/valuation adapter), `ledgr_carrier_compiled_pack()` and
`_unpack()` (remover: the compiled-envelope RFC).

### 1.1 Fold state

| # | Group: field | Producer (stage, site) | Consumer (stage, site) | Via | Ticket |
| --- | --- | --- | --- | --- | --- |
| E01 | state: cash | E envelope fe:1741 | P1 equity fe:578, :589 | direct | 3164 |
| E02 | state: cash | P1 settlement install fe:244-249 (called fe:365, :399, :487) | P1 onward | settlement_state | 3164 |
| E03 | state: cash | fold state | P2 ctx cash/equity fe:763-764 | direct | 3165 |
| E04 | state: cash | fold state | P3 planner fe:1093; reconciliation fe:1140-1166; skip plan fe:675 | direct | 3166 |
| E05 | state: cash | P4 fe:1400 (canonical); fe:1328 (compiled) | P5 fe:1446-1469; E return fe:2091 | direct | 3167 (canonical), 3164 (compiled unpack) |
| E06 | state: positions | E import fe:1593-1597 (by name, fe:43-49) | fold state | import_state | 3164 |
| E07 | state: positions | fold state | P1 decision view fe:298-301 (provider by name) | provider_view | 3165 |
| E08 | state: positions | fold state | P1 positions value fe:557-573 (run-order sum) | direct | 3165 |
| E09 | state: positions | fold state | P1 context snapshot fe:600-608 | direct | 3165 |
| E10 | state: positions | fold state | P2 dense fast context fe:786 | P2 input helper | 3164 (dense ctx output unchanged) |
| E11 | state: positions | fold state | P3 current quantity fe:1066 | direct | 3166 |
| E12 | state: positions | fold state | P4 boundary bind fe:1307-1308; E bind fe:1895 | settlement_state | 3164 |
| E13 | state: positions | fold state | P5 actual positions fe:1458-1461 | direct | 3166 |
| E14 | state: positions | P4 fe:1389 (canonical), fe:1324 (compiled) | fold state | direct | 3167, 3164 |
| E15 | state: positions | fold state | dispositions to:136-142; corporate actions cas:465, :634-639 (by name) | settlement_state | 3164 |
| E16 | state: lot_state | E import fe:1594-1595 | fold state | import_state | 3164 |
| E17 | state: lot_state | fold state | P1 equity realized and basis fe:580-581, :589-590 | direct | 3164 |
| E18 | state: lot_state | P4 per-fill apply fe:1349-1357 | fold state | direct | 3164 (operations), 3167 (block) |
| E19 | state: lot_state | fold state | P4 position read fe:1389-1392 | direct | 3164 |
| E20 | state: lot_state | fold state | handler fact oh:787-816 (called fe:1370-1376) | direct | 3164, 3167 |
| E21 | state: lot_state | fold state | compiled pack csf:104-135, batch csf:203-242 | compiled_pack | 3164 |
| E22 | state: lot_state | compiled unpack csf:137-165, :244-247 | fold state fe:1329 | compiled_unpack | 3164 |
| E23 | state: state_prev | E fe:1744; P1 normalize fe:541; P5 fe:1522 | P2 ctx fe:767; P1 fe:542; P5 carry fe:1511; E return fe:2092 | direct | unchanged (WS5 owns its type) |
| E24 | state: state_axis | P1 fe:546; P5 fe:1515 | P1 fe:540 | direct | unchanged |
| E25 | state: event_seq | E fe:1745; P1 fe:366, :400, :488; P4 fe:1330, :1369 | P1 posts fe:360, :394, :481; P3 predicted seq fe:1258; P4 fe:1322, :1366; E fe:2093 | direct | 3166 (P3 prediction), 3167 (P4 block) |
| E26 | state: status, stop_reason | E fe:1919-1920, :1960-1961, :1987-1988 | completion fe:1877-1878, :2038-2039; return fe:2087 | direct | 3168 |
| E27 | state: affected_exposure | E fe:1746, :1921, :1962, :1989 | P3 stop fe:1166; completion fe:1879, :2040, ae:551-555 | direct | 3168 |
| E28 | state: processed | E fe:1926, :1967, :1994; P5 fe:1533 | E fe:1906; P5 fe:1536, :1554, :1562; return fe:2088 | direct | 3168 |
| E29 | state: full_run | P5 fe:1563, :1567 | E fe:2034, :2089 | direct | unchanged |
| E30 | state: last_fully_valued | E fe:1722, :1729, :1747; P1 fe:575 | completion fe:1880, :2041 | direct | 3168 |
| E31 | state: last_executed | E fe:1723, :1731-1732, :1748; P5 fe:1440-1443 | completion fe:1881, :2042 | direct | 3166 (reads plan `exec_ts`) |
| E32 | state: frozen_set | E fe:1749; P1 fe:539 | P1 fe:517-518 (by name) | direct | 3165 |
| E33 | state: current_stage, current_ts | E fe:1902-1903; stages fe:280, :833, :985, :1053, :1291 | E exception row fe:2070-2071 | direct | unchanged |
| E34 | state: pending_segments | P1 fe:293-296; P2 fe:702-705; P5 fe:1484-1491; E fe:1758-1761 | flush fe:251-270 | direct | 3168 |
| E35 | state: diagnostic_seq | flush fe:266-267 | block first sequence fe:262; handler renumbers oh:631-654 | direct | 3168 |
| E36 | state: telemetry_idx | E fe:1750; P5 fe:1537 | P5 fe:1538; E fe:2084 | direct | unchanged |
| E37 | state: equity_facts (new) | accumulator fpc:164-190, appended fe:576-582 (availability) | collect fe:2094; finalisation rf:449-458, :511-524; prefix commit br:1076-1086 | direct | 3168 |
| E38 | state: equity_facts (new) | `record_equity_fact` fe:584-592 (both producers) | memory sink oh:295-312; inline summary oh:313-351; sweep sw:1917-1921 | direct | 3168 |
| E39 | state: equity_facts (new) | recovery rf:188-194 | br:931 then finalisation | direct | 3168 |

### 1.2 Lot book outside the fold

| # | Consumer | Site | Via | Ticket |
| --- | --- | --- | --- | --- |
| E40 | Replay | ar:274-332 | direct typed operations | 3164 |
| E41 | Chunked fills reader | bf:121-166 | direct | 3164 |
| E42 | Run opening | br:643-657 | import_state | 3164 |
| E43 | Run resume | br:669-671 | import_state | 3164 |
| E44 | Sweep opening | sw:1771-1819 | import_state | 3164 |
| E45 | Result replay | br:1241-1252 | direct | 3164 |
| E46 | Walk-forward as-of | wf:1202-1203, la:224-237 | direct | 3164 |
| E47 | Walk-forward carry | wf:1281-1304 | result helper | 3164 |
| E48 | Dispositions | to:149-198 | typed disposition operation via settlement_state | 3164 |
| E49 | Terminal recovery | rf:164-195 | direct | 3164 |
| E50 | Handler accounting fact | oh:787-816 | direct | 3164 |
| E51 | Compiled pack/unpack | csf:104-165, :167-247 | compiled_pack, compiled_unpack | 3164 |

### 1.3 Observation, decision and plan

| # | Group | Producer | Consumer | Via | Ticket |
| --- | --- | --- | --- | --- | --- |
| E52 | decision packet | provider decision view app:530-542, fold additions fe:309-313 | P1 packet | provider_view | 3165 |
| E53 | decision packet | valuation state ae:135-145 | P1 packet | provider_view | 3165 |
| E54 | decision packet | P1 | P2 ctx construction fe:707-820 | P2 input helper | 3165 |
| E55 | decision packet | P1 | P2 target validation fe:872-877, ae:265-267 | direct | 3165 |
| E56 | decision packet | P1 | P2 decision trace, risk and stale segments fe:889-1026 | direct | 3165 |
| E57 | decision packet | P1 | P5 state normalization fe:1509-1515 | direct | 3165 |
| E58 | decision packet | P1 | P5 reconciliation marks fe:1470-1481 | direct | 3165 (observation-interface read); 3166 retains ownership of the plan/effects reconciliation change |
| E59 | decision packet | P1 members fe:619-623 | P2 `ctx$members` fe:772 | P2 input helper | 3165 |
| E60 | decision data | history reader current bars hs:394-413 | P2 bar frame fe:709-712, hs:347-370 | P2 input helper | 3165 |
| E61 | decision data | current closes fe:350 | P1 corporate-action marks | settlement_state | 3165 |
| E62 | execution packet | history reader next bar hs:394-413 (continuation hs:400-412) | P3 availability planner ae:469, :479-482 | direct | 3165 (produce and migrate the P3 input read); 3166 (typed plan construction) |
| E63 | execution packet (dense) | `bars_mat` at `pulse_idx + 1` | P3 dense planner fe:150-156 | direct | 3166 |
| E64 | execution view | provider execution view ae:417-420 | P3 ae:460-468 (by name) | execution_view | 3166 |
| E65 | decision | P2 return fe:1035-1043 | P3 targets fe:1057-1068 (by name today) | direct | 3165 (produce and migrate the P3 decision read); 3166 (typed plan construction) |
| E66 | decision | P2 return | P5 state fe:1425, :1509-1527 | direct | 3165 |
| E67 | decision | P2 return | P5 reconciliation gross fe:1470-1477 | direct | 3165 (decision-interface read); 3166 retains ownership of the plan/effects reconciliation change |
| E68 | decision (skip) | skip decision fe:632-664 | E fe:1954-1956; P3 skip plan | direct | 3165 |
| E69 | plan (dense) | fe:128-198 | P3 | direct | 3166 |
| E70 | plan (availability) | ae:391-529 | P3 | direct | 3166 |
| E71 | plan: affordability | ae:344-389 | availability planner | direct | 3166 |
| E72a | plan | P3 | P3 affordability reconciliation and stop fe:1140-1169 | direct | 3166 |
| E72b | rejection | P3 | P3 `no_fill` diagnostic rows fe:1171-1214 | direct | 3166 |
| E72c | fill | P3 | P3 `filled` diagnostic rows fe:1215-1271 | direct | 3166 |
| E73a | plan (event kinds) | P3 | P3 canonical and compiled kind checks fe:1115-1125 | direct | 3166 |
| E73b | fill | P3 | P4 application fe:1342-1399 | direct | 3166 (interface); 3167 separately owns batching this edge |
| E74a | plan (`expected_final_cash`) | P3 | P5 reconciliation fe:1445-1457, :1468 | direct | 3166 |
| E74b | fill (`exec_ts`, `cash_delta`) | P3 | P5 last-executed and reconciliation detail fe:1434-1443, :1463-1467 | direct | 3166 |
| E75 | fill | P3 | compiled wrapper csf:167-247 | compiled_pack | 3166 |
| E76 | plan (skip) | fe:668-686 | P4, P5 | direct | 3166 |
| E77 | fill | P3 | buffered payload br:103-187 | publication helper | 3166 |
| E78 | fill | P3 | db_live writer lw:18-157 (oh:561-563) | publication helper | 3166 |

LDG-3165 completes all consumers of its changed observation and decision
groups, including P3, P5, E, skips and stops. These interface reads do not
wait for LDG-3166. The existing planning and reconciliation algorithms
remain until LDG-3166 changes their plan/effect representation; no mixed
next-bar observation is reconstructed for P2.

### 1.4 Publication, legs, diagnostics, stops, timing

| # | Group | Producer | Consumer | Via | Ticket |
| --- | --- | --- | --- | --- | --- |
| E79 | publication | payload | staging oh:532-559, flush oh:575-602, event buffer feb:49-112 | direct | 3167 |
| E80 | publication | compiled batch | `append_compiled_spot_batch` oh:738-785 | direct | 3167 |
| E81 | publication (non-fill) | to:215; cas:603; sw:1765 | `append_event_rows` oh:668-671, :714-736 | publication helper | 3167 (indexed write), WS8 (builders) |
| E82 | publication | event buffer | durable `flush_pending` oh:672-695 | direct | 3167 |
| E83 | publication | event buffer | memory materialisation oh:837-865, sw:1923-1926 | direct | 3167 |
| E84 | leg | handler fact oh:787-816 | memory sink `stage_leg`/`add_leg` oh:196-231, `flush_legs` oh:246-283 (called oh:600) | direct | 3167 |
| E85 | leg | `inline_fills` | inline summary oh:313-351 and retained fills/trades | direct | 3167 |
| E86 | leg (compiled) | compiled batch | `add_legs_many` oh:232-245 | direct | 3167 |
| E87 | diagnostics | 15 segment producers (fe:325-336, :489-497, :520-537, :640-653, :879-1025, :1155-1271, :1484-1491, :1944-1952) | block adw:44-92 | direct | 3168 |
| E88 | diagnostics | block | writer adw:94-171 | direct | 3168 |
| E89 | diagnostics | writer drain fe:1871, :2032 | handler oh:631-647; memory filter oh:362-378 | direct | unchanged |
| E90 | stop | P1 fe:337-344 | E fe:1918-1930 | direct | 3168 |
| E91 | stop | P2 fe:975-982 | E fe:1959-1971 | direct | 3168 |
| E92 | stop | P3 fe:1162-1169 | E fe:1986-1998 | direct | 3168 |
| E93 | timing | stage locals | P5 telemetry fe:1535-1551 | direct | unchanged |
| E94 | telemetry | P5 fe:1535-1551 | E fe:2083-2084 | direct | unchanged |

### 1.5 Lot input and applied row

| # | Group: edge | Producer | Consumer | Via | Ticket |
| --- | --- | --- | --- | --- | --- |
| E95 | lot input: opening import | la:182-213 | opening operation la:147-179 | import_state | 3164 |
| E96 | lot input: replay opening, fill, disposition | prepared columns ar:299-308, la:420-466 | typed operation selected by event kind | named replay adapter | 3164 |
| E97 | lot input: P4 fill | fe:1344-1355 | typed fill operation | direct positional input | 3164; 3167 separately owns batching this edge |
| E98 | lot input: P1 disposition | to:159-166 | typed disposition operation | settlement_state | 3164 |
| E99 | applied row: canonical accounting fact | la:367-388, fe:1349-1357 | oh:787-813 | direct; typed scalar result initially | 3164; 3167 separately owns column batching |
| E100 | applied row: replay facts | la:434-487 | ar:309-327 | direct | 3164 |
| E101 | applied row: disposition witness | to:159-169 | to:187-195 | settlement_state | 3164 |

The two sequential changes on an edge are separate obligations: 3164
migrates operation and result representation; 3167 changes P4 application
and publication to a block. Neither defers the other's interface work.
Every Synthesis Section 4 group has at least one row in Sections 1.1-1.5.

**Not carried** (dead today): `pulse_plan$targets` and `$actionable_idx`,
`fill$ts_signal_utc`, the local `cur_qty` (fe:1347). Bound outputs stay as
bound: the stop result's `affected_instrument_ids` and the Phase 5.5 fold
return (`state`, `state_prev`, `next_event_seq`).

## 2. Pins (scope b)

### 2.1 Reasons and restriction codes

- **P3 fill and rejection reasons** are a flat segment (`reason_offset`,
  `reason_count`, `reason_code_list`) in the order
  `ledgr_availability_reason_values()` produces today: blocking tokens, then
  informational, with `unique()` keeping the first occurrence (ae:334-342,
  :438-454). The row's primary `reason_code` is a separate integer column,
  set where it is set today (`reasons[[1L]]` for rejections, ae:381, :452;
  the first informational value or `""` for fills, fe:1231-1233). The
  `reasons` text is built when the diagnostic row is staged.
- **P3 dictionary:** 1 `final_pulse_no_execution`, 2
  `execution_bar_missing`, 3 `insufficient_cash`, 4
  `membership_changed_before_execution`, 5 `trading_halted`, 6
  `quotation_only`, 7 `status_unknown`, 8 `status_unknown_or_conflicting`,
  9 `lifetime_inactive`; 0 is the empty string. A token outside the
  dictionary aborts with `ledgr_invalid_pulse_plan`.
- **Decision-packet restriction codes** have their own levels: 1
  `trading_halted`, 2 `quotation_only`, 3 `status_unknown`, 4
  `status_unknown_or_conflicting`, 5 `lifetime_inactive`, 6
  `valuation_frozen`; 0 is empty. The emitted segment order is preserved,
  including `valuation_frozen` appended after existing restrictions
  (ae:171-185; provider ap:241-265), independent of code order.
- **Code 0** is decoded explicitly as `""`; it is never used as an R index.
- **Other diagnostic producers** (decision trace, terminal, stop, skip,
  reconciliation) keep writing their `reason_code` and `reasons` strings
  into the staging block as today. The lifetime terminal stop (fe:443-453)
  and the decision trace with `sizing_unavailable` (fe:907-914) do not
  follow "primary = first token"; they are not re-encoded.
- **Only fields Synthesis Section 4 declares as integer codes are
  encoded.** Instrument IDs, `terminal_event`, `lifetime_fact_id` and
  exception reasons stay character at their declared boundaries. The
  provider's internal `terminal_levels` stay provider internals.

### 2.2 Other codes

- **Mark source:** 1 `missing`, 2 `expired_close`, 3 `current_close`, 4
  `stale_close`, 5 `frozen_close`; 0 `""` (ae:117-126). `write_off` is
  excluded from the packet dictionary but preserved verbatim in disposition
  metadata and in the diagnostic `mark_source` (fe:489-495).
- **Provider status and lifetime:** integer codes into the provider's own
  level vectors (app:373-377, :398-404); `terminal_event` remains character
  in the carrier.
- **Economic event kinds:** 1 `FILL`, 2 `CASHFLOW`, 3 `DISPOSITION`. The
  canonical-supported set stays `FILL, CASHFLOW` (fe:1120) and compiled
  stays `FILL` (csf:93). Empty plans declare none.
- **Side:** +1 `BUY`, -1 `SELL` in the carrier, tokens at publication.
  **Legs:** CLOSE before OPEN (oh:809-814).
- **Condition classes survive** on the column validators:
  `ledgr_invalid_fill_intent`, `ledgr_invalid_pulse_plan`,
  `ledgr_invalid_lot_fill`, `ledgr_lot_state_invariant`,
  `ledgr_invalid_post_risk_targets` (documented in
  `R/condition-reference.R`; checked by test-codebase-contracts.R:44,
  LTB-0271).

### 2.3 Locators

- `bar_row` is the valuation's `source_row` (run positions, ae:144) and
  `source_column` the history reader's `pulse_columns[pulse_idx]`
  (hs:394-413). A row alone is not a time boundary.
- Feature access stays the cutoff-bound `history_view` (fe:288-292) and the
  projection views, P2-local and unchanged.
- The execution packet holds `exec_ts`, `has_next` and next-bar OHLCV on
  the run axis from `history_bars$next_bar`, including the continuation
  column beyond the last pulse (hs:400-412).

### 2.4 Pulse diagnostic capacity

Let `H` be lifetime-disposition rows, `F` freeze-entry plus freeze-exit rows
(disjoint sets) and `C` the context length. P1 contributes at most `H + F`;
P2 at most one intent row, `max(C, 1)` decision rows and `C` stale-risk
rows; P3 at most `C` accepted and rejected rows; P5 one reconciliation row.
`H, F, C <= N` gives the conservative bound `5N + 3`. Corporate-action
refusal and blocked scheduled-disposition stops return before the later
producers; bound them by `N` and `Q_pulse` (blocked due disposition rows,
not deduplicated). Scheduled-skip pulses fit the bound. **Pinned:**
allocate once in E with `capacity = max(5N + 3, max(Q_pulse))`, where an
absent `Q_pulse` is integer 0. Reset after each drain; never grow. A staged
row beyond capacity is the classed bug refusal
`ledgr_invalid_fold_execution`. The fold's `diagnostic_seq` stays a row
counter; the handler renumbers at write (oh:631-654).

### 2.5 Cash-effect reuse

`ledgr_fill_publication_deltas()` (lw:8-16) and
`ledgr_availability_fill_cash_delta()` (ae:326-332) evaluate the same
expressions in the same order. P3 computes `cash_delta` and
`position_delta` once and later readers reuse them. Both reconciliation
sums (fe:1140-1144, :1463-1467) stay `sum()` over the reused vector in fill
order. LDG-3166 adds a test that the reused values are `identical()` to
both formulas on every case.

## 3. Obligation register (scope c)

Each row is one indivisible obligation with one implementing ticket. LDG-3169
verification is a cross-reference, not a second owner. "Check" names the
case (Section 4), detector or validator (Section 6) or oracle; "control" is
the deliberate violation that must fail that check. "Oracles" means the A0
successor and dense oracles.

### 3.1 Synthesis Sections 2-3

| ID | Obligation (clause) | Producers / consumers | Owner | Check | Control |
| --- | --- | --- | --- | --- | --- |
| O2.01 | Economics, event order, `meta_json`, equity, state, retained diagnostics byte-identical (2) | all | 3169 (whole-candidate verification; each ticket's end check under decision 8 is a gate, not a second owner) | oracles, real-data | M1-M12 |
| O2.02 | Lots alone determine positions (2) | E14, E19 | 3164 | D11 | M5 |
| O2.03 | No snapshot, configuration or store identity change (2) | E, finalisation | 3164 | D12a (store bindings and config hash on C1) | add a config field |
| O2.04 | No dependency change (2) | DESCRIPTION | 3164 | D12b (DESCRIPTION Imports/Suggests unchanged) | add an import |
| O2.05 | No public API change (2) | NAMESPACE | 3164 | D12c (export census) | add an export |
| O2.06 | No new execution-mode branch (2) | fold | 3165 | D12d (mode-branch census, LTB-0331) | add a branch |
| O2.07 | No compiled default (2) | execution spec | 3164 | D12e (default `compiled_accounting_model` unchanged) | flip the default |
| O2.08 | Release deliverables: tests, performance records, internal contracts, one NEWS entry; public examples and registered oracles preserved (2) | packet | 3169 owns the deliverables | final-candidate record | omit NEWS |
| O2.09 | Q1: dense joins at the normalized decision; observation frozen (2) | E10, E63, E69 | 3165 | D13 | edit a dense view builder |
| O2.10 | Q6: one equity record for both producers (2) | E37-E39 | 3168 | D10 | keep the accumulator |
| O3.01 | Run axis is `instrument_ids` (3.1) | E06, E16 | 3164 | V-book (axis length) | wrong-length positions |
| O3.02 | Context axis in provider order incl. held nonmembers; `context_pos` (3.1) | E52-E54 | 3165 | C15 | M8 |
| O3.03 | Fill and rejection rows carry `k` and `pos = context_pos[k]` (3.1) | E72b, E72c, E73b, E74b, E75 | 3166 | V-fill | `pos` not equal `context_pos[k]` |
| O3.04 | Fold environment locked with its exact slot set (3.1) | fpc | 3164 | V-state (slot set, lock) | add a binding |
| O3.05 | Positions and book retyped; E/stop validator extended (3.1) | E06-E22 | 3164 | V-book | wrong-length book column |
| O3.06 | Packet and decision groups validated at construction (3.1) | E52-E68 | 3165 | V-packet, V-decision | NA in `member` |
| O3.07 | Execution view, plan, fill and rejection validated at construction (3.1) | E62-E78 | 3166 | V-plan, V-fill, V-rejection | unsupported kind code |
| O3.08 | Publication and leg columns validated at construction (3.1) | E79-E86 | 3167 | V-publication | duplicate `event_seq` in a block |
| O3.09 | Staging, equity and stop validated; E/stop validator extended (3.1) | E34-E39, E90-E92 | 3168 | V-diagnostics, V-equity | wrong-type equity column |
| O3.10 | Callback outputs validated where they enter (strategy return; feature callbacks unchanged) (3.1) | E65 | 3165 | D4 plus existing strategy-contract tests | skip return validation |
| O3.11 | Deserialised inputs validated where they enter (E import of resume state and openings) (3.1) | E06, E16, E42-E44 | 3164 | V-book on import | corrupt resume lot row |
| O3.12 | Named adapters only for book, compiled and settlement (3.1) | E02, E12, E15, E21-E22 | 3164 | D3 | name lookup in kernel |
| O3.13 | Named adapters only for packet and P2 (3.1) | E07, E52-E54, E60 | 3165 | D3 | ad hoc `match()` in P2 core |
| O3.14 | Execution view is a declared P3 service (3.1) | E64 | 3166 | D24 (phase service-ownership checker, extended to the named execution-view adapter) | call that service from P4 |
| O3.15 | Publication via named helpers (3.1) | E77-E81 | 3167 | D3 | name lookup in block builder |
| O3.16 | Book hand-outs are copies; candidates and workers isolated (3.1) | E12, E15, E21, E41-E51 | 3164 | C14a, A0 `sweep_w2` | write the book by reference |
| O3.17 | Retained `ctx`, state and corporate-action views unchanged by later pulses (3.1) | E54, E23, E61 | 3165 | C14b | mutate a retained view |
| O3.18 | Publication buffers exclusive (3.1) | E79-E86 | 3167 | C14c | share a staged buffer |
| O3.19 | Copy-on-modify lot kernel (3.1, decision 7) | E18 | 3164 | D15 | `setv` on `lot_qty` |
| O3.20 | P1 order: settlement, disposition, lifetime, re-observation, valuation, equity (3.2) | E02, E52-E53 | 3165 | C12, A0 `avail_*` | swap disposition and valuation |
| O3.21 | Provider and valuation converted once per produced view, mapping reused (3.2) | E52-E53 | 3165 | D16 | convert per column |
| O3.22 | Run-order valuation reductions (3.2) | E08 | 3165 | oracles (equity) | sum in context order |
| O3.23 | Decision packet and private execution packet; P2 gets no next bars (3.2) | E60, E62 | 3165 | D5 | pass `next_bar` to P2 |
| O3.24 | Locators name row and prepared pulse column (3.2) | E60 | 3165 | V-packet | row without column |
| O3.25 | Lazy history cutoff-bound and P2-local; no history access in P3-P5 (3.2) | E60 | 3165 | D21 (phase-ownership checker on P3-P5 substrate access) | injected P3 history read |
| O3.26 | No flat ctx or frame retirement in WS4a (3.2) | P2 | 3165 | D20 (route R8.06) | retire a frame |
| O3.27 | Strategy return normalized once on the complete context axis (3.2) | E65 | 3165 | D4 | second normalization |
| O3.28 | Risk on columns; compiled risk plan validated once in E; dynamic mark, equity and short-exposure checks kept (3.2) | E65 | 3165 | test-risk-fold.R:827 migration, A0 `dense_risk_features` | drop the short-exposure check |
| O3.29 | Raw state update carried unnormalized to P5 (3.2) | E66 | 3165 | oracles (`strategy_state`) | normalize in P2 |
| O3.30 | Intent placement unchanged (3.2) | P2 | 3165 | oracles (diagnostics) | move the intent row |
| O3.31 | Scheduled skip: no strategy call (3.2) | E68 | 3165 | C7 (strategy invocation count) | call strategy on skip |
| O3.32 | Scheduled skip: no planning; still settle, value, bind and commit (3.2) | E76 | 3166 | C7 (planner invocation count) | plan on skip |
| O3.33 | One candidate row per actionable context ordinal (3.3) | E69-E70 | 3166 | V-plan | duplicate a row |
| O3.34 | Cost steps vectorized in order (3.3) | E69-E70 | 3166 | C1 | M10 |
| O3.35 | Notional fee on the unrounded spread price (3.3) | E69-E70 | 3166 | C1, C2 | M9 |
| O3.36 | Final price rounding last (3.3) | E69-E70 | 3166 | C2 | round before spread |
| O3.37 | Effects computed once; no sink recomputes (3.3) | E77-E78 | 3166 | D8 | recompute in payload |
| O3.38 | Execution epochs validated once from the prepared axis (3.3) | E62-E63 | 3166 | D1 | per-fill `as.POSIXct` |
| O3.39 | Affordability scan: cash-generating reductions first, then C-locale stable-ID order (3.3) | E71 | 3166 | C11 | scan in decision order |
| O3.40 | Acceptance mask and permutation private to P3 (3.3) | E71 | 3166 | V-plan (fields not returned) | return the permutation |
| O3.41 | Accepted rows published in decision order (3.3) | E72c, E73b | 3166 | C11 | M4 |
| O3.42 | Early rejections then affordability rejections (3.3) | E72b | 3166 | C11 | merge-sort rejections |
| O3.43 | Reconciliation calculations and tolerance unchanged, including `sum()` (3.3) | E04, E58, E67 | 3166 | C8a, oracles | ordered scan instead of `sum()` |
| O3.44 | Planned after-position is diagnostic only (3.3) | E72c | 3166 | C4, C11 (planned and actual compared separately) | use planned as authority |
| O3.45 | Reasons as ordered code segments; tokens and order preserved (3.3) | E72b, E72c | 3166 | oracles (diagnostics), D22 (dictionary fixtures) | bit mask |
| O3.46 | Empty plans declare no kinds; unsupported kinds refuse before mutation (3.3) | E73a | 3166 | LTB-0026 migration plus empty-plan test | declare FILL on empty |
| O3.47 | Flat segments; FIFO sequential within an instrument (3.4) | E18, E40 | 3164 | C4 | M1 |
| O3.48a | A kernel call takes distinct instruments (3.4) | E18 | 3164 | D18 | accept duplicates |
| O3.48b | Independent lot work vectorized across distinct instruments; FIFO consumption sequential within each instrument; scalar event-order aggregate updates retained (3.4) | E18 | 3164 | D25 | restore a scalar per-instrument lot-operation loop |
| O3.49 | Ordered total-basis and Kahan updates in scalar event order (3.4) | E18, E40 | 3164 | C5b, C9 | M11 |
| O3.50 | Opening: signed quantity, any-sign basis, no cash, no Kahan step (3.4) | E40, E42-E44 | 3164 | C5b, D7 | M6 |
| O3.51 | Fill: dust, fees and reversal arithmetic (3.4) | E18, E40 | 3164 | C3, C4 | M3 |
| O3.52 | Disposition: zero fee, zero price allowed, exhaustive, witness at dust tolerance (3.4) | E48 | 3164 | C6 | leave one live lot; wrong witness |
| O3.53 | Cash outside the kernel (3.4) | E18 | 3164 | D17 | cash inside the kernel |
| O3.54 | Replay adds published effects exactly once (3.4) | E40 | 3164 | D23 (replay cash witness) | apply a delta twice |
| O3.55 | Conflict-free consecutive blocks; carried openings successive (3.4) | E40, E42-E44 | 3164 | C5a | reorder a block |
| O3.56 | Dispositions keep their barriers and duplicate refusal (3.4) | E48 | 3164 | test-terminal-outcomes.R, A0 `avail_terminal_resume` | merge two disposition rows |
| O3.57 | Old named-list FIFO deleted (3.4) | E16-E51 | 3164 | D19 | keep `ledgr_lot_apply_fill` |
| O3.58 | Metadata preparation kept until WS7 (3.4) | E40 | 3164 | D20 (route R8.07) | remove the preparer |
| O3.59 | Singleton replay only if the replay gate passes (3.4, decision 6) | E40 | 3164 | reader cells, replay memory | a deliberately slowed replay arm (an injected per-event copy) must fail the reader cell |
| O3.60 | Compiled pack and unpack by gather; aggregates and Kahan state exact; C++ unchanged (3.4) | E21-E22, E51 | 3164 | C9 | M12 |
| O3.61 | Bind the next corporate-action boundary before fills (3.5) | E12 | 3167 | A0 `dense_dividend_state`, C12 | bind after fills |
| O3.62 | Candidate block computed without mutation (3.5) | E73b | 3167 | C13b | install row one before row two validates |
| O3.63 | Install order: book, publish, sequence, legs, positions and cash (3.5) | E73b, E79, E84 | 3167 | W1 (application-order witness) | swap each observed pair |
| O3.64 | Append, fact/leg and flush failures abort; durable rollback; no successful memory result; classes and stage kept; no private-state restore promised (3.5) | E79-E84 | 3167 | C13c, LTB-0280 migration | swallow an injected error |
| O3.65 | Checkpoint and interrupt behaviour unchanged (3.5) | P5, E | 3167 | existing checkpoint tests, A0 `run_interrupted` | flush checkpoint mid-block |
| O3.66 | Compiled state-before-append order (3.5) | E80 | 3167 | W1 (at compiled append entry, the compiled lot state and next sequence are installed) | append before state |
| O3.67 | Fills published as columns; event IDs per block (3.5) | E79 | 3167 | D1, D9 | per-fill list |
| O3.68 | P1 non-fill builders keep order; adapt once into the indexed buffer (3.5) | E81 | 3167 | A0 `dense_dividend_state`, `avail_acquisition` | defer non-fill rows to P5 |
| O3.69 | `meta_json`, memory `meta`, auxiliaries and leg-fee arithmetic unchanged (3.5) | E79-E85 | 3167 | oracles | drop the meta list |
| O3.70 | No Accounting DDL, validator, fallback deletion or reader change (3.5) | all | 3167 | D20 (routes R8.07-R8.10) | add a ledger column |
| O3.71 | Pulse staging in emission order; reset after P5 or E; pinned capacity; no strategy replay (3.6) | E34, E87 | 3168 | D2, C18 | retain staging |
| O3.72 | Existing writer splits chunks; no run-long staging; no second writer (3.6) | E88 | 3168 | C18 | drop a split tail |
| O3.73 | Full logical trace; memory filter and sequence gaps unchanged (3.6) | E89 | 3168 | A0 `memory_diagnostics`, C18 | filter in the fold |
| O3.74 | Equity record per valued pulse with used-row count; frozen prefix to finalisation and inline summary; no memory replay (3.6) | E37-E39 | 3168 | C18, A0 `avail_incomplete` | expose an unused row |
| O3.75 | Two clocks distinct (3.6) | E30-E31 | 3168 | C18 | set last_executed from valuation |
| O3.76 | Finalisation selects equity by producer (3.6) | E37 | 3168 | C16 | restore the old decision |
| O3.77 | P5 order: flush, reconciliation, state, progress, telemetry, checkpoint (3.6) | P5 | 3168 | oracles | swap state and flush |
| O3.78 | E alone installs stops; counted pulses kept (3.6) | E90-E92 | 3168 | C8a, A0 `avail_incomplete` | count a non-counting stop |
| O3.79 | Stop class and affected exposure kept; stop diagnostics staged (3.6) | E90-E92 | 3168 | C8a, C18 | drop the stop segment |
| O3.80 | Telemetry arrays unchanged (3.6) | E93-E94 | 3168 | existing telemetry tests | drop a sample |

### 3.2 Synthesis Section 4 field invariants

Structural field controls are refused by construction validators
(Section 6, V-*). Transition and preservation controls are checked at the
operation or handoff with their required before/after inputs; they are not
malformed standalone records. Rows F4.19, F4.35, F4.37 and F4.49 below are
of that kind and name their check. No extra carrier field or new semantic
refusal is introduced to make an observation.

**Universal construction rule.** For every column group, construction
checks the exact declared storage types, axis lengths, bounds and the typed
length-zero representation with `n = 0` where applicable. The synthesis's
scalar and opaque exceptions (`state_update`, `affected_exposure`, timing
scalars) are preserved. One row per owner:

| ID | Groups (constructors and validator) | Owner | Controls (each must fail its check) |
| --- | --- | --- | --- |
| U-3164 | book (`ledgr_carrier_book()`, V-book); lot input (V-lot-input); applied row (V-applied-row) | 3164 | replace a storage type; shorten one column; violate a bound; replace a typed empty column with an untyped empty list |
| U-3165 | decision packet, decision data, execution packet (`ledgr_carrier_packet()`, V-packet with three subgroups); decision (V-decision) | 3165 | same four controls |
| U-3166 | execution view (V-execution-view); plan (V-plan); fill (V-fill); rejection (V-rejection) | 3166 | same four controls |
| U-3167 | publication (V-publication); leg (V-leg) | 3167 | same four controls |
| U-3168 | diagnostics staging (V-diagnostics); equity (V-equity); typed stop payload (V-stop) | 3168 | same four controls |

Field invariants:

| ID | Group: fields (invariant) | Owner | Control (structural: invalid record refused by the group validator; otherwise the named check) |
| --- | --- | --- | --- |
| F4.01 | state: cash finite; positions equal lot-derived net | 3164 | NaN cash; positions differ from `net_by_inst` |
| F4.02 | state: event_seq >= 1; diagnostic_seq >= 0 | 3164 | event_seq 0 |
| F4.03 | state: state_prev, state_axis lifecycle | 3164 | numeric state_axis |
| F4.04 | state: status, stop_reason, current_stage tokens | 3164 | NA status |
| F4.05 | state: affected_exposure fields | 3164 | missing `specified` |
| F4.06 | state: processed, telemetry_idx >= 0; full_run non-missing | 3164 | NA full_run |
| F4.07 | state: last_fully_valued, last_executed, current_ts POSIXct scalars | 3164 | numeric last_executed |
| F4.08 | state: frozen_set character IDs | 3164 | NA in frozen_set |
| F4.09 | state: pending_segments and equity_facts are the typed groups | 3168 | list staging |
| F4.10 | book: offset, capacity, head, tail integer run axis; disjoint; empty head/tail 1/0 | 3164 | overlapping segments |
| F4.11 | book: lot_qty, lot_price live finite, dead NA | 3164 | NA in a live slot |
| F4.12 | book: net_by_inst, cost_basis_by_inst lot-derived | 3164 | net differs from live lots |
| F4.13 | book: totals scalars finite | 3164 | NaN realized_comp |
| F4.14 | packet: pulse_idx valid; ts epoch; context_pos unique run positions; empty allowed | 3165 | duplicate context_pos |
| F4.15 | packet: cash, positions_value, position finite | 3165 | NaN position |
| F4.16 | packet: member, held, buyable, target_restricted logical, no NA; buyable implies member | 3165 | buyable non-member |
| F4.17 | packet: restriction segment ordered, codes in dictionary | 3165 | code 7 |
| F4.18 | packet: status, lifetime codes; terminal_event, lifetime_fact_id character with empty strings | 3165 | NA terminal_event |
| F4.19 | packet: mark, reference, source_ts, mark_age, mark_source independent | 3165 | adapter preservation check: provider/valuation inputs compared with the constructed packet field by field, including an expired unpriced mark with retained provenance; control erases age, source or reference in the adapter |
| F4.20 | packet: priced, permissible, frozen independent flags | 3165 | NA permissible |
| F4.21 | decision data: current bars only, missing cells retained | 3165 | next-bar column present |
| F4.22 | decision data: source_row and source_column; feature handles immutable | 3165 | row without column |
| F4.23 | execution packet: exec_ts, has_next explicit; continuation preserved | 3165 | has_next NA |
| F4.24 | execution view: member, restricted, reason segments | 3166 | unequal segment lengths |
| F4.25 | decision: targets full and finite; actionable_k ordered | 3165 | NA target |
| F4.26 | decision: state_update opaque; intent_reason existing validation | 3165 | non-character intent |
| F4.27 | plan: accepted, afford_order private; expected_final_cash (dense unused; skip equals cash) | 3166 | skip cash differs |
| F4.28 | plan: economic_event_kinds empty or supported | 3166 | unsupported code |
| F4.29 | fill: k, pos, side (+/-1); distinct pos; decision order | 3166 | side 0 |
| F4.30 | fill: qty, price, fee, effects, exec_ts valid | 3166 | negative fee |
| F4.31 | fill: position_before, planned_position_after (planned only) | 3166 | NA planned |
| F4.32 | fill: info segment ordered and deduplicated | 3166 | duplicate code |
| F4.33 | rejection: k, pos, emit; reason segment; primary separate | 3166 | emit out of order |
| F4.34 | rejection: resolved_price, exec_ts NA only when absent; position finite | 3166 | NA position |
| F4.35 | lot input: per-kind rules (opening signed qty; disposition witnesses) | 3164 | V-lot-input for the declared operation fields (invalid record: operation-row pos = 0L, outside the one-based run-axis bounds); no cash effect of openings checked by D17 plus an opening caller's cash before/after witness, control: a mutant changes opening cash |
| F4.36 | applied row: positions actual from lots; open/close zero when inapplicable | 3164 | open_qty on a pure close |
| F4.37 | applied row: per-event facts; opening does no Kahan step | 3164 | C5b and D7 invocation check; control: an injected Kahan invocation on openings (M6) |
| F4.38 | publication: identifiers and tokens, nullability, generated in blocks | 3167 | NA instrument_id on FILL |
| F4.39 | publication: numeric fields, contiguous fill seq | 3167 | gap in fill seq |
| F4.40 | publication: meta_json, meta, auxiliaries unchanged | 3167 | missing meta on memory sink |
| F4.41 | leg: CLOSE then OPEN | 3167 | OPEN before CLOSE |
| F4.42 | leg: fee split, opening leg P&L 0 | 3167 | nonzero OPEN P&L |
| F4.43 | diagnostics: character columns exact strings and defaults | 3168 | NA reason_code default |
| F4.44 | diagnostics: integer columns and NA defaults; logical sequence counts dropped rows | 3168 | sequence gap removed |
| F4.45 | diagnostics: time columns epoch; decision defaults to pulse | 3168 | NA decision time |
| F4.46 | diagnostics: numeric columns planned/actual meanings | 3168 | actual in place of planned |
| F4.47 | diagnostics: n <= capacity; reset on drain | 3168 | n not reset |
| F4.48 | equity: five columns plus n; only first n valid; capacity = pulse count | 3168 | n beyond capacity |
| F4.49 | stop: class, count and exposure semantics; E applies once | 3168 | V-stop for the payload shape (invalid record: non-logical `counts_processed`); an E application counter for "applies once", control: invoke stop application twice |
| F4.50 | timing: transient stage measurements (unchanged; checked by the existing telemetry tests) | 3168 | negative stage time |
| F4.51 | telemetry: sample indexing and totals (unchanged; checked by the existing telemetry tests) | 3168 | skip a sample index |

### 3.3 Synthesis Section 5 evidence rows

| ID | Evidence row | Owner of the check | Check | Control |
| --- | --- | --- | --- | --- |
| E5.01 | Exact successful outputs | 3169 | oracles, real-data | any M |
| E5.02a | Cost semantics | 3166 | C1, C2 | M9, M10 |
| E5.02b | Lot semantics | 3164 | C3-C6 | M1, M3 |
| E5.03 | Axis and clocks | 3165 | C7, C10, C12, C15, C17 | M8 |
| E5.04a | Lifecycle and ownership: book, compiled, stops and resume | 3164 | C14a, C9, A0 stops and resume | by-reference book write |
| E5.04b | Lifecycle and ownership: retained views | 3165 | C14b | mutate a retained view |
| E5.04c | Lifecycle and ownership: publication buffers | 3167 | C14c | reuse staging |
| E5.05a | Mutation strength: LIFO, opening Kahan | 3164 | M1, D7 | M1, M6 |
| E5.05b | Mutation strength: affordability-order publication | 3166 | C11 | M4 |
| E5.05c | Mutation strength: reordered publication, dropped fee | 3167 | oracles through the typed path | M2, M3 |
| E5.06 | Failure boundary | 3167 | C13b, C13c | swallow an error |
| E5.07 | Representation detectors | the ticket named for each detector in Section 8 | D1-D13, D15-D25 | each detector's own control |
| E5.08 | Dense finalisation | 3168 | C16 | restore the old decision |
| E5.09a | Timing and memory of reader and replay paths (decision 6) | 3164 | ws4a-timing-1 reader cells, replay memory | a deliberately slowed replay arm |
| E5.09b | Timing and allocation, full matrix | 3169 | ws4a-timing-1, absolute checker | absolute-checker controls |
| E5.10 | Scale | 3169 | memory method (Section 7) | calibrated excess |

### 3.4 Synthesis Section 8 routes

All are verified by LDG-3169 with D20: a named-boundary diff of the listed
operations plus the relevant output witness; the control is a deliberate
change to that boundary.

| ID | Route (owner) | Boundary watched |
| --- | --- | --- |
| R8.01 | Provider/valuation adapters removed (WS4b) | `ledgr_carrier_provider_view()` kept |
| R8.02 | Selective diagnostic materialisation (WS4b) | memory filter oh:362-378 unchanged |
| R8.03 | H5 reconciliation JSON (WS4b) | fe:1462-1483 encode kept |
| R8.04 | State normalization and serialization (WS4b/WS5) | fe:1509-1527 kept |
| R8.05 | Intent JSON and typed declared state (WS5) | fe:878-888 kept |
| R8.06 | Context frames (WS6) | bar and feature frames kept |
| R8.07 | Metadata preparation and read architecture (WS7/WS8) | `ledgr_prepare_accounting_events()` kept |
| R8.08 | Non-fill builders and evidence (WS7/WS8) | to:126, cas:545, feb:114 builders kept |
| R8.09 | Fill and non-fill JSON incl. db_live (WS7/WS8) | `meta_json` encode sites kept |
| R8.10 | Memory meta, aggregate auxiliaries, store change (WS7/WS8) | memory columns and schema kept |
| R8.11 | Cold stop and exception encoding (unchanged) | fe:2067-2078, stop `detail_json` kept |
| R8.12 | `canonical_json()` cache retires with its last hot caller (WS4b/WS5) | cache code untouched |
| R8.13 | Native-resident lot state (compiled-envelope RFC) | `src/` unchanged |
| R8.14 | D2 position facts consume transitions; no WS4a D2 slots or schema (WS5) | no new slots beyond `equity_facts` |

### 3.5 Synthesis Section 9 scenarios

| ID | Scenario | Owner | Case |
| --- | --- | --- | --- |
| S1 | Context reordered, run axis fixed | 3165 | C15 |
| S2 | Buy before funding sell in decision order | 3166 | C11 |
| S3 | Unpriced expired holding or disposition followed by fill | 3165 | C12 |
| S4 | Repeated opening with residual Kahan compensation | 3164 | C5b |
| S5 | Later FIFO row fails; handler append fails | 3167 | C13b, C13c |
| S6 | Diagnostic pulse exceeds a writer chunk; run stops early | 3168 | C18 |
| S7a | Compiled input survives another pulse | 3164 | C14a |
| S7b | Retained view survives another pulse | 3165 | C14b |

### 3.6 Review obligation

| ID | Obligation | Owner | Check | Control |
| --- | --- | --- | --- | --- |
| RCR | Independent cold read of every changed stage from code and Synthesis Section 4 | 3169 | workstream 13 close review | a deliberately omitted stage explanation fails the review item |

## 4. New cases for LDG-3163 (scope c)

Recorded on the base by `dev/bench/v0_2_3_ws4a/record.R`, checked exactly by
`check.R` (lossless RDS plus `%.17g` CSV, the A0 serialization). Each gut in
`guts.R` must fail its case.

| Case | Owner | Workload | Frozen outputs | Gut |
| --- | --- | --- | --- | --- |
| C1 | 3166 | Dense durable run and availability sweep with spread 7 bps, fixed 1.25, notional 3 bps; BUY, SELL and a reversal that splits the fee | ledger with `meta_json`, fills, trades, legs, equity | drop the notional step |
| C2 | 3166 | Spread-adjusted prices with more than 8 decimals, including a near-half tie at digit 9, both sides | fills, ledger | notional from the rounded price |
| C3 | 3164 | Fractional fills reaching `ledgr_lot_dust_tolerance` in fold and replay, with fees | ledger, equity, logical FIFO book | tolerance x10 |
| C4 | 3164 | Dense long to short to long with chained costs; at least two live lots with unequal basis before each partial close | ledger, legs, trades, equity; planned and actual positions | LIFO consumption |
| C5a | 3164 | Walk-forward carry of several fractional-basis lots across two boundaries, then partly consumed | opening `meta_json`, replayed book | reorder carried openings |
| C5b | 3164 | Successive opening operations applied to a book with explicitly nonzero `realized_comp`, signed quantities, positive and negative basis | Kahan invocation count 0; bit-identical compensation | Kahan step on openings (M6) |
| C6 | 3164 | Multi-lot fractional disposition, plus a zero-price, zero-fee exhaustive disposition, plus a deliberately wrong replay `realized_model_pnl` witness | ledger, book after replay; refusal of the wrong witness | leave one live lot |
| C7 | 3165, 3166 | Scheduled skips with stale marks and fills on due pulses | diagnostics including skip rows, fills, equity; strategy and planner invocation counts | plan on a skip pulse; call strategy on a skip pulse |
| C8a | 3166 | Small-cash availability fixture; perturb `expected_final_cash` by +1 at the return of `ledgr_fold_build_availability_pulse_plan()` (ae:517-526), before P3's reconciliation; the typed adapter attaches at the equivalent planner return | INCOMPLETE completion, stopped diagnostic and detail, counts, both clocks; injection executed once; mismatch beyond the existing relative tolerance | suppress the stop |
| C8b | 3166 | Perturb the plan after P3 returns, before P4 | the existing P5 reconciliation exception, invocation rollback, no successful memory result | suppress the exception |
| C9 | 3164 | Compiled sweep, fractional quantities, nonzero `realized_comp` over at least two pack/unpack cycles | lot state, events, summaries | drop `realized_comp` in unpack (M12) |
| C10 | 3165 | Availability run with empty context on some pulses | settlement, valuation, equity, diagnostics | skip valuation on empty context |
| C11 | 3166 | Cash-bound pulse: a buy precedes its funding sell in decision order, and decision order differs from stable-ID order | ledger order, reconciliation and rejection rows | publish in affordability order (M4) |
| C12 | 3165 | Disposition cash funding a later fill | ledger, equity | fill before settlement |
| C13a | 3167 | Base: second lot-operation failure | existing external failure class, stage, durable rollback, failed memory result; the observed private prefix recorded, not used as an oracle | swallow the error |
| C13b | 3167 | Typed: second-row failure during candidate computation | book, cash, positions, `event_seq` and buffers identical to snapshots taken before candidate computation (a new assertion implementing Synthesis 3.5, not a base identity claim) | install or publish row one before row two validates |
| C13c | 3167 | Both representations: append, accounting-fact/leg and flush failures after successful calculation, each injected separately; named base and typed attachment adapters | abort, whole-invocation durable rollback, condition and stage evidence, no successful memory result; no private-state restore asserted | swallow each injected error |
| C14a | 3164 | Book and compiled inputs retained across a later pulse | retained values unchanged | write the shared book buffer by reference |
| C14b | 3165 | Retained `ctx$vec` vectors, `state_prev`, availability context and corporate-action state views | retained values unchanged | write the retained view's buffer |
| C14c | 3167 | Published event and leg blocks retained across a later pulse | retained blocks unchanged | reuse the staging buffer |
| C15 | 3165 | v201 availability witness with a `context_pos` mutation | existing exact outputs | wrong `context_pos` (M8) |
| C16 | 3168 | Dense durable run; trace `ledgr_replay_accounting_events()` and `ledgr_run_equity_prefix_commit()` during `ledgr_run_finalize()` only | replay used, prefix commit unused, equity bytes identical | base: force `use_fold_equity = TRUE` at that decision; typed: restore the old decision after asserting dense populated the record |
| C17 | 3165 | Continued final-window execution (carry chain), fees and fractional quantities, plus a standalone-window control | ledger, diagnostics | drop the continuation opportunity |
| C18 | 3168 | Availability run with one pulse larger than an injected writer chunk of 7, followed by an early stop; reuse the v201 fixture and its helper where suitable, without changing its oracle | durable diagnostics, filtered memory diagnostics with sequence gaps, equity used prefix, processed count, both clocks; large pulse and early stop asserted | drop a split tail; retain previous staging; drain unused equity rows |

## 5. Test-migration list (scope d, decision 10)

One row per block. "Keeps" are the retained assertions; "control" is the
violation that must fail the migrated block. Categories: 1 construct typed
containers; 2 same logical FIFO witness; 3 source predicate restated on
columns; 4 economic assertion moves to the typed implementation with the
same inputs and values; 5 shape change, reason stated. Fixture or fault
changes are named individually; none is purely mechanical.

| Test block | Claim | Cat | Change | Keeps | Control |
| --- | --- | --- | --- | --- | --- |
| helper-fixtures.R:130 | - | 1 | one-row typed fill batch through the batch resolver | fill values | wrong price |
| test-accounting-core-consolidation.R:31 | LTB-0019 | 2 | typed book and operations; the original fixture is kept intact | every assertion in the existing block (:36-101), with unchanged inputs and tolerances: all intermediate realized, net and basis values, exact logical live lots, empty live counts, the 512-lot result, no cash or positions fields in the book, per-transition dust and single-sign bounds, and the final fractional P&L, basis and live tuple; only extraction from the container changes | M1 for FIFO; dropped fee for fee-adjusted values; a retained consumed lot for the empty and deep-book results; an injected cash or positions field for book ownership; a corrupted cached net or a retained opposite-sign live quantity for the per-transition invariants; each final fractional value perturbed beyond its existing tolerance |
| test-accounting-core-consolidation.R:211 | LTB-0022 | 5 | kernel and its rescan mutant rebuilt on the typed book; reason: the measured object moved | thresholds <=0.30 and >0.30 | the rescan mutant |
| test-lot-accounting.R:1 | - | 4 | typed fill operation | `ledgr_invalid_lot_fill` on the four inputs | accept qty 0 |
| test-lot-accounting.R:22 | - | 2 | typed book | zero lots, zero basis | tolerance /10 |
| test-cross-asset-corrections.R:88 | LTB-0497 | 2 | `net_by_inst`, live-lot count from the typed book | position 0, held flags | tolerance /10 |
| test-cross-asset-corrections.R:240 | LTB-0498 | 2+3 | typed R side; compiled call on columns; predicates name the typed position read and unpack gather | R and C++ identical on every field | M12 |
| test-execution-spec.R:1 helper | - | 2 | logical live lots and aggregates | same fields | drop `realized_comp` |
| test-execution-spec.R:115 helper | - | 1 | typed spec state | economics | wrong opening |
| test-execution-spec.R:239 helper | - | 1 | typed spec state | economics | wrong opening |
| test-execution-spec.R:523 | LTB-0026 | 3+5 | mock the typed plan builder; kinds as codes; reason: the pulse-plan object is retired | all three injected kinds (CASHFLOW, DISPOSITION, SYNTHETIC_UNKNOWN), canonical CASHFLOW acceptance, compiled refusals with their classes | accept SYNTHETIC_UNKNOWN |
| new block (test-ws4a-carrier.R) | - | - | empty-plan construction declares no kinds | (separate test, not a replacement) | declare FILL on empty |
| test-execution-spec.R:576 | LTB-0006 | 1+2 | dust seed book built typed | every parity assertion | M12 |
| test-execution-spec.R:749 | LTB-0013 | 2 | typed state | every parity assertion | M12 |
| test-fold-phase-contract.R:3 | LTB-0278 | 1+5 | typed constructor; equity record replaces the accumulator; the unnamed-positions refusal inverts, reason: positions become an unnamed run-axis vector (Synthesis 3.1) | closed slot set, no data-frame slot; replacement refuses wrong-length positions | accept wrong length |
| test-fold-phase-contract.R:85 | LTB-0279 | 3 | phase-ownership checker tables updated for new slots and methods | one owner per slot | second writer |
| test-risk-fold.R:83 | - | 5 | "all costs resolved before any publication" per block; reason: one block per pulse | costs before emission | publish before resolve |
| test-risk-fold.R:122 | LTB-0281 | 3 | frozen name sets for the typed groups | packet order, no data frames | extra field |
| test-risk-fold.R:192 | LTB-0136 | 5 | write count per block; reason: one block per pulse | flushes == 3 | extra flush |
| test-risk-fold.R:255 | LTB-0137 | 5 | injection at the second row of candidate computation; reason: `ledgr_lot_apply_fill` is deleted | FAILED, zero rows, sibling identical | partial publish |
| test-risk-fold.R:345 | LTB-0280 | 5 | existing fixture and values kept; separate write and accounting-fact failure checks at the corresponding block boundaries; a two-pulse fixture added as an additional rollback witness, not a replacement; reason and the changed fault timing need the cut's acceptance | atomicity on durable and memory | swallow append error |
| test-risk-fold.R:515 | - | 4+5 | post-risk quantity reaches the batch resolver; per-batch call protocol | qty 10 at cost | pre-risk qty |
| test-risk-fold.R:827 | - | 5 | missing-target refusal kept at initial normalization; the moved post-risk check injects a nonfinite transformed quantity and keeps `ledgr_invalid_post_risk_targets` with parent `ledgr_invalid_strategy_result`; reason: duplicate shape/name normalization deleted (Synthesis 3.2) | class and parent | wrong parent |
| test-corporate-action-disposition.R:53 helper | - | 1 | typed state | values | wrong lot |
| test-corporate-action-disposition.R:108 | LTB-0050 | 1+2 | typed state and book | position 0, no lots, realized -20 | leave a lot |
| test-corporate-action-disposition.R:177 | LTB-0051 | 1 | no-mutation witness compares the typed carrier | cash 1180/1160/1170 | mutate on refuse |
| test-sweep.R:46 | - | 1 | one-row typed block into the handler | typed events equal ledger rows | wrong column |
| test-sweep.R:91 | - | 1 | typed blocks, 1025 events | full columns across growth | lose a column at growth |
| test-sweep.R:146 | - | 1 | typed blocks | single-pass summary equals reconstruction | drop a fill |
| test-sweep.R:220 | - | 1+4 | typed opening, fill operation, block publication | inline equals reconstructed; legs 2/1; attrs | drop OPEN leg |
| test-ledger-writer.R:58 | - | 1 | one-row typed input | FILL row and meta deltas | wrong sign |
| test-ledger-writer.R:103 | - | 1 | one-row typed input | hidden until flush | write through before flush |
| test-ledger-writer.R:220 | LTB-0135 | 1 | one two-row block | hidden until flush, order | reorder |
| test-ledger-writer.R:302 | LTB-0188 | 3 | predicates name indexed column writes; allocation probe on a block write | no per-write copy | copy a column per write |
| test-ledger-writer.R:442 | - | 1 | typed blocks | full columns across growth | lose a column at growth |
| test-ledger-writer.R:753 | - | 1 | one-row typed input | SELL deltas | wrong sign |
| test-ledger-writer.R:781 | - | 1 | two typed writes | event_seq increments | reuse a sequence |
| test-ledger-writer.R:811 | - | 5 | zero-row block is the no-op; reason: `ledgr_fill_none` retired | NO_OP status, no rows | write a row |
| test-ledger-writer.R:829 | - | 1 | typed input | duplicate (run_id, event_seq) refusal, unchanged row count | accept the duplicate |
| test-ledger-writer.R:855 | - | 1 | typed input | invalid-sequence refusal, zero inserted rows | insert before validation |
| test-ledger-writer.R:880 | LTB-0515 | 5 | deltas computed once in P3; call count becomes "one computation per fill, zero in sinks"; reason: Synthesis 3.3 | direct delta oracle values (lines 918-925) | recompute in a sink |
| test-ledger-writer.R:1031 | LTB-0516 | 1+5 | db_live validation on column input | `ledgr_invalid_fill_intent` on bad side and fee; unknown run; NO_OP; transaction sequence | accept a bad fee |
| test-ledger-writer.R:1115 | LTB-0518 | 3 | frozen method sets updated for the block methods | shared mechanisms | duplicate mechanism |
| test-ledger-writer.R:1166 | LTB-0521 | 1+5 | equity part reads the preallocated record; equity-buffer growth retired, reason: the record is preallocated | all 300 values, empty-record semantics, diagnostic and state growth assertions | drop a used row; expose an unused row |
| test-fill-model.R:1 | - | 4 | batch resolver, one row | rounding to 8 digits | round to 7 |
| test-fill-model.R:27 | - | 5 | epochs inside, POSIXct at the boundary; reason: Synthesis 4 | boundary output POSIXct UTC | POSIXct inside the carrier |
| test-fill-model.R:46 | - | 4 | refusal at epoch validation | `LEDGR_SUBSECOND_TIMESTAMP` | accept sub-second |
| test-fill-model.R:59 | - | 5 | instrument, side, quantity and OHLCV values kept as typed-input projection assertions; only proposal/context S3 shape assertions retire | original values | corrupt instrument mapping; corrupt each projected bar field |
| test-fill-model.R:96 | - | 5 | as :59 for the matrix-backed context | original values | as :59 |
| test-fill-model.R:118 | - | 4 | batch resolver | spread symmetry | same sign both sides |
| test-fill-model.R:158 | - | 4 | batch resolver | fee 2.5, `ledgr_invalid_cost_model` | accept negative fee |
| test-fill-model.R:184 | LTB-0002 | 4 | `has_next = FALSE` path | NO_FILL with `LEDGR_LAST_BAR_NO_FILL` | no warning |
| test-fill-model.R:197 | - | 4 | batch resolver | Inf, NaN, negative spread refusals | accept Inf |
| test-cost-model.R:229 | - | 4 | batch resolver | notional on unrounded spread price | M9 |
| test-derived-state.R:61 | - | 1 | ledger built from typed blocks | deterministic reconstruction | drop a row |
| test-release-coverage-branches.R:110 | - | 1+5 | branch tests on the column payload builder | refusal class, deltas -21/2 and 19/-2 | wrong delta |
| test-runner.R:252 | - | 5 | spy on the column writer signature | state written after fills | state first |
| test-availability-diagnostic-production.R:15 helper | - | 1 | typed staging block | default block | missing column |
| test-availability-diagnostic-production.R:32 | - | 1 | typed staging block | production default is one block | two blocks |
| test-availability-diagnostic-production.R:46 | - | 1 | typed staging block | chunk split and types | lose a row at a split |
| test-availability-diagnostic-production.R:95 | - | 1 | typed staging block | chunk survives append failure | drop the chunk |
| test-availability-economics.R:303 | - | 4 | typed affordability scan | accepted order, final cash, reasons | M4 |
| test-availability-economics.R:379 | - | 4 | typed affordability scan | short cover cash | wrong sign |
| test-availability-parity.R:915 | LTB-0024 | 2 | basis from the typed book | equals the second opening's basis | wrong basis |
| test-strategy-schedule.R:1233 | LTB-0507 | 2 | logical FIFO witness instead of container identity | economics, resume | M1 |
| test-terminal-outcomes.R:651 | LTB-0171 | 2 | live-lot count from the typed book | one live lot | commit before failure |
| test-codebase-contracts.R:114 | LTB-0331 | 5 | mode-branch census regenerated; reason: stage bodies rewritten; every remaining row keeps its owner | no new branch | add a branch |
| test-codebase-contracts.R:20 | LTB-0270 | - | no change expected; deleted helpers lose their callers together | as today | orphan helper |
| test-codebase-contracts.R:44 | LTB-0271 | - | no change expected; classes survive (2.2) | as today | remove a class |

Claim prose naming removed constructs is updated in `tests/claims.yml`:
LCL-0022 (`pulse_plan`), LCL-0135 ("fill intents"), LCL-0279 ("short-lived
list shape"). Watch-list blocks change only if a boundary adapter loses
names; they are not planned changes.

## 6. Detectors, validators and mutations (scope e)

Detectors and validators live in `tests/testthat/test-ws4a-carrier.R`; each
names the functions or parse regions it examines and demonstrates its own
failing control. Another detector's failure is not evidence for it.

| ID | Predicate | Examines | Own control |
| --- | --- | --- | --- |
| D1 | No list, S3 object or POSIXct conversion per fill | parse regions of both planners, P3, P4 and the publication helpers | `vector("list", n_fill)` or `as.POSIXct` in the fill loop |
| D2 | Staging used count returns to zero at each drain; only the used prefix is handed out; staging from the prior pulse is never retained, even at constant capacity | runtime hooks on the staging object across pulses | retain the prior pulse's rows |
| D3 | No character indexing on run- or context-axis vectors in the lot kernel, migrated book consumers, P2 core, P3 and the block builder | parse regions listed | `net_by_inst[[id]]` |
| D4 | Strategy return shape/name normalized once per pulse | runtime counter on the normalizer | a second call |
| D5 | P2's input carries no execution-packet field | runtime check on the P2 argument | pass `next_bar` |
| D6 | No JSON encode or parse in the pulse loop beyond the routed sites (fill and non-fill `meta_json`, H5, intent reason, stop and exception detail, and P5's per-pulse strategy-state serialization `canonical_json(state_update)` at fe:1521, route R8.04) | parse-tree allowlist over fold stage functions | new `canonical_json` call in P3 |
| D7 | No Kahan step on opening rows; nonzero compensation preserved | runtime counter in the typed operations, C5b | M6 |
| D8 | No fill-intent object in the fold or sinks; effects computed once | parse regions plus a counter on `ledgr_fill_publication_deltas` | reconstruct an intent; compute twice |
| D9 | No per-fill economic staging list and no per-leg staging list in publication; routed memory `meta` allowed | parse regions of the handler and memory sink | staged per-fill or per-leg list |
| D10 | Exactly one equity writer per valued pulse on both producers; no accumulator in fold or service slots | runtime count plus slot inspection | keep the accumulator |
| D11 | Positions read only from `net_by_inst` | parse regions of P4 and replay | `positions + delta` |
| D12a-e | Store bindings and config hash; DESCRIPTION; export census; mode-branch census; compiled default | existing contract tests and a C1 config-hash witness | change each |
| D13 | Dense observe/ctx builders unchanged | source hash of `ledgr_pulse_context`, `ledgr_update_pulse_context_helpers` and `ledgr_dense_eligibility_planes` (frozen in `records/detectors/frozen.csv`); `ledgr_fold_build_pulse_plan` was also frozen at LDG-3163 but leaves the list when LDG-3166 retypes the dense planner (Q1 freezes observation, not planning) | edit a dense view builder |
| D15 | No by-reference write on book columns | parse regions of the kernel | `collapse::setv(book$lot_qty, ...)` |
| D16 | Provider adapter called once per produced view | runtime counter | per-column conversion |
| D17 | Lot kernel computes no cash | parse region of the kernel | cash inside the kernel |
| D18 | A kernel call refuses duplicate instruments | unit test | accept duplicates |
| D19 | No named-list FIFO function defined in `R/` | parse census of definitions | define `ledgr_lot_apply_fill` |
| D20 | Each Section 3.4 route's named operation and its output witness unchanged | per-route boundary diff plus witness | change the boundary |
| D21 | No history or substrate access in P3-P5 | phase-ownership checker (`tools/check-fold-phase-contract.R`) | injected P3 history read |
| D22 | Dictionaries match literal fixtures (tokens and codes) | fixture comparison, separate from diagnostic round-trip bytes | renumber a token |
| D23 | Replay applies each published cash effect exactly once | replay cash witness on a two-event ledger | apply a delta twice |
| D24 | Service ownership: the execution view and history services are called only from their declared stages | phase-ownership checker (`tools/check-fold-phase-contract.R:66-81, :149-153`), extended to `ledgr_carrier_execution_view()` | call the execution view from P4 |
| D25 | Independent lot consumption, append, compaction and growth are not dispatched through an R loop one input instrument at a time. Permit FIFO depth iteration and the scalar event-order total-basis/Kahan scan that writes per-event aggregate facts; opening rows perform no Kahan step. Cash remains outside the lot kernel. | parse regions of the kernel, with the ordered aggregate-scan region explicitly identified; replay is not examined while decision (6) permits singleton replay calls, and LDG-3164 extends the examined list with the typed operation names | restore a scalar per-instrument lot-operation loop: must fail D25; retain the permitted aggregate scan: must pass D25 |
| W1 | Application order: at the canonical publication entry the candidate book is already installed; sequence advance, leg recording and position/cash installation follow in that order; at compiled append entry the compiled lot state and next sequence are installed | runtime witness at those entries | swap each observed pair |

**Validator map** (constructors and validators, `test-ws4a-carrier.R`):
V-state (fold state, 3164); V-book (3164); V-lot-input (3164);
V-applied-row (3164); V-packet with three subgroups: decision packet,
decision data, execution packet (3165); V-decision (3165);
V-execution-view (3166); V-plan (3166); V-fill (3166); V-rejection (3166);
V-publication (3167); V-leg (3167); V-diagnostics (3168); V-equity (3168);
V-stop (3168). Each enforces the universal construction rule and its
Section 3.2 structural rows; C13b keeps only candidate-calculation
atomicity and C9 only compiled value parity.

Mutations, applied by `dev/bench/v0_2_3_ws4a/guts.R` and run through the
typed path: M1 LIFO consumption; M2 reordered fills within a pulse; M3
dropped fee; M4 affordability-order publication; M5 positions as positions
plus delta; M6 Kahan step on openings; M7 skip a partial close's remainder;
M8 wrong `context_pos`; M9 notional fee from the rounded price; M10 drop
the notional step; M11 `cumsum` totals; M12 drop `realized_comp` in unpack.

## 7. Timing, memory and budget (scope f)

**Protocol `ws4a-timing-1`** on the shared harness. Workloads from
`ledgr_sim_bars(500, 1260, seed = 20260530)` as the carrier probe used:
`wide` (SMA 5/10 transition, one unit, zero cost; availability on complete
facts, dense on the same bars), `nofill` (same bars, flat targets),
`sparse` (monthly rebalance into the top 20 by 63-session return, ties by
instrument ID in C-locale order, equal integer quantities, zero cost,
month-start decisions, no warmup trades), and reader cells on a completed
`wide` durable run. Ratio cells and bounds: exactly decision (4)'s matrix.

- Fills and trades reader cells record nonzero replayed rows and a fixed
  count of complete calls. Equity is a result-reader cell, not a replay
  witness.
- **Absolute cell.** One workload times matched `wide` and `nofill`
  sweeps in the same child process and returns its own named seconds
  clock: `(wide_total - nofill_total) / reps / fills_per_repetition`. The
  work string records reps, the actual fill counts, both outcomes and the
  materialisation policy; unequal fill denominators across repetitions are
  refused. As built (LDG-3163): the two totals are returned as extra named
  clocks, because the shared checker requires identical work strings per
  cell; the harness does not retain them, and keeping them would need a
  harness change. The fill denominator comes from a matched untimed durable
  run read through `ledgr_results`, because a sweep reports closed trades
  but not fills; a repetition whose fills, closed trades or final equity
  differ from that run is refused. The cell also carries a ratio bound of
  1.00, because the harness requires one for every cell; it cannot bind
  before the 40 us check.
- Reader cells use the availability producer's completed wide run (dense is
  frozen). Run and sweep cells repeat their own path once, untimed, before
  the timed reps, as ws2-timing-1 does; a full 8-pair window takes about
  three hours. The shared checker validates that cell's finite positive
  seconds and computes its candidate median.
  `dev/bench/v0_2_3_ws4a/timing_absolute.R` reads that median and requires
  `<= 40e-6`; it never subtracts medians of separate cells. It is shown to
  reject 45 us against a 240 us base, accept 30 us, and reject zero,
  negative and nonfinite measurements.

**Historical memory proposal, superseded by the maintainer settlement
below.** **Memory.** The previously proposed `ps` lifetime-peak subtraction is
withdrawn as a peak-live measure: `peak_pagefile` is a process-lifetime
high-water mark, so setup can dominate it, and private commit includes
allocator-retained storage. At the design-note review, memory-method
validation was unresolved and blocked cut acceptance. LDG-3163 must demonstrate phase isolation, covered
memory domains, collection policy and sensitivity before the decision (5)
budget is assigned to a metric. Its first candidate, to be validated, not
assumed: the measured operation runs in a fresh child that only loads ledgr
and reads prepared inputs from disk; the metric is that child's lifetime
`peak_pagefile` minus a matched load-only child's, valid only if the
load-only peak is shown to be below the operation's. Until validation
succeeds, `ps` private commit and the separately calculated GC maximum
(`sum(gc()[, "max used"] * c(56, 8))` after `gc(reset = TRUE)`) are
labelled observations only. If no validated method meets the claim, the
maintainer decides before acceptance, as decision (5) requires.
**Settled 2026-10-30 (maintainer):** the commit candidate failed
validation (range/median up to 0.15); the gated metric is peak R heap, the
GC maximum above, at most 1.10 x the matched base median, with process
commit reported as an observation. It passes validation on the base
(`dev/bench/v0_2_3_ws4a/records/memory/method.md`).

Both memory workloads use at least 5,000 instruments by 252 sessions; the
deep variant has at least 200 instruments consume 15 live lots in one fill.
Forward and replay are separate operations. The controlled excess is a
byte-sized, independently allocated and touched block, sized from base-only
calibration, allocated before and released after the measured growth or
replay, verified live at those points and verified to breach 1.10 x the
matched base under the validated method. A pointer alias or a copy too
small to breach is not a successful control. Five repetitions, their
aggregation, both producers' Rprofmem bytes per actual fill and the GC
formula are recorded.

**Real-data controls.** The private evidence record
(`E:/ledgr-data/reference/v0.2.3-base-953338df/EVIDENCE.md`) lists the
library and state paths, commit and adapter identities, the installation
command and the compare commands. LDG-3163 recorded an unchanged
w2_minvar rerun as IDENTICAL and the ledgr_cost_notional_bps_fee(1)
scratch mutant as DIFFERS; see dev/bench/v0_2_3_ws4a/records/realdata.md.

**Historical budget estimate at LDG-3162** (decision 12, estimated R lines): `workloads.R` 260,
`timing_absolute.R` 90, `record.R` 420, `check.R` 120, `guts.R` 280,
`memory.R` 230: about 1,400, under 1,500. Detector and validator tests are
package tests, outside this budget. Amended 2026-10-30 by the maintainer:
the full case set needed 962 lines, so decision (12) now allows 2,000
lines in total. Current maintained R totals 1,963 lines, including the base
detector script and protocol workloads, against decision (12)'s 2,000-line
limit; package tests remain outside that stated path budget. The earlier
1,400/1,500 figures are historical.

## 8. Checks per ticket (scope g)

Every ticket 3164-3168 also requires the full suite green.

| Ticket | Oracles | Cases | Detectors, validators, mutations | Timing and memory |
| --- | --- | --- | --- | --- |
| 3164 | A0, dense, real-data | C3, C4, C5a, C5b, C6, C9, C14a (S7a) | D3, D7, D11, D12a-c, D12e, D15, D17-D19, D23, D25; U-3164; V-state, V-book, V-lot-input, V-applied-row; M1, M3, M5, M6, M7, M11, M12; F4.35 opening caller cash-before/after witness | E5.09a: reader cells, replay memory (decision 6) |
| 3165 | A0, dense | C7, C10, C12, C14b (S7b), C15, C17 | D3, D4, D5, D12d, D13, D16, D21; U-3165; V-packet, V-decision; F4.19 adapter check; M8 | none |
| 3166 | A0, dense | C1, C2, C7, C8a, C8b, C11 | D1 (planners), D3, D8, D22, D24; U-3166; V-execution-view, V-plan, V-fill, V-rejection; M4, M9, M10 | none |
| 3167 | A0, dense | C13a-c, C14c | D1 (publication), D3, D6, D9, W1; U-3167; V-publication, V-leg; M2, M3 | none |
| 3168 | A0, dense | C16, C18 | D2, D10, F4.49 application counter; U-3168; V-diagnostics, V-equity, V-stop | none |
| 3169 | all, real-data | all | all, D20, W1 | E5.09b: full matrix; all memory workloads |

Before acceptance, LDG-3163 records each representation detector's expected
baseline outcome. A base failure of a detector that targets the old
representation is expected evidence, not a reason to weaken it.

detectors.R certifies base outcomes, not implementation completion. Each
owning ticket installs its applicable predicates and controls in
test-ws4a-carrier.R and requires production PASS for those regions. At
LDG-3164, D3 covers the kernel and migrated book consumers, and D25 covers
the typed lot operations, excluding the P4 scalar caller allowed until
LDG-3167 and replay while decision (6) permits singleton calls. Later
owners add their stage regions; production attachments may not remain
NOT_EVALUABLE at their owning ticket's close. Preserve the historical
baseline record.

## 9. Status

The design gate and LDG-3163 base preparation are complete, subject to the
prepared-cut review's corrections before acceptance. Their review chains
and results are recorded in tickets.yml. No semantic change beyond the
synthesis and the explicit maintainer settlements is authorized. The shape
and fault-timing changes listed below require acceptance with this cut;
other proposed weakening of fixtures, fault boundaries or oracles returns
through governance.

Shape changes that need the cut's acceptance as their stated reason: the
inverted unnamed-positions witness (LTB-0278); the publication call-count
claims (LTB-0515, LTB-0136, test-risk-fold.R:83); LTB-0280's added two-pulse
witness and changed fault timing; the post-risk class test
(test-risk-fold.R:827); the retired proposal shapes and `ledgr_fill_none`
(test-fill-model.R:59, :96, test-ledger-writer.R:811); LTB-0521's retired
equity-buffer growth; and the mode-branch census regeneration (LTB-0331).
