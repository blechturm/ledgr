# W06 Fixture: Valuation Horizon Exhausted

- Witness: `W06`; class: `semantic_oracle`; policy v4.
- Purpose: a held former member loses its fresh mark, ages exactly through
  the two-session stale horizon, and stops the candidate at the third missing
  expected session without inventing a delisting. Earlier fills stay in the
  ledger; the two cutoff timestamps are distinct.
- Cases: `c1`.

## Assets And Aliases

| stable_id | alias | role |
| --- | --- | --- |
| A01 | AAA | former member, held 100 |
| A02 | BBB | member |

## Calendar (venue XSYN, UTC)

| session | date | open_time | close_time | type |
| --- | --- | --- | --- | --- |
| S1 | 2024-01-02 | 2024-01-02T14:30:00Z | 2024-01-02T21:00:00Z | session |
| S2 | 2024-01-03 | 2024-01-03T14:30:00Z | 2024-01-03T21:00:00Z | session |
| S3 | 2024-01-04 | 2024-01-04T14:30:00Z | 2024-01-04T21:00:00Z | session |
| S4 | 2024-01-05 | 2024-01-05T14:30:00Z | 2024-01-05T21:00:00Z | session |
| S5 | 2024-01-08 | 2024-01-08T14:30:00Z | 2024-01-08T21:00:00Z | session |

Intended horizon: S5 close. Every listed asset is expected at every session.

## Domains And Ordering

- Investment universe `A02`; held-position domain `A01`.
- Target-vector order `A02|A01`.

## Membership And Lifetime Facts

| kind | asset_id | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- |
| membership inv | A01 | 2023-12-01T00:00:00Z | 2024-01-02T00:00:00Z | 2023-12-29T21:00:00Z |
| membership inv | A02 | 2023-12-01T00:00:00Z | (open) | 2023-11-30T21:00:00Z |
| listed | A01 | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |
| listed | A02 | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |

`A01` remains listed and open-ended throughout. Nothing here asserts a
delisting.

## Trading-Status Facts (source `primary`, precedence 1)

| asset_id | status | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- |
| A01 | active | 2023-01-02T14:30:00Z | (open) | 2023-01-02T14:30:00Z |
| A02 | active | 2023-01-02T14:30:00Z | (open) | 2023-01-02T14:30:00Z |

## Bars (accepted; knowledge_time = close_time)

| asset_id | session | open | high | low | close | volume |
| --- | --- | --- | --- | --- | --- | --- |
| A01 | S1 | 100.00 | 100.00 | 100.00 | 100.00 | 1000 |
| A02 | S1 | 50.00 | 50.00 | 50.00 | 50.00 | 1000 |
| A02 | S2 | 50.00 | 50.00 | 50.00 | 50.00 | 1000 |
| A02 | S3 | 50.00 | 50.00 | 50.00 | 50.00 | 1000 |
| A02 | S4 | 50.00 | 50.00 | 50.00 | 50.00 | 1000 |
| A02 | S5 | 50.00 | 50.00 | 50.00 | 50.00 | 1000 |

`A01` has no bar at S2, S3, S4, or S5. These are missing expected
observations; nothing is filled in.

## Opening State

- Cash `90000.00`; positions `A01` 100 (one lot at basis 100.00).
- Zero cost; no risk chain; valuation policy v4 (stale horizon two expected
  sessions).

## Strategy Output (scripted)

| pulse | A02 | A01 |
| --- | --- | --- |
| S1 | 100 | 100 (constructor default) |
| S2 | 100 | 100 |
| S3 | 100 | 100 |
| S4 | not invoked | not invoked |

## Derivations

- S1: `A01` fresh close 100.00, age 0, value 10000; `A02` target 100 fills at
  the S2 open at 50.00 (`last_executed_event_ts` = 2024-01-03T14:30:00Z);
  cash `90000 - 5000 = 85000`.
- S2: `A01` missing expected session, stale mark 100.00, age 1; equity
  `85000 + 5000 + 10000 = 100000`.
- S3: age 2; equity 100000; this is the last fully valued pulse
  (`achieved_horizon` and `last_fully_valued_metric_ts` = 2024-01-04T21:00:00Z).
- S4: third missing expected session; no permissible mark; the candidate
  stops before any strategy decision, risk pass, or fill proposal at S4.
  `stop_reason` = `valuation_horizon_exhausted`; affected exposure
  `100 * 100 = 10000` at the last mark; intended horizon 2024-01-08T21:00:00Z.
- The A02 fill remains in the ledger. No terminal event is inferred. Prefix
  metrics through S3 are visible but incomplete.

## Identity Expectations

Not applicable.

## Synthetic Assumptions

Flat prices; the missing A01 rows are the only gaps.
