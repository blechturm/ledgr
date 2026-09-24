# Seed: Equity Settlement After v0.2.0.2

**Status:** Revised RFC seed; proposed direction for Type 2 challenge.
**Author:** Codex
**Date:** 2026-09-23
**Scope:** the smallest honest settlement contract for evidenced equity events.
This seed is not a specification, ticket cut, or implementation authority.

**Revision note:** the first seed treated Sharadar `ACTIONS.value` as opaque
and recommended Tier 1 only. The corrected census follows the pinned
`ACTIONTYPES` dictionary and falsifies that premise. This revision reopens the
release boundary rather than preserving the old recommendation.

## 1. The question and evidence standard

What is the smallest honest settlement contract for evidenced events,
distinguishing cash-only outcomes, received securities already present on the
sealed physical axis, and received securities outside that axis?

For this seed, *evidenced* means enough source facts to compute the economic
consideration under a named daily-model policy. It does not mean that the
source reconstructs a broker's legal, payment, fractional-cash, or tax record.
Vendor facts and model policy must remain separately identifiable. A value
created by policy must never be presented as a vendor fact.

Incomplete source consideration remains unsupported. Missing broker-exact
detail does not automatically forbid a daily research model, but it narrows
the claim that model may make.

## 2. Corrected ground

The physical execution axis in an availability-aware experiment is the whole
sealed snapshot, not the point-in-time member set. `R/experiment.R:240-251`
selects `universe_all`, and `R/experiment.R:338-349` derives it from
`snapshot_instruments`. The fold keeps that axis fixed. Membership limits what
can be traded; it does not remove an already sealed instrument from the
accounting carrier.

An in-snapshot recipient therefore has an axis slot and sealed price history.
An out-of-snapshot recipient still has neither. That is the boundary between
Tiers 2 and 3; it is not a reason to reject Tier 2.

The current accounting vocabulary is narrower than the proposed behavior.
`ledger_events.event_type` accepts only `FILL` and `CASHFLOW`
(`R/db-schema-create.R:209-220`). `ledgr_prepare_accounting_events()` maps
fills, ordinary cashflows, and the `opening_position` exception to three
operations (`R/accounting-replay.R:135-177`). A lifetime fact's
`terminal_event` is free text and carries no settlement terms
(`R/availability-facts.R:300-340`). When it affects a holding, the fold stops
with `terminal_settlement_unsupported` (`R/fold-engine.R:397-407`). That stop
is correct today.

Before any pulse-level economic event lands, the separately bound compiled
event-envelope guard from the inventory section 9 must make an unrecognized
pulse kind fail closed in both execution arms. This RFC does not absorb or
redesign that prerequisite.

## 3. The three tiers

| Tier | Outcome | Structural work | Evidence and policy |
| ---: | --- | --- | --- |
| 1 | Cash only | Pending or posted cash; terminal cases also close the parent and its lots | Source amount, currency and date semantics; explicit visibility and payment policy where the source lacks clocks |
| 2 | Security or mixed consideration; every recipient already on the sealed axis | Tier 1 plus child quantity, parent/child lots, basis and fractional positions | Source recipient, ratio and cash component; explicit posting, fraction and basis policies |
| 3 | Any recipient outside the sealed axis | Tier 2 plus a new axis, instrument and valuation contract | All Tier 2 inputs plus sealed identity and prices |

Tier 1 is the smallest operation but is not automatically exact. Sharadar
dividends carry ex-dates and amounts, not payment dates. A daily model may use
a declared payment convention, but it must expose that convention and may not
claim broker-exact cash availability.

Tier 2 is structurally reachable on the fixed axis. The corrected census in
section 4 shows that Sharadar supplies real consideration terms for this
shape. The remaining fractional, basis, visibility and posting choices are
model policies, not missing conversion evidence. This seed bets that a
clearly labelled daily-model Tier 2 contract can fit v0.2.0.2.

Tier 3 does not fit. Creating an instrument or admitting unsealed prices would
alter snapshot identity and valuation, not merely settlement. Such an event
may be retained and classified, but it cannot mutate the account.

## 4. The corrected census changes the boundary

The corrected Sharadar census is recorded at
`experiments/EXP-0002-sharadar-ledgr-baselines-v0.1.1/
tier2-prerequisite-census.md` in `ledgr-research`. Its repeatable operator is
`scripts/sharadar/23_census_equity_settlement_tier2.R` there.

The operator validates the relevant meanings and units against the pinned
`DESCRIPTIONS.ACTIONTYPES` rows before interpreting `ACTIONS.value`. It reuses
the accepted 563-instrument physical axis and the registered 11 stock
acquisitions, 6 mixed acquisitions, and 24 spin-off parents. It selects no new
population.

| Measure | Result |
| --- | ---: |
| Registered candidates | 41 |
| Candidates with documented consideration values | 41 |
| Candidates with all recipient identities resolved | 39 |
| Recipient events wholly inside the sealed axis | 24 |
| In-axis events priced on the daily-model posting session | 24 |
| Daily-model Tier 2 evidence candidates | 24 |
| Outside-axis or unresolved outcomes combined | 17 |
| Broker-exact term-complete cases | 0 |

Sharadar documents `acquisitionstock` and `spinoff` values as recipient shares
per parent share and `acquisitioncash` as USD per parent share. The prior
claim that these values were opaque is withdrawn. Multi-recipient events are
preserved as multiple legs rather than forced to one child; low-count shape
cells remain suppressed in the public record.

For acquisitions, the vendor date is the parent's last trade date, so the
census tests prices on the next physical-axis session. For spin-offs it tests
the first session on or after the transaction date. All 24 in-axis candidates
pass that valuation witness.

This does not establish exact settlement. Sharadar still lacks historical
publication time, legal settlement and payment timestamps,
transaction-specific cash-in-lieu rules, and tax-basis instructions. It does
establish enough real source consideration to challenge a daily settlement
model over stock, mixed, and spin-off outcomes.

## 5. Source facts and model policy are different records

The proposal remains a typed `equity_settlement` fact family inside the
sealed `ledgr_facts` bundle, persisted beside membership, status, sessions,
and lifetime facts. It is not an extension of lifetime `terminal_event`, and
it is not itself a ledger event.

This is a schema addition. Persistence is closed over four families
(`R/availability-persistence.R:71-118`), so the change needs a constructor,
typed snapshot tables, write/read and seal validation, hash coverage,
migration, and point-in-time compilation. Reusing the bundle preserves one
snapshot identity rather than creating a parallel evidence system.

The source fact must carry what the vendor actually says:

- stable source-event and revision identity, provenance and subtype;
- parent identity and the vendor date with its documented semantics;
- zero or more recipient legs with stable identity and shares per parent;
- any cash amount per parent and its currency; and
- whether the source record is complete for its declared subtype.

The source fact must not pretend to contain an unavailable publication,
payment, cash-in-lieu, or tax clock. A separately versioned settlement policy
derives the daily schedule used by an experiment and records:

- when the evidence becomes visible to the model;
- the daily posting session;
- whether fractional positions are retained;
- how parent basis is carried or allocated; and
- when modeled cash becomes spendable.

The policy and its version belong in experiment identity. The derived event
must point to both the source-event identity and policy version. This lets a
reader distinguish vendor history from a research convention and compare
results under another policy without rewriting the sealed source fact.

The seed's default bet is conservative next-session visibility when a source
has no historical publication timestamp, fractional positions retained rather
than converted to invented cash, and no claim of tax-basis fidelity. Exact
posting and basis rules remain decisions for synthesis; leaving them unnamed
is not an option if Tier 2 proceeds.

## 6. From evidence to accounting events

Facts should be validated and compiled once before the fold into ordered,
primitive schedules over the fixed snapshot axis. The fold must not scan or
subset fact frames per instrument and pulse.

At the policy's posting boundary, an account-specific interpreter reads the
parent holding and produces one atomic settlement transition:

- cash delta, if any;
- parent quantity and lot disposition;
- one or more in-axis recipient quantity deltas;
- parent-to-recipient basis movement under the declared policy; and
- the source-event and policy identities needed for replay.

If entitlement and payment are distinct under the selected policy, the first
transition creates a pending receivable and the second converts it to
spendable cash. Coincident clocks may collapse them. No strategy callback
authors settlement events, and no reader recomputes consideration from prices.

The canonical R path is authoritative. The same derived events feed memory
and durable handlers, replay, resume, reopen, sweep, and results. A
multi-recipient or mixed event is atomic: interruption may preserve the prefix
or reject the transition, but may not apply only one leg.

## 7. Vocabulary

This seed bets on a new top-level `SETTLEMENT` `event_type`, not `CASHFLOW`
plus `meta$source`. An ordinary `CASHFLOW` is an immediate cash delta. A
settlement may create a pending claim, close a parent, create child positions,
move basis, and later post cash. Hiding those transitions behind `CASHFLOW`
would turn the existing `opening_position` exception into a general mutation
escape hatch.

The cost is real: the ledger CHECK and schema version change; memory and
durable writers, replay, result readers, migrations, schema-bound hashes, and
compatibility tests must be examined. `meta_json` may carry validated subtype
detail, but `meta$source` is provenance within the new type, not its type
discriminator. Unknown subtypes fail closed.

Whether persistence uses one row or linked rows is left to specification,
provided one source event has one atomic account effect and replay can prove
that property.

## 8. Unsupported is not absent

`terminal_settlement_unsupported` remains the stop when a held position meets
an event outside the selected policy or without complete consideration. The
holding and committed prefix remain intact.

The evidence layer must expose a machine-readable pre-run classification:

- supported under a named daily Tier 1 or Tier 2 policy;
- incomplete source consideration;
- recipient unresolved;
- recipient outside the sealed axis;
- recipient unpriced at the posting boundary;
- election or unsupported subtype; or
- broker-exact treatment unavailable.

The last state may coexist with daily-model support. That distinction is the
point of the revision. A recognized event is never represented as absent. An
unsupported event with no affected holding may be diagnostic-only; the same
event affecting a holding stops before mutation.

## 9. Recommendation and sequence

For v0.2.0.2, the seed recommends:

1. land the separately owned compiled event-envelope guard;
2. bind one named daily settlement policy and its identity consequences;
3. add the term-bearing source fact family and unsupported classification;
4. implement cash-only outcomes and fixed-axis stock, mixed, and spin-off
   outcomes for complete source facts;
5. prove the path first on the 24 real Tier 2 candidates, while keeping
   licensed values outside public evidence;
6. retain `terminal_settlement_unsupported` for incomplete, election-based,
   unresolved, unpriced, and out-of-axis events; and
7. defer Tier 3 and any dynamic-axis or instrument-master design.

The implementation claim is deliberately narrow: deterministic daily research
accounting under a named policy. It is not broker, legal, tax, or
cash-in-lieu reconstruction. If synthesis cannot bind the daily visibility,
posting, fractional and basis rules without pretending they came from the
vendor, Tier 2 falls back out of this release.

## 10. Bets and falsifiers

| Bet | What would falsify it |
| --- | --- |
| B1. Tier 2 fits a daily model on the fixed axis. | A required recipient has no stable axis slot or price at the bound posting session, or the account effect requires changing snapshot identity. |
| B2. The 24 cases contain sufficient source consideration. | Reproduction changes the pinned action meaning, a positive ratio or required cash value is missing, or recipient resolution no longer reconciles. |
| B3. Model policy can close non-broker gaps honestly. | A required economic amount can only be invented, or a policy-derived value cannot be distinguished in identity and output from a vendor fact. |
| B4. Source facts remain separate from ledger mutations. | Existing sealed facts can carry all terms without overloading lifetime semantics or duplicating identity. |
| B5. One `SETTLEMENT` vocabulary covers Tiers 1 and 2. | A detecting example requires unrelated top-level event types or makes old readers accept a mutation they cannot replay. |
| B6. Settlement can be atomic. | Mixed or multi-recipient state cannot survive interruption, resume and reopen without partial application. |
| B7. Tier 3 stays outside this release. | Every supposed outside recipient already has a sealed identity and price history, reclassifying it as Tier 2. |
| B8. Compile once, interpret per account. | A runnable probe cannot preserve point-in-time visibility and handler parity without eager account-specific expansion. |

## 11. Cases the next stages must survive

The Type 2 response should attack at least:

- a dividend with no vendor payment date under the named daily policy;
- a stock acquisition posted after the parent's last trade session;
- a mixed acquisition with both child units and cash;
- a spin-off with more than one recipient leg;
- an event learned only after its economic date;
- an in-axis recipient missing a price at the posting boundary;
- an unresolved, elected, or out-of-axis recipient;
- a held and an unheld parent under the same source event;
- interruption during an atomic settlement, then resume and reopen;
- memory/durable and run/sweep parity; and
- compiled execution presented with a non-fill pulse event before its envelope
  declares support.

## 12. What this seed does not authorize

It does not infer a missing ratio or cash amount, fabricate a settlement
price, broaden the snapshot axis, design an instrument master, implement
corporate actions in C++, change adjusted-price policy, claim tax-lot or broker
fidelity, add multi-currency accounting, or promise every Sharadar action
family. It writes no production code, test, ticket, or roadmap status.

The Type 2 response should challenge whether the daily policy is honest enough
to support Tier 2, whether the source/policy/ledger separation is minimal,
whether `SETTLEMENT` is the right vocabulary, and whether the proposed atomic
transition can preserve lots and replay. It should not restore the withdrawn
claim that Sharadar lacks consideration terms.
