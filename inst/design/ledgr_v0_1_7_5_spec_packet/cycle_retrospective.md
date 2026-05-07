# auditr Cycle Retrospective

Source: `C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.7.4_second_run`

This is a maintainer-review artifact. It does not create GitHub issues,
does not execute ledgr workflows, and does not decide final defect truth.

## Status

- episodes: 25
- feedback rows: 45
- feedback summary valid: yes
- categorized feedback: valid
- partial retrospective: no

## Feedback Counts

### Type

| type | items |
| --- | --- |
| documentation_gap | 37 |
| ux_friction | 4 |
| bug | 2 |
| unclear_error | 2 |

### Triage

| triage | items |
| --- | --- |
| docs_gap | 34 |
| expected_user_error | 6 |
| unclear | 5 |

### Severity

| severity | items |
| --- | --- |
| low | 41 |
| medium | 3 |
| high | 1 |

## Task Coverage

### Task Titles

| task_title | episodes |
| --- | --- |
| Build a multi-asset rotation strategy using strategy helpers | 1 |
| Build a single-asset SMA crossover strategy | 1 |
| Build a strategy using feature maps and the mapped accessor | 1 |
| Build a two-asset momentum strategy | 1 |
| Build an RSI mean-reversion strategy | 1 |
| Combine Bollinger Bands and MACD indicators | 1 |
| Compare two helper-pipeline variants with different parameters | 1 |
| Create, import, seal, and run from a CSV snapshot using the low-level path | 1 |
| Diagnose a strategy that runs without error but produces no trades | 1 |
| Discover installed articles from function-level help pages | 1 |
| Follow the getting-started vignette | 1 |
| Follow the indicators article end to end | 1 |
| Follow the metrics-and-accounting article and verify metrics by hand | 1 |
| Follow the strategy-development article end to end | 1 |
| Handle warmup periods and missing values in a helper pipeline strategy | 1 |
| Import CSV data, seal it, and run a backtest | 1 |
| Inspect feature contracts and pulse data before running a backtest | 1 |
| Inspect trades, fills, and summary metrics from a backtest | 1 |
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
| straightforward | 22 |
| challenging | 1 |
| hard | 1 |
| medium | 1 |

## Duplicate Candidates

These are deterministic suggestions only. auditr does not merge findings.

| normalized_title | feedback_ids | titles | episode_ids | n |
| --- | --- | --- | --- | --- |

## Documentation Provenance

- feedback rows missing source_docs: 0
- documentation discovery friction rows: 40

### High-Severity Rows Missing Source Context

| episode_id | feedback_id | title | severity |
| --- | --- | --- | --- |

### Repeated Source Docs

| source_doc | items |
| --- | --- |
| TASK.md | 17 |
| LEDGR_DOCS/indicators.md | 13 |
| LEDGR_DOCS/strategy-development.md | 13 |
| LEDGR_DOCS/getting-started.md | 6 |
| episode_environment | 5 |
| LEDGR_DOCS/experiment-store.md | 5 |
| LEDGR_DOCS/metrics-and-accounting.md | 5 |
| ?ledgr_ind_ttr | 4 |
| ?ledgr_feature_contracts | 3 |
| ?ledgr_pulse_snapshot | 3 |
| ?ledgr_results | 3 |
| ?ledgr_run | 3 |
| ?ledgr_snapshot_seal | 3 |
| ?summary.ledgr_backtest | 3 |
| raw_logs/ledgr_doc_snapshot.md | 3 |
| ?close.ledgr_backtest | 2 |
| ?ledgr_experiment | 2 |
| ?ledgr_ind_rsi | 2 |
| ?ledgr_ind_sma | 2 |
| ?ledgr_pulse_features | 2 |
| ?ledgr_snapshot_from_csv | 2 |
| ?ledgr_snapshot_from_df | 2 |
| ?ledgr_snapshot_import_bars_csv | 2 |
| ?ledgr_snapshot_load | 2 |
| ?select_top_n | 2 |
| ?signal_return | 2 |
| ?target_rebalance | 2 |
| LEDGR_DOCS/index.md | 2 |
| ?ledgr-package | 1 |
| ?ledgr_compute_metrics | 1 |
| ?ledgr_feature_id | 1 |
| ?ledgr_feature_map | 1 |
| ?ledgr_pulse_wide | 1 |
| ?ledgr_run_list | 1 |
| ?ledgr_run_open | 1 |
| ?ledgr_sim_bars | 1 |
| ?ledgr_snapshot_create | 1 |
| ?ledgr_snapshot_info | 1 |
| ?ledgr_ttr_warmup_rules | 1 |
| ?passed_warmup | 1 |
| ?weight_equal | 1 |
| AGENT_PROMPT.md | 1 |
| examples/README.md | 1 |
| LEDGR_DOCS/scripts/getting-started.R | 1 |
| raw_logs/ledgr_pulse_features.txt | 1 |

### Discovery Friction Evidence

| source | episode_id | evidence |
| --- | --- | --- |
| feedback_summary | 2026-05-07_001_cold_start_readme | Package overview lacks a minimal runnable example |
| feedback_summary | 2026-05-07_001_cold_start_readme | Installed examples README contains no executable examples |
| feedback_summary | 2026-05-07_003_single_asset_sma_crossover | Windows rg glob failed for saved help files |
| feedback_summary | 2026-05-07_004_multi_asset_momentum | ledgr_snapshot_from_df help lacks a multi-asset example |
| feedback_summary | 2026-05-07_005_rsi_mean_reversion | Built-in RSI help does not show experiment usage |
| feedback_summary | 2026-05-07_006_bbands_macd | ledgr_ind_ttr help example does not print expected MACD IDs |
| feedback_summary | 2026-05-07_008_snapshot_csv_seal_backtest | ledgr_snapshot_from_csv help omits the full CSV contract |
| feedback_summary | 2026-05-07_009_edge_case_ten_bars | `ledgr_ind_sma` help omits warmup behavior |
| feedback_summary | 2026-05-07_010_strategy_development_article | select_top_n help omits its warning class |
| feedback_summary | 2026-05-07_012_multi_asset_rotation_with_helpers | Strategy helper vignette does not show synthetic multi-asset setup |
| feedback_summary | 2026-05-07_013_trades_fills_and_metrics | ledgr_results trade example does not produce a trade row |
| feedback_summary | 2026-05-07_016_helper_type_errors | Helper docs lack negative examples for common pipeline mistakes |
| feedback_summary | 2026-05-07_020_metrics_and_accounting_article | Wrong assumed summary help topic name gave no close-match hint |
| feedback_summary | 2026-05-07_022_help_page_discoverability | Help article links can trigger browser behavior in headless use |
| feedback_summary | 2026-05-07_023_feature_map_strategy_authoring | No standalone help topic for ctx$features mapped accessor |
| feedback_summary | 2026-05-07_023_feature_map_strategy_authoring | PowerShell double quotes expanded ctx$features during help lookup |
| feedback_summary | 2026-05-07_024_pulse_inspection_views | ledgr_pulse_features help uses wide-view wording for long rows |
| research_report | 2026-05-07_001_cold_start_readme | 5. `raw_logs/ledgr_doc_snapshot.md`, generated by `source("DOC_DISCOVERY.R"); ledgr_write_doc_snapshot()` |
| research_report | 2026-05-07_002_cold_start_getting_started | 5. `DOC_DISCOVERY.R` via `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-07_004_multi_asset_momentum | - Sourced `DOC_DISCOVERY.R` and wrote the required documentation snapshot; logs are in `raw_logs/doc_snapshot_*`. |
| research_report | 2026-05-07_005_rsi_mean_reversion | 5. `raw_logs/ledgr_doc_snapshot.md`, generated by sourcing `DOC_DISCOVERY.R` |
| research_report | 2026-05-07_006_bbands_macd | 6. `DOC_DISCOVERY.R` via `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-07_008_snapshot_csv_seal_backtest | - Documentation discovery worked as instructed after sourcing `DOC_DISCOVERY.R`; output was written to `raw_logs/ledgr_doc_snapshot.md`. |
| research_report | 2026-05-07_009_edge_case_ten_bars | 5. `DOC_DISCOVERY.R` via `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-07_010_strategy_development_article | 5. `DOC_DISCOVERY.R`, via `ledgr_write_doc_snapshot()` \| - `.\RUN_R.cmd -Expr "source('DOC_DISCOVERY.R'); ledgr_write_doc_snapshot()" -Name doc_snapshot` succeeded and wrote `raw_logs/ledgr_doc_snapshot.md`. |
| research_report | 2026-05-07_011_strategy_helper_introduction | - Saved help topics with `DOC_DISCOVERY.R` helpers rather than relying only on the rendered vignette. |
| research_report | 2026-05-07_012_multi_asset_rotation_with_helpers | 4. `DOC_DISCOVERY.R`, then `ledgr_write_doc_snapshot()` output at `raw_logs/ledgr_doc_snapshot.md` \| - Documentation discovery worked after sourcing `DOC_DISCOVERY.R`; the generated snapshot correctly mapped strategy helper topics and result-inspection topics. |
| research_report | 2026-05-07_013_trades_fills_and_metrics | 7. `raw_logs/ledgr_doc_snapshot.md`, generated by `source("DOC_DISCOVERY.R"); ledgr_write_doc_snapshot()` |
| research_report | 2026-05-07_014_close_lifecycle | `DOC_DISCOVERY.R` and running `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-07_015_warmup_and_na_in_helpers | 5. `raw_logs/ledgr_doc_snapshot.md`, generated by `DOC_DISCOVERY.R` |
| research_report | 2026-05-07_016_helper_type_errors | 5. `DOC_DISCOVERY.R` via `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-07_017_parametric_helper_comparison | 7. `raw_logs/ledgr_doc_snapshot.md`, generated by `source("DOC_DISCOVERY.R"); ledgr_write_doc_snapshot()` \| No shell quoting, UTF-8, or runner-capture issues blocked the task. |
| research_report | 2026-05-07_018_manual_vs_helper_parity | 5. `DOC_DISCOVERY.R` with `ledgr_write_doc_snapshot()`, recorded in |
| research_report | 2026-05-07_019_zero_trade_diagnosis | 6. `DOC_DISCOVERY.R`, then `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-07_020_metrics_and_accounting_article | 5. `raw_logs/ledgr_doc_snapshot.md`, generated after sourcing `DOC_DISCOVERY.R` and running `ledgr_write_doc_snapshot()` \| The only failed path was a documentation lookup with the wrong S3 method name, `summary.ledgr_backtest_result`; `DOC_DISCOVERY.R` correctly reported no such help topic. Retrying with the topic from the generated snapshot, `summary.ledgr_backtest`, worked. |
| research_report | 2026-05-07_021_indicators_article | 5. `raw_logs/ledgr_doc_snapshot.md`, generated by `source("DOC_DISCOVERY.R"); ledgr_write_doc_snapshot()` |
| research_report | 2026-05-07_022_help_page_discoverability | Discover installed ledgr vignettes starting only from function-level help pages, without browsing `vignette(package = "ledgr")` first and without using a browser. Then follow one discovered vignette to completion and run its examples. \| 2. In the `Articles` section, found `vignette("strategy-development", package = "ledgr")` and `system.file("doc", "strategy-development.html", package = "ledgr")`. \| 3. In the same `?ledgr_run` `Articles` section, found `vignette("metrics-and-accounting", package = "ledgr")` and `system.file("doc", "metrics-and-accounting.html", package = "ledgr")`. |
| research_report | 2026-05-07_023_feature_map_strategy_authoring | 6. `DOC_DISCOVERY.R` and generated `raw_logs/ledgr_doc_snapshot.md` |
| research_report | 2026-05-07_024_pulse_inspection_views | 4. `DOC_DISCOVERY.R`, then `ledgr_write_doc_snapshot()` \| 2. Sourced `DOC_DISCOVERY.R`, wrote the documentation snapshot, and captured the |
| research_report | 2026-05-07_025_low_level_csv_snapshot_seal_run | 5. `DOC_DISCOVERY.R` via `ledgr_write_doc_snapshot()` |

## Agent And Harness Performance

### Runner Types

| runner_type | episodes |
| --- | --- |
| codex | 25 |

### Runner Models

| runner_model | episodes |
| --- | --- |
| (blank) | 25 |

### Runner Exit Status

| runner_exit_status | episodes |
| --- | --- |
| 0 | 25 |

### Check Status

| check_status | episodes |
| --- | --- |
| (blank) | 25 |

## Prompt And Task Quality

- Review repeated duplicate candidates, missing source_docs rows, and
  documentation discovery friction before choosing the next task theme.
- Confirm whether task briefs were too broad, too narrow, or missing
  constraints before promoting generated follow-up tasks.

## Next-Cycle Theme Candidates

- Potential API or runtime defects need maintainer review
- Runnable starter workflows are scattered
- Indicator strategy examples need broader coverage
- Warmup and sample coverage are underexplained
- Pulse and feature-map API docs have naming ambiguity

## Maintainer Notes

- TODO: Record final duplicate decisions.
- TODO: Record which ledgr fixes, docs, or tests should be prioritized.
- TODO: Choose the next cycle theme.
