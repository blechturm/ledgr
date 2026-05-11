# ledgr v0.1.7.9 Spec

**Status:** Draft
**Target Version:** v0.1.7.9
**Scope:** Strategy-author ergonomics, warmup feasibility checks, helper
empty-selection semantics, public documentation flow, and v0.1.7.8 auditr
intake
**Inputs:**

- `inst/design/ledgr_roadmap.md`
- `inst/design/contracts.md`
- `inst/design/ledgr_design_document.md`
- `inst/design/ledgr_design_philosophy.md`
- `inst/design/ledgr_v0_1_7_8_spec_packet/auditr_v0_1_7_7_followup_plan.md`
- `vignettes/getting-started.Rmd`
- `vignettes/strategy-development.Rmd`
- `vignettes/indicators.Rmd`
- `vignettes/custom-indicators.Rmd`
- `vignettes/reproducibility.Rmd`
- `vignettes/leakage.Rmd`
- `vignettes/metrics-and-accounting.Rmd`
- `vignettes/experiment-store.Rmd`
- `vignettes/research-to-production.Rmd`
- `vignettes/articles/who-ledgr-is-for.Rmd`
- `vignettes/articles/why-r.Rmd`
- `_pkgdown.yml`
- Public-facing documentation review feedback received after the v0.1.7.8
  release

---

## 1. Purpose

v0.1.7.9 closes the remaining strategy-author ergonomics gap before v0.1.8
sweep mode.

v0.1.7.7 stabilized risk metrics and comparison semantics. v0.1.7.8 stabilized
strategy reproducibility preflight, leakage-boundary documentation, provenance
language, and the fold-core/output-handler contract. The next release should not
start sweep mode yet. It should make the existing strategy-author workflow easier
to understand and validate from public docs and exported helpers.

The release has two related goals:

1. **Make common strategy-author mistakes easier to detect before a run.**
   Warmup feasibility, feature IDs, feature-map aliases, and current-bar feature
   availability should be discoverable without manual DuckDB inspection or
   fragile heuristics.
2. **Make the public site feel intentional.** v0.1.7.8 added strong concept
   articles. v0.1.7.9 should reorder, polish, and tighten them so the package
   reads as an auditable research system rather than a collection of long
   examples.

This release remains conservative. It may improve helper semantics and add a
feature-contract inspection helper, but it must not introduce sweep mode, a
second runner, new execution semantics, or the deferred `ctx$all_features()`
surface.

---

## 1.1 Evidence Baseline

| Evidence | Classification | v0.1.7.9 handling |
| --- | --- | --- |
| v0.1.7.5 auditr ergonomics feedback | Existing routed evidence | Promote warmup feasibility, feature-map/accessor discoverability, comparison/summary print clarity, and snapshot metadata clarity. |
| v0.1.7.7 auditr follow-up plan | Existing routed evidence | Use the v0.1.7.9 candidate bundle as the baseline scope. Keep auditr-owned harness issues excluded. |
| v0.1.7.8 release docs are strong but public flow is uneven | Public documentation polish | Reorder pkgdown articles, trim internal homepage material, remove stale version references, and make core concept articles easier to enter. |
| `ledgr_feature_contracts()` reports feature requirements but not snapshot-specific feasibility | UX/API gap | Add `ledgr_feature_contract_check(snapshot, features)` with per-instrument available-bar counts and warmup feasibility. |
| `select_top_n()` warns on all-warmup/no-signal empty selections | Helper ergonomics gap | Return a classed empty selection without warning for the expected no-usable-values path. |
| Strategy docs still explain some raw sizing patterns indirectly | Documentation gap | Document the canonical whole-share allocation formula used by `target_rebalance()`. |
| Feature maps, aliases, engine IDs, and context accessors span multiple docs | Discoverability gap | Add a strategy-context/accessor reference surface and cross-link from relevant help pages. |
| v0.1.7.8 auditr THEME-001 | First-run docs gap | Keep tidyverse-adjacent public examples; make suggested-package expectations explicit rather than adding a separate base-R path. |
| v0.1.7.8 auditr THEME-002 | Indicator docs gap | Expand generated feature ID, warmup, `requires_bars`, `stable_after`, dependency fallback, and strategy-oriented examples. |
| v0.1.7.8 auditr THEME-003 | Feature-map boundary ambiguity | Resolve or document feature-map compatibility across `ledgr_experiment()`, pulse inspection, lower-level helpers, and legacy backtest surfaces. |
| v0.1.7.8 auditr THEME-004 | Runtime message clarity | Promote only concrete item-level error/warning improvements with raw evidence; avoid a broad rewrite. |
| v0.1.7.8 auditr THEME-005 | Store/comparison docs gap | Add programmatic examples for raw comparison metrics, equity follow-up, strategy recovery/rerun, run-info fields, and post-close access. |
| v0.1.7.8 auditr THEME-006 | Custom-indicator contract ambiguity | Clarify scalar `fn(window, params)`, `series_fn` precedence, params behavior, and causal vectorized examples. |
| v0.1.7.8 auditr THEME-007 | Snapshot lifecycle docs gap | Consolidate CSV/Yahoo snapshot lifecycle, sealing semantics, `ledgr_snapshot_info()` columns, and `meta_json` keys. |
| v0.1.7.8 auditr THEME-008 | Auditr harness / runner friction | Exclude from ledgr package scope; route PowerShell quoting, locked logs, help-server capture, and episode-runner guidance to auditr. |
| v0.1.7.8 auditr THEME-009 | Small strategy-helper/lifecycle edge-case docs | Promote only scope-aligned examples: helper discovery, partial-NA handling, post-close access, Tier 3 classes, and ledger-event meaning. |
| v0.1.7.8 auditr THEME-010 | Metrics/scripted usage docs gap | Clarify `summary()` print/return behavior, `ledgr_compute_metrics()` programmatic use, Sharpe edge cases, and annualization constants. |
| Public rendered docs contain stale/internal artifacts | Public polish gap | Remove local temp paths, stale packet/version references, public placeholders, and generated profiling files. |
| Research-to-production article overclaims ledger reconciliation | Safety wording gap | Clarify that the ledger reconstructs ledgr's expected state and paper/live modes still require broker reconciliation. |
| v0.1.7.8 auditr report | Incoming evidence | Route confirmed docs/UX findings into v0.1.7.9, keep auditr harness findings excluded, and defer feature-series retrieval API design to v0.1.8. |

---

## 2. Release Shape

v0.1.7.9 has seven coordinated tracks.

### Track A - Scope, Intake, And Release Baseline

Confirm the v0.1.7.9 scope against the roadmap and the v0.1.7.7 auditr follow-up
plan. Keep a written routing decision for every promoted finding.

This track also owns intake of the v0.1.7.8 auditr report. The report is
now available in this packet as `cycle_retrospective.md` and
`ledgr_triage_report.md`. Each finding must be classified before promotion:

- confirmed ledgr runtime defect;
- ledgr documentation/discoverability gap;
- public-site polish issue;
- later roadmap/backlog item;
- auditr harness/environment issue;
- unclear, requiring raw evidence before action.

Only confirmed ledgr package issues may enter v0.1.7.9 scope. Auditr
harness/task-brief friction remains outside ledgr package work.

### Track B - Feature Contract Feasibility Helper

Implement and document `ledgr_feature_contract_check(snapshot, features)`.

The helper must combine feature contract requirements with the actual sealed
snapshot shape. It should answer a user-facing question:

```text
Can these registered features become usable for every instrument in this
snapshot, or is warmup impossible for some instrument-feature pairs?
```

This is a pre-run inspection helper only. It must not mutate snapshots, repair
features, impute data, or change the runner.

### Track C - Helper Empty-Selection Semantics

Change `select_top_n()` so the all-missing/no-usable-signal path returns a
classed empty selection instead of emitting a warning.

The empty result is expected during warmup and in legitimate no-signal regimes.
The helper pipeline should let strategies write the ordinary path:

```r
signal <- signal_return(ctx, lookback = params$lookback)
selection <- select_top_n(signal, n = params$n)
weights <- weight_equal(selection)
target_rebalance(weights, ctx, equity_fraction = params$equity_fraction)
```

without `suppressWarnings()` around a normal warmup condition.

### Track D - Strategy Author Documentation And Accessor Reference

Improve strategy-author docs around:

- `ctx$feature(id, feature_id)`;
- `ctx$features(id, feature_map)`;
- feature-map aliases versus engine feature IDs;
- feature objects accepted by `ledgr_experiment()`;
- feature object shapes used by lower-level helpers;
- canonical whole-share sizing for raw target strategies;
- current-bar and warmup troubleshooting;
- generated feature IDs for built-in, TTR-backed, and multi-output indicators;
- multi-lookback feature pre-registration when `params` vary lookback.

This track may add a dedicated strategy-context/accessor article or a reference
surface linked from existing articles, whichever fits the current pkgdown shape
with the least duplication.

This track also owns custom-indicator authoring clarity when the issue affects
strategy authors directly: scalar `fn(window, params)` signatures,
`series_fn(bars, params)` signatures, scalar/vectorized precedence, expected
equivalence, params behavior in run and pulse inspection paths, and at least one
causal corrected `series_fn` example.

### Track E - Metrics, Comparison, Snapshot, And Store Discoverability

Close documentation/discoverability gaps that are already surfaced in the
auditr follow-up plan:

- formatted comparison print views versus raw numeric columns;
- `summary(bt)` print output versus returned object behavior;
- exact-ID helpers when tibble output truncates identifiers;
- zero-trade/open-exposure interpretation;
- annualization cadence and metric assumptions;
- flat-strategy Sharpe `NA` and near-zero excess-return volatility behavior;
- `ledgr_compute_metrics()` as the scripted metric extraction path;
- `ledgr_snapshot_info()` examples for sealed handles;
- parsed metadata fields, counts, and ISO UTC date formats;
- post-close result/store inspection expectations;
- raw `ledgr_compare_runs()` metric extraction and follow-up equity comparison
  examples;
- `ledgr_run_info()` field reference and stored-strategy recovery/rerun example;
- last-bar no-fill warning interpretation near articles where the warning
  appears;
- the current boundary for persisted feature retrieval: ledgr exposes feature
  contracts and pulse-time feature inspection, but a full feature-series
  retrieval API is deferred to v0.1.8.

This track is mostly documentation and tests. Code changes should be limited to
small error-message or print-method fixes with raw evidence.

### Track F - Public Site Polish

Apply the public documentation review feedback that is safe and scope-aligned:

- reorder `_pkgdown.yml` articles into a clearer reader journey;
- move audience/philosophy pages earlier;
- trim internal `system.file()` and design-packet details from the homepage;
- remove stale version references such as `v0.1.7.2 helper layer` and old
  "current packet" wording;
- remove stale visible link text such as
  ``[`custom-indicators.md`](custom-indicators.html)`` from public articles;
- avoid local machine paths in rendered README/homepage output;
- fix rendered warnings such as `no DISPLAY variable` if present;
- make `custom-indicators.Rmd` self-contained and runnable;
- show useful `ledgr_strategy_preflight()` output in the reproducibility article;
- clarify research-to-production reconciliation wording;
- soften or link `auditr` companion-package references depending on public
  availability;
- remove generated profiling artifacts such as `Rprof.out` from the public repo
  and ignore them going forward.

This track should improve public presentation without creating new conceptual
articles unless a gap blocks existing docs.

### Track G - Release Gate

Finalize NEWS, ticket status, machine-readable ticket state, documentation
contracts, and verification. Confirm that the v0.1.7.8 auditr report has been
routed and that any deferred findings are recorded explicitly.

---

## 3. Hard Requirements

### R1 - No Second Execution Path

v0.1.7.9 must not add a second runner, a second strategy invocation path, or a
new fill/accounting path.

Any helper or documentation change must preserve the v0.1.7 public contract:
user-facing strategies are `function(ctx, params)`, return full named numeric
targets or an explicit helper wrapper that maps to those targets, and execute
through `ledgr_run()`.

### R2 - Feature Contract Check Uses Sealed Snapshot Evidence

`ledgr_feature_contract_check(snapshot, features)` must derive available bar
counts from the sealed snapshot data, not from heuristics such as total rows
divided by instrument count.

The minimum output columns are:

- `instrument_id`;
- `feature_id`;
- `requires_bars`;
- `available_bars`;
- `warmup_achievable`.

The helper must work with the same feature input shapes accepted by
`ledgr_feature_contracts()`: indicator objects, lists of indicators, named
lists, and feature maps.

`ledgr_experiment(features = ...)` also accepts a feature factory of the form
`function(params)`. That form is intentionally deferred until concrete strategy
parameters exist. `ledgr_feature_contract_check(snapshot, features)` must not
call a feature factory with guessed or empty parameters. For v0.1.7.9, the
standalone helper rejects feature factories with a classed, actionable error
that tells the user to materialize the factory first and call the helper on the
resulting indicators or feature map. A future overload may add an explicit
`params` argument, but that is out of scope for this release.

The helper must not compute feature values. It checks feasibility of the
declared contracts against the sealed snapshot.

### R3 - Feature Contract Check Is Inspectable, Not Corrective

`warmup_achievable = FALSE` is diagnostic information. The helper must not:

- impute missing bars;
- shorten lookbacks automatically;
- alter `requires_bars` or `stable_after`;
- silently drop instruments;
- mutate the snapshot;
- register replacement features.

The user remains responsible for choosing a longer snapshot, a smaller lookback,
or a different feature set.

### R4 - Empty Selection Is An Object, Not A Warning

For `select_top_n(signal, n)`, the all-missing/no-usable-values path must return
a classed empty selection without warning.

The returned object must:

- inherit from `ledgr_selection`;
- preserve the full original universe somewhere the downstream helpers already
  understand or are updated to understand;
- preserve signal origin metadata where available;
- be accepted by `weight_equal()`;
- be accepted by `target_rebalance()` after conversion through
  `weight_equal()`;
- produce a flat target through the normal helper pipeline.

The existing class name `ledgr_empty_selection` may be reused, but it must be a
result class, not only a warning class.

Track C must explicitly review `weight_equal()` and `target_rebalance()` in
addition to `select_top_n()`. If their current empty-selection handling already
preserves the original universe and produces a flat full-universe target, tests
should pin that behavior. If not, Track C owns the smallest helper updates
needed to make the pipeline work without warning suppression.

Partial selection warnings, where fewer than `n` finite values exist but some
selection can still be made, are not automatically removed by this requirement.
They may be revisited only if raw evidence shows they cause durable UX friction.

### R5 - Warmup Diagnostics Must Stay Causal

Warmup/current-bar examples must not imply a strategy can inspect future feature
values to decide whether warmup has passed.

Docs should teach:

- use `ledgr_feature_contracts(features)` to understand feature requirements;
- use `ledgr_feature_contract_check(snapshot, features)` to check snapshot
  feasibility;
- use pulse inspection to see the feature values available at one decision time;
- treat `NA_real_` for a known feature as warmup or unavailable signal, not as
  an unknown feature ID.

Unknown feature IDs must continue to fail loudly.

### R6 - Context And Feature-Map Docs Must Distinguish Namespaces

Docs must distinguish:

- feature-map aliases, such as `ret_5`;
- engine feature IDs, such as `return_5`;
- pulse-time scalar lookup with `ctx$feature(id, feature_id)`;
- pulse-time alias lookup with `ctx$features(id, feature_map)`;
- the list/map objects passed to `ledgr_experiment(features = ...)`.

The docs should not suggest that helpers create or register features lazily from
`params`. If a strategy varies lookback through `params`, every concrete feature
variant must be registered before `ledgr_run()`.

### R7 - Raw Strategy Sizing Formula Must Match `target_rebalance()`

The strategy-development vignette must document the canonical whole-share sizing
formula for users who write raw target strategies:

```r
floor(equity_fraction * ctx$equity / ctx$close(instrument_id))
```

When weights are involved, the formula must match the `target_rebalance()`
contract:

```r
floor(weight * equity_fraction * ctx$equity / ctx$close(instrument_id))
```

Docs must state that sizing uses decision-time close and current pulse equity;
fills still occur at the configured later fill point.

### R8 - Public Site Must Not Publish Local Or Stale Artifacts

The public README/pkgdown surface must not contain:

- local user paths such as `C:\Users\...`;
- stale release references such as `v0.1.7.2 helper layer` when the point is not
  version-specific;
- stale "current packet" references to older versions;
- placeholder article filenames as visible prose;
- generated profiling artifacts such as `Rprof.out`;
- avoidable environment warnings such as `no DISPLAY variable` in rendered
  examples.

If a local path is part of a print method, examples should either use a stable
temporary placeholder in expected output or omit the path from rendered public
examples.

### R9 - Research-To-Production Must Not Overclaim Reconciliation

The research-to-production article must not say that no reconciliation is needed
for paper/live trading.

The correct framing is:

```text
No in-memory state is trusted across restarts. The ledger reconstructs ledgr's
expected state. In paper and live modes, that expected state must still be
reconciled against broker-reported orders, positions, cash, and fills before
trading resumes.
```

Equivalent wording is acceptable if it preserves the same safety boundary.

### R10 - v0.1.7.8 auditr Findings Are Inputs, Not Tickets

The v0.1.7.8 auditr report must not automatically expand v0.1.7.9.

Every finding must be routed before action. Findings may be promoted into
v0.1.7.9 only if they are:

- confirmed ledgr package defects;
- public documentation issues that fit the v0.1.7.9 docs-polish scope;
- strategy-author ergonomics issues already aligned with this milestone;
- blockers for v0.1.8 sweep readiness.

Findings that concern auditr task briefs, episode runners, local shell behavior,
or review harness discovery scripts remain auditr-owned unless raw evidence
shows a package defect.

### R11 - `ctx$all_features()` Remains Deferred

v0.1.7.9 must not implement `ctx$all_features()`.

The roadmap rationale must remain visible: the vectorized all-features accessor
should be designed with the v0.1.8 fold-core and precomputed-feature shapes, not
before them. v0.1.7.9 may improve docs for existing `ctx$feature()` and
`ctx$features()` surfaces only.

### R12 - No Sweep Mode

v0.1.7.9 must not add:

- `ledgr_sweep()`;
- `ledgr_precompute_features()`;
- parameter-grid execution workers;
- no-persistence run execution;
- fold-core refactors beyond documentation or contract clarification.

If work is needed to unblock v0.1.8, record it as a contract or backlog item
unless the maintainer explicitly promotes it into v0.1.7.9.

---

## 3.1 Maintainer Decisions Recorded

The v0.1.7.8 auditr report raised several scope questions. The following
decisions are part of the v0.1.7.9 contract before ticket cut.

### MD1 - Feature-Map Compatibility

Normalize around `ledgr_experiment()` as the canonical public path.

- `ledgr_experiment(features = ...)` accepts indicators, lists, named lists,
  feature maps, and feature factories.
- Pulse inspection helpers should accept the same static feature shapes where
  feasible.
- Legacy or lower-level helpers may stay narrower, but must document accepted
  shapes explicitly.
- Any mismatch that affects the modern experiment-first workflow is a bug.
  Mismatch only in legacy/lower-level paths is documentation debt unless the
  normalization fix is trivial.

### MD2 - `ledgr_backtest()` Feature Maps

Do not make `ledgr_backtest()` a first-class feature-map target in v0.1.7.9.

If `ledgr_backtest()` currently claims feature-map support, correct the claim or
route through the same feature normalization used by `ledgr_experiment()` only
if the implementation is low risk. The experiment-first workflow remains the
documented canonical path.

### MD3 - Runtime Error Improvements

Promote only concrete, item-level message improvements with raw evidence. Do
not create a broad "improve all errors" ticket.

The initial shortlist from `categorized_feedback.yml` in the v0.1.7.8 auditr
episodes directory is:

- `LEDGR_LAST_BAR_NO_FILL`: explain the next-open/final-pulse condition and, if
  cheap, include affected timestamp and instrument count.
- OHLC validation errors: include offending row count and the first few row
  indices, timestamps, instrument IDs, and violated bounds.
- `LEDGR_SNAPSHOT_COVERAGE_ERROR`: include the first missing
  `(instrument_id, ts_utc)` pair, requested universe, and requested range.
- `ledgr_results(bt, what = "metrics")`: replace generic `match.arg()` output
  with a ledgr-specific message pointing to `ledgr_compute_metrics(bt)`.
- `ledgr_unknown_feature_id`: include a registration hint for common
  parameterized IDs, such as registering `ledgr_ind_returns(20)` before
  `ledgr_run()` when the strategy asks for `return_20`.
- wrapped strategy errors: deduplicate repeated condition classes where feasible.
- indicator purity violations: name matched unsafe calls such as `Sys.time()`.

Tickets may promote a smaller subset if raw evidence shows that a message is
harder to improve safely than expected.

### MD4 - Experiment-Store CSV Bridge

Keep the low-level CSV bridge at the end of `experiment-store.Rmd` for
v0.1.7.9, but add a transition that marks it as an advanced import bridge rather
than the core store workflow. Record a future article candidate:
"Data Input And Snapshot Creation".

### MD5 - Persisted Feature Retrieval

No persisted feature-series retrieval API in v0.1.7.9.

Document the current boundary: feature contracts and pulse-time feature
inspection are public; full feature-series retrieval is deferred to v0.1.8
`ledgr_precompute_features()` and sweep result shape design.

### MD6 - First-Run Example Dependencies

ledgr is intentionally tidyverse-adjacent in public examples. The README and
Getting Started workflow may continue to use `dplyr` for data preparation.

Do not add a separate base-R smoke path only to satisfy agent cold-start
friction. Instead, make the dependency expectation explicit:

- examples may use `dplyr` for demo-data preparation and inspection;
- strategy functions should still use ledgr pulse contexts, not data-frame
  operations;
- missing suggested packages should fail with a clear setup/install hint where
  feasible;
- auditr/agent workflows should install suggested example packages or state that
  ledgr public docs assume them.

### MD7 - `ctx$all_features()`

Keep `ctx$all_features()` deferred to v0.1.8. v0.1.7.9 may explain why users
must currently use `ctx$feature()` or `ctx$features(id, feature_map)`.

### MD8 - `select_top_n()` Empty Selection

Implement the classed empty-selection behavior. This is a real helper UX change,
not documentation-only work.

### MD9 - Snapshot Lifecycle

Consolidate CSV, Yahoo, sealing, `ledgr_snapshot_info()`, and `meta_json`
examples in documentation only. No schema/API changes unless tests reveal a true
package defect.

### MD10 - Train/Test Split

No `ledgr_snapshot_split()` in v0.1.7.9. Keep the evaluation-discipline note in
the sweep UX design and revisit split helpers when v0.1.8 sweep docs are
written.

---

## 4. Documentation Requirements

Documentation work is part of the product surface in this release.

### D1 - Pkgdown Article Order

The article navigation should be reorganized around the reader journey. A
preferred grouping is:

```text
Start Here
- Who ledgr is for
- Getting Started with ledgr
- On Leakage: ledgr Design Choices
- On Reproducibility: Provenance and Strategy Tiers

Core Workflow
- Strategy Development And Comparison
- Indicators And Feature IDs
- Custom Indicators And External Features
- Metrics And Accounting
- Experiment Store

Design / Background
- Design Philosophy: From Research to Production
- Why ledgr is built in R
```

The exact section names may change, but audience/philosophy must not remain
buried after all technical workflow articles.

### D2 - Homepage Cleanup

The homepage should preserve the core product pitch:

```text
sealed snapshot -> experiment -> run -> event ledger -> results
```

but remove or relocate internal details that distract first-time readers:

- headless `system.file()` navigation commands;
- stale design-packet references;
- local machine paths in rendered output;
- overly detailed internal help text better suited to reference pages.

### D3 - Custom Indicator Article Must Be Runnable Or Clearly Schematic

`vignettes/custom-indicators.Rmd` should not use undefined `snapshot`,
undefined `strategy`, or hard-coded `AAA` unless the article has built that
snapshot and instrument.

Preferred behavior: make the "Register And Read" section self-contained with
`ledgr_demo_bars`, `DEMO_01`/`DEMO_02`, a `range_3` custom indicator, a strategy
loop over `ctx$universe`, and an experiment using the registered feature.

### D4 - Reproducibility Article Should Show Preflight Results

The reproducibility article should show enough `ledgr_strategy_preflight()`
output to teach the tier model from the rendered page:

- Tier 1 result;
- Tier 2 result with visible dependency;
- Tier 3 result with unresolved symbol diagnostic.

If any of those chunks remain `eval = FALSE` after v0.1.7.8, v0.1.7.9 must
either render them or explicitly explain why the example is schematic. The
preferred result is that all three tier examples render real preflight output.

The examples must stay consistent with the actual print method and must not
duplicate the reference page excessively.

### D5 - Experiment Store Scope Should Stay Focused

The experiment-store article should remain focused on durable snapshots, run
variants, list/info/label/tag/archive, compare, extract strategy, and reopen.

The low-level CSV bridge section was already moved to the end of the article in
v0.1.7.8. v0.1.7.9 should decide whether that is sufficient or whether the
section should be cut from the article and routed to a later "data input and
snapshot creation" article or reference example. v0.1.7.9 may record the split
as a backlog item rather than doing it if scope is tight.

---

## 5. Test Requirements

Tests should scale with risk.

### T1 - Feature Contract Check Tests

Add unit tests covering:

- balanced snapshot with achievable warmup;
- snapshot where one instrument has too few bars;
- multiple features with different `requires_bars`;
- feature map aliases and engine feature IDs;
- invalid feature inputs following existing `ledgr_feature_contracts()`
  validation behavior;
- no mutation of snapshot tables.

### T2 - Empty Selection Tests

Update strategy-helper tests so:

- all-missing signals return an object with class `ledgr_empty_selection`;
- no warning is emitted for the all-missing path;
- `weight_equal(select_top_n(empty_signal, n))` returns empty weights with the
  original universe preserved;
- `target_rebalance(weight_equal(select_top_n(empty_signal, n)), ctx, ...)`
  returns a full-universe flat target;
- existing tie-breaking and partial-selection behavior remains deterministic.

### T3 - Documentation Contract Tests

Update `test-documentation-contracts.R` or equivalent documentation tests to
pin:

- `ledgr_feature_contract_check()` appears in the reference index and relevant
  article links;
- feature factories supplied as `function(params)` produce the specified
  classed error in `ledgr_feature_contract_check()`;
- the custom-indicator article no longer uses undefined schematic `AAA` strategy
  code in the register/read section;
- public articles do not display stale `custom-indicators.md` link text when
  linking to `custom-indicators.html`;
- pkgdown article order contains the intended groups;
- homepage output contains no local `C:\Users\` paths;
- stale version references are absent where no longer intentional;
- research-to-production reconciliation wording does not overclaim;
- rendered docs do not contain `no DISPLAY variable`, if the warning can be
  reproduced locally.

### T4 - Release Verification

Before release:

- targeted tests for new helper and strategy helpers pass;
- documentation contract tests pass;
- full `testthat::test_local()` passes on Windows;
- `R CMD check --no-manual --no-build-vignettes` passes;
- pkgdown builds;
- generated artifacts are not committed;
- Ubuntu and Windows CI are green.

---

## 6. Non-Goals

- No sweep mode.
- No `ledgr_sweep()`.
- No `ledgr_precompute_features()`.
- No `ctx$all_features()`.
- No new strategy signature.
- No new asset class, shorting, margin, or broker semantics.
- No automatic environment management for Tier 2 strategies.
- No automatic warmup repair.
- No data-vendor validation framework.
- No persisted feature-series retrieval API. v0.1.7.9 may document the current
  inspection boundary, but full retrieval of computed feature series should be
  designed with the v0.1.8 `ledgr_precompute_features()` and sweep result
  shapes.
- No `ledgr_snapshot_split()` or train/test split helper. v0.1.7.9 may record
  the split-snapshot evaluation discipline for v0.1.8 sweep planning, but it
  must not implement the helper in this release.
- No large documentation expansion beyond the existing public surface unless
  the v0.1.7.8 auditr report identifies a blocking gap.

---

## 7. auditr Intake

The v0.1.7.8 auditr report has been received in this packet:

- `inst/design/ledgr_v0_1_7_9_spec_packet/cycle_retrospective.md`
- `inst/design/ledgr_v0_1_7_9_spec_packet/ledgr_triage_report.md`

Before ticket cut, the maintainer should decide whether to:

1. update this spec before ticket cut;
2. add a separate routing artifact to this packet;
3. add one or more v0.1.7.9 tickets with raw-evidence references;
4. defer the findings to v0.1.8 or a later documentation backlog;
5. mark findings auditr-owned and excluded.

The default is conservative: do not expand v0.1.7.9 unless the finding matches
the strategy-author ergonomics or public-docs polish scope, or blocks v0.1.8
sweep readiness.

### 7.1 Late Execution-Engine Audit Intake

After the original v0.1.7.9 ticket cut, a focused execution-engine audit was
added at `inst/design/execution_engine_audit.md`. The audit is promoted into
v0.1.7.9 only where it affects release correctness or public contract clarity:

- Opening-position cost basis is a release-blocking correctness bug. Runs that
  use `ledgr_opening(positions = ..., cost_basis = ...)` currently record the
  opening lots as `CASHFLOW` events, while FIFO lot matching only processes
  `FILL` events. Liquidating an opening position therefore produces wrong
  realized/unrealized P&L and wrong trade metrics. This is in scope for
  v0.1.7.9 as a P0 bug ticket.
- FIFO lot-accounting duplication is part of the same bug surface. The fix must
  avoid patching only one result path; it should introduce or route through a
  shared internal lot-accounting primitive.
- `spread_bps` already applies as a full per-leg price adjustment. The behavior
  is not changed in v0.1.7.9, but public docs must explain the convention.
- Dead live equity arrays in the runner may be removed as a narrow cleanup if
  targeted tests confirm no behavior depends on them.
- Minor audit findings about lower-level opening-position validation, RNG
  side effects, and fixed-commission SELL cash deltas must be explicitly routed
  before release. They are not automatically behavior-change tickets.
- The pending-buffer `>` guard is a corrected false positive and must not be
  changed to `>=`.

---

## 8. Suggested Ticket Families

The final ticket list should be cut after v0.1.7.8 auditr intake is routed. A
likely ticket family split is:

1. Scope baseline, auditr intake, and public-docs review routing.
2. `ledgr_feature_contract_check()` contract, implementation, tests, and docs.
3. `select_top_n()` empty-selection semantics and helper-pipeline tests.
4. Strategy context/accessor, feature-map, warmup, and sizing documentation.
5. Metrics/comparison/summary/snapshot/store discoverability docs.
6. Public site polish, pkgdown article order, homepage cleanup, and repo hygiene.
7. Opening-position cost-basis and shared FIFO lot-accounting bug fix.
8. Fill-model spread semantics documentation.
9. Execution-engine cleanup and minor audit finding routing.
10. Release gate, NEWS, verification, and final auditr routing confirmation.

---

## 9. Definition Of Done

v0.1.7.9 is complete when:

- `ledgr_feature_contract_check(snapshot, features)` is implemented, exported,
  documented, and tested;
- `select_top_n()` returns a classed empty selection without warning for the
  all-missing/no-usable-values path;
- the helper pipeline handles empty selections without warning suppression;
- strategy-author docs explain feature IDs, aliases, `ctx$feature()`,
  `ctx$features()`, warmup feasibility, and canonical whole-share sizing;
- comparison, summary, snapshot-info, and experiment-store discoverability gaps
  from the routed auditr findings are closed or explicitly deferred;
- persisted feature-series retrieval is explicitly deferred to v0.1.8
  precompute/sweep design;
- pkgdown article ordering reflects the intended reader journey;
- public docs contain no stale local paths, stale version references, or known
  placeholder artifacts;
- `Rprof.out` and similar generated artifacts are absent from the repository and
  ignored going forward;
- the research-to-production article no longer overclaims reconciliation;
- the v0.1.7.8 auditr report is routed and deferred findings are recorded
  explicitly;
- opening-position lot accounting correctly honors opening cost basis across
  fills, trades, equity reconstruction, derived state, and run comparison
  metrics;
- `spread_bps` per-leg semantics are documented without changing fill behavior;
- execution-engine audit cleanup and minor findings are fixed, documented, or
  explicitly deferred;
- NEWS and ticket statuses match the shipped scope;
- local verification and Ubuntu/Windows CI are green.
