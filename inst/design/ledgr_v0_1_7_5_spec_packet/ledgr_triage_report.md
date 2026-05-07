# ledgr UX Triage Report

Source: `C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.7.4_second_run/categorized_feedback.yml`

This is a maintainer-review artifact. It does not create GitHub issues,
does not execute ledgr workflows, and does not decide final defect truth.

## Validation

- well formed: yes
- errors: 0
- warnings: 0
- themes: 10
- item classifications: 45

## Bucket Counts

| bucket | items |
| --- | --- |
| docs_gap | 30 |
| expected_user_error | 8 |
| missing_api | 2 |
| unclear | 2 |
| bad_example | 1 |
| duplicate | 1 |
| ledgr_bug | 1 |

## Severity Counts

| severity | items |
| --- | --- |
| high | 1 |
| medium | 3 |
| low | 41 |

## Theme Priority Table

| theme_id | severity | bucket | episode_count | feedback_count | title | recommended_action |
| --- | --- | --- | --- | --- | --- | --- |
| THEME-010 | high | ledgr_bug | 3 | 3 | Potential API or runtime defects need maintainer review | Prioritize a MACD regression investigation, then decide whether duplicate run_id and out-of-universe diagnostics are doc changes or error-message improvements. |
| THEME-001 | medium | docs_gap | 4 | 7 | Runnable starter workflows are scattered | Add or link compact end-to-end examples for smoke tests, multi-asset data shape, high-level CSV sealing, and low-level create/import/seal/load/run workflows. |
| THEME-002 | medium | docs_gap | 4 | 6 | Indicator strategy examples need broader coverage | Extend the indicators vignette and indicator help pages with explicit crossover, RSI mean-reversion, mixed built-in/TTR, and expected feature-ID examples. |
| THEME-003 | medium | docs_gap | 3 | 4 | Warmup and sample coverage are underexplained | Add a warmup troubleshooting section that connects indicator window sizes, feature contracts, available bars per instrument, current-bar availability, and zero-trade diagnosis. |
| THEME-004 | medium | docs_gap | 3 | 4 | Pulse and feature-map API docs have naming ambiguity | Create/searchable context accessor docs and align pulse helper argument docs around ledgr_feature_map versus plain indicator lists. |
| THEME-008 | low | expected_user_error | 6 | 6 | Episode environment and discovery helpers caused friction | Harden episode prompts and discovery helpers with Windows-safe search examples, close-match help-topic suggestions, stable log search guidance, and no-browser vignette paths. |
| THEME-005 | low | docs_gap | 4 | 4 | Strategy helper docs need failure and parameter examples | Add helper reference sections for warning/error classes, common mistakes, synthetic multi-asset rotation, and parameter variants requiring multiple registered features. |
| THEME-009 | low | expected_user_error | 3 | 3 | Task briefs contain conflicting or leading requirements | Revise episode task briefs independently of ledgr docs so audit constraints are internally consistent and do not leak discovery targets. |
| THEME-006 | low | docs_gap | 2 | 4 | Result lifecycle and metrics need clearer inspection contracts | Revise result examples and lifecycle docs to show closed trades, metric assumptions, post-close inspection, and explicit-open resource ownership. |
| THEME-007 | low | duplicate | 2 | 2 | Summary print behavior is duplicated feedback | Treat as one advisory issue unless maintainers find separate code paths. |

## High Priority Themes

### THEME-010 - Potential API or runtime defects need maintainer review

- bucket: `ledgr_bug`
- severity: `high`
- episodes: 3
- feedback rows: 3
- evidence: Raw MACD feedback reports an EMA not-enough-values failure unless requires_bars is overridden; duplicate run_id and direct target_rebalance errors were confusing but may be intended behavior with weak messaging.
- recommended action: Prioritize a MACD regression investigation, then decide whether duplicate run_id and out-of-universe diagnostics are doc changes or error-message improvements.
- uncertainty: Only the MACD item is categorized as a ledgr bug with high severity; the other two are kept unclear pending maintainer judgment.

## Issue Candidate Themes

These are grouped findings suitable for maintainer review. They are not GitHub issues yet.
### THEME-010 - Potential API or runtime defects need maintainer review

- bucket: `ledgr_bug`
- severity: `high`
- episodes: 3
- feedback rows: 3
- evidence: Raw MACD feedback reports an EMA not-enough-values failure unless requires_bars is overridden; duplicate run_id and direct target_rebalance errors were confusing but may be intended behavior with weak messaging.
- recommended action: Prioritize a MACD regression investigation, then decide whether duplicate run_id and out-of-universe diagnostics are doc changes or error-message improvements.
- uncertainty: Only the MACD item is categorized as a ledgr bug with high severity; the other two are kept unclear pending maintainer judgment.

### THEME-001 - Runnable starter workflows are scattered

- bucket: `docs_gap`
- severity: `medium`
- episodes: 4
- feedback rows: 7
- evidence: Cold-start, multi-asset, CSV, and low-level snapshot episodes repeatedly needed to combine multiple help pages or vignettes before reaching a complete runnable path.
- recommended action: Add or link compact end-to-end examples for smoke tests, multi-asset data shape, high-level CSV sealing, and low-level create/import/seal/load/run workflows.
- uncertainty: Low-level CSV findings came from a raw feedback file that parser diagnostics marked invalid, but the markdown evidence was readable.

### THEME-002 - Indicator strategy examples need broader coverage

- bucket: `docs_gap`
- severity: `medium`
- episodes: 4
- feedback rows: 6
- evidence: Episodes had to infer SMA crossover semantics, RSI experiment usage, built-in versus TTR RSI choice, MACD feature IDs, and mixed built-in plus TTR strategy wiring.
- recommended action: Extend the indicators vignette and indicator help pages with explicit crossover, RSI mean-reversion, mixed built-in/TTR, and expected feature-ID examples.
- uncertainty: 

### THEME-003 - Warmup and sample coverage are underexplained

- bucket: `docs_gap`
- severity: `medium`
- episodes: 3
- feedback rows: 4
- evidence: Short samples, SMA warmup, absent current bars, and per-instrument sample counts were not obvious from the first-pass docs and produced zero-trade or pulse-debugging confusion.
- recommended action: Add a warmup troubleshooting section that connects indicator window sizes, feature contracts, available bars per instrument, current-bar availability, and zero-trade diagnosis.
- uncertainty: The short-sample episode feedback came from raw markdown after parser failure.

### THEME-004 - Pulse and feature-map API docs have naming ambiguity

- bucket: `docs_gap`
- severity: `medium`
- episodes: 3
- feedback rows: 4
- evidence: Users confused plain feature lists with feature maps, could not find a ctx$features help topic, and found pulse help wording inconsistent with long-row alias behavior.
- recommended action: Create/searchable context accessor docs and align pulse helper argument docs around ledgr_feature_map versus plain indicator lists.
- uncertainty: 

### THEME-008 - Episode environment and discovery helpers caused friction

- bucket: `expected_user_error`
- severity: `low`
- episodes: 6
- feedback rows: 6
- evidence: PowerShell globbing, quoting, locked raw logs, exact help-topic lookup, and vignette browser behavior slowed headless/manual runs.
- recommended action: Harden episode prompts and discovery helpers with Windows-safe search examples, close-match help-topic suggestions, stable log search guidance, and no-browser vignette paths.
- uncertainty: These are mostly episode harness/documentation issues rather than ledgr API defects.

### THEME-005 - Strategy helper docs need failure and parameter examples

- bucket: `docs_gap`
- severity: `low`
- episodes: 4
- feedback rows: 4
- evidence: Helper episodes asked for warning classes, synthetic multi-asset helper setup, negative examples for invalid intermediate returns, and multi-lookback feature registration.
- recommended action: Add helper reference sections for warning/error classes, common mistakes, synthetic multi-asset rotation, and parameter variants requiring multiple registered features.
- uncertainty: 

### THEME-009 - Task briefs contain conflicting or leading requirements

- bucket: `expected_user_error`
- severity: `low`
- episodes: 3
- feedback rows: 3
- evidence: Briefs disclosed helper names while asking for discovery, disagreed with the documented zero-trade checklist count, and asked for a pulse both well past and still inside warmup.
- recommended action: Revise episode task briefs independently of ledgr docs so audit constraints are internally consistent and do not leak discovery targets.
- uncertainty: 

### THEME-006 - Result lifecycle and metrics need clearer inspection contracts

- bucket: `docs_gap`
- severity: `low`
- episodes: 2
- feedback rows: 4
- evidence: Docs did not clearly show a trade-producing ledgr_results example, expose annualization constants for metric checks, or state post-close result access behavior.
- recommended action: Revise result examples and lifecycle docs to show closed trades, metric assumptions, post-close inspection, and explicit-open resource ownership.
- uncertainty: 

