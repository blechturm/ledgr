# ledgr v0.1.6 Specification - Strategy Comparison And Recovery

**Document Version:** 0.1.0  
**Author:** Max Thomasberger  
**Date:** April 28, 2026  
**Release Type:** Experiment Workflow Milestone  
**Status:** **DRAFT FOR REVIEW**

## 0. Goal

v0.1.6 makes strategy development and experiment comparison a coherent user
workflow.

After v0.1.5, ledgr can store durable runs with provenance, telemetry, labels,
and archive metadata. The remaining user workflow gap is:

```text
I wrote several strategies or parameter variants.
How do I understand the strategy contract, compare stored runs,
and inspect or recover the strategy source behind a result?
```

v0.1.6 answers that question with three linked work streams:

1. **Audit stabilisation:** fix or clarify the high-friction issues found in
   the v0.1.5 usability audit.
2. **Strategy development UX:** add a dedicated strategy-development article
   explaining `ctx`, target vectors, strategy parameters, indicators, and
   debugging.
3. **Experiment comparison and recovery:** add APIs for comparing stored runs
   and extracting stored strategy source with an explicit trust boundary.

The release is not a new execution engine. It is a workflow layer over the
sealed-snapshot, pulse-engine, and event-ledger contracts already shipped.

---

## 1. Inputs

v0.1.6 is derived from:

- `inst/design/ledgr_roadmap.md`, section
  `v0.1.6 - Experiment Comparison And Strategy Recovery`;
- `inst/design/ledgr_v0_1_6_spec_packet/ledgr_v0_1_5_audit_report.md`;
- `inst/design/contracts.md`;
- `inst/design/model_routing.md`;
- the accepted v0.1.5 experiment-store APIs and review findings.

---

## 2. Hard Requirements

### R1: No New Execution Semantics

v0.1.6 MUST NOT change pulse ordering, fill timing, ledger event semantics,
snapshot hashing, feature computation semantics, or deterministic replay.

The release may fix validation and diagnostics around the existing execution
surface, including:

- duplicate feature ID preflight;
- `initial_cash` validation;
- final-bar no-fill warning coverage;
- clearer low-level API documentation.

Those changes must not alter the meaning of a valid backtest.

### R2: Comparison Reads Stored Truth

Run comparison must read stored experiment artifacts. It must not rerun
strategies, recompute fills, or mutate the experiment store.

Comparison is a view over:

- run metadata;
- strategy provenance;
- compact telemetry;
- stored result views such as equity, trades, fills, and ledger-derived
  metrics.

### R3: Completed Runs Are The Comparison Unit

`ledgr_compare_runs()` compares completed stored runs.

Default discovery follows `ledgr_run_list()` semantics:

- archived runs are hidden unless requested;
- incomplete or failed runs are not included in default comparisons;
- explicitly requested incomplete or failed runs fail with a classed error
  naming the run status.

Diagnostics for failed and incomplete runs remain the responsibility of
`ledgr_run_info()`.

### R4: Strategy Recovery Has A Trust Boundary

Stored strategy source is provenance. It is not inherently safe code.

`ledgr_extract_strategy(..., trust = FALSE)` must be the default and must not
evaluate recovered source. It returns source text, hashes, parameter metadata,
and reproducibility metadata for inspection.

`trust = TRUE` may parse/evaluate recovered source only after verifying the
stored source hash. Hash verification proves identity of stored text, not
safety. The documentation must say this explicitly.

### R5: `strategy_params` Are Passed As The Second Strategy Argument

The correct parameterised strategy contract is:

```r
function(ctx, params)
```

`params` is not accessed through `ctx$params` in v0.1.6. The v0.1.5 audit
finding about `ctx$params` is a documentation gap, not an implementation bug.

v0.1.6 must add working examples showing parameter access through the second
argument and must not add a duplicate `ctx$params` path accidentally.

### R6: Feature IDs Must Be Discoverable Before Runtime

The TTR feature ID scheme is deterministic but not guessable. v0.1.6 must make
feature IDs discoverable before a strategy is run.

At minimum:

- docs must explain the convention for TTR IDs;
- examples must show reading `ind$id`;
- a helper such as `ledgr_feature_id()` may be added if it keeps the user
  workflow clearer.

The existing unknown-feature runtime error remains necessary, but runtime
errors are not the primary discovery mechanism.

### R7: Low-Level APIs Must Not Look Like Recommended Workflows

The v0.1.5 audit showed that users can confuse low-level and high-level APIs.
v0.1.6 docs must clearly separate:

- recommended high-level workflows;
- low-level DBI recovery helpers;
- legacy helpers kept for compatibility.

In particular:

- `ledgr_state_reconstruct()` is a low-level DBI recovery helper;
- `ledgr_data_hash()` is a legacy direct-`bars` helper;
- `ledgr_backtest_bench()` is session-scoped and takes a `ledgr_backtest`
  object;
- `ledgr_compute_metrics()` takes a `ledgr_backtest` or snapshot-backed object
  supported by the current metrics contract, not an arbitrary equity tibble.

### R8: Long-Only And Last-Bar Semantics Must Be Explicit

v0.1.x remains long-only. Negative target quantities are not supported as short
positions and must not silently look like a working shorting API.

The final-bar no-fill behavior must be tested against a true final-bar target
change. If the implementation and docs diverge, v0.1.6 must either fix the
warning or correct the docs.

### R9: No Sweep, Live, Paper, Or Broker Work

v0.1.6 must not implement:

- parameter sweep mode;
- persistent feature-cache reuse across sessions;
- walk-forward validation;
- paper trading;
- live trading;
- broker adapters;
- short selling;
- portfolio sizing helpers beyond documentation examples.

Those remain roadmap items for later cycles.

---

## 3. Public API Scope

### 3.1 `ledgr_compare_runs()`

Add:

```r
ledgr_compare_runs(
  db_path,
  run_ids = NULL,
  include_archived = FALSE,
  metrics = c("standard")
)
```

Return value: a tibble-like data frame with one row per completed run and at
least:

```text
run_id
label
archived
created_at_utc
snapshot_id
status
final_equity
total_return
max_drawdown
n_trades
win_rate
execution_mode
elapsed_sec
reproducibility_level
strategy_source_hash
strategy_params_hash
config_hash
snapshot_hash
```

Rules:

- If `run_ids = NULL`, compare completed runs returned by the discovery path.
- If `run_ids` is supplied, preserve the requested order.
- Explicit archived runs may be compared.
- Explicit failed or incomplete runs fail with a classed error naming the
  status and pointing to `ledgr_run_info()`.
- Missing run IDs fail with a classed error listing missing IDs.
- No strategy source is evaluated.
- No run is recomputed.
- No database mutation occurs.

`metrics = "standard"` is the only required metrics set in v0.1.6. Additional
metrics may be added later, but v0.1.6 must not silently expose unstable metric
sets.

### 3.2 `ledgr_extract_strategy()`

Add:

```r
ledgr_extract_strategy(db_path, run_id, trust = FALSE)
```

Default return value: an object of class `ledgr_extracted_strategy` containing
at least:

```text
run_id
strategy_source_text
strategy_source_hash
strategy_params
strategy_params_hash
reproducibility_level
R_version
ledgr_version
dependency_versions
trust
hash_verified
warnings
```

Rules:

- `trust = FALSE` never evaluates source.
- `trust = TRUE` verifies the source hash before parsing/evaluating source.
- If evaluation is attempted, the returned object must make the resulting
  function explicit, for example as `strategy_function`.
- Legacy/pre-provenance runs return a clear classed error or a structured
  object with `strategy_source_text = NA`, depending on available metadata.
- Tier 2 and Tier 3 runs must carry warnings explaining why recovered source may
  not be executable.
- Hash mismatch fails with a classed error.

### 3.3 Feature ID Discovery

v0.1.6 may add:

```r
ledgr_feature_id(x)
```

Rules:

- For a single `ledgr_indicator`, return `x$id`.
- For a list of indicators, return a named character vector or character vector
  of IDs.
- Invalid objects fail with a classed error.

If this helper is added, it must be documented as a convenience layer over the
existing indicator ID contract, not as a second ID-generation scheme.

For a list of indicators, the helper returns a plain character vector of
indicator IDs in list order. Names are not required because the IDs themselves
are the stable lookup values.

### 3.4 Audit-Stabilised Existing APIs

Existing APIs must be clarified or fixed where needed:

- `ledgr_state_reconstruct(run_id, con)` must work according to its documented
  low-level signature, or fail with a clear classed error for unsupported
  inputs.
- `ledgr_snapshot_list()` docs must state the accepted inputs: DBI connection
  or DuckDB file path.
- `ledgr_data_hash()` docs must state it is legacy and connection-based.
- `ledgr_backtest_bench()` docs must state it takes a `ledgr_backtest` object
  and is session-scoped.
- `ledgr_compute_metrics()` docs must state accepted input types.
- `ledgr_backtest()` and config validation must reject `initial_cash <= 0`.
- Duplicate feature IDs must fail before DuckDB writes with a user-facing,
  classed error.

### 3.5 Strategy Development Vignette

Add a new article:

```text
vignettes/strategy-development.Rmd
```

The article must explain:

- `function(ctx)` and `function(ctx, params)`;
- the meaning of a pulse;
- every major `ctx` field/helper:
  - `ctx$ts_utc`;
  - `ctx$universe`;
  - `ctx$cash`;
  - `ctx$equity`;
  - `ctx$position(id)`;
  - `ctx$bar(id)`;
  - `ctx$open(id)`;
  - `ctx$high(id)`;
  - `ctx$low(id)`;
  - `ctx$close(id)`;
  - `ctx$volume(id)`;
  - `ctx$targets()`;
  - `ctx$current_targets()`;
  - `ctx$feature(id, feature_id)`;
  - `ctx$features_wide`;
- target-vector requirements;
- `ctx$targets()` versus `ctx$current_targets()`;
- built-in indicators;
- TTR indicators;
- feature ID discovery;
- warmup `NA`;
- debugging with `ledgr_pulse_snapshot()`;
- comparing strategy variants through `ledgr_compare_runs()`;
- inspecting recovered source through `ledgr_extract_strategy()`.

The article must include at least:

- one `function(ctx)` strategy;
- one `function(ctx, params)` strategy;
- one built-in indicator example;
- one TTR indicator example;
- one same-strategy/different-params comparison;
- one different-strategy comparison.

### 3.6 Experiment Store Vignette

Add a dedicated how-to article:

```text
vignettes/experiment-store.Rmd
```

This article is distinct from `research-to-production.Rmd`. The research-to-
production article explains the long-term philosophy; the experiment-store
article teaches the concrete v0.1.5/v0.1.6 run-management workflow.

The article must cover:

- durable DuckDB files as experiment stores;
- creating multiple runs against one sealed snapshot;
- `run_id` as immutable experiment identity;
- `label` as mutable human metadata;
- `ledgr_run_list()`;
- `ledgr_run_info()`;
- `ledgr_run_open()`;
- `ledgr_run_label()`;
- `ledgr_run_archive()`;
- archived versus deleted runs;
- compact telemetry fields;
- reproducibility tiers;
- legacy/pre-provenance runs;
- how `ledgr_compare_runs()` builds on stored run metadata;
- what remains out of scope: hard delete,
  strategy recovery details beyond a pointer to the strategy-development
  article.

All examples must be offline-safe and use `tempfile()` for durable artifacts.

---

## 4. Storage And Schema

v0.1.6 should avoid new schema unless a ticket explicitly justifies it.

`ledgr_compare_runs()` and `ledgr_extract_strategy()` should use the v0.1.5
experiment-store schema:

- `runs`;
- `run_provenance`;
- `run_telemetry`;
- result tables/views used by existing result accessors.

Run tags are mutable grouping metadata stored outside run identity. They are
accepted through LDG-906 as a small additive schema surface and must not affect
run identity, comparison metrics, or source extraction.

Read-only comparison and extraction APIs must not migrate or mutate stores.
If they need v0.1.5 metadata that is missing, they must return legacy-aware
diagnostics rather than silently upgrading the file.

---

## 5. Trust And Recovery Contract

Stored strategy source is data until the user explicitly crosses the trust
boundary.

`ledgr_extract_strategy(..., trust = FALSE)`:

- returns source text and metadata only;
- does not call `parse()`;
- does not call `eval()`;
- does not attach packages;
- does not execute helper code;
- is safe to call on untrusted experiment stores.

`ledgr_extract_strategy(..., trust = TRUE)`:

- verifies stored source hash first;
- may parse/evaluate recovered source;
- must warn that hash verification is not a safety guarantee;
- must fail clearly for missing source, legacy runs, or non-function source;
- must not execute the recovered strategy against data.

The recovered function, if returned, is not guaranteed to be fully reproducible.
The `reproducibility_level` remains the authoritative warning.

---

## 6. Audit Findings Incorporated

The v0.1.5 audit findings are incorporated as follows:

| Audit finding | v0.1.6 handling |
|---|---|
| `ledgr_state_reconstruct()` crash | Investigate and fix/clarify as audit stabilisation |
| `ledgr_snapshot_list(ledgr_snapshot)` confusion | Clarify docs; accepted inputs are connection/path |
| `ledgr_data_hash(data.frame)` confusion | Clarify legacy connection-based helper |
| `ledgr_backtest_bench(db_path)` confusion | Clarify `ledgr_backtest` object input |
| `ctx$params` confusion | Add `function(ctx, params)` examples; do not add `ctx$params` |
| Feature ID naming opacity | Document scheme and surface IDs before runtime |
| Duplicate feature raw DuckDB error | Add user-facing preflight error |
| `initial_cash = 0` accepted | Reject `initial_cash <= 0` |
| Last-bar warning not observed | Add focused test and align docs/implementation |
| `ctx$targets()` vs `ctx$current_targets()` | Explain in strategy-development article |
| Fixed per-run overhead | Document as motivation for future sweep mode |

---

## 7. Non-Goals

v0.1.6 does not include:

- parameter sweep mode;
- walk-forward validation;
- portfolio sizing helpers;
- short selling;
- cross-sectional feature matrices beyond existing `features_wide`;
- persistent feature-cache storage;
- hard delete;
- live trading;
- paper trading;
- broker adapters.

Run tags are mutable grouping metadata only. They are outside run identity and
outside comparison semantics.

---

## 8. Verification Gates

v0.1.6 is complete only when:

- audit stabilisation tests pass;
- comparison API tests pass without recomputation or mutation;
- strategy extraction tests pass for `trust = FALSE`, `trust = TRUE`, legacy
  runs, and hash mismatch;
- the strategy-development article renders offline;
- reference docs clearly distinguish high-level, low-level, and legacy APIs;
- no v0.1.7 sweep APIs are exported;
- `R CMD check --no-manual --no-build-vignettes` passes with 0 errors and
  0 warnings;
- coverage remains at or above the project gate;
- pkgdown builds;
- Ubuntu and Windows CI are green.
