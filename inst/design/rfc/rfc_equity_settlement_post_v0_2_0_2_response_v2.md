# Type 2 Response v2: Equity Settlement After v0.2.0.2

**Status:** Second adversarial Type 2 review, read-only.
**Author:** Claude. **Date:** 2026-09-23
**Reviews:** `rfc_equity_settlement_post_v0_2_0_2_seed_v2.md`, superseding
findings in `rfc_equity_settlement_post_v0_2_0_2_response.md`
**Amended:** 2026-09-23 after maintainer challenge. Sections 1, 5 and 7 now
hold that the census defects gate the census, not the release. F1-F7 stand.

Not a specification, ticket cut, or implementation authority. No licensed
identifier, price or action value appears below; only published aggregates.

## 1. Verdict

The architecture in seed v2 is right and I do not want another seed revision
for it. Moving unit normalization upstream is the correct call, the layer
boundary in section 3 is drawn in the right place, and the `CASHFLOW` versus
`SETTLEMENT` distinction is now earned rather than asserted.

Moving normalization upstream did not hide unresolved assumptions in
principle. It did in practice, in two separable and fixable ways. The
`snapshot_units` assertion travels without the binding that would make it
checkable (F5), and the evidence that 22 events are convertible rests on a
method carrying one unguarded approximation and one vacuous validation (F2,
F3, F4). Neither is architectural, and neither moves a release boundary.
Both leave the number 22 unverified, which gates the census. Section 5 carries
that correction and the reasoning it replaces.

I withdraw my first response's most damaging finding in full. It was wrong.

## 2. What seed v2 gets right

**The layer boundary.** ledgr receiving canonical quantities plus an adapter
transformation-policy identity, and verifying shape, identity, completeness
and axis membership without recomputing a vendor adjustment, is the smallest
contract that survives a second vendor. B1 is correctly stated and its
falsifier is the right one.

**The refusal to reason from a stale bar.** The census requires an accepted
canonical bar at an exact reference session and fails closed otherwise. That
is why two in-axis events drop out. It is the most important discipline in the
operator; most implementations would have taken the last available bar.

**The three-tier split.** Tier 3 reaches the snapshot contract and tiers 1 and
2 do not. The split is real, not a device for making Tier 2 look cheap.

**The retreat from a basis knob, and atomicity.** One closed versioned
derivation per admitted subtype, labelled model basis and never tax basis, is
the right shape. Section 9's insistence that a multi-leg transition cannot
expose a prefix is correct, and far cheaper to design in than to retrofit.

**Candour about what 22 does not prove.** Section 6 does not oversell. My
objection is to the number itself, not to what the seed makes of it.

## 3. Findings

### F1. Withdrawn: the received nonmember has both visibility and an exit

My first response's finding that a settlement-created nonmember would be
invisible to the next decision and would have no exit path is wrong. Seed v2
section 4 challenged it and the challenge is correct. The evidence:

- `R/availability-provider-prepared.R:261-266` takes the nonzero held IDs,
  differences them against the member set, and appends them to the decision
  axis. A held nonmember is on the axis with `held = TRUE`, `member = FALSE`.
- `inst/design/contracts.md:345-350` binds that ordering as contract, not
  implementation detail.
- `inst/design/contracts.md:387-389` states that availability-aware targets
  may hold or exit a restricted ID and that unrestricted held nonmembers may
  reduce without reversing sign.
- `inst/design/contracts.md:429` registers a membership-change diagnostic and
  states that membership must never become an execution gate.

There is no exit problem and no call path to show. I withdraw the finding
without reservation. B5 is the correct bet and I could not falsify it.

I also checked the valuation half of the claim.
`R/accounting-replay.R:335` computes `colSums(positions * close_mat)` with no
`na.rm`, so one missing close would poison the whole pulse. It cannot happen:
`R/run-finalize.R:489-491` aborts with `ledgr_missing_bars` unless every axis
instrument has a close at every pulse. The axis is dense by construction, so
an in-axis recipient is priced at every pulse, not merely at the posting
session. That strengthens Tier 2 rather than weakening it.

### F2. The recipient factor is read at a different session than the parent

This is the substantive defect. The census computes the parent factor at the
unit-reference session and the recipient factor at the model-posting session.
Those are different dates for the acquisition categories.

The adjustment factor is a step function of date. `F(t)` is the cumulative
product of every split effective after `t`, so it jumps at each split date.
The conversion `R * F_recipient / F_parent` is only valid when both factors
are evaluated in the same epoch, because the vendor ratio delivers raw
recipient shares per raw parent share as of the event date. The recipient leg
therefore needs `F_recipient` at the event date.

When a recipient split falls inside the interval between the two sessions, the
canonical ratio is wrong by exactly that split factor. The operator will not
notice, because every input is finite and positive and the result formats
cleanly.

The census states the principle correctly while violating it. Its own
justification for failing two events closed is a refusal "to apply an
event-date ratio to a quantity expressed in another share epoch". That is what
the recipient leg does whenever the window contains a split.

There is a good reason for the choice: a spin-off recipient does not trade
before distribution, so its event-date factor does not exist. That makes the
posting session a necessary approximation, not an error. But an approximation
must be declared and guarded, and this one is presented as normalization.

**Falsifier.** For each of the 22, read the recipient factor at both sessions
and compare. Any disagreement falsifies that event's normalized ratio. If the
event-date factor does not exist, the event is approximated and must be
labelled as such, or fail closed the way the parent-side gate already does.

### F3. The factor is a rounded price quotient, never checked against a split

`F = closeunadj / close` is derived from two vendor-reported prices. Both are
rounded to a small number of decimals before ledgr or the census ever sees
them, so `F` is an estimate of the split factor carrying the relative error of
both operands. The error is worst exactly where it is least visible: on
low-priced instruments, where a half-cent of rounding is a large fraction of
the price.

That error propagates undamped into the canonical ratio and the canonical
cash. A quantity wrong by a fraction of a percent is an economic error no
downstream gate can detect, because the value is well-formed.

The true split factor is not an estimate. It is available exactly, as the
cumulative product of the pinned split values in the same accepted `ACTIONS`
table the operator already reads for its candidate rows. The census derives
the factor from prices anyway and never compares the two. I am not claiming
the 22 are wrong. I am claiming the method cannot tell you whether they are,
and that an exact method is already in the operator's hand.

**Falsifier.** Recompute every factor as a cumulative product of pinned split
values and compare against the price quotient under a tight relative
tolerance. Any event outside tolerance is not normalized.

### F4. The reported validation of the factors excludes nothing

The census reports, as evidence that the corrected run is sound, that "every
normalized factor was positive". `closeunadj / close` is positive whenever
both prices are positive, which is true of every accepted bar. The check
cannot fail. It is not evidence and should not be presented as part of the
reconciliation.

The other two reported checks are real and I credit them: canonical closes
reproduce their pinned source closes, and the checker reproduces both private
files byte-for-byte. Note what they establish. The first proves the bars and
the factors come from the same vendor pull. The second proves determinism.
Neither constrains the ratio. So the reconciliation as published contains two
sound vintage-and-determinism checks and zero checks on the quantity that
Tier 2 actually depends on.

### F5. The contract drops the binding that makes `snapshot_units` checkable

This is where moving normalization upstream did hide something.

`F` is not a property of an event. It is a property of a vendor pull. For a
fixed date, `F(t)` changes whenever a new split occurs after the pull, because
every adjusted close is rescaled. A canonical fact prepared against pull A is
therefore valid only against bars from pull A.

The census earns this explicitly. It joins bars to the pinned source rows by
source row number and asserts the canonical close reproduces the pinned source
close before any factor is used. That assertion is the whole reason
`snapshot_units` means anything.

Seed v2 section 3 lists what ledgr receives. The bar binding is not in the
list. A fact prepared against one bar vintage and ingested into a snapshot
built from another asserts `snapshot_units` truthfully by its own lights and
is silently wrong. Nothing in the proposed contract can detect it.

The fix is small and does not touch B1. Have the fact carry the sealed-bar
references it used, as instrument identity plus session, for the parent leg
and each recipient leg. ledgr then checks those bars are present in the
snapshot it is sealing. That is an identity check of exactly the kind section
3 already assigns to ledgr. It teaches ledgr no vendor code and no adjustment
formula.

### F6. Step 1 of the sequence has no owner

Section 4 calls the compiled event-envelope guard "separately bound" and
section 11 makes it step 1. It is not bound. No `tickets.yml` in any spec
packet contains the word `envelope`. The guard exists only as a proposal in
section 9 of an untracked audit document that I wrote, which explicitly says
it does not belong in the equity RFC.

I agree it does not belong here. But a plan whose first step is unowned work
is not sequenced, and this particular step is the one that stops the first new
economic event kind from being dropped in the compiled arm whenever
`compiled_accounting_model = "spot_fifo"` is active. Someone has to cut it.

### F7. Twenty-two is the entire evidence base, not a sample from it

Section 6 is honest that 22 does not prove semantics, timing, or basis. The
sharper problem is that 22 is not a sample of Tier 2 behaviour. It is all of
it. Section 13 requires reverse-split conversions, multi-leg spin-offs, mixed
cash-and-units acquisitions, lot chains taking a second leg, and events
learned late. The census does not report whether the 22 contain even one of
each. A gate reading "the adapter-normalized real evidence leaves the quantity
path bounded" can be satisfied by 22 events that all have the same shape.

## 4. Adapter/core boundary adjudication

The boundary is drawn correctly and I would not move it. ledgr must not learn
`closeunadj`, action codes, or adjustment arithmetic, and seed v2 is right that
my first response pushed the remedy too far downstream.

One correction to how the boundary is described. Seed v2 says ledgr verifies
shape, identity, completeness and recipient axis membership. That is
necessary and, as F5 shows, not sufficient: the verification set must include
the bar references the normalization consumed. Adding them keeps every vendor
concept upstream. The adapter still owns the formula; ledgr only checks that
the rows the adapter claims to have used are the rows it is about to seal.
With that addition I regard B1 as sound and unfalsified.

## 5. Release-boundary adjudication

**Tier 1 belongs in v0.2.0.2.** Omitted dividends are a silent economic error
across an observed population of 5,034 rows, existing behaviour is wrong
rather than honestly stopped, and no finding here touches the cash path in a
way the same contract addition does not fix. Section 6 is right that Tier 1
needs its own dividend-population witness and cannot borrow Tier 2's census.

**Tier 2 can stay in v0.2.0.2.** An earlier draft of this section said it
should leave; the maintainer challenged it and was right. F2, F3 and F4
establish that 22 is unverified, not that it is wrong. The epoch mismatch
bites only when a recipient split falls inside a window of one or a few
sessions, and the rounding error moves amounts slightly. Converting an
unverified count into a scope cut was an overreach.

The correction is a re-run of one operator in `ledgr-research`. It touches no
ledgr code and runs concurrently with Tier 1 implementation. Seed v2 already
gates Tier 2 on that evidence at step 6, so nothing needs to move.

The argument I underweighted runs the other way. B3 bets both tiers share one
source-fact family. Shipping Tier 1 alone asserts that bet rather than testing
it, binding schema, policy identity and unsupported vocabulary around cash.
Reopening a sealed schema is cheap pre-release; doing the hash, migration,
seal and compilation work twice is not.

Two things still bind. Step 6 admits "only the 22", tying the release to a
count produced by the method under challenge; state the gate as a property
instead. And the real scope question is the quantity workstream's size, above
all whether atomicity holds across resume, reopen and sweep. Not measured
here, and a maintainer call.

## 6. Scenario failures

Cases where the proposal produces a defensible looking result that is wrong or
unfalsifiable. All are additions to section 13.

1. **Recipient splits between the reference and posting sessions.** The
   canonical ratio is off by that split factor. Every gate passes. F2.
2. **Low-priced parent.** Rounding in the price quotient moves the cash per
   parent unit by a fraction of a percent with no diagnostic. F3.
3. **Fact prepared against a later vendor pull than the sealed bars.** A split
   between the pulls rescales every close. `snapshot_units` is asserted
   truthfully and every quantity is wrong. F5.
4. **Parent with no bar at the reference session but a bar the day before.**
   Fails closed today, correctly. It belongs in the required cases so a future
   convenience fix cannot quietly relax it.
5. **Dividend on an instrument whose later split is inside the run window.**
   Tier 1 cash needs Tier 2's epoch discipline and has no census behind it.
6. **Recipient already held from an ordinary fill.** Two lot chains merge
   under a model basis derivation. Section 13 names the lot chain; it does not
   require output to distinguish settlement-created lots from bought lots.
7. **New event kind reaches the compiled accounting arm.** Silent drop, not a
   refusal, until the guard in F6 is cut.

## 7. Recommended route

Full RFC synthesis, with the scope bound before synthesis begins rather than
inside it. Concretely:

1. Do not revise the seed again. Its architecture survives this pass.
2. Bind the canonical fact contract to carry the sealed-bar references for the
   parent leg and each recipient leg, and make ledgr verify them. F5.
3. Synthesize both tiers for v0.2.0.2, Tier 1 first, with Tier 1 carrying its
   own dividend-population normalization witness.
4. Cut the compiled event-envelope guard as an ordinary correctness ticket,
   outside this RFC, before Tier 1 ingestion lands. F6.
5. Return the census to `ledgr-research` for a corrected run: recipient factor
   in the parent's epoch or declared as an approximation, factors derived from
   pinned split values and compared against the price quotient, the positivity
   check replaced by one that can fail, and a subtype breakdown of whatever
   count survives.
6. Restate the Tier 2 gate as a property of the evidence rather than a count.
   Tier 2 implementation may start; it may not land until that gate passes.

What I could not falsify: B1, B3, B4, B5, B7 and B8. B5 I attacked directly
in my first response and was wrong. B3 is only tested if both tiers ship
together. B2 is falsified narrowly: the reproduction it describes has not been
run against an independent factor. B6 is untested; no derivation exists yet.

TYPE_2_DISPOSITION: ACCEPT_SEED_WITH_BOUND_CONDITIONS
