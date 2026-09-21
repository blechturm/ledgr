# ledgr RFC Cycle

**Status:** Current as of three completed cycles (OMS, walk-forward, public transaction-cost API). Revise after the next cycle if the pattern shifts. Not a binding methodology -- a reference card.

**Audience:** the maintainer and any LLM agent (Codex, Claude, future) about to start or continue an RFC cycle.

**Purpose:** capture the discipline rules and stage shape we've converged on, so the next cycle doesn't re-derive them under time pressure.

The cycle is deliberately Hegelian in shape: thesis, antithesis, synthesis. In
LLM-assisted design this is an epistemic control mechanism, not ceremony. Each
stage assigns a different model instance a different failure mode, preserves the
disagreement trail, and only then binds decisions.

---

## The cycle stages

Each RFC cycle produces a sequence of artifacts. Not every cycle needs every stage; flag which are skipped and why.

```text
1. research input            (optional, non-binding)
2. seed v1                   (one author)
3. response                  (different author)
4. response review           (maintainer or original seed author)
5. seed v2                   (if findings warrant; otherwise skip to synthesis)
6. maintainer decisions      (only for product-level binary choices)
7. synthesis                 (different author from v2)
8. final review              (verification, not design)
9. horizon entry             (post-synthesis durable home for deferrals)
```

Examples from completed cycles:

- **OMS RFC** had stages 2, 3, 5 (in-place), 5 (in-place again), 7. Stages 4 and 8 were missed; we paid for both.
- **Walk-forward RFC** had stages 1, 2, 3, 4, 5, 7, 8, 9. Stage 8 final-review plus Amendment 1 added 2026-06-04 after the synthesis was accepted; Amendment 2 and Section 17 ticket-cut gates added 2026-06-04 after a post-Amendment-1 review identified that four of the seven Amendment 1 routings were procedural rather than substantive. See `rfc_walk_forward_evaluation_v0_1_9_x_final_review.md` (closure update section) and synthesis Sections 14, 16, 17.
- **Cost-API RFC** had stages 1, 2, 3, 4, 5, 6, 7, 8, 9. Cleanest of the three.

The walk-forward and cost-API shapes are the model.

Research input may be disposable when it is only a quick scan. It should be
kept as a durable artifact when it contains source review, literature claims, or
evidence that later RFC stages cite.

---

## File naming conventions

Use versioned suffixes for major revisions. Don't edit prior artifacts in place during contested phases.

```text
rfc_<topic>_<window>_seed.md                  v1 seed, historical after v2
rfc_<topic>_<window>_seed_v2.md               revised seed after response findings
rfc_<topic>_<window>_response.md              response-stage adversarial review
rfc_<topic>_<window>_maintainer_decisions.md  only for escalated product choices
rfc_<topic>_<window>_synthesis.md             binding artifact
```

Patch the same file in place only for:

- typos, formatting, citation fixes;
- post-synthesis bug fixes caught during final review (with a clear revision note);
- resolving in-line maintainer decisions where the file itself asked for the resolution (e.g., cost-API v2 Section 17 open questions Q1 and Q2 were resolved in v2 in-place because v2 escalated them).

Otherwise: new file.

---

## Role rotation

When possible, the seed author and the synthesis author are different LLMs. The response author is a third perspective on the seed. The pattern that worked across three cycles:

```text
seed v1       Codex or Claude
response      the other one
seed v2       same as v1 (incorporates findings, owns architectural intent)
synthesis     the one who didn't write v2
final review  the one who didn't write the synthesis
```

The cost-API cycle ran exactly this rotation and produced the cleanest pair (v2 + synthesis). The OMS cycle had the same author writing seed and revisions and incurred the audit-trail problem.

Maintainer is always the final authority and may override role rotation when context-window or coherence requires it.

---

## The "v1 / first implementation" naming convention

RFCs commonly use "v1" internally to mean "the first implementation of *this feature*," not "ledgr v1.0.0" (which on the roadmap means small-scale live trading).

Convention: when an RFC uses "v1" in this internal sense, the synthesis or v2 seed should include a one-line disclaimer:

> "This RFC uses 'v1' as shorthand for the first implementation of [feature]; ledgr's roadmap does not have a [feature] v1 milestone. Post-v1 work lives in named follow-up RFCs at their own roadmap windows."

Walk-forward and cost-API both ended up adding this disclaimer mid-cycle after the maintainer flagged the confusion. Add it upfront in future cycles.

---

## Pre-CRAN-no-users framing

ledgr is pre-CRAN with no external users. This lowers several common design
costs that would matter for a mature CRAN package, but it does not make those
costs disappear automatically.

- "preserve existing user research" - usually phantom unless the maintainer has
  explicitly named local research artifacts as compatibility targets;
- "migration cost for stored configs" - usually phantom for external users, but
  still check maintainer-owned stores and accepted artifact examples;
- "documentation churn for first-contact users" - often measured in roxygen and
  internal code, but still check README, vignettes, pkgdown pages, and release
  examples before treating it as negligible;
- "user mental models" - no external users, but accepted docs can still create
  maintainer-facing mental models that should be changed deliberately.

When an RFC defers a decision on grounds that fall into these categories, name
the assumption explicitly and verify it. If the cost is external-user
compatibility only, pre-CRAN status usually makes it small. If the cost is
internal coherence, code surface, accepted examples, or maintainer workflow, it
still matters.

The cost-API cycle is the example: once the no-external-users framing was made
explicit, both escalated decisions flipped. That was correct for that cycle, but
the rule is not "break freely." Internal coherence, code-citation accuracy, and
roadmap alignment still matter. Pre-CRAN rules out external user-breakage cost;
it does not rule out internal-code cost.

---

## Open questions vs future obligations

Two different artifact categories with different lifetimes.

**Open questions** are decisions for the next spec-cut writer, within the same roadmap window:

- "what's the v1 default for `opening_state_policy`?"
- "should we accept the legacy scalar shape for one transitional release?"
- "what's the per-fold telemetry budget?"

They live in the synthesis's "Open Questions Promoted to Spec-Cut" section. They get resolved when tickets are cut. They are not RFC work.

**Future obligations** are concerns that require a separate RFC cycle in a later roadmap window:

- "diagnostic retention tiers will need return-series storage";
- "walk-forward identity must include cost_model_hash once cost API lands";
- "stateful fee tiers need a cost-state envelope".

They live in the synthesis's "Future Obligations Recorded" section. They become RFC seeds when the relevant cycle opens. They are RFC work, just not this cycle's.

Don't mix them. An open question that's really a future obligation will get punted endlessly; a future obligation that's really an open question will block ticket cut waiting for an RFC that doesn't need to happen.

---

## Post-synthesis horizon entry pattern

When a synthesis is accepted, the post-cycle direction goes into one horizon entry. The pattern is now consistent across walk-forward and cost-API:

```text
### YYYY-MM-DD [tag] <Topic> post-<window> direction

One paragraph: synthesis name, brief framing, what "v1" means in shorthand.

Group deferrals into 4-7 themes (e.g., "stateful fee modeling",
"multi-asset assignment", "TCA and reporting"). Each theme is 2-5 bullets
naming the deferred capability and what RFC would own it.

A "Promoted roadmap hooks" subsection listing 5-12 follow-up RFCs with
target windows (e.g., "v0.2.x, when multi-asset portfolios become common").

A separate "Immediate cross-cycle obligations" subsection for handoffs that
are spec-packet-level, not horizon-level (e.g., "walk-forward spec packet
must extend candidate_key to include cost_model_hash"). These obligations
go to the next concrete spec packet, not into horizon waiting indefinitely.

Closing one-paragraph disclaimer: "this entry does not authorize any of the
above; it records the direction."
```

The horizon entry is the durable home for "what comes after this synthesis." The synthesis itself stays binding for the immediate window; the horizon entry takes the rest.

---

## Final review scope

After synthesis, run a final-review pass before committing or starting ticket-cut. The final review is **verification, not design**:

- check that v2 and synthesis are mutually consistent;
- check that the synthesis's load-bearing claims hold against the actual code (cite line numbers);
- check that decision-note resolutions are reflected in v2 and synthesis;
- check that referenced helpers and surfaces actually exist;
- check the math on any worked example.

The final review does not:

- open new design space;
- re-litigate decisions;
- propose new architecture;
- edit any artifact.

When the final review finds bugs, the patches go in-place on the synthesis (or v2 if the bug is there), with the revision note updated. If a final review finds something that genuinely requires a new design round, escalate to maintainer rather than silently expanding scope.

**Amendment discipline (added 2026-06-04 after walk-forward closure).** When a final review's findings route to maintainer amendments on open spec-cut questions rather than corrections of bound text, the amendment must bind either (a) a substantive default, operational contract, or forbidden-list that forecloses the original concern; or (b) a ticket-cut gate matrix that names the packet-open and release-gate acceptance criteria for the procedural constraint; or both. Procedural constraints alone ("the spec-cut writer must justify X", "the design must address Y") are insufficient closure because they hand the substantive decision back to the moment the amendment was meant to constrain. The walk-forward cycle's Amendments 1 and 2 with Section 17 ticket-cut gates are the reference implementation of this discipline.

The cost-API final review found three real patch requests (fold-core touchpoint
mislabeled "no changes"; fill_model rename touchpoint list incomplete; v2
section 0 superseded text still in present tense) and one informational item
(metrics-and-accounting vignette teaches legacy convention). All were small
document patches, none reopened design.

---

## Review modes, workstreams, and routes

Accepted 2026-09-21 (`rfc/rfc_governance_review_post_v0_2_0_1_synthesis_v2.md`,
D2, D3, D4, D6, D8). Binding as a pilot for the next implementation packet;
the maintainer promotes, revises, or abandons it after that packet's closeout.

**Two modes.** `Type 2` asks whether the problem is framed correctly, the
proposal is the best response, its incentives are sane, and its cost and
failure modes are acceptable; the RFC response stage is Type 2. `Type 1` asks
whether an accepted direction was implemented faithfully, its evidence runs,
and scope stayed contained; final review is Type 1. Synthesis is neither: it
weighs the challenge, chooses, and records what it rejected. Every Type 1
review carries one standing question regardless of brief: are the inputs the
right inputs, and how does the reviewer know independently of the author? A
Type 1 reviewer who finds a design problem returns `NEEDS_TYPE_2` and stops.

**Workstreams, not batches.** At ticket cut the maintainer groups tickets into
workstreams, each sharing one correctness or evidence claim, and records each
ticket's workstream, review mode, review point, and a one-sentence reason in
`tickets.yml`, the sole ticket authority; the batch plan renders that map as a
table and is not separately edited. Ticket cut keeps one independent review
whose brief asks, in order: does every accepted requirement have an owner
(Type 1), and are the grouping and review points sensible (Type 2). A normal
workstream gets one Type 1 review after implementation and before dependent
work removes a fallback, freezes evidence, or makes reversal hard; a
workstream gets Type 2 first when it chooses architecture, public semantics,
an oracle, or an evidence boundary. Batches sequence work; they are not review
units and produce no evidence essay. The packet closeout records what shipped,
which claims are supported, what remains open, one line per rejected approach
or record, and the pilot counters: review invocations per completed ticket
(gate: at most 0.5), findings by mode and whether each changed an outcome,
reruns and rejected records, and disputed classifications.

**Routes.** Full RFC when work changes a contract, public semantics,
authority, or an evidence boundary; Type 2 mandatory, stages and rotation as
above. Bounded spike when an open question can be answered by running the
package; `spike_protocol.md` governs and findings bind nothing. Direct ticket
when work implements an accepted direction; it joins a workstream. Audit when
the question is about existing code or tests; its own Type 2 brief, a table,
proposed tickets. Documentation chore when nothing semantic changes; no
review unless the document defines claims or clocks, in which case it is not
a chore.

---

## Briefs

The maintainer writes every operative brief: review, response, and synthesis
(accepted 2026-09-21, governance synthesis v2, D1). An agent may draft one; a
drafted brief says so, and the review it produces stays provisional until the
maintainer has reread brief and response together and accepted the framing.
An agent must not define the test by which its own design will be challenged.

A brief names its mode near the top — `Type 1`, `Type 2`, or `Decision
synthesis` — asks a question, may name non-negotiables and required reading,
and does not enumerate the conclusions the reviewer is expected to confirm.
Short beats specified: the briefs that produced this repository's best
artifacts fit in ten lines, and the one that produced its worst was the
longest and most prescriptive. Agents reproduce the shape of their brief.

Three properties still hold from earlier cycles: open-ended on next step;
code citations expected, which catches phantom claims; constrained on scope.
Briefs are not durable artifacts and are not templated.

---

## Spikes inside a cycle

A seed may propose a spike; it may not charter one. The charter is written
after the probe in `spike_protocol.md` section 1 and is returned unread if it
fails the smell test in section 8. The seed author does not write the
charter. Earlier spikes ran 50 to 3,100 lines of markdown in one to thirteen
files; the asset-availability spike (v0.1.9.8) ran a 690-line charter, a
927-line seed, a 1,351-line response, 5,082 harness lines, and 938
pre-authored expected rows, and closed inconclusive. The budgets in
`spike_protocol.md` exist because of it.

---

## When to skip stages

- **Skip the research input** when prior art is already well-covered in the RFC corpus (e.g., a follow-up RFC to an accepted synthesis where the parent synthesis cited the literature).
- **Skip the seed v2** when the response findings are minor enough that they can be absorbed into the synthesis directly. This is rare; usually a v2 is cleaner.
- **Skip the maintainer decisions** when no product-level binary choice surfaces. Most cycles do not need this stage.
- **Skip the final review** at your own risk. The cost-API cycle's final review caught three real bugs; running without it would have cut tickets against broken specs.
- **Skip the horizon entry** only if the synthesis defers nothing. This is rare.

---

## When to deviate

This document captures what has worked. It is not a binding methodology. Reasons to deviate:

- **Time pressure.** A small RFC with low blast radius can skip stages.
- **Context-window limits.** If the LLM doing the synthesis can't fit the seed + response + review + code, split the synthesis or do it in passes.
- **Single-author necessity.** If only one LLM is available, role rotation is impossible; record the loss of adversarial review and lean harder on maintainer review.
- **Genuine novelty.** A cycle that establishes a new pattern (e.g., the first RFC to interact with a new external system) may need stages this document doesn't anticipate.

Deviations should be visible. If a cycle deviates from this pattern, the synthesis or final-review note should say which stages were skipped and why.

---

## Revision history

- **2026-05-27** -- initial version. Three completed cycles informed the patterns: OMS RFC (seed/response/synthesis), walk-forward RFC (seed/response/review/v2/synthesis), public transaction-cost API RFC (seed/response/review/v2/maintainer-decisions/synthesis/final-review). Revise after the next cycle.
- **2026-06-04** -- walk-forward RFC closed the cycle with a final-review artifact (`rfc_walk_forward_evaluation_v0_1_9_x_final_review.md`) and Amendment 1 to the synthesis (Section 14). Walk-forward stage list updated above to 1, 2, 3, 4, 5, 7, 8, 9. Pattern: post-synthesis findings route via final_review + maintainer amendment (authorized by synthesis Section 13) when they correct bound text, constrain open spec-cut questions, or augment Minimum Scope / Future Obligations; new RFC chains are reserved for findings that re-deliberate architecture.
- **2026-06-04 (same day)** -- walk-forward RFC closure strengthened with Amendment 2 (synthesis Section 16) and Section 17 ticket-cut gates after a post-Amendment-1 review (Claude online, then Codex) identified that Amendment 1's Sections 14.2 and 14.3 bound procedural constraints ("must justify", "must address", "visually unavoidable") rather than substantive defaults, and that no ticket-cut enforcement mechanism gated the obligations. Amendment 2 replaced the four procedural routings with substantive defaults (carry_test_state, fail-closed metric classification, no-default extraction with rationale arg, operational print data contract). Section 17 added a two-gate enforcement matrix (packet-open and release-gate). Pattern refined: an amendment that routes findings to procedural constraints alone is insufficient closure. A post-synthesis amendment must either (a) bind a substantive default, operational contract, or forbidden-list; or (b) name a ticket-cut gate matrix that enforces the procedural constraint at named lifecycle points; or both. Procedural-only routings ("the spec-cut writer must justify X") fail closed at the cycle-discipline level because they delegate the substantive decision back to the moment the amendment was meant to constrain. The walk-forward closure is the first cycle to apply this refinement; future cycles' final-review patches should follow it.
- **2026-09-08** -- added "Spikes inside a cycle" and the binding `spike_protocol.md` after the asset-availability spike (v0.1.9.8) closed inconclusive: probe before prose, runnable core before expected tables, size budgets as stop signals, provenance in the product not the harness, and a three-action review contract.
- **2026-09-21** -- post-v0.2.0.1 governance review accepted (synthesis v2 at `78cef8c`). Replaced "Prompt-writing notes" with "Briefs": maintainer-owned, mode-named, question-first. Added "Review modes, workstreams, and routes" as a pilot for the next implementation packet. Stages and rotation unchanged. Lesson: agents reproduce the shape of their brief; the cycle's first synthesis was rejected for converting decisions into form checks after an over-specified brief, and its second was returned once for three unchallenged synthesis-only choices.
