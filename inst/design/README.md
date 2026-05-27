# ledgr Design Documents

**Status:** Active design index.
**Authority:** Operational map for agents and human collaborators.
**Latest completed release packet:** `v0.1.8.4`.
**Current active packet:** `v0.1.8.5` canonical research workflow and
teachability.
**Current active packet path:** `inst/design/ledgr_v0_1_8_5_spec_packet/`.
The completed `inst/design/ledgr_v0_1_8_4_spec_packet/` is now an archival
release record.

This directory is the design memory for ledgr. Files here do not all have the
same authority. Use this README to decide what to read first and how much weight
to give each document.

## Start Here

For any non-trivial change, read in this order:

1. `contracts.md` - current execution, snapshot, persistence, feature, and
   strategy contracts.
2. `ledgr_roadmap.md` - milestone arc and active horizon.
3. If a current spec packet exists, read it. Otherwise use the roadmap and
   accepted design decisions to prepare the next packet, not to implement.
4. Only the architecture, RFC, audit, or spike documents relevant to the active
   ticket.

Historical spec packets are records, not current instructions, unless a task
explicitly asks you to inspect one.

## Authority Levels

| Role | Meaning |
| --- | --- |
| Contract | Must be preserved unless changed by a new spec or ADR. |
| Roadmap | Milestone sequence, active horizon, and downstream constraints. |
| Spec packet | Versioned implementation plan and ticket record. |
| Architecture input | Active design constraint for upcoming implementation. |
| Accepted design decision | RFC synthesis accepted by the maintainer; binding for ticket cut and implementation planning within its stated scope until superseded by a spec packet, contract, ADR, or architecture note. |
| RFC / response | Proposal or reviewer disposition; binding only after accepted into spec, roadmap, contract, or ADR. |
| Audit / review | Findings that must be routed before release; not all findings remain active after routing. |
| Spike | Exploratory technical research; informative unless promoted into spec or architecture. |
| Operational playbook | Process instructions for release and collaboration. |
| Horizon note | Non-binding parking lot for future design observations. |

## Pre-CRAN Compatibility Policy

Until ledgr is released on CRAN, stored artifacts, database schemas, config
hashes, provenance formats, and experimental APIs may change without backward
compatibility or a deprecation cycle. Pre-CRAN artifacts are development
artifacts; rerun experiments after upgrading when a cycle changes storage,
hashing, or execution contracts.

This policy permits intentional breaking changes before CRAN. It does not
permit accidental drift. Fingerprint pins, release gates, contract tests,
hash-verification checks, and reproducibility discipline remain load-bearing
for current-version trust and agent containment. Once ledgr reaches CRAN, the
project must define an explicit compatibility and deprecation policy.

## Current Planning State

The v0.1.8.4 packet is complete. It delivered active parameterized feature
aliases, separate feature-grid and strategy-grid helpers, alias-map provenance,
alias-aware pulse debugging, the demo SMA-crossover teaching fixture, and
routed v0.1.8.3 auditr fixes that fit the release scope.

- Spec: `ledgr_v0_1_8_4_spec_packet/v0_1_8_4_spec.md`.
- Auditr triage:
  `ledgr_v0_1_8_4_spec_packet/ledgr_triage_report.md`,
  `ledgr_v0_1_8_4_spec_packet/categorized_feedback.yml`,
  `ledgr_v0_1_8_4_spec_packet/cycle_retrospective.md`, and
  `ledgr_v0_1_8_4_spec_packet/auditr_intake_synthesis.md`.
- Tickets: `ledgr_v0_1_8_4_spec_packet/v0_1_8_4_tickets.md`.
- Machine-readable tickets: `ledgr_v0_1_8_4_spec_packet/tickets.yml`.

The active packet is v0.1.8.5 canonical research workflow and teachability,
including installed-vignette migration to Quarto and article styleguide review.
It is grounded in
`rfc/rfc_research_workflow_artifact_topology_v0_1_8_x_synthesis.md`.

- Spec: `ledgr_v0_1_8_5_spec_packet/v0_1_8_5_spec.md`.
- Tickets: `ledgr_v0_1_8_5_spec_packet/v0_1_8_5_tickets.md`.
- Machine-readable tickets: `ledgr_v0_1_8_5_spec_packet/tickets.yml`.
- Vignette styleguide: `vignette_styleguide.md`.

Do not implement v0.1.8.5 work beyond the spec scope. v0.1.8.5 is
documentation/workflow alignment first; DuckDB-backed feature storage,
parallel dispatch, target risk, cost/liquidity, snapshot lineage, live data
logs, point-in-time regressors, and OMS work remain later milestones.

## Core Documents

- `contracts.md` - authoritative contract index.
- `ledgr_roadmap.md` - milestone arc and active horizon.
- `rfc_cycle.md` - RFC-stage process reference for seed, response,
  synthesis, final review, and horizon-entry workflows.
- `ledgr_design_document.md` - foundational design document.
- `ledgr_design_philosophy.md` - product and design philosophy.
- `model_routing.md` - model/task routing guidance.
- `ledgr_ux_decisions.md` - cross-cutting UX decisions.
- `release_ci_playbook.md` - release gate and CI playbook.
- `vignette_styleguide.md` - Quarto-forward article styleguide for installed
  vignettes and teachability reviews.
- `horizon.md` - non-binding future-idea parking lot.

## Current Architecture Inputs

These files are active architecture inputs from the v0.1.8 cycle, still
load-bearing for future sweep and fold-core work.

- `architecture/ledgr_v0_1_8_sweep_architecture.md`
- `architecture/ledgr_sweep_mode_ux.md`
- `architecture/sweep_mode_code_review.md`
- `architecture/ledgr_feature_map_ux.md`

## Accepted Design Decisions

These synthesis documents are accepted by the maintainer and binding for ticket
cut and implementation planning within their stated scope. They live in `rfc/`
as the end of their RFC thread. When a decision stabilises further it may be
extracted into a standalone architecture note in `architecture/`.

| Area | Document | Scope | Status |
| --- | --- | --- | --- |
| Sweep single-core optimization arc | `rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md` | v0.1.8.3 optimization sequence | Accepted |
| Multi-output indicator bundle UX | `rfc/rfc_multi_output_indicator_ux_synthesis.md` | v0.1.8.1 bundle authoring | Accepted |
| Metric context and risk metrics | `rfc/rfc_risk_free_rate_metric_context_v0_1_8_1_synthesis.md` | v0.1.8.2 metric design | Accepted |
| Target-risk chain boundary | `rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md` | v0.1.9 target-risk planning | Accepted |
| Indicator codebase simplification | `rfc/rfc_indicator_codebase_simplification_v0_1_8_x_synthesis.md` | v0.1.8.1 Phase 1 determinism extraction; v0.1.8.2 Phase 2 file/role cleanup | Accepted |
| Active parameterized feature aliases | `rfc/rfc_active_parameterized_feature_aliases_v0_1_8_x_synthesis.md` | v0.1.8.4 sweep authoring ergonomics | Accepted |
| Research workflow and artifact topology | `rfc/rfc_research_workflow_artifact_topology_v0_1_8_x_synthesis.md` | v0.1.8.5 canonical workflow and teachability planning | Accepted |
| Primitive internals and conditional collapse acceleration | `rfc/rfc_collapse_primitive_internals_v0_1_9_synthesis.md` | v0.1.9 primitive-internals planning and v0.1.9.x implementation gates | Accepted |
| Walk-forward evaluation | `rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md` | v0.1.9.x walk-forward ticket-cut planning after target risk | Accepted |
| OMS semantics and order lifecycle | `rfc/rfc_ledgr_oms_seed_synthesis.md` | v0.2.x OMS data-model and lifecycle planning; paper/live deferred | Accepted |

## RFCs

- `rfc/rfc_design_doc_governance.md`
- `rfc/rfc_design_doc_governance_response.md`
- `rfc/rfc_cost_model_architecture.md`
- `rfc/rfc_cost_model_architecture_response.md`
- `rfc/rfc_rng_contract_v0_1_8.md`
- `rfc/rfc_rng_contract_v0_1_8_response.md`
- `rfc/rfc_sweep_candidate_promotion_contract_v0_1_8.md`
- `rfc/rfc_sweep_candidate_promotion_contract_v0_1_8_response.md`
- `rfc/rfc_sweep_candidate_promotion_contract_v0_1_8_synthesis.md`
- `rfc/rfc_sweep_candidate_promotion_contract_v0_1_8_synthesis_response.md`
- `rfc/rfc_sweep_promotion_context_v0_1_8.md`
- `rfc/rfc_sweep_promotion_context_v0_1_8_response.md`
- `rfc/rfc_sweep_promotion_context_v0_1_8_synthesis.md`
- `rfc/rfc_sweep_promotion_context_v0_1_8_synthesis_response.md`
- `rfc/rfc_sweep_promotion_context_v0_1_8_decision.md`
- `rfc/rfc_parallelism_spike_architecture_consequences.md`
- `rfc/rfc_parallelism_spike_architecture_consequences_response.md`
- `rfc/rfc_sweep_single_core_optimization_routes_v0_1_8.md`
- `rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_response.md`
- `rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md`
- `rfc/rfc_multi_output_indicator_ux.md`
- `rfc/rfc_multi_output_indicator_ux_response.md`
- `rfc/rfc_multi_output_indicator_ux_maintainer_response.md`
- `rfc/rfc_multi_output_indicator_ux_synthesis.md`
- `rfc/rfc_risk_free_rate_metric_context_v0_1_8_1.md`
- `rfc/rfc_risk_free_rate_metric_context_v0_1_8_1_response.md`
- `rfc/rfc_risk_free_rate_metric_context_v0_1_8_1_synthesis.md`
- `rfc/rfc_chainable_risk_oms_policy_boundary.md`
- `rfc/rfc_chainable_risk_oms_policy_boundary_response.md`
- `rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md`
- `rfc/rfc_execution_policy_pipeline_audit_signal_north_star.md`
- `rfc/rfc_ledgr_oms_seed.md`
- `rfc/rfc_ledgr_oms_seed_response.md`
- `rfc/rfc_ledgr_oms_seed_synthesis.md`
- `rfc/rfc_indicator_codebase_simplification_v0_1_8_x.md`
- `rfc/rfc_indicator_codebase_simplification_v0_1_8_x_response.md`
- `rfc/rfc_indicator_codebase_simplification_v0_1_8_x_synthesis.md`
- `rfc/rfc_strategy_authoring_parameterized_indicators_v0_1_8_x.md`
- `rfc/rfc_strategy_authoring_parameterized_indicators_v0_1_8_x_response.md`
- `rfc/rfc_active_parameterized_feature_aliases_v0_1_8_x.md`
- `rfc/rfc_active_parameterized_feature_aliases_v0_1_8_x_response.md`
- `rfc/rfc_active_parameterized_feature_aliases_v0_1_8_x_synthesis.md`
- `rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x.md`
- `rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_response.md`
- `rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`
- `rfc/rfc_pulse_context_data_model_consolidation_v0_1_8_3.md`
- `rfc/rfc_pulse_context_data_model_consolidation_v0_1_8_3_synthesis.md`
- `rfc/rfc_collapse_primitive_internals_v0_1_9.md`
- `rfc/rfc_collapse_primitive_internals_v0_1_9_response.md`
- `rfc/rfc_collapse_primitive_internals_v0_1_9_synthesis.md`
- `rfc/rfc_research_workflow_artifact_topology_v0_1_8_x.md`
- `rfc/rfc_research_workflow_artifact_topology_v0_1_8_x_synthesis.md`
- `rfc/rfc_walk_forward_evaluation_v0_1_9_x_seed.md`
- `rfc/rfc_walk_forward_evaluation_v0_1_9_x_seed_v2.md`
- `rfc/rfc_walk_forward_evaluation_v0_1_9_x_response.md`
- `rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md`

The governance RFC and response drove the completed `v0.1.8.00` prep cycle.
The cost model response is an active downstream constraint for v0.1.8 fold-core design.
The parallelism spike RFC and response are active inputs for the v0.1.8 spec.
The RNG RFC and response split v0.1.8 seed boundary work from later stochastic
strategy helpers.
The promotion RFC and response add `execution_seed` as a visible column and
establish `ledgr_candidate()` / `ledgr_promote()` as the canonical promotion API.
The promotion-context decision adds durable `run_promotion_context`
selection-audit metadata for runs promoted from sweep candidates; full sweep
artifact persistence remains future work.
The sweep optimization synthesis defines the v0.1.8.3+ single-core optimization
arc, and the accepted grid-level feature artifacts synthesis amends v0.1.8.3
to start with runtime projection and shared fold projection consumption before
any parallel or compiled-core work.
The multi-output indicator synthesis defines `ledgr_indicator_bundle` and the
`ledgr_ind_ttr_outputs()` authoring helper for v0.1.8.1.
The metric context RFC and synthesis define the `ledgr_metric_context`,
`ledgr_calendar`, and experiment-level assumption model for v0.1.8.2; the
synthesis is accepted and binding for v0.1.8.2 ticket cut.
The chainable risk/OMS synthesis accepts a narrow v0.1.9 target-risk chain and
defers order-policy, public cost/liquidity chains, tiered output retention, and
OMS semantics. The execution-policy north-star RFC carries the broader
pipeline and audit-signal discussion for v0.1.9.x/v0.2.x planning; it is not
binding implementation scope until promoted through synthesis or a future spec
packet.
The OMS seed synthesis accepts a future v0.2.x two-stream design: `order_events`
for engine-owned order lifecycle beside the existing accounting `ledger_events`
stream. Strategies remain target-vector functions, paper/live adapters remain
deferred to v0.3.0+, and intraday compatibility is preserved by binding
target-decision identity/reconstructability rather than a universal
full-JSON-per-decision storage shape.
The indicator codebase simplification synthesis accepted a Phase 1
determinism-extraction refactor completed in v0.1.8.1; the v0.1.8.2 roadmap
entry carries the Phase 2 file/role cleanup (indicator file renames plus the
`R/indicator_dev.R` split into `R/indicator-dev.R` and `R/pulse-snapshot.R`).
The strategy authoring RFC and response identify parameterized indicator
sweeps as a real strategy-authoring UX gap. The response rejects the
documentation-only convention as sufficient because calling an external feature
factory from strategy code conflicts with current preflight tiers, and points
toward a future active-alias API design before implementation ticket cut.
The active parameterized feature aliases RFC seed carries that follow-up design
space: parameter references in feature declarations, active alias lookup from
the pulse context, alias-map identity, and bundle alias semantics.
The active-alias response recommends a conservative first API pass:
`ledgr_param("name")` scalar placeholders, separate authoring declarations that
resolve to concrete indicators, active `ctx$features(id)` alias lookup, alias
maps in execution config identity, and current flat bundle aliases preserved.
The active-alias synthesis accepts a future-cycle design: constructor support
for scalar parameter references, authoring declarations that are not concrete
indicators, `ledgr_parameters()` introspection, an `alias_map_hash` provenance
layer, flat bundle semantics, and placement in the v0.1.8.4 sweep authoring
ergonomics cycle. It has been amended to inherit the v0.1.8.3 grid-level
concrete-feature-union decision, so parameterized sweep candidates share
concrete feature computation while retaining per-candidate alias identity.
The grid-level feature artifacts RFC seed explores a shared substrate for
parameterized indicator sweeps, precomputed wide feature backing,
candidate-level alias views, runtime pulse-context feature views, DuckDB-backed
research/export artifacts, and future ML training-frame support. It is a seed,
not accepted implementation scope.
The grid-level feature artifacts synthesis accepts a v0.1.8.3 scope amendment:
extend `ledgr_precompute_features()` into a shared runtime projection consumed
by both `ledgr_run()` and `ledgr_sweep()`, keep alias-map identity in
v0.1.8.4, and defer durable research/export artifacts to a future ML/export
RFC. The first projection backend is R-memory; DuckDB-backed precompute storage
and pulse-block-buffered out-of-core projection are parked in `horizon.md` as a
future scaling/storage direction, not v0.1.8.3 runtime scope.
The pulse-context data model consolidation synthesis accepts the post-LDG-2411
rescope of LDG-2413 from narrow B2 proxies to prebuilt static pulse views for
`ctx$bars`, `ctx$feature_table`, and `ctx$features_wide`, while preserving
public data-frame field semantics. LDG-2414 measures that result and informs
the maintainer decision on whether typed memory events and single-pass summary
remain in v0.1.8.3 or defer to v0.1.9.
The collapse primitive-internals synthesis promotes the LDG-2413 construction
spike lesson into v0.1.9 planning: ledgr should prefer primitive internal
shapes and treat data.frames as public boundary views. It does not add
`collapse` to v0.1.8.3 or reopen LDG-2413. The accepted v0.1.9 scope is a
developer guide, deterministic-wrapper spike, event-boundary micro-profile,
and safe cumulative-reconstruction parity spike; production use of `collapse`
waits for measured non-Phase-A value and deterministic hostile-setting parity.
The research workflow and artifact-topology synthesis accepts a v0.1.8.5
planning direction: ledgr should teach one project-local experiment store,
logical separation of sealed snapshots from derived execution artifacts,
docs-first workflow convention before scaffold API, explicit promotion notes,
future split-store triggers, future companion examples, future live data logs,
and future point-in-time regressor snapshots. It does not add runtime scope to
v0.1.8.4.
The walk-forward evaluation synthesis accepts the v0.1.9.x planning direction:
walk-forward is a wrapper over the existing `ledgr_sweep()` and `ledgr_run()`
paths, uses one sealed snapshot with calendar-time folds, records durable fold
and scalar score artifacts, preserves the strategy contract, and defers
selection-integrity diagnostics, purging/embargo, richer retention, and
paper/live interaction to later RFCs.

## Audits And Spikes

- `audits/execution_engine_audit.md` - v0.1.7.9 execution-engine audit and routing.
- `audits/v0_1_8_spec_deep_review.md` - v0.1.8 spec review and routing.
- `spikes/ledgr_parallelism_spike/` - v0.1.8 parallelism spike episode.
- `spikes/ledgr_tidyfinance_unit_probe/` - pre-RFC empirical probe of `tidyfinance` provider unit semantics for future external reference-data adapter design.

## Maintainer Review

- `maintainer_review/feature_value_path_workbook.qmd` - internal notebook for tracing
  how declared features become `ctx$feature()` values. This is a maintainer
  code-review aid, not installed user documentation or a contract.

## ADRs

ADRs live under `adr/`.

- `adr/0001-split-db-semantics.md` - snapshot and run database split.
- `adr/0002-registry-fingerprint-policy.md` - registry fingerprint policy.
- `adr/0003-closure-fingerprinting.md` - closure fingerprinting policy.

## Spec Packets

Versioned spec packets include archival release records and, when cut, the
active implementation packet. Keep them in place.

- `ledgr_v0_1_8_5_spec_packet/` - active v0.1.8.5 packet for canonical
  research workflow and teachability.
- `ledgr_v0_1_8_4_spec_packet/` - v0.1.8.4 release record for active
  parameterized feature aliases, grid helpers, and routed v0.1.8.3 auditr
  findings.
- `ledgr_v0_1_8_3_spec_packet/` - v0.1.8.3 release record for single-core
  sweep optimization and routed v0.1.8.2 auditr findings.
- `ledgr_v0_1_8_2_spec_packet/` - v0.1.8.2 release record for metric context,
  preflight classifier alignment, auditr polish, and indicator Phase 2 cleanup.
- `ledgr_v0_1_8_1_spec_packet/` - v0.1.8.1 release record.
- `ledgr_v0_1_8_0_spec_packet/` - v0.1.8 sweep/fold-core release record.
- `ledgr_v0_1_8_00_spec_packet/` - completed design-governance prep packet.
- `ledgr_v0_1_7_9_spec_packet/` - latest prior shipped release packet.
- `ledgr_v0_1_7_8_spec_packet/` and older - historical records.

Do not treat an older packet as current just because it contains detailed
instructions. Current work follows the active packet when one exists, plus the
contract index.

## Task Entry Points

| Task | Read |
| --- | --- |
| Runtime/execution change | `contracts.md`, current packet if one exists, relevant architecture note |
| Sweep/fold-core planning | `contracts.md`, `architecture/ledgr_v0_1_8_sweep_architecture.md`, `architecture/ledgr_sweep_mode_ux.md` |
| Sweep performance / optimization | `rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md`, `rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`, `rfc/rfc_pulse_context_data_model_consolidation_v0_1_8_3_synthesis.md`, `contracts.md`, current packet if one exists |
| Multi-output indicator authoring | `rfc/rfc_multi_output_indicator_ux_synthesis.md`, relevant release packet or future packet when cut |
| Indicator determinism / fingerprinting | `rfc/rfc_indicator_codebase_simplification_v0_1_8_x_synthesis.md`, relevant release packet or future packet when cut |
| Maintainer feature-path review | `maintainer_review/feature_value_path_workbook.qmd`, `R/experiment.R`, `R/precompute-features.R`, `R/fold-core.R`, `R/pulse-context.R`, `R/feature-inspection.R` |
| Metric context / risk metrics | `rfc/rfc_risk_free_rate_metric_context_v0_1_8_1_synthesis.md`, `rfc/rfc_risk_free_rate_metric_context_v0_1_8_1_response.md`, future packet when cut |
| Target risk planning | `rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md`, `contracts.md`, future packet when cut |
| Walk-forward planning | `rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md`, `rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md`, `rfc/rfc_sweep_candidate_promotion_contract_v0_1_8_synthesis.md`, `contracts.md`, future v0.1.9.x packet when cut |
| Execution policy / OMS north-star planning | `rfc/rfc_execution_policy_pipeline_audit_signal_north_star.md`, `rfc/rfc_cost_model_architecture_response.md`, `ledgr_roadmap.md` |
| Design-doc governance | `ledgr_v0_1_8_00_spec_packet/`, `rfc/rfc_design_doc_governance.md`, `rfc/rfc_design_doc_governance_response.md` |
| Release operation | `release_ci_playbook.md`, active release/closeout ticket if one exists |
| Vignette or article writing | `vignette_styleguide.md`, active packet, relevant existing article |
| Audit intake | relevant audit, current packet if one exists, tickets |
| RFC response | source RFC, related contract section, related roadmap section |
| Spike execution | spike document, current packet if one exists, architecture note that consumes results |

## Maintenance Rule

When adding, moving, renaming, or retiring a cross-cycle design document, update
this README in the same change or record why the document is intentionally not
indexed. At release gate, this README and `AGENTS.md` must both point to the
current active design context.
