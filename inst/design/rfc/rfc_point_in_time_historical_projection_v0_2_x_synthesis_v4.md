# RFC Synthesis v4: Point-in-Time Historical Projection With Missing-Data Policy

**Status:** Decision synthesis, superseding
[synthesis v3](rfc_point_in_time_historical_projection_v0_2_x_synthesis_v3.md),
which required revision, and incorporating the
[maintainer missingness amendment](rfc_point_in_time_historical_projection_v0_2_x_missingness_amendment.md).
Decisions bind on maintainer acceptance.
**Date:** 2026-09-26
**Author:** Claude, per role rotation.
**Baselines:** design `491c4ed`; implementation `ae040e7`. Claims are marked
verified by reading, verified by execution, or open.

**What this document is for.** v3 carried four findings its own reviewer of
record accepted and did not repair. The amendment then added a product
direction v3 had excluded. This document repairs the first and incorporates the
second in one place, and it proposes concrete defaults with their consequences
rather than returning a list of open questions. Section 1 is the whole policy in
one table; the rest is the reasoning, the repairs and what is still gated.

---

## 1. The proposed policy, in one table

Every row is a proposal for maintainer acceptance, not a recorded decision. The
maintainer's own decisions - that the ML release ships simple carry-forward plus
missingness information for prices and indicators, that price padding is
intended on by default with an off switch, and that indicator-output carry is
available independently - are inputs to this table and are not reopened by it.

| Question | Proposed default | Consequence if accepted |
| --- | --- | --- |
| Which sessions a feature window counts | Venue open sessions. Lifetime facts do not narrow the feature axis. | The matrix stops carrying a knowledge clock, v3's trip-wire closes, and features share one axis with valuation. A resumed instrument is `NA` until a full real window accumulates. Requires a design-text change (section 4). |
| Price-input carry | **On**, bounded by a required declared maximum carry age, default **5 venue open sessions**. | Ordinary isolated missing prints fill; structural absence stays `NA`. Safe without knowing where gaps concentrate, because the bound does the work (section 5.1). |
| Carry across an accepted `known_inactive` interval | **Never**, at any age. | A suspension is never bridged by fabricated prices. Independent of the age limit (section 5.2). |
| Indicator-output carry | **Off** by default, available on. | Avoids compounding two treatments by default. A carried output is stale in a way a recomputed one is not, and with price carry already on the second treatment buys little (section 5.3). |
| Which fields carry | `open`, `high`, `low`, `close`, each from its own latest admissible earlier value. **`volume` never carries.** | No cross-field synthesis: carrying a close does not invent a high. A window requiring volume over a gap stays `NA` rather than asserting fabricated liquidity (section 5.4). |
| Readiness under carry | `stable_after` is satisfied on prepared inputs. No rejection threshold. | "Ready" changes meaning and the contract must say so. The carried count and share travel with the value so a consumer can threshold; the engine does not threshold for them (section 5.5). |
| Age clock | Venue open sessions, counted from the carried value's own source time, stated explicitly. | Independent of `ledgr_valuation_stale(max_sessions)`; repeated carry does not refresh age (section 5.6). |

Two defaults carry most of the safety: the age limit and the inactive-interval
prohibition. Everything else is ordinary scoping.

## 2. Settled and carried forward unchanged

Not reopened here, and not re-argued:

- **The knowledge clock.** A history request at simulated decision pulse `t`
  returns, for each historical column `s <= t`, the value and evidence knowable
  at `t`: knowledge clock fixed at `t`, effective clock varying with the column.
  `t` is the simulated decision pulse, never snapshot-seal time and never
  wall-clock now. Accepted in Type 2 review and reaffirmed by the amendment.
- **The column clock.** Columns are consecutive prepared decision pulses ending
  at the invoking pulse, never the last `L` non-missing observations per asset,
  because a per-asset clock gives different assets different time axes in one
  matrix and silently destroys any cross-sectional estimate built from it.
  Leading padding uses `NA_real_`; pre-range history is never silently fetched.
- **Evidence semantics.** A fact effective at `s` but first knowable after `t`
  does not appear; a fact effective at `s` and knowable at `t` appears in column
  `s` even if it was not knowable at `s`. Membership and observation stay
  independent. Historical `held`, `priced`, `mark_age` and `tradable()` state is
  not replayed: those depend on portfolio state and valuation policy, and a
  stale risk mark is never an observed close or a feature input
  (`contracts.md:401-405`).
- **Ownership and shape.** The projection is the single owner and the
  lower-projector direction stays closed (verified by execution). Direction 5.4
  is preserved including its `ctx$window()` spelling. The row axis and its order
  follow `contracts.md:348-352`. The access boundary follows the maintainer
  correction of 2026-09-26, owned by LDG-2864 and LDG-2850.
- **One causal world.** No second execution engine and no second execution path.
  History serves estimation; `ledgr_run_explain()` serves audit; no second
  replay mode ships (section 9).

## 3. Repairs to synthesis v3

Four findings were accepted and not acted on. Each is repaired here rather than
recorded as a withdrawal, because v4 replaces v3 rather than annotating it.

**3.1 The recomputation prohibition is withdrawn.** v3 held that no present or
future resolution could be "recompute the matrix at `t`", citing
`contracts.md:809-810`. That rule forbids later-known facts rewriting cached
earlier outputs. It does not forbid constructing a new, separately identified
view. The accepted packet states the distinction directly: "History admission is
recomputed as of each use cutoff; later-known history cannot retrospectively
alter cached earlier outputs" (v0.2.0.0 spec section 3.5, verified). The
amendment's section 4 reaches the same correction independently: "Do not use
cache immutability to prohibit constructing such a new view."

This was the third instance of one error shape in this cycle - taking a rule
that protects earlier *results* and inflating it into a prohibition on new
*views*. v1 did it with `contracts.md:354-358`; v3 did it with `:809-810`.

**3.2 The mixed-clock section is removed, not deferred.** v3 section 3.4
presented a matrix on the causal clock beside evidence on the knowledge-at-`t`
clock as forced. It was forced only by 3.1's prohibition. Under section 4's
proposal the question does not arise at all, because the feature axis stops
depending on knowledge-timed facts. If the maintainer rejects section 4 and
keeps narrowing, the matrix-clock choice reopens and section 4.4 states what it
would then be.

**3.3 The cost claim is withdrawn and reversed.** v3 claimed the fixed-`t`
decision reduces `L` preparations to one. The rejected per-column-cutoff view
queries the existing single-clock segments along the diagonal, where they are
correct, and `ledgr_availability_prepared_cursor()` advances vectorised for
non-decreasing cutoffs and re-seeks by `cumsum` otherwise, with no rebuild at
any cutoff (`R/availability-provider-prepared.R:133-162`, verified). So the
rejected clock needs no additional preparation and the chosen clock needs new
machinery. The chosen clock is still chosen, on semantics; the cost argument for
it is gone. Section 9 also withdraws the same argument where v3 applied it to
the excluded replay mode.

**3.4 The checkpoint's failure criterion is now a single line.** v3 stated three
different tests. Section 10 replaces them: preparation before execution plus
bounded indexed retrieval or incremental cursor advance is compatible;
reconstructing instrument-by-boundary segments at any pulse stops the
checkpoint.

## 4. The feature session axis

### 4.1 The divergence, restated

Binding text and implementation disagree, and they disagree about values rather
than coverage. The availability synthesis says an instrument's expected
sessions, "which drive feature windows and observation classification, are the
venue open sessions minus those inside an accepted `known_inactive` lifetime
interval"; `contracts.md:803` says "Strict feature windows count expected
sessions"; and the v0.2.0.0 packet requires that "instrument expected sessions
exclude known inactivity for features" (verified at three authorities).

The implementation does not narrow. Feature hydration builds one frame per
instrument on the venue pulse axis, NA-fills absent observations as
`MISSING_EXPECTED_SESSION`, and **fails the run** if any per-instrument axis
differs from the venue axis (`R/backtest-runner.R:873-907`, gate at `:904-905`).
`ledgr_compute_feature_series_strict()` rolls `width` consecutive rows and skips
to `NA` on any non-finite value in the window (`R/features-engine.R:286-320`).
`known_inactive` reaches only trading restriction
(`R/availability-provider.R:195-203`) and terminal handling
(`R/fold-engine.R:505`); it does not reach the feature path at all.

Narrowing removes inactive sessions so a `width`-session window reaches back
past the interval and returns a value. Gating leaves them as `NA` so any
overlapping window returns `NA`. This is not a spec-cut: the rule was added as a
deliberate final-review patch and appears in the accepted packet.

### 4.2 Proposal: adopt gating, change the design text

**Proposed decision.** Feature windows count venue open sessions. Lifetime facts
do not narrow the feature axis. The availability synthesis and packet sentences
requiring narrowing for features are amended; the engine stands.

Four arguments, in order of weight:

1. **The amendment supplies a disclosed substitute, so the undisclosed one is no
   longer needed.** This argument did not exist before the amendment. Narrowing
   bridges a gap silently: the returned number carries no indication that its
   window spans a longer calendar interval than its name implies. Carry-forward
   bridges a gap with the count and share of filled inputs attached (amendment
   section 3). Given a choice between two ways to produce a value across a gap,
   the project takes the one that discloses. Narrowing then has no remaining
   job.
2. **The synthesis already forbids this shape of bridging for the other cause.**
   Section 8 states that a whole-feed outage "leaves the declared session pulses
   in place, so an observation before and after the outage can never masquerade
   as a complete adjacent-session window." Narrowing across inactivity is the
   same masquerade with a different cause. Keeping one and forbidding the other
   needs a reason that the accepted text does not give.
3. **It closes the knowledge clock on the numbers.** Narrowing makes the window
   depend on accepted lifetime facts, which carry knowledge times, so the same
   cell yields different numbers depending on when it is requested. Gating makes
   the matrix a function of sealed bars and the venue axis, invariant in `t`.
   That removes v3's trip-wire and section 3.2's mixed-clock problem entirely.
4. **It unifies two axes that are already split.** The valuation clock already
   "counts venue open sessions regardless of that instrument's lifetime"
   (availability synthesis section 7.3). Under gating, features and valuation
   count the same sessions.

**The cost, stated plainly.** A resumed instrument produces no feature value
until a full window of real observations accumulates - about `stable_after`
sessions after resumption, since carry will not bridge the interval either
(section 5.2). Under narrowing it would have produced a value immediately. That
is the price of the proposal and it is accepted deliberately: a value produced
immediately after a multi-month suspension is the value this design most
distrusts.

**What it costs to adopt.** A text change in the availability synthesis, the
v0.2.0.0 packet sentence and `contracts.md:803`. No engine change. Two checks
this document did not run and the repair should: whether gates 21 through 23
assert narrowing anywhere, and whether the certification fixtures encode it.

### 4.3 What is not being claimed

Gating is not claimed to be better research than narrowing. The two are
different declared sampling semantics and the choice is a product decision. What
is claimed is that gating is cheaper to adopt, consistent with the outage rule
already accepted, sufficient once carry-forward exists, and free of the
knowledge-clock consequence.

### 4.4 If narrowing is kept instead

Then the feature axis depends on knowledge-timed facts and the matrix carries a
knowledge clock. The choice would be between numbers on the causal clock beside
evidence at `t` - internally incoherent, with no flag on cells where the two
disagree - and numbers recomputed at `t` so both halves answer one question,
which section 3.1 now permits. The second is the coherent option, at the cost of
recomputation per cutoff and of a history view whose numbers differ from what
`ctx$feature()` returned during the run. That divergence is acceptable only as a
separately identified view, never as a silent replacement. This subsection
records the fork; it does not decide it, because the proposal in 4.2 makes it
unnecessary.

## 5. Missing-data policy

Carried from the amendment and not reopened: preparation distinguishes
price-input carry from indicator-output carry; input treatment precedes
calculation and output treatment follows it; the effective plan discloses which
operations are selected and disabling one never silently enables the other; a
carried source must be the same stable instrument and field or feature at an
earlier effective time, knowable and admissible at `t`; a later observation
never fills an earlier cell even when known at `t`; no leading value is invented
before the first admissible source; closed sessions contribute no padded session
or lookback count and the declared calendar is the authority; missing
observations never infer a closure; raw observations and raw absence are
unchanged; and treatment never creates an observed bar, membership, trading
permission, valuation mark or execution price.

The proposals below settle what the amendment left open.

### 5.1 Price-input carry is on, with a required bounded age

**Proposed default: on, with a required declared maximum carry age, defaulting
to 5 venue open sessions.**

The bound is what makes default-on defensible without first measuring where
gaps concentrate. An isolated missing print is one session; a short feed outage
is a few; a suspension is weeks to months. A small bound therefore fills the
benign, mechanical case and leaves structural absence as `NA` - and structural
absence is the case the project's own prior-art review flags as informative,
since "distress, illiquidity, reporting failures, and delisting can make
absence informative" (prior-art review section 6.1).

The number 5 is a proposal and the weakest-supported item in this document. No
measurement of ledgr's actual gap distribution exists: no local store carries
availability fact families, so the question is not answerable by reading here.
Once an availability-aware ingest exists, the distribution of run lengths of
missing expected sessions, split by whether they sit before the first
observation, inside the active span, inside an accepted inactive interval, or
after the last observation, is the measurement that should set this number. It
is a query, not a spike. The bound's *existence* does not wait on it.

Rejected alternative: unbounded carry. It is the only combination that is both
default-on and unlimited, and it is the one where a single stale price can
propagate through an entire window unnoticed. It also sits against the package's
existing stance, where substituting an old price for a current one requires an
explicit `ledgr_valuation_stale(max_sessions)` policy and "the package supplies
no default stale horizon" (`contracts.md:306-307`), with the availability
synthesis listing "bounded stale valuation with a required declared horizon" as
in scope. Research inputs do not inherit that limit, but they should inherit its
shape.

### 5.2 Carry never crosses an accepted inactive interval

**Proposed default: prohibited, at any age, independently of the age limit.**

Under section 4.2 an inactive instrument's sessions remain on the axis as `NA`.
Without this rule and with carry on, a suspended instrument's sessions would
fill with its last pre-suspension close, and a moving average over that span
would be computed from a fabricated flat series that looks like a real one. The
age limit alone would already prevent most of this; the prohibition makes it
unconditional and independent of whatever number section 5.1 settles on.

This is also the rule that keeps section 4.2's proposal honest: gating does not
become bridging-by-another-name once carry is switched on.

### 5.3 Indicator-output carry is off by default

**Proposed default: off, available on, independently switchable as the
maintainer directed.**

With price-input carry already on, output carry is a second treatment applied to
a result that has already been treated. The two are not interchangeable -
recomputing a moving average on carried prices and carrying the previous moving
average give different values, which the amendment states - and a carried output
is stale in a way a recomputed one is not: it reflects no new information at
all, whereas a value computed from carried inputs at least incorporates whatever
real observations the window does contain.

The combined default is therefore price carry on, output carry off. A consumer
wanting a fully dense feature series enables output carry explicitly and gets
the evidence that says which cells it produced.

### 5.4 Field scope: prices carry per field, volume never carries

**Proposed default: `open`, `high`, `low` and `close` each carry from their own
latest admissible earlier value. `volume` does not carry. No cross-field
synthesis.**

Carrying a close does not define a high, a low or an open, so each field carries
independently or not at all. A bar with a carried close and a missing high is
not a complete bar, and an indicator requiring the high is `NA` there - which
`ledgr_compute_feature_series_strict()` already enforces, since it requires
every value column present in the frame to be finite across the window
(`R/features-engine.R:303-318`, verified).

Volume is excluded because a carried volume is a fabricated liquidity claim, and
volume is the field most likely to be read as evidence about whether a trade
could have happened. An indicator requiring volume across a gap stays `NA`.

### 5.5 Readiness is satisfied on prepared inputs, with no engine threshold

**Proposed default: `stable_after` readiness is evaluated on the prepared
inputs. The engine imposes no maximum carried share.**

A window of three observed and seventeen carried prices satisfies readiness and
returns a value. That is the declared policy producing exactly what it promises,
not a defect, and a mandatory rejection threshold would be an additional product
decision rather than a repair. The carried count and share travel with the value
(section 6), so a consumer that wants to reject such a window can, and the
engine does not decide for it.

What this does change is the meaning of an existing declared concept.
`stable_after` currently promises that many real observations. Under carry it
promises that many prepared inputs. Section 7 writes that into the contract
rather than leaving it to be discovered.

### 5.6 The age clock

**Proposed default: carry age counts venue open sessions between the carried
value's own source time and the delivered column, stated explicitly in the
delivered evidence.**

Repeated carry retains the original source time, so age accumulates and a value
carried for six sessions under a five-session limit is `NA`, not refreshed. The
clock is independent of `ledgr_valuation_stale(max_sessions)`: a valuation limit
is not an implicit research limit and a research limit is not a valuation
permission.

## 6. Missingness information delivered with values

Values alone are insufficient, and disclosure is mandatory rather than
advisory - it is what discharges the availability synthesis's argument that an
observation before and after a gap must never masquerade as a complete window.
Aligned to the same IDs, columns and cutoff, the delivered result must make
available:

- whether the input or output was missing before its treatment, and whether it
  remains missing after;
- whether the delivered value was carried directly, or computed from
  transformed inputs; a finite indicator can depend on carried prices without
  its own output having been carried;
- the carried value's source time and age, with the clock named (section 5.6);
- incomplete initial warm-up distinguished from a later input gap, and existing
  applicable absence or quality reasons where the evidence supports them;
- for finite-window indicators, the count or share of required inputs that were
  carried in that window.

No finite-window denominator is prescribed for future fitted or recursive
methods, and no second indicator series is computed merely to manufacture a
flag. Dependency provenance and output treatment stay separate facts. No
universal "usable" flag may prevent a future consumer from accepting native
`NA`. These are logical requirements; naming, tokens, tables and plane choices
are not decided here.

**Two reuse candidates the representation work should evaluate first.**
`gap_type` and `is_synthetic` already exist on bars and are already delivered to
the strategy context (`R/pulse-context.R:231,247`). Ingest writes `'NONE'` and
`FALSE` unconditionally (`R/snapshot-source.R:116`); availability alignment
writes `MISSING_EXPECTED_SESSION` (`R/backtest-runner.R:886`); nothing anywhere
sets `is_synthetic = TRUE`; and neither field appears in `contracts.md`. So the
delivery channel for per-cell treatment evidence exists end to end and is
currently constant. Reusing it is attractive and is also a semantic change to a
field with no contract coverage, so whichever way it goes, `gap_type`'s
vocabulary ownership becomes a contract item rather than an implementation
detail.

**Representation is a decision, not a consequence.** The prior-art review
supports values-plus-mask as a *model-facing* representation and states
explicitly that this "does not prove dense-plus-mask should be the canonical
storage form" (section 6.2). Model-facing view versus canonical storage is an
open choice for the checkpoint, and section 11 lists it.

## 7. What a padded window means, in contract terms

The replacement wording is a synthesis decision, not a packet task: what a
padded window *means* cannot be settled by the document that implements it.
`contracts.md:803-805` currently reads, in part, that strict feature windows
count expected sessions, that any missing required observation makes the
affected window `NA_real_`, and that valuation marks never enter feature
computation.

**Proposed replacement, to be applied by the eventual packet as written:**

> Feature windows count venue open sessions. Under the strict policy any missing
> required observation makes the affected window `NA_real_`. Under a declared
> carry policy a required input may instead be satisfied by a carried earlier
> value of the same field for the same stable instrument, within the declared
> maximum carry age and within the instrument's active interval, never across an
> accepted `known_inactive` interval and never from a later observation. A
> window satisfied in part by carried inputs is delivered with the count and
> share of carried inputs, and `stable_after` readiness is satisfied on prepared
> inputs rather than on observations. Valuation marks never enter feature
> computation under any policy.

Consequential contract work the packet must also carry, named here rather than
discovered later: the `strict_window` gap contract's commitment to "a finite
window with no internal carry or imputation" (`contracts.md:799-801`) is
unchanged, because carry happens outside the indicator - and the packet must say
so, since indicators whose `series_fn` "carries or imputes internally" remain a
hard validation failure with `ledgr_indicator_gap_unsupported` (availability
synthesis section 8). The same delivered number is therefore a validation
failure by one route and a shipped value by another, and the contract must state
the distinction: carry is permitted only as a declared, ordered, disclosed
preparation step, never as hidden indicator behaviour. Indicator certification,
cache identity and teaching material follow.

## 8. Identity, parity and immutability

- Treatment, ordering, parameters, the carry age limit, the applicable cutoff
  and the implementation version participate in the existing identity and cache
  machinery. Existing feature-cache keys already include snapshot hash,
  instrument, feature fingerprint and feature-engine version
  (`R/feature-cache.R:122-140`, verified) and
  `history_semantics = "expected_sessions_cutoff_causal"` is already an identity
  input to the active fingerprint (`:55`, verified). A strict artifact must not
  satisfy a padded request.
- Under identical policy and information bounds, scalar reads, historical
  windows and training export agree on values and on missingness evidence. This
  does not require a later-cutoff view to equal an earlier-cutoff output.
- A view with a different cutoff or policy is separately identifiable and never
  overwrites an earlier output. Cache immutability is not a prohibition on
  constructing such a view (section 3.1).
- Strict behaviour is preserved wherever inputs and policy are unchanged. Parity
  is required across paths under the same selected policy; padded outputs may
  intentionally differ from strict outputs.

## 9. History estimates, explain audits

`ledgr_run_explain()` joins one retained decision trace to its availability,
execution, valuation, **feature-identity**, position and terminal evidence
(`contracts.md:884-889`), and `diagnostics` returns a typed zero-row schema for
dense runs (`:879-880`). So it returns feature identity, not feature values or
historical windows, and a dense run retains nothing for it to join. It audits
decisions; it does not reconstruct the numbers a strategy computed.

**Decision, on scope.** The first implementation ships no second replay mode: a
per-column-cutoff clock is a second product with its own detectors and its own
preparation. v3's justification - that it would duplicate a shipped surface, and
that its preparation is the expensive one - is withdrawn on both halves
(section 3.3). The exclusion stands on scope alone.

## 10. What remains gated

**(a) Semantic.** Whether the prepared fact families can express, for each
column `s <= t` at one knowledge cutoff `t`, which distinction applies - outside
the applicable point-in-time domain; inside with an accepted observation; inside
without a usable observation; feature unavailable because warm-up is incomplete
- including precedence and supersession, without a second resolver, per-callback
storage queries, or replay of portfolio state. The valuation-policy distinction
is excluded by section 2, not gated.

**(b) Representational.** Whether the two-clock condition can be prepared once
per run. The prepared fact tables collapse both clocks: each segment start is
`pmax(seconds(effective_from), seconds(knowledge_time))`
(`R/availability-provider-prepared.R:102-105`, and `:47-50` for membership
intervals), so a fact effective at `s` but first knowable at `t > s` is reported
inapplicable at `s` - exactly the cell the decision requires. The state at
`(s, t)` is a two-dimensional range condition per instrument and a collapsed
segment table cannot answer it at any price. Both clocks survive upstream in
`ledgr_availability_provider_data()`, so it is feasible; it needs its own
structure.

**(c) Treatment and evidence.** Whether the section 6 requirements - original
missingness, direct carry, transformed-input provenance, carried counts, source
time and age, and the transformed values themselves - can be prepared and
indexed before the fold alongside (a) and (b). Existing prepared doubles alone
do not establish this. Default-on means every research run pays whatever this
costs, so it is answered before the default is fixed, not after.

**The single failure criterion.** Preparation before execution, with bounded
indexed retrieval or incremental cursor advance, is compatible. Reconstructing
instrument-by-boundary segments at any pulse stops this checkpoint. The existing
`ledgr_availability_prepared_cursor()` is the model of the acceptable pattern.

**Memory, as a reading task before a measuring task.** v3's arithmetic put the
retained feature payload at about 95.4 MiB for 500 instruments, 2,500 pulses and
ten features. Section 6's requirements add planes to that, and how many depends
entirely on the representation chosen - a packed encoding and a plane-per-fact
layout differ by several times, so no multiplier is asserted here. What is
asserted is the sequencing: whether the prepared projection is per-process or
shared under parallel sweep is still unanswered, the motivating consumers run as
sweeps, and that question is answerable **by reading the sweep path**. Read it
before choosing a representation and before commissioning any measurement.

Green on all three parts establishes bounded semantic and representational reuse
only: not future-access repair, not training-export parity, not memory
suitability at research scale.

## 11. Decisions this document does not make

- The number in section 5.1, beyond proposing 5 and naming the query that should
  set it.
- Expiry behaviour at the age limit beyond returning `NA`: whether crossing the
  limit emits a distinguishable reason.
- Lifecycle reset boundaries: whether a corporate action or terminal assertion
  resets the carry chain.
- Which indicator outputs are fillable, if output carry is enabled.
- Encoding of the section 6 evidence, including `gap_type` vocabulary ownership
  and model-facing view versus canonical storage.
- Everything the amendment already defers: fitted imputers, their algorithm
  selection, and the fitting boundary, which stay in the 2026-09-26 horizon
  entry and remain model- and adapter-owned.

## 12. Detecting acceptance requirements

An implementation is acceptable only with detectors that fail on:

1. **Simulated-time escape** - evidence or treatment resolved at snapshot-seal
   time or wall-clock now rather than at the simulated decision pulse. This is a
   **construction** check, not a stability check: a seal-time implementation
   returns the same leaked history on every reopen and passes any
   close-and-reopen comparison. It fails when any resolution input is a seal
   timestamp or a wall clock, and it is falsifiable only through item 2.
2. **Future-knowledge admission** - a fact first knowable after `t` appearing in
   any column. The fixture must contain a fact with `effective_from <= s` and
   `knowledge_time > t`, so seal-time and decision-time resolution differ. Items
   1 and 2 are not independent; this fixture is what makes item 1 detect
   anything.
3. **Late-knowledge omission** - a fact effective at `s` and knowable at `t` not
   appearing in column `s`. The decision is bidirectional.
4. **Future-value escape** - a supported accessor returning a value beyond the
   invoking pulse, in dense and availability-aware execution.
5. **Backward carry** - a cell filled from a later observation, in any policy,
   at any age, even when that observation is knowable at `t`.
6. **Inactive-interval carry** - a carried value crossing an accepted
   `known_inactive` interval (section 5.2), and a carried value exceeding the
   declared age limit (section 5.1).
7. **Silent treatment** - a delivered value whose carried status, carried count
   or source age is absent or wrong; a disabled operation taking effect; or
   enabling one of the two operations enabling the other. No treatment is
   inferred from `NA`.
8. **Strict/padded confusion** - a strict artifact satisfying a padded request
   or the reverse; and strict outputs changing where inputs and policy are
   unchanged.
9. **Retained-result mutation** - mutating a returned window altering engine
   storage, another consumer, or a later result; or a retained result losing its
   axis, cutoff or policy when the fold advances.
10. **Axis alignment** - row order disagreeing with the contract-defined
    decision axis including held-nonmember placement, or a `0 x L` empty-axis
    result failing.
11. **Claimed-distinction collapse** - for whatever distinctions the companion
    claims to express, a detector fails when two become indistinguishable, and
    any distinction it does not claim fails explicitly rather than returning a
    plausible value.
12. **Current-value parity** - scalar, plane and bundle reads disagreeing with
    the pre-change run at any pulse under unchanged policy.
13. **Inspection preservation** - the interactive reader failing when the long
    table is empty.

No member-count, timing or memory threshold is an acceptance gate.

## 13. Next action

Accept, or revise the section 1 table. On acceptance:

1. Amend the narrowing text per section 4.2 - availability synthesis, v0.2.0.0
   packet sentence and `contracts.md:803` - and run the two checks named there.
   This is a current-release text repair and it is a prerequisite for section
   10, because what counts as a session determines where carry is possible.
2. Read the sweep path and answer whether the prepared projection is per-process
   or shared.
3. Run the section 10 checkpoint, all three parts, against the single failure
   criterion.
4. Run the section 5.1 gap-distribution query once an availability-aware ingest
   exists, to set the age limit's number.

Only then consider a spec cut. No comparative spike is chartered and no spec
packet is written here. LDG-2864 and LDG-2850 proceed independently.

## 14. Revision history

- 2026-09-26: v4. Supersedes v3 and incorporates the missingness amendment.
  Repairs v3's four accepted findings; proposes gating as the feature session
  axis with the amendment's disclosure as the argument that makes narrowing
  unnecessary; proposes seven concrete missing-data defaults with their
  consequences; drafts the replacement contract wording; adds a treatment-and-
  evidence part to the checkpoint and reduces the whole checkpoint to one
  failure criterion; withdraws v3's cost arguments in both places they appeared.
- 2026-09-26: v3. Superseded. Made the matrix claim contingent and named the
  representational gap; carried four findings its reviewer accepted and it did
  not repair.
- 2026-09-26: v2. Superseded. Recorded the maintainer's knowledge-clock
  decision.
