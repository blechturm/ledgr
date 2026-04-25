# ledgr v0.1.2 Specification - Section 1: UX Principles & Invariants

**Document Version:** 2.1.2
**Author:** Max Thomasberger  
**Date:** December 20, 2025  
**Amendment Date:** April 24, 2026  
**Release Type:** User Experience Milestone  
**Status:** Approved for Release

---

## Section 1: UX Principles & Invariants

### 1.1 Release Philosophy

**v0.1.2 is a UX release, not a feature release.**

The v0.1.1 release established ledgr's core guarantees:
- Event-sourced execution with full audit trails
- Tamper-resistant data provenance via snapshot hashing
- Deterministic state reconstruction
- Production-grade reliability (all acceptance tests passing)

**The system is deterministic, resumable, and auditable. The experience is low-level.**

v0.1.2 addresses this by providing high-level APIs that make ledgr accessible to researchers, quants, and data scientists who need reproducible backtests but shouldn't need to understand DBI, schema design, or configuration JSON.

**Critical constraint:** This UX improvement MUST NOT compromise the guarantees that define ledgr's value proposition.

---

### 1.2 Three Hard Invariants (Non-Negotiable)

All work in v0.1.2 MUST comply with these three constraints. No exceptions.

#### 🔒 **Invariant 1: No New Execution Semantics**

> **v0.1.2 MUST NOT change pulse ordering, fill logic, ledger writes, snapshot hashing, or state reconstruction semantics.**

**What this means:**
- The execution engine from v0.1.1 remains canonical
- All new APIs are wrappers or post-processing
- Zero behavioral changes to core backtesting logic
- No modifications to event sourcing or ledger structure

**Enforcement:**
- All v0.1.1 acceptance tests (AT1-AT12) MUST pass unchanged
- Snapshot hashes MUST be identical for identical data artifacts
- Ledger event order MUST be identical for identical runs
- State reconstruction MUST produce identical results

**Data provenance note for remote adapters:**

For adapters that fetch external data (e.g., `ledgr_snapshot_from_yahoo()`), determinism is defined relative to the retrieved data artifact, not the remote service. Remote data sources may revise historical data unpredictably.

Remote fetch adapters should document how to archive retrieved data for reproducibility. Users can export snapshots in their preferred format (RDS, Parquet, CSV, etc.) using standard R tools.

**Rationale:** Execution semantics define ledgr's scientific value. Any drift breaks reproducibility guarantees and invalidates prior research.

---

#### 🔒 **Invariant 2: Interactive Tools Are Read-Only**

> **`ledgr_indicator_dev()` and `ledgr_pulse_snapshot()` MUST NOT mutate any persistent ledgr tables.**

**What this means:**
- Interactive development tools are lenses for exploration
- They read from snapshots and construct temporary views
- They never execute strategies or record events
- They never modify persistent database state

**Enforcement:**

**No persistent writes:** Interactive tools MUST NOT modify any persistent ledgr tables (`snapshots`, `snapshot_bars`, `snapshot_instruments`, `runs`, `ledger_events`, `strategy_state`, etc.).

**TEMP allowed:** They MAY create `TEMP VIEW` or `TEMP TABLE` objects on the connection for query convenience.

**Connection hygiene:** Interactive tools MUST either:
- Clean up any `TEMP` objects they create before returning, OR
- Use a dedicated connection created internally and closed on exit

**No side-effecting PRAGMAs:** They MUST NOT change database settings that would affect subsequent runs on the same connection (or MUST reset them before returning).

**Test enforcement:**

Test enforcement verifies that persistent ledgr tables remain unchanged by comparing row counts and content fingerprints before and after calling interactive tools.

```r
# Capture state of persistent tables before calling tool
persistent_tables <- c("snapshots", "snapshot_bars", "snapshot_instruments", 
                       "runs", "ledger_events", "strategy_state")

counts_before <- sapply(persistent_tables, function(tbl) {
  DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) FROM %s", tbl))[[1]]
})

# Call interactive tool
dev <- ledgr_indicator_dev(snapshot, "AAPL", "2020-06-15", lookback = 50)

# Verify no persistent table mutations
counts_after <- sapply(persistent_tables, function(tbl) {
  DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) FROM %s", tbl))[[1]]
})

stopifnot(identical(counts_before, counts_after))
```

TEMP objects are ignored by this test. Interactive tools may create and clean up temporary views/tables as needed for query convenience.

**Rationale:** Interactive tools enable experimentation. If they can mutate state, they become execution paths that bypass governance and audit trails.

---

#### 🔒 **Invariant 3: One Canonical Execution Engine**

> **All user-facing APIs MUST compile to the same internal execution path used in v0.1.1.**

**What this means:**
- `ledgr_backtest()` is a thin wrapper that constructs config → calls `ledgr_run()`
- No alternate runners
- No execution logic duplication
- All execution flows through the same tested, audited engine

**Enforcement:**

**Single entrypoint:** `ledgr_backtest()` MUST call exactly one internal execution function (the canonical `ledgr_run()` or its direct successor).

**No additional writes:** `ledgr_backtest()` MUST NOT perform any database writes beyond what the canonical engine already performs.

**Equivalence tests:** Given identical inputs, `ledgr_backtest()` and direct `ledgr_run()` calls MUST produce semantically equivalent results.

**Config equivalence:** `ledgr_backtest()` must compile inputs into the same canonical config object that `ledgr_run()` expects. Equivalence is defined over the canonicalized configuration stored in the database, not raw input lists.

**Test enforcement for config equivalence:**
```r
# Direct approach: build config explicitly
config <- ledgr_config(
  snapshot = snap,
  universe = c("AAPL", "MSFT"),
  strategy = my_strategy,
  backtest = ledgr_backtest_config(start = "2020-01-01", end = "2020-12-31")
)
result_direct <- ledgr_run(config)

# Wrapper approach: high-level API
result_wrapper <- ledgr_backtest(
  snapshot = snap,
  strategy = my_strategy,
  universe = c("AAPL", "MSFT"),
  start = "2020-01-01",
  end = "2020-12-31"
)

# Compare canonicalized configs from database
config_direct <- DBI::dbGetQuery(con, 
  "SELECT config_json FROM runs WHERE run_id = ?", 
  params = list(result_direct$run_id))[[1]]

config_wrapper <- DBI::dbGetQuery(con,
  "SELECT config_json FROM runs WHERE run_id = ?",
  params = list(result_wrapper$run_id))[[1]]

# Parse and compare (ignoring run_id, timestamps)
cfg1 <- jsonlite::fromJSON(config_direct)
cfg2 <- jsonlite::fromJSON(config_wrapper)

# Remove non-semantic fields
cfg1$run_id <- cfg2$run_id <- NULL
cfg1$created_at <- cfg2$created_at <- NULL

stopifnot(identical(cfg1, cfg2))
```

**Ledger equivalence:** Ledger events must be identical in count, ordering, and semantic content, but may differ in `run_id` and `created_at` timestamps.

**Test enforcement for ledger equivalence:**
```r
# Fetch ledger events from both runs
events_direct <- DBI::dbGetQuery(con,
  "SELECT event_seq, ts_utc, event_type, instrument_id, side, qty, price, fee 
   FROM ledger_events 
   WHERE run_id = ? 
   ORDER BY event_seq",
  params = list(result_direct$run_id))

events_wrapper <- DBI::dbGetQuery(con,
  "SELECT event_seq, ts_utc, event_type, instrument_id, side, qty, price, fee 
   FROM ledger_events 
   WHERE run_id = ? 
   ORDER BY event_seq",
  params = list(result_wrapper$run_id))

# Compare semantic content (excluding run_id, created_at)
stopifnot(identical(events_direct, events_wrapper))

# Final equity must match
stopifnot(abs(result_direct$final_equity - result_wrapper$final_equity) < 1e-10)
```

**Rationale:** Multiple execution paths fragment semantics, double test surface, and create inconsistent guarantees. There is one way to run a backtest.

---

### 1.2.1 Code Review Correctness Amendments

The following amendments clarify the v0.1.2 contract after branch review. They
do not add new execution semantics; they make inherited v0.1.0/v0.1.1 guarantees
explicit where the UX layer could otherwise weaken them.

**Snapshot artifact determinism:** `snapshot_hash` is defined only over the
canonical imported data artifact: normalized `snapshot_instruments` rows and
normalized `snapshot_bars` rows. It MUST NOT include `snapshot_id`,
`snapshots.meta_json`, creation timestamps, or any adapter metadata that is not
part of the imported data artifact. Identical normalized bars and instruments
MUST produce identical hashes across runs and databases.

**Seal-time integrity:** `ledgr_snapshot_seal()` is the final snapshot integrity
gate. It MUST validate non-empty data, bar-to-instrument referential integrity,
and OHLC high/low bounds before writing `snapshot_hash` or transitioning to
`SEALED`. This applies even when data was inserted directly or imported with a
fast/unchecked path.

**Snapshot DB vs run ledger DB:** A `ledgr_snapshot` owns the immutable data
source via `snapshot$db_path` and `snapshot$snapshot_id`. `ledgr_backtest(db_path
= ...)` names the run-ledger database. If they differ, the engine MUST read and
verify data from the snapshot DB while writing `runs`, `ledger_events`,
`strategy_state`, `features`, and `equity_curve` to the run DB. The run config
MUST persist enough provenance to reopen both.

**Strategy result validation:** Functional strategies and R6 strategies share
one `StrategyResult` contract. Target vectors MUST be named, finite numeric
vectors containing exactly the run universe. Missing instruments, extra
instruments, duplicate names, unnamed values, `NA`, `NaN`, and `Inf` MUST fail
loudly. Missing targets MUST NOT be interpreted as implicit zero.

**Replay determinism:** Stored run configs MUST fingerprint executable strategy
and indicator definitions strongly enough that closure values, default
arguments, adapter payload hashes, and registry overwrites cannot silently
change replay behavior under the same config hash.

**Context parity:** The default runtime strategy context and
`ledgr_pulse_snapshot()` MUST expose compatible `bars` and `features` schemas.
Performance proxy contexts are allowed only if they are API-compatible with the
documented data-frame semantics or are explicitly opt-in.

**Snapshot-backed reconstruction:** `ledgr_state_reconstruct()` MUST reconstruct
snapshot-backed runs from the sealed snapshot source recorded in the run config,
verify the snapshot hash before rebuilding, and remain backward-compatible with
legacy runs that use persistent `bars`.

**Public API contract:** Every user-facing v0.1.2 function documented in this
spec MUST be exported and callable without `ledgr:::`. Advertised S3 methods,
including `plot.ledgr_backtest()`, MUST be registered so base dispatch works.

---

### 1.3 Hexagonal Architecture as Design Discipline

**ledgr adopts hexagonal architecture (ports & adapters) as an API boundary discipline.**

```
┌─────────────────────────────────────────┐
│         ledgr Core Fortress             │
│                                         │
│   Event Sourcing │ State Management    │
│   Snapshot System │ Execution Engine    │
│   Ledger │ Position Tracking            │
│                                         │
└──────────────┬──────────────────────────┘
               │
               │ Stable Ports (Interfaces)
               │
    ┌──────────┼──────────┬──────────┐
    │          │          │          │
┌───▼────┐ ┌──▼─────┐ ┌──▼────┐ ┌───▼────┐
│Data    │ │Indicator│ │Metrics│ │Broker  │
│Adapters│ │Adapters │ │Adapters│ │Adapters│
└───┬────┘ └───┬────┘ └───┬───┘ └───┬────┘
    │          │          │          │
┌───▼────┐ ┌──▼─────┐ ┌──▼────┐ ┌───▼────┐
│quantmod│ │TTR     │ │Custom │ │IBrokers│
│(Yahoo/ │ │Custom  │ │Metrics│ │Alpaca  │
│FRED/   │ │        │ │        │ │        │
│Quandl) │ │        │ │        │ │        │
└────────┘ └────────┘ └───────┘ └────────┘
```

**Key principles:**

1. **Core is isolated** - External dependencies never touch execution logic
2. **Ports are stable** - Adapter interfaces define contracts
3. **Adapters are pluggable** - Users bring their own data/indicators/brokers
4. **Core has no opinions** - TTR vs. custom indicators: core doesn't care

**In v0.1.2, this manifests as:**
- Data ingestion adapters (`ledgr_snapshot_from_*`)
- Indicator adapters (`ledgr_adapter_r`, `ledgr_adapter_csv`)
- Post-hoc metric computation (basic built-in metrics only)
- Broker adapters (deferred to v0.2.0+)

**This is NOT a refactor** - internal modules remain as-is. This is an API discipline that defines how external integrations connect to ledgr.

---

### 1.4 Orchestration Philosophy

**ledgr does not compete with R quant packages. It orchestrates them.**

The R quantitative finance ecosystem is mature:
- **quantmod** - Market data fetching (Yahoo/FRED/Quandl via adapters)
- **TTR** - 50+ technical indicators (SMA, RSI, MACD, etc.)
- **PerformanceAnalytics** - 100+ risk/return metrics (deferred to v0.1.3)
- **xts/zoo** - Time series infrastructure
- **IBrokers** - Interactive Brokers integration (deferred to v0.3.0)

**ledgr's unique value is NOT reimplementing these.**

**ledgr's unique value IS:**
1. **Event sourcing** - Full audit trail from data → decisions → trades
2. **Data provenance** - Tamper detection via cryptographic hashing
3. **Reproducibility** - Deterministic state reconstruction
4. **Production path** - Same code runs in backtest, paper, production

**Integration strategy:**
- ✅ Provide adapters for existing packages (quantmod, TTR)
- ✅ Build minimal infrastructure (registry, wrappers)
- ✅ Let domain experts maintain their packages
- ❌ Avoid reimplementing indicators, metrics, data fetchers

**Benefits:**
- Faster time-to-market (leverage existing work)
- Better quality (battle-tested packages)
- Lower maintenance burden (community maintains upstream)
- Ecosystem goodwill (complementary, not competitive)

**Example:**
```r
# Don't build 100 indicators
# Instead: make TTR's 50 indicators easy to use

rsi_14 <- ledgr_adapter_r(TTR::RSI, "rsi_14", 14L, n = 14)
# ^ One-liner access to battle-tested TTR implementation
```

---

### 1.5 What v0.1.2 IS

**v0.1.2 is:**

✅ **High-level API layer** - `ledgr_backtest()`, `ledgr_snapshot_from_*()`  
✅ **Tidy outputs** - S3 objects with `summary()`, `print()`, `plot()`, `as_tibble()`  
✅ **Interactive development** - `ledgr_indicator_dev()`, `ledgr_pulse_snapshot()` for exploration  
✅ **Indicator infrastructure** - Registry, adapters, minimal built-ins  
✅ **R ecosystem integration** - quantmod data, TTR indicators  
✅ **Developer experience** - Reduce time-to-first-backtest from 30 min → 5 min  

**Target users:**
- Researchers who need reproducibility but shouldn't need to know SQL
- Quants migrating from Backtesting.py or VectorBT
- Data scientists familiar with tidyverse conventions

**Concrete UX requirements for migration:**

Users coming from Backtesting.py expect:
- `print(bt)` shows key results without SQL
- `plot(bt)` yields an equity curve + drawdown visualization
- `bt$equity_curve` or `as_tibble(bt, "equity")` returns a tibble
- Strategy development without class boilerplate (functional strategies work)

**Success criteria:**
- New user runs first backtest in <5 minutes
- Strategy development is interactive (not blind coding)
- Results are tidy (not SQL queries)
- Zero boilerplate for simple use cases

---

### 1.6 What v0.1.2 IS NOT

**v0.1.2 is NOT:**

❌ **A refactor** - Internal modules remain unchanged  
❌ **Feature-complete** - Many capabilities deferred to v0.1.3+  
❌ **An indicator library** - Use TTR (50+ indicators) via adapters  
❌ **A metrics engine** - Basic metrics only; PerformanceAnalytics in v0.1.3  
❌ **A paper trading system** - Live data adapters deferred to v0.2.0  
❌ **A production runtime** - Broker adapters deferred to v0.3.0  

**Explicitly out of scope:**
- Walk-forward optimization (v0.2.0)
- Parameter tuning algorithms (user's responsibility)
- Python indicator bridges (unnecessary - R has everything)
- TradingView API integration (doesn't exist)
- Live trading capabilities (v0.3.0)
- Comprehensive documentation (v0.1.3)
- PerformanceAnalytics integration (v0.1.3)

**Why defer these?**

Each deferred item is either:
1. **Requires the v0.1.2 UX foundation** (docs showcasing improved UX)
2. **Requires adapters designed but not implemented** (paper/live trading)
3. **Out of scope entirely** (optimization algorithms are user's domain)

---

### 1.7 Dependency Strategy

**v0.1.2 aims to introduce no new heavy dependencies in Imports.**

**Current hard dependencies (Imports):**
- **DBI** - Database interface abstraction
- **duckdb** - Embedded analytical database
- **jsonlite** - JSON parsing (already present in v0.1.1)
- **digest** - Cryptographic hashing (already present in v0.1.1)
- **rlang** - Utilities (already present in v0.1.1)

**New in v0.1.2 (Imports):**
- **tibble** - Tidy data frames
- **ggplot2** - Visualization

**Soft dependencies (Suggests):**
- **quantmod** - Market data fetching (optional, graceful degradation)
- **TTR** - Technical indicators (optional, graceful degradation)
- **xts** - Time series interoperability (optional)
- **testthat** - Testing
- **knitr, rmarkdown** - Documentation

**Policy:**
- New UX APIs MUST NOT introduce additional heavy Imports beyond tibble and ggplot2
- All external quant packages (quantmod, TTR, PerformanceAnalytics) live in Suggests
- Integration code fails gracefully with helpful install messages

**Graceful degradation example:**
```r
snap <- ledgr_snapshot_from_yahoo(...)
#> Error: quantmod package required
#> Install with: install.packages("quantmod")
```

Users install what they need, when they need it.

**Rationale:**
1. **Security** - Smaller attack surface
2. **Stability** - Fewer breaking change risks
3. **Choice** - Users pick their tools
4. **Maintenance** - Less to maintain

---

### 1.8 Why DuckDB (Not SQLite)

**ledgr uses DuckDB as its embedded database.**

**Rationale:**

DuckDB is optimized for analytical queries, window functions, and columnar scans. ledgr's workload is predominantly analytical:
- Aggregate trades from ledger events
- Compute equity curves using window functions (`SUM(...) OVER (ORDER BY ...)`)
- Calculate metrics via aggregations over returns
- Query historical bars with time-range filters

**DuckDB provides:**
- Columnar storage (better for time series data)
- Full SQL:2011 support (including advanced window functions)
- Excellent compression (smaller snapshot files)
- Vectorized execution (batch processing)
- Modern analytical query optimization

**Still embeddable:**
- Single-file database
- In-process execution
- No server needed
- Zero-copy reads

**Future benefits:**
- Can query Parquet files directly (v0.2.0+)
- Efficient storage for large market data
- Better performance for complex analytical queries

---

### 1.9 Version Roadmap Context

**Where v0.1.2 fits:**

```
v0.1.1 (COMPLETE)
├─ Event sourcing + ledger
├─ Snapshot system + tamper detection
├─ Deterministic execution
├─ All acceptance tests passing
└─ Low-level API only

v0.1.2 (THIS RELEASE) - UX Milestone
├─ High-level API (ledgr_backtest)
├─ Tidy S3 objects
├─ Interactive development tools
├─ Indicator infrastructure
├─ R ecosystem integration (quantmod, TTR)
└─ Basic visualization

v0.1.3 (NEXT) - Documentation
├─ Comprehensive vignettes
├─ API documentation
├─ pkgdown website
├─ Tutorial content
├─ PerformanceAnalytics integration
└─ Migration guides

v0.2.0 (FUTURE) - Paper Trading
├─ Live data adapters
├─ Paper trading mode
├─ Walk-forward optimization
└─ Advanced metrics

v0.3.0 (FUTURE) - Production Trading
├─ Broker adapters (IB, Alpaca)
├─ Risk management layer
├─ Order management
├─ Monitoring & alerts
└─ Production hardening
```

**v0.1.2 is the foundation** for all future work. Get UX right now, or documentation (v0.1.3) and paper trading (v0.2.0) suffer.

---

### 1.10 Testing Philosophy for v0.1.2

**All new code MUST satisfy:**

1. **Zero regressions** - All v0.1.1 tests pass unchanged
2. **Wrapper verification** - `ledgr_backtest()` produces identical results to `ledgr_run()`
3. **Read-only guarantees** - Interactive tools never write to persistent tables
4. **Determinism** - Snapshot hashes identical for identical data artifacts
5. **Direct test coverage** - All new public-facing functions have unit tests and at least one integration test

**Test categories:**

| Category | Purpose | Examples |
|----------|---------|----------|
| **Regression** | v0.1.1 still works | AT1-AT12 unchanged |
| **Equivalence** | Wrappers match core | `ledgr_backtest()` ≡ `ledgr_run()` |
| **Isolation** | Interactive tools safe | `ledgr_indicator_dev()` has no persistent side effects |
| **Integration** | Adapters work | `snapshot_from_yahoo()` → valid snapshot |
| **UX** | User-facing quality | Error messages, print output |

---

### 1.11 Success Metrics

**v0.1.2 succeeds if:**

**Quantitative:**
- ✅ Time-to-first-backtest: <5 minutes (down from 30+)
- ✅ Lines of user code: <10 lines for simple backtest (down from 50+)
- ✅ All v0.1.1 tests pass (zero regressions)
- ✅ All new public APIs have direct test coverage

**Qualitative:**
- ✅ User can develop strategy interactively
- ✅ Results feel "tidy" (tibbles, S3 methods)
- ✅ README and examples demonstrate improved UX
- ✅ Architecture sets foundation for v0.2.0/v0.3.0

**User feedback targets:**
- "Finally! I can use ledgr without reading the internals"
- "Interactive development is a game-changer"
- "The tidyverse integration feels natural"

---

### 1.12 Non-Goals (Explicit)

**v0.1.2 will NOT:**

❌ Modify execution semantics  
❌ Refactor internal modules  
❌ Add paper trading  
❌ Add live trading  
❌ Implement optimization algorithms  
❌ Bridge to Python indicators  
❌ Integrate TradingView  
❌ Build 100+ indicators  
❌ Integrate PerformanceAnalytics (deferred to v0.1.3)  
❌ Provide comprehensive documentation (that's v0.1.3)  

**If a feature isn't listed in Section 2-4 of this spec, it's out of scope.**

---

## End of Section 1

**Next sections will define:**
- Section 2: High-Level API Contract
- Section 3: Indicator Infrastructure
- Section 4: Metrics & Visualization
- Section 5: Implementation Constraints
- Section 6: Testing Requirements
- Section 7: Deferred Features

---

**Document status:** Section 1 peer-reviewed and approved. All critical enforceability issues resolved. Ready to proceed to Section 2.

**Changelog from v2.0.1:**
- Fixed Invariant 2 test enforcement (persistent table mutation checks)
- Fixed Invariant 3 config equivalence (canonicalized comparison)
- Fixed Invariant 3 ledger equivalence (modulo run_id/timestamps)
- Added data provenance note for remote adapters
- Standardized function names (full `ledgr_*` prefix)
- Updated qualitative success metric (README vs. comprehensive docs)
- Minor consistency improvements

**Changelog from v2.1.1 amendment:**
- Added Section 1.2.1 correctness amendments from branch `V0.1.2` review
- Clarified inherited snapshot hashing, seal validation, reconstruction, replay,
  context, and public API contracts
- Added UX amendment for data-first `ledgr_backtest(data = bars, ...)` while
  preserving the single canonical execution path
- Clarified that raw `"LONG"`/`"FLAT"` strategy returns are not core
  StrategyResult values; signal-style helpers must be explicit wrappers


# ledgr v0.1.2 Specification - Sections 2-4: API Contracts (CORRECTED)

**Document Version:** 2.1.2
**Author:** Max Thomasberger  
**Date:** December 20, 2025  
**Amendment Date:** April 24, 2026  
**Release Type:** User Experience Milestone  
**Status:** Approved for Release
**Changelog:** Peer review corrections applied - see end of document

---

## Preamble: Core Assumptions from v0.1.1

### Database Schema

Sections 2-4 assume the following tables exist in v0.1.1:

**Snapshot tables:**
- `snapshots` - Snapshot metadata
- `snapshot_bars` - Historical OHLCV data
- `snapshot_instruments` - Instrument definitions

**Execution tables:**
- `runs` - Backtest run metadata
- `ledger_events` - Event-sourced ledger
- `equity_curve` - Pre-computed equity/cash/positions per pulse
- `features` - Pre-computed feature values per pulse

### Timestamp Format

**Internal representation:** ISO 8601 UTC strings (`"2020-01-01T00:00:00Z"`)

**User input:** Flexible formats accepted (Date objects, "2020-01-01", ISO strings)

**Normalization:** All timestamps converted to ISO 8601 UTC before storage/queries

### Connection Lifecycle Policy

**Default pattern:** Lazy connection (recommended)
- Objects store `db_path` + identifiers
- Connections opened on-demand via internal `ledgr_db_connect(db_path)`
- Connections closed explicitly or via finalizers

**For interactive tools:** Dedicated connection created internally, closed on tool exit

**Windows consideration:** Lazy connections avoid file lock issues when passing objects between functions

---

## Section 2: High-Level API Contract

### 2.1 Overview

Section 2 defines the primary user-facing APIs that enable researchers and quants to run backtests without understanding ledgr's internal architecture.

**Design principle:** All APIs in this section are **wrappers** that compile user inputs into canonical configurations and delegate to the v0.1.1 execution engine. No new execution semantics.

**Compliance:** All APIs MUST satisfy Invariants 1, 2, and 3 from Section 1.

---

#### 2.1.1 Public API Export Contract

All user-facing functions documented in Sections 2-4 are part of the v0.1.2
public API and MUST be exported. Tests MUST lock the export surface so examples
and user workflows do not depend on `ledgr:::` internals.

The v0.1.2 export surface includes, at minimum:

- Snapshot UX: `ledgr_snapshot_from_df()`, `ledgr_snapshot_from_yahoo()`,
  `ledgr_snapshot_close()`, and existing v0.1.1 snapshot functions
- Backtest UX: `ledgr_backtest()`, `ledgr_extract_fills()`,
  `ledgr_compute_equity_curve()`, `ledgr_compute_metrics()`,
  `ledgr_backtest_bench()`
- Indicator UX: `ledgr_indicator()`, `ledgr_register_indicator()`,
  `ledgr_get_indicator()`, `ledgr_list_indicators()`, built-in indicators, and
  adapter constructors
- Interactive UX: `ledgr_indicator_dev()`, `ledgr_pulse_snapshot()`, and their
  close methods
- S3 methods: `print()`, `summary()`, `as_tibble()`, `plot()`, and `close()`
  methods advertised by this spec

Package checks MUST pass without warnings caused by missing exports, missing S3
registrations, undeclared optional dependencies, undocumented method arguments,
or unqualified base/recommended-package calls.

---

### 2.2 Data Ingestion Adapters

#### 2.2.1 Purpose

Data ingestion adapters transform external data sources into ledgr snapshots. They handle:
- Format conversion (data.frame, xts, remote APIs)
- Schema validation
- Instrument registration
- Snapshot sealing

**Key constraint:** Adapters MUST produce snapshots that are indistinguishable from manually-constructed snapshots. The snapshot format is canonical.

---

#### 2.2.2 `ledgr_snapshot_from_df()`

**Purpose:** Create snapshot from in-memory data.frame or tibble.

**Signature:**
```r
ledgr_snapshot_from_df <- function(bars_df,
                                    instruments_df = NULL,
                                    db_path = NULL,
                                    snapshot_id = NULL)
```

**Parameters:**

- `bars_df` - data.frame with columns:
  - `ts_utc` (character, ISO 8601 format or convertible)
  - `instrument_id` (character)
  - `open`, `high`, `low`, `close` (numeric)
  - `volume` (numeric, optional)

- `instruments_df` - Optional data.frame with columns:
  - `instrument_id` (character)
  - `metadata` (list-column, optional)
  - If NULL, auto-generate from unique `bars_df$instrument_id`

- `db_path` - Path to database file
  - If NULL, create tempfile in `tempdir()`
  - If specified, database persists at that path

- `snapshot_id` - Snapshot identifier
  - If NULL, use v0.1.1 canonical generation (timestamp-based)
  - If specified, must be unique within database

**Returns:** S3 object of class `ledgr_snapshot`

**Behavior:**

1. Validate `bars_df` schema (required columns, types)
2. Normalize timestamps to ISO 8601 UTC
3. Create or open database at `db_path`
4. Delegate to v0.1.1 `ledgr_snapshot_create()` for canonical ID generation
5. Import bars via `ledgr_snapshot_import_bars()`
6. Register instruments (auto-generate or use `instruments_df`)
7. Seal snapshot (compute hash, mark immutable)
8. Return `ledgr_snapshot` object (stores path + ID, not open connection)

**Example:**
```r
bars <- tibble::tibble(
  ts_utc = c("2020-01-01", "2020-01-02"),
  instrument_id = c("AAPL", "AAPL"),
  open = c(100, 101),
  high = c(102, 103),
  low = c(99, 100),
  close = c(101, 102),
  volume = c(1000000, 1100000)
)

snap <- ledgr_snapshot_from_df(bars)
#> ledgr_snapshot: 2 bars, 1 instrument
#> Database: /tmp/RtmpXXXX/ledgr_20251220_103045.duckdb
#> Snapshot ID: snapshot_20251220_103045
```

**Validation:**
- All required columns present
- `ts_utc` parseable to datetime
- Numeric columns finite (no NA/NaN/Inf unless explicitly supported)
- No duplicate (ts_utc, instrument_id) pairs
- Bars ordered chronologically per instrument
- OHLC bounds valid: `high >= max(open, low, close)` and
  `low <= min(open, high, close)`
- Every bar `instrument_id` exists in `snapshot_instruments` before sealing

**Snapshot hash contract:**

Adapters MUST NOT make snapshot hashes depend on adapter metadata. The sealed
`snapshot_hash` is a deterministic fingerprint of canonical
`snapshot_instruments` and `snapshot_bars` only. `snapshot_id`,
`snapshots.meta_json`, creation timestamps, and `ledgr_snapshot` object metadata
MUST NOT enter the hash input.

**Seal contract:**

`ledgr_snapshot_from_df()` delegates final immutability to
`ledgr_snapshot_seal()`. Seal-time validation is mandatory even though adapters
also validate inputs. Failed validation MUST leave the snapshot unsealed and
MUST NOT write `snapshot_hash`.

**Error handling:**
```r
snap <- ledgr_snapshot_from_df(bad_data)
#> Error: bars_df missing required column: 'close'
#> Required columns: ts_utc, instrument_id, open, high, low, close
```

---

#### 2.2.3 `ledgr_snapshot_from_yahoo()`

**Purpose:** Fetch data from Yahoo Finance via quantmod and create snapshot.

**Signature:**
```r
ledgr_snapshot_from_yahoo <- function(symbols,
                                       from,
                                       to,
                                       db_path = NULL,
                                       snapshot_id = NULL,
                                       ...)
```

**Parameters:**

- `symbols` - Character vector of ticker symbols
- `from` - Start date (character, Date, or POSIXct)
- `to` - End date (character, Date, or POSIXct)
- `db_path` - Database path (NULL = tempfile)
- `snapshot_id` - Snapshot ID (NULL = canonical generation)
- `...` - Additional arguments passed to `quantmod::getSymbols()`

**Returns:** S3 object of class `ledgr_snapshot`

**Behavior:**

1. Check for quantmod package (fail gracefully if missing)
2. Fetch each symbol via `quantmod::getSymbols()`
3. Convert xts → data.frame
4. Normalize timestamps to ISO 8601 UTC
5. Combine into single bars_df
6. Delegate to `ledgr_snapshot_from_df()`

**Example:**
```r
snap <- ledgr_snapshot_from_yahoo(
  symbols = c("AAPL", "MSFT"),
  from = "2020-01-01",
  to = "2020-12-31"
)
#> Fetching AAPL...
#> Fetching MSFT...
#> ledgr_snapshot: 504 bars, 2 instruments
```

**Graceful degradation:**
```r
snap <- ledgr_snapshot_from_yahoo(...)
#> Error: quantmod package required
#> Install with: install.packages("quantmod")
```

**Data provenance note:**

Per Invariant 1, determinism is defined over the retrieved data artifact, not the remote service. Users should export snapshots to ensure reproducibility:

```r
# Fetch once
snap <- ledgr_snapshot_from_yahoo(symbols, from, to)

# Archive for reproducibility (user's choice of format)
df <- as_tibble(snap, "bars")
saveRDS(df, "yahoo_data_2020.rds")              # R native
# OR: arrow::write_parquet(df, "yahoo_2020.parquet")  # Columnar
# OR: write.csv(df, "yahoo_2020.csv")                  # Portable

# Later: deterministic reload
df <- readRDS("yahoo_data_2020.rds")
snap <- ledgr_snapshot_from_df(df)
**Validation:**

Same as `ledgr_snapshot_from_df()` plus:
- Symbol must return data from Yahoo Finance
- Date range must be valid
- At least one bar per symbol

---

#### 2.2.5 `ledgr_snapshot` S3 Class

**Structure (lazy connection pattern):**
```r
structure(
  list(
    db_path = "/path/to/db.duckdb",
    snapshot_id = "snapshot_20251220_103045",
    metadata = list(
      n_bars = 504L,
      n_instruments = 2L,
      start_date = "2020-01-01T00:00:00Z",
      end_date = "2020-12-31T00:00:00Z",
      created_at = "2025-12-20T10:30:45Z"
    ),
    # Private: connection opened on-demand
    .con = NULL
  ),
  class = "ledgr_snapshot"
)
```

**Connection management:**

Connections are opened lazily via internal helper:
```r
# Internal function (not exported)
ledgr_db_connect <- function(db_path) {
  DBI::dbConnect(duckdb::duckdb(), dbdir = db_path)
}

# Used internally when queries needed
get_connection <- function(snapshot) {
  if (is.null(snapshot$.con) || !DBI::dbIsValid(snapshot$.con)) {
    snapshot$.con <- ledgr_db_connect(snapshot$db_path)
  }
  snapshot$.con
}
```

**Explicit close method:**
```r
#' Close snapshot database connection
#' @export
ledgr_snapshot_close <- function(snapshot) {
  if (!is.null(snapshot$.con) && DBI::dbIsValid(snapshot$.con)) {
    DBI::dbDisconnect(snapshot$.con)
    snapshot$.con <- NULL
  }
  invisible(snapshot)
}

#' @export
close.ledgr_snapshot <- function(con, ...) {
  ledgr_snapshot_close(con)
}
```

**Methods:**

```r
#' @export
print.ledgr_snapshot <- function(x, ...) {
  cat("ledgr_snapshot\n")
  cat("==============\n")
  cat("Bars:        ", x$metadata$n_bars, "\n")
  cat("Instruments: ", x$metadata$n_instruments, "\n")
  cat("Date Range:  ", x$metadata$start_date, "to", x$metadata$end_date, "\n")
  cat("Database:    ", x$db_path, "\n")
  cat("Snapshot ID: ", substr(x$snapshot_id, 1, 32), "...\n")
  
  # Connection status
  if (!is.null(x$.con) && DBI::dbIsValid(x$.con)) {
    cat("Connection:   Open\n")
  } else {
    cat("Connection:   Closed (opens on-demand)\n")
  }
  
  invisible(x)
}

#' @export
summary.ledgr_snapshot <- function(object, ...) {
  # Open connection if needed
  con <- get_connection(object)
  
  # Show per-instrument statistics
  stats <- DBI::dbGetQuery(con, "
    SELECT 
      instrument_id,
      COUNT(*) as n_bars,
      MIN(ts_utc) as start_date,
      MAX(ts_utc) as end_date
    FROM snapshot_bars
    WHERE snapshot_id = ?
    GROUP BY instrument_id
  ", params = list(object$snapshot_id))
  
  print(object)
  cat("\nPer-Instrument Summary:\n")
  print(stats)
  invisible(object)
}
```

**Lifecycle notes:**

- Lazy connections avoid Windows file lock issues
- Users can explicitly close via `ledgr_snapshot_close(snap)`
- Connections auto-close on R session exit (finalizers)
- Passing snapshots between functions is safe (no stale connections)

---

### 2.3 Main Backtest API

#### 2.3.1 `ledgr_backtest()`

**Purpose:** High-level backtest execution wrapper.

**Critical constraint:** This function MUST be a thin wrapper per Invariant 3. It constructs a canonical config and calls `ledgr_run()`. No execution logic.

**Signature:**
```r
ledgr_backtest <- function(snapshot = NULL,
                            strategy,
                            universe = NULL,
                            start = NULL,
                            end = NULL,
                            initial_cash = 100000,
                            features = list(),
                            fill_model = NULL,
                            db_path = NULL,
                            run_id = NULL,
                            data = NULL)
```

**Parameters:**

- `snapshot` - `ledgr_snapshot` object (explicit snapshot mode)
- `data` - Optional convenience input. Supported values:
  - `data.frame`/tibble with OHLCV bars -> creates a sealed snapshot internally
  - `ledgr_snapshot` -> treated the same as `snapshot`
- `strategy` - Strategy function or R6 object
  - Function: `function(ctx) -> named numeric vector`
  - R6: Object with `$on_pulse(ctx)` method
- `universe` - Character vector of instrument IDs. If NULL in data-frame mode,
  infer from `data$instrument_id`; if NULL in snapshot mode, infer all snapshot
  instruments.
- `start` - Start timestamp (NULL = snapshot start)
- `end` - End timestamp (NULL = snapshot end)
- `initial_cash` - Starting capital (numeric)
- `features` - List of `ledgr_indicator` objects
- `fill_model` - Fill model config (NULL = instant fill)
- `db_path` - Database for run ledger. In explicit snapshot mode, NULL =
  snapshot DB. In data-frame mode, NULL = temporary DuckDB in `tempdir()`.
- `run_id` - Run identifier (NULL = auto-generate)

**Returns:** S3 object of class `ledgr_backtest`

**Input modes:**

Exactly one data source is allowed:

1. **Snapshot mode:** `ledgr_backtest(snapshot = snap, ...)`
2. **Data-first mode:** `ledgr_backtest(data = bars, ...)`
3. **Snapshot-as-data mode:** `ledgr_backtest(data = snap, ...)`

Data-first mode is a convenience wrapper only. It MUST call
`ledgr_snapshot_from_df()` to normalize, validate, seal, and hash the data
before constructing the canonical run config. It MUST then call `ledgr_run()`
through the same path as snapshot mode.

Data-first mode MUST NOT:

- write bars directly to the legacy `bars` table
- skip snapshot sealing or hash validation
- create a second execution engine
- change fill, pulse, feature, or ledger semantics

If `data` is a data frame and `db_path` is NULL, ledgr creates a temporary
DuckDB database in `tempdir()` and uses it for the implicit snapshot and run
ledger. If `db_path` is supplied, ledgr uses it for the implicit snapshot and
run ledger. Users who need separate snapshot and run databases should create
the snapshot explicitly and pass `snapshot = snap, db_path = run_db_path`.

**Database provenance:**

`snapshot$db_path` is the immutable data-source database. `db_path` is the
run-ledger database. When `db_path` is NULL, both roles use the snapshot
database for backward compatibility. When `db_path` differs from
`snapshot$db_path`, the engine MUST:

1. Open the snapshot DB read-only or read-intent for snapshot validation and bars
2. Verify the sealed `snapshot_hash` against the snapshot DB before running
3. Write run artifacts only to the run-ledger DB
4. Store both paths and `snapshot_id` in canonical config/run metadata
5. Fail loudly if the recorded snapshot source is unavailable for run or replay

**Implementation contract:**

```r
ledgr_backtest <- function(...) {
  # 1. VALIDATE inputs (fail fast)
  # 2. IF data is a data.frame: ledgr_snapshot_from_df(data, ...)
  # 3. BUILD canonical config (exactly as ledgr_config() would)
  # 4. CALL ledgr_run(config)
  # 5. WRAP result in ledgr_backtest S3 class
  # 6. RETURN
  
  # NO execution logic
  # NO database writes beyond what ledgr_run() does
  # NO alternate data path around snapshots
}
```

**Pseudo-implementation:**
```r
ledgr_backtest <- function(snapshot, strategy, universe, start, end, 
                            initial_cash = 100000, features = list(), 
                            fill_model = NULL, db_path = NULL, run_id = NULL) {
  
  # Validate
  stopifnot(inherits(snapshot, "ledgr_snapshot"))
  stopifnot(is.character(universe), length(universe) > 0)
  
  # Build canonical config
  config <- ledgr_config(
    snapshot = snapshot,
    universe = universe,
    strategy = strategy,
    backtest = ledgr_backtest_config(
      start = start %||% snapshot$metadata$start_date,
      end = end %||% snapshot$metadata$end_date,
      initial_cash = initial_cash
    ),
    features = features,
    fill_model = fill_model %||% ledgr_fill_model_instant(),
    snapshot_db_path = snapshot$db_path,
    db_path = db_path %||% snapshot$db_path,
    run_id = run_id
  )
  
  # Call canonical engine (ONLY execution path)
  result <- ledgr_run(config)
  
  # Wrap in S3 class for tidy methods
  structure(
    result,
    class = c("ledgr_backtest", class(result))
  )
}
```

**Example usage:**
```r
# Minimal data-first backtest
bars <- tibble::tibble(
  ts_utc = as.POSIXct(c("2020-01-01", "2020-01-02"), tz = "UTC"),
  instrument_id = "AAPL",
  open = c(100, 101),
  high = c(101, 102),
  low = c(99, 100),
  close = c(100, 101),
  volume = c(1000, 1100)
)

hold_one <- function(ctx) {
  stats::setNames(rep(1, length(ctx$universe)), ctx$universe)
}

bt <- ledgr_backtest(
  data = bars,
  strategy = hold_one,
  start = "2020-01-01",
  end = "2020-01-02"
)

# Explicit snapshot backtest
bt <- ledgr_backtest(
  snapshot = snap,
  strategy = my_strategy,
  universe = c("AAPL", "MSFT"),
  start = "2020-01-01",
  end = "2020-12-31"
)

# With features
bt <- ledgr_backtest(
  snapshot = snap,
  strategy = my_strategy,
  universe = c("AAPL", "MSFT"),
  start = "2020-01-01",
  end = "2020-12-31",
  features = list(
    ledgr_ind_sma(50),
    ledgr_ind_rsi(14)
  )
)
```

**Equivalence guarantee:**

Per Invariant 3, these two approaches MUST produce identical results:

```r
# Approach 1: Direct config
config <- ledgr_config(...)
result1 <- ledgr_run(config)

# Approach 2: Wrapper
result2 <- ledgr_backtest(...)

# Must be equivalent (modulo run_id)
stopifnot(identical_modulo_run_id(result1, result2))
```

Data-first mode has the same equivalence requirement:

```r
snap <- ledgr_snapshot_from_df(bars, db_path = temp_db)
manual <- ledgr_backtest(snapshot = snap, strategy = strategy, universe = universe)
simple <- ledgr_backtest(data = bars, strategy = strategy, universe = universe)

# Ledger events, fills, and equity curve must match, modulo generated ids/paths.
```

---

#### 2.3.2 Functional Strategy Interface

**Purpose:** Allow users to write strategies as simple functions without R6 boilerplate.

**Strategy function contract:**

A strategy function receives a context object and returns target positions:

```r
my_strategy <- function(ctx) {
  # ctx contains:
  #   $universe     - Instrument IDs in run order
  #   $bars         - Latest OHLCV data (data.frame, ONE ROW PER INSTRUMENT)
  #   $features     - Computed feature values (data.frame)
  #   $positions    - Current positions (named numeric vector)
  #   $cash         - Available cash (numeric scalar)
  #   $equity       - Total equity (numeric scalar)
  #   $ts_utc       - Current timestamp (character, ISO 8601)
  
  # Returns: Named numeric vector of TARGET positions
  # Units: SHARES/CONTRACTS (integer-like numeric)
  # Fractional shares: FORBIDDEN (round/floor in strategy logic)
  
  c(AAPL = 100, MSFT = 50)
}
```

**Context object schemas:**

**`ctx$bars` structure:**
- One row per instrument in universe
- Columns: `instrument_id`, `ts_utc`, `open`, `high`, `low`, `close`, `volume`
- Represents CURRENT bar (not historical window)

**`ctx$features` structure:**
- One row per (instrument, feature) pair
- Columns: `instrument_id`, `feature_name`, `feature_value`
- All requested features for current timestamp

The default runtime context and `ledgr_pulse_snapshot()` MUST expose compatible
schemas for `bars` and `features`. User strategies that work against
`ledgr_pulse_snapshot()` using data-frame semantics (`nrow()`, `$`, `[`, and
column names) MUST work unchanged in `ledgr_backtest()` by default. Optimized
proxy contexts are allowed only when they preserve this API or when explicitly
enabled by user control settings.

**Target positions specification:**

- **Units:** Shares or contracts (numeric)
- **Fractional shares:** Not supported - use `floor()` or `round()` in strategy
- **Negative values:** Short positions (if supported by configuration)
- **Zero:** Flat/exit position
- **Completeness:** Target vector MUST include exactly one named finite numeric
  value for every instrument in `ctx$universe`
- **Missing instruments:** Error (`ledgr_invalid_strategy_result`)
- **Extra instruments:** Error (`ledgr_invalid_strategy_result`)
- **Duplicate or unnamed targets:** Error (`ledgr_invalid_strategy_result`)

**Signal shorthands are not core strategy output:**

Raw string returns such as `"LONG"` or `"FLAT"` are intentionally not valid
`StrategyResult` values in `ledgr_run()` or `ledgr_backtest()`. They are
ambiguous for position size, multi-instrument universes, shorting, and cash
sizing. A strategy that returns `"LONG"` directly MUST fail with
`ledgr_invalid_strategy_result`.

If ledgr provides a signal-oriented convenience helper, it MUST be explicit,
for example:

```r
sig <- ledgr_signal_strategy(
  function(ctx) {
    if (ctx$bars$close[[1]] > mean(ctx$bars$close, na.rm = TRUE)) "LONG" else "FLAT"
  },
  long_qty = 1,
  flat_qty = 0
)
```

Such a helper MUST translate signals into a full named numeric target vector
before the shared StrategyResult validator runs. It MUST NOT introduce a second
strategy contract inside the runner.

**Implementation note:**

Functional strategies are wrapped internally into R6 objects that ledgr's execution engine expects. This wrapper is transparent to users.
Functional strategies and R6 strategies MUST use the same `StrategyResult`
validator. The engine MUST NOT treat missing targets as implicit zero.

```r
# Internal wrapper (not user-facing)
ledgr_strategy_fn <- function(fn) {
  R6::R6Class("FunctionalStrategy",
    public = list(
      on_pulse = function(ctx) {
        fn(ctx)
      }
    )
  )$new()
}
```

**Example:**
```r
# Moving average crossover strategy
sma_crossover <- function(ctx) {
  # Extract close price for AAPL
  aapl_close <- ctx$bars$close[ctx$bars$instrument_id == "AAPL"]
  
  # Extract features
  sma_50 <- ctx$features$feature_value[
    ctx$features$instrument_id == "AAPL" & 
    ctx$features$feature_name == "sma_50"
  ]
  sma_200 <- ctx$features$feature_value[
    ctx$features$instrument_id == "AAPL" & 
    ctx$features$feature_name == "sma_200"
  ]
  
  # Generate signal
  if (sma_50 > sma_200) {
    # Calculate position size (example: use 50% of equity)
    target_value <- 0.5 * ctx$equity
    target_shares <- floor(target_value / aapl_close)
    c(AAPL = target_shares)
  } else {
    c(AAPL = 0)  # Flat
  }
}

bt <- ledgr_backtest(
  snapshot = snap,
  strategy = sma_crossover,  # Just pass the function
  universe = "AAPL",
  features = list(ledgr_ind_sma(50), ledgr_ind_sma(200))
)
```

---

### 2.4 `ledgr_backtest` S3 Class

#### 2.4.1 Object Structure

```r
structure(
  list(
    run_id = "run_abc123",
    db_path = "/path/to/db.duckdb",
    snapshot_db_path = "/path/to/snapshot.duckdb",
    config = <canonical config>,
    
    # Private: connection opened on-demand
    .con = NULL
  ),
  class = c("ledgr_backtest", "ledgr_run")
)
```

**No caching:** Results computed on-demand each method call (metrics are cheap to compute).

**Connection management:** Same lazy pattern as `ledgr_snapshot`.

---

#### 2.4.2 `print.ledgr_backtest()`

**Purpose:** Concise summary suitable for console.

```r
#' @export
print.ledgr_backtest <- function(x, ...) {
  cat("ledgr Backtest Results\n")
  cat("======================\n\n")
  
  cat("Run ID:        ", x$run_id, "\n")
  cat("Universe:      ", paste(x$config$universe, collapse = ", "), "\n")
  cat("Date Range:    ", x$config$backtest$start, "to", x$config$backtest$end, "\n")
  cat("Initial Cash:  ", sprintf("$%.2f", x$config$backtest$initial_cash), "\n")
  
  # Compute final equity from equity_curve table
  con <- get_connection(x)
  final_equity <- DBI::dbGetQuery(con, "
    SELECT equity 
    FROM equity_curve 
    WHERE run_id = ? 
    ORDER BY pulse_seq DESC 
    LIMIT 1
  ", params = list(x$run_id))[[1]]
  
  cat("Final Equity:  ", sprintf("$%.2f", final_equity), "\n")
  
  pnl <- final_equity - x$config$backtest$initial_cash
  pnl_pct <- (pnl / x$config$backtest$initial_cash) * 100
  
  cat("P&L:           ", sprintf("$%.2f (%.2f%%)", pnl, pnl_pct), "\n\n")
  
  cat("Use summary(bt) for detailed metrics\n")
  cat("Use plot(bt) for equity curve visualization\n")
  
  invisible(x)
}
```

**Example output:**
```
ledgr Backtest Results
======================

Run ID:         run_abc123
Universe:       AAPL, MSFT
Date Range:     2020-01-01T00:00:00Z to 2020-12-31T00:00:00Z
Initial Cash:   $100000.00
Final Equity:   $125430.50
P&L:            $25430.50 (25.43%)

Use summary(bt) for detailed metrics
Use plot(bt) for equity curve visualization
```

---

#### 2.4.3 `summary.ledgr_backtest()`

**Purpose:** Detailed performance metrics.

**Signature:**
```r
#' @export
summary.ledgr_backtest <- function(object, metrics = "standard", ...)
```

**Parameters:**
- `object` - `ledgr_backtest` object
- `metrics` - Which metrics to compute:
  - `"standard"` - Basic built-in metrics (ONLY option in v0.1.2)
  - Other values error with helpful message

**Behavior:**

1. Compute metrics (no caching - cheap to recompute)
2. Display formatted output
3. Return invisibly

**Example output:**
```r
summary(bt)

ledgr Backtest Summary
======================

Performance Metrics:
  Total Return:        25.43%
  Annualized Return:   23.10%
  Max Drawdown:        -12.45%
  
Risk Metrics:
  Volatility (annual): 18.50%
  
Trade Statistics:
  Total Trades:        24
  Win Rate:            62.50%
  Avg Trade:           $1059.60
  
Exposure:
  Time in Market:      78.30%
```

**Implementation:**
```r
summary.ledgr_backtest <- function(object, metrics = "standard", ...) {
  
  # Only "standard" supported in v0.1.2
  if (!identical(metrics, "standard")) {
    stop(
      "Only metrics='standard' supported in v0.1.2\n",
      "Advanced metrics (PerformanceAnalytics integration) available in v0.1.3"
    )
  }
  
  # Compute metrics (fresh each time, no caching)
  computed <- ledgr_compute_metrics(object, metrics = "standard")
  
  # Display
  cat("ledgr Backtest Summary\n")
  cat("======================\n\n")
  
  cat("Performance Metrics:\n")
  cat(sprintf("  Total Return:        %.2f%%\n", computed$total_return * 100))
  cat(sprintf("  Annualized Return:   %.2f%%\n", computed$annualized_return * 100))
  cat(sprintf("  Max Drawdown:        %.2f%%\n", computed$max_drawdown * 100))
  
  cat("\nRisk Metrics:\n")
  cat(sprintf("  Volatility (annual): %.2f%%\n", computed$volatility * 100))
  
  cat("\nTrade Statistics:\n")
  cat(sprintf("  Total Trades:        %d\n", computed$n_trades))
  
  if (computed$n_trades > 0) {
    cat(sprintf("  Win Rate:            %.2f%%\n", computed$win_rate * 100))
    cat(sprintf("  Avg Trade:           $%.2f\n", computed$avg_trade))
  } else {
    cat("  Win Rate:            N/A (no trades)\n")
    cat("  Avg Trade:           N/A (no trades)\n")
  }
  
  cat("\nExposure:\n")
  cat(sprintf("  Time in Market:      %.2f%%\n", computed$time_in_market * 100))
  
  invisible(object)
}
```

---

#### 2.4.4 `as_tibble.ledgr_backtest()`

**Purpose:** Extract data as tidy tibbles.

**Signature:**
```r
#' @export
as_tibble.ledgr_backtest <- function(x, what = "equity", ...)
```

**Parameters:**
- `x` - `ledgr_backtest` object
- `what` - Which data to extract:
  - `"equity"` - Equity curve (default)
  - `"fills"` - Fill history
  - `"ledger"` - Raw ledger events

**No mutation:** Computes and returns fresh data each call.

**Examples:**
```r
# Equity curve
equity <- as_tibble(bt, "equity")
# tibble: ts_utc, equity, cash, positions_value, drawdown

# Fills
fills <- as_tibble(bt, "fills")
# tibble: ts_utc, instrument_id, side, qty, price, fee, realized_pnl

# Ledger events
ledger <- as_tibble(bt, "ledger")
# tibble: event_seq, ts_utc, event_type, instrument_id, ...
```

**Implementation:**
```r
as_tibble.ledgr_backtest <- function(x, what = "equity", ...) {
  
  what <- match.arg(what, c("equity", "fills", "ledger"))
  
  con <- get_connection(x)
  
  switch(what,
    equity = {
      # Read from equity_curve table (already computed by engine)
      eq <- tibble::as_tibble(DBI::dbGetQuery(con, "
        SELECT ts_utc, equity, cash, positions_value
        FROM equity_curve
        WHERE run_id = ?
        ORDER BY pulse_seq
      ", params = list(x$run_id)))
      
      # Add drawdown
      eq$running_max <- cummax(eq$equity)
      eq$drawdown <- (eq$equity / eq$running_max - 1) * 100
      
      eq
    },
    fills = {
      ledgr_extract_fills(x)
    },
    ledger = {
      tibble::as_tibble(DBI::dbGetQuery(con, "
        SELECT * FROM ledger_events
        WHERE run_id = ?
        ORDER BY event_seq
      ", params = list(x$run_id)))
    }
  )
}
```

---

#### 2.4.5 Accessor Methods

**Direct component access:**
```r
# Users can access via methods (no cached fields in object)
equity <- as_tibble(bt, "equity")
fills <- as_tibble(bt, "fills")
metrics <- ledgr_compute_metrics(bt)
```

**Helper functions:**
```r
# Get specific metrics
ledgr_get_metric <- function(bt, metric_name) {
  metrics <- ledgr_compute_metrics(bt)
  metrics[[metric_name]]
}

# Example
sharpe <- ledgr_get_metric(bt, "sharpe_ratio")  # Not in v0.1.2, but pattern shown
```

---

### 2.5 Error Handling & Validation

#### 2.5.1 Input Validation

All high-level APIs MUST validate inputs and fail fast with helpful messages:

```r
# Bad snapshot
bt <- ledgr_backtest(snapshot = "not_a_snapshot", ...)
#> Error: 'snapshot' must be a ledgr_snapshot object
#> Create with: ledgr_snapshot_from_yahoo() or ledgr_snapshot_from_df()

# Empty universe
bt <- ledgr_backtest(snapshot = snap, universe = character(0), ...)
#> Error: 'universe' must contain at least one instrument

# Invalid date range
bt <- ledgr_backtest(snap, strategy, universe, start = "2025-01-01", end = "2020-01-01")
#> Error: 'start' must be before 'end'

# Instrument not in snapshot
bt <- ledgr_backtest(snap, strategy, universe = c("AAPL", "INVALID"), ...)
#> Error: Instruments not found in snapshot: INVALID
#> Available instruments: AAPL, MSFT, GOOGL
```

#### 2.5.2 Strategy Errors

Strategy execution errors MUST be caught and reported with context:

```r
bad_strategy <- function(ctx) {
  stop("Oops!")
}

bt <- ledgr_backtest(snap, bad_strategy, ...)
#> Error in strategy execution at 2020-03-15T00:00:00Z:
#>   Oops!
#> 
#> Context:
#>   Run ID: run_abc123
#>   Pulse: 45 of 252
#> 
#> Debug with: ledgr_pulse_snapshot(snap, "2020-03-15T00:00:00Z")
```

---

## Section 3: Indicator Infrastructure

### 3.1 Overview

Section 3 defines the indicator system: construction, registration, interactive development, and adapters.

**Design principles:**
1. **Pure functions** - Indicators are stateless computations
2. **Registry pattern** - Discoverable, reusable
3. **Adapter-based** - Easy integration with TTR, quantmod, custom code
4. **Interactive development** - Test indicators on frozen time windows

**Compliance:** All indicator tools MUST satisfy Invariant 2 (read-only interactive tools).

---

### 3.2 Indicator Contract

#### 3.2.1 `ledgr_indicator()`

**Purpose:** Construct an indicator object.

**Signature:**
```r
ledgr_indicator <- function(id, 
                             fn, 
                             requires_bars,
                             params = list())
```

**Parameters:**

- `id` - Unique identifier (character)
- `fn` - Indicator function: `function(window) -> numeric | list`
  - `window` is a data.frame with columns: `ts_utc`, `open`, `high`, `low`, `close`, `volume`
  - Returns single numeric value OR named list for multi-value indicators
- `requires_bars` - Minimum lookback period (integer)
- `params` - Named list of parameters (for documentation/serialization)

**Returns:** Object of class `ledgr_indicator`

**Contract for `fn` (purity requirements):**

```r
# Purity constraints:
# - NO side effects (no database writes, no file I/O, no global state mutation)
# - NO access to external data AT EXECUTION TIME
# - Deterministic (same input → same output)
# - May close over preloaded data IF immutable and declared in params

my_indicator_fn <- function(window) {
  # window is a data.frame
  # Rows are chronologically ordered (oldest first)
  # Last row is the current bar
  
  close_prices <- window$close
  
  # Compute indicator value
  result <- mean(close_prices)
  
  # Return single value
  return(result)
}
```

**Preloaded data closures (allowed):**

Indicators MAY close over immutable preloaded data (e.g., CSV loaded at construction time), provided:
1. Data is immutable (never modified after loading)
2. Data source is declared in `params` for provenance

Example:
```r
# CSV loaded at construction time
vendor_data <- read.csv("vendor_signals.csv")

vendor_fn <- function(window) {
  current_ts <- window$ts_utc[nrow(window)]
  vendor_data$value[vendor_data$ts_utc == current_ts]
}

vendor_indicator <- ledgr_indicator(
  id = "vendor_signal",
  fn = vendor_fn,
  requires_bars = 1L,
  params = list(
    data_source = "vendor_signals.csv",
    loaded_at = Sys.time()
  )
)
```

**Multi-value indicators:**
```r
bollinger_bands <- function(window) {
  sma <- mean(window$close)
  sd <- sd(window$close)
  
  # Return named list
  list(
    bb_mid = sma,
    bb_upper = sma + 2 * sd,
    bb_lower = sma - 2 * sd
  )
}
```

**Example:**
```r
# Simple moving average
sma_20 <- ledgr_indicator(
  id = "sma_20",
  fn = function(window) mean(window$close),
  requires_bars = 20L,
  params = list(n = 20)
)

# RSI
rsi_14 <- ledgr_indicator(
  id = "rsi_14",
  fn = function(window) {
    changes <- diff(window$close)
    gains <- pmax(changes, 0)
    losses <- abs(pmin(changes, 0))
    
    avg_gain <- mean(tail(gains, 14))
    avg_loss <- mean(tail(losses, 14))
    
    if (avg_loss == 0) return(100)
    
    rs <- avg_gain / avg_loss
    100 - (100 / (1 + rs))
  },
  requires_bars = 15L,
  params = list(n = 14)
)
```

---

#### 3.2.2 Indicator Execution

**Critical constraint:** Indicators are executed ONLY within the canonical pulse loop by the existing feature engine. They are NOT executed during strategy runtime (except via interactive tools for exploration).

**Execution flow:**

1. Pulse loop reaches timestamp T
2. Feature engine identifies required indicators
3. For each indicator:
   - Fetch historical window (last N bars where `ts_utc <= T`)
   - Call `indicator$fn(window)`
   - Store result in `features` table
4. Pass features to strategy via `ctx$features`

**No lookahead:** The window contains only bars with `ts_utc <= T`. The indicator cannot see future data.

**No state:** Each indicator call is independent. No values are cached between pulses (engine may cache computed features in DB, but that's transparent to indicator).

---

### 3.3 Indicator Registry

#### 3.3.1 Purpose

The registry enables:
- Discoverability (`ledgr_list_indicators()`)
- Reusability (define once, use many times)
- Sharing (community can publish indicator packages)

**Implementation:** Global environment (not user-facing).

**Serialization note:** At backtest execution time, indicators are serialized into run config (ID + params + function fingerprint), not stored as registry pointers. This ensures reproducibility even if registry contents change.

**Registry determinism rules:**

- Registering an indicator under an existing name MUST fail unless the caller
  explicitly requests overwrite.
- The run config MUST store the resolved indicator fingerprint used for the run,
  not just the registry name.
- The fingerprint MUST include indicator ID, deterministic params, required
  lookback, stable window, function body/formals, and adapter payload hashes
  where applicable.
- Reusing a `run_id` with a registry name that now resolves to different logic
  MUST fail via config-hash mismatch rather than silently reusing stale results.
- Functional strategy fingerprints follow the same principle: deterministic
  closure/default values must affect the key; non-deterministic captured values
  must fail before run creation.

---

#### 3.3.2 `ledgr_register_indicator()`

**Signature:**
```r
ledgr_register_indicator <- function(indicator, name = NULL)
```

**Parameters:**
- `indicator` - `ledgr_indicator` object
- `name` - Registry name (defaults to `indicator$id`)

**Returns:** Invisible indicator

**Example:**
```r
my_sma <- ledgr_indicator(
  id = "sma_50",
  fn = function(window) mean(window$close),
  requires_bars = 50L
)

ledgr_register_indicator(my_sma)

# Now available globally
sma <- ledgr_get_indicator("sma_50")
```

---

#### 3.3.3 `ledgr_get_indicator()`

**Signature:**
```r
ledgr_get_indicator <- function(name)
```

**Parameters:**
- `name` - Indicator name (character)

**Returns:** `ledgr_indicator` object

**Error handling:**
```r
ind <- ledgr_get_indicator("nonexistent")
#> Error: Indicator 'nonexistent' not found in registry
#> Available indicators: sma_50, sma_200, rsi_14, ema_12, ema_26
#> 
#> Register custom indicators with:
#>   ledgr_register_indicator(my_indicator)
```

---

#### 3.3.4 `ledgr_list_indicators()`

**Signature:**
```r
ledgr_list_indicators <- function(pattern = NULL)
```

**Parameters:**
- `pattern` - Optional regex filter

**Returns:** Character vector of indicator names

**Example:**
```r
ledgr_list_indicators()
#> [1] "sma_50"    "sma_200"   "ema_12"    "ema_26"    "rsi_14"    "return_1"

ledgr_list_indicators("^sma")
#> [1] "sma_50"  "sma_200"
```

---

### 3.4 Interactive Development Tools

#### 3.4.1 Purpose

Interactive development tools allow users to:
- Explore historical data windows
- Test indicator logic interactively
- Debug strategy decisions
- Develop indicators without blind coding

**Critical constraint:** Per Invariant 2, these tools are READ-ONLY. They never execute strategies within the engine runtime or write to the database.

**Execution clarification:** Interactive tools MAY execute indicator functions in-memory for exploration purposes, but they never write computed features to the database and never run the strategy runtime engine.

---

#### 3.4.2 `ledgr_indicator_dev()`

**Purpose:** Create an interactive development session for indicator testing.

**Signature:**
```r
ledgr_indicator_dev <- function(snapshot,
                                 instrument_id,
                                 ts_utc,
                                 lookback = 50L)
```

**Parameters:**
- `snapshot` - `ledgr_snapshot` object
- `instrument_id` - Instrument to analyze
- `ts_utc` - End timestamp for window
- `lookback` - Number of bars to include

**Returns:** Object of class `ledgr_indicator_dev`

**Behavior:**

1. Open dedicated database connection (internal, closed on exit)
2. Query snapshot database for historical bars (READ ONLY)
3. Construct window data.frame
4. Return object with helper methods

**NO database writes. NO strategy execution. NO persistent state mutation. Pure lens.**

**Structure:**
```r
structure(
  list(
    window = <data.frame>,
    instrument_id = "AAPL",
    ts_utc = "2020-06-15T00:00:00Z",
    lookback = 50L,
    
    # Private: dedicated connection for this session
    .con = <DBI connection>,
    
    # Helper methods (all read-only, in-memory execution)
    test = function(fn) { ... },
    test_dates = function(fn, dates) { ... },
    plot = function() { ... }
  ),
  class = "ledgr_indicator_dev"
)
```

**Connection lifecycle:**

Dedicated connection created internally, closed when object finalized or explicitly via:
```r
close.ledgr_indicator_dev <- function(x, ...) {
  if (!is.null(x$.con) && DBI::dbIsValid(x$.con)) {
    DBI::dbDisconnect(x$.con)
    x$.con <- NULL
  }
  invisible(x)
}
```

**Example usage:**
```r
# Create development session
dev <- ledgr_indicator_dev(
  snapshot = snap,
  instrument_id = "AAPL",
  ts_utc = "2020-06-15T00:00:00Z",
  lookback = 50
)

# Explore data
View(dev$window)

# Develop indicator logic interactively
close_prices <- dev$window$close
my_avg <- mean(close_prices)

# Test as function (in-memory execution, no DB writes)
my_fn <- function(window) mean(window$close)
dev$test(my_fn)
#> Result: 142.35

# Test on multiple dates
results <- dev$test_dates(my_fn, dates = c(
  "2020-01-15",
  "2020-03-15",
  "2020-06-15"
))
#>         date   value
#> 1 2020-01-15 135.20
#> 2 2020-03-15 128.45
#> 3 2020-06-15 142.35

# Visualize
dev$plot()  # Line chart of close prices

# Clean up (optional - finalizer handles this)
close(dev)
```

**Print method:**
```r
print.ledgr_indicator_dev <- function(x, ...) {
  cat("ledgr Indicator Development Session\n")
  cat("===================================\n\n")
  cat("Instrument:  ", x$instrument_id, "\n")
  cat("End Date:    ", x$ts_utc, "\n")
  cat("Lookback:    ", x$lookback, "bars\n")
  cat("Window:      ", x$window$ts_utc[1], "to", 
                       x$window$ts_utc[nrow(x$window)], "\n\n")
  cat("Available:\n")
  cat("  $window       - Historical OHLCV data (data.frame)\n")
  cat("  $test(fn)     - Test function on current window\n")
  cat("  $test_dates() - Test on multiple dates\n")
  cat("  $plot()       - Visualize window\n")
  invisible(x)
}
```

**Implementation of helper methods:**
```r
# $test() - Run function on current window (in-memory, no DB writes)
test = function(fn) {
  result <- fn(self$window)
  cat("Result:", result, "\n")
  invisible(result)
}

# $test_dates() - Test on multiple dates (each gets its own query)
test_dates = function(fn, dates) {
  results <- lapply(dates, function(date) {
    # Create new dev session for each date (uses same connection)
    dev_temp <- ledgr_indicator_dev(
      snapshot = private$snapshot,  # Stored internally
      instrument_id = self$instrument_id,
      ts_utc = date,
      lookback = self$lookback
    )
    
    value <- fn(dev_temp$window)
    close(dev_temp)  # Clean up
    
    list(date = date, value = value)
  })
  
  do.call(rbind, lapply(results, as.data.frame))
}

# $plot() - Visualize window (base R graphics)
plot = function() {
  plot(as.Date(self$window$ts_utc), self$window$close,
       type = "l",
       xlab = "Date",
       ylab = "Close Price",
       main = sprintf("%s - Window ending %s", 
                      self$instrument_id, self$ts_utc))
}
```

**Read-only enforcement:**

No methods perform database writes. Complies with Invariant 2 test criteria (persistent table row counts unchanged).

---

#### 3.4.3 `ledgr_pulse_snapshot()`

**Purpose:** Freeze a moment in time for interactive strategy development.

**Signature:**
```r
ledgr_pulse_snapshot <- function(snapshot,
                                  universe,
                                  ts_utc,
                                  features = list(),
                                  initial_cash = 100000,
                                  positions = NULL)
```

**Parameters:**
- `snapshot` - `ledgr_snapshot` object
- `universe` - Character vector of instruments
- `ts_utc` - Timestamp to freeze at
- `features` - List of `ledgr_indicator` objects to compute
- `initial_cash` - Mock cash balance
- `positions` - Mock current positions (NULL = flat)

**Returns:** Object of class `ledgr_pulse_context`

**Behavior:**

1. Open dedicated connection (internal, closed on exit)
2. Query bars for all instruments in universe at `ts_utc`
3. Compute feature values in-memory (execute indicator functions, but don't write to DB)
4. Construct context object (same structure as runtime `ctx`)
5. Return for interactive exploration

**NO strategy execution within engine. NO database writes. Pure lens with in-memory feature computation.**

**Structure (matches runtime context):**
```r
structure(
  list(
    ts_utc = "2020-06-15T00:00:00Z",
    universe = c("AAPL", "MSFT"),
    bars = <data.frame>,        # Latest OHLCV for each instrument
    features = <data.frame>,    # Computed feature values (in-memory)
    positions = c(AAPL = 0, MSFT = 0),
    cash = 100000,
    equity = 100000,
    
    # Private: dedicated connection
    .con = <DBI connection>
  ),
  class = "ledgr_pulse_context"
)
```

**Example usage:**
```r
# Freeze a moment in time
ctx <- ledgr_pulse_snapshot(
  snapshot = snap,
  universe = c("AAPL", "MSFT"),
  ts_utc = "2020-06-15T00:00:00Z",
  features = list(
    ledgr_ind_sma(50),
    ledgr_ind_rsi(14)
  )
)

# Explore interactively
View(ctx$bars)
View(ctx$features)

# Develop strategy logic
aapl_close <- ctx$bars$close[ctx$bars$instrument_id == "AAPL"]
aapl_sma50 <- ctx$features$feature_value[
  ctx$features$instrument_id == "AAPL" & 
  ctx$features$feature_name == "sma_50"
]

if (aapl_close > aapl_sma50) {
  signal <- "BUY"
} else {
  signal <- "SELL"
}

# Once logic works, wrap as strategy function
my_strategy <- function(ctx) {
  # Paste working code here
  aapl_close <- ctx$bars$close[ctx$bars$instrument_id == "AAPL"]
  aapl_sma50 <- ctx$features$feature_value[
    ctx$features$instrument_id == "AAPL" & 
    ctx$features$feature_name == "sma_50"
  ]
  
  if (aapl_close > aapl_sma50) {
    c(AAPL = 100, MSFT = 0)
  } else {
    c(AAPL = 0, MSFT = 100)
  }
}

# Clean up (optional - finalizer handles this)
close(ctx)
```

**Print method:**
```r
print.ledgr_pulse_context <- function(x, ...) {
  cat("ledgr Pulse Context\n")
  cat("==================\n\n")
  cat("Timestamp:   ", x$ts_utc, "\n")
  cat("Universe:    ", paste(x$universe, collapse = ", "), "\n")
  cat("Cash:        ", sprintf("$%.2f", x$cash), "\n")
  cat("Equity:      ", sprintf("$%.2f", x$equity), "\n\n")
  
  cat("Positions:\n")
  for (inst in names(x$positions)) {
    cat(sprintf("  %s: %d shares\n", inst, x$positions[inst]))
  }
  
  cat("\nData available:\n")
  cat("  $bars      - Latest OHLCV (", nrow(x$bars), " instruments)\n")
  cat("  $features  - Computed features (", nrow(x$features), " values)\n")
  cat("  $positions - Current positions\n")
  cat("  $cash      - Available cash\n")
  cat("  $equity    - Total equity\n")
  
  invisible(x)
}
```

**Read-only enforcement:**

This function queries the database and executes indicator functions in-memory, but never writes features to DB or runs strategy runtime. Compliance with Invariant 2 enforced via test suite.

---

### 3.5 Built-In Indicators (Minimal Set)

#### 3.5.1 Purpose

Ship 4 indicators to prove the pattern works. Users access 50+ more via TTR adapter.

**Built-ins:**
1. `ledgr_ind_sma()` - Simple Moving Average
2. `ledgr_ind_ema()` - Exponential Moving Average
3. `ledgr_ind_rsi()` - Relative Strength Index
4. `ledgr_ind_returns()` - Returns

**Note:** `stable_after` parameter removed from v0.1.2 to keep minimal. First few bars may yield NA for some indicators (expected behavior).

---

#### 3.5.2 `ledgr_ind_sma()`

```r
#' Simple Moving Average
#' @param n Window size
#' @export
ledgr_ind_sma <- function(n) {
  ledgr_indicator(
    id = sprintf("sma_%d", n),
    fn = function(window) {
      mean(window$close)
    },
    requires_bars = as.integer(n),
    params = list(n = n)
  )
}
```

**Auto-registered on package load:**
```r
.onLoad <- function(libname, pkgname) {
  ledgr_register_indicator(ledgr_ind_sma(50), "sma_50")
  ledgr_register_indicator(ledgr_ind_sma(200), "sma_200")
  # ...
}
```

---

#### 3.5.3 `ledgr_ind_ema()`

```r
#' Exponential Moving Average
#' @param n Window size
#' @export
ledgr_ind_ema <- function(n) {
  ledgr_indicator(
    id = sprintf("ema_%d", n),
    fn = function(window) {
      alpha <- 2 / (n + 1)
      ema <- window$close[1]
      
      for (i in 2:nrow(window)) {
        ema <- alpha * window$close[i] + (1 - alpha) * ema
      }
      
      ema
    },
    requires_bars = as.integer(n + 1),  # Need at least n+1 bars
    params = list(n = n)
  )
}
```

**Note:** First `n` values will be warming up. This is acceptable for v0.1.2.

---

#### 3.5.4 `ledgr_ind_rsi()`

```r
#' Relative Strength Index
#' @param n Window size (default 14)
#' @export
ledgr_ind_rsi <- function(n = 14L) {
  ledgr_indicator(
    id = sprintf("rsi_%d", n),
    fn = function(window) {
      changes <- diff(window$close)
      gains <- pmax(changes, 0)
      losses <- abs(pmin(changes, 0))
      
      avg_gain <- mean(tail(gains, n))
      avg_loss <- mean(tail(losses, n))
      
      if (avg_loss == 0) return(100)
      
      rs <- avg_gain / avg_loss
      100 - (100 / (1 + rs))
    },
    requires_bars = as.integer(n + 1),
    params = list(n = n)
  )
}
```

---

#### 3.5.5 `ledgr_ind_returns()`

```r
#' Simple Returns
#' @param n Periods back (default 1)
#' @export
ledgr_ind_returns <- function(n = 1L) {
  ledgr_indicator(
    id = sprintf("return_%d", n),
    fn = function(window) {
      current <- window$close[nrow(window)]
      previous <- window$close[nrow(window) - n]
      (current - previous) / previous
    },
    requires_bars = as.integer(n + 1),
    params = list(n = n)
  )
}
```

---

### 3.6 Indicator Adapters

#### 3.6.1 `ledgr_adapter_r()`

**Purpose:** Wrap R package functions (TTR, quantmod) as ledgr indicators.

**Signature:**
```r
ledgr_adapter_r <- function(pkg_fn, 
                             id, 
                             requires_bars, 
                             ...)
```

**Parameters:**
- `pkg_fn` - Function from R package (e.g., `TTR::RSI`)
- `id` - Indicator ID
- `requires_bars` - Lookback period
- `...` - Arguments passed to `pkg_fn`

**Returns:** `ledgr_indicator` object

**Implementation:**
```r
ledgr_adapter_r <- function(pkg_fn, id, requires_bars, ...) {
  
  # Capture arguments
  args <- list(...)
  
  ledgr_indicator(
    id = id,
    fn = function(window) {
      # Call package function with window$close
      result <- do.call(pkg_fn, c(list(window$close), args))
      
      # Return last value (most recent)
      tail(result, 1)
    },
    requires_bars = as.integer(requires_bars),
    params = args
  )
}
```

**Example usage:**
```r
library(TTR)

# Wrap TTR indicators
rsi <- ledgr_adapter_r(TTR::RSI, "ttr_rsi_14", 14L, n = 14)
sma <- ledgr_adapter_r(TTR::SMA, "ttr_sma_50", 50L, n = 50)
macd <- ledgr_adapter_r(TTR::MACD, "ttr_macd", 26L)

# Register
ledgr_register_indicator(rsi)
ledgr_register_indicator(sma)

# Use in backtest
bt <- ledgr_backtest(
  snapshot = snap,
  strategy = my_strategy,
  universe = "AAPL",
  features = list(
    ledgr_get_indicator("ttr_rsi_14"),
    ledgr_get_indicator("ttr_sma_50")
  )
)
```

**Graceful degradation:**
```r
rsi <- ledgr_adapter_r(TTR::RSI, ...)
#> Error: TTR package required
#> Install with: install.packages("TTR")
```

---

#### 3.6.2 `ledgr_adapter_csv()`

**Purpose:** Import pre-computed indicator values from CSV.

**Signature:**
```r
ledgr_adapter_csv <- function(csv_path, 
                               value_col, 
                               date_col = "ts_utc",
                               instrument_col = "instrument_id",
                               id)
```

**Parameters:**
- `csv_path` - Path to CSV file
- `value_col` - Column name with indicator values
- `date_col` - Column name with timestamps (default: "ts_utc")
- `instrument_col` - Column name with instrument IDs (default: "instrument_id")
- `id` - Indicator ID

**Returns:** `ledgr_indicator` object

**Required CSV format:**
```
ts_utc,instrument_id,signal_value
2020-01-01T00:00:00Z,AAPL,0.45
2020-01-01T00:00:00Z,MSFT,0.38
2020-01-02T00:00:00Z,AAPL,0.52
2020-01-02T00:00:00Z,MSFT,0.41
```

**Minimum columns:** `ts_utc`, `instrument_id`, `<value_col>`

**Implementation:**
```r
ledgr_adapter_csv <- function(csv_path, value_col, date_col = "ts_utc", 
                               instrument_col = "instrument_id", id) {
  
  # Load CSV once (at construction time - preloaded closure)
  indicator_data <- read.csv(csv_path)
  
  # Validate
  required <- c(date_col, instrument_col, value_col)
  missing <- setdiff(required, names(indicator_data))
  
  if (length(missing) > 0) {
    stop(sprintf(
      "CSV missing required columns: %s\nFound: %s",
      paste(missing, collapse = ", "),
      paste(names(indicator_data), collapse = ", ")
    ))
  }
  
  ledgr_indicator(
    id = id,
    fn = function(window) {
      # window has instrument_id column (from v0.1.1 feature engine)
      current_ts <- window$ts_utc[nrow(window)]
      current_inst <- window$instrument_id[nrow(window)]
      
      # Lookup by BOTH timestamp AND instrument
      idx <- which(
        indicator_data[[date_col]] == current_ts & 
        indicator_data[[instrument_col]] == current_inst
      )
      
      if (length(idx) == 0) {
        warning(sprintf(
          "No value found for %s/%s in %s",
          current_inst, current_ts, csv_path
        ))
        return(NA)
      }
      
      indicator_data[[value_col]][idx[1]]
    },
    requires_bars = 1L,  # Pre-computed, no lookback needed
    params = list(
      csv_path = csv_path,
      value_col = value_col,
      date_col = date_col,
      instrument_col = instrument_col
    )
  )
}
```

**Usage:**
```r
vendor_signal <- ledgr_adapter_csv(
  csv_path = "vendor_alpha.csv",
  value_col = "signal_value",
  id = "vendor_alpha"
)

bt <- ledgr_backtest(
  snapshot = snap,
  strategy = my_strategy,
  universe = c("AAPL", "MSFT"),
  features = list(vendor_signal)
)
```

---

## Section 4: Metrics & Visualization

### 4.1 Overview

Section 4 defines performance metrics computation and visualization.

**Design principles:**
1. **Post-hoc only** - Metrics are computed AFTER backtest completes
2. **Never influence execution** - Metrics read from ledger/equity tables, never affect strategy
3. **Basic built-ins** - Ship minimal set, defer advanced metrics to v0.1.3

**Compliance:** Metrics MUST NOT violate Invariant 1 (no execution semantics changes).

---

### 4.2 Fill Extraction

#### 4.2.1 `ledgr_extract_fills()`

**Purpose:** Extract all fill events from ledger with FIFO-computed realized P&L.

**Renamed from:** `ledgr_aggregate_trades()` (previous name was misleading - these are fills, not aggregated round-trip trades)

**Signature:**
```r
ledgr_extract_fills <- function(bt)
```

**Parameters:**
- `bt` - `ledgr_backtest` object

**Returns:** Tibble with columns:
- `ts_utc` - Fill timestamp
- `instrument_id` - Instrument
- `side` - "BUY" or "SELL"
- `qty` - Quantity
- `price` - Execution price
- `fee` - Transaction fee
- `realized_pnl` - Realized profit/loss (FIFO, 0 for opening fills)

**Implementation:**

```r
ledgr_extract_fills <- function(bt) {
  
  con <- get_connection(bt)
  
  # Extract ALL fill events
  ledger <- DBI::dbGetQuery(con, "
    SELECT 
      ts_utc,
      instrument_id,
      side,
      qty,
      price,
      fee,
      meta_json
    FROM ledger_events
    WHERE run_id = ? 
      AND event_type IN ('FILL', 'FILL_PARTIAL')
    ORDER BY event_seq
  ", params = list(bt$run_id))
  
  # Parse meta_json to extract realized_pnl
  ledger$meta <- lapply(ledger$meta_json, jsonlite::fromJSON)
  ledger$realized_pnl <- sapply(ledger$meta, function(m) {
    m$realized_pnl %||% 0
  })
  
  # Return ALL fills (not just closes)
  tibble::tibble(
    ts_utc = ledger$ts_utc,
    instrument_id = ledger$instrument_id,
    side = ledger$side,
    qty = ledger$qty,
    price = ledger$price,
    fee = ledger$fee,
    realized_pnl = ledger$realized_pnl
  )
}
```

**Note:** Round-trip trade aggregation (grouping fills into complete trades) deferred to v0.2.0.

**Rationale:**

FIFO (First-In-First-Out) accounting:
- Already implemented in `ledger_events.meta_json` from v0.1.1
- Tax-compliant (standard cost basis method)
- Works for all strategy types (long-only, long-short, always-in-market)
- Simple to extract from ledger (no additional computation)

---

### 4.3 Performance Metrics

#### 4.3.1 `ledgr_compute_metrics()`

**Purpose:** Compute performance metrics from backtest results.

**Signature:**
```r
ledgr_compute_metrics <- function(bt, metrics = "standard")
```

**Parameters:**
- `bt` - `ledgr_backtest` object
- `metrics` - Which metrics to compute:
  - `"standard"` - Basic built-in metrics (ONLY option in v0.1.2)
  - Other values error with helpful message

**Returns:** Named list of metric values

**Implementation:**

```r
ledgr_compute_metrics <- function(bt, metrics = "standard") {
  
  # Only "standard" supported in v0.1.2
  if (!identical(metrics, "standard")) {
    stop(
      "Only metrics='standard' supported in v0.1.2\n",
      "Advanced metrics (PerformanceAnalytics integration) available in v0.1.3"
    )
  }
  
  con <- get_connection(bt)
  
  # Get equity curve from pre-computed table
  equity <- DBI::dbGetQuery(con, "
    SELECT ts_utc, equity, cash, positions_value
    FROM equity_curve
    WHERE run_id = ?
    ORDER BY pulse_seq
  ", params = list(bt$run_id))
  
  # Get fills
  fills <- ledgr_extract_fills(bt)
  
  # Compute returns (use simple returns, handle NAs)
  returns <- c(NA, diff(equity$equity) / equity$equity[-length(equity$equity)])
  returns <- returns[!is.na(returns)]  # Remove first NA
  
  # Standard metrics with zero guards
  list(
    # Returns
    total_return = (equity$equity[nrow(equity)] / equity$equity[1]) - 1,
    annualized_return = compute_annualized_return(equity),
    
    # Risk
    volatility = if (length(returns) > 1) sd(returns, na.rm = TRUE) * sqrt(252) else NA,
    max_drawdown = compute_max_drawdown(equity$equity),
    
    # Trade statistics (with zero guards)
    n_trades = nrow(fills),
    win_rate = if (nrow(fills) > 0) sum(fills$realized_pnl > 0) / nrow(fills) else NA,
    avg_trade = if (nrow(fills) > 0) mean(fills$realized_pnl) else NA,
    
    # Exposure (computed from positions_value)
    time_in_market = compute_time_in_market(equity)
  )
}
```

**Helper functions:**

```r
compute_annualized_return <- function(equity) {
  # Days in backtest
  days <- as.numeric(difftime(
    as.Date(equity$ts_utc[nrow(equity)]),
    as.Date(equity$ts_utc[1]),
    units = "days"
  ))
  
  if (days <= 0) return(NA)
  
  years <- days / 365.25
  
  total_return <- (equity$equity[nrow(equity)] / equity$equity[1]) - 1
  
  if (years <= 0) return(NA)
  
  (1 + total_return)^(1 / years) - 1
}

compute_max_drawdown <- function(equity_values) {
  running_max <- cummax(equity_values)
  drawdown <- (equity_values / running_max) - 1
  min(drawdown)
}

compute_time_in_market <- function(equity) {
  # Computed from positions_value column (already in equity_curve table)
  # Fraction of pulses with non-zero position value
  mean(abs(equity$positions_value) > 1e-6)
}
```

**Metrics included in v0.1.2:**

| Metric | Description | Zero-guard |
|--------|-------------|------------|
| `total_return` | Total return (%) | N/A |
| `annualized_return` | Annualized return (%) | Returns NA if days <= 0 |
| `volatility` | Annualized volatility (%) | Returns NA if < 2 returns |
| `max_drawdown` | Maximum drawdown (%) | N/A |
| `n_trades` | Total number of fills | N/A |
| `win_rate` | % of profitable fills | Returns NA if no trades |
| `avg_trade` | Average realized P&L per fill | Returns NA if no trades |
| `time_in_market` | Fraction of time with positions | N/A |

**Advanced metrics (Sharpe, Sortino, Calmar, VaR, CVaR, etc.) deferred to v0.1.3 via PerformanceAnalytics integration.**

---

#### 4.3.2 Equity Curve Computation

**Purpose:** Extract equity curve from v0.1.1 pre-computed `equity_curve` table.

**Signature:**
```r
ledgr_compute_equity_curve <- function(bt)
```

**Implementation:**

```r
ledgr_compute_equity_curve <- function(bt) {
  
  con <- get_connection(bt)
  
  # Read from equity_curve table (already computed by v0.1.1 engine)
  equity <- DBI::dbGetQuery(con, "
    SELECT ts_utc, equity, cash, positions_value
    FROM equity_curve
    WHERE run_id = ?
    ORDER BY pulse_seq
  ", params = list(bt$run_id))
  
  # Compute drawdown columns
  equity$running_max <- cummax(equity$equity)
  equity$drawdown <- (equity$equity / equity$running_max - 1) * 100
  
  tibble::as_tibble(equity)
}
```

**Note:** v0.1.1 engine already computes and stores equity curve during backtest execution. This function just reads it and adds drawdown columns.

---

### 4.3.3 Snapshot-Backed State Reconstruction

**Purpose:** Rebuild derived state for a run from event-sourced ledger artifacts
and the same market data source used during execution.

`ledgr_state_reconstruct(run_id, con)` remains a public core API. In v0.1.2 it
MUST support both:

1. Legacy v0.1.0 runs that read from persistent `bars`
2. Snapshot-backed v0.1.1/v0.1.2 runs that read from sealed `snapshot_bars`

**Snapshot-backed reconstruction contract:**

- Read `snapshot_id` and snapshot database provenance from `runs.config_json`
- Reopen the snapshot DB when it differs from the run-ledger DB
- Recompute and verify `snapshot_hash` before rebuilding
- Use the recorded sealed snapshot as the source for pulse calendars and
  mark-to-market prices
- Fail loudly if the snapshot source is missing, unsealed, or corrupted
- Rebuilt `positions`, `cash`, `pnl`, and `equity_curve` MUST match the run's
  derived artifacts for the same ledger

**Rationale:** v0.1.2 high-level APIs make snapshot-backed runs the normal user
path. Reconstruction that only reads a legacy `bars` table breaks the inherited
deterministic replay guarantee.

---

### 4.4 Visualization

#### 4.4.1 `plot.ledgr_backtest()`

**Purpose:** Visualize backtest results using ggplot2.

**Signature:**
```r
#' @export
plot.ledgr_backtest <- function(x, ..., type = "equity")
```

The package MUST register `S3method(plot, ledgr_backtest)` so `plot(bt)`
dispatches to this method. This is required because `print.ledgr_backtest()`
advertises `plot(bt)` as the user-facing visualization entrypoint.

**Parameters:**
- `x` - `ledgr_backtest` object
- `...` - Additional arguments (unused)
- `type` - Plot type:
  - `"equity"` - Equity curve + drawdown (default)
  - `"trades"` - Trade distribution (deferred to v0.1.3)
  - `"returns"` - Returns histogram (deferred to v0.1.3)

**Implementation for equity plot:**

```r
plot.ledgr_backtest <- function(x, ..., type = "equity") {
  
  type <- match.arg(type, c("equity", "trades", "returns"))
  
  if (type != "equity") {
    stop(sprintf("Plot type '%s' not yet implemented in v0.1.2", type))
  }
  
  # Get equity curve
  eq <- as_tibble(x, "equity")
  eq$date <- as.Date(eq$ts_utc)
  
  # Equity curve plot (use ggplot2 defaults for colors)
  p1 <- ggplot2::ggplot(eq, ggplot2::aes(x = date, y = equity)) +
    ggplot2::geom_line(size = 1) +
    ggplot2::labs(
      title = "Equity Curve",
      x = NULL,
      y = "Equity ($)"
    ) +
    ggplot2::theme_minimal()
  
  # Drawdown plot (use ggplot2 defaults for colors)
  p2 <- ggplot2::ggplot(eq, ggplot2::aes(x = date, y = drawdown)) +
    ggplot2::geom_area(alpha = 0.6) +
    ggplot2::labs(
      title = "Drawdown",
      x = "Date",
      y = "Drawdown (%)"
    ) +
    ggplot2::theme_minimal()
  
  # Combine plots if gridExtra available
  if (requireNamespace("gridExtra", quietly = TRUE)) {
    gridExtra::grid.arrange(p1, p2, ncol = 1)
  } else {
    # Fallback: show equity only
    print(p1)
    message(
      "\nShowing equity curve only.\n",
      "Install 'gridExtra' for combined equity + drawdown plot:\n",
      "  install.packages('gridExtra')"
    )
  }
  
  invisible(x)
}
```

**Example usage:**

```r
plot(bt)
```

Produces:
- If `gridExtra` available: Two-panel plot (equity + drawdown)
- If not: Single equity curve with helpful message

**Layout:**
- Top panel: Line chart of equity over time
- Bottom panel: Area chart of drawdown (negative values)

**Colors:** Uses ggplot2 default color scheme (not hardcoded)

**Additional plot types deferred to v0.1.3**

---

### 4.5 Post-Hoc Guarantee

**Critical constraint:** All metrics and visualizations MUST be computed post-hoc from ledger/equity tables. They MUST NOT influence execution.

**Enforcement:**

1. Metrics read from `ledger_events` and `equity_curve` tables (read-only)
2. Equity curve read from pre-computed table (read-only)
3. Fills extracted from ledger (read-only)
4. No writes to database during metric/visualization computation
5. No feedback loop to strategy execution

**Test:**

```r
# Compute metrics
metrics1 <- ledgr_compute_metrics(bt)

# Re-compute (should be identical)
metrics2 <- ledgr_compute_metrics(bt)

stopifnot(identical(metrics1, metrics2))

# Metrics don't affect ledger
con <- get_connection(bt)
ledger_before <- nrow(DBI::dbGetQuery(con, "SELECT * FROM ledger_events WHERE run_id = ?", 
                                       params = list(bt$run_id)))
metrics <- ledgr_compute_metrics(bt)
ledger_after <- nrow(DBI::dbGetQuery(con, "SELECT * FROM ledger_events WHERE run_id = ?",
                                      params = list(bt$run_id)))

stopifnot(ledger_before == ledger_after)
```

---

## End of Sections 2-4 (CORRECTED)

**Summary:**

- **Section 2:** High-level API contract (data ingestion, `ledgr_backtest()`, S3 methods)
  - Lazy connections, canonical ID generation, no caching
- **Section 3:** Indicator infrastructure (construction, registry, interactive dev, adapters)
  - Preloaded closures allowed, stable_after removed, adapter_csv fixed
- **Section 4:** Metrics & visualization (fill extraction, basic metrics, ggplot2)
  - Fills not trades, zero guards, equity_curve table usage

**Next sections:**
- Section 5: Implementation Constraints
- Section 6: Testing Requirements
- Section 7: Deferred Features

---

## Changelog (v2.1.1 from v2.0.2)

### Critical Fixes

**Section 2:**
1. **2.2.2** - Removed digest-based snapshot_id generation; use v0.1.1 canonical behavior
2. **2.2.5** - Changed to lazy connection pattern; added `ledgr_snapshot_close()` method
3. **2.3.1** - Removed "or database connection" option; accept only `ledgr_snapshot`
4. **2.3.2** - Added explicit specifications for target positions (shares/contracts) and context schemas
5. **2.4** - Removed caching; methods compute fresh data each call
6. **2.4.4** - Fixed `as_tibble()` to not mutate object

**Section 3:**
7. **3.2.1** - Fixed purity wording: "no external data AT EXECUTION TIME"; preloaded closures allowed
8. **3.4.2** - Clarified interactive tools may execute indicator functions in-memory but never write to DB
9. **3.5** - Removed `stable_after` parameter entirely from v0.1.2
10. **3.6.2** - Fixed `adapter_csv()` to require `instrument_id` column and lookup by both timestamp AND instrument

**Section 4:**
11. **4.2** - Renamed to `ledgr_extract_fills()`; returns ALL fills, not aggregated trades
12. **4.3.1** - Only accept `metrics="standard"`; added zero guards for win_rate, avg_trade
13. **4.3.1** - Fixed returns computation with `na.rm=TRUE`
14. **4.3.1** - Fixed `time_in_market` to compute from `positions_value` not fills
15. **4.3.2** - Fixed to read from `equity_curve` table directly (not window function over ledger)
16. **4.4.1** - Removed color specifications; use ggplot2 defaults
17. **4.4.1** - Made `gridExtra` optional with graceful fallback

### Additions

18. **Preamble** - Added schema assumptions, timestamp format policy, connection lifecycle policy
19. **2.2.5** - Added connection lifecycle notes and Windows file lock considerations
20. **3.4** - Added dedicated connection management for interactive tools
21. **4.3.1** - Added comprehensive zero guards and NA handling

### v2.1.1 Code Review Amendments

22. **1.2.1** - Added correctness amendment layer for snapshot hashing, seal validation, split DB semantics, strategy validation, replay determinism, context parity, reconstruction, and exports
23. **2.1.1** - Added public API export contract
24. **2.2.2** - Clarified artifact-only snapshot hashing and seal-time validation
25. **2.3.1** - Clarified split snapshot DB/run ledger DB semantics
26. **2.3.2** - Changed missing functional strategy targets from implicit zero to fail-loud validation
27. **3.3.1** - Strengthened registry-backed replay determinism requirements
28. **4.3.3** - Added snapshot-backed reconstruction contract
29. **4.4.1** - Required `plot.ledgr_backtest()` S3 registration

### v2.1.2 UX Amendments

30. **2.3.1** - Added data-first `ledgr_backtest(data = bars, ...)` convenience mode that implicitly creates a sealed snapshot and still delegates to `ledgr_run()`
31. **2.3.1** - Added equivalence requirement for data-first mode versus explicit snapshot workflows
32. **2.3.2** - Clarified that raw signal strings such as `"LONG"`/`"FLAT"` are not valid core strategy outputs; signal helpers must map to full target vectors before validation

### Approved

This corrected specification has been implemented and verified for the v0.1.2 release.

# ledgr v0.1.2 Specification - Sections 5-7: Constraints, Testing & Deferrals (CORRECTED)

**Document Version:** 2.2.2
**Author:** Max Thomasberger  
**Date:** December 20, 2025  
**Amendment Date:** April 24, 2026  
**Release Type:** User Experience Milestone  
**Status:** Approved for Release
**Changelog:** Critical correctness fixes from peer review

---

## Section 5: Implementation Constraints

### 5.1 Overview

Section 5 defines the rules and patterns that all v0.1.2 code MUST follow to maintain compliance with the three hard invariants from Section 1.

**Purpose:** Provide implementers with concrete guidance on how to write code that satisfies the specification without violating constraints.

**Scope:** These constraints apply to ALL new code in v0.1.2. Existing v0.1.1 code remains unchanged.

---

### 5.2 Wrapper Function Constraints

**Rule:** High-level wrapper functions MUST delegate to canonical v0.1.1 implementations.

#### 5.2.1 `ledgr_backtest()` Implementation Pattern

**Required structure:**

```r
ledgr_backtest <- function(...user_params...) {
  # Phase 1: VALIDATE inputs
  # - Type checking
  # - Range checking
  # - Existence checking
  # Early return with helpful errors
  
  # Phase 2: RESOLVE data source
  # - If data is a data.frame, call ledgr_snapshot_from_df()
  # - If data/snapshot is a ledgr_snapshot, use it directly
  # - Reject ambiguous calls that provide both data and snapshot
  # - Do not write legacy bars directly

  # Phase 3: BUILD canonical config
  # - Use existing ledgr_config() builder
  # - Use existing sub-builders (ledgr_backtest_config, etc.)
  # - NO timestamp normalization here (done in builders)
  # - No new config structures
  
  # Phase 4: CALL canonical engine
  result <- ledgr_run(config)
  
  # Phase 5: WRAP result
  # - Add S3 class
  # - NO additional computation
  # - NO database writes
  
  # Phase 6: RETURN
  return(result)
}
```

**Critical normalization constraint:**

> **Timestamp normalization MUST occur exactly once, in a single canonical place.**
>
> If `ledgr_config()` already normalizes timestamps, wrappers MUST NOT normalize again. If builders do not normalize, create a shared helper function used by ALL entrypoints.
>
> Double normalization or inconsistent normalization between entrypoints violates Invariant 3.

**Forbidden patterns:**

```r
# ❌ WRONG - Don't normalize if builder already does
ledgr_backtest <- function(..., start, end, ...) {
  start <- iso_utc(start)  # Double normalization if ledgr_config() also does this
  end <- iso_utc(end)
  
  config <- ledgr_config(...)  # Already normalizes internally
}

# ❌ WRONG - Don't create alternate execution path
ledgr_backtest <- function(...) {
  if (simple_case) {
    # Special fast path
    run_simplified_engine(...)
  } else {
    ledgr_run(...)
  }
}

# ❌ WRONG - Don't add execution logic
ledgr_backtest <- function(...) {
  result <- ledgr_run(...)
  
  # Recompute some fills with different logic
  result$trades <- custom_trade_aggregation(result)
  
  return(result)
}

# ❌ WRONG - Don't write to database
ledgr_backtest <- function(...) {
  result <- ledgr_run(...)
  
  # Store summary in new table
  DBI::dbExecute(con, "INSERT INTO backtest_summaries ...")
  
  return(result)
}
```

**Correct pattern:**

```r
# ✅ CORRECT - Pure wrapper (assumes ledgr_config() handles normalization)
ledgr_backtest <- function(snapshot = NULL, strategy, universe = NULL, start, end,
                            initial_cash = 100000, features = list(), 
                            fill_model = NULL, db_path = NULL, run_id = NULL,
                            data = NULL) {
  
  # Resolve exactly one source.
  if (!is.null(snapshot) && !is.null(data)) {
    stop("Provide only one of `snapshot` or `data`.")
  }
  if (!is.null(data) && inherits(data, "ledgr_snapshot")) {
    snapshot <- data
    data <- NULL
  }
  if (!is.null(data)) {
    snapshot_db <- db_path %||% tempfile(fileext = ".duckdb")
    snapshot <- ledgr_snapshot_from_df(data, db_path = snapshot_db)
  }
  if (!inherits(snapshot, "ledgr_snapshot")) {
    stop("Provide `snapshot` or data-frame `data`.")
  }
  
  if (is.null(universe)) {
    universe <- infer_universe(snapshot)
  }
  
  # Build config (normalization happens in builders)
  config <- ledgr_config(
    snapshot = snapshot,
    universe = universe,
    strategy = strategy,
    backtest = ledgr_backtest_config(
      start = start %||% snapshot$metadata$start_date,
      end = end %||% snapshot$metadata$end_date,
      initial_cash = initial_cash
    ),
    features = features,
    fill_model = fill_model %||% ledgr_fill_model_instant(),
    snapshot_db_path = snapshot$db_path,
    db_path = db_path %||% snapshot$db_path,
    run_id = run_id
  )
  
  # Call engine
  result <- ledgr_run(config)
  
  # Wrap
  structure(result, class = c("ledgr_backtest", class(result)))
}
```

**Test enforcement:**

```r
test_that("ledgr_backtest is a pure wrapper", {
  # Setup
  snap <- ledgr_snapshot_from_df(test_bars)
  
  # Direct config approach
  config <- ledgr_config(
    snapshot = snap,
    universe = c("TEST_A", "TEST_B"),
    strategy = test_strategy,
    backtest = ledgr_backtest_config(start = "2020-01-01", end = "2020-12-31")
  )
  result_direct <- ledgr_run(config)
  
  # Wrapper approach
  result_wrapper <- ledgr_backtest(
    snapshot = snap,
    strategy = test_strategy,
    universe = c("TEST_A", "TEST_B"),
    start = "2020-01-01",
    end = "2020-12-31"
  )
  
  # Compare observable outputs (not config, which may have internal differences)
  # 1. Ledger events must be semantically identical
  events1 <- get_ledger_events(result_direct$run_id)
  events2 <- get_ledger_events(result_wrapper$run_id)
  
  # Remove run_id and timestamps for comparison
  compare_cols <- c("event_seq", "event_type", "instrument_id", "side", "qty", "price", "fee")
  
  expect_equal(nrow(events1), nrow(events2))
  expect_identical(events1[, compare_cols], events2[, compare_cols])
  
  # 2. Final equity must match
  eq1 <- get_final_equity(result_direct$run_id)
  eq2 <- get_final_equity(result_wrapper$run_id)
  
  expect_equal(eq1, eq2, tolerance = 1e-10)
})

# Helper functions for tests (define these in test utilities)
get_ledger_events <- function(run_id) {
  con <- get_test_connection()
  DBI::dbGetQuery(con, "
    SELECT * FROM ledger_events 
    WHERE run_id = ? 
    ORDER BY event_seq
  ", params = list(run_id))
}

get_final_equity <- function(run_id) {
  con <- get_test_connection()
  DBI::dbGetQuery(con, "
    SELECT equity FROM equity_curve 
    WHERE run_id = ? 
    ORDER BY pulse_seq DESC 
    LIMIT 1
  ", params = list(run_id))[[1]]
}
```

---

#### 5.2.2 Data Ingestion Adapter Pattern

**Required structure:**

```r
ledgr_snapshot_from_<source> <- function(...source_params...) {
  # Phase 1: VALIDATE source availability
  # - Check for required packages
  # - Fail gracefully with install instructions
  
  # Phase 2: FETCH data
  # - Use source-specific API
  # - Handle source errors
  
  # Phase 3: NORMALIZE format
  # - Convert to standard data.frame
  # - Extract columns BY NAME (not position)
  # - Normalize timestamps to ISO 8601 UTC
  # - Validate schema
  
  # Phase 4: DELEGATE to canonical ingestion
  ledgr_snapshot_from_df(bars_df, ...)
}
```

**Example (corrected column extraction):**

```r
ledgr_snapshot_from_yahoo <- function(symbols, from, to, db_path = NULL, 
                                       snapshot_id = NULL, ...) {
  
  # Validate package availability
  if (!requireNamespace("quantmod", quietly = TRUE)) {
    stop(
      "quantmod package required\n",
      "Install with: install.packages('quantmod')"
    )
  }
  
  # Fetch data
  all_bars <- list()
  
  for (symbol in symbols) {
    message("Fetching ", symbol, "...")
    
    tryCatch({
      data <- quantmod::getSymbols(
        symbol, 
        from = from, 
        to = to,
        auto.assign = FALSE,
        ...
      )
      
      # Extract by NAME suffix (Yahoo returns SYMBOL.Open, SYMBOL.High, etc.)
      col_names <- colnames(data)
      
      bars <- data.frame(
        ts_utc = format(zoo::index(data), "%Y-%m-%dT%H:%M:%SZ"),
        instrument_id = symbol,
        open = as.numeric(data[, grep("\\.Open$", col_names)]),
        high = as.numeric(data[, grep("\\.High$", col_names)]),
        low = as.numeric(data[, grep("\\.Low$", col_names)]),
        close = as.numeric(data[, grep("\\.Close$", col_names)]),
        volume = as.numeric(data[, grep("\\.Volume$", col_names)])
      )
      
      all_bars[[symbol]] <- bars
      
    }, error = function(e) {
      stop(sprintf("Failed to fetch %s: %s", symbol, e$message))
    })
  }
  
  # Combine
  bars_df <- do.call(rbind, all_bars)
  
  # Delegate to canonical ingestion
  ledgr_snapshot_from_df(bars_df, db_path = db_path, snapshot_id = snapshot_id)
}
```

---

### 5.3 Pure Indicator Function Constraints

**Rule:** Indicator functions MUST be pure, deterministic, and side-effect-free.

#### 5.3.1 Required Properties

**Determinism:**
- Same input → same output
- No randomness (no `runif()`, `rnorm()`, etc.)
- No system state (no `Sys.time()`, `Sys.getenv()`)

**No side effects:**
- No file I/O (no `write.csv()`, `saveRDS()`)
- No database writes (no `DBI::dbExecute()`)
- No global state mutation (no `<<-` assignment)
- No printing/messaging during execution (no `print()`, `message()`)

**No external data access at execution time:**
- No web requests (no `httr::GET()`)
- No reading from disk during execution (loading at construction OK)
- Window parameter is the ONLY data source

**Allowed exception - Preloaded closures:**

Indicators MAY close over immutable data loaded at construction time, provided:
1. Data is loaded ONCE at indicator construction
2. Data is never modified after loading
3. Data source is declared in `params` for provenance
4. **`params` contains only DETERMINISTIC, STABLE values** (no `Sys.time()`)

```r
# ✅ ALLOWED - Data loaded at construction with deterministic provenance
vendor_data <- read.csv("signals.csv")
data_hash <- digest::digest(vendor_data)  # Deterministic fingerprint

vendor_indicator <- ledgr_indicator(
  id = "vendor_signal",
  fn = function(window) {
    # Closure over vendor_data (immutable)
    current_ts <- window$ts_utc[nrow(window)]
    current_inst <- window$instrument_id[nrow(window)]
    vendor_data$value[
      vendor_data$ts_utc == current_ts & 
      vendor_data$instrument_id == current_inst
    ]
  },
  requires_bars = 1L,
  params = list(
    data_source = "signals.csv",
    data_hash = data_hash  # Deterministic provenance
  )
)

# ❌ FORBIDDEN - Sys.time() in params (non-deterministic)
bad_indicator <- ledgr_indicator(
  id = "bad",
  fn = function(window) { ... },
  requires_bars = 10L,
  params = list(
    loaded_at = Sys.time()  # Non-deterministic, violates fingerprinting
  )
)

# ❌ FORBIDDEN - Reading at execution time
bad_indicator <- ledgr_indicator(
  id = "bad",
  fn = function(window) {
    # Reads file every execution
    data <- read.csv("signals.csv")
    # ...
  }
)
```

**Note on metadata:** If non-deterministic metadata is needed for debugging (e.g., load time), store it outside `params` in a separate field like `indicator$meta` that is NOT used for fingerprinting.

---

#### 5.3.2 Test Enforcement

**Determinism test:**

```r
test_that("indicator is deterministic", {
  window <- data.frame(
    ts_utc = c("2020-01-01T00:00:00Z", "2020-01-02T00:00:00Z"),
    instrument_id = c("TEST_A", "TEST_A"),
    open = c(100, 101),
    high = c(102, 103),
    low = c(99, 100),
    close = c(101, 102),
    volume = c(1000, 1100)
  )
  
  indicator <- ledgr_ind_sma(2)
  
  result1 <- indicator$fn(window)
  result2 <- indicator$fn(window)
  result3 <- indicator$fn(window)
  
  expect_identical(result1, result2)
  expect_identical(result2, result3)
})
```

**No side effects test:**

```r
test_that("indicator has no side effects", {
  window <- test_window_data
  indicator <- ledgr_ind_rsi(14)
  
  # Should produce no output
  expect_silent(indicator$fn(window))
  
  # Static check: forbid <<- assignment
  fn_body <- deparse(indicator$fn)
  expect_false(any(grepl("<<-", fn_body, fixed = TRUE)),
               info = "Indicator function contains <<- assignment")
})
```

---

### 5.4 Read-Only Interactive Tool Constraints

**Rule:** Interactive tools MUST NOT modify persistent database state.

#### 5.4.1 Implementation Pattern (Environment-Backed)

**Required structure:**

```r
ledgr_<interactive_tool> <- function(...) {
  # Phase 1: CREATE dedicated connection
  con <- ledgr_db_connect(db_path)
  
  # Phase 2: QUERY database (read-only)
  # - Use SELECT queries only
  # - May create TEMP VIEW/TABLE for convenience
  
  # Phase 3: CREATE environment-backed object
  e <- new.env(parent = emptyenv())
  
  # Store data in environment
  e$data <- query_results
  e$.con <- con
  e$.private <- list(...)  # Private fields
  
  # Phase 4: SET UP cleanup via finalizer
  reg.finalizer(e, function(env) {
    if (!is.null(env$.con) && DBI::dbIsValid(env$.con)) {
      DBI::dbDisconnect(env$.con)
    }
  }, onexit = TRUE)
  
  # Phase 5: SET class and RETURN
  class(e) <- "ledgr_<tool_name>"
  e
}
```

**Example (corrected finalizer pattern):**

```r
ledgr_indicator_dev <- function(snapshot, instrument_id, ts_utc, lookback = 50L) {
  
  # Open dedicated connection
  con <- ledgr_db_connect(snapshot$db_path)
  
  # Query historical window (READ ONLY)
  window <- DBI::dbGetQuery(con, "
    SELECT ts_utc, instrument_id, open, high, low, close, volume
    FROM snapshot_bars
    WHERE snapshot_id = ? 
      AND instrument_id = ? 
      AND ts_utc <= ?
    ORDER BY ts_utc DESC
    LIMIT ?
  ", params = list(snapshot$snapshot_id, instrument_id, ts_utc, lookback))
  
  # Reverse to chronological order
  window <- window[rev(seq_len(nrow(window))), ]
  
  # Create environment-backed object
  e <- new.env(parent = emptyenv())
  
  # Store data
  e$window <- window
  e$instrument_id <- instrument_id
  e$ts_utc <- ts_utc
  e$lookback <- lookback
  e$.con <- con
  e$.snapshot <- snapshot  # For test_dates() helper
  
  # Set up cleanup finalizer
  reg.finalizer(e, function(env) {
    if (!is.null(env$.con) && DBI::dbIsValid(env$.con)) {
      DBI::dbDisconnect(env$.con)
      env$.con <- NULL
    }
  }, onexit = TRUE)
  
  # Set class
  class(e) <- "ledgr_indicator_dev"
  
  e
}

# Explicit close method
close.ledgr_indicator_dev <- function(x, ...) {
  if (!is.null(x$.con) && DBI::dbIsValid(x$.con)) {
    DBI::dbDisconnect(x$.con)
    x$.con <- NULL
  }
  invisible(x)
}

# Helper methods access environment fields
test.ledgr_indicator_dev <- function(x, fn) {
  result <- fn(x$window)
  cat("Result:", result, "\n")
  invisible(result)
}

test_dates.ledgr_indicator_dev <- function(x, fn, dates) {
  results <- lapply(dates, function(date) {
    # Create new dev session for each date
    temp_dev <- ledgr_indicator_dev(
      snapshot = x$.snapshot,
      instrument_id = x$instrument_id,
      ts_utc = date,
      lookback = x$lookback
    )
    value <- fn(temp_dev$window)
    close(temp_dev)
    list(date = date, value = value)
  })
  do.call(rbind, lapply(results, as.data.frame))
}

plot.ledgr_indicator_dev <- function(x, ...) {
  plot(as.Date(x$window$ts_utc), x$window$close,
       type = "l", xlab = "Date", ylab = "Close Price",
       main = sprintf("%s - Window ending %s", x$instrument_id, x$ts_utc))
}

# Print method
print.ledgr_indicator_dev <- function(x, ...) {
  cat("ledgr Indicator Development Session\n")
  cat("===================================\n\n")
  cat("Instrument:  ", x$instrument_id, "\n")
  cat("End Date:    ", x$ts_utc, "\n")
  cat("Lookback:    ", x$lookback, "bars\n")
  cat("Window:      ", x$window$ts_utc[1], "to", 
                       x$window$ts_utc[nrow(x$window)], "\n\n")
  cat("Available:\n")
  cat("  $window       - Historical OHLCV data (data.frame)\n")
  cat("  test(fn)      - Test function on current window\n")
  cat("  test_dates()  - Test on multiple dates\n")
  cat("  plot()        - Visualize window\n")
  invisible(x)
}
```

---

#### 5.4.2 Test Enforcement

**Persistent table mutation test:**

```r
test_that("interactive tool does not mutate persistent tables", {
  snap <- ledgr_snapshot_from_df(test_bars)
  
  # Capture state of persistent tables
  con <- ledgr_db_connect(snap$db_path)
  persistent_tables <- c("snapshots", "snapshot_bars", "snapshot_instruments")
  
  counts_before <- sapply(persistent_tables, function(tbl) {
    DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) FROM %s", tbl))[[1]]
  })
  
  DBI::dbDisconnect(con)
  
  # Call interactive tool
  dev <- ledgr_indicator_dev(snap, "TEST_A", "2020-06-15", lookback = 50)
  
  # Use tool methods
  test(dev, function(w) mean(w$close))
  plot(dev)
  
  # Clean up
  close(dev)
  
  # Verify no persistent mutations
  con <- ledgr_db_connect(snap$db_path)
  counts_after <- sapply(persistent_tables, function(tbl) {
    DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) FROM %s", tbl))[[1]]
  })
  
  DBI::dbDisconnect(con)
  ledgr_snapshot_close(snap)
  
  expect_identical(counts_before, counts_after)
})
```

**Note:** TEMP object cleanup tests are fragile with DuckDB and have been removed. The persistent table mutation test is sufficient to enforce Invariant 2.

---

### 5.5 Database Connection Hygiene

**Rule:** Manage connection lifecycle explicitly to avoid resource leaks.

#### 5.5.1 Lazy Connection Pattern (Preferred)

**For snapshot and backtest objects:**

```r
# Store path, not connection
structure(
  list(
    db_path = "/path/to/db.duckdb",
    snapshot_id = "...",
    .con = NULL  # Opened on-demand
  ),
  class = "ledgr_snapshot"
)

# Internal helper (not exported)
get_connection <- function(snapshot) {
  if (is.null(snapshot$.con) || !DBI::dbIsValid(snapshot$.con)) {
    snapshot$.con <- DBI::dbConnect(duckdb::duckdb(), dbdir = snapshot$db_path)
  }
  snapshot$.con
}

# Use in methods
print.ledgr_snapshot <- function(x, ...) {
  con <- get_connection(x)  # Opens if needed
  # Query database
  # ...
}
```

**Benefits:**
- Avoids Windows file lock issues
- Safe to pass objects between functions
- Connections auto-close on session exit

---

#### 5.5.2 Dedicated Connection Pattern (For Interactive Tools)

**For tools that need isolated connections:**

```r
ledgr_tool <- function(...) {
  # Create dedicated connection
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path)
  
  # Create environment-backed object
  e <- new.env(parent = emptyenv())
  e$.con <- con
  # ... other fields
  
  # Set up finalizer
  reg.finalizer(e, function(env) {
    if (!is.null(env$.con) && DBI::dbIsValid(env$.con)) {
      DBI::dbDisconnect(env$.con)
    }
  }, onexit = TRUE)
  
  class(e) <- "ledgr_tool"
  e
}

# Provide explicit close
close.ledgr_tool <- function(x, ...) {
  if (!is.null(x$.con) && DBI::dbIsValid(x$.con)) {
    DBI::dbDisconnect(x$.con)
    x$.con <- NULL
  }
  invisible(x)
}
```

---

#### 5.5.3 Connection Hygiene Test

**Functional test (more reliable than leak counting):**

```r
test_that("connections can be opened and closed repeatedly", {
  # Create temp database
  db_path <- tempfile(fileext = ".duckdb")
  
  # Open/close cycle (should not leak or lock)
  for (i in 1:10) {
    con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path)
    DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS test (x INT)")
    DBI::dbDisconnect(con)
  }
  
  # Should be able to delete (not locked on Windows)
  expect_true(file.exists(db_path))
  
  # Give OS time to release lock
  Sys.sleep(0.1)
  
  # Should not error (file not locked)
  expect_silent(unlink(db_path))
})
```

---

### 5.6 Error Handling Patterns

**Rule:** Fail fast with helpful, actionable error messages.

#### 5.6.1 Input Validation Errors

**Pattern:**

```r
validate_input <- function(snapshot, universe, ...) {
  # Check type
  if (!inherits(snapshot, "ledgr_snapshot")) {
    stop(
      "'snapshot' must be a ledgr_snapshot object\n",
      "Create with: ledgr_snapshot_from_yahoo() or ledgr_snapshot_from_df()"
    )
  }
  
  # Check non-empty
  if (length(universe) == 0) {
    stop("'universe' must contain at least one instrument")
  }
  
  # Check existence
  con <- get_connection(snapshot)
  available <- DBI::dbGetQuery(con, "
    SELECT DISTINCT instrument_id FROM snapshot_bars WHERE snapshot_id = ?
  ", params = list(snapshot$snapshot_id))$instrument_id
  
  missing <- setdiff(universe, available)
  if (length(missing) > 0) {
    stop(sprintf(
      "Instruments not found in snapshot: %s\nAvailable: %s",
      paste(missing, collapse = ", "),
      paste(available, collapse = ", ")
    ))
  }
}
```

---

#### 5.6.2 Strategy Execution Errors

**Pattern:**

```r
tryCatch({
  target_positions <- strategy(ctx)
}, error = function(e) {
  stop(sprintf(
    "Error in strategy execution at %s:\n  %s\n\nContext:\n  Run ID: %s\n  Pulse: %d of %d\n\nDebug with: ledgr_pulse_snapshot(snapshot, '%s')",
    ctx$ts_utc,
    e$message,
    run_id,
    pulse_num,
    total_pulses,
    ctx$ts_utc
  ))
})
```

---

#### 5.6.3 Graceful Package Dependency Errors

**Pattern:**

```r
check_package <- function(pkg_name, install_cmd) {
  if (!requireNamespace(pkg_name, quietly = TRUE)) {
    stop(sprintf(
      "%s package required\nInstall with: %s",
      pkg_name,
      install_cmd
    ))
  }
}

# Usage
ledgr_snapshot_from_yahoo <- function(...) {
  check_package("quantmod", "install.packages('quantmod')")
  # ...
}
```

---

### 5.7 Timestamp Normalization

**Rule:** Accept flexible input, normalize to ISO 8601 UTC internally.

#### 5.7.1 Normalization Function

**Accepted formats (strict):**
- ISO 8601: `"2020-01-01T00:00:00Z"` or `"2020-01-01T12:34:56Z"`
- Date-only: `"2020-01-01"` (interpreted as 00:00:00 UTC)
- R Date objects
- R POSIXct objects (converted to UTC)

**Rejected formats:**
- Locale-dependent strings (e.g., `"01/02/2020"`)
- Ambiguous formats

```r
# Internal helper (not exported)
iso_utc <- function(ts) {
  # POSIXct - convert to UTC
  if (inherits(ts, "POSIXct")) {
    # Force UTC interpretation (no lubridate dependency)
    if (attr(ts, "tzone") != "UTC") {
      ts <- as.POSIXct(format(ts, tz = "UTC"), tz = "UTC")
    }
    return(format(ts, "%Y-%m-%dT%H:%M:%SZ"))
  }
  
  # Date object
  if (inherits(ts, "Date")) {
    return(sprintf("%sT00:00:00Z", as.character(ts)))
  }
  
  # Character strings
  if (is.character(ts)) {
    # Already ISO format with Z
    if (grepl("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$", ts)) {
      return(ts)
    }
    
    # Date-only format YYYY-MM-DD
    if (grepl("^\\d{4}-\\d{2}-\\d{2}$", ts)) {
      return(sprintf("%sT00:00:00Z", ts))
    }
    
    # ISO without Z
    if (grepl("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}$", ts)) {
      return(paste0(ts, "Z"))
    }
    
    # Reject other formats
    stop(sprintf(
      "Unsupported timestamp format: %s\nAccepted formats:\n  - ISO 8601: '2020-01-01T00:00:00Z'\n  - Date-only: '2020-01-01'\n  - R Date/POSIXct objects",
      ts
    ))
  }
  
  stop(sprintf("Cannot normalize timestamp of type: %s", class(ts)[1]))
}
```

**Usage:**

```r
# In config builders (NOT in wrappers if builders already normalize)
ledgr_backtest_config <- function(start, end, initial_cash = 100000) {
  list(
    start = iso_utc(start),
    end = iso_utc(end),
    initial_cash = initial_cash
  )
}
```

---

## Section 6: Testing Requirements

### 6.1 Overview

Section 6 defines the testing requirements for v0.1.2 to ensure compliance with invariants and specification correctness.

**Testing philosophy:**
1. **Zero regressions** - All v0.1.1 tests must pass unchanged
2. **Wrapper correctness** - New APIs must be equivalent to canonical paths
3. **Isolation** - Interactive tools must not mutate state
4. **Integration** - Adapters must produce valid results

---

### 6.2 Test Categories

#### 6.2.1 Regression Tests (Priority: CRITICAL)

**Purpose:** Ensure v0.1.2 does not break v0.1.1 functionality.

**Requirement:** ALL v0.1.1 acceptance tests (AT1-AT12) MUST pass unchanged.

**Test suite:**

```r
# tests/testthat/test-regression.R

test_that("v0.1.1 acceptance tests pass", {
  # Run each acceptance test as a separate test
  # (Better granularity than source())
  
  # AT1: Snapshot creation
  source("tests/acceptance/test-AT1-snapshot-creation.R")
  
  # AT2-AT12: Similar pattern
  # ...
  
  # All should pass without modification
})
```

**Enforcement:** CI/CD pipeline MUST run v0.1.1 test suite on every commit as first step. Fail fast on regression.

---

#### 6.2.2 Equivalence Tests (Priority: CRITICAL)

**Purpose:** Verify high-level APIs produce identical results to low-level APIs.

**Invariant 3 enforcement:**

```r
# tests/testthat/test-equivalence.R

test_that("ledgr_backtest() equivalent to ledgr_run()", {
  # Setup
  snap <- ledgr_snapshot_from_df(test_bars)
  
  # Approach 1: Direct config
  config <- ledgr_config(
    snapshot = snap,
    universe = c("TEST_A", "TEST_B"),
    strategy = test_strategy,
    backtest = ledgr_backtest_config(
      start = "2020-01-01",
      end = "2020-12-31",
      initial_cash = 100000
    )
  )
  result_direct <- ledgr_run(config)
  
  # Approach 2: Wrapper
  result_wrapper <- ledgr_backtest(
    snapshot = snap,
    strategy = test_strategy,
    universe = c("TEST_A", "TEST_B"),
    start = "2020-01-01",
    end = "2020-12-31",
    initial_cash = 100000
  )
  
  # Compare ledger events (FULL comparison, not subset)
  con <- get_connection(snap)
  
  events1 <- DBI::dbGetQuery(con, "
    SELECT event_seq, ts_utc, event_type, instrument_id, side, qty, price, fee
    FROM ledger_events
    WHERE run_id = ?
    ORDER BY event_seq
  ", params = list(result_direct$run_id))
  
  events2 <- DBI::dbGetQuery(con, "
    SELECT event_seq, ts_utc, event_type, instrument_id, side, qty, price, fee
    FROM ledger_events
    WHERE run_id = ?
    ORDER BY event_seq
  ", params = list(result_wrapper$run_id))
  
  # Compare all semantic fields
  expect_equal(nrow(events1), nrow(events2))
  expect_identical(events1$event_seq, events2$event_seq)
  expect_identical(events1$ts_utc, events2$ts_utc)
  expect_identical(events1$event_type, events2$event_type)
  expect_identical(events1$instrument_id, events2$instrument_id)
  expect_identical(events1$side, events2$side)
  expect_equal(events1$qty, events2$qty, tolerance = 1e-10)
  expect_equal(events1$price, events2$price, tolerance = 1e-10)
  expect_equal(events1$fee, events2$fee, tolerance = 1e-10)
  
  # Compare final equity
  eq1 <- DBI::dbGetQuery(con, "
    SELECT equity FROM equity_curve WHERE run_id = ? ORDER BY pulse_seq DESC LIMIT 1
  ", params = list(result_direct$run_id))[[1]]
  
  eq2 <- DBI::dbGetQuery(con, "
    SELECT equity FROM equity_curve WHERE run_id = ? ORDER BY pulse_seq DESC LIMIT 1
  ", params = list(result_wrapper$run_id))[[1]]
  
  expect_equal(eq1, eq2, tolerance = 1e-10)
  
  # Cleanup
  ledgr_snapshot_close(snap)
})

test_that("snapshot adapters produce identical data hashes", {
  # Create bars data.frame
  bars <- test_bars_df
  
  # Approach 1: Direct from df with one snapshot_id
  snap1 <- ledgr_snapshot_from_df(
    bars,
    db_path = tempfile(fileext = ".duckdb"),
    snapshot_id = "snapshot_20250101_000000_aaaa"
  )
  
  # Approach 2: Same data with a different snapshot_id
  snap2 <- ledgr_snapshot_from_df(
    bars,
    db_path = tempfile(fileext = ".duckdb"),
    snapshot_id = "snapshot_20250101_000000_bbbb"
  )
  
  # Compare sealed snapshot hashes; IDs/metadata must not affect the artifact hash
  hash1 <- ledgr_snapshot_info(snap1)$snapshot_hash
  hash2 <- ledgr_snapshot_info(snap2)$snapshot_hash
  
  expect_equal(hash1, hash2)
  
  # Cleanup
  ledgr_snapshot_close(snap1)
  ledgr_snapshot_close(snap2)
})
```

---

#### 6.2.3 Isolation Tests (Priority: CRITICAL)

**Purpose:** Verify interactive tools do not mutate persistent state.

**Invariant 2 enforcement:**

```r
# tests/testthat/test-isolation.R

test_that("ledgr_indicator_dev() does not mutate database", {
  snap <- ledgr_snapshot_from_df(test_bars)
  
  # Capture persistent table state
  con <- ledgr_db_connect(snap$db_path)
  persistent_tables <- c("snapshots", "snapshot_bars", "snapshot_instruments")
  
  counts_before <- sapply(persistent_tables, function(tbl) {
    DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) FROM %s", tbl))[[1]]
  })
  
  DBI::dbDisconnect(con)
  
  # Create dev session
  dev <- ledgr_indicator_dev(snap, "TEST_A", "2020-06-15", lookback = 50)
  
  # Use all methods
  test(dev, function(w) mean(w$close))
  test_dates(dev, function(w) mean(w$close), dates = c("2020-01-15", "2020-03-15"))
  plot(dev)
  
  # Close
  close(dev)
  
  # Verify no mutations
  con <- ledgr_db_connect(snap$db_path)
  counts_after <- sapply(persistent_tables, function(tbl) {
    DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) FROM %s", tbl))[[1]]
  })
  
  DBI::dbDisconnect(con)
  ledgr_snapshot_close(snap)
  
  expect_identical(counts_before, counts_after)
})

test_that("ledgr_pulse_snapshot() does not mutate database", {
  snap <- ledgr_snapshot_from_df(test_bars)
  
  # Capture state
  con <- ledgr_db_connect(snap$db_path)
  persistent_tables <- c("snapshots", "snapshot_bars", "snapshot_instruments")
  
  counts_before <- sapply(persistent_tables, function(tbl) {
    DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) FROM %s", tbl))[[1]]
  })
  
  DBI::dbDisconnect(con)
  
  # Create pulse snapshot
  ctx <- ledgr_pulse_snapshot(
    snapshot = snap,
    universe = c("TEST_A", "TEST_B"),
    ts_utc = "2020-06-15",
    features = list(ledgr_ind_sma(50))
  )
  
  # Access fields
  _ <- ctx$bars
  _ <- ctx$features
  
  # Close
  close(ctx)
  
  # Verify no mutations
  con <- ledgr_db_connect(snap$db_path)
  counts_after <- sapply(persistent_tables, function(tbl) {
    DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) FROM %s", tbl))[[1]]
  })
  
  DBI::dbDisconnect(con)
  ledgr_snapshot_close(snap)
  
  expect_identical(counts_before, counts_after)
})
```

---

#### 6.2.4 Integration Tests (Priority: HIGH)

**Purpose:** Verify adapters work end-to-end.

**Use fixture data (not live):**

```r
# tests/testthat/test-integration.R

test_that("quantmod adapter works with fixture", {
  skip_if_not_installed("quantmod")
  
  # Use committed fixture data (already in R format for testing)
  fixture_data <- readRDS(system.file("testdata", "aapl_2020_jan.rds", package = "ledgr"))
  
  # Test data ingestion (quantmod pathway validated separately in interactive tests)
  snap <- ledgr_snapshot_from_df(fixture_data)
  
  # Should have created valid snapshot
  expect_s3_class(snap, "ledgr_snapshot")
  expect_true(file.exists(snap$db_path))
  
  # Should have data
  expect_true(snap$metadata$n_bars > 0)
  expect_equal(snap$metadata$n_instruments, 1L)
  
  # Can run backtest
  bt <- ledgr_backtest(
    snapshot = snap,
    strategy = function(ctx) c(AAPL = 100),
    universe = "AAPL"
  )
  
  expect_s3_class(bt, "ledgr_backtest")
  
  # Cleanup
  ledgr_snapshot_close(snap)
})

# Separate: live Yahoo test (interactive only, not in CI)
test_that("quantmod adapter works with live Yahoo", {
  skip_if_offline()
  skip_on_cran()
  skip_on_ci()
  
  # Real Yahoo fetch (can break due to API changes, adjustments, etc.)
  snap <- ledgr_snapshot_from_yahoo(
    symbols = "AAPL",
    from = "2020-01-01",
    to = "2020-01-31"
  )
  
  expect_s3_class(snap, "ledgr_snapshot")
  expect_true(snap$metadata$n_bars > 0)
  
  ledgr_snapshot_close(snap)
})

test_that("TTR adapter works", {
  skip_if_not_installed("TTR")
  
  snap <- ledgr_snapshot_from_df(test_bars)
  
  # Wrap TTR indicator
  rsi <- ledgr_adapter_r(TTR::RSI, "ttr_rsi", 14L, n = 14)
  
  # Should create valid indicator
  expect_s3_class(rsi, "ledgr_indicator")
  expect_equal(rsi$requires_bars, 14L)
  
  # Should work in backtest
  bt <- ledgr_backtest(
    snapshot = snap,
    strategy = function(ctx) c(TEST_A = 100),
    universe = "TEST_A",
    features = list(rsi)
  )
  
  expect_s3_class(bt, "ledgr_backtest")
  
  # Cleanup
  ledgr_snapshot_close(snap)
})
```

---

#### 6.2.5 Unit Tests (Priority: HIGH)

**Purpose:** Test individual functions in isolation.

```r
# tests/testthat/test-unit.R

test_that("iso_utc() normalizes timestamps correctly", {
  # Date object
  expect_equal(iso_utc(as.Date("2020-01-01")), "2020-01-01T00:00:00Z")
  
  # POSIXct
  ts <- as.POSIXct("2020-01-01 12:34:56", tz = "UTC")
  expect_equal(iso_utc(ts), "2020-01-01T12:34:56Z")
  
  # String formats
  expect_equal(iso_utc("2020-01-01"), "2020-01-01T00:00:00Z")
  expect_equal(iso_utc("2020-01-01T00:00:00Z"), "2020-01-01T00:00:00Z")
  expect_equal(iso_utc("2020-01-01T12:34:56"), "2020-01-01T12:34:56Z")
  
  # Reject unsupported formats
  expect_error(iso_utc("01/02/2020"), "Unsupported timestamp format")
})

test_that("ledgr_indicator validates inputs", {
  expect_error(
    ledgr_indicator(id = "", fn = mean, requires_bars = 10),
    "id"
  )
  
  expect_error(
    ledgr_indicator(id = "test", fn = "not_a_function", requires_bars = 10),
    "fn.*function"
  )
  
  expect_error(
    ledgr_indicator(id = "test", fn = mean, requires_bars = -1),
    "requires_bars"
  )
})

test_that("ledgr_extract_fills() handles empty ledger", {
  snap <- ledgr_snapshot_from_df(test_bars)
  
  # Create backtest with no trades
  bt <- ledgr_backtest(
    snapshot = snap,
    strategy = function(ctx) c(TEST_A = 0),  # Never trade
    universe = "TEST_A"
  )
  
  fills <- ledgr_extract_fills(bt)
  
  expect_s3_class(fills, "tbl_df")
  expect_equal(nrow(fills), 0)
  
  # Cleanup
  ledgr_snapshot_close(snap)
})

test_that("ledgr_compute_metrics() handles no trades gracefully", {
  snap <- ledgr_snapshot_from_df(test_bars)
  
  # Backtest with no trades
  bt <- ledgr_backtest(
    snapshot = snap,
    strategy = function(ctx) c(TEST_A = 0),
    universe = "TEST_A"
  )
  
  metrics <- ledgr_compute_metrics(bt)
  
  expect_equal(metrics$n_trades, 0)
  expect_true(is.na(metrics$win_rate))
  expect_true(is.na(metrics$avg_trade))
  
  # Cleanup
  ledgr_snapshot_close(snap)
})
```

---

#### 6.2.6 UX Tests (Priority: MEDIUM)

**Purpose:** Verify error messages and print output quality.

```r
# tests/testthat/test-ux.R

test_that("print methods produce clean output", {
  snap <- ledgr_snapshot_from_df(test_bars)
  
  output <- capture.output(print(snap))
  
  expect_true(any(grepl("ledgr_snapshot", output)))
  expect_true(any(grepl("Bars:", output)))
  expect_true(any(grepl("Instruments:", output)))
  
  ledgr_snapshot_close(snap)
})

test_that("error messages are helpful", {
  expect_error(
    ledgr_backtest(
      snapshot = "not_a_snapshot",
      strategy = function(ctx) c(),
      universe = "TEST"
    ),
    "ledgr_snapshot object.*Create with"
  )
  
  snap <- ledgr_snapshot_from_df(test_bars)
  
  expect_error(
    ledgr_backtest(
      snapshot = snap,
      strategy = function(ctx) c(),
      universe = character(0)
    ),
    "at least one instrument"
  )
  
  ledgr_snapshot_close(snap)
})
```

---

### 6.3 Coverage Requirements

**Minimum coverage targets:**

| Category | Coverage Target | Priority |
|----------|----------------|----------|
| High-level APIs | 100% | CRITICAL |
| Interactive tools | 100% | CRITICAL |
| Adapters | 90% | HIGH |
| Helper functions | 80% | MEDIUM |
| Print/summary methods | 70% | MEDIUM |

**Measurement:**

```r
# Use covr package
library(covr)

cov <- package_coverage()
print(cov)

# Fail CI if below threshold
total_cov <- percent_coverage(cov)
if (total_cov < 80) {
  stop(sprintf("Coverage %.1f%% below required 80%%", total_cov))
}
```

---

### 6.4 Test Execution Order

**CI/CD Pipeline:**

1. **Regression tests** (v0.1.1 acceptance) - MUST PASS FIRST
2. **Unit tests** - Fast feedback
3. **Equivalence tests** - Verify wrapper correctness
4. **Isolation tests** - Verify read-only guarantee
5. **Integration tests** - End-to-end workflows
6. **UX tests** - Error messages and output quality

**Fail fast:** Stop pipeline on first failure in critical tests (regression, equivalence, isolation).

---

### 6.5 Test Data

**Standard test fixtures (CORRECTED):**

```r
# tests/testthat/fixtures/test_bars.R

# Set seed FIRST (before any randomness)
set.seed(12345)

# Define date range
dates <- seq.Date(as.Date("2020-01-01"), as.Date("2020-12-31"), by = "day")
n_days <- length(dates)  # 366 (2020 is leap year)

# Define instruments
instruments <- c("TEST_A", "TEST_B")

# Create panel structure (cartesian product: 732 rows total)
test_bars <- expand.grid(
  date = dates,
  instrument_id = instruments,
  stringsAsFactors = FALSE
)

# Sort by instrument, then date
test_bars <- test_bars[order(test_bars$instrument_id, test_bars$date), ]

# Generate per-instrument random walks
test_bars$open <- NA
test_bars$high <- NA
test_bars$low <- NA
test_bars$close <- NA
test_bars$volume <- NA

for (inst in instruments) {
  idx <- test_bars$instrument_id == inst
  n <- sum(idx)
  
  # Random walk for prices
  returns <- rnorm(n, mean = 0.0005, sd = 0.02)
  prices <- 100 * cumprod(1 + returns)
  
  test_bars$open[idx] <- prices
  test_bars$close[idx] <- prices * (1 + rnorm(n, 0, 0.005))
  test_bars$high[idx] <- pmax(test_bars$open[idx], test_bars$close[idx]) * (1 + abs(rnorm(n, 0, 0.01)))
  test_bars$low[idx] <- pmin(test_bars$open[idx], test_bars$close[idx]) * (1 - abs(rnorm(n, 0, 0.01)))
  test_bars$volume[idx] <- round(rnorm(n, 1000000, 200000))
}

# Add ISO timestamps
test_bars$ts_utc <- sprintf("%sT00:00:00Z", test_bars$date)

# Final structure (732 rows: 366 days × 2 instruments)
test_bars <- test_bars[, c("ts_utc", "instrument_id", "open", "high", "low", "close", "volume")]

# Verify structure
stopifnot(nrow(test_bars) == 732)
stopifnot(length(unique(test_bars$instrument_id)) == 2)
stopifnot(all(table(test_bars$instrument_id) == 366))
```

**Example strategy:**

```r
# Simple buy-and-hold
test_strategy <- function(ctx) {
  c(TEST_A = 100, TEST_B = 50)
}
```

---

## Section 7: Deferred Features

### 7.1 Overview

Section 7 explicitly defines what is OUT OF SCOPE for v0.1.2 and when deferred features will be delivered.

**Purpose:** Prevent scope creep and set clear expectations.

---

### 7.2 Deferred to v0.1.3 (Documentation Release)

**Target:** Q1 2026

#### 7.2.1 Comprehensive Documentation

**What:**
- Full vignettes (5+):
  - "Getting Started with ledgr"
  - "Developing Custom Indicators"
  - "Using Technical Indicators (TTR Integration)"
  - "Interactive Strategy Development"
  - "ledgr and the R Ecosystem"
- pkgdown website with full API documentation
- Tutorial videos
- Migration guides (from Backtesting.py, quantstrat)

**Why deferred:**
- v0.1.2 UX must be complete before documenting it
- Writing vignettes for poor UX is counterproductive
- Documentation showcases the improved v0.1.2 experience

**What ships in v0.1.2:**
- README with quickstart example
- Function documentation (roxygen)
- Vignette outlines (structure only)

---

#### 7.2.2 PerformanceAnalytics Integration

**What:**
- `ledgr_metrics_pa()` function
- 100+ advanced metrics:
  - Sharpe Ratio, Sortino Ratio, Calmar Ratio
  - Information Ratio, Treynor Ratio
  - VaR, CVaR, Expected Shortfall
  - Omega Ratio, Kappa Ratios
  - Upside/Downside capture
- Integration with `chart.RiskReturnScatter()` and other PA visualizations

**Why deferred:**
- v0.1.2 has basic metrics (8) sufficient for initial release
- PA integration requires careful API design
- Documentation should show PA integration examples

**What ships in v0.1.2:**
- Basic metrics: total_return, annualized_return, volatility, max_drawdown, win_rate, avg_trade, n_trades, time_in_market
- Note in docs: "Advanced metrics via PerformanceAnalytics in v0.1.3"

---

#### 7.2.3 Advanced Visualizations

**What:**
- Trade distribution plots
- Returns histogram
- Rolling Sharpe ratio
- Interactive plots (plotly)
- Multi-backtest comparison plots

**Why deferred:**
- v0.1.2 has basic equity + drawdown plot
- Advanced viz requires more complex ggplot2/plotly code
- Should be documented with examples

**What ships in v0.1.2:**
- `plot.ledgr_backtest()` with equity curve + drawdown
- Note: Additional plot types coming in v0.1.3

---

#### 7.2.4 Signal Strategy Convenience Helper

**What:**
- `ledgr_signal_strategy(fn, long_qty = 1, flat_qty = 0)` or equivalent
- Allows explicit signal-style strategy authoring for simple tutorials
- Maps `"LONG"`/`"FLAT"` outputs to full named numeric target vectors

**Why deferred/optional:**
- The core v0.1.2 strategy contract is already simple: return named numeric
  targets
- Raw string signals are ambiguous without an explicit sizing policy
- Implementing this incorrectly would create a second strategy contract

**What ships in v0.1.2:**
- Raw `"LONG"`/`"FLAT"` returns are not valid `StrategyResult` values
- If time permits, ship only an explicit helper that maps signals before the
  shared StrategyResult validator runs

---

#### 7.2.5 xts Conversion Utilities

**What:**
- `as_xts.ledgr_backtest()` method
- Seamless integration with xts/zoo workflows
- PerformanceAnalytics compatibility

**Why deferred:**
- Low priority for initial release
- Requires testing against PA expectations

**What ships in v0.1.2:**
- tibble outputs only
- Note: xts conversion in v0.1.3

---

### 7.3 Deferred to v0.2.0 (Paper Trading)

**Target:** Q2 2026

#### 7.3.1 Live Data Adapters

**What:**
- `ledgr_data_yahoo_live()` - Real-time Yahoo Finance
- `ledgr_data_ib_live()` - Interactive Brokers feed
- `ledgr_data_alpaca_live()` - Alpaca Markets feed
- Streaming data ingestion

**Why deferred:**
- v0.1.2 is backtest-only
- Live data requires different architecture (streaming)
- Paper trading prerequisite

**What ships in v0.1.2:**
- Historical snapshot adapters only
- Architecture supports future live adapters

---

#### 7.3.2 Paper Trading Mode

**What:**
- `ledgr_run_live()` function
- Mode: `"paper"` (live data + simulated fills)
- Real-time strategy execution
- Position reconciliation
- Monitoring dashboard

**Why deferred:**
- v0.1.2 focuses on backtest UX
- Paper trading requires live data adapters
- Needs production-hardening

**What ships in v0.1.2:**
- Backtest mode only
- Architecture designed for future paper/live modes

---

#### 7.3.3 Walk-Forward Optimization

**What:**
- `ledgr_walk_forward()` function
- Train/test period management
- Out-of-sample validation
- Result aggregation across folds

**Why deferred:**
- Complex feature requiring solid backtest foundation
- Users can implement manually in v0.1.2
- Needs careful API design

**What ships in v0.1.2:**
- Manual walk-forward possible via loops
- Vision documented in spec

---

#### 7.3.4 Benchmark Comparison

**What:**
- `ledgr_compare()` function
- Alpha, Beta, Information Ratio computation
- Relative performance metrics
- Benchmark visualization

**Why deferred:**
- Requires multiple backtest comparison infrastructure
- PerformanceAnalytics dependency

**What ships in v0.1.2:**
- Single backtest metrics only

---

#### 7.3.5 Round-Trip Trade Aggregation

**What:**
- `ledgr_aggregate_trades_roundtrip()` function
- Entry-to-exit trade grouping
- Hold time analysis
- Win/loss streaks

**Why deferred:**
- Complex aggregation logic
- v0.1.2 has FIFO fill extraction (sufficient)
- Needs user feedback on desired semantics

**What ships in v0.1.2:**
- `ledgr_extract_fills()` with realized P&L

---

### 7.4 Deferred to v0.3.0 (Production Trading)

**Target:** Q3 2026

#### 7.4.1 Broker Adapters

**What:**
- `ledgr_broker_ib()` - Interactive Brokers
- `ledgr_broker_alpaca()` - Alpaca Markets
- `ledgr_broker_tdameritrade()` - TD Ameritrade
- Order submission, cancellation, amendment
- Fill confirmations
- Position queries

**Why deferred:**
- Requires paper trading validation first
- High-risk (real money)
- Regulatory considerations

**What ships in v0.1.2:**
- Simulated broker only

---

#### 7.4.2 Risk Management Layer

**What:**
- Position size limits
- Maximum drawdown circuit breakers
- Daily loss limits
- Concentration limits
- Kill switches

**Why deferred:**
- Production-critical feature
- Needs extensive testing
- Regulatory requirements

**What ships in v0.1.2:**
- No risk management (backtest only)

---

#### 7.4.3 Order Management

**What:**
- Partial fill handling
- Order rejections
- Amendment workflows
- Order lifecycle tracking

**Why deferred:**
- Complex state management
- Production-critical
- Broker-specific nuances

**What ships in v0.1.2:**
- Instant fills only (backtest)

---

#### 7.4.4 Monitoring & Alerting

**What:**
- Slack/email notifications
- Performance dashboards
- Error alerting
- Position monitoring

**Why deferred:**
- Production infrastructure
- Not needed for backtesting

**What ships in v0.1.2:**
- Console output only

---

#### 7.4.5 Production Hardening

**What:**
- Circuit breakers
- Automatic retries
- Failover mechanisms
- Logging infrastructure
- Audit trail enhancements

**Why deferred:**
- Production deployment requirement
- Extensive testing needed

**What ships in v0.1.2:**
- Event sourcing foundation ready

---

### 7.5 Out of Scope (Not Planned)

#### 7.5.1 Parameter Optimization Algorithms

**What users might expect:**
- Genetic algorithms
- Grid search
- Bayesian optimization
- Built-in optimizers

**Why out of scope:**
- Users bring their own optimizers
- ledgr provides fast backtest primitive
- Optimization is user's domain
- Many excellent R packages exist (GA, rgenoud, etc.)

**What ledgr provides:**
- Fast backtesting for optimization loops
- Helper: `ledgr_generate_folds()` for walk-forward (v0.2.0)
- Users control optimization strategy

---

#### 7.5.2 Python Indicator Bridges

**What users might expect:**
- Direct ta-lib integration
- Python function execution from R

**Why out of scope:**
- R has equivalent indicators (TTR)
- reticulate adds complexity
- Missing indicators can be ported to R (usually <30 min)
- Community can build extension packages

**What ledgr provides:**
- Indicator adapter pattern
- Easy to port Python indicators to R
- Documentation on equivalence

---

#### 7.5.3 TradingView Integration

**What users might expect:**
- Pine Script execution
- Direct TradingView API

**Why out of scope:**
- No official TradingView API for executing Pine strategies server-side
- Pine Script is client-side language only
- Web scraping violates TOS

**What ledgr provides:**
- CSV adapter for manual TradingView exports
- Conversion guide (Pine Script → R)
- Function equivalence table

---

#### 7.5.4 Machine Learning Model Integration

**What users might expect:**
- Built-in ML models
- Auto-fitting models
- Model selection

**Why out of scope:**
- Users bring their own models
- R has excellent ML packages (caret, tidymodels, etc.)
- Models are just indicators (via adapter)

**What ledgr provides:**
- Indicators can wrap ML predictions
- CSV adapter for pre-computed predictions
- Integration via standard interfaces

---

#### 7.5.5 High-Frequency Trading Support

**What users might expect:**
- Tick-level data
- Microsecond timestamps
- Order book simulation

**Why out of scope:**
- ledgr targets daily/intraday strategies
- HFT requires specialized infrastructure
- DuckDB is OLAP-optimized, not tick-level

**What ledgr provides:**
- Minute-level data support
- Extension point for custom data adapters

---

### 7.6 Deferral Rationale Summary

| Feature | Version | Rationale |
|---------|---------|-----------|
| **Comprehensive docs** | v0.1.3 | Need good UX to document |
| **PerformanceAnalytics** | v0.1.3 | Advanced metrics, needs careful integration |
| **Advanced viz** | v0.1.3 | Basic plot sufficient for v0.1.2 |
| **Live data adapters** | v0.2.0 | Paper trading prerequisite |
| **Paper trading** | v0.2.0 | Requires live data + validation |
| **Walk-forward** | v0.2.0 | Complex, users can do manually in v0.1.2 |
| **Broker adapters** | v0.3.0 | Requires paper trading validation |
| **Risk management** | v0.3.0 | Production-critical, extensive testing |
| **Production hardening** | v0.3.0 | Production deployment requirement |
| **Optimization algos** | Never | User's responsibility |
| **Python bridges** | Never | R has equivalents |
| **TradingView API** | Never | Doesn't exist for server-side execution |
| **ML integration** | Never | Users bring models |
| **HFT support** | Never | Wrong use case |

---

## End of Sections 5-7 (CORRECTED)

**Summary:**

- **Section 5:** Implementation constraints (how to write compliant code)
- **Section 6:** Testing requirements (what must be tested and how)
- **Section 7:** Deferred features (clear scope boundaries)

**Complete v0.1.2 Specification:**
- Section 1: UX Principles & Invariants ✅
- Section 2: High-Level API Contract ✅
- Section 3: Indicator Infrastructure ✅
- Section 4: Metrics & Visualization ✅
- Section 5: Implementation Constraints ✅ (CORRECTED)
- Section 6: Testing Requirements ✅ (CORRECTED)
- Section 7: Deferred Features ✅

---

## Changelog (v2.2.2 from v2.1.0)

### Critical Fixes

**Section 5:**
1. **5.2.1** - Added normalization constraint (single canonical place, no double normalization)
2. **5.2.1** - Fixed equivalence test to compare observable outputs, not configs
3. **5.2.2** - Fixed quantmod column extraction (by name, not position)
4. **5.3.1** - Removed `Sys.time()` from params (violates determinism)
5. **5.3.1** - Clarified params must be deterministic for fingerprinting
6. **5.3.2** - Fixed side-effects test (use `expect_silent()`, not `capture_messages()`)
7. **5.4.1** - Fixed finalizer pattern (environment-backed, not list-based)
8. **5.4.2** - Removed fragile TEMP cleanup test
9. **5.5.3** - Replaced connection leak test with functional hygiene test
10. **5.7.1** - Fixed timestamp parsing (strict formats, no locale dependence, no lubridate)

**Section 6:**
11. **6.2.2** - Strengthened equivalence tests (compare all fields including ts_utc, fee)
12. **6.2.4** - Fixed integration test (use fixture CSV, mark live test as interactive-only)
13. **6.5** - Fixed test fixture (set.seed() BEFORE randomness, correct panel structure: 732 rows)

### v2.2.1 Code Review Amendments

14. **5.2.1** - Added `snapshot_db_path` to wrapper/config examples so split snapshot DB/run DB semantics are explicit
15. **6.2.2** - Updated snapshot adapter equivalence test to compare `snapshot_hash` across different snapshot IDs

### v2.2.2 UX Amendments

16. **5.2.1** - Added data source resolution phase for `ledgr_backtest()` so data-frame UX still routes through snapshot creation and canonical config
17. **7.2.4** - Added deferred/optional signal strategy helper scope and kept raw signal returns out of the core StrategyResult contract

### Approved

This corrected specification addresses all critical correctness issues and is implemented for the v0.1.2 release.

**Status:** APPROVED FOR RELEASE
