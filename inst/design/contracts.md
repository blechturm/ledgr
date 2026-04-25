# ledgr Contract Index

This file is a compact index of the contracts that future contributors and
coding agents must preserve. The authoritative narrative remains in
`inst/design/ledgr_v0_1_2_spec_packet/v0_1_2_spec.md`.

## Execution Contract

- There is one canonical execution path: `ledgr_backtest()` builds a canonical
  config and calls `ledgr_run()`, which calls `ledgr_backtest_run()`.
- Convenience APIs may reduce setup friction, but must not implement alternate
  execution semantics.
- The runner owns pulse order, fills, strategy state, ledger events, features,
  and equity output.

## Snapshot Contract

- Backtests run against sealed snapshots.
- Snapshot hashes cover normalized bars and instruments only; metadata and
  snapshot IDs do not alter artifact hashes.
- Sealing validates referential integrity and OHLC consistency before writing a
  snapshot hash or transitioning to `SEALED`.
- Split snapshot/run DB mode must verify the source snapshot hash from the
  snapshot DB while writing run artifacts to the run DB.

## Strategy Contract

- Strategy output is a full named numeric target vector, or a list containing
  `targets`.
- Names must exactly match `ctx$universe`; missing, extra, duplicate, unnamed,
  or non-finite targets fail with `ledgr_invalid_strategy_result`.
- Raw signal strings such as `"LONG"` and `"FLAT"` are invalid core outputs.
  `ledgr_signal_strategy()` is an explicit convenience wrapper that maps signals
  to normal targets before validation.
- Functional strategies and R6 strategies use the same target validator.

## Context Contract

- Runtime and interactive pulse contexts expose data-frame-compatible
  `ctx$bars` and long-table `ctx$features`.
- Ergonomic helpers such as `ctx$feature()` and `ctx$features_wide` are derived
  views over `ctx$features`; they do not change feature computation semantics.
- Interactive pulse and indicator tools are read-only against persistent ledgr
  tables.

## Result Contract

- Results are derived from ledger and equity tables.
- `print()`, `summary()`, `plot()`, and `tibble::as_tibble()` must not mutate the
  backtest object or persistent run state.
- Metrics are descriptive only and must never feed back into strategy execution.

## Verification Contract

- Full regression tests must pass before release-ticket completion.
- Package check target:
  `R CMD check --no-manual --no-build-vignettes ledgr_0.1.2.tar.gz`.
- Coverage gate target: at least 80% total coverage via `tools/check-coverage.R`.
- CI must run acceptance tests before the full package check and include a
  Windows runner before v0.1.2 release.
