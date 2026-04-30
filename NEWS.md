# ledgr 0.1.7.1

- Stabilised the installed-package UX after the v0.1.7 experiment-first reset,
  with clearer start-here documentation, modern base-pipe examples, and a
  runnable offline workflow built around `ledgr_demo_bars`.
- Added `ledgr_utc()` as a small UTC timestamp helper for examples and user
  workflows, avoiding repeated `as.POSIXct(..., tz = "UTC")` boilerplate.
- Made `ledgr_demo_bars` and `ledgr_sim_bars()` tibble-friendly for modern R
  examples.
- Added display-only result timestamp printing controls through
  `options(ledgr.print_ts_utc = "auto")`, so all-midnight EOD result tables can
  print compact dates while underlying `ts_utc` values remain POSIXct UTC.
- Verified MACD TTR warmup against direct TTR output for `macd`, `signal`, and
  `histogram` outputs with both `percent = TRUE` and `percent = FALSE`; under
  the tested TTR version, `macd` is first valid at `nSlow`, while `signal` and
  `histogram` are first valid at `nSlow + nSig - 1`.
- Expanded strategy and TTR indicator articles with clearer `ctx`, `params`,
  feature ID, warmup `NA`, and quantity-target sizing guidance.
- Clarified the experiment-store mental model: sealed snapshots freeze market
  data, while indicators, features, runs, labels, tags, comparisons, and
  telemetry are derived artifacts that can be added later.

# ledgr 0.1.7

## Breaking changes

- Began the v0.1.7 experiment-first API reset. The public research workflow now
  centers on `ledgr_experiment()` and `ledgr_run()` rather than `db_path`-first
  calls and direct `ledgr_backtest()` usage.
- The v0.1.7 strategy contract is `function(ctx, params)`. Strategies without
  tunable parameters receive `params = list()`.
- The v0.1.7 context target constructors are `ctx$flat()` and `ctx$hold()`;
  the older `ctx$targets()` and `ctx$current_targets()` helpers now fail with
  migration guidance.

## New features

- Added `ledgr_opening()` for explicit opening cash, positions, and optional
  cost basis.
- Added `ledgr_experiment()` as the central object for the experiment-first
  workflow.
- Added `ledgr_run()` as the public single-run API for `ledgr_experiment`
  objects, including run-time `features = function(params)` evaluation and an
  explicit `seed = NULL` identity field.
- Converted experiment-store APIs to snapshot-first signatures and extended
  `ledgr_snapshot_load()` so a durable file with exactly one sealed snapshot can
  be resumed without retyping the snapshot id.
- Added `ledgr_param_grid()` as a typed, non-executing parameter-grid object
  with stable canonical-JSON labels for future sweep/tune workflows.
- Added curated print methods for `ledgr_run_list()` and
  `ledgr_compare_runs()` while keeping the underlying objects tibble-compatible.
- Added `ledgr_demo_bars` and `ledgr_sim_bars()` as deterministic offline demo
  data for examples and documentation.
- Made durable `ledgr_backtest` handles safer to clean up: explicit `close(bt)`
  checkpoints before disconnecting, and a finalizer safety net attempts one
  auto-checkpoint if a durable handle is garbage-collected without close.
- Rewrote README and vignettes around the v0.1.7 experiment-first workflow and
  added a v0.1.6 to v0.1.7 migration guide.
- Added `ledgr_opening_from_broker()` as a reserved adapter hook. v0.1.7 does
  not ship built-in broker integrations.

# ledgr 0.1.6

- Added `ledgr_compare_runs()` for comparing completed stored runs from a
  durable experiment store without rerunning strategies.
- Added `ledgr_extract_strategy()` for safe strategy-source inspection and
  optional hash-verified recovery from the experiment store.
- Added `ledgr_run_tag()`, `ledgr_run_untag()`, and `ledgr_run_tags()` for
  mutable run grouping metadata that does not change experiment identity.
- Added dedicated experiment-store and strategy-development articles covering
  run management, `ctx`, feature IDs, comparison, and safe source inspection.
- Added `ledgr_feature_id()` and `print.ledgr_indicator()` so strategy authors
  can discover exact built-in and TTR feature IDs before writing
  `ctx$feature()` calls.
- Expanded the TTR indicator article with feature ID examples for built-in
  indicators, RSI, ATR, BBands, and MACD.

# ledgr 0.1.5

- Added the v0.1.5 experiment-store schema foundation, including schema-version
  metadata, additive migration hooks, run provenance and telemetry tables, and
  defensive future-schema checks.
- Added `strategy_params` support for `function(ctx, params)` strategies and
  durable run provenance capture for strategy source hashes, parameter hashes,
  dependency versions, R version, and reproducibility tier.
- Added experiment-store discovery APIs: `ledgr_run_list()`,
  `ledgr_run_info()`, and `ledgr_run_open()` for listing, inspecting, and
  reopening completed runs without recomputation.
- Added `ledgr_run_label()` and `ledgr_run_archive()` for metadata-only run
  management without changing experiment identity or deleting artifacts.
- Added `ledgr_results()` as a package-prefixed wrapper for result tables.
- Made mistyped `ctx$feature()` lookups fail loudly with available feature IDs
  instead of silently returning `NA`, while preserving warmup `NA` behavior for
  known features.
- Persisted compact run telemetry summaries, including execution mode, elapsed
  time, pulse count, feature-cache hit/miss counts, and `persist_features`;
  `print.ledgr_backtest()` and `ledgr_run_info()` now surface execution mode.
- Relaxed snapshot ID diagnostics so explicit durable custom IDs do not warn
  unless they use the generated `snapshot_` prefix in a malformed way.

# ledgr 0.1.4

- Stabilised the research workflow ahead of the experiment-store APIs, with
  durable snapshot reuse, safer strategy helpers, faster indicator
  precomputation, and broader TTR indicator support.
- Added `ledgr_snapshot_load()` for reopening existing sealed snapshots from a
  durable DuckDB file, with optional hash verification.
- Updated `ledgr_snapshot_list()` so it accepts either a DBI connection or a
  DuckDB file path.
- Added `ctx$current_targets()` to runtime and interactive pulse contexts for
  hold-unless-signal strategy patterns.
- Made internal backtest configs an S3 `ledgr_config` object with validation
  and diagnostic printing, while keeping public workflows centered on
  `ledgr_backtest()`.
- Marked `ledgr_data_hash()` as a legacy v0.1.0 helper and moved internal
  run/snapshot-adapter hash call sites to explicitly named internal helpers.
- Added optional vectorized indicator `series_fn` support for full-series
  feature precomputation, including vectorized built-in indicators.
- Added a session-scoped feature cache keyed by snapshot hash, instrument,
  indicator fingerprint, feature-engine version, and date range, with
  `ledgr_clear_feature_cache()` for explicit cleanup.
- Added `ledgr_ind_ttr()` and `ledgr_ttr_warmup_rules()` for low-code TTR
  indicator construction with explicit warmup and fingerprint metadata.
- Expanded low-code TTR support to common close, high/low, HLC, and HLCV
  indicators including WMA, ROC, momentum, CCI, BBands, aroon,
  DonchianChannel, MFI, CMF, and rolling statistic functions.
- Added `ledgr_deregister_indicator()` for cleaning up session-scoped
  indicator registry entries during interactive work and tests.
- Changed fn-only custom indicator fallback from expanding full-history windows
  to bounded stable windows to avoid accidental O(n^2) feature work.
- Clarified v0.x compatibility policy, strategy reproducibility tiers,
  next-open fill semantics, and low-level API lifecycle notes in design and
  reference documentation.

# ledgr 0.1.3

- Reworked the README into a 5-minute installed-package path with runnable
  synthetic data, rendered output, target-vector strategy examples, and an
  explicit determinism trust check.
- Added a getting-started vignette that walks through the research loop:
  in-memory bars, strategy authoring, result inspection, pulse debugging,
  indicators, Yahoo convenience data, CSV snapshots, and durable DuckDB
  artifacts.
- Added human-readable pulse context helpers for strategy code, including
  `ctx$close()`, `ctx$position()`, `ctx$targets()`, and related OHLCV accessors.
- Improved target-vector validation errors so unnamed, non-numeric, missing,
  and extra instrument targets point users to the required contract: a named
  numeric target vector with names matching `ctx$universe`.
- Audited exported reference documentation and examples so public examples run
  offline, use temporary files/databases, guard optional dependencies, and avoid
  network access.
- Added metric definitions to the reference documentation, including the
  closed-trade meaning of win rate and average trade.
- Added local and CI release gates for the README cold-start example,
  acceptance tests, `rcmdcheck`, coverage, and pkgdown site builds.
- Added a GitHub Pages pkgdown deployment workflow for publishing the package
  site after the repository is made public.
- Hardened DuckDB run persistence by checkpointing runner-owned write
  connections before disconnect/shutdown, fixing cross-connection visibility on
  Ubuntu CI.
- Documented the longer-term experiment-store model: DuckDB files as durable
  research artifacts, immutable run IDs, strategy identity, reproducibility
  tiers, and future run discovery/comparison APIs.

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
