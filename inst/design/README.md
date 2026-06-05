# ledgr Design Documents

**Status:** Active design index.
**Authority:** Operational map for agents and human collaborators.
**Latest completed release packet:** `v0.1.9.1`.
**Current active packet:** None. The next planned packet is v0.1.9.2 sweep
artifact persistence; RFC seed pending.
**Current active packet path:** None.
The completed `inst/design/ledgr_v0_1_9_1_spec_packet/` is an archival release
record. Do not treat it as authorization for new implementation work after the
v0.1.9.1 release gate.

This directory is the design memory for ledgr. Files here do not all have the
same authority. Use this README to decide what to read first and how much weight
to give each document.

## Start Here

For any non-trivial change, read in this order:

1. `contracts.md` - current execution, snapshot, persistence, feature, and
   strategy contracts.
2. `ledgr_roadmap.md` - milestone arc and active horizon.
3. If an active spec packet has been cut, read that packet. Otherwise use the
   latest completed packet only as release history, not as new-work
   authorization.
4. For RFC-cycle work, read `rfc_cycle.md` before drafting or reviewing a seed,
   response, synthesis, final review, or horizon entry.
5. Only the architecture, RFC, audit, or spike documents relevant to the active
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

The v0.1.9.1 packet is complete. It shipped the first public transaction-cost
API and the cost-identity surface required by later v0.1.9.x packets:
`cost_model_hash`, `cost_plan_json`, explicit `timing_model`, required
`cost_model`, cost model inspection helpers, legacy shape rejection, and
bounded auditr identity / disclaimer documentation fixes.

- Spec: `ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md`.
- Tickets: `ledgr_v0_1_9_1_spec_packet/v0_1_9_1_tickets.md`.
- Machine-readable tickets: `ledgr_v0_1_9_1_spec_packet/tickets.yml`.
- Batch plan: `ledgr_v0_1_9_1_spec_packet/batch_plan.md`.
- Identity reference:
  `manual/identity_contract.qmd` and `manual/identity_contract.md`.
- Primary synthesis:
  `rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md`.

v0.1.9.2 sweep artifact persistence, v0.1.9.3 target risk, and v0.1.9.4
walk-forward remain future packets. The cost identity fields from v0.1.9.1 are
forward dependencies for those packets; their presence here does not mark those
future layers implemented.

The v0.1.8.5 packet is complete. It delivered the canonical research workflow,
artifact-topology guidance, Quarto installed-vignette migration, README and
pkgdown reading-flow alignment, experiment-store and reproducibility guidance,
sweep and execution-semantics articles, and a canonized vignette styleguide. It
was grounded in `rfc/rfc_research_workflow_artifact_topology_v0_1_8_x_synthesis.md`.

- Spec: `ledgr_v0_1_8_5_spec_packet/v0_1_8_5_spec.md`.
- Tickets: `ledgr_v0_1_8_5_spec_packet/v0_1_8_5_tickets.md`.
- Machine-readable tickets: `ledgr_v0_1_8_5_spec_packet/tickets.yml`.
- Vignette styleguide: `vignette_styleguide.md`.
- Auditr triage:
  `ledgr_v0_1_8_5_spec_packet/ledgr_triage_report.md`,
  `ledgr_v0_1_8_5_spec_packet/categorized_feedback.yml`, and
  `ledgr_v0_1_8_5_spec_packet/cycle_retrospective.md`.

The v0.1.8.6 packet is complete. It shipped the accepted feature-projection
materialization path, structured benchmark suite, performance attribution,
storage-decision deferrals, and the v0.1.8.7 Optimization Round 2 handoff.
Snapshot administration and research-loop helper follow-up from v0.1.8.5 remain
deferred to the horizon for a later RFC/spec cycle.

- Spec: `ledgr_v0_1_8_6_spec_packet/v0_1_8_6_spec.md`.
- Primary synthesis:
  `rfc/rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md`.

Target risk, walk-forward, public cost/liquidity APIs, OMS work, live data
logs, point-in-time regressors, public benchmark dashboards, and broad collapse
adoption remain deferred unless a later active packet explicitly scopes a
bounded subset. Auditr-report bugfix intake is also deferred until a future
packet routes it.

The v0.1.8.7 packet is complete. It shipped Optimization Round 2 and explicit
legacy execution cleanup: modern execution is snapshot-backed and
function-strategy based, while raw `bars` execution, R6 strategy execution, and
run-time `data_hash` identity are removed from modern execution or fail before
fold entry. It also shipped the event-buffer/emission lane, representation/setup
cleanup, fills reconstruction/read-back cleanup, deterministic `collapse`
wrapper, and fast-sweep versus promotion/materialization artifact boundary.

- Spec: `ledgr_v0_1_8_7_spec_packet/v0_1_8_7_spec.md`.
- Tickets: `ledgr_v0_1_8_7_spec_packet/v0_1_8_7_tickets.md`.
- Machine-readable tickets: `ledgr_v0_1_8_7_spec_packet/tickets.yml`.
- Benchmark attribution:
  `ledgr_v0_1_8_7_spec_packet/benchmark_attribution_closeout.md`.
- Cycle retrospective:
  `ledgr_v0_1_8_7_spec_packet/cycle_retrospective.md`.
- Key inputs:
  `audits/fold_path_hotpath_audit.md`,
  `manual/snapshots_data.qmd` (migrated fold trust-boundary rationale),
  `collapse_optimization_map.md`,
  `spikes/ledgr_optimization_round_spike/README.md`, and
  `manual/execution_fold_core.qmd` plus
  `manual/performance_arc_v0_1_8_x.qmd` (migrated ADR-0004 rationale).

The v0.1.8.8 packet is complete. It shipped parallel sweep dispatch and
determinism, fold-core diagnostics / containment, a repo-local reproducible
peer benchmark report, and a self-profiling workload grid extension for
v0.1.8.9 optimization scoping. Sequential sweep remains the reference
implementation; parallelism is candidate dispatch over the same fold core. The
packet also binds deterministic-only resume/parallel RNG semantics with
`ctx$pulse_seed`, an internal typed execution-spec constructor, and a
mechanical fold-core split paired with documentation if behavior-neutral. The
maintainer-manual skeleton and stale-doc cleanup ticket was explicitly
deferred.

- Spec: `ledgr_v0_1_8_8_spec_packet/v0_1_8_8_spec.md`.
- Tickets: `ledgr_v0_1_8_8_spec_packet/v0_1_8_8_tickets.md`.
- Machine-readable tickets: `ledgr_v0_1_8_8_spec_packet/tickets.yml`.
- Batch plan: `ledgr_v0_1_8_8_spec_packet/batch_plan.md`.
- Release closeout: `ledgr_v0_1_8_8_spec_packet/release_closeout.md`.
- Key inputs:
  `spikes/ledgr_parallelism_spike/summary_report.md`,
  `spikes/ledgr_parallelism_spike/architecture_synthesis.md`,
  `manual/sweep.qmd`,
  `manual/execution_fold_core.qmd`, and
  `ledgr_v0_1_8_7_spec_packet/benchmark_attribution_closeout.md`.

The v0.1.8.9 packet is complete. It shipped the single-core optimization round
fed by the v0.1.8.9 spike synthesis: `collapse::setv` fixes for
scale-growing column buffers, per-pulse vectorization, yyjsonr dependency
consolidation with canonical JSON byte-format v2, and workload-grid /
peer-benchmark remeasurement.

- Spec: `ledgr_v0_1_8_9_spec_packet/v0_1_8_9_spec.md`.
- Tickets: `ledgr_v0_1_8_9_spec_packet/v0_1_8_9_tickets.md`.
- Machine-readable tickets: `ledgr_v0_1_8_9_spec_packet/tickets.yml`.
- Batch plan: `ledgr_v0_1_8_9_spec_packet/batch_plan.md`.
- Release closeout: `ledgr_v0_1_8_9_spec_packet/v0_1_8_9_release_closeout.md`.
- Primary synthesis:
  `spikes/ledgr_v0_1_8_9_optimization_round_spike/architecture_synthesis.md`.

The v0.1.8.10 packet is complete. It closed the v0.1.8.x single-core arc with
ephemeral subphase telemetry, matrix-canonical fold substrate and accepted
strategy accessors, event-preserving fold-owned FIFO accounting, yyjsonr
options hoisting, a compiled hot-frame B2 measurement gate, a scoped public
memory-backed sweep B2 spot-FIFO opt-in, and a workload-grid / peer-benchmark
measurement closeout. Events remain canonical evidence; inline accounting
facts are typed derived outputs and parity targets, not replacements for the
event stream. Default execution remains canonical R, and durable compiled
integration remains deferred.

- Spec: `ledgr_v0_1_8_10_spec_packet/v0_1_8_10_spec.md`.
- Tickets: `ledgr_v0_1_8_10_spec_packet/v0_1_8_10_tickets.md`.
- Machine-readable tickets: `ledgr_v0_1_8_10_spec_packet/tickets.yml`.
- Batch plan: `ledgr_v0_1_8_10_spec_packet/batch_plan.md`.
- Per-lane attribution:
  `ledgr_v0_1_8_10_spec_packet/per_lane_attribution.md`.
- Primary synthesis:
  `spikes/ledgr_v0_1_8_10_optimization_round_spike/architecture_synthesis.md`.

The latest completed packet is v0.1.8.11. Per the roadmap, it was a
documentation, structure, and cleanup release before v0.1.9 features. Tickets
are closed; Batch 0 packet alignment, Batch 1 `contracts.md` audit, Batch 2
planning-doc housekeeping, and Batch 3 RFC decision-index work are complete
after Claude review. Batch 4 `contracts.md` structure work is complete after
Claude review. Batch 5 maintainer-manual foundation work is complete after
Claude review. Batch 6 user-facing documentation refresh work is complete after
Claude review. Batch 7 performance arc narrative work is complete after Claude
review. Batch 8 research software disclaimer surface work is complete after
Claude review. Batch 9 generated docs and man-page audit work is complete after
Claude review. LDG-2539 was added to consume the generated-doc audit findings
and is complete after review. Batch 10 `inst/` subdirectory audit and reviewed
cleanup work is complete.
Rescoped 2026-06-04: LDG-2540 through LDG-2546 added to absorb the manual
remainder and complete the `adr/` + `architecture/` + `maintainer_review/`
directory wind-downs in v0.1.8.11 itself; no v0.1.8.12 follow-on is planned.
ADR-0005 was deleted in the 2026-06-04 structural review. Spec Section 3.7
introduces the two-layer manual article standard (Synthesis + Implementation
Trace) after a 2026-06-04 review found the first articles too
synthesis-heavy; every new manual article in this packet ships both layers,
while LDG-2546 retrofits the two existing articles.
LDG-2546 covers `execution_fold_core` and `performance_arc` and winds down
`maintainer_review/`. Batch 11 / LDG-2540 +
LDG-2541 is complete after Claude review: both new deterministic substrate
manual articles now carry Synthesis and Implementation Trace layers. Batch 14 /
LDG-2546 is complete after Claude review: existing manual articles now carry
Implementation Trace layers and `maintainer_review/` is wound down. Batch 12 /
LDG-2542 + LDG-2543 is complete after Claude review: sweep and features manual
articles now carry both layers, the architecture notes were migrated, and
`architecture/` is wound down to its README. Batch 13 / LDG-2544 + LDG-2545 is
complete after Claude review: ADR-0004 rationale is split into the manual,
`adr/` is wound down to its README, and the benchmark methodology article is in
place. Batch 15 / LDG-2537 closed the packet on 2026-06-04 and updated the
branch for merge/tag.

- Spec: `ledgr_v0_1_8_11_spec_packet/v0_1_8_11_spec.md`.
- Tickets: `ledgr_v0_1_8_11_spec_packet/v0_1_8_11_tickets.md`.
- Machine-readable tickets: `ledgr_v0_1_8_11_spec_packet/tickets.yml`.
- Batch plan: `ledgr_v0_1_8_11_spec_packet/batch_plan.md`.

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

- `manual/execution_fold_core.qmd`
- `manual/performance_arc_v0_1_8_x.qmd`
- `manual/observability_determinism.qmd`
- `manual/snapshots_data.qmd`
- `manual/features.qmd`
- `manual/sweep.qmd`
- `manual/benchmark_methodology.qmd`
- `collapse_optimization_map.md`
- `spikes/ledgr_parallelism_spike/summary_report.md`
- `spikes/ledgr_parallelism_spike/architecture_synthesis.md`
- `spikes/ledgr_optimization_round_spike/README.md`

## Accepted Design Decisions

These synthesis documents are accepted by the maintainer and binding for ticket
cut and implementation planning within their stated scope. They live in `rfc/`
as the end of their RFC thread. When a decision stabilises further it may be
extracted into a standalone architecture note in `architecture/`.

For topic-oriented lookup and ADR routing, start with `rfc/README.md`; it is an
index only and does not replace the source RFCs, final reviews, ADRs, contracts,
or versioned packet records.

| Area | Document | Scope | Status |
| --- | --- | --- | --- |
| Sweep single-core optimization arc | `rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md` | v0.1.8.3 optimization sequence | Accepted |
| Multi-output indicator bundle UX | `rfc/rfc_multi_output_indicator_ux_synthesis.md` | v0.1.8.1 bundle authoring | Accepted |
| Metric context and risk metrics | `rfc/rfc_risk_free_rate_metric_context_v0_1_8_1_synthesis.md` | v0.1.8.2 metric design | Accepted |
| Target-risk chain boundary | `rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md` | v0.1.9 target-risk planning | Accepted |
| Indicator codebase simplification | `rfc/rfc_indicator_codebase_simplification_v0_1_8_x_synthesis.md` | v0.1.8.1 Phase 1 determinism extraction; v0.1.8.2 Phase 2 file/role cleanup | Accepted |
| Active parameterized feature aliases | `rfc/rfc_active_parameterized_feature_aliases_v0_1_8_x_synthesis.md` | v0.1.8.4 sweep authoring ergonomics | Accepted |
| Research workflow and artifact topology | `rfc/rfc_research_workflow_artifact_topology_v0_1_8_x_synthesis.md` | v0.1.8.5 canonical workflow and teachability planning | Accepted |
| Feature projection shape, materialization policy, and lookback access | `rfc/rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md` | v0.1.8.6 feature-projection materialization; later lookback/export/storage gates | Accepted |
| Primitive internals and conditional collapse acceleration | `rfc/rfc_collapse_primitive_internals_v0_1_9_synthesis.md` | v0.1.9 primitive-internals planning and v0.1.9.x implementation gates | Accepted |
| Walk-forward evaluation | `rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md` (Amendment 1 + Amendment 2 + Section 17 ticket-cut gates, all 2026-06-04) | v0.1.9.x walk-forward ticket-cut planning after target risk; final review closed the cycle, Amendment 2 strengthened four procedural routings into substantive defaults, Section 17 binds packet-open and release-gate enforcement | Accepted |
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
- `rfc/rfc_feature_projection_shape_and_lookback_v0_1_8_x.md`
- `rfc/rfc_feature_projection_shape_and_lookback_v0_1_8_x_response.md`
- `rfc/rfc_feature_projection_shape_and_lookback_v0_1_8_x_seed_v2.md`
- `rfc/rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md`
- `rfc/rfc_feature_projection_shape_and_lookback_v0_1_8_x_final_review.md`
- `rfc/rfc_research_workflow_artifact_topology_v0_1_8_x.md`
- `rfc/rfc_research_workflow_artifact_topology_v0_1_8_x_synthesis.md`
- `rfc/rfc_walk_forward_evaluation_v0_1_9_x_seed.md`
- `rfc/rfc_walk_forward_evaluation_v0_1_9_x_seed_v2.md`
- `rfc/rfc_walk_forward_evaluation_v0_1_9_x_response.md`
- `rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md`
- `rfc/rfc_walk_forward_evaluation_v0_1_9_x_final_review.md`

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
paper/live interaction to later RFCs. Amendment 1 (2026-06-04) closed the
cycle by correcting the Section 3 train-fold scoring binding
(`scoring_start = train_start_utc`), binding procedural constraints on
Section 11 Open Questions 1, 5, 7, and 10, augmenting Section 10 with a
survivorship disclosure obligation and two test items, and recording a
Section 12 compute-scaling caveat. The amendment is authorized by synthesis
Section 13 and does not open a new RFC chain; the final-review artifact
carries the underlying reviewer text. Amendment 2 (2026-06-04) strengthened
four of Amendment 1's procedural routings into substantive defaults: v1
`opening_state_policy = carry_test_state` with a warned `flat_test_state`
opt-in (Section 16.2); fail-closed selection-rule behavior for level metrics
via metric-registry classification (Section 16.3); no-default extraction
with required `selection_rationale` when `"latest"` is used (Section 16.4);
an operational per-fold degradation table data contract for the default
print method (Section 16.5); and a path-dependency obligation in Section 12
(per-fold test metrics under `carry_test_state` are not statistically
independent). Section 17 (Ticket-Cut Gates) binds a two-gate matrix
(packet-open and release-gate enforcement) over every Amendment 1 and
Amendment 2 obligation. The closure rule recorded in
`inst/design/rfc_cycle.md` is now: a post-synthesis amendment that routes
only procedural constraints is insufficient closure; either substantive
defaults or named ticket-cut gates or both must land.

## Audits And Spikes

- `audits/execution_engine_audit.md` - v0.1.7.9 execution-engine audit and routing.
- `audits/v0_1_8_spec_deep_review.md` - v0.1.8 spec review and routing.
- `spikes/ledgr_parallelism_spike/` - v0.1.8 parallelism spike episode.
- `spikes/ledgr_tidyfinance_unit_probe/` - pre-RFC empirical probe of `tidyfinance` provider unit semantics for future external reference-data adapter design.

## Maintainer Review

- `maintainer_review/README.md` - wind-down policy for the retired workbook
  location. New implementation-depth notes belong in manual article
  `## Implementation Trace` sections.
- `manual/features.qmd` - maintainer manual article tracing how declared
  features become `ctx$feature()` values. It absorbed the retired feature value
  path workbook in LDG-2543.

## Maintainer Manual

- `manual/README.qmd` / `manual/README.md` - internal maintainer-manual index
  and bounded remainder.
- `manual/execution_fold_core.qmd` - first maintainer-manual article for
  execution and fold-core architecture. This is synthesis, not a replacement
  for contracts, RFCs, ADRs, architecture notes, or packet records.
- `manual/observability_determinism.qmd` - internal maintainer-manual article
  for fingerprints, closure captures, RNG determinism, telemetry, replay, and
  event evidence. This is synthesis, not a replacement for contracts.
- `manual/snapshots_data.qmd` - internal maintainer-manual article for snapshot
  sealing, split stores, fold-entry guards, and the data trust boundary. This
  is synthesis, not a replacement for contracts.

## ADRs

ADRs live under `adr/`.

See `adr/README.md` for the current ADR pattern. ADRs are wound down as a
recurring artifact; the existing files are historical records pending
migration into manual articles. Do not author new ADRs without confirming
against the three-condition bar in `adr/README.md`.

- ADR-0001 through ADR-0004 have been migrated into the maintainer manual and
  deleted. See `manual/snapshots_data.qmd`,
  `manual/observability_determinism.qmd`,
  `manual/execution_fold_core.qmd`, and
  `manual/performance_arc_v0_1_8_x.qmd`.

## Spec Packets

Versioned spec packets include archival release records and, when cut, the
active implementation packet. Keep them in place.

- `ledgr_v0_1_8_10_spec_packet/` - v0.1.8.10 release record for
  ephemeral telemetry, matrix-canonical strategy accessors, fold-owned FIFO
  accounting, yyjsonr options hoist, the scoped B2 spot-FIFO sweep opt-in, and
  measurement closeout.
- `ledgr_v0_1_8_9_spec_packet/` - v0.1.8.9 release record for
  column-buffer `setv` fixes, per-pulse vectorization, yyjsonr consolidation,
  and post-fix measurement gates.
- `ledgr_v0_1_8_8_spec_packet/` - v0.1.8.8 release record for parallel sweep
  dispatch and determinism, fold-core diagnostics / containment, repo-local
  peer benchmark reporting, and the self-profiling workload grid.
- `ledgr_v0_1_8_7_spec_packet/` - v0.1.8.7 release record for Optimization
  Round 2: legacy execution cleanup, dependency/function-strategy cleanup,
  event-emission/buffer lane, representation/setup cleanup, reconstruction
  read-back cleanup, run-artifact materialization policy, and benchmark
  attribution.
- `ledgr_v0_1_8_6_spec_packet/` - v0.1.8.6 release record for
  feature-projection materialization, structured benchmarks, performance
  attribution, storage-decision deferrals, and v0.1.8.7 optimization handoff.
- `ledgr_v0_1_8_5_spec_packet/` - v0.1.8.5 release record for canonical
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
| Runtime/execution change | `contracts.md`, current packet if one exists, relevant maintainer manual article |
| Sweep/fold-core planning | `contracts.md`, `manual/sweep.qmd`, `manual/execution_fold_core.qmd` |
| Sweep performance / optimization | `rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md`, `rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`, `rfc/rfc_pulse_context_data_model_consolidation_v0_1_8_3_synthesis.md`, `rfc/rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md`, `contracts.md`, current packet if one exists |
| Feature projection / materialization | `rfc/rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md`, `rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`, `rfc/rfc_pulse_context_data_model_consolidation_v0_1_8_3_synthesis.md`, current packet |
| Multi-output indicator authoring | `rfc/rfc_multi_output_indicator_ux_synthesis.md`, relevant release packet or future packet when cut |
| Indicator determinism / fingerprinting | `rfc/rfc_indicator_codebase_simplification_v0_1_8_x_synthesis.md`, relevant release packet or future packet when cut |
| Maintainer feature-path review | `manual/features.qmd`, `R/experiment.R`, `R/precompute-features.R`, `R/fold-engine.R`, `R/pulse-context.R`, `R/feature-inspection.R` |
| Metric context / risk metrics | `rfc/rfc_risk_free_rate_metric_context_v0_1_8_1_synthesis.md`, `rfc/rfc_risk_free_rate_metric_context_v0_1_8_1_response.md`, future packet when cut |
| Target risk planning | `rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md`, `contracts.md`, future packet when cut |
| Walk-forward planning | `rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md` (with Amendment 1 in Section 14, Amendment 2 in Section 16, ticket-cut gates in Section 17), `rfc/rfc_walk_forward_evaluation_v0_1_9_x_final_review.md` (closure update section), `rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md`, `rfc/rfc_sweep_candidate_promotion_contract_v0_1_8_synthesis.md`, `contracts.md`, future v0.1.9.x packet when cut |
| Execution policy / OMS north-star planning | `rfc/rfc_execution_policy_pipeline_audit_signal_north_star.md`, `rfc/rfc_cost_model_architecture_response.md`, `ledgr_roadmap.md` |
| Design-doc governance | `ledgr_v0_1_8_00_spec_packet/`, `rfc/rfc_design_doc_governance.md`, `rfc/rfc_design_doc_governance_response.md` |
| Release operation | `release_ci_playbook.md`, active release/closeout ticket if one exists |
| Vignette or article writing | `vignette_styleguide.md`, active packet, relevant existing article |
| Audit intake | relevant audit, current packet if one exists, tickets |
| RFC response | source RFC, related contract section, related roadmap section |
| Spike execution | spike document, current packet if one exists, maintainer manual or RFC record that consumes results |

## Maintenance Rule

When adding, moving, renaming, or retiring a cross-cycle design document, update
this README in the same change or record why the document is intentionally not
indexed. At release gate, this README and `AGENTS.md` must both point to the
current active design context.
