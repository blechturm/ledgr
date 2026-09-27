# Spike inventory: the late-known barrier revision seam

**Ran:** 2026-09-27, branch `spike/segmented-feature-views` from `0cf20e7`.
**Charter:** `charter.md`. **Probe:** `probe_findings.md`. **Evidence:**
`spike_evidence.csv`, 49 rows, all derived from the sealed store or from the
candidate's own resolution. No row is a narrated literal.

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

## What remains open

Three things this spike does not answer, stated so the closeout does not
overclaim.

**The engine does none of this.** The candidate is standalone code in this
directory. It shows the seam exists and is separable; it does not show that
ledgr's hydration path can produce it.

**Nothing is costed.** No clock is reported, deliberately: the charter asks for
no cost number. What eager preparation costs against a declared workload and
memory envelope needs its own charter with those quantities stated, which is the
question this spike unblocks.

**Cross-sectional features and output carry.** The locality that makes the reach
bounded depends on per-instrument independence, which a feature reading across
instruments breaks. And whether a forbidden output carry falls out of the same
seam is untested. Both were named in the charter as expected to remain open.
