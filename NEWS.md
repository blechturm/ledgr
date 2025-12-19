# ledgr 0.1.1

- Added snapshot provenance workflow: create, import (CSV), list/info, hash, and seal snapshots.
- Runner can source data from a SEALED snapshot and fails loud on tampering (hash mismatch).

# ledgr 0.1.0

- Initial deterministic backtest core spine (schema, config/data hashing, features, strategy contract, fill model, ledger writer, derived state reconstruction, runner, acceptance tests).
- Strategy state persistence/restore for resume-safe strategy state.
- Equity curve reconstruction emits one row per pulse timestamp.
- Added public API functions `ledgr_db_init()` and `ledgr_state_reconstruct()`.
