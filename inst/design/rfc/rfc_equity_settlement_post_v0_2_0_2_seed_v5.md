# Seed v5: Equity Settlement After v0.2.0.2

**Status:** Revised RFC seed for focused Type 2 review; non-binding.
**Author:** Codex.
**Date:** 2026-09-23.
**Revises:** `rfc_equity_settlement_post_v0_2_0_2_seed_v4.md`.
**New evidence:** the independently reviewed settlement-axis-density spike.

This is a narrow historical successor. It changes persistence and the proven
axis boundary. It does not reopen the accepted evidence, policy, or accounting
direction from seed v4.

## 1. Why v5 exists

The Type 2 review of v4 found that its one-row `SETTLEMENT` proposal cannot
feed existing position reconstruction. One persisted row has one
`instrument_id` and one scalar position delta; a stock exchange affects at
least a parent and recipient. The atomic spike proved a lot-state transition,
not compatibility with the production event projections.

The same review inferred that a late-start recipient could not join a sealed
axis because one finalization branch requires a dense close matrix. The bounded
density spike falsified that inference for the public availability path it ran.
A hidden non-member with no pre-entitlement bars became held at its first real
bar, completed, and reopened identically to a complete-history control.

The spike does not generalize to finalization without a prepared bar matrix or
fold equity. This seed does not make that generalization.

## 2. Product question

What is the smallest honest daily-model contract that can post evidenced gross
cash distributions and nonrealizing pure-stock exchanges, while preserving
existing per-instrument reconstruction and refusing incomplete evidence,
groups, marks, policies, or compiled handling before mutation?

## 3. Admission remains two-dimensional

The adapter decides evidence readiness:

| State | Meaning |
| --- | --- |
| `canonical_ready` | Meaning, identities, units, normalized legs, clocks required by policy, bar references, and build identity are verified. |
| `canonical_incomplete` | A recognized event lacks or contradicts at least one required claim; no leg is guessed. |

ledgr then decides account effect:

| Effect | v0.2.0.2 scope |
| --- | --- |
| `additive_gross_cash` | Supported under one explicit gross-amount policy and one explicit posting policy. |
| `nonrealizing_stock_exchange` | Supported only by the closed one-parent, one-recipient carryover rule in section 6. |
| `other_settlement` | Recognized and refused. |

A mutation shape never upgrades incomplete evidence.

## 4. Upstream producer and physical closure

The Sharadar adapter owns vendor decoding and unit normalization. Before the
real-data ledgr gate it must:

- validate pinned action definitions before decoding values;
- group source rows under stable parent and recipient identities;
- normalize cash and recipient quantities into snapshot units;
- bind the canonical bar vintage and normalization policy;
- preserve entitlement, effective, knowledge, and payment clocks separately;
- emit explicit incomplete reasons rather than guessed legs; and
- compute recipient closure to a fixed point across the supported window.

Closure adds resolved recipients to the physical valuation axis only. It must
not add them to membership, alter trading status, or make them strategy-visible
while they are neither members nor held. A recipient of a recipient is included
when its resolved event also falls inside the supported window.

For the release path, a recipient needs a real usable mark when its holding
becomes effective and the required forward valuation coverage. It does not need
invented bars before entitlement or complete history across the experiment.

This claim is limited to availability-aware runs carrying the prepared ragged
bar matrix and fold equity exercised by the density spike. Another execution
path must establish its own evidence or refuse settlement before running.
The null-`bars_mat` reconstruction branch is unchanged.

## 5. Sealed fact family

ledgr receives one typed, vendor-neutral `equity_settlement` fact family. A
complete fact carries stable event identity, parent, subtype, source clocks,
canonical normalized legs, normalization-policy identity, bar/build binding,
and completeness state. An incomplete fact retains its header and reason but
contains no guessed leg.

The fact is not a ledger event. Snapshot identity binds it without another
hash, registry, or provenance manifest. Basis allocation, posting, withholding,
and account mutation remain ledgr policies rather than adapter claims.

## 6. Supported daily-model policies

Historical row-publication time is unavailable. Each experiment therefore
chooses `assume_effective_knowledge_v001` or strict refusal. The choice enters
experiment identity and disclosure.

### 6.1 Gross distribution

`gross_vendor_distribution_v001` admits only a documented cash amount per
canonical parent unit. It makes no payment-time, withholding, investor-tax, or
net-cash claim.

The experiment explicitly chooses `ex_date_close_v001` or
`next_session_open_v001`; there is no default. The convention and unavailable
payment-time claim enter identity and results. The mutation is one existing
`CASHFLOW` event with source-fact, amount-policy, and posting-policy identity.

### 6.2 Nonrealizing pure-stock exchange

The closed rule requires one terminating parent, exactly one resolved recipient
on the prepared axis, one positive canonical ratio, no cash or election, and
`nonrealizing_full_basis_carryover_v001`.

At `first_session_on_or_after_effective_v001`, every live parent lot is
consumed. A recipient lot receives parent quantity times the canonical ratio
and the parent's full model basis. Total model basis is conserved, realized PnL
does not change, and fractional units remain fractional. This is a labelled
research model, not broker, legal, payment, withholding, or tax truth.

Any missing real mark, normalization claim, source term, or policy refuses the
group before account mutation.

## 7. Persisted settlement group

A stock exchange persists as one logical `SETTLEMENT` group with one row per
affected instrument, not one opaque row. In the supported rule that means one
parent row and one recipient row.

Each row retains ordinary `instrument_id` and scalar position delta so current
per-instrument cumulative reconstruction remains authoritative. Validated
metadata carries a shared settlement-group identity, source-fact identity,
row index, expected row count, parent or recipient role, posting policy, basis
policy, and the lot transition belonging to that instrument. Event identities
are deterministic per group row.

The preparer validates the complete group and pre-state before mutation:

- exactly the expected rows and unique row indices are present;
- group, source, timestamp, roles, and policies agree;
- parent and recipient position deltas match canonical quantities;
- all consumed parent lots exist and no lot is consumed twice;
- successor lots conserve total model basis and realize nothing; and
- projected positions equal successor lot net quantities.

The handler appends the complete row block in one transaction after the
successor state validates. Memory uses one block append. Replay groups rows and
repeats completeness and duplicate checks before applying any row. A partial,
duplicate, malformed, interrupted, or inconsistent group exposes neither an
account prefix nor a ledger prefix.

Existing position projections continue to sum scalar deltas by instrument.
Economic-event reporting groups the physical rows by settlement-group identity;
raw row count is not presented as economic-event count.

Cash distributions remain single-row `CASHFLOW`. Opening-position metadata is
not reused as settlement vocabulary. Canonical R remains the executable oracle.

## 8. Unsupported and failure visibility

The release refuses cash or mixed acquisitions, parent-retained spin-offs,
basis-only returns of capital, elections, multiple recipients, fractional cash,
cash in lieu, net withholding, unresolved identities, runtime axis growth, and
any event needing an inferred term or price.

Recognized unsupported facts are reported before execution. If an affected
instrument is held when the fact applies, the existing
`terminal_settlement_unsupported` meaning preserves the holding and mutates
nothing. Unheld facts may remain diagnostic.

If a recipient has no permissible mark when quantity would appear, the group
does not append. The outcome must be an intentional settlement or valuation
reason with finite diagnostic payload, never `ledgr_config_non_finite`. The
density spike observed that lower-level error and did not authorize its repair.

## 9. Compiled prerequisite

Before any pulse-level economic event lands, compiled spot-FIFO must reject a
plan containing `CASHFLOW` or `SETTLEMENT`. It may not silently omit the event.
This release does not implement compiled settlement.

## 10. One admission gate

One end-to-end gate is capped at ten cases:

1. gross distribution before a later parent split;
2. both posting conventions produce distinct labelled results, while an
   unstated convention or knowledge policy is rejected;
3. wrong bar build, price policy, or normalization version is rejected;
4. a two-row one-recipient exchange across multiple parent lots preserves
   quantity, total basis, realization, and existing position projections;
5. missing, duplicate, inconsistent, or partial group rows leave no account or
   ledger prefix;
6. fixed-point closure over a parent, recipient, and later recipient leaves
   membership and pre-settlement fills identical to the unaugmented case;
7. late-start and complete-history recipients match on the supported
   availability path; a missing effective mark fails intentionally;
8. cash acquisition, mixed acquisition, spin-off, unresolved recipient, and
   unsupported execution path each retain their actual refusal reason;
9. interruption, resume, replay, and reopen apply each group once; and
10. compiled spot-FIFO refuses the economic-event envelope before execution.

Synthetic cases establish failure sensitivity. Private Sharadar evidence then
reconciles eligible, refused, and fixed-point closure aggregates without
publishing identifiers, prices, action values, or suppressed cells.

## 11. Sequence

1. Accept the revised Sharadar producer specification and RFC synthesis.
2. Land the compiled event-envelope guard.
3. Implement upstream facts, normalization, refusal states, membership
   invariance, and fixed-point physical closure.
4. Implement the ledgr fact schema, path preflight, and intentional unpriced
   refusal against synthetic fixtures.
5. Implement gross distributions and `CASHFLOW` projection.
6. Implement grouped canonical-R `SETTLEMENT`, transactional append, replay,
   results, interruption, resume, and reopen.
7. Run the single gate and one independent workstream review.

Synthetic ledgr work may precede private data. The real gate cannot precede an
accepted upstream build.

## 12. Bets and falsifiers

| Bet | Falsifier |
| --- | --- |
| B1. Fixed-point static closure is the right availability boundary. | A resolved recipient cannot be presealed, remains visible before membership or holding, changes membership or fills, or requires runtime axis growth. |
| B2. Pre-entitlement history is unnecessary on the supported path. | A late-start recipient with a real effective mark diverges from the complete control in ordinary availability execution, finalization, results, or reopen. |
| B3. The producer boundary is vendor-neutral. | ledgr must know a Sharadar code, raw vendor value, `closeunadj`, or normalization formula. |
| B4. Gross cash is honest under explicit labels. | The amount meaning is undocumented or the policy makes an undisclosed payment, withholding, or tax claim. |
| B5. Full carryover is closed. | It needs an unavailable basis split, realization, election, cash leg, or fabricated recipient mark. |
| B6. Grouped rows preserve current projections. | Correct replay requires nested-payload position reconstruction or a second position authority. |
| B7. Validate-then-append is atomic. | Any bad, interrupted, resumed, or replayed group exposes a prefix or duplicate effect. |
| B8. The compiled boundary fails closed. | A planned economic event reaches compiled execution or is silently dropped. |

## 13. Changes from v4 and non-authority

V5 accepts response-v4 F1 and replaces one opaque settlement row with one
validated group of per-instrument rows. It adds group-completeness replay and
keeps the existing scalar-delta position authority.

The density spike refutes response-v4 F2 only for the executed public
availability path. V5 narrows closure to that path, requires a real effective
mark, adds membership-invariance and fixed-point cases from F3, and makes the
non-finite diagnostic failure explicit. F4 is closed by testing the consumer
boundary before the real-data gate.

All other v4 directions survive: upstream normalization and bar vintage,
sealed vendor-neutral facts, explicit gross-cash and posting policies,
one-recipient carryover, refusal of broader settlement, atomicity, and the
compiled guard.

This seed authorizes no code, ticket, schema migration, census rerun, licensed
publication, membership change, dynamic axis, broker or tax claim, or compiled
settlement. The companion Sharadar draft must be revised consistently after
this seed survives Type 2 review; this seed does not accept it by itself.
