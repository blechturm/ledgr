# Seed v2: Equity Settlement After v0.2.0.2

**Status:** Revised RFC seed; proposed direction for Type 2 challenge.
**Author:** Codex
**Date:** 2026-09-23
**Revises:** `rfc_equity_settlement_post_v0_2_0_2_seed.md`
**Responds to:** `rfc_equity_settlement_post_v0_2_0_2_response.md`

This is not a specification, ticket cut, or implementation authority.

## 1. Revision decision

The Type 2 response found a real blocker. Sharadar action ratios are stated in
event-date shares, while the sealed bars and ledgr quantities use a backwards
split-adjusted share basis. Applying a vendor ratio directly inside ledgr can
silently create the wrong quantity.

The response placed the remedy too far downstream. Sharadar unit decoding and
split normalization are data-preparation work. ledgr must not learn
`closeunadj`, Sharadar action codes, or vendor-specific adjustment formulas.

The corrected upstream census now performs that normalization. Of 24 in-axis
events with recipient prices, 22 have all source consideration transformed
into the sealed snapshot's split-adjusted unit basis. The other in-axis events
fail closed because no accepted parent-side canonical bar establishes the
factor. Real non-unit factors occur in the passing population; the conversion
is not ceremonial.

This seed therefore keeps fixed-axis Tier 2 in contention, but only behind an
adapter-owned canonical-fact gate. It rejects both earlier extremes:

- vendor ratios are not opaque; and
- documented vendor ratios are not automatically snapshot-unit ratios.

## 2. The product question

What is the smallest vendor-neutral settlement contract for:

1. cash-only outcomes;
2. received securities already present on the sealed physical axis; and
3. received securities outside that axis?

The contract must distinguish vendor evidence, adapter normalization, daily
research policy and broker-exact fact. A value created in one layer may not be
presented as belonging to another.

## 3. The boundary between preparation and accounting

The required pipeline is:

```text
vendor-native action rows
  -> adapter decoding and unit normalization
  -> sealed vendor-neutral settlement facts in snapshot units
  -> ledgr policy schedule
  -> account-specific ledger effects
```

The adapter owns:

- action-specific units and meanings;
- stable parent and recipient identity resolution;
- conversion of every per-share amount into the snapshot quantity basis;
- source completeness and ambiguity classification; and
- a versioned transformation identity bound into the sealed facts.

For the current Sharadar split-adjusted basis, the preparation proof uses:

```text
F = closeunadj / close
canonical recipient ratio = vendor ratio * F_recipient / F_parent
canonical cash per parent unit = vendor cash per share / F_parent
```

That formula is an implementation of the Sharadar adapter, not a ledgr rule.
Another adapter may use raw shares, a vendor factor file, or another lawful
method and still satisfy the same core contract.

ledgr receives:

- stable source-event and revision identities;
- parent and zero or more recipient instrument identities;
- cash and recipient quantities per canonical parent unit;
- `unit_basis = "snapshot_units"`;
- the adapter transformation-policy identity; and
- an explicit completeness or unsupported classification.

ledgr verifies shape, identity, completeness and that every recipient belongs
to the sealed physical axis. It does not recompute a vendor adjustment.

## 4. Existing core boundaries

The availability-aware physical axis is the entire sealed snapshot.
`R/experiment.R:240-251` selects `universe_all`, and
`R/experiment.R:338-349` derives it from `snapshot_instruments`. Membership
governs tradability, not whether a held instrument has an accounting slot.

Held nonmembers already enter the decision axis after members and may be held,
reduced, or exited (`inst/design/contracts.md:343-350` and `:387-397`). The
response's claim that a received nonmember is invisible or has no exit is
therefore not established. A settlement-created position must enter ordinary
position state before the next decision so this existing contract applies.

The ledger currently admits only `FILL` and `CASHFLOW`
(`R/db-schema-create.R:209-220`). Lifetime `terminal_event` is free text and
contains no settlement terms (`R/availability-facts.R:300-340`). A held
terminal event correctly stops as `terminal_settlement_unsupported`
(`R/fold-engine.R:397-407`).

Before any new pulse-level economic event lands, the separately bound compiled
event-envelope guard must reject an unrecognized pulse kind in both execution
arms. This RFC does not absorb that prerequisite.

## 5. Tiers and proposed release boundary

| Tier | Outcome | v0.2.0.2 proposal |
| ---: | --- | --- |
| 1 | Cash only | Admit when the adapter supplies canonical cash terms and the selected policy supplies the required clocks. |
| 2 | Security or mixed consideration; every recipient is on the sealed axis | Admit only from canonical adapter facts that pass the unit-basis and price gates. |
| 3 | Any recipient outside the sealed axis | Retain and classify, but do not mutate the account. |

Tier 1 comes first in implementation because omitted dividends are a silent
economic error over a large observed population, while existing security
settlement stops honestly. That sequencing does not decide Tier 2 by itself.

Tier 2 follows in the same release only if the Tier 1 mechanism and the
adapter-normalized real evidence leave the quantity path bounded. Its marginal
work is parent/recipient quantity, lots, basis, fractional positions and
multi-leg atomicity. A failed gate retains the current stop without weakening
Tier 1.

Tier 3 changes snapshot identity and valuation and is deferred.

## 6. Corrected empirical ground

The tracked record is `experiments/EXP-0002-sharadar-ledgr-baselines-v0.1.1/
tier2-prerequisite-census.md` in `ledgr-research`; its operator is
`scripts/sharadar/23_census_equity_settlement_tier2.R`.

| Measure | Result |
| --- | ---: |
| Registered candidates | 41 |
| Documented vendor consideration | 41 |
| All recipient identities resolved | 39 |
| Recipients wholly inside the sealed axis | 24 |
| Recipients priced at the model-posting boundary | 24 |
| Canonical unit-normalized in-axis candidates | 22 |
| Broker-exact term-complete cases | 0 |

These counts prove that real fixed-axis canonical facts can be constructed for
22 events. They do not prove accounting semantics, historical availability,
payment timing, fractional cash, or tax basis.

The Sharadar preparation layer must apply the same unit discipline to every
per-share cash amount, including dividends. Tier 1 release evidence therefore
requires its own adapter-normalization witness; Tier 2's census is not a proxy
for all 5,034 dividend rows.

## 7. Sealed facts and daily policy

The proposal remains one typed `equity_settlement` fact family inside the
sealed facts bundle. It is neither lifetime free text nor a ledger event.
Persistence is currently closed over four families
(`R/availability-persistence.R:71-118`), so this is a real schema addition with
constructor, storage, read, seal, hash, migration and compilation work.

The sealed fact contains canonical consideration and source identity. A
separately versioned ledgr policy supplies only choices the source cannot:

- evidence visibility in daily time;
- accounting posting and modeled cash availability;
- fractional-position treatment; and
- a closed basis derivation selected for the event subtype.

Those policies enter experiment identity and output. They never rewrite the
sealed source fact. When a historical publication or payment timestamp is
absent, output must say which modeled convention replaced it and what claim is
therefore unavailable.

The seed retains conservative next-session visibility as a hypothesis, not an
accepted default. The Type 2 response correctly notes that next-session cash
availability may be optimistic. Synthesis must either bind a defensible daily
convention with that limitation exposed or leave the affected subtype
unsupported.

## 8. Basis, fractions and adjusted units

Basis treatment is not an unconstrained user knob. Each admitted subtype needs
one closed, versioned derivation with detecting examples. A relative-fair-value
derivation may be appropriate for a research spin-off model, but it is not
universal merger or tax law. The output calls it model basis, not tax basis.

Fractional positions may be retained only as an explicit analytical
approximation. They must be identified in results as positions that may not
have been held by a real brokerage account. No missing cash-in-lieu amount is
fabricated from a market price.

The adapter-normalized ratios prevent split double counting. ledgr applies no
explicit split to quantities because the snapshot already uses split-adjusted
prices and units.

## 9. Ledger vocabulary and atomicity

The response is right that immediate cash-only effects do not require a new
top-level type. They compile to the existing `CASHFLOW` event with typed source
and policy identity.

A new `SETTLEMENT` type is reserved for transitions that mutate quantity or
lots, or create a pending claim whose equity and spendable-cash clocks differ.
It is not introduced merely because a cashflow originated in a corporate
action.

One source event may produce an entitlement transition and a later cashflow,
but replay must bind them to one source identity and prevent duplicate
application. A mixed or multi-recipient quantity transition is atomic: failure
preserves the prefix rather than applying only one leg.

The canonical R path remains authoritative. Memory and durable handlers,
replay, resume, reopen, sweep and results consume the same derived events. No
strategy callback authors settlement terms, and no reader reconstructs them
from prices.

## 10. Unsupported is observable

Pre-run classification must distinguish:

- supported under a named daily Tier 1 or Tier 2 policy;
- adapter normalization unavailable or failed;
- incomplete source consideration;
- recipient unresolved, outside the axis, or unpriced;
- election or unsupported subtype; and
- broker-exact treatment unavailable.

Daily-model support and broker-exact unavailability may coexist. A recognized
event is never represented as absent. An unsupported event affecting a holding
stops before mutation; an unheld event may remain diagnostic-only.

## 11. Sequence and gates

1. Land the separately owned compiled event-envelope guard.
2. Specify the vendor-neutral canonical fact contract.
3. Make `ledgr.sharadar` emit canonical cash terms and prove the dividend unit
   basis over its registered population.
4. Implement Tier 1 fact ingestion, policy identity, cash accounting and
   unsupported classification.
5. Prove Tier 1 entitlement/payment behavior, handler parity and replay.
6. Admit only the 22 unit-normalized real Tier 2 candidates to the quantity
   work; retain the other classifications unchanged.
7. Implement and prove atomic fixed-axis quantity settlement.
8. Defer Tier 3 and dynamic-axis design.

The work may stop after step 5 with an honest Tier 1 release. Tier 2 proceeds
only if its upstream facts and core semantics both pass; it is not required to
justify the common infrastructure retroactively.

## 12. Bets and falsifiers

| Bet | Falsifier |
| --- | --- |
| B1. Vendor normalization belongs upstream. | ledgr cannot validate or replay a canonical fact without knowing a vendor action code or adjustment formula. |
| B2. The 22 cases are convertible into snapshot units. | Reproduction changes a factor, normalized amount, identity, or posting-session price. |
| B3. Tier 1 and Tier 2 share one source-fact family. | Their source identity or completeness contracts require incompatible schemas rather than subtype validation. |
| B4. Immediate cash stays `CASHFLOW`. | A cash-only case needs quantity/lot mutation or distinct entitlement equity that cannot be represented without a settlement transition. |
| B5. Fixed-axis Tier 2 needs no membership exception. | A settlement-created held nonmember is absent from the next decision axis or cannot be reduced under the existing contract. |
| B6. Closed model-basis derivations are honest. | A required economic amount can only be invented, or output cannot distinguish model basis from vendor or tax basis. |
| B7. Mixed and multi-leg settlement is atomic. | Interruption, replay or resume can expose a partially applied source event. |
| B8. Tier 3 remains separate. | An apparently outside recipient already has a sealed identity and price history, making it Tier 2 instead. |

## 13. Required adversarial cases

- a dividend before and after a later parent split;
- parent-only, recipient-only, both-side and reverse-split conversions;
- an acquisition whose parent has no admissible unit-basis witness;
- a received nonmember visible on the next decision axis and then exited;
- a mixed acquisition with cash and recipient units;
- a spin-off with multiple recipient legs;
- an event learned after its economic date;
- distinct entitlement and payment clocks;
- an existing recipient holding whose lot chain receives another leg;
- interruption, resume and reopen around one atomic settlement; and
- canonical/compiled and memory/durable parity.

## 14. What this seed does not authorize

It does not put Sharadar decoding in ledgr, infer a missing ratio or cash
amount, fabricate cash in lieu, broaden the axis, design an instrument master,
change adjusted-price policy, claim broker or tax fidelity, add multi-currency
accounting, or implement corporate actions in C++. It creates no production
code, test, ticket, roadmap status or release claim.

The next Type 2 pass should attack the upstream/core boundary, the staged
release decision, the cash-versus-settlement vocabulary, the daily clock
conventions and the closed basis derivations. It should not restore either
withdrawn premise about opaque values or directly usable vendor ratios.
