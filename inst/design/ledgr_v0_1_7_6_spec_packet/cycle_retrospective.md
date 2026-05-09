# auditr Cycle Retrospective

Source: `C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.7.5`

This is a maintainer-review artifact. It does not create GitHub issues,
does not execute ledgr workflows, and does not decide final defect truth.

## Status

- episodes: 33
- feedback rows: 64
- feedback summary valid: yes
- categorized feedback: valid
- partial retrospective: no

## Feedback Counts

### Type

| type | items |
| --- | --- |
| documentation_gap | 52 |
| ux_friction | 9 |
| unclear_error | 3 |

### Triage

| triage | items |
| --- | --- |
| docs_gap | 55 |
| expected_user_error | 5 |
| unclear | 4 |

### Severity

| severity | items |
| --- | --- |
| low | 61 |
| medium | 2 |
| high | 1 |

## Task Coverage

### Task Titles

| task_title | episodes |
| --- | --- |
| Build a multi-asset rotation strategy using strategy helpers | 1 |
| Build a single-asset SMA crossover strategy | 1 |
| Build a strategy using a mixed built-in and TTR-backed feature map | 1 |
| Build a strategy using feature maps and the mapped accessor | 1 |
| Build a two-asset momentum strategy | 1 |
| Build an RSI mean-reversion strategy | 1 |
| Combine Bollinger Bands and MACD indicators | 1 |
| Compare two helper-pipeline variants with different parameters | 1 |
| Create, import, seal, and run from a CSV snapshot using the low-level path | 1 |
| Diagnose a strategy that runs without error but produces no trades | 1 |
| Discover ctx$features() and passed_warmup() from ?ledgr_feature_map alone | 1 |
| Discover installed articles from function-level help pages | 1 |
| Extract and recover a stored strategy from a completed run | 1 |
| Fetch real market data from Yahoo Finance and compare five strategies | 1 |
| Follow the getting-started vignette | 1 |
| Follow the indicators article end to end | 1 |
| Follow the metrics-and-accounting article and verify metrics by hand | 1 |
| Follow the strategy-development article end to end | 1 |
| Handle warmup periods and missing values in a helper pipeline strategy | 1 |
| Import CSV data, seal it, and run a backtest | 1 |
| Inspect feature contracts and pulse data before running a backtest | 1 |
| Inspect ledger events and handle the unsupported metrics result type | 1 |
| Inspect trades, fills, and summary metrics from a backtest | 1 |
| Interpret ledgr_snapshot_info() metadata columns after sealing | 1 |
| Interpret the warmup diagnostic and distinguish the three warmup-adjacent failure modes | 1 |
| Register all lookback variants before ledgr_run() in a parameter sweep | 1 |
| Run a strategy with only 10 bars of data | 1 |
| Run the README example | 1 |
| Run two variants and compare results | 1 |
| Trigger and interpret strategy helper error messages | 1 |
| Understand the backtest object lifecycle and close() behaviour | 1 |
| Use the strategy helper pipeline from documentation | 1 |
| Verify that raw strategy logic and the helper pipeline produce the same results | 1 |

### Difficulty

| difficulty | episodes |
| --- | --- |
| straightforward | 28 |
| hard | 2 |
| blocked | 1 |
| challenging | 1 |
| easy | 1 |

## Duplicate Candidates

These are deterministic suggestions only. auditr does not merge findings.

| normalized_title | feedback_ids | titles | episode_ids | n |
| --- | --- | --- | --- | --- |

## Documentation Provenance

- feedback rows missing source_docs: 0
- documentation discovery friction rows: 43

### High-Severity Rows Missing Source Context

| episode_id | feedback_id | title | severity |
| --- | --- | --- | --- |

### Repeated Source Docs

| source_doc | items |
| --- | --- |
| LEDGR_DOCS/strategy-development.md | 25 |
| TASK.md | 22 |
| LEDGR_DOCS/indicators.md | 13 |
| LEDGR_DOCS/experiment-store.md | 11 |
| LEDGR_DOCS/metrics-and-accounting.md | 10 |
| ?ledgr_run | 9 |
| ?ledgr_results | 7 |
| LEDGR_DOCS/getting-started.md | 7 |
| ?summary.ledgr_backtest | 6 |
| episode_environment | 5 |
| ?ledgr_compare_runs | 4 |
| ?ledgr_pulse_snapshot | 4 |
| ?signal_return | 4 |
| ?target_rebalance | 4 |
| raw_logs/ledgr_doc_snapshot.md | 4 |
| ?ledgr_feature_id | 3 |
| ?ledgr_feature_map | 3 |
| ?select_top_n | 3 |
| ?close.ledgr_backtest | 2 |
| ?ledgr_backtest | 2 |
| ?ledgr_compute_metrics | 2 |
| ?ledgr_feature_contracts | 2 |
| ?ledgr_ind_rsi | 2 |
| ?ledgr_ind_ttr | 2 |
| ?ledgr_snapshot_from_csv | 2 |
| ?ledgr_snapshot_from_yahoo | 2 |
| ?ledgr_snapshot_import_bars_csv | 2 |
| ?ledgr_snapshot_seal | 2 |
| ?passed_warmup | 2 |
| ?ledgr-package | 1 |
| ?ledgr_db_init | 1 |
| ?ledgr_experiment | 1 |
| ?ledgr_extract_strategy | 1 |
| ?ledgr_ind_sma | 1 |
| ?ledgr_param_grid | 1 |
| ?ledgr_pulse_features | 1 |
| ?ledgr_run_label | 1 |
| ?ledgr_sim_bars | 1 |
| ?ledgr_snapshot_create | 1 |
| ?ledgr_snapshot_info | 1 |
| ?ledgr_weights | 1 |
| ?weight_equal | 1 |
| DOC_DISCOVERY.R | 1 |
| examples/README.md | 1 |
| LEDGR_DOCS/scripts/getting-started.R | 1 |
| raw_logs/next_docs_paths_stdout.txt | 1 |

### Discovery Friction Evidence

| source | episode_id | evidence |
| --- | --- | --- |
| feedback_summary | 2026-05-08_001_cold_start_readme | Installed README-style example is non-executable |
| feedback_summary | 2026-05-08_003_single_asset_sma_crossover | SMA help page is too terse for crossover use |
| feedback_summary | 2026-05-08_005_rsi_mean_reversion | RSI docs emphasize TTR while native RSI helper is only in help |
| feedback_summary | 2026-05-08_005_rsi_mean_reversion | Native RSI help page lacks a complete ledgr strategy example |
| feedback_summary | 2026-05-08_008_snapshot_csv_seal_backtest | High-level CSV snapshot help does not describe sealing semantics |
| feedback_summary | 2026-05-08_014_close_lifecycle | Task-intent map omits close help topic for backtest lifecycle tasks |
| feedback_summary | 2026-05-08_017_parametric_helper_comparison | Temporary R script with UTF-8 BOM failed before help discovery |
| feedback_summary | 2026-05-08_020_metrics_and_accounting_article | Guessed S3 summary help topic name failed |
| feedback_summary | 2026-05-08_022_help_page_discoverability | Core run help pages do not link to getting-started |
| feedback_summary | 2026-05-08_023_feature_map_strategy_authoring | Mapped ctx$features accessor has no standalone help topic |
| feedback_summary | 2026-05-08_028_snapshot_info_metadata_columns | ledgr_snapshot_info help does not enumerate sealed meta_json keys |
| research_report | 2026-05-08_001_cold_start_readme | Preflight observed ledgr `0.1.7.5`, satisfying the required `>= 0.1.7.5`. The package overview help did not include a complete runnable workflow itself; it directed users to `vignette("getting-started", package = "ledgr")`. The installed examples README was non-executable, so I treated `LEDGR_DOCS/getting-started.md` as the README-equivalent first complete example. |
| research_report | 2026-05-08_002_cold_start_getting_started | - Generated the documentation snapshot with `DOC_DISCOVERY.R`; it found the |
| research_report | 2026-05-08_003_single_asset_sma_crossover | 6. `DOC_DISCOVERY.R` via `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-08_004_multi_asset_momentum | 6. `DOC_DISCOVERY.R`, via `ledgr_write_doc_snapshot()` \| 8. Installed help saved with `ledgr_save_help()` for `?ledgr_experiment`, `?ledgr_run`, `?ledgr_results`, `?ledgr_ind_returns`, `?ledgr_feature_id`, `?ledgr_pulse_snapshot`, `?signal_return`, `?select_top_n`, `?weight_equal`, and `?target_rebalance` |
| research_report | 2026-05-08_005_rsi_mean_reversion | - Generated the documentation snapshot with `DOC_DISCOVERY.R`; see `raw_logs/ledgr_doc_snapshot.md`. |
| research_report | 2026-05-08_006_bbands_macd | 5. `DOC_DISCOVERY.R`, via `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-08_007_experiment_store_compare | 5. `DOC_DISCOVERY.R`, via `ledgr_write_doc_snapshot()` \| No shell quoting failures occurred because all non-trivial R code was saved in |
| research_report | 2026-05-08_008_snapshot_csv_seal_backtest | 5. `DOC_DISCOVERY.R` via `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-08_009_edge_case_ten_bars | 5. `DOC_DISCOVERY.R` via `ledgr_write_doc_snapshot()` \| 7. Help topics captured with `ledgr_save_help()`: `?ledgr_experiment`, |
| research_report | 2026-05-08_010_strategy_development_article | 5. `raw_logs/ledgr_doc_snapshot.md`, generated by `source("DOC_DISCOVERY.R"); ledgr_write_doc_snapshot()` |
| research_report | 2026-05-08_011_strategy_helper_introduction | 4. `DOC_DISCOVERY.R` via `ledgr_write_doc_snapshot()` \| One task-design friction item remains: `TASK.md` says the final script should discover helper function names without being told them in advance, but the same task brief lists the helper names in the goal. I still used the docs and `DOC_DISCOVERY.R` snapshot as the discovery path. |
| research_report | 2026-05-08_012_multi_asset_rotation_with_helpers | 4. `DOC_DISCOVERY.R` via `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-08_013_trades_fills_and_metrics | 5. `raw_logs/ledgr_doc_snapshot.md`, generated by `source("DOC_DISCOVERY.R"); ledgr_write_doc_snapshot()` |
| research_report | 2026-05-08_014_close_lifecycle | 5. `DOC_DISCOVERY.R` via `ledgr_write_doc_snapshot()`, output saved at |
| research_report | 2026-05-08_015_warmup_and_na_in_helpers | 5. `raw_logs/ledgr_doc_snapshot.md`, generated after sourcing `DOC_DISCOVERY.R` \| - Used `DOC_DISCOVERY.R` to create the installed documentation snapshot and saved relevant help pages. |
| research_report | 2026-05-08_016_helper_type_errors | 4. `DOC_DISCOVERY.R` via `source("DOC_DISCOVERY.R"); ledgr_write_doc_snapshot()` \| - I used `RUN_R.cmd` to avoid PowerShell quoting and stderr-capture friction. |
| research_report | 2026-05-08_017_parametric_helper_comparison | 5. `raw_logs/ledgr_doc_snapshot.md`, generated with `DOC_DISCOVERY.R` |
| research_report | 2026-05-08_018_manual_vs_helper_parity | 5. `raw_logs/ledgr_doc_snapshot.md`, generated by sourcing `DOC_DISCOVERY.R` |
| research_report | 2026-05-08_019_zero_trade_diagnosis | 6. `raw_logs/ledgr_doc_snapshot.md`, generated from `DOC_DISCOVERY.R` \| 7. Help topics saved through `DOC_DISCOVERY.R`: `?select_top_n`, `?ledgr_pulse_snapshot`, `?ledgr_feature_contracts`, `?signal_return`, and `?target_rebalance` |
| research_report | 2026-05-08_020_metrics_and_accounting_article | 5. `DOC_DISCOVERY.R`, via `ledgr_write_doc_snapshot()` \| - Documentation snapshot: `.\RUN_R.cmd -Expr "source('DOC_DISCOVERY.R'); ledgr_write_doc_snapshot()" -Name doc_snapshot` |
| research_report | 2026-05-08_021_indicators_article | 5. `raw_logs/ledgr_doc_snapshot.md`, generated by `source("DOC_DISCOVERY.R"); ledgr_write_doc_snapshot()` \| The first read attempt for generated help files used filenames with a `_help` suffix, but `ledgr_save_help()` writes files as `raw_logs/<topic>.txt`. This was local episode handling friction and was resolved by listing `raw_logs/` and reading the generated filenames. |
| research_report | 2026-05-08_022_help_page_discoverability | vignettes without browsing `vignette(package = "ledgr")` and without using a \| vignette's examples to completion, and assess whether a headless user can find \| 6. `DOC_DISCOVERY.R` |
| research_report | 2026-05-08_023_feature_map_strategy_authoring | 5. `DOC_DISCOVERY.R` generated `raw_logs/ledgr_doc_snapshot.md` \| No ledgr runtime debugging was needed after following the rendered vignettes. I did one documentation-discovery pass with `DOC_DISCOVERY.R`, then saved the relevant help topics with the helper functions before writing the script. The main first-time-user friction was that `ctx$features()` is documented on `?ledgr_feature_map` and in vignettes, but it is not discoverable as its own help topic from `ledgr_help_topics()`. |
| research_report | 2026-05-08_024_pulse_inspection_views | 4. `DOC_DISCOVERY.R` via `run_doc_discovery.R` \| I also initially looked for saved help files with `help-*.md` names, but `ledgr_save_help()` wrote `raw_logs/<topic>.txt`. This did not block the ledgr task. |
| research_report | 2026-05-08_026_warmup_diagnostic_and_three_cases | 4. `raw_logs/ledgr_doc_snapshot.md`, generated by sourcing `DOC_DISCOVERY.R` |
| research_report | 2026-05-08_027_ledger_events_and_metrics_error | 5. `DOC_DISCOVERY.R`, via `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-08_028_snapshot_info_metadata_columns | 4. `DOC_DISCOVERY.R` via `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-08_029_mixed_builtin_ttr_feature_map | 4. `DOC_DISCOVERY.R`, via `ledgr_write_doc_snapshot()` \| pattern. `ledgr_save_help()` had written `*.txt` files in `raw_logs/`, so I |
| research_report | 2026-05-08_030_multi_lookback_pre_registration | 5. `raw_logs/ledgr_doc_snapshot.md`, generated from `DOC_DISCOVERY.R` |
| research_report | 2026-05-08_031_ctx_features_discoverability | 5. `DOC_DISCOVERY.R` via `ledgr_write_doc_snapshot()` \| The first attempted read of saved help files used guessed filenames ending in `_help.txt`, but `ledgr_save_help()` actually wrote files such as `raw_logs/ledgr_feature_map.txt`. Listing `raw_logs/` resolved this. This was episode/file-discovery friction, not a ledgr API problem. |
| research_report | 2026-05-08_032_yahoo_five_strategies | 6. `DOC_DISCOVERY.R` via `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-08_033_strategy_extraction_and_recovery | 5. `DOC_DISCOVERY.R` via `ledgr_write_doc_snapshot()` |

## Agent And Harness Performance

### Runner Types

| runner_type | episodes |
| --- | --- |
| codex | 33 |

### Runner Models

| runner_model | episodes |
| --- | --- |
| (blank) | 33 |

### Runner Exit Status

| runner_exit_status | episodes |
| --- | --- |
| 0 | 33 |

### Check Status

| check_status | episodes |
| --- | --- |
| (blank) | 33 |

## Prompt And Task Quality

- Review repeated duplicate candidates, missing source_docs rows, and
  documentation discovery friction before choosing the next task theme.
- Confirm whether task briefs were too broad, too narrow, or missing
  constraints before promoting generated follow-up tasks.

## Next-Cycle Theme Candidates

- Episode environment and Windows friction
- Summary, metrics, ledger, and result inspection clarity
- Strategy and feature-map authoring docs
- Warmup, final-bar, zero-trade, and short-sample diagnostics
- Snapshot import, sealing, and metadata contracts

## Maintainer Notes

- TODO: Record final duplicate decisions.
- TODO: Record which ledgr fixes, docs, or tests should be prioritized.
- TODO: Choose the next cycle theme.
