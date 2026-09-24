# Seed v3: Equity Settlement After v0.2.0.2

**Status:** Revised RFC seed; proposed direction for Type 2 challenge.
**Author:** Codex
**Date:** 2026-09-23
**Revises:** `rfc_equity_settlement_post_v0_2_0_2_seed_v2.md`
**New evidence:** `settlement_quantity_primitive_spike/closeout.md`

This is not a specification, ticket cut, or implementation authority.

## 1. Why v3 exists

Seed v2 divided settlement by consideration and recipient location. The
bounded spike showed that this is not the first boundary ledgr encounters.
The first boundary is the accounting mutation an event requires.

Operation 3 accepted positive quantity during a fold, including beside a
fill and across resume and reopen. It did not consume an existing lot. A
negative leg reached net zero while leaving positive and negative lots live.
The compiled arm completed while silently omitting the event. A malformed
second leg left the first leg applied on the memory path.

Three v2 conclusions therefore retire:

- `cash-only` is not a release class. A cash acquisition still extinguishes
  a position and needs lot semantics.
- operation 3 is not a general quantity-settlement primitive. It inserts a
  declared lot.
- a new top-level `SETTLEMENT` event is not justified merely by mid-fold
  emission. The spike proved that emission itself is possible.

Seed v2's B4 is falsified for cash acquisitions. Its claim about a population
of 22 is also retired: the corrected census has not run, so v3 establishes no
convertible quantity count.

The layer boundary, typed sealed fact, policy separation, closed model-basis
rule, atomicity requirement, and off-axis deferral survive unchanged.

## 2. Product question

What is the smallest honest contract that can admit evidenced corporate cash
distributions now, retain all other recognized equity-settlement facts without
pretending they are absent, and avoid binding the wrong lot operation?

The contract must separate vendor evidence, adapter normalization, modeled
daily policy, and account mutation. It must not make consideration shape stand
in for accounting shape.

## 3. The new partition

The primary partition is the mutation required after policy is selected.

| Class | Required account effect | v0.2.0.2 proposal |
| --- | --- | --- |
| A. Additive cash distribution | Add cash; no position, lot, basis, realization, or pending-claim mutation. | Admit through `CASHFLOW` after the single gate passes. |
| B. Lot settlement | Consume, extinguish, add, rewrite, or reallocate lots or basis; realization may be required. | Retain as recognized and unsupported. Do not mutate the account. |
| C. Off-axis receipt | Class B plus a recipient outside the sealed physical axis. | Retain and classify; defer with dynamic-axis valuation design. |

Dividends and pure distributions may qualify for Class A. Consideration paid
only in cash does not qualify by itself. Cash acquisitions belong to Class B
because the parent holding must be extinguished. Return of capital belongs to
Class B because basis changes even when quantity does not.

Received securities already on the physical axis are Class B, not a release
tier. Their valuation boundary is tractable, but the measured accounting
primitive is not. Recipient location remains useful only after a correct lot
transition exists.

If a daily model needs entitlement equity before spendable cash, it is not
Class A under this release. The fact remains visible and unsupported rather
than being collapsed into an immediate cash posting.

## 4. Preparation and core boundary

The pipeline remains:

```text
vendor-native action rows
  -> adapter decoding and unit normalization
  -> sealed vendor-neutral equity-settlement facts
  -> ledgr daily policy
  -> supported account effects or an explicit stop
```

The adapter owns vendor codes, action-specific units, parent and recipient
identity resolution, completeness classification, unit normalization, and a
versioned transformation-policy identity.

Normalization must close the standing Type 2 findings:

- parent and recipient factors use a compatible share epoch;
- exact cumulative split values are authoritative, with any rounded price
  quotient used only as an independent check;
- a positivity check is not validation because it cannot detect the disputed
  quantity error; and
- every normalized leg carries the bar references and vintage against which
  it was prepared.

ledgr receives canonical facts and verifies their shape, identities,
completeness, unit-basis declaration, referenced bars, and bar-vintage match.
It does not recompute vendor adjustment arithmetic.

## 5. One sealed fact family

One typed `equity_settlement` family belongs in the sealed fact bundle. It is
not lifetime free text and is not itself a ledger event. This remains real
schema, constructor, migration, seal, read, hash, and compilation work.

The fact needs at least:

- stable source-event and revision identities;
- a closed event subtype;
- parent and zero or more recipient identities;
- canonical cash and recipient-quantity legs per canonical parent unit;
- explicit completeness or unsupported classification;
- entitlement, effective, knowledge, and payment clocks when supplied;
- unit basis and transformation-policy identity; and
- parent and recipient normalization-bar references plus bar vintage.

The family stores Class A, B, and C facts. Admission is a compiler decision,
not a schema omission. A later lot-settlement design must not require the
source evidence to be resealed merely because its account projection changes.

## 6. Policy and basis

A separately versioned ledgr policy maps source clocks into the supported
daily model. That identity enters experiment identity and result output. The
policy never rewrites the sealed fact.

For Class A, the policy must identify when the modeled cashflow becomes
visible and spendable. Missing source clocks may be replaced only by a named
modeled convention whose unavailable claim is reported. If the policy needs a
pending entitlement asset, the fact is outside Class A for this release.

Class B remains subject to one closed model-basis derivation per admitted
subtype. It is called model basis, never vendor or tax basis. No basis amount,
cash in lieu, ratio, price, or payment time is fabricated to make a fact pass.

## 7. Ledger vocabulary after the spike

The v0.2.0.2 vocabulary is deliberately smaller than v2 proposed.

- An admitted Class A fact compiles to the existing `CASHFLOW` event, carrying
  source-fact identity, policy identity, and the canonical cash delta.
- Operation 3 remains the opening-position lot-insertion operation. Corporate
  settlement does not reuse its `opening_position` discriminator.
- No top-level `SETTLEMENT` event type is added in this release.
- Class B and C facts emit no account mutation. A held affected position stops
  with an explicit unsupported classification before mutation.

Future Class B support requires one atomic accounting operation that can
consume existing lots, add received lots, realize the selected economics, and
apply model-basis changes as one source-event group. The spike did not decide
whether that operation is serialized as a new event type or as a validated
group of typed events. This seed does not choose for it.

That is not a neutral event-name debate. The next runnable core must first
demonstrate correct consumption, reallocation, and rollback. Serialization is
chosen only after those semantics exist.

Canonical R remains the normative executable oracle. Any future compiled arm
must refuse an unknown economic event rather than complete after dropping it.

## 8. Atomicity and observability

The spike's prefix result rejects append-then-validate. A source event is
classified and all derived effects are validated before the first account
mutation or ledger append. Failure exposes no derived prefix.

Class A compiles to one validated cash effect. The same boundary must be able
to reject a fact whose classification changes after policy selection. This
does not claim that future multi-leg Class B is solved.

Pre-run output distinguishes at least:

- admitted additive cash distribution under a named policy;
- normalization unavailable or bar vintage mismatched;
- incomplete source consideration;
- lot or basis mutation required;
- recipient unresolved, unpriced, or outside the physical axis;
- unsupported election or subtype; and
- broker-exact treatment unavailable.

A recognized event is never represented as absent. Unsupported facts that
affect a holding stop before mutation; unheld facts may remain diagnostic.

## 9. Sequence

The compiled event-envelope guard is still an unowned prerequisite. Before
implementation starts, it needs an ordinary correctness ticket with an owner.
This RFC does not absorb it, and accepting this seed does not make it landed.

After that prerequisite, there are two stages:

1. Build the runnable Class A core: the common sealed fact family, adapter
   normalization with bar-vintage binding, ledgr verification and
   classification, policy identity, one CASHFLOW projection, and explicit
   unsupported handling for Classes B and C.
2. Run the single admission gate in section 10. A pass admits Class A only.
   A failure leaves all equity settlement unsupported.

The corrected recipient census may run concurrently, but its result is input
to a future Class B decision. It neither gates nor expands Class A, and v3
states no expected count.

## 10. One admission gate

The gate asks one question: does the runnable core admit only additive cash
distributions while preserving identity, normalization, atomicity, replay,
and explicit refusal everywhere else?

Its initial case set is capped at eight:

1. a distribution before and after a later parent split;
2. a fact prepared against a different bar vintage;
3. a missing or incompatible parent unit-basis witness;
4. a cash acquisition misclassified as cash-only;
5. a cash return that requires basis mutation;
6. interruption, resume, and reopen without duplicate application;
7. a malformed derived effect that leaves no prefix; and
8. an unknown pulse economic kind refused by both execution arms.

Real-population evidence is expressed as properties and explicit denominators,
not as a precommitted passing count. Every admitted row must satisfy the Class
A predicate and its normalization witness. Every other recognized row must
appear in one unsupported class. No positivity-only check counts as evidence.

## 11. Bets and falsifiers

| Bet | Falsifier |
| --- | --- |
| B1. Vendor decoding and normalization stay upstream. | ledgr cannot validate or replay the canonical fact without learning a vendor code or adjustment formula. |
| B2. One sealed family can retain all three classes. | Their source identity, clocks, or completeness require incompatible fact schemas rather than subtype validation. |
| B3. Accounting mutation is the honest release partition. | A Class A fact needs lot, basis, realization, or pending-claim state, or a Class B fact needs none of them. |
| B4. Additive distribution cash stays `CASHFLOW`. | A qualifying Class A case cannot be represented as one cash delta with source and policy identity. |
| B5. Operation 3 stays opening-only. | The existing operation consumes an earlier lot and performs the required settlement economics without opposing live lots. |
| B6. Validate-before-append provides atomic Class A projection. | Any failure, interruption, replay, or resume exposes a derived prefix or duplicate effect. |
| B7. Bar-vintage binding is vendor-neutral verification. | ledgr must recompute vendor arithmetic to detect a fact prepared against different bars. |
| B8. Closed model-basis derivations remain necessary for Class B. | An admitted subtype needs no basis rule, or one honest rule cannot be stated without fabricating an amount. |
| B9. Off-axis receipt remains a separate valuation problem. | The recipient already has sealed identity and price history, making it an on-axis Class B fact. |

## 12. What this seed rejects

It rejects the v2 tier table as the release partition, the unverified count of
22, reuse of opening-position operation 3 for settlement, and introduction of
`SETTLEMENT` before a consuming operation exists. It also rejects treating a
cash acquisition or return of capital as an additive cash distribution.

It does not reject the common fact family, upstream normalization, daily
policy separation, model-basis discipline, atomicity, or off-axis deferral.

## 13. What this seed does not authorize

It does not implement corporate actions, infer missing terms, rerun or publish
the census, put Sharadar logic in ledgr, widen the physical axis, change price
adjustment policy, add a ledger event type, design the future lot operation,
claim broker or tax fidelity, cut tickets, or change release scope by itself.

The Type 2 response should attack whether the mutation partition is honest,
whether Class A is smaller than the product value claimed for it, whether one
fact family still earns its schema cost, and whether deferring the event name
merely postpones a decision the runnable core actually needs.
