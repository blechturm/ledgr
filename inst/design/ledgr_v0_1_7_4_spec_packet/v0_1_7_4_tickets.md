# ledgr v0.1.7.4 Tickets

**Version:** 0.1.7.4  
**Date:** May 3, 2026  
**Total Tickets:** 9  

---

## Ticket Organization

v0.1.7.4 is an authoring-UX and auditr-cleanup cycle with four coordinated
tracks:

1. **Feature-map authoring UX:** add `ledgr_feature_map()`, `ctx$features()`,
   and `passed_warmup()` without changing the execution model.
2. **Auditr documentation fixes:** remove hidden helper usage, improve helper
   discovery, strengthen feature-ID/warmup/TTR docs, and add external-review
   framing.
3. **CSV snapshot import investigation:** verify or fix the documented CSV
   import/seal/run workflow.
4. **Release hygiene:** keep installed docs, contracts, NEWS, pkgdown, and CI
   aligned with the shipped scope.

Under `inst/design/model_routing.md`, ticket generation, public API additions,
context accessors, run identity/config hashing, snapshot persistence, and
release gates are Tier H. Documentation-only implementation may be Tier M, but
contract-teaching docs require Tier H review.

### Dependency DAG

```text
LDG-1401 -> LDG-1402 -> LDG-1403 -> LDG-1404 -> LDG-1408 -> LDG-1409
LDG-1401 -------------------------> LDG-1405 -------------> LDG-1408
LDG-1401 -------------------------> LDG-1406 -------------> LDG-1408
LDG-1401 -------------------------> LDG-1407 -------------> LDG-1409
LDG-1402 -------------------------> LDG-1408
LDG-1403 -------------------------> LDG-1408
LDG-1405 -------------------------> LDG-1409
LDG-1406 -------------------------> LDG-1409
LDG-1408 -------------------------> LDG-1409
```

`LDG-1409` is the v0.1.7.4 release gate.

### Priority Levels

- **P0 (Blocker):** Required for release coherence or correctness risk.
- **P1 (Critical):** Required for the v0.1.7.4 user story to work.
- **P2 (Important):** Required for discoverability or documentation quality.
- **P3 (Optional):** Useful, but not a release blocker.

---

## LDG-1401: Scope, Metadata, And Contract Baseline

**Priority:** P0  
**Effort:** 1 day  
**Dependencies:** None  
**Status:** Done

**Description:**
Finalize the v0.1.7.4 release boundary before implementation begins. This
ticket confirms that feature-map authoring UX is in scope, records the auditr
findings, and prepares contracts/NEWS scaffolding without implementing the API.

**Tasks:**
1. Review `v0_1_7_4_spec.md`, `ledgr_triage_report.md`,
   `cycle_retrospective.md`, and `ledgr_feature_map_ux.md` for consistency.
2. Add a draft `NEWS.md` v0.1.7.4 section with planned bullets for feature maps,
   auditr documentation fixes, CSV workflow verification, and installed-doc
   hygiene.
3. Update `contracts.md` scaffolding for feature maps as authoring UX, not
   execution semantics.
4. Confirm `features = list(...)` compatibility remains a hard requirement.
5. Confirm `ledgr_docs()`, sweep/tune, feature roles/selectors, and
   `ctx$features_wide()` are out of scope.
6. Confirm stale `inst/doc/ttr-indicators.*` artifacts are in scope for cleanup.
7. Verify ticket IDs, dependencies, and model classifications are internally
   consistent.

**Acceptance Criteria:**
- [x] v0.1.7.4 spec, roadmap, and feature-map design agree on scope.
- [x] `NEWS.md` has a draft v0.1.7.4 section.
- [x] `contracts.md` has a clear location for feature-map contracts.
- [x] `features = list(...)` compatibility is explicitly preserved.
- [x] Non-goals are explicit: no sweep/tune, no new execution path, no roles,
      no selectors, no `ctx$features_wide()`, no `ledgr_docs()`.
- [x] Ticket markdown and YAML classifications agree.

**Test Requirements:**
- Documentation consistency scan.
- Export/API inventory scan.
- Spec/ticket filename scan.

**Source Reference:** v0.1.7.4 spec sections 1, 2, 8.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: H
review_tier: H
classification_reason: >
  Version scoping, public API boundary decisions, contract scaffolding, and
  ticket classification are Tier H by routing rule.
invariants_at_risk:
  - release scope
  - public API boundary
  - feature-map contract placement
  - documentation contract
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_4_spec_packet/v0_1_7_4_spec.md
  - inst/design/ledgr_v0_1_7_4_spec_packet/ledgr_triage_report.md
  - inst/design/ledgr_v0_1_7_4_spec_packet/cycle_retrospective.md
  - inst/design/ledgr_feature_map_ux.md
  - inst/design/contracts.md
  - inst/design/release_ci_playbook.md
  - NEWS.md
tests_required:
  - documentation consistency scan
  - export/API inventory scan
  - spec/ticket filename scan
escalation_triggers:
  - feature maps require execution-path changes
  - config_hash parity cannot be specified without identity changes
  - CSV workflow issue proves to be a snapshot bug requiring broader scope
forbidden_actions:
  - implementing ledgr_feature_map
  - changing execution behavior
  - adding sweep/tune APIs
  - adding ledgr_docs
```

---

## LDG-1402: Feature Map Type, Experiment Registration, And Identity

**Priority:** P1  
**Effort:** 3-5 days  
**Dependencies:** LDG-1401  
**Status:** Planned

**Description:**
Implement `ledgr_feature_map()` and make `ledgr_experiment(features = ...)`
accept feature maps while preserving plain list registration and
feature-related `config_hash` identity for equivalent indicator definitions.

**Tasks:**
1. Implement a typed `ledgr_feature_map(...)` object carrying aliases,
   indicator objects, and resolved feature IDs.
2. Validate aliases: named, non-empty, non-`NA`, unique, and syntactically valid
   R names.
3. Validate mapped values are ledgr indicator objects.
4. Reject duplicate resolved feature IDs unless a later design deliberately
   supports duplicate aliases.
5. Add compact print behavior for feature maps.
6. Teach `ledgr_experiment(features = ...)` to accept feature maps by extracting
   the underlying indicator definitions.
7. Preserve `features = list(...)` behavior unchanged.
8. Ensure experiments copy feature definitions/resolved IDs at construction
   time so caller rebinding or mutation cannot alter the experiment.
9. Ensure equivalent feature maps and plain lists produce the same
   feature-related `config_hash` for equivalent indicator definitions.

**Acceptance Criteria:**
- [ ] Valid named indicators create a `ledgr_feature_map`.
- [ ] Invalid aliases and invalid mapped values fail with classed errors.
- [ ] Duplicate resolved feature IDs fail before feature computation.
- [ ] `ledgr_experiment(features = feature_map)` registers the same features as
      the equivalent plain list.
- [ ] Existing `ledgr_experiment(features = list(...))` tests still pass.
- [ ] Mutating/rebinding the caller's map after experiment construction does
      not alter the experiment's feature set.
- [ ] Equivalent feature map and plain list registrations produce the same
      feature-related `config_hash`.

**Test Requirements:**
- Feature-map constructor tests.
- Experiment registration tests for list and feature map inputs.
- Duplicate feature ID tests.
- Config-hash parity tests.
- Copy-on-use immutability tests.
- Existing experiment/config hash tests.

**Source Reference:** v0.1.7.4 spec sections R1, R2, R3, R6, R7, A1, A2.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  This ticket adds exported public API and touches experiment feature
  registration and config_hash identity. Public API and identity are hard
  escalation areas, so Tier H implementation and review are required.
invariants_at_risk:
  - public API compatibility
  - experiment feature registration
  - config_hash identity
  - feature ID uniqueness
  - copy-on-use immutability
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_4_spec_packet/v0_1_7_4_spec.md
  - inst/design/ledgr_feature_map_ux.md
  - inst/design/contracts.md (Strategy Contract, Context Contract, Canonical JSON Contract)
  - R/experiment.R
  - R/indicator.R
  - R/features-engine.R
  - R/config-hash.R
  - R/config-canonical-json.R
  - tests/testthat/test-experiment.R
  - tests/testthat/test-backtest-wrapper.R
tests_required:
  - feature-map constructor tests
  - experiment registration tests
  - duplicate feature ID tests
  - config-hash parity tests
  - immutability tests
escalation_triggers:
  - aliases appear to need run identity semantics
  - feature maps require changes to canonical JSON format
  - plain list compatibility breaks
  - duplicate feature IDs cannot be caught before runtime
forbidden_actions:
  - changing feature ID generation
  - making aliases silently part of config_hash identity
  - breaking features = list(...)
  - adding roles, selectors, prep, bake, or wide feature tables
```

---

## LDG-1403: Pulse Feature Bundles And Warmup Predicate

**Priority:** P1  
**Effort:** 3-5 days  
**Dependencies:** LDG-1402  
**Status:** Planned

**Description:**
Add `ctx$features(id, features)` and exported `passed_warmup()` so strategies
can read all mapped feature values for one instrument at one pulse and guard
signal logic without repeated `!is.na()` checks.

**Tasks:**
1. Add `ctx$features(id, features)` to pulse contexts.
2. Return a named numeric vector keyed by feature-map aliases.
3. Preserve warmup `NA` values for known registered features.
4. Fail loudly for invalid instrument IDs.
5. Fail loudly when a feature map asks for an unregistered feature ID, listing
   available feature IDs.
6. Ensure `ctx$features()` exposes no data unavailable at `ctx$ts_utc`.
7. Implement and export `passed_warmup(x)`.
8. Make `passed_warmup(numeric(0))` abort with a classed error.
9. Test both standard mode and audit-log mode behavior.

**Acceptance Criteria:**
- [ ] `ctx$features(id, feature_map)` returns aliased scalar numeric values.
- [ ] Warmup `NA` is preserved and not treated as an unknown feature.
- [ ] Invalid instruments and unregistered mapped features fail loudly.
- [ ] `ctx$features()` respects the existing no-lookahead pulse boundary.
- [ ] `passed_warmup()` returns `TRUE` only when all values are non-`NA`.
- [ ] `passed_warmup()` zero-length input aborts with a classed error.
- [ ] Standard and audit-log execution modes behave identically.

**Test Requirements:**
- Pulse-context accessor tests.
- Strategy-run tests using feature maps.
- Warmup `NA` tests.
- Unknown/unregistered feature tests.
- Standard/audit-log parity tests.
- Existing pulse context and strategy helper tests.

**Source Reference:** v0.1.7.4 spec sections R4, R5, R7, A3, A4.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  This ticket adds pulse-context accessors and must preserve no-lookahead,
  execution-mode parity, and strategy context semantics. Pulse semantics and
  execution behavior are hard escalation areas.
invariants_at_risk:
  - no-lookahead pulse context
  - strategy context contract
  - feature warmup semantics
  - execution-mode parity
  - strategy error diagnostics
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_4_spec_packet/v0_1_7_4_spec.md
  - inst/design/ledgr_feature_map_ux.md
  - inst/design/contracts.md (Strategy Contract, Context Contract)
  - R/pulse-context.R
  - R/backtest-runner.R
  - R/indicator_dev.R
  - R/strategy-helpers.R
  - tests/testthat/test-pulse-context-accessors.R
  - tests/testthat/test-backtest-audit-log-equivalence.R
tests_required:
  - pulse-context accessor tests
  - feature-map strategy run tests
  - warmup and unknown feature tests
  - standard/audit-log parity tests
escalation_triggers:
  - ctx$features needs future data or full-table access
  - standard mode and audit-log mode disagree
  - warmup behavior conflicts with feature-engine validation
  - strategy error wrapping loses context
forbidden_actions:
  - adding ctx$features_wide
  - bypassing ctx$feature validation
  - treating unknown features as warmup NA
  - changing pulse order or fill timing
```

---

## LDG-1404: Feature Map Documentation And Teaching Integration

**Priority:** P1  
**Effort:** 2-4 days  
**Dependencies:** LDG-1403  
**Status:** Planned

**Description:**
Document feature maps as the preferred readable authoring pattern for
feature-heavy strategies while keeping the explicit `ctx$feature()` contract
visible. `strategy-development` is the primary teaching home; `indicators`
covers configuration and links to the strategy section.

**Tasks:**
1. Add roxygen docs and examples for `ledgr_feature_map()` and
   `passed_warmup()`.
2. Add `@section Articles:` links for feature-map pages.
3. Update `strategy-development` with the feature-map strategy pattern after
   the basic pulse, target, feature-ID, and warmup contracts.
4. Update `indicators` to introduce feature-map configuration and link forward
   to strategy-development.
5. Explain that `passed_warmup()` is a guard for `ctx$features()` output, not a
   pipeline transformation.
6. Show that `features = list(...)` remains valid.
7. Regenerate Rd and rendered vignette markdown according to repo practice.

**Acceptance Criteria:**
- [ ] `ledgr_feature_map()` and `passed_warmup()` have help pages.
- [ ] Help pages include installed article links and local examples.
- [ ] `strategy-development` is the primary feature-map tutorial.
- [ ] `indicators` explains configuration and links to strategy-development.
- [ ] Docs preserve the explicit `ctx$feature(id, feature_id)` contract.
- [ ] Docs state `passed_warmup()` semantic boundary and zero-length error.
- [ ] Examples avoid hardcoded one-instrument repetition where a universe loop
      is the intended pattern.

**Test Requirements:**
- Documentation render.
- Rd documentation scans.
- Vignette scans for feature-map teaching order.
- Existing documentation contract tests.

**Source Reference:** v0.1.7.4 spec sections A5, B2; `ledgr_feature_map_ux.md`.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: H
classification_reason: >
  Documentation and roxygen work is bounded, but it teaches a new public API
  and strategy-authoring contract. Tier M implementation is acceptable with
  Tier H review for contract accuracy.
invariants_at_risk:
  - feature-map public API documentation
  - strategy authoring mental model
  - documentation teaching order
  - installed article discoverability
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_4_spec_packet/v0_1_7_4_spec.md
  - inst/design/ledgr_feature_map_ux.md
  - inst/design/contracts.md (Documentation Contract, Strategy Contract)
  - R/strategy-helpers.R
  - R/strategy-types.R
  - vignettes/strategy-development.Rmd
  - vignettes/indicators.Rmd
tests_required:
  - documentation render
  - Rd documentation scans
  - feature-map teaching-order scans
escalation_triggers:
  - docs require API behavior not implemented in LDG-1402/1403
  - feature maps appear to replace target-vector strategy contract
  - indicators vignette becomes a duplicate strategy tutorial
forbidden_actions:
  - documenting unimplemented feature roles or selectors
  - hiding ctx$feature explicit contract
  - adding a second execution model in prose
  - making examples depend on network data
```

---

## LDG-1405: External Review And Copy-Paste Documentation Fixes

**Priority:** P2  
**Effort:** 2-3 days  
**Dependencies:** LDG-1401  
**Status:** Planned

**Description:**
Apply the confirmed external-review and auditr documentation fixes that do not
depend on feature-map implementation: visible `article_utc()` cleanup,
homepage framing, `ledgr_backtest()` fixture clarification, leakage wrong/right
example, and first-path navigation cleanup.

**Tasks:**
1. Replace visible vignette calls to hidden `article_utc()` with exported
   `ledgr_utc()`.
2. Remove hidden setup helpers where no longer needed.
3. Add homepage framing near the canonical workflow:
   "The setup is not overhead. The setup is the audit trail."
4. Clarify in `metrics-and-accounting` that `ledgr_backtest()` is a compact
   accounting fixture helper, not the canonical research workflow.
5. Add a leakage wrong/right example in `strategy-development` or a
   pkgdown-only article.
6. Ensure the leakage section ends with: "The ledgr strategy has no object from
   which it can accidentally read tomorrow's close."
7. Remove or rewrite non-runnable first-path examples/navigation.
8. Regenerate README/vignette markdown where applicable.

**Acceptance Criteria:**
- [ ] Visible vignette code no longer calls hidden `article_utc()`.
- [ ] Homepage contains the audit-trail framing sentence.
- [ ] `metrics-and-accounting` labels `ledgr_backtest()` as a compact fixture
      helper and names the canonical workflow.
- [ ] Leakage wrong/right example is present and uses the required closing line.
- [ ] First-path navigation does not send users to non-runnable placeholders.
- [ ] Rendered docs remain in sync with source docs.

**Test Requirements:**
- Documentation scans for `article_utc(` in visible docs.
- README/vignette render.
- Documentation contract tests.
- Pkgdown build if article navigation changes.

**Source Reference:** v0.1.7.4 spec sections R8, B1, B6, B7.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: H
classification_reason: >
  The work is documentation-focused but affects first-contact learning paths
  and package positioning. Tier H review is required for documentation
  contract and north-star alignment.
invariants_at_risk:
  - copy-paste runnable documentation
  - canonical workflow framing
  - no-lookahead teaching
  - first-path documentation navigation
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_4_spec_packet/v0_1_7_4_spec.md
  - inst/design/ledgr_design_philosophy.md
  - README.Rmd
  - vignettes/metrics-and-accounting.Rmd
  - vignettes/strategy-development.Rmd
  - vignettes/getting-started.Rmd
  - _pkgdown.yml
tests_required:
  - article_utc documentation scan
  - README/vignette render
  - documentation contract tests
escalation_triggers:
  - leakage example needs new API support
  - ledgr_backtest fixture framing conflicts with public API docs
  - first-path examples require executable example infrastructure
forbidden_actions:
  - adding new exported docs helper
  - making ledgr_backtest the canonical research path
  - adding browser-only discovery as the only path
  - using hidden helpers in visible code
```

---

## LDG-1406: Helper, Feature-ID, Warmup, And TTR Docs

**Priority:** P2  
**Effort:** 2-4 days  
**Dependencies:** LDG-1401  
**Status:** Planned

**Description:**
Resolve ledgr-side auditr documentation findings around helper discoverability,
feature IDs, parameter-grid feature registration, short-data/warmup diagnosis,
and TTR multi-output examples.

**Tasks:**
1. Add or strengthen `@section Articles:` blocks and local examples for:
   `signal_return()`, `select_top_n()`, `weight_equal()`,
   `target_rebalance()`, `ledgr_signal_strategy()`, `ledgr_signal()`,
   `ledgr_selection()`, `ledgr_weights()`, and `ledgr_target()`.
2. Add examples for named feature aliases with `ledgr_feature_id(features)`.
3. Add a concrete parameter-grid feature registration example using
   `ledgr_ind_returns(5)`, `ledgr_ind_returns(10)`, and
   `ledgr_ind_returns(20)`, with strategy lookup based on `params$lookback`.
4. Extend zero-trade/warmup diagnosis with `requires_bars` and `stable_after`
   versus available bars per instrument.
5. Explain per-instrument warmup and final-bar no-fill behavior.
6. Update TTR docs for suggested-package expectations, BBands outputs, MACD
   matching arguments, warmup rules, and pulse snapshot prerequisites.
7. Record auditr `DOC_DISCOVERY.R` `n = Inf` as an external auditr follow-up,
   not a ledgr package API requirement.

**Acceptance Criteria:**
- [ ] Helper and value-type help pages are useful before reading the vignette.
- [ ] Feature-ID docs cover aliases and parameter-grid registration.
- [ ] Parameter-grid example registers all swept lookback feature variants.
- [ ] Warmup docs cover short data, per-instrument warmup, and final-bar
      no-fill.
- [ ] TTR docs cover dependency, multi-output, MACD, warmup, and pulse snapshot
      prerequisites.
- [ ] Auditr harness bug is recorded as external follow-up.

**Test Requirements:**
- Rd documentation scans.
- Vignette/documentation render.
- Documentation scans for parameter-grid and TTR phrases.
- Existing documentation contract tests.

**Source Reference:** v0.1.7.4 spec sections R9, R10, R11, R12, R15, B2, B3,
B4, B5, D3.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: H
classification_reason: >
  This is documentation and roxygen work, but it teaches public helper,
  feature-ID, warmup, and TTR contracts. Tier M implementation with Tier H
  review is appropriate.
invariants_at_risk:
  - helper composition documentation
  - feature ID discovery
  - warmup semantics
  - TTR multi-output semantics
  - documentation discoverability
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_4_spec_packet/v0_1_7_4_spec.md
  - inst/design/ledgr_v0_1_7_4_spec_packet/ledgr_triage_report.md
  - inst/design/contracts.md (Strategy Contract, Context Contract, Documentation Contract)
  - R/strategy-helpers.R
  - R/strategy-types.R
  - R/signal-strategy.R
  - R/indicator-ttr.R
  - R/indicator.R
  - vignettes/strategy-development.Rmd
  - vignettes/indicators.Rmd
  - vignettes/metrics-and-accounting.Rmd
tests_required:
  - Rd documentation scans
  - documentation render
  - documentation contract tests
escalation_triggers:
  - examples require runtime behavior not currently supported
  - TTR docs reveal implementation mismatch
  - diagnostics require new persistent tables
  - feature-ID docs suggest aliases are implemented before LDG-1402
forbidden_actions:
  - changing feature ID generation
  - auto-registering feature variants
  - treating unknown feature IDs as warmup
  - adding ledgr_docs to work around auditr
```

---

## LDG-1407: CSV Snapshot Import/Seal Workflow Investigation

**Priority:** P0  
**Effort:** 2-4 days  
**Dependencies:** LDG-1401  
**Status:** Planned

**Description:**
Investigate the auditr Task 008 report that the documented CSV
import/seal/backtest workflow required an undocumented metadata workaround
before `ledgr_run()` accepted the sealed snapshot.

**Tasks:**
1. Read the raw Task 008 auditr script and logs before changing code.
2. Identify the exact failing call and the workaround used.
3. Classify the finding as confirmed ledgr bug, documentation mismatch, auditr
   misuse, or no longer reproducible.
4. Reproduce the documented CSV path locally if possible.
5. If confirmed as a bug, add a failing-then-passing regression and fix the
   minimal snapshot/import/metadata path.
6. If not a bug, add a regression or documentation example showing the supported
   path.
7. Preserve snapshot sealing, hashing, loading, and metadata invariants.

**Acceptance Criteria:**
- [ ] Raw Task 008 evidence has been reviewed and summarized.
- [ ] Finding is classified with rationale.
- [ ] Documented `ledgr_snapshot_from_csv()` -> `ledgr_experiment()` ->
      `ledgr_run()` path works without undocumented metadata edits, or the
      required documented path is clarified.
- [ ] New test or documentation protects the supported workflow.
- [ ] Snapshot sealing/hash/load invariants are unchanged.

**Test Requirements:**
- CSV snapshot import/seal/run regression.
- Snapshot load regression if a new-session path is involved.
- Existing snapshot adapter, seal, load, experiment, and runner tests.

**Source Reference:** v0.1.7.4 spec sections R13, C1, C2.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  The ticket may touch snapshot import, sealing, loading, metadata, and
  experiment execution. Snapshot semantics and persistence are hard escalation
  areas, so Tier H implementation and review are required.
invariants_at_risk:
  - snapshot sealing
  - snapshot metadata
  - snapshot loading
  - snapshot hash integrity
  - experiment snapshot validation
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_4_spec_packet/v0_1_7_4_spec.md
  - inst/design/ledgr_v0_1_7_4_spec_packet/ledgr_triage_report.md
  - C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.7.3/2026-05-03_008_snapshot_csv_seal_backtest/
  - inst/design/contracts.md (Snapshot Contract, Persistence Contract)
  - R/snapshot_adapters.R
  - R/snapshots-list.R
  - R/snapshots-seal.R
  - R/experiment.R
  - tests/testthat/test-snapshot-adapters.R
  - tests/testthat/test-snapshots-load.R
tests_required:
  - CSV snapshot import/seal/run regression
  - snapshot load regression if applicable
  - existing snapshot and experiment tests
escalation_triggers:
  - fix requires changing snapshot hash inputs
  - metadata workaround indicates schema migration issue
  - ledgr_run rejects a valid sealed snapshot
  - documented workflow conflicts with snapshot contract
forbidden_actions:
  - bypassing snapshot sealing
  - mutating sealed snapshot data
  - weakening hash verification
  - documenting undocumented metadata edits as normal workflow
```

---

## LDG-1408: Contracts, Site Reference, Installed-Doc Hygiene, And NEWS

**Priority:** P1  
**Effort:** 2-3 days  
**Dependencies:** LDG-1402, LDG-1403, LDG-1404, LDG-1405, LDG-1406  
**Status:** Planned

**Description:**
Align contracts, NEWS, pkgdown reference structure, package help, and installed
documentation hygiene with the implemented v0.1.7.4 scope. Remove stale
installed `ttr-indicators` artifacts unless a deliberate documentation contract
change says otherwise.

**Tasks:**
1. Update `contracts.md` for feature maps, `ctx$features()`,
   `passed_warmup()`, and installed-doc hygiene.
2. Update `NEWS.md` from planned bullets to delivered bullets.
3. Add `ledgr_feature_map()` and `passed_warmup()` to `_pkgdown.yml` reference
   sections.
4. Update package help and function-level article links for new exports.
5. Remove stale `inst/doc/ttr-indicators.Rmd`, `.R`, and `.html` if tracked.
6. Add or update documentation tests preventing retired installed article paths
   from reappearing.
7. Ensure package help and function help do not link to `ttr-indicators`.
8. Render docs according to repo practice.

**Acceptance Criteria:**
- [ ] Contracts describe feature maps as authoring UX, not execution semantics.
- [ ] Contracts describe `ctx$features()` and `passed_warmup()` boundaries.
- [ ] NEWS accurately summarizes v0.1.7.4 delivered scope.
- [ ] `_pkgdown.yml` includes new helper exports in the appropriate reference
      section.
- [ ] Stale installed `ttr-indicators` artifacts are absent or explicitly
      justified by a contract change.
- [ ] Documentation tests guard installed article links and stale paths.

**Test Requirements:**
- Documentation contract tests.
- Installed-doc hygiene tests.
- Rd scans for new exports and article links.
- Pkgdown build if reference/nav changes.
- NEWS/scope scan.

**Source Reference:** v0.1.7.4 spec sections R14, D1, D2.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: H
classification_reason: >
  Mostly documentation, metadata, and site-configuration work, but it changes
  contracts and release-facing package documentation. Tier H review is required
  for contract and release coherence.
invariants_at_risk:
  - documentation contract
  - installed vignette boundary
  - pkgdown reference structure
  - release notes accuracy
  - public API discoverability
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_4_spec_packet/v0_1_7_4_spec.md
  - inst/design/contracts.md
  - inst/design/release_ci_playbook.md
  - NEWS.md
  - _pkgdown.yml
  - R/ledgr-package.R
  - tests/testthat/test-documentation-contracts.R
  - inst/doc/
tests_required:
  - documentation contract tests
  - installed-doc hygiene tests
  - Rd scans
  - pkgdown build if nav/reference changes
escalation_triggers:
  - stale installed docs are required by build tooling
  - pkgdown reference structure conflicts with exports
  - contracts need behavior not implemented by prior tickets
forbidden_actions:
  - retaining stale ttr-indicators installed docs without a contract exception
  - adding undocumented exports
  - changing contracts to bless unimplemented behavior
  - moving pkgdown-only positioning articles into installed vignettes
```

---

## LDG-1409: v0.1.7.4 Release Gate

**Priority:** P0  
**Effort:** 1 day  
**Dependencies:** LDG-1401, LDG-1402, LDG-1403, LDG-1404, LDG-1405, LDG-1406, LDG-1407, LDG-1408  
**Status:** Planned

**Description:**
Final validation gate for v0.1.7.4.

**Tasks:**
1. Verify spec, tickets, contracts, NEWS, DESCRIPTION, README, help pages,
   vignettes, and pkgdown agree.
2. Bump `DESCRIPTION` to version `0.1.7.4` during the release gate.
3. Verify feature-map constructor, experiment integration, config-hash parity,
   and copy-on-use tests.
4. Verify `ctx$features()` and `passed_warmup()` tests, including standard and
   audit-log mode parity.
5. Verify `passed_warmup()` zero-length behavior is a classed error.
6. Verify visible docs no longer call hidden `article_utc()`.
7. Verify homepage, `metrics-and-accounting`, and leakage framing are present.
8. Verify helper, feature-ID, warmup, and TTR docs meet spec.
9. Verify CSV snapshot import finding is fixed or explicitly classified with a
   regression/documentation update.
10. Verify stale installed `ttr-indicators` artifacts are absent or justified.
11. Render README and changed vignettes/articles.
12. Run full package tests.
13. Run coverage gate if required by current release practice.
14. Run package check.
15. Build pkgdown if navigation/reference/articles changed.
16. Run the full WSL/Ubuntu check from `release_ci_playbook.md`.
17. Confirm Windows and Ubuntu remote CI are green before tagging.
18. Confirm no open P0/P1 review findings remain.

**Acceptance Criteria:**
- [ ] Full tests pass.
- [ ] Feature-map and pulse-bundle tests pass.
- [ ] Config-hash parity tests pass.
- [ ] CSV snapshot workflow test or classification is present.
- [ ] `R CMD check --no-manual --no-build-vignettes` passes with 0 errors and
      0 warnings.
- [ ] `DESCRIPTION` version is `0.1.7.4` before release tagging.
- [ ] README and changed articles render.
- [ ] pkgdown builds if navigation/reference/articles changed.
- [ ] Local WSL/Ubuntu gate passes on the release branch.
- [ ] Remote Windows and Ubuntu CI are green on the target commit.
- [ ] Contracts, NEWS, help pages, and vignettes match the implemented scope.
- [ ] No accidental future-cycle API exposure exists.
- [ ] No open P0/P1 review findings remain.

**Test Requirements:**
- Full package tests.
- Feature-map test suite.
- Pulse-context parity tests.
- CSV snapshot workflow tests.
- R CMD check.
- README/article renders.
- pkgdown build if applicable.
- export/API inventory scan.
- local WSL/Ubuntu gate.
- remote CI verification.

**Source Reference:** v0.1.7.4 spec section 9.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: H
review_tier: H
classification_reason: >
  Release gates are Tier H by routing rule. This ticket validates public API,
  context behavior, identity, snapshot investigation, documentation, contracts,
  CI, package metadata, and release tagging readiness.
invariants_at_risk:
  - release correctness
  - public API export boundary
  - config_hash identity
  - pulse context semantics
  - snapshot workflow correctness
  - documentation accuracy
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_4_spec_packet/v0_1_7_4_spec.md
  - inst/design/ledgr_v0_1_7_4_spec_packet/v0_1_7_4_tickets.md
  - inst/design/ledgr_v0_1_7_4_spec_packet/tickets.yml
  - inst/design/contracts.md
  - inst/design/release_ci_playbook.md
  - DESCRIPTION
  - NEWS.md
  - README.Rmd
  - _pkgdown.yml
tests_required:
  - full package tests
  - feature-map tests
  - pulse-context parity tests
  - CSV snapshot workflow tests
  - R CMD check
  - README/article renders
  - pkgdown build if applicable
  - export/API inventory scan
  - local WSL/Ubuntu gate
  - remote CI verification
escalation_triggers:
  - any CI failure remains unexplained
  - config_hash parity fails
  - R CMD check warnings require scope decisions
  - CSV snapshot investigation remains unresolved
  - documentation examples cannot run offline
forbidden_actions:
  - tagging before remote CI is green
  - ignoring R CMD check warnings
  - shipping with stale retired installed docs
  - accepting the gate with open P0 or P1 issues
```

---

## Out Of Scope

Do not implement these in v0.1.7.4:

- `ledgr_docs()`;
- `ledgr_sweep()`;
- `ledgr_precompute_features()`;
- `ledgr_tune()`;
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
- hard delete.
