# RFC Synthesis: Active Parameterized Feature Aliases

**Status:** Accepted synthesis - binding for v0.1.8.4 active-alias ticket cut.
**Date:** 2026-05-25
**Author:** Codex
**Thread:**

- `inst/design/rfc/rfc_strategy_authoring_parameterized_indicators_v0_1_8_x.md`
- `inst/design/rfc/rfc_strategy_authoring_parameterized_indicators_v0_1_8_x_response.md`
- `inst/design/rfc/rfc_active_parameterized_feature_aliases_v0_1_8_x.md`
- `inst/design/rfc/rfc_active_parameterized_feature_aliases_v0_1_8_x_response.md`
- LDG-2303 strategy preflight contract alignment.
- LDG-2210 multi-output indicator bundle authoring.

---

## 1. Decision Summary

The original strategy-authoring RFC identified a real UX problem but its
docs-only recommendation is not sufficient. The attractive helper-factory
pattern:

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

calls an external user helper from inside strategy code. Per LDG-2303, that is
an unresolved user helper and therefore Tier 3. The strategy should fail
preflight before execution.

The recommended direction for a future API is first-class active
parameterized feature aliases:

```r
features <- ledgr_feature_map(
  fast = ledgr_ind_sma(ledgr_param("fast_n")),
  slow = ledgr_ind_sma(ledgr_param("slow_n"))
)

strategy <- function(ctx, params) {
  x <- ctx$features("AAA")
  x[["fast"]]
}
```

This gives users one feature declaration, stable strategy-facing aliases, and a
Tier-1-compatible strategy body. The first pass should be conservative:
explicit scalar parameter references, authoring declarations that resolve to
ordinary concrete indicators, flat bundle aliases, and no automatic tuning or
winner selection.

---

## 2. Recommended User Model

### Parameter References

Use `ledgr_param("name")` as the first public spelling for parameter
references.

This borrows one useful idea from tidymodels: declarations can carry visible
placeholders that are resolved later. It should not clone tidymodels'
workflow model. In ledgr, parameter references are serializable values used by
explicit sweep/run materialization. They are not tunable parameter objects with
priors, ranges, objectives, or automatic selection semantics.

First-pass rules:

- direct scalar substitution only;
- no arithmetic expressions on references;
- no formula or tidy-eval placeholder syntax;
- missing parameters fail at materialization with a classed error;
- non-scalar parameter values fail at materialization with a classed error;
- references are data, not executable expressions.

Users who need derived values should compute them in the candidate grid:

```r
ledgr_param_grid(
  fast10_slow40 = list(fast_n = 10L, slow_n = 40L, width = 30L)
)
```

### Constructor Integration

The first implementation should preserve the clean user shape:

```r
ledgr_ind_sma(ledgr_param("fast_n"))
```

ledgr-owned indicator constructors should recognize `ledgr_param()` in scalar
parameter positions and return an authoring-layer declaration when any
parameter reference is present. Non-parameterized calls keep returning current
concrete `ledgr_indicator` or `ledgr_indicator_bundle` objects.

The first pass should support these package-owned constructors:

- `ledgr_ind_sma()`;
- `ledgr_ind_ema()`;
- `ledgr_ind_rsi()`;
- `ledgr_ind_returns()`;
- `ledgr_ind_ttr()`;
- `ledgr_ind_ttr_outputs()`.

First-pass `ledgr_param()` support in direct `ledgr_indicator()` calls is
deferred. Users with custom indicators should resolve parameter values before
calling `ledgr_indicator()` until a later custom-indicator parameterization
contract exists.

Supported placement means documented scalar indicator-tuning arguments such as
window lengths and scalar options. It does not include feature IDs, feature-map
aliases, instrument IDs, input/output column names, function-valued arguments,
`series_fn` / adapter functions, nested parameter references, or arbitrary
lists. Those positions must remain concrete at declaration time.

### Authoring Declarations Are Not Concrete Indicators

Parameterized declarations are an authoring-layer object model. They should not
pretend to be unresolved `ledgr_indicator` objects.

The concrete indicator contract stays unchanged:

```text
concrete indicator -> concrete feature ID -> concrete fingerprint
```

Resolution turns an authored declaration plus concrete `params` into ordinary
concrete indicators before precompute, sweep, or run execution.

### Feature IDs

`ledgr_feature_id()` on an unresolved parameterized declaration should fail
with a classed error explaining that feature IDs exist only after resolution
with concrete parameters.

Do not invent placeholder IDs such as `sma_<fast_n>`. Do not return closures.
Placeholder IDs are tempting for printing, but they risk leaking a non-concrete
identifier into cache, comparison, or feature lookup paths.

The same rule applies to unresolved bundles. A bundle containing
`ledgr_param()` cannot expose output feature IDs until it has been resolved and
flattened with concrete parameters.

---

## 3. Runtime Flow

The active-alias flow should be explicit:

1. `ledgr_feature_map()` accepts concrete indicators, concrete bundles, and
   parameterized authoring declarations.
2. Construction validates declaration shape early: known constructors, valid
   aliases, supported parameter-reference placement, and serializable records.
3. Construction does not validate candidate values. Values are not available
   yet.
4. `ledgr_experiment(features = ...)` stores the authored declaration without
   resolving it.
5. `ledgr_run()` resolves once using the run's concrete `params`.
6. `ledgr_sweep()` resolves alias maps once per candidate using that
   candidate's concrete `params`, but concrete feature computation is unioned
   across the grid. Shared concrete features are computed once through the
   v0.1.8.3 runtime projection / `ledgr_precompute_features()` path, not once
   per candidate.
7. Resolution validates values late: required parameters, scalar shape, type,
   and constructor-specific constraints.
8. Precompute and fold execution receive ordinary concrete feature
   definitions.
9. The fold context receives an active alias map for the current run or
   candidate.

The pulse context then supports:

```r
ctx$features("AAA")
```

when an active alias map exists. The returned vector/list is keyed by strategy
aliases, not concrete engine IDs.

Existing forms remain valid:

```r
ctx$feature("AAA", "sma_20")
ctx$features("AAA", static_feature_map)
```

If no active alias map exists, `ctx$features("AAA")` must fail loudly with a
classed error. It must not silently return all features keyed by concrete
feature ID. The error should direct users to exact-ID lookup or to declaring
`features` as a feature map / parameterized feature map.

This strategy form stays preflight-compatible because the strategy body reads
`ctx`, `params`, local variables, string literals, and exported ledgr helpers.
It does not call a user-defined feature factory.

The active alias map is still per candidate and belongs to alias identity and
provenance. The runtime projection may carry a derived alias-to-index map for
cheap pulse access, but it is not the storage layer for alias maps and it has no
hash.

---

## 4. Identity And Provenance

### Hash Surfaces

Resolved alias maps are execution interface. They are read by the strategy
during execution and can change fills, events, and equity. They therefore
belong in execution identity.

Recommended first-pass hash contract:

- `config_hash`: includes the resolved alias map unconditionally.
- `feature_set_hash`: remains concrete-feature-only.
- `alias_map_hash`: add as a separate provenance hash.
- strategy function fingerprint: unchanged.
- concrete feature fingerprints: unchanged.
- execution seed derivation: unchanged unless a future spec finds a concrete
  need.

Unconditional inclusion is intentional. Conditional inclusion based on static
detection of `ctx$features()` usage would be brittle and hard to explain. This
means converting an experiment from a plain feature list to a feature map can
change `config_hash` even if a given strategy still uses exact-ID lookup. That
is acceptable because the strategy-visible execution interface changed.

The metric-context decision is the counterexample. Metric context is
post-execution analysis metadata and does not enter execution identity. Active
alias maps are pre-execution strategy interface and do enter identity.

### Provenance Layers

Store three layers:

```text
authored declaration: fast = SMA(n = param fast_n)
resolved alias map:   fast -> sma_20
concrete feature:     sma_20 fingerprint ...
```

The concrete feature layer is sufficient for computation. It is not sufficient
for audit: after a sweep, users should be able to inspect that `fast` came from
`params$fast_n`, not from a hard-coded `20`.

Recommended storage names for a future ticket:

- `alias_map_json`
- `alias_map_hash`
- `alias_map_version`

This should mirror the LDG-2306 `metric_context_*` storage pattern: write the
records at run creation, read them through accessors, and verify stored hashes
against reconstructed records. For the first pass, store authored-declaration
provenance inside `alias_map_json` rather than adding a second declaration JSON
column. That keeps the schema compact while preserving the audit relationship
between authored references and resolved aliases.

Exact schema details can be finalized in the implementation spec, but the
distinction between authored declaration, resolved alias map, and concrete
feature identity is binding.

### Pre-CRAN Compatibility

Per maintainer policy recorded on 2026-05-25, ledgr does not commit to
backward-compatible storage or hash migrations before CRAN release. A future
active-alias implementation may break old development artifacts without a
deprecation cycle.

This does not weaken current-version trust. Fingerprint pins, contract tests,
release gates, and hash-verification checks remain load-bearing. They prevent
accidental drift; they do not require migration shims for intentional
pre-CRAN design changes.

The existing `tests/testthat/test-fingerprint-stability.R` pins from LDG-2212
must continue to pass for current concrete, non-parameterized declarations.
Active aliases may add new identity surfaces; they must not change existing
concrete feature fingerprints unless a future spec explicitly authorizes that
contract change.

---

## 5. Parameter Introspection And Grids

`ledgr_parameters(features)` should ship with the first active-alias pass. It
is the minimum inspection helper that keeps users from discovering missing
parameters only at materialization time.

For a declaration such as:

```r
features <- ledgr_feature_map(
  fast = ledgr_ind_sma(ledgr_param("fast_n")),
  slow = ledgr_ind_sma(ledgr_param("slow_n"))
)
```

`ledgr_parameters(features)` should return an ordinary data frame describing
the parameter references. Minimum stable columns:

- `param_name`: the string supplied to `ledgr_param()`;
- `alias`: the feature-map alias where the reference appears;
- `argument`: the constructor argument where the reference appears.

Use one row per parameter reference. A parameter used by two aliases should
therefore produce two rows. The first pass does not need ranges, priors,
distributions, or objective metadata.

This composes with the planned parameter-grid helper work recorded in
`horizon.md` as `2026-05-15 [ux] Parameter-grid construction helpers`:

```r
grid <- ledgr_grid_cross(
  fast_n = c(10L, 20L),
  slow_n = c(40L, 80L),
  qty = 10L
)
```

Grid helpers remain grid constructors only. They validate and assemble
candidate parameter sets. They do not rank, optimize, tune, promote, or choose
winners.

Candidate ranking is separate future UX work, already parked in `horizon.md`
as `2026-05-25 [ux] Sweep candidate ranking views`, with a possible shape such
as:

```r
ranked <- ledgr_rank_candidates(
  results,
  by = "sharpe_ratio",
  direction = "desc",
  na_rm = TRUE
)
```

Users can filter with base R or dplyr before ranking. ledgr should not own a
filter DSL or automatic winner selection in the active-alias API.

---

## 6. Bundles And Future Adapters

Preserve current flat bundle aliases in the first pass.

Given:

```r
features <- ledgr_feature_map(
  bands = ledgr_ind_ttr_outputs(
    "BBands",
    input = "close",
    n = ledgr_param("bb_n")
  )
)
```

the active alias map should expose the same flat generated aliases used by the
current bundle contract, such as:

```r
x <- ctx$features("AAA")
x[["bbands_dn"]]
x[["bbands_up"]]
```

Do not introduce nested namespace returns such as `x[["bands"]][["up"]]` in
the first pass. Nested returns would make the shape of `ctx$features()` depend
on whether a feature-map entry came from a bundle, which is a larger API change
than active aliases need.

Parameter references inside bundle constructors resolve before bundle
materialization. After resolution, bundles flatten to ordinary concrete
single-output indicators as they do today.

Future TA-Lib adapter work can ship independently if it follows the accepted
multi-output bundle contract. Active aliases should not block TA-Lib. If a
future adapter wants nested bundle namespaces, that belongs in a separate
bundle-namespace RFC.

---

## 7. Conditional Feature Families

The first pass does not support executable feature-factory logic such as:

```r
if (params$regime == "trend") {
  ledgr_ind_sma(params$n)
} else {
  ledgr_ind_rsi(params$n)
}
```

That is conditional feature-family selection, not scalar parameter
substitution. It would require a declaration language, helper-capture contract,
or another RFC.

The recommended current workaround is to declare all variants and choose which
alias to read inside the strategy:

```r
features <- ledgr_feature_map(
  trend = ledgr_ind_sma(ledgr_param("n")),
  range = ledgr_ind_rsi(ledgr_param("n"))
)

strategy <- function(ctx, params) {
  x <- ctx$features("AAA")
  signal <- if (identical(params$regime, "trend")) {
    x[["trend"]]
  } else {
    x[["range"]]
  }
}
```

This computes both feature families and uses one. It is less efficient than
conditional materialization, but it keeps the strategy preflight-safe and the
feature declaration explicit.

When variants need different parameter values per family, use distinct
parameter names:

```r
features <- ledgr_feature_map(
  trend = ledgr_ind_sma(ledgr_param("trend_n")),
  range = ledgr_ind_rsi(ledgr_param("range_n"))
)
```

---

## 8. Non-Goals

The first active-alias API must not add:

- arbitrary expression language for feature declarations;
- formula, tidy-eval, or AST-derived feature inference;
- automatic feature-set inference from strategy code;
- conditional feature-family declarations;
- nested bundle namespace return shapes;
- grouped precompute batching or a second feature engine;
- changes to concrete feature fingerprints;
- automatic candidate ranking, winner selection, or `ledgr_tune()` semantics;
- CRAN-style migration or deprecation machinery for pre-CRAN artifacts.

---

## 9. Roadmap Placement

Do not add this work to v0.1.8.2. The v0.1.8.2 metric-context and auditr arc is
already closed.

Accepted placement: v0.1.8.4 as a dedicated active parameterized feature
aliases release.

The API should land before a walk-forward cycle that teaches parameterized
sweeps as a common workflow. Walk-forward does not strictly require active
aliases, but parameterized walk-forward without active aliases would make this
Tier-3 helper-factory trap much more visible.

Coordinate this with the accepted v0.1.9 target-risk chain synthesis. The risk
chain also adds to fold/pulse-context behavior. If active aliases land in
v0.1.8.4 and target-risk lands in v0.1.9, the two context surfaces should be
reviewed together so their helpers, identity records, and error messages do not
overlap or contradict each other.

When the API ships, update the LDG-2311 strategy-development bridge prose. The
current helper-factory / inline-workaround guidance should become the fallback
for cases active aliases do not cover, while `ledgr_param()` feature maps become
the recommended path for parameterized indicator sweeps.

---

## 10. Required Verification Surfaces

An implementation spec should require tests for:

- `ledgr_param()` construction, serialization, printing, and validation.
- Missing and non-scalar parameter materialization errors.
- Supported constructor integration with parameter references for the first-pass
  constructor set.
- Rejection of unsupported placements, including IDs, aliases, input/output
  column names, function arguments, nested references, and direct
  `ledgr_indicator()` custom construction.
- `ledgr_feature_id()` failure on unresolved declarations.
- `ledgr_feature_id()` failure on unresolved bundles.
- Successful resolution to concrete indicators and normal feature IDs.
- `ledgr_parameters(features)` introspection.
- `ledgr_run()` active alias map available through `ctx$features(id)`.
- `ledgr_sweep()` per-candidate alias maps and provenance.
- Classed error when `ctx$features(id)` is called without an active alias map.
- `config_hash` changes when only alias names change.
- `feature_set_hash` remains unchanged when concrete features are unchanged.
- `alias_map_hash` changes when alias mappings change.
- Flat bundle alias behavior with parameterized bundle constructors.
- Existing exact-ID lookup and explicit `ctx$features(id, map)` behavior.
- Documentation contract tests for the new authoring pattern and for prose
  explaining that external feature factories inside strategies remain Tier 3.

The implementation should also preserve existing fingerprint stability pins
unless a future spec explicitly authorizes a fingerprint contract change.
