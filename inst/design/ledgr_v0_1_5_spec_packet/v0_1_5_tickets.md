# ledgr v0.1.5 Experiment Store Tickets

**Version:** 0.1.0  
**Date:** April 27, 2026  
**Total Tickets:** 9  
**Estimated Duration:** 3-5 weeks

---

## Ticket Organization

v0.1.5 makes DuckDB experiment stores a first-class user concept. The ticket
range starts at `LDG-801` to avoid collisions with v0.1.4 tickets.

The work is intentionally persistence- and identity-heavy. Under
`inst/design/model_routing.md`, most implementation tickets classify as Tier H
because they touch DuckDB schema/writes, run identity, strategy identity,
canonical JSON, or execution-adjacent pulse context behavior.

### Dependency DAG

```text
LDG-801 -> LDG-802 -> LDG-803 -> LDG-808 -> LDG-809
LDG-801 -----------> LDG-804 -> LDG-808 -> LDG-809
LDG-801 -> LDG-803 -> LDG-806 -> LDG-808 -> LDG-809
LDG-801 ---------------------> LDG-808 -> LDG-809
LDG-805 ---------------------> LDG-808 -> LDG-809
LDG-807 ---------------------> LDG-808 -> LDG-809
```

`LDG-809` is the v0.1.5 release gate. It should not be accepted until the
experiment-store APIs, audit regressions, contracts, NEWS, docs, tests, and CI
all match the accepted scope.

### Priority Levels

- **P0 (Blocker):** Required for the experiment-store model to be correct.
- **P1 (Critical):** Required for the release to feel coherent and auditable.
- **P2 (Important):** Required for discoverability or documentation quality.
- **P3 (Optional):** Useful, but not a release blocker.

---

## LDG-801: Experiment Store Schema And Migration Protocol

**Priority:** P0  
**Effort:** 2-3 days  
**Dependencies:** None  
**Status:** Done

**Description:**
Add the v0.1.5 experiment-store schema foundation and defensive migration
protocol. This ticket creates the durable place where later tickets can store
run provenance, strategy identity, telemetry summaries, labels, archive state,
and schema version information.

Read-only APIs must be able to inspect old stores without mutating them. Write
APIs may perform additive migrations, but migrations must be transactional where
possible and update `schema_version` last.

**Tasks:**
1. Define the v0.1.5 logical schema for run metadata, strategy provenance, and
   dependency versions.
2. Add `schema_version` handling for experiment-store metadata.
3. Implement a schema-version check used before experiment-store reads/writes.
4. Ensure read-only discovery can classify legacy/pre-provenance stores without
   mutating the file.
5. Implement additive write-triggered migration for old stores.
6. Wrap migration in a DuckDB transaction where possible.
7. Update `schema_version` only after all migration steps succeed.
8. Fail clearly when a file advertises a schema newer than the installed ledgr
   understands.
9. Preserve existing v0.1.4 run, snapshot, ledger, feature, and equity tables.
10. Define and test `data_hash` as the run-level input-window hash, not the
    deprecated public `ledgr_data_hash()` helper.
11. Define valid v0.1.5 `execution_mode` values: `audit_log` and `db_live`.

**Acceptance Criteria:**
- [x] Existing v0.1.4 databases remain readable.
- [x] Existing v0.1.4 run rows, ledger events, feature rows, and equity curves
      remain readable after migration.
- [x] Read-only schema inspection does not mutate legacy databases.
- [x] Write-triggered migration is additive and non-destructive.
- [x] Failed migration leaves the store readable at the previous schema version.
- [x] Future-schema databases fail with a classed error.
- [x] `data_hash` is documented and tested as the run input-window hash.
- [x] Valid `execution_mode` values are constrained to `audit_log` and
      `db_live` for v0.1.5.

**Test Requirements:**
- New schema/migration tests.
- Existing `tests/testthat/test-db-schema*.R` tests.
- Legacy-store fixture or generated pre-v0.1.5 database.
- Failure-path test for future `schema_version`.
- Failure-path test for interrupted/failed migration if practical.

**Source Reference:** v0.1.5 spec sections 4.1, 4.2, 4.5.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  Touches DuckDB schema, migrations, persistence, restart safety, run identity
  fields, and legacy-store compatibility. These are hard-escalation areas under
  the model routing rulebook.
invariants_at_risk:
  - DuckDB schema compatibility
  - restart and resume safety
  - legacy run discoverability
  - run input identity
  - no silent mutation from read-only APIs
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_5_spec_packet/v0_1_5_spec.md
  - inst/design/contracts.md (Persistence Contract, Snapshot Contract, Canonical JSON Contract)
  - R/db-schema-create.R
  - R/db-schema-validate.R
  - R/backtest-runner.R
  - R/data-hash.R
tests_required:
  - legacy store can be inspected without mutation
  - write-triggered migration is additive
  - schema_version is updated last
  - future schema versions fail clearly
  - data_hash remains run-window identity, not public legacy ledgr_data_hash()
escalation_triggers:
  - migration requires destructive table rebuilds
  - schema change affects ledger event semantics
  - data_hash semantics conflict with resume logic
  - migration cannot be made transaction-safe
forbidden_actions:
  - silently overwriting existing run rows
  - mutating legacy stores from read-only APIs
  - downgrading newer schema versions
  - changing snapshot_hash semantics
```

---

## LDG-802: Strategy Params And Provenance Capture

**Priority:** P0  
**Effort:** 3-4 days  
**Dependencies:** LDG-801  
**Status:** Done

**Description:**
Make strategy parameters and strategy provenance part of durable experiment
identity. `ledgr_backtest()` must support both `function(ctx)` and
`function(ctx, params)` strategies, store JSON-safe `strategy_params`, capture
strategy source text where possible, and write hashes and reproducibility tiers
to the experiment store.

**Tasks:**
1. Add `strategy_params = list()` to `ledgr_backtest()`.
2. Support `function(ctx)` and `function(ctx, params)` strategy signatures.
3. Treat `function(ctx, params)` with default `strategy_params = list()` as
   valid; the strategy receives an empty list.
4. Fail clearly for unsupported strategy signatures. In v0.1.5, only
   `function(ctx)` and `function(ctx, params)` are valid; for example,
   `function(ctx, params, extra)` must fail.
5. Validate that `strategy_params` are canonical-JSON serializable.
6. Hash `strategy_params` through the canonical JSON path.
7. Capture functional strategy source text where possible.
8. Hash captured strategy source text.
9. Store strategy type, source text, source hash, params JSON, params hash, and
   capture method.
10. Store ledgr version, R version, and relevant dependency versions.
11. Classify functional strategies into reproducibility tiers.
12. Classify R6 strategies as Tier 2 by default unless a future explicit
    metadata contract is implemented.
13. Mark old runs without provenance as legacy/pre-provenance.
14. Document that `strategy_source_hash` is meaningful for direct comparison
    only between runs with the same `R_version`.
15. Document the existing `NULL`/`NA` canonical JSON collision for params.

**Acceptance Criteria:**
- [x] `function(ctx)` strategies remain supported.
- [x] `function(ctx, params)` strategies receive `strategy_params`.
- [x] `function(ctx, params)` with `strategy_params = list()` receives an empty
      list and is valid.
- [x] Unsupported signatures such as `function(ctx, params, extra)` fail
      clearly.
- [x] Changing `strategy_params` changes `strategy_params_hash`.
- [x] Changing strategy source changes `strategy_source_hash`.
- [x] Non-JSON-safe params fail with a classed actionable error.
- [x] R6 strategies are not classified as Tier 1 by default.
- [x] Stored run metadata includes strategy source hash, params hash, ledgr
      version, R version, dependency versions, and reproducibility level.
- [x] Legacy/pre-provenance runs are labeled clearly.

**Test Requirements:**
- New strategy identity tests.
- Existing functional strategy tests.
- R6 strategy coverage if current tests include R6 strategies.
- Canonical JSON hashing tests for strategy params.
- Tests for unsupported strategy signature.
- Test for `function(ctx, params)` with empty default `strategy_params`.
- Tests for R-version-sensitive hash note in docs or run info.

**Source Reference:** v0.1.5 spec sections 2.R4-R6, 3.1, 4.3, 4.4, 5.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  Touches strategy execution calling convention, strategy source capture,
  canonical JSON, strategy parameter hashing, dependency version provenance,
  and experiment identity. These are hard-escalation identity and execution
  areas.
invariants_at_risk:
  - strategy call semantics
  - target validation must remain unchanged
  - canonical JSON identity
  - strategy source and params hashes
  - reproducibility tier correctness
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_5_spec_packet/v0_1_5_spec.md
  - inst/design/contracts.md (Strategy Contract, Canonical JSON Contract)
  - R/backtest.R
  - R/backtest-runner.R
  - R/config-canonical-json.R
  - R/strategy-contracts.R
  - R/config-validate.R
tests_required:
  - function(ctx) remains valid
  - function(ctx, params) receives params
  - unsupported signature errors
  - params hash changes when params change
  - source hash changes when source changes
  - R6 strategy defaults to Tier 2
  - non-JSON-safe params fail clearly
escalation_triggers:
  - implementation changes strategy output validation
  - implementation touches fill timing or pulse order
  - static source analysis becomes broader than specified
  - canonical JSON behavior must change
forbidden_actions:
  - serializing closure environments wholesale
  - treating R6 strategies as Tier 1 by default
  - changing target-vector validation semantics
  - evaluating recovered strategy source
```

---

## LDG-803: Run Discovery, Info, And Reopen APIs

**Priority:** P0  
**Effort:** 3-4 days  
**Dependencies:** LDG-801, LDG-802  
**Status:** Done

**Description:**
Add the core experiment-store discovery APIs:
`ledgr_run_list()`, `ledgr_run_info()`, and `ledgr_run_open()`.

`ledgr_run_open()` must return a `ledgr_backtest`-compatible handle for
completed runs without recomputation. `ledgr_run_info()` must return an S3
`ledgr_run_info` object with a concise print method.

**Tasks:**
1. Implement `ledgr_run_list(db_path, include_archived = FALSE)`.
2. Include run identity, provenance, status, archive state, telemetry summary,
   and basic result summary columns in `ledgr_run_list()`.
3. Implement `ledgr_run_info(db_path, run_id)` returning class
   `ledgr_run_info`.
4. Implement `print.ledgr_run_info()`.
5. Implement `ledgr_run_open(db_path, run_id)`.
6. Ensure reopened handles support `summary()`, `plot()`,
   `tibble::as_tibble()`, `ledgr_results()`, and `close()`.
7. Ensure `ledgr_run_open()` does not execute strategy code, recompute fills,
   or mutate runs by default.
8. Make `ledgr_run_open()` fail with a classed error for failed, interrupted,
   running, or otherwise incomplete runs.
9. Ensure archived completed runs can be opened.
10. Ensure legacy/pre-provenance runs are listed and explained.
11. Ensure runs created before LDG-806 telemetry persistence have absent or
    `NA` telemetry fields in `ledgr_run_info()` and this is not treated as an
    error.

**Acceptance Criteria:**
- [x] Multiple runs in one DuckDB file are discoverable.
- [x] `ledgr_run_info()` returns class `ledgr_run_info`.
- [x] `print.ledgr_run_info()` is concise and readable.
- [x] `ledgr_run_open()` returns a `ledgr_backtest`-compatible handle for
      completed runs.
- [x] Reopened handles support existing result methods.
- [x] Incomplete runs fail clearly on open.
- [x] `ledgr_run_info()` provides diagnostics for incomplete runs.
- [x] No strategy code executes during reopen.

**Test Requirements:**
- New run-store API tests.
- Tests for completed, failed, running, archived, and legacy/pre-provenance
  runs.
- Tests that reopened handles support `summary()`, `plot()`,
  `tibble::as_tibble()`, and `ledgr_results()`.
- Tests that reopen does not mutate run rows.
- Tests that absent telemetry fields are tolerated and displayed as missing or
  `NA`.

**Source Reference:** v0.1.5 spec sections 3.2, 3.3, 3.4, 8.1.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  Adds public experiment-store APIs over persistent DuckDB artifacts and
  hydrates ledgr_backtest-compatible handles. This touches persistence,
  public API, run identity, and derived result access.
invariants_at_risk:
  - reopened runs must not recompute or mutate execution artifacts
  - run status handling
  - legacy run labeling
  - result method compatibility
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_5_spec_packet/v0_1_5_spec.md
  - inst/design/contracts.md (Persistence Contract, Result Contract)
  - R/backtest.R
  - R/backtest-runner.R
  - R/derived-state.R
  - R/public-api.R
  - R/db-schema-create.R
tests_required:
  - ledgr_run_list lists multiple runs
  - ledgr_run_info has class and print method
  - ledgr_run_open reopens completed runs without recomputation
  - ledgr_run_open rejects incomplete runs
  - archived completed runs can be opened
  - reopened handles support existing result helpers
escalation_triggers:
  - implementation needs partial-run handles
  - implementation changes result reconstruction semantics
  - implementation needs to execute strategy source during reopen
forbidden_actions:
  - recomputing fills during ledgr_run_open()
  - mutating run artifacts during ledgr_run_open()
  - silently opening failed/incomplete runs as if complete
  - adding comparison APIs in v0.1.5
```

---

## LDG-804: Run Labels And Archive Metadata

**Priority:** P1  
**Effort:** 1-2 days  
**Dependencies:** LDG-801
**Status:** Done

**Description:**
Add metadata-only run management APIs:
`ledgr_run_label()` and `ledgr_run_archive()`.

`run_id` remains immutable. Labels are mutable human names. Archival is
non-destructive cleanup that hides runs from default list views while keeping
them auditable.

**Tasks:**
1. Implement `ledgr_run_label(db_path, run_id, label)`.
2. Validate labels according to the v0.1.5 spec.
3. Allow labels on any run status, including failed and incomplete runs.
4. Ensure label changes do not alter identity hashes.
5. Implement `ledgr_run_archive(db_path, run_id, reason = NULL)`.
6. Allow archive on any run status, including failed and incomplete runs.
7. Store archive timestamp and optional reason.
8. Make double-archival idempotent without rewriting original archive metadata.
9. Document that archiving a currently executing run is undefined and need not
   be supported in v0.1.5; implementations may fail clearly for in-progress
   status rather than attempting to coordinate with an active runner.
10. Ensure `ledgr_run_list()` hides archived runs by default and shows them when
   `include_archived = TRUE`.
11. Ensure `ledgr_run_info()` reports archive state.

**Acceptance Criteria:**
- [x] Labels can be set and updated without changing `run_id`.
- [x] Label changes do not alter experiment identity hashes.
- [x] Failed and incomplete runs can be labeled.
- [x] Runs can be archived without deleting artifacts.
- [x] Failed and incomplete runs can be archived.
- [x] In-progress archive behavior is documented; if unsupported, it fails
      clearly.
- [x] Double archive is idempotent and preserves original archive metadata.
- [x] Archived runs are hidden by default but visible when requested.

**Test Requirements:**
- New metadata mutation tests.
- Tests for completed, failed, incomplete, and archived runs.
- Tests for idempotent archival.
- Tests that label/archive writes do not change identity hashes.

**Source Reference:** v0.1.5 spec sections 3.5, 3.6, 8.1.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  Although behavior is metadata-only, this ticket writes to DuckDB experiment
  store state and changes public API surface. DuckDB writes are a hard
  escalation area.
invariants_at_risk:
  - run_id immutability
  - experiment identity hashes must not change on metadata edits
  - archive must remain non-destructive
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_5_spec_packet/v0_1_5_spec.md
  - inst/design/contracts.md (Persistence Contract)
  - R/db-schema-create.R
  - R/backtest-runner.R
  - run APIs introduced by LDG-803
tests_required:
  - label update does not alter identity hashes
  - archive hides run from default list
  - include_archived lists archived runs
  - archive works for failed and incomplete runs
  - double archive is idempotent
escalation_triggers:
  - implementation requires hard delete or unarchive
  - archive affects result methods or run open semantics beyond spec
  - metadata writes require non-additive migration
forbidden_actions:
  - renaming run_id
  - deleting run artifacts
  - rewriting original archive timestamp on second archive call
  - changing strategy or config hashes during metadata edits
```

---

## LDG-805: Audit UX Fixes - Feature Lookup And Snapshot IDs

**Priority:** P1  
**Effort:** 1-2 days  
**Dependencies:** None

**Description:**
Fix the two audit-derived UX footguns that do not require the full run-store API:
unknown feature IDs must fail loudly, and intentional snapshot IDs must not
generate noisy canonical-format warnings.

**Tasks:**
1. Update runtime `ctx$feature()` to distinguish unknown feature ID from known
   feature warmup `NA`.
2. Update interactive pulse contexts consistently.
3. Raise a classed condition for unknown feature IDs naming the feature,
   instrument, and available feature IDs.
4. Preserve valid warmup `NA` behavior for known features.
5. Update docs for `ctx$feature()` behavior.
6. Change snapshot ID validation so explicit durable names do not warn merely
   for not matching generated-ID format.
7. Keep generated snapshot IDs in canonical form.
8. Warn or error only for genuinely suspicious malformed generated-style IDs.
9. Add regression tests based on the audit typo `returns_20` vs `return_20`.

**Acceptance Criteria:**
- [x] Unknown `ctx$feature()` IDs fail loudly with a classed condition.
- [x] Error message lists available feature IDs.
- [x] Known features during warmup still return expected `NA` behavior.
- [x] Runtime and `ledgr_pulse_snapshot()` contexts behave consistently.
- [x] Explicit noncanonical snapshot IDs no longer produce the old noisy
      warning.
- [x] Generated snapshot IDs remain canonical.
- [x] Malformed generated-style IDs still produce useful diagnostics.

**Test Requirements:**
- `tests/testthat/test-pulse-context-accessors.R`
- `tests/testthat/test-indicator-tools.R`
- Snapshot adapter tests.
- New audit regression test for a mistyped feature ID.

**Source Reference:** v0.1.5 spec sections 2.R7, 6.1, 6.2, 8.3.

**Classification:**
```yaml
risk_level: medium
implementation_tier: H
review_tier: H
classification_reason: >
  Touches pulse context behavior used during strategy execution and snapshot ID
  validation. The changes are bounded but affect runtime strategy authoring and
  snapshot UX, so Tier H implementation is warranted.
invariants_at_risk:
  - feature warmup NA semantics
  - strategy runtime context behavior
  - snapshot ID validation
  - generated snapshot ID convention
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_5_spec_packet/v0_1_5_spec.md
  - inst/design/ledgr_v0_1_5_spec_packet/ledgr_v0_1_4_audit_report.md
  - inst/design/contracts.md (Context Contract, Snapshot Contract)
  - R/pulse-context.R
  - R/features-engine.R
  - R/snapshot_adapters.R
tests_required:
  - unknown feature ID errors with available IDs
  - known warmup feature returns NA as before
  - runtime and pulse_snapshot contexts match
  - explicit custom snapshot IDs do not warn
  - generated snapshot IDs remain canonical
escalation_triggers:
  - implementation changes feature computation or caching
  - implementation changes snapshot hash or sealing semantics
  - unknown feature handling cannot distinguish warmup from typo
forbidden_actions:
  - changing indicator warmup rules
  - changing feature values or alignment
  - banning custom snapshot IDs
  - mutating snapshot artifacts during validation
```

---

## LDG-806: Persisted Telemetry Summary And Execution Mode Visibility

**Priority:** P1  
**Effort:** 1-2 days  
**Dependencies:** LDG-801, LDG-803

**Description:**
Persist a compact run telemetry summary so stored runs remain explainable after
the original R session is gone. Also make execution mode visible in
`print.ledgr_backtest()` and `ledgr_run_info()`.

**Tasks:**
1. Persist execution mode for each run.
2. Persist elapsed wall time.
3. Persist feature cache hits and misses.
4. Persist whether features were stored in DuckDB (`persist_features`).
5. Keep detailed `ledgr_backtest_bench()` session-scoped.
6. Update `ledgr_run_info()` to show persisted telemetry summary.
7. Update `print.ledgr_backtest()` to show execution mode.
8. Ensure failed runs record the minimum durable telemetry fields:
   `status = "FAILED"`, `execution_mode`, and `elapsed_sec` up to the failure
   point when measurable. If elapsed time or cache counts are unavailable at
   failure time, store `NA` rather than omitting or inventing values.
9. Add tests that reopen a run in a fresh handle and still see telemetry
   summary.

**Acceptance Criteria:**
- [x] `print.ledgr_backtest()` shows execution mode.
- [x] `ledgr_run_info()` shows execution mode.
- [x] `ledgr_run_info()` shows elapsed seconds, cache hits, cache misses, and
      `persist_features`.
- [x] Persisted telemetry survives a fresh handle/session.
- [x] Failed runs record execution mode and status; elapsed time and cache
      counts are stored when available and otherwise represented as `NA`.
- [x] `ledgr_backtest_bench()` remains a detailed session-scoped helper.
- [x] No full per-component telemetry table is persisted in v0.1.5.

**Test Requirements:**
- Telemetry persistence tests.
- `print.ledgr_backtest()` snapshot or expectation test.
- `ledgr_run_info()` print test.
- Existing feature-cache telemetry tests.

**Source Reference:** v0.1.5 spec sections 2.R9, 3.2, 3.4, 4.1, 6.3, 6.4.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  Writes telemetry summary fields into persistent run metadata and changes
  public print behavior. This touches DuckDB writes, run metadata, and public
  diagnostics.
invariants_at_risk:
  - run metadata consistency
  - feature cache telemetry counts
  - execution mode visibility
  - session-scoped detailed telemetry remains separate
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_5_spec_packet/v0_1_5_spec.md
  - inst/design/ledgr_v0_1_5_spec_packet/ledgr_v0_1_4_audit_report.md
  - inst/design/contracts.md (Persistence Contract, Result Contract)
  - R/backtest-runner.R
  - R/backtest.R
  - R/feature-cache.R
  - run APIs introduced by LDG-803
tests_required:
  - telemetry summary persisted on successful run
  - run_info reports telemetry after reopening
  - print.ledgr_backtest reports execution mode
  - ledgr_backtest_bench remains session-scoped
  - cache hit/miss counts remain accurate
escalation_triggers:
  - implementation needs to persist full telemetry tables
  - telemetry fields conflict with feature-cache tests
  - execution_mode values beyond audit_log/db_live are needed
forbidden_actions:
  - changing feature cache key semantics
  - replacing ledgr_backtest_bench() with persisted-only telemetry
  - adding wall-clock assertions to tests
```

---

## LDG-807: Package-Prefixed Result Wrapper

**Priority:** P2  
**Effort:** 0.5-1 day  
**Dependencies:** None  
**Status:** Done

**Description:**
Add `ledgr_results()` as a package-prefixed discovery helper over the existing
S3 result path. The wrapper solves the audit finding that users must already
know to call `tibble::as_tibble(bt, what = ...)`.

**Tasks:**
1. Implement `ledgr_results(bt, what = c("equity", "fills", "trades", "ledger"))`.
2. Delegate to `tibble::as_tibble(bt, what = what)`.
3. Preserve the exhaustive v0.1.5 `what` set.
4. Export and document `ledgr_results()`.
5. Add examples using temporary data.
6. Add tests for all supported `what` values.
7. Ensure no mutation of backtest object or persistent run state.

**Acceptance Criteria:**
- [x] `ledgr_results(bt, "equity")` matches `tibble::as_tibble(bt, what = "equity")`.
- [x] `ledgr_results(bt, "fills")` matches the existing result path.
- [x] `ledgr_results(bt, "trades")` matches the existing result path.
- [x] `ledgr_results(bt, "ledger")` matches the existing result path.
- [x] Unsupported `what` values fail clearly.
- [x] Function is exported, documented, and covered by examples.

**Test Requirements:**
- Result wrapper tests.
- `tests/testthat/test-backtest-s3.R`.
- Export surface test.
- Roxygen/documentation check.

**Source Reference:** v0.1.5 spec sections 3.7, 6.5, 8.1.

**Classification:**
```yaml
risk_level: low
implementation_tier: M
review_tier: M
classification_reason: >
  Contained public API addition that delegates to the existing result path.
  It does not alter result reconstruction or persistence semantics.
invariants_at_risk:
  - wrapper must not become an alternate result implementation
  - supported what values must match as_tibble.ledgr_backtest()
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_5_spec_packet/v0_1_5_spec.md
  - inst/design/contracts.md (Result Contract)
  - R/backtest.R
  - tests/testthat/test-backtest-s3.R
tests_required:
  - wrapper matches tibble::as_tibble() for all supported values
  - unsupported what errors
  - exported and documented
escalation_triggers:
  - implementation touches ledgr_compute_equity_curve()
  - implementation touches ledger reconstruction
  - implementation adds new result types
forbidden_actions:
  - duplicating result reconstruction code
  - mutating run state
  - expanding what values beyond the spec without review
```

---

## LDG-808: Documentation, Contracts, And Site Updates

**Priority:** P1  
**Effort:** 1-2 days  
**Dependencies:** LDG-801, LDG-802, LDG-803, LDG-804, LDG-805, LDG-806, LDG-807

**Description:**
Update user-facing and agent-facing documentation so v0.1.5's experiment-store
model is visible, coherent, and aligned with implementation.

**Tasks:**
1. Update `contracts.md` with the experiment-store contract.
2. Update `contracts.md` for strategy params, provenance tiers, schema
   migration, strict feature lookup, and run API lifecycle.
3. Update `NEWS.md`.
4. Add reference docs and examples for all new exported functions.
5. Add or update pkgdown articles explaining the experiment-store model.
6. Keep README concise; link to deeper docs rather than bloating onboarding.
7. Ensure examples remain offline-safe and use temporary files.
8. Add pkgdown navigation entries for new articles/functions if needed.
9. State clearly that comparison and strategy recovery are v0.1.6 scope.
10. Update `vignettes/research-to-production.Rmd` to reference the v0.1.5
    experiment-store APIs once they exist, especially `ledgr_run_list()`,
    `ledgr_run_open()`, and `ledgr_run_info()`.

**Acceptance Criteria:**
- [x] `contracts.md` matches v0.1.5 behavior.
- [x] `NEWS.md` lists public API additions and behavior changes.
- [x] Every new exported function has offline-safe examples.
- [x] pkgdown navigation includes new user-facing docs where appropriate.
- [x] Docs explain `run_id`, `label`, archive, legacy/pre-provenance runs, and
      strategy params.
- [x] `vignettes/research-to-production.Rmd` explains the v0.1.5
      experiment-store role in the research-to-production arc.
- [x] Docs do not imply v0.1.5 supports comparison or strategy recovery.

**Test Requirements:**
- `devtools::document()` or `roxygen2::roxygenise()`.
- `R CMD check --no-manual --no-build-vignettes`.
- `pkgdown::build_site()`.
- README/vignette render checks if changed.

**Source Reference:** v0.1.5 spec sections 1, 7, 8.4.

**Classification:**
```yaml
risk_level: medium
implementation_tier: H
review_tier: H
classification_reason: >
  Mostly documentation, but it modifies contracts.md and documents public API
  lifecycle. Contract modifications are Tier H under the model routing rules.
invariants_at_risk:
  - docs must match public API
  - contracts must not overpromise comparison or recovery
  - examples must remain offline-safe
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_5_spec_packet/v0_1_5_spec.md
  - inst/design/contracts.md
  - NEWS.md
  - README.Rmd
  - vignettes
  - _pkgdown.yml
tests_required:
  - roxygen/documentation generation
  - R CMD check
  - pkgdown build
  - README/vignette render if changed
escalation_triggers:
  - documentation requires changing public API semantics
  - examples need network access
  - contracts conflict with implementation
forbidden_actions:
  - documenting v0.1.6 APIs as available in v0.1.5
  - adding live/paper/sweep content to v0.1.5 docs
  - using non-offline examples
```

---

## LDG-809: v0.1.5 Experiment Store Gate

**Priority:** P0  
**Effort:** 1 day  
**Dependencies:** LDG-801, LDG-802, LDG-803, LDG-804, LDG-805, LDG-806, LDG-807, LDG-808

**Description:**
Final validation gate for v0.1.5. This ticket verifies that the
experiment-store core is coherent, documented, covered, and green in CI.

**Tasks:**
1. Verify the v0.1.5 spec, tickets, contracts, and NEWS agree.
2. Run all v0.1.5 targeted tests.
3. Run v0.1.4 regression tests.
4. Run acceptance tests from earlier v0.1.x cycles where applicable.
5. Run coverage gate.
6. Run package check.
7. Build pkgdown.
8. Confirm Ubuntu and Windows CI are green.
9. Confirm no v0.1.6 APIs were accidentally exposed.

**Acceptance Criteria:**
- [x] `R CMD check --no-manual --no-build-vignettes` passes with 0 errors and
      0 warnings.
- [x] Coverage remains at or above the project gate.
- [x] pkgdown site builds.
- [x] README and vignettes remain offline-safe.
- [x] Ubuntu and Windows CI are green.
- [x] `contracts.md` and `NEWS.md` match the implemented scope.
- [x] All v0.1.5 acceptance criteria are satisfied.
- [x] No open P0/P1 review findings remain.

**Local Gate Evidence (2026-04-28):**
- `devtools::test()` passed with 1138 passing tests, 0 failures, 0 warnings,
  and 1 expected skip.
- `tools/check-readme-example.R` passed under installed-package semantics.
- `tools/check-coverage.R` reported 83.03% coverage, above the 80% gate.
- `devtools::check(args = c("--no-manual", "--no-build-vignettes"))` passed
  with 0 errors and 0 warnings. The only note was the local Windows clock
  verification note: "unable to verify current time."
- `pkgdown::build_site(new_process = FALSE, install = TRUE)` completed.
- Export scan found no accidental v0.1.6 API exposure. Future sweep APIs only
  appear in non-evaluated roadmap/article examples.
- Ubuntu and Windows CI were confirmed green after the local gate commit.

**Test Requirements:**
- `tools/check-coverage.R`
- `tools/check-readme-example.R` if README changes
- `R CMD check --no-manual --no-build-vignettes`
- `pkgdown::build_site()`
- `.github/workflows/R-CMD-check.yaml`

**Source Reference:** v0.1.5 spec section 8.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: H
review_tier: H
classification_reason: >
  Release gate and final Tier H review for the v0.1.5 experiment-store cycle.
  Validates all contracts, public APIs, tests, CI, docs, and acceptance
  criteria.
invariants_at_risk:
  - all v0.1.5 contracts
  - experiment-store identity and provenance
  - persistence and migration safety
  - public API surface
  - release quality gates
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_5_spec_packet/v0_1_5_spec.md
  - inst/design/ledgr_v0_1_5_spec_packet/v0_1_5_tickets.md
  - inst/design/contracts.md
  - NEWS.md
  - tools/check-coverage.R
  - tools/check-readme-example.R
  - .github/workflows/R-CMD-check.yaml
  - all v0.1.5 review findings
tests_required:
  - all targeted v0.1.5 tests pass
  - earlier v0.1.x regression tests pass where applicable
  - R CMD check passes with 0 errors and 0 warnings
  - coverage gate passes
  - pkgdown builds
  - Ubuntu and Windows CI are green
escalation_triggers: []
forbidden_actions:
  - accepting the gate with open P0 or P1 issues
  - bypassing R CMD check or coverage
  - releasing without green CI
  - accepting accidental v0.1.6 API scope
```

---

## Out Of Scope

Do not implement these in v0.1.5:

- run comparison tables;
- strategy extraction or strategy revival;
- tags;
- hard delete;
- persistent feature cache;
- parameter sweep mode;
- live trading;
- paper trading;
- broker adapters;
- streaming data;
- performance rewrites of the pulse loop or DuckDB write path.
