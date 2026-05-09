# ledgr UX Triage Report

Source: `C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.7.5/categorized_feedback.yml`

This is a maintainer-review artifact. It does not create GitHub issues,
does not execute ledgr workflows, and does not decide final defect truth.

Maintainer curation note: the generated counts below still include
`THEME-010`, but that theme is an auditr runner/environment finding, not a
ledgr implementation issue. Do not include `THEME-010` in ledgr handoff
unless it is explicitly reframed as test-harness context.

## Validation

- well formed: yes
- errors: 0
- warnings: 0
- themes: 10
- item classifications: 64

## Bucket Counts

| bucket | items |
| --- | --- |
| docs_gap | 55 |
| expected_user_error | 5 |
| unclear | 4 |

## Severity Counts

| severity | items |
| --- | --- |
| high | 1 |
| medium | 2 |
| low | 61 |

## Theme Priority Table

| theme_id | severity | bucket | episode_count | feedback_count | title | recommended_action |
| --- | --- | --- | --- | --- | --- | --- |
| THEME-010 | high | expected_user_error | 3 | 3 | Episode environment and Windows friction | Add Windows-safe task instructions and preflight checks for encoding, glob usage, and Yahoo-dependent network tasks or provide allowed cached fixtures. |
| THEME-003 | medium | docs_gap | 6 | 8 | Summary, metrics, ledger, and result inspection clarity | Document direct summary(bt) usage, point unsupported metrics result requests to ledgr_compute_metrics(), expose or exemplify metric metadata, and clarify ledger versus portfolio state tables. |
| THEME-002 | medium | docs_gap | 5 | 7 | Strategy and feature-map authoring docs | Create or cross-link a pulse-context accessor reference and expand indicator helper pages with complete feature-map strategy examples. |
| THEME-004 | medium | docs_gap | 5 | 7 | Warmup, final-bar, zero-trade, and short-sample diagnostics | Add explicit examples and diagnostic notes for short samples, open fills, final-bar warnings, stable_after, and current-bar absence error classes. |
| THEME-005 | medium | docs_gap | 4 | 5 | Snapshot import, sealing, and metadata contracts | Consolidate CSV contract references, document implicit sealing and low-level minimum sequence, enumerate sealed meta_json fields, and list ledgr-controlled Yahoo arguments. |
| THEME-006 | medium | docs_gap | 4 | 7 | Experiment store, run IDs, and comparison workflow | Document run_id rules near creation, connect parameter grids to comparison and extraction workflows, preserve raw metric readability, and show result-table follow-up for equity curves. |
| THEME-007 | medium | docs_gap | 4 | 7 | Helper pipeline examples and errors | Adjust discovery task briefs, add three-asset helper examples, and improve helper warnings/errors with prevention patterns and next-helper guidance. |
| THEME-009 | medium | docs_gap | 4 | 6 | Public documentation boundaries and installed paths | Replace source-tree paths with installed-package references, remove stale version wording, and improve help aliases or task-intent mappings. |
| THEME-001 | medium | docs_gap | 3 | 4 | Runnable first examples and onboarding paths | Add a minimal ledgr-only smoke path, clarify copied-script cleanup, and cross-link core run and experiment help pages to the getting-started workflow. |
| THEME-008 | medium | docs_gap | 3 | 5 | Feature registration and parameter safety | Align feature declaration acceptance across APIs or document differences prominently; add pre-registration hints and finite-param examples. |

## Excluded High Priority Environment Finding

### THEME-010 - Episode environment and Windows friction

- bucket: `expected_user_error`
- severity: `high`
- episodes: 3
- feedback rows: 3
- evidence: Rows identify environmental issues outside ledgr behavior: UTF-8 BOM script failure, PowerShell rg glob syntax, and unavailable Yahoo endpoint from the episode environment.
- auditr action: Add Windows-safe task instructions and preflight checks for encoding, glob usage, and Yahoo-dependent network tasks or provide allowed cached fixtures. Network-dependent episodes must not be silently run under a sandbox that blocks outbound HTTPS.
- ledgr handoff status: Excluded. The Yahoo endpoint failure is high severity for the episode but appears environmental, not a ledgr bug. Keep only the separate ledgr documentation point about reserved Yahoo arguments under `THEME-005`.

## Issue Candidate Themes

These are grouped ledgr-facing findings suitable for maintainer review. They
are not GitHub issues yet. `THEME-010` is intentionally excluded because it is
an auditr runner/environment issue.

### THEME-003 - Summary, metrics, ledger, and result inspection clarity

- bucket: `docs_gap`
- severity: `medium`
- episodes: 6
- feedback rows: 8
- evidence: Rows cluster around result-reading confusion: summary double-printing when wrapped in print(), metrics requested through ledgr_results(), annualization frequency visibility, and ledger event semantics.
- recommended action: Document direct summary(bt) usage, point unsupported metrics result requests to ledgr_compute_metrics(), expose or exemplify metric metadata, and clarify ledger versus portfolio state tables.
- uncertainty: Duplicate links are advisory; summary print rows and metrics-result rows appear to describe the same user-facing behaviors.

### THEME-002 - Strategy and feature-map authoring docs

- bucket: `docs_gap`
- severity: `medium`
- episodes: 5
- feedback rows: 7
- evidence: Multiple rows report that indicator and feature-map help pages expose pieces of strategy authoring but lack complete or centrally discoverable ctx$features, warmup, and runnable strategy examples.
- recommended action: Create or cross-link a pulse-context accessor reference and expand indicator helper pages with complete feature-map strategy examples.
- uncertainty: Rows overlap but are not all exact duplicates because they cover different help topics and examples.

### THEME-004 - Warmup, final-bar, zero-trade, and short-sample diagnostics

- bucket: `docs_gap`
- severity: `medium`
- episodes: 5
- feedback rows: 7
- evidence: Episodes found that warmup exhaustion, last-bar no-fill warnings, zero closed trades with open fills, and current-bar absence require clearer diagnostics or examples.
- recommended action: Add explicit examples and diagnostic notes for short samples, open fills, final-bar warnings, stable_after, and current-bar absence error classes.
- uncertainty: Some rows are related diagnostics rather than duplicates because they occur at different stages of a run.

### THEME-005 - Snapshot import, sealing, and metadata contracts

- bucket: `docs_gap`
- severity: `medium`
- episodes: 4
- feedback rows: 5
- evidence: CSV and snapshot episodes needed clearer high-level versus low-level paths, CSV contracts, DB setup, sealed metadata keys, and reserved Yahoo ellipsis arguments.
- recommended action: Consolidate CSV contract references, document implicit sealing and low-level minimum sequence, enumerate sealed meta_json fields, and list ledgr-controlled Yahoo arguments.
- uncertainty: The invalid low-level episode still has one feedback_summary.csv row and is included as evidence.

### THEME-006 - Experiment store, run IDs, and comparison workflow

- bucket: `docs_gap`
- severity: `medium`
- episodes: 4
- feedback rows: 7
- evidence: Run comparison and durable experiment episodes report friction around immutable run IDs, labels, parameter grids, comparison print formatting, equity curve comparison, and strategy recovery reruns.
- recommended action: Document run_id rules near creation, connect parameter grids to comparison and extraction workflows, preserve raw metric readability, and show result-table follow-up for equity curves.
- uncertainty: Long run ID truncation and raw metric type display may be print-format documentation gaps or presentation API issues.

### THEME-007 - Helper pipeline examples and errors

- bucket: `docs_gap`
- severity: `medium`
- episodes: 4
- feedback rows: 7
- evidence: Helper episodes report a mix of task-brief leakage, missing multi-asset examples, warning provenance gaps, incomplete-coverage surprises, and helper error messages that need more actionable next steps.
- recommended action: Adjust discovery task briefs, add three-asset helper examples, and improve helper warnings/errors with prevention patterns and next-helper guidance.
- uncertainty: Some helper error rows were triaged unclear, so bucket assignment remains advisory.

### THEME-009 - Public documentation boundaries and installed paths

- bucket: `docs_gap`
- severity: `medium`
- episodes: 4
- feedback rows: 6
- evidence: Rows show stale version wording, source-tree paths in installed docs, missing lifecycle task routing, and discoverability issues for summary and close help topics.
- recommended action: Replace source-tree paths with installed-package references, remove stale version wording, and improve help aliases or task-intent mappings.
- uncertainty: The task-intent and guessed help-topic rows may belong to auditr or documentation routing rather than ledgr runtime behavior.

### THEME-001 - Runnable first examples and onboarding paths

- bucket: `docs_gap`
- severity: `medium`
- episodes: 3
- feedback rows: 4
- evidence: Cold-start episodes repeatedly needed clearer runnable entry points, safer copied-script cleanup guidance, and links from core help pages back to getting-started material.
- recommended action: Add a minimal ledgr-only smoke path, clarify copied-script cleanup, and cross-link core run and experiment help pages to the getting-started workflow.
- uncertainty: Evidence is from feedback rows; no ledgr source was inspected.

### THEME-008 - Feature registration and parameter safety

- bucket: `docs_gap`
- severity: `medium`
- episodes: 3
- feedback rows: 5
- evidence: Rows identify mismatches or omissions around feature map acceptance, finite JSON-safe params, pre-registering parameterized features, and using ledgr_feature_id() instead of guessed IDs.
- recommended action: Align feature declaration acceptance across APIs or document differences prominently; add pre-registration hints and finite-param examples.
- uncertainty: The feature-map ledgr_backtest incompatibility is medium severity and may indicate missing API consistency rather than only documentation.

