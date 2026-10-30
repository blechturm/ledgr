# WS4a Carrier Design Note (LDG-3162)

- Status: draft for its independent design review; LDG-3162 is complete only
  when that review passes.
- Author: Claude, 2026-10-30.
- Base: `release/v0.2.3`; `R/` and `src/` identical to `953338df`.
- Authority: the accepted synthesis
  (`../rfc/rfc_typed_fold_carrier_v0_2_3_synthesis.md`, "Synthesis") binds
  the design; cut 5 in `tickets.yml` binds order, oracles and gates. This
  note applies them and adds no design. Where it pins something the
  synthesis left to the cut (Synthesis Section 7: code assignments,
  locators, pulse capacity, detector names), it says so.
- Inputs: four read-only censuses of the base, run 2026-10-30: carrier
  fields, vocabularies, test blocks and existing coverage. Their findings
  are cited by file and line below. Abbreviations: `fe` = `R/fold-engine.R`,
  `ae` = `R/availability-economics.R`, `oh` = `R/output-handler.R`,
  `la` = `R/lot-accounting.R`, `csf` = `R/compiled-spot-fifo.R`,
  `br` = `R/backtest-runner.R`, `lw` = `R/ledger-writer.R`,
  `adw` = `R/availability-diagnostic-writer.R`, `fpc` =
  `R/fold-phase-contract.R`, `rf` = `R/run-finalize.R`.

## 1. Consumer map (scope a)

One row per carrier group of Synthesis Section 4: who produces it today,
who consumes it, and which ticket changes it. Name-based instrument reads
are marked "by name".

| Group | Producers today | Consumers today | Ticket |
| --- | --- | --- | --- |
| state: `cash` | E fe:1741; P1 install fe:244-249 (fe:365, :399, :487); P4 fe:1400 (compiled fe:1328) | P1 equity fe:578, :589; P2 ctx fe:763-764; P3 planner fe:1093, recon fe:1140-1166; P4 fe:1298; P5 fe:1446-1469; skip plan fe:675; E return fe:2091 | 3164 (type unchanged; validator) |
| state: `positions` | E fe:1593-1597 (by name, fe:43-49); P1 install; P4 fe:1389, fe:1324 | P1 fe:298-301, :557-570, :606; P2 fast ctx fe:786; P3 fe:1066; P4 fe:1307-1308; P5 fe:1459; E fe:1895; to:136-142, cas:634-639, cas:465 (by name) | 3164 |
| state: `lot_state` | E fe:1594-1595; P1 install; P4 fe:1329, :1357 | P1 fe:580-590; P4 fe:1350, :1374, :1390; compiled pack csf:203-242 (by name, la:30, :120) | 3164 |
| state: `state_prev`, `state_axis`, `event_seq`, `status`, `stop_reason`, `affected_exposure`, `processed`, `full_run`, `last_fully_valued`, `last_executed`, `frozen_set`, `current_stage`, `current_ts`, `diagnostic_seq`, `telemetry_idx` | as Phase 5.1 | as Phase 5.1 | unchanged; validated by 3164 (E/stop) |
| state: `pending_segments` | P1 fe:293-296; P2 fe:702-705; P5 fe:1484-1491; E fe:1758-1761 | flush fe:256-268 into `ledgr_availability_diagnostic_block` | 3168 |
| state: `equity_facts` (new) | today the accumulator fpc:164-190 (availability only) and `record_equity_fact` fe:584-592 (both producers) | finalisation rf:449-458, :511-524; prefix commit br:1076-1086; inline summary oh:313-351 | 3168 |
| book (lot state) consumers outside the fold | replay accounting-replay.R:274-332; chunked fills reader backtest-fills.R:121-166; opening/resume br:643-671, sweep.R:1771-1819; result replay br:1241-1252; walk-forward walk-forward.R:1202-1203, :1281-1290; dispositions terminal-outcomes.R:149-198; recovery rf:164-195; handler fact oh:787-816; compiled csf:104-165, :167-247 | same | 3164 |
| decision packet | P1 return fe:609-629; provider decision view availability-provider-prepared.R:530-542 plus fe:309-313 | P2 fe:695-1044 (context ids by name throughout); P3 fe:1054-1094; P5 fe:1419-1515 | 3165 |
| decision data | P2 bar frame from `history_bars$current` fe:709-712; projection views | P2 ctx construction only | 3165 (packet split; ctx unchanged) |
| execution packet | `history_bars$next_bar` fe:282 (history-substrate.R:394-413) | P3 fe:1094 then ae:469, :479-482 | 3165 (produced), 3166 (consumed) |
| execution view | provider `execution_view` ae:417-420 | ae:460-468 (by name) | 3166 |
| decision | P2 fe:1035-1043; skip fe:655-664 | P3 fe:1057-1065 (`id_to_idx[target_names]` by name); P5 fe:1423-1476 | 3165 |
| plan, fill, rejection | dense fe:128-198; availability ae:391-529; skip fe:668-686; affordability ae:344-389 | P3 segments fe:1171-1271; P4 fe:1293-1399; P5 fe:1434-1468; compiled csf:167-247 | 3166 |
| lot input, applied row | P4 per-fill call fe:1349-1357; replay accounting-replay.R:296-328 | handler fact oh:787-816; replay outputs | 3164 (implementation), 3167 (P4 block) |
| publication | payload br:103-187; live lw:18-157; staging oh:532-602; leg staging oh:196-283; compiled oh:738-785 | flush oh:575-602; durable oh:672-695; memory materialisation oh:837-865 | 3166 (input), 3167 (block, staging) |
| leg | oh:787-816 (CLOSE then OPEN, oh:809-814); compiled src/spot_fifo.cpp:302, :313 | inline summary oh:313-351 | 3167 |
| diagnostics | 15 segment producers (Section 2.4); block adw:44-92; writer adw:94-171 | handler oh:631-654 (renumbers `diagnostic_seq`); memory filter oh:362-378 | 3168 |
| stop | fe:337-344 (P1), fe:975-982 (P2), fe:1162-1169 (P3) | E fe:1918-1930, :1959-1971, :1986-1998 | 3168 |
| timing, telemetry | stage locals; P5 fe:1535-1551 | E fe:2083-2084 | unchanged |

**Transitional adapters,** each named in code with its remover:
`ledgr_carrier_provider_view()` (P1 provider and valuation outputs to the
packet; removed by WS4b); `ledgr_carrier_settlement_state()` (the
corporate-action plan's `post`/`post_disposition` state in and out; WS4b or
WS8); `ledgr_carrier_compiled_pack()` / `_unpack()` (compiled-envelope RFC).
Permanent boundary helpers: E import (`ledgr_carrier_import_state()`), P2
input and return, publication, results.

**Not carried** (dead today, census): `pulse_plan$targets` and
`$actionable_idx` (no reader), `fill$ts_signal_utc` (no reader), `entry$cur_qty`
(dead local fe:1347). The stop result's `affected_instrument_ids` and the
Phase 5.5 fold return (`state`, `state_prev`, `next_event_seq`, read by no
caller) stay as bound; this note does not change bound returns.

## 2. Pins (scope b)

### 2.1 Reasons

- **P3 fill and rejection rows** carry reasons as a flat segment:
  `reason_offset`, `reason_count`, `reason_code_list` (integer codes, in
  the order `ledgr_availability_reason_values()` produces today: blocking
  tokens, then informational, `unique()` keeping the first occurrence,
  ae:334-342, :438-454). The row's primary `reason_code` is a **separate
  integer column**, set where it is set today (`reasons[[1L]]` for
  rejections, ae:452, :381; first informational value or `""` for fills,
  fe:1231-1233). The text `reasons` is built only when the diagnostic row
  is staged, by `paste(dictionary[codes], collapse = "|")`.
- **Every other diagnostic producer** (decision trace, terminal, stop,
  skip, reconciliation; vocabulary census item 1) keeps writing its
  `reason_code` and `reasons` strings directly into the staging block, once
  per segment as today. Two producers break "primary = first token": the
  lifetime terminal stop (fe:443-453) and the decision trace with
  `sizing_unavailable` (fe:907-914). They are not re-encoded.
- **Static dictionary** (P3 reason codes, ordered as first defined):
  `final_pulse_no_execution`, `execution_bar_missing`, `insufficient_cash`,
  `membership_changed_before_execution`, `trading_halted`,
  `quotation_only`, `status_unknown`, `status_unknown_or_conflicting`,
  `lifetime_inactive`. Code 0 is `""`. A token outside the dictionary
  aborts with `ledgr_invalid_pulse_plan`.
- **Open vocabularies** (terminal-event labels, exception `$reason`,
  instrument IDs) are never coded at compile time. Where carried, they use
  a per-run dictionary in first-seen order, as
  `ledgr_history_segment_dictionary()` does (history-substrate.R:468-505).

### 2.2 Other codes

- **Mark source** (packet `mark_source`): 1 `missing`, 2 `expired_close`,
  3 `current_close`, 4 `stale_close`, 5 `frozen_close`, 0 `""`
  (ae:117-126). `write_off` occurs only on disposition meta
  (terminal-outcomes.R:113-114), which is not a packet field.
- **Provider status and lifetime**: the provider's own level vectors
  (availability-provider-prepared.R:373-377, :398-407), carried as integer
  codes into those levels; `terminal_event` uses the provider's per-run
  `terminal_levels`.
- **Economic event kinds** (plan): 1 `FILL`, 2 `CASHFLOW`, 3
  `DISPOSITION`. The canonical-supported set stays `FILL, CASHFLOW`
  (fe:1120); compiled stays `FILL` (csf:93); empty plans declare none.
- **Side**: +1 `BUY`, -1 `SELL` inside the carrier; tokens at publication.
  **Leg action**: CLOSE before OPEN (oh:809-814).
- **Condition classes survive.** The column validators raise the classes
  the removed object validators raised: `ledgr_invalid_fill_intent`,
  `ledgr_invalid_pulse_plan`, `ledgr_invalid_lot_fill`,
  `ledgr_lot_state_invariant`, `ledgr_invalid_post_risk_targets`
  (documented in `R/condition-reference.R` and checked by
  test-codebase-contracts.R:44, LTB-0271).

### 2.3 Locators

- `bar_row` is the valuation's `source_row` (run positions, ae:144) and
  `source_column` the history reader's `pulse_columns[pulse_idx]`
  (history-substrate.R:394-413). A row alone is not a time boundary.
- Feature access stays the existing cutoff-bound `history_view`
  (fe:288-292) and projection views, P2-local and unchanged.
- The execution packet holds `exec_ts`, `has_next` and next-bar OHLCV on
  the run axis from `history_bars$next_bar`, including the continuation
  column beyond the last pulse (history-substrate.R:400-412).

### 2.4 Pulse diagnostic capacity

From the vocabulary census item 6 (`N` = run-axis size): a due pulse adds
at most `H + F + max(C, 1) + 2C + 2` rows and every other pulse less, with
`C, H <= N` and `F <= N`, except two stop producers bounded by `N`
(corporate-action refusal) and by `Q_pulse` (blocked scheduled dispositions,
not deduplicated). **Pinned:** the staging block is allocated once in E with
`capacity = max(5 * N + 3, max(Q_pulse))`, where `Q_pulse` comes from the
corporate-action plan's due rows per pulse. It is reset, never grown, after
each drain. A staged row beyond capacity aborts with
`ledgr_invalid_fold_execution` (a bug, not a data condition). The fold's
`diagnostic_seq` remains a row counter; the handler renumbers rows at write
(oh:631-654), unchanged.

### 2.5 Cash-effect reuse

`ledgr_fill_publication_deltas()` (lw:8-16) and
`ledgr_availability_fill_cash_delta()` (ae:326-332) evaluate the same
expressions in the same order, so P3 computes `cash_delta` and
`position_delta` once and every later reader reuses them. The two
reconciliation sums (fe:1140-1144, fe:1463-1467) stay `sum()` over the
reused vector in fill order. LDG-3166 adds a test that the reused values
are `identical()` to both formulas on the case set.

## 3. Obligation register (scope c)

Each indivisible obligation has one owner. "Control" is the deliberate
violation that must fail its check. Case IDs `C1`-`C17` are the new cases
of Section 4; `D` and `M` are the detectors and mutations of Section 6.
"Oracles" means A0 successor, dense oracle and (where the ticket says so)
the real-data reference.

| ID | Obligation (Synthesis section) | Owner | Check | Control |
| --- | --- | --- | --- | --- |
| R2.1 | Economics, event order, `meta_json`, equity, state and retained diagnostics byte-identical (2) | 3169 (each ticket checks per decision 8) | oracles, C1-C17 | any gut of Section 4 |
| R2.2 | Lots alone determine positions (2) | 3164 | D11 | M5 (positions + delta) |
| R2.3 | No schema, public API, execution-mode branch or compiled default change (2) | 3169 | D12 (store bindings, export census, mode-branch census) | add an export |
| R2.4 | Q1: dense joins at the normalized decision; observation frozen (2, 4 note) | 3165 | D13 (dense observe/ctx functions unchanged) | edit a dense view builder |
| R2.5 | Q6: one equity record for both representations (2) | 3168 | C16, D10 | restore the accumulator |
| R3.1a | Run axis; context axis in provider order with held nonmembers; `context_pos` (3.1) | 3165 | C15, v201 witness | M8 (wrong `context_pos`) |
| R3.1b | Fill and rejection rows carry `k` and `pos = context_pos[k]` (3.1) | 3166 | C15 | M8 |
| R3.1c | Fold slots: retyped positions and book (3.1) | 3164 | D14 (validator) | wrong-length book column |
| R3.1d | Fold slots: typed staging and `equity_facts`, accumulator removed (3.1) | 3168 | D14 | wrong-type equity column |
| R3.1e | Each group validated at construction; E/stop validator extended by its owner (3.1) | per group (3164-3168) | D14 | per group |
| R3.1f | Named adapters only; no ad hoc name lookup in a positional kernel (3.1) | 3164 (book, compiled, settlement), 3165 (packet, P2), 3166 (execution view), 3167 (publication) | D3 | name lookup in kernel |
| R3.1g | Ownership: exclusive buffers; copies at hand-out; candidates and workers isolated (3.1) | 3164 (book), 3165 (views), 3167 (publication) | C14, A0 `sweep_w2` | by-reference write to a handed-out book |
| R3.1h | Copy-on-modify kernel (3.1, decision 7) | 3164 | D15 (no `setv` on book columns) | `setv` on `lot_qty` |
| R3.2a | P1 order of settlement, disposition, lifetime, re-observation, valuation, equity (3.2) | 3165 | C12, A0 `avail_*` | swap disposition and valuation |
| R3.2b | Provider and valuation converted once per produced view (3.2) | 3165 | D16 (adapter call count = views) | convert per column |
| R3.2c | Run-order valuation reductions (3.2) | 3165 | oracles (equity bytes) | sum in context order |
| R3.2d | Decision packet and private execution packet; P2 gets no next bars (3.2) | 3165 | D5 | pass `next_bar` to P2 |
| R3.2e | Lazy history cutoff-bound and P2-local; no flat ctx or frame retirement (3.2) | 3165 | D13 | read history in P3 |
| R3.2f | Strategy return normalized once; risk on columns; compiled risk plan validated once in E; dynamic checks kept (3.2) | 3165 | D4, test-risk-fold.R:827 migration | second normalization |
| R3.2g | Raw state update unnormalized to P5; intent placement unchanged (3.2) | 3165 | oracles (`strategy_state`) | normalize in P2 |
| R3.2h | Scheduled skip: no strategy call (3.2) | 3165 | C7 | call strategy on skip |
| R3.2i | Scheduled skip: no planning, still settle, value, bind and commit (3.2) | 3166 | C7 | plan on skip |
| R3.3a | One candidate row per actionable context ordinal (3.3) | 3166 | C11 | duplicate a row |
| R3.3b | Cost steps vectorized in order; unrounded notional; last rounding (3.3) | 3166 | C1, C2 | M9 (notional from rounded price), M10 (drop notional) |
| R3.3c | Effects computed once; no sink recomputes (3.3) | 3166 | D8, Section 2.5 test | recompute in payload |
| R3.3d | Execution epochs validated once from the prepared axis; no per-fill parse (3.3) | 3166 | D1 | per-fill `as.POSIXct` |
| R3.3e | Affordability scan order; private mask and permutation; decision-order publication; early then affordability rejections (3.3) | 3166 | C11 | M4 |
| R3.3f | Reconciliation calculations and tolerance unchanged, including `sum()` (3.3) | 3166 | C8, oracles | ordered scan in place of `sum()` |
| R3.3g | Planned after-position is diagnostic only (3.3) | 3166 | C4, C11 (planned and actual compared separately) | use planned as authority |
| R3.3h | Reasons as ordered code segments; dictionaries keep tokens (3.3, 2.1 here) | 3166 | oracles (diagnostics), C11 | bit mask |
| R3.3i | Empty plans declare no kinds; unsupported kinds refuse before mutation (3.3) | 3166 | LTB-0026 migration | declare FILL on empty |
| R3.4a | Flat segments; FIFO sequential within an instrument, vectorized across (3.4) | 3164 | C3, C4, C5 | M1 (LIFO), M7 (skip partial remainder) |
| R3.4b | Ordered total-basis and Kahan updates in scalar event order (3.4) | 3164 | C5, C9 | M11 (`cumsum` totals) |
| R3.4c | Opening: signed quantity, any-sign basis, no cash or Kahan (3.4) | 3164 | C5, D7 | M6 |
| R3.4d | Fill: dust, fees, reversal arithmetic (3.4) | 3164 | C3, C4 | M3 (drop fee) |
| R3.4e | Disposition: zero fee, zero price allowed, exhaustive, replay witness at dust tolerance (3.4) | 3164 | C6, A0 `avail_terminal_resume` | leave a live lot |
| R3.4f | Cash outside the kernel; replay adds published effects once (3.4) | 3164 | D17 | add cash in kernel |
| R3.4g | Distinct instruments per call; conflict-free consecutive blocks; carried openings successive (3.4) | 3164 | C5, D18 | reorder a block |
| R3.4h | Dispositions keep their barriers and duplicate refusal (3.4) | 3164 | test-terminal-outcomes.R, A0 | merge two disposition rows |
| R3.4i | Old FIFO deleted; replay and opening/resume use the typed operations; metadata preparation kept (3.4) | 3164 | D19 (no named-list FIFO symbol in R/) | keep `ledgr_lot_apply_fill` |
| R3.4j | Singleton replay only if the replay gate passes (3.4, decision 6) | 3164 | ws4a-timing-1 reader cells, replay memory | n/a (gate) |
| R3.4k | Compiled pack and unpack by gather; aggregates and Kahan exact; C++ unchanged (3.4) | 3164 | C9 | M12 (drop `realized_comp` in unpack) |
| R3.5a | Bind next corporate-action boundary before fills (3.5) | 3167 | A0 `dense_dividend_state`, C12 | bind after fills |
| R3.5b | Candidate block computed without mutation; failure leaves state and buffers unchanged (3.5) | 3167 | C13 | mutate before success |
| R3.5c | Install order: book, publish, sequence, legs, positions and cash (3.5) | 3167 | C13, LTB-0137/0280 migrations | publish before install |
| R3.5d | Append/flush failure aborts; durable rollback; no memory partial; classes, stage, checkpoint and interrupt preserved; compiled state-before-append (3.5) | 3167 | C13, LTB-0280 migration | swallow an append error |
| R3.5e | Fills published as columns; event IDs per block (3.5) | 3167 | D1, D9 | per-fill list |
| R3.5f | P1 non-fill builders keep order; adapt once into the indexed buffer (3.5) | 3167 | A0 `dense_dividend_state`, `avail_acquisition` | defer non-fill rows to P5 |
| R3.5g | `meta_json`, memory `meta`, auxiliaries and leg-fee arithmetic unchanged (3.5) | 3167 | oracles, D9 | drop the meta list |
| R3.5h | No Accounting DDL, validator, fallback deletion or reader change (3.5) | 3167 | D12, scope diff | add a column |
| R3.6a | Pulse staging in emission order; reset after P5/E; pinned capacity; no strategy replay (3.6) | 3168 | D2, C17 | grow staging |
| R3.6b | Existing writer splits chunks; no run-long staging, no second writer (3.6) | 3168 | D2, v201 `chunk_rows = 7` witness | retain staging across pulses |
| R3.6c | Full logical trace; memory filter and sequence gaps unchanged (3.6) | 3168 | A0 `memory_diagnostics` | filter in the fold |
| R3.6d | Equity record per valued pulse; used-row count; frozen prefix to finalisation and inline summary; no memory replay; two clocks (3.6) | 3168 | A0 `avail_incomplete`, C16 | replay equity for memory |
| R3.6e | Finalisation selects equity by producer (3.6, P1 patch) | 3168 | C16 | key on record length |
| R3.6f | P5 order: flush, reconciliation, state, progress, telemetry, checkpoint (3.6) | 3168 | oracles | swap state and flush |
| R3.6g | E alone installs stops; counted pulses; stop class and exposure kept; stop diagnostics staged (3.6) | 3168 | A0 `avail_incomplete`, C8 | install stop in P2 |
| R3.6h | Telemetry arrays unchanged (3.6) | 3168 | existing telemetry tests | n/a |
| R4.1 | Producer scope line (4) | 3165 | D13 | dense emits packet |
| R4.2 | Epoch doubles inside the carrier; POSIXct at boundaries (4) | 3165 (packet), 3166 (plan), 3167 (publication) | D1 | POSIXct column |
| R4.3 | Dictionaries and locators pinned without semantic change (4, 7) | 3162 (this note) | oracles | renumber a token |
| R5.1 | Section 5 evidence table, each row | 3163 records, owners above check | Section 4 | Section 4 |
| R5.2 | P2 next-bar detector (5, P3 patch) | 3165 | D5 | as D5 |
| R5.3 | Dense durable finalisation through event replay (5, P1 patch) | 3168 | C16 | as C16 |
| R8.x | Section 8 routes stay with WS4b, WS5, WS6, WS7, WS8 and the compiled RFC; no D2 slots; cold stop and exception records keep their encoding; JSON cache untouched | 3169 | D12, D20 (scope diff over the routed files and symbols) | implement a routed item |
| R9.1-R9.7 | Section 9 scenarios | S1 3165 (C15); S2 3166 (C11); S3 3165 (C12); S4 3164 (C5); S5 3167 (C13); S6 3168 (C17); S7 3164 (C14) | named cases | as cases |
| RCR | Independent cold read of every changed stage from code and Section 4 of the synthesis | 3169 | workstream 13 close review | n/a |

## 4. New cases for LDG-3163 (scope c)

Each is recorded on the base by `dev/bench/v0_2_3_ws4a/record.R`, checked
exactly by `check.R` (lossless RDS plus `%.17g` CSV, the A0 serialization)
and has at least one gut in `guts.R` that must fail. Coverage gaps come
from the coverage census.

| Case | Workload | Frozen outputs | Gut that must fail |
| --- | --- | --- | --- |
| C1 | Dense durable run and availability sweep with spread 7 bps, fixed 1.25 and notional 3 bps; BUY, SELL and a reversal that splits the fee | ledger with `meta_json`, fills, trades, legs, equity | drop the notional step |
| C2 | Prices whose spread-adjusted value has more than 8 decimals, including a near-half tie at digit 9, both sides | fills, ledger | notional from the rounded price |
| C3 | Fractional fills reaching `ledgr_lot_dust_tolerance` in fold and replay, with fees | ledger, equity, logical FIFO book | tolerance x10 |
| C4 | Dense long to short to long with chained costs | ledger, CLOSE/OPEN legs, trades, equity; planned and actual positions | LIFO consumption |
| C5 | Walk-forward carry of several fractional-basis lots per instrument across two boundaries, then partly consumed; nonzero `realized_comp` before the carried openings | opening `meta_json`, replayed book, `realized_comp` | Kahan step on openings |
| C6 | Disposition of a multi-lot fractional holding | ledger, book after replay | leave one live lot |
| C7 | Scheduled skips with stale marks and fills on due pulses | diagnostics including skip rows, fills, equity | plan on a skip pulse |
| C8 | Affordability reconciliation stop, forced by perturbing `expected_final_cash` by +1 at the P3/P4 seam | completion, diagnostics, INCOMPLETE prefix | none (the stop itself is the witness) |
| C9 | Compiled sweep with fractional quantities and nonzero `realized_comp` over at least two pack/unpack cycles | lot state, events, summaries | drop `realized_comp` in unpack |
| C10 | Availability run with empty context on some pulses | settlement, valuation, equity, diagnostics | skip valuation on empty context |
| C11 | Cash-bound pulse where a buy precedes its funding sell in decision order and decision order differs from stable-ID order | ledger order, reconciliation and rejection rows | publish in affordability order |
| C12 | Disposition cash funding a later fill | ledger, equity | fill before settlement |
| C13 | Candidate-calculation failure on the second row (dense and availability) and append failure, durable and memory | state, buffers and outputs unchanged; FAILED status | mutate before success |
| C14 | Retained `ctx$vec` vectors, `state_prev`, an availability context and compiled batch inputs, compared after later pulses | retained values | write the book by reference |
| C15 | v201 availability witness with a `context_pos` mutation | existing exact outputs | wrong `context_pos` mapping |
| C16 | Dense durable run whose finalisation route is traced (replay must run; prefix commit must not) | route trace and equity | key the route on record length |
| C17 | Continued final-window execution (carry chain) with fees and fractional quantities, plus a standalone-window control | ledger, diagnostics | drop the continuation opportunity |

C8, C13 and C16 inject or trace at seams that exist in both the base and
the typed representation (the P3/P4 plan boundary, the handler's append
method, the finalisation entry), named in `guts.R` so the same injection
runs before and after. Real-data controls (scope e of LDG-3163) are in
Section 7.

## 5. Test-migration list (scope d, decision 10)

Every registered or unregistered test that changes. "Change" is the
representation change the synthesis authorises; "keeps" is the semantic
assertion that survives; each replacement must fail on the stated
violation. Categories: 1 construct typed containers; 2 compare the same
logical FIFO witness; 3 source predicate restated on columns; 4 economic
assertion moves to the typed implementation with the same inputs and
values; 5 shape change with a stated reason.

| Test (block) | Claim | Cat | Change | Keeps | Fails on |
| --- | --- | --- | --- | --- | --- |
| helper-fixtures.R:130 `ledgr_test_next_open_fill` | - | 1 | builds a one-row typed fill batch through the batch resolver | same fill values | wrong price |
| test-accounting-core-consolidation.R:31 | LTB-0019 | 2 | typed book and operations | the four literal values and the dust bound | M1 |
| test-accounting-core-consolidation.R:211 | LTB-0022 | 5 | kernel and its rescan mutant rebuilt on the typed book; reason: the measured object moved | same slope thresholds (<=0.30 production, >0.30 mutant) | the rescan mutant |
| test-lot-accounting.R:1 | - | 4 | typed fill operation | `ledgr_invalid_lot_fill` on the four inputs | accept qty 0 |
| test-lot-accounting.R:22 | - | 2 | typed book | zero lots and zero basis | tolerance /10 |
| test-cross-asset-corrections.R:88 | LTB-0497 | 2 | `net_by_inst` and live-lot count read from the typed book | position 0, held flags | tolerance /10 |
| test-cross-asset-corrections.R:240 | LTB-0498 | 2+3 | R side uses the typed implementation; compiled call takes columns; source predicates name the typed position read and unpack gather | R and C++ identical on every asserted field | M12 |
| test-execution-spec.R:1 helper `ledgr_expect_lot_states_equivalent` | - | 2 | compares logical live lots and aggregates | same fields | drop `realized_comp` |
| test-execution-spec.R:115, :239 helpers | - | 1 | typed spec state | same economics | - |
| test-execution-spec.R:523 | LTB-0026 | 3+5 | mock the typed plan builder; kinds become codes; source predicates name the block application; reason: the pulse-plan object is retired | refusal classes `ledgr_invalid_pulse_plan` and compiled-unavailable | declare FILL on empty |
| test-execution-spec.R:576 | LTB-0006 | 1+2 | dust seed book built typed | every parity assertion | M12 |
| test-execution-spec.R:749 | LTB-0013 | 2 | typed state | every parity assertion | M12 |
| test-fold-phase-contract.R:3 | LTB-0278 | 1+5 | typed constructor; equity record replaces the accumulator; **the unnamed-positions refusal inverts**, reason: positions become an unnamed run-axis vector (Synthesis 3.1); the replacement refuses a wrong-length positions vector | closed slot set; no data-frame slot | wrong length accepted |
| test-fold-phase-contract.R:85 | LTB-0279 | 3 | `tools/check-fold-phase-contract.R` owner table and method patterns updated for the new slots and methods | one owner per slot | second writer of a slot |
| test-risk-fold.R:83 | - | 5 | "all costs resolved before any publication" asserted per block; reason: per-fill writes become one block | costs before emission | publish before resolve |
| test-risk-fold.R:122 | LTB-0281 | 3 | frozen name sets for the typed groups | stage packet order, no data frames | extra field |
| test-risk-fold.R:192 | LTB-0136 | 5 | write count per block; reason as above | flushes == 3 | extra flush |
| test-risk-fold.R:255 | LTB-0137 | 5 | injection moves to the second row of the candidate calculation; reason: `ledgr_lot_apply_fill` is deleted | FAILED, zero rows, sibling identical | partial publish |
| test-risk-fold.R:345 | LTB-0280 | 5 | injection on the block append method, plus a fixture with fills on two pulses; reason: one call per pulse | atomicity on durable and memory | swallow append error |
| test-risk-fold.R:515 | - | 4+5 | post-risk quantity reaches the batch resolver; resolver call protocol is per batch | qty 10 at cost | pre-risk qty |
| test-risk-fold.R:827 | - | 5 | retargeted to the surviving post-risk property check, which keeps class `ledgr_invalid_post_risk_targets` with parent `ledgr_invalid_strategy_result`; reason: the duplicate shape/name normalization is deleted (Synthesis 3.2) | class and parent | wrong parent |
| test-corporate-action-disposition.R:53 helper | - | 1 | typed state | same values | - |
| test-corporate-action-disposition.R:108 | LTB-0050 | 1+2 | typed state and book | position 0, no lots, realized -20 | leave a lot |
| test-corporate-action-disposition.R:177 | LTB-0051 | 1 | no-mutation witness compares the typed carrier | cash 1180/1160/1170 | mutate on refuse |
| test-sweep.R:46, :91, :146 | - | 1 | one-row typed fill block into the handler | typed events equal ledger rows; growth; summary | wrong column |
| test-sweep.R:220 | - | 1+4 | typed opening, fill operation and block publication | inline equals reconstructed; legs 2/1 | drop OPEN leg |
| test-ledger-writer.R:58, :103, :442, :753, :781, :829, :855 | - | 1 | one-row typed fill input | each block's asserted rows, deltas and refusals | wrong delta |
| test-ledger-writer.R:220 | LTB-0135 | 1 | one two-row block | hidden until flush, order | reorder |
| test-ledger-writer.R:302 | LTB-0188 | 3 | predicates name indexed column writes; allocation probe on a block write | no per-write copy | copy column per write |
| test-ledger-writer.R:811 | - | 5 | zero-row block is the no-op; reason: `ledgr_fill_none` is retired | NO_OP status and no rows | write a row |
| test-ledger-writer.R:880 | LTB-0515 | 5 | deltas computed once in P3; per-path call count becomes "one computation per fill, zero in sinks"; reason: Synthesis 3.3 | direct delta oracle values (lines 918-925) | recompute in a sink |
| test-ledger-writer.R:1031 | LTB-0516 | 1+5 | db_live validation on column input | `ledgr_invalid_fill_intent` on bad side and fee; transaction sequence | accept bad fee |
| test-ledger-writer.R:1115 | LTB-0518 | 3 | frozen method sets updated for the renamed block methods | shared mechanisms | duplicate mechanism |
| test-ledger-writer.R:1166 | LTB-0521 | 1 | equity part fed from the equity record | identical frames | drop a row |
| test-fill-model.R:1, :118, :158, :197 | - | 4 | batch resolver, one row | rounding, symmetry, fee, invalid-input refusals | wrong rounding |
| test-fill-model.R:27 | - | 5 | epochs inside the carrier, POSIXct at the boundary; reason: Synthesis 4 | boundary output is POSIXct UTC | POSIXct inside |
| test-fill-model.R:46 | - | 4 | refusal at epoch validation | `LEDGR_SUBSECOND_TIMESTAMP` | accept sub-second |
| test-fill-model.R:59, :96 | - | 5 | retired with the proposal object; their value-level claims move to C1/C2 and the :1 block; reason: proposal and fill-context objects are retired (Synthesis 3.3) | equal fill values | wrong value |
| test-fill-model.R:184 | LTB-0002 | 4 | `has_next = FALSE` path | NO_FILL with `LEDGR_LAST_BAR_NO_FILL` warning | no warning |
| test-cost-model.R:229 | - | 4 | batch resolver | notional on unrounded spread price | M9 |
| test-derived-state.R:61 | - | 1 | ledger built from typed blocks | deterministic reconstruction | - |
| test-release-coverage-branches.R:110 | - | 1+5 | branch tests on the column payload builder | refusal class and deltas -21/2, 19/-2 | wrong delta |
| test-runner.R:252 | - | 5 | spy on the column writer signature | state written after fills | write state first |
| test-availability-diagnostic-production.R:15 helper, :32, :46, :95 | - | 1 | typed staging block instead of `segments = list(list(...))` | default block, chunk split, survive append failure | lose a row at a split |
| test-availability-economics.R:303, :379 | - | 4 | typed affordability scan | accepted order, final cash, reasons | M4 |
| test-availability-parity.R:915 | LTB-0024 | 2 | basis from the typed book | equals the second opening's basis | wrong basis |
| test-strategy-schedule.R:1233 | LTB-0507 | 2 | logical FIFO witness instead of container identity | economics and resume | M1 |
| test-terminal-outcomes.R:651 | LTB-0171 | 2 | live-lot count from the typed book | one live lot | commit before failure |
| test-codebase-contracts.R:114 | LTB-0331 | 5 | mode-branch census regenerated; reason: stage bodies rewritten; every remaining branch row keeps its owner | no new mode branch | add a branch |
| test-codebase-contracts.R:20, :44 | LTB-0270, LTB-0271 | - | no change expected: deleted helpers lose their callers together; condition classes survive (Section 2.2) | as today | orphan helper |

Claim prose that names removed constructs is updated in `tests/claims.yml`
with the same reason: LCL-0022 (`pulse_plan`), LCL-0135 ("fill intents"),
LCL-0279 ("short-lived list shape"). Watch-list blocks (census) change only
if a boundary adapter loses names; they are not planned changes.

## 6. Detectors and mutations (scope e)

Detectors live in `tests/testthat/test-ws4a-carrier.R` (parse-tree or
runtime predicates on named functions). Mutations are applied by
`dev/bench/v0_2_3_ws4a/guts.R` to an archived copy and must fail identity.

| ID | Predicate | Where | Violation that must fail it |
| --- | --- | --- | --- |
| D1 | No list, S3 object or POSIXct conversion created per fill in the planners, P3, P4 or publication | parse tree of the named functions | `vector("list", n_fill)` or `as.POSIXct` inside the fill loop |
| D2 | Diagnostic staging is one pre-allocated typed block per pulse, reset at drain; the writer and the memory sink's retained chunks are allowed | runtime: staging length constant across pulses; parse tree: no `[[length + 1]] <-` on staging | list-segment staging; staging retained across pulses |
| D3 | No character indexing on a run- or context-axis vector inside the lot kernel and migrated book consumers | parse tree | `net_by_inst[[id]]` |
| D4 | The strategy return is shape/name normalized once per pulse | runtime counter on the normalizer | a second call |
| D5 | P2's input carries no execution-packet field | runtime check plus a mutation passing one | `next_bar` reaches P2 |
| D6 | No JSON encode or parse inside the pulse loop beyond the routed sites (fill and non-fill `meta_json`, H5 reconciliation detail, intent reason, stop and exception detail) | parse-tree allowlist | a new `canonical_json` call in P3 |
| D7 | No Kahan step on opening rows; nonzero compensation preserved across openings | runtime counter plus C5 | M6 |
| D8 | No fill-intent object constructed in the fold or sinks; effects computed once | parse tree plus counter on `ledgr_fill_publication_deltas` | reconstruction or a second computation |
| D9 | No per-fill economic staging list in publication; the routed memory `meta` list is allowed | parse tree | a staged per-fill list |
| D10 | Finalisation route selected by producer | runtime trace (C16) | key on record length |
| D11 | Positions read only from `net_by_inst` | parse tree | `positions + delta` |
| D12 | Store-format bindings, export list and condition classes unchanged | existing contract tests | a binding change |
| D13 | Dense observe/ctx builders unchanged; dense emits from the decision on | source hash of the named dense functions | edit a dense view builder |
| D14 | Each group's validator refuses wrong length, type, bound or dictionary code | unit tests per group | accept a wrong-length column |
| D15 | No by-reference write on book columns | parse tree | `collapse::setv(book$lot_qty, ...)` |
| D16 | Provider adapter called once per produced view | runtime counter | per-column conversion |
| D17 | Lot kernel computes no cash | parse tree | cash inside the kernel |
| D18 | A kernel call refuses duplicate instruments | unit test | accept duplicates |
| D19 | No named-list FIFO symbol remains in `R/` | parse census of function definitions in `R/` | `ledgr_lot_apply_fill` defined |
| D20 | Routed files and symbols of Synthesis Section 8 unchanged by the cut | diff census at LDG-3169 | edit a routed symbol |

Mutations: M1 LIFO consumption; M3 dropped fee; M4 affordability-order
publication; M5 positions as positions + delta; M6 Kahan step on openings;
M7 skip a partial close's remainder; M8 wrong `context_pos`; M9 notional fee
from the rounded price; M10 drop the notional step; M11 `cumsum` totals; M12
drop `realized_comp` in unpack; M2 reordered fills within a pulse.

## 7. Timing, memory and budget (scope f)

**Protocol `ws4a-timing-1`** (shared harness; `matrix.csv`,
`thresholds.csv`, `workloads.R`, `protocol.md`). Workloads, all from
`ledgr_sim_bars(500, 1260, seed = 20260530)` as the carrier probe used:

- `wide`: SMA 5/10 transition, one unit, zero cost; availability on complete
  facts (every instrument a member every session, as the probe's
  prerequisite established), dense on the same bars;
- `nofill`: same bars, flat targets;
- `sparse`: monthly rebalance into the top 20 by 63-session return,
  ties by instrument ID in C-locale order, equal integer quantities, zero
  cost, decisions on month-start sessions with no warmup trades, outputs
  materialised as for `wide`;
- reader cells: a completed `wide` durable run; warm `ledgr_results(bt,
  "fills")`, `"trades"` and `"equity"` each in their own cell, with a fixed
  invocation count and recorded nonzero replayed rows.

Cells and bounds are those of decision (4). The marginal clock for the
absolute cell is `(t_wide - t_nofill) / reps / n_fills` measured in one
process, with `n_fills` read from the run. The small checker
`dev/bench/v0_2_3_ws4a/timing_absolute.R` reads the shared checker's
per-cell result and fails when the candidate median exceeds `40e-6`; it is
shown to reject 45 us against a 240 us base and accept 30 us.

**Memory method** (`dev/bench/v0_2_3_ws4a/memory.R`): each measured
operation runs in a fresh R process. The instrument is
`ps::ps_memory_info()` (ps 1.9.3): `peak_pagefile` (peak private commit,
covering the R heap and native allocations such as DuckDB) read
immediately before and after the operation; the reported peak-live value
is `peak_after - pagefile_before`. Default GC policy; five repetitions,
median. Domains: the whole process's private commit. `gc()` "max used" is
reported beside it with its formula (`sum(gc()[, "max used"] * c(56, 8))`
after `gc(reset = TRUE)`), never as peak live. Workloads: forward run and,
separately, a full replay (`ledgr_results(bt, "fills")`) on (i) 5,000
instruments x 252 sessions with SMA transitions and (ii) a deep-book
variant where 200 instruments each accumulate 15 single-unit lots and close
them in one fill. Controlled excess: the gut retains an extra copy of the
typed book's lot columns for the operation's duration (frozen size: a copy
of `lot_qty` and `lot_price` at their peak length, observed after the last
fill); it must exceed 1.10 x base. Rprofmem bytes per actual fill on the
`wide` workloads as in decision (5). If the instrument fails validation,
the metric returns to the maintainer before acceptance.

**Real-data controls:** the evidence record
(`E:/ledgr-data/reference/v0.2.3-base-953338df/EVIDENCE.md`, private, with
a stable pointer from LDG-3163's evidence) lists the library and state
paths, the commit and adapter identities, the installation command and
the compare commands; an unchanged `w2_minvar` rerun is IDENTICAL and a
scratch worker with `ledgr_cost_notional_bps_fee(1)` DIFFERS.

**Budget** (decision 12, estimated R lines): `workloads.R` 260,
`timing_absolute.R` 80, `record.R` 380, `check.R` 120, `guts.R` 260,
`memory.R` 220, detector baselines runner 80: about 1,400, under 1,500.
Detector predicates themselves live in the package test file, outside this
budget.

## 8. Identity checks per ticket (scope g)

| Ticket | Oracles | Cases | Detectors and mutations | Timing and memory |
| --- | --- | --- | --- | --- |
| 3164 | A0, dense, real-data | C3, C4, C5, C6, C9, C14 | D3, D7, D11, D14 (book), D15, D17, D18, D19; M1, M3, M5, M6, M7, M11, M12 | reader cells, replay memory (decision 6) |
| 3165 | A0, dense | C7 (strategy part), C10, C12, C15 | D4, D5, D13, D14, D16; M8 | none |
| 3166 | A0, dense | C1, C2, C7, C8, C11 | D1 (planners), D8, D14; M4, M9, M10 | none |
| 3167 | A0, dense | C13 | D1 (publication), D9, D6; M2 | none |
| 3168 | A0, dense | C16, C17 | D2, D10, D14 | none |
| 3169 | all, real-data | all | all, D12, D20 | full matrix, all memory workloads |

## 9. Settled here, and items for the maintainer's attention

Pinned by this note (Synthesis Section 7): the dictionaries (2.1-2.2), the
locators (2.3), the pulse capacity (2.4) and the detector names (6). Timing
noise and memory base values are recorded by LDG-3163.

Shape changes that need the cut's acceptance as their stated reason
(decision 10's "separately stated, accepted reason"): the inverted
unnamed-positions witness (LTB-0278), the publication call-count claims
(LTB-0515, LTB-0136, LTB-0280, test-risk-fold.R:83), the post-risk class
test (test-risk-fold.R:827), the retired proposal and `ledgr_fill_none`
tests (test-fill-model.R:59, :96, test-ledger-writer.R:811) and the
mode-branch census regeneration (LTB-0331). No economic value, fixture or
oracle changes. No Type 2 question is open.
