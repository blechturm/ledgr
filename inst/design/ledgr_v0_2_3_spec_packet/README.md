# ledgr v0.2.3 Spec Packet

Role: living; current packet front door.
Status: planning; macro plan accepted 2026-10-28; no cut or executable ticket is accepted.
Authority: routing only. The roadmap binds release scope, accepted RFCs bind
design, contracts bind shipped behavior, and a future `tickets.yml` becomes
implementation authority only after its cut is accepted.

v0.2.3 is the cleanup, performance and research-authoring release that follows
the published v0.2.2 point-in-time foundation. This directory is intentionally
small until the maintainer accepts a macro plan and the first cut. It does not
copy the large carried inventory from the roadmap or manufacture ticket status.

## Start here

| Need | Source |
| --- | --- |
| Release goal and carried scope | [Roadmap current-release section](../ledgr_roadmap.md#next-release) |
| Within-release order (accepted 2026-10-28) | [Macro plan](macro_plan.md) |
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
