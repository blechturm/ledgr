# ledgr UX Triage Report

Source: `C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.7.3/categorized_feedback.yml`

This is a maintainer-review artifact. It does not create GitHub issues,
does not execute ledgr workflows, and does not decide final defect truth.

## Validation

- well formed: yes
- errors: 0
- warnings: 0
- themes: 10
- item classifications: 98

## Bucket Counts

| bucket | items |
| --- | --- |
| unclear | 36 |
| docs_gap | 29 |
| duplicate | 26 |
| ledgr_bug | 4 |
| missing_api | 2 |
| bad_example | 1 |

## Severity Counts

| severity | items |
| --- | --- |
| medium | 16 |
| low | 82 |

## Theme Priority Table

| theme_id | severity | bucket | episode_count | feedback_count | title | recommended_action |
| --- | --- | --- | --- | --- | --- | --- |
| THEME-001 | medium | duplicate | 12 | 13 | Episode doc-discovery helpers fail on n = Inf | Fix or document the episode-local discovery helper full-read path and make save/read helper signatures unambiguous. |
| THEME-003 | medium | docs_gap | 5 | 6 | Strategy helper pages are discoverable only after reaching the vignette | Improve help-topic cross-links and examples for signal_return(), select_top_n(), weight_equal(), target_rebalance(), ledgr_signal_strategy(), and ledgr_target(). |
| THEME-004 | medium | docs_gap | 5 | 6 | Feature ID naming and registration create recurring first-use friction | Add stronger examples for named feature aliases, multi-output IDs, and parameter-grid feature registration. |
| THEME-005 | medium | docs_gap | 5 | 9 | Short-data, warmup, and final-bar behavior need a diagnosis recipe | Add a short-data and zero-trade troubleshooting section covering requires_bars, per-instrument warmup, pulse snapshots, empty selections, and final-bar no-fill warnings. |
| THEME-009 | medium | docs_gap | 3 | 5 | TTR and multi-output indicator APIs need stronger examples | Add examples for TTR dependency expectations, multi-output column selection, MACD argument matching, pulse debugging, and fingerprint-safe diagnostics. |
| THEME-002 | medium | docs_gap | 2 | 2 | Hidden article_utc helper breaks copy-paste examples | Show the helper before first use, inline as.POSIXct(..., tz = 'UTC'), or expose a public date-time helper. |
| THEME-010 | medium | ledgr_bug | 1 | 1 | Snapshot import/seal metadata path blocked a documented workflow | Investigate the documented snapshot import/seal path and either fix metadata handling or document the required metadata step. |
| THEME-007 | low | unclear | 6 | 7 | Shell and headless logging can misclassify successful workflows | Improve episode harness logging guidance: capture exit code, stdout, stderr, encoding, and headless vignette access separately. |
| THEME-006 | low | docs_gap | 4 | 6 | Summary and comparison outputs are display-first | Document structured alternatives for exact checks and make summary/comparison help discovery clearer. |
| THEME-008 | low | bad_example | 2 | 2 | Installed README and examples path is not a runnable start | Point first-start docs to runnable vignettes or make examples/README.md explicit that it is not the first runnable path. |

## High Priority Themes

No high priority themes.

## Issue Candidate Themes

These are grouped findings suitable for maintainer review. They are not GitHub issues yet.
### THEME-003 - Strategy helper pages are discoverable only after reaching the vignette

- bucket: `docs_gap`
- severity: `medium`
- episodes: 5
- feedback rows: 6
- evidence: Runs report missing or hard-to-find helper topics, absent Articles sections on some strategy-authoring pages, and no local examples on pipeline helper pages.
- recommended action: Improve help-topic cross-links and examples for signal_return(), select_top_n(), weight_equal(), target_rebalance(), ledgr_signal_strategy(), and ledgr_target().
- uncertainty: Some helper pages do link articles; the gap is discoverability from first-contact help paths.

### THEME-004 - Feature ID naming and registration create recurring first-use friction

- bucket: `docs_gap`
- severity: `medium`
- episodes: 5
- feedback rows: 6
- evidence: Users repeatedly needed ledgr_feature_id(), local setNames() aliases, and explicit registration for all parameterized lookbacks to avoid guessing feature IDs.
- recommended action: Add stronger examples for named feature aliases, multi-output IDs, and parameter-grid feature registration.
- uncertainty: Some behavior is documented; evidence supports UX/documentation hardening rather than a confirmed API bug.

### THEME-005 - Short-data, warmup, and final-bar behavior need a diagnosis recipe

- bucket: `docs_gap`
- severity: `medium`
- episodes: 5
- feedback rows: 9
- evidence: Runs found silent all-warmup zero-trade results, terse LEDGR_LAST_BAR_NO_FILL warnings, useful ledgr_empty_selection warnings, and confusion about per-instrument warmup counts.
- recommended action: Add a short-data and zero-trade troubleshooting section covering requires_bars, per-instrument warmup, pulse snapshots, empty selections, and final-bar no-fill warnings.
- uncertainty: At least one warning improvement is positive current behavior; duplicate detection is advisory.

### THEME-009 - TTR and multi-output indicator APIs need stronger examples

- bucket: `docs_gap`
- severity: `medium`
- episodes: 3
- feedback rows: 5
- evidence: Runs reported conditional TTR availability confusion, multi-column indicator discovery by error, MACD percent argument divergence, pulse_snapshot failures despite full backtest success, and lack of safe debugging patterns.
- recommended action: Add examples for TTR dependency expectations, multi-output column selection, MACD argument matching, pulse debugging, and fingerprint-safe diagnostics.
- uncertainty: MACD divergence may be user argument mismatch but raw evidence calls it behavior risk.

### THEME-002 - Hidden article_utc helper breaks copy-paste examples

- bucket: `docs_gap`
- severity: `medium`
- episodes: 2
- feedback rows: 2
- evidence: Rendered vignettes call article_utc() while the helper is only in hidden setup chunks; copied visible code fails with 'could not find function'.
- recommended action: Show the helper before first use, inline as.POSIXct(..., tz = 'UTC'), or expose a public date-time helper.
- uncertainty: No conflicting raw evidence found.

### THEME-010 - Snapshot import/seal metadata path blocked a documented workflow

- bucket: `ledgr_bug`
- severity: `medium`
- episodes: 1
- feedback rows: 1
- evidence: The CSV import/seal/backtest task succeeded only after an undocumented metadata workaround before ledgr_run() would accept the sealed snapshot.
- recommended action: Investigate the documented snapshot import/seal path and either fix metadata handling or document the required metadata step.
- uncertainty: Only one feedback row; raw script/log review would be needed before declaring a package bug.

### THEME-007 - Shell and headless logging can misclassify successful workflows

- bucket: `unclear`
- severity: `low`
- episodes: 6
- feedback rows: 7
- evidence: PowerShell wrapped stderr warnings/messages as NativeCommandError despite exit code 0, multiline Rscript -e was brittle, captured UTF-8 rendered poorly, and printing a vignette tried to open a browser URL.
- recommended action: Improve episode harness logging guidance: capture exit code, stdout, stderr, encoding, and headless vignette access separately.
- uncertainty: Most evidence belongs to the Windows/headless episode harness, not ledgr.

### THEME-006 - Summary and comparison outputs are display-first

- bucket: `docs_gap`
- severity: `low`
- episodes: 4
- feedback rows: 6
- evidence: summary(bt) prints and returns the backtest invisibly, comparison print output truncates/formats values, rounding precision is unstated, and summary help is hard to find from the snapshot.
- recommended action: Document structured alternatives for exact checks and make summary/comparison help discovery clearer.
- uncertainty: Most evidence is UX friction, not incorrect calculations.

### THEME-008 - Installed README and examples path is not a runnable start

- bucket: `bad_example`
- severity: `low`
- episodes: 2
- feedback rows: 2
- evidence: examples/README.md is listed under Start Here but says examples are non-executable and have no implementations yet.
- recommended action: Point first-start docs to runnable vignettes or make examples/README.md explicit that it is not the first runnable path.
- uncertainty: The vignettes were usable once found.

