# ledgr Contract Index

This file is a compact index of the contracts that future contributors and
coding agents must preserve. The authoritative narrative remains in
the active versioned spec packet, currently
`inst/design/ledgr_v0_1_7_8_spec_packet/`.

## Execution Contract

- v0.1.7 makes `ledgr_run()` the public single-run API over a
  `ledgr_experiment` object. `ledgr_backtest()` is demoted from the recommended
  public workflow to a lower-level compatibility surface.
- There is still one canonical execution path. Public convenience APIs must
  build canonical config and delegate to the existing runner; they must not
  implement alternate pulse, fill, ledger, feature, or replay semantics.
- Convenience APIs may reduce setup friction, but must not implement alternate
  execution semantics.
- ledgr is a deterministic backtesting core with adapter boundaries to the R
  finance ecosystem. Indicator, data, and visualization packages should plug
  into ledgr through explicit adapters rather than replacing or bypassing the
  canonical execution path.
- The runner owns pulse order, fills, strategy state, ledger events, features,
  and equity output.
- v0.1.7 is an intentional hard public API reset. It explicitly overrides the
  earlier "deprecate where practical" posture for the research workflow because
  carrying both old and new public surfaces into sweep mode would create
  avoidable long-term complexity. Breaking changes must be documented in
  `NEWS.md` and the v0.1.6-to-v0.1.7 migration guide.
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
- Exporting direct config construction remains deferred. v0.1.7 public
  workflows start with `ledgr_experiment()` and run with `ledgr_run()`.

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
- In the v0.1.7 snapshot-first workflow, `ledgr_snapshot_load()` is the normal
  new-session resumption path. After loading a snapshot handle, ordinary
  run-management APIs should use the snapshot object rather than a `db_path`
  argument.
- `ledgr_snapshot_list()` accepts either a DBI connection or a DuckDB file path.
  Path inputs are opened read-style for discovery and closed before returning.
- Explicit custom snapshot IDs are allowed. The generated `snapshot_` pattern is
  a convention for generated IDs, not a ban on durable user names; warn only
  when a user-supplied ID starts with `snapshot_` but is malformed.
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
- Runtime schema creation and validation must be read-only with respect to
  data rows in ledgr tables except for deliberate schema migration or DDL. They
  may inspect DuckDB metadata to verify table shape and constraints, but must
  not prove constraints by writing invalid probe rows into ledgr tables.
  Constraint enforcement belongs in isolated tests with disposable database
  connections.
- DuckDB constraint metadata is an introspection contract. If a runtime
  validator or create-side compatibility check cannot interpret expected
  constraint metadata, it must fail loudly rather than mutate user rows or
  silently recreate durable tables.
- Completed run artifacts are durable when `ledgr_run()` returns. User-facing
  `close(bt)` and `ledgr_snapshot_close(snapshot)` calls are resource-management
  tools for long sessions, explicit opens, and lazy cursors; documentation must
  not frame them as data-loss prevention.
- User-facing metadata mutations such as run labels, archives, and tags promise
  immediate fresh-connection visibility. They must use strict checkpointing or
  an equivalent durable-read guarantee before returning.
- Best-effort checkpointing is reserved for cleanup paths where a secondary
  checkpoint error would mask the primary run or cleanup error. It must not be
  used as the only durability mechanism for public mutating APIs.
- Low-level CSV snapshot workflows must survive close and reopen:
  create/import/seal followed by `ledgr_snapshot_load(verify = TRUE)` must
  preserve hash verification, seal-time metadata, and subsequent `ledgr_run()`
  execution.
- v0.1.7 public experiment-store APIs are snapshot-first. A `db_path` appears
  in normal workflows only at snapshot creation or snapshot loading.
- `ledgr_run_list()` and `ledgr_run_info()` are read-only experiment-store
  discovery APIs. They must tolerate legacy/pre-provenance stores and treat
  missing telemetry as missing/`NA`, not as corruption.
- Completed and failed v0.1.5+ runs persist compact `run_telemetry`:
  `status`, `execution_mode`, elapsed seconds, pulse count, `persist_features`,
  and feature-cache hit/miss counts. Detailed per-component telemetry remains
  session-scoped through `ledgr_backtest_bench()`.
- `ledgr_run_open()` returns a `ledgr_backtest` handle only for completed
  `DONE` runs. Opening a run must not execute strategy code, recompute fills,
  or mutate persistent run artifacts.
- `ledgr_run_label()` and `ledgr_run_archive()` mutate only run metadata.
  They must never rename `run_id`, delete artifacts, or change experiment
  identity hashes. Archive is non-destructive and idempotent.
- Run comparison, run tags, and strategy-source recovery are available. Hard
  delete is not available in v0.1.x and must not be documented as such.

## Canonical JSON Contract

- Canonical JSON is produced by `canonical_json()`.
- Named vectors and named lists are sorted by key before serialization.
- Serialization uses `jsonlite::toJSON(auto_unbox = TRUE, null = "null",
  na = "null", digits = NA, pretty = FALSE)`.
- Config hashes, strategy-state JSON, snapshot metadata JSON, and ledger
  `meta_json` must use this canonical path when deterministic identity matters.
- Feature-map authoring objects are wrappers around existing indicator
  definitions. Equivalent feature maps and plain feature lists must preserve
  feature-related config identity for equivalent indicator definitions unless a
  later contract deliberately changes run identity semantics.

## Strategy Contract

- Strategy output is a full named numeric target vector, a `ledgr_target`, or a
  list containing `targets`.
- Names must exactly match `ctx$universe`; missing, extra, duplicate, unnamed,
  or non-finite targets fail with `ledgr_invalid_strategy_result`.
- Target values are desired instrument quantities after the next fill, not
  portfolio weights, order sizes, or signals. `ledgr_target` is a thin wrapper
  around those same target quantities and is unwrapped before execution.
- Strategy helper pipelines may use `ledgr_signal`, `ledgr_selection`, and
  `ledgr_weights` as intermediate value types, but those objects are invalid
  direct strategy outputs. Helper pipelines must terminate in `ledgr_target` or
  a plain full named numeric target vector.
- v0.1.7.2 helper weights are public authoring helpers only. They do not alter
  the execution contract, and target constructors must reject negative weights
  or leverage until explicit short-selling and leverage semantics are specified.
- The v0.1.7.2 reference helper pipeline is deliberately small:
  `signal_return()` reads already-registered `return_<lookback>` features,
  `select_top_n()` ignores missing signals and breaks ties by instrument ID,
  `weight_equal()` creates long-only equal weights, and `target_rebalance()`
  converts weights into full-universe `ledgr_target` quantities using
  decision-time equity and close prices. These helpers must not auto-register
  indicators, silently normalize weights, or add a second execution path.
- The helper composition contract is
  `signal -> selection -> weights -> target quantities -> existing execution
  path`. Signal, selection, and weight objects are research objects with origin
  metadata; `ledgr_target` is the only helper value type that may unwrap into
  executable target quantities.
- `target_rebalance()` floors share quantities to whole numbers after sizing
  long-only weights from current pulse equity and current close prices. It must
  not silently create fractional share targets.
- Feature maps are authoring UX over the existing feature registry and pulse
  context. They may make feature registration and pulse-time lookup easier, but
  they must not add a second strategy path: strategies still return full named
  numeric target vectors, `ledgr_target`, or `list(targets = ...)`.
- `ledgr_feature_map()` may bundle aliases, indicator objects, and resolved
  feature IDs for registration and lookup. Existing
  `ledgr_experiment(features = list(...))` workflows remain valid.
- Feature-map aliases are readable names for strategy authors. They are not
  roles, selectors, recipes-style preprocessing groups, or execution
  instructions.
- `passed_warmup()` is a guard used inside strategy logic after feature values
  have been read. It is not a helper-pipeline transformation and must not imply
  a second signal/selection/weight/target execution path.
- v0.1.x does not define a supported broker-style short-selling contract.
  Negative target quantities are outside the supported public workflow until
  explicit shorting semantics are specified.
- Raw signal strings such as `"LONG"` and `"FLAT"` are invalid core outputs.
  `ledgr_signal_strategy()` is an explicit convenience wrapper that maps signals
  to normal targets before validation.
- Functional strategies and R6 strategies use the same target validator.
- v0.1.7 public experiment workflows accept only functional strategies with
  signature `function(ctx, params)`. `params` defaults to `list()` and is passed
  as the second argument. `ctx$params` is not part of the public contract.
- Legacy lower-level paths may retain older signatures temporarily only as
  explicit compatibility surfaces; they must not be taught in user-facing
  v0.1.7 workflows.
- Strategy reproducibility is tiered:
  - Tier 1: self-contained `function(ctx, params)` style logic with explicit
    parameters and no unresolved external objects.
  - Tier 2: logic that can be inspected but not fully replayed without external
    context, including package-qualified calls outside the active R
    distribution and resolved non-function closure objects. Tier 2 is allowed,
    but users own package installation, package version parity, and non-ledgr
    environment management.
  - Tier 3: environment-dependent logic whose execution identity cannot be
    recovered from stored metadata.
- Strategy preflight classifies functional strategies before execution. Tier 3
  is a classed error by default in ordinary runs and future sweep mode. A
  single-run override may exist only as an explicit opt-in; Tier 3 must not be
  accepted silently or downgraded to warning-only behavior. v0.1.7.8 does not
  implement a single-run override; if a later explicit override is added,
  forced Tier 3 runs must still record `tier_3` in provenance.
- Base R references are Tier 1-compatible when they are ordinary function calls
  or constants and do not introduce hidden mutable state. This classification is
  based on packages distributed with the active R installation, discovered from
  package metadata such as `Priority: base` or `Priority: recommended`, not from
  a hand-maintained package-name allowlist.
- Package-qualified calls to packages outside the active R distribution, such
  as `pkg::fn()`, and resolved non-function closure objects are
  Tier 2-compatible. Unqualified user helper calls such as `my_helper(ctx)` are
  Tier 3 unless a later dependency-declaration contract records them
  explicitly.
- Ledgr's exported public namespace is Tier 1-compatible because ledgr itself
  is the required execution environment for ledgr experiments. Documented
  strategy helpers such as `signal_return()`, `select_top_n()`,
  `weight_equal()`, `target_rebalance()`, and `passed_warmup()` must not be
  treated as unresolved Tier 3 symbols merely because examples omit the
  `ledgr::` qualifier.
- Static analysis is not a proof of semantic reproducibility. The preflight may
  use `codetools::findGlobals()` or a similar mechanism, but it must document
  limits around dynamic dispatch, `do.call()`, `get()`, `eval()`, dynamically
  constructed strategies, S3/S4/R6 runtime state, `<<-`, and closures that
  mutate captured environments.
- The minimum `ledgr_strategy_preflight` result contract contains `tier`,
  `allowed`, `reason`, `unresolved_symbols`, `package_dependencies`, and
  `notes`, and has class `ledgr_strategy_preflight`. In v0.1.7.8, `allowed` is
  `TRUE` for `tier_1` and `tier_2`, and `FALSE` for `tier_3`.
- Future sweep mode inherits the v0.1.7.8 preflight semantics. Sweep may accept
  Tier 1 and Tier 2 strategies, but Tier 3 strategies must be rejected before
  execution.
- v0.1.5 run provenance stores `strategy_source_hash`,
  `strategy_params_hash`, captured strategy source where available,
  dependency versions, R version, and reproducibility tier. R6 strategies are
  Tier 2 by default unless a future explicit metadata contract upgrades them.
- `strategy_source_hash` is R-version-sensitive and should be compared directly
  only between runs created under the same `R_version`.
- `ledgr_extract_strategy(trust = FALSE)` is inspection-only: it returns stored
  source text and metadata without parsing, evaluating, or executing source.
  `trust = TRUE` verifies the stored source hash before parsing/evaluating the
  source into a function object. Hash verification proves stored-text identity,
  not safety.
- Canonical JSON currently serializes both `NULL` and `NA` as JSON `null`;
  users who need to distinguish those parameter values must encode that
  distinction explicitly.

## Context Contract

- Runtime and interactive pulse contexts expose data-frame-compatible
  `ctx$bars` and long-table `ctx$feature_table`.
- Ergonomic helpers such as `ctx$feature()` and `ctx$features()` are derived
  views over `ctx$feature_table`; they do not change feature computation
  semantics.
- `ctx$flat(default = 0)` constructs a full target vector initialized to a
  scalar quantity. `ctx$hold()` constructs a full target vector initialized to
  current positions. Strategies choose between them based on whether the default
  behavior is flat-unless-signal or hold-unless-signal.
- `ctx$feature(instrument_id, feature_id)` must fail loudly for unknown feature
  IDs, including the requested feature, instrument, and available feature IDs
  (`<none>` if no features are registered). A known feature whose current value
  is warmup `NA` remains a normal `NA` lookup, not an error.
- `ctx$features(instrument_id, feature_map)` is a pulse-scoped bundled view
  over `ctx$feature()`. It must preserve no-lookahead semantics, fail loudly
  for unregistered mapped feature IDs, and return warmup `NA` for known
  features that are not usable yet.
- `passed_warmup()` is a strategy-authoring guard for named numeric vectors
  produced by `ctx$features()`. It is not a helper-pipeline transformation and
  zero-length input must fail loudly rather than returning vacuous success.
- `ledgr_feature_contracts()`, `ledgr_pulse_features()`, and
  `ledgr_pulse_wide()` are read-only inspection views over declared features
  and pulse-known data. They must not precompute unavailable data, mutate
  persistent ledgr tables, or change strategy execution semantics.
- `ledgr_pulse_wide()` uses stable names
  `{instrument_id}__ohlcv_{field}` and
  `{instrument_id}__feature_{feature_id}`. Feature-map aliases may filter or
  order the view but must not replace engine feature IDs in wide column names.
- v0.1.7.4 feature maps do not add a new `ctx$features_wide()` contract; the
  public wide pulse inspection API is `ledgr_pulse_wide()`.
- Strategy evaluation errors are wrapped with pulse context while preserving the
  original condition as the parent. The wrapper must name the run, timestamp,
  instruments, and available feature IDs so users can distinguish strategy
  logic failures from feature ID and warmup behavior.
- Indicators may provide an optional `series_fn(bars, params)` for full-series
  precomputation. The input is one instrument's full bar series in ascending
  time order, and the output must be a numeric vector aligned to `nrow(bars)`.
- Full-series precomputation may return warmup `NA_real_` directly without
  calling `series_fn()` when `nrow(bars) < stable_after`; strategy-visible
  output remains an aligned all-`NA_real_` series for that feature/instrument.
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
- TTR adapter parity tests must cover every listed warmup rule and every
  documented multi-output column. Derived outputs such as MACD `histogram` are
  verified against the documented derivation applied to direct TTR output, not
  against a nonexistent TTR column.
- Supported TTR indicators must handle short samples consistently: validly
  constructed indicators should produce aligned warmup `NA_real_` values rather
  than leaking low-level TTR errors from ordinary feature precomputation.
- TTR input mappings are adapter contracts: `close` maps to `bars$close`, `hl`
  maps to `High/Low`, `hlc` maps to `High/Low/Close`, `ohlc` maps to
  `Open/High/Low/Close`, and `hlcv` maps to `High/Low/Close/Volume`.
- TTR-backed generated IDs use rules-table `id_args` first and then any other
  supplied scalar arguments in sorted order before the optional output suffix.
  Users must provide `id` explicitly when non-scalar TTR arguments would make a
  generated ID ambiguous.
- `ledgr_feature_id()` is a discovery helper over existing `ledgr_indicator`
  IDs. It must not generate aliases, rename indicators, or change fingerprint
  semantics; list input returns IDs in list order.
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
- In v0.1.7 public workflows, `ctx$flat()` creates a full named target vector
  initialized to flat positions. It is appropriate when unspecified instruments
  should go flat.
- In v0.1.7 public workflows, `ctx$hold()` creates a full named target vector
  initialized from current holdings. It is appropriate for hold-unless-signal
  strategies and rebalance throttling.
- `ctx$targets()` and `ctx$current_targets()` are removed from the v0.1.7
  public workflow and should fail loudly with migration guidance once the
  context reset ticket is implemented.
- Interactive pulse and indicator tools are read-only against persistent ledgr
  tables.

## Result Contract

- Results are derived from ledger and equity tables.
- `print()`, `summary()`, `plot()`, and `tibble::as_tibble()` must not mutate the
  backtest object or persistent run state.
- Warmup and zero-trade diagnostics may appear on result-inspection surfaces
  such as `summary(bt)`, but they must not mutate the backtest object,
  persistent run state, result tables, metrics, or run identity.
- Ordinary result-access APIs over durable `ledgr_backtest` handles should use
  per-operation read connections where practical so inspecting results does not
  leave a DuckDB connection open and block a later write in the same session.
- `tibble::as_tibble(bt, what = ...)` supports the v0.1.5 result set:
  `equity`, `fills`, `trades`, and `ledger`.
- `ledgr_results(bt, what = ...)` is the package-prefixed wrapper over that
  same result path. It must delegate to `tibble::as_tibble()` and must not
  duplicate reconstruction logic.
- `ledgr_results(bt, what = ...)` may return a ledgr-owned tibble subclass for
  display. That subclass must remain tibble-compatible, and
  `tibble::as_tibble()` must expose the raw result table.
- `ledgr_results(bt, what = "fills")` returns execution fill rows, including
  opening and closing actions. `ledgr_results(bt, what = "trades")` returns
  closed trade rows only. Public `n_trades` and `win_rate` metrics are computed
  from closed trade rows, so open-only fills do not count as trades until
  quantity is closed.
- Timestamp display options are print-only. `options(ledgr.print_ts_utc =
  "auto")` may compact all-midnight UTC timestamps to dates in ledgr-owned
  print paths, but returned and stored `ts_utc` values remain POSIXct UTC.
- `ledgr_compare_runs()` reads stored completed-run artifacts only. It must not
  rerun strategy code, evaluate recovered source, or mutate the experiment
  store while producing comparison tables.
- `ledgr_compare_runs()` returns raw numeric metric columns for ranking and
  filtering. Percentage formatting is a print-only concern; users must not need
  to parse display strings such as `"+5.2%"` to rank runs.
- `ledgr_run_tag()`, `ledgr_run_untag()`, and `ledgr_run_tags()` manage mutable
  run grouping metadata in `run_tags`. Tags must not alter run identity hashes,
  stored artifacts, comparison semantics, or strategy provenance.
- Metrics are descriptive only and must never feed back into strategy execution.
- `ledgr_state_reconstruct()` is the public reconstruction entry point for a
  run id and DBI connection. It delegates to the shared derived-state rebuild
  path, which verifies snapshot-backed sources before rebuilding derived
  artifacts.
- `ledgr_extract_fills()` and `ledgr_compute_equity_curve()` are user-facing
  read helpers over existing run artifacts; they must not become alternate
  reconstruction implementations.
- Public standard metrics use the equity rows returned by
  `ledgr_results(bt, what = "equity")` and the closed trade rows returned by
  `ledgr_results(bt, what = "trades")`.
- `initial_equity` is the `equity` value in the first public equity row for the
  completed run. Total return is `final_equity / initial_equity - 1`, where
  `final_equity` is the `equity` value in the last public equity row. If no
  equity row exists or `initial_equity` is zero, total return is `NA`.
- Annualized return is the geometric annualized return from the same first and
  last public equity rows: `(final_equity / initial_equity)^(1 / years) - 1`,
  where `years = (n_equity_rows - 1) / bars_per_year`. If fewer than two equity
  rows exist, `bars_per_year` is invalid, or `initial_equity` is zero, the
  metric is `NA`.
- Max drawdown is the maximum peak-to-trough decline in public equity rows:
  `min(equity / cummax(equity) - 1)`.
- Annualized volatility is `sd(period_returns) * sqrt(bars_per_year)`, where
  `period_returns` are adjacent public equity-row returns
  `equity[t] / equity[t - 1] - 1`. If fewer than two period returns exist, the
  metric is `NA`.
- v0.1.7.7 adds the first explicit risk-adjusted metric contract. The standard
  metric set ships `sharpe_ratio` unless an implementation ticket records a
  public deferral and an alternate v0.1.8 sweep-ranking path.
- Sharpe-style metrics are computed from period excess returns:
  `excess_return[t] = equity_return[t] - rf_period_return[t]`. The annualized
  ratio is `mean(excess_return) / sd(excess_return) * sqrt(bars_per_year)`.
  The formula consumes a pulse-aligned per-period risk-free return vector; the
  source of that vector must not change the formula.
- The first v0.1.7.7 risk-free-rate provider is a scalar annual rate expressed
  as a decimal, so `0.02` means two percent per year. The default is `0`.
  Conversion to a per-period return is geometric:
  `(1 + rf_annual)^(1 / bars_per_year) - 1`. Non-finite rates, rates less than
  or equal to `-1`, or invalid `bars_per_year` values make the metric `NA`
  rather than producing misleading values.
- Time-varying risk-free-rate series and real data providers such as FRED,
  Treasury, ECB, or central-bank adapters are deferred. Future providers must
  produce the same pulse-aligned `rf_period_return` vector consumed by the
  v0.1.7.7 formula.
- Risk-adjusted metrics must not silently assume daily bars. They reuse the
  documented `bars_per_year` cadence contract and must either snap known
  cadences, accept an explicit provider value, or fail/defer loudly when
  cadence is unknown.
- Sharpe-style metrics return `NA_real_` for short samples, all-missing return
  inputs, invalid adjacent equity returns, flat equity, and constant-return
  cases. Near-zero excess-return volatility is defined as
  `sd(excess_return) <= .Machine$double.eps`. Infinite Sharpe values must not
  be emitted silently.
- Sortino, Calmar, Omega, information ratio, alpha/beta, benchmark-relative
  metrics, VaR, and tail-risk metrics are deferred until the standard
  risk-metric contract is stable.
- Optional PerformanceAnalytics parity tests are external evidence only. They
  must name the exact PerformanceAnalytics functions, annualization scale, and
  risk-free-rate units used for comparison, and they must not redefine ledgr's
  owned metric formulas or become a runtime dependency.
- `n_trades` is the number of closed trade rows. It is not the number of fill
  rows.
- `win_rate` is the share of closed trade rows with strict `realized_pnl > 0`.
  Breakeven trades are not wins. If no closed trade rows exist, `win_rate` is
  `NA`.
- `avg_trade` is the mean `realized_pnl` across closed trade rows. If no closed
  trade rows exist, `avg_trade` is `NA`.
- `time_in_market` is the share of public equity rows with absolute
  `positions_value > 1e-6`.

## Documentation Contract

- README and narrative vignettes use the base pipe `|>` in canonical examples.
- README and narrative vignettes prefer `filter()` / `between()` over
  `subset()` for applied data preparation examples.
- First-path examples avoid raw `as.POSIXct(..., tz = "UTC")` boilerplate when
  `ledgr_utc()` or an equivalent clearer pattern is available.
- Narrative run-list and comparison examples should demonstrate curated print
  defaults directly. Full-column access belongs in explicit tibble-compatible
  "dig deeper" examples.
- Background and positioning articles such as "Who ledgr is for" and "Why
  ledgr is built in R" live under `vignettes/articles/` for pkgdown. They must
  not be installed vignettes, copied into `inst/doc/`, or mixed into the
  operational vignette set.
- README must document noninteractive installed-documentation discovery for
  `Rscript` and agent workflows, including `vignette(package = "ledgr")` and
  `system.file("doc", package = "ledgr")`.
- Core function-level help pages must point to relevant installed articles with
  both interactive and browser-free lookup paths. The browser-free form is
  `system.file("doc", "<article>.html", package = "ledgr")`.
- Feature-map and pulse-inspection help pages must point to the installed
  articles that teach them: `strategy-development` for strategy authoring and
  `indicators` for indicator contracts and pulse views.
- Package help (`?ledgr` / `?ledgr-package`) must include a compact "Start
  here" spine with `vignette(package = "ledgr")`,
  `system.file("doc", package = "ledgr")`, and direct paths for core installed
  articles such as `strategy-development`, `metrics-and-accounting`, and
  `experiment-store`.
- Indicator concepts must have one installed teaching article, `indicators`,
  covering built-in indicators, TTR-backed indicators, feature IDs, and warmup
  `NA`. `ttr-indicators` must not remain as a parallel installed teaching
  vignette unless the contract explicitly documents why both are needed.
- TTR-specific reference facts, including multi-output column names and
  detailed warmup formulas, belong in function help such as `?ledgr_ind_ttr`
  and `?ledgr_ttr_warmup_rules`.
- Indicator documentation should make the adapter boundary explicit: ledgr owns
  feature contracts and execution semantics, while calculation packages such as
  TTR and future adapters supply indicator computations through normal
  `ledgr_indicator` objects.
- README and package help should describe ledgr as a deterministic backtesting
  core that connects to the R finance ecosystem through adapters. This
  positioning must not claim unshipped adapters or frame ledgr as replacing
  existing finance packages.
- Help pages must not present pkgdown-only background articles as installed
  vignettes.
- Visible vignette code must not depend on hidden setup helpers. Prefer
  exported helpers such as `ledgr_utc()` or show local helpers before first
  visible use.
- Installed documentation must not expose stale retired article paths such as
  `ttr-indicators` after `indicators` is the single installed indicator
  article, unless the contract explicitly documents why both are needed.

## Verification Contract

- Full regression tests must pass before release-ticket completion.
- Package check target:
  `R CMD check --no-manual --no-build-vignettes ledgr_*.tar.gz`.
- Coverage gate target: at least 80% total coverage via `tools/check-coverage.R`.
- CI must run acceptance tests before the full package check and include a
  Windows runner before v0.1.2 release.
- For tickets that touch executable R code, package metadata, vignettes,
  pkgdown, DuckDB persistence, snapshots, file paths, time zones, encodings, or
  other OS-sensitive behavior, a local WSL/Ubuntu gate should run before push.
  At minimum this gate runs package tests and `R CMD check` under Linux; docs
  and pkgdown changes also require a local pkgdown build where practical.
- Release-ticket execution should follow `inst/design/release_ci_playbook.md`.
  Main-branch CI and tag-triggered CI are separate gates; a release tag is not
  valid until the tag workflow is green.
