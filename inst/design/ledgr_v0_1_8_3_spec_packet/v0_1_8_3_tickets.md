# ledgr v0.1.8.3 Tickets

Version: v0.1.8.3
Date: 2026-05-25
Total Tickets: 11

## Ticket Organization

This packet implements the scoped v0.1.8.3 plan from `v0_1_8_3_spec.md`:
empirically grounded single-core sweep optimization, plus the routed v0.1.8.2
auditr findings that fit this release.

The performance spine is:

```text
baseline protocol
  -> accounting parity gate
  -> typed memory events
  -> single-pass summary reconstruction
  -> post-change measurement and residual hot-path report
```

The auditr spine is deliberately separate:

```text
preflight indirection hardening
  -> preflight/docs boundary polish
  -> metric-context docs/display polish
  -> sweep inspection and real-data docs polish
```

No active aliases, parameter-grid helpers, sweep ranking helpers, full sweep
artifact persistence, fast context, parallel dispatch, target risk, walk-forward,
cost/liquidity, OMS, paper/live, benchmark, or external-reference-data adapter
work is in scope unless the maintainer amends the spec.

## Dependency DAG

```text
LDG-2401 Scope Routing, Packet Setup, And Auditr Decisions
  |-- LDG-2402 Performance Protocol And v0.1.8.2 Baseline
  |     |-- LDG-2408 Typed Memory Event Representation
  |     |     `-- LDG-2409 Single-Pass Sweep Summary Reconstruction
  |     |           `-- LDG-2410 Post-Change Measurement And Residual Report
  |     `-- LDG-2410 Post-Change Measurement And Residual Report
  |-- LDG-2403 Persistent-Versus-Memory Accounting Parity Gate
  |     |-- LDG-2408 Typed Memory Event Representation
  |     `-- LDG-2409 Single-Pass Sweep Summary Reconstruction
  |-- LDG-2404 Strategy Preflight Indirection Hardening
  |     `-- LDG-2405 Preflight Documentation And Strategy-Boundary Polish
  |-- LDG-2406 Metric-Context Documentation And Display Polish
  `-- LDG-2407 Sweep Inspection, Export, And Real-Data Example Polish

LDG-2411 Release Gate depends on LDG-2401 through LDG-2410.
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
Status: In Review

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

---

## LDG-2402: Performance Protocol And v0.1.8.2 Baseline

Priority: P1
Effort: M
Dependencies: LDG-2401
Status: Pending

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

---

## LDG-2403: Persistent-Versus-Memory Accounting Parity Gate

Priority: P1
Effort: M
Dependencies: LDG-2401
Status: Pending

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
- The parity gate can be rerun after LDG-2408 and LDG-2409.

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

---

## LDG-2404: Strategy Preflight Indirection Hardening

Priority: P1
Effort: M
Dependencies: LDG-2401
Status: Pending

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

---

## LDG-2405: Preflight Documentation And Strategy-Boundary Polish

Priority: P2
Effort: M
Dependencies: LDG-2404
Status: Pending

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

---

## LDG-2406: Metric-Context Documentation And Display Polish

Priority: P2
Effort: M
Dependencies: LDG-2401
Status: Pending

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

---

## LDG-2407: Sweep Inspection, Export, And Real-Data Example Polish

Priority: P2
Effort: L
Dependencies: LDG-2401
Status: Pending

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

---

## LDG-2408: Typed Memory Event Representation

Priority: P1
Effort: L
Dependencies: LDG-2402, LDG-2403
Status: Pending

### Description

Introduce a typed in-memory event representation for the sweep memory output
handler while preserving durable persistent ledger-event serialization.

### Tasks

- Identify the current memory output-handler event payload and repeated parsing
  costs.
- Add a typed memory event representation scoped to in-memory sweep execution.
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
- `R/fold-core.R`
- `R/sweep.R`

### Classification

```yaml
type: optimization
surface: memory_events
scope: sweep_memory_path
```

---

## LDG-2409: Single-Pass Sweep Summary Reconstruction

Priority: P1
Effort: L
Dependencies: LDG-2403, LDG-2408
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
- No lazy `features_wide`, fast-context, or parallel worker behavior is added.

### Verification

Single-pass summary tests, accounting parity tests, sweep tests,
metric-kernel tests, promotion tests, and targeted performance comparison
against the LDG-2402 baseline.

### Source Reference

- `v0_1_8_3_spec.md` Sections 5, 6, and 8
- `inst/design/rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md`
- `R/sweep.R`

### Classification

```yaml
type: optimization
surface: sweep_summary
scope: memory_path
```

---

## LDG-2410: Post-Change Measurement And Residual Report

Priority: P1
Effort: M
Dependencies: LDG-2402, LDG-2408, LDG-2409
Status: Pending

### Description

Rerun the v0.1.8.3 performance protocol after the scoped optimization lands,
publish speedup/regression evidence, and name the remaining inefficiency
pockets.

### Tasks

- Rerun all LDG-2402 workloads on the v0.1.8.3 branch after LDG-2408 and
  LDG-2409 land.
- Record exact SHA and environment metadata.
- Compare median elapsed time, candidate fold time, summary reconstruction
  time, metric computation time, and top profile functions.
- Confirm no material `ledgr_run()` regression from shared-path changes.
- Publish `post_change_report.md`, `residual_hot_path_report.md`, and
  `summary_report.md`.
- Recommend whether fast context B1/B2 remains the next optimization slice.
- If the optimization fails to improve the reference workload, explain why it
  still ships or recommend deferral/reversion.

### Acceptance Criteria

- Post-change report uses the same protocol as the baseline.
- Residual report names remaining dominant inefficiency pockets.
- Next optimization recommendation is measurement-based, not assumed.
- Performance claims in `NEWS.md` or docs are supported by the report.

### Verification

Manual review of reports, rerun smoke/reference workloads, and targeted tests
for any code paths touched during measurement cleanup.

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

## LDG-2411: v0.1.8.3 Release Gate And Closeout

Priority: P0
Effort: S
Dependencies: LDG-2401, LDG-2402, LDG-2403, LDG-2404, LDG-2405, LDG-2406, LDG-2407, LDG-2408, LDG-2409, LDG-2410
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
