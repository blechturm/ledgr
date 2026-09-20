# Sharadar Corporate-Event Evidence For Release Scoping

Date: 2026-09-20. Non-binding empirical input to the existing v0.2.x
corporate-actions and explicit accounting-event directions. This is not an
RFC, accepted release scope, vendor schema, or implementation authorization.
Scheduling update: the maintainer assigned the bounded equity direction to
v0.2.0.2 on 2026-09-20; the roadmap owns that commitment. This note remains
evidence rather than an economic or API contract.

## Source and evidence limits

Sources are the private `blechturm/ledgr-research` repository at
`a7b24b3b694a3ee754c61537339ec24679e9d3a0`:

- [Corporate-event inventory](https://github.com/blechturm/ledgr-research/blob/a7b24b3b694a3ee754c61537339ec24679e9d3a0/experiments/EXP-0002-sharadar-ledgr-baselines-v0.1.1/corporate-event-inventory.md).
- [Worked terminal-stop investigation and correction](https://github.com/blechturm/ledgr-research/blob/a7b24b3b694a3ee754c61537339ec24679e9d3a0/experiments/EXP-0002-sharadar-ledgr-baselines-v0.1.1/valuation-stop-investigation.md).
- [LFB-001 and LFB-011](https://github.com/blechturm/ledgr-research/blob/a7b24b3b694a3ee754c61537339ec24679e9d3a0/docs/governance/ledgr-feedback.md): missing dividend cashflows and held-security transformations/distributions.
- [Qualified Batch C results](https://github.com/blechturm/ledgr-research/blob/a7b24b3b694a3ee754c61537339ec24679e9d3a0/experiments/EXP-0002-sharadar-ledgr-baselines-v0.1.1/results.md).

These are author-reported executed findings, inspected as tracked documents;
the private data and R runs were not independently reproduced for this note.
Only non-reconstructive aggregates are imported. Counts below five remain
suppressed. Events are counted by source security and effective date; event
families can describe the same transaction and must not be summed as unique
economic events. Potential population exposure is not proof of later holdings.

## What the census establishes

The existing population contains 563 instruments over 757 sessions in 2019-2021.

| Event or observation | Reported evidence |
| --- | --- |
| Target acquisitions | 23; includes 11 stock and six mixed stock/cash cases, with other forms suppressed below five. |
| Delistings | 24; all 24 in-window price-history endings correspond to delistings. |
| Long member-price gaps | Eight exceed the two-session stale horizon; all terminate without resuming and have nearby acquisition/delisting evidence. No separate unexplained long-gap class was found. |
| Spin-offs | 24 parent events across 23 instruments. |
| Splits | 23 events across 22 instruments; current bars are split-adjusted. |
| Cash dividends | 5,034 events across 457 instruments. |
| Ticker changes | 30; stable identities and prices reportedly continue across the changes. |

The six retained scenario runs cover only a common 31-session prefix.
Established holdings cross 145 dividend events and suppressed low-count
spin-off and acquisition/delisting exposure. The dividend count does not prove
145 payments were due inside the prefix; entitlement and payment clocks differ.
Cash, positions and equity reconcile under implemented price-accounting rules,
but omitted distributions prevent economically complete total-return claims.

The adapter previously withheld an accepted delisting when its listing start
was unknown. The narrow fix exports the terminal assertion independently;
all 24 delistings now produce terminal facts. A representative held run stops
with `terminal_settlement_unsupported`, not fabricated successor units or cash.
This adapter correction is distinct from missing ledgr settlement accounting.

## Data requirements remain unresolved

The retained action records identify events but do not supply documented units
for every numeric value, row-level publication times, or complete settlement
terms. Dividend ex-dates and amounts survive; payment dates do not. Twenty-one
target acquisitions resolve to one stable counterparty; that does not establish
their exchange ratios. Spin-off entitlements likewise need supported terms.

The worked acquisition has public contractual terms, but the source terminal
date and legal completion date differ. `assume_effective` is an explicit
knowledge-time assumption, not evidence of historical publication. Its
fractional-cash formula uses a five-trading-day VWAP ending three trading days
before effectiveness, not a post-event pricing window; the exact required
VWAP/holder inputs and posting time remain unresolved. Do not generalize this
contract to other transactions or decode an undocumented vendor number as a ratio.

Current quantities and split-adjusted prices form an adjusted-unit model.
Applying an additional split to quantity would double count. Cash amounts and
security-conversion ratios must use a compatible unit basis; moving to raw-share
accounting is an explicit interpretation decision, not an adapter cleanup.

## Implications for the existing plan

LFB-001 and LFB-011 now have observed portfolio impact. Consider a bounded
equity implementation covering dividend entitlements/payments, cash/security/
mixed acquisition consideration, fractional entitlements, and spin-off child
distributions. Distinguish entitlement, effective, knowledge and payment times;
include the valuation of unsettled claims and received non-member securities.
Adapters supply supported terms and explicit assumptions; ledgr owns account
effects and replay. Incomplete terms retain an honest unsupported outcome.

The roadmap already requires accounting-core consolidation before new
settlement semantics. Limit that prerequisite to consistent production
accounting/replay and preserve independent verification. Compiled-default
promotion, crypto funding, derivatives, multi-currency and tax accounting are
not established requirements of this equity evidence.

Use [Cross-Asset-Accounting-Critical-Events.md](Cross-Asset-Accounting-Critical-Events.md)
as design-space context, rechecking primary sources only for decisions that
become binding. The census does not justify implementing its entire cross-asset
catalogue or another broad data-quality framework. A new release alone cannot
make the historical portfolios complete: supported event terms or explicit
research policies are also required on the data side.
