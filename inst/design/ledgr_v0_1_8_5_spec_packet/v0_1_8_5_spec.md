# ledgr v0.1.8.5 Spec

**Status:** Draft implementation spec for v0.1.8.5.
**Target Branch:** `v0.1.8.5`
**Scope:** Canonical research workflow and teachability release after active
aliases and grid helpers.
**Auditr Input:** Routed from the completed v0.1.8.4 packet. Broader workflow
documentation, sweep-inspection, cross-surface semantics, and "where do I look
for X?" findings are accepted as v0.1.8.5 inputs. A pending auditr report may
add a bounded intake batch if it lands before the release gate.
**Non-scope for this pass:** New execution semantics, project scaffold helper,
split-store runtime, snapshot lineage API, live data log, production promotion
record, point-in-time regressor API, pins/vetiver integration, companion
example repository implementation, DuckDB-backed feature storage,
out-of-core projection, parallel dispatch, target risk, public cost/liquidity
API, OMS work, automatic candidate ranking, objective functions, and strategy
template libraries.
**In-scope pre-CRAN cleanup:** Narrow legacy sweep-authoring surfaces so active
aliases plus feature/strategy grids are the canonical feature-parameter sweep
path.

---

## 0. Source Inputs

Authoritative inputs:

- `inst/design/contracts.md`
- `inst/design/ledgr_roadmap.md`
- `inst/design/README.md`
- `inst/design/rfc/rfc_research_workflow_artifact_topology_v0_1_8_x_synthesis.md`
- `inst/design/ledgr_v0_1_8_4_spec_packet/v0_1_8_4_spec.md`

Supporting context:

- `inst/design/horizon.md`
- `inst/design/release_ci_playbook.md`
- `inst/design/rfc/rfc_active_parameterized_feature_aliases_v0_1_8_x_synthesis.md`
- `inst/design/rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`
- `inst/design/rfc/rfc_sweep_candidate_promotion_contract_v0_1_8_synthesis.md`
- `inst/design/rfc/rfc_sweep_promotion_context_v0_1_8_synthesis.md`
- `inst/design/rfc/rfc_ledgr_oms_seed_synthesis.md`
- `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md`

Auditr and review inputs:

- `inst/design/ledgr_v0_1_8_4_spec_packet/ledgr_triage_report.md`
- `inst/design/ledgr_v0_1_8_4_spec_packet/categorized_feedback.yml`
- `inst/design/ledgr_v0_1_8_4_spec_packet/cycle_retrospective.md`
- `inst/design/ledgr_v0_1_8_4_spec_packet/auditr_intake_synthesis.md`

Horizon entries promoted into this spec:

- data input and snapshot creation article;
- compact execution semantics article;
- research workflow scaffolds and companion templates, documentation-only
  prerequisite;
- pre-CRAN compatibility policy, user-facing wording;
- accepted OMS direction and intraday-safe target-decision storage, roadmap
  context only.

This spec does not treat horizon entries as automatic backlog tickets. It
promotes only the documentation and teachability parts that fit v0.1.8.5.

---

## 1. Thesis

v0.1.8.5 is a teachability release.

v0.1.8.4 made the sweep authoring model coherent: active aliases, separate
feature and strategy grids, executable grid composition, alias-map provenance,
alias-aware pulse debugging, and a small demo SMA-crossover teaching fixture
now exist. The next problem is not another runtime layer. The next problem is
that users need one clear path through the package.

The release should make this workflow the default way to understand ledgr:

```text
seal data
  -> declare features and strategy
  -> sweep deliberately
  -> inspect evidence
  -> promote explicitly
  -> reopen from durable artifacts
```

The package already owns each primitive in that chain. v0.1.8.5 makes the
chain teachable, runnable, and internally consistent across the public docs.

The single-window workflow taught here is the foundation, not the complete
research-method story. Promotion records an explicit selection decision; it
does not prove that the selected candidate is statistically validated.
Walk-forward evaluation, accepted for v0.1.9.x planning in
`inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md`, is the
next conceptual upgrade for users who need stronger selection-integrity
evidence.

The tone should be confident rather than self-deprecating. This is not merely a
"boring" workflow. It is ledgr's strongest product position: reproducible
research artifacts are the easiest path, not an afterthought.

---

## 2. Release Goals

v0.1.8.5 has ten primary goals:

1. Add a canonical research workflow article or vignette that walks through the
   full package-owned path from sealed data to promoted evidence.
2. Align README and Getting Started with the same first-contact story, while
   keeping them shorter than the dedicated workflow article.
3. Align Experiment Store documentation around one project-local store,
   normally `artifacts/ledgr_store.duckdb`.
4. Align Sweeps documentation with active aliases, feature grids, strategy
   grids, explicit inspection, and promotion notes.
5. Add or split a focused data-input and snapshot-creation article if that
   keeps the Experiment Store article from carrying too much low-level data
   setup material.
6. Add a compact execution-semantics reference for target holdings, pulse-time
   causality, next-open fills, cost timing, open positions, final-bar no-fill
   behavior, and warmup guards.
7. Surface backup, schema-version, and pre-CRAN compatibility guidance in
   user-facing documentation.
8. Route v0.1.8.3/v0.1.8.4 auditr workflow findings into concrete docs
   surfaces instead of leaving them as generic "documentation gap" notes.
9. Set durable standards for README and vignette narrative flow so package
   documentation becomes easier to read rather than merely more complete.
10. Use the pre-CRAN window to simplify the public sweep-authoring story:
    active aliases plus feature/strategy grids become the supported feature
    parameter sweep path, while legacy feature factories are narrowed to
    compatibility and advanced fixed-feature use.

The release succeeds when a new serious user can answer:

- where does raw data live?
- what gets sealed into ledgr?
- which files should be source controlled?
- which artifacts are generated but still important?
- how do feature params differ from strategy params?
- how should sweep results be inspected?
- what does promotion record and what does it not record?
- how do I reopen the evidence later?

---

## 3. Canonical Workflow Contract

The v0.1.8.5 teaching workflow is:

1. Create or load raw data outside ledgr.
2. Seal normalized market data into a ledgr snapshot.
3. Declare features, strategy code, and grids explicitly in project files.
4. Run a single backtest against sealed input evidence.
5. Sweep feature and strategy parameters deliberately.
6. Inspect metrics, fills, equity, warnings, failures, and candidate identity.
7. Promote explicitly with `ledgr_promote(..., note = ...)`.
8. Reopen the promoted run from the experiment store.

This release must not imply that sweeps prove selection quality. Provenance
records what happened. It does not validate that the selection protocol was
statistically sound.

The workflow article must say this directly. A single-window sweep is
exploratory evidence with an audit trail. A promoted candidate is a recorded
choice, not proof that the strategy will generalize. Naive sweep-and-pick
selection is a selection-bias risk. Walk-forward and out-of-sample evaluation
are the planned next conceptual layer, not v0.1.8.5 scope.

The workflow article should use active aliases as the primary strategy-facing
feature path:

```r
features <- ledgr_feature_map(
  fast = ledgr_ind_sma(ledgr_param("fast_n")),
  slow = ledgr_ind_sma(ledgr_param("slow_n"))
)
```

Feature parameters and strategy parameters must remain visibly separate:

```r
feature_grid <- ledgr_feature_grid(
  fast_n = c(10L, 20L),
  slow_n = c(40L, 80L),
  .filter = fast_n < slow_n
)

strategy_grid <- ledgr_strategy_grid(
  qty = c(10, 25),
  threshold = c(0, 0.005)
)
```

The canonical warmup guard in strategy examples is `passed_warmup()`. Do not
teach ad hoc `!is.na(sma)` checks in new v0.1.8.5 examples.

### 3.1 Sweep Authoring Boundary

v0.1.8.5 accepts a pre-CRAN cleanup decision: do not keep two first-class
feature-parameter sweep models.

The supported feature-parameter sweep path is:

```text
parameterized feature map
  -> ledgr_feature_grid()
  -> ledgr_strategy_grid()
  -> ledgr_grid_cross()
  -> active aliases in ctx$features(id)
```

Legacy feature factories such as `features = function(params) ...` are no
longer a supported public path for parameterized feature sweeps. They may
remain as compatibility or advanced fixed-feature machinery, but docs must not
teach them as the feature-tuning path. If a legacy factory is used with
`feature_params`, executable grids, or parameterized bundle sweeps, ledgr
should fail or warn with a classed, action-oriented condition instead of
silently routing the wrong parameter bag.

`ledgr_param_grid()` remains available for strategy-only sweeps and legacy flat
parameter grids. It should be documented as compatibility/advanced surface,
not as the recommended way to tune feature declarations.

Direct parameterized multi-output bundle sweeps through active aliases should
be supported if the implementation fix is localized. The legacy feature-factory
bundle collision path should be documented as unsupported unless it can reuse
the active-alias disambiguation path with minimal risk.

---

## 4. Artifact Topology

Bind the documentation default to one project-local store:

```text
my-study/
  data-raw/
  artifacts/
    ledgr_store.duckdb
  R/
  scripts/
  notebooks/
  reports/
  README.md
```

Teach the roles:

- `data-raw/` contains user-owned raw inputs and download scripts, not ledgr
  execution evidence.
- `artifacts/ledgr_store.duckdb` contains sealed snapshots, committed runs,
  labels, tags, promotions, provenance, and generated ledgr evidence.
- `R/` and `scripts/` contain source-controlled research code.
- `notebooks/` are exploratory and may be disposable unless the user chooses
  to promote them into reports.
- `reports/` contain human-facing review artifacts.

The docs must be explicit that ignored artifacts are not disposable. A common
`.gitignore` may ignore `artifacts/`, but users still need ordinary backup
discipline for the store if they care about the evidence.

Physical split stores, shared snapshot stores, and cross-project snapshot
reuse are future advanced topology. v0.1.8.5 may mention them as future
pressure points, but must not teach them as a public workflow.

---

## 5. Data Lifecycle

Historical data discipline:

- new historical data creates a new sealed snapshot;
- vendor corrections create a new sealed snapshot;
- universe expansion creates a new sealed snapshot;
- multi-vendor comparisons use separate sealed snapshots;
- older snapshots remain necessary while promoted runs reference them.

Anti-patterns to name:

- appending new historical data into an existing sealed snapshot;
- resealing changed data under the same `snapshot_id`;
- deleting snapshots still referenced by runs or promotions;
- appending live ticks or bars into a backtest snapshot;
- treating synthetic gap fills or corrections as raw data without documenting
  the repair policy.

Snapshot lineage metadata is future scope. It may become a small API later
with fields such as `family`, `family_version`, `extends`, `supersedes`, and
`lineage_note`. v0.1.8.5 should teach the discipline without implementing the
lineage API.

Live production ticks and bars belong to future append-only data logs, not
sealed backtest snapshots. If live history later becomes research evidence, it
should be sealed into a new immutable snapshot.

---

## 6. Documentation Surface

### 6.1 Dedicated Workflow Article

Create a dedicated article or vignette, tentatively:

```text
vignettes/research-workflow.Rmd
```

This is the canonical end-to-end research workflow article. The existing
`vignettes/research-to-production.Rmd` must not compete with it. Default
disposition: narrow `research-to-production.Rmd` to a short
promotion-boundaries and future-production article that points to the workflow
article for the research path and to the roadmap for future paper/live work. If
that article remains substantially redundant with the new workflow article,
remove it from the main reading flow or replace it with a redirecting/narrowed
article.

The article should be runnable end to end where possible. If a section is
conceptual because it would require external data or large artifacts, it must
say so plainly and keep the runnable core intact.

Required article shape:

1. Project topology.
2. Snapshot creation from package-owned demo data or small local data.
3. Feature map with active aliases.
4. Strategy declaration using the demo strategy and a short custom-strategy
   bridge.
5. Single run.
6. Sweep.
7. Candidate inspection.
8. Why this is not validation.
9. Promotion with note.
10. Reopen from store.
11. Walk-forward and out-of-sample evaluation as the next roadmap layer, using
    a short "Future: Walk-Forward Evaluation" callout that links to
    `inst/design/ledgr_roadmap.md` and
    `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md` until
    a user-facing walk-forward article exists.
12. Report/review outline.

The report/review outline must include:

- hypothesis and data window;
- snapshot hash and data-source assumptions;
- feature and strategy declarations;
- candidate grid summary;
- top-N candidate table;
- warning/failure review;
- equity and drawdown plots;
- promotion note;
- reason for rejecting alternatives.
- selection caveat: the promoted candidate is not statistically validated by
  promotion itself.

### 6.2 README And Getting Started

README and Getting Started should continue to be first-contact documents, not
long workflow manuals. They should:

- show the fastest credible path to running a backtest;
- show the active-alias/grid model only as much as needed for that path;
- use one consistent store-path pattern;
- link to the research workflow article for the full evidence loop;
- link to focused vignettes for feature maps, sweeps, experiment stores,
  reproducibility, metrics, and strategy development;
- avoid mixing obsolete exact-ID sweep examples with the primary path.

v0.1.8.4 already rewrote large parts of README, Getting Started, Sweeps,
Indicators, and Strategy Development around active aliases and the demo
strategy. v0.1.8.5 should inventory and refine that work rather than assume a
blank slate. The known `README` strategy-source inspection regression from the
v0.1.8.4 documentation rewrite should be treated as a first-contact polish item
in Batch B: the README should prove that stored strategy source is inspectable
without overwhelming the quick-start path.

The README is not a feature catalog. It should answer:

1. What is ledgr?
2. How do I install or load it?
3. How do I run a small backtest quickly?
4. What evidence did that backtest produce?
5. Where do I go next for sweeps, stores, reproducibility, metrics, and
   strategy authoring?

Do not try to demonstrate every major capability in the README. Mention
capabilities briefly and route to the relevant vignette. The README should
sell the shape of the package and prove that a backtest can run, not teach the
whole research workflow.

`README.Rmd` is the source document and `README.md` must be regenerated or
updated with it. They should not drift.

Getting Started may be slightly longer than the README, but it should still
remain an onboarding path rather than a reference manual. If the user needs to
understand the full artifact lifecycle, send them to the research workflow
article.

### 6.3 Experiment Store And Reproducibility

Experiment Store docs should center on:

- the store as durable ledgr evidence;
- snapshot/run/promotion roles;
- labels, tags, archive state, and reopen;
- backup guidance;
- pre-CRAN schema compatibility caveats.

Backup guidance must be concrete enough to act on. Add a "Backup
Conventions" subsection that recommends at least one simple file-level pattern
for `artifacts/ledgr_store.duckdb`, such as copying or syncing the closed
DuckDB file to a separate backup location. It may mention alternatives such as
filesystem snapshots, cloud sync, Git LFS with size caveats, or DuckDB export,
but it must not leave users with only the phrase "ordinary backup discipline."

Reproducibility docs should connect:

- sealed snapshot hashes;
- feature fingerprints and feature-set hashes;
- strategy source and preflight tier;
- config hashes;
- promotion notes;
- the limits of provenance.

### 6.4 Sweeps

Sweeps docs should teach:

- `ledgr_feature_grid()`;
- `ledgr_strategy_grid()`;
- `ledgr_grid_cross()`;
- candidate inspection before promotion;
- warning and failure review;
- promotion as explicit research evidence.

Sweeps docs must also explain the legacy boundary:

- active aliases and executable grids are the supported feature-parameter
  sweep path;
- `ledgr_param_grid()` remains useful for strategy-only or legacy flat-grid
  sweeps;
- feature factories are not the supported path for parameterized feature
  sweeps;
- legacy factory bundle-output collisions are expected boundary failures unless
  a future implementation explicitly supports them.

Do not introduce objective-function or automatic winner-selection semantics.
Transparent ranking views remain a future horizon item.

### 6.5 Data Input And Snapshot Creation

If the existing Experiment Store article remains too broad, split low-level
snapshot material into a focused data-input article. The article may cover:

- local data frames and CSVs;
- Yahoo convenience adapter caveats;
- raw vs adjusted price policy;
- quantmod/network dependency notes;
- reproducible preprocessing before sealing;
- why sealing is an input boundary.

### 6.6 Compact Execution Semantics

Add a short standalone article, tentatively:

```text
vignettes/execution-semantics.Rmd
```

The article should be compact and linked from the workflow, strategy
development, sweeps, and metrics/accounting articles. Do not spread the core
execution explanation across many partial sections. It should explain:

- strategies return full named numeric target holdings;
- missing targets are errors, not implicit flat positions;
- strategy decisions see the pulse, not the future;
- next-open fill timing;
- cost application after strategy decisions;
- final-bar no-fill warnings;
- open-position metrics;
- `passed_warmup()` for feature readiness.

### 6.7 Vignette Narrative Standards

v0.1.8.5 must include a reading-flow and redundancy review for installed
articles.

Each major vignette should have one primary job:

- README: identity, quick backtest, and links.
- Getting Started: first guided run with minimal conceptual overhead.
- Research Workflow: full reproducible study path from snapshot to promotion
  and reopen.
- Data Input And Snapshot Creation: how input data becomes sealed evidence.
- Strategy Development: strategy contract, `ctx`, targets, warmup, state, and
  preflight.
- Indicators / Feature Maps: indicator declarations, active aliases,
  fingerprints, bundles, and feature identity.
- Sweeps: feature grids, strategy grids, candidate inspection, failures,
  warnings, and promotion.
- Experiment Store: durable artifacts, labels/tags/archive, comparison,
  recovery, and reopen.
- Reproducibility: hashes, strategy source, preflight tiers, config identity,
  and limits of provenance.
- Metrics And Accounting: derived fills/trades/equity/metrics and metric
  context.

The expected reading flow is:

```text
README
  -> Getting Started
  -> Research Workflow
  -> focused articles as needed:
       Data Input / Snapshot Creation
       Strategy Development
       Indicators / Feature Maps
       Sweeps
       Experiment Store
       Reproducibility
       Metrics And Accounting
```

Vignettes should link forward and sideways intentionally. They should not all
re-explain sealing, target holdings, feature aliases, and experiment stores
from scratch. If a concept has a canonical home, other articles should give a
short reminder and link there.

Every vignette should state its job early, either in prose or through its first
section heading. Examples should be runnable unless explicitly marked as
conceptual. Fragmentary code should be avoided in first-contact documents and
used sparingly elsewhere.

Redundancy is acceptable only when it prevents context loss. It is not
acceptable when it creates competing explanations of the same contract.

---

## 7. Small Helper Policy

v0.1.8.5 is documentation-first.

If implementation work discovers that a tiny helper is necessary for the docs
to be honest and runnable, it may be considered only if it is
documentation-supporting inspection or summary ergonomics. Examples:

- a read-only summary helper;
- a small print or inspection polish;
- a documentation-facing example fixture.

The helper must not add:

- storage layers;
- dispatch paths;
- identity surfaces;
- scaffold generation;
- execution semantics;
- new persistence schemas;
- cross-store topology;
- new optimizer or ranking semantics.

If a proposed helper violates those boundaries, stop and route it to a future
spec packet instead.

---

## 8. Auditr Routing

v0.1.8.5 accepts the workflow-shaped auditr findings from the v0.1.8.3 report
as documentation inputs:

- broader doc routing gaps;
- residual sweep inspection patterns;
- cross-surface accounting and metric semantics;
- "where do I look for X?" friction;
- runnable lifecycle examples for metrics and promotion where they support the
  canonical workflow;
- bounded data-source troubleshooting where it removes first-contact friction.

v0.1.8.5 does not reopen v0.1.8.4's completed runtime tickets. If a new bug is
found while writing docs, route it separately and keep the fix focused.

Ticket cut should name the auditr episodes or task IDs that the workflow docs
intend to exercise. If the packet cannot name them at ticket cut, the release
gate must at least include a manual checklist that maps the canonical workflow
steps to existing auditr surfaces.

### 8.1 Pending Auditr Report Slot

An auditr report is expected while this spec is active. Reserve space in the
ticket packet for a small auditr-intake batch after that report lands.

The intake must classify each finding before accepting work:

- **release blocker:** correctness, reproducibility, or severe user-confusion
  issue that must land before v0.1.8.5 release;
- **v0.1.8.5 docs fit:** finding that directly improves README, vignette flow,
  canonical workflow, artifact topology, or first-contact teaching;
- **v0.1.8.5 focused bug fit:** small defect discovered by auditr that can be
  fixed without opening a new architecture surface;
- **future roadmap:** valid finding that belongs to v0.1.8.6, v0.1.8.7,
  v0.1.9, or v0.2.x;
- **auditr-side:** issue in task setup, shell assumptions, or report
  generation rather than ledgr.

The auditr-intake batch must not become a general cleanup bucket. If a finding
requires new storage, dispatch, identity, risk, cost, OMS, or scaffold
semantics, defer it explicitly rather than absorbing it into this teachability
release.

Keep the intake bounded. If accepted auditr findings would add more than about
five tickets or one focused week of work, split them: release blockers and
direct teachability fits stay in v0.1.8.5; lower-priority docs polish and
architecture-shaped findings move to a later packet or `horizon.md`.

The v0.1.8.4 auditr report promotes one additional v0.1.8.5 decision:
legacy feature factories are no longer a supported feature-parameter sweep
path. Route parameterized bundle support through the active-alias path, and
route feature-factory collisions to classed warnings/errors plus documentation
unless a trivial implementation reuse is available.

---

## 9. Version Boundaries

This release intentionally does not consolidate v0.1.8.6 or v0.1.8.7 into
v0.1.8.5.

v0.1.8.6 is now a measurement and decision spike for DuckDB-backed feature
storage and out-of-core projection. It should compare the current R-memory
projection path against a block-hydrated DuckDB prototype before any storage
implementation is accepted. The output may be "implement", "defer", or "reject
for now".

v0.1.8.7 remains parallel sweep dispatch. It should come after the storage
decision because worker transport, payload size, and read-only DuckDB paths
affect parallel architecture.

v0.1.9 target risk should not be pulled into this release. The workflow docs
may mention risk as future work, but must not teach a placeholder risk API.

v0.2.x OMS, PIT data, corporate actions, snapshot lineage, roll-forward data
sources, and benchmark context stay out of this release. The accepted OMS
synthesis may be cited only as roadmap context.

The legacy sweep-authoring cleanup is not a new sweep engine. It narrows
ambiguous pre-CRAN public surface so the v0.1.8.4 active-alias model can be
taught and tested as the canonical feature-sweep route.

---

## 10. Proposed Ticket Cut

The exact LDG IDs should be assigned in the ticket packet. The cut should be
small enough that each batch can receive code review before the next one.

### Batch A: Workflow Article Spine

- Inventory current README and vignette flow before rewriting.
- Identify canonical homes for repeated concepts.
- Create the dedicated research workflow article.
- Build the runnable path with package-owned demo data where possible.
- Include the explicit selection-is-not-validation section.
- Link walk-forward and out-of-sample evaluation as future conceptual
  upgrades, not v0.1.8.5 implementation scope.
- Include the required report/review outline.
- Add documentation contract tests for the article's core vocabulary.

Minimum documentation contract checks for this batch:

- the workflow article contains all required article-shape sections from
  Section 6.1;
- the workflow article contains all report/review outline items from
  Section 6.1;
- the workflow article contains the selection-is-not-validation callout;
- the workflow article mentions walk-forward or out-of-sample evaluation as
  the next conceptual layer;
- warmup examples use `passed_warmup()`;
- backup guidance contains at least one concrete backup pattern.

### Batch B: First-Contact Alignment

- Update README and Getting Started to point at the same workflow.
- Reduce README to a quick-backtest path plus capability links, not a full
  feature catalog.
- Fix the README strategy-source inspection regression from the v0.1.8.4 docs
  rewrite so the audit-trail story is visible but concise.
- Keep them concise and route full detail to the workflow article.
- Verify no stale exact-ID examples are presented as the primary sweep path.
- Update `_pkgdown.yml` article ordering and grouping so site navigation
  matches the reading flow in Section 6.7.

Minimum documentation contract checks for this batch:

- README answers the five questions listed in Section 6.2;
- README links to the focused articles instead of demonstrating every major
  feature;
- `_pkgdown.yml` exposes the workflow article and preserves a coherent reading
  order.

### Batch C: Store, Data, And Reproducibility Docs

- Align Experiment Store and Reproducibility docs with the one-store topology.
- Add backup and pre-CRAN schema guidance.
- Split or add Data Input And Snapshot Creation material if needed.
- Name the Yahoo/real-data caveats only as far as needed for the workflow.

Minimum documentation contract checks for this batch:

- Experiment Store documentation has a "Backup Conventions" subsection;
- pre-CRAN compatibility guidance is visible from the public docs;
- data-input and snapshot-creation material is reachable from the reading
  flow;
- no public doc implies that sealed snapshots can be mutated in place.

### Batch D: Sweep Boundary And Execution Semantics Docs

- Audit legacy feature-factory and direct bundle-output sweep behavior.
- Support direct active-alias parameterized multi-output bundle sweeps if the
  fix is localized; otherwise fail with a classed explicit unsupported
  condition.
- Add classed, action-oriented warnings or errors for legacy feature-factory
  parameterized sweep paths that would otherwise receive the wrong parameter
  namespace.
- Align Sweeps docs with feature grids, strategy grids, candidate inspection,
  and promotion notes.
- Document the legacy sweep-authoring boundary: active aliases are the feature
  parameter sweep path; `ledgr_param_grid()` is strategy-only/legacy; feature
  factories are compatibility/advanced and unsupported for parameterized
  feature sweeps.
- Add the compact execution semantics article.
- Ensure warmup examples use `passed_warmup()`.

Minimum documentation contract checks for this batch:

- `vignettes/execution-semantics.Rmd` exists;
- execution semantics are linked from at least the workflow, strategy
  development, sweeps, and metrics/accounting articles;
- targeted feature-map, experiment, or sweep tests cover the supported
  active-alias bundle path and unsupported legacy boundary;
- Sweeps documentation does not introduce objective-function or automatic
  winner-selection semantics;
- Sweeps documentation contains the executable-grid versus legacy-flat-grid
  boundary;
- new warmup examples avoid ad hoc `!is.na(sma)`-style guards and use
  `passed_warmup()`.

### Batch E: Release Gate And Auditr Mapping

- Map canonical workflow steps to auditr surfaces or a manual release-gate
  checklist.
- Reserve and fill auditr-intake tickets from any report that lands while this
  packet is active.
- Run documentation contract tests.
- Render changed vignettes/articles.
- Run package checks required by the release playbook.
- Update tickets, NEWS, and design index as needed.

Minimum release-gate checks for this batch:

- release-gate checklist or closeout notes map the canonical workflow to
  tested/documented surfaces;
- pending auditr report has a recorded disposition if it lands before release;
- `README.Rmd` and `README.md` are synchronized;
- changed vignettes render or have a documented maintainer exception.

### Batch F: Optional Pending Auditr Intake

This batch exists only if the currently-running auditr report lands before the
v0.1.8.5 release gate.

- Classify findings using Section 8.1.
- Accept only release blockers, direct teachability/docs fits, and tightly
  scoped bugs.
- Defer architecture-shaped findings to the roadmap or horizon.
- Record explicit maintainer disposition for rejected or deferred items.

---

## 11. Acceptance Criteria

The release is acceptable when:

1. A user can follow one package-owned workflow path from snapshot to
   promotion and reopen.
2. The public docs consistently teach active aliases and separate feature vs
   strategy parameter namespaces.
3. Feature-parameter sweep docs and examples teach active aliases plus
   feature/strategy grids as the supported path.
4. `ledgr_param_grid()` is described as strategy-only or legacy flat-grid
   surface, and feature factories are not taught as the parameterized feature
   sweep path.
5. Unsupported legacy factory parameterization or bundle-collision paths fail
   or warn with classed, action-oriented conditions rather than silently
   routing the wrong parameter bag.
6. The project-local store topology is documented with clear boundaries
   between raw data, ledgr artifacts, source code, notebooks, and reports.
7. The docs explicitly say that ignored ledgr artifacts still need backups.
8. The docs explain new data, vendor corrections, and live ticks without
   implying in-place snapshot mutation.
9. Sweeps are presented as exploratory evidence, not automatic selection.
10. Promotion notes are visible as research evidence, not production approval.
11. The report/review outline from the workflow synthesis is present.
12. The workflow article explicitly distinguishes promotion from statistical
   validation.
13. The workflow article names walk-forward or out-of-sample evaluation as the
    next conceptual layer.
14. New warmup examples use `passed_warmup()`.
15. Pre-CRAN compatibility guidance is user-visible.
16. Experiment Store backup guidance contains at least one concrete backup
    pattern for `artifacts/ledgr_store.duckdb`.
17. v0.1.8.6 storage work remains a spike decision, not a hidden dependency of
    the workflow docs.
18. README demonstrates a quick credible backtest and routes capability depth
    to vignettes instead of trying to show every feature.
19. `_pkgdown.yml` navigation reflects the documented reading flow.
20. Vignettes have a documented reading flow and avoid competing explanations
    of the same contract.
21. Any auditr report that lands during the release has a disposition
    classified per Section 8.1.
22. Release-gate checks pass or failures are documented with maintainer
    disposition.

---

## 12. Explicit Deferrals

Do not implement these in v0.1.8.5:

- `ledgr_new_research_project()` or any scaffold generator;
- companion example repository;
- strategy family field guides;
- automatic candidate ranking or `ledgr_tune()`;
- split-store runtime;
- snapshot lineage API;
- live data log;
- seal-from-live-history workflow;
- production promotion records;
- PIT regressor snapshots;
- pins/vetiver model-artifact integration;
- DuckDB-backed feature storage;
- out-of-core projection;
- parallel sweep dispatch;
- target-risk chains;
- public transaction-cost model API;
- liquidity or capacity policy;
- OMS data-model implementation;
- benchmark context;
- corporate actions or instrument master;
- paper/live adapter work.

---

## 13. Release Notes Draft

v0.1.8.5 should be described as a documentation and workflow release:

- it teaches ledgr's canonical reproducible research path;
- it aligns first-contact docs with active aliases and grid helpers;
- it clarifies project artifact topology and backup expectations;
- it documents how to inspect and promote sweep evidence deliberately;
- it prepares the ground for the v0.1.8.6 storage spike and v0.1.8.7
  parallel-dispatch planning without implementing either.

Do not market it as a new runtime feature release.
