# RFC Seed: Active Parameterized Feature Aliases

**Status:** Design seed - follow-up required before synthesis or ticket cut.
**Date:** 2026-05-25
**Supersedes:** The docs-only recommendation in
`rfc_strategy_authoring_parameterized_indicators_v0_1_8_x.md`.
**Inputs:**
- `rfc_strategy_authoring_parameterized_indicators_v0_1_8_x.md` - problem
  statement and current pattern inventory.
- `rfc_strategy_authoring_parameterized_indicators_v0_1_8_x_response.md` -
  correction that the clean docs-only pattern violates current preflight tiers.
- LDG-2303 - v0.1.8.2 strategy preflight alignment.
- LDG-2210 - multi-output indicator bundle authoring and bundle flattening.

---

## 1. Problem Statement

ledgr can already sweep indicator parameters, but the user-facing strategy
authoring model is not good enough.

Today, a user can write a feature factory:

```r
features <- function(params) {
  ledgr_feature_map(
    fast = ledgr_ind_sma(params$fast_n),
    slow = ledgr_ind_sma(params$slow_n)
  )
}
```

The desired strategy body is:

```r
strategy <- function(ctx, params) {
  x <- ctx$features("AAA", features(params))
}
```

That strategy calls an external user helper function. Under the current
preflight contract, unresolved user helper functions are Tier 3 and rejected
before execution. The mechanically valid Tier 1 workaround duplicates the
feature-map declaration inside the strategy, which is poor API design and
creates declaration drift.

The current RFC response therefore reframes the issue: this is not only a
documentation gap. ledgr lacks a first-class authoring surface for
parameterized feature aliases.

---

## 2. Target User Shape

The intended future shape is declaration-first:

```r
features <- ledgr_feature_map(
  fast = ledgr_ind_sma(ledgr_param("fast_n")),
  slow = ledgr_ind_sma(ledgr_param("slow_n"))
)

strategy <- function(ctx, params) {
  x <- ctx$features("AAA")

  if (x[["fast"]] > x[["slow"]]) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    return(targets)
  }

  ctx$flat()
}
```

`ledgr_param("fast_n")` is a placeholder spelling, not an accepted API. The
design point is that the feature declaration contains serializable parameter
references. ledgr resolves those references at candidate/run materialization
time and supplies the active alias map to the pulse context.

The strategy no longer calls a user feature factory. If it otherwise uses only
`ctx`, `params`, base/recommended functions, and exported ledgr helpers, it can
remain Tier 1.

---

## 3. Proposed Conceptual Model

1. Users declare a feature map that may contain parameter references.
2. Parameterized declarations are authoring objects, not executable runtime
   feature objects.
3. Before precompute, sweep, or run execution, ledgr resolves the declaration
   using concrete `params`.
4. Resolution produces ordinary concrete `ledgr_indicator` objects with
   ordinary feature IDs and fingerprints.
5. The resolved run/candidate also carries an active alias map:

```text
strategy alias -> concrete feature ID
fast           -> sma_20
slow           -> sma_50
```

6. The fold context can read this active alias map:

```r
ctx$features("AAA")
```

7. Exact-ID lookup remains unchanged:

```r
ctx$feature("AAA", "sma_20")
```

8. Existing explicit feature-map lookup remains valid:

```r
ctx$features("AAA", static_feature_map)
```

---

## 4. Identity And Provenance Principles

### Concrete Feature Identity Does Not Change

Feature cache identity still comes from concrete resolved feature definitions:
feature ID, feature fingerprint, snapshot hash, instrument, feature-engine
version, and existing cache keys.

Parameterized declarations should not introduce a second feature engine, a
runtime multi-output object, or a new cache key family.

### Alias Maps Are Execution Interface

Aliases are not market-data identity, but they are strategy-visible runtime
interface. If changing the alias map can change what the strategy reads, it can
change fills and equity.

Default design assumption: resolved alias maps belong in execution config
identity and run/sweep provenance. A synthesis must decide the exact hash
surfaces:

- `config_hash`: likely includes the resolved alias map.
- `feature_set_hash`: likely remains concrete-feature-only unless explicitly
  redefined.
- strategy function fingerprint: should remain a property of the strategy
  function, not of alias metadata.
- execution seed derivation: should remain tied to existing candidate/run
  identity rules unless a synthesis chooses otherwise.

### Metric Context Is The Counterexample

Metric context is post-execution analysis metadata and deliberately does not
enter execution identity. Active alias maps are different: they are read by the
strategy during execution. The expected answer is therefore the opposite of the
metric-context answer.

### Pre-CRAN Compatibility Policy

This design does not need to preserve compatibility with stored artifacts from
earlier development cycles. Until ledgr is released on CRAN, database schemas,
config hashes, provenance formats, and experimental APIs may change without a
backward-compatibility or deprecation cycle.

The synthesis should define current-version behavior and clear failure modes.
It should not spend design complexity on migrating old pre-CRAN run databases
unless a specific current-cycle acceptance criterion requires it.

---

## 5. Scope Boundaries

### Simple Substitution First

The first design should cover simple scalar substitution:

```r
ledgr_ind_sma(ledgr_param("fast_n"))
```

It should not try to encode arbitrary feature-factory control flow:

```r
if (params$regime == "trend") {
  ledgr_ind_sma(params$n)
} else {
  ledgr_ind_rsi(params$n)
}
```

Conditional feature selection is executable user logic. It needs either a
separate declaration language, an explicit helper-capture design, or continued
use of current factory/exact-ID patterns.

### Parameter Reference Semantics To Decide

A synthesis must answer:

- What is the spelling: `ledgr_param("fast_n")`, another function, or a
  formula-like placeholder?
- Are only direct scalar substitutions allowed?
- Are arithmetic expressions on references allowed?
- What happens when the parameter is missing?
- What happens when the parameter value is not a scalar?
- Are references allowed inside bundle constructors?
- Are references allowed inside adapter params beyond built-ins?

The conservative first answer should be direct scalar substitution only.

### Fingerprint Semantics To Decide

Parameterized declarations introduce a new unresolved authoring state.

Open choices:

- unresolved declarations have no indicator fingerprint; only resolved
  concrete indicators do;
- unresolved declarations have a declaration/schema fingerprint, separate from
  concrete feature fingerprints;
- unresolved declarations are not `ledgr_indicator` objects at all, but a
  separate authoring class resolved before indicator construction.

The third option is likely cleanest: avoid pretending an unresolved
parameterized declaration is a concrete indicator.

---

## 6. Bundle Alias Semantics To Decide

Current bundle-in-feature-map behavior:

```r
ledgr_feature_map(
  bbands = ledgr_ind_ttr_outputs("BBands", input = "close", n = 20)
)
```

expands to aliases such as `bbands_dn`, `bbands_mavg`, `bbands_up`, and
`bbands_pctb`. The user-provided alias `bbands` is not a namespace.

Parameterized aliases force an explicit decision:

```r
ledgr_feature_map(
  bb = ledgr_ind_ttr_outputs("BBands", input = "close", n = ledgr_param("n"))
)
```

Possible outcomes:

1. Preserve current semantics: `ctx$features("AAA")` returns `bbands_dn`,
   `bbands_mavg`, etc.
2. Prefix with user alias: `ctx$features("AAA")` returns `bb_dn`, `bb_mavg`,
   etc.
3. Treat bundle aliases as namespaces: `x[["bb"]]` is itself a named vector.
4. Reject bundle entries in active parameterized alias maps until a later
   bundle-namespace design.

This decision intersects with the accepted LDG-2210 bundle flatten contract and
must be resolved before implementation.

---

## 7. Current-State Bridge Documentation

Until this API exists, docs should state:

- exact-ID lookup works for parameterized built-ins;
- `ledgr_feature_id(ledgr_ind_*(params$...))` is safer than hand-built strings
  when the constructor is cheap;
- static feature maps work well with `ctx$features(id, feature_map)`;
- plain feature factories returning lists are valid, but strategy code must use
  exact feature IDs;
- calling an external feature factory from inside a strategy is not Tier 1 or
  Tier 2 under current preflight rules;
- duplicating a parameterized feature map inside a strategy is mechanically
  valid but not the desired long-term UX;
- bundle-backed sweeps can use stable output IDs when prefix/naming is stable,
  while fingerprints and provenance distinguish parameterizations.

This is bridge guidance, not the desired end-state.

---

## 8. Roadmap Placement

This is API work, not v0.1.8.2 documentation polish.

Likely placements:

- v0.1.8.4 if the parameter-grid quality-of-life cycle grows into a broader
  sweep-authoring ergonomics cycle;
- v0.1.8.5/v0.1.8.6 if it deserves a dedicated strategy-authoring slice;
- v0.1.9.x if it should coordinate with the target-risk / pulse-context
  contract work.

Do not implement before a synthesis answers parameter-reference semantics,
fingerprint semantics, alias identity, and bundle interaction.

---

## 9. Non-Goals For The First API Pass

- No arbitrary expression language for feature factories.
- No hidden provider lookup, file I/O, RNG, clocks, or mutable state in feature
  declarations.
- No second feature engine.
- No change to exact-ID `ctx$feature()` lookup.
- No removal of explicit `ctx$features(id, feature_map)`.
- No grouped precompute batching.
- No change to concrete feature fingerprints.
- No implicit benchmark/beta/risk feature semantics.

---

## 10. Questions For The Next Review

1. Should unresolved parameterized declarations be separate objects from
   `ledgr_indicator`?
2. Should resolved alias maps enter `config_hash` unconditionally?
3. Should sweep candidate identity expose both `feature_set_hash` and
   `alias_map_hash`?
4. Should bundle aliases preserve current generated-ID semantics or introduce
   user-alias prefixing / namespaces?
5. Should simple substitution support only scalar params?
6. Should this land before walk-forward, where parameterized sweeps will be
   more common?
