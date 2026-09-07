# W11 Fixture: Dynamic Membership With Complete Observations

- Witness: `W11`; class: `semantic_oracle`; policy v4.
- Purpose: membership changes while every effective member has complete
  accepted observations; no observation sparsity is inferred from the
  membership dynamics.
- Cases: `c1`.

## Assets And Aliases

| stable_id | alias | role |
| --- | --- | --- |
| A01 | AAA | member throughout |
| A02 | BBB | member S1 to S2, then held non-member |
| A03 | CCC | member from S3 |

## Calendar (venue XSYN, UTC)

| session | date | open_time | close_time |
| --- | --- | --- | --- |
| S1 | 2024-01-02 | 2024-01-02T14:30:00Z | 2024-01-02T21:00:00Z |
| S2 | 2024-01-03 | 2024-01-03T14:30:00Z | 2024-01-03T21:00:00Z |
| S3 | 2024-01-04 | 2024-01-04T14:30:00Z | 2024-01-04T21:00:00Z |
| S4 | 2024-01-05 | 2024-01-05T14:30:00Z | 2024-01-05T21:00:00Z |

## Domains And Ordering

- Membership rule `inv`; declared member order `A01, A02` then `A01, A03`.
- Target-vector order: S1 and S2 `A01|A02`; S3 and S4 `A01|A03|A02`.
- Held-position domain `A02`.

## Membership Facts

| universe_id | asset_id | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- |
| inv | A01 | 2023-12-01T00:00:00Z | (open) | 2023-11-30T21:00:00Z |
| inv | A02 | 2023-12-01T00:00:00Z | 2024-01-04T00:00:00Z | 2024-01-03T22:00:00Z |
| inv | A03 | 2024-01-04T00:00:00Z | (open) | 2024-01-03T22:00:00Z |

## Lifetime Facts

| asset_id | assertion | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- |
| A01 | listed | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |
| A02 | listed | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |
| A03 | listed | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |

## Trading-Status Facts

| asset_id | source | precedence | status | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- | --- | --- |
| A01 | primary | 1 | active | 2023-01-02T14:30:00Z | (open) | 2023-01-02T14:30:00Z |
| A02 | primary | 1 | active | 2023-01-02T14:30:00Z | (open) | 2023-01-02T14:30:00Z |
| A03 | primary | 1 | active | 2023-01-02T14:30:00Z | (open) | 2023-01-02T14:30:00Z |

## Bars (accepted; knowledge_time = close_time; all four sessions)

| asset_id | open | high | low | close | volume |
| --- | --- | --- | --- | --- | --- |
| A01 | 100.00 | 100.00 | 100.00 | 100.00 | 1000 |
| A02 | 50.00 | 50.00 | 50.00 | 50.00 | 1000 |
| A03 | 20.00 | 20.00 | 20.00 | 20.00 | 1000 |

Every asset has a row at every session, including `A03` before its entry.

## Opening State

Cash `95000.00`; positions `A02` 100 (one lot at basis 50.00); zero cost;
no risk chain.

## Strategy Output (scripted)

Hold at every pulse: `A02` 100, others 0. No intents.

## Derivations

- Visible domain S1 and S2 `A01|A02`; S3 and S4 `A01|A03|A02`.
- Every visible asset at every pulse has an accepted observation: expected
  session absence count 0; all marks fresh, age 0.
- At S3 `A02` is a held non-member with constructor-default target 100,
  unrestricted.
- `A03` pre-membership rows at S1 and S2 were knowable at their closes and
  pass calendar, lifetime, classification, and observation rules, so at S3
  they are admissible source history: two admissible rows.
- Equity every pulse `95000 + 100 * 50 = 100000`.
