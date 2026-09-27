# RFC Synthesis v10: Point-in-Time Historical Projection With Missing Data

**Status: ACCEPTED by the maintainer 2026-09-27.** The section 1 policy table is
accepted as written. The section 4 session-axis proposal is accepted with a
direction: the documentation reports the engine's current behaviour, and
reaching the stated design goal of instrument-narrowed expected sessions is
scheduled for the next release, in `../ledgr_roadmap.md` with the reasoning kept
in `../horizon.md` (2026-09-27, both `[data]` entries). Acceptance settles
semantics; it authorizes no implementation, spec packet or spike.

**Status (drafting):** Decision synthesis, superseding
[synthesis v9](rfc_point_in_time_historical_projection_v0_2_x_synthesis_v9.md),
which placed a barrier wrongly. Incorporates the
[maintainer missingness amendment](rfc_point_in_time_historical_projection_v0_2_x_missingness_amendment.md).
**Date:** 2026-09-26
**Author:** Claude, per role rotation.
**Baselines:** design `491c4ed`; implementation `ae040e7`. Claims are marked
verified by reading, verified by execution, or open.

**What changed from v9.** One correction and two acceptance clarifications. v9
placed a corporate-action barrier at the earliest supplied event clock, on the
reasoning that earliest is most conservative. It is not, because a barrier can
be reopened by a fresh observation: with an entitlement boundary on Monday, a
real print on Tuesday and an effective boundary on Wednesday, Tuesday becomes a
new carry source and Wednesday is filled without any path crossing Monday - so
the later boundary loses its protection entirely. Neither the earliest nor the
latest clock is inherently conservative for a barrier that observations can
reopen, so section 5.2 now retains **every** supplied boundary. Detector 9 is
rewritten around that case, detector 10 scopes the unlocatable-fact failure, and
section 5.2 makes that failure cutoff-local as `contracts.md:354-358` requires.
Section 3.7 records all three.

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
| Carry across a carry barrier | **Never**, at any age. Barriers are an accepted `known_inactive` interval; any knowable corporate action **where `price_basis` is undeclared**, with a barrier at each supplied event clock; and a knowable terminal assertion, permanently. | Suspensions are never bridged and nothing carries past a terminal event, while a declared split-adjusted basis lets carry cross a split rather than accruing avoidable `NA`. Barriers are also what make padded values depend on the request cutoff, accepted deliberately (sections 5.2 and 6). |
| Indicator-output carry | **Off** by default, available on. | Avoids compounding two treatments by default. Enabling it does not produce a dense series: warm-up, expiry and inactivity still leave holes (section 5.3). |
| Which fields carry | `open`, `high`, `low`, `close`, each from its own latest admissible earlier value. **`volume` never carries.** | Requires a required-input admission rule the engine does not have today; today's window gate over-blocks and under-blocks (section 5.4). |
| Which missing outputs are fillable, when output carry is on | Only an output missing because a required input was unavailable after input treatment. | Warm-up, unsatisfied readiness, calculation errors and anything across a barrier are never filled (section 5.7). |
| Readiness under carry | `stable_after` is satisfied on prepared inputs. No engine threshold on carried share. | After a gap or a resumption a *prepared* window suffices, not a window of real observations. "Ready" changes meaning and the contract must say so (sections 5.5 and 7). |
| Age clock | Venue open sessions from the carried value's own source time, stated explicitly. | Independent of `ledgr_valuation_stale(max_sessions)`; repeated carry does not refresh age (section 5.6). |
| Values under a carry policy | Knowledge-dependent by construction. The padded view is separately identified and computed at the request cutoff. | The strict policy remains the only cutoff-invariant one. The dependency has a conservative, derivable bound; whether revised values can be prepared or updated efficiently within it is a checkpoint question (section 6). |

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

### 3.3 From synthesis v5

**The affected-cell criterion was wrong in kind.** v5 section 6.1 defined the
revisable set by whether a column falls inside the newly knowable inactive
interval. Take Monday observed at 100 with Tuesday and Wednesday missing, and a
later fact naming Tuesday alone as inactive. Wednesday's carry from Monday fills
the span through Tuesday, so section 5.2 forbids it and Wednesday's value
changes - yet Wednesday is outside the interval and a one-session indicator's
window at Wednesday contains no Tuesday cell, so v5's set excluded it. That also
made detectors 5 and 8 contradict each other on the same cell. The criterion is
the carry path, and section 6.1 now states it that way.

**The forward reach omitted the window width and the output-carry stage.** v5
section 6.2 derived the affected column range from the asserted interval and the
carry age limit alone. The carry age bounds which *inputs* are filled, not how
far a filled input propagates: `width <- stable_after` and
`window <- bars_df[seq.int(i - width + 1L, i), ]`
(`R/features-engine.R:304,309`, verified) put an input at session `j` inside
every window ending in `j .. j + W_f - 1`, so a twenty-session average ending at
session 21 changes when a carried input at session 2 is invalidated under a
five-session carry limit. Enabled output carry extends the reach again. Section
6.1 derives the corrected bound.

**Required-field completeness was equated with output availability.** v5 section
5.4 and its contract draft said a window is unavailable "when and only when" a
declared field is unavailable. That is wrong in both directions: readiness
returns all-`NA` when the series is shorter than the window
(`R/features-engine.R:306`, verified) with every field present, and enabled
output carry can deliver a value where the calculation was unavailable.
Sections 5.4 and 7 now state the rule as input admission before calculation,
with readiness, calculation validity and output carry as separate later stages.

**Two smaller corrections.** v5 section 5.5 again said resumption waits for real
observations, after v4 was corrected for the same thing; it does not, because
the first print at or after resumption becomes a new admissible source. And v5
section 5.1 called the gap query non-blocking while section 13 placed it inside
the sequence preceding a spec cut; section 13 now runs it in parallel.

### 3.4 From synthesis v6

**The checkpoint prescribed a method it should only have permitted.** v6 framed
part (d) as whether revised values can be prepared "efficiently within that
bound" and required each feature's window dependencies as a checkpoint input.
That presumes a ranged invalidation. Recalculating an affected instrument's
whole indicator series during preparation is an equally valid candidate and
needs no window bookkeeping at all: identify which instrument's relevant facts
changed, prepare its inputs at the applicable cutoff, recalculate its series.
The bound constrains where *answers* may change, not where an implementation
performs *calculations*. Sections 6.2 and 10(d) now say so.

**The carry policy was not finished, and section 6's trigger set depended on
it.** v6 section 11 left lifecycle reset boundaries and fillable output
categories open, while the amendment requires this synthesis to settle both.
That mattered beyond tidiness: v6 section 6.1 said inactivity is the only
knowledge-dependent input, and a later-knowable corporate action that resets
carry would be a second trigger. `snapshot_equity_corporate_actions` carries
`knowledge_time` (`R/availability-schema.R:99`, verified), so the question is
real rather than hypothetical. Section 5.2 now defines carry barriers to include
corporate actions and terminal assertions, section 5.7 states the fillable
categories, and section 6.1 generalises its trigger set accordingly. The bound's
arithmetic is unchanged, because the mechanism is identical: a carry path
crossing a barrier.

### 3.5 From synthesis v7

**The corporate-action barrier had the wrong rationale.** v7 argued that
carrying a pre-split close past its split delivers a price on the wrong scale,
and that refusing was conservative because the series "might turn out" to be
adjusted. The basis is not an open question. The accepted equity synthesis
section 4 states that "the supported price basis is split-adjusted, and
distribution-adjusted bars are not admitted", and `price_basis` records the
declaration, permits `NULL` for an undeclared basis, and refuses
`distribution_adjusted` for execution with
`ledgr_distribution_adjusted_bars_unsupported`
(`R/snapshot_adapters.R:15-16,783-787,819-827`, verified). So in the supported
case a split introduces no scale break at all, and v7's blanket barrier would
have inserted avoidable `NA` into consistently adjusted data. Section 5.2 now
keys the rule on the declared basis.

**The permanent terminal prohibition was contradicted and unstated.** v7 section
5.2 forbade carry forever after a terminal assertion, while section 5.5
permitted carry to restart after any new observation and section 7's replacement
contract prohibited only *crossing* a barrier. With a terminal event at session
10, an accepted observation at 12 and a missing value at 13, carrying 12 to 13
crosses no boundary: section 7 permitted it while section 5.2 and detector 8
forbade it. Section 5.2 now states the permanence as the distinguishing property
of that barrier kind, section 5.5 exempts it from resumption, and section 7
carries it.

**One stale sentence.** v7 section 6.2 still opened by asking whether revised
values can be prepared efficiently "within that bound", which its own later
paragraph had superseded by admitting whole-series recalculation.

### 3.6 From synthesis v8

**A barrier had no stated location.** v8 said which corporate actions are
barriers and section 6.1 then wrote `[a, b]` for the sessions a barrier
occupies, but nothing said which clock determines that session. Knowability says
when a fact may be used, not which historical session its effect sits on, and
the event clocks are optional: `ledgr_validate_equity_corporate_action_rows()`
enforces `entitlement <= effective <= payment` only "when supplied" and requires
none of them to be non-missing (`R/availability-facts.R:469-481`, verified),
while `*_validated` flags exist for the economic terms and not for the clocks
(`:374-376`, `R/availability-schema.R`, verified). Nor is there one inherited
interpretation: the accepted equity synthesis section 3.4 locates the dividend
boundary on the entitlement clock, and settlement orders and bounds on
`entitlement_time` while using `effective_time` for other effects
(`R/corporate-action-settlement.R:9,78,166,171`, verified). Two implementations
could have stopped carry at different sessions and both claimed compliance.
Section 5.2 now locates the barrier and states the refusal when it cannot be
located.

**The subtype claim was too strong.** v8 said `subtype` has no enumeration, and
inferred that no vocabulary exists. Named subtypes do exist in settlement, which
tests `subtype == "ordinary_cash_dividend"` and matches subtype sets
(`R/corporate-action-settlement.R:145,155,158`, verified), while validation
requires only "a stable lower-snake-case code"
(`R/availability-facts.R:403`, verified). The accurate claim is that there is no
exhaustive validated enumeration, which is what makes the subtype-free default
appropriate; it is not that the vocabulary is absent.

### 3.7 From synthesis v9

**An earlier barrier is not a more conservative barrier.** v9 located a
corporate-action barrier at the earliest supplied event clock and argued that
this kept the branch conservative in one direction. Section 5.5 permits carry to
restart from any real observation, and that defeats it. Take an undeclared basis
and a knowable fact with an entitlement boundary on Monday, a real observation
of 100 on Tuesday, an effective boundary on Wednesday, and Wednesday's price
missing. v9 places the only barrier on Monday. Wednesday's carry source is
Tuesday, so the filled span is `(Tuesday, Wednesday]` and never touches Monday:
Wednesday takes 100, on the far side of the effective boundary the barrier
existed to protect. The same holds for output carry.

The sources establish that the clocks mean different things, not that the
earliest subsumes the rest - the accepted equity synthesis section 3.4 uses the
entitlement boundary for dividends while settlement uses the effective clock for
disposition and quantity effects (`R/corporate-action-settlement.R:155-171`,
verified), and validation permits the dates to differ. Choosing the latest clock
inverts the defect rather than removing it, by permitting carry across the
earlier boundary. Section 5.2 therefore retains every supplied boundary, which
needs no precedence decision between the clocks and is bounded at two barriers
per fact.

**Detector 9 was scoped wrongly and would have rejected this correction.** It
mandated a single earliest barrier, and its missing-clock clause was unqualified
even though section 5.2 exempts a declared basis and a strict policy. It is
rewritten, scoped, and carries the case above as a required fixture.

**The fail-closed outcome must be cutoff-local.** "Knowable at the request
cutoff" was already the wording, but nothing said that preparing a whole run
must not let an unlocatable fact first knowable in June fail a May decision.
`contracts.md:354-358` settles it: "Future facts may change snapshot and
descendant identity but must not rewrite earlier context, errors, features, or
supported telemetry." Errors are named explicitly. Section 5.2 now states it.

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

### 4.2 Decision: report the engine, keep the goal

**Accepted 2026-09-27.** Feature windows count venue open sessions, and lifetime
facts do not narrow the feature axis. The documentation is corrected to report
what the engine does rather than what was aspired to, and the engine stands.

**The door stays open, and it is scheduled.** Instrument-narrowed expected
sessions remain the stated design goal and are scheduled for the next release in
`../ledgr_roadmap.md`. This is a decision about what the documents claim now,
not a rejection of the semantics. The reasoning on both sides, the measured cost
each way, the two arguments that were made and do not hold, and the trip-wire
that makes narrowing expensive are recorded in `../horizon.md` (2026-09-27) so
that the next release reinstates it from the reasoning rather than from scratch.

**What the correction touches, and what it must not.** The live authority is
`contracts.md:803`. The availability synthesis, the v0.2.0.0 packet and gate 21
are accepted records of what was decided then, and Cut 13's LDG-2851 states the
convention directly: "historical closeouts, RFC artifacts, recorded spike
evidence and negative regression fixtures keep their original text and continue
to describe the surface they were written against." So the repair amends
`contracts.md`, records the supersession of gate 21's narrowing clause where
supersessions are recorded, and does not rewrite accepted RFC or packet text.
It also adds the fixture that was missing, which is what let the two drift apart
for two releases.

That scoping is a decision this document makes, not a mechanical consequence,
and the ticket should carry it explicitly.

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

**The cost, measured rather than estimated.** Both checks v4 and v9 left unrun
have now been run, and the cost is smaller than this document previously
claimed.

*Gates.* Gate 21 is the **only** gate that asserts narrowing, and only in one
clause of a sentence covering several behaviours: "those sessions leave the
feature and classification expected set". A scan of the whole gate section finds
that requirement once. The rest of gate 21 - target restriction at decision,
fills blocked with `lifetime_inactive`, mark ageing on venue sessions,
`valuation_horizon_exhausted` - is untouched by the axis decision, and section
4.4 preserves all of it. Gate 22 is terminal-assertion stopping and gate 23 is
stable-ID continuity, neither of which bears on the axis.

*Fixtures.* **No fixture encodes narrowing.** `known_inactive` appears in eleven
test files and none of them assert a feature value;
`tests/testthat/test-availability-features.R`, the strict-feature certification
file, contains four tests and no lifetime reference at all. Adopting gating
therefore requires no fixture change.

*And why the divergence survived a release.* Gate 21's narrowing clause has no
test coverage anywhere. It is design text that nothing executes, which is the
mechanism by which the engine and four authorities could disagree through two
tagged versions. The neighbouring guarantee is covered - `:114` of that file
tests that future facts cannot change earlier features, which is
`contracts.md:809-810` - so the cutoff-causal protection was wired up and this
rule was not. Whichever direction is chosen, the repair should add the fixture
that pins it, or the same drift recurs.

*The other direction is the expensive one.* Keeping narrowing requires an engine
change to a hydration path that currently **fails the run** on per-instrument
axes (`R/backtest-runner.R:904-905`), fixtures written from scratch since none
exist, and possible repair of existing fixtures that today expect `NA` across an
inactive span - plus the second knowledge channel in argument 1. That cost was
never stated before this measurement and is larger than gating's.

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
observation. That is a query, not a spike. It tunes the number and
blocks nothing: section 13 runs it in parallel with acceptance and the
checkpoint.

Rejected alternative: unbounded carry. Default-on and unlimited is the one
combination where a single stale price can propagate through a whole window with
nothing to stop it, and it sits against the package's existing stance, where
substituting an old price requires an explicit
`ledgr_valuation_stale(max_sessions)` policy and "the package supplies no
default stale horizon" (`contracts.md:306-307`). Research inputs do not inherit
that limit, but they should inherit its shape.

### 5.2 Carry never crosses a carry barrier

**Proposed default: prohibited, at any age, independently of the age limit.** A
**carry barrier** is a session or interval a carried value may not span. The
first implementation has three kinds, all derived from knowable facts:

1. **An accepted `known_inactive` interval.** Without this, a suspended
   instrument's sessions would fill from its last pre-suspension close and an
   average over that span would be computed from a fabricated flat series that
   reads like a real one.
2. **A knowable corporate action, but only where `price_basis` is undeclared.**
   The supported basis is split-adjusted (accepted equity synthesis section 4),
   and `price_basis` records it, with `NULL` leaving it undeclared and
   `distribution_adjusted` refused for execution outright
   (`R/snapshot_adapters.R:15-16,783-787,819-827`, verified). Three cases
   follow. Under a **declared split-adjusted** basis the series is consistently
   adjusted, so a split introduces no scale break and is **not** a barrier:
   carry crosses it, and blocking it would add avoidable `NA` to good data.
   Under an
   **undeclared** basis a scale break is possible and undetectable, so **any**
   knowable corporate action is a barrier, whatever its subtype. A
   **distribution-adjusted** basis never reaches a run. The asymmetry is
   deliberate - the conservatism sits where the ignorance is - and it needs no
   subtype classification, which matters because `subtype` is free text with no
   enumeration in the schema or in validation (`R/availability-schema.R:95`,
   verified), so a subtype-keyed rule would have to rest on a vocabulary this
   cycle does not own. A distribution in a split-adjusted series moves the price
   for real rather than rescaling it, so it is an age question, not a barrier -
   and that is a product choice rather than an accuracy guarantee, because the
   age limit bounds how stale a carried value is and not how large the resulting
   error can be. This rule decides only where a research carry stops; it does
   not touch accounting semantics.

   **Where the barriers sit.** **Every** supplied event clock among
   `entitlement_time` and `effective_time` produces its own barrier, at the
   first venue open session at or after it, and carry may not reach into or past
   any of them. A fact with both supplied produces two barriers, or one where
   they land on the same session, so a fact contributes at most two.

   Retaining both is not caution for its own sake. Choosing a single clock
   cannot work, because a barrier is reopened by any real observation (section
   5.5): with an entitlement boundary before an observation and an effective
   boundary after it, a single earliest barrier leaves the effective boundary
   unprotected, while a single latest barrier leaves the entitlement boundary
   unprotected. Neither extreme is conservative, and choosing between them would
   also require a clock-precedence rule the sources do not supply - the accepted
   equity synthesis uses the entitlement boundary for dividends while settlement
   uses the effective clock for disposition and quantity effects. Retaining both
   needs no such rule.

   `payment_time` never produces a barrier: it is an upper bound on the event,
   so using it would refuse too little. `knowledge_time` never produces one
   either - it says when the fact may be used, not when its effect occurred -
   and substituting it is prohibited rather than merely discouraged.

   **When no boundary can be established.** The clocks are optional: validation
   enforces their ordering only when supplied and requires none to be present
   (`R/availability-facts.R:469-481`, verified), and no `*_validated` flag
   covers them, so a fact can be knowable with every event clock missing. Where
   such a fact is knowable at the request cutoff, the basis is undeclared and at
   least one carry operation is enabled, the policy **fails closed** with a
   classed condition naming the fact. It does not guess a session, does not fall
   back to knowledge time, and does not silently deliver carried values under an
   unlocatable boundary. The two escapes are declaring the price basis, which
   removes the barrier entirely, and disabling carry, for which barriers are
   irrelevant.

   **The failure is cutoff-local.** Preparation may establish the refusal ahead
   of execution, but its observable effect begins only at cutoffs where the fact
   is knowable. An unlocatable fact first knowable in June must not fail a May
   decision, because "future facts ... must not rewrite earlier context, errors,
   features, or supported telemetry" (`contracts.md:354-358`, verified). The
   condition's name and storage are implementation decisions; its cutoff
   boundary is not.
3. **A knowable terminal assertion, permanently.** After a terminal event there
   is nothing to carry. Unlike the other two kinds this is not a boundary that a
   later observation reopens: a real print after a terminal assertion stays
   admissible as an observation (section 4.4) but never becomes a carry source.

This is the lifecycle reset decision the amendment requires of this synthesis.
Barriers are also the source of the cutoff dependence in section 6, because
whether one applies to a given cell depends on whether the asserting fact is
knowable at the request cutoff. That consequence is accepted rather than
avoided: the alternative is to keep filling cells across a boundary the data
says exists.

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
fields** and the window gate to test exactly those fields. The rule is **input
admission before calculation**, and it does not describe output availability.
Readiness still returns all-`NA` when the series is shorter than the window
(`R/features-engine.R:306`, verified) with every field present. Calculation
validity keeps its own handling, since
`ledgr_normalize_feature_scalar_output()` aborts on non-numeric and non-finite
results (`:239-246`, verified). And any permitted output carry applies after
calculation and can deliver a value where the calculation was unavailable. Input
admission, readiness, calculation validity and output carry are four stages and
certification tests them separately; an error is never converted into a fillable
gap. Without the admission rule, "volume never carries" does not imply
"volume-dependent indicators are `NA` across gaps". Naming the rule is a
synthesis decision; its shape - a declaration on the indicator definition
alongside `gap_contract`, or inference from the callback - is not decided
here.

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
resumption a prepared window suffices, so readiness does not require every input
in the window to be observed, and a value appears as soon as carry can complete
the window. Section 5.2 forbids carrying *across* an inactive interval or a
corporate-action barrier, not carrying after one: once a real observation
appears at or after the resumption it becomes a new admissible source, and later
gaps carry from it normally. A terminal barrier is the exception, because it is
permanent: no observation after it becomes a carry source, even though the
observation itself remains admissible (section 5.2, kind 3).

### 5.6 The age clock

**Proposed default: carry age counts venue open sessions between the carried
value's own source time and the delivered column, stated explicitly in the
delivered evidence.**

Repeated carry retains the original source time, so age accumulates and a value
carried for six sessions under a five-session limit is `NA`, not refreshed. The
clock is independent of `ledgr_valuation_stale(max_sessions)`: a valuation limit
is not an implicit research limit and a research limit is not a valuation
permission.

### 5.7 Which missing outputs are fillable

**Proposed default, when output carry is enabled: exactly one category.** An
output may be filled only when it is missing *because a required input was
unavailable after input treatment*, within the declared output carry age and not
across a barrier.

Never fillable:

- **Leading warm-up and unsatisfied readiness.** No value exists before the
  first admissible source, and none before `stable_after` is satisfied. The
  engine returns all-`NA` for a series shorter than the window
  (`R/features-engine.R:306`, verified) and no carry changes that.
- **Calculation errors.** An invalid indicator output aborts
  (`ledgr_normalize_feature_scalar_output()` at `:239-246`, verified) and is
  never converted into a gap that output carry then fills. This is the
  amendment's requirement that errors not become fillable gaps, stated as a
  category rather than a slogan.
- **Anything across a barrier**, per section 5.2, and anything after a terminal
  assertion.

So output carry fills exactly the holes that input carry could not close, and
nothing else. This is the fillable-output decision the amendment requires of
this synthesis. Which *named* outputs of a multi-output indicator participate is
a consequence of this rule rather than a separate list: each output is fillable
on its own missingness cause.

## 6. Values under a carry policy depend on the request cutoff

This section replaces v4's invariance claim and corrects the bound v5 derived
for it.

### 6.1 The statement, and the bound

Under the strict policy with the section 4.2 axis, a feature value is a function
of sealed bars and the venue axis, and does not change with the request cutoff
`t`. **Under a carry policy it does**, because sections 5.2 and 5.3 condition
carry on facts that carry knowledge times.

With the axis fixed and observations always admissible (section 4.4), bar
presence does not vary with `t`, and age counts sessions on a fixed axis so it
does not vary with `t` either. What varies is which **carry barriers** are
knowable at `t` (section 5.2): an accepted inactive interval, a corporate action
under an undeclared price basis, or a terminal assertion. All three act through
one mechanism - a carry path crossing a barrier - so the derivation below is
stated once and applies to each.

**The criterion is the carry path, not the destination.** A cell at session `s`
is filled from `src(s)`, the latest earlier session holding a real observation,
which fills the span `(src(s), s]`. A newly knowable inactive interval forbids
that carry when the span *crosses* the interval, so a destination lying outside
the interval can still lose its value.

**The bound.** Write `[a, b]` for the venue sessions a newly knowable barrier
occupies: an interval for an inactive lifetime assertion, and a single session
for each supplied event clock of a corporate action, located by section 5.2's
boundary rule rather than by knowledge time. A corporate-action fact can
therefore contribute two point barriers, and its affected set is the union of
the ranges below taken over each. With `A_in` for the declared maximum input
carry age, `W_f` for a feature's `stable_after`, and `A_out` for the declared
maximum output carry age. A disabled stage contributes zero. For one instrument
and one feature, every cell whose delivered value can differ between cutoffs `t1
< t2` lies within

> `[a, b + A_in + W_f - 1 + A_out]`

derived as follows. Carry into `s` is newly forbidden only if `(src(s), s]`
intersects `[a, b]`, which needs `s >= a` and `src(s) + 1 <= b`; with
`s - src(s) <= A_in` that gives `s <= b - 1 + A_in`, so affected inputs lie in
`[a, b + A_in]`. An input at `j` enters every window ending in
`j .. j + W_f - 1` (`R/features-engine.R:304,309`, verified), which extends the
range by `W_f - 1`. An enabled output carry can then propagate a changed output
a further `A_out` sessions.

**One barrier kind escapes the formula.** A terminal assertion has no forward
side, because carry never resumes past it (section 5.2). Its affected range
therefore runs from `a` to the end of the requested axis, and the arithmetic
above does not apply. This is a bound, not a prediction: most of those cells
were already `NA`.

**Output carry can be forbidden on its own.** With price padding disabled and
output carry enabled, no input changes, yet a carried output whose own path
crosses the interval is still forbidden. The bound covers that case because
`A_in` is then zero, but the mechanism is separate and the checkpoint must treat
it separately.

**Scope of the derivation.** It holds for features whose entire input dependency
is bounded by `W_f`, which is what `gap_contract = "strict_window"` commits a
definition to (`contracts.md:799-801`). It does not automatically cover
recursive or fitted methods, whose dependency is not a finite window; those
arrive with the deferred fitted-preprocessing work and must derive their own
bound.

### 6.2 What this establishes, and what it does not

The dependency has a conservative, derivable bound. The checkpoint must
establish whether correct cutoff-specific values and their evidence can be
produced at all: the bound says where answers may change, and places no
constraint on where an implementation performs its calculations.

That is deliberately weaker than v5 claimed. A derivable range says where
recalculation may be needed. It does not say what recalculation costs, how
revised values are produced, or whether preparation stays practical - and a long
inactive interval can put most of an instrument's history in range, at which
point being bounded stops being a useful property. Locality is not efficiency.

**The bound does not prescribe a recalculation method.** It constrains where
answers may change, not where an implementation performs calculations.
Recalculating an affected instrument's whole indicator series during preparation
is an admitted candidate and needs no window bookkeeping: identify which
instrument's relevant facts changed, prepare its inputs at the applicable
simulated cutoff, recalculate its series. Finding the affected instrument and
deriving the exact affected output range are different amounts of bookkeeping,
and the ranged variant should earn its complexity by measurement rather than by
assumption.

Neither candidate is free, and nothing here says which wins. At `ae040e7` the
strict path loops over windows and invokes `series_fn` on each window rather
than once per series (`R/features-engine.R:308-328`, verified), so whole-series
recalculation costs roughly window width times series length in R per feature
today; vectorised whole-series computation is a candidate capability, not a
property this path has. Equally, per-range invalidation carries bookkeeping that
may cost more than it saves - the pattern is familiar from spreadsheet
dependency tracking and from warehouse refresh strategies that choose full or
incremental recomputation by cost while requiring the same result. Those
precedents justify allowing different preparation granularities; they establish
nothing about which is right here.

Instrument-level independence must not be assumed beyond instrument-local
indicators: multivariate and fitted methods may make one instrument's revision
affect others, and they are deferred (section 6.1's scope note).

**A named candidate, added 2026-09-27 on a maintainer proposal.** The preceding
paragraphs treat the mechanism as unknown. It need not be. The snapshot is
sealed, so every fact's knowledge time is known before the run starts, which
means admissibility changes only at a finite and enumerable list of breakpoints,
and between two breakpoints nothing about it changes. A feature series is
therefore **piecewise constant in the knowledge clock**. And because pulses
advance monotonically, the cutoff advances monotonically too, so only the
current segment's view is ever required.

That yields a concrete preparation strategy rather than a search:

- enumerate each instrument's own admissibility breakpoints from the sealed
  facts, before the fold;
- compute that instrument's series once per segment between its breakpoints;
- serve the current pulse from the segment containing it, and a history view at
  `t` from the segment containing `t`;
- hold one view live and advance it forward, discarding the previous segment.

Its cost is bounded by fact sparsity rather than by pulse count. A lifetime fact
names one instrument, and features are computed per instrument from that
instrument's own bars today, so a breakpoint recomputes one series rather than
the panel. The prepare cost is the baseline multiplied by one plus the average
number of admissibility-affecting facts per instrument, which is typically one
or two - a listing and a delisting - rather than a multiple of `T`.

Two limits, stated because they decide how far the candidate carries.

Cross-sectional features break the per-instrument locality: if a feature reads
across instruments, a fact about one changes the values of others and the cheap
single-series recompute collapses into a panel recompute. The shipped features
are per-instrument, so the candidate holds for what exists, and the multivariate
and fitted methods this cycle was motivated by are exactly the case that breaks
it. Extending it is their work, not this document's.

Warm-up interacts with the breakpoint. Recomputing under a different
expected-session set moves where warm-up completes, so the affected range is the
breakpoint plus the window rather than the breakpoint alone. Section 6.1's bound
already carries the `W_f - 1` term for that reason, and the two derivations
agree.

The candidate satisfies section 10's failure criterion on its face: preparation
happens before execution, nothing reconstructs fact segments at a pulse, no
accessor queries storage per callback, and no second execution path appears. So
checkpoint part (d) becomes a measurement of a stated design rather than a
search for one.

Section 10's failure criterion still applies to whatever mechanism is proposed,
including this one: preparation before execution is compatible, and per-callback
storage queries, reconstructing fact segments at a pulse, or a second execution
path are not. Whether the candidate above produces correct cutoff-specific
values and evidence within those constraints, and at what cost, is checkpoint
part (d). This document names a candidate; it does not assert that it works.

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
> indicator declares the input fields it requires, and input admission tests
> exactly those fields before calculation. Under the strict policy any missing
> required input makes the affected window `NA_real_`. Readiness and
> calculation-validity rules are unchanged and apply after admission, and any
> permitted output carry applies after calculation; an error is never a fillable
> gap. Under a declared carry policy a required input may instead be
> satisfied by a carried earlier value of the same field for the same stable
> instrument, within the declared maximum carry age and never across a carry
> barrier, never from a later observation, and never for `volume`. Carry barriers
> are an accepted `known_inactive` interval and, where the price basis is
> undeclared, any knowable corporate action; under a declared split-adjusted
> basis a split is not a barrier. Where the basis is undeclared, each supplied
> entitlement or effective clock of a corporate action produces a barrier at the
> first venue open session at or after it; payment time and knowledge time never
> produce one; and where no such boundary is supplied the request fails at
> cutoffs where the fact is knowable rather than carrying under an unlocatable
> boundary, without affecting earlier cutoffs. After a knowable terminal assertion nothing
> carries at all, permanently, and no later observation becomes a carry source,
> although that observation itself remains admissible. Where output carry is
> declared it may fill only an output missing because a required input was
> unavailable after input treatment; warm-up, unsatisfied readiness and
> calculation errors are never filled. A window satisfied in part by carried inputs is delivered with the
> count and share of carried inputs, and `stable_after` readiness is satisfied
> on prepared inputs rather than on observations. Values delivered under a carry
> policy depend on the request cutoff through barrier knowability only; such a
> view is separately identified and never overwrites an earlier output.
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

**(d) Numerical revision.** Whether correct cutoff-specific values and their
evidence can be produced, under the single failure criterion: prepared before
execution, with no per-callback storage query, no reconstruction of fact
segments at a pulse, and no second execution path.

Since 2026-09-27 this part has a named candidate rather than an open field, and
it should be run as a measurement of that candidate first. Section 6.2 states
it: enumerate each instrument's admissibility breakpoints from the sealed facts,
compute one series per segment, serve the current pulse and any history view
from the segment containing its cutoff, and advance one live view forward. What
the measurement must establish is the prepare cost against the baseline at a
realistic universe and range, the count of breakpoints per instrument in real
data rather than in fixtures, the transient memory while a segment is replaced,
and the same under the per-worker replication established below.

Two things the candidate does not settle and this part must still answer: what
happens when a feature reads across instruments, since the candidate's cost
argument depends on per-instrument locality that cross-sectional features break;
and whether a forbidden output carry, which is its own trigger, is handled by
the same segmentation.

**The bound is also the recompute target.** Section 6.1 derives `[a, b + A_in +
W_f - 1 + A_out]` as the set of cells whose value may differ between cutoffs. It
is simultaneously the set of rows a segment change needs to recompute, so the
same interval serves as a claim and as an instruction. The locality is strict
rather than heuristic: a window ending at `s` reads only `W_f` expected sessions
back from `s`, so if none of those lie in the changed region the value cannot
change and the row needs no check at all.

That gives a second, cheaper form of the candidate. Rather than recomputing an
instrument's whole series per segment, recompute only the banded rows, with the
band table built before the fold from the sealed facts. The expensive part of
partial updating is normally discovering what to invalidate, and sealed facts
remove that problem entirely: the trigger table is static, so nothing resolves
dependencies at a pulse, and the update is an indexed write into a typed buffer
rather than new machinery.

**Two stages, in this order, because the cheap form has a failure mode the
expensive form does not.** Banding that gets its arithmetic wrong ships a stale
value silently - no error and no `NA`, just a number from the previous knowledge
state - whereas whole-series recomputation either runs correctly or does not
run. So whole-series per segment is implemented first and serves as the
normative oracle, matching this project's existing rule that canonical R is the
oracle for an optimised path; banding is then implemented against it with a
differential test asserting cell-for-cell agreement over a fixture carrying
every breakpoint kind. The measurement decides whether banding ships at all.

**A measured prior, so the measurement does not start from nothing.** Against
the 2026-09-05 Sharadar acquisition over 2015-01-01 to 2024-12-31, breakpoint
density is 1.11 lifetime events per instrument across 11,474 instruments whose
price coverage overlaps the window, and 0.451 across the 1,586 large and mega
caps. On whole-series-per-segment that is a prepare-phase multiplier of about
2.11x and 1.45x respectively; terminal assertions alone are about 0.62 per
instrument, so a declared split-adjusted basis, under which corporate actions
are not barriers, sits nearer 1.6x. The same window holds 2,473 distinct
breakpoint dates against roughly 2,520 trading days, so a panel-wide recompute
per breakpoint date is unaffordable and per-instrument locality is load-bearing
rather than an optimisation. Universe choice moves the cost more than the
algorithm does, which makes universe churn an input to this part rather than a
detail. The full record, with method and queries, is in the research repo's
`docs/governance/ledgr-upstream-state.md`.

Note what the prior does not say. It is zero under the semantics this version
ships, because the engine consults no lifetime fact for a feature window. These
figures price the next release, and they are a multiplier on the prepare phase
rather than on a run, so the absolute cost still needs the existing phase
clocks.

Performance conclusions stay separate from this semantic result. Any eventual
measurement covers preparation cost, the evidence in section 8, and worker
memory under the per-process replication established below, and it follows
`../spike_protocol.md`. Nothing here charters it.

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
- The shape of the required-input declaration in section 5.4: a field on the
  indicator definition beside `gap_contract`, or inference from the callback.
- Whether a future release wants finer granularity under an undeclared price
  basis than "any corporate action is a barrier". That would need an exhaustive
  validated subtype enumeration, which does not exist today even though named
  subtypes do; it is a refinement rather than a gap, since section 5.2's rule is
  subtype-free.
- Whether the corporate-action event clocks should gain `*_validated` flags of
  their own, as the economic terms have. Section 5.2 works with supplied clocks
  and fails closed without them, so this is a strengthening rather than a
  prerequisite, and it belongs to the fact-family owner.

- Encoding of the section 8 evidence, including `gap_type` vocabulary ownership
  and model-facing view versus canonical storage.
- The recalculation granularity of section 6.2, which measurement decides rather
  than this document.
- Everything the amendment defers: fitted imputers, their algorithm selection
  and the fitting boundary, which stay in the 2026-09-26 horizon entry and
  remain model- and adapter-owned.

Not on this list any more: the age limit's number, which section 5.1 proposes as
a shipping default with a named tuning measurement; lifecycle reset boundaries,
decided in section 5.2; and which missing outputs are fillable, decided in
section 5.7. The price-basis dependency in section 5.2 is decided from an
existing declared field and needs nothing from another workstream to operate.
Also not open: a precedence rule between the entitlement and effective clocks,
which retaining every supplied boundary removes rather than defers.

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
4. **Revision correctness** - a carry whose path crosses a barrier knowable at
   `t` still delivering a value, including where the destination lies outside
   the barrier; and, in the other direction, a cell losing its carry because of
   a fact *not* knowable at `t`. Both halves are required; input carry and
   output carry are both in scope; and all three barrier kinds need a fixture.
5. **Revision locality** - a value differing between two cutoffs outside section
   6.1's conservative bound, which would mean the dependency is wider than the
   derivation allows. Cells inside the bound *may* differ and must never fail
   this detector, since the bound is a superset rather than a prediction.
6. **Future-value escape** - a supported accessor returning a value beyond the
   invoking pulse, in dense and availability-aware execution.
7. **Backward carry** - a cell filled from a later observation, in any policy,
   at any age, even when that observation is knowable at `t`.
8. **Age and barrier violation** - a carried value exceeding the declared age
   limit, or crossing any carry barrier, or appearing at all after a knowable
   terminal assertion. The over-blocking direction fails too: a corporate action
   acting as a barrier under a declared split-adjusted basis (section 5.2).
9. **Barrier location** - **where the price basis is undeclared and at least one
   carry operation is enabled**, any supplied entitlement or effective clock of
   a knowable corporate action not producing a barrier at the first venue open
   session at or after it; or, in any policy, a barrier located from
   `payment_time` or `knowledge_time`. The scope qualifier matters: without it
   this item and detector 8 contradict each other under a declared
   split-adjusted basis, where a corporate action must *not* act as a barrier.
   The required fixture is the case a single-clock rule misses: an undeclared
   basis, an entitlement boundary, a real observation on a later session, an
   effective boundary after that observation, and a missing price at the
   effective boundary, which must not be filled from the intervening
   observation. Output carry needs the same fixture.
10. **Unlocatable barrier** - a knowable corporate-action fact supplying no
    event clock proceeding instead of failing closed, **where the basis is
    undeclared and at least one carry operation is enabled**; the failure
    occurring under a declared basis or a strict policy, which section 5.2
    exempts; or the failure observable at a cutoff where the fact is not yet
    knowable, which `contracts.md:354-358` forbids.
11. **Observation suppression** - a real observation inside an accepted inactive
    interval being dropped rather than delivered (section 4.4).
12. **Input admission** - a window computed when a declared required field is
    unavailable, or refused because an undeclared field is unavailable; and a
    readiness outcome or a calculation error being reported as a field-admission
    outcome or converted into a fillable gap (section 5.4).
13. **Silent treatment** - a delivered value whose carried status, carried count
    or source age is absent or wrong; a disabled operation taking effect; or
    enabling one operation enabling the other. No treatment is inferred from
    `NA`.
    Also: an output filled outside section 5.7's single eligible category.
14. **Strict/padded confusion** - a strict artifact satisfying a padded request
    or the reverse; and strict outputs changing where inputs and policy are
    unchanged.
15. **Retained-result mutation** - mutating a returned window altering engine
    storage, another consumer, or a later result; or a retained result losing
    its axis, cutoff or policy when the fold advances.
16. **Axis alignment** - row order disagreeing with the contract-defined
    decision axis including held-nonmember placement, or a `0 x L` empty-axis
    result failing.
17. **Claimed-distinction collapse** - for whatever distinctions the companion
    claims to express, a detector fails when two become indistinguishable, and
    any distinction it does not claim fails explicitly rather than returning a
    plausible value.
18. **Current-value parity** - scalar, plane and bundle reads disagreeing with
    the pre-change run at any pulse under unchanged policy.
19. **Inspection preservation** - the interactive reader failing when the long
    table is empty.

No member-count, timing or memory threshold is an acceptance gate.

## 13. Next action

Accept, or revise the section 1 table. On acceptance:

1. Give the session-axis repair an **owning ticket in the current release**. It
   amends four authorities including gate 21, and it must check whether
   certification fixtures encode narrowing. It is a prerequisite for section 10,
   because what counts as a session determines where carry is possible.
2. Run the section 10 checkpoint, all four parts, against the single failure
   criterion. Part (d) asks only whether correct cutoff-specific values and
   evidence can be produced within the constraints, with recalculation
   granularity left to measurement; part (c) must be answered before the carry
   default is fixed.
3. Choose the section 8 representation with per-worker replication assumed
   (section 10), then measure rather than measuring first.

Only then consider a spec cut. No comparative spike is chartered and no spec
packet is written here.

Not blocking any of the above: run the section 5.1 gap-distribution query once
an availability-aware ingest exists, to tune the age limit. It is advisory and
runs in parallel. LDG-2864 and LDG-2850 also proceed independently.

## 14. Revision history

- 2026-09-27: v10, checkpoint part (d) records that section 6.1's bound is also
  the recompute target, adds the banded form of the candidate with its static
  pre-fold trigger table, and orders the two forms: whole-series per segment as
  the normative oracle first, banding against it second with a differential
  test, because banding can ship a stale value silently and whole-series cannot.
  Adds the measured breakpoint density from the 2026-09-05 Sharadar acquisition
  as the measurement's starting prior, including that 2,473 distinct breakpoint
  dates in ten years make per-instrument locality load-bearing rather than
  optional, and that the figures are zero under the semantics this version
  ships.
- 2026-09-27: v10, section 6.2 and checkpoint part (d) gain a named preparation
  candidate on a maintainer proposal. Because the snapshot is sealed, every
  fact's knowledge time is known before the run and admissibility changes only
  at an enumerable set of breakpoints, so a feature series is piecewise constant
  in the knowledge clock and a monotone pulse axis needs only the current
  segment's view. Cost is bounded by fact sparsity rather than pulse count,
  since a lifetime fact names one instrument. Recorded with its two limits:
  cross- sectional features break the per-instrument locality, and warm-up
  extends the affected range by the window. Part (d) becomes a measurement of a
  stated design rather than a search for one. No accepted semantics change.
- 2026-09-27: v10, section 4.3 cost paragraph replaced with measured results.
  The two checks v4 and v9 deferred are run: gate 21 is the only gate asserting
  narrowing and only in one clause, and no fixture encodes it, so adopting
  gating costs one clause and no test changes. Recorded alongside: that clause
  has no test coverage at all, which is how the divergence survived two tagged
  versions, and the narrowing direction carries an engine change plus fixtures
  written from scratch. No decision changed; an unpriced cost is now priced.
- 2026-09-26: v10, corrected in place after Type 2 review of `22b9580`. Detector
  9's positive barrier requirement and section 7's per-clock sentence now carry
  the policy scope - undeclared basis, at least one carry operation enabled -
  which section 5.2 already stated. Without it detector 9 and detector 8
  contradicted each other under a declared split-adjusted basis. No decision
  changed; the reviewed text is preserved in git history at that hash.
- 2026-09-26: v10. Supersedes v9. Corrects the barrier-placement rule: every
  supplied entitlement or effective clock produces its own barrier, rather than
  only the earliest. An earlier barrier is not a more conservative one, because
  section 5.5 lets any real observation restart carry, so an observation falling
  between the two clocks leaves the later boundary unprotected; choosing the
  latest clock inverts the defect instead of removing it. Retaining both also
  removes the need for a clock-precedence rule the sources do not supply.
  Detector 9 is rewritten around that fixture and no longer mandates a single
  barrier, detector 10 scopes the unlocatable-fact failure to an undeclared
  basis with carry enabled, and section 5.2 makes that failure cutoff-local as
  `contracts.md:354-358` requires.
- 2026-09-26: v9. Supersedes v8 with one bounded clarification. States where a
  corporate-action barrier sits: the first venue open session at or after the
  earliest supplied of the entitlement and effective clocks, with `payment_time`
  and `knowledge_time` both prohibited as locators, and a fail-closed refusal at
  preparation when a knowable fact supplies no event clock at all. This was
  needed because the clocks are optional - validation enforces their order only
  when supplied and requires none to be present - and because settlement and the
  accepted equity synthesis use different clocks for different effects, so two
  implementations could have stopped carry at different sessions. Adds detector
  9 for barrier location. Corrects v8's claim that no subtype vocabulary exists
  to the accurate one that no exhaustive validated enumeration exists, and
  records that allowing carry across a distribution in a split-adjusted series
  bounds staleness rather than error size.
- 2026-09-26: v8. Supersedes v7. Keeps the open recalculation method and the
  fillable-output rule. Corrects the corporate-action barrier, whose rationale
  ignored that the supported price basis is already split-adjusted: the rule is
  now keyed on the declared `price_basis`, so a split is no barrier under a
  declared split-adjusted basis and any corporate action is one under an
  undeclared basis, which is operational today without a subtype vocabulary that
  `subtype` does not have. States the terminal prohibition's permanence as that
  barrier kind's distinguishing property, exempts it from section 5.5's
  resumption rule, and carries it into section 7's replacement contract, which
  previously prohibited only crossing a barrier and so contradicted section 5.2.
  Adds the over-blocking direction to detector 8 and removes section 6.2's stale
  "within that bound".
- 2026-09-26: v7. Supersedes v6. Keeps the corrected bound and the settled
  clock semantics. Stops the checkpoint prescribing a recalculation method:
  whole-series recalculation of an affected instrument during preparation is an
  admitted candidate beside per-range invalidation, the bound constrains where
  answers may change rather than where computation happens, and neither
  candidate is costed here - the strict path invokes `series_fn` per window at
  `ae040e7`, so whole-series vectorisation is a candidate capability rather than
  an existing property. Completes the carry policy the amendment requires this
  synthesis to settle: carry barriers now comprise accepted inactive intervals,
  knowable price-scale corporate actions and knowable terminal assertions, and
  section 5.7 states the single category of fillable missing output. Generalises
  section 6.1's trigger set to barrier knowability, with the bound's arithmetic
  unchanged because the mechanism is identical. Fixes detector 5 to say cells
  inside the bound may differ, and section 5.5's readiness wording.
- 2026-09-26: v6. Supersedes v5. Keeps the section 1 policy. Corrects section
  6's revision bound in two places: the criterion is whether a carry path
  crosses the newly knowable inactive interval rather than whether the
  destination sits inside it, and the forward reach is
  `b + A_in + W_f - 1 + A_out` rather than the carry age alone, since an input
  enters every window ending within `W_f - 1` sessions of it and an enabled
  output carry propagates further. Records that a forbidden output carry is its
  own mechanism, limits the derivation to features whose input dependency is
  bounded by `W_f`, and replaces the claim that revision is an indexed
  invalidation with the weaker and accurate claim that the dependency is local
  while its cost is a checkpoint question. Restates the required-field rule as
  input admission before calculation, with readiness, calculation validity and
  output carry as separate stages. Fixes the resumption statement and makes the
  gap query's advisory status consistent.
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
