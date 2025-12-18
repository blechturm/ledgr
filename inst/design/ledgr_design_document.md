# Ledgr: Event‑Sourced Trading Framework (R)

**Status:** v0.3 — *Specification locked*

**Primary goal:** A correctness‑first, restart‑safe, low‑frequency (EOD / daily) systematic trading framework implemented as an R package, suitable for rule‑based and ML‑based strategies, with strict no‑lookahead guarantees and reproducible backtests.

This document is a **binding system specification**. Anything not defined here must not be relied upon for correctness. Examples, tutorials, and concrete strategies live outside this document.

---

## 1. Core Design Principles

1. **Correctness over performance** (for v0.x)
2. **No lookahead, by construction**
3. **Event‑sourced ledger** (append‑only, reconstructable)
4. **Deterministic replay** (same inputs ⇒ same outputs)
5. **Restart safety** (crash‑safe at any point)
6. **Vendor independence** (ports & adapters)
7. **Explicit temporal semantics** (no implicit time assumptions)
8. **Modularity with hard contracts** (prevent drift)

---

## 2. System Scope (v0.x)

**In scope**
- Daily / EOD trading cadence (close → next open)
- Equities / ETFs (cash equity trading)
- Rule‑based and ML‑based strategies
- Backtesting, paper trading, live trading

**Explicitly out of scope (documented limitations)**
- High‑frequency / intraday execution
- Options, futures, crypto
- Wash‑sale tax compliance (flagged, not enforced)
- Full PIT corporate‑action adjustment (future work)

---

## 3. Architecture Overview

Hexagonal architecture (Ports & Adapters):

- **Core Engine** (pure logic, deterministic)
- **Ports** (data, execution, reference data)
- **Adapters** (Yahoo, IBKR, etc.)
- **Persistence** (DuckDB + Parquet)

State flows only through **explicit events** persisted to disk.

---

## 4. Temporal Model (Hard‑coded for v0.1–v0.3)

All internal timestamps are UTC.

**EOD Epoch Semantics (ADR‑0014)**

- Market close: 16:00 exchange‑local
- Observation delay: +15 minutes
- Observation time `T_obs(k)`: trading day *k* at 16:15 local → UTC
- Decision deadline: next trading day 09:00 local
- Execution start `T_exec(k+1)`: next trading day open (09:30 NYSE)

If decision computation misses the deadline, **no orders are placed**.

---

## 5. Data Model & Quality

### 5.1 Bar Data

Canonical bar (S3 DTO):
- instrument_id
- timestamp_utc
- open, high, low, close, volume
- gap_type ∈ {NONE, MISSING, HALT, SOURCE_ERROR, HOLIDAY_MISMATCH}
- is_synthetic (boolean)

### 5.2 Data Quality Contract

A **Data Health Score** is computed per instrument per pulse based on:
- missing bars in lookback
- synthetic bars in lookback
- source errors

**Default engine rule:**
- If data health < threshold ⇒ strategy output for that instrument is ignored (no trade).

Strategies may *opt in* to using synthetic data, but must do so explicitly.

---

## 6. Instrument Master (Point‑in‑Time)

- Instruments are identified by immutable `instrument_id`
- Symbols are time‑varying labels

Required fields:
- instrument_id
- listing_datetime_utc
- delisting_datetime_utc (nullable)
- status ∈ {ACTIVE, HALTED, SUSPENDED, DELISTED}

Port function:
```
get_instruments_at(timestamp_utc)
```
Returns only tradeable instruments at that timestamp.

---

## 7. Ledger Model (LOCKED DECISION)

### 7.1 Event‑Sourced Ledger (ADR‑0013)

The system uses an **append‑only event ledger**, not full double‑entry accounting.

Ledger events:
- OrderIntentCreated
- OrderSubmitted
- OrderAcknowledged
- OrderFilled (partial or full)
- OrderCancelled / Rejected
- CashFlow (fees, dividends)

Each event is immutable and timestamped.

### 7.2 Derived State

Derived at any time from the ledger:
- Positions (qty per instrument)
- Cost basis (FIFO lots)
- Cash balance
- Realized PnL
- Unrealized PnL
- Portfolio equity

This guarantees reconstructability and restart safety.

---

## 8. Cost Basis & Tax Assumptions

**ADR‑0012**
- Cost basis method: FIFO
- Wash sales: **not enforced in v0.x**

Reported PnL may differ from tax PnL. This is documented and explicit.

---

## 9. Strategy Interface (CRITICAL ADDITION)

### 9.1 Strategy Lifecycle

All strategies must implement:

```r
initialize(config, universe, refdata)

on_pulse(ctx) -> StrategyResult
```

Strategies are **pure decision functions**. They do not place orders directly.

### 9.2 PulseContext

`ctx` contains:
- bars & features **up to T_obs only**
- derived positions, cash, equity
- data health flags
- calendar info (rebalance signals, trading day)
- safety state (GREEN / YELLOW / RED)
- strategy_state (if any)

### 9.3 StrategyResult

A structured return object:
- `targets` (required): desired positions (qty or weights)
- `diagnostics` (optional): signals, ranks, explanations
- `state_update` (optional): JSON‑serializable state blob
- `actions` (optional): advisory requests (e.g. suggest cancel stale orders)

The engine validates and executes results.

---

## 10. Strategy State Policy (NEW)

- Strategies are **stateless by default**
- Any internal state **must** be emitted via `state_update`
- The engine persists and restores this state

State stored anywhere else is undefined behavior.

---

## 11. Feature Pipeline & Leakage Prevention

**ADR‑0011**

Feature definitions must declare:
- `requires_bars`
- `stable_after`

The engine:
- passes only the valid history window
- never exposes future bars

Mandatory tests:
- past‑only vs past+future equality test

Limitations (documented): external data leaks cannot be fully prevented in v0.x.

---

## 12. Target → Order Translation

- Strategies express **targets**, not orders
- Engine computes target gap using:
  - current position
  - remaining working orders
  - partial fills
- Stale orders are aged out per OMS policy

In YELLOW safety state: reduce‑only (no new exposure).

---

## 13. Order Management System (OMS)

Order states:
- INTENT → SUBMITTING → PENDING → ACKED → WORKING
- FILLED / CANCELLED / REJECTED / UNKNOWN

**Soft‑commit:** intent persisted before broker call

**Hard‑commit:** broker acknowledgment persisted

On restart, reconciliation prioritizes un‑acked intents.

---

## 14. Parallel Bots & Isolation

- Each bot has:
  - its own config
  - its own ledger namespace
  - its own OMS
- Bots may share market data but **never share state**

Parallel execution is process‑level, not thread‑level.

---

## 15. ML and Non‑ML Strategy Support

The framework is strategy‑agnostic.

Supported styles:
- Rule‑based indicators
- Rebalancing portfolios
- Calendar/event‑driven logic
- ML models (offline‑trained or online‑updated)

ML models:
- trained outside the engine
- loaded as immutable artifacts per run
- treated as deterministic functions at decision time

---

## 16. Maintainability & Extensibility

- Clear module boundaries
- Versioned configs and artifacts
- One responsibility per component

Changes to strategies, data sources, or execution adapters do not affect core invariants.

### 16.1 Extension Path: Additional Asset Classes (Futures, Crypto, FX)

The architecture is intentionally **asset-class extensible**. Additional asset classes are *not* permanently out of scope; they are deferred to future versions.

**What remains invariant (core stays the same):**
- Event-sourced ledger + derived state reconstruction
- Strategy API (`on_pulse(ctx) -> StrategyResult`) returning targets
- Ports & adapters separation (new venues are adapters)
- Deterministic replay via snapshotting and artifact bundles

**What must be extended per asset class (explicit seams):**

1) **Instrument Master schema**
- Add the minimum metadata required to trade and value instruments correctly.
  - *Futures*: contract specs (expiry, multiplier, tick size, exchange, last trade/notice datetimes)
  - *Crypto*: base/quote currency pair, venue, precision/lot sizes
  - *FX*: currency pair conventions, settlement conventions

2) **Session/Calendar profile (temporal semantics)**
- The engine supports multiple session models via configuration.
  - *Equities*: close → next open (EOD)
  - *Crypto*: 24/7; define an explicit daily cutoff timestamp for “EOD-like” operation
  - *Futures*: exchange session calendars (including overnight trading)

3) **Valuation model (mark-to-market semantics)**
- Derived state must value positions using asset-class-specific rules.
  - *Futures*: contract valuation with multiplier; daily mark-to-market / variation margin
  - *Crypto*: multi-currency balances; quote-currency valuation

4) **Cashflow/event types**
- Extend the `CashFlow` and ledger event taxonomy to represent asset-class mechanics.
  - *Futures*: variation margin cash movements, commissions, exchange fees
  - *Crypto perps*: funding payments; maker/taker fees
  - *FX*: rollover/swap fees (if applicable)

5) **Risk / limits**
- Add asset-class-specific constraints as dedicated modules.
  - *Futures*: margin requirements, contract limits, expiry/roll constraints
  - *Crypto*: venue risk, rate limits, leverage caps (if derivatives are used)

6) **Continuous series and rolling (futures-specific)**
- Feature computation may use continuous series; execution trades actual contracts.
- Roll rules and roll-cost accounting are an explicit module.

**Versioning rule:** Any new asset class requires:
- a schema migration plan (instrument master + cashflows)
- new invariants/tests for temporal correctness and valuation
- a new adapter (execution + market data)

This preserves correctness while enabling future expansion.

## 17. What Is Explicitly Not in This Document

- Concrete strategy implementations
- Dashboard/UI design
- Broker‑specific quirks
- Tax reporting workflows

These live in vignettes, README, or ops documentation.

---

## 18. Final Lock Statement

This document is **frozen for v0.3**.

Further changes require a new versioned design document.

