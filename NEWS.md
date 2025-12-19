# ledgr 0.0.0.9000

- Initial v0.1.0 implementation of the deterministic backtest “core spine” (schema, config/data hashing, features, strategy contract, fill model, ledger writer, derived state reconstruction, runner, acceptance tests).
- Added `strategy_state` persistence/restore for resume-safe strategy state.
- Equity curve reconstruction now emits one row per pulse timestamp.
- Added public API functions `ledgr_db_init()` and `ledgr_state_reconstruct()`.
