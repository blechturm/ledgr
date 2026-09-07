# W26 Fixture: Empty Public Domain And First Entry

- Witness: `W26`; class: `semantic_oracle`; policy v4.
- Purpose: a pulse with no members and no holdings invokes the strategy with
  an empty public domain and accepts a named zero-length numeric target; the
  first historically knowable member appears later without exposing its
  future entry on the empty pulse.
- Cases: `c1`.

## Asset And Calendar

`A01` (alias AAA). Venue XSYN:

| session | date | open_time | close_time |
| --- | --- | --- | --- |
| S1 | 2024-01-02 | 2024-01-02T14:30:00Z | 2024-01-02T21:00:00Z |
| S2 | 2024-01-03 | 2024-01-03T14:30:00Z | 2024-01-03T21:00:00Z |
| S3 | 2024-01-04 | 2024-01-04T14:30:00Z | 2024-01-04T21:00:00Z |

## Membership, Lifetime, And Status Facts

| kind | asset_id | source | precedence | value | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- | --- | --- | --- |
| membership inv | A01 | | | member | 2024-01-03T00:00:00Z | (open) | 2024-01-02T22:00:00Z |
| lifetime | A01 | | | listed | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |
| status | A01 | primary | 1 | active | 2023-01-02T14:30:00Z | (open) | 2023-01-02T14:30:00Z |

No other membership fact exists. The entry becomes knowable after the S1
decision at 21:00:00Z. The S3 fill relies on the status row.

## Bars (accepted; knowledge_time = close_time)

| asset_id | session | open | high | low | close | volume |
| --- | --- | --- | --- | --- | --- | --- |
| A01 | S1 | 100.00 | 100.00 | 100.00 | 100.00 | 1000 |
| A01 | S2 | 100.00 | 100.00 | 100.00 | 100.00 | 1000 |
| A01 | S3 | 100.00 | 100.00 | 100.00 | 100.00 | 1000 |

## Opening State

Cash `100000.00`; no positions; zero cost; no risk chain.

## Strategy Output (scripted)

| pulse | domain | output |
| --- | --- | --- |
| S1 | empty | named zero-length numeric |
| S2 | A01 | A01 100 |

## Derivations

- S1: visible domain empty; the fork still invokes the strategy; the
  zero-length named numeric is accepted; zero target rows; zero fills;
  `A01` is not visible because its entry is not yet knowable.
- S2: `A01` visible; target 100; fill at the S3 open at 100.00; cash 90000.
