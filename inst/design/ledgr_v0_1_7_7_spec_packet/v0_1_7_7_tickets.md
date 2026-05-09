# ledgr v0.1.7.7 Tickets

**Version:** 0.1.7.7
**Date:** May 9, 2026
**Total Tickets:** 7

---

## Ticket Organization

v0.1.7.7 defines ledgr's first explicit risk-adjusted metric contract before
v0.1.8 sweep mode needs stable ranking and scoring semantics. The release also
closes small comparison, provenance, snapshot/Yahoo documentation, and logo
placement gaps. It must not expand into sweep mode, target-risk APIs,
PerformanceAnalytics adapters, risk-free-rate data adapters, or indicator
adapter work.

Tracks:

1. **Metric contract:** define shipped/deferred metrics, excess-return semantics,
   risk-free-rate scope, frequency safety, and edge cases.
2. **Native metrics:** implement ledgr-owned metric definitions and independent
   public-table oracles.
3. **Optional parity:** use `{PerformanceAnalytics}` only as an optional test
   oracle where definitions match.
4. **Comparison and docs:** expose raw numeric comparison columns and close the
   small documentation gaps from the v0.1.7.5 retrospective.
5. **Branding:** promote the logo into package-visible README/pkgdown assets.
6. **Release gate:** run the normal release checks and remote CI.

### Dependency DAG

```text
LDG-1701 -> LDG-1702 -> LDG-1703 -> LDG-1707
LDG-1702 -> LDG-1704 -----------^
LDG-1701 -> LDG-1705 -----------^
LDG-1701 -> LDG-1706 -----------^
```

`LDG-1707` is the v0.1.7.7 release gate.

### Priority Levels

- **P0 (Blocker):** Required for release correctness or scope coherence.
- **P1 (Critical):** Required for the v0.1.7.7 user-facing contract to hold.
- **P2 (Important):** Required for release hygiene and future maintainability.
- **P3 (Optional):** Useful, but not a release blocker.

---

## LDG-1701: Risk Metric Contract Baseline

**Priority:** P0
**Effort:** 0.5-1 day
**Dependencies:** None
**Status:** Done

**Description:**
Finalize the v0.1.7.7 metric contract before implementation. Decide which
risk-adjusted metrics ship, which are deferred, how Sharpe-style metrics use
excess returns, how scalar annual risk-free rates are converted to per-period
returns, and how frequency/edge cases are handled.

**Tasks:**
1. Review `v0_1_7_7_spec.md`, `ledgr_roadmap.md`, `contracts.md`, and the
   existing metrics implementation/docs.
2. List shipped and deferred metrics explicitly.
3. Define the return-series contract over public equity rows.
4. Define the risk-free-rate provider boundary for scalar annual rates and
   explicitly defer time-varying real-data providers.
5. Define annualization/frequency behavior without hard-coding daily bars.
6. Define edge-case semantics for zero trades, flat equity, constant returns,
   zero or near-zero volatility, short samples, and missing returns.
7. Update `contracts.md` and metric documentation scaffolding if needed.

**Acceptance Criteria:**
- [x] Shipped and deferred risk-adjusted metrics are explicitly listed.
- [x] Sharpe is either shipped or explicitly deferred with public rationale.
- [x] Sharpe-style metrics are specified as
      `mean(excess_return) / sd(excess_return)` over period excess returns.
- [x] Scalar annual risk-free-rate units and conversion are documented.
- [x] Time-varying risk-free-rate series and real data providers are explicitly
      shipped or deferred.
- [x] Frequency/annualization behavior is documented without silent daily-only
      assumptions.
- [x] Edge-case semantics are written before implementation.

**Implementation Notes:**
- Reviewed the current metric implementation in `R/backtest.R`, the existing
  metric oracle tests, and the metrics-and-accounting vignette.
- Recorded the v0.1.7.7 risk metric contract in `contracts.md`:
  - `sharpe_ratio` is the planned shipped risk-adjusted metric;
  - Sharpe-style metrics consume period excess returns;
  - scalar annual risk-free rates are decimals with default `0`;
  - scalar rates convert geometrically to per-period returns using
    `(1 + rf_annual)^(1 / bars_per_year) - 1`;
  - time-varying risk-free-rate series and real providers such as FRED,
    Treasury, ECB, and central-bank adapters are deferred;
  - Sortino, Calmar, Omega, information ratio, alpha/beta,
    benchmark-relative metrics, VaR, and tail-risk metrics are deferred.
- Added the same contract explanation to `vignettes/metrics-and-accounting.Rmd`
  and the checked-in companion markdown.
- Added documentation-contract assertions for the new risk metric boundary.
- No metric implementation code changed in this ticket; LDG-1702 owns the
  implementation and public-table oracle expansion.

**Verification:**
```text
pkgload::load_all('.', quiet=TRUE);
testthat::test_file('tests/testthat/test-documentation-contracts.R')
```

Result: passed on Windows.

**Test Requirements:**
- Documentation contract scan for the metric contract.
- Scope grep confirming no FRED/Treasury/ECB adapters, sweep APIs, target-risk
  APIs, or PerformanceAnalytics public adapter are introduced.

**Source Reference:** v0.1.7.7 spec sections 1.1, 3, 4, 9, 12.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: H
review_tier: H
classification_reason: >
  Metric semantics, frequency safety, risk-free-rate assumptions, and sweep
  ranking prerequisites affect public API behavior and future architecture.
invariants_at_risk:
  - metric definition stability
  - future sweep ranking semantics
  - frequency safety
  - risk-free-rate provider boundary
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_7_spec_packet/v0_1_7_7_spec.md
  - inst/design/ledgr_roadmap.md
  - inst/design/contracts.md
  - R/backtest.R
  - vignettes/metrics-and-accounting.Rmd
  - tests/testthat/test-metric-oracles.R
tests_required:
  - documentation contract scan
  - scope grep for forbidden feature work
escalation_triggers:
  - Sharpe cannot be defined without changing run identity
  - annualization cannot be made frequency-safe
  - real risk-free-rate data is needed to ship the metric
forbidden_actions:
  - adding reference-data adapters
  - adding PerformanceAnalytics runtime dependency
  - adding sweep or target-risk APIs
  - changing result table semantics without a spec update
```

---

## LDG-1702: Ledgr-Native Risk Metrics And Public-Table Oracles

**Priority:** P0
**Effort:** 1-2 days
**Dependencies:** LDG-1701
**Status:** Done

**Description:**
Implement the shipped ledgr-owned metric definitions, preferably including
Sharpe ratio, inside the existing `ledgr_compute_metrics()` standard metric
surface. Metrics must derive from public result tables or the same helpers used
to produce those tables, and oracle tests must independently recompute them from
public tables.

**Tasks:**
1. Extend `ledgr_compute_metrics_internal()` and `summary.ledgr_backtest()` with
   the shipped risk-adjusted metric.
2. Build or extend internal return-series helpers over adjacent public equity
   rows.
3. Implement scalar annual risk-free-rate conversion if Sharpe ships.
4. Preserve the existing `metrics = "standard"` public surface unless LDG-1701
   explicitly changes it.
5. Extend `tests/testthat/test-metric-oracles.R` with independent public-table
   oracle checks.
6. Add edge-case tests for flat equity, constant returns, near-zero volatility,
   short samples, and zero-trade runs.
7. Update Rd and metrics-and-accounting documentation.

**Acceptance Criteria:**
- [x] `ledgr_compute_metrics(bt)` exposes every shipped metric consistently.
- [x] `summary(bt)` prints shipped risk metrics when available.
- [x] Metric code does not mutate ledgr stores.
- [x] Public-table oracle tests independently recompute every shipped metric.
- [x] Tests cover zero trades, flat equity, constant returns, near-zero
      volatility, and short samples.
- [x] Infinite Sharpe-style values are not emitted silently.
- [x] Documentation explains formulas, risk-free assumptions, annualization, and
      edge cases.

**Implementation Notes:**
- Added `sharpe_ratio` to the standard ledgr-owned metric surface and to
  `summary.ledgr_backtest()`.
- Added adjacent-equity-row return helpers, geometric scalar annual
  risk-free-rate conversion, and an explicit zero-denominator Sharpe guard.
- Extended public-table oracle tests so expected metrics are independently
  recomputed from `ledgr_results(bt, what = "equity")` and
  `ledgr_results(bt, what = "trades")`.
- Documented the formulas, scalar risk-free-rate assumptions, annualization, and
  `sd(excess_return) <= .Machine$double.eps` edge policy in contracts and the
  metrics article.
- Added a NEWS entry calling out the new Sharpe metric and the existing
  volatility metric's stricter invalid-return behavior.
- Verification passed:
  `testthat::test_file("tests/testthat/test-metric-oracles.R")`,
  `testthat::test_file("tests/testthat/test-metrics-zero-trades.R")`,
  `testthat::test_file("tests/testthat/test-backtest-s3.R")`, and
  `testthat::test_file("tests/testthat/test-documentation-contracts.R")`.

**Test Requirements:**
- `tests/testthat/test-metric-oracles.R`
- `tests/testthat/test-metrics-zero-trades.R`
- `tests/testthat/test-backtest-s3.R`
- `tests/testthat/test-documentation-contracts.R`

**Source Reference:** v0.1.7.7 spec sections 4, 5, 7.4, 10, 12.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: H
review_tier: H
classification_reason: >
  Core metric computation affects public API, summary output, comparison
  surfaces, future sweep ranking, and documented formulas.
invariants_at_risk:
  - public metric definitions
  - public-table derivability
  - summary output consistency
  - frequency-safe annualization
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_7_spec_packet/v0_1_7_7_spec.md
  - inst/design/contracts.md
  - R/backtest.R
  - tests/testthat/test-metric-oracles.R
  - tests/testthat/test-metrics-zero-trades.R
  - vignettes/metrics-and-accounting.Rmd
tests_required:
  - tests/testthat/test-metric-oracles.R
  - tests/testthat/test-metrics-zero-trades.R
  - tests/testthat/test-backtest-s3.R
  - tests/testthat/test-documentation-contracts.R
escalation_triggers:
  - metric requires hidden runner state
  - metric changes existing public result table semantics
  - metric cannot be made frequency-safe
forbidden_actions:
  - relying on PerformanceAnalytics for canonical computation
  - adding a metrics result table
  - mutating stores during metric computation
  - weakening existing metric oracles
```

---

## LDG-1703: Optional PerformanceAnalytics Parity Tests

**Priority:** P1
**Effort:** 0.5-1 day
**Dependencies:** LDG-1702
**Status:** Done

**Description:**
Use `{PerformanceAnalytics}` only as an optional parity oracle where definitions
can be aligned. This ticket must not add a public PerformanceAnalytics adapter
or make the package a runtime dependency.

**Tasks:**
1. Decide whether `{PerformanceAnalytics}` must be added to `Suggests`.
2. Add optional tests guarded by
   `testthat::skip_if_not_installed("PerformanceAnalytics")`.
3. Compare only metrics with aligned definitions and explicit annualization
   scale.
4. Normalize sign conventions or compounding assumptions explicitly in tests.
5. Document that parity tests are not the source of ledgr's metric contract.

**Acceptance Criteria:**
- [x] `{PerformanceAnalytics}` is optional.
- [x] Absence of `{PerformanceAnalytics}` does not affect ledgr metric output.
- [x] Parity tests name the exact PerformanceAnalytics functions used.
- [x] Annualization scale and risk-free-rate units are explicit.
- [x] No public PerformanceAnalytics adapter is exported.
- [x] No hashes, run identity, config identity, or snapshot identity change
      because of optional parity tests.

**Implementation Notes:**
- Added `{PerformanceAnalytics}` to `Suggests` only; it is not imported and no
  public adapter or export was added.
- Added optional parity tests guarded by
  `testthat::skip_if_not_installed("PerformanceAnalytics")` and
  `testthat::skip_if_not_installed("xts")`.
- Compared ledgr metrics against explicitly aligned PerformanceAnalytics
  functions:
  `PerformanceAnalytics::Return.annualized(scale = 252, geometric = TRUE)`,
  `PerformanceAnalytics::StdDev.annualized(scale = 252)`, and
  `PerformanceAnalytics::SharpeRatio.annualized(scale = 252, geometric = FALSE,
  Rf = rf_period_return)`.
- The test converts ledgr's scalar annual risk-free rate to the same per-period
  risk-free return that PerformanceAnalytics receives as `Rf`.
- Added a contract note that optional PerformanceAnalytics parity is external
  evidence only and must not redefine ledgr-owned metric formulas or become a
  runtime dependency.
- Verification passed:
  `testthat::test_file("tests/testthat/test-metrics-performanceanalytics.R")`,
  `testthat::test_file("tests/testthat/test-metric-oracles.R")`, and
  `testthat::test_file("tests/testthat/test-documentation-contracts.R")`.

**Test Requirements:**
- `tests/testthat/test-metrics-performanceanalytics.R` if created.
- `tests/testthat/test-metric-oracles.R`
- `tests/testthat/test-documentation-contracts.R`

**Source Reference:** v0.1.7.7 spec sections 3 R6, 6, 9, 12.

**Classification:**
```yaml
risk_level: high
implementation_tier: M
review_tier: H
classification_reason: >
  Optional ecosystem parity must not become a runtime dependency or silently
  redefine ledgr-owned metrics.
invariants_at_risk:
  - optional dependency boundary
  - metric definition ownership
  - run identity stability
  - documentation accuracy
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_7_spec_packet/v0_1_7_7_spec.md
  - DESCRIPTION
  - R/backtest.R
  - tests/testthat/test-metric-oracles.R
  - vignettes/metrics-and-accounting.Rmd
tests_required:
  - optional PerformanceAnalytics parity tests
  - metric oracle tests
  - documentation contract tests
escalation_triggers:
  - parity definitions cannot be aligned
  - PerformanceAnalytics must become mandatory
  - adapter API is needed to satisfy parity
forbidden_actions:
  - adding a public PerformanceAnalytics adapter
  - importing PerformanceAnalytics
  - using PerformanceAnalytics as canonical metric implementation
  - changing run identity based on optional package versions
```

---

## LDG-1704: Raw Numeric Comparison Columns

**Priority:** P1
**Effort:** 1 day
**Dependencies:** LDG-1702
**Status:** Done

**Description:**
Make `ledgr_compare_runs()` useful for programmatic ranking by exposing raw
numeric companion columns for metrics while preserving the curated printed view.
Users must not parse strings such as `"+5.2%"` to rank runs.

**Tasks:**
1. Inspect `ledgr_compare_runs_select()` and `print.ledgr_comparison()`.
2. Add raw numeric columns for total return, max drawdown, existing standard
   metrics, and any newly shipped risk metric.
3. Preserve formatted columns or print formatting for human display.
4. Ensure full tibble access preserves raw columns.
5. Update tests for data access and printed display.
6. Update documentation and contract tests.

**Acceptance Criteria:**
- [x] Users can rank by numeric total return without parsing display strings.
- [x] Users can rank by numeric max drawdown without parsing display strings.
- [x] Users can rank by any shipped risk metric without parsing display strings.
- [x] Printed comparison output remains readable and curated.
- [x] Tests cover raw column access and printed display.
- [x] Future sweep result docs can reference the same metric-column convention.

**Implementation Notes:**
- Extended `ledgr_compare_runs()` with raw numeric standard metric columns:
  `annualized_return`, `volatility`, `sharpe_ratio`, `avg_trade`, and
  `time_in_market`, while preserving existing raw `total_return` and
  `max_drawdown`.
- Computed comparison metrics from stored `equity_curve` and `ledger_events`
  artifacts only; no run-store schema changes, strategy reruns, or formatted
  string parsing were introduced.
- Kept formatted percentages as a print-only concern and added `sharpe_ratio`
  to the curated comparison print view.
- Documented the raw numeric comparison contract in `contracts.md` and
  `?ledgr_compare_runs`.
- Verification passed:
  `testthat::test_file("tests/testthat/test-run-compare.R")`,
  `testthat::test_file("tests/testthat/test-run-print.R")`,
  `testthat::test_file("tests/testthat/test-metric-oracles.R")`, and
  `testthat::test_file("tests/testthat/test-documentation-contracts.R")`.

**Test Requirements:**
- `tests/testthat/test-run-compare.R`
- `tests/testthat/test-run-print.R`
- `tests/testthat/test-metric-oracles.R`
- `tests/testthat/test-documentation-contracts.R`

**Source Reference:** v0.1.7.7 spec sections 3 R7, 7.1, 10, 12.

**Classification:**
```yaml
risk_level: high
implementation_tier: M
review_tier: H
classification_reason: >
  Comparison output is a public ranking surface and future sweep results must
  inherit its metric-column conventions.
invariants_at_risk:
  - programmatic comparison output
  - print/data separation
  - future sweep ranking surface
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_7_spec_packet/v0_1_7_7_spec.md
  - R/run-store.R
  - tests/testthat/test-run-compare.R
  - tests/testthat/test-run-print.R
  - tests/testthat/test-metric-oracles.R
tests_required:
  - tests/testthat/test-run-compare.R
  - tests/testthat/test-run-print.R
  - tests/testthat/test-metric-oracles.R
  - tests/testthat/test-documentation-contracts.R
escalation_triggers:
  - raw columns require changing stored run schema
  - print method cannot preserve curated display
  - new columns break existing comparison tests
forbidden_actions:
  - parsing formatted strings internally
  - removing existing comparison columns without a spec update
  - changing run-store persistence schema for display-only reasons
```

---

## LDG-1705: Provenance And Snapshot/Yahoo Documentation Hygiene

**Priority:** P1
**Effort:** 1 day
**Dependencies:** LDG-1701
**Status:** Todo

**Description:**
Close documentation gaps that are not metric implementation work: make
`ledgr_extract_strategy(..., trust = FALSE)` a prominent provenance feature and
clarify the Yahoo/seal documentation details identified in the v0.1.7.5
retrospective.

**Tasks:**
1. Add a compact stored-strategy inspection example to README near durable run
   discovery/comparison.
2. Add or strengthen an experiment-store vignette section on inspecting stored
   strategy source.
3. Ensure `?ledgr_extract_strategy` links to the experiment-store and
   strategy-development articles.
4. Document the `trust = FALSE` and `trust = TRUE` boundary clearly.
5. Update `?ledgr_snapshot_from_yahoo` to state the returned handle is sealed.
6. Update `?ledgr_snapshot_seal` to document idempotent already-sealed behavior.
7. Document harmless `quantmod` startup/S3 messages in the Yahoo snapshot help.
8. Update rendered companion markdown and documentation contract tests.

**Acceptance Criteria:**
- [ ] README shows `ledgr_extract_strategy(..., trust = FALSE)` as the safe
      stored-strategy inspection path.
- [ ] Experiment-store docs teach source inspection from a completed run without
      rerunning strategy code.
- [ ] Trust-boundary prose is explicit: source identity is not code safety.
- [ ] Legacy/pre-provenance limitations are mentioned.
- [ ] `?ledgr_snapshot_from_yahoo` states the returned handle is sealed.
- [ ] `?ledgr_snapshot_seal` documents idempotent behavior on sealed handles.
- [ ] Yahoo snapshot docs mention expected `quantmod` stderr noise.
- [ ] Rd, Rmd, rendered markdown, and doc-contract tests agree.

**Implementation Notes:**
- Pending.

**Test Requirements:**
- `tests/testthat/test-documentation-contracts.R`
- Documentation grep for `ledgr_extract_strategy(..., trust = FALSE)`.
- Documentation grep for Yahoo/seal wording.

**Source Reference:** v0.1.7.7 spec sections 3 R8, 7.2, 7.3, 10, 12.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: H
classification_reason: >
  Documentation work, but it teaches provenance trust boundaries and snapshot
  lifecycle semantics that users rely on for safe inspection and ingestion.
invariants_at_risk:
  - stored strategy provenance trust boundary
  - snapshot seal lifecycle documentation
  - Yahoo adapter documentation accuracy
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_7_spec_packet/v0_1_7_7_spec.md
  - README.Rmd
  - README.md
  - R/strategy-extract.R
  - R/snapshot_adapters.R
  - R/snapshots-seal.R
  - vignettes/experiment-store.Rmd
  - vignettes/strategy-development.Rmd
  - tests/testthat/test-documentation-contracts.R
tests_required:
  - tests/testthat/test-documentation-contracts.R
  - documentation grep for strategy extraction examples
  - documentation grep for snapshot/Yahoo corrections
escalation_triggers:
  - docs require changing strategy extraction behavior
  - docs require changing snapshot seal behavior
  - Yahoo adapter behavior differs from documented sealed-state claim
forbidden_actions:
  - evaluating stored strategy source in safe examples
  - weakening trust-boundary language
  - changing snapshot hashes for documentation convenience
```

---

## LDG-1706: Logo Asset Placement

**Priority:** P2
**Effort:** 0.5-1 day
**Dependencies:** LDG-1701
**Status:** Todo

**Description:**
Promote the source logo from the design packet into package-visible
documentation assets and display it in the GitHub README and pkgdown site.

**Tasks:**
1. Inspect `inst/design/ledgr_v0_1_7_7_spec_packet/ledgr.svg` for size and
   render suitability.
2. Copy the package-facing SVG asset into `man/figures/`.
3. Use SVG in README and pkgdown unless rendering proves unsuitable.
4. Generate a raster derivative only if needed for README/pkgdown compatibility.
5. Update README source and rendered README.
6. Update `_pkgdown.yml` only if the default `man/figures` convention is
   insufficient.
7. Add or update documentation contract tests for logo paths.

**Acceptance Criteria:**
- [ ] Source logo remains in the v0.1.7.7 design packet.
- [ ] Package-facing logo asset exists under `man/figures/`.
- [ ] README displays the logo through a repository-relative path.
- [ ] pkgdown displays the logo.
- [ ] No local absolute paths are used.
- [ ] Raster derivative is committed only if needed and documented.
- [ ] Local rendering/build checks confirm paths.

**Implementation Notes:**
- Pending.

**Test Requirements:**
- README source/render check.
- pkgdown build when feasible.
- Documentation contract test for logo paths.

**Source Reference:** v0.1.7.7 spec sections 3 R9, 8, 10, 12.

**Classification:**
```yaml
risk_level: low
implementation_tier: L
review_tier: M
classification_reason: >
  Branding/documentation asset work with low runtime risk, but package-visible
  paths and generated artifacts need review.
invariants_at_risk:
  - package documentation asset paths
  - README/pkgdown rendering
  - generated artifact hygiene
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_7_spec_packet/v0_1_7_7_spec.md
  - inst/design/ledgr_v0_1_7_7_spec_packet/ledgr.svg
  - README.Rmd
  - README.md
  - _pkgdown.yml
  - man/figures/
tests_required:
  - README render check
  - pkgdown build when feasible
  - documentation contract logo-path scan
escalation_triggers:
  - SVG cannot render on GitHub or pkgdown
  - logo asset is too large for package-facing docs
  - raster generation becomes necessary
forbidden_actions:
  - committing local absolute paths
  - committing generated artifacts outside package-visible docs
  - replacing the package title with an image-only header
```

---

## LDG-1707: v0.1.7.7 Release Gate

**Priority:** P0
**Effort:** 1 day
**Dependencies:** LDG-1703, LDG-1704, LDG-1705, LDG-1706
**Status:** Todo

**Description:**
Run the v0.1.7.7 release gate according to the release CI playbook. Do not do
broad release-gate surgery. If CI exposes a core design issue, stop and create a
blocker ticket with a problem statement and definition of done.

**Tasks:**
1. Confirm every v0.1.7.7 ticket is done and status matches in markdown/YAML.
2. Run targeted metric, comparison, documentation, README, and logo checks.
3. Run optional PerformanceAnalytics parity tests when installed.
4. Run full local Windows tests.
5. Run `R CMD check --no-manual --no-build-vignettes`.
6. Run coverage gate.
7. Run pkgdown build because README/pkgdown/docs changed.
8. Run local WSL/Ubuntu gate if DuckDB-sensitive files were touched.
9. Push branch and wait for branch CI.
10. Merge only after branch CI is green.
11. Wait for main CI and tag-triggered CI before declaring the release valid.

**Acceptance Criteria:**
- [ ] All v0.1.7.7 ticket statuses are complete and synchronized.
- [ ] Targeted metric/comparison/docs/logo tests pass.
- [ ] Optional PerformanceAnalytics parity tests pass when installed or skip
      cleanly when absent.
- [ ] Full local Windows tests pass.
- [ ] `R CMD check --no-manual --no-build-vignettes` passes.
- [ ] Coverage gate passes.
- [ ] pkgdown build passes.
- [ ] Local WSL/Ubuntu gate passes when required and available.
- [ ] Remote branch CI is green.
- [ ] Main CI is green after merge.
- [ ] Tag-triggered CI is green before release is declared valid.

**Implementation Notes:**
- Pending.

**Test Requirements:**
- `tests/testthat/test-metric-oracles.R`
- `tests/testthat/test-run-compare.R`
- `tests/testthat/test-run-print.R`
- `tests/testthat/test-documentation-contracts.R`
- Optional `tests/testthat/test-metrics-performanceanalytics.R`
- Full local test suite.
- R CMD check.
- Coverage.
- pkgdown.
- Remote CI.

**Source Reference:** v0.1.7.7 spec sections 11, 12.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: H
review_tier: H
classification_reason: >
  Release gates, CI interpretation, tag movement, metric correctness, and
  documentation rendering are release-critical and must follow the playbook.
invariants_at_risk:
  - release validity
  - CI discipline
  - metric contract correctness
  - documentation rendering
  - tag correctness
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_7_spec_packet/v0_1_7_7_spec.md
  - inst/design/ledgr_v0_1_7_7_spec_packet/v0_1_7_7_tickets.md
  - inst/design/ledgr_v0_1_7_7_spec_packet/tickets.yml
  - inst/design/release_ci_playbook.md
  - inst/design/contracts.md
tests_required:
  - targeted metric/comparison/docs/logo tests
  - optional PerformanceAnalytics parity tests
  - full local test suite
  - R CMD check
  - coverage
  - pkgdown
  - remote CI
escalation_triggers:
  - Ubuntu failure points to broad core infrastructure
  - CI failure cannot be reproduced narrowly
  - fix expands outside initially failing subsystem
  - metric contract conflict appears during release gate
  - main and tag CI disagree
forbidden_actions:
  - broad release-gate surgery
  - moving a release tag before main CI is green
  - declaring release valid before tag CI is green
  - weakening tests to pass CI
```
