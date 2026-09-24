# Post-v0.2.0.2 Equity Settlement Inventory

**Status:** Third pass, read-only. Not an RFC seed and not a design.
**Correction:** the second pass asserted a wall that does not exist for
securities already inside the sealed snapshot. Sections 6, 8, 10 and 13
carry the correction; the maintainer found it.
**Date:** 2026-09-23.
**Tree:** v0.2.0.2 after cut 2 (accounting core) and cut 3 (ingestion) closed.

## 1. Purpose and method

The accounting-core cycle showed why an inventory precedes a seed: its census
refuted the roadmap's "eight independently written FIFO replay loops" premise
before anyone designed against it. This document does the same job for equity
settlement. It records what the tree actually does today, what the evidence
layer actually carries, and which of the census requirements the current
architecture can and cannot express.

Method: read the landed accounting core, the ledger schema, the availability
fact constructors, the equity projection, and the corporate-event research.
Every claim below cites a file and line and was read at this tree.

**What this is not.** It proposes no semantics, no event vocabulary and no
ticket. It does not decide anything. Section 8 lists the premises a seed
would otherwise inherit unexamined, which is the part worth arguing with.
Sections 9 to 11 were added in a second pass, after the first pass named them
as gaps. Section 9 proposes one small ticket that is not equity work.

## 2. The substrate after cut 2

Cut 2 replaced seven driver loops with one preparer and one replay. That is
the surface equity settlement must extend, and it is much narrower than the
surface the same work would have faced before the cut.

**The persisted vocabulary is two event types.**
`R/db-schema-create.R:214` now reads
`event_type TEXT NOT NULL CHECK (event_type IN ('FILL','CASHFLOW'))`. `FEE`
was admitted by the schema before cut 2 and never produced; LDG-2781 removed
it. `side` is still `CHECK (side IN ('BUY','SELL'))` at `:216`.

**The replay recognises three operations**, assigned in
`ledgr_prepare_accounting_events()` at `R/accounting-replay.R:135-177`:

| op | event_type | discriminator | effect |
| ---: | --- | --- | --- |
| 1 | `FILL` | side `BUY` or `SELL` | lot open or close, realized PnL, cash and position deltas |
| 2 | `CASHFLOW` | none | cash delta only; no lot and no position effect |
| 3 | `CASHFLOW` | `meta$source == "opening_position"` | seeds a lot at a supplied cost basis and position |

**Everything else fails closed.** `R/accounting-replay.R:172-177` aborts with
`Unsupported accounting event_type` for any other value. Each operation
validates its own inputs before dispatch: FILL requires positive qty and
price, non-negative fee and a non-empty instrument; operation 3 requires a
finite `position_delta` and `cost_basis` and a non-empty instrument.

**The operation code has exactly two consumers**, both in the same file: the
replay loop records fill legs only for operation 1 (`:252-257`), and
`ledgr_accounting_fills_from_replay()` selects `operation == 1L` at `:352`.
Nothing else in `R/` branches on it. A new operation therefore has a small
blast radius inside the replay and a large one in the projections, which is
the opposite of the pre-cut-2 situation.

## 3. The two extension points, and their costs

A new economic event can enter in exactly two ways today.

**(a) A new `event_type`.** Requires a schema CHECK change, which is a
persisted-schema change and therefore a durable-identity decision, plus a new
operation branch and new validation. Every reader that assumes two types must
be revisited.

**(b) A new `meta$source` discriminator on `CASHFLOW`.** This is the route
`opening_position` already took, at `R/fold-event-buffer.R:113-119`, which
writes `list(source = "opening_position", cash_delta, position_delta,
cost_basis, opening_position = TRUE)`. It needs no schema change, and the
preparer already reads `meta[[i]]$source` at `:154`.

Route (b) is cheaper and has precedent. Whether it is right is a seed
question, not an inventory one, but the inventory can say this much: route (b)
puts the economic vocabulary inside an opaque JSON field that the schema does
not constrain, and the tamper boundary for `meta_json` is the snapshot hash
rather than a CHECK constraint.

## 4. What the evidence layer already carries

Corporate-action evidence enters through availability facts, not through the
ledger. `ledgr_facts_lifetime()` at `R/availability-facts.R:294-315` accepts
`instrument_id`, `effective_from`, optional `effective_to`, and `assertion`
constrained to `known_active`, `known_inactive` or `unknown`.

**`terminal_event` is free text.** `R/availability-facts.R:315` reads it with
`ledgr_fact_optional_character(df, "terminal_event")`. There is no controlled
vocabulary, no validation, and no mapping from a terminal-event label to an
economic outcome. The adapter supplies a string; ledgr records it and uses
only its non-emptiness.

That is the single most important structural fact in this inventory. The
evidence layer knows *that* an instrument terminated and carries the adapter's
label for why. It does not know, and cannot currently express, the *terms*:
no exchange ratio, no consideration split, no entitlement or payment clock.
The census confirms the data side has the same gap.

## 5. The honest stop today

When a held instrument reaches a terminal event, the fold stops rather than
guessing. `R/fold-engine.R:398-404` collects held ids with a non-empty
`terminal_event`, sets `terminal_status <- "INCOMPLETE"` and
`stop_reason <- "terminal_settlement_unsupported"`.

`contracts.md:434` binds the meaning: "valuation stop | preserve the holding;
never fabricate cash settlement". `contracts.md:419` binds the related
`lifetime_inactive` decision restriction the same way: "allow hold or exit;
never fabricate settlement".

This is the behaviour equity settlement would replace, for supported cases
only. The contract line is the thing a seed must not quietly weaken: whatever
ships, an unsupported or under-specified event must still stop honestly
rather than invent a number.

## 6. Census requirements against the current architecture

From `inst/design/research/Sharadar-Corporate-Event-Evidence.md`, over 563
instruments and 757 sessions in 2019-2021.

| outcome | census count | transforms | expressible today? |
| --- | ---: | --- | --- |
| cash dividend | 5,034 events, 457 instruments | cash only | operation 2 already carries a pure cash delta. Missing: entitlement and payment clocks, which the data also lacks. |
| split | 23 events, 22 instruments | quantity and basis | not expressible. Bars are already split-adjusted, so applying a split to quantity would double count. |
| cash acquisition | part of 23 target acquisitions | position to cash, realized PnL | close to a `SELL` fill at the consideration price, but the terms are not evidenced. |
| stock acquisition | 11 of 23 | position to a different position | depends on the recipient. Not expressible when the acquirer is outside the sealed snapshot. Unexamined when it is inside: see section 10. Terms are not evidenced either way. |
| mixed acquisition | 6 of 23 | both | same, plus fractional entitlement. |
| spin-off | 24 parent events, 23 instruments | basis split, new position | same, for the child security. |
| delisting | 24, all in-window endings | terminal | stops honestly today. |
| ticker change | 30 | identity only | prices and identities reportedly continue; no account effect. |

**Valuation binds only outside the snapshot.**
`ledgr_accounting_equity_from_replay()` at `R/accounting-replay.R:335` computes
`positions_value <- colSums(positions * close_mat)`, where `close_mat` is the
instrument-by-pulse close matrix built over the execution universe. Section 10
establishes that for an availability-aware experiment that universe is every
instrument in the sealed snapshot, so a received security that is already in
the snapshot has both a row and prices.

The constraint is therefore narrower than it first appears. It binds when the
recipient is absent from the snapshot: then there is no row, no price, and the
census's requirement to value "received non-member securities" cannot be met
without reaching the snapshot contract. Note that "non-member" in the census
means not a current index member, which is not the same as absent from the
snapshot; the two were conflated in this document's second pass.

## 7. Constraints a seed inherits whether or not it names them

1. **Adjusted-unit basis.** Current quantities and split-adjusted prices form
   an adjusted-unit model. Cash amounts and conversion ratios must use a
   compatible basis. Moving to raw-share accounting is an interpretation
   decision, not a cleanup.
2. **Four distinct clocks.** Entitlement, effective, knowledge and payment
   times differ. The census has ex-dates and amounts but not payment dates.
3. **Terms are not evidenced.** Twenty-one acquisitions resolve to one
   counterparty without establishing exchange ratios. Spin-off entitlements
   need supported terms. One worked acquisition has public terms whose
   `assume_effective` knowledge time is an explicit assumption.
4. **Unsupported must stay honest.** `contracts.md:434` and the existing
   `terminal_settlement_unsupported` stop.
5. **Snapshot identity.** Adding a persisted event type is a schema change;
   `meta_json` content already feeds the snapshot hash.

## 8. Premises worth testing before the seed is written

The accounting-core cycle cost a correction round because a premise survived
into the seed unexamined. These are this cycle's candidates.

- **"ledgr owns account effects and replay; adapters supply supported terms."**
  The census asserts this division. It has not been tested against the fact
  constructors, which today carry no terms at all, only a free-text
  `terminal_event`. Where the term-bearing fact family would live is unknown.
- **How many instrument-creating events land inside the snapshot.** This is
  the open empirical question and it is answerable from the same Sharadar data
  that produced the census. Of the 11 stock acquisitions, 6 mixed acquisitions
  and 24 spin-off parents, the census does not say for how many the acquirer
  or child is itself in the 563-instrument population. That partition decides
  how much of tier 2 in section 10 is reachable at all. This document's second
  pass asserted all of them needed the broad architecture change; that was an
  inference from an error, not a measurement.
- **"Cash-only is the cheap tier."** It is the smallest, not the cheapest. The
  replay already carries a cash delta, but there is no term-bearing fact
  family, no entitlement or payment clock, no consideration price, no rule for
  when an event becomes knowable, and no production path from evidence to
  accounting events. Dividends have ex-dates and amounts but no payment dates.
  Every tier needs a real semantic design.
- **"Accounting-core consolidation is the prerequisite."** It is done, and it
  helped. The remaining constraints it did not touch are the term-bearing
  evidence gap in section 4 and, for tier 3 only, the snapshot boundary.
- **Whether route (b), a `meta$source` discriminator, is adequate** for a
  vocabulary that must eventually carry terms and clocks, or whether that
  pushes typed economic data into an unconstrained JSON field.

## 9. The compiled path: a silent-drop risk, not a present defect

Checked after the first pass. The compiled accelerator is narrower than
expected and nothing is wrong today, but its shape makes the first new event
kind dangerous.

**It is well gated.** `ledgr_require_compiled_spot_fifo_dispatch()` at
`R/compiled-spot-fifo.R:62-91` returns early unless the model is `spot_fifo`,
then aborts unless the fold is buffered and the output handler supports
compiled batches. `ledgr_run_compiled_spot_fifo_batch()` aborts if any fill
side is outside `BUY`/`SELL`. It never sees a CASHFLOW: opening positions are
emitted by `R/fold-event-buffer.R` before the fold, not in the accounting
stage.

**The risk is the branch shape.** The accounting stage is a two-armed
`if (use_compiled_spot_fifo) { ... } else { ... }` at
`R/fold-engine.R:815-841`, and both arms iterate fills only. The compiled arm
additionally runs only when `length(compiled_fills) > 0L`. A new per-pulse
economic event, a dividend at a pulse with no trade for instance, has no place
in either arm. If it were added to the canonical R arm alone it would be
silently dropped whenever `compiled_accounting_model = "spot_fifo"` is active.

**What protects that today is fixture-dependent.** LCL-0006 is canonical-R
versus compiled differential parity, detected by LTB-0006, LTB-0013 and
LTB-0014. It would catch a dropped event kind only if that kind were also
added to the differential fixture. Nothing structurally forces the two arms to
consume the same event set.

**Proposal, and it does not belong in the equity RFC.** Give the pulse plan an
explicit event-kind set, today just `fill`, and assert at the compiled
boundary that it contains nothing outside the compiled envelope, aborting with
the existing `ledgr_compiled_spot_fifo_unavailable` class. That converts a
silent drop into the refusal the rest of the compiled gate already performs.
Pair it with a source guard, in the cut 4 style, asserting that the two arms
read the same event sources, so a future kind cannot be added to one arm only.
The assertion alone is not enough: someone could add a kind to the plan and to
the R arm and still forget the envelope check.

This is a small correctness ticket that should land before equity work starts,
because equity is what introduces the second event kind.

## 10. The axis is fixed, but it is the whole snapshot

This section replaces a wrong claim. The second pass said a received security
"cannot enter the axis during a run, whatever the ledger says", and treated
that as architectural. The first half is true and the conclusion does not
follow.

**What is fixed.** `exp$universe` is resolved once at experiment construction
and never re-derived. Walk-forward passes the same value to every fold and to
`ledgr_lot_state_asof()` at `R/walk-forward.R:260` and `:918`, and the fold
takes `instrument_ids <- execution$instrument_ids` at `R/fold-engine.R:202`.
The axis cannot grow mid-run.

**What it is fixed to.** `R/experiment.R:247-251` reads:

```r
execution_universe <- if (is.null(universe_rule)) {
  ledgr_experiment_normalize_universe(universe, universe_all)
} else {
  universe_all
}
```

`universe_all` is every row of `snapshot_instruments`
(`R/experiment.R:338-349`). So for an availability-aware experiment, the
physical execution axis is the entire sealed snapshot, not the current member
set. Membership governs what may be traded; the axis is wider.

**Consequence.** A received security that is already in the snapshot has an
axis slot and, through the same `instrument_ids`, prices. It need not be a
member and need not ever have been tradable. Neither a dynamic axis nor a
changed snapshot contract is implicated for that case.

**Three tiers, not two.**

| tier | recipient | blocked by |
| ---: | --- | --- |
| 1 | none; cash only | nothing structural. Blocked by missing terms and clocks, section 4. |
| 2 | already inside the sealed snapshot | nothing structural in axis or valuation. Needs quantity and basis transformations, and evidenced terms. Unexamined. |
| 3 | outside the sealed snapshot | no axis slot and no prices. Reaches the snapshot contract and an instrument master. Defer. |

The census does not partition the instrument-creating events between tiers 2
and 3. Until it does, no one can say how much of tier 2 is reachable, and this
document should not be read as claiming otherwise.

## 11. Prior art already in the repository

The repo carries more of this than the first pass credited, and it is directly
on point. Both documents should be read before the seed.

`inst/design/research/Cross-Asset-Accounting-Critical-Events.md:103` already
states the minimal schema for identity mutation: parent instrument, child or
new instrument if any, effective date, venue status change, ownership
conversion ratio, cash-in-lieu terms, and terminal payout semantics. That is
exactly the gap section 4 found in `terminal_event`. It also names four
categories worth reusing as vocabulary: instrument-identity mutation, explicit
quantity event, explicit cash event, and source/vendor event record only.

`inst/design/research/ledgr_ragged_universe_prior_art_review.md` surveys how
other engines handle it.

| system | what it does | relevance |
| --- | --- | --- |
| LEAN | separates dynamic membership, security identity and per-security calendars; `Symbol` survives ticker changes via map files; removed securities stay active while held; corporate actions emitted as events | the closest precedent for an instrument axis that changes without destroying economic state |
| zipline-reloaded | at `auto_close_date` cancels orders and closes the position, falling back to the last sale when the current price is NaN | the precedent for what ledgr has already decided not to do; the review calls it "economically wrong for bankruptcy, acquisition, or an illiquid delisting" |
| NautilusTrader | instrument status handling, with an open issue on the same ground | partial |
| vectorbt | symbol key is the identity surface; no dated listing, alias or corporate-action master found | shows the cost of not modelling it |

The review also records that no surveyed engine has mature first-class support
for instrument-creating events in crypto, and treats that absence as a result
rather than a gap in the survey.

The useful conclusion for a seed: LEAN is the precedent for letting the axis
change; Zipline is the precedent for the fabrication ledgr's
`terminal_settlement_unsupported` already refuses. Neither removes the need to
decide where a received security's marks come from.

## 12. What this inventory has not yet covered

Stated plainly, because the accounting-core inventory's first pass missed six
readers and claimed completeness it did not have.

- No site-by-site census of every consumer of `positions`, `equity` or
  `realized_pnl` across the projections. Section 2's operation-code count is
  complete; the projection-side count is not.
- The cross-asset catalogue and the prior-art review are now read for the
  identity-mutation question only, in section 11. Their other categories,
  time-accrual costs, options deliverables and crypto non-trade events, are
  not covered and the census says they are not established requirements.
- Walk-forward and the fixed axis are covered in section 10. Sweep is not:
  whether a mid-run axis change is expressible through the memory handler and
  the worker boundary was not examined. Resume and reopen behaviour for a new
  event type was not examined either.
- The compiled path is covered in section 9 for the drop risk. Whether the C++
  kernel itself would need to know about a new operation was not examined,
  because the R-side envelope refuses before it is reached.
- No measurement of anything. This is a structural inventory.

## 13. Correction record

The second pass asserted, in section 10 and by inference in section 6, that a
received security cannot be valued or held because the instrument axis is
fixed and the price matrix covers only what the axis contains. Both halves of
that are true. The conclusion drawn from them was wrong, because the axis is
fixed to the entire sealed snapshot, not to the tradable member set, which
`R/experiment.R:247-251` makes plain and this document did not read closely
enough on the second pass.

Three things followed from the error and are withdrawn:

1. that instrument-creating events necessarily require a changed snapshot
   contract and a dynamic axis;
2. that the roughly forty such events in the census all fall on the far side
   of that wall;
3. that the genuinely bounded subset is therefore dividends and cash
   acquisitions.

What survives: the wall is real for tier 3, recipients absent from the
snapshot. The term-bearing evidence gap in section 4 is unaffected and binds
every tier. The compiled-path risk in section 9 is unaffected.

The maintainer found this. It is recorded here rather than silently patched,
because the same error class, asserting a boundary from an unread premise, has
now cost this project three corrections: six missed ledger readers in the
accounting-core inventory, a forced-text column set that covered three names
where seven were needed, and this.
