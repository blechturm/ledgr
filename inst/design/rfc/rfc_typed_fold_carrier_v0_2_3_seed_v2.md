# RFC Seed v2: Typed Fold Carrier for v0.2.3

- Status: Seed v2. Synthesis by Codex is next.
- Author: Claude
- Date: 2026-10-30
- Target window: v0.2.3, WS4a, before its cut
- Baseline reviewed: `release/v0.2.3` at `99567ad8`
- Prior stages: seed v1 (Claude); Type 2 response v1 (Codex,
  ACCEPT_WITH_CHANGES). The maintainer folded the response review into
  Section 1 of this file (2026-10-30), since the seed author accepts every
  finding.
- Maintainer decisions: Q1 and Q6, 2026-10-30, recorded in seed v1 Section 5
  and restated in Section 2.
- Evidence: `dev/spikes/ws4a-carrier-probe/` (`7d14ebe0`, typed-lots arm
  `5555f9e8`); `dev/spikes/shape-audit/audit.md`;
  `dev/spikes/json-hot-path-audit/audit.md`

Shorthand, as in the response: **Phase** is the fold-phase synthesis,
**Accounting** the typed-accounting synthesis, **Authoring** the
strategy-authoring synthesis and **Macro** the v0.2.3 macro plan.

## 1. Rulings on the Type 2 Response

Every finding is accepted. One remedy is resolved differently: F2's
run-axis targets (marked (*) below).

| Finding | Ruling | Where |
| --- | --- | --- |
| Evidence: one fixed-fee identity case existed; reorder and dropped-fee mutations ran on the native arm; "costs settled" overclaimed IEEE identity | Accepted; corrected | 3 |
| F1: affordability order versus publication order | Accepted | 4.6 |
| F1: planned versus actual position after a fill | Accepted | 4.6, 4.7 |
| F2: rejection rows keep resolved price, execution time, ordered reasons and emission order | Accepted | 4.6 |
| F2: targets must never be zero-padded; the actionable axis must be named | Accepted. (*) Resolved by keeping observation and decision columns on the context axis, not with run-axis `NA` | 4.4, 4.5 |
| F2: the contract table is incomplete; transitional adapters must be declared | Accepted | 4.1, 5 |
| F3: separate open, close and dispose operations; cash outside the kernel | Accepted | 4.3 |
| F3 / Q3: replay uses the one implementation in WS4a; singleton-call cost is a gate | Accepted | 4.3, 6 |
| F3 / Q8: distinct instruments is a precondition of a kernel call, not of an event batch | Accepted | 4.3 |
| F4: diagnostics stay bounded through the existing writer | Accepted | 4.9 |
| F4 / Q4: the blanket trace skip is false; selective retention needs a row and sequence comparison | Accepted. Selective materialization is routed to WS4b | 4.9 |
| F5: one ownership split; non-fill events keep their P1 order; WS4a imports none of Accounting's DDL or validator | Accepted | 4.8 |
| F5: compiled unpack, not only pack | Accepted | 4.3 |
| Q2: keep the P1 adapter; convert once per produced view | Accepted | 4.4 |
| Q7: adjacent cuts | Accepted | 9 |
| Equity record: needs a valid-row count and the two run clocks | Accepted | 4.10 |
| Validation: the risk-mark and equity runtime checks stay; the fold-state validator must be extended | Accepted | 4.2, 4.5 |
| Gate additions; peak memory; atomicity check; no unqualified move into `contracts.md` | Accepted | 5, 6 |

**Why (*) differs.** Target validation already returns targets reordered onto
the context axis (`R/strategy-contracts.R:55-100`). Today's actionable
indices also index that vector (`R/fold-engine.R:1063-1068`). Keeping
observation and decision columns on the context axis therefore needs no
padding rule at all, so there is no missing value to misread as zero.
Fold state stays on the run axis. `context_pos` is the only bridge between
the two axes.

## 2. Question, Boundary and Decisions

The question and boundary are unchanged from seed v1 Section 1. The seed
types the slots and hand-offs of the fold-phase stages (E, P1-P5). Economics,
event order and `meta_json` stay byte-identical. Lots stay the only position
authority. There is no compiled default, no new execution-mode branch, and
no schema or public API change.

- **Q1, decided:** dense emits the carrier from P2's normalized decision
  onward. Its observation and context path is not retyped.
- **Q6, decided:** the availability equity accumulator (shape audit P4) moves
  from WS4b to WS4a. The macro plan's WS4b amendment is corrected when this
  RFC is accepted.

## 3. Evidence, Corrected

The probe supports typed R for the measured shape. It does not show that
native code is never useful. The typed arm measured 27.17 and 27.07 us per
fill (wide and partial-heavy), against 24.81 for native. Durable runs took
11.34 s against a 7.75 s floor (`typed_lots_findings.md:5-9`). The roughly
200 us gain over base comes from the combined representation change. It is
not an isolated price of lists or name lookups.

Coverage the seed v1 misstated:

- Identity included one fixed-fee case (`typed-check.R:19-22`). No case
  chained spread and notional fees.
- The LIFO mutation ran through the typed kernel. The reorder and
  dropped-fee mutations ran through the native arm (`typed-check.R:28-43`).
- The probe kernel handles fills only, and re-imported the legacy book after
  non-fill events (`typed-lots.R:103-119`). Openings and dispositions were
  never applied by a typed kernel.
- Per-element cost steps are an implementation hypothesis. The Section 6
  identity cases prove or refute it.

## 4. Architecture

### 4.1 Axes and boundary helpers

There are three axes:

- **Run axis:** `execution$instrument_ids`. Fold state lives here.
- **Context axis:** this pulse's decision universe, as integer ordinals
  `1..n_ctx`. Observation and decision columns live here.
  `context_pos[k]` is ordinal `k`'s position on the run axis. On dense,
  `context_pos` is `seq_len(n_inst)`.
- **Row axes:** fill, rejection, event, lot slot, pulse and diagnostic row,
  each with its own carrier group.

Permanent name boundaries:

1. building `ctx` (P2 entry);
2. normalizing the strategy return (P2 exit);
3. writing `instrument_id` at publication;
4. the fold return.

Declared transitional adapters, each named in code with the cut that
removes it:

- the P1 provider and valuation adapter (WS4b);
- the corporate-action plan's state in and out (WS4b, or WS8 for its event
  rows);
- compiled pack and unpack (the compiled-envelope RFC).

No other stage converts between IDs and positions.

### 4.2 Fold state

The Phase 5.1 locked environment and slot set stay, with three changes:

- `positions` becomes an unnamed double vector on the run axis;
- `lot_state` becomes the typed book of 4.3;
- `pending_segments` becomes a pulse-sized typed diagnostic staging block
  (4.9).

The fold state holds no handler or writer buffer. The validator
(`R/fold-phase-contract.R:73-122`) is extended to check the typed book's
column types and lengths and the run-axis lengths. It runs at construction
and at stop application.

### 4.3 The lot book and one accounting implementation

The book layout is the probe's (`typed-lots.R:3-22`). The contract table in
Section 5 lists it.

**Operations.** One implementation provides three operations. Each call
takes rows in canonical order whose instruments are distinct within that
call.

- **open:** appends a signed lot with its cost basis. It changes no cash and
  makes no realized-P&L or Kahan update (`R/lot-accounting.R:147-179`).
- **close:** a fill. It consumes FIFO depth vectorized across instruments,
  opens any remainder, and adds `pnl - fee` to realized P&L with the Kahan
  step in row order.
- **dispose:** a close with zero fee that allows a zero price. It must
  exhaust every live lot and match `realized_model_pnl` at dust tolerance
  (`R/lot-accounting.R:447-487`).

**Callers.** A caller partitions an ordered stream into consecutive
conflict-free blocks and never reorders it. Repeated carried openings for
one instrument (`R/fold-event-buffer.R:120-124`) become successive blocks.
P4's fill batch is one block, because each actionable target yields at most
one fill.

**Outputs per row:** actual position before and after (read from
`net_by_inst`), `close_qty`, `open_qty`, `realized_close`, `realized_delta`,
`event_realized` and `event_cost_basis`.

**Cash stays outside the kernel.** One ordered scan adds cash effects that
were already computed, once each: `ledgr_fill_publication_deltas()` in the
fold and the published `cash_delta` in replay
(`R/accounting-replay.R:296-328`). Neither path computes a fill's cash a
second time.

**Replay in WS4a.** `ledgr_lot_apply_event()` becomes a typed-scalar adapter
onto this implementation. `ledgr_lot_apply_fill()`, the named-list
`ledgr_lot_state()` and `ledgr_position_from_lots()` are deleted. Metadata
preparation and the reader architecture stay until WS7. Section 6 gates the
replay's time and allocation. If singleton calls cost too much, the replay
groups conflict-free blocks through the same kernel.

**Compiled `spot_fifo`.** Pack gathers live lots from the typed book. Unpack
rebuilds the typed book by gather and carries the aggregates and Kahan state
exactly (`R/compiled-spot-fifo.R:137-165`). The fill batch passes as columns.
The C++ code and the opt-in envelope are unchanged.

**Copies.** The canonical kernel uses copy-on-modify. By-reference writes
need the Section 6 scale evidence and an ownership proof written into the
cut.

### 4.4 Observation packet (P1 to P5)

The packet holds the contents Phase 4.2 lists:

- pulse index and time;
- `context_pos`;
- cash and positions value;
- positions on the context axis (a copy);
- `member`, `held` and `buyable`;
- valuation: mark, age, source code, `priced` and `permissible`;
- source-row locators into the prepared bars and feature matrices;
- membership.

It contains no data frame. Execution-bar columns are not in the packet: P3
reads them through its own locator, so the `ctx` builder never sees them
(contract-execution-decision-and-fill-contexts).

The P1 adapter converts the provider's and the valuation state's named
outputs once per produced view and reuses the mapping across columns. P1 can
produce a view again after settlement or disposition
(`R/fold-engine.R:389-418`). The cut reports the adapter's cost.

### 4.5 Decision (P2 to P5)

The strategy return is normalized for shape and names once
(`R/strategy-contracts.R:34-101`). Missing targets are refused, never
zero-filled.

The duplicate post-risk normalization goes (`R/risk-model.R:478-489`). The
property checks stay: risk-mark and equity validation run at runtime
(`R/risk-model.R:416-475`).

The compiled risk plan is validated once in E.

Outputs, on the context axis:

- `strategy_qty` (before risk) and `target_qty` (after risk);
- `actionable_k`, context ordinals in context order;
- the raw state update, unnormalized until P5 (Phase 4.3);
- `intent_reason` as today.

### 4.6 Plan (P3 to P5)

**Fill batch,** in decision-axis order (contract-availability-affordability):

- `k` and `pos`;
- `side` (+1 or -1), `qty`, `price`, `fee`;
- `cash_delta`, from one call of `ledgr_fill_publication_deltas()`;
- `exec_ts` as an epoch;
- `position_before`;
- `planned_position_after`, used for diagnostics only;
- informational reasons.

**Plan-level fields:** `expected_final_cash`, an acceptance mask over
candidate rows, and a private affordability permutation. The permutation
orders the cash scan: cash-generating reductions first, then C-locale
stable-ID order (`R/availability-economics.R:350-388`). Accepted rows are
then compacted back into decision order (`:513-516`). Publication is never
sorted by priority, and the virtual cash never stands in for event-order
cash. Reconciliation keeps its arithmetic and tolerance
(`R/fold-engine.R:1140-1168`).

**Rejection batch:**

- `k`, `pos` and an emission ordinal: early rejections first, then
  affordability rejections (`:513-514`);
- reasons;
- `resolved_price`, `NA` when no fill was resolved;
- `exec_ts`, `NA` on the final pulse;
- `position`.

**Reasons** use one fixed integer dictionary in a flat segment: per-row
offsets and counts into one code vector. They are ordered and deduplicated
as today (`R/availability-economics.R:334-341, 375-382`). Text is built only
at the diagnostic boundary. A bit mask is not used, because it loses order.

**Costs.** Cost steps are applied to the batch in chain order. Notional fees
use the unrounded spread-adjusted price, and the fill price is rounded last
(`R/cost-model.R:407-420`).

### 4.7 Apply (P4 to P5)

One close-operation call takes the fill batch. Then one ordered cash scan
runs in event order. P4 alone produces the actual book outputs of 4.3; P3
never pre-applies lots. Phase 4.5 atomicity holds: the book, cash, positions
and `event_seq` change only after the batch succeeds.

### 4.8 Publication and ownership

There is one split, by owner:

- **The fold** owns economic state and the transient semantic batches.
- **The handler** owns persistence and retention buffers. Its event buffer
  is preallocated and written by index (P18).
- **The diagnostic writer** owns the bounded diagnostic chunks.

A batch is transferred or copied at append or flush. Anything handed out is
a copy or never written again: `ctx` positions, `state_prev`, the
corporate-action plan's state input, compiled inputs, the fold return and
checkpoints.

"One typed block per pulse" means fill publication. `event_id` is built per
block, and leg staging uses typed columns (F3-F6).

Non-fill events keep their P1 order and their row builders (Phase 4.2).
They are adapted once at publication into the indexed buffer (E6).

WS4a reuses Accounting's field meanings internally. It imports none of
Accounting's DDL, evidence validator, fallback deletions or reader changes.

Routed JSON (rule 14):

- fill `meta_json` and the memory `meta` list, non-fill `meta_json`, and
  replay's metadata parse go to WS8;
- the reconciliation `detail_json` goes to WS4b (H5).

### 4.9 Diagnostics

Stages write a pulse-sized typed staging block with the persisted diagnostic
columns, sized from the pulse's known row counts. P5 drains it into the
existing bounded writer, which already accepts one typed block per pulse and
splits it at chunk boundaries (`R/availability-diagnostic-writer.R:94-171`).
E keeps its stop drainage. No run-long buffer and no second writer exist.

WS4a builds the full block and keeps today's memory-sink filter
(`R/output-handler.R:362-378`). Selective materialization moves to WS4b's
"diagnostic flushing" item: a sink-owned descriptor may skip payload columns
only once logical row count and order are fixed. `diagnostic_seq` advances
for every logical row. A retained-row and sequence comparison must pass.

### 4.10 Equity record

The fold owns five double vectors preallocated to the pulse count: `ts`,
`cash`, `positions_value`, `realized_pnl` and `cost_basis`. They come with a
valid-row count `n`. The existing `last_fully_valued` and `last_executed`
slots stay the two run clocks for early stop, INCOMPLETE runs and resume
(contracts.md, rebuilt equity, 2657-2665).

The record replaces both the availability accumulator (P4) and the memory
sink's growable vectors (P17). At E, ownership passes to finalisation and
the handler.

## 5. Carrier Contract

"Writer" is the stage that writes a column. "Lives" is how long a value
lasts. Unchanged Phase 5.1 slots are listed by reference.

| Group | Column | Type | Axis | Missing / empty | Writer | Lives |
| --- | --- | --- | --- | --- | --- | --- |
| state | `cash` | double | scalar | never `NA` | E, P1, P4 | run |
| state | `positions` | double | run | 0 when flat; never `NA` | P1, P4 | run |
| state | `event_seq` | integer | scalar | next unused | E, P1, P4 | run |
| state | other Phase 5.1 slots | as today | - | as today | as today | run |
| book | `offset`, `capacity` | integer | run | prefix offsets; disjoint segments | E, P1, P4 | run |
| book | `head`, `tail` | integer | run | empty = 1/0 | E, P1, P4 | run |
| book | `lot_qty`, `lot_price` | double | lot slot | dead slots `NA` | E, P1, P4 | run |
| book | `net_by_inst`, `cost_basis_by_inst` | double | run | 0 when flat | E, P1, P4 | run |
| book | `total_cost_basis`, `realized_pnl`, `realized_comp` | double | scalar | never `NA` | E, P1, P4 | run |
| packet | `pulse_idx`, `ts` | integer, double epoch | scalar | never `NA` | P1 | P5 |
| packet | `context_pos` | integer | context | unique, on run axis; may be empty | P1 | P5 |
| packet | `cash`, `positions_value` | double | scalar | never `NA` | P1 | P5 |
| packet | `position` | double | context | copy of state | P1 | P5 |
| packet | `member`, `held`, `buyable` | logical | context | never `NA`; `buyable` implies `member` | P1 | P5 |
| packet | `mark`, `mark_age`, `mark_source` | double, integer, integer code | context | `NA` when unpriced | P1 | P5 |
| packet | `priced`, `permissible` | logical | context | never `NA` | P1 | P5 |
| packet | `bar_row`, `feature_row` | integer | context | locators into prepared matrices | P1 | P5 |
| decision | `strategy_qty`, `target_qty` | double | context | never `NA` after validation | P2 | P5 |
| decision | `actionable_k` | integer | actionable | context order; may be empty | P2 | P4 |
| decision | `state_update` | opaque | - | `NULL` = carry | P2 | P5 |
| fill | `k`, `pos`, `side` | integer | fill | never `NA` | P3 | P5 |
| fill | `qty`, `price`, `fee`, `cash_delta`, `exec_ts` | double | fill | never `NA` | P3 | P5 |
| fill | `position_before`, `planned_position_after` | double | fill | planned, not book | P3 | P5 |
| fill | `info_offset`, `info_count`, `info_code` | integer | fill / code | ordered dictionary codes | P3 | P5 |
| plan | `expected_final_cash` | double | scalar | never `NA` | P3 | P5 |
| plan | `accepted`, `afford_order` | logical, integer | candidate | private to P3 | P3 | P3 |
| rejection | `k`, `pos`, `emit` | integer | rejection | emission order | P3 | P5 |
| rejection | `reason_offset`, `reason_count`, `reason_code` | integer | rejection / code | ordered, deduplicated | P3 | P5 |
| rejection | `resolved_price`, `exec_ts`, `position` | double | rejection | `NA` when absent | P3 | P5 |
| apply | `position_before`, `position_after` | double | fill | actual, from the book | P4 | P5 |
| apply | `close_qty`, `open_qty`, `realized_close`, `realized_delta`, `event_realized`, `event_cost_basis` | double | fill | never `NA` | P4 | P5 |
| diagnostics | persisted diagnostic columns | as writer schema | pulse row | pulse-sized | P1-P5 | P5 drain |
| equity | `ts`, `cash`, `positions_value`, `realized_pnl`, `cost_basis`; `n` | double; integer | pulse | rows beyond `n` unused | P1 | E handoff |

**Referenced services** are not carrier columns. They are declared in Phase
5.2: prepared bars and feature matrices, the provider, the valuation state,
the corporate-action plan, the cost steps, the risk plan, pulse seeds, the
output handler, the diagnostic writer and telemetry.

Each group's constructor points to this table. Acceptance binds the table as
pending WS4a scope. It enters `contracts.md` when WS4a closes, not before.

## 6. Gate

**Identity.** A0, the WS3 dense lane and the v0.2.2 real-data reference
must match exactly: ledger rows including `meta_json`, equity, strategy
state, diagnostics with their retained rows and sequence gaps, and the
logical live FIFO contents and aggregates. Container bytes are not compared,
because the layouts differ.

Required cases:

- chained non-zero costs, including spread, fixed and notional, plus
  rounding edges;
- fractional dust;
- short reversals where dense supports them;
- repeated carried openings;
- zero-price dispositions;
- scheduled skips;
- stops and resume;
- compiled pack and unpack.

Planned and actual positions are compared separately. All mutations run
through the typed implementation: LIFO, reordered publication, a dropped
fee, a zero-delta Kahan step on an opening, and sorting publication by
affordability priority.

**Timing.** Use the shared harness `dev/bench/timing/` with alternating
pairs, on the no-fill, sparse-rebalance and wide all-fill shapes, for both
producers. Proposed bounds, set finally at the cut:

- the availability wide sweep marginal is at most 40 us per fill;
- the no-fill floor is within noise of base;
- the durable wide run takes at most 60% of base.

Replay time and allocation are recorded separately.

**Scale.** One universe of at least 5,000 instruments, plus a deep-book
variant where single fills consume more than ten lots. Record cumulative
Rprofmem and peak live memory, including book growth and replay.

**Detectors.** Mutation tests catch:

- a list per fill in the plan or publication;
- a run-long or list-grown diagnostic buffer;
- a name lookup inside the lot kernel;
- a second shape normalization of the strategy return;
- JSON in the pulse loop beyond the routed items.

**Ownership.** An early-failure check shows that a failing P4 batch leaves
the book, cash, positions and `event_seq` unchanged.

**Cold read (rule 15).** A clean-context reviewer explains each changed
stage from its code and Section 5 alone.

## 7. Identity and Release Impact

- **Snapshot content identity:** none.
- **Run configuration identity:** none.
- **Store format fingerprint:** none.
- **Release impact:** product tests and performance records, plus one
  `NEWS.md` line.

## 8. Rejected

- **A native default.** It is a non-goal, and saves 2.4 us per fill on the
  measured shape.
- **Per-fill lists with faster helpers.** They measured 69 us per fill.
- **`positions + delta` as the position authority.**
- **Sorting publication by affordability priority.**
- **One distinct-instrument rule for whole event batches.**
- **Fill cash computed inside the lot kernel.**
- **A blanket skip of the decision trace.**
- **A run-long diagnostic buffer.**
- **Importing Accounting's DDL or validator into WS4a.**
- **Run-axis decision columns padded with `NA`.** See (*) in Section 1.

## 9. Open Questions Promoted to the Cut, and Sequence

**Open at the cut:**

- whether replay uses singleton or blocked calls, decided by the replay
  gate;
- the exact timing bounds;
- the integer dictionaries for reasons and mark sources.

**Sequence:**

1. Synthesis (Codex).
2. Type 1 final review (Claude).
3. Acceptance, which also corrects the macro plan's WS4b amendment for P4.
4. The WS4a cut, as an adjacent release-ready cut; WS4b inherits nothing
   until WS4a is accepted.
