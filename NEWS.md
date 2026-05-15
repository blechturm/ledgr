# ledgr 0.1.8.0

- Added sequential `ledgr_sweep()` for lightweight parameter-grid exploration
  over the same private fold core used by `ledgr_run()`, with in-memory sweep
  output rather than per-candidate DuckDB writes.
- Added `ledgr_param_grid()`, `ledgr_precompute_features()`,
  `ledgr_candidate()`, and `ledgr_promote()` support for explicit sweep
  construction, candidate extraction, and committed run promotion.
- Added row-level `execution_seed`, compact row-level provenance, and durable
  `run_promotion_context` records so promoted runs remain traceable to their
  source sweep candidate and selection view.
- Added explicit execution seed support for `ledgr_run()` and deterministic
  sweep candidate seed derivation from the master seed, candidate label, and
  candidate parameters.
- Refactored fold execution internals around a shared execution core, memory
  and persistent output handlers, a reserved future target-risk slot, and a
  private fill-timing/cost-resolution boundary.
- Added parity coverage proving sweep, promotion, and direct run behavior agree
  for deterministic strategies, seeded stochastic strategies, feature-factory
  sweeps, fill timing, standard metrics, and config identity.
- Added the `sweeps` vignette and README workflow section documenting
  train/sweep/evaluate discipline, caller-owned ranking, failure rows, seeds,
  provenance, promotion context, and deferred non-goals.

# ledgr 0.1.7.9

- Added `ledgr_feature_contract_check()` so users can inspect feature warmup
  feasibility before running a strategy, including explicit handling for
  deferred feature factories.
- Improved strategy-author ergonomics around empty selections, feature maps,
  strategy context helpers, custom indicators, and zero-trade/warmup diagnosis.
- Polished public documentation flow, article ordering, snapshot/store examples,
  result-inspection guidance, and release-site hygiene.
- Fixed opening-position lot accounting so cost basis is honored consistently
  across fills, trades, metrics, equity reconstruction, derived state, and run
  comparison output.
- Documented current per-leg `spread_bps` semantics without changing fill-model
  behavior.
- Removed dead live equity-array bookkeeping and routed remaining execution
  engine audit findings to explicit release or roadmap decisions.

# ledgr 0.1.7.8

- Added strategy reproducibility preflight with `ledgr_strategy_preflight()`,
  classifying functional strategies as `tier_1`, `tier_2`, or `tier_3` before
  ordinary `ledgr_run()` execution.
- Integrated Tier 3 enforcement into the existing run path so unresolved
  unqualified helper dependencies stop execution with a classed error before
  run artifacts are written.
- Recorded strategy preflight results in run provenance and exposed the
  reproducibility tier through existing run-info, comparison, and strategy
  extraction surfaces.
- Added public design articles for reproducibility, leakage, and custom
  indicator authoring, including the `trust = FALSE` strategy-extraction
  boundary and the residual risk of custom vectorized `series_fn` code.
- Routed the v0.1.7.7 auditr follow-up findings so reproducibility, leakage,
  provenance, and custom-indicator boundary work shipped in v0.1.7.8 while
  broader strategy-author ergonomics remained deferred to v0.1.7.9.
- Documented the fold-core/output-handler contract that future sweep mode must
  inherit so `ledgr_sweep()` can remove persistence overhead without becoming a
  second execution engine.

# ledgr 0.1.7.7

- Added the first ledgr-owned risk-adjusted standard metric, `sharpe_ratio`,
  computed from adjacent public equity-row excess returns with a scalar annual
  risk-free rate converted geometrically to a per-period return.
- Tightened standard metric return-series handling so invalid adjacent equity
  returns make annualized volatility and Sharpe-style metrics `NA` instead of
  silently dropping structurally invalid return rows.

# ledgr 0.1.7.6

- Completed a DuckDB persistence architecture review covering connection
  ownership, checkpoint placement, transaction boundaries, shutdown behavior,
  and DuckDB metadata assumptions.
- Hardened schema validation boundaries so runtime validators remain read-only
  with respect to ledgr data rows while constraint enforcement is tested in
  isolated disposable databases.
- Added explicit live DML coverage for `runs.status` and `snapshots.status`
  constraints, including valid status values and safe cleanup after expected
  DuckDB constraint failures.
- Added fresh-connection persistence tests proving completed runs, public run
  metadata mutations, and low-level CSV snapshot create/import/seal/load
  workflows are readable after reopen.
- Documented a narrow local WSL/Ubuntu DuckDB gate and preserved branch,
  `main`, and tag-triggered CI as separate release evidence.
- Routed the v0.1.7.5 auditr retrospective into later roadmap milestones so
  v0.1.7.6 stays focused on persistence architecture.

# ledgr 0.1.7.5

- Hardened the TTR adapter with parity tests across every supported
  `ledgr_ttr_warmup_rules()` entry and resolved the MACD warmup boundary with
  direct TTR evidence.
- Added a user-facing warmup diagnostic for zero-trade runs where a registered
  feature never becomes finite because an instrument has too few bars.
- Fixed: schema validation probes now issue an explicit rollback after expected
  constraint violations, preventing DuckDB connection-state contamination on
  Ubuntu under coverage instrumentation.
- Improved result-inspection documentation with a compact closed-trade example
  that distinguishes equity, fills, trades, ledger rows, and summary metrics.
- Added a complete low-level CSV snapshot bridge from create/import/seal
  through verified load, metadata inspection, experiment construction, and
  `ledgr_run()`.
- Strengthened indicator, helper, feature-map, and `ctx$features()`
  discoverability while keeping feature-map aliases distinct from engine
  feature IDs.
- Documented ledgr's adapter posture as a deterministic backtesting core that
  connects to R finance ecosystem packages through explicit adapter boundaries.

# ledgr 0.1.7.4

- Breaking: the raw long feature table on pulse contexts moved from
  `ctx$features` to `ctx$feature_table`; `ctx$features` is now the
  feature-map bundle accessor. This keeps raw inspection data and strategy
  authoring accessors separate.
- Added feature-map authoring UX with `ledgr_feature_map()`,
  `ctx$features()`, and `passed_warmup()` while preserving the existing
  target-vector execution contract and `features = list(...)` registration.
- Added feature-inspection views with `ledgr_feature_contracts()`,
  `ledgr_pulse_features()`, and `ledgr_pulse_wide()` so users can inspect
  contracts, long pulse rows, and stable wide pulse rows.
- Resolved auditr documentation findings around hidden vignette helpers,
  helper-page discovery, feature IDs, warmup diagnosis, TTR-backed indicators,
  leakage examples, and first-path navigation.
- Fixed the low-level CSV snapshot create/import/seal workflow so sealing
  derives missing runnable metadata from imported bars and instruments without
  changing snapshot hash identity.
- Cleaned installed-documentation hygiene, including stale retired
  `ttr-indicators` artifacts, package/help-page article links, pkgdown
  reference entries, and documentation-contract tests.

# ledgr 0.1.7.3

- Correctness hardening: aligned equity-curve state, final positions, and
  summary/comparison metrics against ledger fills, with focused regressions for
  the v0.1.7.2 auditr accounting finding.
- Metric explainability: documented every metric shown by `summary()`,
  `ledgr_compare_runs()`, and related result surfaces, and added independent
  oracle tests that recompute expected values from public result tables.
- Documentation discoverability: made installed articles discoverable
  from package-level and function-level help pages for headless and agent
  workflows.
- Concept documentation: added installed accounting/metrics and
  indicators articles, consolidated TTR-backed and built-in indicator teaching,
  and tighten helper, feature-ID, warmup, and no-trade guidance.

# ledgr 0.1.7.2

- Stabilised comparison metrics and zero-row result schemas: `n_trades` now
  counts closed trade rows consistently across `summary()`,
  `ledgr_compare_runs()`, `ledgr_run_list()`, and `ledgr_results(bt, what =
  "trades")`, while `what = "fills"` continues to expose execution fill rows.
- Improved result-access connection lifecycle: ordinary durable result
  inspection now opens and closes read connections per operation, and `close()`
  is documented as long-session resource management rather than data-safety
  ceremony.
- Added the strategy-helper value type foundation: `ledgr_signal`,
  `ledgr_selection`, `ledgr_weights`, and `ledgr_target`, with `ledgr_target`
  unwrapping through the existing target-vector validator.
- Added the minimal strategy-helper reference layer: `signal_return()`,
  `select_top_n()`, `weight_equal()`, and `target_rebalance()` for long-only
  helper pipelines that still terminate in normal target quantities.
- Improved strategy diagnostics and feature-ID documentation: strategy errors
  now include pulse timestamp, run, instrument, and available-feature context
  while preserving the original error as the parent condition.
- Overhauled the strategy-development article around the ledgr pulse mental
  model, helper functions, feature IDs, warmup behavior, interactive pulse
  debugging, and run comparison.
- Improved documentation discovery and pkgdown positioning: README now shows
  noninteractive installed-vignette lookup paths, background positioning
  articles remain pkgdown-only, and experiment-store docs clarify durable paths,
  persistent snapshot IDs, labels, tags, CSV snapshot creation, and handle
  lifecycle framing.

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
- Included package vignettes in source builds and declared the vignette build
  dependencies so GitHub installs with `build_vignettes = TRUE` expose
  `vignette(package = "ledgr")`.

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
