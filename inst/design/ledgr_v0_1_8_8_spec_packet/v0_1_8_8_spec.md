# ledgr v0.1.8.8 Spec

**Status:** Draft planning spec for v0.1.8.8.  
**Target Branch:** `v0.1.8.8`.  
**Scope:** Parallel sweep dispatch and determinism; fold-core maintainer
documentation and code legibility; repo-local reproducible peer benchmark
reporting.  
**Non-scope for this pass:** package-vignette peer marketing, hosted benchmark
claims, a ledgr-authored compiled fold core, target risk / OMS / cost model
work, durable identity byte redesign, public distributed execution APIs,
promotion-grade sweep artifact expansion, and semantic event-schema changes
unless explicitly promoted by a separate decision.

---

## 0. Source Inputs

Authoritative inputs:

- `inst/design/contracts.md`
- `inst/design/README.md`
- `inst/design/ledgr_roadmap.md`
- `inst/design/horizon.md`
- `inst/design/rfc_cycle.md`
- `inst/design/rfc/rfc_optimization_round_v0_1_8_7_synthesis.md`
- `inst/design/adr/0004-dependency-footprint-and-strategy-interface.md`

v0.1.8.8 planning inputs:

- `inst/design/maintainer_review/fold_core_workbook.qmd`
- `inst/design/maintainer_review/feature_value_path_workbook.qmd`
- `inst/design/ledgr_v0_1_8_7_spec_packet/benchmark_attribution_closeout.md`
- `dev/bench/README.md`
- `dev/bench/peer_three_way.R`
- `dev/bench/peer_three_way_backtrader.py`
- `dev/bench/peer_sweep_three_way.R`

Parallelism inputs:

- `inst/design/spikes/ledgr_parallelism_spike/summary_report.md`
- `inst/design/spikes/ledgr_parallelism_spike/architecture_synthesis.md`
- `inst/design/rfc/rfc_parallelism_spike_architecture_consequences.md`
- `inst/design/rfc/rfc_parallelism_spike_architecture_consequences_response.md`
- `inst/design/architecture/ledgr_v0_1_8_sweep_architecture.md`

Horizon entries promoted or partially promoted:

- `2026-05-13 [infrastructure] Public parallel sweep backend`
- `2026-05-13 [infrastructure] Parallel worker setup and Tier 2 packages`
- `2026-05-13 [infrastructure] mori as transport, not hot lookup`
- `2026-05-13 [infrastructure] Worker-local read-only DuckDB transport`
- `2026-05-13 [infrastructure] Parallel interrupt and partial-result semantics`
- `2026-05-28 [execution] RNG resume is non-deterministic for stochastic strategies`
- `2026-05-28 [architecture] Fold-core structural debt surfaced by adversarial review`
- `2026-05-30 [optimization] Post-v0.1.8.7 remaining fold-loop levers`

This spec promotes only the work below. Other horizon entries remain
non-binding unless explicitly pulled into a later ticket.

---

## 1. Thesis

v0.1.8.7 removed the largest single-core hot-path rocks and legacy execution
gunk. v0.1.8.8 should make the optimized engine easier to maintain and safer to
parallelize.

The release has three tracks:

1. **Parallel sweep dispatch and determinism.** Add an optional public parallel
   sweep path while keeping sequential `ledgr_sweep()` as the reference
   implementation and preserving deterministic row ordering, failure reporting,
   warning association, seed derivation, and promotion provenance.
2. **Fold-core legibility.** Turn the current fold-core workbook into a
   current, function-complete maintainer guide and add professional inline
   comments to the fold-core source where the control flow is load-bearing.
3. **Repo-local peer benchmark report.** Add a reproducible Quarto benchmark
   report under `dev/bench/`, with `uv`-managed Python peer environments and
   careful same-host comparability language.

The release should not reopen the v0.1.8.7 optimization architecture. The
single-core pure-R fold remains the reference implementation. Parallelism is a
candidate-dispatch layer over the same fold core, not a second engine.

---

## 2. Release Goals

v0.1.8.8 has eight release goals:

1. Add a public, optional parallel sweep dispatch path that preserves the
   sequential sweep contract and fails loudly when required worker dependencies
   are unavailable.
2. Define deterministic per-candidate seed derivation and result ordering so
   parallel worker completion order cannot change sweep rows, warnings, errors,
   or promotion provenance.
3. Settle RNG resume semantics for stochastic strategies in a way that aligns
   with parallel seed handling.
4. Specify worker package setup, Tier 2 dependency handling, worker-local input
   transport, interrupt semantics, warning/error capture, and partial-result
   behavior before implementation.
5. Refresh `fold_core_workbook.qmd` against current source and make it a
   function-complete maintainer guide with diagrams, verified claims, and clear
   explanation of run/sweep fold flow.
6. Add inline comments in `R/fold-core.R` and related fold-core files where
   they explain invariants, phase boundaries, non-obvious state transitions, or
   parity-sensitive replay logic.
7. Produce a current-source intra-loop diagnostic profile that splits the
   remaining pure-R fold loop into named sub-buckets without turning that
   diagnostic into an optimization mandate.
8. Add a repo-local, reproducible peer benchmark Quarto report under
   `dev/bench/`, including same-host ledgr / quantstrat / Backtrader rows and
   a `uv`-managed Python environment for Python peers.

The release succeeds when the parallel path is deterministic, the fold core is
substantially easier for maintainers to reason about, and the benchmark report
can be re-run from a clean repository checkout without relying on ambient
Python packages.

---

## 3. Workstream A: Parallel Sweep Dispatch

### 3.1 Bound Semantics

Sequential sweep remains the reference implementation:

- `workers = 1` or omitted must preserve existing `ledgr_sweep()` behavior.
- Parallel dispatch must call the same fold core as sequential sweep.
- Parallel dispatch must not introduce a second execution engine.
- Parallel dispatch must not write candidate ledgers, equity curves, features,
  run telemetry, or promotion artifacts from workers.
- Workers return compact candidate results to the orchestrator.
- The orchestrator owns final result ordering, warning/error association, and
  any durable write performed after the sweep.

Parallel dispatch is candidate-level only. It does not parallelize one
candidate's fold loop.

### 3.2 Determinism Requirements

Parallel execution must be deterministic with respect to the sequential sweep
contract:

- Candidate result rows are ordered by candidate order, not worker completion
  order.
- Candidate warnings are attached to the same candidate row independent of
  worker scheduling.
- Candidate failures produce the same failure row semantics independent of
  worker scheduling.
- Per-candidate seeds are derived from stable sweep identity and candidate
  identity, not from global RNG state or worker order.
- Promotion provenance and reproduction keys remain stable for the same
  candidate.
- `ledgr_candidate_reproduction_key()` is the byte-stable surface that must
  remain identical for the same candidate across worker counts.

The seed derivation rule must be documented and tested before workers are
enabled.

### 3.3 Worker Setup

The first parallel backend is `mirai`, kept as a suggested dependency so
sequential ledgr remains backend-free. If `workers > 1` is requested and
`mirai` is unavailable, ledgr must fail loudly with an actionable install
message. It must not silently fall back to sequential execution.

Worker dependency declaration is hybrid:

- static strategy preflight emits worker dependency metadata;
- packages required for unqualified calls are attached on workers;
- packages used only through `pkg::fn` are checked with `requireNamespace()`;
- users may augment the detected set with an explicit worker package argument;
- setup failures report the offending package and candidate context where
  possible.

Helpers must be package functions, explicit task payloads, or explicit
registered objects. Do not rely on arbitrary `.GlobalEnv` state being present
on workers.

Windows-safe serialization-based assumptions are preferred over fork-only
assumptions. Sequential ledgr must not depend on any parallel backend package.

### 3.4 Worker Input Transport

Allowed first-pass transport:

- serialized in-memory candidate payloads when small enough;
- sealed snapshot path + metadata opened read-only by each worker, if the
  implementation chooses the worker-local DuckDB path.

Non-scope for the first pass:

- shared mutable DBI connections across workers;
- unsynchronized concurrent writes to one DuckDB store;
- `mori` as hot per-pulse feature lookup representation;
- remote/distributed execution APIs.

`mori` remains a possible transport/memory-pressure tool, not the default
feature lookup representation.

### 3.5 Interrupts, Progress, And Partial Results

The first implementation uses a small, explicit contract:

- deterministic complete-result output when all candidates finish;
- discard-all-on-interrupt behavior for the first public parallel path;
- no partial-result return.

Partial-result behavior remains out of scope. A future partial-result contract
must define atomicity, row ordering, error state, promotion eligibility, and
reproducibility guarantees before implementation.

---

## 4. Workstream B: RNG Resume And Ambient RNG Discipline

v0.1.8.8 must settle the verified resume gap for stochastic strategies.

Current verified state:

- deterministic strategies resume correctly because state is reconstructed from
  events;
- stochastic strategies can diverge on resume because `.Random.seed` is not
  restored to the point it would have reached in a continuous run.

Binding policy:

- resume equivalence is guaranteed for strategies that are deterministic given
  `(ctx, params)`;
- strategies must not depend on ambient `.Random.seed` for resume or parallel
  equivalence;
- ambient-RNG strategies fail loudly for resume / parallel paths with migration
  guidance;
- `ctx$seed` remains the per-execution seed derived from the sweep/run seed
  contract;
- v0.1.8.8 adds `ctx$pulse_seed`, a stable per-pulse seed derived from
  `(execution_seed, pulse_idx)`, so stochastic strategies can generate
  pulse-specific but resume-stable and worker-stable randomness without reading
  ambient RNG state.
- `pulse_idx` is the 1-based position of the pulse in the run's pulse
  sequence, not a timestamp hash, event sequence number, or worker-local
  counter.

The parallel path must not depend on global RNG state. Per-candidate seeds and
per-pulse seeds are derived from stable identities, not worker order.

Acceptance gates:

- deterministic strategy resume remains byte-identical;
- ambient-RNG strategy resume / parallel execution fails loudly according to
  the accepted policy;
- strategies using `ctx$pulse_seed` are reproducible across continuous,
  resumed, sequential sweep, and parallel sweep execution;
- parallel candidate seeds are stable across worker counts and worker
  completion order;
- tests prove `workers = 1` and `workers > 1` produce identical candidate
  results for deterministic strategies.

---

## 5. Workstream C: Fold-Core Maintainer Documentation

This workstream is mandatory for v0.1.8.8.

### 5.1 Workbook Refresh

Refresh `inst/design/maintainer_review/fold_core_workbook.qmd` so it is current
against the post-v0.1.8.7 source.

Required properties:

- state clearly that it is internal maintainer documentation, not a user-facing
  article and not a contract;
- verify all line anchors or replace stale anchors with search-stable function
  references where line drift is likely;
- explain the run and sweep call graph;
- explain every function in `R/fold-core.R` or explicitly classify the function
  as moved, deprecated, test-only, or out of current scope;
- explain the event source-of-truth model and all view reconstruction paths;
- document the remaining divergence between run and sweep reconstruction paths;
- document the current output handler contracts;
- include diagrams for high-level flow, per-pulse execution, event emission,
  reconstruction, and metrics materialization;
- include a current-source intra-loop profile summary, clearly marked as
  diagnostic evidence rather than a binding optimization plan;
- update the workbook freshness statement and verification date as part of the
  release.

The workbook may reference `feature_value_path_workbook.qmd` where feature
projection and pulse-context data flow interact with the fold.

### 5.2 Inline Comments

Add comments to fold-core source where they reduce maintainer risk:

- before major phase boundaries;
- before replay-sensitive state transitions;
- before event-ordering or timestamp-ordering invariants;
- before non-obvious accounting transitions;
- around output-handler and reconstruction boundaries;
- around any intentionally duplicated algorithm that exists for performance or
  parity reasons.

Do not add comments that merely repeat obvious code. Comments should explain
why the block exists, what invariant it preserves, or what must stay in sync.

### 5.3 Documentation Non-Goals

This workstream does not authorize semantic refactors by itself. In
particular, the following require explicit tickets:

- changing event schema or event types;
- changing replay/equity algorithms;
- changing run/sweep artifact semantics;
- changing public strategy context surfaces.

---

## 6. Workstream D: Fold-Core Structural Containment

The documentation pass may surface small structural changes. Only bounded,
reviewable containment work is in scope.

### 6.1 Typed Execution Spec

v0.1.8.8 must add an internal typed `ledgr_execution_spec()` constructor and
validator. It is not a public API.

Intent:

- replace hand-built, equivalent-but-not-identical run/sweep execution lists
  with a validated internal value object;
- make worker serialization explicit;
- reduce run/sweep drift before parallelism multiplies execution entry points.

Acceptance gates:

- `ledgr_run()` and `ledgr_sweep()` build equivalent execution specs through
  one constructor;
- byte-identical execution-list parity holds between the typed-spec path and
  any remaining hand-built equivalent during the transition;
- all existing run/sweep parity tests remain green;
- the execution spec is serializable for worker dispatch;
- invalid execution specs fail before fold entry.
- hand-built execution-list call sites are removed once typed-spec parity is
  verified across run and sweep tests.

### 6.2 File Split

Splitting `R/fold-core.R` is in scope only as a mechanical refactor paired with
the documentation refresh. The workbook should describe the structure that
ships, so the split and workbook update land together.

Allowed split targets:

- fold engine;
- event/view reconstructors;
- metrics helpers;
- test-only replay helpers if still needed.

Acceptance gates:

- no behavioral changes;
- no public API changes;
- imports/source loading remain stable;
- targeted fold, sweep, replay, and metrics tests pass.

### 6.3 Explicit Event Types

`POSITION_SEED` and reserved `FEE` / `DIVIDEND` / `SPLIT` event types are
deferred from v0.1.8.8. They must not be slipped into this release as a cleanup
side effect.

A dedicated explicit-event-types RFC is scheduled for the v0.2.x corporate
actions / instrument-master arc. It must address:

- DB schema and migration impact;
- event-stream parity or accepted intentional parity change;
- replay semantics;
- opening-position accounting;
- promotion/reproduction keys;
- docs and examples.

Opening-position event semantics remain unchanged in v0.1.8.8.

### 6.4 Deferred Structural Debt

The following remain deferred unless separately authorized:

- one production replay kernel;
- phased pulse for portfolio-level risk;
- batch-aware cost model;
- compiled fold core;
- matrix-canonical public strategy surface.

---

## 7. Workstream E: Repo-Local Peer Benchmark Report

This workstream creates a reproducible benchmark report in the repository. It
is not package documentation.

Required location:

```text
dev/bench/
  peer_benchmark.qmd
  python/
    backtrader/
      pyproject.toml
      uv.lock
      README.md
```

Rendered output, if tracked, must also live under `dev/bench/` and be clearly
marked as local, machine-specific benchmark evidence.

### 7.1 Scope

The report must cover:

- ledgr canonical TTR-backed SMA path;
- ledgr built-in SMA diagnostic path;
- quantstrat;
- Backtrader via a `uv`-managed Python environment.

Strongly recommended if local setup allows:

- LEAN Python-strategy mode. This is the verdict-setting peer row for the later
  compiled-core scoping question because it measures a compiled engine paying
  an interpreted-language strategy boundary. If local setup is brittle but
  feasible, include a clearly labeled preliminary row rather than silently
  dropping the measurement.

Optional later peers:

- zipline-reloaded, in a separate `uv` project;
- Ziplime / Ziplime-Polars, only if a local pinned environment can run it.

Context-only rows:

- published LEAN references;
- published Ziplime references.

Context rows must not be included in same-host ratios.

VectorBT remains excluded from the main event-driven peer table because it is a
different vectorized paradigm. It can be mentioned only as a category mismatch.

The new Quarto report supersedes `dev/bench/peer_comparison.md`, which remains
historical pre-Lane-B input and should point readers to the current report.

### 7.2 Reproducibility Requirements

The benchmark report must:

- generate shared bars once;
- store shared-input hashes/provenance;
- run all same-host peers against the same generated data shape;
- load current-source ledgr with the existing installed-package mismatch guard;
- run Python peers through `uv run --project ...`;
- write raw results and environment metadata under `dev/bench/results/`;
- make package versions visible in the report;
- fail loudly when optional peers are unavailable.

Python environments should be split by peer. Backtrader must not share a Python
environment with zipline-reloaded if their dependency pins conflict.

### 7.3 Benchmark Language

The report must be careful about comparability:

- same-host rows are workload-specific, not global speed rankings;
- timing boundaries must be stated per engine;
- ledgr canonical peer rows use TTR-backed vectorized features and the
  `features_wide` cross-sectional strategy surface;
- quantstrat uses TTR-backed indicators;
- Backtrader uses its native indicator implementation unless a separate
  precomputed-indicator sensitivity row is added;
- some wall-time differences reflect each engine's idiomatic strategy API, not
  only fold-loop speed;
- ledgr durable-run rows persist ledger/equity artifacts where peers may be
  in-memory only, and that asymmetry must be labeled.

The report may include a "safe language" section for release notes, but it must
not create a package-vignette or pkgdown benchmark page.

---

## 8. Measurement Gates

v0.1.8.8 must preserve the v0.1.8.7 measurement discipline.

Required measurements:

- sequential baseline sweep timing before parallel work;
- parallel sweep timing across candidate counts and worker counts;
- worker setup overhead;
- deterministic equality between sequential and parallel rows;
- current-source intra-loop profile for fold-core documentation;
- peer benchmark report rerun after the benchmark harness is finalized.

Recommended benchmark dimensions:

- cheap SMA workload;
- feature-heavy workload where sweep amortization can matter;
- small, medium, and record-width shapes;
- Windows host first, because Windows-safe behavior is a release goal.

Do not claim parallel speedup from one shape alone. Report startup overhead,
per-candidate slope, and crossover point where parallelism begins to pay.

---

## 9. Verification Gates

Release-ticket work must include targeted tests for:

- sequential `ledgr_sweep()` contract unchanged;
- `workers = 1` equals sequential reference;
- `workers > 1` deterministic ordering independent of completion order;
- warning and failure rows attached to the correct candidate;
- per-candidate seed derivation independent of worker count;
- missing worker dependency fails loudly;
- worker setup loads declared Tier 2 packages or reports actionable failure;
- no worker writes heavy artifacts to persistent ledgr tables during sweep;
- interruption behavior matches the accepted contract;
- deterministic strategy resume remains byte-identical;
- ambient-RNG strategies fail loudly where the accepted policy requires it;
- `ctx$pulse_seed` strategies reproduce across continuous/resumed and
  sequential/parallel execution;
- typed execution specs match any remaining hand-built equivalent during the
  transition;
- fold-core workbook freshness statement and verification date are updated as
  part of release closeout;
- fold-core workbook function-name references exist in the current source;
- fold-core comments do not mask behavior changes;
- `ledgr_candidate_reproduction_key()` output is stable across worker counts
  for the same candidate;
- peer benchmark report runs or skips optional peers with clear status.

Full package tests and package check are required before release.

---

## 10. Settled Spec-Cut Decisions

These decisions are bound for ticket cut:

| # | Decision | Bound answer |
| --- | --- | --- |
| 1 | Parallel backend | `mirai` as `Suggests`; fail loudly when `workers > 1` and backend is unavailable. |
| 2 | Worker dependency declaration | Hybrid: static preflight emits worker dependency metadata; users may augment with explicit worker packages. |
| 3 | RNG resume policy | Deterministic-only resume guarantee for strategies deterministic in `(ctx, params)`; add `ctx$pulse_seed`; fail loudly for ambient-RNG resume / parallel use. |
| 4 | Partial-result policy | Discard-all-on-interrupt for v0.1.8.8; defer partial-result contract. |
| 5 | Typed execution spec | Mandatory internal `ledgr_execution_spec()` constructor and validator in v0.1.8.8. |
| 6 | File split | Pair mechanical `R/fold-core.R` split with Batch 1 documentation refresh. |
| 7 | Explicit event types | Defer from v0.1.8.8; schedule dedicated RFC in the v0.2.x corporate-actions arc. |
| 8 | Peer list | Required: ledgr canonical, ledgr built-in diagnostic, quantstrat, Backtrader. Strongly recommended if local setup allows: LEAN Python-strategy mode. Optional: zipline-reloaded, Ziplime. |

---

## 11. Proposed Batch Shape

Initial batch plan, subject to review:

1. **Batch 0 - Packet and scope alignment.** Finalize spec, tickets, batch
   plan, review prompts, and the settled decision table.
2. **Batch 1 - Fold-core documentation and mechanical split.** Split
   `R/fold-core.R` along engine / reconstruction / metrics boundaries if the
   split remains mechanical, then update workbook, diagrams, function inventory,
   and source comments against the structure that ships. No behavior changes.
3. **Batch 2 - Intra-loop diagnostic profile.** Produce current-source fold
   sub-bucket measurements and park future optimization options in horizon.
4. **Batch 3 - RNG and seed policy.** Add `ctx$pulse_seed`, ambient-RNG
   fail-loud behavior for resume / parallel use, and deterministic seed tests.
5. **Batch 4 - Execution spec / worker payload boundary.** Add typed execution
   spec constructor, validator, parity tests, and worker-serializable payload
   shape.
6. **Batch 5 - Parallel worker setup and backend skeleton.** Add `mirai`
   backend setup, hybrid dependency handling, and fail-loud unavailable-backend
   behavior.
7. **Batch 6 - Parallel sweep dispatch.** Implement candidate dispatch,
   deterministic collection, warnings, errors, and result ordering.
8. **Batch 7 - Interrupt/progress semantics and measurement.** Finish
   user-facing operational behavior and parallel attribution.
9. **Batch 8 - Repo-local peer benchmark report.** Add `dev/bench` Quarto
   report and `uv`-managed Backtrader environment; add LEAN Python-strategy
   mode if local setup is tractable.
10. **Batch 9 - Release gate.** Full tests, package check, benchmark closeout,
    docs review, and release notes.

If the cycle becomes too wide, keep Batches 0-7 as the core release and move
Batch 8 to a later same-branch documentation ticket. Do not drop Batch 1; the
fold-core maintainer documentation is a release goal.

---

## 12. Future Obligations Recorded

Later work, not authorized here:

- compiled fold core;
- one production replay kernel;
- portfolio-level phased pulse and target-risk affordability;
- batch-aware transaction cost / liquidity model;
- promotion-grade sweep artifact expansion;
- explicit event types RFC, scheduled for the v0.2.x corporate-actions arc per
  Section 6.3;
- external package output adapters;
- point-in-time data tables and external regressor snapshots;
- public hosted benchmark dashboard;
- LEAN C# / native-strategy benchmark claims outside Python-strategy mode;
- same-host peer benchmark claims beyond rows actually measured by the repo
  harness.
