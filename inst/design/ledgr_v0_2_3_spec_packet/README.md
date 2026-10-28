# ledgr v0.2.3 Spec Packet

Role: living; current packet front door.
Status: implementation; macro plan accepted 2026-10-28; cut 1 (one output handler) accepted 2026-10-28 in `tickets.yml`.
Authority: routing only. The roadmap binds release scope, accepted RFCs bind
design, contracts bind shipped behavior, and `tickets.yml` is implementation
authority for each accepted cut.

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
