# ledgr Roadmap

**Status:** Active (derived from locked design document v0.3)

This roadmap translates the *ledgr* design document into concrete, buildable milestones. Each version has a clear **goal**, **scope**, and **definition of done**. If a milestone’s “done” criteria are met, the version is considered complete.

The roadmap is intentionally conservative and correctness‑first.

---

## Guiding Principles

- Treat the v0.1.x experiment store as the foundation for, not a replacement
  for, the long-term backtest -> paper -> live path

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

## v0.1.2 - Snapshot Correctness And Research UX

**Goal:** Make the backtest engine usable without weakening the v0.1.1
reproducibility guarantees.

### Scope
- Data-first `ledgr_backtest()` convenience path
- Functional strategy wrapper
- Result views for trades, ledger, equity, summary, and plots
- Interactive read-only pulse and indicator debugging tools
- Cross-platform deterministic replay checks

### Definition of Done
- Simple research backtest runs from an in-memory data frame
- Convenience APIs still use the canonical execution path
- Snapshot hashing, sealing, no-lookahead, and event sourcing remain intact

---

## v0.1.3 - Onboarding Release

**Goal:** Make a skeptical first-time user productive quickly while explaining
the ledgr mental model.

### Scope
- README as executable front door
- Getting-started vignette as guided tutorial
- Clear target-vector and pulse-context strategy authoring docs
- Offline-safe examples and package-site build checks

### Definition of Done
- README and vignette run from installed package code
- The first backtest does not require manual DuckDB or snapshot setup
- Documentation explains the difference between quick convenience paths and
  durable research artifacts

---

## v0.1.4 - Experiment Store Core

**Goal:** Make DuckDB experiment stores a first-class user concept.

### Scope
- `strategy_params` as explicit experiment identity
- Strategy functions support `function(ctx)` and `function(ctx, params)`
- Store strategy source text, strategy source hash, strategy parameter hash,
  ledgr version, R version, and relevant dependency versions with each run
- Mark runs created before the experiment-store schema as legacy/pre-provenance
  artifacts rather than treating them as fully recoverable experiments
- `ledgr_runs(db_path)` to discover runs
- `ledgr_open_run(db_path, run_id)` to reopen a stored run without recomputing
- `ledgr_run_info(db_path, run_id)` to inspect run identity and provenance
- `ledgr_label_run(db_path, run_id, label)` for mutable human names
- `ledgr_archive_run(db_path, run_id, reason = NULL)` for non-destructive cleanup

### Definition of Done
- One sealed snapshot can support multiple named experiments in the same DuckDB
  file
- `run_id` is documented and enforced as an immutable experiment key
- Legacy/pre-provenance runs are discoverable and clearly labeled with their
  missing provenance guarantees
- Archived runs are hidden by default but remain auditable
- Users can leave an R session and later rediscover and reopen stored runs

---

## v0.1.5 - Experiment Comparison And Strategy Recovery

**Goal:** Let users compare experiments and recover strategy code where possible.

### Scope
- `ledgr_compare_runs(db_path, run_ids = NULL)` returning a compact comparison
  table
- `ledgr_extract_strategy(db_path, run_id, trust = FALSE)` or equivalent
  recovery API
- Deterministic capture of JSON-safe strategy parameters
- Clear warnings for strategies that depend on unresolved external objects
- Optional tagging API for grouping runs

### Definition of Done
- Users can compare final equity, return, drawdown, and trade count across runs
- Self-contained functional strategies can be recovered from the experiment
  store with an explicit trust boundary
- Strategy parameters are visible, hashable, and reusable

---

## v0.1.6 - Lightweight Parameter Sweep Mode

**Goal:** Let users run fast exploratory parameter sweeps without DuckDB
persistence, with guaranteed numeric parity against full truth runs.

### Key Constraint

Sweep mode is not a separate engine. It is the same execution path with
persistence disabled. Parity tests enforce this as a CI invariant. Any engine
change that silently breaks sweep/truth agreement is a build failure.

### Scope

- `ledgr_sweep()` as the sweep entry point: same config contract as
  `ledgr_backtest()`, no DuckDB artifact produced
- Explicit public API boundary: which guarantees hold in sweep mode and which
  do not (no run identity, no provenance, no ledger persistence)
- Parity test suite: identical equity curves from `ledgr_sweep()` and
  `ledgr_backtest()` on the same input fixture
- Clear documentation of the intended workflow: sweep to shortlist, then
  `ledgr_backtest()` for the candidates worth storing

### Definition of Done

- `ledgr_sweep()` and `ledgr_backtest()` produce numerically identical results
  on the same input
- Parity is enforced by CI, not by convention
- The public API surface clearly communicates what sweep mode does and does not
  guarantee

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

