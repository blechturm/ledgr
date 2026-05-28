# ledgr RFC Cycle

**Status:** Current as of three completed cycles (OMS, walk-forward, public transaction-cost API). Revise after the next cycle if the pattern shifts. Not a binding methodology — a reference card.

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
- **Walk-forward RFC** had stages 1, 2, 3, 4, 5, 7, 9. Clean.
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
- resolving in-line maintainer decisions where the file itself asked for the resolution (e.g., cost-API v2 §17 open questions Q1 and Q2 were resolved in v2 in-place because v2 escalated them).

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

The cost-API final review found three real patch requests (fold-core touchpoint
mislabeled "no changes"; fill_model rename touchpoint list incomplete; v2
section 0 superseded text still in present tense) and one informational item
(metrics-and-accounting vignette teaches legacy convention). All were small
document patches, none reopened design.

---

## Prompt-writing notes

When the maintainer prompts an LLM (Codex or Claude) for a stage, the prompts have a consistent shape:

- name the role (response-stage reviewer, synthesis author, final reviewer);
- list files to read in order;
- list the constraints (roadmap, predecessor syntheses, current code);
- name what to focus on (specific questions);
- name what to skip (don't redesign, don't edit, don't generate code);
- specify the output artifact (file path and structure);
- include process-discipline notes (revision notes, role rotation, in-place vs new file).

The actual prompts used for each cycle may be available in conversation history,
but they are not durable artifacts. Reference them as examples when available;
otherwise use the shape above. Do not formalize them into a template library yet.

The prompts that worked best had three properties:

1. **Open-ended on next step.** "Decide what to do next: revise, escalate, synthesize, or run another response round." Better than "write a synthesis" when the right step might not be synthesis.
2. **Code citations expected.** "Verify against R/fill-model.R; cite line numbers." Catches phantom claims.
3. **Constrained on scope.** "Don't propose new architecture." Prevents Codex's tendency to over-bind and Claude's tendency to add follow-up obligations.

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

- **2026-05-27** — initial version. Three completed cycles informed the patterns: OMS RFC (seed/response/synthesis), walk-forward RFC (seed/response/review/v2/synthesis), public transaction-cost API RFC (seed/response/review/v2/maintainer-decisions/synthesis/final-review). Revise after the next cycle.
