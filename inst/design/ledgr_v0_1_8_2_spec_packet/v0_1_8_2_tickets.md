# ledgr v0.1.8.2 Tickets

Version: v0.1.8.2
Date: 2026-05-24
Total Tickets: 13

## Ticket Organization

This packet implements the scoped v0.1.8.2 plan from `v0_1_8_2_spec.md`:
metric context and risk-free-rate assumptions, the auditr-routed strategy
preflight contract fix, selected documentation/message polish from the auditr
cycle, and optional indicator codebase Phase 2 cleanup if the routing gate
keeps it in scope.

`LDG-2301` is intentionally preserved as a pre-spec research ticket. It is not
a dependency for v0.1.8.2 implementation. It records tidyfinance unit semantics
for future external reference-data adapter design only.

## Dependency DAG

```text
LDG-2301 Run tidyfinance unit probe   (independent research; not release-blocking)

LDG-2302 Scope routing and maintainer decision gate
  |-- LDG-2303 Strategy preflight contract alignment
  |-- LDG-2304 Metric context constructors and hashing
  |     `-- LDG-2306 Experiment and run metric-context storage
  |-- LDG-2305 Calendar constructors and annualization policy
  |     `-- LDG-2307 Metric kernel, summary, and single-run metrics
  |           `-- LDG-2308 Comparison and sweep metric-context threading
  |                 `-- LDG-2309 Promotion context metric disclosure
  |-- LDG-2310 Metric-context docs and inspection updates
  |-- LDG-2311 Auditr docs and message polish
  `-- LDG-2312 Indicator codebase Phase 2 cleanup

LDG-2313 Release gate depends on LDG-2303 through LDG-2312.
```

## Priority Levels

- P0: Release gate, scope gate, or implementation blocker.
- P1: User-facing correctness, runtime contract, persistence/schema work, or
  accepted public surface.
- P2: Documentation, message polish, internal cleanup, or exploratory research.

---

## LDG-2301: Run tidyfinance Unit Probe And Record Findings

Priority: P2
Effort: S
Dependencies: none
Status: Todo

### Description

Run the tidyfinance unit probe and record empirical findings before any future
external reference-data adapter RFC or ticket assumes provider output
semantics.

This ticket is intentionally research-only. It answers what upstream
`tidyfinance` functions return for risk-free rates, stock prices, and
optionally Fama-French factors. It does not implement ledgr adapters, change
metric context, add beta, or add runtime data-download behavior.

### Tasks

- Run SPIKE-1 in `inst/design/spikes/ledgr_tidyfinance_unit_probe/README.md`
  for risk-free output semantics.
- Run SPIKE-2 for stock-price output semantics and benchmark-return
  feasibility.
- Optionally run SPIKE-3 if Fama-French factor discovery is quick; otherwise
  record it as not run.
- Run the required probes on Windows native R and Ubuntu/WSL, or record the
  platform-specific blocker if one platform cannot run.
- Record findings in the spike README under the appropriate `Findings`
  subsections.
- Record exact package versions, observed columns, units, cadence/gap behavior,
  and platform differences.
- Do not add any ledgr runtime function, public adapter, dependency, or
  metric-context integration.

### Acceptance Criteria

- SPIKE-1 findings state whether `download_data_risk_free()` returns
  annualized or period values, decimal or percent units, and how date gaps are
  represented for the tested tidyfinance version.
- SPIKE-2 findings state which stock-price columns are present, whether
  `adjusted_close` is usable as the future benchmark-return default, and what
  split/dividend behavior was observed.
- SPIKE-3 is either completed with canonical type names and unit findings, or
  explicitly marked as not run because it remains optional.
- Findings include Windows and Ubuntu/WSL results or documented platform
  blockers.
- The ticket produces design memory only: no R package runtime files, exported
  APIs, DESCRIPTION dependency changes, or committed raw data artifacts.

### Verification

Manual review of the spike README findings and `git diff --check`.

### Source Reference

- `inst/design/spikes/ledgr_tidyfinance_unit_probe/README.md`
- `inst/design/horizon.md`
- `inst/design/rfc/rfc_risk_free_rate_metric_context_v0_1_8_1_synthesis.md`

### Classification

```yaml
type: research
surface: external_reference_data
scope: pre_spec
```

---

## LDG-2302: Scope Routing And Maintainer Decision Gate

Priority: P0
Effort: S
Dependencies: none
Status: Todo

### Description

Close the remaining v0.1.8.2 scope and policy decisions before runtime
implementation begins. This ticket converts the draft spec, auditr triage, and
accepted syntheses into a final synchronized ticket plan.

### Tasks

- Review `v0_1_8_2_spec.md`, `categorized_feedback.yml`,
  `ledgr_triage_report.md`, `cycle_retrospective.md`, `inst/design/README.md`,
  and `inst/design/ledgr_roadmap.md`.
- Decide whether `ledgr_risk_free_rate()` ships in v0.1.8.2 or defers.
- Decide whether `ledgr_risk_free_series()` remains design-only or whether any
  bounded implementation is allowed.
- Decide whether `ledgr_compare_runs(exp, ...)` ships, or whether v0.1.8.2
  keeps the required snapshot-first `metric_context = NULL` path only.
- Decide resolved external scalar strategy policy: `tier_2` with docs, or
  `tier_3` under a stricter params-boundary.
- Decide bundle ID asymmetry policy: document shipped v0.1.8.1 IDs, or amend
  identity policy.
- Decide high-level CSV error class policy: document actual high-level classes,
  or add a shared CSV parent class if small.
- Confirm whether indicator codebase Phase 2 remains in v0.1.8.2 scope.
- Keep `v0_1_8_2_tickets.md`, `tickets.yml`, and spec routing synchronized.

### Acceptance Criteria

- Every pending decision in spec Sections 3 and 10 has an explicit maintainer
  disposition.
- Deferred items name the future milestone or horizon/RFC home.
- No external reference-data adapter, beta API, benchmark API, grid helper,
  helper-sharing API, parallel sweep, target-risk, OMS, walk-forward, or
  random-slice work is pulled into v0.1.8.2 without spec amendment.
- Ticket statuses and dependencies are synchronized in markdown and YAML.

### Verification

Manual packet review and `git diff --check`.

### Source Reference

- `inst/design/ledgr_v0_1_8_2_spec_packet/v0_1_8_2_spec.md`
- `inst/design/ledgr_v0_1_8_2_spec_packet/categorized_feedback.yml`
- `inst/design/ledgr_v0_1_8_2_spec_packet/ledgr_triage_report.md`
- `inst/design/ledgr_v0_1_8_2_spec_packet/cycle_retrospective.md`

### Classification

```yaml
type: governance
surface: design_packet
scope: v0.1.8.2
```

---

## LDG-2303: Strategy Preflight Contract Alignment

Priority: P1
Effort: M
Dependencies: LDG-2302
Status: Todo

### Description

Fix the auditr-confirmed preflight contract gap. Strategies using forbidden
nondeterministic calls such as `Sys.time()` must fail early through the Tier 3
preflight path, not later through `ledgr_config_non_deterministic`. Strategies
using global assignment (`<<-`) must not execute and write completed runs.

### Tasks

- Align `ledgr_strategy_preflight()` with the determinism forbidden-call
  policy. Prefer sharing the determinism forbidden-call list rather than
  duplicating it.
- Add explicit `<<-` detection before execution.
- Preserve no-force wording and condition classes:
  `ledgr_strategy_tier3` and `ledgr_strategy_preflight_error`.
- Apply the maintainer decision from LDG-2302 for resolved external scalars.
- Update reproducibility and strategy-development prose for the final policy.
- Add regression tests for `Sys.time()`, `Sys.Date()` if appropriate,
  `Sys.getenv()` if appropriate, `<<-`, and resolved external scalars.
- Verify `ledgr_run()` and `ledgr_sweep()` reject Tier 3 strategies before
  writing run/candidate artifacts.

### Acceptance Criteria

- Forbidden nondeterministic calls fail through preflight with
  `ledgr_strategy_tier3` / `ledgr_strategy_preflight_error`.
- The late `ledgr_config_non_deterministic` path is no longer the first user
  error for these strategies.
- `<<-` strategies do not produce completed runs or sweep candidates.
- Resolved external scalar behavior matches the LDG-2302 policy decision.
- Documentation and tests agree on Tier 1, Tier 2, Tier 3, helper reuse, and
  no-force behavior.

### Verification

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-strategy-preflight.R'); testthat::test_file('tests/testthat/test-sweep.R'); testthat::test_file('tests/testthat/test-backtest-wrapper.R')"
```

### Source Reference

- `v0_1_8_2_spec.md` Sections 10 and 13
- `inst/design/contracts.md` strategy reproducibility section
- `R/strategy-preflight.R`
- `R/determinism.R`

### Classification

```yaml
type: bugfix
surface: strategy_preflight
scope: runtime_contract
```

---

## LDG-2304: Metric Context Constructors, Validation, And Hashing

Priority: P1
Effort: M
Dependencies: LDG-2302
Status: Todo

### Description

Add the public metric-context object surface and stable serialization identity
for metric assumptions.

### Tasks

- Implement `ledgr_metric_context()`.
- Implement `ledgr_metric_us_equity()` and `ledgr_metric_crypto()` templates.
- Implement `ledgr_metric_context_resolve()`.
- Implement `ledgr_metric_context_hash()` and schema version handling.
- If accepted by LDG-2302, implement `ledgr_risk_free_rate()`; otherwise
  explicitly defer it in docs/spec notes.
- Validate scalar risk-free rates as finite annual values greater than `-1`.
- Reserve `benchmark`, `market_factor`, and `mar` fields as `NULL` provider
  slots without implementing providers.
- Use `canonical_json()` for stable hashing, omit NULL reserved fields from
  hash input, and normalize dates to ISO strings.
- Add S3 accessor/generic support for constructor/accessor behavior where
  needed.

### Acceptance Criteria

- Metric-context objects validate inputs and reject ambiguous or invalid
  assumptions.
- Hashes are stable under list insertion order and omit NULL reserved fields.
- `metric_context_version` is an integer schema version with initial value `1`.
- No external provider lookup or hidden download is introduced.
- Public templates are the primary UX path in docs/examples.

### Verification

Targeted metric-context constructor/hash tests and `git diff --check`.

### Source Reference

- `v0_1_8_2_spec.md` Sections 3, 4, and 6
- `inst/design/rfc/rfc_risk_free_rate_metric_context_v0_1_8_1_synthesis.md`
- `R/config-canonical-json.R`

### Classification

```yaml
type: feature
surface: metric_context
scope: public_api
```

---

## LDG-2305: Calendar Constructors And Annualization Policy

Priority: P1
Effort: M
Dependencies: LDG-2302
Status: Todo

### Description

Add explicit calendar objects for annualization and preserve legacy inference
only as a compatibility fallback.

### Tasks

- Implement `ledgr_calendar()`.
- Implement `ledgr_calendar_us_equity()` and `ledgr_calendar_crypto()`.
- Support `bars_per_day` for intraday US equity calendars.
- Document that the default metric context uses US equity daily calendar.
- Keep existing inference as a fallback for legacy/no-context paths.
- Add diagnostic warnings when observed data frequency appears inconsistent
  with a supplied calendar.
- Document the current intraday `snap_to_frequency()` footgun and the explicit
  calendar fix.

### Acceptance Criteria

- Daily US equity defaults preserve today's 252-period behavior.
- US equity minute bars can be represented as `252 * 390`.
- Crypto calendar support is explicit and not inferred from ticker symbols.
- Fallback inference is documented as imprecise for intraday and unusual
  calendars.
- Summary/print surfaces can label the calendar source and decomposition.

### Verification

Calendar constructor tests, annualization tests, and documentation contract
tests for calendar labels and intraday warnings.

### Source Reference

- `v0_1_8_2_spec.md` Section 5
- `R/fold-core.R`
- `R/backtest.R`

### Classification

```yaml
type: feature
surface: annualization
scope: public_api
```

---

## LDG-2306: Experiment And Run Metric-Context Storage

Priority: P1
Effort: L
Dependencies: LDG-2304, LDG-2305
Status: Todo

### Description

Thread resolved metric context into experiments and runs as analysis metadata,
excluding it from execution identity.

### Tasks

- Add `metric_context = NULL` and `risk_free_rate = NULL` to
  `ledgr_experiment()`.
- Reject calls that provide both `metric_context` and `risk_free_rate`.
- Store the resolved metric context on the `ledgr_experiment` object.
- Add `metric_context_json`, `metric_context_hash`, and
  `metric_context_version` to run storage.
- Persist resolved run metric context at run creation or successful run
  finalization, not lazily in metric computation.
- Add legacy-run fallback behavior for runs without stored metric context.
- Prove metric context does not enter execution config hash, strategy hash,
  snapshot hash, feature-set hash, seed derivation, fills, ledger rows, event
  ordering, or target validation.

### Acceptance Criteria

- New runs store recoverable metric context metadata.
- Old runs without metric context return a complete fallback context through
  accessors.
- Metric context storage failure does not roll back otherwise successful
  execution artifacts unless implementation review finds rollback safer.
- Existing default behavior is preserved when default context equals today's
  assumptions.
- Execution identity hashes remain unchanged by metric context changes.

### Verification

Experiment tests, run-store/schema tests, legacy fallback tests, and targeted
hash non-interference tests.

### Source Reference

- `v0_1_8_2_spec.md` Sections 4 and 6
- `R/experiment.R`
- `R/backtest-runner.R`
- `R/db-schema-create.R`
- `R/run-store.R`

### Classification

```yaml
type: persistence
surface: experiment_run_metadata
scope: v0.1.8.2
```

---

## LDG-2307: Metric Kernel, Summary, And Single-Run Metrics

Priority: P1
Effort: L
Dependencies: LDG-2304, LDG-2305, LDG-2306
Status: Todo

### Description

Replace hidden annualization/risk-free assumptions in single-run metric
computation with resolved metric context and a serialization-safe
`metric_kernel`.

### Tasks

- Implement `ledgr_metric_kernel()`.
- Ensure `metric_kernel` is a plain named list with no environments, closures,
  active bindings, live connections, external pointers, or reference semantics.
- Compute `bars_per_year` from explicit calendar or legacy fallback inference.
- Compute scalar `rf_period_return` as
  `(1 + annual_rate)^(1 / bars_per_year) - 1`.
- Update `ledgr_compute_metrics_internal()` to use stored run context by
  default, with call-time override support.
- Return a classed `ledgr_metrics` object that remains list-like for `$` and
  `[[`.
- Update `summary.ledgr_backtest()` to disclose risk-free-rate and calendar
  assumptions.

### Acceptance Criteria

- `ledgr_compute_metrics()` uses stored run context by default.
- Call-time overrides are ephemeral and do not mutate run metadata.
- Classed metric results support `ledgr_metric_context(metrics)`.
- Summary output prints zero risk-free-rate explicitly and names the
  annualization source.
- Legacy runs use documented fallback behavior.

### Verification

Metric tests, summary tests, serialization-safety tests, and documentation
contract tests for printed assumptions.

### Source Reference

- `v0_1_8_2_spec.md` Sections 7, 8, and 13
- `R/backtest.R`
- `R/fold-core.R`

### Classification

```yaml
type: feature
surface: metrics_summary
scope: public_api
```

---

## LDG-2308: Comparison And Sweep Metric-Context Threading

Priority: P1
Effort: L
Dependencies: LDG-2307
Status: Todo

### Description

Thread one metric context through comparison and sweep result tables. Replace
standalone `bars_per_year` in the sweep candidate path with `metric_kernel`.

### Tasks

- Add `metric_context = NULL` to `ledgr_compare_runs()` while preserving the
  required snapshot-first form.
- Apply the LDG-2302 decision for optional `ledgr_compare_runs(exp, ...)`
  support.
- Remove hardcoded `risk_free_rate = 0` from comparison metrics and consume
  the comparison metric context.
- Fail loudly on incompatible mixed-cadence comparisons.
- Add one sweep-level metric context to `ledgr_sweep()` result tables.
- Replace `bars_per_year` with `metric_kernel` in
  `ledgr_sweep_run_candidate()`.
- Preserve sweep result table-level metric context after tibble rebuilds.
- Keep metric context out of seed derivation and execution identity.

### Acceptance Criteria

- Comparison tables have exactly one metric context.
- Sweep tables have exactly one metric context.
- `ledgr_metric_context(comparison)` and `ledgr_metric_context(sweep)` recover
  the used context.
- Candidate metrics read annualization and risk-free assumptions from
  `metric_kernel`, not a separate `bars_per_year` parameter.
- Mixed-cadence comparisons fail with actionable wording.

### Verification

Comparison tests, sweep tests, metric-kernel threading tests, and promotion
candidate parity checks.

### Source Reference

- `v0_1_8_2_spec.md` Sections 7 and 8
- `R/run-store.R`
- `R/sweep.R`

### Classification

```yaml
type: feature
surface: comparison_sweep_metrics
scope: public_api
```

---

## LDG-2309: Promotion Context Metric Disclosure

Priority: P1
Effort: M
Dependencies: LDG-2308
Status: Todo

### Description

Record and disclose the metric context that produced a source sweep candidate
table separately from the metric context of the promoted run.

### Tasks

- Add source sweep metric-context fields to promotion context where applicable.
- Preserve the distinction between source sweep context, run context, and
  comparison context.
- Update accessors/print methods as needed so users can inspect promotion
  metric assumptions.
- Ensure promotion replay and same-snapshot verification examples remain valid.
- Confirm no promotion behavior changes execution identity or seed derivation.

### Acceptance Criteria

- Promoted runs can disclose the source sweep metric context used to rank the
  candidate.
- Run metric context remains the committed run's own default analysis context.
- The three-context vocabulary from the spec is reflected in docs/tests.

### Verification

Promotion-context tests and documentation contract tests.

### Source Reference

- `v0_1_8_2_spec.md` Section 8
- `R/promotion-context.R`
- `R/promote.R`

### Classification

```yaml
type: feature
surface: promotion_context
scope: provenance
```

---

## LDG-2310: Metric-Context Documentation And Inspection Updates

Priority: P2
Effort: M
Dependencies: LDG-2307, LDG-2308, LDG-2309
Status: Todo

### Description

Update installed docs, help pages, and inspection examples for metric context
and auditr findings that touch the same result/comparison/sweep/promotion
surfaces.

### Tasks

- Document metric-context templates, scalar shorthand, explicit context, and
  default US equity calendar.
- Explain annualization, risk-free-rate disclosure, intraday calendar warnings,
  and sensitivity-analysis workflow.
- Add compare-runs setup cue for experiment-store workflows.
- Add report-ready numeric comparison export example using `as.data.frame()` or
  tibble conversion.
- Add promotion replay verification example.
- Update invalid `ledgr_results(bt, what = "features")` guidance to point to
  `ledgr_pulse_snapshot()`.
- Add warning-handling guidance for sweeps, promotions, and final-bar no-fill
  warnings.

### Acceptance Criteria

- Users can discover which metric context produced summaries, metric results,
  comparisons, sweeps, and promoted candidate rankings.
- Docs do not promise external adapters, benchmark metrics, beta, or future
  sensitivity wrappers.
- Documentation contract tests pin the new public claims.

### Verification

Documentation contract tests, vignette render checks as needed, and stale
version/encoding scan.

### Source Reference

- `v0_1_8_2_spec.md` Sections 8, 10, and 13
- `vignettes/metrics-and-accounting.Rmd`
- `vignettes/sweeps.Rmd`
- `vignettes/experiment-store.Rmd`

### Classification

```yaml
type: documentation
surface: metric_context_inspection
scope: installed_docs
```

---

## LDG-2311: Auditr Documentation And Message Polish

Priority: P2
Effort: M
Dependencies: LDG-2302
Status: Todo

### Description

Implement the low-risk auditr docs/message polish that does not belong to
metric-context implementation.

### Tasks

- Add Yahoo snapshot sealing/idempotence example.
- Add Yahoo discoverability to the task-intent map.
- Document `ledgr_save_help()` scalar-only behavior or provide a loop example.
- Document partial bundle `naming` plus explicit `outputs`.
- Improve duplicate bundle-prefix collision wording.
- Improve timestamp errors to name `ts_utc`, UTC, and trailing-`Z` examples.
- Improve CSV validation messages to state artifact state and next action.
- Add final-bar warning extension verification example.
- In `vignettes/strategy-development.Rmd`, add fills extraction,
  zero-fill versus zero-closed-trade, pulse-level target-name `setdiff()`, and
  compact Tier 3 hard-failure examples.
- Add real-data flat, buy-and-hold, equal-weight, and single-instrument
  examples without introducing benchmark helper APIs.
- Route auditr environment friction to auditr guidance, not ledgr runtime.

### Acceptance Criteria

- All accepted low-risk auditr findings from spec Section 10.4 are addressed
  or explicitly deferred.
- No parameter-grid helper, helper-sharing API, benchmark API, or external
  adapter is introduced.
- Runtime message changes preserve existing condition classes unless LDG-2302
  explicitly approved a small class-boundary change.

### Verification

Documentation contract tests, targeted message tests if runtime strings change,
and encoding/stale-version scan.

### Source Reference

- `v0_1_8_2_spec.md` Section 10
- `inst/design/ledgr_v0_1_8_2_spec_packet/categorized_feedback.yml`

### Classification

```yaml
type: documentation
surface: auditr_polish
scope: installed_docs
```

---

## LDG-2312: Indicator Codebase Phase 2 Cleanup

Priority: P2
Effort: M
Dependencies: LDG-2302
Status: Todo

### Description

If retained by LDG-2302, complete the accepted Phase 2 indicator file/role
cleanup as a mechanical refactor only.

### Tasks

- Rename `R/indicators_builtin.R` to `R/indicator-builtins.R`.
- Rename `R/indicator_adapters.R` to `R/indicator-adapters.R`.
- Split `R/indicator_dev.R` into `R/indicator-dev.R` and
  `R/pulse-snapshot.R`.
- Preserve public APIs, feature IDs, fingerprints, exports, behavior, and
  error classes.
- Preserve `ledgr_invalid_args`, `ledgr_purity_violation`, and
  `ledgr_config_non_deterministic`.
- Accept only expected roxygen file-reference changes in generated Rd files.
- Do not broaden `ledgr_pulse_features()` input support or rename public
  functions.

### Acceptance Criteria

- Fingerprint-stability and feature-factory identity pins remain unchanged.
- Public exports remain unchanged.
- No behavior or documentation content changes occur outside expected file
  references.
- The indicator cluster has the target file shape described in the spec.

### Verification

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-fingerprint-stability.R'); testthat::test_file('tests/testthat/test-indicators.R'); testthat::test_file('tests/testthat/test-indicator-ttr.R'); testthat::test_file('tests/testthat/test-indicator-adapters.R'); testthat::test_file('tests/testthat/test-feature-cache.R'); testthat::test_file('tests/testthat/test-precompute-features.R'); testthat::test_file('tests/testthat/test-sweep.R'); testthat::test_file('tests/testthat/test-api-exports.R')"
```

Also run `devtools::document()` and review generated diffs.

### Source Reference

- `v0_1_8_2_spec.md` Section 9
- `inst/design/rfc/rfc_indicator_codebase_simplification_v0_1_8_x_synthesis.md`

### Classification

```yaml
type: refactor
surface: indicator_codebase
scope: internal
```

---

## LDG-2313: v0.1.8.2 Release Gate And Closeout

Priority: P0
Effort: S
Dependencies: LDG-2303, LDG-2304, LDG-2305, LDG-2306, LDG-2307, LDG-2308, LDG-2309, LDG-2310, LDG-2311, LDG-2312
Status: Todo

### Description

Close the v0.1.8.2 packet after all implementation and documentation tickets
land. This ticket verifies the release boundary, documentation, tests, NEWS,
site/build artifacts, and ticket metadata.

### Tasks

- Confirm all v0.1.8.2 implementation tickets are complete and statuses are
  synchronized in `v0_1_8_2_tickets.md` and `tickets.yml`.
- Update `NEWS.md` for metric context, risk-free-rate/annualization
  disclosure, preflight bug fixes, docs/message polish, and any retained
  indicator cleanup.
- Verify no deferred roadmap feature was implemented accidentally.
- Run targeted tests for changed surfaces.
- Run full local tests and package checks appropriate for a release gate.
- Run stale-version and encoding scans.
- Confirm no generated local artifacts or raw spike outputs are committed.

### Acceptance Criteria

- All ticket statuses and machine-readable metadata are synchronized.
- `NEWS.md` includes relevant v0.1.8.2 changes.
- Full test suite passes locally.
- Package check passes with agreed release flags.
- Documentation contract tests pass.
- Stale-version and encoding scans are clean.
- Deferred v0.1.8.3+ roadmap features remain out of scope.
- `LDG-2301` findings are either recorded or explicitly left as independent
  research, with no effect on release readiness.

### Verification

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" -e "pkgload::load_all('.', quiet=TRUE); testthat::test_local('.', reporter='summary')"
& "C:\Program Files\R\R-4.5.2\bin\x64\R.exe" CMD build .
& "C:\Program Files\R\R-4.5.2\bin\x64\R.exe" CMD check --no-manual --no-build-vignettes ledgr_<version>.tar.gz
```

### Source Reference

- `v0_1_8_2_spec.md`
- `inst/design/release_ci_playbook.md`

### Classification

```yaml
type: release_gate
surface: package
scope: v0.1.8.2
```
