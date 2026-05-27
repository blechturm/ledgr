# ledgr Roadmap

**Status:** Active roadmap.
**Authority:** Milestone sequence, current planning horizon, and downstream
constraints.
**Latest completed packet:** `inst/design/ledgr_v0_1_8_4_spec_packet/`.
**Active packet:** v0.1.8.5 canonical research workflow and teachability.
**Active packet path:** `inst/design/ledgr_v0_1_8_5_spec_packet/`.

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
| v0.1.8.5 | Active | Canonical research workflow and teachability release after active aliases and grid UX stabilize. | `inst/design/ledgr_v0_1_8_5_spec_packet/` |
| v0.1.8.6 | Planned | DuckDB feature-storage measurement spike, snapshot administration and ETL provenance implementation, and research-loop ergonomics helpers (sweep review and promotion recovery summary); RFC-driven. | Future packet; horizon entries |
| v0.1.8.7 | Planned | Parallel sweep dispatch after serial semantics, metrics, grid UX, and R-level optimization stabilize. | Future packet |
| v0.1.9 | Planned | Target risk layer and primitive-internals planning gates. | Future packet |
| v0.1.9.x | Planned | Walk-forward evaluation before OMS and paper-trading work. | Future packet; accepted RFC synthesis |
| v0.1.9.x | Planned | Conditional primitive-internals implementation phases after collapse gates. | Future packet |
| v0.1.9.x | Planned | Selection integrity diagnostics after the walk-forward window model stabilizes. | Future packet |
| v0.1.9.x | Planned | Sweep artifact persistence for compact search-space audit. | Future packet |
| v0.1.9.x | Planned | Target construction helper extensions over the existing strategy-helper pipeline. | Future packet |
| v0.1.9.x / v0.2.0 | Planned | Public transaction-cost model API after internal boundary stabilizes. | Future packet |
| v0.2.x | Planned | Liquidity and capacity policy separate from cost application. | Future packet |
| v0.2.x | Planned | Point-in-time data tables for external observations and reference data. | Future packet |
| v0.2.x | Planned | Corporate actions and instrument master for serious equity data. | Future packet |
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

- `inst/design/architecture/ledgr_v0_1_8_sweep_architecture.md`
- `inst/design/architecture/ledgr_sweep_mode_ux.md`
- `inst/design/architecture/sweep_mode_code_review.md`
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

### v0.1.8.6 DuckDB Feature Storage Spike, Snapshot Administration, And Research-Loop Helpers

v0.1.8.6 hosts three coordinated workstreams. They share a release but are
scoped and decided independently.

Sequencing:

- A full RFC cycle on snapshot administration and ETL provenance metadata
  must conclude before the v0.1.8.6 spec is cut. The horizon entry is the
  seed-shape input. The research-loop ergonomics helpers (Workstream C)
  fold into the same RFC because the promotion-recovery summary couples
  directly to the snapshot/run metadata model; the RFC synthesis decides
  helper shape alongside metadata shape.
- The DuckDB feature-storage spike remains a measurement-and-decision
  packet; its outcome is decided after the spike runs, independently of
  the snapshot administration and helpers RFC.

#### Workstream A: Snapshot Administration And ETL Provenance

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

Authoritative input (planned):

- RFC cycle on snapshot administration and provenance metadata, to be cut
  after v0.1.8.5 closes and before the v0.1.8.6 spec is cut;
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
  storage surface before v0.1.8.7 parallel dispatch;
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
  v0.1.8.7 parallel-dispatch decision.

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

#### Workstream C: Research-Loop Ergonomics Helpers

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

Authoritative input (planned):

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

### v0.1.8.7 Parallel Sweep Dispatch

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

### Later v0.1.8.x Sweep Stabilization

Intent:

- harden sweep behavior without opening a new architecture front;
- refine sweep result printing, failure capture, feature-factory coverage, and
  warmup diagnostics;
- consider `ledgr_snapshot_split()` only if the manual holdout workflow proves
  awkward after sweep ships.

### v0.1.9 Target Risk Layer

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

### v0.1.9.x Walk-Forward Evaluation

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

### v0.1.9.x Sweep Artifact Persistence

Intent:

- persist compact sweep result bundles for audit and expensive exploratory
  work;
- store grid definitions, candidate summaries, warnings/errors, metric context,
  feature-set hashes, execution seeds, selection/ranking views, manifest data,
  and snapshot locator hints;
- let promoted runs reference or copy enough sweep artifact metadata to answer
  "why this candidate?" without committing every candidate as a durable run.

Constraints:

- do not store full ledger, fill, trade, or equity artifacts for every
  candidate by default;
- do not weaken `ledgr_promote()` or `run_promotion_context`;
- keep artifact persistence separate from automatic winner selection.

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

### v0.1.9.x / v0.2.0 Public Transaction-Cost Model API

Intent:

- expose cost-model factories only after the internal v0.1.8 boundary and
  v0.1.9 risk identity model are stable;
- keep broker/exchange-specific templates out of core unless clearly labelled
  approximations;
- preserve the distinction between cost application and quantity-changing
  execution/liquidity policy;
- require fingerprinting/source/identity treatment for function-valued cost
  models before public exposure.

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
  they are stable primitives.

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
