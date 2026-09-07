# W07 Fixture: Accepted Terminal Event Without Settlement Support

- Witness: `W07`; class: `semantic_oracle`; policy v4.
- Purpose: an accepted terminal event whose economic settlement the accounting
  sibling cannot represent stops the candidate with a terminal-accounting
  reason that is distinct from unknown lifetime (W05) and from valuation
  exhaustion (W06).
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

Intended horizon: S3 close.

## Domains And Ordering

Investment universe `A01`; held-position domain `A01`; target-vector order
`A01`.

## Membership Facts

| universe_id | asset_id | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- |
| inv | A01 | 2023-12-01T00:00:00Z | (open) | 2023-11-30T21:00:00Z |

## Lifetime Facts

| asset_id | assertion | terminal_type | effective_from | effective_to | knowledge_time | settlement_terms |
| --- | --- | --- | --- | --- | --- | --- |
| A01 | listed | | 2023-01-02T00:00:00Z | 2024-01-04T00:00:00Z | 2023-01-02T21:00:00Z | |
| A01 | delisted | delisting_with_cash_distribution | 2024-01-04T00:00:00Z | (open) | 2024-01-03T22:00:00Z | unknown |

The delisting is an accepted terminal event. Its settlement terms are not
representable by the accounting sibling in this spike.

## Trading-Status Facts (source `primary`, precedence 1)

| asset_id | status | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- |
| A01 | active | 2023-01-02T14:30:00Z | 2024-01-04T00:00:00Z | 2023-01-02T14:30:00Z |
| A01 | delisted | 2024-01-04T00:00:00Z | (open) | 2024-01-03T22:00:00Z |

## Bars (accepted; knowledge_time = close_time)

| asset_id | session | open | high | low | close | volume |
| --- | --- | --- | --- | --- | --- | --- |
| A01 | S1 | 100.00 | 100.00 | 100.00 | 100.00 | 1000 |
| A01 | S2 | 100.00 | 100.00 | 100.00 | 100.00 | 1000 |

No S3 bar exists.

## Opening State

Cash `90000.00`; positions `A01` 100 (one lot at basis 100.00); zero cost;
no risk chain.

## Strategy Output (scripted)

| pulse | A01 |
| --- | --- |
| S1 | 100 |
| S2 | 100 |
| S3 | not invoked |

## Derivations

- S1 and S2: fresh marks, age 0, equity 100000, no intents, no fills.
- The delisting becomes knowable at 2024-01-03T22:00:00Z, after the S2
  decision. At the S3 pulse it is effective and knowable. The terminal event
  is accepted, but the accounting sibling cannot represent its settlement, so
  the candidate stops with `terminal_settlement_unsupported` before any
  strategy, risk, or fill work at S3.
- Achieved horizon S2 close; affected exposure `100 * 100 = 10000` at the S2
  mark; valuation at S2 is fresh (age 0), so this is not
  `valuation_horizon_exhausted`; lifetime is known, so this is not the W05
  unknown-lifetime state.
- No fills executed, so `last_executed_event_ts` is absent.
