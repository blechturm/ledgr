# ledgr v0.1.8.3 Tickets

Version: v0.1.8.3
Date: 2026-05-25
Total Tickets: 15

## Ticket Organization

This packet implements the scoped v0.1.8.3 plan from `v0_1_8_3_spec.md`:
empirically grounded single-core sweep optimization, plus the routed v0.1.8.2
auditr findings that fit this release.

The performance spine is:

```text
baseline protocol
  -> accounting parity gate
  -> projection interface and R-memory backend
  -> shared fold projection consumption and parity gates
  -> fast context B1
  -> pulse context data model consolidation
  -> post-LDG-2413 measurement and maintainer decision
  -> typed memory events and single-pass summary if retained
  -> residual hot-path report
```

The original projection synthesis allowed typed events and B1 to be sequenced by
measurement. The LDG-2409 checkpoint measured helper churn as the larger
remaining fold slice, so LDG-2411 now lands before LDG-2410. The accepted
pulse-context data model consolidation synthesis rescopes LDG-2413 from a
narrow B2 proxy ticket to prebuilt static pulse views, with LDG-2414 providing
the measurement evidence for the LDG-2410 / LDG-2412 disposition decision.

The auditr spine is deliberately separate:

```text
preflight indirection hardening
  -> preflight/docs boundary polish
  -> metric-context docs/display polish
  -> sweep inspection and real-data docs polish
```

No active aliases, alias-map identity, parameter-grid helpers, sweep ranking
helpers, full sweep artifact persistence, DuckDB-backed precompute storage,
out-of-core projection, DuckDB indicator computation, parallel dispatch, target
risk, walk-forward, cost/liquidity, OMS, paper/live, benchmark, or
external-reference-data adapter work is in scope unless the maintainer amends
the spec.

## Dependency DAG

```text
LDG-2401 Scope Routing, Packet Setup, And Auditr Decisions
  |-- LDG-2402 Performance Protocol And v0.1.8.2 Baseline
  |     |-- LDG-2408 Runtime Projection Interface And R-Memory Backend
  |     |     `-- LDG-2409 Shared Fold Projection Consumption And Parity Gate
  |     |           |-- LDG-2411 Fast Context B1 Pulse Helper Reuse
  |     |           |     `-- LDG-2413 Pulse Context Data Model Consolidation
  |     |           |           `-- LDG-2414 Post-Change Measurement And Residual Report
  |     |           |-- LDG-2410 Typed Memory Event Representation
  |     |           |     `-- LDG-2412 Single-Pass Sweep Summary Reconstruction
  |     |           `-- LDG-2414 Post-Change Measurement And Residual Report
  |     `-- LDG-2414 Post-Change Measurement And Residual Report
  |-- LDG-2403 Persistent-Versus-Memory Accounting Parity Gate
  |     |-- LDG-2408 Runtime Projection Interface And R-Memory Backend
  |     |-- LDG-2409 Shared Fold Projection Consumption And Parity Gate
  |     |-- LDG-2410 Typed Memory Event Representation
  |     |-- LDG-2411 Fast Context B1 Pulse Helper Reuse
  |     |-- LDG-2412 Single-Pass Sweep Summary Reconstruction
  |     `-- LDG-2413 Pulse Context Data Model Consolidation
  |-- LDG-2404 Strategy Preflight Indirection Hardening
  |     `-- LDG-2405 Preflight Documentation And Strategy-Boundary Polish
  |-- LDG-2406 Metric-Context Documentation And Display Polish
  `-- LDG-2407 Sweep Inspection, Export, And Real-Data Example Polish

LDG-2415 Release Gate depends on LDG-2401 through LDG-2414.
```

## Priority Levels

- P0: Release gate, scope gate, or implementation blocker.
- P1: User-facing correctness, runtime contract, performance spine, or
  persistence/accounting verification.
- P2: Documentation, message polish, inspection examples, or planning cleanup.

---

## LDG-2401: Scope Routing, Packet Setup, And Auditr Decisions

Priority: P0
Effort: S
Dependencies: none
Status: Done

### Description

Finalize the v0.1.8.3 packet after the v0.1.8.2 auditr report lands. This
ticket converts the spec, auditr triage, maintainer decisions, roadmap context,
and accepted optimization synthesis into a synchronized implementation plan.

### Tasks

- Update `v0_1_8_3_spec.md` so auditr input is no longer marked pending.
- Record maintainer decisions for:
  - constant-string and direct-function `do.call()` indirection;
  - `attr(ctx, ...) <- ...` context mutation;
  - captured mutable environment policy;
  - `ledgr_snapshot_seal()` return shape;
  - deferral of `ledgr_sweep_summary()` or equivalent flat-export helper.
- Cut `v0_1_8_3_tickets.md` and `tickets.yml`.
- Update `inst/design/README.md`, `inst/design/ledgr_roadmap.md`, and
  `AGENTS.md` so v0.1.8.3 is the active implementation packet.
- Confirm v0.1.8.2 is archival and no new runtime scope is added there.
- Preserve the performance-release thesis: auditr fixes are scoped bug/docs
  work, not permission to implement deferred API surfaces.

### Acceptance Criteria

- Spec, ticket markdown, and `tickets.yml` agree on ticket ids, statuses,
  dependencies, and scope.
- Every accepted auditr finding has a ticket, a deferral, or an explicit
  rejection.
- Deferred public API ideas name their future roadmap/horizon home.
- Design index, roadmap, and agent notes point to v0.1.8.3 as active.

### Verification

Manual packet review and `git diff --check`.

### Source Reference

- `v0_1_8_3_spec.md`
- `categorized_feedback.yml`
- `ledgr_triage_report.md`
- `cycle_retrospective.md`
- `inst/design/rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md`

### Classification

```yaml
type: governance
surface: design_packet
scope: v0.1.8.3
```

### Completion Notes

- Updated `v0_1_8_3_spec.md` so the v0.1.8.2 auditr input is routed rather
  than pending, with explicit decisions for `do.call()` indirection,
  `attr(ctx, ...) <- ...` mutation, captured mutable environments,
  `ledgr_snapshot_seal()` return shape, and `ledgr_sweep_summary()` deferral.
- Cut the v0.1.8.3 ticket packet with `LDG-2401` through `LDG-2415` in
  `v0_1_8_3_tickets.md` and synchronized machine-readable metadata in
  `tickets.yml`.
- Updated `inst/design/README.md`, `inst/design/ledgr_roadmap.md`, and
  `AGENTS.md` so v0.1.8.3 is the active implementation packet and v0.1.8.2 is
  treated as archival release record.
- Confirmed accepted auditr findings route into preflight hardening, docs and
  message polish, explicit deferrals, or auditr-repo task drift rather than new
  v0.1.8.3 API scope.
- Verified ticket IDs match between `v0_1_8_3_tickets.md` and `tickets.yml`;
  `git diff --check` reported no whitespace errors beyond local Git ignore
  permission warnings.

---

## LDG-2402: Performance Protocol And v0.1.8.2 Baseline

Priority: P1
Effort: M
Dependencies: LDG-2401
Status: Done

### Description

Create the reproducible performance protocol before optimizing the sweep memory
path, then capture the v0.1.8.2 baseline measurement.

### Tasks

- Create runnable measurement scripts under
  `dev/spikes/ledgr_v0_1_8_3_sweep_optimization/`.
- Create reviewed report stubs under
  `inst/design/spikes/ledgr_v0_1_8_3_sweep_optimization/`.
- Define smoke, reference, wider, persistent-comparison, and metric-context
  workloads.
- Record v0.1.8.2 tag, exact SHA, R version, OS, CPU/memory where practical,
  package versions, warmup policy, and iteration policy.
- Measure median elapsed time over repeat runs; avoid single-run claims.
- Capture total sweep time, candidate fold time, summary reconstruction time,
  metric computation time, profile top functions, and relevant workload sizes
  where practical.
- Document measurement noise and any workload scaling compromises.

### Acceptance Criteria

- Baseline scripts can be rerun locally.
- Baseline report records exact git SHA and environment metadata.
- Workloads include at least the existing 50-candidate benchmark lineage and
  one wider workload justified from the spec.
- Baseline report states whether LDG-2108B hot-path proportions still hold
  after v0.1.8.2.
- No optimization implementation is bundled into this ticket.

### Verification

Manual review of scripts and baseline report; rerun at least the smoke and
reference workloads.

### Source Reference

- `v0_1_8_3_spec.md` Section 4
- `inst/design/audits/sweep_performance_measurement.md`
- `inst/design/audits/sweep_hot_path_profile.md`
- `dev/spikes/ledgr_sweep_performance/run_benchmark.R`
- `dev/spikes/ledgr_sweep_performance/profile_hot_path.R`

### Classification

```yaml
type: measurement
surface: sweep_performance
scope: benchmark_protocol
```

### Completion Notes

- Added the v0.1.8.3 sweep-optimization measurement harness under
  `dev/spikes/ledgr_v0_1_8_3_sweep_optimization/`, with shared workload
  definitions plus baseline, post-change, profiling, and summary entrypoints.
- Added reviewed report artifacts under
  `inst/design/spikes/ledgr_v0_1_8_3_sweep_optimization/`, including
  `README.md`, `baseline_report.md`, `summary_report.md`, and pending
  post-change/residual report placeholders.
- Ran the baseline protocol on the v0.1.8.3 planning branch before runtime
  optimization. The package version is `0.1.8.2`; the report records current
  HEAD `f5b49d4` and tag `v0.1.8.2` at `9d8dfc8`.
- Captured all required workload classes: smoke, reference 50-candidate EOD,
  wider feature-payload, persistent committed-run comparison, and non-default
  metric-context sweep.
- Captured Rprof top frames for the reference workload and recorded the
  LDG-2108B split check: `ledgr_execute_fold()` now accounts for about 79.8%
  of sampled reference-workload time, so the older 64% fold / 31%-33%
  reconstruction split must be treated as stale until post-change measurement.
- Baseline median timings include:
  - `reference_50_candidates` plain sweep: 45.585s;
  - `reference_50_candidates` precomputed sweep: 45.490s;
  - `wider_feature_payload` plain sweep: 65.360s;
  - `persistent_comparison` plain sweep: 4.415s versus run loop: 9.420s;
  - `metric_context_non_default` plain sweep: 4.350s.
- No optimization implementation landed in this ticket.

---

## LDG-2403: Persistent-Versus-Memory Accounting Parity Gate

Priority: P1
Effort: M
Dependencies: LDG-2401
Status: Done

### Description

Establish parity tests before typed memory events or single-pass summary
reconstruction change the sweep memory path.

### Tasks

- Add persistent `ledgr_run()` versus sweep memory-path parity tests.
- Cover realized PnL and unrealized PnL as FIFO lot-state accounting outputs.
- Cover opening positions, buy fills, sell fills, partial closes, full closes,
  multi-instrument runs, final-bar no-fill warnings, zero-trade candidates,
  open-position-at-end candidates, and non-default metric context.
- Include standard metric values where available: total return, Sharpe ratio,
  max drawdown, trade counts, win rate, average trade, and time in market.
- Define and document floating-point tolerances per output class.
- Preserve current warning behavior, candidate status, promotion context, and
  public sweep result shape.

### Acceptance Criteria

- Tests fail if memory-path accounting drifts from persistent-path accounting
  for realized or unrealized PnL.
- Tolerances are explicit in the test file and justified.
- `metric_kernel` remains the metric-assumption input in tested sweep paths.
- The parity gate can be rerun after LDG-2408 through LDG-2413.

### Verification

Targeted parity tests, sweep tests, metric-kernel tests, and promotion tests.

### Source Reference

- `v0_1_8_3_spec.md` Sections 5 and 6
- `inst/design/rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md`
- `R/sweep.R`
- `R/fold-core.R`

### Classification

```yaml
type: test
surface: accounting_parity
scope: sweep_memory_path
```

### Completion Notes

- Expanded `tests/testthat/test-sweep-parity.R` into the LDG-2403 accounting
  gate for future typed-event and single-pass summary work.
- Added explicit accounting and metric tolerances (`1e-10`) with test-file
  comments explaining that they allow only floating-point order noise, not
  cent-level accounting drift.
- Added memory reconstruction checks that rebuild equity, realized PnL,
  unrealized PnL, fills, and metrics from ledger events with the same
  `ledgr_equity_from_events()`, `ledgr_fills_from_events()`, and
  `ledgr_metrics_from_equity_fills()` helpers used by the sweep memory path,
  then compare those outputs to persistent `ledgr_run()` artifacts.
- Extended candidate coverage to zero-trade, partial close, full close,
  multi-instrument, final-bar no-fill warning, and open-position-at-end cases.
- Added opening-position lot coverage with a non-default metric context and
  asserted that sweep metric-context hash/provenance still drive candidate
  metric assumptions.
- Preserved public sweep result shape and promotion/direct-run parity checks.
- Verification passed:
  - `testthat::test_file('tests/testthat/test-sweep-parity.R')`
  - `testthat::test_file('tests/testthat/test-sweep.R')`
  - `testthat::test_file('tests/testthat/test-metric-kernel.R')`
  - `testthat::test_file('tests/testthat/test-promotion-context.R')`

---

## LDG-2404: Strategy Preflight Indirection Hardening

Priority: P1
Effort: M
Dependencies: LDG-2401
Status: Done

### Description

Fix the auditr-confirmed preflight bypass where constant-string `do.call()` can
invoke forbidden nondeterministic functions before strategy execution.

### Tasks

- Extend strategy preflight to classify constant-string `do.call()` targets
  that resolve to forbidden nondeterministic functions as Tier 3.
- Classify direct-function `do.call()` targets such as
  `do.call(Sys.time, list())` as Tier 3 when statically visible.
- Reject statically visible `attr(ctx, ...) <- ...` as unsupported context
  mutation.
- Preserve `ledgr_strategy_tier3` and `ledgr_strategy_preflight_error`
  condition classes.
- Preserve no-force behavior: `ledgr_run()` and `ledgr_sweep()` must reject
  before completed run rows or candidate artifacts are written.
- Keep captured mutable environments Tier 2 for now when statically resolved,
  but add tests/doc hooks showing the policy is explicit.
- Add adversarial regression tests for representative forbidden targets:
  `Sys.time`, `Sys.Date`, `Sys.getenv`, `get`, `eval`, and `assign` where those
  targets are part of the existing forbidden-call policy.

### Acceptance Criteria

- `do.call("Sys.time", list())` fails through preflight as Tier 3.
- `do.call(Sys.time, list())` fails through preflight as Tier 3 when visible.
- `attr(ctx, "secret") <- 1` fails through preflight as unsupported context
  mutation.
- Error messages name the offending target or mutation pattern.
- No late `ledgr_config_non_deterministic` error is the first user-facing error
  for the covered `do.call()` cases.
- Existing allowed Tier 1 and Tier 2 strategy fixtures still pass.

### Verification

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-strategy-preflight.R', reporter='summary'); testthat::test_file('tests/testthat/test-sweep.R', reporter='summary'); testthat::test_file('tests/testthat/test-backtest-wrapper.R', reporter='summary')"
```

### Source Reference

- `categorized_feedback.yml` THEME-002, especially episode 016 FB-001
- `v0_1_8_3_spec.md` Sections 7 and 10
- `R/strategy-preflight.R`
- `R/determinism.R`

### Classification

```yaml
type: bugfix
surface: strategy_preflight
scope: runtime_contract
```

### Completion Notes

- Extended strategy preflight analysis with a bounded AST pass for visible
  `do.call()` targets. Constant-string targets such as
  `do.call("Sys.time", list())` and direct-function targets such as
  `do.call(Sys.time, list())` now route through Tier 3 preflight when the
  target is part of the existing forbidden-call policy.
- Added unsupported context-mutation detection for statically visible
  `attr(ctx, ...) <- ...` writes.
- Kept resolved captured mutable environments Tier 2, but added an explicit
  preflight note warning that such objects may be mutated externally outside
  stored run metadata.
- Added adversarial regression coverage for `do.call()` targets resolving to
  `Sys.time`, `Sys.Date`, `Sys.getenv`, `get`, `eval`, and `assign`, plus
  runtime artifact checks for `ledgr_run()` and `ledgr_sweep()`.
- Preserved `ledgr_strategy_tier3` and `ledgr_strategy_preflight_error`
  condition classes and avoided late `ledgr_config_non_deterministic` as the
  first user-facing error for covered `do.call()` cases.
- Verification passed:
  - `testthat::test_file('tests/testthat/test-strategy-preflight.R')`
  - `testthat::test_file('tests/testthat/test-sweep.R')`
  - `testthat::test_file('tests/testthat/test-backtest-wrapper.R')`

---

## LDG-2405: Preflight Documentation And Strategy-Boundary Polish

Priority: P2
Effort: M
Dependencies: LDG-2404
Status: Done

### Description

Update installed docs and examples so the strategy preflight contract matches
the v0.1.8.3 hardened behavior and the v0.1.8.2 Tier 2/Tier 3 policy.

### Tasks

- Add a forbidden-call table to `?ledgr_strategy_preflight` and/or the
  reproducibility vignette.
- Document Tier 3 execution failure classes, no-force wording, and the
  preflight-versus-determinism distinction.
- Document ambient RNG strategy behavior separately from custom-indicator RNG
  restrictions.
- Document captured mutable environment caveats while keeping resolved captures
  Tier 2 unless a later policy changes.
- Fix Tier 2/Tier 3 examples that imply all globals are Tier 3.
- Fix examples or prose that use invalid helper-factory patterns in strategy
  code without explaining preflight consequences.
- Keep auditr task-brief corrections out of the ledgr package unless they
  correspond to installed docs.

### Acceptance Criteria

- Installed docs explain direct calls and `do.call()` indirection consistently.
- Users can distinguish resolved immutable captures from unresolved helper
  symbols and mutable-environment caveats.
- Docs do not imply `stats::median()` is Tier 2 if the installed classifier
  treats recommended-R functions as Tier 1.
- Documentation contract tests pin the new preflight claims where practical.

### Verification

Documentation contract tests and targeted preflight tests if examples are
executable.

### Source Reference

- `categorized_feedback.yml` THEME-002 and THEME-004
- `v0_1_8_3_spec.md` Section 7
- `vignettes/reproducibility.Rmd`
- `vignettes/strategy-development.Rmd`

### Classification

```yaml
type: documentation
surface: strategy_preflight
scope: installed_docs
```

### Completion Notes

- Added forbidden-call and visible-indirection documentation to the
  reproducibility article and `?ledgr_strategy_preflight`, including
  `do.call("Sys.time", list())`, dynamic lookup/evaluation helpers, global
  assignment, and `attr(ctx, ...) <- ...` context mutation.
- Documented Tier 3 hard-failure classes, no-force behavior, and the
  preflight-before-determinism boundary.
- Documented the current captured-mutable-environment policy: resolved captures
  remain Tier 2, but mutation remains the user's reproducibility risk.
- Documented ambient strategy RNG as Tier 2 under the execution-seed contract
  and distinguished it from stricter custom-indicator determinism.
- Added documentation contract assertions for the new preflight claims.
- Verification passed:
  - `testthat::test_file('tests/testthat/test-documentation-contracts.R')`
  - `testthat::test_file('tests/testthat/test-strategy-preflight.R')`

---

## LDG-2406: Metric-Context Documentation And Display Polish

Priority: P2
Effort: M
Dependencies: LDG-2401
Status: Done

### Description

Address the v0.1.8.2 auditr feedback showing that the metric-context surface
works but is under-explained in installed docs and displays.

### Tasks

- Enumerate `ledgr_metric_context()` constructor fields instead of relying on
  `...` discovery.
- Document `calendar`, `risk_free_rate`, `benchmark`, `market_factor`, and
  `mar` semantics, including reserved provider fields.
- Clarify which fields enter `ledgr_metric_context_hash()` and which display
  labels do not.
- Add a non-mutating metric-context override example that visibly proves stored
  run context is unchanged.
- Add intraday annualization guidance showing default US equity daily behavior
  versus explicit `bars_per_day`.
- Improve risk-free-rate label/source/as-of display if low risk; otherwise
  document where to inspect the nested object.
- Reduce noisy metric-context/kernel display in `ledgr_metrics` or document the
  raw attribute behavior if display changes are deferred.

### Acceptance Criteria

- Users can discover required metric-context fields from installed help.
- Hash/provenance semantics are explicit enough to explain why label-only
  changes do or do not affect identity.
- Intraday users are pointed to explicit calendar construction instead of
  hidden cadence inference.
- Any print/display changes preserve object structure and public accessors.

### Verification

Metric-context documentation contract tests, metric-context tests if display
behavior changes, and pkgdown/reference checks if help pages are regenerated.

### Source Reference

- `categorized_feedback.yml` THEME-003
- `v0_1_8_3_spec.md` Section 7
- `R/metric-context.R`
- `vignettes/metrics-and-accounting.Rmd`

### Classification

```yaml
type: documentation
surface: metric_context
scope: installed_docs
```

### Completion Notes

- Enumerated `ledgr_metric_context()` constructor fields in installed help:
  `risk_free_rate`, `calendar`, `benchmark`, `market_factor`, and `mar`.
- Documented reserved provider-field semantics and the explicit-calendar
  requirement for intraday annualization.
- Clarified metric-context hash payload semantics and the label/provenance split:
  display labels are inspectable but do not enter the hash.
- Added a non-mutating call-time override example that checks the stored run
  context hash remains unchanged.
- Documented nested `risk_free_rate` inspection for label/source/as-of
  provenance and left print behavior unchanged.
- Documented raw metric-kernel attributes as programmatic provenance rather than
  printed report columns.
- Verification passed:
  - `testthat::test_file('tests/testthat/test-documentation-contracts.R')`
  - `testthat::test_file('tests/testthat/test-metric-context.R')`
  - `testthat::test_file('tests/testthat/test-metric-context-storage.R')`
  - `testthat::test_file('tests/testthat/test-metric-context-tables.R')`

---

## LDG-2407: Sweep Inspection, Export, And Real-Data Example Polish

Priority: P2
Effort: L
Dependencies: LDG-2401
Status: Done

### Description

Address accepted auditr docs/example findings around sweep inspection, export,
Yahoo workflows, and invalid installed examples without adding new public
helper APIs.

### Tasks

- Document failed-candidate fields and access patterns for error class/message,
  warnings, params, feature fingerprints, and provenance hashes.
- Document flat export patterns for list-column sweep results without adding
  `ledgr_sweep_summary()`.
- Fix installed examples that use `ctx$equity()` when the installed context
  exposes `ctx$equity` as a field.
- Fix invalid parameter-grid vector syntax examples; do not implement new grid
  helpers in this ticket.
- Document `ledgr_snapshot_seal()` as returning a structured object with
  `$hash` and `$snapshot`; show `$hash` extraction when needed.
- Clarify one-experiment-per-strategy workflow wording.
- Clarify accepted bundle alias/feature-ID asymmetry from v0.1.8.1.
- Add or update Yahoo workflow guidance: snapshot sealing, rerun lifecycle
  after failed runs, quantmod stderr noise, and real-data happy path.
- Add troubleshooting snippets for timestamp comparisons, intraday time
  extraction, zero-trade/zero-sizing diagnosis, final-bar no-fill warnings,
  and fill-model required fields.
- Keep public helper ideas such as `ledgr_sweep_summary()` and fill-model
  factories deferred unless the maintainer amends scope.

### Acceptance Criteria

- Users can export a flat sweep report with documented base-R or tibble
  patterns.
- Users can inspect failed sweep candidates without guessing list-column names.
- Installed examples do not teach invalid API calls or invalid grid syntax.
- Real Yahoo workflow docs include seal/rerun/noise guidance without adding an
  external provider abstraction.
- No active-alias, grid-helper, ranking-helper, or sweep-artifact-persistence
  API is introduced.

### Verification

Documentation contract tests, example smoke tests if examples are executable,
and stale-version/encoding scans.

### Source Reference

- `categorized_feedback.yml` THEME-001, THEME-004, THEME-006, and THEME-007
- `v0_1_8_3_spec.md` Section 7
- `vignettes/sweeps.Rmd`
- `vignettes/strategy-development.Rmd`
- `vignettes/metrics-and-accounting.Rmd`
- `vignettes/experiment-store.Rmd`

### Classification

```yaml
type: documentation
surface: sweep_docs_examples
scope: installed_docs
```

### Completion Notes

- Documented failed sweep candidate inspection for `error_class`, `error_msg`,
  `params`, `warnings`, `feature_fingerprints`, and provenance hashes.
- Added a base-R flat-export recipe for sweep result list columns without adding
  `ledgr_sweep_summary()` or any other public helper.
- Fixed installed `ctx$equity()` examples to use the current `ctx$equity` field.
- Fixed the invalid `ledgr_param_grid()` vector example in the indicators
  article.
- Documented the structured `$hash`/`$snapshot` return when
  `ledgr_snapshot_seal()` is called with a snapshot handle.
- Added one-experiment-per-strategy wording and troubleshooting snippets for
  timestamp comparison, intraday time extraction, zero sizing, and fill-model
  required fields.
- Kept ranking helpers, sweep summary helpers, active aliases, and full sweep
  artifact persistence out of scope.
- Verification passed:
  - `testthat::test_file('tests/testthat/test-documentation-contracts.R')`
  - `testthat::test_file('tests/testthat/test-sweep.R')`
  - `git diff --check`

---

## LDG-2408: Runtime Projection Interface And R-Memory Backend

Priority: P1
Effort: L
Dependencies: LDG-2402, LDG-2403
Status: In Review

### Description

Extend the feature precompute path so execution can consume a projection
interface backed by R-memory matrices without adding a second feature engine.

### Tasks

- Keep `ledgr_precompute_features()` as the single feature precompute path.
- Add an internal projection interface and first R-memory backend.
- Use a named list of matrices keyed by concrete feature ID, with each matrix
  shaped `[instrument_idx, pulse_idx]`.
- Emit instrument and pulse indices, carry `feature_engine_version`, and reserve
  only a NULL alias-index extension point for v0.1.8.4.
- Fill missing/warmup/not-found projection slots with `NA_real_`.
- Flatten bundle outputs to ordinary concrete feature IDs before projection.
- Do not bump `feature_engine_version`, concrete fingerprints,
  `feature_set_hash`, or `config_hash`.
- Do not add DuckDB-backed precompute storage, out-of-core projection, or
  DuckDB-implemented indicator computation.

### Acceptance Criteria

- Projection shape and index metadata are pinned by tests.
- Projection values match current feature precompute output for the reference
  workloads.
- Missingness and bundle flattening match current accessor semantics.
- Fingerprint stability pins remain unchanged.
- The fold does not depend on the projection's concrete storage representation
  directly; it consumes the projection through internal helpers.

### Verification

Projection unit tests, feature precompute tests, bundle/indicator tests, and
fingerprint-stability tests.

### Source Reference

- `v0_1_8_3_spec.md` Sections 3, 8, and 9
- `inst/design/rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`
- `R/precompute-features.R`
- `R/feature-cache.R`
- `R/indicator.R`

### Classification

```yaml
type: optimization
surface: runtime_projection
scope: feature_precompute
```

### Completion Notes

- Added an internal `ledgr_runtime_projection` interface with an R-memory
  backend keyed by concrete feature ID and shaped as
  `[instrument_idx, pulse_idx]` matrices.
- Extended `ledgr_precompute_features()` to attach a projection while keeping
  the existing payload and feature-precompute path authoritative.
- The projection carries instrument and pulse indices, `feature_engine_version`,
  and a reserved `alias_index = NULL` extension point without changing feature
  fingerprints, `feature_set_hash`, or `config_hash`.
- Added projection helper functions for feature scalar access, current-pulse
  feature tables, current-pulse wide views, and feature-map bundle access.
- Pinned projection shape, missing warmup slots, bundle flattening, and
  fingerprint stability with targeted tests.
- Verification passed:
  - `testthat::test_file('tests/testthat/test-precompute-features.R')`
  - `testthat::test_file('tests/testthat/test-pulse-context-accessors.R')`
  - `testthat::test_file('tests/testthat/test-indicator-ttr.R')`
  - `testthat::test_file('tests/testthat/test-feature-map.R')`
  - `testthat::test_file('tests/testthat/test-fingerprint-stability.R')`

---

## LDG-2409: Shared Fold Projection Consumption And Parity Gate

Priority: P1
Effort: L
Dependencies: LDG-2403, LDG-2408
Status: In Review

### Description

Route both `ledgr_run()` and `ledgr_sweep()` through the same projection-backed
feature access path in the shared fold core, with parity tests before fast
context activation.

### Tasks

- Make `ledgr_run()` the one-candidate projection case and `ledgr_sweep()` the
  grid-union projection case.
- Consume projection values through pre-resolved integer indices inside the
  fold.
- Preserve public `ctx$feature()` and related feature helper semantics.
- Preserve `ctx$features_wide` schema, column ordering, types, and `ts_utc`
  behavior.
- Materialize `ctx$features_wide` as a fresh current-pulse view, not a reusable
  mutable public object.
- Use `ledgr_sweep_run_candidate()` as the convergence point for per-candidate
  fold setup where applicable.
- Add projection-vs-table, state-leak, schema, and shared run/sweep parity
  tests.
- Add a single-candidate `ledgr_run()` wall-clock regression check.

### Acceptance Criteria

- `ledgr_run()` and `ledgr_sweep()` consume the same internal projection shape.
- Strategy-visible feature values are bit-exact equal to the current accessor
  path on reference workloads.
- Capturing `ctx$features_wide` at pulse `t` cannot be mutated by pulse `t+1`.
- `ctx$features_wide` schema and `ts_utc` handling match current behavior.
- Single-candidate `ledgr_run()` does not materially regress.
- No public context API changes.

### Verification

Projection parity tests, sweep tests, backtest-wrapper tests, feature
inspection tests, accounting parity tests, and the single-candidate runtime
workload from the LDG-2402 protocol.

### Source Reference

- `v0_1_8_3_spec.md` Sections 3, 4, 8, and 9
- `inst/design/rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`
- `R/fold-core.R`
- `R/pulse-context.R`
- `R/sweep.R`

### Classification

```yaml
type: optimization
surface: fold_feature_access
scope: shared_fold_core
```

### Completion Notes

- Routed `ledgr_run()` through the same runtime projection shape as the sweep
  path, with committed runs acting as the one-candidate projection case.
- Routed `ledgr_sweep()` through a grid-union projection, using supplied
  `precomputed_features$projection` when present and building the same internal
  projection from the resolved grid otherwise.
- Updated `ledgr_execute_fold()` and `ledgr_sweep_run_candidate()` to consume
  projection-backed feature helpers through the shared fold setup.
- Preserved public `ctx$feature()`, `ctx$features()`, and
  `ctx$features_wide` semantics while materializing `ctx$features_wide` as a
  fresh current-pulse view with stable schema and `ts_utc` behavior.
- Preserved the public `ctx$feature_table` data-frame contract. This means the
  projection path removes scalar-accessor string matching and wide-view reshape
  work, but does not yet remove the per-pulse long-form feature-table
  materialization cost; that residual cost is explicitly left for LDG-2413 /
  LDG-2414 measurement or a later context-contract change.
- Kept the legacy table-backed fold branch as a tested parity fallback rather
  than deleting it during the projection foundation ticket.
- Added projection-vs-current-wide-view, state-leak, shared-fold structure,
  fold-level projection-vs-table parity, restricted-candidate-feature,
  sweep, committed-run, and accounting-parity coverage.
- Verification passed:
  - `testthat::test_file('tests/testthat/test-sweep.R')`
  - `testthat::test_file('tests/testthat/test-sweep-parity.R')`
  - `testthat::test_file('tests/testthat/test-experiment-run.R')`
  - `testthat::test_file('tests/testthat/test-backtest-wrapper.R')`
  - `testthat::test_file('tests/testthat/test-pulse-context-accessors.R')`
  - LDG-2402 smoke workload, 2 reps, profile disabled:
    `sweep_plain` median 1.43s, `sweep_precomputed` median 0.96s, `run_loop`
    median 5.635s. The run-loop result is close to the baseline smoke
    run-loop median of 5.245s and remains a residual-report watch item.
  - Full local test suite:
    `testthat::test_local('.', reporter = 'summary')`

---

## LDG-2410: Typed Memory Event Representation

Priority: P1
Effort: L
Dependencies: LDG-2402, LDG-2403, LDG-2409
Status: Pending

### Description

Introduce a typed in-memory event representation for the sweep memory output
handler while preserving durable persistent ledger-event serialization.

### Tasks

- Identify the current memory output-handler event payload and repeated parsing
  costs.
- Add a typed memory event representation scoped to in-memory sweep execution.
- Reuse projection pulse/index information where useful; do not invent a
  separate indexing model.
- Keep durable persistent output serialized to stable `meta_json` rows.
- Preserve event ordering, event sequence, fill timing, cost metadata, target
  validation, and final-bar behavior.
- Add conversion/equivalence tests between typed memory events and durable
  event rows.
- Rerun the LDG-2403 accounting parity gate after the representation change.
- Avoid public result-shape changes.

### Acceptance Criteria

- Typed memory events preserve all fields needed by summary reconstruction,
  warnings, promotion, accounting parity, and metric computation.
- Durable run-store/event serialization is unchanged unless a maintainer
  amendment explicitly records a pre-CRAN breaking change.
- Parity tests pass after typed memory events land.
- Existing sweep/run tests and fingerprint-stability pins remain green.

### Verification

Typed-event unit tests, accounting parity tests, sweep tests,
backtest-wrapper/run-store tests if touched, and fingerprint-stability tests.

### Source Reference

- `v0_1_8_3_spec.md` Sections 3, 5, and 8
- `inst/design/rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md`
- `inst/design/rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`
- `R/fold-core.R`
- `R/sweep.R`

### Classification

```yaml
type: optimization
surface: memory_events
scope: sweep_memory_path
```

---

## LDG-2411: Fast Context B1 Pulse Helper Reuse

Priority: P1
Effort: L
Dependencies: LDG-2403, LDG-2409
Status: In Review

### Description

Activate the first fast-context slice by initializing lookup environments and
helper closures once per candidate fold, then mutating only pulse-specific
values during execution.

### Tasks

- Make `use_fast_context` meaningful for the shared fold path.
- Initialize stable lookup environments, feature accessors, and helper closures
  once per candidate.
- Mutate current pulse index, timestamp, bars/features pointers, and portfolio
  state per pulse.
- Preserve public pulse-context fields and helper behavior.
- Ensure `ctx$features_wide` still materializes as a fresh view and passes
  state-leak tests.
- Rerun projection parity, accounting parity, sweep, and run tests.

### Acceptance Criteria

- Fast-context B1 produces bit-exact equivalent outputs to the current path on
  reference workloads.
- No strategy-facing context API changes.
- No shared mutable public context object leaks across pulses.
- `ledgr_run()` and `ledgr_sweep()` both benefit from the shared fold change.

### Verification

Fast-context tests, projection parity tests, accounting parity tests, sweep
tests, backtest-wrapper tests, and targeted LDG-2402 smoke/reference workloads.

### Source Reference

- `v0_1_8_3_spec.md` Sections 3, 8, and 9
- `inst/design/rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md`
- `inst/design/rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`
- `R/fold-core.R`
- `R/pulse-context.R`

### Classification

```yaml
type: optimization
surface: fast_context
scope: b1_helper_reuse
```

### Completion Notes

- Made `use_fast_context` active in the shared fold path and enabled it for
  both committed `ledgr_run()` execution and in-memory `ledgr_sweep()`
  candidates.
- Added a private fast-context state that is initialized once per candidate
  fold. It reuses the pulse lookup environment, scalar/bar/position helper
  closures, projection-backed `ctx$feature()` closure, and
  `ctx$features()` feature-map closure.
- Preserved a fresh public context list per pulse. B1 reuses private helper
  closure state; it does not reuse the public `ctx` object across pulses.
- Preserved `ctx$feature_table` and fresh `ctx$features_wide` materialization
  semantics. Long-form feature-table and wide-view allocation remain visible
  residual costs for LDG-2413 / LDG-2414.
- Removed the dead committed-run `features_proxy` allocation that was left over
  from the old fast-context scaffold and was not consumed by the fold.
- Extended the direct fold parity test to compare legacy table mode,
  projection mode, and fast-context projection mode, including event streams,
  scalar feature values, `ctx$feature_table`, `ctx$features_wide`, and helper
  closure reuse across pulses.
- Checkpoint measurement against the LDG-2409 checkpoint:
  - reference `sweep_plain`: 47.835s -> 43.245s median;
  - reference `sweep_precomputed`: 43.235s -> 43.140s median;
  - persistent `sweep_plain`: 4.255s -> 3.980s median;
  - persistent `run_loop`: 10.420s -> 10.255s median.
- Checkpoint profile: `ledgr_update_pulse_context_helpers` and
  `ledgr_attach_feature_helpers` are replaced by
  `ledgr_update_fast_pulse_context_helpers` at 22.2% total sample share;
  `data.frame`, `as.data.frame`, and `ledgr_projection_features_wide` remain
  the primary residual feature-context allocation frames.
- Verification passed:
  - `testthat::test_file('tests/testthat/test-sweep.R')`
  - `testthat::test_file('tests/testthat/test-pulse-context-accessors.R')`
  - `testthat::test_file('tests/testthat/test-backtest-wrapper.R')`
  - `testthat::test_file('tests/testthat/test-sweep-parity.R')`
  - `testthat::test_file('tests/testthat/test-experiment-run.R')`
  - `testthat::test_file('tests/testthat/test-precompute-features.R')`

---

## LDG-2412: Single-Pass Sweep Summary Reconstruction

Priority: P1
Effort: L
Dependencies: LDG-2403, LDG-2409, LDG-2410, LDG-2411
Status: Pending

### Description

Replace redundant post-candidate summary reconstruction in the sweep memory
path with a single-pass helper over already-ordered typed memory events.

### Tasks

- Implement a single-pass summary helper over typed memory events.
- Consume events in fold-produced order; assert ordering if needed rather than
  silently sorting away upstream drift.
- Avoid repeated metadata parsing in candidate summary reconstruction.
- Thread `metric_kernel` directly and avoid standalone `bars_per_year`, hidden
  cadence inference, or hard-coded zero risk-free-rate assumptions.
- Preserve public `ledgr_sweep_results` columns, attributes, promotion context,
  warning behavior, and candidate status semantics.
- Rerun the LDG-2403 accounting parity gate after the summary change.

### Acceptance Criteria

- Candidate summaries match pre-change semantics within documented tolerance.
- Realized/unrealized PnL remain FIFO lot-state accounting outputs.
- `metric_kernel` is the only metric-assumption input in the new summary path.
- Public sweep result shape and promotion context remain compatible.
- No lazy `features_wide`, active-alias, or parallel worker behavior is added.

### Verification

Single-pass summary tests, accounting parity tests, sweep tests,
metric-kernel tests, promotion tests, and targeted performance comparison
against the LDG-2402 baseline.

### Source Reference

- `v0_1_8_3_spec.md` Sections 5, 6, and 8
- `inst/design/rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md`
- `inst/design/rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`
- `R/sweep.R`

### Classification

```yaml
type: optimization
surface: sweep_summary
scope: memory_path
```

---

## LDG-2413: Pulse Context Data Model Consolidation

Priority: P1
Effort: L
Dependencies: LDG-2403, LDG-2409, LDG-2411
Status: Pending

### Description

Rescope the old fast-context B2 proxy ticket around prebuilt static pulse
views. Preserve public `ctx$bars`, `ctx$feature_table`, and
`ctx$features_wide` data-frame field semantics while moving their construction
out of the pulse hot loop where parity permits.

### Tasks

- Run and record the `ctx$feature_table` usage audit. In v0.1.8.3,
  prebuild `ctx$feature_table` either way; if no documented strategy usage is
  found, record only a future-deprecation note in `inst/design/horizon.md`.
- Remove `run_feature_matrix` from the fold execution contract and remove the
  legacy `is.null(runtime_projection)` branch from `ledgr_execute_fold`.
  A setup-only matrix intermediate may remain in `ledgr_run_fold()` if it is
  simpler than direct projection construction.
- Build `ctx$bars` static pulse views once at the appropriate setup point:
  run setup for `ledgr_run()`, sweep setup for `ledgr_sweep()` with views
  threaded through candidate folds.
- Build candidate-specific `ctx$features_wide` and `ctx$feature_table` views
  from the runtime projection restricted to candidate `feature_ids`.
- Preserve `ctx$bars`, `ctx$feature_table`, and `ctx$features_wide` schemas,
  column ordering, types, `ts_utc`, missing-value behavior, and data-frame
  field semantics.
- Preserve B1 helper closure reuse and projection-backed `ctx$feature()` /
  `ctx$features()` scalar accessors.
- Add state-leak tests for in-run captured views, in-strategy mutation, and
  cross-candidate isolation.
- Measure peak memory or object sizes for the prebuilt view bundle for LDG-2414.
- Rerun projection, accounting, sweep, run, and backtest-wrapper parity tests.

### Acceptance Criteria

- Prebuilt static pulse views ship with bit-exact parity against the LDG-2411
  projection+B1 path.
- `ctx$bars`, `ctx$feature_table`, and `ctx$features_wide` remain data-frame
  fields with current public schemas and semantics.
- No active bindings, function-valued context fields, or custom S3 public view
  classes are introduced.
- `run_feature_matrix` no longer survives into the fold execution contract.
- No second fold core or sweep-only execution semantics.
- State-leak tests prove captured views and strategy mutation do not corrupt
  later pulses or other sweep candidates.
- Reference workload performance and `ledgr_run()` single-candidate overhead
  are measured in LDG-2414.

### Verification

Pulse-context prebuilt-view tests, projection parity tests, accounting parity
tests, sweep tests, backtest-wrapper tests, fingerprint-stability tests, and
targeted LDG-2402 workloads plus peak-memory/object-size measurement in
LDG-2414.

### Source Reference

- `v0_1_8_3_spec.md` Sections 3, 8, and 9
- `inst/design/rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`
- `inst/design/rfc/rfc_pulse_context_data_model_consolidation_v0_1_8_3_synthesis.md`
- `R/fold-core.R`
- `R/pulse-context.R`
- `R/runtime-projection.R`

### Classification

```yaml
type: optimization
surface: pulse_context
scope: prebuilt_static_views
```

---

## LDG-2414: Post-Change Measurement And Residual Report

Priority: P1
Effort: M
Dependencies: LDG-2402, LDG-2408, LDG-2409, LDG-2411, LDG-2413
Status: Pending

### Description

Rerun the v0.1.8.3 performance protocol after runtime projection, B1, and
pulse-context data model consolidation land. Publish speedup/regression,
peak-memory/object-size evidence, and the residual hot-path report that informs
the maintainer decision on LDG-2410 typed memory events and LDG-2412
single-pass summary reconstruction.

### Tasks

- Rerun all LDG-2402 workloads on the v0.1.8.3 branch after LDG-2408,
  LDG-2409, LDG-2411, and LDG-2413 are done.
- Record exact SHA and environment metadata.
- Compare median elapsed time, candidate fold time, summary reconstruction
  time, metric computation time, single-candidate `ledgr_run()` time, and top
  profile functions.
- Record peak memory or object-size evidence for the prebuilt pulse-view
  bundle.
- Confirm no material `ledgr_run()` regression from shared-path changes.
- Publish `post_change_report.md`, `residual_hot_path_report.md`, and
  `summary_report.md`.
- Include post-fold reconstruction sampled-time share and wall-clock evidence
  sufficient for the maintainer to decide whether LDG-2410 and LDG-2412 remain
  in v0.1.8.3 or defer to v0.1.9.
- Evaluate whether strategy bytecode compilation (`compiler::cmpfun()`) is a
  credible next micro-optimization, including fingerprint/provenance risk and
  measured benefit if practical.
- Explicitly report whether lazy `ctx$features_wide`, persistent-path
  single-pass reconstruction, and `ctx$flat()` / `ctx$hold()` allocation remain
  material after v0.1.8.3.
- Recommend whether DuckDB-backed precompute storage/out-of-core projection,
  parallel dispatch, or another bottleneck is the next optimization slice.
- If the optimization fails to improve the reference workload, explain why it
  still ships or recommend deferral/reversion.

### Acceptance Criteria

- Post-change report uses the same protocol as the baseline.
- Residual report names remaining dominant inefficiency pockets.
- Residual report includes peak memory/object-size evidence for prebuilt
  pulse views.
- Residual report includes a maintainer-facing LDG-2410 / LDG-2412 disposition
  recommendation with supporting measurement evidence.
- Residual report names or dismisses the known deferred R-level candidates:
  lazy `ctx$features_wide`, persistent-path single-pass reconstruction,
  strategy bytecode compilation, and `ctx$flat()` / `ctx$hold()` allocation.
- Next optimization recommendation is measurement-based, not assumed.
- Performance claims in `NEWS.md` or docs are supported by the report.

### Verification

Manual review of reports, rerun smoke/reference/single-run workloads, and
targeted tests for any code paths touched during measurement cleanup.

### Source Reference

- `v0_1_8_3_spec.md` Sections 4 and 8
- LDG-2402 baseline artifacts

### Classification

```yaml
type: measurement
surface: sweep_performance
scope: post_change_report
```

---

## LDG-2415: v0.1.8.3 Release Gate And Closeout

Priority: P0
Effort: S
Dependencies: LDG-2401, LDG-2402, LDG-2403, LDG-2404, LDG-2405, LDG-2406, LDG-2407, LDG-2408, LDG-2409, LDG-2410, LDG-2411, LDG-2412, LDG-2413, LDG-2414
Status: Pending

### Description

Close the v0.1.8.3 packet after performance work, auditr fixes, documentation
polish, measurement reports, and package metadata land.

### Tasks

- Confirm ticket statuses are synchronized in `v0_1_8_3_tickets.md` and
  `tickets.yml`.
- Update `NEWS.md` for performance changes, preflight hardening, and
  docs/message polish.
- Verify no deferred API surface was implemented accidentally.
- Run targeted tests for changed runtime and documentation surfaces.
- Run full local tests and package checks appropriate for a release gate.
- Run stale-version, encoding, and generated-artifact scans.
- Confirm performance reports support any release claims.
- Follow the release/CI playbook through merge and tag when requested.

### Acceptance Criteria

- All v0.1.8.3 tickets are done or explicitly deferred by maintainer decision.
- Full test suite passes locally.
- Package build and check pass with agreed release flags.
- Documentation contract tests pass.
- Performance baseline, post-change report, and residual hot-path report are
  present or the optimization is explicitly deferred with evidence.
- Auditr findings are fixed, deferred, rejected, or assigned to a future home.
- No generated local artifacts are committed.

### Verification

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" -e "pkgload::load_all('.', quiet=TRUE); testthat::test_local('.', reporter='summary')"
& "C:\Program Files\R\R-4.5.2\bin\x64\R.exe" CMD build .
& "C:\Program Files\R\R-4.5.2\bin\x64\R.exe" CMD check --no-manual --no-build-vignettes ledgr_<version>.tar.gz
```

### Source Reference

- `v0_1_8_3_spec.md`
- `inst/design/release_ci_playbook.md`

### Classification

```yaml
type: release_gate
surface: package
scope: v0.1.8.3
```
