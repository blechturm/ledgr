# Accepted Decisions Awaiting Consolidation

**Role:** living
**Status:** working
**Authority:** Index only. The linked exact source sections bind; this file
does not restate, combine or supersede them.
**Purpose:** Bridge accepted pending decisions to their exact sources,
implementation owners and affected current contract groups.

Start with [contracts.md](contracts.md) for shipped behavior and preserved
internal invariants. Use this bridge only when the current answer is accepted
but still awaits implementation or consolidation. Implementation status belongs
in the owning packet's `tickets.yml`; accepted unscheduled obligations belong
in the [RFC pipeline](rfc/README.md#rfc-pipeline).

A row leaves when its shipped behavior is stated by the named contract groups
and its history remains recoverable, or when ownership moves exactly once to a
ticket or pipeline row. Partial supersession keeps every operative source
section visible. The [Workstream 33 reconciliation][ws33] records the complete
pre-change population and every exit.

| Topic | Exact binding source sections | Current owner | Affected contract rule groups | Pipeline row |
| --- | --- | --- | --- | --- |
| <a id="point-in-time-historical-projection"></a>Point-in-time historical projection | [v11 Section 1](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md#1-decision-and-scope); [Section 3](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md#3-information-shape-and-ownership); [Section 5](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md#5-the-simple-missing-data-policy); [Section 6](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md#6-preparation-without-mandatory-revision-machinery); [Section 7](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md#7-checkpoint-disposition-and-ticket-cut-boundary); [Section 8](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md#8-contract-changes-and-detecting-requirements) | History-wave RFC amendment, then its implementation cut | [Snapshot facts](contracts.md#contract-snapshot-point-in-time-facts); [availability provider and timing](contracts.md#contract-availability-provider-and-timing); [context pulse data](contracts.md#contract-context-pulse-data); [result reads](contracts.md#contract-result-read-surfaces) | [Pipeline](rfc/README.md#point-in-time-historical-projection) |
| <a id="recursive-indicator-boundary"></a>Recursive-indicator history boundary | [Feature projection Direction 5.4](rfc/rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md#direction-54---lookback-primitive); [v11 Section 2](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md#2-evidence-and-the-decision-it-supports); [v11 Section 6](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md#6-preparation-without-mandatory-revision-machinery) | History-wave RFC amendment and recursive-indicator synthesis | [Indicator computation](contracts.md#contract-context-indicator-computation); [strict features](contracts.md#contract-context-strict-features) | [Pipeline](rfc/README.md#recursive-indicator-semantics) |
| <a id="objective-filtered-walk-forward-identity"></a>Objective-filtered walk-forward identity | [Validation synthesis Section 6](rfc/rfc_validation_toolkit_v0_1_9_x_synthesis.md#6-d4-business-objective-enters-session-identity); [maintainer amendment Section 14](rfc/rfc_validation_toolkit_v0_1_9_x_synthesis.md#14-amendment-2026-06-26-maintainer-v0197-business-objective-promotion) | Future business-objective completion RFC and implementation packet | [Execution identity](contracts.md#contract-execution-identity); [business objectives](contracts.md#contract-result-business-objectives) | [Pipeline](rfc/README.md#objective-filtered-walk-forward-identity) |
| <a id="oms-order-lifecycle"></a>OMS order lifecycle | [Target-risk synthesis Section 5](rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md#5-explicit-deferrals); [OMS synthesis Sections 3-10](rfc/rfc_ledgr_oms_seed_synthesis.md#3-accepted-architecture); [OMS minimum scope](rfc/rfc_ledgr_oms_seed_synthesis.md#12-v02x-minimum-scope) | Future OMS contract and owning implementation packet | [Entry points](contracts.md#contract-execution-entry-points); [target risk](contracts.md#contract-execution-target-risk); [accounting events](contracts.md#contract-execution-accounting-events) | [Pipeline](rfc/README.md#oms-order-lifecycle) |

## Migration evidence

The row-by-row disposition of both retired decision catalogues is recorded in
the packet's [decision catalogue reconciliation][catalogue]. The Workstream 33
reconciliation records this bridge's complete fifteen-row pre-change
population. Those inventories are migration evidence, not another decision
index.

[catalogue]:
  ledgr_v0_2_2_spec_packet/decision_catalogue_reconciliation.md
[ws33]:
  ledgr_v0_2_2_spec_packet/current_contract_reconciliation.md#decision-bridge-reconciliation
