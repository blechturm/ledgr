# ledgr v0.2.2 Spec Packet

**Status:** Cut 1 and all five workstreams accepted by the maintainer on
2026-10-03 after Type 1 close review and the focused Workstream 5 corrections.
Cut 2 passed independent review after bounded patches and was accepted by the
maintainer on 2026-10-03. Workstreams 6 and 7 are accepted; Workstreams 8 and
9 are pending.

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
- `horizon_migration_reconciliation.md`: the LDG-2931 classification,
  obligation sweep and LDG-2932 body/redirect reconciliation; it is migration
  evidence, not authority or a backlog.
- `../roadmap_history.md`: the verbatim planning tail displaced when LDG-2933
  reduced the roadmap to its maintained sequence; it is historical context,
  not current scope or sequencing authority.
- `design_memory_overhaul_closeout.md`: the accepted LDG-2934 evidence
  reconciliation, least-machinery decision and six-scenario navigation walk.
- `decision_catalogue_reconciliation.md`: LDG-2925 row-by-row migration
  evidence for the two retired catalogues; it is not a decision index.
- `../README.md`: the LDG-2926 short front door for current authority and
  task-oriented routes.
- `../rfc/README.md`: the LDG-2929 current RFC pipeline for active, due,
  deliberately parked and accepted-obligation work.
- `tickets.yml`: sole ticket and sequencing authority. It records twelve
  complete Cut 1 tickets, six complete Cut 2 tickets and five pending Cut 2
  tickets; Cut 1 is closed and Cut 2 is open.
- `writer_scaling_closeout.md`: accepted Workstream 6 record for the shipped
  fill-event flush and diagnostic-sequence repair.
- `feature_accessor_scaling_closeout.md`: agent-provisional Workstream 7
  record for the accepted prepared feature accessors and exact explicit-map
  memoization.

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

The Workstream 5 close review was invocation seven and its focused re-review
was invocation eight. The actual count is therefore 8/12 = 0.667. The
historical breach is recorded rather than repaired by adding tickets or
combining reviews.

The maintainer accepted Workstream 5 and closed Cut 1 on 2026-10-03 after the
record-only correction at `79363fb`, without a ninth review invocation.

This cut changes no package behavior. Other v0.2.2 product, optimization and
RFC work remains outside it and may be cut separately after its own authority
is ready.

## Cut 2: Proven long-window optimizations

**Status:** Independent review returned `PASS_AFTER_PATCHES`; its bounded
ticket corrections are incorporated. The maintainer accepted Cut 2 on
2026-10-03. Workstream 6 was accepted on 2026-10-03 and Workstream 7 on
2026-10-04. Workstream 8 was accepted on 2026-10-04 after its focused
correction review returned `PASS`; Workstream 9 remains pending.

Authority: macro-plan WS1 for all mechanisms; the maintained roadmap's opening
optimization row additionally authorizes the writer and accessor tickets but
not the strict-feature ticket. Evidence comes from the fold-writer/accessor
spike, the long-window scaling record and the accepted exact-parity
internal-optimization proof template.

| Workstream | Tickets | Content | Review claim |
| --- | --- | --- | --- |
| 6 Writer scaling | LDG-2935-2937 | per-pulse fill flush; conditional constant-time diagnostic sequence; closeout | scale-growing writer work is removed with exact outputs, ordering, resume and existing failure behavior |
| 7 Feature-accessor scaling | LDG-2938-2940 | prepared scalar lookups; validate-once and exact run-local last-map memo; closeout | repeated accessor work disappears without changing values, errors, validation, workers or isolation |
| 8 Built-in strict-feature acceleration | LDG-2941-2942 | accelerated path for ledgr SMA and returns only; closeout | values and NA masks remain exact while repeated frame, validation and dispatch work is removed |
| 9 Availability fact scaling | LDG-2943-2945 | vector session construction; linear membership resolution; closeout | exact fact rows, evidence, errors, ordering and snapshot identity survive the scaling repair |

Workstream 8 implementation is `9bde734` plus the exact-SMA correction
`11bd294`; its agent-provisional record is
`strict_feature_acceleration_closeout.md`. The corrected reproducible
50-instrument by 500-pulse gate measured 34.7-40.7% cold-run savings and exact
public outputs. The first close review disproved the original
`rowMeans(embed())` identity claim. Its focused correction review is Cut 2
invocation 7/11 = 0.636, recorded as a historical review-gate breach.
The maintainer accepted the workstream after that `PASS`; no redundant eighth
review was counted.

The four workstreams are independent after cut acceptance. Each candidate
starts with a current-tree baseline, semantic oracle, failure-sensitive
structural detector and preregistered materiality threshold. A candidate that
misses its gate closes as measured and rejected; it does not acquire production
changes merely because an older spike looked promising.

One combined Type 1 and Type 2 cut review plus four Type 1 close reviews is five
planned invocations over eleven tickets, 0.455 against the 0.5 gate. Without
the four owned evidence closeouts it would be 5/7 = 0.714; the closeout tickets
are retained because each produces the independently reviewable evidence for
one workstream, not to pad the denominator. Correction reviews count and any
breach is recorded rather than repaired by padding.

The cut authorizes no public API, schema, run or snapshot identity, snapshot
hash, tolerance, default, persistence contract, verification-policy or
failure-semantics change. The availability feature-engine provenance digest
must change when its implementation body changes; that expected digest update
and its compatibility disclosure are not a public identity change. The cut
excludes custom, external and TTR indicator semantics, db_live and compiled
accounting behavior, snapshot-verification redesign and every candidate that
fails its gate.

## Expected later artifacts

- accepted design records or explicit references to their existing locations;
- rendered packet status and closeout evidence as implementation proceeds.

The roadmap remains the compact cross-version index and points here. Detailed
v0.2.2 planning belongs in this packet so that the roadmap and the packet do
not become competing copies of the same plan.
