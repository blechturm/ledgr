# W12 Fixture: Historically Knowable Broader Estimation Population

- Witness: `W12`; class: `semantic_oracle`; policy v4.
- Purpose: the investment universe is narrower than a broader estimation
  population that was knowable at fit time; using the broader population is
  permitted and its identity is recorded.
- Cases: `c0` default population (historically knowable investment
  membership); `c1` explicit named override to the broader population.

## Assets And Aliases

| stable_id | alias | role |
| --- | --- | --- |
| A01 | AAA | investment member |
| A02 | BBB | investment member |
| A03 | CCC | listed, not a member; in the broader population |

## Calendar (venue XSYN, UTC)

| session | date | close_time |
| --- | --- | --- |
| S1 | 2024-01-02 | 2024-01-02T21:00:00Z |
| S2 | 2024-01-03 | 2024-01-03T21:00:00Z |
| S3 | 2024-01-04 | 2024-01-04T21:00:00Z |

## Domains

- Investment universe `A01, A02` (membership `inv`, effective
  2023-12-01T00:00:00Z open-ended, knowledge 2023-11-30T21:00:00Z).
- Estimation population `c0`: `est_pop_members` = investment membership at
  the fit cutoff = `A01|A02`.
- Estimation population `c1`: `est_pop_broad_v1` = every asset listed with
  an accepted observation on or before the cutoff = `A01|A02|A03`. `A03`
  was listed 2023-01-02T00:00:00Z (knowledge 2023-01-02T21:00:00Z) and its
  observations are accepted at their closes, so the population is fully
  knowable at the cutoff.
- No positions; the witness is about fitting, not execution.

## Bars (accepted closes; knowledge_time = close_time)

| asset_id | S1 close | S2 close | S3 close |
| --- | --- | --- | --- |
| A01 | 100.00 | 100.00 | 100.00 |
| A02 | 50.00 | 50.00 | 50.00 |
| A03 | 20.00 | 20.00 | 20.00 |

## Fitted Transform

- Recipe `center_v1`: `x_centered = close - mean(close over population and
  sessions S1 to S2)`.
- Fit cutoff (information cutoff) S2 close 2024-01-03T21:00:00Z.
- Fit RNG identity `fixed:20240103` (the mean needs no randomness; the
  identity is recorded because the artifact contract requires it).
- Label maturity: not applicable (unsupervised).

## Derivations

- `c0` mean `(100 + 100 + 50 + 50) / 4 = 75`.
- `c1` mean `(100 + 100 + 50 + 50 + 20 + 20) / 6 = 340 / 6 = 56.6666666667`.
- Transformed A01 value at S3: `c0` `100 - 75 = 25`; `c1`
  `100 - 56.6666666667 = 43.3333333333`.
- Both fits are causal: their populations and inputs were knowable at the
  cutoff. The population identity differs, so the fitted-artifact identity
  differs between `c0` and `c1`.

## Identity Expectations

`fitted_artifact_identity` in `c1` is `changed` relative to `c0`.
`snapshot_hash` is `equal` between the cases (same sealed facts).

## Synthetic Assumptions

Flat prices; the centering recipe is a stand-in for any fitted transform.
