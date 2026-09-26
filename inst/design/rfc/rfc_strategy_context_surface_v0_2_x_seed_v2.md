# RFC Seed v2: Strategy Context Surface And Helper Composability

**Status:** Seed v2 - supersedes seed v1 as the operative seed. Nothing here is
binding until a synthesis is accepted.
**Date:** 2026-09-26
**Author:** Claude (seed v1 and v2; per `../rfc_cycle.md` seed v2 stays with the
seed author because it incorporates findings and owns architectural intent. The
synthesis must be written by a third author, since the response author is now a
party to the design).
**Baseline:** `v0.2.0.2` at `ede5bee`, with the implementation branch
`origin/codex/ws16-v0.2.1.0` at `b47b83f` now published (it was local-only when
the response was written, which is why several v1 claims were unverifiable).
**Inputs:**
- Seed v1: `rfc_strategy_context_surface_v0_2_x_seed.md` (historical)
- Response: `rfc_strategy_context_surface_v0_2_x_response.md` (ChatGPT)
- Response probes: `../../../dev/spikes/strategy-context-surface/`
- Maintainer decision 2026-09-26: the response's narrower question is accepted
  as this cycle's question, with the documented-surface check retained as the
  binding gate.

---

## 1. What Changed From Seed v1

Seed v1 asked a surface-shape question and its acceptance criteria were counts.
That framing rewarded deletion, and three of its proposals would have violated
bound contract text. The response caught each one. This seed adopts the
response's question and records the corrections rather than restating v1.

**Premises withdrawn.** Each was wrong, and each is corrected by text v1 had
already declared authoritative:

| v1 claim | Correction |
| --- | --- |
| `ctx$positions` duplicates `ctx$hold()`; delete one | `contracts.md:754-762` binds `positions` as a read-only pulse-start snapshot and `hold()` as a *constructor* of intent. Equal values in the complete case do not merge the roles, and `hold()` completes a sparse axis where `positions` does not. |
| A context selection should default to the full visible axis | `contracts.md:396-400` binds nonmember reservation: rebalance helpers start held nonmembers at current quantity, reserve their marked exposure, and size only current members. A full-axis default would try to allocate weight to holdings that cannot receive it. |
| Every intermediate must span the axis or exits vanish | Verified false. A two-of-three selection yields the complete target `AAA=500, BBB=500, CCC=0`; completion happens in `ledgr_target_rebalance()` from `ctx`, not from any attribute the intermediates carry. The completeness rule is a final-target rule. |
| `ctx$features(id)` and the feature rectangles are vestigial | A configured alias map returns a named bundle (`fast`, `slow`), and a projection-backed context returns bundle values while its long table is empty. An empty compatibility table is not evidence of absent data. Bound at `contracts.md:767-781`. |
| The plane alignment contract is unwritten | `contracts.md:744-749` and `man/ledgr_strategy_context.Rd:17-29` already document alignment and `ctx$idx()`. It is incomplete, not absent: it lacks unnamed-vector examples and says "instruments in the run" where the decision axis is meant. |
| `ctx$bar(id)` supersets the scalar accessors | It carries OHLCV and bar metadata but neither position nor feature values. |
| Unnamed planes are kept unnamed for speed | Never measured. Asserted from vector length. Withdrawn as a justification; the planes should stay unnamed because the axis is the addressing scheme, not because of an unmeasured cost. |

**Census reconciled.** v1 reported 29 public `ctx` members, the response 28.
Both are correct: `ctx$tradable()` exists only on the implementation branch, so
the dense constructor exposes 28 at `39de0bf` and 29 at `b47b83f`. A single
universal census is inappropriate anyway, because availability adds fields
conditionally. This is the clearest illustration of why v1's unpublished
baseline was a defect in its own right.

**Measurements re-scoped.** v1's timings (1.77 s scalar loop against 0.55 s
planes) and its 9,466-fill result came from the then-unpublished branch. The
branch is now published, so they are reproducible, but the response's objection
stands on its own terms: a single elapsed-time pair cannot establish an API
prohibition. They are retained as motivation for *teaching* planes and are
withdrawn as an argument for *removing* scalar reads.

**Scope removed.** The rebalance band leaves this cycle entirely (section 7).

**Invalid gate removed.** v1's acceptance criterion 5 required fills to fall
with equity unchanged. Different holdings produce different equity, so that
detector cannot hold in general.

## 2. Question

**How does a strategy read current information and express portfolio intent
without alignment tricks or hidden allocation policy?**

Both failure modes are concrete, not rhetorical.

**Alignment tricks** are the observable symptom and the strongest surviving
evidence from v1. Four executed formulations of "equal-weight everything"
return identical targets, and the cleanest of the four abandons the pipeline:

```r
# A: hand-built named logical over the universe
hold <- ledgr_selection(stats::setNames(rep(TRUE, length(ctx$universe)), ctx$universe))
ledgr_target_rebalance(ledgr_weight_equal(hold), ctx)
# B: a trick that depends on flat() being all zeros
ledgr_target_rebalance(ledgr_weight_equal(ledgr_selection(ctx$flat() == 0)), ctx)
# C: top_n abused to mean "all"
ledgr_weight_equal(ledgr_select_top_n(ledgr_signal(ctx$flat() + 1), n = length(ctx$universe)))
# D: leave the pipeline and size by hand
tg <- ctx$flat(); tg[] <- floor(ctx$equity / length(tg) / ctx$vec$close); tg
```

The response adds the decisive qualification: D is shorter but **not a general
replacement**. On a fixture with equity 100, prices 10 and 20, and two shares
of former member OLD, the helper returns `AAA=6, OLD=2` with 40 of equity
reserved, while D returns `AAA=5, OLD=2` because it divides by axis length.
So the trick is not merely ugly - it silently ignores reservation policy. That
is the case for fixing the entrances rather than tolerating the workaround.

**Hidden allocation policy** is what v1 would have introduced. It names both
rejected defaults: a full-axis default allocates to holdings that cannot take
weight, and a `priced & admissible` screen converts missing input into exit
intent. The response also shows a permissible valuation mark is not an
accepted current close, so a "tradable" screen and a sizing screen are not the
same predicate.

## 3. Settled By The Response (not open for synthesis)

Recorded so the synthesis does not re-litigate them.

- **Scalar reads stay.** They serve the single-asset case, and removing them
  could not forbid the loop anyway: `ctx$bar(id)` is loopable and slices or
  builds a frame (`R/pulse-context.R:741-767`). Teach planes for
  cross-sectional work. The scalar-accessor warning is evaluated on its own
  merits in its own cycle, not used as a foundation here.
- **Feature bundles stay.** A feature value has two keys. A plane fixes the
  feature; a bundle fixes the asset. Named consumers exist in
  `vignettes/indicators.qmd:206`, `vignettes/sweeps.qmd:163-176` and
  `vignettes/research-workflow.qmd:274`.
- **Allocation defaults to investment membership** - all configured
  instruments in a dense context, `ctx$members` when availability is active -
  with no silent quality screen.
- **No class on the axis in this cycle.** v1's frame-or-nested-list dichotomy
  was false and classing does not materialise anything, but no entrance needs
  it. Improve the reference first.
- **No tidy eval on `ctx`.** `dplyr::filter()` drops rows; a selection must be
  able to express a full-axis mask. A verb named `filter` that does not filter
  misleads where the semantics matter most.
- **Tombstones go.** `ctx$targets()` and `ctx$current_targets()` are removed
  without replacements.
- **Candidate rules leave the selection namespace.** `ledgr_select_argmax()`
  and `ledgr_select_argmin()` build a `ledgr_selection_rule` from a metric
  (`R/walk-forward-selection.R:15-52`) and do not select instruments.
- **`ctx$safety_state` becomes private.**

## 4. Open Decisions

### D1. The inspection boundary

The response supports removing the long and wide feature rectangles
(`ctx$feature_table`, `ctx$features_wide`) and `ctx$bars` from the callback's
public read surface, with read-only access through the existing pulse
inspection APIs instead. This is new scope that seed v1 never posed, and it is
the largest open item: it needs a contract amendment, internal call-site
updates, and alias/warmup tests on both the projection and interactive paths.

The synthesis must decide what leaves the callback, what replaces it, and
whether an empty compatibility table is removed or repaired. It must not
rebuild frames inside the callback to preserve the old spelling.

### D2. Empty-domain behaviour

`contracts.md:375-379` permits an empty decision axis and a zero-length target.
The implementation rejects it in at least three places: `ledgr_target()` aborts
on `length(x) < 1L` (`R/strategy-types.R:219-221`),
`ledgr_validate_strategy_helper_ctx()` aborts on `length(universe) < 1L`
(`R/strategy-helpers.R:6-8`), which every ctx-validating helper passes through,
and `ledgr_selection(logical(), universe = character())` aborts on the universe
check. `ctx$hold()` returns a valid empty named vector, so the contract's
promise is half-implemented.

This is a genuine contract-versus-implementation contradiction, found by the
response, and it must be resolved in this cut: a new "everything" entrance
cannot require an undocumented escape hatch for nothing.

### D3. Public `ctx$positions`

The response accepts removing it **if** `ctx$vec$positions` remains the
canonical read view, and is explicit that `ctx$hold()` must not be taught as
its replacement, because `hold()` constructs and fills a new target vector
(`R/pulse-context.R:796-828`). `contracts.md:754-762` binds both spellings as
read-only views of the same pulse-known state.

So the decision is narrow: does the scalar/plane law justify removing the
top-level snapshot, given that its plane survives and its apparent replacement
is a different kind of thing? A related sub-decision: `contracts.md:747` binds
the plane field name as `positions`, so any rename to `position` is an
amendment rather than a consequence.

### D4. Entrance validation

The shape is settled (section 5); the rules are not. For a context-derived
entrance the synthesis must bind: whether unnamed input must match axis length
exactly, whether named input aligns by unique known IDs, that no recycling
occurs, how a deliberately chosen subset is distinguished from incomplete or
`NA` input, and whether an attempt to weight a nonmember errors or is dropped.
The response argues for exact length, alignment by known IDs, no recycling,
continued `NA` rejection, and rejecting nonmember weights. Each needs a named
error class.

## 5. Proposed Shape

Explicit context-first entrances with named arguments, rather than a
constructor that changes behaviour by argument class. Value constructors for
already-named vectors remain, unchanged, for use without a context.

```r
# membership allocation; held nonmembers are preserved and reserved downstream
ledgr_selection(ctx) |>
  ledgr_weight_equal() |>
  ledgr_target_rebalance(ctx)

# an evaluated plane, not a data-masked expression
ledgr_signal(ctx, values = ctx$vec$feature("return_20")) |>
  ledgr_select_top_n(10) |>
  ledgr_weight_equal() |>
  ledgr_target_rebalance(ctx)
```

Three teachable roles replace seed v1's single syntactic law: **read current
state**, **select and weight members**, **return complete intent**. Scalar and
plane stay symmetric for OHLCV and position; the feature accessor takes an
extra argument because a feature value has a second key, and that is explained
rather than treated as an exception. No scalar method is manufactured for every
availability metadata plane in order to claim zero exceptions.

## 6. Binding Gate

The reframed question is qualitative, so the cycle keeps one mechanical gate:
the **documented-surface check**. A reference table in
`man/ledgr_strategy_context.Rd` lists every public `ctx` member with its shape
and its counterpart, covering dense and availability variants, and
`tests/testthat/test-documentation-contracts.R` asserts the documented set
equals the actual public surface. A member cannot ship undocumented, and the
table cannot drift the way prose does. No new registry or generator is built
for this; the existing documentation-contract mechanism carries it.

Alongside it, the response's practical checks, restated as obligations:

1. The short equal-member pipeline reproduces the dense control's targets and
   the reserved-budget result with a held nonmember; final targets are
   complete.
2. Missing sizing input fails explicitly, and deliberate omission, an explicit
   exit and `ctx$hold()` stay distinguishable. Empty membership and an empty
   axis both work.
3. Scalar, plane and alias-bundle reads agree on values, order and warmup;
   unknown IDs and length or name mismatches fail with useful context.
4. Every taught workflow renders against the chosen surface, and a reader finds
   axis, units, missingness and omission rules in one reference.
5. No per-pulse frame materialisation and no full-history work is added. Any
   performance claim uses a reproducible same-workload comparison.

## 7. Non-Goals

- The rebalance band. It changes portfolio policy, not spelling: units,
  comparison basis, explicit exits, residual cash and downstream risk
  interactions all need decisions, and a large fill count does not establish
  which band is right. It belongs with the existing rebalancing work. Teach
  hold-unless-signal in the meantime.
- Any change to the strategy contract, the four classed intermediates, or the
  pipeline order.
- Estimator-backed weighting. It needs a point-in-time multivariate window that
  does not exist, and the horizon places optimizers in extension territory.
- Weight caps and long-only handling: `ledgr_risk_max_weight()` and
  `ledgr_risk_long_only()` own those as constraints, not intent.
- An imputation policy. Unknown information must not silently become a negative
  selection.
- Deprecation shims, new tombstones, a spike, or a new provenance system. The
  response's probes already settle the helper questions.

## 8. Sequencing

Design work only; it runs in parallel with the open v0.2.0.2 chain and is
implemented after the release gate. Workstream 18 writes its articles against
the surface that actually ships and accepts one later rewrite; no article
teaches the proposed surface before it exists. The response and this seed agree
on this point, so it is not an open question.

## 9. Credit

The response author found the nonmember-reservation conflict, the
selection-versus-target completeness error, the feature-bundle evidence, the
`hold()` sparse-completion distinction, and the empty-domain contradiction, and
declined to charter a spike. Sections 1 through 4 of this seed are largely their
work, restated as seed positions so the synthesis has one operative document.
