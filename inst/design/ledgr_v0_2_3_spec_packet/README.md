# ledgr v0.2.3 Spec Packet

Role: living; current packet front door.
Status: working; macro plan revision 7 records the accepted within-release
order. Cuts 1, 2, 4 and 5 are closed. Cut 5's typed carrier is merged at
`b5622f09`. Cut 6 (WS4b, one execution path) is accepted in `tickets.yml`;
its first [review](cut_review_6.md) returned `NEEDS_TYPE_2`, the maintainer
chose Option B, and the focused [re-review](cut_review_6_rereview_1.md) is
`PASS_AFTER_PATCHES` with its patches applied. The maintainer's reuse-first
[evidence reconciliation](cut_6_evidence_reconciliation.md) closes the
pre-acceptance input gate without replaying accepted workloads. The maintainer
accepted revision 4 on 2026-11-01; implementation starts with LDG-3170.
Cut 2 (WS3 dense oracle and current-tree timing) is closed and accepted at revision 3.2. The 2026-10-30 amendment aligns its descriptive baseline with Cut 4's shared paired-gate harness boundary; its focused [review](cut_review_2_amendment.md) is `PASS`. Workstream 2's accepted [Type 1 close review](ws2_close_review.md) freezes the dense oracle at `cbf25359`. Workstream 3's accepted [Type 1 close review](ws3_close_review.md) freezes the descriptive [current-tree record](../../../dev/bench/peer_benchmark/records/20261030-current-tree/). Together they discharge C1's oracle/baseline prerequisite. A0 remains independent, the record is not a future ratio arm or public speed claim, and the old peer driver retires only after replacement coverage is accepted.
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
