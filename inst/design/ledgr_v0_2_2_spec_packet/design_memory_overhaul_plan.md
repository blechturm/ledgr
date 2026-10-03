# v0.2.2 Design-Memory Overhaul Plan

**Status:** Accepted by the maintainer for Cut 1 on 2026-10-03; the independent
ticket-cut review returned `PASS_AFTER_PATCHES`, Workstream 1 is accepted
after Type 1 close review and Workstream 2 is in progress.

**Date:** 2026-10-03

**Purpose:** Make current design authority, accepted choices, unfinished work
and historical evidence easy to find without replacing ledgr's existing RFC,
spike, packet, ticket, roadmap or review processes.

**Revision note:** The Type 2 review found that the first draft orphaned
accepted but unscheduled RFC obligations and added more metadata than the
accepted governance model supports. This revision keeps those obligations in
the RFC pipeline, makes the required RFC-cycle amendment explicit and removes
the proposed audit ledger, mandatory spike index, closed status vocabulary and
semantic drift checks.

## 1. The problem to solve

ledgr has enough design evidence. It does not consistently distinguish what
that evidence means now.

The main symptoms are structural:

- `horizon.md` calls itself a non-binding parking lot, but many documents cite
  it for binding scope, routing and policy;
- `rfc/README.md` mixes an active pipeline, accepted decisions and historical
  implementation state;
- `ledgr_roadmap.md` mixes cross-version sequencing with detailed design
  arguments and completed-release history;
- `inst/design/README.md` is both a front door and a long historical ledger;
- accepted choices are spread across contracts, syntheses, packet closeouts,
  roadmap rows and horizon entries;
- operative status and supersession are not consistently visible; and
- accepted but unscheduled RFC obligations currently depend on the horizon,
  whose own header says it is non-binding.

The scale now makes those ambiguities material. The design root has more than
two hundred RFC markdown files, more than forty spec-packet directories, and
an active horizon of roughly 9,500 lines. The problem is not missing prose. It
is finding the current answer without reconstructing project history.

## 2. Design principles

1. **Keep the workflows.** RFC cycles, spec packets, `tickets.yml`, spikes,
   audits, the roadmap and the horizon remain.
2. **One role per surface.** A file may explain, bind, schedule, park, index or
   preserve evidence. It should not quietly do several of those jobs.
3. **Authority stays native.** Contracts, accepted syntheses and ticket cuts
   remain authoritative. An index points to authority; it never becomes it.
4. **Prefer explicit state to chronology.** A newer date does not supersede an
   older artifact. Supersession must be named.
5. **Keep history, remove it from the hot path.** Historical artifacts remain
   readable without appearing in the route to the current answer.
6. **Summaries stay short.** If an index row needs an argument, the argument
   belongs in its linked artifact.
7. **Check links, not governance form.** Optional automation may detect broken
   links in the current navigation surfaces. It must not classify documents,
   pin wording, enforce prose metadata or infer semantic authority.
8. **Migrate only what matters.** Operative and cited artifacts are normalized
   first. The historical corpus is not mass-rewritten.

## 3. Proposed file structure

No existing RFC, spike, audit or packet directory is renamed. The only new
current-facing design surface is a decision bridge. One archive file holds the
bodies removed from the legacy horizon.

```text
inst/design/
|-- README.md                       front door and current routes
|-- contracts.md                    normative current-release rules
|-- decisions.md                    accepted decisions awaiting consolidation
|-- ledgr_roadmap.md                version goals and committed sequencing
|-- horizon.md                      open parking plus historical link stubs
|-- horizon_archive.md              full bodies of resolved legacy entries
|-- planning_context_history.md     retained historical planning narrative
|-- rfc/
|   |-- README.md                   RFC pipeline and open obligations
|   `-- rfc_*.md                    existing cycle artifacts, unchanged paths
|-- spikes/                         existing spike evidence, unchanged
|-- audits/                         existing audit evidence, unchanged
|-- research/
|   |-- README.md                   retained research evidence index
|   `-- <existing research records>
|-- manual/                         explanatory and maintainer guidance
`-- ledgr_v*_spec_packet/           release packets; structure unchanged
```

The archive is not a second design index. Its header explains that it is
historical, and the one-line stubs retained in `horizon.md` redirect readers to
the full body and any promoted authority.

## 4. Responsibility of each surface

### 4.1 `inst/design/README.md`: front door

The front door answers four questions only:

1. What release is active?
2. Which documents can bind work?
3. Where should a reader go for a contract, decision, future idea, active RFC,
   implementation ticket or evidence?
4. Which documents are historical or explanatory only?

It contains a short authority ladder, current release links and task-oriented
routes. It does not contain release history, a decision catalogue or a full
RFC ledger. A length above roughly 200 lines is a review signal, not a gate.

### 4.2 `contracts.md`: binding behavior

After migration, `contracts.md` is the normative statement of the rules the
current release promises and ships, covering both public behavior and internal
invariants contributors must preserve. It does not carry the full argument
that selected them; accepted syntheses retain that rationale.

That is not yet an assumption the overhaul may make. The current header calls
the file a compact index and points its authoritative narrative to the stale
v0.1.9.5 packet. Before the new front door presents it as canonical, a bounded
contract census must inspect all thirteen top-level sections, the header and
operative cross-references.

The resulting rules are:

- contracts describe current-release promises, not accepted future direction;
- an accepted but unimplemented rule stays in its synthesis and the decision
  bridge;
- the affected contract clause gains only a one-line `Accepted change pending`
  link to the decision-bridge topic, carrying no restatement of the future
  rule; the implementing packet removes the link when it rewrites the clause;
- the implementing packet owns the contract edit and its failure-sensitive
  detector;
- where code disagrees with a contract, the contract stands provisionally and
  the disagreement is ticketed or routed; a contract changes only through its
  owning process;
- contracts do not defer a current rule to the roadmap or horizon;
- an H2-only table of contents makes the existing thirteen stable topic
  headings the navigation surface; and
- a semantic conflict found by the census is routed as a product or governance
  finding, not silently repaired as editorial cleanup.

The file remains one Markdown document in this overhaul. Splitting it would
create new authority boundaries without evidence that the topical headings
are insufficient.

### 4.3 `decisions.md`: accepted-decision bridge

This is a new index, not a new source of authority. It replaces both current
decision catalogues and lists only accepted choices whose current answer is not
yet fully consolidated into `contracts.md` or another named standing binding
document.

It does not paraphrase a combined rule or track packet progress. Its rows are:

| Topic | Exact binding source sections | Missing consolidation | Pipeline row |
|---|---|---|---|
| Example | One or more section links. | Contract or standing-document destination. | Link to `Obligations open`, or blank. |

Rules:

- proposals, alternatives and open questions do not appear;
- exact source sections replace a prose summary;
- partial supersession lists both operative sources and their exact sections;
- no Accepted/Ticketed/Implemented state is maintained here;
- obligation text appears only in the RFC pipeline; this bridge may link to its
  row but does not copy it;
- a row leaves at a release closeout only when the closeout links the exact
  contract heading that now carries the rule and its obligations are routed.

Implemented contract behavior is found through the contract's own headings,
not duplicated indefinitely in this bridge.

### 4.4 `rfc/README.md`: pipeline, not decision memory

The RFC index contains cycles that are active, due, deliberately parked or in
state `Obligations open`. Each row is short and carries:

- topic;
- current stage;
- latest operative artifact;
- next action or trigger; and
- owner or route when known.

On acceptance, a cycle with no unscheduled obligation leaves the pipeline once
its decision bridge and implementation route are recorded. A cycle with an
accepted but unscheduled obligation stays as `Obligations open`. Each such
obligation names its exact source section, trigger and intended route. The row
leaves at the ticket-cut gate when every obligation is ticketed, or when every
remaining obligation is explicitly dropped by the maintainer. Historical
seeds, responses and reviews remain at their existing paths and are reachable
from the accepted synthesis.

Both existing decision catalogues are retired. Only accepted choices still
awaiting consolidation enter `decisions.md`; implemented behavior points to
`contracts.md` or its other standing authority. The RFC index must stop
describing `horizon.md` as authoritative.

### 4.5 `ledgr_roadmap.md`: committed sequencing

The roadmap answers what the current and next releases intend to deliver and
in what dependency order. It may point to an accepted design or active RFC,
but does not restate its argument.

Completed releases collapse to compact outcome rows linking their packet and
closeout. Older planning narrative remains available in
`planning_context_history.md` or another explicitly historical document.

Roadmap scope is a maintainer commitment, not package semantics. A roadmap row
cannot substitute for an accepted design or contract.

### 4.6 `horizon.md`: parking space

The active part of the horizon contains open, non-binding ideas whose release,
design or priority is unsettled. An entry carries:

- date and short title;
- the observation or opportunity;
- why it may matter;
- the trigger for reconsideration, if known; and
- links to evidence, never copied evidence.

The horizon must not be cited as the authority for a contract, release scope,
accepted decision or ticket. Once an item is promoted, refuted or dropped, its
full body moves to `horizon_archive.md`. Its exact heading remains in a
historical-redirect section of `horizon.md` with one line naming the
disposition, archive link and durable authority when one exists. Existing
heading links therefore continue to resolve.

### 4.7 Evidence remains consumer-linked

No new spike or audit ledger is required. A consumed spike or audit is found
from the synthesis, ticket, roadmap row or research record that uses it. A Red
spike with no immediate consumer gets one horizon entry so the failed route is
not repeated. An audit with an unowned material finding routes that finding to
the horizon and may then close as `Routed`; the audit directory does not become
a second backlog.

`research/README.md` remains the existing map of research evidence. Research,
audit and spike records inform design but do not bind package behavior.

### 4.8 Spec packets and tickets

Packet structure stays unchanged. A packet README summarizes release state;
`tickets.yml` remains the sole ticket, dependency and execution authority.
Ticket details are not copied into the roadmap or design indexes.

Released packets become historical evidence. They can still be cited for the
implementation of an accepted decision, but they are not edited to reflect
later package truth.

### 4.9 Authority resolution and the planning ladder

For current package behavior and preserved internal invariants, the normalized
`contracts.md` is the first binding reference.
For an accepted direction not yet implemented, the accepted synthesis and any
recorded maintainer decisions bind the packet. `tickets.yml` may divide and
sequence that work but may not reinterpret it. Code, tests and closeouts prove
what exists; they do not silently change the accepted rule.

A conflict between binding documents is a defect to route, not a precedence
puzzle for the reader; reliance on the disputed rule stops until it is
resolved. The later document wins only when it explicitly supersedes the
earlier source and the indexes are updated with it. A code-versus-contract
disagreement is different: the contract stands provisionally and the code is
treated as defective unless the maintainer routes a contract change.

Future work moves through a visible ladder:

| State | Home |
|---|---|
| Interesting but uncommitted idea | `horizon.md` |
| Known design question with a trigger | RFC pipeline, possibly Parked |
| Accepted choice not yet consolidated | `decisions.md` plus its binding source |
| Accepted unscheduled obligation | RFC pipeline as `Obligations open` |
| Committed release scope | `ledgr_roadmap.md` and the owning packet |
| Executable work | packet `tickets.yml` |

Moving upward is explicit. An idea is not scheduled because it has a horizon
entry, and an accepted decision is not implemented merely because it has a
decision-index row.

## 5. Minimal status and supersession metadata

Current-facing documents keep the free-text `Status` and `Authority` fields
already used by the repository. This plan introduces no closed vocabulary and
no required `Scope` field. The directory, front door and indexes establish the
document's role; prose remains readable without decoding metadata.

An operative artifact must add `Superseded by` or `Superseded in part by` when
that fact is necessary to avoid misuse. The pointer names the replacement and,
for partial supersession, its exact sections. Acceptance records continue to
name the maintainer and date where the existing process requires them.

Old historical files are not mass-retrofitted. Add a supersession pointer only
when a file is otherwise touched or is still likely to be mistaken for current
authority. No checker enforces lifecycle labels or header form.

## 6. Lifecycle and update rules

Updates attach to existing reviewed gates rather than to a new continuous
bookkeeping duty.

| Existing gate | Required design-memory update |
|---|---|
| Idea is parked | Add one horizon entry; do not add a roadmap promise. |
| RFC opens | Add or update one RFC pipeline row. |
| Synthesis acceptance | Mark the synthesis; update the decision bridge; route implementation; keep accepted unscheduled obligations in the RFC pipeline. |
| Superseding synthesis acceptance | Link the old and new exact sections and update the decision bridge. |
| Spike or audit close | Link the consumer, or park one unconsumed result or finding in the horizon. |
| Ticket cut opens | Update the packet README and roadmap pointer; `tickets.yml` owns all ticket detail; remove obligations that the cut now owns from the RFC pipeline. |
| Release closeout | Close the packet; compact the roadmap; update the front door and `AGENTS.md`; remove a decision-bridge row only while linking the exact contract heading that now carries its rule; verify that no ticketed obligation remains listed in the RFC pipeline. |
| Horizon item graduates | Move its content to the durable home and archive; retain its exact heading as a one-line redirect. |

This is a bounded amendment to both the stage-9 list item and the
`Post-synthesis horizon entry pattern` section of `rfc_cycle.md`. The horizon
stops being the durable home for accepted obligations. An obligation is a
later-work constraint that an accepted synthesis makes binding, such as a
`must`, a `before ticket cut` condition, or a named packet or cycle handoff.
Other deferred possibilities are speculation and may go to the horizon.
Accepted unscheduled obligations stay in the RFC pipeline until the ticket-cut
gate owns them or the maintainer explicitly drops them. Stages 1 through 8,
review rotation and all other RFC-cycle mechanics remain unchanged.

Nothing is silently superseded. If two binding sources conflict and neither
names supersession, work stops at that ambiguity and routes a correction. A
reader or agent must not infer authority from filename version, modification
time or proximity to the current release.

## 7. Definition of done by artifact

- **Contract:** states the normative rules the current release promises and
  ships; has no binding dependency on the roadmap or horizon; its topic is
  reachable through the H2 table of contents; code disagreements are routed
  with the contract standing provisionally; and conflicts between binding
  documents are resolved rather than hidden in an editorial rewrite.
- **RFC decision:** accepted synthesis or explicit rejection; decision bridge
  updated; implementation routed. A cycle may remain in the pipeline only as
  `Obligations open` until the ticket-cut gate owns every accepted unscheduled
  obligation or the maintainer explicitly drops the remainder.
- **Spike:** closeout names Green, Red or Inconclusive; evidence is
  reproducible; its consumer is linked or its unconsumed result is parked; no
  design is claimed as bound.
- **Audit:** findings are owned, rejected with a reason or routed to the
  horizon. `Routed` closes the audit without creating an audit backlog.
- **Spec packet:** release gate and closeout are complete; ticket states agree;
  roadmap, current-release links and implemented-decision links are updated.
- **Horizon item:** remains visibly parked, or its body is archived with its
  original heading retained as a promoted, refuted or dropped redirect.
- **Decision bridge row:** names exact operative sections and remains only
  while the answer is not consolidated into a standing binding document. Its
  removal record links the exact contract heading that received the rule.

## 8. Migration plan

### Stage 1. Establish the contract baseline

1. Find and read authority handoffs in the header and body, including phrases
   such as `authoritative`, `binding` and `remains binding` and paths to other
   design artifacts.
2. Inspect operative references to packets, syntheses, the roadmap and the
   horizon, and future or conditional language such as `until`, `will`,
   `planned` and `later`.
3. In each of the thirteen top-level sections, sample a few clauses against
   existing tests. This is not a clause-by-clause behavioral audit. A mismatch
   is a routed finding, not permission to edit the contract to match code.
4. Before removing the current header handoffs, list the normative `must`,
   `must not` and `binding` statements in the v0.1.9.5 packet and the named
   v0.1.8 strategy-preflight source. Confirm each statement is already in
   `contracts.md`, explicitly superseded or deliberately dropped.
5. Check that the released v0.2.0.0, v0.2.0.1 and v0.2.1.0 packets recorded
   their contract changes in `contracts.md`. Route a rule found only in a
   packet as a finding.
6. Classify findings as stale authority text, accepted-but-unimplemented
   direction, code-versus-contract disagreement or conflict between binding
   documents. Route the latter three through the proportionate existing
   process rather than repairing them editorially.
7. Once the outbound check supports it, replace the stale v0.1.9.5 authority
   statement with the normative-current-release role and add an H2-only table
   of contents. Preserve existing heading text and anchors.

### Stage 2. Establish the front door and bridge

1. Add `decisions.md` and `horizon_archive.md`.
2. Rewrite `inst/design/README.md` as the short front door, pointing to the
   normalized contract rather than assuming its authority in advance.
3. Make the operative roadmap, horizon and RFC-index status explicit in their
   existing free-text headers.
4. Do not move or rewrite historical RFCs.

### Stage 3. Amend stage 9 and separate the current indexes

1. Amend both the stage-9 list item and the `Post-synthesis horizon entry
   pattern` section of `rfc_cycle.md` so accepted obligations remain in the
   pipeline rather than gaining authority through the horizon.
2. Replace the decision catalogues in `inst/design/README.md` and
   `rfc/README.md` with the single decision bridge.
3. Keep active, due, deliberately parked and `Obligations open` cycles in the
   RFC pipeline.
4. Link exact source sections; do not create merged decision summaries.
5. Mark explicit supersession chains. Treat an unverifiable or conflicting row
   as a finding, not as a decision to repair by editorial judgment.

### Stage 4. Drain the mixed horizon

Count entries from the file when migration begins, then classify all of them.
At this review there are 171 entries under `Open` and 14 under `Resolved`; both
sections are in scope. Classifications are:

- still parked;
- promoted to accepted authority or committed roadmap scope;
- measured evidence belonging in research, an audit or a benchmark record;
- refuted; or
- dropped.

Never delete an entry body during this migration. Move resolved bodies to
`horizon_archive.md` and retain the exact heading in a historical-redirect
section of `horizon.md`.

Before moving a body, search it for obligation language such as `must`,
`before ticket cut`, `obligation`, `gate` and `owes`, then read the surrounding
text. The search is a review aid, not proof of completeness. Route accepted
unscheduled obligations through the RFC pipeline. Re-point operative documents
that treat the entry as binding, including the current `contracts.md`
reference to the 2026-09-29 design work, to the owning accepted source or
pipeline obligation. Released packets and historical syntheses are not edited;
their existing citations continue to resolve through the retained stubs.

### Stage 5. Compact the roadmap and current context

1. Keep detailed dependency planning for the current and next release.
2. Collapse completed releases to outcomes and links.
3. Move historical narrative, without rewriting it, to the existing planning
   history or the archive.
4. Classify misleading root documents such as old UX or model-routing plans as
   current, superseded or historical. Rename or move only when a status header
   and index link cannot remove the ambiguity.

### Stage 6. Close navigation and process gaps

1. Reconcile the existing research index without duplicating its findings.
2. Ensure consumed spikes and audits are linked from their consumer; route
   unconsumed material results to one horizon entry rather than a new ledger.
3. Update `AGENTS.md` only with the final navigation and authority rules,
   keeping it concise and operational.
4. Correct remaining prose that calls the horizon authoritative.

### Stage 7. Consider an optional link check

Only after the manual migration stabilizes, decide whether a link checker is
worth keeping. Its maximum scope is verifying local Markdown targets in
`inst/design/README.md`, `decisions.md`, `rfc/README.md` and `AGENTS.md`.

It does not detect duplicate topics, require headers, classify operative
artifacts, interpret horizon citations or enter the package test suite merely
because it exists. If ordinary Markdown tooling supplies the same result, add
nothing.

## 9. Review and implementation shape

This plan receives a Type 2 review before implementation. The reviewer should
attack whether the proposed surfaces are necessary, whether a simpler split
works, and whether the migration would leave two competing authorities.

If accepted, implementation is cut into five bounded workstreams:

1. contract census and normalization;
2. front door, decision bridge and minimal supersession metadata;
3. RFC-cycle stage 9 amendment and RFC pipeline;
4. horizon classification and migration; and
5. roadmap/current-context compaction, consumer links and optional link check.

Each workstream owns one coherence claim. The horizon migration is reviewed
separately because a wrong classification can lose a real obligation. Routine
link and header corrections do not create new design rounds.

The final review samples real topics rather than checking prose form. Starting
from `inst/design/README.md`, a reader should normally reach the current
binding answer within two links; every accepted unscheduled obligation should
appear in the RFC pipeline; an old horizon heading should still resolve; and a
superseded source should point to its operative replacement.

## 10. Explicit non-goals

This overhaul does not:

- change RFC stages 1 through 8, review modes, the spike protocol or ticket
  authority; stage 9 changes only as stated in Section 6;
- revive ADRs as a required process;
- replace Markdown with a database, YAML registry, site generator or service;
- create one file per decision;
- rename or reorganize the historical RFC and packet corpus;
- rewrite old evidence to match current truth;
- promote roadmap or horizon prose into package contracts;
- alter package behavior; or
- require every old document to satisfy the new header convention.

The intended result is smaller than a new governance system: one front door,
one temporary bridge for unconsolidated accepted decisions, one RFC pipeline
that does not lose obligations, one release roadmap and one honest parking lot.
