# Response Review Addendum: Asset Availability And Point-In-Time Universes

## 1. Status And Authority

**Status:** Stage 4 follow-up review addendum, accepted as an input to the
comparative architecture spike. Non-binding for implementation.

**Author:** Codex, acting as the Seed v1 author and response reviewer.

**Date:** 2026-09-07.

**Revision history:**

- Revision 1 restored four omitted review details, distinguished the
  pre-existing portfolio-budget gap from ragged-universe exposure, and
  preserved the accepted quantity semantics while reopening only the
  removal-policy default and its budget interaction.
- Revision 2 corrected the Section 16.3 finding: the response leaves the stale
  mark and observed-close relationship underspecified; it does not logically
  require a stale mark in the close vector.

**Reviews:**

- `rfc_asset_availability_point_in_time_universes_v0_1_9_8_seed.md`;
- `rfc_asset_availability_point_in_time_universes_v0_1_9_8_response.md` at
  commit `898fe0eceb59e908cf6dd08f9739ba9345caea95`;
- `../research/Sharadar-Empirical-Evidence.md`;
- `../research/ledgr_ragged_universe_prior_art_review.md`;
- `../research/rfc-evidence-handoff.md`; and
- the current execution, strategy, risk, cache, walk-forward, and result
  contracts in `../contracts.md` and `R/`.

This addendum preserves the accepted response as a historical Stage 3/4
artifact. It does not edit or revoke that response. It records additional
methodological, API, and UX findings that must shape the spike charter and
Seed v2.

This addendum authorizes no implementation, schema, public API, runtime mode,
accounting behavior, OMS behavior, liquidity model, affordability layer, or
ticket cut.

## 2. Disposition

The architectural direction remains sound:

- canonical market and lineage facts are sparse, immutable, and hash-bound;
- membership, observation, valuation, execution, and feature validity remain
  separate state planes;
- bounded rectangular computation does not require fabricated observations;
- strategy-visible state remains decision-time only;
- one fold core remains mandatory; and
- physical storage and fold-local representation remain separate decisions.

The comparative architecture spike must not begin as a performance contest
between physical representations. Its first gate is semantic conformance to
the witnesses in the companion spike charter. A prototype that fails a
semantic witness is disqualified before timing or memory results are
interpreted.

Eight findings require disposition in the spike charter before the spike can
act as evidence for Seed v2. Five further findings become explicit Seed v2 or
spike-report obligations.

## 3. Findings Required Before The Spike

### R1. Preserved Holdings Need An Explicit Portfolio Budget

**Disposition:** confirmed; High.

`ledgr_target_rebalance()` currently sizes selected targets from total equity.
If a future ragged-aware helper preserves held non-members at their current
quantity while allocating member weights against total equity, retained
exposure and new target exposure can exceed NAV. The shipped risk chain has no
portfolio-level affordability, cash-floor, or gross-exposure rule.

This is not created by ragged universes. The current fold applies fill cash
deltas without a cash-floor check, and a dense-universe hold-based strategy can
already retain positions while adding new buys. The accepted constructor rule
for held non-members makes the gap easier to reach through documented helpers;
it does not originate the gap.

A second failure remains even if the helper subtracts retained exposure at
decision time: an intended sale can fail at the execution opportunity while a
replacement purchase succeeds. Expected sale proceeds are not realized cash.

**Spike requirement:** every prototype must expose the same declared budget
policy and reconcile cash, quantities, gross exposure, pre-risk targets, and
post-risk targets for:

- a retained former member plus full allocation to current members; and
- a failed sale paired with a successful replacement purchase.

Both cases must include a current dense-baseline row before applying a proposed
policy. A changed result is then identified as an explicit policy correction,
not attributed to the physical ragged representation.

The spike may compare policy alternatives, but none may be implicit. Candidate
policies include residual-budget sizing, conservative no-sale-proceeds sizing,
a declared financing assumption, a bounded affordability rule, or rejection
of the unsupported combination. The spike must not invent a general OMS,
liquidity model, or margin system.

### R2. Unknown Lifetime Is Not A Terminal Event

**Disposition:** confirmed; High.

The empirical lifecycle cases were adversarial and do not estimate population
rates. Missing or conflicting lifetime metadata does not establish an
economic terminal event. A held instrument may have unknown lifetime metadata
and a valid fresh observation.

Seed v2 and the spike oracle must distinguish:

1. incomplete lifetime metadata with a valid fresh observation;
2. an unavailable current mark with a permitted stale valuation;
3. no permissible valuation after the configured stale limit; and
4. an accepted terminal event whose settlement cannot yet be represented.

Only the last two can justify a valuation-related run stop, and the recorded
reason must name the failed evidence or accounting assumption. An unpriced
holding must not be mislabeled as a delisting or unresolved terminal event.

### R3. A No-Fill Diagnostic Is Not A Pending Order

**Disposition:** confirmed; High.

A zero target is a desired quantity for one decision. If its next execution
opportunity has no eligible price, ledgr records no fill and carries no order.
A later exit requires a fresh strategy target. Terms such as `pending`,
`standing exit`, or `exit when trading resumes` are forbidden unless a future
OMS contract explicitly creates persistent order state.

`ledgr_liquidate()`, if retained as illustrative assignment sugar, means only
`targets[id] <- 0`. It does not preserve intent across pulses.

**Spike requirement:** compare one zero target followed by a no-fill and a
later hold with the same sequence where zero is reissued. The first sequence
must not exit later; the second is a new, independently visible attempt.

### R4. Universe Selection And Availability Policy Are Independent

**Disposition:** confirmed; High.

A character-vector investment universe does not imply complete observations.
A fixed basket can contain isolated gaps, scheduled closures, halts, differing
listing histories, and unknown source states. Conversely, a changing
membership rule can have complete observations for every eligible member.

The public design must keep these axes independently expressible:

- which instruments are in the investment or strategy domain;
- which membership rule, if any, changes that domain over time; and
- how observation, valuation, and execution availability are classified.

The response's proposed inference that character input means dense semantics
and a classed membership rule means ragged semantics is withdrawn as a bound
recommendation. Exact API names remain a Seed v2 decision after the spike.

### R5. Lifetime And Trading Status Must Stay Separate

**Disposition:** confirmed; High before public API binding.

A trading halt, quotation-only period, pre-listing state, known delisting, and
unknown lifetime are not one `known_inactive` fact. A derived target
restriction may combine evidence from multiple planes, but it must preserve a
typed reason and knowledge cutoff.

Decision-time target admissibility remains separate from execution-time
fillability. For daily bars, execution eligibility at the open must not depend
on the later high, low, close, volume total, or a status update unavailable at
the open.

**Spike requirement:** include a halted current member with a still-usable
feature, a quotation-only state, and a valid observed bar with unknown
lifetime metadata. Show the strategy-visible state, requested target,
post-risk target, and execution verdict separately.

The response's scalar strategy example also needs correction. Its buy mask
checks membership and feature usability but not `target_restricted`, so a
halted member with a usable feature can receive a target that the following
validator rejects. Seed v2 examples and prototype helpers must either include
the restriction plane in the decision mask or enforce the same admissibility
rule through a named helper; they must not teach an example that triggers its
own declared error contract.

### R6. Fold-Local Fitting Is Not Automatically Historically Causal

**Disposition:** confirmed; High at the preprocessing boundary.

Fitting a transform only on a training fold prevents direct test-set fitting.
It does not make an earlier replay within that training fold causal. A
transform fitted using December observations was not available to a simulated
February decision in the same January-December window.

Seed v2 must distinguish:

- retrospective in-sample training diagnostics;
- transforms trained before a scored interval;
- causal rolling or expanding refits; and
- untouched outer evaluation.

Every fitted artifact needs an availability time, input and revision cutoff,
label-maturity rule, training-population identity, fit RNG identity, and
declared use boundary. General purging, embargo, CPCV, and an ML model API
remain deferred; unsupported causal claims must fail or be labeled rather than
being implied by `fold-local`.

The fit plan must also state which inner candidate-selection boundary requires
another preprocessing fit and the information cutoff used to reconstruct the
historical features available at that boundary. A single fit at the outer
training boundary does not make inner selection or earlier training replays
causal.

### R7. Investment Membership Is Not The Only Learning Population

**Disposition:** confirmed; High methodological correction.

The investment universe, research or estimation universe, and held-position
domain are distinct. A broader estimation population can be causal when its
membership and inputs were knowable at the fit time. A population selected by
future index membership is not causal.

Current-member-only fitting may be a deliberately supported first scope, but
it is not a universal leakage theorem. Cross-sectional preprocessing must bind
the historically knowable estimation population and its identity separately
from the strategy's investment membership.

A deterministic per-date cross-sectional transform may be precomputed across
the full requested date range when every dependency used for each date was
knowable on that date. That optimization remains causal only when the
date-specific estimation population, input cutoff, revision policy, and
transform identity are bound. Whole-range precomputation is not itself proof
of lookahead.

### R8. Causal Output Invariance And Artifact Identity Are Different Tests

**Disposition:** confirmed; High for spike validity.

Adding a future fact to a sealed snapshot should change the snapshot content
hash and dependent artifact identities. It must not change earlier admissible
features, decisions, fills, or economic outputs. The spike must not require an
unchanged whole-artifact hash after changing hashed source facts.

The perturbation oracle is:

| Perturbation | Must remain unchanged | May or must change |
| --- | --- | --- |
| Add a not-yet-knowable future listing | Earlier public state, features, targets, fills, and economic outputs | Snapshot and dependent artifact identities |
| Modify only outer-test observations | Fitted numeric state when fit inputs and RNG are fixed | Dataset and request/cache identity |
| Change training observations | No fitted-value parity guarantee | Fit-input identity and fitted artifact |
| Change an economically relevant policy | Only outputs proven unaffected by the fixture | Policy and dependent identities |

Stochastic perturbation tests must couple random streams when testing causal
outputs. Production RNG derivation remains a separate identity test.

Dense identity parity is qualified by identical canonical payloads, schema
versions, package versions, and other explicit identity inputs.

## 4. Further Seed v2 And Spike-Report Obligations

### R9. Removal And Flat Semantics Are Product Choices

Membership-aware `ctx$flat()` remains a defensible safe default, but it is not
a methodological invariant. Seed v2 must bind a removal policy and its budget
interaction. Literal full named numeric vectors remain valid strategy output.
Strategy state is keyed by stable instrument ID; positional indices are
pulse-local and must not be reused across membership changes.

### R10. Feature Usability And Age Need Consumer-Specific Clocks

`usable` must name the consumer contract. Scalar Boolean logic, a model with
native missingness, and a fitted imputer do not share one universal usable
predicate. Lookback and mark age must name their clocks: global pulses,
instrument-expected sessions, accepted observations, or elapsed time.
Observed closes and valuation marks remain separate values.

The response's Section 16.3 alternative is underspecified and must not survive
unchanged into Seed v2: `priced` includes a stale-within-policy mark, while the
statement that `ctx$vec$close` is `NA` wherever `!priced` says nothing about
what `close` contains when a stale mark makes `priced` true. It does not
logically require the stale mark to appear in `close`, but it leaves that
forbidden collapse available. Seed v2 must state the positive contract instead:
an accepted observed close and an accepted valuation mark have separate fields
and state. A holding can be valued from a permitted stale mark while its
strategy-visible close remains `NA` because no current observation was
accepted.

### R11. Explainability Must Join Decision To Outcome

Availability state alone does not explain a realized position. The shared
semantic oracle must connect:

- membership or carried-position reason at decision time;
- feature state and preprocessing identity;
- current quantity and pre-risk target;
- post-risk target and risk reason;
- execution opportunity and fill or no-fill result; and
- resulting position, valuation mark source, age, and policy.

Episode summaries are derived views. They must not merge changing requested
quantities or make fresh attempts look like one persistent order. The spike
must compare diagnostic-retention cost and state whether evidence is persisted,
reconstructed from sealed inputs, or unavailable at a retention tier.

### R12. Decision Views And Retrospective Audit Views Differ

Strategy-visible queries obey the as-of cutoff. Retrospective reports may show
the full internal axis, later transitions, source conflicts, and frame-size
telemetry when clearly labeled and kept outside strategy execution.

The threat model covers supported ledgr data and strategy interfaces. It does
not claim that arbitrary user R code, global data access, process inspection,
or wall-clock behavior is sandboxed.

### R13. Incomplete Runs Need Selection And Disclosure Rules

An incomplete candidate or fold must retain intended horizon, achieved
horizon, stop reason, affected exposure, and selection eligibility. A finite
prefix metric is not complete-period evidence. Comparable selection requires
the same evaluation horizon or an explicit exclusion shown beside the selected
row. The spike records these semantics; Seed v2 binds their integration with
existing sweep and walk-forward failure rows.

## 5. Precision Corrections Carried Forward

Seed v2 and the spike report must preserve these corrections:

- The seed did not reject masks. Static supersets plus orthogonal masks were a
  viable runtime component, though not sufficient as a public view.
- `members union held` is the chosen way to preserve one aligned public
  position/target domain. Current helpers make alternatives expensive; they do
  not make that architecture mathematically inevitable.
- `unknown` remains stored distinctly and has consumer-specific conservative
  behavior. It must not be described as failing every positive predicate when
  another plane, such as a held position or accepted observation, establishes
  a different consumer fact.
- The spike's membership churn rate is a chosen synthetic stress parameter,
  not a rate estimated from the Sharadar evidence.
- `observed_row_outside_expectation` is not synonymous with an off-calendar
  bar; expectation may also depend on lifetime, membership, and coverage.
- An unscheduled closure uses its actual announcement and knowledge time; it is
  not necessarily knowable only after the session.
- A per-instrument feature remains cache-safe only when its complete semantic
  dependency identity includes calendar, classification, stale-input policy,
  admissible-history rule, and other relevant ancestors.
- Effective-dated fact fixtures include a revision witness: an open assertion
  is later closed or corrected while preserving the earlier as-of answer.
- Dense parity is measured across values, ordering, arithmetic, artifacts, and
  same-version identity. It is not assumed from an inert-plane design.

## 6. Maintainer Choices Preserved

The addendum does not decide:

- residual-budget, conservative-budget, financing, bounded-affordability, or
  rejection policy for preserved holdings;
- the default removal policy when membership ends and its interaction with the
  declared portfolio budget;
- partial reductions directly from strategy output;
- the first-implementation default for an exhausted valuation horizon;
- fixed-member-only versus a broader historically knowable estimation
  population in the first implementation;
- the public constructor names or exact state-view shape; or
- the diagnostic retention tier.

The accepted quantity semantics are not reopened: zero always means desired
quantity zero, target wrappers remain thin, package constructors initialize a
held non-member to its current quantity, and liquidation requires an explicit
zero target. The spike may compare removal-policy defaults around those rules;
it may not restore command semantics or persistent intent to target vectors.

The spike may compare alternatives. Seed v2 must select or explicitly defer
each choice before synthesis.

## 7. Required Handoff

The next artifact is
`rfc_asset_availability_point_in_time_universes_v0_1_9_8_spike_charter.md`.
The spike may start only against that charter. Its report becomes evidence for
Seed v2; it is not itself architecture authority.

After the spike:

1. Seed v2 incorporates the measured representation results and the semantic
   witness outcomes.
2. Irreducible product choices move to a maintainer-decisions artifact only if
   Seed v2 cannot recommend a default.
3. Synthesis is authored by an eligible different author.
4. Final review verifies decisions, evidence limits, and non-scope before any
   specification or tickets.
