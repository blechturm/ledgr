# W01 Fixture: Retained Holding And Full Member Allocation

- Witness: `W01`; class: `semantic_oracle`;
  policy: `asset_availability_initial_policy_v4`.
- Purpose: make the double-allocation outcome of the current dense fold
  visible, then show the approved residual-NAV sizing with exposure
  reservation and delayed reinvestment.
- Cases: `c0` current dense fold, hold plus new allocation, no budget rule;
  `c1` v3 policy with constructor-default hold of the former member; `c2` v3
  policy with an explicit exit of the former member and reinvestment at the
  next pulse.

## Assets And Aliases

| stable_id | alias | role |
| --- | --- | --- |
| A01 | AAA | former member, held 300 |
| A02 | BBB | current member |
| A03 | CCC | current member |

## Calendar (venue XSYN, UTC)

| session | date | open_time | close_time | type |
| --- | --- | --- | --- | --- |
| S1 | 2024-01-02 | 2024-01-02T14:30:00Z | 2024-01-02T21:00:00Z | session |
| S2 | 2024-01-03 | 2024-01-03T14:30:00Z | 2024-01-03T21:00:00Z | session |
| S3 | 2024-01-04 | 2024-01-04T14:30:00Z | 2024-01-04T21:00:00Z | session |

Decision pulses are session closes. Execution opportunities are the next
session opens (`ledgr_timing_next_open()` semantics). Every asset is expected
to observe every session.

## Domains And Ordering

- Investment universe: `c0` dense static list `A01, A02, A03` (the dense fold
  must configure the held asset); `c1` and `c2` members `A02, A03` in that
  declared order.
- Held-position domain: `A01`.
- Estimation universe: not used.
- Target-vector order: `c0` `A01|A02|A03`; `c1` and `c2` `A02|A03|A01`
  (declared members, then held non-members in stable-ID order).
- Feasibility order (`c1`, `c2`): stable-ID order `A01|A02|A03`.

## Membership Facts (`c1`, `c2`)

| universe_id | asset_id | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- |
| inv | A01 | 2023-12-01T00:00:00Z | 2024-01-02T00:00:00Z | 2023-12-29T21:00:00Z |
| inv | A02 | 2023-12-01T00:00:00Z | (open) | 2023-11-30T21:00:00Z |
| inv | A03 | 2023-12-01T00:00:00Z | (open) | 2023-11-30T21:00:00Z |

## Lifetime Facts

| asset_id | assertion | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- |
| A01 | listed | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |
| A02 | listed | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |
| A03 | listed | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |

## Trading-Status Facts (source `primary`, precedence 1)

| asset_id | status | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- |
| A01 | active | 2023-01-02T14:30:00Z | (open) | 2023-01-02T14:30:00Z |
| A02 | active | 2023-01-02T14:30:00Z | (open) | 2023-01-02T14:30:00Z |
| A03 | active | 2023-01-02T14:30:00Z | (open) | 2023-01-02T14:30:00Z |

Every fill expected below relies on these effective active assertions. A bar
alone never implies tradability.

## Bars (accepted; `knowledge_time` = close_time; open record event time = open_time)

| asset_id | session | open | high | low | close | volume |
| --- | --- | --- | --- | --- | --- | --- |
| A01 | S1 | 100.00 | 100.00 | 100.00 | 100.00 | 1000 |
| A01 | S2 | 100.00 | 100.00 | 100.00 | 100.00 | 1000 |
| A01 | S3 | 100.00 | 100.00 | 100.00 | 100.00 | 1000 |
| A02 | S1 | 50.00 | 50.00 | 50.00 | 50.00 | 1000 |
| A02 | S2 | 50.00 | 50.00 | 50.00 | 50.00 | 1000 |
| A02 | S3 | 50.00 | 50.00 | 50.00 | 50.00 | 1000 |
| A03 | S1 | 20.00 | 20.00 | 20.00 | 20.00 | 1000 |
| A03 | S2 | 20.00 | 20.00 | 20.00 | 20.00 | 1000 |
| A03 | S3 | 20.00 | 20.00 | 20.00 | 20.00 | 1000 |

## Opening State (before the S1 decision)

- Cash `70000.00` (finite, non-negative).
- Positions: `A01` 300, one lot of 300 at basis 100.00 opened
  2023-12-15T14:30:00Z.
- Marks at S1 close: `A01` observed close 100.00, age 0, value 30000.00.
- NAV at S1 close: 100000.00. The held former member is 30 percent of NAV.
- Carried strategy state: none.

## Policies

- Cost model `ledgr_cost_zero()`; risk chain none; timing next open.
- `c0`: current package behavior, no affordability rule, sizing from total
  equity with `floor(w * equity / close)`.
- `c1`, `c2`: v3 budget policy; sizing from residual marked NAV after
  reserving the current marked absolute exposure of every held non-member;
  same-pulse netting; `cash_tolerance` 1e-8.

## Strategy Output (scripted per pulse)

| case | pulse | A01 | A02 | A03 | note |
| --- | --- | --- | --- | --- | --- |
| c0 | S1 | 300 (hold) | 1000 | 2500 | weights 0.5/0.5 of total equity 100000 |
| c1 | S1 | 300 (constructor default) | 700 | 1750 | weights 0.5/0.5 of residual NAV 70000 |
| c1 | S2 | 300 | 700 | 1750 | unchanged; reservation persists |
| c2 | S1 | 0 (explicit exit) | 700 | 1750 | sizing base still 70000 |
| c2 | S2 | (not visible; not held) | 1000 | 2500 | weights of residual NAV 100000 |

## Derivations

- `c0`: A02 `floor(0.5 * 100000 / 50) = 1000`; A03
  `floor(0.5 * 100000 / 20) = 2500`; intended gross exposure
  `300*100 + 1000*50 + 2500*20 = 130000`; both buys fill at the S2 open; cash
  `70000 - 50000 - 50000 = -30000`; the current fold applies no affordability
  rule, so the pulse completes with negative cash and gross exposure 130000
  against NAV 100000.
- `c1`: reserved exposure `300 * 100 = 30000`; residual NAV
  `100000 - 30000 = 70000`; A02 `floor(0.5 * 70000 / 50) = 700`; A03
  `floor(0.5 * 70000 / 20) = 1750`; feasibility in stable-ID order credits
  nothing (no sale) then debits `-35000` and `-35000` from 70000, ending at 0,
  both accepted; event order `A02|A03`; cash after 0; actual exposure
  `30000 + 35000 + 35000 = 100000`.
- `c2`: reservation persists at S1 because no accepted fill has yet changed
  the position, so member targets stay 700 and 1750; feasibility credits the
  A01 sale `+30000` first (virtual 100000), then debits `-35000` (65000) and
  `-35000` (30000); event order `A02|A03|A01` gives event cash 35000, 0,
  30000; virtual and recorded final cash both 30000; actual exposure 70000.
  At the S2 decision no non-member is held, residual NAV is 100000, targets
  become 1000 and 2500, and the additional 300 and 750 shares fill at the S3
  open for 15000 each, leaving cash 0. The sale created cash but did not
  expand the S1 targets retroactively.

## Identity Expectations

Not applicable in this witness.

## Synthetic Assumptions

- Flat prices, zero costs, and unit lot structure are chosen for exact
  arithmetic. Weights sum to one by construction.
- The dense baseline `c0` is a control description of the current fold and
  is not a v3 policy outcome.
