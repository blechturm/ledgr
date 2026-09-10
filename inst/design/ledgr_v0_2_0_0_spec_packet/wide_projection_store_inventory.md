# v0.2.0.0 Wide-Projection Store Inventory

Date: 2026-09-09

Baseline: `321e78d` (`Extract backtest ownership and coordinator stages`)

This inventory was recorded before the first LDG-2684 artifact-shape edit. It
classifies the stores and projection surfaces that could be affected by the
reserved-candidate-name correction. It authorizes no migration beyond the
dispositions below.

## Commands

The inventory used `git ls-files` and a recursive workspace scan for
`.duckdb`, `.db`, `.sqlite`, and `.sqlite3` files. Each discovered DuckDB file
was then opened read-only and its table names were listed.

## Stores

No tracked database file exists. No named maintainer-owned store was supplied
at ticket cut or before this inventory.

The workspace contains five ignored local benchmark run stores under
`dev/bench/results/`:

- `ledgr_regression_ab_20260531T100832Z_current_state_update.duckdb`
- `ledgr_regression_ab_20260531T100925Z_current_state_update.duckdb`
- `ledgr_regression_ab_20260531T100925Z_event_closure_no_state_update.duckdb`
- `ledgr_regression_continuous_20260531T101455Z.duckdb`
- `ledgr_regression_continuous_20_50_20260531T101945Z.duckdb`

All five contain run, snapshot, ledger, feature, state, equity, provenance, and
telemetry tables. None contains a saved-sweep table, including
`sweep_returns`. They are disposable benchmark evidence and require no
migration for LDG-2684.

## Artifact Disposition

- Saved sweep returns remain persisted in long form. Their table schema and
  candidate IDs do not change.
- `ledgr_sweep_returns_wide()` is an in-memory read-time projection. Only a
  candidate column that equals `ts_utc` or begins with the reserved
  `..ledgr_candidate_` prefix changes its displayed column name.
- Long, matrix, data-frame, xts, return-panel, and candidate-extraction
  surfaces keep the original candidate IDs.
- The wide name contains its reverse mapping as lowercase UTF-8 hex. No
  persistent mapping registry or identity field is added.
- No migration is promised for an unnamed artifact or for local files outside
  this recorded inventory.
