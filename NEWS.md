# ledgr 0.1.4

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
