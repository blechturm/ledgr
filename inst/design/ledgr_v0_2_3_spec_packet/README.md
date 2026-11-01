# ledgr v0.2.3 Spec Packet

Role: living; current packet front door.
Status: working; macro plan revision 7 records the accepted within-release
order. Cuts 1, 2, 4 and 5 are closed. Cut 6 (WS4b, one execution path) is
implemented and accepted through `14252ffb`: its final independent Type 1
confirmation is `PASS`, and workstream 14/LDG-3178 are complete. Cut 7 is the
accepted WS5 strategy-authoring implementation cut (workstreams 15-18,
LDG-3179-LDG-3190); it resolves the accepted synthesis's bounded spec-cut
questions. Its independent [cut review](cut_review_7.md) returned
`NEEDS_TYPE_2`: all independent corrections are applied, and the maintainer
accepted its recommended durable cursor/checkpoint option on 2026-11-01. The
bounded pre-acceptance probes are recorded in
`dev/bench/v0_2_3_strategy_authoring_preflight/`; its focused
[re-review](cut_review_7_rereview_1.md) is `PASS_AFTER_PATCHES` with patches
applied. Its [final confirmation](cut_review_7_confirmation_1.md) required four
exact textual patches and stated that no further review was needed once they
landed; all are applied. The maintainer accepted the cut on 2026-11-01.
Cut 2 (WS3 dense oracle and current-tree timing) is closed and accepted at revision 3.2. The 2026-10-30 amendment aligns its descriptive baseline with Cut 4's shared paired-gate harness boundary; its focused [review](cut_review_2_amendment.md) is `PASS`. Workstream 2's accepted [Type 1 close review](ws2_close_review.md) freezes the dense oracle at `cbf25359`. Workstream 3's accepted [Type 1 close review](ws3_close_review.md) freezes the descriptive [current-tree record](../../../dev/bench/peer_benchmark/records/20261030-current-tree/). Together they discharge C1's oracle/baseline prerequisite. A0 remains independent, the record is not a future ratio arm or public speed claim, and the old peer driver retires only after replacement coverage is accepted.

Workstream 15 (LDG-3179--LDG-3181) is implementation-complete and prepared
for its independent Type 1 close review. The bounded record is
[ws15_implementation_matrix.md](ws15_implementation_matrix.md) with runnable
inventories under `dev/bench/v0_2_3_ws5/` and timing preregistration under
`dev/bench/timing/protocols/ws5-timing-1/`. Ticket statuses remain pending
until that close review and maintainer acceptance; integrated Cut 7 timing is
descriptive milestone evidence, not a WS15 correctness gate.
Authority: routing only. The roadmap binds release scope, accepted RFCs bind
design, contracts bind shipped behavior, and `tickets.yml` is the sole
implementation and sequencing authority for accepted cuts.

v0.2.3 is the cleanup, performance and research-authoring release that follows
the published v0.2.2 point-in-time foundation. The macro plan and cut 1 were
accepted on 2026-10-28; later cuts are added to `tickets.yml` as the
maintainer accepts them. The packet does not copy the large carried inventory
from the roadmap or manufacture ticket status.

## Start here

| Need | Source |
| --- | --- |
| Release goal and carried scope | [Roadmap current-release section](../ledgr_roadmap.md#next-release) |
| Within-release order (accepted 2026-10-28) | [Macro plan](macro_plan.md) |
| Cut, workstream and ticket state | [tickets.yml](tickets.yml) |
| Due, active and parked design work | [RFC pipeline](../rfc/README.md#rfc-pipeline) |
| Current package behavior | [Contracts](../contracts.md) |
| Accepted choices awaiting consolidation | [Decisions bridge](../decisions.md) |
| Non-binding future ideas | [Horizon](../horizon.md) |
| What v0.2.2 shipped | [Released v0.2.2 packet](../ledgr_v0_2_2_spec_packet/README.md) |

## First planning duties

Before the first implementation cut:

1. reconcile the roadmap's carried commitments and maintenance inventory
   against the released v0.2.2 tree;
2. run the due design work needed by that cut rather than reopening settled
   v0.2.2 choices;
3. complete the focused release-candidate, CI-gate and evidence-reuse RFC
   before designing the next publication cut; and
4. create the macro plan and `tickets.yml` only when their concrete order and
   implementation ownership are ready to be reviewed.

The packet must stay human-readable. Historical evidence remains at its
versioned source; link to it instead of copying it here.
