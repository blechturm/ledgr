# Type 2 Response: Post-v0.2.0.1 Governance Seed v3

**Status:** Adversarial design response; input to synthesis or a revised
seed. **Respondent:** Claude. **Date:** 2026-09-21.
**Responds to:** `rfc_governance_review_post_v0_2_0_1_seed_v3.md` at
`05f66dc`. Context: the roadmap governance section, the Seed v2 Type 2
review, and the rejected synthesis.

**Review mode:** Type 2. This judges the proposed system, not its sentences.

## Verdict

**REVISE_THEN_SYNTHESIZE.** The shape is right and it is the first proposal
in this cycle that removes more than it adds. It should be accepted in
substance. It has one structural weakness that its own scenario table admits
but does not repair, and one decision it needs to make and does not: whether
accepting this seed unblocks v0.2.0.2 or the test-suite audit still gates it.
Both fixes are sentences, not mechanisms. Nothing here argues for rejection.

## Is it the smallest workable change?

Nearly. The test is a simpler alternative: **humans write the briefs, delete
batch essays, keep one ticket source, and stop.** Three sentences, no
workstream concept, no Type 1/Type 2 vocabulary, no authority section, no
pilot. It fixes the causal mechanism of this cycle's failure, because the
seed author briefed the adversary and the adversary reproduced the brief's
shape. It removes most of the bulk.

It fails in two places, and those failures are exactly the additions v3
makes. It keeps the batch as the review unit, so v0.2.0.1's sixteen batches
stay sixteen review points; the workstream rule is what cuts that. And it
does not settle implementation authority, which the roadmap mandates in
terms that forbid deferral. The Type 1/Type 2 naming costs one word per
brief and prevents the specific failure that sank the synthesis. The pilot
costs a list. So v3 is the simpler alternative plus the four things that
alternative cannot do without. That is close to minimal.

What v3 should have done and did not is show the arithmetic. Regroup
v0.2.0.1 into workstreams under its own rule: provider, writer, parity and
retirement (Batches 2-4) share one claim; finalization and seal validators
(5-6) share persistence; benchmark boundary and manuals (7, 11) share
evidence meaning and are Type 2; event buffers and valuation (8-9) are the
hot-path amendment; dense timestamps and hash dedup (12-13) are exact
parity; final evidence and release gate (14-15) are Type 1 verification.
Six workstreams, roughly eight reviews against twenty-six invocations, and
eight briefs for the maintainer to write rather than twenty-six. That
number is the seed's own case for itself, and its absence is the one place
"smallest" is asserted rather than shown.

## The structural weakness: Type 1 is only as independent as the brief

The Seed v2 Type 2 review's sharpest finding was B2: a reviewer who reruns
the author's check verifies by the author's oracle and cannot catch a shared
wrong input. Batch 13 was caught because a reviewer, unprompted, asked
whether the fixture was the right fixture.

v3's repair is in its Batch 13 scenario row: "Type 1 brief requires the
reviewer to establish fixture identity independently." The catch now depends
on the maintainer remembering to write that sentence into the brief. The
same row admits it: "If the maintainer's brief repeats the same wrong fixture
assumption, reviewer and author can still share the error."

That moves the locus of the catch from reviewer initiative to maintainer
foresight, and makes it contingent on a document one person writes under
time pressure. For the one class of defect that justified keeping review at
all, v3 has made independence weaker, not stronger. The old six-section
format, for all its bloat, had a containment section that made every
reviewer look at inputs whether or not anyone thought to ask.

The repair is one standing question that every Type 1 review carries
regardless of brief: **are the inputs the right inputs, and how does the
reviewer know independently of the author?** One question is not a
checklist. It is the minimum that keeps Type 1 review from collapsing into
rerunning the author's command, which is what B2 showed and what v3's own
table concedes.

A second standing route, equally cheap: a Type 1 reviewer who finds a design
problem returns `NEEDS_TYPE_2` and stops. v3 has no path from verification
back to challenge. This cycle's final review found nothing wrong with a
synthesis that was wrong in kind, partly because its brief gave it no way
to say so.

## The decision v3 does not make

The roadmap makes the test-suite audit a named workstream of this review,
with a scope that dwarfs the process half: three lanes, CRAN, a test
taxonomy, testing documentation, and compiled execution as a case study. It
then says: "No new implementation packet opens until this governance review
is resolved."

v3 says the audit "remains a separate workstream and may recommend its own
RFC." That is the right scoping. But it leaves the sequencing question open:
if the audit is chartered separately, does accepting v3 resolve the
governance review for the purpose of that roadmap sentence, or does
v0.2.0.2 stay blocked until the audit reports? The maintainer has already
scheduled v0.2.0.2 and said the audit runs first. v3 should say which
reading it takes, in one sentence, because a synthesis cannot invent it and
the answer decides when product work resumes.

## Two smaller gaps, each a sentence

**"Keep what changed the decision" needs someone to notice at the time.** v3
routes durable prose to failures that "changed a decision, invalidated a
plausible record, or constrains how later evidence may be interpreted." The
agent that hit the failure decides, under a brief that says keep less; the
incentive runs toward silence. v3's own row admits trivial-looking failures
can disappear. The closeout v3 keeps lists "what shipped, which claims are
supported, and what remains open." Add "what was rejected and why" — one
line per rejection, not a narrative — and most of the Seed v2 review's B5
closes without ceremony.

**The pilot's failure conditions have no number.** "Does not materially
reduce review/artifact load" is a judgment by the same bottleneck the pilot
exists to test. The measures list is good; one of them needs a threshold
before the pilot starts. Governance lines per ticket in v0.2.0.1 were about
7,695 over 26, roughly 300; review invocations per ticket were 1.0. Naming
either as the bar to beat makes the pilot falsifiable. Without it the pilot
review is another brief the maintainer writes to themselves.

## Is Type 1 / Type 2 separated at the right points?

Yes for the two places that matter: the RFC response is Type 2 and the final
review is Type 1; directional workstreams get Type 2 before implementation
and Type 1 after. That is the correct order and it is where this cycle
failed.

One stage has no type: **synthesis.** In this cycle the synthesis was the
failure point, and it is neither challenge nor verification; it chooses.
Its brief should say so — weigh the response's challenge, choose, and record
what was rejected — because a synthesis briefed as Type 1 fills a template,
which is what happened.

## Is the canonical-R authority decision sound?

Yes, and it is the best-argued part of the seed. It meets every element the
roadmap requires: canonical R is the normative oracle; oracle authority is
separate from runtime default; a permitted divergence needs its own RFC
naming outputs, oracle, reason, compatibility, and proof ownership; and
divergence fails closed until then. The two refinements that make it sound
rather than merely compliant are that canonical R can itself be wrong, with
contract-level defects resolved first, and that existing tolerances are not
widened to admit a faster path. Both are the right calls. The only thing to
add is that "runnable in the focused differential lane" is a commitment the
test-suite audit must honor, so the two workstreams should reference each
other.

## The stronger alternative

v3 plus the five sentences above: ticket cut retains its independent review
so the workstream grouping gets a second perspective; Type 1 carries one
standing input-identity question; `NEEDS_TYPE_2` exists; the closeout lists
rejections; the pilot names one number. Each closes a gap v3's own scenario
table admits, none adds a mechanism, and together they cost perhaps a
paragraph in the seed.

On ticket cut specifically: v0.2.0.1 reviewed its cut independently, and v3
makes workstream grouping and review-point assignment a maintainer decision
recorded in one sentence. That assignment is now the highest-leverage
classification in the whole system, and v3 is silent on whether anyone
other than its author looks at it. If the cut review is retained, the
grouping gets an adversary; if not, the seed's admitted residual failure —
maintainer misclassification — has no check at the one moment it could be
caught. Retaining a review that already exists is not new ceremony.

A genuinely stronger structural alternative — a second human, or a
rotating second reviewer of the maintainer's briefs — is not available to a
one-maintainer project and is not proposed.

## Scenarios

v3's eight rows are honest and I accept them as written, including the
admitted failures. Two scenarios are missing and both matter.

| Scenario | v3 behavior | Where it fails |
| --- | --- | --- |
| Maintainer delegates a brief to an agent under time pressure | The rule says "must not." Real use will. | An agent-drafted brief that the maintainer accepts unread reproduces this cycle exactly. v3 needs to say either that a delegated brief is marked and its review is provisional, or that the risk is accepted. |
| A Type 1 review discovers a design problem | No route back to Type 2. | The reviewer either overreaches into design under a verification brief or stays silent. This cycle's final review stayed silent. `NEEDS_TYPE_2` is the route. |

Applied to v3's own Batch 13 row with the standing question added: the
reviewer checks input identity because every Type 1 review does, not because
this brief happened to say so. The row's admitted failure — brief and author
share the assumption — narrows to the case where the maintainer, the author,
and a reviewer asking the standing question all miss it. That is the
independence the seed claims and does not yet deliver.

## Incentives and failure modes in use

**Maintainer fatigue.** Briefs get shorter and vaguer; reviews get shallower.
v3's pilot tracks "findings that changed an outcome," which would show it.
Adequate.

**Under-recording.** Under "keep less," agents will not write up failures.
The closeout rejection line is the mitigation; v3 lacks it.

**Grouping drift.** Agents draft ticket cuts. Workstreams will be proposed
to minimize review points. The cut review is the mitigation; v3 is silent.

**Type 2 avoidance.** Type 2 briefs are harder to write than Type 1, so the
default will drift toward Type 1. The pilot's Type 1/Type 2 findings count
makes zero Type 2 visible. Adequate, if the number is looked at.

**The bottleneck itself.** v3 names it and does not price it. The workstream
arithmetic above prices it: about eight briefs per packet the size of
v0.2.0.1, not twenty-six. That is a defensible load. v3 should say so.

## Disposition

Accept the direction. Revise the seed with: the workstream arithmetic; the
standing Type 1 input question and the `NEEDS_TYPE_2` route; the closeout
rejection line; one pilot number; the ticket-cut review retained explicitly;
the synthesis brief typed; the two added scenarios; and the one-sentence
answer on whether acceptance unblocks v0.2.0.2. Then synthesize. Every item
is a sentence in the seed and none adds a check, a test, or a standing
artifact.

**TYPE_2_RESPONSE_DISPOSITION: REVISE_THEN_SYNTHESIZE**
