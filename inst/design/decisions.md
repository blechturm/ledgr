# Accepted Decisions Awaiting Consolidation

**Status:** Current bridge for accepted choices not yet consolidated into a
standing binding document.
**Authority:** Index only. The linked exact source sections bind; this file
does not restate, combine or supersede them.

Start with [contracts.md](contracts.md) for shipped behavior and preserved
internal invariants. Use this bridge only when the current answer is accepted
but still awaits consolidation. Implementation status belongs in the owning
packet's `tickets.yml`; accepted unscheduled obligations belong in the
[RFC pipeline](rfc/README.md#rfc-pipeline).

A row leaves at release closeout only when the closeout links the exact
standing-document heading that received the rule. Partial supersession keeps
every operative source section visible.

| Topic | Exact binding source sections | Missing consolidation | Pipeline row |
| --- | --- | --- | --- |
| <a id="execution-window-minimum"></a>Execution-window minimum | [v0.1.9.5 spec, Batch 1, H-1](ledgr_v0_1_9_5_spec_packet/v0_1_9_5_spec.md#batches-1a--1b--1c----correctness-prerequisites-and-stale-item-fixes) | [Execution Contract](contracts.md#execution-contract) | |
| <a id="fill-transition-validity"></a>Fill-transition validity | [v0.1.9.5 spec, Batch 1, H-2](ledgr_v0_1_9_5_spec_packet/v0_1_9_5_spec.md#batches-1a--1b--1c----correctness-prerequisites-and-stale-item-fixes) | [Execution Contract](contracts.md#execution-contract) | |
| <a id="cost-rounding-and-fees"></a>Cost rounding and fees | [v0.1.9.5 spec, Batch 2, M-7](ledgr_v0_1_9_5_spec_packet/v0_1_9_5_spec.md#batch-2----kernel-and-cost-model-hygiene) | [Execution Contract](contracts.md#execution-contract) | |
| <a id="walk-forward-snapshot-override"></a>Walk-forward snapshot override | [v0.1.9.5 spec, Batch 4](ledgr_v0_1_9_5_spec_packet/v0_1_9_5_spec.md#batch-4----candidate-generic-and-walk-forward-locator-synthesis-section-3) | [Execution Contract](contracts.md#execution-contract) | |
| <a id="point-in-time-historical-projection"></a>Point-in-time historical projection | [v11 Section 1](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md#1-decision-and-scope); [Section 3](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md#3-information-shape-and-ownership); [Section 5](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md#5-the-simple-missing-data-policy); [Section 6](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md#6-preparation-without-mandatory-revision-machinery); [Section 7](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md#7-checkpoint-disposition-and-ticket-cut-boundary); [Section 8](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md#8-contract-changes-and-detecting-requirements) | [Snapshot Contract](contracts.md#snapshot-contract), [Availability Contract](contracts.md#availability-contract), [Context Contract](contracts.md#context-contract) and [Result Contract](contracts.md#result-contract) | [Pipeline](rfc/README.md#point-in-time-historical-projection) |
| <a id="recursive-indicator-boundary"></a>Recursive-indicator history boundary | [Feature projection Direction 5.4](rfc/rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md#direction-54---lookback-primitive); [v11 Section 2](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md#2-evidence-and-the-decision-it-supports); [v11 Section 6](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md#6-preparation-without-mandatory-revision-machinery) | Future recursive-indicator synthesis, then [Context Contract](contracts.md#context-contract) | [Pipeline](rfc/README.md#recursive-indicator-semantics) |
| <a id="objective-filtered-walk-forward-identity"></a>Objective-filtered walk-forward identity | [Validation synthesis Section 6](rfc/rfc_validation_toolkit_v0_1_9_x_synthesis.md#6-d4-business-objective-enters-session-identity); [maintainer amendment Section 14](rfc/rfc_validation_toolkit_v0_1_9_x_synthesis.md#14-amendment-2026-06-26-maintainer-v0197-business-objective-promotion) | [Execution Contract](contracts.md#execution-contract) and [Result Contract](contracts.md#result-contract) when the deferred capability is implemented | [Pipeline](rfc/README.md#objective-filtered-walk-forward-identity) |
| <a id="oms-order-lifecycle"></a>OMS order lifecycle | [Target-risk synthesis Section 5](rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md#5-explicit-deferrals); [OMS synthesis Sections 3-10](rfc/rfc_ledgr_oms_seed_synthesis.md#3-accepted-architecture); [OMS minimum scope](rfc/rfc_ledgr_oms_seed_synthesis.md#12-v02x-minimum-scope) | Future OMS contract and owning implementation packet | [Pipeline](rfc/README.md#oms-order-lifecycle) |
| <a id="equity-corporate-actions"></a>Equity corporate actions | [Equity-settlement Section 2](rfc/rfc_equity_settlement_post_v0_2_0_2_synthesis.md#2-decision); [sealed facts](rfc/rfc_equity_settlement_post_v0_2_0_2_synthesis.md#32-sealed-facts); [policy](rfc/rfc_equity_settlement_post_v0_2_0_2_synthesis.md#33-policy); [account effects and maintainer posting decision](rfc/rfc_equity_settlement_post_v0_2_0_2_synthesis.md#34-account-effects); [fidelity](rfc/rfc_equity_settlement_post_v0_2_0_2_synthesis.md#35-fidelity); [capability and boundary Sections 3.6-3.8](rfc/rfc_equity_settlement_post_v0_2_0_2_synthesis.md#36-the-capability-ladder); [resolved decisions](rfc/rfc_equity_settlement_post_v0_2_0_2_synthesis.md#4-open-decisions-resolved); [release boundary](rfc/rfc_equity_settlement_post_v0_2_0_2_synthesis.md#11-release-boundary-and-final-review); [Cut 6 authority and workstream clauses](ledgr_v0_2_0_2_spec_packet/README.md#cut-6-usable-equity-corporate-actions-closed) | [Availability Contract](contracts.md#availability-contract), [Execution Contract](contracts.md#execution-contract) and [Result Contract](contracts.md#result-contract) | [Pipeline](rfc/README.md#exact-equity-quantity-settlement) |
| <a id="testing-architecture"></a>Testing architecture | [Testing synthesis Section 2](rfc/rfc_testing_architecture_v0_2_0_2_synthesis.md#2-bound-architecture); [Section 3](rfc/rfc_testing_architecture_v0_2_0_2_synthesis.md#3-the-five-open-decisions); [Section 7](rfc/rfc_testing_architecture_v0_2_0_2_synthesis.md#7-release-boundary-and-final-review) | [Verification Contract](contracts.md#verification-contract) | |
| <a id="accounting-core-consolidation"></a>Accounting-core consolidation | [Accounting synthesis Section 2](rfc/rfc_accounting_core_consolidation_v0_2_0_2_synthesis.md#2-decision); [Section 3](rfc/rfc_accounting_core_consolidation_v0_2_0_2_synthesis.md#3-bound-architecture); [Section 4](rfc/rfc_accounting_core_consolidation_v0_2_0_2_synthesis.md#4-open-decisions-resolved) | [Execution Contract](contracts.md#execution-contract) | [Pipeline](rfc/README.md#compiled-execution-envelope) |

## Migration evidence

The row-by-row disposition of both retired decision catalogues is recorded in
the packet's [decision catalogue reconciliation][reconciliation]. That
inventory is migration evidence, not another decision index.

[reconciliation]:
  ledgr_v0_2_2_spec_packet/decision_catalogue_reconciliation.md
