# Synthesis: Typed Fold Carrier For v0.2.3

Role: record; decision synthesis, binding in its stated scope once accepted.
Status: ACCEPTED by the maintainer 2026-10-30, after Type 1 final review
PASS_AFTER_PATCHES (Claude) with P1-P3 applied in place; binding pending
WS4a scope; not implemented.
Mode: Decision synthesis, RFC cycle stage 7. Author: Codex (response author).
Date: 2026-10-30. Brief: drafted by Claude for, and owned by, the maintainer.
Baseline: `a86dbc228dae312129da31a6f872d294c00ad57d`; `R/` and contracts have
no diff from seed v2's `99567ad8`. No new measurement accompanies this record.
Inputs: seed v1, response v1 and seed v2, including its Section 1 rulings.
Citation aliases (paths relative to the repository):
- **V1**, **Response**, **V2**: `inst/design/rfc/rfc_typed_fold_carrier_v0_2_3_seed.md`,
  `rfc_typed_fold_carrier_v0_2_3_response.md`, `rfc_typed_fold_carrier_v0_2_3_seed_v2.md`, respectively, in that directory.
- **Phase**: `inst/design/rfc/rfc_fold_execution_phase_ownership_v0_2_2_synthesis.md`.
- **Accounting**: `inst/design/rfc/rfc_typed_accounting_event_boundary_v0_2_3_synthesis.md`.
- **Authoring**: `inst/design/rfc/rfc_strategy_authoring_api_v0_2_3_synthesis.md`.
- **Macro**: `inst/design/ledgr_v0_2_3_spec_packet/macro_plan.md`.
- **Style**: `inst/design/manual/optimization_coding_style.qmd`.

## 1. Corrections The Synthesis Author Owes

1. **Withdraw Response F2's padded run-axis targets.** Accept V2:48-54's
   context-axis resolution. Validation already returns context order and
   actionable indices address it (`R/strategy-contracts.R:55-100`;
   `R/fold-engine.R:1063-1068`). Explicit axes plus `context_pos` provide the
   required alignment without padding. No missing target becomes zero or `NA`.
2. **Correct V2:199-201, not the no-lookahead rule.** P1 alone reads the
   availability substrate (`inst/design/contracts.md:135-140`). It currently
   obtains current and next bars and passes next bars to P3
   (`R/fold-engine.R:281-289,1094`; `R/history-substrate.R:394-417`). Bind two
   separate P1 outputs: a decision packet and a private execution packet.
   P3 gets primitive columns, never a new substrate reader; P2 gets no next bars.
3. **Correct V2:268-271's attribution of rollback to Phase.** Canonical P4
   installs lots before publication, then advances sequence and updates cash;
   compiled P4 installs state before append (`R/fold-engine.R:1324-1399`).
   Phase:197-219 does not promise rollback of the fold environment on every
   error. Section 3.5 explicitly defines the batching amendment and failure
   boundary; it does not invent a new in-memory transaction engine.
4. **Do not erase unpriced provenance.** V2:349's blanket `NA` is wrong:
   an expired unpriced mark retains age and source `expired_close`; missing
   history has source `missing` (`R/availability-economics.R:110-144`).
   Preserve each field independently, including reference, source time and frozen.
5. **Do not equate final pulse with missing execution time** (V2:254).
   A continued carry window can execute beyond its last decision pulse
   (`R/history-substrate.R:400-412`). Preserve the prepared opportunity sentinel.
6. **Complete V2's table and JSON routing.** Add publication/effects, leg,
   intent, stop and timing groups; retain state/intent serialization under
   their existing owners (Macro:227-280). The live state slot census has no
   equity slot (`R/fold-phase-contract.R:1-21`); adding it is explicit below,
   not an assertion that the implementation's slot set already includes it.

## 2. Decision

Adopt seed v2 with Section 1 corrections: positional typed columns, one R lot
implementation, columnar publication and bounded diagnostics, within E/P1-P5.
Acceptance is not implementation (Macro:181-223; `inst/design/README.md:35-51`).

Economics, canonical event order, ledger `meta_json`, equity, strategy state
and retained diagnostics remain byte-identical. Lots alone determine positions.
There is no schema/public API change, new execution-mode branch, or compiled
default. Canonical R remains the normative executable oracle
(`inst/design/contracts.md:104-126,345-390`; Accounting:92-102).

**Q1 and Q6 stand:** dense joins at the normalized decision; its observation
and context construction are frozen. WS4a owns both equity representations,
including shape-audit P4 formerly routed to WS4b (V1:360-383). The acceptance
step reconciles that macro-plan routing. WS4a and WS4b are adjacent release-ready
cuts, with carrier acceptance before consolidation (Macro:183-226; V2:463-467).

**Identity/release:** no snapshot/configuration/store identity or dependency
change. Supply tests, performance records, internal contracts and one NEWS
entry; preserve public examples and registered oracles (Macro:42-51; V2:430-436).

## 3. Bound Architecture

### 3.1 Axes, ownership and validation

The fixed run axis is `execution$instrument_ids`. Context columns are in the
provider's decision order, including held nonmembers; `context_pos[k]` maps
that order onto run positions (`R/availability-provider-prepared.R:517-542`).
Dense uses identity mapping at P2 exit. Fill/rejection rows carry `k` and
`pos = context_pos[k]`; neither row index is silently used as an instrument index.

E locks the fold environment. Retype positions, lots and pending segments;
add `equity_facts` and remove the separate accumulator. Other slots/owners stay.
This implements Phase:225-236's ownership, changing the actual census at
`R/fold-phase-contract.R:1-21,164-189`. Handler/writer buffers remain services.

Validate types, exact lengths, bounds and dictionaries when constructing each
group; extend the fold-state validator at E and stop application. Validate new
properties introduced by callbacks, alignment and deserialization, not each
read (Style:173-181,229-240; `R/fold-phase-contract.R:73-122`). Lot/transition
checks and current classed refusals survive. No all-book rescan per field read.

Named adapters cover E import/replay, P2 input/return, publication/results and
transitional provider/valuation, corporate-action and compiled boundaries.
P3's `execution_view` is a declared service, not a history read
(Phase:253-266; `R/availability-economics.R:417-420`). Code names each adapter
and its downstream owner; no ad hoc name lookup enters a positional kernel.

The fold owns state and transient batches; handler owns event/leg retention;
diagnostic writer owns bounded chunks. Mutable buffers are exclusive. Public
views, corporate-action inputs, checkpoints, compiled inputs and returned
values are copied or never written again. The lot kernel starts with ordinary
copy-on-modify; changing this requires scale evidence and a cut ownership proof
(Style:157-172; V2:182-184). Candidates/workers never share mutable books.

### 3.2 P1 observation and P2 decision

P1 keeps cash settlement, scheduled disposition, lifetime resolution,
re-observation, valuation and equity order (Phase:146-171). Convert provider/
valuation outputs once per produced view, reusing its mapping; do not rewrite
their internals. Preserve run-order valuation reductions, even though the
returned packet is context-aligned (`R/fold-engine.R:557-608`).

P1 separates current decision data and cutoff-bound feature/history access
from next-bar OHLCV. P2 receives only the former. A source locator must name
both its row and prepared pulse column; a row alone is not a time boundary.
Existing lazy history access stays cutoff-bound and P2-local; WS4a does not
implement WS5's flat public context or WS6's frame retirement
(`R/history-substrate.R:382-417`; Authoring:51-87; Macro:253-284).

Normalize the strategy return once, on the complete context axis. Apply risk
on those columns; validate the compiled plan once in E, but retain dynamic
mark/equity and transformed-property checks. Remove duplicate target shape/
name normalization, not risk/short-exposure semantics
(`R/fold-engine.R:872-990`; `R/risk-model.R:381-489`). Carry raw state updates
to P5 without earlier normalization. Intent retains its present diagnostic
placement. Scheduled skips invoke neither strategy nor P3 planning, but still
settle, value, bind the next boundary and commit (Phase:175-184;
`inst/design/contracts.md:141-156`; `R/fold-engine.R:632-675`).

### 3.3 P3 planning and costs

One candidate row per actionable context ordinal. Vectorize cost steps in
their compiled order; preserve spread-adjusted unrounded notional fees and
last-step rounding (`R/cost-model.R:407-420`; contract-execution-cost-model,
`inst/design/contracts.md:406-418`). Compute both publication effects once via
`ledgr_fill_publication_deltas()` and reuse them; no sink recomputes economics.
Construction validates execution epochs from the prepared opportunity axis,
without per-fill timestamp parsing.

Affordability has its own ordered scan: unblocked cash-generating reductions
first, then the remaining rows, each in radix stable-ID order. Keep acceptance
mask and permutation private to P3. Compact accepted rows into decision order;
keep early rejections followed by affordability rejections. Preserve the two
cash reconciliation calculations and tolerance, including their existing
`sum` expressions; reusing `cash_delta` does not license replacing a reduction
with an ordered scan (`R/availability-economics.R:344-388,513-516`;
`R/fold-engine.R:1140-1168,1445-1483`; contract-availability-affordability).

Planned after-position remains diagnostic evidence; actual position is produced
only by lots. Reasons are ordered, deduplicated code segments, with the first
code producing the primary reason. Dictionaries preserve existing tokens;
no bit-mask ordering or vocabulary change (`R/availability-economics.R:334-341`;
`R/fold-engine.R:1171-1270`). Empty plans declare no economic kinds; unsupported
kinds still refuse before mutation (`R/fold-engine.R:205-234`).

### 3.4 One typed lot implementation, including replay

Use flat segments and cached lot-derived aggregates. Consume FIFO sequentially
within each instrument and vectorize across distinct instruments. Compact/grow
by gather; ordered total-basis and Kahan updates retain scalar event order,
not `sum`/`cumsum` (`dev/spikes/ws4a-carrier-probe/typed-lots.R:27-99`).
This is a justified sequential semantic under Style:201-222.

Name the operations **opening**, **fill**, **disposition**: a fill can open,
close or reverse, so V2's name `close` is misleading. Opening appends signed
quantity and finite basis of either sign, without cash or Kahan updates.
Fill preserves dust, fees and reversal arithmetic. Disposition has zero fee,
may close at zero price, and must exhaust live lots; replay checks the existing
realized-model witness at dust tolerance (`R/lot-accounting.R:147-179,239-389,447-487`).
Cash is a separate event-order scan of already computed effects; replay adds
published effects exactly once (`R/accounting-replay.R:296-328`).

Distinct instruments is a kernel-call precondition, not an event-stream rule.
Use consecutive conflict-free blocks without reordering; repeated carried
openings remain successive transitions (`R/fold-event-buffer.R:120-124`).
P4's fills form one block; P1 dispositions retain their own barriers and
duplicate refusal (`R/terminal-outcomes.R:149-153`; `R/fold-engine.R:389-418`).

Delete the old named-list FIFO implementation; replay and opening/resume
initialization use the same typed operations. Keep current metadata preparation
and semantic checks, projecting typed scalar inputs at its boundary. Singleton
replay is allowed only if the cut gate passes; otherwise use consecutive
blocks through the same implementation. No second FIFO survives until WS7.
Compiled pack AND unpack gather typed lots and preserve aggregate/Kahan state;
the C++ and its opt-in envelope remain unchanged
(`R/compiled-spot-fifo.R:104-165,223-247`; Accounting:152-211).

### 3.5 P4 application, publication and failure boundary

Bind the next corporate-action entitlement boundary before fills. Compute the
canonical candidate lot block and ordered effect results without mutating
owned state. A calculation/validation failure here leaves state and output
buffers unchanged. Then install the candidate book, publish/stage its event
block, advance sequence, record leg/accounting columns, and install positions
and cash. This explicitly replaces Phase:199-203's per-fill interleaving with
the same ordering of steps per block; all per-event facts remain available.
It is a batching change, not a claim that the old implementation was atomic
at pulse scope (`R/fold-engine.R:1303-1399`).

A failure during append/flush still aborts: durable rollback covers the whole
invocation; a failed memory candidate exposes no successful partial result.
No promise is made that already-mutated private state/buffers are restored
after a handler error. Preserve condition classes, diagnostic stage and
checkpoint/interrupt behavior; compiled state-before-append order stays
(Phase:208-219; `R/output-handler.R:659-706`; `R/fold-engine.R:2055-2081`).
The early-failure gate is therefore about candidate calculation; separate
append/flush injection gates verify the existing abort/rollback contract.

Publish fills as columns; format event IDs for a whole block. P1 non-fill
builders retain append/mutation order and adapt once into the indexed sink,
never wait until P4/P5. Keep `meta_json` bytes, memory `meta` and aggregate
auxiliaries, and canonical leg-fee arithmetic. WS4a imports none of Accounting's
DDL, new evidence validator, fallback deletions or public readers
(Phase:158-165; Accounting:75-90,152-227; `R/output-handler.R:520-600`).

### 3.6 Diagnostics, equity and P5

Stages write typed pulse staging in emission order, reset after P5 or E stop
drainage. Reserve a conservative pulse bound from axis size and known producer
counts; use indexed slices and a used-row count, never replay the strategy to
discover counts. The existing writer splits oversized blocks into bounded
chunks and replaces flushed buffers (`R/availability-diagnostic-writer.R:94-171`).
No run-long staging or second writer. WS4a builds the full logical trace and
retains today's sink filter/sequence gaps; selective materialization is WS4b
(`R/output-handler.R:353-377`; V2:302-314).

P1 writes one five-column equity record per valued pulse, preallocated to the
fold's pulse count with a used-row count. E hands a frozen completed prefix
to finalization and the handler's existing inline summary. Do not replay
equity for the memory sink. This replaces both current accumulators, retains
early-stop prefixes and distinguishes last-valued from last-executed time
(`R/fold-engine.R:574-591,2094`; `R/output-handler.R:285-314`;
`inst/design/contracts.md:2657-2665`; Accounting:207-211). Both producers
fill the record; finalization still selects its equity source by producer,
not by record length: availability uses the fold record, dense durable runs
keep event replay (`R/run-finalize.R:449-453,526-530`).

P5 preserves flush, reconciliation, state normalization/persistence, progress,
telemetry and checkpoint order. E alone installs typed stop results; retain
which stops count a processed pulse (Phase:208-219,275-285). Stop class and
opaque affected exposure stay; stop diagnostics use the same staging schema.
Telemetry retains its present typed arrays (`R/fold-engine.R:1533-1558`).

## 4. Carrier Contract

Types: D double, I integer, L logical, C character. Epoch = UTC seconds;
money = existing accounting currency (USD here), units = signed instrument
quantity. Same-group columns have exactly their declared axis length; empty
groups have typed length-zero columns and `n=0`. Owners shown as stage/lifetime.
Constructors reference this table; read-only handles grant no P3-P5 substrate access.

| Group | Columns | Type; axis; unit | Invariant / missingness | Writer; lifetime |
| --- | --- | --- | --- | --- |
| state | cash; positions | D scalar; D run; money/units | finite; positions equal lot-derived net | E/P1/P4; run |
| state | event_seq; diagnostic_seq | I scalar; sequence | next event >=1; diagnostic last assigned >=0 | E/P1/P4; E/P5; run |
| state | state_prev; state_axis | opaque; C context IDs or NULL | existing normalization/axis lifecycle | E/P1/P5; run |
| state | status, stop_reason, current_stage | C scalar | existing tokens; stop_reason may be NA | E/stage owner; run |
| state | affected_exposure | opaque list | existing value/details/time/specified | E; run |
| state | processed, telemetry_idx; full_run | I scalar; L scalar | nonnegative counts; nonmissing flag | E/P5; run |
| state | last_fully_valued, last_executed, current_ts | existing POSIXct scalars; UTC | existing NA/initial sentinels; distinct clocks | E/P1/P5/current stage; run |
| state | frozen_set | C IDs | existing frozen transition set | P1; run |
| state | pending_segments; equity_facts | typed diagnostic/equity groups below | no duplicate writer/service buffer | stages/P1; pulse/run |
| book | offset, capacity; head, tail | I run; slot/count | disjoint prefix segments; empty head/tail=1/0; live bounds valid | E/P1/P4; run |
| book | lot_qty, lot_price | D allocated slot; units, money/unit | live finite; dead NA; FIFO order | E/P1/P4; run |
| book | net_by_inst, cost_basis_by_inst | D run; units, money | lot-derived with canonical dust, not reduction recomputation | E/P1/P4; run |
| book | total_cost_basis, realized_pnl, realized_comp | D scalar; money | canonical ordered basis/Kahan updates | E/P1/P4; run |
| decision packet | pulse_idx, ts; context_pos | I/D scalars; I context; index/epoch/index | valid pulse; unique run positions; empty context allowed | P1; through P5 |
| decision packet | cash, positions_value; position | D scalar; D context; money/units | copied after settlement; valuation reduction retains run order | P1; through P5 |
| decision packet | member, held, buyable, target_restricted | L context; flags | authoritative provider planes, no NA; buyable implies member | P1 adapter; through P5 |
| decision packet | restriction_offset, restriction_count, restriction_code | I context/context/code; index/count/code | ordered reason segment; primary first | P1 adapter; through P5 |
| decision packet | status, lifetime; terminal_event, lifetime_fact_id | I codes; C context | preserve provider vocabulary and empty strings | P1 adapter; through P2 |
| decision packet | mark, reference, source_ts; mark_age, mark_source | D context; I context; money/unit, epoch, sessions, code | missing mark does not erase age/source/reference | P1 adapter; through P5 |
| decision packet | priced, permissible, frozen | L context; flags | preserve valuation flags independently | P1 adapter; through P5 |
| decision data | open, high, low, close, volume, observed | D/L context; price/units/flag | current-bar missing cells retained; no future columns | P1; P2 |
| decision data | source_row, source_column; feature locator/handle | I context/I scalar; existing cutoff-bound handle | indexes prepared current data; feature handles immutable to fold | P1; P2 only |
| execution packet | exec_ts, has_next; open, high, low, close, volume | D/L scalar; D run; epoch/flag/price/units | absence explicit; continuation opportunity preserved | P1; P3 only |
| execution view | member, restricted; reason_offset/count/code | L candidate; I segments | current provider execution cutoff; private P3 adapter | P3; P3 |
| decision | strategy_qty, target_qty; actionable_k | D context; I actionable; units/index | full finite targets; ordered context ordinals with abs(delta)>sqrt(eps) | P2; P5 |
| decision | state_update; intent_reason | opaque; C scalar or NULL | NULL carries state; intent existing validation/placement | P2; P5 |
| plan | accepted, afford_order; expected_final_cash | L/I candidate; D scalar; flag/index/money | priority scan only; dense field unused, skip equals cash | P3; locals/P5 |
| plan | economic_event_kinds | I kind codes | empty or supported declared kinds; fail closed otherwise | P3; P4 |
| fill | k, pos, side | I fill; index/sign | pos=context_pos[k]; distinct pos; side +/-1; decision order | P3; P5 |
| fill | qty, price, fee, cash_delta, position_delta, exec_ts | D fill; units, price, money, money, units, epoch | valid resolved values; effects computed once | P3; P5 |
| fill | position_before, planned_position_after | D fill; units | planned diagnostic evidence, never position authority | P3; P5 |
| fill | info_offset, info_count, info_code | I fill/fill/code | ordered deduplicated informational reasons | P3; P5 |
| rejection | k, pos, emit; reason_offset/count/code | I rejection; I segments | early then affordability order; primary reason first | P3; P5 |
| rejection | resolved_price, exec_ts, position | D rejection; price/epoch/units | only unresolved price/absent opportunity NA; position finite | P3; P5 |
| lot input | operation, pos, side; qty, price, fee, position_before, realized_model_pnl | I/D operation row; code/index/sign/units/price/money | Section 3.4 per-kind rules; opening qty signed; replay disposition witnesses required, production computes realized witness | E/P1/P4/preparer; kernel call |
| applied row | position_before, position_after; close_qty, open_qty | D operation row; units | actual from lots; open/close zero when inapplicable | E/P1/P4/replay; caller boundary |
| applied row | realized_close, realized_delta, event_realized, event_cost_basis | D operation row; money | per-event facts in order; opening does no Kahan step | lot implementation; caller boundary |
| publication | event_id, run_id, event_type, instrument_id, side | C event; identifier/token | current output tokens/nullability, generated in blocks | handler boundary; retained output |
| publication | ts_utc, qty, price, fee, event_seq, cash_delta, position_delta | D/I event; epoch/units/price/money/sequence/effects | common current fields/effects; contiguous fill seq | P4/handler; retained output |
| publication | meta_json; meta; event_realized, event_cost_basis | C; list; D event | existing sink-specific bytes/auxiliaries, routed to WS8 | handler; retained output |
| leg | event_seq; instrument_id, side, action | I/C leg; sequence/IDs/tokens | CLOSE then OPEN when both exist | P4/handler; retained output |
| leg | ts_utc, qty, price, fee, realized_pnl | D leg; epoch/units/price/money/money | canonical leg fee split; opening leg PnL=0 | P4/handler; retained output |
| diagnostics | run_id, instrument_id, stage, outcome, reason_code, reasons, mark_source, feature_identity_json, detail_json | C diagnostic | exact existing strings/defaults; routed JSON unchanged | P1-P5; E/P5 drain |
| diagnostics | diagnostic_seq, mark_age, event_seq | I diagnostic | existing NA defaults; logical sequence includes dropped rows | stages/E/P5; drain |
| diagnostics | ts_utc, decision_ts_utc, execution_ts_utc | D diagnostic; epoch | decision defaults to pulse; absent execution NA | stages; drain |
| diagnostics | target, quantity, price, target_before_risk, target_after_risk, position_before, position_after | D diagnostic; units/price | existing per-stage planned/actual meanings and NA defaults | stages; drain |
| diagnostics | n, capacity | I scalar; rows | used prefix <= pulse-bound capacity; reset on drain | stages; pulse |
| equity | ts, cash, positions_value, realized_pnl, cost_basis; n | D pulse; I scalar; epoch/money/count | only first n valued rows valid; capacity=pulse count | P1; frozen E handoff |
| stop | status, reason_code, affected_instrument_ids; affected_exposure; counts_processed; diagnostics | C; opaque; L scalar; typed block | existing class, stage-specific count and exposure semantics | P1/P2/P3; E applies once |
| timing | sample_start; t_feats, t_bars, t_ctx, t_strat, t_target, t_fill, t_event, t_state | existing clock scalar; D scalar seconds | transient stage measurements | owning stage; P5 |
| telemetry | t_pulse, t_bars, t_ctx, t_fill, t_state, t_feats, t_strat, t_target, t_event, t_exec | D sample; seconds | current sample indexing and totals unchanged | P5/E; run |

Producer scope (Q1): dense emits `decision` onward plus state, book, equity,
diagnostics, publication and leg; it emits no decision packet, decision data,
execution packet or execution view, and its P3 reads `bars_mat` at
`pulse_idx + 1` (`R/fold-engine.R:150-156`) until WS4b removes it.
Defaults: `R/availability-diagnostic-writer.R:35-91`; legs: `R/output-handler.R:204-214,803-813`.
POSIXct materializes at output boundaries. Existing scalar state/stop/timing
types remain exceptions (`R/fold-phase-contract.R:23-157`). The cut pins code
dictionaries and feature locators without changing their semantics.

## 5. Evidence Before The Cut And Before Deletion

Existing evidence supports typed R on the measured shape: 27.17/27.07 us/fill
wide/partial, not a universal limit (`dev/spikes/ws4a-carrier-probe/typed_lots_findings.md:5-23`).
Fixed-fee identity exists; chained-cost identity and non-fill typed operations
do not. Only LIFO was mutated through the typed arm; reorder/drop-fee used native
(`dev/spikes/ws4a-carrier-probe/typed-check.R:19-43`; `typed-lots.R:103-119`).
Rprofmem is cumulative R allocation, not peak live memory or native allocation
(`dev/spikes/ws4a-carrier-probe/probe_findings.md:44-48`). No new timing is claimed.

Before cut acceptance, run every proposed oracle/checker on unchanged base,
register cases and thresholds, and settle baseline surprises (Macro:63-77).
Before deleting old paths, require the following evidence on the implementation:

| Claim | Required detection / result |
| --- | --- |
| Exact successful outputs | A0, WS3 dense lane, v0.2.2 real-data reference: ledger/JSON, equity, strategy state, retained diagnostics/sequence gaps and logical live FIFO/aggregates identical (V2:379-400). |
| Cost and lot semantics | Both sides with chained spread/fixed/notional fees, rounding edges, fractional dust, dense short reversal, repeated carried openings, zero-price dispositions and corporate cash; unchanged bytes. |
| Axis and clocks | Reordered/changing context, held nonmember, empty context, scheduled skips, unpriced/expired/frozen marks and continued final-window execution preserve outputs and no-lookahead. |
| Lifecycle/ownership | Stops, resume, carry windows, retained ctx/state, candidate/worker isolation and compiled pack/unpack; same economic prefixes and no alias mutation. |
| Mutation strength | Typed-path LIFO, reordered publication, dropped fee and affordability-order publication fail identity; an opening Kahan call fails an invocation detector, with nonzero-compensation preservation also checked. |
| Failure boundary | Candidate error leaves state/buffers unchanged; append/flush error aborts, durable writes roll back, memory yields no successful partial result; existing condition/stage evidence preserved. |
| Representation | Detect per-fill lists, run-long/list-grown diagnostics, kernel name lookups, duplicate target normalization and unrouted hot JSON; a structural detector shows P2's input carries no execution-packet field, and a mutation passing one fails; cold reader explains every changed stage from Section 4 and code (Macro:78-92). |
| Dense finalization | A durable dense run still finalizes equity through event replay, byte-identical, although its fold equity record is filled. |
| Timing/allocation | Shared `dev/bench/timing/` alternating pairs for no-fill/sparse/wide on both producers; replay separately; no hidden singleton-copy regression. |
| Scale | >=5,000 instruments and fills consuming >10 lots; report cumulative Rprofmem and peak live memory including book growth and replay; bounded diagnostic storage. |

Cut defaults: availability wide sweep marginal <=40 us/fill; durable wide
<=60% of base; no-fill and replay have no regression beyond the predeclared
noise band. Wide allocated bytes/fill must not exceed base (V1:400-415).
The cut may revise numeric timing bounds with baseline/noise evidence before
acceptance, never after seeing implementation failure. It must fix a peak-memory
budget and replay threshold before choosing singleton/blocking or by-reference
ownership. Reuse settled probe effects rather than rerun a new A/A exercise.
No registered fixture/oracle is weakened: any mechanical book-layout comparison
change has a separately stated representation reason and preserves the old
logical witness; container layout is not an economics oracle (Response:255-263).

## 6. Rejected Items

- Run-axis padded targets: context alignment eliminates padding and matches validation (Section 1).
- Native default or native-resident books: outside WS4a and unsupported by a necessity claim (Section 2).
- A second FIFO until WS7: one typed implementation serves replay now (Section 3.4).
- Calling all lot operations fills/closes: opening and disposition have distinct arithmetic/checks (Section 3.4).
- Position deltas or planned after-position as authority: lots alone determine actual positions (Section 3.3).
- Affordability-order publication or unordered reason masks: changes canonical evidence (Section 3.3).
- P3 history reads or next bars in public ctx: violates the existing history/no-lookahead boundary (Section 1).
- Whole-stream distinct instruments: repeated carried openings are valid (Section 3.4).
- Blanket trace skipping or run-long staging: loses retained evidence or the memory bound (Section 3.6).
- Full in-memory rollback on every P4 error: not Phase's contract; no new transaction engine (Section 3.5).
- WS8 schema/validator/fallback changes now: violates WS4a's identity and scope boundary (Section 3.5).

## 7. Open Questions Promoted To The Cut

The cut settles singleton/blocked replay within Section 5 thresholds, code
assignments, feature locators, pulse capacity, timing/noise and memory budgets,
and detector names, with checked evidence before acceptance. Axes, ownership,
stage access, operations, publication order and failure semantics are settled.

## 8. Future Obligations

WS4b removes provider/valuation adapters, owns selective diagnostics after
retained-row/sequence parity, and removes H5 reconciliation JSON. WS4b/WS5
divide state normalization/serialization; WS5 owns intent JSON and typed
declared state, WS6 context frames
(Macro:227-280; `dev/spikes/json-hot-path-audit/audit.md:13-16`).
WS7/WS8 own metadata preparation/read architecture, non-fill builders/evidence,
fill and non-fill JSON, memory meta/aggregate auxiliaries and the store change
(Accounting:175-227). These are explicit rule-14 routes, including db_live;
cold stop/exception records retain current encoding. The JSON cache retires
with its last hot caller, not prematurely (Macro:237-243).
The compiled-envelope RFC owns native-resident state. WS5 D2 consumes actual
event-kind/position transitions and recording-bar provenance; WS4a adds no D2
slots or strategy-state schema (Authoring:89-131,247-297).

## 9. Failure Scenarios And Release Boundary

| Scenario | Required result |
| --- | --- |
| Context reordered while run axis stays fixed | Map via context_pos; neither wrong asset nor silent missing target. |
| Buy before funding sell in decision order | Affordability may accept both; publish in decision order, preserving ordered cash and reconciliation. |
| Unpriced expired holding or disposition followed by fill | Preserve mark evidence and P1 barriers; stop/dispose/reobserve under existing policy. |
| Repeated opening lot with residual Kahan compensation | Append each lot in order; do not manufacture realized-P&L updates. |
| Later FIFO row fails; handler append fails | First failure leaves candidate uninstalled; second aborts under Section 3.5, without claiming private-state rollback. |
| Diagnostic pulse exceeds writer chunk; run stops early | Split chunks safely; drain used staging/equity prefixes only, preserve sequences and both clocks. |
| Retained view or compiled input survives another pulse | Its values remain unchanged; no shared-buffer mutation. |

Next: Type 1 final review, maintainer acceptance, then WS4a measure/cut/review/
implement. Acceptance reconciles Q6 routing; closure promotes implemented rules
into contracts. This draft records no maintainer acceptance (Macro:21-24,31-51).

## Revision History

- 2026-10-30, Claude, after the Type 1 final review
  (`rfc_typed_fold_carrier_v0_2_3_final_review.md`): P1 keeps finalization's
  equity source keyed on producer (Section 3.6, Section 5 row); P2 adds the
  producer-scope line under Section 4; P3 adds the P2 next-bar detector to
  Section 5. No other text changed.
