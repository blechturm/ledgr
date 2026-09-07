# W30 Fixture: Consumer-Specific Missingness

- Witness: `W30`; class: `semantic_oracle`; policy v4.
- Purpose: the same missing feature value reaches two declared consumers. A
  scalar Boolean signal rejects consumption under its guard; a model with
  native missing-value handling may consume it under a fitted, identity-bound
  contract. Neither consumer changes observation, valuation, or execution
  price state. The model consumer is a prototype-only stub.
- Cases: `c1` scalar guard; `c2` model stub.

## Asset And Calendar

`A01` (alias AAA), member, listed, active, not held; cash 100000.00. Venue
XSYN sessions S1 2024-01-02, S2 2024-01-03, S3 2024-01-04, S4 2024-01-05
(opens 14:30:00Z, closes 21:00:00Z).

## Bars (accepted)

| session | open | close |
| --- | --- | --- |
| S1 | 100.00 | 100.00 |
| S2 | 100.00 | 101.00 |
| S3 | missing | missing |
| S4 | 102.00 | 102.00 |

## Feature And Consumers

- Feature `x` = accepted close; at S3 `x` is missing.
- Consumer `scalar_guard_v1`: `signal = x > 100`; guard rejects a missing
  `x`.
- Consumer `model_stub_native_missing_v1`: a prototype-only stub whose
  fitted contract (identity `fit:W15:label_mean_v1`) declares native
  missing-value handling; it may consume the missing value. No ML API is
  authorized.

## Derivations

- S3 observation state `expected_session_absence` for both consumers; the
  asset is unheld, so no valuation mark is required; the S4 open exists, so
  execution price availability at the S4 open is true for both consumers.
- `c1`: usable false, reason `missing_value_scalar_guard`; no signal.
- `c2`: usable true, reason `model_native_missing_handling`; the consumer
  identity is recorded.
- Neither consumer alters observation, valuation, or execution-price state.
