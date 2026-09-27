# Spike closeout: the late-known barrier revision seam

**Verdict: green on the charter's question, and the charter's question turned out
not to be the one that matters.** The kill condition decides the first half: the
revision was exhibited inside the one-of-everything scope with one barrier kind,
one feature and one instrument, so the seam is separable from the carry policy.
The second half is not a charter clause at all - it comes from the measurements the
charter's own weakest item asked for, taken afterwards.

Branch `spike/segmented-feature-views`, `b686984..592da01` from `0cf20e7`.
Artifacts in `dev/spikes/segmented-feature-views/`.

## What ran

Six commits, four questions, three evidence sets, all rerunnable except the two
that read an external lake.

| Artifact | What it does | Evidence |
| --- | --- | --- |
| `probe.R` | establishes P1-P5 by execution before any prose | `probe_evidence.csv` |
| `spike_runner.R` | eight cases on the seam, shared fixture in `spike_core.R` | `spike_evidence.csv`, 49 rows |
| `spike_ablation.R` | blocks A-E: authoring style, universe size, bias of not revising | `spike_ablation_evidence.csv`, 223 rows |
| `spike_checker.R` | scope guard, rerun, diff, over both parts | 272 rows reproduce |
| `lag_measurement.R` | the empirical knowledge lags | `lag_measurement_evidence.csv` |
| `vendor_carry_measurement.R` | the magnitude, on 8.37M instrument-sessions | `vendor_carry_evidence.csv` |

Harness 1,289 lines of R against the 1,500 budget. Charter 166 lines against 150,
a deliberate overrun recorded in its own commit. Nothing in `R/`, `src/`, `tests/`,
`man/`, `NAMESPACE` or `DESCRIPTION` changed, enforced by the checker's scope guard.

Two gutted paths fail as they should: removing the barrier check collapses the
three revising cases to zero, and removing the cross-sectional coupling collapses
block C onto block B.

## What was learned about the package

**Section 6.1's bound holds, and its scope fence is load bearing.** A finite window
revises exactly `W_f` cells from one revised input, and `rolling_max` reproduces
`rolling_mean` exactly, so the reach is the window and not the reducer. A recursive
or expanding style revises to the end of the axis, outside the bound. The fence is
measured, not assumed.

**Section 6.2's locality is exact for per-instrument features and fails by a factor
of the universe for cross-sectional ones.** One instrument and 3 cells at universes
of 4, 40 and 200; every instrument and `3N` cells when the feature reads the panel.

**The bias of not revising is conserved.** Across twelve lag positions at two
widths, the never-revised shortcut's errors plus the full-knowledge shortcut's
errors equal the history revision exactly. No choice of shortcut reduces the total;
the fact's arrival time only decides who pays. The never-revised shortcut is free
on decisions once the fact arrives `W_f` sessions after the affected observation.

**`pkgload::load_all()` dirties package scope** by regenerating the cpp11
registration on every load. Any spike checker guarding scope must revert those two
files or it fails its own guard on a second run.

**LFB-012 shapes fixtures, not only designs.** A late-known inactive interval
cannot be layered over an open-ended active assertion, so it must be carved.

## What the spec may consume

Stated as proposals for the cycle. None is a decision this closeout can make, and
the last one challenges an accepted document.

1. **The bound and the fence can be cited as measured** rather than derived, and
   the cross-sectional factor of `N` can be stated as a number in section 6.2's
   limits paragraph.

2. **Checkpoint part (d) moves behind a data prerequisite.** Every carry barrier
   ledgr can build from Sharadar has knowable equal to effective, because `ACTIONS`
   carries no evidence column and `assume_effective` sets `knowledge_time` to
   `effective_from`. At zero lag nothing revises. The cost charter becomes due when
   a two-clock source lands, and the only genuine two-clock family measured is SF1
   fundamentals at a 44-day median filing lag, which ledgr's snapshot cannot store.

3. **The carry-age default's justifying measurement came back empty.** Section 5.1
   names the age-5 default "the weakest-supported item in this document" and names
   the measurement that should set it: the run-length distribution of missing
   expected sessions. Measured over 2020-2024, 9,448 tickers, 8,367,776
   instrument-sessions: **1** missing expected session. The vendor omits nothing.

4. **A default flip is therefore worth considering, and needs a Type 2 round.**
   Section 6.1 makes the strict policy cutoff-invariant and states that cutoff
   dependence arrives with carry. So carry-on is the root of section 6's revision
   obligations. With carry default-off those obligations become conditional rather
   than owed, and the shipped engine is already strict, so this is a decision not
   to add rather than a removal. The carry policy should survive as opt-in, because
   a source that genuinely omits sessions still needs it.

5. **The larger effect is a section 4 question, not a section 6 one.** 3.24% of the
   panel - 270,949 sessions across 2,735 tickers - is printed with zero volume, and
   99.32% of those repeat the previous close against a 5.76% control. 100,500 of
   them sit in runs longer than five sessions; the longest run is 663. Section 4.4
   admits observations unconditionally and no fill path gates on volume, so a
   carried price and a traded price are indistinguishable downstream. The controls
   under design govern 861 sessions of the same phenomenon.

## What remains open

**The engine does none of this.** The candidate is standalone code in this
directory. It shows the seam exists and is separable; it does not show ledgr's
hydration path can produce it.

**Nothing is costed**, deliberately, and proposal 2 says the charter is not yet due.

**Output carry** is untested, as the charter expected.

**Cross-sectional preparation** is measured as broken, not designed.

**One assumption behind proposal 2 was not verified at the adapter.** That Sharadar
ingest declares `assume_effective` is taken from the research repo's record, not
from adapter source read here. The lag-zero conclusion rests on it.

**The late-arrival tail is detected, not sized.** Rows dated 1998 appeared between
two captures 17 hours apart. A distribution needs captures over months.

**Three questions on one charter** is the process smell this spike carries. It was
capped in writing rather than split, and a fourth would have required its own
charter.
