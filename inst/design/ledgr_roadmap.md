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

1. **Sweep** (v0.1.8): fast, parallel, no persistence -- explore the parameter
   space using shared precomputed features and find the candidates.
2. **Persist** (v0.1.5): full provenance run -- validate top candidates with
   durable artifacts, strategy identity metadata, and experiment-store provenance.

v0.1.5 ships before v0.1.8 because sweep mode depends on the same experiment
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

## Roadmap Discipline

The active roadmap prioritizes the core research-to-paper-trading arc over
expanding strategy-family and asset-class coverage.

The near-term goal is not to support every trading style. The near-term goal is
to prove that one deterministic, event-sourced research workflow can travel from
sealed historical data to paper-trading operations with the same audit trail:

```text
sealed data
  -> deterministic research backtest
  -> durable experiment store
  -> reproducible strategy provenance
  -> comparison and metrics
  -> parameter sweep
  -> target risk layer
  -> OMS simulation
  -> paper trading
  -> observability
```

A new strategy family is not admitted to the active roadmap until ledgr has the
data model, accounting model, execution semantics, and provenance contract to
support it without weakening sealed snapshots, no-lookahead execution,
event-sourced accounting, or run provenance.

Strategy-family expansions remain valuable, but they are deferred until the
backtest-to-paper arc is proven.

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
- Mutable tagging API for grouping runs without changing experiment identity

### Definition of Done

- Users can compare final equity, return, drawdown, and trade count across runs
- Self-contained functional strategies can be recovered from the experiment
  store with an explicit trust boundary
- Strategy parameters are visible, hashable, and reusable
- Tags can group runs as mutable metadata without affecting stored artifacts or
  comparison semantics

---

## v0.1.7 - Core UX Overhaul

**Goal:** Replace the db_path-first research API with a coherent
experiment-first model. Hard-breaks the existing public API; no backward
compatibility. The new surface is the foundation v0.1.8 sweep mode builds on.

**Note:** v0.1.7 is an intentional public API reset before wider adoption.
It explicitly overrides any earlier "deprecate where possible" posture. The
package has no known production users; the cost of a clean break now is lower
than the cost of carrying two API layers into sweep mode and beyond.

**Full spec:** `inst/design/ledgr_ux_decisions.md`

**Spec packet required** before any implementation starts. v0.1.7 scope is
large enough to warrant its own ticket packet with acceptance criteria per
function.

### Scope

**New surface:**
- `ledgr_experiment()` -- central spec object; design this first
- `ledgr_run()` -- single run on an experiment (replaces `ledgr_backtest()` as public API)
- `ledgr_param_grid()` -- typed grid constructor
- `ledgr_opening()` and `ledgr_opening_from_broker()` -- opening state
- `ctx$flat()` and `ctx$hold()` -- replace `ctx$targets()` and `ctx$current_targets()`
- Snapshot-first signatures for all store operation APIs
- `ledgr_run_list` and `ledgr_comparison` S3 print methods

**Hard removals:**
- `ctx$targets()` and `ctx$current_targets()` -- calling them is a loud error
- `function(ctx)` strategy signature -- `function(ctx, params)` is the only valid form
- All `db_path`-first public APIs -- replaced by snapshot-first signatures
- `ledgr_backtest()` demoted to internal; `ledgr_run()` is the public API

**Lifecycle:**
- `close(bt)` made optional; auto-checkpoint on GC with informational message
- In-memory runs require no `close()` at all

### Synthetic Demo Dataset

ledgr ships a built-in, committed demo dataset and a user-facing generator
function. These replace ad-hoc inline bar construction in all vignettes,
examples, and documentation.

#### DGP Design

The dataset is generated by a **regime-switching GBM with GARCH-like
volatility** and a **two-factor correlation structure**:

```text
log-return[i,t] = beta_market[i] * market_factor[t]
                + beta_sector[i] * sector_factor[t]
                + idiosyncratic[i,t]

each factor follows: dX = mu[regime] dt + sigma[regime] dW
regime[t] follows a 3-state Markov chain
```

Three regimes:

| Regime  | Daily mu   | Daily sigma | Typical duration |
|---------|-----------|-------------|-----------------|
| Trending (bull) | +0.03% | 1.0%  | ~60 days        |
| Choppy          |  0.00% | 1.5%  | ~30 days        |
| Crash / bear    | -0.30% | 3.0%  | ~10 days        |

Conditional volatility within each regime follows a GARCH(1,1) update to
produce clustering. Volume is a log-normal function of realized volatility,
giving higher volume in crash regimes.

#### Dataset Specification

- **Instruments:** 12, named `SYM_01` through `SYM_12`; grouped into two
  synthetic sectors of 6 each for factor structure
- **Date range:** 2015-01-01 to 2021-12-31, daily bars (~1,760 rows per
  instrument; ~21,120 rows total)
- **Columns:** `ts_utc`, `instrument_id`, `open`, `high`, `low`, `close`,
  `volume` -- identical schema to `ledgr_snapshot_from_df()` input
- **Stored seed:** fixed in `data-raw/make_demo_bars.R` so the committed
  data is reproducible given the same DGP code and R version

#### Deliverables

- `data-raw/make_demo_bars.R`: the reproducible DGP script; never run
  automatically, regeneration requires a deliberate decision
- `data/ledgr_demo_bars.rda`: committed dataset, available as
  `ledgr::ledgr_demo_bars` after `library(ledgr)`
- `ledgr_sim_bars(n_instruments, n_days, seed, ...)`: exported generator so
  users can create larger or differently-seeded datasets for their own
  experiments; the internal DGP is documented and readable
- Rd documentation for `ledgr_demo_bars` and `ledgr_sim_bars()`

The DGP has no runtime dependencies. All generation code is base R.

### Documentation And Vignette Rewrite

All vignettes, Rd examples, and the README are rewritten to use
`ledgr_demo_bars` or `ledgr_sim_bars()` instead of inline ad-hoc bar
construction. This is a companion task to the dataset ticket, not optional
polish.

#### Scope

- **`vignettes/getting-started.Rmd`**: replace inline bars with a
  `ledgr_demo_bars` subset; demonstrate at least two instruments
- **`vignettes/research-to-production.Rmd`**: replace inline bars;
  examples should show a multi-instrument universe to make the
  research-to-production arc concrete
- **`vignettes/ttr-indicators.Rmd`**: replace the single-instrument
  synthetic bars with a `ledgr_demo_bars` subset
- **`README.Rmd` / `README.md`**: the quick-start example uses
  `ledgr_demo_bars` rather than a hand-constructed data frame
- **All Rd examples in `man/`** that currently construct bars inline:
  replace with `ledgr_demo_bars` or a `ledgr_sim_bars()` call
- Internal test helpers (`test_bars` etc.) are **excluded** -- test
  isolation matters more than consistency there

#### Constraint

The v0.1.10 and v0.1.12 vignettes already reference "the canonical demo
dataset." This task makes that reference concrete. All later vignettes must
be authored against `ledgr_demo_bars` from v0.1.7 onward.

### Definition of Done

- Full workflow from `ledgr_snapshot_from_df()` through `ledgr_run()` and
  `ledgr_compare_runs()` uses no `db_path` argument after snapshot creation
- `ctx$hold()` and `ctx$flat()` are the only documented target constructors
- `function(ctx)` strategies emit a loud error at run time
- `ledgr_run_list()` and `ledgr_compare_runs()` print curated views with
  percentage formatting and footers
- All vignettes and examples are updated to the new API; no inline bar
  construction remains in vignettes or README prose
- `ledgr_demo_bars` is a committed `.rda` in `data/` with >= 10 instruments
  and >= 5 years of daily bars
- `ledgr_sim_bars()` is exported, documented, and deterministic given the
  same seed
- `data-raw/make_demo_bars.R` is the single source of truth for the
  committed dataset; it is not run at install or check time
- All Rd examples that previously constructed bars inline are updated to
  use `ledgr_demo_bars` or `ledgr_sim_bars()`
- `inst/design/ledgr_ux_decisions.md` open questions resolved before ticket cut

---

## v0.1.7.1 - Installed UX Stabilisation

**Goal:** Stabilise the installed-package experience after the v0.1.7
experiment-first reset without reopening the public API design.

### Scope

- Installed narrative docs are discoverable and runnable.
- README and vignettes use modern base-pipe examples with `ledgr_demo_bars`.
- `ledgr_utc()` removes repeated `as.POSIXct(..., tz = "UTC")` boilerplate in
  user-facing examples.
- `ledgr_demo_bars` and `ledgr_sim_bars()` are tibble-friendly.
- Result-table printing can compact all-midnight UTC timestamps for EOD output
  while preserving POSIXct UTC values for programmatic access.
- Experiment-store docs explain curated defaults, "dig deeper" tibble access,
  handle cleanup, snapshot lifecycle, and the difference between sealed market
  data and derived features/runs.
- The audit-reported MACD warmup case is reproduced and fixed or explicitly
  documented as not reproducible.

### Definition of Done

- A first-time installed-package user can run the offline experiment-first
  workflow without source or design-doc context.
- Main run-list and comparison examples use curated print defaults directly.
- `close(bt)` and `ledgr_snapshot_close(snapshot)` are explained before they
  appear as cleanup ceremony.
- No sweep/tune APIs are exported.
- CI is green on Ubuntu and Windows.

---

## v0.1.7.2 - Auditr UX Stabilisation And Strategy Helper Layer

**Goal:** Close the highest-value auditr companion-package findings from the
installed v0.1.7.1 experience and prepare the strategy helper layer without
changing ledgr's canonical target-vector execution contract.

v0.1.7 established `function(ctx, params)` as the public strategy shape.
v0.1.7.2 has two tracks:

1. **Auditr UX stabilisation:** fix confirmed comparison/trade metric
   inconsistencies and remove the most repeated documentation/discovery
   friction from installed-package workflows.
2. **Strategy helper design:** prepare a thin helper layer that lets strategies
   express the common research sequence:

```text
signal -> selection -> weights -> target
```

The helper layer is not a second engine. It must terminate in explicit target
quantities before execution and must continue to use `ledgr_run()` and the
existing runner.

### Scope

- Confirm and fix comparison/trade metric semantics:
  - `summary()`, `ledgr_compare_runs()`, `ledgr_extract_fills()`, and
    `ledgr_results(bt, what = "trades")` must use documented, non-conflicting
    definitions.
  - Flat or zero-trade runs must return stable zero-row result schemas, not
    `0 x 0` tibbles.
- Improve installed documentation discovery for noninteractive users:
  - standard vignette/help discovery paths;
  - command-line safe alternatives for reading installed docs;
  - explicit suggested-package expectations in runnable vignettes.
- Tighten strategy and indicator examples:
  - direct SMA crossover;
  - two-asset momentum;
  - stateful threshold or RSI example;
  - feature ID discovery with `ledgr_feature_id()`;
  - warmup and short-history behavior near examples.
- Overhaul `vignettes/strategy-development.Rmd` as the central strategy
  authoring chapter:
  - teach the design mental model;
  - explain why strategies are `function(ctx, params)`;
  - build a simple quant strategy step by step;
  - show helper functions as economic logic;
  - demonstrate interactive snapshot/pulse debugging during strategy
    development.
- Clarify experiment-store operational examples:
  - durable snapshot IDs;
  - labels/tags in comparison workflows;
  - explicit CSV seal/load/backtest workflow;
  - handle lifecycle framing for long sessions and multi-run workflows.
- Public helper value types for strategy authoring:
  - `ledgr_signal`
  - `ledgr_selection`
  - `ledgr_weights`
  - `ledgr_target`
- Minimal reference helpers for:
  - feature-backed signals;
  - top-n selection;
  - equal weighting;
  - target construction from weights.
- `ledgr_target` validator support as a thin wrapper around a full named
  numeric target vector.
- `contracts.md` update when helper validator support ships, preserving the
  target-quantity execution contract while allowing `ledgr_target` as a helper
  wrapper.
- Explicit long-only behavior: negative weights remain unsupported until a
  future short-selling contract exists.
- Documentation that distinguishes the helper pipeline from the core execution
  contract.
- Corrected handle lifecycle documentation: explicit close calls release
  result-access DuckDB connections for long sessions, but are not framed as
  data-loss prevention after `ledgr_run()` completes.
- Evaluation of per-operation read connections for result access so ordinary
  result inspection does not keep durable DuckDB files locked.

### Non-goals

- No sweep/tune APIs.
- No `strategy_helpers`, `strategy_packages`, or `strategy_globals_ok`
  dependency declaration arguments. Sweep worker dependency packaging remains
  v0.1.8 scope.
- No short selling, leverage, broker margin semantics, or order-level risk.
- No large helper zoo.

### Definition of Done

- The auditr high-priority trade-metric theme is either fixed or explicitly
  documented with tests proving intended behavior.
- Installed-package documentation has a reliable noninteractive discovery path.
- First-path examples are runnable from a clean installed package with stated
  suggested-package assumptions.
- Warmup, feature ID, and strategy target-shape examples address the recurring
  auditr friction points.
- The strategy-development vignette reads as a coherent teaching chapter, with
  runnable examples against `ledgr_demo_bars` and a clear distinction between
  current APIs and any helper-layer examples.
- Helper pipelines run through `ledgr_run()` and produce the same kind of
  target quantities as hand-written strategies.
- Returning signals, selections, or weights directly from a strategy fails
  loudly.
- `contracts.md` is updated to allow `ledgr_target` as a validated wrapper
  while preserving the target-quantity execution contract.
- Strategy documentation explains when to use the helper layer and when to
  write plain `function(ctx, params)` logic.
- Documentation explains close semantics without teaching defensive cleanup as
  mandatory happy-path ceremony.
- Result-access connection lifecycle is either improved with per-operation read
  connections or explicitly deferred to v0.1.8 with the corrected close framing
  retained in v0.1.7.2 docs.
- No sweep/tune APIs or sweep dependency declaration arguments are exported.

---

## v0.1.7.3 - Accounting Correctness And Indicator Documentation UX

**Goal:** Close the confirmed v0.1.7.2 accounting defect, make public metrics
auditable from result tables, and clean up the installed documentation spine so
indicator usage is teachable from one canonical article.

v0.1.7.3 is intentionally small and correctness-first. The release may refactor
documentation architecture, but it must not introduce the future feature-map API
surface.

### Scope

- Fix the Episode 013 equity-curve inconsistency so final cash, positions,
  `positions_value`, equity, fills, trades, and summary metrics reconcile.
- Add independent metric oracles that recompute public metrics from public
  result tables rather than ledgr metric internals.
- Add an installed `metrics-and-accounting` vignette that teaches fills,
  trades, equity rows, and summary metric definitions.
- Strengthen help-page and package-level article discovery for headless users
  and agents.
- Consolidate indicator teaching into a single installed `indicators` vignette:
  - built-in ledgr indicators and TTR-backed indicators share one mental model;
  - feature IDs are shown before use;
  - warmup `NA` is explained as the general indicator contract;
  - multi-output TTR details remain available through focused reference docs.
- Retire `ttr-indicators` as a parallel installed teaching vignette once the
  general indicators article exists. Do not keep redundant installed docs for
  the same indicator mental model.
- Keep the feature-map API proposal in `inst/design/ledgr_feature_map_ux.md` as
  future design work. Do not export `ledgr_feature_map()`, `ctx$features()`, or
  `passed_warmup()` in this release.

### Definition of Done

- Accounting fixtures pass in supported execution modes.
- Every printed public metric has a documented definition and an independent
  regression oracle.
- Installed help pages point to the correct teaching articles with interactive
  and noninteractive lookup paths.
- `indicators` is the installed article for indicator concepts; `ttr-indicators`
  is removed from the installed article spine or otherwise deliberately retired
  with matching contract, help, pkgdown, and test updates.
- TTR-specific output names and warmup formulas remain discoverable from
  `?ledgr_ind_ttr`.
- No feature-map API is exported.
- Ubuntu and Windows CI are green.

---

## v0.1.7.4 - External Documentation Review And Auditr Report

**Goal:** Close the documentation gaps identified by external review and the
v0.1.7.3 auditr episode report, and add the feature-authoring UX needed to make
indicator-heavy strategies readable before the v0.1.8 API surface expands.

This release may add a small authoring API for feature maps, but it must not
change the execution model: strategies still return full named numeric target
vectors, and helper objects must flow through the same target-vector validator.
Documentation scope is intentionally held open until the auditr report is
complete; the items below are confirmed findings from external review that do
not depend on that report.

### Confirmed Scope

**`ledgr_backtest()` API-story clarification**

The `metrics-and-accounting` vignette uses `ledgr_backtest()` as a compact
accounting fixture while every other article teaches the canonical
`snapshot -> ledgr_experiment() -> ledgr_run()` path. A reader who enters the
site non-linearly sees two shapes for the same workflow. Add one sentence near
the first `ledgr_backtest()` call making the fixture role explicit:

> This article uses `ledgr_backtest()` as a compact fixture helper for
> hand-checkable accounting examples. The canonical research workflow remains
> `snapshot -> ledgr_experiment() -> ledgr_run()`, as shown in Getting Started.

**Homepage framing**

Add the following line to the homepage, near the canonical workflow diagram.
It is the clearest single-sentence description of why the setup exists:

> The setup is not overhead. The setup is the audit trail.

**Leakage wrong/right example**

Add a pkgdown-only article or a focused section in `strategy-development`
showing a seductive vectorized leakage pattern alongside the ledgr equivalent:

```r
# Wrong: lead() reads tomorrow's close at decision time
bars |>
  mutate(signal = lead(close) / close - 1 > 0)

# ledgr: the strategy has no object from which it can read tomorrow's close
strategy <- function(ctx, params) {
  targets <- ctx$flat()
  for (id in ctx$universe) {
    if (ctx$close(id) > ctx$open(id)) targets[id] <- params$qty
  }
  targets
}
```

The closing line should be: "The ledgr strategy has no object from which it
can accidentally read tomorrow's close." This makes the pulse model emotionally
obvious rather than only architecturally described.

**Feature-map authoring UX**

Promote the design in `inst/design/ledgr_feature_map_ux.md` into this release.
The goal is to remove stringly typed feature lookup from ordinary strategy code
without adding a second execution path.

Minimum user shape:

```r
features <- ledgr_feature_map(
  rsi = ledgr_ind_ttr("RSI", input = "close", n = 14),
  bb_up = ledgr_ind_ttr("BBands", input = "close", output = "up", n = 20)
)

strategy <- function(ctx, params) {
  targets <- ctx$hold()
  for (id in ctx$universe) {
    x <- ctx$features(id, features)
    if (passed_warmup(x) && x[["rsi"]] > 50 && ctx$close(id) > x[["bb_up"]]) {
      targets[id] <- params$qty
    }
  }
  targets
}
```

The same `features` object should be accepted by
`ledgr_experiment(features = features)` for registration and by
`ctx$features(id, features)` for pulse-time lookup. Plain `list()` feature
registration remains supported.

The first version includes `ledgr_feature_map()`, `ctx$features()`, and
`passed_warmup()`. It does not add feature roles, selectors, `prep()`, `bake()`,
wide feature tables, or any general preprocessing pipeline.

### Auditr-Driven Scope

The v0.1.7.3 auditr report found no high-severity ledgr theme. The package is
holding, but the installed-package experience still has repeated documentation
and discovery friction. v0.1.7.4 should resolve or explicitly defer every
ledgr-side finding:

- replace visible vignette calls to hidden `article_utc()` helpers with
  exported `ledgr_utc()`;
- investigate the CSV snapshot import/seal metadata workaround report and fix
  or document the supported path;
- add first-contact article links and local examples for strategy helper and
  helper value-type help pages;
- document readable feature aliases, multi-output feature IDs, and
  parameter-grid feature registration;
- extend zero-trade and warmup diagnosis with short-data and per-instrument
  preflight checks;
- make TTR dependency, multi-output columns, MACD argument matching, and pulse
  snapshot prerequisites explicit;
- remove or rewrite non-runnable first-path examples and stale installed-doc
  navigation;
- record the auditr `DOC_DISCOVERY.R` `n = Inf` issue as an auditr-side
  follow-up, not a ledgr package API requirement.

### Non-Goals

- No execution behavior changes.
- No new exported API outside the narrow feature-map authoring surface.
- No sweep/tune APIs.

### Definition of Done

- `ledgr_backtest()` fixture role is explicit in `metrics-and-accounting`.
- Homepage carries the "setup is the audit trail" framing.
- Leakage wrong/right example exists as an article or vignette section.
- `ledgr_feature_map()`, `ctx$features()`, and `passed_warmup()` are implemented,
  documented, and tested against the existing strategy target-vector contract.
- Plain `features = list(...)` registration remains supported.
- All ledgr-side auditr report findings are either resolved or explicitly
  deferred with a rationale.
- Stale installed `ttr-indicators` artifacts are absent or justified by an
  explicit documentation-contract change.
- No new R CMD check warnings or notes.
- Ubuntu and Windows CI are green.

---

## v0.1.7.5 - Indicator, Diagnostics, And Documentation Hardening (DONE)

**Goal:** Resolve the v0.1.7.4 follow-up work and harden the user-facing
research workflow before returning to persistence architecture and sweep-mode
preparation.

This release converted the external-review and auditr feedback into concrete
package behavior, documentation, and contract tests. It kept the execution model
unchanged: all strategies still flow through sealed snapshots, feature
precomputation, no-lookahead pulse execution, event-sourced accounting, and
durable experiment-store runs.

### Scope

- Correct TTR warmup contracts, including MACD's full signal-EMA warmup, and
  add parity coverage across the supported TTR adapter surface.
- Add diagnostics and documentation for impossible warmup and zero-trade runs.
- Expand result-inspection documentation so users can see equity, fills, trades,
  ledger events, metrics, and summaries in one coherent workflow.
- Document the low-level CSV snapshot create/import/seal/load/run path.
- Improve helper and feature-map discoverability, including parameterized
  feature-registration guidance for future sweeps.
- Add ecosystem positioning: ledgr is a ports/adapters architecture around a
  deterministic core, not a replacement for the broader R finance ecosystem.
- Record release-CI lessons from Ubuntu/DuckDB failures in the playbook and
  contracts.

### Definition of Done

- MACD and other supported TTR indicators have deterministic warmup contracts
  and regression tests.
- Zero-trade warmup diagnostics are visible but non-fatal.
- The primary vignettes explain result inspection, CSV snapshots, warmup
  troubleshooting, helper usage, and ecosystem positioning.
- Documentation contract tests protect installed article links and headless
  discovery paths.
- Ubuntu and Windows CI are green.

---

## v0.1.7.6 - DuckDB Persistence Architecture Review

**Goal:** Make DuckDB persistence boring across Windows, Ubuntu, pkgdown, and
CI before v0.1.8 adds sweep-mode pressure around the execution core.

v0.1.7.5 proved that Ubuntu CI can expose real persistence design issues even
when Windows appears green. The response must be deliberate architecture work,
not release-gate surgery. This milestone audits and consolidates ledgr's DuckDB
connection, transaction, checkpoint, schema-validation, and fresh-read
contracts so future releases can keep platform parity without long CI-debugging
sessions.

### Scope

- Produce a connection-lifecycle map for all public DuckDB entry points:
  snapshot creation/loading, experiment runs, run-store discovery, result
  access, metadata mutation, and vignette/pkgdown examples.
- Produce a mutating-API checkpoint matrix:
  every public function that writes durable state must state whether it
  checkpoints before returning, why, and which fresh-connection read path proves
  it.
- Audit all direct `DBI::dbConnect()`, `dbDisconnect()`, `CHECKPOINT`,
  transaction, temporary view, and `duckdb_register()` paths.
- Confirm whether every connection open should go through a single helper, or
  document the few allowed exceptions.
- Keep runtime schema creation and validation read-only with respect to data
  rows in ledgr tables, except deliberate schema migration or DDL.
- Keep constraint-enforcement probes out of runtime validators; enforcement
  belongs in isolated tests with disposable DuckDB connections.
- Verify DuckDB metadata assumptions, including `duckdb_constraints()` output
  shape, and document how DuckDB version upgrades are checked.
- Review residual lifecycle decisions from the v0.1.7.5 post-release review:
  runner checkpoint strictness, redundant shutdown ownership, and
  `duckdb_constraints()` expression-format dependency during DuckDB upgrades.
- Curate the v0.1.7.5 auditr retrospective and triage report into a routing
  artifact. Only pull findings into v0.1.7.6 when they directly affect DuckDB
  persistence, low-level CSV snapshot workflows, sealed metadata inspection, or
  fresh-connection release-gate verification.
- Define a small local WSL/Ubuntu parity gate that exercises the historically
  fragile paths without requiring a full release run.
- Update contracts, release playbook, and tests based on the architecture
  review.

### Definition of Done

- A written DuckDB persistence architecture review exists under
  `inst/design/`, with connection ownership, transaction, checkpoint, and
  schema-validation rules.
- `contracts.md` states the final persistence invariants.
- `release_ci_playbook.md` contains the local WSL/Ubuntu parity gate and the
  hard stop rule for Ubuntu-driven release surgery.
- Targeted tests prove:
  - schema validation has no row side effects;
  - constraint enforcement is tested only in isolated disposable databases;
  - completed runs are visible from a fresh connection;
  - snapshot create/import/seal/load works from a fresh connection;
  - the low-level CSV snapshot workflow used by pkgdown works under WSL.
- Any remaining direct DuckDB connection or transaction exception is documented
  with a reason.
- The DuckDB architecture review records explicit decisions for runner
  checkpoint strictness, shutdown ownership, and DuckDB metadata-format upgrade
  checks.
- The v0.1.7.5 auditr retrospective and triage report are routed in a written
  follow-up artifact. `THEME-010` remains excluded from ledgr handoff unless it
  is reframed as auditr harness work, and broad documentation themes are
  deferred to the appropriate later milestone rather than absorbed into
  v0.1.7.6.
- External code review confirms the architecture is sound before the release
  gate.
- Ubuntu and Windows CI are green without broad release-gate infrastructure
  edits.

---

## v0.1.7.7 - Risk Metrics Contract

**Goal:** Define the first small, auditable risk-adjusted metric layer before
v0.1.8 sweep mode needs ranking and scoring criteria.

The current standard metric set covers total return, annualized return,
annualized volatility, max drawdown, trade counts, win rate, average trade, and
time in market. It does not yet include Sharpe ratio or related risk-adjusted
metrics. This milestone decides what ledgr owns directly, what remains
adapter/documentation territory for packages such as `{PerformanceAnalytics}`,
and how those definitions will be reused by comparison and future sweep
workflows.

External ecosystem adapters, including a possible `{talib}` adapter PR, may land
opportunistically when they satisfy ledgr's adapter contracts. They are not
roadmap drivers and must not block this metric milestone or v0.1.8.

### Scope

- Add a documented Sharpe ratio metric or explicitly defer it with a recorded
  rationale.
- Define the return series used for risk metrics. The default candidate is
  adjacent public equity-row returns, matching current volatility semantics.
- Define annualization behavior and reuse ledgr's existing detected
  `bars_per_year` convention unless a deliberate alternative is chosen. The
  design must remain valid for future intraday and tick/pulse frequencies; it
  must not hard-code daily assumptions into metric identity or public semantics.
- Sharpe-style metrics must be implemented over excess returns:
  `excess_return[t] = equity_return[t] - rf_period_return[t]`. The formula must
  consume a pulse-aligned per-period risk-free return vector; a scalar annual
  risk-free rate is only the first provider for that vector, not a special
  formula branch.
- Define risk-free rate handling:
  - default value;
  - scalar vs. time-varying support;
  - units and annualization assumptions.
- Define zero-volatility and near-zero-volatility behavior so flat, constant,
  and tiny samples do not produce misleading infinite values.
- Decide whether additional metrics such as Sortino ratio, Calmar ratio, or
  information ratio are in scope or explicitly deferred.
- Decide whether ledgr owns a minimal core risk metric set, exposes optional
  adapters to established metric packages, or both.
- Use `{PerformanceAnalytics}` as an optional parity oracle where definitions
  match ledgr-owned metrics. Parity tests must skip cleanly when the package is
  absent. A public `{PerformanceAnalytics}` adapter is deferred until the ledgr
  risk metric contract is stable.
- Ensure `summary(bt)`, `ledgr_compute_metrics()`, `ledgr_compare_runs()`, and
  future sweep-ranking design can use the same metric definitions.
- Add independent public-table oracles for any new metrics, following the
  existing metric-oracle pattern.
- Update the metrics-and-accounting documentation with formulas, assumptions,
  edge cases, and examples.
- Add raw numeric companion columns alongside formatted display strings in
  `ledgr_compare_runs()` output. The v0.1.7.5 auditr retrospective showed that
  every agent or user who tries to rank runs programmatically must parse
  formatted percent strings such as `"+5.2%"`. Raw columns (`total_return_num`,
  `max_drawdown_num`, etc.) make ranking composable without brittle string
  parsing. This is a natural addition here because `ledgr_compare_runs()` is
  already in scope for the new risk metric, and sweep mode will need the same
  programmatic ranking surface.
- Close three documentation gaps identified in the v0.1.7.5 auditr retrospective:
  - `?ledgr_snapshot_from_yahoo` must state that the returned handle is already
    sealed.
  - `?ledgr_snapshot_seal` must document that calling seal on an already-sealed
    snapshot handle is idempotent: it returns the existing hash without
    re-sealing or erroring.
  - `?ledgr_snapshot_from_yahoo` must note that `quantmod` may emit harmless
    startup and S3-method-overwrite messages to stderr during Yahoo fetches;
    these do not indicate failure.
- Make `ledgr_extract_strategy(..., trust = FALSE)` more prominent in the
  README and experiment-store documentation as a safe stored-strategy
  provenance inspection path.
- Add the ledgr logo to package-visible documentation assets and display it in
  the GitHub README and pkgdown site.

### Non-Goals

- No full performance-analytics metric zoo.
- No mandatory dependency on `{PerformanceAnalytics}` or other metric packages.
- No public `{PerformanceAnalytics}` adapter in this milestone.
- No FRED, Treasury, ECB, central-bank, or other risk-free-rate data adapters.
- No arbitrary user-supplied risk-free time series until the alignment and
  provenance contract is implemented.
- No sweep, tune, or parallel execution APIs.
- No indicator-adapter work such as `{talib}`.

### Definition of Done

- At least one risk-adjusted metric ships and is tested, or the deferral
  rationale is public and v0.1.8's sweep ranking design is unblocked by another
  explicit scoring mechanism.
- The risk metric contract states exactly which risk-adjusted metrics ship and
  which are deferred.
- Any shipped Sharpe-style metric has documented return-source, annualization,
  risk-free-rate, and zero-volatility semantics.
- Any shipped Sharpe-style metric is computed from excess returns through a
  risk-free-rate provider boundary, even when the first provider is only a
  scalar annual rate.
- Time-varying risk-free rates are explicitly shipped or explicitly deferred;
  they must not be implied by a scalar-only implementation.
- The metric contract records the decision on ecosystem metric interoperability,
  such as `{PerformanceAnalytics}` or equivalent packages.
- Metric definitions are frequency-safe: daily, weekly, intraday, and future
  tick/pulse data must either compute with documented annualization semantics or
  fail/defer loudly rather than silently applying a daily-only convention.
- `ledgr_compute_metrics()` and `summary(bt)` expose the shipped metric
  consistently.
- `ledgr_compare_runs()` includes the new risk metric and exposes raw numeric
  companion columns for all metrics alongside formatted display strings.
- Programmatic ranking of `ledgr_compare_runs()` output does not require string
  parsing.
- Public-table oracle tests independently recompute every shipped risk metric.
- Optional `{PerformanceAnalytics}` parity tests cover matching ledgr-owned
  metric definitions where practical and skip cleanly when the package is not
  installed.
- Zero-trade, flat-equity, constant-return, and short-sample cases are tested.
- Documentation explains that ledgr provides a small auditable metric layer and
  may interoperate with the broader R finance ecosystem rather than replacing
  it.
- `?ledgr_snapshot_from_yahoo` states the returned handle is sealed.
- `?ledgr_snapshot_seal` documents idempotent behavior on already-sealed handles.
- `?ledgr_snapshot_from_yahoo` notes expected `quantmod` stderr messages.
- README and experiment-store documentation show `ledgr_extract_strategy(...,
  trust = FALSE)` as the safe stored-strategy inspection path.
- GitHub README and pkgdown display the ledgr logo from package-visible assets.
- Ubuntu and Windows CI are green.

---

## v0.1.7.8 - Strategy Reproducibility Preflight

**Goal:** Lock the strategy reproducibility-tier contract before v0.1.8 sweep
mode runs user strategies across parameter grids and optional worker processes.

Sweep mode may allow practical Tier 2 strategies, but it must not accept Tier 3
strategies whose behavior depends on unresolved, non-recoverable external state.
This milestone turns the existing provenance-tier concept into a preflight check
with user-facing diagnostics and documentation.

### Scope

- Add a strategy reproducibility preflight for user-written strategy functions.
- Classify strategies as Tier 1, Tier 2, or Tier 3 before execution.
- Accept Tier 1 and Tier 2 strategies for ordinary runs and future sweep mode.
- Reject Tier 3 strategies with a classed error that names unresolved external
  symbols or environment dependencies where possible.
- Treat base R and standard-library references as Tier 1-compatible.
- Treat package-qualified calls such as `pkg::fn()` as Tier 2-compatible.
- Treat unresolved free variables and unqualified external helper calls such as
  `my_helper(ctx)` as Tier 3 unless a future explicit dependency-declaration
  contract upgrades them.
- Use static analysis, initially via `codetools::findGlobals()`, while
  documenting its limits for dynamic dispatch patterns such as `do.call()`,
  `get()`, and dynamically constructed strategies.
- Document hidden mutable state as a known preflight blind spot. Static global
  analysis cannot reliably catch `<<-` assignments or closures that mutate
  captured environments. The vignette must warn that these patterns can produce
  order-dependent sweep results even when symbol resolution appears to be Tier 2.
- Add a reproducibility-tiers vignette that explains:
  - Tier 1 is self-contained and fully reproducible from stored source and
    params;
  - Tier 2 requires user-managed package/environment parity;
  - Tier 3 is not accepted for sweep because worker execution cannot recover
    hidden state reliably.
- Sign off the v0.1.8 fold-core/output-handler boundary as a written contract
  without duplicating the v0.1.8 implementation scope. The sign-off must be
  recorded in `contracts.md` or a design document under `inst/design/`.

### Non-Goals

- No sweep, tune, or parallel execution APIs.
- No strategy dependency declaration API in this milestone.
- No automatic package installation or worker environment management.
- No attempt to prove dynamic dispatch targets statically.

### Definition of Done

- Strategy preflight assigns Tier 1, Tier 2, or Tier 3 before execution.
- Tier 3 strategies fail with a classed error and actionable diagnostics.
- Tier 1 and Tier 2 strategy examples are tested and documented.
- Package-qualified calls are documented as Tier 2, not Tier 3.
- Unqualified external helper dependencies are documented as Tier 3 unless a
  later dependency-declaration contract changes that rule.
- Hidden mutable state patterns such as `<<-` and captured mutable environments
  are documented as unsupported for sweep even when static analysis cannot prove
  them unsafe.
- The reproducibility-tiers vignette explains consequences for ordinary runs,
  future sweep workers, and later production use.
- The preflight API has a stable interface designed so v0.1.8 can invoke it
  directly without v0.1.8-specific tiering parameters.
- Ubuntu and Windows CI are green.

---

## v0.1.7.9 - Strategy Author Ergonomics

**Goal:** Close the remaining strategy-author ergonomics feedback from the
v0.1.7.5 and v0.1.7.7 auditr retrospectives that does not belong in the
risk-metrics or reproducibility-preflight milestones. After those two milestones
stabilise the measurement and correctness surfaces, this milestone improves the
experience of writing and validating multi-instrument strategies from
documentation alone.

This milestone is deliberately placed after v0.1.7.8 and before v0.1.8. One
item — `ctx$all_features()` — is consciously deferred to v0.1.8 and recorded
here so the reasons are available when the fold-core design work begins.

The v0.1.7.7 auditr run added a second source of ergonomics evidence. v0.1.7.8
owns only the reproducibility, leakage-boundary, custom-indicator, and provenance
pieces from that report. The remaining ledgr-owned themes are parked here:
feature-map and ctx accessor discoverability, warmup/current-bar
troubleshooting, first-run entry points, comparison/summary print semantics,
snapshot metadata clarity, and selected helper/error-message UX.

### Scope

- Implement `ledgr_feature_contract_check(snapshot, features)`. The v0.1.7.5
  auditr retrospective showed that every agent or first-time user who needs to
  confirm warmup feasibility before a run must manually combine
  `ledgr_feature_contracts()` (which reports `requires_bars` per feature) with
  `ledgr_snapshot_info()` (which reports only total bar count and instrument
  count). That manual combination is a heuristic: dividing total bars by
  instrument count works only for balanced snapshots where every instrument has
  the same date range. For snapshots where instruments start at different dates
  or contain gaps, the floor is wrong and impossible-warmup cases are
  silently missed.
  `ledgr_feature_contract_check(snapshot, features)` must:
  - query per-instrument bar counts from the sealed snapshot;
  - join them against `ledgr_feature_contracts(features)$requires_bars`;
  - return a data frame with one row per (instrument, feature), with columns
    `instrument_id`, `feature_id`, `requires_bars`, `available_bars`, and
    `warmup_achievable`;
  - be usable as a pre-run validation step and in vignette examples.
- Change `select_top_n()` to return a classed empty result instead of emitting
  a warning when no instruments are selected. The current behavior forces callers
  to write `suppressWarnings(..., classes = "ledgr_empty_selection")` to handle
  the expected no-signal path explicitly. Per the design philosophy
  (§2.6 Explicit over implicit), an expected code path should not require warning
  suppression — the caller should be able to check the result type. The classed
  empty result must be compatible with `weight_equal()` and `target_rebalance()`
  so the helper pipeline continues to work without change. The existing
  `ledgr_empty_selection` class name may be reused as the result class.
- Document the canonical whole-share allocation formula in the
  strategy-development vignette for users who write raw strategies outside the
  helper pipeline:
  `floor(equity_fraction * ctx$equity / ctx$close(instrument_id))`
  This is what `target_rebalance()` does internally. Users who write the momentum
  or other allocation strategies manually need this documented as the correct
  pattern, not an incidental choice.
- Add a strategy-context/accessor reference surface that explains engine feature
  IDs, feature-map aliases, `ctx$feature()`, `ctx$features()`, and accepted
  feature object shapes for `ledgr_experiment()` versus lower-level backtest
  helpers.
- Add first-run entry-point links from primary run/experiment help pages to the
  installed Getting Started article and document config-hash stability
  expectations at the user-facing level.
- Improve warmup/current-bar troubleshooting examples, including how summary
  diagnostics map to feature contract fields and snapshot-specific bar counts.
- Document comparison and summary output semantics: formatted print views versus
  raw numeric columns, summary print/return behavior, and exact-ID helpers when
  tibble output truncates identifiers.
- Improve snapshot metadata and seal lifecycle examples, including
  `ledgr_snapshot_info()` on sealed handles, parsed metadata fields, counts, and
  ISO UTC date formats.
- Review targeted helper, target, and parameter error-message findings from the
  v0.1.7.7 auditr report; promote only item-level findings that raw evidence
  classifies as ledgr UX bugs or durable docs gaps.
- Record the `ctx$all_features()` deferral with full rationale (see below).

### Deferred To v0.1.8: `ctx$all_features(feature_map)`

The v0.1.7.5 auditr retrospective showed that every raw multi-instrument
strategy uses the same imperative per-instrument for-loop:

```r
strategy <- function(ctx, params) {
  targets <- ctx$flat()
  for (id in ctx$universe) {
    x <- ctx$features(id, feature_map)        # per-instrument call
    if (passed_warmup(x) && <condition>) {
      targets[id] <- params$qty
    }
  }
  targets
}
```

This is verbose and not idiomatic R. A vectorized alternative would be:

```r
all_features <- ctx$all_features(feature_map)  # named list by instrument
crossed <- vapply(all_features, function(x) passed_warmup(x) && x[["sma_fast"]] > x[["sma_slow"]], logical(1))
targets[crossed] <- params$qty
```

or even more concise patterns using the named list. **This is parked at v0.1.8,
not implemented here, for the following reasons:**

1. **The `ctx` object shape is defined by the fold core.** The fold core
   extraction in v0.1.8 is the right moment to decide whether `ctx` grows a
   vectorized surface. A naive implementation now — `lapply(ctx$universe,
   ctx$features, feature_map)` with a wrapper — would work but would lock in an
   API before the fold core's internal data layout is settled.

2. **Consistency with `ledgr_precompute_features()`.** In v0.1.8, features are
   precomputed and shared zero-copy across sweep workers via
   `ledgr_precompute_features()`. The precomputed object carries per-instrument
   feature matrices indexed by instrument and pulse. `ctx$all_features()` and
   `ledgr_precompute_features()` both give the strategy access to the same
   underlying data; they should use the same shape and naming conventions. If
   `ctx$all_features()` is designed before the precomputed-features interface is
   finalized, the two surfaces risk being inconsistent.

3. **The helper pipeline already solves the most common case.** `signal_return()`
   → `select_top_n()` → `weight_equal()` → `target_rebalance()` abstracts the
   per-instrument loop entirely and produces more readable strategy code for the
   common ranking-and-weighting pattern. The vectorized ctx accessor primarily
   benefits raw strategies with custom per-instrument logic that the helper
   pipeline cannot express. That is a real use case, but not urgent enough to
   justify designing the API before the fold core is stable.

**When v0.1.8 opens:** revisit whether `ctx$all_features(feature_map)` returns
a named list (one element per instrument, each a named numeric vector of feature
values) or a wide data frame (rows = instruments, columns = feature aliases).
The named-list form is more consistent with `ctx$features(id, feature_map)`; the
data frame form is more convenient for `dplyr`-style filtering. The decision
should be made in the context of how `ledgr_precompute_features()` structures its
output, since strategies in sweep mode may eventually receive feature data through
the same channel.

### Non-Goals

- No sweep or parallel execution APIs.
- No change to the `function(ctx, params)` strategy signature.
- No automatic warmup repair or imputation.
- No `ctx$all_features()` — deliberately deferred to v0.1.8.

### Definition of Done

- `ledgr_feature_contract_check(snapshot, features)` is implemented, exported,
  and documented; it returns per-instrument bar counts, `requires_bars`, and
  `warmup_achievable` flags; it is used in at least one vignette example.
- `select_top_n()` returns a classed empty result when no instruments are
  selected; callers can check the result class explicitly; the helper pipeline
  (`weight_equal()`, `target_rebalance()`) handles the classed empty result
  without change; the `suppressWarnings(classes = "ledgr_empty_selection")`
  pattern is no longer required.
- The canonical whole-share allocation formula is documented in the
  strategy-development vignette.
- The `ctx$all_features()` deferral rationale is recorded in this roadmap entry
  and referenced in the v0.1.8 section.
- Ubuntu and Windows CI are green.

---

## v0.1.8 - Lightweight Parameter Sweep Mode

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
  -> share (e.g., mori zero-copy pending SPIKE-3; plain R objects otherwise)
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
`ledgr_run()` and `ledgr_sweep()` call. Implementing `ledgr_sweep()` by
copying the runner and deleting DuckDB calls is explicitly prohibited because
that path leads to silent parity drift.

### Strategy Contract

Sweep mode requires sweep-compatible strategies:

```text
sweep-compatible strategy =
  function(ctx, params)         # functional, explicit params
  + no DuckDB side effects      # no reads/writes to the run store
  + Tier 1 or Tier 2 reproducibility
  + no Tier 3 unresolved external state
```

R6 strategies are excluded from sweep mode in the initial implementation unless
they can be freshly instantiated per parameter set with no shared state. Sweep
mode fails loudly with a clear error for non-compatible strategies.

Sweep inherits the v0.1.7.8 strategy reproducibility preflight. Tier 1
strategies are fully self-contained. Tier 2 strategies are accepted when their
external package/environment requirements are explicit enough for users to
manage on workers, for example package-qualified calls such as `pkg::fn()`.
Tier 3 strategies are rejected before execution.

### Context API: Resolve `ctx$all_features()` Deferral

v0.1.7.9 deliberately parked `ctx$all_features(feature_map)` here. The
outstanding design question is: should `ctx` grow a vectorized surface that
returns feature values for all instruments at once, and if so, what shape should
it take?

This must be resolved when the fold core is extracted. The fold core defines
exactly what `ctx` is — its shape, what data it carries at each pulse, and how
sweep workers receive it. `ctx$all_features()` is a question about that shape.

The two candidate shapes are:

- **Named list** — `list(AAPL = c(sma_fast = 101.2, sma_slow = 99.8), MSFT = ...)`.
  Consistent with `ctx$features(id, feature_map)`, easy to iterate with
  `vapply()`.
- **Wide data frame** — rows = instruments, columns = feature aliases.
  More convenient for `dplyr`-style filtering and ranking; closer to how
  `ledgr_precompute_features()` might structure its output.

The decision should be made in the context of `ledgr_precompute_features()`.
If precomputed feature matrices are exposed as wide per-instrument slices, the
ctx accessor should follow the same convention so strategies written for ordinary
runs and strategies written to consume precomputed features use the same mental
model. If they diverge, document why.

If `ctx$all_features()` is implemented in this milestone, it must also be
reflected in the fold-core parity contract: the same result from
`ctx$all_features()` in a `ledgr_run()` context and from the equivalent access
pattern in a sweep worker context.

### Deterministic Random State

Every backtest and sweep run is fully deterministic by default. Strategies that
use randomness (Monte Carlo sizing, stochastic optimisers, random tie-breaking)
must produce the same output for the same inputs without user intervention.

`ledgr_run()` and `ledgr_sweep()` accept an optional `seed` argument:

```r
ledgr_run(..., seed = NULL)   # NULL derives default from run_id
ledgr_run(..., seed = 42)     # explicit override
ledgr_run(..., seed = NA)     # explicit opt-out: non-deterministic

ledgr_sweep(..., seed = NULL) # NULL derives default from sweep candidate label
ledgr_sweep(..., seed = 42)   # explicit override; same seed for every combination
ledgr_sweep(..., seed = NA)   # explicit opt-out: non-deterministic
```

When `seed = NULL`, the effective seed is derived deterministically but the
source differs by function: `ledgr_run()` derives it from `run_id`;
`ledgr_sweep()` derives it from the sweep candidate label -- the name supplied
to `ledgr_param_grid()`, or the auto-hash label for unnamed entries. This means
the same params always produce the same random draws regardless of the order
they appear in the grid. When `seed = NA`, no seed is set and random draws are
non-deterministic; this is an explicit user choice, not the default.

The engine calls `set.seed(seed + pulse_index)` before each pulse callback.
This gives each pulse an independent, deterministic random state. The
pulse-specific seed is exposed as `ctx$seed` for strategy inspection or
logging.

The effective seed is stored in `config_json` and included in `config_hash`.
Two runs that differ only by seed produce different config hashes, which is
correct: they are different experiments. `ledgr_run_info()` surfaces the seed.

Parity between `ledgr_run()` and `ledgr_sweep()` extends to random state:
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

`precomputed_features` is a typed object, not a raw list. It is built from a
`ledgr_experiment` and the param grid so ledgr can automatically derive the
required indicator configurations:

```r
features <- ledgr_precompute_features(exp, param_grid)

# With explicit date range -- defaults to full snapshot range
features <- ledgr_precompute_features(exp, param_grid, start = "2016-01-01", end = "2021-12-31")

results <- exp |>
  ledgr_sweep(param_grid, precomputed_features = features)
```

The object carries: `snapshot_hash`, universe, `start`/`end` range, indicator
fingerprints, feature-engine version, and feature matrices. `ledgr_sweep()`
fails loudly if the feature object does not match the experiment snapshot, date
range, universe, or indicator set.

When `features` in `ledgr_experiment()` is `function(params) list(...)`, the
precompute step evaluates it for every unique indicator configuration across
the param grid and deduplicates by fingerprint. Combinations that share the
same indicators pay the compute cost once.

Indicator parameters are first-class sweep parameters. A grid that varies
`sma_n`, `rsi_n`, or another indicator adapter argument is represented as an
ordinary `ledgr_param_grid()` plus `features = function(params) ...`; v0.1.8
does not add a separate indicator-sweep API. The sweep result must retain both
the original params and the resolved per-candidate feature fingerprints so a
candidate with different feature construction is not conflated with a candidate
that only differs in strategy thresholds.

Warmup feasibility is also candidate-specific when features are parameterized.
A short training snapshot may support `sma_n = 20` and reject or flag
`sma_n = 200`. `ledgr_precompute_features()` and `ledgr_sweep()` must validate
coverage against each candidate's resolved feature set and the union of all
feature fingerprints requested by the grid.

If `start` and `end` are `NULL`, `ledgr_precompute_features()` computes the full
sealed snapshot range. A sweep may request the same range or a narrower covered
range; it must fail if the requested pulse range or warmup requirements are not
covered by the feature object.

### Performance Expectations

Sweep mode is not vectorbt-style instant matrix sweeps. It is the same
simulation with a cheaper output path. Expected gains over `ledgr_run()`:

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
  ledgr_precompute_features(exp, param_grid)
)

# Sweep -- ledgr_sweep() respects the active future plan
results <- exp |> ledgr_sweep(param_grid, precomputed_features = features)
```

- **future.mirai / mirai** -- `future` backend over persistent mirai workers;
  executable examples must be checked against current package APIs before
  publication
- **mori** -- OS-level shared memory via ALTREP; feature series shared
  zero-copy across all workers; mori objects are transparent at the ledgr API
  boundary, but cross-process serialization behavior with mirai's NNG layer
  requires explicit verification before this pattern is documented as working
  (see `inst/design/ledgr_parallelism_spike.md`, SPIKE-3)

ledgr takes no hard dependency on any of these. `ledgr_sweep()` respects a
`future` plan if set by the user; otherwise runs sequentially. mirai is
`Suggests` at most, conditional on platform spike results. mori is not a
declared dependency until cross-process shared-memory access is confirmed on
Windows and Ubuntu. The `precomputed_features` interface accepts normal R
objects; the mori zero-copy path is an optional user-configured optimization,
not a ledgr API contract.

The platform viability and serialization assumptions underlying this parallel
pattern are verified by the spikes at `inst/design/ledgr_parallelism_spike.md`.
All five spikes must complete before the v0.1.8 parallel design is finalized.

### Implementation Note

**Dead equity tracking — completed in v0.1.7.9 (LDG-1910).** The six
pre-allocated `eq_*` arrays (`eq_cash`, `eq_positions_value`, `eq_equity`,
`eq_ts`, `eq_realized`, `eq_unrealized`) and the live-loop FIFO lot-accounting
that fed them have been removed from `backtest-runner.R`. The resume-replay
lot-accounting that shared the same `lot_map`/`kahan_add` structures was also
removed because it exclusively fed those dead arrays. The authoritative equity
and P&L output is the post-run derived-state reconstruction; that path is
unchanged.

**Remaining fold-core extraction work for v0.1.8.** The dead-array cleanup is
done. The outstanding work is the output-handler boundary split: `fail_run` and
`write_persistent_telemetry` are closures that capture the DuckDB `con` from the
outer runner frame and currently prevent a clean fold-only path. Moving them out
of fold scope, and routing telemetry through the result/output-handler path
instead of `.ledgr_telemetry_registry`, is the concrete v0.1.8 refactor that
enables a sweep candidate to evaluate without a live DuckDB connection or
persistent-run status mutation.

### Pre-Spec Prerequisite: Parallelism Spike

Before the v0.1.8 spec packet is opened, the five spikes at
`inst/design/ledgr_parallelism_spike.md` must produce recorded findings. The
spike results determine: mirai dependency classification (`Suggests` vs.
user-managed), whether the mori zero-copy pattern is documented as working,
whether workers use pre-fetched bar data or per-worker read-only DuckDB
connections, and whether the daemon cache-warming optimization is real. Any of
these that remain unresolved will require mid-spec decisions that carry higher
revision risk.

The spikes do not block v0.1.7.9 or v0.1.7.x patch work. They are a
prerequisite for the v0.1.8 spec cut, not for the current release cycle.

### Definition of Done

- `ledgr_sweep()` and `ledgr_run()` produce identical results on the same
  input: equity curve, trades, fills, final positions, cash, fill timing,
  warmup behaviour, fee model, long-only enforcement, and random draws
- Parity is enforced by CI, not by convention
- Both functions call the same internal fold core; no copied runner code
- `write_persistent_telemetry` and `fail_run` do not capture the DuckDB
  connection from fold scope; telemetry travels through the output-handler
  path, not `.ledgr_telemetry_registry`
- `ledgr_precompute_features()` is implemented, typed, and validates against
  the requesting sweep call
- Indicator-parameter sweeps are supported through `features = function(params)`;
  candidate results retain per-candidate feature fingerprints, and validation
  covers the union of all feature fingerprints requested by the param grid
- Strategy compatibility contract is enforced with clear errors
- Failed combinations produce result rows with `status = "FAILED"`,
  `error_class`, `error_msg`, and `NA` metric columns; `stop_on_error = FALSE`
  is the default; `stop_on_error = TRUE` aborts on first error
- `ledgr_sweep_results` S3 print method follows the same conventions as
  `ledgr_comparison` (curated columns, percentage formatting, footer), and its
  metric columns are chosen from the v0.1.7.7 risk metric contract rather than
  redefined locally
- `params` list column in results enables clean candidate promotion:
  `results |> slice(1) |> pull(params) |> first()` passes directly to `ledgr_run()`
- Warning emitted when grid exceeds the threshold size and no precomputed
  features are supplied
- Single-process sweep is documented with a working example
- Recommended parallel stack is documented separately as optional guidance;
  not part of first-release user docs
- Default seed derivation from grid label is documented and tested; the spec
  states explicitly whether derivation happens inside the fold core, in the
  sweep dispatcher before dispatch, or in the output handler
- `ctx$seed` is available at every pulse in both run and sweep modes
- Explicit `seed = NA` opt-out is documented with a clear warning about
  non-determinism
- `ledgr_tune()` is explicitly out of scope for this milestone; it is a candidate post-v0.1.8 convenience wrapper once the fold core is stable, not an indefinite deferral

---

## v0.1.8.1 - Reference Data And Risk-Free Rate Adapters

**Goal:** Add reproducible non-price reference data series, starting with
risk-free-rate sources, so risk metrics can use real rate curves without
changing the metric semantics defined in v0.1.7.7.

This milestone is deliberately after sweep mode. v0.1.7.7 reserves the internal
excess-return contract so scalar risk-free rates and future pulse-aligned rate
series feed the same metric engine. This release adds the data-provider layer.

### Scope

- Design reference-data adapters for risk-free-rate sources such as FRED,
  Treasury, ECB, or other central-bank data.
- Snapshot external rate series with source identity, retrieval/vintage
  metadata, currency/region, and query parameters.
- Align rate observations to ledgr pulse calendars with documented
  forward-fill, interpolation, or missing-value policy.
- Convert external rate quotes into pulse-aligned per-period risk-free returns
  consumed by the v0.1.7.7 metric contract.
- Define whether and how reference-rate series affect snapshot hashes, config
  hashes, and run identity.
- Document how scalar risk-free rates, adapter-backed curves, and missing-rate
  cases differ.

### Non-Goals

- No broad macro-data warehouse.
- No live broker or live market-data integration.
- No change to the Sharpe-style metric formula defined in v0.1.7.7.

### Definition of Done

- At least one risk-free-rate source adapter is implemented or all adapters are
  explicitly deferred with a documented reason.
- Adapter-backed rate series align to pulse calendars before metric computation.
- Provenance and run-identity implications are documented and tested.
- Risk metrics consume the same pulse-aligned excess-return contract used by
  scalar rates.
- Ubuntu and Windows CI are green.

---

## v0.1.9 - Target Risk Layer

**Goal:** Add a first-class, composable risk transform between strategy target
outputs and fill simulation. Risk is not part of the strategy; it is a separate
layer that constrains what the fill model receives.

### Scope

#### Risk Function Contract

- `risk` argument added to `ledgr_experiment()`. Default is `NULL`, equivalent
  to `ledgr_risk_identity()`.
- The execution path at every pulse is:
  ```text
  strategy(ctx, params)           -> targets_raw
  risk(targets_raw, ctx, params)  -> targets_risked
  fill_model(targets_risked, state) -> trades
  ```
- Contract: `function(targets, ctx, params) -> targets` where `targets` is the
  named numeric vector from the strategy. The return must be a named numeric
  vector of the same shape.
- `risk = NULL` is the default and is stored as `null` in `config_json`. Two
  runs that differ only in risk configuration produce different `config_hash`
  values.

#### Helpers

**`ledgr_risk_identity()`** -- returns targets unchanged. Equivalent to
`risk = NULL`. Useful for explicit documentation in experiment code.

**`ledgr_risk_compose(...)`** -- chains multiple risk functions in order, each
receiving the output of the previous. `ledgr_risk_compose()` with no arguments
returns `ledgr_risk_identity()`.

**Cross-pulse stateless helpers** -- these read `targets` and current `ctx`
state (prices, positions). They do not require cross-pulse historical state such
as equity peaks, trailing volatility, or prior losses.

- `ledgr_risk_no_short()`: zero any negative target quantities
- `ledgr_risk_max_weight(max)`: cap any single instrument's implied portfolio
  weight; uses `ctx$close()` for weight estimation
- `ledgr_risk_max_gross_exposure(max)`: cap total gross exposure; uses
  `ctx$close()`
- `ledgr_risk_max_net_exposure(max)`: cap net exposure; uses `ctx$close()`
- `ledgr_risk_min_trade_value(min)`: zero targets that would generate trades
  below a minimum estimated value; uses `ctx$close()`

All weight and exposure helpers compute implied weights from current close prices
and current portfolio value. The Rd documentation states this assumption
explicitly for each helper. Actual fill values may differ under next-open
execution.

#### Explicit Semantics

- **Returning all-zero targets means liquidation**, not halting. Zero targets
  drive the fill model to close all positions.
- **There is no HALT sentinel in v0.1.9.** Risk functions that want to hold
  current positions should return `ctx$hold()`. This is already expressible
  without a special sentinel.

#### Parity Contract Extension

The fold-core parity contract from v0.1.8 is extended to cover risk:

> `ledgr_run()` and `ledgr_sweep()` must apply identical risk transforms for
> identical snapshot, strategy, params, opening, execution, and risk.

This is documented in `contracts.md`.

#### Experiment Print

`print.ledgr_experiment()` includes a risk summary line:

```text
Risk: identity
```

or

```text
Risk: composed[no_short, max_weight(10%), max_gross_exposure(100%)]
```

### Non-goals

- No order interception or order-level risk events in the ledger
- No broker-aware risk (margin constraints, account-level position limits)
- No stateful helpers requiring cross-pulse historical state -- `ctx` does not
  yet expose equity curve, drawdown, or trailing volatility
- No persisted risk-event ledger (risk decisions are not recorded as ledger
  events)
- No HALT or hold sentinel -- use `ctx$hold()` directly

### Definition of Done

- `risk` argument accepted and validated by `ledgr_experiment()` at
  construction time; non-function values are rejected with a clear error
- Risk transform is applied every pulse between strategy output and fill model
- `ledgr_risk_compose()` with no arguments returns identity; tested explicitly
- All stateless helpers implemented, tested, and documented with explicit price
  assumption caveats in Rd
- `ctx$hold()` documented as the correct pattern for hold-current-positions
  risk behavior
- `print.ledgr_experiment()` includes risk summary
- Parity contract extended and documented in `contracts.md`
- `ledgr_run()` and `ledgr_sweep()` produce identical results under identical
  risk configurations; verified by parity tests
- `R CMD check --no-manual --no-build-vignettes` passes with 0 errors and
  0 warnings
- Coverage gate passes

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

## v0.2.x - Snapshot Lineage And Roll-Forward Data Sources

**Goal:** Bridge immutable research snapshots to operational EOD workflows
without making sealed snapshots mutable.

This milestone is intentionally parked for later design. It exists because the
paper/live path needs an appendable market-data story before users connect
ledgr to real broker workflows. Sealed snapshots remain immutable; the
appendable data source lives outside the snapshot.

### Scope

- Define the distinction between:
  - appendable market-data sources;
  - immutable as-of snapshots;
  - derived run/features/results artifacts.
- Snapshot roll-forward workflow:
  - prior sealed snapshot plus new EOD bars;
  - new immutable snapshot with a new hash;
  - lineage metadata such as parent snapshot hash, appended date range, and
    data-source provenance.
- Separate warmup history from decision/trading range so production-style EOD
  runs can start with fully warmed indicators instead of waiting from
  deployment day.
- Preserve sealed-snapshot reproducibility while making daily data refreshes
  ergonomic.

### Non-goals

- No mutation of sealed market-data artifacts.
- No live broker data adapter in this milestone.
- No paper trading execution.

### Definition of Done

- Users can create a new as-of snapshot from an existing sealed snapshot plus
  new bars without changing the parent snapshot.
- Snapshot lineage is inspectable.
- Runs can distinguish the feature warmup/history range from the decision
  range.
- The workflow is documented as the bridge from research snapshots to paper
  trading.

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

## Deferred Strategy Families (After Research-To-Paper Arc)

These milestones are valuable, but they are deliberately parked until the
research-to-paper-trading arc is proven. They should not block risk metrics,
sweep mode, target risk, OMS simulation, paper trading, or observability.

They may be promoted back into the active roadmap only when the relevant data
model, accounting model, execution semantics, and provenance contract are clear.
The "formerly v0.1.x" labels are historical provenance only; they do not reserve
future version numbers.

### Portfolio Optimization Support (deferred; formerly v0.1.10)

**Goal:** Make portfolio optimization a first-class research workflow in ledgr.

An optimizer is a strategy that computes target weights mathematically rather
than by rules. The strategy contract already supports this output; what is
missing is the tooling that makes writing optimizer strategies natural rather
than awkward.

ledgr is the harness, not the solver. The optimization math stays external
(quadprog, CVXR, PortfolioAnalytics, or any other solver the user chooses).
ledgr provides the clean inputs and the clean output conversion so that plugging
in a solver feels like one function call, not an exercise in data wrangling.

#### Scope

##### Context Accessors

- `ctx$returns_matrix(lookback)` -- a numeric matrix of shape
  `instruments x time` covering the lookback window, ready for covariance
  estimation or any return-based optimization input. Respects the no-lookahead
  guarantee: only bars available at the current pulse are included.
- `ctx$weights_to_targets(weights)` -- converts a named weight vector
  (e.g. `c(SPY = 0.6, TLT = 0.4)`) to share quantities using current equity
  and close prices. Validates that weights sum to at most 1 and that all names
  are in `ctx$universe`.

##### Vignette

A worked vignette demonstrating the full research workflow:

1. Write a mean-variance strategy using `ctx$returns_matrix()` and an external
   solver.
2. Sweep over lookback window and risk-target combinations using
   `ledgr_precompute_features()` and `ledgr_sweep()`.
3. Persist the winning configuration with `ledgr_run()` and label it in
   the experiment store.
4. Compare runs with `ledgr_compare_runs()`.

The vignette is the primary deliverable -- the context accessors exist to make
it readable.

##### Reproducibility Note

Strategies that call external solvers (quadprog, CVXR) reference package
functions that are outside the base-R namespace. These strategies are classified
Tier 2 (source captured, replay requires solver package). This is documented
explicitly in the vignette and in `ledgr_run_info()` output.

#### Definition of Done

- A mean-variance strategy can be written in under 30 lines of strategy code
  using `ctx$returns_matrix()` and a standard solver
- `ctx$weights_to_targets()` handles weight-to-quantity conversion correctly
  under edge cases: zero equity, missing prices, weights that do not span the
  full universe
- The sweep-to-persist-to-compare workflow is demonstrated end-to-end in the
  vignette against the canonical demo dataset
- `ctx$returns_matrix()` is covered by no-lookahead tests

---

### Calendar And Event-Driven Strategies (deferred; formerly v0.1.11)

**Goal:** Give strategies a structured temporal context so calendar and
event-driven logic does not require manual date arithmetic inside the strategy
function.

Calendar strategies are among the most common in systematic research --
month-end rebalancing, quarter-end drift correction, regime detection by
calendar period. Today a ledgr strategy can read `ctx$ts_utc` and compute
everything manually, but every user rewrites the same boilerplate. A thin
calendar layer eliminates that without adding hidden state or breaking the
no-lookahead guarantee.

#### Scope

##### Calendar Context Accessors

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

##### Rebalance Throttle Helper

- `ctx$calendar$periods_since_rebalance(frequency)` where `frequency` is one
  of `"daily"`, `"weekly"`, `"monthly"`, `"quarterly"` -- returns an integer
  count of full periods elapsed since the last pulse on which the strategy
  returned a non-flat target change. Intended for strategies that want to
  rebalance on a schedule without tracking their own rebalance timestamp.

##### Vignette Extension

Extend the strategy-authoring vignette with a calendar-driven rebalancing
example: a monthly rebalancing portfolio that acts only on month-end pulses and
holds otherwise.

#### Definition of Done

- All calendar accessors are derived from sealed snapshot data with no
  wall-clock calls
- `ctx$calendar$days_since()` is tested against known trading calendars with
  gaps and holidays present in the snapshot
- No-lookahead tests cover calendar accessor paths
- Calendar-driven rebalancing is demonstrated in the strategy-authoring vignette

---

### Pairs And Spread Trading (deferred; formerly v0.1.12)

**Goal:** Make cross-instrument spread strategies natural to write without
manual cross-instrument data assembly inside the strategy function.

Pairs trading and statistical arbitrage are distinct from universe-level
portfolio optimization: they operate on instrument pairs, require spread
z-scores and rolling cointegration residuals, and produce relative rather than
absolute target positions. The returns matrix from v0.1.8 partially addresses
this, but the pair-level spread computation is specific enough to warrant its
own accessor layer.

#### Scope

##### Spread Accessors

- `ctx$spread(id_a, id_b, lookback)` -- the current price spread between two
  instruments, normalized as a rolling z-score over `lookback` bars. Uses
  log-price difference by default; raw difference available via a `method`
  argument.
- `ctx$spread_history(id_a, id_b, lookback)` -- the full lookback window of
  spread values as a numeric vector, for strategies that need to fit a
  cointegration model or compute their own statistics.

Both accessors respect the no-lookahead guarantee and are computed from the
sealed snapshot bars available at the current pulse.

##### Position Helpers

- `ctx$net_exposure(id_a, id_b)` -- the current net dollar exposure of a pair
  as a signed scalar: positive means long `id_a` / short `id_b`, negative
  means the reverse. Simplifies the position-sizing logic common to
  pairs strategies.

##### Vignette

A worked vignette demonstrating a z-score mean-reversion pairs strategy:
entry on spread z-score threshold, exit on reversion to zero, position sizing
using `ctx$net_exposure()`. Sweep over lookback and entry threshold using
`ledgr_sweep()`, persist the winner.

#### Definition of Done

- `ctx$spread()` and `ctx$spread_history()` respect no-lookahead across all
  lookback window sizes
- `ctx$net_exposure()` is consistent with the ledger-derived position state
- A pairs strategy can be written in under 40 lines of strategy code
- The sweep-to-persist workflow is demonstrated in the vignette against the
  canonical demo dataset with at least two instruments

---

## Deferred Interoperability And Reporting Ports

These ports fit ledgr's hexagonal architecture, but they are not prerequisites
for the research-to-paper-trading arc. They may land opportunistically if they
stay thin, optional, and compatible with ledgr's core contracts; otherwise they
wait until the core arc is proven.

### PerformanceAnalytics Reporting Adapter

**Goal:** Add an optional reporting adapter that lets ledgr users pass completed
runs and return streams into `{PerformanceAnalytics}` without changing ledgr's
execution or metric semantics.

This milestone depends on the v0.1.7.7 risk metric contract. It must not define
ledgr's canonical metrics. ledgr-owned metrics remain computed from public
result tables. `{PerformanceAnalytics}` is an optional analysis and reporting
port around that core.

#### Scope

- Export a ledgr return-series conversion helper, such as `ledgr_as_returns()`,
  that derives adjacent equity-row returns from public ledgr result tables.
- Add optional `{PerformanceAnalytics}` examples for completed ledgr runs.
- Add adapter helpers only if they stay thin wrappers over public result tables.
- Support parity checks against ledgr-native metrics where definitions match.
- Document differences in assumptions, sign conventions, risk-free-rate units,
  annualization, geometric vs. arithmetic conventions, and benchmark handling.

#### Non-Goals

- No mandatory `{PerformanceAnalytics}` dependency.
- No replacement of ledgr-native metric computation.
- No metric zoo in core ledgr.
- No mutation of ledgr stores.
- No effect on run identity unless adapter outputs are explicitly persisted in a
  later milestone.

#### Definition of Done

- Users can obtain a `{PerformanceAnalytics}`-compatible return series from a
  completed ledgr run.
- Optional `{PerformanceAnalytics}` examples skip cleanly when the package is
  absent.
- Any adapter-computed metrics clearly identify whether they are ledgr-native,
  `{PerformanceAnalytics}`-native, or parity-checked.
- Documentation explains that this is an interoperability adapter, not the
  source of ledgr's metric contract.
- Ubuntu and Windows CI are green.

### TA-Lib Indicator Adapter

**Goal:** Accept an optional `{talib}` indicator adapter if it arrives as a thin
port that returns ordinary `ledgr_indicator` objects and preserves ledgr's
feature-precompute and no-lookahead contracts.

This work may arrive as an external PR against main. It is welcome, but it must
not drive the release sequence or block the research-to-paper arc.

#### Scope

- Keep `{talib}` optional.
- Use ledgr's indicator adapter boundary and deterministic feature identities.
- Prefer full-series `series_fn()` integration and `{talib}` lookback metadata
  for warmup contracts.
- Restrict initial scope to continuous numeric indicators; charting and
  candlestick-pattern semantics require separate design.

#### Definition of Done

- The adapter produces normal ledgr indicators and appears in
  `ledgr_feature_contracts()` with `source = "talib"`.
- Tests skip cleanly when `{talib}` is absent.
- Direct-output parity and warmup tests cover the supported initial surface.

---

## Deferred Provenance And Artifact Infrastructure

This is not a strategy family. It is provenance infrastructure that becomes
important if ledgr is expected to carry trained-model strategies toward paper
trading. It is deferred for now, but should be reconsidered before v0.3.0 if
ML-based strategies become a target use case for the first paper-trading arc.

### ML Strategy Artifact Management (deferred; formerly v0.1.13)

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

#### Scope

##### Artifact Registry

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

##### Strategy Integration

- `strategy_params` accepts artifact handles as values. An artifact handle
  serializes to its content hash in JSON, making it canonical-JSON-safe and
  hashable. The `strategy_params_hash` therefore changes when the model
  changes, even if no other parameter changes.
- Strategies that load a model via an artifact handle are classified Tier 2
  (source captured, artifact hash recorded, but replay requires the artifact
  file to be present). This is documented explicitly.
- Strategies that load a model by raw file path (bypassing the artifact
  registry) are classified Tier 3.

##### Vignette

A worked vignette: train a classification model offline (e.g. logistic
regression or xgboost), register it as an artifact, write a strategy that
loads and calls it at each pulse, run two experiments with different model
versions, compare run provenance to show the artifact hashes differ.

#### Definition of Done

- A model artifact can be registered and its hash stored as part of run
  identity.
- Two runs using different model versions produce different
  `strategy_params_hash` values even when all other parameters are identical.
- `ledgr_run_info()` displays artifact hashes for runs that reference
  artifacts.
- Tier 2 vs. Tier 3 classification is correctly applied based on whether
  the artifact registry was used.
- The vignette demonstrates the full workflow: train, register, backtest,
  compare.

---

## Deferred Asset-Class And Market-Structure Families

These areas are not rejected; they are parked until the core product has proven
that sealed research data can travel through sweep, target risk, OMS simulation,
paper trading, and observability without changing execution semantics.

- **Shorting, margin, borrow, and leverage** require explicit borrow cost,
  collateral, liquidation, and risk-limit semantics. The current target-risk
  layer should stay long-only or explicitly constrained until those accounting
  rules exist.
- **Futures and rolls** require contract metadata, expiry, margin, roll policy,
  settlement, and continuous-series provenance. They should not be modeled as
  ordinary equities with different symbols.
- **Options and multi-leg derivatives** require Greeks, expiry, assignment,
  exercise, contract multipliers, and multi-leg order semantics. They are
  outside the current ledger and fill model.
- **FX and multi-currency accounting** require currency conversion rates,
  cash ledgers by currency, base-currency reporting, and rate provenance.
- **Crypto exchange support** requires 24/7 calendars, venue-specific fees,
  custody assumptions, and exchange adapter boundaries.
- **Corporate actions** such as dividends, splits, and adjusted/unadjusted
  price policy require explicit data-source and accounting contracts.
- **Order-book, tick, and market microstructure strategies** require data and
  fill assumptions beyond OHLCV bars. They should not be approximated silently
  through daily-bar semantics.
- **Advanced slippage, liquidity, and market-impact models** belong in the
  execution/fill layer, not in ad hoc strategy code.

---

## Permanently Unsupported Patterns

Some patterns are not deferred; they are incompatible with ledgr's core
contract.

- Strategies that require lookahead or future data access.
- Strategies whose result depends on unrecorded wall-clock time, live API calls,
  mutable global state, hidden files, or non-reproducible randomness.
- Claims about intrabar order, queue position, or tick sequencing when the
  sealed input contains only OHLCV bars and the fill model does not state the
  assumption explicitly.
- Human discretionary decisions inside the strategy loop unless those decisions
  are represented as sealed, timestamped input data.

---

## Future Extensions (Explicitly Deferred)

These ideas remain valid but are not part of the active research-to-paper arc
unless a future version promotes them with a concrete contract.

- Intraday / multi-pulse scheduling
- Modular validation zoo:
  - read-only validation suites for data quality, snapshot integrity,
    indicators, strategy outputs, fill assumptions, ledger reconciliation,
    and experiment-store metadata
  - structured validation results with check IDs, severity, affected objects,
    and classed failures/warnings
  - explicit extension mechanism so package or user-defined checks can be
    composed without changing core execution semantics
- Tax-aware accounting (wash sales, lot selection)
- UI / dashboards

---

## Final Note

This roadmap is intentionally strict. If a milestone feels boring, it is
probably correct.
