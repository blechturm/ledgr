# auditr Cycle Retrospective

Source: `C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.8.11`

This is a maintainer-review artifact. It does not create GitHub issues,
does not execute ledgr workflows, and does not decide final defect truth.


## Status

- episodes: 46
- feedback rows: 133
- feedback summary valid: yes
- categorized feedback: valid
- partial retrospective: no

## Feedback Counts

### Type

| type | items |
| --- | --- |
| documentation_gap | 94 |
| ux_friction | 31 |
| unclear_error | 8 |

### Triage

| triage | items |
| --- | --- |
| docs_gap | 94 |
| unclear | 25 |
| expected_user_error | 14 |

### Severity

| severity | items |
| --- | --- |
| low | 96 |
| medium | 32 |
| high | 5 |

## Task Coverage

### Task Titles

| task_title | episodes |
| --- | --- |
| Author scalar and vectorized custom indicators from documentation | 1 |
| B2 spot-FIFO sweep opt-in parity | 1 |
| Build a parameterized feature map with ledgr_param and run it end to end | 1 |
| Build a strategy using feature maps and the mapped accessor | 1 |
| Canonical JSON v2 hash stability | 1 |
| compiled_accounting_model fail-closed boundaries | 1 |
| Compose feature and strategy grids into an executable grid for sweep | 1 |
| Construct and inspect the v0.1.8.2 metric context surface | 1 |
| Create, import, seal, and run from a CSV snapshot using the low-level path | 1 |
| Diagnose leakage in a vectorized feature and correct it | 1 |
| DISCLAIMER discoverability | 1 |
| Discover ctx$features() and passed_warmup() from ?ledgr_feature_map alone | 1 |
| Discover installed articles from function-level help pages | 1 |
| Exercise the LDG-2303 preflight contract additions | 1 |
| Fetch a Yahoo universe and sweep each strategy's hyperparameters end to end | 1 |
| Fetch real market data from Yahoo Finance and compare five strategies | 1 |
| Follow the first-contact workflow article | 1 |
| Follow the indicators article end to end | 1 |
| Follow the metrics-and-accounting article and verify metrics by hand | 1 |
| Follow the strategy-development article end to end | 1 |
| Hit each row of the helper pipeline troubleshooting table | 1 |
| Inspect a pulse with feature_params and alias-aware views | 1 |
| Inspect feature contracts and pulse data before running a backtest | 1 |
| Interpret ledgr_snapshot_info() metadata columns after sealing | 1 |
| Interpret the warmup diagnostic and distinguish the three warmup-adjacent failure modes | 1 |
| Matrix-canonical ctx accessor substrate | 1 |
| Observe sweep failure rows and stop_on_error behaviour | 1 |
| Parallel sweep discard-all interrupt | 1 |
| Parallel sweep parity and preflight dependency surface | 1 |
| Precompute features for a larger sweep grid | 1 |
| Probe alias identity hashing and declaration-order preservation | 1 |
| Probe the feature_params and params namespace split and its classed errors | 1 |
| Probe the static-analysis boundary of strategy preflight | 1 |
| pulse_seed determinism under sequential and parallel sweep | 1 |
| Real-data Yahoo workflow with explicit metric context across the full lifecycle | 1 |
| Run a basic sweep, select a candidate, and promote it | 1 |
| Run the README example | 1 |
| Sweep parameterized multi-output bundles and confirm alias and hash-suffix behavior | 1 |
| Trace one metric context across experiment, run, comparison, sweep, and promotion | 1 |
| Trigger adversarial CSV, indicator-bundle, and registration error paths | 1 |
| Trigger LEDGR_LAST_BAR_NO_FILL and verify the warning explains itself | 1 |
| Try to bypass strategy preflight and verify Tier 3 enforcement | 1 |
| Use the strategy helper pipeline from documentation | 1 |
| Verify seed propagation and inspect promotion context | 1 |
| Verify the Sharpe ratio metric and risk-free-rate parameter | 1 |
| Walk the Inspection Surfaces map and verify each surface answers its question | 1 |

### Difficulty

| difficulty | episodes |
| --- | --- |
| straightforward | 24 |
| challenging | 17 |
| "hard" | 2 |
| "medium" | 2 |
| blocked | 1 |

## Duplicate Candidates

These are deterministic suggestions only. auditr does not merge findings.

| normalized_title | feedback_ids | titles | episode_ids | n |
| --- | --- | --- | --- | --- |

## Documentation Provenance

- feedback rows missing source_docs: 0
- documentation discovery friction rows: 118

### High-Severity Rows Missing Source Context

| episode_id | feedback_id | title | severity |
| --- | --- | --- | --- |

### Repeated Source Docs

| source_doc | items |
| --- | --- |
| TASK.md | 63 |
| LEDGR_DOCS/sweeps.md | 37 |
| LEDGR_DOCS/indicators.md | 24 |
| ?ledgr_sweep | 19 |
| LEDGR_DOCS/strategy-development.md | 19 |
| ?ledgr_run | 15 |
| episode_environment | 14 |
| LEDGR_DOCS/metrics-and-accounting.md | 13 |
| ?ledgr_feature_map | 12 |
| LEDGR_DOCS/experiment-store.md | 11 |
| ?ledgr_strategy_context | 10 |
| ?ledgr_run_info | 9 |
| LEDGR_DOCS/custom-indicators.md | 9 |
| ?ledgr_pulse_snapshot | 8 |
| ?ledgr_strategy_preflight | 7 |
| ?ledgr_indicator | 6 |
| ?ledgr_param_grid | 6 |
| LEDGR_DOCS/reproducibility.md | 6 |
| raw_logs/ledgr_doc_snapshot.md | 6 |
| ?ledgr_metric_context | 5 |
| ?ledgr_results | 5 |
| DOC_DISCOVERY.R | 5 |
| ?ledgr_experiment | 4 |
| ?ledgr_feature_contracts | 4 |
| ?ledgr_feature_id | 4 |
| ?ledgr_precompute_features | 4 |
| ?ledgr_pulse_features | 4 |
| LEDGR_DOCS/research-workflow.md | 4 |
| ?ledgr-package | 3 |
| ?ledgr_backtest | 3 |
| ?ledgr_candidate | 3 |
| ?ledgr_compute_metrics | 3 |
| ?ledgr_feature_contract_check | 3 |
| ?ledgr_ind_ttr_outputs | 3 |
| ?ledgr_promote | 3 |
| ?ledgr_promotion_context | 3 |
| ?ledgr_snapshot_from_csv | 3 |
| ?ledgr_snapshot_from_yahoo | 3 |
| ?summary.ledgr_backtest | 3 |
| AGENT_PROMPT.md | 3 |
| LEDGR_DOCS/index.md | 3 |
| ?ledgr_candidate_reproduction_key | 2 |
| ?ledgr_deregister_indicator | 2 |
| ?ledgr_ind_ttr | 2 |
| ?ledgr_param | 2 |
| ?ledgr_pulse_wide | 2 |
| ?ledgr_run_promotion_context | 2 |
| ?ledgr_snapshot_import_bars_csv | 2 |
| ?select_top_n | 2 |
| ?ledgr | 1 |
| ?ledgr_calendar | 1 |
| ?ledgr_compare_runs | 1 |
| ?ledgr_feature_grid | 1 |
| ?ledgr_get_indicator | 1 |
| ?ledgr_grid_add_baseline | 1 |
| ?ledgr_grid_cross | 1 |
| ?ledgr_grid_named | 1 |
| ?ledgr_parameters | 1 |
| ?ledgr_register_indicator | 1 |
| ?ledgr_risk_free_rate | 1 |
| ?ledgr_run_open | 1 |
| ?ledgr_snapshot_info | 1 |
| ?ledgr_snapshot_load | 1 |
| ?ledgr_strategy_grid | 1 |
| ?passed_warmup | 1 |
| ?print.ledgr_precomputed_features | 1 |
| ?signal_return | 1 |
| ?target_rebalance | 1 |
| ?weight_equal | 1 |
| help(package = "ledgr") | 1 |
| LEDGR_DOCS/execution-semantics.md | 1 |
| LEDGR_DOCS/leakage.md | 1 |
| LEDGR_DOCS/scripts/sweeps.R | 1 |
| NEWS.md | 1 |
| raw_logs/reproducible_script_attempt1_stdout.txt | 1 |
| system.file("doc", "index.html", package = "ledgr") | 1 |
| system.file("doc", "research-workflow.html", package = "ledgr") | 1 |
| system.file("doc", "research-workflow.qmd", package = "ledgr") | 1 |
| system.file("doc", "strategy-development.html", package = "ledgr") | 1 |
| system.file("doc", "strategy-development.qmd", package = "ledgr") | 1 |
| vignette(package = "ledgr") | 1 |

### Discovery Friction Evidence

| source | episode_id | evidence |
| --- | --- | --- |
| feedback_summary | 2026-06-04_001_cold_start_readme | Installed package overview has no minimal runnable smoke example |
| feedback_summary | 2026-06-04_001_cold_start_readme | Package overview points to a pkgdown-only positioning article |
| feedback_summary | 2026-06-04_002_cold_start_getting_started | Docs index does not label the first-contact workflow |
| feedback_summary | 2026-06-04_003_strategy_development_article | Final-bar no-fill warning code is not exposed as a warning class |
| feedback_summary | 2026-06-04_004_strategy_helper_introduction | Helper discovery task names the answers |
| feedback_summary | 2026-06-04_004_strategy_helper_introduction | Individual helper help pages do not show the full pipeline |
| feedback_summary | 2026-06-04_006_indicators_article | No complete mixed built-in plus TTR scalar strategy example |
| feedback_summary | 2026-06-04_006_indicators_article | Scalar ctx$feature warmup guard pattern is implicit |
| feedback_summary | 2026-06-04_006_indicators_article | Indicators example final-bar warning lacks immediate local interpretation |
| feedback_summary | 2026-06-04_008_feature_map_strategy_authoring | ctx$features has no direct help topic |
| feedback_summary | 2026-06-04_008_feature_map_strategy_authoring | PowerShell UTF-8 BOM made helper script fail in R |
| feedback_summary | 2026-06-04_009_pulse_inspection_views | Feature-map pulse snapshots can make wide output alias-keyed |
| feedback_summary | 2026-06-04_009_pulse_inspection_views | Pulse view help examples are not standalone |
| feedback_summary | 2026-06-04_010_low_level_csv_snapshot_seal_run | Low-level CSV lifecycle lacks one seal-to-run example |
| feedback_summary | 2026-06-04_010_low_level_csv_snapshot_seal_run | Inline RUN_R -Expr commands are fragile with dollar signs and nested quotes |
| feedback_summary | 2026-06-04_011_warmup_diagnostic_and_three_cases | Feature maps are easy to pass to ledgr_backtest but are rejected |
| feedback_summary | 2026-06-04_011_warmup_diagnostic_and_three_cases | Current-bar absence lacks a minimal runnable example |
| feedback_summary | 2026-06-04_011_warmup_diagnostic_and_three_cases | Contract-check example can hide the key feasibility columns |
| feedback_summary | 2026-06-04_012_snapshot_info_metadata_columns | Snapshot info help leaves some returned columns under-described |
| feedback_summary | 2026-06-04_013_ctx_features_discoverability | Feature-map help should cross-reference strategy context accessors |
| feedback_summary | 2026-06-04_013_ctx_features_discoverability | PowerShell Set-Content can create BOM-prefixed temporary R scripts |
| feedback_summary | 2026-06-04_014_yahoo_five_strategies | Warmup feasibility wording points to the static contract helper |
| feedback_summary | 2026-06-04_014_yahoo_five_strategies | Yahoo multi-symbol fallback pattern is left to the user |
| feedback_summary | 2026-06-04_014_yahoo_five_strategies | Bollinger Band strategy requires inference from feature IDs |
| feedback_summary | 2026-06-04_015_sharpe_ratio_and_risk_metrics | risk_free_rate default is indirect in compute and summary help |
| feedback_summary | 2026-06-04_015_sharpe_ratio_and_risk_metrics | Sharpe NA edge-case rules are not exact in help |
| feedback_summary | 2026-06-04_016_leakage_diagnosis_and_series_fn_boundary | ledgr_indicator help disagrees with vignette on fn signature |
| feedback_summary | 2026-06-04_016_leakage_diagnosis_and_series_fn_boundary | PowerShell inline R expression expanded dollar-sign column access |
| feedback_summary | 2026-06-04_017_custom_indicator_authoring | No post-run feature result table despite persisted feature workflow |
| feedback_summary | 2026-06-04_017_custom_indicator_authoring | `?ledgr_indicator` documents the scalar function signature inconsistently |
| feedback_summary | 2026-06-04_018_sweep_basic_candidate_promotion | Doc snapshot task-intent map omits sweep-specific starting points |
| feedback_summary | 2026-06-04_018_sweep_basic_candidate_promotion | Basic named ledgr_param_grid() sweep example is not prominent |
| feedback_summary | 2026-06-04_019_sweep_failure_rows | Sweep diagnostic columns stay hidden after selection |
| feedback_summary | 2026-06-04_020_sweep_precomputed_features | No runnable sweep example for supported feature-factory flat grids |
| feedback_summary | 2026-06-04_020_sweep_precomputed_features | Precomputed payload print help does not describe printed fields |
| feedback_summary | 2026-06-04_020_sweep_precomputed_features | Documentation snapshot task-intent map lacks a sweep/precompute category |
| feedback_summary | 2026-06-04_020_sweep_precomputed_features | Broad raw_logs search can hit live locked runner logs |
| feedback_summary | 2026-06-04_021_sweep_seed_and_promotion_context | Sweeps vignette does not show all promotion-context access paths |
| feedback_summary | 2026-06-04_021_sweep_seed_and_promotion_context | Named sweep candidate guidance is split across old and new grid APIs |
| feedback_summary | 2026-06-04_021_sweep_seed_and_promotion_context | Flat named grid stores strategy params in feature_params_json |
| feedback_summary | 2026-06-04_021_sweep_seed_and_promotion_context | Candidate summary schema is not concrete enough for artifact checks |
| feedback_summary | 2026-06-04_021_sweep_seed_and_promotion_context | Documentation snapshot task-intent map omits sweep and promotion workflow |
| feedback_summary | 2026-06-04_021_sweep_seed_and_promotion_context | PowerShell rg glob failed for raw_logs help files |
| feedback_summary | 2026-06-04_022_yahoo_universe_sweep_per_strategy | Feature-factory sweeps lack a worked example |
| feedback_summary | 2026-06-04_022_yahoo_universe_sweep_per_strategy | Feature-set hash extraction is not shown |
| feedback_summary | 2026-06-04_022_yahoo_universe_sweep_per_strategy | Yahoo fallback workflow is not documented |
| feedback_summary | 2026-06-04_023_adversarial_preflight_and_force_override | Task brief says stats::median should be Tier 2, but ledgr classifies it as Tier 1 |
| feedback_summary | 2026-06-04_023_adversarial_preflight_and_force_override | Defined global scalar request conflicts with ledgr's captured-value Tier 2 rule |
| feedback_summary | 2026-06-04_024_adversarial_inputs_csv_bundle_registration | High-level CSV error classes are easy to confuse with low-level CSV import classes |
| feedback_summary | 2026-06-04_024_adversarial_inputs_csv_bundle_registration | No documented pattern to verify failed CSV imports leave no store artifacts |
| feedback_summary | 2026-06-04_024_adversarial_inputs_csv_bundle_registration | Registration duplicate error behavior is not described in the help example |
| feedback_summary | 2026-06-04_024_adversarial_inputs_csv_bundle_registration | CSV duplicate-row testing can be masked by chronology validation order |
| feedback_summary | 2026-06-04_025_final_bar_no_fill_warning | Warning code lacks a discoverable help topic |
| feedback_summary | 2026-06-04_026_inspection_surfaces_map | Inspection map omits ledgr_run_promotion_context argument shape |
| feedback_summary | 2026-06-04_026_inspection_surfaces_map | Inspection map names surfaces but not their required setup objects |
| feedback_summary | 2026-06-04_027_helper_pipeline_troubleshooting | Zero-fill troubleshooting table could include a minimal sizing-to-zero diagnostic |
| feedback_summary | 2026-06-04_027_helper_pipeline_troubleshooting | Searching raw_logs can hit locked Codex log files |
| feedback_summary | 2026-06-04_028_metric_context_constructors_and_templates | Metric context UX priority is implied rather than explicit |
| feedback_summary | 2026-06-04_029_metric_context_end_to_end_lifecycle | Missing runnable example for full metric-context lifecycle |
| feedback_summary | 2026-06-04_029_metric_context_end_to_end_lifecycle | Label placement for metric context is easy to get wrong |
| feedback_summary | 2026-06-04_029_metric_context_end_to_end_lifecycle | Full metric-context equality requires manual checks beyond hash equality |
| feedback_summary | 2026-06-04_030_adversarial_preflight_v0_1_8_2_additions | ledgr_run_info not-found condition is not documented |
| feedback_summary | 2026-06-04_031_yahoo_metric_context_end_to_end | Sweep results need an export-safe example |
| feedback_summary | 2026-06-04_032_adversarial_preflight_indirection_bypass | Tier 2 scalar acceptance is easy to miss after run success |
| feedback_summary | 2026-06-04_032_adversarial_preflight_indirection_bypass | Visible indirection coverage wording is ambiguous |
| feedback_summary | 2026-06-04_033_active_alias_end_to_end | Main strategy docs omit active-alias ctx$features(id) form |
| feedback_summary | 2026-06-04_033_active_alias_end_to_end | ledgr_feature_map help lacks parameterized feature-map example |
| feedback_summary | 2026-06-04_033_active_alias_end_to_end | bt$config stores strategy_params but not params |
| feedback_summary | 2026-06-04_033_active_alias_end_to_end | ledgr_feature_id help does not document unresolved parameterized error class |
| feedback_summary | 2026-06-04_034_two_namespace_contract_errors | No documented public path to build one malformed sweep candidate for diagnostics |
| feedback_summary | 2026-06-04_035_executable_grid_composition | Missing examples for mixing cross grids with baselines and named candidates |
| feedback_summary | 2026-06-04_035_executable_grid_composition | Candidate print and help understate feature params |
| feedback_summary | 2026-06-04_035_executable_grid_composition | Legacy flat-grid row shape is surprising with active aliases |
| feedback_summary | 2026-06-04_036_alias_aware_pulse_inspection | Parameterized pulse snapshot example is missing from indicators documentation |
| feedback_summary | 2026-06-04_036_alias_aware_pulse_inspection | Inline named alias-map shape lacks a pulse feature example |
| feedback_summary | 2026-06-04_036_alias_aware_pulse_inspection | Pulse active alias metadata fields are not listed in the pulse snapshot help value |
| feedback_summary | 2026-06-04_037_alias_identity_and_declaration_order | Alias hash fields are not documented in public help or vignettes |
| feedback_summary | 2026-06-04_037_alias_identity_and_declaration_order | Searching all raw_logs can hit locked runner log files |
| feedback_summary | 2026-06-04_038_parameterized_bundle_outputs_in_sweeps | Parameterized bundle hash suffix rule is not explained |
| feedback_summary | 2026-06-04_038_parameterized_bundle_outputs_in_sweeps | Task example omits required TTR bundle input argument |
| feedback_summary | 2026-06-04_038_parameterized_bundle_outputs_in_sweeps | Active-alias ctx$features lookup shape is easy to miss |
| feedback_summary | 2026-06-04_038_parameterized_bundle_outputs_in_sweeps | ctx$ts_utc formatting behavior surprised strategy debugging code |
| feedback_summary | 2026-06-04_039_b2_spot_fifo_opt_in | Sweep candidate rows do not expose fill counts |
| feedback_summary | 2026-06-04_040_compiled_accounting_model_errors | No runnable fail-closed example for compiled_accounting_model errors |
| feedback_summary | 2026-06-04_041_parallel_sweep_parity | worker_dependencies cannot be passed directly to worker_packages |
| feedback_summary | 2026-06-04_041_parallel_sweep_parity | Full reproduction key includes per-sweep identity |
| feedback_summary | 2026-06-04_041_parallel_sweep_parity | Compact sweep rows expose trades but not fill counts |
| feedback_summary | 2026-06-04_042_parallel_sweep_discard_all | No runnable docs example for parallel discard-all worker failure |
| feedback_summary | 2026-06-04_043_canonical_json_v2_identity | Feature and alias hashes require nested candidate-key inspection |
| feedback_summary | 2026-06-04_043_canonical_json_v2_identity | Config hash changed when only the store path changed |
| feedback_summary | 2026-06-04_043_canonical_json_v2_identity | PowerShell UTF-8 BOM broke temporary R helper script |
| feedback_summary | 2026-06-04_044_matrix_canonical_accessors | No complete matrix-canonical strategy example |
| feedback_summary | 2026-06-04_044_matrix_canonical_accessors | `ctx$idx()` argument details are embedded rather than reference-like |
| feedback_summary | 2026-06-04_045_pulse_seed_determinism | ctx pulse_seed is absent from the strategy context accessor reference |
| feedback_summary | 2026-06-04_045_pulse_seed_determinism | Sweep determinism comparison surface is not explicit about sweep_id metadata |
| feedback_summary | 2026-06-04_045_pulse_seed_determinism | Preflight worker_dependencies field shape is underdocumented |
| feedback_summary | 2026-06-04_045_pulse_seed_determinism | PowerShell wildcard pattern caused rg path error while searching rendered docs |
| feedback_summary | 2026-06-04_046_disclaimer_discoverability | Installed research-workflow disclaimer link points to missing file |
| feedback_summary | 2026-06-04_046_disclaimer_discoverability | Package overview surfaces do not expose the disclaimer |
| feedback_summary | 2026-06-04_046_disclaimer_discoverability | Strategy-development warning does not link to the formal disclaimer |
| feedback_summary | 2026-06-04_046_disclaimer_discoverability | NEWS mentions disclaimer posture without a readable disclaimer path |
| research_report | 2026-06-04_001_cold_start_readme | - No ledgr runtime error blocked the task. |
| research_report | 2026-06-04_003_strategy_development_article | - `raw_logs/reproducible_script_stdout.txt` showed that the final-bar no-fill warning object is only `simpleWarning,warning,condition`, despite the message containing an all-caps ledgr warning code. This did not block the workflow, but it is a condition-handling/documentation friction item. |
| research_report | 2026-06-04_006_indicators_article | I did not find a current link to a retired or missing indicators article in the consulted installed documentation. |
| research_report | 2026-06-04_007_help_page_discoverability | - The first verification run of `reproducible_script.R` failed because my regex only matched single-line `vignette()` calls. `metrics-and-accounting` wraps across lines in `raw_logs/ledgr_run.txt`, so I changed the parser to allow whitespace and line breaks between the article name and `package = "ledgr"`. This was an artifact-script issue, not a ledgr documentation issue. |
| research_report | 2026-06-04_008_feature_map_strategy_authoring | One failed documentation-discovery attempt came from creating an R helper script \| with PowerShell `Set-Content -Encoding UTF8`, which wrote a BOM that R rejected. \| files without a BOM. Evidence: `raw_logs/doc_discovery_stderr.txt` and |
| research_report | 2026-06-04_010_low_level_csv_snapshot_seal_run | One PowerShell `-Expr` metadata-inspection command containing `$` was altered by shell expansion, and one single-quoted retry lost quotes before R execution. I worked around this by writing `raw_logs/inspect_meta_json_saved.R` and running it through `RUN_R.cmd -Script`. This was episode runner / shell quoting friction, not a ledgr API issue. |
| research_report | 2026-06-04_011_warmup_diagnostic_and_three_cases | Fourth attempt: I tried to trigger current-bar absence with the single-instrument 15-bar snapshot by requesting a pulse timestamp outside the sample. ledgr failed before strategy evaluation with `ledgr_invalid_args`, consistent with the documentation. |
| research_report | 2026-06-04_013_ctx_features_discoverability | One failed documentation-helper attempt occurred before the final script: I wrote a temporary R script with PowerShell `Set-Content`, which added a UTF-8 BOM. R failed with `Error: unexpected input in "﻿"`. I retried using `RUN_R.cmd -Expr` for the short helper calls, and `ledgr_save_help()` succeeded. |
| research_report | 2026-06-04_016_leakage_diagnosis_and_series_fn_boundary | - An inline PowerShell `-Expr` command using `ledgr_demo_bars$instrument_id` failed because `$instrument_id` was expanded away by PowerShell. I kept the logs and switched to saved `.R` scripts. Evidence: `raw_logs/inspect_demo_bad_shell_stdout.txt` and `raw_logs/inspect_demo_bad_shell_stderr.txt`. |
| research_report | 2026-06-04_020_sweep_precomputed_features | locked by another process. I avoided those logs afterward and kept searches to \| specific files or directories. Evidence: `raw_logs/rg_locked_log.txt`. |
| research_report | 2026-06-04_021_sweep_seed_and_promotion_context | Documentation discovery friction remained even though the task was completed. The rendered sweeps vignette documented master seed derivation and `execution_seed`, but it did not show all three promotion-context read paths. The research workflow used `info$promotion_context`, while the explicit `ledgr_promotion_context()` and `ledgr_run_promotion_context()` accessors were easier to find through help pages and the metrics vignette. The task-intent map listed the helper topics but did not group sweeps/promotion as a task intent. \| One local search command failed because PowerShell did not expand `.\raw_logs\ledgr_*.txt` as expected for `rg`; I reran the search without that glob. This was shell usage friction, not a ledgr failure. |
| research_report | 2026-06-04_025_final_bar_no_fill_warning | No implementation debugging iterations were needed because `LEDGR_DOCS/execution-semantics.md` included a directly relevant example. Documentation discovery friction: `ledgr_save_help("LEDGR_LAST_BAR_NO_FILL")` failed because the warning code has no help topic. The workaround was to rely on the rendered execution vignette and grep `conditionMessage(w)` for the warning token. |
| research_report | 2026-06-04_027_helper_pipeline_troubleshooting | The main ledgr diagnostics were clear and sufficient for the first three failure rows. The zero-fill case required the documented single-pulse inspection to distinguish sizing-to-zero from empty selection or warmup. Searching `raw_logs/` with `rg` also hit locked Codex log files; this was episode-environment friction, not a ledgr behavior. |
| research_report | 2026-06-04_036_alias_aware_pulse_inspection | - No shell quoting or Windows runner workaround was needed beyond using |
| research_report | 2026-06-04_037_alias_identity_and_declaration_order | Completed with observed regressions and one blocked acceptance check. \| Observed mismatches or blocked checks: |
| research_report | 2026-06-04_043_canonical_json_v2_identity | - A first attempt to save help-topic discovery code with PowerShell `Set-Content -Encoding UTF8` produced a UTF-8 BOM. R failed with `Error: unexpected input in "﻿"`. Retried with an episode script created without BOM and `RUN_R.cmd`. |
| research_report | 2026-06-04_046_disclaimer_discoverability | Blocked. \| Second iteration: the script found the `research-workflow` disclaimer link, but following `../DISCLAIMER.md` resolved to a missing installed package-root file. It also showed empty package help/vignette logs because those objects were not captured by plain auto-printing. \| blocked |

## Agent And Harness Performance

### Runner Types

| runner_type | episodes |
| --- | --- |
| codex | 46 |

### Runner Models

| runner_model | episodes |
| --- | --- |
| (blank) | 46 |

### Runner Exit Status

| runner_exit_status | episodes |
| --- | --- |
| 0 | 46 |

### Check Status

| check_status | episodes |
| --- | --- |
| (blank) | 46 |

## Prompt And Task Quality

- Review repeated duplicate candidates, missing source_docs rows, and
  documentation discovery friction before choosing the next task theme.
- Confirm whether task briefs were too broad, too narrow, or missing
  constraints before promoting generated follow-up tasks.

## Next-Cycle Theme Candidates

- Hashes And Reproducibility Identity
- Errors Warnings And Diagnostics
- Strategy Context And Indicators
- Sweep And Candidate Workflows
- Runnable Examples And Reference Completeness

## Maintainer Notes

- TODO: Record final duplicate decisions.
- TODO: Record which ledgr fixes, docs, or tests should be prioritized.
- TODO: Choose the next cycle theme.
