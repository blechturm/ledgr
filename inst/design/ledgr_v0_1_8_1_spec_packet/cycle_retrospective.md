# auditr Cycle Retrospective

Source: `C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.8`

This is a maintainer-review artifact. It does not create GitHub issues,
does not execute ledgr workflows, and does not decide final defect truth.


## Status

- episodes: 44
- feedback rows: 97
- feedback summary valid: yes
- categorized feedback: valid
- partial retrospective: no

## Feedback Counts

### Type

| type | items |
| --- | --- |
| documentation_gap | 78 |
| ux_friction | 11 |
| unclear_error | 8 |

### Triage

| triage | items |
| --- | --- |
| docs_gap | 84 |
| unclear | 7 |
| expected_user_error | 6 |

### Severity

| severity | items |
| --- | --- |
| low | 83 |
| medium | 14 |

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
| Observe sweep failure rows and stop_on_error behaviour | 1 |
| Precompute features for a larger sweep grid | 1 |
| Rank multiple runs programmatically using the comparison table | 1 |
| Register all lookback variants before ledgr_run() in a parameter sweep | 1 |
| Run a basic sweep, select a candidate, and promote it | 1 |
| Run a strategy with only 10 bars of data | 1 |
| Run the README example | 1 |
| Run two variants and compare results | 1 |
| Sweep indicator parameters using a feature factory | 1 |
| Sweep on a train snapshot and evaluate the selected candidate out of sample | 1 |
| Trigger and interpret strategy helper error messages | 1 |
| Understand the backtest object lifecycle and close() behaviour | 1 |
| Use the strategy helper pipeline from documentation | 1 |
| Verify seed propagation and inspect promotion context | 1 |
| Verify that raw strategy logic and the helper pipeline produce the same results | 1 |
| Verify the Sharpe ratio metric and risk-free-rate parameter | 1 |

### Difficulty

| difficulty | episodes |
| --- | --- |
| straightforward | 32 |
| challenging | 7 |
| medium | 3 |
| easy | 1 |
| hard | 1 |

## Duplicate Candidates

These are deterministic suggestions only. auditr does not merge findings.

| normalized_title | feedback_ids | titles | episode_ids | n |
| --- | --- | --- | --- | --- |
| result inspection help examples do not produce a closed trade | 2026-05-15_013_trades_fills_and_metrics/FB-001; 2026-05-15_020_metrics_and_accounting_article/FB-001 | Result-inspection help examples do not produce a closed trade | 2026-05-15_013_trades_fills_and_metrics; 2026-05-15_020_metrics_and_accounting_article | 2 |

## Documentation Provenance

- feedback rows missing source_docs: 0
- documentation discovery friction rows: 108

### High-Severity Rows Missing Source Context

| episode_id | feedback_id | title | severity |
| --- | --- | --- | --- |

### Repeated Source Docs

| source_doc | items |
| --- | --- |
| TASK.md | 36 |
| LEDGR_DOCS/indicators.md | 22 |
| LEDGR_DOCS/strategy-development.md | 19 |
| ?ledgr_run | 15 |
| LEDGR_DOCS/sweeps.md | 14 |
| LEDGR_DOCS/experiment-store.md | 13 |
| ?summary.ledgr_backtest | 10 |
| LEDGR_DOCS/metrics-and-accounting.md | 10 |
| ?ledgr_results | 9 |
| LEDGR_DOCS/getting-started.md | 8 |
| LEDGR_DOCS/custom-indicators.md | 7 |
| ?ledgr_compute_metrics | 6 |
| ?ledgr_sweep | 6 |
| episode_environment | 6 |
| ?ledgr_compare_runs | 5 |
| ?ledgr_snapshot_seal | 5 |
| ?signal_return | 5 |
| ?ledgr_backtest | 4 |
| ?ledgr_feature_contract_check | 4 |
| ?ledgr_feature_contracts | 4 |
| ?ledgr_pulse_features | 4 |
| ?ledgr_pulse_snapshot | 4 |
| ?ledgr_snapshot_info | 4 |
| ?select_top_n | 4 |
| ?target_rebalance | 4 |
| ?ledgr_indicator | 3 |
| ?ledgr_precompute_features | 3 |
| ?ledgr_promote | 3 |
| ?ledgr_snapshot_import_bars_csv | 3 |
| LEDGR_DOCS/index.md | 3 |
| LEDGR_DOCS/reproducibility.md | 3 |
| LEDGR_DOCS/scripts/sweeps.R | 3 |
| ?close.ledgr_backtest | 2 |
| ?ledgr_experiment | 2 |
| ?ledgr_extract_strategy | 2 |
| ?ledgr_feature_id | 2 |
| ?ledgr_ind_rsi | 2 |
| ?ledgr_snapshot_create | 2 |
| ?ledgr_snapshot_from_csv | 2 |
| ?ledgr_strategy_context | 2 |
| AGENT_PROMPT.md | 2 |
| LEDGR_DOCS/leakage.md | 2 |
| raw_logs/ledgr_doc_snapshot.md | 2 |
| ?as_tibble.ledgr_backtest | 1 |
| ?ledgr-package | 1 |
| ?ledgr_candidate | 1 |
| ?ledgr_feature_map | 1 |
| ?ledgr_ind_sma | 1 |
| ?ledgr_ind_ttr | 1 |
| ?ledgr_promotion_context | 1 |
| ?ledgr_pulse_wide | 1 |
| ?ledgr_run_info | 1 |
| ?ledgr_run_promotion_context | 1 |
| ?ledgr_signal | 1 |
| ?ledgr_signal_strategy | 1 |
| ?ledgr_sim_bars | 1 |
| ?ledgr_snapshot_from_df | 1 |
| ?ledgr_snapshot_from_yahoo | 1 |
| ?ledgr_strategy_preflight | 1 |
| ?ledgr_weights | 1 |
| ?passed_warmup | 1 |
| ?print.ledgr_precomputed_features | 1 |
| ?weight_equal | 1 |
| C:/Users/maxth/AppData/Local/R/win-library/4.5/ledgr/examples/README.md | 1 |
| DOC_DISCOVERY.R | 1 |
| LEDGR_DOCS/scripts/custom-indicators.R | 1 |
| LEDGR_DOCS/scripts/strategy-development.R | 1 |

### Discovery Friction Evidence

| source | episode_id | evidence |
| --- | --- | --- |
| feedback_summary | 2026-05-15_001_cold_start_readme | Installed package lacks a runnable README-style overview |
| feedback_summary | 2026-05-15_001_cold_start_readme | Minimal ledgr_run example does not print a smoke-test confirmation |
| feedback_summary | 2026-05-15_001_cold_start_readme | Closed-trade terminology is easy to miss in first-run output |
| feedback_summary | 2026-05-15_002_cold_start_getting_started | Getting-started version context is ambiguous under ledgr 0.1.8 |
| feedback_summary | 2026-05-15_003_single_asset_sma_crossover | SMA crossover docs stop short of a complete runnable strategy |
| feedback_summary | 2026-05-15_003_single_asset_sma_crossover | print(summary(bt)) prints both summary and backtest handle |
| feedback_summary | 2026-05-15_003_single_asset_sma_crossover | Signal terminology is easy to over-apply to simple feature rules |
| feedback_summary | 2026-05-15_004_multi_asset_momentum | summary return value is surprising when printed explicitly |
| feedback_summary | 2026-05-15_005_rsi_mean_reversion | Indicator function signature differs between custom indicator docs and built-in RSI object |
| feedback_summary | 2026-05-15_005_rsi_mean_reversion | Native RSI help page lacks feature ID and warmup contract context |
| feedback_summary | 2026-05-15_006_bbands_macd | ledgr_ind_ttr help does not show rendered MACD feature IDs |
| feedback_summary | 2026-05-15_006_bbands_macd | Long multi-output feature IDs are truncated in pulse inspection output |
| feedback_summary | 2026-05-15_008_snapshot_csv_seal_backtest | Explicit CSV seal workflow is buried behind experiment-store docs |
| feedback_summary | 2026-05-15_008_snapshot_csv_seal_backtest | ledgr_snapshot_info usage omits the one-argument snapshot form |
| feedback_summary | 2026-05-15_009_edge_case_ten_bars | ledgr_pulse_features list input failure is easy to hit from getting-started examples |
| feedback_summary | 2026-05-15_010_strategy_development_article | Strategy article does not contain the requested suppressWarnings example |
| feedback_summary | 2026-05-15_010_strategy_development_article | What Next points first-time users to an installed source-tree design file |
| feedback_summary | 2026-05-15_011_strategy_helper_introduction | Task names helpers while asking user to discover them |
| feedback_summary | 2026-05-15_011_strategy_helper_introduction | Individual helper help pages are isolated from the full experiment setup |
| feedback_summary | 2026-05-15_012_multi_asset_rotation_with_helpers | Strategy helper docs do not show a synthetic three-asset rotation example |
| feedback_summary | 2026-05-15_012_multi_asset_rotation_with_helpers | Synthetic bar helper is not surfaced from the strategy-helper path |
| feedback_summary | 2026-05-15_013_trades_fills_and_metrics | Result-inspection help examples do not produce a closed trade |
| feedback_summary | 2026-05-15_014_close_lifecycle | Closed backtest result access semantics are inconsistent across docs |
| feedback_summary | 2026-05-15_014_close_lifecycle | close() examples use compatibility workflow instead of primary experiment workflow |
| feedback_summary | 2026-05-15_015_warmup_and_na_in_helpers | Warmup pulse docs do not warn that every universe member still needs a current bar |
| feedback_summary | 2026-05-15_015_warmup_and_na_in_helpers | Partial-warmup inspection example runs into full-backtest coverage rules |
| feedback_summary | 2026-05-15_016_helper_type_errors | target_rebalance help omits out-of-universe weight validation |
| feedback_summary | 2026-05-15_016_helper_type_errors | ledgr_run help lacks a compact invalid helper return example |
| feedback_summary | 2026-05-15_016_helper_type_errors | No single troubleshooting table for helper-pipeline error messages |
| feedback_summary | 2026-05-15_017_parametric_helper_comparison | Helper comparison example does not show changing lookback parameters |
| feedback_summary | 2026-05-15_017_parametric_helper_comparison | Comparison print output obscures raw numeric metric types |
| feedback_summary | 2026-05-15_019_zero_trade_diagnosis | Empty-selection warning expectation conflicts with installed behavior |
| feedback_summary | 2026-05-15_019_zero_trade_diagnosis | Pulse feature inspection is narrower than experiment feature registration |
| feedback_summary | 2026-05-15_020_metrics_and_accounting_article | Result-inspection help examples do not produce a closed trade |
| feedback_summary | 2026-05-15_020_metrics_and_accounting_article | Help pages mention v0.1.7 in a v0.1.8 installation |
| feedback_summary | 2026-05-15_021_indicators_article | Indicators article shows LEDGR_LAST_BAR_NO_FILL but does not explain it |
| feedback_summary | 2026-05-15_021_indicators_article | First finite warmup verification requires custom pulse-loop code |
| feedback_summary | 2026-05-15_021_indicators_article | UTF-8 BOM in temporary R helper script caused a parse failure |
| feedback_summary | 2026-05-15_022_help_page_discoverability | Article links are discoverable but not gathered in a single help index |
| feedback_summary | 2026-05-15_022_help_page_discoverability | Last-bar no-fill warning is terse when vignette examples are run as a script |
| feedback_summary | 2026-05-15_024_pulse_inspection_views | Pulse inspection help examples are not runnable in isolation |
| feedback_summary | 2026-05-15_024_pulse_inspection_views | `ledgr_pulse_snapshot()` help understates accepted feature shapes |
| feedback_summary | 2026-05-15_025_low_level_csv_snapshot_seal_run | Seal metadata names differ between narrative and info columns |
| feedback_summary | 2026-05-15_025_low_level_csv_snapshot_seal_run | Active raw log files can make recursive text search fail |
| feedback_summary | 2026-05-15_026_warmup_diagnostic_and_three_cases | ledgr_backtest feature shape is unclear for feature maps |
| feedback_summary | 2026-05-15_026_warmup_diagnostic_and_three_cases | Warmup Diagnostics omits stable_after wording |
| feedback_summary | 2026-05-15_026_warmup_diagnostic_and_three_cases | Current-bar absence lacks a minimal reproducible example |
| feedback_summary | 2026-05-15_026_warmup_diagnostic_and_three_cases | PowerShell UTF-8 BOM caused R parse failure |
| feedback_summary | 2026-05-15_027_ledger_events_and_metrics_error | Ledger docs do not explicitly resolve portfolio state update rows |
| feedback_summary | 2026-05-15_028_snapshot_info_metadata_columns | meta_json schema is not documented field by field |
| feedback_summary | 2026-05-15_028_snapshot_info_metadata_columns | Snapshot help topic version labels look older than installed ledgr |
| feedback_summary | 2026-05-15_029_mixed_builtin_ttr_feature_map | ledgr_run params docs do not explicitly call out non-finite numeric rejection |
| feedback_summary | 2026-05-15_030_multi_lookback_pre_registration | Alias versus engine ID distinction is easy to miss in parameterized lookup |
| feedback_summary | 2026-05-15_030_multi_lookback_pre_registration | Sweep documentation can distract from ledgr_run pre-registration task |
| feedback_summary | 2026-05-15_031_ctx_features_discoverability | Feature-map help lacks See Also links for related strategy accessors |
| feedback_summary | 2026-05-15_032_yahoo_five_strategies | Strategy preflight rejects ordinary external helper functions |
| feedback_summary | 2026-05-15_032_yahoo_five_strategies | Yahoo snapshot is already sealed but task still required explicit seal |
| feedback_summary | 2026-05-15_032_yahoo_five_strategies | Feature contracts alone do not confirm snapshot warmup feasibility |
| feedback_summary | 2026-05-15_033_strategy_extraction_and_recovery | Extraction help does not state missing-run error class |
| feedback_summary | 2026-05-15_033_strategy_extraction_and_recovery | Trusted recovery rerun example is not executable end-to-end |
| feedback_summary | 2026-05-15_034_sharpe_ratio_and_risk_metrics | Manual Sharpe recomputation needs a public annualization constant |
| feedback_summary | 2026-05-15_034_sharpe_ratio_and_risk_metrics | Summary output does not identify a nonzero risk-free rate |
| feedback_summary | 2026-05-15_035_comparison_programmatic_ranking | Raw comparison example still prints metric columns as character percentages |
| feedback_summary | 2026-05-15_035_comparison_programmatic_ranking | Max drawdown sort direction is easy to reverse |
| feedback_summary | 2026-05-15_035_comparison_programmatic_ranking | Curated comparison print view hides several standard metric columns |
| feedback_summary | 2026-05-15_036_strategy_preflight_and_tier_classification | Tier 3 run error implies a default override may exist |
| feedback_summary | 2026-05-15_037_leakage_diagnosis_and_series_fn_boundary | Leakage article warns about full-sample quantiles but does not show an end-to-end ledgr run |
| feedback_summary | 2026-05-15_037_leakage_diagnosis_and_series_fn_boundary | Replacing a feature definition with the same ID requires registry cleanup not shown in experiment docs |
| feedback_summary | 2026-05-15_037_leakage_diagnosis_and_series_fn_boundary | No public validator proves causal correctness of a vectorized series_fn |
| feedback_summary | 2026-05-15_037_leakage_diagnosis_and_series_fn_boundary | Help snapshot filenames were easy to guess incorrectly |
| feedback_summary | 2026-05-15_038_custom_indicator_authoring | Persisted feature values are not exposed through ledgr_results |
| feedback_summary | 2026-05-15_038_custom_indicator_authoring | ledgr_indicator help understates the scalar fn signature |
| feedback_summary | 2026-05-15_038_custom_indicator_authoring | Live-object params errors are not illustrated in custom indicator docs |
| feedback_summary | 2026-05-15_038_custom_indicator_authoring | Runnable custom-indicators script omits the vectorized indicator path |
| feedback_summary | 2026-05-15_039_sweep_basic_candidate_promotion | Runnable sweeps vignette script contains no sweep workflow |
| feedback_summary | 2026-05-15_039_sweep_basic_candidate_promotion | Getting started vignette still says sweep execution is reserved for later versions |
| feedback_summary | 2026-05-15_039_sweep_basic_candidate_promotion | `ledgr_compute_metrics()` does not expose `final_equity` for sweep-row comparison |
| feedback_summary | 2026-05-15_040_sweep_train_test_discipline | Cross-snapshot promotion error does not name the required opt-in |
| feedback_summary | 2026-05-15_040_sweep_train_test_discipline | Listed runnable sweeps vignette script contains no runnable sweep workflow |
| feedback_summary | 2026-05-15_041_sweep_failure_rows | Sweep result export needs guidance for list columns |
| feedback_summary | 2026-05-15_041_sweep_failure_rows | Mixed failure sweep promotion example is missing |
| feedback_summary | 2026-05-15_041_sweep_failure_rows | stop_on_error class vector contains duplicate generic classes |
| feedback_summary | 2026-05-15_042_sweep_feature_factory | Static feature registration guidance conflicts with feature factories |
| feedback_summary | 2026-05-15_042_sweep_feature_factory | Per-candidate feature_set_hash behavior lacks an explicit example |
| feedback_summary | 2026-05-15_042_sweep_feature_factory | Precompute help example does not demonstrate feature factories |
| feedback_summary | 2026-05-15_043_sweep_precomputed_features | Print help omits precomputed payload fields |
| feedback_summary | 2026-05-15_044_sweep_seed_and_promotion_context | Sweeps runnable vignette script is empty |
| feedback_summary | 2026-05-15_044_sweep_seed_and_promotion_context | Promotion candidate_summary shape and fields are underspecified |
| feedback_summary | 2026-05-15_044_sweep_seed_and_promotion_context | No complete stochastic seed replay example |
| research_report | 2026-05-15_006_bbands_macd | - No ledgr API errors blocked the task. The only stderr content in the final run was ordinary package attach messages from `dplyr`. |
| research_report | 2026-05-15_010_strategy_development_article | Succeeded with documentation friction. The article workflow runs end to end and the class-specific `suppressWarnings()` mechanism works on this R version. However, the rendered `strategy-development` article does not contain the `suppressWarnings(..., classes = "ledgr_empty_selection")` example or `warn_empty = FALSE` note mentioned in `TASK.md`. The installed help instead documents `ledgr_empty_selection` as an object class returned without warning, while `ledgr_partial_selection` is the warning class. |
| research_report | 2026-05-15_011_strategy_helper_introduction | - No ledgr runtime failure blocked the task. |
| research_report | 2026-05-15_012_multi_asset_rotation_with_helpers | The run emitted `LEDGR_LAST_BAR_NO_FILL` warnings. This did not block completion because the documentation explains that next-open fills cannot execute target changes emitted on the final pulse, and the result tables contained fills and closed trades. \| No code-level ledgr failure blocked the task. The main iteration was documentation assembly: |
| research_report | 2026-05-15_017_parametric_helper_comparison | - No ledgr runtime failure blocked the task. |
| research_report | 2026-05-15_020_metrics_and_accounting_article | No ledgr runtime failures occurred. One documentation friction point came from |
| research_report | 2026-05-15_021_indicators_article | - My first helper script for saving help topics failed because PowerShell `Set-Content -Encoding UTF8` wrote a BOM. R failed with `Error: unexpected input in "﻿"`. I recreated the helper with `apply_patch` and reran it successfully. Evidence: `raw_logs/save_help_topics_stderr.txt` and `raw_logs/save_help_topics_retry_status.json`. |
| research_report | 2026-05-15_023_feature_map_strategy_authoring | No failed ledgr API attempts were needed. I avoided PowerShell `$` quoting |
| research_report | 2026-05-15_024_pulse_inspection_views | No runtime debugging iterations were needed after following the rendered indicators vignette. The main friction was documentation discoverability from individual help pages: `?ledgr_pulse_features` and `?ledgr_pulse_wide` have very short examples that depend on previously-created `pulse` and `features` objects, so they are not runnable in isolation. `?ledgr_pulse_snapshot` supplies a runnable setup and was needed to bridge that gap. A smaller argument-documentation mismatch also appeared: `?ledgr_pulse_snapshot` says `features` is a list, while the vignette demonstrates that a feature map is also accepted. |
| research_report | 2026-05-15_025_low_level_csv_snapshot_seal_run | - `rg` over `raw_logs/` encountered locked active Codex log files and returned Windows `os error 32`; this was environment friction, not a ledgr API failure. \| - The only minor ledgr documentation friction was terminology: seal documentation discusses `n_bars` and `n_instruments`, while the structured `ledgr_snapshot_info()` columns expose `bar_count` and `instrument_count`; the `n_*` names are visible only inside `meta_json`. |
| research_report | 2026-05-15_026_warmup_diagnostic_and_three_cases | 1. My first doc discovery helper script failed before R parsing because PowerShell `Set-Content -Encoding UTF8` wrote a UTF-8 BOM. Evidence: `raw_logs/doc_discovery_stderr.txt`. I rewrote the helper script without the BOM and reran successfully as `raw_logs/doc_discovery_retry_status.json`. |
| research_report | 2026-05-15_027_ledger_events_and_metrics_error | No shell quoting workaround was needed because multiline R code stayed in |
| research_report | 2026-05-15_034_sharpe_ratio_and_risk_metrics | The task was not blocked. Two documentation/API friction items are recorded in `framework_feedback.md`: |
| research_report | 2026-05-15_035_comparison_programmatic_ranking | No blocked debugging loop was needed. The first complete workflow ran |
| research_report | 2026-05-15_036_strategy_preflight_and_tier_classification | Classify three ledgr strategy functions with `ledgr_strategy_preflight()`, inspect the preflight result fields, attempt to run a Tier 3 strategy through `ledgr_run()` via `ledgr_experiment()`, verify no run artifact is written for the blocked Tier 3 attempt, and confirm that a Tier 1 strategy runs and stores a matching reproducibility level. \| For execution testing, I built one sealed snapshot from `ledgr_demo_bars`, created a Tier 3 experiment, checked `ledgr_run_list(snapshot)`, attempted `ledgr_run()` with run ID `tier_3_blocked`, captured the error object, and checked `ledgr_run_list(snapshot)` again. Then I created a Tier 1 experiment on the same snapshot, ran it with run ID `tier_1_allowed`, and inspected `ledgr_run_info(snapshot, "tier_1_allowed")`. \| The documentation was sufficient to predict the three preflight classifications and the Tier 3 run failure. `LEDGR_DOCS/reproducibility.md` gave direct examples for all three tiers and stated that Tier 3 strategies fail before execution. `?ledgr_strategy_preflight` documented the result fields and the tier meanings. `?ledgr_run_info` documented the stored `reproducibility_level` field. |
| research_report | 2026-05-15_038_custom_indicator_authoring | 1. A PowerShell `Select-String` search failed because my regex for `ctx$...` |
| research_report | 2026-05-15_040_sweep_train_test_discipline | evaluated the locked parameters on the held-out test snapshot. \| - train same-snapshot promoted run: `momentum_locked_train` \| - held-out promoted run: `momentum_locked_test` |
| research_report | 2026-05-15_042_sweep_feature_factory | The main implementation attempt ran successfully. The only friction was documentation interpretation: |
| research_report | 2026-05-15_044_sweep_seed_and_promotion_context | The main friction was that the rendered sweeps vignette had the conceptual workflow, but the listed `LEDGR_DOCS/scripts/sweeps.R` file contained only the auditr wrapper comments/setup marker and no runnable sweep example. Also, the promotion context documentation described `candidate_summary` as a "view" but did not specify the returned object shape or fields; in practice it was a list of compact records, not a tibble/data-frame-like object. |

## Agent And Harness Performance

### Runner Types

| runner_type | episodes |
| --- | --- |
| codex | 44 |

### Runner Models

| runner_model | episodes |
| --- | --- |
| (blank) | 44 |

### Runner Exit Status

| runner_exit_status | episodes |
| --- | --- |
| 0 | 44 |

### Check Status

| check_status | episodes |
| --- | --- |
| (blank) | 44 |

## Prompt And Task Quality

- Review repeated duplicate candidates, missing source_docs rows, and
  documentation discovery friction before choosing the next task theme.
- Confirm whether task briefs were too broad, too narrow, or missing
  constraints before promoting generated follow-up tasks.

## Next-Cycle Theme Candidates

- Feature, indicator, and warmup contracts need clearer user-facing guidance
- Runnable first-run and vignette examples are incomplete or misleading
- Result inspection, metrics, and comparison outputs obscure schemas or numeric types
- Strategy helper pipeline docs lack troubleshooting and complete setup paths
- Sweep, promotion, precompute, and seed workflows are present but underspecified

## Maintainer Notes

- TODO: Record final duplicate decisions.
- TODO: Record which ledgr fixes, docs, or tests should be prioritized.
- TODO: Choose the next cycle theme.
