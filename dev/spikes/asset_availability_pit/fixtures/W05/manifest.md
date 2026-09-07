# W05 Fixture: Unknown Lifetime With A Valid Observation

- Witness: `W05`; class: `semantic_oracle`; policy v4.
- Purpose: incomplete lifetime metadata with a fresh accepted observation and
  an effective active status must neither fabricate a terminal event nor stop
  the candidate.
- Cases: `c1`.

## Assets And Aliases

| stable_id | alias | role |
| --- | --- | --- |
| A02 | BBB | member; lifetime metadata absent |

## Calendar (venue XSYN, UTC)

| session | date | open_time | close_time | type |
| --- | --- | --- | --- | --- |
| S1 | 2024-01-02 | 2024-01-02T14:30:00Z | 2024-01-02T21:00:00Z | session |
| S2 | 2024-01-03 | 2024-01-03T14:30:00Z | 2024-01-03T21:00:00Z | session |

## Domains And Ordering

- Investment universe `A02`; target-vector order `A02`; no holdings.

## Membership Facts

| universe_id | asset_id | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- |
| inv | A02 | 2023-12-01T00:00:00Z | (open) | 2023-11-30T21:00:00Z |

## Lifetime Facts

No row exists for `A02`. Lifetime state is `unknown`. This is a deliberate
absence, not a placeholder.

## Trading-Status Facts (source `primary`, precedence 1)

| asset_id | status | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- |
| A02 | active | 2023-01-02T14:30:00Z | (open) | 2023-01-02T14:30:00Z |

## Bars (accepted; knowledge_time = close_time)

| asset_id | session | open | high | low | close | volume |
| --- | --- | --- | --- | --- | --- | --- |
| A02 | S1 | 50.00 | 50.00 | 50.00 | 50.00 | 1000 |
| A02 | S2 | 50.00 | 50.00 | 50.00 | 50.00 | 1000 |

## Opening State

Cash `100000.00`; no positions; no carried state; zero cost; no risk chain.

## Strategy Output (scripted)

| pulse | A02 target |
| --- | --- |
| S1 | 100 |

## Derivations

- Unknown lifetime restricts nothing and creates no terminal event. The
  observation, status, and execution facts resolve independently.
- S1 decision: fresh close 50.00 (age 0); target 100 accepted; intent buy 100.
- S2 open: active status and open 50.00; fill 100 at 50.00; cash
  `100000 - 5000 = 95000`; equity at S2 close `95000 + 100 * 50 = 100000`.
- No stop reason, no terminal event, evidence complete.
