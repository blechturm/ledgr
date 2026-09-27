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

**The knowledge lag distribution is the missing input, and it is measurable.**
Block E shows the bias splits by how late a fact arrives, so the size of the real
bias is that split applied to the lags a data vendor actually delivers. The lags
here were chosen to cross the boundary, not sampled from anything. Sharadar
carries the clocks needed to measure the real distribution, which makes this the
one open quantity that needs no new machinery to answer.

**No decision or outcome is simulated.** Every number above is a count of cells or
a relative difference in an indicator. Whether a biased indicator changes a
position, and whether that changes a return, needs both views run through the
engine against a strategy. The `full` shortcut losing only *lost* signals suggests
a direction - a backtest that skips positions the point-in-time run would have
taken reports flattered results - but direction is not magnitude, and this spike
measures neither.

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

**Nothing is costed.** No clock is reported, deliberately: the charter asks for
no cost number. What eager preparation costs against a declared workload and
memory envelope needs its own charter with those quantities stated, which is the
question this spike unblocks.

**Output carry.** Whether a forbidden output carry falls out of the same seam is
untested. It was named in the charter as expected to remain open, and still is.

**Cross-sectional features are now measured, not answered.** The ablation shows
the locality breaks and by how much - every instrument revises, work linear in the
universe. It does not say what a correct cross-sectional preparation looks like,
and the `3N` figure is a revision count on a 22-session axis, not a cost. What it
settles is that the per-instrument candidate in section 6.2 cannot be extended to
these features by assuming its locality still holds.
