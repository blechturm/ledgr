# auditr v0.1.7.7 Follow-Up Plan

**Status:** Draft routing artifact
**Source reports:**

- `inst/design/ledgr_v0_1_7_8_spec_packet/cycle_retrospective.md`
- `inst/design/ledgr_v0_1_7_8_spec_packet/ledgr_triage_report.md`

This document routes the v0.1.7.7 auditr findings into ledgr release scope. It
does not create implementation tickets by itself. Raw episode evidence still
has to be checked before a finding is promoted from this plan into code or docs
work.

## Summary

The v0.1.7.7 auditr run was healthy:

- 35 episodes;
- all runner exits were `0`;
- categorized feedback was valid;
- no high-priority themes;
- no feedback rows were missing `source_docs`.

The findings are mostly documentation and discoverability debt, not runtime
defects. v0.1.7.8 should remain focused on strategy reproducibility preflight,
leakage-boundary documentation, custom-indicator boundary documentation, and
explicit routing. Broad strategy-author ergonomics should move to v0.1.7.9.

## Ownership

### ledgr-Owned

These themes contain ledgr documentation, UX, or product-surface findings:

- `THEME-001` - First-run and entry-point documentation gaps.
- `THEME-002` - Strategy helper dependency and parameter workflow friction.
- `THEME-003` - Feature map, ctx accessor, and feature ID discoverability.
- `THEME-004` - Warmup, short-sample, and current-bar diagnostics.
- `THEME-005` - Metrics, accounting, and comparison auditability.
- `THEME-006` - Snapshot metadata and seal lifecycle clarity.
- `THEME-007` - Console print and formatted output semantics.
- `THEME-009` - Strategy provenance and experiment-store discoverability.
- `THEME-010` - Target, helper, and parameter error-message quality, pending
  item-level classification.

### auditr-Owned

These findings should not be assigned to ledgr package work unless reframed as a
package defect with raw evidence:

- `THEME-008` - Windows episode-runner and task-brief friction.
- Overcounted documentation-discovery friction caused by normal successful
  `DOC_DISCOVERY.R` usage.
- Missing `ledgr_extract_strategy` task-intent mapping in `DOC_DISCOVERY.R`.
- Broad recursive searches over live `raw_logs/` locking active `codex_*` logs
  on Windows.
- Task brief wording conflicts in strategy-helper and zero-trade diagnosis
  episodes.

## Routing Table

| Theme | Classification | v0.1.7.8 action | v0.1.7.9 candidate | Backlog / excluded | Notes |
| --- | --- | --- | --- | --- | --- |
| `THEME-001` First-run and entry-point docs | ledgr docs gap | Exclude from v0.1.7.8 unless raw evidence shows a reproducibility/preflight blocker. | Add executable first-run smoke path, Getting Started links from primary run/experiment help, and config-hash stability wording. | - | Current evidence supports docs gap, not determinism bug. |
| `THEME-002` Helper dependency and parameter workflow | mixed ledgr docs / reproducibility boundary | Promote only the dependency-boundary pieces: all feature parameter variants must be registered before `ledgr_run()`; helper pipelines must not create features lazily from `params`. | Add helper dependency checklist, multi-lookback examples, and clearer unknown-feature hints. | - | This overlaps v0.1.7.8 leakage and reproducibility docs. |
| `THEME-003` Feature map, ctx accessor, feature IDs | ledgr docs gap | Promote only the feature-boundary explanation needed by leakage/custom-indicator docs. | Add strategy-context/accessor reference topic; improve feature-map, alias, engine-ID, `ctx$feature()`, and `ctx$features()` discoverability. | - | Broad accessor ergonomics belong in v0.1.7.9. |
| `THEME-004` Warmup, short-sample, current-bar diagnostics | ledgr docs gap | Exclude from v0.1.7.8 unless raw evidence proves a runtime defect affecting leakage or preflight. | Add runnable warmup/current-bar examples and feature-contract feasibility docs, likely with `ledgr_feature_contract_check()`. | - | Matches existing v0.1.7.9 scope. |
| `THEME-005` Metrics/accounting/comparison auditability | ledgr docs gap | Exclude from v0.1.7.8 unless raw evidence proves metric bug. | Document annualization cadence, zero-trade/open-exposure guidance, and comparison print-vs-raw schema. | - | v0.1.7.7 shipped metric work; this is follow-up clarity. |
| `THEME-006` Snapshot metadata/seal clarity | ledgr docs gap | Exclude from v0.1.7.8. | Add snapshot-info examples for sealed handles, parsed metadata/schema fields, counts, and date formats. | Optional docs backlog if v0.1.7.9 scope is too large. | Low severity. |
| `THEME-007` Console print/formatted output | ledgr docs gap | Exclude from v0.1.7.8. | Document summary print/return behavior, ID helpers for truncated tibbles, and formatted comparison output vs raw numeric data. | Optional docs backlog. | Low severity. |
| `THEME-008` Windows runner/task friction | auditr harness/environment | Excluded. | - | auditr-owned | Do not add ledgr APIs to work around harness behavior. |
| `THEME-009` Strategy provenance/experiment-store discoverability | mixed ledgr docs / auditr mapping | Promote provenance semantics that affect reproducibility tiers, especially `ledgr_extract_strategy()` limits and stored-source recoverability. | Clarify installed-package paths, post-close result access, and experiment-store task-map discoverability. | auditr should update discovery mapping. | Binding-name preservation needs design classification before any code change. |
| `THEME-010` Target/helper/parameter error-message quality | unclear ledgr docs or small UX bugs | Item-level raw-evidence review required before promotion. Promote only confirmed preflight/leakage/reproducibility error-message issues. | Improve targeted helper troubleshooting docs and selected error messages if verified. | - | Do not promote the whole theme without classification. |

## v0.1.7.8 Promotions

The following pieces are in v0.1.7.8 scope:

- `THEME-002` dependency-boundary documentation for feature pre-registration and
  parameterized helper workflows.
- `THEME-003` feature-boundary explanation needed by the leakage and
  custom-indicator articles.
- `THEME-009` reproducibility-facing strategy provenance clarification,
  especially safe `ledgr_extract_strategy(..., trust = FALSE)` semantics and
  the limits of stored source.
- Any `THEME-010` item that raw evidence confirms as a preflight, leakage, or
  reproducibility diagnostic defect.

Everything else is routed to v0.1.7.9, a later docs backlog, or auditr.

## v0.1.7.9 Candidate Bundle

The v0.1.7.9 Strategy Author Ergonomics milestone should explicitly consider:

- strategy-context/accessor reference documentation;
- feature map aliases versus engine feature IDs;
- `ctx$feature()` and `ctx$features()` discoverability;
- warmup/current-bar runnable troubleshooting examples;
- `ledgr_feature_contract_check(snapshot, features)`;
- first-run entry-point help links;
- comparison print view versus raw numeric columns;
- summary print/return behavior;
- snapshot metadata and sealed-handle info examples;
- targeted helper and parameter error-message improvements.

## Exclusion Rules

- Do not change ledgr package APIs to compensate for auditr task-brief or
  runner-environment issues.
- Do not promote parser-triaged `unclear` rows without raw evidence.
- Do not expand v0.1.7.8 into broad strategy-author ergonomics; that belongs in
  v0.1.7.9 unless it blocks preflight or leakage documentation.
