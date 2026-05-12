# ledgr v0.1.7.9 Tickets

**Version:** 0.1.7.9
**Date:** May 11, 2026
**Total Tickets:** 10

---

## Ticket Organization

v0.1.7.9 closes the strategy-author ergonomics and public-documentation polish
work that remains after v0.1.7.7 risk metrics and v0.1.7.8 reproducibility
preflight. It improves warmup feasibility inspection, helper-pipeline behavior,
feature-map/context documentation, custom-indicator contract clarity,
programmatic result examples, snapshot lifecycle docs, and public site flow.
After a late execution-engine audit, the release also includes a
release-blocking opening-position cost-basis fix plus narrow fill-model
documentation and runner cleanup follow-ups.

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
7. **Runtime blocker:** opening-position lot accounting and shared FIFO helper.
8. **Fill-model docs:** document spread semantics as a per-leg price
   adjustment.
9. **Runner cleanup:** remove dead equity buffers and route minor audit
   follow-ups.
10. **FIFO edge-case tests:** add opening-position accounting regression
    coverage before release.
11. **Release gate:** NEWS, ticket status, verification, and CI.

### Dependency DAG

```text
LDG-1901 -> LDG-1902 ----.
LDG-1901 -> LDG-1903 ----+-> LDG-1904 ----.
LDG-1901 -> LDG-1905 ---------------------+-> LDG-1907
LDG-1901 -> LDG-1906 ---------------------+
LDG-1901 -> LDG-1908 ---------------------+
LDG-1901 -> LDG-1909 ---------------------+
LDG-1901 -> LDG-1910 ---------------------+
LDG-1908 -> LDG-1911 ---------------------'
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
**Status:** Done

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
- [x] Users can find `ctx$feature()` and `ctx$features()` from installed help or
      pkgdown docs without text-searching vignettes.
- [x] Feature-map alias versus engine-ID semantics are explained with examples.
- [x] Docs state which APIs accept feature maps and which are narrower.
- [x] Built-in, native RSI, TTR-backed, and multi-output indicator examples show
      or explain expected feature IDs.
- [x] Parameterized lookback examples show registering every concrete feature
      variant before `ledgr_run()`.
- [x] Custom-indicator docs consistently use `fn(window, params)` and
      `series_fn(bars, params)`.
- [x] At least one corrected causal `series_fn` example is shown.
- [x] Raw whole-share sizing formula matches `target_rebalance()`.
- [x] No docs imply helpers lazily create features from `params`.
- [x] No `ctx$all_features()` API is added.

**Implementation Notes:**
- Added installed help topic `?ledgr_strategy_context` and pkgdown reference
  entry for context accessors including `ctx$feature()`, `ctx$features()`,
  `ctx$flat()`, and `ctx$hold()`.
- Updated strategy and indicator docs to distinguish feature-map aliases,
  engine feature IDs, accepted feature object shapes, and narrower lower-level
  surfaces.
- Added native RSI feature-ID/warmup coverage alongside existing built-in,
  TTR-backed, and multi-output examples.
- Updated custom-indicator docs for `fn(window, params)`,
  `series_fn(bars, params)`, scalar/vectorized precedence, equivalence
  expectations, deterministic params, and a causal `sides = 1` vectorized
  example.
- Made the custom-indicator register/read section self-contained with demo
  data, a real snapshot, and a universe loop instead of hard-coded `AAA`.
- Documented the raw and weighted whole-share sizing formulas used by
  `target_rebalance()`.

**Verification:**
```text
PASS: testthat::test_file("tests/testthat/test-documentation-contracts.R", reporter = "summary")
PASS: rmarkdown::render("vignettes/strategy-development.Rmd", output_format = "github_document", quiet = TRUE)
PASS: rmarkdown::render("vignettes/indicators.Rmd", output_format = "github_document", quiet = TRUE)
PASS: rmarkdown::render("vignettes/custom-indicators.Rmd", output_format = "github_document", quiet = TRUE)
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
**Status:** Done

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
- [x] Programmatic comparison examples show raw numeric extraction, not string
      parsing.
- [x] Docs show how to inspect or compare equity curves after selecting runs.
- [x] `summary(bt)` and `ledgr_compute_metrics()` scripted usage are clear.
- [x] Sharpe `NA` edge cases and annualization assumptions are documented.
- [x] `ledgr_run_info()` fields are documented or cross-linked.
- [x] Strategy recovery docs include rerun boundaries and missing-run class.
- [x] Snapshot lifecycle docs cover CSV, Yahoo, sealing state, metadata columns,
      and `meta_json` keys.
- [x] `experiment-store.Rmd` clearly marks the CSV bridge as advanced material.
- [x] Persisted feature-series retrieval is explicitly deferred.
- [x] Any runtime-message changes are covered by targeted tests.

**Implementation Notes:**
- Added raw `ledgr_compare_runs()` extraction and follow-up equity inspection
  examples after selecting the best run.
- Clarified that `summary(bt)` is print-oriented and that
  `ledgr_compute_metrics()` is the scripted metric extraction path.
- Expanded `ledgr_run_info()` field references in the store article and help.
- Added stored-strategy trusted rerun sketch and `ledgr_run_not_found`
  boundary.
- Consolidated CSV/Yahoo snapshot lifecycle, sealing, `ledgr_snapshot_info()`
  fields, `meta_json`, counts, and ISO UTC dates.
- Marked the low-level CSV bridge as advanced material and recorded the future
  "Data Input And Snapshot Creation" article candidate.
- Documented the current persisted-feature boundary and explicitly deferred
  feature-series retrieval to v0.1.8 precompute/sweep design.
- Narrowly improved `ledgr_results(bt, what = "metrics")` and unknown result
  table errors with a ledgr-specific class and `ledgr_compute_metrics()` hint.
- Softened the research-to-production reconciliation overclaim.

**Verification:**
```text
PASS: testthat::test_file("tests/testthat/test-documentation-contracts.R", reporter = "summary")
PASS: testthat::test_file("tests/testthat/test-results-wrapper.R", reporter = "summary")
PASS: rmarkdown::render("vignettes/experiment-store.Rmd", output_format = "github_document", quiet = TRUE)
PASS: rmarkdown::render("vignettes/metrics-and-accounting.Rmd", output_format = "github_document", quiet = TRUE)
PASS: rmarkdown::render("vignettes/research-to-production.Rmd", output_format = "github_document", quiet = TRUE)
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
**Status:** Done

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
- [x] Pkgdown article order matches the v0.1.7.9 reader journey.
- [x] Homepage preserves the core product pitch while removing internal/stale
      material.
- [x] Public docs contain no local `C:\Users\` paths.
- [x] Public docs contain no stale `custom-indicators.md` visible link text.
- [x] Public docs contain no unintended stale version references.
- [x] `dplyr` usage is intentional and documented as example data preparation.
- [x] `Rprof.out` is absent from the repository and ignored going forward.
- [x] pkgdown builds after the polish pass.

**Implementation Notes:**
- Reordered the pkgdown article groups into Start Here, Core Workflow, and
  Design / Background, with `who-ledgr-is-for`, Getting Started, Leakage, and
  Reproducibility as the first reader path.
- Trimmed internal `system.file()` and versioned design-packet material from
  the README while preserving package help and vignette discovery.
- Sanitized rendered README and Getting Started temporary DuckDB paths to
  `<temporary DuckDB path>`.
- Removed stale `v0.1.7.2 helper layer` wording from background articles and
  softened the `auditr` reference to a planned companion package.
- Removed tracked `Rprof.out` and added profiling artifacts to `.gitignore`.
- Adjusted noninteractive reference examples that printed temporary local DB
  paths during pkgdown builds.

**Verification:**
```text
PASS: testthat::test_file("tests/testthat/test-documentation-contracts.R", reporter = "summary")
PASS: rmarkdown::render("README.Rmd", output_format = "github_document", quiet = TRUE)
PASS: rmarkdown::render("vignettes/getting-started.Rmd", output_format = "github_document", quiet = TRUE)
PASS: pkgdown::build_site(new_process = FALSE, install = TRUE)
PASS: git diff --check
PASS: source/rendered-doc grep found no `C:\Users`, `custom-indicators.md`,
      `v0.1.7.2 helper layer`, `current v0.1.7.6`, `no DISPLAY variable`, or
      reconciliation-overclaim text in README, vignettes, man, or R sources.
NOTE: pkgdown's generated markdown/LLM files use `.md` URLs for article links;
      the source and HTML visible text do not contain stale
      `custom-indicators.md` display text.
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

## LDG-1908: Opening-Position Lot Accounting And Shared FIFO Helper

**Priority:** P0
**Effort:** 1-2 days
**Dependencies:** LDG-1901
**Status:** Done

**Description:**
Fix the release-blocking execution-engine bug found in
`inst/design/execution_engine_audit.md`: opening positions created through
`ledgr_opening(positions = ..., cost_basis = ...)` are written as `CASHFLOW`
events, but the lot maps used by the runner, reconstruction, fill extraction,
and run-comparison stats only process `FILL` events. Liquidating an opening
position is therefore classified as an `OPEN`, produces no closed trade row, and
reports wrong realized/unrealized P&L and trade metrics.

This ticket must centralize FIFO lot accounting rather than patching the same
logic inline in every location.

**Tasks:**
1. Add regression tests that reproduce the bug with an opening long position at
   a nonzero cost basis and a later sale at a different price.
2. Add a shared internal lot-accounting helper that can:
   - seed opening lots from opening-position `CASHFLOW` event metadata;
   - apply ordinary `FILL` events using the existing FIFO semantics;
   - return realized P&L, open/close quantities, remaining lots, and remaining
     cost basis in a shape usable by the current result paths.
3. Replace or route all six existing FIFO paths through the shared helper:
   resume replay, live-loop accounting, post-run equity reconstruction,
   standalone derived-state reconstruction, extracted fill/trade derivation,
   and run-store comparison stats.
4. Ensure opening-position `CASHFLOW` events are interpreted only when their
   metadata identifies them as opening-position events with finite quantity and
   cost basis.
5. Preserve existing behavior for runs without opening positions.
6. Preserve the event ledger shape; do not convert opening positions into fake
   `FILL` events.
7. Confirm `ledgr_extract_fills()`, `ledgr_results(..., "trades")`,
   `ledgr_compute_metrics()`, run comparison stats, and reconstructed equity
   agree for the opening-position regression.
8. Update documentation only if the fix exposes a user-facing clarification
   about opening-position cost basis.

**Acceptance Criteria:**
- [x] Selling an opening long with cost basis below the sale price produces a
      `CLOSE` fill row with positive realized P&L.
- [x] The same scenario produces a closed trade row and correct `n_trades`,
      `win_rate`, and `avg_trade` in run comparison/metrics outputs.
- [x] Run comparison stats for the opening-position regression reflect correct
      realized P&L and trade counts.
- [x] Equity reconstruction reports realized and unrealized P&L against opening
      cost basis, not against zero.
- [x] `ledgr_state_reconstruct()` and the persisted equity curve agree for the
      regression scenario.
- [x] All six FIFO/lot-accounting paths use the shared helper or an explicitly
      documented common internal primitive.
- [x] Existing FIFO torture tests and accounting consistency tests still pass.
- [x] Opening-position events remain `CASHFLOW` events; no fake fill events are
      introduced.

**Implementation Notes:**
- Added `R/lot-accounting.R` as the shared FIFO lot-accounting primitive.
- Routed the runner resume replay, live-loop lot state, post-run equity
  reconstruction, standalone derived-state reconstruction, extracted
  fill/trade derivation, and run-store comparison stats through the shared
  helper.
- Seeded fresh-run live-loop lot state from normalized opening positions so the
  runner's in-loop accounting stays consistent with replay/reconstruction paths.
- Updated the live-loop event guard to accept `FILL` and `FILL_PARTIAL`, while
  preserving the prior no-row safety for DB-live writes.
- Opening-position `CASHFLOW` events now seed lots only when their metadata has
  `source = "opening_position"` plus finite `position_delta` and `cost_basis`.
- Added a regression in `test-experiment-run.R` covering extracted fills,
  trades, metrics, comparison stats, persisted equity P&L, and
  `ledgr_state_reconstruct()` for a sale of an opening long position.
- Opening-position events remain `CASHFLOW` events; the ledger shape is
  unchanged.

**Verification:**
```text
tests/testthat/test-experiment-run.R
tests/testthat/test-fifo-torture.R
tests/testthat/test-accounting-consistency.R
tests/testthat/test-derived-state.R
tests/testthat/test-run-compare.R
full testthat
```

Result: passed on Windows with one expected skip in the full suite
(`ledgr_snapshot_from_yahoo` missing-package path not exercised because
`quantmod` is installed). After review fixes, reran the same targeted tests and
full local test suite with the same result.

**Test Requirements:**
- Regression test for opening-position liquidation.
- Regression test for extracted fills/trades and metrics.
- Regression test for derived-state reconstruction.
- Existing FIFO/accounting/run-compare tests.

**Source Reference:** `inst/design/execution_engine_audit.md`; runner FIFO paths
in `R/backtest-runner.R`, `R/derived-state.R`, and `R/run-store.R`.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: H
review_tier: H
classification_reason: >
  This ticket changes execution-engine lot accounting, realized/unrealized P&L,
  fill action classification, and trade metrics for public opening-position
  workflows. It is release-blocking because the current behavior silently
  reports wrong accounting.
invariants_at_risk:
  - event-sourced accounting correctness
  - opening-position cost basis semantics
  - FIFO trade matching
  - fill/trade/metric consistency
  - resume determinism
required_context:
  - inst/design/execution_engine_audit.md
  - R/lot-accounting.R
  - R/backtest-runner.R
  - R/derived-state.R
  - R/run-store.R
  - R/backtest.R
  - tests/testthat/test-fifo-torture.R
  - tests/testthat/test-derived-state.R
  - tests/testthat/test-run-compare.R
tests_required:
  - targeted opening-position accounting regression tests
  - tests/testthat/test-fifo-torture.R
  - tests/testthat/test-accounting-consistency.R
  - tests/testthat/test-derived-state.R
  - tests/testthat/test-run-compare.R
escalation_triggers:
  - opening-position CASHFLOW metadata is insufficient to seed lots safely
  - shared helper cannot preserve existing FIFO behavior
  - resume replay and post-run reconstruction disagree after the fix
forbidden_actions:
  - adding a second execution path
  - converting opening positions into fake FILL events
  - silently dropping opening-position cost basis
  - patching only one FIFO path while leaving others divergent
```

---

## LDG-1909: Fill-Model Spread Semantics Documentation

**Priority:** P2
**Effort:** 0.5 day
**Dependencies:** LDG-1901
**Status:** Done

**Description:**
Document the existing `spread_bps` convention identified in
`inst/design/execution_engine_audit.md`. The current next-open fill model
applies `spread_bps` as a full per-leg price adjustment: buys fill at
`open * (1 + spread_bps / 10000)` and sells fill at
`open * (1 - spread_bps / 10000)`. A round trip therefore costs approximately
`2 * spread_bps` basis points of notional. The behavior is tested in code but
not explained clearly in public docs.

This ticket is documentation/contract clarification only. It must not change
fill prices or rename public fields.

**Tasks:**
1. Add clear public documentation for `spread_bps` in fill-model argument docs
   and any relevant vignette/accounting text.
2. State explicitly that `spread_bps` is a per-leg price adjustment, not a
   quoted bid/ask spread split across buy and sell legs.
3. Include a small numeric example or sentence explaining the round-trip effect.
4. Add or update documentation contract tests if a suitable public-doc contract
   already exists for fill-model wording.
5. Leave runtime fill-model behavior unchanged.

**Acceptance Criteria:**
- [x] Public docs explain that `spread_bps` is applied once on each fill leg.
- [x] Public docs explain that a buy/sell round trip costs approximately
      `2 * spread_bps` basis points before commissions.
- [x] Existing fill-model tests still pass with no behavior change.
- [x] No new fill-model parameter or rename is introduced.

**Implementation Notes:**
- Added per-leg `spread_bps` wording to `ledgr_backtest()` and
  `ledgr_experiment()` public argument docs and generated Rd files.
- Added metrics/accounting vignette text explaining that the adjustment is not
  split across bid/ask legs and that a round trip costs approximately
  `2 * spread_bps` basis points before fixed commissions.
- Added documentation-contract assertions for the fill-model wording.
- Left runtime fill-model behavior unchanged.

**Verification:**
```text
PASS: tests/testthat/test-fill-model.R
PASS: tests/testthat/test-documentation-contracts.R
PASS: rendered vignettes/metrics-and-accounting.Rmd to github_document
```

**Test Requirements:**
- Existing fill-model tests.
- Documentation contract tests if wording is pinned.

**Source Reference:** `inst/design/execution_engine_audit.md`; `R/fill-model.R`.

**Classification:**
```yaml
risk_level: medium
implementation_tier: L
review_tier: M
classification_reason: >
  This ticket documents an existing execution-cost convention. The primary risk
  is public misunderstanding; runtime behavior must not change.
invariants_at_risk:
  - fill-model contract clarity
  - public documentation accuracy
required_context:
  - inst/design/execution_engine_audit.md
  - R/fill-model.R
  - R/backtest.R
  - vignettes/metrics-and-accounting.Rmd
  - man/ledgr_backtest.Rd
tests_required:
  - tests/testthat/test-fill-model.R
  - tests/testthat/test-documentation-contracts.R
escalation_triggers:
  - docs reveal disagreement between tests and implementation
  - maintainer chooses to change semantics instead of documenting current behavior
forbidden_actions:
  - changing fill prices
  - renaming spread_bps
  - adding a new fill-model API
```

---

## LDG-1910: Execution Engine Audit Cleanup And Minor Finding Routing

**Priority:** P2
**Effort:** 0.5-1 day
**Dependencies:** LDG-1901
**Status:** Done

**Description:**
Address the non-blocking execution-engine audit cleanup that is safe inside
v0.1.7.9 and explicitly route the remaining minor findings. The main cleanup is
removing six live equity arrays in `R/backtest-runner.R` that are updated on
every pulse but never read because the equity curve is reconstructed from the
persisted ledger after the run.

This ticket must stay narrow. It must not change execution semantics except for
adding a defensive validation guard if the lower-level opening-position config
gap is confirmed reachable.

**Tasks:**
1. Remove the unused `eq_ts`, `eq_cash`, `eq_positions_value`, `eq_equity`,
   `eq_realized`, and `eq_unrealized` arrays if tests confirm they are dead.
2. Confirm no downstream code reads those arrays or depends on their side
   effects.
3. Review the lower-level opening-position universe validation gap below
   `ledgr_experiment()` and either:
   - add a small defensive runner/config validation if reachable through public
     APIs; or
   - record why it remains internal-only and already protected by public
     experiment validation.
4. Record decisions for the RNG side effect and
   `commission_fixed > qty * fill_price` SELL cash-delta behavior. Do not change
   either behavior without a separate maintainer decision.
5. Confirm the pending-buffer `>` guard remains unchanged because the audit
   false positive has been corrected.

**Acceptance Criteria:**
- [x] Dead live equity arrays are removed or a specific reason for retaining
      them is recorded.
- [x] Targeted runner/accounting tests still pass after the cleanup.
- [x] The lower-level opening-position universe validation gap is either closed
      with a defensive check or explicitly routed as internal-only.
- [x] RNG side-effect and negative SELL cash-delta findings are recorded as
      deferred/design-decision items unless separately promoted.
- [x] The pending-buffer guard is not changed to `>=`.

**Implementation Notes:**
- Removed the unused live equity vectors and the live-loop lot-accounting work
  that only fed those vectors. The authoritative equity output remains the
  post-run ledger reconstruction.
- Added a defensive `validate_ledgr_config()` guard so low-level
  `ledgr_backtest_run()` configs reject `opening.positions` instruments outside
  `universe.instrument_ids`.
- Recorded LDG-1910 routing in `execution_engine_audit.md`: RNG global-state
  behavior is deferred to v0.1.8 stochastic/sweep design; negative SELL
  cash-delta behavior requires a post-v0.1.7.9 follow-up or explicit WONTFIX at
  the release gate; and the pending-buffer `>` guard remains unchanged.

**Verification:**
```text
PASS: tests/testthat/test-runner.R
PASS: tests/testthat/test-accounting-consistency.R
PASS: tests/testthat/test-config.R
PASS: tests/testthat/test-experiment-run.R
PASS: tests/testthat/test-derived-state.R
PASS: tests/testthat/test-run-compare.R
PASS: scope grep found no eq_ts, eq_cash, eq_positions_value, eq_equity,
      eq_realized, eq_unrealized, total_pulses_len, or existing_events_all in
      R/backtest-runner.R
PASS: scope grep confirmed pending_idx uses `>` and not `>=`
PASS: execution-engine audit records deferred RNG and SELL cash-delta decisions
```

**Test Requirements:**
- Targeted runner/accounting tests.
- Scope grep for dead arrays.

**Source Reference:** `inst/design/execution_engine_audit.md`; live equity
buffer code in `R/backtest-runner.R`.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: M
classification_reason: >
  This ticket removes dead runner work and routes minor audit findings without
  changing core execution behavior. The risk is accidental behavior drift in the
  runner during cleanup.
invariants_at_risk:
  - runner accounting behavior
  - release-scope discipline
  - internal/public API boundary
required_context:
  - inst/design/execution_engine_audit.md
  - R/backtest-runner.R
  - R/backtest.R
  - R/experiment.R
  - tests/testthat/test-runner.R
  - tests/testthat/test-accounting-consistency.R
tests_required:
  - targeted runner/accounting tests
escalation_triggers:
  - equity arrays are discovered to feed a hidden side effect
  - lower-level validation gap is reachable through a supported public API
  - RNG behavior change is required to satisfy tests
forbidden_actions:
  - changing fill timing
  - changing RNG semantics without a separate decision
  - changing commission semantics without a separate decision
  - changing the pending-buffer guard to >=
```

---

## LDG-1911: Opening-Position FIFO Edge-Case Test Coverage

**Priority:** P1
**Effort:** 1 day
**Dependencies:** LDG-1908
**Status:** Done

**Description:**
The existing opening-position test (`test-experiment-run.R:158`) covers only the
simplest scenario: a single instrument, single lot, fee=0, no resume, `audit_log`
mode. LDG-1908 introduced `ledgr_lot_accounting()` and seeded all six FIFO paths;
this ticket adds the edge-case scenarios that exercise those paths under realistic
conditions. These tests ensure the fix holds under resume, accumulation,
multi-instrument isolation, non-zero fees, position flips, and `db_live` mode.

**Tasks:**
1. Add test: resume after partial opening-position liquidation.
   - Fresh run, open 100 shares of AAA at cost_basis=50. Sell 40 shares (close).
   - Resume from that checkpoint. Sell remaining 60 shares (close).
   - Verify: resumed run's fills and equity_curve have correct realized P&L for the
     second partial close; lot map is empty at end; no cost-basis double-count.
2. Add test: opening position + subsequent accumulation before liquidation.
   - Open 50 shares at cost_basis=40 via opening_positions.
   - Strategy buys 50 more shares at market (FILL event, price=60).
   - Strategy then sells all 100 shares (FIFO: opening lot first at cost=40, then
     accumulated lot at cost=60).
   - Verify: two separate realized P&L amounts are correct; FIFO lot ordering is
     preserved (opening lot drains before accumulated lot).
3. Add test: multi-instrument opening positions with independent lot isolation.
   - Opening positions: AAA=100 shares at cost_basis=50, BBB=200 shares at cost_basis=30.
   - Both instruments close out; strategy does nothing additional.
   - Verify: AAA realized P&L is computed from cost 50, BBB from cost 30;
     no cross-instrument lot contamination.
4. Add test: non-zero fee with opening position.
   - Open 100 shares at cost_basis=50; close all shares, fee=5.
   - Verify: `fills$realized_pnl` is pre-fee gross (realized_close);
     `equity_curve$realized_pnl` cumulates post-fee (realized_close - fee);
     trade metrics are consistent with the post-fee convention.
5. Add test: position flip originating from an opening position.
   - Open 100 shares at cost_basis=50. Strategy issues a sell-250 signal.
   - Expected: closes the 100-share opening lot (FIFO), opens a 150-share short.
   - Verify: realized P&L from the close is correct; lot map contains the short lot
     with correct cost basis; no phantom opening-position residual.
6. Add test: `db_live` execution mode with opening positions.
   - Re-run the base opening-position scenario (`test-experiment-run.R:158`) with
     `mode = "db_live"`.
   - Verify: fills, equity_curve, and `ledgr_state_reconstruct()` output are
     identical to the `audit_log` mode result.

**Acceptance Criteria:**
- [x] All six test scenarios are implemented and pass.
- [x] Resume scenario confirms no cost-basis double-count at the checkpoint boundary.
- [x] Accumulation scenario confirms FIFO lot ordering: opening lot drains before accumulated lot.
- [x] Multi-instrument scenario confirms lot isolation: no cross-instrument contamination.
- [x] Fee scenario confirms `fills$realized_pnl` is pre-fee gross and
      `equity_curve$realized_pnl` is post-fee cumulative.
- [x] Position-flip scenario confirms a single sell closes the opening lot and
      seeds the resulting short lot correctly.
- [x] `db_live` scenario output matches `audit_log` mode output exactly.
- [x] No regressions in the existing test suite.

**Implementation Notes:**
- All tests live in `tests/testthat/test-fifo-opening-positions.R` (new file).
- Scenario 1 (resume) must exercise the resume replay path
  (`backtest-runner.R:~1215`), not just the fresh-run seeding block.
- Scenario 2 (accumulation) verifies FIFO ordering when both an opening-position lot
  and an ordinary-fill lot coexist; opening lot must drain first.
- Scenario 5 (position flip) specifically exercises the close/open split for a
  single sell that closes an opening lot and seeds the resulting short lot.
- Scenario 6 (`db_live`) confirms consistency across execution modes; the two paths
  that diverge by mode are the live-loop and the post-run reconstruction.
- Fee convention: `fills$realized_pnl = realized_close` (pre-fee gross);
  `equity_curve$realized_pnl = cumsum(realized_close - fee)` (post-fee);
  trade metrics currently aggregate the gross closed-trade P&L. This is a
  pre-existing convention, not introduced by LDG-1908; scenario 4 verifies it
  holds with opening positions.
- Added `tests/testthat/test-fifo-opening-positions.R` with six scenarios:
  resume after partial opening-position liquidation, accumulation before
  liquidation, multi-instrument isolation, non-zero fees, position flip into a
  short lot, and `db_live` / `audit_log` parity.
- Targeted verification passed:
  `testthat::test_file('tests/testthat/test-fifo-opening-positions.R',
  reporter='summary')`.

**Verification:**
```text
targeted opening-position FIFO tests
full testthat (regression guard)
```

**Test Requirements:**
- `tests/testthat/test-fifo-opening-positions.R`: all six scenarios.
- Full test suite for regression guard.

**Source Reference:** LDG-1908 implementation; `tests/testthat/test-experiment-run.R:158`
(base scenario); v0.1.7.9 spec §7.1.

**Classification:**
```yaml
risk_level: low
implementation_tier: L
review_tier: M
classification_reason: >
  Pure test addition. No production code changes. The risk is tests that do not
  actually exercise the intended paths, providing false confidence in the LDG-1908 fix.
invariants_at_risk:
  - opening-position accounting correctness
  - FIFO lot ordering under accumulation
  - resume checkpoint correctness
  - fee/P&L convention consistency
required_context:
  - R/lot-accounting.R
  - R/backtest-runner.R
  - R/derived-state.R
  - R/run-store.R
  - R/backtest.R
  - tests/testthat/test-experiment-run.R
  - tests/testthat/test-fifo-torture.R
  - tests/testthat/test-accounting-consistency.R
tests_required:
  - tests/testthat/test-fifo-opening-positions.R
  - full testthat
escalation_triggers:
  - a scenario reveals a remaining bug in the LDG-1908 paths
  - resume checkpoint seeding is found to be incorrect
  - db_live and audit_log produce different results for opening positions
forbidden_actions:
  - changing production code (tests only)
  - skipping the resume scenario
  - using fee=0 for scenario 4
```

---

## LDG-1907: v0.1.7.9 Release Gate, NEWS, And Packet Finalization

**Priority:** P0
**Effort:** 1 day
**Dependencies:** LDG-1902, LDG-1903, LDG-1904, LDG-1905, LDG-1906, LDG-1908, LDG-1909, LDG-1910, LDG-1911
**Status:** Done

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
6. Confirm execution-engine audit findings are fixed, documented, or explicitly
   routed, including the opening-position cost-basis blocker.
7. Run targeted tests for changed code.
8. Run documentation contract tests.
9. Run full local tests.
10. Run package check and pkgdown build.
11. Confirm generated artifacts are not committed.

**Acceptance Criteria:**
- [x] All prior v0.1.7.9 tickets are complete or explicitly deferred.
- [x] NEWS and version metadata match the shipped scope.
- [x] `v0_1_7_9_tickets.md` and `tickets.yml` are synchronized.
- [x] Opening-position lot accounting regressions pass.
- [x] Documentation contract tests pass.
- [x] Full local tests pass.
- [x] `R CMD check --no-manual --no-build-vignettes` passes.
- [x] pkgdown builds.
- [x] No generated artifacts are committed.
- [x] Ubuntu and Windows CI are green.

**Implementation Notes:**
- Bumped `DESCRIPTION` to `0.1.7.9`.
- Added the v0.1.7.9 `NEWS.md` entry covering feature-contract checks,
  strategy-author docs/UX polish, public-site cleanup, opening-position FIFO
  accounting, spread semantics documentation, and execution-engine audit
  routing.
- Kept all deferred v0.1.8+ scope deferred: sweep mode, feature precompute,
  `ctx$all_features()`, persisted feature retrieval, and
  `ledgr_snapshot_split()`.
- Confirmed execution-engine audit findings are fixed, documented, or routed:
  opening-position cost basis and FIFO edge cases are covered by LDG-1908 and
  LDG-1911; spread semantics by LDG-1909; dead arrays and minor audit routing by
  LDG-1910; future cost-policy questions by the roadmap/RFC response.
- Adjusted two source-tree documentation-contract checks so installed-package
  `R CMD check` skips them when `_pkgdown.yml` or source `man/` files are not
  available in the check tree.
- Branch, main, and tag CI are green on Ubuntu and Windows.

**Verification:**
```text
PASS targeted opening-position tests:
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-fifo-opening-positions.R', reporter='summary')"

PASS documentation contract tests:
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-documentation-contracts.R', reporter='summary')"

PASS full local testthat:
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" -e "pkgload::load_all('.', quiet=TRUE); testthat::test_local('.', reporter='summary')"

PASS package build:
$env:RSTUDIO_PANDOC='C:\Program Files\RStudio\resources\app\bin\quarto\bin\tools'; & "C:\Program Files\R\R-4.5.2\bin\x64\R.exe" CMD build .

PASS R CMD check:
& "C:\Program Files\R\R-4.5.2\bin\x64\R.exe" CMD check --no-manual --no-build-vignettes ledgr_0.1.7.9.tar.gz

PASS pkgdown build:
$env:RSTUDIO_PANDOC='C:\Program Files\RStudio\resources\app\bin\quarto\bin\tools'; & "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" -e ".libPaths(c(normalizePath('lib', winslash='/'), .libPaths())); pkgdown::build_site(new_process = FALSE, install = TRUE)"

PASS branch CI:
GitHub Actions R-CMD-check run 25722219193 passed on
`v0.1.7.9` before merge.

PASS main CI:
GitHub Actions R-CMD-check run 25723836818 passed on `main`.
GitHub Actions pkgdown run 25723836828 passed on `main` and deployed Pages.

PASS tag CI:
GitHub Actions R-CMD-check run 25724929625 passed for tag `v0.1.7.9`.
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
