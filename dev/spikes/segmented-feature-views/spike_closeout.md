# Spike closeout: the late-known barrier revision seam

**Verdict: green on the charter's question.** The kill condition decides it: the
revision was exhibited inside the one-of-everything scope with one barrier kind,
one feature and one instrument, so the seam is separable from the carry policy.

The data findings that followed were **returned for correction** in adversarial
review on 2026-09-27 and are restated below at the strength the evidence carries.
Two defects in the harness were found by that review and are fixed. Revision 2.

Branch `spike/segmented-feature-views`, from `0cf20e7`. Artifacts in
`dev/spikes/segmented-feature-views/`.

## What ran

| Artifact | What it does | Evidence |
| --- | --- | --- |
| `probe.R` | establishes P1-P5 by execution before any prose | `probe_evidence.csv` |
| `spike_runner.R` | eight cases on the seam, fixture in `spike_core.R` | `spike_evidence.csv`, 49 rows |
| `spike_ablation.R` | blocks A-E: authoring style, universe size, bias of not revising | `spike_ablation_evidence.csv`, 223 rows |
| `spike_checker.R` | scope guard, rerun, diff, over both parts | 272 rows reproduce |
| `lag_measurement.R` | the knowledge lags the vendor exposes | `lag_measurement_evidence.csv` |
| `zero_volume_measurement.R` | row coverage and zero-volume sessions | `zero_volume_evidence.csv` |

Harness 1,320 lines of R against the 1,500 budget. Charter 166 lines against 150:
an overrun recorded as deliberate, which review correctly notes trips protocol
section 8, and recording it is not the same as the maintainer accepting it. Three
questions on one charter likewise conflicts with section 2. Neither invalidates the
observations, and neither is protocol compliance.

Two gutted paths fail as they should: removing the barrier check collapses the
three revising cases to zero, and removing the cross-sectional coupling collapses
block C onto block B.

## What was learned about the package

**Section 6.1's bound is corroborated by the fixtures, not replaced by them.** A
finite window revises exactly `W_f` cells from one revised input, and `rolling_max`
reproduces `rolling_mean` exactly, so the reach follows the window and not the
reducer. A recursive or expanding style revises to the end of the axis, outside the
bound, so section 6.1's scope fence is load bearing. The derivation still carries
the generality; the fixtures show it holds where they reach.

**Section 6.2's locality is exact for per-instrument features and breaks for a
panel-dependent one.** One instrument and 3 cells at universes of 4, 40 and 200;
every instrument and `3N` cells when each instrument's value is demeaned by the
panel. `3N` is that feature's cost, not a universal cross-sectional multiplier.

**The mismatched cells partition between the two shortcuts.** Across twelve lag
positions at two widths, the never-revised shortcut's wrong cells plus the
full-knowledge shortcut's wrong cells equal the history revision exactly. That is a
partition of mismatching cells in these fixtures. It is not conserved economic
harm, which nothing here measures.

**`pkgload::load_all()` dirties package scope** by regenerating the cpp11
registration on every load.

**A scope guard on working-tree status proves less than it appears to**, because
committing an edit passes it. The checker now also diffs the committed range
against a base, and that check independently confirms no package file changed since
`0cf20e7`.

**An unconditional `git checkout --` in a checker is a hazard.** The previous
revision reverted the two load artifacts whether or not the author had edits there,
which would have discarded real work. It now reverts only if they were clean before
the rerun, and says when it skips.

**LFB-012 shapes fixtures, not only designs.** A late-known inactive interval
cannot be layered over an open-ended active assertion, so it must be carved.

## What the spec may consume

Proposals for the cycle, restated after review. None is a decision this closeout
can make.

1. **Cite the bound and the fence as corroborated.** Section 6.2's limits paragraph
   can state a measured factor for the panel-demeaned feature, named as that
   feature's cost.

2. **This source does not exercise revision; that does not discharge the
   obligation.** Verified at adapter source: lifetime facts assign `knowledge_time`
   from the effective clock, and membership snapshots assign both clocks from source
   availability boundaries with a declared one-day lag, so neither family carries an
   independent knowledge clock. But `assume_effective` only fills a *missing*
   knowledge time, and ledgr's public constructors already accept an explicit one,
   so late-known facts are constructible today. Checkpoint part (d) is therefore
   **not** generally postponed; review rejected that and the rejection is accepted.
   What the measurement supports is narrower: part (c) is default-sensitive by its
   own text, which says "default-on means every research run pays whatever this
   costs, so it is answered before the default is fixed." Parts (a), (b) and (d) are
   not default-sensitive and remain owed.

3. **Report the coverage measurement at its actual strength.** Supported: *this
   captured vintage has almost complete internal row coverage under the stated
   definitions* - 1 absent session in 8,367,777 inside coverage, with duplicate
   keys, null OHLC and non-positive prices all measured at zero, so those
   qualifications do not bite. Withdrawn: "the vendor omits nothing" and "the
   population is empty." Section 5.1 asked for run lengths of missing expected
   sessions across four lifecycle locations; defining coverage from observed
   endpoints makes the first and fourth unmeasurable by construction, and the run
   lengths reported here are of zero-volume rows, a different population. Section
   5.1 also states the query "blocks nothing", so the sequencing was a
   prioritisation mistake and not a missed gate.

4. **Default-off is defensible as a product judgment, and does not retire the
   obligation.** Withdrawn: that section 6's obligations become "conditional rather
   than owed". Correct statement: conditional at runtime, still owed for every
   supported configuration. Output carry creates the dependency independently of
   price-input carry, so flipping one default would not remove it. The supportable
   rationale is that automatic imputation should require demonstrated benefit and
   that users can elect a disclosed treatment, which stands without claiming this
   vintage represents every source. Deferring checkpoint (d) needs an explicit
   deferral or restriction of the carry capability, not a default change. Review
   traced sections 5.4 to 5.7 and section 7 as largely surviving the flip; sections
   1, 5.3, 6.3 and 10(c) carry statements presuming input carry is normally active
   and would need revising.

5. **Open a separate source-provenance and execution-policy item.** 270,949
   sessions, 3.238% of the panel across 2,735 tickers, print with zero recorded
   volume, and 99.32% of those repeat the previous close against a 5.76% control.
   That association is consistent with vendor imputation, with an official close
   published without trading, and with other conventions; the measurement does not
   distinguish them and no longer claims to. Withdrawn: "the vendor already
   carried", and "indistinguishable downstream", since volume survives into
   `ctx$vec$volume` and the execution bar. Supported and narrower: the built-in cost
   resolver prices from the open with no volume gate (`R/cost-model.R:396`), so an
   execution-side policy question exists. Section 4.4 separates research-input
   admission from trading permission, so research admission must not change merely
   because a price lacks recorded volume.

   Two numbers in the previous revision were wrong and are corrected. Sessions
   *beyond* an age-five limit is **59,270**, 0.708% of the panel, not the 100,500
   that sit *in* runs longer than five. And the 861 sessions in runs spanning a
   selected action date apply no price-basis rule, knowledge cutoff, carry path or
   lifecycle barrier, so they are an upper envelope and not the set the proposed
   controls would govern.

## What remains open

**The engine does none of this.** The candidate is standalone code in this
directory.

**Nothing is costed**, deliberately.

**Output carry** is untested.

**Cross-sectional preparation** is measured as broken for one feature, not designed.

**Two coverage qualifications remain unquantified.** A session absent from the whole
panel disappears from a calendar derived from observed dates, and coverage defined
by observed endpoints cannot see leading or trailing omissions or an entirely absent
instrument. Closing them needs a declared venue calendar and instrument population,
which is section 5.1's query rather than this spike.

**Section 5.1's actual request is unanswered.** Three of its four lifecycle
locations, and the missing-session population itself, are not measured here.

**The zero-volume mechanism is a hypothesis.** Distinguishing vendor imputation from
a published official close needs vendor documentation or a second source.

**The late-arrival tail is detected, not sized.** Rows dated 1998 appeared between
two captures 17 hours apart; a distribution needs captures over months.

**One provenance defect is fixed, and worth recording as a pattern.** The previous
revision paired a pinned price acquisition with an unrecorded `max(acquisition_id)`
for actions, so its action-side numbers were not reproducible. Both are now pinned
and recorded.

**One review claim is not adopted as stated.** Review corrects a calendar
justification citing an announcement published 2018-12-04 rather than 2018-01-01. No
announcement was cited here; the claim made was that a constant knowledge time is
honest for a calendar published in advance. That claim was itself unverified and is
withdrawn, which reaches the same place by a different route.
