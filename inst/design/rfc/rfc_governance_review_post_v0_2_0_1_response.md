# Response: Post-v0.2.0.1 Governance Review Seed

**Status:** Reviewer response; input to seed v2 or synthesis.
**Respondent:** Codex
**Date:** 2026-09-20
**Responds to:** `inst/design/rfc/rfc_governance_review_post_v0_2_0_1_seed.md`

**Revision note:** written as the response-stage reviewer for a seed
authored separately. The seed was not edited.

## Summary Verdict

The seed has the right center: executable checks should replace duplicated
narrative, hot paths need an explicit quality phase, Git should carry build
history, and the test-suite audit should classify rather than immediately
rewrite. It is not ready for synthesis. Its review-yield count is too low, its
blanket removal of batch review conflicts with an observed class of finding,
and its thresholds and size caps are not yet evidence-based.

My own bias is adverse to that conclusion: I implemented most v0.2.0.1
batches and wrote most of their evidence documents. I found no evidence that
the documents themselves discovered defects. I therefore do not defend batch
evidence as a default artifact. I do defend a review stop where a material
correctness or evidence boundary exists, because source review changed such
boundaries after their executable gates were green.

## Accepted Direction

- Keep the RFC cycle, role rotation, maintainer acceptance, immutable or
  superseded measurements, and separate cold, warm, and peer clocks.
- Replace Markdown/YAML ticket duplication with one authoritative source.
- Make a release-level public-pipeline profile, duplication scan, complexity
  census, and reachability check executable records rather than prose.
- Require a before/after profile when a batch changes the pulse loop, seal
  path, or public result read.
- Keep the proposed test-suite audit as classification work. Do not infer a
  rewrite from the census alone.
- Remove routine batch evidence narratives. Tests, commits, and immutable
  record prefixes are the ordinary evidence; an exception needs a concrete
  record-serving purpose.

## Blocking Corrections

### 1. Recount review yield before deleting the review stage

The repository supports a minimum of 26 completed review invocations, not
"roughly twenty." I counted only rounds named in durable artifacts and
excluded Batch 10 because the batch plan retains it as diagnostic history:

| Group | Count | Establishing record |
| --- | ---: | --- |
| Base spec and base ticket cut | 3 | `batch_plan.md:43-44,115-121` |
| Hot-path amendment and its ticket cut | 3 | amendment `:4-5,411-416`; packet `README.md:11` |
| Timestamp amendment and its ticket cut | 3 | amendment `:6-7,648-657`; `batch_plan.md:5` |
| Batch 1 | 2 | `batch_plan.md:153-154` says re-review |
| Batches 2 through 6 | 5 | `batch_plan.md:180-340` |
| Batch 7 | 2 | `batch_plan.md:369-373` |
| Batch 8 | 1 | `batch_plan.md:404-413` |
| Batch 9 | 2 | evidence `:138-144` says first review; accepted status `:3` |
| Batches 11 through 15 | 5 | `batch_plan.md:466-612` and closeout `:203-216` |

Method: I searched the batch plan, amendment revision records, packet README,
and evidence status lines for `independent review`, `re-review`, `first
independent review`, and `correction review`, then reconciled those events
against `git log --oneline v0.2.0.0..v0.2.0.1` (45 commits). This is a lower
bound because inline review text and Batch 10's review are not durable.

The same records show at least 14 review events that changed requirements,
code, tests, harnesses, or accepted evidence, not five:

1. base-spec N1 (`batch_plan.md:43-44`);
2. ticket-cut corrections (`e1ae717`, `batch_plan.md:119-121`);
3. the hot-path amendment's ratio and guard corrections (amendment
   `:411-414`);
4. the timestamp amendment's prerequisite, `NEITHER`, denominators, and
   reclassification (amendment `:648-654`);
5. Batch 1 option containment (`bdcab66`, Batch 1 evidence `:97-105`);
6. Batch 3's review-imposed production append-failure witness
   (`batch_plan.md:217-222`);
7. Batch 4's three Batch 5 carry-forwards (`batch_plan.md:254-263`);
8. Batch 5's two Batch 6 carry-forwards (`batch_plan.md:291-301`);
9. Batch 6's delimiter, missing-state, and syntax-tree corrections
   (`ad66fd5`, Batch 6 evidence `:122-137`);
10. Batch 7's phase-label, Zipline teardown, and provider-boundary corrections
    (Batch 7 evidence `:97-110`);
11. Batch 8's GC and five-attribute witnesses (Batch 8 evidence `:137-144`);
12. Batch 9's observed counters and reachable-helper guard (Batch 9 evidence
    `:138-144`);
13. Batch 12's asymmetric `candidate_row` comparison (Batch 12 evidence
    `:11-20`); and
14. Batch 13's wrong frozen fixture hash (Batch 13 evidence `:13-17`).

Seed v2 must distinguish review invocations, extra review rounds, and
review-induced corrections. The current single "five" count conflates them
and materially understates review yield.

### 2. Section 4.2 deletes too much

Batch 13 is the required counterexample. Its current and candidate arms used a
`PEER_` fixture instead of the frozen Stage L fixture. The run could pass its
tests, byte comparison, no-dedup mutant, and hot-path profile because both arms
shared the same wrong input. Source review compared the stored hash, rejected
the record, added a fail-closed fixture-hash guard, and forced all eight runs
to repeat (`batch13-snapshot-hash-evidence.md:13-17`; commit `765e467`).

That finding was not produced by a test suite plus a Section 4.5 profile. The
roadmap also makes independent review at material design and correctness
boundaries non-negotiable. Section 4.2 may remove review from routine batches,
but it must not defer every implementation review to the release gate.

### 3. Register the census threshold

Use **5.0 percent of captured samples in the named profiled stage** as the
function-level finding threshold. It catches the alias-map path at 56.73
percent (`horizon.md:324-336`) and the instructed `replicate()` comparator at
6.39 percent (`horizon.md:356-361`) with 1.39 points of margin. A 10-percent
rule would miss the latter; a 1-percent rule would turn ordinary sampled noise
into a findings list. Crossing 5 percent creates a finding to classify, not an
automatic ticket or performance claim.

### 4. Replace guessed size caps with observed ceilings

I measured heading-to-heading spans with `Get-Content` and the `###` line
numbers. The eleven entries dated 2026-09-17 through 2026-09-20 are 25, 23,
76, 74, 130, 49, 89, 51, 34, 26, and 49 lines. The seed author's six cited
entries are 130, 89, 76, 74, 51, and 49 including their headings, exactly its
129, 88, 75, 73, 50, and 48 content-line counts. Each records at least one
measured defect, product gap, or duplicate family. A 40-line cap rejects all
six larger evidence-bearing entries.

The Stage O evidence is 264 lines and records a 21-percent warm slowdown plus
three failed peer attempts (`batch14-final-evidence.md:86-98,223-239`). The
release closeout is 219 lines and records the Zipline alignment defect and five
gate-harness correction groups (`v0_2_0_1_release_closeout.md:90-97,124-156`).

The empirical stop-and-talk ceilings are therefore: horizon entry **130
lines**, release closeout **220 lines**, and a record-bearing empirical
checkpoint **265 lines**. The inline-review one-page rule already exists in
`spike_protocol.md`; the repository has no durable inline reviews from which
to derive a tighter numerical cap.

## Non-Blocking Findings

1. The checklist claim holds narrowly. `rg` found zero occurrence in `tests/`
   or `dev/` of "computed on a hot path" or "never read on the common branch."
   The June alias-normalization spike measures a known candidate but does not
   execute a generic read/use or reachability census. However, the seed's
   statement that the documentation test only checks file existence is false:
   `test-documentation-contracts.R:3444-3451` checks six phrases in each of the
   QMD and rendered Markdown files. None is the checklist question.
2. The packet has 24 Markdown files, not 25. A `Get-ChildItem -Filter *.md`
   plus `Get-Content` count gives 24 files and the stated 7,695 lines. The
   ticket, batch-plan, evidence-file, and commit counts otherwise reproduce:
   1,687; 612; 14 files spanning 45-264 lines; and 45 commits.
3. Bias audit: Section 4.4 promotes the substance of the seed author's
   130-line profiling entry into a mandatory quality phase, while Section 4.7
   calls that entry over-length. Section 4.2 also preserves independent review
   at the release gate, where the author reviewed Batches 9-15, while deleting
   earlier review stops without comparing their yields. Those are protections
   of the author's method and later review role. Section 7's preservation of
   historical artifacts is not special protection: it applies to every author
   and is required by the roadmap. The six-section review artifacts themselves
   receive no exemption; the seed proposes to remove them.
4. I found no basis to preserve routine batch evidence documents because I
   wrote them. The defensible review examples are the defects above, especially
   the wrong Batch 13 fixture and the Batch 12 asymmetric comparison. The
   documents are useful citations here, but the findings, guards, reruns, and
   commits are the value.

## Open Questions You'd Add Or Remove

- Add one bounded question: which implementation boundaries count as
  "material correctness" for the roadmap's retained independent-review rule?
  The Batch 13 frozen-fixture boundary is a positive example; ordinary
  documentation and mechanical ticket-status batches are negative examples.
- Remove the question whether the maintainer checklist currently executes.
  It does not; the exact search result settles it.
- Remove the question whether the seed's five/twenty count is adequate. The
  durable lower bound of 26 reviews and 14 changed outcomes settles it.
- No maintainer product decision is needed. The remaining disputes are factual
  corrections and process-scope alignment.

## Recommended Next Step

Revise to seed v2: the proposed deletion of batch review and the proposed
budgets rest on falsified counts and conflict with a roadmap non-negotiable,
so synthesis would otherwise bind a process whose own evidence contradicts it.
