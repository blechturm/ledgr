# Lean Core Interface Table: First Checkpoint

- Status: accepted by the maintainer on 2026-11-06 after a section-by-section
  review (LDG-3211, Cut 12, workstream 26).
- Pin: `d5b3a151`, the Cut 11 close. Every `file:line` refers to that commit;
  `R/` is unchanged since. `C:` means a line of `inst/design/contracts.md`.
- Authority: the [skeleton synthesis](../rfc/rfc_lean_core_skeleton_v0_2_3_synthesis.md)
  Sections 2-5 with its accepted
  [pulse plumbing amendment](../rfc/rfc_lean_core_pulse_plumbing_v0_2_3_synthesis.md),
  and macro WS16. The semantic baseline is
  [Typed Fold Carrier](../contracts.md#contract-execution-fold-carrier)
  (C:243-342).
- Evidence: [`dev/bench/v0_2_3_ws16_interface/`](../../../dev/bench/v0_2_3_ws16_interface/).
  Its two probes ran the pinned code and recorded what each stage reads and
  writes and which stored data each read touches. The
  [fold plumbing spike](../../../dev/spikes/fold_plumbing/README.md)
  (`d8aeb04c`) replayed real folds with stages that do no work and measured
  what moving the data costs (Section 4.1).

Part A explains the fold core and should be read first. Part B is reference:
one row per field, with the code line that writes or reads it. Part C says
how the recorder captures each boundary, and checks the checkpoint against
the accepted design rules.

# Part A. How the fold core works

## 1. What this document is for

Macro WS16 replaces today's fold core with a lean one, built beside it in
`dev/lean_core/` and proven piece by piece. This checkpoint builds three
pieces:
- the lot kernel, the FIFO arithmetic behind every fill;
- memory-bounded data preparation;
- a stage recorder that both pieces, and every later family, are proven
  with.

The recorder runs today's code (the pin), freezes what goes into and comes
out of each stage, and the lean piece must reproduce the outputs exactly.
That only works if we know everything each stage reads and writes. This
document is that list. It describes today's code. Where an accepted
decision already fixes the lean core's shape, it says so and links the
decision; everything else is left to the family that builds it.

## 2. One run: preparation, then the pulse loop

```text
 sealed snapshot
      |
      v
 PREPARATION (once per run)
   load bars ----------> substrate: bar planes, facts, calendar, masks
   compute features ---> projection: one matrix per feature
   build provider -----> availability provider: membership, status
      |
      v
 FOLD (ledgr_execute_fold -> ledgr_fold_envelope)
   E builds fold state and services, then for each pulse:
      P1 observe -> P2 decide -> P3 plan -> P4 apply -> P5 commit
   E writes completion evidence and returns the result
```

A **pulse** is one decision time, normally a session close. The run's
pulses are a subset of the prepared **sessions**. `ledgr_run()`,
`ledgr_sweep()` and walk-forward all prepare this way and call the same fold
(`R/backtest-runner.R:847`, `R/sweep.R:1827`).

## 3. E and the five stages

**E** is the envelope, `ledgr_fold_envelope()` (`R/fold-engine.R:1670-2098`).
- Before the loop it validates the execution spec, imports the opening lot
  book, builds the fold reader and valuation cursor, and creates `services`
  and the fold state (Section 4).
- In the loop it calls the five stages in order. When a stage returns a stop
  result, only E installs it (`ledgr_fold_apply_stop()`), flushes the
  pulse's diagnostics and ends the loop.
- After the loop it flushes pending events, writes the completion row and
  returns the result. On an error it writes one exception diagnostic and
  re-signals the condition.

| Stage | Function (`R/fold-engine.R`) | What it does | Hands on |
| --- | --- | --- | --- |
| P1 observe and settle | `ledgr_fold_stage_observe_settle` `:296` | Reads this pulse's and the next session's bars. Asks the provider who is a member, buyable or halted. Values holdings, with stale or frozen marks where needed. Posts corporate actions and terminal dispositions to the ledger and the book. Aligns strategy state to the new decision axis. Writes the pulse's equity row. P1 is the only stage that reads the prepared data. | observation (decision packet and decision data) to P2; execution packet (next bar) to P3; or a stop |
| P2 decide | `ledgr_fold_stage_decide` `:729` | Builds `ctx`, the strategy's view, and calls `strategy(ctx, params)`. Requires a full target vector (a missing target is refused, never zero). Applies the risk chain and records intent and sizing evidence. | decision: strategy and post-risk targets, and which instruments must trade; or a stop |
| P3 plan | `ledgr_fold_stage_plan` `:1086` | For each instrument that must trade, decides fill or rejection: membership and restrictions at execution time, next-session open price, costs, affordability. | plan: fills and rejections, with the expected final cash; or a stop, including the affordability-reconciliation stop (INCOMPLETE, `:1178-1203`) |
| P4 apply | `ledgr_fold_stage_apply` `:1382` | Runs the fills through the lot kernel on a copy of the book. If that succeeds, installs the book, publishes the ledger events through the output handler, then sets positions from the lots and cash by an ordered scan. | changes the fold state |
| P5 commit | `ledgr_fold_stage_commit` `:1520` | Reconciles cash with the plan, drains the pulse's staged diagnostics to the writer, applies the strategy's state update, counts the pulse, records telemetry, and stops at `max_pulses`. | continue or end |

On a pulse the strategy schedule skips, P2 and P3 are replaced by
`ledgr_fold_scheduled_skip_decision` (`:667`, hold every position) and
`ledgr_fold_scheduled_skip_plan` (`:706`, empty plan). P1, P4 and P5 still
run.

```text
 E, pulse i
  |
  +--> P1 observe ----stop?----------------------------> E installs stop, ends loop
        | observation                     | execution packet (next bar)
        v                                 |
       P2 decide (strategy, risk) --stop? |
        | decision                        |
        v                                 v
       P3 plan (fill or reject) <---------+  --stop?
        | plan
        v
       P4 apply (lot kernel, ledger events, positions, cash)
        |
        v
       P5 commit (reconcile, flush diagnostics, strategy state)
```

## 4. Fold state, `services` and carrier groups

Stages share data through three containers.

**Fold state** (Section 8). One locked environment with exactly 22 named
slots, created by E (`R/fold-engine.R:1783-1800`): cash, positions, the lot
book, strategy state, counters, the pulse's diagnostic staging and the equity
record. Stages change it in place. It is the run's only mutable state apart
from the objects listed under `services` below.

**`services`** (Section 9). A plain named list of 46 fields that E builds
once per fold (`R/fold-engine.R:1848-1895`) and passes to every stage. In
this document "services" means this list and nothing else. It holds two
kinds of fields:
- fixed inputs: instrument IDs, the strategy function and its parameters,
  the risk plan, calendars and epochs, feature ID maps;
- stateful objects: lists of closures or environments with their own
  internal state. These are the fold reader (`history_reader`), the
  availability provider, the valuation cursor, the corporate-action plan,
  the output handler, which publishes events, and the diagnostic writer.

Each stage receives the whole list and reads the fields it needs. Eleven
fields hold objects whose internal state changes during a run (ten measured,
`schedule_query` by its code); the rest never change.

**Carrier groups** (Section 10). What one stage hands to the next: the
decision packet, decision data, execution packet, decision, plan, stop
result. Each is a named list of plain typed vectors of equal length (columns,
not rows), checked once when built by `ledgr_carrier_problem()`
(`R/fold-carrier.R:207`); today that is every pulse, in the lean core only in
debug mode (pulse plumbing R1). Their exact fields are a spec in the code,
`R/fold-carrier.R:45-180`.

### 4.1 How writes land on a pulse, and what moving data costs

Every write goes to the next row of a buffer that already exists. One loop
runs one pulse at a time with the stages in a fixed order, so a row's
position is its order of writing. Each row also carries its own stamp:
- **Fill events.** P4 numbers them from `fold_state$event_seq` and the
  handler holds the block; P5 copies it into the event buffer
  (`R/output-handler.R:567`). The append check refuses a sequence that does
  not increase or a time that goes back (`R/accounting-replay.R:141-152`).
- **Diagnostics.** Stages stage rows in `pending_segments` (fixed capacity).
  P5, or E at a stop, drains them as one block stamped with the pulse time
  and numbered from `diagnostic_seq` (`R/fold-engine.R:268-293`).
- **Equity.** P1 writes row `n + 1` of a record preallocated to the pulse
  count (`R/fold-carrier.R:979`).

Nothing checks that equity row k belongs to pulse k; after a stop the record
is a shorter prefix and its `ts` column names the pulses.

In the lean core (pulse plumbing amendment): a fill becomes a compact record
in reserved rows, committed at P5, with the ledger's wide columns built at
the output boundary (R7, R9); only residual diagnostic rows are written,
directly (R10); equity goes straight into epoch vectors.

The spike replayed both workloads through stub stages that read the same
`services` fields, hand on that pulse's real outputs and write through the
real code. Both first variants (today's, and outputs preallocated and
overwritten) and the later lean variants (`lean.R`) reproduced every event,
diagnostic row and equity row exactly.
Microseconds per pulse (`evidence/timing.csv`):

| | momentum 40 x 504 | fill-heavy 500 x 1,260 |
| --- | ---: | ---: |
| real loop | 1,925 | 6,087 |
| moving the data, as today | 1,190 | 1,976 |
| of which per-pulse carrier and append checks | 476 | 825 |
| of which diagnostic staging | 714 | 445 |
| of which fill publication (block, hold, copy) | 60 | 929 |
| handing outputs on and `services` reads | under 40 | under 40 |
| lean compact shape, floor v1 (`evidence/lean_timing.csv`) | 22 | 71 |

The parts overlap and do not add up: each removes a whole component, so it
is no design's saving. Handing data between stages is nearly free; the cost
is fixed R work per pulse. Where the lean core checks and writes is decided
by the accepted [pulse plumbing amendment](../rfc/rfc_lean_core_pulse_plumbing_v0_2_3_synthesis.md).

## 5. Data structures, with examples

**Axes.** Positions live on the **run axis**, the run's fixed instrument
list (N). The strategy sees the **context axis**, this pulse's decision axis
(members, then held former members). `context_pos` maps one to the other.

```text
run axis:        AAA  BBB  CCC  DDD        positions = c(10, 0, 5, 0)
context (pulse): CCC  AAA                  context_pos = c(3L, 1L)
decision packet: position = positions[context_pos] = c(5, 10)
```

**Lot book** (Section 11). One flat structure for all instruments, not a list
of per-instrument lots. Instrument `i` owns slots `offset[i] + 1` to
`offset[i] + capacity[i]` of `lot_qty` and `lot_price`; its live lots, oldest
first, are slots `head[i]` to `tail[i]` of that segment. Dead slots hold NA.
Example: AAA buys 100 at 10, then 50 at 11, then sells 30 at 12; BBB is flat.

```text
offset   = c(0L, 4L)     capacity = c(4L, 0L)   # a full segment grows to max(4, 2 x capacity)
head     = c(1L, 1L)     tail     = c(2L, 0L)   # BBB empty: head 1, tail 0
lot_qty  = c(70, 50, NA, NA)                    # the sale consumed 30 of the oldest lot
lot_price= c(10, 11, NA, NA)
net_by_inst = c(120, 0)  cost_basis_by_inst = c(1250, 0)   # 70 x 10 + 50 x 11
total_cost_basis = 1250  realized_pnl = 60      # (12 - 10) x 30, no fee
```

The kernel `ledgr_lot_apply(book, input)` takes a block of operations on
distinct instruments: fills, openings and dispositions. It returns a new
book and one applied row per operation, and never changes the book it was
given.

**Prepared data** (Section 12). The substrate holds each bar field as one
matrix, instruments by sessions:

```text
bars$close[i, j]   = close of instrument i at session j     (N x T, NA where no bar)
bars$observed[i, j] = TRUE where a bar exists
feature_values$return_63[i, j] = the feature at session j  (same N x T shape)
history_reader$pulse_columns[k] = the session column of pulse k
```

At 500 instruments and 5,040 sessions each plane is 20 MB. History reads also
build full-size mask planes lazily, in the substrate's `history_memo`. The
**read service** is the object behind `ledgr_history_matrix()` and
`ledgr_history_frame()`. Each decided pulse gets a **view** on it: the read
service plus the pulse's cutoff column, so a strategy can read only the past.
In the lean core, stages pass positions into these planes rather than copying
columns out of them (pulse plumbing R6).

**Tiles** (lean core, LDG-3215). Instead of full N x T planes, the lean core
keeps blocks of a fixed number of sessions (time-major), with only some
blocks in memory, and gathers across blocks when a read spans them. Each
block holds only the instruments with stored data in it. The
values, admission and evidence of every read stay the same.

## 6. What the first checkpoint changes

| Piece | Today | Lean | Proven at |
| --- | --- | --- | --- |
| Lot kernel | `ledgr_lot_apply`, used by P4, replay, opening import and terminal dispositions | one R kernel with no call into the old arithmetic; compiled later only through WS14, with this R kernel as the reference (pulse plumbing R12) | the kernel boundary, on every captured call |
| Preparation | full N x T planes, one long bars query, full feature matrices | tiles with a declared working-set budget | bar hydration, substrate, feature series, fold-reader packets and every registered history read |
| Recorder | none | captures every boundary in Section 14 from the pin | its own replay check |

The stages, E and every other existing function stay as they are.

## 7. Terms and units

| Term | Meaning |
| --- | --- |
| E, P1-P5 | The envelope and the five stages (Section 3). "P2 skip" and "P3 skip" are the scheduled-skip replacements. |
| Boundary | A function whose complete input and output the recorder captures (Section 14). |
| Owner | The one function or object that may write a field. Everything else reads it. |
| Fixed / mutable | Fixed: never changes after E builds it. Mutable: changes during the run. For `services` this was measured: each field's full serialization was hashed at the fold's first stage call and at its end, over 45 folds of ten workloads. `schedule_query` is mutable by its code but unchanged in every workload. |
| (s) | A read or write found only in the code, not in the probe: an argument passed on but never evaluated, or a branch no workload reached. |
| A0 workloads | The eight small reference workloads of `dev/bench/v0_2_3_output_freeze/`. |
| Units | `money`: account currency. `qty`: instrument units, signed, long positive. `epoch`: UTC seconds as a double. `sessions`: a count of sessions. `pos`: a 1-based index. `code`: a position in a fixed word list, 0 meaning empty. POSIXct appears only at output boundaries, in four fold-state slots, in three `services` axes (`bar_axis`, `pulses_posix`, `execution_opportunities_posix`) and in the observation's `ts`. |
| Axes | `run` (N), `context`, `row` (a group's own rows), `segment` (the total of a code list), `session` (T columns), `pulse`. |

**Time values in the lean core (maintainer, 2026-11-06).** Every time inside
the fold is an `epoch`: the four POSIXct fold-state times, the three
`services` axes and the observation's `ts`. E prepares one POSIXct pulse axis
that `ctx$ts_utc` indexes; results, the completion record and exception
diagnostics convert at the output boundary. Users see no change
([Typed Fold Carrier](../contracts.md#contract-execution-fold-carrier); the
manual's "No POSIXct in the hot loop").

# Part B. Reference

## 8. Fold state slots

Owner: E. Validator: `ledgr_fold_state_validate()`
(`R/fold-phase-contract.R:82-155`), at creation and after a stop, never per
pulse. Slots: `R/fold-phase-contract.R:1-24`. In the lean core, internally
assembled state and the state after a stop are checked only in debug mode
(pulse plumbing LR-17).

| Slot | Type, axis | Unit | Invariant | Written by (line) | Read by |
| --- | --- | --- | --- | --- | --- |
| `cash` | double scalar | money | finite | P1 settlement `R/fold-engine.R:248`; P4 `:1512` (ordered scan `:1506`) | P1, P2, P3, P3 skip, P4, P5 |
| `positions` | double run, unnamed | qty | finite; a fill or disposition sets touched positions from the book net (`:1505`); imported positions are kept as given (C:331-336) | P1 `:249`; P4 `:1511` | P1, P2 (`ledgr_position_fact_source`), P3, P3 skip, P4, P5 |
| `lot_state` | lot book (Section 11) | Section 11 | book rules with `reduction = FALSE` | P1 `:250`; P4 `:1478`, compiled `:1428` | P1 (equity row), P2 (position facts), P4 |
| `strategy_state` | list of declared fields | declared | aligned to `state_axis` | P1 align `:547`; P5 `:1629` | P1, P2 (`ledgr_strategy_state_view`), P5 |
| `position_facts` | list(`entry_bar`, `exit_bar`), integer run | session pos | NA when not anchored (`R/position-facts.R:1-9`) | P1 `:242`; P4 `:1432`, `:1482` (`R/position-facts.R:197`) | P1, P2, P4 |
| `state_axis` | character context IDs or NULL | ID | the axis `strategy_state` is aligned to | P1 `:555` (s); P5 `:1627` | P1 |
| `state_axis_changed` | logical scalar | flag | not NA | P1 `:554` (s); P5 `:1628` | validation only |
| `event_seq` | integer scalar | sequence | at least 1; the next ledger sequence | P1 `:380`, `:411`, `:495`; P4 `:1436`, `:1493` | P1, P3 (implicit block), P4 |
| `status` | character scalar | token | non-empty; `DONE` until a stop | E stop `R/fold-phase-contract.R:198` | E completion `R/fold-engine.R:2039-2047`, empty run `:1906`, result `:2088` |
| `stop_reason` | character scalar | token | NA until a stop | E stop `R/fold-phase-contract.R:199` | E completion |
| `affected_exposure` | list(`value`, `details`, `ts_utc`, `specified`) | money; POSIXct | the four fields present | E stop `:200` | P3 (s) affordability stop `R/fold-engine.R:1195`; E completion |
| `processed` | integer scalar | pulses | non-negative | P5 `:1631`; E stop `R/fold-phase-contract.R:206` | P5; E telemetry sampling `R/fold-engine.R:1935`; E stop; E result `:2089` |
| `full_run` | logical scalar | flag | not NA | P5 `:1660` | E completion and result |
| `last_fully_valued` | POSIXct scalar | time | the last valued pulse | P1 `:586` | E completion |
| `last_executed` | POSIXct scalar | time | the latest fill time | P5 `:1550` | P5; E completion |
| `frozen_set` | character IDs | ID | held instruments with a frozen mark | P1 `:545` | P1 |
| `current_stage` | character scalar | label | non-empty | E `:1932`; P1 `:304`; P2 `:823`, `:1015`; P3 `:1094`; P4 `:1389` | E exception diagnostic `:2072` only |
| `current_ts` | POSIXct scalar | time | the current pulse | E `:1931` | E exception diagnostic `:2071` |
| `pending_segments` | diagnostics staging (carrier) | rows | used prefix valid; capacity fixed in E `:1795-1797` | stages via `ledgr_fold_staging_add`, `_add_residual`, `_write` (`R/fold-carrier.R:876-928`); P2 skip `:673` and E's skip row `R/fold-engine.R:1969-1977` stage rows; E stop; flush drains `:286-287` | flush; P1-P5; P2 skip `:673`; E stop `R/fold-phase-contract.R:201` |
| `equity_facts` | equity record (carrier) | money; epoch | rows preallocated to the pulse count | P1 `R/fold-engine.R:633` (`R/fold-carrier.R:979`) | P1; E result `R/fold-engine.R:2096` |
| `diagnostic_seq` | integer scalar | rows | non-negative; rows drained so far | flush `:288`; P5 through the flush it calls `:1599` | P3, flush; P5 through the flush it calls `:1599` |
| `telemetry_idx` | integer scalar | samples | non-negative | P5 `:1635` | P5 |

`current_stage`, `current_ts` and `pending_segments` change on every pulse,
so a whole-state comparison names them; it does not skip them.

## 9. `services` fields

Owner: E for the list; a stateful object owns its own internal state.
Nothing validates the list as a whole; each field is checked by its
producer or where the table says. Section 14 freezes nine of the eleven
mutable fields and records the calls of `output_handler` and
`diagnostic_writer`. Lines are `R/fold-engine.R` unless named.

| Field | Type | Fixed / mutable (code) | Read by (helper) | Producer |
| --- | --- | --- | --- | --- |
| `run_id` | character | fixed | P1 (`ledgr_accounting_rows`), P2, P3 (implicit blocks), P4 (compiled), P5 (flush) | E `:1672` |
| `instrument_ids` | character run | fixed | every stage; P2 skip (s) | E `:1673` |
| `id_to_idx` | integer | fixed | no stage | E `:1674` |
| `history_reader` | list of closures | mutable: read counter `R/history-substrate.R:507-511`; substrate memo `R/history-frame.R:151-158`, written by later reads | P1 (`bars`, `view`, `pulse_columns`) | `ledgr_history_substrate_fold_reader`, `R/history-substrate.R:488` |
| `empty_df` | data.frame | fixed | P2 (s) | E `:1753` |
| `runtime_projection` | projection (Section 12) | fixed | P2 (`ledgr_update_pulse_context_helpers`) | `R/backtest-runner.R:675`, `R/sweep.R:285` |
| `projection_pulse_idx` | integer pulse | fixed | P1 (settlement install), P2 | E `:1762` |
| `def_ids` | character | fixed | P2 (s) | E `:1755` |
| `active_alias_map` | named character or NULL | fixed | P2 (s) | E `:1698` |
| `risk_plan` | compiled risk plan | fixed; checked once `:1699` | P2 (`ledgr_apply_risk_plan`) | E `:1699` |
| `execution_seed` | integer or NULL | fixed | P2 | E `:1702` |
| `pulse_seeds` | integer pulse or NULL | fixed | P2 (`ledgr_pulse_seed_at`, `R/rng.R:101`) | E `:1711` |
| `strategy_fn` | function | mutable only through user state in its closure (1 of 45 folds) | P2 (`ledgr_call_strategy_fn`) | E `:1675` |
| `strategy_params` | list | fixed | P2 (`ledgr_call_strategy_fn`, strategy helpers) | E `:1676` |
| `strategy_call_signature` | character | fixed | P2 | E `:1677` |
| `strategy_is_functional` | logical | fixed | P2 | E `:1678` |
| `strategy_state_declaration` | declaration | fixed | P1 (s), P5 (`ledgr_strategy_state_defaults`) | execution spec |
| `strategy_state_default_scalars` | list | fixed | P1 (s), P5 (`ledgr_strategy_state_apply_values`) | execution spec |
| `availability_provider` | provider | mutable: cursor `seek` `R/availability-provider-prepared.R:316-343` | P1 (`decision_view`), P3 (`ledgr_carrier_execution_view`) | `R/history-substrate.R:1621` |
| `valuation_state` | list of closures | mutable: `advance` cursor `R/availability-economics.R:82-107` | P1 | E `:1733` |
| `corporate_action_plan` | plan or NULL | mutable: state environment `R/corporate-action-settlement.R:243` (8 folds) | P1 (`check_clocks`, `post`, `check_quantity_effects`, `has_disposition`, `post_disposition`; `:368-411`), P4 (`bind_boundary`); E (`event_kinds` `:1745`, `bind_boundary` `:1922`) | execution spec |
| `terminal_policy` | policy | fixed | P1 (`ledgr_terminal_resolve`) | E `:1837` |
| `output_handler` | handler | mutable: buffers and connection | P1 (passed to corporate-action `post`, `post_disposition` and `ledgr_disposition_post`, which call `append_event_rows`), P4, P5 | caller |
| `availability_feature_name_state` | list | fixed | P2 (s) | E `:1815` |
| `availability_feature_lookup_state` | list | fixed | P2 (`ledgr_attach_feature_helpers`) | E `:1822` |
| `context_build_counts` | environment | mutable: `R/pulse-context.R:88-90` (6 folds) | P2 (`ledgr_refresh_pulse_context_lookup`) | E `:1812` |
| `context_preparation_counts` | environment | fixed in the fold: written only by E `:1813-1847` | P2 (held in each context lookup, `R/pulse-context.R:657`) | E `:1813` |
| `bar_axis` | POSIXct session | fixed | P2 (`ledgr_position_fact_source`) | E `:1876` |
| `position_fact_fill_axis` | list | fixed | P4 (`ledgr_position_fact_fill_bar`) | E `:1830` |
| `position_fact_unknown_basis` | character | fixed | no stage | execution spec |
| `position_fact_unknown_basis_mask` | logical run | fixed | P2 (`ledgr_position_fact_source`) | E `:1879` |
| `pulse_notes` | environment | mutable: P2 writes `sizing_skipped` `:819` and `raw_sizing_notice_written` `:925`; exposed to the strategy as `ctx$.notes`, so values read back from it are user output and checked under pulse plumbing R2 | P2 | E `:1838` |
| `schedule_query` | closure | mutable: memoizes each newly queried schedule `R/strategy-schedule.R:174-176` | P2 (s), only through `ctx$.schedule_query` `:778` | E `:1842` |
| `execution_opportunities_posix` | POSIXct or NULL | fixed | P1 (execution packet `exec_ts`) | execution spec |
| `execution_epochs` | double, epoch | fixed | P3 | E `:1729` |
| `execution_epoch_valid` | logical | fixed; checked once `:1730` | P3 | E `:1730` |
| `cost_resolver` | function | fixed | P3 (`ledgr_plan_resolve`) | execution spec |
| `pulses_posix` | POSIXct pulse | fixed | P4 | E `:1679` |
| `use_compiled_spot_fifo` | logical | fixed | P3, P4 | E `:1717` |
| `event_mode` | character | fixed; retired in the lean core with `execution_mode` (LR-12) | P4, P5 (s) | E `:1713` |
| `diagnostic_writer` | list of closures | mutable: `R/availability-diagnostic-writer.R:89-205` | P3 (`can_encode`, `append_implicit`), P5 flush (`keep`, `append_block`, `record_coverage`) | E `:1803` |
| `telemetry` | environment | mutable: P5 `:1637-1648`, E `:2084-2085` | P5 | execution spec |
| `telemetry_stride`, `checkpoint_every`, `max_pulses` | integer, integer, double | fixed; `checkpoint_every` retires with `execution_mode` (LR-20) | P5 | E `:1682-1684` |
| `decision_due` | logical pulse or NULL | fixed | P1, E `:1958` | E `:1895` |

## 10. Groups passed between stages

Each value is owned by the stage that builds it and never written after that
stage returns. Carrier groups are checked once by `ledgr_carrier_problem()`
(`R/fold-carrier.R:207`) through their constructor. Rows marked "plain" are
ordinary lists that nothing checks. Every group is built fresh on every
pulse, so today every check also runs on every pulse: about nine to ten per
pulse on the spike workloads, counting P3's execution view
(`check_census.csv`). In the lean core these group checks run only in debug
mode (pulse plumbing R1, LR-13).

| Group | Fields and units | Producer (line) | Validator | Consumers |
| --- | --- | --- | --- | --- |
| decision packet | spec `R/fold-carrier.R:46-65`. `pulse_idx` pos; `ts` epoch; `context_pos` pos; `cash`, `positions_value` money; `position` qty; `member`, `held`, `buyable`, `target_restricted`, `priced`, `permissible`, `frozen` flags; `restriction_*` code list; `status`, `lifetime` provider codes; `terminal_event`, `lifetime_fact_id` text; `mark`, `reference` money per unit; `source_ts` epoch; `mark_age` sessions; `mark_source` code | P1 `R/fold-engine.R:589-598`, from `ledgr_carrier_provider_view` (`R/fold-carrier.R:549`) | `ledgr_carrier_packet` `R/fold-carrier.R:488` | P2, P3, P5, P2 skip |
| decision data | spec `:66-72`. OHLC money per unit; `volume` qty; `observed` flag; `source_row` pos; `source_column` session pos; `history` the pulse's view | P1 `R/fold-engine.R:602-612` | `ledgr_carrier_packet` | P2 only; E drops it `:1988` |
| execution packet | spec `R/fold-carrier.R:73-77`. `exec_ts` epoch; `has_next` flag; next-session OHLC money per unit and `volume` qty, run axis | P1 `R/fold-engine.R:620-628` | `ledgr_carrier_packet` | P3 only |
| observation (plain) | `pulse_idx`, `ts` (POSIXct), `ts_iso`, `positions_value`, `packet`, `data`; clocks `sample_start`, `t_feats`, `t_bars` | P1 `:648-661` | none | P2-P5 |
| decision | spec `R/fold-carrier.R:78-83`. `context_pos` pos; `strategy_qty`, `target_qty` qty on context; `actionable_k` context ordinals that must trade; `state_update`, `intent_reason` opaque | P2 `R/fold-engine.R:1068-1075`; skip `:688-695` | `ledgr_carrier_decision` `R/fold-carrier.R:495` | P3, P5 |
| decision extras (plain) | `diagnostic_decision`, `diagnostic_risk` (unexpanded diagnostic segments); clocks `sample_start`, `t_ctx`, `t_strat`, `t_target` | P2 `R/fold-engine.R:1076-1083`; skip `:696-701` | segment builder `R/fold-carrier.R:821` | P3, P5 |
| plan (`batch`), with fill and rejection | spec `R/fold-carrier.R:91-113`. Plan: `expected_final_cash` money; `economic_event_kinds` codes. Fill: `k` ordinal, `pos` pos, `side` +1/-1, `qty` qty, `price` money per unit, `fee`, `cash_delta` money, `position_delta`, `position_before`, `planned_position_after` qty, `exec_ts` epoch, info code list. Rejection: `k` ordinal, `pos` pos, `emit`, `primary`, reason code list, `resolved_price` money per unit, `exec_ts` epoch, `position` qty | P3 `ledgr_fold_build_availability_pulse_plan` `R/fold-engine.R:1126`; skip `:709-720` | `ledgr_carrier_plan` `R/fold-carrier.R:501` | P4, P5 |
| plan extras, apply result (plain) | clocks `sample_start`, `t_target`, `t_fill`; P4 returns `sample_start`, `t_event`, `t_state` | P3 `R/fold-engine.R:1338-1343`; P4 `:1513-1517` | none | P4, P5 |
| execution view | spec `R/fold-carrier.R:86-90`. `member`, `restricted` flags; reason code list; one row per instrument that must trade | P3 `R/fold-engine.R:1120` | `ledgr_carrier_execution_view` `R/fold-carrier.R:622` | P3 only |
| publication | spec `R/fold-carrier.R:117-133`. Ordered `ledger_events` columns: IDs and tokens text, `ts_utc` epoch, `qty`, `position_delta` qty, `price` money per unit, `fee`, `cash_delta` money, `event_seq` sequence, typed missing evidence | P4 handler `ledgr_fill_event_payload` `R/backtest-runner.R:92` (called `R/output-handler.R:538`, `R/ledger-writer.R:142`) | `ledgr_carrier_new` `R/fold-carrier.R:507`, at `R/backtest-runner.R:108-111`, `:138-140` | the handler, which keeps it. In the lean core replaced by compact fill records in reserved rows; the wide ledger columns are built at the output boundary (R7, R9) |
| leg | spec `R/fold-carrier.R:134-138`. `event_seq`; `qty` qty; `price`, `fee`, `realized_pnl` money; `ts_utc` epoch | P4 handler `ledgr_fill_leg_block` `R/output-handler.R:44` (called `:769`) | `ledgr_carrier_new`, at `R/output-handler.R:70` | the memory sink, which keeps it |
| stop result | spec `R/fold-carrier.R:175-179` | P1 `R/fold-engine.R:353`; P2 `:1006`; P3 `:1191` | `ledgr_fold_stop_result` `R/fold-phase-contract.R:161` | E only |

## 11. Lot kernel boundary

`ledgr_lot_apply(book, input)` (`R/lot-accounting.R:402-704`) is the one
FIFO arithmetic (layout example in Section 5). It returns `list(book,
applied)` or raises a condition, and never changes its input book (C:325-330).

| Group | Fields, type, unit | Invariant | Validator (where) | Lean core: external check and phase; kept refusal; debug check; unit test |
| --- | --- | --- | --- | --- |
| book | `offset`, `capacity`, `head`, `tail` integer run (slot pos); `lot_qty` double slots (qty, signed); `lot_price` double slots (money per unit); `net_by_inst` double run (qty); `cost_basis_by_inst` double run (money); `total_cost_basis`, `realized_pnl`, `realized_comp` double scalars (money) | C:281 and `R/lot-accounting.R:50-67`: disjoint segments in axis order; live lots `head..tail`; dead slots NA; finite totals; a flat net is exactly 0; cached net and basis equal the lot sums only for books built by openings | `ledgr_lot_book_problem` `:68`; `reduction = TRUE` only when built from openings (`:819`); `FALSE` at fold entry (`R/fold-engine.R:203`), in fold-state validation, at the compiled unpack (`R/compiled-spot-fifo.R:134`) and in the kernel's overflow check (`:566`) | external: imported opening and carried books at E (`R/lot-accounting.R:819`), replayed books through the read validator; kept: corrupt book at fold entry, `ledgr_lot_state_invariant` (`R/fold-engine.R:203-207`); debug: `ledgr_lot_book_problem` after every kernel call; test: disjoint segments, live `head..tail`, dead slots NA, flat net exactly 0, cached sums for books built by openings, finite totals |
| lot input | `operation` integer (1 fill, 3 opening, 4 disposition), `pos` integer, `side` integer; `qty` qty, `price` money per unit, `fee` money, `position_before` qty, `realized_model_pnl` money | C:290; distinct positions in one call | `ledgr_lot_input` `:286-336`, in the operation wrappers `:707-729`. In the lean core the economic input rules stay (R3); shape re-checks on input ledgr built are debug-only (LR-18) | external: none inside the fold (P3 builds it from checked data); import and replay inputs at their entry; kept: position outside the axis and the economic rules of C:290, `ledgr_invalid_lot_fill`; debug: shape, type and distinct-position checks (LR-18); test: each operation's sign and value rules, fee and witness recycling |
| applied row | eight doubles per row: `position_before`, `position_after`, `close_qty`, `open_qty` qty; `realized_close`, `realized_delta`, `event_realized`, `event_cost_basis` money | C:291; the close/open split is checked against the lots before and after | `ledgr_lot_applied` `:351-394`, every call. In the lean core this self-check is debug-only (LR-13); the contracted refusals below stay (R3) | external: none; kept: none of its own; debug: `ledgr_lot_applied` (LR-13); test: close/open split against the lots before and after, an opening closes nothing, finite values, split within its slack |
| refusals | `ledgr_invalid_lot_fill` (axis `:405-410`, overflow `:592-596`); `ledgr_lot_state_invariant` (opening through an opposing lot, disposition exhaustion `:604-613`; capacity `:648-653`); witness mismatch through `ledgr_accounting_event_error` (`:598-603`) | the earliest failing row refuses; within a row: closing overflow, opening through an opposing lot, disposition exhaustion, realized witness, later overflow (`:549-615`) | in the kernel, as it runs | external: n/a; kept: all, same classes and order (R3); debug: none extra; test: each refusal, earliest failing row first, in-row order as listed |

| Caller | Pinned entry | Census calls (A0 / fill-heavy / tests) |
| --- | --- | --- |
| fold P4 fill block | `ledgr_fold_fill_candidate` `R/fold-engine.R:1355`, through `ledgr_lot_fill` | 56 / 1,249 / 12,795 |
| replay and readers | `ledgr_replay_accounting_events` `R/accounting-replay.R:445`, blocks `:491`, through `ledgr_lot_apply_blocks` `R/lot-accounting.R:747` | 124 / 1,250 / 103,238 |
| opening and carried-lot import | `ledgr_lot_book_from_opening` `R/lot-accounting.R:786`, called by `R/backtest-runner.R:596` | 27 / 0 / 416 |
| terminal disposition and recovery | `ledgr_disposition_post` `R/terminal-outcomes.R:125`, kernel `:170` | 7 / 0 / 63 |

The census also counts 40,019 direct calls from tests and one P4 call outside
the candidate (`../../../dev/bench/v0_2_3_ws16_entry/evidence/fifo_blocks_tests.csv`).
P4 finds its earliest failing fill by bisecting block prefixes itself
(`R/fold-engine.R:1366-1379`), one kernel call per prefix. That `failed`
index is a P4 output, not a kernel output. The compiled spot FIFO
(`R/fold-engine.R:1411-1446`, `R/compiled-spot-fifo.R:109`) does not call the
kernel and is outside this checkpoint.

## 12. Prepared data and the tile adaptation

### 12.1 Today's prepared data

| Object | Fields | Type, axis, unit | Producer | Owner, lifetime | Lean core: external check and phase; kept refusal; debug check; unit test |
| --- | --- | --- | --- | --- | --- |
| substrate | `substrate_version`, `clock_kind`, `snapshot_hash`, `policy_identity`, `history_policy`, `source_start_utc`, `data_start_utc` | scalars; POSIXct times | `ledgr_history_substrate` `R/history-substrate.R:1499-1619` | immutable; one per execution | external: snapshot open, sealing and hash verification, then identity and axis checks once in preparation (`R/history-substrate.R:1509-1530`); kept: their existing refusals; debug: none; test: identity unchanged by tiling |
| substrate | `instrument_ids`, `instrument_index`; `axis`, `pulse_index` | character N with ID-to-pos map; POSIXct T with ISO-name-to-pos map | `:1599-1602` | immutable | external: preparation, as above; kept: as above; debug: none; test: one global instrument map serves every tile |
| substrate | `bars`: `open`, `high`, `low`, `close`, `volume` double N x T (money per unit; qty), `observed` logical N x T | instruments by sessions; NA where no bar | `ledgr_history_substrate_bar_matrices` `:422-461`; duplicate bars refuse `:448` | immutable | external: import and sealing, plus coverage (`:94`) and duplicate bars, `ledgr_invalid_history_substrate` (`:448`), once in preparation; kept: both; debug: none; test: tile planes equal the full planes' values and absence |
| substrate | `bar_gap_runs` per field | runs of missing values (session pos) | C++ `ledgr_cpp_history_gap_runs` `:1575-1581` | immutable | external: none (derived); kept: none; debug: run bounds; test: a run crossing a tile edge stays one run |
| substrate | `segments` (`lifetime`, `lifetime_terminal`), `segment_counts`, `sessions`, `provider_plan` | typed segment columns with effective and knowledge times (epoch); counts; calendar; provider plan holding membership and status facts | `:1547-1589` | immutable | external: fact knowledge, `ledgr_availability_data_require_fact_knowledge` (`:1531`), once in preparation; kept: its refusal; debug: none; test: segment resolution unchanged across tiles |
| substrate | `history_memo` | environment of mask planes built on first use (Section 12.2) | `:1615` | mutable; never staged | external: none (derived); kept: none; debug: mask consistency; test: per-tile masks equal full-plane masks at every cutoff |
| substrate | `feature_projection` | projection | `ledgr_history_substrate_bind_features` `:409-420` | immutable after binding | external: feature outputs once in preparation, `ledgr_invalid_feature_output` (with the accepted post-warmup NA decision); kept: it; debug: none; test: tile-served feature reads equal full-matrix reads |
| projection | `feature_values` | per feature ID a double N x T matrix, dimnames IDs x ISO pulses | `R/runtime-projection.R:1-55` | immutable | external: shape once, `ledgr_invalid_runtime_projection` (`R/runtime-projection.R:10-36`); kept: it; debug: none; test: as `feature_projection` |
| projection | `feature_planes` | per feature, sparse evidence keyed `(row - 1) * n_pulse + col`, sorted | `ledgr_projection_index_planes` `R/runtime-projection.R:62-102` | immutable | external: none (derived); kept: none; debug: key order; test: evidence identical per tile |
| projection | `instrument_index`, `pulse_index`, `pulses_posix`, `pulses_iso`, `feature_engine_version`, `alias_index` | maps and identity | `:39-52` | immutable | external: preparation; kept: none; debug: none; test: maps unchanged by tiling |
| read service | `substrate`, `feature_defs`, `feature_names` | locked environment | `ledgr_history_read_service` `R/history-frame.R:461-481`, which first builds the mask summaries `:446-457` | fixed per fold | external: history request arguments at each request (user code, R2; `R/history-frame.R:991-1043`); kept: their refusals, e.g. `ledgr_invalid_history_field`; debug: none; test: every registered history read returns identical frames, matrices and metadata on tiles |
| view | `service`, `cutoff_col` (session pos) | list | `ledgr_history_view` `R/history-frame.R:483-488` | one per decided pulse; never changed | external: none (built by E per pulse); kept: none; debug: cutoff within the axis; test: a view never reads past its cutoff |

### 12.2 Where data is read and allocated, and what tiles change

Each row is an existing function the checkpoint keeps. "Today" is what
`tile_probe.R` recorded on a history test fixture (late-known lifetime fact,
bar gap, price carry) and on the 40 x 504 momentum run
(`tile_access_by_site.csv`). Tiles may change only how data is stored,
fetched and allocated; the calculation, order, admission and evidence stay.
LDG-3215 chooses widths, residency and eviction.

| Function (pinned) | Today | Change for tiles |
| --- | --- | --- |
| bar hydration: `ledgr_precompute_fetch_bars_frame` `R/precompute-features.R:477`, called from `R/history-substrate.R:320`; the runner's own query `R/backtest-runner.R:629` | one long query over every instrument and session, ordered by instrument and time (20,160 x 7 at 40 x 504) | query by tile session range into tile planes; same rows, values and duplicate refusal |
| bar planes `R/history-substrate.R:422` | six N x T planes, instruments by sessions | time-major tiles (sessions x stored instruments) with one global instrument map and explicit absence (skeleton Section 3) |
| gap runs `:1575-1581` | runs over each full plane | runs computed across tile edges; a run crossing an edge stays one run |
| fold-reader packets `:465-486`, `:510-529` | one column of every plane per packet; `next_bar` reads the next column | tile column read; `next_bar` may cross a tile edge |
| feature input `R/history-features.R:169-218` | one instrument's row from column 1 to the range end (41 calls for 40 instruments) | gather that instrument's prefix across tiles; the gathered row is a measured allocation |
| feature output `R/history-features.R:456-460`, written `:487` | one N x T matrix per feature, written by instrument and knowledge range | write each range into tile output planes; no full matrix |
| payload and projection: `ledgr_history_precompute_payload` `R/history-substrate.R:376-407`; `ledgr_projection_from_payload` `R/runtime-projection.R:134-187`; run path `ledgr_projection_from_feature_matrix` `:108-132` | sweep and precompute split each matrix into per-instrument vectors, then rebuild an N x T matrix; the run path wraps the matrices | the projection serves tile ranges; any split or rebuild copy is counted |
| memo masks and carry sources: `ledgr_history_prepare_masks` `R/history-frame.R:60-95`, `ledgr_history_prepare_positions` `:101-121`, `ledgr_history_mask_barrier` `:126-146`, overlays `:186-204` | full-axis planes: base masks N x T, carry source N x T per field, last barrier N x T, a 1 x T overlay per late-known instrument fact | prepared per tile, or kept whole and counted in the working set (LDG-3215 decides); overlays keep the cutoff and vintage choice (`:207`, `:257`) |
| compact bar read: `ledgr_history_bar_compact` `:625-663`, C++ through `ledgr_history_value_slice` `:602-623` | the whole stored plane and the full masks go to C++ with row and column indices; carry reach starts at `dependency_first` (`:535-544`) | pass a gathered slice of the requested rows and columns `dependency_first` to cutoff, with remapped columns, or tile-aware access in the same C++ |
| long bar read: `ledgr_history_bar_evidence` `:287-325` | `stored[rows, columns]`; carried values read by linear index into the stored plane (`:298-305`), possibly before the window | gather the window and every referenced source column |
| feature reads: compact `:665`, evidence `:359-432` | `feature_values[rows, columns]`, `observed[rows, columns]`, the base-mask slice | tile range gather |
| pulse feature read: `ledgr_projection_feature_vector_accessor` `R/runtime-projection.R:232-257` | one projection column per feature per decided pulse | tile column read |
| valuation cursor `R/availability-economics.R:3-11` | holds `bars$close`, the full N x T plane | reads closes by tile column |

The probe found no function that needs more than storage, fetch and
allocation changes, so this ticket does not return `NEEDS_TYPE_2`. Other
reused functions, unchanged: snapshot open, sealing and verification
(`ledgr_snapshot_ensure_handle`); fact segments and their resolvers
(`R/history-substrate.R:539-1495`); the provider plan
(`R/availability-provider-prepared.R:346`); feature certification and
calculation (`R/history-features.R:19`, `:282-407`); treatment and carry
(`R/history-treatment.R`); the read plan and admission
(`R/history-frame.R:991-1227`, `:770-829`); the C++ history kernels
(`src/`); projection lookups (`R/runtime-projection.R`); the strategy context
(`R/pulse-context.R`).

## 13. Validation placement

> R1-R5 and pulse-plumbing Section 4 decide validation placement. For every
> field record type, axis, unit, invariant, producer, owner, external
> validator and phase, retained R3 refusal/class/order, debug assertion and
> module-property test. Internal construction is not a production validation
> boundary. Publication retains P3 effects and uses R7-R10 committed ranges,
> including P1 and stop drainage. Recorder captures are copied at the semantic
> boundary under R13; worker debug mode is explicit.

Scope (maintainer, 2026-11-06): this checkpoint fills the lean-core column
for the fields its code touches, Sections 11 and 12.1. Each later family
fills its own stage's rows at its cut, before its code.

| Guarantee | Checked at | Trusted after |
| --- | --- | --- |
| Substrate identity and axis | `R/history-substrate.R:1509-1530`; rectangular coverage `:94`; duplicate bars `:448` | every read |
| Projection shape | `R/runtime-projection.R:10-36`: named feature IDs, N x T double matrices | every feature read |
| Fact knowledge | `ledgr_availability_data_require_fact_knowledge` `R/history-substrate.R:1531` | segments and masks |
| Fold state | `R/fold-phase-contract.R:82`, at creation and after a stop. In the lean core the internally assembled state and the state after a stop are checked only in debug mode (pulse plumbing LR-17) | stages |
| Risk plan, execution epochs | once in E, `R/fold-engine.R:1699`, `:1730` | P2, P3 |
| Carrier groups | once at construction (Section 10), which today is every pulse: 238 us per pulse on momentum, 389 on fill-heavy. Only the conditions that can fail on data cost 10 and 25 (spike `checks_timing.csv`). Under the accepted [pulse plumbing amendment](../rfc/rfc_lean_core_pulse_plumbing_v0_2_3_synthesis.md) (R1-R3) the lean core checks ledgr's own groups only in debug mode | consumers |
| Fill events | the publication group check (Section 10), then the append check `ledgr_validate_accounting_append` `R/accounting-replay.R:88` (called `R/output-handler.R:468`), about 250 us per fill block whatever its size; the same check runs again on read (typed accounting synthesis 3.4). Under the amendment (R4) the fold's own events are checked on read only | the event buffer |
| Diagnostic staging | capacity per row (C:223-229); the staging group at E and at each drain. In the lean core the staging and writer-block assertions are debug-only and the capacity refusal stays (LR-17) | the writer |
| Strategy return, post-risk targets | `ledgr_validate_strategy_targets` `R/fold-engine.R:868`; `:1020-1022`. In the lean core the strategy return stays checked on every decided pulse; the post-risk quantity re-check is debug-only, and post-risk admissibility and short-exposure refusals stay (LR-16) | P3 |
| History requests | at the request (`R/history-frame.R:991-1043`, lookback `:515`, cutoff `:1084`) | the read |
| Lot input, applied rows, dynamic refusals | Section 11 | the calling boundary |

Kept limits (C:331-342, skeleton Section 2): imported positions are not
required to equal the lot-derived net, and a book reached by fills or
dispositions is not required to equal a fresh sum of its lots. Passing typed
vectors instead of carrier objects keeps every carrier guarantee.

# Part C. Recording and checks

## 14. Recorded boundaries

> R1-R5 and pulse-plumbing Section 4 decide validation placement. For every
> field record type, axis, unit, invariant, producer, owner, external
> validator and phase, retained R3 refusal/class/order, debug assertion and
> module-property test. Internal construction is not a production validation
> boundary. Publication retains P3 effects and uses R7-R10 committed ranges,
> including P1 and stop drainage. Recorder captures are copied at the semantic
> boundary under R13; worker debug mode is explicit.

How the recorder freezes what it captures:
- Plain values are frozen by serialize and restore, so no live environment
  or reused buffer is held.
- Fixed `services` fields are captured once per fold.
- Mutable fields are captured at entry and exit by serializing each binding
  of their environments into a store keyed by digest. An unchanged large
  binding (the substrate inside `history_reader`, the close plane inside
  `valuation_state`) is therefore stored once per fold.
- `output_handler` and `diagnostic_writer` are not frozen. The capture
  records their calls in order, with frozen arguments and return values, and
  replay substitutes a recording handler that returns them. That includes
  `keep`: the durable sink keeps every staged diagnostic row
  (`R/output-handler.R:88`), the memory sink filters (`:331`).
- A captured value is copied, never held by reference. If a later family
  writes stage outputs into reused buffers, a recorder that keeps references
  records the last pulse's values: in the spike, 500 of 504 and 1,259 of
  1,260 recorded decisions were wrong (`parity.csv`).
- The spike's `tape.R` is a working prototype of this capture for stage
  results, staging calls, fill publication and equity rows. It wraps the
  pinned functions from outside, and its replay reproduced the real events,
  diagnostic blocks and equity record exactly.
- `.Random.seed` is part of P2's input and output: E seeds once
  (`R/fold-engine.R:1706-1712`) and strategies draw from the global stream.
- A raised condition is recorded with its class, message, and the state and
  handler calls before it.

Comparison: `identical()` over values, names, attributes, types and order.
Only these clock fields are dropped: `sample_start`, `pulse_start`,
`t_feats`, `t_bars`, `t_ctx`, `t_strat`, `t_target`, `t_fill`, `t_event`,
`t_state`, and the `telemetry` fields `t_pulse`, `t_bars`, `t_ctx`, `t_fill`,
`t_state`, `t_feats`, `t_strat`, `t_target`, `t_event`, `t_exec`, `t_loop`
and `t_pre`. Counters are compared. Function source references are not.

Replay check: re-run each pinned boundary on its frozen input, giving it only
the fold-state slots and `services` fields that Sections 8 and 9 list for
it, and compare with the frozen output. A match proves the capture is
complete.

| Boundary (pinned) | Complete input | Complete output |
| --- | --- | --- |
| E `ledgr_fold_envelope` `R/fold-engine.R:1670-2098` | execution spec; output handler | result list `:2087-2097`; handler calls `init_buffers`, `run_transaction`, `write_run_evidence` or `write_run_diagnostics`, `pending_event_count`, `flush_pending`, `write_exception_diagnostic`; the diagnostic writer's `drain`, `release`; a re-signalled condition `:2082` |
| P1 `ledgr_fold_stage_observe_settle` `:296-662` | arguments `pulse_idx`, `ts`, `ts_iso`, `sample_telemetry`, `sample_start`; P1's slots and fields | observation and execution packet, or a stop; slot writes (Section 8); handler `append_event_rows`; mutable fields after; conditions |
| P2 `ledgr_fold_stage_decide` `:729-1084` | observation; P2's slots and fields; `.Random.seed` | decision and extras, or a stop; staged rows; `pulse_notes`, `context_build_counts`, the `schedule_query` memo and `strategy_fn` closure state; `.Random.seed`; `ledgr_strategy_error` and validation conditions |
| P3 `ledgr_fold_stage_plan` `:1086-1344` | observation, decision, execution packet; P3's slots and fields | plan and extras, or a stop; staged rows; `diagnostic_writer$append_implicit` blocks |
| P4 `ledgr_fold_stage_apply` `:1382-1518` | observation, plan; P4's slots and fields | apply result; `cash`, `positions`, `lot_state`, `position_facts`, `event_seq`; handler `write_fill_events`, `record_accounting_fact` or `append_compiled_spot_batch`; corporate-action `bind_boundary`; on refusal, the earlier fills' publication and then the failing fill's condition `:1459-1468` |
| P5 `ledgr_fold_stage_commit` `:1520-1664` | observation, decision, plan, apply result; P5's slots and fields | `continue`; slot writes; handler `flush_pulse_events`, `pending_event_count`, `flush_pending`; telemetry; the flush below; reconciliation conditions `:1560`, `:1584` |
| Scheduled skip: decision `:667-702`, plan `:706-727`, E's skip row `:1969-1977` | observation; `cash`, `positions`; `instrument_ids` | decision with nothing to trade; empty plan; staged `scheduled_skip` and `marked` rows |
| Stop installation `ledgr_fold_apply_stop` `R/fold-phase-contract.R:197-210` | fold state; stop result | `status`, `stop_reason`, `affected_exposure`, staged rows, `processed`; validation condition |
| Pulse flush `ledgr_fold_flush_pulse_block` `R/fold-engine.R:268-294` | `pending_segments`, `diagnostic_seq`; `run_id`, `ts` | the drained block and the `keep`, `append_block`, `record_coverage` calls; reset staging; new `diagnostic_seq` |
| Lot kernel `ledgr_lot_apply` `R/lot-accounting.R:402` | book; lot input | book and applied rows, or a condition (Section 11) |
| Bar hydration (Section 12.2) | snapshot handle, universe, start and end | the bars frame: rows, column types and order |
| Substrate `ledgr_history_substrate` `R/history-substrate.R:1499` | bars, IDs, axis, facts, config, hash, start, clock kind | the substrate list without `history_memo` and `feature_projection`, which are compared through the reads |
| Feature series `ledgr_history_compute_feature_series` `R/history-features.R:447` | substrate, definitions, calculation start and end | value matrices and the `ledgr_feature_planes` attribute |
| Fold-reader packets `ledgr_history_substrate_fold_reader` `R/history-substrate.R:488-537` | substrate; pulses; features; aliases | `pulse_columns`; `bars(pulse_idx)` current and next packets per pulse; `view(pulse_idx)` cutoff |
| History reads (`R/history-frame.R:969-1227`, `:1479`) | view; request (kind, name, lookback, instruments, `min_observations`, `min_instruments`, layout); the context's decision planes | the returned frame or matrix: values, classes, names, dimnames and metadata (`:1198-1217`), or the request's condition |

## 15. Observable-data notes

These six notes mark where a later data contract would extend the design
([observable-data synthesis](../rfc/rfc_lean_core_observable_data_v0_2_3_synthesis.md)
Section 2). They add no field, placeholder or descriptor.

1. Prepared values and evidence (Section 12.1 bar planes): today numeric
   OHLCV and an observed mask; a later data contract may extend this owner.
2. Identity and axes (Section 12.1 `instrument_ids`, `axis`): a market-level
   series must not acquire execution semantics to fit the instrument axis.
3. Feature input and output (Section 12.2): the input frame names OHLCV
   (`R/history-features.R:230`); later dependencies extend here.
4. P1 packets and the read service (Section 10 decision data, Section 12.1
   read service and view): a contracted extension stays possible without
   making the valuation packet a bag of readable data.
5. P2's strategy context (Section 9 P2 fields): today's `ctx` is not a
   general external-data accessor (`R/pulse-context.R:100`, `:166`).
6. History requests and admission (Section 12.2 reads): bar or feature
   requests with numeric finite-value admission stay as contracted.

## 16. Fixed boundaries and the five-scenario check

The fixed boundaries of the [core extension architecture](../rfc/rfc_core_extension_architecture_v0_2_3_synthesis.md)
(Section 2), as this checkpoint keeps them:

| Boundary | How the checkpoint keeps it |
| --- | --- |
| One fold | Lean code lives in `dev/lean_core/`; nothing in `R/` calls it; no mode branch. Run and sweep both call `ledgr_execute_fold` (`R/backtest-runner.R:847`, `R/sweep.R:1827`). |
| Strategy | Untouched; the recorder observes the callback and its return check from outside (`R/fold-engine.R:821-836`, `:868`). |
| Causality and trust | Tiles load only through the verified snapshot handle (`R/history-substrate.R:313`); P1 stays the only reader of prepared data (`R/fold-engine.R:305-308`); history reads keep the cutoff and vintage rules (`R/history-frame.R:207`, `:257`). |
| Accounting | One kernel arithmetic with the same refusals; cash stays a separate ordered scan (`R/lot-accounting.R:263-271`). |
| Ownership, publication and reads | Copy on modify (`R/lot-accounting.R:677-687`); retained views are copies that tiles never write; P4's install-then-publish order (`R/fold-engine.R:1478-1495`) is recorded and compared. |

Affected-owner check for this checkpoint's three pieces (preparation, lot
kernel, recorder):

| Scenario | Owners it would change elsewhere | This checkpoint |
| --- | --- | --- |
| Order management (OMS) | P3 planning, order state in E, P4 batching, lifecycle publication in P4/P5 | No change. The kernel keeps blocks of distinct instruments and never merges repeated rows (`R/lot-accounting.R:735-742`); no lifecycle field. |
| Other order types | P3 fill resolution; preparation and P1 execution slices | Tiles keep every OHLCV plane and the next-bar packet (`R/fold-engine.R:620-628`); no order-type field. |
| Short selling and leverage | P2 and P3 policy; financing publication | Signed lots and openings stay (`R/lot-accounting.R:321-328`); the kernel keeps today's arithmetic and refusals. |
| Other asset classes | preparation terms; valuation, sizing and settlement functions | No per-instrument term or constant is added to the substrate (`R/history-substrate.R:1590-1618`); any kernel change takes its own contract. |
| New observable data kinds | ingest and identity, preparation, feature functions, P1, P2's context | The six notes of Section 15 mark these owners; tiles store today's numeric planes only (`R/history-substrate.R:422-461`). |

## 17. `dev/lean_core/` layout and loading

```text
dev/lean_core/
  README.md       how to load, capture, replay and compare
  load.R          lean_core_load(lib): pinned build plus lean environment
  recorder/       LDG-3212: capture.R, compare.R, replay.R, run.R, check.R, omissions.R
  fifo.R          LDG-3213 lean kernel
  prepare.R       LDG-3216 tile preparation
  parity/         family runners (FIFO, preparation)
```

`lean_core_load(lib)`:
1. Loads ledgr from the installed pinned library and refuses unless the
   library's `LEDGR_INSTALLED_FROM_COMMIT` is `d5b3a151` and ledgr loaded
   from it (the entry record's `ws16_load_installed`).
2. Sources the lean files into one environment whose parent is the ledgr
   namespace. Lean code can therefore call existing validators and functions
   by name, and writes nothing into the namespace.
3. `lean_core_load(lib, debug = FALSE)`: `debug = TRUE` runs every internal
   assertion. The parity runners run both settings and pass the setting to
   their workers explicitly (pulse plumbing R1); it is not a public option.

The test-suite capture loads the pinned source archive with `pkgload`
instead (`LEDGR_SOURCE_COMMIT`). Captures go to a directory the caller names;
private captures stay on E:, and only manifests of counts and digests are
committed. `dev/` is excluded from the package (`.Rbuildignore` `^dev(/|$)`).
