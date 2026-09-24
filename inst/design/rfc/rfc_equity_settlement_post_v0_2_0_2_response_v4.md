# Type 2 Response v4: Paired Equity-Settlement Design

**Status:** Fourth adversarial Type 2 review, read-only. Binds nothing.
**Author:** Claude. **Date:** 2026-09-23
**Reviews:** ledgr seed v4 and the Sharadar producer specification v0.1.0.

No licensed identifier, price or action value appears below.

## 1. Verdict

The direction is right. The paired boundary is drawn well, the producer
specification is a genuine vendor-neutral contract rather than a ledgr
export, and the honesty apparatus around gross cash is the best work in this
cycle.

Two structural claims are not established by the evidence cited for them,
and both would be found late and expensively.

The one-row `SETTLEMENT` unit is unproven because the spike replaced the
code that would have falsified it. And static axis closure collides with an
existing hard requirement that every axis instrument have a bar at every
pulse, which the closure spike did not measure.

Neither is fatal to the design. Both change what has to be built.

## 2. What the two spikes establish, and what they do not

**The atomic spike establishes** that the current lot carrier can consume
parent lots, create recipient lots, preserve a caller-supplied basis
allocation, and refuse malformed groups before append. That is real and it
retires the earlier RED result correctly.

**It does not establish that one persisted row suffices.** The prototype row
carries `position_delta = 0` and a single `instrument_id`, the parent, with
the legs nested inside `meta_json`. Production reconstructs positions by
cumulative sum of `position_delta` grouped per instrument
(`R/accounting-replay.R:300-308`), and that reconstruction feeds
`ledgr_accounting_equity_from_replay()` and the whole equity curve. Against
the prototype row it would return zero for every instrument.

The spike did not hit that. It replaced `ledgr_accounting_positions_at_pulses`
with a version reading a `positions_after_matrix` its own replay built, and
derived positions from `next_lots$net_by_inst` instead of from the event
stream. The reader was changed to fit the writer.

So the inventory's deletion from the working theory, that a multi-leg
transformation necessarily requires several persisted rows, is not
earned. It was made true by substitution.

**The closure spike establishes** that every resolved outside-axis recipient
in the observed window had an accepted canonical bar at its posting session,
a positive normalization factor, and coverage to the required horizon, and
that the result is failure-sensitive under gutting. That is a real and
well-run measurement.

**It does not establish that those recipients can join a sealed axis.** See
F2. Posting-session presence and horizon coverage are weaker than what the
consumer requires.

Neither spike touched cash consideration, basis derivation, fractional
units, or the two unresolved recipients. Both say so.

## 3. Findings

### F1. One-row `SETTLEMENT` changes reconstruction, not just vocabulary

Seed v4 section 7 presents the choice between `SETTLEMENT` and alternatives
as event vocabulary. It is not. Under the current schema an event row has one
`instrument_id` and one `position_delta`, and every downstream position and
equity surface derives from summing the second grouped by the first.

A settlement affecting one parent and one or more recipients has two or more
instruments. One row cannot deliver a position delta to two instruments. So
adopting the one-row unit requires replacing the per-instrument
reconstruction with something that parses a nested payload, in every place
that reconstruction is used: replay, equity, derived state, run finalize,
fold reconstruction, and sweep.

That is a much larger change than the seed describes, and it is load-bearing
for correctness rather than for tidiness. A nested payload also removes the
ability to ask which events touched an instrument without decoding JSON,
which the lifetime `terminal_event` experience already showed is a trap.

**The smaller alternative.** Persist the group as one row per affected
instrument, each carrying its own `instrument_id` and `position_delta`, all
sharing one settlement group identity and one source-fact identity. Validate
the whole group and construct the complete successor state before any append,
exactly as the spike already proved at that boundary, then append the rows in
one call. Replay gains one invariant: a group is applied only if every row of
it is present.

This keeps every existing reconstruction path working unchanged, keeps
per-instrument queryability, and keeps atomicity where the spike measured it.
It costs one group-completeness check and a duplicate-prevention key on the
group identity.

Whether the event type is named `SETTLEMENT` then becomes what the seed
already correctly said it should be: a question to settle after the semantics
exist, not before.

### F2. Static axis closure collides with the dense close-matrix requirement

`R/run-finalize.R:486-492` builds the instrument-by-pulse close matrix and
aborts with `ledgr_missing_bars` unless each axis instrument has exactly one
bar for every pulse in the window. I verified this while reviewing seed v2;
it is why an in-axis recipient is priced everywhere rather than only at its
posting session.

The closure spike measured that every recipient had a bar at its posting
session and reached the required horizon. That is a different and weaker
property. A recipient that begins trading inside the window, which is the
normal case for a spin-off child and common for a newly listed acquirer, has
no bars before it existed. Placing it on a sealed axis therefore aborts the
run rather than valuing it.

Three ways out and none is in either document. Back-fill pre-listing bars,
which fabricates prices and the seed rightly forbids elsewhere. Start every
window after the last recipient's listing, which is not a research
constraint anyone would accept. Or relax the density requirement, which is a
contract change with its own review and reaches the valuation semantics of
every instrument, not just recipients.

This is the finding that most changes what gets built, and it is cheap to
settle: build one synthetic snapshot containing a mid-window-listed
instrument and load it.

### F3. The closure's two safety properties are asserted, not tested

Static closure is legitimate preparation rather than future knowledge, and I
want to be clear that I checked rather than assumed. Membership governs the
decision axis; a non-member, non-held recipient does not appear to the
strategy (`R/availability-provider-prepared.R:261-266`), does not enter
sizing, and contributes nothing to equity at zero quantity. Once a settlement
lands the recipient is held and becomes visible, which is correct. Building a
snapshot with hindsight about its date range and contents is what building a
snapshot is.

That argument depends entirely on two properties, and neither is tested.

**Membership invariance.** The producer specification and the seed both state
that closure leaves membership and tradability unchanged. Nothing measures
it, and no case in the section 10 gate covers it. If a membership rule is
ever evaluated over the snapshot instrument set rather than over sealed
membership facts, closure silently changes what is tradable, and that is real
look-ahead contamination. The gate needs one case: the same experiment over a
closed and an unclosed snapshot produces identical membership and identical
fills up to the first settlement.

**Closure transitivity.** Neither document says whether closure is computed
to a fixed point. A recipient that is itself acquired inside the window needs
its own recipient on the axis. In a three-year window over this population it
may not arise. Over a research horizon it certainly does, and the failure is
the same abort as F2 but later and less obviously.

### F4. Upstream-first sequencing hides F2 until the last step

Section 11 implements the Sharadar grouped facts and static axis closure at
step 3, and the ledgr consumer at steps 4 through 6, with the real gate at
step 7. If F2 holds, step 3 produces snapshots the consumer cannot load, and
nothing discovers that until step 7.

The boundary itself is not circular. The producer specification's ownership
table is clean and B2's falsifier is the right test. But sequencing that puts
all the producer work before any consumer contact is only safe when the
consumer's constraints are known, and one of them is not.

## 4. What v4 gets right, including where I was invited to attack

**Gross cash is honest enough to ship.** Two declared posting conventions
with no implicit default, both entering experiment identity, with payment
time reported as unavailable rather than assumed, and withholding named as
unavailable rather than zero. This is exactly the bound the maintainer set
and it is implemented rather than gestured at. I have no attack on it.

**One-recipient nonrealizing carryover is defensible, and less dangerous
than it looks.** The brief asks whether it disguises taxable acquisitions
under a convenient label. The tax characterization genuinely is unavailable,
and the seed says so. What matters more is that the choice barely affects the
product. Carryover and realization differ only in the split between realized
and unrealized profit, never in total equity, because equity is position
times price either way. Nothing in sizing or risk keys on cost basis. The
exposure is confined to reporting, and the label covers it. I decline the
invitation.

**The producer specification is stable source evidence, not a ledgr export.**
Its ownership table gives ledgr every modelling decision and keeps every
vendor decision upstream. Stating that acquisition time is not historical
knowledge time is the kind of thing a premature schema does not say. Storing
no guessed leg for an incomplete event is the correct reading of response v3.

**The refusal to over-reach on feasibility.** Section 14 rejects broad
support merely because the primitive works, and names that the spike accepted
basis fractions rather than deriving them. That is the discipline the whole
cycle has been trying to reach.

**Scope against cost.** Dividends alone would justify this work; they are the
largest systematic error in the package for equity research and they
compound. The stock-exchange case rides on infrastructure the dividend path
needs anyway. The governance cost is the four-seed cycle, which is real, but
it is sunk and it produced two genuine reversals.

## 5. Both designs through the required cases

| Case | Seed v4 | Alternative |
| --- | --- | --- |
| Missing payment time | Declared convention, unavailability reported | Same, unchanged |
| Withholding | Gross, labelled, not zero | Same, unchanged |
| A later split | Adapter normalizes to snapshot units; standing findings F2-F5 still condition this | Same, unchanged |
| Taxable stock acquisition | Carryover, labelled research model; equity path unaffected | Same, unchanged |
| Spin-off | Refused, parent-retained basis allocation | Refused, same reason |
| Unresolved recipient | Refused before execution | Refused, same |
| Interruption and resume | One row replayed once; reconstruction path unproven | Group applied only if complete; existing reconstruction unchanged |
| Compiled execution | Envelope refuses; prerequisite unowned | Same, unchanged |

The designs differ on one row. Everything else in seed v4 I am adopting
rather than improving.

## 6. Where my alternative fails

Multi-row grouping makes duplicate prevention harder, not easier. A partially
written group after an interruption must be detectable, which means the group
identity and expected row count have to be persisted somewhere a reader can
check before applying. The one-row design gets that for free.

It also multiplies rows in the ledger for a single economic event, which
makes a naive event count misleading and any per-event reporting need to
group before it reports.

And I have not run it. The atomic spike proved validate-then-apply at the
boundary, not multi-row append atomicity through the durable handler. My
alternative inherits the same evidence gap I am charging seed v4 with, one
step further along.

## 7. Route

The seed needs one change, F1's serialization, and that is small. F2 is not a
seed question at all; it is an open empirical question with a cheap answer,
which makes it a bounded spike under the routes section rather than another
seed round.

My recommendation is to charter a one-question spike on whether a
mid-window-listed instrument can join a sealed axis at all, revise the seed's
section 7 to the multi-row group, add the two missing gate cases from F3, and
carry the rest to synthesis unchanged. If the spike says density is
relaxable, static closure survives as written. If it does not, the closure
scope shrinks to recipients already trading at window start and the seed
needs that boundary stated.

I have marked this REVISE_SEED rather than PROCEED_TO_SYNTHESIS because F1
changes what is built and F2 may change what is possible. If the maintainer
judges the serialization change bindable in synthesis, the minimum that
cannot be bound there is the density question, and it should be answered
before step 3 of section 11 regardless of the disposition.

TYPE_2_DISPOSITION: REVISE_SEED
