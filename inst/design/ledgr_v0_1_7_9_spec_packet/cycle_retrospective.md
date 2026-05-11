# auditr Cycle Retrospective

Source: `C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.7.8`

This is a maintainer-review artifact. It does not create GitHub issues,
does not execute ledgr workflows, and does not decide final defect truth.


## Status

- episodes: 38
- feedback rows: 82
- feedback summary valid: yes
- categorized feedback: valid
- partial retrospective: no

## Feedback Counts

### Type

| type | items |
| --- | --- |
| documentation_gap | 55 |
| ux_friction | 17 |
| unclear_error | 6 |
| bug | 4 |

### Triage

| triage | items |
| --- | --- |
| docs_gap | 61 |
| expected_user_error | 11 |
| unclear | 10 |

### Severity

| severity | items |
| --- | --- |
| low | 72 |
| medium | 9 |
| high | 1 |

## Task Coverage

### Task Titles

| task_title | episodes |
| --- | --- |
| Author scalar and vectorized custom indicators from documentation | 1 |
| Build a multi-asset rotation strategy using strategy helpers | 1 |
| Build a single-asset SMA crossover strategy | 1 |
| Build a strategy using a mixed built-in and TTR-backed feature map | 1 |
| Build a strategy using feature maps and the mapped accessor | 1 |
| Build a two-asset momentum strategy | 1 |
| Build an RSI mean-reversion strategy | 1 |
| Classify strategies with preflight and observe Tier 3 blocking | 1 |
| Combine Bollinger Bands and MACD indicators | 1 |
| Compare two helper-pipeline variants with different parameters | 1 |
| Create, import, seal, and run from a CSV snapshot using the low-level path | 1 |
| Diagnose a strategy that runs without error but produces no trades | 1 |
| Diagnose leakage in a vectorized feature and correct it | 1 |
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
| straightforward | 31 |
| challenging | 6 |
| hard | 1 |

## Duplicate Candidates

These are deterministic suggestions only. auditr does not merge findings.

| normalized_title | feedback_ids | titles | episode_ids | n |
| --- | --- | --- | --- | --- |

## Documentation Provenance

- feedback rows missing source_docs: 0
- documentation discovery friction rows: 77

### High-Severity Rows Missing Source Context

| episode_id | feedback_id | title | severity |
| --- | --- | --- | --- |

### Repeated Source Docs

| source_doc | items |
| --- | --- |
| TASK.md | 28 |
| LEDGR_DOCS/strategy-development.md | 20 |
| LEDGR_DOCS/indicators.md | 15 |
| ?ledgr_run | 11 |
| LEDGR_DOCS/experiment-store.md | 11 |
| episode_environment | 9 |
| LEDGR_DOCS/metrics-and-accounting.md | 9 |
| ?ledgr_results | 8 |
| ?ledgr_backtest | 6 |
| LEDGR_DOCS/custom-indicators.md | 6 |
| LEDGR_DOCS/getting-started.md | 5 |
| ?ledgr_compare_runs | 4 |
| ?ledgr_compute_metrics | 4 |
| ?ledgr_feature_map | 4 |
| ?ledgr_indicator | 4 |
| ?summary.ledgr_backtest | 4 |
| raw_logs/ledgr_doc_snapshot.md | 4 |
| ?ledgr_extract_strategy | 3 |
| ?ledgr_feature_contracts | 3 |
| ?ledgr_ind_ttr | 3 |
| ?ledgr_pulse_features | 3 |
| ?ledgr_pulse_snapshot | 3 |
| ?ledgr_snapshot_from_yahoo | 3 |
| ?ledgr_snapshot_seal | 3 |
| LEDGR_DOCS/reproducibility.md | 3 |
| ?ledgr_ind_rsi | 2 |
| ?ledgr_ind_sma | 2 |
| ?ledgr_snapshot_info | 2 |
| ?passed_warmup | 2 |
| ?select_top_n | 2 |
| ?signal_return | 2 |
| ?target_rebalance | 2 |
| AGENT_PROMPT.md | 2 |
| DOC_DISCOVERY.R | 2 |
| LEDGR_DOCS/leakage.md | 2 |
| ?close.ledgr_backtest | 1 |
| ?ledgr-package | 1 |
| ?ledgr_experiment | 1 |
| ?ledgr_run_info | 1 |
| ?ledgr_run_list | 1 |
| ?ledgr_sim_bars | 1 |
| ?ledgr_snapshot_from_csv | 1 |
| ?ledgr_snapshot_from_df | 1 |
| ?ledgr_snapshot_import_bars_csv | 1 |
| ?ledgr_strategy_preflight | 1 |
| ?ledgr_weights | 1 |
| installed examples/README.md | 1 |
| LEDGR_DOCS/scripts/getting-started.R | 1 |
| raw_logs/ledgr-package.txt | 1 |
| raw_logs/ledgr_pulse_features.txt | 1 |
| raw_logs/ledgr_run.txt | 1 |
| reproducible_script.R | 1 |

### Discovery Friction Evidence

| source | episode_id | evidence |
| --- | --- | --- |
| feedback_summary | 2026-05-10_001_cold_start_readme | Installed README-style example file is not executable |
| feedback_summary | 2026-05-10_001_cold_start_readme | Package overview points to vignettes but lacks a minimal smoke test |
| feedback_summary | 2026-05-10_001_cold_start_readme | Getting-started smoke test depends on suggested tidyverse packages |
| feedback_summary | 2026-05-10_003_single_asset_sma_crossover | SMA help topic lacks feature ID and warmup guidance |
| feedback_summary | 2026-05-10_005_rsi_mean_reversion | RSI is documented through TTR while a native RSI helper also exists |
| feedback_summary | 2026-05-10_005_rsi_mean_reversion | Native RSI help lacks strategy and feature-contract context |
| feedback_summary | 2026-05-10_005_rsi_mean_reversion | TTR dependency requirement needs an episode-safe fallback note |
| feedback_summary | 2026-05-10_006_bbands_macd | ledgr_ind_ttr help example does not show expected MACD feature IDs |
| feedback_summary | 2026-05-10_006_bbands_macd | Default pulse feature printing truncates long multi-output indicator IDs |
| feedback_summary | 2026-05-10_007_experiment_store_compare | ledgr_run same-ID resume behavior is not documented |
| feedback_summary | 2026-05-10_008_snapshot_csv_seal_backtest | High-level CSV snapshot help omits the CSV contract and sealing semantics |
| feedback_summary | 2026-05-10_008_snapshot_csv_seal_backtest | Recursive raw log search can hit locked runner logs |
| feedback_summary | 2026-05-10_009_edge_case_ten_bars | Getting-started SMA20 example lacks short-sample guidance |
| feedback_summary | 2026-05-10_010_strategy_development_article | Strategy article uses stale version number in warn_empty note |
| feedback_summary | 2026-05-10_010_strategy_development_article | What's Next link points to source-tree path instead of installed package path |
| feedback_summary | 2026-05-10_011_strategy_helper_introduction | Task asks for undisclosed helper discovery while naming the helpers |
| feedback_summary | 2026-05-10_011_strategy_helper_introduction | Strategy-development vignette gives conflicting reproducibility tier for helper strategy |
| feedback_summary | 2026-05-10_012_multi_asset_rotation_with_helpers | Strategy helper rotation example only shows two instruments |
| feedback_summary | 2026-05-10_012_multi_asset_rotation_with_helpers | Last-bar no-fill warning needs clearer first-run interpretation |
| feedback_summary | 2026-05-10_012_multi_asset_rotation_with_helpers | Rebalance helper can create many small adjustment trades |
| feedback_summary | 2026-05-10_013_trades_fills_and_metrics | Result inspection help examples do not produce closed trades |
| feedback_summary | 2026-05-10_013_trades_fills_and_metrics | ledgr_backtest help title has stale version label |
| feedback_summary | 2026-05-10_014_close_lifecycle | close documentation does not explicitly show post-close result access |
| feedback_summary | 2026-05-10_015_warmup_and_na_in_helpers | Partial-NA helper-pipeline behavior is only explicit in help, not the vignette |
| feedback_summary | 2026-05-10_015_warmup_and_na_in_helpers | Diagnostic helper functions inside strategies trigger tier-3 preflight |
| feedback_summary | 2026-05-10_017_parametric_helper_comparison | Parameterized lookback needs a clearer multi-feature registration example |
| feedback_summary | 2026-05-10_017_parametric_helper_comparison | Programmatic comparison metric extraction could use a compact example |
| feedback_summary | 2026-05-10_019_zero_trade_diagnosis | ledgr_pulse_features feature-list handling is unclear |
| feedback_summary | 2026-05-10_021_indicators_article | Indicators article shows final-bar warning without explaining it locally |
| feedback_summary | 2026-05-10_022_help_page_discoverability | Strategy vignette points to an installed path with a source-tree prefix |
| feedback_summary | 2026-05-10_022_help_page_discoverability | Printing a discovered vignette can start the R help server in a headless run |
| feedback_summary | 2026-05-10_023_feature_map_strategy_authoring | ctx$features is not directly discoverable as a help topic |
| feedback_summary | 2026-05-10_023_feature_map_strategy_authoring | passed_warmup zero-length error has an undocumented extra class |
| feedback_summary | 2026-05-10_024_pulse_inspection_views | ledgr_pulse_features argument text says columns instead of rows |
| feedback_summary | 2026-05-10_024_pulse_inspection_views | ledgr_pulse_snapshot help underspecifies feature map input |
| feedback_summary | 2026-05-10_024_pulse_inspection_views | Inline PowerShell R expressions can silently expand $ column access |
| feedback_summary | 2026-05-10_025_low_level_csv_snapshot_seal_run | Snapshot count metadata names require cross-checking meta_json |
| feedback_summary | 2026-05-10_026_warmup_diagnostic_and_three_cases | R discovery code is easy to run accidentally as PowerShell |
| feedback_summary | 2026-05-10_026_warmup_diagnostic_and_three_cases | PowerShell dollar expansion can turn R expressions into misleading ledgr errors |
| feedback_summary | 2026-05-10_027_ledger_events_and_metrics_error | Ledger docs do not make portfolio state update event rows concrete |
| feedback_summary | 2026-05-10_028_snapshot_info_metadata_columns | ledgr_snapshot_info help does not enumerate meta_json schema |
| feedback_summary | 2026-05-10_029_mixed_builtin_ttr_feature_map | ledgr_backtest rejects feature maps despite feature-map help saying they are accepted |
| feedback_summary | 2026-05-10_030_multi_lookback_pre_registration | Run comparison docs do not explain how to compare equity curves |
| feedback_summary | 2026-05-10_031_ctx_features_discoverability | No standalone help topic for ctx$features() |
| feedback_summary | 2026-05-10_031_ctx_features_discoverability | Feature-map help lacks a See Also path to warmup details |
| feedback_summary | 2026-05-10_031_ctx_features_discoverability | PowerShell expands $ in inline ctx$features help probe |
| feedback_summary | 2026-05-10_032_yahoo_five_strategies | Yahoo snapshot seal semantics are easy to misread in task workflows |
| feedback_summary | 2026-05-10_032_yahoo_five_strategies | Rendered vignettes lack an end-to-end Yahoo multi-strategy example |
| feedback_summary | 2026-05-10_033_strategy_extraction_and_recovery | No end-to-end recovered-strategy rerun example |
| feedback_summary | 2026-05-10_033_strategy_extraction_and_recovery | Strategy provenance fields lack value reference |
| feedback_summary | 2026-05-10_033_strategy_extraction_and_recovery | Missing-run extraction error class is undocumented |
| feedback_summary | 2026-05-10_034_sharpe_ratio_and_risk_metrics | Flat-strategy Sharpe NA is not shown in the flat example |
| feedback_summary | 2026-05-10_034_sharpe_ratio_and_risk_metrics | Manual Sharpe replication depends on an implicit annualization constant |
| feedback_summary | 2026-05-10_034_sharpe_ratio_and_risk_metrics | summary risk_free_rate help is less explicit than compute_metrics help |
| feedback_summary | 2026-05-10_034_sharpe_ratio_and_risk_metrics | Direct R help capture in a script can start the HTTP help server |
| feedback_summary | 2026-05-10_035_comparison_programmatic_ranking | Experiment-store vignette does not demonstrate raw comparison metrics |
| feedback_summary | 2026-05-10_036_strategy_preflight_and_tier_classification | Tier 3 run failure class is not documented |
| feedback_summary | 2026-05-10_036_strategy_preflight_and_tier_classification | ledgr_run_info object fields are not enumerated |
| feedback_summary | 2026-05-10_037_leakage_diagnosis_and_series_fn_boundary | Leakage article warns about full-sample quantiles but does not show a corrected series_fn |
| feedback_summary | 2026-05-10_037_leakage_diagnosis_and_series_fn_boundary | ledgr_indicator help omits params in fn signature |
| feedback_summary | 2026-05-10_037_leakage_diagnosis_and_series_fn_boundary | Relationship between scalar fn and series_fn is unclear for nontrivial vectorized indicators |
| feedback_summary | 2026-05-10_038_custom_indicator_authoring | No documented way to retrieve persisted feature series |
| feedback_summary | 2026-05-10_038_custom_indicator_authoring | Custom indicator fn params contract is inconsistent |
| feedback_summary | 2026-05-10_038_custom_indicator_authoring | Broad raw_logs search hit shell and locked-file friction |
| research_report | 2026-05-10_008_snapshot_csv_seal_backtest | Searching all `raw_logs/` with `rg` produced access errors for active `codex_*` stdout/stderr logs. This did not block the ledgr workflow; I avoided treating those locked runner logs as ledgr evidence. |
| research_report | 2026-05-10_010_strategy_development_article | - No shell quoting failures occurred because all nontrivial R code was put in saved scripts and run through `RUN_R.cmd`. |
| research_report | 2026-05-10_013_trades_fills_and_metrics | `ledgr_results(bt, what = "metrics")` failed with the expected match-argument error because the documentation says metrics are not a result table; use `ledgr_compute_metrics(bt)` instead. \| The only meaningful documentation friction found was in the help-page examples for `?ledgr_results` and `?ledgr_compute_metrics`: they use a strategy that opens a position but never closes it, so the example trade table has zero rows and the trade metrics are `n_trades = 0`, `win_rate = NA`, `avg_trade = NA`. That is valid behavior, but it is a weak first example for learning the trades and metrics interface. Evidence is in `raw_logs/doc_example_trades.txt` and `raw_logs/doc_example_metrics.txt`. |
| research_report | 2026-05-10_018_manual_vs_helper_parity | No actionable documentation gap, API bug, unclear ledgr error, or workaround was observed. |
| research_report | 2026-05-10_019_zero_trade_diagnosis | One documentation/API friction point occurred while inspecting the late pulse: I first passed a plain indicator list to `ledgr_pulse_features(pulse, features)` because plain lists are accepted by `ledgr_pulse_snapshot()`, `ledgr_experiment()`, and `ledgr_feature_contracts()`. `ledgr_pulse_features()` errored with `` `x` must be a ledgr_feature_map object ``. The workaround was to use `ledgr_feature_map()` for the diagnostic feature declarations. |
| research_report | 2026-05-10_021_indicators_article | No ledgr API failures blocked the task. The only notable friction was that the indicators example and my backtest emitted `LEDGR_LAST_BAR_NO_FILL`. The indicators article shows this warning in example output but does not explain it nearby. I found the explanation later in `LEDGR_DOCS/metrics-and-accounting.md`: under the next-open fill model, a target emitted on the last pulse cannot fill because no later bar exists. |
| research_report | 2026-05-10_023_feature_map_strategy_authoring | Friction: the package help-topic list does not expose `ctx$features` as its own searchable help topic because it is a context method rather than an exported function. A first-time user searching help pages for `ctx$features` directly has to find it indirectly through `?ledgr_feature_map`, vignettes, or text search. |
| research_report | 2026-05-10_024_pulse_inspection_views | - No ledgr API failure was encountered. The only ledgr documentation issue found was minor wording in `?ledgr_pulse_features`, where the `feature_map` argument says it filters and orders feature columns even though the function returns long feature rows. |
| research_report | 2026-05-10_026_warmup_diagnostic_and_three_cases | Third, while trying to create a compact reproduction with `-Expr`, I used R code containing `$` inside a PowerShell double-quoted argument. PowerShell expanded `$instrument_id` and `$flat`, which produced a misleading ledgr input error. I retried with an expression that avoided `$`, and then captured the intended feature-map failure in `raw_logs/feature_map_backtest_failure_no_dollar_stderr.txt`. |
| research_report | 2026-05-10_027_ledger_events_and_metrics_error | No ledgr runtime blocker occurred. Documentation discovery worked after sourcing `DOC_DISCOVERY.R`, and the final script ran cleanly with no stderr output. The main friction was interpretive: the task asks about portfolio state update events, but the public ledger table for this simple run contains only `FILL` events. |
| research_report | 2026-05-10_034_sharpe_ratio_and_risk_metrics | `tools::Rd2txt()`. \| No ledgr API failure blocked the task. |
| research_report | 2026-05-10_036_strategy_preflight_and_tier_classification | For the blocked-run check, I constructed a `ledgr_experiment()` around the Tier |
| research_report | 2026-05-10_038_custom_indicator_authoring | Blocked: \| 7. One broad `rg` search over `raw_logs/` hit locked live Codex log files; a narrower search avoided those files. Evidence appears in the command output from the `rg` run. |

## Agent And Harness Performance

### Runner Types

| runner_type | episodes |
| --- | --- |
| codex | 38 |

### Runner Models

| runner_model | episodes |
| --- | --- |
| (blank) | 38 |

### Runner Exit Status

| runner_exit_status | episodes |
| --- | --- |
| 0 | 38 |

### Check Status

| check_status | episodes |
| --- | --- |
| (blank) | 38 |

## Prompt And Task Quality

- Review repeated duplicate candidates, missing source_docs rows, and
  documentation discovery friction before choosing the next task theme.
- Confirm whether task briefs were too broad, too narrow, or missing
  constraints before promoting generated follow-up tasks.

## Next-Cycle Theme Candidates

- Runtime errors and warnings need more actionable messages
- Experiment store, run comparison, and persisted results need stronger programmatic examples
- Indicator feature IDs, warmup, and helper contracts are under-documented
- Feature map compatibility is inconsistent across APIs
- Custom indicator scalar and vectorized contracts conflict

## Maintainer Notes

- TODO: Record final duplicate decisions.
- TODO: Record which ledgr fixes, docs, or tests should be prioritized.
- TODO: Choose the next cycle theme.
