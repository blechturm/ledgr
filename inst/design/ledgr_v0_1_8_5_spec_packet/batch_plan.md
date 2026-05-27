# v0.1.8.5 Batch Plan

**Status:** Review batching plan for the v0.1.8.5 teachability cycle.
**Scope:** Groups the v0.1.8.5 tickets into implementation/review batches.

v0.1.8.5 is a teachability release. Code review for this cycle includes
editorial and style review. Reviewers should use an inverted-pyramid lens:
start with the main user outcome, then explain the details only after the
reader knows why they matter.

Global review standards:

- The first screen or first section should tell the user what they can do.
- README and first-contact docs should not become feature catalogs.
- Installed vignettes should migrate to Quarto and follow
  `inst/design/vignette_styleguide.md`.
- Quarto callouts, diagrams when they add teaching value, exercises, and
  related-article links are reviewable teaching tools, not decoration.
- Sweep promotion must be framed as recorded selection, not statistical
  validation.
- Walk-forward and out-of-sample testing are the next conceptual layer, not
  v0.1.8.5 scope.
- Each vignette should have one primary job and say or demonstrate it early.
- Repeated concepts should have one canonical home and short cross-links
  elsewhere.

---

## Batch 0: Scope And Inventory

Tickets:

- `LDG-2434` Packet Setup, Documentation Inventory, And Reading Flow
- `LDG-2440` Pending Auditr Intake And Bounded Routing

Purpose:

Establish the documentation inventory, reading-flow baseline, and bounded
auditr intake before rewriting public docs. This batch prevents v0.1.8.5 from
turning into a general cleanup bucket.

Review focus:

- Inventory identifies canonical homes for repeated concepts.
- Auditr findings are classified and bounded.
- Accepted auditr findings fit v0.1.8.5 teachability or release-blocker scope.
- If no auditr report lands during the cycle, `LDG-2440` closes as "no
  findings" with a one-line retrospective note. If a report lands, the bounded
  intake rule from spec Section 8.1 applies: no more than roughly five tickets
  or one focused week without maintainer amendment; overflow defers to
  v0.1.8.6, horizon, or a future packet.
- Runtime, storage, parallelism, target risk, cost/liquidity, OMS, and scaffold
  work remain deferred.

---

## Batch 1: Canonical Workflow Spine

Tickets:

- `LDG-2435` Canonical Research Workflow Article

Purpose:

Create the load-bearing end-to-end research workflow article. Other first-
contact and reference docs should point to this article instead of inventing a
parallel narrative.

Review focus:

- First section or paragraph names the outcome before code or vocabulary: a
  reproducible research artifact with audit-trail provenance.
- The seal -> declare -> run -> sweep -> inspect -> promote -> reopen path is
  clear.
- Promotion is explicitly described as recorded selection, not proof of
  generalization.
- Naive sweep-and-pick is named as a selection-bias risk.
- Walk-forward or out-of-sample evaluation is identified as the next conceptual
  layer.
- Warmup examples use `passed_warmup()`.
- Runnable core renders or has a documented maintainer exception.
- Documentation contract tests for the workflow article exist and cover:
  selection-is-not-validation phrasing, the walk-forward forward-link,
  `passed_warmup()` usage, the 12 required article-shape sections, and the
  report/review outline items.
- This batch may produce an `.Rmd` review draft; the canonical installed
  source becomes `.qmd` only after Batch 1B.

---

## Batch 1B: Quarto Infrastructure And Article Styleguide

Tickets:

- `LDG-2443` Quarto Vignette Infrastructure And Styleguide

Purpose:

Make Quarto the installed-vignette format for v0.1.8.5, establish the article
styleguide, and migrate the research workflow article as the proof-of-concept
before the remaining docs batches scale the pattern.

Review focus:

- Quarto CLI availability and local render path are verified.
- Package/project configuration renders `.qmd` vignettes without accidentally
  rendering unrelated design notebooks.
- `inst/design/vignette_styleguide.md` exists and covers voice, opening
  pattern, callouts, diagrams, exercises, code chunks, cross-links,
  reference-content boundaries, and related-article endings.
- `vignettes/research-workflow.qmd` is the canonical source.
- Any temporary `research-workflow.Rmd` draft is removed or explicitly
  excluded from installed articles.
- Quarto callouts render in the checked output path; diagrams are rendered and
  kept only when they add teaching value.
- Documentation contract tests no longer assume `.Rmd` source for migrated
  vignettes.

---

## Batch 2: First-Contact Experience

Tickets:

- `LDG-2436` README, Getting Started, And Pkgdown Reading Flow

Purpose:

Make the first-contact path quick, credible, and routed. README and Getting
Started should teach how to run a small backtest and inspect the evidence, then
link to focused articles for depth.

Review focus:

- README answers the five questions from the spec.
- README demonstrates a quick credible backtest.
- README links deeper capabilities instead of demonstrating every major
  feature inline.
- README strategy-source inspection proves the audit-trail story concisely.
- Getting Started remains onboarding, not a reference manual.
- Getting Started is migrated to Quarto and follows the styleguide.
- `_pkgdown.yml` exposes the workflow article and preserves the reading flow.
- No obsolete exact-ID sweep example is presented as the primary path.

---

## Batch 3: Evidence, Store, And Reproducibility

Tickets:

- `LDG-2437` Store, Data Input, And Reproducibility Docs

Purpose:

Teach what evidence ledgr creates, where it lives, how sealed snapshots behave,
and how users should preserve project-local stores.

Review focus:

- Experiment Store docs include a concrete "Backup Conventions" subsection.
- Backup guidance names at least one file-level copy/sync pattern.
- Snapshot lifecycle anti-patterns are explicit.
- Data-input and snapshot-creation material is reachable from the reading flow.
- Reproducibility docs distinguish evidence capture from proof of selection
  validity.
- Yahoo/real-data caveats stay bounded and practical.
- Experiment Store and Reproducibility are migrated to Quarto and use callouts
  for backup, pre-CRAN, and data-source caveats where useful.

---

## Batch 4: Sweep Boundary And Execution Semantics

Tickets:

- `LDG-2442` Legacy Sweep Authoring Boundary
- `LDG-2438` Sweeps And Execution Semantics Docs

Purpose:

Codify the supported feature-parameter sweep path and give execution semantics
one canonical explanation. `LDG-2438` depends on `LDG-2442` because the sweep
docs need the finalized legacy-boundary language.

Batch 2 may anticipate the legacy-boundary teaching because the teaching
decision was already settled by v0.1.8.4: active aliases are canonical for
feature-parameter sweeps. Batch 4 codifies the classed-error and compatibility
behavior so runtime messages match that teaching.

Review focus:

- Active aliases plus feature/strategy grids are the canonical
  feature-parameter sweep path.
- `ledgr_param_grid()` remains strategy-only or legacy flat-grid context.
- Feature factories are not taught as the parameterized feature-sweep route.
- Unsupported legacy paths fail or warn with classed, action-oriented
  conditions.
- `vignettes/execution-semantics.qmd` exists and is linked from the required
  articles as native Quarto source.
- Sweeps is migrated to Quarto and follows the styleguide.
- Sweeps docs do not introduce objective-function, automatic ranking,
  automatic winner-selection, or `ledgr_tune()` semantics.
- New warmup examples use `passed_warmup()`.

---

## Batch 4.5: Remaining Core Vignette Migration

Tickets:

- `LDG-2444` Remaining Core Vignette Quarto Migration

Purpose:

Migrate the v0.1.8.4-aligned core articles that were not otherwise touched by
Batches 2-4, and apply the styleguide without reopening runtime or API scope.

Review focus:

- Strategy Development, Indicators / Feature Maps, and Metrics/Accounting have
  `.qmd` canonical sources.
- Each article states or demonstrates its primary job in the first section or
  paragraph.
- Callouts, diagrams, exercises, and related links improve teaching rather
  than adding decoration.
- Reference-style function contracts remain in roxygen/help pages; vignettes
  focus on workflows, explanation, and worked examples.
- Exact-ID feature lookup is not reintroduced as the primary parameterized
  sweep path.

---

## Batch 5: Vignette Flow And Redundancy

Tickets:

- `LDG-2439` Research-To-Production Disposition And Redundancy Cleanup

Purpose:

Clean up the reading flow after the canonical homes exist. This batch decides
what `research-to-production.Rmd` is for and removes competing explanations
from other vignettes.

Review focus:

- `research-to-production.Rmd` no longer competes with
  `research-workflow.qmd`.
- `research-to-production` is either migrated as a narrowed Quarto article or
  removed from the main reading flow with maintainer disposition.
- Each major vignette has one primary job, stated or demonstrated early. The
  preferred trigger is a first-section heading or first paragraph that names the
  job clearly enough for review by inspection.
- Repeated explanations of sealing, target holdings, active aliases, and
  experiment stores are reduced to reminders outside canonical homes.
- `_pkgdown.yml` does not route users through redundant articles before the
  canonical workflow.

---

## Batch 6: Release Gate

Tickets:

- `LDG-2441` v0.1.8.5 Release Gate And Closeout

Purpose:

Verify the teachability release, close the packet, and record any accepted
exceptions.

Review focus:

- Documentation contract tests pass or have maintainer-accepted exceptions.
- Changed vignettes render or have maintainer-accepted exceptions.
- Quarto-sourced vignettes and pkgdown article pages render or have
  maintainer-accepted exceptions.
- README generated output is synchronized.
- `_pkgdown.yml` navigation matches the documented reading flow.
- Package checks required by the release playbook pass or have recorded
  disposition.
- `tickets.yml` and `v0_1_8_5_tickets.md` agree on final statuses.
- NEWS frames v0.1.8.5 as a documentation/workflow release, not a runtime
  feature release.
- Workflow docs and Experiment Store docs do not commit to v0.1.8.6 DuckDB-
  backed feature storage or out-of-core projection as already-decided
  implementation. The v0.1.8.6 storage work remains a decision spike.
- `cycle_retrospective.md` is updated with v0.1.8.5 outcomes: shipped tickets,
  absorbed auditr findings if any, carry-forward items for v0.1.8.6/v0.1.9 or
  horizon, and process lessons for `inst/design/rfc_cycle.md`.
- The cycle adhered to `inst/design/rfc_cycle.md`; any deviations are recorded
  in `cycle_retrospective.md` per the "When to deviate" rule.

---

## Recommended Execution Order

```text
Batch 0
  -> Batch 1
      -> Batch 1B
      -> Batch 2
      -> Batch 3
      -> Batch 4
          -> Batch 4.5
          -> Batch 5
              -> Batch 6
```

Batch 2 and Batch 3 may proceed in parallel after Batch 1B if the workflow
article's canonical homes and Quarto conventions are stable. Batch 4 should
wait for Batch 0's legacy boundary decision, Batch 1's workflow language, and
Batch 1B's styleguide. Batch 4.5 should wait for Batch 1B and can proceed once
the core Quarto pattern is proven. Batch 5 should wait until the canonical
homes exist.
