# ledgr UX Triage Report

Source: `C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.7.7/categorized_feedback.yml`

This is a maintainer-review artifact. It does not create GitHub issues,
does not execute ledgr workflows, and does not decide final defect truth.

## Maintainer Ownership Overlay

This section is a human-maintainer overlay added after report generation. It
does not modify `categorized_feedback.yml`; it classifies handoff ownership for
the current run.

### ledgr-owned

These themes should be handed to ledgr implementers with the original evidence
below.

- `THEME-003` - Feature map, ctx accessor, and feature ID discoverability.
- `THEME-005` - Metrics, accounting, and comparison auditability.
- `THEME-004` - Warmup, short-sample, and current-bar diagnostics.
- `THEME-002` - Strategy helper dependency and parameter workflow friction.
- `THEME-001` - First-run and entry-point documentation gaps.
- `THEME-007` - Console print and formatted output semantics.
- `THEME-006` - Snapshot metadata and seal lifecycle clarity.
- `THEME-010` - Target, helper, and parameter error-message quality, pending
  ledgr maintainer classification of docs-gap versus small UX bug.

### auditr-owned

These findings are harness, task-brief, or report-quality issues and should not
be assigned to ledgr.

- `THEME-008` - Windows episode-runner and task-brief friction.
- Retrospective documentation-discovery friction is overcounted because normal
  successful `DOC_DISCOVERY.R` usage is currently counted as friction evidence.
- `DOC_DISCOVERY.R` task-intent mapping missed `ledgr_extract_strategy` for
  strategy extraction and recovery tasks.
- Broad searches over `raw_logs/` can fail on locked live `codex_*` stdout and
  stderr logs on Windows.
- Task brief wording conflicts appeared in the strategy-helper introduction and
  zero-trade diagnosis episodes.

### mixed / needs decision

- `THEME-009` - Strategy provenance and experiment-store discoverability.
  ledgr should clarify strategy extraction and provenance semantics; auditr
  should update the task-intent documentation map so extraction/recovery paths
  surface `ledgr_extract_strategy`.

## Validation

- well formed: yes
- errors: 0
- warnings: 0
- themes: 10
- item classifications: 68

## Bucket Counts

| bucket | items |
| --- | --- |
| docs_gap | 53 |
| duplicate | 6 |
| unclear | 5 |
| expected_user_error | 4 |

## Severity Counts

| severity | items |
| --- | --- |
| medium | 5 |
| low | 63 |

## Theme Priority Table

| theme_id | severity | bucket | episode_count | feedback_count | title | recommended_action |
| --- | --- | --- | --- | --- | --- | --- |
| THEME-003 | medium | docs_gap | 6 | 9 | Feature map, ctx accessor, and feature ID discoverability | Add a strategy-context/accessor reference topic, richer indicator strategy examples, and explicit ledgr_backtest versus ledgr_experiment feature object contracts. |
| THEME-005 | medium | docs_gap | 6 | 8 | Metrics, accounting, and comparison auditability | Expose or document annualization cadence, improve zero-trade/open exposure guidance, and document comparison output schema versus print view. |
| THEME-004 | medium | docs_gap | 5 | 8 | Warmup, short-sample, and current-bar diagnostics | Add runnable warmup/current-bar examples and document how summary diagnostics map to feature contract fields and snapshot bar counts. |
| THEME-002 | medium | docs_gap | 4 | 5 | Strategy helper dependency and parameter workflow friction | Document a helper dependency checklist and add examples showing every lookback registered before run; consider clearer unknown-feature hints. |
| THEME-001 | medium | docs_gap | 3 | 4 | First-run and entry-point documentation gaps | Add a clearly installed executable smoke test, document config-hash stability expectations, and link Getting Started from primary run/experiment help. |
| THEME-007 | low | docs_gap | 5 | 5 | Console print and formatted output semantics | Document summary print/return behavior, advise exact ID helpers where tibble output truncates, and distinguish formatted comparison output from raw numeric data. |
| THEME-008 | low | expected_user_error | 5 | 5 | Windows episode-runner and task-brief friction | Tighten task briefs and runner guidance for Windows quoting, encoding, and active log file handling. |
| THEME-010 | low | unclear | 5 | 6 | Target, helper, and parameter error-message quality | Improve targeted error messages and troubleshooting docs; maintainers should classify which items are docs gaps versus small ledgr UX bugs. |
| THEME-006 | low | docs_gap | 3 | 5 | Snapshot metadata and seal lifecycle clarity | Add snapshot_info examples for sealed handles and document parsed metadata/schema fields, including seal-derived counts and date formats. |
| THEME-009 | low | docs_gap | 3 | 4 | Strategy provenance and experiment-store discoverability | Use installed-package paths in docs, document post-close read access, and clarify strategy extraction provenance semantics. |

## High Priority Themes

No high priority themes.

## Issue Candidate Themes

These are grouped findings suitable for maintainer review. They are not GitHub issues yet.
### THEME-003 - Feature map, ctx accessor, and feature ID discoverability

- bucket: `docs_gap`
- severity: `medium`
- episodes: 6
- feedback rows: 9
- evidence: Users repeatedly needed clearer links between indicators, feature maps, engine IDs, aliases, ctx$feature(), ctx$features(), and accepted feature object types.
- recommended action: Add a strategy-context/accessor reference topic, richer indicator strategy examples, and explicit ledgr_backtest versus ledgr_experiment feature object contracts.
- uncertainty: The feature-map/backtest failures are documented as UX documentation gaps from raw episodes; maintainers should decide whether normalization is an API bug or a docs boundary.

### THEME-005 - Metrics, accounting, and comparison auditability

- bucket: `docs_gap`
- severity: `medium`
- episodes: 6
- feedback rows: 8
- evidence: Metric audit episodes could not retrieve detected annualization cadence, needed clearer zero-trade/open-exposure signals, and found comparison print views hide raw metric columns.
- recommended action: Expose or document annualization cadence, improve zero-trade/open exposure guidance, and document comparison output schema versus print view.
- uncertainty: Unsupported metrics in ledgr_results is likely an error-message UX issue; parser triage leaves it unclear rather than a proven bug.

### THEME-004 - Warmup, short-sample, and current-bar diagnostics

- bucket: `docs_gap`
- severity: `medium`
- episodes: 5
- feedback rows: 8
- evidence: Episodes needed clearer guidance for all-warmup runs, staggered current-bar absence, feature contracts, stable_after, and snapshot-specific feasibility.
- recommended action: Add runnable warmup/current-bar examples and document how summary diagnostics map to feature contract fields and snapshot bar counts.
- uncertainty: Some behavior completed without warnings and surfaced only in summary output; this may be expected but needs clearer user-facing guidance.

### THEME-002 - Strategy helper dependency and parameter workflow friction

- bucket: `docs_gap`
- severity: `medium`
- episodes: 4
- feedback rows: 5
- evidence: Multiple episodes hit or anticipated missing pre-registration for return lookbacks, especially when helper pipelines or params choose lookbacks dynamically.
- recommended action: Document a helper dependency checklist and add examples showing every lookback registered before run; consider clearer unknown-feature hints.
- uncertainty: One row is triaged unclear because pre-run validation may or may not be feasible, but the documentation need is consistent.

### THEME-001 - First-run and entry-point documentation gaps

- bucket: `docs_gap`
- severity: `medium`
- episodes: 3
- feedback rows: 4
- evidence: Cold-start runs had to infer the executable starting point, rely on suggested tidyverse packages, and reconcile dynamic config hash output; entry-point run help omits the Getting Started article link.
- recommended action: Add a clearly installed executable smoke test, document config-hash stability expectations, and link Getting Started from primary run/experiment help.
- uncertainty: Config hash behavior was observed as changing while other hashes and results stayed stable; raw evidence supports a documentation gap, not necessarily a determinism defect.

### THEME-007 - Console print and formatted output semantics

- bucket: `docs_gap`
- severity: `low`
- episodes: 5
- feedback rows: 5
- evidence: Several runs showed accidental double printing from print(summary(bt)) or ambiguity from formatted/truncated tibble-style output.
- recommended action: Document summary print/return behavior, advise exact ID helpers where tibble output truncates, and distinguish formatted comparison output from raw numeric data.
- uncertainty: Some rows are user-error-adjacent, but repeated reports make them useful documentation targets.

### THEME-008 - Windows episode-runner and task-brief friction

- bucket: `expected_user_error`
- severity: `low`
- episodes: 5
- feedback rows: 5
- evidence: Manual runs hit task wording conflicts, PowerShell quoting/BOM issues, and locked live codex logs during broad raw_logs searches.
- recommended action: Tighten task briefs and runner guidance for Windows quoting, encoding, and active log file handling.
- uncertainty: These are episode-harness and operator-friction findings, not ledgr package defects.

### THEME-010 - Target, helper, and parameter error-message quality

- bucket: `unclear`
- severity: `low`
- episodes: 5
- feedback rows: 6
- evidence: Rows call out clearer bad-return examples, generic helper error labels, run-hash mismatch recovery, non-finite parameter rejection, duplicate condition classes, and reserved Yahoo arguments.
- recommended action: Improve targeted error messages and troubleshooting docs; maintainers should classify which items are docs gaps versus small ledgr UX bugs.
- uncertainty: Several parser triage values are unclear, so treat the bug/doc boundary as unresolved.

### THEME-006 - Snapshot metadata and seal lifecycle clarity

- bucket: `docs_gap`
- severity: `low`
- episodes: 3
- feedback rows: 5
- evidence: Snapshot workflows left users unsure about implicit sealing, snapshot-handle info calls, ISO UTC date representation, and meta_json inner fields.
- recommended action: Add snapshot_info examples for sealed handles and document parsed metadata/schema fields, including seal-derived counts and date formats.
- uncertainty: No evidence contradicts the current API; this is primarily documentation and output-schema discoverability.

### THEME-009 - Strategy provenance and experiment-store discoverability

- bucket: `docs_gap`
- severity: `low`
- episodes: 3
- feedback rows: 4
- evidence: Installed users were pointed at source-tree contract paths, post-close result access was not explicit, and strategy extraction was not surfaced or did not preserve binding names.
- recommended action: Use installed-package paths in docs, document post-close read access, and clarify strategy extraction provenance semantics.
- uncertainty: Binding-name preservation may be an intentional provenance design choice; docs should state current behavior either way.

