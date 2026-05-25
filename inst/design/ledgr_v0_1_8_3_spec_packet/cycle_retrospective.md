# auditr Cycle Retrospective

Source: `C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.8.2`

This is a maintainer-review artifact. It does not create GitHub issues,
does not execute ledgr workflows, and does not decide final defect truth.


## Status

- episodes: 16
- feedback rows: 57
- feedback summary valid: yes
- categorized feedback: valid
- partial retrospective: no

## Feedback Counts

### Type

| type | items |
| --- | --- |
| documentation_gap | 41 |
| unclear_error | 7 |
| ux_friction | 7 |
| bug | 2 |

### Triage

| triage | items |
| --- | --- |
| docs_gap | 41 |
| unclear | 11 |
| expected_user_error | 5 |

### Severity

| severity | items |
| --- | --- |
| low | 44 |
| medium | 12 |
| high | 1 |

## Task Coverage

### Task Titles

| task_title | episodes |
| --- | --- |
| Answer a small research question on real data with no procedural hand-holding | 1 |
| Author multi-output indicator bundles and verify they flatten to ordinary features | 1 |
| Construct and inspect the v0.1.8.2 metric context surface | 1 |
| Exercise the LDG-2303 preflight contract additions | 1 |
| Fetch a Yahoo universe and sweep each strategy's hyperparameters end to end | 1 |
| Hit each row of the helper pipeline troubleshooting table | 1 |
| Probe metric context validation, mutation, and hash invariants | 1 |
| Probe the static-analysis boundary of strategy preflight | 1 |
| Real-data Yahoo workflow with explicit metric context across the full lifecycle | 1 |
| Trace one metric context across experiment, run, comparison, sweep, and promotion | 1 |
| Trigger adversarial CSV, indicator-bundle, and registration error paths | 1 |
| Trigger LEDGR_LAST_BAR_NO_FILL and verify the warning explains itself | 1 |
| Try to bypass strategy preflight and verify Tier 3 enforcement | 1 |
| Use metric context call-time overrides for sensitivity analysis | 1 |
| Verify the v0.1.8.2 intraday annualization correctness fix | 1 |
| Walk the Inspection Surfaces map and verify each surface answers its question | 1 |

### Difficulty

| difficulty | episodes |
| --- | --- |
| straightforward | 8 |
| challenging | 7 |
| "medium" | 1 |

## Duplicate Candidates

These are deterministic suggestions only. auditr does not merge findings.

| normalized_title | feedback_ids | titles | episode_ids | n |
| --- | --- | --- | --- | --- |

## Documentation Provenance

- feedback rows missing source_docs: 0
- documentation discovery friction rows: 59

### High-Severity Rows Missing Source Context

| episode_id | feedback_id | title | severity |
| --- | --- | --- | --- |

### Repeated Source Docs

| source_doc | items |
| --- | --- |
| TASK.md | 21 |
| LEDGR_DOCS/metrics-and-accounting.md | 18 |
| LEDGR_DOCS/strategy-development.md | 11 |
| LEDGR_DOCS/experiment-store.md | 10 |
| ?ledgr_strategy_preflight | 9 |
| LEDGR_DOCS/reproducibility.md | 9 |
| ?ledgr_metric_context | 8 |
| LEDGR_DOCS/sweeps.md | 8 |
| ?ledgr_sweep | 7 |
| episode_environment | 6 |
| ?ledgr_run | 5 |
| ?ledgr_strategy_context | 5 |
| ?ledgr_compute_metrics | 4 |
| ?ledgr_risk_free_rate | 4 |
| ?ledgr_snapshot_from_csv | 4 |
| ?ledgr_snapshot_from_yahoo | 4 |
| ?ledgr_experiment | 3 |
| ?ledgr_param_grid | 3 |
| ?summary.ledgr_backtest | 3 |
| LEDGR_DOCS/indicators.md | 3 |
| raw_logs/ledgr_doc_snapshot.md | 3 |
| ?ledgr_calendar | 2 |
| ?ledgr_compare_runs | 2 |
| ?ledgr_ind_ttr_outputs | 2 |
| ?ledgr_snapshot_import_bars_csv | 2 |
| LEDGR_DOCS/custom-indicators.md | 2 |
| ?ledgr_candidate | 1 |
| ?ledgr_feature_map | 1 |
| ?ledgr_ind_ttr | 1 |
| ?ledgr_indicator | 1 |
| ?ledgr_metric_context_hash | 1 |
| ?ledgr_promote | 1 |
| ?ledgr_promotion_context | 1 |
| ?ledgr_register_indicator | 1 |
| ?ledgr_results | 1 |
| ?ledgr_run_info | 1 |
| ?ledgr_snapshot_load | 1 |
| ?ledgr_snapshot_seal | 1 |
| ?target_rebalance | 1 |
| AGENT_PROMPT.md | 1 |
| LEDGR_DOCS/index.md | 1 |
| LEDGR_DOCS/scripts/strategy-development.R | 1 |

### Discovery Friction Evidence

| source | episode_id | evidence |
| --- | --- | --- |
| feedback_summary | 2026-05-25_001_multi_output_indicator_bundles | Task expects bundle and single-output TTR IDs to match, but docs and behavior say they intentionally differ |
| feedback_summary | 2026-05-25_001_multi_output_indicator_bundles | Sweep docs do not show a focused extraction example for feature fingerprints and feature-set hashes |
| feedback_summary | 2026-05-25_002_yahoo_universe_sweep_per_strategy | ledgr_snapshot_seal return shape differs from documentation |
| feedback_summary | 2026-05-25_002_yahoo_universe_sweep_per_strategy | Failed-candidate diagnostics are not shown as concrete accessors |
| feedback_summary | 2026-05-25_002_yahoo_universe_sweep_per_strategy | Sweep tables need a documented flat export pattern |
| feedback_summary | 2026-05-25_002_yahoo_universe_sweep_per_strategy | Strategy docs are inconsistent about ctx equity accessor shape |
| feedback_summary | 2026-05-25_003_adversarial_preflight_and_force_override | Task Tier 2 example conflicts with installed preflight rules |
| feedback_summary | 2026-05-25_003_adversarial_preflight_and_force_override | Task global-variable Tier 3 requirement conflicts with reproducibility docs |
| feedback_summary | 2026-05-25_003_adversarial_preflight_and_force_override | Mutable external environment classified as Tier 2 |
| feedback_summary | 2026-05-25_003_adversarial_preflight_and_force_override | Run-info absence check is not documented as a no-row verification pattern |
| feedback_summary | 2026-05-25_004_adversarial_inputs_csv_bundle_registration | High-level CSV error classes are easy to confuse with low-level CSV import classes |
| feedback_summary | 2026-05-25_004_adversarial_inputs_csv_bundle_registration | Register-indicator help omits duplicate-registration error contract |
| feedback_summary | 2026-05-25_005_final_bar_no_fill_warning | Timestamp comparison pattern is hard to find from strategy docs |
| feedback_summary | 2026-05-25_005_final_bar_no_fill_warning | Strategy-development mixes ctx$equity and ctx$equity() |
| feedback_summary | 2026-05-25_005_final_bar_no_fill_warning | PowerShell expands $ inside double-quoted rg patterns |
| feedback_summary | 2026-05-25_006_inspection_surfaces_map | Inspection table names sweep rows but does not show minimal construction path |
| feedback_summary | 2026-05-25_006_inspection_surfaces_map | print.ledgr_backtest invisibility is not documented in the inspection map |
| feedback_summary | 2026-05-25_006_inspection_surfaces_map | Full ledgr_metrics print exposes noisy attributes |
| feedback_summary | 2026-05-25_006_inspection_surfaces_map | Comparison print formatting can obscure raw numeric column types |
| feedback_summary | 2026-05-25_007_helper_pipeline_troubleshooting | Tier 3 example runs the wrong experiment object |
| feedback_summary | 2026-05-25_007_helper_pipeline_troubleshooting | Zero-trade diagnosis needs a scriptable n_trades path |
| feedback_summary | 2026-05-25_007_helper_pipeline_troubleshooting | Zero-sizing troubleshooting lacks a compact runnable example |
| feedback_summary | 2026-05-25_008_unguided_yahoo_research_question | Missing end-to-end real Yahoo research recipe |
| feedback_summary | 2026-05-25_008_unguided_yahoo_research_question | Fill model documentation does not reveal required field names |
| feedback_summary | 2026-05-25_008_unguided_yahoo_research_question | Snapshot rerun lifecycle is easy to trip after a failed run |
| feedback_summary | 2026-05-25_008_unguided_yahoo_research_question | indicators vignette shows ledgr_param_grid vector syntax that fails |
| feedback_summary | 2026-05-25_008_unguided_yahoo_research_question | Final-bar no-fill warning lacks a documented strategy pattern |
| feedback_summary | 2026-05-25_008_unguided_yahoo_research_question | Yahoo/quantmod stderr message is documented in help but not the main Yahoo vignette path |
| feedback_summary | 2026-05-25_009_metric_context_constructors_and_templates | Metric context help hides explicit constructor fields behind ellipsis |
| feedback_summary | 2026-05-25_009_metric_context_constructors_and_templates | Metric context print omits risk-free-rate label and source |
| feedback_summary | 2026-05-25_009_metric_context_constructors_and_templates | Documentation snapshot task map under-prioritizes metric-context topics |
| feedback_summary | 2026-05-25_010_metric_context_end_to_end_lifecycle | Metric-context label shorthand is unclear |
| feedback_summary | 2026-05-25_010_metric_context_end_to_end_lifecycle | Documentation discovery map omits sweep and promotion intent |
| feedback_summary | 2026-05-25_011_intraday_calendar_annualization_fix | Default minute-bar annualization mismatch is not demonstrated |
| feedback_summary | 2026-05-25_011_intraday_calendar_annualization_fix | Timestamp accessor examples do not show safe intraday time extraction |
| feedback_summary | 2026-05-25_011_intraday_calendar_annualization_fix | Broad raw_logs searches can hit Windows path and locked-file issues |
| feedback_summary | 2026-05-25_012_adversarial_preflight_v0_1_8_2_additions | Strategy preflight docs do not enumerate the forbidden-call contract |
| feedback_summary | 2026-05-25_012_adversarial_preflight_v0_1_8_2_additions | Runtime Tier 3 rejection class and message contract is underdocumented |
| feedback_summary | 2026-05-25_012_adversarial_preflight_v0_1_8_2_additions | Ambient RNG strategy distinction is hard to discover |
| feedback_summary | 2026-05-25_013_adversarial_metric_context_invariants | Metric context help omits concrete constructor fields |
| feedback_summary | 2026-05-25_013_adversarial_metric_context_invariants | Metric context hash docs do not state provenance-field semantics |
| feedback_summary | 2026-05-25_014_metric_context_sensitivity_overrides | Metric override example does not visibly prove non-mutating behavior |
| feedback_summary | 2026-05-25_014_metric_context_sensitivity_overrides | Sweep result export needs guidance because list columns break base CSV writing |
| feedback_summary | 2026-05-25_014_metric_context_sensitivity_overrides | Inline PowerShell expression expanded `$` inside R code |
| feedback_summary | 2026-05-25_015_yahoo_metric_context_end_to_end | Multi-strategy workflow wording does not match experiment API shape |
| feedback_summary | 2026-05-25_015_yahoo_metric_context_end_to_end | Sweep results are not directly CSV-exportable after as.data.frame |
| feedback_summary | 2026-05-25_016_adversarial_preflight_indirection_bypass | do.call string Sys.time is silently accepted |
| research_report | 2026-05-25_001_multi_output_indicator_bundles | No blocked debugging loop was needed. Before the first full script run, I removed |
| research_report | 2026-05-25_002_yahoo_universe_sweep_per_strategy | Attempt 1 failed after Yahoo snapshot creation because the documentation led me to compare `ledgr_snapshot_seal(snapshot)` directly with `ledgr_snapshot_info(snapshot)$snapshot_hash`. The actual seal return was a list with `$hash` and `$snapshot`, not a bare hash string. I added a defensive extraction of `$hash`. |
| research_report | 2026-05-25_003_adversarial_preflight_and_force_override | One acceptance criterion was blocked by installed-package behavior and docs: |
| research_report | 2026-05-25_005_final_bar_no_fill_warning | 5. One PowerShell `rg` search failed because `$equity` expanded inside a |
| research_report | 2026-05-25_006_inspection_surfaces_map | No ledgr runtime failures blocked the task. The main first-time-user friction was navigational: the Inspection Surfaces table was a useful single-screen map for reading result surfaces, but building the sweep/promotion part still required leaving the metrics vignette for `LEDGR_DOCS/sweeps.md` and related help pages. The raw full print of `ledgr_compute_metrics(bt)` was also noisy because attributes expose metric context/kernel details. |
| research_report | 2026-05-25_007_helper_pipeline_troubleshooting | The main friction was documentation shape rather than runtime behavior. The Tier 3 example in the troubleshooting section defines `tier3_strategy`, but the final run call uses an earlier `exp` object instead of constructing an experiment with `tier3_strategy`; I worked around this by creating a new `ledgr_experiment()` for the Tier 3 strategy. For zero-trade diagnosis, `summary(bt)` is print-oriented, so the reproducible script used `ledgr_compute_metrics(bt)$n_trades` plus `ledgr_results(bt, what = "fills")` to make the check scriptable. To hit the "sizing to zero" cause, I used a very small `equity_fraction` and confirmed on a late pulse that the target floored to all zero. |
| research_report | 2026-05-25_009_metric_context_constructors_and_templates | The ledgr workflow itself did not fail. The friction was mostly documentation and inspection granularity: the rendered vignette had the needed examples, but the help page for `ledgr_metric_context()` uses `...` instead of listing explicit constructor fields, and the context-level print does not show the risk-free-rate label/source even though the nested `ledgr_risk_free_rate` object retains it. |
| research_report | 2026-05-25_011_intraday_calendar_annualization_fix | locked-file errors. Restricting the search to rendered docs and saved help |
| research_report | 2026-05-25_012_adversarial_preflight_v0_1_8_2_additions | No ledgr runtime bug blocked the task. The main friction was documentation-oriented: the strategy preflight help does not enumerate the full forbidden-call list or exact hard-failure class/message contract, and the ambient RNG distinction is only discoverable from the observed preflight result rather than clearly explained in the strategy-tier documentation. `LEDGR_DOCS/custom-indicators.md` lists randomness with unsafe indicator-function patterns, which could mislead a first-time user trying to understand why strategy-level `runif(1)` is Tier 2 rather than Tier 3. |
| research_report | 2026-05-25_013_adversarial_metric_context_invariants | No code-level workaround was needed for the final workflow. Documentation friction remained around `ledgr_metric_context()` constructor details: the help page exposes `x` and `...` but does not list the concrete constructor fields such as `calendar`, `benchmark`, `market_factor`, and `mar`, so the reserved provider probes were driven mostly by the task brief and observed errors. |
| research_report | 2026-05-25_014_metric_context_sensitivity_overrides | One inline `RUN_R.cmd -Expr` inspection failed because PowerShell expanded `$` in `ledgr_demo_bars$ts_utc`. The failed command is captured in `raw_logs/inspect_demo_bars_*`. I switched to saved scripts for code containing `$`. |
| research_report | 2026-05-25_016_adversarial_preflight_indirection_bypass | No shell quoting failures occurred because all multi-line R code was kept in |

## Agent And Harness Performance

### Runner Types

| runner_type | episodes |
| --- | --- |
| codex | 16 |

### Runner Models

| runner_model | episodes |
| --- | --- |
| (blank) | 16 |

### Runner Exit Status

| runner_exit_status | episodes |
| --- | --- |
| 0 | 16 |

### Check Status

| check_status | episodes |
| --- | --- |
| (blank) | 16 |

## Prompt And Task Quality

- Review repeated duplicate candidates, missing source_docs rows, and
  documentation discovery friction before choosing the next task theme.
- Confirm whether task briefs were too broad, too narrow, or missing
  constraints before promoting generated follow-up tasks.

## Next-Cycle Theme Candidates

- Preflight boundaries need clearer enforcement and diagnostics
- Examples and task wording conflict with installed API behavior
- Metric context lifecycle docs and print surfaces are incomplete
- Sweep inspection and report export need concrete accessors
- Real Yahoo workflows need a more complete happy path

## Maintainer Notes

- TODO: Record final duplicate decisions.
- TODO: Record which ledgr fixes, docs, or tests should be prioritized.
- TODO: Choose the next cycle theme.
