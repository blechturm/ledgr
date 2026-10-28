# ledgr Design Memory

Role: living; current design-memory front door for release `v0.2.3`.
Status: working
Authority: routing map only under the accepted governance-lifecycle synthesis
[Sections 2 and 7](rfc/rfc_governance_lifecycle_v0_2_2_synthesis.md#2-authority-and-document-lifetime-s-r1-r2).
This file does not create package behavior, accept a decision or authorize
implementation.
Current packet: [ledgr v0.2.3](ledgr_v0_2_3_spec_packet/README.md).
Cuts 1 (one output handler) and 2 (WS3 dense oracle/current-tree timing) were
accepted on 2026-10-28. The packet's `tickets.yml` is their sole ticket and
sequencing authority; acceptance does not claim implementation.

Use this page to identify the shortest authoritative route. Do not infer
authority from a filename, version number, modification date or proximity to
the current release.

## Start here

| Need | Read |
| --- | --- |
| Current package behavior or an internal invariant | [contracts.md](contracts.md) and its H2 topic links |
| Accepted choice not yet consolidated | [decisions.md](decisions.md), then the exact linked source sections |
| Active or owed RFC work | [RFC pipeline](rfc/README.md#rfc-pipeline) |
| Current release goal and dependency order | [v0.2.3 packet](ledgr_v0_2_3_spec_packet/README.md) and [roadmap](ledgr_roadmap.md) |
| Executable implementation work | [Current tickets](ledgr_v0_2_3_spec_packet/tickets.yml), accepted cuts 1 and 2 |
| Uncommitted future idea | [horizon.md](horizon.md) |
| Research, audit or spike evidence | [research](research/README.md), [audits](audits/) or [spikes](spikes/) as cited by its consumer |
| Released history | [roadmap release records](ledgr_roadmap.md), [historical planning context](planning_context_history.md) and the versioned spec-packet directories |

For RFC work, read [rfc_cycle.md](rfc_cycle.md). For a spike, read
[spike_protocol.md](spike_protocol.md). For release execution, read
[release_ci_playbook.md](release_ci_playbook.md).

## What can bind work

1. [contracts.md](contracts.md) is normative for shipped public behavior and
   preserved internal invariants.
2. Accepted synthesis sections and recorded maintainer decisions bind their
   stated pending scope until consolidated or explicitly superseded.
   Acceptance does not claim implementation. The temporary
   [decision bridge](decisions.md) points to their exact operative sections;
   it is not authority itself.
3. [ledgr_roadmap.md](ledgr_roadmap.md) binds release scope and release
   sequence, not package semantics. An accepted current-release macro plan
   binds uncut within-release order; v0.2.3's is
   [ledgr_v0_2_3_spec_packet/macro_plan.md](ledgr_v0_2_3_spec_packet/macro_plan.md).
4. A versioned packet turns accepted scope into implementation work. Within a
   cut, its `tickets.yml` alone owns ticket detail, state and sequencing.
5. Incorporated evidence binds only the rule an accepted section expressly
   promotes, with a link to that section.
6. [rfc_cycle.md](rfc_cycle.md), [spike_protocol.md](spike_protocol.md),
   [release_ci_playbook.md](release_ci_playbook.md) and repository `AGENTS.md`
   bind the processes they govern.

RFC seeds, responses, audits, reviews, spikes, research notes and manuals are
evidence or explanation unless an accepted artifact explicitly promotes a
rule from them. `horizon.md` is non-binding parking.

## Conflict rules

- If code or a test disagrees with a current contract, the contract stands
  provisionally. Route the code defect or an authorized contract change.
- If two binding documents conflict, stop relying on the disputed rule and
  route the conflict. Do not solve it by choosing the newer or nearer file.
- A later document takes precedence only when it explicitly supersedes the
  earlier source and identifies the operative replacement sections.
- An index, catalogue, packet closeout or explanatory summary cannot silently
  change the rule in its source authority.
- `tickets.yml` may divide and sequence accepted work; it may not reinterpret
  the accepted design.

## Current release

Release `v0.2.2` was published on 2026-10-27. Its
[packet](ledgr_v0_2_2_spec_packet/README.md), frozen
[macro plan](ledgr_v0_2_2_spec_packet/macro_plan.md) and
[tickets](ledgr_v0_2_2_spec_packet/tickets.yml) are release evidence.

Release `v0.2.3` is the active implementation release. Its
[packet front door](ledgr_v0_2_3_spec_packet/README.md) starts from the roadmap
and RFC pipeline; `tickets.yml` records accepted cuts and implementation state.

The latest tagged release and older release outcomes remain discoverable in
the [roadmap](ledgr_roadmap.md) and their versioned packet directories. Those
records explain what shipped; they do not authorize new work.

## Standing design surfaces

| Surface | Role |
| --- | --- |
| [contracts.md](contracts.md) | Current behavioral and internal-invariant authority |
| [decisions.md](decisions.md) | Temporary exact-source bridge for accepted unconsolidated choices |
| [ledgr_roadmap.md](ledgr_roadmap.md) | Committed release goals and sequencing |
| [horizon.md](horizon.md) | Non-binding parking |
| [rfc/README.md](rfc/README.md) | Active, due, parked and open-obligation RFC pipeline |
| [adr/README.md](adr/README.md) | Historical ADR routing and records; the ADR process is wound down |
| [manual/](manual/) | Maintainer explanation and implementation guidance |
| [research/](research/README.md) | Research evidence and vendor-specific interpretation |
| [audits/](audits/) | Bounded findings and their routing evidence |
| [spikes/](spikes/) and `dev/spikes/` | Empirical probes; informative until promoted |

## Historical and explanatory material

Historical RFC versions, released packets, responses, reviews and closeouts
stay at their existing paths. Start from an accepted synthesis or packet
closeout rather than reconstructing authority from intermediate artifacts.
The [historical planning context](planning_context_history.md) preserves older
navigation prose; it is not maintained.

The pre-CRAN compatibility framing and review routes live in
[rfc_cycle.md](rfc_cycle.md). Architecture inputs and methodology references
remain evidence until a current binding artifact names them.

## Maintenance

Update this front door only when the active release, primary routes or
authority rules change. Do not add ticket detail, a release-by-release ledger,
decision summaries or an RFC catalogue here.
