# W22 Fixture: Unpriced Holding Through Max-Weight Risk

- Witness: `W22`; class: `semantic_oracle`; policy v4.
- Purpose: a held instrument without a decision-time close is valued by the
  separate bounded-stale mark; a chain containing `max_weight` does not
  abort, records the mark source and age, and records a pass-through or
  reduction reason; the same chain keeps the same `risk_chain_hash`. The
  mandated boundary case: a new positive target on an unheld instrument with
  no permissible mark stops with `risk_mark_unavailable`.
- Cases: `c0` fresh-close control; `c1` stale mark with reduction; `c2`
  stale mark with pass-through; `c3` unheld target without a mark.

## Assets And Aliases

| stable_id | alias | role |
| --- | --- | --- |
| A01 | AAA | member, not held |
| A02 | BBB | former member, held 200 |
| A03 | CCC | member, never observed (`c3`) |

## Calendar (venue XSYN, UTC)

| session | date | open_time | close_time |
| --- | --- | --- | --- |
| S1 | 2024-01-02 | 2024-01-02T14:30:00Z | 2024-01-02T21:00:00Z |
| S2 | 2024-01-03 | 2024-01-03T14:30:00Z | 2024-01-03T21:00:00Z |
| S3 | 2024-01-04 | 2024-01-04T14:30:00Z | 2024-01-04T21:00:00Z |

## Domains And Ordering

Members `A01, A03`; held non-member `A02`; target-vector order `A01|A03|A02`.

## Membership And Lifetime Facts

| kind | asset_id | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- |
| membership inv | A01 | 2023-12-01T00:00:00Z | (open) | 2023-11-30T21:00:00Z |
| membership inv | A02 | 2023-12-01T00:00:00Z | 2024-01-02T00:00:00Z | 2023-12-29T21:00:00Z |
| membership inv | A03 | 2023-12-01T00:00:00Z | (open) | 2023-11-30T21:00:00Z |
| listed | A01 | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |
| listed | A02 | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |
| listed | A03 | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |

## Trading-Status Facts

| asset_id | source | precedence | status | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- | --- | --- |
| A01 | primary | 1 | active | 2023-01-02T14:30:00Z | (open) | 2023-01-02T14:30:00Z |
| A02 | primary | 1 | active | 2023-01-02T14:30:00Z | (open) | 2023-01-02T14:30:00Z |
| A03 | primary | 1 | active | 2023-01-02T14:30:00Z | (open) | 2023-01-02T14:30:00Z |

The `c0` and `c1` fills at the S3 open rely on the `A02` row.

## Bars (accepted; knowledge_time = close_time)

| asset_id | session | open | close | cases |
| --- | --- | --- | --- | --- |
| A01 | S1, S2, S3 | 100.00 | 100.00 | all |
| A02 | S1 | 50.00 | 50.00 | all |
| A02 | S2 | 50.00 | 50.00 | `c0` only (absent in `c1`, `c2`, `c3`) |
| A02 | S3 | 50.00 | 50.00 | all |
| A03 | none | | | no observation at any session |

## Opening State

Cash `90000.00`; positions `A02` 200 (one lot at basis 50.00). Equity at
the S2 decision `90000 + 200 * 50 = 100000` in every case (fresh close in
`c0`, stale mark in `c1` to `c3`).

## Policies

| case | risk chain |
| --- | --- |
| c0 | `ledgr_risk_max_weight(0.05)` |
| c1 | `ledgr_risk_max_weight(0.05)` |
| c2 | `ledgr_risk_max_weight(0.5)` |
| c3 | `ledgr_risk_max_weight(0.5)` |

Zero cost; valuation v3 (stale horizon two expected sessions).

## Strategy Output (scripted, S2 decision)

| case | A01 | A03 | A02 |
| --- | --- | --- | --- |
| c0 | 0 | 0 | 200 (constructor default) |
| c1 | 0 | 0 | 200 |
| c2 | 0 | 0 | 200 |
| c3 | 0 | 100 (new positive target) | 200 |

## Derivations

- `c0`: A02 fresh close 50.00 (age 0); cap `0.05 * 100000 / 50 = 100`;
  post-risk 100 with `max_weight_reduction`; closure accepts (same sign,
  smaller); intent sell 100 at the S3 open at 50.00; cash 95000. Its
  `risk_chain_hash` and valuation-evidence identity are captured as the
  baselines for `c1` and `c2`.
- `c1`: A02 S2 row missing; stale mark 50.00 age 1; `max_weight` uses the
  mark; cap 100; post-risk 100 with `stale_mark_reduction`; fill at the S3
  open (bar present, active); cash 95000. `risk_chain_hash` equal to `c0`
  (same chain and arguments); valuation evidence identity differs.
- `c2`: cap `0.5 * 100000 / 50 = 1000`; post-risk 200 with
  `stale_mark_pass_through`; no intent. `risk_chain_hash` differs from `c0`
  because the argument differs.
- `c3`: A03 is unheld with a new positive target 100 and no permissible mark
  of any kind; `max_weight` requires a mark; the candidate stops before fill
  proposal or state mutation with `risk_mark_unavailable`, recording asset
  `A03`, target 100, and risk step `max_weight`. This is not the
  held-position stale-mark rule and not `valuation_horizon_exhausted`.
