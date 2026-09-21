# RFC Synthesis v2: A Smaller Governance Loop After v0.2.0.1

**Status:** Draft; pending Type 1 final review and maintainer acceptance.
On acceptance it binds as a pilot for the next implementation packet only,
and becomes the default after the maintainer reviews that pilot. It
supersedes the rejected first synthesis, which remains as history.

**Date:** 2026-09-21. **Window:** none; this changes process, not code.

**Author:** Claude, synthesis author under the `rfc_cycle.md` rotation:
Codex wrote Seed v3 and the Seed v2 Type 2 review; Claude wrote the Type 2
response to v3 and the combined review of its revision. Final review belongs
to Codex, as Type 1.

**Reviewed HEAD:** `v0.2.0.2` at `a8fc555` for the first draft. The revised
Seed v3 it cites was committed after that draft, at the commit the pipeline
index records; its text is unchanged from the working-tree form read.

## 1. What this synthesis chooses

The question was: what is the smallest change to how humans and agents build
this package that keeps drift and hallucination on a leash, and what does it
cost to live under?

The answer chosen is Seed v3's: change who frames review, separate design
challenge from verification, and review coherent workstreams instead of
every batch. Remove routine artifacts without replacing them with a machine
layer. Seven findings from the review of the revised seed are resolved
below and one roadmap-mandated output the seed omitted is supplied. Three
synthesis-only choices in the first draft were returned by final review and
resolved by maintainer decision; Section 9 records them.

The cycle's diagnosis stands and is not restated: v0.2.0.1 applied one rigor
shape to everything, and the first governance round then did the same at a
higher level. The failure mechanism was that agents reproduce the shape of
their brief, and the seed author wrote the brief for their own adversary.

## 2. Decisions

### D1. Humans own the question

The maintainer writes every operative brief: review, response, and
synthesis. An agent may draft; a drafted brief says so, and the review it
produces stays provisional until the maintainer has reread brief and
response together and accepted the framing. A brief names its mode near the
top: `Type 1`, `Type 2`, or `Decision synthesis`. It asks a question; it does
not enumerate conclusions to confirm.

Why: this is the causal fix. Rejected: agent-authored briefs as default,
which is what produced the rejected synthesis.

### D2. Two review modes and one deciding stage

Type 2 asks whether the problem is framed correctly, the proposal is the
best response, its incentives are sane, and its cost and failure modes are
acceptable. Type 1 asks whether an accepted direction was implemented
faithfully, its evidence runs, and scope stayed contained. Synthesis is
neither: it weighs the challenge, chooses, and records what it rejected.

Every Type 1 review carries one standing question regardless of brief:
are the inputs the right inputs, and how does the reviewer know
independently of the author? A Type 1 reviewer who finds a design problem
returns `NEEDS_TYPE_2` and stops.

Why: Batch 13 was caught by a reviewer asking about the fixture unprompted;
verification by the author's oracle cannot catch a shared wrong input. The
standing question is the minimum that keeps Type 1 from collapsing into
rerunning the author's command. Rejected: one mode with a section template.

### D3. Workstreams, not batches

At ticket cut the maintainer groups tickets into workstreams, each sharing
one correctness or evidence claim, and names each workstream's review point
with a one-sentence reason in the ticket source. A normal workstream gets
one Type 1 review after implementation and before dependent work removes a
fallback, freezes evidence, or makes reversal hard. A workstream gets a
Type 2 review first when it chooses architecture, public semantics, an
oracle, or an evidence boundary, or any decision that passing the author's
tests would not prove good. The maintainer may merge or add review points.

Ticket cut keeps its one independent review. Its brief names both
questions explicitly and in order: verify spec-to-ticket coverage as Type 1,
then challenge the workstream grouping and review-point map as Type 2. D2
forbids disguising one mode as the other; a brief that names both is not
disguise, and under D1 the maintainer controls that both are asked.

Applied to v0.2.0.1: seven workstreams, correcting the seed's six. Witnesses
and test-only references (Batch 1); provider, writer, parity and retirement
(2-4); finalization and seal validators (5-6); benchmark meaning and manuals
(7 and 11); event buffers and valuation (8-9); dense timestamps and hash
deduplication (12-13); final evidence and release (14-15). Batch 0 is the
cut; Batch 10 is diagnostic history. That is one cut review, seven Type 1
reviews, and one Type 2 review of benchmark meaning: nine invocations against
twenty-six, or 0.35 per ticket.

Why: the cut from twenty-six to nine keeps review where corrections actually
happened. Rejected: the batch as automatic review unit; Seed v2's closed
category list, which produced disagreement between two careful readers on
the first packet it was applied to.

### D4. Keep less, but keep what changed the decision

`tickets.yml` is the one authoritative ticket source; any readable view is
generated. A batch produces no evidence essay; its record is ticket state,
commit, tests, and links to evidence with independent future value. The
packet has one closeout: what shipped, which claims are supported, what
remains open, and one line for each approach or record rejected and why.

An empirical release claim records input identity, environment, source
commit, reproduction command, result, and clock. A failed attempt or review
finding gets durable prose only when it changed a decision, invalidated a
plausible record, or constrains later interpretation; the note states the
consequence. Git is the ledger for committed states and is not claimed to
hold the reason an uncommitted or plausible-looking result was rejected.

Why: the response author, who wrote the evidence essays, found none that
discovered a defect; the rejections that mattered were discoverable because
someone wrote the reason down. Rejected: "Git holds the history"; deleting
all failure narrative; hard line caps enforced by test.

### D5. Withdrawn: no standing release profile

The first draft bound a documented-quickstart profile on every release.
Final review returned it: Seed v3 had considered and declined that
obligation, and the draft left its fixture, clock, repetitions, and
interpretation undefined. The maintainer struck it. The finding behind it
survives as a benchmark correction in Section 7, not as a process rule.

The roadmap's preference for executable checks is honored where it applies:
to claims about the package, where a command is the only thing an agent
cannot hallucinate. It does not govern agents, because Seed v2 and its
synthesis showed that a check on process form verifies conformance, not
independence. Rejected: the five-percent census, duplication scan,
per-batch profiles, guard-per-review, and a standing profile with undefined
terms.

### D6. Proportionate routes

The roadmap requires routes for a full RFC, a bounded spike, a direct
ticket, an audit, and a documentation chore. Under D2 and D3 they are:

- **Full RFC** when the work changes a contract, public semantics,
  authority, or an evidence boundary. Type 2 response is mandatory; the
  cycle's stages and rotation are unchanged.
- **Bounded spike** when an open question can be answered by running the
  package. `spike_protocol.md` governs: probe first, one question, one kill
  condition. Its findings feed an RFC or a ticket; they bind nothing.
- **Direct ticket** when the work implements an accepted direction. It joins
  a workstream and receives that workstream's Type 1 review.
- **Audit** when the question is about existing code or tests. It gets its
  own Type 2 brief, produces a table, and proposes tickets. The test-suite
  audit is one.
- **Documentation chore** when nothing semantic changes. No review, unless
  the document defines claims or clocks, in which case it is not a chore;
  Batch 7 is the example.

Why: mandated at `ledgr_roadmap.md:1673` and absent from every seed.
Rejected: leaving routes to precedent.

### D7. Implementation authority

Accepted contracts and specifications define ledgr's semantics. Canonical R
is the normative executable oracle for optimized and compiled
implementations. A faster implementation cannot establish correctness by
agreeing with itself or winning a benchmark. Oracle authority and runtime
default are separate: an optimized path may become the default after its
own accepted scope and differential evidence without displacing the oracle.
Exact contractual outputs compare exactly; existing tolerances are not
widened to admit a faster path. If canonical R conflicts with an accepted
contract or independent economic truth, the contract defect is resolved
first and canonical R corrected. An intentional divergence needs an RFC
naming outputs, independent oracle, reason, compatibility consequences, and
proof ownership; until accepted, divergence fails closed. Canonical R stays
runnable in a differential lane that the test-suite audit defines and
assigns ownership to; it need not be the default or run at full scale.

Why: mandated by the roadmap, and Seed v3's formulation meets every element.
Rejected: a faster path as its own oracle; oracle and default as one thing.

### D8. Pilot, gate, and failure conditions

This model applies to the next implementation packet only. The preregistered
gate is one condition: at most 0.5 independent review invocations per
completed ticket. The v0.2.0.1 baseline is 1.0; the retrospective estimate
is 0.35. Findings by type, and whether each changed an outcome, are recorded
for the pilot review to weigh; they are not a condition to pass, because a
correct packet must not fail for lacking defects. Fine ticket cutting to
meet the ratio is what the cut review's Type 2 question exists to catch.

The pilot records workstreams and review types; maintainer and agent turns
and heavy-command runtime attributable to governance; findings by type and
whether each changed an outcome; reruns, rejected records, and reopenings;
retained governance files and lines including linked notes; and disputed
classifications. It records these in the closeout, not in a new artifact.

The model is revised or abandoned if it misses the gate, if a Type 2 issue
again reaches synthesis as a checklist, if a material change escapes review
through workstream classification, or if a decision-changing failure becomes
undiscoverable.

Why: reversibility. Rejected: binding every future packet on acceptance; a
yield quota, which final review showed punishes correctness and rewards
manufactured findings.

### D9. The cost, priced

For a packet of v0.2.0.1's size: about nine review briefs, the workstream
grouping at cut, one Decision-synthesis brief per RFC, a reread of each
agent-drafted brief with its response, and the pilot review. Roughly twelve
to fifteen maintainer decision points, against twenty-six review invocations
and their briefs. The maintainer is the bottleneck by design; the
alternative encodes judgment in forms that are not independent.

## 3. Sequencing

The test-suite audit gates v0.2.0.2. Acceptance of this synthesis does not
open that packet; the audit must finish and receive explicit acceptance
first. The audit runs under D6 as an audit, with its own Type 2 brief.

## 4. Scope kept unchanged

The six non-negotiables remain: independent review at material design and
correctness boundaries; immutable or explicitly superseded empirical
evidence; visible failures, corrections, and abandoned approaches; scope
containment and explicit maintainer acceptance; executable semantic and
persistence invariants where practical; separate, honestly labelled cold,
warm, and peer clocks. D3 carries the first; D4 the second and third; D1
and D8 the fourth; existing tests the fifth; the existing benchmark
methodology the sixth. No v0.2.0.1 decision or historical artifact is
rewritten. This synthesis creates no package code, test, source guard,
benchmark, ticket, or standing artifact.

## 5. Process documents this binds

Each carries one decision. Wording is implementation work after acceptance,
not synthesis text.

- `AGENTS.md`: D1, and D4's bounded statement: the package is exact about
  provenance, identity, and evidence; the process that builds it keeps
  committed states in Git and a concise reason for any rejection that
  changed a decision, and does not reconstruct sessions.
- `rfc_cycle.md`: D2's modes and the `NEEDS_TYPE_2` route; D1's brief rule
  replacing the prompt-writing notes; D6's routes.
- `spike_protocol.md`: D6's spike route reference; budgets stay as stop
  signals, unenforced by test.
- The next packet's `batch_plan.md` template: D3 replaces "A batch is the
  independent review unit" with workstreams; D4 removes the evidence essay.
- `ledgr_roadmap.md`: D7 recorded as the resolution of the governance
  section's authority question; D8's pilot named against the next packet.

## 6. Rejected alternatives

Seed v2's mechanized model, for converting judgment into form checks that
verify conformance rather than independence. The three-sentence alternative
(human briefs, no essays, one ticket source, stop), for keeping sixteen
review points and failing the authority mandate. Blanket batch review, for
cost without proportionate yield. Removing all implementation review, for
Batch 13. A second human or rotating second reviewer of the maintainer's
briefs, as unavailable to a one-maintainer project. Hard line caps enforced
by a documentation test, for rewarding fragmentation.

## 7. Deferred to horizon

The peer benchmark's public-workflow claim has a known gap: it reads
`ctx$features_wide` while the documentation teaches `ctx$features()`, so
the taught idiom is unmeasured (horizon 2026-09-18). Closing it is a direct
ticket under D6 for the next packet: one benchmark row using the taught
idiom, inheriting the benchmark's fixture, clocks, and repetitions. It is a
correction to an existing claim, not a process rule. The code-health census,
duplication scan, and reachability guards as triggered audits under D6, not
release steps. The question of whether a
second reviewing human ever becomes available. The observation that this
cycle needed nine artifacts to change a process document, which the pilot
should show is not repeated.

## 8. What the final reviewer verifies

Type 1, by reading and counting, in one page: that D3's seven workstreams
cover every v0.2.0.1 batch that produced a correction; that D6 names all
five roadmap routes; that D8's gate is the single ratio; that D7 meets each
element of `ledgr_roadmap.md:1680-1687`; that Section 4 carries all six
non-negotiables; and that nothing here creates a test, guard, or standing
artifact. Then whether the synthesis is mutually consistent with Seed v3
where it did not deliberately overrule it. After final review and
maintainer decision, the overrulings that remain are the seven-workstream
count and the route taxonomy; the two cut briefs, the paired gate, and the
restored profile were withdrawn.

## 9. Revision history

- 2026-09-21 — Synthesis v2, Claude, from revised Seed v3, its Type 2
  response, and the combined review of the revision. Supersedes the first
  synthesis rejected the same day for converting decisions into form checks.
- 2026-09-21 — Revised after Codex's Type 1 final review returned three
  synthesis-only choices and two corrections, all accepted by maintainer
  decision: D8's yield quota struck; D3's second cut review withdrawn for
  one two-question brief, retrospective nine reviews at 0.35; D5 withdrawn
  as a rule and its finding routed as a benchmark-correction ticket in
  Section 7; Section 5's `AGENTS.md` wording aligned with D4; the revised
  Seed v3 committed separately after this synthesis.
