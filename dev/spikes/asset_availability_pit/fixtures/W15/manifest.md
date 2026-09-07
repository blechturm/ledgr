# W15 Fixture: Delayed Label And Later Revision

- Witness: `W15`; class: `semantic_oracle`; policy v4.
- Purpose: a real small supervised fit excludes labels and revisions that
  are not knowable at its information cutoff; perturbing outer-test data
  leaves the fitted numeric state unchanged when fit inputs and RNG are
  fixed; a revision knowable before the cutoff changes the fit.
- Cases: `c1` baseline fit; `c2` outer-test perturbation; `c3` revision
  knowable before the cutoff.

## Asset And Calendar

`A01` (alias AAA), member and listed, status active; venue XSYN closes at
21:00:00Z.

| session | date | close (original) | close (c3 revised) |
| --- | --- | --- | --- |
| S1 | 2024-01-02 | 100.00 | 100.00 |
| S2 | 2024-01-03 | 101.00 | 101.50 |
| S3 | 2024-01-04 | 102.00 | 102.00 |
| S4 | 2024-01-05 | 103.00 | 103.00 |
| S5 | 2024-01-08 | 104.00 | 104.00 |
| S6 | 2024-01-09 | 105.00 (c2: 999.00) | 105.00 |

Closes are accepted at their close times.

## Revision Facts

| asset_id | session | field | old | new | knowledge_time | cases |
| --- | --- | --- | --- | --- | --- | --- |
| A01 | S2 | close | 101.00 | 101.50 | 2024-01-08T21:00:00Z | c1, c2 (after cutoff) |
| A01 | S2 | close | 101.00 | 101.50 | 2024-01-04T22:00:00Z | c3 (before cutoff) |

## Supervised Fit

- Feature `x_t = close_t`; label `y_t = close_{t+2} / close_t - 1`, knowable
  at the close of session `t+2` (label maturity rule: two expected sessions).
- Recipe `label_mean_v1`: fitted state = mean of matured labels.
- Information cutoff (fit boundary) S4 close 2024-01-05T21:00:00Z.
- Fit population `A01`; RNG identity `fixed:20240105`.
- Matured by the cutoff: `y_S1` (knowable S3 close) and `y_S2` (knowable S4
  close). `y_S3` (knowable S5) and `y_S4` (knowable S6) are excluded.

## Derivations

- `c1`: `y_S1 = 102/100 - 1 = 0.02`; `y_S2 = 103/101 - 1 = 0.0198019802`;
  fitted mean `(0.02 + 0.0198019802) / 2 = 0.0199009901`. The revision is
  knowable after the cutoff, so the original 101.00 is used.
- `c2`: only S6 (outer test) changes to 999.00; no fit input changes; fitted
  mean identical to `c1`; fitted-artifact identity equal; dataset identity
  changed.
- `c3`: the revision is knowable at 2024-01-04T22:00:00Z, before the cutoff,
  so `y_S2 = 103/101.5 - 1 = 0.0147783251`; fitted mean
  `(0.02 + 0.0147783251) / 2 = 0.0173891626`; fitted-artifact identity
  changed relative to `c1`.

## Identity Expectations

`c2`: `fitted_artifact_identity` equal to `c1`, `dataset_identity` changed.
`c3`: `fitted_artifact_identity` changed relative to `c1`.
