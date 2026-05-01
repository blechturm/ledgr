# ledgr v0.1.7.1 Installed UX Stabilisation Tickets

**Version:** 0.1.0  
**Date:** April 30, 2026  
**Total Tickets:** 7  
**Estimated Duration:** 1-2 weeks

---

## Ticket Organization

v0.1.7.1 is a patch release for the v0.1.7 experiment-first API. The ticket
range starts at `LDG-1101` to avoid collisions with the v0.1.7 cycle.

Under `inst/design/model_routing.md`, ticket classification and release scoping
are Tier H work. The only planned executable bug fix is the MACD warmup
investigation. Documentation work is mostly Tier M implementation with Tier H
review where it teaches public workflow, strategy semantics, persistence, or
new helper behavior.

### Dependency DAG

```text
LDG-1101 -> LDG-1102 -> LDG-1104 -> LDG-1107
LDG-1101 -> LDG-1103 -> LDG-1104 -> LDG-1107
LDG-1101 -> LDG-1105 -------------> LDG-1107
LDG-1101 -> LDG-1106 -------------> LDG-1107
LDG-1101 --------------------------> LDG-1107
```

`LDG-1107` is the v0.1.7.1 release gate.

### Priority Levels

- **P0 (Blocker):** Required for correctness or release coherence.
- **P1 (Critical):** Required for the installed-package user story to work.
- **P2 (Important):** Required for discoverability or documentation quality.
- **P3 (Optional):** Useful, but not a release blocker.

---

## LDG-1101: Patch Scope, Version, And Documentation Standard

**Priority:** P0  
**Effort:** 0.5-1 day  
**Dependencies:** None  
**Status:** Done

**Description:**
Lock the v0.1.7.1 patch boundary before implementation begins. This ticket
aligns version metadata, NEWS, roadmap, package documentation standards, and
the explicit non-goal boundary so later tickets do not drift into another API
reset.

**Tasks:**
1. Update `DESCRIPTION` to `Version: 0.1.7.1`.
2. Add a `# ledgr 0.1.7.1` section to `NEWS.md` with placeholder bullets for:
   - installed documentation and offline examples;
   - modern example style and UTC date ergonomics;
   - MACD warmup investigation/fix;
   - strategy, feature-ID, warmup, run comparison, and snapshot lifecycle docs.
3. Update `inst/design/ledgr_roadmap.md` to record v0.1.7.1 as a focused
   installed UX and MACD warmup stabilisation patch.
4. Keep `inst/design/ledgr_v0_1_7_1_spec_packet/v0_1_7_1_spec.md` as the
   source of truth for this patch cycle.
5. Add or update a documentation-standard note in the relevant design contract
   or UX decision document:
   - README and narrative vignettes use the base pipe `|>`;
   - narrative examples use `filter()` / `between()` instead of `subset()`;
   - examples avoid raw `as.POSIXct(..., tz = "UTC")` boilerplate where a
     package helper or clearer local pattern is available;
   - Windows-facing examples avoid unsafe `$` shell one-liners.
6. Confirm no `ledgr_sweep()`, `ledgr_tune()`, or
   `ledgr_precompute_features()` APIs are exported or implied for v0.1.7.1.
7. Confirm v0.1.7 breaking-change messaging remains intact.

**Acceptance Criteria:**
- [ ] Version metadata, NEWS, spec, roadmap, and tickets agree on v0.1.7.1.
- [ ] The patch scope is explicitly documentation, example, UX, and MACD
      warmup stabilisation.
- [ ] The documentation example style is recorded before doc rewrites begin.
- [ ] The non-goal boundary excludes sweep/tune, broker/live, shorting, schema
      migrations, and portfolio optimizer APIs.
- [ ] No compatibility shim or second public workflow is introduced.

**Test Requirements:**
- Version consistency scan.
- Export/API inventory scan for sweep/tune non-goals.
- Documentation consistency scan.

**Source Reference:** v0.1.7.1 spec sections 0, 2, 4, 6.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: H
review_tier: H
classification_reason: >
  Version scoping, ticket generation, compatibility posture, documentation
  standard setting, and release boundary definition are Tier H by rule.
invariants_at_risk:
  - release scope
  - public API compatibility policy
  - documentation contract
  - non-goal boundary
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_1_spec_packet/v0_1_7_1_spec.md
  - inst/design/ledgr_v0_1_7_1_spec_packet/ledgr_triage_report.md
  - inst/design/ledgr_v0_1_7_spec_packet/v0_1_7_spec.md
  - inst/design/contracts.md
  - inst/design/ledgr_ux_decisions.md
  - inst/design/ledgr_roadmap.md
  - DESCRIPTION
  - NEWS.md
tests_required:
  - version consistency scan
  - export/API inventory scan
  - documentation consistency scan
escalation_triggers:
  - a new public helper becomes more than documentation ergonomics
  - a schema migration appears necessary
  - sweep/tune scope leaks into the patch release
  - v0.1.7 breaking-change policy needs revision
forbidden_actions:
  - adding sweep/tune APIs
  - adding broker/live integrations
  - changing execution semantics
  - weakening the experiment-first workflow
```

---

## LDG-1102: MACD Warmup Regression

**Priority:** P0  
**Effort:** 1-2 days  
**Dependencies:** LDG-1101  
**Status:** Done

**Description:**
Reproduce and resolve the audit-reported MACD warmup failure where
`ledgr_ind_ttr("MACD", output = "macd", nFast = 12, nSlow = 26, nSig = 9,
percent = FALSE)` constructs with `requires_bars = 26` but feature computation
appears to require 34 bars.

**Tasks:**
1. Add a failing regression test for the exact audit case before changing the
   implementation.
2. Compare `ledgr_ind_ttr()` output against direct `TTR::MACD()` output for:
   - `output = "macd"`, `percent = TRUE`;
   - `output = "macd"`, `percent = FALSE`;
   - `output = "signal"`, `percent = TRUE`;
   - `output = "signal"`, `percent = FALSE`;
   - `output = "histogram"`, `percent = TRUE`;
   - `output = "histogram"`, `percent = FALSE`.
3. Determine whether the warmup difference is caused by `percent`, output
   selection, TTR version behavior, or ledgr normalization.
4. Update `R/indicator-ttr.R` so the warmup rules table and inference logic
   remain synchronized.
5. Extend TTR warmup verification tests so every MACD output/percent case that
   ledgr supports is checked against actual TTR output.
6. If the audit case is not reproducible, document the tested TTR version and
   the observed direct-output warmup in the test comments and release notes.
7. Update relevant docs if the documented MACD warmup changes.

**Acceptance Criteria:**
- [ ] The audit MACD case is covered by a targeted test.
- [ ] Direct TTR output and ledgr inferred warmup agree for supported MACD
      output/percent combinations.
- [ ] `ledgr_ttr_warmup_rules()` and `ledgr_ttr_infer_requires_bars()` cannot
      drift silently for MACD.
- [ ] Existing TTR indicator tests continue to pass.
- [ ] Any changed MACD behavior is documented in NEWS and indicator docs.

**Test Requirements:**
- Targeted MACD regression test.
- Direct TTR warmup verification test for MACD cases.
- Full `tests/testthat/test-indicator-ttr.R`.
- Feature computation smoke test using the MACD audit case.

**Source Reference:** v0.1.7.1 spec section 2 R7, section 3.3;
triage THEME-009.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  TTR warmup inference affects feature computation readiness, indicator
  metadata, strategy behavior, and reproducibility expectations. The work
  touches a known invariant-sensitive area and must be implemented and reviewed
  at Tier H.
invariants_at_risk:
  - indicator warmup correctness
  - TTR adapter contract
  - feature computation readiness
  - strategy behavior on early bars
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_1_spec_packet/v0_1_7_1_spec.md
  - inst/design/ledgr_v0_1_7_1_spec_packet/ledgr_triage_report.md
  - inst/design/contracts.md (Indicator Contract, series_fn contract)
  - R/indicator-ttr.R
  - R/features-engine.R
  - tests/testthat/test-indicator-ttr.R
  - vignettes/ttr-indicators.Rmd
tests_required:
  - targeted MACD regression test
  - direct TTR output warmup verification
  - existing indicator-ttr test suite
  - feature computation smoke test
escalation_triggers:
  - the defect is in shared feature normalization rather than MACD rules
  - fixing MACD changes indicator fingerprint identity
  - TTR behavior differs by installed TTR version in a non-deterministic way
  - a broader warmup-table redesign seems necessary
forbidden_actions:
  - weakening deterministic warmup inclusion rules
  - adding heuristic warmup inference
  - changing unrelated TTR indicators
  - changing feature engine semantics without escalation
```

---

## LDG-1103: Date/Time Ergonomics And Modern Example Style

**Priority:** P1  
**Effort:** 1-2 days  
**Dependencies:** LDG-1101  
**Status:** Done

**Description:**
Make the first examples look like modern applied R and remove distracting UTC
date boilerplate from user-facing workflows. This ticket evaluates and, if
accepted, adds a small `ledgr_utc()` helper, then updates README and narrative
examples to use base pipe style with `filter()` / `between()`.

**Tasks:**
1. Audit README and narrative vignettes for:
   - `subset()`;
   - raw `as.POSIXct("...", tz = "UTC")` filters;
   - unnecessary `as_tibble()` around objects that are already tibble-like;
   - magrittr `%>%` in new v0.1.7.1 examples.
2. Confirm whether `ledgr_demo_bars` is a tibble. If not, make the shipped data
   tibble-like without changing its required columns or values.
3. Implement `ledgr_utc(x)` if the helper remains the cleanest solution:
   - accepts character scalar/vector date or datetime strings;
   - returns POSIXct in UTC;
   - uses base R unless there is an explicitly reviewed dependency reason;
   - fails with a classed error on unparseable inputs;
   - does not change stored timestamp semantics.
4. Document `ledgr_utc()` if added, including date-only and datetime examples.
5. Update README and narrative vignette code to prefer:
   - `library(ledgr)`;
   - `library(dplyr)` and `library(tibble)` where helpful;
   - base pipe `|>`;
   - `filter()` and `between()`;
   - `slice_head()` or similar readable tibble operations.
6. Keep package code and compact Rd examples namespaced where that is clearer.
7. Update `_pkgdown.yml` if a new helper needs a reference entry.
8. Add tests for `ledgr_utc()` if implemented.

**Acceptance Criteria:**
- [ ] README first data-preparation example uses base pipe, `filter()`, and
      `between()`.
- [ ] User-facing examples no longer teach `subset()` as the main style.
- [ ] Raw `as.POSIXct(..., tz = "UTC")` boilerplate is removed from the main
      narrative path or explicitly justified.
- [ ] `ledgr_demo_bars` is presented and usable as a tibble-like object.
- [ ] `ledgr_utc()` exists, is tested, and is documented if the ticket chooses
      to add it.
- [ ] No new heavy dependency is added without review.

**Test Requirements:**
- Unit tests for `ledgr_utc()` if implemented.
- Data-shape test for `ledgr_demo_bars` tibble compatibility.
- README render.
- Vignette render for changed narrative docs.
- Pattern scan for `subset(` in main README/narrative examples.

**Source Reference:** v0.1.7.1 spec section 2 R12 and section 3.1.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: H
classification_reason: >
  The work is mostly documentation and a contained utility helper, but the
  helper would be exported public API and timestamp handling is user-visible.
  Implementation is Tier M with Tier H review.
invariants_at_risk:
  - timestamp interpretation
  - public helper API
  - example readability
  - package dependency footprint
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_1_spec_packet/v0_1_7_1_spec.md
  - inst/design/ledgr_ux_decisions.md
  - README.Rmd
  - vignettes/getting-started.Rmd
  - vignettes/strategy-development.Rmd
  - vignettes/experiment-store.Rmd
  - data/ledgr_demo_bars.rda
  - DESCRIPTION
  - NAMESPACE
tests_required:
  - ledgr_utc tests if helper is implemented
  - ledgr_demo_bars tibble compatibility test
  - README render
  - changed vignette render
escalation_triggers:
  - lubridate or another new dependency seems necessary
  - helper semantics need time zones other than UTC
  - shipped demo data values must change
  - docs require changing snapshot/bar schema
forbidden_actions:
  - changing stored timestamp semantics
  - adding lubridate as Imports without review
  - replacing base pipe with magrittr in the new canonical examples
  - making demo data depend on network access
```

---

## LDG-1104: Strategy, Feature ID, Warmup, And Sizing Documentation

**Priority:** P1  
**Effort:** 2-3 days  
**Dependencies:** LDG-1102, LDG-1103  
**Status:** Done

**Description:**
Close the installed-documentation gaps that block ordinary strategy
development. The strategy-development and TTR indicator docs must explain
`ctx`, `params`, feature IDs, warmup, target vectors, and current sizing
semantics without requiring design-doc context.

**Tasks:**
1. Update `vignettes/strategy-development.Rmd` so it teaches:
   - `function(ctx, params)` as the only v0.1.7 strategy contract;
   - what `ctx` is and which accessors matter in ordinary strategies;
   - how `params` is supplied by `ledgr_run()`;
   - `ctx$flat()` versus `ctx$hold()`;
   - `ctx$feature()` and unknown-feature errors;
   - warmup `NA` handling with `is.na()`;
   - multi-asset target-vector patterns using current quantity targets.
2. Update `vignettes/ttr-indicators.Rmd` so feature IDs are taught before
   strategy code:
   - built-in indicator ID examples;
   - TTR indicator ID examples;
   - `ledgr_feature_id()` for a single indicator and list;
   - SMA, RSI, momentum, Bollinger Bands, and MACD examples.
3. Document warmup concepts in narrative form:
   - `requires_bars`;
   - `stable_after`;
   - early `NA` values;
   - short-history no-trade pattern;
   - insufficient-history failure pattern.
4. Add a simple allocation/sizing example using current share/quantity target
   vectors. Do not introduce weight-based APIs.
5. Update relevant Rd examples for strategy functions and indicator
   constructors where needed.
6. Update `inst/design/contracts.md` only for clarification of existing
   strategy, context, indicator, or long-only target semantics.
7. Render changed vignettes and generated markdown.

**Acceptance Criteria:**
- [ ] A user can learn `ctx` and `params` from installed documentation.
- [ ] Docs show `function(ctx, params)` access to `params` and do not teach
      `ctx$params`.
- [ ] Feature IDs are discoverable and shown before strategy use.
- [ ] Warmup `NA` behavior is distinct from unknown feature ID errors.
- [ ] At least one short-history guarded strategy example exists.
- [ ] Current target-vector sizing semantics are documented without adding new
      sizing APIs.
- [ ] TTR MACD documentation matches the LDG-1102 outcome.

**Test Requirements:**
- Render changed vignettes.
- Run code chunks for strategy and TTR docs where practical.
- Documentation scan for `ctx$params`.
- Documentation scan for old target helper names as recommended usage.
- Existing strategy, feature ID, and indicator tests.

**Source Reference:** v0.1.7.1 spec sections 2 R5, R6, R8; triage
THEME-003, THEME-004, THEME-006, THEME-009.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: H
classification_reason: >
  The ticket is documentation-heavy, but it teaches the public strategy
  contract, context semantics, indicator IDs, warmup behavior, and target-vector
  sizing. These are user-facing execution concepts and need Tier H review.
invariants_at_risk:
  - strategy contract comprehension
  - context helper semantics
  - indicator ID discoverability
  - warmup behavior expectations
  - long-only target-vector semantics
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_1_spec_packet/v0_1_7_1_spec.md
  - inst/design/ledgr_v0_1_7_1_spec_packet/ledgr_triage_report.md
  - inst/design/contracts.md (Strategy Contract, Context Contract, Indicator Contract)
  - vignettes/strategy-development.Rmd
  - vignettes/ttr-indicators.Rmd
  - R/pulse-context.R
  - R/indicator.R
  - R/indicator-ttr.R
tests_required:
  - changed vignette render
  - strategy documentation code chunks
  - TTR documentation code chunks
  - documentation scans for ctx$params and old helper names
escalation_triggers:
  - docs reveal a missing helper that seems necessary for v0.1.7.1
  - target-vector semantics are unclear or inconsistent with implementation
  - warmup behavior differs from the LDG-1102 tests
  - a weight-based allocation API seems necessary
forbidden_actions:
  - adding ctx$params
  - adding target-weight or optimizer APIs
  - teaching old target helpers as current usage
  - adding runtime feature-ID lookup as the default strategy style
```

---

## LDG-1105: Experiment Store, Run Comparison, And Snapshot Lifecycle Docs

**Priority:** P2  
**Effort:** 1-2 days  
**Dependencies:** LDG-1101  
**Status:** Done

**Description:**
Clarify the experiment-store and snapshot lifecycle documentation so installed
users understand durable run management, run comparison semantics, labels/tags,
and high-level versus low-level snapshot CSV flows.

**Tasks:**
1. Update `vignettes/experiment-store.Rmd` so it clearly explains:
   - `ledgr_run_list(snapshot)`;
   - `ledgr_run_info(snapshot, run_id)`;
   - `ledgr_run_open(snapshot, run_id)`;
   - `ledgr_compare_runs(snapshot, run_ids = ...)`;
   - labels, archive, tags, and `ledgr_run_tags()`;
   - what mutates metadata and what never changes run identity.
2. Document comparison metric semantics:
   - `n_trades` counts closed/realised trades;
   - `win_rate` is based on realised closed-trade observations;
   - fills and closed trades are different concepts.
3. Rewrite narrative run-list and comparison examples to demonstrate curated
   defaults directly:
   - use `ledgr_run_list(snapshot)` as the main discovery demo;
   - use `ledgr_compare_runs(snapshot, run_ids = ...)` as the main comparison
     demo;
   - do not use base `[` column slicing to make the main output readable;
   - if full-column access is needed, show it as an explicit "dig deeper"
     pattern with `as_tibble()` and `select()`.
4. Add examples showing tag/label filtering with ordinary tibble/dplyr
   operations, without adding new filter arguments.
5. Rework the reopen section so it is framed as "inspect a completed run after
   the fact" or "resume in a new session", not as part of the ordinary result
   path.
6. Clarify cleanup semantics:
   - `ledgr_run()` and `ledgr_run_open()` return handles that may own DuckDB
     resources while live;
   - durable handles have a finalizer safety net;
   - `close(bt)` remains deterministic resource cleanup for scripts, tests, and
     long sessions;
   - `ledgr_snapshot_close(snapshot)` releases the snapshot handle when the
     workflow is finished.
7. Ensure the first vignette use of `close(bt)` is preceded by a plain-language
   explanation of why the handle should be closed.
8. Update getting-started or README where needed so run discovery/comparison
   is visible from the first workflow.
9. Update snapshot CSV docs to distinguish:
   - high-level `ledgr_snapshot_from_*()` helpers;
   - low-level adapter/import flows;
   - auto-seal and reseal behavior;
   - metadata population and manual low-level obligations.
10. Add a clear market-data versus derived-data mental model:
    - sealed snapshots freeze real market data and its hash;
    - users do not append more instruments, dates, corrections, or tick data to
      an already sealed snapshot;
    - those changes create a new snapshot;
    - indicators/features are derived data and can be recomputed against sealed
      snapshots through new experiments or runs;
    - feature computation must not mutate the sealed market-data artifact.
11. Avoid unsafe Windows shell one-liners in command-line examples.
12. Render changed vignettes and generated markdown.

**Acceptance Criteria:**
- [ ] Installed docs explain how to list, inspect, reopen, compare, label,
      archive, and tag runs.
- [ ] Main `ledgr_run_list()` and `ledgr_compare_runs()` demos show curated
      defaults directly, without base `[` column slicing.
- [ ] Full-column access is shown only as an explicit tibble-compatible
      "dig deeper" pattern.
- [ ] Comparison metric semantics are documented clearly.
- [ ] Tag/label examples use existing APIs and tibble operations only.
- [ ] Reopen examples explain no-recompute inspection and deterministic cleanup
      without making `close()` feel like the primary workflow.
- [ ] The first `close(bt)` example explains that live run handles may own
      DuckDB resources and close is deterministic cleanup.
- [ ] Snapshot CSV lifecycle docs separate high-level and low-level workflows.
- [ ] Docs explain that sealed snapshots freeze market data while indicators
      are derived data that can be added/recomputed through new runs.
- [ ] No new experiment-store schema or query DSL is introduced.
- [ ] Windows-facing examples avoid fragile `$` shell quoting.

**Test Requirements:**
- Render changed vignettes.
- Run relevant experiment-store code chunks where practical.
- Documentation scan for `ledgr_run_list("path.duckdb")` in current workflow
  examples.
- Documentation scan for base `[` column slicing immediately after
  `ledgr_run_list()` or `ledgr_compare_runs()` in narrative examples.
- Documentation scan for unsafe shell examples containing `$`.
- Existing run-store and comparison tests.

**Source Reference:** v0.1.7.1 spec sections 2 R9, R10, R11; triage
THEME-001, THEME-002, THEME-007, THEME-008.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: H
classification_reason: >
  The ticket is documentation-heavy, but it teaches persistence, run identity,
  snapshot lifecycle, and comparison semantics. These are contract-sensitive
  public concepts and need Tier H review.
invariants_at_risk:
  - experiment-store mental model
  - run identity immutability
  - comparison metric interpretation
  - snapshot lifecycle expectations
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_1_spec_packet/v0_1_7_1_spec.md
  - inst/design/ledgr_v0_1_7_1_spec_packet/ledgr_triage_report.md
  - inst/design/contracts.md (Persistence Contract, Run Identity Contract, Snapshot Contract, Result Contract)
  - vignettes/experiment-store.Rmd
  - vignettes/getting-started.Rmd
  - README.Rmd
  - R/run-store.R
  - R/snapshots-list.R
tests_required:
  - changed vignette render
  - experiment-store documentation chunks
  - current-workflow documentation scan
  - curated-print documentation scan
  - unsafe-shell documentation scan
escalation_triggers:
  - docs require new filtering/query APIs
  - curated print methods are insufficient for the narrative examples
  - snapshot lifecycle documentation conflicts with implementation
  - metric semantics appear wrong or under-specified
  - a schema change seems necessary
forbidden_actions:
  - adding tag or label query DSLs
  - changing comparison metric definitions
  - changing snapshot sealing semantics
  - reintroducing db_path-first store examples as the main path
  - using base column slicing to hide poor default prints in narrative demos
```

---

## LDG-1106: Result Timestamp Display Options

**Priority:** P2  
**Effort:** 1-2 days  
**Dependencies:** LDG-1101  
**Status:** Done

**Description:**
Make EOD result-table printing compact without weakening timestamp correctness.
`ts_utc` must remain POSIXct UTC for all programmatic paths, but ledgr-owned
print methods should be able to display date-only values when all visible
timestamps are midnight UTC.

**Tasks:**
1. Add a package option:
   - `options(ledgr.print_ts_utc = "auto")` as the default;
   - `"auto"` displays date-only values for all-midnight-UTC result tables and
     full UTC datetimes otherwise;
   - `"datetime"` always displays full UTC datetimes.
2. Validate invalid option values with a clear classed error or warning in the
   relevant print path.
3. Add a display helper for `ts_utc` that:
   - detects all non-missing timestamps at midnight UTC;
   - formats EOD values as `YYYY-MM-DD`;
   - preserves full datetime display for intraday values;
   - handles empty and all-`NA` timestamp vectors safely.
4. Introduce classed tibble result printing where needed so the display helper
   applies to ledgr-owned result tables without mutating the underlying data.
5. Ensure `ledgr_results()` remains tibble-compatible and programmatic access
   to `ts_utc` remains POSIXct UTC.
6. Ensure `tibble::as_tibble()` or equivalent raw access returns the original
   timestamp column, not formatted strings.
7. Update README/vignette examples if compact timestamp printing changes their
   rendered output.
8. Document the option and display-only contract.

**Acceptance Criteria:**
- [ ] EOD result tables can print `ts_utc` as dates in ledgr-owned print paths.
- [ ] Intraday result tables still print full datetimes.
- [ ] `options(ledgr.print_ts_utc = "datetime")` restores full datetime
      display.
- [ ] Underlying `ts_utc` values remain POSIXct UTC.
- [ ] `as_tibble()` / raw programmatic access is not display-formatted.
- [ ] Invalid option values fail or warn clearly.
- [ ] Documentation states this is display-only.

**Test Requirements:**
- Unit tests for timestamp display helper.
- Print tests for EOD and intraday result tables.
- Option tests for `"auto"`, `"datetime"`, and invalid values.
- Type-preservation tests for `ledgr_results()` and `as_tibble()`.
- Existing result/run-store tests.

**Source Reference:** v0.1.7.1 spec section 2 R13.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: H
classification_reason: >
  The work is a bounded result-display UX change, but it touches exported result
  objects, print behavior, package options, and timestamp presentation. It must
  preserve programmatic timestamp semantics and therefore needs Tier H review.
invariants_at_risk:
  - timestamp type preservation
  - result table composability
  - print/display contract
  - package option behavior
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_1_spec_packet/v0_1_7_1_spec.md
  - inst/design/contracts.md (Result Contract)
  - R/run-store.R
  - R/backtest.R
  - tests/testthat/test-run-store.R
  - tests/testthat/test-backtest-wrapper.R
tests_required:
  - timestamp display helper tests
  - EOD and intraday print tests
  - package option tests
  - type-preservation tests
  - existing result/run-store tests
escalation_triggers:
  - ledgr_results() must stop returning a tibble-compatible object
  - timestamp values would need mutation rather than display formatting
  - intraday timestamps become ambiguous
  - global option behavior conflicts with tibble printing
forbidden_actions:
  - converting stored or returned ts_utc values to character
  - hiding intraday time information in auto mode
  - changing result table schemas
  - changing fill or ledger timestamps
```

---

## LDG-1107: v0.1.7.1 Release Gate

**Priority:** P0  
**Effort:** 1 day  
**Dependencies:** LDG-1102, LDG-1104, LDG-1105, LDG-1106  
**Status:** Pending

**Description:**
Perform the final v0.1.7.1 gate. This ticket verifies that the patch release
matches the spec, the MACD outcome is settled, docs render, examples work, and
no future-cycle APIs leaked into the release.

**Tasks:**
1. Confirm all tickets are complete and reviewed.
2. Confirm `DESCRIPTION` is `0.1.7.1`.
3. Confirm `NEWS.md` has accurate v0.1.7.1 bullets.
4. Confirm `inst/design/ledgr_roadmap.md` and this packet match the release
   scope.
5. Confirm the MACD audit case is fixed or explicitly documented as not
   reproducible.
6. Confirm README and narrative docs use modern example style:
   - base pipe;
   - `filter()` / `between()` where appropriate;
   - no main-path `subset()`;
   - no raw UTC boilerplate in first examples.
7. Confirm installed narrative docs are discoverable from pkgdown and package
   documentation.
8. Confirm EOD timestamp display remains display-only and does not mutate
   `ts_utc` values.
9. Run full test suite.
10. Run `R CMD check --no-manual --no-build-vignettes`.
11. Build pkgdown locally.
12. Confirm no `ledgr_sweep()`, `ledgr_tune()`, or
    `ledgr_precompute_features()` exports exist.
13. Confirm Ubuntu and Windows CI are green before merge/tag.

**Acceptance Criteria:**
- [ ] All v0.1.7.1 tickets are done and reviewed.
- [ ] Version metadata, NEWS, roadmap, spec, and tickets agree.
- [ ] Tests pass locally.
- [ ] R CMD check passes with 0 errors and 0 warnings.
- [ ] pkgdown builds.
- [ ] CI is green on Ubuntu and Windows.
- [ ] No future sweep/tune APIs are exported.
- [ ] Timestamp display option is tested and documented as display-only.
- [ ] Final review signs off on release scope.

**Test Requirements:**
- `devtools::test()`.
- `R CMD check --no-manual --no-build-vignettes`.
- pkgdown build.
- Export/API inventory scan.
- Documentation pattern scans.
- CI verification.

**Source Reference:** v0.1.7.1 spec section 6.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: H
review_tier: H
classification_reason: >
  Release gates are Tier H by routing rule. This ticket verifies version scope,
  test completeness, documentation rendering, exported API boundaries, and CI
  readiness before merge and tag.
invariants_at_risk:
  - release correctness
  - package build health
  - public API export boundary
  - documentation/installability
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_1_spec_packet/v0_1_7_1_spec.md
  - inst/design/ledgr_v0_1_7_1_spec_packet/v0_1_7_1_tickets.md
  - inst/design/ledgr_v0_1_7_1_spec_packet/tickets.yml
  - DESCRIPTION
  - NEWS.md
  - README.Rmd
  - _pkgdown.yml
  - inst/design/ledgr_roadmap.md
tests_required:
  - devtools::test()
  - R CMD check --no-manual --no-build-vignettes
  - pkgdown build
  - export/API inventory scan
  - documentation pattern scans
  - CI verification
escalation_triggers:
  - any CI failure remains unexplained
  - exported API inventory contains future-cycle APIs
  - R CMD check warnings require scope decisions
  - documentation examples cannot run offline
forbidden_actions:
  - tagging before CI is green
  - ignoring R CMD check warnings
  - shipping with known future-cycle API leaks
  - changing implementation behavior during the release gate without a ticket
```

---

## Out Of Scope For v0.1.7.1

- Sweep mode.
- `ledgr_tune()`.
- `ledgr_precompute_features()`.
- Persistent sweep results.
- New tag/label query DSLs.
- Target-weight or optimizer APIs.
- Short selling.
- Broker integrations.
- Live or paper trading.
- Experiment-store schema migrations.
