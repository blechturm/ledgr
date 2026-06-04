# ledgr RFC Decision Index

**Status:** Evergreen reader index.
**Authority:** Index only. Source RFCs, final reviews, ADRs, contracts, and
versioned spec packets remain authoritative.

This directory contains several kinds of RFC artifacts:

- `*_seed*.md` files are proposal drafts and design prompts.
- `*_response.md`, `*_review.md`, and maintainer-decision files are review or
  clarification artifacts for their thread.
- `*_synthesis.md` files are the accepted decision records when marked accepted
  or approved by final review.
- `*_final_review.md` files verify synthesis artifacts. They do not open new
  design space unless they explicitly route a correction back into the cycle.

Do not cite this file as replacement authority for a decision. Use it to find
the binding artifact, then cite that artifact and any final review, ADR,
contract, or spec packet listed beside it.

## Topic Decision Index

| Topic | Current binding direction | Primary authority | Review / packet / contract links |
| --- | --- | --- | --- |
| Design-governance process | RFC cycles separate seed, response, synthesis, final review, and horizon parking before ticket cut. | `rfc_design_doc_governance.md`, `rfc_design_doc_governance_response.md`, `../rfc_cycle.md` | `../README.md`, active packet records |
| Sweep candidate contract and promotion | `ledgr_sweep()` returns compact candidate rows; `ledgr_candidate()` and `ledgr_promote()` are the canonical promotion path; full sweep artifact persistence remains future work. | `rfc_sweep_candidate_promotion_contract_v0_1_8_synthesis.md`, `rfc_sweep_promotion_context_v0_1_8_synthesis.md`, `rfc_sweep_promotion_context_v0_1_8_decision.md` | `../contracts.md`, v0.1.8.0+ packet records |
| Parallel sweep dispatch | Parallelism is candidate dispatch over the same fold core, not a second execution engine. Sequential sweep remains the reference path. | `../architecture/ledgr_v0_1_8_sweep_architecture.md` (no formal synthesis; binding via architecture note plus response and packet records) | `rfc_parallelism_spike_architecture_consequences_response.md`, `../contracts.md`, v0.1.8.0+ packet records |
| Single-core optimization arc | Optimization must preserve the shared `ledgr_run()` / `ledgr_sweep()` fold core; pulse-context and reconstruction costs are shared execution costs. | `rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md` | `../ledgr_v0_1_8_7_spec_packet/`, `../ledgr_v0_1_8_9_spec_packet/`, `../ledgr_v0_1_8_10_spec_packet/` |
| Runtime projection and feature artifacts | Shared runtime projection and grid-level feature artifact consumption precede broader parallel or compiled-core work. | `rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`, `rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md` | `../contracts.md`, v0.1.8.6+ packet records |
| Pulse-context data model | Consolidated pulse views and feature access must preserve no-lookahead and public data-frame/tibble boundaries. | `rfc_pulse_context_data_model_consolidation_v0_1_8_3_synthesis.md` | `../contracts.md`, `../architecture/fold_core_trust_boundary.md` |
| Snapshot trust boundary | Production fold entry is guarded by sealed snapshots; primitive fold hot paths trust normalized snapshot inputs after the boundary check. | `../architecture/fold_core_trust_boundary.md` | `../adr/0001-split-db-semantics.md`, `../adr/0003-closure-fingerprinting.md`, `../contracts.md` |
| Strategy callback accessor addendum | Existing scalar helpers remain first-class; the high-throughput path is `ctx$vec`, `ctx$idx()`, and `ctx$vec$feature(feature_id)`. | `rfc_strategy_callback_contract_addendum_v0_1_8_10_synthesis.md` | `rfc_strategy_callback_contract_addendum_v0_1_8_10_final_review.md`, `../ledgr_v0_1_8_10_spec_packet/`, `../contracts.md` |
| Strategy authoring helpers | Internal optimization can consume `ctx$vec`; later public helper extensions such as `ledgr_target` remain v0.1.9.x scope. | `rfc_strategy_authoring_helpers_v0_1_8_x_synthesis.md` | `rfc_strategy_authoring_helpers_v0_1_8_x_final_review.md`, `../horizon.md` |
| Active parameterized feature aliases | Parameter references in feature declarations and alias-map identity are accepted future-cycle direction, not ad hoc strategy-code conventions. | `rfc_active_parameterized_feature_aliases_v0_1_8_x_synthesis.md` | v0.1.8.4 packet records, `../contracts.md` |
| Multi-output indicator UX | Multi-output bundles use `ledgr_indicator_bundle` and related authoring helpers rather than bespoke per-output hacks. | `rfc_multi_output_indicator_ux_synthesis.md` | v0.1.8.1 packet records |
| Indicator simplification and determinism | Indicator determinism extraction and later file/role cleanup are separate phases. | `rfc_indicator_codebase_simplification_v0_1_8_x_synthesis.md` | v0.1.8.1 and v0.1.8.2 packet records |
| Primitive internals and collapse | Prefer primitive internal runtime state with centralized public-boundary conversion; `collapse` is conditional acceleration behind determinism gates. | `rfc_collapse_primitive_internals_v0_1_9_synthesis.md` | `../adr/0004-dependency-footprint-and-strategy-interface.md`, v0.1.8.7+ packet records |
| B2 compiled hot frame | B2 is a production-parity measurement gate and scoped spot-FIFO accelerator path. Public opt-in is authorized only for memory-backed sweep spot-FIFO; durable compiled integration, non-spot accounting, and default compiled execution remain deferred. | `rfc_compiled_hot_frame_b2_v0_1_9_x_synthesis.md`, `rfc_compiled_hot_frame_b2_v0_1_9_x_maintainer_decisions.md` (Decision 2 narrowing) | `rfc_compiled_hot_frame_b2_v0_1_9_x_final_review.md`, `../horizon.md` (2026-06-02 `[architecture]` scope guard), `../ledgr_v0_1_8_10_spec_packet/`, `../contracts.md` |
| Public transaction-cost model | Public cost/liquidity API expansion remains downstream; current B2 scope keeps user cost resolvers in R. | `rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md` | `../ledgr_v0_1_8_10_spec_packet/`, `../horizon.md` |
| Metric context and risk-free assumptions | Metric context, calendar, and experiment-level assumptions are explicit model inputs. | `rfc_risk_free_rate_metric_context_v0_1_8_1_synthesis.md` | v0.1.8.2 packet records, `../contracts.md` |
| Target-risk / OMS policy boundary | v0.1.9 target-risk is a narrow chain; OMS, public cost/liquidity chains, and tiered output retention remain deferred. | `rfc_chainable_risk_oms_policy_boundary_synthesis.md` | `../ledgr_roadmap.md`, `../horizon.md` |
| OMS order lifecycle | Future OMS uses an order-event stream beside accounting events; strategies remain target-vector functions; paper/live remains deferred. | `rfc_ledgr_oms_seed_synthesis.md` | `../horizon.md`, future v0.2.x packet |
| Walk-forward evaluation | Walk-forward ticket cut waits until target risk is available and must preserve snapshot lineage and run identity. | `rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md` | `../ledgr_roadmap.md`, `../horizon.md` |
| Research workflow topology | Canonical research workflow and artifact topology are teaching/discoverability work, not execution semantics. | `rfc_research_workflow_artifact_topology_v0_1_8_x_synthesis.md` | v0.1.8.5 packet records, v0.1.8.11 documentation packet |

## ADR Routing

This table records the Batch 3 / LDG-2530 routing decision for stable
architectural candidates. "Keep as RFC" means no ADR is created in this batch;
the cited RFC, final review, packet, and contract remain the binding source.

| Candidate | Routing | Current authority | Reason and next trigger |
| --- | --- | --- | --- |
| B2 spot-FIFO scope guard | ADR-now (2026-06-03) → wound down (2026-06-04). | `../horizon.md` (2026-06-02 `[architecture]` B2 spot-FIFO accelerator scope guard), `rfc_compiled_hot_frame_b2_v0_1_9_x_synthesis.md`, `rfc_compiled_hot_frame_b2_v0_1_9_x_maintainer_decisions.md` (Decision 2 narrowing), `rfc_compiled_hot_frame_b2_v0_1_9_x_final_review.md`, `../ledgr_v0_1_8_10_spec_packet/`, `../contracts.md`, `../adr/README.md` | LDG-2530 promoted B2 to ADR-0005. Structural review (2026-06-04) found ADR-0005 was shape-wise a horizon scope-guard entry, redundant with the existing horizon entry + maintainer-decisions narrowing + `contracts.md`. ADR-0005 deprecated; the constraint is bound by the horizon entry + maintainer-decisions + contract. Reopen only through a future RFC that proposes durable compiled integration, non-spot compiled accounting, another compiled accounting model, or default compiled execution. |
| Canonical R default execution | Keep as contract and v0.1.8.10 packet authority. | `../contracts.md`, `../ledgr_v0_1_8_10_spec_packet/v0_1_8_10_spec.md`, B2 synthesis / final review | The default is stable but already pinned in the public contract and release packet. Create an ADR only if a future proposal tries to change the default away from canonical R. |
| Matrix-canonical strategy accessor contract | Keep as RFC plus contracts. | `rfc_strategy_callback_contract_addendum_v0_1_8_10_synthesis.md`, `rfc_strategy_callback_contract_addendum_v0_1_8_10_final_review.md`, `../contracts.md` | This is an additive context/accessor contract rather than a cross-cutting platform choice. Create an ADR only if a future refactor changes public strategy-authoring shape or helper ownership. |
| Fold-owned FIFO accounting boundary | Keep as v0.1.8.10 architecture / packet / contract authority. | `../spikes/ledgr_v0_1_8_10_optimization_round_spike/architecture_synthesis.md`, `../ledgr_v0_1_8_10_spec_packet/v0_1_8_10_spec.md`, `../contracts.md` | The boundary is stable for current spot-asset accounting. Create an ADR only when a future cycle widens accounting semantics, changes event ownership, or introduces durable compiled accounting. |

## Historical And Scaffolding Artifacts

The following artifact classes are useful for provenance but should not be used
as final authority when a synthesis or final review exists:

- seed drafts (`*_seed.md`, `*_seed_v2.md`, `*_seed_v3.md`);
- review prompts and response artifacts (`*_response.md`, `*_review.md`);
- maintainer-decision notes that were later consumed by a synthesis;
- topic seeds without synthesis, unless a later roadmap/spec explicitly names
  them as active planning inputs.

Some threads have no formal synthesis, or have a maintainer-decision artifact
that explicitly narrows or extends an accepted synthesis. In those cases the
topic table names the binding artifact directly: often an architecture note, a
maintainer-decisions file, an ADR, or a versioned spec packet. A response or
seed alone is not authority unless a later architecture note, packet, contract,
or ADR carries it forward.

When cutting tickets, prefer the accepted synthesis and final review, then
check the versioned spec packet and `../contracts.md` for current scope
boundaries.
