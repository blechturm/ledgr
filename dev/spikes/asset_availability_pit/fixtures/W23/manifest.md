# W23 Fixture: Post-Risk Closure On Restricted Holdings

- Witness: `W23`; class: `semantic_oracle`; policy v4.
- Purpose: two restricted holdings exercise the closure rule. A long holding
  of 100 with a hold target is reduced to 80 by `max_weight` and accepted; a
  short holding with a hold target is mapped to zero by `long_only` and
  accepted. Both strategy outputs first satisfy hold-or-zero. The short case
  is an isolated algebraic closure test only.
- Cases: `c1` long; `c2` short.

## Assets And Aliases

| stable_id | alias | role |
| --- | --- | --- |
| A01 | AAA | member, held 100 (`c1`) |
| A02 | BBB | member, held -100 (`c2`, algebraic only) |

## Calendar (venue XSYN, UTC)

| session | date | open_time | close_time |
| --- | --- | --- | --- |
| S1 | 2024-01-02 | 2024-01-02T14:30:00Z | 2024-01-02T21:00:00Z |
| S2 | 2024-01-03 | 2024-01-03T14:30:00Z | 2024-01-03T21:00:00Z |

## Membership And Lifetime Facts

| kind | asset_id | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- |
| membership inv | A01 | 2023-12-01T00:00:00Z | (open) | 2023-11-30T21:00:00Z |
| membership inv | A02 | 2023-12-01T00:00:00Z | (open) | 2023-11-30T21:00:00Z |
| listed | A01 | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |
| listed | A02 | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |

## Trading-Status Facts

| asset_id | source | precedence | status | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- | --- | --- |
| A01 | primary | 1 | active | 2023-01-02T14:30:00Z | 2024-01-02T20:00:00Z | 2023-01-02T14:30:00Z |
| A01 | primary | 1 | halted | 2024-01-02T20:00:00Z | 2024-01-04T14:00:00Z | 2024-01-02T20:00:00Z |
| A02 | primary | 1 | active | 2023-01-02T14:30:00Z | 2024-01-02T20:00:00Z | 2023-01-02T14:30:00Z |
| A02 | primary | 1 | halted | 2024-01-02T20:00:00Z | 2024-01-04T14:00:00Z | 2024-01-02T20:00:00Z |

Both are target-restricted at the S1 decision and halted at the S2 open. No
fill is expected in this witness.

## Bars (accepted; knowledge_time = close_time)

| asset_id | session | open | high | low | close | volume |
| --- | --- | --- | --- | --- | --- | --- |
| A01 | S1 | 100.00 | 100.00 | 100.00 | 100.00 | 500 |
| A01 | S2 | 100.00 | 100.00 | 100.00 | 100.00 | 0 |
| A02 | S1 | 50.00 | 50.00 | 50.00 | 50.00 | 500 |
| A02 | S2 | 50.00 | 50.00 | 50.00 | 50.00 | 0 |

## Opening State

| case | cash | positions | equity at S1 close |
| --- | --- | --- | --- |
| c1 | 90000.00 | A01 100 (lot basis 100.00) | 90000 + 100 * 100 = 100000 |
| c2 | 105000.00 | A02 -100 (short, basis 50.00) | 105000 - 100 * 50 = 100000 |

## Policies

| case | risk chain |
| --- | --- |
| c1 | `ledgr_risk_max_weight(0.08)` |
| c2 | `ledgr_risk_long_only()` |

Zero cost.

## Strategy Output (scripted, S1 decision)

| case | target | admissible set |
| --- | --- | --- |
| c1 | A01 100 (hold) | 100 or 0 |
| c2 | A02 -100 (hold) | -100 or 0 |

## Derivations

- `c1`: cap `0.08 * 100000 / 100 = 80`; post-risk 80; sign unchanged and
  magnitude smaller than the admissible strategy target 100, so post-risk
  validation accepts; intent sell 20 at the S2 open; halted, so no-fill
  `trading_halted`; position stays 100.
- `c2`: `long_only` maps -100 to 0; zero is admissible post-risk; intent
  buy 100 to cover at the S2 open; halted, so no-fill `trading_halted`;
  position stays -100. No short-accounting claim is made.
