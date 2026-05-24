# RFC: Strategy Authoring For Parameterized Indicators

**Status:** Request for comment - strategy authoring UX proposal; no
implementation started.
**Date:** 2026-05-24
**Author:** Claude Code
**Input:** Maintainer question on how strategies should read feature values
when indicator parameters are swept.
**Context files:**
- `R/pulse-context.R` - `ctx$feature()` / `ctx$features()` API
- `R/indicator.R` - `ledgr_indicator()` constructor; `ledgr_feature_id()`
- `R/indicators_builtin.R` - built-in indicator ID convention (`sma_<n>`, etc.)
- `R/indicator-bundle.R` - bundle authoring layer
- `R/feature-map.R` - `ledgr_feature_map()` alias contract
- `R/experiment.R` - static feature path and feature-factory mode
- `vignettes/indicators.Rmd` - feature lifecycle documentation
- `vignettes/strategy-development.Rmd` - strategy authoring guide
- `inst/design/rfc/rfc_multi_output_indicator_ux_synthesis.md` - bundle flatten contract
- `tests/testthat/test-fingerprint-stability.R` - feature-factory sweep test

---

## 1. Problem Statement

ledgr's sweep workflow lets a user vary indicator parameters across candidates:

```r
features <- function(params) list(ledgr_ind_sma(params$n))
grid <- ledgr_param_grid(
  short = list(n = 20),
  long = list(n = 50)
)
```

The feature factory produces a different `ledgr_indicator` per candidate. The
candidate-specific feature IDs are `sma_20`, `sma_50`, and so on. The strategy
must then read these candidate-specific IDs from the pulse context.

This works today, but the strategy author has to make a non-obvious choice
about *how* to read the feature whose ID changes across candidates. The
available patterns are documented in fragments (the indicators vignette shows a
factory; the test suite uses one approach; the strategy-development vignette
does not currently address parameter sweeps explicitly). The result is that a
new user setting up an indicator-parameter sweep has to invent or rediscover a
pattern instead of following a recommended convention.

This RFC enumerates the patterns currently available, identifies where the
friction lives, and proposes a documentation-led recommendation with one
optional minor API helper for later consideration.

---

## 2. Patterns Currently Available

### Pattern 1: Strategy reconstructs the ID from `params`

```r
features <- function(params) list(ledgr_ind_sma(params$n))

strategy <- function(ctx, params) {
  sma_id <- paste0("sma_", params$n)
  value <- ctx$feature("AAA", sma_id)
  ...
}
```

- Pro: minimal; no extra construction per pulse; mirrors the test suite's
  current convention in `test-fingerprint-stability.R`.
- Con: couples strategy code to the indicator's ID naming convention. Replacing
  `ledgr_ind_sma()` with a custom adapter that uses a different ID format
  breaks the strategy silently. Acceptable for built-ins whose ID convention is
  part of the public contract; risky for custom adapters.

### Pattern 2: Strategy uses `ledgr_feature_id()` for runtime lookup

```r
strategy <- function(ctx, params) {
  sma_id <- ledgr_feature_id(ledgr_ind_sma(params$n))
  value <- ctx$feature("AAA", sma_id)
  ...
}
```

- Pro: ID-format-agnostic; survives changes to the indicator's ID convention.
- Con: constructs a `ledgr_indicator` object on every pulse only to read its
  ID. For one feature this is negligible; for many features it is wasteful.
  Also, the user is still hardcoding *which* indicator family the strategy
  expects, so the decoupling is incomplete.

### Pattern 3: Feature map factory with stable aliases

```r
make_features <- function(params) ledgr_feature_map(
  fast = ledgr_ind_sma(params$fast_n),
  slow = ledgr_ind_sma(params$slow_n)
)

strategy <- function(ctx, params) {
  fm <- make_features(params)
  vals <- ctx$features("AAA", fm)
  if (vals[["fast"]] > vals[["slow"]]) {
    return(setNames(rep(params$qty, length(ctx$universe)), ctx$universe))
  }
  ctx$flat()
}

exp <- ledgr_experiment(snapshot, strategy, features = make_features)
```

- Pro: strategy vocabulary (`fast`, `slow`) is invariant across candidates.
  Only the underlying indicator definitions vary. The same factory drives both
  the experiment's feature materialization and the strategy's read path. ID
  conventions can change without touching strategy code.
- Con: the strategy reconstructs the feature map on every pulse. For pure
  functions of `params` this is cheap, but it is technically per-pulse churn.
  Closing over `make_features(params)` at run start would avoid the churn but
  interacts with strategy fingerprinting and adds complexity.

### Special Case: Bundles With Stable IDs

`ledgr_ind_ttr_outputs()` produces feature IDs derived from a prefix and
output token, not from parameter values:

```r
features <- function(params) ledgr_ind_ttr_outputs("BBands", input = "close", n = params$n)

strategy <- function(ctx, params) {
  dn <- ctx$feature("AAA", "bbands_dn")
  up <- ctx$feature("AAA", "bbands_up")
  ...
}
```

For bundle-backed sweeps, the strategy reads invariant IDs across candidates.
Only the fingerprint distinguishes the parameterizations for caching and
provenance. The patterns above do not apply to bundles in the same way.

---

## 3. Where Friction Lives

The friction is concentrated in three places.

### 3.1 Convention Discovery

A user encountering indicator-parameter sweeps for the first time has to
infer that the canonical convention is Pattern 3 (factory + aliases) rather
than Pattern 1 (string reconstruction). The current documentation shows
Pattern 1 in the indicators vignette and the fingerprint-stability test
suite, but does not call out that Pattern 3 is the recommended shape for
non-trivial sweeps. The user therefore tends to follow what they see, even
when Pattern 3 would scale better.

### 3.2 Per-Pulse Feature-Map Reconstruction

Pattern 3 reconstructs the feature map on every pulse. For a single sweep
this is negligible, but for sweeps with high candidate counts and many
features, the per-pulse construction adds up. The pulse context does not
currently expose the active feature map to the strategy, so the strategy
cannot avoid the reconstruction without closing over `params` at run start.

### 3.3 Tension With Strategy Fingerprinting

Closing over `make_features(params)` at run start would naturally avoid
per-pulse churn, but ledgr fingerprints strategy functions for provenance and
replay. A closure that captures candidate-specific feature maps changes the
function fingerprint per candidate, which may invalidate strategy registry
keys and complicate provenance. This pushes users back toward Pattern 1 even
when Pattern 3 would be cleaner.

---

## 4. Design Constraints

Any proposal here must preserve these contracts.

1. **No second feature engine.** Indicators still precompute feature series
   before execution. The pulse context still serves scalar feature values from
   the precomputed cache.
2. **No feature ID drift.** Built-in, TTR, bundle-expanded, and custom feature
   IDs remain stable. This RFC must not change the indicator ID convention.
3. **No fingerprint drift.** Strategy function fingerprints, feature
   fingerprints, and candidate feature-set hashes must not change as a result
   of any recommendation here.
4. **No-lookahead boundary preserved.** Any new pulse-context surface must
   remain decision-time only.
5. **Sweep provenance unchanged.** Candidate-level `feature_set_hash` and
   sweep result row schema remain the same.

---

## 5. Proposed Options

### Option A: Documentation-Only Convention

Pick Pattern 3 (factory + feature map + stable aliases) as the canonical
convention for non-trivial indicator-parameter sweeps. Document it explicitly
in:

- `vignettes/strategy-development.Rmd`: add a "Sweeping Indicator Parameters"
  section showing the factory + aliases pattern as the recommended shape.
- `vignettes/indicators.Rmd`: extend the existing factory example to use a
  feature map with aliases, not a plain list.
- `vignettes/sweeps.Rmd`: cross-link to the strategy-authoring section when
  introducing feature factories.

Document Pattern 1 as the lightweight shortcut for built-ins where the user
accepts the convention coupling. Document Pattern 2 as a defensive option for
adapter-heavy workflows.

For bundles, document that bundle-backed sweeps produce invariant IDs and
that the factory-with-aliases pattern is not required.

Pro:
- Zero API change.
- Surfaces the existing best practice without changing the contract surface.
- Low risk; pure docs work.

Con:
- Does not solve per-pulse reconstruction (Section 3.2).
- Does not resolve the fingerprinting tension (Section 3.3).
- Relies on users reading the recommended convention; the test suite's current
  Pattern 1 example may continue to bias new users.

### Option B: Documentation Plus Pulse-Context Helper

Add a read-only `ctx$feature_map()` accessor returning the candidate's active
feature map, so Pattern 3 strategies can read aliases without reconstructing:

```r
strategy <- function(ctx, params) {
  vals <- ctx$features("AAA", ctx$feature_map())
  if (vals[["fast"]] > vals[["slow"]]) {
    ...
  }
  ctx$flat()
}

exp <- ledgr_experiment(snapshot, strategy, features = make_features)
```

The pulse context already holds the resolved indicator set for the active
candidate. Exposing the corresponding feature map as a no-argument read-only
helper would eliminate per-pulse reconstruction and remove the fingerprinting
tension entirely (the strategy does not need to capture any closure).

Pro:
- Resolves per-pulse reconstruction.
- Resolves the strategy-fingerprinting tension.
- Strategy code becomes the cleanest possible: one factory definition, no
  parameter-derived ID strings, no per-pulse construction.

Con:
- Adds public surface to the pulse context. Any addition to `ctx` is a
  contract change.
- The `feature_map` returned by `ctx$feature_map()` must reflect what the user
  passed (factory mode) or what the experiment stored (static mode); the
  semantics need to be precise to avoid surprises when aliases differ across
  modes.
- Bundle expansion currently uses feature IDs as aliases (per the bundle
  flatten contract). The returned feature map would expose those derived
  aliases, which may not be what the user expected from a `ctx$feature_map()`
  call.

### Option C: Documentation Plus Implicit Default Feature Map

Allow `ctx$features(id)` to default to the active feature map when the second
argument is omitted:

```r
strategy <- function(ctx, params) {
  vals <- ctx$features("AAA")
  ...
}
```

This is the most ergonomic shape but the most invasive: it changes the
documented `ctx$features(id, feature_map)` signature into `ctx$features(id,
feature_map = NULL)` with a fallback. It also obscures the dependency on the
active feature map, making strategy code harder to read in isolation.

Pro:
- Maximally ergonomic strategy code.

Con:
- Changes a public method signature.
- Hides the feature-map dependency, which is the opposite of ledgr's
  explicit-contracts discipline.
- Same semantic ambiguity issues as Option B (which feature map is active in
  which mode).

---

## 6. Recommendation

Accept Option A as the v0.1.8.2 documentation track addition. Defer Options B
and C until there is concrete evidence (auditr findings, contributor
questions, or strategy benchmarks) that per-pulse reconstruction is a real
friction point rather than a theoretical one.

Reasoning:

- The patterns already work today. The user-visible problem is convention
  discovery (Section 3.1), not capability.
- Documentation can close 80% of the friction by recommending Pattern 3
  explicitly and showing the factory-with-aliases shape as a first-class
  example.
- The per-pulse reconstruction concern (Section 3.2) is currently theoretical.
  Sweeps in the current architecture already pay larger per-pulse costs in the
  fold core. Adding pulse-context surface to optimize a non-load-bearing
  reconstruction would be a premature contract expansion.
- The fingerprinting tension (Section 3.3) is real but currently has a
  workaround (don't close over `params`; reconstruct in the strategy body).
  Pattern 3 with per-pulse reconstruction sidesteps it cleanly.
- Option B can be revisited as a v0.1.8.4 or v0.1.9.x patch once metric
  context, sweep optimization, and walk-forward have stabilized the
  surrounding contracts. By then there will be real evidence of whether the
  friction is felt.

For bundles, no documentation change is needed beyond cross-linking the
existing bundle examples to the strategy-authoring page.

---

## 7. Non-Goals

This RFC does not propose:

- changing the indicator ID convention;
- changing `ledgr_feature_id()`, `ledgr_feature_map()`, or
  `ledgr_indicator()` signatures;
- changing the pulse context's `ctx$feature()` or `ctx$features()` semantics
  in v0.1.8.2;
- changing how feature factories are materialized at run start;
- changing strategy function fingerprinting, registry, or provenance;
- adding a strategy authoring DSL;
- introducing implicit feature lookup that hides the active feature map;
- adding new feature-shape input normalization;
- changing bundle flatten semantics.

---

## 8. Acceptance Criteria If Accepted

If Option A is accepted into v0.1.8.2 documentation scope:

1. `vignettes/strategy-development.Rmd` contains a "Sweeping Indicator
   Parameters" section that names Pattern 3 (factory + aliases) as the
   recommended shape, shows a runnable example, and notes Pattern 1 as the
   shortcut for built-ins.
2. `vignettes/indicators.Rmd` updates the existing factory example to use a
   feature map with named aliases.
3. `vignettes/sweeps.Rmd` cross-links to the strategy-authoring section when
   it introduces feature factories.
4. Documentation contract tests pin the new pattern wording so future drift
   surfaces as test failures.
5. No public API change. No fingerprint change. No man-page signature
   change beyond doc additions.
6. The test suite's existing Pattern 1 example in
   `test-fingerprint-stability.R` is retained as-is (it is a fingerprint
   test, not a user-facing recommendation).

---

## 9. Open Questions

1. Should the recommended pattern in the strategy-development vignette use
   `ctx$features("AAA", make_features(params))` (per-pulse reconstruction) or
   should the docs explicitly warn about closure-over-`params` and document
   the fingerprinting tension as a known limit?
2. If Option B is later accepted, should `ctx$feature_map()` return the
   resolved feature map verbatim (including bundle-derived aliases), or
   should it surface only the user-provided aliases for cases where the
   distinction matters?
3. Should this RFC be folded into the v0.1.8.2 docs track as part of the
   broader feature lifecycle documentation work, or scoped as its own ticket?
4. Does the talib adapter PR (issue #2), if delivered, require any change to
   the recommended pattern, or do bundle-backed adapters always escape the
   problem this RFC addresses?

---

## 10. Roadmap Placement

If accepted as Option A: v0.1.8.2 documentation scope, alongside the metric
context documentation work and the Phase 2 indicator codebase cleanup.

If later promoted to Option B: v0.1.8.4 (parameter-grid quality-of-life
helpers) or v0.1.9.x, after walk-forward semantics have settled and any
related pulse-context surface changes can be considered together.

Option C is not recommended for any milestone in the current arc.
