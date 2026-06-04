# ledgr v0.1.8.3 Spec

**Status:** Ticket-cut baseline for v0.1.8.3 implementation.
**Target Branch:** `v0.1.8.3`
**Scope:** Empirically grounded single-core sweep optimization, now expanded by
the accepted grid-level feature artifacts synthesis to cover the full R-level
fold/runtime optimization arc, plus routed auditr feedback that identifies
confirmed bugs, documentation gaps, or low-risk message polish.
**Auditr Input:** Routed v0.1.8.2 auditr report in this packet:
`ledgr_triage_report.md`, `categorized_feedback.yml`, and
`cycle_retrospective.md`. Planning and performance-baseline work may proceed in
parallel with auditr fixes, but the release cannot close until accepted auditr
findings are fixed, deferred, or explicitly rejected.
**Non-scope for this pass:** Active parameterized feature aliases, alias-map
storage/hash/provenance, parameter-grid quality-of-life helpers, automatic
candidate ranking or winner selection, public parallel sweep dispatch,
Rcpp/compiled kernels, DuckDB-backed precompute storage or indicator
computation, lazy `features_wide` API changes, target-risk layers,
walk-forward validation, public cost/liquidity chains, OMS work, paper/live
adapters, external reference-data adapters, and full sweep artifact persistence
unless explicitly promoted by maintainer amendment.

---

## 0. Source Inputs

Authoritative inputs:

- `inst/design/contracts.md`
- `inst/design/ledgr_roadmap.md`
- `inst/design/README.md`
- `inst/design/rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md`
- `inst/design/rfc/rfc_risk_free_rate_metric_context_v0_1_8_1_synthesis.md`
- `inst/design/rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`
- `inst/design/rfc/rfc_pulse_context_data_model_consolidation_v0_1_8_3_synthesis.md`

Supporting context:

- `inst/design/horizon.md`
- `inst/design/release_ci_playbook.md`
- `inst/design/manual/sweep.qmd`
- `inst/design/manual/sweep.qmd`
- `inst/design/audits/sweep_performance_measurement.md`
- `inst/design/audits/sweep_hot_path_profile.md`
- `dev/spikes/ledgr_sweep_performance/run_benchmark.R`
- `dev/spikes/ledgr_sweep_performance/profile_hot_path.R`
- `inst/design/ledgr_v0_1_8_2_spec_packet/v0_1_8_2_spec.md`
- `inst/design/ledgr_v0_1_8_2_spec_packet/v0_1_8_2_tickets.md`

Auditr intake:

- `inst/design/ledgr_v0_1_8_3_spec_packet/ledgr_triage_report.md`
- `inst/design/ledgr_v0_1_8_3_spec_packet/categorized_feedback.yml`
- `inst/design/ledgr_v0_1_8_3_spec_packet/cycle_retrospective.md`

This spec does not treat auditr rows as automatically true package defects.
Rows are evidence. Ticket cut must distinguish confirmed runtime bugs,
documentation gaps, expected user errors, low-risk message polish, and backlog
design requests.

---

## 1. Thesis

v0.1.8.3 is a performance release, not a new workflow release.

v0.1.8.0 introduced sequential sweep over the shared fold core. v0.1.8.1 and
v0.1.8.2 stabilized the surrounding authoring, metric, storage, and
documentation contracts. v0.1.8.3 can now optimize the sweep memory path without
changing public sweep semantics.

The accepted optimization synthesis identifies two measured hot spots:

```text
fold-core pulse-context churn                  about two thirds of measured sweep time
post-candidate event-derived reconstruction    about one third of measured sweep time
```

Those proportions come from LDG-2108B, measured before the v0.1.8.1 and
v0.1.8.2 changes landed. The v0.1.8.2 baseline may show different proportions.
That is expected, not a measurement error. The Section 4 protocol is the
current evidence gate for v0.1.8.3 claims.

LDG-2402 showed that the old LDG-2108B split is stale for v0.1.8.2. The
reference workload now samples `ledgr_execute_fold()` as the dominant share of
time. Per the accepted grid-level feature artifacts synthesis, v0.1.8.3 is
therefore amended to cover the full R-level fold/runtime optimization arc:

```text
runtime projection interface and R-memory backend
  -> shared ledgr_run()/ledgr_sweep() projection consumption
  -> fast context B1
  -> pulse context data model consolidation / prebuilt static pulse views
  -> post-LDG-2413 measurement and maintainer decision
  -> typed memory events and single-pass summary reconstruction if retained
```

LDG-2409 checkpoint measurement reordered the next optimization slice:
projection removed the old `ledgr_features_wide()` hot frame, but helper churn
still dominates the sampled reference workload. B1 therefore lands before typed
memory events unless a later measurement contradicts this finding.

The accepted pulse-context data model consolidation synthesis then rescopes the
old "fast context B2" ticket. LDG-2413 now targets prebuilt static pulse views:
`ctx$bars`, `ctx$feature_table`, and `ctx$features_wide` remain data-frame
fields, but are built outside the pulse hot loop where parity permits and then
plucked by `pulse_idx`. After LDG-2413, LDG-2414 measures the result and gives
the maintainer the evidence needed to decide whether LDG-2410 typed memory
events and LDG-2412 single-pass summary remain in v0.1.8.3 or move to v0.1.9.

The release still does not change public strategy-facing context semantics.
The projection is an internal interface with an R-memory list-of-matrices
backend in v0.1.8.3. A future DuckDB-backed projection backend and durable
feature artifact substrate are deferred to horizon.

The release must be empirically grounded. Every optimization claim needs a
before/after measurement, a reproducible script or fixture, and a residual
hot-path report that records which inefficiency pockets remain after the
release.

The release also keeps an auditr intake lane. If auditr finds confirmed bugs or
high-value documentation/message issues, those may be routed into v0.1.8.3 as
long as they do not expand the performance release into a new API milestone.

Roadmap placement:

| Release | Scope |
| --- | --- |
| v0.1.8.3 | Empirically measured single-core sweep optimization: runtime projection, shared fold projection consumption, fast context B1, pulse-context data model consolidation, measurement-gated typed memory events and single-pass summary, plus routed auditr fixes. |
| v0.1.8.4 | Active parameterized feature aliases for sweep authoring. |
| v0.1.8.5 | Parameter-grid quality-of-life helpers after active aliases stabilize. |
| v0.1.8.6 | DuckDB-backed precompute storage / out-of-core projection candidate if residual evidence shows memory scaling, repeated precompute, ML/export, or parallel-worker sharing is load-bearing. |
| v0.1.8.7 | Parallel sweep dispatch after serial semantics, metrics, grid UX, and R-level optimization stabilize. |
| v0.1.9 | Target-risk chain. |
| v0.1.9.x | Walk-forward, selection integrity, compact sweep artifacts, and target-construction helper extensions. |
| v0.1.9.x / v0.2.0 | Public transaction-cost model API. |
| v0.2.x | Liquidity/capacity policy, point-in-time data, corporate actions/instrument master, benchmark context/active metrics, reference strategy templates, and OMS lineage. |

---

## 2. Release Goals

v0.1.8.3 has eight primary goals:

1. Establish a reproducible performance protocol for sweep optimization.
2. Capture a v0.1.8.2 baseline measurement before changing the hot path.
3. Resolve and test persistent-path versus memory-path accounting parity for
   realized and unrealized PnL.
4. Implement an internal runtime projection interface with an R-memory
   list-of-matrices backend.
5. Route both `ledgr_run()` and `ledgr_sweep()` through the same projection
   consumption path in the shared fold.
6. Implement fast context B1 where projection parity is green and helper churn
   remains the measured bottleneck.
7. Implement pulse-context data model consolidation by prebuilding static
   pulse views where parity permits, without changing strategy-facing
   context semantics.
8. Publish post-LDG-2413 measurements and give the maintainer evidence to
   decide whether typed memory events and single-pass sweep summary
   reconstruction remain in v0.1.8.3 or defer to v0.1.9.
9. Implement typed memory events and single-pass sweep summary reconstruction
   if retained after the measurement decision.
10. Publish post-change measurements and a residual hot-path report.

It has one required intake gate:

11. Route v0.1.8.3 auditr findings into accepted fixes, documentation/message
   polish, explicit deferrals, or rejections before release gate.

The routed auditr findings add one required runtime fix:

12. Harden strategy preflight against constant-string and direct-function
   `do.call()` indirection to forbidden nondeterministic calls, and classify
   `attr(ctx, ...) <- ...` context mutation as unsupported strategy code.

---

## 3. Scope Boundary

### In Scope

Performance evidence:

- benchmark/profiling protocol for v0.1.8.3;
- baseline measurement against the v0.1.8.2 tag;
- post-change measurement on the v0.1.8.3 branch;
- residual hot-path analysis after scoped optimization lands;
- measurement scripts committed under `dev/spikes/`;
- summarized reports committed under `inst/design/spikes/`.

Accounting parity:

- explicit parity tests for persistent `ledgr_run()` artifacts versus sweep
  memory replay;
- equality or documented tolerance checks for fills, equity, realized PnL,
  unrealized PnL, standard metrics, warning behavior, candidate status, and
  metric-context-sensitive Sharpe computations;
- confirmation that FIFO lot-tracking remains the authoritative source for
  realized and unrealized PnL semantics.

Runtime projection:

- extend `ledgr_precompute_features()` as the single feature precompute path to
  emit an internal projection shape;
- first backend is R-memory list-of-matrices, keyed by concrete feature ID and
  shaped `[instrument_idx, pulse_idx]`;
- missing projection slots use `NA_real_` wherever the current accessor path
  returns `NA` or no value;
- bundle outputs flatten to ordinary concrete single-output feature IDs;
- preserve `feature_engine_version`, concrete fingerprints, `feature_set_hash`,
  and `config_hash`;
- make `ledgr_run()` the one-candidate projection case and `ledgr_sweep()` the
  grid-union case;
- design projection access as an internal interface so a later DuckDB-backed
  backend can be added without refactoring the fold.

Shared fold projection consumption:

- consume projection values through pre-resolved integer indices rather than
  per-pulse string matching, reshape, or data-frame construction;
- preserve public `ctx$feature()` and related helper semantics;
- preserve `ctx$features_wide` schema, column ordering, types, and `ts_utc`
  behavior;
- materialize `ctx$features_wide` as a fresh current-pulse view, not a reusable
  mutable row shell;
- prove projection-vs-current-accessor parity before fast-context activation.

Typed memory events:

- typed in-memory event representation for the memory output handler;
- durable persistent output remains serialized to stable `meta_json` rows;
- equivalence tests between typed memory events and durable ledger-event rows;
- no weakening of event ordering, event sequence, cost metadata, fill timing,
  final-bar behavior, or target validation.

Single-pass summary reconstruction:

- consume already-ordered memory events without redundant sorts;
- avoid repeated metadata parsing in the memory summary path;
- compute equity, fills, trades, and standard metrics through one coherent
  summary path where practical;
- accept `metric_kernel` as the metric assumption input;
- preserve the public `ledgr_sweep_results` shape and promotion context.

Fast context:

- activate B1 after projection parity is green: initialize lookup environments
  and helper closures once per candidate and mutate pulse-specific values;
- no public strategy-facing context API change.

Pulse-context data model consolidation:

- rescope the old B2 proxy ticket to prebuilt static pulse views;
- run and record the `ctx$feature_table` usage audit before implementation;
- prebuild `ctx$bars` at the appropriate setup point for each entry path:
  run setup for `ledgr_run()`, sweep setup for `ledgr_sweep()`;
- prebuild candidate-specific `ctx$features_wide` and `ctx$feature_table`
  views from the runtime projection restricted to candidate `feature_ids`;
- preserve `ctx$bars`, `ctx$feature_table`, and `ctx$features_wide` as
  data-frame fields with the current schemas, column ordering, types,
  `ts_utc`, and missing-value semantics;
- remove `run_feature_matrix` from the fold execution contract and remove
  the legacy `is.null(runtime_projection)` branch from `ledgr_execute_fold`;
- allow `run_feature_matrix` to remain as a setup-only intermediate in
  `ledgr_run_fold()` if that is simpler than direct projection construction;
- add state-leak tests for in-run captured views, in-strategy mutation, and
  cross-candidate isolation;
- record peak memory and wall-clock impact in LDG-2414.

Auditr intake:

- confirmed runtime bugs;
- low-risk documentation corrections;
- low-risk message polish that preserves error classes;
- contract clarification when the existing behavior is correct but confusing;
- explicit parking of design/API requests in `horizon.md` or a future RFC.

Planning cleanup:

- move design context from v0.1.8.2 release closeout to v0.1.8.3 planning in
  `inst/design/README.md`, `inst/design/ledgr_roadmap.md`, and `AGENTS.md`;
- create v0.1.8.3 tickets only after the auditr and performance-protocol intake
  points are clear enough to route.

### Out Of Scope

Public context API changes:

- no lazy `ctx$features_wide` via active bindings. The v0.1.8.3 path is fresh
  current-pulse data-frame fields built outside the hot loop where parity
  permits; if context view construction or access remains hot after the
  release, the residual report should name it explicitly;
- no active bindings;
- no change from field to function for public context fields;
- no custom S3 view class for `ctx$bars`, `ctx$feature_table`, or
  `ctx$features_wide` in v0.1.8.3;
- no new strategy-facing feature lookup contract.

Future sweep UX:

- no active parameterized feature aliases;
- no parameter-grid helper release;
- no `ledgr_rank_candidates()` or automatic objective/winner selection;
- no public tuning DSL.

Parallel and compiled execution:

- no public parallel sweep dispatch;
- no worker API;
- no mori transport adoption;
- no Rcpp or Fortran kernel work.
- no required strategy bytecode-compilation work. `compiler::cmpfun()` may be
  evaluated as a residual-report candidate only after projection and fast
  context changes land.

Risk, evaluation, and execution policy:

- no target-risk chain;
- no walk-forward, CSCV/PBO, or random-slice validation;
- no public transaction-cost model API;
- no OMS, paper/live adapters, or broker/exchange templates.

Storage and artifacts:

- no full sweep artifact save/load feature;
- no broad schema redesign beyond fields required by the scoped optimization;
- no DuckDB-backed precompute storage, out-of-core projection, or long/wide
  research artifact tables;
- no DuckDB-implemented indicator computation;
- no backward-compatibility shims for pre-CRAN development artifacts unless the
  maintainer explicitly requests them, per the pre-CRAN compatibility policy in
  `inst/design/README.md`.

Persistent reconstruction:

- no persistent-path single-pass reconstruction or reconstruction-path
  unification in v0.1.8.3. The single-pass work targets the sweep memory path;
  persistent reconstruction can be revisited later if the residual report shows
  it is a material cost or correctness-maintenance burden.

---

## 4. Experimental Protocol

The first runtime-adjacent ticket in v0.1.8.3 should define and run the
experimental protocol before optimization starts.

Recommended files:

```text
inst/design/spikes/ledgr_v0_1_8_3_sweep_optimization/
  README.md
  baseline_report.md
  post_change_report.md
  residual_hot_path_report.md
  summary_report.md

dev/spikes/ledgr_v0_1_8_3_sweep_optimization/
  run_baseline.R
  run_post_change.R
  profile_hot_path.R
  summarize_results.R
```

The exact script names may change during ticket cut, but the split should
remain:

- `dev/spikes/` contains runnable measurement/profiling scripts;
- `inst/design/spikes/` contains reviewed summaries that explain the evidence.

### Baseline And Comparison Points

Baseline:

- tag: `v0.1.8.2`;
- record exact git SHA;
- record R version, package versions, OS, CPU, and memory where practical;
- run at least one warmup before measured iterations.

Comparison:

- v0.1.8.3 branch after scoped optimization;
- record exact git SHA;
- rerun the same workloads under the same protocol;
- compare median elapsed time, not a single run.

### Required Workloads

The protocol should include at least:

1. **Smoke workload**: small candidate grid for rapid parity and script health.
2. **Reference workload**: the existing 50-candidate EOD benchmark lineage from
   LDG-2108A/LDG-2108B.
3. **Wider workload**: more instruments, features, or candidates to expose
   event-summary and feature-payload behavior beyond the narrow reference case.
   The performance-protocol ticket should define the exact shape. It should
   consider the parallelism spike's wide-feature shape
   (`250 instruments x 2520 bars x 50 features`) or a justified scaled
   equivalent if local runtime or memory pressure makes the full shape
   impractical.
4. **Persistent comparison workload**: one or more committed `ledgr_run()` calls
   matched against sweep candidate replay for accounting parity.
5. **Metric-context workload**: non-default risk-free rate or calendar context
   proving the new summary path consumes `metric_kernel` rather than reverting
   to scalar or zero-risk-free assumptions.
6. **Single-candidate `ledgr_run()` workload**: a committed-run baseline that
   can detect material wall-clock regression from the new one-candidate
   projection builder path.

### Measurements

Capture, where practical:

- total elapsed sweep time;
- total elapsed `ledgr_run()` time for the single-candidate baseline;
- candidate fold time;
- post-candidate summary reconstruction time;
- metric computation time;
- allocations or garbage-collection pressure if the tooling is reliable;
- peak memory or object-size accounting for prebuilt pulse-view bundles;
- profile top functions before and after;
- number of candidates, pulses, instruments, features, fills, and events;
- correctness/parity results for each workload.

The release should not set an arbitrary speedup threshold such as "must be 2x
faster." The gate is evidence-based:

```text
measured improvement on the target sweep workload
+ no correctness drift
+ no material ledgr_run() regression
+ documented remaining hot spots
```

If the scoped optimization fails to improve the reference workload, the release
must either explain why the optimization is still valuable or defer the change.

The residual hot-path report is not only a release artifact. It is binding
evidence for the next optimization decision: if fast context remains the
dominant bottleneck, it supports the synthesis's expected next slice; if another
inefficiency dominates, the next packet should follow the measurement rather
than the earlier prediction.

---

## 5. Accounting And Event Semantics

The v0.1.8.3 optimization must not create a third accounting semantics path.

Current implementations differ in shape:

- persistent reconstruction can use vectorized cash/position machinery over
  stored events;
- memory reconstruction uses lot state while deriving equity and fills from the
  in-memory event stream.

The semantic rule for v0.1.8.3 is:

```text
realized_pnl and unrealized_pnl are FIFO lot-state accounting outputs
```

Vectorized reconstruction is a performance technique only. It must preserve
the lot-derived accounting outputs.

Before typed memory events or single-pass summary reconstruction land, tests
must establish expected equivalence for:

- opening-position events;
- buy fills;
- sell fills;
- partial closes;
- full closes;
- multi-instrument runs;
- no-fill final-bar warnings;
- zero-trade and open-position-at-end cases;
- non-default metric context;
- standard metric values, including at least total return, Sharpe ratio, max
  drawdown, trade counts, win rate, average trade, and time in market where
  those values are available.

Floating-point parity is at-tolerance, not necessarily byte-identical. The
accounting parity ticket must pick and document tolerance rules per output
class. Equity values may use an absolute tolerance scaled to account value; PnL
and return values may use relative or mixed tolerance where appropriate. The
test file must record the chosen tolerance and rationale so a later
optimization cannot silently widen it.

Event order is part of the contract. Memory events consumed by the single-pass
helper must already be in fold-produced event order. The helper may assert
ordering; it should not silently reorder in a way that masks upstream drift.

---

## 6. Metric Kernel Constraint

v0.1.8.2 introduced `metric_kernel` so metric assumptions are resolved once and
carried as a serialization-safe value object.

The v0.1.8.3 single-pass summary helper must accept `metric_kernel` directly.
It must not reintroduce:

- standalone `bars_per_year` plumbing in the sweep candidate path;
- hard-coded `risk_free_rate = 0`;
- cadence inference when an explicit metric context is already available;
- non-serializable context captures.

The summary path should preserve the v0.1.8.2 inspection surfaces:

- `ledgr_metric_context(ledgr_sweep_results)`;
- `metric_context_hash` attribute on sweep results;
- `metric_context_version` attribute on sweep results;
- summary disclosure of risk-free-rate and annualization assumptions.

Sweep candidates must always carry a resolved metric context from the
experiment or the default context. The single-pass helper does not need a silent
missing-context fallback. If a sweep candidate reaches the helper without a
valid `metric_kernel`, it should fail loudly with the existing metric-context
error discipline rather than infer cadence or risk-free assumptions.

---

## 7. Auditr Intake Rules

Auditr feedback is in scope for v0.1.8.3 after triage. The v0.1.8.2 auditr
report has been routed into one runtime fix, several documentation/message
polish tracks, explicit deferrals, and auditr-task drift outside this package.

Performance-protocol work may proceed in parallel with auditr fixes.
Exceptions: a confirmed bug that affects accounting parity, event semantics,
metric-kernel semantics, or the benchmark protocol pauses the affected
optimization ticket until it is routed.

### Routed v0.1.8.2 Auditr Decisions

Confirmed runtime bug:

- THEME-002 FB-001 from episode 016: `do.call("Sys.time", list())` is
  classified as Tier 1 and allowed to execute. v0.1.8.3 must fix this as a
  narrow preflight static-analysis extension following the LDG-2303 pattern.

Maintainer policy decisions:

- Constant-string and direct-function `do.call()` targets that resolve to
  forbidden nondeterministic functions are Tier 3.
- `attr(ctx, ...) <- ...` is unsupported context mutation and should be
  rejected by strategy preflight when it is statically visible.
- Captured mutable environments remain Tier 2 for now when statically
  resolved, but documentation must state that externally mutating captured
  environments is outside reproducible strategy style.
- `ledgr_snapshot_seal()` keeps its structured return with `$hash` and
  `$snapshot`; documentation and examples should show `$hash` extraction when a
  bare hash is needed.
- A public `ledgr_sweep_summary()` or flat-export helper is deferred. v0.1.8.3
  should document flat export patterns instead.
- Auditr task-brief drift is not ledgr runtime scope. Task expectations around
  bundle IDs, `stats::median()`, resolved globals, and stale target-version
  metadata should be corrected in the auditr repository separately.

Accepted docs/message polish:

- preflight forbidden-call table, Tier 3 class/no-force wording, ambient RNG
  distinction, and resolved-capture caveats;
- metric-context constructor fields, label/source display, hash provenance
  semantics, non-mutating override examples, and intraday annualization
  examples;
- sweep failed-candidate accessors, feature-fingerprint/provenance extraction,
  and flat export patterns for list-column results;
- installed example corrections for `ctx$equity`, parameter-grid syntax,
  `ledgr_snapshot_seal()` return shape, one-experiment-per-strategy wording,
  bundle ID expectations, and Tier 3 examples;
- Yahoo workflow, snapshot rerun lifecycle, timestamp comparisons, zero-trade
  diagnosis, fill-model required fields, and quantmod stderr guidance;
- low-risk condition message polish for CSV, timestamp, OHLC, bundle-collision,
  and indicator-registration errors when condition classes remain stable.

Accepted auditr categories for this packet:

- confirmed runtime bugs;
- contract violations;
- release-gate failures;
- documentation that teaches now-invalid behavior;
- error/warning messages that block ordinary user recovery;
- small docs/message improvements that fit the release without touching
  deferred roadmap surfaces.

Default deferrals:

- new public APIs unrelated to the projection, pulse-context data model
  consolidation, typed memory events, fast context, or single-pass summary;
- ranking helpers and winner selection, unless separately scheduled in a future
  packet or parked in `horizon.md`;
- active aliases to v0.1.8.4 and parameter-grid helpers to v0.1.8.5;
- parallel sweep to v0.1.8.7 or a later explicitly scoped packet;
- DuckDB-backed precompute storage, out-of-core projection, and durable
  feature artifacts to horizon until residual evidence and active-alias
  contracts justify promotion;
- risk-layer, OMS, walk-forward, or benchmark-provider work to their named
  roadmap cycles or `horizon.md` if no cycle owns the finding yet;
- large documentation rewrites not needed to explain the scoped release.

When the auditr report arrives, the packet should add:

- `ledgr_triage_report.md` or equivalent;
- `categorized_feedback.yml` if the report has enough items to warrant machine
  routing;
- explicit ticket assignments or horizon entries for every accepted finding.

Those artifacts are now present in this packet. Their accepted runtime and docs
work is represented by LDG-2404 through LDG-2407 in the ticket cut.

---

## 8. Ticket-Cut Guidance

The ticket cut uses this sequence:

1. **Planning context and packet setup**
   - update `README`, roadmap, and `AGENTS.md`;
   - create `v0_1_8_3_tickets.md` and `tickets.yml`;
   - confirm v0.1.8.2 is treated as an archival packet.

2. **Performance protocol and baseline**
   - write/run benchmark and profiling scripts;
   - capture the v0.1.8.2 baseline report;
   - identify measurement noise and acceptable comparison rules.

3. **Accounting parity gate**
   - add persistent-versus-memory parity tests;
   - explicitly cover realized/unrealized PnL and metric context.

4. **Strategy preflight indirection hardening**
   - fix constant-string and direct-function `do.call()` bypasses for
     forbidden nondeterministic targets;
   - reject statically visible `attr(ctx, ...) <- ...` mutation;
   - preserve Tier 3 condition classes and before-execution rejection.

5. **Auditr documentation and message polish**
   - split across preflight/docs, metric-context docs, sweep inspection/export
     docs, installed example corrections, and real-data troubleshooting;
   - preserve deferred API boundaries.

6. **Runtime projection interface and R-memory backend**
   - extend `ledgr_precompute_features()` to emit the projection;
   - pin projection shape, missingness, bundle flattening, and version policy;
   - keep DuckDB-backed storage deferred.

7. **Shared fold projection consumption**
   - make `ledgr_run()` and `ledgr_sweep()` consume the same projection
     interface;
   - add projection-vs-table, state-leak, schema, and shared-run/sweep parity
     gates;
   - use `ledgr_sweep_run_candidate()` as the convergence point for
     per-candidate fold setup where applicable.

8. **Fast context B1**
   - initialize lookup environments and helper closures once per candidate;
   - mutate pulse-specific values per pulse;
   - activate after projection parity is green, before typed memory events,
     because the LDG-2409 checkpoint profile leaves helper churn as the
     dominant remaining measured bottleneck.

9. **Pulse context data model consolidation**
   - run `ctx$feature_table` usage audit;
   - remove `run_feature_matrix` from the fold execution contract;
   - prebuild `ctx$bars`, `ctx$features_wide`, and `ctx$feature_table`
     static pulse views where parity permits;
   - preserve public context field schemas and data-frame field semantics;
   - add state-leak tests for captured views, strategy mutation, and
     cross-candidate isolation.

10. **Post-LDG-2413 measurement and maintainer decision**
   - rerun baseline workloads;
   - publish speedup and regression results;
   - record peak memory/object-size evidence for prebuilt views;
   - document remaining inefficiency pockets;
   - decide whether typed memory events and single-pass summary remain in
     v0.1.8.3 or defer to v0.1.9.

11. **Typed memory events, if retained**
   - add typed memory event representation;
   - keep durable persistent `meta_json` serialization unchanged;
   - prove typed and durable representations are equivalent.

12. **Single-pass summary reconstruction, if retained**
   - compute sweep summary artifacts without redundant event replay;
   - thread `metric_kernel`;
   - preserve sweep result shape and promotion metadata.

13. **Release gate**
   - full local tests;
   - package build/check;
   - coverage gate if applicable;
   - README/design index/roadmap/NEWS verification;
   - CI merge/tag playbook.

Projection work must precede fast context and typed memory events. The LDG-2409
checkpoint measurement reorders B1 before typed events because fold helper churn
remains the larger measured slice. The accepted pulse-context data model
consolidation synthesis then makes LDG-2413 the next R-level optimization and
measurement gate. Typed events and single-pass summary remain ticketed, but
their v0.1.8.3 disposition is a maintainer decision after the LDG-2413/LDG-2414
measurement evidence.

---

## 9. Required Verification

Runtime verification must include:

- targeted accounting parity tests;
- projection shape, missingness, bundle flattening, and fingerprint-stability
  tests;
- projection-vs-current-accessor parity tests;
- `ctx$features_wide` state-leak and schema-preservation tests;
- prebuilt static pulse-view parity, schema, state-leak, cross-candidate
  isolation, and peak-memory/object-size checks;
- shared `ledgr_run()` / `ledgr_sweep()` projection-consumption tests;
- single-candidate `ledgr_run()` wall-clock regression check;
- targeted strategy-preflight adversarial tests for `do.call()` indirection and
  `attr(ctx, ...) <- ...` rejection;
- sweep tests;
- promotion tests;
- metric-context sweep/comparison tests;
- run-store and backtest wrapper tests if storage or reconstruction paths move;
- `tests/testthat/test-fingerprint-stability.R` pins unchanged unless a
  maintainer-approved amendment explicitly re-blesses a deliberate hash change;
- full testthat before release gate;
- package build and check before release gate.

Expected test surfaces include:

- `tests/testthat/test-sweep-parity.R` or an equivalent new parity file;
- `tests/testthat/test-sweep.R`;
- `tests/testthat/test-metric-kernel.R`;
- `tests/testthat/test-backtest-wrapper.R`;
- `tests/testthat/test-metric-context-storage.R`;
- a typed-event-specific test file if the representation is substantial enough
  to warrant direct unit coverage;
- a single-pass-summary-specific test file if the helper is factored as a
  separately testable unit.
- a projection-specific test file if the runtime projection is factored as a
  separately testable unit;
- a fast-context-specific test file if B1 activation is substantial enough to
  warrant direct unit coverage;
- a pulse-context prebuilt-view-specific test file if LDG-2413 is factored as a
  separately testable unit.

Performance verification must include:

- v0.1.8.2 baseline report;
- v0.1.8.3 post-change report;
- residual hot-path report;
- script-level reproducibility notes.

Documentation/design verification must include:

- `inst/design/README.md` current-cycle status;
- `inst/design/ledgr_roadmap.md` current-cycle status;
- `AGENTS.md` current planning context;
- v0.1.8.3 `v0_1_8_3_tickets.md` and `tickets.yml` status synchronization;
- `NEWS.md` entry if runtime behavior or performance claims are user-visible;
- pkgdown rebuild only if auditr-routed documentation fixes or installed help
  changes make it relevant;
- no stale claim that v0.1.8.2 remains the active release gate.

---

## 10. Release Acceptance Criteria

v0.1.8.3 can close when:

1. Auditr findings are routed or explicitly deferred.
2. The constant-string/direct-function `do.call()` preflight bypass is fixed
   or explicitly reclassified by maintainer amendment.
3. `attr(ctx, ...) <- ...` has either a preflight rejection test or an explicit
   maintainer amendment explaining why it remains documented-only.
4. The v0.1.8.2 performance baseline is recorded.
5. Runtime projection ships through the shared `ledgr_run()` / `ledgr_sweep()`
   fold path with projection parity, missingness, bundle, state-leak, and
   `ctx$features_wide` schema tests.
6. The projection does not bump `feature_engine_version`, concrete
   fingerprints, `feature_set_hash`, or `config_hash`.
7. Fast context B1 and pulse-context data model consolidation ship with parity
   and measured evidence. Typed memory events and single-pass summary
   reconstruction either ship with parity and measured improvement, or are
   explicitly deferred with maintainer-approved evidence after LDG-2414.
8. Persistent and memory reconstruction parity is tested for realized and
   unrealized PnL.
9. `metric_kernel` remains the sole metric-assumption input for sweep summary
   computation.
10. Public sweep result shape, promotion context, warning behavior, and execution
   identity remain compatible with v0.1.8.2 contracts unless a ticket records an
   intentional pre-CRAN breaking change.
11. Accepted auditr docs/message findings are fixed, deferred, or assigned to a
   named future home.
12. The residual hot-path report names the remaining dominant inefficiency
   pockets and recommends the next optimization slice.
13. Full release gates pass locally and in CI.
