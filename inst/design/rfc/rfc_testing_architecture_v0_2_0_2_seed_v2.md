# RFC Seed v2: Testing Architecture For v0.2.0.2 And After

**Status:** Seed v2; non-binding. Supersedes Seed v1 for further
deliberation after the Type 2 response at `caeb137`.

**Release destination:** v0.2.0.2, as its opening workstreams. The
profiles, the claims registry, and the canonical-R overlay outlive the
release.

**Author:** Claude, returning after Codex's response. Bias in Section 9.

**Next step:** a second Type 2 response on the changed mechanisms, then
synthesis by a different author.

## 1. Question

How should ledgr's tests be organized so that an ordinary check is fast
enough for CRAN and daily use, every guarantee the suite currently gives is
kept somewhere that runs, canonical R remains the executable oracle for
optimized paths, and the suite stops regrowing the way it grew?

## 2. What Is Established

Sources: `inst/design/audits/v0_2_0_test_suite_audit.md`,
`inst/design/audits/post_v0_2_0_1_test_suite_audit.md` with its 930-row
table at `788bd92`, and the Type 2 response. Numbers corrected from v1 are
marked.

### 2.1 The cost is setup repetition in a minority of blocks

930 blocks, 948.02 attributed seconds. Documentation, governance, and
source-shape pins together are 90 blocks and 5.5 seconds. 183 blocks in 53
files build the full snapshot, experiment, and sweep and consume 379.74
seconds; v1 said all behavioral and negative blocks did, which the audit
refutes, and v1 repeated a 42-file, 58-percent census figure the audit had
already said does not reproduce at block granularity. The audit proposes
134 fixture reductions and 126 merges against 26 deletions. Routing is one
tool; the entanglement of setup, scope, and oracle placement is the
problem.

### 2.2 Lanes do not partition files

Of 134 files, 58 are homogeneous under the audit's proposed lanes: 35 fast,
16 review, 7 heavy. The other 76 mix lanes, 30 contain all three, and those
76 hold 620 blocks and 814.42 of the 948.02 seconds. The mixed files are the
subsystem files maintainers read together: walk-forward orchestration,
availability parity and economics, sweep parity, the ledger writer, the
sweep core, the runner, and the metric oracles. Any file-level routing
splits them, demotes their cheap witnesses, or duplicates them.

### 2.3 The suite is red for the reason predicted

23 failures. Eight blocks in `test-documentation-contracts.R` account for 22:
version-stamped prose pins broken by the governance change. The 23rd pins
`engine_version` at `0.2.0.1` against a package at `0.2.0.2`. None is a
product defect. The audit's own cleanup order is oracle repair, move,
shrink, merge, then delete.

### 2.4 Where the strong evidence is

74 blocks carry an embedded detecting mutation; the prior audit's six open
probes are closed. Independent calculation is 22 blocks across 18 files.
The canonical-R differential subset the audit could name is three blocks,
6.16 seconds. Cross-path parity is 41 blocks.

### 2.5 What no artifact yet provides

A contracts-to-tests map. The audit's `contract_or_defect` column cites a
contract or defect in 33 of 930 rows and restates the title in all 930. The
prior audit's twelve-row map is the only one. Its overlap field is
description similarity, not proof of duplicate coverage.

### 2.6 CRAN blockers

Four blocks write `tests/testthat/Rplots.pdf`; one fails read-only. A
durable walk-forward run emits an unowned finalizer advisory at exit. One
block muffles every warning after recording the expected class. Zero blocks
use `skip_on_cran`. The 70.80-second fast candidate is a sum of attributed
block times from one Windows run, not a clean run of a profile.

## 3. Existing Authority

Unchanged from v1: the roadmap's audit section binds three lanes, a fast
lane at 60 to 90 seconds, CRAN as an explicit lane, no deletion for slowness
alone, equivalent detecting evidence, the compiled path's five-way evidence
classification, and maintained documentation; the governance synthesis
binds D2, D4, D6, and D7.

## 4. Proposed Direction

### 4.1 Profiles on blocks, files stay whole

Four named profiles: `fast`, `cran`, `review`, `heavy`. A block belongs to
`fast` unless it says otherwise. A homogeneous review or heavy file declares
its profile once at the top; a mixed file tags only its non-fast blocks,
one line each, with a helper that skips unless the requested profile
includes the block. Files are never split or moved for routing.

Each profile has a registered runner command and, where it is a gate, a
budget measured on the registered CI runner: `fast` at most 90 seconds
clean; `cran` is `fast`'s membership run under CRAN conditions with its own
clean measurement; `review` has no budget and runs at every workstream
review point and the release gate; `heavy` runs by name. Local timings are
advisory. Drift control is the `fast` gate itself: an expensive block added
without a tag fails the next CI run, and the author tags it or shrinks it.
That is what a directory could never do, and what v1 left to "if somebody
runs it."

Why not directories: Section 2.2. Why `cran` is a separate name with the
same initial members: CRAN tolerates a different Suggests set, platform,
graphics device, and filesystem than a developer's fast run, and one budget
serving two promises will bend toward whichever is checked more often.
Rejected: directory lanes; a single fast-and-CRAN profile; a tag inside
every block regardless of file homogeneity.

### 4.2 CRAN

The `cran` runner sets a read-only working directory, an empty optional
dependency set, and the CRAN check environment, and reports its own clean
time. Three repairs land first: graphics blocks open a temporary device;
the warning block asserts its class and lets other warnings surface; the
finalizer advisory is localized to its owner before it is touched. Compiled
sources stay in `fast`, where they sit at 0.4 seconds, so platform coverage
comes with the check itself. No block gets `skip_on_cran`.

### 4.3 The canonical-R overlay and its owner

The three audited blocks and the public-sweep parity check become the
differential overlay: tagged `review` and additionally `differential`. A
workstream that touches canonical R, a compiled path, a comparison
tolerance, or a sink invokes it at its review point; the release gate
invokes it unconditionally, because a path trigger can miss a new path.
The repository maintainer owns the overlay as a standing authority under
D7. The accounting-core consolidation workstream is its first consumer, not
its owner, because it changes the implementation the overlay judges. The
roadmap's five-way classification maps onto profiles: kernel traces and
small witnesses `fast`; sink atomicity and representative cost and risk
cases `review`; full-scale records `heavy`.

Rejected: v1's workstream ownership, which ends when the workstream does
and sits on the wrong side of the conflict.

### 4.4 Two axes, and rules only where a defect was found

Every block is classified on two orthogonal axes. Scope: unit, component,
workflow, migration, or protocol. Oracle: independent calculation,
cross-path parity, external reference, negative witness, state invariant,
or behavioral. Profile, cost, and environment needs are routing attributes,
not categories. Documentation pins route to the render step; governance
pins are deleted; source-shape pins become explicit reachability guards or
are deleted.

Category rules are written only where the audit found a defect. Cleanup:
graphics use a temporary device, DuckDB connections and run stores are torn
down explicitly, nothing writes outside the session temporary directory.
Determinism: no oracle compares a version string, a timestamp of the run,
or a random draw without a seed; warnings are asserted by class, never
muffled wholesale. Declined with reason: mock rules, because the audit
found no mocks; golden-file rules, because none exist and none are
proposed; failure-message rules, because no failure was traced to one. A
rule without a found defect is form.

### 4.5 A claims registry, and one line for new tests

`tests/claims.yml` holds one row per load-bearing claim: an identifier, its
source in `contracts.md` or a defect ID, the detecting blocks by file and
title, the profile, and the owner. It is populated from `contracts.md` and
the prior audit's twelve rows, not from 930 titles, and it is the source,
not a view. `dev/check-claims.R` runs at the release gate and fails when a
referenced block no longer resolves, a claim has no owner, or a
`differential` block is unregistered. It reads structure only. It never
reads prose, never counts lines, and never asserts a phrase; that fence is
the difference between it and the file this RFC retires.

A new test carries one line, `# Oracle: <source>`, naming where its
expected value comes from independently of the call under test. A block
that is a registered detecting block cites its claim identifier. Type 1
review returns a circular Oracle line under D2's standing question. No
retrofit: existing blocks are not annotated, because after-the-fact
citations are manufactured and the registry carries the load-bearing
claims instead.

Rejected: v1's three-line retrofit across surviving blocks and its untested
grep; a registry populated from every block title.

### 4.6 Documentation

`tests/README.md`, under sixty lines: the four profiles and their runner
commands, the Oracle line with one example, the registry and its checker,
where frozen evidence lives and how it is regenerated, and what to do when
`fast` exceeds budget. No test reads it.

## 5. What Ships Before The RFC Synthesizes

One direct ticket: the eight red blocks are skipped with the reason
"pending testing-architecture RFC; version-stamped prose pin", and the
`engine_version` witness reads the version from `DESCRIPTION`. The suite is
green, every block is preserved, and the audit's order — repair, move,
shrink, merge, delete — is untouched. v1's pre-synthesis deletion is
withdrawn.

## 6. Workstreams For v0.2.0.2

Five, in the audit's order, each with one Type 1 review, each closing only
when `fast` is measured under 90 seconds on the registered runner.

| Workstream | Content | Claim reviewed |
| --- | --- | --- |
| Oracle and claims | 21 oracle repairs, the three CRAN repairs, the registry seeded from `contracts.md` and the prior map, the checker | every load-bearing claim resolves to a detecting block with an owner |
| Move | profile tags, four runners, the `fast` and `cran` CI gates, the overlay tagged | `fast` and `cran` run clean under budget; nothing untagged is expensive |
| Shrink | 134 fixture reductions | each reduced block's failure condition still fails |
| Merge | 126 merges by claim family | no registered claim loses its detecting block |
| Delete | 26 replace-then-delete, then the eight skipped pins | the checker passes with nothing unresolved |

Shrink and Merge carry the risk. Their standing question is whether the
smaller fixture or the merged block still exposes the defect the original
did; the registry is what makes that question answerable.

## 7. Scenarios

| Scenario | Behavior | Residual failure |
| --- | --- | --- |
| Agent adds a test | `fast` by default, Oracle line, review asks if it is independent | a plausible circular line can pass a tired reviewer |
| Slow test lands in `fast` | the CI gate fails; tag or shrink | host variance needs the registered runner and a small tolerance |
| Governance documents change | nothing fails | none |
| Compiled path diverges | overlay fails at the touching workstream's review, or at release | a divergence between reviews reaches the release gate, not a release |
| `Rplots.pdf` on CRAN | fixed in Oracle and claims; `cran` runs read-only | platform graphics stay `review` evidence |
| Sole guard merged away | the checker fails on the unresolved block | only for registered claims; an unregistered contract is unguarded |
| Mixed subsystem file | tagged per block; file whole; cheap witnesses stay `fast` | tag lines accumulate; a file that becomes homogeneous is not noticed |
| Optional dependency absent | `skip_if_not_installed` in `fast`; `cran` runs without it by design | a claim guarded only by an optional-dependency block is unguarded on CRAN |
| Path trigger goes stale | the release invocation catches it | one release later than the workstream review would have |
| Accounting workstream closes | the overlay's owner is the maintainer; nothing changes | none |
| First registry is incomplete | unregistered claims are invisible to the checker | the prior map and `contracts.md` bound the omission; Merge review asks the overlap question anyway |

## 8. Open Decisions For The Response

1. The profile helper. A skip-based helper is cheap and visible in the
   block; a testthat filter on a label attribute would avoid running the
   block at all. Say which, and whether a homogeneous file's single
   declaration is worth the two mechanisms.
2. The 90-second gate: on which runner, with what tolerance, and whether it
   binds now at a projected 70.80 or only after Shrink and Merge.
3. Registry grain: one row per `contracts.md` section, or finer. Finer
   rows are more useful and more work; the response should say where the
   audit's evidence supports either.
4. Whether `cran` should diverge from `fast`'s membership from day one
   for the optional-dependency blocks, or only when CRAN first fails.
5. The single Oracle line against the response's five review questions:
   is the line redundant with a good brief, or the thing that survives a
   bad one?
6. Whether Section 5's skip-with-reason is the accepted-direction ticket
   it claims to be.

## 9. Bias

v1 read the audit as confirmation in the four places the response named,
including one where the audit had refuted the number v1 repeated. v2 adopts
the response's mechanism at 4.1, 4.3, 4.4, and 4.5 and its safety order at
5 and 6. What this author still favors and the response should test: the
Oracle line, kept for new tests only; and a preference for the smallest
registry that answers the coverage question, which may under-build it.

## 10. Non-Goals

No file moves or splits for routing, no new test framework, no
`expect_snapshot`, no change to what any kept block asserts except the 21
oracle repairs, no production refactoring, no CI beyond the profile
runners and two gates, and no test or checker that reads a document.

## Revision History

- 2026-09-21 — Seed v1, Claude, from the two audits and the census.
- 2026-09-21 — Seed v2, Claude, after the Type 2 response at `caeb137`:
  directory lanes replaced by block profiles with CI gates; `cran` a
  separate profile; the overlay owned by the maintainer; two-axis taxonomy
  with rules only where defects were found; comment retrofit replaced by a
  structure-checked claims registry and one Oracle line for new tests;
  Section 5 reduced to skip-with-reason; Section 2.1 corrected; five
  scenarios added.
