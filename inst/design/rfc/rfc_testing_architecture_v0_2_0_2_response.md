# Response: Testing Architecture For v0.2.0.2 And After

**Status:** Type 2 adversarial response; input to seed revision or synthesis.

**Respondent:** Codex

**Date:** 2026-09-21

**Responds to:**
`inst/design/rfc/rfc_testing_architecture_v0_2_0_2_seed.md` at `8889f1c`

## Verdict

The seed has the right safety instinct and the wrong organizing mechanism.
It is right that slow evidence should be routed rather than discarded. It is
not yet a design that would survive daily use.

The first failure would be the directory split. The audit classified blocks,
but directories classify files. Of 134 test files, 76 contain blocks assigned
to more than one proposed lane, 30 contain all three lanes, and those mixed
files hold 620 blocks and 814.42 of the measured 948.02 seconds. The seed turns
that mismatch into an uncosted file-fragmentation project.

The next failure would be the inline metadata. Three plausible comments above
a test do not stop an agent from adding a circular oracle; they make the
circularity look reviewed. The temporary accounting workstream would then
close, leaving the standing canonical-R lane without an owner. These are not
minor omissions around a sound design. They determine whether the design can
work.

The direction should be revised, not rejected. Keep the three execution
profiles and the no-deletion-without-equivalent-evidence rule. Rework how tests
are assigned, how claims are represented, and who owns standing parity.

## My Bias And The Seed's Confirmation Bias

I wrote the audit, including the lane proposal and the five-field rule. I have
an incentive to defend both. They do not deserve that authority.

The audit's lanes came from one Windows run and a mechanical cutoff: an
unconstrained substantive block measured at no more than 0.80 seconds entered
the candidate fast lane. Its overlap field is description-level Jaccard
similarity, explicitly not proof of duplicate coverage. Its
`contract_or_defect` field restates the block title in all 930 rows. The audit
called its oracle class a *dominant routing aid*, not a complete taxonomy. The
candidate was useful evidence for an RFC, not an architecture ready to adopt.

The seed reads the audit as confirmation in four places where the audit warned
against doing so:

1. Section 2.1 repeats the static-census claim that 42 files hold 58 percent of
   assertions, although the audit says that count did not reproduce at block
   granularity. It also says all 710 behavioral and negative-witness blocks
   rebuild a snapshot, experiment, and sweep. The audit found 183 full-stack
   blocks in 53 files, consuming 379.74 seconds. The stronger sentence is
   false.
2. Section 4.1 promotes the audit's 461-block candidate into directory
   membership without checking whether those blocks share files with the 469
   blocks assigned elsewhere.
3. Section 4.4 turns nine dominant-oracle labels into the package's test
   taxonomy even though the audit explicitly limited them to routing.
4. Section 4.5 drops the audit's lane and overlap fields in favor of the seed
   author's pre-existing three-comment proposal, then cites the audit as the
   reason to add a map.

This is the seed author's stated bias materializing: it uses the audit to
confirm the census, directory split, and comment standard it already favored,
including where the audit contradicted the census.

## The Five Bets

### 1. Routing rather than deletion

The safety principle holds. The diagnosis is too simple.

The audit proposes 26 replace-then-delete blocks, but it also proposes 134
fixture reductions and 126 merges, against only 35 explicit lane-only moves.
The ordinary suite is slow because setup, scope, oracle placement, and routing
are entangled. Merely moving existing work makes daily feedback faster by
running less evidence; it does not make the evidence cheaper or easier to
maintain.

The seed also reverses the audit's safety order. The audit says repair oracles,
route lanes, shrink, merge, then delete. Seed Section 5 authorizes deletion of
the failing documentation and governance blocks before the RFC synthesizes and
before replacement evidence exists. D6 says audits propose and RFCs decide.
This is neither already accepted direction nor replace-then-delete.

Routing is therefore one tool, not the problem statement. The retained
principle should be: every load-bearing claim has detecting evidence at the
cheapest layer that can falsify it, and slower corroboration has a named
invocation point.

### 2. Directories, with fast equal to CRAN

A directory is visible, but its unit is wrong for the current suite.

Only 58 files are homogeneous under the audit proposal: 35 fast, 16 review,
and seven heavy. The other 76 must be split or assigned wholesale. The worst
examples are exactly the files maintainers need to understand together:
walk-forward orchestration, availability parity and economics, sweep parity,
the ledger writer, the shared sweep core, runner behavior, and metric oracles.

If they are split block by block, helpers and related scenarios scatter across
three trees. If assigned wholesale to the slowest lane, cheap negative and
contract witnesses disappear from daily feedback. If copied, the suite gains
the duplication this RFC is meant to remove. A visible `git mv` does not solve
any of those choices.

Nor does a directory prevent drift. An agent can still add an expensive test
under `tests/testthat/`; the seed's own Section 7 admits detection occurs only
if somebody runs the timing gate.

Fast and CRAN may begin with the same membership, but they are not the same
operational promise. The 70.80 seconds is a sum of attributed block times, not
a clean run of the proposed lane, and leaves 19.20 seconds of local headroom.
Developer fast tests may profitably use an installed optional dependency;
CRAN must tolerate different Suggests sets, platforms, graphics devices, and
filesystem permissions. Give them separate named profiles and budgets even if
one manifest initially supplies both. That keeps later CRAN constraints from
distorting local feedback or requiring another architecture change.

### 3. Accounting-core ownership of canonical-R parity

An implementation workstream cannot permanently own a standing authority.
Once accounting consolidation closes, its review point and staffing close with
it. The next compiled optimization, availability-aware accounting change, or
new sink then inherits an owner only by implication.

It is also the wrong conflict boundary. The accounting workstream changes the
implementation being compared and would own the test that judges it. It should
be the first *consumer* of canonical-R parity, not its permanent owner.

The repository maintainer accepting an optimized or compiled change owns the
standing differential overlay. Relevant workstreams must invoke it when they
touch canonical R, a compiled path, comparison tolerances, or sink semantics;
the release gate invokes it regardless. A change trigger can miss a new path,
so the release invocation is the backstop. That is durable after any one
workstream ends and matches D7's authority decision.

### 4. Nine oracle classes as the taxonomy

The audit's labels are not a taxonomy of tests. They describe the dominant
oracle in a block that may also contain negative, persistence, parity, and
shape assertions. The seed then mixes three different dimensions:

- evidence source: independent calculation, parity, external reference;
- behavior under test: persistence/state and negative rejection; and
- artifact location: documentation and source-shape pins.

The resulting rules are internally unstable. Section 4.4 says a behavioral
assertion must use a value computed outside the call, which is the definition
it gives independent calculation two rows later. Persistence can be tested by
independent arithmetic or parity. A negative witness may be unit, integration,
or migration evidence. None of those facts decides its directory.

Use at least two orthogonal classifications: scope/layer and oracle/evidence.
Cost, environment, and invocation profile are routing attributes, not test
categories. This also exposes what the roadmap asked for but the seed omits:
fixture ownership, deterministic time and randomness, permitted mocks,
cleanup, golden-file regeneration, and failure-message rules.

### 5. Three unenforced comment lines stop regrowth

This is the weakest long-term bet.

Retroactively adding three lines to 904 surviving blocks creates 2,712 lines
of unverified metadata. The audit can supply generic `failure_condition` text,
but it cannot supply the missing contract. Authors will infer one after the
fact, which is exactly how provenance theater is produced.

The comments drop two of the audit's five questions: cheapest lane and existing
overlap. Directory location does not explain why a lane is appropriate, and a
reviewer asking about overlap from memory has no coverage map to consult. The
proposed grep script validates syntax at most. Because it is "never tested,"
it can silently stop finding comments or references. Because comments do not
execute, they can drift while the block remains green.

Type 1 review remains necessary for semantic judgment, but it cannot be the
only enforcement for 904 annotations. Review is where plausible circular
oracles are hardest to notice, especially after the metadata itself creates an
appearance of rigor.

## A Candidate Challenged Against Section 7

Before proposing an alternative, I tested this candidate against the seed's
own scenarios:

- preserve subsystem-oriented files;
- move homogeneous files directly, but put mixed files in review until a small
  detecting spine is extracted rather than splitting all 620 mixed blocks;
- keep fast and CRAN as separate profiles with initially shared membership;
- classify tests on two axes, scope and oracle;
- record only load-bearing claims in a small machine-readable claims registry,
  with references to detecting blocks and lane owners; and
- make the repository maintainer own the canonical-R differential overlay.

| Seed scenario | Candidate behavior | Where the candidate still fails |
| --- | --- | --- |
| Agent adds a test | It joins the subsystem file's profile. A new load-bearing claim requires a registry row; supporting evidence cites an existing claim during review. | Supporting tests can still accumulate without judgment; timing and overlap review remain necessary. |
| Slow integration test lands in fast | The clean fast-profile CI gate fails. The file either moves wholesale to review or a minimal fast witness is extracted. | Timing varies by host; the gate needs a registered reference runner and a modest variance rule. |
| Governance documents change | Historical prose has no test. A small current-state consistency claim may fail only when current authorities disagree. | A bad documentation example can escape unless its public behavior has an executable journey. |
| Compiled path diverges from canonical R | Relevant-path CI invokes the differential overlay; the release gate always invokes it. | A path trigger can become stale; the unconditional release invocation is required. |
| `Rplots.pdf` on CRAN | Graphics tests use a temporary device and the CRAN profile runs in a read-only working directory. | Platform-specific graphics behavior remains review evidence. |
| Sole guard is merged away | The claims checker fails when a registered detecting block no longer resolves or a claim has no owner. | The initial registry can omit a real contract; populate it from contracts and the prior twelve-row map, not all 930 titles. |

This candidate survives the scenarios better, but not perfectly. Its principal
cost is a small authoritative registry and checker. That is new mechanism, but
it replaces 2,712 comment lines, an untested grep script, and a 620-block file
split. It enforces only load-bearing claims rather than pretending every test
title is a contract.

## Proposed Revision

I therefore propose revising the seed around the candidate, with these
specific changes:

1. Correct Section 2.1. Remove the unreproduced 42-file / 58-percent claim and
   the false statement that all behavioral and negative blocks build the full
   pipeline.
2. Re-plan lane migration at file granularity. State explicitly whether the 76
   mixed files are split, assigned wholesale, or used to extract a compact fast
   spine, and cost that decision before ticket cut.
3. Keep fast and CRAN as separate named profiles. They may share membership at
   first; each gets its own clean-run measurement and environment contract.
4. Make the repository maintainer the standing canonical-R parity owner.
   Accounting consolidation is the first consuming workstream, not the owner
   after closure.
5. Replace the single-axis nine-class taxonomy with scope/layer plus
   oracle/evidence, with routing attributes for cost and environment. Add the
   fixture, determinism, mock, cleanup, golden-file, and failure-message rules
   the roadmap requires.
6. Replace the three-comment retrofit and untested grep with a checked registry
   of load-bearing claims. Keep the audit's five questions in review briefs;
   do not manufacture 904 retrospective contract citations.
7. Delete Section 5's pre-synthesis authorization. Repair red oracles first;
   replace before deleting; act only after synthesis acceptance.
8. Re-run the scenario table with mixed files, an absent optional dependency,
   a stale change trigger, a closed accounting workstream, and an incomplete
   initial claims registry.

This preserves the seed's best idea - strict evidence survives somewhere that
runs - while avoiding a directory topology, temporary owner, and comment
ritual that would recreate the same maintenance problem in a new form.

revise the seed
