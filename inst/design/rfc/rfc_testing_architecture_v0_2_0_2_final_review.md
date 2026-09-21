# Final Review: Testing Architecture For v0.2.0.2 And After

**Role:** Claude, Type 1 final reviewer under rotation; author of Seeds v1
through v3, not of the synthesis. **Date:** 2026-09-21.
**Reviewed artifact:** `rfc_testing_architecture_v0_2_0_2_synthesis.md` at
`b3d53a6`. **Inputs checked independently:** the 930-row audit table at
`788bd92`, the test sources, Seed v3 at `a4516d5`, both responses.

## What Ran

- Recomputed from the audit table, not from v3: the canonical core is three
  blocks at `test-execution-spec.R:490`, `:542`, and
  `test-sweep-persistence-parity.R:209`, summing to 6.16 seconds; the fast
  candidate is 70.80 seconds and 76.96 with the core; dispositions are 21
  oracle repairs, 134 shrinks, 126 merges, 26 deletions, 35 moves, 588 kept;
  total 948.02 seconds.
- Confirmed the three canonical `test_that` blocks exist at those lines with
  the cited titles. The third is in the audit's heavy lane; the synthesis
  moves it into every `fast` run deliberately, at 5.75 seconds.
- Reconfirmed the mock and frozen-fixture inventories from the previous
  round: `local_mocked_bindings()` in twelve test files; seven CSV fixtures
  under `tests/testthat/fixtures/availability-v0-2-0-1/`; zero
  `expect_snapshot`.
- Checked red state from the table: nine failed blocks, 23 failing
  assertions; eight blocks in `test-documentation-contracts.R`, one in
  `test-availability-fold-witnesses.R`.
- Synthesis is 245 lines, within budget; `git diff --check` clean; commit
  `b3d53a6` contains only the synthesis. Rotation holds: Codex synthesized,
  the v3 author reviews.

## Findings

**1. Citation defect, patched in both artifacts.** Synthesis §4 item 1 says
"repair or replace the 23 currently red blocks"; Seed v3 §6 says "the 23
red blocks". The audit (`:94`) and the table say 23 failing assertions in
nine blocks. Both now read nine blocks with 23 failing assertions, with a
revision note in each. The workstream's content is unchanged; the count of
blocks to touch is nine.

**2. Housekeeping.** The synthesis commit did not advance the RFC pipeline
row, which still read "seed v3 written; synthesis pending". Advanced with
this review.

**3. Upheld: the three departures from v3 are named and resolved.** The
inline oracle note is rejected at D5 with a reason v3's own §8.5 invited.
Census independence at D4 corrects a real gap: v3 let one selector produce
both sides of its own reconciliation. The workstream reorder at §4 corrects
a circularity in v3 that I wrote and did not see: Oracle-and-claims built
the census that only Move's runner could produce.

**4. Upheld: the five open decisions are each closed.** D1's `[LTB-0001]`
prefix on registered blocks only; D2's hard ceiling with a median-of-three
confirmation; D3's grain by falsifiable invariant rather than heading;
D4's per-invocation census with independent sides; D5's rejection. None
contradicts v3's bound sections; each is a choice v3 left open.

**5. Upheld: §6 runs the control-plane scenario as bound**, with three
required mutations, and states the honest residual that no checker proves
its own completeness. That residual is why this review compared source
declarations, the table, and the synthesis's numbers separately rather
than accepting any one artifact's summary.

**6. Upheld: nothing in the synthesis creates a test, checker, or artifact
before the packet opens**, and §7 correctly routes any design failure to
`NEEDS_TYPE_2` rather than to this review.

## Reconciliation

| Seed v3 | Synthesis | Verdict |
| --- | --- | --- |
| one runner, two profiles, fail-closed | same | consistent |
| CRAN as isolated mode | same, isolation method recorded | consistent |
| canonical core in every `fast` run | same; 76.96 s | consistent, arithmetic holds |
| registry of declared claims, structure-only checker | same, plus census reconciliation as a checker failure | consistent, strengthened |
| conditional inline oracle note (§8.5) | rejected at D5 | departure, named in §5 |
| Oracle-and-claims builds the census; Move builds the runner | reordered: repair first, control plane second | departure, named in §1 and §4 |
| quarantine with reason, deleted later | no permanent skip; delete with reason | departure, named in §5 |
| "the 23 red blocks" | "the 23 currently red blocks" | both wrong; both patched to nine |

## Decision

**PASS_AFTER_PATCHES.** The synthesis binds v3's direction faithfully,
resolves every open decision, names every departure, and holds against the
audit table and the sources at every number I could recompute. The one
defect is a block-versus-assertion count that appeared first in my own v3
and was carried forward; it is corrected in place in both files. Ready for
maintainer acceptance. Acceptance gates v0.2.0.2's ticket cut under the
five workstreams in the synthesis's order; it authorizes no test edit
before that cut.
