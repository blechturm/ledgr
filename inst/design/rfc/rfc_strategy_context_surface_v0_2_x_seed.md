# RFC: Strategy Context Surface And Helper Composability

**Status:** Seed v1 - request for response-stage review. No implementation
started. Nothing in this document is binding until a synthesis is accepted.
**Date:** 2026-09-26
**Author:** Claude (seed v1; per `../rfc_cycle.md` role rotation the response
stage should be authored by a different model, and the synthesis by whoever
did not write the final seed).
**Window:** v0.2.x, after the v0.2.0.2 release gate. This cycle is design
work only and does not compete with the open v0.2.0.2 workstream chain.
**Input:** Maintainer discussion 2026-09-25/26 that began with a landing-page
critique ("too much too early"), moved through the strategy helper pipeline,
and ended at the observation that `ctx$vec$positions` is correct but assumes
the reader has studied a nested structure. The maintainer's framing: the
interface must be genuinely logical and predictable, tombstones must go, and
the target is tidyverse usability.
**Context files:**
- `../contracts.md` - authoritative; names 20 `ctx` members in 27 places
- `../ledgr_ux_decisions.md` - guiding principles, "Tidyverse adjacent" first
- `R/pulse-context.R` - the context constructor and helper bundle
- `R/strategy-helpers.R` - the signal/selection/weights/target pipeline
- `R/strategy-types.R` - the four classed intermediates
- `tests/testthat/test-api-exports.R` - the locked export surface
- `../manual/optimization_coding_style.qmd` - the seven shapes; constrains any
  proposal that would manifest a frame per pulse

---

## 1. Problem Statement

The strategy read surface has grown to 29 public members at the top level of
`ctx` plus 8 under `ctx$vec`. The nesting is not the problem. The problem is
that there are **three different conventions** for expressing "one instrument
versus all instruments", so there is no single rule a reader can learn:

| Concept | One instrument | All instruments |
| --- | --- | --- |
| OHLCV | `ctx$close(id)` (function) | `ctx$vec$close` (plane) |
| positions | `ctx$position(id)` (function) | `ctx$positions` **and** `ctx$hold()` |
| features | `ctx$feature(id, fid)` | `ctx$vec$feature(fid)` (a function) |

The OHLCV convention is clean and holds five times out of five. It then breaks
twice, and the feature domain has five separate routes rather than two.

A second, related problem: the helper pipeline
(`signal -> selection -> weights -> target`) is already correctly shaped for
piping, but it has exactly one entrance from `ctx`, and that entrance is
hard-wired to returns. The consequence is measurable in how badly the simplest
possible strategy reads. "Equal-weight everything" currently requires either a
hand-built named logical vector or a trick.

## 2. Current State Inventory (measured, not asserted)

All figures below were obtained by executing the package at
`codex/ws16-v0.2.1.0`, not by reading source.

### 2.1 Shape census

Top level of `ctx`, public members only: 15 functions, 5 scalars, 5 vectors,
3 data frames, 1 list. `ctx$vec` holds 7 planes plus 1 function.

### 2.2 Verified redundancies

- `identical(ctx$hold(), ctx$positions)` is **TRUE** - same values, same
  names. `ctx$positions` is simultaneously the only vector-at-top-level
  (breaking the convention that top level takes an id) and a duplicate of
  something that already follows it.
- `ctx$bar(id)` returns a one-row data frame carrying `instrument_id`,
  `ts_utc`, OHLCV, `gap_type` and `is_synthetic` - strictly more than the
  seven per-field scalar accessors expose.
- `ctx$feature_table` is a 0x4 empty frame in an ordinary run.
  `ctx$features(id)` returned `character(0)` with no names. Both look
  vestigial and both are named in `contracts.md`.

### 2.3 The plane alignment contract is unwritten and is a trap

`ctx$vec` planes are **unnamed** and positionally aligned to `ctx$vec$id`.
`ctx$vec$close[["AAA"]]` raises `subscript out of bounds`;
`ctx$vec$close["AAA"]` would return `NA` silently. `ctx$idx("AAA")` returns the
integer index and is the intended bridge. None of this is stated where a
strategy author will find it. The planes should stay unnamed - naming a
2,000-element vector every pulse is a real hot-path cost - so this is a
documentation and contract obligation, not a change.

### 2.4 Tombstones

Exactly two: `ctx$targets()` and `ctx$current_targets()`, both v0.1.7 removals
raising `ledgr_context_helper_removed`. Both are named in `contracts.md`.
Removing them is 12 lines.

### 2.5 The pipeline already pipes

Verified signatures:

```
ledgr_signal_return(ctx, lookback = 20L)
ledgr_select_top_n(signal, n)
ledgr_weight_equal(selection)
ledgr_target_rebalance(weights, ctx, equity_fraction = 1.0)
```

The flowing intermediate is first in every call and `ctx` is re-supplied where
needed, so this is already valid today and already reads like dplyr:

```r
ledgr_signal_return(ctx, 20L) |>
  ledgr_select_top_n(10) |>
  ledgr_weight_equal() |>
  ledgr_target_rebalance(ctx)
```

This is the part of the design that works. No proposal in this seed changes it.

### 2.6 One name collision

`ledgr_select_argmax()` and `ledgr_select_argmin()` do not select instruments.
They take a **metric** and return a `ledgr_selection_rule`, which is candidate
selection for sweeps. They share the `ledgr_select_*` prefix with
`ledgr_select_top_n()`, which selects instruments from a signal. Two unrelated
concepts under one prefix.

### 2.7 What the simplest strategy costs today

Four formulations of "equal-weight everything" were executed and produce
identical results (6 fills, total quantity 1002, identical final equity):

```r
# A
hold <- ledgr_selection(stats::setNames(rep(TRUE, length(ctx$universe)), ctx$universe))
ledgr_target_rebalance(ledgr_weight_equal(hold), ctx)
# B
ledgr_target_rebalance(ledgr_weight_equal(ledgr_selection(ctx$flat() == 0)), ctx)
# C
ledgr_target_rebalance(
  ledgr_weight_equal(ledgr_select_top_n(ledgr_signal(ctx$flat() + 1),
                                        n = length(ctx$universe))), ctx)
# D
tg <- ctx$flat(); tg[] <- floor(ctx$equity / length(tg) / ctx$vec$close); tg
```

The cleanest of the four is D, which leaves the pipeline entirely. A pipeline
built for composability cannot express its most basic case without a
hand-built logical vector (A), a trick that depends on `flat()` being all
zeros (B), or an abuse of `top_n` (C). This is the strongest single piece of
evidence that the entrances are missing, not the verbs.

## 3. Design Constraints

These bound any proposal and the synthesis should treat them as fixed unless it
argues explicitly otherwise.

1. **`contracts.md` is authoritative and names the surface.** Twenty `ctx`
   members appear in 27 places, including every member this seed proposes to
   delete or rename. Any accepted change carries a contract amendment.
2. **No frame per pulse.** `optimization_coding_style.qmd` forbids manifesting
   data frames on paths that scale with instruments x pulses. This rules out
   making the decision axis a per-pulse tibble, however tidyverse-natural that
   would be. The axis stays a set of aligned vectors.
3. **Missing is not zero.** `contracts.md` forbids silently treating an absent
   strategy target as zero. Any selection-producing verb must therefore span
   the full decision axis so unselected instruments carry explicit `FALSE`,
   which becomes an explicit exit downstream. This is why relaxing
   `ledgr_weight_equal()` to accept a bare character vector of ids is unsafe:
   ids carry only the chosen names, so the exits silently disappear.
4. **Tidyverse adjacent without a tidyverse dependency**
   (`ledgr_ux_decisions.md`). `rlang` is already in Imports, so tidy eval is
   available at no dependency cost; the question is whether it is desirable,
   not whether it is affordable.
5. **Pre-release, no consumers.** Breaking the surface is free. Deprecation
   shims are not required and tombstones are not to be added.

## 4. The Four Decisions

Everything else in this seed is a mechanical correction with no defensible
second position (section 5). These four are the reason this is an RFC.

### D1. Does the API forbid the pathological access pattern, or warn about it?

v0.2.0.2 Workstream 16 added `ledgr_scalar_accessor_loop`, a runtime warning
that fires once per run when a strategy calls a scalar accessor as many times
in one pulse as there are instruments, at 100 instruments or more. Measured at
100 instruments, one run using a scalar loop took 1.77 s against 0.55 s for the
same strategy reading planes.

The warning exists because `ctx$close(id)` invites the loop. The alternative is
to remove the seven per-field scalar accessors, leaving `ctx$bar(id)` for a
single instrument (which already carries more information) and `ctx$vec$*` for
planes. Then the trap is unwriteable rather than detectable - and the warning
machinery becomes dead weight.

Arguments for keeping them: a single-asset strategy genuinely wants
`ctx$close(id)`, and `ctx$bar(id)` returns a data frame, so looping it is worse
than looping the scalar accessor. Arguments for removing them: they are the
sole reason a runtime warning had to be invented, and the same information is
reachable two other ways.

This decision governs the rest. **Seed position:** keep them, make the
convention exact, and let the warning do its job - the API should permit the
readable thing and flag the pathological one. The response stage should attack
this position; it is the seed author's least confident conclusion.

### D2. What is the canonical feature route at decision time?

Five exist: `ctx$feature(id, fid)`, `ctx$features(id)`, `ctx$features_wide`,
`ctx$feature_table`, `ctx$vec$feature(fid)`. `contracts.md` names four of them.
Two appear vestigial by measurement (2.2).

**Seed position:** two survive - `ctx$feature(id, fid)` for one value and
`ctx$vec$feature(fid)` for the plane - unless the response can name a consumer
that needs a rectangle. The response should check whether `ctx$features_wide`
and `ctx$feature_table` serve the interactive `ledgr_pulse_snapshot()` path
rather than strategies, which would change the answer to "keep, but move off
`ctx`".

### D3. Does a context-derived selection default to the axis or to `tradable()`?

If `ledgr_selection(ctx)` is added as the "everything" entrance, it must mean
one of two things: every instrument on the current decision axis, or every
instrument in `ctx$tradable()` (admissible and priced, added in v0.2.0.2).
These differ once availability is active.

**Seed position:** the decision axis. A default that silently drops an
instrument you could still exit is a correctness hazard under constraint 3, and
the narrower reading remains available as `ledgr_selection(ctx$tradable(),
ctx)`. The response should test whether that produces a surprising result when
a held instrument is a non-member.

### D4. Is `ctx` the only noun, or does the decision axis become an object?

The tidyverse-native representation of aligned per-instrument data is a table,
and `ctx$vec` is already one in all but type. Making the axis a first-class
classed object (with a print method, and possibly `as.data.frame()` for
interactive use) would let the surface be described as "one object, one law"
rather than "a list with a nested list inside it".

**Seed position:** do not do this now. Constraint 2 forbids materialising a
frame per pulse, and a lazily materialised one puts the cost on the idiomatic
path, which is worse than the current explicitness. But the question deserves a
recorded answer rather than a seed author's preference, because everything else
hangs off it.

## 5. Mechanical Corrections (no second position expected)

The synthesis should bind these as consequences, not decisions.

1. Delete `ctx$targets()` and `ctx$current_targets()`; amend `contracts.md`.
2. Delete `ctx$positions`; `ctx$hold()` is byte-identical. Amend
   `contracts.md` (2 mentions).
3. Rename `ctx$vec$positions` to `ctx$vec$position`: each element is one
   instrument's position, matching `close` rather than being pluralised.
4. Rename `ledgr_select_argmax()` / `ledgr_select_argmin()` out of the
   instrument-selection namespace (`ledgr_rule_argmax()` or
   `ledgr_candidate_argmax()`).
5. Remove `ctx$bars` (covered by `ctx$bar(id)` and `ctx$vec`) and move
   `ctx$safety_state` behind a `.` prefix.
6. State the plane alignment contract (2.3) in `contracts.md` and in the `ctx`
   reference: planes are unnamed, aligned to `ctx$vec$id`, crossed with
   `ctx$idx(id)`.

## 6. Proposed Rules For The Synthesis To Bind

**R1. The one law.** For every per-instrument field `F`, `ctx$F(id)` returns
one value and `ctx$vec$F` returns all values, aligned to `ctx$vec$id`. No other
convention for one-versus-all exists on `ctx`.

**R2. Entrances, not verbs.** The pipeline gains ctx-first entrances rather
than more stages: `ledgr_signal(ctx, <plane>)` as the universal signal door
(making `ledgr_signal_return()` a convenience on top of it), and a polymorphic
`ledgr_selection()` accepting `(ctx)`, `(logical, ctx)` and `(ids, ctx)`. Every
`select_*` verb returns a selection spanning the full axis.

**R3. One argument for turnover.** `ledgr_target_rebalance(weights, ctx,
band = )` keeps current holdings unless the desired target differs by more than
the band. This is intent shaping, not a constraint, so it does not belong in
the risk chain. Rationale: an unbanded per-pulse equal-weight rebalance
produced 9,466 fills on `ledgr_demo_bars`, which is the wrong default behaviour
to teach.

**R4. The surface is documented by contract, not by prose.** A generated
reference table in `ledgr_strategy_context.Rd` lists every public `ctx` member
with its shape and its counterpart, and
`tests/testthat/test-documentation-contracts.R` asserts the documented set
equals the actual public surface, so a new member cannot ship undocumented.

## 7. Non-Goals

- No change to the strategy contract itself: `function(ctx, params)` returning
  a full named numeric target vector.
- No change to the four classed intermediates or the pipeline order.
- No tidy eval / data masking on `ctx`. A masked row filter reads familiar but
  `dplyr::filter()` drops rows while a ledgr selection must retain the full
  axis; a verb named `filter` that does not filter would mislead in the one
  place the semantics matter. Explicit `ctx$vec$close > 100` also names the
  plane and the pulse, which masking would hide.
- No weight verbs beyond `ledgr_weight_equal()`. Estimator-backed weighting
  (inverse volatility, minimum variance) needs a point-in-time multivariate
  window that does not exist, and the horizon already places optimizers in
  extension territory.
- No weight caps or long-only handling: `ledgr_risk_max_weight()` and
  `ledgr_risk_long_only()` own those, and they are constraints, not intent.
- No deprecation shims and no new tombstones.

## 8. Acceptance Criteria If Implemented

1. Public top-level `ctx` members are reduced from 29 to at most 15, and every
   per-instrument field satisfies R1 with zero exceptions.
2. A documentation contract test fails when a public `ctx` member is added,
   removed or reshaped without the reference table changing.
3. `ledgr_selection(ctx) |> ledgr_weight_equal() |> ledgr_target_rebalance(ctx)`
   runs, and a test asserts it is identical to the hand-built form in 2.7A.
4. A test asserts that an unselected instrument in a context-derived selection
   produces an explicit exit target, not an absent one.
5. The banded rebalance reduces fill count on `ledgr_demo_bars` by a stated
   factor with equity unchanged within a stated tolerance, and a mutation that
   ignores the band fails a registered detector.
6. No tombstone remains in `R/pulse-context.R`.
7. `contracts.md` is amended for every renamed or removed member, and no
   contract sentence names a member that no longer exists.
8. All executed vignettes render, and the strategy-authoring articles teach R1
   as a single sentence.

## 9. Open Questions vs Future Obligations

**Open for this cycle:** D1 through D4, and whether `ctx$features_wide` moves
to the interactive path rather than being deleted.

**Future obligations, not this cycle:** the point-in-time multivariate return
window and the ragged-panel policy it requires (separate cycle; see the
portfolio-construction discussion of 2026-09-25); whether `ctx$vec` should be
renamed now that it is the primary read path; whether the scalar-accessor
warning can be retired if D1 resolves toward removal.

## 10. Recommended Sequencing

This cycle is design work and can run in parallel with the open v0.2.0.2 chain
(workstreams 19, 16, 17, 18, 15). It must not be implemented inside that
release.

One scheduling decision is needed before the synthesis lands. v0.2.0.2 cut 11
workstream 18 re-cuts three executed articles onto a shared demo universe, and
those articles teach `ctx`. If this RFC's implementation follows, they are
rewritten twice. The seed's recommendation is that workstream 18 writes against
the current surface and accepts one later rewrite, because the release gate
sits behind it - but the maintainer should make that call deliberately rather
than discover it when the synthesis is accepted.
