# Final Review: Post-v0.2.0.1 Governance Synthesis v2

**Status:** Type 1 final review complete; substantive additions returned to
Type 2 before maintainer acceptance.

**Reviewer:** Codex. **Date:** 2026-09-21.

**Reviewed artifact:**
`rfc_governance_review_post_v0_2_0_1_synthesis_v2.md` at `91fdbf2`.
Inputs: revised Seed v3 in the working tree, its Type 2 response at
`a8fc555`, the Seed v2 Type 2 review, the rejected first synthesis, and
`rfc_cycle.md` final-review rules.

## Verdict

**Not ready for maintainer acceptance.** Most decisions faithfully and
clearly synthesize the accepted direction. Three synthesis-only choices alter
the operating model and did not receive Type 2 challenge. One of them creates
a perverse incentive. Under D2 and `rfc_cycle.md:191-198`, final review must
return those choices to Type 2 rather than repair them as verification edits.

## Findings

### B1. D8 makes finding a defect an acceptance quota

Revised Seed v3 preregisters one numerical pilot gate: at most 0.5 independent
review invocation per completed ticket (`seed_v3.md:219-223`). The Type 2
response asked for one number and said that zero Type 2 findings should be
visible, not that zero findings should fail the pilot.

D8 adds a second gate: at least one review finding must change an outcome
(`synthesis_v2.md:185-190`). A correctly designed and implemented packet now
fails precisely because reviewers find nothing. Reviewers and authors gain an
incentive to manufacture or preserve a correction so the process can pass.
The rule also confounds process quality with the unknown defect rate of one
packet.

This is a substantive acceptance rule, not a citation or consistency patch.
Type 2 must either defend a yield requirement with a non-gameable denominator
or remove it. Final review does not choose between those designs.

### B2. D5 restores a mandatory release step after the latest challenge accepted its absence

Revised Seed v3 rejects a mandatory profile for an ordinary release and
accepts that performance debt may accumulate until a benchmark, targeted
profile, or scheduled audit exposes it (`seed_v3.md:136-145,192-205`). The
Type 2 response explicitly accepts that scenario.

D5 nevertheless requires an end-to-end documented-quickstart profile on every
release and binds it into `benchmark_methodology.qmd`
(`synthesis_v2.md:120-139,250`). The synthesis records this as a deliberate
overruling, but no adversary has reviewed the concrete rule. It does not define
the fixture, clock, environment, repetitions, meaning of "top ten", or what
counts as surprising. Without those decisions it can become the same kind of
ritual the cycle is trying to remove.

The earlier Type 2 review proposed a stable performance trend, so profiling is
not forbidden design space. This particular standing obligation still needs
Type 2 review before it can bind.

### B3. D3 turns one ticket-cut review into two without a reviewed cost decision

Revised Seed v3 retains one independent ticket-cut review carrying a Type 1
coverage duty and Type 2 challenge to the review map (`seed_v3.md:89-93`). The
Type 2 response asks that ticket-cut review be retained; it does not require
two invocations.

D3 changes this to two briefs and two reviews because modes may not be mixed
(`synthesis_v2.md:70-85`). That raises the retrospective model from about eight
reviews to ten and is material to the RFC's central cost claim. Separation may
be the right decision, but it is another unchallenged design choice. Type 2
must choose whether modes identify questions within one review or require
separate review invocations.

### M1. The process-document instruction revives rejected Git-as-history wording

D4 correctly says Git records committed states but does not preserve why an
uncommitted or plausible-looking result was rejected
(`synthesis_v2.md:102-119`). Section 5 then directs `AGENTS.md` to receive the
old sentence that the process need not be exact "because Git already is"
(`:237-241`). Seed v3 and its Type 2 review rejected that unqualified claim.

After the Type 2 issues are resolved, Section 5 should instead carry D4's
bounded statement: Git is the ledger for committed states; decision-changing
rejections need a concise durable reason.

### M2. The revised seed is not yet part of repository history

Synthesis v2 is committed, but the exact revised Seed v3 it claims as input is
still untracked. The RFC index update is also uncommitted. The synthesis may
not be accepted while its controlling input exists only in one working tree.

The smallest correction is to commit the exact revised seed before acceptance
and disclose that it was committed after the synthesis it informed. Rewriting
history is unnecessary; leaving the source untracked is not acceptable.

## Verification performed

- Read the synthesis, revised Seed v3, Type 2 response, Seed v2 Type 2 review,
  rejected first synthesis, roadmap governance section, and final-review rules.
- Recomputed D3: two cut reviews plus seven Type 1 workstream reviews plus one
  Type 2 benchmark review equals ten; `10 / 26 = 0.3846`, reported honestly as
  about 0.38.
- Confirmed the seven workstreams cover Batch 1 and Batches 2 through 9 and 11
  through 15; Batch 0 is ticket cut and Batch 10 is diagnostic history.
- Confirmed D6 names all five roadmap routes: RFC, spike, ticket, audit, and
  documentation chore.
- Confirmed D7 addresses semantic authority, canonical R, runtime default,
  tolerances, intentional divergence, proof ownership, and the focused
  differential lane.
- Confirmed the test-suite audit explicitly gates v0.2.0.2.
- Confirmed all six roadmap non-negotiables are carried and the synthesis is
  288 lines, below its 300-line ceiling.
- Ran whitespace and working-tree containment checks. No source, test, seed,
  synthesis, or unrelated file was edited by this review.

## Verified non-findings

- Role rotation is correct: Codex authored Seed v3, Claude authored the Type 2
  response and synthesis, and Codex performs Type 1 final review.
- D1, D2, D4, D6, D7, D9, and the audit sequencing are internally coherent
  apart from M1's later process-document wording.
- The synthesis does not recreate Seed v2's line-count tests, per-batch profile
  mandate, duplication census, reachability scan, or guard-per-review rule.
- The pilot remains reversible and binds only the next implementation packet.

## Required next step

Run a focused Type 2 review of only B1 through B3: the review-yield condition,
the mandatory documented-idiom profile, and whether ticket-cut modes require
one or two invocations. Then patch the synthesis decisions, correct M1, commit
the exact revised seed and index state, and repeat Type 1 verification. Do not
reopen the accepted workstream model or canonical-R authority decision.

**FINAL_REVIEW_DISPOSITION: NEEDS_TYPE_2**

## Re-verification at `78cef8c`

Type 1, 2026-09-21, Codex. All five findings are closed. B1: D8 carries only
the review-invocation ratio; no defect-yield quota. B2: the standing release
profile is withdrawn and the benchmark gap is routed separately. B3: ticket
cut is one review with a two-question brief; 9 / 26 = 0.346, reported as
0.35. M1: the `AGENTS.md` instruction preserves Git's bounded role and
requires reasons for decision-changing rejections. M2: Seed v3 is tracked at
`a3ab93c` and the synthesis discloses the late commit.

The Section 8 checklist passes: seven workstreams cover Batches 1-9 and
11-15, with Batch 0 ticket cut and Batch 10 diagnostic history; D6 names all
five routes; D8 has the single ratio gate; D7 settles every authority
question; Section 4 carries all six non-negotiables; no test, guard,
benchmark, ticket, or standing artifact is created; the synthesis is exactly
300 lines and `git diff --check` passes. No new defects; no protected
decision reopened; no files changed. Acceptance does not open v0.2.0.2; the
test-suite audit remains its gate.

**FINAL_REVIEW_DISPOSITION: PASS_AFTER_PATCHES**
