# auditr Cycle Retrospective

Source: `C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.7.7`

This is a maintainer-review artifact. It does not create GitHub issues,
does not execute ledgr workflows, and does not decide final defect truth.

## Maintainer Harness Findings

This section is a human-maintainer overlay added after report generation. It
separates auditr harness findings from ledgr product findings for handoff.

- The run itself was healthy: all 35 runner exits were `0`, feedback summary
  validation passed, categorized feedback validation passed, and no feedback
  rows were missing `source_docs`.
- The `documentation discovery friction rows: 44` count below is inflated.
  Many counted rows simply record normal successful `DOC_DISCOVERY.R` usage.
  auditr should narrow this detector to actual failure or workaround language.
- auditr should update `DOC_DISCOVERY.R` task-intent mapping to surface
  `ledgr_extract_strategy` for strategy extraction, recovery, and
  experiment-store tasks.
- auditr should tighten task brief wording where the task asks agents to
  discover helpers but names the exact helpers, and where task checklist counts
  conflict with the referenced ledgr docs.
- auditr should document or avoid broad recursive searches over live
  `raw_logs/` because active `codex_*` stdout/stderr files can be locked on
  Windows.
- auditr should keep Windows shell-search guidance visible for R expressions
  containing `$`, such as `ctx$features`, because PowerShell expands `$...`
  inside double-quoted patterns.

## Status

- episodes: 35
- feedback rows: 68
- feedback summary valid: yes
- categorized feedback: valid
- partial retrospective: no

## Feedback Counts

### Type

| type | items |
| --- | --- |
| documentation_gap | 57 |
| ux_friction | 9 |
| unclear_error | 2 |

### Triage

| triage | items |
| --- | --- |
| docs_gap | 57 |
| expected_user_error | 6 |
| unclear | 5 |

### Severity

| severity | items |
| --- | --- |
| low | 63 |
| medium | 5 |

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
| Rank multiple runs programmatically using the comparison table | 1 |
| Register all lookback variants before ledgr_run() in a parameter sweep | 1 |
| Run a strategy with only 10 bars of data | 1 |
| Run the README example | 1 |
| Run two variants and compare results | 1 |
| Trigger and interpret strategy helper error messages | 1 |
| Understand the backtest object lifecycle and close() behaviour | 1 |
| Use the strategy helper pipeline from documentation | 1 |
| Verify that raw strategy logic and the helper pipeline produce the same results | 1 |
| Verify the Sharpe ratio metric and risk-free-rate parameter | 1 |

### Difficulty

| difficulty | episodes |
| --- | --- |
| straightforward | 30 |
| medium | 3 |
| challenging | 2 |

## Duplicate Candidates

These are deterministic suggestions only. auditr does not merge findings.

| normalized_title | feedback_ids | titles | episode_ids | n |
| --- | --- | --- | --- | --- |

## Documentation Provenance

- feedback rows missing source_docs: 0
- documentation discovery friction rows: 44

### High-Severity Rows Missing Source Context

| episode_id | feedback_id | title | severity |
| --- | --- | --- | --- |

### Repeated Source Docs

| source_doc | items |
| --- | --- |
| LEDGR_DOCS/strategy-development.md | 24 |
| TASK.md | 23 |
| LEDGR_DOCS/indicators.md | 19 |
| LEDGR_DOCS/metrics-and-accounting.md | 11 |
| LEDGR_DOCS/experiment-store.md | 10 |
| ?summary.ledgr_backtest | 9 |
| LEDGR_DOCS/getting-started.md | 9 |
| ?ledgr_run | 8 |
| episode_environment | 8 |
| ?ledgr_compute_metrics | 5 |
| ?ledgr_feature_contracts | 4 |
| ?ledgr_ind_ttr | 4 |
| ?ledgr_pulse_features | 4 |
| ?ledgr_results | 4 |
| ?ledgr_snapshot_info | 4 |
| ?ledgr_snapshot_seal | 4 |
| ?signal_return | 4 |
| raw_logs/ledgr_doc_snapshot.md | 4 |
| ?ledgr_feature_id | 3 |
| ?ledgr_feature_map | 3 |
| ?passed_warmup | 3 |
| ?ledgr_backtest | 2 |
| ?ledgr_compare_runs | 2 |
| ?ledgr_experiment | 2 |
| ?ledgr_extract_strategy | 2 |
| ?ledgr_ind_rsi | 2 |
| ?ledgr_pulse_snapshot | 2 |
| ?select_top_n | 2 |
| ?target_rebalance | 2 |
| ?close.ledgr_backtest | 1 |
| ?ledgr-package | 1 |
| ?ledgr_ind_returns | 1 |
| ?ledgr_ind_sma | 1 |
| ?ledgr_run_info | 1 |
| ?ledgr_snapshot_from_csv | 1 |
| ?ledgr_snapshot_from_yahoo | 1 |
| ?ledgr_weights | 1 |
| ?weight_equal | 1 |
| installed examples/README.md | 1 |
| LEDGR_DOCS/scripts/getting-started.R | 1 |
| raw_logs/select_top_n.txt | 1 |
| raw_logs/signal_return.txt | 1 |

### Discovery Friction Evidence

| source | episode_id | evidence |
| --- | --- | --- |
| feedback_summary | 2026-05-10_001_cold_start_readme | No installed README-style executable first example |
| feedback_summary | 2026-05-10_003_single_asset_sma_crossover | ledgr_ind_sma help page lacks strategy context |
| feedback_summary | 2026-05-10_005_rsi_mean_reversion | Built-in RSI helper is much less documented than TTR RSI |
| feedback_summary | 2026-05-10_008_snapshot_csv_seal_backtest | Snapshot info usage does not show snapshot-handle form clearly |
| feedback_summary | 2026-05-10_015_warmup_and_na_in_helpers | ledgr_ind_returns help omits warmup metadata |
| feedback_summary | 2026-05-10_022_help_page_discoverability | Entry-point run help omits Getting Started article link |
| feedback_summary | 2026-05-10_023_feature_map_strategy_authoring | ctx$features has no standalone help topic |
| feedback_summary | 2026-05-10_024_pulse_inspection_views | ledgr_pulse_features help uses wide-view wording for long rows |
| feedback_summary | 2026-05-10_031_ctx_features_discoverability | No standalone help topic for ctx feature accessors |
| feedback_summary | 2026-05-10_031_ctx_features_discoverability | No obvious ledgr strategy help topic |
| feedback_summary | 2026-05-10_033_strategy_extraction_and_recovery | Strategy extraction is not surfaced in the experiment-store task map |
| research_report | 2026-05-10_001_cold_start_readme | 6. `raw_logs/ledgr_doc_snapshot.md`, generated by `DOC_DISCOVERY.R` |
| research_report | 2026-05-10_002_cold_start_getting_started | 5. `raw_logs/ledgr_doc_snapshot.md`, generated by `source("DOC_DISCOVERY.R"); ledgr_write_doc_snapshot()` \| 6. Help topics saved with `DOC_DISCOVERY.R`: `?ledgr_run`, `?ledgr_snapshot_from_df`, `?ledgr_results`, and `?ledgr_experiment` |
| research_report | 2026-05-10_003_single_asset_sma_crossover | 6. `raw_logs/ledgr_doc_snapshot.md`, generated by sourcing `DOC_DISCOVERY.R` \| - No shell quoting workaround was needed because all multi-line R code was saved |
| research_report | 2026-05-10_004_multi_asset_momentum | 6. `DOC_DISCOVERY.R`, then `ledgr_write_doc_snapshot()` \| 8. Help pages saved with `ledgr_save_help()` for `signal_return`, `select_top_n`, `weight_equal`, `target_rebalance`, `ledgr_experiment`, `ledgr_run`, `ledgr_snapshot_from_df`, `ledgr_results`, `ledgr_ind_returns`, `ledgr_signal`, `ledgr_selection`, `ledgr_weights`, and `ledgr_target` |
| research_report | 2026-05-10_005_rsi_mean_reversion | 6. `DOC_DISCOVERY.R` via `ledgr_write_doc_snapshot()`, output in `raw_logs/ledgr_doc_snapshot.md` |
| research_report | 2026-05-10_006_bbands_macd | 5. `DOC_DISCOVERY.R` via `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-10_007_experiment_store_compare | 5. `DOC_DISCOVERY.R` via `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-10_008_snapshot_csv_seal_backtest | 5. `DOC_DISCOVERY.R`, via `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-10_009_edge_case_ten_bars | 5. `DOC_DISCOVERY.R` with `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-10_010_strategy_development_article | 5. `DOC_DISCOVERY.R`, via `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-10_011_strategy_helper_introduction | 5. `DOC_DISCOVERY.R` \| No ledgr execution errors occurred. The main friction was task-level: `TASK.md` says the helper functions should be discovered through documentation and not supplied in advance, but the goal line names the exact helpers. I still followed the documentation workflow and confirmed the discovery path through `LEDGR_DOCS/strategy-development.md`, the `DOC_DISCOVERY.R` snapshot task-intent map, and saved installed help pages. |
| research_report | 2026-05-10_012_multi_asset_rotation_with_helpers | 5. `DOC_DISCOVERY.R` via `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-10_013_trades_fills_and_metrics | 6. `raw_logs/ledgr_doc_snapshot.md`, generated by `DOC_DISCOVERY.R` |
| research_report | 2026-05-10_014_close_lifecycle | 6. `DOC_DISCOVERY.R` via `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-10_015_warmup_and_na_in_helpers | 5. `raw_logs/ledgr_doc_snapshot.md`, generated by `source("DOC_DISCOVERY.R"); ledgr_write_doc_snapshot()` |
| research_report | 2026-05-10_016_helper_type_errors | 4. `DOC_DISCOVERY.R` with `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-10_017_parametric_helper_comparison | 5. `DOC_DISCOVERY.R` via `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-10_019_zero_trade_diagnosis | 5. `DOC_DISCOVERY.R` via `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-10_020_metrics_and_accounting_article | 5. `DOC_DISCOVERY.R` via `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-10_021_indicators_article | 5. `raw_logs/ledgr_doc_snapshot.md`, generated by sourcing `DOC_DISCOVERY.R` and running `ledgr_write_doc_snapshot()` \| - The documentation discovery workflow worked: `DOC_DISCOVERY.R` generated a task-intent map that pointed to the indicators article and the relevant help topics. |
| research_report | 2026-05-10_022_help_page_discoverability | Discover installed ledgr articles starting only from function-level help pages, without using `vignette(package = "ledgr")` or a browser until at least one vignette name was found from help text. Then navigate to at least two installed vignettes, run one linked vignette to completion, and judge whether a headless user can find teaching material from help alone. \| 3. `raw_logs/ledgr_doc_snapshot.md`, generated by `source("DOC_DISCOVERY.R"); ledgr_write_doc_snapshot()` \| - `vignette("strategy-development", package = "ledgr")` |
| research_report | 2026-05-10_023_feature_map_strategy_authoring | 5. `DOC_DISCOVERY.R` via `ledgr_write_doc_snapshot()` \| - Saved help pages with `DOC_DISCOVERY.R` helpers rather than browser help. \| - Used `RUN_R.cmd` for all R execution to avoid PowerShell quoting problems. |
| research_report | 2026-05-10_024_pulse_inspection_views | 4. `DOC_DISCOVERY.R` via `ledgr_write_doc_snapshot()` \| `ledgr_pulse_wide()` as inspection views over the same pulse. The doc discovery |
| research_report | 2026-05-10_025_low_level_csv_snapshot_seal_run | 5. `raw_logs/ledgr_doc_snapshot.md`, generated by `source("DOC_DISCOVERY.R"); ledgr_write_doc_snapshot()` |
| research_report | 2026-05-10_026_warmup_diagnostic_and_three_cases | 5. `DOC_DISCOVERY.R`, then `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-10_027_ledger_events_and_metrics_error | 4. `DOC_DISCOVERY.R` via `source("DOC_DISCOVERY.R"); ledgr_write_doc_snapshot()` |
| research_report | 2026-05-10_028_snapshot_info_metadata_columns | 4. `DOC_DISCOVERY.R`, then `ledgr_write_doc_snapshot()`. |
| research_report | 2026-05-10_029_mixed_builtin_ttr_feature_map | 4. `DOC_DISCOVERY.R` via `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-10_030_multi_lookback_pre_registration | 6. `DOC_DISCOVERY.R`, then `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-10_031_ctx_features_discoverability | 4. `DOC_DISCOVERY.R`, then `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-10_033_strategy_extraction_and_recovery | 5. `DOC_DISCOVERY.R` via `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-10_034_sharpe_ratio_and_risk_metrics | 5. `DOC_DISCOVERY.R` via `ledgr_write_doc_snapshot()` |
| research_report | 2026-05-10_035_comparison_programmatic_ranking | 4. `DOC_DISCOVERY.R` via `source("DOC_DISCOVERY.R"); ledgr_write_doc_snapshot()` |

## Agent And Harness Performance

### Runner Types

| runner_type | episodes |
| --- | --- |
| codex | 35 |

### Runner Models

| runner_model | episodes |
| --- | --- |
| (blank) | 35 |

### Runner Exit Status

| runner_exit_status | episodes |
| --- | --- |
| 0 | 35 |

### Check Status

| check_status | episodes |
| --- | --- |
| (blank) | 35 |

## Prompt And Task Quality

- Review repeated duplicate candidates, missing source_docs rows, and
  documentation discovery friction before choosing the next task theme.
- Confirm whether task briefs were too broad, too narrow, or missing
  constraints before promoting generated follow-up tasks.

## Next-Cycle Theme Candidates

- Feature map, ctx accessor, and feature ID discoverability
- Metrics, accounting, and comparison auditability
- Warmup, short-sample, and current-bar diagnostics
- Strategy helper dependency and parameter workflow friction
- First-run and entry-point documentation gaps

## Maintainer Notes

- TODO: Record final duplicate decisions.
- TODO: Record which ledgr fixes, docs, or tests should be prioritized.
- TODO: Choose the next cycle theme.
