# ledgr v0.1.8.8 Tickets

Version: v0.1.8.8
Date: 2026-05-31
Total Tickets: 12

## Ticket Organization

This packet implements the scoped v0.1.8.8 plan from `v0_1_8_8_spec.md`:
parallel sweep dispatch and determinism, fold-core maintainer documentation /
containment, a repo-local reproducible peer benchmark report, a self-profiling
workload grid extension for v0.1.9 input, and a slip-eligible internal
maintainer-manual cleanup.

The release spine is:

```text
packet alignment
  -> fold-core documentation + mechanical split
  -> intra-loop diagnostic profile
  -> RNG / pulse-seed policy
  -> typed execution spec
  -> parallel backend + worker setup
  -> parallel sweep dispatch
  -> interrupt semantics + parallel measurement
  -> repo-local peer benchmark and parity report
  -> self-profiling workload grid extension
  -> maintainer manual skeleton + stale-doc cleanup (deferred)
  -> release gate
```

v0.1.8.8 is not a second execution engine, compiled-core, target-risk, OMS,
cost/liquidity, durable identity redesign, promotion-grade artifact, public
distributed execution, or package-vignette benchmark release. Sequential sweep
remains the reference implementation.

## Dependency DAG

```text
LDG-2468 Packet Alignment And v0.1.8.8 Planning State
  |-- LDG-2469 Fold-Core Documentation And Mechanical Split
  |     |-- LDG-2470 Fold-Loop Diagnostic Profile
  |     `-- LDG-2478 Internal Maintainer Manual Skeleton And Stale-Doc Cleanup
  |
  |-- LDG-2471 RNG Resume And Pulse-Seed Contract
  |     `-- LDG-2472 Typed Execution Spec
  |           `-- LDG-2473 Parallel Worker Setup And Backend Skeleton
  |                 `-- LDG-2474 Parallel Sweep Dispatch
  |                       `-- LDG-2475 Interrupt Semantics And Parallel Measurement
  |
  |-- LDG-2476 Repo-Local Peer Benchmark And Parity Report
  |     `-- LDG-2479 Self-Profiling Workload Grid Extension
  `-- LDG-2479 (also depends on LDG-2476)

LDG-2477 v0.1.8.8 Release Gate And Closeout
  depends on LDG-2468 through LDG-2476 plus LDG-2479; LDG-2478 is explicitly
  deferred by maintainer decision.
```

LDG-2476, LDG-2479, and LDG-2478 are separable if the cycle becomes too wide.
LDG-2479 depends on LDG-2476 because the grid scenarios reuse the same
`bench_sma_crossover_strategy()` definition and the cost-surface ranking is
calibrated against the LDG-2476 peer benchmark record. LDG-2469 is not optional:
the fold-core maintainer documentation and source legibility work is a release
goal.

## Priority Levels

- P0: Scope gate, determinism gate, parallel contract gate, documentation gate,
  or release gate.
- P1: Primary v0.1.8.8 implementation or measurement work.
- P2: Useful benchmark/documentation work that may slip if the core release is
  too wide.

---

## LDG-2468: Packet Alignment And v0.1.8.8 Planning State

Priority: P0
Effort: S
Dependencies: none
Status: Completed

### Description

Finalize the v0.1.8.8 planning packet and make the active-version state
unambiguous across the design index, roadmap, horizon, AGENTS notes, spec,
ticket file, machine-readable ticket metadata, and batch plan.

### Tasks

- Keep `v0_1_8_8_spec.md`, `v0_1_8_8_tickets.md`, `tickets.yml`, and
  `batch_plan.md` synchronized.
- Confirm `inst/design/README.md`, `inst/design/ledgr_roadmap.md`,
  `inst/design/horizon.md`, and `AGENTS.md` point to the v0.1.8.8 packet as
  active.
- Confirm the settled spec-cut decisions are visible: `mirai` as `Suggests`,
  hybrid worker dependency handling, deterministic-only RNG resume with
  `ctx$pulse_seed`, discard-all interrupt behavior, mandatory internal typed
  execution spec, mechanical fold-core split paired with docs, explicit event
  types deferred to v0.2.x, and peer-list tiers.
- Confirm the packet explicitly defers compiled core, target risk, OMS,
  cost/liquidity, durable identity byte redesign, public distributed execution,
  promotion-grade artifact expansion, and package-vignette benchmark claims.

### Acceptance Criteria

- Spec, ticket markdown, `tickets.yml`, and batch plan agree on ticket IDs,
  dependencies, statuses, priorities, and scope.
- README, roadmap, horizon, and AGENTS active-packet language agrees with the
  spec.
- No deferred milestone is accidentally promoted by active-packet text.
- Ticket dependencies form the intended DAG.
- Stale-scope `rg` checks and a diff review are recorded as packet-alignment
  evidence.

### Verification

Manual packet review and `rg` checks for stale active-packet, deferred-scope,
and legacy planning language.

Completion note (2026-05-30): Committed the reviewed v0.1.8.8 planning packet,
then aligned the design index and AGENTS active-context notes to the new packet.
Rechecked the spec, tickets, YAML, batch plan, roadmap, horizon, README, and
AGENTS entries for active-packet consistency. The original ten-ticket
`tickets.yml` parsed cleanly, and the new spec packet remained ASCII. The packet
now clearly scopes parallel sweep dispatch/determinism, fold-core maintainer
documentation/containment, repo-local peer benchmarking, and slip-eligible
maintainer-manual cleanup while keeping compiled core, target risk, OMS,
cost/liquidity, durable identity redesign, public distributed execution, and
package-vignette benchmark claims deferred.

### Source Reference

- `v0_1_8_8_spec.md`
- `inst/design/ledgr_roadmap.md`
- `inst/design/horizon.md`
- `AGENTS.md`

### Classification

```yaml
type: governance
surface: design_packet
scope: v0.1.8.8
```

---

## LDG-2469: Fold-Core Documentation And Mechanical Split

Priority: P0
Effort: L
Dependencies: LDG-2468
Status: Completed

### Description

Refresh the fold-core maintainer workbook, add professional inline comments,
and mechanically split `R/fold-core.R` along the structure the workbook
documents. This ticket is documentation and containment work, not a behavior
change.

### Tasks

- Update `inst/design/maintainer_review/fold_core_workbook.qmd` against the
  current post-v0.1.8.7 source.
- Update the workbook freshness statement and verification date.
- Make the workbook function-complete for the fold-core source after any file
  split, or explicitly classify moved/test-only/out-of-scope functions.
- Add diagrams for high-level flow, per-pulse execution, event emission,
  reconstruction, and metrics materialization.
- Add inline comments in fold-core source where they explain invariants, phase
  boundaries, replay-sensitive transitions, accounting transitions, or
  duplicated parity-sensitive algorithms.
- Split fold-core source mechanically into engine, reconstruction, metrics, and
  test-only/helper files if the split remains behavior-neutral.
- Keep the workbook organization aligned with the structure that ships.

### Acceptance Criteria

- No public API changes.
- No event, equity, fills, sweep, metric, or replay behavior changes.
- The workbook no longer presents stale v0.1.8.6/v0.1.8.7 line anchors as
  current.
- Every fold-core function has workbook coverage or an explicit classification.
- Comments explain "why" and invariants, not obvious "what" code narration.
- File-split source loading works under package load and tests.
- Existing fold, sweep, replay, fills, and metrics parity tests pass.

### Verification

Targeted fold/sweep/replay/metrics tests, package load check, workbook function
name grep/check, and manual rendered-workbook review.

Completion note (2026-05-30): Mechanically split the former `R/fold-core.R`
into `R/fold-engine.R`, `R/fold-event-buffer.R`,
`R/fold-reconstruction.R`, and `R/fold-metrics.R`. Added inline comments only
where they document no-lookahead, event/state adjacency, replay step-function,
and close-before-open invariants. Refreshed `fold_core_workbook.qmd` against
the new source layout with function-complete coverage and diagrams for
high-level flow, per-pulse/event emission, reconstruction, and metrics
materialization. Claude reviewed the batch and approved with no blocking
findings; the only suggested diagram polish was folded in before commit.
Verification passed: `pkgload::load_all('.', quiet=TRUE)`,
`test-sweep.R`, `test-sweep-parity.R`, `test-metric-kernel.R`,
`test-metric-oracles.R`, `test-metrics-zero-trades.R`,
`test-backtest-audit-log-equivalence.R`, `test-fills-streaming.R`,
`test-ledger-writer.R`, `test-api-exports.R`, ASCII scan, function-reference
grep, and Quarto render of the workbook.

### Source Reference

- `v0_1_8_8_spec.md`, Sections 5 and 6.2
- `inst/design/maintainer_review/fold_core_workbook.qmd`
- `inst/design/horizon.md`, fold-core structural-debt entry

### Classification

```yaml
type: maintainability
surface: fold_core
scope: documentation_and_mechanical_split
```

---

## LDG-2470: Fold-Loop Diagnostic Profile

Priority: P1
Effort: M
Dependencies: LDG-2469
Status: Completed

### Description

Produce a current-source intra-loop diagnostic profile after v0.1.8.7 B0/R/A/C.
The goal is attribution for documentation and future planning, not another
optimization pass.

### Tasks

- Add or update a local diagnostic harness that splits the remaining pure-R
  fold loop into named sub-buckets: context access/building, bar/feature reads,
  strategy callback, target/order conversion, fill resolution, state update,
  and event emission.
- Run the diagnostic on at least the current TTR-backed peer turnover shape and
  one low-turnover or wide shape if practical.
- Record raw results under `dev/bench/results/`.
- Summarize results in the fold-core workbook and/or the v0.1.8.8 packet.
- Park future optimization options in `inst/design/horizon.md` without
  promoting them into v0.1.8.8 implementation scope.

### Acceptance Criteria

- Each reported bucket has a clear measurement method and timing boundary.
- The report does not claim a new optimization win.
- Collapse, compiled-core, and primitive-internals follow-ups remain future
  options unless explicitly ticketed later.
- Results are labeled current-source, local-host, and machine-specific.

### Verification

Benchmark script output review, result-file review, workbook/packet summary
review, and horizon diff review.

Completion note (2026-05-30): implemented fold-loop bucket telemetry for
`t_feats`, `t_bars`, `t_ctx`, `t_strat`, `t_target`, `t_fill`, `t_event`, and
`t_state`; fixed the sampled-telemetry index so diagnostic vectors persist;
added `dev/bench/fold_loop_diagnostic.R`; recorded local current-source packet
artifacts; and parked future implications in `inst/design/horizon.md`. Targeted
telemetry, durable-run parity, sweep parity, ledger-writer, and sweep tests
passed. External review approved the batch with no blocking findings.

### Source Reference

- `v0_1_8_8_spec.md`, Sections 5.1 and 8
- `inst/design/horizon.md`, post-v0.1.8.7 remaining fold-loop levers
- `inst/design/ledgr_v0_1_8_7_spec_packet/benchmark_attribution_closeout.md`

### Classification

```yaml
type: diagnostic
surface: fold_loop
scope: current_source_profile
```

---

## LDG-2471: RNG Resume And Pulse-Seed Contract

Priority: P0
Effort: L
Dependencies: LDG-2468
Status: Completed

### Description

Bind and implement the deterministic-only resume/parallel RNG policy. Add
`ctx$pulse_seed` so stochastic strategies can use pulse-specific,
resume-stable, worker-stable randomness without reading ambient `.Random.seed`.

### Tasks

- Add `ledgr_derive_pulse_seed()` or equivalent internal helper derived from
  `(execution_seed, pulse_idx)`.
- Keep the helper aligned with existing `ledgr_derive_seed()` and the
  `ledgr_seed_v1` contract; do not invent an unrelated seed derivation scheme.
- Define `pulse_idx` as the 1-based position in the run's pulse sequence.
- Add `ctx$pulse_seed` to strategy contexts.
- Preserve existing `ctx$seed` semantics.
- Extend static preflight or execution guards so ambient-RNG strategies fail
  loudly for resume and parallel paths with migration guidance.
- Document the deterministic-only resume guarantee and the `ctx$pulse_seed`
  migration pattern.
- Keep seed derivation independent of worker order and global RNG state.

### Acceptance Criteria

- Deterministic strategy resume remains byte-identical.
- Strategies using `ctx$pulse_seed` reproduce across continuous run, resumed
  run, sequential sweep, and parallel-ready execution fixtures.
- Ambient-RNG strategies fail loudly where the policy requires them to fail.
- Per-candidate and per-pulse seed derivation is stable across worker counts.
- Existing seed/reproduction-key tests remain green.

### Verification

Targeted seed, resume, sweep, preflight, and pulse-context tests. Add fixtures
for `ctx$pulse_seed` reproducibility and ambient-RNG fail-loud behavior.

Completion note (2026-05-30): added internal `ledgr_derive_pulse_seed()` as a
`ledgr_derive_seed()` derivative under `ledgr_seed_v1`; exposed
`ctx$pulse_seed` while preserving `ctx$seed`; added structured
`ambient_rng_symbols` to strategy preflight; made ambient-RNG strategies fail
loudly on resume with `ctx$pulse_seed` migration guidance; and updated
contracts, help, and reproducibility docs. Targeted seed, preflight, resume,
sweep parity, sweep, pulse-context, runner, and documentation-contract tests
passed. External review approved the batch with no blocking findings.

### Source Reference

- `v0_1_8_8_spec.md`, Section 4
- `inst/design/horizon.md`, RNG resume non-determinism entry
- `R/fold-core.R`
- `R/sweep.R`
- `R/strategy-preflight.R`
  (`ledgr_derive_seed()` / `ledgr_seed_v1`)

### Classification

```yaml
type: determinism_contract
surface: rng_resume_and_sweep
scope: pulse_seed
```

---

## LDG-2472: Typed Execution Spec

Priority: P0
Effort: L
Dependencies: LDG-2471
Status: Completed

### Description

Replace hand-built run/sweep execution-list construction with an internal
`ledgr_execution_spec()` constructor and validator. This is internal plumbing
for run/sweep drift prevention and worker serialization, not a public API.

### Tasks

- Add an internal `ledgr_execution_spec()` constructor with a spec version and
  validation.
- Route both `ledgr_run()` and `ledgr_sweep()` execution assembly through the
  constructor.
- Preserve existing public APIs and output surfaces.
- Add transition tests proving typed-spec output matches any remaining
  hand-built execution-list equivalent.
- Remove hand-built execution-list call sites once parity is verified.
- Ensure execution specs are serializable for worker dispatch.
- Fail before fold entry on invalid specs.

### Acceptance Criteria

- `ledgr_run()` and `ledgr_sweep()` build equivalent execution specs through
  one constructor.
- Typed-spec parity holds during transition.
- No hand-built execution-list construction remains after parity is proven.
- Existing run/sweep/event/replay parity tests remain green.
- Invalid specs fail clearly before fold entry.
- The spec object is serializable by the planned worker backend.

### Verification

Targeted run/sweep parity tests, serialization tests, invalid-spec tests,
worker-payload dry-run tests, and full fold/sweep test subset.

Completion note (2026-05-30): added internal `ledgr_execution_spec_v1`
construction and validation, routed committed run and sweep candidate fold
payloads through `ledgr_execution_spec()`, made `ledgr_execute_fold()` validate
before unpacking fields, removed hand-built execution-list construction from
production and direct-fold tests, and pinned the constructor as internal-only in
the API export lock. Added execution-spec tests for former-list field-shape
parity, invalid-spec failure, serialization round-trip, and run/sweep routing
through the constructor. Targeted fold/sweep/API tests and the full test suite
passed. External review approved with no blocking findings.

### Source Reference

- `v0_1_8_8_spec.md`, Section 6.1
- `inst/design/horizon.md`, fold-core structural-debt entry
- `R/backtest-runner.R`
- `R/sweep.R`
- `R/fold-engine.R`
- `R/execution-spec.R`

### Classification

```yaml
type: internal_refactor
surface: execution_spec
scope: run_sweep_payload
```

---

## LDG-2473: Parallel Worker Setup And Backend Skeleton

Priority: P0
Effort: L
Dependencies: LDG-2472
Status: Completed

### Description

Add the parallel backend skeleton, worker setup contract, and dependency
handling. `mirai` is the first backend and remains a suggested dependency.
Sequential ledgr must remain backend-free.

### Tasks

- Add `mirai` to `Suggests` if needed.
- Add internal backend availability checks.
- Fail loudly when `workers > 1` is requested and `mirai` is unavailable.
- Add worker setup code for loading ledgr source/package code.
- Extend static preflight metadata to identify worker package needs.
- Attach packages required for unqualified calls on workers using the backend
  setup mechanism, e.g. `mirai::everywhere({ library(pkg) })` where applicable.
- Check `requireNamespace()` for qualified `pkg::fn` uses.
- Add an explicit user override/augmentation mechanism for worker packages.
- Reject or document `.GlobalEnv` helper smuggling as unsupported.
- Add worker setup dry-run tests.

### Acceptance Criteria

- `workers = 1` does not require `mirai`.
- `workers > 1` without `mirai` fails loudly and actionably.
- Worker setup loads declared Tier 2 packages or reports actionable failure.
- Qualified and unqualified package requirements are handled according to the
  spike-grounded policy.
- Sequential sweep behavior is unchanged.
- No worker writes persistent artifacts during setup.

### Verification

Dependency/import checks, worker setup tests, missing-backend tests,
preflight metadata tests, sequential sweep regression tests, and optional manual
worker dry-run on Windows.

### Source Reference

- `v0_1_8_8_spec.md`, Sections 3.3 and 9
- `inst/design/spikes/ledgr_parallelism_spike/summary_report.md`
- `inst/design/spikes/ledgr_parallelism_spike/architecture_synthesis.md`
- `R/strategy-preflight.R`
- `R/sweep.R`

### Classification

```yaml
type: infrastructure
surface: parallel_worker_setup
scope: mirai_backend
```

---

## LDG-2474: Parallel Sweep Dispatch

Priority: P1
Effort: XL
Dependencies: LDG-2473
Status: Completed

### Description

Implement optional candidate-level parallel sweep dispatch over the same fold
core. Parallelism is a dispatch layer, not a second execution engine.

### Tasks

- Add public or experimental `workers` control to `ledgr_sweep()` according to
  the accepted API shape.
- Dispatch candidates to workers using typed execution specs.
- Collect compact candidate results in orchestrator-owned order.
- Preserve sequential result row order, warning association, failure semantics,
  seed derivation, reproduction keys, and promotion provenance.
- Ensure workers return results and do not write candidate ledgers, equity
  curves, feature panels, run telemetry, or promotion artifacts.
- Support `workers = 1` as the sequential reference.
- Add tests for equal sequential/parallel results across worker counts.

### Acceptance Criteria

- `workers = 1` equals existing sequential sweep behavior.
- `workers > 1` uses the same fold core and produces the same rows as
  sequential for deterministic strategies.
- Candidate rows are ordered by candidate order, not worker completion order.
- Candidate warnings and failures attach to the correct candidate.
- `ledgr_candidate_reproduction_key()` output is stable across worker counts
  for the same candidate.
- No persistent heavy artifact rows are written by workers during sweep.

### Verification

Sequential/parallel equality tests, warning/failure ordering tests, reproduction
key stability tests, artifact-count tests, seed tests, and worker-count
variation tests.

### Source Reference

- `v0_1_8_8_spec.md`, Sections 3.1, 3.2, and 9
- `R/sweep.R`
- `R/fold-core.R`
- `R/backtest-runner.R`

### Classification

```yaml
type: parallel_execution
surface: ledgr_sweep
scope: candidate_dispatch
```

---

## LDG-2475: Interrupt Semantics And Parallel Measurement

Priority: P1
Effort: L
Dependencies: LDG-2474
Status: Completed

### Description

Finish the operational parallel contract: discard-all interrupt behavior,
progress/failure reporting where supported, and empirical measurement of worker
overhead and parallel crossover points.

### Tasks

- Implement or document discard-all-on-interrupt behavior.
- Ensure interrupted sweeps do not return partially promotable results unless a
  future partial-result contract explicitly authorizes it.
- Add tests or manual verification for interrupt/cancel behavior where
  practical.
- Measure sequential baseline, worker setup overhead, per-candidate slope, and
  parallel timings across candidate counts and worker counts.
- Include cheap-SMA and feature-heavy workloads where practical.
- Record raw results and environment metadata under `dev/bench/results/`.
- Summarize parallel attribution without claiming speedup from one shape.

### Acceptance Criteria

- Interrupt behavior matches the spec and does not leave ambiguous partial
  results.
- Parallel measurements distinguish startup overhead, per-candidate slope, and
  crossover point.
- Same workload rows compare sequential and parallel current-source runs.
- Results are labeled local-host and machine-specific.
- No public speedup claim exceeds the measured evidence.

### Verification

Interrupt tests/manual verification, benchmark output review, result-file
review, and documentation/closeout review.

Completion note (2026-05-30): implemented the v0.1.8.8 discard-all interrupt
contract for worker-backed sweep collection with structured
`ledgr_parallel_sweep_interrupted` errors and backend cleanup. Documented the
contract in `ledgr_sweep()` help and `inst/design/contracts.md`. Added
`dev/bench/parallel_sweep_measurement.R` to measure worker setup overhead,
candidate-count scaling inputs, worker-count rows, cheap-SMA and feature-heavy
workloads, sequential/parallel equality, and environment metadata. Ran the
smoke harness on the local Windows host; all worker-backed rows matched the
sequential reference, and no crossover was observed for the tiny candidate
counts measured. Raw local result files were written under ignored
`dev/bench/results/`, and the closeout summary was recorded in
`parallel_sweep_measurement_closeout.md`. Targeted parallel sweep and contract
documentation tests passed.

### Source Reference

- `v0_1_8_8_spec.md`, Sections 3.5 and 8
- `dev/bench/`
- `inst/design/spikes/ledgr_parallelism_spike/architecture_synthesis.md`

### Classification

```yaml
type: measurement
surface: parallel_sweep
scope: interrupt_and_attribution
```

---

## LDG-2476: Repo-Local Peer Benchmark And Parity Report

Priority: P2
Effort: XL
Dependencies: LDG-2468
Status: Completed

### Description

Create a reproducible Quarto benchmark report under `dev/bench/`. This is
repo-local developer benchmark documentation and an internal correctness
sanity check, not package documentation, pkgdown content, or public hosted
ranking material.

The report has two purposes:

1. Measure wall-time across same-host peers with the existing comparability
   discipline.
2. Compare ledgr's per-bar equity curves, derived top-line metrics, and
   trade-level outputs against the peer engines as an internal sanity check
   that ledgr's engine produces the right results when given the same inputs.

The parity check is for the maintainer, not for outside readers. It is a
building-phase quality gate, not a marketing artifact.

### Tasks

- Add `dev/bench/peer_benchmark.qmd`.
- Add a `uv`-managed Backtrader environment under `dev/bench/python/backtrader/`
  with `pyproject.toml`, `uv.lock`, and README.
- Run the required same-host peer rows: ledgr canonical TTR-backed SMA, ledgr
  built-in SMA diagnostic, quantstrat, and Backtrader.
- Attempt LEAN Python-strategy mode if local setup is tractable; if brittle but
  feasible, record a preliminary row rather than silently dropping it.
- Keep zipline-reloaded and Ziplime optional and non-blocking.
- Keep published LEAN/Ziplime rows context-only, not in same-host ratios.
- Exclude VectorBT from the event-driven peer table except as a paradigm note.
- Make `dev/bench/peer_comparison.md` point to the new Quarto report as the
  current benchmark artifact.
- Each peer harness emits a canonical-schema equity curve under
  `dev/bench/results/` per peer per workload, plus fills and trade tables where
  the peer exposes comparable data. Missing fills/trade surfaces are recorded
  with explicit unavailable metadata, not silently dropped.
- Compute Tier 1 per-bar parity against ledgr canonical: equity-curve
  correlation, cash trajectory match, per-instrument position match, and
  daily-return correlation.
- Compute Tier 2 derived top-line parity: total return, annualized return,
  volatility, Sharpe ratio, max drawdown.
- Compute Tier 3 trade-level parity where the peer emits comparable trade
  data: trade count, per-trade entry/exit timestamps, entry/exit prices, PnL,
  duration, win rate, average trade.
- Attribute every residual divergence to one of six documented sources:
  indicator initialization window, fill-timing edges, cost/margin defaults,
  position-sizing rounding, timestamp alignment, or float-ordering rounding.
- Persist parity numbers under `dev/bench/results/parity_history/` as
  append-only JSON keyed by release tag and workload, so parity track record
  accumulates across releases.
- Walk one failing parity check end to end in the report as the
  divergence-attribution template, so future cycles inherit the discipline.
- Record the three-source attribution rule in the report: when a parity check
  fails, the candidate explanations are (1) ledgr is wrong, (2) the peer is
  wrong, (3) the harness is wrong; default mental move is to consider all
  three, not to assume ledgr first.
- Label each wall-time row with parity status. Rows failing any parity check
  carry an inline footnote naming the failed check and its attributed source.

### Acceptance Criteria

- Report lives under `dev/bench/` and is not included in package vignettes or
  pkgdown.
- Python peers run through `uv run --project ...`.
- Shared bars are generated once and reused across same-host peers.
- Input hashes, environment metadata, package versions, and timing boundaries
  are visible.
- Optional peers fail/skip loudly with status.
- Report language distinguishes workload-specific same-host rows from general
  speed rankings.
- Each required peer emits a canonical-schema equity curve consumed by the
  parity computer. Fills and trade tables are emitted where the peer exposes
  comparable data; otherwise the peer emits explicit unavailable metadata.
- Tier 1 per-bar parity is computed for every required peer; passes when daily
  equity correlation > 0.999 against ledgr canonical and max single-bar
  divergence < 1% of equity; failures attributed to a documented source.
- Tier 2 derived top-line parity is computed and reported; metric-level
  divergence is honest about whether it follows from a Tier 1 divergence or is
  metric-definition-specific.
- Tier 3 trade-level parity is computed for peers that emit comparable trade
  data; missing trade data is labeled "trade-level parity unavailable", not
  silently dropped.
- Every residual divergence is attributed to one of the six documented
  sources, or flagged as unattributed and queued for investigation.
- Parity history JSON is appended atomically per release tag with no
  destructive rewrites; the history file is the parity track record across
  releases.
- The walked failing-parity example is present and follows the three-source
  attribution rule.
- The wall-time table labels each row with parity status; no row claims faster
  wall time without disclosing whether parity holds.

### Verification

Render or dry-run the Quarto report as practical, run the required peer
harness or smoke shape, inspect raw results/environment metadata, inspect the
parity history JSON for atomic append behavior, review divergence-attribution
text for honesty (especially the three-source default), and manually review
comparability and parity language.

Completion note (2026-05-30): added the repo-local
`dev/bench/peer_benchmark.qmd` report and `dev/bench/peer_benchmark.R` harness.
The harness generates one shared bars file, records an input hash, runs ledgr
canonical TTR, ledgr built-in SMA, quantstrat where installed, and Backtrader
through a `uv`-managed Python project. It also probes separate `uv` projects for
optional zipline-reloaded and LEAN Python tooling, recording environment-ready
or unavailable rows without treating them as parity-comparable engine outputs
until canonical harnesses are wired. It computes Tier 1/Tier 2/Tier 3 parity
surfaces and appends parity history under ignored
`dev/bench/results/parity_history/`. Added the Backtrader, zipline-reloaded,
and LEAN `uv` project files and lockfiles under `dev/bench/python/`. Updated
`peer_comparison.md` to point to the new report as current. Smoke harness output
and closeout evidence are summarized in
`peer_benchmark_parity_closeout.md`. Targeted report/harness checks and package
checks passed; Quarto rendered successfully through the RStudio-bundled
executable, and generated HTML artifacts were removed before commit.

Follow-up note (2026-05-31): three-phase decomposition work was completed after
the 2026-05-30 LDG-2476 closure and does not reopen this ticket. The original
acceptance criteria remain met. The follow-up evidence in
`dev/bench/peer_benchmark/notes/three_phase_decomposition_design.md`,
`dev/bench/peer_benchmark/notes/three_phase_decomposition_results.md`,
`dev/bench/peer_benchmark/notes/ledgr_regression_source_analysis.md`, and
`dev/bench/peer_benchmark/notes/backtrader_scale_check.md` refined the v0.1.9
optimization inputs: durable ledgr is currently faster than the parity-matched
ephemeral path at high fill density, durable ledgr's engine loop is 1.74x
Backtrader on the 500 x 1260 SMA 5/10 workload, and memory output-handler cost
plus in-memory event reconstruction are now explicit v0.1.9 optimization
targets. Headline findings are recorded in
`inst/design/ledgr_v0_1_8_8_spec_packet/peer_benchmark_parity_closeout.md` and
the 2026-05-31 optimization entry in `inst/design/horizon.md`.

### Source Reference

- `v0_1_8_8_spec.md`, Section 7
- `dev/bench/README.md`
- `dev/bench/peer_three_way.R`
- `dev/bench/peer_three_way_backtrader.py`
- `inst/design/ledgr_v0_1_8_7_spec_packet/benchmark_attribution_closeout.md`

### Classification

```yaml
type: benchmark_documentation
surface: dev_bench
scope: repo_local_peer_report_and_internal_parity_check
```

---

## LDG-2479: Self-Profiling Workload Grid Extension

Priority: P1
Effort: M
Dependencies: LDG-2476
Status: Completed

### Description

Extend the existing `dev/bench/shared/run_benchmarks.R` suite with a structured
self-profiling workload grid that varies universe size, history length, fill
density, and persistence mode. This is the v0.1.8.8 contribution to the v0.1.9
single-core optimization round: it captures cost-surface scaling behavior that
the LDG-2476 single-point peer benchmark could not see, and gives the v0.1.9
spec a measured baseline.

This is a self-profiling tool, not a peer benchmark, not a public performance
dashboard, and not a competitive ranking artifact. The grid scenarios are
ledgr-only.

The need for the grid surfaced in LDG-2476 closeout work: the apparent peer
regression at 500x1260 SMA 5/10 decomposed into per-fill cost surfaces
(engine fill emission ~1.7 ms/fill, fills read-back ~1.2 ms/fill with
super-linear scaling) that were invisible at the SMA 20/50 density used by the
v0.1.8.7 closeout. A grid that varies fill density and universe size makes the
cost-surface behavior directly attributable per dimension.

### Tasks

- Add sixteen named density-by-universe-size scenarios to `bench_specs()` in
  `dev/bench/shared/run_benchmarks.R` for both `smoke` and `record` presets.
  The cells are SMA windows {20/50, 5/10} crossed with universe sizes
  {50, 100, 500, 1000} (all at n_pulses = 1260 except small at n_pulses =
  252), crossed with persistence modes {durable, ephemeral}.
- For durable cells, route through the existing `bench_run_scenario_once()`
  path (`ledgr_run` durable).
- For ephemeral cells, route through the existing `bench_run_sweep_once()`
  path with `candidates = 1L`, matching the existing
  `peer_sma_crossover_sweep` ephemeral pattern.
- Add `fills_extract_sec`, `equity_extract_sec`, and `ledger_extract_sec`
  phase columns to `bench_run_scenario_once()` output rows. Time each
  `ledgr_results()` call individually with `system.time()`. Record `NA` for
  cells where the call is not made.
- Add `mus_per_fill_engine` and `mus_per_fill_extract` derived columns to the
  per-row output and the summary CSV.
- Update `bench_comparability_note()` so each new grid scenario carries the
  classification "Self-profiling workload grid cell; not a peer comparison
  row" with the specific `(density, universe_size, persistence)` tuple
  documented.
- Run the `record` preset on the local host with the grid scenarios, write the
  baseline record under `dev/bench/results/`, and capture environment metadata
  the same way the existing suite does.
- Write `dev/bench/notes/workload_grid_baseline_closeout.md` documenting the
  per-cell phase decomposition, per-fill cost ranking, observed scaling
  behavior across each grid dimension, and the v0.1.9 single-core optimization
  target stack derived from the ranking.
- Note in the closeout that ephemeral cells record `snapshot_sec` and
  `t_wall_sec` only (the existing sweep path does not surface per-pulse
  telemetry); per-pulse decomposition on the ephemeral path is deferred to
  v0.1.9.

### Acceptance Criteria

- The sixteen new scenarios appear in both smoke and record presets of
  `bench_specs()`.
- A targeted smoke run, for example
  `Rscript dev/bench/shared/run_benchmarks.R --preset smoke --repeats 1
  --warmup 0 --scenarios
  density_low_small_durable,density_high_small_durable,
  density_low_small_ephemeral,density_high_small_ephemeral`, completes without
  error on the local host and produces a row per cell.
- The existing ten v0.1.8.6 Workstream S scenarios still run unchanged at
  smoke and record presets, with byte-identical scenario definitions.
- Per-row output includes `fills_extract_sec`, `equity_extract_sec`, and
  `ledger_extract_sec` columns. Durable cells populate them; ephemeral cells
  may carry `NA` where the call is not made.
- `mus_per_fill_engine` and `mus_per_fill_extract` are computed in the per-row
  output and the summary CSV.
- The baseline `record` preset run captures all sixteen new scenarios on the
  local host. The record file path is recorded in the closeout note.
- The closeout note ranks observed cost surfaces by both absolute magnitude
  and scaling behavior, derives a v0.1.9 optimization target stack from the
  ranking, and labels the result as local-host, machine-specific,
  current-source evidence rather than a public performance claim.
- No public API changes; no changes to `ledgr_run()`, `ledgr_sweep()`, or the
  function-strategy contract.
- No peer engine work (Backtrader, quantstrat, zipline, LEAN) ships in this
  ticket.

### Verification

Run `Rscript dev/bench/shared/run_benchmarks.R --preset smoke` and confirm the
existing scenarios plus the sixteen new scenarios produce rows without error.
Run `Rscript dev/bench/shared/run_benchmarks.R --preset record --scenarios
<grid-only-list>` on the local host to capture the baseline grid record.
Spot-check the output CSV for the new phase decomposition columns and the
derived per-fill metrics. Review the closeout note for honest scaling claims
and a defensible v0.1.9 target stack.

The largest cells (1000 x 1260 SMA 5/10 durable) may take >10 minutes per run
on the local host. Recording can be done over multiple `--scenarios` calls if
single-session wall time is impractical, as long as the same record file
prefix and environment metadata are preserved.

Completion note (2026-05-31): added sixteen self-profiling grid scenarios to
`dev/bench/shared/run_benchmarks.R`, with SMA density {20/50, 5/10}, universe
size {small, medium, large, xlarge}, and persistence {durable, ephemeral}.
Durable rows now time `ledgr_results()` extraction for equity, fills, and
ledger separately and compute per-fill engine/extraction microsecond metrics.
The smoke preset ran all existing scenarios plus all sixteen grid cells. The
grid-only record preset wrote
`dev/bench/results/ledgr_bench_record_20260531T132910Z_*`, and the baseline
interpretation is recorded in `dev/bench/notes/workload_grid_baseline_closeout.md`.

### Source Reference

- `v0_1_8_8_spec.md`, Section 9 (Workstream G)
- `dev/bench/shared/run_benchmarks.R`
- `dev/bench/notes/workload_grid_baseline_closeout.md`
- `dev/bench/peer_benchmark/notes/ledgr_regression_source_analysis.md`
- `dev/bench/peer_benchmark/notes/backtrader_scale_check.md`
- `dev/bench/peer_benchmark/notes/three_phase_decomposition_design.md`
- `dev/bench/peer_benchmark/notes/three_phase_decomposition_results.md`
- `inst/design/ledgr_v0_1_8_8_spec_packet/peer_benchmark_parity_closeout.md`
- `inst/design/horizon.md` (2026-05-31 [optimization] LDG-2476 peer-benchmark
  turnover cost decomposition entry)

### Classification

```yaml
type: self_profiling_benchmark
surface: dev_bench_workload_grid
scope: density_x_universe_size_x_persistence
```

---

## LDG-2478: Internal Maintainer Manual Skeleton And Stale-Doc Cleanup

Priority: P2
Effort: M
Dependencies: LDG-2468, LDG-2469
Status: Deferred

### Description

Create the internal maintainer-manual skeleton under `inst/design/manual/` and
clean up stale documentation-like surfaces that confuse agents or outside
readers. This is structural cleanup only; it does not require authoring the full
manual in v0.1.8.8.

### Tasks

- Rename or migrate `inst/design/maintainer_review/` to
  `inst/design/manual/`.
- Preserve the current fold-core and feature-value-path workbooks under the new
  manual tree.
- Add `README.md`, `_quarto.yml`, and `index.qmd` for manual navigation and
  conventions.
- Create the manual domain directories: `execution/`, `data/`, `features/`,
  `sweep/`, `observability/`, and `diagrams/`.
- Move only current reusable Mermaid diagrams into the manual tree, or inline
  them in the relevant QMD articles.
- Delete or rewrite stale diagrams, including any schema diagram that still
  documents removed `data_hash` execution identity.
- Delete `inst/schemas/` unless it gains a real implemented schema artifact.
- Audit `man/*.Rd` `system.file("doc", "*.html", package = "ledgr")`
  references against rendered vignette names, and fix broken links.
- Decide whether `inst/testdata/yahoo_mock.csv` remains an installed fixture
  with an explanatory README or moves to `tests/testthat/fixtures/`.
- Update references in the design index, roadmap, horizon, AGENTS notes, and
  active packet files where they point at the old maintainer-review path.

### Acceptance Criteria

- `inst/design/manual/` is the documented home for internal maintainer articles.
- Governance artifacts remain under `inst/design/` and are not mixed into the
  maintainer manual.
- No `inst/design/maintainer_review/` references remain in roadmap, horizon,
  AGENTS notes, design README, or active packet files after the migration.
- Package vignettes remain under `vignettes/`; `inst/doc/` build semantics are
  preserved and not treated as a trash directory.
- Stale standalone diagrams/schemas are removed, rewritten, or explicitly
  classified.
- Installed-vignette links in man pages resolve to current rendered vignette
  names or are corrected.
- Test fixtures under `inst/testdata/` are either documented as installed
  fixtures or moved beside the tests that use them.
- No generated Quarto HTML/cache artifacts are committed unless explicitly
  intended and reviewed.

### Verification

Directory-tree review, stale-path `rg` checks, man-page installed-vignette link
audit, Quarto render/dry-run for the manual index as practical, and package
load or targeted documentation tests as needed.

Deferral note (2026-05-31): deferred by maintainer decision to keep the
v0.1.8.8 release gate focused on completed parallel dispatch, fold-core
diagnostics, peer benchmark, and workload-grid work. This P2 cleanup remains
scoped for a future maintainer-manual / architecture-documentation release and
does not block `LDG-2477`.

### Source Reference

- `v0_1_8_8_spec.md`, Section 8
- `inst/design/maintainer_review/`
- `inst/diagrams/`
- `inst/schemas/`
- `inst/testdata/`
- `man/`

### Classification

```yaml
type: documentation_infrastructure
surface: internal_manual
scope: skeleton_and_stale_doc_cleanup
```

---

## LDG-2477: v0.1.8.8 Release Gate And Closeout

Priority: P0
Effort: M
Dependencies: LDG-2468, LDG-2469, LDG-2470, LDG-2471, LDG-2472, LDG-2473, LDG-2474, LDG-2475, LDG-2476, LDG-2479
Status: Completed

### Description

Run the release gate, close the planning packet, and prepare v0.1.8.8 for merge
and tag. `LDG-2478` slipped by explicit maintainer decision on 2026-05-31; the
core release gate is tied to LDG-2468 through LDG-2476 plus the completed
LDG-2479 workload grid.

### Tasks

- Confirm all required tickets are complete or explicitly deferred.
- Confirm ticket markdown and `tickets.yml` statuses agree.
- Run targeted tests for parallel/determinism/fold-core changes.
- Run full test suite.
- Run package build and check.
- Run or review parallel benchmark attribution.
- Review fold-core workbook freshness and rendered output.
- Review peer benchmark report status if LDG-2476 shipped.
- Review workload grid extension closeout note and baseline record if
  LDG-2479 shipped; confirm the grid extension did not change the existing
  v0.1.8.6 Workstream S scenarios.
- Review maintainer-manual cleanup status if LDG-2478 shipped.
- Update roadmap, horizon, NEWS/release notes, and active-packet references.
- Ensure generated local artifacts are not committed.

### Acceptance Criteria

- Required tests and checks pass or have documented, accepted non-blocking
  caveats.
- Sequential sweep contract remains unchanged.
- Parallel path is deterministic under the accepted worker/RNG policy.
- Fold-core workbook and comments reflect the code that ships.
- Measurements are current-source, local-host, and caveated.
- Release notes do not overclaim parallel speedup or peer superiority.
- The release branch is ready for merge and tag.

### Verification

Targeted tests, full tests, package build/check, benchmark closeout review,
documentation review, and manual release checklist.

Completion note (2026-05-31): completed the v0.1.8.8 release gate with
`LDG-2478` explicitly deferred by maintainer decision. Targeted
parallel/sweep/RNG/execution-spec tests passed, the full local test suite
passed with one expected skip, `R CMD build --no-build-vignettes .` passed, and
`R CMD check --no-manual --no-build-vignettes ledgr_0.1.8.7.tar.gz` completed
with two accepted vignette-output warnings from the no-build-vignettes boundary.
Release evidence and caveats are recorded in `release_closeout.md`.

### Source Reference

- `v0_1_8_8_spec.md`
- `v0_1_8_8_tickets.md`
- `tickets.yml`
- `batch_plan.md`
- `release_closeout.md`

### Classification

```yaml
type: release_gate
surface: release_process
scope: v0.1.8.8
```
