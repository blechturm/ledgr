# W27 Fixture: History Across Exit And Re-Entry

- Witness: `W27`; class: `semantic_oracle`; policy v4.
- Purpose: a stable asset exits membership and later re-enters. Its
  admissible pre-exit observations stay keyed to the stable ID; rolling
  history follows the declared history policy; asset-scoped strategy state
  is kept while member or held, dropped when neither, and re-initialized on
  re-entry; portfolio-level state is preserved; no positional reuse.
- Cases: `c1` held through the exit; `c2` not held.

## Assets And Aliases

| stable_id | alias | role |
| --- | --- | --- |
| A01 | AAA | exits and re-enters |
| A02 | BBB | member throughout |

## Calendar (venue XSYN closes at 21:00:00Z)

S1 2024-01-02, S2 2024-01-03, S3 2024-01-04, S4 2024-01-05, S5 2024-01-08.

## Membership Facts (universe `inv`)

| assertion_id | asset_id | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- |
| m1 | A01 | 2023-12-01T00:00:00Z | 2024-01-04T00:00:00Z | 2024-01-03T22:00:00Z |
| m2 | A01 | 2024-01-08T00:00:00Z | (open) | 2024-01-05T22:00:00Z |
| m3 | A02 | 2023-12-01T00:00:00Z | (open) | 2023-11-30T21:00:00Z |

Declared member order: S1 to S2 `A01, A02`; S5 `A02, A01`.

Both listed open-ended and active (primary, p1).

## Bars (accepted closes; all sessions present)

| asset_id | S1 | S2 | S3 | S4 | S5 |
| --- | --- | --- | --- | --- | --- |
| A01 | 100.00 | 101.00 | 102.00 | 103.00 | 104.00 |
| A02 | 50.00 | 50.00 | 50.00 | 50.00 | 50.00 |

## Feature

`rm2` = rolling mean of the last two accepted closes keyed by stable ID.

## Strategy State

- At S1 the strategy writes `asset_state["A01"] = 7` (initial value on any
  fresh initialization is 0) and increments a portfolio-level
  `pulse_counter` at every pulse (0 before S1).

## Opening State

`c1`: cash 90000.00, `A01` 100 (lot basis 100.00). `c2`: cash 100000.00,
no positions. Zero cost; no risk chain; hold strategy (no intents).

## Derivations

- `c1`: `A01` is visible at every pulse (member or held); `asset_state`
  entry persists with value 7 through S5; `rm2` at S3 `(101 + 102) / 2 =
  101.5`, S4 102.5, S5 103.5; `pulse_counter` 5 at S5.
- `c2`: `A01` is visible at S1, S2, S5 only; at S3 the entry is removed
  (`asset_state_present` false); at S5 re-entry initializes a new entry
  with value 0, not 7; `rm2` at S5 is still `(103 + 104) / 2 = 103.5`
  because the S4 observation was knowable at its close and passes every
  history rule; positional index of `A01` is 1 at S1 and 2 at S5;
  `pulse_counter` 5 at S5.
