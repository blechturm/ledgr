# ledgr v0.1.6 Strategy Comparison And Recovery Tickets

**Version:** 0.1.0  
**Date:** April 28, 2026  
**Total Tickets:** 9  
**Estimated Duration:** 3-5 weeks

---

## Ticket Organization

v0.1.6 turns the v0.1.5 experiment store into a strategy-development and
comparison workflow. The ticket range starts at `LDG-901` to avoid collisions
with earlier cycles.

Under `inst/design/model_routing.md`, tickets touching execution validation,
DuckDB persistence, run identity, strategy source, or public API contracts are
Tier H. Documentation-only tickets are lower tier unless they encode new public
workflow contracts.

### Dependency DAG

```text
LDG-901 -> LDG-902 -> LDG-905 -> LDG-907 -> LDG-908 -> LDG-909
LDG-901 -> LDG-903 -> LDG-905 -> LDG-907 -> LDG-908 -> LDG-909
LDG-901 -> LDG-904 -> LDG-905 -> LDG-907 -> LDG-908 -> LDG-909
LDG-901 ----------------------------> LDG-907 -> LDG-908 -> LDG-909
LDG-906 (optional, not release-gate dependency)
```

`LDG-909` is the v0.1.6 release gate. `LDG-906` is optional and must not block
the gate unless it is explicitly promoted after review.

### Priority Levels

- **P0 (Blocker):** Required for correctness or release coherence.
- **P1 (Critical):** Required for the user story to work.
- **P2 (Important):** Required for discoverability or documentation quality.
- **P3 (Optional):** Useful, but not a release blocker.

---

## LDG-901: v0.1.5 Audit Stabilisation

**Priority:** P0  
**Effort:** 2-3 days  
**Dependencies:** None  
**Status:** Done

**Description:**
Address the concrete v0.1.5 audit findings that would otherwise undermine
strategy comparison and recovery. This ticket fixes the suspected crash-level
issue, replaces raw storage-layer errors with user-facing diagnostics, tightens
cash validation, and verifies final-bar no-fill behavior.

This ticket must not add `ctx$params`. The correct parameter contract remains
`function(ctx, params)`.

**Tasks:**
1. Reproduce the reported `ledgr_state_reconstruct()` failure.
2. Fix `ledgr_state_reconstruct(run_id, con)` if it fails according to the
   documented low-level signature.
3. If unsupported inputs such as a `ledgr_backtest` object are passed, fail
   with a clear classed error pointing to the documented signature.
4. Add preflight validation for duplicate feature IDs before DuckDB feature
   writes.
5. Replace duplicate-feature raw DuckDB errors with a classed user-facing
   condition naming the duplicate IDs.
6. Reject `initial_cash <= 0` in backtest/config validation.
7. Add a focused regression test for a true final-bar target change that should
   emit `LEDGR_LAST_BAR_NO_FILL`.
8. If the final-bar behavior and docs diverge, fix either implementation or docs
   so they match.
9. Clarify docs for:
   - `ledgr_snapshot_list()` accepted inputs;
   - `ledgr_data_hash()` as a legacy DBI helper;
   - `ledgr_backtest_bench()` as session-scoped and object-based;
   - `ledgr_compute_metrics()` accepted inputs.
10. Document long-only/negative target behavior in contracts or reference docs.

**Acceptance Criteria:**
- [x] `ledgr_state_reconstruct(run_id, con)` works as documented or fails
      clearly for invalid inputs.
- [x] Duplicate feature IDs fail before DuckDB writes with a classed ledgr
      error.
- [x] `initial_cash = 0` and negative initial cash fail with a classed ledgr
      error.
- [x] Final-bar target-change warning behavior is covered by a regression test.
- [x] Docs no longer imply unsupported object signatures for low-level helpers.
- [x] No `ctx$params` API is introduced.
- [x] Existing v0.1.5 run storage and replay behavior is unchanged for valid
      inputs.

**Test Requirements:**
- Unit test for `ledgr_state_reconstruct()` documented signature.
- Invalid-input tests for low-level helper misuse.
- Duplicate feature ID test.
- `initial_cash <= 0` validation test.
- Final-bar no-fill warning test.
- Existing v0.1.x acceptance tests.

**Source Reference:** v0.1.6 spec sections 2, 3.4, 6.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  Touches execution-adjacent validation, final-bar fill diagnostics, low-level
  reconstruction, public API error behavior, and feature write preflight.
  These areas include execution, persistence, and public API hard-escalation
  concerns under the model routing rulebook.
invariants_at_risk:
  - deterministic replay
  - final-bar no-fill semantics
  - feature identity uniqueness
  - backtest input validation
  - low-level recovery API behavior
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_6_spec_packet/v0_1_6_spec.md
  - inst/design/ledgr_v0_1_6_spec_packet/ledgr_v0_1_5_audit_report.md
  - inst/design/contracts.md (Execution Contract, Strategy Contract, Persistence Contract)
  - R/public-api.R
  - R/backtest.R
  - R/backtest-runner.R
  - R/features-engine.R
  - R/pulse-context.R
tests_required:
  - state reconstruction tests
  - duplicate feature ID tests
  - initial_cash validation tests
  - final-bar no-fill warning tests
  - regression acceptance tests
escalation_triggers:
  - fix requires changing ledger or fill semantics
  - duplicate feature handling requires schema changes
  - state reconstruction cannot be fixed without changing run storage
  - docs and implementation contracts conflict
forbidden_actions:
  - adding ctx$params as an implicit parameter path
  - changing valid target vector semantics
  - changing snapshot hash or ledger event semantics
  - silently allowing duplicate feature IDs
```

---

## LDG-902: Feature ID Discovery UX

**Priority:** P1  
**Effort:** 1-2 days  
**Dependencies:** LDG-901  
**Status:** Done

**Description:**
Make indicator feature IDs discoverable before runtime. The v0.1.5 audit showed
that TTR IDs such as `ttr_macd_12_26_9_signal` are deterministic but not
guessable. Runtime unknown-feature errors are necessary but not sufficient.

**Tasks:**
1. Document the TTR feature ID convention in the TTR indicator article.
2. Add examples that show assigning indicators to objects and reading `ind$id`.
3. Consider adding `ledgr_feature_id(x)` for a `ledgr_indicator` or list of
   indicators.
4. If added, export and document `ledgr_feature_id()`.
5. Improve `print.ledgr_indicator` if it exists, or add a concise print method
   if the current indicator print output hides the ID.
6. Add examples for built-in and TTR indicators showing the ID used in
   `ctx$feature()`.
7. Ensure unknown-feature runtime errors still list available IDs.

**Acceptance Criteria:**
- [x] Users can discover the exact feature ID before running a strategy.
- [x] TTR ID examples include at least BBands, MACD, ATR, and RSI.
- [x] Built-in indicator ID examples are documented.
- [x] Any new helper is exported, documented, tested, and does not create a
      second ID-generation scheme.
- [x] List input returns a plain character vector of IDs in list order.
- [x] Existing indicator fingerprints and IDs remain unchanged.

**Test Requirements:**
- Unit tests for any new helper or print method.
- Existing TTR indicator tests.
- Reference example checks.

**Source Reference:** v0.1.6 spec sections 2.6, 3.3, 6.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: H
classification_reason: >
  Bounded user-facing API/documentation improvement around existing indicator
  IDs. It should not alter feature computation or fingerprint semantics, but
  any exported helper requires Tier H review for public API surface.
invariants_at_risk:
  - feature ID stability
  - indicator fingerprint stability
  - public API discoverability
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_6_spec_packet/v0_1_6_spec.md
  - inst/design/contracts.md (Indicator Contract, Strategy Contract)
  - R/indicators_builtin.R
  - R/indicator-ttr.R
  - vignettes/ttr-indicators.Rmd
tests_required:
  - feature ID helper tests if helper is added
  - TTR ID examples render
  - existing indicator tests remain green
escalation_triggers:
  - implementation would change existing IDs
  - implementation would change fingerprints
  - helper scope expands beyond ID discovery
forbidden_actions:
  - renaming existing feature IDs
  - adding aliases that mask duplicate feature IDs
  - changing TTR warmup or series_fn behavior
```

---

## LDG-903: Compare Stored Runs

**Priority:** P0  
**Effort:** 2-3 days  
**Dependencies:** LDG-901  
**Status:** Done

**Description:**
Add `ledgr_compare_runs()` for comparing completed stored runs without
recomputing strategies. This is the central v0.1.6 experiment-comparison API.

**Tasks:**
1. Implement `ledgr_compare_runs(db_path, run_ids = NULL,
   include_archived = FALSE, metrics = c("standard"))`.
2. Read run metadata, strategy provenance, telemetry, and result-derived
   metrics from the experiment store.
3. Preserve requested `run_ids` order when supplied.
4. Hide archived runs by default when `run_ids = NULL`.
5. Allow explicitly requested archived completed runs.
6. Fail clearly for explicitly requested failed, running, or incomplete runs.
7. Fail clearly for missing run IDs.
8. Return a tibble-like data frame with the required columns from the spec.
9. Ensure the function does not mutate the database.
10. Ensure the function does not rerun strategies or execute recovered source.
11. Document examples comparing same-strategy/different-params and
    different-strategy runs.

**Acceptance Criteria:**
- [x] Completed stored runs can be compared in one table.
- [x] No strategy is rerun.
- [x] No database mutation occurs.
- [x] Archived run behavior matches the spec.
- [x] Failed/incomplete run behavior is classed and points to
      `ledgr_run_info()`.
- [x] Result columns include final equity, total return, max drawdown,
      trade count, win rate, execution mode, elapsed seconds, and identity
      hashes.
- [x] Legacy/pre-provenance runs remain inspectable but comparison output marks
      missing identity fields clearly.

**Test Requirements:**
- Multi-run durable store fixture.
- Same-strategy/different-params comparison.
- Different-strategy comparison.
- Archived run behavior.
- Failed/incomplete run error behavior.
- No-recompute test using a side-effect strategy counter.
- No-mutation test for read-only comparison.

**Source Reference:** v0.1.6 spec sections 2.2, 2.3, 3.1.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  Reads DuckDB experiment-store artifacts, exposes a new public comparison API,
  combines run identity, provenance, telemetry, and result metrics, and must
  preserve no-recompute/no-mutation guarantees. This touches persistence,
  identity, and public API contracts.
invariants_at_risk:
  - experiment-store read-only behavior
  - run identity interpretation
  - archived and incomplete run semantics
  - result metric consistency
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_6_spec_packet/v0_1_6_spec.md
  - inst/design/ledgr_v0_1_5_spec_packet/v0_1_5_spec.md
  - inst/design/contracts.md (Persistence Contract, Run Identity Contract, Result Contract)
  - R/run-store.R
  - R/backtest.R
  - R/public-api.R
tests_required:
  - comparison API tests
  - no recompute tests
  - no mutation tests
  - archived and failed run tests
escalation_triggers:
  - comparison requires recomputing result views
  - comparison needs schema changes
  - metric definitions conflict with summary/metrics output
  - legacy run behavior is ambiguous
forbidden_actions:
  - executing strategy source
  - mutating stores from comparison
  - adding sweep APIs
  - silently including failed or running runs in comparisons
```

---

## LDG-904: Extract Stored Strategy Source

**Priority:** P0  
**Effort:** 2-3 days  
**Dependencies:** LDG-901  
**Status:** Done

**Description:**
Add `ledgr_extract_strategy()` for inspecting and optionally recovering stored
strategy source from the experiment store. The default path must be safe: source
text and metadata only, with no evaluation.

**Tasks:**
1. Implement `ledgr_extract_strategy(db_path, run_id, trust = FALSE)`.
2. Return a classed `ledgr_extracted_strategy` object with source text, hashes,
   params, reproducibility metadata, versions, and warnings.
3. Add a concise print method.
4. With `trust = FALSE`, never parse or evaluate source.
5. With `trust = TRUE`, verify source hash before parsing/evaluating.
6. Make clear that hash verification proves stored-text identity, not safety.
7. Fail clearly on source hash mismatch.
8. Handle legacy/pre-provenance runs clearly.
9. Warn for Tier 2 and Tier 3 strategies whose source may not be executable.
10. Do not execute the recovered strategy against data.

**Acceptance Criteria:**
- [x] `trust = FALSE` returns source metadata without evaluation.
- [x] `trust = TRUE` verifies the hash before any evaluation.
- [x] Hash mismatch fails with a classed error.
- [x] Legacy/pre-provenance runs fail or return structured missing-source
      diagnostics.
- [x] Tier 2/Tier 3 warnings are visible.
- [x] Print output is concise and does not dump long source by default.
- [x] No strategy execution occurs during extraction.

**Test Requirements:**
- Tier 1 `function(ctx, params)` extraction.
- Tier 2/R6 or external-symbol extraction.
- Legacy/pre-provenance run behavior.
- Hash mismatch failure.
- `trust = FALSE` no-eval test.
- `trust = TRUE` hash-verified recovery test.

**Source Reference:** v0.1.6 spec sections 2.4, 3.2, 5.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  Touches strategy source provenance, strategy hashes, trust-boundary semantics,
  public API behavior, and experiment-store identity. These are identity and
  public API hard-escalation areas.
invariants_at_risk:
  - strategy source hash meaning
  - trust boundary correctness
  - reproducibility tier interpretation
  - legacy run handling
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_6_spec_packet/v0_1_6_spec.md
  - inst/design/ledgr_v0_1_5_spec_packet/v0_1_5_spec.md
  - inst/design/contracts.md (Run Identity Contract, Strategy Contract, Compatibility Policy)
  - R/strategy-provenance.R
  - R/run-store.R
tests_required:
  - extraction tests
  - hash mismatch tests
  - no-eval tests
  - trust=TRUE tests
  - legacy run tests
escalation_triggers:
  - trust=TRUE requires changing source capture semantics
  - source hashes are not reproducible enough for verification
  - evaluation environment cannot be made explicit
forbidden_actions:
  - evaluating source when trust=FALSE
  - executing recovered strategies against data
  - treating hash verification as a safety guarantee
  - silently recovering missing or mismatched source
```

---

## LDG-905: Strategy Development And Comparison Vignette

**Priority:** P1  
**Effort:** 2 days  
**Dependencies:** LDG-902, LDG-903, LDG-904  
**Status:** Pending

**Description:**
Add a dedicated strategy-development article that teaches the ledgr strategy
contract, `ctx`, targets, indicators, strategy params, debugging, and comparison.
This article is the user-facing story for v0.1.6.

**Tasks:**
1. Create `vignettes/strategy-development.Rmd`.
2. Explain `function(ctx)` and `function(ctx, params)`.
3. Show parameter access through the second argument, not `ctx$params`.
4. Explain every major `ctx` field/helper listed in the spec.
5. Explain target-vector requirements.
6. Explain `ctx$targets()` versus `ctx$current_targets()`.
7. Cover built-in indicators.
8. Cover TTR indicators and feature ID discovery.
9. Explain warmup `NA` behavior.
10. Show `ledgr_pulse_snapshot()` debugging.
11. Show comparing same-strategy/different-params runs.
12. Show comparing different strategies.
13. Show source inspection with `ledgr_extract_strategy(..., trust = FALSE)`.
14. Add the article to `_pkgdown.yml`.
15. Ensure all examples are offline-safe.

**Acceptance Criteria:**
- [ ] Article renders offline.
- [ ] Article includes `function(ctx)` and `function(ctx, params)` examples.
- [ ] Article explains `ctx` comprehensively enough that a new strategy author
      does not need to infer fields from source code.
- [ ] Article shows built-in and TTR indicators.
- [ ] Article shows feature ID discovery before runtime.
- [ ] Article culminates in `ledgr_compare_runs()`.
- [ ] Article uses `ledgr_extract_strategy(..., trust = FALSE)` safely.
- [ ] No example uses network access.

**Test Requirements:**
- Render `vignettes/strategy-development.Rmd`.
- Build pkgdown.
- Run README/vignette offline checks where applicable.

**Source Reference:** v0.1.6 spec section 3.5.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: H
classification_reason: >
  Documentation-heavy but central to the v0.1.6 user contract. It teaches
  strategy semantics, feature IDs, and new comparison/recovery APIs, so Tier H
  review is required even though implementation is mostly vignette work.
invariants_at_risk:
  - strategy authoring mental model
  - target-vector semantics
  - feature ID usage
  - trust-boundary explanation
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_6_spec_packet/v0_1_6_spec.md
  - inst/design/contracts.md (Strategy Contract, Context Contract, Indicator Contract)
  - vignettes/getting-started.Rmd
  - vignettes/ttr-indicators.Rmd
  - vignettes/research-to-production.Rmd
tests_required:
  - vignette render
  - pkgdown build
  - offline example checks
escalation_triggers:
  - article requires undocumented API behavior
  - examples reveal contract ambiguity
  - comparison or extraction APIs change after article is written
forbidden_actions:
  - documenting ctx$params as supported
  - using network data in examples
  - implying sweep, live, or paper trading support
```

---

## LDG-906: Optional Run Tags

**Priority:** P3  
**Effort:** 1-2 days  
**Dependencies:** LDG-903  
**Status:** Pending

**Description:**
Optional additive tagging API for grouping runs. This ticket is not part of the
release gate unless explicitly promoted after review.

**Tasks:**
1. Decide whether tags remain in v0.1.6 scope.
2. If retained, design a small additive schema for run tags.
3. Add APIs only if the schema and UX are trivial and do not disturb comparison
   or extraction work.
4. Keep hard delete out of scope.
5. Document tags as mutable metadata, not identity.

**Acceptance Criteria:**
- [ ] If implemented, tags do not alter run identity hashes.
- [ ] If implemented, tags are additive and non-destructive.
- [ ] If deferred, roadmap/spec notes remain accurate.
- [ ] LDG-909 does not depend on this ticket unless explicitly promoted.

**Test Requirements:**
- Only required if implemented: tag schema/API tests and migration tests.

**Source Reference:** v0.1.6 spec section 7 and roadmap v0.1.6 optional tagging.

**Classification:**
```yaml
risk_level: medium
implementation_tier: H
review_tier: H
classification_reason: >
  Optional, but if implemented it touches DuckDB schema, mutable run metadata,
  and public API surface. Those are persistence and public API hard-escalation
  areas.
invariants_at_risk:
  - run identity immutability
  - schema migration safety
  - archive/label/tag metadata boundaries
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_6_spec_packet/v0_1_6_spec.md
  - inst/design/ledgr_v0_1_5_spec_packet/v0_1_5_spec.md
  - inst/design/contracts.md (Persistence Contract, Run Identity Contract)
  - R/run-store.R
tests_required:
  - tag schema tests if implemented
  - tag API tests if implemented
  - no identity hash mutation tests if implemented
escalation_triggers:
  - tags require destructive migration
  - tags start affecting comparison semantics
  - tags become required for the v0.1.6 user story
forbidden_actions:
  - making tags part of experiment identity
  - adding hard delete
  - blocking the release gate on optional tag work without explicit rescope
```

---

## LDG-907: Experiment Store Vignette

**Priority:** P1  
**Effort:** 1-2 days  
**Dependencies:** LDG-901, LDG-903  
**Status:** Pending

**Description:**
Add a dedicated experiment-store how-to article. This fills the audit gap that
run management is currently taught only indirectly through getting-started and
the research-to-production philosophy article.

**Tasks:**
1. Create `vignettes/experiment-store.Rmd`.
2. Explain durable DuckDB files as experiment stores.
3. Show creating multiple runs against one sealed snapshot.
4. Explain immutable `run_id` and mutable `label`.
5. Demonstrate `ledgr_run_list()`.
6. Demonstrate `ledgr_run_info()`.
7. Demonstrate `ledgr_run_open()`.
8. Demonstrate `ledgr_run_label()`.
9. Demonstrate `ledgr_run_archive()`.
10. Explain archived versus deleted runs.
11. Explain compact telemetry fields.
12. Explain reproducibility tiers and legacy/pre-provenance runs.
13. Show how `ledgr_compare_runs()` builds on stored run metadata.
14. Add the article to `_pkgdown.yml`.
15. Keep all examples offline-safe and use `tempfile()`.

**Acceptance Criteria:**
- [ ] Article renders offline.
- [ ] Article teaches concrete run-management APIs, not only philosophy.
- [ ] Article distinguishes `run_id` from `label`.
- [ ] Article explains archive as non-destructive cleanup.
- [ ] Article explains telemetry and reproducibility tiers.
- [ ] Article links comparison to stored run metadata.
- [ ] Article does not imply hard delete or tags are available unless LDG-906
      is accepted.

**Test Requirements:**
- Render `vignettes/experiment-store.Rmd`.
- Build pkgdown.
- Offline example checks where applicable.

**Source Reference:** v0.1.6 spec section 3.6.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: H
classification_reason: >
  Documentation-heavy but central to the experiment-store workflow. It explains
  run identity, labels, archive, telemetry, reproducibility tiers, and
  comparison, so Tier H review is required for contract accuracy.
invariants_at_risk:
  - experiment-store mental model
  - run identity versus metadata distinction
  - archive semantics
  - reproducibility-tier interpretation
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_6_spec_packet/v0_1_6_spec.md
  - inst/design/ledgr_v0_1_5_spec_packet/v0_1_5_spec.md
  - inst/design/contracts.md (Persistence Contract, Run Identity Contract)
  - vignettes/research-to-production.Rmd
  - vignettes/getting-started.Rmd
tests_required:
  - vignette render
  - pkgdown build
  - offline example checks
escalation_triggers:
  - article requires undocumented API behavior
  - examples need comparison behavior not implemented in LDG-903
  - run tags become necessary to explain the workflow
forbidden_actions:
  - documenting hard delete
  - documenting tags as available unless LDG-906 is accepted
  - using network data in examples
  - implying strategy recovery executes source by default
```

---

## LDG-908: v0.1.6 Documentation, Contracts, And NEWS

**Priority:** P1  
**Effort:** 1-2 days  
**Dependencies:** LDG-901, LDG-903, LDG-904, LDG-905, LDG-907  
**Status:** Pending

**Description:**
Bring contracts, NEWS, reference docs, and pkgdown navigation into alignment with
the accepted v0.1.6 scope.

**Tasks:**
1. Update `inst/design/contracts.md` for comparison and strategy extraction.
2. Update contracts for feature ID discovery if a helper is added.
3. Update contracts for long-only/negative target behavior.
4. Update contracts/reference docs for low-level versus high-level API
   boundaries.
5. Update `NEWS.md`.
6. Ensure every new exported function has an offline-safe example.
7. Ensure pkgdown navigation includes new APIs and articles.
8. Ensure docs do not imply v0.1.7 sweep mode is available.

**Acceptance Criteria:**
- [ ] Contracts match v0.1.6 behavior.
- [ ] NEWS lists all public API additions and behavior changes.
- [ ] New exported functions have examples.
- [ ] Pkgdown navigation is complete.
- [ ] Low-level, legacy, and recommended APIs are clearly distinguished.
- [ ] No v0.1.7 APIs are documented as available.

**Test Requirements:**
- `devtools::document()`.
- Example checks.
- pkgdown build.
- Export scan for accidental v0.1.7 APIs.

**Source Reference:** v0.1.6 spec sections 3.6, 6, 8.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: H
classification_reason: >
  Cross-cutting docs and contracts update. Mostly documentation and package
  plumbing, but it updates contracts and public API documentation, requiring
  Tier H review under the model routing workflow.
invariants_at_risk:
  - public API documentation accuracy
  - strategy and result contracts
  - trust-boundary documentation
  - roadmap scope clarity
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_6_spec_packet/v0_1_6_spec.md
  - inst/design/contracts.md
  - NEWS.md
  - _pkgdown.yml
  - man/
tests_required:
  - documentation generation
  - pkgdown build
  - examples remain offline-safe
escalation_triggers:
  - documentation requires changing public API semantics
  - contracts conflict with implementation
  - examples need network access
forbidden_actions:
  - documenting sweep, live, or paper APIs as available
  - hiding trust-boundary warnings
  - adding undocumented exports
```

---

## LDG-909: v0.1.6 Release Gate

**Priority:** P0  
**Effort:** 1 day  
**Dependencies:** LDG-901, LDG-902, LDG-903, LDG-904, LDG-905, LDG-907, LDG-908  
**Status:** Pending

**Description:**
Final validation gate for v0.1.6. This ticket verifies that audit
stabilisation, strategy-development documentation, comparison, recovery,
contracts, tests, package checks, and CI all match the accepted scope.

**Tasks:**
1. Verify v0.1.6 spec, tickets, contracts, roadmap, and NEWS agree.
2. Run all v0.1.6 targeted tests.
3. Run v0.1.x acceptance/regression tests where applicable.
4. Run coverage gate.
5. Run README/vignette offline checks.
6. Run package check.
7. Build pkgdown.
8. Confirm Ubuntu and Windows CI are green.
9. Confirm no v0.1.7 APIs were accidentally exposed.
10. Confirm no open P0/P1 review findings remain.

**Acceptance Criteria:**
- [ ] `R CMD check --no-manual --no-build-vignettes` passes with 0 errors and
      0 warnings.
- [ ] Coverage remains at or above the project gate.
- [ ] pkgdown site builds.
- [ ] README and vignettes remain offline-safe.
- [ ] Ubuntu and Windows CI are green.
- [ ] Contracts and NEWS match the implemented scope.
- [ ] All v0.1.6 acceptance criteria are satisfied.
- [ ] No open P0/P1 review findings remain.
- [ ] No accidental v0.1.7 API exposure exists.

**Test Requirements:**
- `tools/check-coverage.R`.
- `tools/check-readme-example.R` if README changes.
- Strategy-development vignette render.
- `R CMD check --no-manual --no-build-vignettes`.
- `pkgdown::build_site()`.
- `.github/workflows/R-CMD-check.yaml`.

**Source Reference:** v0.1.6 spec section 8.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: H
review_tier: H
classification_reason: >
  Release gate and final Tier H review for the v0.1.6 strategy comparison and
  recovery cycle. Validates all contracts, public APIs, tests, docs, CI, and
  acceptance criteria.
invariants_at_risk:
  - all v0.1.6 contracts
  - comparison and recovery API correctness
  - trust boundary
  - public API surface
  - release quality gates
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_6_spec_packet/v0_1_6_spec.md
  - inst/design/ledgr_v0_1_6_spec_packet/v0_1_6_tickets.md
  - inst/design/contracts.md
  - NEWS.md
  - tools/check-coverage.R
  - tools/check-readme-example.R
  - .github/workflows/R-CMD-check.yaml
  - all v0.1.6 review findings
tests_required:
  - all targeted v0.1.6 tests pass
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
  - accepting accidental v0.1.7 API scope
```

---

## Out Of Scope

Do not implement these in v0.1.6:

- parameter sweep mode;
- persistent feature-cache storage;
- walk-forward validation;
- short selling;
- portfolio sizing helpers;
- live trading;
- paper trading;
- broker adapters;
- hard delete;
- full source-environment serialization.
