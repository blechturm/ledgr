# ledgr v0.1.2 Implementation Tickets

**Version:** 1.0.0  
**Date:** December 20, 2025  
**Total Tickets:** 43  
**Estimated Duration:** 8 weeks  

---

## Ticket Organization

Tickets are organized by week according to the v0.1.2 roadmap:
- **Week 1:** High-Level API & Snapshot/Runner Correctness (12 tickets)
- **Week 2:** Indicator Infrastructure (12 tickets)
- **Week 3:** Trade Aggregation, Reconstruction & Basic Metrics (8 tickets)
- **Week 4:** Visualization (2 tickets)
- **Week 5:** Documentation Foundation, API Surface & Polish (9 tickets)

### Code Review Correctness Gates

The following tickets were added after the code review of branch `V0.1.2`.
They are placed as gates in the DAG so later UX, metrics, documentation, and
release tickets cannot complete on top of known correctness gaps:

- `LDG-105` and `LDG-109` sit between snapshot adapters and the high-level
  backtest wrapper. Snapshot hashes and sealed snapshot validity are part of the
  data contract, so `LDG-107` must not be accepted until these are fixed.
- `LDG-110`, `LDG-111`, and `LDG-112` sit immediately after `LDG-107` and block
  trade aggregation, regression, and final integration. They harden run storage,
  strategy result validation, and resume safety before downstream metrics read
  ledger state.
- `LDG-211` sits after the indicator registry/adapters and before adapter
  integration tests. It prevents mutable in-memory registries from undermining
  replay determinism.
- `LDG-212` sits after interactive indicator/pulse tools and before final
  integration/docs. It keeps interactive development contexts compatible with
  default runtime contexts.
- `LDG-308` sits in Week 3 before final integration because snapshot-backed
  runs must be reconstructable through the public API.
- `LDG-500` is the Week 5 release gate. It locks the exported v0.1.2 API and
  package-check hygiene before documentation, coverage, and CI verification.

**Priority Levels:**
- 🔴 **P0 (Blocker):** Must complete before dependent work
- 🟠 **P1 (Critical):** Core functionality
- 🟡 **P2 (Important):** Quality of life
- 🟢 **P3 (Nice to have):** Polish

---

## Week 1: High-Level API & Snapshot/Runner Correctness

### LDG-101: Set Up Test Infrastructure
**Priority:** 🔴 P0  
**Effort:** 2 days  
**Dependencies:** None  

**Description:**
Set up testing infrastructure and fixtures required for all subsequent work.

**Tasks:**
1. Create `tests/testthat/fixtures/` directory structure
2. Implement corrected `test_bars` fixture (732 rows, proper seeding)
3. Implement `test_strategy` helper function
4. Create test helper functions:
   - `get_test_connection()`
   - `get_ledger_events(run_id)`
   - `get_final_equity(run_id)`
5. Set up covr for coverage tracking
6. Configure CI/CD to run v0.1.1 regression tests first

**Acceptance Criteria:**
- [ ] `test_bars` fixture matches spec (732 rows: 366 days × 2 instruments)
- [ ] Seed set correctly (before randomness)
- [ ] Test helpers documented
- [ ] Coverage reporting works locally
- [ ] CI runs regression tests before new tests

**Test Requirements:**
- Unit test for fixture structure validation
- Verify seed determinism (run twice, same output)

**Spec Reference:** Section 6.5

---

### LDG-102: Implement Timestamp Normalization Helper
**Priority:** 🔴 P0  
**Effort:** 1 day  
**Dependencies:** LDG-101  

**Description:**
Implement `iso_utc()` helper function for canonical timestamp normalization.

**Tasks:**
1. Create `R/timestamp.R`
2. Implement `iso_utc()` with strict format validation
3. Support: POSIXct, Date, ISO strings, YYYY-MM-DD
4. Reject: locale-dependent formats, ambiguous strings
5. No lubridate dependency
6. Document accepted formats

**Acceptance Criteria:**
- [ ] Accepts all required formats (POSIXct, Date, ISO strings)
- [ ] Rejects unsupported formats with helpful errors
- [ ] Always returns ISO 8601 UTC format
- [ ] No external dependencies beyond base R
- [ ] 100% test coverage

**Test Requirements:**
- Unit tests for all accepted formats
- Unit tests for rejected formats
- Edge cases: leap seconds, timezone conversions

**Spec Reference:** Section 5.7.1

---

### LDG-103: Implement `ledgr_snapshot` S3 Class (Lazy Connection)
**Priority:** 🔴 P0  
**Effort:** 2 days  
**Dependencies:** LDG-102  

**Description:**
Implement lazy connection pattern for `ledgr_snapshot` objects.

**Tasks:**
1. Create `R/snapshot.R`
2. Define `ledgr_snapshot` structure (stores `db_path`, not connection)
3. Implement `get_connection()` internal helper
4. Implement `ledgr_snapshot_close()`
5. Implement `close.ledgr_snapshot()`
6. Implement `print.ledgr_snapshot()` with connection status
7. Implement `summary.ledgr_snapshot()`

**Acceptance Criteria:**
- [ ] Objects store `db_path` + `snapshot_id`, not open connection
- [ ] `get_connection()` opens on-demand
- [ ] `close()` method works
- [ ] Print shows connection status (open/closed)
- [ ] No Windows file lock issues in tests
- [ ] 100% test coverage

**Test Requirements:**
- Unit tests for lazy connection behavior
- Test close/reopen cycle
- Functional hygiene test (10 open/close cycles, no lock)
- Windows CI verification

**Spec Reference:** Section 2.2.5

---

### LDG-104: Implement `ledgr_snapshot_from_df()`
**Priority:** 🔴 P0  
**Effort:** 2 days  
**Dependencies:** LDG-103  

**Description:**
Implement data.frame → snapshot adapter.

**Tasks:**
1. Create `R/snapshot_adapters.R`
2. Implement input validation (schema, types, no duplicates)
3. Normalize timestamps via `iso_utc()`
4. Delegate to v0.1.1 `ledgr_snapshot_create()`
5. Use canonical snapshot ID generation (no digest-based)
6. Handle instrument auto-generation
7. Error messages match spec examples

**Acceptance Criteria:**
- [ ] Accepts valid data.frames with required columns
- [ ] Validates schema before processing
- [ ] Timestamps normalized to ISO 8601 UTC
- [ ] Delegates to v0.1.1 for ID generation and sealing
- [ ] Helpful error messages for common mistakes
- [ ] 100% test coverage

**Test Requirements:**
- Unit tests with valid inputs
- Unit tests for each validation error
- Integration test: df → snapshot → backtest

**Spec Reference:** Section 2.2.2

---

### LDG-105: Fix Snapshot Hash Determinism
**Priority:** 🔴 P0  
**Effort:** 1.5 days  
**Dependencies:** LDG-104  

**Description:**
Make `snapshot_hash` deterministic over the imported data artifact, as required
by the v0.1.1 snapshot contract. Identical normalized `snapshot_bars` and
`snapshot_instruments` must produce the same hash even when snapshot IDs,
creation timestamps, or non-data metadata differ.

**Tasks:**
1. Remove `snapshots.snapshot_id` and `snapshots.meta_json` from the hash input
2. Hash only canonical `snapshot_instruments` and `snapshot_bars` rows
3. Ensure adapter metadata such as `created_at` cannot affect `snapshot_hash`
4. Update tests that currently expect hashes to include snapshot ID/metadata
5. Add regression tests for identical imported data across different snapshot IDs
6. Add tamper tests proving data-row changes still change the hash

**Acceptance Criteria:**
- [x] Identical normalized bars/instruments produce identical hashes across runs
- [x] Different snapshot IDs do not change `snapshot_hash`
- [x] Snapshot metadata changes do not change `snapshot_hash`
- [x] Bars/instruments mutations still fail tamper verification
- [x] Existing v0.1.1 snapshot regression tests are updated without weakening tamper detection

**Test Requirements:**
- Unit test: same data, different snapshot IDs -> equal hash
- Unit test: same data, different metadata -> equal hash
- Unit test: instrument mutation -> different hash
- Unit test: bar mutation -> different hash

**Spec Reference:** v0.1.1 Sections R2, 3.4, 4.1

---

### LDG-109: Enforce Seal-Time Snapshot Validation
**Priority:** 🔴 P0  
**Effort:** 1.5 days  
**Dependencies:** LDG-104  

**Description:**
Make `ledgr_snapshot_seal()` the final integrity gate for snapshots. A snapshot
must not be sealable if bars reference missing instruments or OHLC data violates
the canonical high/low bounds, even if data was inserted directly or imported
with validation disabled.

**Tasks:**
1. Add referential integrity validation inside `ledgr_snapshot_seal()`
2. Add OHLC validation inside `ledgr_snapshot_seal()`
3. Keep seal transition and hash write atomic in one DuckDB transaction
4. Ensure failed seals leave snapshots unsealed and do not write `snapshot_hash`
5. Use fail-loud error classes for invalid references and invalid OHLC rows
6. Add direct-table-write tests that bypass import helpers

**Acceptance Criteria:**
- [x] Bars with unknown `instrument_id` cannot be sealed
- [x] Invalid OHLC rows cannot be sealed
- [x] Failed seal does not write `snapshot_hash`
- [x] Failed seal does not transition to `SEALED`
- [x] Valid snapshots still seal atomically

**Test Requirements:**
- Unit test: direct write with missing instrument fails seal
- Unit test: direct write with `high < max(open, close, low)` fails seal
- Unit test: direct write with `low > min(open, close, high)` fails seal
- Unit test: valid snapshot seal still writes hash and status atomically

**Spec Reference:** v0.1.1 Sections R4, 4.1, I11

---

### LDG-106: Implement `ledgr_snapshot_from_yahoo()`
**Priority:** 🟠 P1  
**Effort:** 1.5 days  
**Dependencies:** LDG-104  

**Description:**
Implement quantmod → snapshot adapter.

**Tasks:**
1. Add to `R/snapshot_adapters.R`
2. Check quantmod availability with helpful error
3. Fetch via `quantmod::getSymbols()`
4. Extract columns BY NAME (not position): `.Open`, `.High`, etc.
5. Normalize timestamps
6. Delegate to `ledgr_snapshot_from_df()`

**Acceptance Criteria:**
- [ ] Graceful error if quantmod missing
- [ ] Column extraction by name suffix (robust to reordering)
- [ ] Timestamps normalized
- [ ] Multi-symbol support
- [ ] Error handling for failed fetches
- [ ] 100% test coverage (fixture-based)

**Test Requirements:**
- CI test uses fixture CSV (not live Yahoo)
- Interactive test marked `skip_on_ci()` for live Yahoo
- Unit test for column name extraction
- Integration test with fixture

**Spec Reference:** Section 2.2.3, 5.2.2

---

### LDG-107: Implement `ledgr_backtest()` Wrapper
**Priority:** 🔴 P0  
**Effort:** 2 days  
**Dependencies:** LDG-104, LDG-105, LDG-109  

**Description:**
Implement high-level backtest wrapper (thin wrapper over `ledgr_run()`).

**Tasks:**
1. Create `R/backtest.R`
2. Implement input validation (snapshot type, universe non-empty)
3. Build canonical config via `ledgr_config()`
4. Call `ledgr_run(config)` (NO execution logic)
5. Wrap result in `ledgr_backtest` S3 class
6. NO timestamp normalization (done in config builders)

**Acceptance Criteria:**
- [ ] Accepts only `ledgr_snapshot` objects
- [ ] Validates inputs with helpful errors
- [ ] Calls `ledgr_run()` with canonical config
- [ ] Returns S3-wrapped result
- [ ] NO execution logic (pure wrapper)
- [ ] 100% test coverage

**Test Requirements:**
- **CRITICAL:** Equivalence test vs direct `ledgr_run()`
- Input validation tests for each error case
- UX test for error messages

**Spec Reference:** Section 2.3.1, 5.2.1

---

### LDG-108: Implement `ledgr_backtest` S3 Methods
**Priority:** 🟠 P1  
**Effort:** 1.5 days  
**Dependencies:** LDG-107  

**Description:**
Implement S3 methods for `ledgr_backtest` objects.

**Tasks:**
1. Add to `R/backtest.R`
2. Implement `print.ledgr_backtest()` (concise console output)
3. Implement `summary.ledgr_backtest()` (metrics display)
4. Implement `as_tibble.ledgr_backtest()` (equity/fills/ledger)
5. NO caching in object (compute fresh each time)
6. Use lazy connection pattern

**Acceptance Criteria:**
- [ ] `print()` shows run summary
- [ ] `summary()` computes and displays metrics
- [ ] `as_tibble()` extracts equity/fills/ledger
- [ ] Methods don't mutate object
- [ ] Output matches spec examples
- [ ] 100% test coverage

**Test Requirements:**
- UX tests for print output quality
- Unit tests for as_tibble variants
- Verify no object mutation

**Spec Reference:** Section 2.4.2, 2.4.3, 2.4.4

---

### LDG-110: Define and Implement Split Snapshot/Run Database Semantics
**Priority:** 🟠 P1  
**Effort:** 2 days  
**Dependencies:** LDG-107  

**Description:**
Resolve the documented `db_path` contract for `ledgr_backtest()`. If `db_path`
is documented as the run-ledger database while the snapshot object carries its
own `snapshot$db_path`, the runner must either support split databases or reject
them explicitly. For v0.1.2, implement the documented split-DB behavior.

**Tasks:**
1. Preserve both `snapshot$db_path` and run-ledger `db_path` in canonical config
2. Open the snapshot DB for read/validation and the run DB for run artifacts
3. Verify sealed snapshot hash against the snapshot DB before running
4. Materialize the runner's `bars` view from the snapshot source without assuming snapshot tables exist in the run DB
5. Store enough provenance in `runs.config_json` to reopen both databases
6. Add a fail-loud error if the snapshot DB is unavailable during run/reconstruction

**Acceptance Criteria:**
- [x] `ledgr_backtest(snapshot = snap, db_path = different_file)` runs successfully
- [x] Run artifacts are written to the run DB, not the snapshot DB
- [x] Snapshot hash verification still reads the original snapshot DB
- [x] Config stores both paths deterministically
- [x] Same-DB behavior remains backward compatible

**Test Requirements:**
- Integration test with separate snapshot DB and run DB
- Regression test for existing same-DB workflows
- Tamper test where the snapshot DB changes after run config creation

**Spec Reference:** Section 2.3.1, 2.5.1

---

### LDG-111: Validate Functional Strategy Results
**Priority:** 🔴 P0  
**Effort:** 1 day  
**Dependencies:** LDG-107  

**Description:**
Apply the same `StrategyResult` validation rules to functional strategies that
already apply to R6 strategy objects. Functional strategy results must not
silently omit instruments, include unknown instruments, duplicate targets, or
return non-finite quantities.

**Tasks:**
1. Extract shared target validation from the R6 strategy contract
2. Apply validation to functional strategy results inside the runner
3. Require targets for every instrument in `ctx$universe`
4. Reject targets outside the universe
5. Reject unnamed, duplicated, missing, or non-finite targets
6. Keep named numeric vector shorthand, but normalize through the shared validator

**Acceptance Criteria:**
- [x] Missing universe targets fail with `ledgr_invalid_strategy_result`
- [x] Extra targets fail with `ledgr_invalid_strategy_result`
- [x] Non-finite target quantities fail
- [x] Valid functional strategies still work
- [x] R6 and functional strategy validation behavior is identical

**Test Requirements:**
- Unit test: functional strategy missing one instrument fails
- Unit test: functional strategy returns extra instrument fails
- Unit test: NA/Inf target fails
- Regression test: valid named numeric vector still passes

**Spec Reference:** Section 2.3.2, 5.3.2

---

### LDG-112: Make `db_live` Resume Pulse-Atomic
**Priority:** 🟠 P1  
**Effort:** 1.5 days  
**Dependencies:** LDG-107  

**Description:**
Fix resume semantics for `db_live` so a pulse is considered complete only after
strategy state, fills, features, and equity output for that pulse are all
durably written. A crash after `strategy_state` insertion must not cause resume
to skip unfinished fills.

**Tasks:**
1. Define a pulse completion marker or derive completion from all required artifacts
2. Move `strategy_state` write after fill persistence, or wrap the whole pulse in a transaction
3. Update resume anchor to the last fully completed pulse
4. Delete partial tail data from the first incomplete pulse
5. Add crash-injection tests around state write/fill write boundaries

**Acceptance Criteria:**
- [x] Crash after strategy-state write but before fills does not skip the pulse
- [x] Resume replays the incomplete pulse deterministically
- [x] Completed pulses are not replayed unnecessarily
- [x] `audit_log` resume behavior remains unchanged

**Test Requirements:**
- Simulated crash after `strategy_state` write in `db_live`
- Simulated crash after partial fill persistence in `db_live`
- Regression test for clean `db_live` resume

**Spec Reference:** Section 5.4.2, v0.1.0 restart safety requirements

---

## Week 2: Indicator Infrastructure

### LDG-201: Implement `ledgr_indicator()` Constructor
**Priority:** 🔴 P0  
**Effort:** 1.5 days  
**Dependencies:** LDG-101  

**Description:**
Implement indicator constructor with purity validation.

**Tasks:**
1. Create `R/indicator.R`
2. Define `ledgr_indicator` structure
3. Validate inputs (id non-empty, fn is function, requires_bars > 0)
4. Validate params are deterministic (no `Sys.time()`)
5. Store id, fn, requires_bars, params
6. Document purity requirements in roxygen

**Acceptance Criteria:**
- [ ] Validates all inputs
- [ ] Returns `ledgr_indicator` object
- [ ] params checked for determinism
- [ ] Clear error messages
- [ ] 100% test coverage

**Test Requirements:**
- Unit tests for valid construction
- Unit tests for each validation error
- Test forbidden params (Sys.time, etc.)

**Spec Reference:** Section 3.2.1, 5.3.1

---

### LDG-202: Implement Indicator Registry
**Priority:** 🟠 P1  
**Effort:** 1 day  
**Dependencies:** LDG-201  

**Description:**
Implement global indicator registry.

**Tasks:**
1. Add to `R/indicator.R`
2. Create internal registry environment
3. Implement `ledgr_register_indicator(indicator, name)`
4. Implement `ledgr_get_indicator(name)`
5. Implement `ledgr_list_indicators(pattern)`
6. Error handling for missing indicators

**Acceptance Criteria:**
- [ ] Registry persists across function calls
- [ ] `get_indicator()` retrieves registered indicators
- [ ] `list_indicators()` supports regex filtering
- [ ] Helpful error for missing indicators
- [ ] 100% test coverage

**Test Requirements:**
- Unit tests for register/get/list
- Test error messages
- Test pattern filtering

**Spec Reference:** Section 3.3

---

### LDG-203: Implement Built-In Indicators
**Priority:** 🟠 P1  
**Effort:** 2 days  
**Dependencies:** LDG-201  

**Description:**
Implement 4 built-in indicators: SMA, EMA, RSI, Returns.

**Tasks:**
1. Create `R/indicators_builtin.R`
2. Implement `ledgr_ind_sma(n)`
3. Implement `ledgr_ind_ema(n)`
4. Implement `ledgr_ind_rsi(n)`
5. Implement `ledgr_ind_returns(n)`
6. Register in `.onLoad()`

**Acceptance Criteria:**
- [ ] All 4 indicators implemented
- [ ] Pure functions (no side effects)
- [ ] Deterministic (same input → same output)
- [ ] Auto-registered on package load
- [ ] 100% test coverage

**Test Requirements:**
- Determinism tests for each indicator
- Side-effects tests (expect_silent)
- Static check for `<<-` assignment
- Accuracy tests against known values

**Spec Reference:** Section 3.5

---

### LDG-204: Implement `ledgr_adapter_r()`
**Priority:** 🟠 P1  
**Effort:** 1.5 days  
**Dependencies:** LDG-201  

**Description:**
Implement R package function wrapper adapter (for TTR).

**Tasks:**
1. Create `R/indicator_adapters.R`
2. Implement `ledgr_adapter_r(pkg_fn, id, requires_bars, ...)`
3. Capture additional arguments
4. Create wrapper that calls package function
5. Return last value (most recent)
6. Graceful error if package missing

**Acceptance Criteria:**
- [ ] Wraps arbitrary R functions
- [ ] Passes additional arguments correctly
- [ ] Returns last value
- [ ] Helpful error if package missing
- [ ] 100% test coverage

**Test Requirements:**
- Unit test with `mean()` (base R, always available)
- Integration test with TTR (skip if not installed)
- Test argument passing

**Spec Reference:** Section 3.6.1

---

### LDG-205: Implement `ledgr_adapter_csv()`
**Priority:** 🟠 P1  
**Effort:** 1.5 days  
**Dependencies:** LDG-201  

**Description:**
Implement CSV pre-computed indicator adapter.

**Tasks:**
1. Add to `R/indicator_adapters.R`
2. Load CSV at construction time (closure)
3. Validate required columns: ts_utc, instrument_id, value_col
4. Lookup by BOTH timestamp AND instrument
5. Return NA with warning if not found
6. Deterministic provenance in params (data hash)

**Acceptance Criteria:**
- [ ] Loads CSV once at construction
- [ ] Validates required columns
- [ ] Lookup by ts_utc AND instrument_id
- [ ] Multi-instrument support
- [ ] Deterministic params
- [ ] 100% test coverage

**Test Requirements:**
- Unit test with fixture CSV
- Test multi-instrument lookup
- Test missing value handling
- Verify closure immutability

**Spec Reference:** Section 3.6.2, 5.3.1

---

### LDG-206: Implement `ledgr_indicator_dev()` (Environment-Backed)
**Priority:** 🟡 P2  
**Effort:** 2 days  
**Dependencies:** LDG-201  

**Description:**
Implement interactive indicator development tool (read-only).

**Tasks:**
1. Create `R/interactive_tools.R`
2. Create environment-backed object
3. Open dedicated connection
4. Query snapshot_bars (read-only)
5. Set up finalizer for cleanup
6. Implement `test()` method
7. Implement `test_dates()` method
8. Implement `plot()` method
9. Implement `close()` method
10. Implement `print()` method

**Acceptance Criteria:**
- [ ] Environment-backed object (not list)
- [ ] Finalizer cleans up connection
- [ ] All methods read-only
- [ ] Helper methods work (test, test_dates, plot)
- [ ] Explicit close() method
- [ ] 100% test coverage

**Test Requirements:**
- **CRITICAL:** Isolation test (no persistent table mutations)
- Test helper methods
- Verify connection cleanup
- Test finalizer behavior

**Spec Reference:** Section 3.4.2, 5.4.1

---

### LDG-207: Implement `ledgr_pulse_snapshot()`
**Priority:** 🟡 P2  
**Effort:** 2 days  
**Dependencies:** LDG-203  

**Description:**
Implement pulse context snapshot tool (read-only).

**Tasks:**
1. Add to `R/interactive_tools.R`
2. Create environment-backed object
3. Query bars for universe at ts_utc
4. Compute features in-memory (don't write to DB)
5. Set up finalizer for cleanup
6. Implement `close()` method
7. Implement `print()` method

**Acceptance Criteria:**
- [ ] Environment-backed object
- [ ] Queries database (read-only)
- [ ] Computes features in-memory
- [ ] No database writes
- [ ] Finalizer cleans up
- [ ] 100% test coverage

**Test Requirements:**
- **CRITICAL:** Isolation test (no persistent table mutations)
- Verify feature computation (in-memory only)
- Test connection cleanup

**Spec Reference:** Section 3.4.3, 5.4.1

---

### LDG-208: Integration Test - TTR Adapter
**Priority:** 🟡 P2  
**Effort:** 0.5 days  
**Dependencies:** LDG-204, LDG-211  

**Description:**
End-to-end test with TTR package.

**Tasks:**
1. Create `tests/testthat/test-integration-ttr.R`
2. Wrap TTR::RSI via adapter
3. Run backtest with TTR indicator
4. Verify results

**Acceptance Criteria:**
- [ ] Test skipped if TTR not installed
- [ ] TTR indicator works in backtest
- [ ] Results validated

**Test Requirements:**
- Integration test (full backtest)
- `skip_if_not_installed("TTR")`

**Spec Reference:** Section 6.2.4

---

### LDG-209: Integration Test - CSV Adapter
**Priority:** 🟡 P2  
**Effort:** 0.5 days  
**Dependencies:** LDG-205, LDG-211  

**Description:**
End-to-end test with CSV indicator.

**Tasks:**
1. Create `tests/testthat/test-integration-csv.R`
2. Create fixture CSV with pre-computed values
3. Wrap via `ledgr_adapter_csv()`
4. Run backtest
5. Verify indicator values match CSV

**Acceptance Criteria:**
- [ ] CSV adapter works in backtest
- [ ] Multi-instrument CSV support verified
- [ ] Results validated

**Test Requirements:**
- Integration test (full backtest)
- Fixture CSV committed to repo

**Spec Reference:** Section 6.2.4

---

### LDG-210: Purity Tests for Indicators
**Priority:** 🔴 P0  
**Effort:** 1 day  
**Dependencies:** LDG-203  

**Description:**
Implement comprehensive purity tests for indicators.

**Tasks:**
1. Create `tests/testthat/test-indicator-purity.R`
2. Determinism tests (3x same input → same output)
3. Side-effects tests (`expect_silent()`)
4. Static check for `<<-` assignment
5. Apply to all built-in indicators

**Acceptance Criteria:**
- [ ] Determinism tests pass
- [ ] No output/messages during execution
- [ ] No `<<-` assignment detected
- [ ] Tests run for all built-ins

**Test Requirements:**
- Test each built-in indicator
- Template for user indicators

**Spec Reference:** Section 5.3.2

---

### LDG-211: Make Registry-Backed Replay Deterministic
**Priority:** 🟠 P1  
**Effort:** 2 days  
**Dependencies:** LDG-202, LDG-204, LDG-205, LDG-107  

**Description:**
Close determinism gaps caused by mutable in-memory strategy and indicator
registries. A stored run config must fingerprint the executable strategy and
indicator definitions strongly enough that a changed closure, changed default,
changed adapter payload, or overwritten registry entry cannot silently reuse a
stale deterministic run ID or replay different logic under the same config.

**Tasks:**
1. Include functional strategy closure environment/default values in strategy fingerprints where deterministic
2. Fail loud when a functional strategy captures non-deterministic values
3. Include indicator function body, params, stable window, and adapter data hash in feature config fingerprints
4. Detect duplicate indicator registry names unless an explicit overwrite flag is provided
5. Store resolved indicator fingerprints in `runs.config_json`
6. Ensure DONE-run reuse compares the strengthened config hash

**Acceptance Criteria:**
- [ ] Two closures with different captured target values produce different strategy keys
- [ ] Non-deterministic captured values fail before run creation
- [ ] Indicator registry overwrite cannot silently change replay behavior
- [ ] CSV adapter data changes alter the feature fingerprint
- [ ] Reusing a run ID with changed strategy/indicator logic fails loud

**Test Requirements:**
- Unit test for closure-value strategy hashing
- Unit test for duplicate indicator registration behavior
- Integration test: changed registered indicator under same name changes config hash or errors
- Regression test: unchanged deterministic strategy/indicators reuse the same run ID

**Spec Reference:** Section 5.1, 5.3.1, 5.6

---

### LDG-212: Align Interactive and Runtime Pulse Contexts
**Priority:** 🟠 P1  
**Effort:** 1 day  
**Dependencies:** LDG-206, LDG-207, LDG-111  

**Description:**
Make strategies developed with `ledgr_pulse_snapshot()` behave the same under
the default runtime context. The public interactive context and default
`ledgr_backtest()` context must expose compatible `bars` and `features`
semantics, or the performance-optimized context must be explicit and opt-in.

**Tasks:**
1. Define the canonical strategy context schema for `bars` and `features`
2. Make `ledgr_pulse_snapshot()` and default runtime contexts use that schema
3. If a fast proxy remains, make it opt-in via `control$fast_context = TRUE`
4. Add compatibility tests for `nrow()`, column indexing, and named column access
5. Document any performance-mode deviations in `control`

**Acceptance Criteria:**
- [ ] A strategy using data-frame `bars` semantics works in `ledgr_pulse_snapshot()`
- [ ] The same strategy works in default `ledgr_backtest()`
- [ ] Fast proxy mode is opt-in or API-compatible
- [ ] Feature context shape is consistent between interactive and runtime modes

**Test Requirements:**
- Integration test: develop strategy against `ledgr_pulse_snapshot()` and run it unchanged
- Unit test for `bars` class/columns in runtime context
- Unit test for `features` class/columns in runtime context

**Spec Reference:** Section 3.4.3, 5.4.1

---

## Week 3: Trade Aggregation, Reconstruction & Basic Metrics

### LDG-301: Implement `ledgr_extract_fills()`
**Priority:** 🟠 P1  
**Effort:** 1.5 days  
**Dependencies:** LDG-107, LDG-110, LDG-111, LDG-112  

**Description:**
Extract fill events from ledger with FIFO realized P&L.

**Tasks:**
1. Create `R/fills.R`
2. Query ledger_events for FILL/FILL_PARTIAL
3. Parse meta_json for realized_pnl
4. Return ALL fills (not just closes)
5. Return tibble with proper columns

**Acceptance Criteria:**
- [ ] Returns all fills (realized_pnl may be 0)
- [ ] Parses meta_json correctly
- [ ] Returns tibble with required columns
- [ ] Handles empty ledger (0 rows)
- [ ] 100% test coverage

**Test Requirements:**
- Unit test with fills
- Unit test with empty ledger (no trades)
- Integration test (backtest → fills)

**Spec Reference:** Section 4.2.1

---

### LDG-302: Implement `ledgr_compute_equity_curve()`
**Priority:** 🟠 P1  
**Effort:** 1 day  
**Dependencies:** LDG-107  

**Description:**
Extract equity curve from v0.1.1 pre-computed table.

**Tasks:**
1. Create `R/equity.R`
2. Query equity_curve table (v0.1.1 already computes this)
3. Add drawdown columns
4. Return tibble

**Acceptance Criteria:**
- [ ] Reads from equity_curve table
- [ ] Computes running_max and drawdown
- [ ] Returns tibble
- [ ] 100% test coverage

**Test Requirements:**
- Unit test with equity data
- Verify drawdown calculation
- Integration test (backtest → equity curve)

**Spec Reference:** Section 4.3.2

---

### LDG-303: Implement Basic Metrics Computation
**Priority:** 🟠 P1  
**Effort:** 2 days  
**Dependencies:** LDG-301, LDG-302  

**Description:**
Implement 8 basic metrics with zero guards.

**Tasks:**
1. Create `R/metrics.R`
2. Implement `ledgr_compute_metrics(bt, metrics = "standard")`
3. Compute: total_return, annualized_return, volatility, max_drawdown
4. Compute: n_trades, win_rate, avg_trade, time_in_market
5. Add zero guards (n_trades == 0 → NA for win_rate, avg_trade)
6. NA handling in returns computation (`na.rm = TRUE`)
7. Error on non-"standard" metrics

**Acceptance Criteria:**
- [ ] Computes all 8 metrics
- [ ] Zero guards work (no division by zero)
- [ ] NA handling correct
- [ ] Errors on unsupported metrics
- [ ] 100% test coverage

**Test Requirements:**
- Unit test with normal backtest
- Unit test with zero trades
- Unit test with few data points
- Edge cases: single pulse, no returns

**Spec Reference:** Section 4.3.1

---

### LDG-304: Helper Functions for Metrics
**Priority:** 🟠 P1  
**Effort:** 1 day  
**Dependencies:** LDG-303  

**Description:**
Implement metric computation helpers.

**Tasks:**
1. Add to `R/metrics.R`
2. Implement `compute_annualized_return(equity)`
3. Implement `compute_max_drawdown(equity_values)`
4. Implement `compute_time_in_market(equity)` (from positions_value)
5. All with proper NA/zero handling

**Acceptance Criteria:**
- [ ] Helpers work correctly
- [ ] Handle edge cases (zero trades, single day, etc.)
- [ ] 100% test coverage

**Test Requirements:**
- Unit tests for each helper
- Edge case tests

**Spec Reference:** Section 4.3.1

---

### LDG-305: Update `summary.ledgr_backtest()` with Metrics
**Priority:** 🟠 P1  
**Effort:** 0.5 days  
**Dependencies:** LDG-303  

**Description:**
Wire metrics into summary method.

**Tasks:**
1. Update `R/backtest.R`
2. Call `ledgr_compute_metrics()` in summary
3. Display formatted output
4. Handle zero trades gracefully

**Acceptance Criteria:**
- [ ] Summary displays all 8 metrics
- [ ] Formatting matches spec examples
- [ ] Handles zero trades (shows NA)
- [ ] 100% test coverage

**Test Requirements:**
- UX test for output format
- Test with zero trades

**Spec Reference:** Section 2.4.3

---

### LDG-306: Update `as_tibble()` with Fills/Equity
**Priority:** 🟠 P1  
**Effort:** 0.5 days  
**Dependencies:** LDG-301, LDG-302  

**Description:**
Wire fills and equity extraction into as_tibble.

**Tasks:**
1. Update `R/backtest.R`
2. Add "equity" option → calls `ledgr_compute_equity_curve()`
3. Add "fills" option → calls `ledgr_extract_fills()`
4. Add "ledger" option (raw events)

**Acceptance Criteria:**
- [ ] All three options work
- [ ] Returns tibbles
- [ ] No object mutation
- [ ] 100% test coverage

**Test Requirements:**
- Unit test for each option
- Verify no mutation

**Spec Reference:** Section 2.4.4

---

### LDG-307: Zero-Trade Edge Case Tests
**Priority:** 🔴 P0  
**Effort:** 0.5 days  
**Dependencies:** LDG-303  

**Description:**
Comprehensive edge case testing for zero trades.

**Tasks:**
1. Create `tests/testthat/test-edge-cases.R`
2. Test backtest with no trades
3. Verify metrics return NA where appropriate
4. Test summary/print don't error
5. Test as_tibble returns empty fills

**Acceptance Criteria:**
- [ ] Zero-trade backtest doesn't error
- [ ] Metrics handle gracefully
- [ ] All methods work with zero trades

**Test Requirements:**
- Edge case suite
- Zero trades
- Single trade
- Single pulse

**Spec Reference:** Section 6.2.5

---

### LDG-308: Reconstruct Snapshot-Backed Runs
**Priority:** 🟠 P1  
**Effort:** 2 days  
**Dependencies:** LDG-110, LDG-302  

**Description:**
Make `ledgr_state_reconstruct()` work for v0.1.1/v0.1.2 snapshot-backed runs.
The public reconstruction API must rebuild derived state from the same sealed
snapshot source used during the original run, not from a legacy persistent
`bars` table that may be empty.

**Tasks:**
1. Read snapshot provenance from `runs.config_json`
2. Reopen the snapshot DB when it differs from the run DB
3. Verify the snapshot hash before reconstructing
4. Use `snapshot_bars` as the bar source for pulse calendars and mark-to-market
5. Preserve support for legacy v0.1.0 runs that still use persistent `bars`
6. Add clear errors when snapshot provenance or source data is unavailable

**Acceptance Criteria:**
- [x] `ledgr_state_reconstruct()` succeeds for a normal snapshot-backed backtest
- [x] Reconstruction validates the sealed snapshot hash
- [x] Reconstruction works when run DB and snapshot DB are separate
- [x] Legacy v0.1.0 reconstruction still works
- [x] Missing snapshot source fails loud with actionable guidance

**Test Requirements:**
- Integration test: snapshot backtest -> reconstruct -> equity matches run output
- Integration test with separate snapshot DB/run DB
- Tamper test: corrupted snapshot fails reconstruction
- Regression test for legacy `bars` table reconstruction

**Spec Reference:** v0.1.0 reconstruction API, v0.1.1 snapshot run contract

---

## Week 4: Visualization

### LDG-401: Implement `plot.ledgr_backtest()` - Equity Curve
**Priority:** 🟡 P2  
**Effort:** 1.5 days  
**Dependencies:** LDG-302  

**Description:**
Implement equity curve visualization.

**Tasks:**
1. Create `R/plot.R`
2. Implement `plot.ledgr_backtest(x, type = "equity")`
3. Use ggplot2 (default colors, no hardcoded hex)
4. Equity curve (line)
5. Drawdown (area)
6. Two-panel if gridExtra available, else equity-only with message
7. Register `S3method(plot, ledgr_backtest)` in `NAMESPACE`
8. Ensure `plot(bt)` works because `print.ledgr_backtest()` advertises it

**Acceptance Criteria:**
- [ ] Creates ggplot2 plot
- [ ] `plot(bt)` dispatches to `plot.ledgr_backtest()` without base plot errors
- [ ] Uses default theme colors
- [ ] Shows equity + drawdown if gridExtra present
- [ ] Graceful fallback if gridExtra missing
- [ ] Helpful message about optional dependency
- [ ] 100% test coverage

**Test Requirements:**
- Visual test (create plot, verify no errors)
- Test with/without gridExtra
- UX test for message content

**Spec Reference:** Section 4.4.1

---

### LDG-402: Plot Visual Tests
**Priority:** 🟢 P3  
**Effort:** 0.5 days  
**Dependencies:** LDG-401  

**Description:**
Create visual regression tests for plots.

**Tasks:**
1. Create `tests/testthat/test-plot-visual.R`
2. Generate plots with test data
3. Verify no errors
4. Optional: vdiffr for visual regression

**Acceptance Criteria:**
- [ ] Plots generate without errors
- [ ] Visual tests (if vdiffr used)

**Test Requirements:**
- Generate plot for various backtests
- No crashes

**Spec Reference:** Section 6.2.6

---

## Week 5: Documentation Foundation, API Surface & Polish

### LDG-500: Export v0.1.2 API and Fix Package Check Hygiene
**Priority:** 🔴 P0  
**Effort:** 1.5 days  
**Dependencies:** LDG-105, LDG-108, LDG-109, LDG-110, LDG-111, LDG-112, LDG-201, LDG-202, LDG-203, LDG-204, LDG-205, LDG-206, LDG-207, LDG-211, LDG-212, LDG-301, LDG-302, LDG-303, LDG-308, LDG-401, LDG-402  

**Description:**
Lock the public v0.1.2 API surface and remove package-check hygiene issues
before documentation and release tasks. Implemented user-facing functions must
be callable without `ledgr:::` and advertised methods must dispatch normally.

**Tasks:**
1. Export v0.1.2 public constructors, registries, adapters, indicators, metrics, fills, bench, and pulse tools
2. Register S3 methods for `plot.ledgr_backtest()` and close methods for interactive contexts
3. Update `test-api-exports.R` to lock the intended v0.1.2 public API
4. Add missing imports or qualify calls flagged by `R CMD check`
5. Add missing Suggests entries for optional packages referenced via `::`/`requireNamespace()`
6. Remove use of unavailable APIs such as `DBI::dbGetConnection`, or guard them correctly
7. Document `...` arguments in close-method Rd files
8. Update `DESCRIPTION`, `NEWS.md`, and package title/description from v0.1.1 scaffolding to v0.1.2

**Acceptance Criteria:**
- [ ] No v0.1.2 public API requires `ledgr:::`
- [ ] Export lock test includes all intended v0.1.2 user-facing functions
- [ ] `plot(bt)` dispatches through the registered S3 method
- [ ] `R CMD check --no-manual --no-build-vignettes` has no warnings caused by undeclared imports, missing aliases, or unqualified functions
- [ ] Optional missing Suggests skip gracefully in tests
- [ ] Package metadata reports version 0.1.2 and no longer describes the package as scaffolding

**Test Requirements:**
- API export lock test
- Smoke tests using only exported functions
- `R CMD check` run with `_R_CHECK_FORCE_SUGGESTS_=false`

**Spec Reference:** Section 2.1, 7.2.1

---

### LDG-501: Package Documentation (roxygen)
**Priority:** 🟠 P1  
**Effort:** 2 days  
**Dependencies:** LDG-500  

**Description:**
Complete roxygen documentation for all exported functions.

**Tasks:**
1. Document all exported functions
2. Add @examples for key functions
3. Document parameters and return values
4. Add @seealso cross-references
5. Generate man/ files

**Acceptance Criteria:**
- [ ] All exports documented
- [ ] Examples run without errors
- [ ] Parameters documented
- [ ] Build passes R CMD check

**Test Requirements:**
- Examples run successfully
- `R CMD check` passes

**Spec Reference:** Section 7.2.1

---

### LDG-502: README with Quickstart
**Priority:** 🟠 P1  
**Effort:** 1 day  
**Dependencies:** LDG-501, LDG-507  

**Description:**
Create comprehensive README with quickstart example.

**Tasks:**
1. Create `README.md`
2. Feature overview
3. Installation instructions
4. Quickstart example (5-minute backtest)
5. Link to vignettes (placeholders)
6. Badge setup (CI, coverage, CRAN)

**Acceptance Criteria:**
- [ ] README clear and concise
- [ ] Quickstart works
- [ ] Installation instructions correct
- [ ] Links valid

**Test Requirements:**
- Quickstart code runs
- Links checked

**Spec Reference:** Section 7.2.1

---

### LDG-503: Vignette Outlines
**Priority:** 🟡 P2  
**Effort:** 1 day  
**Dependencies:** LDG-501  

**Description:**
Create vignette structure (outlines only, full content in v0.1.3).

**Tasks:**
1. Create `vignettes/` directory
2. Create outlines for:
   - "Getting Started with ledgr"
   - "Developing Custom Indicators"
   - "Interactive Strategy Development"
3. Structure only (1-2 paragraphs + TOC per vignette)

**Acceptance Criteria:**
- [ ] Vignette files created
- [ ] Structure defined
- [ ] Note: "Full content in v0.1.3"
- [ ] Build succeeds

**Test Requirements:**
- Vignettes build without errors

**Spec Reference:** Section 7.2.1

---

### LDG-504: Error Message Audit
**Priority:** 🟡 P2  
**Effort:** 1 day  
**Dependencies:** LDG-500, LDG-501  

**Description:**
Audit all error messages for clarity and helpfulness.

**Tasks:**
1. Review all `stop()` calls
2. Verify error messages match spec examples
3. Add "how to fix" suggestions where missing
4. Test error messages

**Acceptance Criteria:**
- [ ] All errors have helpful messages
- [ ] Installation instructions in package errors
- [ ] "Create with: ..." suggestions where applicable
- [ ] Error tests pass

**Test Requirements:**
- UX tests for error messages
- Verify spec examples

**Spec Reference:** Section 2.5, 5.6

---

### LDG-505: Regression Test Suite
**Priority:** 🔴 P0  
**Effort:** 1 day  
**Dependencies:** LDG-105, LDG-109, LDG-110, LDG-111, LDG-112, LDG-211, LDG-212, LDG-308  

**Description:**
Run full v0.1.1 acceptance test suite.

**Tasks:**
1. Run AT1-AT12 from v0.1.1
2. Verify all pass unchanged
3. Document any required adaptations
4. Add to CI as first step

**Acceptance Criteria:**
- [ ] All v0.1.1 tests pass
- [ ] No modifications to test logic
- [ ] CI runs regression first (fail fast)

**Test Requirements:**
- AT1-AT12 pass
- CI configured

**Spec Reference:** Section 6.2.1

---

### LDG-506: Coverage Report
**Priority:** 🟡 P2  
**Effort:** 0.5 days  
**Dependencies:** LDG-505  

**Description:**
Generate coverage report and verify targets.

**Tasks:**
1. Run `covr::package_coverage()`
2. Verify coverage targets:
   - High-level APIs: 100%
   - Interactive tools: 100%
   - Adapters: 90%+
   - Helpers: 80%+
3. Generate HTML report
4. Add to CI

**Acceptance Criteria:**
- [ ] Coverage meets targets
- [ ] HTML report generated
- [ ] CI fails if below 80% total

**Test Requirements:**
- Coverage measured
- Targets met

**Spec Reference:** Section 6.3

---

### LDG-507: Final Integration Test
**Priority:** 🔴 P0  
**Effort:** 1 day  
**Dependencies:** LDG-208, LDG-209, LDG-212, LDG-308, LDG-401, LDG-500, LDG-504  

**Description:**
End-to-end integration test covering full workflow.

**Tasks:**
1. Create `tests/testthat/test-integration-full.R`
2. Workflow: Data loading → snapshot → indicators → backtest → metrics → plot
3. Verify all components work together
4. Check for memory leaks, connection leaks

**Acceptance Criteria:**
- [ ] Full workflow completes
- [ ] No errors or warnings
- [ ] Results validated
- [ ] No resource leaks

**Test Requirements:**
- Full integration test
- Resource leak checks

**Spec Reference:** Section 6.2.4

---

### LDG-508: Windows CI Verification
**Priority:** 🔴 P0  
**Effort:** 0.5 days  
**Dependencies:** LDG-505, LDG-506, LDG-507  

**Description:**
Verify all tests pass on Windows CI.

**Tasks:**
1. Configure GitHub Actions with Windows runner
2. Run full test suite
3. Verify no file lock issues
4. Verify connection hygiene

**Acceptance Criteria:**
- [ ] All tests pass on Windows
- [ ] No file lock errors
- [ ] CI green on Windows

**Test Requirements:**
- Windows CI passing
- File lock test specifically verified

**Spec Reference:** Section 5.5.3

---

### LDG-509: Add Agent-Ready Project Metadata
**Priority:** P2  
**Effort:** 1 day  
**Dependencies:** LDG-500  

**Description:**
Make the repository easier for future coding agents and human handoffs to
continue safely by turning the design contracts and ticket DAG into lightweight,
machine-readable project metadata.

**Tasks:**
1. Add root `AGENTS.md` with repo-specific workflow rules and verification commands
2. Add machine-readable ticket metadata (`tickets.yml`) for IDs, dependencies, files, and tests
3. Add a compact contract index (`inst/design/contracts.md` or `inst/schemas/contracts.yml`)
4. Add traceability conventions for tests (`LDG-XXX / spec section` in test names)
5. Add ADR folder and starter ADRs for split DB semantics, registry overwrite policy, and closure fingerprinting
6. Document expected R commands and local Windows R path assumptions

**Acceptance Criteria:**
- [ ] Future agents can identify the next unblocked ticket without parsing prose
- [ ] Core contracts are discoverable in one compact file
- [ ] Verification commands are documented
- [ ] ADRs capture open/high-impact design decisions
- [ ] Existing tests/docs continue to pass/check

**Test Requirements:**
- Static validation that `tickets.yml` contains all `LDG-*` ticket IDs
- Static validation that ticket dependencies reference known IDs
- Smoke check that commands in `AGENTS.md` are syntactically correct

**Spec Reference:** Section 2.1.1, Section 6

---

## Summary Statistics

**Total Tickets:** 44  
**Estimated Total Effort:** ~49.5 days (8-9 weeks calendar time with parallelization)

**By Priority:**
- 🔴 P0 (Blocker): 15 tickets
- 🟠 P1 (Critical): 19 tickets
- 🟡 P2 (Important): 9 tickets
- 🟢 P3 (Nice to have): 1 ticket

**By Week:**
- Week 1: 12 tickets (foundational + snapshot/runner correctness)
- Week 2: 12 tickets (indicators + replay/context determinism)
- Week 3: 8 tickets (fills, reconstruction, metrics)
- Week 4: 2 tickets (visualization)
- Week 5: 10 tickets (API surface, docs & polish)
- Ongoing: Review-driven correctness gates are embedded in the DAG

**Critical Path:**
LDG-101 -> LDG-102 -> LDG-103 -> LDG-104 -> LDG-105/LDG-109 -> LDG-107 -> LDG-110/LDG-111/LDG-112 -> LDG-301 -> LDG-303 -> LDG-308 -> LDG-500 -> LDG-505 -> LDG-507 -> LDG-508

**Test Coverage Targets:**
- Regression: 100% (v0.1.1 tests)
- Equivalence: 100% (wrapper tests)
- Isolation: 100% (read-only tests)
- Unit: 80%+ overall
- Integration: Key workflows

---

## Implementation Notes

### Parallelization Opportunities

**Week 1:**
- LDG-104, LDG-106 can be developed in parallel after LDG-103
- LDG-105 and LDG-109 can run in parallel after LDG-104
- LDG-110, LDG-111, and LDG-112 can run in parallel after LDG-107
- LDG-108 can start after LDG-107

**Week 2:**
- LDG-203, LDG-204, LDG-205 can be developed in parallel after LDG-201
- LDG-206, LDG-207 can be developed in parallel
- LDG-211 can start after LDG-202/204/205
- LDG-212 can start after LDG-206/207 and LDG-111

**Week 3:**
- LDG-301, LDG-302 can be developed in parallel
- LDG-304 parallel with LDG-303
- LDG-308 can start once LDG-110 and LDG-302 are complete

### Risk Mitigation

**High-Risk Tickets:**
- LDG-105, LDG-109 (snapshot artifact integrity)
- LDG-107 (core wrapper - must be pure)
- LDG-110 (split database semantics)
- LDG-111 (strategy validation changes affect fills)
- LDG-112 (resume safety)
- LDG-211 (replay determinism and config hashing)
- LDG-206, LDG-207 (finalizers can be tricky)
- LDG-308 (public reconstruction must match snapshot runs)
- LDG-303 (metrics edge cases)
- LDG-500 (exports/package check can expose incomplete API decisions)
- LDG-505 (regression - must pass)

**Mitigation:**
- Extra review time for high-risk tickets
- Early prototyping of finalizer pattern
- Comprehensive edge case testing
- Daily regression runs

### Review Checkpoints

**Week 1 End:** High-level API working, snapshot integrity fixed, runner safety gates passing  
**Week 2 End:** Indicators working, purity/replay/context determinism passing  
**Week 3 End:** Fills, reconstruction, metrics, and zero-trade tests passing  
**Week 4 End:** Plots working  
**Week 5 End:** Public API locked, documentation complete, all tests/checks passing, ready to ship

---

## Ticket Template

For new tickets, use this template:

```markdown
### LDG-XXX: [Title]
**Priority:** [🔴 P0 | 🟠 P1 | 🟡 P2 | 🟢 P3]  
**Effort:** [X days]  
**Dependencies:** [Ticket IDs]  

**Description:**
[What needs to be done]

**Tasks:**
1. [Concrete task]
2. [Concrete task]

**Acceptance Criteria:**
- [ ] [Testable criterion]
- [ ] [Testable criterion]

**Test Requirements:**
- [Specific tests needed]

**Spec Reference:** Section X.X
```

---

**End of Implementation Tickets**
