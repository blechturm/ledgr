# RFC Response: Strategy Authoring For Parameterized Indicators

**Status:** Reviewer response - docs-only recommendation not sufficient.
**Date:** 2026-05-25
**RFC:** `inst/design/rfc/rfc_strategy_authoring_parameterized_indicators_v0_1_8_x.md`
**Reviewer:** Codex

---

## Overall Assessment

The RFC identifies a real UX gap, but its recommended Option A is too weak.
The package can already sweep indicator parameters, but the strategy-authoring
surface does not give users a clean way to read the candidate-specific features
by stable strategy-facing names.

The proposed documentation pattern:

```r
features <- function(params) {
  ledgr_feature_map(
    fast = ledgr_ind_sma(params$fast_n),
    slow = ledgr_ind_sma(params$slow_n)
  )
}

strategy <- function(ctx, params) {
  x <- ctx$features("AAA", features(params))
}
```

is not just inelegant. Under the current preflight contract, it is also the
wrong thing to recommend.

The strategy references `features`, an unqualified user helper function from
the surrounding environment. Current preflight classifies unresolved user
helper functions as Tier 3. That is deliberate: ledgr cannot recover arbitrary
file-level or interactive helper functions from stored run metadata. Resolved
external scalar values are Tier 2; external helper functions are not.
This is the current v0.1.8.2 contract after LDG-2303: `ledgr_run()` and
`ledgr_sweep()` reject Tier 3 strategies before execution artifacts are
created.

So the clean-looking "one factory, one strategy" pattern either fails preflight
or pushes users toward helper-capture semantics that ledgr has intentionally not
accepted. A documentation-only response would teach users a pattern that
conflicts with the reproducibility model.

Verdict: accept the problem statement, reject Option A as sufficient, and open
API design for active parameterized feature aliases.

---

## Critical Finding: The Recommended Pattern Breaks The Tier Contract

The current strategy preflight policy is:

- Tier 1: self-contained strategy logic using explicit `params`, base /
  recommended R references, and exported ledgr helpers;
- Tier 2: inspectable but user-managed external state, such as package-qualified
  dependencies or resolved immutable non-function closure objects;
- Tier 3: unresolved free symbols, user helper functions, forbidden
  nondeterminism, or global assignment.

In the RFC's Pattern 3 example, `features` is a function. It is neither an
exported ledgr helper nor a resolved immutable scalar. Therefore the strategy is
not Tier 1 or Tier 2 under the current contract.
Per LDG-2303, this failure happens at the strategy preflight layer, before the
strategy reaches functional-strategy fingerprinting or fold execution.

A mechanically valid Tier 1 version duplicates the feature declaration inside
the strategy:

```r
features <- function(params) {
  ledgr_feature_map(
    fast = ledgr_ind_sma(params$fast_n),
    slow = ledgr_ind_sma(params$slow_n)
  )
}

strategy <- function(ctx, params) {
  fmap <- ledgr_feature_map(
    fast = ledgr_ind_sma(params$fast_n),
    slow = ledgr_ind_sma(params$slow_n)
  )

  x <- ctx$features("AAA", fmap)
}
```

That is acceptable to the static analyzer, but it is poor API design. It makes
the user duplicate the research declaration and creates an obvious drift risk:
the experiment feature factory and the strategy lookup map can disagree.

The simpler built-in shortcut is currently cleaner:

```r
strategy <- function(ctx, params) {
  fast <- ctx$feature("AAA", paste0("sma_", params$fast_n))
  slow <- ctx$feature("AAA", paste0("sma_", params$slow_n))
}
```

But that couples strategy logic to feature ID conventions. It works for built
ins whose ID convention is public, but it is not the authoring model ledgr
should ask users to scale across custom indicators, adapters, and bundles.

---

## UX Finding: The Function-Wrapped Feature Map Is The Smell

The deeper UX gap is not only "users need docs for feature factories." It is
that users must remember to wrap `ledgr_feature_map()` in `function(params)` at
all:

```r
features <- function(params) {
  ledgr_feature_map(...)
}
```

This is a low-level materialization detail leaking into the authoring surface.
The user wants to declare:

```r
fast = SMA using params$fast_n
slow = SMA using params$slow_n
strategy reads fast and slow
```

Instead, today they must coordinate three separate things:

1. a feature factory that materializes concrete indicators for each candidate;
2. exact feature IDs or a reconstructed feature map inside the strategy;
3. preflight rules that reject the helper if the strategy calls the factory.

That is a real API gap. Documentation can explain the limitation, but it cannot
turn the current pattern into good code.

---

## Better Direction: Active Parameterized Feature Aliases

The desired user-facing shape is closer to:

```r
features <- ledgr_feature_map(
  fast = ledgr_ind_sma(ledgr_param("fast_n")),
  slow = ledgr_ind_sma(ledgr_param("slow_n"))
)

strategy <- function(ctx, params) {
  x <- ctx$features("AAA")
  if (x[["fast"]] > x[["slow"]]) {
    ...
  }
}
```

The exact spelling is open. `ledgr_param("fast_n")` is only an illustrative
placeholder. The important design move is that parameterized feature aliases
become first-class experiment metadata, not a helper function the strategy must
call.

This simple shape only covers parameter substitution into an otherwise fixed
feature declaration. It does not cover arbitrary user factory logic such as
choosing one indicator family in one regime and a different indicator family in
another. Conditional feature-factory structure remains a separate design
problem unless ledgr deliberately introduces a serializable declaration language
for that structure.

Under this model:

1. The experiment stores a feature-map declaration with strategy-facing aliases.
2. Candidate/run materialization resolves parameter references into ordinary
   concrete `ledgr_indicator` objects.
3. The engine still computes and caches ordinary single-output feature IDs and
   fingerprints.
4. The fold context receives an active alias map for the current run/candidate.
5. `ctx$features(instrument_id)` returns active mapped values by alias.
6. `ctx$feature(instrument_id, feature_id)` remains the exact-ID scalar
   accessor.

This removes the external helper call from strategy code. The strategy can stay
Tier 1 if it otherwise uses only `ctx`, `params`, base/recommended functions,
and exported ledgr helpers.

This also solves the "users must write a function around `ledgr_feature_map()`"
problem. Parameterization becomes part of the feature declaration rather than
the user manually writing a materializer.

---

## Required Design Constraints For The API Work

Any API work in this direction must preserve these constraints.

### Feature Identity Remains Concrete

Parameterized declarations are authoring objects. Before execution and
precompute, they must resolve to ordinary `ledgr_indicator` definitions with
ordinary feature IDs and fingerprints.

No runtime multi-output object. No second feature engine. No change to the
feature cache key shape.

### Aliases Are Strategy Runtime Interface

Aliases are not market-data identity, but they are part of the strategy-visible
runtime interface.

If `fast` and `slow` point to different feature IDs, swapping the aliases can
change strategy behavior even if the same concrete indicators exist. Therefore
the active alias map should be treated as execution configuration/provenance,
not as disposable display metadata.

The implementation must decide exactly how alias maps enter config JSON and
config hashes. The default assumption should be: if changing the alias map can
change strategy behavior, it belongs in execution identity.

### Plain Lists Keep Exact-ID Semantics

If `features` is a plain list, there is no alias map. In that case:

```r
ctx$features("AAA")
```

should fail with an explicit message telling users to either:

- use `ctx$feature("AAA", feature_id)` for exact-ID lookup; or
- supply features as a feature map / parameterized feature map when they want
  alias lookup.

### Existing `ctx$features(id, feature_map)` Remains Valid

The existing explicit map form should remain supported for backward
compatibility and for static feature-map strategies:

```r
ctx$features("AAA", mapped_features)
```

The new no-map form should be an addition, not a replacement.

### Bundle Alias Semantics Must Be Explicit

Bundle entries currently expand using generated feature IDs as aliases:

```r
ledgr_feature_map(
  bbands = ledgr_ind_ttr_outputs("BBands", input = "close", n = 20)
)
```

does not create one alias called `bbands`. It creates aliases like
`bbands_dn`, `bbands_mavg`, `bbands_up`, and `bbands_pctb`.

Any active alias-map API must preserve or deliberately redesign this behavior.
It cannot leave users guessing whether `x[["bbands"]]` or `x[["bbands_up"]]`
is the expected lookup.

### Parameter References Must Be Deterministic

If ledgr introduces parameter references such as `ledgr_param("fast_n")`, they
must be serializable, deterministic, and validated at materialization time.

They must not allow arbitrary expressions, I/O, provider lookups, RNG, clocks,
or mutable state inside feature construction. A parameterized feature
declaration should be data, not executable user code.

---

## Response To The RFC Options

### Option A: Documentation-Only Convention

Reject as sufficient.

Documentation is still needed, but it should document the current limitation
and the exact-ID fallback. It should not present `features(params)` inside the
strategy as the recommended clean pattern, because that conflicts with the
Tier 3 helper policy.

### Option B: `ctx$feature_map()`

Defer and redesign.

The pulse context does not currently hold the user's feature map. It holds
feature values keyed by engine feature IDs. Exposing `ctx$feature_map()` would
require threading alias metadata through experiment materialization, config,
precompute, sweep, and fold context. That is real API work, not a small
accessor.

The more useful API is probably not `ctx$feature_map()`, but active alias
lookup:

```r
ctx$features("AAA")
```

where the active alias map was supplied by experiment feature declaration.

### Option C: Implicit Default Feature Map

Reconsider only as part of the active-alias design.

The RFC rejects Option C because implicit lookup hides dependencies. That
concern is valid if the feature map is a hidden object. It is less valid if the
active alias map is explicit experiment metadata and printed / inspectable as
part of the run configuration.

Still, this should not be slipped in as a signature tweak. It needs a dedicated
design because it changes the strategy context contract.

---

## Recommended Next Step

Do not fold the RFC into LDG-2310 as a documentation-only patch.

Do not treat the active-alias direction as a small v0.1.8.2 add-on. It touches
experiment feature declaration, candidate/run materialization, config identity,
precompute and sweep candidate metadata, pulse-context helpers, bundle alias
semantics, and legacy-run compatibility. It needs its own design pass and
roadmap placement, likely in a future parameter-grid / strategy-authoring
quality-of-life cycle rather than the current release gate.

Instead:

1. Keep the RFC as the problem statement.
2. Treat this response as the design correction.
3. Open a synthesis or replacement RFC focused on "active parameterized feature
   aliases" before ticketing implementation.
4. Park the docs-only fallback as current-state guidance only, not as the
   desired end-state.

The API work is worth considering because it addresses a real authoring gap:
users should not have to duplicate feature declarations, remember to wrap
`ledgr_feature_map()` in `function(params)`, or choose between clean aliases and
preflight compatibility.

---

## What To Document Before The API Exists

Until a first-class API ships, documentation should be honest:

- built-in parameter sweeps can use exact IDs derived from `params`;
- `ledgr_feature_id(ledgr_ind_*(params$...))` is safer than hand-built strings
  when the constructor is cheap;
- feature-map aliases are cleanest for static maps;
- parameterized feature maps currently require either duplication inside the
  strategy or exact-ID lookup;
- calling an external feature factory from the strategy is not Tier 1/Tier 2
  under current preflight rules;
- bundle-backed sweeps can use stable output IDs when prefix/naming is stable,
  while fingerprints and provenance distinguish parameterizations.

LDG-2311 already covers the general rule that reusable file-level helper
functions are Tier 3 unless represented through an approved helper surface. The
remaining bridge-documentation gap is narrower: the strategy-development and
indicator/sweep docs should state this rule specifically for
indicator-parameter sweeps.

That documentation is a bridge, not the final UX.
