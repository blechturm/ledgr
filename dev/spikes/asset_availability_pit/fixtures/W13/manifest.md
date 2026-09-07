# W13 Fixture: Future-Selected Estimation Population

- Witness: `W13`; class: `semantic_oracle`; policy v4.
- Purpose: the same historical rows as `W12` `c1` are selected using
  knowledge of future index entry; the fit is rejected as non-causal. The
  witness differs from `W12` only in population-construction information.
- Cases: `c1`. This manifest is self-contained; it restates the W12 facts.

## Assets And Aliases

| stable_id | alias | role |
| --- | --- | --- |
| A01 | AAA | investment member |
| A02 | BBB | investment member |
| A03 | CCC | listed; joins the investment universe at S5 |

## Calendar (venue XSYN closes at 21:00:00Z)

| session | date | close_time |
| --- | --- | --- |
| S1 | 2024-01-02 | 2024-01-02T21:00:00Z |
| S2 | 2024-01-03 | 2024-01-03T21:00:00Z |
| S3 | 2024-01-04 | 2024-01-04T21:00:00Z |
| S5 | 2024-01-08 | 2024-01-08T21:00:00Z |
| S9 | 2024-01-12 | 2024-01-12T21:00:00Z |

## Membership Facts (universe `inv`)

| asset_id | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- |
| A01 | 2023-12-01T00:00:00Z | (open) | 2023-11-30T21:00:00Z |
| A02 | 2023-12-01T00:00:00Z | (open) | 2023-11-30T21:00:00Z |
| A03 | 2024-01-08T00:00:00Z | (open) | 2024-01-05T22:00:00Z |

## Lifetime Facts

| asset_id | assertion | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- |
| A01 | listed | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |
| A02 | listed | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |
| A03 | listed | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |

No positions and no execution; trading-status facts are not consulted.

## Bars (accepted closes; knowledge_time = close_time)

| asset_id | S1 close | S2 close | S3 close |
| --- | --- | --- | --- |
| A01 | 100.00 | 100.00 | 100.00 |
| A02 | 50.00 | 50.00 | 50.00 |
| A03 | 20.00 | 20.00 | 20.00 |

## Fitted Transform And Population Rule

- Recipe `center_v1`; fit cutoff S2 close 2024-01-03T21:00:00Z; RNG identity
  `fixed:20240103`.
- Population rule `est_pop_future_union_v1` = every asset that is a member
  of `inv` at any session up to S9 (2024-01-12T21:00:00Z). Evaluating it
  requires the `A03` membership fact, knowable 2024-01-05T22:00:00Z, later
  than the fit cutoff.

## Derivations

- The selected row set is `A01|A02|A03` with the closes above; its mean
  would be 56.6666666667, identical to `W12` `c1`.
- The population construction consulted information knowable only after the
  cutoff, so the fit is rejected with `estimation_population_non_causal`.
  No fitted numeric state is produced in causal mode.

## Identity Expectations

Not applicable; no artifact is produced.
