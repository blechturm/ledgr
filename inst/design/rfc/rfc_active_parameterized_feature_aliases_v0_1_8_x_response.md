# RFC Response: Active Parameterized Feature Aliases

**Status:** Reviewer response - recommends a conservative first API pass.
**Date:** 2026-05-25
**RFC:** `inst/design/rfc/rfc_active_parameterized_feature_aliases_v0_1_8_x.md`
**Reviewer:** Codex

---

## Overall Assessment

The seed is the right follow-up to the strategy-authoring RFC and response. It
correctly reframes the issue from "document the right feature factory pattern"
to "design a first-class parameterized feature alias surface."

The core direction is sound:

```r
features <- ledgr_feature_map(
  fast = ledgr_ind_sma(ledgr_param("fast_n")),
  slow = ledgr_ind_sma(ledgr_param("slow_n"))
)

strategy <- function(ctx, params) {
  x <- ctx$features("AAA")
  ...
}
```

This gives the user one feature declaration, stable strategy-facing names, and
no external helper function inside the strategy body. It preserves the LDG-2303
preflight contract: the strategy reads `ctx`, `params`, and string keys, not a
user-defined feature factory.

Recommendation: move this direction toward synthesis, but keep the first API
pass conservative. Do not add arbitrary feature-factory expressions, nested
bundle namespaces, or automatic candidate selection.

---

## Recommended First-Cut API

### Parameter References

Use a visible placeholder primitive:

```r
ledgr_param("fast_n")
```

This is deliberately similar in spirit to tidymodels' placeholder-driven tuning
workflow, but ledgr should not clone tidymodels' workflow model. In ledgr, the
placeholder marks a value that comes from candidate `params`; sweep,
precompute, promotion, and provenance remain explicit.

First-cut rules:

- direct scalar substitution only;
- no arithmetic expressions on parameter references;
- no conditional feature-family selection;
- missing parameters fail during materialization with a classed error;
- non-scalar parameter values fail during materialization with a classed error;
- parameter references are serializable data, not executable expressions.

The conservative spelling is verbose enough to be searchable and explicit
enough for agents and reviewers:

```r
ledgr_ind_sma(ledgr_param("fast_n"))
```

Formula or tidy-eval spellings should be deferred. They add parsing ambiguity
without solving a current user problem.

### Authoring Object Model

Parameterized declarations should not be concrete `ledgr_indicator` objects.
They should be authoring-layer declaration objects that resolve to ordinary
indicators before precompute, sweep, or run execution.

That preserves the existing `ledgr_indicator` contract:

```text
concrete indicator -> concrete feature ID -> concrete fingerprint
```

Unresolved declarations may have a declaration record for provenance, but they
should not have ordinary indicator fingerprints. Concrete resolved indicators
remain the only values that enter feature-cache identity.

### Active Alias Lookup

Add active alias lookup as an additive pulse-context behavior:

```r
ctx$features("AAA")
```

This should return values keyed by the resolved active alias map for the
current run/candidate. Existing explicit-map lookup remains valid:

```r
ctx$features("AAA", static_feature_map)
```

If no active alias map exists, `ctx$features("AAA")` must fail loudly with a
classed error. It should not silently return all features keyed by engine ID.
The error should direct users to either:

- exact-ID lookup with `ctx$feature(id, feature_id)`; or
- declaring `features` as a feature map / parameterized feature map.

### Identity And Hashing

Resolved alias maps should enter execution config identity unconditionally.

Even if a particular strategy uses exact-ID lookup, the alias map is part of
the run's strategy-visible execution interface. Conditional inclusion based on
static detection of `ctx$features()` usage would be brittle and hard to reason
about.

Recommended hash surfaces:

- `config_hash`: include the resolved alias map.
- `feature_set_hash`: keep concrete-feature-only.
- `alias_map_hash`: add as a separate sweep/run provenance field if useful.
- strategy function fingerprint: unchanged; it is still a property of the
  strategy function body and captures.
- execution seed derivation: unchanged unless a future synthesis finds a
  concrete need.

This mirrors the metric-context decision in reverse. Metric context is
post-execution analysis metadata and does not enter execution identity. Active
alias maps are read during execution, so they do.

### Provenance

Store both sides of the relationship:

```text
authored declaration: fast = SMA(n = param fast_n)
resolved alias map:   fast -> sma_20
concrete feature:     sma_20 fingerprint ...
```

The resolved concrete indicators are enough for feature computation. They are
not enough for audit: after the sweep, the user should be able to see that
`fast` was driven by `params$fast_n`, not by a hard-coded value.

The exact storage shape belongs in synthesis, but the requirement is
load-bearing: authored parameter-reference provenance must survive into sweep
and run inspection.

---

## Bundle Decision For First Pass

Preserve current flat generated aliases for bundles.

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

the first pass should behave like the current bundle flattening contract:

```r
x <- ctx$features("AAA")
x[["bbands_dn"]]
x[["bbands_up"]]
```

Do not introduce nested namespace returns such as `x[["bands"]][["up"]]` in the
first pass. Nested values would make the return shape depend on whether a
bundle is present, which would surprise users and complicate existing
`passed_warmup()` style checks.

If users need shorter bundle names, keep using bundle `prefix` / `naming`
controls. A later bundle-namespace RFC can revisit this, but it should not be
part of the first active-alias API.

---

## Grid Helper Composition

Active parameterized aliases should compose with planned grid helpers, but they
should not depend on them.

Base path:

```r
grid <- ledgr_param_grid(
  fast10_slow40 = list(fast_n = 10L, slow_n = 40L, qty = 10),
  fast20_slow80 = list(fast_n = 20L, slow_n = 80L, qty = 10)
)
```

Future grid-helper path:

```r
grid <- ledgr_grid_cross(
  fast_n = c(10L, 20L),
  slow_n = c(40L, 80L),
  qty = 10L
)
```

The useful tidymodels-adjacent idea is:

```text
declaration with placeholders -> inspect parameter needs -> generate grid -> sweep
```

In ledgr terms:

```r
features <- ledgr_feature_map(
  fast = ledgr_ind_sma(ledgr_param("fast_n")),
  slow = ledgr_ind_sma(ledgr_param("slow_n"))
)

ledgr_parameters(features)
```

would show the parameter IDs the declaration needs. A future
`ledgr_grid_cross()` can validate that grid rows provide those IDs. This stays
within ledgr's explicit sweep model: grid helpers create candidate parameter
sets; they do not rank candidates or choose winners.

---

## Candidate Ranking Is Adjacent But Separate

Users will write small helpers to rank sweep results. That is real UX friction,
but it is not the same problem as active feature aliases.

The right future helper is a transparent candidate-ranking view, not automatic
winner selection:

```r
ranked <- ledgr_rank_candidates(
  results,
  by = "sharpe_ratio",
  direction = "desc",
  na_rm = TRUE
)

candidate <- ledgr_candidate(ranked, 1)
```

This is intentionally tidyverse-adjacent but not tidy-eval. Users can filter
with base R or dplyr before ranking. ledgr only owns ordering mechanics,
classed validation, and selection provenance.

This work should be parked with sweep-result / parameter-grid ergonomics, not
folded into active aliases.

---

## Pre-CRAN Compatibility

Do not design migration complexity for pre-CRAN stored artifacts.

Before ledgr reaches CRAN, schema changes, config-hash changes, provenance
shape changes, and experimental API changes may break older development
artifacts without a deprecation cycle. The synthesis should define
current-version behavior and clear failure modes, not legacy migrations.

Fingerprint pins, contract tests, and release gates remain important. They
prevent accidental drift. They do not imply a backward-compatibility guarantee
for intentional pre-CRAN design changes.

---

## Recommended Synthesis Positions

The synthesis should likely accept:

1. `ledgr_param("name")` as the first parameter-reference spelling.
2. Direct scalar substitution only.
3. Separate authoring-layer declaration objects, not unresolved
   `ledgr_indicator` objects.
4. Resolution to ordinary concrete indicators before precompute, sweep, or run.
5. `ctx$features(id)` active-alias lookup as an additive behavior.
6. Classed error when no active alias map exists.
7. Resolved alias map included in `config_hash` unconditionally.
8. `feature_set_hash` remains concrete-feature-only.
9. Optional `alias_map_hash` as separate provenance.
10. Bundle first pass preserves current flat generated aliases.
11. Pre-CRAN compatibility policy permits breaking old development artifacts.
12. Candidate-ranking helpers are separate future UX work.

---

## Non-Goals Confirmed

- No arbitrary expression language.
- No conditional feature-family declaration in the first pass.
- No automatic winner selection.
- No `ledgr_tune()` semantics.
- No nested bundle namespace return shape.
- No second feature engine.
- No change to concrete feature fingerprints.
- No legacy migration burden before CRAN.

