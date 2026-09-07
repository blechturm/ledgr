# W04 Fixture: Reissued Exit Target

- Witness: `W04`; class: `semantic_oracle`; policy v4.
- Purpose: after the W03 no-fill, a new zero target is a fresh attempt with
  its own decision and execution evidence.
- Cases: `c1`. This manifest is self-contained; it restates the W03 facts.

## Assets And Aliases

| stable_id | alias | role |
| --- | --- | --- |
| A01 | AAA | member, held 100 |

## Calendar (venue XSYN, UTC)

| session | date | open_time | close_time | type |
| --- | --- | --- | --- | --- |
| S1 | 2024-01-02 | 2024-01-02T14:30:00Z | 2024-01-02T21:00:00Z | session |
| S2 | 2024-01-03 | 2024-01-03T14:30:00Z | 2024-01-03T21:00:00Z | session |
| S3 | 2024-01-04 | 2024-01-04T14:30:00Z | 2024-01-04T21:00:00Z | session |

## Domains And Ordering

Investment universe `A01`; held-position domain `A01`; target-vector order
`A01`.

## Membership And Lifetime Facts

| kind | asset_id | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- |
| membership inv | A01 | 2023-12-01T00:00:00Z | (open) | 2023-11-30T21:00:00Z |
| listed | A01 | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |

## Trading-Status Facts

| asset_id | source | precedence | status | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- | --- | --- |
| A01 | primary | 1 | active | 2023-01-02T14:30:00Z | 2024-01-03T14:00:00Z | 2023-01-02T14:30:00Z |
| A01 | primary | 1 | halted | 2024-01-03T14:00:00Z | 2024-01-04T14:00:00Z | 2024-01-02T22:00:00Z |
| A01 | primary | 1 | active | 2024-01-04T14:00:00Z | (open) | 2024-01-03T22:00:00Z |

The S3 fill relies on the third row: effective and knowable at the S3 open.

## Bars (accepted; knowledge_time = close_time)

| asset_id | session | open | high | low | close | volume |
| --- | --- | --- | --- | --- | --- | --- |
| A01 | S1 | 100.00 | 100.00 | 100.00 | 100.00 | 1000 |
| A01 | S2 | 100.00 | 100.00 | 100.00 | 100.00 | 0 |
| A01 | S3 | 100.00 | 100.00 | 100.00 | 100.00 | 1000 |

## Opening State

Cash `90000.00`; positions `A01` 100 (one lot at basis 100.00); no carried
strategy state; cost `ledgr_cost_zero()`; no risk chain.

## Strategy Output (scripted)

| pulse | A01 target | attempt |
| --- | --- | --- |
| S1 | 0 | attempt 1 |
| S2 | 0 | attempt 2, a new decision |

## Derivations

- Attempt 1: decision S1 (not restricted; halt knowable at 22:00), execution
  S2 open, no-fill `trading_halted`.
- Attempt 2: decision S2 (restricted because the halt is knowable; zero is
  admissible), execution S3 open, status active, fill sell 100 at 100.00,
  cash `90000 + 10000 = 100000`.
- The two attempts carry distinct attempt identifiers and distinct decision
  and execution timestamps. Attempt 2 is not a continuation of attempt 1.
