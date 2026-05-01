# ledgr Strategy Helper Specification

**Status:** Draft, not yet implementation-ready
**Target Version:** v0.1.7.2
**Scope:** Strategy authoring helper layer over the existing target-vector
contract
**Non-goals:** Full DSL, sweep dependency packaging, ML pipelines, feature
store, intent extraction, short selling

---

## 1. Purpose

Define a small, explicit helper layer for writing ledgr strategies in a way
that reads like financial reasoning while still executing through the existing
canonical ledgr target-vector contract.

A strategy may be written as a pipeline:

```text
signal -> selection -> weights -> target -> execution
```

This model must:

- preserve execution correctness;
- remain deterministic and reproducible;
- support arbitrary `function(ctx, params)` R strategies;
- be teachable through examples;
- avoid hidden semantics;
- terminate in explicit target quantities before execution.

This document is a design specification for a proposed v0.1.7.2 helper layer.
It does not introduce an alternate engine, alternate pulse loop, alternate fill
model, or alternate result path.

---

## 2. Strategy Contract Boundary

The v0.1.7 public strategy signature remains:

```r
function(ctx, params) -> target
```

The canonical execution contract remains:

```text
strategy output received by the runner must be a full named numeric target
vector of desired instrument quantities.
```

The helper layer may introduce intermediate objects:

```text
ledgr_signal -> ledgr_selection -> ledgr_weights -> ledgr_target
```

Only `ledgr_target` reaches the existing strategy-result validator. A
`ledgr_target` is a thin S3 wrapper around a full named numeric vector of target
quantities. It is not a weight vector, order object, or signal object.

### Required Contract Update

When this helper layer is implemented, `contracts.md` must be updated to say:

- core execution still consumes target quantities only;
- helper pipelines may use signals, selections, and weights internally;
- helper pipelines must terminate in `ledgr_target` or a plain full named
  numeric target vector before execution;
- `ledgr_target` is accepted by the strategy result validator after unwrapping
  to its numeric target vector.

Until those validator changes exist, this specification is not implemented.

---

## 3. Helper Signature Convention

All pipeline helpers take the piped object as the first argument.

If `ctx` is required, `ctx` is always the second argument.

Examples:

```r
weight_equal(selection)
weight_inverse_vol(selection, ctx, window = 63)
target_rebalance(weights, ctx, equity_fraction = 1.0)
```

Signal constructors are the exception because they start from the context:

```r
signal_return(ctx, lookback = 20)
```

---

## 4. Core Types

All helper types are public S3 classes and value types. They carry metadata for
printing and diagnostics only. They do not carry hidden execution instructions.

### 4.1 `ledgr_signal`

```text
named numeric vector of scores per instrument
```

Names must be instrument IDs. Values may be `NA_real_`; selection helpers define
how `NA` is handled.

### 4.2 `ledgr_selection`

```text
named logical vector where TRUE means selected
```

This is the only supported representation for selections.

### 4.3 `ledgr_weights`

```text
named numeric vector of target portfolio weights
```

Weights may be unnormalized. Negative weights are rejected by target
constructors in v0.1.7.2 because ledgr does not yet define public short-selling
semantics.

### 4.4 `ledgr_target`

```text
full named numeric vector of target quantities
```

Names must exactly match `ctx$universe`. Values are desired quantities after the
next fill. `ledgr_target` must unwrap to the same shape expected from a plain
strategy target vector.

---

## 5. Type Coercion Rules

Type coercion is stage-specific.

```text
Signal helpers accept:
  ledgr_signal OR named numeric vector

Selection helpers accept:
  ledgr_signal OR named numeric vector

Weight helpers accept:
  ledgr_selection OR named logical vector

Target helpers accept:
  ledgr_weights
```

Helpers do not coerce across stages.

Example:

```text
weight_equal() does not accept named numeric vectors.
```

Rationale: numeric vectors are ambiguous. At the signal stage they are scores;
at the weight stage they are allocation weights. The helper layer must not infer
intent from shape alone.

---

## 6. Helper Families

### 6.1 Signal Helpers

```r
signal_*(ctx, ...) -> ledgr_signal
```

Signal helpers are read-only wrappers over the feature engine.

Example:

```text
signal_return(ctx, lookback = 20)
requires feature_id "return_20" to exist
```

If the feature ID is missing, the helper must fail with a classed error naming
the missing feature ID and reminding the user to register the corresponding
indicator in `ledgr_experiment()`.

Implementation for v0.1.7.2:

```text
Use ctx$feature(instrument_id, feature_id) for each instrument in ctx$universe.
The first reference helper uses `ledgr_ind_returns(lookback)` so it does not
expand the indicator surface.
```

### 6.2 Signal Transforms

```r
signal_rank(signal, ...) -> ledgr_signal
signal_zscore(signal, ...) -> ledgr_signal
```

Transforms must be explicit. No helper silently normalizes scores unless that
normalization is the named purpose of the helper.

### 6.3 Signal Combination

Normalization must be explicit.

```r
signal_combine(
  signal_rank(signal_return(ctx)),
  signal_rank(signal_quality(ctx)),
  weights = c(0.7, 0.3)
)
```

No hidden normalization occurs.

### 6.4 Selection Helpers

```r
select_*(signal, ...) -> ledgr_selection
```

Recommended initial helper:

```r
select_top_n(signal, n)
```

Edge behavior:

```text
- NA values are ignored
- if fewer than n assets are available, select all available assets and warn
- if no assets are available, return an empty selection and warn
```

Tie-breaking:

```text
Break ties deterministically by instrument_id in alphabetical order.
```

### 6.5 Weight Helpers

```r
weight_*(selection, ...) -> ledgr_weights
```

Recommended initial helper:

```r
weight_equal(selection)
```

Empty selection produces empty weights.

### 6.6 Weight Constraints

```r
cap_*(weights, ...) -> ledgr_weights
```

Example:

```r
cap_weight(weights, max_weight = 0.10, renormalize = FALSE)
```

Rules:

```text
- default: no renormalization
- renormalization must be explicit
- no silent redistribution
- negative weights are rejected in v0.1.7.2
```

### 6.7 Target Constructors

```r
target_rebalance(weights, ctx, equity_fraction = 1.0)
target_overlay(weights, ctx, allocation = 0.3)
```

Target constructors are the bridge back to the existing execution contract.
They produce `ledgr_target` objects that unwrap to full target vectors.

---

## 7. Target Construction

### 7.1 Quantity Calculation

```text
price_i = ctx$close(asset_i)
raw_qty_i = (weight_i * equity_fraction * equity) / price_i
qty_i = floor(raw_qty_i)
```

If `price_i` is `NA`, non-finite, or less than or equal to zero:

```text
- emit a classed warning naming asset_i
- assign target quantity 0 for target_rebalance()
- preserve current quantity for target_overlay()
```

Target constructors must never return a partial target vector. The output must
always span the full universe.

### 7.2 Equity Timing

```text
equity is evaluated at decision time using the current pulse state
fills occur at next open, so small drift is expected
```

This drift must be documented in Rd examples for target constructors.

### 7.3 Weight Normalization Behavior

```text
target_rebalance applies weights as-is

if sum(abs(weights)) < 1:
  portfolio is under-invested

if sum(abs(weights)) > 1:
  error because leverage is not supported in v0.1.x
```

No implicit normalization occurs.

### 7.4 Negative Weights

Negative weights are rejected by target constructors in v0.1.7.2 with a classed
error.

Rationale: ledgr does not yet define public short-selling semantics, margin
rules, borrow costs, or broker-style short lifecycle behavior.

### 7.5 Rebalance Semantics

`target_rebalance()` defines a full desired portfolio.

```text
weights names present in input:
  target computed quantity

universe names absent from weights:
  target quantity 0
```

Empty weights therefore produce `ctx$flat()`.

Override explicitly when no selection should mean "do nothing":

```r
if (sum(selection) == 0) return(ctx$hold())
```

### 7.6 Overlay Semantics

`target_overlay()` preserves existing holdings for assets absent from the
weights vector.

```text
weights names present in input:
  target computed quantity

universe names absent from weights:
  target current quantity
```

An asset present in the weights vector with weight `0` explicitly targets flat.
An asset absent from the weights vector is preserved.

For overlay helpers, "selected assets" means exactly the instruments whose names
are present in the `ledgr_weights` vector. It does not mean assets with non-zero
weights, and it does not refer back to the original `ledgr_selection` object
after weights have been constructed.

---

## 8. Control Flow

Rebalance gates remain ordinary R control flow:

```r
if (!condition) return(ctx$hold())
```

There is no pipeline abstraction for time gates in v0.1.7.2.

---

## 9. Empty Selection Behavior

```text
empty selection
-> empty weights
-> target_rebalance()
-> flat target
```

Rationale:

```text
rebalance semantics define the full desired portfolio
empty pipeline means empty portfolio
```

Hold behavior must be explicit:

```r
if (sum(selection) == 0) return(ctx$hold())
```

---

## 10. Sweep Dependency Contract

The following dependency declaration API is explicitly deferred to v0.1.8 sweep
mode:

```r
ledgr_experiment(
  strategy_helpers = list(...),
  strategy_packages = c(...),
  strategy_globals_ok = c(...)
)
```

Reason: dependency packaging only becomes user-visible once strategies need to
be transported reliably into parallel sweep workers. Shipping those arguments in
v0.1.7.2 would create dead public surface before sweep mode exists.

The v0.1.8 sweep spec owns:

- recursive helper dependency analysis;
- package declaration checks;
- static-analysis false-positive allowlists;
- closure bundle size warnings;
- worker transport compatibility.

v0.1.7.2 helpers must still avoid hidden session state, but no new
`ledgr_experiment()` dependency declaration arguments are introduced in this
cycle.

---

## 11. Print Methods

All helper types print:

```text
- class and number of instruments
- origin/helper name where known
- summary statistics
- top 3 and bottom 3 values where meaningful
```

Example:

```text
<ledgr_signal> [12 assets]
origin: signal_return
non-NA: 10/12

AAA  0.182
BBB  0.114
CCC  0.097
...
JJJ -0.031
KKK -0.044
LLL     NA
```

Print methods must not mutate helper objects or persistent ledgr artifacts.

---

## 12. Reference Strategies

Reference strategies should live in:

```text
tests/testthat/test-strategy-reference.R
```

They serve as:

```text
- acceptance tests
- documentation examples
- regression tests for helper edge behavior
```

---

## 13. Acceptance Criteria

Each reference strategy must:

```text
- run via ledgr_run()
- produce valid target quantities
- preserve the single canonical execution path
- handle:
  - empty selection
  - fewer-than-n selection
  - NA signals
  - invalid prices
  - negative weights
- produce trades or explicitly test empty behavior
```

Implementation tickets must also verify:

```text
- ledgr_target unwraps to a full target vector
- plain full named numeric target vectors still work
- signal/selection/weight objects cannot be returned directly from strategies
- contracts.md is updated when validator support lands
- no sweep/tune APIs or dependency declaration arguments are exported
```

---

## 14. Deferred

```text
- helper zoo beyond the minimal reference set
- sweep worker dependency packaging
- ML pipelines
- feature store
- calendar helpers
- pairs strategies
- intent extraction
- short selling
- leverage
```

---

## Final Summary

```text
ctx -> signal -> select -> weight -> target -> execution
```

---

## Final One-Line Definition

**ledgr strategies express financial logic explicitly and execute it
deterministically.**
