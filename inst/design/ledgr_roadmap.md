# ledgr Roadmap

**Status:** Active roadmap.
**Authority:** Milestone sequence, current planning horizon, and downstream
constraints.
**Current cycle:** v0.1.8.00 design-governance prep.
**Active packet:** `inst/design/ledgr_v0_1_8_00_spec_packet/`.

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

- **One execution semantics.** `ledgr_run()` and future `ledgr_sweep()` must
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
- **Public API only after internal boundaries are stable.** Risk, sweep, and
  cost-model APIs must not expose internals that will immediately need to be
  rewritten.

## Roadmap Discipline

Roadmap detail is intentionally uneven:

- Completed milestones are one-line records with links to spec packets.
- The active prep cycle and next implementation milestone carry detailed scope.
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
| v0.1.8.00 | Active prep | Design-document governance and v0.1.8 readiness. | `inst/design/ledgr_v0_1_8_00_spec_packet/` |
| v0.1.8 | Next | Lightweight parameter sweep mode and fold-core split. | To be cut after v0.1.8.00 |
| v0.1.8.x | Planned | Sweep stabilization and directly adjacent UX hardening. | Future packet |
| v0.1.8.1 | Planned | Reference-data and risk-free-rate adapters. | Future packet |
| v0.1.9 | Planned | Target risk layer. | Future packet |
| v0.1.9.x / v0.2.x | Planned | Walk-forward and selection-bias diagnostics. | Future packet |
| v0.1.9.x / v0.2.0 | Planned | Public transaction-cost model API after internal boundary stabilizes. | Future packet |
| v0.2.x | Planned | OMS semantics, snapshot lineage, and roll-forward data sources. | Future packets |
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

## Active Prep: v0.1.8.00

v0.1.8.00 prepares the repository for v0.1.8 implementation. It is a
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

## Next Milestone: v0.1.8 Lightweight Sweep Mode

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
  through `ledgr_run()`;
- precomputed-feature object validated against snapshot hash and feature
  fingerprints;
- fill timing and cost resolution as separable internal steps.

The fold core owns deterministic execution:

- pulse calendar order;
- pulse context construction;
- registered feature lookup;
- strategy invocation;
- target validation;
- fill timing;
- cost resolution;
- final-bar no-fill behavior;
- cash, position, and state transitions;
- event-stream meaning.

Output handlers decide what to keep:

- full DuckDB ledger and provenance for `ledgr_run()`;
- in-memory candidate summaries for sweep;
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
- candidate status and failure capture;
- caller-owned ranking through ordinary R/dplyr workflows;
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
targets_risked
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
- mandatory `ledgr_snapshot_split()`;
- paper/live adapter behavior.

## Future Constraints Beyond v0.1.8

The following milestones are intentionally brief. They are here only to keep
downstream constraints visible while v0.1.8 is designed.

### v0.1.8.x Sweep Stabilization

Intent:

- harden v0.1.8 sweep behavior without opening a new architecture front;
- fix bugs and parity gaps found after the first sweep release;
- refine sweep result printing, failure capture, feature-factory coverage, and
  warmup diagnostics;
- improve evaluation-discipline documentation around manual train/test flows;
- consider `ledgr_snapshot_split()` only if the manual holdout workflow proves
  awkward after sweep ships.

Non-scope:

- no walk-forward API;
- no PBO/CSCV diagnostics;
- no public parallel sweep feature;
- no public risk-layer API;
- no public cost-model API;
- no intraday semantics.

### v0.1.8.1 Reference Data And Risk-Free Rate Adapters

Intent:

- add optional reference-data adapters for benchmark/risk-free-rate inputs;
- keep external data provenance explicit;
- avoid making external reference data a hidden dependency of core metrics;
- keep current sealed snapshot semantics intact.

### v0.1.9 Target Risk Layer

Intent:

- introduce `risk_fn(targets, ctx, params) -> targets` after sweep stabilizes;
- provide helpers for max weight, long-only, sector/net exposure, and minimum
  trade value;
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

### v0.1.9.x / v0.2.x Walk-Forward And Selection-Bias Diagnostics

Intent:

- build `ledgr_walk_forward()` only after `ledgr_sweep()` is stable enough to
  act as the training-window candidate evaluator;
- represent training/scoring windows explicitly, including separate scoring
  ranges and warmup lookback ranges;
- reuse the same ranking/objective contract that sweep exposes instead of
  duplicating selection logic;
- evaluate PBO/CSCV diagnostics after walk-forward and sweep result shapes are
  stable enough to support combinatorial candidate-selection analysis.

Known constraints:

- fold-core input sources must support sliced evaluation without requiring a
  sealed snapshot per fold;
- precomputed feature validation must cover candidate-varying feature factories
  and slice-aware warmup;
- reproducibility and selection integrity remain orthogonal: provenance records
  what happened, not whether the selection protocol was statistically sound.

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

### v0.2.x OMS Semantics And Snapshot Lineage

Intent:

- model orders, cancellations, partial fills, and execution reports in
  simulation before paper/live adapters;
- add snapshot lineage and roll-forward data-source workflows;
- preserve event-sourced reconstruction and auditability;
- keep broker reconciliation requirements explicit before live execution.

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

- portfolio optimization support;
- calendar and event-driven strategies;
- pairs and spread trading;
- PerformanceAnalytics reporting adapters;
- TA-Lib or additional indicator backends;
- ML strategy artifact management;
- futures, options, crypto, FX, intraday, and multi-currency market-structure
  support.

These are intentionally not expanded here. If one becomes relevant to an active
milestone, promote it from `inst/design/horizon.md` or cut a focused RFC/spec.

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
