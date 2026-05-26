# RFC Seed: OMS Semantics for ledgr

**Status:** Draft RFC seed for maintainer review.

**Scope:** OMS data model and lifecycle semantics for a future `v0.2.x` planning window, after walk-forward and public transaction-cost boundaries have stabilized unless the roadmap is amended.

**Non-scope:** Implementation tickets, broker adapters, public cost/liquidity APIs, intraday/HFT support, and live trading.

**Working title:** `rfc_oms_semantics_order_events_v0_2_x_seed.md`

**Revision note:** This is a post-response revised seed. The initial untracked
draft was reviewed in `rfc_ledgr_oms_seed_response.md` and then revised in
place; future iterations should preserve separate versioned seed files if the
review cycle continues.

---

## 0. Executive summary

ledgr should grow OMS semantics by adding an append-only `order_events` lifecycle stream beside the existing append-only `ledger_events` accounting stream.

`ledger_events` remains accounting truth.

`order_events` becomes order-lifecycle truth.

The two streams reference each other by `run_id`, `order_id`, and event sequence identifiers.

They do not share rows.

This keeps current ledgr accounting stable while giving paper/live design a place to represent order intent, acknowledgments, partial fills, cancellations, rejections, and reconciliation boundaries.

The strategy contract does not change.

A strategy remains `function(ctx, params)`.

A strategy still returns a full named numeric target vector.

The fold core remains the single execution engine.

OMS semantics are inserted after target validation and target-risk transformation, and before fill/cost/ledger accounting.

The first OMS model should be deliberately small.

It should target single-currency, long-only, daily-bar, EOD equities workflows.

The default research behavior should remain synchronous next-open fill behavior.

The first OMS path should make current fills a degenerate synchronous order lifecycle, not a second execution engine.

The first lifecycle should fit on one page:

```text
target delta
  -> ORDER_INTENT        market, next-open, engine-generated
  -> ORDER_ACCEPTED      synchronous in research; broker ack in paper/live
  -> ORDER_PARTIAL_FILL* optional one or more partials
  -> ORDER_FILLED        terminal success
     | ORDER_REJECTED    terminal failure
     | ORDER_CANCELED    terminal cancellation
  -> FILL accounting event(s)
```

The RFC should bind a few decisions now and defer the rest.

Bind now:

- `ledger_events` stays accounting truth.
- `order_events` is a separate lifecycle stream.
- strategies never manage orders.
- OMS state never lives in `strategy_state`.
- target decisions are persisted in paper/live, not in research/sweep by default.
- order-event persistence starts as explicit/diagnostic for research, not as a default artifact for every committed run.
- safety gates are adapter/policy responsibilities.
- no sweep-to-live path exists.
- research, paper, and live share the fold-core semantics.

Defer now:

- broker adapters.
- public cost API.
- public liquidity/execution API.
- limit orders beyond model placeholders.
- cancel/replace workflows beyond representable lifecycle events.
- multi-currency.
- intraday.
- options/futures/FX/crypto.
- live restart automation.
- full FIX translation.

This seed incorporates reviewer response from
`rfc_ledgr_oms_seed_response.md`.

The proposed schemas are pre-CRAN design sketches. They may change or break
before public implementation, and no compatibility promise is made until a
future spec packet binds the implementation contract.

---

## 1. Prior art and fit assessment

This section is intentionally load-bearing rather than encyclopedic.

The goal is to identify the vocabulary and invariants ledgr should borrow, and the patterns it should reject.

### 1.1 FIX protocol

FIX is the vocabulary source.

The relevant FIX concepts are `ExecutionReport(35=8)`, `ExecType(150)`, `OrdStatus(39)`, and the quantity fields `OrderQty(38)`, `CumQty(14)`, `LastQty(32)`, and `LeavesQty(151)`.

FIX makes a crucial distinction: `ExecType` says why an execution report was sent, while `OrdStatus` says the order's current state after that event.

That distinction should be copied into ledgr.

It prevents the common design mistake of treating an event name as the complete order state.

A fill event can have one event meaning and leave the order in a partially-filled or filled state.

A cancel request can create a pending-cancel state without meaning the order has actually been canceled.

A rejection can happen before or after an order was acknowledged.

FIX also defines the lifecycle as broader than fills.

Its order-state material covers executions, cancellations, modifications, sequencing, restatements, rejections, status requests, multi-day orders, IOC/FOK orders, execution corrections/cancels, and trading halts.

ledgr should not implement this whole surface.

It should borrow the status vocabulary and the event-versus-state model.

Fit with ledgr:

- Use FIX-aligned names where possible.
- Store both event type and resulting order status.
- Store original quantity, cumulative quantity, last quantity, and leaves quantity.
- Keep `PendingCancel` and `PendingReplace` semantics distinct from terminal `Canceled` and `Replaced`.
- Preserve terminal states as explicit states, not as missing rows.

Rejections:

- Do not implement raw FIX messages in core.
- Do not expose numeric FIX tags as the ledgr public API.
- Do not implement multi-day, IOC/FOK, replacements, corrections, and trading halts in the first release.
- Do not confuse broker protocol translation with the internal ledgr domain model.

References:

- [FIX-STATE] FIX Trading Community, Order State Changes, https://www.fixtrading.org/online-specification/order-state-changes/

### 1.2 quantstrat and blotter

The closest R prior art is `quantstrat` plus `blotter`.

`quantstrat::addOrder()` is explicitly about modeling a real trading environment rather than assuming instant execution.

Its documentation separates rules, orders, delays, and transactions.

It also recognizes order types such as market, limit, stop-limit, stop-trailing, and iceberg, and order statuses such as open, closed, canceled, revoked, and replaced.

`blotter::addTxn()` represents transaction-level accounting and position/P&L effects.

That split is useful.

For ledgr, the important lesson is that orders and transactions are not the same object.

Orders express intent and lifecycle.

Transactions/fills express accounting changes.

Fit with ledgr:

- Borrow the separation of orders and transactions.
- Borrow the idea that backtests should not assume every decision instantly becomes a transaction.
- Borrow the R user expectation that an order layer can exist above an accounting transaction layer.

Rejections:

- Do not use mutable global environments as the primary state model.
- Do not let strategy code own the order book.
- Do not use order mutation as the audit trail.
- Do not make reproducibility depend on ambient R session state.
- Do not make OMS state inseparable from portfolio accounting state.

ledgr's positioning relative to quantstrat should be plain:

quantstrat/blotter are transaction-oriented R backtesting infrastructure with an order book and portfolio accounting.

ledgr should be a deterministic, sealed-snapshot, event-sourced research-to-paper architecture.

The overlap is real, but the contract is stricter.

References:

- [QUANTSTRAT-ADDORDER] quantstrat `addOrder`, https://www.rdocumentation.org/packages/quantstrat/versions/0.16.7/topics/addOrder
- [BLOTTER-ADDTXN] blotter `addTxn`, https://rdrr.io/rforge/blotter/man/addTxn.html

### 1.3 backtrader

backtrader has a clear broker/order mental model.

Orders translate strategy decisions into messages suitable for a broker.

The user can create, cancel, and receive notifications about orders.

The order execution documentation also makes the causality point ledgr already enforces: the current data has already happened and cannot be used for same-bar execution.

For market orders in backtrader, the next opening price is the natural first executable price.

backtrader also has `order_target_size`, `order_target_value`, and `order_target_percent`, inspired by Zipline.

That target family is close to ledgr's target-vector mental model.

The engine computes whether the target requires a buy or sell and by how much.

Fit with ledgr:

- Borrow the target-to-order bridge.
- Borrow the explicit causality rule for next-bar execution.
- Borrow the idea that an order object can be a structured intent record.
- Borrow the idea that pending order state matters.

Rejections:

- Do not move ledgr strategy functions toward OOP strategy subclasses.
- Do not make strategies retain order references.
- Do not call broker callbacks from the strategy scope.
- Do not require the user to manually suppress repeated target emissions because an order is pending.
- Do not put a mutable broker object inside `ctx`.

References:

- [BACKTRADER-ORDER] backtrader Orders, https://www.backtrader.com/docu/order/
- [BACKTRADER-EXECUTION] backtrader Order Creation/Execution, https://www.backtrader.com/docu/order-creation-execution/order-creation-execution/
- [BACKTRADER-TARGET] backtrader Target Orders, https://www.backtrader.com/docu/order_target/order_target/

### 1.4 Zipline

Zipline is spiritually close to ledgr because of its target APIs.

`order_target()` adjusts a position to a target share amount.

`order_target_value()` adjusts to a target asset value.

`order_target_percent()` adjusts to a target portfolio percentage.

Zipline's documentation also warns that target orders do not account for open orders.

Two target calls before the first is filled can over-order.

That warning is directly relevant to ledgr.

If ledgr adds OMS semantics, open order state must be engine-owned.

The strategy should continue returning desired state.

The engine should decide whether an outstanding order already covers the target delta.

Fit with ledgr:

- Borrow target-to-order translation as an engine concern.
- Borrow trading controls as adapter/policy gates: long-only, max leverage, max order count, max order size, max position size.
- Borrow the explicit concept of open orders.

Rejections:

- Do not expose single-asset imperative order APIs as the primary ledgr strategy contract.
- Do not make repeated target emissions accidentally double outstanding order quantity.
- Do not let paper/live safety be optional strategy-side discipline.

References:

- [ZIPLINE-API] Zipline API Reference, https://zipline.ml4trading.io/api-reference.html

### 1.5 NautilusTrader

NautilusTrader is the strongest architecture analog.

It has an explicit research-to-live parity philosophy.

It uses deterministic event-driven execution.

It separates strategy, risk, execution, data, portfolio, and cache responsibilities.

It routes backtest orders to simulated execution and live orders to venue adapters while preserving the same kernel semantics.

Its live reconciliation documentation is especially relevant.

It treats reconciliation as alignment between venue reality and the system's internal event-built state.

It distinguishes in-flight orders awaiting acknowledgement, pending updates, and pending cancels.

It generates or applies missing events during reconciliation and refuses startup when reconciliation fails.

Fit with ledgr:

- Borrow research-to-live parity as an architecture requirement.
- Borrow deterministic event processing as a core value.
- Borrow separation of strategy, risk, execution, data, portfolio/accounting, and reconciliation.
- Borrow the idea that adapter substitution happens at a boundary, not inside strategies.
- Borrow the principle that reconciliation is an engine/adapter obligation, not a strategy feature.

Rejections:

- Do not clone the full Nautilus component model in R.
- Do not import venue-rich order-type complexity into the first ledgr OMS pass.
- Do not add a threaded order manager to ledgr's first OMS layer.
- Do not broaden into high-frequency execution, order book simulation, or venue-specific order semantics.
- Do not rewrite ledgr as a Rust/Python-style OOP event bus.

References:

- [NAUTILUS-ARCH] NautilusTrader Architecture, https://nautilustrader.io/docs/latest/concepts/architecture/
- [NAUTILUS-ORDERS] NautilusTrader Orders, https://nautilustrader.io/docs/latest/concepts/orders/
- [NAUTILUS-EVENTS] NautilusTrader Events, https://nautilustrader.io/docs/latest/concepts/events/
- [NAUTILUS-LIVE] NautilusTrader Live / Reconciliation, https://nautilustrader.io/docs/latest/concepts/live/
- [NAUTILUS-WHY] Why NautilusTrader Exists, https://nautilustrader.io/blog/why-nautilustrader-exists/

### 1.6 Industry literature invariants

The industry literature is useful only if reduced to data-model invariants.

Harris gives the microstructure baseline: orders have types, terms, priority, execution uncertainty, and market context.

Almgren-Chriss gives the cost/execution split: execution has temporary and permanent market impact considerations, and implementation choices affect realized cost.

Pedersen reinforces that trading costs and funding/liquidity constraints determine whether an apparent strategy survives implementation.

Hendershott, Jones, Menkveld, and Riordan emphasize that algorithmic execution is about order submissions, cancellations, and trades, not merely final positions.

The invariants ledgr should take are narrow:

- An order is not a fill.
- An order's lifecycle must survive partial progress.
- A fill changes accounting state.
- A cancellation request is not the same as a cancellation confirmation.
- A rejected order may occur before or after acknowledgement.
- Cost application and liquidity feasibility are not the same concern.
- The order lifecycle must carry enough quantity state to explain what remains open.
- Reconciliation must compare internal state to external reality, not assume the internal ledger is sufficient.

References:

- [HARRIS] Larry Harris, *Trading and Exchanges*, https://books.google.com/books/about/Trading_and_Exchanges.html?id=Rd9hDRR1Yx4C
- [ALMGREN-CHRISS] Almgren and Chriss, *Optimal Execution of Portfolio Transactions*, https://quantitativebrokers.com/s/Optimal-Execution-of-Portfolio-Transaction-_-AlmgrenChriss-1999.pdf
- [PEDERSEN] Lasse Heje Pedersen, *Efficiently Inefficient*, https://www.jstor.org/stable/j.ctt1287knh
- [HENDERSHOTT-JONES-MENKVELD] Hendershott, Jones, and Menkveld, *Does Algorithmic Trading Improve Liquidity?*, https://faculty.haas.berkeley.edu/hender/algo.pdf
- [HENDERSHOTT-RIORDAN] Hendershott and Riordan, *Algorithmic Trading and Information*, https://people.stern.nyu.edu/bakos/wise/papers/wise2009-3b2_paper.pdf

---

## 2. ledgr constraints the OMS design must preserve

### 2.1 Execution constraints

There is one canonical execution path.

Public convenience APIs may build config.

They may not implement alternate pulse, fill, ledger, feature, or replay semantics.

`ledgr_run()` and `ledgr_sweep()` must call the same fold core.

Sweep mode may use a lighter output handler.

Sweep mode may skip DuckDB persistence.

Sweep mode may keep only summaries.

Sweep mode may not change strategy semantics.

Sweep mode may not change target validation.

Sweep mode may not change feature values.

Sweep mode may not change pulse order.

Sweep mode may not change fill timing.

Sweep mode may not change cost semantics.

Sweep mode may not change state transitions.

Sweep mode may not change final-bar behavior.

Sweep mode may not change event-stream meaning.

The fold core owns pulse order.

The fold core owns context construction.

The fold core owns feature lookup.

The fold core owns strategy invocation.

The fold core owns target validation.

The fold core owns the future target-risk slot.

The fold core owns fill timing.

The fold core owns cost resolution.

The fold core owns cash, position, and strategy-state transitions.

The fold core owns the canonical in-memory event stream.

The output handler materializes fold outputs.

The output handler must not reinterpret prices, fees, cash deltas, or cost metadata.

### 2.2 Strategy constraints

A strategy is a function of `(ctx, params)`.

`ctx` is pulse-known decision-time state.

`params` is JSON-safe strategy parameter state.

A strategy returns a full named numeric target vector.

Strategies do not return orders.

Strategies do not return signals.

Strategies do not return deltas.

Strategies do not manage order lifecycle.

Missing targets are not silently zero.

`ctx$flat()` creates a full target vector initialized to zero.

`ctx$hold()` creates a full target vector initialized to current holdings.

Future OMS state must not become part of strategy state.

Future broker state must not become part of strategy state.

Future reconciliation state must not become part of strategy state.

### 2.3 Accounting constraints

ledgr records backtests as accounting evidence first.

`ledger_events` says what actually filled or changed accounting state.

Fills are execution rows derived from ledger events.

Trades are fill rows that close quantity.

Equity rows value the portfolio through time.

Metrics are formulas over public result tables.

`ledger_events` remains the accounting source of truth.

OMS lifecycle events must not silently enter the ledger and change accounting result behavior.

Derived views must continue to know exactly which event rows affect positions, cash, P&L, and metrics.

### 2.4 Snapshot and reproducibility constraints

Sealed snapshots are immutable input evidence.

A committed research run is reproducible from sealed snapshot, strategy, params, features, opening state, universe, execution options, and seed.

A paper or live decision is not necessarily reconstructible from a sealed snapshot.

Paper/live decisions therefore need explicit target-decision persistence.

Research/sweep target decisions do not need default persistence because they are reconstructible and storage-heavy.

### 2.5 Scope constraints

v0.1.8.4 is not an OMS release.

v0.1.9 is target risk.

v0.1.9.x includes walk-forward evaluation before OMS and paper-trading work.

v0.1.9.x / v0.2.0 is the planned public transaction-cost model API window.

v0.2.x is the proposed OMS data-model and state-machine planning window.

The first OMS design is not paper trading.

The first OMS design is not live trading.

The first OMS design is not a public liquidity API.

The first OMS design is not a public cost API.

The first OMS design should preserve the current synchronous fill behavior by default.

The first OMS design should not make full order lifecycle persistence the default artifact for ordinary research runs until telemetry and review justify that promotion.

---

## 3. Problem statement

Current ledgr backtests have fill semantics but not order semantics.

The current engine can answer:

```text
Given a target delta and execution assumptions, what simulated fill event should be recorded?
```

It cannot yet answer:

```text
What order was intended?
Was that order submitted?
Was it accepted?
Was it partially filled?
Was it canceled?
Was it rejected?
Was it replaced in a future replacement-capable workflow?
Was broker state reconciled in a future paper/live adapter workflow?
Which order lifecycle event caused this accounting fill?
```

That gap is acceptable for deterministic target-vector research.

It is not acceptable for paper/live workflows.

Paper/live requires asynchronous state.

Broker APIs return acknowledgements, rejections, partial fills, cancels, and status updates.

Network or process failures can lose messages.

Restart safety requires reconciliation.

A broker may report state that differs from ledgr's expected state.

The design challenge is to add these concepts without changing the strategy contract and without creating a second execution engine.

---

## 4. Thesis

OMS semantics should be added as a fold-owned lifecycle layer between target deltas and accounting fills.

The ledgr strategy should remain a desired-state policy.

The engine should remain responsible for translating desired state into executable intent.

The OMS layer should represent that intent and its lifecycle.

The accounting ledger should record only accounting consequences.

The result tables should continue deriving accounting views from `ledger_events`.

Order lifecycle inspection should derive from `order_events`.

Reconciliation should compare `order_events`, `ledger_events`, and external broker reports.

The initial OMS model should be a synchronous research-compatible degenerate case.

That makes the current fill path the simplest OMS lifecycle rather than a competing engine.

---

## 5. Explicit non-goals

This RFC seed does not define broker adapters.

This RFC seed does not define Interactive Brokers, Alpaca, Binance, Schwab, or any other vendor integration.

This RFC seed does not define live trading implementation.

This RFC seed does not define paper trading implementation.

This RFC seed does not define a public cost-model API.

This RFC seed does not define a public liquidity/capacity API.

This RFC seed does not define a public order-entry API for strategies.

This RFC seed does not expose `ctx$order()`.

This RFC seed does not expose `ctx$cancel()`.

This RFC seed does not support intraday-specific semantics.

This RFC seed does not support HFT or tick-by-tick execution.

This RFC seed does not support multi-currency accounting.

This RFC seed does not support futures, options, FX, crypto, or venue-specific market structure.

This RFC seed does not support margin or broker-style short-selling contracts beyond current ledgr support.

This RFC seed does not support limit-order-book simulation.

This RFC seed does not support replacement chains as a first-class public workflow.

This RFC seed does not support automatic order slicing.

This RFC seed does not support smart order routing.

This RFC seed does not support execution algorithms such as VWAP, TWAP, POV, or arrival-price algos.

This RFC seed does not let exploratory sweep output launch paper/live trading.

This RFC seed does not store full target decisions for research sweeps by default.

---

## 6. Core vocabulary

### 6.1 Target decision

A target decision is the strategy's full desired holdings vector at one pulse.

It is not an order.

It is not an accounting event.

It is not a fill.

In research mode, it is reconstructible by replaying the sealed experiment.

In paper/live mode, it is an audit record and must be persisted.

Once target-risk transforms exist, a target decision must distinguish the raw
strategy target from the post-risk/orderable target.

OMS order-intent construction consumes the post-risk/orderable target.

The raw target remains necessary audit evidence because it explains what the
strategy asked for before policy gates changed or rejected it.

### 6.2 Target delta

A target delta is the difference between post-risk/orderable target quantity and current engine-known position quantity.

The fold core computes it.

The strategy does not compute it.

A zero delta produces no order intent.

A non-zero delta is the input to the future OMS order-intent step.

### 6.3 Order intent

An order intent is the engine's deterministic representation of what it intends to execute to satisfy a target delta.

For v1 OMS, an order intent is a market, next-open, single-instrument order.

An order intent has an `order_id`.

An order intent has side.

An order intent has quantity.

An order intent has instrument.

An order intent has timing policy.

An order intent has source pulse.

An order intent may link back to a target decision in paper/live modes.

Order intent is the first OMS lifecycle event.

### 6.4 Order event

An order event is an append-only lifecycle record for one order.

It has an event type.

It has a resulting order status.

It may have a FIX-aligned execution type.

It has cumulative quantity state where applicable.

It may link to a ledger event when the lifecycle event causes accounting impact.

### 6.5 Ledger event

A ledger event is an append-only accounting record.

It records fills, fees, cashflows, and future accounting events.

It is the source of truth for derived fills, trades, equity, and metrics.

It is not the source of truth for order lifecycle.

### 6.6 Fill proposal

A fill proposal is the timing-model output between order intent and cost
resolution.

It records the proposed side, quantity, execution timestamp, and execution
bar/reference price before costs resolve the final fill intent.

A fill proposal has a deterministic `proposal_id`.

The `proposal_id` is the audit bridge from target delta and order intent to
the cost-resolved fill intent and resulting ledger event.

For v1 synchronous research diagnostics, one order intent normally produces
one fill proposal.

Future liquidity and execution policies may fan one order intent into multiple
proposals or produce no proposal.

### 6.7 Fill intent

A fill intent is the current internal post-cost object that becomes a ledger fill event.

The cost resolver operates before output handlers see events.

The OMS layer must not move cost application into output handlers.

### 6.8 Execution report

An execution report is an external or simulated report about order lifecycle progress.

In ledgr's internal model, execution reports are normalized into `order_events`.

The core should not expose raw broker-specific execution-report formats.

FIX terminology should inform normalized field names and statuses.

---

## 7. Bound design decisions

### 7.1 Separate order lifecycle stream

Decision:

```text
ledger_events remains accounting truth.
order_events is the new lifecycle stream.
```

Rationale:

The existing ledger schema, metric pipeline, hash chain, and result contracts depend on `ledger_events` meaning accounting.

Mixing lifecycle rows into `ledger_events` would widen the surface area of accounting replay.

A separate stream lets ledgr iterate on OMS lifecycle without destabilizing current accounting artifacts.

Long-term, a typed-domain event table may be cleaner.

That should be a deliberate v0.3.x refactor, not the first OMS step.

### 7.2 Target-decision persistence by mode

Decision:

```text
research/sweep: target decisions are not persisted by default.
paper/live: target decisions must be persisted.
```

Rationale:

Research target decisions are reconstructible from sealed evidence and deterministic execution inputs.

Persisting every target vector for every sweep candidate would explode storage.

Paper/live target decisions are not fully reconstructible because the data feed and broker state are time-varying external inputs.

Paper/live target decisions are therefore audit records.

This should be a mode-level policy.

Do not make it a casual per-call flag.

### 7.3 Strategy state is user memory only

Decision:

OMS state must not be stored in `strategy_state`.

Broker reconciliation state must not be stored in `strategy_state`.

Accounting state must not be stored in `strategy_state`.

`strategy_state` remains opaque user strategy memory.

The engine does not read it for OMS decisions.

### 7.4 Pre-OMS `FILL_PARTIAL` cleanup

Decision:

Route the current `FILL_PARTIAL` mismatch as a small cleanup ticket before OMS implementation.

Delete stale `FILL_PARTIAL` reader support.

Do not add `FILL_PARTIAL` to the `ledger_events` DDL.

Do not let the OMS RFC explain around a vestigial mismatch.

The OMS design assumes a clean baseline.

Partial fills remain central to future OMS semantics.

Future partial fills should be represented as multiple ordinary `FILL`
accounting rows linked to `ORDER_PARTIAL_FILL` / `ORDER_FILLED` lifecycle
events, not as a second accounting event type.

### 7.5 First OMS scope

Decision:

The first OMS model is EOD equities only.

It is single asset class.

It is daily bars.

It is next-open fills.

It is single currency.

It has no margin.

It has no broker-style shorting contract.

Current ledgr arithmetic can represent negative quantities internally, but v1
OMS should not make shorting, borrow, locate, margin, or recall semantics public
without a separate RFC.

It has no futures.

It has no options.

It has no FX.

It has no crypto.

It has no limit-order-book semantics.

### 7.6 Sequencing

Decision:

```text
v0.1.9             chainable target-risk transforms
v0.1.9.x           walk-forward evaluation before OMS and paper-trading work
v0.1.9.x/v0.2.0    public cost API
v0.2.x             OMS data model and lifecycle state machine
v0.2.x             public liquidity/execution policy API, coordinated with OMS
v0.3.0+            paper adapter, then live adapter
```

Rationale:

Keep the roadmap order explicit.

Target-risk and walk-forward change what the engine is allowed to trade.

The public cost API is quantity-preserving and should stabilize before OMS.

OMS then gives later liquidity, paper, and live work a lifecycle substrate.

Keep the synchronous default unchanged.

Only after OMS semantics are stable should paper/live adapters become public
release scope.

### 7.7 Safety gates are adapter/policy gates

Decision:

Strategies remain pure target-vector functions.

Safety gates live in adapter/policy layers.

Paper/live mode requires deliberate arming.

Paper/live mode requires reconciliation before order submission.

Paper/live mode cannot be launched directly from exploratory sweep output.

---

## 8. Proposed lifecycle model

### 8.1 Minimal v1 lifecycle

The minimal v1 lifecycle is:

```text
NO_ORDER
  -> ORDER_INTENT
  -> ORDER_ACCEPTED
  -> ORDER_FILLED
```

Optional branches are:

```text
ORDER_ACCEPTED
  -> ORDER_PARTIAL_FILL
  -> ORDER_PARTIAL_FILL
  -> ORDER_FILLED
```

```text
ORDER_INTENT
  -> ORDER_REJECTED
```

```text
ORDER_ACCEPTED
  -> ORDER_CANCEL_REQUESTED
  -> ORDER_CANCELED
```

```text
ORDER_ACCEPTED
  -> ORDER_PARTIAL_FILL
  -> ORDER_CANCEL_REQUESTED
  -> ORDER_CANCELED
```

Each state transition is represented by an append-only event.

There is no mutable order row that acts as truth.

A latest-order-state view may be derived.

### 8.2 Event type versus order status

`order_event_type` is the reason this row exists.

`order_status` is the resulting order state after this row.

This mirrors the FIX distinction between `ExecType` and `OrdStatus`.

Active v1 examples:

| order_event_type | resulting order_status | Notes |
| --- | --- | --- |
| ORDER_INTENT | PENDING_NEW | Engine created intent. |
| ORDER_ACCEPTED | NEW | Simulated accept or broker acknowledgement. |
| ORDER_PARTIAL_FILL | PARTIALLY_FILLED | Fill occurred and leaves quantity remains. |
| ORDER_FILLED | FILLED | Fill completed the order. |
| ORDER_CANCEL_REQUESTED | PENDING_CANCEL | Cancel requested; not terminal. |
| ORDER_CANCELED | CANCELED | Cancel confirmed. |
| ORDER_REJECTED | REJECTED | Order rejected. |

Reserved future examples:

| order_event_type | resulting order_status | Notes |
| --- | --- | --- |
| ORDER_EXPIRED | EXPIRED | Future, not v1 default. |
| ORDER_DONE_FOR_DAY | DONE_FOR_DAY | Future, not v1 default. |

The event names are ledgr domain names.

The statuses are FIX-aligned status names.

Partial-fill naming is bound for v1:

```text
event type: ORDER_PARTIAL_FILL
status:     PARTIALLY_FILLED
```

Event names use action phrases. Status names use state/adjective phrases.

### 8.3 Quantity invariants

Every lifecycle event after intent should support these quantity fields:

- `order_qty`
- `cum_qty`
- `last_qty`
- `leaves_qty`

At intent:

```text
order_qty  = requested quantity
cum_qty    = 0
last_qty   = 0 or NULL
leaves_qty = requested quantity
```

At partial fill:

```text
cum_qty    increases
last_qty   equals this event's executed quantity
leaves_qty = order_qty - cum_qty
status     = PARTIALLY_FILLED when leaves_qty > 0
```

At filled:

```text
cum_qty    = order_qty
last_qty   > 0
leaves_qty = 0
status     = FILLED
```

At canceled after no fill:

```text
cum_qty    = 0
last_qty   = 0 or NULL
leaves_qty = 0
status     = CANCELED
```

At canceled after partial fill:

```text
0 < cum_qty < order_qty
last_qty   = 0 or NULL
leaves_qty = 0
status     = CANCELED
```

A canceled order may have fills.

The unfilled quantity of a terminal canceled order is derivable as:

```text
canceled_qty = order_qty - cum_qty
```

If ledgr later needs to persist this directly, it should use a separate
`canceled_qty` field rather than assigning that meaning to `leaves_qty`.

A rejected order should have no fill accounting event.

A pending cancel may still receive fills before cancellation completes.

Filled versus partially filled classification must use a numeric tolerance, not
strict double equality. The first implementation should use the same tolerance
style as the fold delta path, currently based on `sqrt(.Machine$double.eps)`.

### 8.4 v1 state transition table

Allowed v1 transitions:

| From | To | Event |
| --- | --- | --- |
| none | PENDING_NEW | ORDER_INTENT |
| PENDING_NEW | NEW | ORDER_ACCEPTED |
| PENDING_NEW | REJECTED | ORDER_REJECTED |
| NEW | PARTIALLY_FILLED | ORDER_PARTIAL_FILL |
| NEW | FILLED | ORDER_FILLED |
| NEW | PENDING_CANCEL | ORDER_CANCEL_REQUESTED |
| NEW | REJECTED | ORDER_REJECTED |
| PARTIALLY_FILLED | PARTIALLY_FILLED | ORDER_PARTIAL_FILL |
| PARTIALLY_FILLED | FILLED | ORDER_FILLED |
| PARTIALLY_FILLED | PENDING_CANCEL | ORDER_CANCEL_REQUESTED |
| PENDING_CANCEL | CANCELED | ORDER_CANCELED |
| PENDING_CANCEL | PARTIALLY_FILLED | ORDER_PARTIAL_FILL |
| PENDING_CANCEL | FILLED | ORDER_FILLED |

Representable but non-default states:

- PENDING_REPLACE
- REPLACED
- EXPIRED
- DONE_FOR_DAY
- SUSPENDED
- CALCULATED
- ACCEPTED_FOR_BIDDING

These names may be reserved in schema enums or validation code.

They should not be public workflows in v1.

Cancel-reject and replacement races are not active v1 research workflows.

Before paper/live adapters are implemented, this table must be widened to
represent broker cancel rejection and late fills during pending cancel without
collapsing them into terminal cancellation.

### 8.5 Terminal states

Active v1 terminal states are:

- FILLED
- CANCELED
- REJECTED

A terminal state means no further execution is expected for that order.

`EXPIRED` is a reserved future terminal state.

`DONE_FOR_DAY` is reserved but should not be treated as globally terminal for
all future workflows; in FIX-inspired models it means no more executions are
expected for the trading day.

Corrections and busts are not in v1.

Reconciliation adjustments may create separate reconciliation events in later paper/live work.

---

## 9. Proposed data model

### 9.1 `order_events`

Proposed table:

This is an illustrative semantic shape, not a final migration script.

The first research-only OMS diagnostic schema may omit fields whose semantics
belong to later paper/live adapter RFCs.

```sql
CREATE TABLE order_events (
  order_event_id TEXT NOT NULL PRIMARY KEY,
  run_id TEXT NOT NULL,
  order_event_seq INTEGER NOT NULL,
  ts_utc TIMESTAMP NOT NULL,
  ts_effective_utc TIMESTAMP,
  source_pulse_seq INTEGER,

  order_id TEXT NOT NULL,
  parent_order_id TEXT,
  target_decision_id TEXT,
  proposal_id TEXT,

  order_event_type TEXT NOT NULL,
  order_status TEXT NOT NULL,
  exec_type TEXT,

  instrument_id TEXT,
  side TEXT CHECK (side IS NULL OR side IN ('BUY','SELL')),
  order_qty DOUBLE,
  cum_qty DOUBLE,
  last_qty DOUBLE,
  leaves_qty DOUBLE,

  order_type TEXT,
  time_in_force TEXT,
  limit_price DOUBLE,
  stop_price DOUBLE,

  fill_price DOUBLE,
  fill_fee DOUBLE,

  ledger_event_seq INTEGER,
  ledger_event_id TEXT,

  source TEXT NOT NULL,
  source_event_id TEXT,
  broker_order_id TEXT,
  client_order_id TEXT,

  meta_json TEXT,

  UNIQUE(run_id, order_event_seq)
);
```

The exact SQL may change.

The semantic fields should not.

### 9.2 Required field meaning

`order_event_id` is deterministic and unique inside ledgr artifacts.

The first implementation should derive it from `run_id` and
`order_event_seq`, mirroring the deterministic ledger event ID pattern.

`run_id` links to the run.

`order_event_seq` is the per-run lifecycle event sequence.

`proposal_id`, when present, should be deterministic inside the run. The first
implementation can derive it from `run_id` and a per-run proposal sequence.

`ts_utc` is the ledgr event timestamp.

`ts_effective_utc` is optional and can represent external broker event time when different from ledgr ingestion time.

For research simulation, `ts_effective_utc` should be NULL unless an explicit
diagnostic mode binds a different meaning.

`source_pulse_seq` links the order event to the decision pulse that produced it
when that relationship is available.

`order_id` links all lifecycle events for one order.

`parent_order_id` is reserved for replacement or child order structures.

`target_decision_id` links to persisted paper/live target decisions.

`proposal_id` links lifecycle fill events to the timing-model proposal that was
cost-resolved into a ledger fill. It is nullable for non-fill lifecycle events.

`order_event_type` is the event reason.

`order_status` is the resulting status.

`exec_type` is a FIX-aligned normalized execution type.

`instrument_id` is ledgr instrument identity.

`side` is BUY or SELL for v1.

`order_qty` is the original executable quantity.

`cum_qty` is cumulative filled quantity.

`last_qty` is quantity filled in this event.

`leaves_qty` is quantity remaining.

`order_type` is MARKET for v1 default.

`time_in_force` is DAY or NULL for v1 default.

`limit_price` and `stop_price` are reserved.

`fill_price` and `fill_fee` mirror fill-relevant event facts for lifecycle inspection.

`ledger_event_seq` and `ledger_event_id` link lifecycle events to accounting events.

`source` distinguishes origin, such as `research_sim`, `paper_adapter`, and
`live_adapter`.

Reconciliation is an action or producer role, not the same kind of value as an
origin. A later paper/live RFC should decide whether reconciliation gets its
own event types, a separate `produced_by` field, or a separate table.

`source_event_id` stores adapter or simulator source identity.

`broker_order_id` stores broker-side identity when available.

`client_order_id` stores ledgr/client-side order identity sent to broker.

`broker_order_id`, `client_order_id`, `parent_order_id`,
`source_event_id`, and `ts_effective_utc` are paper/live-shaped fields. They
may be omitted from the first research diagnostic schema or stored in
`meta_json` until the paper/live RFC binds their semantics.

`meta_json` stores versioned extra fields.

### 9.3 Do not use one flat universal event table yet

A single typed-domain event table is attractive.

It would allow all events to share a sequence, timestamp model, and provenance envelope.

It would also force an immediate refactor of current accounting code.

That is the wrong first OMS move.

The first move should be a separate `order_events` stream.

A future unified event table should be a deliberate refactor.

### 9.4 `target_decisions`

Paper/live needs target-decision persistence.

Research/sweep does not persist target decisions by default.

Proposed table for paper/live modes:

```sql
CREATE TABLE target_decisions (
  target_decision_id TEXT NOT NULL PRIMARY KEY,
  run_id TEXT NOT NULL,
  decision_seq INTEGER NOT NULL,
  ts_utc TIMESTAMP NOT NULL,
  universe_hash TEXT,
  strategy_target_vector_json TEXT NOT NULL,
  strategy_target_vector_hash TEXT NOT NULL,
  risked_target_vector_json TEXT,
  risked_target_vector_hash TEXT,
  current_positions_json TEXT,
  strategy_params_hash TEXT,
  strategy_source_hash TEXT,
  feature_set_hash TEXT,
  risk_chain_hash TEXT,
  risk_audit_json TEXT,
  data_lineage_json TEXT,
  meta_json TEXT,
  UNIQUE(run_id, decision_seq)
);
```

The strategy target vector should be serialized as the full named vector.

If target-risk transforms are active, the post-risk/orderable target vector
should also be serialized.

When no risk chain is active, `risked_target_vector_json` and
`risked_target_vector_hash` are NULL and consumers treat the strategy target as
the orderable target.

When a risk chain is active, the risked vector and its hash are both present.

It should not omit zero targets.

It should not treat missing instruments as zero.

It should record enough context to audit what the strategy asked for and what
policy gates allowed the engine to turn into order intent.

It should not replace provenance.

It should not store OMS state.

This table is paper/live-scale in the first design. Daily EOD persistence is
acceptable; intraday or tick-level target-decision persistence would require a
separate storage design before becoming a public workflow.

### 9.5 Derived views

`ledgr_results(bt, what = "ledger")` should continue returning accounting ledger rows.

`ledgr_results(bt, what = "fills")` should continue deriving from accounting fill rows.

`ledgr_results(bt, what = "trades")` should continue deriving closed trade rows.

`ledgr_results(bt, what = "equity")` should continue deriving portfolio valuation.

New order inspection surfaces can be added later:

```r
ledgr_results(bt, what = "orders")
ledgr_results(bt, what = "order_events")
ledgr_results(bt, what = "target_decisions")
ledgr_order_state(bt)
ledgr_order_lifecycle(bt, order_id)
```

Do not overload `what = "ledger"` to mean all event types.

Do not make metrics accidentally sensitive to order lifecycle rows.

### 9.6 Relationship to `ledger_events`

`ledger_events` should remain recognizable.

Possible near-term additions:

```text
ledger_events.order_id          nullable
ledger_events.order_event_seq   nullable
```

If schema change is too disruptive, store the links in `meta_json` first.

The long-term model should use typed columns for links.

For v1 research diagnostics, bind the link mechanism as:

```text
- preallocate the deterministic ledger event ID before writing lifecycle rows;
- write ledger_event_id and ledger_event_seq into the lifecycle fill event;
- write order_id, order_event_seq, and proposal_id into ledger_events.meta_json;
- do not mutate already-written order_events rows.
```

This keeps the first implementation append-only and avoids adding typed columns
to `ledger_events` before OMS proves its shape.

The important rule remains semantic:

```text
order_events may link to ledger_events.
ledger_events may link to order_events.
they never share rows.
links must not require post-hoc mutation of already-written order_events rows.
```

A later schema may promote the `meta_json` ledger link fields into typed
nullable columns when order lifecycle joins become a public inspection path.

---

## 10. Fold-core integration

### 10.1 Current conceptual chain

Current ledgr conceptual chain:

```text
strategy(ctx, params)
  -> targets
  -> target validation
  -> target-risk no-op
  -> target deltas
  -> next-open fill proposal
  -> cost resolver
  -> fill intent
  -> ledger event
  -> output handler
```

### 10.2 Future OMS chain

Future OMS-aware chain:

```text
strategy(ctx, params)
  -> targets
  -> target validation
  -> target-risk chain
  -> target validation
  -> target deltas
  -> order intent construction
  -> order lifecycle simulation or adapter submission
  -> fill proposal with proposal_id / execution report normalization
  -> cost resolver
  -> fill intent
  -> ledger event with preallocated deterministic event_id
  -> lifecycle fill event carrying ledger_event_id and proposal_id
  -> output handler
```

The fold core remains the owner.

The output handler remains persistence/accumulation.

### 10.3 Default synchronous research path

The default synchronous research path should be behavior-preserving.

For each non-zero target delta:

1. Build an `ORDER_INTENT` for a MARKET next-open order.
2. Mark it `ORDER_ACCEPTED` synchronously.
3. Resolve the existing next-open fill proposal path and assign a deterministic `proposal_id`.
4. Resolve cost through the existing `ledgr_resolve_fill_proposal()` boundary.
5. Preallocate the deterministic `FILL` ledger event ID.
6. Emit `ORDER_FILLED` with `proposal_id`, `ledger_event_id`, and `ledger_event_seq` when the fill is complete.
7. Emit the `FILL` accounting event with `order_id`, `order_event_seq`, and `proposal_id` in `meta_json`.

If no next bar exists:

1. Build no accounting fill.
2. Preserve current final-bar no-fill behavior.
3. Decide whether an `ORDER_INTENT` should be emitted only in OMS diagnostic mode.
4. Default research behavior should not introduce confusing unfilled terminal orders on the final bar unless OMS mode is explicitly enabled.

### 10.4 Partial fills in research simulation

v1 default research simulation should not create partial fills unless explicitly configured.

The data model should support partial fills.

The default next-open fill model should keep full-fill behavior.

Liquidity policy should introduce quantity-changing behavior later.

Cost policy should not clip quantities.

### 10.5 Rejections in research simulation

Research rejections should be rare in v1.

Possible deterministic rejection causes:

- invalid target after validation.
- missing instrument.
- missing execution price.
- unsupported side.
- unsupported quantity.
- insufficient cash if cash enforcement becomes binding.

The first OMS data model should represent rejections.

It should not invent broker-like rejection behavior beyond the current research engine's actual validation semantics.

### 10.6 Outstanding orders and repeated targets

Once asynchronous paper/live enters scope, the engine must account for outstanding orders when translating targets to intents.

The strategy can emit the same target on every pulse.

That must not double-order.

Engine-owned target-to-order logic should compute desired exposure relative to:

- current accounting position.
- accepted-but-unfilled order quantity.
- pending-cancel state.
- pending-new state.
- partially filled leaves quantity.

For asynchronous modes, order intent quantity should be derived from:

```text
post-risk target - current accounting position - engine-known outstanding net order quantity
```

The synchronous research path has no persistent outstanding order after the
pulse completes, so the first diagnostic implementation can keep the current
target-delta behavior while reserving this invariant for paper/live.

This is the main reason OMS state must be engine-owned.

---

## 11. Research, sweep, paper, and live mode behavior

### 11.1 Research committed run

Research committed runs use sealed snapshots.

Research committed runs are reproducible.

Research committed runs need not persist target decisions by default.

Research committed runs may eventually persist order events if OMS mode is enabled or once OMS data model becomes standard.

The first implementation should treat research order-event persistence as
diagnostic/explicit, not as a default artifact for every committed research run.

Research committed runs should not change public metrics when OMS rows are added.

### 11.2 Sweep candidates

Sweeps are exploratory.

Sweeps use the same fold core.

Sweeps may use a memory output handler.

Sweeps should not persist target decisions.

Sweeps should not persist full order events by default.

Sweeps may keep compact lifecycle warning summaries.

Sweeps must not become a second OMS simulator.

Sweep promotion remains the path to committed artifacts.

The suppression gate belongs at the output-handler / retention-policy
boundary.

The memory output handler used by sweeps should discard full `order_events`
unless a future diagnostic mode explicitly asks for them.

The persistent DuckDB output handler should write `order_events` only when the
run mode and retention policy enable diagnostic OMS artifacts.

### 11.3 Paper runs

Paper runs are not pure sealed-snapshot research runs.

Paper runs must persist target decisions.

Paper runs must persist order events.

Paper runs must persist accounting ledger events for simulated or broker-paper fills.

Paper runs must perform reconciliation before trading.

Paper runs must require explicit arming.

Paper runs must not launch directly from sweep output.

### 11.4 Live runs

Live runs inherit paper requirements.

Live runs also require stricter arming.

Live runs require broker cash and position reconciliation before order submission.

Live runs require clock and data freshness checks.

Live runs require per-order safety gates.

Live runs require runtime kill controls.

Live runs must abort on unreconciled mismatch in v1.

Live runs must not auto-reconcile by trading unless a later RFC explicitly permits that.

---

## 12. Safety gates

Safety gates are adapter/policy responsibilities.

They are not strategy responsibilities.

### 12.1 Arming

Paper/live mode requires explicit arming.

A config flag is insufficient.

Proposed shape:

```r
ledgr_arm_live(broker, mode = "paper")
ledgr_arm_live(broker, mode = "live")
```

The exact function name is not binding.

The separate deliberate action is binding.

### 12.2 Pre-flight gates

Before any paper/live order:

- reconcile broker cash.
- reconcile broker positions.
- reconcile broker open orders.
- check snapshot/live-data lineage.
- check current bars match ledgr's view of now.
- check clock freshness.
- abort on mismatch.
- do not auto-reconcile in v1.

### 12.3 Per-order gates

Before any paper/live order submission:

- max order notional.
- max daily turnover.
- max position size per instrument.
- max gross exposure.
- max net exposure.
- long-only gate where applicable.
- no-trade restricted instrument list if supported.

### 12.4 Runtime gates

During paper/live run:

- kill switch.
- stale data stop.
- stale broker response stop.
- repeated rejection stop.
- repeated reconciliation mismatch stop.
- optional drawdown circuit breaker.

### 12.5 Provenance gates

Exploratory sweep output cannot launch paper/live.

A candidate must be promoted.

The promoted run must receive an explicit reproducibility-level upgrade or deployment approval marker.

Paper/live launch must refer to a committed artifact.

No accidental sweep-to-live pipeline is allowed.

---

## 13. Reconciliation boundaries

Reconciliation is future adapter work.

The data model must leave room for it.

### 13.1 Reconciliation inputs

A future adapter should report:

- broker order status reports.
- broker fill reports.
- broker position reports.
- broker cash reports.
- broker account constraints.
- broker clock or server time where available.

### 13.2 Reconciliation outputs

A future ledgr reconciliation layer may produce:

- reconciliation warnings.
- reconciliation aborts.
- missing order lifecycle events.
- missing fill lifecycle events.
- accounting discrepancy reports.
- external-order observations.

v1 should not auto-trade to reconcile.

v1 should abort on material mismatch.

### 13.3 Reconciliation event storage

Do not store reconciliation in `strategy_state`.

Do not store reconciliation-only observations as accounting ledger fills unless they represent accepted accounting adjustments.

Possible future table:

```text
reconciliation_events
```

or future reconciliation-specific order event types with a separate
producer/origin field.

Accounting corrections require a separate accounting RFC.

---

## 14. Public API direction

### 14.1 Do not expose order entry to strategies

Do not add:

```r
ctx$order()
ctx$buy()
ctx$sell()
ctx$cancel()
```

These would break the strategy-as-policy contract.

They would also pull order state into strategy code.

### 14.2 Possible internal constructors

Internal constructors may include:

```r
ledgr_order_intent(...)
ledgr_order_event(...)
ledgr_order_status(...)
ledgr_order_lifecycle_validate(...)
```

These should remain internal until the data model stabilizes.

### 14.3 Possible inspection APIs

Public inspection APIs may include:

```r
ledgr_order_events(bt)
ledgr_orders(bt)
ledgr_order_lifecycle(bt, order_id)
ledgr_target_decisions(bt)
```

These should be read-only.

They should not mutate the backtest object.

They should not mutate persistent state.

### 14.4 Mode and retention shape

A future execution-mode distinction could look like:

```r
ledgr_run(exp, params, run_id, mode = "research")
ledgr_run(exp, params, run_id, mode = "paper")
ledgr_run(exp, params, run_id, mode = "live")
```

The exact API is not binding.

The mode-level policy is binding.

Target-decision persistence should follow mode.

Paper/live safety should follow mode.

Retention should be a separate concept.

For example, research mode might later support diagnostic order-event retention
without becoming paper/live mode.

---

## 15. Testing implications

### 15.1 State-machine tests

Tests should verify allowed transitions.

Tests should reject invalid transitions.

Tests should distinguish `PENDING_CANCEL` from `CANCELED`.

Tests should distinguish `PARTIALLY_FILLED` from `FILLED`.

Tests should verify that a canceled partially filled order preserves fill history.

Tests should verify that a rejected order has no accounting fill.

### 15.2 Accounting isolation tests

Tests should verify that adding order lifecycle rows does not change ledger-derived fills.

Tests should verify that metrics ignore order lifecycle rows.

Tests should verify that equity is derived from accounting events.

Tests should verify that result tables remain stable for current backtests.

### 15.3 Fold parity tests

Tests should verify `ledgr_run()` and `ledgr_sweep()` still share fold semantics.

Tests should verify memory output handler and DB output handler see semantically equivalent accounting events.

Tests should verify order-event support does not create a second target-delta engine.

Tests should verify that sweep memory output handlers discard full lifecycle
rows by default while persistent handlers write them only when the selected
mode and retention policy enable diagnostic OMS artifacts.

Before diagnostic OMS rows can become a default research artifact, the
implementation spec must include a telemetry gate for pulse/runtime overhead
and artifact-size growth.

### 15.4 Replay tests

Research replay should reconstruct the same target deltas and fills from sealed inputs.

If order-event diagnostics are enabled, research replay should reconstruct the
same `order_event_seq` sequence and deterministic order event IDs.

Paper/live replay should read persisted target decisions and order events.

Reconciliation tests should wait until adapter design.

### 15.5 Cleanup tests

Before OMS work, route the `FILL_PARTIAL` mismatch.

Test the deletion of stale `FILL_PARTIAL` reader support.

Do not leave stale derived-fill branches around the OMS implementation.

---

## 16. Migration and rollout

### 16.1 Pre-OMS cleanup

Ticket: delete stale current `FILL_PARTIAL` reader support.

Ticket: document that partial-fill lifecycle semantics are not active until OMS/liquidity policy introduces them, and that accounting remains ordinary `FILL` rows.

Ticket: verify `ledger_events` result derivation remains accounting-only.

### 16.2 Data model phase

Ticket: add `order_events` table for explicit/diagnostic research OMS mode.

Ticket: add internal order-event constructors.

Ticket: add deterministic `proposal_id` construction for timing proposals that produce fill intents.

Ticket: add lifecycle validation.

Ticket: add read-only inspection helpers behind internal or experimental surface.

Ticket: add schema tests.

### 16.3 Fold degenerate path phase

Ticket: insert order-intent construction after target delta.

Ticket: simulate synchronous accept/fill in explicit research OMS diagnostic path.

Ticket: link lifecycle fill events to ledger fills using preallocated deterministic ledger event IDs and ledger `meta_json` back-links.

Ticket: preserve current default public results.

Ticket: test no change in current examples unless order-event inspection is requested.

### 16.4 Paper/live preparatory phase

Ticket: add `target_decisions` persistence for paper/live modes.

Ticket: add arming contract placeholder.

Ticket: add adapter safety-gate interface sketch.

Ticket: add reconciliation input/output placeholder design.

Do not implement broker adapters in this phase.

---

## 17. Recommended first ticket packet

1. Pre-OMS cleanup for `FILL_PARTIAL` mismatch.
2. Add `order_events` schema and schema-version handling.
3. Add internal event/status enumerations.
4. Add lifecycle transition validator.
5. Add internal order-intent constructor for target deltas.
6. Add deterministic proposal IDs for next-open timing proposals.
7. Add degenerate synchronous OMS path behind non-public diagnostic feature flag or experiment option.
8. Link lifecycle fill events to ledger fill events using the v1 immutable link mechanism.
9. Add order-event inspection helper for development tests.
10. Add accounting isolation tests.
11. Add fold parity tests.
12. Add docs note explaining order lifecycle versus accounting ledger.
13. Add open-question review before public API exposure.

---

## 18. Open questions for maintainer review

1. What evidence and telemetry gate should promote explicit OMS diagnostic rows into default committed research artifacts, if ever?

2. Should `target_decisions` be a real table immediately, or deferred until the paper/live RFC?

3. Should the v1 status enum reserve future FIX-aligned statuses even if validation does not allow them yet?

4. Should `ORDER_CANCEL_REQUESTED` be in the first data model even though default synchronous research fills will almost never use it?

5. Should `ORDER_REPLACED` and `PENDING_REPLACE` be reserved but invalid in v1, or omitted entirely until a replace RFC?

6. Should `ORDER_ACCEPTED` be emitted in research synchronous mode, or should `ORDER_INTENT` go directly to `ORDER_FILLED` for compactness?

7. Should `ORDER_INTENT` use resulting status `PENDING_NEW` or `NEW` in research simulation?

8. Should paper/live target-decision persistence serialize full target vectors, sparse non-zero vectors plus universe hash, or both?

9. Should `source` values be fixed enum strings at schema level or validated in R constructors only?

10. Should live adapter arming be modeled as a persistent event, a runtime capability object, or both?

11. Should reconciliation observations live in `order_events`, or in a separate `reconciliation_events` table?

12. Should order lifecycle sequence and accounting ledger sequence share a global per-run sequence number in the future unified event table design?

13. Should current final-bar no-fill behavior emit any OMS lifecycle row in OMS diagnostic mode?

14. What minimal outstanding-order accounting, if any, is needed before asynchronous paper/live support exists?

15. Should cash insufficiency become an order rejection, target validation failure, risk-layer clipping, or remain outside v1?

16. Should long-only enforcement live in target validation, target risk, order policy, or adapter safety gates?

17. Should simulated partial fills be introduced only with liquidity policy, or can a diagnostic fill model create them earlier?

18. What is the minimum public documentation required before any OMS table ships pre-CRAN?

---

## 19. Final recommendation

Add OMS semantics as a separate lifecycle stream after the prerequisite roadmap
gates, not as a ledger rewrite.

Keep ledgr's existing accounting ledger clean.

Keep strategies pure.

Make target-to-order translation engine-owned.

Use FIX names for statuses and event semantics where they fit.

Use quantstrat/blotter as the R comparison point, but avoid mutable global state.

Use backtrader and Zipline as target-to-order cautions, especially around open orders.

Use NautilusTrader as the architectural north star, but scale the design down to ledgr's R-native, pre-CRAN, single-maintainer scope.

The correct first OMS milestone is not broker integration.

The correct first milestone is a small, deterministic, append-only, diagnostic
order lifecycle model that can represent today's next-open fill as the simplest
possible order lifecycle without changing ordinary research artifacts by
default.
