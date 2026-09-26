# Final Review: Strategy Context Surface And Helper Composability Synthesis

**Mode:** Type 1 final verification. **Date:** 2026-09-26
**Reviewer:** Claude. I authored seed v1 and v2, so this review checks whether
the synthesis preserved the response's corrections against my original framing,
not whether it agrees with me.
**Target:** `71c2a3ab61c0c4628557393d9632744a73700bf8`,
`rfc_strategy_context_surface_v0_2_x_synthesis.md`.
**Baselines:** D `289e13e`, I `b47b83f`. Citations below were checked against
the stated baseline.

## Verification performed

I reran the committed probe at D on R 4.6.1 / rlang 1.3.0. **All 41 recorded
observations reproduce byte-identically** against
`dev/spikes/strategy-context-surface/observations.csv`, so the evidence base is
portable across R minor versions, not an artifact of the response author's
environment. I sampled seven code and contract citations and all seven are
accurate at their stated baseline. I did not build a new harness or run a
package campaign.

Every numerical claim the synthesis binds as an acceptance check is backed by a
reproduced observation: all four formulations give `AAA=15, BBB=7`; member
allocation gives `AAA=6, OLD=2`; the manual formulation gives `AAA=5, OLD=2`,
confirming it is not a general replacement; explicit-none gives `AAA=0, OLD=2`;
the full-axis form errors on `OLD` with `ledgr_invalid_strategy_helper`, which
matches the synthesis's own error mapping.

**1. Constructor dispatch and alignment.** Sound. The dispatch premise holds at
runtime: the fold classes its own context (`R/fold-engine.R:610`), so a
strategy
receives a `ledgr_pulse_context` in both the dense fast path
(`use_fast_context <- !availability_active`, `R/backtest-runner.R:851`) and the
general path. I hunted for ordinary inputs with ambiguous meaning and the
principal one is closed explicitly: an unnamed payload of `length(M)` where
`length(M) < length(Daxis)` is rejected rather than guessed ("No recycling or
guessing a shorter member axis"). Omission versus `FALSE` for a held nonmember
is consistent, and a missing named member is bound as an error rather than a
subset declaration, with `ids` as the subset spelling.

**2. Portfolio intent and allocation.** Verified, including the distinction the
brief asks about. `ledgr_signal_return()` does substitute `NA` for inadmissible
members (`values[!admissible] <- NA_real_`, `R/strategy-helpers.R:95`), and
`ledgr_select_top_n()` does exclude missing scores and returns an empty
selection when none is available (`R/strategy-helpers.R:137-139`;
`contracts.md:617-623`). So an inadmissible member is **exited, not held**, and
the synthesis names that consequence, requires it documented as a
convenience-helper policy, and directs authors to guard and return `ctx$hold()`
instead. No implicit quality screen or financing policy has entered: the
constructor table states that no price, restriction, valuation-age or
orderability mask is added.

**3. Empty domains.** The three cases stay distinct, and the contradiction the
response found is real: `ctx$hold()` returns a valid empty named vector while
`ledgr_target()` and `ledgr_target_rebalance()` both reject the empty case.
Final-target completeness is not weakened - `ledgr_target(numeric(), universe =
c("AAA"))` still errors, and the fold's allowance remains availability-only
(`allow_empty = availability_active`, `R/fold-engine.R:689`, against
`ledgr_validate_strategy_targets(..., allow_empty = FALSE)`,
`R/strategy-contracts.R:34`). The prohibition on empty snapshot or config
universes prevents the dense case from arising, so section 4 does not
over-promise.

**4. Surface changes and inspection deferral.** Correct, and the deferral is
handled the way the brief requires: the synthesis states plainly that the
existing inspection sources "do not establish a replacement for the actual
availability-aware callback state," so no equivalence is claimed and no
replacement is designed here. It also retreats from its own author's removal
proposal, which is the right direction for a synthesis to be wrong in. The
`tradable()` predicate is described accurately at I (`admissible & priced`, with
a dense positive-finite-close fallback) together with its limitation.

**5. Acceptance criteria and teaching.** The gate is falsifiable and its
independence requirement is explicit: the documented expectation "must not be
generated from the observed fixture," comparison runs in both directions on
observable shapes rather than counts, and dense and availability variants
"cannot pass by checking only their intersection." The invalid detector from
seed v1 (fills down with equity unchanged) is gone, and no timing ratio or
member-count target is a gate.

## Nonblocking findings

**N1. The committed checker cannot run on the maintainer's R.**
`dev/spikes/strategy-context-surface/check.py:22-23` invokes `Rscript` with
`--slave`, which aborts with `0xC0000005` on R 4.6.1, the version AGENTS.md
names for local verification. The probe itself runs cleanly and its output is
identical, so this is harness portability, not evidence. *Smallest correction:*
replace `--slave` with `--no-echo`. Outside the synthesis; raised because the
spike protocol's diff-based checker should be runnable by the maintainer.

**N2. Two adjacent failures take different condition families.** "Known
nonmember selected TRUE, selected in `ids`, or assigned a weight" maps to
`ledgr_invalid_strategy_helper`, while "invalid or unknown names, missing M
entries" maps to `ledgr_invalid_strategy_type`. A nonmember ID is arguably an
unknown name, so an implementer could reasonably choose the wrong family. The
split is defensible - membership is policy, validity is type - and it matches
observed behavior. *Smallest correction:* one sentence stating that membership
violations are helper-family regardless of how the ID was supplied.

## Editorial

Section 2's fourth qualification is correct and the defect is mine: seed v2's
printed formulation C ends in weights and needs the final target constructor to
substantiate target parity. Fix belongs in the seed, not the synthesis.

## Disposition

The synthesis is coherent, precisely cited, and usable. It binds dispatch,
alignment, error families, empty-domain behavior, the position amendment and
the surface gate at a level of detail an implementer can work from, and its
acceptance checks name the defect each one detects rather than asserting that
unimplemented APIs already pass. It corrects both prior documents where they
were wrong, including its own author's inspection proposal and four
over-corrections in my withdrawal ledger. Neither nonblocking finding touches a
decision, a contract amendment or a detector.

PASS

---

# Focused Verification Of The Amendment

**Target:** `d9daa4d1bbfffe81180297a52c7baf4bc8e03d3f`, synthesis only
(+97/-27). **Date:** 2026-09-26. The PASS above stands for `71c2a3ab` and does
not cover predicate projection or zero-weight sizing; this section covers only
those changes and their consequences.

Both amended behaviours fix real defects that my original review missed. I
verified the `where` row and the error mapping and called them consistent; the
amendment was found by a strategy-authoring exercise, which is a method
citation-checking does not substitute for.

**Zero-weight sizing - confirmed in both modes.** The price loop iterates
`names(weights)` and resolves a price before consulting the weight value
(`R/strategy-helpers.R:282-300`), so a zero weight requires a usable close
while
omitting the ID does not. Executed at D on a dense source-level context with
`close = c(10, NA)`: weights `(AAA=1, BBB=0)` fire a spurious
`ledgr_invalid_target_price` warning, weights `(AAA=1)` alone do not, and both
produce `AAA=10, BBB=0`. Two spellings of one intent, identical targets,
different diagnostics. The availability half is structurally certain from the
same branch, which aborts rather than warns. The correction is a widening, so
it
cannot break a strategy that previously worked, and the synthesis states
plainly
that helper behaviour changes.

**Predicate projection - confirmed.** `ctx$vec$close` is an anticipated `NA`
carrier on the axis (the price loop tests `is.na(price)`), so
`where = ctx$vec$close > 100` yields `NA` at a held nonmember with no close. The
original rule rejected any `NA`, which would have made the documented predicate
example fail for an ordinary portfolio state. Projecting to M before checking
`NA` is correct, and the accompanying asymmetry is deliberate and coherent:
infinity is rejected anywhere, a missing numeric score stays meaningful and is
excluded by `select_top_n()`, and a missing logical decision on a member is
fail-closed rather than imputed.

**Budget arithmetic - exact.** `allocation_equity <- max(0, equity -
sum(abs(quantities * marks)))` (`R/strategy-helpers.R:258-272`) is the
amendment's
formula verbatim, and sizing is `floor(weight * equity_fraction * A / close)`.
NAV 100 with OLD exposure 40 gives A = 60, so AAA at close 10 yields 6 shares
at
weight 1 and `floor(3.6) = 3` at weight 0.6, matching the new gate row. The
consequence the amendment draws is right and matters beyond this cut: an
optimizer emitting total-NAV weights must convert before passing them here.

**Consistency.** The correction reached the places it had to. Section 6 binds
it
in both the Availability and Strategy amendment rows; section 7 adds separate
predicate-projection and zero-weight gate rows whose cases would fail against
current behaviour, which is the right property for a gate written before
implementation. My earlier N2 is resolved explicitly: an ID in Daxis outside M
is a known nonmember, not an unknown name. The three new citations check out -
`contracts.md:678-686`, `tests/testthat/test-strategy-preflight.R:82`, and the
referenced scheduler seed exists.

## Nonblocking finding

**N3. The member-side missing predicate stays fatal and needs a taught guard.**
The amendment fixes `NA` at nonmember positions, but a *member* with no current
close still makes `where = ctx$vec$close > 100` an error ("NA for AAA errors").
That is the correct fail-closed choice, since imputing `FALSE` would be the
silent negative selection this cut forbids. The cost is that the most natural
predicate an author writes is fragile in exactly the availability mode this RFC
exists to serve, and the same data gap is graceful through `values` and fatal
through `where`. *Smallest correction:* have the representative authoring
examples show the guard - `where = !is.na(ctx$vec$close) & ctx$vec$close >
100` -
and state the values-versus-where difference in the documentation row, so the
pattern is taught rather than discovered by hitting the error.

## Disposition

The amendment is accurate, correctly scoped to two behavioural changes plus
teaching, bound in the contract table, and covered by gates that detect the
uncorrected behaviour. It keeps scheduling, causal frames and helper-preflight
redesign out, and records the preflight boundary rather than silently exempting
it. N3 is a documentation obligation and touches no decision or detector.

PASS
