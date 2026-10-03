# ledgr RFC Pipeline

**Status:** Current RFC pipeline for `v0.2.2` planning and accepted later-work
obligations.
**Authority:** Routing index only. Accepted syntheses, maintainer decisions,
contracts and versioned packets remain authoritative.

This file contains only RFC work that is active, due, deliberately parked or
still owed by an accepted synthesis. Completed cycles with no open obligation
do not remain here. Historical seeds, responses, reviews and syntheses stay at
their existing paths and remain discoverable through their consumers and
versioned packets.

The allowed states are:

- **Active:** an RFC cycle has started and its next stage is named.
- **Due:** a recorded trigger has fired, but the cycle has not started.
- **Parked:** the trigger has not fired; this is non-binding routing, not a
  roadmap promise.
- **Obligations open:** an accepted synthesis binds later work that no ticket
  cut owns yet. The row names the exact source, trigger and intended route.

`horizon.md` is non-binding parking, never authority for an accepted
obligation. An `Obligations open` row leaves only when a ticket cut owns it or
the maintainer explicitly drops it with a recorded reason.

## RFC Pipeline

| Cycle or obligation | State | Latest operative artifact | Next action or trigger |
| --- | --- | --- | --- |
| <a id="feature-map-read-surface"></a>Feature-map read surface | **Active** | [Seed v1](rfc_feature_map_read_surface_v0_2_x_seed.md); accepted callback obligation in [Strategy Callback Addendum: Future obligations](rfc_strategy_callback_contract_addendum_v0_1_8_10_synthesis.md#future-obligations-recorded) | Write the Type 2 response against the current fail-closed alias/engine-ID collision rule, then continue the RFC cycle. |
| <a id="terminal-outcome-policy"></a>Terminal outcomes without settlement evidence | **Due** | [v0.2.2 macro plan WS2](../ledgr_v0_2_2_spec_packet/macro_plan.md#ws2-terminal-gap-and-execution-usability) | The v0.2.2 trigger has fired. Gather the named prior art and write the seed for declared refusal, write-off, haircut and qualifying-mark policies. |
| <a id="recursive-indicator-semantics"></a>Recursive indicator history, readiness, gaps and causality | **Due** | [Historical-projection v11 Section 6](rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md#6-preparation-without-mandatory-revision-machinery); [v0.2.2 macro plan WS4](../ledgr_v0_2_2_spec_packet/macro_plan.md#ws4-recursive-indicator-semantics-and-strict-feature-acceleration) | Run the bounded public-API probe, then write the seed. Do not let an optimization choose convergence or gap semantics. |
| <a id="snapshot-verification-policy"></a>Snapshot verification and reusable feature-artifact policy | **Due** | [v0.2.2 macro plan WS5](../ledgr_v0_2_2_spec_packet/macro_plan.md#ws5-snapshot-verification-and-artifact-policy) | The v0.2.2 policy window is open. Frame verification cost, component hashes and feature persistence before implementation tickets. |
| <a id="shorting-leverage-contract"></a>Shorting and leverage contract | **Parked** | [Roadmap](../ledgr_roadmap.md); [horizon](../horizon.md) | Open before Palomar constraint expansion or another release claims short, leveraged or market-neutral portfolio semantics. |
| <a id="cross-asset-accounting-events"></a>Cross-asset accounting-critical events and non-spot accounting | **Parked** | [Cross-Asset Accounting Critical Events](../research/Cross-Asset-Accounting-Critical-Events.md); [horizon](../horizon.md) | Open when crypto, futures, margin, FX or derivatives work needs interest, borrow, funding or other non-trade events. |
| <a id="spot-crypto-readiness"></a>Spot-crypto readiness | **Parked** | [Roadmap](../ledgr_roadmap.md); [spike protocol](../spike_protocol.md) | Resume with the named public-path BTC/EUR and ETH/EUR prerequisite probe when spot crypto enters a committed release window. |
| <a id="tax-accounting"></a>Jurisdictional tax accounting and after-tax returns | **Parked** | [Cross-Asset Accounting Critical Events](../research/Cross-Asset-Accounting-Critical-Events.md); [horizon](../horizon.md) | Open only after spot-crypto and accounting-critical-event evidence can separate legal interpretation, facts, policy, lots and reporting. |
| <a id="benchmark-methodology"></a>External benchmark methodology | **Parked** | [Research index](../research/README.md); [horizon](../horizon.md) | Run the reserved research pass when a release makes a new public comparative performance claim. |
| <a id="multi-asset-trade-definitions"></a>Multi-asset trade definitions | **Parked** | [Research index](../research/README.md) | Open with the non-spot accounting arc, before cross-asset trade statistics are claimed. |
| <a id="strategy-scheduler"></a>Strategy schedule decorator and held-pulse skipping | **Parked** | [Staged seed](rfc_strategy_schedule_decorator_v0_1_9_x_seed.md); [v0.2.2 macro plan WS6](../ledgr_v0_2_2_spec_packet/macro_plan.md#ws6-conditional-scheduler-v2) | Run the held-pulse cost probe. Open the response stage only if the measured product-path cost is material. |
| <a id="portfolio-construction"></a>Generic portfolio-construction scaffolding and adapters | **Parked** | [Historical-projection v11](rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md); [methodology references](../methodology_references.md); [horizon](../horizon.md) | Open after the public historical surface ships and a capability beyond the v0.2.2 representative long-only strategy is justified. |
| <a id="execution-policy"></a>Execution policy, liquidity and broader OMS implementation | **Parked** | [Execution-policy north star](rfc_execution_policy_pipeline_audit_signal_north_star.md); [OMS synthesis](rfc_ledgr_oms_seed_synthesis.md) | Open a concrete child RFC when order policy, partial fills, liquidity, capacity or paper/live execution enters committed scope. |
| <a id="instrument-master-data"></a>Instrument master, PIT regressors and snapshot administration | **Parked** | [Cross-Asset Accounting Critical Events](../research/Cross-Asset-Accounting-Critical-Events.md); [horizon](../horizon.md) | Open the relevant data RFC when a committed workflow needs identity mutation, PIT regressor facts, administration or lineage beyond current contracts. |
| <a id="ml-architecture"></a>ML strategy and fitted-imputer architecture | **Parked** | [Reproducible Leakage-Safe ML](../research/Reproducible-Leakage-Safe-ML.md); [historical-projection v11 Section 9](rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md#9-deferred-work-and-reopening) | Open after causal history ships and a workflow requires fitted transforms, model identity, refitting or embargo-aware training. |
| <a id="point-in-time-historical-projection"></a>Point-in-time historical projection implementation | **Obligations open** | [Accepted v11 Section 7](rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md#7-checkpoint-disposition-and-ticket-cut-boundary) and [Section 8](rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md#8-contract-changes-and-detecting-requirements) | **Trigger:** v0.2.2 WS3. **Route:** resolve the semantic-evidence and two-clock representation prerequisites, then cut implementation and release evidence under one owning packet. |
| <a id="exact-equity-quantity-settlement"></a>Exact equity quantity settlement | **Obligations open** | [Equity-settlement synthesis Section 9](rfc_equity_settlement_post_v0_2_0_2_synthesis.md#9-future-obligations-recorded) | **Trigger:** the next equity-accounting release that claims recipient quantities or basis transfer. **Route:** a dedicated exact-quantity RFC before ticket cut. |
| <a id="compiled-execution-envelope"></a>Compiled execution envelope | **Obligations open** | [Accounting-core synthesis Section 9](rfc_accounting_core_consolidation_v0_2_0_2_synthesis.md#9-future-obligations-recorded) | **Trigger:** a release proposes another compiled call site, operation or default. **Route:** the focused compiled-execution RFC using the recorded carrier and scaling evidence. |
| <a id="objective-filtered-walk-forward-identity"></a>Objective-filtered walk-forward identity | **Obligations open** | [Validation synthesis Section 14](rfc_validation_toolkit_v0_1_9_x_synthesis.md#14-amendment-2026-06-26-maintainer-v0197-business-objective-promotion) | **Trigger:** a walk-forward workflow lets a business objective participate in selection. **Route:** the business-objective completion RFC and its implementation packet must bind session identity before execution. |
| <a id="oms-order-lifecycle"></a>OMS order lifecycle minimum scope and follow-ups | **Obligations open** | [OMS synthesis Section 12](rfc_ledgr_oms_seed_synthesis.md#12-v02x-minimum-scope) and [Section 14](rfc_ledgr_oms_seed_synthesis.md#14-future-obligations-on-record) | **Trigger:** an OMS implementation, paper/live, liquidity, unified-event or intraday storage cycle opens. **Route:** the owning spec cut or named follow-up RFC must consume the applicable obligation. |
| <a id="validation-toolkit-follow-ups"></a>Validation-toolkit robustness follow-ups | **Obligations open** | [Validation synthesis Section 12](rfc_validation_toolkit_v0_1_9_x_synthesis.md#12-future-obligations-recorded) | **Trigger:** one of the section's named prerequisites or product demands fires. **Route:** a focused evaluation RFC; shorting-, lineage- and benchmark-dependent items wait for those upstream contracts. |
| <a id="strategy-callback-follow-ups"></a>Strategy-callback hardening follow-ups | **Obligations open** | [Strategy Callback Addendum: Future obligations](rfc_strategy_callback_contract_addendum_v0_1_8_10_synthesis.md#future-obligations-recorded) | **Trigger:** a real mutation bug, post-CRAN hardening need or separately authorized compiled core. **Route:** the named contract-hardening or compiled-callback RFC; feature-map vector reads are already consumed by the active feature-map cycle above. |

When a synthesis is accepted, update this pipeline and the
[decision bridge](../decisions.md) in the same acceptance step. The bridge
links here; it does not copy obligation text. At ticket cut, remove each newly
owned obligation from this table because `tickets.yml` becomes its executable
home.
