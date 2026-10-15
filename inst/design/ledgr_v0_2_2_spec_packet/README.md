# ledgr v0.2.2 Spec Packet

Role: mixed; current packet front door and index of durable packet records.
Status: working
Authority: routing only. `tickets.yml` is the sole ticket, dependency,
acceptance and sequencing authority.

This packet is the durable home for the v0.2.2 release plan. It deliberately
does not copy workstream status, ticket dependencies or acceptance state from
`tickets.yml`.

## Start here

| Need | Source |
| --- | --- |
| Current tickets, dependencies and acceptance | [`tickets.yml`](tickets.yml) |
| Release scope, order and definition of done | [`macro_plan.md`](macro_plan.md) |
| Current behavioural authority | [`contracts.md`](../contracts.md) |
| Accepted decision bridge | [`decisions.md`](../decisions.md) |
| Active, due, paused, parked and open RFC work | [`rfc/README.md`](../rfc/README.md) |
| Maintained release sequence | [`ledgr_roadmap.md`](../ledgr_roadmap.md) |
| Non-binding future parking | [`horizon.md`](../horizon.md) |
| Design-memory navigation | [`inst/design/README.md`](../README.md) |

The macro plan does not authorize implementation and does not replace an
accepted RFC, contract or research finding. Historical planning displaced
from that file remains in [`macro_plan_history.md`](macro_plan_history.md).

## Current cut review records

Cut reviews and finding-bearing workstream reviews are durable packet records:

- [`cut_review_7.md`](cut_review_7.md),
  [`cut_review_9.md`](cut_review_9.md),
  [`cut_review_13.md`](cut_review_13.md) and
  [`cut_review_14.md`](cut_review_14.md);
- [`cut_review_15.md`](cut_review_15.md),
  [`cut_review_15_rereview.md`](cut_review_15_rereview.md) and
  [`cut_review_15_rereview_2.md`](cut_review_15_rereview_2.md);
- [`close_review_32.md`](close_review_32.md) and
  [`close_review_32_rereview_1.md`](close_review_32_rereview_1.md);
- [`close_review_33.md`](close_review_33.md);
- [`close_review_34.md`](close_review_34.md) and
  [`close_review_34_rereview_1.md`](close_review_34_rereview_1.md);
- [`close_review_35.md`](close_review_35.md);
- [`close_review_36.md`](close_review_36.md) and
  [`close_review_36_rereview_1.md`](close_review_36_rereview_1.md);
- [`close_review_37.md`](close_review_37.md);
- [`close_review_38.md`](close_review_38.md) and
  [`close_review_38_rereview_1.md`](close_review_38_rereview_1.md).

A finding-free `PASS` is recorded as one line in `tickets.yml` and has no
separate file. The ticket authority says which reviews are operative.

## Durable closeouts and reconciliations

These records explain completed decisions or evidence without becoming a
second status ledger:

- [`design_memory_overhaul_closeout.md`](design_memory_overhaul_closeout.md),
  [`current_contract_reconciliation.md`](current_contract_reconciliation.md),
  [`decision_catalogue_reconciliation.md`](decision_catalogue_reconciliation.md)
  and
  [`horizon_migration_reconciliation.md`](horizon_migration_reconciliation.md);
- [`governance_record_normalization.md`](governance_record_normalization.md);
- [`fold_phase_contract_closeout.md`](fold_phase_contract_closeout.md) and
  [`fold_phase_extraction_closeout.md`](fold_phase_extraction_closeout.md);
- [`current_only_records_closeout.md`](current_only_records_closeout.md),
  [`current_store_format_closeout.md`](current_store_format_closeout.md),
  [`feature_map_read_surface_reconciliation.md`](feature_map_read_surface_reconciliation.md)
  and
  [`feature_retention_identity_closeout.md`](feature_retention_identity_closeout.md);
- [`terminal_outcomes_reconciliation.md`](terminal_outcomes_reconciliation.md),
  [`writer_scaling_closeout.md`](writer_scaling_closeout.md),
  [`feature_accessor_scaling_closeout.md`](feature_accessor_scaling_closeout.md),
  [`availability_fact_scaling_closeout.md`](availability_fact_scaling_closeout.md),
  [`fact_integrity_verification_closeout.md`](fact_integrity_verification_closeout.md),
  [`strict_feature_acceleration_closeout.md`](strict_feature_acceleration_closeout.md)
  and [`strict_ttr_cleanup_closeout.md`](strict_ttr_cleanup_closeout.md).

Other packet files remain historical evidence at their existing paths. Use
`tickets.yml`, not this index, to decide whether a record is current.

## Evidence form

Each ticket acceptance item has one evidence item. That item contains:

1. a stable pointer to a test block, claim, file section, commit, record or
   review artifact; and
2. one sentence saying what the evidence established.

Prefix observed runs, benchmarks and reviewed comparisons with `Empirical:`.
Such evidence retains input identity, environment, source commit, reproduction
command, reviewed range, result and clock where applicable. Preserve reviewed
ranges exactly. A bare path, unsupported conclusion or mutable local-only
result is not complete evidence.

## Review records

The packet follows M1 and M2 from the accepted governance-lifecycle synthesis:

- a review with findings receives a file named for its review point, while a
  finding-free `PASS` is one line in `tickets.yml`;
- workstream and ticket fields link the review and summarize only what changed;
- independent-verdict counts, findings by review mode and maintainer decision
  turns are measured once at cut close, without ratio gates or padding.

## Document roles

This README is a front door. `tickets.yml` is executable ticket authority,
`macro_plan.md` is release planning, the RFC pipeline routes unfinished design
work, contracts bind current behaviour, and closeouts preserve evidence. Keep
those jobs separate when adding a packet artifact. The report-only guard's
bounded role and reproduction path live in
[`dev/governance_guard/README.md`](../../../dev/governance_guard/README.md).
