# Getting Started with ledgr

Full content in v0.1.3.

This vignette outline introduces the data-first backtest workflow, explicit
snapshot workflow, result inspection, and the invariants ledgr preserves during
a run.

## Outline

- Prepare OHLCV bars
- Run `ledgr_backtest(data = ...)`
- Inspect `summary()`, `plot()`, and `as_tibble()`
- Move from implicit snapshots to explicit snapshot management
- Reconstruct state from the ledger
