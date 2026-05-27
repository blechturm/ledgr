# Batch 0 Inventory And Auditr Intake

**Status:** Batch 0 completion note for `LDG-2434` and `LDG-2440`.
**Date:** 2026-05-27
**Scope:** Documentation inventory, reading-flow baseline, repeated-concept
canonical homes, pkgdown navigation review, and bounded auditr routing.

Batch 0 confirms that v0.1.8.5 remains a teachability/workflow release. It
does not authorize runtime semantics, storage schemas, target risk,
walk-forward implementation, cost/liquidity, OMS, scaffold generation, or
parallel dispatch.

---

## Documentation Inventory

Current first-contact and vignette surfaces:

| Surface | Current primary job | v0.1.8.5 disposition |
| --- | --- | --- |
| `README.Rmd` / `README.md` | First contact, quick experiment, sweep teaser, durable research links | Keep quick and inverted-pyramid. Reduce feature-catalog pressure; prove one credible backtest and route depth to vignettes. |
| `vignettes/getting-started.Rmd` | First complete onboarding walkthrough | Align with README and canonical workflow. Keep runnable, but do not become a reference manual. |
| `vignettes/research-workflow.Rmd` | Not yet present | Add as the canonical seal -> declare -> run -> sweep -> inspect -> promote -> reopen article in `LDG-2435`. |
| `vignettes/experiment-store.Rmd` | Durable snapshots, run store, run discovery, strategy source, reopen/archive, low-level CSV bridge | Narrow toward project-local store, backup conventions, data/snapshot lifecycle, and store inspection. Move general workflow teaching to `research-workflow.Rmd`. |
| `vignettes/reproducibility.Rmd` | Experiment/provenance model, source extraction, tiers, params boundary | Keep as reproducibility reference. Link from workflow and distinguish evidence capture from selection validity. |
| `vignettes/sweeps.Rmd` | Sweep exploration, train/test discipline, grids, precompute, failures, seeds, promotion | Align with active aliases and executable grids. Keep "sweep is exploration" as first principle; no automatic winner-selection semantics. |
| `vignettes/strategy-development.Rmd` | Strategy authoring, ctx, targets, feature maps, preflight, helper pipelines | Keep as strategy-authoring reference. Link execution semantics and avoid owning sweep workflow. |
| `vignettes/indicators.Rmd` | Built-in features, lifecycle, pulse inspection, feature maps, contracts, parameterized indicators | Keep as feature/indicator reference. Avoid teaching feature factories as the parameterized sweep path. |
| `vignettes/custom-indicators.Rmd` | Custom indicator object construction, fingerprints, adapters, registration | Keep focused on authoring custom indicators. |
| `vignettes/metrics-and-accounting.Rmd` | Ledger/fills/trades/equity/metrics, zero-trade diagnostics, open positions | Keep accounting reference. Link execution semantics for target/fill timing. |
| `vignettes/leakage.Rmd` | Leakage boundaries and user responsibilities | Keep as conceptual guardrail; link from workflow where validation limits are discussed. |
| `vignettes/research-to-production.Rmd` | Current broad research-to-production narrative | Narrow in `LDG-2439` to promotion boundaries, production caveats, and future paper/live context, or remove from main reading flow if redundant. |
| `vignettes/articles/who-ledgr-is-for.Rmd` | Audience positioning | Keep in Start Here, but do not make it the operational first-run path. |
| `vignettes/articles/why-r.Rmd` | R/platform rationale | Keep as background. |

---

## Canonical Homes For Repeated Concepts

| Concept | Canonical home for v0.1.8.5 | Other surfaces should |
| --- | --- | --- |
| End-to-end research workflow | `vignettes/research-workflow.Rmd` | Link to it instead of repeating the full path. |
| Quick first backtest | `README.Rmd` and `vignettes/getting-started.Rmd` | Keep examples short and route deeper topics. |
| Project-local store and backup | `vignettes/experiment-store.Rmd` | Use short reminders and link to backup conventions. |
| Reproducibility/provenance limits | `vignettes/reproducibility.Rmd`; workflow article for the short warning | State "evidence, not validation" and link. |
| Selection-is-not-validation | `vignettes/research-workflow.Rmd` | Repeat the warning where sweeps/promotion appear. |
| Sweep grids and promotion | `vignettes/sweeps.Rmd`; workflow article for the user path | Avoid objective-function or automatic ranking language. |
| Execution semantics | New `vignettes/execution-semantics.Rmd` in `LDG-2438` | Link rather than restating target/fill timing in full. |
| Active aliases and feature maps | `vignettes/indicators.Rmd` and `vignettes/strategy-development.Rmd` | Link to the relevant feature/strategy article. |
| Warmup and stable feature values | `vignettes/execution-semantics.Rmd` plus indicator/strategy reminders | Use `passed_warmup()` in new examples. |
| Accounting and metrics | `vignettes/metrics-and-accounting.Rmd` | Link for derived ledger/fill/trade/equity details. |

---

## Current Pkgdown Reading Flow

Current `_pkgdown.yml` groups articles as:

```text
Start Here:
  who-ledgr-is-for
  getting-started
  leakage
  reproducibility

Core Workflow:
  strategy-development
  indicators
  custom-indicators
  metrics-and-accounting
  experiment-store
  sweeps

Design / Background:
  research-to-production
  why-r
```

Required v0.1.8.5 navigation changes:

- Add `research-workflow` to the early reading path after Getting Started.
- Keep README and Getting Started as entry points, not full references.
- Move or narrow `research-to-production` so it does not compete with the new
  workflow article.
- Add/link `execution-semantics` once `LDG-2438` creates it.
- Preserve focused reference articles for strategy development, indicators,
  sweeps, experiment store, reproducibility, metrics/accounting, and leakage.

---

## Research-To-Production Disposition

Default disposition for `LDG-2439`:

- `research-workflow.Rmd` becomes the canonical end-to-end research article.
- `research-to-production.Rmd` should narrow to production boundaries:
  promotion caveats, what v0.1.x does not yet do, and future paper/live context.
- If the article remains substantially redundant after narrowing, remove it
  from the main reading flow and keep only a short redirecting/narrowed article.

---

## Auditr Intake Routing

The v0.1.8.5 packet already includes the completed auditr report for the
previous cycle:

- `ledgr_triage_report.md`
- `categorized_feedback.yml`
- `cycle_retrospective.md`

The report contains 87 feedback rows across 7 themes. Batch 0 classifies them
against the v0.1.8.5 bounded-intake rule:

| Theme | Route | Rationale |
| --- | --- | --- |
| `THEME-001` Beginner docs and runnable examples | Accept into `LDG-2435`, `LDG-2436`, `LDG-2437`, release docs review | Direct teachability fit. Consolidates first-run path, runnable examples, warning framing, and help-page routing. |
| `THEME-002` Feature map and alias inspection | Accept documentation parts into `LDG-2435`, `LDG-2438`; defer API expansion beyond scoped error/docs work | Directly supports canonical active-alias workflow. Broader API additions wait for future packets unless localized and already covered by `LDG-2442`. |
| `THEME-003` Sweep grids and result schema | Accept into `LDG-2438` | Direct teachability fit for sweeps, executable grids, result columns, candidate summary, warnings/failures, and promotion context. |
| `THEME-004` Preflight and error clarity | Accept only scoped message/docs pieces into `LDG-2438` and `LDG-2442`; defer broad preflight architecture | Fits where errors teach namespace mistakes, missing aliases, and unsupported legacy sweep paths. General preflight hardening is not v0.1.8.5 scope. |
| `THEME-005` Identity hash contract | Defer to future roadmap/spec packet | Requires maintainer design decision about artifact identity versus configuration equivalence. Not a teachability-only fix. |
| `THEME-006` Episode environment friction | Reject from ledgr v0.1.8.5; route to auditr/harness environment | Safe-directory, shell quoting, locked logs, and task metadata are episode-harness issues unless future docs intentionally cover shell-runner guidance. |
| `THEME-007` Parameterized bundle sweep blockers | Accept bounded boundary work into `LDG-2442`; documentation wording into `LDG-2438` | High-priority because it affects canonical sweep teaching. Scope is limited to active-alias canonical path and classed/action-oriented legacy-boundary behavior. |

Accepted auditr work remains within the budget because it is attached to
existing tickets rather than expanding the packet. Any additional auditr report
that lands during v0.1.8.5 must still follow the bounded-intake rule: no more
than roughly five tickets or one focused week without maintainer amendment.

If no further auditr report lands before release gate, `LDG-2440` remains
complete with this routing note as the intake record.

---

## Batch 0 Completion

`LDG-2434` completion evidence:

- spec/ticket/yaml packet exists and agrees on the 9 ticket IDs and dependency
  shape;
- documentation inventory above identifies current surfaces and primary jobs;
- repeated concepts have canonical homes;
- `research-to-production.Rmd` disposition is bound for `LDG-2439`;
- `_pkgdown.yml` current grouping and required changes are recorded;
- runtime/storage scope remains deferred.

`LDG-2440` completion evidence:

- auditr report was read and classified by theme;
- accepted findings were attached to existing v0.1.8.5 tickets;
- architecture-shaped findings were deferred;
- episode-environment findings were rejected from ledgr release scope;
- no new tickets were added from auditr intake, preserving the bounded budget.
