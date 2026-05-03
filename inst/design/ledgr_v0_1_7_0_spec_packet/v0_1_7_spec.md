# ledgr v0.1.7 Specification - Core UX Overhaul

**Document Version:** 0.1.0  
**Author:** Max Thomasberger  
**Date:** April 28, 2026  
**Release Type:** Public API Reset  
**Status:** **DRAFT FOR REVIEW**

## 0. Goal

v0.1.7 replaces the current `db_path`-first research workflow with a coherent
experiment-first public API.

The release is intentionally breaking. Earlier v0.x cycles preferred additive
changes and deprecations where possible. v0.1.7 explicitly overrides that
posture because the package has no known production users and because carrying
both the old and new public surfaces into sweep mode would create avoidable
long-term complexity.

The target user story is:

```text
I have sealed data.
I define one experiment object.
I run, inspect, compare, label, archive, and recover results without passing
DuckDB paths around after snapshot creation.
```

v0.1.7 is not sweep mode. It is the API foundation that v0.1.8 sweep mode
builds on.

---

## 1. Inputs

v0.1.7 is derived from:

- `inst/design/ledgr_roadmap.md`, section `v0.1.7 - Core UX Overhaul`;
- `inst/design/ledgr_ux_decisions.md`;
- `inst/design/ledgr_sweep_mode_ux.md` for forward compatibility only;
- `inst/design/contracts.md`;
- `inst/design/model_routing.md`;
- the implemented v0.1.6 experiment-store, comparison, strategy-extraction,
  and run-tag APIs.

---

## 2. Hard Requirements

### R1: Intentional API Reset

v0.1.7 is a hard public API reset.

The release must:

- document the break in `NEWS.md`;
- update the compatibility policy and contracts;
- provide a migration guide from v0.1.6 to v0.1.7;
- remove old public workflow signatures from examples and vignettes;
- fail loudly for removed signatures when practical.

Compatibility shims are out of scope unless explicitly approved by a ticket.

### R2: Experiment-First Public Model

`ledgr_experiment()` is the central public object for research execution.

The public workflow becomes:

```r
snapshot <- ledgr_snapshot_from_df(bars, db_path = "research.duckdb")

exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = strategy,
  features = list(...),
  opening  = ledgr_opening(cash = 100000)
)

bt <- exp |> ledgr_run(params = list(...), run_id = "candidate_1")
```

After snapshot creation or `ledgr_snapshot_load()`, users should not pass a
DuckDB path to ordinary research workflow functions.

New-session resumption is part of this model. A user who only has an existing
DuckDB file must recover a snapshot handle first, then continue with
snapshot-first store operations:

```r
snapshot <- ledgr_snapshot_load("research.duckdb", snapshot_id = "demo_2015_2021")
snapshot |> ledgr_run_list()
```

If `ledgr_snapshot_load()` is not the final user-facing name, v0.1.7 must
provide an equivalent `ledgr_snapshot_open()` style API before removing
`db_path`-first store operations.

### R3: `ledgr_run()` Is The Public Single-Run API

`ledgr_run()` replaces `ledgr_backtest()` as the public entry point for a single
research run.

`ledgr_backtest()` may remain as an internal or low-level compatibility helper,
but it must not be the recommended public API in README, vignettes, pkgdown
articles, or examples.

`ledgr_run()` must call the same canonical execution path as existing valid
backtests. It must not fork pulse ordering, fill timing, ledger semantics,
feature semantics, or snapshot semantics.

### R4: `function(ctx, params)` Is The Only Strategy Signature

From v0.1.7 onward, strategy functions must have signature:

```r
function(ctx, params)
```

Rules:

- `params` is always supplied as the second argument.
- Strategies with no tunable parameters receive `params = list()`.
- `function(ctx)` is no longer valid.
- `ctx$params` must not be added.
- unsupported signatures fail with a classed error before execution.

This reset removes ambiguity before v0.1.8 sweep mode.

### R5: Target Constructors Are `ctx$flat()` And `ctx$hold()`

The target-vector helpers are renamed for user clarity:

| Removed | Replacement | Meaning |
|---|---|---|
| `ctx$targets()` | `ctx$flat()` | zero target vector; go flat unless signal |
| `ctx$current_targets()` | `ctx$hold()` | current positions as targets; hold unless signal |

The old helper names must fail loudly with migration guidance. They must not
remain as aliases.

### R6: Snapshot-First Store APIs

Experiment-store operations become snapshot-first or handle-first:

```r
snapshot |> ledgr_run_list()
snapshot |> ledgr_run_info("run_id")
snapshot |> ledgr_run_open("run_id")
snapshot |> ledgr_run_label("run_id", "Label")
snapshot |> ledgr_run_tag("run_id", c("candidate", "v1"))
snapshot |> ledgr_run_archive("run_id", reason = "dominated")
snapshot |> ledgr_compare_runs()
snapshot |> ledgr_extract_strategy("run_id")
```

`db_path`-first public signatures are removed from the documented workflow.
If the old signatures remain callable internally, they must be clearly marked
low-level and excluded from user-facing examples.

### R7: Opening State Is Explicit

`ledgr_opening()` is the explicit starting state for a run. It captures:

- opening date, if supplied;
- cash;
- positions;
- cost basis, if supplied.

Opening cash and positions are represented in the ledger as opening events so
state remains reconstructable from the event stream.

If an opening date is supplied, bars before the opening date may be used for
indicator warmup only. The pulse loop starts at the opening date.

### R8: Close Lifecycle Is Safe By Default

Explicit `close(bt)` remains valid and preferred in examples. Forgetting it must
not silently lose durable run artifacts.

Target behavior:

- `close(bt)` checkpoints immediately.
- durable run handles auto-checkpoint from a finalizer when possible;
- the finalizer emits a one-time informational message;
- in-memory runs require no close;
- tests verify that a forgotten close does not lose a completed durable run.

The GC path is a safety net, not the primary workflow.

### R9: Curated Prints Are Part Of The UX Contract

`ledgr_run_list` and `ledgr_comparison` are tibble-like objects with curated
print methods.

Print methods must:

- show at most 7-8 columns by default;
- format return, drawdown, and win-rate values as percentages in print only;
- keep underlying columns numeric for downstream analysis;
- include footers pointing to detailed APIs such as `ledgr_run_info()` and
  identity/telemetry views;
- omit noisy `NA` fields where possible.

### R10: Demo Data Replaces Inline Bar Construction

v0.1.7 ships a built-in deterministic demo dataset and a public simulator:

```r
ledgr_demo_bars
ledgr_sim_bars(...)
```

All README and vignette examples should use these instead of hand-constructing
ad-hoc bars. Test helper datasets remain excluded from this rule.

### R11: Sweep Mode Remains Out Of Scope

v0.1.7 must not implement:

- `ledgr_sweep()`;
- `ledgr_precompute_features()`;
- a shared fold-core rewrite for sweep;
- `ledgr_tune()`;
- persistent feature-cache storage;
- live trading;
- paper trading;
- broker adapters;
- short selling.

`ledgr_param_grid()` may be introduced as a typed parameter-grid object for
v0.1.8 compatibility, but no multi-run execution API ships in v0.1.7.

---

## 3. Public API Scope

### 3.1 `ledgr_experiment()`

Add:

```r
ledgr_experiment(
  snapshot,
  strategy,
  features = list(),
  opening = ledgr_opening(cash = 100000),
  universe = NULL,
  fill_model = ledgr_fill_next_open(),
  persist_features = TRUE,
  execution_mode = c("audit_log", "db_live")
)
```

Return value: a classed `ledgr_experiment` object.

Rules:

- `snapshot` must be a sealed ledgr snapshot or a compatible snapshot handle.
- `strategy` must satisfy the v0.1.7 strategy signature contract.
- `features` may be a fixed list of indicators or `function(params) list(...)`.
- `opening` must be a valid `ledgr_opening` object.
- `universe = NULL` means all instruments in the snapshot.
- supplied `universe` values must be a non-empty character vector and a subset
  of the snapshot instruments.
- the object stores enough metadata for `ledgr_run()` to avoid asking for
  `db_path`, instrument IDs, start/end dates, or strategy separately.
- printing an experiment shows snapshot identity, universe size, feature mode,
  strategy class, opening state, and execution mode.

### 3.2 `ledgr_opening()`

Add:

```r
ledgr_opening(
  cash,
  date = NULL,
  positions = NULL,
  cost_basis = NULL
)
```

Return value: a classed `ledgr_opening` object.

Rules:

- `cash` must be finite and non-negative.
- `positions`, if supplied, must be a named numeric vector.
- negative positions are rejected in v0.1.7 because short selling is out of
  scope.
- `cost_basis`, if supplied, must be named consistently with `positions`.
- if `date = NULL`, the run starts at the first valid pulse after indicator
  warmup.
- if `date` is supplied, the run starts at that date and the warmup check must
  prove all indicators have enough prior bars.

### 3.3 `ledgr_opening_from_broker()`

Add only as a structural adapter hook:

```r
ledgr_opening_from_broker(x, ...)
```

v0.1.7 does not ship broker integrations. The function may accept only
explicitly supported adapter objects and otherwise fails with a classed
not-supported error. It must not open network connections or call broker APIs
implicitly.

If this surface is judged too early during implementation, the ticket must
escalate before replacing it with documentation-only reservation.

### 3.4 `ledgr_run()`

Add:

```r
ledgr_run(
  exp,
  params = list(),
  run_id = NULL,
  seed = NULL
)
```

Return value: a `ledgr_backtest`-compatible run handle.

Rules:

- `exp` must be a `ledgr_experiment`.
- `params` must be a list; empty list is valid.
- if `exp$features` is a function, evaluate it with `params` before feature
  precomputation.
- `run_id`, if omitted, is generated by the same durable ID rules as existing
  backtests.
- `seed` is reserved for parity with v0.1.8. v0.1.7 must always include a
  `seed` field in `config_json` before config hashing, with `seed = NULL`
  represented explicitly for default runs. If non-NULL seeds are not fully
  implemented in v0.1.7, they must fail clearly with a classed "reserved for
  v0.1.8" error.
- `ledgr_run()` must preserve current event ledger and result semantics for
  equivalent valid runs.

### 3.5 `ledgr_param_grid()`

Add:

```r
ledgr_param_grid(...)
```

Return value: a classed `ledgr_param_grid` object.

Rules:

- inputs are parameter lists;
- user-supplied names become stable grid labels;
- unnamed entries receive labels derived from a stable short hash of canonical
  params JSON;
- labels must be unique;
- every entry must be a list;
- the object is not executed in v0.1.7;
- the object exists to lock the future sweep/tune parameter-grid contract.

### 3.6 Context Helpers

Add to runtime and `ledgr_pulse_snapshot()` contexts:

```r
ctx$flat()
ctx$hold()
```

Rules:

- `ctx$flat()` returns a named numeric target vector with zero quantity for
  every instrument in `ctx$universe`.
- `ctx$hold()` returns a named numeric target vector matching current
  positions.
- both helpers validate names and finiteness before return where practical.
- `ctx$targets()` and `ctx$current_targets()` fail with a classed migration
  error.

### 3.7 Snapshot Resumption

New-session workflows require a first-class path from a durable DuckDB file
back to a snapshot handle:

```r
snapshot <- ledgr_snapshot_load(db_path, snapshot_id)
```

Rules:

- this is the only normal workflow place, besides snapshot creation, where a
  user supplies `db_path`;
- the returned object must carry enough store metadata for all snapshot-first
  run-management APIs;
- docs must show resuming a session by loading the snapshot first;
- if multiple sealed snapshots exist and `snapshot_id` is missing, the function
  must fail with a classed error pointing to `ledgr_snapshot_list(db_path)`;
- if the final public name is changed to `ledgr_snapshot_open()`, the older
  function must be clearly documented as the same resumption concept or
  low-level compatibility surface.

### 3.8 Snapshot-First Store Operations

Update public workflow signatures for:

```r
ledgr_run_list(snapshot, ...)
ledgr_run_info(snapshot, run_id, ...)
ledgr_run_open(snapshot, run_id, ...)
ledgr_run_label(snapshot, run_id, label = NULL, ...)
ledgr_run_tag(snapshot, run_id, tags, ...)
ledgr_run_untag(snapshot, run_id, tags = NULL, ...)
ledgr_run_archive(snapshot, run_id, reason = NULL, ...)
ledgr_compare_runs(snapshot, run_ids = NULL, ...)
ledgr_extract_strategy(snapshot, run_id, ...)
```

Rules:

- mutation functions return the snapshot object for piping and reassignment.
- read functions return their existing classed objects.
- old `db_path`-first public examples are removed.
- old `db_path`-first calls fail loudly or are marked internal/low-level.
- behavior for archived, failed, incomplete, and legacy runs remains as defined
  in v0.1.5 and v0.1.6 unless explicitly changed here.

### 3.9 Curated Print Methods

Update or add print methods for:

```r
print.ledgr_run_list()
print.ledgr_comparison()
```

Rules:

- print methods must not change the underlying data;
- they must remain compatible with dplyr/tibble workflows;
- full columns remain available through ordinary tibble operations.

### 3.10 Demo Dataset And Simulator

Add:

```r
ledgr_demo_bars
ledgr_sim_bars(n_instruments = 12, n_days = 1760, seed = 1, ...)
```

Rules:

- `ledgr_demo_bars` is a committed `.rda` dataset in `data/`;
- `data-raw/make_demo_bars.R` is the single source of truth for regenerating
  the committed dataset;
- the generator uses a documented deterministic synthetic data process;
- no runtime network access;
- no heavy optional dependencies;
- README, vignettes, and Rd examples use demo data where appropriate.

---

## 4. Breaking-Change Policy

v0.1.7 must make breaking changes visible and intentional.

Required artifacts:

- `NEWS.md` section with a "Breaking changes" subsection;
- migration guide under `inst/design/` or a vignette/article;
- contracts update documenting the v0.1.7 public workflow;
- roxygen docs for removed or demoted functions that remain exported;
- tests proving removed signatures fail with clear messages.

The old API must not remain silently supported in user-facing paths.

---

## 5. Storage And Identity

v0.1.7 should avoid unnecessary schema changes. The preferred approach is to
map the new experiment-first API onto the v0.1.5/v0.1.6 store:

- `runs`;
- `run_provenance`;
- `run_telemetry`;
- `run_tags`;
- existing result and ledger tables.

Any schema change requires a dedicated ticket and Tier H review.

Identity rules:

- `ledgr_run()` must produce the same identity fields as the equivalent
  existing backtest path for equivalent inputs.
- `ledgr_experiment()` itself is an ephemeral R object and is not persisted as
  a separate experiment-store identity in v0.1.7.
- `ledgr_opening()` data that affects execution must be represented in the
  config hash.
- `universe` selection affects execution and must be represented in the config
  hash.
- `seed` must appear in config JSON and config hashing even when it is `NULL`.
- `ledgr_param_grid()` labels are not run IDs.

---

## 6. Documentation Scope

All public docs should be rewritten around the new workflow:

- README quickstart;
- `vignettes/getting-started.Rmd`;
- `vignettes/research-to-production.Rmd`;
- `vignettes/strategy-development.Rmd`;
- `vignettes/experiment-store.Rmd`;
- `vignettes/ttr-indicators.Rmd`;
- all relevant Rd examples.

Docs must not teach:

- `db_path`-first store calls;
- `function(ctx)` strategies;
- `ctx$targets()` or `ctx$current_targets()`;
- `ledgr_backtest()` as the main entry point;
- `ledgr_sweep()`, `ledgr_precompute_features()`, or `ledgr_tune()` as
  available APIs.

---

## 7. Non-Goals

v0.1.7 does not include:

- sweep mode;
- persisted sweep results;
- multi-run tuning;
- fold-core extraction for sweep;
- cross-sectional feature APIs beyond current behavior;
- portfolio optimization helpers;
- short selling;
- broker integrations;
- paper trading;
- live trading;
- persistent feature-cache storage.

---

## 8. Verification Gates

v0.1.7 is complete only when:

- the v0.1.7 spec, tickets, roadmap, contracts, and NEWS agree;
- old public workflow signatures fail loudly or are explicitly documented as
  low-level/internal;
- `ledgr_run()` and equivalent existing valid runs have matching result
  semantics;
- `function(ctx)` strategies fail;
- `function(ctx, params)` with `params = list()` works;
- `ctx$flat()` and `ctx$hold()` work in runtime and pulse-snapshot contexts;
- old context helper names fail with migration guidance;
- snapshot-first store APIs cover list/info/open/label/archive/tags/compare/
  extract workflows;
- curated print methods render without changing underlying columns;
- demo dataset and simulator are documented and deterministic;
- README and vignettes render offline using the new API;
- no v0.1.8 sweep APIs are exported;
- `devtools::test()` passes;
- coverage gate passes;
- `R CMD check --no-manual --no-build-vignettes` passes with 0 errors and
  0 warnings;
- pkgdown builds;
- Ubuntu and Windows CI are green.
