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
- v0.x may make breaking public-API changes when they protect correctness or
  simplify the public model. Every breaking change must be documented in
  `NEWS.md` and, where practical, pass through one deprecation release.
- The default fill model is `next_open` with zero spread and zero fixed
  commission. A target emitted at pulse `t` is filled at the next available bar;
  a target emitted on the final pulse has no next bar and is not filled.

## Config Contract

- `ledgr_config()` is an internal construction helper in v0.1.4. It returns an
  S3 object of class `ledgr_config`, validates the object before returning, and
  has a concise print method for diagnostics.
- `validate_ledgr_config()` is the internal validator name used by execution
  code. It delegates to the same schema checks as the legacy
  `ledgr_validate_config()` helper.
- Exporting direct config construction is deferred until the experiment-store
  API proves that users need it. Public workflows should continue to start with
  `ledgr_backtest()`.

## Snapshot Contract

- Backtests run against sealed snapshots.
- Snapshot hashes cover normalized bars and instruments only; metadata and
  snapshot IDs do not alter artifact hashes.
- Sealing validates referential integrity and OHLC consistency before writing a
  snapshot hash or transitioning to `SEALED`.
- Split snapshot/run DB mode must verify the source snapshot hash from the
  snapshot DB while writing run artifacts to the run DB.
- `ledgr_snapshot_load(db_path, snapshot_id)` may reopen an existing sealed
  snapshot. It must never create, silently overwrite, or silently reseal a
  snapshot. `verify = TRUE` recomputes the snapshot hash before returning.
- `ledgr_snapshot_list()` accepts either a DBI connection or a DuckDB file path.
  Path inputs are opened read-style for discovery and closed before returning.
- `ledgr_data_hash()` is a legacy v0.1.0 helper for direct `bars` table
  workflows. Snapshot-backed workflows should use sealed `snapshot_hash`
  values. Internal run-resume and snapshot-adapter data-subset hashes must use
  explicit internal helpers, not the exported legacy function.

## Persistence Contract

- Runner-owned DuckDB write connections must issue `CHECKPOINT` before
  disconnect/shutdown when a later fresh connection is expected to read the
  same database file.
- Cross-connection read-back is part of the persistence contract: completed
  runs and their `ledger_events`, `features`, and `equity_curve` rows must be
  visible from a newly opened connection.

## Canonical JSON Contract

- Canonical JSON is produced by `canonical_json()`.
- Named vectors and named lists are sorted by key before serialization.
- Serialization uses `jsonlite::toJSON(auto_unbox = TRUE, null = "null",
  na = "null", digits = NA, pretty = FALSE)`.
- Config hashes, strategy-state JSON, snapshot metadata JSON, and ledger
  `meta_json` must use this canonical path when deterministic identity matters.

## Strategy Contract

- Strategy output is a full named numeric target vector, or a list containing
  `targets`.
- Names must exactly match `ctx$universe`; missing, extra, duplicate, unnamed,
  or non-finite targets fail with `ledgr_invalid_strategy_result`.
- Raw signal strings such as `"LONG"` and `"FLAT"` are invalid core outputs.
  `ledgr_signal_strategy()` is an explicit convenience wrapper that maps signals
  to normal targets before validation.
- Functional strategies and R6 strategies use the same target validator.
- Strategy reproducibility is tiered:
  - Tier 1: self-contained `function(ctx, params)` style logic with explicit
    parameters and no unresolved external objects.
  - Tier 2: logic that can be inspected but not fully replayed without external
    context, including R6 strategies unless they provide explicit source and
    parameter metadata.
  - Tier 3: environment-dependent logic whose execution identity cannot be
    recovered from stored metadata.
- v0.1.4 run-identity design must treat `strategy_source_hash`,
  `strategy_params_hash`, and reproducibility tier as part of experiment
  provenance. R6 strategy identity must not be finalized implicitly.

## Context Contract

- Runtime and interactive pulse contexts expose data-frame-compatible
  `ctx$bars` and long-table `ctx$features`.
- Ergonomic helpers such as `ctx$feature()` and `ctx$features_wide` are derived
  views over `ctx$features`; they do not change feature computation semantics.
- Indicators may provide an optional `series_fn(bars, params)` for full-series
  precomputation. The input is one instrument's full bar series in ascending
  time order, and the output must be a numeric vector aligned to `nrow(bars)`.
- Feature warmup `NA_real_` and warmup `NaN` are normalized to `NA_real_`.
  Infinite values, post-warmup `NA`, and post-warmup `NaN` values are invalid.
- Indicator fingerprints include `series_fn` when present. Changing `fn`,
  `series_fn`, parameters, or warmup requirements changes the fingerprint.
- TTR indicators created by `ledgr_ind_ttr()` store TTR function name, TTR
  version, input shape, output column, and forwarded TTR arguments in indicator
  params. Only `params$args` are forwarded to TTR; metadata fields are identity
  fields for fingerprints and diagnostics.
- TTR warmup inference is allowed only for functions listed by
  `ledgr_ttr_warmup_rules()`. Each listed rule must be deterministic from
  explicit arguments alone and verified against direct TTR output in tests.
- TTR input mappings are adapter contracts: `close` maps to `bars$close`, `hl`
  maps to `High/Low`, `hlc` maps to `High/Low/Close`, `ohlc` maps to
  `Open/High/Low/Close`, and `hlcv` maps to `High/Low/Close/Volume`.
- TTR-backed generated IDs use rules-table `id_args` first and then any other
  supplied scalar arguments in sorted order before the optional output suffix.
  Users must provide `id` explicitly when non-scalar TTR arguments would make a
  generated ID ambiguous.
- Fn-only indicators remain supported. In v0.1.4 the fallback uses bounded
  stable windows, not expanding full-history windows.
- Feature precomputation may use a session-scoped cache. Cache entries are keyed
  by sealed `snapshot_hash`, instrument ID, indicator fingerprint,
  feature-engine version, and date range. The cache is never persisted to
  DuckDB and may be cleared with `ledgr_clear_feature_cache()`.
- The session feature cache is a runner precomputation optimization for
  repeated backtests over sealed snapshots. Low-level recovery helpers and
  interactive pulse/indicator tools recompute features because they do not own
  a sealed snapshot hash cache key.
- `ctx$targets()` creates a full named target vector initialized to flat
  positions. It is appropriate when the strategy wants unspecified instruments
  to go flat.
- `ctx$current_targets()` creates a full named target vector initialized from
  current holdings. It is appropriate for hold-unless-signal strategies and
  rebalance throttling.
- Interactive pulse and indicator tools are read-only against persistent ledgr
  tables.

## Result Contract

- Results are derived from ledger and equity tables.
- `print()`, `summary()`, `plot()`, and `tibble::as_tibble()` must not mutate the
  backtest object or persistent run state.
- Metrics are descriptive only and must never feed back into strategy execution.
- `ledgr_state_reconstruct()` is the public reconstruction entry point for a
  run id and DBI connection. It delegates to the shared derived-state rebuild
  path, which verifies snapshot-backed sources before rebuilding derived
  artifacts.
- `ledgr_extract_fills()` and `ledgr_compute_equity_curve()` are user-facing
  read helpers over existing run artifacts; they must not become alternate
  reconstruction implementations.

## Verification Contract

- Full regression tests must pass before release-ticket completion.
- Package check target:
  `R CMD check --no-manual --no-build-vignettes ledgr_0.1.2.tar.gz`.
- Coverage gate target: at least 80% total coverage via `tools/check-coverage.R`.
- CI must run acceptance tests before the full package check and include a
  Windows runner before v0.1.2 release.
