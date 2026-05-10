# ledgr v0.1.7.8 Tickets

**Version:** 0.1.7.8
**Date:** May 10, 2026
**Total Tickets:** 8

---

## Ticket Organization

v0.1.7.8 locks the strategy reproducibility boundary before v0.1.8 sweep mode.
It adds a preflight contract and implementation, publishes narrative
reproducibility and leakage design articles, promotes the custom-indicator
boundary into current public docs, signs off the fold-core/output-handler
boundary, and routes the v0.1.7.7 auditr feedback without turning the release
into broad strategy-author ergonomics work.

Tracks:

1. **Scope and routing:** preserve v0.1.7.8 focus and route auditr evidence.
2. **Preflight contract:** define Tier 1, Tier 2, Tier 3 and the result object.
3. **Preflight implementation:** classify strategies and wire into `ledgr_run()`.
4. **Reproducibility article:** teach experiments, provenance, extraction, and
   tiers.
5. **Leakage article:** teach strategy and feature leakage boundaries.
6. **Custom-indicator docs:** promote stale placeholder docs into current
   feature-boundary teaching material.
7. **Fold-core sign-off:** record the v0.1.8 fold/output-handler contract.
8. **Release gate:** update NEWS, docs contracts, tickets, and CI.

### Dependency DAG

```text
LDG-1801 -> LDG-1802 -> LDG-1803 -> LDG-1808
LDG-1802 -> LDG-1804 -----------^
LDG-1801 -> LDG-1806 -> LDG-1805 -> LDG-1808
LDG-1802 -> LDG-1807 -----------^
LDG-1801 -----------------------^
```

`LDG-1808` is the v0.1.7.8 release gate.

### Priority Levels

- **P0 (Blocker):** Required for release correctness or scope coherence.
- **P1 (Critical):** Required for the v0.1.7.8 user-facing contract to hold.
- **P2 (Important):** Required for release hygiene and future maintainability.
- **P3 (Optional):** Useful, but not a release blocker.

---

## LDG-1801: Scope, auditr Routing, And Release Baseline

**Priority:** P0
**Effort:** 0.5 day
**Dependencies:** None
**Status:** Todo

**Description:**
Finalize the v0.1.7.8 scope baseline before implementation. Confirm that the
v0.1.7.7 auditr reports are routed through
`auditr_v0_1_7_7_followup_plan.md`, that broad ergonomics findings remain parked
for v0.1.7.9, and that only reproducibility, leakage, custom-indicator boundary,
and provenance-facing findings are promoted into this cycle.

**Tasks:**
1. Read `v0_1_7_8_spec.md`, `auditr_v0_1_7_7_followup_plan.md`,
   `cycle_retrospective.md`, and `ledgr_triage_report.md`.
2. Confirm every v0.1.7.7 auditr theme has a routing decision.
3. Confirm `THEME-008` and auditr harness/task-brief issues remain excluded
   from ledgr package scope.
4. Confirm v0.1.7.9 roadmap owns broad feature-map, ctx accessor, warmup,
   print/schema, snapshot metadata, and first-run documentation work.
5. Update this ticket file and `tickets.yml` only if routing or dependencies
   change.

**Acceptance Criteria:**
- [ ] `auditr_v0_1_7_7_followup_plan.md` is the accepted routing artifact.
- [ ] Every auditr theme has a v0.1.7.8, v0.1.7.9, backlog, or auditr-owned
      routing decision.
- [ ] No auditr finding is promoted without a raw-evidence requirement.
- [ ] v0.1.7.8 scope remains limited to reproducibility, leakage, provenance,
      custom indicators, and fold-core sign-off.
- [ ] v0.1.7.9 roadmap retains the deferred ergonomics themes.

**Implementation Notes:**
- Pending.

**Verification:**
```text
documentation review only
```

**Test Requirements:**
- Documentation/routing review.
- Scope grep for forbidden release expansion.

**Source Reference:** v0.1.7.8 spec sections 1.1, 2, 8, 9, 11.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: L
review_tier: M
classification_reason: >
  Scope routing determines which auditr findings become implementation work and
  prevents v0.1.7.8 from expanding into broad strategy-author ergonomics.
invariants_at_risk:
  - release scope discipline
  - auditr evidence routing
  - roadmap sequencing
required_context:
  - inst/design/ledgr_v0_1_7_8_spec_packet/v0_1_7_8_spec.md
  - inst/design/ledgr_v0_1_7_8_spec_packet/auditr_v0_1_7_7_followup_plan.md
  - inst/design/ledgr_v0_1_7_8_spec_packet/cycle_retrospective.md
  - inst/design/ledgr_v0_1_7_8_spec_packet/ledgr_triage_report.md
  - inst/design/ledgr_roadmap.md
tests_required:
  - documentation/routing review
escalation_triggers:
  - auditr evidence reveals a confirmed runtime defect outside current scope
  - broad ergonomics work is needed to satisfy reproducibility preflight
forbidden_actions:
  - implementing runtime changes
  - adding ledgr APIs for auditr harness issues
  - promoting unclear auditr rows without raw evidence
```

---

## LDG-1802: Strategy Reproducibility Preflight Contract

**Priority:** P0
**Effort:** 0.5-1 day
**Dependencies:** LDG-1801
**Status:** Todo

**Description:**
Record the strategy preflight contract before implementation. The contract must
define Tier 1, Tier 2, Tier 3, Tier 3 error semantics, the base-R-distribution
classification rule, ledgr public helper treatment, static-analysis limits, and
the `ledgr_strategy_preflight` result shape.

**Tasks:**
1. Update `contracts.md` with the preflight contract.
2. Define Tier 1, Tier 2, and Tier 3 in terms of recoverability and
   environment responsibility.
3. Record that Tier 3 is an error by default in ordinary runs and future sweep
   mode.
4. Record that packages distributed with the active R installation may be
   Tier 1-compatible based on package metadata rather than a hard-coded
   allowlist.
5. Record that non-standard package-qualified calls are Tier 2.
6. Record that ledgr's documented public strategy-helper surface is
   Tier 1-compatible.
7. Record static-analysis limits and mutable-state caveats.
8. Define the minimum `ledgr_strategy_preflight` result object fields.

**Acceptance Criteria:**
- [ ] `contracts.md` defines Tier 1, Tier 2, and Tier 3.
- [ ] Tier 3 is specified as a classed error by default.
- [ ] Base-R-distribution classification is metadata-based, not a
      hand-maintained package allowlist.
- [ ] Ledgr's documented public strategy-helper surface is Tier 1-compatible.
- [ ] Static-analysis limits and mutable closure state are documented.
- [ ] The minimum result shape includes `tier`, `allowed`, `reason`,
      `unresolved_symbols`, `package_dependencies`, and `notes`.
- [ ] Future sweep mode is specified to inherit these tier semantics.

**Implementation Notes:**
- Pending.

**Verification:**
```text
pkgload::load_all('.', quiet=TRUE);
testthat::test_file('tests/testthat/test-documentation-contracts.R')
```

**Test Requirements:**
- Documentation contract tests for the preflight contract.
- Scope grep confirming no sweep APIs were added.

**Source Reference:** v0.1.7.8 spec sections 3, 4, 9.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: M
review_tier: H
classification_reason: >
  The tier contract gates future sweep execution and changes how strategy
  reproducibility is enforced before user code runs.
invariants_at_risk:
  - strategy reproducibility semantics
  - future sweep compatibility
  - Tier 3 enforcement
  - static analysis boundary honesty
required_context:
  - inst/design/ledgr_v0_1_7_8_spec_packet/v0_1_7_8_spec.md
  - inst/design/contracts.md
  - inst/design/ledgr_design_document.md
  - inst/design/ledgr_design_philosophy.md
tests_required:
  - tests/testthat/test-documentation-contracts.R
escalation_triggers:
  - Tier 3 semantics require breaking existing public strategy APIs
  - base R package classification cannot be made metadata-based
  - ledgr public helper calls cannot be classified without false positives
forbidden_actions:
  - implementing sweep mode
  - adding dependency declaration APIs
  - downgrading Tier 3 to warning-only behavior
```

---

## LDG-1803: Strategy Preflight Implementation And ledgr_run Integration

**Priority:** P0
**Effort:** 1-2 days
**Dependencies:** LDG-1802
**Status:** Todo

**Description:**
Implement the strategy preflight API and wire it into `ledgr_run()` so
strategies are classified before execution. Tier 3 strategies must stop with a
classed error by default. Tier 1 and Tier 2 strategies must remain accepted.

**Tasks:**
1. Add the public preflight API, preferably `ledgr_strategy_preflight()`.
2. Return a `ledgr_strategy_preflight` object with the fields defined in
   LDG-1802.
3. Use static analysis, initially via `codetools::findGlobals()`, without
   exposing codetools output shape as public API.
4. Classify base-R-distribution calls as Tier 1-compatible using package
   metadata.
5. Classify ledgr public strategy helpers as Tier 1-compatible.
6. Classify non-standard package-qualified calls as Tier 2.
7. Classify unresolved user helpers/free variables as Tier 3.
8. Wire the preflight into `ledgr_run()` before strategy execution.
9. Add classed errors for Tier 3 default execution.
10. Add tests for Tier 1, Tier 2, Tier 3, ledgr helper calls, and run
    integration.

**Acceptance Criteria:**
- [ ] Tier 1 example passes and returns `tier_1`.
- [ ] Tier 2 package-qualified example passes and returns `tier_2`.
- [ ] Ledgr public helper example is not Tier 3.
- [ ] Tier 3 unqualified helper example stops `ledgr_run()` with a classed
      error.
- [ ] Diagnostics name unresolved symbols where possible.
- [ ] `ledgr_run()` calls preflight automatically before strategy execution.
- [ ] Existing strategy, runner, and provenance tests still pass.
- [ ] No second execution path is introduced.

**Implementation Notes:**
- Pending.

**Verification:**
```text
pkgload::load_all('.', quiet=TRUE);
testthat::test_file('tests/testthat/test-strategy-provenance.R')
testthat::test_file('tests/testthat/test-strategy-contracts.R')
testthat::test_file('tests/testthat/test-experiment-run.R')
testthat::test_file('tests/testthat/test-runner.R')
```

**Test Requirements:**
- New or updated preflight tests.
- Existing strategy provenance and runner tests.
- Documentation contract tests if public docs/Rd change.

**Source Reference:** v0.1.7.8 spec sections 3, 5.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: H
review_tier: H
classification_reason: >
  The implementation runs before user strategies and affects accepted strategy
  code, future sweep eligibility, and reproducibility classifications.
invariants_at_risk:
  - ledgr_run execution contract
  - functional strategy validation
  - reproducibility tier correctness
  - no second execution path
required_context:
  - inst/design/ledgr_v0_1_7_8_spec_packet/v0_1_7_8_spec.md
  - inst/design/contracts.md
  - R/backtest-runner.R
  - R/experiment.R
  - R/strategy-provenance.R
  - R/strategy-contracts.R
  - tests/testthat/test-strategy-provenance.R
  - tests/testthat/test-strategy-contracts.R
  - tests/testthat/test-experiment-run.R
  - tests/testthat/test-runner.R
tests_required:
  - preflight classification tests
  - tests/testthat/test-strategy-provenance.R
  - tests/testthat/test-strategy-contracts.R
  - tests/testthat/test-experiment-run.R
  - tests/testthat/test-runner.R
escalation_triggers:
  - preflight rejects existing documented ledgr examples
  - Tier 3 cannot be detected without high false positives
  - ledgr_run integration changes run identity or result tables
forbidden_actions:
  - implementing sweep mode
  - adding worker environment management
  - treating ledgr public helpers as unresolved Tier 3 symbols
  - weakening existing strategy result validation
```

---

## LDG-1804: On Reproducibility Article And Reference Links

**Priority:** P1
**Effort:** 1 day
**Dependencies:** LDG-1802
**Status:** Todo

**Description:**
Create `vignettes/reproducibility.Rmd` as the authoritative narrative article
for ledgr's experiment model, provenance model, strategy extraction, trust
semantics, reproducibility tiers, and Tier 2 user responsibilities.

**Tasks:**
1. Add `vignettes/reproducibility.Rmd` with title "On Reproducibility: ledgr
   Design Choices".
2. Explain the experiment model: sealed snapshot, strategy, params, features,
   opening state, run identity, and derived result tables.
3. Explain the provenance model: stored source, hashes, params, dependencies,
   R version, and reproducibility tier.
4. Explain `ledgr_extract_strategy()`, `trust = FALSE`, and `trust = TRUE`.
5. Explain why stored source text is not full reproducibility.
6. Teach Tier 1, Tier 2, and Tier 3 with compact examples.
7. Explain that Tier 2 is allowed but requires user-managed environment parity.
8. Mention `renv`, Docker, `{rix}`, and `{uvr}` only as possible environment
   management tools, not as ledgr dependencies or tutorials.
9. Update `_pkgdown.yml` navigation.
10. Link from `?ledgr_extract_strategy`, `?ledgr_experiment`, and preflight
    docs where appropriate.
11. Adjust `experiment-store.Rmd` so stored-strategy extraction is a concise
    workflow example that cross-links to the reproducibility article.
12. Add documentation contract tests.

**Acceptance Criteria:**
- [ ] `vignettes/reproducibility.Rmd` exists and is linked in pkgdown.
- [ ] Rendered companion markdown exists if this repo keeps one for the article.
- [ ] The article is authoritative for provenance, extraction, trust semantics,
      and tiers.
- [ ] `experiment-store.Rmd` links to the article and does not duplicate the
      full trust-boundary explanation.
- [ ] Public docs explain Tier 2 environment responsibility without teaching
      environment-management tools.
- [ ] Documentation contract tests pin the experiment/provenance model, safe
      extraction boundary, tier definitions, and Tier 3 behavior.

**Implementation Notes:**
- Pending.

**Verification:**
```text
pkgload::load_all('.', quiet=TRUE);
testthat::test_file('tests/testthat/test-documentation-contracts.R')
```

**Test Requirements:**
- Documentation contract tests.
- Vignette render check if content includes executed examples.

**Source Reference:** v0.1.7.8 spec sections 2, 6, 10.

**Classification:**
```yaml
risk_level: high
implementation_tier: M
review_tier: H
classification_reason: >
  The article teaches trust and provenance semantics; misleading wording could
  cause users to over-trust stored source or misunderstand Tier 2.
invariants_at_risk:
  - provenance trust boundary
  - safe strategy extraction semantics
  - reproducibility tier documentation
  - experiment-store docs consistency
required_context:
  - inst/design/ledgr_v0_1_7_8_spec_packet/v0_1_7_8_spec.md
  - inst/design/contracts.md
  - R/strategy-extract.R
  - R/experiment.R
  - vignettes/experiment-store.Rmd
  - tests/testthat/test-documentation-contracts.R
tests_required:
  - tests/testthat/test-documentation-contracts.R
escalation_triggers:
  - docs require changing strategy extraction behavior
  - trust semantics conflict with existing tests
  - Tier 2 environment language implies ledgr manages external environments
forbidden_actions:
  - evaluating stored strategy source in safe examples
  - making renv, Docker, rix, or uvr package dependencies
  - duplicating long trust-boundary explanations across multiple articles
```

---

## LDG-1805: On Leakage Article And Strategy Vignette Cleanup

**Priority:** P1
**Effort:** 1 day
**Dependencies:** LDG-1806
**Status:** Todo

**Description:**
Create `vignettes/leakage.Rmd` as the public narrative article for ledgr's
leakage boundaries. The article must teach strategy-boundary leakage,
feature-boundary leakage, and remaining user responsibilities without claiming
ledgr certifies all research processes.

**Tasks:**
1. Add `vignettes/leakage.Rmd` with title "On Leakage: ledgr Design Choices".
2. Include a blunt `lead(close)` example as a simple first warning.
3. Include a subtler full-sample preprocessing example, such as full-sample
   `quantile()` thresholding.
4. Explain the strategy boundary: pulse context, no future market-data table,
   current positions/cash/equity/features.
5. Explain the feature boundary: registered indicators, IDs, warmup, bounded
   scalar windows, vectorized `series_fn` shape/value checks.
6. Explain residual risks: biased snapshots, bad availability timestamps,
   survivorship, research-loop leakage, and semantically leaky custom
   `series_fn`.
7. Link to the promoted custom-indicator article from LDG-1806.
8. Update `strategy-development.Rmd` so the old leakage section points to the
   new article and no longer makes the over-absolute "no object" claim without
   caveat.
9. Update `_pkgdown.yml` navigation.
10. Add documentation contract tests.

**Acceptance Criteria:**
- [ ] `vignettes/leakage.Rmd` exists and is linked in pkgdown.
- [ ] The subtle feature-construction leak is explained.
- [ ] The article distinguishes ledgr-enforced boundaries from user
      responsibilities.
- [ ] Public docs do not cite `ledgr_check_no_lookahead()` as public API.
- [ ] `strategy-development.Rmd` links to the leakage article and softens the
      old overclaim.
- [ ] The leakage article links to the custom-indicator article.
- [ ] Documentation contract tests pin the key leakage-boundary claims.

**Implementation Notes:**
- Pending.

**Verification:**
```text
pkgload::load_all('.', quiet=TRUE);
testthat::test_file('tests/testthat/test-documentation-contracts.R')
```

**Test Requirements:**
- Documentation contract tests.
- Vignette render check if examples execute.

**Source Reference:** v0.1.7.8 spec sections 1.1, 7, 10.

**Classification:**
```yaml
risk_level: high
implementation_tier: M
review_tier: H
classification_reason: >
  Leakage documentation is a core positioning and correctness surface. Overclaim
  or underclaim can mislead users about what ledgr prevents.
invariants_at_risk:
  - no-lookahead teaching accuracy
  - feature-boundary honesty
  - custom series_fn residual risk
  - public API boundary for internal diagnostics
required_context:
  - inst/design/ledgr_v0_1_7_8_spec_packet/v0_1_7_8_spec.md
  - vignettes/strategy-development.Rmd
  - vignettes/indicators.Rmd
  - vignettes/custom-indicators.md
  - R/features-engine.R
  - tests/testthat/test-documentation-contracts.R
tests_required:
  - tests/testthat/test-documentation-contracts.R
escalation_triggers:
  - leakage article requires exporting internal diagnostics
  - custom-indicator article is not ready to link
  - docs imply ledgr certifies external data availability or research-loop purity
forbidden_actions:
  - exporting `ledgr_check_no_lookahead()` without a separate ticket
  - claiming ledgr eliminates all leakage
  - adding new runtime feature APIs for documentation convenience
```

---

## LDG-1806: Custom Indicator Article And Placeholder Cleanup

**Priority:** P1
**Effort:** 1 day
**Dependencies:** LDG-1801
**Status:** Todo

**Description:**
Resolve the stale public vignette placeholders and promote custom-indicator
documentation into current public teaching material. The custom-indicator
article must explain scalar `fn`, vectorized `series_fn`, warmup, fingerprints,
determinism, and the residual leakage risk of full-series code.

**Tasks:**
1. Replace `vignettes/custom-indicators.md` with a current article source or
   create `vignettes/custom-indicators.Rmd` plus rendered companion.
2. Explain `ledgr_indicator()`, scalar `fn(window, params)`, and
   `series_fn(bars, params)`.
3. Explain `requires_bars`, `stable_after`, warmup `NA_real_`, shape/value
   validation, and fingerprints.
4. Explain deterministic params and unsafe function patterns at the level users
   need for authoring.
5. Explain that `series_fn` receives full bars and therefore output validation
   does not prove causal correctness.
6. Cover `ledgr_adapter_r()` and `ledgr_adapter_csv()` only if doing so does not
   make the article too broad.
7. Decide whether `interactive-strategy-development.md` is removed from the
   public vignette surface or explicitly routed to a later ticket.
8. Update `_pkgdown.yml` only if the custom-indicator article becomes a public
   pkgdown article.
9. Add documentation contract tests.

**Acceptance Criteria:**
- [ ] `custom-indicators.md` no longer contains stale "Full content in v0.1.3"
      placeholder text.
- [ ] Custom indicator docs explain scalar and vectorized paths.
- [ ] Custom indicator docs explain `series_fn` leakage residual risk.
- [ ] `interactive-strategy-development.md` is moved, removed, or routed with a
      recorded reason.
- [ ] Leakage article can link to current custom-indicator documentation.
- [ ] Documentation contract tests pin the absence of stale placeholder text.

**Implementation Notes:**
- Pending.

**Verification:**
```text
pkgload::load_all('.', quiet=TRUE);
testthat::test_file('tests/testthat/test-documentation-contracts.R')
```

**Test Requirements:**
- Documentation contract tests.
- Vignette render check if promoted to Rmd.

**Source Reference:** v0.1.7.8 spec sections 3, 7, 9, 10.

**Classification:**
```yaml
risk_level: high
implementation_tier: M
review_tier: H
classification_reason: >
  Custom indicators are the highest-risk user-extensible feature boundary for
  accidental leakage and deterministic reproducibility drift.
invariants_at_risk:
  - feature generation contract
  - custom series_fn leakage caveat
  - public documentation freshness
  - pkgdown article navigation
required_context:
  - inst/design/ledgr_v0_1_7_8_spec_packet/v0_1_7_8_spec.md
  - vignettes/custom-indicators.md
  - vignettes/interactive-strategy-development.md
  - R/indicator.R
  - R/features-engine.R
  - R/indicator_adapters.R
  - tests/testthat/test-documentation-contracts.R
tests_required:
  - tests/testthat/test-documentation-contracts.R
escalation_triggers:
  - docs require changing custom indicator API
  - adapter docs conflict with existing tests
  - placeholder cleanup would remove useful public content without replacement
forbidden_actions:
  - changing feature computation behavior
  - exporting internal diagnostics
  - adding optional package dependencies for examples
```

---

## LDG-1807: Fold-Core And Output-Handler Boundary Sign-Off

**Priority:** P1
**Effort:** 0.5-1 day
**Dependencies:** LDG-1802
**Status:** Todo

**Description:**
Record the written fold-core/output-handler boundary that v0.1.8 sweep mode must
inherit. This is a design-contract ticket only; it must not implement sweep
mode or refactor the runner.

**Tasks:**
1. Review the v0.1.8 roadmap sweep section and current runner/persistence
   architecture.
2. Define the fold-core as the deterministic per-pulse execution engine.
3. Define output handlers as persistence/accumulation layers for ledger events,
   fills, equity rows, feature rows, telemetry, and summaries.
4. Record that `ledgr_run()` and future `ledgr_sweep()` must share the same
   fold semantics.
5. Record that sweep may remove persistence but may not change execution
   semantics.
6. Record how the v0.1.7.8 preflight is called before future sweep execution.
7. Update `contracts.md` or create a dedicated design document under
   `inst/design/`.

**Acceptance Criteria:**
- [ ] Fold-core and output-handler are defined in a written contract.
- [ ] Contract states sweep and run share execution semantics.
- [ ] Contract states output handling may differ but strategy, target, fill,
      state, and feature semantics may not.
- [ ] Contract states future sweep inherits v0.1.7.8 preflight semantics.
- [ ] No runner refactor or sweep implementation is performed in this ticket.

**Implementation Notes:**
- Pending.

**Verification:**
```text
documentation review only
```

**Test Requirements:**
- Documentation contract scan if `contracts.md` changes.
- Scope grep confirming no sweep API was added.

**Source Reference:** v0.1.7.8 spec sections 3, 4, 9; roadmap v0.1.8 section.

**Classification:**
```yaml
risk_level: high
implementation_tier: L
review_tier: H
classification_reason: >
  The boundary constrains the v0.1.8 sweep architecture. If it is vague, sweep
  can drift into a second execution engine.
invariants_at_risk:
  - run/sweep semantic parity
  - no second execution path
  - fold/output separation
  - preflight inheritance by sweep
required_context:
  - inst/design/ledgr_v0_1_7_8_spec_packet/v0_1_7_8_spec.md
  - inst/design/ledgr_roadmap.md
  - inst/design/contracts.md
  - R/backtest-runner.R
  - R/run-store.R
tests_required:
  - documentation contract scan if contracts.md changes
  - scope grep for sweep APIs
escalation_triggers:
  - boundary cannot be defined without runner refactor
  - v0.1.8 roadmap contradicts current runner semantics
  - output handler separation requires production code changes now
forbidden_actions:
  - implementing `ledgr_sweep()`
  - refactoring the runner
  - adding parallel backend code
  - changing result table semantics
```

---

## LDG-1808: v0.1.7.8 Release Gate, NEWS, And Packet Finalization

**Priority:** P0
**Effort:** 0.5-1 day
**Dependencies:** LDG-1801, LDG-1803, LDG-1804, LDG-1805, LDG-1807
**Status:** Todo

**Description:**
Finalize the v0.1.7.8 release after all implementation and documentation tracks
are complete. Update NEWS, contract tests, ticket status, and release notes;
run local verification and ensure Ubuntu/Windows CI pass before merge.

**Tasks:**
1. Update `NEWS.md` with delivered v0.1.7.8 bullets.
2. Update `v0_1_7_8_tickets.md` and `tickets.yml` statuses and implementation
   notes.
3. Confirm `auditr_v0_1_7_7_followup_plan.md` routing is preserved.
4. Confirm v0.1.7.9 roadmap still owns deferred ergonomics.
5. Run targeted documentation/preflight tests.
6. Run full Windows tests.
7. Push branch and verify remote Ubuntu/Windows CI before merge.
8. Do not move release tags unless explicitly requested after the release gate.

**Acceptance Criteria:**
- [ ] NEWS summarizes delivered v0.1.7.8 scope in past tense.
- [ ] Tickets and `tickets.yml` statuses are consistent.
- [ ] Documentation contract tests pass.
- [ ] Strategy preflight tests pass.
- [ ] Full Windows tests pass locally.
- [ ] Remote Ubuntu/Windows CI is green.
- [ ] No generated local artifacts are committed.
- [ ] No sweep, paper/live, OMS, dependency-management, or broad ergonomics APIs
      were added.

**Implementation Notes:**
- Pending.

**Verification:**
```text
pkgload::load_all('.', quiet=TRUE);
testthat::test_local('.', reporter='summary')
```

**Test Requirements:**
- Full test suite.
- Remote CI.
- Scope grep for forbidden APIs.

**Source Reference:** v0.1.7.8 spec sections 9, 10, 11.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: M
review_tier: H
classification_reason: >
  Release-gate work verifies the whole v0.1.7.8 contract and protects against
  scope creep, stale tickets, generated artifacts, and CI regressions.
invariants_at_risk:
  - release integrity
  - CI parity
  - ticket/status consistency
  - forbidden scope exclusions
required_context:
  - inst/design/ledgr_v0_1_7_8_spec_packet/v0_1_7_8_spec.md
  - inst/design/ledgr_v0_1_7_8_spec_packet/v0_1_7_8_tickets.md
  - inst/design/ledgr_v0_1_7_8_spec_packet/tickets.yml
  - NEWS.md
  - tests/testthat/test-documentation-contracts.R
tests_required:
  - full test suite
  - documentation contract tests
  - strategy preflight tests
  - remote CI
escalation_triggers:
  - Ubuntu CI fails on preflight or docs changes
  - generated artifacts appear in git status
  - release gate reveals scope creep into v0.1.8 or v0.1.7.9 work
forbidden_actions:
  - committing generated local artifacts
  - moving tags without explicit maintainer request
  - weakening tests to pass CI
  - adding release-scope features during the gate
```
