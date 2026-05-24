# auditr Cycle Retrospective

Source: `C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.8.1`

This is a maintainer-review artifact. It does not create GitHub issues,
does not execute ledgr workflows, and does not decide final defect truth.


## Status

- episodes: 8
- feedback rows: 30
- feedback summary valid: yes
- categorized feedback: valid
- partial retrospective: no

## Feedback Counts

### Type

| type | items |
| --- | --- |
| documentation_gap | 18 |
| ux_friction | 7 |
| unclear_error | 5 |

### Triage

| triage | items |
| --- | --- |
| docs_gap | 18 |
| unclear | 7 |
| expected_user_error | 3 |
| ledgr_bug | 2 |

### Severity

| severity | items |
| --- | --- |
| low | 23 |
| medium | 5 |
| high | 2 |

## Task Coverage

### Task Titles

| task_title | episodes |
| --- | --- |
| Answer a small research question on real data with no procedural hand-holding | 1 |
| Author multi-output indicator bundles and verify they flatten to ordinary features | 1 |
| Fetch a Yahoo universe and sweep each strategy's hyperparameters end to end | 1 |
| Hit each row of the helper pipeline troubleshooting table | 1 |
| Trigger adversarial CSV, indicator-bundle, and registration error paths | 1 |
| Trigger LEDGR_LAST_BAR_NO_FILL and verify the warning explains itself | 1 |
| Try to bypass strategy preflight and verify Tier 3 enforcement | 1 |
| Walk the Inspection Surfaces map and verify each surface answers its question | 1 |

### Difficulty

| difficulty | episodes |
| --- | --- |
| challenging | 4 |
| straightforward | 4 |

## Duplicate Candidates

These are deterministic suggestions only. auditr does not merge findings.

| normalized_title | feedback_ids | titles | episode_ids | n |
| --- | --- | --- | --- | --- |

## Documentation Provenance

- feedback rows missing source_docs: 0
- documentation discovery friction rows: 25

### High-Severity Rows Missing Source Context

| episode_id | feedback_id | title | severity |
| --- | --- | --- | --- |

### Repeated Source Docs

| source_doc | items |
| --- | --- |
| TASK.md | 16 |
| LEDGR_DOCS/strategy-development.md | 9 |
| ?ledgr_run | 6 |
| ?ledgr_strategy_preflight | 6 |
| LEDGR_DOCS/experiment-store.md | 6 |
| ?ledgr_results | 5 |
| LEDGR_DOCS/metrics-and-accounting.md | 5 |
| LEDGR_DOCS/reproducibility.md | 5 |
| ?ledgr_ind_ttr_outputs | 3 |
| ?ledgr_snapshot_from_csv | 3 |
| ?ledgr_snapshot_from_yahoo | 3 |
| episode_environment | 3 |
| LEDGR_DOCS/indicators.md | 3 |
| LEDGR_DOCS/sweeps.md | 3 |
| ?ledgr_compare_runs | 2 |
| ?ledgr_compute_metrics | 2 |
| ?ledgr_promote | 2 |
| ?ledgr_pulse_snapshot | 2 |
| ?ledgr_snapshot_import_bars_csv | 2 |
| ?ledgr_experiment | 1 |
| ?ledgr_feature_id | 1 |
| ?ledgr_feature_map | 1 |
| ?ledgr_ind_ttr | 1 |
| ?ledgr_param_grid | 1 |
| ?ledgr_snapshot_seal | 1 |
| ?ledgr_sweep | 1 |
| DOC_DISCOVERY.R | 1 |
| LEDGR_DOCS/getting-started.md | 1 |
| LEDGR_DOCS/research-to-production.md | 1 |
| raw_logs/ledgr_doc_snapshot.md | 1 |

### Discovery Friction Evidence

| source | episode_id | evidence |
| --- | --- | --- |
| feedback_summary | 2026-05-24_001_multi_output_indicator_bundles | Default BBands bundle IDs do not match hand-written single-output TTR IDs |
| feedback_summary | 2026-05-24_001_multi_output_indicator_bundles | Partial `naming` map needs explicit `outputs` filter |
| feedback_summary | 2026-05-24_002_yahoo_universe_sweep_per_strategy | Yahoo snapshot sealing contract is easy to misread |
| feedback_summary | 2026-05-24_002_yahoo_universe_sweep_per_strategy | Large Cartesian grids require undocumented boilerplate |
| feedback_summary | 2026-05-24_002_yahoo_universe_sweep_per_strategy | Promotion replay verification needs a direct example |
| feedback_summary | 2026-05-24_002_yahoo_universe_sweep_per_strategy | Last-bar no-fill warnings lack sweep and promotion context |
| feedback_summary | 2026-05-24_002_yahoo_universe_sweep_per_strategy | Documentation helper scalar-only behavior was not obvious |
| feedback_summary | 2026-05-24_003_adversarial_preflight_and_force_override | Global assignment strategy is allowed and writes a run |
| feedback_summary | 2026-05-24_003_adversarial_preflight_and_force_override | stats-qualified function example does not produce Tier 2 |
| feedback_summary | 2026-05-24_003_adversarial_preflight_and_force_override | No-force wording is absent for nondeterministic strategy rejection |
| feedback_summary | 2026-05-24_004_adversarial_inputs_csv_bundle_registration | High-level CSV helper does not raise documented CSV error class |
| feedback_summary | 2026-05-24_004_adversarial_inputs_csv_bundle_registration | Recursive raw log search can hit locked Codex session logs |
| feedback_summary | 2026-05-24_005_final_bar_no_fill_warning | Final-bar warning docs do not show the extension verification pattern |
| feedback_summary | 2026-05-24_006_inspection_surfaces_map | Compare-runs surface needs experiment-first setup cue |
| feedback_summary | 2026-05-24_006_inspection_surfaces_map | Unsupported features result-table error omits pulse-time route |
| feedback_summary | 2026-05-24_007_helper_pipeline_troubleshooting | Troubleshooting table does not name the fills extraction API |
| feedback_summary | 2026-05-24_007_helper_pipeline_troubleshooting | Missing-name diagnostic omits how to obtain the target before validation |
| feedback_summary | 2026-05-24_007_helper_pipeline_troubleshooting | Zero trades and zero fills need clearer separation |
| feedback_summary | 2026-05-24_007_helper_pipeline_troubleshooting | Tier 3 hard-failure claim lacks a runnable example |
| feedback_summary | 2026-05-24_008_unguided_yahoo_research_question | Yahoo workflow is hard to discover from the task-intent map |
| feedback_summary | 2026-05-24_008_unguided_yahoo_research_question | Strategy helper functions trigger tier-3 preflight unless inlined |
| feedback_summary | 2026-05-24_008_unguided_yahoo_research_question | Printed comparison mixes human formatting with report-ready values |
| research_report | 2026-05-24_001_multi_output_indicator_bundles | The task was not blocked, and the ledgr workflow ran to completion in `raw_logs/reproducible_script_stdout.txt`. |
| research_report | 2026-05-24_002_yahoo_universe_sweep_per_strategy | - Initial attempt to call `ledgr_save_help()` with a vector of topics failed with `Error: path must be a non-empty scalar string.` I retried with a small saved helper script that called `ledgr_save_help()` one topic at a time. Evidence: `raw_logs/help_pages_stderr.txt` and `raw_logs/help_topics_stdout.txt`. |
| research_report | 2026-05-24_004_adversarial_inputs_csv_bundle_registration | A recursive `rg` over `raw_logs/` hit locked Codex session logs: |

## Agent And Harness Performance

### Runner Types

| runner_type | episodes |
| --- | --- |
| codex | 8 |

### Runner Models

| runner_model | episodes |
| --- | --- |
| (blank) | 8 |

### Runner Exit Status

| runner_exit_status | episodes |
| --- | --- |
| 0 | 8 |

### Check Status

| check_status | episodes |
| --- | --- |
| (blank) | 8 |

## Prompt And Task Quality

- Review repeated duplicate candidates, missing source_docs rows, and
  documentation discovery friction before choosing the next task theme.
- Confirm whether task briefs were too broad, too narrow, or missing
  constraints before promoting generated follow-up tasks.

## Next-Cycle Theme Candidates

- Preflight Contract Alignment
- Workflow Documentation Gaps
- Indicator Bundle Ergonomics
- CSV Error Clarity
- Inspection Troubleshooting Examples

## Maintainer Notes

- TODO: Record final duplicate decisions.
- TODO: Record which ledgr fixes, docs, or tests should be prioritized.
- TODO: Choose the next cycle theme.
