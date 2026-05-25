# ledgr UX Triage Report

Source: `C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.8.2/categorized_feedback.yml`

This is a maintainer-review artifact. It does not create GitHub issues,
does not execute ledgr workflows, and does not decide final defect truth.


## Validation

- well formed: yes
- errors: 0
- warnings: 0
- themes: 7
- item classifications: 57

## Bucket Counts

| bucket | items |
| --- | --- |
| docs_gap | 28 |
| unclear | 8 |
| bad_example | 7 |
| duplicate | 7 |
| expected_user_error | 4 |
| missing_api | 2 |
| ledgr_bug | 1 |

## Severity Counts

| severity | items |
| --- | --- |
| high | 1 |
| medium | 12 |
| low | 44 |

## Theme Priority Table

| theme_id | severity | bucket | episode_count | feedback_count | title | recommended_action |
| --- | --- | --- | --- | --- | --- | --- |
| THEME-002 | high | ledgr_bug | 3 | 10 | Preflight boundaries need clearer enforcement and diagnostics | Review static-analysis contract tests for dynamic dispatch and context mutation, then align task examples and reproducibility docs with the intended tier boundaries. |
| THEME-004 | medium | bad_example | 7 | 9 | Examples and task wording conflict with installed API behavior | Audit task briefs and installed examples against ledgr 0.1.8.2 behavior, then update examples or package behavior where the intended contract differs. |
| THEME-003 | medium | docs_gap | 6 | 11 | Metric context lifecycle docs and print surfaces are incomplete | Add end-to-end metric context examples and improve print/reference surfaces for risk-free rate, provenance, promotions, and override lifecycle. |
| THEME-001 | medium | docs_gap | 5 | 7 | Sweep inspection and report export need concrete accessors | Add focused sweep inspection and reporting examples, including failed-candidate accessors and an export-safe flat summary pattern. |
| THEME-006 | medium | docs_gap | 3 | 5 | Real Yahoo workflows need a more complete happy path | Add a full Yahoo research workflow that covers snapshot sealing, reruns after failure, expected dependency stderr chatter, and report-ready artifacts. |
| THEME-007 | low | docs_gap | 6 | 11 | Strategy inspection and troubleshooting surfaces need scriptable recipes | Add compact troubleshooting recipes and inspection snippets that are friendly to scripted episode evidence collection. |
| THEME-005 | low | unclear | 1 | 6 | Input and registration errors need more actionable context | Tighten error messages and add reference notes for CSV validation classes, timestamp requirements, OHLC row context, bundle collisions, and duplicate registration. |

## High Priority Themes

### THEME-002 - Preflight boundaries need clearer enforcement and diagnostics

- bucket: `ledgr_bug`
- severity: `high`
- episodes: 3
- feedback rows: 10
- evidence: Preflight task examples conflicted with installed tiering, forbidden-call contracts were underdocumented, and `do.call("Sys.time", list())` completed successfully despite Tier 1 classification.
- recommended action: Review static-analysis contract tests for dynamic dispatch and context mutation, then align task examples and reproducibility docs with the intended tier boundaries.
- uncertainty: The do.call string case appears high priority; mutable context attributes and captured environments need an explicit maintainer policy.

## Issue Candidate Themes

These are grouped findings suitable for maintainer review. They are not GitHub issues yet.
### THEME-002 - Preflight boundaries need clearer enforcement and diagnostics

- bucket: `ledgr_bug`
- severity: `high`
- episodes: 3
- feedback rows: 10
- evidence: Preflight task examples conflicted with installed tiering, forbidden-call contracts were underdocumented, and `do.call("Sys.time", list())` completed successfully despite Tier 1 classification.
- recommended action: Review static-analysis contract tests for dynamic dispatch and context mutation, then align task examples and reproducibility docs with the intended tier boundaries.
- uncertainty: The do.call string case appears high priority; mutable context attributes and captured environments need an explicit maintainer policy.

### THEME-004 - Examples and task wording conflict with installed API behavior

- bucket: `bad_example`
- severity: `medium`
- episodes: 7
- feedback rows: 9
- evidence: Episodes found mismatches in bundle ID expectations, target version metadata, ctx equity accessor syntax, Tier 2/Tier 3 examples, parameter-grid syntax, and multi-strategy workflow wording.
- recommended action: Audit task briefs and installed examples against ledgr 0.1.8.2 behavior, then update examples or package behavior where the intended contract differs.
- uncertainty: Several findings are not ledgr bugs unless the task/example text is confirmed as the intended contract.

### THEME-003 - Metric context lifecycle docs and print surfaces are incomplete

- bucket: `docs_gap`
- severity: `medium`
- episodes: 6
- feedback rows: 11
- evidence: Metric context rows repeatedly asked for explicit constructor fields, clearer labels, provenance/hash semantics, non-mutating override examples, and compact promotion context output.
- recommended action: Add end-to-end metric context examples and improve print/reference surfaces for risk-free rate, provenance, promotions, and override lifecycle.
- uncertainty: Most rows are docs gaps, but compact print output for promotion context may require a small API/print-method change.

### THEME-001 - Sweep inspection and report export need concrete accessors

- bucket: `docs_gap`
- severity: `medium`
- episodes: 5
- feedback rows: 7
- evidence: Multiple episodes needed exact list-column accessors, failed-candidate row fields, and flat export patterns because sweep results include nested columns.
- recommended action: Add focused sweep inspection and reporting examples, including failed-candidate accessors and an export-safe flat summary pattern.
- uncertainty: Some rows could be solved by documentation alone, while repeated CSV-export failures may justify a helper.

### THEME-006 - Real Yahoo workflows need a more complete happy path

- bucket: `docs_gap`
- severity: `medium`
- episodes: 3
- feedback rows: 5
- evidence: Real-data episodes hit unclear snapshot seal return shape, missing end-to-end Yahoo recipe, rerun lifecycle confusion, and quantmod stderr noise.
- recommended action: Add a full Yahoo research workflow that covers snapshot sealing, reruns after failure, expected dependency stderr chatter, and report-ready artifacts.
- uncertainty: The quantmod stderr items are probably expected environment behavior, but they still affect first-pass episode triage.

### THEME-007 - Strategy inspection and troubleshooting surfaces need scriptable recipes

- bucket: `docs_gap`
- severity: `low`
- episodes: 6
- feedback rows: 11
- evidence: Episodes needed scriptable paths for timestamp comparisons, no-fill warnings, print invisibility, raw metric types, zero-trade and zero-sizing diagnosis, fill-model fields, and intraday time extraction.
- recommended action: Add compact troubleshooting recipes and inspection snippets that are friendly to scripted episode evidence collection.
- uncertainty: PowerShell-specific rows are expected-user errors, but documenting the saved-script pattern would reduce repeated episode friction.

### THEME-005 - Input and registration errors need more actionable context

- bucket: `unclear`
- severity: `low`
- episodes: 1
- feedback rows: 6
- evidence: CSV and indicator-registration probes produced errors that were correct enough to fail, but often lacked precise column, row, instrument, or duplicate-feature context.
- recommended action: Tighten error messages and add reference notes for CSV validation classes, timestamp requirements, OHLC row context, bundle collisions, and duplicate registration.
- uncertainty: The raw evidence supports UX friction, but some wording changes may be lower priority than docs additions.
