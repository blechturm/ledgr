# ledgr v0.1.8.2 Spec

**Status:** Ticket-cut baseline for v0.1.8.2 implementation.
**Target Branch:** `v0.1.8.2`
**Scope:** Metric context and risk-free-rate assumptions, auditr-routed
preflight alignment and documentation/message polish, plus indicator codebase
Phase 2 cleanup.
**Auditr Input:** The v0.1.8.2 auditr run and triage report have been added
to this packet. Confirmed bugs and high-value improvements from that triage are
routed below; final ticket cut still requires maintainer decisions for the open
policy items.
**Non-scope for this pass:** External reference-data adapters, beta metrics,
benchmark-relative metrics, public factor adapters, single-core sweep
optimization, parameter-grid QoL helpers, parallel sweep dispatch, target-risk
layers, execution-policy/OMS work, walk-forward validation, and random-slice
validation unless explicitly added by spec amendment.

---

## 0. Source Inputs

Authoritative inputs:

- `inst/design/contracts.md`
- `inst/design/ledgr_roadmap.md`
- `inst/design/README.md`
- `inst/design/rfc/rfc_risk_free_rate_metric_context_v0_1_8_1_synthesis.md`
- `inst/design/rfc/rfc_indicator_codebase_simplification_v0_1_8_x_synthesis.md`

Supporting context:

- `inst/design/horizon.md`
- `inst/design/release_ci_playbook.md`
- `inst/design/rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md`
- `inst/design/spikes/ledgr_tidyfinance_unit_probe/README.md`
- `inst/design/ledgr_v0_1_8_1_spec_packet/v0_1_8_1_spec.md`
- `inst/design/ledgr_v0_1_8_1_spec_packet/v0_1_8_1_tickets.md`

Post-ticket-cut maintenance input:

- final review of implementation tickets after any scope amendment.

This spec does not treat auditr rows as automatically true package defects.
Rows are evidence. Ticket cut must still distinguish documentation gaps,
confirmed runtime bugs, expected user errors, and backlog design requests.

---

## 1. Thesis

v0.1.8.1 made ledgr easier to learn and added the multi-output indicator bundle
authoring surface. v0.1.8.2 should correct the next hidden assumption layer:
metric context.

The current package still hides risk-free-rate and annualization assumptions in
places users reasonably expect to audit. The accepted metric-context design
turns those assumptions into explicit, inspectable analysis metadata:

```text
experiment metric_context
  -> run metric_context metadata
  -> metric_kernel for metric computation
  -> disclosed context on summaries, metrics, comparisons, sweeps, promotion
```

The release should preserve execution identity. Metric context changes metric
analysis, not strategy execution. It must not affect snapshots, strategy
hashes, feature-set hashes, seed derivation, fills, ledgers, event ordering, or
fold-core state transitions.

v0.1.8.2 may also complete the accepted Phase 2 indicator codebase cleanup if
the file moves remain purely mechanical and preserve fingerprints, feature IDs,
exports, docs, and tests. That cleanup is useful, but metric context is the
core release identity.

The auditr run is a required intake lane. It found one contract-level
preflight issue and several low-risk documentation or message improvements.
Those items should be routed into this packet before tickets are finalized,
provided they do not pull in deferred roadmap features.

Roadmap placement:

| Release | Scope |
| --- | --- |
| v0.1.8.2 | Metric context, risk-free-rate assumptions, preflight alignment, and indicator codebase Phase 2 cleanup. |
| v0.1.8.3 | Single-core sweep optimization after metric-kernel semantics settle. |
| v0.1.8.4 | Parameter-grid quality-of-life helpers. |
| v0.1.8.5 | Parallel sweep dispatch after serial semantics, metrics, and grid UX stabilize. |
| v0.1.9 | Target-risk chain. |
| v0.1.9.x | Walk-forward evaluation before OMS and paper-trading work. |
| v0.2.x+ | Execution-policy/OMS, public cost/liquidity chains, beta as feature/constraint, paper trading. |

---

## 2. Release Goals

v0.1.8.2 has four primary goals:

1. Make risk-free-rate and annualization assumptions explicit, stored, and
   recoverable across runs, summaries, metrics, comparisons, sweeps, and
   promotion context.
2. Replace standalone `bars_per_year` plumbing in metric computation with a
   serialization-safe `metric_kernel` so v0.1.8.3 sweep optimization can build
   on a stable metric interface.
3. Complete low-risk indicator file/role cleanup from the accepted
   simplification synthesis if review confirms it is mechanical.
4. Fix the confirmed preflight classifier contract gap from the auditr run.

It also has one intake gate:

5. Route accepted auditr documentation and message polish into concrete
   v0.1.8.2 tickets, deferrals, or rejections before ticket cut.

---

## 3. Scope Boundary

### In Scope

Metric context:

- `ledgr_calendar()`;
- `ledgr_calendar_us_equity()`;
- `ledgr_calendar_crypto()`;
- `ledgr_metric_context()`;
- `ledgr_metric_us_equity()`;
- `ledgr_metric_crypto()`;
- `ledgr_experiment(metric_context = ..., risk_free_rate = ...)`;
- run metadata storage for resolved metric context;
- classed `ledgr_metrics` result object;
- metric-context-aware `summary()`;
- metric-context-aware `ledgr_compute_metrics()`;
- `ledgr_compare_runs(..., metric_context = NULL)`;
- `ledgr_sweep()` using one sweep-level metric context;
- promotion context recording source sweep metric context;
- `metric_kernel` replacing standalone sweep-candidate `bars_per_year`;
- docs and print output disclosing risk-free-rate and calendar assumptions.

Indicator cleanup:

- rename `R/indicators_builtin.R` to `R/indicator-builtins.R`;
- rename `R/indicator_adapters.R` to `R/indicator-adapters.R`;
- split `R/indicator_dev.R` into `R/indicator-dev.R` and
  `R/pulse-snapshot.R`;
- preserve all public APIs, fingerprints, feature IDs, exports, error classes,
  docs, and tests.

Auditr intake:

- preflight classifier alignment for forbidden nondeterministic calls and
  global assignment;
- documentation gaps affecting v0.1.8.2 surfaces;
- message or workflow polish that fits the release boundary;
- missing-API findings only if they are explicitly accepted by maintainer
  routing.

### Non-Scope

- external reference-data adapters such as tidyfinance, FRED, or central-bank
  fetchers;
- automatic ticker lookup inside metric, strategy, indicator, or fold-core
  paths;
- beta, alpha, Treynor, information ratio, Sortino, or benchmark-relative
  public metrics;
- `ledgr_risk_free_series()` implementation unless the pending ticket-cut
  decision below explicitly proves it is bounded and safe;
- benchmark and market-factor provider implementations;
- single-core sweep optimization, typed memory events, or single-pass summary
  reconstruction;
- parameter-grid quality-of-life helpers;
- public parallel sweep dispatch;
- target-risk, order-policy, cost/liquidity chains, or OMS semantics;
- walk-forward and random-slice validation;
- paper-trading or live-trading adapters.

### Ticket-Cut Decisions

These decisions close the draft planning baseline for implementation ticket
cut:

- `ledgr_risk_free_rate()` ships in v0.1.8.2 as a scalar subordinate object
  for named/manual annual risk-free-rate assumptions.
- `ledgr_risk_free_series()` remains design-only; no time-varying
  risk-free-rate series implementation ships in v0.1.8.2.
- `ledgr_compare_runs(exp, ...)` is deferred. v0.1.8.2 implements the existing
  snapshot-first comparison form with `metric_context = NULL`; users who want
  experiment context can pass `metric_context = ledgr_metric_context(exp)`.

---

## 4. Metric Context Requirements

The accepted public model is:

```text
metric_context is the user-facing metric-assumption object
metric_kernel is the internal precompiled metric machinery
```

The UX priority is:

```text
market templates -> scalar shorthand -> explicit metric_context
```

Example:

```r
exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = strategy,
  features = features,
  metric_context = ledgr_metric_us_equity(risk_free_rate = 0.04)
)
```

Lower-level explicit form:

```r
ctx <- ledgr_metric_context(
  risk_free_rate = 0.04,
  calendar = ledgr_calendar_us_equity()
)
```

Scalar shorthand:

```r
exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = strategy,
  risk_free_rate = 0.04
)
```

The shorthand is equivalent to `ledgr_metric_context(risk_free_rate = 0.04)`,
which uses `ledgr_calendar_us_equity()` by default. Docs must state that the
default calendar is US equity daily and that crypto, international, and
intraday users should pass the relevant template or explicit calendar.

Implementation requirements:

- add `metric_context = NULL` and `risk_free_rate = NULL` to
  `ledgr_experiment()`;
- reject calls that supply both a non-NULL `metric_context` and non-NULL
  `risk_free_rate`;
- resolve `NULL` through `ledgr_metric_context_resolve(NULL)`;
- store the resolved metric context on the experiment object;
- store the resolved run metric context as run metadata at run creation or
  successful run finalization time;
- accessors for old runs must return a complete fallback context, not `NULL`;
- call-time metric-context overrides for summary/metrics are ephemeral and do
  not mutate run metadata.

---

## 5. Calendar And Annualization Requirements

`ledgr_calendar` is the public annualization primitive:

```r
ledgr_calendar(
  trading_days_per_year,
  bars_per_day = 1L
)
```

Derived:

```text
bars_per_year = trading_days_per_year * bars_per_day
```

Convenience constructors:

```r
ledgr_calendar_us_equity()
ledgr_calendar_us_equity(bars_per_day = 390L)
ledgr_calendar_crypto()
```

Transition policy:

1. If a metric context supplies a calendar, the calendar wins.
2. If no metric context is available, existing inference remains as a backward
   compatibility fallback.
3. The fallback inference is documented as imprecise for intraday and unusual
   calendars.
4. If a supplied calendar looks inconsistent with observed data, ledgr should
   warn and suggest the appropriate explicit `bars_per_day` style fix.

The spec must acknowledge the current intraday annualization bug: the existing
`snap_to_frequency()` inference maps 60-second bars to calendar minutes per
year instead of US equity trading minutes. v0.1.8.2 should frame explicit
calendar support as a correctness fix and provenance improvement, not only as
new capability.

---

## 6. Storage And Identity Requirements

Metric context is metadata, not execution identity.

Store on runs:

```text
metric_context_json
metric_context_hash
metric_context_version
```

For v0.1.8.2, prefer columns on the existing `runs` table, consistent with
current run metadata fields. A separate table can be extracted later if query
patterns justify it.

`metric_context_version` is an integer schema version for the serialized metric
context JSON format. Initial value: `1`.

`metric_context_hash` is computed with ledgr's internal `canonical_json()`
helper over normalized context fields. Omit NULL reserved fields from hash
input. Normalize dates such as `risk_free_rate$as_of` to ISO date strings
before hashing.

Metric context must not enter:

- execution config hash;
- strategy hash;
- snapshot hash;
- feature-set hash;
- sweep execution seed derivation;
- fills, ledger rows, event ordering, or target validation.

Metric context may appear in:

- run metadata;
- metric result metadata;
- comparison result metadata;
- sweep result metadata;
- promotion context;
- printed output.

---

## 7. Metric Kernel Requirements

At sweep setup:

```r
metric_context <- ledgr_metric_context_resolve(exp$metric_context)
metric_kernel <- ledgr_metric_kernel(
  context = metric_context,
  pulses = pulses_posix
)
```

`metric_kernel` replaces the standalone `bars_per_year` parameter in the sweep
candidate path. After this migration, `bars_per_year` is removed from
`ledgr_sweep_run_candidate()` and metric annualization is read from
`metric_kernel$bars_per_year`.

Minimum structure:

```r
list(
  metric_context = normalized_context_plain_list,
  metric_context_hash = "<sha256>",
  metric_context_version = 1L,
  bars_per_year = 252,
  rf_period_return = 0,
  calendar = normalized_calendar_plain_list
)
```

For scalar annual risk-free rates:

```text
rf_period_return = (1 + annual_rate)^(1 / bars_per_year) - 1
```

Serialization constraint:

- plain named list only;
- no R environment captures;
- no active bindings;
- no closures that carry mutable state;
- no live connections;
- no external pointers;
- no reference semantics.

This is a hard constraint for v0.1.8.3 optimization and future parallel sweep
dispatch.

The interface contract is:

```text
any function that consumes equity/fills/events to produce metrics accepts
metric_kernel
```

That includes today's `ledgr_metrics_from_equity_fills()` and the future
single-pass summary helper.

---

## 8. Public Output And Accessors

`ledgr_metric_context(x)` should be the public accessor/generic.

Accessor targets:

- `ledgr_experiment`;
- `ledgr_backtest`;
- `ledgr_metrics`;
- `ledgr_comparison`;
- `ledgr_sweep_results`;
- promotion context objects if useful.

`ledgr_compute_metrics()` should return a classed `ledgr_metrics` object while
remaining list-like enough for existing `$` and `[[` usage.

Summary output should disclose assumptions:

```text
Risk Metrics:
  Risk-Free Rate:      0.00% annual
  Annualization:       252 periods/year (US equity daily)
  Volatility (annual): 12.30%
  Sharpe Ratio:        0.845
```

For custom calendars:

```text
Annualization:       98280 periods/year (252 trading days * 390 bars/day)
```

`ledgr_compare_runs()` v0.1.8.2 path:

```r
ledgr_compare_runs(
  snapshot,
  run_ids = NULL,
  include_archived = FALSE,
  metrics = c("standard"),
  metric_context = NULL
)
```

`metric_context = NULL` resolves to the default context. The current hardcoded
`risk_free_rate = 0` path in `ledgr_compare_runs_metric_stats()` must be
threaded through the comparison metric context.

Mixed-cadence comparison should fail loudly rather than silently combining
incompatible annualization assumptions.

The same one-context-per-table rule applies to `ledgr_sweep()`. Sweep result
reconstruction paths must preserve the table-level metric context after any
tibble rebuild, including future optimized builders.

Metric context vocabulary:

| Context | Meaning |
| --- | --- |
| Source sweep metric context | The context that produced the candidate table and ranking metrics. |
| Run metric context | The default analysis context stored with the committed run. |
| Comparison metric context | The context that produced a comparison table. |

Promotion records the source sweep metric context separately from the promoted
run's metric context so train/test assumptions remain auditable.

---

## 9. Indicator Codebase Phase 2

Phase 1 determinism extraction shipped in v0.1.8.1. Phase 2 is eligible for
v0.1.8.2 if ticket cut confirms it remains mechanical. The sequencing
precondition from the synthesis is satisfied: Phase 1 shipped as LDG-2212 in
v0.1.8.1, and v0.1.8.1 completed its release CI cycle.

Potential file shape:

```text
R/indicator.R
R/determinism.R
R/indicator-builtins.R
R/indicator-adapters.R
R/indicator-ttr.R
R/indicator-dev.R
R/pulse-snapshot.R
```

Constraints:

- no public API changes;
- no feature ID changes;
- no fingerprint changes;
- no export changes except generated ordering if unavoidable;
- no behavior changes;
- no error-class changes, including `ledgr_invalid_args`,
  `ledgr_purity_violation`, and `ledgr_config_non_deterministic`;
- no documentation content changes except file-reference fields generated by
  roxygen;
- no broadening of `ledgr_pulse_features()` input support;
- no rename of public functions.

The Phase 2 ticket should start with existing fingerprint-stability,
feature-factory identity, indicator, feature-cache, precompute, sweep, and API
export-lock tests passing before any file move.

Required Phase 2 guard tests:

- `tests/testthat/test-fingerprint-stability.R`;
- `tests/testthat/test-indicators.R`;
- `tests/testthat/test-indicator-ttr.R`;
- `tests/testthat/test-indicator-adapters.R`;
- `tests/testthat/test-feature-cache.R`;
- `tests/testthat/test-precompute-features.R`;
- `tests/testthat/test-sweep.R`;
- `tests/testthat/test-api-exports.R`;
- `devtools::document()` with no unexpected `man/*.Rd` diffs except generated
  file-reference fields.

---

## 10. Auditr Intake And Routing

The v0.1.8.2 auditr run reviewed eight episodes and produced 30 findings:

| Bucket | Items |
| --- | ---: |
| docs_gap | 17 |
| unclear | 7 |
| expected_user_error | 3 |
| ledgr_bug | 2 |
| bad_example | 1 |

| Severity | Items |
| --- | ---: |
| high | 2 |
| medium | 5 |
| low | 23 |

Source artifacts:

- `inst/design/ledgr_v0_1_8_2_spec_packet/ledgr_triage_report.md`;
- `inst/design/ledgr_v0_1_8_2_spec_packet/categorized_feedback.yml`;
- `inst/design/ledgr_v0_1_8_2_spec_packet/cycle_retrospective.md`.

The auditr run did not find metric-context blockers. It found one
contract-level preflight gap in a previously shipped surface, several
documentation/message gaps, and a few policy decisions that must close before
ticket cut.

Required triage buckets:

- confirmed runtime bug;
- documentation gap;
- expected user error;
- missing API;
- duplicate;
- future roadmap request;
- rejected / no action.

Routing rules:

- confirmed bugs in current v0.1.8.2 surfaces should usually be fixed in this
  release;
- documentation gaps that affect metric context, metrics, summaries,
  comparisons, sweeps, or indicator cleanup should usually be fixed here;
- missing APIs require explicit maintainer approval before they become scope;
- beta, benchmark adapters, external data adapters, grid QoL, parallel sweep,
  walk-forward, target-risk, and OMS requests should route to roadmap/horizon
  unless the spec is amended.

Ticket cut is not complete until auditr findings are either assigned to
v0.1.8.2 tickets, deferred to named future milestones, or explicitly rejected.

### Must Fix In v0.1.8.2

`THEME-001` is a confirmed strategy-preflight contract problem:

- strategies using forbidden nondeterministic calls such as `Sys.time()` can
  classify as `tier_1` and then fail later when `ledgr_run()` raises
  `ledgr_config_non_deterministic` from the determinism layer;
- strategies using global assignment (`<<-`) can classify as `tier_2`, execute,
  and write a completed run.

This is a runtime contract gap, not only a documentation problem. The ticket
should align `ledgr_strategy_preflight()` with the determinism forbidden-call
policy and add explicit `<<-` detection before execution. Prefer sharing the
determinism forbidden-call list rather than duplicating it. Regression tests
must prove these strategies fail early with `ledgr_strategy_tier3` /
`ledgr_strategy_preflight_error`, not later through
`ledgr_config_non_deterministic`.

### Auditr Decision Dispositions

These auditr findings are routed as follows:

| Finding | Decision |
| --- | --- |
| Resolved external scalar strategy references | Keep resolved immutable external scalars as `tier_2`, with stronger warning and reproducibility prose. `tier_3` is reserved for unresolved helpers, mutable state, `<<-`, forbidden nondeterministic calls, and unrecoverable runtime dependencies. |
| Bundle default IDs vs hand-written TTR IDs | Keep bundle IDs as shipped in v0.1.8.1. Document the asymmetry and show `naming = ...` for users who need parity with hand-written single-output TTR IDs. |
| High-level CSV error classes | Do not add a new CSV error-class hierarchy in v0.1.8.2. Document the actual high-level classes and improve CSV/timestamp messages, artifact-state wording, and next-action guidance. |

### Batch With Metric-Context Documentation

These findings touch result, comparison, sweep, or promotion surfaces that will
already need v0.1.8.2 metric-context documentation updates:

- compare-runs setup cue for experiment-store workflows;
- report-ready numeric comparison export via `as.data.frame()` or tibble
  conversion;
- promotion replay verification example;
- `ledgr_results(bt, what = "features")` error message pointing to
  `ledgr_pulse_snapshot()`;
- warning-handling guidance for sweeps, promotions, and final-bar no-fill
  warnings.

They should be batched into a documentation/inspection track unless ticket cut
finds a small runtime message change is cleaner.

### Low-Risk Documentation And Message Polish

These low-severity findings can be one P2 docs/message track:

- Yahoo snapshot sealing/idempotence example;
- Yahoo discoverability in the task-intent map;
- `ledgr_save_help()` scalar-only note or loop example;
- partial bundle `naming` requires explicit `outputs`;
- duplicate bundle-prefix collision wording;
- timestamp errors should name `ts_utc`, UTC, and trailing-`Z` examples;
- CSV validation failures should state artifact state and next action;
- final-bar warning extension verification example;
- fills extraction and zero-fill versus zero-closed-trade examples;
- pulse-level target-name `setdiff()` diagnostic;
- compact Tier 3 hard-failure runnable example;
- real-data flat, buy-and-hold, equal-weight, and single-instrument examples.

`vignettes/strategy-development.Rmd` is the likely home for the helper-pipeline
items: fills extraction, zero-fill versus zero-closed-trade examples,
pulse-level target-name diagnostics, and compact Tier 3 hard-failure examples.

### Explicit Deferrals

- Cartesian grid boilerplate routes to v0.1.8.4 parameter-grid QoL. v0.1.8.2
  may add a vignette snippet but must not add a new grid helper without spec
  amendment. Preserve the design memory in `inst/design/horizon.md` under the
  parameter-grid construction helper entry.
- Strategy helper sharing beyond inlining routes to a future RFC. v0.1.8.2 may
  document the inlining/self-contained rewrite pattern, but must not add a
  `helpers = ...` public surface. If the idea remains active after the docs
  track, park it explicitly in `inst/design/horizon.md` before opening an RFC.
- Real-data benchmark helper APIs remain deferred. Examples are allowed;
  benchmark APIs are not.
- Auditr environment friction belongs in auditr guidance, not ledgr runtime.

---

## 11. tidyfinance Spike Handling

`LDG-2301` is a pre-spec research ticket, not implementation scope.

The tidyfinance unit probe may run during the v0.1.8.2 branch, but its findings
must not add adapter implementation to v0.1.8.2 unless this spec is amended.

Allowed outputs:

- recorded provider-unit findings;
- provider version and platform notes;
- future RFC input for external reference-data adapter design.

Disallowed outputs:

- new public ledgr adapter functions;
- hidden downloads in metric computation;
- DESCRIPTION dependency changes;
- committed raw provider data artifacts;
- beta or benchmark public APIs.

---

## 12. Candidate Ticket Tracks

The final ticket packet should likely contain these tracks after auditr routing:

1. Scope routing and auditr triage gate.
2. Strategy preflight contract alignment for forbidden nondeterminism and
   global assignment.
3. Metric context constructors, validation, hashing, and serialization.
4. Calendar constructors, annualization disclosure, and inference fallback.
5. Experiment/run storage and legacy-run fallback behavior.
6. Metric kernel integration in summary and single-run metrics.
7. Comparison and sweep metric-context threading.
8. Promotion context disclosure.
9. Summary/print/help/vignette documentation updates.
10. Auditr documentation/message polish accepted into this release.
11. Indicator codebase Phase 2 cleanup.
12. Release gate.

`LDG-2301` remains a research ticket and should not be treated as a dependency
of the implementation tracks unless a later spec amendment says otherwise.

---

## 13. Verification Strategy

Ticket cut must assign focused verification to each implementation track. The
minimum expected verification surfaces are:

- metric-context constructor and validation tests, including invalid
  `metric_context` / `risk_free_rate` combinations;
- calendar and annualization tests, including US equity daily, US equity
  intraday, crypto, and fallback inference behavior;
- metric-context hash and canonical JSON tests, including NULL-field omission,
  date normalization, and stable ordering;
- run-storage migration tests covering new runs and legacy runs without stored
  metric context;
- `ledgr_compute_metrics()` and `summary()` tests proving the stored context,
  fallback context, and call-time override behavior;
- comparison tests covering `metric_context = NULL`, explicit contexts,
  hardcoded-risk-free-rate removal, mixed-cadence failure, and accessor
  recovery;
- sweep tests covering one sweep-level context, `metric_kernel` replacing
  standalone `bars_per_year`, table-level attribute/accessor durability, and
  promotion context disclosure;
- serialization-safety tests for `metric_kernel` proving it is a plain named
  list without environments, closures, connections, external pointers, active
  bindings, or reference semantics;
- documentation contract tests for summary output, risk-free-rate disclosure,
  annualization labels, calendar defaults, intraday warnings, and sensitivity
  analysis guidance;
- Phase 2 indicator cleanup guard tests listed in Section 9 if that track is
  retained;
- stale-version and encoding scans from the release playbook;
- full `testthat`, `R CMD build`, and `R CMD check --no-manual
  --no-build-vignettes` before release closeout.

---

## 14. Definition Of Done

Before release:

- auditr triage is complete and routed;
- preflight classifier alignment fixes are implemented and covered by
  regression tests;
- all ticket statuses are synchronized in markdown and YAML;
- metric context is disclosed anywhere Sharpe or annualized metrics are printed;
- run, comparison, sweep, promotion, and metric result accessors recover the
  used metric context;
- legacy runs have documented fallback behavior;
- metric context does not change execution identity or fold-core behavior;
- metric-kernel objects are plain serializable lists;
- existing metric behavior is preserved where default context equals today's
  assumptions;
- intraday inference limitations are documented and explicit calendars are
  taught as the preferred fix;
- NEWS documents user-visible metric-context changes and any auditr fixes;
- full tests pass;
- package check passes with agreed release flags;
- stale-version and encoding scans are clean;
- no generated local artifacts or raw spike outputs are committed.
