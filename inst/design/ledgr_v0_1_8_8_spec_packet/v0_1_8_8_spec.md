# ledgr v0.1.8.8 Spec

**Status:** Release-gate closeout spec for v0.1.8.8.
**Target Branch:** `v0.1.8.8`.  
**Scope:** Parallel sweep dispatch and determinism; fold-core maintainer
documentation and code legibility; repo-local reproducible peer benchmark
reporting with internal cross-engine parity sanity check; self-profiling
workload grid extension as input to the v0.1.9 single-core optimization
round. The internal maintainer-manual skeleton and stale documentation cleanup
ticket was explicitly deferred on 2026-05-31.
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

The release ships four tracks and records one explicit deferral:

1. **Parallel sweep dispatch and determinism.** Add an optional public parallel
   sweep path while keeping sequential `ledgr_sweep()` as the reference
   implementation and preserving deterministic row ordering, failure reporting,
   warning association, seed derivation, and promotion provenance.
2. **Fold-core legibility.** Turn the current fold-core workbook into a
   current, function-complete maintainer guide and add professional inline
   comments to the fold-core source where the control flow is load-bearing.
3. **Repo-local peer benchmark report and internal parity sanity check.** Add
   a reproducible Quarto benchmark report under `dev/bench/`, with
   `uv`-managed Python peer environments, careful same-host comparability
   language, and an internal cross-engine parity check on equity curves,
   derived top-line metrics, and trade-level outputs as a building-phase
   sanity check that ledgr's engine produces the right results when given
   equivalent inputs.
4. **Self-profiling workload grid extension.** Extend the existing
   `dev/bench/shared/run_benchmarks.R` suite with a structured grid that
   varies universe size, history length, fill density, and persistence mode,
   together with post-fold extraction phase decomposition. The grid is
   ledgr-only self-profiling, not a peer comparison, and feeds the v0.1.9
   single-core optimization spec with measured cost-surface scaling
   evidence the LDG-2476 single-point peer benchmark could not see.
5. **Deferred maintainer manual cleanup.** `LDG-2478` would establish
   `inst/design/manual/` as the internal maintainer-facing article tree and
   remove or quarantine stale installed-doc, diagram, schema, and fixture
   surfaces. It was deferred by maintainer decision on 2026-05-31 and does not
   block v0.1.8.8.

The release should not reopen the v0.1.8.7 optimization architecture. The
single-core pure-R fold remains the reference implementation. Parallelism is a
candidate-dispatch layer over the same fold core, not a second engine.

---

## 2. Release Goals

v0.1.8.8 has eleven release goals:

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
9. Compute internal cross-engine parity (per-bar equity, derived top-line
   metrics, trade-level data where available) against the peer rows as a
   building-phase sanity check that ledgr's engine produces the right results
   when given equivalent inputs, with every residual divergence attributed to
   a documented source and the parity track record persisted across releases.
10. Extend the existing `dev/bench/shared/run_benchmarks.R` suite with a
    self-profiling workload grid that varies universe size, history length,
    fill density, and persistence mode, plus post-fold extraction phase
    decomposition; capture a baseline grid record under current source for
    v0.1.9 optimization input. The grid is ledgr-only, not a peer comparison,
    and not a public performance claim.
11. Create the internal maintainer-manual skeleton, retire stale standalone
    documentation surfaces, and audit installed-vignette links without turning
    the package documentation into an internal architecture manual.

The release succeeds when the parallel path is deterministic and the fold core
is substantially easier for maintainers to reason about. If Batch 8 ships in
this release, the benchmark report must be re-runnable from a clean repository
checkout without relying on ambient Python packages, and the parity sanity
check must tell the maintainer honestly whether ledgr's engine matches
established peer engines on equivalent inputs. If Batch 8B ships, the workload
grid must extend the existing benchmark suite without changing the existing
scenarios, and must produce a baseline grid record plus closeout note labeled
as local-host, machine-specific, current-source evidence. The peer/parity
report, the workload grid extension, and the maintainer-manual cleanup are
useful but separable; any may slip by explicit maintainer decision if the
parallel/determinism release becomes too wide.

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

The compiled fold core, when authorized, is assumed to ship as a separate
`ledgrcore` sister package declared as `Suggests` from ledgr. It consumes the
`ledgr_execution_spec_v1` payload (Workstream D / LDG-2472) through the same
internal constructor ledgr uses and emits events through the existing
output-handler interface. The pure-R fold core remains the reference
implementation; the release contract for any `ledgrcore` version is
byte-identical event-stream parity against the fixtures already used for
run-vs-sweep and audit-log-equivalence. The decision to build is gated on
the v0.1.8.9 single-core optimization round and the LDG-2476 LEAN-Python
parity row; this paragraph records the architectural assumption, not
authorization. See the `2026-05-30 [architecture] Compiled fold core as
ledgrcore sister package` entry in `inst/design/horizon.md` for the full
trade-off enumeration.

---

## 7. Workstream E: Repo-Local Peer Benchmark And Parity Report

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

The report is repo-local building-phase artifact only. It must not create a
package-vignette, pkgdown page, or release-note marketing claim in v0.1.8.8.
Surfacing benchmark or parity findings to users is a v0.2.x+ decision with its
own scope.

### 7.4 Cross-Engine Parity Discipline

The benchmark report doubles as an internal cross-engine sanity check that
ledgr's engine produces the right results when given equivalent inputs. The
parity check is for the maintainer, not for outside readers.

Three parity tiers are computed against the ledgr canonical row:

- **Tier 1 (per-bar):** equity-curve correlation, cash trajectory match,
  per-instrument position match, daily-return correlation. This is the
  strongest gate: if Tier 1 holds, Tier 2 follows modulo float order.
- **Tier 2 (derived top-line):** total return, annualized return, volatility,
  Sharpe ratio, max drawdown. Legibility surface for the maintainer; should
  follow from Tier 1.
- **Tier 3 (trade-level):** trade count, per-trade entry/exit timestamps,
  entry/exit prices, PnL, duration, win rate, average trade. Separate parity
  surface that tests fill semantics directly. Computed where the peer emits
  comparable trade data; missing data is labeled, not silently dropped.

Every residual divergence must be attributed to one of six documented sources:

1. Indicator initialization window (TTR vs Backtrader vs LEAN ready-bar).
2. Fill timing edges (last bar, gaps, missing data).
3. Cost/margin defaults (commission models, slippage models).
4. Position-sizing rounding (whole share vs fractional).
5. Timestamp alignment (UTC vs naive, bar open vs close).
6. Float ordering (sum order, cumulation order).

Divergences that do not fit a documented source are flagged as unattributed
and queued for investigation, not silently absorbed.

Three-source attribution rule. When a parity check fails, the default mental
move is to consider three candidates, not to pre-assume ledgr is the bug:

1. ledgr is wrong (real engine bug; investigate).
2. The peer is wrong (known peer edge case; document, move on).
3. The harness is wrong (input mismatch, timestamp alignment, initialization
   window misalignment; most divergences end up here).

The discipline only works if attribution is honest in both directions.

Parity history is persisted as append-only JSON under
`dev/bench/results/parity_history/`, keyed by release tag and workload, so the
parity track record accumulates across releases. One failing parity check must
be walked end to end in each report cycle as the divergence-attribution
template, so the discipline survives by example.

Wall-time rows must be labeled with parity status. No row claims faster wall
time without disclosing whether parity holds.

---

## 8. Workstream F: Internal Maintainer Manual Skeleton

This workstream creates the structure for internal maintainer-facing articles.
It is structural cleanup only: it does not require authoring the full manual in
v0.1.8.8.

The target tree is:

```text
inst/design/manual/
  README.md
  _quarto.yml
  index.qmd
  execution/
  data/
  features/
  sweep/
  observability/
  diagrams/
```

The boundary is important:

- `inst/design/` remains the home for governance artifacts such as contracts,
  roadmap, horizon, ADRs, RFCs, audits, spikes, and spec packets.
- `inst/design/manual/` is the internal maintainer manual: prose and diagrams
  explaining important ledgr concepts and load-bearing implementation paths.
- Package vignettes remain in `vignettes/`; generated installed vignette
  artifacts may appear in `inst/doc/` during package build and must not be
  confused with internal maintainer docs.

Required cleanup:

- move or rename `inst/design/maintainer_review/` to `inst/design/manual/`;
- preserve the current fold-core and feature-value-path workbooks under the
  new manual tree;
- add an index and navigation/conventions README;
- move only current reusable Mermaid diagrams into the manual tree, or inline
  them in relevant QMDs;
- delete or rewrite stale diagrams, including any schema diagram that still
  documents removed `data_hash` execution identity;
- delete `inst/schemas/` unless it gains a real implemented schema artifact;
- audit `man/*.Rd` `system.file("doc", "*.html", package = "ledgr")`
  references against rendered vignette names;
- decide whether `inst/testdata/yahoo_mock.csv` remains an installed fixture
  with an explanatory README or moves to `tests/testthat/fixtures/`.

This ticket should not author every future article. Future article targets
include strategy contract, output handlers, time contract, snapshot spine,
storage schema, indicator contract, replay invariants, determinism gate,
telemetry, parallel dispatch, and benchmark methodology.

---

## 9. Workstream G: Self-Profiling Workload Grid Extension

This workstream is the v0.1.8.8 contribution to the v0.1.9 single-core
optimization round. The LDG-2476 peer benchmark surfaced a per-fill cost
surface that was not visible at the SMA 20/50 density used by the v0.1.8.7
closeout but dominates at the SMA 5/10 density used by the apples-to-apples
parity harness. The workstream extends the existing
`dev/bench/shared/run_benchmarks.R` suite (the v0.1.8.6 Workstream S harness)
with a structured grid that varies universe size, history length, fill
density, and persistence mode so cost-surface scaling is directly visible per
dimension.

This is a self-profiling tool. It is not a peer benchmark, not a public
performance dashboard, and not a competitive ranking artifact. The grid runs
only ledgr.

### 9.1 Bound Scope

The workload grid extension must:

- extend the existing v0.1.8.6 Workstream S suite
  (`dev/bench/shared/run_benchmarks.R`) with named density-by-universe-size
  scenarios, not replace it;
- preserve the existing scenario contracts (`baseline_single_run`,
  `pulse_loop_empty`, `wide_panel_no_features`, `feature_read_score`,
  `feature_turnover`, `indicator_payload`, `sweep_memory_summary`,
  `persistent_replay`, `peer_sma_crossover`, `peer_sma_crossover_sweep`);
- cover both `durable` (`ledgr_run` path) and `ephemeral` (`ledgr_sweep`
  candidates=1 path) variants for every density-by-universe-size cell;
- add post-fold extraction phase decomposition columns to the existing
  benchmark output schema;
- run the new scenarios at `record` preset, write a baseline grid record under
  `dev/bench/results/`, and produce a closeout note ranking cost surfaces.

### 9.2 Grid Cells

Sixteen new named scenarios. SMA windows control fill density; universe size
and history length control scale.

| Scenario | n_inst | n_pulses | SMA windows | Persistence |
| --- | ---: | ---: | --- | --- |
| `density_low_small_durable` | 50 | 252 | 20/50 | durable |
| `density_high_small_durable` | 50 | 252 | 5/10 | durable |
| `density_low_med_durable` | 100 | 1260 | 20/50 | durable |
| `density_high_med_durable` | 100 | 1260 | 5/10 | durable |
| `density_low_wide_durable` | 500 | 1260 | 20/50 | durable |
| `density_high_wide_durable` | 500 | 1260 | 5/10 | durable |
| `density_low_xwide_durable` | 1000 | 1260 | 20/50 | durable |
| `density_high_xwide_durable` | 1000 | 1260 | 5/10 | durable |
| `density_low_small_ephemeral` | 50 | 252 | 20/50 | ephemeral |
| `density_high_small_ephemeral` | 50 | 252 | 5/10 | ephemeral |
| `density_low_med_ephemeral` | 100 | 1260 | 20/50 | ephemeral |
| `density_high_med_ephemeral` | 100 | 1260 | 5/10 | ephemeral |
| `density_low_wide_ephemeral` | 500 | 1260 | 20/50 | ephemeral |
| `density_high_wide_ephemeral` | 500 | 1260 | 5/10 | ephemeral |
| `density_low_xwide_ephemeral` | 1000 | 1260 | 20/50 | ephemeral |
| `density_high_xwide_ephemeral` | 1000 | 1260 | 5/10 | ephemeral |

All cells use the SMA crossover-event strategy from
`bench_sma_crossover_strategy()`, `trade = TRUE`, and the existing
`bench_make_sma_features()` indicator definition. Smoke preset shrinks each
cell to the existing smoke-preset shape ratios.

### 9.3 Phase Decomposition

The existing suite records `snapshot_sec`, `t_pre_sec`, `t_loop_sec`,
`t_residual_sec`, `t_wall_sec`, and `replay_sec`. Add post-fold extraction
columns to the per-row CSV:

- `fills_extract_sec`: wall for `ledgr_results(bt, "fills")`.
- `equity_extract_sec`: wall for `ledgr_results(bt, "equity")`.
- `ledger_extract_sec`: wall for `ledgr_results(bt, "ledger")`.

Add derived per-fill metrics:

- `mus_per_fill_engine = t_loop_sec / fills * 1e6`.
- `mus_per_fill_extract = fills_extract_sec / fills * 1e6`.

These columns must populate for durable cells. Ephemeral cells use the
existing `bench_run_sweep_once()` path, which does not surface per-pulse
telemetry or run a separate `ledgr_results()` extraction; ephemeral cells
record `snapshot_sec` and `t_wall_sec` only, and the missing columns carry
`NA`. The asymmetry must be documented in the closeout note. Exposing
per-candidate telemetry on the ephemeral path is deferred to v0.1.9.

### 9.4 Reproducibility

The grid must use:

- `set.seed(args$seed)` from the existing harness;
- per-iteration seed offsets (`seed + iter`) for replication semantics;
- `OMP_NUM_THREADS = 1`, `OPENBLAS_NUM_THREADS = 1`, `MKL_NUM_THREADS = 1`,
  `NUMEXPR_NUM_THREADS = 1` thread environment;
- the existing installed-package mismatch guard.

The grid runs on current source. Cross-release comparison requires identical
scenario definitions and identical environment metadata; do not edit
shipped scenario shapes mid-release.

### 9.5 Closeout Artifact

The release must include `dev/bench/notes/workload_grid_baseline_closeout.md`
documenting:

- the record file path and environment metadata;
- per-cell phase decomposition;
- per-cell per-fill engine and extraction costs;
- ranking of observed cost surfaces by absolute magnitude and by scaling
  behavior across the grid dimensions;
- the v0.1.9 single-core optimization target stack derived from the ranking;
- explicit caveats: local-host, machine-specific, current-source, not a
  competitive comparison, not a public performance claim.

### 9.6 Non-Goals

The workload grid extension is not:

- a peer benchmark (no Backtrader / quantstrat / zipline / LEAN rows);
- a public performance dashboard or pkgdown article;
- a v0.1.9 optimization implementation (the grid measures; the optimization
  round acts);
- a contract change to `ledgr_run()`, `ledgr_sweep()`, or any public surface;
- authorization for a new public ephemeral entry point. The ephemeral cells
  exercise the existing `ledgr_sweep()` candidates=1 path already used by the
  pre-existing `peer_sma_crossover_sweep` scenario; if a cleaner ephemeral
  entry point is needed, that is a separate v0.1.9 ticket.

The grid is a measurement tool for the v0.1.9 spec inputs, not a deliverable
to outside readers.

---

## 10. Measurement Gates

v0.1.8.8 must preserve the v0.1.8.7 measurement discipline.

Required measurements:

- sequential baseline sweep timing before parallel work;
- parallel sweep timing across candidate counts and worker counts;
- worker setup overhead;
- deterministic equality between sequential and parallel rows;
- current-source intra-loop profile for fold-core documentation;
- peer benchmark report rerun after the benchmark harness is finalized;
- self-profiling workload grid baseline capture under current source if
  Batch 8B ships, recorded under `dev/bench/results/` with per-cell phase
  decomposition and per-fill metrics.

Recommended benchmark dimensions:

- cheap SMA workload;
- feature-heavy workload where sweep amortization can matter;
- small, medium, and record-width shapes;
- explicit fill-density coverage (low vs high turnover) across universe
  sizes, captured by the Workstream G workload grid;
- Windows host first, because Windows-safe behavior is a release goal.

Do not claim parallel speedup from one shape alone. Report startup overhead,
per-candidate slope, and crossover point where parallelism begins to pay.

---

## 11. Verification Gates

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
- peer benchmark report runs or skips optional peers with clear status;
- per-bar equity-curve parity is computed for every required peer with
  attribution for any residual divergence;
- derived top-line metric parity is computed and consistent with per-bar
  parity within float-ordering tolerance;
- trade-level parity is computed for peers that emit comparable trade data,
  or labeled unavailable when not;
- parity history JSON is appended atomically per release tag with no
  destructive rewrites;
- one failing parity check is walked end to end as the divergence-attribution
  template;
- the three-source attribution rule is documented in the report;
- wall-time rows carry parity-status labels and do not claim speed without
  disclosing parity state;
- if Batch 8B ships: the sixteen workload grid scenarios run on the local
  host at smoke and record presets without altering the existing
  v0.1.8.6 Workstream S scenarios;
- if Batch 8B ships: per-row output includes `fills_extract_sec`,
  `equity_extract_sec`, `ledger_extract_sec`, `mus_per_fill_engine`, and
  `mus_per_fill_extract` columns; durable cells populate them; ephemeral
  cells use `NA` where the extraction call is not made;
- if Batch 8B ships: the closeout note ranks observed cost surfaces by
  absolute magnitude and by scaling behavior, derives a v0.1.9 optimization
  target stack, and labels the result as local-host, machine-specific,
  current-source evidence rather than a public performance claim;
- maintainer-manual cleanup leaves package vignettes and `inst/doc/` build
  semantics intact;
- stale diagram/schema/testdata surfaces are deleted, moved, or explicitly
  documented;
- man-page installed-vignette links resolve to current rendered vignette names
  or are corrected.

Full package tests and package check are required before release.

---

## 12. Settled Spec-Cut Decisions

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
| 9 | Self-profiling workload grid | Extend the existing `dev/bench/shared/run_benchmarks.R` suite (sixteen density-by-universe-size cells across durable and ephemeral persistence modes plus post-fold extraction phase decomposition). Ledgr-only, not a peer benchmark. Baseline grid record and closeout note feed the v0.1.9 single-core optimization spec. |

---

## 13. Proposed Batch Shape

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
9. **Batch 8 - Repo-local peer benchmark and parity report.** Add `dev/bench`
   Quarto report and `uv`-managed Backtrader environment; add LEAN
   Python-strategy mode if local setup is tractable.
10. **Batch 8B - Self-profiling workload grid extension.** Extend the existing
    `dev/bench/shared/run_benchmarks.R` suite with the sixteen
    density-by-universe-size grid scenarios plus post-fold extraction phase
    decomposition. Capture a baseline grid record on the local host and write
    the closeout note that ranks observed cost surfaces and derives the v0.1.9
    optimization target stack.
11. **Batch 9 - Maintainer manual skeleton and stale-doc cleanup.** Create
    the internal manual tree, migrate the current workbooks, retire stale
    diagrams/schema placeholders, audit installed-vignette links, and classify
    or move installed test fixtures.
12. **Batch 10 - Release gate.** Full tests, package check, benchmark closeout,
    docs review, and release notes.

If the cycle becomes too wide, keep Batches 0-7 as the core release and move
Batches 8, 8B, and/or 9 to later same-branch documentation tickets by explicit
maintainer decision. Do not drop Batch 1; the fold-core maintainer
documentation is a release goal.

---

## 14. Future Obligations Recorded

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
- full maintainer-manual article authoring beyond the v0.1.8.8 skeleton and
  cleanup pass.
