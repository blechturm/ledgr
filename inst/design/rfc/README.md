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

## RFC Pipeline

Forward-looking state of owed and in-flight RFC cycles. The Topic Decision
Index below records what is bound; this table records what is pending. One
row per cycle or cluster. `inst/design/horizon.md` remains authoritative for
full scope, routing, and non-commitments; this table is the thirty-second
overview.

**States:** `in-flight` (cycle open, next stage named) | `due` (recorded
trigger has fired, seed unwritten) | `gate without seed` (named as a
predecessor by other planned work, never scoped -- the dangerous state) |
`parked` (horizon entry with trigger not yet fired) | `parked (seed
staged)` (seed pre-written as design preservation; cycle deliberately
not opened).

| Cycle / cluster | State | Next step / trigger | Staged inputs | Authority |
| --- | --- | --- | --- | --- |
| Shorting / leverage contract | **gate without seed** | Write the seed-shape before v0.2.x Palomar constraint scoping opens. Must bind: short-proceeds cash treatment, borrow availability/cost (depends on accrual events row), equity margin vs derivatives arc, `risk_long_only` defaulting. | Gap 4 of the 2026-06-11 strategy-family gaps entry | horizon 2026-06-11 `[strategy]` gaps entry; gate references in the 2026-06-01 strategy-callback and 2026-06-09 Palomar-constraint entries |
| Ragged universe / asset lifetime | **gate without seed** | v0.2.x-v0.3.0; "direction B; needs a dedicated RFC". The largest research-validity gap vs peer frameworks; blocks broad-equity universes with delistings. | none staged | horizon 2026-05-28 `[data]` live bad-data / sim-to-real entry (direction B) |
| Accounting-critical event types (now incl. time-accrual costs: interest, borrow, funding) | **gate without seed** | v0.2.x; the crypto-readiness spike and the shorting contract RFC must both name it as a dependency when they open. | Gap 3 routing in the 2026-06-11 gaps entry | horizon 2026-06-11 `[strategy]` gaps entry; v0.2.x roadmap row |
| Benchmark context | parked (research slot reserved) | v0.2.x; run the deep-research pass at cycle open. | reserved filename `../research/Benchmark-Methodology.md` | horizon 2026-05-24 beta / external-benchmark entries |
| Multi-asset trade definitions | parked (research slot reserved) | v0.2.x, with non-spot accounting. | reserved filename `../research/Trade-Accounting-Definitions.md` | `../research/README.md` future slots table |
| Strategy schedule decorator ("hold until the next date") | parked (seed staged, 2026-06-12) | Cycle opens when its proposed window approaches: a small "schedule decorator + Pass 2 helpers" authoring tick after v0.1.9.5 (MD-1). Response stage then verifies the decision-mask mechanism against `R/execution-spec.R` and the resume path. | seed (standalone, incl. ecosystem survey and the Section 5 mechanism options); horizon weight-strategy entry 2026-06-12 status update | `rfc_strategy_schedule_decorator_v0_1_9_x_seed.md` |
| Portfolio-construction cluster: weight-strategy wrapper -> optimization scaffolding -> Palomar constraint expansion -> adapter family | parked | v0.2.x; scaffolding must be scoped before any adapter is selected; constraint expansion is half-gated on the shorting contract row. | 2026-06-07/09 horizon entries; `../methodology_references.md` Palomar section; adapter candidates incl. 2026-06-11 status update (RiskPortfolios, NMOF, parma, estimator category) | horizon 2026-06-07 `[planning]` scaffolding + 2026-06-09 `[risk]`/`[ux]`/`[adapters]` entries |
| Execution-policy cluster: order policy (now incl. intra-bar protective exits), liquidity/capacity, OMS implementation, cost-model post-direction (~10 recorded future-RFC obligations) | parked (north star bound) | v0.2.x; concrete RFCs instantiate pipeline stages. | `rfc_execution_policy_pipeline_audit_signal_north_star.md`; `rfc_ledgr_oms_seed_synthesis.md`; cost synthesis deferral lists; Gap 1 routing | north-star RFC + horizon 2026-05-25/27 execution entries + 2026-06-11 gaps entry |
| Data cluster: PIT regressor snapshots (one unified RFC), corporate actions / instrument master, snapshot administration, snapshot lineage | parked | v0.2.x. | partial seed-shape for snapshot administration recorded in horizon | horizon 2026-05-25/26/27 data + infrastructure entries |
| ML / cross-sectional cluster: ML-first shape, cross-sectional indicators, multi-strategy allocation | parked | v0.2.x. | 2026-06-09 entries; Peterson multi-strategy entry | horizon 2026-06-09 `[research]` entries |
| Evaluation cluster remainder: post-sweep clustering, randomized/blocked slice diagnostics, selection-session registry, hypothesis recording, walk-forward post-direction | parked | After the validation-toolkit cycle binds the diagnostics substrate. | 2026-06-07/09 entries; walk-forward synthesis future obligations | horizon entries cited per item |
| Accounting cluster remainder: non-spot models (futures/margin/options/FX), lot-selection / tax-aware policies | parked | v0.2.x derivatives arc; lot-selection routed 2026-06-11 (Gap 2). | closed `compiled_accounting_model` enum reserves the seam | horizon v0.2.x rows + 2026-06-11 gaps entry |

Maintenance rule: update a row when its cycle opens (state -> in-flight with
artifact links), when a gate's seed lands (move toward in-flight), or when a
synthesis is accepted (delete the row; the Topic Decision Index takes over).
Non-RFC debt (audit findings, vignette work, contracts passes, release
gates) is tracked in `../horizon.md` and the roadmap, not here.

## Topic Decision Index

| Topic | Current binding direction | Primary authority | Review / packet / contract links |
| --- | --- | --- | --- |
| Design-governance process | RFC cycles separate seed, response, synthesis, final review, and horizon parking before ticket cut. | `rfc_design_doc_governance.md`, `rfc_design_doc_governance_response.md`, `../rfc_cycle.md` | `../README.md`, active packet records |
| Sweep candidate contract and promotion | `ledgr_sweep()` returns compact candidate rows; `ledgr_candidate()` and `ledgr_promote()` are the canonical promotion path; v0.1.9.2 adds compact saved-sweep artifacts and retained net return series without adding per-candidate committed-run artifacts. | `rfc_sweep_candidate_promotion_contract_v0_1_8_synthesis.md`, `rfc_sweep_promotion_context_v0_1_8_synthesis.md`, `rfc_sweep_promotion_context_v0_1_8_decision.md`, `rfc_sweep_artifact_persistence_v0_1_9_x_synthesis.md` | `../contracts.md`, v0.1.8.0+ and v0.1.9.2 packet records |
| Parallel sweep dispatch | Parallelism is candidate dispatch over the same fold core, not a second execution engine. Sequential sweep remains the reference path. | `../manual/sweep.qmd` | `rfc_parallelism_spike_architecture_consequences_response.md`, `../contracts.md`, v0.1.8.0+ packet records |
| Single-core optimization arc | Optimization must preserve the shared `ledgr_run()` / `ledgr_sweep()` fold core; pulse-context and reconstruction costs are shared execution costs. | `rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md` | `../ledgr_v0_1_8_7_spec_packet/`, `../ledgr_v0_1_8_9_spec_packet/`, `../ledgr_v0_1_8_10_spec_packet/` |
| Runtime projection and feature artifacts | Shared runtime projection and grid-level feature artifact consumption precede broader parallel or compiled-core work. | `rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`, `rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md` | `../contracts.md`, v0.1.8.6+ packet records |
| Pulse-context data model | Consolidated pulse views and feature access must preserve no-lookahead and public data-frame/tibble boundaries. | `rfc_pulse_context_data_model_consolidation_v0_1_8_3_synthesis.md` | `../contracts.md`, `../manual/snapshots_data.qmd` |
| Snapshot trust boundary | Production fold entry is guarded by sealed snapshots; primitive fold hot paths trust normalized snapshot inputs after the boundary check. | `../manual/snapshots_data.qmd` | `../contracts.md`, `../manual/execution_fold_core.qmd` |
| Strategy callback accessor addendum | Existing scalar helpers remain first-class; the high-throughput path is `ctx$vec`, `ctx$idx()`, and `ctx$vec$feature(feature_id)`. | `rfc_strategy_callback_contract_addendum_v0_1_8_10_synthesis.md` | `rfc_strategy_callback_contract_addendum_v0_1_8_10_final_review.md`, `../ledgr_v0_1_8_10_spec_packet/`, `../contracts.md` |
| Strategy authoring helpers | Internal optimization can consume `ctx$vec`; later public helper extensions such as `ledgr_target` remain v0.1.9.x scope. | `rfc_strategy_authoring_helpers_v0_1_8_x_synthesis.md` | `rfc_strategy_authoring_helpers_v0_1_8_x_final_review.md`, `../horizon.md` |
| Active parameterized feature aliases | Parameter references in feature declarations and alias-map identity are accepted future-cycle direction, not ad hoc strategy-code conventions. | `rfc_active_parameterized_feature_aliases_v0_1_8_x_synthesis.md` | v0.1.8.4 packet records, `../contracts.md` |
| Multi-output indicator UX | Multi-output bundles use `ledgr_indicator_bundle` and related authoring helpers rather than bespoke per-output hacks. | `rfc_multi_output_indicator_ux_synthesis.md` | v0.1.8.1 packet records |
| Indicator simplification and determinism | Indicator determinism extraction and later file/role cleanup are separate phases. | `rfc_indicator_codebase_simplification_v0_1_8_x_synthesis.md` | v0.1.8.1 and v0.1.8.2 packet records |
| Primitive internals and collapse | Prefer primitive internal runtime state with centralized public-boundary conversion; `collapse` is conditional acceleration behind determinism gates. | `rfc_collapse_primitive_internals_v0_1_9_synthesis.md` | `../manual/performance_arc_v0_1_8_x.qmd`, v0.1.8.7+ packet records |
| B2 compiled hot frame | B2 is a production-parity measurement gate and scoped spot-FIFO accelerator path. Public opt-in is authorized only for memory-backed sweep spot-FIFO; durable compiled integration, non-spot accounting, and default compiled execution remain deferred. | `rfc_compiled_hot_frame_b2_v0_1_9_x_synthesis.md`, `rfc_compiled_hot_frame_b2_v0_1_9_x_maintainer_decisions.md` (Decision 2 narrowing) | `rfc_compiled_hot_frame_b2_v0_1_9_x_final_review.md`, `../horizon.md` (2026-06-02 `[architecture]` scope guard), `../ledgr_v0_1_8_10_spec_packet/`, `../contracts.md` |
| API naming consistency and surface tightening | v0.1.9.5 is a no-alias hard-rename and surface-tightening release before the teaching-documentation batches. It binds R1-R7, a closed verb-first allowlist, `ledgr_ind_*` constructor vs `ledgr_indicator_*` infrastructure semantics, the final rename/unexport table, walk-forward candidate locator/override rules, a same-release `contracts.md` rework, M-8 as a before-or-with rename prerequisite, and Recovery docs for the low-level recovery pair. | `rfc_api_naming_consistency_v0_1_9_5_synthesis.md` | `rfc_api_naming_consistency_v0_1_9_5_final_review.md`, `tests/testthat/test-api-exports.R`, `../contracts.md`, future v0.1.9.5 packet |
| Validation toolkit (selection-integrity diagnostics + business-objective constructor) | v0.1.9.6 ships the bundled toolkit, adapter-first: DSR / MinTRL / K-Ratio native from primary literature; sweep-level PBO/CSCV over retained completed-candidate panels (A-prime) with fail-closed panel-hygiene gates; deterministic hierarchical candidate clustering as the effective-trial-count input; `ledgr_business_objective()` with all-pass composition, the required per-criterion tear-down table, and `ledgr_objective_*` steps (criterion 2 = closed-trade realized-P&L concentration; risk = max_drawdown only); the objective enters walk-forward session identity via a conditional payload key (omitted when absent, byte-identity regression gate). Session-object persistence only; PA extends the existing Suggests boundary; MIT core with no GPL/AGPL code transfer. Per-fold train-sweep PBO and `fold_seq` retention stay parked in horizon (2026-06-12 `[evaluation]`). | `rfc_validation_toolkit_v0_1_9_x_synthesis.md` (accepted 2026-06-12) | `rfc_validation_toolkit_v0_1_9_x_final_review.md`, `rfc_validation_toolkit_v0_1_9_x_seed_v2.md` (D1-D4 in-line), `../research/Validation-Toolkit.md`, `../ledgr_roadmap.md` v0.1.9.6 row, future v0.1.9.6 packet |
| Public transaction-cost model | v0.1.9.1 implements the first public transaction-cost API: classed cost-model constructors, ordered cost chains, explicit timing model, required `cost_model`, cost identity (`cost_model_hash`, `cost_plan_json`), and legacy-shape rejection. Liquidity, quantity mutation, broker templates, and function-valued user models remain downstream. | `rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md` | `../ledgr_v0_1_9_1_spec_packet/`, `../contracts.md`, `../manual/identity_contract.qmd`, `../horizon.md` |
| Metric context and risk-free assumptions | Metric context, calendar, and experiment-level assumptions are explicit model inputs. | `rfc_risk_free_rate_metric_context_v0_1_8_1_synthesis.md` | v0.1.8.2 packet records, `../contracts.md` |
| Target-risk / OMS policy boundary | v0.1.9 target-risk is a narrow chain; OMS, public cost/liquidity chains, and tiered output retention remain deferred. | `rfc_chainable_risk_oms_policy_boundary_synthesis.md` | `../ledgr_roadmap.md`, `../horizon.md` |
| OMS order lifecycle | Future OMS uses an order-event stream beside accounting events; strategies remain target-vector functions; paper/live remains deferred. | `rfc_ledgr_oms_seed_synthesis.md` | `../horizon.md`, future v0.2.x packet |
| Walk-forward evaluation | Walk-forward ticket cut waits until target risk is available and must preserve snapshot lineage and run identity. v1 is a wrapper over `ledgr_sweep()` + `ledgr_run()` with per-fold scalar score matrix; selection-integrity diagnostics, purging/embargo, and richer retention are deferred. Amendment 2 binds v1 `opening_state_policy = carry_test_state`, fail-closed selection on level metrics, no-default extraction with `selection_rationale` required when `"latest"` is used, and an operational per-fold degradation table for the default print method. Section 17 ticket-cut gate matrix enforces all Amendment 1 and Amendment 2 obligations at packet-open and release-gate review. | `rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md` (with Amendment 1 in Section 14, Amendment 2 in Section 16, ticket-cut gates in Section 17; all dated 2026-06-04) | `rfc_walk_forward_evaluation_v0_1_9_x_final_review.md` (closure update), `../ledgr_roadmap.md`, `../horizon.md`, `../rfc_cycle.md` |
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
