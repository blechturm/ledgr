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

Ordinarily, a row leaves only at release closeout, when the exact receiving
rule group is recorded. The governance-lifecycle synthesis Section 4 gives
Workstream 33 one-time authority to close already-consolidated rows with that
same proof; it is not a general early-exit rule. Partial supersession keeps
every operative source section visible. The [Workstream 33
reconciliation][ws33] records the complete pre-change population and every
authorized exit.

| Topic | Exact binding source sections | Current owner | Affected contract rule groups | Pipeline or ticket route |
| --- | --- | --- | --- | --- |
| <a id="point-in-time-historical-projection"></a>Point-in-time historical projection | [Accepted v12 Sections 1-10](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v12.md), as narrowed by the [accepted ordinary-history manifestation amendment](rfc/rfc_point_in_time_historical_projection_v0_2_x_manifestation_amendment.md); [receiver map](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v12.md#supersession-and-receiver-map) | Cut 19 LDG-3105, then LDG-3104 | [Snapshot facts](contracts.md#contract-snapshot-point-in-time-facts); [config policies](contracts.md#contract-config-policies); [availability activation](contracts.md#contract-availability-activation-and-calendar); [units and universe](contracts.md#contract-availability-units-and-universe); [availability provider and timing](contracts.md#contract-availability-provider-and-timing); [pulse data](contracts.md#contract-context-pulse-data); [inspection](contracts.md#contract-context-inspection); [fold core](contracts.md#contract-execution-fold-core); [window start](contracts.md#contract-execution-window-start); [walk-forward](contracts.md#contract-execution-walk-forward-folds); [event staging](contracts.md#contract-execution-event-staging); [execution identity](contracts.md#contract-execution-identity); [config construction](contracts.md#contract-config-construction); [snapshot identity](contracts.md#contract-snapshot-identity-and-verification); [current format](contracts.md#contract-persistence-current-format); [strategy outputs](contracts.md#contract-strategy-outputs); [decision axis](contracts.md#contract-strategy-decision-axis); [result reads](contracts.md#contract-result-read-surfaces); [return panels](contracts.md#contract-result-return-panels); [fills and sweep restoration](contracts.md#contract-result-fills-and-sweep-restoration); [release gates](contracts.md#contract-verification-release-gates); [store and codebase gates](contracts.md#contract-verification-store-and-codebase-gates); [strategy-context teaching](contracts.md#contract-documentation-strategy-context) | [Pipeline](rfc/README.md#history-manifestation) |
| <a id="recursive-indicator-boundary"></a>Recursive-indicator history boundary | [Accepted v12 Sections 5-7 and 10](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v12.md); [Feature projection Direction 5.4](rfc/rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md#direction-54---lookback-primitive) remains derivation | v0.2.2 history implementation cut, indicator workstream | [Indicator computation](contracts.md#contract-context-indicator-computation); [strict features](contracts.md#contract-context-strict-features); [TTR adapter](contracts.md#contract-context-ttr-adapter); [feature path](contracts.md#contract-context-feature-path); [indicator teaching](contracts.md#contract-documentation-indicators) | [History-wave pipeline](rfc/README.md#point-in-time-historical-projection); [redirect](rfc/README.md#recursive-indicator-semantics) |
| <a id="strategy-scheduler"></a>Strategy schedule decorator and held-pulse skipping | [Accepted synthesis Sections 2-9](rfc/rfc_strategy_schedule_decorator_v0_1_9_x_synthesis.md#2-bound-public-model); [maintainer decisions](rfc/rfc_strategy_schedule_decorator_v0_1_9_x_maintainer_decisions.md) | Cut 21 Workstreams 60-63, LDG-3109 through LDG-3114 | [Entry points](contracts.md#contract-execution-entry-points); [fold core](contracts.md#contract-execution-fold-core); [execution identity](contracts.md#contract-execution-identity); [config construction](contracts.md#contract-config-construction); [current format](contracts.md#contract-persistence-current-format); [strategy outputs](contracts.md#contract-strategy-outputs); [decision axis](contracts.md#contract-strategy-decision-axis); [result reads](contracts.md#contract-result-read-surfaces); [strategy-context teaching](contracts.md#contract-documentation-strategy-context) | [Cut 21 tickets](ledgr_v0_2_2_spec_packet/tickets.yml) |
| <a id="objective-filtered-walk-forward-identity"></a>Objective-filtered walk-forward identity | [Validation synthesis Section 6](rfc/rfc_validation_toolkit_v0_1_9_x_synthesis.md#6-d4-business-objective-enters-session-identity); [maintainer amendment Section 14](rfc/rfc_validation_toolkit_v0_1_9_x_synthesis.md#14-amendment-2026-06-26-maintainer-v0197-business-objective-promotion) | No implementation ticket is open; the pipeline row routes future completion | [Execution identity](contracts.md#contract-execution-identity); [business objectives](contracts.md#contract-result-business-objectives) | [Pipeline](rfc/README.md#objective-filtered-walk-forward-identity) |
| <a id="oms-order-lifecycle"></a>OMS order lifecycle | [Target-risk synthesis Section 5](rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md#5-explicit-deferrals); [OMS synthesis Sections 3-10](rfc/rfc_ledgr_oms_seed_synthesis.md#3-accepted-architecture); [OMS minimum scope](rfc/rfc_ledgr_oms_seed_synthesis.md#12-v02x-minimum-scope) | No implementation ticket is open; the pipeline row routes the future OMS contract and implementation packet | [Entry points](contracts.md#contract-execution-entry-points); [target risk](contracts.md#contract-execution-target-risk); [accounting events](contracts.md#contract-execution-accounting-events) | [Pipeline](rfc/README.md#oms-order-lifecycle) |

The two history rows are currently owned by Cut 16, Workstreams 40 through 44
and LDG-3057 through LDG-3071. Their receiver-level ownership is recorded in
the cut's `contract_receivers` field.

## Removed locators

These anchors preserve inbound links only. They carry no current authority or
editable obligation; follow the named receiver.

| Former topic | Current receiver |
| --- | --- |
| <a id="execution-window-minimum"></a>Execution-window minimum | [Execution window start](contracts.md#contract-execution-window-start); historical authority remains in the v0.1.9.5 packet. |
| <a id="fill-transition-validity"></a>Fill-transition validity | [Fill and lot validity](contracts.md#contract-execution-fills-and-lots); historical authority remains in the v0.1.9.5 packet. |
| <a id="cost-rounding-and-fees"></a>Cost rounding and fees | [Cost-model arithmetic](contracts.md#contract-execution-cost-model); historical authority remains in the v0.1.9.5 packet. |
| <a id="walk-forward-snapshot-override"></a>Walk-forward snapshot override | [Execution identity](contracts.md#contract-execution-identity); historical authority remains in the v0.1.9.5 packet. |
| <a id="equity-corporate-actions"></a>Equity corporate actions | Current behavior is in [accounting events](contracts.md#contract-execution-accounting-events), [availability valuation](contracts.md#contract-availability-valuation) and [corporate-action results](contracts.md#contract-result-corporate-actions); unimplemented exact-quantity work remains in the [pipeline](rfc/README.md#exact-equity-quantity-settlement). |
| <a id="testing-architecture"></a>Testing architecture | Shipped release gates are in the [Verification Contract](contracts.md#contract-verification-release-gates); the current control plane is owned by `tests/README.md`, `tests/test-gates.yml` and `tests/claims.yml`; accepted design history remains in the testing-architecture synthesis. |
| <a id="accounting-core-consolidation"></a>Accounting-core consolidation | Current staging and dispatch rules are in [event staging](contracts.md#contract-execution-event-staging) and [compiled dispatch](contracts.md#contract-execution-compiled-accounting); the accepted internal architecture remains in the accounting-core synthesis and its implementations in `R/accounting-replay.R` and `R/lot-accounting.R`; future compiled work remains in the [pipeline](rfc/README.md#compiled-execution-envelope). |
| <a id="snapshot-verification-policy"></a>Snapshot verification policy | Current rule-3 identity, verification and read-class rules are in the [Snapshot Contract](contracts.md#contract-snapshot-identity-and-verification), [snapshot trust boundary](contracts.md#contract-execution-snapshot-trust) and [verification gate](contracts.md#contract-verification-terminal-and-snapshot-gates); accepted history remains in the snapshot-verification synthesis and Cut 13. |

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
