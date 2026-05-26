# RFC Seed: Research Workflow And Artifact Topology

**Status:** Design seed - superseded by accepted synthesis
`inst/design/rfc/rfc_research_workflow_artifact_topology_v0_1_8_x_synthesis.md`.
**Date:** 2026-05-26
**Author:** Codex
**Target Scope:** v0.1.8.x / v0.1.9 planning; not binding for v0.1.8.4
implementation unless accepted by a later synthesis.
**Inputs:**

- `inst/design/contracts.md`
- `inst/design/ledgr_roadmap.md`
- `inst/design/horizon.md`
- `inst/design/rfc/rfc_active_parameterized_feature_aliases_v0_1_8_x_synthesis.md`
- `inst/design/rfc/rfc_sweep_candidate_promotion_contract_v0_1_8_synthesis.md`
- `inst/design/rfc/rfc_sweep_promotion_context_v0_1_8_synthesis.md`
- `inst/design/ledgr_v0_1_8_4_spec_packet/v0_1_8_4_spec.md`
- Maintainer discussion on research scaffolding, companion examples, split
  snapshot/run stores, ML model artifacts, and production retraining.

---

## 1. Problem Statement

ledgr now has enough public surface that the API alone does not fully answer a
more important product question:

> What workflow should ledgr make easy by default, and what artifact topology
> should support it?

This is broader than whether ledgr should ship a project scaffold. It affects:

- README and getting-started examples;
- the future shape of a "project workflow" or "research workflow" vignette;
- whether ledgr should generate starter projects;
- whether the default artifact layout should be one DuckDB store or multiple
  stores;
- how users should distinguish sealed input evidence from derived execution
  artifacts;
- how production retraining, model artifacts, walk-forward studies, and team
  research stores should eventually fit.

The current package mostly nudges users toward a single experiment store: the
DuckDB file behind a sealed snapshot stores market data, committed runs,
labels, tags, promotion context, comparison artifacts, and telemetry together.
Some lower-level paths can run against a separate run DB by attaching the
snapshot DB read-only, but that topology is not first-class in the
experiment-first workflow. `ledgr_run()` and `ledgr_promote()` write to
`exp$snapshot$db_path`; run-store APIs discover runs from the snapshot handle's
database.

The RFC asks what ledgr should teach as canonical now, what should remain
advanced/future, and what scaffolding or documentation should encode the
answer.

---

## 2. Thesis

ledgr should make the reproducible research workflow the easiest workflow:

```text
seal data
  -> declare features and strategy
  -> sweep deliberately
  -> inspect evidence
  -> promote explicitly
  -> keep reproducible artifacts in a project-local experiment store
```

For v0.1.x, the recommended artifact topology should be one project-local
experiment store:

```text
my-study/
  data-raw/
  artifacts/
    ledgr_store.duckdb
  R/
  scripts/
  reports/
  README.md
```

The store contains sealed snapshots and derived execution artifacts. Raw source
data, user reports, scripts, and source-controlled project files stay outside
the store.

The teaching model should distinguish logical roles inside the store:

```text
sealed snapshot = immutable normalized input evidence
runs/sweeps     = derived execution evidence
promotion notes = explicit research decisions
```

The default should not teach separate snapshot/run/promotion stores yet.
Physical separation is useful later for shared snapshot stores, compliance
immutability, multi-project reuse, or large-team workflows, but the current
public API does not make that topology first-class.

---

## 3. Current State

### Supported And Recommended Today

The current public workflow is:

```r
snapshot <- ledgr_snapshot_from_df(bars, db_path = "artifacts/ledgr_store.duckdb")
exp <- ledgr_experiment(snapshot, strategy, features = features)
results <- ledgr_sweep(exp, grid)
candidate <- ledgr_candidate(results, "candidate_id")
bt <- ledgr_promote(exp, candidate, run_id = "promoted_run")
ledgr_compare_runs(snapshot)
```

This writes committed run artifacts into the same DuckDB file as the sealed
snapshot. Research promotion rationale is already supported through
`ledgr_promote(..., note = "...")` and durable promotion context; production
approval records remain future scope. Run discovery starts from the snapshot
handle:

- `ledgr_run_list(snapshot)`
- `ledgr_run_info(snapshot, run_id)`
- `ledgr_compare_runs(snapshot)`
- `ledgr_run_open(snapshot, run_id)`
- `ledgr_run_label(snapshot, run_id, ...)`
- `ledgr_run_tag(snapshot, run_id, ...)`

This is the behavior that documentation should treat as canonical.

### Partially Supported But Not First-Class

`ledgr_backtest(snapshot = snap, db_path = run_db, ...)` can write a run to a
separate run database. The runner records `data$snapshot_db_path` and attaches
the snapshot database read-only while executing or reconstructing state.

This confirms the underlying engine can understand separate snapshot and run
paths. However, the topology is not first-class in the public
experiment-first workflow:

- `ledgr_run(exp, ...)` has no run DB argument and uses `exp$snapshot$db_path`;
- `ledgr_promote()` calls `ledgr_run()`;
- run-store discovery APIs search the snapshot DB;
- a split-store run can be inspected from its returned `ledgr_backtest` handle,
  but not from `ledgr_run_open(snapshot, run_id)`.

Therefore split stores should be described as future/advanced, not as the
default scaffold.

---

## 4. Canonical Workflow Patterns

The RFC should not pretend every ledgr user works the same way. It should
identify several acceptable workflow patterns and pick one teaching default.

### Pattern A: Script-Numbered Teaching Workflow

```text
scripts/
  01_make_snapshot.R
  02_define_experiment.R
  03_sweep_train.R
  04_review_results.R
  05_promote_candidate.R
```

Advantages:

- easy to teach;
- easy to run in order;
- explicit about the canonical lifecycle;
- good for examples, demos, and generated starter projects.

Disadvantages:

- can imply a one-pass workflow even though real research is iterative;
- script numbers can become stale as projects mature.

Recommendation: use this as the first teaching/default scaffold pattern, not
as the only endorsed workflow.

### Pattern B: Notebook Or Report-First Workflow

```text
reports/
  research_notebook.qmd
  sweep_review.qmd
```

Advantages:

- good for narrative research and exploratory review;
- convenient for teaching and sharing with humans.

Disadvantages:

- easier to mix setup, execution, and interpretation;
- harder to test and rerun in small pieces;
- can hide stateful side effects.

Recommendation: support through examples and report templates, but do not make
notebooks the only canonical workflow.

### Pattern C: Package-Style Research Project

```text
R/
  features.R
  strategy.R
  grids.R
scripts/
  run_sweep.R
  review_candidate.R
tests/
```

Advantages:

- better for long projects;
- code is testable and reusable;
- integrates well with CI and team review.

Disadvantages:

- heavier for first-time users;
- more setup than a small study needs.

Recommendation: document as the serious-project escalation path after the
teaching workflow.

---

## 5. Project Layout Recommendation

Recommended default layout:

```text
my-ledgr-study/
  README.md
  .gitignore
  data-raw/
  artifacts/
    ledgr_store.duckdb
  R/
    features.R
    strategy.R
    grids.R
  scripts/
    01_make_snapshot.R
    02_single_run.R
    03_sweep_train.R
    04_review_results.R
    05_promote_candidate.R
  notebooks/
    scratch.qmd
  reports/
    sweep_review.qmd
    validation_report.qmd
```

Suggested ownership:

- `data-raw/`: user-owned original data files or local export staging. ledgr
  does not treat these as sealed evidence.
- `artifacts/`: generated ledgr artifacts, ignored by git by default.
- `artifacts/ledgr_store.duckdb`: project-local experiment store.
- `R/`: source-controlled feature, strategy, and grid definitions.
- `scripts/`: source-controlled execution drivers.
- `notebooks/`: optional scratch or narrative exploration. This gives
  iterative work a home without polluting the numbered workflow scripts.
- `reports/`: user-owned Qmd/Rmd reports. First pass should not introduce
  `ledgr_report_*()` helpers.
- `README.md`: study purpose, assumptions, execution order, and artifact
  policy.

Suggested `.gitignore` baseline:

```text
artifacts/
*.duckdb
*.duckdb.wal
*.duckdb.tmp
.Rhistory
.RData
```

Git guidance:

- commit source code, documentation, report sources, and small example inputs
  when appropriate;
- do not commit mutable DuckDB experiment stores by default;
- do not commit large raw vendor downloads unless the project explicitly owns
  that storage policy;
- write export artifacts for sharing when needed instead of treating the store
  as a git-friendly file.

Backup and recovery policy:

- the experiment store is the project-local source of truth for sealed
  snapshots and committed runs;
- ignoring `artifacts/` in git does not mean the artifacts are disposable;
- users should back up `artifacts/` with ordinary project backup discipline,
  such as filesystem snapshots, compressed archives, replicated storage, or
  team storage policy;
- ledgr should not claim recovery from a deleted or corrupted store unless a
  future backup/export helper explicitly provides it.

Report guidance:

- use `reports/sweep_review.qmd` or `.Rmd` for human review;
- first-pass workflow docs should recommend a minimum review checklist:
  candidate table, top candidate metrics, warnings/failures, sample equity
  curves, drawdown view, promotion rationale, and any rejected caveats;
- ledgr should not add `ledgr_report_*()` helpers in the first workflow pass.

Quarto/R Markdown policy:

- package vignettes may remain Rmd while current documentation infrastructure
  uses R Markdown;
- project workflow examples may show Qmd because Quarto is the more modern
  report format, but should not require Quarto for core package execution;
- generated scaffolds, if added later, should either support both `.qmd` and
  `.Rmd` or document the chosen report engine explicitly.

---

## 6. Use Cases

### Tiny Learning Project

Goal: learn ledgr or demonstrate one strategy shape.

Recommended topology:

```text
one temp or local demo store
one demo strategy
one small feature grid
```

Docs may use `tempfile()` to avoid writing into user projects. Generated
research scaffolds should use project-local ignored artifacts instead.

### Long Discretionary Research Project

Goal: iterate on hypotheses, features, parameters, and review.

Recommended topology:

```text
one project-local experiment store
many sealed snapshots if data windows change
many sweep results
selected promoted runs
user-owned reports
```

The important discipline is not one-pass execution; it is explicit evidence:
which snapshot, which features, which strategy hash, which params, which
metrics, which promotion decision.

### Multi-Year Research With Periodic Reseal

Goal: keep a study alive as new market data arrives, vendors correct history,
or the research universe changes, while preserving the audit trail for earlier
runs.

Recommended topology:

```text
one project-local experiment store
many sealed snapshots in a logical family
each run references the exact snapshot it used
older snapshots retained while runs or promotions depend on them
```

New data should produce a new sealed snapshot. A sealed snapshot is immutable
input evidence, not an append target. Quarterly refreshes, vendor correction
reseals, universe expansions, and multi-vendor comparisons should therefore
create separate snapshots with stable names such as `spy_qqq_2026_q1`,
`spy_qqq_2026_q2`, or `vendor_b_spy_2026_q2`.

The current package can already store multiple snapshots in one DuckDB file.
What it does not yet provide is first-class lineage metadata that says "this
snapshot extends that snapshot" or "this snapshot supersedes that snapshot
because the vendor corrected history." A future lightweight lineage API should
consider optional snapshot metadata such as:

- `family`: a logical group such as `spy_qqq_main` or
  `walk_forward_60m_12m`;
- `family_version`: a monotonic version or date-stamped version inside the
  family;
- `extends`: the previous snapshot when a reseal adds newer data;
- `supersedes`: the previous snapshot when a reseal replaces data because of
  corrections or vendor changes;
- `lineage_note`: human-readable reason for the reseal.

Possible future inspection helper:

```r
ledgr_snapshot_family(snapshot, family = "spy_qqq_main")
```

This RFC should preserve the distinction without making lineage metadata a
v0.1.8.4 implementation requirement.

### Active-Alias Parameter Sweep

Goal: explore feature parameters and strategy parameters without dynamic
feature factories inside strategies.

Recommended topology:

```text
features.R       -> ledgr_feature_map(... ledgr_param(...))
grids.R          -> feature_grid + strategy_grid + ledgr_grid_cross()
03_sweep_train.R -> ledgr_sweep()
04_review.R      -> candidate inspection
05_promote.R     -> ledgr_promote()
```

This should be the v0.1.8.4-era teaching path.

### Production Retraining

Goal: periodically retrain or reselect an algorithm for deployment.

This RFC should describe the workflow but should not define production
deployment APIs.

Likely workflow:

```text
training snapshot
validation / forward-test snapshot
sweep or training run
candidate selection
promotion decision
deployment handoff
later retrain creates a new decision record
```

Required evidence for a future production promotion record may include:

- training snapshot hash;
- validation snapshot hash;
- strategy hash;
- feature parameters;
- strategy parameters;
- feature-set hash;
- alias-map hash;
- metric context;
- model artifact reference when ML is involved;
- approval actor or automated policy result;
- promotion timestamp and note.

Recommendation: carve production promotion records into a later RFC. The
current package has promotion context for research replay, but production
deployment, paper trading, OMS adapters, and retraining governance are broader
than this workflow RFC.

This means v0.1.x can teach:

```r
ledgr_promote(exp, candidate, run_id = "candidate_12", note = "Selected after train-window review.")
```

as research promotion evidence. It should not yet teach that this is a formal
production deployment approval record.

### Live Production Feed Capture

Goal: run a promoted algorithm against market data that continues to arrive
after the historical snapshot used for research and promotion.

This is related to the workflow RFC, but it is not the same artifact type as a
sealed research snapshot. Live production data is naturally append-oriented:
new ticks or bars arrive, gaps can occur, vendors can backfill corrections, and
operational systems need to know what was observed when. Sealed snapshots are
immutable replay inputs. ledgr should not blur those contracts.

Future topology:

```text
promoted decision record
append-only live data log
feed/session calendar policy
gap detection policy
gap repair / backfill policy
execution and decision log
periodic seal from live log into a new historical snapshot
```

The production record should eventually reference both sides:

```text
promoted_from:
  training snapshot hash
  validation snapshot hash
  strategy hash
  feature params
  strategy params
  model artifact ref, if ML is involved

running_on:
  live data log id
  feed id
  calendar/session policy
  gap policy
  correction policy
```

Append semantics belong to the live data log, not to sealed snapshots. If the
live log becomes research evidence later, the correct move is to seal a
historical range from that log into a new snapshot and run backtests against
that new immutable input.

This should be carved into a later production/paper-trading data-topology RFC.
The workflow RFC should only name the boundary so users do not infer that live
ticks or bars should be appended to the promoted backtest snapshot.

### Walk-Forward Research

Goal: repeated train/test windows without selection leakage.

Future topology:

```text
many sealed window snapshots or slice descriptors
one sweep/run set per window
one review artifact per window
one aggregate walk-forward result
```

This depends on a future walk-forward design. The current RFC should only make
the project layout compatible with it.

Compatibility sketch:

```text
artifacts/ledgr_store.duckdb
  snapshots:
    train_2019_h1
    test_2019_h2
    train_2020_h1
    test_2020_h2
  future walk-forward metadata:
    window_id
    train_snapshot_id
    validation_snapshot_id
    selected_run_id
    decision_note
```

The single-store default can hold this shape for early walk-forward work. A
future walk-forward RFC should decide whether windows are materialized as
separate snapshots, slice descriptors over larger snapshots, or both.

### External Point-In-Time Regressors

Goal: keep the workflow compatible with external research data beyond OHLCV
bars, such as fundamentals, macro releases, analyst estimates, vendor factors,
or alternative data.

This is future scope. The workflow RFC should only record that serious quant
research needs point-in-time regressor discipline: a backtest must use the
value known at the historical decision time, not the value later revised or
known today. These data sets have vintage semantics and should follow the same
sealing discipline as bar snapshots when they become ledgr-owned replay inputs.

DuckDB is still the natural backbone for this class of work in the foreseeable
roadmap. Its columnar storage and ASOF joins fit point-in-time lookup patterns
well enough for daily, moderate intraday, fundamentals, macro, and many
research-scale alternative data sets. Very large tick-scale or multi-writer
data platforms may eventually require split stores, Parquet/Arrow layouts, or
external databases, but that is not the v0.1.x default.

A separate "External Data And Point-In-Time Regressors" RFC should design the
snapshot, lineage, lookup, and feature-projection contracts. This workflow RFC
only needs to confirm that the canonical topology does not preclude sealed
regressor snapshots and PIT-correct lookup later.

### ML Strategy Research

Goal: train models, evaluate predictions in the ledgr fold, and preserve model
provenance.

Do not put ML model objects into ledgr's core store as the near-term default.
Future design should likely use `pins` / `vetiver` for trained model artifacts
and ledgr for exact references to those artifacts.

Likely topology:

```text
ledgr store:
  snapshots, runs, sweeps, fills, metrics, promotion notes, model refs

pins/vetiver board:
  trained models, prototypes, lockfiles, model cards, monitoring artifacts
```

The strategy abstraction should remain pulse-based. A model decision is still
made at the pulse boundary. Expensive prediction should be optimized by loading
models once, caching prediction artifacts, or precomputing prediction matrices
when that is causal and reproducible.

This is horizon scope. Mention in this RFC only to avoid designing the project
layout into a corner.

### Shared Team Research Store

Goal: multiple people inspect or contribute artifacts.

Current recommendation: one project-local store per project, with explicit
exports for sharing. Multi-user write concurrency and shared snapshot stores
are future topology questions.

Parallel dispatch note: v0.1.8.7-style parallel sweep workers are the
near-term single-user version of the same write-concurrency problem. A future
parallel design must define whether workers write only isolated in-memory
candidate results and merge in the main process, use worker-local artifact
stores, or require a split-store/dispatcher-owned write path. The canonical
single-store workflow should not imply unsynchronized concurrent writes to one
DuckDB file.

Future split-store triggers:

- repeated cross-project reuse of the same large snapshot;
- team-level immutable input stores;
- compliance policy requiring write separation;
- multi-writer contention in one DuckDB file;
- large artifact size or archival policy differences.

Order-of-magnitude guidance: a single local store is the right default for
daily or moderate intraday research. When a store grows into tens of gigabytes,
backup/copy time and artifact cleanup become real workflow concerns. At
hundreds of gigabytes, split storage, shared snapshots, or out-of-core feature
storage should be treated as architecture work rather than project hygiene.

Cross-project reuse before split stores are first-class: accept duplication or
deliberately use one shared project store. Do not recommend symlink hacks or
manually attaching snapshot stores as the normal user workflow.

Portability guidance: sealed snapshots should be treated as self-contained
normalized market-data evidence. Workflow docs should avoid depending on
absolute local paths inside reproducibility-critical records; raw-data source
paths can be useful metadata, but replay should depend on sealed snapshot
content and hashes.

### Audit And Replay

Goal: reconstruct what happened from stored artifacts.

The canonical workflow should make replay easy:

- load snapshot handle;
- list runs;
- inspect run info and promotion context;
- open run handle;
- compare runs;
- verify snapshot hash and config hash.

This aligns with existing experiment-store APIs and with auditr-style workflow
probes.

---

## 7. Scaffold API Decision

This RFC should explicitly decide whether v0.1.x needs a public scaffold
helper.

Options:

### Option A: Docs-Only Convention

No new API. README, getting-started, and a workflow vignette show the canonical
layout. Users copy or adapt it.

Advantages:

- zero new API surface;
- lowest maintenance;
- easy to revise before workflow stabilizes.

Disadvantages:

- less discoverable;
- users still assemble files manually.

### Option B: Core Scaffold Helper

Add a public helper later:

```r
ledgr_new_research_project(
  path,
  template = "active-alias-sweep"
)
```

Advantages:

- discoverable;
- gives users a correct starting point;
- useful for agentic workflows where file structure matters.

Disadvantages:

- creates template maintenance debt;
- every workflow change becomes a template migration question;
- may overstate ledgr's ownership of project structure.

### Option C: Docs First, Helper Later

Document the convention now. Add a helper only after active aliases, grid
helpers, pulse debugging, and the first workflow vignette settle.

Recommended first response position: Option C.

Do not add `ledgr_new_research_project()` to v0.1.8.4. v0.1.8.4 should finish
active aliases, grid helpers, pulse-debug naming, demo strategy, and docs. A
scaffold helper should encode that stabilized workflow rather than shape it.

---

## 8. Companion Repo Decision

Do not conflate three ideas:

1. core ledgr demo strategy;
2. companion example-project repository;
3. strategy-template library.

The v0.1.8.4 spec already proposes one core demo strategy for documentation.
That is enough for the core package.

A future companion repository can be valuable if it is framed as
`ledgr-examples`: complete worked studies showing the canonical workflow. It
should not be a library of prebuilt alpha strategies. Examples should remain
educational, copyable, and explicit.

Good companion repo shape:

```text
ledgr-examples/
  active-alias-sma-crossover/
  rsi-threshold/
  breakout/
  volatility-filter/
```

Each example should include:

- data acquisition or demo-data setup;
- snapshot creation;
- feature declarations;
- feature grid and strategy grid;
- strategy function;
- sweep script;
- review report;
- promotion decision example.

Avoid exporting reusable strategy functions from the companion repo unless a
later product decision explicitly creates a strategy-template package. Keep the
first companion repo as worked examples, not an API dependency.

---

## 9. Anti-Patterns To Avoid

The canonical workflow should steer users away from:

- many anonymous temp DuckDB files in durable research;
- one DuckDB file per run as the default;
- hidden auto-generated artifacts with no stable paths;
- raw source data stored only inside ledgr;
- production deployment from an unpromoted sweep row;
- appending live ticks or bars to a sealed snapshot;
- resealing changed data under the same `snapshot_id`;
- deleting old snapshots while runs or promotions still reference them;
- treating synthetic, gap-filled, or vendor-corrected live data as raw input
  without recording the repair policy;
- calling feature factories from inside strategy code;
- using "latest model" lookup for deterministic ML replay;
- treating example strategies as profitability claims;
- committing mutable DuckDB stores to git by default.

---

## 10. Schema And Version Compatibility

Until ledgr reaches its first CRAN release, stored DuckDB artifacts are
development artifacts. The workflow documentation should say that upgrading
ledgr may require rerunning experiments from source data, feature declarations,
strategy code, and parameter grids.

Near-term policy:

- stores should carry schema and package-version metadata where available;
- incompatible reads should fail loudly with an action-oriented message rather
  than partially interpreting old artifacts;
- workflow docs should teach users to preserve the code and raw/source data
  needed to recreate artifacts;
- no automatic migration guarantee should be promised before the package has a
  stable public artifact contract.

Post-CRAN or post-stabilization policy can revisit explicit migrations,
export/import bundles, or long-term artifact compatibility. That belongs in a
separate storage/schema RFC.

---

## 11. Comparison Context

The workflow should be framed with confidence. ledgr's design is heavier than
notebook-only backtesting tools, but it earns that weight through sealed input
artifacts, strategy/config hashes, event-sourced execution, and explicit
promotion context.

Compared with general experiment trackers such as MLflow, ledgr is narrower
and R-native. It does not have a tracking server, model registry, or web UI.
The tradeoff is a simpler local artifact story and stronger backtest-specific
reproducibility through sealed snapshots and fold contracts.

Compared with most backtesting frameworks, ledgr is more opinionated about
artifact discipline. That is intentional. The canonical workflow should make
clear that the upfront structure is the price of defensible replay.

---

## 12. Auditr Alignment

The canonical workflow should be the workflow auditr probes:

```text
snapshot -> experiment -> run -> sweep -> inspect -> promote -> reopen
```

Auditr findings should be triaged against this workflow. If auditr exposes user
confusion, missing messages, or unsafe defaults in this path, those findings
should be high priority because they affect the package's recommended flow.

The workflow RFC should not treat auditr as an implementation detail. It is
external evidence about whether the canonical workflow is understandable and
robust.

---

## 13. Open Questions

1. Should the first accepted synthesis bind Option C: docs-only convention now,
   scaffold helper later?
2. Should a new workflow vignette be created, or should getting-started and
   experiment-store carry the full canonical workflow?
3. Should the project layout recommend `artifacts/ledgr_store.duckdb` as the
   default store path, or leave the filename project-specific?
4. Should report templates be shipped as static Qmd files in docs/examples, or
   remain entirely user-owned?
5. Should split snapshot/run stores be documented as an advanced unsupported
   topology, or left out of public docs until first-class API support exists?
6. What is the minimum evidence needed before adding
   `ledgr_new_research_project()`?
7. Should `ledgr-examples` be a future companion repo, and what governance
   keeps it from becoming a strategy library?
8. Should production promotion records be explicitly carved out into a later
   RFC?
9. How should cross-project snapshot reuse be handled before split stores are
    first-class?
10. Should first-pass workflow docs standardize on Qmd, Rmd, or support both?
11. What backup guidance is strong enough for users without making ledgr
    responsible for storage operations it does not own?
12. How should the v0.1.8.7 parallel-dispatch design coordinate with the
    canonical single-store workflow?
13. Should snapshot lineage metadata (`family`, `extends`, `supersedes`,
    `lineage_note`) land as a small research API before split snapshot/run
    stores are first-class?
14. What production data-log contract should own append-only live feed capture,
    gap detection, backfill, corrections, and the later sealing of live history
    into immutable research snapshots?
15. Should external point-in-time regressors become their own RFC before ML
    strategy workflows, since ML and factor research both depend on vintage
    correctness?

---

## 14. Suggested Synthesis Shape

If accepted, the synthesis should likely bind:

- one project-local experiment store as the v0.1.x canonical topology;
- logical distinction between sealed snapshots and derived execution artifacts
  inside that store;
- raw data outside ledgr, sealed normalized snapshots inside ledgr;
- new historical data, vendor corrections, and universe changes create new
  sealed snapshots rather than mutating existing snapshots;
- live production ticks and bars belong to append-only live data logs, not to
  sealed backtest snapshots;
- artifact backup is user/project responsibility; `artifacts/` should be
  git-ignored but not treated as disposable;
- docs-first workflow convention before scaffold API;
- no `ledgr_new_research_project()` in v0.1.8.4;
- split stores as future advanced topology requiring first-class run-store API
  support;
- parallel dispatch must define a coordinated write strategy and must not
  imply unsynchronized concurrent writes to one DuckDB store;
- research promotion notes use existing `ledgr_promote(..., note = ...)` and
  promotion context;
- production promotion records as a separate RFC;
- snapshot lineage metadata as a future lightweight API, not a v0.1.8.4
  implementation requirement;
- live data logs, gap policy, correction policy, and seal-from-live-history
  workflows as future production/paper-trading topology;
- external point-in-time regressor snapshots as a separate data RFC, with
  DuckDB as the default near-term backbone where scale permits;
- pre-CRAN artifact compatibility is best-effort only; incompatible stores
  should fail loudly rather than silently migrate;
- pins/vetiver ML artifact integration as horizon scope only;
- companion example repo as future education/product work, not a core strategy
  library;
- auditr alignment with the canonical workflow.
