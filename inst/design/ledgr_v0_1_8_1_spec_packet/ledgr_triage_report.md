# ledgr UX Triage Report

Source: `C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.8/categorized_feedback.yml`

This is a maintainer-review artifact. It does not create GitHub issues,
does not execute ledgr workflows, and does not decide final defect truth.


## Validation

- well formed: yes
- errors: 0
- warnings: 1
- themes: 9
- item classifications: 97

## Bucket Counts

| bucket | items |
| --- | --- |
| docs_gap | 74 |
| duplicate | 9 |
| expected_user_error | 5 |
| unclear | 5 |
| missing_api | 4 |

## Severity Counts

| severity | items |
| --- | --- |
| medium | 14 |
| low | 83 |

## Theme Priority Table

| theme_id | severity | bucket | episode_count | feedback_count | title | recommended_action |
| --- | --- | --- | --- | --- | --- | --- |
| THEME-002 | medium | docs_gap | 13 | 22 | Feature, indicator, and warmup contracts need clearer user-facing guidance | Add a compact feature lifecycle guide covering registration, IDs and aliases, map/list accepted shapes, warmup diagnostics, current-bar requirements, and live-object parameter errors. |
| THEME-001 | medium | docs_gap | 11 | 12 | Runnable first-run and vignette examples are incomplete or misleading | Audit installed runnable scripts and first-run examples; prioritize complete smoke tests for ledgr_run, closed-trade inspection, indicators, strategy recovery, custom indicators, and sweeps. |
| THEME-004 | medium | docs_gap | 11 | 14 | Result inspection, metrics, and comparison outputs obscure schemas or numeric types | Document return values and schemas for summary, comparison, metrics, ledger/events, feature persistence, and closed-trade versus fill terminology; expose missing programmatic fields where appropriate. |
| THEME-003 | medium | docs_gap | 8 | 14 | Strategy helper pipeline docs lack troubleshooting and complete setup paths | Create a helper-pipeline troubleshooting table and one complete multi-asset example showing setup, parameter changes, validation failures, and zero-trade diagnosis. |
| THEME-006 | medium | docs_gap | 6 | 12 | Sweep, promotion, precompute, and seed workflows are present but underspecified | Update sweeps docs around v0.1.8 support, failure rows, feature factories, precompute structure, promotion context schema, cross-snapshot opt-in, and stochastic seed replay. |
| THEME-009 | medium | unclear | 5 | 6 | Terse or ambiguous warnings and errors make diagnosis harder | Improve warning text and docs with origin, consequence, and next-step pointers; consider public validation support for causal vectorized features. |
| THEME-005 | medium | docs_gap | 4 | 7 | Snapshot, sealing, and metadata docs need field-level examples | Add a low-level CSV snapshot and sealing walkthrough plus a field-by-field snapshot_info/meta_json reference. |
| THEME-008 | low | expected_user_error | 5 | 5 | Runner and local environment friction affected reproducibility but is mostly expected user error | Harden task briefs and runner templates with UTF-8/no-BOM guidance, safe log-search patterns, generated help index names, and longer sweep timeouts. |
| THEME-007 | low | docs_gap | 4 | 4 | Version and discoverability signals are stale or scattered | Refresh version labels and add a central installed article/help index with current workflow entry points. |

## High Priority Themes

No high priority themes.

## Issue Candidate Themes

These are grouped findings suitable for maintainer review. They are not GitHub issues yet.
### THEME-002 - Feature, indicator, and warmup contracts need clearer user-facing guidance

- bucket: `docs_gap`
- severity: `medium`
- episodes: 13
- feedback rows: 22
- evidence: Rows cluster around feature ID shapes, built-in versus custom indicator signatures, warmup/current-bar feasibility, pre-registration, and how to inspect mapped features.
- recommended action: Add a compact feature lifecycle guide covering registration, IDs and aliases, map/list accepted shapes, warmup diagnostics, current-bar requirements, and live-object parameter errors.
- uncertainty: Some findings may be documentation gaps around intended behavior rather than runtime defects.

### THEME-001 - Runnable first-run and vignette examples are incomplete or misleading

- bucket: `docs_gap`
- severity: `medium`
- episodes: 11
- feedback rows: 12
- evidence: Multiple episodes had to stitch together installed help pages, vignettes, or manual code because advertised runnable examples were absent, empty, or did not exercise the requested workflow.
- recommended action: Audit installed runnable scripts and first-run examples; prioritize complete smoke tests for ledgr_run, closed-trade inspection, indicators, strategy recovery, custom indicators, and sweeps.
- uncertainty: Duplicate detection is advisory because some rows refer to different docs with the same underlying example gap.

### THEME-004 - Result inspection, metrics, and comparison outputs obscure schemas or numeric types

- bucket: `docs_gap`
- severity: `medium`
- episodes: 11
- feedback rows: 14
- evidence: Several rows show that printed summaries and comparison tables are useful for humans but leave scripts guessing about closed trades, raw numeric columns, schemas, constants, or persisted feature values.
- recommended action: Document return values and schemas for summary, comparison, metrics, ledger/events, feature persistence, and closed-trade versus fill terminology; expose missing programmatic fields where appropriate.
- uncertainty: The rows do not prove all missing fields are intended public APIs; maintainer decision needed.

### THEME-003 - Strategy helper pipeline docs lack troubleshooting and complete setup paths

- bucket: `docs_gap`
- severity: `medium`
- episodes: 8
- feedback rows: 14
- evidence: Helper users repeatedly needed examples that bridge individual helper pages to full experiment setup and clearer guidance for type, selection, tier, and zero-trade diagnostics.
- recommended action: Create a helper-pipeline troubleshooting table and one complete multi-asset example showing setup, parameter changes, validation failures, and zero-trade diagnosis.
- uncertainty: Some task wording itself contributed to confusion, so fixes may belong in task briefs as well as ledgr docs.

### THEME-006 - Sweep, promotion, precompute, and seed workflows are present but underspecified

- bucket: `docs_gap`
- severity: `medium`
- episodes: 6
- feedback rows: 12
- evidence: Sweep episodes exposed gaps in current-version messaging, cross-snapshot promotion opt-in wording, list-column export guidance, failure-row promotion, feature factories, precompute payloads, and seed replay.
- recommended action: Update sweeps docs around v0.1.8 support, failure rows, feature factories, precompute structure, promotion context schema, cross-snapshot opt-in, and stochastic seed replay.
- uncertainty: One runtime timeout is environmental and should inform task/runner defaults rather than ledgr behavior.

### THEME-009 - Terse or ambiguous warnings and errors make diagnosis harder

- bucket: `unclear`
- severity: `medium`
- episodes: 5
- feedback rows: 6
- evidence: Warnings around last-bar no-fill behavior and leakage/causality boundaries were repeatedly understandable only after extra investigation.
- recommended action: Improve warning text and docs with origin, consequence, and next-step pointers; consider public validation support for causal vectorized features.
- uncertainty: Some rows are explicitly uncertain and should be validated by maintainers before issue creation.

### THEME-005 - Snapshot, sealing, and metadata docs need field-level examples

- bucket: `docs_gap`
- severity: `medium`
- episodes: 4
- feedback rows: 7
- evidence: CSV import, one-argument snapshot inspection, seal metadata names, meta_json fields, and already-sealed Yahoo snapshots all caused avoidable ambiguity.
- recommended action: Add a low-level CSV snapshot and sealing walkthrough plus a field-by-field snapshot_info/meta_json reference.
- uncertainty: One validation-error row is unclear because evidence supports poor locality but not necessarily an incorrect validator.

### THEME-008 - Runner and local environment friction affected reproducibility but is mostly expected user error

- bucket: `expected_user_error`
- severity: `low`
- episodes: 5
- feedback rows: 5
- evidence: Episodes hit PowerShell UTF-8 BOM parsing, active log files during recursive search, guessed help snapshot filenames, and short outer timeouts for long sweeps.
- recommended action: Harden task briefs and runner templates with UTF-8/no-BOM guidance, safe log-search patterns, generated help index names, and longer sweep timeouts.
- uncertainty: These rows should not be treated as ledgr bugs without additional raw evidence.

### THEME-007 - Version and discoverability signals are stale or scattered

- bucket: `docs_gap`
- severity: `low`
- episodes: 4
- feedback rows: 4
- evidence: Users saw v0.1.7 labels in a v0.1.8 context, source-tree design-file pointers, and article links without a single installed help index.
- recommended action: Refresh version labels and add a central installed article/help index with current workflow entry points.
- uncertainty: The workflows still generally ran, so this is mostly orientation risk.


## Validation Problems

| severity | check | message |
| --- | --- | --- |
| warning | summary_episode_count | summary$episodes_reviewed does not match episode_index rows. |
