# RFC Synthesis: Research Workflow And Artifact Topology

**Status:** Accepted synthesis - binding planning direction for v0.1.8.5 and
future workflow/storage work. Does not amend the active v0.1.8.4 implementation
packet.
**Date:** 2026-05-26
**Author:** Codex
**Thread:**

- `inst/design/rfc/rfc_research_workflow_artifact_topology_v0_1_8_x.md`
- `inst/design/rfc/rfc_active_parameterized_feature_aliases_v0_1_8_x_synthesis.md`
- `inst/design/rfc/rfc_sweep_candidate_promotion_contract_v0_1_8_synthesis.md`
- `inst/design/rfc/rfc_sweep_promotion_context_v0_1_8_synthesis.md`
- `inst/design/ledgr_v0_1_8_4_spec_packet/v0_1_8_4_spec.md`
- Maintainer discussion on project scaffolds, companion examples, multi-year
  reseals, live production data logs, ML model artifacts, and point-in-time
  regressors.

**Response step skipped intentionally.** The seed absorbed multiple review
rounds before synthesis: scaffold/workflow feedback, production-retraining
scope, multi-year reseal semantics, live data-log boundaries, pins/vetiver
model-artifact boundaries, and external point-in-time regressor scope. The
seed-to-synthesis flow without a separate response document reflects that the
review iteration happened inside the seed.

---

## 1. Decision Summary

Accept the RFC's central position: ledgr should make the reproducible research
workflow the easiest workflow by default.

The canonical v0.1.x workflow is:

```text
seal data
  -> declare features and strategy
  -> sweep deliberately
  -> inspect evidence
  -> promote explicitly
  -> reopen from durable artifacts
```

The canonical v0.1.x artifact topology is one project-local experiment store:

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

The store contains sealed snapshots and derived ledgr artifacts. Raw source
data, source-controlled project code, exploratory notebooks, and user reports
stay outside the store.

v0.1.8.5 becomes the planned workflow/documentation cycle. It should not add a
new execution engine, split-store runtime, live data log, production promotion
record, snapshot lineage API, point-in-time regressor API, or project scaffold
helper. Those remain future work unless a separate spec packet scopes them.

---

## 2. Bound Workflow Contract

The v0.1.x teaching path should center on:

1. Create or load raw data outside ledgr.
2. Seal normalized market data into a ledgr snapshot.
3. Declare features, strategy code, and parameter grids as explicit project
   files.
4. Run a single backtest or sweep against sealed input evidence.
5. Inspect metrics, fills, equity, warnings, failures, and candidate identity.
6. Promote deliberately with `ledgr_promote(..., note = ...)`.
7. Reopen promoted evidence from the experiment store.

The workflow is not a tuning DSL, not a project-management framework, and not a
production-deployment approval system. It is the package-owned explanation of
how ledgr's existing evidence model should be used in real research projects.

---

## 3. Store Topology

Bind one project-local experiment store as the default v0.1.x topology:

```text
artifacts/ledgr_store.duckdb
```

This path should be the recommended path in new workflow docs and examples
unless a shorter temporary path is useful for a tiny demo. The name
`ledgr_store.duckdb` is intentionally generic: one store, many snapshots, runs,
sweeps, labels, tags, and promotion contexts.

The single-store model is logical, not conceptual. The workflow documentation
must still teach that these are different roles:

```text
sealed snapshots      = immutable normalized input evidence
committed runs        = derived execution evidence
sweeps                = candidate evaluation artifacts
promotion context     = explicit selection evidence
reports/scripts/code  = user-owned project files outside the store
```

Physical split stores are future advanced topology. Do not teach split
snapshot/run stores as the public workflow until ledgr has first-class API
support for run-store discovery, promotion, comparison, and reopen.

---

## 4. Data Lifecycle

### Historical Data

New historical data, vendor corrections, universe expansions, and multi-vendor
comparisons create new sealed snapshots. They do not mutate an existing sealed
snapshot.

The workflow must reject these anti-patterns:

- append new historical data into an existing sealed snapshot;
- reseal changed data under the same `snapshot_id`;
- delete old snapshots while runs or promotions still reference them;
- treat synthetic, gap-filled, or vendor-corrected data as raw input without
  recording the repair or correction policy.

### Snapshot Lineage

Snapshot lineage metadata is accepted as a future lightweight API direction,
not a v0.1.8.5 requirement.

Future metadata may include:

- `family`;
- `family_version`;
- `extends`;
- `supersedes`;
- `lineage_note`.

A helper such as `ledgr_snapshot_family()` is a plausible small API after the
workflow docs land, but it should not be implemented inside the v0.1.8.4 active
alias work and does not need to block v0.1.8.5 documentation.

### Live Production Data

Live production ticks and bars belong to an append-only live data log, not to
the sealed snapshot that justified a promoted backtest.

Future production topology must distinguish:

```text
promoted_from:
  training snapshot hash
  validation snapshot hash
  strategy hash
  feature params
  strategy params
  model artifact ref, if any

running_on:
  live data log id
  feed id
  session/calendar policy
  gap policy
  correction policy
```

If live history becomes research evidence, the future workflow should seal a
historical range from the live log into a new immutable snapshot.

Live data logs, gap detection, repair/backfill policy, corrections, and
seal-from-live-history workflows are future production or paper-trading
topology. They are not v0.1.8.5 scope.

---

## 5. Documentation And Scaffolding Policy

v0.1.8.5 is documentation-first.

Create or revise docs so users can see the canonical workflow without needing a
project generator:

- a dedicated research-workflow article or vignette;
- Getting Started updated to point at the canonical workflow without absorbing
  all detail;
- Experiment Store docs aligned with the one-store topology;
- Sweeps docs aligned with active aliases, feature grids, strategy grids, and
  promotion;
- Reproducibility docs aligned with backup, schema, and sealed-snapshot
  discipline.

Do not add `ledgr_new_research_project()` in v0.1.8.5. A scaffold helper can
be reconsidered after the docs prove stable and either auditr or maintainer
review shows that manual project setup remains a meaningful usability problem.

Report templates should not be public API in the first pass. The workflow docs
may give a recommended report outline:

- hypothesis and data window;
- snapshot hash and data-source assumptions;
- feature and strategy declarations;
- candidate grid summary;
- top-N candidate table;
- warning/failure review;
- equity and drawdown plots;
- promotion note and reason for rejection of alternatives.

Generated project scaffolds and companion examples can later turn that outline
into concrete files.

---

## 6. Companion Examples

Accept `ledgr-examples` as a future education/product direction, not a core
runtime dependency and not a v0.1.8.5 requirement.

The companion repo should contain complete worked studies:

```text
snapshot -> features -> grids -> sweep -> review -> promote
```

It must be governed as examples, not as an official strategy library:

- no profitability claims;
- no hidden provider downloads;
- no black-box reusable strategy objects;
- examples use sealed snapshots, explicit features, explicit params, ordinary
  validation, and promotion notes;
- richer strategy families live outside the core package unless a later product
  decision creates a strategy-template package.

Core ledgr may keep one small demo strategy as a teaching fixture if scoped by
the v0.1.8.4 active-alias spec. That is not a commitment to build a strategy
zoo in core.

---

## 7. Point-In-Time Regressors And ML Artifacts

External point-in-time regressors are a separate future data RFC. The workflow
docs may mention them only to avoid painting the topology into a corner.

Future scope:

- fundamentals;
- macroeconomic releases;
- analyst estimates;
- vendor factors;
- alternative data;
- vintage metadata and ASOF lookup semantics;
- sealed regressor snapshots and lineage.

DuckDB remains the default near-term backbone where scale permits. It fits the
local-first, R-native, columnar, ASOF-join-heavy shape of point-in-time
research. Tick-scale data, very large stores, and multi-writer platforms remain
split-store or external-backend questions.

ML model artifacts remain horizon scope. `pins` and `vetiver` are the likely
future boundary tools for trained model objects, model cards, prototypes,
lockfiles, monitoring artifacts, and deployed model endpoints. ledgr should own
the backtest evidence and immutable model references, not the model registry
implementation.

The ML abstraction remains pulse-based:

```text
current pulse context -> model prediction or prediction lookup -> target vector
```

Do not design ML replay around "latest model" lookup.

---

## 8. Parallel And Split-Store Constraints

The canonical single-store workflow must not imply unsynchronized concurrent
writes to one DuckDB file.

The future v0.1.8.7 parallel dispatch design must choose an explicit write
strategy, such as:

- workers produce isolated in-memory candidate results and the main process
  owns writes;
- workers write worker-local artifacts that are merged centrally;
- a future split-store dispatcher owns the durable write path.

No parallel design may weaken deterministic row order, warning/error
association, seed derivation, or promotion provenance to fit worker scheduling.

Split snapshot/run stores remain future advanced topology. They require
first-class run-store APIs before public documentation should teach them.

---

## 9. Versioning, Backup, And Portability

Until ledgr reaches its first CRAN release, stored DuckDB artifacts are
development artifacts. Workflow docs must say that upgrading ledgr may require
rerunning experiments from source data, feature declarations, strategy code,
and parameter grids.

Near-term policy:

- stores carry schema/package metadata where available;
- incompatible reads fail loudly with action-oriented messages;
- no automatic migration guarantee before ledgr has a stable public artifact
  contract;
- source code and raw/source data should be preserved so artifacts can be
  recreated.

`artifacts/` should be git-ignored by default, but it is not disposable. Users
must back it up with ordinary project backup discipline: filesystem snapshots,
archives, replicated storage, or their team's normal backup system. ledgr does
not claim to be a backup tool.

Sealed snapshots should be treated as self-contained replay evidence. If the
store records original source paths, those paths are provenance metadata, not
runtime dependencies for replay.

---

## 10. Open Question Positions

1. **Docs-first convention now?** Yes. Bind docs-first. Scaffold helper later.
2. **New workflow vignette/article?** Yes. Add a dedicated workflow article.
   Getting Started and Experiment Store should link to it rather than carry the
   full workflow.
3. **Default store path?** Use `artifacts/ledgr_store.duckdb` in canonical
   docs.
4. **Report templates?** Do not ship a public template helper now. Provide a
   recommended report outline.
5. **Split stores in public docs?** Mention only as future/advanced topology
   until first-class APIs exist.
6. **When add `ledgr_new_research_project()`?** After workflow docs stabilize
   and review evidence shows manual setup remains a real problem.
7. **Companion repo?** Yes, later, as worked examples rather than a strategy
   library.
8. **Production promotion records?** Separate RFC.
9. **Cross-project snapshot reuse?** Defer until split stores or a snapshot
   catalog design. Accept duplication for now.
10. **Qmd or Rmd?** Keep installed package vignettes in Rmd while the package
    docs are Rmd-based. User project reports and future scaffolds may use Qmd.
11. **Backup guidance?** Strong user-owned guidance: ignored does not mean
    disposable.
12. **Parallel dispatch coordination?** Main process or dispatcher owns durable
    writes; no unsynchronized concurrent writes to one store.
13. **Snapshot lineage metadata?** Future lightweight API after workflow docs,
    not v0.1.8.5.
14. **Production data-log contract?** Separate production/paper-trading RFC.
15. **PIT regressors before ML?** Yes. Serious ML/factor research depends on
    vintage-correct external inputs, so PIT regressors should have their own RFC
    before broad ML strategy workflows.

---

## 11. v0.1.8.5 Scope

v0.1.8.5 should be planned as:

```text
Canonical Research Workflow And Artifact Topology
```

Expected scope:

- write the workflow article/vignette;
- update Getting Started, Experiment Store, Sweeps, and Reproducibility docs to
  align with the canonical workflow;
- add README roadmap or quickstart language only where it improves first
  contact;
- document the `artifacts/ledgr_store.duckdb` convention and backup guidance;
- align auditr-routed workflow issues with the canonical path;
- keep active-alias examples coherent with v0.1.8.4 if that cycle has landed.

Non-goals:

- no `ledgr_new_research_project()`;
- no split-store runtime;
- no snapshot lineage API;
- no live data log;
- no production promotion record;
- no point-in-time regressor API;
- no pins/vetiver dependency;
- no companion repo implementation;
- no strategy-template package.

If v0.1.8.4 implementation surfaces a small documentation-supporting helper
that is necessary for the canonical workflow, the v0.1.8.5 spec may consider
it explicitly. The default assumption is docs and workflow alignment, not
runtime architecture.

---

## 12. Roadmap Placement

This synthesis fills the previously reserved v0.1.8.5 slot. The original
parameter-grid helper scope moved into v0.1.8.4, leaving room for a focused
workflow cycle before DuckDB-backed feature storage and parallel dispatch.

The ordering is intentional:

```text
v0.1.8.4 active aliases and grid UX
v0.1.8.5 canonical workflow docs and artifact topology
v0.1.8.6 optional DuckDB-backed feature storage
v0.1.8.7 parallel dispatch
v0.1.9 target risk and primitive-internals planning gates
```

Workflow comes before parallel dispatch because the single-store write boundary
must be clear before larger sweeps and worker coordination become public
surface. Workflow also comes before broader ML/data work because PIT
regressors, pins/vetiver, and live logs need the same artifact-discipline
language.

