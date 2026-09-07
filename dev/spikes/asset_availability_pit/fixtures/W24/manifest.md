# W24 Fixture: Held State Across A Fold Boundary

- Witness: `W24`; class: `semantic_oracle`; policy v4.
- Purpose: the closing state of one fork execution contains a former member
  that is still held; the next fork execution opens on an axis of current
  members plus that holding, and opening validation accepts its stable-ID
  quantity, lot, cash, and valuation evidence without requiring membership.
  No walk-forward orchestrator integration is claimed.
- Cases: `c1`.

## Assets And Aliases

| stable_id | alias | role |
| --- | --- | --- |
| A01 | AAA | member in fold 1, held into fold 2 |
| A02 | BBB | member throughout |
| A03 | CCC | member from S3 |

## Calendar (venue XSYN, UTC)

| session | date | open_time | close_time | fold |
| --- | --- | --- | --- | --- |
| S1 | 2024-01-02 | 2024-01-02T14:30:00Z | 2024-01-02T21:00:00Z | 1 |
| S2 | 2024-01-03 | 2024-01-03T14:30:00Z | 2024-01-03T21:00:00Z | 1 |
| S3 | 2024-01-04 | 2024-01-04T14:30:00Z | 2024-01-04T21:00:00Z | 1 (closing pulse) |
| S4 | 2024-01-05 | 2024-01-05T14:30:00Z | 2024-01-05T21:00:00Z | 2 (opening pulse) |

## Membership Facts (universe `inv`)

| asset_id | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- |
| A01 | 2023-12-01T00:00:00Z | 2024-01-04T00:00:00Z | 2024-01-03T22:00:00Z |
| A02 | 2023-12-01T00:00:00Z | (open) | 2023-11-30T21:00:00Z |
| A03 | 2024-01-04T00:00:00Z | (open) | 2024-01-03T22:00:00Z |

## Lifetime Facts

| asset_id | assertion | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- |
| A01 | listed | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |
| A02 | listed | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |
| A03 | listed | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |

## Trading-Status Facts

| asset_id | source | precedence | status | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- | --- | --- |
| A01 | primary | 1 | active | 2023-01-02T14:30:00Z | (open) | 2023-01-02T14:30:00Z |
| A02 | primary | 1 | active | 2023-01-02T14:30:00Z | (open) | 2023-01-02T14:30:00Z |
| A03 | primary | 1 | active | 2023-01-02T14:30:00Z | (open) | 2023-01-02T14:30:00Z |

The fold-1 fill at the S2 open relies on the `A01` row.

## Bars (accepted; knowledge_time = close_time; every session)

| asset_id | open | high | low | close | volume |
| --- | --- | --- | --- | --- | --- |
| A01 | 100.00 | 100.00 | 100.00 | 100.00 | 1000 |
| A02 | 50.00 | 50.00 | 50.00 | 50.00 | 1000 |
| A03 | 20.00 | 20.00 | 20.00 | 20.00 | 1000 |

## Fold 1

Opening cash 100000.00; no positions; universe `A01, A02`. Scripted: S1
target `A01` 100 (fills at the S2 open at 100.00; cash 90000); S2 and S3
hold. Closing state at S3 close: cash 90000; `A01` 100 in one lot at basis
100.00; `A01` mark 100.00 fresh (age 0).

## Fold 2

Opens at S4 with members `A02, A03` and the carried holding `A01`. Opening
axis `A02|A03|A01`. Opening validation must accept the carried state.

## Derivations

- Fold 1 closing: equity `90000 + 100 * 100 = 100000`.
- Fold 2 opening validation checks stable-ID quantity 100, lot basis 100.00,
  cash 90000, and the valuation mark 100.00 age 0; `A01` is not a member and
  membership is not required. Visible domain at S4 `A02|A03|A01`; held
  non-member count 1.
