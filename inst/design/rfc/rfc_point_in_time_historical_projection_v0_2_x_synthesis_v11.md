# RFC Synthesis v11: Point-in-Time Historical Projection With Missing Data

**Status:** **Accepted by the maintainer 2026-09-28.** Operative synthesis; it
replaces v10, which becomes part of the derivation and correction record. The
simplification direction is authorized. This document still authorizes no
implementation or spike: section 7 governs the next-release ticket cut.
**Mode:** Decision synthesis. **Author:** Codex, at maintainer request; this
departs from the earlier author rotation.
**Final verification:** Claude's Type 1 review of `8c3e1aa` on 2026-09-28
returned PASS with two low-severity findings, corrected here: F1 distinguishes
full snapshots from small controls; F2 gives evidence preservation an owner at
ticket cut. The review checked the reported figures against local evidence CSVs;
no new package or source-data execution is claimed. The section 7 preservation
obligation is **discharged**: the report, six scripts, six evidence CSVs and a
provenance README are committed at `412f600` on `spike/segmented-feature-views`,
under `dev/spikes/revision-exposure/`.
**Basis:** Accepted [v10][v10] and the [missingness amendment][amendment].
Original baselines: design `491c4ed`, implementation `ae040e7`. Current reading
baseline: `d7c6d7f4c80c36d4f6b1c4ac88bfa9a4fe4afa80`. No package code was executed.

## 1. Decision and scope

Ship historical prices and indicator values suitable for statistical and ML
consumers, with simple declared carry-forward and aligned missingness evidence.
Keep the simulated decision-time information bound and one execution fold.
Prepare values and evidence before execution; expose bounded indexed reads.

Use ordinary prepared series wherever they answer the request correctly.
Straightforward whole-series recalculation during preparation is the baseline
candidate when a supported policy requires different historical values at a
different cutoff. No requirement to store a series per knowledge segment, build
an invalidation graph, or implement partial updates follows from that rule.

The empirical investigation supports deferring those optimizations for the
assessed workloads. It does not remove correctness obligations for supported
inputs, turn carry off, defer its opt-in form, or drop missingness disclosure.
Fitted imputers and general model lifecycle remain separate design work.

Accepted 2026-09-28, this document replaces v10 as the immediate synthesis. Earlier
artifacts remain the reasoning and correction record; their superseded
architecture and sequencing clauses do not add obligations to this document.
The checkpoint disposition in section 7 is exhaustive.

## 2. Evidence and the decision it supports

The committed [semantic spike][spike] exhibits a late-known barrier changing a
feature value in a throwaway preparation path. Its finite-window fixtures
corroborate bounded propagation; recursive and panel-dependent fixtures show
why that bound cannot be generalized. It does not establish production cost,
output-carry completeness, or the need for segmented numerical storage. Its
recorded charter deviations remain deviations, not protocol compliance.

The subsequent exposure investigation was reported to the maintainer on
2026-09-27 at `dev/spikes/revision-exposure/revision_exposure_report.md`, with
seven scripts and seven evidence CSVs. They were untracked and are unavailable
at this document's reading baseline. Originally maintainer-supplied, these
figures were subsequently checked against the local evidence CSVs in Claude's
Type 1 review. This rewrite did not rerun the investigation; preservation of
its report, scripts and CSVs remains an explicit section 7 obligation:

| Investigation | Reported result | Supported inference |
| --- | --- | --- |
| Fourteen built baselines, 2019-2021 | Ten snapshots each with 562 instruments and 413,532 bars; four controls each with 5 instruments and 100 bars; 224,732 facts across all fourteen, with no encoded positive knowledge lag | Describes the adapter's constructed clocks, not observed publication timing |
| Declared calendar and active spans | 127,875 expected sessions, zero absent; spans cover 175 instruments, with no span assumed for the other 387 | No missing-session run length to tune carry age in this declared subset |
| Comparable source captures, 17 hours apart | A terminal-date correction for FDMLQ, from 2007-12-27 to 2002-04-24 | A source correction exists; its timing and consequences need attribution |
| That correction traced through prices and indicators | No absent cells affected by carry; the final bar changes one indicator cell at each tested width, 5, 20, 60 and 200; FDMLQ occurs in none of the fourteen workloads | Zero affected intended requests from the attributed correction |
| Completed baseline execution | All 10,486 actual fills matched to their execution bars; zero on zero-volume bars | Zero realised exposure to that execution-policy issue in these runs |

Source comparisons used multiset semantics because event keys were not unique;
date corrections appear as removed and added keys. The fill join used civil
dates because execution opens and bar closes have different timestamps; all
matched fill prices equalled the corresponding open in this US-equity sample.

These results justify closing this investigation for the assessed workloads
and deferring additional optimization machinery. They do not establish zero
historical late arrival in the source, a future revision rate, or safety for
every strategy. `assume_effective` is an assumption, not observed zero lag.
The capture interval bounds a vendor-table change, not first market knowledge.
Preserve the local report and its evidence when integrating this successor;
do not replace that provenance step with another experiment.

Zero recorded volume is a separate execution-policy question. Repeated prices
do not establish vendor carry. Research admission, execution permission and
valuation are separate authorities; these results require no observation-schema
change. The existing liquidity/capacity roadmap item remains the appropriate
route, without becoming a historical-projection prerequisite.

## 3. Information, shape and ownership

For a request at simulated decision pulse `t`, each historical column `s <= t`
uses evidence knowable at `t` and applicable at `s`. Seal time and wall-clock
time are never substitutes. A later-known fact effective at `s` is included
once knowable at `t`; a fact first knowable after `t` is excluded, including
from errors and treatment decisions. Family precedence, completeness and
supersession retain their existing authority. No second resolver is invented.

[Direction 5.4][shape] remains the public lookback contract: `ctx$window()`
reads one feature per call into an `n_inst x lookback` numeric matrix, rows in
the invoking `ctx$universe` order and columns oldest to current. Columns count
consecutive prepared decision pulses, not each asset's last non-missing rows.
Early requests have leading `NA_real_` columns; an empty axis is `0 x lookback`.
The current decision axis includes held nonmembers as the contracts require.
Membership at a past column does not itself exclude an admissible observation.
No list return, multi-feature tensor, second warm-up rule or hidden fetch of
pre-range history is introduced. Declared hydration may supply a carry seed
without expanding the public axis. Raw-price and companion-evidence delivery
must preserve this alignment; their exact surface is a packet decision.

The engine may retain the complete prepared dataset. Supported context reads
enforce the invoking pulse and permitted axis. A declared maximum lookback is
not a causality requirement, and deliberate R reflection is outside the access
guarantee. The projection remains the numerical owner; no lower projector or
automatic full-panel long materialization is introduced. Cut 13's context
surface contract must include the new reader and any evidence surface.

Historical `held`, `priced`, `mark_age` and trading state are not replayed.
History supports estimation; explain supports retained run evidence. There is
no second replay mode, on scope grounds. Equal-cutoff, equal-policy scalar,
window and supported export reads agree. Later-cutoff views may differ from an
earlier decision's value without rewriting that decision.

## 4. Session axis and independent release work

Current feature hydration uses venue open sessions. The current-release repair
has owners, LDG-2866 and LDG-2867, in the existing packet. They document and
pin that behavior without changing the engine. Their status must be read from
the integrating release branch; this rewrite neither closes nor reopens them.
The historical v0.2.0.0 packet and availability gate 21 remain historical
records, with supersession recorded through that repair.

V10's accepted next-release goal of instrument-narrowed expected sessions
remains separately scheduled. This rewrite does not cancel it. If narrowing
ships, its window composition is resolved at the request cutoff and its
outputs are aligned back to the common public column axis. Its interaction
with observations inside inactive intervals must be settled explicitly in
that work; the current fixed-axis policy admits those observations. No window
may silently choose between the two meanings.

Strict values are cutoff-invariant only with fixed admitted observations, a
fixed feature axis and no knowledge-dependent treatment. Narrowing can change
historical values even when both carry operations are off. Its implementation
must satisfy section 7(d); the carry-locality bound is not its proof. Numerical
correctness remains required, but segmented or incremental storage is not a
prerequisite for narrowing. The recorded axis reasoning remains available.

## 5. The simple missing-data policy

These retain the accepted product defaults. Preparation is explicit and occurs
outside indicator callbacks and the execution fold. It never creates observed
bars, membership, trading permission, valuation marks or execution prices.

- **Price-input carry:** on by default, switchable off, with a required declared
  maximum age defaulting to five venue open sessions. OHLC fields each use
  their own latest admissible earlier source from the same stable instrument.
  No cross-field synthesis; volume never carries.
- **Indicator-output carry:** off by default, independently available on with
  a declared maximum age. It follows input treatment and calculation. Disabling
  one operation never enables the other.
- **Age:** count venue open sessions from the carried value's original source
  time to the delivered column. Repeated carry never refreshes age. No source
  later than the destination may fill it, even if known at the request cutoff.
  No leading value is invented. Closed weekends and holidays contribute no
  padded session or lookback count; the declared calendar is the authority.
- **Admission and readiness:** indicators declare required input fields;
  admission tests exactly those fields before calculation. Readiness is
  evaluated on prepared inputs, with no engine threshold on carried share.
  Input admission, readiness, calculation validity and output carry are
  separate stages. Invalid calculations retain their error handling.
- **Fillable output:** only missing because a required input was unavailable
  after input treatment, after declared readiness, with an admissible earlier
  output. Warm-up, unsatisfied readiness, errors and unsupported computations
  never become fillable gaps. An `NA` alone does not establish the cause.

Five sessions remains a declared product default, not an empirically optimized
number. The measured absence distribution does not establish its benefit or
optimality. The bound limits age, not error size or the informativeness of a
gap. Expiry returns `NA`; carry does not promise an entirely finite ML matrix.
Any further filtering or fitted imputation stays a disclosed consumer choice.

### Carry barriers

Both carry operations obey the same barriers, resolved using facts knowable at
the request cutoff. Test the entire source-to-destination path, not just the
destination's membership in an interval:

1. An accepted `known_inactive` interval prohibits carry across it.
2. With **undeclared price basis**, any knowable corporate action contributes
   a barrier at the first venue open session at or after **each** supplied
   entitlement or effective clock. Retain both when distinct; neither payment
   nor knowledge time locates a barrier. With a declared `split_adjusted`
   basis, corporate actions introduce no barrier under this accepted policy;
   `distribution_adjusted` remains refused for execution. A distribution under
   the supported basis is a real price move; allowing carry is a product
   choice, not an accuracy guarantee. No subtype taxonomy is added.
3. A knowable terminal assertion permanently prohibits carry from its terminal
   boundary onward. Later real observations remain admissible under the
   fixed-axis policy, but never restart carry after that boundary.

An unlocatable corporate action, with neither event clock supplied, fails with
a classed condition naming the fact only when it is knowable, the basis is
undeclared and at least one carry operation is enabled. Preparation may record
that outcome in advance; it must not make an earlier cutoff fail. Neither
strict policy nor a declared basis triggers that carry-specific failure.

After a nonterminal barrier, a new real observation may supply later carry if
its path crosses no remaining barrier. An intervening observation between two
corporate-action boundaries does not erase the later boundary. Actual admitted
observations are preserved; restrictions on treatment do not quarantine them.

### Disclosure and future extension

Alongside values, aligned to IDs, columns, policy and cutoff, provide original
and remaining missingness, direct carry versus calculation from treated inputs,
source time and age, warm-up versus later gaps, and applicable supported reasons.
For finite windows provide the count and share of required inputs carried.
No second indicator series is required merely to manufacture a flag, and no
universal usable/not-usable flag excludes consumers that handle native `NA`.

Keep source values, transformations and consumption separate. Treatment order,
parameters, implementation version, information bounds and axis semantics
participate in existing identity and cache machinery. A strict artifact cannot
satisfy a padded request. A later view cannot overwrite a retained result.
Future fitted transforms must be able to use original missingness and a
training-only fitting scope; no transformation DAG, registry or fitted-model
store is required here. Fitted algorithm choice remains model/adapter-owned.

## 6. Preparation without mandatory revision machinery

The baseline is one ordinary prepared series wherever its values can be reused
correctly. Filter and resolve historical evidence at `(s, t)` through prepared
indexes under the existing fact authority. Keep both clocks available: the
existing diagonal `pmax(effective_from, knowledge_time)` segment start alone
cannot answer this historical query. That is an access-representation need,
not a requirement to version every numerical series.

Where a supported policy changes historical inputs or outputs with knowledge,
prepare the needed cutoff-correct answers using the simplest adequate method.
Recalculating a complete affected series is permitted; it needs no exact output
band. Evidence may change while numbers do not. One view may be reused whenever
the requested values are invariant; fact arrival alone is not a mandate for a
new numerical copy. The minimal dependency identification needed for correct
reuse remains work; this document claims neither that it is free nor that a
whole-series callback is already vectorized.

Preparation stays before the fold. Retrieval may slice prepared values and
advance or re-seek indexes. It may not issue per-callback history SQL, rebuild
fact segments or recompute a whole panel at each pulse. The shared fold serves
runs and sweeps. This does not create an alternate execution path.

Prepared data is reusable; a consumer's cursor is local. One forward fold does
not imply globally monotone requests: sweeps restart, inspection can seek
backward, and reopened runs have independent consumers. Returned windows must
remain unchanged and must not expose mutable engine storage.

Defer numerical segmentation, static trigger tables, exact invalidation bands
and partial updates as implementation requirements. V10 sections 6.1 and 10(d)
preserve the conservative carry bound and the preceding-input, source-state
and warm-up qualifications. They remain reasoning aids, not a prescribed data
structure or a requirement to calculate only within that band. Recursive,
cross-sectional, fitted and narrowed-axis dependencies need their own treatment;
the instrument-local finite-window result cannot certify them.

This decision does not remove the existing prepared fact segments. It does not
assert that an unmeasured whole-series implementation is affordable. Measure
ordinary preparation and delivered evidence in the implementation workload,
including total prepared storage and per-worker copies. Optimize only for an
observed bottleneck. Event density alone establishes neither necessity nor
affordability, and the earlier `2.11x` arithmetic is not a runtime estimate.

## 7. Checkpoint disposition and ticket-cut boundary

The old four-part checkpoint is no longer an instruction to commission a
segmented-candidate measurement before ticket cut. Its obligations are:

| Part | Disposition | What must be demonstrated |
| --- | --- | --- |
| (a) Semantic evidence | Live prerequisite for committing the evidence contract | Effective column and knowledge cutoff resolve through the existing family authority, including precedence, completeness and supersession; claimed distinctions remain distinguishable |
| (b) Two-clock representation | Live prerequisite for choosing the access representation | Raw clocks support prepared `(s, t)` retrieval without callback SQL, a second resolver or portfolio replay; a diagonal-only lookup fails the detecting case |
| (c) Treatment and disclosure | Retained implementation and release obligation | Both carry stages, required-field admission and aligned provenance are correct; their preparation and delivery costs are measured on the intended workload |
| (d) Numerical correctness | Retained for every supported configuration; segmented/banded performance work deferred | A fact changing treatment or window composition yields correct values and evidence at each cutoff, without changing earlier outputs; output carry is checked independently |

The spike answers the existence of one revision seam. It closes neither (a)/(b)
nor all of (c)/(d); it supplies no production cost verdict. Zero affected
requests in the assessed workloads is not a replacement for detecting fixtures.
Those fixtures certify supported behavior even where the real workload does
not exercise it. They need not instantiate a segmented production architecture.

The packet may own (c) and correctness under (d) as ordinary implementation
work. Resolve the concrete (a)/(b) representation questions before committing
their implementation interfaces; any remaining executable uncertainty may use
a bounded probe under [spike_protocol.md][protocol]. No comparative spike or
multi-stage experiment is chartered here. Ordinary implementation verification
does not become a spike merely because it measures its own cost.

At ticket cut, map each retained requirement to an owner, including the
contract amendment, required-field declaration, companion representation,
context-surface registration, and preservation in the repository of the exposure
report, its scripts and evidence CSVs with their source and workload provenance.
Keep the independently scheduled narrowing work explicit. A missing feasible
representation or unaffordable simple preparation returns that concrete issue
to the maintainer; it does not silently weaken
causality, omit carry, or authorize an optimization project.

## 8. Contract changes and detecting requirements

[contracts.md][contracts] remains authoritative for shipped behavior. The next
packet must amend its strict-window-only wording to permit declared external
input treatment and the narrowly eligible output treatment in section 5.
`strict_window` continues to prohibit hidden internal imputation. Required-field
admission, readiness on prepared inputs, barrier rules, missingness disclosure,
cutoff-specific identity and retained-result immutability become explicit.
The axis contract must state the selected semantics and the separate narrowing
scope; this rewrite does not apply a current-release engine change.

Acceptance must detect these defects, regardless of storage representation:

- Seal/wall-clock resolution, future-known admission, or omission of a fact
  effective at `s` and knowable at `t`. Include a fixture on which those clocks
  differ; reopen stability alone cannot detect a stable leaked answer.
- A supported accessor reading beyond its pulse or outside its ordered decision
  axis; wrong early padding, empty shape or scalar/window parity; inspection
  failing when the long table is empty.
- Backward carry, refreshed source age, cross-field or volume carry, crossing
  any barrier, losing the second corporate-action boundary after a fresh print,
  or restarting after a terminal boundary. Detect over-blocking under a declared
  split-adjusted basis and cutoff-inappropriate unlocatable-fact errors too.
- Conflating required-field admission, warm-up, calculation validity and output
  eligibility; silently enabling treatment or omitting its aligned provenance.
- Wrong values or evidence after a late-known change, including output carry
  alone and narrowing if supported. Preserve earlier-cutoff outputs; agreement
  between two implementations is insufficient if both use the wrong facts.
- Wrong cache reuse across policy, axis or information bounds; retained-result
  mutation, query-order dependence, or an unsupported companion distinction
  returning a plausible answer instead of failing explicitly.

V10's locality detector may corroborate the bounded cases; it does not require
partial computation or impose that bound on other feature families. No new
arbitrary timing, memory or member-count threshold is prescribed by this RFC.
Existing release performance gates continue to apply independently.

## 9. Deferred work and reopening

The record for revision optimization is v10 sections 6 and 10, the committed
semantic spike, and the exposure evidence described in section 2. Preserve it;
do not translate every derived bound into an implementation ticket.

Reopen optimization when an intended request actually changes under a supported
knowledge-timed fact or policy **and** simple correct preparation shows a
material time, memory or maintenance problem. Record affected instruments,
input/indicator cells and requests, then the consequence of a precisely named
shortcut, then the cost of correcting it. Synthetic cases establish correctness;
real requests establish the product need. A new source with genuine knowledge
clocks or missing sessions triggers exposure assessment, not automatic approval
of segmentation. Any causal approximation needs a separate explicit decision.

Fitted imputers remain the focused ML follow-up already recorded in the
2026-09-26 horizon entry. Liquidity policy, corporate-action vocabulary/clock
strengthening and general model lifecycle retain their own routes. None is a
prerequisite for the simple declared treatment promised here.

## 10. Reading anchors and integration

Load-bearing implementation anchors at the reading baseline: provider raw
clocks and construction in `R/availability-provider.R:28-47,211-246`;
diagonal segments and backward seek in
`R/availability-provider-prepared.R:47-55,102-160`; venue alignment in
`R/backtest-runner.R:873-907`; strict per-window calculation, current all-OHLC
gate and scalar validation in `R/features-engine.R:235-246,286-328`; sweep
projection payload and worker submission in `R/sweep.R:1068,1276-1292`,
candidate restart at `:1413`; arbitrary inspection cutoff in
`R/pulse-snapshot.R:35-41`. These are reading evidence, not new benchmarks.

The [original projection probe][projection-probe] established the mandatory
full runtime backing in both modes. Cut 13 subsequently repaired supported
access, as recorded in v10 and the current Context Contract. The fact that
complete data remains internal does not require physical bounded-slice closures.

Next: use section 7 for the next-release ticket cut. The exposure report, its
scripts and CSVs are preserved at `412f600`. The RFC index and roadmap record this
document as operative and retain v10 as the derivation record; no fresh seed cycle
is needed.

[v10]: rfc_point_in_time_historical_projection_v0_2_x_synthesis_v10.md
[amendment]: rfc_point_in_time_historical_projection_v0_2_x_missingness_amendment.md
[shape]: rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md#direction-54---lookback-primitive
[contracts]: ../contracts.md
[protocol]: ../spike_protocol.md
[spike]: ../../../dev/spikes/segmented-feature-views/spike_closeout.md
[projection-probe]: ../../../dev/spikes/historical-projection/probe_findings.md
