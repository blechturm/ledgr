# W02 Fixture: Failed Sale And Successful Replacement Purchase

- Witness: `W02`; class: `semantic_oracle`; policy v4.
- Purpose: state which rule governs a replacement purchase when the intended
  sale does not fill, and prove the exact affordability boundary with
  same-pulse netting, stable-ID funding priority, target-vector event order,
  and reconciliation within `cash_tolerance`.
- Cases: `c0a` production interface with a genuine missing execution bar
  (current coverage rejection); `c0b` complete-data dense scenario (current
  financing and cash behavior, no budget rule); `c1` fork under v3 policy
  with a halted sale and an unaffordable purchase; `c2` mandated exact
  boundary where accepted sale proceeds exactly fund the purchase.
- The reconciliation failure `affordability_reconciliation_failed` cannot be
  produced from valid inputs; it is defined as checker mutation `M5` in
  `../../evidence/checker_mutations/README.md`.

## Assets And Aliases

| stable_id | alias | role |
| --- | --- | --- |
| A01 | AAA | former member, held 300 (old holding to sell) |
| A02 | BBB | member (replacement to buy) |

## Calendar (venue XSYN, UTC)

| session | date | open_time | close_time | type |
| --- | --- | --- | --- | --- |
| S1 | 2024-01-02 | 2024-01-02T14:30:00Z | 2024-01-02T21:00:00Z | session |
| S2 | 2024-01-03 | 2024-01-03T14:30:00Z | 2024-01-03T21:00:00Z | session |

## Domains And Ordering

- `c0a`, `c0b`: dense static universe declared as `A01, A02`; target-vector
  and event order `A01|A02`.
- `c1`, `c2`: member `A02`; held non-member `A01`; target-vector and event
  order `A02|A01`; feasibility order `A01|A02` (stable-ID).

## Membership, Lifetime, And Status Facts

| kind | asset_id | value | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- | --- |
| membership inv | A01 | member | 2023-12-01T00:00:00Z | 2024-01-02T00:00:00Z | 2023-12-29T21:00:00Z |
| membership inv | A02 | member | 2023-12-01T00:00:00Z | (open) | 2023-11-30T21:00:00Z |
| lifetime | A01 | listed | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |
| lifetime | A02 | listed | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |
| status (all cases) | A02 | active | 2023-01-02T14:30:00Z | (open) | 2023-01-02T14:30:00Z |
| status (`c0a`, `c0b`, `c2`) | A01 | active | 2023-01-02T14:30:00Z | (open) | 2023-01-02T14:30:00Z |
| status (`c1`) | A01 | active | 2023-01-02T14:30:00Z | 2024-01-03T14:00:00Z | 2023-01-02T14:30:00Z |
| status (`c1`) | A01 | halted | 2024-01-03T14:00:00Z | 2024-01-04T14:00:00Z | 2024-01-02T22:00:00Z |

Status source `primary`, precedence 1. Every expected fill has an effective
active assertion.

## Bars (accepted; knowledge_time = close_time)

| asset_id | session | open | high | low | close | volume | cases |
| --- | --- | --- | --- | --- | --- | --- | --- |
| A01 | S1 | 100.00 | 100.00 | 100.00 | 100.00 | 1000 | all |
| A01 | S2 | 100.00 | 100.00 | 100.00 | 100.00 | 1000 | `c0b`, `c1`, `c2` (absent in `c0a`) |
| A02 | S1 | 50.00 | 50.00 | 50.00 | 50.00 | 1000 | all |
| A02 | S2 | 50.00 | 50.00 | 50.00 | 50.00 | 1000 | all |

`c0a` deliberately omits the A01 S2 bar so the production coverage gate is
exercised with a genuine missing execution bar.

## Opening State

| case | cash | positions | lots |
| --- | --- | --- | --- |
| c0a | 10000.00 | A01 300 | 300 at basis 100.00 |
| c0b | 10000.00 | A01 300 | 300 at basis 100.00 |
| c1 | 10000.00 | A01 300 | 300 at basis 100.00 |
| c2 | 0.00 | A01 300 | 300 at basis 100.00 |

All opening cash values are finite and non-negative. Zero cost model; no
risk chain; `cash_tolerance` 1e-8.

## Strategy Output (scripted, S1 decision)

| case | A01 | A02 | A02 notional |
| --- | --- | --- | --- |
| c0a | 0 | 500 | 25000 |
| c0b | 0 | 500 | 25000 |
| c1 | 0 | 500 | 25000 |
| c2 | 0 | 600 | 30000 |

## Derivations

- `c0a`: the dense configuration requires every configured instrument to
  observe every pulse. The A01 S2 row is missing, so `ledgr_run()` rejects
  before any pulse with class `LEDGR_SNAPSHOT_COVERAGE_ERROR`. No fill, no
  cash change.
  This records the production rejection; it is not a budget-policy outcome.
- `c0b`: both bars exist. The current fold has no affordability rule. Events
  in declared order: sell A01 300 at 100.00 (`+30000`, cash 40000), buy A02
  500 at 50.00 (`-25000`, cash 15000). Equity at S2 close
  `15000 + 25000 = 40000`.
- `c1`: at the S1 decision the halt is not knowable (22:00 after the 21:00
  decision), so target 0 is admissible and both intents exist. At the S2 open
  the resolved A01 status is `halted`: no-fill `trading_halted`, no virtual
  credit. Feasibility then evaluates the A02 buy: `10000 - 25000 = -15000`
  below negative tolerance, so the purchase is rejected alone with
  `insufficient_cash`. Rejection under the affordability rule governs; no
  financing is assumed. Cash stays 10000; positions unchanged; A01 valued at
  the fresh S2 close 100.00; equity `10000 + 30000 = 40000`.
- `c2`: feasibility in stable-ID order credits the A01 sale
  `+30000` (virtual 30000), then debits the A02 buy `-30000` (virtual
  `0.00`, absolute value not greater than 1e-8, canonical zero, accepted).
  Event application in target-vector order applies the A02 buy first (event
  cash `-30000`, a permitted intermediate negative) then the A01 sale (event
  cash `0.00`). Virtual final 0.00 and recorded final 0.00 reconcile within
  1e-8; the completed pulse is valid because it is not below `-1e-8`.
  Positions after: A01 0, A02 600; equity at S2 close `0 + 600 * 50 = 30000`.

## Identity Expectations

Not applicable.

## Synthetic Assumptions

Flat prices; zero costs; the halt in `c1` is the only status change.
