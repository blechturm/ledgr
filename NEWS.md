# ledgr 0.1.2

- Added a data-first `ledgr_backtest(data = bars, ...)` convenience path that creates a sealed snapshot and then runs the canonical engine.
- Added indicator registry, built-in indicators, adapters, pulse development tools, basic metrics, fill extraction, equity curves, and plotting.
- Strengthened strategy and indicator fingerprints so mutable registry state cannot silently change deterministic replays.
- Exported and documented the v0.1.2 public API surface.

# ledgr 0.1.1

- Added snapshot provenance workflow: create, import (CSV), list/info, hash, and seal snapshots.
- Runner can source data from a SEALED snapshot and fails loud on tampering (hash mismatch).

# ledgr 0.1.0

- Initial deterministic backtest core spine (schema, config/data hashing, features, strategy contract, fill model, ledger writer, derived state reconstruction, runner, acceptance tests).
- Strategy state persistence/restore for resume-safe strategy state.
- Equity curve reconstruction emits one row per pulse timestamp.
- Added public API functions `ledgr_db_init()` and `ledgr_state_reconstruct()`.
