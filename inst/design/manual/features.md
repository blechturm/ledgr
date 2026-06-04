# Features, Aliases, And Runtime Lookup


**Status:** Reviewable maintainer-manual article for LDG-2543.

**Authority:** Synthesis plus implementation trace. Binding execution
contracts remain in `../contracts.md`, accepted RFC rows in
`../rfc/README.md`, and the active packet in
`../ledgr_v0_1_8_11_spec_packet/v0_1_8_11_spec.md`, Section 3.7.

This article explains how feature declarations become runtime pulse
values. It does not create new feature contracts, public API, or
implementation scope.

> [!WARNING]
>
> ### Synthesis, Not New Authority
>
> Feature maps and aliases are convenience and traceability tools. The
> execution contract remains no-lookahead pulse evaluation over sealed
> snapshot data, with functional strategies returning full named numeric
> target vectors.

## The Short Version

Feature values flow through one path:

1.  A user declares indicators or a `ledgr_feature_map()`.
2.  `ledgr_experiment()` materializes concrete feature definitions and
    alias storage.
3.  Optional `ledgr_precompute_features()` builds reusable feature
    projections for a sweep grid.
4.  The fold builds pulse contexts with scalar `ctx$feature()` and
    alias-vector `ctx$features()` helpers.
5.  Strategies read current-pulse feature values only.

The model is intentionally explicit:

- `ctx$feature(instrument_id, feature_id)` looks up one concrete feature
  ID.
- `ctx$features(instrument_id, feature_map)` returns an alias-keyed
  numeric vector for the supplied feature map.
- `ctx$features(instrument_id)` works only when the run has an active
  alias map.
- Warmup is represented as `NA`, not as a hidden fill or silent
  substitution.

## Why Feature Maps Exist

Feature-heavy strategies should not need to repeat opaque feature IDs in
three places: declaration, experiment registration, and pulse lookup. A
feature map binds a stable alias to each concrete feature definition, so
strategy code can refer to domain names such as `fast`, `slow`, `rsi`,
or `bb_up` while ledgr still tracks concrete indicator IDs and
fingerprints.

Example shape:

``` r
features <- ledgr_feature_map(
  fast = ledgr_ind_sma(20),
  slow = ledgr_ind_sma(50)
)

strategy <- function(ctx, params) {
  x <- ctx$features("AAA", features)
  targets <- ctx$flat()
  targets[["AAA"]] <- if (!anyNA(x) && x[["fast"]] > x[["slow"]]) 1 else 0
  targets
}
```

The aliases improve strategy readability. The concrete feature IDs and
fingerprints preserve deterministic provenance.

## Experiment Materialization

`ledgr_experiment()` accepts feature definitions as a list, feature
factory, or feature map. Materialization resolves the feature input into
concrete indicator definitions plus alias storage. For feature maps,
active aliases are normalized and stored as canonical JSON, SHA-256
hash, version, and original alias order.

This matters for two reasons:

- pulse contexts can expose `ctx$features(instrument_id)` without
  requiring the strategy to pass the feature map again;
- sweep candidates can carry alias-map provenance in compact candidate
  rows.

## Precompute And Projection

`ledgr_precompute_features()` is the sweep-side reuse layer. It resolves
each candidate’s feature definitions, builds a deduplicated feature
union, computes feature payloads, and records per-candidate feature rows
with fingerprints and alias-map storage.

The precomputed object is accepted only if it still matches the current
experiment and grid. Snapshot hash, universe, scoring range, grid
labels, feature engine version, candidate parameter hashes, and required
feature fingerprints are all checked before use.

When a runtime projection is available, pulse helpers can read from
matrix-like projection storage instead of a per-pulse long feature
table. The public lookup surface stays the same.

## TTR Adapters

TTR indicators use `ledgr_ind_ttr()`. The adapter normalizes the TTR
function, input selection, output selection, static args, and warmup
rule into a normal ledgr indicator object. Multi-output TTR functions
require an explicit output selection so feature IDs and values stay
deterministic.

TTR is an adapter mechanism, not a separate feature engine. Once
constructed, the indicator participates in the same feature-definition
validation, fingerprinting, projection, and pulse lookup paths as
ledgr-native indicators.

## Runtime Lookup

During fold execution, each pulse context receives feature helpers:

- `ctx$feature()` for scalar exact-ID lookup;
- `ctx$.feature_vector()` for internal vector lookup;
- `ctx$features()` for alias-keyed feature-map lookup;
- `ctx$features_wide()` for inspection-style wide feature views.

The scalar accessor validates instrument and feature IDs, returns the
current pulse value when present, and returns the configured default for
absent values. The alias-vector accessor validates the alias map, checks
that each requested feature resolves to a scalar numeric value, and
returns a named vector keyed by alias.

Missing feature IDs fail loudly. Warmup values are legitimate `NA`
values and are left for strategy logic to handle.

## Implementation Trace

This section follows the two-layer manual standard in the active
v0.1.8.11 spec, Section 3.7. It describes the current implementation and
its code anchors; it does not authorize new behavior.

### Data Structures

| Runtime object | Shape | Key fields |
|----|----|----|
| `ledgr_indicator` | list-like indicator definition | `id`, `fn`, `series_fn`, `requires_bars`, `stable_after`, `params`, `source` |
| `ledgr_feature_map` | list with aliases and indicators | `aliases`, `indicators`, `feature_ids` |
| alias map | named character vector | names are aliases, values are concrete feature IDs |
| alias storage | list persisted into configs/provenance | `alias_map_json`, `alias_map_hash`, `alias_map_version`, `alias_map_order` |
| materialized feature result | experiment-time list | `features`, `alias_map`, `alias_map_json`, `alias_map_hash`, `alias_map_version` |
| `ledgr_precomputed_features` | sweep feature artifact | snapshot hash, universe, ranges, grid labels, feature union, candidate features, projection, warmup |
| runtime projection | matrix-backed feature payload | instrument index, feature IDs, feature value matrices |
| pulse context | per-pulse list | `feature_table`, `.feature_projection`, `.feature_pulse_idx`, `.feature_ids`, `active_alias_map`, feature helper closures |

Alias storage is canonicalized by sorting aliases, serializing a payload
of `alias_map_version` plus `mappings`, and hashing the canonical JSON
with SHA-256. The original alias order is kept separately for
user-facing order.

### Code Anchors

| Boundary | Anchor |
|----|----|
| Feature-map construction and duplicate feature-ID validation | `R/feature-map.R:52-127` |
| Alias validation for feature maps | `R/feature-map.R:129-160` |
| Feature-map parameterization and resolution | `R/feature-map.R:162-175` |
| Feature-map object validation | `R/feature-map.R:177-239` |
| Experiment feature validation | `R/experiment.R:350-368` |
| Experiment feature materialization and alias storage | `R/experiment.R:388-426` |
| Feature-factory grid guard | `R/experiment.R:435-464` |
| Feature engine definition validation and built-ins | `R/features-engine.R:1-170` |
| Feature engine version and feature cache keys | `R/feature-cache.R:1-132` |
| Feature cache get/set | `R/feature-cache.R:153-168` |
| Precompute object construction | `R/precompute-features.R:41-85` |
| Precompute validation | `R/precompute-features.R:107-182` |
| Candidate feature resolution and alias provenance | `R/precompute-features.R:283-374` |
| Feature-set hash | `R/precompute-features.R:400-409` |
| Feature definitions from indicators | `R/precompute-features.R:420-457` |
| Payload, projection, and warmup assembly | `R/precompute-features.R:470-532` |
| Alias-map canonical JSON and SHA-256 hash | `R/feature-alias-map.R:26-52` |
| Alias-map restoration from config JSON | `R/feature-alias-map.R:56-87` |
| Runtime alias lookup map | `R/feature-alias-map.R:90-110` |
| Pulse-context scalar and bundle accessors | `R/pulse-context.R:54-137` |
| Feature helper attachment and projection-backed fast path | `R/pulse-context.R:262-324` |
| Fast context-state helper reuse | `R/pulse-context.R:351-414` |
| Projection-backed bundle lookup | `R/runtime-projection.R:437-512` |
| Pulse inspection rows and active alias maps | `R/feature-inspection.R:271-380` |
| TTR adapter construction and normalization | `R/indicator-ttr.R:110-240`, `R/indicator-ttr.R:459-496` |
| TTR warmup, deterministic IDs, execution, and output selection | `R/indicator-ttr.R:533-558`, `R/indicator-ttr.R:594-611`, `R/indicator-ttr.R:621-678`, `R/indicator-ttr.R:781-820` |

### Resolution Chain

The runtime chain is:

1.  `ledgr_experiment()` validates the `features` argument.
2.  `ledgr_experiment_materialize_features()` resolves feature factories
    and feature maps into concrete feature definitions.
3.  `ledgr_alias_map_storage()` stores active aliases as canonical JSON
    plus hash and version.
4.  The fold builds pulse contexts with `active_alias_map` and either a
    long feature table or runtime projection.
5.  `ledgr_attach_feature_helpers()` attaches scalar and bundle
    accessors.
6.  `ctx$feature(instrument_id, feature_id)` calls the scalar accessor.
7.  `ctx$features(instrument_id, feature_map)` or
    `ctx$features(instrument_id)` resolves an alias map, calls scalar
    lookup for each concrete feature ID, and returns alias-keyed numeric
    values.

If a projection exists, steps 5 to 7 use projection-backed helpers. If
not, the same public helpers read from the long feature table on the
pulse context.

### Feature Cache Keys

The in-memory feature cache is keyed by:

- snapshot hash;
- instrument ID;
- feature fingerprint;
- feature engine version;
- start and end timestamps.

The key is encoded as a `ledgr_feature_cache_v2` string with
length-prefixed fields. Feature fingerprints include the indicator ID,
function references, series function references, `requires_bars`,
`stable_after`, and stable params. The feature engine version is a hash
over the relevant feature-engine function sources.

The cache is process-local. It is a reuse optimization and does not
replace snapshot hashing, feature fingerprinting, or precomputed-feature
validation.

### Alias Map Dispatch

`ledgr_feature_lookup_map()` has three modes:

- no argument: use the active alias map from the run configuration and
  fail if none exists;
- named character vector: normalize and use that vector directly;
- feature-map object: validate the object and derive concrete feature
  IDs.

This is why both of these are valid when an active alias map exists:

``` r
ctx$features("AAA")
ctx$features("AAA", features)
```

The first form is shorter but requires the experiment’s active alias
map. The second form is explicit and works from the supplied feature
map.

### TTR Adapter Mechanism

`ledgr_ind_ttr()` requires TTR at construction time, normalizes the
function and arguments, computes or validates the warmup rule, and
constructs a deterministic indicator ID. Execution builds the TTR input
from bars, invokes the TTR function, and selects a scalar output column
or vector. If the TTR result has multiple outputs and the caller did not
select one, the adapter fails loudly.

### Edge Cases

Fail-loud cases:

- duplicate feature-map aliases or invalid alias names;
- duplicate concrete feature IDs in a feature map;
- invalid feature definitions or missing indicator functions;
- feature factory grids paired with separate `feature_params` where the
  active feature-grid helpers are required instead;
- missing active alias map for `ctx$features(instrument_id)`;
- unknown instrument IDs in scalar or bundle lookup;
- unknown feature IDs in scalar, bundle, or inspection lookup;
- non-scalar or non-numeric feature values returned through
  `ctx$features()`;
- precomputed-feature mismatch on snapshot, universe, range, grid
  labels, engine version, params hash, or required fingerprints;
- multi-output TTR adapters without explicit output selection.

Silent or non-failing cases:

- warmup values are `NA`;
- scalar lookup can return the configured default for absent values;
- empty feature tables can be valid when no feature values are
  requested.

Not certified by this article:

- point-in-time external regressors;
- broad feature-store persistence;
- compiled feature engines;
- live data-provider adapters.

### Hot And Cold Paths

Cold/setup path:

- indicator and feature-map construction;
- experiment materialization;
- alias-map canonical JSON and hash generation;
- precomputed-feature validation and projection assembly;
- feature-cache key creation.

Hot/pulse path:

- scalar `ctx$feature()` lookup;
- alias-vector `ctx$features()` lookup;
- projection-backed value reads;
- strategy warmup decisions based on `NA` values.

The implementation keeps the pulse hot path small by attaching reusable
helper closures and, when available, reading projection matrices instead
of rebuilding long feature tables per pulse.

### Concrete Inspection Example

The same feature map can be inspected outside the strategy path:

``` r
pulse <- ledgr_pulse_snapshot(exp, at = 3)
ledgr_pulse_features(pulse, features)
```

The inspection helper returns rows with `ts_utc`, `instrument_id`,
`feature_id`, `feature_value`, and alias information when an alias map
is supplied or active. The inspection surface is read-only; it does not
mutate snapshot or run tables.

## Where Next

- Use `sweep.qmd` for sweep candidate provenance, precomputed feature
  use in candidate grids, and promotion.
- Use `execution_fold_core.qmd` for pulse context construction and fold
  entry.
- Use `observability_determinism.qmd` for feature fingerprints, config
  hashes, closure hashes, and parallel determinism.
- Use `snapshots_data.qmd` for snapshot sealing and fold-entry data
  guards.
