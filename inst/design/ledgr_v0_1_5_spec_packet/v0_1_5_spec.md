# ledgr v0.1.5 Specification - Experiment Store Core

**Document Version:** 0.1.2  
**Author:** Max Thomasberger  
**Date:** April 27, 2026  
**Release Type:** Experiment Store Milestone  
**Status:** **DRAFT FOR REVIEW**

## 0. Goal

v0.1.5 makes DuckDB experiment stores a first-class user concept.

After v0.1.4, ledgr can create sealed snapshots, run reproducible backtests,
reuse durable snapshots, precompute features efficiently, and use a broad TTR
indicator adapter. The remaining workflow gap is experiment management:

```text
I created several runs in a durable DuckDB file. How do I find them,
understand them, reopen them, and know what produced them?
```

v0.1.5 answers that question.

The core product model is:

```text
DuckDB file      = experiment store
snapshot         = sealed input data
run_id           = immutable experiment key
strategy + params = logic identity
ledger           = execution truth
views            = derived outputs
```

The release also incorporates the v0.1.4 audit findings that directly affect
experiment-store usability: feature ID typos must not silently produce no-op
strategies, intentional snapshot IDs must not generate noisy warnings, stored
runs need durable telemetry summaries, and result extraction needs a
package-prefixed discovery path.

---

## 1. Inputs

v0.1.5 is derived from:

- `inst/design/ledgr_roadmap.md`, section `v0.1.5 - Experiment Store Core`;
- `inst/design/ledgr_v0_1_5_spec_packet/ledgr_v0_1_4_audit_report.md`;
- `inst/design/contracts.md`, especially the strategy, persistence, context,
  and result contracts;
- the completed v0.1.4 stabilisation work.

---

## 2. Hard Requirements

### R1: No New Execution Semantics

v0.1.5 MUST NOT change pulse ordering, target validation, fill timing, ledger
event semantics, snapshot hashing, feature computation, or derived-state
reconstruction semantics.

The experiment-store API is a discovery and provenance layer over existing run
artifacts. It must not become a second execution engine.

### R2: DuckDB Files Are Experiment Stores

A durable DuckDB file may contain:

- one or more sealed snapshots;
- one or more runs against those snapshots;
- run provenance metadata;
- derived result tables.

Users must be able to leave an R session, reopen the DuckDB file later, list
stored runs, inspect run provenance, and reopen a run without recomputing it.

### R3: `run_id` Is Immutable

`run_id` is the immutable experiment key.

v0.1.5 MUST NOT support renaming `run_id`. Human-friendly names belong in a
mutable `label` field.

Completed runs MUST NOT be silently overwritten. If a user attempts to create a
completed `run_id` again, ledgr must fail clearly and point them to
`ledgr_run_open()`.

### R4: Experiment Identity Is Explicit

Experiment identity is:

```text
snapshot_hash
+ strategy_source_hash
+ strategy_params_hash
+ config_hash
+ ledgr_version
+ R_version
+ relevant_dependency_versions
```

Changing any identity component creates a different experiment, even if the
human-readable `label` is the same.

### R5: Strategy Parameters Are First-Class

`strategy_params` are part of experiment identity, not optional comments.

`ledgr_backtest()` must support:

```r
function(ctx)
function(ctx, params)
```

The `function(ctx, params)` form is the preferred durable research form.
`strategy_params` must be JSON-safe enough to hash with ledgr's canonical JSON
path. Non-JSON-safe parameters must fail with an actionable error.

### R6: Strategy Source Capture Is Provenance, Not A Full Replay Guarantee

v0.1.5 stores strategy source text and a source hash where possible. This
supports inspection and future strategy recovery work, but it is not the same
as guaranteeing executable replay.

Reproducibility levels must be explicit:

```text
Tier 1: self-contained function(ctx, params) with explicit params
Tier 2: inspectable but needs external context, including most R6 strategies
Tier 3: environment-dependent or not meaningfully recoverable
Legacy: run created before v0.1.5 provenance metadata
```

Runs created before the experiment-store schema must be discoverable and
clearly marked as legacy/pre-provenance artifacts. They must not be silently
upgraded to fully reproducible experiments.

### R7: Feature ID Typos Must Fail Loudly

The v0.1.4 audit found that a strategy typo such as `returns_20` instead of the
actual feature ID `return_20` can silently behave like a no-op strategy.

v0.1.5 must distinguish:

- a known feature whose value is `NA` at a pulse because of warmup;
- an unknown feature name that was never configured.

`ctx$feature(instrument_id, feature_name)` MUST NOT silently return the default
value for unknown feature IDs. It must raise a classed condition, preferably an
error, naming the missing feature and listing available feature IDs.

### R8: Archive Instead Of Delete

v0.1.5 supports non-destructive run cleanup through archival.

Archived runs are hidden from `ledgr_run_list()` by default but remain
discoverable, inspectable, and auditable when requested.

Hard delete remains out of scope.

### R9: Telemetry Summaries Must Survive The Session

`ledgr_backtest_bench()` remains a detailed session-scoped telemetry view.

v0.1.5 must additionally persist a compact run telemetry summary so
`ledgr_run_info()` can report:

- execution mode;
- elapsed wall time;
- feature cache hits and misses;
- whether features were persisted;
- any other cheap high-level execution counters already available at run
  completion.

The full per-component telemetry table does not need to be persisted in
v0.1.5.

---

## 3. Public API Scope

### 3.1 Backtest Entry Point

`ledgr_backtest()` remains the normal execution entry point.

v0.1.5 extends it with explicit strategy parameters:

```r
bt <- ledgr_backtest(
  snapshot = snapshot,
  strategy = strategy,
  strategy_params = list(window = 20, quantity = 10),
  run_id = "sma_20"
)
```

Rules:

- `strategy_params` defaults to `list()`.
- `function(ctx)` strategies continue to work.
- `function(ctx, params)` strategies receive `strategy_params`.
- Other strategy signatures fail with a classed error.
- `strategy_params` are stored and hashed.
- `strategy_params` must be canonical JSON serializable.

### 3.2 Run Discovery

Add:

```r
ledgr_run_list(db_path, include_archived = FALSE)
```

Return value: a tibble with at least:

```text
run_id
label
snapshot_id
snapshot_hash
created_at
status
archived
reproducibility_level
strategy_source_hash
strategy_params_hash
config_hash
ledgr_version
execution_mode
elapsed_sec
final_equity
total_return
n_trades
```

Notes:

- Archived runs are excluded unless `include_archived = TRUE`.
- Legacy/pre-provenance runs are included and clearly labeled.
- Summary columns such as `final_equity`, `total_return`, and `n_trades` may be
  derived from existing result tables. They must not trigger a rerun.

### 3.3 Run Reopen

Add:

```r
bt <- ledgr_run_open(db_path, run_id)
```

`ledgr_run_open()` returns a `ledgr_backtest`-compatible handle over an existing
run.

Rules:

- It may open completed archived runs because archived means hidden from
  default lists, not deleted.
- It must fail with a classed error for failed, interrupted, running, or
  otherwise incomplete runs. v0.1.5 does not expose partial-run handles.
- It must not execute strategy code.
- It must not recompute fills.
- It must not mutate the run by default.
- It must support `summary()`, `plot()`, `tibble::as_tibble()`,
  `ledgr_results()`, and `close()`.
- Incomplete-run diagnostics belong in `ledgr_run_info()`.

### 3.4 Run Info

Add:

```r
info <- ledgr_run_info(db_path, run_id)
```

Return value: an S3 object of class `ledgr_run_info` containing:

- run identity fields;
- snapshot identity fields;
- strategy source hash and parameter hash;
- strategy parameter JSON or decoded parameters when safe;
- reproducibility level and notes;
- ledgr/R/dependency versions;
- archive status;
- persisted telemetry summary;
- legacy/pre-provenance limitations when applicable.

`print.ledgr_run_info()` must provide a concise human-readable view with at
least `run_id`, `label`, status, archive state, snapshot identity, strategy
hashes, reproducibility level, execution mode, elapsed time, and legacy
limitations when present. The full record remains accessible through normal R
inspection (`str()`, `unclass()`, or documented fields).

`ledgr_run_info()` should not execute recovered strategy source. Strategy
recovery is v0.1.6 scope.

### 3.5 Run Label

Add:

```r
ledgr_run_label(db_path, run_id, label)
```

Rules:

- `label` is mutable.
- `run_id` is immutable.
- Labels may be applied to runs in any status, including failed or incomplete
  runs, because labels mutate metadata only.
- Changing a label must not alter experiment identity hashes.
- Empty labels are allowed only if the implementation treats them as `NULL`;
  otherwise labels must be non-empty scalar strings.

### 3.6 Run Archive

Add:

```r
ledgr_run_archive(db_path, run_id, reason = NULL)
```

Rules:

- Archival is non-destructive.
- Runs in any status may be archived, including failed or incomplete runs,
  because archival mutates metadata only.
- Archived runs remain readable through `ledgr_run_info()` and
  `ledgr_run_open()`.
- `ledgr_run_list()` hides archived runs by default.
- `reason` is stored when supplied.
- Calling `ledgr_run_archive()` on an already archived run is idempotent. It
  should not rewrite the original archive timestamp or reason unless a future
  explicit unarchive/rearchive API is added.

### 3.7 Result Discovery Wrapper

The v0.1.4 audit found that `tibble::as_tibble(bt, what = "trades")` is correct
but not easily discoverable.

v0.1.5 should add a thin package-prefixed wrapper:

```r
ledgr_results(bt, what = c("trades", "ledger", "equity", "fills"))
```

Rules:

- For v0.1.5, the exhaustive supported `what` values are `equity`, `fills`,
  `trades`, and `ledger`, matching `tibble::as_tibble.ledgr_backtest()`.
- It delegates to the existing result path for those values.
- It must not mutate the backtest object or persistent run state.
- It is a discovery helper, not a new result implementation.

---

## 4. Storage And Schema Contract

The implementation may use one table or several normalized tables, but the
experiment store must persist the following logical records.

### 4.1 Run Record

Minimum logical fields:

```text
run_id
snapshot_id
snapshot_hash
config_hash
data_hash
created_at
completed_at
status
label
archived
archived_at
archive_reason
execution_mode
persist_features
elapsed_sec
feature_cache_hits
feature_cache_misses
ledgr_version
R_version
dependency_versions_json
schema_version
```

`data_hash` is the run-level input-window hash used for restart/resume safety:
it identifies the subset of the sealed snapshot actually used by the run
(`snapshot_hash` plus the selected universe and start/end pulse range). It is
not the deprecated public `ledgr_data_hash()` direct-bars helper.

Valid `execution_mode` values in v0.1.5 are:

```text
audit_log
db_live
```

Additional execution modes require a future spec update because the stored
string is part of the experiment-store contract.

The existing `runs` table may be migrated in place if that is safer than adding
a parallel metadata table. Migrations must be additive and non-destructive.

### 4.2 Schema Migration Protocol

v0.1.5 must define a defensive schema migration policy before implementation.

Policy:

- Every experiment-store API checks the store schema version before reading or
  writing run metadata.
- Read-only discovery APIs such as `ledgr_run_list()` and `ledgr_run_info()`
  must be able to read legacy/pre-provenance stores without mutating the file.
- Write APIs such as `ledgr_backtest()`, `ledgr_run_label()`, and
  `ledgr_run_archive()` may perform automatic additive migrations before the
  write.
- Automatic migrations must be wrapped in a DuckDB transaction where possible.
- `schema_version` is updated last. If migration fails, the file must remain at
  the previous schema version and later reads must still classify existing runs
  correctly.
- Write-triggered migration should emit a concise classed message so users know
  their experiment store schema was upgraded. Pure read-only discovery should
  not produce noisy migration messages.
- If a file advertises a schema version newer than the installed ledgr version
  understands, ledgr must fail with a classed error rather than attempting to
  read or downgrade it.

v0.1.5 does not require a public manual migration function. The public policy is
legacy-compatible reads and automatic additive migration on writes.

### 4.3 Strategy Provenance Record

Minimum logical fields:

```text
run_id
strategy_type
strategy_source_text
strategy_source_hash
strategy_capture_method
strategy_params_json
strategy_params_hash
reproducibility_level
unresolved_symbols_json
provenance_notes_json
```

Capture methods may include:

```text
deparse_function
functional_no_source
R6_object
legacy_pre_provenance
unsupported
```

The exact names may change during implementation, but the stored record must be
clear enough for `ledgr_run_info()` to explain the provenance limitation.

### 4.4 Dependency Version Record

At minimum, v0.1.5 stores:

```text
ledgr
R
duckdb
DBI
digest
jsonlite
tibble
```

When a run uses TTR-backed indicators, the recorded dependency versions must
include `TTR`.

Additional dependency versions may be stored if cheap and deterministic.

### 4.5 Legacy Runs

If a DuckDB file contains runs without v0.1.5 provenance fields:

- `ledgr_run_list()` must still list them;
- `ledgr_run_info()` must state that provenance is incomplete;
- `reproducibility_level` must be `legacy` or equivalent;
- missing strategy hashes must remain missing rather than inferred.

---

## 5. Strategy Identity Contract

### 5.1 Functional Strategies

Functional strategy source is captured using a stable source-text method such
as:

```r
paste(deparse(strategy), collapse = "\n")
```

The source hash is computed over the captured source text.

This is sufficient for inspection and partial recovery, but it does not capture
all closure state. It is also R-version-sensitive: `strategy_source_hash` is
meaningful for direct comparison only between runs created under the same
`R_version`. Cross-version hash equality is not guaranteed even for logically
identical functions.

Therefore:

- self-contained `function(ctx, params)` strategies with JSON-safe params are
  Tier 1;
- functions that refer to external helpers, global variables, or package calls
  may be Tier 2 unless those dependencies are explicitly documented;
- functions whose source cannot be captured are Tier 3.

The implementation should detect unresolved external symbols where practical,
but v0.1.5 does not need to prove full static analysis of R code.

### 5.2 R6 Strategies

R6 strategies remain supported by the execution engine.

For v0.1.5 provenance:

- R6 strategies are Tier 2 by default;
- they may become Tier 1 only if a future explicit source/parameter metadata
  contract is implemented;
- v0.1.5 must not silently classify R6 runs as fully reproducible.

### 5.3 Parameter Hashing

`strategy_params_hash` is computed from canonical JSON.

Rules:

- named lists are key-sorted before serialization;
- scalar values are auto-unboxed through the existing canonical JSON path;
- `NULL` and `NA` follow the existing canonical JSON representation and both
  serialize as JSON `null`; v0.1.5 treats them as identical for parameter-hash
  identity unless the user encodes the distinction explicitly;
- unsupported objects fail early with a classed error.

---

## 6. Audit-Derived UX Requirements

### 6.1 Strict Feature Lookup

`ctx$feature()` must fail loudly when a strategy asks for an unknown feature ID.

Expected behavior:

```r
ctx$feature("SPY", "returns_20")
```

If configured features include `return_20` but not `returns_20`, ledgr must
raise a classed condition that:

- names the requested feature;
- names the instrument;
- lists available feature IDs;
- makes clear that warmup `NA` is different from an unknown feature.

Warmup remains valid. If `return_20` exists but is not stable yet at the current
pulse, `ctx$feature("SPY", "return_20")` may return `NA_real_` or the caller's
explicit default according to the existing feature-access contract.

### 6.2 Snapshot ID Warning Policy

Generated snapshot IDs should continue to use the canonical form:

```text
snapshot_YYYYmmdd_HHMMSS_XXXX
```

Explicit user-supplied snapshot IDs are durable names and must not produce a
warning merely because they do not follow the generated-ID pattern.

Warnings should be reserved for genuinely suspicious cases, such as an explicit
ID that appears to be a malformed generated-style ID. The `snapshot_` prefix is
a generated-ID convention in v0.1.5, not a general ban on user-supplied names.

### 6.3 Execution Mode Visibility

The audit showed that `db_live` was about 4x slower than `audit_log` for the
same SMA strategy workload. That is acceptable, but it must be visible.

`print.ledgr_backtest()` must show the execution mode used for the run.

### 6.4 Persisted Telemetry Summary

`ledgr_run_info()` must expose enough telemetry to explain a stored run after
the original R session is gone.

Minimum fields:

```text
execution_mode
elapsed_sec
feature_cache_hits
feature_cache_misses
persist_features
```

This does not replace `ledgr_backtest_bench()`.

### 6.5 Result Access Discoverability

`ledgr_results()` should be documented as the package-prefixed entry point for
result tables. The existing S3 path remains valid.

Example:

```r
ledgr_results(bt, what = "trades")
ledgr_results(bt, what = "equity")
```

---

## 7. Non-Goals

v0.1.5 does not implement:

- run comparison tables (`ledgr_compare_runs()` is v0.1.6 scope);
- strategy extraction/revival (`ledgr_extract_strategy()` is v0.1.6 scope);
- tags;
- hard delete;
- persistent feature cache;
- parameter sweep mode;
- live trading;
- paper trading;
- broker adapters;
- streaming data;
- performance rewrites of the pulse loop or DuckDB write path.

v0.1.5 may store data needed by v0.1.6, but it must not expose half-finished
comparison or strategy-recovery APIs.

---

## 8. Verification Gates

v0.1.5 is accepted only when the following gates pass.

### 8.1 Experiment Store API Tests

Tests must prove:

- `ledgr_run_list()` discovers multiple runs in one DuckDB file;
- archived runs are hidden by default and visible with
  `include_archived = TRUE`;
- `ledgr_run_open()` returns a reusable handle without recomputing the run;
- `ledgr_run_open()` fails clearly for failed or incomplete runs;
- `summary()`, `plot()`, `tibble::as_tibble()`, and `ledgr_results()` work on
  reopened runs;
- `ledgr_run_info()` exposes identity, provenance, archive status, and
  telemetry summary;
- labels can change without changing `run_id` or identity hashes;
- completed runs cannot be silently overwritten.
- legacy stores can be listed without mutation;
- write-triggered schema migration is additive and leaves the store readable if
  migration fails.

### 8.2 Strategy Identity Tests

Tests must prove:

- `function(ctx)` strategies still work;
- `function(ctx, params)` strategies receive `strategy_params`;
- changing `strategy_params` changes `strategy_params_hash`;
- changing strategy source changes `strategy_source_hash`;
- non-JSON-safe `strategy_params` fail clearly;
- R6 strategies are not classified as Tier 1 by default;
- legacy/pre-provenance runs are discoverable and clearly labeled.

### 8.3 Audit Regression Tests

Tests must prove:

- unknown feature IDs in `ctx$feature()` fail loudly;
- warmup `NA` for known features still behaves correctly;
- explicit noncanonical snapshot IDs do not produce the old noisy warning;
- malformed generated-style snapshot IDs still produce a useful warning or
  error;
- print output and `ledgr_run_info()` both surface execution mode;
- persisted telemetry is available after reopening the run in a fresh handle.

### 8.4 Package Gates

Release gate:

1. `contracts.md` and `NEWS.md` match v0.1.5 scope.
2. v0.1.4 regression tests continue to pass.
3. README and vignettes remain offline-safe.
4. Coverage remains at or above the project gate.
5. pkgdown site builds.
6. `R CMD check --no-manual --no-build-vignettes` passes with 0 errors and 0
   warnings.
7. Ubuntu and Windows CI are green.

---

## 9. Candidate Ticket Areas

Ticket IDs should be assigned after this spec is reviewed. The expected work
areas are:

1. Experiment-store schema migration and legacy-run handling.
2. `strategy_params`, source capture, hashes, and reproducibility levels.
3. Run discovery/open/info/label/archive APIs.
4. Strict feature lookup and snapshot ID warning policy.
5. Persisted telemetry summary and execution-mode visibility.
6. Result discovery wrapper.
7. Documentation, examples, and pkgdown updates.
8. v0.1.5 release gate.

---

## 10. Roadmap Impact

The release order remains:

```text
v0.1.5  experiment store core
v0.1.6  experiment comparison and strategy recovery
v0.1.7  lightweight parameter sweep mode
v0.2.0  OMS semantics
```

v0.1.5 is intentionally not a comparison release. It establishes the durable
experiment identity and discovery layer that comparison, strategy recovery, and
sweep workflows depend on.
