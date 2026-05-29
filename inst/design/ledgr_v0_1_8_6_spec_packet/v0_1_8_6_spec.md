# ledgr v0.1.8.6 Spec

**Status:** Draft implementation spec for v0.1.8.6.
**Target Branch:** `v0.1.8.6`.
**Scope:** Feature-projection materialization, structured benchmark suite with a
small QuantConnect-comparable subset, storage/provenance decision work,
and research-loop helper follow-up from v0.1.8.5.
**Auditr Input:** Deferred. The next auditr report will run after prompt fixes
in the auditr repository; no auditr bugfix intake is scoped for v0.1.8.6.
**Non-scope for this pass:** A second execution engine, parallel dispatch,
target risk, walk-forward evaluation, public cost/liquidity APIs, OMS work,
live data logs, point-in-time regressors, public ML/training-frame APIs,
project scaffolding, companion-repository implementation, broad collapse
adoption, public hosted performance dashboards, hard CI performance-regression
thresholds, auditr-report bugfixes, and `ctx$window()` unless target-risk
planning explicitly needs it.

---

## 0. Source Inputs

Authoritative inputs:

- `inst/design/contracts.md`
- `inst/design/ledgr_roadmap.md`
- `inst/design/README.md`
- `inst/design/rfc_cycle.md`
- `inst/design/rfc/rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md`
- `inst/design/rfc/rfc_feature_projection_shape_and_lookback_v0_1_8_x_final_review.md`
- `inst/design/ledgr_v0_1_8_5_spec_packet/v0_1_8_5_spec.md`

Predecessor design decisions:

- `inst/design/rfc/rfc_pulse_context_data_model_consolidation_v0_1_8_3_synthesis.md`
- `inst/design/rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`
- `inst/design/rfc/rfc_research_workflow_artifact_topology_v0_1_8_x_synthesis.md`
- `inst/design/rfc/rfc_collapse_primitive_internals_v0_1_9_synthesis.md`

Measurement and spike inputs:

- `dev/spikes/spike-feature-payload-dps.R`
- `dev/spikes/profile-loop.R`
- `dev/bench/fetch_lean_reference.R` and the generated `dev/bench/lean_reference.csv`
  - the scraped LEAN benchmark throughput baseline used by Section 6.
- QuantConnect performance page and linked benchmark documentation/sources as a
  structural reference for named benchmark scenarios and machine-readable
  benchmark outputs:
  - `https://www.quantconnect.com/performance`
  - `https://www.quantconnect.com/docs/v2/cloud-platform/backtesting/engine-performance`
- the 2026-05-28 horizon entries for feature projection materialization,
  persistent DB replay, snapshot administration, and research-loop ergonomics.

Pending inputs:

- Snapshot administration / ETL provenance RFC output, if that workstream is
  promoted into implementation tickets during this packet.

This spec promotes only the work below. Horizon entries remain non-binding
unless explicitly named here or in follow-up tickets.

---

## 1. Thesis

v0.1.8.6 is a measured setup-performance and storage-boundary release.

v0.1.8.3 made the fold loop materially faster by moving pulse-context view
construction out of the hot path. v0.1.8.5 made the research workflow
teachable. The current v0.1.8.6 question is narrower: before adding storage
machinery, remove the redundant setup work the accepted feature-projection RFC
has already isolated.

The order is binding:

```text
5.0 feature cache-key dedup
  -> 5.1 schema-only feature_table by default
  -> current-source remeasurement
  -> structured benchmark suite
  -> two-mode instrument x feature width sweep
  -> storage/provenance decision work
```

The package should not implement a DuckDB-backed projection, typed persistent
event columns, collapse-backed reshape path, or lookback API merely because
they are plausible. They enter only through the gates below.

---

## 2. Release Goals

v0.1.8.6 has twelve release goals:

1. Deduplicate feature cache-key construction by hoisting repeated
   feature-definition fingerprints and engine-version values out of the
   per-(instrument, feature) loop without changing any cache-key values.
2. Stop building the full-panel long `feature_table` by default while preserving
   a schema-only `ctx$feature_table` field and explicit internal full-long
   opt-in for tests/debugging/compatibility.
3. Fix the non-fast pulse-context helper path so it does not rebuild long rows
   when the default schema-only feature table is used.
4. Make the remaining eager `features_wide` data.frame manifestation cheaper
   without changing the `ctx$features_wide` contract or adding a collapse
   dependency.
5. Profile the remaining cold `t_pre` and broad residual costs after the
   materialization fixes so follow-up optimization starts from attributed code
   paths rather than an unexplained timing remainder.
6. Drop the intermediate wide-view matrix allocation after profiling as a
   narrow cleanup if the direct-slice implementation remains cheap and
   contract-preserving.
7. Close the performance investigation with a measurement/docs-only attribution
   table that names and owns every remaining large wall-clock bucket before
   v0.1.8.7 design work starts.
8. Reproduce the current-source performance baseline after each materialization
   change and add a two-mode instrument x feature width sweep before making
   throughput invariance or storage-need claims.
9. Create a structured benchmark suite with stable named scenarios,
   current-source guards, warmup/repeat behavior, machine-readable outputs, and
   a small QuantConnect-comparable subset so future performance work is
   comparable across commits, versions, and at least a few external benchmark
   shapes.
10. Decide the DuckDB feature-storage path only after the setup fixes are
   measured, so the spike evaluates the remaining bottleneck rather than stale
   materialization costs.
11. Carry forward the v0.1.8.5 research-loop helper gaps and snapshot
   administration / ETL provenance planning if their RFC/spec inputs land in
   time for ticket cut.
12. Accept typed persistent event columns only if storage/schema work is
   explicitly accepted for this packet; otherwise keep Direction 5.6 deferred.

The release succeeds when setup work is cheaper, memory pressure from unused
long materialization is reduced, and the next storage decision is based on
post-fix measurements rather than the stale v0.1.8.0 profile.

Workstream labels in this spec map to the roadmap as follows:

- roadmap Workstream 0, Feature Projection Materialization: Sections 3 and 4;
- roadmap Workstream B, DuckDB Feature Storage Spike: Section 5;
- structured benchmark suite: Section 6, added by this spec from the
  QuantConnect comparison and required by the storage decision gate;
- roadmap Workstream A, Snapshot Administration And ETL Provenance: Section 7;
- roadmap Workstream C, Research-Loop Ergonomics Helpers: Section 7.

---

## 3. Workstream 0a: Feature Cache-Key Deduplication

Accepted source:

- Direction 5.0 in
  `rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md`.

Implementation direction:

- Keep `ledgr_feature_cache_key()` as the canonical key constructor for parity
  and public/internal contract clarity.
- In the precompute path, compute each resolved concrete feature definition's
  `ledgr_feature_def_fingerprint(def)` once per execution/precompute scope.
- Compute `ledgr_feature_engine_version()` once per execution/precompute scope.
- Reuse those values when constructing per-instrument cache keys.
- Do not key the memoization by R object address or mutable environment
  identity. The cache lives inside the precompute/run assembly scope, not in a
  global registry and not in the persisted feature cache.

Acceptance gates:

- Cache keys are byte-identical before and after dedup for representative
  scalar, multi-output, parameterized, and explicit-fingerprint feature
  definitions.
- Existing fingerprint-stability tests remain green.
- A targeted measurement shows the flat `t_pre` cost shrinks materially on the
  spike workload.
- No public API, cache schema, feature identity, or persisted artifact contract
  changes.

---

## 4. Workstream 0b: Feature Table Materialization Policy

Accepted source:

- Direction 5.1 in
  `rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md`.

Binding policy:

- Default runtime view construction builds:
  - `features_wide`;
  - a zero-row, schema-preserving `feature_table`.
- Full-panel long `feature_table` is built only through explicit internal
  opt-in for tests, debugging, and compatibility paths that truly need it.
- Feature inspection builds only the current pulse's long shape on demand.
- `ctx$feature_table` remains a plain data.frame field. This cycle does not
  replace it with an active binding or function-valued data field.
- `ctx$features_wide` remains a plain data.frame field in this cycle, but its
  data.frame manifestation should use primitive list/matrix internals and cheap
  boundary stamping where this preserves byte-equivalent behavior.

Rejected mechanisms for v0.1.8.6:

- inferring strategy use of `ctx$feature_table` from source code;
- adding an experiment-level public flag;
- adding a per-strategy capability hint;
- deprecating `ctx$feature_table` in the same change.

Implementation hazards:

- The fast fold path already tolerates absent long rows by falling back to a
  schema-shaped empty frame.
- The non-fast helper path must be changed so it does not rebuild long rows
  from the projection when the default schema-only feature table is present.

Acceptance gates:

- Full-long-enabled and schema-only-default runs produce identical event
  streams on reference workloads.
- Existing strategy-facing `features_wide`, `feature()`, and `features()`
  behavior remains unchanged.
- Tests that truly require long rows opt into full long or move to
  `features_wide`.
- A measurement shows the pulse-view build gap shrinks on pulse-heavy
  workloads.
- Any wide-view manifestation optimization preserves the existing
  `ctx$features_wide` data.frame contract and event-stream parity, and does not
  add a collapse dependency.
- No public `feature_table` deprecation warning ships in this release.

---

## 5. Workstream B: Measurement And Storage Decision

The DuckDB-backed projection/storage question remains a measurement-and-decision
workstream. It is not automatically an implementation commitment.

Required measurement sequence:

1. Re-run the feature-payload spike on current source after Workstream 0a
   (Section 3).
2. Re-run it again after Workstream 0b (Section 4).
3. Add the structured benchmark suite from Section 6.
4. Add an instrument x feature width sweep in two modes:
   - **read/score mode:** strategy reads and scores features but produces no
     fills, isolating feature-access and projection scaling;
   - **turnover mode:** strategy generates representative fills, exposing
     event, fill, and reconstruction scaling.
   The pulse-only sweep justifies the setup-bottleneck ordering, but it does
   not prove loop throughput is width-invariant.
5. Only then run the DuckDB-backed projection/storage comparison if the
   remaining bottleneck still points at storage, hydration, memory ceiling, or
   worker transport.

Decision outcomes:

- **Implement:** only if a block-hydrated DuckDB path materially improves the
  remaining bottleneck without weakening determinism, feature identity, or
  portability.
- **Defer:** if DuckDB storage is plausible but not yet load-bearing after
  5.0/5.1.
- **Reject for now:** if the post-fix bottleneck is not storage or hydration.

Typed persistent event columns:

- Direction 5.6 is accepted as the complete persistent replay fix, but it is
  conditional in v0.1.8.6.
- If storage/schema work is explicitly accepted, add nullable typed persistent
  event columns through a tested pre-CRAN migration path.
- If storage/schema work is not accepted, do not ship a DuckDB SQL
  `json_extract` replay patch as a partial substitute unless a separate bugfix
  requires it.

Acceptance gates:

- Measurements use `pkgload::load_all(".")` or another current-source guard,
  not an installed stale package.
- The release notes and docs do not claim LEAN equivalence/parity or
  width-invariant loop throughput; a caveated side-by-side comparison against
  `dev/bench/lean_reference.csv` is permitted and encouraged.
- Any storage/schema work includes reconstruction parity against existing
  `meta_json` replay paths.

---

## 6. Workstream S: Structured Benchmark Suite

This workstream turns the ad hoc feature-payload spike into a small, repeatable
benchmark suite. The goal is not a public performance page yet. The goal is a
local, source-guarded suite that can answer "what got faster or slower, and
which subsystem moved?" without repeating the stale-installed-package trap.

Structural reference and captured baseline:

- QuantConnect publishes a stable set of named benchmark algorithms and tracks
  data-points/sec over time. ledgr copies the structure, not the contents.
- The LEAN throughput numbers are captured into `dev/bench/lean_reference.csv`
  by `dev/bench/fetch_lean_reference.R`, which scrapes the inlined Highcharts
  series from the QC performance page and joins each benchmark to its source
  link and nearest ledgr scenario. Re-run the scraper to refresh; it fails
  loudly if QC stops inlining the series rather than returning stale numbers.
- v0.1.8.6 runs a small comparability subset that maps ledgr scenarios to the
  specific named LEAN benchmarks below and reports both sides. This is an
  honest, caveated **side-by-side comparison, not an equivalence or speed-ranking
  claim**: ledgr is interpreted R and event-sourced, while LEAN is a compiled C#
  engine (its Python column is a compiled engine with an interpreted Python
  callback) with different datafeed and brokerage abstractions. ledgr is
  expected to trail; the value is tracking the gap honestly over time.

Required benchmark properties:

- stable named scenarios;
- synthetic or package-owned data only;
- current-source guard, preferably via `pkgload::load_all(".")` or an explicit
  package-version/source check;
- warmup/repeat behavior, with the first run skipped or clearly marked;
- machine-readable output, such as JSON or CSV, plus an optional compact
  markdown summary;
- environment metadata: git SHA if available, branch, package version, R
  version, platform, timestamp, and scenario parameters;
- phase metrics, not just one DPS headline.

Initial scenario set:

| Scenario | Purpose |
| --- | --- |
| `baseline_single_run` | canonical tiny end-to-end `ledgr_run()` |
| `pulse_loop_empty` | fold loop with pulses but no feature or trade pressure |
| `wide_panel_no_features` | dense multi-instrument bar/pulse scaling |
| `feature_read_score` | many instruments x features, strategy scores but does not trade |
| `feature_turnover` | same width, but generates representative fills/events |
| `indicator_payload` | many registered indicators/features and cache/materialization stress |
| `sweep_memory_summary` | in-memory sweep summary/reconstruction path |
| `persistent_replay` | persistent write/read-back and `meta_json` replay cost |

QC-comparable subset:

| ledgr Scenario | QC Shape It Roughly Mirrors | Comparability Rule |
| --- | --- | --- |
| `baseline_single_run` | basic template benchmark | report full wall time and bars/sec for a minimal end-to-end run |
| `pulse_loop_empty` | one-equity empty `OnData` benchmark | no features, no trades, one instrument, dense pulses |
| `wide_panel_no_features` | many-equity empty `OnData` benchmark | many instruments, no features, no trades, same synthetic cadence |
| `indicator_payload` | indicator ribbon benchmark | many registered indicator/features over one or more instruments |

`feature_read_score` is **not** in the comparable subset: it is a ledgr-only
scenario (ledgr's cross-sectional feature width has no clean published-LEAN
analogue - LEAN's read-heavy benchmarks are universe-selection, which ledgr has
no surface for). It is still measured in the suite; it is just not part of the
side-by-side.

LEAN baseline throughput (security-bars/sec; median of 2026 CI runs; full set
and source links in `dev/bench/lean_reference.csv`):

| LEAN benchmark | ledgr scenario | C# | Python | comparable |
| --- | --- | ---: | ---: | --- |
| Basic Template (1 sym, buy-and-hold) | `baseline_single_run` | ~289k | ~242k | yes |
| Equity 1 Symbol, second (empty loop) | `pulse_loop_empty` | ~450k | ~366k | yes |
| Equity 400 Symbols, minute (empty loop) | `wide_panel_no_features` | ~974k | ~959k | yes |
| Indicator ribbon (50 chained, 1 sym) | `indicator_payload` | ~182k | ~76k | partial |

A "data point" here is one security-bar. The comparable ledgr metric is
`security_bars_sec = n_inst * n_pulses / t_wall` (defined for every scenario,
with or without features) - NOT the feature-payload spike's
`feature_cells_sec = n_inst * n_pulses * n_feat / t_wall`, which is `n_feat`
times larger. The two must never be conflated; for the empty scenarios `n_feat`
is zero and only `security_bars_sec` is defined. The 400-symbol empty loop is
LEAN's fastest because batching amortizes per-bar overhead - the same
dense-panel shape ledgr uses. ledgr is expected to trail by
roughly an order of magnitude or more; the Python column is the nearest
interpreted-language reference (still a compiled engine underneath). The job is
to report ledgr's measured number next to these and track the gap honestly, not
to claim equivalence.

For this subset, the benchmark output must include both ledgr-native phase
metrics and QC-style headline units:

- bars/sec;
- data-points/sec, where a data point is explicitly defined for each scenario;
- wall-clock runtime;
- scenario dimensions: instruments, pulses, features/indicators, and event
  count.

The output must state which QC shape is being approximated and which parts are
not comparable. For example, ledgr does not currently have QC-style universe
selection, scheduled events, brokerage simulation, or `History()` request
benchmarks, so those are not part of the v0.1.8.6 comparison.

Metrics:

- `t_pre`;
- `t_viewbuild` or `gap_viewbuild`;
- `t_loop`;
- `t_wall`;
- persistent write/read-back time where applicable;
- replay/reconstruction time where applicable;
- peak R memory where measurable;
- events/sec for turnover-heavy scenarios;
- bars/sec and data-points/sec for comparison;
- warnings/failures count.

The suite may report a headline DPS value, but it must not make that the only
result. The v0.1.8.0 stale-build incident showed that one headline number can
hide whether the bottleneck is setup, loop execution, event writing, or replay.

Non-scope:

- no public hosted benchmark page;
- no CI failure threshold from benchmark drift in this cycle;
- no LEAN equivalence or speed-ranking claim (an honest, caveated side-by-side
  comparison against `dev/bench/lean_reference.csv` IS in scope);
- no scheduler, universe-selection, or history/window benchmark until ledgr has
  the corresponding public surfaces.

Acceptance gates:

- the suite can run the initial named scenarios from current source;
- results are machine-readable and include scenario parameters and environment
  metadata;
- read/score and turnover scenarios are both present for the instrument x
  feature width sweep;
- the benchmark output separates feature-access scaling from fill/event/replay
  scaling;
- release documentation can cite benchmark results without implying public
  hosted performance claims;
- the QC-comparable subset emits the QC-style headline units above, reports each
  comparable (yes/partial) subset scenario's number next to the matching
  `dev/bench/lean_reference.csv` value, and includes explicit comparability
  notes. Scenarios with no LEAN analogue (e.g. `feature_read_score`) are
  measured but exempt from the side-by-side.

---

## 7. Workstreams A And C: Snapshot Administration And Research-Loop Helpers

This workstream carries forward planned v0.1.8.6 roadmap work, but its
implementation ticket cut depends on the relevant RFC/spec input landing before
the release gate.

Snapshot administration / ETL provenance intent:

- record user-supplied ETL provenance, notes, labels, and authorship at
  snapshot creation without changing `snapshot_hash`;
- expose listing/filtering surfaces that help users navigate project stores
  with multiple snapshots;
- keep engine-computed metadata, user-supplied descriptive metadata, and
  lifecycle state separate.

Research-loop helper intent:

- add a sweep-review helper that ranks completed candidates by an explicit,
  visible rule and separates issue rows;
- add a promotion-recovery summary helper that summarizes the stored
  "what caused this result?" evidence without hiding recovery limitations;
- revise v0.1.8.5 workflow docs if these helpers remove the need for lower-level
  "API gap" callouts.

Constraints:

- helpers summarize existing APIs; they do not replace `ledgr_results()`,
  `ledgr_run_info()`, `ledgr_extract_strategy()`, `ledgr_candidate()`, or
  promotion-context fields;
- no automatic winner-picking helper;
- no statistical validation surface;
- no walk-forward or out-of-sample evaluation helper;
- no production deployment approval model.

If the RFC input does not land in time, keep this workstream as planned and do
not block the mandatory 5.0/5.1 materialization fixes on it.

---

## 8. Auditr Report Deferral

No auditr bugfix intake is scoped for v0.1.8.6.

The maintainer decision is to fix overly explicit prompts in the auditr
repository first. The next auditr report will run in the next version, after
those prompt fixes, so this packet does not reserve release capacity for auditr
findings and does not route current false positives into ledgr tickets.

If an independently discovered release-blocking bug appears during v0.1.8.6,
it can still be handled as a normal release-blocking defect. That is separate
from auditr report intake.

---

## 9. Proposed Ticket Cut

Ticket identifiers are assigned in `v0_1_8_6_tickets.md` and `tickets.yml`.
The intended ticket areas are below. `batch_plan.md` groups these ticket areas
into review batches for execution and review.

1. **Spec and planning alignment.** Keep README, roadmap, AGENTS, and the
   active packet in sync with v0.1.8.6 scope.
2. **Feature cache-key dedup.** Hoist fingerprint and engine-version work,
   add cache-key parity fixtures, and remeasure.
3. **Schema-only feature table default.** Add the construction-time view policy,
   fix non-fast helper rebuild behavior, update tests, and remeasure.
4. **Structured benchmark suite.** Add the named benchmark runner, current-source
   guard, warmup/repeat behavior, machine-readable outputs, and initial
   scenarios.
5. **Width sweep and storage decision.** Add two-mode instrument x feature sweep
   coverage through the benchmark suite and record the post-5.0/5.1 decision.
6. **Conditional storage/schema work.** Implement typed persistent event columns
   only if accepted after the storage decision gate.
7. **Fast wide-view manifestation.** Preserve `ctx$features_wide` as a
   data.frame while building it from primitive columns with cheap boundary
   stamping.
8. **Cold setup/residual profiling diagnostic.** Attribute the remaining
   `t_pre` and residual costs after the manifestation work without optimizing
   them in the same ticket.
9. **Drop intermediate wide-matrix allocation.** Remove the all-pulse wide
   matrix allocation from default pulse-view construction as a narrow cleanup
   while preserving `ctx$features_wide`.
10. **Performance attribution closeout.** Use differential toggles and Rprof
   attribution to name and own every remaining large wall-clock bucket without
   adding phase hooks or optimizing in the closeout gate.
11. **Snapshot/provenance and helper tickets.** Cut only after the relevant RFC
   or spec input is accepted.
12. **Release gates.** Update NEWS, docs, tests, package checks, and
   retrospective records.

---

## 10. Acceptance Criteria

The v0.1.8.6 release may close only when:

- feature cache keys are parity-checked before/after dedup;
- fingerprint-stability pins pass;
- schema-only default and full-long opt-in produce identical event streams on
  reference workloads;
- LDG-2403 accounting parity remains green for schema-only and full-long paths;
- the non-fast context path does not rebuild long rows by default;
- feature-inspection and any tests needing long rows use the explicit supported
  path;
- wide-view data.frame manifestation remains contract-compatible and is covered
  by event-stream parity tests if accepted;
- cold setup/residual profiling is recorded after the accepted materialization
  work, or explicitly deferred with maintainer rationale, and does not ship
  optimization or public-surface changes under the profiling ticket;
- the intermediate wide-matrix allocation follow-up is accepted with parity
  evidence or explicitly deferred with maintainer rationale;
- the performance attribution closeout names and owns every remaining bucket
  above `10%` wall time or `1s`, separates expected interpreter/GC/DBI overhead
  from genuinely unexplained-and-nameable time, and records a maintainer
  disposition for any unresolved attribution gap;
- current-source remeasurement is recorded after 5.0 and after 5.1;
- the structured benchmark suite runs from current source, writes
  machine-readable results, records environment metadata, and reports phase
  metrics instead of DPS alone;
- at least the QC-comparable subset named in Section 6 runs and emits bars/sec,
  data-points/sec, wall-clock runtime, dimensions, and comparability notes;
- a two-mode instrument x feature width sweep is recorded before any
  width-invariance or storage-need claim, including read/score mode and
  turnover mode;
- any accepted storage/schema migration has reconstruction parity against the
  legacy `meta_json` path;
- any snapshot/provenance helper work preserves `snapshot_hash` semantics;
- any research-loop helper exposes ranking/recovery limits rather than hiding
  them;
- no auditr-report findings are required for release closeout; the auditr
  report is deferred to the next version after prompt fixes in the auditr repo;
- targeted tests, full tests, and release package checks pass according to
  `inst/design/release_ci_playbook.md`;
- `DESCRIPTION`, `NEWS.md`, README, pkgdown/docs, tickets, and the cycle
  retrospective are updated at release closeout.

---

## 11. Explicit Deferrals

Deferred unless a later accepted packet scopes them:

- parallel sweep dispatch;
- target risk and net affordability;
- `ctx$window()` unless target-risk planning explicitly needs covariance
  windows;
- full-panel long export/training APIs;
- public ML/PIT regressor APIs;
- public cost/liquidity APIs;
- OMS and paper/live trading;
- broad collapse dependency adoption;
- public hosted benchmark dashboard and hard CI performance-regression gates;
- project scaffold generation and companion-repository implementation;
- split-store runtime and production deployment promotion records;
- live data logs and external provider integrations.

---

## 12. Release Notes Draft

```markdown
# ledgr 0.1.8.6

## Setup performance and feature projection

- Deduplicate feature cache-key work during feature precompute while preserving
  fingerprint and cache-key values.
- Avoid building the full-panel long `feature_table` by default; keep a
  schema-only pulse-context field and explicit internal opt-in for long rows.
- Build existing `features_wide` data.frames more cheaply from primitive
  projection columns while preserving the current strategy-facing contract.
- Remove the intermediate wide-view matrix allocation as a narrow cleanup if
  the direct-slice implementation remains cheap and contract-preserving.
- Record post-fix performance measurements and a width sweep to guide the
  storage/projection decision.

## Benchmarks

- Add a structured local benchmark suite with stable named scenarios,
  current-source guards, repeatable outputs, and phase-level metrics.
- Include a small LEAN-comparable subset, reported side by side with
  QuantConnect's published benchmark throughput and explicit comparability
  caveats. This is an honest comparison, not a parity claim.
- Record a diagnostic attribution of the remaining cold setup and residual
  runtime costs to guide the next optimization decision.
- Close with a measurement/docs-only attribution table that names and owns the
  remaining large wall-clock gaps before v0.1.8.7 design work starts.

## Storage and provenance

- Decide whether DuckDB-backed feature storage or typed persistent event
  columns are load-bearing after the setup fixes are measured.
- Continue snapshot administration, ETL provenance, and research-loop helper
  planning where accepted.

## Bug fixes

- No auditr-report bugfix intake is scoped for this release; the next report is
  deferred until the auditr prompt fixes land.
```

This draft is intentionally conservative. Do not claim storage implementation,
typed persistent columns, or helper APIs unless their tickets ship.
