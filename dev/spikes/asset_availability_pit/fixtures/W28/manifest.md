# W28 Fixture: Calendar And Age Semantics

- Witness: `W28`; class: `semantic_oracle`; policy v4.
- Purpose: on one declared venue calendar, a scheduled closure and a missing
  expected session produce different expectation reasons and valuation
  ages. The expected-session clock does not age a mark on the closure but
  does on the missing session. Multi-venue scheduling is not claimed.
- Cases: `c1`.

## Asset

`A01` (alias AAA), member, listed, active; held 100 (lot basis 100.00);
cash 90000.00; zero cost; no risk chain; hold strategy.

## Calendar (venue XSYN, UTC)

| session | date | open_time | close_time | type |
| --- | --- | --- | --- | --- |
| S1 | 2024-01-02 | 2024-01-02T14:30:00Z | 2024-01-02T21:00:00Z | session |
| S2 | 2024-01-03 | 2024-01-03T14:30:00Z | 2024-01-03T21:00:00Z | session |
| X | 2024-01-04 | | | scheduled closure (declared) |
| S3 | 2024-01-05 | 2024-01-05T14:30:00Z | 2024-01-05T21:00:00Z | session |
| S4 | 2024-01-08 | 2024-01-08T14:30:00Z | 2024-01-08T21:00:00Z | session |

The pulse axis is S1, S2, S3, S4. The closure is not a pulse and no
observation is expected on it.

## Bars (accepted; knowledge_time = close_time)

| asset_id | date | close |
| --- | --- | --- |
| A01 | 2024-01-02 | 100.00 |
| A01 | 2024-01-03 | 101.00 |
| A01 | 2024-01-08 | 103.00 |

No row exists for 2024-01-04 (closure, not expected) or 2024-01-05
(expected session, missing).

## Derivations

- S2: fresh, age 0, mark 101.00; equity `90000 + 10100 = 100100`.
- 2024-01-04: expectation reason `scheduled_closure`; not a pulse; the age
  clock does not advance.
- S3: expectation reason `expected_session_absence`; stale mark 101.00 age
  1; equity 100100.
- S4: fresh, age 0, mark 103.00; equity `90000 + 10300 = 100300`.
