# W19 Fixture: Incomplete Candidate In Selection

- Witness: `W19`; class: `semantic_oracle`; policy v4.
- Purpose: one of two candidates stops before the intended horizon because
  valuation evidence is insufficient. Its prefix metric is visible but not
  comparable complete-period evidence; horizon, stop reason, affected
  exposure, and eligibility appear beside the successful candidate.
- Cases: `cand_a` completes; `cand_b` stops.

## Assets And Aliases

| stable_id | alias | role |
| --- | --- | --- |
| A01 | AAA | former member held by `cand_b` |
| A02 | BBB | member bought by `cand_a` |

## Calendar (venue XSYN, UTC)

| session | date | open_time | close_time |
| --- | --- | --- | --- |
| S1 | 2024-01-02 | 2024-01-02T14:30:00Z | 2024-01-02T21:00:00Z |
| S2 | 2024-01-03 | 2024-01-03T14:30:00Z | 2024-01-03T21:00:00Z |
| S3 | 2024-01-04 | 2024-01-04T14:30:00Z | 2024-01-04T21:00:00Z |
| S4 | 2024-01-05 | 2024-01-05T14:30:00Z | 2024-01-05T21:00:00Z |
| S5 | 2024-01-08 | 2024-01-08T14:30:00Z | 2024-01-08T21:00:00Z |

Intended horizon for both candidates: S5 close. Selection metric: total
return of equity from the S1 close to the intended horizon.

## Membership And Lifetime Facts

| kind | asset_id | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- |
| membership inv | A01 | 2023-12-01T00:00:00Z | 2024-01-02T00:00:00Z | 2023-12-29T21:00:00Z |
| membership inv | A02 | 2023-12-01T00:00:00Z | (open) | 2023-11-30T21:00:00Z |
| listed | A01 | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |
| listed | A02 | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |

## Trading-Status Facts

| asset_id | source | precedence | status | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- | --- | --- |
| A01 | primary | 1 | active | 2023-01-02T14:30:00Z | (open) | 2023-01-02T14:30:00Z |
| A02 | primary | 1 | active | 2023-01-02T14:30:00Z | (open) | 2023-01-02T14:30:00Z |

The `cand_a` fill at the S2 open relies on the `A02` row.

## Bars (accepted; knowledge_time = close_time)

| asset_id | S1 | S2 | S3 | S4 | S5 |
| --- | --- | --- | --- | --- | --- |
| A02 open/close | 50/50 | 50/50 | 52/52 | 54/54 | 55/55 |
| A01 open/close | 100/100 | 110/110 | missing | missing | missing |

## Candidates

| candidate | opening cash | opening positions | scripted targets |
| --- | --- | --- | --- |
| cand_a | 100000.00 | none | S1: A02 100; later: hold |
| cand_b | 90000.00 | A01 100 (lot basis 100.00) | hold |

Zero cost; no risk chain; valuation v3.

## Derivations

- `cand_a`: fill 100 `A02` at the S2 open at 50.00; cash 95000; equity S1
  100000, S2 100000, S3 `95000 + 5200 = 100200`, S4 100400, S5 100500;
  total return `100500 / 100000 - 1 = 0.005`; evidence complete; eligible.
- `cand_b`: equity S1 `90000 + 10000 = 100000`; S2 `90000 + 11000 =
  101000` (fresh); S3 age 1, 101000; S4 age 2, 101000; S5 third missing
  expected session: stop `valuation_horizon_exhausted` before strategy;
  achieved horizon S4 close; prefix return `101000 / 100000 - 1 = 0.01`;
  affected exposure 11000; evidence incomplete; not eligible.
- Selection: `cand_a` selected with 0.005; `cand_b` shown beside it as an
  exclusion with its higher but incomplete prefix 0.01. The prefix is not
  compared as complete-period evidence.
