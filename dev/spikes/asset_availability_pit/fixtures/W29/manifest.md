# W29 Fixture: Stable Asset And Alias Continuity

- Witness: `W29`; class: `semantic_oracle`; policy v4.
- Purpose: one stable asset changes ticker while its lots, accepted history,
  features, and identity continue; a later different asset reuses the old
  ticker and receives a different stable ID with no inherited state.
- Cases: `c1`.

## Assets, Aliases, And Alias Facts

| stable_id | alias | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- |
| A01 | AAA | 2023-01-02T00:00:00Z | 2024-01-04T00:00:00Z | 2023-01-02T21:00:00Z |
| A01 | AAX | 2024-01-04T00:00:00Z | (open) | 2024-01-03T22:00:00Z |
| A06 | AAA | 2024-01-08T00:00:00Z | (open) | 2024-01-05T22:00:00Z |

## Calendar (venue XSYN closes at 21:00:00Z)

S1 2024-01-02, S2 2024-01-03, S3 2024-01-04, S4 2024-01-05, S5 2024-01-08.

## Membership And Lifetime

- `A01`: member and listed throughout (knowledge 2023-11-30T21:00:00Z and
  2023-01-02T21:00:00Z); status active.
- `A06`: listed 2024-01-08T00:00:00Z (knowledge 2024-01-05T22:00:00Z);
  member from 2024-01-08T00:00:00Z (knowledge 2024-01-05T22:00:00Z); status
  active from 2024-01-08T14:30:00Z (knowledge 2024-01-05T22:00:00Z).

## Bars (accepted closes)

| asset_id | S1 | S2 | S3 | S4 | S5 |
| --- | --- | --- | --- | --- | --- |
| A01 | 100.00 | 101.00 | 102.00 | 103.00 | 104.00 |
| A06 | | | | | 10.00 |

## Opening State And Feature

Cash 90000.00; `A01` 100 in one lot at basis 100.00; feature `rm2` rolling
mean of two closes keyed by stable ID; hold strategy; `asset_state["A01"]`
= 7 written at S1.

## Derivations

- S3: `A01` label changes to `AAX`; stable ID, lot, history, and
  `asset_state` continue; `rm2 = (101 + 102) / 2 = 101.5`; feature identity
  equal to S2 (aliases are labels, not identity inputs).
- S5: `A06` appears under label `AAA` with stable ID `A06`; held 0; zero
  admissible history rows before S5; no `asset_state` entry; `rm2` absent
  (one observation). `A01` `rm2 = (103 + 104) / 2 = 103.5`.
