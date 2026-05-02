# ledgr UX Triage Report

Source: `C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.7.1/categorized_feedback.yml`

This is a maintainer-review artifact. It does not create GitHub issues,
does not execute ledgr workflows, and does not decide final defect truth.

## Validation

- well formed: yes
- errors: 0
- warnings: 0
- themes: 8
- item classifications: 38

## Bucket Counts

| bucket | items |
| --- | --- |
| docs_gap | 21 |
| unclear | 8 |
| expected_user_error | 6 |
| ledgr_bug | 2 |
| bad_example | 1 |

## Severity Counts

| severity | items |
| --- | --- |
| high | 1 |
| medium | 9 |
| low | 28 |

## Theme Priority Table

| theme_id | severity | bucket | episode_count | feedback_count | title | recommended_action |
| --- | --- | --- | --- | --- | --- | --- |
| THEME-006 | high | ledgr_bug | 3 | 4 | Comparison and trade metrics conflict or lack definitions | Confirm intended metric semantics, fix any inconsistency in ledgr_compare_runs(), document n_trades definitions, and return stable zero-row result schemas. |
| THEME-001 | medium | docs_gap | 9 | 9 | Noninteractive documentation discovery is weak | Add a documented noninteractive discovery path, ensure installed vignettes are discoverable from standard entry points, and point command-line users to stable installed files or helper commands. |
| THEME-003 | medium | docs_gap | 4 | 3 | Feature IDs and indicator output discovery drive repeated friction | Keep emphasizing ledgr_feature_id(), add a compact supported TTR indicator/output table or discoverability helper, and include examples that pass generated IDs into strategies. |
| THEME-004 | medium | docs_gap | 4 | 5 | Strategy contract examples need broader coverage | Add focused examples for SMA crossover, two-asset momentum, stateful threshold strategies, and clarify when examples are conceptual versus runnable against demo data. |
| THEME-005 | medium | docs_gap | 4 | 3 | Warmup and short-history behavior is under-explained | Add a warmup and short-datasets note near indicator examples, consider preflight warnings when required bars exceed available bars, and wrap strategy evaluation errors with timestamp/instrument/feature context. |
| THEME-002 | medium | docs_gap | 3 | 5 | First runnable examples are not clearly self-contained | Make the primary getting-started path explicitly runnable from a clean install, state suggested-package expectations before code, and distinguish temporary vignette storage from durable project storage. |
| THEME-008 | low | expected_user_error | 4 | 5 | Shell, logging, and encoding issues are mostly non-ledgr friction | Treat as environment guidance: provide Windows-safe command examples and remind reviewers to check true process exit codes and full logs. |
| THEME-007 | low | docs_gap | 3 | 4 | Experiment-store operational steps need clearer guidance | Add operational notes and small examples for persistent snapshot IDs, labels/tags, explicit CSV seal/load workflows, and defensive cleanup. |

## High Priority Themes

### THEME-006 - Comparison and trade metrics conflict or lack definitions

- bucket: `ledgr_bug`
- severity: `high`
- episodes: 3
- feedback rows: 4
- evidence: Episode 010 reports ledgr_compare_runs() n_trades = 0 while ledgr_extract_fills() prints two fills and summary() reports Total Trades: 2. Episode 007 saw n_trades = 0 for nonzero target holdings and changed equity. Episode 009 reports ledgr_results(bt, what = "trades") as a 0 x 0 tibble for a flat run.
- recommended action: Confirm intended metric semantics, fix any inconsistency in ledgr_compare_runs(), document n_trades definitions, and return stable zero-row result schemas.
- uncertainty: Episode 007 explicitly notes the zero count may be intentional depending on ledgr's definition; episode 010 has stronger conflicting evidence.

## Issue Candidate Themes

These are grouped findings suitable for maintainer review. They are not GitHub issues yet.
### THEME-006 - Comparison and trade metrics conflict or lack definitions

- bucket: `ledgr_bug`
- severity: `high`
- episodes: 3
- feedback rows: 4
- evidence: Episode 010 reports ledgr_compare_runs() n_trades = 0 while ledgr_extract_fills() prints two fills and summary() reports Total Trades: 2. Episode 007 saw n_trades = 0 for nonzero target holdings and changed equity. Episode 009 reports ledgr_results(bt, what = "trades") as a 0 x 0 tibble for a flat run.
- recommended action: Confirm intended metric semantics, fix any inconsistency in ledgr_compare_runs(), document n_trades definitions, and return stable zero-row result schemas.
- uncertainty: Episode 007 explicitly notes the zero count may be intentional depending on ledgr's definition; episode 010 has stronger conflicting evidence.

### THEME-001 - Noninteractive documentation discovery is weak

- bucket: `docs_gap`
- severity: `medium`
- episodes: 9
- feedback rows: 9
- evidence: Multiple episodes report that help(package = "ledgr"), vignette(package = "ledgr"), or printing a vignette object produced empty, unusable, or browser-dependent output in Rscript/noninteractive workflows. Agents worked around this by reading installed HTML/Rd files or using tools::Rd_db()/Rd2txt().
- recommended action: Add a documented noninteractive discovery path, ensure installed vignettes are discoverable from standard entry points, and point command-line users to stable installed files or helper commands.
- uncertainty: Some behavior may come from base R help mechanics or local Windows/browser configuration, not ledgr itself.

### THEME-003 - Feature IDs and indicator output discovery drive repeated friction

- bucket: `docs_gap`
- severity: `medium`
- episodes: 4
- feedback rows: 3
- evidence: Parsed and raw feedback repeatedly notes exact feature IDs are easy to guess incorrectly. Raw episode 004 guessed return_5 incorrectly, episode 005 contrasts rsi_14 with ttr_rsi_14, and raw episode 006 found BBands/MACD outputs most discoverable through errors or a vignette.
- recommended action: Keep emphasizing ledgr_feature_id(), add a compact supported TTR indicator/output table or discoverability helper, and include examples that pass generated IDs into strategies.
- uncertainty: Construction-time validation was reported as helpful, so the main issue is smooth-path documentation rather than broken validation.

### THEME-004 - Strategy contract examples need broader coverage

- bucket: `docs_gap`
- severity: `medium`
- episodes: 4
- feedback rows: 5
- evidence: Users had to infer SMA crossover, multi-asset target vector shape, target quantities versus weights, stateful RSI mean reversion, and conceptual AAA examples versus DEMO_01/DEMO_02 runnable data.
- recommended action: Add focused examples for SMA crossover, two-asset momentum, stateful threshold strategies, and clarify when examples are conceptual versus runnable against demo data.
- uncertainty: Most workflows were completed with workarounds, so severity is documentation/UX rather than confirmed runtime failure.

### THEME-005 - Warmup and short-history behavior is under-explained

- bucket: `docs_gap`
- severity: `medium`
- episodes: 4
- feedback rows: 3
- evidence: Warmup guards were needed for SMA, momentum, RSI, and a 10-bar edge case. The 10-bar SMA20 run silently stayed flat; unguarded feature use failed with a raw R missing-value error; ledgr_ind_rsi(n = 14) reports Requires bars: 15 without an explanation in the cited help.
- recommended action: Add a warmup and short-datasets note near indicator examples, consider preflight warnings when required bars exceed available bars, and wrap strategy evaluation errors with timestamp/instrument/feature context.
- uncertainty: Some warmup behavior is expected; the issue is whether ledgr should warn proactively or only document the user responsibility.

### THEME-002 - First runnable examples are not clearly self-contained

- bucket: `docs_gap`
- severity: `medium`
- episodes: 3
- feedback rows: 5
- evidence: The README-equivalent example was not runnable, the getting-started and strategy-development vignettes use dplyr/tibble without an upfront dependency note, and a durable example uses tempfile() despite durable wording.
- recommended action: Make the primary getting-started path explicitly runnable from a clean install, state suggested-package expectations before code, and distinguish temporary vignette storage from durable project storage.
- uncertainty: Installed environment already had some suggested packages, so cold-start dependency failures were not directly observed.

### THEME-008 - Shell, logging, and encoding issues are mostly non-ledgr friction

- bucket: `expected_user_error`
- severity: `low`
- episodes: 4
- feedback rows: 5
- evidence: PowerShell quoting expanded R $ expressions, stderr redirection through Tee-Object or PowerShell wrappers made successful R runs look failed, and captured tibble output showed mojibake on Windows.
- recommended action: Treat as environment guidance: provide Windows-safe command examples and remind reviewers to check true process exit codes and full logs.
- uncertainty: Raw evidence frames these as not ledgr runtime bugs.

### THEME-007 - Experiment-store operational steps need clearer guidance

- bucket: `docs_gap`
- severity: `low`
- episodes: 3
- feedback rows: 4
- evidence: Feedback calls out remembering or setting snapshot IDs, missing label/tag examples in compare workflows, needing lower-level explicit seal/load steps for CSV import, and easy-to-miss close()/on.exit() lifecycle cleanup.
- recommended action: Add operational notes and small examples for persistent snapshot IDs, labels/tags, explicit CSV seal/load workflows, and defensive cleanup.
- uncertainty: The runs succeeded; these are hardening improvements for repeatable manual workflows.

