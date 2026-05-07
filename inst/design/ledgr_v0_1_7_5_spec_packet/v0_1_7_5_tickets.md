# ledgr v0.1.7.5 Tickets

**Version:** 0.1.7.5
**Date:** May 7, 2026
**Total Tickets:** 8

---

## Ticket Organization

v0.1.7.5 is a hardening and discoverability cycle with four coordinated
tracks:

1. **TTR adapter parity and MACD warmup:** verify every supported TTR rule and
   resolve the MACD warmup contradiction with direct evidence.
2. **Warmup diagnostics:** surface impossible warmup and short-sample outcomes
   where users already inspect runs.
3. **Documentation workflows:** improve result inspection, low-level CSV,
   indicator examples, helper discovery, and `ctx$features()` discoverability.
4. **Release hygiene and adapter positioning:** keep contracts, NEWS, package
   help, the release playbook, and ecosystem-positioning prose aligned.

Under `inst/design/model_routing.md`, ticket generation, release scoping,
contract changes, TTR indicator work, persistence-sensitive examples, and
release gates require Tier H classification or review. Documentation-only
implementation can be Tier M when it does not alter executable behavior, but
contract-teaching documentation still requires Tier H review.

### Dependency DAG

```text
LDG-1501 -> LDG-1502 -> LDG-1507 -> LDG-1508
LDG-1501 -> LDG-1503 -> LDG-1506 -> LDG-1507
LDG-1501 -> LDG-1504 -------------> LDG-1507
LDG-1501 -> LDG-1505 -------------> LDG-1507
LDG-1502 -> LDG-1506
LDG-1504 -> LDG-1506
LDG-1505 -> LDG-1506
LDG-1507 -> LDG-1508
```

`LDG-1508` is the v0.1.7.5 release gate.

### Priority Levels

- **P0 (Blocker):** Required for release correctness or scope coherence.
- **P1 (Critical):** Required for the v0.1.7.5 user story to work.
- **P2 (Important):** Required for discoverability or documentation quality.
- **P3 (Optional):** Useful, but not a release blocker.

---

## LDG-1501: Scope, Evidence, And Contract Baseline

**Priority:** P0
**Effort:** 1 day
**Dependencies:** None
**Status:** Done

**Description:**
Finalize the v0.1.7.5 release boundary before implementation begins. Confirm
which auditr findings are in ledgr scope, record the adapter-positioning
direction, scaffold NEWS/contracts, and make sure every promoted issue is tied
to raw evidence rather than generated triage alone.

**Tasks:**
1. Review `v0_1_7_5_spec.md`, `curated_ledgr_issue_subset.md`,
   `ledgr_triage_report.md`, and `cycle_retrospective.md`.
2. Classify promoted findings as confirmed ledgr bug, documentation mismatch,
   expected user error with weak messaging, auditr issue, or no longer
   reproducible.
3. Add a draft `NEWS.md` v0.1.7.5 section with planned bullets.
4. Update `contracts.md` scaffolding for TTR parity, warmup diagnostics, and
   adapter-positioning language if needed.
5. Confirm `{talib}` adapter implementation is out of scope unless explicitly
   promoted to a separate ticket.
6. Confirm release-playbook post-mortem additions are carried on the branch.
7. Verify ticket markdown and YAML agree on IDs, dependencies, classifications,
   and forbidden actions.

**Acceptance Criteria:**
- [x] v0.1.7.5 spec, curated subset, and generated reports agree on release
      scope or explicitly document disagreements.
- [x] Every promoted auditr issue has a raw-evidence verification requirement.
- [x] `NEWS.md` has a draft v0.1.7.5 section.
- [x] `contracts.md` has a clear location for changed TTR/warmup/adapter
      contracts.
- [x] `{talib}` adapter implementation is explicitly out of scope unless
      separately promoted.
- [x] Ticket markdown and YAML classifications agree.

**Test Requirements:**
- Documentation consistency scan.
- Spec/ticket filename scan.
- NEWS/scope scan.

**Source Reference:** v0.1.7.5 spec sections 1, 2, 3, 8.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: H
review_tier: H
classification_reason: >
  Version scoping, evidence classification, contract scaffolding, and ticket
  generation are Tier H by model_routing.md.
invariants_at_risk:
  - release scope
  - evidence quality
  - public adapter boundary
  - documentation contract
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_5_spec_packet/v0_1_7_5_spec.md
  - inst/design/ledgr_v0_1_7_5_spec_packet/curated_ledgr_issue_subset.md
  - inst/design/ledgr_v0_1_7_5_spec_packet/ledgr_triage_report.md
  - inst/design/ledgr_v0_1_7_5_spec_packet/cycle_retrospective.md
  - inst/design/contracts.md
  - inst/design/release_ci_playbook.md
  - NEWS.md
tests_required:
  - documentation consistency scan
  - spec/ticket filename scan
  - NEWS/scope scan
escalation_triggers:
  - raw evidence contradicts curated scope
  - TTR parity requires broader indicator redesign
  - talib adapter is promoted into current release scope
forbidden_actions:
  - implementing code changes
  - changing execution behavior
  - adding talib adapter APIs
  - weakening release gates
```

---

## LDG-1502: TTR Adapter Parity And MACD Warmup Investigation

**Priority:** P0
**Effort:** 2-4 days
**Dependencies:** LDG-1501
**Status:** Done

**Description:**
Build a systematic parity matrix across every supported `ledgr_ind_ttr()` rule
and every documented multi-output column. Use direct TTR evidence to decide
whether the reported MACD `output = "macd"` warmup issue is real and isolated.

**Tasks:**
1. Build a table-driven parity matrix from `ledgr_ttr_warmup_rules()`.
2. Cover every documented multi-output column for ATR, BBands, MACD, aroon,
   and DonchianChannel.
3. Define one test helper that normalizes direct TTR output into an aligned
   unnamed numeric vector.
4. For ledgr-derived MACD `histogram`, compare to direct `macd - signal`.
5. Compare direct TTR first-valid row, inferred `requires_bars`, ledgr
   precomputed first-valid row, deterministic ID, and output values.
6. Add focused MACD boundary tests around `nSlow`, `nSlow + nSig - 1`,
   `percent = TRUE/FALSE`, and `macd`/`signal`/`histogram`.
7. Test short-sample behavior at `requires_bars - 1`, `requires_bars`, and
   `requires_bars + 1` for MACD and representative non-MACD cases.
8. If direct evidence proves the MACD rule is wrong, update implementation,
   docs, rendered companions, and expected outputs.
9. If the rule is correct, document why the auditr failure did not reproduce
   and add a regression for the actual failing path if found.

**Acceptance Criteria:**
- [x] Every `ledgr_ttr_warmup_rules()` row has at least one parity case.
- [x] Every documented multi-output column has a parity case.
- [x] Direct TTR output and ledgr output match after defined normalization.
- [x] MACD `histogram` parity uses direct `macd - signal`.
- [x] MACD boundary behavior is decided by direct TTR output.
- [x] Short-sample supported TTR indicators return aligned warmup `NA` rather
      than leaking low-level TTR errors.
- [x] TTR version and case metadata are visible in failure context.
- [x] `indicators.Rmd`, checked-in `indicators.md`, and Rd docs match any
      changed MACD contract.

**Implementation Notes:**
- Direct TTR evidence confirms the MACD report: `TTR::MACD()` cannot be called
  successfully at pulse lengths 26-33 because it computes the signal EMA
  internally even when only `output = "macd"` is selected.
- `ledgr_ind_ttr("MACD", ...)` now infers `requires_bars = nSlow + nSig - 1`
  for `macd`, `signal`, and ledgr-derived `histogram` outputs.
- The parity matrix covers all 18 warmup-rule functions and every documented
  multi-output column for ATR, BBands, MACD, aroon, and DonchianChannel.
- Non-MACD TTR indicators matched direct TTR output after normalization; no
  additional warmup-rule defects were found.
- Feature precomputation now returns aligned warmup `NA_real_` values when a
  valid supported indicator receives fewer rows than `stable_after`, avoiding
  low-level TTR short-sample errors during ordinary warmup.

**Test Requirements:**
- TTR parity matrix tests.
- MACD boundary tests.
- Short-sample TTR tests.
- Existing indicator/TTR tests.
- Documentation render if docs change.

**Source Reference:** v0.1.7.5 spec sections R2, R3, R4, A1-A4.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  TTR indicators are an explicit hard-context area in model_routing.md. This
  ticket may change adapter warmup contracts, feature IDs in docs, and feature
  precomputation behavior.
invariants_at_risk:
  - TTR adapter contract
  - feature warmup semantics
  - feature ID documentation
  - series_fn precomputation
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_5_spec_packet/v0_1_7_5_spec.md
  - inst/design/ledgr_v0_1_7_5_spec_packet/curated_ledgr_issue_subset.md
  - inst/design/contracts.md (Context Contract)
  - R/indicator-ttr.R
  - R/indicator.R
  - tests/testthat/test-indicator-ttr.R
  - vignettes/indicators.Rmd
  - man/ledgr_ind_ttr.Rd
  - man/ledgr_ttr_warmup_rules.Rd
tests_required:
  - TTR parity matrix tests
  - MACD boundary tests
  - short-sample TTR tests
  - existing indicator/TTR tests
escalation_triggers:
  - direct TTR output differs across installed TTR versions
  - parity requires changing feature-engine validation
  - supported TTR functions require per-function special cases beyond warmup
  - short-sample behavior cannot be normalized without masking real errors
forbidden_actions:
  - assuming the auditr MACD claim without direct evidence
  - changing fill or strategy execution semantics
  - adding unsupported TTR functions without warmup rules
  - changing feature IDs for documentation convenience
```

---

## LDG-1503: Zero-Trade Warmup Diagnostics

**Priority:** P1
**Effort:** 2-4 days
**Dependencies:** LDG-1501
**Status:** Planned

**Description:**
Surface a user-facing diagnostic when a registered feature is all warmup `NA`
for an instrument because the sample is shorter than the feature contract.
Prefer `summary(bt)` as the primary surface.

**Tasks:**
1. Review the raw short-sample auditr episode before implementation.
2. Determine available bars per instrument for registered features without
   string parsing.
3. Detect all-warmup feature output per instrument.
4. Add a compact diagnostic note to `summary(bt)` that names feature ID,
   instrument ID, required bars, and available bars.
5. Use `ledgr_*` class conventions for any warning/note object that needs
   programmatic handling.
6. Ensure diagnostics do not alter fills, ledger events, equity, metrics, run
   identity, or persistent tables.
7. Document how to interpret the diagnostic in warmup troubleshooting docs.
8. Document the three warmup-adjacent failure modes separately: normal feature
   warmup where a known feature is `NA` and later recovers, impossible warmup
   where all values remain `NA` because the instrument never reaches the
   feature contract, and current-bar absence where no pulse is constructed and
   the strategy is not called.

**Acceptance Criteria:**
- [ ] A short-sample `sma_20` on 10 bars produces a visible warmup diagnostic.
- [ ] Diagnostic includes feature ID, instrument ID, required bars, and
      available bars.
- [ ] Zero-trade runs remain valid completed runs.
- [ ] Diagnostics do not affect result tables, metrics, or config/run identity.
- [ ] Multiple instruments with different sample starts are handled.
- [ ] Docs connect the diagnostic to `ledgr_feature_contracts()` and warmup
      troubleshooting.
- [ ] Docs include a named three-way distinction between ordinary warmup,
      impossible warmup, and current-bar absence/pulse construction failure.

**Test Requirements:**
- Short-sample impossible-warmup run test.
- `summary(bt)` diagnostic test.
- Multi-instrument uneven-sample test.
- Existing summary/result tests.
- Documentation contract tests if docs change.

**Source Reference:** v0.1.7.5 spec sections R5, B1-B3.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  This ticket touches run diagnostics and summary behavior after feature
  computation. It must preserve execution, result, metric, and identity
  semantics, so Tier H implementation and review are required.
invariants_at_risk:
  - run result semantics
  - feature warmup semantics
  - summary output contract
  - run identity
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_5_spec_packet/v0_1_7_5_spec.md
  - inst/design/ledgr_v0_1_7_5_spec_packet/curated_ledgr_issue_subset.md
  - inst/design/contracts.md (Context Contract, Result Contract)
  - R/backtest-runner.R
  - R/backtest.R
  - R/feature-inspection.R
  - R/features-engine.R
  - tests/testthat/test-backtest-s3.R
  - tests/testthat/test-results-wrapper.R
  - tests/testthat/test-feature-inspection.R
tests_required:
  - short-sample impossible-warmup run test
  - summary diagnostic test
  - multi-instrument sample coverage test
  - existing summary/result tests
escalation_triggers:
  - diagnostic requires changing persistent schema
  - diagnostic affects metrics or result rows
  - available-bar accounting cannot be derived from registered feature metadata
  - warning noise appears in normal warmup cases
forbidden_actions:
  - treating zero-trade runs as failed runs
  - changing fill timing
  - changing ledger/equity/metric computation
  - string-parsing feature IDs when metadata is available
```

---

## LDG-1504: Result Inspection Lifecycle Documentation

**Priority:** P2
**Effort:** 1-2 days
**Dependencies:** LDG-1501
**Status:** Planned

**Description:**
Add one compact result-inspection example that opens and closes a position, then
shows equity, fills, closed trades, ledger rows, `summary(bt)`, and metric
interpretation side by side.

**Tasks:**
1. Review raw result-inspection auditr episodes.
2. Add a deterministic closed-trade example to `metrics-and-accounting`.
3. Show `ledgr_results()` for `equity`, `fills`, `trades`, and `ledger`.
4. Explain why open-only fills do not produce closed trade rows.
5. State that `what = "metrics"` is not a supported result table.
6. Cross-link from `?ledgr_results`, `?summary.ledgr_backtest`, and
   `?ledgr_compare_runs`.
7. Render checked-in vignette companions.

**Acceptance Criteria:**
- [ ] Example produces at least one fill row and one closed trade row.
- [ ] Docs distinguish fills, trades, ledger, equity, and summary metrics.
- [ ] Docs state `ledgr_results(..., what = "metrics")` is unsupported.
- [ ] Result-related help pages point to the example.
- [ ] Rendered docs are in sync.

**Test Requirements:**
- Documentation render.
- Documentation contract scans for result lifecycle language.
- Existing result/summary tests if examples are executed.

**Source Reference:** v0.1.7.5 spec sections R6, C1.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: H
classification_reason: >
  Documentation-focused work with executable examples over public result APIs.
  Tier H review is required because it teaches result semantics and metric
  interpretation.
invariants_at_risk:
  - result documentation contract
  - metric interpretation
  - first-contact result inspection
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_5_spec_packet/v0_1_7_5_spec.md
  - inst/design/contracts.md (Result Contract, Documentation Contract)
  - R/backtest.R
  - R/result-table.R
  - R/run-store.R
  - vignettes/metrics-and-accounting.Rmd
  - tests/testthat/test-documentation-contracts.R
tests_required:
  - documentation render
  - documentation contract scans
  - existing result/summary tests if examples execute
escalation_triggers:
  - example cannot produce a closed trade without changing execution behavior
  - docs reveal mismatch in metric formulas
  - ledgr_results needs new result table types
forbidden_actions:
  - adding what = "metrics"
  - changing metric definitions
  - changing result table schemas for documentation convenience
```

---

## LDG-1505: Low-Level CSV Snapshot Bridge Example

**Priority:** P2
**Effort:** 1-3 days
**Dependencies:** LDG-1501
**Status:** Planned

**Description:**
Add one complete low-level CSV workflow example that bridges from
`ledgr_snapshot_create()` through CSV import, sealing, verified loading,
metadata inspection, experiment construction, and `ledgr_run()`.

**Tasks:**
1. Review the raw low-level CSV auditr episode.
2. Add a compact end-to-end example in `experiment-store` or snapshot help.
3. Show `ledgr_snapshot_create()` -> `ledgr_snapshot_import_bars_csv()` ->
   `ledgr_snapshot_seal()` -> `ledgr_snapshot_load(verify = TRUE)`.
4. Before writing the example, decide whether `ledgr_snapshot_info()` should
   expose parsed `start_date` and `end_date` as top-level columns alongside
   `bar_count` and `instrument_count`. If yes, implement the scoped API change;
   if no, record the reason and show a compact `meta_json` parsing pattern.
5. Show `ledgr_snapshot_info()` and explain `meta_json` as envelope metadata
   without hiding the naming boundary between `n_bars`/`n_instruments` in
   metadata and `bar_count`/`instrument_count` in the info surface.
6. Show the loaded snapshot passed to `ledgr_experiment()` and `ledgr_run()`.
7. Cross-link relevant snapshot help pages to the full bridge.
8. Add a regression if the example reveals workflow drift.

**Acceptance Criteria:**
- [ ] One documented example shows the full low-level CSV bridge.
- [ ] Example explains seal metadata versus artifact hash.
- [ ] Example uses `ledgr_snapshot_load(verify = TRUE)` before experiment use.
- [ ] The `ledgr_snapshot_info()` metadata naming gap has an explicit recorded
      decision, with a code change or documented parsing pattern as appropriate.
- [ ] Relevant help pages link to the bridge.
- [ ] Example runs or has a clearly justified non-executed chunk with tested
      equivalent coverage.

**Test Requirements:**
- Documentation render.
- CSV snapshot create/import/seal/load/run test if not already covered.
- Snapshot help-page documentation scans.
- Existing snapshot adapter/load tests.

**Source Reference:** v0.1.7.5 spec sections R7, C2.

**Classification:**
```yaml
risk_level: high
implementation_tier: M
review_tier: H
classification_reason: >
  Primarily documentation, but it teaches snapshot creation, sealing, loading,
  metadata, and run workflow. Snapshot semantics are hard escalation areas, so
  review is Tier H and implementation must stop if code behavior changes.
invariants_at_risk:
  - snapshot sealing
  - snapshot load verification
  - snapshot metadata interpretation
  - canonical experiment workflow
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_5_spec_packet/v0_1_7_5_spec.md
  - inst/design/contracts.md (Snapshot Contract, Persistence Contract, Documentation Contract)
  - R/snapshot.R
  - R/snapshot_adapters.R
  - R/snapshots-seal.R
  - R/snapshots-list.R
  - vignettes/experiment-store.Rmd
  - tests/testthat/test-snapshot-adapters.R
  - tests/testthat/test-snapshots-load.R
tests_required:
  - documentation render
  - CSV snapshot create/import/seal/load/run test if needed
  - snapshot help documentation scans
  - existing snapshot adapter/load tests
escalation_triggers:
  - example requires changing snapshot metadata behavior
  - verified load path fails
  - docs imply metadata is part of snapshot hash
  - low-level workflow bypasses canonical experiment path
forbidden_actions:
  - bypassing snapshot sealing
  - weakening hash verification
  - mutating sealed snapshot data
  - documenting manual meta_json edits as normal workflow
```

---

## LDG-1506: Indicator, Helper, And Feature-Map Discoverability

**Priority:** P1
**Effort:** 3-5 days
**Dependencies:** LDG-1502, LDG-1503, LDG-1504, LDG-1505
**Status:** Planned

**Description:**
Improve the high-friction documentation surfaces identified by both auditr
runs: indicators, strategy helpers, feature maps, and `ctx$features()`.

**Tasks:**
1. Extend indicator docs with SMA crossover semantics.
2. Add RSI mean-reversion with experiment usage.
3. Show mixed built-in and TTR-backed indicators in one feature map or feature
   list.
4. Print expected feature IDs for TTR examples, including MACD.
5. Improve alias-versus-feature-ID language.
6. Add warmup troubleshooting that uses `ledgr_feature_contracts()` and the new
   diagnostic from LDG-1503.
7. Add or strengthen helper-page examples and warning/error class references.
8. Make `ctx$features()` discoverable from `?ledgr_feature_map`, with
   `?passed_warmup` as a secondary cross-link.
9. Review starter navigation and ensure `examples/README.md` is not presented
   as a first runnable path if it remains a placeholder.
10. Ensure every help-page Articles section that links to an installed vignette
    shows both the `vignette("name", package = "ledgr")` discovery call and the
    `system.file("doc", "name.html", package = "ledgr")` installed-file path.
11. Add a compact parameterized-feature registration example showing that all
    swept feature values, such as `ret_5`, `ret_10`, and `ret_20`, must be
    registered before `ledgr_run()` rather than created lazily inside strategy
    logic from `params$lookback`.
12. Render checked-in vignette companions.

**Acceptance Criteria:**
- [ ] Indicators docs cover SMA crossover, RSI mean-reversion, mixed
      built-in/TTR usage, explicit feature IDs, and alias-vs-feature-ID
      language.
- [ ] Warmup troubleshooting links feature contracts, available bars, and
      zero-trade diagnostics.
- [ ] Helper docs name warning/error classes where relevant.
- [ ] `ctx$features()` is reachable from `?ledgr_feature_map` and shown in a
      tiny strategy-body snippet.
- [ ] Starter navigation points to runnable examples, not placeholder artifacts.
- [ ] Installed-vignette Articles sections include both `vignette()` and
      `system.file("doc", ..., package = "ledgr")` forms for headless users.
- [ ] Helper and indicator docs explain pre-run registration of all swept
      feature parameter values, with a compact multi-lookback example.
- [ ] Rendered docs are in sync.

**Test Requirements:**
- Documentation render.
- Documentation contract scans.
- Rd scans for article links and `ctx$features()` snippet.
- Existing indicator/helper documentation tests.

**Source Reference:** v0.1.7.5 spec sections R8, R9, C3-C5.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: H
classification_reason: >
  Documentation implementation is bounded, but it teaches feature contracts,
  helper pipelines, ctx$features(), and TTR behavior. Tier H review is required
  for contract accuracy and discoverability.
invariants_at_risk:
  - indicator teaching flow
  - feature-map alias semantics
  - helper composition documentation
  - ctx$features discoverability
  - installed documentation spine
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_5_spec_packet/v0_1_7_5_spec.md
  - inst/design/contracts.md (Strategy Contract, Context Contract, Documentation Contract)
  - R/feature-map.R
  - R/strategy-helpers.R
  - R/indicator-ttr.R
  - vignettes/indicators.Rmd
  - vignettes/strategy-development.Rmd
  - README.Rmd
  - _pkgdown.yml
  - tests/testthat/test-documentation-contracts.R
tests_required:
  - documentation render
  - documentation contract scans
  - Rd scans for links and ctx$features snippet
  - existing indicator/helper documentation tests
escalation_triggers:
  - docs require new helper APIs
  - examples reveal unresolved TTR parity defect
  - indicators article becomes a duplicate strategy tutorial
  - ctx$features docs imply direct raw table access is preferred
forbidden_actions:
  - adding ctx$features_wide
  - adding feature roles/selectors/prep/bake
  - hiding explicit feature ID contract
  - presenting examples/README.md as runnable if it is not
```

---

## LDG-1507: Contracts, NEWS, Playbook, And Adapter Positioning

**Priority:** P1
**Effort:** 1-2 days
**Dependencies:** LDG-1502, LDG-1503, LDG-1504, LDG-1505, LDG-1506
**Status:** Planned

**Description:**
Align contracts, NEWS, package help, release playbook, pkgdown/reference links,
and user-facing positioning with the implemented v0.1.7.5 scope.

**Tasks:**
1. Update `contracts.md` for any changed TTR warmup behavior and the new
   warmup diagnostic surface.
2. Update `NEWS.md` from planned bullets to delivered v0.1.7.5 bullets.
3. Add adapter-positioning language to README or a positioning article.
4. Ensure package help and function help article links match the updated docs.
5. Ensure `release_ci_playbook.md` includes remote-log-first debugging,
   DuckDB constraint-probe rollback, and stop-and-review rules.
6. Update `_pkgdown.yml` if reference placement or navigation changes.
7. Add or update documentation contract tests.

**Acceptance Criteria:**
- [ ] Contracts match shipped TTR, warmup diagnostic, and documentation
      behavior.
- [ ] NEWS accurately summarizes delivered v0.1.7.5 scope.
- [ ] Adapter-positioning language is present in user-facing docs.
- [ ] Release playbook includes the v0.1.7.4 post-mortem guardrails.
- [ ] Package help, function help, and pkgdown navigation remain coherent.
- [ ] Documentation contract tests cover the new release-critical doc claims.

**Test Requirements:**
- Documentation contract tests.
- NEWS/scope scan.
- Rd article-link scans.
- Pkgdown build if navigation/reference changes.

**Source Reference:** v0.1.7.5 spec sections R10, R11, D1-D3.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: H
classification_reason: >
  Mostly documentation, metadata, and contract alignment, but it modifies
  contracts and release-facing documentation. Tier H review is required.
invariants_at_risk:
  - documentation contract
  - release notes accuracy
  - release-gate process
  - public ecosystem positioning
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_5_spec_packet/v0_1_7_5_spec.md
  - inst/design/contracts.md
  - inst/design/release_ci_playbook.md
  - NEWS.md
  - README.Rmd
  - R/ledgr-package.R
  - _pkgdown.yml
  - tests/testthat/test-documentation-contracts.R
tests_required:
  - documentation contract tests
  - NEWS/scope scan
  - Rd article-link scans
  - pkgdown build if navigation/reference changes
escalation_triggers:
  - contracts need behavior not implemented by prior tickets
  - adapter positioning implies talib implementation is shipped
  - playbook guidance conflicts with current CI workflow
forbidden_actions:
  - claiming talib adapter support
  - blessing unimplemented behavior in contracts
  - weakening release-gate checks
  - moving pkgdown-only positioning articles into installed vignettes
```

---

## LDG-1508: v0.1.7.5 Release Gate

**Priority:** P0
**Effort:** 1 day
**Dependencies:** LDG-1501, LDG-1502, LDG-1503, LDG-1504, LDG-1505, LDG-1506, LDG-1507
**Status:** Planned

**Description:**
Final validation gate for v0.1.7.5. Follow
`inst/design/release_ci_playbook.md`; remote branch, main, and tag CI are
separate evidence.

**Tasks:**
1. Verify spec, tickets, contracts, NEWS, DESCRIPTION, README, help pages,
   vignettes, and pkgdown agree.
2. Bump `DESCRIPTION` to version `0.1.7.5` during the release gate.
3. Verify TTR parity matrix and MACD boundary tests.
4. Verify short-sample TTR behavior tests.
5. Verify zero-trade warmup diagnostic tests.
6. Verify result lifecycle and low-level CSV documentation/examples.
7. Verify indicator/helper/feature-map discoverability docs.
8. Verify adapter-positioning language and playbook additions.
9. Render README and changed vignettes/articles.
10. Run full package tests.
11. Run coverage gate.
12. Run package check.
13. Build pkgdown if navigation/reference/articles changed.
14. Run local WSL/Ubuntu gate for executable R, DuckDB, docs, or CI-sensitive
    changes.
15. Push branch and verify remote branch CI is green.
16. Merge to `main` only after branch CI is green.
17. Verify `main` CI and pkgdown are green.
18. Tag only after `main` is green.
19. Verify tag-triggered CI is green.
20. Confirm no open P0/P1 review findings remain.

**Acceptance Criteria:**
- [ ] Full tests pass.
- [ ] TTR parity and MACD boundary tests pass.
- [ ] Warmup diagnostic tests pass.
- [ ] Result lifecycle and CSV bridge docs are present and rendered.
- [ ] Documentation contract tests pass.
- [ ] `R CMD check --no-manual --no-build-vignettes` passes with 0 errors and
      0 warnings.
- [ ] `DESCRIPTION` version is `0.1.7.5` before release tagging.
- [ ] README and changed articles render.
- [ ] Pkgdown builds if navigation/reference/articles changed.
- [ ] Local WSL/Ubuntu gate passes where required.
- [ ] Remote branch CI is green on the target commit.
- [ ] `main` CI is green.
- [ ] Tag-triggered CI is green.
- [ ] No open P0/P1 review findings remain.

**Test Requirements:**
- Full package tests.
- TTR parity suite.
- Warmup diagnostic tests.
- Documentation contract tests.
- R CMD check.
- Coverage gate.
- README/article renders.
- Pkgdown build if applicable.
- Local WSL/Ubuntu gate.
- Remote CI verification.

**Source Reference:** v0.1.7.5 spec section 9.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: H
review_tier: H
classification_reason: >
  Release gates are Tier H by routing rule. This ticket validates executable
  behavior, documentation, package metadata, CI, and release tagging readiness.
invariants_at_risk:
  - release correctness
  - TTR adapter contract
  - warmup diagnostics
  - documentation accuracy
  - CI/release process
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_5_spec_packet/v0_1_7_5_spec.md
  - inst/design/ledgr_v0_1_7_5_spec_packet/v0_1_7_5_tickets.md
  - inst/design/ledgr_v0_1_7_5_spec_packet/tickets.yml
  - inst/design/contracts.md
  - inst/design/release_ci_playbook.md
  - DESCRIPTION
  - NEWS.md
  - README.Rmd
  - _pkgdown.yml
tests_required:
  - full package tests
  - TTR parity suite
  - warmup diagnostic tests
  - documentation contract tests
  - R CMD check
  - coverage gate
  - README/article renders
  - pkgdown build if applicable
  - local WSL/Ubuntu gate
  - remote CI verification
escalation_triggers:
  - any CI failure remains unexplained
  - TTR parity is version-dependent without documentation
  - R CMD check warnings require scope decisions
  - documentation examples cannot run offline
  - remote branch/main/tag evidence disagrees
forbidden_actions:
  - tagging before remote CI is green
  - ignoring R CMD check warnings
  - weakening Ubuntu or coverage gates to pass release
  - accepting the gate with open P0 or P1 issues
```

---

## Out Of Scope

Do not implement these in v0.1.7.5:

- `ledgr_sweep()`;
- `ledgr_precompute_features()`;
- `ledgr_tune()`;
- `{talib}` adapter support unless explicitly promoted to a new ticket;
- visualization APIs;
- machine-learning training-frame APIs;
- feature roles or selectors;
- recipes-style `prep()` / `bake()`;
- `ctx$features_wide()`;
- strategy dependency-packaging arguments;
- persistent feature-cache storage;
- short selling;
- leverage;
- broker integrations;
- paper trading;
- live trading;
- hard delete;
- ledgr package APIs solely to work around auditr harness issues.
