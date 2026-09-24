# Type 2 Response: Equity Settlement After v0.2.0.2

**Mode:** Type 2 adversarial response to
`rfc_equity_settlement_post_v0_2_0_2_seed.md`.
**Reviewer/date:** Claude, 2026-09-23.
**Bias, stated first.** The corrected census makes Tier 2 newly plausible, and
a reviewer who just had a boundary claim overturned is tempted to overcorrect
in the other direction and wave the new evidence through. I also wrote the
inventory whose section 10 error the maintainer caught, which biases me toward
accepting whatever replaced it. I have tried to correct for both by testing the
census operator rather than reading it, and by attacking the seed's strongest
claim rather than its weakest.

## 1. Verdict

**REVISE_SEED.** The source/policy separation is right and reusable, and the
corrected census is real: I reproduced its arithmetic and its operator does
what it says. But the seed moves Tier 2 into this release on an evidence base
that never tested the one thing Tier 2 uniquely needs, and it couples the
vocabulary decision to the boundary decision so that accepting Tier 2 also
buys a schema change that Tier 1 does not require.

Two findings are blocking and neither is wording. The first is a missing
unit-basis invariant that the census cannot see. The second is a trap state
for received non-members that collides with an existing contract.

## 2. What the corrected census actually establishes

I verified the load-bearing aggregates against the tracked operator and the
redacted report. They hold and they reconcile.

- 11 stock + 6 mixed + 24 spin-off parents = 41 registered candidates.
- 41 - 24 in-axis = 17 outside-axis or unresolved, matching the reported row.
- The operator does validate the pinned `ACTIONTYPES` meanings before reading
  any value (`23_census_equity_settlement_tier2.R:137-164`) and aborts if the
  pinned meaning changed. The withdrawal of the "opaque value" claim is sound.
- `daily_model_candidate` requires documented terms, `inside_axis`, a bar on
  the model posting session, and that the recipient is not the parent
  (`:491-495`). That is a defensible conjunction.

**What the counts prove.** That Sharadar supplies action-specific
consideration values for every registered candidate, that 39 have resolvable
recipient identities, and that for 24 the recipient sits inside this
563-instrument axis with an accepted price at the posting boundary. The seed is
right that no ratio, cash amount, recipient or price has to be invented for
those 24.

**What they do not prove, and the seed reads them as if they did.**

*The 24 is a property of this universe, not of the event population.*
`population` is the distinct instrument set of the accepted membership parquet,
asserted at 563 (`:118-126`). "Inside axis" therefore means "happened to also
be in this particular 563-name snapshot." A user running a 100-name universe
would see a far lower in-axis rate on the same events. The seed presents 24 as
evidence that "Tier 2 fits"; it is evidence that Tier 2 fits *wide* snapshots.
Section 4 should say so, because it changes who the feature is for.

*Nothing in the census tests convertibility.* Six checks are listed and all six
concern existence: meanings, legs, identity, axis, positive values, price at
posting. The operator contains no split or adjustment logic at all; every
`split` hit in it is R's `split()` or `strsplit()`. See finding F1.

*No portfolio-impact weighting.* The census counts events, not exposure.
`Sharadar-Corporate-Event-Evidence.md` reports that the retained runs cross 145
dividend events against suppressed low-count spin-off and acquisition exposure.
The seed never sets 24 candidate events against 5,034 dividend events when
arguing what belongs in this release.

## 3. Strongest case for the seed

Stated properly, because the rest of this response argues against it.

The three-layer separation of vendor fact, model policy and broker-exact fact
is the best idea in the document. It is what lets ledgr say something useful
about an event whose legal record it cannot reconstruct, without laundering
one into the other. The requirement that a policy-derived value be
distinguishable in identity and output from a vendor fact (section 5) is the
right test, and it is stronger than what most engines do: the prior-art review
records Zipline closing positions at a stale last-sale price with no such
distinction.

The machine-readable unsupported classification in section 8 is also a genuine
product improvement independent of any tier. Today an unsupported event is a
run that stops; under the seed it is a run that stops *and a caller who knows
why before running*. That should ship whatever the boundary decision is.

And the structural claim is correct. I re-verified `R/experiment.R:247-251`
and `:338-349`: the availability-aware axis is the whole sealed snapshot, so an
in-snapshot recipient genuinely has a slot and prices. Tier 2 is reachable.
Reachable is not the same as ready.

## 4. Adversarial findings

### F1 — Blocking, architecture. The unit-basis invariant is untested.

**The claim.** Sharadar `acquisitionstock` and `spinoff` values are recipient
shares per parent share (seed section 4). ledgr holds split-adjusted
quantities: the adapter's own casebook binds "vendor-native split-adjusted
OHLCV evidence" and forbids treating `closeadj` as executable OHLCV
(`ledgr.sharadar/R/semantic-casebook.R:283`).

**The failure.** A vendor ratio stated per parent share at the event date is in
the share count that existed *then*. A split-adjusted series is scaled to the
build epoch, so a holding of `Q_adj` at event date `T` is `Q_adj / s_parent`
real shares, where `s_parent` is the parent's cumulative split factor from `T`
to the epoch. The received quantity in the recipient's own adjusted units is
`R * (Q_adj / s_parent) * s_recipient`. Computing `R * Q_adj` is wrong by
`s_recipient / s_parent` and silently so. The census window contains 23 splits
across 22 instruments, and the operator never checks whether any coincides with
a Tier 2 parent or recipient after its event date.

**Why this is not wording.** Seed section 12 declines to "change adjusted-price
policy" while section 6 proposes recipient quantity deltas and basis movement
that depend on exactly that policy. `Sharadar-Corporate-Event-Evidence.md`
already warns that "cash amounts and security-conversion ratios must use a
compatible unit basis" and that moving to raw-share accounting is an
interpretation decision. The seed cites neither.

**Smallest better decision.** State the invariant: a conversion is admissible
only when the ratio and the held quantity are expressed in the same adjustment
epoch, and the recipient quantity is produced in the recipient's own epoch.
Extend the census with a split-coincidence test over the 24, and make
unit-basis mismatch a distinct unsupported class. Until that runs, the 24 are
evidence of consideration terms, not of convertibility, and B2's falsifier
should include it.

### F2 — Release boundary. The mechanism cost and the coverage run opposite.

Tier 1 is 5,034 dividend events across 457 instruments and today is a *silent
understatement*: dividends are absent, no stop fires, and total return is
wrong without telling anyone. Tier 2 is at most 24 candidates and today is an
*honest stop*: the run halts, the holding is preserved, nothing is fabricated.

The marginal mechanism Tier 2 adds over Tier 1 is most of the RFC: a new
top-level event type with its CHECK, schema version, hash coverage, migration
and reader changes; multi-leg atomicity; pending claims; parent-to-child basis
allocation; a fractional-position rule; and compiled schedules for quantity
mutation. Tier 1 needs a cash delta the replay already carries, plus the fact
family, clocks and classification that both tiers need anyway.

I do not accept the obvious counter that converting an abort into an answer is
worth more than fixing a wrong number. It would be, if the answer were sound.
Under F1 the Tier 2 answer may be wrong by a split factor with no stop, which
is strictly worse than the current abort: it replaces a known gap with an
unknown error in exactly the 24 cases the seed leads with.

### F3 — Basis allocation is not a policy knob.

Seed section 5 lists "how parent basis is carried or allocated" alongside
visibility and posting as a versioned policy. It does not belong there.
Visibility and posting are research conventions that shift *when* a known
amount lands. Basis allocation changes *how much realized PnL is reported* on
every later sale of both parent and child, permanently, and there is a
standard: relative fair market value at the distribution date, which is
computable from the in-axis prices the census already verified exist. Leaving
it a free knob makes two runs with identical data and identical strategy report
different returns for a reason the user did not choose on economic grounds.

**Smallest better decision.** Derive basis allocation from posting-session
prices; make it a named derivation with a recorded formula, not a policy
choice. Reserve policy status for genuinely conventional choices.

### F4 — The vocabulary question is coupled to the boundary and should not be.

Seed section 7 bets on a top-level `SETTLEMENT` type, arguing `CASHFLOW` plus
`meta$source` would become "a general mutation escape hatch." That argument is
correct *for quantity mutation* and irrelevant for cash.

A dividend is an immediate cash delta. That is precisely what `CASHFLOW`
already means, and operation 2 in `ledgr_prepare_accounting_events()` already
carries it. Using `CASHFLOW` for dividend cash is not an escape hatch; the
escape hatch is `opening_position`, and it is one because it mutates positions
and lots, which a dividend does not.

So the line that makes the vocabulary minimal is semantic, not convenient:
**`CASHFLOW` for events that only move cash; a new type only when quantity or
lot state mutates.** Under Tier 1 alone no new `event_type` is needed, and the
schema CHECK, version bump, hash coverage, migration and reader review all
disappear. The seed reaches the opposite conclusion only because it decided the
boundary first.

I reject the alternatives the brief lists for the Tier 2 case, if Tier 2 ever
proceeds: linked `CASHFLOW` plus quantity events cannot be made atomic without
inventing a link type that is a compound event with extra steps, and separate
source and ledger vocabularies duplicate identity for no gain. If quantity
mutation lands, one atomic typed event is right. It just should not land yet.

### F5 — The posting convention flatters results.

For acquisitions the vendor date is the parent's last trade date and the seed
posts on the next physical-axis session (section 4). Real merger consideration
reaches a holder days to weeks after the last trade. The model therefore frees
cash earlier than history allowed, and a strategy can redeploy it earlier. That
is a bias toward better backtest results, not a neutral convention, and the
seed's own standard in section 1, that a policy "narrows the claim that model
may make," is not met by leaving it unremarked.

**Smallest better decision.** Bind a conservative posting lag rather than the
next session, or state explicitly that the model is optimistic on cash
availability and by how much.

### F6 — Retained fractional positions produce portfolios nobody could hold.

Section 5's default retains fractional positions rather than inventing
cash-in-lieu. Honest about the missing rule, but the result is a position a
holder could not have had, which then compounds through every later valuation
and trade. It is the right default only if the output is labelled as not
reproducible by a real account. That labelling is not in section 8's
classification list.

## 5. Simpler competing design

**Tier 1 only in v0.2.0.2, with the whole evidence apparatus, and no new
event type.**

Keep, unchanged from the seed: the typed `equity_settlement` source fact family
inside the sealed bundle; the versioned policy identity in experiment identity;
the four-clock distinction; the machine-readable unsupported classification;
compile-once-interpret-per-account; and `terminal_settlement_unsupported` for
everything else.

Drop for this release: the `SETTLEMENT` event type and its schema, CHECK, hash,
migration and reader consequences; multi-leg atomicity; pending claims where
posting and payment coincide; basis allocation; the fractional rule.

Represent dividend cash as `CASHFLOW` carrying validated source-event and
policy identities in `meta`, under operation 2, which exists.

Gate Tier 2 behind a named prerequisite: the unit-basis invariant stated and a
split-coincidence census over the 24 passing. That is a bounded spike under
`spike_protocol.md`, not an RFC.

This is smaller on every axis the loop measures: no persisted-schema change, no
identity migration, no compiled quantity path, and a test surface that is cash
arithmetic plus the fact family. It delivers the 5,034-event correction and the
classification, which are the parts a user notices, and it leaves the 24-case
abort exactly as honest as it is today.

The cost is real and I state it: runs that hold an acquired or spun-off name
still stop. Under F1 that is the better failure.

## 6. Scenario failures

**The most damaging omission: a received non-member has no exit.** A spin-off
child on the sealed axis is not an index member.
`R/availability-economics.R:173`
binds held non-members to hold, exit or reduce; increasing is a classed
strategy-result failure. So the position may be held. But the strategy authors
targets over the decision view, where the child is a non-member and may not be
permissible to trade, and section 6 gives no mechanism for the strategy to
learn it now holds something it never bought. The likely outcome is a position
held to the end of the run because no target can legally or practically move
it, silently inflating or deflating terminal equity. The seed's scenario list
in section 11 does not contain it. This alone would change the design.

**Chained settlements.** The census counting unit is one parent and event date,
so an event whose recipient is itself a Tier 2 parent later in the window is
invisible to the aggregates. Two settlements touching the same lot chain in the
same or adjacent sessions make the result ordering-dependent, and section 6's
atomicity is per-event, not per-chain.

**Split-coincident parent.** F1's concrete case: a Tier 2 parent or recipient
with a split between the event date and the build epoch. Not tested, not
classified, silent.

**Unheld parent, held recipient.** Section 11 covers held and unheld parents
under one source event, but not the case where a prior settlement already gave
the account a position in the recipient, so the new legs must merge into an
existing lot chain rather than create one.

## 7. Recommended route

1. Revise the seed to Tier 1 only, retaining the fact family, policy identity,
   four clocks and classification in full.
2. State the unit-basis invariant in the revised seed as a named prerequisite
   for any future Tier 2, with F1's falsifier added to B2.
3. Add the non-member exit problem to the seed's own case list and resolve it
   before any quantity mutation is designed, because it constrains the
   mechanism rather than the wording.
4. Move basis allocation from policy to derivation.
5. Keep the compiled event-envelope guard as the separately owned prerequisite,
   unchanged.
6. Re-run the census with a split-coincidence test before Tier 2 is reopened.

If synthesis disagrees with the boundary and keeps Tier 2, F1 and the
non-member exit still have to be answered inside this cycle, and the vocabulary
argument in F4 should be re-made on semantic grounds rather than on
`CASHFLOW` being too narrow.

TYPE_2_DISPOSITION: REVISE_SEED
