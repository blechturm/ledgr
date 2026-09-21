# RFC Seed v3: A Smaller Governance Loop After v0.2.0.1

**Status:** Revised replacement seed; non-binding. Supersedes Seed v2 for
further deliberation. Seed v2 and the rejected synthesis remain historical
evidence.

**Date:** 2026-09-21. **Release destination:** none; this changes process,
not package behavior.

**Author:** Codex, after the maintainer rejected the first synthesis and the
Type 2 review rejected Seed v2's direction.

**Next step:** Claude writes the synthesis from this revision and the completed
Type 2 response. The maintainer writes a `Decision synthesis` brief: weigh the
challenge, choose, and record what was rejected. It is neither a Type 1 nor a
Type 2 brief.

## The question

What is the smallest change to how humans and agents build this package that
keeps drift and hallucination on a leash, and what does it cost to live under?

The answer proposed here is: change who frames review, distinguish design
challenge from verification, and review coherent workstreams instead of every
batch. Remove routine artifacts and reviews without replacing them with a new
machine-enforced governance layer.

## Diagnosis

v0.2.0.1 did not suffer from too little rigor. It suffered from applying the
same rigor shape repeatedly: sixteen batches, fifteen completed after review,
at least 26 review invocations, fourteen batch evidence documents, duplicate
ticket sources, and a release record surrounded by more prose than checker
code. That cost produced real corrections, so deleting review wholesale would
be reckless.

The first governance round then repeated the same mistake at a higher level.
The response brief asked the reviewer to falsify claims by counting. Codex did
that. Seed v2 corrected the counts. The synthesis converted its proposals into
form checks. Final review verified the checks. Nobody had been assigned the
primary job of asking whether the proposed system was a good way to govern the
package.

The missing distinction is not narrative versus executable evidence. It is
**Type 2 design challenge versus Type 1 verification**:

- Type 2 asks whether the problem is framed correctly, the proposal is the
  best available response, its incentives are sane, and its failure modes and
  total cost are acceptable.
- Type 1 asks whether an accepted direction was implemented faithfully, its
  tests and evidence run, and scope stayed contained.

Both are necessary. They should not be disguised as one another.

Every Type 1 review carries one standing question regardless of its brief:
**Are the inputs the right inputs, and how does the reviewer know independently
of the author?** A Type 1 reviewer who encounters a design problem returns
`NEEDS_TYPE_2` and stops; the maintainer then writes a Type 2 brief.

## Proposed operating rule

### Humans own the question

The maintainer writes every operative review and synthesis brief. An agent may
suggest wording or collect evidence, but the brief does not become operative
until the maintainer has chosen the question, review type, evidence boundary,
and stopping point. An agent must not define the test by which its own design
will be challenged.

If an agent drafts a brief, the brief says so. Its review remains provisional
until the maintainer rereads the brief and response together and explicitly
accepts the question framing. This reduces but cannot remove rubber-stamp risk.

Briefs stay question-first. They may name non-negotiables and required source
material, but they do not enumerate the conclusions the reviewer is expected
to confirm. The brief must say `Type 1` or `Type 2` near the top.

This is the main new human cost. The maintainer cannot delegate the framing of
the difficult judgment and still expect independent thought.

### Review workstreams, not batch numbers

At ticket cut, the maintainer groups tickets into coherent workstreams and
names the review point for each workstream. A workstream is a set of changes
that shares one correctness or evidence claim and can be judged together.
Batch boundaries remain useful for sequencing; they stop being automatic
review boundaries.

Ticket cut retains one independent review. It verifies spec-to-ticket coverage
as Type 1 work and challenges the workstream grouping and review-point map as
Type 2 work. This is the second perspective on the highest-leverage
classification in the model.

The normal workstream receives one Type 1 review after its implementation and
before dependent work removes a fallback, freezes evidence, or makes the change
hard to reverse. A workstream receives a Type 2 review first when it chooses or
changes architecture, public semantics, an authoritative oracle, a benchmark
or evidence boundary, or another decision for which passing the author's tests
would not prove that the decision is good.

The maintainer may combine adjacent workstreams or add a review point. The
ticket source records the reason in one sentence. There is no closed category
list pretending to remove judgment.

Applied retrospectively, v0.2.0.1 becomes about six workstreams: provider,
writer, parity and retirement (Batches 2-4); finalization and seal validators
(5-6); benchmark meaning and manuals (7 and 11); event buffers and valuation
(8-9); dense timestamps and hash deduplication (12-13); and final evidence and
release (14-15). One ticket-cut review, six Type 1 workstream reviews, and one
Type 2 benchmark review are about eight reviews and eight maintainer briefs,
or 0.31 review invocation per ticket, against at least 26 invocations in the
released packet. This is an estimate of the proposed shape, not a guarantee.

### Keep less, but keep what changed the decision

Future packets use `tickets.yml` as the one authoritative ticket source. A
human-readable ticket view may be generated, but it is not separately edited.

A batch does not create an evidence essay by default. Its durable record is the
ticket state, implementation commit, tests, and links to any evidence that has
independent future value. The packet has one concise closeout explaining what
shipped, which claims are supported, what remains open, and one line for each
approach or record rejected and why.

An empirical release claim records its input identity, environment, source
commit, reproduction command, result, and clock. A failed attempt or review
finding gets durable prose only when it changed a decision, invalidated a
plausible record, or constrains how later evidence may be interpreted. That
note states the consequence; it does not reconstruct the whole session.

Git remains the ledger for committed states. It is not treated as a substitute
for the reason an uncommitted or plausible-looking result was rejected.

### Do not automate governance to compensate for weak framing

This seed rejects Seed v2's mandatory per-hot-path-batch profiles, release-wide
five-percent profile census, normalized-body duplication scan, hard artifact
line caps, and rule that every boundary review must leave a new test. Each can
be useful when its question calls for it; none is a universal governance rule.

Profile when performance is an acceptance criterion, a stable benchmark shows
a regression, or a change has a credible scale risk. Run complexity and test-
suite audits as their own bounded work, with their own Type 2 question, rather
than hiding them inside every release gate. A new permanent guard must protect
a named recurrence risk and be cheaper to maintain than the failure it blocks.

Document budgets remain stop signals. Over-length work is edited or split when
that improves comprehension, not because a physical-line test fails.

## Implementation authority

Accepted contracts and specifications define ledgr's semantics. Canonical R is
the normative executable oracle for optimized and compiled implementations of
those semantics. A faster implementation cannot establish correctness by
agreeing with itself or by winning a benchmark.

Oracle authority and runtime default are separate. An optimized implementation
may become the runtime default after its own accepted scope and differential
evidence without displacing canonical R as the reference. Exact contractual
outputs compare exactly; existing contract tolerances remain tolerances and
may not be widened merely to admit an optimized path.

If canonical R conflicts with an accepted contract or independently established
economic truth, the contract-level defect is resolved first and canonical R is
corrected. The optimized path then follows. A proposed intentional divergence
requires a new RFC that names the affected outputs, independent oracle, reason,
compatibility consequences, and proof ownership. Until that RFC is accepted,
divergence fails closed.

Canonical R must therefore remain runnable in the focused differential lane.
It need not be the production default or be rerun at full scale for every
release. The test-suite audit must preserve and assign ownership to that lane.

## What it costs to live under

The recurring obligations are deliberately few:

1. The maintainer writes the brief and chooses Type 1 or Type 2.
2. Ticket cut records workstreams, their review points, and one-sentence
   reasons.
3. Each workstream pays for one independent Type 1 review; only directional
   work pays for Type 2 before implementation.
4. Release-significant empirical claims pay for a reproducible record.
5. Decision-changing failures pay for a short durable explanation.

The system spends scarce human attention rather than creating automatic checks
to simulate it. That makes the maintainer a bottleneck and leaves judgment in
the process. Those are real costs. The alternative is to encode imperfect
judgment in expanding forms and tests, which Seed v2 showed is not free and is
not actually independent.

There is no mandatory profile or code-health census for an ordinary release,
no review per batch, no batch evidence essay, and no second ticket authority.

## Scenario test against the Type 2 review

| Scenario | Proposed behavior | Where this design still fails |
| --- | --- | --- |
| Routine internal cleanup off a hot path | One workstream, tests, one Type 1 review; no essay or profile. | A subtle architectural consequence can be missed if the maintainer wrongly treats it as routine. |
| Prepared-provider hot-path rewrite | Targeted profile because performance is an acceptance claim; Type 1 differential review after implementation. Type 2 only if representation or oracle direction is still open. | The distinction between implementation and architecture remains judgment; the system cannot automate it honestly. |
| Batch 13 wrong frozen fixture | Type 1 brief requires the reviewer to establish fixture identity independently, not merely rerun the author's checker. The rejection consequence is recorded. | If the maintainer's brief repeats the same wrong fixture assumption, reviewer and author can still share the error. |
| Batch 7 clock definitions | Type 2 review occurs when benchmark meaning and permitted claims are chosen, even if the diff is documentation. | A mislabeled "documentation chore" can bypass the gate; file type is not a reliable risk signal. |
| Failed uncommitted benchmark changes direction | Preserve a short decision note and the retained record if safe; Git alone is not claimed to contain it. | Someone must notice that the failure changed direction. Trivial-looking failures can still disappear. |
| Ordinary release with no performance objective | No mandatory census; existing targeted tests and chosen workstream reviews run. | Slow performance or duplication drift can accumulate until a benchmark, profile, or scheduled audit exposes it. This is an accepted trade-off. |
| Compiled implementation diverges from canonical R | Divergence fails unless a separate RFC supplies an independent oracle; runtime-default evidence cannot transfer authority. | Canonical R itself can be wrong. The written contract and independent economic evidence must remain above it. |
| Reviewer or agent confidently hallucinates | Independent author, human-owned brief, citations, and maintainer acceptance provide multiple perspectives. | Independence reduces correlated error; it does not eliminate it. A persuasive but wrong Type 2 argument can still win. |
| Maintainer delegates a brief under time pressure | The agent-drafted brief is marked and the resulting review remains provisional until framing and response are read together. | A rushed maintainer can still rubber-stamp both; the process makes that risk visible but cannot prevent it. |
| Type 1 review discovers a design problem | Reviewer returns `NEEDS_TYPE_2` and stops; the maintainer writes a Type 2 brief. | The extra round costs time, and a reviewer can still misclassify the issue as implementation detail. |

The common residual failure is maintainer misclassification. This proposal does
not hide that fact behind a taxonomy. Its defense is a small number of visible
decisions, independent perspectives, and reversibility.

## Pilot and failure conditions

Apply this model to the next implementation packet only. It becomes the default
after the maintainer reviews the pilot; it is not permanent on seed acceptance.

The preregistered numerical gate is at most 0.5 independent review invocation
per completed ticket. v0.2.0.1's baseline is about 1.0; the retrospective
workstream estimate is about 0.31. Missing the gate revises the model even if
the maintainer believes the packet felt lighter.

The pilot records, without a new evidence essay:

- workstreams, review types, and review invocations;
- elapsed maintainer/agent turns and heavy-command runtime attributable to
  governance;
- Type 1 and Type 2 findings and whether they changed an outcome;
- reruns, rejected records, and post-acceptance reopenings;
- retained governance files and total lines, including linked notes and
  checker code; and
- cases where the review type or workstream boundary was disputed.

Revise or abandon the model if it does not materially reduce review/artifact
load, if a Type 2 issue again reaches synthesis as a checklist, if a material
change escapes review because of workstream classification, or if a decision-
changing failure becomes undiscoverable. A lighter process that cannot survive
those failures is merely less visible, not better.

## Scope kept unchanged

The roadmap's six non-negotiables remain. No v0.2.0.1 product decision or
historical artifact is rewritten. The current test-suite audit remains a
separate workstream and may recommend its own RFC and refactoring; this seed
does not predetermine its findings. Existing cold, warm, and peer clock rules
remain binding.

The test-suite audit is a gate for v0.2.0.2. Acceptance of the governance
synthesis alone does not authorize that packet to open; the audit must finish
and receive explicit maintainer acceptance first.

This seed changes the division of responsibility, review unit, and default
artifact set. It creates no package code, ticket, test, source guard, benchmark,
or new standing ceremony.

## Evidence and provenance

Inputs are the roadmap governance section (`ledgr_roadmap.md:1653-1766`), Seed
v2, its response and response review, the rejected synthesis and final review,
the v0.2.0.1 batch plan and final evidence, and
`rfc_governance_review_post_v0_2_0_1_seed_v2_type_2_review.md`. The revision
also incorporates
`rfc_governance_review_post_v0_2_0_1_seed_v3_response.md` and the maintainer's
decision that the test-suite audit gates v0.2.0.2.

**SEED_V3_DISPOSITION: REVISED_AND_READY_FOR_SYNTHESIS**
