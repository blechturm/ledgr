# ledgr v0.1.8.4 Tickets

Version: v0.1.8.4
Date: 2026-05-26
Total Tickets: 13

## Ticket Organization

This packet implements the scoped v0.1.8.4 plan from `v0_1_8_4_spec.md`:
active parameterized feature aliases, separated feature-grid and strategy-grid
helpers, active alias lookup in run/sweep contexts, pulse-debug inspection, and
the small auditr-routed fixes accepted for this cycle.

The implementation spine is:

```text
parameter references
  -> feature-map resolution and parameter introspection
  -> grid helpers
  -> active alias lookup in ledgr_run() / ledgr_sweep()
  -> alias-map identity and provenance
  -> pulse-debug inspection
  -> demo strategy and docs
  -> warmup-guard docs cleanup
```

The auditr spine is deliberately bounded:

```text
bundle output identity
  -> sweep print footer
  -> preflight message ordering
  -> runnable sweep-script discovery
  -> bounded Yahoo / real-data notes
```

Broad workflow documentation, metric-context lifecycle documentation,
cross-surface accounting/metric explanations, snapshot lineage, live data logs,
point-in-time regressors, scaffold helpers, ranking/tuning helpers, target risk,
walk-forward, parallel dispatch, and DuckDB-backed feature storage remain out
of scope for this release unless the maintainer amends the packet.

## Dependency DAG

```text
LDG-2421 Scope Routing, Packet Setup, And Auditr Intake
  |-- LDG-2422 Parameter Reference Declarations And Constructor Integration
  |     |-- LDG-2423 Feature Resolution, Introspection, And Bundle Identity
  |     |     |-- LDG-2425 Active Alias Runtime Lookup In Run And Sweep
  |     |     |     |-- LDG-2426 Alias Map Identity, Provenance, And Hashes
  |     |     |     |-- LDG-2427 Pulse Debug And Feature Inspection Alias Views
  |     |     |     `-- LDG-2428 Demo SMA Crossover Strategy Helper
  |     |     `-- LDG-2430 Primary Active-Alias Documentation Path
  |     `-- LDG-2424 Feature, Strategy, And Executable Grid Helpers
  |           |-- LDG-2425 Active Alias Runtime Lookup In Run And Sweep
  |           `-- LDG-2430 Primary Active-Alias Documentation Path
  |-- LDG-2429 Auditr-Routed Sweep Print And Preflight Message Fixes
  |     `-- LDG-2430 Primary Active-Alias Documentation Path
  |-- LDG-2432 Warmup Guard Documentation Cleanup
  |     `-- LDG-2430 Primary Active-Alias Documentation Path
  `-- LDG-2431 Bounded Real-Data And Error-Message Documentation Polish
        `-- LDG-2430 Primary Active-Alias Documentation Path

LDG-2433 Release Gate And Closeout depends on LDG-2421 through LDG-2432.
```

## Priority Levels

- P0: Release gate, scope gate, or implementation blocker.
- P1: Public API, runtime contract, provenance, feature identity, or release
  correctness.
- P2: Documentation, message polish, examples, or bounded auditr cleanup.

---

## LDG-2421: Scope Routing, Packet Setup, And Auditr Intake

Priority: P0
Effort: S
Dependencies: none
Status: Done

### Description

Finalize the v0.1.8.4 packet after the v0.1.8.3 auditr report lands. This
ticket converts the accepted active-alias spec, auditr intake synthesis,
workflow deferrals, roadmap context, and design index into synchronized
implementation planning artifacts.

### Tasks

- Update `v0_1_8_4_spec.md` so auditr input is routed rather than pending.
- Record accepted auditr routes in `auditr_intake_synthesis.md`.
- Cut `v0_1_8_4_tickets.md` and `tickets.yml`.
- Confirm broad workflow documentation is deferred to v0.1.8.5.
- Confirm runtime surfaces outside active aliases and grid helpers remain out
  of scope.
- Keep the release thesis narrow: active-alias sweep authoring UX plus bounded
  auditr fixes.

### Acceptance Criteria

- Spec, ticket markdown, and `tickets.yml` agree on ticket IDs, dependencies,
  statuses, and scope.
- Every accepted auditr finding has a ticket, a deferral, or an explicit
  non-ledgr/auditr-side route.
- Deferred public API ideas name their future roadmap/horizon home.
- v0.1.8.4 ticket cut does not silently pull in v0.1.8.5 workflow scope.

### Verification

Manual packet review and `git diff --check`.

### Source Reference

- `v0_1_8_4_spec.md`
- `auditr_intake_synthesis.md`
- `categorized_feedback.yml`
- `ledgr_triage_report.md`
- `cycle_retrospective.md`
- `inst/design/rfc/rfc_active_parameterized_feature_aliases_v0_1_8_x_synthesis.md`

### Classification

```yaml
type: governance
surface: design_packet
scope: v0.1.8.4
```

### Completion Notes

- Added `auditr_intake_synthesis.md` and changed `v0_1_8_4_spec.md` from
  pending auditr intake to routed auditr intake.
- Added the auditr-routed parameterized bundle output identity constraint to
  the spec's bundle semantics and verification requirements.
- Cut `LDG-2421` through `LDG-2432` in this ticket packet and synchronized
  machine-readable metadata in `tickets.yml`.

---

## LDG-2422: Parameter Reference Declarations And Constructor Integration

Priority: P1
Effort: M
Dependencies: LDG-2421
Status: Done

### Description

Add first-class scalar parameter references through `ledgr_param("name")` and
teach the first-pass ledgr-owned indicator constructors to accept those
references in supported scalar tuning arguments.

### Tasks

- Implement `ledgr_param()` declaration objects with stable printing,
  validation, and serialization behavior.
- Reject missing, empty, non-string, multi-value, or unsupported parameter
  references with classed errors.
- Update the first-pass supported indicator constructors so supported scalar
  tuning arguments may accept `ledgr_param()`.
- Ensure unresolved parameterized declarations are not treated as concrete
  indicators.
- Make `ledgr_feature_id()` fail loudly on unresolved parameterized
  declarations and unresolved bundles.
- Document which constructor arguments support parameter references in this
  pass.

### Acceptance Criteria

- `ledgr_param("fast_n")` creates a stable declaration object.
- Unsupported parameter-reference placement fails with an action-oriented
  classed error.
- Concrete constructor behavior remains unchanged when no parameter reference
  is supplied.
- Existing concrete feature fingerprints remain stable.
- Unresolved declarations cannot be accidentally precomputed or used as
  concrete feature IDs.

### Verification

Targeted tests for parameter construction, constructor integration, unresolved
feature ID failures, and existing fingerprint pins.

### Completion Notes

- Added `ledgr_param()` and exported `ledgr_parameters()`.
- Added unresolved parameterized indicator and bundle declaration objects.
- Integrated `ledgr_param()` with first-pass ledgr-owned constructors:
  `ledgr_ind_sma()`, `ledgr_ind_ema()`, `ledgr_ind_rsi()`,
  `ledgr_ind_returns()`, `ledgr_ind_ttr()`, and
  `ledgr_ind_ttr_outputs()`.
- Kept `ledgr_indicator()` custom construction concrete-only by rejecting
  parameter references in direct custom indicator metadata.
- Made `ledgr_feature_id()` fail with `ledgr_unresolved_feature_id` for
  unresolved declarations.
- Verified with feature-map, indicator, TTR, fingerprint-stability, API export,
  precompute, sweep, and documentation-contract targeted tests.

### Source Reference

- `v0_1_8_4_spec.md` Sections 3 and 9
- `rfc_active_parameterized_feature_aliases_v0_1_8_x_synthesis.md`

### Classification

```yaml
type: feature
surface: feature_authoring
scope: parameter_references
```

---

## LDG-2423: Feature Resolution, Introspection, And Bundle Identity

Priority: P1
Effort: L
Dependencies: LDG-2422
Status: Done

### Description

Resolve parameterized feature maps to ordinary concrete indicators for each run
or sweep candidate. Add parameter introspection and enforce safe concrete
feature identity for parameterized bundles.

### Tasks

- Implement feature-map resolution from `feature_params` to concrete
  indicators.
- Add `ledgr_parameters(features)` with stable minimum columns:
  `param_name`, `alias`, and `argument`.
- Validate required feature parameters before run/sweep/precompute execution.
- Allow unused feature parameters but surface them through inspection where
  practical.
- Preserve concrete feature fingerprints and `feature_set_hash` semantics.
- Enforce the auditr-routed parameterized bundle output identity constraint:
  same flat strategy-facing bundle aliases may resolve to candidate-specific
  concrete IDs, but concrete projection IDs must be parameter-distinct.
- Produce classed errors for missing parameters, non-scalar values, unsupported
  placements, and unresolved/ambiguous bundle outputs.

### Acceptance Criteria

- A feature map containing `ledgr_param()` resolves to concrete indicators when
  all required `feature_params` are supplied.
- Missing feature parameters fail before candidate execution or precompute.
- `ledgr_parameters()` reports duplicated references as separate rows.
- Mixed concrete and parameterized feature maps are supported; concrete entries
  are shared across candidates.
- Parameterized bundle outputs with different parameter values do not collide
  in concrete projection identity.
- If a parameterized bundle cannot be disambiguated safely, the resolver fails
  before execution with an action-oriented classed error.

### Verification

Targeted feature-map resolution tests, parameter introspection tests, bundle
projection tests, fingerprint stability tests, and a multi-candidate
parameterized bundle collision regression.

### Completion Notes

- Updated `ledgr_feature_map()` to accept mixed concrete and parameterized
  declarations while preserving existing concrete-map behavior.
- Added feature-map resolution from concrete `feature_params` to ordinary
  concrete indicators before materialization.
- Added `ledgr_parameters()` introspection with duplicated references reported
  as separate rows.
- Added missing and non-scalar feature-parameter errors with classed failures.
- Added parameterized TTR bundle output resolution that keeps flat
  strategy-facing aliases but makes candidate-specific concrete projection IDs
  parameter-distinct.
- Verified mixed concrete/parameterized map resolution and TTR bundle identity
  regression coverage.

### Source Reference

- `v0_1_8_4_spec.md` Sections 3, 5, 6, and 9
- `auditr_intake_synthesis.md` AUD-184-02
- `rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`

### Classification

```yaml
type: feature
surface: feature_resolution
scope: active_alias_materialization
```

---

## LDG-2424: Feature, Strategy, And Executable Grid Helpers

Priority: P1
Effort: L
Dependencies: LDG-2421
Status: Done

### Description

Add public grid construction helpers that keep feature parameters and strategy
parameters in separate namespaces while producing executable sweep candidates.

### Tasks

- Implement `ledgr_feature_grid()` with cross-product construction, scalar
  recycling, deterministic labels, duplicate handling, JSON-safe values, and
  `.filter`.
- Implement `ledgr_strategy_grid()` with the same construction semantics and
  compatibility inheritance from `ledgr_param_grid`.
- Implement `ledgr_grid_cross()` to compose feature and strategy grids into
  executable candidates.
- Implement `ledgr_grid_named()` for explicitly named executable candidates.
- Implement `ledgr_grid_add_baseline()` for appending named baseline
  candidates.
- Enforce `.filter` evaluation rules and unknown-symbol failures.
- Ensure composed candidates store separate `feature_params` and
  `strategy_params` namespaces.

### Acceptance Criteria

- Feature-grid rows cannot be accidentally passed as strategy params.
- Strategy-grid objects remain compatible with existing `ledgr_param_grid`
  checks where intended.
- `ledgr_grid_cross(strategy = strategy_grid)` and
  `ledgr_grid_cross(features = feature_grid)` each create one empty row for the
  omitted namespace.
- Calling `ledgr_grid_cross()` with both sides omitted fails with guidance.
- Grid labels are deterministic and duplicate labels fail where specified.
- `ledgr_grid_named()` accepts nested `feature` and `strategy` specs.
- `ledgr_grid_add_baseline()` supports multiple named baselines in one call.

### Verification

Targeted grid-helper tests for construction, labels, filters, omitted-grid
behavior, class inheritance, duplicate failures, and executable candidate
shape.

### Completion Notes

- Added `ledgr_feature_grid()`, `ledgr_strategy_grid()`,
  `ledgr_grid_cross()`, `ledgr_grid_named()`, and
  `ledgr_grid_add_baseline()`.
- Kept `ledgr_feature_grid()` distinct from `ledgr_param_grid` so feature rows
  cannot be accidentally passed as strategy params.
- Made `ledgr_strategy_grid()` inherit from `ledgr_param_grid` for existing
  strategy-grid compatibility.
- Made executable grids inherit from `ledgr_param_grid` while storing nested
  `feature_params` and `strategy_params` namespaces per candidate.
- Added narrow `.filter` validation with classed failures for unsupported
  symbols, global-state reads, invalid lengths, and `NA` outputs.
- Added omitted-grid handling, named executable candidates, baseline appends,
  duplicate-label checks, and feature-resolution integration for executable
  grid feature params.
- Verified with grid-helper, param-grid, API export, feature-map, precompute,
  sweep, and documentation-contract targeted tests.

### Source Reference

- `v0_1_8_4_spec.md` Section 4

### Classification

```yaml
type: feature
surface: sweep_grid_helpers
scope: authoring_ux
```

---

## LDG-2425: Active Alias Runtime Lookup In Run And Sweep

Priority: P1
Effort: L
Dependencies: LDG-2423, LDG-2424
Status: Done

### Description

Thread resolved alias maps through `ledgr_run()` and `ledgr_sweep()` so
strategies can read active aliases through `ctx$features(id)` while the fold
still consumes ordinary concrete features through the shared projection path.

### Tasks

- Add `feature_params` support to `ledgr_run()` for parameterized feature maps.
- Ensure `params` remains the strategy-parameter list passed to
  `strategy(ctx, params)`.
- Resolve each sweep candidate's feature map from that candidate's
  `feature_params`.
- Thread the resolved alias map into the fold context.
- Implement active `ctx$features(id)` alias lookup for current run/candidate
  alias maps.
- Preserve exact concrete feature ID lookup and explicit map lookup behavior.
- Fail loudly when `ctx$features(id)` is called without an active alias map.
- Preserve the shared fold core; do not add a second execution path.

### Acceptance Criteria

- `ledgr_run()` can execute a parameterized feature map with explicit
  `feature_params` and separate strategy `params`.
- `ledgr_sweep()` can execute candidates with separate feature and strategy
  parameter namespaces.
- `ctx$features(id)` returns alias-keyed numeric values when an active alias map
  is available.
- `passed_warmup(ctx$features(id))` works for active alias vectors.
- Static feature-set workflows keep current exact-ID behavior.
- No feature factory is called from inside strategy code in the recommended
  active-alias path.
- `ledgr_run()` and `ledgr_sweep()` still share the same fold core.

### Verification

Run/sweep active-alias tests, exact-ID regression tests, passed-warmup tests,
state-leak checks where relevant, and existing sweep/backtest-wrapper tests.

### Completion Notes

- Added `feature_params` support to `ledgr_run()` while keeping `params` as
  the strategy-runtime parameter namespace.
- Materialized feature maps into concrete indicators plus a resolved active
  alias map before fold execution.
- Threaded active alias maps through both committed runs and in-memory sweep
  candidate execution without introducing a second fold path.
- Added `ctx$features(id)` active-alias lookup while preserving
  `ctx$feature(id, feature_id)` and explicit `ctx$features(id, feature_map)`
  behavior.
- Added classed `ledgr_no_active_alias_map` failures when the active lookup is
  used without a resolved alias map.
- Verified `passed_warmup(ctx$features(id))` against active alias vectors.

### Source Reference

- `v0_1_8_4_spec.md` Sections 3 and 6
- `inst/design/contracts.md`

### Classification

```yaml
type: feature
surface: pulse_context
scope: active_alias_lookup
```

---

## LDG-2426: Alias Map Identity, Provenance, And Hashes

Priority: P1
Effort: M
Dependencies: LDG-2425
Status: Done

### Description

Store resolved alias maps in execution identity and provenance without changing
concrete feature fingerprints or the concrete-feature-only `feature_set_hash`.

### Tasks

- Add `alias_map_json`, `alias_map_hash`, and `alias_map_version` where
  execution identity stores active alias maps.
- Include the resolved alias map in `config_hash`.
- Keep `feature_set_hash` concrete-feature-only.
- Ensure `alias_map_hash` changes when alias mappings change.
- Preserve promotion and candidate replay provenance.
- Expose enough alias-map provenance for failure-row and promoted-candidate
  inspection.
- Document the relationship between `config_hash`, `feature_set_hash`, and
  `alias_map_hash`.

### Acceptance Criteria

- Alias-only name changes affect `config_hash`.
- `feature_set_hash` remains unchanged when concrete features are unchanged.
- `alias_map_hash` changes when alias mappings change.
- Sweep failure rows and candidate provenance include the resolved alias map or
  an inspectable reference to it.
- Promotion/replay can verify the candidate's resolved alias map.
- Existing non-active-alias provenance remains backward compatible.

### Verification

Hash tests, sweep provenance tests, promotion context tests, failure-row tests,
and serialization round-trip checks for alias maps.

### Completion Notes

- Added alias-map storage helpers with `alias_map_json`, `alias_map_hash`, and
  `alias_map_version`.
- Included resolved alias-map identity in committed-run configs so alias-only
  name changes affect `config_hash`.
- Preserved concrete-only `feature_set_hash` behavior by leaving feature
  fingerprints unchanged by alias names.
- Added sweep result `feature_params` and candidate-feature provenance columns
  for resolved alias maps.
- Included alias-map provenance in sweep success and failure rows.
- Verified alias-map JSON round-trip, alias-hash sensitivity, config-hash
  sensitivity, and feature-set-hash stability.

### Source Reference

- `v0_1_8_4_spec.md` Section 7
- `rfc_active_parameterized_feature_aliases_v0_1_8_x_synthesis.md`

### Classification

```yaml
type: provenance
surface: execution_identity
scope: alias_map
```

---

## LDG-2427: Pulse Debug And Feature Inspection Alias Views

Priority: P2
Effort: M
Dependencies: LDG-2425
Status: Done

### Description

Update pulse debugging and feature inspection tools so they can speak the new
active-alias naming convention and separate feature params from strategy
params.

### Tasks

- Add `feature_params` support to `ledgr_pulse_snapshot()` for parameterized
  feature declarations.
- Update `ledgr_pulse_features()` so it can display strategy-facing aliases
  and resolved concrete feature IDs.
- Update `ledgr_pulse_wide()` so it can provide an alias-keyed view when a
  feature map or active alias map is available.
- Ensure pulse-debug helpers keep exact concrete-feature behavior available.
- Improve missing-parameter and unresolved-alias messages for pulse-debug
  workflows.
- Add runnable examples or documentation snippets for pulse-debug setup.

### Acceptance Criteria

- Pulse debugging can inspect a parameterized feature map with concrete
  `feature_params`.
- Inspection views show alias and concrete feature ID without collapsing
  feature and strategy params into one namespace.
- Exact concrete-feature inspection remains supported.
- Missing feature params name the parameter and alias/argument that requires
  it.
- Pulse feature helper examples are runnable or explicitly point to setup.

### Verification

Pulse-snapshot tests, pulse-feature tests, pulse-wide tests, error-class tests,
and documentation example checks where available.

### Completion Notes

- Added `feature_params` support to `ledgr_pulse_snapshot()` for
  parameterized feature maps.
- Stored the resolved active alias map and alias-map hash metadata on pulse
  snapshots.
- Updated `ledgr_pulse_features()` to use active aliases by default when a
  pulse carries an alias map, while still showing concrete feature IDs.
- Updated `ledgr_pulse_wide()` so alias-aware views use strategy-facing
  aliases as wide feature keys.
- Preserved exact concrete inspection by allowing explicit named alias maps and
  ordinary non-feature-map snapshots to continue using concrete feature IDs.
- Improved feature-parameter errors so missing or non-scalar values name the
  alias and constructor argument requiring them.
- Preserved declaration-order runtime alias lookup while keeping canonical
  sorted alias-map JSON for hashing.

### Source Reference

- `v0_1_8_4_spec.md` Section 8
- `auditr_intake_synthesis.md` THEME-007 routing

### Classification

```yaml
type: feature
surface: pulse_debug
scope: active_alias_inspection
```

---

## LDG-2428: Demo SMA Crossover Strategy Helper

Priority: P2
Effort: S
Dependencies: LDG-2425
Status: Todo

### Description

Add a small tuneable SMA-crossover demo strategy helper for README,
getting-started, and sweeps documentation. The helper is a teaching fixture,
not an investment recommendation and not a strategy library surface.

### Tasks

- Implement `ledgr_demo_sma_crossover_strategy()`.
- Require active aliases named `fast` and `slow`.
- Use `passed_warmup()` for warmup guard.
- Read strategy params `qty` and `threshold`.
- Return full named numeric target vectors.
- Keep the feature map explicit in docs; do not add
  `ledgr_demo_sma_crossover_features()` in this cycle.
- Document the helper's required parameter contract and failure mode when
  active aliases are absent.

### Acceptance Criteria

- The helper returns a Tier-1-compatible function.
- Strategy preflight reports `tier_1`, `allowed = TRUE`, and no unresolved
  symbols.
- The helper holds until `fast` and `slow` pass warmup.
- `qty = 0L` produces a flat baseline candidate.
- Missing aliases or no active alias map fail through the same classed errors
  as ordinary active-alias lookup.
- Documentation presents the helper as a demo fixture, not a recommended
  trading strategy.

### Verification

Strategy preflight tests, run/sweep demo tests, warmup tests, missing-alias
tests, and documentation contract checks.

### Source Reference

- `v0_1_8_4_spec.md` Section 3

### Classification

```yaml
type: feature
surface: demo_strategy
scope: documentation_fixture
```

---

## LDG-2429: Auditr-Routed Sweep Print And Preflight Message Fixes

Priority: P2
Effort: S
Dependencies: LDG-2421
Status: Done

### Description

Implement the two small auditr-routed behavior/message fixes that are
independent of the active-alias runtime spine.

### Tasks

- Update sweep result printing so reordering or subsetting does not claim rows
  are still in parameter-grid order.
- Add regression coverage for reordered sweep results.
- Update strategy preflight reporting so `<<-` global assignment violations are
  prioritized over unresolved-symbol noise for left-hand-side names.
- Add regression coverage for a `global_probe_value <<- 1` style strategy.
- Keep strategy rejection semantics unchanged.

### Acceptance Criteria

- Reordered sweep result printing is neutral or accurate.
- `ledgr_candidate()` metadata-preservation warnings still work when users
  drop sweep-result classes.
- `<<-` strategies remain rejected.
- Preflight messages prioritize the mutation violation and do not lead with an
  irrelevant unresolved LHS symbol.

### Verification

Sweep print tests and strategy preflight tests.

### Completion Notes

- Replaced the sweep-result footer with neutral current-table-order guidance
  so reordered/subsetted results no longer claim parameter-grid order.
- Added explicit reordered-sweep print regression coverage.
- Suppressed unresolved-symbol noise for `<<-` left-hand-side names while
  preserving Tier 3 global-assignment rejection semantics.
- Added regression coverage for `global_probe_value <<- 1`.
- Verified with:
  `testthat::test_file('tests/testthat/test-sweep.R')` and
  `testthat::test_file('tests/testthat/test-strategy-preflight.R')`.

### Source Reference

- `auditr_intake_synthesis.md` AUD-184-01 and AUD-184-03

### Classification

```yaml
type: bugfix
surface: sweep_print_and_preflight
scope: auditr_routed
```

---

## LDG-2430: Primary Active-Alias Documentation Path

Priority: P2
Effort: L
Dependencies: LDG-2423, LDG-2424, LDG-2425, LDG-2427, LDG-2428, LDG-2429, LDG-2431
Status: Todo

### Description

Update the main user-facing documentation path for active aliases, grid helpers,
and the demo strategy while preserving the boundary against broader workflow
documentation that belongs to v0.1.8.5.

### Tasks

- Update README first-contact example with explicit feature map, feature grid,
  strategy grid, executable grid, and demo strategy.
- Update getting-started with the active-alias mental model.
- Update sweeps with feature-grid versus strategy-grid usage, `.filter`,
  baseline candidate, metadata-preserving ranking, `ledgr_candidate()`, and
  promotion verification.
- Update strategy-development to move users away from feature factories inside
  strategies and toward active aliases.
- Update indicators with `ledgr_param()` examples and bundle alias semantics.
- Ensure docs do not hide feature maps behind a demo feature helper.
- Ensure experiment-store, reproducibility, metrics-and-accounting, leakage,
  and custom-indicators are not converted wholesale to the demo strategy.
- Fix runnable sweep script discovery: either make the prepared sweeps script
  useful or stop listing it as runnable.

### Acceptance Criteria

- First-contact docs teach feature params and strategy params as separate
  namespaces.
- The active-alias example is runnable and uses the demo strategy without
  hiding feature declarations.
- The docs show a metadata-preserving sweep ranking/selection pattern and warn
  against `as.data.frame()` before `ledgr_candidate()` when metadata matters.
- Bundle docs clarify flat strategy-facing aliases versus concrete feature IDs.
- Runnable script listings include only useful executable workflow code.
- v0.1.8.5 workflow topics are linked or deferred, not duplicated into this
  cycle.

### Verification

Documentation contract tests where available, example smoke tests, stale
version scan, encoding scan, and manual docs review.

### Source Reference

- `v0_1_8_4_spec.md` Section 8
- `auditr_intake_synthesis.md` AUD-184-04 and AUD-184-05
- `rfc_research_workflow_artifact_topology_v0_1_8_x_synthesis.md`

### Classification

```yaml
type: documentation
surface: active_alias_docs
scope: installed_docs
```

---

## LDG-2431: Bounded Real-Data And Error-Message Documentation Polish

Priority: P2
Effort: M
Dependencies: LDG-2421
Status: Todo

### Description

Apply bounded auditr-routed docs/message polish that fits v0.1.8.4 without
opening the v0.1.8.5 canonical workflow cycle.

### Tasks

- Add small Yahoo notes where relevant:
  - Yahoo snapshot creation/sealing semantics;
  - optional `TTR` dependency callout for examples that use TTR indicators;
  - Yahoo price-adjustment policy pointer if already known;
  - buy-and-hold baseline sizing warning where examples compare strategies.
- Improve touched errors so they name expected classes, unchanged artifact
  state, next action, and the most relevant violation first where practical.
- Avoid a package-wide error-message rewrite.
- Avoid a full real-data workflow article.
- Record explicit deferrals to v0.1.8.5 for broad workflow, metric-context, and
  accounting/metric surface docs.

### Acceptance Criteria

- v0.1.8.4 docs no longer imply Yahoo snapshots require a separate seal step
  after helper creation if the helper already seals.
- Optional TTR-dependent examples make the dependency clear.
- Baseline comparison examples avoid or flag unfair fixed-quantity comparisons.
- Touched error messages are more action-oriented without changing core
  behavior.
- Broad workflow themes are explicitly deferred rather than silently omitted.

### Verification

Documentation review, targeted error-message tests where behavior is touched,
stale version scan, and `git diff --check`.

### Source Reference

- `auditr_intake_synthesis.md` AUD-184-06 and AUD-184-07
- `categorized_feedback.yml` THEME-006 and THEME-008

### Classification

```yaml
type: documentation
surface: real_data_and_messages
scope: bounded_auditr_polish
```

---

## LDG-2432: Warmup Guard Documentation Cleanup

Priority: P2
Effort: S
Dependencies: LDG-2421
Status: Done

### Description

Make `passed_warmup()` the canonical vignette and example pattern for mapped
feature warmup guards. Avoid teaching ad hoc checks such as `!is.na(sma)` or
`is.na(f[["fast"]]) || is.na(f[["slow"]])` in installed examples.

### Tasks

- Search README, vignettes, examples, and man-page examples for hand-written
  feature warmup checks.
- Replace feature-vector warmup guards with `passed_warmup(x)` where the input
  is a mapped feature vector returned by `ctx$features()`.
- Keep `is.na()` only where the example is explicitly about scalar NA behavior
  or non-feature data, and add a short justification if needed.
- Ensure the active-alias demo strategy and v0.1.8.4 docs use
  `passed_warmup(ctx$features(id))`.
- Link or mention `passed_warmup()` in the active-alias, strategy-development,
  sweeps, and indicators documentation where warmup is taught.

### Acceptance Criteria

- Installed vignettes do not teach ad hoc `!is.na(sma)` feature warmup checks
  as the recommended pattern.
- Active-alias examples use `passed_warmup()` for `ctx$features()` vectors.
- Any remaining `is.na()` checks in examples are not feature-vector warmup
  guards or are explicitly justified.
- `passed_warmup()` remains documented as the strategy-authoring guard for
  mapped feature values.

### Verification

Documentation grep for `is.na(`, `!is.na(`, and `passed_warmup`; documentation
contract tests where available; manual docs review.

### Completion Notes

- Replaced vignette feature warmup examples in `strategy-development` and
  `research-to-production` with `passed_warmup()` guards.
- Updated both source `.Rmd` files and checked-in rendered `.md` companions.
- Verified that installed vignette/man/README grep only leaves the
  `passed_warmup()` reference explanation of its underlying predicate.

### Source Reference

- `v0_1_8_4_spec.md` Sections 1, 3, 8, and 9
- `passed_warmup()` reference documentation

### Classification

```yaml
type: documentation
surface: warmup_docs
scope: installed_docs
```

---

## LDG-2433: v0.1.8.4 Release Gate And Closeout

Priority: P0
Effort: M
Dependencies: LDG-2421, LDG-2422, LDG-2423, LDG-2424, LDG-2425, LDG-2426, LDG-2427, LDG-2428, LDG-2429, LDG-2430, LDG-2431, LDG-2432
Status: Todo

### Description

Run the v0.1.8.4 release gate, confirm accepted scope is complete, and record
explicit deferrals for future workflow and storage/data cycles.

### Tasks

- Run targeted tests for active aliases, grid helpers, pulse debugging, demo
  strategy, provenance, sweep print, and preflight message changes.
- Run full package tests.
- Run package build and `R CMD check --no-manual --no-build-vignettes`.
- Run documentation/example checks required by touched docs.
- Update NEWS with active-alias/grid-helper user-facing summary.
- Confirm v0.1.8.5 workflow deferrals are recorded.
- Confirm no generated local artifacts are committed.
- Mark ticket statuses complete in both ticket files.

### Acceptance Criteria

- All tests and package checks required by the release playbook pass or have a
  documented maintainer-approved exception.
- Active alias docs and runtime behavior match the spec.
- The auditr-routed accepted fixes are complete or explicitly deferred by
  maintainer decision.
- Broad workflow, split-store, live-log, PIT-regressor, and scaffold-helper
  items remain out of v0.1.8.4.
- `v0_1_8_4_tickets.md` and `tickets.yml` agree on final statuses.

### Verification

Full test suite, package build/check, docs checks, ticket status sync, and
manual release-gate review.

### Source Reference

- `v0_1_8_4_spec.md`
- `tickets.yml`
- `inst/design/release_ci_playbook.md`

### Classification

```yaml
type: release_gate
surface: package
scope: v0.1.8.4
```
