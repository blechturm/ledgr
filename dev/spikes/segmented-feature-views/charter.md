# Spike charter: segmented feature views

**Status:** Draft for maintainer ownership. Binds nothing. Authorizes no
production change, no spec packet, and no second execution path.
**Governs:** `../../../inst/design/spike_protocol.md`, which supersedes anything
here that conflicts with it.
**Feeds:** checkpoint part (d) of
`../../../inst/design/rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v10.md`
(accepted 2026-09-27).
**Probe:** `probe.R`, findings in `probe_findings.md`, evidence in
`probe_evidence.csv`, run 2026-09-27. Every claim below was executed or is cited
from `contracts.md`.

## The prerequisite question, already answered

*Does per-instrument segmentation of knowledge-dependent state work at all?*

**Yes, and it ships.** The prepared availability provider compiles canonical
facts once before the fold into per-instrument piecewise-constant segments in a
flat CSR layout, one cursor per instrument, advancing vectorised for a
non-decreasing cutoff and re-seeking by `cumsum` for a decreasing one
(`R/availability-provider-prepared.R:5-19`, `:99-131`, `:143-160`). A bounded
fact whose knowledge time falls after its effective time resolves causally
through the public surface: probe P1 shows the halt unrestricted at its
effective instant and restricted at its knowledge instant with reason
`trading_halted`.

So this spike does not ask whether the shape works. It asks whether the shape
survives a different payload.

## The one question

> Does per-instrument segmented preparation remain viable when a segment
> carries a feature series rather than a handful of resolved codes?

Viable means both of: total prepared storage stays bounded at research scale,
and no recomputation happens per pulse.

The question exists because the two quantities scale differently, which the
probe measured. The fact segment store is independent of the pulse axis - 960
bytes for four instruments and twenty boundaries. A feature plane is instruments
times pulses times eight bytes. A segmented feature view holds one plane per
segment, so its storage grows as segments times instruments times pulses times
features while the store it is modelled on grows as instruments times
boundaries.

## Kill condition

The spike stops and recharters if no schedule satisfies both halves at the
target shape: if eager preparation of all segments exceeds the memory an
ordinary research machine has, and lazy preparation cannot avoid computing
inside the fold. A single schedule that satisfies one half while failing the
other is a red outcome, not a partial pass.

## Exactly two alternatives

Protocol section 8 returns a charter comparing more than two. The two are:

1. **Eager**: compile every segment's feature payload before the fold.
2. **Lazy**: compile a segment's payload when the fold first reaches it.

Banding, whole-series recomputation and any hybrid are out of scope here. The
synthesis already sequences banding behind a measured whole-series cost, and
measuring a third alternative before this question is answered is what the
protocol forbids.

## Fixture

`ledgr_sim_pit_inputs()`, which the probe exercised. Case placement is fixed:
one halt on instrument 2, one delisting on instrument 1, one missing observation
on instrument 4, regardless of how many instruments are requested. So event
density is varied by composing several bundles, not by scaling one. The spike
states the composition it used and why.

No new generator, no generator refactor. If the fixed placement turns out to be
what blocks the measurement, that is a finding for the closeout and a reason to
extend the generator afterwards, not a task inside this spike.

## Clocks

Protocol section 10 applies, because the question reaches both boundaries.
Report separately:

- **cold end to end**: source inputs through the prepared feature views;
- **warm research iteration**: from an existing unchanged verified snapshot
  through the same views.

Any preparation rebuilt per experiment belongs to the warm clock whatever it is
called. If the harness cannot isolate reusable snapshot preparation, it reports
the cold clock plus phase timings and labels the warm number incomplete. The
package carries no prepare-phase clock, so phase timing comes from the harness;
the closeout says so rather than implying package telemetry.

## Deliverables

Protocol section 6, exactly three:

- a runner that writes evidence CSVs;
- a checker that reruns into a scratch directory, diffs against the recorded
  CSVs, and guards package scope (`R`, `src`, `tests`, `NAMESPACE`,
  `DESCRIPTION`, `man`, `inst/design`);
- an inventory showing one gutted path failing, and listing what was demoted,
  deleted, and learned about the package.

Counts of passes are not evidence. A row is evidence only if the fork derived it
from provider facts; any row narrated as a literal is labelled and excluded.

## Test cases

At most ten, and none written before a fork exists that can fail it. The order
is the protocol's: smallest runnable fork with one seam, run it, let its
failures generate the cases, then freeze expected answers in git with the
reviewer named in the commit message. A case the fork cannot fail is a policy
sentence for the synthesis, not a test.

## Boundaries

- The throwaway knowledge-dependent rule this spike needs in order to have
  anything to segment is **throwaway**. It is not a first draft of
  instrument-narrowed expected sessions, which is scheduled for the next release
  on its own recorded reasoning, and it must not be promoted into one.
- No hash ledger, registry, first-appearance record, gate mode or provenance
  machinery. Git is the ledger. Identity claims use ledgr's own primitives, or
  are labelled `proto:` once.
- Structural numbers from the small fixture never appear in a ranking.
- Nothing in `R/`, `src/`, `tests/`, `man/`, `NAMESPACE` or `DESCRIPTION`
  changes.

## Terminal outcome

One page. What ran, what was learned about the package, what the synthesis may
consume, what remains open. Green, red or inconclusive in one sentence naming
the charter clause that decides it.

Two questions the charter expects to remain open afterwards, so the closeout
does not overclaim: what happens when a feature reads across instruments, since
the cost argument depends on per-instrument locality that cross-sectional
features break; and whether a forbidden output carry is handled by the same
segmentation.
