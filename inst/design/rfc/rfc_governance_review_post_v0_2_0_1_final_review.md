# Final Review: Post-v0.2.0.1 Governance Review

**Role:** Claude, final reviewer under rotation; did not write the synthesis.
**Date:** 2026-09-21.
**Status:** Verification complete. Three citation patches applied in place to
the synthesis with a revision note. No rule, decision, or scope changed.
Maintainer acceptance is the next step. Short citations use `synthesis.md`,
`seed_v2.md`, `batch_plan.md`, and `batchNN` for packet evidence files.

## What Ran

- Baseline `v0.2.0.2` at `bc2e72a`. `git diff --check` clean. The commit
  holds only the synthesis and the pipeline row.
- Synthesis: 258 lines, ten sections in the required order.
- Roadmap `:1653-1766`: the six non-negotiables appear verbatim at range
  lines 13-18; the range opens at the governance heading and closes at the
  test-audit resolution sentence.
- Boundary corrections: read `batch3:30-38`, `batch5:7-47`, `batch7:97-110`
  and the matching `batch_plan.md:217-222,275-300,357-372`. Applied Section
  4.1 to Batch 2 from `batch_plan.md:156-188`.
- Canonical-R oracle: `rfc/README.md:99` already records "Keep as contract
  and v0.1.8.10 packet authority."
- Horizon routing: the per-pulse entry spans `:309-438`; cited `:324-390`
  opens at the measurements and `:411-437` opens at the parked direction.
- Every target section in the process-document table checked for existence
  by heading grep across the six named files.

## Findings By Severity

**1. Citation defect, patched.** The process-document table named an
`rfc_cycle.md` section "implementation handoff after acceptance". No such
heading exists; the file's sections run from "The cycle stages" through
"Revision history". The row now reads "new section after 'Final review
scope'", which is where the synthesis's own change belongs. The synthesis's
checklist item 5 requires every change to name a section; as written it
failed its own check.

**2. Citation defect, patched.** The `benchmark_methodology.qmd` row named
"record contract; clocks". "Clocks" resolves to `### Two clocks, two
questions` at `:43`; "record contract" resolves to no heading. The row now
names `Record Generation Workflow` and `Two clocks, two questions`.

**3. Width, patched.** The Direction line was 110 characters. Rewrapped. Two
other prose lines sit at 80 and 81, inside the tolerance the response-review
precedent already shows; left as they are.

**4. Upheld: Batch 5 retention.** My seed v2 excluded Batch 5 because its
only counted correction was a soft carry-forward. The synthesis retains it on
what the batch changed, not on what review found: `batch5:7-47` records
atomic prefix commit, resume, and reopen semantics, which is Section 4.2(c)
persistence by definition. That is the correct reading of the classifier and
my application table was wrong.

**5. Upheld: the fifth flag.** `evidence_clock_or_release_claim` is new
against v2's four clauses. `batch7:97-110` establishes phase-label, teardown
attribution, and provider-clock corrections that a checker's arithmetic
passed and a profile would not adjudicate. The prompt permitted widening
with a named batch; this is one.

**6. Upheld: canonical-R oracle is a restatement.** It was not in v2, but
the roadmap scope requires the review to settle implementation authority,
and the rule binds nothing beyond the existing topic-decision row. It opens
no design space.

**7. Upheld: every binding rule carries a check.** Each of 4.1 through 4.8
names an R/testthat enforcement route. Whether each route is implementable
is ticket work; that it is named satisfies the synthesis's own standard.

## Synthesis Reconciliation

| `seed_v2.md` | `synthesis.md` | Verdict |
| --- | --- | --- |
| §4.2 (a)-(d); Batches 3, 5, 7 outside | (c) covers 3 and 5; new flag covers 7 | correct; v2 application table superseded |
| §4.7 authority caps 40/120/40 | same, plus 300 for seed, response, synthesis | consistent; the 300s match the spike protocol |
| §4.4 5 percent | same, "must be classified, not necessarily fixed" | consistent |
| §4.6 three guards | same, with `CHEAPEST_PLAUSIBLE` / `WRONG_CANDIDATE` manifest fields | consistent, made checkable |
| §4.8 sentence | quoted verbatim | consistent |
| doc-only batches never reviewed | file type never waives a flag | stricter; not a contradiction |
| checklist item 3: review for 1, 3-9, 11-15; outside 0, 2, 10 | applied; Batch 2 has no (a)-(e) touch and no counted correction | holds |

## Decision

Accept for maintainer acceptance. The synthesis is mutually consistent with
seed v2, its load-bearing claims hold against the repository at the cited
lines, both open decisions are resolved by evidence rather than preference,
and the one party with a stake in the size rule conceded it on a count. The
three patches are citation fixes of the kind `rfc_cycle.md` permits in place;
none touches a rule. After acceptance, one commit applies the process-document
table and a post-synthesis horizon entry records what was deferred.

**Maintainer disposition, 2026-09-21: rejected.** This review verified the
synthesis against its own checklist and never asked whether its enforcement
layer was proportionate. That is the review's own failure, and it is the same
failure the cycle set out to correct: a form check of a form check. The
acceptance above is void.
