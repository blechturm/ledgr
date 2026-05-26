# RFC Synthesis: OMS Semantics For ledgr

**Status:** Accepted synthesis - binding for the future v0.2.x OMS data-model and lifecycle planning window; non-binding for v0.1.9, v0.1.9.x, and the public cost-model API window.
**Date:** 2026-05-26
**Source RFC:** `inst/design/rfc/rfc_ledgr_oms_seed.md`
**Reviewer response:** `inst/design/rfc/rfc_ledgr_oms_seed_response.md`
**Predecessor:** `inst/design/rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md`
**North-star context:** `inst/design/rfc/rfc_execution_policy_pipeline_audit_signal_north_star.md`
**Roadmap anchor:** `inst/design/ledgr_roadmap.md` (OMS at v0.2.x; paper trading at v0.3.0; live at v1.0.0)

---

## 1. Decision Summary

OMS semantics are accepted as the v0.2.x design direction, with the data-model and lifecycle work scoped as a separate append-only stream that does not modify the existing accounting ledger contract. The strategy contract does not change. Strategies remain `function(ctx, params)` returning a full named numeric target vector. Engine-owned target-to-order translation, lifecycle state, and adapter-side safety machinery are introduced as new internal layers; none of them become public strategy APIs.

The synthesis binds the v0.2.x architecture as:

```text
strategy targets
  -> target validation
  -> target-risk chain
  -> target validation
  -> target deltas
  -> order intent construction
  -> order lifecycle simulation or adapter submission
  -> fill proposal with deterministic proposal_id
  -> cost resolver
  -> fill intent
  -> preallocate deterministic ledger_event_id
  -> lifecycle fill event carrying ledger_event_id and proposal_id
  -> ledger event carrying order back-links in meta_json
  -> output handler
```

Two append-only streams hold lifecycle truth and accounting truth respectively:

```text
order_events    order lifecycle (engine-owned)
ledger_events   accounting (unchanged contract; gains nullable meta_json back-links)
```

The streams reference each other through `run_id`, `order_id`, `order_event_seq`, `ledger_event_seq`, `ledger_event_id`, and `proposal_id`. They never share rows. Links are immutable: lifecycle fill events carry forward links into already-allocated ledger event IDs; ledger rows carry back links inside `meta_json`.

The first OMS path is a deliberately degenerate synchronous lifecycle that represents today's next-open fill as the simplest possible order lifecycle. Default research artifacts do not change. Diagnostic OMS rows are explicit/opt-in until telemetry justifies promotion to default.

---

## 2. Roadmap Sequencing

Bound sequencing (matches `ledgr_roadmap.md`):

```text
v0.1.9            chainable target-risk transforms
v0.1.9.x          walk-forward evaluation
v0.1.9.x/v0.2.0   public transaction-cost model API
v0.2.x            OMS data model and lifecycle state machine
v0.2.x            public liquidity/execution policy API, coordinated with OMS
v0.3.0+           paper adapter, then live adapter
v1.0.0            small-scale live trading
```

The synthesis does not authorize OMS work before the v0.1.9 target-risk chain ships, walk-forward evaluation stabilizes, and the public cost-model API window opens. The synthesis explicitly rejects an invented `v0.1.10` planning slot. If a future maintainer wishes to advance OMS before the v0.1.9.x prerequisites land, that requires an explicit roadmap amendment, not an in-RFC retarget.

Snapshot lineage and roll-forward data sources are adjacent v0.2.x roadmap workstreams. This synthesis does not bind their APIs or storage contracts; it only keeps the OMS design compatible with them.

---

## 3. Accepted Architecture

The synthesis binds the following architectural invariants for the v0.2.x OMS surface.

### 3.1 Strategy contract preservation

```text
strategy: function(ctx, params) -> full named numeric target vector
```

Strategies do not receive `ctx$order()`, `ctx$buy()`, `ctx$sell()`, or `ctx$cancel()`. Strategies do not retain order references. Strategies do not manage lifecycle. OMS state, broker state, and reconciliation state never live in `strategy_state`. The engine owns target-to-order translation, order-intent construction, and lifecycle transitions.

### 3.2 Single fold core

`ledgr_run()`, `ledgr_sweep()`, and any future paper/live entry points share the existing fold core. OMS is added as an additional internal layer inside that fold, not as a parallel engine. Memory and persistent output handlers continue to see semantically equivalent accounting events. The OMS layer is inserted between target deltas and ledger writing; it does not alter fill timing, cost resolution, cash and position transitions, or final-bar no-fill behavior in the default synchronous research path.

### 3.3 Two append-only streams

`ledger_events` remains accounting truth and continues to be the source for derived fills, trades, equity, and metrics. `order_events` becomes order-lifecycle truth and is the source for derived order state and lifecycle inspection. The streams never share rows. A future typed-domain unified event table is reserved for v0.3.x and is not part of the first OMS milestone.

### 3.4 Raw target versus orderable target

Once v0.1.9 target risk lands, a target decision is no longer a single vector. It is a record carrying:

- the raw strategy target vector,
- the post-risk/orderable target vector (when a risk chain is active),
- risk-chain identity and audit signals.

Order-intent construction consumes the post-risk/orderable target. The raw strategy target remains required audit evidence because it explains what the strategy asked for before policy gates changed or rejected it.

### 3.5 Engine-owned outstanding-order accounting

For asynchronous paper/live modes, order intent quantity is derived as:

```text
order intent qty = post-risk target
                 - current accounting position
                 - engine-known outstanding net order quantity
```

The synchronous research path has no persistent outstanding order after the pulse completes, so the first diagnostic implementation reserves this invariant for paper/live and continues to use the current target-delta behavior.

---

## 4. Data Model Decisions

### 4.1 `order_events`

A new append-only table holds order lifecycle rows. Semantic fields are bound; the exact SQL may evolve through implementation:

```text
order_event_id        TEXT  PRIMARY KEY, deterministic from run_id + order_event_seq
run_id                TEXT  NOT NULL
order_event_seq       INTEGER NOT NULL, per-run lifecycle sequence
ts_utc                TIMESTAMP NOT NULL, ledgr event timestamp

order_id              TEXT  NOT NULL, links all events for one order
proposal_id           TEXT  nullable for non-fill lifecycle events
source_pulse_seq      INTEGER nullable

order_event_type      TEXT  NOT NULL, ledgr domain action phrase
order_status          TEXT  NOT NULL, FIX-aligned state phrase
exec_type             TEXT  optional FIX-aligned execution type

instrument_id         TEXT
side                  TEXT  CHECK (side IS NULL OR side IN ('BUY','SELL'))
order_qty             DOUBLE
cum_qty               DOUBLE
last_qty              DOUBLE
leaves_qty            DOUBLE

order_type            TEXT  default 'MARKET' in v1
time_in_force         TEXT  default 'DAY' or NULL in v1
limit_price           DOUBLE reserved
stop_price            DOUBLE reserved

fill_price            DOUBLE
fill_fee              DOUBLE

ledger_event_seq      INTEGER nullable
ledger_event_id       TEXT    nullable

source                TEXT  NOT NULL, origin: 'research_sim' | 'paper_adapter' | 'live_adapter'
meta_json             TEXT  versioned extra fields

UNIQUE(run_id, order_event_seq)
```

Adapter-shaped columns (`broker_order_id`, `client_order_id`, `parent_order_id`, `ts_effective_utc`, `source_event_id`, `target_decision_id`) may be omitted from the first research diagnostic schema or stored in `meta_json` until the paper/live RFC binds their semantics. The schema may add them as nullable columns at that point; pre-CRAN compatibility allows schema change without migration cost.

### 4.2 Target-decision artifacts

Paper/live persists target decisions. Research and sweep do not persist target decisions by default.

The synthesis binds the logical target-decision contract, not a universal row-per-decision full-vector JSON storage shape. A target-decision artifact must let ledgr answer, under the declared mode and retention policy:

- which decision produced which order intent;
- what the strategy asked for;
- what risk allowed, if a risk chain was active;
- which universe, data lineage, strategy, params, features, and risk chain were in force.

Required logical fields:

```text
target_decision_id              TEXT  PRIMARY KEY
run_id                          TEXT  NOT NULL
decision_seq                    INTEGER NOT NULL
ts_utc                          TIMESTAMP NOT NULL
universe_hash                   TEXT
strategy_target_vector_hash     TEXT  NOT NULL
risked_target_vector_hash       TEXT  nullable
target_payload_ref              TEXT  nullable, retention-dependent
risked_target_payload_ref       TEXT  nullable, retention-dependent
current_positions_json          TEXT
strategy_params_hash            TEXT
strategy_source_hash            TEXT
feature_set_hash                TEXT
risk_chain_hash                 TEXT
risk_audit_json                 TEXT
data_lineage_json               TEXT
meta_json                       TEXT

UNIQUE(run_id, decision_seq)
```

When payloads are retained, the strategy target vector is the full named vector. It does not omit zero targets. Missing instruments are not treated as zero. When no risk chain is active, the risked target hash and payload reference are NULL and consumers treat the strategy target as the orderable target. When a risk chain is active, the risked target hash is populated and the payload reference is populated when the selected retention tier keeps the payload.

The first EOD implementation may use full-vector JSON stored directly on the decision row. That is an implementation detail, not the universal storage contract. Intraday and tick-level persistence require a separate storage design and are not part of v0.2.x. The v0.2.x schema must not force a destructive migration to support later deduplicated, sparse, columnar, or payload-reference storage.

### 4.3 Link mechanism between `order_events` and `ledger_events`

The v1 immutable link mechanism is bound as:

```text
1. The fold preallocates a deterministic ledger event ID before any lifecycle
   fill event is written.
2. The lifecycle fill event (ORDER_FILLED or ORDER_PARTIAL_FILL) carries
   ledger_event_id and ledger_event_seq.
3. The accounting ledger row carries order_id, order_event_seq, and
   proposal_id inside meta_json.
4. No already-written order_events row is mutated.
```

A future schema may promote the `meta_json` ledger link fields to nullable typed columns when order lifecycle joins become a public inspection path. That promotion is not in v0.2.x scope.

### 4.4 `proposal_id` as audit bridge

A fill proposal is the timing-model output between order intent and cost resolution. It carries a deterministic `proposal_id` derived from `run_id` and a per-run proposal sequence. The `proposal_id` is the audit bridge that joins:

```text
target delta -> order intent -> fill proposal -> fill intent -> ledger event -> lifecycle fill event
```

In v1 synchronous research, one order intent produces one fill proposal. Future liquidity and execution policies may fan one order intent into multiple proposals or produce no proposal; the data model leaves room for that without binding it in v1.

### 4.5 Derived views

The existing public surface continues to derive from `ledger_events`:

```r
ledgr_results(bt, what = "ledger")    # unchanged: accounting rows
ledgr_results(bt, what = "fills")     # unchanged: derived from FILL rows
ledgr_results(bt, what = "trades")    # unchanged: derived closed-trade rows
ledgr_results(bt, what = "equity")    # unchanged: portfolio valuation
```

New inspection surfaces are added once the data model stabilizes:

```r
ledgr_results(bt, what = "orders")
ledgr_results(bt, what = "order_events")
ledgr_results(bt, what = "target_decisions")
ledgr_order_state(bt)
ledgr_order_lifecycle(bt, order_id)
```

`what = "ledger"` is not overloaded to include lifecycle rows. Metrics do not become sensitive to lifecycle rows.

---

## 5. Lifecycle State Model Decisions

### 5.1 Event-name and status-name convention

The synthesis binds:

```text
Event names are action phrases. They describe why the row exists.
Status names are state/adjective phrases. They describe the order's resulting state.
```

This mirrors the FIX distinction between `ExecType` and `OrdStatus`. The convention applies to the whole status enum, not just partial fills.

### 5.2 Active v1 event-and-status pairs

```text
ORDER_INTENT           -> PENDING_NEW
ORDER_ACCEPTED         -> NEW
ORDER_PARTIAL_FILL     -> PARTIALLY_FILLED
ORDER_FILLED           -> FILLED
ORDER_CANCEL_REQUESTED -> PENDING_CANCEL
ORDER_CANCELED         -> CANCELED
ORDER_REJECTED         -> REJECTED
```

`ORDER_PARTIAL_FILL` / `PARTIALLY_FILLED` is the bound naming. `ORDER_PARTIALLY_FILLED` is not used.

### 5.3 Reserved future statuses

```text
PENDING_REPLACE  REPLACED  EXPIRED  DONE_FOR_DAY
SUSPENDED        CALCULATED          ACCEPTED_FOR_BIDDING
```

These may be reserved in schema enums or validation code. They are not active v1 public workflows. `DONE_FOR_DAY` should not be treated as globally terminal because in FIX-inspired models it means no more executions are expected for the trading day, not that the order is permanently terminal.

### 5.4 v1 transition table

Allowed v1 transitions:

```text
none              -> PENDING_NEW         (ORDER_INTENT)
PENDING_NEW       -> NEW                 (ORDER_ACCEPTED)
PENDING_NEW       -> REJECTED            (ORDER_REJECTED)
NEW               -> PARTIALLY_FILLED    (ORDER_PARTIAL_FILL)
NEW               -> FILLED              (ORDER_FILLED)
NEW               -> PENDING_CANCEL      (ORDER_CANCEL_REQUESTED)
NEW               -> REJECTED            (ORDER_REJECTED)
PARTIALLY_FILLED  -> PARTIALLY_FILLED    (ORDER_PARTIAL_FILL)
PARTIALLY_FILLED  -> FILLED              (ORDER_FILLED)
PARTIALLY_FILLED  -> PENDING_CANCEL      (ORDER_CANCEL_REQUESTED)
PENDING_CANCEL    -> CANCELED            (ORDER_CANCELED)
PENDING_CANCEL    -> PARTIALLY_FILLED    (ORDER_PARTIAL_FILL)
PENDING_CANCEL    -> FILLED              (ORDER_FILLED)
```

Active v1 terminal states: `FILLED`, `CANCELED`, `REJECTED`.

Cancel-reject and replacement races are not active v1 research workflows. Before paper/live adapters are implemented, the transition table must be widened to represent broker cancel rejection (e.g., `PENDING_CANCEL -> NEW` or `PENDING_CANCEL -> PARTIALLY_FILLED`) and late fills during pending cancel, without collapsing them into terminal cancellation. This future obligation is on record.

### 5.5 Quantity invariants

Every lifecycle event after intent supports `order_qty`, `cum_qty`, `last_qty`, `leaves_qty`. FIX-aligned terminal cancellation:

```text
canceled after no fill:
  cum_qty    = 0
  last_qty   = 0 or NULL
  leaves_qty = 0
  status     = CANCELED

canceled after partial fill:
  0 < cum_qty < order_qty
  last_qty   = 0 or NULL
  leaves_qty = 0
  status     = CANCELED
```

The unfilled quantity of a terminal canceled order is derivable as `canceled_qty = order_qty - cum_qty`. `leaves_qty` is not overloaded with that meaning. If ledgr later needs to persist canceled quantity directly, it uses a separate `canceled_qty` field.

Filled-versus-partially-filled classification uses a numeric tolerance, not strict double equality. The first implementation uses the same tolerance style as the fold delta path (`sqrt(.Machine$double.eps)`).

A rejected order has no fill accounting event. A pending-cancel order may still receive fills before cancellation completes.

---

## 6. Fold-Core Integration Decisions

### 6.1 Default synchronous research path

For each non-zero target delta, the synchronous research path executes:

```text
1. Build an ORDER_INTENT for a MARKET next-open order.
2. Mark it ORDER_ACCEPTED synchronously.
3. Resolve the existing next-open fill proposal path; assign deterministic proposal_id.
4. Resolve cost through the existing ledgr_resolve_fill_proposal() boundary.
5. Preallocate the deterministic FILL ledger event ID.
6. Emit ORDER_FILLED with proposal_id, ledger_event_id, ledger_event_seq when the fill is complete.
7. Emit the FILL accounting event with order_id, order_event_seq, and proposal_id in meta_json.
```

One non-zero target delta produces one ORDER_INTENT, one fill proposal, one fill intent, one FILL ledger row, and one lifecycle fill event chain. The synchronous path does not emit ORDER_PARTIAL_FILL.

### 6.2 Final-bar behavior

The current final-bar no-fill warning (`LEDGR_LAST_BAR_NO_FILL`) is preserved. Whether OMS diagnostic mode emits an ORDER_INTENT on the final bar without a fill is deferred to the implementation spec. Default research behavior does not introduce unfilled terminal orders on the final bar unless OMS diagnostic mode is explicitly enabled.

### 6.3 Partial fills in research

v1 default research simulation does not create partial fills. The data model supports them. The default next-open fill model keeps full-fill behavior. Cost policy may not clip quantities. Liquidity policy is the future layer that may introduce quantity-changing behavior; that work belongs to the public liquidity/execution policy API window, not to v0.2.x OMS data-model work.

### 6.4 Rejections in research

Research rejections are rare in v1. Possible deterministic rejection causes are limited to invalid target after validation, missing instrument, missing execution price, unsupported side, unsupported quantity, and (if cash enforcement becomes binding) insufficient cash. The data model represents rejections but does not invent broker-like rejection behavior beyond current research-engine validation semantics.

---

## 7. Mode And Retention Decisions

### 7.1 Mode is the execution context

```text
mode = "research" | "paper" | "live"
```

`mode` controls execution context: which adapters are reachable, which safety gates fire, which persistence obligations apply.

This future axis must not be confused with the current internal `execution_mode = "audit_log" | "db_live"` setting. The v0.2.x spec cut must choose names that make the axes clearly orthogonal, for example by renaming this user-facing concept to `run_context` if `mode` is too ambiguous.

### 7.2 Retention is a separate concept

```text
retention = "default" | "diagnostic" | "full"
```

`retention` controls which artifacts are stored. Research mode may later support diagnostic order-event retention without becoming paper/live. The exact API is not bound now; the conceptual separation is.

### 7.3 Order-event persistence by mode and retention

```text
research, retention=default:    no order_events written
research, retention=diagnostic: order_events written; behind explicit opt-in
sweep memory output handler:    order_events discarded by default
paper:                          order_events required
live:                           order_events required
```

The suppression gate lives at the output-handler / retention-policy boundary, not in fold logic. Memory output handlers discard full lifecycle rows by default. The persistent DuckDB output handler writes them only when the run mode and retention policy enable diagnostic OMS artifacts.

### 7.4 Target-decision persistence by mode

```text
research and sweep: no target_decisions written by default
paper:              target_decisions required
live:               target_decisions required
```

Research decisions are reconstructible from sealed evidence and deterministic execution inputs. Paper and live decisions are not, because data feeds and broker state are time-varying external inputs.

### 7.5 Promotion gate for default research OMS rows

Before diagnostic OMS rows can become a default research artifact, the implementation spec must include:

- a telemetry gate measuring pulse and runtime overhead,
- an artifact-size growth bound,
- evidence that current public results do not change.

This gate is a hard prerequisite, not a polish item.

---

## 8. Safety, Arming, And Reconciliation Boundaries

### 8.1 Safety is adapter and policy responsibility

Strategies remain pure target-vector functions. Safety gates live in adapter and policy layers, not in strategy code.

### 8.2 Arming

Paper and live mode require explicit arming. A config flag is insufficient. The first design uses a separate deliberate action:

```r
ledgr_arm_live(broker, mode = "paper")
ledgr_arm_live(broker, mode = "live")
```

The exact function name is not binding. The separate deliberate action is binding.

### 8.3 Pre-flight gates

Before any paper or live order: broker cash reconciliation, broker position reconciliation, broker open-order reconciliation, snapshot/live-data lineage check, clock-freshness check. Mismatch aborts. v1 does not auto-reconcile.

### 8.4 Per-order gates

Before any paper or live order submission: max order notional, max daily turnover, max position size per instrument, max gross exposure, max net exposure, long-only gate where applicable, and no-trade restricted instrument list when supported.

### 8.5 Runtime gates

During paper or live run: kill switch, stale-data stop, stale broker-response stop, repeated-rejection stop, repeated reconciliation-mismatch stop, optional drawdown circuit breaker.

### 8.6 Provenance gates

Exploratory sweep output cannot launch paper or live. A candidate must be promoted to a committed artifact. The promoted artifact must receive an explicit reproducibility-level upgrade or deployment approval marker before paper or live launch. No sweep-to-live pipeline is allowed at any level of the public surface.

### 8.7 Reconciliation event storage

Reconciliation observations do not live in `strategy_state`. Reconciliation-only observations do not become accounting ledger fills unless they represent accepted accounting adjustments. Whether reconciliation events live as `order_events` rows with their own event types, in a future `reconciliation_events` table, or via a separate `produced_by` field is deferred to the paper/live RFC.

---

## 9. Identity, Provenance, And Replay

### 9.1 Deterministic IDs

```text
order_event_id  derived from run_id + order_event_seq (mirrors ledger pattern)
order_id        derived from run_id + per-run order sequence
proposal_id     derived from run_id + per-run proposal sequence
ledger_event_id preallocated before lifecycle write
```

Replay must reconstruct the same `order_event_seq` sequence and the same deterministic IDs when order-event diagnostics are enabled.

Combined lifecycle/accounting audit views must use a deterministic ordering rule when `order_events` and `ledger_events` share timestamps. The exact implementation is a spec-cut detail, but it must define stable tie-breakers using sequence columns rather than relying on database row order.

### 9.2 Provenance fields on `target_decisions`

`strategy_target_vector_hash` and `risked_target_vector_hash` are companion hashes to the JSON payloads. They allow cheap equality checks without parsing JSON. Hash construction uses canonical JSON, mirroring `strategy_params_hash`.

### 9.3 Risk-chain identity

`risk_chain_hash` and `risk_audit_json` capture which risk chain ran and what it changed. These are required when the risked target vector is populated and NULL otherwise.

### 9.4 Pre-CRAN policy

Proposed schemas are pre-CRAN design sketches. They may change or break before public implementation. No compatibility promise is made until a future spec packet binds the implementation contract.

---

## 10. Implementation Constraints

### 10.1 Pre-OMS cleanup is a prerequisite

Before any OMS implementation work begins, three cleanup tickets must land:

```text
1. Delete stale FILL_PARTIAL reader support from R/ code paths.
2. Document that partial-fill lifecycle semantics are not active until
   OMS/liquidity policy introduces them; accounting remains ordinary FILL rows.
3. Verify ledger_events result derivation remains accounting-only.
```

Future partial fills are represented as multiple ordinary `FILL` accounting rows linked to `ORDER_PARTIAL_FILL` / `ORDER_FILLED` lifecycle events. `FILL_PARTIAL` is not added to the `ledger_events` DDL.

### 10.2 Testing obligations

The v0.2.x OMS implementation spec must include:

- State-machine tests verifying allowed transitions, rejecting invalid transitions, distinguishing `PENDING_CANCEL` from `CANCELED` and `PARTIALLY_FILLED` from `FILLED`, preserving fill history for canceled-after-partial, and verifying rejected orders have no accounting fill.
- Accounting isolation tests verifying lifecycle rows do not change ledger-derived fills, trades, equity, or metrics.
- Fold-parity tests verifying `ledgr_run()` and `ledgr_sweep()` share fold semantics and that memory and persistent output handlers see semantically equivalent accounting events.
- Output-handler tests verifying sweep memory handlers discard full lifecycle rows by default and persistent handlers write them only when mode and retention enable diagnostic OMS artifacts.
- Replay tests verifying deterministic `order_event_seq` and order IDs when diagnostics are enabled.
- A telemetry-overhead test bounding pulse/runtime cost of diagnostic OMS rows.
- A batching test or implementation invariant proving OMS diagnostic writes are batchable; no per-pulse DB writes are allowed in sweep or ordinary research hot paths.

### 10.3 Worker-safe plans

Any OMS-related policy plan that flows through sweep must be a worker-safe plain serializable value object. No live DB connections, external pointers, mutable environments, or active bindings in serialized identity objects. This carries forward from the chainable-risk synthesis and the execution-policy north-star RFC.

---

## 11. Explicit Deferrals

The v0.2.x OMS planning window does not include:

- broker adapters of any kind (Interactive Brokers, Alpaca, Binance, Schwab, etc.);
- live trading implementation;
- paper trading implementation;
- a public cost-model API (handled by the v0.1.9.x/v0.2.0 cost-API window);
- a public liquidity/capacity policy API;
- a public order-entry API for strategies;
- intraday-specific semantics;
- HFT or tick-by-tick execution;
- an intraday target-decision storage contract that would require destructive migration from the EOD implementation;
- multi-currency accounting;
- futures, options, FX, crypto, or venue-specific market structure;
- margin or broker-style short-selling contracts beyond current ledgr support;
- limit-order-book simulation;
- replacement chains as a first-class public workflow;
- automatic order slicing;
- smart order routing;
- execution algorithms (VWAP, TWAP, POV, arrival-price);
- cancel-reject and replacement-race state-machine transitions (reserved as a future obligation before paper/live);
- a unified typed-domain event table (reserved for v0.3.x refactor);
- accounting correction or bust semantics;
- live restart automation;
- full FIX protocol translation;
- broker-shaped column semantics in the v1 schema (deferred to the paper/live RFC, may live in `meta_json`).

---

## 12. v0.2.x Minimum Scope

The v0.2.x OMS planning window must include, at minimum:

1. Pre-OMS `FILL_PARTIAL` cleanup tickets (§10.1).
2. `order_events` schema and schema-version handling.
3. Internal event-type and status enumerations matching §5.2 and §5.4.
4. Lifecycle transition validator enforcing the §5.4 table.
5. Internal order-intent constructor for non-zero target deltas.
6. Deterministic `proposal_id` construction for next-open timing proposals.
7. Degenerate synchronous OMS path behind a non-public diagnostic feature flag or experiment option, implementing the §6.1 step sequence exactly.
8. Immutable link between lifecycle fill events and ledger fill events using the §4.3 mechanism.
9. Order-event inspection helper behind an internal or experimental surface.
10. Accounting isolation tests, fold parity tests, replay tests, and a telemetry gate.
11. Documentation explaining order lifecycle versus accounting ledger.
12. Open-question review before any public API exposure.

The v0.2.x release must not ship public `ctx$order()`, `ctx$cancel()`, `ledgr_results(bt, what = "orders")`, `ledgr_order_state()`, or `ledgr_arm_live()` surfaces. Those wait for explicit follow-up planning rounds.

---

## 13. Open Questions Promoted To Spec-Cut

The following questions remain open and must be resolved during the v0.2.x spec-cut phase, before tickets are committed:

1. What evidence and telemetry gate promotes explicit OMS diagnostic rows into default committed research artifacts, if ever?
2. Should `target_decisions` be created as a real table during v0.2.x, or deferred until the paper/live RFC even though paper/live is the only intended writer?
3. Should the v1 status enum reserve future FIX-aligned statuses even when v1 validation does not allow them?
4. Should `ORDER_CANCEL_REQUESTED` ship in v1 even though the synchronous research default will almost never use it?
5. Should `ORDER_REPLACED` and `PENDING_REPLACE` be reserved-but-invalid in v1, or omitted entirely until a replace RFC?
6. Should `ORDER_ACCEPTED` be emitted in synchronous research mode, or should `ORDER_INTENT` go directly to `ORDER_FILLED` for compactness?
7. Should `ORDER_INTENT` resolve to `PENDING_NEW` or directly to `NEW` in research simulation?
8. Should paper/live target-decision persistence serialize full target vectors, sparse non-zero vectors plus universe hash, or both?
9. What target-decision storage shape balances first-EOD simplicity with intraday compatibility?
10. Should `source` values be fixed enum strings at schema level, or validated in R constructors only?
11. Should live adapter arming be modeled as a persistent event, a runtime capability object, or both?
12. Should reconciliation observations live in `order_events` with a dedicated event type, or in a separate `reconciliation_events` table?
13. Should order lifecycle sequence and accounting ledger sequence share a global per-run sequence number in the future unified event-table design?
14. Should the current final-bar no-fill behavior emit any OMS lifecycle row in OMS diagnostic mode?
15. What minimal outstanding-order accounting, if any, is needed before asynchronous paper/live support exists?
16. Should cash insufficiency become an order rejection, target validation failure, risk-layer clipping, or remain outside v1?
17. Should long-only enforcement live in target validation, target risk, order policy, or adapter safety gates?
18. Should simulated partial fills be introduced only with liquidity policy, or can a diagnostic fill model create them earlier?
19. What is the minimum public documentation required before any OMS table ships pre-CRAN?

These questions are not blockers for the synthesis. They are inputs to the v0.2.x spec packet. Resolving these open questions during spec cut is authorized; changing a bound decision in this synthesis still requires a follow-up RFC or explicit maintainer amendment.

---

## 14. Future Obligations On Record

The synthesis records the following obligations for later RFCs:

- **Paper/live RFC** must widen the §5.4 transition table to represent cancel-reject and late-fill-during-pending-cancel transitions without collapsing them into terminal cancellation.
- **Paper/live RFC** must define adapter-shaped column semantics (`broker_order_id`, `client_order_id`, `parent_order_id`, `ts_effective_utc`, `source_event_id`, `target_decision_id`) or commit to keeping them in `meta_json`.
- **Paper/live RFC** must define reconciliation event storage (`order_events` vs separate table) and whether reconciliation gets a `produced_by` field.
- **Liquidity/execution RFC** must define partial-fill semantics, no-fill policy, volume clipping, and participation caps.
- **Unified event-table RFC** (v0.3.x) may consolidate `order_events`, `ledger_events`, and `target_decisions` into a typed-domain shape with a global per-run sequence.
- **Intraday/tick storage RFC** must redesign `target_decisions` storage if intraday persistence becomes a public workflow.
- **Target-decision storage spec** must keep the first EOD implementation compatible with later deduplicated, sparse, columnar, or payload-reference storage.

---

## 15. Acceptance

This synthesis is accepted as binding for v0.2.x OMS data-model and lifecycle planning. The maintainer may amend it via a follow-up RFC; ad-hoc changes during spec-cut are not authorized.

Predecessor synthesis (`rfc_chainable_risk_oms_policy_boundary_synthesis.md`) remains binding for v0.1.9. The execution-policy north-star RFC (`rfc_execution_policy_pipeline_audit_signal_north_star.md`) remains a non-binding architectural reference for v0.1.9.x and v0.2.x planning. This synthesis does not modify either.
