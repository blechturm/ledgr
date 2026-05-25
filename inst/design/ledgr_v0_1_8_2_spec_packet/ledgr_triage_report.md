# ledgr UX Triage Report

Source: `C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.8.1/categorized_feedback.yml`

This is a maintainer-review artifact. It does not create GitHub issues,
does not execute ledgr workflows, and does not decide final defect truth.


## Validation

- well formed: yes
- errors: 0
- warnings: 0
- themes: 7
- item classifications: 30

## Bucket Counts

| bucket | items |
| --- | --- |
| docs_gap | 17 |
| unclear | 7 |
| expected_user_error | 3 |
| ledgr_bug | 2 |
| bad_example | 1 |

## Severity Counts

| severity | items |
| --- | --- |
| high | 2 |
| medium | 5 |
| low | 23 |

## Theme Priority Table

| theme_id | severity | bucket | episode_count | feedback_count | title | recommended_action |
| --- | --- | --- | --- | --- | --- | --- |
| THEME-001 | high | ledgr_bug | 3 | 7 | Preflight Contract Alignment | Reconcile ledgr_strategy_preflight behavior with the reproducibility documentation, then add compact examples for tier_1, tier_2, tier_3, helper reuse, and no-force rejection wording. |
| THEME-002 | medium | docs_gap | 3 | 7 | Workflow Documentation Gaps | Add small end-to-end examples and task-intent map entries for Yahoo import, sweeps, promotion replay checks, compare-runs setup, and report-safe metric export. |
| THEME-003 | medium | unclear | 2 | 3 | Indicator Bundle Ergonomics | Decide whether bundle IDs should be identity-compatible with single-output indicators, then document or change naming/filter behavior and improve duplicate bundle collision wording. |
| THEME-004 | medium | unclear | 1 | 3 | CSV Error Clarity | Document high-level CSV error classes or wrap failures consistently, then add standardized timestamp and snapshot-creation failure messages. |
| THEME-005 | low | docs_gap | 4 | 6 | Inspection Troubleshooting Examples | Expand troubleshooting and inspection docs with minimal runnable snippets and improve warning/error text where runtime context is missing. |
| THEME-006 | low | expected_user_error | 3 | 3 | Episode Environment Friction | Add auditr episode guidance for one-topic doc helper calls, targeted evidence-log searches on Windows, and expected Yahoo dependency stderr noise. |
| THEME-007 | low | docs_gap | 1 | 1 | Real Data Benchmarks | Add real-data benchmark examples for flat, buy-and-hold, equal-weight, and single-instrument comparisons using Yahoo snapshots. |

## High Priority Themes

### THEME-001 - Preflight Contract Alignment

- bucket: `ledgr_bug`
- severity: `high`
- episodes: 3
- feedback rows: 7
- evidence: Raw feedback and reports show Sys.time and superassignment did not follow the expected tier_3 path, resolved globals conflicted with params-boundary guidance, examples did not reliably produce the expected tier, and helper functions were rejected as unresolved symbols.
- recommended action: Reconcile ledgr_strategy_preflight behavior with the reproducibility documentation, then add compact examples for tier_1, tier_2, tier_3, helper reuse, and no-force rejection wording.
- uncertainty: Some rows are clear behavior bugs, while others may be intentional tier semantics that need stronger documentation rather than code changes.

## Issue Candidate Themes

These are grouped findings suitable for maintainer review. They are not GitHub issues yet.
### THEME-001 - Preflight Contract Alignment

- bucket: `ledgr_bug`
- severity: `high`
- episodes: 3
- feedback rows: 7
- evidence: Raw feedback and reports show Sys.time and superassignment did not follow the expected tier_3 path, resolved globals conflicted with params-boundary guidance, examples did not reliably produce the expected tier, and helper functions were rejected as unresolved symbols.
- recommended action: Reconcile ledgr_strategy_preflight behavior with the reproducibility documentation, then add compact examples for tier_1, tier_2, tier_3, helper reuse, and no-force rejection wording.
- uncertainty: Some rows are clear behavior bugs, while others may be intentional tier semantics that need stronger documentation rather than code changes.

### THEME-002 - Workflow Documentation Gaps

- bucket: `docs_gap`
- severity: `medium`
- episodes: 3
- feedback rows: 7
- evidence: Users had to infer Yahoo sealing semantics, Cartesian grid construction, promotion replay verification, warning handling in sweeps and promotions, experiment-first setup for comparison, Yahoo discoverability, and raw report-ready comparison exports.
- recommended action: Add small end-to-end examples and task-intent map entries for Yahoo import, sweeps, promotion replay checks, compare-runs setup, and report-safe metric export.
- uncertainty: Evidence supports documentation work; only the grid helper row might become a missing API if maintainers prefer a helper over vignette guidance.

### THEME-003 - Indicator Bundle Ergonomics

- bucket: `unclear`
- severity: `medium`
- episodes: 2
- feedback rows: 3
- evidence: Bundle default IDs differed from equivalent single-output TTR IDs, partial naming needed explicit output filtering, and duplicate-prefix bundle flattening reported a duplicate alias without explaining the generated feature ID collision.
- recommended action: Decide whether bundle IDs should be identity-compatible with single-output indicators, then document or change naming/filter behavior and improve duplicate bundle collision wording.
- uncertainty: The ID mismatch could be an API bug or an intentional shorter-ID convention that needs a prominent note.

### THEME-004 - CSV Error Clarity

- bucket: `unclear`
- severity: `medium`
- episodes: 1
- feedback rows: 3
- evidence: CSV validation failures surfaced high-level classes different from the documented low-level CSV class, timestamp errors did not name UTC or trailing-Z requirements, and failures did not state artifact state or next action.
- recommended action: Document high-level CSV error classes or wrap failures consistently, then add standardized timestamp and snapshot-creation failure messages.
- uncertainty: The intended class boundary between ledgr_snapshot_from_csv and lower-level CSV import is not clear from the raw evidence.

### THEME-005 - Inspection Troubleshooting Examples

- bucket: `docs_gap`
- severity: `low`
- episodes: 4
- feedback rows: 6
- evidence: Feedback repeatedly asks for runnable inspection snippets: final-bar extension verification, feature inspection via pulse snapshots, fills extraction, pre-validation target-name checks, closed-trade versus fill distinction, and run context in final-bar warnings.
- recommended action: Expand troubleshooting and inspection docs with minimal runnable snippets and improve warning/error text where runtime context is missing.
- uncertainty: Most rows are docs gaps; the multi-run warning row may require ledgr warning metadata changes rather than documentation alone.

### THEME-006 - Episode Environment Friction

- bucket: `expected_user_error`
- severity: `low`
- episodes: 3
- feedback rows: 3
- evidence: Feedback covers scalar-only doc helper use, locked active Codex logs during recursive raw log search, and harmless quantmod startup output on stderr.
- recommended action: Add auditr episode guidance for one-topic doc helper calls, targeted evidence-log searches on Windows, and expected Yahoo dependency stderr noise.
- uncertainty: These appear to be expected environment or helper-use issues, not ledgr core defects.

### THEME-007 - Real Data Benchmarks

- bucket: `docs_gap`
- severity: `low`
- episodes: 1
- feedback rows: 1
- evidence: The unguided Yahoo report found no obvious buy-and-hold or equal-weight real-data benchmark example and hand-rolled equal-weight target sizing.
- recommended action: Add real-data benchmark examples for flat, buy-and-hold, equal-weight, and single-instrument comparisons using Yahoo snapshots.
- uncertainty: Evidence supports a docs gap; a dedicated benchmark helper could be considered later but is not required by the feedback.

