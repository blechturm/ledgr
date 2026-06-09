# ledgr Roadmap

**Status:** Active roadmap.
**Authority:** Milestone sequence, current planning horizon, and downstream
constraints.
**Latest completed packet:** `inst/design/ledgr_v0_1_9_2_spec_packet/`.
**Active packet:** v0.1.9.3 target-risk packet on branch `v0.1.9.3`.
**Active packet path:** `inst/design/ledgr_v0_1_9_3_spec_packet/`.

This roadmap is a directional planning document. Versioned spec packets are the
authoritative records for completed release work. Architecture notes, RFC
responses, ADRs, and contracts carry detailed design constraints when they are
more precise than this roadmap.

## Vision

ledgr is a deterministic, event-sourced systematic trading research framework
for R.

It is built around:

- sealed market-data snapshots;
- pulse-time strategy decisions with no lookahead access;
- full named numeric targets as the strategy contract;
- registered feature definitions and explicit feature identity;
- append-only execution ledgers;
- derived fills, trades, equity, and metrics;
- experiment-store provenance and strategy recovery;
- reproducibility preflight and trust boundaries.

The v0.1.x arc builds a correctness-first research system. Paper and live
trading remain future work until the research engine, provenance model, and
fold-core architecture are stable.

## Guiding Principles

- **One execution semantics.** `ledgr_run()` and `ledgr_sweep()` must
  share the same internal fold core. Sweep may use a lighter output handler, but
  it must not become a second execution engine.
- **Causality first.** Strategy contexts expose decision-time information only.
  Fill/cost contexts may see execution-bar information after strategy decisions
  have been made.
- **Provenance is necessary, not sufficient.** Provenance records what happened.
  It does not prove that candidate selection was statistically sound.
- **Strict contracts beat silent convenience.** Missing targets, invalid
  feature shapes, hash mismatches, and unsafe strategy tiers should fail loudly.
- **R-native research workflow.** ledgr should feel natural in R and tidyverse-
  adjacent workflows while keeping core execution semantics deterministic.
- **Layer boundaries stay explicit.** Target construction, target risk,
  execution/liquidity policy, cost application, OMS semantics, and broker
  reconciliation are distinct concerns. The target-risk layer must not become a
  catch-all for portfolio construction, cost estimation, liquidity feasibility,
  or order policy.
- **Public API only after internal boundaries are stable.** Risk, sweep, and
  cost-model APIs must not expose internals that will immediately need to be
  rewritten.

## Roadmap Discipline

Roadmap detail is intentionally uneven:

- Completed milestones are one-line records with links to spec packets.
- The active implementation milestone and next planned milestone carry detailed
  scope.
- Later milestones carry intent bullets and downstream constraints only.
- Ticket-level acceptance criteria belong in spec packets, not here.
- Non-binding ideas belong in `inst/design/horizon.md` until promoted.

When a future constraint affects the active design, it must be linked to its
authoritative home: contracts, architecture notes, RFC responses, ADRs, or a
versioned packet.

## Milestone Sequence

| Milestone | Status | Goal | Authoritative record |
| --- | --- | --- | --- |
| v0.0.x | Done | Package foundation and first execution spine. | Historical code and early records |
| v0.1.0 | Done | Deterministic backtest MVP. | `inst/design/ledgr_v0_1_0_spec_packet/` |
| v0.1.1 | Done | Data ingestion and snapshotting. | `inst/design/ledgr_v0_1_1_spec_packet/` |
| v0.1.2 | Done | Snapshot correctness and research UX. | `inst/design/ledgr_v0_1_2_spec_packet/` |
| v0.1.3 | Done | Onboarding release. | `inst/design/ledgr_v0_1_3_spec_packet/` |
| v0.1.4 | Done | Research workflow stabilisation. | `inst/design/ledgr_v0_1_4_spec_packet/` |
| v0.1.5 | Done | Experiment store core. | `inst/design/ledgr_v0_1_5_spec_packet/` |
| v0.1.6 | Done | Experiment comparison and strategy recovery. | `inst/design/ledgr_v0_1_6_spec_packet/` |
| v0.1.7 | Done | Core UX overhaul. | `inst/design/ledgr_v0_1_7_0_spec_packet/` |
| v0.1.7.1 | Done | Installed UX stabilisation. | `inst/design/ledgr_v0_1_7_1_spec_packet/` |
| v0.1.7.2 | Done | Auditr UX and strategy helper layer. | `inst/design/ledgr_v0_1_7_2_spec_packet/` |
| v0.1.7.3 | Done | Accounting correctness and indicator docs. | `inst/design/ledgr_v0_1_7_3_spec_packet/` |
| v0.1.7.4 | Done | External documentation review and auditr report. | `inst/design/ledgr_v0_1_7_4_spec_packet/` |
| v0.1.7.5 | Done | Indicator, diagnostics, and documentation hardening. | `inst/design/ledgr_v0_1_7_5_spec_packet/` |
| v0.1.7.6 | Done | DuckDB persistence architecture review. | `inst/design/ledgr_v0_1_7_6_spec_packet/` |
| v0.1.7.7 | Done | Risk metrics contract. | `inst/design/ledgr_v0_1_7_7_spec_packet/` |
| v0.1.7.8 | Done | Strategy reproducibility preflight. | `inst/design/ledgr_v0_1_7_8_spec_packet/` |
| v0.1.7.9 | Done | Strategy author ergonomics and execution-engine stabilization. | `inst/design/ledgr_v0_1_7_9_spec_packet/` |
| v0.1.8.00 | Done | Design-document governance and v0.1.8 readiness. | `inst/design/ledgr_v0_1_8_00_spec_packet/` |
| v0.1.8 | Done | Lightweight parameter sweep mode and fold-core split. | `inst/design/ledgr_v0_1_8_0_spec_packet/` |
| v0.1.8.1 | Done | Auditr stabilization and multi-output indicator bundle authoring. | `inst/design/ledgr_v0_1_8_1_spec_packet/` |
| v0.1.8.2 | Done | Metric context, risk-free-rate, and indicator codebase Phase 2 cleanup. | `inst/design/ledgr_v0_1_8_2_spec_packet/` |
| v0.1.8.3 | Done | Single-core R-level fold/runtime optimization after metric-kernel semantics settled. | `inst/design/ledgr_v0_1_8_3_spec_packet/` |
| v0.1.8.4 | Done | Active parameterized feature aliases plus separate feature-grid and strategy-grid helpers for sweep authoring. | `inst/design/ledgr_v0_1_8_4_spec_packet/` |
| v0.1.8.5 | Done | Canonical research workflow and teachability release after active aliases and grid UX stabilize. | `inst/design/ledgr_v0_1_8_5_spec_packet/` |
| v0.1.8.6 | Done | Feature-projection materialization, structured benchmarks, DuckDB/storage decision work, performance attribution, and v0.1.8.7 optimization handoff. Snapshot administration and research-loop helpers deferred. | `inst/design/ledgr_v0_1_8_6_spec_packet/` |
| v0.1.8.7 | Done | Optimization round 2 and legacy cleanup: removed raw `bars` execution, R6 strategy execution, and run-time `data_hash` identity from modern execution; dropped cli/R6, added collapse, and shipped measured event-buffer, representation/setup, reconstruction, artifact-policy, and benchmark-attribution work. | `inst/design/ledgr_v0_1_8_7_spec_packet/` |
| v0.1.8.8 | Done | Parallel sweep dispatch and determinism, fold-core diagnostics and containment, repo-local peer benchmark reporting, and self-profiling workload-grid evidence for v0.1.8.9 optimization scoping. Maintainer-manual skeleton cleanup deferred. | `inst/design/ledgr_v0_1_8_8_spec_packet/` |
| v0.1.8.9 | Done | Single-core optimization round: scale-growing buffer write fixes, per-pulse vectorization, yyjsonr canonical JSON byte-format v2 migration, per-lane attribution, and workload-grid / peer-benchmark closeout. | `inst/design/ledgr_v0_1_8_9_spec_packet/` |
| v0.1.8.10 | Done | Ephemeral subphase telemetry, matrix-canonical substrate and strategy accessors, event-preserving fold-owned FIFO accounting, yyjsonr options hoist, B2 compiled spot-FIFO accelerator gate, scoped public memory-backed sweep opt-in, and measurement closeout. | `inst/design/ledgr_v0_1_8_10_spec_packet/` |
| v0.1.8.11 | Done | Documentation, structure, and cleanup release before v0.1.9 features: contract/design-index audit, RFC decision index, user-facing disclaimer and vignette refresh, internal performance-arc narrative, maintainer manual, benchmark methodology article, and `adr/` + `architecture/` + `maintainer_review/` wind-down. | `inst/design/ledgr_v0_1_8_11_spec_packet/` |
| v0.1.9.1 | Done | Public transaction-cost model API, explicit timing-model surface, cost identity (`cost_model_hash`, `cost_plan_json`), and bounded auditr identity/disclaimer fixes. | `inst/design/ledgr_v0_1_9_1_spec_packet/` |
| v0.1.9.2 | Done | Sweep artifact persistence: durable saved-sweep artifacts, optional retained net equity/return series for completed candidates, reopened-sweep candidate compatibility, and compact retention infrastructure for later walk-forward. | `inst/design/ledgr_v0_1_9_2_spec_packet/` |
| v0.1.9.3 | Active | Target-risk: per-pulse restructure plus chainable risk layer, including risk-chain identity for walk-forward. | `inst/design/ledgr_v0_1_9_3_spec_packet/` |
| v0.1.9.4 | Planned | Walk-forward culmination: consumes cost identity from v0.1.9.1, sweep retention infrastructure from v0.1.9.2, and risk-chain identity from v0.1.9.3; Section 17 gates fire here. | Future packet; accepted walk-forward synthesis |
| v0.1.9.x | Planned | Conditional primitive-internals implementation phases after collapse gates. | Future packet |
| v0.1.9.x | Planned | Selection integrity diagnostics after the walk-forward window model stabilizes. | Future packet |
| v0.1.9.x | Planned | Crypto-readiness spike: fractional positions, 24/7 calendar, maker/taker cost shape; measurement and doc-disposition only. | Future packet |
| v0.1.9.x | Planned | Target construction helper extensions over the existing strategy-helper pipeline. | Future packet |
| v0.2.x | Planned | Liquidity and capacity policy separate from cost application. | Future packet |
| v0.2.x | Planned | Point-in-time data tables for external observations and reference data. | Future packet |
| v0.2.x | Planned | Corporate actions and instrument master for serious equity data. | Future packet |
| v0.2.x | Planned | Explicit accounting-critical event types RFC coordinated with corporate actions and instrument master. | Future packet |
| v0.2.x | Planned | Benchmark context and active metrics after benchmark/reference substrate. | Future packet |
| v0.2.x | Planned | OMS semantics, snapshot lineage, and roll-forward data sources. | Future packets |
| v0.2.x | Planned | Reference strategy templates as executable contract demonstrations. | Future packet |
| v0.3.0 | Planned | Paper trading adapter and reconciliation. | Future packet |
| v0.4.0 | Planned | Observability and operations. | Future packet |
| v1.0.0 | Planned | Small-scale live trading. | Future packet |

## Completed Milestone Records

Completed milestones are not expanded here. Their scope, tickets, and
acceptance criteria live in the linked packet directories above.

The durable summary is:

- v0.1.0-v0.1.2 built the deterministic snapshot/run spine and correctness
  invariants.
- v0.1.3-v0.1.4 stabilized onboarding, public workflow, and strategy/pulse
  ergonomics.
- v0.1.5-v0.1.6 added durable experiment storage, comparison, and strategy
  extraction.
- v0.1.7.0-v0.1.7.4 rebuilt the public UX, demo data, strategy helpers,
  indicator surface, and leakage documentation.
- v0.1.7.5-v0.1.7.7 hardened indicators, diagnostics, persistence review, and
  risk metrics.
- v0.1.7.8 added strategy reproducibility preflight and tier semantics.
- v0.1.7.9 stabilized strategy author ergonomics, public documentation, and
  execution-engine accounting before sweep design.

If a completed milestone detail matters for a new change, inspect its packet
directly instead of treating old roadmap prose as current authority.

## Completed Prep: v0.1.8.00

v0.1.8.00 prepared the repository for v0.1.8 implementation. It is a
design-governance cycle, not a runtime feature release.

Authoritative packet:

- `inst/design/ledgr_v0_1_8_00_spec_packet/v0_1_8_00_spec.md`
- `inst/design/ledgr_v0_1_8_00_spec_packet/v0_1_8_00_tickets.md`
- `inst/design/ledgr_v0_1_8_00_spec_packet/tickets.yml`

Scope:

- index `inst/design/` through `inst/design/README.md`;
- move architecture notes, RFCs, audits, and spikes into role-based
  subdirectories;
- keep completed spec packets in place as historical records;
- shorten this roadmap;
- maintain `inst/design/horizon.md` as a non-binding idea parking lot;
- update `AGENTS.md` and release-gate playbooks so agent context stays current;
- verify pkgdown article discoverability and LLM-oriented site artefacts;
- run the parallelism spikes needed before v0.1.8 spec cut.

Non-goals:

- no package runtime changes;
- no exported API changes;
- no runner, snapshot, fill, or accounting behavior changes;
- no package version metadata changes.

## Completed Milestone: v0.1.8 Lightweight Sweep Mode

This section records the completed v0.1.8 sweep design. It retains the original
requirement language because those constraints remain useful background for
patch work, but it is no longer the active implementation milestone. Active
v0.1.8.x patch scope is defined in the sections below and in the relevant spec
packet.

v0.1.8 introduces the internal architecture needed for parameter sweeps without
duplicating execution semantics.

Primary architecture inputs:

- `inst/design/manual/sweep.qmd`
- `inst/design/manual/sweep.qmd`
- `inst/design/manual/sweep.qmd`
- `inst/design/spikes/ledgr_parallelism_spike/README.md`
- `inst/design/contracts.md`

### v0.1.8 Thesis

Sweep is an evaluation primitive over the same fold core as `ledgr_run()`:

```text
candidate + data slice + output policy -> candidate result
```

It is not:

```text
for each params row, call a separate execution engine
```

The long-term stack is:

```text
fold core
  -> ledgr_run()
  -> ledgr_sweep()
  -> ledgr_walk_forward()
  -> PBO/CSCV diagnostics
```

v0.1.8 may be sequential and modest. It must still preserve the internal
boundaries that make parallel sweep, walk-forward analysis, and selection-bias
diagnostics possible later.

### Required Internal Boundaries

v0.1.8 must define or reserve these internal boundaries:

- private shared fold core, tentatively named `ledgr_run_fold()`;
- output handler that separates execution semantics from persistence;
- pre-fold strategy preflight result passed into output handling;
- parameter-grid candidate identity;
- summary-only sweep result shape with enough identity to promote a candidate
  through `ledgr_candidate()` / `ledgr_promote()`;
- row-level `execution_seed` and compact row-level `provenance` so filtered,
  sorted, sliced, or saved candidate rows remain promotion-ready;
- durable `run_promotion_context` selection-audit metadata for runs promoted
  from sweep candidates;
- precomputed-feature object validated against snapshot hash and feature
  fingerprints;
- fill timing and cost resolution as separable internal steps.

The fold core owns deterministic execution:

- pulse calendar order;
- pulse context construction;
- registered feature lookup;
- strategy invocation;
- target validation;
- reserved future target-risk step, a no-op in v0.1.8;
- fill timing;
- cost resolution;
- final-bar no-fill behavior;
- cash, position, and state transitions;
- event-stream meaning.

Output handlers decide what to keep:

- full DuckDB ledger and provenance for `ledgr_run()`;
- in-memory candidate summaries for sweep;
- promotion context for committed runs created through `ledgr_promote()`;
- failure records and warnings;
- future worker-local or selected-candidate outputs.

### Parity Contract

For deterministic strategies, `ledgr_run()` and `ledgr_sweep()` must agree on:

- target validation;
- feature values;
- pulse order;
- fill timing;
- fill prices, fees, and cash deltas;
- final positions and cash;
- equity curve and metrics where retained;
- long-only and final-bar behavior;
- preflight tier;
- random draw semantics when a seed is used;
- `config_hash` for unchanged scalar execution config.

Exact numeric parity is required on the same platform/R version for
deterministic strategies. Cross-platform floating-point behavior can be handled
separately if it becomes relevant.

### Sweep UX Commitments

v0.1.8 sweep should support:

- typed parameter grids;
- candidate result tables;
- row-level execution seed and compact provenance fields;
- candidate status and failure capture;
- caller-owned ranking through ordinary R/dplyr workflows;
- candidate extraction and promotion through `ledgr_candidate()` and
  `ledgr_promote()` rather than manual `params[[1]]` extraction;
- durable promotion context that records the selected candidate and the
  filtered/sorted selection view that led to a committed run;
- optional precomputed features;
- manual train/sweep/evaluate discipline in the docs.

Sweep must not pretend provenance solves selection bias. Documentation should
state the orthogonality clearly:

```text
Reproducibility and selection integrity are orthogonal. Provenance records what
happened. It does not prove that the candidate-selection process was sound.
```

Manual discipline for v0.1.8:

```text
train snapshot -> sweep candidates -> lock params -> evaluate on held-out test snapshot
```

`ledgr_snapshot_split()`, walk-forward analysis, and PBO/CSCV diagnostics are
deferred until sweep itself exists.

### Feature And Warmup Constraints

Precomputed features must validate:

- snapshot identity;
- feature identities/fingerprints;
- parameter-grid coverage;
- scoring range coverage;
- warmup lookback coverage.

For slice-aware evaluation, scoring range and warmup lookback range are
different intervals. For example, a fold scored from 2017-01-01 may need
pre-2017 bars to warm `sma_10`. v0.1.8 should not make architectural choices
that prevent slice-aware bar counts later.

The feature cache is already structurally close to slice-aware evaluation
because its key includes snapshot hash, instrument, indicator fingerprint,
engine version, start timestamp, and end timestamp.

### Parallelism Constraints

Parallel execution is not required for the first sweep release unless the
v0.1.8 spec explicitly adds it. The implementation must still avoid blocking
future parallelism.

Known constraints:

- global telemetry/preflight side channels must not leak across candidates or
  workers;
- DuckDB writes must stay outside the fold core;
- worker output must be isolated if parallel writes are introduced;
- mirai is a viable optional backend and should remain `Suggests` at most;
- parallel candidate dispatch should preload feature payloads or lookup state
  once during worker setup, not serialize large payloads with every candidate;
- `mori` is boundary-compatible but is a future transport/memory-pressure tool,
  not the default hot feature-lookup representation;
- worker-local read-only DuckDB access is viable for sealed snapshots in the
  spike and should remain a reserved future transport;
- parallel Tier 2 code needs explicit worker package/setup semantics before
  candidate dispatch;
- parallel sweep requires per-candidate seed derivation from explicit inputs so
  results do not depend on daemon assignment or global worker RNG state;
- v0.1.8 seed work should accept explicit execution seeds, move seeding to the
  fold-core boundary, and derive sweep candidate seeds in the dispatcher;
- v0.1.8 should use discard-all interrupt semantics for sweeps rather than
  partial result objects.

The parallelism spike findings are recorded in
`inst/design/spikes/ledgr_parallelism_spike/README.md`, with the architecture
synthesis in
`inst/design/spikes/ledgr_parallelism_spike/architecture_synthesis.md`.

### Internal Cost Boundary

v0.1.8 should reserve a private timing/cost boundary but must not expose public
cost-model factories.

Internal chain:

```text
validated_targets
  -> future risk step, no-op in v0.1.8
  -> next_open_timing()
  -> ledgr_fill_proposal
  -> cost resolver
  -> ledgr_fill_intent
  -> fold event
```

Hard constraints:

- strategy `ctx` remains decision-time only;
- cost resolution uses a separate fill/execution context;
- execution context may carry next-bar OHLCV for future cost models;
- v0.1.8 must reserve the future risk insertion point between target
  validation and fill timing rather than treating validated targets and fill
  timing as one indivisible step;
- quantity mutation is out of scope for the first cost contract;
- output handlers must not compute or reinterpret costs;
- existing `spread_bps` and `commission_fixed` behavior, including
  `config_hash`, must remain byte-identical after internal refactor.

Authoritative cost architecture response:

- `inst/design/rfc/rfc_cost_model_architecture_response.md`

### v0.1.8 Non-Goals

v0.1.8 should not include:

- exported cost-model factories;
- exchange/broker fee templates;
- market-impact models;
- liquidity clipping or quantity mutation;
- separate sweep execution grid;
- public risk-layer API;
- walk-forward analysis;
- PBO/CSCV diagnostics;
- full sweep artifact save/load/replay helpers;
- mandatory `ledgr_snapshot_split()`;
- paper/live adapter behavior.

## v0.1.8.x Patch Horizon

The following milestones are intentionally brief. They are here only to keep
downstream constraints visible while v0.1.8.x patch releases are scoped.

### v0.1.8.1 Auditr Stabilization And Indicator Bundle UX

Authoritative inputs:

- `inst/design/ledgr_v0_1_8_1_spec_packet/v0_1_8_1_spec.md`;
- `inst/design/rfc/rfc_multi_output_indicator_ux_synthesis.md`.

Intent:

- route v0.1.8 auditr findings into documentation, example, diagnostic, and
  small runtime-polish tickets without reopening sweep execution design;
- add the accepted multi-output indicator authoring bundle UX as a narrow
  authoring-layer improvement;
- preserve the existing single-output feature contract, feature fingerprints,
  sweep provenance, and fold-core execution semantics.

Non-scope:

- no metric context or risk-free-rate storage model;
- no single-core sweep performance optimization;
- no walk-forward API;
- no public parallel sweep feature;
- no target-risk layer.

### v0.1.8.2 Metric Context And Indicator Codebase Phase 2 Cleanup

Authoritative inputs:

- `inst/design/rfc/rfc_risk_free_rate_metric_context_v0_1_8_1_synthesis.md`;
- `inst/design/rfc/rfc_indicator_codebase_simplification_v0_1_8_x_synthesis.md`.

Intent:

- add experiment-level metric context as analysis metadata, not execution
  identity;
- provide market templates such as US equity and crypto metric contexts;
- store a run's resolved metric context as run metadata;
- thread one metric context through `summary()`, `ledgr_compute_metrics()`,
  `ledgr_compare_runs()`, `ledgr_sweep()`, and promotion context;
- replace hidden risk-free-rate and annualization assumptions with disclosed,
  inspectable context;
- complete Phase 2 of the indicator codebase simplification: rename
  `R/indicators_builtin.R` to `R/indicator-builtins.R` and
  `R/indicator_adapters.R` to `R/indicator-adapters.R`, and split
  `R/indicator_dev.R` into `R/indicator-dev.R` plus `R/pulse-snapshot.R`.

Constraints:

- metric context must not enter execution config hash, strategy hash, snapshot
  hash, feature-set hash, seed derivation, fills, or event ordering;
- `metric_kernel` must be a plain serializable value object so later sweep
  optimization and parallel dispatch can consume it safely;
- intraday calendar inference remains a compatibility fallback, but explicit
  calendars/templates are the teaching path;
- Phase 2 file moves must preserve all public APIs, feature IDs, fingerprints,
  exports, error classes, and roxygen prose; file-reference fields in
  `man/*.Rd` may change as expected;
- Phase 2 may only run after Phase 1 (LDG-2212) has shipped and completed at
  least one CI cycle.

### v0.1.8.3 Single-Core Sweep Optimization

Authoritative input:

- `inst/design/rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md`.
- `inst/design/rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`.
- `inst/design/ledgr_v0_1_8_3_spec_packet/v0_1_8_3_spec.md`.
- `inst/design/ledgr_v0_1_8_3_spec_packet/v0_1_8_3_tickets.md`.

Intent:

- optimize no-DB sweep execution after metric-kernel semantics are stable;
- introduce a runtime projection interface with an R-memory backend;
- make `ledgr_run()` and `ledgr_sweep()` consume the same projection through
  the shared fold core;
- introduce typed memory events and single-pass summary reconstruction if
  parity design closes cleanly;
- reduce fold-core context churn with fast context B1/B2 where parity permits,
  without changing strategy-facing context semantics;
- keep `ledgr_run()` and `ledgr_sweep()` on one execution core.
- route the v0.1.8.2 auditr findings that fit this performance release,
  especially preflight indirection hardening and docs/message polish.

Precondition:

- persistent-path and memory-path realized/unrealized PnL semantics must be
  resolved before implementation begins.

Constraints:

- no active alias lookup, alias-map identity, or parameter-grid helper surface;
- no DuckDB-backed precompute storage or out-of-core projection in this cycle;
- no DuckDB-implemented indicator computation;
- if fast context B2 cannot preserve parity, ship B1 only and defer B2 with
  measurement evidence.

### v0.1.8.4 Active Parameterized Feature Aliases And Grid Helpers

Authoritative input:

- `inst/design/ledgr_v0_1_8_4_spec_packet/v0_1_8_4_spec.md`.
- `inst/design/rfc/rfc_active_parameterized_feature_aliases_v0_1_8_x_synthesis.md`.

Intent:

- add first-class parameterized feature aliases for sweep authoring;
- support `ledgr_param("name")` scalar references in the first-pass
  package-owned indicator constructors;
- let strategies read active feature aliases with `ctx$features(id)` without
  calling external feature factories from strategy code;
- preserve concrete feature IDs and fingerprints by resolving declarations to
  ordinary indicators before precompute, sweep, or run execution;
- inherit the v0.1.8.3 grid-level concrete-feature-union decision so shared
  concrete features are computed once across a sweep grid, not once per
  candidate;
- store resolved alias maps in execution identity and provenance;
- pull parameter-grid construction helpers into this release so users can build
  larger parameterized sweeps without hand-writing named `ledgr_param_grid()`
  entries, while keeping feature parameters and strategy parameters in separate
  public namespaces.

Constraints:

- direct scalar substitution only; no expression language, tidy-eval,
  conditional feature-family declarations, or AST-derived feature inference;
- no nested bundle namespaces in the first pass; preserve current flat bundle
  aliases;
- no automatic candidate ranking, winner selection, or tuning objective;
- grid helpers create candidate parameter sets only, even when they support
  `.filter` for structural grid constraints;
- keep exact-ID lookup and explicit-map `ctx$features(id, map)` behavior
  unchanged;
- coordinate pulse-context additions with the accepted v0.1.9 target-risk
  chain design.

### v0.1.8.5 Canonical Research Workflow And Teachability

Authoritative input:

- `inst/design/rfc/rfc_research_workflow_artifact_topology_v0_1_8_x_synthesis.md`.

Intent:

- teach the reproducible research workflow as ledgr's default user path:
  seal data, declare features and strategy, sweep deliberately, inspect
  evidence, promote explicitly, and reopen from durable artifacts;
- standardize v0.1.x documentation around one project-local experiment store,
  normally `artifacts/ledgr_store.duckdb`;
- distinguish sealed snapshots from derived execution artifacts while keeping
  physical split stores out of the public workflow until first-class APIs
  exist;
- align Getting Started, Experiment Store, Sweeps, Reproducibility, and any
  workflow article with the active-alias and grid-helper UX from v0.1.8.4;
- document backup guidance, schema-version caveats, and the rule that ignored
  artifacts are not disposable;
- route auditr findings against the canonical workflow path.

Scope:

- documentation and workflow alignment first;
- a dedicated research-workflow article or vignette;
- no project scaffold helper unless a future spec packet explicitly scopes it;
- no split-store runtime, snapshot lineage API, live data log, production
  promotion record, point-in-time regressor API, pins/vetiver integration, or
  companion example repository implementation.

Constraints:

- `ledgr_promote(..., note = ...)` remains research promotion evidence, not a
  production deployment approval record;
- new historical data creates new sealed snapshots rather than mutating old
  snapshots;
- live production ticks and bars belong to future append-only data logs, not
  sealed backtest snapshots;
- parallel dispatch must later coordinate durable writes rather than imply
  unsynchronized worker writes to one DuckDB store.

### v0.1.8.6 Feature Projection Materialization, Storage Spike, Benchmarks, And Optimization Handoff

v0.1.8.6 hosts coordinated materialization, benchmark, storage-decision, and
performance-attribution workstreams. Snapshot administration and research-loop
helper planning were considered in the packet, but deferred to the horizon by
maintainer decision during closeout.

Sequencing:

- Feature-projection materialization is first. The accepted
  `rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md` binds
  Direction 5.0 (feature cache-key deduplication) before Direction 5.1
  (schema-only `feature_table` by default), followed by current-source
  remeasurement and an instrument x feature width sweep.
- The structured benchmark suite is a separate local engineering workstream.
  It gives the storage decision stable named scenarios, current-source guards,
  machine-readable output, and a small QuantConnect-comparable subset without
  becoming a hosted performance dashboard.
- Snapshot administration, ETL provenance metadata, and research-loop
  ergonomics helpers are deferred out of v0.1.8.6. The horizon entry is the
  seed-shape input for a later RFC/spec cycle, likely v0.2.0-class work where
  it can align with snapshot lineage and point-in-time data surfaces.
- The DuckDB feature-storage spike remains a measurement-and-decision
  packet. It should run after 5.0/5.1 remeasurement so it measures the
  remaining bottleneck rather than stale setup costs.
- Auditr-report bugfix intake is deferred to the next version. The maintainer
  will first fix overly explicit prompts in the auditr repository, then rerun
  the report in the next cycle.

#### Workstream 0: Feature Projection Materialization

Intent:

- remove redundant feature fingerprint and engine-version work from the
  per-(instrument, feature) precompute path without changing cache-key values;
- stop building the full-panel long `feature_table` by default while preserving
  a schema-only field, explicit internal full-long opt-in, and single-pulse
  inspection support;
- keep `ctx$features_wide` and projection-backed scalar/vector accessors as the
  canonical decision-time surfaces;
- remeasure after each change using current source, then add an instrument x
  feature width sweep before making storage claims.

Constraints:

- no active-binding or function-valued replacement for `ctx$feature_table`;
- no public deprecation of `ctx$feature_table` in this cycle;
- no collapse import for the materialization fix;
- no claim that loop throughput is width-invariant until the width sweep
  measures it.

#### Workstream S: Structured Benchmark Suite

Intent:

- turn the feature-payload spike into repeatable named benchmark scenarios with
  current-source guards, explicit warmup/repeat behavior, phase metrics,
  environment metadata, and machine-readable output;
- include a small QuantConnect/LEAN-comparable subset where ledgr has honest
  scenario analogues, reported side by side rather than as parity or
  speed-ranking claims;
- keep ledgr-only scenarios such as cross-sectional feature read/score
  measured without pretending they have a direct published LEAN analogue;
- provide the measurement substrate for the two-mode instrument x feature width
  sweep and the DuckDB/storage decision.

Constraints:

- no public hosted benchmark dashboard in this cycle;
- no hard CI performance-regression threshold in this cycle;
- no LEAN equivalence, parity, or "beats LEAN" language;
- no scheduler, universe-selection, or history/window benchmark until ledgr has
  matching public surfaces.

#### Deferred Workstream A: Snapshot Administration And ETL Provenance

Deferred out of v0.1.8.6 by maintainer decision. The notes below preserve the
shape of the future RFC input; they do not authorize implementation in this
cycle.

Intent:

- close the v0.1.8.5 USP-defensibility gap by giving users a first-class
  surface to record ETL provenance, free-text notes, labels, and authorship
  at snapshot creation;
- expose listing and filtering APIs so a research project store with many
  snapshots is navigable without ID memorization;
- separate engine-computed metadata, user-supplied descriptive metadata,
  and administrative lifecycle state in both schema and public API;
- define ledgr's data-provenance model as the substrate that future v0.2.x
  point-in-time, corporate-actions, and snapshot-lineage work will extend.

Authoritative input (future):

- RFC cycle on snapshot administration and provenance metadata, to be cut
  before implementation tickets are cut for that workstream;
- `inst/design/horizon.md` snapshot-administration entry as the seed-shape
  input.

Constraints:

- `snapshot_hash` must not depend on mutable user metadata;
- ETL provenance recorded at create/seal time is append-only thereafter;
  administrative edits go through an audit-logged path if the RFC promotes
  one;
- listing surface filters by snapshot-level fields only; it does not
  become a bar-data query engine;
- migration path or explicit pre-CRAN "rerun your experiments" gate must
  ship with any schema change;
- ledgr stores user metadata faithfully but does not interpret it as
  execution identity, feature identity, or selection input;
- the three-category separation (engine-computed / user-supplied /
  lifecycle) is the load-bearing design constraint and must be preserved
  in both schema and API.

Non-scope:

- no production deployment registry;
- no external data-catalog integration;
- no schema migration tooling for non-ledgr stores;
- no automatic ETL inference from data sources.

#### Workstream B: DuckDB Feature Storage Spike

Intent:

- measure whether DuckDB-backed feature storage or out-of-core projection is
  actually needed after the v0.1.8.3 R-memory runtime projection and v0.1.8.4
  active-alias/grid UX have stabilized;
- compare the current R-memory projection path against a prototype
  DuckDB-backed, block-hydrated projection path on representative workloads;
- decide whether to implement, defer, or reject a durable feature-library
  storage surface before v0.1.8.8 parallel dispatch;
- preserve the R `series_fn()` / TTR / custom-indicator extension surface in
  every prototype;
- keep DBI access at block boundaries, never per pulse.

This workstream is a measurement and decision packet first. It must not
automatically become a storage implementation release. A DuckDB-backed
projection or feature library should ship only if the spike shows a clear
bottleneck that the current R-memory projection path cannot handle with
smaller changes.

Required spike comparisons:

- small EOD workflows where the current in-memory path should remain the
  reference baseline;
- wider EOD feature grids with active aliases and shared concrete-feature
  unions;
- repeated candidate families where feature precompute reuse could matter;
- larger-universe or intraday-like synthetic stress cases to expose memory,
  hydration, and file-size ceilings without claiming intraday support;
- optional worker-read or worker-transport probes if they directly inform the
  v0.1.8.8 parallel-dispatch decision.

Measurement outputs:

- wall-clock runtime by phase: feature materialization, projection hydration,
  fold execution, and summary reconstruction;
- peak R memory and serialized payload size;
- DuckDB file size, query/hydration time, and block size sensitivity;
- per-candidate setup cost and any shared-library reuse benefit;
- evidence about whether the bottleneck is storage, transport, fold execution,
  or post-candidate reconstruction.

Readiness gates:

- v0.1.8.3 runtime projection interface and R-memory backend have landed;
- v0.1.8.4 active aliases have fixed alias-map identity and grid-level
  concrete-feature-union semantics;
- v0.1.8.5 workflow spec has clarified which artifact topology remains
  documentation-only and which storage surfaces require first-class APIs;
- post-v0.1.8.3 residual evidence shows memory scaling, repeated precompute,
  ML/export, or parallel-worker sharing is the next bottleneck.

Constraints:

- no per-pulse DBI traffic;
- no DuckDB-implemented indicator computation without a separate RFC;
- no second feature engine;
- no public storage API, schema, or migration promise unless the spike is
  promoted by the spec and release decision;
- no public ML/export API unless explicitly promoted through a spec packet.

Exit decisions:

- **Implement:** only if evidence shows a material bottleneck and a
  block-hydrated DuckDB path beats or complements the R-memory path without
  weakening determinism, portability, or feature identity.
- **Defer:** if DuckDB-backed storage is plausible but not yet load-bearing.
- **Reject for now:** if the bottleneck remains fold execution,
  pulse-context churn, or summary reconstruction rather than feature storage.

#### Deferred Workstream C: Research-Loop Ergonomics Helpers

Deferred out of v0.1.8.6 by maintainer decision. The notes below preserve the
shape of the future RFC input; they do not authorize implementation in this
cycle.

Intent:

- ship the two API gaps that the v0.1.8.5 canonical workflow article had to
  flag with user-visible "Design note" and "API gap" callouts because the
  underlying surfaces existed only at the lower level;
- add a sweep-review helper that ranks completed candidates by an explicit
  rule, returns a compact review table, separates issue rows, and keeps the
  ranking rule visible at the call site;
- add a promotion-recovery-summary helper that returns one compact object
  describing a promoted run's "what caused this result?" record without
  asking users to navigate nested `promotion_context` fields or to call
  `ledgr_extract_strategy()` separately;
- revise the workflow article's "Design note" and "API gap" callouts to
  reference the new helpers, or remove them if the helpers make the
  lower-level paths unnecessary in the teaching arc.

Authoritative input (future):

- the same snapshot administration RFC that drives Workstream A, since the
  promotion-recovery summary couples directly to the snapshot/run metadata
  model;
- `inst/design/horizon.md` research-loop ergonomics entry as the seed-shape
  input.

Constraints:

- helpers do not replace `ledgr_results()`, `ledgr_run_info()`,
  `ledgr_extract_strategy()`, `ledgr_candidate()`, or the underlying
  promotion-context fields; they are summary surfaces over those APIs,
  not parallel ones;
- the sweep-review helper must require an explicit rank-by argument or
  return the chosen rule alongside the rows; no silent default metric;
- the recovery summary must distinguish stored facts (parameters, hashes,
  note) from interpretation (reproducibility tier, hash-verification
  status, recovery limitations); Tier 1 and Tier 2 strategies must not
  collapse into a single "verified" status;
- output is inspectable as a plain data frame or named list, never an
  opaque print-only object;
- the lower-level paths remain in the public API.

Non-scope:

- no automatic candidate selection or winner-picking helper;
- no statistical-validation surface;
- no walk-forward or out-of-sample evaluation helper;
- no benchmark-relative or attribution helper.

### v0.1.8.7 Optimization Round: Fold-Core Primitive Contract And Artifact Materialization Policy

v0.1.8.7 completed the RFC-first Optimization Round 2 and legacy cleanup. The
accepted direction is that fold-core internals should prefer primitive R objects
and functions (atomic vectors, matrices, lists, index maps, closures), while
data.frames are manifested only at public or strategy-facing boundaries when
explicitly needed.

The same cycle also settled run-artifact materialization policy. The
v0.1.8.6 profiling showed that persistent feature-panel writes can dominate
wall time when `persist_features = TRUE`, while sweep candidates already avoid
that path. v0.1.8.7 formalized the intended fast/slow split: evaluation
paths keep heavy feature artifacts ephemeral and save compact results, while
promotion/inspection paths explicitly materialize durable views and pay that
tax.

This is the project's second optimization round (after the v0.1.8.6 measurement
round) and pulls the ADR 0004 dependency/hot-path decisions into scope: drop
`cli` (unused) and `R6` (legacy strategy interface), add `collapse` (pure C,
zero transitive deps), keep `tibble` (tidyverse signal). The optimization
content is the three lanes from
`inst/design/audits/fold_path_hotpath_audit.md`, prioritized by the LDG-2457
real-run profile (the per-event buffer/append path is ~72-82% of loop R time):

- **Lane B - event emission/buffering (the big rock):** make the per-event
  buffer write in-place (base-R env-bound columns + realistic sizing, or
  `collapse::setv`); carry whole-second `POSIXct` end to end (no per-fill
  format/parse round trip); batch `meta_json` per row at flush; cheap event ids.
  Fixes both `handler$buffer_event` (durable) and `append_event_row_list` (sweep).
- **Lane A - cache-key/setup:** hoist run-level timestamp normalization out of
  the per-key loop; replace JSON+SHA session keys with a length-prefixed
  composite key.
- **Lane C - read-back reconstruction:** preallocated-column rewrite of
  `ledgr_fills_from_events`; `.subset2`/`get_vars` reads.

`collapse` adoption is gated on the `ledgr_with_collapse_deterministic()` wrapper
(scoped `set_collapse()`, hostile-settings-safe; see ADR 0004). Every win is
validated by **re-profiling the real run** and re-running the LDG-2457 peer
benchmark, not isolated micro-benchmarks.

Maintainer decision (2026-05-29): v0.1.8.7 also removes the legacy execution
gunk that keeps old representations load-bearing. Modern execution is
snapshot-backed and function-strategy based. Raw mutable `bars` configs and R6
strategy paths must fail clearly before entering the fold, and run-time
`data_hash` is no longer modern sealed-run identity. `ledgr_data_hash()`,
`runs.data_hash`, and snapshot-adapter `data_hash` metadata are deleted by the
spec packet; old-store migration may tolerate historical columns only long
enough to rewrite them out.

Authoritative input:

- Maintainer-manual article:
  `inst/design/manual/snapshots_data.qmd`. It records the migrated sealed-data
  trust boundary, the current committed-run versus sweep guard asymmetry, and
  the session-cache-key stance that durable provenance formats must not leak
  into hot lookup paths.
- RFC cycle on primitive fold-core contract redesign, using the v0.1.8.6
  benchmark suite, width sweep, LDG-2453 wide-view manifestation work, and
  LDG-2454 cold setup/residual profiling as empirical input. Implementation
  tickets are cut in the same packet after the RFC is accepted.
- RFC cycle on **Run Artifact Materialization Policy**. Seed question:
  `persist_features` and other heavy derived views should not be default fast
  path side effects; they should be explicit slow-path materializations backed
  by enough stored reproducibility identity to regenerate them.

Intent:

- map every data.frame currently crossing the fold-core boundary, including
  bars, `features_wide`, `feature_table`, event buffers, and inspection/export
  surfaces;
- decide which strategy-facing surfaces should become primitive-native
  surfaces, which should remain data.frame conveniences, and which should be
  explicit helper manifestations;
- define the cheapest allowed data.frame boundary manifestation pattern,
  including compact-row-name list stamping where it preserves behavior;
- preserve one execution semantics for `ledgr_run()` and `ledgr_sweep()` before
  parallel worker boundaries multiply the cost of carrying heavy objects;
- define fast/evaluation and slow/committed artifact policies:
  sweeps and exploratory evaluation persist compact summaries and reproduction
  keys, while promoted/committed runs can materialize feature panels, pulse
  inspection views, and other heavy derived artifacts explicitly;
- specify the minimal durable reproduction key needed for later
  materialization: snapshot hash, strategy identity, strategy params, feature
  definitions/fingerprints, feature params, feature-engine version, seed, config
  identity, metric context, and later risk-chain identity;
- implement the accepted contract in the same version, after the RFC binds the
  strategy-context contract and parity gates.

Readiness gates:

- v0.1.8.6 closes with post-materialization benchmark outputs and the cold
  setup/residual profiling note recorded;
- the RFC distinguishes narrow parity-preserving manifestation optimizations
  from public strategy-context contract changes;
- strategy UX explicitly chooses between primitive helpers, data.frame helper
  functions, and any retained compatibility fields;
- artifact policy explicitly chooses default `persist_features` semantics and
  any materialize-on-demand helper surface;
- fold-entry guard policy explicitly chooses whether sweep continues to trust a
  sealed snapshot handle or converges with committed-run hash recomputation;
- event-stream parity, snapshot identity, no-lookahead, and mutation-leak tests
  are named as gates for any implementation ticket.

Implementation constraints:

- implementation follows the accepted RFC; no ad hoc contract change lands
  before the RFC synthesis is accepted;
- the sequential fold remains the reference execution path and must retain
  event-stream parity against the pre-redesign behavior on reference workloads;
- data.frame helper manifestations are explicit boundary utilities or retained
  compatibility surfaces named by the RFC, not implicit fold-core payloads;
- sealed snapshot validation and timestamp normalization are run/setup-boundary
  duties, not repeated per-cell or per-pulse fold-core work;
- ephemeral/evaluation results and promoted/materialized committed results must
  have a parity gate: the regenerated committed result must match the original
  candidate/run result byte-for-byte or within existing accounting tolerances
  where those tolerances already apply;
- the `t_pre` cache-key construction cost remains a separate performance lane;
  artifact materialization policy removes default persistence tax but does not
  claim to solve feature cache-key/setup costs;
- benchmark/profiling deltas are recorded after implementation so the
  parallel-dispatch decision starts from the redesigned fold-core cost model.

Non-scope:

- no parallel sweep dispatch;
- no target-risk implementation;
- `collapse` is adopted for the hot-path lanes per ADR 0004 (gated on the
  `ledgr_with_collapse_deterministic()` wrapper); broad/idiomatic `collapse` use
  beyond those lanes stays out of scope;
- no DuckDB projection/storage rewrite;
- no active-binding or function-valued data-field mechanism unless the RFC
  explicitly accepts it.

### v0.1.8.8 Parallel Sweep Dispatch

Intent:

- add optional parallel candidate dispatch only after the single-core sweep path
  remains the reference implementation and R-level optimization has been
  resolved;
- preserve deterministic result row order, warning/error association, and seed
  derivation regardless of worker completion order;
- keep worker execution isolated from persistent stores and shared mutable
  process state;
- prefer Windows-safe worker assumptions, including PSOCK-style serialization.

Readiness gates:

- `ledgr_sweep()` candidate execution is fully isolated and no-DB;
- `metric_kernel` and candidate payloads are plain serializable value objects;
- single-core performance measurements show remaining candidate work is
  CPU-bound enough to justify parallel overhead;
- v0.1.8.3 R-level optimization and any v0.1.8.6 storage/projection decision
  are resolved;
- v0.1.8.7 primitive fold-core contract redesign is accepted and any
  contract-preserving implementation work needed before worker serialization
  is complete or explicitly deferred;
- grid UX has stabilized enough that larger sweeps are an intentional public
  workflow rather than accidental friction;
- the v0.1.8.5 canonical workflow constraints are reflected in the write
  strategy: no unsynchronized concurrent writes to one DuckDB store;
- interrupt, progress, warning ordering, failure ordering, package state, and
  worker setup semantics are explicitly specified before implementation.

Non-scope:

- no change to the sequential sweep contract;
- no weakening of seed, warning, failure-row, or promotion provenance
  guarantees to fit worker scheduling;
- no public distributed execution API.

Related determinism gap (from the 2026-05-28 fold-core review):

- The same RNG-state question affects run *resume*: on resume the loop
  re-seeds and jumps to `start_idx` without restoring `.Random.seed`, so a
  stochastic strategy diverges from a continuous run (state is correctly
  replayed from events; the RNG stream is not). Whatever this cycle decides
  about per-candidate seed derivation should also settle resume RNG handling —
  checkpoint `.Random.seed`, replay-from-start, or document a
  deterministic-only resume guarantee. See `inst/design/horizon.md` (RNG resume
  entry).

### v0.1.9.x Follow-On Documentation After v0.1.8.11

Intent:

- hold only bounded documentation remainder after v0.1.8.11, if review or
  ticket execution leaves a deliberately deferred article family;
- keep any follow-on documentation separate from v0.1.9 target-risk
  implementation and other v0.1.9.x feature packets;
- avoid reopening governance-record synthesis if v0.1.8.11 has already made
  the load-bearing decisions discoverable.

Target article families:

- **Execution:** fold core, pulse lifecycle, strategy contract, output
  handlers, execution spec, RNG/determinism, and whole-second time contract;
- **Data:** snapshot spine, storage schema, and snapshot adapters;
- **Features:** feature value path, cache/projection, indicator contract, and
  `series_fn` / TTR adapter semantics;
- **Sweep:** sweep architecture, promotion/reproduction, and parallel dispatch;
- **Observability:** error hierarchy, telemetry, replay invariants, collapse
  determinism gate, and benchmark methodology.

Readiness gates:

- v0.1.8.11 has shipped or explicitly deferred a bounded documentation
  remainder;
- the fold-core and feature-value-path workbooks have a stable home under
  `inst/design/manual/` or a clear disposition explaining why not;
- package vignette build semantics remain intact (`vignettes/` source,
  `inst/doc/` build output).

Implementation constraints:

- this is documentation-only follow-on work;
- no execution semantics, event schemas, durable identity bytes, target-risk
  behavior, OMS policy, or compiled-core architecture changes are authorized by
  the manual work itself;
- small fixes are allowed only when the article work uncovers stale links,
  stale diagrams, broken generated-doc references, or missing doc guards.

Non-scope:

- no package-vignette benchmark marketing;
- no public hosted benchmark dashboard;
- no rewrite of RFC/ADR/spec-packet governance records into articles;
- no broad implementation refactor hidden inside documentation work.

Source memory:

- `inst/design/horizon.md`, entry
  `2026-05-30 [documentation] Maintainer manual article backlog after
  v0.1.8.8 skeleton`, now pulled forward into v0.1.8.11.

### Later v0.1.8.x Sweep Stabilization

Intent:

- harden sweep behavior without opening a new architecture front;
- refine sweep result printing, failure capture, feature-factory coverage, and
  warmup diagnostics;
- consider `ledgr_snapshot_split()` only if the manual holdout workflow proves
  awkward after sweep ships.

Fold-core refactor (from the 2026-05-28 adversarial review; do before
OMS/risk/intraday open a new architecture front):

- collapse the two equity-reconstruction implementations — the inline run-path
  copy and the sweep summary, plus the test-only parity twins — into one
  production replay kernel fed by DB or memory event sinks;
- introduce a typed `ledgr_execution_spec()` constructor so `ledgr_run()` and
  `ledgr_sweep()` stop hand-building divergent `execution` lists;
- split `fold-core.R` (engine + reconstructors + metrics helpers) before those
  concerns multiply;
- add explicit event types (`POSITION_SEED`, and reserve `FEE`/`DIVIDEND`/
  `SPLIT`) instead of overloading `CASHFLOW` with `meta_json` flags.

See `inst/design/horizon.md` (fold-core structural-debt entry). The
phased-pulse restructure is tracked separately as a v0.1.9 target-risk
prerequisite (above).

### Peer Benchmark Expansion (Later v0.1.8.x)

Intent:

- expand the same-host peer comparison beyond `Backtrader` and `quantstrat` so
  v0.1.8.7's measured position has broader empirical grounding;
- replace vendor M3 orientation rows in `dev/bench/lean_reference.csv` and
  `dev/bench/ziplime_reference.csv` with real same-host measurements where
  feasible;
- add a second compiled-core data point so "compiled core is the next-class
  lever" is not a one-engine artifact.

Worth running same-host:

- **zipline-reloaded** — actively maintained Python event-driven backtester;
  closest architecture match to ledgr / Backtrader; lowest setup friction
  (pip-installable, comparable workload definition);
- **LEAN locally (Python-strategy mode)** — the structural apples-to-apples
  comparison for a future compiled-core ledgr: both are compiled engines with
  interpreted-language callbacks per pulse (LEAN's `.NET ↔ Python` boundary maps
  to a compiled-core ledgr's `C ↔ R` boundary). Closes the "we never measured a
  compiled engine on this host" gap; higher setup friction (LEAN CLI plus mono
  on non-Windows hosts) but highest payoff for the writeup. LEAN-C# (compiled
  strategy) is *not* the right baseline for this question — Python-strategy
  mode is;
- **NautilusTrader** — Rust-core / Python-wrapper engine; second compiled-core
  data point.

Worth a contextual row, not a headline:

- **VectorBT** — different paradigm (vectorized, no per-bar callback). Useful
  as the "what does vectorized look like" reference but structurally apples-to-
  oranges; report alongside event-driven peers only with an explicit paradigm
  note.

Out of scope for the expansion:

- **backtesting.py** — single-asset; doesn't face the multi-asset alignment
  problem (per the missing-data resilience research);
- **PyAlgoTrade** — unmaintained;
- **bt (Python)** — target-weight rebalance paradigm, not order-based; making
  the comparison fair is more work than the insight justifies.

Verdict-setter for compiled-core scoping (priority within the expansion):

- The LEAN-Python row is the empirical verdict on whether a compiled-core ledgr
  would land in the same performance class as LEAN. The structural argument
  says yes — both are compiled engines with interpreted-language callbacks per
  pulse, with ledgr keeping an additional ~2–5s residual for the per-fill
  sealed-ledger write LEAN-Python doesn't pay by default. The LEAN-Python
  number tells us whether that structural claim holds in measured form.
- Prioritize LEAN-Python locally above the other expansion targets when
  scheduling. The result is a load-bearing input for the v0.2.x+ compiled-core
  decision (a months-long build) and changes the framing:
  - if compiled-core ledgr would plausibly land near LEAN-Python (structural
    claim measured-confirmed): proceed with compiled-core scoping;
  - if the measured residual gap is larger than the structural argument
    predicts: rethink what compiled-core needs to address before committing to
    the build (likely callback-marshaling design, ctx access patterns, or
    DuckDB flush amortization).

Fairness constraints:

- same host, same power profile;
- same workload shape (500 × 1,260 daily SMA crossover) or one equivalent
  reference workload per engine class;
- indicator-implementation parity where possible — TTR-equivalent for ledgr /
  quantstrat, engine-native indicators elsewhere with documented notes;
- existing `dev/bench/peer_three_way.R` plus `peer_three_way_backtrader.py`
  harness extends with one new engine row per addition; no new harness
  architecture required.

Sequencing:

- Independent of v0.1.8.8 parallel-dispatch work; can land before, after, or
  alongside. v0.1.8.7 Batch 8 stays narrow (attribution against the existing
  three-engine peer set); peer-set expansion is a separate task whose
  deliverable is "the peer comparison table got more rows."

Non-scope:

- no public hosted benchmark dashboard;
- no cross-host peer-ranking claims; same-host scope only;
- no architectural comparison with vectorized engines beyond a contextual row
  with an explicit paradigm note.

See `inst/design/horizon.md` (peer-benchmark expansion entry, v0.1.8.x line).

### v0.1.8.11 Documentation, Structure, And Cleanup

v0.1.8.11 is a documentation, structure, and cleanup release. It precedes
v0.1.9 target risk and any other v0.1.9.x feature work. It is the entropy
management cycle the post-v0.1.8.10 / B2 codified-architecture surface
requires.

It supersedes and expands the previously planned v0.1.9.x Maintainer Manual
And Architecture Documentation milestone (kept below as the foundation). The
expansion absorbs RFC synthesis, ADR population, and decision-log synthesis
that the earlier milestone excluded as non-scope. That exclusion was correct
for v0.1.8.8; it is no longer correct after the v0.1.8.10 / B2 arc.

Authoritative input:

- `inst/design/ledgr_v0_1_8_11_spec_packet/v0_1_8_11_spec.md`;
- `inst/design/horizon.md` entry
  `2026-06-02 [documentation] Documentation, structure, and cleanup release
  before v0.1.9 features`;
- the existing 2026-05-30 maintainer manual backlog as foundation;
- `inst/design/horizon.md` entry
  `2026-06-01 [documentation] User-facing research-software disclaimer for
  financial backtesting`;
- `inst/design/horizon.md` entry
  `2026-06-01 [strategy] Strategy callback contract + authoring helpers
  post-v0.1.8.x direction`;
- `inst/design/horizon.md` entry
  `2026-06-02 [architecture] B2 spot-FIFO accelerator is not a derivatives
  accounting model`.

Intent:

- synthesize codified architectural decisions from accepted RFCs, decision
  logs, and spec packets into discoverable, human- and agent-readable form;
- populate ADRs for stabilized architectural decisions that currently live
  only as RFC bindings;
- audit `contracts.md` for stale, missing, duplicated, or poorly organized
  contract language after v0.1.8.10, then restructure only where that preserves
  or clarifies existing semantics;
- refresh user-facing vignettes (who-ledgr-is-for, why-r,
  strategy-development, research-workflow) to reflect the post-v0.1.8.10 /
  B2 reality, including ephemeral sweep as a real sweep mode and the
  v0.1.8.x performance arc as evidence that R can be fast;
- add a plain-English research-software disclaimer surface and modest links
  from user-facing entry points if review accepts the horizon proposal;
- author an internal v0.1.8.x performance-arc narrative that names what got
  faster and how to attribute it;
- structural pass on `inst/design/contracts.md` organized by surface
  (execution-spec, fold-engine, output-handler, lot-accounting, ctx, etc.)
  rather than chronologically;
- grow `inst/design/manual/` per the 2026-05-30 backlog (execution, data,
  features, sweep, observability);
- audit and refresh man pages that have drifted during the v0.1.8.x arc;
- add an RFC index that points readers at the load-bearing decisions and
  marks the rest as scaffolding;
- internal compiled-accounting documentation
  (`compiled_accounting_model` enum scope guard) for future contributors
  and future-self;
- document the post-v0.1.8.10 strategy accessor surface (`ctx$vec`,
  `ctx$idx()`, and `ctx$vec$feature(feature_id)`) and keep Pass 2 helper
  extensions deferred to the v0.1.9.x helper milestone.

Tone target:

- prose, not reference manual;
- a point of view, not a fact dump;
- examples that teach, not exhaustive enumeration;
- the maintainer voice should signal "this was thought about, here is why";
- a little fun to read - the synthesis layer earns its place by being more
  readable than the source.

Sequencing rationale:

- The v0.1.8.x arc has grown the codified-architecture surface past what
  the maintainer can hold in head. The RFC discipline ratifies decisions
  correctly but does not synthesize them into discoverable form.
- Deferring synthesis risks making the next architectural decision against
  a codified surface the maintainer no longer has full visibility on. That
  is the failure mode the RFC discipline was built to prevent.
- v0.1.9 target risk, v0.1.9.x crypto-readiness, walk-forward, and other
  planned feature work sit behind this release.

Readiness gates:

- v0.1.8.10 has shipped, including the B2 LDG-2522 disposition;
- the v0.1.9 feature arc has not started (target risk RFC scoping may run
  in parallel but implementation waits);
- existing vignette build semantics are intact (`vignettes/` source,
  `inst/doc/` build output);
- maintainer has explicit time budget for the synthesis-and-prose work;
  this is not a back-of-the-couch release.

Implementation constraints:

- this is a documentation, structure, and cleanup release;
- no execution semantics, event schemas, durable identity bytes,
  target-risk behavior, OMS policy, or compiled-core architecture changes
  are authorized by this release;
- small fixes are allowed only when the article work uncovers stale links,
  stale diagrams, broken generated-doc references, or missing doc guards;
- if a synthesis pass reveals an actual contract bug rather than a doc
  bug, it gets its own ticket in a later cycle; do not fix architecture
  bugs as side effects of documentation work.

Non-scope:

- no new public API;
- no execution-semantics or fold-core changes;
- no target risk, OMS, walk-forward, or compiled promotion work;
- no public hosted benchmark dashboard;
- no rewrite of accepted RFC text into prose articles (the RFCs remain
  authoritative; synthesis points at them, not replaces them);
- no broad implementation refactor hidden inside documentation work.
No tickets are cut yet. The first packet artifact is a spec draft for Claude /
maintainer review.

Source memory:

- `inst/design/horizon.md`, entries
  `2026-06-02 [documentation] Documentation, structure, and cleanup
  release before v0.1.9 features` and
  `2026-05-30 [documentation] Maintainer manual article backlog after
  v0.1.8.8 skeleton`;
- `inst/design/horizon.md`, entries
  `2026-06-01 [documentation] User-facing research-software disclaimer for
  financial backtesting`,
  `2026-06-01 [strategy] Strategy callback contract + authoring helpers
  post-v0.1.8.x direction`, and
  `2026-06-02 [architecture] B2 spot-FIFO accelerator is not a derivatives
  accounting model`.

### v0.1.9.x Line Sequencing

Sequencing decision recorded 2026-06-05. The v0.1.9.x line is a four-tick
arc culminating in walk-forward. Each tick produces identity or
infrastructure that walk-forward consumes when it ticket-cuts at v0.1.9.4:

- **v0.1.9.1** -- cost-API
  (`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md`,
  accepted; completed packet).
- **v0.1.9.2** -- sweep artifact persistence
  (`inst/design/rfc/rfc_sweep_artifact_persistence_v0_1_9_x_synthesis.md`,
  accepted; completed packet).
- **v0.1.9.3** -- target-risk: per-pulse restructure plus chainable
  risk layer
  (active packet; section immediately below; previously framed as the v0.1.9
  headline before the arc was sequenced).
- **v0.1.9.4** -- walk-forward culmination
  (`inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md`
  with Amendments 1 + 2 + Section 17 ticket-cut gate matrix). It gets
  cost identity from v0.1.9.1, sweep retention infrastructure from
  v0.1.9.2, and risk-chain identity from v0.1.9.3.

Rationale, cross-cycle identity handoffs, and scope-discipline
acknowledgment: see the 2026-06-05 horizon entry "v0.1.9.x line
sequencing -- four-tick arc culminating in walk-forward" in
`inst/design/horizon.md`.

Other v0.1.9.x roadmap candidates listed in sections below
(crypto-readiness spike, target-construction-helper extensions, etc.)
are not yet sequenced into this arc. They slot in as separate scoping
decisions when their windows open -- either as small parallel releases
between the four named ticks or absorbed into one of them at scoping
time.

### v0.1.9.3 Target Risk Layer

Sequenced as **v0.1.9.3** in the v0.1.9.x arc above. This remains the
target-risk packet in the four-tick sequence.

Authoritative input:

- `inst/design/rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md`.

Intent:

- introduce a chainable target-risk layer after sweep stabilizes;
- provide classed ledgr risk-step objects first, not arbitrary user-supplied
  risk functions;
- provide long-only and max-weight helpers as the minimum adapter set;
- preserve the same fold core parity contract by inserting risk between
  strategy targets and fill timing;
- expose risk identity in experiment/sweep candidate metadata;
- keep cost-estimation helpers separate from actual cost application.

Known constraint:

- Risk functions may initially receive the same strategy-context shape as the
  strategy function, including helpers such as `ctx$hold()`. If a future
  risk-specific context is introduced, the equivalence and method surface must
  be specified rather than assumed.

Implementation prerequisite (from the 2026-05-28 fold-core review):

- Net affordability and portfolio-level risk require restructuring the
  per-pulse fill loop. It currently interleaves delta -> proposal -> cost ->
  event -> state-mutation per instrument, which resists portfolio-level
  decisions. The target shape is plan (targets -> deltas) -> batch proposals
  -> batch cost -> batch/portfolio risk + net feasibility -> emit -> apply
  atomically. A per-instrument cash check would mis-reject rebalancing buys
  that sort before their funding sells. See `inst/design/horizon.md`
  (affordability-in-target-risk and the 2026-05-28 fold-core structural-debt
  entry).

Cost-estimation bridge:

- Pre-trade filters such as alpha-vs-cost checks belong in the risk layer
  because they can suppress proposed fills before timing/cost resolution.
- Current helpers based on close prices are approximations, not true execution
  cost estimates.
- Future risk design should decide whether risk receives a cost-estimation
  function or a cost-policy object that mirrors the execution cost resolver.
- Research order-policy chains, public cost/liquidity chains, and OMS lifecycle
  semantics are deferred to the execution-policy north-star thread.

### v0.1.9 Primitive Internals Planning Gates

Authoritative input:

- `inst/design/rfc/rfc_collapse_primitive_internals_v0_1_9_synthesis.md`.

Intent:

- adopt primitive internal shapes as a planning discipline: vectors, matrices,
  lists, and index maps inside hot paths, with data.frames treated as public
  boundary views;
- evaluate `collapse` as a conditional acceleration layer, not as an upfront
  dependency;
- make deterministic call discipline explicit before any production
  `collapse` path lands;
- preserve the LDG-2413 v0.1.8.3 base-R split/nest implementation rather than
  reopening the completed optimization ticket.

v0.1.9 planning scope:

- write the primitive-internals developer guide before broad implementation
  tickets;
- spike `ledgr_with_collapse_deterministic()` with scoped
  `collapse::set_collapse()` state restoration, including error-path restore
  tests;
- micro-profile the event-boundary output buffer path before claiming Phase B
  wall-clock value;
- run a safe cumulative-reconstruction parity spike for cash, positions, and
  equity curves while keeping FIFO lot replay out of scope.

Implementation gates:

- no `collapse` `Imports` dependency is added until the deterministic wrapper
  spike clears and at least one non-Phase-A production surface shows clear
  measured value on the LDG-2402 reference workload;
- hostile caller-side `collapse` settings must not change ledgr outputs;
- Phase B and Phase C.1 implementation work belongs in v0.1.9.x after the
  planning gates, not in the active v0.1.8.3 packet.

**Amended by ADR 0004 (2026-05-29):** the LDG-2457 real-run profile satisfies the
"clear measured value on a production surface" gate above — the per-event
buffer/append path is ~72-82% of loop R time
(`inst/design/audits/fold_path_hotpath_audit.md`). `collapse` adoption for the
buffer/emission lane is therefore pulled forward into the v0.1.8.7 fold-core
work; the deterministic-wrapper precondition (`ledgr_with_collapse_deterministic()`,
scoped `set_collapse()`, hostile-settings-safe) still applies. Alongside it,
`cli` (verified unused) and `R6` (legacy strategy interface) are dropped and
`collapse` added — a net 9 -> 8 Imports move. `tibble` is retained deliberately
as a tidyverse-compatibility signal. See
`inst/design/manual/performance_arc_v0_1_8_x.qmd`.

### v0.1.9.x Crypto-Readiness Spike And Doc Disposition

The crypto-readiness spike is deferred to v0.1.9.x. It remains a focused
measurement spike on whether spot crypto is already supported by ledgr's
existing equity-shaped surfaces, with explicit disposition for documentation
and any specific follow-up work. It is not a derivatives release; perpetuals,
dated futures, funding rates, and margin accounting all remain part of the
deferred derivatives arc that lands after the v0.1.x product arc completes.

Intent:

- verify spot-crypto support as a focused measurement spike before users
  discover edge cases in production research;
- confirm fractional-position correctness end-to-end (target -> fill ->
  lot -> trade -> equity -> metrics) at sub-integer quantities;
- confirm sub-second / sub-minute timestamp preservation through
  snapshot, fold core, and output handlers;
- confirm the v0.1.8.2 crypto metric-context template produces correct
  24/7 annualization in practice;
- probe the v0.1.9.x cost API for "% of notional" maker/taker cost
  expressibility;
- document the spot-crypto support level with explicit caveats, or route
  specific gaps to follow-up cycles.

This workstream is a measurement and decision packet. Implementation is
out of scope; any code change needed to make spot crypto work cleanly is
scoped into its own follow-up ticket or release after the spike concludes.

Required spike axes:

- **Fractional position correctness.** End-to-end test: declare a strategy that
  targets `0.0123 BTC`, run through the fold core, inspect lots, trades, and
  equity. Verify accounting precision is not silently coerced to integer at any
  layer.
- **Timestamp resolution.** Seal a synthetic snapshot with sub-second
  `ts_utc`, run a small strategy, confirm timestamps survive snapshot -> fold
  -> output handlers without truncation.
- **24/7 metric context.** Use the crypto metric-context template against a
  synthetic 7-day crypto-style snapshot, confirm annualization factor and
  Sharpe / drawdown calculations are correct for 24/7 cadence.
- **Maker/taker cost shape.** Probe whether "% of notional" commission is
  expressible through the existing `spread_bps` + `commission_fixed` surface
  or through the function-valued cost-model API. Identify the API extension
  needed if neither path is clean.
- **Demo data.** Decide whether to ship a small synthetic crypto demo dataset
  alongside `ledgr_demo_bars`, or leave users to bring their own.

Measurement outputs:

- pass/fail evidence per axis;
- a footgun list naming any code path that silently constrains crypto support;
- a support-level recommendation: **supported**, **supported with caveats**, or
  **blocked**.

Readiness gates:

- v0.1.8.x fold-core and benchmark work has stabilized enough that crypto
  findings are about crypto support rather than known execution scaffolding;
- v0.1.8.2 metric-context crypto template is in place;
- intraday-readiness audit findings inform which cadence and timestamp footguns
  to probe specifically.

Constraints:

- spot crypto only; no perpetuals, no dated futures, no funding rates, no
  margin model;
- no derivatives architecture work;
- no new instrument-class architecture;
- no exchange-specific adapter;
- the spike output is a doc disposition and a footgun list, not an
  implementation release.

Non-scope:

- crypto data adapter;
- exchange-specific cost-model factories;
- perpetuals or dated-futures contract specs;
- margin or funding-rate accounting;
- crypto demo strategy beyond what is needed to drive the spike's tests.

Exit decisions:

- **Pass:** ship a vignette section or short doc note explaining spot crypto
  support; close the spike with the footgun list pinned as contract tests.
- **Supported with caveats:** ship a doc note naming the workarounds, route
  specific gaps to a v0.1.9.x follow-up.
- **Blocked:** identify the minimum work required, scope it into a v0.1.9.x
  follow-up or later packet, and defer the user-facing crypto support claim
  until the work lands.

### v0.1.9.4 Walk-Forward Evaluation

Sequenced as **v0.1.9.4** in the v0.1.9.x arc (see v0.1.9.x Line
Sequencing section above). Ticket-cut consumes cost-identity from
v0.1.9.1, sweep retention infrastructure from v0.1.9.2, and risk-chain
identity from v0.1.9.3; Section 17 gate matrix from the synthesis fires
at this packet.

Accepted design input:

- `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md`.

Intent:

- build `ledgr_walk_forward()` only after `ledgr_sweep()` is stable enough to
  act as the training-window candidate evaluator;
- keep walk-forward as a wrapper over `ledgr_sweep()` and `ledgr_run()`, not a
  second fold-core execution path;
- represent training/test scoring windows explicitly, including warmup
  hydration and final-bar fill semantics;
- use ledgr-owned classed selection rules over train-window scalar score rows;
- run exactly the selected candidate on the next test window and record
  explicit fold, candidate, score, and session provenance;
- allow ordinary `ledgr_promote()` only through an extracted explicit candidate
  rather than through an implicit parameter path or selection rule.

Known constraints:

- implementation waits until the v0.1.9 target-risk chain is stable enough to
  contribute risk-chain identity to walk-forward sessions and candidates;
- fold-core input sources must support sliced evaluation without requiring a
  sealed snapshot per fold;
- precomputed feature validation must cover candidate-varying feature factories
  and slice-aware warmup;
- identity excludes transient `sweep_id` and includes snapshot, experiment,
  fold-list, selection-rule, metric-context, feature, parameter, seed, and
  risk-chain components as bound in the synthesis;
- reproducibility and selection integrity remain orthogonal: provenance records
  what happened, not whether the selection protocol was statistically sound.
- richer diagnostic retention, randomized/blocked slice protocols, PBO, DSR,
  CPCV, purging/embargo, cross-snapshot folds, and paper/live walk-forward are
  deferred until the first walk-forward window model is stable.

### v0.1.9.x Selection Integrity Diagnostics

Intent:

- extend the walk-forward window model into explicit selection-bias diagnostics;
- support blocked, anchored, or randomized slice protocols without violating
  no-lookahead constraints;
- make PBO/CSCV-style diagnostics visible as research-validity tools, not as
  ordinary sweep ranking;
- provide reports that distinguish reproducibility, validation protocol, and
  selection integrity.

Constraints:

- do not treat arbitrary row-level random splits as valid time-series
  validation;
- do not make provenance claims stand in for statistical selection discipline;
- build on stable sweep results, metric context, grid ergonomics, and
  slice-aware feature validation;
- keep the first `ledgr_walk_forward()` release narrower than this diagnostic
  layer.

### v0.1.9.2 Sweep Artifact Persistence

Sequenced as **v0.1.9.2** in the v0.1.9.x arc. The RFC cycle is accepted and
closed. The active packet opens from
`inst/design/rfc/rfc_sweep_artifact_persistence_v0_1_9_x_synthesis.md`.

Intent:

- persist compact sweep result bundles for audit and expensive exploratory
  work;
- add `ledgr_sweep_retention()` and a `retain` argument on `ledgr_sweep()`,
  defaulting to today's scalar-only sweep behavior;
- optionally retain net portfolio equity/return series for completed
  candidates only;
- save, reopen, list, and inspect saved sweeps in the experiment store;
- expose long and wide retained-series accessors over reopened and in-memory
  sweeps;
- persist cost identity from v0.1.9.1 (`cost_model_hash`, `cost_plan_json`);
- preserve reopened-sweep candidate extraction and promotion readiness without
  treating stored scalar rows or retained return rows as committed-run
  artifacts.

Constraints:

- no ranking helpers, named selection views, winner-picking, or automatic
  promotion;
- no full ledger, fill, trade, or per-instrument artifacts for every candidate
  by default;
- no benchmark-relative diagnostics, signal-decay tooling,
  implementation/cost-decay tooling, gross-vs-net cost attribution, liquidity,
  TCA, OMS, taxes, financing, or broker reconciliation;
- no walk-forward integration or per-fold retention dimensions in v0.1.9.2;
- do not weaken `ledgr_promote()` or `run_promotion_context`;
- keep artifact persistence separate from automatic winner selection;
- promotion from a reopened saved sweep re-executes the selected candidate from
  its reproduction key against the sealed snapshot.

### v0.1.9.x Target Construction Helper Extensions

Intent:

- extend the existing `signal_*()` -> `select_*()` -> `weight_*()` ->
  `target_*()` helper pipeline;
- add small, deterministic helpers for common EOD target construction patterns
  such as rank weighting, inverse-vol weighting, explicit normalization,
  rebalance bands, or similar narrow primitives after their contracts are
  specified;
- keep helpers composable with full named numeric target vectors and strategy
  preflight.

Constraints:

- this is not full portfolio optimization, quadratic solving, risk parity, or
  black-box allocation;
- helpers must not collapse target construction into target risk, cost,
  liquidity, or order policy;
- helpers must preserve the public strategy contract: strategies return full
  named numeric target quantities or an explicit wrapper maps to those targets.

### v0.1.9.1 Public Transaction-Cost Model API

Sequenced as **v0.1.9.1** in the v0.1.9.x arc. This is the first dependency
that the later walk-forward packet consumes.

Status note:

- v0.1.9.1 is complete. It shipped the public cost API, explicit
  `timing_model` plus required `cost_model` construction contract, legacy
  shape rejection, and release-gate documentation closeout.
- `cost_model_hash` and `cost_plan_json` are now the concrete cost-identity
  handoff that v0.1.9.2 sweep persistence and v0.1.9.4 walk-forward must
  consume.

Intent:

- expose the accepted cost-model factories in v0.1.9.1 as the first
  dependency in the four-tick v0.1.9.x arc;
- keep broker/exchange-specific templates out of core unless clearly labelled
  approximations;
- preserve the distinction between cost application and quantity-changing
  execution/liquidity policy;
- keep arbitrary function-valued cost models deferred until a later identity
  RFC resolves fingerprinting and source-treatment rules.

### v0.2.x Liquidity And Capacity Policy

Intent:

- model execution feasibility separately from cost;
- add policy concepts such as participation limits, minimum ADV/volume, minimum
  price, turnover/capacity diagnostics, or liquidity refusal only after the
  execution context exposes the required execution-bar data;
- keep capacity estimates explicitly labelled as research approximations unless
  a later OMS/execution model makes stronger claims possible.

Constraints:

- liquidity policy may change quantities or refuse fills, so it must not be
  hidden inside transaction-cost calculation;
- participation and capacity rules require execution-bar volume and point-in-
  time data assumptions;
- this layer must coordinate with OMS semantics before paper/live execution.

### v0.2.x Point-In-Time Data Tables

Intent:

- introduce explicit point-in-time semantics for external observations and
  reference data beyond OHLCV bars;
- model fields such as `known_at`, `available_at`, `effective_at`,
  `event_time`, `revision_time`, source, source version, and alignment policy;
- support later value, quality, earnings, macro, index-membership, and factor
  research without hidden lookahead.

Constraints:

- no hidden provider lookups inside metric, strategy, indicator, or fold-core
  paths;
- external observations must be sealed, versioned, and provenance-bearing
  before they affect execution or metrics;
- feature beta, universe-derived benchmarks, and fundamental/factor features
  depend on this layer.

### v0.2.x Corporate Actions And Instrument Master

Intent:

- make real equity data semantics explicit before ledgr claims serious
  cross-sectional equity research support;
- define raw versus adjusted price policy, split and dividend handling,
  delisting treatment, symbol-to-instrument identity, and point-in-time
  universe membership;
- keep sealed snapshots honest about survivorship and adjustment assumptions.

Constraints:

- reproducible snapshots are not enough if the sealed data is survivorship-
  biased or uses ambiguous adjustment policy;
- corporate-action semantics should coordinate with point-in-time data tables
  and benchmark/reference-data design;
- adapters may provide data, but ledgr must define the interpretation contract
  before using it in committed experiments.

### v0.2.x Explicit Accounting Event Types RFC

Intent:

- replace overloaded accounting-critical event semantics with explicit event
  types when corporate actions, fees, and instrument-master work need them;
- evaluate `POSITION_SEED`, `FEE`, `DIVIDEND`, and `SPLIT` together rather
  than slipping one schema change into a maintenance cycle;
- keep event-stream, replay, promotion, and migration consequences visible in a
  dedicated RFC.

Constraints:

- do not change current opening-position `CASHFLOW` semantics as part of
  v0.1.8.8 fold-core documentation or parallel-dispatch work;
- the RFC must address DB schema/migration, replay semantics, event-stream
  parity or accepted intentional parity change, reproduction keys, and docs;
- coordinate with point-in-time data tables and corporate-action interpretation
  policy before committed experiments depend on these event types.

### v0.2.x Benchmark Context And Active Metrics

Intent:

- implement the reserved `metric_context$benchmark` substrate with aligned
  benchmark/reference returns;
- add benchmark-relative diagnostics such as active return, tracking error,
  information ratio, beta, alpha, benchmark correlation, and capture metrics
  after the benchmark provider contract is stable;
- start with explicit external benchmark series before universe-derived
  benchmarks.

Constraints:

- no hidden ticker lookup or provider download during metric computation;
- universe-derived benchmarks require point-in-time membership and survivorship
  semantics, so they come after the external-benchmark substrate;
- diagnostic beta should not be gated on the target-risk chain, but feature beta
  and beta constraints require additional alignment/risk designs.

### v0.2.x External Package Adapters (PerformanceAnalytics first)

Intent:

- expose ledgr's stable public result tables (equity, fills, trades, ledger) to
  the established R quant ecosystem through thin, optional, output-only adapters;
- ship a PerformanceAnalytics adapter first for its real strength — the
  drawdown/return tables and long-tail risk/return stats — as the public proof
  of the hexagonal pattern: ledgr owns the canonical evidence, adapters enrich
  the analysis;
- treat charting as a separate, swappable renderer over the same return stream,
  not a PA lock-in: PA's base-graphics charts are a familiar/legacy option, but
  tidyquant (ggplot2 over the same PA metrics) or a native ledgr ggplot
  tear-sheet are the modern faces; the reusable port is the equity -> return
  conversion, which many renderers can consume;
- rank later adapters by readiness: PerformanceAnalytics (reporting) ->
  PortfolioAnalytics (portfolio construction, after the target-risk chain) ->
  tidyfinance (factor/data research, with PIT semantics) -> quantmod (data
  ingestion); PMwR / quantstrat / blotter / fPortfolio are low priority or
  skipped due to accounting/engine overlap;
- treat this as a large capability multiplier: one stable result-table contract
  unlocks the whole reporting/research surface without ledgr reimplementing it.

Constraints:

- output projection only — no causality, no strategy-contract, no engine
  mutation, no second canonical metrics path;
- consume ledgr's own canonical return series (whatever `ledgr_compute_metrics`
  derives); never reinvent the return formula inside an adapter;
- PerformanceAnalytics metrics use PA conventions and may differ from ledgr's;
  scope PA to what ledgr does not already compute and label any overlap rather
  than presenting two conflicting headline numbers as both authoritative;
- optional dependency (`Suggests` + `check_installed`), never `Imports`;
- adapters inspect, they do not select winners (no sweep ranking / promotion
  automation);
- PerformanceAnalytics benchmark-relative metrics (active return, tracking
  error, information ratio) coordinate with the v0.2.x Benchmark Context layer so
  PA does not pre-empt ledgr's own benchmark contract;
- gated by a full RFC cycle before any public adapter API or new `Suggests`
  dependency ships.

### v0.2.x OMS Semantics And Snapshot Lineage

Authoritative input:

- `inst/design/rfc/rfc_execution_policy_pipeline_audit_signal_north_star.md`.

Intent:

- model orders, cancellations, partial fills, and execution reports in
  simulation before paper/live adapters;
- add snapshot lineage and roll-forward data-source workflows;
- preserve event-sourced reconstruction and auditability;
- keep broker reconciliation requirements explicit before live execution.

### v0.2.x Reference Strategy Templates

Intent:

- provide small executable examples that stress-test ledgr's strategy,
  target-construction, risk, metric, sweep, and validation APIs;
- use canonical EOD examples such as flat baseline, SMA crossover, top-N
  momentum, mean reversion, or rotation only as contract demonstrations;
- support documentation, auditr tasks, and agent evaluation without becoming a
  black-box strategy zoo.

Constraints:

- no profitability claims;
- no hidden data downloads or provider assumptions;
- examples must use sealed snapshots, explicit features, explicit params, and
  ordinary promotion/validation workflows.

### v0.3.0 Paper Trading Adapter And Reconciliation

Intent:

- add paper-trading adapters only after OMS semantics are stable;
- reconcile ledgr expected state against broker-reported orders, fills,
  positions, and cash before trading resumes;
- never claim the internal ledger alone is sufficient for live restart safety;
- keep adapter-specific fee schedules and execution quirks out of core unless
  they are stable primitives;
- simulate data streams with realistic deficiencies — missing, garbled, late,
  duplicated, and revised ticks — at much higher than EOD frequency, to test
  the execution seams before live;
- require the backtest engine to model degraded data on the same execution
  path (direction B from the 2026-05-28 live bad-data resilience horizon
  entry), so strategies are validated against the data conditions they will
  face live, not an artificially clean dense panel.

Data-quality boundary:

- Live data is an append-only data log with an ingest-time data-quality and
  degradation policy (quarantine / reject / carry-forward-with-staleness /
  halt-symbol / halt-session), distinct from the sealed-snapshot fail-fast gate
  used in backtest. The dense-panel `ledgr_missing_bars` abort is a backtest
  seal-time gate, not a universal invariant.
- This needs a dedicated RFC (the maintainer has flagged it). Scope: a unified
  data-quality model spanning sealed backtest and streaming live, the
  degradation-policy surface, the bad-data simulation harness, and the
  intersection with v0.2.x Point-In-Time Data Tables (late/revised ticks).

### v0.4.0 Observability And Operations

Intent:

- improve operational telemetry, run monitoring, and restart visibility;
- keep observability read-only with respect to persistent ledgr tables;
- support small-team operational workflows without changing research semantics.

### v1.0.0 Small-Scale Live Trading

Intent:

- live trading is the end of the research-to-paper arc, not a shortcut around
  it;
- scope remains small scale and correctness-first;
- live mode must inherit sealed data/provenance discipline where applicable and
  explicit broker reconciliation where required.

## Deferred Strategy And Integration Families

The following remain deferred until the research-to-paper arc is stable:

- full portfolio optimization support;
- calendar and event-driven strategies;
- pairs and spread trading;
- PerformanceAnalytics reporting adapters;
- TA-Lib or additional indicator backends;
- ML strategy artifact management;
- futures, options, crypto, FX, intraday, and multi-currency market-structure
  support.

These are intentionally not expanded here. If one becomes relevant to an active
milestone, promote it from `inst/design/horizon.md` or cut a focused RFC/spec.

ML strategy artifact management depends on stable walk-forward windows,
point-in-time feature tables, model artifact identity, prediction-table
provenance, and selection diagnostics. Do not reduce it to "call `predict()`
inside a strategy."

## Permanently Unsupported Patterns

ledgr is not aiming to support:

- high-frequency or tick-by-tick execution;
- sub-millisecond simulation;
- black-box live trading without reconciliation;
- implicit target completion where missing instruments are treated as zero;
- unsealed mutable market-data inputs for committed experiments;
- hidden dependency capture in strategy source.

## Final Note

The roadmap exists to keep direction clear. The closer a change is to execution
semantics, persistence, feature identity, strategy reproducibility, or public
API, the more it should be grounded in `contracts.md`, the active packet, and
the relevant architecture/RFC documents instead of roadmap prose.
