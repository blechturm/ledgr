# ledgr Design Memory

**Status:** Current design front door for release `v0.2.2`.
**Authority:** Routing map only. This file does not create package behavior,
accept a decision or authorize implementation.
**Current packet:** [ledgr v0.2.2](ledgr_v0_2_2_spec_packet/README.md).
Its `tickets.yml` is the sole ticket and sequencing authority for cut work.

Use this page to identify the shortest authoritative route. Do not infer
authority from a filename, version number, modification date or proximity to
the current release.

## Start here

| Need | Read |
| --- | --- |
| Current package behavior or an internal invariant | [contracts.md](contracts.md) and its H2 topic links |
| Accepted choice not yet consolidated | [decisions.md](decisions.md), then the exact linked source sections |
| Active or owed RFC work | [RFC pipeline](rfc/README.md#rfc-pipeline) |
| Current release goal and dependency order | [v0.2.2 macro plan](ledgr_v0_2_2_spec_packet/macro_plan.md) and [roadmap](ledgr_roadmap.md) |
| Executable implementation work | The owning packet's `tickets.yml`; for the current release, [v0.2.2 tickets](ledgr_v0_2_2_spec_packet/tickets.yml) |
| Uncommitted future idea | [horizon.md](horizon.md) |
| Research, audit or spike evidence | [research](research/README.md), [audits](audits/) or [spikes](spikes/) as cited by its consumer |
| Released history | [roadmap release records](ledgr_roadmap.md), [historical planning context](planning_context_history.md) and the versioned spec-packet directories |

For RFC work, read [rfc_cycle.md](rfc_cycle.md). For a spike, read
[spike_protocol.md](spike_protocol.md). For release execution, read
[release_ci_playbook.md](release_ci_playbook.md).

## What can bind work

1. [contracts.md](contracts.md) is normative for shipped public behavior and
   preserved internal invariants.
2. An accepted synthesis and recorded maintainer decisions bind their stated
   future scope until consolidated or explicitly superseded. The temporary
   [decision bridge](decisions.md) points to their exact operative sections;
   it is not authority itself.
3. [ledgr_roadmap.md](ledgr_roadmap.md) binds committed release scope and
   dependency order, not package semantics.
4. A versioned packet turns accepted scope into implementation work. Its
   `tickets.yml` alone owns ticket detail, state and sequencing.
5. [rfc_cycle.md](rfc_cycle.md), [spike_protocol.md](spike_protocol.md),
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

Release `v0.2.2` is active. Its maintained scope and dependency plan is
[macro_plan.md](ledgr_v0_2_2_spec_packet/macro_plan.md). Cut 1 implements the
accepted design-memory overhaul; its live state is in
[tickets.yml](ledgr_v0_2_2_spec_packet/tickets.yml). Other macro workstreams
remain non-executable until their own accepted designs or ticket cuts exist.

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
| [adr/README.md](adr/README.md) | ADR routing and operative ADR records |
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
