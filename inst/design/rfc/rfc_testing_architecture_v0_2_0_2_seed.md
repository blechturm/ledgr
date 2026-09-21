# RFC Seed: Testing Architecture For v0.2.0.2 And After

**Status:** Seed v1; non-binding. Input to the Type 2 response.

**Release destination:** v0.2.0.2, as its opening workstreams. The lanes,
the rule for new tests, and the canonical-R lane outlive the release.

**Author:** Claude. Bias is stated in Section 9.

**Next step:** Codex writes the Type 2 response from the audit it authored.
This seed proposes no ticket cut and edits no test.

## 1. Question

How should ledgr's tests be organized so that an ordinary check is fast
enough for CRAN and daily use, every guarantee the suite currently gives is
kept somewhere that runs, canonical R remains the executable oracle for
optimized paths, and the suite stops regrowing the way it grew?

## 2. What Is Established

Two audits and a census, all in the repository:
`inst/design/audits/v0_2_0_test_suite_audit.md` (2026-09-09),
`inst/design/audits/post_v0_2_0_1_test_suite_audit.md` with its 930-row
block table (2026-09-21, `788bd92`), and the static census in the governance
cycle. Numbers below are theirs.

### 2.1 The cost is setup repetition, not slop

930 blocks, 951.73 seconds. Documentation pins, governance pins, and
source-shape pins together are 90 blocks and 5.5 seconds. The time is in 357
behavioral and 353 negative-witness blocks that each rebuild a snapshot,
experiment, and sweep to assert something: 42 files build the full pipeline
and hold 58 percent of assertions. The audit proposes 134 fixture reductions
and 126 merges against 26 deletions. This is a routing problem with a
deletion component, not the reverse.

### 2.2 The suite is red for the reason predicted

23 failures. Eight blocks in `test-documentation-contracts.R` account for 22:
version-stamped prose pins that broke when the governance documents changed.
The 23rd pins `engine_version` at `0.2.0.1` against a package at `0.2.0.2`.
None is a product defect. Version labels and prose are not oracles.

### 2.3 Where the strong evidence is, and how little of it there is

74 blocks carry an embedded detecting mutation; all six probes the prior
audit left open are now closed with measured dispositions. Independent
calculation, the strongest oracle class, is 22 blocks across 18 files. The
canonical-R differential subset the audit could name is three blocks, 6.16
seconds, two of them in the fast lane. Cross-path parity is 41 blocks.

### 2.4 What the audit could not deliver

Its `contract_or_defect` column cites `contracts.md`, a section, or a defect
ID in 33 of 930 rows; in all 930 it restates the block's title. There is no
contracts-to-tests coverage map beyond the prior audit's twelve rows. Which
contracts have no test, and which have five, is not yet known.

### 2.5 CRAN blockers the assertion count hides

Four blocks write `tests/testthat/Rplots.pdf`; one fails in a read-only
working directory. A durable walk-forward run emits a finalizer advisory at
process exit that no block has been shown to own. One block muffles every
warning after recording the expected class, so the run's zero-warning count
proves nothing. Zero blocks use `skip_on_cran`.

## 3. Existing Authority

The roadmap's audit section binds: three lanes, a fast lane at 60 to 90
seconds, CRAN as an explicit lane rather than scattered skips, slowness never
justifying deletion, equivalent detecting evidence preserved, the compiled
path classified into traces, atomicity, witnesses, representative cases, and
one or two full-scale records without a Cartesian grid, and maintained
testing documentation. The governance synthesis binds D2 (Type 1 reviews ask
whether the inputs are right), D4 (one source, generated views), D6 (audits
propose, RFCs decide), and D7 (canonical R is the oracle; runtime default is
separate; canonical R stays runnable in a lane the audit defines and this RFC
assigns).

## 4. Proposed Direction

### 4.1 Three lanes by directory, and the fast lane is the CRAN lane

`tests/testthat/` holds the fast lane and nothing else. It is what
`R CMD check` runs, on CRAN and locally, and it stays under 90 seconds. The
audit's 461-block candidate runs in 70.80 seconds today and covers all eleven
claim families; it is the starting membership, not a promise.

`tests/review/` holds the review lane: persistence and state invariants,
cross-path parity, the canonical-R differential protocol, randomized
validators, and any block whose fixture cannot be made small without losing
the defect. `R CMD check` does not see it. A wrapper `dev/run-review-lane.R`
runs it at every workstream review point and at the release gate.

`dev/protocols/` holds heavy evidence: benchmark records, stress proofs,
frozen-evidence regeneration. Each is invoked by name, never by default.

Why a directory and not a skip helper: a heavy test drifting back into the
fast lane is then a file move visible in every diff, rather than a missing
`skip_if` line nobody notices. The roadmap asks for exactly that rule. The
cost is one wrapper and a CI job. Rejected: a lane tag inside each block
(invisible drift), and a separate CRAN lane distinct from the fast lane
(two things to keep under budget instead of one).

### 4.2 CRAN

The fast lane is CRAN-clean by construction, so no block gets
`skip_on_cran`. Three repairs land in the first workstream: graphics blocks
open an explicit temporary device; the warning block asserts its expected
class and lets any other warning surface; the finalizer advisory is localized
to its owning block before it is fixed, not attributed by guess. Optional
dependencies keep `skip_if_not_installed`. Nothing in the fast lane touches
the network or writes outside the session temporary directory. Compiled
sources are exercised in the fast lane, where they already sit at 0.4
seconds, so platform coverage comes with the CRAN check itself.

### 4.3 The canonical-R lane and its owner

Canonical R's authority under D7 needs a place to be exercised. The three
audited blocks become one named protocol in the review lane, joined by the
public-sweep parity check from `test-peer-benchmark-boundary.R`. The
roadmap's five-way classification of compiled evidence maps onto the lanes:
adversarial kernel traces and small workflow witnesses stay fast; sink
atomicity and representative cost and risk cases are review; the one or two
full-scale records are protocols. The owner is the accounting-core
consolidation workstream, because it is the next work that must prove exact
fill and realized-trade parity against canonical R, and D7 makes that its
gate. Ownership is recorded in `tickets.yml`, not in a document.

Rejected: leaving the subset at three blocks with no owner, which is the
audit's honest state and not a lane; and a standing owner outside any
workstream, which no one would staff.

### 4.4 The taxonomy is the audit's oracle classes, minus three

The roadmap asks for an explicit taxonomy rather than one uniform style. The
audit already produced one at the right grain. Six oracle classes are test
categories and stay; three are not tests and route out.

| Class | Lives in | Oracle it must name |
| --- | --- | --- |
| Behavioral assertion | fast, unless the fixture forces review | a value computed outside the call under test |
| Negative witness | fast | the rejected input and the expected condition class |
| Persistence or state invariant | review | the invariant, stated; reopen or resume as the check |
| Cross-path parity | review; canonical-R protocol for compiled | the reference path and the comparison rule |
| Independent calculation | fast | the hand computation or reference formula in the block |
| External reference | fast, optional dependency | the external source and its version |
| Documentation surface pin | out: the render step | none; a build diff is the check |
| Governance text pin | out: deleted | none; the artifacts no longer exist |
| Source-shape pin | out: an explicit reachability guard, or deleted | the forbidden call and the path it must not reach |

### 4.5 The rule for new tests, and the retroactive path

Every block carries three comment lines above its body:

```r
# Guards:      contract section or defect ID, not a paraphrase of the title
# Oracle:      where the expected value comes from, independent of the call
# Breaks when: the smallest deliberate change that makes it fail
```

Lane is the directory, so no line is needed. Overlap is the reviewer's
question, not the author's line. A full snapshot-run-sweep fixture in the
fast lane needs its reason in the Guards line. A block whose honest Oracle
line is "the same production helper the test calls" is returned at Type 1
review under D2's standing question; that is the enforcement, and there is
no test that greps for the lines.

Retroactively: the audit table's `failure_condition` and `oracle_class`
columns transcribe into the 904 surviving blocks as they are touched by the
cleanup workstreams; deleted blocks are never annotated. `Guards` is
authored, because the audit's column does not cite. The prior audit's twelve
contracts are the skeleton. A twenty-line `dev/test-map.R` greps `Guards`
into a generated coverage table on demand; it is never edited and never
tested. Whether it is worth writing is Section 8's question.

### 4.6 Documentation

One file, `tests/README.md`, under sixty lines: the three lanes and the
command that runs each, the three comment lines and one example, where
frozen evidence lives and how it is regenerated, and what to do when a fast
block exceeds its budget. Rejected: a manual chapter, and any documentation
test that reads it.

## 5. What Ships Before The RFC Synthesizes

Under D6 these implement accepted direction and are direct tickets now:
delete the eight failing documentation-contract blocks and the governance
pins, because the artifacts they pin no longer exist; read `engine_version`
from `DESCRIPTION` in the frozen witness or drop the field from the
comparison. The suite is green again, and nothing waits.

## 6. Workstreams For v0.2.0.2

Four, in order, each with one Type 1 review, each closing only when the fast
lane is measured under 90 seconds:

| Workstream | Content | Claim reviewed |
| --- | --- | --- |
| Repair | 26 replace-and-delete, 21 fix-oracle, the three CRAN blockers | every removed block's evidence exists elsewhere |
| Split | move 277 review and 192 protocol blocks; add the wrapper and CI job | `R CMD check` runs only the fast lane; nothing was lost in the move |
| Consolidate | 134 fixture reductions, 126 merges, by claim family | each merged block's failure condition still fails |
| Map | Guards lines on survivors; the canonical-R protocol named; `tests/README.md` | every contract in the prior audit's map has a named block |

Consolidate is the largest and the only one with real risk; its review's
standing question is whether the smaller fixture still exposes the defect the
larger one did.

## 7. Scenarios

| Scenario | Behavior | Residual failure |
| --- | --- | --- |
| Agent adds a test | three lines, fast lane by default, Type 1 asks whether the Oracle is independent | a plausible but circular Oracle line can pass a tired reviewer |
| A slow integration test lands in the fast lane | the workstream-close timing gate fails | only if someone runs it; the gate is a number, not a test |
| Governance documents change | nothing fails | none; that was the point |
| Compiled path diverges from canonical R | the review-lane protocol fails at the next workstream review | a divergence between reviews ships to that review, not to a release |
| `Rplots.pdf` on CRAN | fixed in Repair | none |
| The only block guarding a contract is merged away | the map, if built, shows the gap; otherwise the reviewer's overlap question | without the map this depends on one reviewer noticing |

## 8. Open Decisions For The Response

1. Directory split against a skip helper. The split is structurally stronger
   and costs a wrapper; the helper is cheaper and drifts silently. Argue from
   the audit's move count, not from taste.
2. Is 90 seconds the gate now, at 70.80 with 461 blocks, or after
   Consolidate? The seed says now, and every workstream close.
3. The canonical-R owner. The accounting-core workstream is the seed's
   answer because its gate needs the lane; say whether a workstream can own
   a standing lane after it closes.
4. The coverage map: a twenty-line script and a ticket, or the Guards lines
   alone. The seed leans map; the audit's column failure is the reason.
5. Whether six retained classes are a taxonomy the roadmap will accept, or
   whether it wanted category rules for naming and fixtures that this seed
   declines to write.
6. Section 5 ships before synthesis. Say whether any of it is not already
   accepted direction.

## 9. Bias

This author wrote the static census the audit verified, argued for the
three-line inline standard before the audit reported, and proposed the
directory split in conversation. Sections 4.1 and 4.5 adopt all three. The
response should ask whether the audit's own five-field rule and its lane
proposal were the better starting points, and whether the seed's fondness
for its census made it read the audit as confirmation.

## 10. Non-Goals

No new test framework, no `expect_snapshot`, no change to what any kept
block asserts except the 21 oracle repairs, no production refactoring, no
CI redesign beyond one review-lane job, and no test that reads a document.

## Revision History

- 2026-09-21 — Seed v1, Claude, from the two audits and the census.
