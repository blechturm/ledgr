# Response: OMS Semantics RFC Seed

**Status:** Reviewer response; design input for a future OMS synthesis.
**Respondent:** Codex
**Date:** 2026-05-26
**Responds to:** `inst/design/rfc/rfc_ledgr_oms_seed.md`

**Revision note:** This response was written against the initial untracked OMS
seed. The seed was later revised in place, so some blocking findings may now be
resolved in the current seed. Future OMS RFC rounds should preserve separate
versioned seed files before response-stage edits.

---

## Summary Verdict

The seed is architecturally sound. Its central decision is correct:

```text
strategy targets remain the user contract;
order lifecycle becomes engine-owned;
ledger_events remain accounting truth;
order_events, if added, are a separate lifecycle stream.
```

That direction aligns with ledgr's current fold core, the target-risk roadmap,
the execution-policy north-star RFC, and the current accounting ledger design.
It also takes the right lessons from FIX, quantstrat/blotter, backtrader,
Zipline, and NautilusTrader.

The seed should not move to synthesis as-is. The issues are not fatal, but they
are binding design questions:

- roadmap sequencing currently conflicts with `inst/design/ledgr_roadmap.md`;
- terminal-cancel `LeavesQty` examples are not FIX-aligned;
- the `FILL_PARTIAL` cleanup direction is left open when it should be bound;
- the order lifecycle stream is append-only, but link-update language implies
  mutable post-hoc edits;
- raw strategy targets, risked targets, and orderable targets are not yet
  separated;
- paper/live-shaped schema fields are included before the paper/live RFC owns
  their semantics.

The right next step is seed revision, then another review pass, then synthesis.

---

## Accepted Direction

The response accepts these seed-level decisions:

- `ledger_events` remains the accounting source of truth.
- OMS lifecycle rows do not share rows with accounting ledger rows.
- Strategies remain `function(ctx, params)` target-vector functions.
- Strategies do not receive `ctx$order()`, `ctx$buy()`, `ctx$sell()`, or
  `ctx$cancel()`.
- OMS state does not live in `strategy_state`.
- Safety gates are adapter/policy responsibilities, not strategy
  responsibilities.
- Exploratory sweep output cannot directly launch paper/live trading.
- Research, paper, and live must share fold semantics; there must not be a
  second execution engine.

These are the load-bearing design choices. The remaining findings refine how
the seed should make them implementable.

---

## Blocking Corrections

### 1. Roadmap Sequencing

The seed proposes a `v0.1.10 / v0.2.0` OMS planning window and then places
public cost/liquidity APIs after OMS.

That conflicts with the current roadmap:

```text
v0.1.9             target-risk and primitive-internals planning gates
v0.1.9.x           walk-forward evaluation before OMS and paper-trading work
v0.1.9.x/v0.2.0    public transaction-cost model API
v0.2.x             liquidity/capacity, PIT data, corporate actions,
                   benchmark context, OMS semantics
v0.3.0             paper adapter and reconciliation
v1.0.0             small-scale live trading
```

Recommendation:

- retarget this seed to future `v0.2.x` OMS semantics;
- explicitly state that walk-forward and the public cost API come first unless
  the roadmap is amended;
- keep paper/live adapter work in `v0.3.0+` scope.

Do not invent `v0.1.10` unless the roadmap is deliberately changed.

### 2. FIX `LeavesQty` Semantics

The seed's canceled-order examples are not FIX-aligned.

The FIX order-state examples show terminal canceled orders with
`LeavesQty = 0`, including both no-fill cancellation and partial-fill
cancellation. If ledgr wants to preserve "unfilled quantity that will not
execute," use a separate field or derive it:

```text
canceled_qty = order_qty - cum_qty
```

Do not overload `leaves_qty` with that meaning if the model is FIX-inspired.

Recommendation:

```text
canceled after no fill:
  cum_qty      = 0
  last_qty     = 0 or NULL
  leaves_qty   = 0
  canceled_qty = order_qty        # derived or future explicit field

canceled after partial fill:
  0 < cum_qty < order_qty
  last_qty     = 0 or NULL
  leaves_qty   = 0
  canceled_qty = order_qty - cum_qty
```

### 3. `FILL_PARTIAL` Cleanup Direction

The seed correctly identifies the current mismatch:

- the DDL allows only `FILL`, `FEE`, and `CASHFLOW`;
- several readers still accept `FILL_PARTIAL`;
- no current writer emits `FILL_PARTIAL`.

The cleanup direction should be bound before OMS tickets are cut.

Recommendation:

```text
Delete stale FILL_PARTIAL reader support.
Do not add FILL_PARTIAL to ledger_events DDL.
Future partial fills become multiple ordinary FILL ledger rows linked to
ORDER_PARTIAL_FILL / ORDER_FILLED lifecycle events.
```

This keeps `ledger_events` an accounting stream and avoids two accounting event
taxonomies.

### 4. Append-Only Linking

The seed says `order_events` is append-only, but the future chain includes:

```text
ledger event -> order event link update
```

That creates a mutable lifecycle row unless the ID is known before write.

Recommendation:

Bind this invariant:

```text
Order/ledger links must be represented without post-hoc mutation of already
written order_events rows.
```

Acceptable first implementations:

- preallocate deterministic ledger event IDs and write the link in the order
  event before persistence;
- put a one-way typed link from the ledger event to the order event;
- emit a separate append-only `ORDER_ACCOUNTED` / `ORDER_LEDGER_LINKED` event.

The seed does not need to choose the final implementation yet, but it should
reject mutable link updates.

### 5. Raw Targets Versus Risked Targets

The seed describes a target decision as the strategy's full desired holdings
vector. That is not enough once v0.1.9 target risk exists.

The future audit path needs at least:

- raw strategy target;
- post-risk/orderable target;
- risk-chain identity and audit signal;
- target delta derived from the post-risk target.

Recommendation:

Define `target_decision` as a family of decision records or a record with
separate fields:

```text
strategy_target_vector_json
risked_target_vector_json
target_vector_hash / risked_target_vector_hash
risk_chain_hash / risk_audit_json
```

Do not let OMS obscure whether a trade came from strategy intent or risk-policy
modification.

---

## Schema And State-Machine Decisions Needed Before Synthesis

### Deterministic IDs

`order_event_id` should not be "globally unique enough." ledgr's replay model
requires deterministic construction.

Recommendation:

```text
order_event_id = paste0(run_id, "_order_", sprintf("%08d", order_event_seq))
order_id       = paste0(run_id, "_ord_",   sprintf("%08d", order_seq))
```

The exact prefix is not important. Determinism is.

### Quantity Tolerance

Strict double equality is unsafe for cumulative fill accounting.

Recommendation:

Use the same style of tolerance as the fold delta path, currently based on
`sqrt(.Machine$double.eps)`, when classifying:

- filled versus partially filled;
- zero leaves;
- zero residual target delta.

### State-Machine Scope

The v1 table includes `PENDING_CANCEL` but does not fully model cancel-reject
races. This is acceptable for research-mode diagnostics, but not enough for
paper/live adapters.

Recommendation:

- keep research v1 small;
- explicitly defer CancelReject/replacement semantics to paper/live adapter
  design;
- before paper/live, widen the transition table to represent cancel rejection
  and late fills during pending cancel.

### V1 Status Vocabulary

Split active v1 states from reserved future states.

Active v1:

```text
PENDING_NEW
NEW
PARTIALLY_FILLED
FILLED
PENDING_CANCEL
CANCELED
REJECTED
```

Reserved future:

```text
PENDING_REPLACE
REPLACED
EXPIRED
DONE_FOR_DAY
SUSPENDED
CALCULATED
ACCEPTED_FOR_BIDDING
```

`DONE_FOR_DAY` should not be globally terminal in ledgr semantics. In
FIX-inspired models it means no more executions are expected for the trading
day, not necessarily that a multi-day order is permanently terminal.

### Paper/Live Fields

The proposed `order_events` schema includes fields that belong to later
paper/live adapter design:

- `broker_order_id`;
- `client_order_id`;
- `parent_order_id`;
- `ts_effective_utc`;
- `source_event_id`;
- possibly `target_decision_id`.

These may be necessary later, but the v1 research OMS schema should not pretend
their semantics are already bound.

Recommendation:

- mark them explicitly as deferred adapter fields; or
- move them to `meta_json` until the paper/live RFC binds them; or
- omit them from the first schema and add them later pre-CRAN.

### Source Semantics

The seed currently mixes origins and actions in `source`:

```text
research_sim
paper_adapter
live_adapter
reconciliation
```

`reconciliation` is not the same kind of value as the others.

Recommendation:

Use `source` for origin and event types for action, or split:

```text
source_origin = research_sim | paper_adapter | live_adapter
produced_by   = engine | adapter | reconciliation
```

This can be deferred, but should not be left ambiguous before schema tickets.

---

## Runtime Scope Recommendations

### Order Events Should Be Diagnostic First

Do not write full order lifecycle rows for every normal research run by
default in the first implementation.

Recommendation:

```text
Initial research OMS persistence is explicit/diagnostic.
Default committed research runs keep current public artifacts until telemetry
and review show that order rows can become standard without surprising users.
Sweeps do not persist full order events by default.
```

This avoids changing artifact size and inspection behavior before the lifecycle
model proves itself.

### Outstanding Orders

The seed is right that asynchronous paper/live must account for outstanding
orders. The first research-only diagnostic implementation can defer full
outstanding-order netting if synchronous fills remain immediate.

Recommendation:

Bind the paper/live invariant now:

```text
future order intent quantity = post-risk target - current position -
                               engine-known outstanding net order quantity
```

Then state that the synchronous research path has no persistent outstanding
orders after the pulse completes.

### Long-Only Scope

The seed says "long-only or current-ledgr-compatible." That is too vague.

Recommendation:

Bind v1 OMS as long-only at the public contract level unless a separate
shorting/margin RFC lands first. Current ledgr arithmetic may represent
negative quantities internally, but broker-style shorting semantics are not a
stable public OMS contract.

### API Naming

Avoid `persistence = "research" | "paper" | "live"`.

That overloads storage policy with execution mode.

Recommendation:

Use future language like:

```text
mode = research | paper | live
retention = default | diagnostic | full
```

The exact API is future scope; the conceptual separation should be captured
now.

---

## Testing Implications

Add these expectations to the seed's testing section:

- order IDs and order event sequences are deterministic across replay;
- order lifecycle rows, when enabled, do not change ledger-derived fills,
  trades, equity, or metrics;
- target vector JSON has a companion hash for cheap equality checks;
- classification of `FILLED` versus `PARTIALLY_FILLED` uses a numeric
  tolerance;
- the memory output handler can discard order events for sweeps while the
  persistent output handler records them only when the selected mode/retention
  allows it;
- research synchronous OMS mode has a telemetry gate before it can become
  default.

---

## Deferred To Future RFCs

The seed should explicitly defer:

- broker adapters;
- live restart automation;
- reconciliation implementation;
- order replacement chains;
- cancel-reject handling beyond reserved state-machine vocabulary;
- external broker ID idempotency rules;
- paper/live target-decision persistence details;
- public liquidity/capacity policy;
- public order-entry API;
- unified typed-domain event table;
- accounting correction/bust semantics.

The current RFC should keep the data model compatible with these directions,
not design them.

---

## Editorial Notes

These are not blocking:

- Split permanent design rejections from "not yet" deferrals.
- Rename the working title to remove `v0.1.10`.
- Avoid "as today" phrasing; name the current internal function or contract
  instead.
- Move some open questions into accepted positions after the seed is patched.
- Keep the prior-art section, but phrase academic sources as motivating context
  rather than proof for specific schema invariants.

---

## Recommended Next Step

Patch the seed with the blocking corrections and explicit deferrals above, then
send the revised seed for one more review.

Do not draft synthesis yet. The design direction is right, but the roadmap,
quantity semantics, and lifecycle/schema commitments need to be stable before
the synthesis binds decisions.
