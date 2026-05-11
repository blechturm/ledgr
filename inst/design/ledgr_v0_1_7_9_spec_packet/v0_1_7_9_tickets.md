# ledgr v0.1.7.9 Tickets

**Version:** 0.1.7.9
**Date:** May 11, 2026
**Total Tickets:** 7

---

## Ticket Organization

v0.1.7.9 closes the strategy-author ergonomics and public-documentation polish
work that remains after v0.1.7.7 risk metrics and v0.1.7.8 reproducibility
preflight. It improves warmup feasibility inspection, helper-pipeline behavior,
feature-map/context documentation, custom-indicator contract clarity,
programmatic result examples, snapshot lifecycle docs, and public site flow.

The release remains conservative. It does not add sweep mode,
`ledgr_precompute_features()`, `ctx$all_features()`, `ledgr_snapshot_split()`,
or a persisted feature-series retrieval API.

Tracks:

1. **Scope and routing:** route v0.1.7.8 auditr findings and lock maintainer
   decisions.
2. **Feature feasibility:** add `ledgr_feature_contract_check()`.
3. **Helper semantics:** make `select_top_n()` empty selections object-based.
4. **Strategy author docs:** feature IDs, feature maps, ctx accessors, warmup,
   custom indicators, and sizing.
5. **Result/store docs and messages:** comparison, metrics, snapshot lifecycle,
   store examples, and targeted runtime-message polish.
6. **Public site polish:** pkgdown order, homepage cleanup, stale artifacts, and
   repo hygiene.
7. **Release gate:** NEWS, ticket status, verification, and CI.

### Dependency DAG

```text
LDG-1901 -> LDG-1902 ----.
LDG-1901 -> LDG-1903 ----+-> LDG-1904 ----.
LDG-1901 -> LDG-1905 ---------------------+-> LDG-1907
LDG-1901 -> LDG-1906 ---------------------'
```

`LDG-1907` is the v0.1.7.9 release gate.

### Priority Levels

- **P0 (Blocker):** Required for release correctness or scope coherence.
- **P1 (Critical):** Required for the v0.1.7.9 user-facing contract to hold.
- **P2 (Important):** Required for release hygiene and future maintainability.
- **P3 (Optional):** Useful, but not a release blocker.

---

## LDG-1901: Scope, auditr Routing, And Maintainer Decisions

**Priority:** P0
**Effort:** 0.5 day
**Dependencies:** None
**Status:** Done

**Description:**
Finalize the v0.1.7.9 scope baseline before implementation. Confirm that the
v0.1.7.8 auditr reports are routed through this packet, that all ten auditr
themes have an explicit disposition, and that maintainer decisions MD1-MD10 are
locked before code tickets begin.

**Tasks:**
1. Read `v0_1_7_9_spec.md`, `cycle_retrospective.md`,
   `ledgr_triage_report.md`, and the v0.1.7.9 roadmap section.
2. Confirm every v0.1.7.8 auditr theme has a routing decision in the spec.
3. Confirm THEME-008 remains auditr-owned and excluded from ledgr package work.
4. Confirm feature-series retrieval, `ctx$all_features()`, train/test split
   helpers, and sweep mode remain deferred.
5. Confirm `ledgr` examples remain tidyverse-adjacent and that suggested-package
   expectations are explicit rather than replaced with a base-R-only path.
6. Update this ticket file and `tickets.yml` only if routing or dependencies
   change.

**Acceptance Criteria:**
- [x] Every v0.1.7.8 auditr theme has a v0.1.7.9, backlog, deferred, or
      auditr-owned routing decision.
- [x] MD1-MD10 remain recorded in `v0_1_7_9_spec.md`.
- [x] No auditr finding is promoted without raw-evidence classification.
- [x] v0.1.7.9 scope remains limited to strategy-author ergonomics,
      documentation/discoverability, targeted runtime-message polish, and public
      site hygiene.
- [x] The release explicitly excludes sweep mode, `ctx$all_features()`,
      `ledgr_snapshot_split()`, and persisted feature-series retrieval.

**Implementation Notes:**
- Reviewed `cycle_retrospective.md` and `ledgr_triage_report.md` against
  `v0_1_7_9_spec.md`.
- Confirmed all ten v0.1.7.8 auditr themes are recorded in the evidence
  baseline, with THEME-008 excluded as auditr harness/runner friction.
- Confirmed MD1-MD10 are recorded before implementation tickets begin.
- Confirmed feature-series retrieval, `ctx$all_features()`,
  `ledgr_snapshot_split()`, and sweep/precompute APIs remain deferred.
- Confirmed the first-run docs decision keeps ledgr tidyverse-adjacent rather
  than adding a base-R-only path for agent convenience.

**Verification:**
```text
documentation/routing review
scope grep for deferred API expansion
```

Result: passed. No implementation definitions for `ledgr_sweep()`,
`ledgr_precompute_features()`, `ctx$all_features()`, `ledgr_snapshot_split()`,
or `ledgr_results(..., what = "features")` were found in active package code,
tests, vignettes, README, or `contracts.md`.

**Test Requirements:**
- Documentation/routing review.
- Scope grep for forbidden API expansion.

**Source Reference:** v0.1.7.9 spec sections 1.1, 2, 3.1, 6, 7.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: L
review_tier: M
classification_reason: >
  Scope routing determines which auditr findings become implementation work and
  prevents v0.1.7.9 from expanding into sweep, train/test split helpers, or
  feature-retrieval APIs.
invariants_at_risk:
  - release scope discipline
  - auditr evidence routing
  - roadmap sequencing
required_context:
  - inst/design/ledgr_v0_1_7_9_spec_packet/v0_1_7_9_spec.md
  - inst/design/ledgr_v0_1_7_9_spec_packet/cycle_retrospective.md
  - inst/design/ledgr_v0_1_7_9_spec_packet/ledgr_triage_report.md
  - inst/design/ledgr_roadmap.md
tests_required:
  - documentation/routing review
escalation_triggers:
  - auditr evidence reveals a confirmed runtime defect outside current scope
  - a deferred API is required to satisfy a v0.1.8 blocker
forbidden_actions:
  - implementing runtime changes
  - adding ledgr APIs for auditr harness issues
  - promoting unclear auditr rows without raw evidence
```

---

## LDG-1902: Feature Contract Feasibility Helper

**Priority:** P1
**Effort:** 1-2 days
**Dependencies:** LDG-1901
**Status:** Done

**Description:**
Implement `ledgr_feature_contract_check(snapshot, features)` as a pre-run
inspection helper. The helper combines declared feature requirements with actual
sealed-snapshot per-instrument bar counts and reports whether warmup is
achievable for each instrument-feature pair.

**Tasks:**
1. Add exported `ledgr_feature_contract_check(snapshot, features)`.
2. Reuse existing feature validation where possible so supported static feature
   shapes match `ledgr_feature_contracts()`.
3. Query per-instrument available bar counts from the sealed snapshot.
4. Return a data frame with `instrument_id`, `feature_id`, `requires_bars`,
   `available_bars`, and `warmup_achievable`.
5. Reject `features = function(params)` feature factories with a classed,
   actionable error that tells users to materialize the factory first.
6. Document that the helper is diagnostic only: no mutation, repair, imputation,
   dropping, or feature computation.
7. Add reference docs and pkgdown reference entry.
8. Add a concise example in a vignette or help page.

**Acceptance Criteria:**
- [x] `ledgr_feature_contract_check()` is exported and documented.
- [x] Balanced snapshots with sufficient history report `warmup_achievable =
      TRUE`.
- [x] Short or uneven snapshots report `warmup_achievable = FALSE` for affected
      instrument-feature pairs.
- [x] Feature maps preserve alias/engine-ID clarity in output or docs.
- [x] Feature factories fail with a classed actionable error.
- [x] The helper does not mutate snapshot tables or compute feature values.
- [x] At least one public doc example demonstrates pre-run warmup feasibility
      checking.

**Implementation Notes:**
- Added exported `ledgr_feature_contract_check(snapshot, features)` in
  `R/feature-inspection.R`.
- The helper reuses `ledgr_feature_contracts()` input normalization, rejects
  feature factories with class `ledgr_feature_factory_requires_params`, and
  requires a sealed snapshot.
- Output preserves feature aliases and engine IDs and adds `available_bars` plus
  `warmup_achievable` per instrument-feature pair without computing feature
  values.
- Added help, pkgdown reference entry, API export registration, and a warmup
  feasibility example in `vignettes/indicators.Rmd`.

**Verification:**
```text
PASS: testthat::test_file("tests/testthat/test-feature-inspection.R", reporter = "summary")
PASS: testthat::test_file("tests/testthat/test-api-exports.R", reporter = "summary")
PASS: testthat::test_file("tests/testthat/test-documentation-contracts.R", reporter = "summary")
PASS: rmarkdown::render("vignettes/indicators.Rmd", output_format = "github_document", quiet = TRUE)
PASS: testthat::test_local(".", reporter = "summary") with 1 expected skip
```

**Test Requirements:**
- `tests/testthat/test-feature-inspection.R`
- `tests/testthat/test-documentation-contracts.R`

**Source Reference:** v0.1.7.9 spec R2, R3, R5, T1.

**Classification:**
```yaml
risk_level: high
implementation_tier: M
review_tier: H
classification_reason: >
  The helper introduces a new exported inspection API over sealed snapshot
  data and feature contracts, and it must not weaken snapshot immutability or
  feature-generation semantics.
invariants_at_risk:
  - sealed snapshot immutability
  - feature contract semantics
  - warmup diagnostics accuracy
  - no feature computation in inspection helper
required_context:
  - inst/design/ledgr_v0_1_7_9_spec_packet/v0_1_7_9_spec.md
  - inst/design/contracts.md
  - R/feature-inspection.R
  - R/snapshots-info.R
  - tests/testthat/test-feature-inspection.R
tests_required:
  - tests/testthat/test-feature-inspection.R
  - tests/testthat/test-documentation-contracts.R
escalation_triggers:
  - feature factories require params-aware inspection to be useful
  - snapshot bar counts cannot be queried without changing snapshot APIs
  - feature-map alias semantics conflict with existing feature contracts
forbidden_actions:
  - mutating sealed snapshots
  - computing or persisting feature values
  - adding persisted feature-series retrieval
  - silently accepting feature factories without concrete params
```

---

## LDG-1903: `select_top_n()` Empty-Selection Semantics

**Priority:** P1
**Effort:** 1 day
**Dependencies:** LDG-1901
**Status:** Done

**Description:**
Change the all-missing/no-usable-signal path in `select_top_n()` from a warning
path to an object path. Expected warmup/no-signal conditions should return a
classed empty selection that flows through `weight_equal()` and
`target_rebalance()` to a flat full-universe target.

**Tasks:**
1. Update `select_top_n()` so all-missing signals return a classed empty
   `ledgr_selection` without warning.
2. Reuse or add `ledgr_empty_selection` as a result class.
3. Preserve original universe and signal origin metadata.
4. Review `weight_equal()` and `target_rebalance()` and make minimal updates if
   needed so the helper pipeline returns a flat full-universe target.
5. Keep deterministic tie-breaking and partial-selection behavior intact.
6. Update helper docs and examples to remove the normal `suppressWarnings()`
   warmup pattern where appropriate.

**Acceptance Criteria:**
- [x] All-missing signals return an object inheriting from both
      `ledgr_empty_selection` and `ledgr_selection`.
- [x] No warning is emitted for the all-missing path.
- [x] Empty selections preserve the full original universe for downstream target
      construction.
- [x] `weight_equal(select_top_n(empty_signal, n))` returns empty weights with
      universe metadata preserved.
- [x] `target_rebalance(weight_equal(select_top_n(empty_signal, n)), ctx, ...)`
      returns a flat full-universe target.
- [x] Partial-selection warnings remain deterministic unless explicitly changed
      by raw evidence.
- [x] Strategy-development docs no longer teach warning suppression as the
      expected warmup path.

**Implementation Notes:**
- Updated `select_top_n()` so all-missing signals return a
  `ledgr_empty_selection`/`ledgr_selection` object without warning.
- Preserved signal origin and full-universe metadata on the empty selection so
  `weight_equal()` and `target_rebalance()` produce a flat full-universe target.
- Kept deterministic tie-breaking and `ledgr_partial_selection` warning
  behavior unchanged.
- Updated helper tests, reference docs, and strategy/metrics vignette prose to
  remove the normal warmup `suppressWarnings()` pattern.
- Re-rendered `strategy-development.md` and `metrics-and-accounting.md`.

**Verification:**
```text
PASS: testthat::test_file("tests/testthat/test-strategy-reference.R", reporter = "summary")
PASS: testthat::test_file("tests/testthat/test-documentation-contracts.R", reporter = "summary")
PASS: rmarkdown::render("vignettes/strategy-development.Rmd", output_format = "github_document", quiet = TRUE)
PASS: rmarkdown::render("vignettes/metrics-and-accounting.Rmd", output_format = "github_document", quiet = TRUE)
```

**Test Requirements:**
- `tests/testthat/test-strategy-reference.R`
- `tests/testthat/test-documentation-contracts.R`

**Source Reference:** v0.1.7.9 spec R4, T2, MD8.

**Classification:**
```yaml
risk_level: high
implementation_tier: M
review_tier: H
classification_reason: >
  This changes strategy-helper behavior used inside user strategy functions and
  must preserve the target-vector contract and helper-pipeline semantics.
invariants_at_risk:
  - strategy helper pipeline behavior
  - full-universe target construction
  - no silent missing-target treatment
required_context:
  - inst/design/ledgr_v0_1_7_9_spec_packet/v0_1_7_9_spec.md
  - R/strategy-helpers.R
  - tests/testthat/test-strategy-reference.R
  - vignettes/strategy-development.Rmd
tests_required:
  - tests/testthat/test-strategy-reference.R
  - tests/testthat/test-documentation-contracts.R
escalation_triggers:
  - empty selection cannot preserve universe without changing helper classes
  - documented strategies depend on the old warning path
  - downstream helpers produce partial or unnamed targets
forbidden_actions:
  - treating missing strategy targets as zero
  - changing the strategy function signature
  - changing fill or execution semantics
```

---

## LDG-1904: Strategy Context, Feature Map, Warmup, And Custom Indicator Docs

**Priority:** P1
**Effort:** 2-3 days
**Dependencies:** LDG-1902, LDG-1903
**Status:** Todo

**Description:**
Close strategy-author documentation gaps around feature IDs, feature-map aliases,
`ctx$feature()`, `ctx$features()`, warmup, custom indicator signatures,
multi-lookback pre-registration, and raw whole-share sizing.

**Tasks:**
1. Add or update a strategy-context/accessor reference surface for
   `ctx$feature()`, `ctx$features()`, `ctx$flat()`, `ctx$hold()`, and related
   pulse accessors.
2. Clarify feature-map aliases versus engine feature IDs.
3. Document where feature maps are accepted and where lower-level helpers remain
   narrower.
4. Apply MD1 and MD2: keep `ledgr_experiment()` canonical and do not make
   `ledgr_backtest()` a first-class feature-map target unless the fix is
   trivial.
5. Add generated feature-ID, warmup, and `requires_bars`/`stable_after` guidance
   for built-in, native RSI, TTR-backed, and multi-output indicators.
6. Add multi-lookback pre-registration examples for parameterized strategies.
7. Update custom-indicator docs for `fn(window, params)`,
   `series_fn(bars, params)`, precedence, equivalence expectations, params
   behavior, and a causal corrected `series_fn` example.
8. Document the canonical raw sizing formula:
   `floor(weight * equity_fraction * ctx$equity / ctx$close(instrument_id))`.
9. Add See Also links among feature maps, `passed_warmup()`,
   `ledgr_feature_id()`, `ledgr_feature_contracts()`, pulse inspection, and the
   new feature-contract check helper.
10. Keep `ctx$all_features()` deferred and explain the current alternatives
    only where useful.

**Acceptance Criteria:**
- [ ] Users can find `ctx$feature()` and `ctx$features()` from installed help or
      pkgdown docs without text-searching vignettes.
- [ ] Feature-map alias versus engine-ID semantics are explained with examples.
- [ ] Docs state which APIs accept feature maps and which are narrower.
- [ ] Built-in, native RSI, TTR-backed, and multi-output indicator examples show
      or explain expected feature IDs.
- [ ] Parameterized lookback examples show registering every concrete feature
      variant before `ledgr_run()`.
- [ ] Custom-indicator docs consistently use `fn(window, params)` and
      `series_fn(bars, params)`.
- [ ] At least one corrected causal `series_fn` example is shown.
- [ ] Raw whole-share sizing formula matches `target_rebalance()`.
- [ ] No docs imply helpers lazily create features from `params`.
- [ ] No `ctx$all_features()` API is added.

**Implementation Notes:**
- Pending.

**Verification:**
```text
documentation contract tests
targeted help-page render checks
```

**Test Requirements:**
- `tests/testthat/test-documentation-contracts.R`
- Optional targeted vignette render checks for changed articles.

**Source Reference:** v0.1.7.9 spec Track D, R5, R6, R7, MD1, MD2, MD7.

**Classification:**
```yaml
risk_level: high
implementation_tier: M
review_tier: H
classification_reason: >
  These docs teach the user-facing strategy-author contract. Inaccurate wording
  can create feature leakage, wrong feature registration, or incompatible helper
  usage.
invariants_at_risk:
  - feature ID contract
  - feature-map alias semantics
  - pulse-context no-lookahead model
  - custom indicator determinism
  - target sizing semantics
required_context:
  - inst/design/ledgr_v0_1_7_9_spec_packet/v0_1_7_9_spec.md
  - vignettes/strategy-development.Rmd
  - vignettes/indicators.Rmd
  - vignettes/custom-indicators.Rmd
  - R/feature-map.R
  - R/feature-inspection.R
  - R/pulse-context.R
  - R/indicator_dev.R
tests_required:
  - tests/testthat/test-documentation-contracts.R
escalation_triggers:
  - feature-map compatibility requires nontrivial runtime normalization
  - custom indicator docs reveal behavior inconsistent with implementation
  - raw sizing formula conflicts with target_rebalance tests
forbidden_actions:
  - implementing ctx$all_features()
  - implementing sweep/precompute APIs
  - claiming ledgr certifies custom series_fn causal correctness
```

---

## LDG-1905: Result, Store, Snapshot, Metrics, And Targeted Message Polish

**Priority:** P1
**Effort:** 2-3 days
**Dependencies:** LDG-1901
**Status:** Todo

**Description:**
Improve programmatic examples and selected diagnostics for experiment-store
results, comparison tables, metrics, snapshot lifecycle, strategy recovery, and
runtime messages. Keep changes limited to documentation and small, evidenced
error-message improvements.

**Tasks:**
1. Add raw `ledgr_compare_runs()` metric extraction examples.
2. Add follow-up equity-curve comparison examples after selecting runs.
3. Clarify `summary(bt)` print output versus returned object behavior.
4. Direct scripted metric users to `ledgr_compute_metrics()`.
5. Document flat-strategy Sharpe `NA`, near-zero excess-return volatility, and
   annualization constants.
6. Add or improve `ledgr_run_info()` field references.
7. Add stored-strategy recovery/rerun examples and relevant error classes such
   as `ledgr_run_not_found`.
8. Document post-close result/store access.
9. Consolidate CSV/Yahoo snapshot lifecycle, sealing semantics,
   `ledgr_snapshot_info()` columns, parsed `meta_json`, counts, and ISO UTC
   date formats.
10. Keep the low-level CSV bridge in `experiment-store.Rmd`, but add an
    advanced-section transition and record the future "Data Input And Snapshot
    Creation" article candidate if needed.
11. Document the current persisted feature boundary and defer full feature-series
    retrieval to v0.1.8.
12. Promote only targeted runtime-message improvements from MD3 when they are
    low risk and backed by raw evidence.

**Acceptance Criteria:**
- [ ] Programmatic comparison examples show raw numeric extraction, not string
      parsing.
- [ ] Docs show how to inspect or compare equity curves after selecting runs.
- [ ] `summary(bt)` and `ledgr_compute_metrics()` scripted usage are clear.
- [ ] Sharpe `NA` edge cases and annualization assumptions are documented.
- [ ] `ledgr_run_info()` fields are documented or cross-linked.
- [ ] Strategy recovery docs include rerun boundaries and missing-run class.
- [ ] Snapshot lifecycle docs cover CSV, Yahoo, sealing state, metadata columns,
      and `meta_json` keys.
- [ ] `experiment-store.Rmd` clearly marks the CSV bridge as advanced material.
- [ ] Persisted feature-series retrieval is explicitly deferred.
- [ ] Any runtime-message changes are covered by targeted tests.

**Implementation Notes:**
- Pending.

**Verification:**
```text
documentation contract tests
targeted tests for any changed errors
```

**Test Requirements:**
- `tests/testthat/test-documentation-contracts.R`
- Targeted tests for changed runtime messages/classes.

**Source Reference:** v0.1.7.9 spec Track E, R8, MD3, MD4, MD5, MD9.

**Classification:**
```yaml
risk_level: high
implementation_tier: M
review_tier: H
classification_reason: >
  Result, metric, store, and snapshot docs are central to ledgr's auditability.
  Runtime-message changes must stay narrow and avoid changing behavior.
invariants_at_risk:
  - result table semantics
  - metric contract documentation
  - snapshot lifecycle clarity
  - strategy provenance trust boundary
  - no persisted feature retrieval in v0.1.7.9
required_context:
  - inst/design/ledgr_v0_1_7_9_spec_packet/v0_1_7_9_spec.md
  - vignettes/experiment-store.Rmd
  - vignettes/metrics-and-accounting.Rmd
  - vignettes/research-to-production.Rmd
  - R/run-store.R
  - R/backtest.R
  - R/snapshots-info.R
  - R/snapshot_adapters.R
tests_required:
  - tests/testthat/test-documentation-contracts.R
  - targeted tests for changed error messages
escalation_triggers:
  - docs require adding feature-series retrieval
  - snapshot metadata docs reveal schema inconsistency
  - runtime-message improvements require behavior changes
forbidden_actions:
  - adding ledgr_results(..., what = "features")
  - changing metric definitions
  - changing snapshot seal semantics
  - implementing data-input article split unless explicitly promoted
```

---

## LDG-1906: Public Site Polish, Article Order, And Repo Hygiene

**Priority:** P2
**Effort:** 1-2 days
**Dependencies:** LDG-1901
**Status:** Todo

**Description:**
Polish the public-facing documentation surface after the v0.1.7.8 concept
articles. Reorder articles, clean stale/internal homepage material, remove local
paths and generated artifacts, and make example dependency expectations
explicit while keeping ledgr tidyverse-adjacent.

**Tasks:**
1. Reorder `_pkgdown.yml` article groups around the reader journey.
2. Move `who-ledgr-is-for` and core concept articles earlier in the site.
3. Trim internal `system.file()` and design-packet references from the
   homepage/README.
4. Remove stale version references such as `v0.1.7.2 helper layer` where not
   intentionally historical.
5. Remove stale visible link text such as `custom-indicators.md`.
6. Avoid local machine paths in rendered README/homepage output.
7. Verify rendered docs do not contain `no DISPLAY variable` warnings if
   reproducible locally.
8. Keep `dplyr` in public examples where appropriate, but state that examples
   use it for data preparation and that strategy functions use ledgr pulse
   contexts.
9. Soften or link `auditr` companion-package references depending on public
   availability.
10. Remove `Rprof.out` and ignore generated profiling artifacts.

**Acceptance Criteria:**
- [ ] Pkgdown article order matches the v0.1.7.9 reader journey.
- [ ] Homepage preserves the core product pitch while removing internal/stale
      material.
- [ ] Public docs contain no local `C:\Users\` paths.
- [ ] Public docs contain no stale `custom-indicators.md` visible link text.
- [ ] Public docs contain no unintended stale version references.
- [ ] `dplyr` usage is intentional and documented as example data preparation.
- [ ] `Rprof.out` is absent from the repository and ignored going forward.
- [ ] pkgdown builds after the polish pass.

**Implementation Notes:**
- Pending.

**Verification:**
```text
pkgdown build
documentation contract tests
rendered-site grep for stale artifacts
```

**Test Requirements:**
- `tests/testthat/test-documentation-contracts.R`
- pkgdown build.

**Source Reference:** v0.1.7.9 spec Track F, D1, D2, R8, MD6.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: M
classification_reason: >
  Public site polish affects first impressions and discoverability, but should
  not change runtime semantics.
invariants_at_risk:
  - public documentation accuracy
  - package positioning
  - release hygiene
required_context:
  - inst/design/ledgr_v0_1_7_9_spec_packet/v0_1_7_9_spec.md
  - _pkgdown.yml
  - README.md
  - vignettes/articles/who-ledgr-is-for.Rmd
  - vignettes/articles/why-r.Rmd
  - vignettes/leakage.Rmd
  - vignettes/reproducibility.Rmd
tests_required:
  - tests/testthat/test-documentation-contracts.R
  - pkgdown build
escalation_triggers:
  - pkgdown ordering conflicts with generated site structure
  - local path output comes from a print method rather than rendered examples
  - removing Rprof.out exposes broader ignore hygiene issues
forbidden_actions:
  - changing runtime behavior for site polish
  - removing tidyverse-adjacent examples solely for agent convenience
  - adding new concept articles without maintainer approval
```

---

## LDG-1907: v0.1.7.9 Release Gate, NEWS, And Packet Finalization

**Priority:** P0
**Effort:** 1 day
**Dependencies:** LDG-1902, LDG-1903, LDG-1904, LDG-1905, LDG-1906
**Status:** Todo

**Description:**
Finalize v0.1.7.9 after all implementation and documentation tickets are done.
Update NEWS and ticket status, run verification, confirm deferred scope remains
deferred, and ensure Ubuntu/Windows CI are green before merge/tag.

**Tasks:**
1. Update `NEWS.md` for v0.1.7.9.
2. Update `DESCRIPTION` version if release timing requires it.
3. Confirm ticket statuses and `tickets.yml` are in sync.
4. Confirm v0.1.7.8 auditr findings are routed or explicitly deferred.
5. Confirm deferred items remain deferred: sweep, precompute, `ctx$all_features`,
   persisted feature retrieval, and `ledgr_snapshot_split`.
6. Run targeted tests for changed code.
7. Run documentation contract tests.
8. Run full local tests.
9. Run package check and pkgdown build.
10. Confirm generated artifacts are not committed.

**Acceptance Criteria:**
- [ ] All prior v0.1.7.9 tickets are complete or explicitly deferred.
- [ ] NEWS and version metadata match the shipped scope.
- [ ] `v0_1_7_9_tickets.md` and `tickets.yml` are synchronized.
- [ ] Documentation contract tests pass.
- [ ] Full local tests pass.
- [ ] `R CMD check --no-manual --no-build-vignettes` passes.
- [ ] pkgdown builds.
- [ ] No generated artifacts are committed.
- [ ] Ubuntu and Windows CI are green.

**Implementation Notes:**
- Pending.

**Verification:**
```text
targeted tests
documentation contract tests
full testthat
R CMD check
pkgdown build
CI
```

**Test Requirements:**
- Full test suite.
- R CMD check.
- pkgdown build.
- CI on Ubuntu and Windows.

**Source Reference:** v0.1.7.9 spec sections 5, 6, 8, 9.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: M
review_tier: H
classification_reason: >
  The release gate validates all scoped docs/API work and ensures deferred
  sweep-related features did not leak into v0.1.7.9.
invariants_at_risk:
  - release correctness
  - CI health
  - documentation contract consistency
  - deferred scope boundaries
required_context:
  - inst/design/ledgr_v0_1_7_9_spec_packet/v0_1_7_9_spec.md
  - inst/design/ledgr_v0_1_7_9_spec_packet/v0_1_7_9_tickets.md
  - inst/design/ledgr_v0_1_7_9_spec_packet/tickets.yml
  - NEWS.md
  - DESCRIPTION
tests_required:
  - targeted tests
  - tests/testthat/test-documentation-contracts.R
  - full testthat
  - R CMD check
  - pkgdown build
escalation_triggers:
  - release gate reveals scope creep into v0.1.8 work
  - CI failure requires code changes outside completed tickets
  - generated artifacts are produced by verification
forbidden_actions:
  - merging with failing CI
  - committing generated local artifacts
  - adding release-scope features during the gate without a ticket
```
