# auditr Cycle Retrospective

Source: `C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.8.4`

This is a maintainer-review artifact. It does not create GitHub issues,
does not execute ledgr workflows, and does not decide final defect truth.


## Status

- episodes: 30
- feedback rows: 87
- feedback summary valid: yes
- categorized feedback: valid
- partial retrospective: no

## Feedback Counts

### Type

| type | items |
| --- | --- |
| documentation_gap | 64 |
| ux_friction | 15 |
| unclear_error | 6 |
| bug | 2 |

### Triage

| triage | items |
| --- | --- |
| docs_gap | 63 |
| unclear | 15 |
| expected_user_error | 9 |

### Severity

| severity | items |
| --- | --- |
| low | 62 |
| medium | 22 |
| high | 3 |

## Task Coverage

### Task Titles

| task_title | episodes |
| --- | --- |
| Author multi-output indicator bundles and verify they flatten to ordinary features | 1 |
| Build a parameterized feature map with ledgr_param and run it end to end | 1 |
| Build a single-asset SMA crossover strategy | 1 |
| Build a strategy using a mixed built-in and TTR-backed feature map | 1 |
| Build a strategy using feature maps and the mapped accessor | 1 |
| Build a two-asset momentum strategy | 1 |
| Classify strategies with preflight and observe Tier 3 blocking | 1 |
| Compose feature and strategy grids into an executable grid for sweep | 1 |
| Discover ctx$features() and passed_warmup() from ?ledgr_feature_map alone | 1 |
| Discover installed articles from function-level help pages | 1 |
| Exercise the LDG-2303 preflight contract additions | 1 |
| Follow the getting-started vignette | 1 |
| Inspect a pulse with feature_params and alias-aware views | 1 |
| Inspect feature contracts and pulse data before running a backtest | 1 |
| Observe sweep failure rows and stop_on_error behaviour | 1 |
| Precompute features for a larger sweep grid | 1 |
| Probe alias identity hashing and declaration-order preservation | 1 |
| Probe the feature_params and params namespace split and its classed errors | 1 |
| Probe the static-analysis boundary of strategy preflight | 1 |
| Register all lookback variants before ledgr_run() in a parameter sweep | 1 |
| Run a basic sweep, select a candidate, and promote it | 1 |
| Run a strategy with only 10 bars of data | 1 |
| Run the README example | 1 |
| Sweep indicator parameters using a feature factory | 1 |
| Sweep parameterized multi-output bundles and confirm alias and hash-suffix behavior | 1 |
| Trigger LEDGR_LAST_BAR_NO_FILL and verify the warning explains itself | 1 |
| Try to bypass strategy preflight and verify Tier 3 enforcement | 1 |
| Understand the backtest object lifecycle and close() behaviour | 1 |
| Verify seed propagation and inspect promotion context | 1 |
| Walk the Inspection Surfaces map and verify each surface answers its question | 1 |

### Difficulty

| difficulty | episodes |
| --- | --- |
| straightforward | 20 |
| challenging | 6 |
| "medium" | 3 |
| blocked | 1 |

## Duplicate Candidates

These are deterministic suggestions only. auditr does not merge findings.

| normalized_title | feedback_ids | titles | episode_ids | n |
| --- | --- | --- | --- | --- |

## Documentation Provenance

- feedback rows missing source_docs: 0
- documentation discovery friction rows: 88

### High-Severity Rows Missing Source Context

| episode_id | feedback_id | title | severity |
| --- | --- | --- | --- |

### Repeated Source Docs

| source_doc | items |
| --- | --- |
| TASK.md | 31 |
| LEDGR_DOCS/sweeps.md | 27 |
| LEDGR_DOCS/indicators.md | 26 |
| LEDGR_DOCS/strategy-development.md | 15 |
| ?ledgr_feature_map | 12 |
| ?ledgr_run | 12 |
| ?ledgr_sweep | 11 |
| episode_environment | 11 |
| LEDGR_DOCS/getting-started.md | 11 |
| ?ledgr_param_grid | 8 |
| ?ledgr_strategy_context | 8 |
| ?ledgr_ind_ttr_outputs | 5 |
| ?ledgr_precompute_features | 5 |
| ?ledgr_pulse_features | 5 |
| LEDGR_DOCS/index.md | 5 |
| ?ledgr_experiment | 4 |
| ?ledgr_feature_contracts | 4 |
| ?ledgr_pulse_snapshot | 4 |
| ?ledgr_pulse_wide | 4 |
| ?ledgr_run_info | 4 |
| ?ledgr_strategy_preflight | 4 |
| raw_logs/ledgr_doc_snapshot.md | 4 |
| LEDGR_DOCS/experiment-store.md | 3 |
| LEDGR_DOCS/metrics-and-accounting.md | 3 |
| LEDGR_DOCS/reproducibility.md | 3 |
| LEDGR_DOCS/scripts/getting-started.R | 3 |
| ?close.ledgr_backtest | 2 |
| ?ledgr_feature_grid | 2 |
| ?ledgr_feature_id | 2 |
| ?ledgr_grid_add_baseline | 2 |
| ?ledgr_grid_named | 2 |
| ?ledgr_param | 2 |
| ?ledgr_promote | 2 |
| ?ledgr_results | 2 |
| ?passed_warmup | 2 |
| ?summary.ledgr_backtest | 2 |
| LEDGR_DOCS/scripts/sweeps.R | 2 |
| ?ledgr-package | 1 |
| ?ledgr_candidate | 1 |
| ?ledgr_compare_runs | 1 |
| ?ledgr_compute_metrics | 1 |
| ?ledgr_demo_bars | 1 |
| ?ledgr_grid_cross | 1 |
| ?ledgr_ind_ttr | 1 |
| ?ledgr_parameters | 1 |
| ?ledgr_promotion_context | 1 |
| ?ledgr_run_promotion_context | 1 |
| ?ledgr_strategy_grid | 1 |
| ?print.ledgr_precomputed_features | 1 |
| ?signal_return | 1 |
| AGENT_PROMPT.md | 1 |
| installed ledgr/examples/README.md | 1 |
| LEDGR_DOCS/scripts/indicators.R | 1 |
| LEDGR_DOCS/scripts/strategy-development.R | 1 |

### Discovery Friction Evidence

| source | episode_id | evidence |
| --- | --- | --- |
| feedback_summary | 2026-05-26_001_cold_start_readme | Installed package has no obvious top-level README first-run example |
| feedback_summary | 2026-05-26_001_cold_start_readme | Getting-started first-run example depends on suggested tidyverse helpers |
| feedback_summary | 2026-05-26_001_cold_start_readme | Cleanup pattern in getting-started is unclear for copied scripts |
| feedback_summary | 2026-05-26_001_cold_start_readme | Git status is blocked by safe-directory ownership check |
| feedback_summary | 2026-05-26_002_cold_start_getting_started | Rendered getting-started output has stale config hash |
| feedback_summary | 2026-05-26_003_single_asset_sma_crossover | No direct documented contract inspection path for active-alias feature parameters |
| feedback_summary | 2026-05-26_003_single_asset_sma_crossover | summary(bt) is easy to double-print in scripts |
| feedback_summary | 2026-05-26_004_multi_asset_momentum | Last-bar no-fill warning can look like a failed run in first examples |
| feedback_summary | 2026-05-26_005_edge_case_ten_bars | Impossible warmup is only visible after calling summary |
| feedback_summary | 2026-05-26_006_close_lifecycle | Closed backtest handle result access is not stated explicitly |
| feedback_summary | 2026-05-26_006_close_lifecycle | Close guidance mentions lazy result cursors without a discoverable example |
| feedback_summary | 2026-05-26_007_help_page_discoverability | Core execution help pages do not link to Getting Started |
| feedback_summary | 2026-05-26_007_help_page_discoverability | Help article links do not show the runnable vignette script path |
| feedback_summary | 2026-05-26_007_help_page_discoverability | Runnable strategy-development examples emit expected warning to stderr |
| feedback_summary | 2026-05-26_007_help_page_discoverability | Wrapped help text is easy to parse incorrectly |
| feedback_summary | 2026-05-26_008_feature_map_strategy_authoring | ctx$features is not directly discoverable as a help topic |
| feedback_summary | 2026-05-26_008_feature_map_strategy_authoring | ctx$features examples disagree on whether feature_map is required |
| feedback_summary | 2026-05-26_008_feature_map_strategy_authoring | passed_warmup empty-input example does not show how to inspect error classes |
| feedback_summary | 2026-05-26_009_pulse_inspection_views | ledgr_pulse_snapshot help does not explain active alias maps |
| feedback_summary | 2026-05-26_009_pulse_inspection_views | Pulse view help examples are not standalone |
| feedback_summary | 2026-05-26_010_mixed_builtin_ttr_feature_map | Warmup docs do not show how to verify first fills against stable_after |
| feedback_summary | 2026-05-26_011_multi_lookback_pre_registration | Exact multi-lookback parameter-grid example is not runnable end to end |
| feedback_summary | 2026-05-26_011_multi_lookback_pre_registration | Alias names and concrete feature IDs are easy to confuse |
| feedback_summary | 2026-05-26_011_multi_lookback_pre_registration | Git status sanity check blocked by safe.directory ownership |
| feedback_summary | 2026-05-26_012_ctx_features_discoverability | Feature-map help does not link directly to formal strategy context reference |
| feedback_summary | 2026-05-26_012_ctx_features_discoverability | Strategy-development example omits feature_map argument to ctx$features() |
| feedback_summary | 2026-05-26_014_sweep_basic_candidate_promotion | Listed sweeps script is not runnable |
| feedback_summary | 2026-05-26_014_sweep_basic_candidate_promotion | Direct ledgr_param_grid promotion path is hard to find |
| feedback_summary | 2026-05-26_014_sweep_basic_candidate_promotion | final_equity comparison needs ledgr_results despite compute_metrics step |
| feedback_summary | 2026-05-26_014_sweep_basic_candidate_promotion | ledgr_sweep help does not enumerate result schema |
| feedback_summary | 2026-05-26_016_sweep_feature_factory | Exact-ID feature factory sweep lacks a complete runnable example |
| feedback_summary | 2026-05-26_016_sweep_feature_factory | Pulse feature inspection accepts list for snapshot but not for feature filtering |
| feedback_summary | 2026-05-26_016_sweep_feature_factory | Sweep docs do not explain duplicated params and feature_params for legacy factories |
| feedback_summary | 2026-05-26_017_sweep_precomputed_features | Missing runnable feature-factory precompute example |
| feedback_summary | 2026-05-26_017_sweep_precomputed_features | Precomputed print help omits displayed fields |
| feedback_summary | 2026-05-26_017_sweep_precomputed_features | Documentation snapshot lacks sweep intent group |
| feedback_summary | 2026-05-26_017_sweep_precomputed_features | PowerShell inline R expression expanded dollar sign |
| feedback_summary | 2026-05-26_018_sweep_seed_and_promotion_context | No minimal stochastic sweep replay example |
| feedback_summary | 2026-05-26_018_sweep_seed_and_promotion_context | Promotion candidate_summary structure is not explicit |
| feedback_summary | 2026-05-26_019_multi_output_indicator_bundles | Task identity expectation conflicts with installed bundle ID docs |
| feedback_summary | 2026-05-26_019_multi_output_indicator_bundles | Bundle factory examples do not show how strategies should read features |
| feedback_summary | 2026-05-26_020_adversarial_preflight_and_force_override | Tier 2 example conflicts with stats::median behavior |
| feedback_summary | 2026-05-26_020_adversarial_preflight_and_force_override | Defined external variables are Tier 2, not Tier 3 |
| feedback_summary | 2026-05-26_020_adversarial_preflight_and_force_override | Doc snapshot task-intent map omits strategy preflight topic |
| feedback_summary | 2026-05-26_020_adversarial_preflight_and_force_override | Git status blocked by unsafe repository ownership |
| feedback_summary | 2026-05-26_021_final_bar_no_fill_warning | Last-bar warning boundary is ambiguous for next-open runs |
| feedback_summary | 2026-05-26_022_inspection_surfaces_map | Sweeps script is listed as runnable but contains no runnable sweep |
| feedback_summary | 2026-05-26_022_inspection_surfaces_map | Inspection map does not fully route sweep and promotion setup |
| feedback_summary | 2026-05-26_022_inspection_surfaces_map | Printed final equity is rounded while table/comparison values are exact |
| feedback_summary | 2026-05-26_023_adversarial_preflight_v0_1_8_2_additions | Sweep grid APIs are easy to mix up for a first sweep |
| feedback_summary | 2026-05-26_025_active_alias_end_to_end | Help pages omit one-argument ctx features active-alias lookup |
| feedback_summary | 2026-05-26_025_active_alias_end_to_end | bt config stores strategy params under strategy_params not params |
| feedback_summary | 2026-05-26_025_active_alias_end_to_end | ledgr_run config does not expose feature_set_hash |
| feedback_summary | 2026-05-26_025_active_alias_end_to_end | ledgr_parameters help lacks an example for reading required feature params |
| feedback_summary | 2026-05-26_025_active_alias_end_to_end | ledgr_param help does not point to the full active-alias workflow |
| feedback_summary | 2026-05-26_025_active_alias_end_to_end | PowerShell glob passed to rg produced an invalid path error |
| feedback_summary | 2026-05-26_026_two_namespace_contract_errors | Wrong-namespace strategy parameter fails as generic replacement error |
| feedback_summary | 2026-05-26_026_two_namespace_contract_errors | Sparse docs for intentionally incomplete executable sweep rows |
| feedback_summary | 2026-05-26_026_two_namespace_contract_errors | Recursive raw log search hit locked session logs |
| feedback_summary | 2026-05-26_026_two_namespace_contract_errors | PowerShell expanded `$` inside inline R expression |
| feedback_summary | 2026-05-26_027_executable_grid_composition | Grid helper help lacks executable candidate schema examples |
| feedback_summary | 2026-05-26_027_executable_grid_composition | Mixing cross-product grids with explicit named candidates is unclear |
| feedback_summary | 2026-05-26_027_executable_grid_composition | Legacy parameter-grid help contains stale separate-API wording |
| feedback_summary | 2026-05-26_027_executable_grid_composition | Legacy flat-grid sweep row shape is not explained |
| feedback_summary | 2026-05-26_028_alias_aware_pulse_inspection | Indicators vignette does not demonstrate alias-aware default pulse views |
| feedback_summary | 2026-05-26_028_alias_aware_pulse_inspection | Inline named character alias maps lack a concrete pulse-view example |
| feedback_summary | 2026-05-26_029_alias_identity_and_declaration_order | alias_map_hash changes when the same alias points to a different concrete feature |
| feedback_summary | 2026-05-26_029_alias_identity_and_declaration_order | No-argument ctx$features(id) active-alias lookup is underdocumented |
| feedback_summary | 2026-05-26_030_parameterized_bundle_outputs_in_sweeps | Parameterized TTR bundle feature map is rejected by ledgr_experiment |
| feedback_summary | 2026-05-26_030_parameterized_bundle_outputs_in_sweeps | ledgr_feature_contracts gives a low-level error for unresolved parameterized bundles |
| feedback_summary | 2026-05-26_030_parameterized_bundle_outputs_in_sweeps | Hash-suffix scheme is not shown at the user-facing level |
| feedback_summary | 2026-05-26_030_parameterized_bundle_outputs_in_sweeps | Feature factory parameter routing is ambiguous with feature_params and feature grids |
| feedback_summary | 2026-05-26_030_parameterized_bundle_outputs_in_sweeps | Task snippet omits required input argument for ledgr_ind_ttr_outputs |
| feedback_summary | 2026-05-26_030_parameterized_bundle_outputs_in_sweeps | BBands pctB alias casing is easy to misread |
| research_report | 2026-05-26_001_cold_start_readme | - No ledgr runtime error blocked the task. \| - A final `git status --short` check was blocked by Git's safe-directory |
| research_report | 2026-05-26_002_cold_start_getting_started | - No ledgr runtime failure blocked the task. |
| research_report | 2026-05-26_004_multi_asset_momentum | - The first implementation path was directly supported by `LEDGR_DOCS/strategy-development.md`; no blocked debugging iterations were needed. |
| research_report | 2026-05-26_005_edge_case_ten_bars | - The no-indicator `buy_if_up_qty` strategy produced 2 fills and 1 closed trade, confirming that the small dataset is not inherently blocked. |
| research_report | 2026-05-26_006_close_lifecycle | No ledgr API failure blocked the task. The main friction was documentation \| `RUN_R.cmd` avoided PowerShell quoting issues. No stderr output was produced by |
| research_report | 2026-05-26_007_help_page_discoverability | - The first consolidated `reproducible_script.R` attempt failed because my regex expected `vignette("name", package = "ledgr")` to remain on one line. `Rd2txt` wraps help output across lines. I fixed this by collapsing help text before using a whitespace-tolerant regex. Evidence: `raw_logs/debug_iteration_1_regex_failure.txt`. |
| research_report | 2026-05-26_012_ctx_features_discoverability | main friction was documentation navigation rather than runtime behavior: |
| research_report | 2026-05-26_013_strategy_preflight_and_tier_classification | confirmed it was blocked before writing a run artifact, and ran the Tier 1 \| rows after it, confirming no `tier_3_blocked` run artifact was written. |
| research_report | 2026-05-26_015_sweep_failure_rows | - No actionable ledgr documentation gap, unclear ledgr error, missing API, or package bug was found during this episode, so `framework_feedback.md` remains an empty YAML list. |
| research_report | 2026-05-26_018_sweep_seed_and_promotion_context | The main documentation friction was that the seed/promotion behavior was |
| research_report | 2026-05-26_023_adversarial_preflight_v0_1_8_2_additions | This was a resolved workflow/documentation friction item and is recorded in `framework_feedback.md`. |
| research_report | 2026-05-26_025_active_alias_end_to_end | Succeeded for the executable active-alias workflow, with one blocked sub-check: `bt$config` did not expose `feature_set_hash`, so I could not confirm literal `feature_set_hash` equality from `ledgr_run()` output. I confirmed instead that the resolved concrete feature definitions and fingerprints for run 1 and run 3 were identical. |
| research_report | 2026-05-26_026_two_namespace_contract_errors | - Searching both `LEDGR_DOCS` and `raw_logs` with `rg` hit locked Codex session |
| research_report | 2026-05-26_030_parameterized_bundle_outputs_in_sweeps | The direct documented active-alias workflow then blocked at \| Blocked for the main task. \| blocked |

## Agent And Harness Performance

### Runner Types

| runner_type | episodes |
| --- | --- |
| codex | 30 |

### Runner Models

| runner_model | episodes |
| --- | --- |
| (blank) | 30 |

### Runner Exit Status

| runner_exit_status | episodes |
| --- | --- |
| 0 | 30 |

### Check Status

| check_status | episodes |
| --- | --- |
| (blank) | 30 |

## Prompt And Task Quality

- Review repeated duplicate candidates, missing source_docs rows, and
  documentation discovery friction before choosing the next task theme.
- Confirm whether task briefs were too broad, too narrow, or missing
  constraints before promoting generated follow-up tasks.

## Next-Cycle Theme Candidates

- Identity hash contract
- Parameterized bundle sweep blockers
- Beginner docs and runnable examples
- Feature map and alias inspection
- Sweep grids and result schema

## Maintainer Notes

- TODO: Record final duplicate decisions.
- TODO: Record which ledgr fixes, docs, or tests should be prioritized.
- TODO: Choose the next cycle theme.
