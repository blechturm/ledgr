# Comparative Architecture Spike Charter: Asset Availability And PIT Universes

## 1. Status And Authority

**Status:** Chartered, not started. Non-binding architecture evidence work.

**Date:** 2026-09-07.

**Revision note:** Revised after execution-readiness review. The spike now uses
a disposable instrumented fold fork, separates semantic-oracle witnesses from
representation-discriminating witnesses, adds the missing response-blocker
witnesses, and assigns approval, execution, and review roles.

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
diagnostic-retention cost while preserving one fold core and the existing dense
path?

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
reimplement those semantics. This is the shared semantic oracle against which
all representations run.

The conceptual materializer output contains:

- deterministic `axis_ids` for the bounded window;
- the declared global pulse axis and per-instrument expected-session state;
- observed and accepted OHLCV planes without fabricated executable values;
- membership, lifetime, observation, valuation, trading-status, execution,
  and feature-validity state with knowledge times;
- valuation marks separated from observed closes;
- decision-time public views filtered to knowable members plus held IDs;
- execution-time inputs unavailable to the strategy context;
- complete typed dependency identity; and
- reason-coded evidence sufficient to explain each witness.

Names and physical layouts are illustrative. The spike report records the
common semantic fields actually used by all survivors.

Before any ragged witness is interpreted, W21 must show parity between the
instrumented fork and the package fold on the current dense fixture. A fork
that fails this control is invalid; its remaining conformance or timing rows
must not be used.

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

## 5. Semantic Witness Format

Each witness records:

- canonical facts and their effective, knowledge, and revision times;
- investment universe, estimation universe, and held-position domain;
- decision pulse and strategy-visible state;
- current quantity, pre-risk target, and post-risk target;
- execution opportunity and fill or no-fill result;
- cash, position, gross exposure, and valuation after execution;
- diagnostic or incomplete-evidence result;
- identities expected to remain equal; and
- identities expected to change.

Expected outcomes are written before prototype timing is examined.

Witnesses have two roles:

| Class | Witnesses | Meaning of a passing conformance row |
| --- | --- | --- |
| Semantic oracle | W1-W16, W19, W22-W24 | The representation supplied the required evidence and the shared fork produced the maintainer-approved semantic outcome. Identical rows are expected and do not rank representations. |
| Representation discriminating | W17, W18, W20, W21 | The representation also satisfies causality, stable-ID, reconstruction, cache/parallel, or dense-parity properties that can differ by physical shape. |

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

The table includes the equivalent current dense-fold sequence, including any
negative-cash result, before applying the approved policy. This makes the
pre-existing accounting-policy gap visible rather than attributing it to
ragged membership.

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
eligibility at an EOD open uses only evidence knowable for that open. For this
witness, the open is fillable only when an execution-bar open exists and no
status fact with `knowledge_time <= open_time` forbids trading. The later daily
high, low, close, volume total, and later status updates are not consulted.

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
unchanged when fit inputs and RNG are fixed.

### W16. Effective-Dated Revision

An open lifetime or membership assertion is later closed or corrected. An
as-of query before the amendment reproduces the earlier answer; an as-of query
afterward sees the revision. Both answers retain provenance.

### W17. Future-Fact Perturbation

Adding a future listing leaves earlier strategy-visible state, features,
targets, fills, and economic outputs unchanged. Snapshot and dependent artifact
identities change because hashed source facts changed.

### W18. Cached Positional State Across Membership Change

A membership change reorders a pulse-local public axis. Supported state keyed
by stable instrument ID remains correct. Reusing a cached positional index must
fail clearly or be outside the certified contract; it must not silently refer
to another instrument.

### W19. Incomplete Candidate In Selection

One candidate stops before the intended horizon because valuation evidence is
insufficient. Its prefix metric is not treated as comparable complete-period
evidence. Intended horizon, achieved horizon, stop reason, affected exposure,
and selection eligibility remain visible beside successful candidates.

### W20. Prototype Reconstruction, Cache, And Parallel Parity

For supported complete and incomplete fixtures, direct materialization,
fork-local serialized reconstruction, cold and warm cache paths, and sequential
and parallel materializer calls recover matching fork-only execution inputs,
targets, quantities, economic results, evidence status, and declared prototype
identity. This witness does not claim package sweep, reopen, walk-forward, or
promotion integration.

### W21. Dense Reconstruction Parity

On the existing dense fixture, the instrumented fork and package fold produce
the same values, ordering, target validation, risk output, fills, accounting,
events, metrics, and reconstruction behavior. Same-version identity remains
byte-identical where canonical payloads are unchanged. New-version identity is
reported separately rather than assumed equal.

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
first satisfy the accepted hold-or-zero rule.

### W24. Held State Across A Fold Boundary

The closing state of one fork execution contains a former member that remains
held. The next fork execution receives that state on an opening axis containing
current members plus the holding. Opening validation accepts the stable-ID
quantity, lot, cash, and valuation evidence without requiring current
membership. This is a fold-boundary semantic witness, not a claim that the
current walk-forward orchestrator already supports the new state.

## 7. Disqualifying Properties

A prototype is removed from performance ranking if it:

- exposes a future instrument, fact, value, dimension, or decision-time name;
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
- cannot reproduce its result through supported reopen, cache, or parallel
  paths; or
- proposes the instrumented fork, an event-native path, or any other prototype
  executor as a production architecture.

## 8. Synthetic And Empirical Fixtures

Use three fixture scales:

1. **Small semantic fixtures:** W1-W24, sized for exact expected tables.
2. **Empirical-shape fixture:** not less than 500 instruments by 750 sessions,
   shaped from the reviewed Sharadar evidence without reproducing private data.
3. **Current dense baseline:** the established dense package and benchmark
   fixtures.

The empirical-shape fixture includes a deliberately chosen membership-churn
stress level, initially 10 percent, plus pre-membership history, isolated gaps,
scheduled closures, status changes, stale marks, and revisions. The report
must call 10 percent a synthetic stress parameter, define its denominator, and
must not attribute it to the empirical study.

## 9. Measurement Protocol

Measure only semantic survivors. Use the same materializer interface,
instrumented fold fork, strategy, seed, and retention setting.

Report separately:

- cold materialization time;
- warm materialization and cache time;
- fold execution time;
- per-pulse time;
- materialized-frame bytes;
- peak process RSS;
- worker replication cost under parallel sweep;
- cache-key count and invalidation behavior;
- diagnostic-retention rows and bytes by retention tier; and
- reopen and reconstruction time.

Randomize or rotate prototype execution order, perform a warm pre-pass where
appropriate, and report repetitions and dispersion. Do not infer overhead from
one sequential row order.

The measured fixture is the boundary of every performance claim. No public
benchmark or production optimization commitment follows from the spike.

## 10. User Workflow Evidence

The report includes three connected, executable journeys using prototype-only
names:

1. **Prepare data:** inspect which lifetime, membership, calendar, revision,
   and knowledge-time facts are present before sealing.
2. **Define and run research:** declare investment and estimation universes,
   availability, valuation, removal, preprocessing, and incomplete-evidence
   policies; inspect the effective plan; run through the shared spike fork.
3. **Explain and revisit:** trace one decision through feature state, target,
   risk, execution, position, valuation, metrics, reopen, and promotion.

The journeys include one entrant, one retained former member, one unavailable
execution opportunity, and one attractive but incomplete result that is not
eligible as complete evidence.

These are spike evidence, not package vignettes. Future teaching work remains
subject to `../vignette_styleguide.md` and a separately authorized release.

## 11. Required Spike Report

The spike report must contain:

- separate semantic-oracle and representation-discriminating conformance
  tables for W1-W24 by prototype;
- exact failure evidence for every disqualified prototype;
- representation diagrams after, not before, the semantic table;
- measurement tables with fixture, host, seed, order, repetition, and
  retention metadata;
- a separate output-causality and identity-perturbation table;
- an explainability and retention-cost comparison;
- a clear recommendation or an honest no-winner verdict;
- open product choices that measurement cannot decide; and
- the empirical limitations carried verbatim from the evidence synthesis.

## 12. Exit Gate And Handoff

The spike is complete only when:

- the repository maintainer approved all expected witness outcomes before
  timing;
- at least one prototype survives every disqualifying property;
- measurements are reproducible from recorded commands and fixtures;
- no package runtime or public API was changed;
- the named non-executing reviewer verified the conformance tables; and
- the report states which conclusions are semantic, measured, inferred, or
  still choices.

Package-level parity for committed runs, sequential and parallel sweeps,
saved-sweep reopen, walk-forward opening state, candidate extraction, and
promotion is deferred to implementation acceptance after an RFC synthesis and
specification authorize integration. W20 and W24 provide prototype evidence
for that later work; they do not satisfy those production gates.

If no prototype survives, the result is a red spike and Seed v2 must revise the
architecture before synthesis. If one or more survive, Seed v2 consumes the
conformance and measurement record and selects or preserves alternatives.

The spike report does not authorize implementation, a schema, an API, a mode,
or tickets.
