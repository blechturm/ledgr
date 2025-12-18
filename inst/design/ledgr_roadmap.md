# ledgr Roadmap

**Status:** Active (derived from locked design document v0.3)

This roadmap translates the *ledgr* design document into concrete, buildable milestones. Each version has a clear **goal**, **scope**, and **definition of done**. If a milestone’s “done” criteria are met, the version is considered complete.

The roadmap is intentionally conservative and correctness‑first.

---

## Guiding Principles

- Ship **vertical slices**, not partial subsystems
- Prefer **determinism and auditability** over speed
- No live trading before paper trading is boring
- Every version must be restart‑safe and testable

---

## v0.0.x — Package Foundation (DONE)

**Goal:** Establish a clean, professional R package skeleton aligned with the design doc.

### Scope
- R package scaffold (`usethis`, `devtools`)
- Module directory structure
- Design document stored under `inst/design/`
- Minimal README + module READMEs
- Testthat setup

### Definition of Done
- `devtools::check()` passes (notes acceptable)
- No trading logic implemented
- Repository clearly communicates *framework*, not bot

---

## v0.1.0 — Deterministic Backtest MVP (Core Spine)

**Goal:** Run a fully deterministic EOD backtest end‑to‑end using the core contracts.

### Scope

#### Data & Storage
- DuckDB database initialization
- Minimal schemas:
  - runs
  - instruments
  - bars
  - ledger_events
- Snapshot metadata (hashes, timestamps)

#### Ledger & Derived State
- Append‑only event ledger
- Derived reconstruction of:
  - positions (qty)
  - cash balance
  - realized / unrealized PnL
  - equity curve

#### Strategy Layer
- Strategy interface implemented:
  - `initialize()`
  - `on_pulse(ctx)`
- `PulseContext` + `StrategyResult` structs
- Stateless‑by‑default enforcement

#### Feature Engine (Minimal)
- Feature definitions with:
  - `requires_bars`
  - `stable_after`
- Engine‑enforced window slicing
- Mandatory lookahead tests

#### Execution Simulation
- EOD fill model:
  - next open
  - fixed spread (bps)
  - fixed commission

#### Data Health
- Gap detection (calendar‑based)
- Synthetic flag
- Default no‑trade on unhealthy data

### Deliverables
- `ledgr_backtest_run(config)`
- DuckDB artifact bundle per run
- One trivial test strategy (e.g. buy‑and‑hold) used only in tests

### Definition of Done
- Same inputs ⇒ identical ledger + equity curve
- Restarting a backtest reproduces identical results
- Lookahead test suite runs and passes

---

## v0.1.1 — Data Ingestion & Snapshotting

**Goal:** Make backtests reproducible from stored market data snapshots.

### Scope
- One market data adapter (free-ish source)
- Bar validation:
  - OHLC sanity
  - missing days
  - obvious outliers (flag only)
- Snapshot metadata:
  - provider
  - download date
  - query params
  - content hash

### Definition of Done
- Backtest replay does not depend on re‑downloading data
- Data provenance is inspectable per run

---

## v0.2.0 — OMS Semantics (Simulation Only)

**Goal:** Introduce realistic order lifecycle handling without a real broker.

### Scope
- OMS state machine tables:
  - INTENT
  - SUBMITTING
  - PENDING
  - ACKED
  - WORKING
  - FILLED / CANCELLED / REJECTED / UNKNOWN
- Soft‑commit before submission
- Partial fills (simulated)
- Stale order aging policy

### Definition of Done
- No double‑submit invariant holds
- Crash/restart mid‑simulation recovers cleanly
- Target‑gap logic respects working orders

---

## v0.3.0 — Paper Trading Adapter + Reconciliation

**Goal:** Trade against a real broker in paper mode safely.

### Scope
- Execution adapter (IBKR recommended)
- Startup reconciliation:
  - open orders
  - positions
  - cash
- Client order IDs + strategy tagging
- Safety states:
  - GREEN (normal)
  - YELLOW (reduce‑only)
  - RED (halt)

### Definition of Done
- Paper trading runs for weeks without manual fixes
- Restart during market hours is safe
- Reconciliation discrepancies are visible and classified

---

## v0.4.0 — Observability & Operations

**Goal:** Make the system operable and debuggable.

### Scope
- Metrics tables:
  - heartbeat
  - decision latency
  - order latency
  - PnL summary
- Periodic reconciliation checks
- Alert hooks (email / log‑based acceptable)
- Manual emergency procedures documented

### Definition of Done
- Operator can answer “what is it doing?” quickly
- Frozen or stalled bot is detectable

---

## v1.0.0 — Live Trading (Small Scale)

**Goal:** Controlled live trading with conservative limits.

### Scope
- Live execution enabled behind config gate
- Strict exposure and turnover caps
- Daily post‑trade reports

### Definition of Done
- One month of live trading without system errors
- All incidents explainable via ledger + logs

---

## Future Extensions (Explicitly Deferred)

- Additional asset classes (crypto, futures, FX)
- Intraday / multi‑pulse scheduling
- Advanced transaction cost models
- Tax‑aware accounting (wash sales, lot selection)
- UI / dashboards

---

## Final Note

This roadmap is intentionally strict. If a milestone feels boring, it’s probably correct.

