# ledgr UX Triage Report

Source: `C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.8.3/categorized_feedback.yml`

This is a maintainer-review artifact. It does not create GitHub issues,
does not execute ledgr workflows, and does not decide final defect truth.


## Validation

- well formed: yes
- errors: 0
- warnings: 0
- themes: 10
- item classifications: 56

## Bucket Counts

| bucket | items |
| --- | --- |
| docs_gap | 31 |
| bad_example | 5 |
| duplicate | 5 |
| missing_api | 5 |
| unclear | 4 |
| expected_user_error | 3 |
| ledgr_bug | 3 |

## Severity Counts

| severity | items |
| --- | --- |
| medium | 10 |
| low | 46 |

## Theme Priority Table

| theme_id | severity | bucket | episode_count | feedback_count | title | recommended_action |
| --- | --- | --- | --- | --- | --- | --- |
| THEME-001 | medium | docs_gap | 8 | 10 | Runnable examples and doc routing gaps | Tighten the generated doc snapshot intent map and only list runnable vignette scripts when they contain useful executable workflow code. |
| THEME-002 | medium | docs_gap | 4 | 8 | Sweep ranking, promotion, and provenance inspection | Add a single sweep inspection and promotion verification recipe covering ranking, ledgr_candidate metadata, provenance list columns, final_equity lookup, and replay metrics. |
| THEME-007 | medium | missing_api | 4 | 6 | Indicator authoring and causal validation | Document indicator registry lifecycle, strategy context runtime types, causal-validation limits, and pulse feature setup in one authoring-focused guide. |
| THEME-003 | medium | docs_gap | 3 | 7 | Feature factory and precompute boundaries | Document a complete feature-factory precompute workflow and make bundle identity constraints explicit, including safe feature IDs when parameters vary. |
| THEME-004 | medium | docs_gap | 3 | 5 | Strategy preflight boundaries and messages | Add a compact preflight boundary table and verification snippets, then align task examples with current tier behavior. |
| THEME-005 | medium | docs_gap | 3 | 5 | Metric context lifecycle and overrides | Create one runnable metric-context lifecycle example and document public fields or accessors for risk-free-rate provenance and annual_rate. |
| THEME-006 | medium | docs_gap | 2 | 7 | Yahoo and real-data workflow clarity | Add a Yahoo/live-data troubleshooting and baseline-comparison section with explicit adapter semantics, dependencies, and research-sample cleanup choices. |
| THEME-010 | low | docs_gap | 4 | 4 | Accounting and metric surface semantics | Add cross-surface examples that explain where execution events, equity state, final equity, Sharpe, and trade metrics live. |
| THEME-008 | low | unclear | 3 | 5 | Error message actionability | Revise user-facing errors to include expected classes, unchanged artifact state, next action, and the most relevant violation first. |
| THEME-009 | low | expected_user_error | 3 | 3 | Episode environment and PowerShell guidance | Add Windows-safe examples for fixed-string rg searches, line ranges, and ledgr_save_help output filenames to episode instructions. |

## High Priority Themes

No high priority themes.

## Issue Candidate Themes

These are grouped findings suitable for maintainer review. They are not GitHub issues yet.
### THEME-001 - Runnable examples and doc routing gaps

- bucket: `docs_gap`
- severity: `medium`
- episodes: 8
- feedback rows: 10
- evidence: Multiple episodes had to assemble workflows from scattered help pages or were routed to empty/near-empty runnable scripts and incomplete task-intent maps.
- recommended action: Tighten the generated doc snapshot intent map and only list runnable vignette scripts when they contain useful executable workflow code.
- uncertainty: Duplicates are advisory because some rows concern auditr doc-discovery output while others concern ledgr documentation content.

### THEME-002 - Sweep ranking, promotion, and provenance inspection

- bucket: `docs_gap`
- severity: `medium`
- episodes: 4
- feedback rows: 8
- evidence: Users repeatedly needed base R ranking patterns that preserve sweep metadata, flat provenance extraction, and cross-surface promotion replay checks.
- recommended action: Add a single sweep inspection and promotion verification recipe covering ranking, ledgr_candidate metadata, provenance list columns, final_equity lookup, and replay metrics.
- uncertainty: One print-footer issue may be implementation behavior rather than documentation only.

### THEME-007 - Indicator authoring and causal validation

- bucket: `missing_api`
- severity: `medium`
- episodes: 4
- feedback rows: 6
- evidence: Feedback asks for clearer causal-validator limits, same-ID deregistration guidance, series_fn-only or diagnostic guidance, duplicate registration behavior, timestamp comparison type, and runnable pulse helper examples.
- recommended action: Document indicator registry lifecycle, strategy context runtime types, causal-validation limits, and pulse feature setup in one authoring-focused guide.
- uncertainty: The no-causal-validator row is a confirmed absence from public docs, not proof that no internal tooling exists.

### THEME-003 - Feature factory and precompute boundaries

- bucket: `docs_gap`
- severity: `medium`
- episodes: 3
- feedback rows: 7
- evidence: Feedback points to missing examples for parameterized features, feature hashes, precompute printing, grid mismatch diagnostics, SMA warmup interpretation, and bundle ID collisions.
- recommended action: Document a complete feature-factory precompute workflow and make bundle identity constraints explicit, including safe feature IDs when parameters vary.
- uncertainty: The bundle duplicate-ID row is marked bug in feedback but may resolve as either a documented restriction or an API change.

### THEME-004 - Strategy preflight boundaries and messages

- bucket: `docs_gap`
- severity: `medium`
- episodes: 3
- feedback rows: 5
- evidence: Episodes found mismatches or ambiguity around Tier 1/Tier 2/Tier 3 examples, run-row absence after abort, and which indirection bodies preflight inspects.
- recommended action: Add a compact preflight boundary table and verification snippets, then align task examples with current tier behavior.
- uncertainty: Some rows are task-brief mismatches rather than package defects.

### THEME-005 - Metric context lifecycle and overrides

- bucket: `docs_gap`
- severity: `medium`
- episodes: 3
- feedback rows: 5
- evidence: Users needed clearer examples for context creation, print/provenance inspection, scalar risk-free access, sweep experiment-level context, and comparison default context.
- recommended action: Create one runnable metric-context lifecycle example and document public fields or accessors for risk-free-rate provenance and annual_rate.
- uncertainty: The comparison default-context row is classified unclear because behavior may be intentional but surprising.

### THEME-006 - Yahoo and real-data workflow clarity

- bucket: `docs_gap`
- severity: `medium`
- episodes: 2
- feedback rows: 7
- evidence: Live-data episodes surfaced ambiguity about Yahoo sealing, TTR availability, harmless quantmod stderr, price adjustment policy, same-capital baselines, final-bar warnings, and trade metrics for open positions.
- recommended action: Add a Yahoo/live-data troubleshooting and baseline-comparison section with explicit adapter semantics, dependencies, and research-sample cleanup choices.
- uncertainty: Some items are documentation gaps while TTR-native Bollinger support would be a missing API if maintainers want no optional dependency.

### THEME-010 - Accounting and metric surface semantics

- bucket: `docs_gap`
- severity: `low`
- episodes: 4
- feedback rows: 4
- evidence: Users needed clearer separation between ledger rows, equity rows, standard metric objects, final_equity, and closed-trade metrics.
- recommended action: Add cross-surface examples that explain where execution events, equity state, final equity, Sharpe, and trade metrics live.
- uncertainty: Promotion final_equity rows are duplicates across tasks but remain separate feedback rows.

### THEME-008 - Error message actionability

- bucket: `unclear`
- severity: `low`
- episodes: 3
- feedback rows: 5
- evidence: Rows describe correct failures whose messages omit missing labels, artifact state, high-level CSV class mapping, duplicate feature-ID framing, or prioritization of mutation over unresolved-symbol wording.
- recommended action: Revise user-facing errors to include expected classes, unchanged artifact state, next action, and the most relevant violation first.
- uncertainty: CSV and bundle rows may be solved by docs if message changes are not desired.

### THEME-009 - Episode environment and PowerShell guidance

- bucket: `expected_user_error`
- severity: `low`
- episodes: 3
- feedback rows: 3
- evidence: Episodes hit PowerShell range syntax, dollar-sign quoting, and saved-help filename guessability problems.
- recommended action: Add Windows-safe examples for fixed-string rg searches, line ranges, and ledgr_save_help output filenames to episode instructions.
- uncertainty: These are episode UX issues rather than ledgr runtime defects.

