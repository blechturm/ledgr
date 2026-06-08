# RFC Synthesis: Sweep Artifact Persistence For ledgr (v0.1.9.2)

**Status:** Binding synthesis for the v0.1.9.2 spec-packet cut.
**Author:** Codex.
**Date:** 2026-06-06.
**Supersedes for spec-cut purposes:** `rfc_sweep_artifact_persistence_v0_1_9_x_seed_v2.md`.
**Final review:** Claude review received 2026-06-07; patches applied in this
revision.
**Cycle closure:** Maintainer accepted the synthesis and closed the RFC cycle
on 2026-06-07. The v0.1.9.2 spec packet may open from this synthesis.
**Revision note:** 2026-06-07 -- tightened reopened-sweep semantics, storage
schema keys, return-column naming, schema incompatibility behavior, and release
fixtures after additional pre-final-review LLM reviews. This revision also
corrects seed v2 Section 9.2's `NA_character_` ephemeral `sweep_id` binding
against current code: `ledgr_sweep()` creates a session sweep id and stores it
on the returned `ledgr_sweep_results` object at `R/sweep.R:173` and
`R/sweep.R:211`. In-memory retained returns therefore use that session sweep id
because it is already the public in-session key and makes bind/filter/save
workflows preserve a stable candidate-series key before durable save. The
correction is documented here so the audit trail remains visible.

**Revision note (round 2):** 2026-06-07 -- bound canonical JSON shape for all
`*_json` columns, `candidate_row` ordering semantics, the `retention_returns`
column type in `ledgr_sweep_list()`, and the `retained_db_delta_bytes` scope
in the storage smoke measurement. These are spec-cut tightening patches from
the fourth-round final review.

## 0. v1 naming disclaimer

This RFC uses "v1" as shorthand for the first implementation of sweep artifact
persistence in ledgr. ledgr's roadmap does not have a sweep-persistence v1
milestone. Post-v1 sweep-persistence work lives in named follow-up RFCs at
their own roadmap windows.

## 1. Scope and non-scope

v0.1.9.2 adds durable sweep artifact persistence and optional retained net
portfolio equity/returns for completed sweep candidates.

Bound scope:

- `ledgr_sweep()` gains `retain = ledgr_sweep_retention()` with the default
  preserving today's scalar-only sweep behavior.
- Users can save, reopen, list, and inspect saved sweeps in the same DuckDB
  experiment store that holds snapshots and runs.
- Saved sweeps persist scalar candidate summary rows and, when explicitly
  retained, candidate-level net portfolio equity/return series.
- Reopened sweeps materialize into `ledgr_sweep_results`-compatible objects
  that behave like in-session sweep results for filtering, printing, candidate
  extraction, and return access.
- Cost identity from v0.1.9.1 is persisted with the sweep artifact.

Bound non-scope:

- no ranking helpers, named selection views, winner-picking, top-N retention,
  or automatic promotion;
- no full ledger, fill, trade, or per-instrument artifacts for every candidate
  by default;
- no cost-component attribution, gross-vs-net decomposition, liquidity, TCA,
  OMS, taxes, financing, or broker reconciliation;
- no benchmark-relative diagnostics, signal-decay substrate, or
  implementation/cost-decay substrate;
- no walk-forward per-fold/per-candidate retention integration;
- no saved-sweep schema migration machinery beyond pre-CRAN fail-closed
  handling for incompatible future schemas.

The RFC seed v2 already absorbed the response-stage amendments and binds this
shape. This synthesis resolves the spec-cut questions and names the gates.

## 2. Bound semantic shape

The retained public series is a long table keyed by `sweep_id`,
`candidate_id`, and `ts_utc`. The durable storage table uses
`candidate_row` and `pulse_index` as compact internal keys, then joins back to
`candidate_id` for public accessors.

Required long columns:

```text
sweep_id | candidate_id | ts_utc | equity | period_return
```

Semantics:

- one row per scoring pulse for each completed candidate;
- `equity` is net portfolio equity at that pulse;
- `period_return` is the adjacent-period return ending at `ts_utc`;
- the first row for each candidate has `period_return = NA_real_`;
- metric parity drops the leading `NA_real_`;
- failed candidates have no retained return rows;
- final-bar no-fill preserves the final equity row and stores the warning on
  the candidate summary row.

This confirms seed v2 Section 5. The current return kernel computes adjacent
returns from equity values at `R/backtest.R:1421` through `R/backtest.R:1428`
and metrics consume that vector at `R/backtest.R:1608`. Current equity
materialization is pulse-indexed, not fill-indexed: the fold records equity
facts before fill resolution at `R/fold-engine.R:208` through
`R/fold-engine.R:214`, while durable reconstruction writes rows over
`pulses_posix` at `R/backtest-runner.R:1428`, `R/backtest-runner.R:1445`, and
`R/backtest-runner.R:1483`.

## 3. Bound API surface

New public constructor:

```r
ledgr_sweep_retention(
  returns = c("none", "completed")
)
```

`returns = "none"` is the default. `returns = "completed"` retains net
portfolio equity/returns for completed candidates only. No other enum values
are accepted in v0.1.9.2.

`ledgr_sweep()` gains:

```r
retain = ledgr_sweep_retention()
```

Persistence and inspection:

```r
ledgr_sweep_save(sweep, snapshot, sweep_id = NULL, note = NULL)
ledgr_sweep_open(snapshot, sweep_id)
ledgr_sweep_list(snapshot)
ledgr_sweep_info(x)
```

`ledgr_sweep_list(snapshot)` returns a tibble with one row per saved sweep in
the snapshot's experiment store. Required columns are `sweep_id`,
`created_at_utc`, `engine_version`, `sweep_schema_version`, `n_candidates`,
`n_completed`, `retention_returns`, and `note`. The `retention_returns` column
is a character scalar mirroring the saved `ledgr_sweep_retention(returns = ...)`
value (`"none"` or `"completed"` in v0.1.9.2); the character shape scales
naturally if future retention enum values are added. Rows are ordered by
`created_at_utc` descending.

`ledgr_sweep_info(x)` accepts an in-memory or reopened
`ledgr_sweep_results`-compatible object, not a bare `sweep_id`. It returns a
classed printable inspection object backed by a plain named list. The object
names the sweep id, snapshot id/hash when known, cost identity, metric-context
identity, feature identity, retention spec, grid summary, candidate counts, and
saved-artifact audit metadata when available. Bare-id inspection remains
spelled `ledgr_sweep_open(snapshot, sweep_id)` followed by
`ledgr_sweep_info()`.

Return access:

```r
ledgr_sweep_returns(x, candidates = NULL)
ledgr_sweep_returns_wide(x, candidates = NULL, value = c("returns", "equity"))
```

`ledgr_sweep_open()` eagerly materializes a `ledgr_sweep_results`-compatible
object. It is not a lazy dbplyr object and does not hold a live DuckDB
connection. Therefore v0.1.9.2 does not export or require `close()` for saved
sweeps; any close method is out of scope unless implementation discovers a
short-lived internal resource that cannot be safely hidden.

`ledgr_sweep_returns()` returns the long table with `period_return`.
`ledgr_sweep_returns_wide()` returns one wide tibble per call;
`value = "returns"` is the default and `value = "equity"` returns wide equity.
Both accessors operate identically on in-memory and reopened sweeps: return
shape, classed conditions, and `candidates` filter semantics are the same in
both contexts.
The wide helper first resolves the same long retained-series payload as
`ledgr_sweep_returns()` and must raise the same classed conditions under the
same missing-retention, missing-candidate, failed-candidate, snapshot, and
schema-incompatibility cases before pivoting.
The wide shape is:

```text
ts_utc | <candidate_id_1> | <candidate_id_2> | ...
```

Classed conditions:

- `ledgr_sweep_returns_unretained`;
- `ledgr_sweep_returns_candidate_not_completed`;
- `ledgr_sweep_returns_candidate_not_found`;
- `ledgr_invalid_sweep_id`;
- `ledgr_sweep_id_exists`;
- `ledgr_sweep_snapshot_not_found`;
- `ledgr_sweep_snapshot_hash_mismatch`;
- `ledgr_sweep_schema_incompatible`.

`ledgr_candidate()` and `ledgr_promote()` are not redesigned. They must work
against reopened saved sweeps by consuming the same candidate row and metadata
shape that in-session sweeps expose.

Promotion from a reopened saved sweep re-executes the selected candidate from
its reproduction key against the same sealed snapshot and experiment identity.
It does not commit the stored scalar row or retained return series as if they
were a full run. This means scalar-only saved sweeps remain promotable, and the
promotion boundary remains the place where full ledger, fills, trades, and
durable equity artifacts are produced.

`ledgr_sweep_open(snapshot, sweep_id)` intentionally requires a snapshot. Open
is a promote-ready inspection operation, not detached artifact viewing. If the
snapshot is missing or mismatched, opening fails before returning an object.
`ledgr_sweep_snapshot_not_found` means the saved sweep's `snapshot_id` is not
present in the provided store. `ledgr_sweep_snapshot_hash_mismatch` means the
snapshot id exists but its current `snapshot_hash` differs from the hash stored
on the sweep artifact.
Snapshot-decoupled read-only sweep inspection remains a future obligation.

## 4. Bound identity exclusion

Retention policy is non-identity. Two runs of the same sweep candidate that
differ only by `retain = ledgr_sweep_retention(returns = "none")` versus
`retain = ledgr_sweep_retention(returns = "completed")` must produce identical
execution identity and scalar results.

The retention metadata attribute key is bound as:

```text
sweep_retention
```

Implementation binding:

- `sweep_retention` lives beside, not inside, `execution_assumptions`;
- `config_hash_payload()` explicitly excludes `sweep_retention` as defense in
  depth;
- candidate reproduction keys exclude retention policy;
- persisted storage metadata records retention so the artifact can be reopened,
  but that storage metadata does not enter candidate identity.

Current code makes the defensive exclusion necessary. `config_hash()` hashes
`config_hash_payload(config)` at `R/config-hash.R:1` through
`R/config-hash.R:2`, and the current payload helper excludes only named fields
such as `db_path`, `run_id`, `alias_map_order`, snapshot DB path, and
`features$feature_set_hash` at `R/config-hash.R:5` through
`R/config-hash.R:14`. The sweep result already has an
`execution_assumptions` attribute at `R/sweep.R:232` through `R/sweep.R:239`;
retention must not be added there.

## 5. Spec-cut bindings

All six seed v2 Section 13 questions are resolved here. No open question is
left for ticket cut.

### Q1. sweep_id collision behavior

Bind reject-on-collision.

`ledgr_sweep_save()` with an existing `sweep_id` raises
`ledgr_sweep_id_exists`. There is no silent overwrite, suffixing, or
`overwrite = TRUE` in v0.1.9.2.

`sweep_id` is a non-empty, non-whitespace character scalar of at most 256
ASCII-printable characters. `NULL` means "use the in-session sweep id" for
`ledgr_sweep_save()` and is not a persisted id value. `NA_character_`, empty
strings, whitespace-only strings, non-scalar values, non-ASCII values, and
over-length values raise `ledgr_invalid_sweep_id`. Wider id character sets and
longer ids are deferred until there is a concrete user need.

### Q2. Wide accessor shape

Bind separate function.

`ledgr_sweep_returns_wide()` is a separate exported helper. Do not add
`pivot =` to `ledgr_sweep_returns()`.

### Q3. Wide accessor value-column scope

Bind one wide tibble per call with a `value` argument.

```r
ledgr_sweep_returns_wide(x, candidates = NULL, value = c("returns", "equity"))
```

The default is `"returns"` because return matrices are the primary input to
PerformanceAnalytics-style consumers.

### Q4. note argument shape

Bind free-text scalar.

`note` is `NULL` or a length-one character string. Structured notes are a
future obligation, not v0.1.9.2 scope.

### Q5. Retention attribute key

Bind `sweep_retention`.

The key is used on in-memory sweep results and reopened saved-sweep objects.

### Q6. Storage schema

Bind three tables:

- `sweeps`;
- `sweep_candidates`;
- `sweep_returns`.

The detailed schema contract is in Section 6.

## 6. DuckDB schema shape

The schema uses one parent table, one candidate summary table, and one retained
series table. The implementation may add indexes for read performance, but the
keys below are binding.

All `*_json` columns on `sweeps` and `sweep_candidates` use the canonical JSON
serialization produced by ledgr's existing `canonical_json()` helper.
Round-trip parity is byte-equivalent against the canonical serialization, not
against arbitrary JSON shape variants. This binding covers `retention_json`,
`metric_context_json`, `execution_assumptions_json`, `candidate_features_json`,
`grid_json`, `cost_plan_json`, `metrics_json`, `params_json`,
`feature_params_json`, `warnings_json`, `feature_fingerprints_json`, and
`provenance_json`.

### sweeps

One row per saved sweep artifact.

```text
sweep_id TEXT NOT NULL PRIMARY KEY
snapshot_id TEXT NOT NULL
snapshot_hash TEXT NOT NULL
created_at_utc TIMESTAMP NOT NULL
engine_version TEXT NOT NULL
sweep_schema_version INTEGER NOT NULL
note TEXT
retention_json TEXT NOT NULL
metric_context_json TEXT NOT NULL
metric_context_hash TEXT NOT NULL
metric_context_version INTEGER NOT NULL
cost_model_hash TEXT NOT NULL
cost_plan_json TEXT NOT NULL
execution_assumptions_json TEXT NOT NULL
feature_union_hash TEXT NOT NULL
feature_engine_version TEXT NOT NULL
candidate_features_json TEXT NOT NULL
grid_json TEXT NOT NULL
```

Logical foreign key: `snapshot_id` references `snapshots(snapshot_id)`. The
implementation may enforce this through a DuckDB foreign key or through
fail-closed save/open validation, but `ledgr_sweep_save()` must reject a
snapshot mismatch before writing.

`created_at_utc` is the UTC save timestamp stamped by `ledgr_sweep_save()`.
`engine_version` is the package version string of the ledgr code that writes
the artifact. `sweep_schema_version` is an implementation-owned integer
artifact-schema version, not the package version. `engine_version` is audit and
debugging metadata only; it does not gate `ledgr_sweep_open()`. Schema
compatibility is controlled by `sweep_schema_version`.

`grid_json` is the canonical JSON manifest of the evaluated candidate grid as
saved: candidate row order, public `candidate_id`, strategy parameters, feature
parameters, and execution seeds. It is not a reconstruction of the user's
original grid-helper expression or source code. If a later release needs source
expression retention, that is a separate artifact-design extension.

Cost identity storage: `cost_model_hash` and `cost_plan_json` on `sweeps` are
the authoritative persisted cost identity for the saved sweep. v0.1.9.2 cost
models are experiment-level, not candidate-grid dimensions, so storing the plan
once is the compact default. Both fields are non-null for v0.1.9.2 artifacts.

Feature identity storage is layered: `feature_union_hash` and
`candidate_features_json` describe the sweep-level union/resolution substrate;
candidate-level feature identity lives on `sweep_candidates` as
`feature_set_hash` plus `feature_fingerprints_json`.

### sweep_candidates

One row per `ledgr_sweep_results` candidate row.

```text
sweep_id TEXT NOT NULL
candidate_id TEXT NOT NULL
candidate_row INTEGER NOT NULL
status TEXT NOT NULL CHECK (status IN ('DONE','FAILED'))
final_equity DOUBLE
metrics_json TEXT NOT NULL
total_return DOUBLE
annualized_return DOUBLE
volatility DOUBLE
sharpe_ratio DOUBLE
max_drawdown DOUBLE
n_trades INTEGER
win_rate DOUBLE
avg_trade DOUBLE
time_in_market DOUBLE
execution_seed INTEGER
error_class TEXT
error_msg TEXT
params_json TEXT NOT NULL
feature_params_json TEXT NOT NULL
warnings_json TEXT NOT NULL
feature_set_hash TEXT NOT NULL
feature_fingerprints_json TEXT NOT NULL
provenance_json TEXT NOT NULL
cost_model_hash TEXT NOT NULL
metric_context_hash TEXT NOT NULL
PRIMARY KEY (sweep_id, candidate_row)
UNIQUE (sweep_id, candidate_id)
```

Logical foreign key: `sweep_id` references `sweeps(sweep_id)`.

Durable summary storage binds all public scalar and JSON-serialized columns
produced by `ledgr_sweep_row()` in v0.1.9.2, except per-candidate fold
telemetry timings (`t_engine`, `t_results`, `t_fills_extract`), which remain
ephemeral measurement state and are not persisted. Current row construction is
visible at `R/sweep.R:1437` through `R/sweep.R:1503` for success and failure
rows, and the shared row constructor emits the scalar and list columns at
`R/sweep.R:1512` through `R/sweep.R:1553`. List columns are stored as canonical
JSON.

`metrics_json` is the storage source of truth for the scalar metric set. It is
canonical JSON for a plain named list of scalar metric values keyed by metric
name. It does not store the metric kernel, intermediate return vectors, or
metric-computation state. The typed metric columns remain because they are the
public sweep-result columns users filter and sort today, but open/save parity
must treat `metrics_json` as the guard against future metric-column drift. If a
later metric kernel adds a metric, the canonical JSON can retain it before any
schema projection changes.

`candidate_row` is the compact durable candidate key. `candidate_id` remains
the public identifier and is unique within a sweep. Public accessors join
through `candidate_id`; retained-series storage uses `candidate_row` to avoid
repeating long candidate ids in every pulse row.

`candidate_row` is the 1-indexed row position of the candidate in the original
in-memory `ledgr_sweep_results` tibble as produced by `ledgr_sweep()`. Save
preserves this assignment; reopen reconstructs it exactly. `candidate_row`
does not reorder under dplyr operations on the in-memory or reopened object.

Current sweep rows expose this public identifier as `run_id`. v0.1.9.2 binds a
pre-CRAN rename from candidate-row `run_id` to `candidate_id` across
`ledgr_sweep_results`, `ledgr_candidate()`, persistence, and documentation.
The old `run_id` meaning is reserved for committed runs created through
`ledgr_run()` or `ledgr_promote()`. The NEWS entry must call this out as part
of the new sweep-persistence surface.

`cost_model_hash` is denormalized on `sweep_candidates` for scanability and
row-level audit checks. `cost_plan_json` remains authoritative on `sweeps`; if
`provenance_json` carries cost-plan content, save/open validation must assert
it is identical to `sweeps.cost_plan_json`.

`feature_set_hash` is denormalized on `sweep_candidates` from
`provenance_json` for row-level scans and audit checks. Save/open validation
must assert that the denormalized value equals the value inside the candidate's
canonical provenance JSON.

`metric_context_hash` is denormalized on `sweep_candidates` for scanability,
but the sweep-level value on `sweeps` is authoritative in v0.1.9.2 because
metric context is not a candidate-grid dimension. Save/open validation must
assert that every candidate row value equals `sweeps.metric_context_hash`.

### sweep_returns

Rows exist only when the saved sweep retained returns.

```text
sweep_id TEXT NOT NULL
candidate_row INTEGER NOT NULL
pulse_index INTEGER NOT NULL
ts_utc TIMESTAMP NOT NULL
equity DOUBLE NOT NULL
period_return DOUBLE
PRIMARY KEY (sweep_id, candidate_row, pulse_index)
```

Logical foreign key: `(sweep_id, candidate_row)` references
`sweep_candidates(sweep_id, candidate_row)`.

`period_return` is nullable because the first row per candidate has no
previous equity. DuckDB stores that value as NULL; open/accessor code must
round-trip it to `NA_real_`, not `NaN`, and must not drop the row.

`pulse_index` is the canonical durable row key because retained equity is
scoring-pulse indexed. `ts_utc` remains a required UTC timestamp value for
public accessors and joins. The table should have a non-unique index on
`(sweep_id, candidate_row, ts_utc)` for timestamp scans.

Timestamps use the same whole-second UTC `POSIXct` contract as existing ledgr
equity artifacts. v0.1.9.2 uses DuckDB `TIMESTAMP`, not `TIMESTAMPTZ`, matching
the existing schema convention. Round-trip tests must assert that reopened
`ts_utc` values equal the original `pulses_posix` values.

Opening a sweep compares the stored integer `sweep_schema_version` with the
current implementation's supported saved-sweep schema version. A stored version
greater than the current supported version raises
`ledgr_sweep_schema_incompatible`. A stored version less than or equal to the
current supported version may open only if all required v0.1.9.2 columns and
identity checks pass. Missing required saved-sweep tables or columns also raise
`ledgr_sweep_schema_incompatible`. v0.1.9.2 does not attempt migration.

## 7. Test fixture paths and names

All tests below are release-gate tests, not optional audit scripts.

### Canonical-series parity matrix

File: `tests/testthat/test-sweep-persistence-parity.R`.

Test names:

- `test_that("retained series match inline-memory summary on R accounting", ...)`;
- `test_that("retained series match inline-memory summary on compiled spot FIFO", ...)`;
- `test_that("retained series match ordered-event reconstruction on R accounting", ...)`;
- `test_that("retained series match ordered-event reconstruction on compiled spot FIFO", ...)`.

The two source paths are grounded in current code: the inline summary path is
selected at `R/sweep.R:956` through `R/sweep.R:957` and builds equity at
`R/sweep.R:1341` through `R/sweep.R:1378`; the ordered-event path calls
`ledgr_sweep_summary_from_ordered_events()` at `R/sweep.R:967`, whose
reconstruction emits equity rows at `R/fold-reconstruction.R:140` through
`R/fold-reconstruction.R:145`.

The compiled spot-FIFO tests may use `skip_if_not_installed()` or the existing
compiled-accounting availability guard, but the fixture row must remain in the
release-gate matrix.

### Identity orthogonality

File: `tests/testthat/test-sweep-persistence-identity.R`.

Test names:

- `test_that("retention policy is absent from execution assumptions and candidate identity", ...)`;
- `test_that("config hash payload defensively excludes forced sweep retention metadata", ...)`.

Assertions:

- same `cost_model_hash`;
- same `cost_plan_json`;
- same candidate reproduction key excluding storage-only materialization fields;
- same `config_hash`;
- same scalar candidate metrics;
- same execution seed;
- `attr(sweep, "sweep_retention")` exists;
- `attr(sweep, "execution_assumptions")$sweep_retention` is absent.

### Final-bar no-fill

File: `tests/testthat/test-sweep-persistence-returns.R`.

Test name:

- `test_that("retained returns preserve the final equity row after final-bar no-fill", ...)`.

Assertions:

- retained rows per completed candidate equal the scoring-pulse count;
- final `ts_utc` equals the final scoring pulse;
- the candidate summary row carries `LEDGR_LAST_BAR_NO_FILL`;
- final-row `period_return` is adjacent-row computed, not hard-coded to zero.

Existing final-bar warning behavior is already tested for committed runs at
`tests/testthat/test-backtest-wrapper.R:534`; v0.1.9.2 adds the retained-series
assertions for sweeps.

### Failed-candidate absence

File: `tests/testthat/test-sweep-persistence-returns.R`.

Test name:

- `test_that("failed candidates are absent from retained returns and explicit access fails", ...)`.

Assertions:

- failed candidate summary row exists with `status = "FAILED"`;
- retained returns contain no failed `candidate_id`;
- explicit access raises `ledgr_sweep_returns_candidate_not_completed`.

Current DONE/FAILED row semantics are grounded at `R/sweep.R:1451` and
`R/sweep.R:1487`, and candidate extraction already rejects failed candidates at
`R/sweep.R:290` through `R/sweep.R:291`.

### Persistence inspection and validation

File: `tests/testthat/test-sweep-persistence-roundtrip.R`.

Test names:

- `test_that("saved sweep list returns the bound inspection columns", ...)`;
- `test_that("sweep info reports identity, retention, grid, and audit metadata", ...)`;
- `test_that("invalid sweep ids fail before save or open writes", ...)`;
- `test_that("snapshot id absence and hash mismatch raise distinct conditions", ...)`.

Assertions:

- `ledgr_sweep_list(snapshot)` returns the Section 3 columns in descending
  `created_at_utc` order;
- `ledgr_sweep_info(x)` accepts in-memory and reopened sweep objects and
  rejects bare `sweep_id` strings;
- `ledgr_sweep_info(x)` reports the bound identity, retention, grid summary,
  candidate counts, and saved-artifact audit metadata;
- invalid `sweep_id` inputs raise `ledgr_invalid_sweep_id`;
- missing snapshot ids raise `ledgr_sweep_snapshot_not_found`;
- hash mismatches on existing snapshot ids raise
  `ledgr_sweep_snapshot_hash_mismatch`.

### Round-trip parity

File: `tests/testthat/test-sweep-persistence-roundtrip.R`.

Test name:

- `test_that("saved sweeps round-trip scalar rows, attributes, identity, and retained returns", ...)`.

Assertions:

- `ledgr_sweep_save()` then `ledgr_sweep_open()` reconstructs a
  `ledgr_sweep_results`-compatible object;
- scalar candidate rows match under canonical ordering;
- `sweep_retention`, metric-context attributes, feature identity attributes,
  cost identity, execution assumptions, and candidate reproduction keys match;
- retained return/equity rows match exactly under canonical ordering;
- duplicate `sweep_id` raises `ledgr_sweep_id_exists`.

Round-trip parity compares the bound identity surfaces and scalar rows
enumerated above. Reopened-only audit fields such as `created_at_utc`,
`engine_version`, stored `sweep_schema_version`, and durable `note` are set at
save time and are not part of in-memory/reopened parity. They are verified
through `ledgr_sweep_list()` and `ledgr_sweep_info()` tests instead.

### Reopened object survivability

File: `tests/testthat/test-sweep-persistence-roundtrip.R`.

Test names:

- `test_that("reopened sweeps remain candidate-compatible after dplyr filtering", ...)`;
- `test_that("reopened sweeps retain metadata after arrange and slice", ...)`.

Assertions:

- `ledgr_sweep_open()` returns an eager `ledgr_sweep_results`-compatible
  object, not a lazy DB handle;
- after `dplyr::filter(status == "DONE")`, the object still supports
  `ledgr_candidate()`;
- after `dplyr::arrange()` and `dplyr::slice(1)`, the object still has
  `sweep_retention`, cost identity, metric-context identity, feature identity,
  and candidate reproduction metadata;
- `ledgr_candidate()` on a filtered, sorted, or sliced reopened sweep captures
  the same filtered/sorted `selection_view` metadata as the in-session sweep
  path.

Implementation must provide one attribute-restoration path for both in-session
and reopened sweep results. Base row subsetting and `dplyr::filter()`,
`dplyr::arrange()`, and `dplyr::slice()` must preserve the bound sweep metadata
needed by `ledgr_candidate()`, return accessors, and saved-sweep inspection.
That restoration behavior may be implemented through class methods,
vctrs/dplyr reconstruction methods, or an equivalent package-owned helper, but
it must be shared by in-session and reopened sweep objects.

### Unsaved in-memory sweep ids

File: `tests/testthat/test-sweep-persistence-returns.R`.

Test name:

- `test_that("unsaved retained returns use the ephemeral in-session sweep id", ...)`.

Binding:

- in-memory sweeps use `attr(sweep, "sweep_id")` in returned retained-series
  rows;
- `ledgr_sweep_save(sweep, snapshot, sweep_id = NULL)` persists under that id;
- `ledgr_sweep_save(sweep, snapshot, sweep_id = "explicit")` persists under
  the supplied durable id and reopened return rows report `"explicit"`;
- `ledgr_sweep_save()` does not mutate the caller's in-memory sweep object.
  After save-with-explicit-id, accessors on the original object still report
  its in-session sweep id; accessors on `ledgr_sweep_open(snapshot,
  "explicit")` report the durable id.

### Wide accessor shape

File: `tests/testthat/test-sweep-persistence-returns.R`.

Test names:

- `test_that("wide retained returns and wide equity share the same timestamp spine", ...)`;
- `test_that("wide retained returns preserve leading NA while wide equity does not", ...)`.

Assertions:

- `ledgr_sweep_returns_wide(x, value = "returns")` and
  `ledgr_sweep_returns_wide(x, value = "equity")` have identical `ts_utc`
  values and candidate columns;
- the first candidate value row in the returns-wide result is `NA_real_`;
- the first candidate value row in the equity-wide result is finite when the
  candidate has a finite initial equity row;
- the wide helper raises the same classed retained-series conditions as the
  long helper before pivoting.

### Storage smoke measurement

File: `inst/design/ledgr_v0_1_9_2_spec_packet/sweep_retention_storage_smoke.md`.

Fixture:

- `ledgr_demo_bars`;
- instruments `DEMO_01` and `DEMO_02`;
- the first 1,260 distinct `ts_utc` values available for those instruments;
- the `vignettes/sweeps.qmd` SMA alias example grid, producing the same
  feature-grid and strategy-grid shape as the teaching article;
- `retain = ledgr_sweep_retention(returns = "none")` baseline versus
  `retain = ledgr_sweep_retention(returns = "completed")` retained run.

Acceptance ratio:

```text
expected_bytes = n_completed * n_pulses * 64
ratio = retained_db_delta_bytes / expected_bytes
```

`retained_db_delta_bytes` is the byte delta of the `sweep_returns` table only
between the `returns = "completed"` save and the `returns = "none"` baseline.
The `sweeps` and `sweep_candidates` tables contribute identical row counts to
both saves and are excluded from the delta.

The release gate passes when `ratio <= 2.0` and the actual measurement is
recorded. If the ratio exceeds `2.0`, the packet requires maintainer sign-off
with a written disposition before release. The smoke test is a storage sanity
gate, not a public performance benchmark.

The smoke document must also record DuckDB compressed table sizes by table and,
where DuckDB exposes it, by column family. The ratio is a release guardrail; the
size breakdown is what tells future optimization work whether repeated text
ids, indexes, timestamps, or numeric payload dominate storage.

### Classed errors

File: `tests/testthat/test-sweep-persistence-errors.R`.

Test names:

- `test_that("retained-return access fails clearly when returns were not retained", ...)`;
- `test_that("retained-return access distinguishes missing and failed candidates", ...)`;
- `test_that("sweep save and open raise classed persistence errors", ...)`;
- `test_that("incompatible saved-sweep schema fails closed", ...)`.

## 8. Walk-forward forward obligation

v0.1.9.2 does not implement walk-forward integration. It must leave an
additive path for v0.1.9.4.

Bound forward obligations:

- retained return rows may later gain `fold_seq` and train/test window columns;
- v0.1.9.2 candidate identity must not redefine walk-forward candidate identity;
- v0.1.9.4 owns per-fold/per-candidate retention and diagnostic-retention tiers;
- saved sweep artifacts may be consumed by walk-forward later, but v0.1.9.2
  does not create walk-forward sessions or selection protocols.

The roadmap already sequences walk-forward after cost identity, sweep
persistence, and risk identity (`inst/design/ledgr_roadmap.md:112`,
`inst/design/ledgr_roadmap.md:1343`, `inst/design/ledgr_roadmap.md:1353`).
The walk-forward synthesis records richer diagnostic retention as a future
obligation at
`inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md:555`
through
`inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md:563`.

## 9. Alpha-decay routing

v0.1.9.2 supports one layer: single-stream strategy return decay over retained
net strategy returns.

Deferred layers:

- benchmark-relative return decay waits for v0.2.x benchmark context and active
  metrics;
- signal decay waits for feature/forward-return/IC substrate;
- implementation and cost decay wait for gross-vs-net and cost-component
  attribution substrate.

The roadmap puts aligned benchmark/reference returns and active metrics in
v0.2.x (`inst/design/ledgr_roadmap.md:121`,
`inst/design/ledgr_roadmap.md:1775` through
`inst/design/ledgr_roadmap.md:1781`). The cost-API synthesis keeps v1 cost
retention scalar and routes component detail out of v0.1.9.1 at
`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:434`.

## 10. Minimum scope for the v0.1.9.2 packet

The packet must include:

1. `ledgr_sweep_retention()`.
2. `retain` argument on `ledgr_sweep()`, defaulting to scalar-only behavior.
3. `sweep_retention` non-identity attribute.
4. Defensive exclusion of `sweep_retention` from `config_hash_payload()`.
5. `ledgr_sweep_save()`, `ledgr_sweep_open()`, `ledgr_sweep_list()`,
   `ledgr_sweep_info()`, and print methods for reopened saved-sweep objects.
6. `ledgr_sweep_returns()` and `ledgr_sweep_returns_wide()`.
7. `sweeps`, `sweep_candidates`, and `sweep_returns` tables.
8. Round-trip persistence and reopen parity.
9. All tests named in Section 7.
10. Documentation and NEWS obligations from Sections 13 and 14.
11. Roadmap/horizon/design-index packet housekeeping.
12. Storage smoke measurement with the Section 7 acceptance ratio.

Non-scope items in Section 1 must not appear as hidden ticket work.

## 11. Future obligations recorded

The accepted post-synthesis horizon entry must record these deferrals:

- walk-forward per-fold/per-candidate return-series retention;
- signal decay substrate;
- implementation/cost-decay substrate and gross-vs-net definition;
- selection-integrity diagnostic helpers over retained returns;
- PerformanceAnalytics adapter;
- per-instrument and per-trade retention;
- cross-sweep comparison helpers;
- sweep extension/append semantics;
- structured sweep notes;
- `persist =` narrower than `retain =`;
- benchmark-relative return decay;
- snapshot-decoupled sweep reopening;
- saved-sweep schema migration.
- pushed-down or lazy wide-return pivots for very large saved sweeps.

These obligations do not authorize implementation in v0.1.9.2.

## 12. Open questions promoted to spec-cut

None. Seed v2 Section 13 questions Q1 through Q6 are bound in Section 5 of this
synthesis.

If ticket-cut discovers a genuine new product-level binary, it requires a
maintainer decision note rather than silent expansion inside the spec packet.

## 13. NEWS entry shape

Copy-edit from this paragraph at release close:

> `ledgr_sweep()` can now retain and persist compact sweep artifacts. The new
> `retain = ledgr_sweep_retention()` argument defaults to today's scalar-only
> sweep behavior; opting into `returns = "completed"` keeps net portfolio
> equity and pulse-aligned returns for completed candidates. Saved sweeps can be
> eagerly reopened from the experiment store as sweep-like result objects and
> queried through `ledgr_sweep_returns()` or
> `ledgr_sweep_returns_wide()`. Sweep result candidate identifiers are now
> named `candidate_id`; committed runs still use `run_id`. This release does
> not add ranking helpers, automatic selection, benchmark-relative alpha/beta
> diagnostics, signal-decay tooling, or gross-vs-net cost attribution; those
> remain routed to later benchmark-context, feature-analysis, and
> execution-attribution RFCs.

## 14. Vignette obligation

Source file: `vignettes/sweeps.qmd`.

Add these sections:

- `## Save And Reopen Sweep Artifacts`;
- `## Retain Candidate Return Series`;
- `## Three Evidence Tiers`;
- `## What Retained Returns Can And Cannot Validate`;
- `## Why ledgr And PerformanceAnalytics Metrics May Differ`.

Required content:

- show the three workflows: scalar-only screening, in-session retained returns,
  durable saved sweep with retained returns;
- state that retained returns are net strategy returns, not benchmark-relative
  returns;
- state that a saved sweep is not a batch of committed runs: it stores
  candidate summary evidence and, when requested, compact net equity/return
  series, while full ledgers, fills, trades, and per-instrument artifacts remain
  available only after explicit promotion;
- state that promotion from a reopened saved sweep re-executes the selected
  candidate from its reproduction key against the sealed snapshot;
- state that failed candidates remain in the summary but have no retained
  return rows;
- state that final-bar no-fill warnings do not remove the final equity row;
- state that PerformanceAnalytics metrics can differ from ledgr metric rows
  because annualization and return-shape conventions differ;
- show examples dropping the leading `NA_real_` in `period_return` before
  handing retained returns to external metric packages;
- preserve caller-owned ranking through dplyr and do not introduce a package
  ranking helper.

Generated `vignettes/sweeps.md` and `inst/doc/sweeps.html` update only through
the normal vignette build path.

## 15. Roadmap and horizon patches

After this synthesis is accepted and the spec packet opens, patch
`inst/design/ledgr_roadmap.md`:

- header lines 5 through 9: set the active packet to v0.1.9.2 and the active
  packet path to `inst/design/ledgr_v0_1_9_2_spec_packet/`;
- milestone table line 110: change v0.1.9.2 from Planned to Active and replace
  "RFC seed pending" with the new packet path;
- v0.1.9.2 section lines 1623 through 1642: replace "seed draft is still
  pending" with synthesis-accepted scope, including optional retained net
  equity/returns and explicit non-scope for ranking, benchmark diagnostics, and
  walk-forward integration.

After final review acceptance, patch `inst/design/horizon.md`:

- update the 2026-06-05 sweep RFC schedule entry at line 1618 from scheduled
  cycle to synthesis accepted/final review complete;
- add one post-synthesis direction entry that records the future obligations
  from Section 11, especially benchmark-relative return decay as the F11
  obligation tied to v0.2.x benchmark context;
- keep the entry non-authorizing: it records deferrals, not active scope.

## 16. Ticket-cut gate matrix

The v0.1.9.2 packet may not open or pass release gate unless the rows below are
satisfied.

| Gate item | Packet-open criterion | Release-gate criterion |
| --- | --- | --- |
| RFC closure | Seed v2, response, synthesis, and Claude final review are present; final-review patches, if any, are applied in place. | Release closeout cites the accepted synthesis and final review. |
| Scope discipline | Spec packet lists Section 1 non-scope items as forbidden hidden work. | No exported surface or docs imply ranking helpers, named selection views, benchmark diagnostics, signal decay, implementation/cost decay, or walk-forward integration. |
| API surface | Tickets name each function and classed condition in Sections 3 and 10. | Help pages, NAMESPACE, examples, and tests cover every new function and condition. |
| Identity exclusion | Tickets include `sweep_retention` attribute and config-hash exclusion work. | Section 7 identity tests pass and prove retention does not alter cost identity, candidate keys, config hash, scalar metrics, or execution seeds. |
| Schema | Packet binds `sweeps`, `sweep_candidates`, `sweep_returns`, schema version handling, and fail-closed old-schema behavior. | Round-trip tests pass; duplicate IDs reject; open missing snapshot raises `ledgr_sweep_snapshot_not_found`; snapshot hash mismatch raises `ledgr_sweep_snapshot_hash_mismatch`; incompatible saved-sweep schema raises `ledgr_sweep_schema_incompatible`; no migration machinery beyond the bound pre-CRAN fail-closed behavior is added. |
| Retained series semantics | Tickets include final-bar, failed-candidate, return-alignment, and summary-path parity fixtures. | All Section 7 tests pass across the required fixture matrix. |
| Storage smoke | Packet creates the smoke-measurement artifact path and fixture recipe. | Measurement is recorded at `inst/design/ledgr_v0_1_9_2_spec_packet/sweep_retention_storage_smoke.md`; ratio is `<= 2.0` or maintainer sign-off records why the packet ships anyway. |
| Documentation | Packet names `vignettes/sweeps.qmd` sections from Section 14 and man-page examples. | Vignette, man pages, and NEWS entry are present; generated docs are rebuilt through the normal release path. |
| Roadmap/horizon | Packet includes roadmap/horizon housekeeping tickets. | Roadmap and horizon patches from Section 15 are complete. |

Silent omission of a row fails the release gate.

## 17. Code verification of v2 load-bearing claims

Current sweep entry and metadata:

- `ledgr_sweep()` entry point begins at `R/sweep.R:77`.
- Cost identity attributes are attached at `R/sweep.R:230` and
  `R/sweep.R:231`.
- Execution assumptions are attached at `R/sweep.R:232` through
  `R/sweep.R:239`.
- Candidate reproduction keys carry cost identity at `R/sweep.R:386` and
  `R/sweep.R:387`.
- Candidate task payloads carry cost identity at `R/sweep.R:711` and
  `R/sweep.R:712`; failure and success provenance carry it at `R/sweep.R:737`,
  `R/sweep.R:738`, `R/sweep.R:995`, and `R/sweep.R:996`.

Cost identity and net-cost execution:

- Cost plan JSON and hash helpers are at `R/cost-model.R:286` and
  `R/cost-model.R:290` through `R/cost-model.R:291`.
- Cost resolver reconstruction from plan JSON is at `R/cost-model.R:389`.
- Cost resolution uses execution-bar open as price basis at
  `R/cost-model.R:411`, accumulates fees at `R/cost-model.R:412`,
  `R/cost-model.R:420`, and `R/cost-model.R:422`, rounds `fill_price` at
  `R/cost-model.R:425`, and returns fee at `R/cost-model.R:433`.
- Sweep candidate execution constructs the resolver from `exp$cost_plan_json`
  at `R/sweep.R:919`.

Return alignment:

- `compute_period_returns()` starts at `R/backtest.R:1421`.
- It returns zero rows for fewer than two equity values at `R/backtest.R:1423`,
  computes adjacent `prev` and `cur` vectors at `R/backtest.R:1424` and
  `R/backtest.R:1425`, and computes period returns at `R/backtest.R:1428`.
- Metrics consume the adjacent return vector at `R/backtest.R:1608`.

Final-bar no-fill and equity rows:

- The fold records equity facts before fill resolution at `R/fold-engine.R:208`
  through `R/fold-engine.R:214`.
- Final-bar no-fill warning emission is later in the compiled branch at
  `R/fold-engine.R:368` through `R/fold-engine.R:371` and again in the
  non-compiled branch at
  `R/fold-engine.R:452` through `R/fold-engine.R:455`.
- Durable equity uses `cash_at + positions_value` at
  `R/backtest-runner.R:1428`, builds non-empty rows over `pulses_posix` at
  `R/backtest-runner.R:1443` through `R/backtest-runner.R:1451`, and writes the
  table at `R/backtest-runner.R:1481` through `R/backtest-runner.R:1483`.

Two summary paths:

- Sweep uses the inline summary path when available at `R/sweep.R:956` through
  `R/sweep.R:957`.
- Otherwise it calls ordered-event reconstruction at `R/sweep.R:967`.
- The inline handler builds equity at `R/sweep.R:1341` through
  `R/sweep.R:1378`.
- The ordered-event reconstructor emits equity rows at
  `R/fold-reconstruction.R:140` through `R/fold-reconstruction.R:145`.

Identity exclusion:

- `config_hash()` hashes `config_hash_payload()` at `R/config-hash.R:1`
  through `R/config-hash.R:2`.
- Current exclusions are visible at `R/config-hash.R:5` through
  `R/config-hash.R:14`.
- Feature-definition ordering normalization follows at `R/config-hash.R:17`
  through `R/config-hash.R:24`; v0.1.9.2 must add retention exclusion without
  disturbing that behavior.

DONE/FAILED distinction:

- Candidate extraction detects failed candidates at `R/sweep.R:290` through
  `R/sweep.R:291`.
- Success rows bind `status = "DONE"` at `R/sweep.R:1451`.
- Failure rows bind `status = "FAILED"` at `R/sweep.R:1487`.
- This forecloses a meaningful `returns = "all"` v0.1.9.2 enum because failed
  candidates do not have retained return series.

Roadmap and predecessor-RFC grounding:

- v0.1.9.2 is the planned sweep artifact persistence tick at
  `inst/design/ledgr_roadmap.md:110` and `inst/design/ledgr_roadmap.md:1623`.
- Walk-forward consumes the v0.1.9.2 retention infrastructure later at
  `inst/design/ledgr_roadmap.md:112`.
- Benchmark context and active metrics are deferred to v0.2.x at
  `inst/design/ledgr_roadmap.md:121` and
  `inst/design/ledgr_roadmap.md:1775` through
  `inst/design/ledgr_roadmap.md:1781`.
- Cost-component retention remains deferred by the cost-API synthesis at
  `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:434`.

## 18. Recommendation

Final review proceeds. This synthesis binds all seed v2 spec-cut questions and
does not require a maintainer binary decision or seed v3.
