# ledgr v0.1.4 Usability and Architecture Audit

Run timestamp: 20260427_132643
Package version: 0.1.4
Package path: C:/Users/maxth/Documents/GitHub/ledg_usability_audit/audit-lib/ledgr
Data: 8800 Yahoo OHLCV rows for SPY, QQQ, IWM, TLT, GLD from 2018-01-01 to 2024-12-31.

## Coverage

- Real-data paths: `ledgr_snapshot_from_df()`, `ledgr_snapshot_from_csv()`, `ledgr_snapshot_from_yahoo()`, `ledgr_snapshot_load()`, and path-first `ledgr_snapshot_list()`.
- Backtest paths: `ledgr_backtest()` data-first and snapshot-first, `audit_log`, `db_live`, `persist_features = TRUE/FALSE`, metrics, fills, equity, plotting, telemetry, and low-level reconstruction.
- Strategy styles: buy-and-hold, SMA trend following, signal wrapper, volatility breakout, and momentum rotation.
- Indicator paths: built-ins, custom `series_fn`, TTR adapter, CSV adapter, R-function adapter, registry register/get/list/deregister, pulse snapshots, and indicator development.

## Benchmark Summary

                              strategy execution_mode elapsed_sec user_sec
1                             buy_hold      audit_log        8.22     7.72
2                            sma_trend      audit_log        8.23     7.66
3                           rsi_signal      audit_log       10.25     9.61
4                         vol_breakout      audit_log        8.61     8.12
5                    momentum_rotation      audit_log        9.72     9.24
6               sma_trend_cache_repeat      audit_log        8.25     7.82
7                            sma_trend        db_live       33.00    32.77
8 momentum_rotation_no_feature_persist      audit_log        9.19     8.80
  system_sec total_return annualized_return volatility max_drawdown n_trades
1       0.54    0.0874130        0.01410248 0.01754808  -0.03683402        5
2       0.66    0.1145970        0.01829546 0.06320654  -0.09695687       40
3       0.61   -0.0134928       -0.00226754 0.32320588  -0.14558536     1121
4       0.49    0.1702740        0.02662408 0.58021782  -0.37272285      297
5       0.55    0.1187525        0.01892890 0.91564908  -0.30600571      858
6       0.56    0.1145970        0.01829546 0.06320654  -0.09695687       40
7       2.09    0.1145970        0.01829546 0.06320654  -0.09695687       40
8       0.55    0.1187525        0.01892890 0.91564908  -0.30600571      858
   win_rate avg_trade time_in_market
1 0.0000000  0.000000      0.9993373
2 0.1750000 64.275001      0.7852883
3 0.2827832  1.992364      0.7428761
4 0.2121212 23.271374      0.8648111
5 0.2494172  8.955708      0.9403579
6 0.1750000 64.275001      0.7852883
7 0.1750000 64.275001      0.7852883
8 0.2494172  8.955708      0.9403579

## Logged Errors

                      time                                                step
1 2026-04-27T13:28:47+0200       expected error invalid strategy target vector
2 2026-04-27T13:28:47+0200                expected error unsupported TTR input
3 2026-04-27T13:28:48+0200                expected error missing snapshot load
4 2026-04-27T13:28:49+0200 expected error invalid post-warmup indicator values
                                                      class
1 ledgr_invalid_strategy_result/rlang_error/error/condition
2            ledgr_invalid_args/rlang_error/error/condition
3      LEDGR_SNAPSHOT_NOT_FOUND/rlang_error/error/condition
4  ledgr_invalid_feature_output/rlang_error/error/condition
                                                                                                                            message
1 `targets` must be a named numeric target vector with names matching ctx$universe. Names must be unique, non-empty instrument IDs.
2                                TTR::BBands is a known ledgr TTR function but does not support input = "hlc". Use input = "close".
3                                                                                                Snapshot not found: does_not_exist
4                                                                Feature bad_na_after_warmup returned NA outside the warmup period.

## Assessment

- Strength: the package is unusually explicit about deterministic snapshots, next-open fill timing, run ledgers, and derived-state reconstruction. The audit could reuse sealed snapshots and compare execution modes without re-importing data.
- Strength: strategy authoring is compact once the `ctx` object is understood. `ctx$current_targets()` is important for hold-unless-signal strategies; `ctx$targets()` is better for full rebalance strategies.
- Strength: vectorized indicators and the session cache materially reduce repeated feature work in parameter-sweep-like runs. Benchmark rows include feature-cache hit/miss counts.
- UX weakness: key S3 helpers require knowing the right generic namespace, for example `tibble::as_tibble(bt)` rather than a package-prefixed extractor.
- UX weakness: feature IDs are stringly typed. Strategy code must know names such as `ttr_bbands_20_pctb`; a typo fails at runtime inside the strategy.
- UX weakness: benchmark telemetry has coarse/NA fields for some modes and is session-scoped, so persisted runs cannot be profiled after reload.
- Architecture weakness: result discovery and comparison are still file/manual-run oriented. The package design notes say experiment-store APIs are future work, and the audit felt that gap when comparing many strategy runs.
- Performance risk: full ledgers plus persisted per-pulse features are correctness-friendly but can produce many DuckDB writes. For exploratory sweeps, `persist_features = FALSE` and cache reuse are important.
- Peculiarity: metrics are ledger-derived; `win_rate` and `avg_trade` reflect realized fill rows, so open-position profits can show in equity while closed-trade win rate remains zero.

## Concrete Findings

- `audit_log` mode completed the five main strategy runs in roughly 8.2-10.3 seconds each on 8,800 rows, 5 instruments, and 10 indicators.
- `db_live` produced identical SMA trend metrics to `audit_log`, but took 33.0 seconds versus 8.23 seconds for the same strategy, about 4x slower in this workload.
- The first feature-heavy run had 50 cache misses. Subsequent runs had 50 cache hits and 0 misses, confirming the session feature cache is working.
- Cache hits reduced feature precomputation, but total wall time still stayed near 8-10 seconds because the per-pulse loop dominates these small runs.
- `persist_features = FALSE` reduced the momentum run database from roughly 7.35 MB to 2.63 MB, with similar elapsed time. This is useful for exploratory sweeps when persisted features are not needed.
- A first version of the momentum strategy used `returns_20` instead of the actual built-in feature ID `return_20`. The strategy ran as a no-op rather than failing loudly. This is the clearest UX footgun found during strategy authoring.
- The package emits useful classed errors for invalid strategy output, unsupported TTR mappings, missing snapshots, and invalid post-warmup indicator values.
- Snapshot warnings correctly nudged custom snapshot IDs toward the canonical `snapshot_YYYYmmdd_HHMMSS_XXXX` format, but this is noisy in scripted audit workflows where explicit durable names are intentional.

## Artifacts

- Output directory: C:/Users/maxth/Documents/GitHub/ledg_usability_audit/audit_outputs/run_20260427_132643
- `tables/run_metrics.csv`: wall-clock timings and standard metrics.
- `tables/run_benchmarks.csv`: per-component telemetry from `ledgr_backtest_bench()`.
- `logs/errors.csv`: all expected and unexpected errors captured by the harness.
- `data/bars_yahoo_2018_2024.csv`: real Yahoo data used for the main runs.
