# ledgr v0.1.8.3 Spec

**Status:** Ticket-cut baseline for v0.1.8.3 implementation.
**Target Branch:** `v0.1.8.3`
**Scope:** Empirically grounded single-core sweep optimization, plus routed
auditr feedback that identifies confirmed bugs, documentation gaps, or low-risk
message polish.
**Auditr Input:** Routed v0.1.8.2 auditr report in this packet:
`ledgr_triage_report.md`, `categorized_feedback.yml`, and
`cycle_retrospective.md`. Planning and performance-baseline work may proceed in
parallel with auditr fixes, but the release cannot close until accepted auditr
findings are fixed, deferred, or explicitly rejected.
**Non-scope for this pass:** Active parameterized feature aliases,
parameter-grid quality-of-life helpers, automatic candidate ranking or winner
selection, public parallel sweep dispatch, Rcpp/compiled kernels, lazy
`features_wide` API changes, target-risk layers, walk-forward validation,
public cost/liquidity chains, OMS work, paper/live adapters, external
reference-data adapters, and full sweep artifact persistence unless explicitly
promoted by maintainer amendment.

---

## 0. Source Inputs

Authoritative inputs:

- `inst/design/contracts.md`
- `inst/design/ledgr_roadmap.md`
- `inst/design/README.md`
- `inst/design/rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md`
- `inst/design/rfc/rfc_risk_free_rate_metric_context_v0_1_8_1_synthesis.md`

Supporting context:

- `inst/design/horizon.md`
- `inst/design/release_ci_playbook.md`
- `inst/design/architecture/ledgr_v0_1_8_sweep_architecture.md`
- `inst/design/architecture/ledgr_sweep_mode_ux.md`
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

The first v0.1.8.3 optimization target is the second bucket:

```text
typed memory events + single-pass sweep summary reconstruction
```

This target is first because it does not require a strategy-facing context API
change, has a clear parity surface, and directly follows from the existing
memory output-handler boundary.

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
| v0.1.8.3 | Empirically measured single-core sweep optimization: typed memory events and single-pass summary reconstruction, plus routed auditr fixes. |
| v0.1.8.4 | Active parameterized feature aliases for sweep authoring. |
| v0.1.8.5 | Parameter-grid quality-of-life helpers after active aliases stabilize. |
| v0.1.8.6 | Fast context B1/B2 before parallel dispatch, if v0.1.8.3 residual profiling confirms context churn remains dominant. |
| v0.1.8.7 | Parallel sweep dispatch after serial semantics, metrics, grid UX, and fast-context decision stabilize. |
| v0.1.9 | Target-risk chain. |
| v0.1.9.x | Walk-forward, selection integrity, compact sweep artifacts, and target-construction helper extensions. |
| v0.1.9.x / v0.2.0 | Public transaction-cost model API. |
| v0.2.x | Liquidity/capacity policy, point-in-time data, corporate actions/instrument master, benchmark context/active metrics, reference strategy templates, and OMS lineage. |

---

## 2. Release Goals

v0.1.8.3 has five primary goals:

1. Establish a reproducible performance protocol for sweep optimization.
2. Capture a v0.1.8.2 baseline measurement before changing the hot path.
3. Resolve and test persistent-path versus memory-path accounting parity for
   realized and unrealized PnL.
4. Implement typed memory events and single-pass sweep summary reconstruction
   without changing strategy-facing semantics.
5. Publish post-change measurements and a residual hot-path report.

It has one required intake gate:

6. Route v0.1.8.3 auditr findings into accepted fixes, documentation/message
   polish, explicit deferrals, or rejections before release gate.

The routed auditr findings add one required runtime fix:

7. Harden strategy preflight against constant-string and direct-function
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

Fast context:

- no activation of `use_fast_context` in v0.1.8.3 unless the maintainer
  explicitly amends the packet after typed memory events and single-pass
  summary reconstruction land;
- no B1/B2 context reuse or list-backed proxy work in the baseline scope.

Public context API changes:

- no lazy `ctx$features_wide`;
- no active bindings;
- no change from field to function for public context fields;
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

Risk, evaluation, and execution policy:

- no target-risk chain;
- no walk-forward, CSCV/PBO, or random-slice validation;
- no public transaction-cost model API;
- no OMS, paper/live adapters, or broker/exchange templates.

Storage and artifacts:

- no full sweep artifact save/load feature;
- no broad schema redesign beyond fields required by the scoped optimization;
- no backward-compatibility shims for pre-CRAN development artifacts unless the
  maintainer explicitly requests them, per the pre-CRAN compatibility policy in
  `inst/design/README.md`.

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

### Measurements

Capture, where practical:

- total elapsed sweep time;
- candidate fold time;
- post-candidate summary reconstruction time;
- metric computation time;
- allocations or garbage-collection pressure if the tooling is reliable;
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

- new public APIs unrelated to typed memory events or single-pass summary;
- ranking helpers and winner selection, unless separately scheduled in a future
  packet or parked in `horizon.md`;
- active aliases to v0.1.8.4 and parameter-grid helpers to v0.1.8.5;
- fast context to v0.1.8.6 if residual profiling confirms context churn
  remains dominant;
- parallel sweep to v0.1.8.7 or a later explicitly scoped packet;
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

6. **Typed memory events**
   - add typed memory event representation;
   - keep durable persistent `meta_json` serialization unchanged;
   - prove typed and durable representations are equivalent.

7. **Single-pass summary reconstruction**
   - compute sweep summary artifacts without redundant event replay;
   - thread `metric_kernel`;
   - preserve sweep result shape and promotion metadata.

8. **Post-change measurement and residual report**
   - rerun baseline workloads;
   - publish speedup and regression results;
   - document remaining inefficiency pockets and next optimization candidates.

9. **Release gate**
   - full local tests;
   - package build/check;
   - coverage gate if applicable;
   - README/design index/roadmap/NEWS verification;
   - CI merge/tag playbook.

Fast-context work should be listed as a stretch or future ticket only after the
post-change residual report proves it remains the right next bottleneck.

Tracks 5 and 6 should be separate tickets by default. This lets the parity gate
run twice: once after typed memory events land, proving the representation
change preserves accounting, and once after the single-pass summary helper
lands, proving the reconstruction change preserves accounting. If ticket cut
combines them for review efficiency, the combined ticket must still preserve
both internal verification checkpoints.

---

## 9. Required Verification

Runtime verification must include:

- targeted accounting parity tests;
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
5. Typed memory events and single-pass summary reconstruction either ship with
   parity and measured improvement, or are explicitly deferred with evidence.
6. Persistent and memory reconstruction parity is tested for realized and
   unrealized PnL.
7. `metric_kernel` remains the sole metric-assumption input for sweep summary
   computation.
8. Public sweep result shape, promotion context, warning behavior, and execution
   identity remain compatible with v0.1.8.2 contracts unless a ticket records an
   intentional pre-CRAN breaking change.
9. Accepted auditr docs/message findings are fixed, deferred, or assigned to a
   named future home.
10. The residual hot-path report names the remaining dominant inefficiency
   pockets and recommends the next optimization slice.
11. Full release gates pass locally and in CI.
