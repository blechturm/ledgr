# Seed v4: Equity Settlement After v0.2.0.2

**Status:** Revised RFC seed for Type 2 challenge; non-binding.
**Author:** Codex.
**Date:** 2026-09-23.
**Revises:** `rfc_equity_settlement_post_v0_2_0_2_seed_v3.md`.
**New evidence:** ledgr atomic settlement spike at `39c4832`; Sharadar
axis-closure spike at `00259f6`; proposed Sharadar producer specification.
This document is not a specification, ticket cut, or implementation authority.

## 1. Why a fourth seed is warranted

The v3 response requested two bounded corrections: seal only terms with stable
meaning, and test the modeled posting convention rather than only the machinery
around it. Those corrections still stand.

Two later spikes changed more than wording.

The Sharadar spike showed that all 15 resolved recipient events outside the
selected physical axis had canonical identities, accepted bars, posting marks,
and normalization inputs. A static preseal closure passed for every one. The
observed `off-axis` class therefore does not justify runtime axis mutation.

The ledgr spike then showed that the current lot carrier can consume parent
lots, create one or more recipient lots, preserve caller-supplied model basis,
and survive replay, interruption, resume, and reopen as one validated group.
Malformed groups failed before append, and the compiled arm refused the
unknown operation. The missing primitive is feasible; its economic inputs are
the remaining question.

Seed v3's hierarchy is retired. Recipient location is a preparation outcome,
not an account-effect class. `Lot settlement` is no longer one indivisible
deferred category merely because the primitive was thought absent.

## 2. Product question

What is the smallest honest daily-model contract that can post evidenced gross
cash distributions and nonrealizing pure-stock exchanges, while refusing every
event whose source terms, axis preparation, posting convention, or accounting
policy are incomplete?

The release must be usable without describing an approximation as broker,
legal, payment, withholding, or tax truth.

## 3. Two independent admission dimensions

Every recognized source event is classified on two axes.

### 3.1 Evidence readiness

| State | Meaning |
| --- | --- |
| `canonical_ready` | Source meaning, identities, units, normalized legs, required bars, and bar vintage are verified. |
| `canonical_incomplete` | The event is recognized, but at least one required source or normalization claim is unavailable or contradictory. |

The Sharadar adapter owns this axis. The proposed producer specification in
`ledgr-research` at
`docs/design/sharadar-equity-settlement/v0.1.0/spec.md` defines it. ledgr does
not learn Sharadar codes, `closeunadj`, or its adjustment formula.

### 3.2 Account effect

| State | Required mutation | v0.2.0.2 proposal |
| --- | --- | --- |
| `additive_gross_cash` | Add modeled gross cash; no lot, basis, position, realization, or pending-claim mutation. | Support under an explicit posting policy. |
| `nonrealizing_stock_exchange` | Consume all parent lots and create recipient lots while preserving total model basis and realizing nothing. | Support only under the closed rule in section 6. |
| `other_settlement` | Any basis split with the parent retained, cash-plus-lot mutation, realization, election, cash in lieu, or pending claim. | Recognize and refuse. |

Evidence readiness is decided before account effect is admitted. A correctly
shaped mutation with unevidenced terms remains unsupported.

## 4. Upstream producer contract

The Sharadar work is a separate implementation surface and lands before the
real-data ledgr gate. Its contract is proposed, not assumed, by the companion
specification.

It must:

- validate pinned vendor action definitions before decoding a value;
- group source rows into one event with stable parent and recipient identities;
- normalize cash and recipient quantities into the snapshot's split-adjusted
  unit basis;
- bind canonical bar references and canonical-build identity;
- retain source clocks and state when a clock is unavailable;
- prepare the static union of the base valuation axis and resolved recipients;
- leave membership and tradability unchanged; and
- emit explicit incomplete/refusal states without guessed legs.

The adapter does not supply basis allocation, posting, withholding, or account
mutation. Acquisition time is not historical event knowledge time.

## 5. Sealed fact family

ledgr receives one typed, vendor-neutral `equity_settlement` fact family. The
family stores stable event identity, parent identity, subtype, supplied clocks,
canonical normalized legs, normalization-policy identity, bar/build binding,
and completeness state.

The family stores only claims the adapter validated. An incomplete event keeps
its header and reason but has no guessed leg. This closes response-v3 F1: the
schema represents observed source evidence rather than a speculative future
ledger projection.

The snapshot fact is not a ledger event. Snapshot identity naturally binds its
content; no fact hash, hash ledger, or duplicate provenance manifest is added.

## 6. Supported daily-model policies

Historical row-publication time is unavailable. A run must therefore choose
either `assume_effective_knowledge_v001` or strict refusal. The assumption
enters experiment identity and result disclosure and is not described as
point-in-time publication evidence.

### 6.1 Gross cash distribution

An admitted distribution must have documented cash-per-share meaning and a
canonical cash amount per canonical parent unit. The only amount policy in
this release is `gross_vendor_distribution_v001`.

It makes no withholding, investor-tax, or net-payment claim. Those claims are
unavailable, not zero.

Because source payment time is generally unavailable, the experiment must
choose one declared posting convention:

- `ex_date_close_v001`: apply after the ex-date close; spendable only at the
  next execution opportunity; or
- `next_session_open_v001`: apply at the next modeled session opening.

There is no implicit default. The convention and the unavailable payment-time
claim enter experiment identity and result disclosure. A future receivable or
payment-date model is a separate design.

An admitted distribution compiles to one existing `CASHFLOW` event carrying
source-fact, amount-policy, and posting-policy identity.

### 6.2 Nonrealizing pure-stock exchange

The bounded release rule is deliberately narrower than all stock settlement.
It requires:

- one parent that terminates;
- exactly one resolved recipient on the prepared physical axis;
- one positive canonical recipient ratio;
- no cash, election, fractional-cash, or other consideration leg; and
- the declared `nonrealizing_full_basis_carryover_v001` model.

At the modeled effective session, each live parent lot is consumed. Its full
model basis is transferred to a recipient lot whose quantity is the parent
quantity multiplied by the canonical ratio. Total model basis is preserved,
realized PnL is unchanged, and fractional recipient units remain fractional.
No cash in lieu is fabricated.

This is a research-accounting model, not a tax characterization of the legal
transaction. Events that do not satisfy every predicate remain unsupported.

The posting convention is
`first_session_on_or_after_effective_v001`, and its identity enters the
experiment. If the upstream fact cannot support that session without a model
assumption beyond its declared normalization policy, the event is refused.

## 7. Ledger event contract

Cash distributions remain `CASHFLOW` because their account effect is exactly a
cash delta.

The stock exchange uses a new top-level `SETTLEMENT` event. The operation is
one source-event group, not a negative fill plus an opening-position event and
not a `CASHFLOW` discriminator. Its validated payload contains the source fact,
parent, recipient, canonical ratio, posting policy, and basis policy.

Preparation validates every leg and the pre-state before mutation. Application
constructs the complete successor lot state, checks position/lot agreement and
basis conservation, and only then replaces state and appends one event. A
failure exposes neither an account prefix nor a ledger prefix.

Canonical R remains the normative executable oracle. The spike's prototype
serialization as `CASHFLOW` was a feasibility device and is explicitly
rejected as the production vocabulary.

## 8. Unsupported remains visible

At minimum, these outcomes remain unsupported in this release:

- source meaning, identity, amount, unit, clock, bar, or vintage unavailable;
- unresolved or unpriced recipient after static preparation;
- cash or mixed acquisition;
- spin-off or other parent-retained basis allocation;
- return of capital or another basis-only mutation;
- election-dependent consideration;
- multiple recipient legs;
- fractional cash, cash in lieu, or broker-specific rounding;
- net-of-withholding, tax, or broker-exact treatment; and
- any fact requiring runtime axis growth.

Recognized unsupported facts are reported before execution. If an affected
instrument is held when the event becomes applicable, the run retains the
existing `terminal_settlement_unsupported` fail-closed meaning and mutates
nothing. An unheld event may remain diagnostic.

## 9. Compiled boundary prerequisite

The compiled event-envelope guard identified by the inventory remains a
prerequisite and must receive an ordinary correctness ticket before settlement
implementation starts.

Any run whose pulse plan contains `CASHFLOW` or `SETTLEMENT` economic events
must fail before execution when compiled spot-FIFO is selected. The accelerator
may not complete after dropping an event. This release does not implement
compiled settlement.

## 10. One admission gate

One end-to-end gate asks whether only fully evidenced facts covered by a named
daily-model policy mutate the account, with every other recognized fact
refused before mutation.

The case set is capped at ten:

1. a gross distribution before a later parent split;
2. one distribution under both posting conventions, producing distinct and
   correctly labelled results, with an unstated posting or knowledge policy
   rejected;
3. a fact prepared against the wrong bar build or price-policy version;
4. a one-recipient pure-stock exchange preserving quantity and total basis;
5. the same exchange across multiple parent lots;
6. a malformed settlement group leaving no account or event prefix;
7. a cash acquisition, mixed acquisition, and spin-off each refused for its
   actual unsupported reason;
8. an unresolved, unpriced, or unprepared recipient refused before execution;
9. interruption, resume, replay, and reopen applying each event once; and
10. compiled spot-FIFO refusing the economic-event envelope before execution.

Synthetic cases establish failure sensitivity. Private Sharadar evidence then
reconciles aggregate eligible, refused, and axis-closure counts without
publishing identifiers, prices, action values, or suppressed cells.

## 11. Sequence

1. Accept the Sharadar producer specification and this RFC synthesis.
2. Land the compiled event-envelope guard.
3. Implement the Sharadar grouped facts, normalization, refusal states, and
   static axis closure. Rebuild private evidence without changing membership.
4. Implement the ledgr fact schema and validators against synthetic fixtures.
5. Implement gross-distribution policy and `CASHFLOW` projection.
6. Implement canonical-R `SETTLEMENT`, replay, results, interruption, resume,
   and reopen for the one-recipient carryover rule.
7. Run the single admission gate and independent workstream review.

Synthetic ledgr steps may be developed without licensed data, but the real
integration gate cannot precede the accepted upstream build.

## 12. Bets and falsifiers

| Bet | Falsifier |
| --- | --- |
| B1. Static upstream closure is the right axis boundary. | A resolved required recipient cannot be given canonical identity and required marks before sealing, but can be handled correctly only by runtime expansion. |
| B2. The producer contract is vendor-neutral at the boundary. | ledgr must know a Sharadar code, `closeunadj`, or the vendor normalization formula to validate or replay a fact. |
| B3. Gross distributions are honest under explicit model labels. | The source amount meaning cannot be documented, or either posting policy requires an unreported payment or withholding claim. |
| B4. One-recipient full carryover is a closed model. | It requires an unprovided basis split, realization amount, election, cash leg, or recipient mark to preserve the stated invariants. |
| B5. One typed `SETTLEMENT` event is the honest persistence unit. | Replay or atomic recovery requires independently visible legs whose identity cannot be represented as one validated event payload. |
| B6. Current lot state is sufficient. | A valid exchange cannot consume parent lots and create recipient lots while preserving basis and position/lot agreement. |
| B7. Validate-then-apply is atomic. | Any malformed, interrupted, resumed, or replayed case exposes a prefix or duplicate effect. |
| B8. The compiled boundary fails closed. | A planned economic event reaches or completes under compiled execution without an independently verified implementation. |

## 13. What changed from v3

This seed accepts response-v3 F1 and F2. It stores only validated source claims
and makes posting convention a gate result rather than prose.

It accepts F3's distinction: mutation shape is a feasibility classification,
while product admission requires evidenced terms plus an explicit model policy.
Gross cash is labelled gross and payment time unavailable; withholding is not
silently treated as zero.

New spike evidence removes recipient location as a runtime class and replaces
blanket Class-B deferral with one closed, nonrealizing stock-exchange model.
It also makes the event-vocabulary decision that v3 correctly deferred until a
consuming atomic operation existed.

## 14. Rejected alternatives

This seed rejects dynamic axis growth for the observed Sharadar population,
opening-position reuse, settlement encoded as an opaque `CASHFLOW` source,
append-then-validate, implicit ex-date cash, silent zero withholding, raw
vendor ratios applied to canonical quantities, and storing guessed legs for
incomplete events.

It also rejects broad support merely because the primitive is feasible. The
atomic spike accepted caller-supplied basis fractions; it did not derive them.
Spin-offs, mixed consideration, cash realization, and cash in lieu therefore
remain outside the release.

## 15. What this seed does not authorize

It does not implement or ticket either repository, alter the accepted census,
publish licensed data, change membership, infer missing clocks or terms,
support broker or tax accounting, add dynamic axes, or promote compiled
settlement. Those actions require an accepted synthesis and specification.
