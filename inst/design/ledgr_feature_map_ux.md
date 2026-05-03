# ledgr Feature Map UX -- Design Proposal

**Status:** Draft proposal. Candidate for a future feature-authoring ticket;
explicitly not part of LDG-1306.
**Scope:** User-facing feature declaration, feature lookup, warmup guards, and
strategy-authoring ergonomics. This document does not change the execution
model.

---

## Problem

Feature-heavy strategies currently require users to maintain two parallel
structures:

```r
features <- list(rsi_14, bb_up)

strategy <- function(ctx, params) {
  rsi <- ctx$feature("DEMO_01", "ttr_rsi_14")
  bb_up <- ctx$feature("DEMO_01", "ttr_bbands_20_up")
  ...
}
```

This repeats feature identity in two forms: indicator objects for registration
and string IDs for pulse-time lookup. It also encourages strategy code that
hardcodes instrument IDs, repeats `ctx$feature()` calls, and spreads warmup
guards across long `!is.na()` conditions.

That is the wrong teaching surface. A ledgr strategy should make the financial
decision readable; infrastructure details should stay close to the feature
definition.

---

## Design Principle

One feature object should span declaration, registration, and pulse-time use.

The user should define indicators once, assign readable aliases once, register
the same object with the experiment, and use the same object inside the strategy
closure.

This is closer to `ggplot2::aes()` than to `recipes::recipe()`. A feature map is
a declarative mapping from user-facing names to underlying feature definitions.
It is applied later by the engine and the pulse context. ledgr should not grow a
general preprocessing pipeline with `prep()`, `bake()`, roles, or selector
machinery.

---

## Proposed User Shape

Define the indicator objects, then build one feature map:

```r
rsi_14 <- ledgr_ind_ttr("RSI", input = "close", n = 14)
bb_up <- ledgr_ind_ttr("BBands", input = "close", output = "up", n = 20)

features <- ledgr_feature_map(
  rsi = rsi_14,
  bb_up = bb_up
)
```

Define the strategy before constructing the experiment, matching existing
vignette convention:

```r
strategy <- function(ctx, params) {
  targets <- ctx$hold()

  for (id in ctx$universe) {
    x <- ctx$features(id, features)

    if (passed_warmup(x) && x[["rsi"]] > 50 && ctx$close(id) > x[["bb_up"]]) {
      targets[id] <- params$qty
    }
  }

  targets
}
```

Then register the same feature map:

```r
exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = strategy,
  features = features,
  opening = ledgr_opening(cash = 10000)
)
```

The strategy function closes over `features`. That closure is what makes the
single-definition pattern possible: the same map is used at experiment
construction time for registration and at pulse time for feature lookup.

---

## Proposed Objects

### `ledgr_feature_map()`

`ledgr_feature_map()` returns a typed object that carries:

- user aliases, such as `rsi` and `bb_up`;
- indicator objects, used by `ledgr_experiment(features = ...)`;
- derived feature IDs, used by pulse contexts;
- enough metadata to print and validate the map clearly.

The object is richer than a named character vector. It is both the registration
object and the lookup object.

`ledgr_experiment(features = ...)` continues to accept a plain `list()` of
indicator objects. `ledgr_feature_map()` is the preferred form when strategies
need readable aliases and bundled pulse-time lookup.

Aliases are user-facing names. They are not roles, selectors, or transformation
groups. The first version should not add role machinery.

### `ctx$features(id, features)`

`ctx$features()` reads all mapped features for one instrument at the current
pulse and returns a named numeric vector keyed by aliases:

```r
x <- ctx$features("DEMO_01", features)

x[["rsi"]]
x[["bb_up"]]
```

The first version should prefer this narrow per-instrument lookup over a wide
table form. A future `ctx$features_wide()` can be considered if a real strategy
or diagnostic workflow needs it.

### `passed_warmup(x)`

`passed_warmup()` is a strategy-authoring predicate:

```r
passed_warmup <- function(x) all(!is.na(x))
```

For named numeric vectors produced by `ctx$features()`, this is semantically
equivalent to "all requested indicators are stable at this pulse." ledgr
indicator contracts require built-in and TTR-backed indicators to return `NA`
until their warmup requirements are satisfied.

The documentation must state the boundary precisely: `passed_warmup()` has the
warmup meaning for vectors returned by `ctx$features()`. For arbitrary vectors,
it is only an `all(!is.na(x))` predicate and does not prove why values are
missing.

`passed_warmup()` is not a signal pipeline transformation. It is a guard used
inside strategy logic.

---

## Immutability Contract

A feature map passed to `ledgr_experiment(features = ...)` must be treated as
immutable for that experiment.

Implementation should enforce this by copy-on-use: `ledgr_experiment()` extracts
and stores the indicator list and resolved feature IDs at construction time.
Subsequent mutations or rebinding of the caller's `features` variable must not
change the experiment's registered feature set.

This follows R's copy-on-modify model and avoids holding a mutable caller-owned
object as the authoritative experiment definition.

---

## Validation Rules

`ledgr_feature_map()` should fail loudly when:

- aliases are missing, duplicated, empty, or `NA`;
- any mapped value is not a ledgr indicator object;
- two aliases resolve to the same feature ID unless duplicate aliases are
  explicitly supported by a later design;
- aliases are not syntactically valid R names for returned feature vectors.

`ctx$features(id, features)` should fail loudly when:

- `id` is not in `ctx$universe`;
- a mapped feature ID was not registered with the experiment;
- a mapped feature value cannot be represented as a scalar numeric value at the
  current pulse.

Warmup is not an error. Warmup is represented by `NA` values and handled with
`passed_warmup()`.

---

## Non-Goals

- Do not add a second execution path. Strategies still return full named numeric
  target vectors or a helper value type that unwraps to one.
- Do not add a general preprocessing pipeline.
- Do not add recipes-style roles, selectors, `prep()`, or `bake()`.
- Do not require a new wide feature table API in the first version.
- Do not make `passed_warmup()` responsible for diagnosing data-quality
  failures outside ledgr feature vectors.

---

## Documentation Implications

The documentation target should be a general installed indicators vignette,
not a TTR-specific vignette. TTR indicators are one source of features; the
teaching model should cover built-in ledgr indicators and TTR-backed indicators
under the same strategy-authoring contract.

Candidate file name: `vignettes/indicators.Rmd`. For v0.1.7.3, before the
feature-map API exists, the title should be closer to "Indicators And Feature
IDs". After the feature-map API ships, the same installed vignette can grow into
"Indicators And Feature Maps" without creating a second indicator article.

Once this API exists, the indicators vignette should teach the
configuration/execution boundary:

- configuration time: define indicator objects and create a feature map;
- indicator warmup: known indicators return `NA` until they are usable,
  regardless of whether they are built-in or TTR-backed;
- execution time: read mapped features from the pulse context;
- warmup handling: use `passed_warmup()` to gate signal logic;
- target decision: update target holdings for each instrument in
  `ctx$universe`.

In v0.1.7.3, the same vignette should still consolidate indicator teaching even
without the feature-map API: built-in indicators, TTR-backed indicators, exact
feature IDs, and warmup should be taught in one installed article. After the API
ships, examples that hardcode one instrument repeatedly or require readers to
copy feature ID strings into strategy bodies should be replaced with the feature
map form.

The existing installed `ttr-indicators` vignette should not remain as a
parallel teaching article once `indicators.Rmd` exists. Its useful teaching
content should be folded into the general indicators vignette, and TTR-specific
reference facts should live in `?ledgr_ind_ttr`. Keeping both installed
vignettes would create redundant reading paths for the same concept.

Deleting or moving `ttr-indicators.Rmd` is a documentation-architecture change
that requires updates to `contracts.md`, package-level help, function-level
article links, pkgdown navigation, and documentation discovery tests.

The strategy-development vignette should mention the feature map only after the
basic pulse and target-holdings contract is clear. Feature maps are an authoring
ergonomics layer, not a new execution model.
