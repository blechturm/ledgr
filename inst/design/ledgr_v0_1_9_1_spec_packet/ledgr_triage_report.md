# ledgr UX Triage Report

Source: `C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.8.11/categorized_feedback.yml`

This is a maintainer-review artifact. It does not create GitHub issues,
does not execute ledgr workflows, and does not decide final defect truth.


## Validation

- well formed: yes
- errors: 0
- warnings: 0
- themes: 10
- item classifications: 133

## Bucket Counts

| bucket | items |
| --- | --- |
| docs_gap | 89 |
| unclear | 15 |
| expected_user_error | 14 |
| missing_api | 12 |
| ledgr_bug | 3 |

## Severity Counts

| severity | items |
| --- | --- |
| high | 5 |
| medium | 32 |
| low | 96 |

## Theme Priority Table

| theme_id | severity | bucket | episode_count | feedback_count | title | recommended_action |
| --- | --- | --- | --- | --- | --- | --- |
| THEME-004 | high | unclear | 10 | 16 | Hashes And Reproducibility Identity | Define and document the public identity contract for feature, alias, config, snapshot, metric-context, and sweep hashes; investigate high-severity invariant mismatches. |
| THEME-005 | medium | docs_gap | 15 | 21 | Errors Warnings And Diagnostics | Document condition classes and add minimal fail-closed examples with visible diagnostic fields and actionable messages. |
| THEME-002 | medium | docs_gap | 14 | 18 | Strategy Context And Indicators | Expand reference cross-links and runnable examples for ctx$features, parameterized feature maps, helper pipelines, and active-alias inspection. |
| THEME-003 | medium | docs_gap | 14 | 29 | Sweep And Candidate Workflows | Add end-to-end sweep examples covering named grids, feature factories, candidate reproduction keys, promotion context, worker setup, and failure rows. |
| THEME-010 | medium | docs_gap | 8 | 8 | Runnable Examples And Reference Completeness | Fill reference-page examples and value sections where users had to infer field shapes, setup objects, or edge-case behavior. |
| THEME-006 | medium | docs_gap | 5 | 9 | Metrics And Accounting Surfaces | Clarify metric defaults, NA rules, metric-context lifecycle, accounting model scope, and fill-count availability in run and sweep outputs. |
| THEME-008 | low | expected_user_error | 13 | 13 | Windows And Runner Friction | Harden episode/task guidance with Windows-safe command patterns, log-search excludes, and explicit target-version checks. |
| THEME-007 | low | docs_gap | 7 | 11 | CSV Snapshot And Bundle Lifecycle | Add lifecycle examples that go from CSV or bundle registration through sealing, inspection, validation failures, and run execution. |
| THEME-001 | low | docs_gap | 3 | 4 | Onboarding And Documentation Entry Points | Add explicit start-here, task-intent, and inspection-map pointers in installed overview and rendered docs. |
| THEME-009 | low | docs_gap | 1 | 4 | Disclaimer Discoverability | Install or relink the formal disclaimer and surface it from package overview, doc index, relevant articles, and NEWS references. |

## High Priority Themes

### THEME-004 - Hashes And Reproducibility Identity

- bucket: `unclear`
- severity: `high`
- episodes: 10
- feedback rows: 16
- evidence: Identity rows include missing hash extraction examples plus high-severity raw evidence that feature_set_hash was unavailable and config/alias hashes changed against task invariants.
- recommended action: Define and document the public identity contract for feature, alias, config, snapshot, metric-context, and sweep hashes; investigate high-severity invariant mismatches.
- uncertainty: Includes high-severity raw evidence and docs gaps; maintainer should decide which hash behaviors are contractual defects versus documentation gaps.

## Issue Candidate Themes

These are grouped findings suitable for maintainer review. They are not GitHub issues yet.
### THEME-004 - Hashes And Reproducibility Identity

- bucket: `unclear`
- severity: `high`
- episodes: 10
- feedback rows: 16
- evidence: Identity rows include missing hash extraction examples plus high-severity raw evidence that feature_set_hash was unavailable and config/alias hashes changed against task invariants.
- recommended action: Define and document the public identity contract for feature, alias, config, snapshot, metric-context, and sweep hashes; investigate high-severity invariant mismatches.
- uncertainty: Includes high-severity raw evidence and docs gaps; maintainer should decide which hash behaviors are contractual defects versus documentation gaps.

### THEME-005 - Errors Warnings And Diagnostics

- bucket: `docs_gap`
- severity: `medium`
- episodes: 15
- feedback rows: 21
- evidence: Warning and error reports show missing help topics, generic messages, ambiguous classes, and diagnostic examples that do not expose the key columns or offending inputs.
- recommended action: Document condition classes and add minimal fail-closed examples with visible diagnostic fields and actionable messages.
- uncertainty: Theme is advisory grouping; individual item evidence remains authoritative.

### THEME-002 - Strategy Context And Indicators

- bucket: `docs_gap`
- severity: `medium`
- episodes: 14
- feedback rows: 18
- evidence: Rows cluster around ctx accessors, feature maps, indicators, helper pipelines, active aliases, and pulse feature lookup examples.
- recommended action: Expand reference cross-links and runnable examples for ctx$features, parameterized feature maps, helper pipelines, and active-alias inspection.
- uncertainty: Theme is advisory grouping; individual item evidence remains authoritative.

### THEME-003 - Sweep And Candidate Workflows

- bucket: `docs_gap`
- severity: `medium`
- episodes: 14
- feedback rows: 29
- evidence: Sweep, grid, candidate, promotion, precompute, parallel, and discard-all workflows repeatedly needed more concrete examples and schema guidance.
- recommended action: Add end-to-end sweep examples covering named grids, feature factories, candidate reproduction keys, promotion context, worker setup, and failure rows.
- uncertainty: Theme is advisory grouping; individual item evidence remains authoritative.

### THEME-010 - Runnable Examples And Reference Completeness

- bucket: `docs_gap`
- severity: `medium`
- episodes: 8
- feedback rows: 8
- evidence: Remaining rows ask for standalone examples, clearer value fields, or reference details that reduce first-run inference.
- recommended action: Fill reference-page examples and value sections where users had to infer field shapes, setup objects, or edge-case behavior.
- uncertainty: Theme is advisory grouping; individual item evidence remains authoritative.

### THEME-006 - Metrics And Accounting Surfaces

- bucket: `docs_gap`
- severity: `medium`
- episodes: 5
- feedback rows: 9
- evidence: Metric-context, Sharpe/risk-free-rate, accounting-model, fill-count, and spot-FIFO rows point to missing or indirect result-surface explanations.
- recommended action: Clarify metric defaults, NA rules, metric-context lifecycle, accounting model scope, and fill-count availability in run and sweep outputs.
- uncertainty: Theme is advisory grouping; individual item evidence remains authoritative.

### THEME-008 - Windows And Runner Friction

- bucket: `expected_user_error`
- severity: `low`
- episodes: 13
- feedback rows: 13
- evidence: Several rows are about PowerShell quoting/BOM behavior, locked live logs, rg glob pitfalls, stderr from optional dependencies, and task-version mismatches.
- recommended action: Harden episode/task guidance with Windows-safe command patterns, log-search excludes, and explicit target-version checks.
- uncertainty: These are advisory runner/task-environment issues and should not be treated as ledgr source defects without separate confirmation.

### THEME-007 - CSV Snapshot And Bundle Lifecycle

- bucket: `docs_gap`
- severity: `low`
- episodes: 7
- feedback rows: 11
- evidence: CSV, snapshot, seal-to-run, bundle registration, and parameterized bundle rows repeatedly ask for lifecycle examples and validation-order clarity.
- recommended action: Add lifecycle examples that go from CSV or bundle registration through sealing, inspection, validation failures, and run execution.
- uncertainty: Theme is advisory grouping; individual item evidence remains authoritative.

### THEME-001 - Onboarding And Documentation Entry Points

- bucket: `docs_gap`
- severity: `low`
- episodes: 3
- feedback rows: 4
- evidence: First-contact package surfaces, indexes, task-intent maps, and inspection maps often require inference to find the intended starting point.
- recommended action: Add explicit start-here, task-intent, and inspection-map pointers in installed overview and rendered docs.
- uncertainty: Theme is advisory grouping; individual item evidence remains authoritative.

### THEME-009 - Disclaimer Discoverability

- bucket: `docs_gap`
- severity: `low`
- episodes: 1
- feedback rows: 4
- evidence: The installed research workflow links to a missing disclaimer path, and normal overview surfaces do not expose the formal disclaimer.
- recommended action: Install or relink the formal disclaimer and surface it from package overview, doc index, relevant articles, and NEWS references.
- uncertainty: Theme is advisory grouping; individual item evidence remains authoritative.

