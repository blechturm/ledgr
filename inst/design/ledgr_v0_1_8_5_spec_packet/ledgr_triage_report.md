# ledgr UX Triage Report

Source: `C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.8.4/categorized_feedback.yml`

This is a maintainer-review artifact. It does not create GitHub issues,
does not execute ledgr workflows, and does not decide final defect truth.


## Validation

- well formed: yes
- errors: 0
- warnings: 0
- themes: 7
- item classifications: 87

## Bucket Counts

| bucket | items |
| --- | --- |
| docs_gap | 47 |
| duplicate | 11 |
| bad_example | 8 |
| ledgr_bug | 7 |
| expected_user_error | 6 |
| missing_api | 4 |
| unclear | 4 |

## Severity Counts

| severity | items |
| --- | --- |
| high | 3 |
| medium | 22 |
| low | 62 |

## Theme Priority Table

| theme_id | severity | bucket | episode_count | feedback_count | title | recommended_action |
| --- | --- | --- | --- | --- | --- | --- |
| THEME-005 | high | unclear | 2 | 6 | Identity hash contract | Decide whether config_hash and alias_map_hash represent artifact identity or configuration equivalence, then expose/document the corresponding hashes consistently on run and sweep surfaces. |
| THEME-007 | high | ledgr_bug | 1 | 7 | Parameterized bundle sweep blockers | Treat the rejected active-alias bundle map and factory collision as high-priority contract decisions; update examples and error messages around the chosen support boundary. |
| THEME-001 | medium | docs_gap | 14 | 20 | Beginner docs and runnable examples | Consolidate the first-run path, mark expected warning output, keep vignette scripts runnable, and add direct help-page links from core execution topics to the relevant articles and scripts. |
| THEME-002 | medium | missing_api | 12 | 24 | Feature map and alias inspection | Document one canonical active-alias workflow from parameter declaration through contract inspection, pulse views, strategy access, run identity, and bundle output naming; add classed errors for unresolved maps. |
| THEME-003 | medium | docs_gap | 8 | 16 | Sweep grids and result schema | Add a sweep schema reference with executable-grid and legacy-grid examples, candidate summary structure, result columns, precompute labels, and promotion comparison guidance. |
| THEME-004 | medium | ledgr_bug | 8 | 14 | Preflight and error clarity | Tighten classed errors and teaching examples for namespace mistakes, missing active aliases, unresolved features, preflight tiers, and parameterized bundle support boundaries. |
| THEME-006 | low | expected_user_error | 9 | 10 | Episode environment friction | Keep these first-class for episode harness hardening, but route separately from ledgr documentation or implementation work. |

## High Priority Themes

### THEME-005 - Identity hash contract

- bucket: `unclear`
- severity: `high`
- episodes: 2
- feedback rows: 6
- evidence: Identity episodes found missing single-run feature/alias hash surfaces and observed config_hash or alias_map_hash changes where the task expected invariance.
- recommended action: Decide whether config_hash and alias_map_hash represent artifact identity or configuration equivalence, then expose/document the corresponding hashes consistently on run and sweep surfaces.
- uncertainty: Raw evidence supports the observations, but the intended hash semantics require maintainer decision before marking implementation incorrect.

### THEME-007 - Parameterized bundle sweep blockers

- bucket: `ledgr_bug`
- severity: `high`
- episodes: 1
- feedback rows: 7
- evidence: The final bundle episode was blocked by ledgr_experiment rejecting parameterized bundle outputs and by factory-sweep ID collisions, with adjacent documentation gaps on suffixes, factory routing, required input, and pctb casing.
- recommended action: Treat the rejected active-alias bundle map and factory collision as high-priority contract decisions; update examples and error messages around the chosen support boundary.
- uncertainty: Evidence shows failures, but maintainers must decide whether direct parameterized bundle sweeps are supported API or documentation overreach.

## Issue Candidate Themes

These are grouped findings suitable for maintainer review. They are not GitHub issues yet.
### THEME-005 - Identity hash contract

- bucket: `unclear`
- severity: `high`
- episodes: 2
- feedback rows: 6
- evidence: Identity episodes found missing single-run feature/alias hash surfaces and observed config_hash or alias_map_hash changes where the task expected invariance.
- recommended action: Decide whether config_hash and alias_map_hash represent artifact identity or configuration equivalence, then expose/document the corresponding hashes consistently on run and sweep surfaces.
- uncertainty: Raw evidence supports the observations, but the intended hash semantics require maintainer decision before marking implementation incorrect.

### THEME-007 - Parameterized bundle sweep blockers

- bucket: `ledgr_bug`
- severity: `high`
- episodes: 1
- feedback rows: 7
- evidence: The final bundle episode was blocked by ledgr_experiment rejecting parameterized bundle outputs and by factory-sweep ID collisions, with adjacent documentation gaps on suffixes, factory routing, required input, and pctb casing.
- recommended action: Treat the rejected active-alias bundle map and factory collision as high-priority contract decisions; update examples and error messages around the chosen support boundary.
- uncertainty: Evidence shows failures, but maintainers must decide whether direct parameterized bundle sweeps are supported API or documentation overreach.

### THEME-001 - Beginner docs and runnable examples

- bucket: `docs_gap`
- severity: `medium`
- episodes: 14
- feedback rows: 20
- evidence: Multiple cold-start, help-navigation, lifecycle, warning, and runnable-script rows report that users can complete tasks only after inferring the maintained path, interpreting expected warnings, or locating unstated runnable scripts.
- recommended action: Consolidate the first-run path, mark expected warning output, keep vignette scripts runnable, and add direct help-page links from core execution topics to the relevant articles and scripts.
- uncertainty: Some rows are low severity and resolved by the first-pass agent; group as documentation polish unless maintainers decide a specific example is a release gate.

### THEME-002 - Feature map and alias inspection

- bucket: `missing_api`
- severity: `medium`
- episodes: 12
- feedback rows: 24
- evidence: Rows repeatedly show friction around ctx$features forms, active alias maps, unresolved parameterized feature maps, pulse views, bundle outputs, and alias/casing conventions.
- recommended action: Document one canonical active-alias workflow from parameter declaration through contract inspection, pulse views, strategy access, run identity, and bundle output naming; add classed errors for unresolved maps.
- uncertainty: Some rows request API support while others request clearer documentation; maintainers should decide which gaps are public-contract changes.

### THEME-003 - Sweep grids and result schema

- bucket: `docs_gap`
- severity: `medium`
- episodes: 8
- feedback rows: 16
- evidence: Sweep episodes report missing candidate schema examples, unclear legacy versus executable grid row shapes, ambiguous grid composition, and sparse promotion/result-column documentation.
- recommended action: Add a sweep schema reference with executable-grid and legacy-grid examples, candidate summary structure, result columns, precompute labels, and promotion comparison guidance.
- uncertainty: Legacy flat-grid behavior may be intentionally retained; documentation should make that compatibility boundary explicit.

### THEME-004 - Preflight and error clarity

- bucket: `ledgr_bug`
- severity: `medium`
- episodes: 8
- feedback rows: 14
- evidence: Rows include low-level replacement/subscript/vapply errors, unknown-feature messages that omit the fix, and preflight examples that conflict with observed tier classification.
- recommended action: Tighten classed errors and teaching examples for namespace mistakes, missing active aliases, unresolved features, preflight tiers, and parameterized bundle support boundaries.
- uncertainty: Some failures are expected user errors, but the evidence supports improving messages before labeling them user mistakes.

### THEME-006 - Episode environment friction

- bucket: `expected_user_error`
- severity: `low`
- episodes: 9
- feedback rows: 10
- evidence: Several rows are about safe.directory ownership, PowerShell quoting/globbing, locked logs, or task metadata rather than ledgr behavior.
- recommended action: Keep these first-class for episode harness hardening, but route separately from ledgr documentation or implementation work.
- uncertainty: These should not become ledgr issues unless a maintainer intentionally broadens the documentation scope to shell-runner guidance.

