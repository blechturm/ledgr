# Type 2 Adversarial Review: Post-v0.2.0.1 Governance Seed v2

**Status:** Adversarial design review; input to a replacement seed, not to
synthesis.

**Reviewer:** Codex. **Date:** 2026-09-21.

**Reviewed artifact:**
`rfc_governance_review_post_v0_2_0_1_seed_v2.md`, unchanged since
`f57d0f7`. **Repository HEAD:** `4517cfe`, which records the maintainer's
rejection of the first synthesis.

**Review mode:** Type 2. This review asks whether the proposed operating
system is a good idea, whether it solves the actual problem, and whether a
better design exists. It does not grade Seed v2 claim by claim.

## 1. Verdict

**REVISE_DIRECTION_BEFORE_SYNTHESIS.**

Seed v2 correctly identifies duplicated prose, duplicated ticket sources,
indiscriminate batch review, and an absence of systematic performance
inspection. Its best proposals should survive. The system it assembles from
them should not.

The proposal does not demonstrate lower total governance cost. It removes
some narrative and reviews, then adds per-hot-path-batch profiling, a
release-wide profiling and static-analysis phase, record/checker bundles,
and permanent guards. On the v0.2.0.1 packet it would remove five reviews of
completed batches while requiring at least nine before/after profile pairs
plus the new release-wide quality run. That may be a useful exchange, but the
seed neither prices nor tests it.

More seriously, it mistakes executable verification for independent thought.
Its boundary reviewer runs the author's identity/parity check; its quality
phase promises "no reviewer judgment"; passed checks are silent. That is the
same pathology that invalidated the first synthesis: conformance to a proposed
system substitutes for asking whether the system and its oracle are right.

Seed v2 is therefore not ready to be synthesized. It needs a new design round,
not a narrower enforcement layer.

## 2. Criteria Used

A governance system is better only if it improves the combination of:

1. **Detection leverage:** important errors caught per unit of review cost.
2. **Epistemic independence:** a reviewer can challenge the author's problem,
   oracle, measurement boundary, and preferred solution.
3. **Total cost:** authoring, review, execution, maintenance, and later
   archaeology, not Markdown lines alone.
4. **Incentive compatibility:** the easiest way to comply is also the honest
   way to work, rather than moving prose into scripts or notes.
5. **Auditability:** a future maintainer can find why a decision changed and
   which failures mattered.
6. **Proportionality:** ordinary work stays ordinary; exceptional work earns
   exceptional evidence.
7. **Reversibility:** the process can be piloted, measured, and abandoned.

Seed v2 performs poorly on criteria 2, 3, 4, and 7, and has unresolved
trade-offs on 1 and 5.

## 3. Ideas Worth Keeping

The following ideas are independently valuable and do not require accepting
Seed v2's full system:

- choose one authoritative ticket source and generate or omit any other view;
- stop requiring a narrative evidence essay for every implementation batch;
- bind release-significant empirical claims to a reproducible record, source
  commit, environment, and command;
- label cold, warm, and peer clocks separately;
- preserve review at genuinely consequential design and correctness points;
- make performance and code-health debt visible instead of assuming green
  tests imply good implementation; and
- treat document budgets as prompts to edit or route supporting material.

These are a sound pruning agenda. They do not imply a mandatory checker for
every claim, a profile for every hot-path batch, or a census in every release.

## 4. Blocking Design Findings

### B1. The proposal has no net-cost case

Seed v2 measures document lines and review counts, not the cost of the system
that replaces them (`seed_v2.md:40-76`). The release contains 45 commits over
four days and at least 26 review invocations, but no elapsed authoring time,
review time, benchmark runtime attributable to governance, or maintenance cost
for checkers and guards.

Applied to the packet, Section 4.2 removes review from Batches 0, 2, 3, 5, and
7 among the fifteen completed-and-reviewed batches; Batch 10 was diagnostic
history, not another completed review. Section 4.5 would require profile pairs
for at least Batches 2, 3, 4, 5, 6, 8, 9, 12, and 13 because they change the
pulse loop, seal path, or public-result/finalization path
(`batch_plan.md:156-340,375-454,496-552`). Section 4.4 adds another public-
pipeline profile, duplication scan, seven-shape census, and reachability pass.

The seed therefore proposes at least ten new executions to replace five
reviews, before checker maintenance. It supplies no runtime estimate or pilot.
"Fewer documents" is established; "less process" is not.

### B2. It removes the independent part of independent review

Section 4.2 says the reviewer should run the identity or parity check, "not
read the narrative" (`seed_v2.md:149-162`). That is verification by the
author's chosen oracle. It cannot challenge whether the fixture, oracle,
comparison, or question is the right one.

Batch 13 is presented as the model, but it refutes this mandate. Both arms and
the executable gates shared the wrong `PEER_` fixture. The defect was caught
because a reviewer compared the record's meaning and stored hash against the
intended frozen fixture (`seed_v2.md:72-77`; response review `:23-32`). Merely
rerunning the registered comparison would have repeated the mistake.

Batch 7 is the second counterexample. Its arithmetic checker passed while
review corrected the built-in-SMA phase label, Zipline teardown attribution,
and provider-clock meaning (`batch7-benchmark-manual-evidence.md:97-110`).
Those are semantic challenges to the measurement model, not failed commands.

The process needs two explicit review modes:

- **Type 1:** verify conformance, reproduction, containment, and claimed tests;
- **Type 2:** attack the problem framing, alternatives, oracle, incentives,
  failure modes, and whether the proposed system is better.

The RFC response stage must be Type 2. Final review can be Type 1. A high-risk
implementation review may require both. Seed v2 defines only Type 1 and calls
it independent review.

### B3. The material-boundary classifier is not a usable decision rule

Section 4.1 defines a boundary epistemically: correctness depends on a decision
without an independent oracle. Section 4.2 then implements that idea as four
subject-matter categories (`seed_v2.md:127-162`). The two definitions are not
equivalent.

The categories produced disagreement immediately. Seed v2 excludes Batch 5
despite its atomic replacement, rollback, resume, and reopen behavior plainly
being persistence behavior (`batch_plan.md:275-300`). It excludes Batch 3
despite write-failure retry being a persistence boundary. It excludes Batch 7
because documentation-only work is categorically unreviewed even though that
batch defines the clocks supporting release claims.

This is not a missing fifth checkbox. Architecture, dependency changes,
numerical stability, concurrency, migration tooling, security, and benchmark
meaning can all be material without fitting cleanly. A closed taxonomy will
either miss risk or expand until nearly every batch qualifies. It also invites
classification bargaining instead of engineering judgment.

### B4. The proposed quality phase is not a valid quality-control design

Section 4.4 combines four different activities: performance profiling,
duplication detection, complexity review, and forbidden-call reachability
(`seed_v2.md:171-186`). They have different fixtures, noise models, owners,
cadences, and acceptance logic.

The 5 percent sample-share threshold is a triage heuristic, not a quality
gate. A necessary function can dominate a tiny fast stage; a harmful cost can
be split across helpers and stay below 5 percent; wall regressions can occur
without share changes; sampling shares vary between runs. It catches the two
known examples because it was fitted to them. The seed specifies no stable
workload, environment, repetitions, uncertainty rule, baseline, or absolute-
time floor.

"Every public results read" is also not a closed workload. The namespace has
159 exports, including multiple result, open, explain, fills, trades, snapshot,
sweep, and walk-forward surfaces. A normalized-body duplicate scan and a
mechanical census of seven semantic anti-patterns will create false positives
that require exactly the reviewer judgment Section 4.4 excludes.

This should be separated into a stable performance-regression lane and a
periodic or triggered code-health audit. Neither belongs automatically in
every release.

### B5. "Git holds the history" contradicts the evidence model

The seed says reviews were inline and not durable (`:60-61`), then proposes to
delete attempt histories and correction disclosures because Git holds them
(`:143-145`), while also making passed review silent (`:215-218`). These claims
cannot all be true.

Git records committed states. It does not preserve an uncommitted failed
benchmark, an inline review, a discarded candidate, or why a correct-looking
record was rejected unless someone writes that reason into a durable artifact
or commit message. The Batch 13 wrong record and the Batch 10 diagnostic remain
understandable because their meaning was explicitly recorded, not because Git
can infer it.

Routine procedural narration should disappear. Decision-changing failures,
abandoned approaches, and supersession reasons must remain concise and
discoverable. This is selective retention, not "Git instead of narrative."

### B6. The seed omits a mandatory decision

The roadmap requires this cycle to decide whether canonical R remains the
normative oracle, distinguish authority from runtime default, and define how a
permitted divergence is specified, tested, and reviewed
(`ledgr_roadmap.md:1680-1687`). Seed v2 mentions implementation authority in
its opening scope but proposes no answer in Section 4 and does not list it as
an open decision in Section 8.

That omission cannot be repaired by a synthesis author inventing the answer.
It needs a proposal and adversarial review because it governs future compiled
execution.

### B7. The redesign has no pilot, success measure, or rollback

Seed v2 applies its process to every future packet after one exceptional,
optimization-heavy release. It does not compare v0.2.0.1 with an ordinary
feature or documentation release, define a trial window, or say what result
would show the redesign failed.

That is especially risky for governance: once checkers, guards, and templates
land, their existence becomes an argument for retaining them. A process change
should be easier to reverse than a product change, not less.

## 5. High-Severity Weaknesses

### H1. Physical line caps optimize the wrong proxy

Hard caps reward dense prose and fragmentation. Moving 90 lines from horizon
to `dev/bench/notes` reduces the counted authority artifact while preserving
or increasing total tokens and forcing future readers across files. The first
rejected synthesis demonstrated the effect: it compressed judgment into tables
and machine fields to satisfy the 300-line brief.

Budgets should remain soft stop signals. The question is whether an artifact
contains one coherent decision and whether supporting evidence is separately
reusable, not whether it has 40 or 120 physical lines.

### H2. "One command" overstates reproducibility

A source commit and command are necessary for many empirical claims, but not
sufficient. Reproduction can also depend on data identity, OS, R and package
versions, hardware, environment variables, external runtimes, and whether the
command is destructive. Architectural and usability claims may have no useful
single command at all.

The rule should apply to empirical release claims, with the environment and
input identity required. It should not define all behavior evidence.

### H3. The test-suite audit risks becoming the next mega-process

The audit covers 134 files and 40,067 lines, with block timing, mutation
evidence, duplication, CRAN rules, lane ownership, and source guards
(`seed_v2.md:244-253`; roadmap `:1689-1761`). That work may be justified, but
Seed v2 simultaneously proposes more release checks before the audit has
decided test lanes and cost standards.

The audit should first sample and classify, then propose changes. It should not
inherit Section 4.4 as a predetermined output.

### H4. The RFC cycle is exempted from the critique it triggered

Seed v2 declares the decision cycle sound because decisions that completed it
were sound (`:35-38`). That is outcome selection, not a comparison. It does not
measure the cycle's cost, ask whether fewer stages would have produced the same
decisions, or examine how a tightly specified response prompt turned the first
review into fact checking.

The stages need not be removed. Their roles do need clarification: the response
must challenge the design; response review checks whether the challenge was
answered; synthesis chooses; final review verifies. Without that distinction,
the same failure will recur under cleaner templates.

## 6. Scenario Test Of The Proposed System

| Scenario | Seed v2 behavior | Result |
| --- | --- | --- |
| Routine internal cleanup off hot paths | Tests, no review | Proportionate. |
| Prepared-provider hot-path rewrite | Tests plus profiles; review classification disputed | More measurement, no guaranteed design challenge. |
| Batch 13 wrong frozen fixture | Author's parity check can pass on shared wrong input | Fails unless reviewer independently questions identity. |
| Batch 7 clock definitions | Documentation-only means no review | Fails on release-claim semantics. |
| Uncommitted failed benchmark that changes direction | Attempt prose deleted; Git has no object | Loses visible failure. |
| Ordinary release with no performance objective | Full profile, duplication, census, reachability run | Recurring cost without demonstrated value. |
| Compiled implementation differs from canonical R | No authority rule in the seed | Mandatory question unanswered. |

The proposal succeeds only in the low-risk case. Its difficult cases are the
ones governance exists to handle.

## 7. A Better Direction

The better design is a subtractive, risk-based pilot rather than a new
mechanized governance layer.

1. **Keep one ticket source.** Generate a readable view if humans need it; do
   not hand-maintain two authorities.
2. **Remove default batch essays.** A batch closes with ticket state, tests,
   commit, and links to any independently valuable evidence. Write a short
   decision note only when a failure or review changed direction.
3. **Choose coherent review gates at packet cut.** The maintainer selects a
   small number of review points based on novelty, irreversibility, semantic
   risk, and evidence authority. Adjacent implementation batches may share one
   review. The decision and rationale are visible; no closed category list
   pretends to remove judgment.
4. **Name the review mode.** RFC responses are Type 2. Release and evidence
   verification is Type 1. High-risk code can require both, in that order.
5. **Scope empirical records.** Release claims and decision-bearing experiments
   record command, commit, environment, and input identity. Preserve failed
   attempts only when they changed a decision or constrain interpretation.
6. **Separate performance from code health.** Maintain one stable release
   benchmark trend. Require targeted profiles when performance is an acceptance
   criterion, a regression appears, or a change has credible scale risk. Run
   duplication/complexity audits periodically or by trigger, not per release.
7. **Use soft document budgets.** Route reusable evidence; keep necessary
   rationale with the decision. Over-budget means edit and discuss, not fail a
   line-count test.
8. **Settle implementation authority explicitly.** Canonical R versus another
   oracle, runtime default, permitted divergence, and proof ownership require a
   reviewed decision before compiled expansion.
9. **Pilot for one packet.** Do not bind every future packet immediately.

This design removes actual obligations before adding any. It retains human
judgment where the failure history shows judgment mattered.

## 8. Pilot Measures

The pilot should compare with v0.2.0.1 and one ordinary prior packet on:

- number of review invocations and distinct review gates;
- elapsed authoring/review turns and heavy-command runtime;
- findings split into Type 1 and Type 2;
- rejected records, reruns, and post-acceptance reopenings;
- retained governance artifacts and total lines, including linked notes and
  checker code rather than only authoritative prose;
- test and benchmark runtime added by the process; and
- maintainer interventions caused by unclear authority or excessive ceremony.

Before the pilot, record failure criteria. Examples: governance runtime or
artifact volume does not fall; a Type 2 issue reaches synthesis unchallenged;
or a decision-changing failure becomes undiscoverable. Any one triggers
revision rather than automatic rollout.

## 9. Requirements For A Replacement Seed

A replacement seed should:

1. state the causal diagnosis, not only the artifact counts;
2. compare at least blanket review, Seed v2's mechanized model, and the
   subtractive risk-based pilot;
3. estimate the obligations each model would impose on v0.2.0.1 and on one
   ordinary release;
4. define Type 1 and Type 2 review and assign each RFC stage a mode;
5. answer the implementation-authority question rather than delegate it to
   synthesis;
6. define which failures and evidence deserve durable context;
7. separate stable performance regression from periodic code-health audit;
8. use soft budgets unless a hard limit has evidence and a clear escape; and
9. bind a pilot, measures, failure criteria, and rollback.

The replacement should not preserve Seed v2's section structure merely to
make corrections locatable. The overall model, not its wording, is what must
change.

## 10. Disposition

Do not rerun stage 7 from Seed v2. Return to a revised seed and a genuinely
Type 2 response. The previous response's factual work remains useful evidence,
but it is not the missing design challenge.

**TYPE_2_REVIEW_DISPOSITION: REVISE_DIRECTION_BEFORE_SYNTHESIS**
