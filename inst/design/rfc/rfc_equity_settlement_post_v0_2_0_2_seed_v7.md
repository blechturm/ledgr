# Seed v7: Usable Equity Corporate Actions Without False Completeness

**Status:** Replacement RFC seed for Type 2 review; non-binding.
**Author:** Codex.
**Date:** 2026-09-24.
**Replaces:** `rfc_equity_settlement_post_v0_2_0_2_seed_v6.md`.

## 1. Why v7 exists

V6 answered the immediate execution problem but left three product questions
implicit. It used the generic name `settlement_policy` for equity-specific
behavior, it made approximation disclosure a result detail rather than a
headline quality signal, and it did not make the producer contract teachable
without Sharadar knowledge.

The maintainer has also made a release-boundary decision. Exact parent-to-
recipient quantity and model-basis transformation is scheduled for one of the
next equity-accounting releases under its own RFC. It is not part of this
release and is not an unowned horizon aspiration.

That deferral is a real capability gap. The corrected census found 41
transformation candidates and 22 daily-model-ready cases, including 10 clean
single-recipient stock acquisitions. A terminal disposition does not preserve
future recipient exposure, and it cannot substitute for receiving a spin-off
while the parent continues trading. The gap is material for buy-and-hold,
index, spin-off, merger-arbitrage, tax-lot and broker-reconciliation work.

The horizon comparison records that common engines also stop at liquidation
or partial security distributions. That bounds the market gap without
lowering ledgr's eventual correctness target.

Executed evidence is narrower: the quantity-primitive spike closed RED; the
axis-density spike closed GREEN only on its scoped public path; and terminal
disposition closed GREEN for current and permitted stale marks, refusal
without a mark, resume-once and reopen parity.

## 2. Product question

What is the smallest vendor-neutral equity-corporate-action product that lets
ordinary research complete under explicit modeled assumptions, keeps strict
refusal available, makes economic incompleteness impossible to overlook, and
does not claim exact position transformation before that capability exists?
## 3. Recommendation

This release should ship one coherent equity-corporate-action slice:

1. a sealed, vendor-neutral `equity_corporate_actions` fact family;
2. a first-class `corporate_action_policy` with a zero-configuration research
   preset and an explicit strict preset;
3. evidenced gross cash distributions through existing `CASHFLOW`;
4. modeled terminal disposition through a distinct `DISPOSITION` event;
5. headline corporate-action fidelity in ordinary results; and
6. an executable data-contract vignette plus a synthetic non-Sharadar
   conformance example.

It should preserve and report evidenced quantity-changing facts but should not
turn them into positions in this release. It should not claim corporate-action
completeness, broker-exact settlement, net cash, tax correctness or exact
recipient exposure.
## 4. Architecture boundary

The product has three layers. Their names and responsibilities must not blur.

### 4.1 Adapter-private vendor layer

An adapter decodes source codes, resolves stable parent and recipient
identities, validates source meanings, normalizes quantity and cash terms into
the snapshot's unit basis, preserves available clocks and emits explicit
refusal states. Sharadar-specific fields, action codes and conversion formulas
end here.

The Sharadar repository needs a reviewed producer specification before its
facts become release evidence. It owns the pinned action-type meanings,
split-factor conversion, recipient resolution, bar-vintage binding, population
reconciliation and privacy-safe evidence. ledgr does not repeat those
calculations.

### 4.2 Sealed canonical fact layer

ledgr accepts facts through a public constructor consistent with its existing
family-first surface, provisionally `ledgr_facts_equity_corporate_actions()`.
The family has a header and evidenced terms, not a vendor payload and not a
pre-serialized accounting event.

The header carries stable fact identity, subtype, parent identity, the four
clocks when supplied, knowledge time, build and bar-vintage identity,
normalization-policy identity, completeness and one closed refusal reason.
The clocks remain distinct: entitlement, effective, knowledge and payment.
An unavailable clock remains unavailable; another clock is not copied into it.

Terms may carry a normalized gross cash amount, a recipient identity and a
normalized recipient quantity per parent unit when each is independently
validated. Their presence preserves source evidence. It does not assert that
ledgr can execute the economic transformation.

The constructor and seal validator own row shape, keys, finite domains,
identity references and clock ordering. They do not decode a vendor or infer a
missing term. A future exact-quantity RFC may require a schema migration or a
reseal; this release does not promise that today's evidence shape is the final
accounting contract.
### 4.3 Runtime accounting-effect layer

ledgr resolves a policy against sealed facts and emits only account effects it
actually supports. The internal concepts stay asset-neutral: cash movement,
position disposal, future position consume/create, lot-basis transition,
clocks, policy identity and approximation reporting.

The public fact family and policy are deliberately equity-specific. Crypto
token events, futures settlement, option exercise and physical delivery may
later use some of the same internal effects, but they receive their own fact
families and policies. This release does not create a universal settlement API
whose equity assumptions would constrain those assets.
## 5. Public experience

The ordinary path needs no new argument:

```r
experiment <- ledgr_experiment(snapshot, strategy)
```

Omission resolves to the versioned research preset. The explicit forms are:

```r
research <- ledgr_experiment(snapshot, strategy,
  corporate_action_policy = ledgr_corporate_actions_research())
strict <- ledgr_experiment(snapshot, strategy,
  corporate_action_policy = ledgr_corporate_actions_strict())
```

Advanced users may construct a policy from closed values. Arbitrary callbacks
are not accepted. The first policy surface has four choices:

| Choice | Research preset | Other admitted value |
| --- | --- | --- |
| cash amount | `gross` | `refuse` |
| cash posting | `next_open` | `effective_close`, `refuse` |
| held terminal position | `last_mark` | `last_permissible`, `refuse` |
| unsupported quantity event | `report_only` | `refuse` |

`last_mark` means the latest finite sealed mark at or before the terminal
event, even beyond the ordinary staleness horizon. This beyond-horizon rule
was not executed by the spike and must earn its place in the release gate.
It is terminal-only and reports the source time and age. No finite qualifying
mark means refusal; zero and fabricated prices are forbidden.

The resolved policy, including defaults, enters experiment and run identity.
Historical runs do not acquire it implicitly.
## 6. Honest completion

Execution state and economic fidelity answer different questions. The release
should not overload `DONE`, `INCOMPLETE` and `FAILED` with both.

Ordinary results add a headline `corporate_action_fidelity` value:

- `none`: no supplied fact affected a held instrument;
- `evidenced`: every exercised effect used supported evidenced semantics;
- `modeled`: at least one configured cash-posting or disposition convention
  was exercised; and
- `unsupported`: at least one relevant supplied fact was reported without its
  economic position effect.

Severity is monotone: `unsupported` outranks `modeled`, which outranks
`evidenced`, which outranks `none`. A run may therefore be `DONE` while its
ordinary printed result says `corporate actions: UNSUPPORTED`. That wording is
not a warning hidden in a specialist reader.

The same summary shows selected settings and identities, counts by exercised
choice and refusal reason, aggregate affected marked exposure, gross cash
posted, positions disposed, realized model PnL and unsupported facts. Zero is
printed as zero. Raw events and facts remain inspectable.

This quality field speaks only about supplied corporate-action facts. It must
not claim the source was complete or that no unknown event existed.
## 7. Supported account effects

### 7.1 Gross cash distributions

A distribution is admitted only after the adapter validates and normalizes a
documented gross amount per canonical parent unit. ledgr posts one existing
`CASHFLOW` at the selected convention. It asserts neither payment-date truth,
withholding, investor tax nor broker net cash.

### 7.2 Modeled terminal disposition

For a held terminal asset, the research preset consumes the live lots at the
selected evidenced mark, realizes model PnL under canonical FIFO, removes the
position and moves cash. It persists `DISPOSITION`, not `FILL`: no exchange,
broker, order, fee or executable trade is asserted.

The event carries source-fact and policy identity, quantity, mark, source
timestamp, age, before/after position, realized model PnL and terminal subtype.
Validation precedes mutation, and the existing fold transaction makes the
effect atomic. Interruption and resume apply it once.

Strict mode retains `terminal_settlement_unsupported`, preserves the holding
and stops. Contradictory facts, corrupt state and a missing mark required by
the policy also stop.

### 7.3 Unsupported quantity effects

`report_only` changes no account state. It records that a relevant acquisition
or spin-off effect was omitted and raises fidelity to `unsupported`. Strict
mode stops when the affected parent is held. Neither behavior is described as
settlement.

## 8. Data preparation and documentation

The release includes an executable vignette provisionally titled
`Preparing Equity Corporate-Action Data for ledgr`. With fictional vendor
data it teaches the private-to-canonical boundary, headers and terms, keys,
clocks, units, refusal states, physical axis versus membership, construction,
validation, sealing, reopening, inspection, policy presets, and the difference
between preserved facts, executed effects and unsupported effects.

A synthetic adapter with different source column names and codes must build
the same canonical facts and pass the same constructor and seal validator.
This is the vendor-neutrality witness. It must not call a Sharadar helper or
reproduce a Sharadar formula.

The constructor and validator are the authority. The vignette is executable
teaching, not a prose schema that can drift independently.
## 9. Compiled boundary

Before either new pulse-level economic effect ships, compiled spot-FIFO must
refuse a plan containing `CASHFLOW`, `DISPOSITION` or a future quantity
transformation. It may not drop one silently. Canonical R remains the
executable authority. This release adds no compiled settlement behavior.

## 10. Exact quantity follow-up

The roadmap now schedules a focused RFC for one of the next equity-accounting
releases. It owns atomic parent/recipient event groups, parent consumption,
recipient creation, mixed cash legs, model-basis transfer, fractional claims,
replay and reopen, off-axis valuation and compiled refusal or support.

The corrected census is its empirical input. Exact quantity settlement is not
required to make this release useful, but it is required before ledgr can
claim complete acquisition or spin-off accounting. The follow-up may change
the fact schema if its runnable core proves today's fields insufficient.

## 11. One release gate

One gate, capped at ten cases, must detect:

1. a fictional non-Sharadar adapter producing the canonical fact shape;
2. dividend normalization across a later parent split;
3. distinct identified `next_open` and `effective_close` cash results;
4. current, permitted-stale and beyond-horizon terminal marks with source age;
5. strict refusal versus research disposition on the same held terminal;
6. no finite mark causing no mutation and no fabricated value;
7. interruption, resume, replay and reopen applying one disposition once;
8. `report_only` changing headline fidelity and summary but no account state;
9. physical closure leaving membership, pre-event features and fills intact;
10. compiled execution refusing the economic-event envelope before running.

The upstream private gate separately reconciles the distribution population
and corrected transformation census without publishing identifiers, prices,
action values or suppressed cells.

## 12. Sequence

1. Accept the ledgr synthesis and a companion Sharadar producer specification.
2. Land the compiled economic-event-envelope refusal.
3. Add the canonical constructor, sealed fact family, synthetic adapter and
   executable vignette.
4. Add policy identity, corporate-action fidelity and ordinary summaries.
5. Implement gross `CASHFLOW` and canonical-R `DISPOSITION`.
6. Run the one gate and one independent workstream review.

The research default cannot change before strict mode, identity, fidelity and
ordinary reporting exist. No exact-quantity ticket enters this workstream.

## 13. Bets and falsifiers

| Bet | Falsifier |
| --- | --- |
| B1. The research preset makes ordinary studies usable. | Real held terminal cases commonly lack an evidenced finite mark, or routine runs remain incomplete for another corporate-action reason. |
| B2. A separate fidelity axis makes approximation unavoidable. | A user can consume headline returns without seeing `modeled` or `unsupported`, or a gutted reporting path leaves the ordinary result unchanged. |
| B3. The canonical fact family is vendor-neutral. | The fictional adapter needs a Sharadar field, code or conversion helper to pass validation. |
| B4. Equity-specific public names preserve cross-asset freedom. | A supported internal effect requires an equity concept, or a future asset class would need to pretend its lifecycle event is a corporate action. |
| B5. Cash and terminal disposition are a coherent small release. | Either effect requires grouped multi-instrument persistence, another execution engine or a new valuation seam. |
| B6. Quantity settlement can follow without dishonest claims now. | A supported release claim or common documented workflow requires recipient exposure rather than an explicit modeled or unsupported result. |
| B7. The default remains reversible. | A historical run changes meaning, strict refusal is not selectable, or policy identity cannot distinguish the choices. |

## 14. What v7 rejects

V7 rejects a generic `settlement_policy`, a universal cross-asset fact family,
silent completion, a fake sale, specialist-only disclosure, exact quantity
mutation in this release and the claim that preserving current terms guarantees
no future reseal. It also rejects competitor incompleteness as a reason to
lower ledgr's long-term target.

It retains v6's zero-configuration research direction, strict preset, adapter
ownership, sealed canonical facts, gross cash, terminal disposition,
bar-vintage binding, physical closure, canonical-R authority and compiled
refusal. It turns exact quantity transformation into scheduled follow-up work
and makes product usability, data preparation and economic fidelity part of
the design rather than documentation afterthoughts.

This seed authorizes no code, schema migration, ticket or default change.
