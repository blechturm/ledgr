# ledgr Roadmap

**Status:** Active (derived from locked design document v0.3)

This roadmap translates the *ledgr* design document into concrete, buildable
milestones. Each version has a clear **goal**, **scope**, and **definition of
done**. If a milestone's done criteria are met, the version is considered
complete.

The roadmap is intentionally conservative and correctness-first.

---

## Vision

ledgr covers the systematic trading arc from research to production:

```text
research  ->  paper trading  ->  live trading on an edge device
```

The research layer (v0.1.x) validates strategies through sealed-snapshot
backtests, a durable experiment store, and fast parameter sweeps. Those
strategies use the same contract in paper and live mode through broker adapters.
The event-sourced ledger is the shared model across all three modes: backtest and
paper fills share the same event schema; live trading extends the event stream
with broker lifecycle events without changing the strategy contract.

DuckDB runs anywhere R runs, including lightweight ARM edge hardware. A validated
strategy can be deployed to an edge device with an R instance, a DuckDB
experiment store, and a broker adapter -- fully auditable through the same ledger
it was developed against.

The research workflow before deployment has two phases:

1. **Sweep** (v0.1.7): fast, parallel, no persistence -- explore the parameter
   space using shared precomputed features and find the candidates.
2. **Persist** (v0.1.5): full provenance run -- validate top candidates with
   durable artifacts, strategy identity metadata, and experiment-store provenance.

v0.1.5 ships before v0.1.7 because sweep mode depends on the same experiment
identity and parity contracts that persistence establishes.

These phases compose with ecosystem parallelism packages (mori, mirai, furrr)
without ledgr taking hard dependencies on them.

---

## Guiding Principles

- Treat the v0.1.x experiment store as the foundation for, not a replacement
  for, the long-term backtest -> paper -> live path.
- Ship **vertical slices**, not partial subsystems.
- Prefer **determinism and auditability** over speed.
- No live trading before paper trading is boring.
- Every version must be restart-safe and testable.

---

## v0.0.x - Package Foundation (DONE)

**Goal:** Establish a clean, professional R package skeleton aligned with the
design doc.

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

## v0.1.0 - Deterministic Backtest MVP (Core Spine)

**Goal:** Run a fully deterministic EOD backtest end-to-end using the core
contracts.

### Scope

#### Data And Storage

- DuckDB database initialization
- Minimal schemas:
  - runs
  - instruments
  - bars
  - ledger_events
- Snapshot metadata (hashes, timestamps)

#### Ledger And Derived State

- Append-only event ledger
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
- Stateless-by-default enforcement

#### Feature Engine (Minimal)

- Feature definitions with:
  - `requires_bars`
  - `stable_after`
- Engine-enforced window slicing
- Mandatory lookahead tests

#### Execution Simulation

- EOD fill model:
  - next open
  - fixed spread (bps)
  - fixed commission

#### Data Health

- Gap detection (calendar-based)
- Synthetic flag
- Default no-trade on unhealthy data

### Deliverables

- `ledgr_backtest_run(config)`
- DuckDB artifact bundle per run
- One trivial test strategy (for example buy-and-hold) used only in tests

### Definition of Done

- Same inputs -> identical ledger + equity curve
- Restarting a backtest reproduces identical results
- Lookahead test suite runs and passes

---

## v0.1.1 - Data Ingestion And Snapshotting

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

- Backtest replay does not depend on re-downloading data
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

## v0.1.4 - Research Workflow Stabilisation

**Goal:** Stabilize the post-onboarding research loop before the larger
experiment-store API is finalized.

v0.1.4 was originally scoped as "Experiment Store Core." Evaluation after
v0.1.3 showed that durable snapshot reuse, strategy ergonomics, indicator
performance, and reference-doc clarity needed to be tightened first. The
experiment-store core moves to v0.1.5.

### Scope

#### Public API And Lifecycle Cleanup

- Document the v0.x compatibility policy
- Clarify low-level lifecycle for `ledgr_backtest_run()`
- Keep `ledgr_config()` internal while giving it a stable S3 class and
  validator
- Mark `ledgr_data_hash()` as a legacy direct-bars helper
- Clarify `ledgr_state_reconstruct()` as a low-level DBI recovery API
- Resolve public/internal wording for telemetry helpers

#### Durable Snapshot Research Workflow

- `ledgr_snapshot_load(db_path, snapshot_id, verify = FALSE)` for reopening
  existing sealed snapshots
- Path-first `ledgr_snapshot_list("artifact.duckdb")`
- Documentation for connection cleanup and durable artifact reuse

#### Strategy And Pulse Ergonomics

- `ctx$current_targets()` for hold-unless-signal strategy logic
- Position-sizing examples using `ctx$cash`, `ctx$equity`, and `ctx$close(id)`
- Clear documentation that `ctx$targets()` starts from flat targets
- Correct next-open fill-model wording
- Rebalance-throttling examples using `ctx$ts_utc`
- Strategy reproducibility tiers recorded as a design contract for the future
  experiment-store layer

#### Indicator Performance And TTR Bridge

- Optional full-series `series_fn` path for indicators
- Bounded fallback windows for fn-only indicators
- Session-scoped feature cache keyed by snapshot hash, indicator fingerprint,
  feature-engine version, instrument, and date range
- `ledgr_clear_feature_cache()` for explicit cache cleanup
- `ledgr_ind_ttr()` and `ledgr_ttr_warmup_rules()` for low-code TTR indicators
- Expanded deterministic TTR warmup support for common technical indicators
- TTR adapter article in the pkgdown site

### Definition of Done

- v0.1.4 stabilisation tickets are complete
- `contracts.md` and `NEWS.md` match the implemented scope
- README/vignettes/reference examples remain offline-safe
- Feature-cache tests prove repeated runs avoid repeated feature computation
  without relying on brittle wall-clock thresholds
- TTR warmup rules are verified against actual TTR output
- `R CMD check --no-manual --no-build-vignettes` passes with 0 errors and
  0 warnings
- Coverage remains at or above the project gate
- pkgdown site builds
- Ubuntu and Windows CI are green

---

## v0.1.5 - Experiment Store Core

**Goal:** Make DuckDB experiment stores a first-class user concept.

### Scope

- `strategy_params` as explicit experiment identity
- Strategy functions support `function(ctx)` and `function(ctx, params)`
- Store strategy source text, strategy source hash, strategy parameter hash,
  ledgr version, R version, and relevant dependency versions with each run
- Mark runs created before the experiment-store schema as legacy/pre-provenance
  artifacts rather than treating them as fully recoverable experiments
- Run APIs follow a noun-first family convention matching the snapshot API:
  `ledgr_run_list()`, `ledgr_run_open()`, `ledgr_run_info()`,
  `ledgr_run_label()`, and `ledgr_run_archive()`
- `ledgr_run_list(db_path)` to discover runs
- `ledgr_run_open(db_path, run_id)` to reopen a stored run without recomputing
- `ledgr_run_info(db_path, run_id)` to inspect run identity and provenance
- `ledgr_run_label(db_path, run_id, label)` for mutable human names
- `ledgr_run_archive(db_path, run_id, reason = NULL)` for non-destructive cleanup

### Definition of Done

- One sealed snapshot can support multiple named experiments in the same DuckDB
  file
- `run_id` is documented and enforced as an immutable experiment key
- Legacy/pre-provenance runs are discoverable and clearly labeled with their
  missing provenance guarantees
- Archived runs are hidden by default but remain auditable
- Users can leave an R session and later rediscover and reopen stored runs

---

## v0.1.6 - Experiment Comparison And Strategy Recovery

**Goal:** Let users compare experiments and recover strategy code where possible.

### Scope

- `ledgr_compare_runs(db_path, run_ids = NULL)` returning a compact comparison
  table
- `ledgr_extract_strategy(db_path, run_id, trust = FALSE)` or equivalent
  recovery API
- Trust boundary semantics:
  - `trust = FALSE` returns stored strategy source text and metadata only;
  - `trust = TRUE` may parse/evaluate recovered source after verifying the
    stored source hash, but hash verification proves identity, not safety.
- Deterministic capture of JSON-safe strategy parameters
- Clear warnings for strategies that depend on unresolved external objects
- Optional tagging API for grouping runs

### Definition of Done

- Users can compare final equity, return, drawdown, and trade count across runs
- Self-contained functional strategies can be recovered from the experiment
  store with an explicit trust boundary
- Strategy parameters are visible, hashable, and reusable

---

## v0.1.7 - Lightweight Parameter Sweep Mode

**Goal:** Let users run fast exploratory parameter sweeps without DuckDB
persistence, with guaranteed numeric parity against full truth runs.

### Architectural Framing

The backtest is a left fold over pulses:

```text
final_state = Reduce(apply_pulse, pulses, initial_state)
```

Each `apply_pulse` is a pure function of state, bar data, precomputed features,
and the strategy. DuckDB writes are an output handler applied to the result, not
part of the computation. This means `ledgr_backtest()` and `ledgr_sweep()` are
the same fold with different output handlers, not different engines.

Parameter sweeps expose two naturally parallel map dimensions:

```text
map(instruments x indicators -> feature series)   # pure, no dependencies
  -> share zero-copy (mori)
map(parameter combinations -> fold result)        # pure, no dependencies
  ->
reduce(fold results -> comparison table)          # cheap, sequential
```

The only sequential work is within a single fold (the pulse loop has a
time-step dependency that cannot be broken) and the final reduce. Everything
else is embarrassingly parallel.

### Core Invariant

> Sweep mode may remove persistence.
> Sweep mode may not change execution semantics.

The implementation must extract an internal fold core that both
`ledgr_backtest()` and `ledgr_sweep()` call. Implementing `ledgr_sweep()` by
copying the runner and deleting DuckDB calls is explicitly prohibited because
that path leads to silent parity drift.

### Strategy Contract

Sweep mode requires sweep-compatible strategies:

```text
sweep-compatible strategy =
  function(ctx, params)         # functional, explicit params
  + no hidden mutable state     # no closures capturing external env state
  + no DuckDB side effects      # no reads/writes to the run store
  + Tier 1 reproducibility      # as defined in LDG-702
```

R6 strategies are excluded from sweep mode in the initial implementation unless
they can be freshly instantiated per parameter set with no shared state. Sweep
mode fails loudly with a clear error for non-compatible strategies.

### Deterministic Random State

Every backtest and sweep run is fully deterministic by default. Strategies that
use randomness (Monte Carlo sizing, stochastic optimisers, random tie-breaking)
must produce the same output for the same inputs without user intervention.

`ledgr_backtest()` and `ledgr_sweep()` accept an optional `seed` argument:

```r
ledgr_backtest(..., seed = NULL)   # NULL derives default from run_id
ledgr_backtest(..., seed = 42)     # explicit override
ledgr_backtest(..., seed = NA)     # explicit opt-out: non-deterministic
```

When `seed = NULL`, the effective seed is derived deterministically from
`run_id` so the same experiment always starts from the same random state across
sessions. When `seed = NA`, no seed is set and random draws are
non-deterministic; this is an explicit user choice, not the default.

The engine calls `set.seed(seed + pulse_index)` before each pulse callback.
This gives each pulse an independent, deterministic random state. The
pulse-specific seed is exposed as `ctx$seed` for strategy inspection or
logging.

The effective seed is stored in `config_json` and included in `config_hash`.
Two runs that differ only by seed produce different config hashes, which is
correct: they are different experiments. `ledgr_run_info()` surfaces the seed.

Parity between `ledgr_backtest()` and `ledgr_sweep()` extends to random state:
same seed, same pulse order, same draws.

### Parity Scope

"Same equity curve" is necessary but not sufficient. Full parity requires:

- same equity curve
- same trades and fills
- same final positions and cash balance
- same target/fill timing behaviour
- same final-bar no-fill behaviour
- same random draws at each pulse (same seed, same pulse order)

The in-memory event stream produced by sweep mode must be semantically
equivalent to the persisted ledger. Sweep mode drops the DuckDB write; it does
not drop the event semantics.

### Precomputed Features Interface

`precomputed_features` is a typed object, not a raw list:

```r
features <- ledgr_precompute_features(
  snapshot,
  indicators = list(...),
  universe = NULL,
  start = NULL,
  end = NULL
)

ledgr_sweep(
  snapshot = snapshot,
  strategy = strategy,
  strategy_params = param_grid,
  precomputed_features = features
)
```

The object carries: `snapshot_hash`, universe, start/end range, indicator
fingerprints, feature-engine version, and feature matrices. `ledgr_sweep()`
fails loudly if the feature object does not match the requested snapshot, date
range, universe, or indicator set.

If `start` and `end` are `NULL`, `ledgr_precompute_features()` computes the full
sealed snapshot range. A sweep may request the same range or a narrower covered
range; it must fail if the requested pulse range or warmup requirements are not
covered by the feature object.

### Performance Expectations

Sweep mode is not vectorbt-style instant matrix sweeps. It is the same
simulation with a cheaper output path. Expected gains over `ledgr_backtest()`:

- no DuckDB write per run
- no repeated feature computation (features computed once, reused across the
  sweep)
- no run/schema/provenance overhead
- result materialisation reduced to summary output

The pulse loop remains sequential within each run. Sweep mode does not vectorise
strategy evaluation or fill logic. Wall-time gains come from removing
persistence overhead and from parallelising across parameter combinations.

### Recommended Parallel Stack (no hard dependencies)

The first implementation contract is: single-process sweep is correct and faster
than `ledgr_backtest()`. Parallel sweep is user-composable and not part of the
ledgr API.

The intended high-performance parallel pattern composes ledgr with ecosystem
packages users configure independently:

```r
# One-time setup
future::plan(future.mirai::mirai_multisession, workers = 8)
features <- mori::share(                    # zero-copy across all workers
  ledgr_precompute_features(snap, indicators)
)

# Sweep
results <- furrr::future_pmap(param_grid, function(...) {
  ledgr_sweep(..., precomputed_features = features)
})
```

- **future.mirai / mirai** - `future` backend over persistent mirai workers;
  current recommended shape is `future::plan(future.mirai::mirai_multisession,
  workers = n)`, but executable examples must be checked against current
  package docs before publication
- **mori** - OS-level shared memory via ALTREP; feature series shared
  zero-copy across all workers; lazy access means workers pay only for the
  features they touch; mori objects are transparent at the R API boundary
- **furrr** - idiomatic `purrr`-style map API; swap `pmap` for
  `future_pmap` without changing sweep code

ledgr takes no hard dependency on any of these. The `precomputed_features`
interface accepts normal R objects; mori-shared objects work because they are
indistinguishable from plain R objects at the API boundary.

### Definition of Done

- `ledgr_sweep()` and `ledgr_backtest()` produce identical results on the same
  input: equity curve, trades, fills, final positions, cash, fill timing, and
  random draws
- Parity is enforced by CI, not by convention
- Both functions call the same internal fold core; no copied runner code
- `ledgr_precompute_features()` is implemented, typed, and validates against
  the requesting sweep call
- Strategy compatibility contract is enforced with clear errors
- The public API surface clearly communicates what sweep mode does and does not
  guarantee
- Single-process sweep is documented with a working example
- Recommended parallel stack is documented separately as optional guidance
- Default seed derivation from `run_id` is documented and tested
- `ctx$seed` is available at every pulse in both backtest and sweep modes
- Explicit `seed = NA` opt-out is documented with a clear warning about
  non-determinism

---

## v0.1.8 - Portfolio Optimization Support

**Goal:** Make portfolio optimization a first-class research workflow in ledgr.

An optimizer is a strategy that computes target weights mathematically rather
than by rules. The strategy contract already supports this output; what is
missing is the tooling that makes writing optimizer strategies natural rather
than awkward.

ledgr is the harness, not the solver. The optimization math stays external
(quadprog, CVXR, PortfolioAnalytics, or any other solver the user chooses).
ledgr provides the clean inputs and the clean output conversion so that plugging
in a solver feels like one function call, not an exercise in data wrangling.

### Scope

#### Context Accessors

- `ctx$returns_matrix(lookback)` -- a numeric matrix of shape
  `instruments x time` covering the lookback window, ready for covariance
  estimation or any return-based optimization input. Respects the no-lookahead
  guarantee: only bars available at the current pulse are included.
- `ctx$weights_to_targets(weights)` -- converts a named weight vector
  (e.g. `c(SPY = 0.6, TLT = 0.4)`) to share quantities using current equity
  and close prices. Validates that weights sum to at most 1 and that all names
  are in `ctx$universe`.

#### Vignette

A worked vignette demonstrating the full research workflow:

1. Write a mean-variance strategy using `ctx$returns_matrix()` and an external
   solver.
2. Sweep over lookback window and risk-target combinations using
   `ledgr_precompute_features()` and `ledgr_sweep()`.
3. Persist the winning configuration with `ledgr_backtest()` and label it in
   the experiment store.
4. Compare runs with `ledgr_compare_runs()`.

The vignette is the primary deliverable -- the context accessors exist to make
it readable.

#### Reproducibility Note

Strategies that call external solvers (quadprog, CVXR) reference package
functions that are outside the base-R namespace. These strategies are classified
Tier 2 (source captured, replay requires solver package). This is documented
explicitly in the vignette and in `ledgr_run_info()` output.

### Definition of Done

- A mean-variance strategy can be written in under 30 lines of strategy code
  using `ctx$returns_matrix()` and a standard solver
- `ctx$weights_to_targets()` handles weight-to-quantity conversion correctly
  under edge cases: zero equity, missing prices, weights that do not span the
  full universe
- The sweep-to-persist-to-compare workflow is demonstrated end-to-end in the
  vignette against the canonical demo dataset
- `ctx$returns_matrix()` is covered by no-lookahead tests

---

## v0.1.9 - Calendar And Event-Driven Strategies

**Goal:** Give strategies a structured temporal context so calendar and
event-driven logic does not require manual date arithmetic inside the strategy
function.

Calendar strategies are among the most common in systematic research --
month-end rebalancing, quarter-end drift correction, regime detection by
calendar period. Today a ledgr strategy can read `ctx$ts_utc` and compute
everything manually, but every user rewrites the same boilerplate. A thin
calendar layer eliminates that without adding hidden state or breaking the
no-lookahead guarantee.

### Scope

#### Calendar Context Accessors

- `ctx$calendar$is_month_end` -- logical, TRUE if the current pulse is the last
  trading day of the calendar month
- `ctx$calendar$is_quarter_end` -- logical, TRUE if the current pulse is the
  last trading day of the calendar quarter
- `ctx$calendar$days_since(reference_ts)` -- integer count of trading days
  between `reference_ts` and the current pulse, using the universe calendar
  derived from the sealed snapshot
- `ctx$calendar$trading_day` -- integer position of the current pulse within
  the sealed snapshot (1 = first pulse)

All accessors are derived from the sealed snapshot calendar, not from a live
clock. No-lookahead is preserved by construction.

#### Rebalance Throttle Helper

- `ctx$calendar$periods_since_rebalance(frequency)` where `frequency` is one
  of `"daily"`, `"weekly"`, `"monthly"`, `"quarterly"` -- returns an integer
  count of full periods elapsed since the last pulse on which the strategy
  returned a non-flat target change. Intended for strategies that want to
  rebalance on a schedule without tracking their own rebalance timestamp.

#### Vignette Extension

Extend the strategy-authoring vignette with a calendar-driven rebalancing
example: a monthly rebalancing portfolio that acts only on month-end pulses and
holds otherwise.

### Definition of Done

- All calendar accessors are derived from sealed snapshot data with no
  wall-clock calls
- `ctx$calendar$days_since()` is tested against known trading calendars with
  gaps and holidays present in the snapshot
- No-lookahead tests cover calendar accessor paths
- Calendar-driven rebalancing is demonstrated in the strategy-authoring vignette

---

## v0.1.10 - Pairs And Spread Trading

**Goal:** Make cross-instrument spread strategies natural to write without
manual cross-instrument data assembly inside the strategy function.

Pairs trading and statistical arbitrage are distinct from universe-level
portfolio optimization: they operate on instrument pairs, require spread
z-scores and rolling cointegration residuals, and produce relative rather than
absolute target positions. The returns matrix from v0.1.8 partially addresses
this, but the pair-level spread computation is specific enough to warrant its
own accessor layer.

### Scope

#### Spread Accessors

- `ctx$spread(id_a, id_b, lookback)` -- the current price spread between two
  instruments, normalized as a rolling z-score over `lookback` bars. Uses
  log-price difference by default; raw difference available via a `method`
  argument.
- `ctx$spread_history(id_a, id_b, lookback)` -- the full lookback window of
  spread values as a numeric vector, for strategies that need to fit a
  cointegration model or compute their own statistics.

Both accessors respect the no-lookahead guarantee and are computed from the
sealed snapshot bars available at the current pulse.

#### Position Helpers

- `ctx$net_exposure(id_a, id_b)` -- the current net dollar exposure of a pair
  as a signed scalar: positive means long `id_a` / short `id_b`, negative
  means the reverse. Simplifies the position-sizing logic common to
  pairs strategies.

#### Vignette

A worked vignette demonstrating a z-score mean-reversion pairs strategy:
entry on spread z-score threshold, exit on reversion to zero, position sizing
using `ctx$net_exposure()`. Sweep over lookback and entry threshold using
`ledgr_sweep()`, persist the winner.

### Definition of Done

- `ctx$spread()` and `ctx$spread_history()` respect no-lookahead across all
  lookback window sizes
- `ctx$net_exposure()` is consistent with the ledger-derived position state
- A pairs strategy can be written in under 40 lines of strategy code
- The sweep-to-persist workflow is demonstrated in the vignette against the
  canonical demo dataset with at least two instruments

---

## v0.1.11 - ML Strategy Artifact Management

**Goal:** Make ML-based strategies first-class experiment-store citizens by
giving model artifacts their own provenance slot in run identity.

The design document specifies that ML models are trained outside the engine,
loaded as immutable artifacts per run, and treated as deterministic functions
at decision time. The strategy contract already supports this at runtime --
a strategy can load and call any model. What is missing is the provenance
layer: a trained model is not JSON-safe, cannot go in `strategy_params`, and
cannot be fingerprinted by the existing source-hash mechanism. Without artifact
management, ML strategies are always Tier 3 and the experiment store cannot
distinguish two runs that used different model versions.

### Scope

#### Artifact Registry

- `ledgr_artifact_register(path, label = NULL)` -- hashes a model artifact
  file (any format: `.rds`, `.onnx`, `.pt`, etc.) and registers it in the
  experiment store with a content hash, file size, and optional label. Returns
  an artifact handle.
- `ledgr_artifact_load(db_path, artifact_hash)` -- retrieves a registered
  artifact path by hash. Does not load the model itself; loading is the
  user's responsibility and keeps ledgr framework-agnostic.
- Artifact hashes are stored in a new `run_artifacts` table linked to
  `run_provenance`. A run that references an artifact carries the artifact
  hash as part of its experiment identity.

#### Strategy Integration

- `strategy_params` accepts artifact handles as values. An artifact handle
  serializes to its content hash in JSON, making it canonical-JSON-safe and
  hashable. The `strategy_params_hash` therefore changes when the model
  changes, even if no other parameter changes.
- Strategies that load a model via an artifact handle are classified Tier 2
  (source captured, artifact hash recorded, but replay requires the artifact
  file to be present). This is documented explicitly.
- Strategies that load a model by raw file path (bypassing the artifact
  registry) are classified Tier 3.

#### Vignette

A worked vignette: train a classification model offline (e.g. logistic
regression or xgboost), register it as an artifact, write a strategy that
loads and calls it at each pulse, run two experiments with different model
versions, compare run provenance to show the artifact hashes differ.

### Definition of Done

- A model artifact can be registered and its hash stored as part of run
  identity
- Two runs using different model versions produce different
  `strategy_params_hash` values even when all other parameters are identical
- `ledgr_run_info()` displays artifact hashes for runs that reference
  artifacts
- Tier 2 vs. Tier 3 classification is correctly applied based on whether
  the artifact registry was used
- The vignette demonstrates the full workflow: train, register, backtest,
  compare

---

## v0.2.0 - OMS Semantics (Simulation Only)

**Goal:** Introduce realistic order lifecycle handling without a real broker.

### Scope

- OMS state machine tables:
  - INTENT
  - SUBMITTING
  - PENDING
  - ACKED
  - WORKING
  - FILLED / CANCELLED / REJECTED / UNKNOWN
- Soft-commit before submission
- Partial fills (simulated)
- Stale order aging policy

### Definition of Done

- No double-submit invariant holds
- Crash/restart mid-simulation recovers cleanly
- Target-gap logic respects working orders

---

## v0.3.0 - Paper Trading Adapter + Reconciliation

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
  - YELLOW (reduce-only)
  - RED (halt)

### Definition of Done

- Paper trading runs for weeks without manual fixes
- Restart during market hours is safe
- Reconciliation discrepancies are visible and classified

---

## v0.4.0 - Observability And Operations

**Goal:** Make the system operable and debuggable.

### Scope

- Metrics tables:
  - heartbeat
  - decision latency
  - order latency
  - PnL summary
- Periodic reconciliation checks
- Alert hooks (email / log-based acceptable)
- Manual emergency procedures documented

### Definition of Done

- Operator can answer "what is it doing?" quickly
- Frozen or stalled bot is detectable

---

## v1.0.0 - Live Trading (Small Scale)

**Goal:** Controlled live trading with conservative limits.

### Scope

- Live execution enabled behind config gate
- Strict exposure and turnover caps
- Daily post-trade reports

### Definition of Done

- One month of live trading without system errors
- All incidents explainable via ledger + logs

---

## Future Extensions (Explicitly Deferred)

- Additional asset classes (crypto, futures, FX)
- Intraday / multi-pulse scheduling
- Advanced transaction cost models
- Tax-aware accounting (wash sales, lot selection)
- UI / dashboards

---

## Final Note

This roadmap is intentionally strict. If a milestone feels boring, it is
probably correct.
