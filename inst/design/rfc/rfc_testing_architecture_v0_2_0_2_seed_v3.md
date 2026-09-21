# RFC Seed v3: Testing Architecture For v0.2.0.2 And After

**Status:** Seed v3; non-binding. Supersedes Seed v2 after the second Type
2 response at `19837f0`.

**Release destination:** v0.2.0.2, as its opening workstreams. The runner,
the registry, and the canonical core outlive the release.

**Author:** Claude. This seed adopts the response's minimum design and
writes it down so that someone other than its proposer owns it before it
binds. Where the author still differs, Section 8 says so.

**Next step:** synthesis by Codex under rotation, then Type 1 final review.

## 1. Question

How should ledgr's tests be organized so that an ordinary check is fast
enough for CRAN and daily use, every guarantee the suite currently gives is
kept somewhere that runs, canonical R remains the executable oracle for
optimized paths, and the suite stops regrowing the way it grew?

## 2. What Is Established

Sources: the two audits, the 930-row table at `788bd92`, and the two
responses. v2 Section 2 holds the detail; only what changed is restated.

930 blocks, 948 attributed seconds. Pins of any kind are 90 blocks and 5.5
seconds; 183 blocks in 53 files build the full pipeline and cost 380
seconds. 76 of 134 files mix lanes and hold 814 of the 948 seconds, so
routing must be per block. The suite is red: 22 failures are
version-stamped prose pins and one is an `engine_version` fixture pinned at
`0.2.0.1`. The audit's cleanup order is oracle repair, move, shrink, merge,
delete.

Two premises in v2 were false and are corrected here. The suite uses mocks:
`local_mocked_bindings()` appears in twelve test files. The suite carries
frozen reference artifacts: seven CSV fixtures under
`tests/testthat/fixtures/availability-v0-2-0-1/`, read against a reviewed
baseline with a mutation check, and a frozen-baseline assertion helper used
by provider and reference tests. Zero blocks use `expect_snapshot`.

One risk no earlier scenario tested: the routing and checking machinery can
itself fail silently. A selector that drops blocks makes every gate faster
and greener while evidence goes unexecuted.

## 3. Existing Authority

The roadmap's audit section and the governance synthesis's D2, D4, D6, and
D7, as v2 Section 3 states. Nothing here changes them.

## 4. Proposed Direction

### 4.1 One runner, two membership profiles, fail-closed

One parameterized runner. Two membership profiles: `fast`, which is every
block unless tagged otherwise, and `review`. Heavy protocols are named
scripts outside ordinary membership, invoked by name. One tagging form on
the block; a homogeneous file may declare its profile once, and that
declaration expands to the same per-block form rather than being a second
authority. An unknown profile token fails the run; it never skips.

Every gated run emits a census of blocks selected and blocks executed, and
the gate reconciles them: a block that was promised and did not run fails
the gate, regardless of what passed. `fast` is at most 90 seconds clean on
the registered CI runner; local timings are advisory. The timing gate
catches cost drift; the census catches routing drift.

Rejected: v1's directories; v2's four runners and its second tagging
system; a timing gate as the only drift control.

### 4.2 CRAN as an execution mode

CRAN is not a membership. The `fast` set runs in an ordinary mode and in a
CRAN mode: an isolated library whose method is recorded, so optional
packages are absent rather than unset; a read-only working directory; the
CRAN check environment; its own clean clock and its own gate. Three repairs
land first: graphics blocks open a temporary device; the warning block
asserts its class and lets other warnings surface; the finalizer advisory
is localized to its owner before it is touched. No block gets
`skip_on_cran`.

### 4.3 The canonical core runs every time

The three audited differential blocks, 6.16 seconds, run in every `fast`
run: 70.80 plus 6.16 is under 90, and a path trigger at that cost is risk
with no saving. Extended parity, the public-sweep comparison and any
full-scale record, is `review` and runs unconditionally at the release
gate. The maintainer owns both under D7. The accounting-core consolidation
workstream is the first consumer and never the owner. The roadmap's
five-way classification maps as in v2.

### 4.4 A registry of declared claims, with an execution census

`tests/claims.yml` is the register of *declared* load-bearing claims and
claims nothing about completeness. One row per claim: a stable identifier;
its source in `contracts.md` or a defect ID; its scope and oracle class;
the detecting blocks by stable block ID, not by file and title; the profile
each is promised in; and the owner. Seeded from `contracts.md` and the
prior audit's twelve rows. A checker runs at the release gate and fails
when a referenced block does not resolve, a claim has no owner, or the
census shows a promised block did not run in its promised profile. It reads
structure only, never prose, never a count of lines.

Because the checker cannot see undeclared claims, the Shrink, Merge, and
Delete reviews ask the overlap question directly; the registry narrows it,
it does not answer it.

Oracle metadata lives in the registry for declared claims. An unregistered
test carries an inline oracle note only when its oracle is not evident from
the block; there is no universal comment rule. Rejected: v1's three-line
retrofit; v2's universal `# Oracle:` line; file-and-title identifiers.

### 4.5 Rules only where a mechanism exists

Scope and oracle are review vocabulary and registry fields, not a
classification of all 930 blocks. Rules are bound where the audit found a
defect or the repository contains the mechanism:

- **Cleanup.** Graphics use a temporary device; DuckDB connections and run
  stores are torn down explicitly; nothing writes outside the session
  temporary directory.
- **Determinism.** No oracle compares a version string, a run timestamp, or
  an unseeded draw; warnings are asserted by class, never muffled
  wholesale.
- **Mocks.** A mocked binding may isolate a dependency; it may never supply
  the value the block then asserts. A block whose oracle is the thing it
  mocks is circular and is returned at review.
- **Frozen artifacts.** Each fixture names its regeneration command, and
  that command does not run the implementation the fixture guards.
  Historical fields such as a recorded `engine_version` stay as recorded
  and are excluded from the economic comparison; they are never made
  dynamic, because a witness that reads the current value is true by
  construction.

Declined with reason: snapshot-file rules, because no `expect_snapshot`
exists and none is proposed; failure-message rules, because no failure was
traced to one.

### 4.6 Documentation

`tests/README.md`, under sixty lines: the runner and its profiles and
modes, the registry and checker, the four rules above, and what to do when
`fast` exceeds budget. No test reads it.

## 5. Nothing Ships Before Synthesis

v1's deletions and v2's skips are withdrawn. The suite stays red until the
packet's first workstream repairs or quarantines each broken oracle under
the accepted design, and every red block is explained in the audit. A green
suite obtained by editing evidence before the architecture is accepted
would be the pathology this RFC exists to end.

## 6. Workstreams For v0.2.0.2

Five, in the audit's order, each with one Type 1 review, each closing only
when `fast` is under budget and its census reconciles.

| Workstream | Content | Claim reviewed |
| --- | --- | --- |
| Oracle and claims | 21 oracle repairs; the three CRAN repairs; the 23 red blocks repaired, replaced, or quarantined with a reason; the registry seeded; the census and checker built | every declared claim resolves to a block that ran where promised |
| Move | tags, the runner, the `fast` and CRAN gates, the canonical core in `fast` | both gates clean under budget with a reconciled census |
| Shrink | 134 fixture reductions | each reduced block's failure condition still fails |
| Merge | 126 merges by claim family | no declared claim loses its block; the overlap question asked per merge |
| Delete | 26 replace-then-delete; then the quarantined pins | the checker passes and every deletion's replacement is named |

## 7. Scenarios

| Scenario | Behavior | Residual failure |
| --- | --- | --- |
| Agent adds a test | `fast` by default; review asks the standing oracle question | a circular oracle can pass a tired reviewer |
| Slow test lands in `fast` | the timing gate fails | host variance; the registered runner and a tolerance |
| Governance documents change | nothing fails | none |
| Compiled path diverges | the canonical core fails the next `fast` run | extended parity divergence waits for a review point or release |
| `Rplots.pdf` on CRAN | fixed first; CRAN mode is read-only | platform graphics remain `review` |
| Sole guard merged away | the checker fails on the unresolved block if declared | an undeclared claim is invisible; the merge review's overlap question is the only guard |
| Mixed subsystem file | tagged per block; file whole | a file that becomes homogeneous is not noticed |
| Optional dependency absent | `skip_if_not_installed` in ordinary mode; CRAN mode is isolated by construction | a claim guarded only under an optional dependency is unguarded on CRAN |
| Accounting workstream closes | the maintainer owns the core and the overlay; nothing changes | none |
| First registry incomplete | undeclared claims are outside the checker | bounded by `contracts.md` and the prior map, not proven |
| Selector or runner refactor drops blocks | the census shows promised blocks did not run; the gate fails even though every executed test passed | a census that is itself miscomputed; one mechanism, so one place to break |
| A mock supplies the asserted value | returned at review under the mock rule | only if the reviewer reads the mock, which the rule makes a named question |

## 8. Open Decisions For Synthesis

1. The stable block identifier: a token in the `test_that` title, a
   comment, or a testthat label. Must survive a title edit and be visible
   in a diff.
2. The 90-second tolerance on the registered runner.
3. Registry grain: a `contracts.md` section, or finer where the prior map
   already is.
4. Whether the census reconciliation runs on every CI cycle or only at
   gates; the seed says every gated run.
5. The author's residual preference: an inline oracle note for an
   unregistered test whose oracle is not evident. Is "not evident"
   reviewable, or is it the universal rule under another name?

## 9. Bias

Across three seeds this author put three false facts into the record — a
refuted census figure, an overgeneralized fixture claim, and a denial that
mocks and frozen artifacts exist — each a sentence that served the argument
and was not checked. v3 adopts the response's design in full. What remains
the author's is the inline note in 4.4 and the belief that a design should
be written down by someone other than its proposer before it binds; the
synthesis should weigh both as coming from the party that was wrong.

## 10. Non-Goals

No file moves or splits, no new test framework, no `expect_snapshot`, no
change to what any kept block asserts except the 21 oracle repairs, no
production refactoring, no CI beyond the one runner and its gates, no
pre-synthesis edit to any test, and no test or checker that reads a
document.

## Revision History

- 2026-09-21 — Seed v1, Claude, from the two audits and the census.
- 2026-09-21 — Seed v2, Claude, after the first Type 2 response.
- 2026-09-21 — Seed v3, Claude, after the second Type 2 response at
  `19837f0`: one runner and two profiles with fail-closed selection and a
  selected-versus-executed census; CRAN as an isolated execution mode; the
  canonical core in every `fast` run; a registry of declared claims with
  stable IDs and census reconciliation; rules for the mocks and frozen
  artifacts that exist; no universal oracle comment; nothing ships before
  synthesis; the control-plane scenario added; two false premises corrected.
