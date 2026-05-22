# ledgr v0.1.8.1 Spec

**Status:** Draft scoped implementation baseline.
**Target Branch:** `v0.1.8.1`
**Scope:** v0.1.8 auditr finding triage, documentation/UX stabilization,
examples, diagnostics, narrow message polish, the accepted indicator
determinism-extraction refactor, and the accepted multi-output indicator bundle
authoring UX.
**Non-scope for this pass:** All other roadmap feature work, performance
optimization, parallel sweep, parameter-grid QoL helpers, new research workflow
templates, metric context/risk-free-rate storage, target-risk layers, execution
policy/OMS work, and new public analysis APIs unless explicitly listed as
in-scope below.

---

## 0. Source Inputs

This spec is based on the v0.1.8 auditr packet:

- `inst/design/ledgr_v0_1_8_1_spec_packet/categorized_feedback.yml`
- `inst/design/ledgr_v0_1_8_1_spec_packet/ledgr_triage_report.md`
- `inst/design/ledgr_v0_1_8_1_spec_packet/cycle_retrospective.md`

Supporting context:

- `inst/design/contracts.md`
- `inst/design/ledgr_roadmap.md`
- `inst/design/horizon.md`
- `inst/design/rfc/rfc_multi_output_indicator_ux_synthesis.md`
- `inst/design/rfc/rfc_indicator_codebase_simplification_v0_1_8_x_synthesis.md`
- `inst/design/rfc/rfc_risk_free_rate_metric_context_v0_1_8_1_synthesis.md`
- `inst/design/rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md`
- `inst/design/ledgr_v0_1_8_0_spec_packet/v0_1_8_spec.md`
- `inst/design/ledgr_v0_1_8_0_spec_packet/v0_1_8_tickets.md`

The v0.1.8.0 packet path above reflects the normalized patch-release directory
layout. If a branch still has the older `ledgr_v0_1_8_spec_packet/` path, use
the equivalent v0.1.8 spec and ticket files from that directory.

This spec does not treat auditr rows as automatically true package defects.
Rows are evidence. Ticket cut must still distinguish documentation gaps,
confirmed runtime bugs, expected user errors, and backlog design requests.

---

## 1. Thesis

v0.1.8.0 made ledgr's sweep workflow real. v0.1.8.1 should make the package
easier to learn, inspect, and debug from installed documentation.

The auditr run did not find high-severity execution failures. It found a
different problem: users can complete many workflows, but they often need to
stitch together help pages, vignettes, examples, and implicit design knowledge.

v0.1.8.1 is therefore an auditr-first stabilization cycle:

```text
installed docs + runnable examples + clearer diagnostics
  -> fewer implicit contracts
  -> easier first-run and research workflows
```

The release should preserve the v0.1.8 execution architecture. It should not
reopen sweep design, introduce a second execution path, or start broad roadmap
features before auditr findings are routed.

The accepted non-auditr additions for this cycle are narrow and
indicator-adjacent:

- the Phase 1 indicator determinism-extraction refactor from
  `rfc/rfc_indicator_codebase_simplification_v0_1_8_x_synthesis.md`;
- the multi-output indicator bundle authoring UX from
  `rfc/rfc_multi_output_indicator_ux_synthesis.md`.

The determinism extraction must land before bundle/adapter implementation that
touches `ledgr_function_fingerprint()` or indicator fingerprints. Metric context
is deferred to v0.1.8.2, and single-core sweep optimization is deferred to
v0.1.8.3.

Roadmap placement for adjacent work:

| Release | Scope |
| --- | --- |
| v0.1.8.1 | Auditr stabilization, indicator determinism extraction, and multi-output indicator bundle authoring. |
| v0.1.8.2 | Metric context and risk-free-rate assumptions. |
| v0.1.8.3 | Single-core sweep optimization after metric-kernel semantics settle. |
| v0.1.8.4 | Parameter-grid quality-of-life helpers. |
| v0.1.8.5 | Parallel sweep dispatch after serial semantics, metrics, and grid UX stabilize. |
| v0.1.9 | Target-risk chain. |
| v0.2.x | Execution-policy / OMS north-star work, only after further synthesis/spec cut. |

This spec must not pull future-release items forward implicitly through
documentation examples, helper APIs, or incidental schema changes.

---

## 2. Auditr Evidence Baseline

The v0.1.8 auditr cycle produced:

| Measure | Count |
| --- | ---: |
| Episodes | 44 |
| Feedback rows | 97 |
| High-severity rows | 0 |
| Medium-severity rows | 14 |
| Low-severity rows | 83 |
| Triage themes | 9 |

Bucket counts from the triage report:

| Bucket | Items |
| --- | ---: |
| docs_gap | 74 |
| duplicate | 9 |
| expected_user_error | 5 |
| unclear | 5 |
| missing_api | 4 |

The absence of high-severity rows means v0.1.8.1 should not become a
large corrective architecture release by default. The concentration in
`docs_gap` means most value is likely in better examples, schemas, glossary
text, warning explanations, and installed documentation routing.

---

## 3. Release Goals

v0.1.8.1 has six auditr-first goals and two accepted non-auditr additions:

1. Make feature, indicator, feature-map, and warmup contracts teachable from a
   compact installed guide.
2. Add or repair runnable first-run workflows so users can run representative
   ledgr tasks without assembling code from several pages.
3. Document result inspection schemas and distinctions: fills versus closed
   trades, summary output, comparison tables, metrics, ledger/events, and
   feature persistence.
4. Improve strategy-helper documentation with full setup paths and a compact
   troubleshooting table for common helper-pipeline failures.
5. Polish sweep, promotion, precompute, and seed documentation now that
   v0.1.8.0 has shipped.
6. Improve the most confusing warnings/errors where auditr shows users needed
   extra investigation to understand origin, consequence, or next action.
7. Add the accepted multi-output indicator bundle authoring UX without changing
   the existing single-output feature contract or runtime feature semantics.
8. Extract package-level determinism and fingerprint helpers from
   `R/indicator.R` into `R/determinism.R` before indicator-adjacent bundle or
   adapter work lands, without changing public APIs, hashes, feature IDs,
   exports, or documentation output.

Secondary goals:

- Refresh stale v0.1.7 wording in v0.1.8.x documentation.
- Add a clearer installed-documentation entry point for core workflows.
- Keep metric context, sweep optimization, grid QoL, parallel dispatch, target
  risk, and OMS/policy-pipeline work sequenced into their roadmap releases.
- Keep auditr harness friction separate from ledgr package defects.

---

## 4. Theme Routing

### THEME-002: Feature, Indicator, And Warmup Contracts

**Status:** In scope.
**Priority:** Highest auditr priority.

Auditr rows cluster around feature IDs, aliases, built-in versus custom
indicator signatures, feature maps versus lists, warmup feasibility, current
bar requirements, pre-registration, feature factories, and inspection helpers.

Required v0.1.8.1 outcome:

- A compact feature lifecycle guide exists in installed documentation.
- The guide explains:
  - indicator construction;
  - feature IDs and aliases;
  - static feature lists/maps;
  - feature factories for sweeps;
  - warmup requirements and `stable_after`;
  - current-bar requirements separate from warmup;
  - how to inspect mapped features;
  - what live-object params errors mean.
- Help pages for core indicator and feature-inspection functions point to the
  guide or include enough local context to avoid isolated-page confusion.

Candidate rows include:

- built-in RSI `$fn` signature confusion;
- `ledgr_indicator()` scalar `fn(window, params)` documentation gap;
- feature-map/list acceptance mismatch in inspection helpers;
- impossible warmup only becoming clear after `summary(bt)`;
- static registration guidance conflicting with sweep feature factories;
- exact multi-output TTR feature ID debugging needs.

### THEME-001: Runnable First-Run And Vignette Examples

**Status:** In scope.
**Priority:** Highest auditr priority.

Users repeatedly needed to assemble runnable scripts from multiple sources or
found advertised runnable scripts that did not exercise the requested workflow.

Required v0.1.8.1 outcome:

- Installed first-run documentation has a runnable smoke-test workflow.
- The minimal `ledgr_run()` example prints or inspects a concrete result before
  closing resources.
- Representative runnable examples exist for:
  - basic `ledgr_run()`;
  - single-asset SMA crossover;
  - closed-trade and fill inspection;
  - custom scalar and vectorized indicators;
  - sweep candidate selection and promotion;
  - strategy recovery or reproducibility inspection where already documented.
- Runnable vignette scripts must either contain meaningful executable workflow
  code or not be advertised as runnable scripts.

This theme is documentation and example hygiene. It should not force a new
runtime API unless a documented example cannot be made honest without one.

### THEME-004: Result Inspection, Metrics, And Comparison Schemas

**Status:** In scope, docs-first.
**Priority:** High.

Printed outputs are useful for humans but users need clearer programmatic
schemas.

Required v0.1.8.1 outcome:

- Documentation distinguishes:
  - fills versus closed trades;
  - ledger/events versus fills/trades;
  - formatted print views versus raw numeric tibble columns;
  - summary side effects versus return value;
  - `ledgr_compute_metrics()` fields versus sweep result fields.
- Help pages or vignettes list the important raw columns for:
  - `ledgr_compare_runs()`;
  - `ledgr_results()`;
  - `ledgr_compute_metrics()`;
  - `summary.ledgr_backtest`;
  - sweep result rows and promotion context.
- Ranking examples explain sign conventions such as max drawdown being a
  negative return.
- Summary and metrics documentation explicitly acknowledge the current
  risk-free-rate and annualization limitations, and route the full metric
  context fix to v0.1.8.2:
  - installed docs should describe current behavior, such as the current
    risk-free-rate assumption and cadence-based annualization estimate, without
    promising a specific future version to users;
  - v0.1.8.1 must not introduce partial metric-context storage or a second
    annualization source.

Auditr includes missing-api rows in this area, such as exposing persisted
feature values through `ledgr_results(..., what = "features")` or adding
`final_equity` to `ledgr_compute_metrics()`. These are not automatically in
scope. They require maintainer decision at ticket cut because they expand public
API.

### THEME-003: Strategy Helper Pipeline

**Status:** In scope.
**Priority:** High.

Users can use the helper pipeline, but the path from individual helper pages to
a full experiment is too fragmented.

Required v0.1.8.1 outcome:

- Add a complete multi-asset helper-pipeline example.
- Add a compact troubleshooting table covering:
  - empty selections;
  - partial selections;
  - out-of-universe weights;
  - missing or malformed strategy targets;
  - zero-trade diagnosis;
  - Tier 2/Tier 3 preflight surprises;
  - parameters that change helper behavior.
- Clarify when signals/helpers are optional authoring conveniences and when a
  strategy can directly return target holdings.

Runtime changes should be narrow and message-focused unless ticket cut confirms
an actual helper behavior bug.

### THEME-006: Sweep, Promotion, Precompute, And Seed Workflows

**Status:** In scope.
**Priority:** High.

v0.1.8 sweep works, but auditr exposed documentation gaps in the newly shipped
surface.

Required v0.1.8.1 outcome:

- The getting-started docs no longer imply sweep execution is deferred.
- The sweeps vignette and help pages cover:
  - failure rows and promotion rejection;
  - list-column export guidance;
  - feature factories;
  - precomputed feature payload structure;
  - per-candidate `feature_set_hash`;
  - cross-snapshot promotion and the required opt-in;
  - stochastic seed replay with `execution_seed`;
  - promotion context schema, including `candidate_summary`.
- Runnable sweeps scripts must contain real sweep code or not be advertised as
  runnable.
- The empty `LEDGR_DOCS/scripts/sweeps.R` finding is a priority quick fix
  because it appeared in multiple episodes: either populate it with a minimal
  runnable sweep/candidate/promotion workflow or stop listing it as runnable.

Candidate message polish:

- Cross-snapshot promotion mismatch should name `require_same_snapshot = FALSE`
  and point to the train/test workflow.
- The duplicated generic classes emitted by the `stop_on_error = TRUE` failure
  path should be treated as a small runtime bug, not a user-education issue:
  normalize the class vector if confirmed by code review, and document
  `inherits(e, "ledgr_strategy_error")` as the robust user assertion pattern.

### THEME-009: Terse Or Ambiguous Warnings And Errors

**Status:** In scope after validation.
**Priority:** Medium-high.

Auditr found warnings that were technically correct but under-explained.

Required v0.1.8.1 outcome:

- Improve selected warnings/errors to include:
  - origin;
  - consequence;
  - next diagnostic action.
- At minimum, validate and route rows concerning:
  - `LEDGR_LAST_BAR_NO_FILL`;
  - leakage/causal vectorized feature guidance;
  - OHLC CSV validation locality;
  - Tier 3 wording implying an override may exist;
  - same-ID indicator replacement guidance.
- Tier 3/preflight tickets must verify the runtime path, not only prose. Tier 3
  strategies must not be accepted silently or downgraded to warning-only
  behavior.

Potential public validators for causal vectorized features are backlog design
items unless separately scoped. They should not enter v0.1.8.1 silently through
message-polish work.

### THEME-005: Snapshot, Sealing, And Metadata Docs

**Status:** In scope.
**Priority:** Medium.

Users can create and inspect snapshots, but the low-level path and metadata
schema need clearer field-level examples.

Required v0.1.8.1 outcome:

- Add or expand a low-level CSV snapshot/sealing walkthrough.
- Show both `ledgr_snapshot_info(snapshot)` and lower-level
  `ledgr_snapshot_info(con, snapshot_id)` forms where supported.
- Document snapshot/seal metadata field names consistently:
  - public info columns such as `bar_count` and `instrument_count`;
  - `meta_json` names such as `n_bars` and `n_instruments`, if still present.
- Improve CSV validation errors if maintainer review confirms low locality is a
  runtime defect rather than an acceptable coarse validation error.

### THEME-007: Version And Discoverability Signals

**Status:** In scope.
**Priority:** Medium-low.

Users saw stale v0.1.7 references in v0.1.8 workflows and had to discover
articles through scattered links.

Required v0.1.8.1 outcome:

- Refresh stale v0.1.7 wording where v0.1.8.x behavior has changed.
- Add or improve a central installed documentation index for current workflows.
- Replace source-tree design-file pointers in user-facing docs with installed
  help, articles, or rendered contract references.

### THEME-008: Runner And Local Environment Friction

**Status:** Mostly out of ledgr package scope.
**Priority:** Low.

Rows in this theme concern UTF-8 BOMs in temporary helper scripts, locked log
files during recursive search, guessed help snapshot filenames, and too-short
outer timeouts.

Required v0.1.8.1 outcome:

- Do not treat these as ledgr package bugs without raw evidence.
- If the repo contains auditr task templates or runner guidance, it may be
  updated separately.
- ledgr package tickets should only reference THEME-008 when a concrete package
  doc can reduce avoidable user confusion.

### LDG-2201 Routing Gate Disposition

LDG-2201 closes the initial routing gate. Implementation tickets may refine
wording and tests, but they should not reopen release scope without a spec
amendment.

| Theme | Disposition | Ticket |
| --- | --- | --- |
| THEME-001 runnable examples | In scope | LDG-2203 |
| THEME-002 feature/indicator/warmup contracts | In scope | LDG-2202 |
| THEME-003 strategy helper pipeline | In scope | LDG-2205 |
| THEME-004 result inspection/metrics schemas | In scope, docs-first | LDG-2204 |
| THEME-005 snapshot/sealing metadata | In scope | LDG-2207 |
| THEME-006 sweep/promotion/precompute/seed workflows | In scope | LDG-2206 |
| THEME-007 discoverability/version labels | In scope | LDG-2209 |
| THEME-008 runner/local environment friction | Mostly out of ledgr package scope | No primary implementation ticket; referenced only if a package doc can reduce avoidable confusion |
| THEME-009 warnings/errors | In scope after validation | LDG-2208, with coordination into LDG-2202 and LDG-2207 where the row is feature or snapshot specific |
| Indicator determinism extraction | Accepted internal refactor for v0.1.8.1 | LDG-2212; must land before LDG-2210 and other indicator-adjacent code work |
| Multi-output indicator bundle UX | Accepted roadmap add-on for v0.1.8.1 | LDG-2210 |
| Release validation | In scope | LDG-2211 |

---

## 5. Missing-API Rows

The auditr packet includes several `missing_api` rows. v0.1.8.1 should not
automatically implement them.

Rows requiring explicit maintainer decision:

- `ledgr_results(bt, what = "features")` for persisted feature values;
- a public causal validator for vectorized `series_fn` indicators;
- `final_equity` in `ledgr_compute_metrics()`;
- a public annualization constant for Sharpe-ratio verification;
- possibly richer installed documentation indexes or generated help
  navigation helpers if treated as API rather than docs.

Default disposition for this spec:

- document the current supported path if one exists;
- add public API only if ticket cut confirms it is small, coherent, and needed
  to satisfy an existing public contract;
- otherwise move to horizon or a later roadmap cycle.

LDG-2201 maintainer dispositions:

| Missing or proposed API | v0.1.8.1 disposition | Follow-up owner |
| --- | --- | --- |
| `ledgr_results(bt, what = "features")` for persisted feature values | Deferred. Do not add a new `ledgr_results()` result kind in v0.1.8.1. LDG-2202 and LDG-2204 should document the supported inspection paths and note the absence of a committed public persisted-feature table accessor. | Future feature inspection/results API design, if still needed after documentation pass |
| Public causal validator for vectorized `series_fn` indicators | Deferred. Do not add a public validator in v0.1.8.1. LDG-2202 and LDG-2208 should clarify current causal expectations, preflight limits, and diagnostics. | Future feature QA/causality design |
| `final_equity` in `ledgr_compute_metrics()` | Deferred. Do not change the metrics object schema in v0.1.8.1. LDG-2204 should document where final equity is available today, including equity results and sweep rows. | Future metrics schema/metric-context work if a schema change is justified |
| Public annualization constant or bars-per-year accessor for Sharpe verification | Deferred to metric-context design. LDG-2204 should document current behavior: risk-free rate is currently fixed by the existing metric path and annualization is inferred from cadence. No second annualization source should be introduced in v0.1.8.1. | v0.1.8.2 metric context/risk-free-rate work |
| Richer installed documentation indexes or navigation helpers | Documentation-only improvements are in scope under LDG-2209. Do not add a public runtime helper unless a later ticket explicitly scopes it. | LDG-2209 for docs; future API only if separately specified |

---

## 6. Accepted Internal Refactor: Indicator Determinism Extraction

v0.1.8.1 includes Phase 1 from
`rfc/rfc_indicator_codebase_simplification_v0_1_8_x_synthesis.md`.

Required outcome:

- add pre-refactor fingerprint-stability pins;
- add pre-refactor feature-factory identity pins;
- create `R/determinism.R`;
- move only the accepted package-level determinism/fingerprint helpers out of
  `R/indicator.R`:
  - `ledgr_deparse_one()`;
  - `ledgr_static_function_signature()`;
  - `ledgr_stable_payload()`;
  - `ledgr_function_fingerprint()`;
  - `ledgr_are_params_deterministic()`;
  - `ledgr_assert_indicator_fn_pure()`;
  - `ledgr_assert_indicator_safe()`;
- keep `ledgr_indicator_fingerprint()`, `ledgr_feature_id()`,
  `ledgr_indicator()`, print methods, and indicator registry functions in
  `R/indicator.R`;
- preserve all current feature IDs, fingerprints, feature-cache keys,
  feature-set hashes, strategy registry/config identity, error classes,
  exports, and generated documentation output.

Sequencing:

- This ticket must land before multi-output bundle or talib-adapter work that
  touches `ledgr_function_fingerprint()` or indicator fingerprints.
- Pins must be added and pass before moving functions.
- The move is complete only if pins still pass after the move.

Required identity gates:

- hard pins for built-in indicators, a local `ledgr_adapter_r()` closure,
  `ledgr_function_fingerprint()` over a local strategy closure, and
  `ledgr_feature_engine_version()`;
- version-conditional pins for TTR indicators, keyed to the recorded
  `packageVersion("TTR")`;
- a feature-factory identity pin using:

```r
features = function(params) list(ledgr_ind_sma(params$n))
grid <- ledgr_param_grid(short = list(n = 10L), long = list(n = 20L))
```

The feature-factory test should use the existing deterministic sweep fixture
shape (`ledgr_sweep_test_bars()`, extracted if needed) and pin candidate feature
fingerprints and feature-set hashes.

Non-goals for this refactor:

- no public API changes;
- no hash changes;
- no file renames beyond adding `R/determinism.R`;
- no `R/indicator_dev.R` split;
- no `ledgr_pulse_features()` input broadening;
- no feature-shape normalization;
- no documentation rewrite.

## 7. Accepted Roadmap Add-On: Multi-Output Indicator Bundle UX

v0.1.8.1 includes the accepted multi-output indicator authoring bundle from
`rfc/rfc_multi_output_indicator_ux_synthesis.md`.

Required outcome:

- add an authoring-layer bundle helper for multi-output indicators;
- flatten bundles into ordinary single-output feature definitions at feature
  declaration boundaries;
- preserve output-specific feature IDs and fingerprints;
- keep existing single-output indicators and adapters backward compatible;
- use a derived default prefix from the source function name, with normalized
  lowercase output names;
- support explicit raw output names only as an opt-in.

Non-goals for this add-on:

- no runtime multi-output feature object;
- no grouped precompute batching;
- no `multi_series_fn` execution path;
- no discovery helpers beyond the ticketed bundle UX;
- no change to sweep provenance or feature-set hashing semantics.

---

## 8. Non-Goals

v0.1.8.1 auditr-first scope must not silently include:

- public parallel sweep;
- single-core sweep performance optimization;
- Rcpp/Fortran acceleration;
- parameter-grid quality-of-life helpers or a grid DSL;
- metric context, risk-free-rate storage, or `metric_kernel` integration;
- target-risk layers, risk chains, or risk adapter helpers;
- execution-policy, order-policy, public cost/liquidity chains, OMS, or
  audit-signal retention tiers;
- walk-forward, PBO, or CSCV workflows;
- workflow template generation;
- `ledgr_tune()`;
- `ledgr_snapshot_split()`;
- paper/live adapters;
- new objective/ranking ownership in `ledgr_sweep()`;
- broad public feature-retrieval or causality-validation APIs without ticketed
  maintainer approval.
- indicator codebase Phase 2 cleanup, including file renames,
  `R/indicator_dev.R` splitting, or `R/pulse-snapshot.R` extraction.

Further roadmap work requires an explicit spec amendment. This spec intentionally
keeps v0.1.8.2+ roadmap items out of v0.1.8.1.

---

## 9. Documentation Standards For This Cycle

v0.1.8.1 documentation should follow these standards:

1. Installed docs must be enough. A user should not need source-tree design
   files to complete ordinary workflows.
2. Conceptual vignettes may exist, but advertised runnable scripts must contain
   meaningful executable code.
3. Examples should close the loop by showing at least one inspected result.
4. Printed views must be distinguished from raw programmatic data.
5. Strict contracts should be paired with diagnostics and next actions.
6. Feature, snapshot, and sweep lineage terms should be used consistently.
7. Tidyverse-adjacent examples are acceptable when the vignette or README loads
   the relevant package explicitly.

---

## 10. Candidate Ticket Tracks

Ticket cut should convert this spec into a small number of coherent tracks:

1. **Scope routing and duplicate disposition**
   - Confirm every auditr theme has an explicit route.
   - Record which missing-api rows are deferred.
   - This track must complete before ticket cut begins for implementation
     tracks.

2. **Indicator determinism extraction**
   - Implement the accepted Phase 1 refactor from
     `rfc_indicator_codebase_simplification_v0_1_8_x_synthesis.md`.
   - Must land before Track 11 bundle work or any talib-adapter work touching
     indicator fingerprinting.
   - Acceptance criteria must include pre-refactor pins, two-tier fingerprint
     stability tests, the feature-factory identity pin, no public API changes,
     no hash drift, and no unexpected `man/*.Rd` diffs.

3. **Feature lifecycle and warmup guide**
   - Address THEME-002 and related parts of THEME-009.
   - Coordinate with Track 11 so bundle flattening, derived feature IDs, and
     when to use bundle helpers versus single-output adapters are taught in the
     lifecycle guide rather than duplicated inconsistently.

4. **Runnable examples and first-run workflow**
   - Address THEME-001 and stale runnable-script findings.

5. **Result inspection and metrics schemas**
   - Address THEME-004 and decide missing-api rows.

6. **Strategy helper pipeline documentation**
   - Address THEME-003.

7. **Sweep documentation polish**
   - Address THEME-006.

8. **Snapshot and metadata documentation**
   - Address THEME-005.

9. **Warning/error message polish**
   - Address validated THEME-009 rows.

10. **Discoverability and version labels**
   - Address THEME-007.

11. **Multi-output indicator bundle authoring**
    - Implement the accepted bundle UX without changing the core feature series
      contract.
    - Acceptance criteria must cite the synthesis test requirements, including
      ordinary-indicator materialization, unique feature IDs, output-specific
      fingerprints, and unchanged existing single-output IDs/fingerprints.
    - Function-level help should link to the Track 3 lifecycle guide rather than
      becoming a second conceptual guide.

12. **Release gate**
    - Verify docs, examples, tests, NEWS, site build, and package check.

No other roadmap-feature tickets should be added to v0.1.8.1 unless this spec
is explicitly amended.

---

## 11. Verification Strategy

v0.1.8.1 verification should include:

- targeted tests for any runtime message or API behavior changed by a ticket;
- documentation contract tests for new links, examples, and required wording;
- fingerprint-stability and feature-factory identity pins for the determinism
  extraction refactor;
- runnable script checks for examples advertised as runnable;
- pkgdown build;
- full `testthat` run;
- `R CMD check --no-manual --no-build-vignettes`;
- spot-checks of installed help pages for the workflows auditr exercised.

For docs-only tickets, verification may be primarily documentation contract
tests plus manual rendered-doc review. For message/API tickets, targeted tests
must assert the new behavior directly.

---

## 12. Definition Of Done

v0.1.8.1 is done when:

- every v0.1.8 auditr theme has an explicit disposition;
- the accepted indicator determinism extraction has shipped before
  indicator-adjacent bundle/adapter work or has been explicitly deferred by
  maintainer decision before such work starts;
- the accepted multi-output indicator bundle UX has either shipped or been
  explicitly deferred by maintainer decision;
- medium-severity documentation gaps are either fixed or deliberately deferred;
- missing-api rows have maintainer decisions;
- first-run, feature lifecycle, result inspection, helper pipeline, sweep, and
  snapshot workflows are teachable from installed documentation;
- stale v0.1.7 wording no longer contradicts v0.1.8.x behavior;
- runnable scripts advertised to users are genuinely runnable;
- `NEWS.md` documents the patch release, including new public API, behavioral
  changes, notable documentation/example additions, and runtime bug fixes;
- release-gate tests and package checks pass.
