# Spike inventory: the late-known barrier revision seam

**Ran:** 2026-09-27, branch `spike/segmented-feature-views` from `0cf20e7`.
**Charter:** `charter.md`. **Probe:** `probe_findings.md`. **Evidence:**
`spike_evidence.csv`, 49 rows, and `spike_ablation_evidence.csv`, 223 rows, all
derived from the sealed store or from the candidate's own resolution. No row is a
narrated literal.

## Verdict

**Green on the charter's question.** A late-known carry barrier revises earlier
finite-window feature values, and a view prepared at an earlier cutoff is
unchanged when prepared again at that cutoff. The charter clause that decides it
is the kill condition: the revision was exhibited inside the one-of-everything
scope, with one barrier kind, one feature and one instrument, so the seam is
separable from the carry policy.

## The eight cases and what each shows

| case | revised cells | shows |
| --- | --- | --- |
| A gap inside barrier | 3 | the seam: 66.58 becomes `NA` once the barrier is knowable |
| B no gap inside barrier | 0 | a barrier with nothing to fill revises nothing |
| C gap before barrier | 0 | a fill whose span misses the barrier is untouched |
| D strict policy, no carry | 0 | the strict policy is cutoff-invariant |
| E age refuses before the barrier | 0 | the age bound and the barrier compose; age dominating leaves nothing to revise |
| F width five | 5 | the forward reach is the feature width |
| G barrier away from the gap | 0 | position matters, not presence |
| H wide barrier, one gap | 3 | reach follows the gap, not the barrier's length |

Every case also reports `stable_on_recompute` true and
`observed_inside_barrier_retained` true, and every case with revisions reports
them inside section 6.1's bound.

## What was learned about the package

**Section 6.1's forward reach is exactly the feature width.** Three revised
cells at width three, five at width five, from a single revised input. The
synthesis derived `W_f - 1` over three review rounds; one run confirms it.

**The strict policy really is cutoff-invariant.** Case D sets the carry age to
zero and nothing revises. Section 6.1 asserts this; it is now executed rather
than argued.

**Section 4.4 holds under carry.** A real observation inside an accepted
inactive interval is retained in the prepared close in every case, so the
barrier stops fabricated values without discarding real ones.

**LFB-012 shapes the fixture, not just the design.** A late-known inactive
interval cannot be layered over an open-ended active assertion, because opposing
assertions may not overlap in effective time. Carving it out instead leaves the
interval absent before its knowledge time, which resolves to `unknown`, and gate
21 leaves `unknown` unrestricted. The causal structure the spike needs therefore
falls out of the existing rules rather than having to be arranged.

**`pkgload::load_all()` dirties the package scope.** It regenerates `R/cpp11.R`
and `src/cpp11.cpp` on every load, by line endings alone. Any spike checker that
guards package scope must revert those or it fails its own guard on a second
consecutive run. The checker does, and says why.

## One gutted path failing

Removing the single barrier check from the carry rule -
`if (any(bar[seq.int(src + 1L, i)])) next` - and rerunning the checker:

```text
FAIL  A_gap_inside_barrier / revised_cells: recorded 3 -> fresh 0
FAIL  F_width_five / revised_cells:         recorded 5 -> fresh 0
FAIL  H_wide_barrier / revised_cells:       recorded 3 -> fresh 0
FAIL  A_gap_inside_barrier / carried_after: recorded 0 -> fresh 1
CHECKER FAILED: evidence row set changed; evidence values drifted
```

The three revising cases collapse to zero and the locality rows disappear,
because without the barrier the carry proceeds at both cutoffs and there is
nothing to revise. The checker catches it on values and on the row set.

## Demoted and deleted

- The first charter's question, sizing a pulse-scaled payload, was **deleted**.
  It presumed the semantic seam settled when the probe had only shown the
  diagonal.
- The lazy preparation arm was **deleted**. It was disqualified by the charter's
  own viability criterion before any measurement.
- Two of the author's own cases were **demoted** during step two. `D` duplicated
  `A` because no bar was dropped differently, and the original `E` set the carry
  age to one against a one-session gap, which discriminates nothing. Both were
  replaced by cases that can fail: the strict policy, and an age bound that
  refuses before the barrier is reached.
- The probe's P3 conclusion, that the payload was the whole question, was
  **withdrawn** rather than deleted, and its arithmetic kept as arithmetic.

## The ablation: universe size and authoring style

Added 2026-09-27 on a maintainer brief. `spike_ablation.R`, 91 evidence rows in
`spike_ablation_evidence.csv`. No clock is reported here either. **Neither kill
condition fired**, and two synthesis claims are now executed rather than argued.

### Block A, authoring style: section 6.1's scope fence is load bearing

Same barrier geometry as case A, varying only the style.

| style | width | revised cells | last revised | inside 6.1's bound |
| --- | --- | --- | --- | --- |
| `rolling_mean` | 3 | 3 | 8 | yes |
| `rolling_max` | 3 | 3 | 8 | yes |
| `rolling_mean` | 5 | 5 | 10 | yes |
| `rolling_max` | 5 | 5 | 10 | yes |
| `ema` | 3 | 17 | 22 | **no** |
| `ema` | 5 | 17 | 22 | **no** |
| `expanding_mean` | 3 | 17 | 22 | **no** |

Three things follow. **The reach is the window, not the reducer:** `rolling_max`
reproduces `rolling_mean` exactly at both widths, so the dependency is the window
and the bound does not care what the window computes. **One revised input revises
`W_f` cells:** three at width three, five at width five, both beginning at
session 6, which is `W_f - 1` forward of the affected input. **The bound holds
with slack:** its limit was session 15 at width three and the last revision was
at 8, because the `A_in` term assumes a carry this geometry does not realise. It
is a bound, not a prediction, as section 6.1 says.

And the fence earns its place. A recursive or expanding style revises every cell
to the end of the axis - 17 of 22, from the first affected session onward - so
`W_f - 1` is not a property of features generally. Section 6.1 already excludes
these; the exclusion is now measured rather than assumed, which matters because
the fitted and multivariate methods this cycle was motivated by sit on that side
of the fence.

### Blocks B and C, universe size: locality holds, and cross-section breaks it

One instrument's barrier becoming knowable, counted over the whole panel.

| universe | per-instrument feature | cross-sectional feature |
| --- | --- | --- |
| 4 | 1 instrument, 3 cells | 4 instruments, 12 cells |
| 40 | 1 instrument, 3 cells | 40 instruments, 120 cells |
| 200 | 1 instrument, 3 cells | 200 instruments, 600 cells |

Section 6.2's locality premise is exact for a per-instrument feature: the revised
set is the barrier's instrument and nothing else at every size, and the revised
cell count does not move with the universe. Under a cross-sectional feature - the
same rolling mean over each instrument's close demeaned by the panel at that
session - every instrument revises and the work is `3N`, linear in the universe.
Section 6.2 states this as a limit in prose; it is a factor of 200 here.

### Blocks D and E, the bias of not revising: it is conserved, not avoided

The synthesis does not ask whether revising earns its cost. These blocks do, by
reading the series the way a run reads it - the value at session `t` - and
comparing the correct behaviour against both available shortcuts:

- **reference**, prepared at `t` for every `t`: the diagonal of the correct
  behaviour;
- **full**, one preparation using every fact in the snapshot, reused at every
  pulse. What a backtester does when it loads today's data. This is lookahead;
- **stale**, one preparation at the run's first cutoff, never revised. This is
  staleness, and carries no lookahead.

**For a rolling window the bias is presence, not magnitude.** Against `full`, the
rolling mean showed 3 biased decisions at width three and 5 at width five, and
every one of them was a *lost* signal: the reference had a value where the
shortcut had none, never the reverse, and the relative difference where both had
values was exactly zero. The mechanism is survivorship, made concrete. Knowing
the suspension refuses the carry, so there is no window, so there is no
indicator, so the strategy does not trade a position the point-in-time run would
have taken and would have had to live with.

**For a recursive or expanding style the bias is permanent and small.** The EMA
biased 12 of 22 decisions but by at most 0.14% and 0.013% on average; the
expanding mean, 12 decisions at most 0.030%. Values are always present, so
nothing is lost or fabricated - the series is simply slightly wrong forever.
Whether 0.14% flips a ranking is a question about a strategy, not about a
feature, and this spike does not answer it.

**The total bias is conserved. The knowledge lag only decides who pays it.** Block
E moves the barrier's knowledge time across the revised range at two widths:

| knowledge session | revised range | history cells | `stale` wrong | `full` wrong |
| --- | --- | --- | --- | --- |
| 7 | 6-8 | 3 | 2 | 1 |
| 8 | 6-8 | 3 | 1 | 2 |
| 9 and later | 6-8 | 3 | 0 | 3 |
| 7 | 6-10 | 5 | 4 | 1 |
| 8 | 6-10 | 5 | 3 | 2 |
| 9 | 6-10 | 5 | 2 | 3 |
| 10 | 6-10 | 5 | 1 | 4 |
| 11 and later | 6-10 | 5 | 0 | 5 |

In all twelve rows `stale + full` equals the history revision exactly. A revised
cell is wrong under `stale` when the run already knew the fact at that session and
wrong under `full` when it did not, and every revised cell is one or the other.
So **no choice of shortcut reduces the total**; the fact's arrival time decides
how it splits.

That yields the practical rule, and it is the opposite of the intuition. **A fact
arriving promptly makes the full-knowledge shortcut nearly correct** and the
never-revised one nearly all wrong. A fact arriving late - a restatement, a
delisting notice filed weeks after the event - is where using today's data bites.
The `stale` shortcut costs nothing on decisions once the fact arrives at least
`W_f` sessions after the affected observation: session 9 at width three and 11 at
width five, both `6 + W_f`, so the crossover tracks the window exactly.

Two consequences for section 6.2's candidate. The diagonal a run consumes is much
cheaper to get right than a history view, because only 2 distinct barrier states
are visited across all 22 cutoffs in every block D case - the segmentation payoff,
measured. And the decision bias and the research bias are different sizes: the
history view revises `W_f` cells per event regardless of lag, while the decisions
lose only the part of that range the run had already passed.

### What the ablation does not establish

**The fixture's barrier density does not scale.** `ledgr_sim_pit_inputs()` places
its cases on instruments 1 to 4, so the sealed store holds two barrier knowledge
times at every universe size, and 198 of 200 instruments have none. That is a
teaching fixture, not a density model. So these rows test section 6.2's
*locality* and say nothing about its *multiplier* - the claim that per-instrument
admissibility facts number "one or two". Reading confirmation of the multiplier
into a fixture that hard-codes two facts would be circular. The real density was
measured separately on the Sharadar lake and belongs in that record.

**The knowledge lag distribution is now partly supplied, and the rest is not
reachable from one capture.** The lags in block E were chosen to cross the
boundary, not sampled. The section below measures the real ones where the vendor
exposes them; what it cannot give is a distribution of late arrivals, because
that needs captures accumulated over months rather than two a day apart.

**No decision or outcome is simulated.** Every number above is a count of cells or
a relative difference in an indicator. Whether a biased indicator changes a
position, and whether that changes a return, needs both views run through the
engine against a strategy. The `full` shortcut losing only *lost* signals suggests
a direction - a backtest that skips positions the point-in-time run would have
taken reports flattered results - but direction is not magnitude, and this spike
measures neither.

### The lags, measured: the revision problem is a fundamentals problem

`lag_measurement.R`, recorded in `lag_measurement_evidence.csv`, against the lake
at acquisitions `20260905T092008Z` and `20260905T092856Z`. Read-only; no
acquisition was run. Not part of the checker's set, because it reads a 15 GB
external path that exists on one machine.

**Two columns that look like knowledge clocks are not.** `firstadded` minus
`firstpricedate` has a median of 4,821 days and 3,076 of 20,961 tickers are
non-positive; `lastupdated` minus `lastpricedate` has a median of 3,366 days for
delisted tickers. Those are vendor onboarding and last-modified stamps, not market
knowledge. Recorded because they are the obvious thing to reach for and the
numbers foreclose it.

**The barrier families as this adapter builds them carry no independent knowledge
clock.** `ACTIONS` has only `date`. **Corrected after review 2026-09-27:** the
decisive evidence is the adapter's explicit assignments, not the `knowledge`
argument, because `assume_effective` in ledgr only fills a knowledge time that is
*missing* (`R/availability-facts.R:1193-1199`). Read at source in
`ledgr-research/packages/ledgr.sharadar/`: lifetime facts assign `knowledge_time`
from the effective clock (`R/lifetime-facts.R:99,113`), and membership snapshots
assign *both* clocks from source availability boundaries with a declared one-day lag
(`R/membership-facts.R:108-120`) rather than preserving an index-effective clock.
Membership intervals are prohibited outright. So neither family presents two
distinct clocks - though for membership that is because both are set to availability,
which is a different representation from lifetime's collapse onto effective.

**At zero lag there is no revision at all.** A barrier that becomes knowable
exactly when it becomes effective can only affect cells at or after its own
effective session - cells no earlier cutoff could have delivered. Nothing already
returned ever changes. Section 6.1's mechanism is "which barriers are knowable at
`t`", and with the two clocks collapsed that set never gains a barrier retroactively.

So block E's split resolves, for price barriers, to its endpoint:

| lag | source | `stale` wrong | `full` wrong |
| --- | --- | --- | --- |
| 0 sessions | the barrier families as this adapter builds them | all of `W_f` | none |
| ~1 session | dividends, from first appearance | `W_f - 1` | 1 |
| -4 sessions | splits, knowable before effective | all of `W_f` | none |
| ~30 sessions | SF1 quarterly filing lag | 0 if `W_f <= 30` | all of `W_f` |

**The direction reverses between the two, and that is the result.** For price
barriers the full-knowledge preparation is not a shortcut at all - it is the
correct answer, and the dangerous implementation is the naive one that prepares
once at the run's start and never revises, which is wrong across the whole window.
For fundamentals it inverts: the SF1 as-reported filing lag is 44 days median and
93 to 101 days at the 95th percentile - about 30 and 64 sessions - so
today's-data preparation is wrong across the entire window of any feature shorter
than about 30 sessions, which is the classic restated-fundamentals lookahead, and
never revising is nearly right.

Sharadar's fundamentals do carry two genuine clocks, and ledgr's snapshot has no
fundamentals table. So the one family that would make revision matter is the one
family ledgr cannot yet store.

**Withdrawn after review: "checkpoint part (d)'s cost does not need paying until a
two-clock source lands."** That conflates a source not exercising an obligation with
the package not owing it. ledgr's public constructors accept an explicit
`knowledge_time`, so late-known facts are constructible through the public API today
regardless of what any adapter supplies, and part (d) stays owed for every supported
carry configuration. What the measurement does support is narrower: part (c) is
default-sensitive by its own text - "default-on means every research run pays
whatever this costs, so it is answered before the default is fixed" - while parts
(a), (b) and (d) are not.

**A thin tail exists and is not measurable from one capture gap.** Across the two
captures 17 hours apart, 72 `tickerchange` rows dated back to 1998 appeared, along
with one restated `delisted` row for a 2002 event at 8,900 days and one
`adrratiosplit` at 270 days. Those are genuine late arrivals - vendor backfill
corrections rather than market knowledge, but they would drive revision if
ingested. One capture gap detects arrivals and cannot estimate a distribution; a
real one needs captures accumulated over months, which is the forward-looking item
already open in the research repo.

### Row coverage and zero-volume sessions, corrected after review

`zero_volume_measurement.R`, recorded in `zero_volume_evidence.csv`. Window
2020-01-01 to 2024-12-31, price and action acquisitions both pinned to
`20260905T092008Z`: 9,448 tickers, 1,258 sessions, and 8,367,777 sessions inside
instrument coverage of which 8,367,776 printed. Read-only.

**Restated at revision 2.** Adversarial review on 2026-09-27 returned this section.
The measurements stand; several of the claims drawn from them did not. What is
withdrawn is marked as withdrawn rather than quietly edited.

**Internal row coverage is almost complete under the stated definitions.** Sessions
inside a ticker's own coverage that carry no row at all: **1**, out of 8,367,777.
Duplicate `(ticker, date)` keys, null OHLC fields and non-positive prices are each
measured at **0**, so the two qualifications that could have let absence hide - keys
that are not unique, and rows present but unusable - do not bite here.

**Withdrawn: "the vendor omits nothing" and "the population is empty."** Coverage is
defined from each ticker's first and last observed print, so leading and trailing
omissions and entirely absent instruments cannot be seen by construction, and a
session absent from the whole panel disappears from a calendar derived from observed
dates. Section 5.1 asked for run lengths of missing expected sessions split across
four lifecycle locations - before the first observation, inside the active span,
inside an accepted inactive interval, after the last observation. This speaks to the
second only, and the run lengths below are of zero-volume rows, a different
population. Section 5.1 also states the query "blocks nothing", so taking it late
was a prioritisation mistake, not a missed gate.

**An association, with no mechanism established.** 270,949 sessions - **3.238% of
the panel**, across 2,735 tickers - are printed with zero recorded volume, and on
**99.32%** of them the close equals the previous close, against a **5.76%** control
for sessions that did trade. That is consistent with vendor imputation, with an
official or reference close published without trading, and with other publication
conventions. This measurement does not distinguish them. **Withdrawn: "the vendor
already carried."**

| Quantity | Sessions | Share of panel |
| --- | --- | --- |
| Absent inside coverage | 1 | 0.00% |
| In zero-volume runs spanning a selected action date (upper envelope) | 861 | 0.010% |
| Beyond an age-20 limit | 13,863 | 0.166% |
| Beyond an age-5 limit | 59,270 | 0.708% |
| In runs longer than 5 sessions | 100,500 | 1.201% |
| Zero recorded volume, all | 270,949 | 3.238% |

**Two numbers were wrong in revision 1.** Sessions *beyond* an age-five limit is
**59,270**, since a seven-session run exceeds an age of five by two and not by
seven; 100,500 is the count *in* such runs and was misreported as the count beyond
the age. And the 861 applies no price-basis rule, no knowledge cutoff, no actual
carry path and no lifecycle barrier, so it is an upper envelope and **not** the set
the proposed controls would govern. The longest unbroken zero-volume run is **663**
sessions.

**The execution-side question, narrowed.** Volume does survive downstream: into the
execution bar and to strategies as `ctx$vec$volume` (`R/fill-model.R:52,86`,
`R/pulse-context.R:229,550`). **Withdrawn: "indistinguishable downstream."** What is
supported is narrower - the built-in cost resolver prices from the open with no
volume gate (`R/cost-model.R:396`), and no default path refuses a fill on a session
with no recorded volume. Section 4.4 separates research-input admission from trading
permission, so this belongs to execution policy and source provenance, and research
admission must not change merely because a price lacks recorded volume.

**One clean negative.** Rows dated after a ticker's terminal action: **0**. The
vendor does not print past a delisting, so the phantom-history worry is refuted.

**What this does not say.** It does not price anything in returns. It does not
establish that a zero-volume close is wrong, nor that it would be unexecutable.
And it is one vendor and one captured vintage, which cannot establish that
default-on lacks benefit across other sources, asset classes, field-level gaps or
ingestion failures.

### The ablation's own gutted path

Removing the cross-sectional coupling - `p <- p - m` in `feat_at()` - collapses
block C onto block B:

```text
FAIL  C_cross_sectional_200 / instruments_revised: recorded 200 -> fresh 1
FAIL  C_cross_sectional_200 / panel_revised_cells: recorded 600 -> fresh 3
FAIL  C_cross_sectional_40  / instruments_revised: recorded 40 -> fresh 1
FAIL  C_cross_sectional_4   / instruments_revised: recorded 4 -> fresh 1
CHECKER FAILED: evidence values drifted
```

So the panel-wide revision is caused by the coupling and not by universe size in
itself, and block B is the control that shows it.

### Harness note

The fixture and candidate moved to `spike_core.R`, shared by the runner and the
ablation. The extraction is proved behaviour preserving by the checker: the
runner's 49 recorded rows reproduce unchanged. The checker now gates both parts,
272 rows in total.

## What remains open

Four things this spike does not answer, stated so the closeout does not
overclaim.

**The engine does none of this.** The candidate is standalone code in this
directory. It shows the seam exists and is separable; it does not show that
ledgr's hydration path can produce it.

**Nothing is costed, and the lag measurement says it need not be yet.** No clock
is reported, deliberately: the charter asks for no cost number. What eager
preparation costs against a declared workload and memory envelope still needs its
own charter with those quantities stated. But the measured lags put that charter
behind a data prerequisite rather than in front of it: every barrier ledgr can
build from Sharadar has knowable equal to effective, so nothing revises, and the
cost of revising is not yet a cost anyone pays. The charter becomes due when a
two-clock source lands, which the same measurement says will be fundamentals.

**Output carry.** Whether a forbidden output carry falls out of the same seam is
untested. It was named in the charter as expected to remain open, and still is.

**Cross-sectional features are now measured, not answered.** The ablation shows
the locality breaks and by how much - every instrument revises, work linear in the
universe. It does not say what a correct cross-sectional preparation looks like,
and the `3N` figure is a revision count on a 22-session axis, not a cost. What it
settles is that the per-instrument candidate in section 6.2 cannot be extended to
these features by assuming its locality still holds.
