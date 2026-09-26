# RFC Synthesis v5: Point-in-Time Historical Projection With Missing-Data Policy

**Status:** Decision synthesis, superseding
[synthesis v4](rfc_point_in_time_historical_projection_v0_2_x_synthesis_v4.md),
which required revision. Incorporates the
[maintainer missingness amendment](rfc_point_in_time_historical_projection_v0_2_x_missingness_amendment.md).
Decisions bind on maintainer acceptance.
**Date:** 2026-09-26
**Author:** Claude, per role rotation.
**Baselines:** design `491c4ed`; implementation `ae040e7`. Claims are marked
verified by reading, verified by execution, or open.

**What changed from v4.** v4 proposed a workable policy and attached a false
architectural claim to it: that fixing the feature session axis removes the
knowledge clock from the numbers. It does not, and v4's own carry rules are why
(section 5.2). Section 6 is new and replaces that claim with a precise statement
of where values can change with the request cutoff, which turns out to be a
single identifiable channel. Three further v4 claims cited implementation that
does not support them. Section 3.2 records each correction.

**What is not reopened.** The maintainer's product direction stands: the ML
release ships simple carry-forward plus missingness information for prices and
indicators, price padding is intended on by default with an off switch, and
indicator-output carry is available independently. The settled simulated
decision-time knowledge bound stands. Section 1 is the reviewable object.

---

## 1. The proposed policy, in one table

Every row is a proposal for maintainer acceptance.

| Question | Proposed default | Consequence if accepted |
| --- | --- | --- |
| Which sessions a feature window counts | Venue open sessions. Lifetime facts do not narrow the feature axis. | Features share one axis with valuation, and only one thing in the pipeline depends on knowledge rather than two. Requires amending four authorities including an executable gate (section 4). |
| Observations inside an accepted inactive interval | **Always admissible.** Inactivity prohibits carry; it does not exclude a real observation. | A genuine print during an asserted inactive period is used, as it is today. Narrowing would have discarded it (section 4.4). |
| Price-input carry | **On**, bounded by a required declared maximum carry age, default **5 venue open sessions**. | Bounds how stale a filled input can be. It does not by itself separate benign gaps from structural absence, and section 5.1 states what it does and does not guarantee. |
| Carry across an accepted `known_inactive` interval | **Never**, at any age. | A suspension is never bridged by fabricated prices. This rule is also the one channel that makes padded values depend on the request cutoff, accepted deliberately (section 6). |
| Indicator-output carry | **Off** by default, available on. | Avoids compounding two treatments by default. Enabling it does not produce a dense series: warm-up, expiry and inactivity still leave holes (section 5.3). |
| Which fields carry | `open`, `high`, `low`, `close`, each from its own latest admissible earlier value. **`volume` never carries.** | Requires a required-input admission rule the engine does not have today; today's window gate over-blocks and under-blocks (section 5.4). |
| Readiness under carry | `stable_after` is satisfied on prepared inputs. No engine threshold on carried share. | After a gap or a resumption a *prepared* window suffices, not a window of real observations. "Ready" changes meaning and the contract must say so (sections 5.5 and 7). |
| Age clock | Venue open sessions from the carried value's own source time, stated explicitly. | Independent of `ledgr_valuation_stale(max_sessions)`; repeated carry does not refresh age (section 5.6). |
| Values under a carry policy | Knowledge-dependent by construction. The padded view is separately identified and computed at the request cutoff. | The strict policy remains the only cutoff-invariant one. Revisions are bounded and identifiable, not a per-pulse rebuild (section 6). |

Two rows carry the safety: the age limit and the inactive-interval prohibition.
One row carries the architecture: the last.

## 2. Settled and carried forward unchanged

- **The knowledge clock.** A history request at simulated decision pulse `t`
  returns, for each historical column `s <= t`, the value and evidence knowable
  at `t`: knowledge clock fixed at `t`, effective clock varying with the column.
  `t` is the simulated decision pulse, never snapshot-seal time and never
  wall-clock now.
- **The column clock.** Columns are consecutive prepared decision pulses ending
  at the invoking pulse, never the last `L` non-missing observations per asset,
  because a per-asset clock gives different assets different time axes in one
  matrix and silently destroys any cross-sectional estimate built from it.
  Leading padding uses `NA_real_`; pre-range history is never silently fetched.
- **Evidence semantics.** A fact effective at `s` but first knowable after `t`
  does not appear; a fact effective at `s` and knowable at `t` appears in column
  `s` even if it was not knowable at `s`. Membership and observation stay
  independent. Historical `held`, `priced`, `mark_age` and `tradable()` state is
  not replayed (`contracts.md:401-405`).
- **Separately identified views.** A view at a different cutoff or policy is
  separately identifiable and never overwrites an earlier output. "History
  admission is recomputed as of each use cutoff; later-known history cannot
  retrospectively alter cached earlier outputs" (v0.2.0.0 spec section 3.5,
  verified). Cache immutability is not a prohibition on constructing a new view.
- **Ownership and shape.** The projection is the single owner and the
  lower-projector direction stays closed (verified by execution). Direction 5.4
  is preserved including its `ctx$window()` spelling. The row axis follows
  `contracts.md:348-352`. The access boundary follows the maintainer correction
  of 2026-09-26, owned by LDG-2864 and LDG-2850.
- **One causal world.** No second execution engine and no second execution path.
  History serves estimation; `ledgr_run_explain()` serves audit; no second
  replay mode ships (section 9).
- **Carried from the amendment.** Preparation distinguishes price-input carry
  from indicator-output carry; input treatment precedes calculation and output
  treatment follows it; the effective plan discloses which operations are
  selected and disabling one never silently enables the other; a carried source
  is the same stable instrument and field or feature at an earlier effective
  time, knowable and admissible at `t`; a later observation never fills an
  earlier cell even when known at `t`; no leading value is invented before the
  first admissible source; closed sessions contribute no padded session or
  lookback count and the declared calendar is the authority; missing
  observations never infer a closure; raw observations and raw absence are
  unchanged; treatment never creates an observed bar, membership, trading
  permission, valuation mark or execution price.

## 3. Repairs

### 3.1 From synthesis v3, settled in v4 and not reopened

The blanket prohibition on recomputing at a later cutoff is withdrawn against
the packet sentence quoted in section 2. The mixed-clock section that the
prohibition forced is gone. The claimed `L`-to-one preparation saving is
withdrawn and reversed: the rejected per-column view walks the existing
prepared cursor with vectorised advance and no rebuild
(`R/availability-provider-prepared.R:133-162`, verified), so the rejected clock
needs no new preparation and the chosen one does; the chosen clock stands on
semantics alone, and the same argument is withdrawn where v3 applied it to the
excluded replay mode. The checkpoint's three inconsistent failure criteria
became one line, restated in section 10.

### 3.2 From synthesis v4

**Invariance withdrawn.** v4 sections 1, 3.2, 4.2 and 4.4 claimed that fixing
the session axis removes the knowledge clock from the numbers. It does not. Take
a two-session average: Monday observed at 100, Tuesday missing, Wednesday
observed at 102, and on Thursday an assertion becomes knowable that Tuesday was
inactive. A request at Wednesday cannot know that, so carry fills Tuesday with
100 and the average is 101. A request at Thursday for the same historical column
must refuse that carry under section 5.2 and return `NA`. The axis never moved;
carry eligibility moved with knowledge, so the value moved. This follows
directly from the settled request-time clock plus v4's own inactive-interval
prohibition, so the prohibition is not the thing to remove - the claim is.
Section 6 replaces it.

**"Inactive sessions remain `NA`" corrected.** v4 sections 4.2 and 5.2 asserted
this as existing behaviour. Feature hydration creates an NA-filled
venue-aligned frame and then copies in whatever observations exist, with no
lifetime masking (`R/backtest-runner.R:881-894`, verified), and observation
acceptance checks instrument, timestamp, OHLC finiteness and volume finiteness
with no inactivity rejection (`R/availability-ingest.R:120-135`, verified). A
real print inside an accepted inactive interval is therefore ingested and used
today. Whether inactivity *excludes observations* or *only prohibits carry* is a
policy question v4 conflated; section 4.4 decides it.

**The age limit's guarantee restated.** v4 section 5.1 claimed that a bounded
age keeps structural absence `NA`. It does not: without an already-knowable
inactivity fact, the first five missing sessions of a long suspension still
fill, and a short gap can itself be informative. The bound limits staleness;
that is all it does. v4 also proposed 5 in section 1 while sections 11 and 13
left the number undecided. Section 5.1 now states it as the shipping default
with the measurement as a tuning input, and section 11 no longer lists it as
open.

**The field-scope citation corrected.** v4 section 5.4 cited
`R/features-engine.R:303-318` as enforcing its promise. That code takes
`value_columns <- intersect(c("open","high","low","close"), names(bars_df))` and
requires every one present in the frame to be finite across the window (`:307`,
verified). It never consults what the indicator requires and it never looks at
volume. So it over-blocks a close-only indicator on a missing high and
under-blocks a volume-dependent indicator on missing volume. Section 5.4 now
names the rule that is needed rather than claiming it exists.

**Three smaller corrections.** After a gap or a resumption, readiness requires a
complete *prepared* window, not a window of real observations, because section
5.5 permits padding; v4 section 4.2 said otherwise. Carry cannot substitute for
narrowing *across inactivity*, because section 5.2 forbids exactly that carry,
so v4's lead argument for gating fails and section 4.3 no longer makes it. And
enabling output carry cannot promise a dense series; section 5.3 says what it
does promise.

## 4. The feature session axis

### 4.1 The divergence, with all four authorities

Binding text and implementation disagree about values, not coverage:

- the availability synthesis: an instrument's expected sessions, "which drive
  feature windows and observation classification, are the venue open sessions
  minus those inside an accepted `known_inactive` lifetime interval";
- `contracts.md:803`: "Strict feature windows count expected sessions";
- the v0.2.0.0 packet: "instrument expected sessions exclude known inactivity
  for features";
- **availability synthesis gate 21** (line 942, verified): with `known_inactive`
  effective, "those sessions leave the feature and classification expected set."

The implementation does not narrow. Hydration builds one frame per instrument on
the venue pulse axis and **fails the run** if any per-instrument axis differs
(`R/backtest-runner.R:873-907`, gate at `:904-905`), so per-instrument axes are
prohibited by that path rather than merely absent.
`ledgr_compute_feature_series_strict()` rolls `width` consecutive rows and skips
to `NA` on any non-finite value in the window (`R/features-engine.R:286-320`).
`known_inactive` reaches only trading restriction
(`R/availability-provider.R:195-203`) and terminal handling
(`R/fold-engine.R:505`).

### 4.2 Proposal: adopt gating, amend the four authorities

**Proposed decision.** Feature windows count venue open sessions. Lifetime facts
do not narrow the feature axis. The four authorities above are amended,
including gate 21. The engine stands.

### 4.3 The argument, on what survives

Two of v4's four arguments are withdrawn. Gating does **not** make the numbers
cutoff-invariant under the proposed carry policy (section 3.2), and carry does
**not** provide a disclosed substitute for bridging inactivity, because section
5.2 forbids that carry. What remains:

1. **One knowledge-dependent channel instead of two.** Under gating, exactly one
   thing depends on when you ask: whether carry is permitted in a cell asserted
   inactive (section 6). Under narrowing, window *composition* depends on it as
   well, and the two interact - a later-known interval both removes sessions and
   forbids carry in them, so a single fact changes the window's membership and
   its fill eligibility at once. One channel is bounded and detectable; two
   interacting channels are considerably harder to prepare, detect or explain.
2. **Narrowing discards real observations.** Per section 3.2 a genuine print
   inside an asserted inactive interval exists today and is used. Narrowing
   removes that session from the axis, so the print is dropped. That sits badly
   against observations being immutable and never synthesized, and against
   pre-membership observations being allowed to contribute when admissible.
3. **Consistency with the outage rule already accepted.** The availability
   synthesis states that a whole-feed outage "leaves the declared session pulses
   in place, so an observation before and after the outage can never masquerade
   as a complete adjacent-session window." Narrowing across inactivity is the
   same masquerade with a different cause.
4. **One axis shared with valuation.** The valuation clock already "counts venue
   open sessions regardless of that instrument's lifetime" (availability
   synthesis section 7.3).

**The cost, stated plainly.** Four authorities change, one of them an executable
gate, and certification fixtures may encode narrowing - a check this document
did not run. That is more than v4's "text-only repair" implied. Against it: the
alternative requires an engine change to a path that currently fails the run on
per-instrument axes, plus the second knowledge channel in argument 1.

Gating is not claimed to be better research than narrowing. The two are
different declared sampling semantics and the choice is a product decision.

### 4.4 Observations are always admissible; only carry is restricted

**Proposed decision, settling the policy question section 3.2 identified.** An
observation is admissible wherever it exists, including inside an accepted
`known_inactive` interval. Inactivity prohibits *carry* into such a cell; it
never removes a real print.

Real data is always usable; fabricated data is never fabricated across a period
asserted not to have traded. This preserves today's ingest and hydration
behaviour, keeps observations immutable in fact as well as in wording, and
leaves inactivity affecting exactly one thing in the research path.

Note what it does not touch: inactivity continues to restrict targets at
decision and block fills at execution with `lifetime_inactive`
(`R/availability-provider.R:195-203`), and the valuation clock continues to age
held marks through inactivity. A usable research input is not a trading
permission.

### 4.5 If narrowing is kept instead

Then window composition and carry eligibility both depend on knowledge, and both
must be prepared, detected and explained together. The matrix is
knowledge-dependent either way (section 6), so the choice is not between a clean
and a dirty option but between one channel and two. Section 6's bounding
argument applies to the carry channel only; the composition channel would need
its own.

## 5. Missing-data policy

### 5.1 Price-input carry is on, with a required bounded age

**Proposed default: on, with a required declared maximum carry age, defaulting
to 5 venue open sessions.**

**What the bound guarantees:** no delivered input is more than the declared
number of venue open sessions old, counted from its own source time. That is the
whole guarantee.

**What it does not guarantee.** It does not separate benign gaps from structural
absence. Where no inactivity fact is yet knowable, the first sessions of a long
suspension fill exactly like an isolated missing print, and only the age bound
eventually stops them. A short gap can itself be informative. The
inactive-interval prohibition (section 5.2) is what addresses structural
absence, and it only applies once the asserting fact is knowable.

The number 5 is proposed as the shipping default and is the weakest-supported
item in this document. It is chosen because an isolated missing print is one
session, a short feed outage is a few, and a suspension is weeks to months, so a
small bound fills the mechanical case and expires before the structural one -
which matters because the project's own prior-art review notes that "distress,
illiquidity, reporting failures, and delisting can make absence informative"
(section 6.1). No measurement supports the specific number: no local store
carries availability fact families, so it is not answerable by reading here. The
measurement that should set it is the distribution of run lengths of missing
expected sessions, split by whether they sit before the first observation,
inside the active span, inside an accepted inactive interval, or after the last
observation. That is a query, not a spike, and it tunes the number rather than
gating the release.

Rejected alternative: unbounded carry. Default-on and unlimited is the one
combination where a single stale price can propagate through a whole window with
nothing to stop it, and it sits against the package's existing stance, where
substituting an old price requires an explicit
`ledgr_valuation_stale(max_sessions)` policy and "the package supplies no
default stale horizon" (`contracts.md:306-307`). Research inputs do not inherit
that limit, but they should inherit its shape.

### 5.2 Carry never crosses an accepted inactive interval

**Proposed default: prohibited, at any age, independently of the age limit.**

Without it, and with carry on, a suspended instrument's sessions would fill from
its last pre-suspension close and an average over that span would be computed
from a fabricated flat series that reads like a real one. The age limit alone
would stop most of this; the prohibition makes it unconditional.

This rule is also the source of the cutoff dependence in section 6, because
whether it applies to a given cell depends on whether the asserting fact is
knowable at the request cutoff. That consequence is accepted rather than
avoided: the alternative is to keep filling cells the data owner has said did
not trade.

### 5.3 Indicator-output carry is off by default

**Proposed default: off, available on, independently switchable.**

With price-input carry already on, output carry treats a result that has already
been treated. The two are not interchangeable - recomputing a moving average on
carried prices and carrying the previous moving average give different values -
and a carried output reflects no new information at all, whereas a value
computed from carried inputs incorporates whatever real observations its window
contains.

**What enabling it does not promise.** Not a dense series. Leading warm-up
before the first admissible source, expiry at the age limit, and inactivity all
still leave `NA`. It fills holes where a previous valid output exists and is
within age and outside an inactive interval, and nowhere else.

### 5.4 Field scope, and the admission rule it requires

**Proposed default: `open`, `high`, `low` and `close` each carry from their own
latest admissible earlier value. `volume` does not carry. No cross-field
synthesis.**

Carrying a close does not define a high, a low or an open, so each field carries
independently or not at all. Volume is excluded because a carried volume is a
fabricated liquidity claim and volume is the field most likely to be read as
evidence that a trade could have happened.

**The rule this needs, which does not exist today.** Today's window gate checks
every OHLC column present in the frame and ignores volume
(`R/features-engine.R:307`, verified). It therefore over-blocks - a close-only
indicator returns `NA` because an unrelated high is missing - and under-blocks -
a volume-dependent indicator is not stopped by missing volume, and whether it
returns `NA` depends on its own callback.

So this section's promise requires an indicator to **declare its required input
fields**, the window gate to test exactly those fields, and certification to
verify that a declared-field indicator returns `NA` when and only when one of
its declared fields is unavailable. Without that rule, "volume never carries"
does not imply "volume-dependent indicators are `NA` across gaps". Naming the
rule is a synthesis decision; its shape - a declaration on the indicator
definition alongside `gap_contract`, or inference from the callback - is not
decided here.

### 5.5 Readiness is satisfied on prepared inputs, with no engine threshold

**Proposed default: `stable_after` readiness is evaluated on the prepared
inputs. The engine imposes no maximum carried share.**

A window of three observed and seventeen carried prices satisfies readiness and
returns a value. That is the declared policy producing what it promises, not a
defect, and a mandatory rejection threshold would be an additional product
decision rather than a repair. The carried count and share travel with the value
(section 8), so a consumer that wants to reject such a window can.

Two consequences to state rather than discover. `stable_after` currently
promises that many real observations and under carry it promises that many
prepared inputs; section 7 writes that into the contract. And after a gap or a
resumption a prepared window suffices, so a value appears as soon as carry can
complete the window - not after a full window of real observations. Under
section 5.2 that does not apply across an accepted inactive interval, where the
wait is for real observations.

### 5.6 The age clock

**Proposed default: carry age counts venue open sessions between the carried
value's own source time and the delivered column, stated explicitly in the
delivered evidence.**

Repeated carry retains the original source time, so age accumulates and a value
carried for six sessions under a five-session limit is `NA`, not refreshed. The
clock is independent of `ledgr_valuation_stale(max_sessions)`: a valuation limit
is not an implicit research limit and a research limit is not a valuation
permission.

## 6. Values under a carry policy depend on the request cutoff

This section replaces v4's invariance claim.

### 6.1 The statement

Under the strict policy with the section 4.2 axis, a feature value is a function
of sealed bars and the venue axis, and does not change with the request cutoff
`t`. **Under a carry policy it does**, because section 5.2 conditions carry on
facts that carry knowledge times.

The dependence is not diffuse. With the axis fixed and observations always
admissible (section 4.4), bar presence does not vary with `t`, and age counts
sessions on a fixed axis so it does not vary with `t` either. Exactly one input
varies: whether an interval is *accepted as inactive* at `t`.

So the set of cells whose value can differ between cutoffs `t1 < t2` is exactly:

> the columns whose window contains a carried cell falling inside an interval
> asserted `known_inactive` by a fact whose `knowledge_time` lies in
> `(t1, t2]`.

Everything else is identical between the two views. This is a bounded,
enumerable set derived from the lifetime facts' knowledge times, not a general
statement that history may change.

### 6.2 What follows for preparation

Revision does not require rebuilding anything at every pulse. It requires that
preparation be *invalidatable over an identifiable range*: when a lifetime fact
becomes knowable, the affected instrument and its affected column range are
derivable from that fact's asserted interval and the carry age limit, which
bounds how far forward a carried value from inside the interval can reach. That
is an indexed invalidation, and section 10's failure criterion still holds: a
per-pulse reconstruction of instrument-by-boundary segments stops the
checkpoint, while bounded indexed retrieval and incremental update do not.

Whether that invalidation can be prepared once per run is now an explicit
checkpoint part (section 10(d)). This document does not assert that it can.

### 6.3 What follows for identity and delivery

- The padded view is a separately identified artifact whose identity includes
  the policy, its parameters including the age limit, and the request cutoff. A
  padded view at a later cutoff may legitimately differ from one at an earlier
  cutoff, and neither overwrites the other.
- The strict artifact remains cutoff-invariant and can be reused across
  cutoffs. A strict artifact must not satisfy a padded request, and the reverse.
- A padded value therefore cannot reuse the run's cached strict feature values
  as though they were the same artifact. The identity rules in section 8 already
  required this; v4's invariance narrative obscured why.
- Because the default is carry-on, the default research path produces a
  cutoff-dependent matrix. The strict policy remains available and is the only
  cutoff-invariant one. This is a cost of the default rather than an argument
  against it.

## 7. What a padded window means, in contract terms

The replacement wording is a synthesis decision: what a padded window means
cannot be settled by the document that implements it. `contracts.md:803-805`
currently states that strict feature windows count expected sessions, that any
missing required observation makes the affected window `NA_real_`, and that
valuation marks never enter feature computation.

**Proposed replacement, to be applied by the eventual packet as written:**

> Feature windows count venue open sessions. An observation is admissible
> wherever it exists, including inside an accepted `known_inactive` interval. An
> indicator declares the input fields it requires, and a window is unavailable
> when and only when one of those declared fields is unavailable in it. Under
> the strict policy any missing required input makes the affected window
> `NA_real_`. Under a declared carry policy a required input may instead be
> satisfied by a carried earlier value of the same field for the same stable
> instrument, within the declared maximum carry age and never across an accepted
> `known_inactive` interval, never from a later observation, and never for
> `volume`. A window satisfied in part by carried inputs is delivered with the
> count and share of carried inputs, and `stable_after` readiness is satisfied
> on prepared inputs rather than on observations. Values delivered under a carry
> policy depend on the request cutoff through the inactivity condition only;
> such a view is separately identified and never overwrites an earlier output.
> Valuation marks never enter feature computation under any policy.

Consequential contract work the packet must also carry, named here rather than
discovered later. The `strict_window` gap contract's commitment to "a finite
window with no internal carry or imputation" (`contracts.md:799-801`) is
unchanged, because carry happens outside the indicator - and the packet must say
so, because indicators whose `series_fn` "carries or imputes internally" remain
a hard validation failure with `ledgr_indicator_gap_unsupported` (availability
synthesis section 8). The same delivered number is therefore a validation
failure by one route and a shipped value by another, and the contract must state
the distinction: carry is permitted only as a declared, ordered, disclosed
preparation step, never as hidden indicator behaviour. Gate 21, indicator
certification including the new required-field rule, cache identity and teaching
material follow.

## 8. Missingness information delivered with values

Disclosure is mandatory, not advisory: it is what discharges the availability
synthesis's argument that an observation before and after a gap must never
masquerade as a complete window. Aligned to the same IDs, columns and cutoff,
the delivered result must make available:

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

**Identity and parity.** Treatment, ordering, parameters, the carry age limit,
the applicable cutoff and the implementation version participate in the existing
identity and cache machinery. Existing feature-cache keys already include
snapshot hash, instrument, feature fingerprint and feature-engine version
(`R/feature-cache.R:122-140`, verified), and
`history_semantics = "expected_sessions_cutoff_causal"` is already an identity
input to the active fingerprint (`:55`, verified). Under identical policy and
information bounds, scalar reads, historical windows and training export agree
on values and on missingness evidence. Strict behaviour is preserved wherever
inputs and policy are unchanged; padded outputs may intentionally differ from
strict outputs.

**Two reuse candidates the representation work should evaluate first.**
`gap_type` and `is_synthetic` already exist on bars and already reach the
strategy context (`R/pulse-context.R:231,247`). Ingest writes `'NONE'` and
`FALSE` unconditionally (`R/snapshot-source.R:116`), availability alignment
writes `MISSING_EXPECTED_SESSION` (`R/backtest-runner.R:886`), nothing sets
`is_synthetic = TRUE`, and neither field appears in `contracts.md`. The delivery
channel for per-cell treatment evidence therefore exists end to end and is
currently constant. Reusing it is attractive and is also a semantic change to a
field with no contract coverage, so `gap_type`'s vocabulary ownership becomes a
contract item either way.

**Representation is a decision, not a consequence.** The prior-art review
supports values-plus-mask as a *model-facing* representation and states that
this "does not prove dense-plus-mask should be the canonical storage form"
(section 6.2). Model-facing view versus canonical storage is an open choice
(section 11).

## 9. History estimates, explain audits

`ledgr_run_explain()` joins one retained decision trace to its availability,
execution, valuation, **feature-identity**, position and terminal evidence
(`contracts.md:884-889`), and `diagnostics` returns a typed zero-row schema for
dense runs (`:879-880`). It returns feature identity, not feature values or
historical windows, and a dense run retains nothing for it to join.

**Decision, on scope.** The first implementation ships no second replay mode: a
per-column-cutoff clock is a second product with its own detectors and
preparation. v3's justification - duplication of a shipped surface, and cost -
is withdrawn on both halves (section 3.1). The exclusion stands on scope alone.

## 10. What remains gated

**(a) Semantic.** Whether the prepared fact families can express, for each
column `s <= t` at one knowledge cutoff `t`, which distinction applies - outside
the applicable point-in-time domain; inside with an accepted observation; inside
without a usable observation; feature unavailable because warm-up is incomplete
- including precedence and supersession, without a second resolver,
per-callback storage queries, or replay of portfolio state.

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

**(c) Treatment and evidence.** Whether the section 8 requirements - original
missingness, direct carry, transformed-input provenance, carried counts, source
time and age, and the transformed values themselves - can be prepared and
indexed before the fold alongside (a) and (b). Existing prepared doubles alone
do not establish this. Default-on means every research run pays whatever this
costs, so it is answered before the default is fixed.

**(d) Numerical revision, new in v5.** Whether the bounded invalidation of
section 6.2 can be prepared once per run: given a lifetime fact's knowledge
time, asserted interval and the declared carry age limit, can the affected
instrument and column range be derived and its prepared values invalidated by
index, without reconstructing segments at a pulse. This part exists because
values are knowledge-dependent under the proposed policy and v4 wrongly claimed
they were not.

**The single failure criterion.** Preparation before execution, with bounded
indexed retrieval or incremental cursor advance, is compatible. Reconstructing
instrument-by-boundary segments at any pulse stops this checkpoint. The existing
`ledgr_availability_prepared_cursor()` is the model of the acceptable pattern.

**Memory: the sweep question is answered, and the answer is worker-local
copies.** `runtime_projection` is placed in each candidate task
(`R/sweep.R:1068`) and the task is handed to `mirai(..., task = task)`
(`:1285`), which serializes it per worker. There is no shared projection store,
so parallel sweeps replicate the projection per process. Peak memory remains
unmeasured, and no multiplier is asserted for section 8's evidence because it
depends entirely on a representation not yet chosen. What follows is the
sequencing: a representation must be chosen with per-worker replication assumed,
and the motivating consumers are sweeps.

Green on all four parts establishes bounded semantic, representational and
revision reuse only: not future-access repair, not training-export parity, not
memory suitability at research scale.

## 11. Decisions this document does not make

- Expiry behaviour at the age limit beyond returning `NA`: whether crossing the
  limit emits a distinguishable reason.
- Lifecycle reset boundaries: whether a corporate action or terminal assertion
  resets the carry chain.
- The shape of the required-input declaration in section 5.4: a field on the
  indicator definition beside `gap_contract`, or inference from the callback.
- Which indicator outputs are fillable, if output carry is enabled.
- Encoding of the section 8 evidence, including `gap_type` vocabulary ownership
  and model-facing view versus canonical storage.
- Everything the amendment defers: fitted imputers, their algorithm selection
  and the fitting boundary, which stay in the 2026-09-26 horizon entry and
  remain model- and adapter-owned.

Not on this list any more: the age limit's number, which section 5.1 proposes as
a shipping default with a named tuning measurement.

## 12. Detecting acceptance requirements

An implementation is acceptable only with detectors that fail on:

1. **Simulated-time escape** - evidence or treatment resolved at snapshot-seal
   time or wall-clock now rather than at the simulated decision pulse. This is
   a **construction** check, not a stability check: a seal-time implementation
   returns the same leaked history on every reopen and passes any
   close-and-reopen comparison. It fails when any resolution input is a seal
   timestamp or a wall clock, and it is falsifiable only through item 2.
2. **Future-knowledge admission** - a fact first knowable after `t` appearing in
   any column. The fixture must contain a fact with `effective_from <= s` and
   `knowledge_time > t`, so seal-time and decision-time resolution differ.
   Items 1 and 2 are not independent; this fixture is what makes item 1 detect
   anything.
3. **Late-knowledge omission** - a fact effective at `s` and knowable at `t` not
   appearing in column `s`. The decision is bidirectional.
4. **Revision correctness** - a carried cell inside an interval asserted
   inactive by a fact knowable at `t` still carrying; and, in the other
   direction, a cell losing its carry because of a fact *not* knowable at `t`.
   Both halves are required, and section 6.1's enumerated set is the fixture's
   basis.
5. **Revision boundedness** - a value differing between two cutoffs outside
   section 6.1's set, which would mean the dependence is not confined to the
   inactivity condition.
6. **Future-value escape** - a supported accessor returning a value beyond the
   invoking pulse, in dense and availability-aware execution.
7. **Backward carry** - a cell filled from a later observation, in any policy,
   at any age, even when that observation is knowable at `t`.
8. **Age and interval violation** - a carried value exceeding the declared age
   limit, or crossing an accepted inactive interval.
9. **Observation suppression** - a real observation inside an accepted inactive
   interval being dropped rather than delivered (section 4.4).
10. **Required-field admission** - a window returning a value when a declared
    required field is unavailable, or returning `NA` because an undeclared
    field is unavailable (section 5.4).
11. **Silent treatment** - a delivered value whose carried status, carried count
    or source age is absent or wrong; a disabled operation taking effect; or
    enabling one operation enabling the other. No treatment is inferred from
    `NA`.
12. **Strict/padded confusion** - a strict artifact satisfying a padded request
    or the reverse; and strict outputs changing where inputs and policy are
    unchanged.
13. **Retained-result mutation** - mutating a returned window altering engine
    storage, another consumer, or a later result; or a retained result losing
    its axis, cutoff or policy when the fold advances.
14. **Axis alignment** - row order disagreeing with the contract-defined
    decision axis including held-nonmember placement, or a `0 x L` empty-axis
    result failing.
15. **Claimed-distinction collapse** - for whatever distinctions the companion
    claims to express, a detector fails when two become indistinguishable, and
    any distinction it does not claim fails explicitly rather than returning a
    plausible value.
16. **Current-value parity** - scalar, plane and bundle reads disagreeing with
    the pre-change run at any pulse under unchanged policy.
17. **Inspection preservation** - the interactive reader failing when the long
    table is empty.

No member-count, timing or memory threshold is an acceptance gate.

## 13. Next action

Accept, or revise the section 1 table. On acceptance:

1. Give the session-axis repair an **owning ticket in the current release**. It
   amends four authorities including gate 21, and it must check whether
   certification fixtures encode narrowing. It is a prerequisite for section 10,
   because what counts as a session determines where carry is possible.
2. Run the section 10 checkpoint, all four parts, against the single failure
   criterion. Part (d) is new and part (c) must be answered before the carry
   default is fixed.
3. Choose the section 8 representation with per-worker replication assumed
   (section 10), then measure rather than measuring first.
4. Run the section 5.1 gap-distribution query once an availability-aware ingest
   exists, to tune the age limit.

Only then consider a spec cut. No comparative spike is chartered and no spec
packet is written here. LDG-2864 and LDG-2850 proceed independently.

## 14. Revision history

- 2026-09-26: v5. Supersedes v4. Withdraws v4's claim that a fixed session axis
  removes the knowledge clock from the numbers, and replaces it with section 6:
  values under a carry policy depend on the request cutoff through the
  inactivity condition only, which bounds the affected set and makes revision an
  indexed invalidation rather than a rebuild. Restates the gating argument on
  its two surviving grounds plus two new ones and names its true adoption cost
  including gate 21. Decides that observations inside an accepted inactive
  interval stay admissible. Corrects the age limit's guarantee, the field-scope
  citation, and the readiness, substitution and density statements. Adds
  checkpoint part (d) and four detectors. Records the sweep answer: worker-local
  replication, confirmed by reading.
- 2026-09-26: v4. Superseded. Proposed the missing-data defaults and repaired
  v3's four findings; attached a false invariance claim to the axis proposal.
- 2026-09-26: v3. Superseded. Made the matrix claim contingent and named the
  representational gap.
- 2026-09-26: v2. Superseded. Recorded the maintainer's knowledge-clock
  decision.
