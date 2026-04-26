# ledgr v0.1.4 Stabilisation Tickets

**Version:** 1.0.0  
**Date:** April 26, 2026  
**Total Tickets:** 14  
**Estimated Duration:** 2-3 weeks

---

## Ticket Organization

v0.1.4 is a stabilisation and research-loop release. It should make the
post-v0.1.3 package safer to use for repeated research scripts and parameter
sweeps before the larger experiment-store API is finalized.

The ticket range starts at `LDG-701` to avoid collisions with v0.1.3 tickets.

### Dependency DAG

```text
LDG-701 -> LDG-702 -> LDG-714
LDG-701 -> LDG-703 -> LDG-714
LDG-701 -> LDG-704 -> LDG-714
LDG-701 -> LDG-705 -> LDG-714
LDG-706 ------------------> LDG-714

LDG-708 -> LDG-711 -> LDG-714
LDG-709 -----------> LDG-714
LDG-710 -> LDG-711 -> LDG-714

LDG-712 -> LDG-713 -> LDG-714
```

`LDG-714` is the stabilisation gate. It should not be accepted until contracts,
NEWS, tests, reference docs, and release checks reflect the accepted scope.
`LDG-707` is optional and is not a release-gate dependency unless the team
chooses to add public indicator deregistration in v0.1.4.

### Priority Levels

- **P0 (Blocker):** Required before v0.1.4 design or release validation can be trusted
- **P1 (Critical):** Required for the research workflow to feel coherent
- **P2 (Important):** Required for documentation quality and maintainability
- **P3 (Optional):** Useful, but not a release blocker

---

## LDG-701: Compatibility Policy and Design-File Hygiene

**Priority:** P0  
**Effort:** 0.5 days  
**Dependencies:** None

**Description:**
Document the v0.x compatibility policy and normalize v0.1.4 design inputs before
implementation begins. v0.1.3 is public, so exported API removals and behavior
changes must be deliberate and visible.

**Tasks:**
1. Add a v0.x compatibility policy to the design docs.
2. State that breaking changes are allowed during v0.x only when they protect
   correctness or simplify the public model.
3. Require `NEWS.md` entries for all breaking changes and deprecations.
4. State that deprecation should pass through one release where practical.
5. Update `inst/design/contracts.md` to summarize or link the policy.
6. Normalize v0.1.4 design inputs to clean UTF-8 or plain ASCII.
7. Remove mojibake from v0.1.4 design documents.

**Acceptance Criteria:**
- [x] v0.x compatibility policy is present in design docs.
- [x] `contracts.md` records the compatibility policy.
- [x] `NEWS.md` is named as mandatory for deprecations and breaking changes.
- [x] v0.1.4 design inputs no longer contain mojibake.
- [x] The policy is referenced by tickets that change exported APIs.

**Test Requirements:**
- `rg -n "[^\\x00-\\x7F]" inst/design/ledgr_v0_1_4_spec_packet`
- Manual review of `contracts.md`

**Source Reference:** Pre-Gate: Compatibility Policy; Pre-Gate: Design-File Encoding Hygiene

---

## LDG-702: Strategy Identity and Reproducibility Tiers

**Priority:** P0 (release-critical, not implementation-blocking)  
**Effort:** 0.5-1 day  
**Dependencies:** LDG-701

**Description:**
Decide how functional and R6 strategies are represented in the future
experiment-store identity model. This must be explicit before run identity is
finalized. This ticket does not block unrelated implementation work such as
snapshot loading, context helpers, or indicator performance; it blocks the
v0.1.4 stabilisation gate and any final run-identity design.

**Tasks:**
1. Define strategy reproducibility tiers for v0.1.4.
2. Treat functional strategies with explicit `strategy_params` as the Tier 1
   path.
3. Classify R6 strategies as Tier 2 by default unless they provide explicit
   source/params metadata or a future identity method.
4. Specify how strategy tier is exposed in run metadata.
5. Update `contracts.md` with the strategy identity boundary.
6. Add a note to the v0.1.4 spec packet before implementation tickets rely on
   run identity.

**Acceptance Criteria:**
- [x] Functional and R6 strategies have explicit reproducibility-tier rules.
- [x] R6 objects are not silently treated as fully reproducible.
- [x] Run metadata design includes a strategy reproducibility tier.
- [x] `contracts.md` records the strategy identity boundary.

**Test Requirements:**
- Design review only

**Source Reference:** Pre-Gate: R6 Strategy Identity

---

## LDG-703: Low-Level API Lifecycle Cleanup

**Priority:** P0  
**Effort:** 1 day  
**Dependencies:** LDG-701

**Description:**
Resolve public/internal status for low-level APIs whose docs currently conflict
with their export status: `ledgr_backtest_run()` and `ledgr_backtest_bench()`.

**Tasks:**
1. Decide whether `ledgr_backtest_run()` remains exported in v0.1.4.
2. Prefer soft deprecation or clear low-level lifecycle wording for
   `ledgr_backtest_run()` unless a deliberate breaking removal is accepted.
3. Ensure docs no longer teach calling `ledgr_backtest_run()` after
   `ledgr_backtest()`.
4. If `ledgr_backtest_run()` is removed, update `NAMESPACE`,
   `test-api-exports.R`, old acceptance tests, contracts, and `NEWS.md`.
5. Decide whether `ledgr_backtest_bench()` is public telemetry or internal.
6. If public, remove "(internal)" from its title and document expected use.
7. If internal, route through the compatibility policy before unexporting.

**Acceptance Criteria:**
- [x] `ledgr_backtest_run()` public status is unambiguous.
- [x] `ledgr_backtest_run()` examples do not invert the public call graph.
- [x] Any deprecation or removal is documented in `NEWS.md`.
- [x] `ledgr_backtest_bench()` title and export status agree.
- [x] Export surface test reflects the accepted lifecycle decision.

**Test Requirements:**
- `tests/testthat/test-api-exports.R`
- `devtools::document()` or `roxygen2::roxygenise()`
- `R CMD check --no-manual --no-build-vignettes`

**Source Reference:** A1, A6

---

## LDG-704: Internal `ledgr_config` Class and Validation

**Priority:** P0  
**Effort:** 1 day  
**Dependencies:** LDG-701

**Description:**
Stabilize the internal config object before the experiment-store layer depends
on it. Do not export `ledgr_config()` until the run-store API proves user-facing
construction is needed.

**Tasks:**
1. Add `class = "ledgr_config"` to configs returned by `ledgr_config()`.
2. Add internal `validate_ledgr_config()`.
3. Add `print.ledgr_config()` if config objects remain visible through
   `bt$config`.
4. Share config validation between runner and future run-hydration paths.
5. Record the export decision explicitly in docs or tickets.

**Acceptance Criteria:**
- [x] Config objects have class `ledgr_config`.
- [x] Internal validation exists and is tested.
- [x] Existing `ledgr_backtest()` and runner behavior is unchanged.
- [x] `ledgr_config()` remains internal unless an explicit export decision is
      recorded.
- [x] `contracts.md` records the config lifecycle contract.

**Test Requirements:**
- `tests/testthat/test-backtest-wrapper.R`
- `tests/testthat/test-config*.R` or new targeted config tests
- Acceptance tests for v0.1.0-v0.1.3

**Source Reference:** A2

---

## LDG-705: Public `ledgr_data_hash()` Deprecation and Internal Hash Split

**Priority:** P1  
**Effort:** 1 day  
**Dependencies:** LDG-701

**Description:**
Deprecate or legacy-mark the public v0.1.0 `ledgr_data_hash()` helper without
breaking internal run and snapshot-adapter hash paths.

**Tasks:**
1. Audit all internal call sites of `ledgr_data_hash()`.
2. Separate hash responsibilities:
   - snapshot artifact hash;
   - run data-subset hash, if retained;
   - future feature-cache input identity.
3. Add explicit internal helpers for run and adapter needs.
4. Replace internal uses of the public legacy helper.
5. Update docs so users are not taught direct `bars` table writes as a modern
   workflow.
6. Deprecate or mark public `ledgr_data_hash()` as legacy v0.1.0.
7. Document the transition in `NEWS.md`.

**Acceptance Criteria:**
- [x] Internal run and adapter paths no longer depend on ambiguous public
      legacy semantics.
- [x] Public docs explain that `ledgr_data_hash()` is legacy if it remains
      exported.
- [x] Snapshot-backed workflows use snapshot hashes, not direct `bars` writes.
- [x] Any deprecation is reflected in `NEWS.md`.

**Test Requirements:**
- `tests/testthat/test-data-hash.R`
- Snapshot adapter tests
- Acceptance tests for snapshot-backed runs

**Source Reference:** A3

---

## LDG-706: Reconstruction Documentation Cleanup

**Priority:** P2  
**Effort:** 0.5 days  
**Dependencies:** None

**Description:**
Clarify that `ledgr_state_reconstruct(run_id, con)` is a low-level recovery API
that requires an explicit DBI connection, while normal users should inspect
results through S3/tibble helpers.

**Tasks:**
1. Lead user examples with `tibble::as_tibble(bt, what = "equity")`.
2. Show `ledgr_state_reconstruct()` only as low-level recovery/rebuild.
3. State clearly that callers using `ledgr_state_reconstruct()` own the DBI
   connection lifecycle.
4. Keep `ledgr_extract_fills()` and `ledgr_compute_equity_curve()` positioned
   as read helpers, not alternate reconstruction implementations.

**Acceptance Criteria:**
- [x] Normal result inspection examples do not require DBI.
- [x] Low-level reconstruction docs are accurate about `con`.
- [x] `contracts.md` remains consistent with the reconstruction delegation
      chain.

**Test Requirements:**
- `devtools::document()` or `roxygen2::roxygenise()`
- `R CMD check --no-manual --no-build-vignettes`

**Source Reference:** A4

---

## LDG-707: Optional Indicator Deregistration Helper

**Priority:** P3  
**Effort:** 0.5 days  
**Dependencies:** None

**Description:**
Decide whether to add `ledgr_deregister_indicator()` for interactive sessions
and tests. This is optional because current examples already clean up local
registry state.

**Tasks:**
1. Decide whether public deregistration is worth adding in v0.1.4.
2. If added, implement `ledgr_deregister_indicator(name, missing_ok = TRUE)`.
3. Ensure deregistration affects only the session registry.
4. Document that persisted run artifacts are not changed.
5. Add tests for existing, missing, and invalid names.

**Acceptance Criteria:**
- [ ] Decision is recorded.
- [ ] If implemented, helper is exported, documented, and tested.
- [ ] Helper does not mutate persisted artifacts.
- [ ] If not implemented, ticket is closed as intentionally unnecessary.

**Test Requirements:**
- `tests/testthat/test-indicators.R`
- `tests/testthat/test-api-exports.R` if exported

**Source Reference:** A5

---

## LDG-708: Load Existing Sealed Snapshots

**Priority:** P0  
**Effort:** 1 day  
**Dependencies:** None

**Description:**
Add `ledgr_snapshot_load()` so durable research scripts can reopen an existing
sealed snapshot without re-importing data or failing on duplicate
`snapshot_id`.

**Tasks:**
1. Implement `ledgr_snapshot_load(db_path, snapshot_id, verify = FALSE)`.
2. Validate that `snapshot_id` exists.
3. Validate that status is `SEALED`.
4. Return a `ledgr_snapshot` handle without importing or mutating bars.
5. Do not silently create or overwrite snapshots.
6. Document when full artifact-hash verification occurs.
7. Update the getting-started vignette to show the load path for reruns.

**Acceptance Criteria:**
- [x] Re-running a script can load an existing snapshot instead of failing.
- [x] Missing snapshots error clearly.
- [x] Unsealed snapshots error clearly.
- [x] Loading a snapshot does not mutate persistent tables.
- [x] Vignette shows the durable rerun workflow.

**Test Requirements:**
- New `tests/testthat/test-snapshots-load.R`
- Snapshot creation/list/info tests
- Getting-started vignette render

**Source Reference:** B1

---

## LDG-709: Path-First Snapshot Listing

**Priority:** P1  
**Effort:** 0.5 days  
**Dependencies:** None

**Description:**
Make `ledgr_snapshot_list()` support both DBI connections and DuckDB file paths,
matching the v0.1.2+ user mental model.

**Tasks:**
1. Support `ledgr_snapshot_list(con)`.
2. Support `ledgr_snapshot_list("artifact.duckdb")`.
3. Open and close connections internally for path input.
4. Preserve the existing `status` filter.
5. Update examples to show path-first use.

**Acceptance Criteria:**
- [x] Path input works without manual DBI setup.
- [x] Connection input remains backward compatible.
- [x] Path-based calls close their internal connection.
- [x] Existing `status` behavior is unchanged.

**Test Requirements:**
- `tests/testthat/test-snapshots-create-list.R`
- New path-first tests
- `R CMD check --no-manual --no-build-vignettes`

**Source Reference:** B2

---

## LDG-710: Current Target Helper

**Priority:** P0  
**Effort:** 0.5-1 day  
**Dependencies:** None

**Description:**
Add `ctx$current_targets()` to prevent accidental flattening in strategies that
intend to hold current positions when no signal fires.

**Tasks:**
1. Add `ctx$current_targets()` to runtime pulse contexts.
2. Add the same helper to `ledgr_pulse_snapshot()` contexts.
3. Return a full named numeric vector over `ctx$universe`.
4. Initialize values from current positions.
5. Use zero for known instruments with no current position.
6. Preserve existing `ctx$targets(default = 0)` behavior.
7. Document that `ctx$targets()` starts from flat and
   `ctx$current_targets()` starts from current holdings.
8. Add tests for flat, held, multi-instrument, and invalid-universe contexts.

**Acceptance Criteria:**
- [x] Runtime contexts expose `ctx$current_targets()`.
- [x] Interactive pulse contexts expose `ctx$current_targets()`.
- [x] Existing `ctx$targets()` behavior remains backward compatible.
- [x] Docs warn that returning zero targets means go flat.
- [x] Hold-state strategy examples use `ctx$current_targets()`.

**Test Requirements:**
- `tests/testthat/test-pulse-context-accessors.R`
- `tests/testthat/test-indicator-tools.R`
- Strategy contract tests

**Source Reference:** B3

---

## LDG-711: Research Workflow Documentation Updates

**Priority:** P1  
**Effort:** 1 day  
**Dependencies:** LDG-708, LDG-710

**Description:**
Update docs and tutorials for realistic research workflows: position sizing,
connection cleanup, fill model behavior, and rebalance throttling.

**Tasks:**
1. Show position sizing from scalar fields:
   `ctx$cash`, `ctx$equity`, and `ctx$close(id)`.
2. Do not add `ctx$cash()` or `ctx$equity()` methods.
3. Add `on.exit(close(bt), add = TRUE)` to longer-running examples.
4. Explain that closing releases DuckDB connections and does not delete stable
   files.
5. Correct fill model wording: default is next available open price, zero
   spread, zero fixed commission.
6. Add one non-default fill model example if the API supports it cleanly.
7. Document self-throttling with `ctx$ts_utc`.
8. Show a monthly rebalance pattern using `ctx$current_targets()`.
9. Update README/vignettes only where this improves clarity; keep README short.

**Acceptance Criteria:**
- [x] Vignette examples deploy a meaningful fraction of capital.
- [x] `ctx$cash` and `ctx$equity` are documented as scalar fields.
- [x] Connection lifecycle docs include `on.exit(close(...), add = TRUE)`.
- [x] Fill model docs say next-open, not instant.
- [x] Rebalance throttling example uses `ctx$ts_utc`.
- [x] No engine-level `rebalance_frequency` is added in this ticket.

**Test Requirements:**
- README render smoke test if README changes
- Getting-started vignette render
- `R CMD check --no-manual --no-build-vignettes`

**Source Reference:** B4, B5, B6, B7

---

## LDG-712: Vectorized Indicator `series_fn`

**Priority:** P0  
**Effort:** 2-3 days  
**Dependencies:** None

**Description:**
Add an optional vectorized full-series indicator path to avoid the current
expanding-window fallback cost for custom indicators.

**Tasks:**
1. Add `series_fn` parameter to `ledgr_indicator()`.
2. Validate `series_fn` purity and deterministic behavior.
3. Include `series_fn` in indicator fingerprinting.
4. Define the contract:
   - input is one instrument's full bar series in ascending time order;
   - output is numeric length `nrow(bars)`;
   - output aligns to bar row order;
   - warmup `NA_real_` and `NaN` are normalized to `NA_real_`;
   - non-finite values outside warmup are invalid.
5. Update feature precomputation to use `series_fn` when present.
6. Add `series_fn` implementations for built-in indicators.
7. Decide and implement fallback `fn` window semantics.
8. If fallback `fn` moves from expanding to bounded windows, document this
   behavior change in `NEWS.md`.
9. Update indicator docs.
10. Update the existing custom-indicators vignette if it remains current, or
    create a focused custom-indicators vignette section if the existing article
    is not adequate for `series_fn`.

**Acceptance Criteria:**
- [x] Custom indicators with `series_fn` avoid the expanding-window loop.
- [x] Built-in indicators use the vectorized path.
- [x] `fn`-only indicators continue to work.
- [x] `series_fn` output length and alignment are validated.
- [x] Warmup `NaN` is normalized to `NA_real_`.
- [x] Indicator fingerprint changes when `series_fn` changes.
- [x] Any fallback behavior change is documented in `NEWS.md`.

**Test Requirements:**
- `tests/testthat/test-indicators.R`
- `tests/testthat/test-features.R`
- No-lookahead tests
- Custom-indicators vignette/render check if the vignette is changed or created

**Source Reference:** C1

---

## LDG-713: Feature Cache Across Parameter Sweeps

**Priority:** P1  
**Effort:** 2-3 days  
**Dependencies:** LDG-712

**Description:**
Add a session-scoped feature cache so repeated runs over the same snapshot and
indicator fingerprint do not recompute the same feature series.

**Tasks:**
1. Define feature cache key:
   `snapshot_hash + instrument_id + indicator_fingerprint + feature_engine_version`.
2. Use `snapshot_hash`, not `snapshot_id`, as data identity.
3. Include date range in the key only if the cache stores range-limited series.
4. Implement a session-scoped cache.
5. Add public `ledgr_clear_feature_cache()`.
6. Add telemetry for feature cache hits and misses.
7. Make precomputation check the cache before calling `series_fn`.
8. Add tests proving `series_fn` is not called again on cache hit.
9. Document that the cache is not persisted across R sessions.

**Acceptance Criteria:**
- [ ] First run computes and caches feature series.
- [ ] Subsequent same-snapshot/same-indicator runs do not call `series_fn`.
- [ ] Cache key uses `snapshot_hash`.
- [ ] Cache key includes indicator fingerprint and feature-engine version.
- [ ] Telemetry shows cache hits/misses.
- [ ] Tests avoid brittle wall-clock thresholds.
- [ ] `ledgr_clear_feature_cache()` is exported and tested.

**Test Requirements:**
- New feature cache tests
- `tests/testthat/test-features.R`
- `tests/testthat/test-backtest-wrapper.R`
- Coverage gate

**Source Reference:** C2

---

## LDG-714: v0.1.4 Stabilisation Gate

**Priority:** P0  
**Effort:** 1 day  
**Dependencies:** LDG-701, LDG-702, LDG-703, LDG-704, LDG-705, LDG-706, LDG-708, LDG-709, LDG-710, LDG-711, LDG-712, LDG-713

**Description:**
Final validation gate for the v0.1.4 stabilisation cycle.

**Tasks:**
1. Ensure `contracts.md` is updated for compatibility policy, strategy tiers,
   config lifecycle, snapshot load semantics, target helper semantics, and
   feature series/cache identity.
2. Ensure `NEWS.md` documents all deprecations, breaking changes, and behavior
   changes.
3. Regenerate documentation.
4. Run v0.1.2 and v0.1.3 acceptance tests.
5. Run the full package check.
6. Run coverage gate.
7. Run README and vignette render checks if docs changed.
8. Confirm CI is green on Ubuntu and Windows.

**Acceptance Criteria:**
- [ ] `R CMD check --no-manual --no-build-vignettes` passes with 0 errors and
      0 warnings.
- [ ] v0.1.2 and v0.1.3 acceptance tests pass.
- [ ] Coverage remains at or above 80%.
- [ ] README cold-start check passes if README changed.
- [ ] pkgdown site builds if reference/vignette docs changed.
- [ ] Ubuntu and Windows CI are green.
- [ ] `contracts.md` and `NEWS.md` match the implemented scope.

**Test Requirements:**
- `tools/check-readme-example.R`
- `tools/check-coverage.R`
- `R CMD check --no-manual --no-build-vignettes`
- `.github/workflows/R-CMD-check.yaml`
- `pkgdown::build_site()`

**Source Reference:** Global Definition Of Done

---

## Out of Scope

Do not implement these in the stabilisation cycle:

- live trading;
- paper trading;
- broker adapters;
- streaming data;
- engine-level rebalance scheduler;
- parameter optimization UI;
- persistent feature cache;
- full experiment-store comparison API;
- strategy extraction/revival API.
