# ledgr v0.1.8.4 Spec

**Status:** Completed release record for v0.1.8.4.
**Target Branch:** `v0.1.8.4`
**Scope:** Active parameterized feature aliases plus parameter-grid
construction helpers for sweep authoring, with routed v0.1.8.3 auditr
findings.
**Auditr Input:** Routed. The v0.1.8.3 auditr report is summarized in
`inst/design/ledgr_v0_1_8_4_spec_packet/auditr_intake_synthesis.md`. The
report has no high-severity findings. v0.1.8.4 accepts the small sweep
print-footer, parameterized bundle identity, preflight message-ordering, and
bounded docs/message polish routes named in that synthesis. Broader workflow
documentation findings defer to v0.1.8.5.
**Non-scope for this pass:** Automatic candidate ranking, winner selection,
`ledgr_tune()` semantics, objective functions, walk-forward validation,
target-risk chains, cost/liquidity policy, OMS work, parallel dispatch,
DuckDB-backed feature storage, out-of-core projection, collapse adoption,
primitive-internals refactors, Rust/Rcpp engines, vectorized/tidy strategy
authoring layers, and broad adapter parameterization beyond the first-pass
constructor set.

---

## 0. Source Inputs

Authoritative inputs:

- `inst/design/contracts.md`
- `inst/design/ledgr_roadmap.md`
- `inst/design/README.md`
- `inst/design/rfc/rfc_active_parameterized_feature_aliases_v0_1_8_x_synthesis.md`
- `inst/design/rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`

Supporting context:

- `inst/design/horizon.md`
- `inst/design/release_ci_playbook.md`
- `inst/design/rfc/rfc_strategy_authoring_parameterized_indicators_v0_1_8_x.md`
- `inst/design/rfc/rfc_strategy_authoring_parameterized_indicators_v0_1_8_x_response.md`
- `inst/design/rfc/rfc_active_parameterized_feature_aliases_v0_1_8_x.md`
- `inst/design/rfc/rfc_active_parameterized_feature_aliases_v0_1_8_x_response.md`
- `inst/design/rfc/rfc_multi_output_indicator_ux_synthesis.md`
- `inst/design/rfc/rfc_pulse_context_data_model_consolidation_v0_1_8_3_synthesis.md`
- `inst/design/rfc/rfc_collapse_primitive_internals_v0_1_9_synthesis.md`
- `inst/design/ledgr_v0_1_8_3_spec_packet/v0_1_8_3_spec.md`

Auditr intake:

- `inst/design/ledgr_v0_1_8_4_spec_packet/ledgr_triage_report.md`
- `inst/design/ledgr_v0_1_8_4_spec_packet/categorized_feedback.yml`
- `inst/design/ledgr_v0_1_8_4_spec_packet/cycle_retrospective.md`
- `inst/design/ledgr_v0_1_8_4_spec_packet/auditr_intake_synthesis.md`

This spec does not treat auditr rows as automatically true package defects.
Rows are evidence. Ticket cut must distinguish confirmed runtime bugs,
documentation gaps, expected user errors, low-risk message polish, and backlog
design requests.

---

## 1. Thesis

v0.1.8.4 is a sweep-authoring UX release.

v0.1.8.0 introduced sequential sweeps. v0.1.8.3 made them fast enough that
larger grids are now a realistic public workflow. The remaining user friction
is authoring parameterized indicator sweeps without hand-writing large grids or
writing strategy bodies before users understand the feature/strategy namespace
model.

The current workaround:

```r
features <- function(params) {
  ledgr_feature_map(
    fast = ledgr_ind_sma(params$fast_n),
    slow = ledgr_ind_sma(params$slow_n)
  )
}

strategy <- function(ctx, params) {
  x <- ctx$features("SPY", features(params))
}
```

is not acceptable as the recommended path. It calls a user-defined helper from
inside strategy code and is therefore Tier 3 under the strategy preflight
contract.

The v0.1.8.4 user model should instead be:

```r
features <- ledgr_feature_map(
  fast = ledgr_ind_sma(ledgr_param("fast_n")),
  slow = ledgr_ind_sma(ledgr_param("slow_n"))
)

feature_grid <- ledgr_feature_grid(
  fast_n = c(10L, 20L, 50L),
  slow_n = c(40L, 80L, 200L),
  .filter = fast_n < slow_n
)

strategy_grid <- ledgr_strategy_grid(
  threshold = c(0.00, 0.01),
  qty = c(50L, 100L)
)

grid <- ledgr_grid_cross(
  features = feature_grid,
  strategy = strategy_grid
)

strategy <- ledgr_demo_sma_crossover_strategy()
```

This keeps the strategy body Tier-1-friendly:

- feature aliases are stable strategy-facing names;
- feature parameter values come from the feature grid;
- strategy parameter values come from the strategy grid and are the only
  values passed to `strategy(ctx, params)`;
- concrete indicators are resolved before precompute, run, or sweep execution;
- the fold still consumes ordinary concrete features through the shared
  v0.1.8.3 projection path;
- `passed_warmup()` remains the strategy-authoring guard for mapped feature
  values.

The demo strategy is a teaching fixture, not a feature declaration helper and
not an investment recommendation. First-contact documentation should keep the
feature map explicit so users see that `fast` and `slow` are active aliases.
Strategy-development documentation should then show the equivalent expanded
strategy body so users can move from the demo fixture to custom strategies.

The release should ship the alias and grid authoring surface together. Active
aliases without grid construction helpers solve only half the UX problem:
users would still need to hand-write large named `ledgr_param_grid()` calls.
v0.1.8.4 therefore pulls the previously planned v0.1.8.5 grid-helper slice
into the active-alias cycle.

The release must keep two parameter namespaces clear:

```text
feature params   -> materialize parameterized features
strategy params  -> passed to strategy(ctx, params)
candidate        -> feature params + strategy params + resolved alias map
```

Do not teach one flat candidate parameter list as the main active-alias UX.
That model is internally convenient but user-confusing because it makes feature
materialization inputs and strategy-function inputs look like the same concept.

This deliberately amends the active-alias synthesis Section 3, steps 5-6,
which described `ledgr_run()` and `ledgr_sweep()` resolving declarations from a
single concrete `params` object. This spec splits that object into
`feature_params` for resolution-time feature materialization and `params` /
`strategy_params` for strategy-runtime decisions. The amendment prevents the
public UX from conflating indicator-construction inputs with strategy-decision
inputs.

---

## 2. Release Goals

v0.1.8.4 has eight primary goals:

1. Add first-class scalar parameter references through `ledgr_param("name")`.
2. Let the first-pass ledgr-owned indicator constructors accept parameter
   references in supported scalar tuning arguments.
3. Resolve parameterized feature maps to ordinary concrete indicators for each
   run or sweep candidate before feature precompute and fold execution.
4. Add active alias lookup through `ctx$features(id)` when the current run or
   candidate has an active alias map.
5. Add feature-grid, strategy-grid, and grid-composition helpers so
   parameterized sweeps are usable without hand-writing large named
   `ledgr_param_grid()` calls or mixing feature and strategy parameters in one
   public namespace.
6. Store resolved alias maps in execution identity and provenance without
   changing concrete feature fingerprints or the concrete-feature-only
   `feature_set_hash`.
7. Update pulse debugging and feature inspection tools so they can display
   active aliases, resolved concrete feature IDs, feature parameters, and
   strategy parameters without collapsing the new namespaces.
8. Ship a small tuneable SMA-crossover demo strategy helper for README,
   getting-started, and sweeps documentation, while keeping feature
   declarations explicit in examples.

It has one required auditr route:

9. Implement or explicitly ticket the accepted v0.1.8.3 auditr routes:
   parameterized bundle output identity, sweep print-footer wording, preflight
   global-assignment message ordering, bounded docs/message polish, and
   deferrals to v0.1.8.5 for broad workflow documentation.

---

## 3. User-Facing Scope

### Parameter References

Add:

```r
ledgr_param("fast_n")
```

First-pass rules:

- parameter names are non-empty strings;
- references are serializable authoring data, not executable expressions;
- direct scalar substitution only;
- no arithmetic expressions on references;
- no formula or tidy-eval placeholder syntax;
- no nested references;
- missing parameters fail at materialization with a classed error;
- non-scalar parameter values fail at materialization with a classed error.

Users who need derived feature values compute them before constructing the
feature grid:

```r
feature_grid <- ledgr_feature_grid(
  fast_n = c(10L, 20L),
  width = c(30L, 60L)
)
```

or use explicitly named executable candidates with precomputed feature
parameter values.

### Supported Constructors

The first pass supports `ledgr_param()` in documented scalar tuning positions
for:

- `ledgr_ind_sma()`;
- `ledgr_ind_ema()`;
- `ledgr_ind_rsi()`;
- `ledgr_ind_returns()`;
- `ledgr_ind_ttr()`;
- `ledgr_ind_ttr_outputs()`.

Supported placement means scalar indicator-tuning arguments such as window
lengths and scalar options.

Unsupported placement includes:

- feature IDs;
- feature-map aliases;
- instrument IDs;
- input/output column names;
- function-valued arguments;
- `series_fn` and adapter functions;
- arbitrary lists;
- direct `ledgr_indicator()` custom construction.

Custom indicators remain concrete in the first pass. Users should resolve
parameter values before calling `ledgr_indicator()` until a future custom
indicator parameterization contract exists.

### Feature Maps And Active Aliases

`ledgr_feature_map()` accepts concrete indicators, concrete bundles, and
parameterized declarations.

Mixing concrete and parameterized entries in one feature map is allowed:

```r
features <- ledgr_feature_map(
  fast = ledgr_ind_sma(ledgr_param("fast_n")),
  baseline = ledgr_ind_sma(20)
)
```

Concrete entries resolve identically for every candidate and are shared through
the grid-level concrete-feature union. Only entries containing parameter
references vary by candidate alias map.

For unresolved parameterized declarations:

- `ledgr_feature_id()` fails with a classed error;
- unresolved bundles cannot expose concrete output feature IDs;
- construction validates declaration shape but not candidate values;
- resolution with concrete params produces ordinary concrete indicators and
  concrete feature IDs.

When a run or sweep candidate has an active alias map:

```r
ctx$features("SPY")
```

returns a named numeric vector keyed by strategy-facing aliases. It should be
usable with:

```r
passed_warmup(ctx$features("SPY"))
```

Existing access forms remain valid:

```r
ctx$feature("SPY", "sma_20")
ctx$features("SPY", static_feature_map)
```

If no active alias map exists, `ctx$features(id)` fails loudly with a classed
error. It must not silently return all concrete features. The error should
direct users to exact-ID lookup or explicit feature-map lookup.

For single-output indicator entries, the `ledgr_feature_map()` alias becomes
the strategy-facing alias. For example,
`fast = ledgr_ind_sma(ledgr_param("fast_n"))` exposes `fast` through
`ctx$features(id)`. Bundle entries are different: they use the bundle's
generated flat output aliases, while the feature-map entry name identifies the
bundle declaration at authoring time.

### Bundle Semantics

Parameterized bundles resolve before bundle materialization. After resolution,
bundles flatten to ordinary concrete single-output indicators as they do today.
Parameterized bundle resolution must also preserve concrete feature identity:
if two candidate declarations produce the same flat bundle alias but different
parameter values, the resolved concrete feature IDs must be parameter-distinct
or the resolver must fail with an action-oriented classed error. The
strategy-facing alias may remain flat per candidate, but the concrete
projection cannot contain two different features with the same concrete ID.

The first pass preserves flat generated bundle aliases. For example:

```r
features <- ledgr_feature_map(
  bands = ledgr_ind_ttr_outputs(
    "BBands",
    input = "close",
    n = ledgr_param("bb_n")
  )
)
```

`ctx$features("SPY")` returns the ordinary flat bundle aliases generated by the
bundle contract, such as `bbands_dn` and `bbands_up`. It does not return
`bands`, `bands_dn`, or nested values. The `bands` entry name identifies the
map entry at authoring time; resolved strategy-facing aliases for bundle
outputs remain the flat bundle output aliases.

The first pass does not introduce nested return shapes such as:

```r
x[["bands"]][["up"]]
```

Nested bundle namespaces remain future work.

### Demo Strategy Teaching Fixture

Add:

```r
ledgr_demo_sma_crossover_strategy()
```

The helper returns a Tier-1 strategy function intended for documentation,
examples, and smoke tests. It should:

- call `ctx$features(id)` and expect active aliases named `fast` and `slow`;
- guard mapped feature values with `passed_warmup()`;
- read only strategy-runtime parameters from `params`, with first-pass
  required names `qty` and `threshold`;
- loop over `ctx$universe`;
- return a full named numeric target vector from `ctx$flat()`;
- avoid external helper calls, dynamic feature construction, global state, and
  non-deterministic inputs.

For each instrument, the strategy should remain flat until both aliases have
passed warmup. After warmup, it should target `params$qty` when
`(fast / slow) - 1` is greater than `params$threshold`; otherwise it should
remain flat.

The parameter contract is part of the public teaching surface:

- `params$qty`: numeric scalar target quantity when the signal is active;
- `params$threshold`: numeric scalar minimum fast/slow spread required before
  the strategy goes long.

Changing these names requires updating README, getting-started, sweeps, and
strategy-development documentation in the same release.

The intended behavior is:

```r
strategy <- ledgr_demo_sma_crossover_strategy()
```

with explicit feature declarations:

```r
features <- ledgr_feature_map(
  fast = ledgr_ind_sma(ledgr_param("fast_n")),
  slow = ledgr_ind_sma(ledgr_param("slow_n"))
)
```

The demo strategy requires an active alias map with aliases named `fast` and
`slow`. Calling it with a static feature set, with no `feature_params`, or with
a feature map that resolves different aliases should fail through the same
classed errors as ordinary active-alias lookup, such as
`ledgr_no_active_alias_map` or the relevant unknown-alias / missing-parameter
error. Documentation should tell users to verify that their feature map uses
`ledgr_param()` and that `feature_params` were supplied at run or sweep time.

Do not add `ledgr_demo_sma_crossover_features()` in the first pass. Hiding the
feature map would hide the active-alias concept that this release is meant to
teach. If a future onboarding surface needs a fully bundled turnkey demo, it
should be evaluated separately after the active-alias docs land.

Reference documentation must describe the helper as a deterministic teaching
fixture. It must not frame it as a recommended trading strategy or as a strategy
library surface.

---

## 4. Grid Helper Scope

`ledgr_param_grid()` remains the low-level explicit contract for existing
sweep code. v0.1.8.4 adds a clearer public UX for active aliases by separating
feature parameters from strategy parameters before composing executable
candidates.

### `ledgr_feature_grid()`

Feature grids define values used only to materialize parameterized feature
declarations:

```r
feature_grid <- ledgr_feature_grid(
  fast_n = c(10L, 20L, 50L),
  slow_n = c(40L, 80L, 200L),
  .filter = fast_n < slow_n
)
```

Rules:

- each named argument supplies feature parameter values;
- scalar constants are recycled across combinations;
- values must be JSON-safe scalar or atomic-vector inputs that can become
  scalar feature parameter values after expansion;
- `NULL`, functions, environments, data frames, and nested lists are not valid
  cross-product values in the first pass;
- `NA` values are allowed when they are intentional candidate parameter values
  and survive existing JSON-safe parameter validation;
- vector arguments are crossed in deterministic argument order;
- generated rows become ordinary feature-parameter lists;
- output is a feature-grid object;
- row labels are deterministic and collision-checked;
- `.filter` is optional and is evaluated only against generated candidate
  parameter columns;
- `.filter` must evaluate to a logical vector of length one or length equal to
  the candidate table;
- `.filter` may reference parameter column names from the grid;
- `.filter` may use R primitive operators such as `<`, `>`, `==`, `!=`, `&`,
  `|`, and `!`;
- `.filter` may use base/recommended R functions when they are resolved from
  their package namespace, such as `abs()`, `log()`, `min()`, and `max()`;
- `.filter` must not call user-defined functions, ledgr-exported helpers, or
  read global state. Unknown symbols fail at construction with a classed error;
- `.filter` is a feature-grid construction filter, not a strategy-execution
  DSL.

The first implementation should keep `.filter` deliberately narrow. If a user
needs complex filtering, they can construct explicitly named feature-grid rows
or use a later helper after the grid object exists.

### `ledgr_strategy_grid()`

Strategy grids define values passed to `strategy(ctx, params)`:

```r
strategy_grid <- ledgr_strategy_grid(
  threshold = c(0.00, 0.01),
  qty = c(50L, 100L)
)
```

Rules:

- each named argument supplies strategy parameter values;
- scalar constants are recycled across combinations;
- values follow the same JSON-safe scalar/atomic rules as feature grids;
- output is a strategy-grid object;
- row labels are deterministic and collision-checked;
- `.filter` may be supported with the same narrow expression contract as
  `ledgr_feature_grid()`, but it evaluates only against strategy parameter
  columns.

`ledgr_strategy_grid()` may share implementation with `ledgr_param_grid()`, but
the public meaning is narrower: these values are strategy-function inputs, not
feature materialization inputs.

### `ledgr_grid_cross()`

`ledgr_grid_cross()` composes feature and strategy grids into executable sweep
candidates:

```r
grid <- ledgr_grid_cross(
  features = feature_grid,
  strategy = strategy_grid
)
```

Rules:

- `features` must be a feature-grid object, or omitted for one empty
  feature-parameter row;
- `strategy` must be a strategy-grid / `ledgr_param_grid` object, or omitted
  for one empty strategy-parameter row if the strategy accepts empty params;
- the output is an executable grid accepted by `ledgr_sweep()` and
  `ledgr_precompute_features()`;
- each executable candidate stores `feature_params`, `strategy_params`, a
  composed candidate label, and later the resolved alias map;
- `strategy(ctx, params)` receives `strategy_params` only;
- feature resolution receives `feature_params` only;
- feature and strategy parameter names may overlap because they live in
  separate namespaces;
- candidate labels must make both source rows inspectable, for example
  `feature_label / strategy_label` or another stable equivalent;
- users are strongly encouraged to name feature-grid and strategy-grid rows
  explicitly when composing grids. Auto-generated hash labels are stable but
  can compose into unfriendly identifiers;
- first-pass `ledgr_grid_cross()` does not need a cross-namespace `.filter`.
  Cross-namespace structural constraints remain future work or can be expressed
  through explicitly named executable candidates.

Omitted-grid examples:

```r
ledgr_grid_cross(strategy = strategy_grid)
ledgr_grid_cross(features = feature_grid)
```

Omitting one side creates one empty row for that namespace. Calling
`ledgr_grid_cross()` with both sides omitted is invalid; users who need a
single empty candidate should use `ledgr_param_grid(candidate = list())` or an
explicit named executable candidate.

This split is the recommended v0.1.8.4 UX. The old flat `ledgr_param_grid()`
remains available for non-parameterized features and legacy explicit sweep
code, but active-alias documentation should not teach feature and strategy
parameters as one flat public namespace.

Implementation note: `ledgr_strategy_grid()` should return an object that also
inherits from `ledgr_param_grid` for compatibility with existing checks and
dispatch. `ledgr_feature_grid()` and executable grids should use distinct
classes so code cannot accidentally pass feature-parameter rows as strategy
params.

### `ledgr_grid_named()`

Readable wrapper for explicitly specified executable candidates:

```r
grid <- ledgr_grid_named(
  conservative = list(
    feature = list(fast_n = 10L, slow_n = 80L),
    strategy = list(threshold = 0.01, qty = 50L)
  ),
  aggressive = list(
    feature = list(fast_n = 50L, slow_n = 200L),
    strategy = list(threshold = 0.00, qty = 200L)
  )
)
```

Rules:

- labels are supplied names;
- each entry contains a `feature` list, a `strategy` list, or both;
- missing `feature` or `strategy` means an empty parameter list for that
  namespace;
- output is the same executable grid shape returned by `ledgr_grid_cross()`;
- duplicate labels fail with a classed error;
- unnamed entries are not allowed in `ledgr_grid_named()`.

The legacy flat named-list shape remains available through
`ledgr_param_grid()` for existing non-parameterized sweeps. The nested
`feature` / `strategy` shape above is the documented path for active-alias
sweeps.

### `ledgr_grid_add_baseline()`

Append explicitly named baseline candidates:

```r
grid <- ledgr_grid_add_baseline(
  grid,
  flat = list(
    feature = list(fast_n = 10L, slow_n = 40L),
    strategy = list(threshold = 0.00, qty = 0L)
  )
)
```

Here `qty = 0L` makes the baseline flat; `threshold` is still supplied because
the demo strategy's parameter contract requires it.

Rules:

- input must be an executable grid;
- added entries must be named executable candidate specs with `feature` and/or
  `strategy` parameter lists;
- multiple baselines may be added in one call through named `...` arguments;
- output is an executable grid;
- duplicate labels fail;
- duplicate parameter rows are allowed if labels differ, because labels are
  candidate names, not identity hashes.

### No Ranking Or Tuning Semantics

Grid helpers only create candidate parameter sets. They do not:

- rank candidates;
- choose winners;
- define objectives;
- promote runs;
- perform random, Bayesian, adaptive, or sequential search;
- imply `ledgr_tune()` semantics.

Candidate ranking remains future UX work.

---

## 5. Parameter Introspection And Validation

Add:

```r
ledgr_parameters(features)
```

For:

```r
features <- ledgr_feature_map(
  fast = ledgr_ind_sma(ledgr_param("fast_n")),
  slow = ledgr_ind_sma(ledgr_param("slow_n"))
)
```

minimum stable columns are:

- `param_name`;
- `alias`;
- `argument`.

Use one row per parameter reference. A parameter used by two aliases produces
two rows.

The first pass does not add ranges, priors, distributions, objectives, or
finalization metadata.

`ledgr_sweep()` and `ledgr_precompute_features()` should validate that each
candidate's feature-parameter row supplies the parameter references required by
the experiment's parameterized feature declaration. A small explicit checker
may also be added if it materially improves documentation or error messages,
but the runtime entry points must not rely on users calling it manually.

Parameter-completeness validation happens before candidate execution or
precompute starts. Missing required feature parameters fail with a classed
error that names the missing parameter and the alias/argument that requires it.
Non-scalar feature-parameter values fail during resolution with a classed
error. Feature parameters not referenced by the declaration are allowed but
should be reported by inspection helpers as unused feature parameters.

Strategy parameters live in the strategy namespace. They are passed to
`strategy(ctx, params)` and are not used for feature resolution. Feature
parameters are not passed to the strategy unless a future spec explicitly adds
an inspection surface for them inside the pulse context.

---

## 6. Runtime Resolution

The flow is:

1. `ledgr_feature_map()` stores an authored declaration.
2. `ledgr_experiment(features = ...)` stores the declaration without resolving
   it.
3. `ledgr_run()` resolves once using concrete `feature_params` and calls the
   strategy with concrete `params`.
4. `ledgr_sweep()` resolves once per executable candidate using that
   candidate's `feature_params` and calls the strategy with that candidate's
   `strategy_params`.
5. Concrete feature computation is unioned across the grid through the
   v0.1.8.3 projection/precompute path.
6. The fold receives ordinary concrete feature definitions plus the active
   alias map for the current run or candidate.
7. `ctx$features(id)` reads the current pulse's values by alias.

This preserves the one-execution-engine rule. Active aliases do not add a
second run path, a second feature engine, or per-candidate duplicate concrete
feature computation where concrete features are shared.

Single-run UX should preserve this split:

```r
bt <- ledgr_run(
  exp,
  strategy = strategy,
  feature_params = list(fast_n = 10L, slow_n = 40L),
  params = list(threshold = 0.01, qty = 100L)
)
```

`params` remains the strategy-parameter argument. `feature_params` is the
feature-materialization argument for active parameterized feature declarations.
Existing non-parameterized runs can continue to omit `feature_params`.

Sweep result rows should preserve the namespace split:

- `params` remains the public strategy-parameter column for compatibility with
  existing sweep-result inspection patterns;
- `feature_params` is added for feature-materialization parameters when active
  aliases are used;
- executable-grid internals may call the strategy namespace
  `strategy_params`, but public result rows should expose that namespace as
  `params` only. Do not require users to read both `params` and
  `strategy_params`;
- failed-candidate inspection should expose both the strategy params and the
  feature params that were used when resolving the candidate;
- provenance should include the resolved alias map and `alias_map_hash` so
  users can connect feature params to concrete feature IDs.

---

## 7. Identity And Provenance

Resolved alias maps are execution interface. They can change what the strategy
reads and therefore belong in execution identity.

First-pass hash contract:

- `config_hash`: includes the resolved alias map unconditionally.
- `feature_set_hash`: remains concrete-feature-only.
- `alias_map_hash`: add as a separate provenance hash.
- concrete feature fingerprints: unchanged.
- strategy fingerprint: unchanged.
- execution seed derivation: unchanged unless a future ticket identifies a
  concrete need.

Store three audit layers:

```text
authored declaration: fast = SMA(n = param fast_n)
resolved alias map:   fast -> sma_20
concrete feature:     sma_20 fingerprint ...
```

Recommended storage names:

- `alias_map_json`
- `alias_map_hash`
- `alias_map_version`

The implementation should mirror the metric-context storage pattern where
practical: write records at run/candidate creation, read them through accessors,
and verify stored hashes against reconstructed records.

---

## 8. Documentation Scope

The main teaching path belongs in `vignettes/sweeps.Rmd`.

The sweeps vignette should teach:

1. minimal sweep recap;
2. parameterized feature aliases with `ledgr_param()`;
3. the feature-grid versus strategy-grid mental model;
4. grid construction with `ledgr_feature_grid()`, `ledgr_strategy_grid()`,
   and `ledgr_grid_cross()`;
5. `.filter` for structural constraints inside a feature or strategy grid;
6. the demo SMA-crossover strategy as the first runnable sweep strategy;
7. strategy alias lookup through `ctx$features(id)`;
8. warmup guarding with `passed_warmup()`;
9. `ledgr_parameters(features)` inspection;
10. alias-map provenance and failed-candidate inspection;
11. explicit non-goals: no ranking, winner selection, tuning objective, or
    conditional feature factories inside strategies.

Pulse debugging and feature inspection must also speak the new naming
convention:

- The intended inspection shape is:

```r
pulse <- ledgr_pulse_snapshot(
  snapshot,
  universe = "SPY",
  ts_utc = "2020-02-12T00:00:00Z",
  features = parameterized_feature_map,
  feature_params = list(fast_n = 10L, slow_n = 40L)
)
```

- `ledgr_pulse_snapshot()` should accept concrete `feature_params` when
  inspecting parameterized feature declarations.
- `ledgr_pulse_features()` should be able to show both strategy-facing alias
  and resolved concrete feature ID for active aliases.
- `ledgr_pulse_wide()` should provide an alias-keyed view when a feature map or
  active alias map is available, while keeping exact concrete-feature
  inspection possible.
- Pulse debug output should distinguish feature parameters from strategy
  parameters. It should not present one flat params list for active-alias
  candidates.
- Error messages for unresolved pulse-debug feature params should name the
  missing feature parameter and the alias/argument that requires it.

Secondary documentation:

- `README.Rmd`: use the demo SMA-crossover strategy as the compact first
  contact with active aliases, feature grids, strategy grids, and
  `ledgr_grid_cross()`. Keep the feature map explicit; do not hide it behind a
  demo feature helper.
- `vignettes/getting-started.Rmd`: use the same demo strategy for the first
  complete run or sweep, then point to `vignettes/sweeps.Rmd` for the full
  grid mental model.
- `vignettes/strategy-development.Rmd`: point users away from feature factories
  inside strategies and toward active aliases for parameterized indicators.
  Start from the demo strategy, then show its equivalent expanded strategy body
  so users learn how to write custom strategies.
- `vignettes/indicators.Rmd`: explain `ledgr_param()` in supported indicator
  constructors using the same `fast` / `slow` aliases where practical, but keep
  the article focused on indicator declaration rather than demo-strategy use.
- pulse-debug examples in strategy-development or indicators docs should use
  the same alias names as the sweep examples, and should show the resolved
  concrete feature IDs only as inspection/provenance detail.
- `vignettes/experiment-store.Rmd`, `vignettes/reproducibility.Rmd`,
  `vignettes/metrics-and-accounting.Rmd`, `vignettes/leakage.Rmd`, and
  `vignettes/custom-indicators.Rmd`: do not convert wholesale. These articles
  teach storage, preflight, accounting, leakage, and custom-indicator contracts;
  mention or link the demo strategy only when it clarifies the active-alias
  path without obscuring the article's primary contract.
- Reference help: document all new helpers and classed error behavior.

---

## 9. Verification Requirements

Ticket cut should include tests for:

- `ledgr_param()` construction, printing, serialization, and validation.
- Rejection of missing, empty, non-string, or unsupported parameter references.
- Supported constructor integration for the first-pass constructor set.
- Rejection of unsupported parameter-reference placements.
- `ledgr_feature_id()` failure on unresolved declarations and unresolved
  bundles.
- Resolution to concrete indicators and ordinary concrete feature IDs.
- `ledgr_parameters(features)` output shape and duplicated-reference behavior.
- `ledgr_feature_grid()` cross-product behavior, scalar recycling,
  deterministic labels, duplicate handling, JSON-safe feature params, and
  `.filter`.
- `ledgr_strategy_grid()` cross-product behavior, scalar recycling,
  deterministic labels, duplicate handling, JSON-safe strategy params, and
  optional `.filter`.
- `ledgr_grid_cross()` composition of feature and strategy grids, including
  separate `feature_params` and `strategy_params` namespaces, composed labels,
  and omitted-grid empty-row behavior.
- `ledgr_grid_named()` executable-candidate validation with `feature` and
  `strategy` parameter namespaces.
- `ledgr_grid_add_baseline()` append behavior and duplicate-label failures.
- `ledgr_demo_sma_crossover_strategy()` returns a Tier-1-compatible function
  that uses active aliases `fast` and `slow`, guards warmup with
  `passed_warmup()`, reads strategy params `qty` and `threshold`, and returns a
  full named numeric target vector.
- Demo strategy preflight is pinned explicitly:

```r
result <- ledgr_strategy_preflight(ledgr_demo_sma_crossover_strategy())
testthat::expect_identical(result$tier, "tier_1")
testthat::expect_true(result$allowed)
testthat::expect_length(result$unresolved_symbols, 0L)
```

- `ledgr_run()` active alias map availability through `ctx$features(id)` with
  `feature_params` used for resolution and `params` passed to the strategy.
- `ledgr_sweep()` per-candidate alias maps and provenance with separate
  feature and strategy parameter namespaces.
- `passed_warmup(ctx$features(id))` works for active alias vectors.
- Pulse debugging accepts parameterized feature declarations plus
  `feature_params`, and inspection views show alias and concrete feature ID
  without collapsing feature and strategy params into one namespace.
- Classed error when `ctx$features(id)` is called without an active alias map.
- Existing exact-ID lookup and explicit feature-map lookup behavior remains
  unchanged.
- `config_hash` changes when only alias names change.
- `feature_set_hash` remains unchanged when concrete features are unchanged.
- `alias_map_hash` changes when alias mappings change.
- Flat bundle alias behavior with parameterized bundle constructors, including
  a multi-candidate case where the same strategy-facing bundle aliases resolve
  from different bundle parameter values without concrete feature-ID collision.
- Existing concrete feature fingerprint pins remain stable.
- Documentation contract tests for the new authoring pattern.

New error messages must be action-oriented. They should name the relevant
parameter, alias, feature, or grid label, and should suggest the corrective
action where that action is unambiguous.

The auditr-routed verification additions are the parameterized bundle identity
case above, sweep print-footer behavior after reordering, and preflight
message-ordering coverage for global assignment.

---

## 10. Ticket-Cut Notes

The first ticket cut should probably split work into:

1. `ledgr_param()` declaration objects and constructor integration.
2. Resolution to concrete indicators and parameter introspection, including the
   auditr-routed parameterized bundle output identity constraint.
3. Grid helper construction (`ledgr_feature_grid()`, `ledgr_strategy_grid()`,
   `ledgr_grid_cross()`, `ledgr_grid_named()`, `ledgr_grid_add_baseline()`).
4. Active alias runtime lookup in `ledgr_run()` and `ledgr_sweep()`.
5. Pulse-debug and feature-inspection updates for active alias naming and
   feature/strategy parameter namespaces.
6. Demo SMA-crossover strategy helper plus documentation examples that use it
   without hiding explicit feature declarations.
7. Alias-map identity/provenance storage and accessors.
8. Primary documentation path: README, getting-started, sweeps,
   strategy-development, and indicators updates.
9. Documentation guardrails: confirm experiment-store, reproducibility,
   metrics-and-accounting, leakage, and custom-indicators are not converted
   wholesale to the demo strategy.
10. Auditr-routed bug/docs/message tickets:
   - sweep print footer after reordering;
   - preflight global-assignment message ordering;
   - runnable sweeps script listing / docs discovery;
   - bounded docs/message polish from `auditr_intake_synthesis.md`.
11. Warmup guard documentation cleanup: use `passed_warmup()` as the canonical
    feature-vector warmup guard instead of ad hoc `!is.na(...)` examples.
12. Release gate.

Broader workflow-documentation themes from auditr are explicitly deferred to
v0.1.8.5's canonical workflow cycle.
