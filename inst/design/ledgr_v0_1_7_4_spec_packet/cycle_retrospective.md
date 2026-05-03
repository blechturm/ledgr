# auditr Cycle Retrospective

Source: `C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.7.3`

This is a maintainer-review artifact. It does not create GitHub issues,
does not execute ledgr workflows, and does not decide final defect truth.

## Status

- episodes: 22
- feedback rows: 98
- categorized feedback: valid
- partial retrospective: no

Warnings:
- Feedback summary CSVs are missing or invalid; retrospective data may be incomplete.

## Feedback Counts

### Type

| type | items |
| --- | --- |
| documentation_gap | 57 |
| ux_friction | 33 |
| unclear_error | 5 |
| bug | 3 |

### Triage

| triage | items |
| --- | --- |
| unclear | 98 |

### Severity

| severity | items |
| --- | --- |
| (blank) | 71 |
| low | 22 |
| medium | 5 |

## Task Coverage

### Task Titles

| task_title | episodes |
| --- | --- |
| Build a multi-asset rotation strategy using strategy helpers | 1 |
| Build a single-asset SMA crossover strategy | 1 |
| Build a two-asset momentum strategy | 1 |
| Build an RSI mean-reversion strategy | 1 |
| Combine Bollinger Bands and MACD indicators | 1 |
| Compare two helper-pipeline variants with different parameters | 1 |
| Diagnose a strategy that runs without error but produces no trades | 1 |
| Discover installed articles from function-level help pages | 1 |
| Follow the getting-started vignette | 1 |
| Follow the indicators article end to end | 1 |
| Follow the metrics-and-accounting article and verify metrics by hand | 1 |
| Follow the strategy-development article end to end | 1 |
| Handle warmup periods and missing values in a helper pipeline strategy | 1 |
| Import CSV data, seal it, and run a backtest | 1 |
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
| straightforward | 17 |
| challenging | 5 |

## Duplicate Candidates

These are deterministic suggestions only. auditr does not merge findings.

| normalized_title | feedback_ids | titles | episode_ids | n |
| --- | --- | --- | --- | --- |
| status | 2026-05-03_003_single_asset_sma_crossover/MD-001; 2026-05-03_004_multi_asset_momentum/MD-001; 2026-05-03_011_strategy_helper_introduction/MD-001; 2026-05-03_012_multi_asset_rotation_with_helpers/MD-001; 2026-05-03_017_parametric_helper_comparison/MD-001 | Status | 2026-05-03_003_single_asset_sma_crossover; 2026-05-03_004_multi_asset_momentum; 2026-05-03_011_strategy_helper_introduction; 2026-05-03_012_multi_asset_rotation_with_helpers; 2026-05-03_017_parametric_helper_comparison | 5 |
| outcome | 2026-05-03_001_cold_start_readme/MD-004; 2026-05-03_008_snapshot_csv_seal_backtest/MD-001 | Outcome | 2026-05-03_001_cold_start_readme; 2026-05-03_008_snapshot_csv_seal_backtest | 2 |
| resolved workarounds | 2026-05-03_004_multi_asset_momentum/MD-002; 2026-05-03_018_manual_vs_helper_parity/MD-003 | Resolved workarounds | 2026-05-03_004_multi_asset_momentum; 2026-05-03_018_manual_vs_helper_parity | 2 |
| workarounds used | 2026-05-03_011_strategy_helper_introduction/MD-003; 2026-05-03_015_warmup_and_na_in_helpers/MD-003 | Workarounds used | 2026-05-03_011_strategy_helper_introduction; 2026-05-03_015_warmup_and_na_in_helpers | 2 |

## Documentation Provenance

- feedback rows missing source_docs: 98
- documentation discovery friction rows: 43

### High-Severity Rows Missing Source Context

| episode_id | feedback_id | title | severity |
| --- | --- | --- | --- |

### Repeated Source Docs

| source_doc | items |
| --- | --- |

### Discovery Friction Evidence

| source | episode_id | evidence |
| --- | --- | --- |
| feedback_summary | 2026-05-03_001_cold_start_readme | Installed README path is not a runnable first example |
| feedback_summary | 2026-05-03_002_cold_start_getting_started | Discovery helper default failed on `n = Inf` |
| feedback_summary | 2026-05-03_005_rsi_mean_reversion | `ledgr_save_doc()` default failed |
| feedback_summary | 2026-05-03_006_bbands_macd | Documentation discovery helper failed with `n = Inf` |
| feedback_summary | 2026-05-03_007_experiment_store_compare | F-001: Documentation helper cannot read all vignette lines with `n = Inf` |
| feedback_summary | 2026-05-03_012_multi_asset_rotation_with_helpers | ledgr issues, UX friction, and documentation gaps |
| feedback_summary | 2026-05-03_014_close_lifecycle | F-004: Documentation discovery helper default failed for vignettes |
| feedback_summary | 2026-05-03_016_helper_type_errors | Documentation discovery friction: `ledgr_read_vignette()` default |
| feedback_summary | 2026-05-03_017_parametric_helper_comparison | `ledgr_read_vignette()` default failed |
| feedback_summary | 2026-05-03_017_parametric_helper_comparison | Helper functions are less discoverable in the snapshot help list |
| feedback_summary | 2026-05-03_018_manual_vs_helper_parity | Bugs or behavior issues |
| feedback_summary | 2026-05-03_019_zero_trade_diagnosis |  |
| feedback_summary | 2026-05-03_020_metrics_and_accounting_article | Hidden helper in the vignette source |
| feedback_summary | 2026-05-03_020_metrics_and_accounting_article | Episode tooling friction |
| feedback_summary | 2026-05-03_021_indicators_article | `ledgr_save_doc()` failed with default `n = Inf` path |
| feedback_summary | 2026-05-03_021_indicators_article | `ledgr_save_doc("indicators.Rmd", ...)` was the wrong helper path |
| feedback_summary | 2026-05-03_022_help_page_discoverability |  |
| feedback_summary | 2026-05-03_022_help_page_discoverability |  |
| feedback_summary | 2026-05-03_022_help_page_discoverability |  |
| feedback_summary | 2026-05-03_022_help_page_discoverability |  |
| feedback_summary | 2026-05-03_022_help_page_discoverability |  |
| research_report | 2026-05-03_001_cold_start_readme | 2. `DOC_DISCOVERY.R`, then `ledgr_write_doc_snapshot()` \| 6. Installed vignette `getting-started`, via `ledgr_read_vignette("getting-started")` \| The installed `examples/README.md` was not executable and said the examples were non-executable development artifacts. The `ledgr-package` help page pointed to `vignette("getting-started", package = "ledgr")` as the first core installed article, so I used that as the package overview. |
| research_report | 2026-05-03_002_cold_start_getting_started | 2. `DOC_DISCOVERY.R` \| 7. `vignette(package = "ledgr")`, saved as \| - `ledgr_read_vignette("getting-started")` failed when called with its default |
| research_report | 2026-05-03_003_single_asset_sma_crossover | 2. `DOC_DISCOVERY.R`, then `ledgr_write_doc_snapshot()` \| 4. `vignette("getting-started", package = "ledgr")` \| 5. `vignette("strategy-development", package = "ledgr")` |
| research_report | 2026-05-03_004_multi_asset_momentum | 3. `DOC_DISCOVERY.R`, then `ledgr_write_doc_snapshot()`. \| 5. `vignette("getting-started", package = "ledgr")` via `ledgr_read_vignette("getting-started", n = 220)`. \| 6. `vignette("strategy-development", package = "ledgr")` via `ledgr_read_vignette("strategy-development", n = 600)`. |
| research_report | 2026-05-03_005_rsi_mean_reversion | 2. `DOC_DISCOVERY.R`, then `ledgr_write_doc_snapshot()`. \| using `ledgr_read_vignette(..., n = <bounded number>)` and writing bounded |
| research_report | 2026-05-03_006_bbands_macd | 2. `DOC_DISCOVERY.R`, then `ledgr_write_doc_snapshot()` \| These match the examples and prose in `?ledgr_ind_ttr` and `vignette("indicators", package = "ledgr")`. \| - The documentation helper `ledgr_read_vignette(..., n = Inf)` failed because `readLines()` rejected infinite `n`; rerunning with a large finite line count worked. |
| research_report | 2026-05-03_007_experiment_store_compare | 2. `DOC_DISCOVERY.R`, sourced before ledgr documentation search \| 4. `ledgr_read_vignette("experiment-store", n = 220)` \| - `ledgr_read_vignette("experiment-store", n = Inf)` failed because the helper |
| research_report | 2026-05-03_008_snapshot_csv_seal_backtest | 2. `raw_logs/ledgr_doc_snapshot.md`, generated by sourcing `DOC_DISCOVERY.R` and running `ledgr_write_doc_snapshot()`. |
| research_report | 2026-05-03_009_edge_case_ten_bars | 2. `DOC_DISCOVERY.R`, then `ledgr_write_doc_snapshot()` \| 4. `ledgr_read_vignette("getting-started", n = 160)` \| 5. `ledgr_read_vignette("strategy-development", n = 180)`, then local installed vignette lines around the experiment/run sections |
| research_report | 2026-05-03_010_strategy_development_article | 3. `DOC_DISCOVERY.R`, then `ledgr_write_doc_snapshot()` \| 5. Installed vignette `strategy-development`, read with `ledgr_read_vignette("strategy-development", n = 10000)` \| - My first attempt to source `DOC_DISCOVERY.R` used `. .\DOC_DISCOVERY.R`, which is PowerShell syntax and failed in R. Using `source("DOC_DISCOVERY.R")` worked. |
| research_report | 2026-05-03_011_strategy_helper_introduction | 3. `DOC_DISCOVERY.R`, then `ledgr_write_doc_snapshot()`. |
| research_report | 2026-05-03_012_multi_asset_rotation_with_helpers | 3. `DOC_DISCOVERY.R`, then `ledgr_write_doc_snapshot()`. \| 5. `vignette("strategy-development", package = "ledgr")`, especially the \| 6. `vignette("indicators", package = "ledgr")`, especially feature IDs and |
| research_report | 2026-05-03_013_trades_fills_and_metrics | 3. `DOC_DISCOVERY.R`, followed by `ledgr_write_doc_snapshot()`; output saved at `raw_logs/ledgr_doc_snapshot.md`. |
| research_report | 2026-05-03_014_close_lifecycle | 2. `DOC_DISCOVERY.R`, then `ledgr_write_doc_snapshot()` \| - Documentation discovery friction: calling `ledgr_read_vignette()` without an |
| research_report | 2026-05-03_015_warmup_and_na_in_helpers | 3. `DOC_DISCOVERY.R`, then `ledgr_write_doc_snapshot()`, generating |
| research_report | 2026-05-03_016_helper_type_errors | 3. `DOC_DISCOVERY.R`, then `ledgr_write_doc_snapshot()`. \| 5. `vignette("strategy-development", package = "ledgr")` via \| `ledgr_read_vignette("strategy-development", n = 220)` and bounded follow-up |
| research_report | 2026-05-03_017_parametric_helper_comparison | 3. `DOC_DISCOVERY.R`, then `ledgr_write_doc_snapshot()`. \| - `ledgr_read_vignette()` failed with its default `n = Inf` because `readLines()` rejected an infinite line count in this R session. Workaround: call `ledgr_read_vignette(..., n = 10000)`. |
| research_report | 2026-05-03_018_manual_vs_helper_parity | 3. `DOC_DISCOVERY.R`, then `ledgr_write_doc_snapshot()`. |
| research_report | 2026-05-03_019_zero_trade_diagnosis | 3. `DOC_DISCOVERY.R`, then `ledgr_write_doc_snapshot()`. \| 5. `vignette("metrics-and-accounting", package = "ledgr")`, especially \| 6. `vignette("strategy-development", package = "ledgr")`, especially the |
| research_report | 2026-05-03_020_metrics_and_accounting_article | 2. `DOC_DISCOVERY.R` \| 1. `ledgr_read_vignette("metrics-and-accounting")` failed with `vector size cannot be infinite` because the helper default passes `n = Inf` to `readLines()`. Workaround: rerun with `n = 10000`. |
| research_report | 2026-05-03_021_indicators_article | 3. `DOC_DISCOVERY.R`, then `ledgr_write_doc_snapshot()`. \| `ledgr_read_vignette("indicators", n = 5000)`. \| `vector size cannot be infinite`. Retrying with `ledgr_read_vignette("indicators", |
| research_report | 2026-05-03_022_help_page_discoverability | without using `vignette(package = "ledgr")` or a browser before finding at \| 3. `DOC_DISCOVERY.R`, then `ledgr_write_doc_snapshot()`; snapshot written to \| 13. After article names were discovered from help, `vignette(package = "ledgr")` |

## Agent And Harness Performance

### Runner Types

| runner_type | episodes |
| --- | --- |
| codex | 22 |

### Runner Models

| runner_model | episodes |
| --- | --- |
| (blank) | 22 |

### Runner Exit Status

| runner_exit_status | episodes |
| --- | --- |
| 0 | 22 |

### Check Status

| check_status | episodes |
| --- | --- |
| (blank) | 22 |

## Prompt And Task Quality

- Review repeated duplicate candidates, missing source_docs rows, and
  documentation discovery friction before choosing the next task theme.
- Confirm whether task briefs were too broad, too narrow, or missing
  constraints before promoting generated follow-up tasks.

## Next-Cycle Theme Candidates

- Episode doc-discovery helpers fail on n = Inf
- Strategy helper pages are discoverable only after reaching the vignette
- Feature ID naming and registration create recurring first-use friction
- Short-data, warmup, and final-bar behavior need a diagnosis recipe
- TTR and multi-output indicator APIs need stronger examples

## Maintainer Notes

- TODO: Record final duplicate decisions.
- TODO: Record which ledgr fixes, docs, or tests should be prioritized.
- TODO: Choose the next cycle theme.
