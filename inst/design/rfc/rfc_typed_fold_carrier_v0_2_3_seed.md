# RFC Seed: Typed Fold Carrier for v0.2.3

- Status: Seed v1. Type 2 response by Codex is next.
- Author: Claude
- Date: 2026-10-30
- Target window: v0.2.3, WS4a, before its cut
- Baseline reviewed: `release/v0.2.3` at `16e8252d`
- Evidence: WS4a carrier probe (`dev/spikes/ws4a-carrier-probe/`, `7d14ebe0`
  and the typed-lots arm `5555f9e8`); shape audit
  (`dev/spikes/shape-audit/audit.md`); JSON audit
  (`dev/spikes/json-hot-path-audit/audit.md`); PMwR probe
  (`dev/spikes/pmwr-performance/`)
- Binding inputs: macro plan WS4a and rules 14-15; fold-phase synthesis
  (`rfc_fold_execution_phase_ownership_v0_2_2_synthesis.md`); typed-accounting
  synthesis (`rfc_typed_accounting_event_boundary_v0_2_3_synthesis.md`);
  strategy-authoring synthesis D1, D2 and D5;
  `manual/optimization_coding_style.qmd`, Rules

## 1. Question and Boundary

What fixed, typed representation should carry one pulse through the fold's
stages? It should do three things:

- both current producers emit it;
- per-fill R work becomes per-pulse vector work;
- the canonical R path stays the readable oracle.

The fold-phase synthesis already binds the stage structure: envelope E, then
P1 observe and settle, P2 decide, P3 plan, P4 apply, P5 commit. It also binds
one locked fold-state environment and the declared run services. This seed
keeps all of that. It types the slots and the values passed between stages.

**In scope:** fold-owned state, the lot book and its kernel, the observation
record (P1 to P2), the normalized decision (P2 to P3), the fill and rejection
batch (P3 to P4), the event batch and its buffer (P4 to the sink), the
diagnostic batch, the equity record, the stop result and telemetry.

**Unchanged:** economics, event order, fill timing, cost semantics, lots as
the only position authority, the public `ctx` and strategy return (WS5),
context frames (WS6), readers and replay (WS7), the persisted schema and
`meta_json` (WS8), the compiled envelope and its RFC, and the per-pulse floor
items the WS4b amendments own. There is no new execution-mode branch.

## 2. What the Probe Settled

Workload: availability producer with complete facts, 500 instruments x 1,260
bars, SMA 5/10, about 67,700 fills, zero costs. Five alternating
fresh-process pairs. Sweep marginals are measured against each arm's own
no-fill floor.

| Arm | Sweep us/fill (wide / partial) | Lot kernel s | Rprofmem GB | Durable run / floor s |
| --- | ---: | ---: | ---: | ---: |
| Base (today) | 226.50 | 2.78 | 7.33 | 25.12 / 8.16 |
| Today's lot code + indexed buffer | 50.50 / 51.20 | 1.78 | 7.46 | 12.71 / 7.67 |
| Native lots + indexed buffer | 24.81 / 23.54 | 0.10 | 6.14 | 10.94 / 7.73 |
| **Typed R lots + indexed buffer** | **27.17 / 27.07** | **0.38 (+0.17 adapter)** | **6.22** | **11.34 / 7.75** |

The base row is from the first probe run; the other three come from the
addendum run on the same protocol.

1. **The per-fill cost was R machinery, not arithmetic.** Per-fill lists, S3
   proposals, name lookups and copies cost about 200 us per fill. Typed
   vectors applied once per pulse remove almost all of it.
2. **Native code is not needed.** It saves about 2.4 us per fill over typed
   R, roughly 0.16 s on this run. That matches the macro plan's non-goal of
   no compiled-default change.
3. **Partial closes do not change the result.** In the partial-heavy variant,
   about half the fills partially close lots, and it costs the same.
4. **The floor dominates afterwards.** A durable run has a 7.7 s floor and
   about 3.6 s of fill work. The floor belongs to WS4b and WS5.
5. **Remaining components** (typed arm, sweep, seconds): plan 0.41, lot
   kernel 0.38, adapter 0.17, payload 0.07, event batch 0.37.
6. **Identity held.** Ledger rows including `meta_json`, equity, strategy
   state and the final book are byte-identical across ten cases. LIFO
   consumption, reordered fills and a dropped fee each fail identity.
7. **Producers differ in timestamps.** Complete facts run on the availability
   producer with identical economics. But availability stamps fills at the
   execution opportunity, 6.5 hours before dense's next-bar stamp.

**Not covered by the probe:**

- non-zero costs;
- more than one strategy shape;
- corporate actions and dispositions under timing;
- deep FIFO books, where one fill consumes many lots;
- universes beyond 500 instruments;
- native allocation (Rprofmem sees only R allocations).

Section 6 turns each into a gate item.

## 3. Proposed Architecture

### 3.1 One axis, names at four boundaries

The run axis is `execution$instrument_ids`, fixed for the run. Every
instrument-indexed column is a vector on it, and instruments inside a stage
are integer positions. The decision axis changes per pulse on the
availability producer. It is carried as `context_pos`, an integer vector of
positions on the run axis, plus masks.

Names are attached or removed in four named helpers only:

1. building `ctx` (P2 entry);
2. normalizing the strategy return (P2 exit);
3. publishing events (the `instrument_id` column, at the sink);
4. the fold return and result boundary.

Today's ad hoc conversions are replaced by these four, for example
`id_to_idx[target_names]` at `R/fold-engine.R:1065`,
`ledgr_fold_positions_snapshot()` (three times per pulse) and the roughly 25
name-indexed reads in decide and commit (shape audit P3, P11, P12).

### 3.2 Fold state

This is the same locked environment and slot set as fold-phase synthesis
Section 5.1, with these changes:

- `positions` becomes an unnamed double vector on the run axis;
- `lot_state` becomes the typed book of Section 3.3;
- `pending_segments` becomes the diagnostic batch of Section 3.8, instead of
  a list grown with `[[length + 1]] <-`;
- `affected_exposure` stays a list, because it is written at most once per
  run.

The validator at `R/fold-phase-contract.R:73-122` checks types and lengths
once, at construction and at stop application. Stages trust it afterwards
(manual, clarity point 3).

### 3.3 The lot book and one lot kernel

The book uses the probe's layout (`dev/spikes/ws4a-carrier-probe/typed-lots.R`):

- per-instrument `offset`, `capacity`, `head` and `tail` integer vectors on
  the run axis;
- flat `lot_qty` and `lot_price` double vectors over allocated lot slots;
- `net_by_inst` and `cost_basis_by_inst` on the run axis;
- three scalars: `total_cost_basis`, `realized_pnl`, `realized_comp`.

**The kernel.** It is one function. It takes a batch whose rows touch
distinct instruments, in canonical event order. It supports three
operations: fill, opening and disposition.

- FIFO depth is consumed in steps, vectorized across instruments.
- Compaction and growth are vectorized gathers.
- Running totals of cash, cost basis and realized P&L stay an ordered loop
  over the batch. `sum()` and `cumsum()` would change floating-point order,
  and byte identity forbids that (`typed-lots.R:85-95`). This loop is a
  sequential semantic, which the base-R rule allows. Its stated reason
  appears in the code.
- Positions are read from `net_by_inst` once per batch, never with
  `positions + delta` (typed-accounting synthesis 3.2).

**One implementation from WS4a on.** The replay
(`R/accounting-replay.R:296-328`) calls the same kernel with batches of one
event until WS7 batches it. `ledgr_lot_apply_fill()`, the named-list
`ledgr_lot_state()` and `ledgr_position_from_lots()` are deleted rather than
kept as a second path. Canonical R remains the normative oracle; the typed
kernel becomes canonical R.

**Position facts (WS5 D2).** WS5 adds two integer bar-index vectors on the
run axis. The kernel returns each row's position before and after, which is
enough to classify entry and exit in event order. WS4a adds no D2 slots.

**Compiled `spot_fifo`.** It is a shipped opt-in. Its adapter packs live
lots from the typed book with one vectorized gather
(`R/compiled-spot-fifo.R:104-166` today loops over instruments) and takes
the fill batch as columns instead of recovering them with `vapply`
(shape audit F10). The C++ code is not edited. Keeping lots native across
pulses stays the compiled-envelope RFC's obligation.

### 3.4 Observation record (P1 to P2)

The record holds:

- `pulse_idx` and `ts` as an epoch;
- `context_pos`;
- `member`, `held` and `buyable` logical vectors on the run axis;
- valuation columns on the run axis: mark, source code, age, priced and
  permissible;
- a copy of positions;
- the next-bar columns for P3.

`ctx` is built from this record by boundary helper 1. Its shape and laziness
belong to WS5.

WS4a does not rewrite the availability provider or the valuation state.
Those are WS4b's floor (amendment P1, P2). A P1 adapter converts their named
outputs into the record once per pulse. That adapter costs one match per
pulse until WS4b removes it, and the cut states this cost.

### 3.5 Normalized decision (P2 to P3)

The strategy return is validated and normalized once
(`R/strategy-contracts.R:34-101`). The risk plan runs on the normalized
vectors, and the post-risk revalidation (`R/risk-model.R:478-489`, shape
audit P10) is deleted. The compiled risk plan is validated once in E, not
per pulse.

The record holds:

- `target_qty`, after risk, on the run axis;
- `strategy_qty`, before risk;
- `actionable_pos`, an integer vector;
- `state_update`, which stays opaque (WS5 owns its typed storage);
- `intent_reason`, which stays as it is today (WS5 owns the typed column).

### 3.6 Fill and rejection batch (P3 to P4)

The fill batch has these columns:

| Column | Type | Meaning |
| --- | --- | --- |
| `pos` | integer | instrument position on the run axis |
| `side` | integer | +1 for a buy, -1 for a sell |
| `qty` | double | quantity |
| `price` | double | fill price |
| `fee` | double | fee |
| `cash_delta` | double | from `ledgr_fill_publication_deltas()`, computed once |
| `exec_ts` | double | execution time, epoch |
| `position_before` | double | position before the fill |
| `position_after` | double | position after the fill |
| `info_reason` | integer | informational reason code |

The rejection batch has `pos`, `reason_code`, `reasons` and `position`.
Today, fill plans build one list, three S3 objects and a timestamp
re-validation per fill (F1, F2, F8, F9). The batch replaces all of them.

**Costs are settled, not open.** The cost-step set is closed: `spread_bps`,
`fixed_fee`, `notional_bps_fee`, `zero` and `chain`
(`R/cost-model.R:389-433`). Each step is per-element arithmetic. Applying
the steps in chain order to the whole batch gives the same IEEE results as
applying them one fill at a time, and the final `round()` is per-element.
The resolver therefore takes the batch's columns in one call per pulse.

**Affordability stays sequential.** It is an ordered cash scan: cash-generating
sells first, then the rest, each group in radix order of instrument ID
(`R/availability-economics.R:344-389`). It becomes one loop over batch
indices, with reason codes as integers. Text appears only at the diagnostic
boundary.

**Timestamps are validated once per pulse.** The pulse and execution axes
are validated in E; fills are not re-validated.

### 3.7 Event batch and buffer (P4 to the sink)

**Columns.** Each pulse publishes one typed column block. Its columns are
the typed-accounting synthesis 3.1 common columns, plus `cash_delta` and
`position_delta`. The memory sink keeps its `event_realized` and
`event_cost_basis` columns until WS8 removes them. WS4a must not define a
different column set; it fills the synthesis's set early.

**Writing.** `event_id` is built for the whole block at once. The handler
owns a preallocated buffer and writes the block by index (P18, F3, F4). Leg
staging becomes typed leg columns (F5, F6).

**`meta_json` stays byte-identical until WS8.** The durable sink encodes it
from the typed block at publication. The memory sink keeps its `meta` list.
This per-fill encode is routed JSON under rule 14: WS8 removes it.

**Non-fill producers** (opening, corporate cash, dispositions) keep their
current row builders in WS4a. They write into the same buffer by index
(E6). Their typed evidence columns are WS8's. See Q5.

### 3.8 Diagnostic batch

The diagnostic batch has one fixed column schema: the persisted diagnostic
columns, today assembled per segment at
`R/availability-diagnostic-writer.R:44-92`. The fold holds one buffer per
run, grown geometrically and written by index. A segment is a set of column
vectors with `n` rows, written once, so lists of lists are no longer
accumulated (P14, I4).

`detail_json` remains a character column. Removing its per-pulse encode is
WS4b's job (H5). The decision trace, one row per context instrument per
pulse, is built and then discarded by the memory sink (I4). See Q4.

### 3.9 Equity record

Five typed vectors are preallocated to the pulse count: ts epoch, cash,
positions value, realized P&L and cost basis. Both sinks and both producers
use them. This covers P17 (WS4a) and P4, which the macro plan routed to
WS4b. See Q6.

### 3.10 Stop result and telemetry

The stop result keeps its class. It is produced at most once per run, so
typing it gains nothing. Telemetry is already typed vectors (P16) and stays
as it is.

### 3.11 Ownership

The fold owns the book, positions and the event, diagnostic and equity
buffers. A by-reference write (`setv`) is allowed only on a buffer no one
else holds (manual, ownership rule). Everything handed out is a copy, or a
value that is never written again:

- the positions in `ctx`;
- `state_prev`;
- the state passed to and returned by the corporate-action plan's `post`
  and `post_disposition`;
- the compiled batch input;
- the fold return;
- checkpoint flushes.

Returning a book transfers ownership. Each sweep candidate and each worker
builds its own fold. Resume imports the book once in E from the replayed
prefix.

The canonical lot kernel uses copy-on-modify, as probed. It switches to
by-reference writes only if the scale measurement (Section 6) shows the
per-pulse copy of the lot vectors matters. In that case the cut states the
ownership proof.

### 3.12 Dense producer

The macro plan says both current producers emit the carrier before WS4b
removes one, and AGENTS.md freezes dense mode. This seed proposes the
following reading:

- **Dense emits the carrier from the normalized decision onward:** the fill
  batch, apply, events, diagnostics, equity and fold state. It already
  shares P4 and P5.
- **Dense keeps its current observation and context construction:**
  `bars_views`, feature views and fast context. WS4b deletes them and WS5
  replaces `ctx`.

Retyping code that is scheduled for deletion buys no comparison evidence.
The comparison WS4b needs is at the decision and economic-event boundary.
The timestamp difference in Section 2, item 7, is data the carrier carries,
not a carrier difference; WS4b settles the implied calendar. See Q1.

## 4. Carrier Contract (draft, macro plan rule 15)

| Group | Column | Type | Axis | Unit | Invariant |
| --- | --- | --- | --- | --- | --- |
| state | `cash` | double | scalar | USD | finite |
| state | `positions` | double | run | units | equals `net_by_inst`; zero where flat |
| state | `event_seq` | integer | scalar | sequence | next unused; strictly increasing |
| book | `offset`, `capacity` | integer | run | slots | prefix offsets; disjoint segments |
| book | `head`, `tail` | integer | run | relative slot | empty = 1/0; live range within capacity |
| book | `lot_qty`, `lot_price` | double | lot slot | units, USD/unit | live finite; dead slots `NA` |
| book | `net_by_inst`, `cost_basis_by_inst` | double | run | units, USD | derived from live lots; dust rule |
| book | `total_cost_basis`, `realized_pnl`, `realized_comp` | double | scalar | USD | canonical event-order accumulation |
| observation | `context_pos` | integer | context | position | unique; within the run axis |
| observation | `member`, `held`, `buyable` | logical | run | flag | `buyable` implies `member` |
| observation | `mark`, `mark_age`, `mark_source` | double, integer, integer | run | USD, sessions, code | defined on `context_pos` |
| decision | `target_qty`, `strategy_qty` | double | run | units | full on context; validated once |
| decision | `actionable_pos` | integer | actionable | position | `abs(delta) > sqrt(eps)` |
| fill batch | Section 3.6 columns | mixed | fill | as named | distinct `pos`; canonical order |
| rejection batch | `pos`, `reason_code`, `reasons`, `position` | integer, integer, character, double | rejection | as named | `reasons` text built at boundary |
| event batch | synthesis 3.1 columns + effects | as DDL | event | as DDL | `event_seq` contiguous per block |
| diagnostics | persisted diagnostic columns | as table | diagnostic row | as table | `diagnostic_seq` contiguous |
| equity | `ts`, `cash`, `positions_value`, `realized`, `cost_basis` | double | pulse | epoch, USD | one row per valued pulse |

The constructor of each group points to this table. The table moves into
`contracts.md` at acceptance.

## 5. Questions for the Response

- **Q1. Dense scope (3.12).** Is "decision onward" an acceptable reading of
  "both producers emit the carrier", given the dense freeze? Or does WS4b's
  comparison need dense observation in the carrier too? This is a maintainer
  decision. **Maintainer, 2026-10-30: decided as proposed.** Dense emits the
  carrier from the normalized decision onward; its observation and context
  path is not retyped.
- **Q2. P1 adapter (3.4).** Should WS4a take the provider and valuation
  internals now to avoid the transitional adapter? That would make WS4a
  larger and move part of WS4b's floor work into it.
- **Q3. One lot kernel for replay from WS4a (3.3).** Does routing the replay
  through the batch kernel with one-event batches before WS7 risk
  replay-order identity, especially opening rows and dispositions? Or should
  the old kernel survive until WS7 as a declared second implementation?
- **Q4. Diagnostics the sink drops (3.8).** Should the fold skip building the
  decision trace when the sink declares it will drop it? The economics are
  unchanged, so it is output retention, not an execution-mode branch under
  AGENTS.md. The response should test that claim.
- **Q5. Non-fill producers (3.7).** Do they join the typed block in WS4a, or
  stay row builders until WS8? Today they are rare per run; they matter only
  for dividend-heavy Sharadar runs.
- **Q6. Equity record routing (3.9).** Should P4 move from WS4b to WS4a so
  that one cut types the whole equity record? This is a maintainer decision.
  **Maintainer, 2026-10-30: decided as proposed.** P4 moves to WS4a; the
  macro plan's WS4b amendment is corrected at acceptance.
- **Q7. Cut shape.** Macro plan Section 4 leaves the choice to this design.
  The seed proposes adjacent cuts: WS4a lands release-ready on its own, and
  WS4b inherits nothing until WS4a is accepted.
- **Q8. Within-pulse order.** Dispositions in P1 and fills in P4 can touch
  the same instrument in one pulse. The kernel's rule that a batch touches
  distinct instruments holds per stage. Does any producer emit two lot
  events for one instrument within one stage?

## 6. Gate Proposal

**Identity.** A0, the WS3 dense lane and the v0.2.2 real-data reference must
be byte-identical: ledger rows including `meta_json`, equity, strategy state,
diagnostics and the final book. Add one identity case with chained non-zero
costs (spread, fixed and notional) and one with dispositions and corporate
cash.

**Timing.** Use the shared harness `dev/bench/timing/` with alternating
pairs, on the no-fill, sparse-rebalance and wide all-fill shapes, for both
producers. Proposed bounds, set finally at the cut:

- availability wide all-fill sweep marginal at most 40 us per fill (the
  probe measured 27);
- the no-fill floor no slower than base beyond the noise band;
- durable wide run time at most 60% of base.

**Allocation.** Rprofmem bytes per fill no higher than base on the wide
shape.

**Scale.** Run one synthetic universe of at least 5,000 instruments, plus a
deep-book variant where single fills consume more than ten lots. Record the
lot kernel's time and allocation; Section 3.11's copy decision depends on
this.

**Detectors.** Mutation tests catch:

- a list per fill in the plan or event batch;
- a growing diagnostic-segment list;
- a name lookup inside the lot kernel;
- a second strategy-return validation;
- JSON inside the pulse loop other than the routed `meta_json` and H5.

**Cold read (rule 15).** A clean-context reviewer explains each changed
stage from its code and Section 4 alone.

## 7. Identity and Release Impact

- **Snapshot content identity:** none.
- **Run configuration identity:** none.
- **Store format fingerprint:** none; there is no schema change.
- **Release impact:** product tests and performance records, plus one
  `NEWS.md` line for the internal speed change. No documentation or
  dependency change.

## 8. Rejected

- **A native lot kernel as the default.** It is a v0.2.3 non-goal, and it
  measured only 2.4 us per fill faster.
- **Keeping per-fill lists with faster helpers.** The R-plus-copying arm
  measured 69 us per fill.
- **`positions + delta` as the position authority.** Typed-accounting
  synthesis 3.2 rejected it.
- **Data-frame or environment-per-instrument carriers.** Both break the
  manual's base-R kernel rule.
- **Retyping the dense observation path.** See 3.12 and Q1.

## 9. Sequence

1. Type 2 response (Codex).
2. Response review.
3. Seed v2, if needed (Claude).
4. Maintainer decisions on Q1 and Q6: recorded in place, 2026-10-30.
5. Synthesis (Codex).
6. Type 1 final review.
7. WS4a cut: measure, cut, Codex cut review, implement.
