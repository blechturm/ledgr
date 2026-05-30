# v0.1.8.8 Batch Plan

**Status:** Review batching plan for the v0.1.8.8 parallel dispatch,
fold-core maintainability, and repo-local peer benchmark cycle.  
**Scope:** Groups the v0.1.8.8 tickets into implementation/review batches.

v0.1.8.8 makes the optimized v0.1.8.7 engine easier to maintain and safe to
parallelize. The review posture is contract-heavy: sequential sweep remains the
reference implementation; parallelism is candidate dispatch over the same fold
core; RNG and worker behavior must be deterministic; and the fold-core
documentation work is a release goal, not optional polish.

Global review standards:

- Do not add a second execution engine.
- `ledgr_sweep()` sequential behavior remains the reference contract.
- `workers = 1` must be equivalent to sequential sweep.
- `workers > 1` must not change result row order, warning/error association,
  seed derivation, reproduction keys, or promotion provenance.
- Workers must not write candidate ledgers, equity curves, feature panels, run
  telemetry, or promotion artifacts during sweep.
- Sequential ledgr must not depend on `mirai`.
- Ambient RNG is not a supported resume/parallel equivalence mechanism.
  Strategies needing stochastic behavior should use `ctx$pulse_seed`.
- The fold-core workbook and comments should explain invariants and phase
  boundaries without masking behavior changes.
- The mechanical fold-core split must be behavior-neutral and test-backed.
- Benchmarks must be current-source, local-host, and caveated.
- The peer benchmark report lives under `dev/bench/`, not package vignettes or
  pkgdown.
- Internal maintainer articles live under `inst/design/manual/`; governance
  artifacts stay under `inst/design/`; package vignettes stay under
  `vignettes/`; `inst/doc/` build semantics must be preserved.
- No compiled core, target risk, OMS, cost/liquidity, durable identity redesign,
  public distributed execution API, promotion-grade artifact expansion, or
  package-vignette benchmark ships in this cycle.

For future batches in this cycle, wait for code review before committing unless
the maintainer explicitly asks otherwise.

---

## Batch 0: Scope And Packet Alignment

Tickets:

- `LDG-2468` Packet Alignment And v0.1.8.8 Planning State

Purpose:

Finalize the active packet and make the v0.1.8.8 scope unambiguous before
documentation, RNG, execution-spec, or parallel work starts.

Review focus:

- `v0_1_8_8_spec.md`, `v0_1_8_8_tickets.md`, `tickets.yml`, and this
  `batch_plan.md` agree.
- README, roadmap, horizon, and AGENTS point to v0.1.8.8 as the active packet.
- The settled spec-cut decisions are visible and consistent:
  - `mirai` as `Suggests`;
  - hybrid worker dependency handling;
  - deterministic-only resume/parallel RNG with `ctx$pulse_seed`;
  - discard-all interrupt behavior;
  - mandatory internal typed execution spec;
  - mechanical fold-core split paired with docs;
  - explicit event types deferred to v0.2.x RFC;
  - required/optional peer tiers.
- Deferred work remains deferred.
- Empirical closeout is packet review: stale-scope `rg` checks and diff review.

---

## Batch 1: Fold-Core Documentation And Mechanical Split

Tickets:

- `LDG-2469` Fold-Core Documentation And Mechanical Split

Purpose:

Make the fold core maintainable before parallelism adds more execution surfaces.
Refresh the workbook, add useful comments, and mechanically split the source
only if the split is behavior-neutral.

Review focus:

- The workbook is current against post-v0.1.8.7 source.
- The workbook freshness statement and verification date are updated.
- Function coverage is complete for the shipped fold-core source layout.
- Diagrams cover high-level flow, per-pulse execution, event emission,
  reconstruction, and metrics materialization.
- Comments explain invariants, phase boundaries, replay-sensitive transitions,
  accounting transitions, or parity-sensitive duplication.
- Comments do not narrate obvious code.
- Any file split is mechanical: no public API changes, no behavior changes, no
  test-only assumptions promoted to production.
- Tests cover fold, sweep, replay, fills, and metrics surfaces.
- Empirical closeout includes package load and workbook function-reference
  checks plus rendered-workbook review.

---

## Batch 2: Fold-Loop Diagnostic Profile

Tickets:

- `LDG-2470` Fold-Loop Diagnostic Profile

Purpose:

Capture current-source diagnostic evidence for the remaining pure-R fold loop.
This batch names buckets for documentation and future planning; it is not an
optimization implementation batch.

Review focus:

- Diagnostic buckets have explicit timing boundaries.
- Candidate buckets include context access/building, bar/feature reads,
  strategy callback, target/order conversion, fill resolution, state update,
  and event emission.
- Results are current-source and local-host.
- At least one turnover shape is measured; one low-turnover or wide shape is
  preferred if practical.
- The workbook/packet summary does not claim a new speedup.
- Future levers are parked in horizon rather than silently promoted.
- Empirical closeout is benchmark script output, result-file review, and
  horizon diff review.

---

## Batch 3: RNG And Pulse-Seed Policy

Tickets:

- `LDG-2471` RNG Resume And Pulse-Seed Contract

Purpose:

Make stochastic strategy behavior explicit before parallelism. Resume and
parallel equivalence are guaranteed for strategies deterministic in
`(ctx, params)`, and `ctx$pulse_seed` becomes the supported migration path for
pulse-specific randomness.

Review focus:

- `ctx$seed` retains existing semantics.
- `ctx$pulse_seed` is derived from `(execution_seed, pulse_idx)`.
- Pulse-seed derivation stays aligned with existing `ledgr_derive_seed()` /
  `ledgr_seed_v1` semantics.
- `pulse_idx` is the 1-based position in the run's pulse sequence.
- Per-candidate and per-pulse seeds do not depend on global RNG state, worker
  order, timestamps, event sequence numbers, or worker-local counters.
- Ambient-RNG strategies fail loudly for resume/parallel paths according to the
  accepted policy.
- `ctx$pulse_seed` strategies reproduce across continuous/resumed and
  sequential/parallel fixtures.
- Documentation gives a clear migration pattern.
- Empirical closeout includes seed, resume, sweep, preflight, and pulse-context
  tests.

---

## Batch 4: Typed Execution Spec

Tickets:

- `LDG-2472` Typed Execution Spec

Purpose:

Replace divergent hand-built run/sweep execution lists with one internal
constructor and validator before worker payloads depend on that shape.

Review focus:

- `ledgr_execution_spec()` is internal-only.
- Public `ledgr_run()` and `ledgr_sweep()` APIs do not change.
- Run and sweep route through the same constructor.
- Spec validation fails before fold entry.
- Spec objects are serializable for worker dispatch.
- Byte-identical execution-list parity holds during transition.
- Hand-built execution-list call sites are removed once parity is proven.
- Existing run/sweep/event/replay parity tests remain green.
- Empirical closeout includes serialization and invalid-spec tests.

---

## Batch 5: Parallel Worker Setup And Backend Skeleton

Tickets:

- `LDG-2473` Parallel Worker Setup And Backend Skeleton

Purpose:

Install the parallel backend skeleton and worker setup contract without yet
turning on full candidate dispatch.

Review focus:

- `mirai` is a suggested dependency, not required for sequential ledgr.
- `workers > 1` without `mirai` fails loudly with an actionable message.
- `workers = 1` does not require or initialize `mirai`.
- Worker setup loads ledgr source/package code correctly.
- Static preflight emits worker dependency metadata.
- Unqualified package calls are handled by worker attachment, e.g.
  `mirai::everywhere({ library(pkg) })` where applicable.
- Qualified `pkg::fn` calls are handled by `requireNamespace()` checks.
- User worker package overrides/augmentations are supported.
- `.GlobalEnv` helper smuggling is unsupported or explicitly rejected.
- Empirical closeout includes missing-backend, setup, preflight metadata, and
  sequential sweep regression tests.

---

## Batch 6: Parallel Sweep Dispatch

Tickets:

- `LDG-2474` Parallel Sweep Dispatch

Purpose:

Implement candidate-level parallel dispatch over the same fold core. This is
the main parallel feature batch.

Review focus:

- Parallelism is candidate-level only.
- `workers = 1` equals the sequential reference.
- `workers > 1` produces identical deterministic candidate results.
- Candidate rows are collected in candidate order.
- Warning and failure rows attach to the correct candidate independent of
  completion order.
- `ledgr_candidate_reproduction_key()` output is stable across worker counts.
- Workers return compact candidate results to the orchestrator.
- Workers do not write heavy persistent artifacts during sweep.
- Empirical closeout includes sequential/parallel equality, worker-count
  variation, warning/failure ordering, artifact-count, seed, and reproduction
  key tests.

---

## Batch 7: Interrupt Semantics And Parallel Measurement

Tickets:

- `LDG-2475` Interrupt Semantics And Parallel Measurement

Purpose:

Close the operational parallel contract and measure the real value of parallel
dispatch without overclaiming.

Review focus:

- Interrupt behavior is discard-all for v0.1.8.8.
- Interrupted sweeps do not return partially promotable results.
- Partial-result semantics remain deferred.
- Measurements distinguish startup overhead, per-candidate slope, and crossover
  point.
- Measurements cover worker counts and candidate counts.
- Cheap-SMA and feature-heavy workloads are used where practical.
- Results are current-source, local-host, and machine-specific.
- No speedup is claimed from one shape alone.
- Empirical closeout includes raw result files, environment metadata, and a
  closeout summary.

---

## Batch 8: Repo-Local Peer Benchmark Report

Tickets:

- `LDG-2476` Repo-Local Peer Benchmark Report

Purpose:

Create the repo-local Quarto benchmark report and `uv`-managed Python peer
environment. This is valuable but separable if the cycle becomes too wide.

Review focus:

- The report lives under `dev/bench/`, not package vignettes or pkgdown.
- Required rows: ledgr canonical TTR, ledgr built-in SMA diagnostic,
  quantstrat, Backtrader.
- Backtrader runs through a `uv`-managed Python environment.
- LEAN Python-strategy mode is attempted if local setup is tractable; if
  brittle but feasible, it is labeled preliminary.
- Optional peers skip/fail loudly with status.
- Shared bars are generated once and reused across same-host peers.
- Input hashes, package versions, environment metadata, and timing boundaries
  are visible.
- Published LEAN/Ziplime rows remain context-only.
- VectorBT remains excluded from the event-driven peer table except as a
  paradigm note.
- `dev/bench/peer_comparison.md` points to the new report as the current
  artifact.
- Empirical closeout includes a render/dry-run and result/comparability review.

---

## Batch 9: Maintainer Manual Skeleton And Stale-Doc Cleanup

Tickets:

- `LDG-2478` Internal Maintainer Manual Skeleton And Stale-Doc Cleanup

Purpose:

Create the internal maintainer-manual skeleton and remove or classify stale
documentation-like surfaces. This is useful but separable if the cycle becomes
too wide.

Review focus:

- `inst/design/manual/` becomes the documented internal maintainer article
  tree.
- `inst/design/` governance artifacts remain separate from manual articles.
- Current `fold_core_workbook.qmd` and `feature_value_path_workbook.qmd` are
  preserved under the new manual tree.
- Stale `inst/diagrams/` files are moved, inlined, rewritten, or deleted.
- Any diagram that still documents removed `data_hash` execution identity is
  not carried forward as current architecture.
- `inst/schemas/` is deleted unless it gains a real implemented schema
  artifact.
- `inst/doc/` is not deleted as "trash"; installed-vignette build semantics are
  preserved.
- `man/*.Rd` `system.file("doc", "*.html", package = "ledgr")` links are
  audited against current rendered vignette names.
- `inst/testdata/yahoo_mock.csv` is either documented as an installed test
  fixture or moved beside the tests that consume it.
- No generated Quarto HTML/cache artifacts are committed accidentally.
- Empirical closeout includes stale-path `rg` checks and directory-tree review.

---

## Batch 10: Release Gate And Closeout

Tickets:

- `LDG-2477` v0.1.8.8 Release Gate And Closeout

Purpose:

Verify the full release, close the packet, and prepare merge/tag. If Batch 8
and/or Batch 9 is explicitly deferred, record the maintainer decision and keep
the core release gate tied to Batches 0-7.

Review focus:

- Ticket statuses agree between markdown and YAML.
- Required tickets are complete or explicitly deferred by maintainer decision.
- Sequential sweep remains the reference contract.
- Parallel path is deterministic under the accepted worker/RNG policy.
- Fold-core workbook and comments reflect the code that ships.
- No generated local artifacts are committed.
- Full tests and package checks pass or have documented accepted caveats.
- Parallel benchmark closeout is honest about overhead and crossover.
- Peer benchmark and maintainer-manual cleanup are complete or explicitly
  deferred by maintainer decision.
- Release notes do not overclaim parallel speedup or peer superiority.
- Roadmap, horizon, design index, AGENTS, and NEWS/release notes are updated.
