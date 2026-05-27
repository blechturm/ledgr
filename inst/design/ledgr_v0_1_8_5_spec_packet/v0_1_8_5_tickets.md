# ledgr v0.1.8.5 Tickets

Version: v0.1.8.5
Date: 2026-05-26
Total Tickets: 11

## Ticket Organization

This packet implements the scoped v0.1.8.5 plan from `v0_1_8_5_spec.md`:
canonical research workflow, Quarto vignette migration, artifact topology,
README and vignette narrative flow, sweep inspection teaching, legacy
sweep-authoring boundary cleanup, concrete backup guidance, and bounded
auditr intake.

The release spine is:

```text
documentation inventory
  -> canonical research workflow article
  -> Quarto vignette infrastructure and styleguide
  -> README / pkgdown reading flow
  -> store, data input, and reproducibility docs
  -> legacy sweep-authoring boundary cleanup
  -> sweeps and execution semantics docs
  -> remaining core vignette Quarto migration
  -> research-to-production disposition and redundancy cleanup
  -> bounded auditr intake
  -> release gate
```

v0.1.8.5 is a teachability release. It must not add runtime semantics,
storage schemas, parallel dispatch, target risk, cost/liquidity policy, OMS,
snapshot lineage, live data logs, point-in-time regressors, scaffold
generation, companion repositories, or strategy-template libraries.

The release must teach that promotion is not statistical validation. A
single-window sweep is exploratory evidence with an audit trail. Walk-forward
and out-of-sample evaluation are future roadmap layers, not v0.1.8.5 scope.

The release also uses the pre-CRAN window to simplify sweep authoring:
active aliases plus feature/strategy grids are the supported feature-parameter
sweep path; `ledgr_param_grid()` remains for strategy-only or legacy flat-grid
use; legacy feature factories are compatibility/advanced fixed-feature
machinery and must not silently accept parameterized feature sweeps.

## Dependency DAG

```text
LDG-2434 Packet Setup, Documentation Inventory, And Reading Flow
  |-- LDG-2435 Canonical Research Workflow Article
  |     `-- LDG-2443 Quarto Vignette Infrastructure And Styleguide
  |           |-- LDG-2436 README And Pkgdown Reading Flow
  |           |-- LDG-2437 Store, Data Input, And Reproducibility Docs
  |           |-- LDG-2438 Sweeps And Execution Semantics Docs
  |           |-- LDG-2444 Remaining Core Vignette Quarto Migration
  |           `-- LDG-2439 Research-To-Production Disposition And Redundancy Cleanup
  |-- LDG-2440 Pending Auditr Intake And Bounded Routing
  |-- LDG-2442 Legacy Sweep Authoring Boundary
  `-- LDG-2441 v0.1.8.5 Release Gate And Closeout

LDG-2438 also depends on LDG-2442 for the legacy boundary language. LDG-2441
depends on LDG-2435 through LDG-2440 plus LDG-2442, LDG-2443, and LDG-2444.
LDG-2440 closed by classifying the v0.1.8.4 auditr themes against the
bounded-intake rule; a fresh report would trigger a separate intake.
```

## Priority Levels

- P0: Release gate, scope gate, or release-blocking auditr routing.
- P1: Primary user-facing documentation path and package narrative.
- P2: Secondary documentation cleanup or redundancy reduction.

---

## LDG-2434: Packet Setup, Documentation Inventory, And Reading Flow

Priority: P0
Effort: S
Dependencies: none
Status: Completed

### Description

Finalize the v0.1.8.5 planning packet and inventory the current README,
vignettes, and pkgdown navigation before rewriting. The release must refine the
v0.1.8.4 active-alias documentation rewrite rather than assume a blank slate.

### Tasks

- Keep `v0_1_8_5_spec.md`, `v0_1_8_5_tickets.md`, and `tickets.yml`
  synchronized.
- Inventory README, Sweeps, Indicators, Strategy
  Development, Experiment Store, Reproducibility, Metrics/Accounting, and
  Research-To-Production docs.
- Map each major vignette to its primary job from the spec's reading-flow
  standard.
- Identify repeated explanations that need a canonical home.
- Review `_pkgdown.yml` article ordering and current navigation grouping.
- Confirm no runtime or storage work is pulled into v0.1.8.5.

### Acceptance Criteria

- Spec, ticket markdown, and `tickets.yml` agree on ticket IDs,
  dependencies, status, and scope.
- A documentation inventory exists in ticket notes, a commit message, or a
  small design note before rewrite tickets begin.
- The inventory identifies canonical homes for repeated concepts.
- The inventory identifies the disposition needed for
  `research-to-production.Rmd`.
- v0.1.8.5 scope remains documentation/workflow alignment.

### Verification

Manual packet review and `git diff --check`.

### Completion Notes

Completed in `batch0_inventory_and_intake.md`. The note inventories README,
vignettes, pkgdown navigation, repeated concepts, canonical homes, and the
`research-to-production.Rmd` disposition. Runtime/storage scope remains
deferred.

### Source Reference

- `v0_1_8_5_spec.md`
- `inst/design/rfc/rfc_research_workflow_artifact_topology_v0_1_8_x_synthesis.md`
- `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md`
- `inst/design/README.md`
- `inst/design/ledgr_roadmap.md`

### Classification

```yaml
type: governance
surface: design_packet
scope: v0.1.8.5
```

---

## LDG-2435: Canonical Research Workflow Article

Priority: P1
Effort: L
Dependencies: LDG-2434
Status: Completed

### Description

Create the canonical end-to-end research workflow article. It should teach the
full package-owned path from sealed data to promoted and reopened evidence
without implying that sweep promotion is statistical validation.

### Tasks

- Add `vignettes/research-workflow.Rmd` as the review draft for the workflow
  article; LDG-2443 migrates the accepted draft to canonical `.qmd` source.
- Build a runnable core using package-owned demo data or a small local data
  path.
- Teach project topology and one project-local store:
  `artifacts/ledgr_store.duckdb`.
- Show active aliases, feature grids, strategy grids, a single run, a sweep,
  candidate inspection, promotion with note, and reopen from store.
- Include an explicit "Why this is not validation" section.
- Add a "Future: Walk-Forward Evaluation" callout that points to the roadmap
  and accepted walk-forward synthesis until a user-facing walk-forward article
  exists.
- Include the report/review outline from the spec.
- Add documentation contract tests for the article structure and load-bearing
  wording.

### Acceptance Criteria

- The article contains all required article-shape sections from the spec.
- The article contains all report/review outline items from the spec.
- The article explicitly says promotion records selection but does not prove
  generalization.
- The article names naive sweep-and-pick as a selection-bias risk.
- The article mentions walk-forward or out-of-sample evaluation as the next
  conceptual layer.
- Warmup examples use `passed_warmup()`.
- The runnable core renders or has a documented maintainer exception.

### Verification

Targeted documentation contract tests, vignette render, and manual article
review.

### Completion Notes

Added `vignettes/research-workflow.Rmd` as the workflow article review draft.
The article teaches the sealed snapshot -> experiment -> single run -> sweep
-> candidate inspection -> promotion -> reopen path, uses active aliases and
executable grids, includes the required validation caveat and walk-forward
forward-link, and documents the report/review outline. Added documentation
contract tests for the required section spine, report outline, validation
caveats, warmup guard, project-local store path, and documented vignette-build
exception. LDG-2443 owns the Quarto migration and final canonical `.qmd`
source.

### Source Reference

- `v0_1_8_5_spec.md` Sections 3, 4, 5, 6.1, and 11
- `rfc_research_workflow_artifact_topology_v0_1_8_x_synthesis.md`

### Classification

```yaml
type: documentation
surface: research_workflow
scope: canonical_workflow
```

---

## LDG-2443: Quarto Vignette Infrastructure And Styleguide

Priority: P1
Effort: M
Dependencies: LDG-2435
Status: Completed

### Description

Make Quarto the canonical installed-vignette format for v0.1.8.5, add the
article styleguide, and migrate the research workflow article as the
proof-of-concept before the remaining documentation batches scale the pattern.

### Tasks

- Verify Quarto CLI availability for local development and release checks.
- Add package/project configuration needed to render `.qmd` vignettes.
- Add `_quarto.yml` or equivalent configuration that renders only intended
  vignette files and does not accidentally process design notebooks.
- Add `inst/design/vignette_styleguide.md` as the review standard for article
  work in this cycle.
- Migrate `vignettes/research-workflow.Rmd` to
  `vignettes/research-workflow.qmd`.
- Apply the editorial punch-list from Batch 1 review: coherent warmup example,
  task-oriented strategy heading, report-before-future section order, and
  related-article links.
- Apply styleguide Section 5 Code Clarity: strip non-semantic `pkg::fn()`
  qualifications and repeated optional-argument boilerplate, and route
  visual-clutter API gaps to notes instead of hiding them in examples.
- Update documentation contract tests so migrated articles are read from `.qmd`
  or rendered output instead of assuming `.Rmd`.
- Smoke-test Quarto vignette rendering and pkgdown integration.

### Acceptance Criteria

- `vignettes/research-workflow.qmd` exists and is the canonical source.
- Temporary `research-workflow.Rmd` source is removed or explicitly excluded
  from installed articles.
- Quarto callouts render in the checked output path; diagrams are rendered and
  kept only when they add teaching value.
- Documentation contract tests cover the workflow article through the canonical
  `.qmd` or rendered output.
- `inst/design/vignette_styleguide.md` exists and covers voice, opening
  pattern, callouts, diagrams, exercises, code chunks, cross-links,
  reference-content boundaries, and related-article endings.
- The migrated workflow article passes the styleguide Section 14 review
  checklist or records explicit exceptions in the ticket notes.
- Package, vignette, and pkgdown configuration changes are scoped to
  documentation rendering and do not alter runtime semantics.

### Verification

Quarto render smoke test, pkgdown article smoke test, documentation contract
tests, and manual styleguide review.

### Completion Notes

Completed Batch 1B Quarto proof-of-concept. Added package/project Quarto
configuration, CI dependency setup, pkgdown navigation for the new workflow
article, and the working draft vignette styleguide. Migrated the research
workflow article from `.Rmd` to canonical `.qmd`, rendered the companion
GitHub markdown, and removed the temporary `.Rmd` source.

Verification completed:

- Quarto CLI available through the RStudio-bundled Quarto executable
  (`1.6.42`).
- `vignettes/research-workflow.qmd` renders to HTML with Quarto callout assets
  present. The workflow article uses evaluated chunks with real rendered output
  and keeps the Mermaid diagrams only where they teach the workflow loop and
  selection-vs-validation boundary.
- `vignettes/research-workflow.qmd` renders to
  `vignettes/research-workflow.md` for GitHub review.
- pkgdown detects `research-workflow` in article navigation and the
  Quarto-only pkgdown article builder writes
  `articles/research-workflow.html` in a temporary smoke site.
- Documentation contract tests read the canonical `.qmd` source and pass.

Known integration note: a full `pkgdown::build_articles()` run still fails on
pre-existing `getting-started.Rmd` executable-code drift. Batch 2 review later
resolved this by retiring the redundant Getting Started article rather than
migrating the drift forward.

Editorial review note: the workflow article intentionally names the promoted-run
recovery surface as an API gap. The underlying provenance exists through
`ledgr_run_info()`, promotion context metadata, and `ledgr_extract_strategy()`,
but future work should consider a small helper that summarizes "what caused this
promoted result?" without requiring users to inspect nested promotion-context
fields directly.

Editorial review note: the workflow article also names candidate review as a
design note. The current public surface supports explicit ranking with table
tools and deliberate extraction through `ledgr_candidate()`, but future work
should consider a compact helper for "rank completed candidates, show the
review columns, separate issue rows, and select one candidate" without hiding
the selection rule.

### Source Reference

- `v0_1_8_5_spec.md` Sections 2, 6.1, 6.7, 10, and 11
- `inst/design/vignette_styleguide.md`
- `vignettes/research-workflow.qmd`

### Classification

```yaml
type: documentation_platform
surface: vignette_rendering
scope: quarto_migration
```

---

## LDG-2436: README And Pkgdown Reading Flow

Priority: P1
Effort: M
Dependencies: LDG-2443
Status: In Progress

### Description

Refine first-contact documentation so users see how to run a small credible
backtest quickly, then route deeper capabilities to focused articles. The
README must not become a feature catalog.

Batch 2 editorial review found that Getting Started duplicated the new
executable README and the Research Workflow article without owning a distinct
job. LDG-2436 therefore drops the installed Getting Started article instead of
migrating it to Quarto.

### Tasks

- Reduce README to identity, install/load, quick backtest, produced evidence,
  and next links.
- Keep `README.Rmd` and `README.md` synchronized.
- Fix the README strategy-source inspection regression from the v0.1.8.4 docs
  rewrite so stored source is inspectable without overwhelming the quick path.
- Remove the redundant Getting Started article from installed docs.
- Route former Getting Started links to Research Workflow.
- Link to the workflow article and focused vignettes for sweeps, stores,
  reproducibility, metrics, feature maps, and strategy development.
- Update `_pkgdown.yml` article ordering and grouping to match the documented
  reading flow.

### Acceptance Criteria

- README answers the five questions in spec Section 6.2.
- README demonstrates a quick credible backtest.
- README links capability depth to vignettes instead of demonstrating every
  major feature.
- README strategy-source inspection proves the audit-trail story concisely.
- No installed Getting Started source or pkgdown navigation entry remains.
- Background articles route first-run readers to Research Workflow.
- `_pkgdown.yml` exposes the workflow article and preserves a coherent reading
  order.
- No obsolete exact-ID sweep example is presented as the primary path.

### Verification

Documentation contract tests, README render/update check, pkgdown navigation
review, and manual first-contact review.

### Source Reference

- `v0_1_8_5_spec.md` Sections 6.2, 6.7, 10, and 11
- `README.Rmd`
- `README.md`
- `_pkgdown.yml`
- `vignettes/articles/who-ledgr-is-for.Rmd`
- `vignettes/articles/why-r.Rmd`

### Classification

```yaml
type: documentation
surface: first_contact_docs
scope: readme_pkgdown
```

---

## LDG-2437: Store, Data Input, And Reproducibility Docs

Priority: P1
Effort: M
Dependencies: LDG-2443
Status: Pending

### Description

Align Experiment Store, Reproducibility, and data-input documentation with the
one-store topology, sealed-snapshot lifecycle, concrete backup guidance, and
pre-CRAN compatibility policy.

### Tasks

- Align Experiment Store docs around `artifacts/ledgr_store.duckdb` as the
  default project-local store.
- Migrate Experiment Store and Reproducibility articles to Quarto and apply
  the styleguide.
- Add a "Backup Conventions" subsection with at least one concrete backup
  pattern for a closed DuckDB store file.
- Add or link user-visible pre-CRAN compatibility guidance.
- Split or add Data Input And Snapshot Creation material if the Experiment
  Store article remains too broad.
- Name snapshot lifecycle anti-patterns: in-place append, reseal under same
  ID, deleting referenced snapshots, live ticks in backtest snapshots, and
  undocumented synthetic corrections.
- Keep Yahoo/real-data caveats bounded to the workflow need.
- Connect Reproducibility docs to hashes, strategy source, preflight tiers,
  config identity, promotion notes, and limits of provenance.

### Acceptance Criteria

- Experiment Store docs contain a "Backup Conventions" subsection.
- Backup guidance includes at least one concrete file-level copy/sync pattern.
- Pre-CRAN compatibility guidance is visible from public docs.
- Data-input and snapshot-creation material is reachable from the reading flow.
- Public docs do not imply sealed snapshots can be mutated in place.
- Reproducibility docs distinguish evidence capture from proof of selection
  validity.
- Experiment Store and Reproducibility have `.qmd` canonical sources and
  render under the Quarto pipeline.

### Verification

Documentation contract tests, targeted grep for snapshot anti-pattern language,
vignette render, and manual docs review.

### Source Reference

- `v0_1_8_5_spec.md` Sections 4, 5, 6.3, 6.5, and 11
- `vignettes/experiment-store.Rmd`
- `vignettes/reproducibility.Rmd`

### Classification

```yaml
type: documentation
surface: store_data_reproducibility
scope: artifact_topology
```

---

## LDG-2438: Sweeps And Execution Semantics Docs

Priority: P1
Effort: M
Dependencies: LDG-2443, LDG-2442
Status: Pending

### Description

Align sweep documentation with active aliases and candidate inspection, and add
a compact execution-semantics article so target holdings, pulse causality,
next-open fills, cost timing, open positions, final-bar warnings, and warmup
guards have one canonical explanation.

### Tasks

- Align Sweeps docs with `ledgr_feature_grid()`, `ledgr_strategy_grid()`,
  `ledgr_grid_cross()`, candidate inspection, warning/failure review, and
  promotion notes.
- Migrate Sweeps to Quarto and apply the styleguide.
- Ensure Sweeps docs do not introduce objective-function, automatic ranking,
  automatic winner-selection, or `ledgr_tune()` semantics.
- Add `vignettes/execution-semantics.qmd`.
- Link execution semantics from workflow, Strategy Development, Sweeps, and
  Metrics/Accounting articles.
- Ensure new warmup examples use `passed_warmup()`.
- Keep exact-ID lookup material as advanced or legacy context, not the primary
  sweep path.
- Document the legacy sweep-authoring boundary from LDG-2442: active aliases
  and executable grids are the feature-parameter sweep path;
  `ledgr_param_grid()` is strategy-only or legacy flat-grid surface; feature
  factories are not the supported parameterized feature-sweep route.

### Acceptance Criteria

- `vignettes/execution-semantics.qmd` exists.
- Execution semantics are linked from the required articles.
- Sweeps and Execution Semantics have `.qmd` canonical sources and render under
  the Quarto pipeline.
- Sweeps docs teach feature grids, strategy grids, candidate inspection, and
  promotion notes.
- Sweeps docs explicitly avoid automatic winner-selection semantics.
- Sweeps docs contain the executable-grid versus legacy-flat-grid boundary.
- Sweeps docs do not teach feature factories as the parameterized
  feature-sweep path.
- New warmup examples avoid ad hoc `!is.na(sma)`-style guards and use
  `passed_warmup()`.

### Verification

Documentation contract tests, warmup grep, vignette render, and manual docs
review.

### Source Reference

- `v0_1_8_5_spec.md` Sections 6.4, 6.6, 10, and 11
- `vignettes/sweeps.Rmd`
- `vignettes/strategy-development.Rmd`
- `vignettes/metrics-and-accounting.Rmd`

### Classification

```yaml
type: documentation
surface: sweeps_execution_semantics
scope: installed_docs
```

---

## LDG-2444: Remaining Core Vignette Quarto Migration

Priority: P1
Effort: M
Dependencies: LDG-2443
Status: Pending

### Description

Migrate the v0.1.8.4-aligned core articles that are not otherwise touched by
the earlier v0.1.8.5 content batches, and apply the styleguide without
reopening runtime or API scope.

### Tasks

- Migrate Strategy Development to Quarto.
- Migrate Indicators / Feature Maps to Quarto.
- Migrate Metrics And Accounting to Quarto.
- Apply the styleguide to headings, opening paragraphs, callouts, diagrams,
  exercises, code chunks, cross-links, and related-article endings.
- Preserve the v0.1.8.4 active-alias teaching improvements.
- Keep reference-style function contracts in roxygen/help pages.
- Ensure exact-ID lookup is not reintroduced as the primary parameterized
  feature-sweep path.

### Acceptance Criteria

- Strategy Development, Indicators / Feature Maps, and Metrics And Accounting
  have `.qmd` canonical sources.
- Each article states or demonstrates its primary job in the first section or
  first paragraph.
- Quarto callouts, diagrams, exercises, and related links improve teaching
  rather than adding decoration.
- Documentation contract tests pass after source extension updates.
- No migrated article reintroduces exact-ID feature lookup as the primary
  parameterized feature-sweep path.

### Verification

Documentation contract tests, Quarto render checks, and manual styleguide
review.

### Source Reference

- `v0_1_8_5_spec.md` Sections 6.7, 10, and 11
- `inst/design/vignette_styleguide.md`
- `vignettes/strategy-development.Rmd`
- `vignettes/indicators.Rmd`
- `vignettes/metrics-and-accounting.Rmd`

### Classification

```yaml
type: documentation_platform
surface: core_vignettes
scope: quarto_migration
```

---

## LDG-2439: Research-To-Production Disposition And Redundancy Cleanup

Priority: P2
Effort: S
Dependencies: LDG-2443, LDG-2436, LDG-2437, LDG-2438, LDG-2444
Status: Pending

### Description

Resolve the relationship between the new canonical workflow article and the
existing `research-to-production.Rmd` article, then perform a redundancy pass
so vignettes have one primary job and do not compete on core contract
explanations.

### Tasks

- Narrow `research-to-production.Rmd` to promotion boundaries,
  production caveats, and future paper/live context, or remove it from the
  main reading flow if it remains redundant.
- Ensure the article points to `research-workflow.qmd` for the research path.
- Migrate the narrowed article to Quarto if it remains in the installed
  article set.
- Review major vignettes against the one-primary-job standard.
- Replace repeated full explanations with short reminders and links to the
  canonical article.
- Confirm the reading-flow diagram remains accurate after edits.

### Acceptance Criteria

- `research-to-production.Rmd` no longer competes with
  `research-workflow.qmd`.
- If retained, Research-To-Production has a `.qmd` canonical source and renders
  under the Quarto pipeline.
- Each major vignette states or clearly demonstrates its primary job early.
- Repeated explanations of sealing, target holdings, active aliases, and
  experiment stores are reduced to reminders outside their canonical homes.
- `_pkgdown.yml` does not send users through redundant articles before the
  canonical workflow.

### Verification

Manual vignette-flow review, documentation contract tests where applicable,
and pkgdown navigation review.

### Source Reference

- `v0_1_8_5_spec.md` Sections 6.1, 6.7, and 10
- `vignettes/research-to-production.Rmd`
- `_pkgdown.yml`

### Classification

```yaml
type: documentation
surface: vignette_flow
scope: redundancy_cleanup
```

---

## LDG-2440: Pending Auditr Intake And Bounded Routing

Priority: P0
Effort: M
Dependencies: LDG-2434
Status: Completed

### Description

Reserve a bounded intake slot for the auditr report expected during the
v0.1.8.5 cycle. The intake must classify findings, accept only release
blockers or direct teachability fits, and defer architecture-shaped work. The
v0.1.8.4 auditr report has already promoted one accepted cleanup decision:
legacy feature factories are no longer the supported parameterized feature
sweep path.

### Tasks

- If the pending auditr report lands before release, read the report and source
  files.
- Classify each finding as release blocker, v0.1.8.5 docs fit,
  v0.1.8.5 focused bug fit, future roadmap, or auditr-side.
- Accept no more than roughly five tickets or one focused week of work without
  maintainer amendment.
- Add accepted findings to this packet or attach them to existing tickets.
- Record explicit deferrals and rejections.
- If no report lands before release gate, close this ticket as no-op with a
  note.

### Acceptance Criteria

- Any auditr report that lands during the release has a disposition classified
  per spec Section 8.1.
- The legacy feature-factory sweep finding is routed through LDG-2442 rather
  than left as a generic documentation gap.
- Release blockers and direct teachability fits are routed.
- Architecture-shaped findings are deferred to roadmap, horizon, or future
  spec packets.
- The intake does not expand v0.1.8.5 beyond the bounded budget without
  maintainer approval.

### Verification

Manual auditr routing review and `git diff --check`.

### Completion Notes

Completed in `batch0_inventory_and_intake.md`. The v0.1.8.4 auditr themes were
classified against the v0.1.8.5 bounded-intake rule. Direct teachability fits
were attached to existing tickets, architecture-shaped findings were deferred,
episode-environment findings were routed outside ledgr release scope, and no
new tickets were added.

### Source Reference

- `v0_1_8_5_spec.md` Section 8.1
- Pending auditr report files, if present

### Classification

```yaml
type: audit_routing
surface: auditr_intake
scope: bounded_release_intake
```

---

## LDG-2442: Legacy Sweep Authoring Boundary

Priority: P1
Effort: M
Dependencies: LDG-2434
Status: Pending

### Description

Codify the pre-CRAN cleanup decision that active aliases plus feature/strategy
grids are the supported feature-parameter sweep path. Legacy feature factories
may remain as compatibility or advanced fixed-feature machinery, but they must
not be taught as the tuning path or silently accept parameterized feature-sweep
inputs.

### Tasks

- Audit legacy feature-factory and direct bundle-output sweep behavior.
- Support direct active-alias parameterized multi-output bundle sweeps if the
  fix is localized and can reuse existing alias-map disambiguation.
- If a legacy factory is used with `feature_params`, executable grids, or
  parameterized feature sweeps, fail or warn with a classed, action-oriented
  condition.
- Keep `ledgr_param_grid()` available and documented for strategy-only sweeps
  and legacy flat-grid compatibility.
- Route legacy feature-factory bundle-output collisions to explicit classed
  boundary failures unless a minimal-risk active-alias reuse is available.
- Add focused tests for the supported active-alias path and unsupported legacy
  paths.
- Coordinate documentation wording with LDG-2438.

### Acceptance Criteria

- Direct active-alias parameterized bundle sweeps work through the canonical
  feature-map/grid path, or fail with a classed explicit unsupported condition
  if the localized implementation is not feasible.
- Feature-factory parameterized sweeps no longer silently receive the wrong
  parameter namespace.
- Unsupported factory/bundle collision paths fail or warn with classed,
  action-oriented conditions.
- `ledgr_param_grid()` remains usable for strategy-only or legacy flat-grid
  sweeps.
- Tests cover the canonical bundle path and the legacy boundary.

### Verification

Targeted feature-map, experiment, sweep, and documentation contract tests;
manual review of error wording.

### Source Reference

- `v0_1_8_5_spec.md` Sections 3.1, 6.4, 8.1, 10, and 11
- `inst/design/ledgr_v0_1_8_5_spec_packet/ledgr_triage_report.md`
- `inst/design/ledgr_v0_1_8_5_spec_packet/categorized_feedback.yml`
- `vignettes/sweeps.Rmd`

### Classification

```yaml
type: compatibility_cleanup
surface: sweep_authoring
scope: legacy_boundary
```

---

## LDG-2441: v0.1.8.5 Release Gate And Closeout

Priority: P0
Effort: M
Dependencies: LDG-2435, LDG-2436, LDG-2437, LDG-2438, LDG-2439, LDG-2440, LDG-2442, LDG-2443, LDG-2444
Status: Pending

### Description

Run the v0.1.8.5 release gate and close the teachability packet. This ticket
verifies that documentation renders, contracts are pinned, README and vignette
flow are coherent, and any auditr intake has been routed.

### Tasks

- Run documentation contract tests.
- Render changed vignettes and README artifacts.
- Render Quarto-sourced vignettes and pkgdown article pages.
- Verify `README.Rmd` and `README.md` are synchronized.
- Verify `_pkgdown.yml` navigation matches the documented reading flow.
- Run package checks required by the release playbook.
- Update NEWS with a documentation/workflow release note.
- Update ticket statuses and completion notes.
- Record release-gate results and maintainer disposition for any exception.

### Acceptance Criteria

- Release-gate checklist or closeout notes map the canonical workflow to
  tested/documented surfaces.
- Documentation contract tests pass or have maintainer-accepted exceptions.
- Changed vignettes render or have maintainer-accepted exceptions.
- All installed vignette sources are `.qmd`, except files with an explicit
  maintainer-approved exception.
- `inst/design/vignette_styleguide.md` is canonized or has a recorded
  carry-forward disposition.
- Package checks required by the release playbook pass or have recorded
  disposition.
- `tickets.yml` and this ticket file agree on final statuses.
- v0.1.8.5 closes as a documentation/workflow release, not a runtime feature
  release.

### Verification

Documentation contract tests, vignette render, README render/update check,
package release checks, and manual closeout review.

### Source Reference

- `v0_1_8_5_spec.md`
- `inst/design/release_ci_playbook.md`
- `NEWS.md`

### Classification

```yaml
type: release_gate
surface: release_process
scope: v0.1.8.5
```
