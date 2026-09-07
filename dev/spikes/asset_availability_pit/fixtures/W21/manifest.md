# W21 Fixture: Dense Reconstruction Parity

- Witness: `W21`; class: `representation_discriminating`; policy v4 (dense
  control; no ragged semantics are exercised).
- Purpose: the compact dense control set covers buys, sells, nonzero costs,
  target risk, carried opening state, FIFO lot accounting, realized and
  unrealized P&L, and final-pulse no-fill handling. The instrumented fork
  and the package fold must agree on every value below. Same-version
  identity stays byte-identical; new-version identity is reported
  separately.
- Cases: `c1`. Identity rows compare the fork against `source:package_fold`,
  the package run of this same fixture under the same package version.

## Assets And Aliases

| stable_id | alias |
| --- | --- |
| A01 | AAA |
| A02 | BBB |

## Calendar (venue XSYN, UTC)

| session | date | open_time | close_time |
| --- | --- | --- | --- |
| S1 | 2024-01-02 | 2024-01-02T14:30:00Z | 2024-01-02T21:00:00Z |
| S2 | 2024-01-03 | 2024-01-03T14:30:00Z | 2024-01-03T21:00:00Z |
| S3 | 2024-01-04 | 2024-01-04T14:30:00Z | 2024-01-04T21:00:00Z |
| S4 | 2024-01-05 | 2024-01-05T14:30:00Z | 2024-01-05T21:00:00Z |

S4 is the final bar of the snapshot.

## Domain And Ordering

Dense static universe declared as `A02, A01` (user order, not sorted).
Target-vector and event order `A02|A01`.

## Lifetime And Status Facts

| kind | asset_id | source | precedence | value | effective_from | effective_to | knowledge_time |
| --- | --- | --- | --- | --- | --- | --- | --- |
| lifetime | A01 | | | listed | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |
| lifetime | A02 | | | listed | 2023-01-02T00:00:00Z | (open) | 2023-01-02T21:00:00Z |
| status | A01 | primary | 1 | active | 2023-01-02T14:30:00Z | (open) | 2023-01-02T14:30:00Z |
| status | A02 | primary | 1 | active | 2023-01-02T14:30:00Z | (open) | 2023-01-02T14:30:00Z |

Every fill below relies on these rows. The dense package path does not
consult status facts; the fork must reach the same fills with them present.

## Bars (accepted)

| asset_id | session | open | high | low | close | volume |
| --- | --- | --- | --- | --- | --- | --- |
| A01 | S1 | 100.00 | 100.00 | 100.00 | 100.00 | 1000 |
| A01 | S2 | 100.00 | 102.00 | 100.00 | 102.00 | 1000 |
| A01 | S3 | 102.00 | 104.00 | 102.00 | 104.00 | 1000 |
| A01 | S4 | 104.00 | 106.00 | 104.00 | 106.00 | 1000 |
| A02 | S1 | 50.00 | 50.00 | 50.00 | 50.00 | 1000 |
| A02 | S2 | 50.00 | 50.00 | 49.00 | 49.00 | 1000 |
| A02 | S3 | 49.00 | 49.00 | 48.00 | 48.00 | 1000 |
| A02 | S4 | 48.00 | 52.00 | 48.00 | 52.00 | 1000 |

## Opening State (carried)

Cash `50000.00`; `A01` 100 in one lot at basis 100.00 opened
2023-12-15T14:30:00Z. Opening lot cost basis 10000.00.

## Policies

- Cost `ledgr_cost_fixed_fee(1)`: fee 1.00 per fill; buy cash delta
  `-(qty * price + fee)`; sell cash delta `qty * price - fee`
  (`R/fold-engine.R` fill application).
- Lot accounting: FIFO; lot basis is the fill price; every fill's fee
  reduces realized P&L by the fee (`R/lot-accounting.R`,
  `realized_delta = realized_close - fee`).
- Risk `ledgr_risk_max_weight(0.55)`: cap per asset
  `0.55 * equity / close`, applied to nonzero targets as
  `sign * min(abs(target), cap)`; equity is cash plus positions at the
  decision close.
- Timing next open; final bar produces no fill and warns
  `LEDGR_LAST_BAR_NO_FILL`.

## Strategy Output (scripted, order A02 then A01)

| pulse | A02 | A01 |
| --- | --- | --- |
| S1 | 800 | 50 |
| S2 | 660 | 0 |
| S3 | 660 | 0 |
| S4 | 0 | 0 |

## Derivations

- S1 close: equity `50000 + 100 * 100 = 60000`; cap A02
  `0.55 * 60000 / 50 = 660` so 800 reduces to 660; cap A01 330 so 50 passes.
- S2 open, event order A02 then A01. Fill 1: buy 660 A02 at 50.00, fee
  1.00, cash delta `-33001`, cash 16999, realized delta `0 - 1 = -1`, new
  lot A02 660 at 50.00. Fill 2: sell 50 A01 at 100.00, fee 1.00, cash delta
  `+4999`, cash 21998, FIFO closes 50 of the 100-lot at basis 100.00,
  realized delta `(100 - 100) * 50 - 1 = -1`, remaining lot A01 50 at
  100.00. Cumulative realized `-2`.
- S2 close: equity `21998 + 660 * 49 + 50 * 102 = 59438`; cap A02
  `0.55 * 59438 / 49 = 667.16` so 660 passes; A01 target 0.
- S3 open. Fill 3: sell 50 A01 at 102.00, fee 1.00, cash delta `+5099`,
  cash 27097, realized delta `(102 - 100) * 50 - 1 = 99`, A01 lots empty.
  Cumulative realized `97`; fees total `3`.
- S3 close: equity `27097 + 660 * 48 = 58777`; cap A02
  `0.55 * 58777 / 48 = 673.49` so 660 passes; no intents.
- S4 (final bar): target A02 0 has no next bar; no fill; warning
  `LEDGR_LAST_BAR_NO_FILL`; equity `27097 + 660 * 52 = 61417`; unrealized
  `(52 - 50) * 660 = 1320` on the A02 lot at basis 50.00.
- Total return `61417 / 60000 - 1 = 0.0236166667`.

## Identity Expectations

`snapshot_hash` and `config_hash` under the same package version are equal
between the fork and the package fold. A new-version identity, if any, is
reported as a separate row and is not asserted equal.
