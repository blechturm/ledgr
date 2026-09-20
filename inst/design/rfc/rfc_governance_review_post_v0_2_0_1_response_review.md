# Response Review: Post-v0.2.0.1 Governance Review

**Role:** Claude, Seed v1 author. **Date:** 2026-09-20.
**Status:** Review complete; seed v2 is the next artifact. Nothing accepted,
no process document edited. Short citations use `seed.md`, `response.md`,
`batch_plan.md`, and `batchNN` for the packet evidence files.

## What Ran

- Baseline `v0.2.0.2` at `c26dddb`. The seed is untracked; the response and
  its pipeline row are committed. No package or test file changed.
- Recount of review mentions in `batch_plan.md` by exact phrase: 16
  "independent review", 2 "re-review", 1 each of "focused re-review",
  "correction review", "additional Claude review", "ticket-cut review", "two
  independent reviews". Seven of 45 cycle commits name a correction or review.
- Read every citation the response relies on for its blocking findings:
  `batch13:11-19` and `git show --stat 765e467`; `batch12:11-20`;
  `batch_plan.md:254-263,291-301`; `test-documentation-contracts.R:3440-3452`;
  `batch6:122-137`; `batch9:136-146`.

## Findings By Severity

**1. Upheld, and it refutes seed §4.2 as written.** `batch13:13-17` records
that the first provisional pass hashed a `PEER_` fixture instead of the
frozen Stage L fixture. Both arms shared the wrong input, so tests, byte
comparison, the no-dedup mutant, and a profile would all have passed. Source
review compared the stored hash against `ed05aa17...c7bb5`, rejected the
record, and the eight-run protocol was repeated. `765e467` adds the 491-line
runner carrying the fail-closed refusal. This is exactly the counterexample
seed §8.2 asked for. It also shows the seed's mechanism claim surviving: the
reviewer ran a comparison rather than reading narrative, and the review left
a guard behind (§4.6, third bullet). The default falls; the principle stands.

**2. Upheld with correction: the count.** Twenty-six invocations reproduces
against my recount plus the three amendment and ticket-cut rounds the seed
omitted. Fourteen changed outcomes is padded. Items 7 and 8 are "three
non-blocking review observations" and "two non-blocking test observations"
carried into the next preflight "without widening its scope"
(`batch_plan.md:257-259,294-296`); they are notes, not rejections. Item 13
found a real asymmetry but `batch12:16-19` says it "cannot mask a difference"
and "did not require a rerun". Removing those three leaves roughly eleven
review events that rejected a record, forced a rerun, or replaced a guard.
That is still more than double the seed's five. The seed counted only
`batch_plan.md` re-review lines and missed corrections recorded in evidence
files; v2 adopts the response's method.

**3. Upheld.** `test-documentation-contracts.R:3444-3451` asserts four
phrases present and two absent in the style manual. Seed §2.5's sentence that
the test "checks that the document exists" is false. The narrower claim holds:
none of the six phrases is the checklist question, so §2.5's conclusion
survives with the sentence corrected.

**4. Upheld, minor.** Twenty-four packet Markdown files, not twenty-five.

**5. Contested: response blocking #4, the size ceilings.** Two problems.
Setting the horizon cap at the observed maximum of 130 lines makes the budget
whatever the largest artifact happened to be; the spike protocol set its 300
line seed budget as a stop signal well below the 927-line seed that motivated
it. And the 220 and 265 line closeout ceilings are derived from documents
whose attempt-history narrative §4.2 deletes, while response non-blocking #4
concedes "the documents themselves [did not discover] defects". The 21
percent slowdown cited as the Stage O document's yield was found by a CSV
comparison during review, not by the document. Blocking #4 and non-blocking
#4 contradict each other. Bias stated: I wrote the entries being capped. The
circularity argument does not depend on who wrote them.

**6. Accepted.** Five percent of captured samples in the named stage, as a
finding to classify rather than an automatic ticket. The 6.39 percent margin
argument is sound.

**7. Accepted.** The bias audit in non-blocking #3 is correct on both counts:
§4.4 promotes this author's profiling method, and §4.2 preserves review at
the gate this author reviewed. v2 states both and leaves the weighing to the
maintainer.

## Seed Reconciliation Table

| Seed | Response | v2 disposition |
| --- | --- | --- |
| §2.3 five of twenty | 26 / 14 | 26 invocations; ~11 outcome changes by the response's method, with the three soft items named |
| §2.5 existence-only test | six-phrase check | corrected; conclusion retained |
| §2.2 25 files | 24 | corrected |
| §4.2 remove batch review | Batch 13 counterexample | split: delete batch evidence documents (conceded); retain review where a batch touches a frozen oracle, evidence identity, accounting boundary, or public contract; reviewer runs the identity check and leaves a guard |
| §4.4 threshold unset | 5 percent | adopted as stated |
| §4.7 caps 40 / 100 | 130 / 220 / 265 | caps from the median finding-bearing entry as stop-and-talk; closeout cap measured after narrative removal, not before |
| §8 open decisions | add "material boundary" definition; remove two settled | adopted; the definition becomes §4.2's rule |

## Decision

Revise to seed v2. The seed author writes it under role rotation. Blocking #1
through #3 are corrections of fact and bind v2 directly. Blocking #4 is
returned with finding 5 above for the response author to answer in the
synthesis round or concede. No maintainer product decision is needed; the
response and this review agree on that.
