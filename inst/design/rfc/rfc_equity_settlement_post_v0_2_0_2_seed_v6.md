# Seed v6: Equity Settlement After v0.2.0.2

**Status:** Replacement RFC seed for Type 2 review; non-binding.
**Author:** Codex.
**Date:** 2026-09-23.
**Replaces:** `rfc_equity_settlement_post_v0_2_0_2_seed_v5.md`.
**New evidence:** `inst/design/spikes/terminal_disposition_policy_spike/`
and the companion research repository's corrected Tier 2 census. Both were
checker-reproduced from their recorded inputs; neither binds this seed.

## 1. Why v6 exists

V5 made exact quantity settlement the centre of the release and retained an
unconditional stop for every other held terminal event. That is internally
consistent and unusable for long research runs: a cash acquisition, mixed
deal, delisting or unsupported action can terminate a multi-year experiment.

The maintainer has now decided the product direction. Ordinary research runs
should finish under named, overridable settings. Strict refusal remains
available. No approximation may be silent: the resolved settings enter run
identity and every exercised approximation appears in ordinary results.

Two measurements change the design.

The bounded terminal-disposition spike used one scratch-only branch at the
existing stop. Reusing FIFO accounting and normal persistence was sufficient
to close a held position at a current or permitted stale mark, reach `DONE`,
resume exactly once and reopen with identical results. Strict mode and a case
without a permissible mark retained the existing stop. The prototype used a
`SELL` only as a mechanical device; it did not establish public vocabulary.

The corrected private Sharadar census then reproduced 41 candidate events.
Thirty-nine had documented economic terms, 24 recipients were on the existing
axis and 22 were normalized into the snapshot's split-adjusted unit basis.
Those 22 include ten clean single-recipient stock acquisitions; the remaining
twelve span mixed acquisitions and parent spin-offs. Non-identity conversion
was observed. No case was broker-exact. Exact detail remains private.

The ten clean exchanges are real future scope, not theoretical scaffolding.
But terminal disposition now solves the release's usability problem without
making grouped quantity settlement a prerequisite.

## 2. Product question

What is the smallest honest settlement policy that lets ordinary
availability-aware equity experiments finish when evidence is incomplete,
posts the cash effects that are ready, preserves strict refusal, and makes the
economic cost of every fallback unavoidable in identity and results?

## 3. Recommendation

This release should ship four things together:

1. one vendor-neutral sealed settlement-fact family;
2. a first-class settlement-policy argument with a research default and a
   strict preset;
3. evidenced gross cash distributions through existing `CASHFLOW`; and
4. a distinct modeled terminal-disposition event for held terminal assets.

It should not ship stock-for-stock, mixed or spin-off quantity mutation. Those
remain the next accounting RFC, now justified by ten, four and eight observed
daily-model cases respectively. The adapter should preserve their validated
facts and prepare recipient-axis closure now, so that deferral loses account
semantics rather than source evidence.

This is deliberate subtraction from v5. It removes grouped ledger rows, group
transactions, group-aware readers and basis-transfer semantics from the
current release. The fallback handles all held terminal subtypes; exact swaps
would improve fidelity for a measured subset but no longer decide whether a
run completes.

## 4. Producer boundary

The adapter owns vendor decoding, stable identities and unit normalization.
For every recognized action it emits one typed, vendor-neutral fact carrying:

- stable fact, parent and recipient identities where known;
- closed subtype and source clocks kept separately;
- canonical cash or quantity terms only when their source meaning, unit and
  split-adjusted conversion are verified;
- canonical build, bar-vintage and normalization-policy identity; and
- completeness state with one closed refusal reason.

An incomplete fact retains its header and reason and receives no guessed leg.
ledgr never sees Sharadar codes, `closeunadj` or a vendor conversion formula.

The corrected census is sufficient evidence for the acquisition and spin-off
shape. It is not the missing population check for distributions. Before a real
distribution gate, the adapter must validate the pinned dividend amount unit,
normalize it to canonical parent units and reconcile the real population.
This is upstream acceptance work, not a calculation ledgr repeats.

Resolved recipients may be added to the sealed physical valuation axis by the
already measured fixed-point closure. They do not join membership, become
tradable or enter a strategy-visible cross-section while unheld. Feature
preparation must use the strategy's declared public domain, not every physical
axis row; otherwise closure is rejected for that experiment.

## 5. One policy surface

`ledgr_experiment()` gains `settlement_policy`. Omitting it resolves to the
research preset. Users may instead select the strict preset or construct a
policy from closed values. Arbitrary callbacks are not accepted.

The public vocabulary stays short. Versioned internal identifiers are what
the config records and hashes. The first implementation needs these choices:

| Knob | Research preset | Other admitted choices |
| --- | --- | --- |
| distribution amount | `gross` | `refuse` |
| distribution posting | `next_open` | `effective_close`, `refuse` |
| held terminal asset | `last_mark` | `last_permissible`, `refuse` |
| unsupported nonterminal quantity event | `report_only` | `refuse` |

`last_mark` means the latest finite sealed observation at or before the event,
even when it is older than the ordinary valuation staleness limit. That
override is terminal-only and must report source time and age.
`last_permissible` obeys the valuation policy. If the selected rule has no
finite qualifying observation, it refuses; no zero or price is fabricated.

The research preset is a model configuration, not a claim that its values are
economic truth. The strict preset selects `refuse` for every approximation.
Adding a new choice later is an identified contract change, not an unversioned
string accepted by a parser.

## 6. Account effects

### 6.1 Gross distributions

A distribution is admitted only after the adapter validates and normalizes a
documented gross amount per canonical parent unit. ledgr posts one existing
`CASHFLOW` at the selected convention. It makes no payment-time, withholding,
investor-tax or net-cash claim.

### 6.2 Modeled terminal disposition

A recognized terminal fact never becomes complete merely because fallback is
allowed. Evidence classification and account policy remain separate.

For a held terminal asset, the research preset consumes the live lots at the
selected mark, realizes model PnL under canonical FIFO, removes the position
and credits or debits cash. It persists one `DISPOSITION` event, not a `FILL`:
no exchange execution, order, fee or broker settlement is asserted.

The event carries source-fact identity when present, policy identity, quantity,
mark, source timestamp, age, before/after position, realized model PnL and the
terminal subtype. Validate first, then mutate and persist inside the existing
fold transaction. Resume must not apply it twice.

The strict preset retains `terminal_settlement_unsupported`: preserve the
holding and stop. The current contract is therefore narrowed explicitly, not
silently contradicted. Corrupt state, contradictory facts and a missing mark
required by the selected rule still fail; permissive does not mean invalid
state is repaired.

### 6.3 Unsupported nonterminal facts

`report_only` changes no account state. It records that a recognized quantity
event, such as a spin-off, was omitted under policy. This is an approximation,
not absence. Strict mode stops when an affected instrument is held.

## 7. Identity and ordinary results

The fully resolved policy, including defaults, enters experiment and run
identity. Reopen verifies the same identity. Historical runs do not acquire a
new implicit policy.

The standard run summary, not a specialist reader, shows:

- the short selected settings and their versioned identities;
- counts by exercised setting and reason;
- affected instruments and gross marked exposure in aggregate;
- cash posted, positions disposed and realized model PnL; and
- unsupported facts reported without mutation.

Zero use is reported as zero, not omitted. Raw events remain available, but a
clean equity curve without this summary is not an acceptable result surface.

One executing vignette runs the same fixture under research and strict
presets side by side. The common example requires no settlement argument. The
strict example demonstrates the stop; the research example demonstrates the
counted approximation.

## 8. Compiled boundary

Before any pulse-level economic event ships, compiled spot-FIFO must refuse a
plan containing `CASHFLOW`, `DISPOSITION` or a future quantity settlement. It
may not silently drop the event. This release does not add compiled settlement.

Canonical R remains the executable authority for every new account effect.

## 9. Scope of exact quantity settlement

V5's nonrealizing stock exchange is deferred, not rejected. The measured ten
clean cases make it the first follow-up, ahead of broader mixed and spin-off
semantics. Its RFC owns lot-basis transfer, group serialization, transaction
boundaries, public-reader validation and compiled behavior.

The sealed producer fact may retain validated canonical legs and recipient
closure because those fields are already evidenced. This release must not
project them into positions or claim that their presence settled an event.

## 10. One release gate

One gate, capped at ten cases, must detect:

1. gross distribution normalization across a later parent split;
2. `next_open` and `effective_close` posting distinct identified cash results;
3. current, permitted-stale and beyond-horizon finite terminal marks, each
   with the correct source and age;
4. strict refusal versus research disposition on the same held terminal;
5. no finite qualifying mark causing no mutation or fabricated price;
6. interruption, resume, replay and reopen applying one disposition once;
7. `report_only` surfacing an unsupported held nonterminal fact while strict
   refuses it;
8. physical closure leaving membership, strategy features and pre-event fills
   unchanged;
9. standard summary counts and affected-value fields changing under a gutted
   reporting path; and
10. compiled execution refusing the economic-event envelope before running.

Synthetic fixtures provide failure sensitivity. A private real-data gate then
reconciles the distribution population and the corrected 41-event partition
without publishing identifiers, prices, action values or suppressed cells.

## 11. Sequence

1. Accept a revised Sharadar producer specification and the RFC synthesis.
2. Land the compiled economic-event-envelope guard.
3. Implement upstream facts, distribution validation, normalization, refusal
   states and fixed-point physical closure.
4. Add policy construction, identity, summaries and documentation before any
   permissive behavior becomes the default.
5. Implement gross `CASHFLOW` and canonical-R `DISPOSITION`.
6. Run the one gate and one independent workstream review.

The default may not change before its identity, summary and strict alternative
exist. Synthetic ledgr work may precede private data; the real gate may not.

## 12. Bets and falsifiers

| Bet | Falsifier |
| --- | --- |
| B1. One policy surface is smaller than subtype-specific modes. | A required behavior cannot be expressed without a callback, hidden precedence or subtype-specific API. |
| B2. Terminal disposition is a bounded account effect. | Production needs another execution, valuation or persistence seam beyond the terminal branch. |
| B3. `last_mark` makes ordinary runs usable without pretending certainty. | Real held terminal cases lack any prior finite sealed mark, or users cannot identify its use from ordinary results. |
| B4. Reporting prevents permissive defaults from becoming silent error. | A run can use a fallback while identity or the standard summary remains unchanged. |
| B5. Gross cash is ready once the adapter verifies the population. | Dividend meaning or unit cannot be validated and normalized without an inferred amount. |
| B6. Quantity settlement can wait without losing evidence. | The fact family or axis cannot retain evidenced recipient terms without committing ledgr to their account semantics. |
| B7. The compiled boundary fails closed. | A new event reaches compiled execution or is silently omitted. |

## 13. What v6 rejects

V6 rejects v5's refusal-centred default, mandatory user choice, and grouped
quantity settlement as the release's usability mechanism. It also rejects a
synthetic `SELL` as public truth, silent omission as resilience, and a separate
assumption reader as adequate disclosure.

It keeps the vendor boundary, normalized sealed facts, bar-vintage binding,
static closure, gross-cash semantics, canonical-R authority and compiled
guard. It records exact quantity settlement as a measured, high-priority
follow-up rather than carrying its unbuilt persistence system into this scope.

This seed authorizes no code, ticket, schema migration, producer acceptance or
release. It uses "first implementation" only for this settlement-policy
surface; the roadmap has no settlement v1 milestone.
