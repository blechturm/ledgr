# Comparative Architecture Spike Charter: Asset Availability And PIT Universes

## 1. Status And Authority

**Status:** Chartered, not started. Non-binding architecture evidence work.

**Date:** 2026-09-07.

**Revision history:**

- Revision 1 followed execution-readiness review. It introduced the disposable
  fold fork, witness classes, response-blocker witnesses, and role separation.
- Revision 2 follows adversarial measurement-contract review. It separates
  independent expected evidence from the shared implementation under test,
  makes the provider interface representation-neutral, expands cache and
  boundary witnesses, and permits reviewed green, red, or inconclusive results.

**Authority inputs:**

- `rfc_asset_availability_point_in_time_universes_v0_1_9_8_seed.md`;
- `rfc_asset_availability_point_in_time_universes_v0_1_9_8_response.md`;
- the companion response-review addendum;
- `../research/Sharadar-Empirical-Evidence.md`;
- `../research/ledgr_ragged_universe_prior_art_review.md`;
- `../research/rfc-evidence-handoff.md`; and
- `../contracts.md`.

Executable prototype code is authorized only under `dev/`, on a dedicated
disposable spike branch that must never merge into a release or default branch.
Design records and the final report may live under `inst/design/`; executable
prototype code may not. This charter authorizes no package API, production
schema, second production execution engine, contract change, migration,
runtime default, or release ticket.

**Role assignments:**

- The repository maintainer approves every expected witness outcome before
  prototype timing begins and accepts or rejects the final spike report.
- Claude is the default spike executor because Codex authored Seed v1 and this
  charter. The maintainer may name a substitute before execution, but the
  substitution and reason must be recorded in the spike report.
- Codex, or another named author who did not execute the spike, reviews the
  completed conformance table before Seed v2 may consume it.

This comparative spike between response review and Seed v2 is a visible
deviation from the default stage list in `../rfc_cycle.md`. The deviation is
required because the current production fold cannot express the semantic
witnesses, and representation evidence is needed before Seed v2 chooses a
runtime shape.

## 2. Question

Which representation supplies ledgr's required point-in-time universe and
availability semantics with the smallest measured runtime, memory, cache, and
diagnostic-retention cost while preserving one production fold architecture
and the existing dense path?

The spike answers that question only after each representation produces the
same semantic evidence. Fast incorrect prototypes are disqualified.

## 3. Required Prototype Boundary

The current `ledgr_execute_fold()` cannot run these witnesses unchanged. Its
validated execution object has one fixed instrument axis for the whole fold,
and the production context, risk, fill, and opening-state paths do not yet
carry the required member-plus-held view, restriction plane, distinct valuation
mark, or post-risk closure rule.

The spike therefore uses one instrumented fork of the fold core under `dev/`.
The fork is evidence scaffolding, not a proposed second engine: it exists only
on the disposable spike branch, is never merged, and must not change files
under `R/`, `src/`, package tests, `NAMESPACE`, or `DESCRIPTION`.

The existing internal `ledgr_execution_spec` object is the named injection
seam. A fork-only execution object mirrors its current fields and adds one
representation provider plus the state and evidence required by this charter.
Every representation supplies that same fork-only interface. No production
execution-spec constructor or validator is changed by the spike.

The instrumented fork owns strategy invocation, target validation, risk, fill
timing, accounting, metrics, and witness evidence once. Representation-specific
code may load or construct facts and provide fold-local state, but it may not
reimplement those semantics. The fork is the shared implementation under test,
not the source of its own expected answers.

The common provider boundary specifies information and operations, not a
mandatory whole-frame allocation. It must supply:

- deterministic stable IDs and the declared pulse axis for a requested bounded
  window;
- a decision view for one pulse, filtered to knowable members plus held IDs;
- a separate execution view for one eligible execution event;
- bounded accepted history for requested stable IDs and information cutoffs;
- membership, lifetime, observation, valuation, trading-status, execution,
  expected-session, and feature-validity evidence with effective, knowledge,
  and revision times;
- valuation marks separated from observed closes and executable prices;
- complete typed dependency identity and reason-coded witness evidence; and
- an inventory of retained backing objects, indexes, caches, histories,
  temporary conversions, and buffers owned by the provider.

Providers may realize those operations eagerly or lazily. A dynamic provider
must not be required to allocate complete bounded-window dense matrices before
returning compact pulse views. A small returned view backed by an undisclosed
full dense frame is measured as the full retained representation.

Names and physical layouts are illustrative. The spike report records the
common semantic fields actually used by all survivors.

Before any ragged witness is interpreted, W21 must show parity between the
instrumented fork and the package fold on a compact dense control set covering
buys, sells, nonzero costs, target risk, carried opening state, and final-pulse
no-fill handling. A fork that fails this control is invalid; its remaining
conformance or timing rows must not be used.

## 4. Representations To Compare

At minimum compare these independently described axes:

| Prototype | Canonical storage | Fold-local representation | Public view axis |
| --- | --- | --- | --- |
| Dense state planes | Bounded-window dense fact and state planes | Fixed superset dense planes | Pulse-filtered member-plus-held view over the superset |
| Dynamic active matrices | Effective-dated facts plus pulse membership | Pulse-dependent compact active planes with carried holdings | Pulse-local member-plus-held axis |
| Sparse facts plus bounded dense materialization | Sparse effective-dated fact tables | Fixed bounded dense planes hydrated per fold | Pulse-filtered member-plus-held view over the materialized superset |

A static superset plus masks may be represented by prototype 1; the seed
classified it as a viable runtime component, not a sufficient public view.

An event-style representation may be compared only as a materializer feeding
the instrumented fork. A prototype that proposes an event-native executor as
the production architecture is disqualified before measurement.

The report attributes cold-build and retained-storage cost to canonical
storage, materialized-frame memory to the fold-local representation, and
per-pulse slicing, remapping, and lookup cost to the public view axis. Because
the dense-state and sparse-fact prototypes converge on the same fold-local
shape, their difference must not be described as a fold-execution advantage
without separate evidence.

Use two matched comparisons before combining dimensions:

1. Compare dense and sparse canonical storage through the same fixed-frame
   consumer.
2. Compare fixed and active fold-local views from the same source facts and
   storage preparation.

No full factorial is required. An advantage is attributed only to the storage,
fold-local, or public-view dimension held apart in that comparison.

## 5. Semantic Witness Format

Before provider implementation, the spike executor writes an independent,
versioned witness specification containing:

- canonical facts and their effective, knowledge, and revision times;
- investment universe, estimation universe, and held-position domain;
- decision pulse and strategy-visible state;
- current quantity, pre-risk target, and post-risk target;
- execution opportunity and fill or no-fill result;
- cash, position, gross exposure, and valuation after execution;
- diagnostic or incomplete-evidence result;
- identities expected to remain equal; and
- identities expected to change.

Expected outputs are exact small tables with independently checked temporal
reasoning and arithmetic. They are not generated from the shared fork or any
provider being certified. The repository maintainer freezes and approves the
witness-specification version before prototype output is used as conformance
evidence. If learning requires a correction, the report records the old and
new expectation, rationale, approver, and affected witnesses, then reruns every
affected provider. Observed output never silently replaces an expected answer.

The initial comparison uses one maintainer-approved budget, removal, valuation,
status-conflict, and incomplete-evidence configuration across all providers.
Alternative product policies run as separately named scenarios against every
relevant provider; a representation may not choose the policy easiest for it.

Before conformance is trusted, the checker must reject deliberate mutations
that pass a stale valuation mark as an execution price, leave a superseded halt
active, omit a carried holding, and remove a required cache dependency. These
are checker tests against the frozen expected tables, not another execution
engine.

Witnesses have two roles:

| Class | Witnesses | Meaning of a passing conformance row |
| --- | --- | --- |
| Semantic oracle | W1-W16, W19, W22-W24, W26-W31 | The representation supplied the required evidence and the shared fork matched the independently approved outcome. Identical rows are expected and do not rank representations. |
| Representation discriminating | W17, W18, W20, W21, W25 | The representation also satisfies causality, stable-ID, graph/cache, reconstruction, parallel, or dense-parity properties that can differ by physical shape. |

Performance comparison begins only after every prototype passes all applicable
oracle and discriminating witnesses. The conformance table reports these two
classes separately so shared policy behavior is not mistaken for evidence that
one representation is better.

## 6. Minimum Semantic Witnesses

### W1. Retained Holding And Full Member Allocation

A former member worth 30 percent of NAV remains held while current-member
weights sum to one. The prototype must expose the declared budget policy and
reconcile target gross exposure. It must not silently allocate the same capital
twice.

The witness table first records the current dense-fold outcome for an
equivalent hold-plus-new-allocation strategy, including gross exposure and
cash. A survivor may change that outcome only through an approved budget-policy
correction applied identically to every representation.

### W2. Failed Sale And Successful Replacement Purchase

The old holding has no eligible execution price while the replacement does.
The result must state whether financing, conservative sizing, affordability,
or rejection governs the purchase. Expected sale proceeds are not cash.

The controls are deliberately different. The genuine unavailable-sale input
is sent through the production interface and its current missing-coverage or
invalid-price rejection is recorded. A separate complete-data dense scenario
records current financing and negative-cash behavior. Only the instrumented
fork executes the selective unavailable-sale scenario under the approved
budget policy. No injected missing-price case may be labeled a supported dense
baseline.

### W3. One Exit Target Followed By A No-Fill

A zero target receives no fill at its next execution opportunity. A later hold
target and later eligible price must not execute the earlier exit. No pending
order or standing intent appears.

### W4. Reissued Exit Target

After W3, the strategy emits a new zero target. That target is a fresh attempt
with its own decision and execution evidence.

### W5. Unknown Lifetime With A Valid Observation

Lifetime metadata is unknown, but a fresh accepted observation exists under
the declared observation/status policy. The run must not fabricate a terminal
event or stop solely because lifetime metadata is incomplete.

### W6. Valuation Horizon Exhausted

A held instrument has no permissible current mark and its bounded stale age is
exceeded. The run records the failed valuation assumption, achieved horizon,
affected exposure, and incomplete-evidence status without inventing a
delisting.

### W7. Accepted Terminal Event Without Settlement Support

A terminal event is accepted, but the accounting sibling cannot represent its
economic settlement. The run stops or excludes complete-performance claims
with a terminal-accounting reason distinct from W5 and W6.

### W8. Halted Member With A Usable Feature

A current member has a usable causal feature but decision-time trading status
restricts its target. The strategy example respects the restriction. Risk and
fill evidence preserve the typed halt reason.

### W9. Quotation-Only And Resumption States

Quotation-only, halted, and resumed trading states remain distinct. Execution
eligibility at an EOD open uses the resolved status effective at that open from
facts with `knowledge_time <= open_time`. Resolution considers effective
intervals, source precedence, and superseding assertions; a known future halt
does not block an earlier open, and an effective resumption supersedes an old
halt. Equal-precedence conflict or unresolved status produces a conservative
no-fill with a typed `status_unknown_or_conflicting` reason in this witness.

`open_time` is the market event time of the accepted execution-price record,
not the later acquisition or publication time of an EOD vendor row. The fill
layer may reconstruct the open-time outcome for a target submitted earlier,
while the strategy remains unable to read that execution evidence. The later
daily high, low, close, volume total, and later status facts are not consulted.

### W10. Fixed Basket With An Isolated Gap

The investment universe is a static two-instrument basket. One classified gap
is handled under an explicit availability policy without requiring fictional
dynamic membership.

### W11. Dynamic Membership With Complete Observations

Membership changes while each effective member has complete accepted
observations. The prototype must not infer observation sparsity from membership
dynamics.

### W12. Historically Knowable Broader Estimation Population

The investment universe is narrower than a broader estimation population that
was knowable at fit time. Using the broader population is permitted and its
identity is recorded.

### W13. Future-Selected Estimation Population

The same historical rows are selected using knowledge of future index entry.
The fit is rejected or labeled non-causal. This witness differs from W12 only
in population-construction information.

### W14. Full-Train Fit Used In An Early Training Replay

A transform fitted on January-December inputs is requested by a February
decision in the same window. Causal mode rejects the unavailable artifact;
retrospective in-sample mode may use it only with an explicit label that bars
an out-of-sample interpretation.

### W15. Delayed Label And Later Revision

A feature observation predates the fit boundary, but its supervised outcome or
revision becomes knowable afterward. The fitted artifact excludes unavailable
labels and revisions. Perturbing outer-test data leaves fitted numeric state
unchanged when fit inputs and RNG are fixed. The fixture performs an actual
small fitted transform and records its numeric state, fit population, label
maturity cutoff, information cutoff, and RNG identity; it does not substitute
a pre-labelled placeholder artifact.

### W16. Effective-Dated Revision

An open lifetime or membership assertion is later closed or corrected. An
as-of query before the amendment reproduces the earlier answer; an as-of query
afterward sees the revision. Both answers retain provenance.

### W17. Future-Fact Perturbation

Adding a fact not yet knowable before the declared comparison cutoff leaves
earlier strategy-visible state, features, targets, fills, and economic outputs
unchanged. An announced future-effective event may affect decisions after its
announcement when the declared strategy consumes that information. Snapshot
and dependent artifact identities change because hashed source facts changed.

### W18. Cached Positional State Across Membership Change

A membership change reorders a pulse-local public axis. Supported state keyed
by stable instrument ID remains correct. A checked accessor or axis-bound token
rejects a stale positional reference. Raw integers retained by arbitrary user
code are outside the certified contract and cannot be detected reliably; the
report documents that unsafe pattern without promising generic detection.

### W19. Incomplete Candidate In Selection

One candidate stops before the intended horizon because valuation evidence is
insufficient. Its prefix metric is not treated as comparable complete-period
evidence. Intended horizon, achieved horizon, stop reason, affected exposure,
and selection eligibility remain visible beside successful candidates.

### W20. Prototype Reconstruction, Cache, And Parallel Parity

For supported complete and incomplete fixtures, direct materialization,
fork-local serialized reconstruction, cold and warm cache paths, and sequential
and parallel provider-only calls recover matching fork-only inputs and evidence.
Separate parallel full-fork tasks recover matching targets, quantities,
economic results, evidence status, and declared prototype identity. This
witness does not claim package sweep, reopen, walk-forward, or promotion
integration.

### W21. Dense Reconstruction Parity

Across the compact dense control set defined in Section 3, the instrumented
fork and package fold produce the same values, ordering, target validation,
risk output, fills, accounting, events, metrics, carried state, and final-pulse
behavior. Same-version identity remains byte-identical where canonical payloads
are unchanged. New-version identity is reported separately rather than assumed
equal.

### W22. Unpriced Holding Through Max-Weight Risk

A held instrument has no accepted decision-time close, but the valuation policy
admits a separate bounded-stale mark. A chain containing `max_weight` must not
abort merely because the strategy close is `NA`. The risk result records the
valuation source, age, and a typed pass-through or reduction reason under the
approved policy. The same risk chain has the same `risk_chain_hash`; valuation
facts and valuation-policy identity carry the differing evidence.

### W23. Post-Risk Closure On Restricted Holdings

Two restricted holdings exercise the closure rule. A long holding of 100 with
a hold target of 100 is reduced to 80 by `max_weight`; post-risk validation
accepts 80 because its sign is unchanged and its magnitude is smaller. A short
holding with a hold target equal to its negative current quantity is mapped to
zero by `long_only`; post-risk validation accepts zero. Both strategy outputs
first satisfy the accepted hold-or-zero rule. The short case is a bounded
algebraic closure test, not authorization or validation of broker-style short
accounting.

### W24. Held State Across A Fold Boundary

The closing state of one fork execution contains a former member that remains
held. The next fork execution receives that state on an opening axis containing
current members plus the holding. Opening validation accepts the stable-ID
quantity, lot, cash, and valuation evidence without requiring current
membership. This is a fold-boundary semantic witness, not a claim that the
current walk-forward orchestrator already supports the new state.

### W25. Transform Graph And Cache Invalidation

The sealed raw series is `1, 3, NA, 9`. A causal carry-forward followed by a
two-observation rolling mean yields `NA, 2, 3, 6`. The same rolling mean applied
before carrying the derived indicator yields `NA, 2, 2, 2`. Both graphs are
causal under their declared rules, but they answer different questions.

The expected feature values are exact, the graph identities differ, and a warm
cache invalidates affected descendants while preserving ancestors whose full
semantic identity is unchanged. Targeted mutations cover the relevant
calendar, classifier, estimation population, and training cutoff. The witness
also uses the actual fitted transform from W15. Neither graph creates an
observed or executable bar.

### W26. Empty Public Domain And First Entry

A pulse has no current members and no held positions. The fork invokes the
strategy with an empty public domain and accepts a named zero-length numeric
target, producing no target rows or fills. When the first historically knowable
member enters later, it appears without exposing its future entry on the empty
pulse.

### W27. History Across Exit And Re-Entry

A stable asset exits membership, remains held for one scenario, and later
re-enters. Its admissible pre-exit observations remain keyed to stable asset ID.
Rolling history, warm-up state, and supported strategy state follow the declared
history policy across both transitions without positional reuse or future
membership leakage.

### W28. Calendar And Age Semantics

On one declared venue calendar, a scheduled closure and a missing expected
session produce different expectation reasons and valuation ages. The expected
session clock does not age a mark on the scheduled closure but does age it on
the missing expected session. Multi-venue UTC scheduling is deferred from this
spike and must not be claimed from this witness.

### W29. Stable Asset And Alias Continuity

One stable asset changes ticker while its lots, accepted history, features, and
identity continue. A later different asset reuses the old ticker and receives a
different stable ID with no inherited state. Public labels may change; economic
and cache identity remain bound to stable asset identity.

### W30. Consumer-Specific Missingness

The same missing feature value reaches two declared consumers. A scalar Boolean
signal rejects consumption under its guard, while a model with native missing
value handling may consume it under a fitted, identity-bound contract. Neither
consumer changes observation, valuation, or execution-price state. The witness
records the distinct usability verdict and reason for each consumer. The model
consumer is a prototype-only stub; this witness does not authorize an ML API.

### W31. Combined Lifecycle And Exposure Stress

An asset leaves membership while held, loses its fresh mark, receives a
post-risk target reduction, and then fails to fill. Requested exposure and
actual exposure remain separate: the risk reduction does not claim that the
position changed. One branch resumes with a fresh explicit target; another
exhausts the valuation horizon and records incomplete evidence. No hidden order,
fabricated fill, or terminal event is inferred.

## 7. Disqualifying Properties

A prototype is removed from performance ranking if it:

- exposes to the decision path a future instrument, fact, value, dimension, or
  decision-time name; retrospective audit views may show later transitions
  when clearly labeled and kept outside strategy execution;
- changes earlier causal outputs under W17;
- requires unchanged content hashes after changing hashed facts;
- fills from carried, stale-valuation-only, imputed, synthetic, rejected, or
  otherwise non-executable values;
- derives open eligibility from information unavailable at the open;
- carries a target or no-fill diagnostic as a persistent order;
- collapses unknown lifetime, missing valuation, or unsupported terminal
  accounting into one state;
- silently exceeds its declared budget or assumes failed-sale proceeds;
- treats incomplete-prefix performance as complete comparable evidence;
- changes dense semantic outputs without an accepted correction;
- cannot reproduce its result through fork-local reconstruction, cache, or
  parallel paths; or
- proposes the instrumented fork, an event-native path, or any other prototype
  executor as a production architecture.

## 8. Synthetic And Empirical Fixtures

Use three fixture families:

1. **Small semantic fixtures:** W1-W31, sized for exact expected tables.
2. **Empirical-shape workloads:** public synthetic data shaped from the
   reviewed Sharadar evidence without reproducing private data.
3. **Current dense controls:** established package fixtures covering the W21
   execution cases.

The empirical-shape family uses predeclared matched slices, not one large
Cartesian grid:

- near-dense, moderate-occupancy, and low-occupancy windows;
- similar occupancy with smooth and bursty membership transitions;
- short and longer rolling-history requirements;
- one full-fork execution and repeated candidates or folds sharing prepared
  inputs; and
- minimal and detailed diagnostic retention.

At least one workload is no smaller than 500 instruments by 750 sessions.
Scale upward only enough to expose allocation or working-set behavior within
the recorded host budget. Each measured feature workload computes an actual
rolling feature and a small cross-sectional transform; precomputed constants
cannot stand in for history or alignment work.

One empirical-shape scenario includes a deliberately chosen 10 percent
membership-churn stress level plus pre-membership history, isolated gaps,
scheduled closures, status changes, stale marks, and revisions. The report
calls 10 percent a synthetic stress parameter, defines its denominator, and
does not attribute it to the empirical study. Multi-venue calendar comparison
is deferred and cannot be claimed from the single-calendar witnesses.

## 9. Measurement Protocol

Measure only semantic survivors. Use the same materializer interface,
instrumented fold fork, strategy, seed, and retention setting.

Measure provider-only materialization separately from full-fork execution.
Keep the approved policy configuration fixed within each matched comparison.

Report separately:

- one-time canonical-store preparation time and retained bytes;
- cold materialization time;
- warm materialization and cache time;
- per-fold hydration time;
- fold execution time;
- per-candidate execution time under repeated reuse;
- per-pulse time;
- complete provider-owned bytes, including backing frames, indexes, histories,
  caches, temporary conversions, and buffers;
- peak process RSS;
- worker replication cost for provider-only and full-fork parallel tasks;
- cache-key count and invalidation behavior;
- diagnostic-retention rows and bytes by retention tier; and
- prototype serialization and reconstruction time.

For this charter, a cold application run uses a fresh R process, a fresh data
connection, and an empty application cache. Filesystem-cache state is recorded
separately and is not called cold unless the command actually controls it. A
warm run reuses the declared process and application cache after a recorded
pre-pass. Report process-level memory alongside R object-size estimates because
external allocations are not fully represented by object size.

Randomize or rotate prototype execution order, perform a warm pre-pass where
appropriate, and report repetitions and dispersion. Do not infer overhead from
one sequential row order.

The measured fixture is the boundary of every performance claim. No public
benchmark or production optimization commitment follows from the spike.

The prototype/package boundary is:

| In this spike | Deferred production integration |
| --- | --- |
| Parallel provider-only and full-fork tasks | Public parallel sweep dispatch |
| Serialize and restore prototype inputs and evidence | Saved-sweep and committed-run reopen |
| Select a prototype row and reconstruct or rerun it | Public candidate extraction and promotion |
| Carry state between two fork executions | Walk-forward orchestrator integration |

Prototype equivalents are labeled as such and must not be reported as package
parity.

## 10. User Workflow Evidence

The report includes three connected, executable journeys using prototype-only
names:

1. **Prepare data:** inspect which lifetime, membership, calendar, revision,
   and knowledge-time facts are present before sealing.
2. **Define and run research:** declare investment and estimation universes,
   availability, valuation, removal, preprocessing, and incomplete-evidence
   policies; inspect the effective plan; run through the shared spike fork.
3. **Explain and revisit:** trace one decision through feature state, target,
   risk, execution, position, valuation, metrics, prototype serialization, and
   candidate reconstruction.

The journeys include one entrant, one retained former member, one unavailable
execution opportunity, and one attractive but incomplete result that is not
eligible as complete evidence.

These are spike evidence, not package vignettes. Future teaching work remains
subject to `../vignette_styleguide.md` and a separately authorized release.

The maintainer or named non-executing reviewer also performs a bounded
task-based read-through before seeing the recorded result. They predict and
then locate the explanation for:

- why a removed member remains held;
- whether a failed exit is retried automatically;
- whether a stale mark permits a purchase;
- which population and cutoff fitted an imputer; and
- whether an attractive prefix result may participate in selection.

The report records wrong predictions, manual joins, hidden assumptions, and
missing diagnostics, then distinguishes safe defaults from expert policy
configuration in the printed effective plan. This is a comprehension check,
not a formal user study, and it does not reopen the accepted zero-target or
held-non-member constructor semantics.

## 11. Required Spike Report

The spike report must contain:

- the frozen witness-specification version and separate semantic-oracle and
  representation-discriminating conformance tables for W1-W31 by prototype;
- checker-mutation results for stale execution prices, status supersession,
  omitted holdings, and missing cache dependencies;
- exact failure evidence for every disqualified prototype;
- preserved failed attempts, repairs, and implementation effort by prototype;
- representation diagrams after, not before, the semantic table;
- measurement tables for semantic survivors, with fixture, host, seed, order,
  repetition, and retention metadata, or an explicit reason no prototype was
  eligible for timing;
- a separate output-causality and identity-perturbation table;
- an explainability and retention-cost comparison;
- a reviewed green, red, or inconclusive terminal outcome;
- the package base commit, immutable spike commit or archive reference,
  prototype change inventory, fixture generator, commands, dependency and
  environment record, expected tables, and retained result files;
- open product choices that measurement cannot decide; and
- the empirical limitations carried verbatim from the evidence synthesis.

## 12. Staged Execution

Run the spike in five bounded stages:

1. **Clarify the charter:** close contradictory executor instructions and
   freeze this revision.
2. **Write witness evidence:** record exact facts, outputs, arithmetic, temporal
   reasoning, and the initial policy configuration; obtain maintainer approval
   and independent review.
3. **Build the shared fork and reference provider:** record the fork change
   inventory, pass the dense control set, and prove the checker catches each
   deliberate defect.
4. **Add remaining providers and journeys:** run conformance, graph/cache
   mutations, full-memory accounting, and the comprehension check without
   representation-specific execution policy.
5. **Measure and close out:** run the bounded workload family, retain evidence,
   attribute failures, and obtain independent terminal review.

No timing from an earlier stage is architecture evidence. A later correction
to the fork, checker, expected table, or common policy reruns every affected
provider before comparison.

## 13. Exit Gate And Handoff

The spike may reach a reviewed terminal outcome only when:

- the repository maintainer approved all expected witness outcomes before
  timing;
- all conformance checks and any permitted measurements are reproducible from
  recorded commands and fixtures;
- no package runtime or public API was changed;
- the named non-executing reviewer verified the conformance tables; and
- the report states which conclusions are semantic, measured, inferred, or
  still choices.

The terminal outcomes are:

- **Green:** one or more representations pass conformance and have valid
  measurements. Seed v2 may consume the comparison without treating it as
  production integration evidence.
- **Red:** the harness and witness specification are valid, but no
  representation survives. The failed attempts remain evidence for revising
  the architecture or representation set.
- **Inconclusive:** a checker, shared-fork, expected-outcome, resource, or
  experimental-design problem prevented a valid comparison. Seed v2 may not
  select a representation from the result; the blocker is corrected or
  explicitly carried unresolved.

Failures are attributed before choosing the next action. A shared-fork defect
is fixed once and all affected providers rerun. An unsatisfiable expected
outcome returns to the maintainer as a design decision. A resource limit is not
reported as a representation defect. Repairs and abandoned attempts remain in
the evidence record so implementation effort is not hidden.

Package-level parity for committed runs, sequential and parallel sweeps,
saved-sweep reopen, walk-forward opening state, candidate extraction, and
promotion is deferred to implementation acceptance after an RFC synthesis and
specification authorize integration. W20 and W24 provide prototype evidence
for that later work; they do not satisfy those production gates.

Executable fork and provider code never merges into production, but it remains
reproducible at an immutable commit retained under a named non-release ref or a
durable archive. The report and accepted design conclusions may move forward
without copying prototype code into the package.

The spike report does not authorize implementation, a schema, an API, a mode,
or tickets.
