# ledgr UX Triage Report

Source: `C:/Users/maxth/Documents/GitHub/auditr/episodes/categorized_feedback.yml`

## Validation

- well formed: yes
- errors: 0
- warnings: 0
- themes: 9
- item classifications: 51

## Bucket Counts

| bucket | items |
| --- | --- |
| docs_gap | 25 |
| duplicate | 19 |
| missing_api | 3 |
| bad_example | 2 |
| expected_user_error | 1 |
| ledgr_bug | 1 |

## Severity Counts

| severity | items |
| --- | --- |
| high | 3 |
| medium | 25 |
| low | 23 |

## Theme Priority Table

| theme_id | severity | bucket | episode_count | feedback_count | title | recommended_action |
| --- | --- | --- | --- | --- | --- | --- |
| THEME-001 | high | docs_gap | 10 | 15 | Installed narrative docs and runnable examples are missing | Ship and install a v0.1.7 getting-started vignette, strategy-development article, and at least one runnable offline example covering snapshot creation, experiment-first runs, result extraction, and cleanup. |
| THEME-009 | high | ledgr_bug | 1 | 1 | One likely MACD warmup runtime defect | Reproduce in ledgr tests and fix or document MACD macd-output warmup so constructed indicators do not fail on first feature computation. |
| THEME-002 | medium | bad_example | 4 | 5 | Experiment-first workflow competes with compatibility examples | Make the experiment-first path the package-level start-here example, cross-link compatibility helpers to it, and align or explicitly explain differing defaults. |
| THEME-003 | medium | docs_gap | 4 | 8 | Feature ID and indicator strategy documentation is too implicit | Add indicator-to-strategy examples showing ledgr_feature_id(), ctx$feature(), feature attachment, and exact IDs for built-in and TTR indicators. |
| THEME-004 | medium | docs_gap | 3 | 3 | Warmup and short-history behavior needs clearer guidance | Document warmup and NA handling in strategy docs with short-history success and failure examples; separately investigate the MACD warmup rule. |
| THEME-006 | medium | missing_api | 1 | 2 | Sizing and allocation APIs are less natural than user tasks | Document full named target-vector shape and consider helpers or examples for target weights, cash-aware sizing, and all-in winner allocation. |
| THEME-007 | medium | docs_gap | 1 | 4 | Run discovery and comparison semantics are underdocumented | Document the current explicit-run-ID workflow, add tag/label filtering examples or APIs, and explain comparison metric semantics such as closed trades. |
| THEME-008 | medium | docs_gap | 1 | 1 | Snapshot CSV lifecycle has surprising seal and metadata behavior | Document high-level and low-level CSV snapshot workflows separately, including auto-seal behavior, reseal return values, and how start/end metadata is populated or supplied. |
| THEME-005 | low | expected_user_error | 8 | 7 | Windows shell one-liners obscure R examples using dollar syntax | Prefer .R script-file execution in Windows-facing docs and include PowerShell-safe quoting only where one-liners are necessary. |

## High Priority Themes

### THEME-001 - Installed narrative docs and runnable examples are missing

- bucket: `docs_gap`
- severity: `high`
- episodes: 10
- feedback rows: 15
- evidence: Across all 10 episodes, installed vignettes were repeatedly absent, README/pkgdown/article material was not discoverable from the installed package, installed examples were non-executable, and users had to stitch workflows from individual help pages.
- recommended action: Ship and install a v0.1.7 getting-started vignette, strategy-development article, and at least one runnable offline example covering snapshot creation, experiment-first runs, result extraction, and cleanup.
- uncertainty: No parser diagnostics were reported; raw markdown consistently supports the theme.

### THEME-009 - One likely MACD warmup runtime defect

- bucket: `ledgr_bug`
- severity: `high`
- episodes: 1
- feedback rows: 1
- evidence: ledgr_ind_ttr('MACD', output = 'macd', nFast = 12, nSlow = 26, nSig = 9, percent = FALSE) reported requires_bars = 26, but ledgr_pulse_snapshot() failed with not enough non-NA values; overriding requires_bars and stable_after to 34 worked.
- recommended action: Reproduce in ledgr tests and fix or document MACD macd-output warmup so constructed indicators do not fail on first feature computation.
- uncertainty: Raw evidence supports likely bug, but this reviewer did not execute ledgr workflows.

## Issue Candidate Themes

These are grouped findings suitable for maintainer review. They are not GitHub issues yet.

### THEME-001 - Installed narrative docs and runnable examples are missing

- bucket: `docs_gap`
- severity: `high`
- episodes: 10
- feedback rows: 15
- evidence: Across all 10 episodes, installed vignettes were repeatedly absent, README/pkgdown/article material was not discoverable from the installed package, installed examples were non-executable, and users had to stitch workflows from individual help pages.
- recommended action: Ship and install a v0.1.7 getting-started vignette, strategy-development article, and at least one runnable offline example covering snapshot creation, experiment-first runs, result extraction, and cleanup.
- uncertainty: No parser diagnostics were reported; raw markdown consistently supports the theme.

### THEME-009 - One likely MACD warmup runtime defect

- bucket: `ledgr_bug`
- severity: `high`
- episodes: 1
- feedback rows: 1
- evidence: ledgr_ind_ttr('MACD', output = 'macd', nFast = 12, nSlow = 26, nSig = 9, percent = FALSE) reported requires_bars = 26, but ledgr_pulse_snapshot() failed with not enough non-NA values; overriding requires_bars and stable_after to 34 worked.
- recommended action: Reproduce in ledgr tests and fix or document MACD macd-output warmup so constructed indicators do not fail on first feature computation.
- uncertainty: Raw evidence supports likely bug, but this reviewer did not execute ledgr workflows.

### THEME-002 - Experiment-first workflow competes with compatibility examples

- bucket: `bad_example`
- severity: `medium`
- episodes: 4
- feedback rows: 5
- evidence: Multiple episodes report that ledgr_backtest examples are easier to find than the v0.1.7 ledgr_experiment plus ledgr_run path, and one episode found default cash differences when switching between workflows.
- recommended action: Make the experiment-first path the package-level start-here example, cross-link compatibility helpers to it, and align or explicitly explain differing defaults.
- uncertainty: Compatibility APIs worked; evidence supports documentation and example-priority friction rather than a runtime defect.

### THEME-003 - Feature ID and indicator strategy documentation is too implicit

- bucket: `docs_gap`
- severity: `medium`
- episodes: 4
- feedback rows: 8
- evidence: SMA, momentum, RSI, Bollinger Bands, and MACD episodes all needed ledgr_feature_id() and ctx$feature() patterns that were discoverable but not shown end to end.
- recommended action: Add indicator-to-strategy examples showing ledgr_feature_id(), ctx$feature(), feature attachment, and exact IDs for built-in and TTR indicators.
- uncertainty: The APIs worked once discovered; classification is documentation gap except where separate runtime evidence exists.

### THEME-004 - Warmup and short-history behavior needs clearer guidance

- bucket: `docs_gap`
- severity: `medium`
- episodes: 3
- feedback rows: 3
- evidence: Users had to infer NA guards for SMA warmup, expected behavior for 10-bar histories, and encountered a likely MACD warmup mismatch.
- recommended action: Document warmup and NA handling in strategy docs with short-history success and failure examples; separately investigate the MACD warmup rule.
- uncertainty: MACD item has runtime failure evidence and is classified as a likely bug; the other items are documentation gaps.

### THEME-006 - Sizing and allocation APIs are less natural than user tasks

- bucket: `missing_api`
- severity: `medium`
- episodes: 1
- feedback rows: 2
- evidence: The multi-asset task asked for allocation toward a stronger asset, but docs exposed target holdings and ctx$flat() rather than weight or cash-aware allocation helpers.
- recommended action: Document full named target-vector shape and consider helpers or examples for target weights, cash-aware sizing, and all-in winner allocation.
- uncertainty: Could be solved as documentation first; helper API need should be weighed by maintainer.

### THEME-007 - Run discovery and comparison semantics are underdocumented

- bucket: `docs_gap`
- severity: `medium`
- episodes: 1
- feedback rows: 4
- evidence: The experiment-store episode found param_grid non-executing, no documented tag or label filters for ledgr_run_list(), compare by run IDs only, and n_trades = 0 despite fill/trade rows.
- recommended action: Document the current explicit-run-ID workflow, add tag/label filtering examples or APIs, and explain comparison metric semantics such as closed trades.
- uncertainty: n_trades may be expected semantics; do not mark it a bug without maintainer validation.

### THEME-008 - Snapshot CSV lifecycle has surprising seal and metadata behavior

- bucket: `docs_gap`
- severity: `medium`
- episodes: 1
- feedback rows: 1
- evidence: CSV import auto-sealed through ledgr_snapshot_from_df(), resealing a sealed snapshot object returned a hash rather than the expected already-sealed error, and low-level CSV import needed explicit start/end for backtest.
- recommended action: Document high-level and low-level CSV snapshot workflows separately, including auto-seal behavior, reseal return values, and how start/end metadata is populated or supplied.
- uncertainty: Single parsed row contains several subfindings; maintainer should split if converting to issues.

### THEME-005 - Windows shell one-liners obscure R examples using dollar syntax

- bucket: `expected_user_error`
- severity: `low`
- episodes: 8
- feedback rows: 7
- evidence: PowerShell expanded ctx$flat(), ctx$close(), data-frame $, and $fn examples in repeated command-line attempts, causing failures before ledgr ran.
- recommended action: Prefer .R script-file execution in Windows-facing docs and include PowerShell-safe quoting only where one-liners are necessary.
- uncertainty: Raw feedback treats this as external to ledgr, so it should not be triaged as a ledgr runtime bug.
