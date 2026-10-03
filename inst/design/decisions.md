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
| <a id="point-in-time-historical-projection"></a>Point-in-time historical projection | [v11 Section 1](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md#1-decision-and-scope); [Section 3](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md#3-information-shape-and-ownership); [Section 5](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md#5-the-simple-missing-data-policy); [Section 6](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md#6-preparation-without-mandatory-revision-machinery); [Section 7](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md#7-checkpoint-disposition-and-ticket-cut-boundary); [Section 8](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md#8-contract-changes-and-detecting-requirements) | [Snapshot Contract](contracts.md#snapshot-contract), [Availability Contract](contracts.md#availability-contract), [Context Contract](contracts.md#context-contract) and [Result Contract](contracts.md#result-contract) | [Point-in-time historical projection](rfc/README.md#rfc-pipeline) |
| <a id="recursive-indicator-boundary"></a>Recursive-indicator history boundary | [Feature projection Direction 5.4](rfc/rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md#direction-54---lookback-primitive); [v11 Section 3](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md#3-information-shape-and-ownership); [v11 Section 9](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md#9-deferred-work-and-reopening) | Future recursive-indicator synthesis, then [Context Contract](contracts.md#context-contract) | [Recursive indicator history, readiness, gaps and causality](rfc/README.md#rfc-pipeline) |
| <a id="objective-filtered-walk-forward-identity"></a>Objective-filtered walk-forward identity | [Validation synthesis Section 6](rfc/rfc_validation_toolkit_v0_1_9_x_synthesis.md#6-d4-business-objective-enters-session-identity); [maintainer amendment Section 14](rfc/rfc_validation_toolkit_v0_1_9_x_synthesis.md#14-amendment-2026-06-26-maintainer-v0197-business-objective-promotion) | [Execution Contract](contracts.md#execution-contract) and [Result Contract](contracts.md#result-contract) when the deferred capability is implemented | |
| <a id="oms-order-lifecycle"></a>OMS order lifecycle | [Target-risk synthesis Section 5](rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md#5-explicit-deferrals); [OMS synthesis Sections 3-10](rfc/rfc_ledgr_oms_seed_synthesis.md#3-accepted-architecture); [OMS minimum scope](rfc/rfc_ledgr_oms_seed_synthesis.md#12-v02x-minimum-scope) | Future OMS contract and owning implementation packet | [Execution-policy cluster](rfc/README.md#rfc-pipeline) |

## Migration evidence

The row-by-row disposition of both retired decision catalogues is recorded in
[decision_catalogue_reconciliation.md](ledgr_v0_2_2_spec_packet/decision_catalogue_reconciliation.md).
That inventory is migration evidence, not another decision index.
