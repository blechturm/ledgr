# Accounting event field inventory

The census covers every shipped producer of `FILL`, `CASHFLOW` and
`DISPOSITION` rows and every reader found under `R/`. The machine-readable
classification is in `event_field_inventory.csv`.

## Current producers

| Event source | Product seam | Current JSON content |
| --- | --- | --- |
| Fill | `ledgr_fill_event()` | fee and signed deltas already represented by typed inputs |
| Opening position | `ledgr_event_buffer_stage_opening()` | source plus values duplicated by qty and price |
| Corporate-action cash | `post_cash()` | source-fact identity, entitlement inputs, policy IDs, timing and exposure evidence |
| Disposition | `ledgr_disposition_post()` | terminal policy and mark evidence plus duplicated quantity, mark and signed deltas |

## Current consumers

- `accounting-replay.R` and `lot-accounting.R` reconstruct economic state.
- `corporate-action-settlement.R` uses `source_fact_id` to prevent duplicate
  or double-credit posting on resume.
- `corporate-action-results.R` and `terminal-outcomes.R` expose policy,
  valuation and affected-exposure evidence.
- `backtest-fills.R`, `backtest-results.R`, `availability-results.R`,
  `derived-state.R`, `run-finalize.R` and `run-store.R` all read the same
  durable event stream for results, reopening or finalization.

## Demoted JSON fields

These do not need independent durable storage in a typed design:

- fill `fee`, `cash_delta` and `position_delta` duplicate typed primitives or
  exact signed arithmetic; fill `realized_pnl` is currently null;
- opening `opening_position` duplicates `source`, `position_delta` duplicates
  `qty`, `cost_basis` duplicates `price`, and `cash_delta` is zero;
- disposition `quantity` duplicates `qty`, `mark` duplicates `price`,
  `position_after` is zero, and its deltas reconcile from
  `position_before`, `qty` and `price`.

The prototype nevertheless persists `cash_delta` and `position_delta` as
typed working effects. Whether the durable schema derives or stores those
values is an exact-arithmetic decision for the RFC, not this spike.

## What must survive JSON removal

The source discriminator, source-fact identity, policy identities,
entitlement inputs, late-arrival flag, terminal label and match, disposition
choice and basis, mark source/time/age, optional haircut, affected exposure,
position-before and realized-model-PnL remain typed evidence or typed
reconciliation fields. Deleting them would weaken resume safety or a shipped
result surface.
