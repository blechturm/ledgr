# ledgr v0.2.2 Spec Packet

**Status:** Cut 1 accepted by the maintainer on 2026-10-03. Workstream 1 is
accepted after Type 1 close review; Workstream 2 is in progress and later
workstreams remain pending.

This packet is the durable home for the v0.2.2 release plan. The release goal,
scope boundary and dependency structure are recorded in `macro_plan.md`. That
plan does not authorize implementation and does not replace an accepted RFC,
contract or research finding.

`tickets.yml` is the sole ticket and sequencing authority. Independent cut
review and maintainer acceptance open Workstream 1; this README only summarizes
the packet state and does not become a second editable ticket ledger.

## Current artifacts

- `macro_plan.md`: maintainer-level release scope, dependency order, cut
  strategy and definition of done.
- `design_memory_overhaul_plan.md`: proposed Markdown architecture, lifecycle
  rules and migration plan for the v0.2.2 design-memory workstream. The
  maintainer accepted it for Cut 1 on 2026-10-03.
- `contract_census.md`: the bounded LDG-2923 migration input and LDG-2924
  reconciliation; it is evidence, not a replacement contract.
- `decision_catalogue_reconciliation.md`: LDG-2925 row-by-row migration
  evidence for the two retired catalogues; it is not a decision index.
- `../README.md`: the LDG-2926 short front door for current authority and
  task-oriented routes.
- `tickets.yml`: sole ticket and sequencing authority. It currently records
  twelve tickets in five workstreams; Workstream 1 is complete, Workstream 2
  is in progress and the remaining workstreams are pending.

## Cut 1: Design-memory authority and discoverability

Authority: the accepted `design_memory_overhaul_plan.md`, macro-plan WS0 and
the accepted governance synthesis D4 through D7.

| Workstream | Tickets | Content | Review claim |
| --- | --- | --- | --- |
| 1 Contract authority baseline | LDG-2923-2924 | bounded contract census; safe header, reference and H2 navigation normalization | contracts can become the normative current-release source without losing a packet-only rule or making a code defect authoritative |
| 2 Front door and decision bridge | LDG-2925-2927 | one temporary bridge, short front door, pending and partial-supersession links | current and accepted-pending answers are reachable within two links without a second authority or state ledger |
| 3 RFC pipeline and obligation routing | LDG-2928-2929 | amend both stage-9 passages; pipeline active, due, parked and open-obligation work | every accepted unscheduled obligation has exactly one operational home and speculation remains non-binding |
| 4 Horizon migration | LDG-2930-2932 | search before moving; classify and route; then preserve bodies behind exact-heading redirects | nothing is deleted, every old link resolves and no binding obligation remains hidden in parking prose |
| 5 Current context and closeout | LDG-2933-2934 | compact roadmap and AGENTS context; reconcile consumers; scenario-based closeout | the repository describes one current state and its normal answers are human-discoverable without reconstructing history |

The workstreams are serial and each receives one Type 1 close review. Together
with the completed combined Type 1 and Type 2 cut review, the planned review
count is six invocations over twelve tickets, exactly 0.500. That review
returned `PASS_AFTER_PATCHES`; its bounded corrections are incorporated. A
correction review is recorded honestly rather than hidden by merging or
padding work.

This cut changes no package behavior. Other v0.2.2 product, optimization and
RFC work remains outside it and may be cut separately after its own authority
is ready.

## Expected later artifacts

- accepted design records or explicit references to their existing locations;
- rendered packet status and closeout evidence as implementation proceeds.

The roadmap remains the compact cross-version index and points here. Detailed
v0.2.2 planning belongs in this packet so that the roadmap and the packet do
not become competing copies of the same plan.
