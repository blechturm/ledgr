# ledgr v0.1.7.2 Spec

**Status:** Draft
**Target Version:** v0.1.7.2
**Scope:** auditr UX stabilisation and strategy helper design
**Inputs:**

- `inst/design/ledgr_v0_1_7_2/ledgr_triage_report.md`
- `inst/design/ledgr_v0_1_7_2/categorized_feedback.yml`
- `inst/design/ledgr_v0_1_7_2/ledgr_strategy_spec.md`
- `inst/design/ledgr_design_philosophy.md`

---

## 1. Purpose

v0.1.7.2 closes the most important issues surfaced by the auditr companion
package against the installed v0.1.7.1 workflow and prepares a strategy-helper
layer for clearer strategy authoring.

This release is not sweep mode. It must not export `ledgr_sweep()`,
`ledgr_tune()`, or sweep dependency declaration arguments.

---

## 2. Release Shape

v0.1.7.2 has two tracks.

### Track A - Auditr UX Stabilisation

Fix or explicitly resolve the recurring installed-package issues found by
auditr:

```text
comparison metrics
installed documentation discovery
first runnable examples
feature ID discovery
strategy examples
warmup and short-history behavior
experiment-store operational guidance
```

### Track B - Strategy Helper Layer

Prepare the helper layer described in `ledgr_strategy_spec.md`:

```text
signal -> selection -> weights -> target -> execution
```

The helper layer must compile back to explicit target quantities before
execution. It must not become a second execution path.

### Track C - Strategy Development Vignette Overhaul

Rewrite the strategy-development vignette as the central teaching document for
strategy authoring in ledgr. The standard is a narrative, worked-learning
chapter: closer to "R for Data Science with a quant focus" than to a reference
page.

The vignette must teach:

- the ledgr mental model from the design document;
- why strategies are ordinary `function(ctx, params)` functions;
- how `ctx` exposes only decision-time state;
- why strategies return target quantities rather than orders, signals, or
  weights;
- how helper functions express economic logic while preserving the target-vector
  execution contract;
- how to use interactive snapshot and pulse debugging to build and understand a
  strategy before running it.

---

## 3. Hard Requirements

### R1 - No Second Execution Path

All implemented strategy helpers must terminate in target quantities consumed by
the existing runner. No helper may bypass `ledgr_run()` or introduce alternate
pulse, fill, ledger, or result semantics.

v0.1.7.2 chooses the explicit wrapper design:

```text
target_rebalance() returns ledgr_target
target_overlay() returns ledgr_target if it ships
ledgr_invalid_strategy_result validation accepts ledgr_target by unwrapping it
to the same full named numeric target vector required today
```

Plain full named numeric target vectors remain valid. `ledgr_target` is a thin
validated wrapper, not a second target representation at execution time.

### R2 - Comparison Metrics Must Be Consistent

`summary()`, `ledgr_compare_runs()`, `ledgr_extract_fills()`, and
`ledgr_results(bt, what = "trades")` must use compatible definitions for trade
and fill counts.

If `n_trades` means closed trades, fills, or round trips, that definition must
be stated in documentation and tested against representative runs.

### R3 - Zero-Row Results Keep Stable Schemas

Flat or zero-trade runs must return zero-row tibbles with the normal column
schema. They must not return `0 x 0` result tables.

### R4 - Installed Documentation Must Be Discoverable Noninteractively

A user or agent working through `Rscript` must have a documented way to discover
and read installed ledgr documentation without relying on a browser.

### R5 - First Examples Must State Suggested-Package Assumptions

Runnable vignettes may use suggested packages such as dplyr and tibble, but they
must state those expectations before code that calls `library(dplyr)` or
`library(tibble)`.

### R6 - Feature IDs Must Be Discoverable Before Use

Examples that use feature IDs in strategies must show the corresponding
`ledgr_feature_id()` call or a compact supported-ID table before the strategy
code relies on those IDs.

### R7 - Warmup And Short-History Behavior Must Be Explicit

Indicator examples must show warmup guards and explain what happens when a
strategy runs on too little history for a registered indicator.

### R8 - Helper Objects Are Intermediate Values

`ledgr_signal`, `ledgr_selection`, and `ledgr_weights` are intermediate helper
objects. Returning them directly from a strategy must fail loudly.

### R9 - Long-Only Until Short Semantics Exist

Negative weights must fail before target construction in v0.1.7.2. Short
selling remains out of scope until ledgr defines explicit short-selling,
margin, and broker lifecycle semantics.

### R10 - Contracts Must Move With Implementation

Track B cannot ship until `contracts.md` is updated to reflect the implemented
helper contract:

- helper pipelines may use weights internally;
- execution still consumes target quantities;
- `ledgr_target` is a valid strategy return type after validator unwrapping;
- signals, selections, and weights are invalid direct strategy returns.

### R11 - Lifecycle Framing Must Reflect Actual Risk

`close(bt)` and `ledgr_snapshot_close(snapshot)` release DuckDB connections held
for result access. They are not required for data safety. Data is durable once
`ledgr_run()` completes because the runner checkpoints and closes its own write
connection.

Documentation must not frame explicit close calls as data-loss prevention. The
correct framing is resource management for long sessions and multi-run workflows
where an open result-access connection can hold a DuckDB lock and block the next
write connection.

Track A8 owns the evaluation of whether result-access operations can use
per-operation read connections instead of cached long-lived connections. If
adopted, explicit close calls become advanced resource-management hints rather
than happy-path cleanup. If deferred, this requirement moves to v0.1.8.

### R12 - Strategy Vignette Is A Teaching Artifact

`vignettes/strategy-development.Rmd` is a central user-facing document, not a
dumping ground for API snippets. It must build a simple strategy step by step,
explain the economic logic of each helper, and show how interactive debugging
confirms what the strategy sees before it is run.

The vignette must distinguish:

- the design mental model;
- runnable installed-package code;
- optional helper-layer examples if Track B ships.

---

## 4. Track A Scope

### A1 - Comparison And Trade Metrics

The auditr report identifies one high-priority confirmed/likely bug:

```text
ledgr_compare_runs() reports n_trades = 0 while fills or summary output show
trading activity.
```

The first implementation task is investigative:

- reproduce the discrepancy in a targeted test;
- identify whether the zero comes from comparison SQL, telemetry, fill/trade
  reconstruction, or metric definition mismatch;
- only then change implementation or documentation.

The resolved implementation must:

- define `n_trades` precisely;
- align `ledgr_compare_runs()` with that definition;
- document how `n_trades` relates to fills, closed trades, and summary output;
- test flat runs, open-only runs, closed round trips, and multi-fill runs;
- ensure zero-row trade results keep the normal schema.

### A2 - Documentation Discovery

Add a stable noninteractive discovery path for installed users. Examples:

```r
vignette(package = "ledgr")
system.file("doc", package = "ledgr")
tools::Rd_db("ledgr")
```

The documentation should explain which path is for browser-oriented interactive
use and which path is reliable in scripts or audit agents.

### A3 - First Runnable Examples

The primary installed workflow must be runnable from a clean installed package
with explicit dependency expectations. If a vignette uses suggested packages,
say so before loading them.

Durable examples that use `tempfile()` must state that `tempfile()` is for a
self-cleaning vignette run, while real research should use a project artifact
path.

### A4 - Feature ID And Indicator Discovery

Improve smooth-path discovery for:

- built-in feature IDs such as returns and SMA;
- TTR IDs such as RSI, BBands, and MACD outputs;
- multi-output indicators.

The preferred first fix is a compact reference table in the TTR vignette and
strategy-development docs that shows common constructors, generated feature IDs,
and multi-output suffixes. New discovery helpers are allowed only if the table
proves insufficient. No fix may introduce aliases that change fingerprint
semantics.

### A5 - Strategy Example Coverage

Add or update examples for:

- SMA crossover;
- two-asset momentum;
- stateful threshold or RSI mean reversion;
- target quantities versus weights;
- `ctx$universe` instead of hard-coded conceptual symbols when the example is
  meant to run against `ledgr_demo_bars`.

Conceptual examples using placeholder IDs such as `AAA` must be labeled as
conceptual.

### A6 - Warmup And Short-History Behavior

Document and test the main warmup patterns:

- known feature with warmup `NA`;
- short dataset with no valid post-warmup value;
- unguarded strategy logic that branches on `NA`;
- post-warmup invalid `NA` from an indicator.

Strategy evaluation errors should be wrapped with useful pulse context where
possible, including timestamp and available feature/instrument context. The
wrapper must preserve the original error as the parent condition.

### A7 - Experiment-Store Operational Guidance

Improve examples for:

- persistent snapshot IDs;
- labels and tags in compare workflows;
- explicit CSV import, seal, load, and backtest;
- corrected handle lifecycle framing:
  - explicit close calls release result-access DuckDB connections;
  - they are not required for data safety after `ledgr_run()` completes;
  - they matter mainly in long sessions that inspect results and then run more
    backtests against the same durable file.

Do not teach `on.exit()` as normal narrative-vignette ceremony. Reserve
defensive cleanup patterns for package-author guidance or long-running script
notes.

### A8 - Result-Access Connection Lifecycle

Evaluate whether result-access APIs can use per-operation read connections
instead of cached long-lived DuckDB connections.

Covered APIs include:

- `ledgr_results()`;
- `ledgr_run_list()`;
- `ledgr_run_info()`;
- `ledgr_compare_runs()`;
- `ledgr_run_open()`;
- `ledgr_extract_strategy()`;
- interactive snapshot/pulse inspection paths where relevant.

The outcome must be one of:

1. implement per-operation read connections for the practical result-access
   paths and remove explicit close calls from happy-path docs; or
2. explicitly defer the change to v0.1.8, list it in the deferred section, and
   keep the corrected long-session close framing in v0.1.7.2 docs.

---

## 5. Track C Scope

### C1 - Teaching Arc

Rewrite `vignettes/strategy-development.Rmd` around a single cumulative example:

```text
idea -> signal -> selection -> sizing -> target -> run -> inspect -> compare
```

The strategy should be simple enough to understand economically, but rich enough
to show multi-instrument decision making, warmup, target construction, and
debugging.

### C2 - Mental Model

The vignette must explain:

- sealed snapshots as the immutable market-data world;
- pulses as the sequence of decision times;
- `ctx` as the decision-time view of that world;
- strategies as pure-ish functions from context and parameters to desired
  holdings;
- target quantities as the handoff to the execution simulator;
- next-open fills as the boundary between decision and execution.

### C3 - Helper Logic

If Track B helper APIs ship, the vignette must introduce them through economic
reasoning:

```text
signal: what do we like?
selection: which instruments do we act on?
weights: how much capital do we want allocated?
target: how many shares does that imply today?
```

If Track B is deferred, the vignette should still teach the same mental model
using explicit `ctx$feature()`, `ctx$flat()`, and target-vector code, with a
short "future helper layer" note pointing to the strategy helper spec.

### C4 - Interactive Debugging

The vignette must show how to use interactive snapshot or pulse debugging to
inspect:

- current universe;
- current bars/prices;
- available features;
- warmup `NA` values;
- the target vector produced by the strategy at a chosen pulse.

The debugging section should support strategy development, not merely list
tools.

### C5 - Quality Bar

The vignette should read as a coherent teaching chapter:

- minimal jargon before examples;
- runnable examples against `ledgr_demo_bars`;
- small code chunks with explanation around them;
- no unexplained cleanup ceremony;
- no conceptual symbols such as `AAA` inside runnable examples;
- clear separation between package-required APIs and suggested-package
  conveniences.

---

## 6. Track B Scope

The helper layer is defined by `ledgr_strategy_spec.md`. v0.1.7.2 may implement
only the minimal reference set needed to prove the design:

- `ledgr_signal`
- `ledgr_selection`
- `ledgr_weights`
- `ledgr_target`
- `signal_return(ctx, lookback = 20)` as the first feature-backed signal
  helper, backed by `ledgr_ind_returns(lookback)` and feature ID
  `return_<lookback>`;
- `select_top_n()`;
- `weight_equal()`;
- `target_rebalance()`;
- optional `target_overlay()` only if `ledgr_strategy_spec.md` explicitly
  defines overlay selection in terms of `ledgr_weights` names and the behavior
  is fully tested.

Anything beyond that is a helper zoo and remains out of scope.

---

## 7. Deferred To v0.1.8

The following remain part of sweep mode, not v0.1.7.2:

- `ledgr_sweep()`
- `ledgr_tune()`
- `ledgr_precompute_features()`
- `strategy_helpers`
- `strategy_packages`
- `strategy_globals_ok`
- worker transport and static dependency packaging
- sweep parity tests

---

## 8. Verification Gates

Before v0.1.7.2 is complete:

- targeted tests cover all comparison metric edge cases;
- zero-row result tables preserve schemas;
- `contracts.md` is updated if Track B ships;
- `ledgr_target` is accepted by the strategy validator, or Track B is explicitly
  deferred and no helper-target API is exported;
- direct strategy returns of `ledgr_signal`, `ledgr_selection`, and
  `ledgr_weights` fail loudly;
- result-access connection lifecycle is resolved by either implementing
  per-operation read connections or explicitly deferring that implementation to
  v0.1.8 in this spec and the roadmap;
- Track B reference strategies live in `tests/testthat/test-strategy-reference.R`
  if helper APIs ship;
- `DESCRIPTION` and `NEWS.md` reflect v0.1.7.2 scope before release;
- documentation examples render;
- `vignettes/strategy-development.Rmd` is reviewed as the central strategy
  teaching artifact and covers mental model, helper logic, and interactive
  debugging;
- no sweep/tune APIs are exported;
- helper objects cannot bypass the existing target validator;
- Ubuntu and Windows CI are green;
- `R CMD check --no-manual --no-build-vignettes` passes.
- Tickets touching executable R code, package metadata, vignettes, pkgdown,
  DuckDB persistence, snapshots, file paths, time zones, encodings, or other
  OS-sensitive behavior run the local WSL/Ubuntu gate before push.
