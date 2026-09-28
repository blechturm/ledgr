# Empirical exposure to historical numerical revision

**Answer to step 1: no revision triggers occur in any research workload this
machine holds, and the reason is structural rather than a sampling accident. Steps
2 and 3 are therefore not entered**, because the brief conditions them on exposure
existing. Recommendation: **no additional revision machinery for the demonstrated
supported scope**, with a named limitation that must not be left implicit.

Working HEAD `d7c6d7f` on `spike/segmented-feature-views`. The brief names `427a41f`
as the reviewed record; `d7c6d7f` is that record plus the Type 2 review response,
which withdrew five overreaching claims and fixed two harness defects. Nothing was
committed, pushed, implemented or amended for this investigation. No package file,
vignette, roadmap or accepted document was edited.

Artifacts, both read-only and both ordinary queries rather than spikes:

| Script | Evidence | What it establishes |
| --- | --- | --- |
| `fact_clock_census.R` | `fact_clock_evidence.csv` | whether any built fact can become knowable after an affected session |
| `declared_absence_census.R` | `declared_absence_evidence.csv` | absence against a declared calendar and declared lifetimes, split by section 5.1's four locations |

## 1. Measured: what actually occurs

### No fact in any built snapshot can become knowable late

Census over all 14 sealed ledgr snapshots on this machine, spanning the real
baseline workloads (562 instruments, 413,532 bars, 2019-01-02 to 2021-12-31, plus
five-instrument controls).

| Availability family | Facts | `knowledge > effective` | `knowledge = effective` | `knowledge < effective` | null |
| --- | --- | --- | --- | --- | --- |
| `snapshot_lifetime` | 2,038 | **0** | 2,038 | 0 | 0 |
| `snapshot_membership` | 222,250 | **0** | 222,250 | 0 | 0 |
| `snapshot_membership_sets` | 444 | **0** | 444 | 0 | 0 |
| `snapshot_trading_status` | 0 | - | - | - | - |
| `snapshot_corporate_actions` | table absent | - | - | - | - |

`knowledge_time > effective_from` is the necessary condition for any of the three
mechanisms to revise a historical value, because a fact is knowable once
`knowledge_time <= cutoff` (`R/availability-provider.R:51-57`). Across 224,732
facts it never holds. `snapshot_trading_status` exists in all 14 snapshots and is
empty in all 14, so the one family that carries a genuine lag in ledgr's own
synthetic fixture - a halt effective on one session and knowable later - has no rows
in any real workload. There is no corporate-actions table at all.

### No absent expected session, against declared inputs

The previous revision defined a calendar from observed dates and coverage from each
instrument's own first and last print, which cannot see leading absence, trailing
absence, or an entirely absent instrument. This measures against declared inputs:
the sealed venue calendar (`snapshot_sessions` where `status = 'open'`) and each
instrument's declared `known_active` span.

| Quantity | Value |
| --- | --- |
| Declared open sessions | 757 |
| Instruments declared / with bars | 563 / 562 |
| Bars, and bars matching a declared open session close | 413,532 / **413,532** |
| Instruments with a declared active span | 175 |
| Instruments with a declared `known_inactive` interval | 18 |
| Expected sessions (declared open, inside a declared active span) | 127,875 |
| **Absent expected sessions** | **0** (0.000%) |

Zero at every one of section 5.1's four locations: none before a first observation,
none after a last observation, none inside an active span, none inside a declared
inactive interval. No bar falls outside the declared calendar either.

So the run-length distribution section 5.1 asked for, to tune the carry age, is
**empty on this workload**. There is no distribution to report, which is a different
statement from the number being small.

### The three mechanisms, separated as the brief requires

| Mechanism | Surface present? | Revision exposure |
| --- | --- | --- |
| Price-input carry | No absent expected session to fill | **0** |
| Output carry | Independent of input carry; no late-knowable fact to forbid a path | **0** |
| Instrument-narrowed sessions | **Yes** - 18 declared inactive intervals | **0** |

Narrowing deserves the emphasis the brief gives it. It is a genuinely independent
mechanism: a newly knowable inactive interval changes which sessions are expected,
which changes window composition, which revises values - with no carry involved. And
it has real surface here, 18 declared intervals. What it lacks is the same necessary
condition: none of those intervals becomes knowable after a session it affects. So
**deferring carry does not remove narrowing's dependency**, and if narrowing ships
against a source that supplies genuine knowledge clocks, the revision obligation
returns through it. That is a coupling to state in the decision, not a reason to act
now.

## 2. Assumptions, stated as assumptions

**`assume_effective` records an assumption, not an observed zero lag.** Verified at
adapter source in `ledgr-research/packages/ledgr.sharadar/`: lifetime facts assign
`knowledge_time` from the effective clock, and membership snapshots assign both
clocks from source availability boundaries with a declared one-day lag. The zeros
above are therefore facts about what the adapter constructs, which is exactly what
the engine consumes - but they are not measurements of when a subscriber could first
have known anything.

**The declared denominator covers 175 of 562 instruments.** 387 carry no lifetime
assertion at all, so no declared span exists for them and they contribute no
expected sessions. Their absence is not derivable from facts, and no span was
assumed for them.

**One vendor, one asset class, four capture vintages one day apart.**

## 3. Remaining unknowns, named rather than filled

**Subscriber knowledge timing is not identifiable from these data.** A single
capture cannot distinguish a new record from a correction, so vintage differences do
not establish first availability. This is reported as not identifiable rather than
as zero cases or as a fabricated lag distribution.

**Absence for the 387 instruments without a declared span** requires a declared
listing history this snapshot does not contain.

**Whether a zero-volume print is an imputation** is unresolved and remains a
hypothesis; the association measured earlier does not distinguish vendor fill from an
official close published without trading.

## 4. What leaving it unchanged does

For the demonstrated scope, nothing: with zero triggers, a preparation that uses all
sealed facts and a cutoff-correct preparation return identical values, so there is
no baseline-versus-reference comparison to make and none was manufactured.

The consequence *per trigger*, should one ever exist, is already bounded by measured
work and did not need rebuilding: across twelve lag positions at two widths, the
cells a never-revised shortcut gets wrong plus those a full-knowledge shortcut gets
wrong equal the history revision exactly, so the affected count per event is the
feature width and the arrival lag decides only which shortcut pays. That is a
partition of mismatching cells in fixtures. It is explicitly **hypothetical** as an
incidence estimate, bounds consequence rather than frequency, and is not economic
harm, which nothing here measures.

## 5. Decision, and the restriction it requires

**Recommended: no additional revision machinery for the demonstrated supported
scope**, combined with an explicit limitation for maintainer consideration. Not
recommended: a straightforward correct implementation, or an elaborate one, since
neither has a demonstrated need; and not inconclusive, because the necessary
condition was measured directly and is absent.

The limitation must be recorded rather than absorbed. A small or absent effect can
justify accepting a limitation; it does not authorise retaining an unqualified exact
point-in-time claim for configurations whose correctness has not been discharged.
Two restrictions follow, and this report adopts neither:

1. Either the carry and narrowing capabilities are explicitly deferred or
   restricted, or checkpoint parts (c) and (d) remain owed for them. A default
   change does not discharge them, and output carry keeps the dependency alive
   independently of price-input carry.
2. Any contract sentence asserting exact cutoff-correct historical values must be
   scoped to the configurations actually discharged - which today means the strict
   policy on a fixed axis.

Checkpoint parts (a) semantic and (b) representational are **not** relieved by this
result. They concern whether the two-clock condition and the historical companion
distinctions can be expressed and prepared at all, which is the historical-data
access work with an established use, and they stand independent of carry.

## 5b. The separate no-trade question: identifiable, and concentrated

Added after the exposure result, on a maintainer question: is the no-trade condition
present in the source data in principle, and if so how big is it.
`no_trade_identifiability.R`, `no_trade_identifiability_evidence.csv`. This concerns
a different population from everything above - sessions where a row **is** present
and nothing traded - so it neither supports nor weakens the revision result.

**Identifiable, explicitly, and corroborated by a second independent signal.**

| Signal | Count | Note |
| --- | --- | --- |
| `volume` null | **0** | the flag is never absent |
| `volume = 0` | 270,949 | the explicit flag |
| ...also `open = high = low = close` | 270,947 | **99.999%** of them |
| ...zero volume but a real intraday range | 2 | the only inconsistent rows |
| ...also equal to the previous close | 268,958 | |
| Traded sessions that are degenerate | 376,088 | control: degeneracy alone is not sufficient |

So this is not hidden or reconstructed information. `volume = 0` is always present and
agrees with OHLC degeneracy on all but two rows in 8.37M. A consumer can identify the
condition exactly. The gap is that ledgr does not *use* an available flag, not that
the data withholds one. Note also that 376,088 traded sessions have no intraday range
at all, so zero volume is the extreme of a continuum rather than a distinct defect.

**Magnitude is concentrated in names a research universe would filter.** By in-window
median dollar volume decile, computed from traded sessions only so a name does not
define its own liquidity from its zero rows:

| Decile | Median $/day | Zero-volume share |
| --- | --- | --- |
| 1 (least liquid) | 5,288 | **37.29%** |
| 2 | 27,943 | 8.72% |
| 3 | 81,381 | 1.76% |
| 4 | 180,180 | 0.72% |
| 5 | 398,206 | 0.28% |
| 6 | 1,092,786 | 0.19% |
| 7 | 3,350,358 | 0.07% |
| 8 | 9,634,830 | 0.04% |
| 9 | 28,308,375 | 0.03% |
| 10 (most liquid) | 140,820,856 | 0.08% |

**This corrects the panel-average framing.** The 3.238% headline is a panel average
dominated by the bottom two deciles. Above decile 3 the exposure is under 1%, and in
the top half of the universe it is under 0.3%. Any liquidity filter a researcher
would apply anyway removes most of it.

It is also a lifecycle phenomenon rather than a general data-quality one. Zero-volume
share is **15.20%** within 90 days before a terminal action, **8.46%** earlier on the
same ticker, and **0.56%** on tickers with no terminal action at all. And it is
concentrated by instrument: 2,735 tickers carry any, 367 carry half of all such
sessions, 1,163 carry ninety percent. By year it ranges from 1.67% in 2020 to 5.26%
in 2022.

**What this supports.** The execution-policy item is worth opening, because the signal
is cheap, explicit and reliable, and no fill path consults it. What it does not
support is treating this as a broad correctness problem: for a liquid universe the
exposure is a fraction of a percent, and where it is large the instrument is either
illiquid or approaching delisting - which is either filtered or is itself the object
of study. Sizing it as "3.2% of the panel" overstates it for any realistic workload.

## 5c. Source-change attribution: one instrument, one cell

Added on review 2026-09-27, second round, which found that `lag_measurement.R` used
`EXCEPT` over `(date, action, ticker, value)` and so conflated an added row with a
changed value. Its "newer-capture-only delisting" rows were candidates, not
established additions. `source_change_attribution.R`,
`source_change_attribution_evidence.csv`.

**The candidate key is not unique, so multiset semantics were required.** 1,363 keys
repeat within a capture and **398 of those hold differing values**, so a dedup by
`any_value()` could report a changed value as stable. The comparison instead treats
each key's values as a bag, following the decomposition the research package's
comparator uses (`vintage-comparison.R`, `sharadar_compare_vintage_rows`).

| Attribution | Keys | Rows |
| --- | --- | --- |
| stable | 693,469 | - |
| added | 1,765 | 2,094 |
| removed | 1,491 | 1,812 |
| changed | **0** | - |

**"Zero changed" does not mean "no restatements."** Because the action date is part
of the key, a restated *date* appears as a removal plus an addition on two different
keys, not as an in-place change. Exactly one such restatement exists among
barrier-relevant kinds, and it is a single instrument:

| Ticker | Action | Date | Attribution | Present sessions at or after |
| --- | --- | --- | --- | --- |
| FDMLQ | `delisted` | 2002-04-24 | added | **1** |
| FDMLQ | `bankruptcyliquidation` | 2002-04-24 | added | **1** |
| FDMLQ | `delisted` | 2007-12-27 | removed | 0 |
| FDMLQ | `bankruptcyliquidation` | 2007-12-27 | removed | 0 |

The vendor moved FDMLQ's terminal date 5.7 years earlier, between two captures 17
hours apart. The other barrier-relevant differences are ordinary flow: 116
`dividend` rows all dated 2026-09-04, the day before the newer capture, and 7
`split` rows dated 2026-09-09, which is **after** the capture and so known in
advance.

**Consequence, traced through to inputs.**

| Mechanism | In scope | Cells that could change |
| --- | --- | --- |
| Price-input carry | 72 sessions at or after an attributed change | **0** - none is absent, so no carry exists to forbid |
| Instrument narrowing | present sessions at or after the added terminal | **1** |

So observed exposure across 45.3M price rows and two saved captures is **one
instrument and one cell, via narrowing, none via carry**. That is not zero, and it
is established by attribution rather than inferred from `assume_effective`.

**What two captures do and do not establish.** Both are full-table dumps of the same
scope (697,356 and 697,638 rows), so an added key does establish that the vendor's
table gained it within the interval. It does **not** establish when the market first
knew, nor what a subscriber querying differently would have seen. And a 17-hour
interval bounds nothing about the rate: one restatement in 17 hours is compatible
with many per year and with this being unusual.

## 5d. The liquidity filter, corrected to decision-time information

Review also found that section 5b ranked instruments by median dollar volume over
the whole study window, which is unavailable at any decision inside it, and
classified sessions by proximity to a *future* delisting, which is an explanatory
label rather than a usable filter. Both are withdrawn.
`pit_liquidity_filter.R`, `pit_liquidity_evidence.csv`, using a trailing 60-session
median dollar volume that excludes the session being judged.

| Trailing filter | Decisions passing | Zero volume that session | Fill bar had no trading | Sessions retained | Tickers |
| --- | --- | --- | --- | --- | --- |
| none | 7,806,491 | 3.211% | 3.210% | 100% | 9,257 |
| >= $100k/day | 6,102,548 | **0.051%** | 0.053% | 78.2% | 8,161 |
| >= $1M/day | 4,324,172 | 0.018% | 0.018% | 55.4% | 6,113 |
| >= $5M/day | 3,064,715 | 0.018% | 0.018% | 39.3% | 4,301 |
| >= $25M/day | 1,678,537 | 0.015% | 0.015% | 21.5% | 2,523 |

The correction strengthens the conclusion rather than weakening it: a modest
$100k/day filter, computable at each decision with no look-ahead, cuts exposure by a
factor of 63 while keeping 78% of sessions and 8,161 of 9,257 tickers. The
execution-relevant column is the fill bar, since ledgr fills at the next session's
open. **Corrected label:** those 3,233 are *eligible decision dates whose next
execution bar has no recorded volume*, not executed orders. They measure potential
exposure. Realised exposure is in section 5e.

**The filter is not free, and the table says so.** A $1M threshold retains 55% of
sessions and a $25M threshold 21.5%, so avoiding the exposure this way is a research
decision about universe coverage rather than a costless screen. What the corrected
measurement supports is narrower than "any realistic filter removes it": a filter
available at decision time reduces it by roughly two orders of magnitude, at a
coverage cost the researcher chooses.

## 5e. The two follow-throughs: downstream bias and realised fills

Both requested by review 2026-09-27, third round. `fdmlq_and_fills.R`,
`fdmlq_and_fills_evidence.csv`.

**FDMLQ downstream: one indicator cell, in no request.** The attributed correction
affects one price session, and one input can reach several outputs, so this needed
finishing rather than assuming.

| Quantity | Value |
| --- | --- |
| FDMLQ bars in the capture | 1,083 |
| History | 1997-12-31 to **2002-04-24** |
| Bars at or after the added terminal date | 1 |
| Position of the affected input in its own history | session **1,083 of 1,083** |
| Indicator cells affected, at widths 5, 20, 60, 200 | **1** at every width |
| Baseline workloads whose declared population contains FDMLQ | **0 of 14** |

The affected session is the *last* bar the instrument ever printed, so the windows
that would ordinarily carry a revised input forward - every window ending within
`W_f - 1` of it - do not exist. The reach is one cell regardless of feature width,
not `W_f` cells. And FDMLQ delisted in 2002 while the baseline workloads run
2019-2021, so the cell falls outside every intended request. **Downstream bias in
every measured request: zero.**

**Realised execution exposure: 0 of 10,486 actual fills.** Measured against the
completed runs already sealed in the baselines, not against eligibility.

| Quantity | Value |
| --- | --- |
| Snapshots carrying persisted fills | 8 |
| Executed `FILL` events | **10,486** |
| Matched to the bar they executed against | 10,486 (100%) |
| Join validation: fill price equals that bar's open | 10,486 (100%) |
| **Fills on a bar with no recorded volume** | **0** |

**A defect in the first attempt is worth recording, because its result would have
been vacuous.** Joining fills to bars on equal timestamps returned zero matches, and
therefore zero zero-volume fills - a true number that established nothing. A fill is
stamped at the session **open** it executes against, 14:30 UTC, while a bar is
stamped at the session **close**, 21:00 UTC. Joining on the civil date matches all
10,486, and the price identity confirms the match rather than assuming it.

**Scope limit.** These runs use a 562-instrument universe of large permatickers,
which is already liquid, so zero realised exposure is the expected outcome and is a
statement about these workloads rather than about all strategies. A strategy trading
the illiquid deciles would need its own measurement; section 5d bounds what it would
find at 0.051% of decisions above a $100k trailing filter.

## 6. What this means for the next release

The measured position is that ledgr's revision machinery would, on the data the
project actually has, run against zero triggers. That argues for spending the next
release on the disclosure and historical-access surface that has demonstrated use,
and for treating carry, narrowing and revision as deferred design with a reopening
trigger.

A reopening trigger written as "a dataset where strict missingness is a material
obstacle" will never fire, because nobody will be able to say whether it has. Two
conditions from this report are checkable instead, and either alone is sufficient:
a built snapshot containing at least one availability fact with
`knowledge_time > effective_from`, which `fact_clock_census.R` tests directly; or a
declared workload with a non-empty run-length distribution of absent expected
sessions, which `declared_absence_census.R` tests directly. Both are queries that
already exist and cost nothing to re-run against a new source.
