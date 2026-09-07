# W10 Fixture: Fixed Basket With An Isolated Gap

- Witness: `W10`; class: `semantic_oracle`; policy v4.
- Purpose: a static two-instrument basket handles one classified gap under
  the explicit availability policy without any dynamic membership.
- Cases: `c1` holds through the gap; `c2` buys the other member at the gap
  pulse and executes at the next open.

## Assets And Aliases

| stable_id | alias | role |
| --- | --- | --- |
| A01 | AAA | member, not held |
| A02 | BBB | member, held 100 |

## Calendar (venue XSYN, UTC)

| session | date | open_time | close_time |
| --- | --- | --- | --- |
| S1 | 2024-01-02 | 2024-01-02T14:30:00Z | 2024-01-02T21:00:00Z |
| S2 | 2024-01-03 | 2024-01-03T14:30:00Z | 2024-01-03T21:00:00Z |
| S3 | 2024-01-04 | 2024-01-04T14:30:00Z | 2024-01-04T21:00:00Z |
| S4 | 2024-01-05 | 2024-01-05T14:30:00Z | 2024-01-05T21:00:00Z |

## Domains And Ordering

Static investment universe `A01, A02` (character basket, no membership
rule); target-vector order `A01|A02`.

## Lifetime And Status Facts

| kind | asset_id | value | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- | --- |
| listed | A01 | | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |
| listed | A02 | | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |
| status primary p1 | A01 | active | 2023-01-02T14:30:00Z | (open) | 2023-01-02T14:30:00Z |
| status primary p1 | A02 | active | 2023-01-02T14:30:00Z | (open) | 2023-01-02T14:30:00Z |

## Bars (accepted; knowledge_time = close_time)

| asset_id | session | open | high | low | close | volume |
| --- | --- | --- | --- | --- | --- | --- |
| A01 | S1 | 100.00 | 100.00 | 100.00 | 100.00 | 1000 |
| A01 | S2 | 100.00 | 100.00 | 100.00 | 100.00 | 1000 |
| A01 | S3 | 100.00 | 100.00 | 100.00 | 100.00 | 1000 |
| A01 | S4 | 100.00 | 100.00 | 100.00 | 100.00 | 1000 |
| A02 | S1 | 50.00 | 50.00 | 50.00 | 50.00 | 1000 |
| A02 | S2 | 50.00 | 50.00 | 50.00 | 50.00 | 1000 |
| A02 | S4 | 50.00 | 50.00 | 50.00 | 50.00 | 1000 |

`A02` has no S3 row: one isolated gap in an expected session.

## Opening State

Cash `95000.00`; positions `A02` 100 (one lot at basis 50.00); zero cost;
no risk chain; availability policy `classify_and_ignore` with stale
valuation up to two expected sessions.

## Strategy Output (scripted)

| case | pulse | A01 | A02 |
| --- | --- | --- | --- |
| c1 | S1, S2, S3, S4 | 0 | 100 |
| c2 | S1, S2 | 0 | 100 |
| c2 | S3 | 100 | 100 |
| c2 | S4 | 100 | 100 |

## Derivations

- The pulse axis is the four declared sessions. The gap removes no pulse and
  adds none.
- S3: `A02` observation state `expected_session_absence`; mark is the stale
  S2 close 50.00 with age 1; `A02` is still a member and not
  target-restricted (status active); equity `95000 + 100 * 50 = 100000`.
- S4: `A02` fresh again, age 0.
- `c2`: the S3 decision buys 100 `A01` (fresh close, active); the S4 open
  exists and is eligible; fill at 100.00; cash `95000 - 10000 = 85000`;
  equity at S4 close `85000 + 10000 + 5000 = 100000`.
- No membership rule is inferred or required: membership change count is 0.
