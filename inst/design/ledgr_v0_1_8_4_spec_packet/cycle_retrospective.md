# auditr Cycle Retrospective

Source: `C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.8.3`

This is a maintainer-review artifact. It does not create GitHub issues,
does not execute ledgr workflows, and does not decide final defect truth.


## Status

- episodes: 22
- feedback rows: 56
- feedback summary valid: yes
- categorized feedback: valid
- partial retrospective: no

## Feedback Counts

### Type

| type | items |
| --- | --- |
| documentation_gap | 45 |
| ux_friction | 6 |
| unclear_error | 3 |
| bug | 2 |

### Triage

| triage | items |
| --- | --- |
| docs_gap | 48 |
| expected_user_error | 4 |
| unclear | 4 |

### Severity

| severity | items |
| --- | --- |
| low | 46 |
| medium | 10 |

## Task Coverage

### Task Titles

| task_title | episodes |
| --- | --- |
| Answer a small research question on real data with no procedural hand-holding | 1 |
| Author multi-output indicator bundles and verify they flatten to ordinary features | 1 |
| Classify strategies with preflight and observe Tier 3 blocking | 1 |
| Construct and inspect the v0.1.8.2 metric context surface | 1 |
| Diagnose leakage in a vectorized feature and correct it | 1 |
| Exercise the LDG-2303 preflight contract additions | 1 |
| Fetch a Yahoo universe and sweep each strategy's hyperparameters end to end | 1 |
| Fetch real market data from Yahoo Finance and compare five strategies | 1 |
| Inspect ledger events and handle the unsupported metrics result type | 1 |
| Observe sweep failure rows and stop_on_error behaviour | 1 |
| Precompute features for a larger sweep grid | 1 |
| Probe the static-analysis boundary of strategy preflight | 1 |
| Run a basic sweep, select a candidate, and promote it | 1 |
| Sweep indicator parameters using a feature factory | 1 |
| Sweep on a train snapshot and evaluate the selected candidate out of sample | 1 |
| Trace one metric context across experiment, run, comparison, sweep, and promotion | 1 |
| Trigger adversarial CSV, indicator-bundle, and registration error paths | 1 |
| Trigger LEDGR_LAST_BAR_NO_FILL and verify the warning explains itself | 1 |
| Try to bypass strategy preflight and verify Tier 3 enforcement | 1 |
| Use metric context call-time overrides for sensitivity analysis | 1 |
| Verify seed propagation and inspect promotion context | 1 |
| Walk the Inspection Surfaces map and verify each surface answers its question | 1 |

### Difficulty

| difficulty | episodes |
| --- | --- |
| straightforward | 11 |
| challenging | 7 |
| "hard" | 2 |
| "medium" | 2 |

## Duplicate Candidates

These are deterministic suggestions only. auditr does not merge findings.

| normalized_title | feedback_ids | titles | episode_ids | n |
| --- | --- | --- | --- | --- |

## Documentation Provenance

- feedback rows missing source_docs: 0
- documentation discovery friction rows: 56

### High-Severity Rows Missing Source Context

| episode_id | feedback_id | title | severity |
| --- | --- | --- | --- |

### Repeated Source Docs

| source_doc | items |
| --- | --- |
| TASK.md | 22 |
| LEDGR_DOCS/sweeps.md | 18 |
| LEDGR_DOCS/metrics-and-accounting.md | 10 |
| ?ledgr_sweep | 9 |
| LEDGR_DOCS/strategy-development.md | 7 |
| ?ledgr_strategy_preflight | 6 |
| ?ledgr_metric_context | 5 |
| LEDGR_DOCS/indicators.md | 5 |
| LEDGR_DOCS/reproducibility.md | 5 |
| ?ledgr_snapshot_from_yahoo | 4 |
| episode_environment | 4 |
| LEDGR_DOCS/experiment-store.md | 4 |
| raw_logs/ledgr_doc_snapshot.md | 4 |
| ?ledgr_ind_ttr_outputs | 3 |
| ?ledgr_precompute_features | 3 |
| ?ledgr_promote | 3 |
| LEDGR_DOCS/custom-indicators.md | 3 |
| LEDGR_DOCS/index.md | 3 |
| LEDGR_DOCS/scripts/sweeps.R | 3 |
| ?ledgr_candidate | 2 |
| ?ledgr_compare_runs | 2 |
| ?ledgr_compute_metrics | 2 |
| ?ledgr_deregister_indicator | 2 |
| ?ledgr_experiment | 2 |
| ?ledgr_ind_ttr | 2 |
| ?ledgr_param_grid | 2 |
| ?ledgr_risk_free_rate | 2 |
| ?ledgr_snapshot_from_csv | 2 |
| raw_logs/workflow_attempt_1_stdout.txt | 2 |
| ?ledgr_calendar | 1 |
| ?ledgr_feature_contract_check | 1 |
| ?ledgr_feature_map | 1 |
| ?ledgr_get_indicator | 1 |
| ?ledgr_ind_sma | 1 |
| ?ledgr_indicator | 1 |
| ?ledgr_metric_context_hash | 1 |
| ?ledgr_metric_context_resolve | 1 |
| ?ledgr_promotion_context | 1 |
| ?ledgr_pulse_features | 1 |
| ?ledgr_pulse_snapshot | 1 |
| ?ledgr_pulse_wide | 1 |
| ?ledgr_register_indicator | 1 |
| ?ledgr_results | 1 |
| ?ledgr_run | 1 |
| ?ledgr_run_info | 1 |
| ?ledgr_run_list | 1 |
| ?ledgr_run_promotion_context | 1 |
| ?ledgr_snapshot_import_bars_csv | 1 |
| ?ledgr_snapshot_seal | 1 |
| ?ledgr_strategy_context | 1 |
| ?print.ledgr_precomputed_features | 1 |
| AGENT_PROMPT.md | 1 |
| DOC_DISCOVERY.R | 1 |
| LEDGR_DOCS/leakage.md | 1 |
| LEDGR_DOCS/scripts/metrics-and-accounting.R | 1 |
| raw_logs/reproducible_script_stderr.txt | 1 |
| raw_logs/strategy_comparison_summary.csv | 1 |
| raw_logs/trial_research_run_stdout.txt | 1 |

### Discovery Friction Evidence

| source | episode_id | evidence |
| --- | --- | --- |
| feedback_summary | 2026-05-26_001_ledger_events_and_metrics_error | Ledger docs do not explicitly say portfolio state updates are not separate ledger rows |
| feedback_summary | 2026-05-26_002_yahoo_five_strategies | Yahoo helper auto-sealing makes seal-once task wording ambiguous |
| feedback_summary | 2026-05-26_002_yahoo_five_strategies | Bollinger strategy path depends on optional TTR availability |
| feedback_summary | 2026-05-26_004_leakage_diagnosis_and_series_fn_boundary | No public causal validator for vectorized series_fn output |
| feedback_summary | 2026-05-26_004_leakage_diagnosis_and_series_fn_boundary | Comparing same-ID indicator definitions requires session deregistration |
| feedback_summary | 2026-05-26_005_sweep_basic_candidate_promotion | Base R ranking via as.data.frame drops sweep metadata |
| feedback_summary | 2026-05-26_005_sweep_basic_candidate_promotion | final_equity comparison requires a different API than ledgr_compute_metrics |
| feedback_summary | 2026-05-26_005_sweep_basic_candidate_promotion | Listed sweeps runnable vignette script has no runnable workflow |
| feedback_summary | 2026-05-26_008_sweep_feature_factory | precompute help does not show feature factory hashes |
| feedback_summary | 2026-05-26_008_sweep_feature_factory | SMA warmup leading NA count is implicit |
| feedback_summary | 2026-05-26_009_sweep_precomputed_features | print.ledgr_precomputed_features help does not document printed fields |
| feedback_summary | 2026-05-26_009_sweep_precomputed_features | No single runnable example covers the full large feature-factory precompute workflow |
| feedback_summary | 2026-05-26_010_sweep_seed_and_promotion_context | Ranking examples do not warn against dropping sweep-result metadata |
| feedback_summary | 2026-05-26_010_sweep_seed_and_promotion_context | Promotion context candidate_summary schema is not documented |
| feedback_summary | 2026-05-26_011_multi_output_indicator_bundles | Default bundle IDs do not match equivalent single-output TTR IDs |
| feedback_summary | 2026-05-26_011_multi_output_indicator_bundles | Sweep result inspection needs clearer guidance for labels and hidden list columns |
| feedback_summary | 2026-05-26_012_yahoo_universe_sweep_per_strategy | Programmatic hyperparameter grid construction is not shown |
| feedback_summary | 2026-05-26_012_yahoo_universe_sweep_per_strategy | Promotion replay metric check needs cross-surface instructions |
| feedback_summary | 2026-05-26_013_adversarial_preflight_and_force_override | Task asks for global scalar to be Tier 3 but docs and ledgr return Tier 2 |
| feedback_summary | 2026-05-26_013_adversarial_preflight_and_force_override | Task suggests stats::median for Tier 2 but recommended-R calls remain Tier 1 |
| feedback_summary | 2026-05-26_013_adversarial_preflight_and_force_override | Documentation snapshot intent map omits strategy preflight for preflight tasks |
| feedback_summary | 2026-05-26_014_adversarial_inputs_csv_bundle_registration | High-level CSV error classes are easy to mis-expect |
| feedback_summary | 2026-05-26_014_adversarial_inputs_csv_bundle_registration | Registration overwrite safety is not documented on help page |
| feedback_summary | 2026-05-26_014_adversarial_inputs_csv_bundle_registration | Feature-map duplicate bundle error is alias-framed |
| feedback_summary | 2026-05-26_015_final_bar_no_fill_warning | ctx$ts_utc comparison type is not explicit |
| feedback_summary | 2026-05-26_016_inspection_surfaces_map | Inspection Surfaces map needs a sweep setup pointer |
| feedback_summary | 2026-05-26_016_inspection_surfaces_map | Pulse feature helper examples are not runnable alone |
| feedback_summary | 2026-05-26_016_inspection_surfaces_map | PowerShell doc excerpt range syntax caused a failed path |
| feedback_summary | 2026-05-26_017_unguided_yahoo_research_question | Yahoo snapshot helper is not in the task-intent map |
| feedback_summary | 2026-05-26_017_unguided_yahoo_research_question | No runnable open-ended Yahoo comparison example |
| feedback_summary | 2026-05-26_017_unguided_yahoo_research_question | One-experiment-per-strategy rule is easy to miss |
| feedback_summary | 2026-05-26_017_unguided_yahoo_research_question | Baseline sizing examples can produce unfair comparisons |
| feedback_summary | 2026-05-26_017_unguided_yahoo_research_question | Final-bar no-fill warning lacks a clear research workflow |
| feedback_summary | 2026-05-26_017_unguided_yahoo_research_question | Yahoo price adjustment semantics are not obvious |
| feedback_summary | 2026-05-26_017_unguided_yahoo_research_question | Open buy-and-hold positions make trade metrics look empty |
| feedback_summary | 2026-05-26_018_metric_context_constructors_and_templates | Task-intent doc map omits metric-context help topics from metrics group |
| feedback_summary | 2026-05-26_019_metric_context_end_to_end_lifecycle | No runnable end-to-end metric-context lifecycle example |
| feedback_summary | 2026-05-26_019_metric_context_end_to_end_lifecycle | Annual risk-free rate lacks a documented scalar accessor |
| feedback_summary | 2026-05-26_019_metric_context_end_to_end_lifecycle | PowerShell searches containing dollar signs are easy to misquote |
| feedback_summary | 2026-05-26_020_adversarial_preflight_v0_1_8_2_additions | Missing example for verifying no run row after preflight abort |
| feedback_summary | 2026-05-26_021_metric_context_sensitivity_overrides | Doc snapshot intent map omits metric-context topics |
| feedback_summary | 2026-05-26_021_metric_context_sensitivity_overrides | Sweep context override path is experiment-level, not call-time |
| feedback_summary | 2026-05-26_021_metric_context_sensitivity_overrides | Saved help file naming was easy to guess incorrectly |
| feedback_summary | 2026-05-26_022_adversarial_preflight_indirection_bypass | Preflight docs do not show which indirection bodies are inspected |
| research_report | 2026-05-26_001_ledger_events_and_metrics_error | - No shell quoting workaround was needed because all substantive R code lived |
| research_report | 2026-05-26_002_yahoo_five_strategies | No strategy run was blocked. The first Yahoo download attempt succeeded, so no \| Two documentation/workflow frictions were still noted: the Yahoo helper returns |
| research_report | 2026-05-26_003_strategy_preflight_and_tier_classification | verify that a Tier 3 strategy is blocked by `ledgr_run()` before a run artifact \| returned zero rows after the Tier 3 attempt, so no `tier_3_blocked` run artifact |
| research_report | 2026-05-26_006_sweep_train_test_discipline | Task `040_sweep_train_test_discipline`: split synthetic ledgr bars into train and test periods, create separate snapshots and experiments, sweep named candidates on the train snapshot, select the best candidate by `sharpe_ratio`, replay it on the train snapshot, then evaluate the same locked parameters on the held-out test snapshot with the cross-snapshot promotion opt-in. \| `ledgr_run_list(train_snapshot)` contained only `locked_train_replay`. `ledgr_run_list(test_snapshot)` contained `locked_test_oos`, so the test run was stored with the test snapshot and not the train snapshot. \| The sweeps vignette communicated the train/test distinction clearly before running the main workflow code. "Normal Train/Test Discipline" gives the explicit sequence from source bars to train snapshot, test snapshot, train sweep, locked candidate, and test evaluation. "Same-Snapshot Replay Is Secondary" states that same-snapshot replay is in-sample and that cross-snapshot evaluation requires deliberately setting `require_same_snapshot = FALSE`. |
| research_report | 2026-05-26_008_sweep_feature_factory | Documentation friction remained around how much the formal help page for |
| research_report | 2026-05-26_010_sweep_seed_and_promotion_context | Two documentation/API-shape frictions remained: |
| research_report | 2026-05-26_011_multi_output_indicator_bundles | The exact overlapping sweep shape was blocked by ledgr's runtime projection because default bundle IDs do not include TTR arguments such as `n`. That is recorded in `framework_feedback.md` and in `raw_logs/reproducible_script_final_stdout.txt`. |
| research_report | 2026-05-26_014_adversarial_inputs_csv_bundle_registration | The documentation phrase confirming CSV validation locality was in `LEDGR_DOCS/experiment-store.md`: "CSV and local data validation happens while the snapshot is created and sealed, before a strategy can run. Missing columns, unparseable timestamps, duplicate `instrument_id`/`ts_utc` rows, and OHLC violations are snapshot import problems. They are not strategy execution errors." \| Succeeded, with documentation/API feedback. Every adversarial path failed before strategy execution, and the CSV failure paths left no snapshot, experiment, or run artifacts. Exact evidence is in `raw_logs/adversarial_results.txt`; CSV observations are also tabulated in `raw_logs/csv_error_observations.tsv`. |
| research_report | 2026-05-26_016_inspection_surfaces_map | `Select-Object -Index 280..340`, which failed in PowerShell because the range |
| research_report | 2026-05-26_018_metric_context_constructors_and_templates | No blocking ledgr errors occurred. The main resolved friction was documentation |
| research_report | 2026-05-26_019_metric_context_end_to_end_lifecycle | - One documentation search command failed because my PowerShell regex quoting |
| research_report | 2026-05-26_020_adversarial_preflight_v0_1_8_2_additions | The ledgr preflight contract itself behaved as documented and as requested by the task. The only friction recorded in `framework_feedback.md` is a low-severity documentation gap around how a first-time user should verify that a preflight-aborted run did not write a run row. |

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

- Runnable examples and doc routing gaps
- Sweep ranking, promotion, and provenance inspection
- Indicator authoring and causal validation
- Feature factory and precompute boundaries
- Strategy preflight boundaries and messages

## Maintainer Notes

- TODO: Record final duplicate decisions.
- TODO: Record which ledgr fixes, docs, or tests should be prioritized.
- TODO: Choose the next cycle theme.
