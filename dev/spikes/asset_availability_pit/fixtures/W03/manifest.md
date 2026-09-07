# W03 Fixture: One Exit Target Followed By A No-Fill

- Witness: `W03`; class: `semantic_oracle`; policy v4.
- Purpose: a zero target that receives no fill leaves no order behind; a later
  hold target and a later eligible price do not execute the earlier exit.
- Cases: `c1`.

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

- Investment universe: `A01` (member throughout). Held-position domain `A01`.
- Target-vector order `A01`. Estimation universe not used.

## Membership And Lifetime Facts

| kind | asset_id | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- |
| membership inv | A01 | 2023-12-01T00:00:00Z | (open) | 2023-11-30T21:00:00Z |
| listed | A01 | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |

## Trading-Status Facts (source `primary`, precedence 1)

| asset_id | status | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- |
| A01 | active | 2023-01-02T14:30:00Z | 2024-01-03T14:00:00Z | 2023-01-02T14:30:00Z |
| A01 | halted | 2024-01-03T14:00:00Z | 2024-01-04T14:00:00Z | 2024-01-02T22:00:00Z |
| A01 | active | 2024-01-04T14:00:00Z | (open) | 2024-01-03T22:00:00Z |

The halt becomes knowable at 2024-01-02T22:00:00Z, after the S1 decision at
21:00:00Z, so the S1 decision is not target-restricted. It is effective and
knowable at the S2 open. The resumption is effective and knowable at the S3
open.

## Bars (accepted; knowledge_time = close_time)

| asset_id | session | open | high | low | close | volume |
| --- | --- | --- | --- | --- | --- | --- |
| A01 | S1 | 100.00 | 100.00 | 100.00 | 100.00 | 1000 |
| A01 | S2 | 100.00 | 100.00 | 100.00 | 100.00 | 0 |
| A01 | S3 | 100.00 | 100.00 | 100.00 | 100.00 | 1000 |

The S2 bar exists as an accepted record; execution at the S2 open is decided
by the resolved status, not by the bar's presence.

## Opening State

- Cash `90000.00`; positions `A01` 100 (one lot at basis 100.00).
- Carried strategy state: none. Cost `ledgr_cost_zero()`; risk chain none.

## Strategy Output (scripted)

| pulse | A01 target | note |
| --- | --- | --- |
| S1 | 0 | exit request |
| S2 | 100 | hold current quantity; no new exit |

## Derivations

- S1 decision: target 0 is admissible (not restricted at decision time);
  intent sell 100 at the S2 open.
- S2 open: resolved status `halted` (effective 14:00, knowable 22:00 the day
  before) produces a typed no-fill `trading_halted`. Position stays 100; cash
  stays 90000.
- S2 decision: target 100 equals the current quantity; no intent exists. No
  pending order or standing intent is carried from S1.
- S3 open: status active and an open price exists, but nothing executes
  because no intent was produced at the S2 decision. Position 100 at the end.

## Identity Expectations

Not applicable.

## Synthetic Assumptions

Flat prices and zero costs.
