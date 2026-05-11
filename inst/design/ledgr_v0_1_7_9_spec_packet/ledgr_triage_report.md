# ledgr UX Triage Report

Source: `C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.7.8/categorized_feedback.yml`

This is a maintainer-review artifact. It does not create GitHub issues,
does not execute ledgr workflows, and does not decide final defect truth.


## Validation

- well formed: yes
- errors: 0
- warnings: 0
- themes: 10
- item classifications: 82

## Bucket Counts

| bucket | items |
| --- | --- |
| docs_gap | 61 |
| expected_user_error | 11 |
| unclear | 6 |
| ledgr_bug | 2 |
| missing_api | 2 |

## Severity Counts

| severity | items |
| --- | --- |
| high | 1 |
| medium | 9 |
| low | 72 |

## Theme Priority Table

| theme_id | severity | bucket | episode_count | feedback_count | title | recommended_action |
| --- | --- | --- | --- | --- | --- | --- |
| THEME-004 | medium | unclear | 8 | 9 | Runtime errors and warnings need more actionable messages | Add ledgr-specific error context: offending rows, instruments, timestamps, unsupported alternatives, matched unsafe calls, and registration hints. |
| THEME-005 | medium | docs_gap | 7 | 10 | Experiment store, run comparison, and persisted results need stronger programmatic examples | Add programmatic workflows for comparison tables, equity follow-up, recovery/rerun, run_info fields, and persisted feature access. |
| THEME-002 | medium | docs_gap | 5 | 7 | Indicator feature IDs, warmup, and helper contracts are under-documented | Expand indicator help pages with generated IDs, warmup/stability fields, dependency preflights, and concise strategy-oriented examples. |
| THEME-003 | medium | unclear | 5 | 7 | Feature map compatibility is inconsistent across APIs | Normalize accepted feature declaration types or document each API boundary explicitly, with See Also links for accessors, contracts, pulse views, and warmup. |
| THEME-006 | medium | docs_gap | 2 | 5 | Custom indicator scalar and vectorized contracts conflict | Document scalar and series_fn signatures, precedence, equivalence expectations, leakage testing patterns, and params behavior across run and pulse evaluators. |
| THEME-001 | medium | docs_gap | 1 | 3 | First-run and smoke-test docs need clearer executable paths | Provide a runnable base-R smoke test in the package overview or README path and point optional-dependency examples to it. |
| THEME-008 | low | expected_user_error | 9 | 10 | Windows and episode-runner friction recurs across manual runs | Keep these separate from ledgr defects and improve episode guidance with saved-script patterns, quoted RUN_R examples, and raw_logs exclusion advice. |
| THEME-009 | low | docs_gap | 7 | 10 | Strategy helper and lifecycle docs need small worked edge cases | Add small worked examples or reference tables for these edge cases while keeping helper docs concise. |
| THEME-007 | low | docs_gap | 4 | 5 | Snapshot import, sealing, metadata, and live data lifecycle need consolidated docs | Centralize snapshot lifecycle examples for CSV and Yahoo paths, including schema, sealing semantics, snapshot_info columns, and meta_json keys. |
| THEME-010 | low | docs_gap | 3 | 5 | Metrics and summary output need clearer scripted usage guidance | Clarify summary return value, direct users to ledgr_compute_metrics for programmatic extraction, and document Sharpe edge cases and annualization constants. |

## High Priority Themes

No high priority themes.

## Issue Candidate Themes

These are grouped findings suitable for maintainer review. They are not GitHub issues yet.
### THEME-004 - Runtime errors and warnings need more actionable messages

- bucket: `unclear`
- severity: `medium`
- episodes: 8
- feedback rows: 9
- evidence: Rows cite bare warning codes, generic match.arg output, missing offending rows or instruments, duplicated classes, and messages that omit the likely fix.
- recommended action: Add ledgr-specific error context: offending rows, instruments, timestamps, unsupported alternatives, matched unsafe calls, and registration hints.
- uncertainty: Some rows may be expected user errors, but the evidence supports improving message clarity.

### THEME-005 - Experiment store, run comparison, and persisted results need stronger programmatic examples

- bucket: `docs_gap`
- severity: `medium`
- episodes: 7
- feedback rows: 10
- evidence: Rows describe unclear same-run resume behavior, truncated comparison printing, missing raw metric examples, incomplete strategy recovery examples, undocumented run-info fields, and no documented persisted-feature retrieval path.
- recommended action: Add programmatic workflows for comparison tables, equity follow-up, recovery/rerun, run_info fields, and persisted feature access.
- uncertainty: The persisted-feature item is high priority and may be an API gap or documentation gap depending on intended behavior.

### THEME-002 - Indicator feature IDs, warmup, and helper contracts are under-documented

- bucket: `docs_gap`
- severity: `medium`
- episodes: 5
- feedback rows: 7
- evidence: Multiple rows report needing to infer feature IDs, native versus TTR indicator choices, dependency fallback behavior, and warmup fields from scattered docs or runtime probes.
- recommended action: Expand indicator help pages with generated IDs, warmup/stability fields, dependency preflights, and concise strategy-oriented examples.
- uncertainty: Some issues are documentation-only; the evidence does not establish incorrect indicator computation.

### THEME-003 - Feature map compatibility is inconsistent across APIs

- bucket: `unclear`
- severity: `medium`
- episodes: 5
- feedback rows: 7
- evidence: Rows show ledgr_feature_map objects working for contracts or pulse inspection but failing in ledgr_backtest, plus discoverability gaps for ctx accessors and warmup helpers.
- recommended action: Normalize accepted feature declaration types or document each API boundary explicitly, with See Also links for accessors, contracts, pulse views, and warmup.
- uncertainty: Because behavior differs by function, classify as unclear until maintainers decide intended compatibility.

### THEME-006 - Custom indicator scalar and vectorized contracts conflict

- bucket: `docs_gap`
- severity: `medium`
- episodes: 2
- feedback rows: 5
- evidence: Rows report missing corrected series_fn examples, no causal validator, inconsistent fn(window) versus fn(window, params) docs, unclear scalar/series_fn precedence, and a pulse snapshot params mismatch.
- recommended action: Document scalar and series_fn signatures, precedence, equivalence expectations, leakage testing patterns, and params behavior across run and pulse evaluators.
- uncertainty: The params mismatch includes runtime evidence, but whether to fix behavior or docs is a maintainer decision.

### THEME-001 - First-run and smoke-test docs need clearer executable paths

- bucket: `docs_gap`
- severity: `medium`
- episodes: 1
- feedback rows: 3
- evidence: Cold-start rows describe non-executable README-style examples, package overview smoke-test discoverability gaps, and suggested-package dependencies in the first getting-started workflow.
- recommended action: Provide a runnable base-R smoke test in the package overview or README path and point optional-dependency examples to it.
- uncertainty: No conflicting raw evidence found; episode 002 had an empty feedback list and is not represented as an item.

### THEME-008 - Windows and episode-runner friction recurs across manual runs

- bucket: `expected_user_error`
- severity: `low`
- episodes: 9
- feedback rows: 10
- evidence: Rows mention locked live logs, headless R help server output, PowerShell dollar expansion, accidental shell execution of R code, namespace mistakes, and fragile log capture.
- recommended action: Keep these separate from ledgr defects and improve episode guidance with saved-script patterns, quoted RUN_R examples, and raw_logs exclusion advice.
- uncertainty: These are primarily episode-environment or user-runner issues, not ledgr source issues.

### THEME-009 - Strategy helper and lifecycle docs need small worked edge cases

- bucket: `docs_gap`
- severity: `low`
- episodes: 7
- feedback rows: 10
- evidence: Rows request examples for helper discovery, tier consistency, three-instrument rotation, sizing drift, closed trades, post-close access, partial NA handling, diagnostics and preflight classes, and ledger event meanings.
- recommended action: Add small worked examples or reference tables for these edge cases while keeping helper docs concise.
- uncertainty: Most rows are low-severity documentation gaps with clear workarounds.

### THEME-007 - Snapshot import, sealing, metadata, and live data lifecycle need consolidated docs

- bucket: `docs_gap`
- severity: `low`
- episodes: 4
- feedback rows: 5
- evidence: Rows show users cross-checking CSV contracts, sealing state, snapshot_info column names, meta_json schema, and Yahoo sealed-snapshot lifecycle across multiple docs.
- recommended action: Centralize snapshot lifecycle examples for CSV and Yahoo paths, including schema, sealing semantics, snapshot_info columns, and meta_json keys.
- uncertainty: No evidence that sealing behavior is wrong; issue is mostly discoverability.

### THEME-010 - Metrics and summary output need clearer scripted usage guidance

- bucket: `docs_gap`
- severity: `low`
- episodes: 3
- feedback rows: 5
- evidence: Rows report duplicate-style summary output in wrappers, missing flat-strategy Sharpe output, implicit annualization constants, and uneven risk_free_rate docs.
- recommended action: Clarify summary return value, direct users to ledgr_compute_metrics for programmatic extraction, and document Sharpe edge cases and annualization constants.
- uncertainty: Duplicate summary output may be intentional invisible-return behavior but is surprising in scripts.

