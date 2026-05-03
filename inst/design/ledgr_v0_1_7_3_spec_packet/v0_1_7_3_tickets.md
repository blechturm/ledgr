# ledgr v0.1.7.3 Tickets

**Version:** 0.1.7.3  
**Date:** May 2, 2026  
**Total Tickets:** 9  

---

## Ticket Organization

v0.1.7.3 is a correctness and explainability subcycle with four coordinated
tracks:

1. **Accounting correctness:** make ledger fills the accounting oracle and fix
   the Episode 013 equity/position/return inconsistency.
2. **Metric definitions and independent oracles:** define every public summary
   metric and test those definitions from public result tables.
3. **Documentation discoverability:** make installed articles discoverable from
   function-level help, package-level help, and pkgdown reading order.
4. **Vignette and concept alignment:** add accounting concepts, tighten helper
   and feature-ID docs, and review the existing articles against the north star.

Under `inst/design/model_routing.md`, ticket generation, contract changes,
execution/fill/ledger semantics, persistence-sensitive behavior, and release
gates are Tier H. Documentation-only tickets may be Tier M implementation with
Tier H review when they teach public contracts.

### Dependency DAG

```text
LDG-1301 -> LDG-1302 -> LDG-1303 -> LDG-1304 -> LDG-1305 -> LDG-1309
LDG-1301 -------------------------> LDG-1306 -------------> LDG-1309
LDG-1304 -------------------------> LDG-1307 -------------> LDG-1309
LDG-1305 -------------------------> LDG-1307
LDG-1306 -------------------------> LDG-1307
LDG-1303 -> LDG-1304 -------------> LDG-1308 -------------> LDG-1309
```

`LDG-1309` is the v0.1.7.3 release gate.

### Priority Levels

- **P0 (Blocker):** Required for correctness or release coherence.
- **P1 (Critical):** Required for the user story to work.
- **P2 (Important):** Required for discoverability or documentation quality.
- **P3 (Optional):** Useful, but not a release blocker.

---

## LDG-1301: Patch Scope, Metadata, And Accounting Contract Baseline

**Priority:** P0  
**Effort:** 1 day  
**Dependencies:** None  
**Status:** Done

**Description:**
Finalize the v0.1.7.3 release boundary before implementation begins. This
ticket makes the correctness subcycle explicit, records non-goals, and prepares
the contract surface for metric and ledger-accounting definitions.

**Tasks:**
1. Review `v0_1_7_3_spec.md` and `ledgr_triage_report.md` for internal
   consistency.
2. Create a draft `NEWS.md` v0.1.7.3 section with placeholders for correctness,
   metric documentation, and discoverability work.
3. Confirm `DESCRIPTION` version handling is deferred to the release gate.
4. Add or update `contracts.md` scaffolding for accounting/metric definitions
   without finalizing definitions that belong to LDG-1303.
5. Confirm `ledgr_docs()` is explicitly out of scope for this cycle.
6. Confirm no sweep/tune, short-selling, leverage, broker, or new execution-path
   work is in scope.
7. Confirm the old `inst/design/ledgr_v0_1_7_2/` packet move/deletion state is
   intentional before commit.

**Acceptance Criteria:**
- [x] v0.1.7.3 spec and triage report agree on scope.
- [x] `NEWS.md` has a draft v0.1.7.3 section.
- [x] `contracts.md` has a clear location for metric/accounting definitions.
- [x] `ledgr_docs()` remains out of scope.
- [x] No sweep/tune APIs, short-selling, leverage, or broker semantics are in
      scope.
- [x] Ticket statuses, dependencies, and classifications are internally
      consistent.

**Test Requirements:**
- Documentation consistency scan.
- Export/API inventory scan.
- Spec/ticket filename scan.

**Source Reference:** v0.1.7.3 spec sections 1, 2, 8.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: H
review_tier: H
classification_reason: >
  Version scoping, ticket generation, contract baseline decisions, and
  non-goal boundaries are Tier H by routing rule.
invariants_at_risk:
  - release scope
  - public API boundary
  - accounting contract placement
  - documentation contract
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_3_spec_packet/v0_1_7_3_spec.md
  - inst/design/ledgr_v0_1_7_3_spec_packet/ledgr_triage_report.md
  - inst/design/contracts.md
  - inst/design/release_ci_playbook.md
  - NEWS.md
tests_required:
  - documentation consistency scan
  - export/API inventory scan
  - spec/ticket filename scan
escalation_triggers:
  - metric definitions require execution changes before scope is settled
  - new public documentation helper appears necessary
  - sweep/tune or short-selling scope appears necessary
forbidden_actions:
  - adding ledgr_docs
  - adding sweep/tune APIs
  - adding short-selling or leverage semantics
  - changing execution behavior during scope setup
```

---

## LDG-1302: Equity Curve And Ledger Fill Consistency

**Priority:** P0  
**Effort:** 2-4 days  
**Dependencies:** LDG-1301  
**Status:** Done

**Description:**
Fix the confirmed Episode 013 defect where fills and trades close a position but
the final equity curve reports an open position and inflated total return.
Ledger fills are the accounting oracle for this ticket.

**Tasks:**
1. Convert the Episode 013 reproducible script into a focused failing
   regression test.
2. Assert that fills contain BUY 1 and SELL 1 for the same instrument.
3. Assert that closed trades contain one realized P&L row of 1.
4. Assert that cumulative fill deltas imply final position zero.
5. Assert that the final equity row does not report `positions_value` for an
   unfilled open position.
6. Identify whether the defect lives in standard mode, audit-log mode, or shared
   fill/equity timing logic.
7. Fix the minimum runner/result path needed so equity rows are written at a
   coherent lifecycle boundary.
8. Preserve existing fill and ledger semantics unless the regression proves they
   are the source of inconsistency.

**Acceptance Criteria:**
- [x] Episode 013 has a failing-then-passing regression test.
- [x] The regression passes in every supported execution mode that writes an
      equity curve.
- [x] Final public positions reconstructed from fills agree with final equity
      `positions_value`.
- [x] Final total return no longer includes an unfilled open position.
- [x] Existing flat, open-only, and closed-trade tests still pass.

**Test Requirements:**
- Episode 013 regression test.
- Standard-mode and audit-log-mode coverage where exposed.
- Existing backtest runner tests.
- Existing result/equity tests.

**Source Reference:** v0.1.7.3 spec sections R1, R2, A1.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  The ticket touches fill timing, equity curve writing, event-ledger
  interpretation, and public metrics. Execution and ledger semantics are hard
  escalation areas, so Tier H implementation and review are required.
invariants_at_risk:
  - event ledger semantics
  - fill lifecycle timing
  - equity curve correctness
  - deterministic replay
  - public result interpretation
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_3_spec_packet/v0_1_7_3_spec.md
  - inst/design/ledgr_v0_1_7_3_spec_packet/ledgr_triage_report.md
  - inst/design/contracts.md (Execution Contract, Result Contract)
  - C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.7.2/2026-05-02_013_trades_fills_and_metrics/
  - R/backtest-runner.R
  - R/derived-state.R
  - R/results.R
tests_required:
  - Episode 013 regression test
  - execution-mode parity test where exposed
  - existing backtest runner tests
  - existing result/equity tests
escalation_triggers:
  - fix requires changing fill semantics
  - standard mode and audit-log mode disagree
  - derived-state reconstruction disagrees with public fills
  - result schema changes appear necessary
forbidden_actions:
  - masking inconsistency in print methods only
  - changing fills to match broken equity rows
  - adding a second result reconstruction path for one metric
  - weakening ledger/event tests
```

---

## LDG-1303: Metric Definitions And Independent Oracle Fixtures

**Priority:** P0  
**Effort:** 3-5 days  
**Dependencies:** LDG-1302  
**Status:** Done

**Description:**
Define ledgr's public summary/comparison metrics and add independent oracle
tests that recompute them from public result tables. This ticket must resolve
the `initial capital` definition before writing total-return oracle tests.

**Tasks:**
1. Decide and document the exact source of `initial capital` for total-return
   calculations.
2. Add canonical definitions for total return, annualized return, max drawdown,
   annualized volatility, total trades, win rate, average trade, and time in
   market to `contracts.md`.
3. Build deterministic accounting fixtures for flat, open-only, profitable
   round-trip, losing round-trip, multi-instrument, final-bar no-fill, and
   helper-flooring scenarios.
4. Recompute expected metrics in tests from public result tables:
   `fills`, `trades`, and `equity`.
5. Ensure tests do not call the same internal metric functions for both actual
   and expected values.
6. Align `summary()`, `ledgr_compare_runs()`, `ledgr_run_list()`, and related
   metric consumers with the documented definitions.
7. Update zero-row metric expectations, including `win_rate = NA` when no
   closed trades exist.

**Acceptance Criteria:**
- [x] `initial capital` has one documented implementation/test definition.
- [x] Every displayed summary metric has a definition in `contracts.md`.
- [x] Independent oracle tests cover the deterministic fixture set.
- [x] `summary()`, `ledgr_compare_runs()`, and `ledgr_run_list()` agree on
      metric definitions.
- [x] `n_trades` counts closed trade rows, not fill rows.
- [x] No expected metric is computed by reusing the internal function under
      test.

**Test Requirements:**
- Independent metric oracle tests.
- Deterministic accounting fixture tests.
- Existing summary, comparison, run-store, and result tests.
- Zero-row metric tests.

**Source Reference:** v0.1.7.3 spec sections R3, R4, R5, B1.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  Public metric definitions are contract-sensitive and derive from ledger,
  trade, and equity outputs. Changes may touch summary, comparison, run-store,
  and result semantics, so Tier H implementation and review are required.
invariants_at_risk:
  - metric definitions
  - result table interpretation
  - comparison semantics
  - summary output correctness
  - zero-row result behavior
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_3_spec_packet/v0_1_7_3_spec.md
  - inst/design/contracts.md (Result Contract, Persistence Contract)
  - R/metrics.R
  - R/results.R
  - R/run-store.R
  - R/backtest.R
  - tests/testthat/test-run-compare.R
  - tests/testthat/test-run-store.R
tests_required:
  - independent metric oracle tests
  - deterministic accounting fixture tests
  - summary/comparison/run-list consistency tests
  - zero-row metric tests
escalation_triggers:
  - current metric implementation conflicts with intended contract
  - annualization assumptions are ambiguous
  - initial capital cannot be derived consistently
  - open-position semantics require broader accounting decisions
forbidden_actions:
  - using internal metric functions as expected-value oracles
  - changing metric labels without definitions
  - hiding edge cases in formatting
  - redefining fills or trades to force metric agreement
```

---

## LDG-1304: Summary, Result Semantics, And Accounting Vignette

**Priority:** P1  
**Effort:** 3-5 days  
**Dependencies:** LDG-1303  
**Status:** Done

**Description:**
Document the metric and result-table concepts that LDG-1303 defines. Add an
installed `metrics-and-accounting` vignette and update help pages for summary
and result access.

**Tasks:**
1. Create `vignettes/metrics-and-accounting.Rmd` as an installed vignette.
2. Explain ledger events, fills, trades, equity curve construction, open
   positions, final-bar no-fill, and zero-trade runs.
3. Show how to recompute key metrics from public result tables using ordinary R
   and dplyr-style transformations.
4. Update summary help to define every displayed metric and the return value of
   `summary(bt)`.
5. Update `ledgr_results()` help to clarify fills versus trades, zero-row
   schemas, realized P&L, `side`, `qty`, and `action`.
6. Add examples that do not depend on network access.
7. Render the vignette and update generated markdown/html according to repo
   practice.

**Acceptance Criteria:**
- [x] `metrics-and-accounting` is an installed vignette.
- [x] The vignette teaches metric derivation from public result tables.
- [x] Summary help defines all displayed metrics.
- [x] `ledgr_results()` help distinguishes fills, trades, open positions, and
      zero-row results.
- [x] Docs state that zero closed trades and `win_rate = NA` can be correct.
- [x] Examples run against offline demo data or tiny in-memory fixtures.

**Test Requirements:**
- Vignette render.
- Documentation checks for metric terms.
- Example execution where practical.
- Existing documentation tests.

**Source Reference:** v0.1.7.3 spec sections B2, B3, D1.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: H
classification_reason: >
  The work is documentation-heavy, but it teaches public accounting and metric
  contracts. Tier M implementation is acceptable with Tier H review for
  correctness against LDG-1303 definitions.
invariants_at_risk:
  - metric documentation accuracy
  - result table semantics
  - installed documentation contract
  - user interpretation of open positions
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_3_spec_packet/v0_1_7_3_spec.md
  - inst/design/contracts.md (Result Contract)
  - vignettes/strategy-development.Rmd
  - vignettes/experiment-store.Rmd
  - R/results.R
  - R/metrics.R
tests_required:
  - vignette render
  - documentation scans for metric definitions
  - existing documentation tests
escalation_triggers:
  - docs expose metric ambiguity left unresolved by LDG-1303
  - examples reveal public table inconsistency
  - summary return behavior must change
forbidden_actions:
  - documenting metrics differently from contracts
  - linking to metrics-and-accounting before the vignette exists
  - adding network-dependent examples
  - treating close calls as data-safety requirements
```

---

## LDG-1305: Function-Level Help Discoverability

**Priority:** P1  
**Effort:** 2-3 days  
**Dependencies:** LDG-1304  
**Status:** Done

**Description:**
Make installed articles discoverable from the help pages users and agents
actually inspect first, not only from the README.

**Tasks:**
1. Add a package-level "Start here" documentation spine to `?ledgr` /
   `?ledgr-package`.
2. Add `@seealso` or `@section Articles:` blocks to key entry points:
   `ledgr_run()`, `ledgr_experiment()`, `ledgr_backtest()`,
   `ledgr_results()`, `ledgr_compare_runs()`, snapshot creation entry points,
   and the strategy helper functions.
3. Include both interactive and noninteractive discovery forms:
   `vignette(...)` and `system.file("doc", ..., package = "ledgr")`.
4. Include the installed `metrics-and-accounting` path after LDG-1304 creates
   it.
5. Add documentation tests or scans that ensure core Rd pages mention the
   intended articles.
6. Regenerate Rd files.

**Acceptance Criteria:**
- [x] `?ledgr` / package help lists installed vignettes and `system.file()`
      lookup commands.
- [x] Core entry-point help pages point to the right installed articles.
- [x] No help page links to an article that is not installed.
- [x] Documentation scans pin the discovery spine.
- [x] Background positioning articles remain pkgdown-only.

**Test Requirements:**
- Rd documentation scan.
- Installed vignette list check.
- Existing documentation contract tests.

**Source Reference:** v0.1.7.3 spec sections R6, R7, C1.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: H
classification_reason: >
  Roxygen/help-page work is bounded, but it changes installed documentation
  discovery and must preserve the installed-vs-pkgdown-only article boundary.
  Tier H review is required for documentation contract compliance.
invariants_at_risk:
  - documentation discoverability
  - installed vignette boundary
  - package-level help accuracy
  - article link stability
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_3_spec_packet/v0_1_7_3_spec.md
  - inst/design/contracts.md (Documentation Contract)
  - R/*.R roxygen for entry points
  - vignettes/
  - vignettes/articles/
tests_required:
  - Rd documentation scan
  - installed vignette list check
  - documentation contract tests
escalation_triggers:
  - desired article is not installed
  - roxygen organization obscures entry-point ownership
  - pkgdown-only article would need to become installed
forbidden_actions:
  - adding ledgr_docs
  - linking to non-installed articles as installed vignettes
  - moving positioning articles into installed vignettes
  - adding browser-only discovery instructions as the sole path
```

---

## LDG-1306: Helper Composition, Feature IDs, And TTR Output Docs

**Priority:** P1  
**Effort:** 2-4 days  
**Dependencies:** LDG-1301  
**Status:** Done

**Description:**
Close the helper and feature documentation gaps from Episodes 006 and 018:
integer flooring in `target_rebalance()`, the helper composition contract,
exact feature IDs, multi-output TTR indicators, and
`ledgr_signal_strategy()` signature alignment.

**Tasks:**
1. Review Episode 006 raw `framework_feedback.md` before finalizing the exact
   TTR/feature-ID docs.
2. Document that `target_rebalance()` floors target quantities to whole shares.
3. Add one example showing pre-floor allocation and post-floor target quantity.
4. Add a compact helper composition contract:
   signal -> selection -> weights -> target -> existing execution path.
5. Strengthen `ledgr_feature_id()` examples for helper and `ctx$feature()`
   workflows.
6. Clarify multi-output TTR indicator IDs, including BBands output names and
   MACD argument consistency.
7. Align `ledgr_signal_strategy()` help with its actual signature and the
   broader `function(ctx, params)` strategy convention.
8. Add documentation scans or examples where practical.

**Acceptance Criteria:**
- [x] Episode 006 raw findings are reviewed and either addressed or explicitly
      deferred.
- [x] `target_rebalance()` docs state whole-share floor sizing.
- [x] The helper composition contract is documented.
- [x] Multi-output TTR IDs are easier to discover before use.
- [x] `ledgr_feature_id()` appears before feature IDs are used in new examples.
- [x] `ledgr_signal_strategy()` help matches the implemented signature.

**Test Requirements:**
- Documentation render.
- Documentation scans for feature-ID-before-use examples.
- Help-page checks for `target_rebalance()` flooring.
- Existing helper and TTR tests.

**Source Reference:** v0.1.7.3 spec sections R8, R9, D3; auditr Episodes 006
and 018.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: H
classification_reason: >
  Primarily documentation and roxygen examples, but it teaches public helper
  contracts and feature-ID semantics. Tier M implementation is acceptable with
  Tier H review for contract accuracy.
invariants_at_risk:
  - helper composition contract
  - target quantity interpretation
  - feature ID/fingerprint expectations
  - TTR multi-output semantics
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_3_spec_packet/v0_1_7_3_spec.md
  - C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.7.2/2026-05-02_006_bbands_macd/framework_feedback.md
  - C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.7.2/2026-05-02_018_manual_vs_helper_parity/framework_feedback.md
  - inst/design/contracts.md (Strategy Contract, Context Contract)
  - R/strategy-helpers.R
  - R/strategy-fn.R
  - R/indicator-ttr.R
  - vignettes/strategy-development.Rmd
tests_required:
  - documentation render
  - feature-ID documentation scans
  - helper/TTR existing tests
escalation_triggers:
  - docs reveal unsupported helper behavior
  - TTR output semantics need implementation changes
  - target flooring behavior conflicts with code
forbidden_actions:
  - changing feature IDs for documentation convenience
  - auto-registering helper features
  - changing target_rebalance semantics without a correctness ticket
  - adding helper APIs outside the spec
```

---

## LDG-1307: Pkgdown Reading Order And Indicator Vignette Spine

**Priority:** P2  
**Effort:** 2-4 days  
**Dependencies:** LDG-1304, LDG-1305, LDG-1306  
**Status:** Done

**Description:**
Make the pkgdown site imply a reading order and review the existing installed
and pkgdown-only vignettes against the ledgr teaching north star. Consolidate
indicator teaching into one installed `indicators` vignette and retire the
redundant installed `ttr-indicators` teaching path.

**Tasks:**
1. Update `_pkgdown.yml` article sections to distinguish Start Here, Core
   Concepts, Research Workflow, and Reference/Design if feasible.
2. Keep positioning/background articles under `vignettes/articles/` and
   pkgdown-only.
3. Treat links to `inst/design/` materials as aspirational unless a deliberate
   pkgdown/design-reference decision is made.
4. Add "what to read next" links to installed vignettes where useful.
5. Review `getting-started`, `strategy-development`, `experiment-store`,
   current indicator/TTR docs, and pkgdown-only articles against the north-star
   checklist.
6. Create or refactor to a general installed `indicators` vignette that teaches
   built-in ledgr indicators and TTR-backed indicators under one mental model.
7. Fold reusable `ttr-indicators` teaching content into `indicators`; move
   TTR-specific reference facts to `?ledgr_ind_ttr` where practical.
8. Remove `ttr-indicators` from the installed article spine unless a deliberate
   contract exception is documented.
9. Update package help, function-level article links, pkgdown navigation,
   contracts, and documentation tests for the new indicator spine.
10. Prefer `.R` script snippets over fragile shell one-liners for examples with
   `$` or multi-line strategy code.
11. Render changed vignettes/articles and build pkgdown if site navigation
   changes.

**Acceptance Criteria:**
- [x] Pkgdown article order communicates the intended reading path.
- [x] Installed versus pkgdown-only article boundaries are preserved.
- [x] No design packet is copied into installed vignettes just for pkgdown.
- [x] Existing vignettes have been reviewed against the north-star checklist.
- [x] `indicators` is the installed teaching article for feature IDs,
      indicator warmup, built-in indicators, and TTR-backed indicators.
- [x] `ledgr_feature_id()`, `ledgr_ind_returns()`, and `ledgr_ind_ttr()` help
      pages link to the installed `indicators` article.
- [x] `ttr-indicators` is not left as a redundant installed teaching vignette.
- [x] TTR-specific output names and warmup details remain discoverable from
      function help.
- [x] Windows-facing examples avoid fragile `$` shell quoting where practical.
- [x] Changed articles render and pkgdown builds if `_pkgdown.yml` changes.

**Test Requirements:**
- Vignette/article renders.
- Pkgdown build if navigation changes.
- Installed-vignette boundary tests.
- Package-help and function-help article-link tests.
- Documentation scans for shell-style examples where practical.

**Source Reference:** v0.1.7.3 spec sections R9, R10, R11, C2, D2, D3;
`inst/design/ledgr_feature_map_ux.md` documentation implications.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: H
classification_reason: >
  Documentation navigation and article review are bounded, but they affect the
  public learning path and installed/pkgdown-only boundary. Tier H review is
  required to protect the documentation contract.
invariants_at_risk:
  - pkgdown navigation
  - installed-vs-pkgdown article boundary
  - documentation teaching order
  - Windows example usability
  - indicator documentation spine
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_3_spec_packet/v0_1_7_3_spec.md
  - inst/design/contracts.md (Documentation Contract)
  - inst/design/ledgr_feature_map_ux.md
  - _pkgdown.yml
  - vignettes/
  - vignettes/articles/
  - R/indicator-ttr.R
  - inst/design/release_ci_playbook.md
tests_required:
  - vignette/article render
  - pkgdown build if navigation changes
  - installed-vignette boundary tests
  - package/function help article-link tests
escalation_triggers:
  - pkgdown requires copying inst/design files into vignettes
  - article order conflicts with installed-vignette policy
  - examples need runtime changes to remain honest
  - indicator docs require new public helper APIs
forbidden_actions:
  - installing pkgdown-only positioning articles
  - copying design packets into installed vignettes without a contract decision
  - adding network-dependent examples
  - hiding broken examples by marking core chunks eval = FALSE
  - exporting ledgr_feature_map, ctx$features, or passed_warmup in this ticket
```

---

## LDG-1308: No-Trade And Warmup Diagnostics

**Priority:** P2  
**Effort:** 2-4 days  
**Dependencies:** LDG-1303, LDG-1304  
**Status:** Done

**Description:**
Improve the user path for successful runs with no fills or no closed trades,
especially when expected warmup warnings are suppressed. This ticket may be
documentation-only or may add a narrow diagnostic/warning improvement if the
design remains bounded.

**Tasks:**
1. Review Episode 019 and existing warmup/helper warning behavior.
2. Document a "zero trades after a successful run" checklist using `summary()`,
   `ledgr_results(..., "fills")`, `ledgr_feature_id()`, and
   `ledgr_pulse_snapshot()`.
3. Consider making `select_top_n()` empty-signal warnings include origin,
   non-missing count, and universe size.
4. Consider adding a narrow `warn_empty = FALSE` or more specific warning class
   only if it avoids broad `suppressWarnings()` without hiding never-usable
   signals.
5. If runtime changes are made, add tests for warmup, never-usable signals, and
   ordinary empty selections.
6. If runtime changes are deferred, document the deferral explicitly.

**Acceptance Criteria:**
- [x] Users have a documented checklist for diagnosing zero-trade runs.
- [x] The docs distinguish expected warmup from never-usable signals.
- [x] If warning behavior changes, tests cover origin/count details and
      suppression behavior.
- [x] If `warn_empty = FALSE` or warning-class work is deferred, the deferral is
      explicit.
- [x] Existing helper behavior remains backward compatible unless a change is
      deliberately documented.

**Test Requirements:**
- Documentation render.
- Warmup/no-trade helper tests if runtime behavior changes.
- Existing helper tests.

**Source Reference:** v0.1.7.3 spec D1, D2; triage report THEME-003 and
Episode 019.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: H
classification_reason: >
  Documentation-only implementation is Tier M. A narrow warning-class or helper
  argument addition is still bounded public API work, but requires Tier H
  review because helper semantics and user diagnostics are involved.
invariants_at_risk:
  - helper warning semantics
  - warmup interpretation
  - zero-trade result interpretation
  - backward compatibility
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_3_spec_packet/v0_1_7_3_spec.md
  - C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.7.2/2026-05-02_019_zero_trade_diagnosis/framework_feedback.md
  - inst/design/contracts.md (Strategy Contract, Result Contract)
  - R/strategy-helpers.R
  - vignettes/strategy-development.Rmd
  - vignettes/metrics-and-accounting.Rmd
tests_required:
  - documentation render
  - helper warning tests if runtime changes
  - existing helper tests
escalation_triggers:
  - diagnostics need run-store schema changes
  - helper API change could break existing calls
  - warning suppression hides real strategy errors
forbidden_actions:
  - broad suppressWarnings guidance without diagnostics
  - hiding never-usable signals as normal warmup
  - changing run success/failure semantics for zero-trade runs
  - adding persistent diagnostic tables in this ticket
```

---

## LDG-1309: v0.1.7.3 Release Gate

**Priority:** P0  
**Effort:** 1 day  
**Dependencies:** LDG-1301, LDG-1302, LDG-1303, LDG-1304, LDG-1305, LDG-1306, LDG-1307, LDG-1308  
**Status:** Planned

**Description:**
Final validation gate for v0.1.7.3.

**Tasks:**
1. Verify spec, tickets, contracts, NEWS, DESCRIPTION, README, help pages, and
   pkgdown navigation agree.
2. Bump `DESCRIPTION` to version `0.1.7.3` during the release gate, not before
   implementation tickets are complete.
3. Verify Episode 013 regression coverage and deterministic accounting fixtures.
4. Verify metric oracle tests recompute expected values independently.
5. Verify Episode 006 raw findings have been reviewed and addressed or
   explicitly deferred.
6. Verify `metrics-and-accounting` is installed before help pages link to it.
7. Verify `indicators` is the installed indicator teaching vignette and
   `ttr-indicators.Rmd` has been deleted, moved to `vignettes/articles/`, or
   deliberately retained with a documented contract exception.
8. Render README and changed vignettes/articles.
9. Run full package tests.
10. Run coverage gate if required by current release practice.
11. Run package check.
12. Build pkgdown if navigation/articles changed.
13. Run the full WSL/Ubuntu check from `release_ci_playbook.md`.
14. Confirm Windows and Ubuntu remote CI are green before tagging.
15. Confirm no open P0/P1 review findings remain.

**Acceptance Criteria:**
- [x] Full tests pass.
- [x] Independent metric oracle tests pass.
- [x] Episode 013 regression passes in all supported equity-writing modes.
- [x] `R CMD check --no-manual --no-build-vignettes` passes with 0 errors and
      0 warnings.
- [x] `DESCRIPTION` version is `0.1.7.3` before release tagging.
- [x] README and changed articles render.
- [x] pkgdown builds if navigation/articles changed.
- [x] Installed indicator documentation is consolidated around `indicators`,
      with no redundant installed `ttr-indicators` teaching path.
- [x] Local WSL/Ubuntu gate passes on the release branch.
- [ ] Remote Windows and Ubuntu CI are green on the target commit.
- [x] Contracts, NEWS, help pages, and vignettes match the implemented scope.
- [x] No accidental future-cycle API exposure exists.
- [ ] No open P0/P1 review findings remain.

**Test Requirements:**
- Full package tests.
- Independent metric oracle tests.
- R CMD check.
- README/article renders.
- pkgdown build if applicable.
- export/API inventory scan.
- local WSL/Ubuntu gate.
- remote CI verification.

**Source Reference:** v0.1.7.3 spec section 9.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: H
review_tier: H
classification_reason: >
  Release gates are Tier H by routing rule. This ticket validates correctness
  regressions, documentation, contracts, CI, package metadata, and API boundary
  before merge and tag.
invariants_at_risk:
  - release correctness
  - package build health
  - public API export boundary
  - accounting contract consistency
  - documentation accuracy
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_3_spec_packet/v0_1_7_3_spec.md
  - inst/design/ledgr_v0_1_7_3_spec_packet/v0_1_7_3_tickets.md
  - inst/design/ledgr_v0_1_7_3_spec_packet/tickets.yml
  - inst/design/contracts.md
  - inst/design/release_ci_playbook.md
  - DESCRIPTION
  - NEWS.md
  - README.Rmd
  - _pkgdown.yml
tests_required:
  - full package tests
  - independent metric oracle tests
  - R CMD check
  - README/article renders
  - pkgdown build if applicable
  - export/API inventory scan
  - local WSL/Ubuntu gate
  - remote CI verification
escalation_triggers:
  - any CI failure remains unexplained
  - metric oracle tests disagree with documented definitions
  - R CMD check warnings require scope decisions
  - documentation examples cannot run offline
forbidden_actions:
  - tagging before remote CI is green
  - ignoring R CMD check warnings
  - shipping with known future-cycle API leaks
  - accepting the gate with open P0 or P1 issues
```

---

## Out Of Scope

Do not implement these in v0.1.7.3:

- `ledgr_docs()`;
- `ledgr_sweep()`;
- `ledgr_precompute_features()`;
- `ledgr_tune()`;
- `ledgr_feature_map()`;
- `ctx$features()`;
- `passed_warmup()`;
- strategy dependency-packaging arguments;
- persistent feature-cache storage;
- short selling;
- leverage;
- broker integrations;
- paper trading;
- live trading;
- large helper zoo APIs;
- hard delete.
