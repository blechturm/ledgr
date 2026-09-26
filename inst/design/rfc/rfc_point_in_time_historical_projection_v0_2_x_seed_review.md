# Seed Review: Point-in-Time Historical Projection

**Status:** Adversarial review of Seed v1. This is **not** the Section 12
response stage. The seed gates that stage on two prerequisites: preserving the
prior-art pass in `../research/` and recording the Section 11 probe. The first
is satisfied by `../research/ML_historical_data_prior_art.md`; the second is
not. The maintainer requested a full adversarial read of the seed's ideas ahead
of that gate, and this document is scoped accordingly. Several findings below
can only be *settled* by the probe; two of them make the probe cheaper.

**Date:** 2026-09-26
**Reviewer:** Claude. The seed names ChatGPT as author and reserves the
response
stage for a different author, so there is no rotation conflict.
**Seed baseline:** `main` at `4350e65`, package version 0.2.0.1.
**Review baseline:** `v0.2.0.2` branch at `4e65378` (the release in progress is
promoted to v0.2.1.0), with the implementation branch
`codex/ws16-v0.2.1.0`. This divergence is itself a finding; see F4.
**Method:** executed source-level inspection of the runtime projection under
`pkgload::load_all()` on R 4.6.1, plus reading of the cited predecessor
syntheses and current fold and context implementations. No spike was built and
no probe was chartered.

---

## 1. What the seed gets right

The seed is disciplined and its central question is well posed. Four things in
particular should survive into any synthesis unchanged.

**Section 3.3 is the most important paragraph in the document.** Refusing to
let
the engine choose complete-case deletion, pairwise covariance, shrinkage,
imputation, normalization or minimum-history thresholds is exactly the boundary
that competing frameworks blur, and the prior-art pass confirms it: LEAN
forward-fills by default, Zipline yields NaN under lifetimes, Qlib delegates to
user processors. Three frameworks, three incompatible defaults, none of them a
property of the market. A backtester that picks one silently has made a
methodological choice on the researcher's behalf.

**Section 3.4 draws the right line in the right place.** Distinguishing
causally
re-estimated transforms from frozen-on-train transforms by *fitting regime*
rather than by algorithm name is the distinction that makes the ML boundary
tractable. The same PCA belongs on either side depending on when it is fitted.

**Section 11's kill condition and Section 15's refusal to charter the
comparative spike** are the correct application of the spike protocol, and they
are the opposite of what the asset-availability spike did before closing
inconclusive.

**Section 2 correctly refuses to treat this as greenfield.** The accepted
`ctx$window()` contract exists and must be explicitly preserved or superseded.
Demanding that disposition rather than quietly re-deciding it is right.

---

## 2. Findings

### F1 - Major: the probe's plumbing question is already answerable, in both modes

The seed frames its gate as an open question: can the current runtime feature
projection supply the numerical backing for a causal lookback under dense
**and**
availability-aware execution? Inspection answers the plumbing half yes, for
both
modes, and the seed appears not to know how favourable its own position is.

Executed at the review baseline, `ctx$.feature_projection` is a classed
`ledgr_runtime_projection` carrying `feature_values`, `instrument_index`,
`pulse_index`, `pulses_posix`, `pulses_iso`, `feature_engine_version` and
`alias_index`. For a three-instrument, twelve-pulse run with one registered
`sma_3`, `feature_values$sma_3` is a **3 x 12 numeric matrix** - instruments by
*all* pulses - and `pulse_index` has length 12 at the first callback.

The projection is not a dense-mode convenience. It is mandatory at the fold
level (`R/fold-engine.R:252` aborts with `ledgr_invalid_fold_execution` when it
is absent) and is passed into the per-pulse context path at
`R/fold-engine.R:631`, which explicitly handles availability one line later
(`id_to_idx = if (availability_active) NULL else id_to_idx`). The availability
branch of the context reads features through
`ledgr_projection_feature_accessor(projection, pulse_idx, ...)`. What
`use_fast_context <- !availability_active` selects is a cached *context state*,
not the existence of the projection.

So `ctx$window(feature, L)` at pulse `i` is a column slice of an already
prepared, already indexed matrix: no database access, no persisted strategy
state, no second computed series, in either mode. Direction A is not merely
"the lower-machinery direction"; its plumbing prerequisite already holds.

**Correction:** rescope Section 11. The probe should not spend effort
re-establishing what inspection shows. The genuinely open half is semantic -
whether a lookback slice can carry membership-at-historical-instant, warm-up
and
staleness meaning without a second availability vocabulary - and the kill
condition should be narrowed to that. As written, a green probe will be read as
evidence for far more than it tested.

### F2 - Major: the seed never asks whether a bounded view exposes an unbounded future

This is the seed's most consequential omission, and it follows directly from
F1.

The full future is materialized and live in the strategy's own context at pulse
one. `ctx$.feature_projection$feature_values[["sma_3"]][, 12]` at pulse 1
returns pulse 12's value. The dot prefix is a convention, not an enforcement
boundary; R does not hide the field. The no-lookahead machinery guards a
*feature series function* from peeking forward while the series is computed
(`LTB-0003`, `R/features-engine.R`); it does not guard a strategy from reading
the prepared panel at decision time. `R/strategy-preflight.R` mentions neither
`feature_projection` nor dot-field access.

Today this requires deliberate misuse and is therefore a latent exposure rather
than a live defect. But the seed proposes to formalize access to exactly this
object. The moment a bounded lookback ships, the enforcement line becomes "the
slice you were handed" versus "the object the slice came from", and they are
one
subscript apart. Whether the view is a copy, a restricted slice, or a guarded
accessor is an architectural decision with a cost on each branch - and Section
7
(cell semantics) and Section 10 (performance) between them never pose it.

For a package whose headline promise is no-lookahead, shipping a history API
without deciding this would be the single most damaging thing in the cycle.

**Correction:** add it as a sixth Section 12 question, and add copy-versus-view
to Section 14's list of things the synthesis must bind.

### F3 - Medium: Section 10 forbids something the engine already does

Section 10 says the first implementation must not normalize "full-panel
long-data materialization merely to recover a matrix". But the engine already
performs full-panel *wide* materialization of every registered feature across
every pulse, before the first callback. At 500 instruments, 2,500 pulses and
ten
features that is 12.5 million doubles, roughly 100 MB resident, with no history
API in existence.

The seed's constraint list therefore reads as though historical materialization
is a new risk to be avoided, when the baseline already pays it and any lookback
API inherits it. The real performance question is not "should we materialize"
but "is the existing full materialization acceptable at research scale, and
does
a lookback contract change its bounds?"

This matters beyond accuracy: it removes the performance argument for Direction
B. A lower shared projector cannot be justified on materialization grounds when
the current projector already materializes everything.

### F4 - Medium: the baseline is stale precisely where the seed's public proposal lands

The seed is written against v0.2.0.1. Since then the release has been promoted
to v0.2.1.0, Workstream 16 shipped new context accessors, and **Cut 13 is
scheduled to rewrite the context surface before the tag**: removing public
`ctx$positions`, renaming the position plane, adding context-first constructor
entrances, and binding a documented-surface contract test that asserts every
public top-level and plane member in both dense and availability contexts.

The seed's headline public shape is `ctx$window()` - a new context member. It
must be dispositioned against Cut 13's accepted rules rather than against
v0.2.0.1: the scalar/plane law, the reference-table gate, and the
decision-axis-versus-investment-membership distinction. A response written
against the old baseline risks proposing a member the surface contract then
rejects.

**Correction:** rebaseline the seed before the response opens, and name
`rfc_strategy_context_surface_v0_2_x_synthesis.md` as a binding predecessor.

### F5 - Medium: the axis question is already answered next door

Section 7 asks how a historical view relates to the current decision axis,
current members, held nonmembers and a fixed basket. The strategy-context
synthesis has already bound that vocabulary: the decision axis may contain held
nonmembers, investment membership may not, allocation defaults to membership,
and no quality screen is applied silently.

Re-deriving those terms here would produce two axis vocabularies for one
concept. Inherit them.

### F6 - Medium: the prior-art pass mostly confirms existing positions

The survey is competent and its negative finding is its most valuable content:
it "does not authorize copying any framework's missing-data, fill-forward,
dataset, or execution policy." But of its transferable positives, Zipline's
declared-lookback-dependency pattern is something ledgr already has in
registered features, and LEAN's per-bar-history anti-pattern is already
forbidden by the optimization coding style. The genuinely new input is narrow:
portfolioBacktest's separation of optimization cadence from rebalance cadence,
which the seed correctly picks up in Section 8.

That is worth stating plainly so the synthesis does not cite the survey as
support for a decision the survey did not drive. It is confirmation, not
evidence, and the seed's own evidence-limitation paragraph is more honest about
this than Section 4 is.

### F7 - Small: Direction A versus Direction B is close to a false binary

Given F1, Direction B's stated rationale - that the current projection cannot
represent point-in-time ragged history without duplicating availability logic -
is not established and is unlikely. Both modes already read one projection. The
remaining question is whether availability needs a different *index* over the
same matrix, which is a small change, or a different *projector*, which is a
large one. Presenting them as two coherent architectural directions overstates
the openness of the choice and invites a synthesis to pick the larger one out
of
caution.

---

## 3. The seed's own five questions, where evidence permits an answer

1. **Predecessor disposition.** Likely preserve, not supersede: the accepted
   contract (one feature, `n_inst x lookback`, universe order, oldest to
   current, leading `NA`) is a direct slice of the matrix that already exists.
   The open part is whether availability metadata travels alongside it - F2 and
   the semantic half of F1.
2. **One substrate, several consumers.** The substrate exists and is already
   shared between dense and availability execution. The unexamined consumer is
   training-panel export, which wants many features at many pulses - the same
   object, unsliced. That makes F2 more acute, not less.
3. **Historical semantics.** Unanswered and genuinely open. This is where the
   probe should spend its effort.
4. **Identity boundary.** The projection already carries
   `feature_engine_version`, which suggests the cache-identity question is
   partly solved. Worth checking before treating it as open.
5. **Minimum first implementation.** On this evidence, one read-only
   single-feature lookback returning a copy, with a companion availability
view,
   and no multi-feature tensor.

---

## 4. Recommended next action

The seed's Section 15 sequence is right in shape but wrong in weight. Rather
than running the probe as specified:

1. Rebaseline onto the v0.2.1.0 surface and add the strategy-context synthesis
   as a binding predecessor (F4, F5).
2. Add the copy-versus-view question to Section 12 and to the acceptance list
   (F2).
3. Rescope the Section 11 probe to the semantic half only, and record the
   plumbing findings in this review as already established (F1, F3).
4. Correct Section 10 to acknowledge existing full materialization (F3).
5. Then open the response stage.

A probe scoped as currently written would come back green and be over-read. A
probe scoped to the semantic question would come back with something the cycle
does not already know.

## 5. Disposition

The seed is a strong document with one major omission, one stale baseline, and
a
gate that is more expensive than it needs to be. Its boundaries - statistical
policy out, fitting regime as the discriminator, no second causal path, no
storage comparison before the prerequisite - are correct and should be kept.
Nothing here requires a new research pass or a broader spike.

Recommended: **patch the seed on F1 through F5 before opening the response
stage.** Not ready for response as written, and not for the reason the seed
itself gives.
