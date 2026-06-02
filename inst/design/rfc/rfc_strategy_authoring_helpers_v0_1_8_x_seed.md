# RFC Seed: Strategy Authoring Helpers (v0.1.8.x)

**Status:** Seed v1. Not accepted. Not authorized implementation scope.
**Cycle:** v0.1.8.x ergonomics. Promotion candidate: v0.1.8.10 alongside
the strategy callback contract addendum, or v0.1.9 if v0.1.8.10 closeout
prefers shipping the accessor surface alone first.
**Relates to:**
`rfc_strategy_callback_contract_addendum_v0_1_8_10_seed_v2.md` (the
accessor surface this helper library consumes). This RFC is gated on
that one closing; the accessors are the substrate.
**Authored:** Claude (seed v1).
**Next stage:** response by Codex (different author per `rfc_cycle.md`
§"Role rotation").

## Problem

After the v0.1.8.10 strategy callback contract addendum lands, strategy
authors have universe-aligned vector access through `ctx$vec` plus
scalar helpers through `ctx$close(id)`, `ctx$position(id)`,
`ctx$feature(id, feature_id)`. Both layers give authors **raw access** to
the substrate.

Raw access is not UX. The strategies that motivated the accessor
addendum — cross-sectional momentum, equal-weight basket rebalance, mean
reversion with cross-sectional weighting, regime-conditional allocation
— all share a four-step pattern:

1. **Compute a signal** (per-instrument vector via `ctx$vec$feature(...)`
   or universe-wide derived statistic).
2. **Select** (top-N, percentile band, threshold filter, logical mask).
3. **Weight** (equal across selected, proportional to score, inverse
   volatility, risk parity).
4. **Size** (convert weights + prices + budget to quantity targets, with
   NA-safe handling for missing prices).

Strategy authors today write each of these steps inline. Even with the
accessor surface, the four-step pattern produces 6-10 lines of
engineering boilerplate per strategy (NA guards, valid-price checks,
named-output construction). That boilerplate is:

- Repetitive across strategies (every momentum, mean-reversion, and
  basket strategy reimplements the same NA handling).
- Error-prone (forgetting to guard against `price <= 0` silently
  produces `Inf` targets; forgetting `na.last = TRUE` silently shuffles
  ranks).
- A teaching obstacle (strategy guide vignettes have to show the
  boilerplate every time, which obscures the actual strategy logic).

The v0.1.8.x strategy authoring UX north star is: **strategy code reads
as the strategy logic and nothing else.** Helpers that encapsulate
selection, weighting, and target construction get authors there.

## Background / current state

Three layers of strategy authoring helpers exist today.

**ctx-bound helpers (already first-class):**
- `ctx$close(id)`, `ctx$open(id)`, `ctx$high(id)`, `ctx$low(id)`,
  `ctx$volume(id)` — scalar OHLCV access (`R/pulse-context.R:375-412`).
- `ctx$position(id)` — scalar position lookup.
- `ctx$feature(id, feature_id)` — scalar feature value.
- `ctx$flat()` — flatten all positions (returns zero-target).
- `ctx$hold()` — hold current positions (returns current as targets).
- `ctx$features(id)` — all features for an instrument.

**Indicator-engine helpers (rich set):**
- `ledgr_ind_sma(n)`, `ledgr_ind_ema(n)`, `ledgr_ind_rsi(n)`,
  `ledgr_ind_returns(n)` — built-in indicator constructors
  (`R/indicator-builtins.R`).
- `ledgr_indicator(id, fn, ...)` — custom indicator factory.
- `ledgr_indicator_bundle(...)` — multi-output indicator from one
  computation.

**Target / target-risk helpers (sparse):**
- `ledgr_target(...)` — type-safe target constructor.
- `ledgr_apply_target_risk_noop(targets, ctx, params)` — placeholder
  for future target-risk chain (currently a no-op pass-through at
  `R/backtest-runner.R:539-541`).

**What's missing** is the layer between **substrate access** (which the
v0.1.8.10 addendum provides) and **type-safe output** (`ledgr_target`):
the **declarative pattern composition** layer that turns "compute
signal, select top-N, equal-weight, dollar-size" from four boilerplate
expressions into four function calls.

Backtrader, vectorbt, and zipline-reloaded all have authoring helpers
of various shapes. Backtrader puts them on the strategy class
(`self.order_target_percent()`, `self.position`); vectorbt puts them in
the portfolio class (`Portfolio.from_signals()`); zipline-reloaded puts
them as global functions (`order_target_percent()`, `top_n()`,
`pipeline_output()`). All three converged on "the common patterns
deserve first-class authoring support."

ledgr's existing `ctx$flat()` and `ctx$hold()` are the precedent — small
helpers that turn one-line idioms into one-function calls. The proposal
extends that precedent to the cross-sectional patterns the v0.1.8.10
addendum unlocks.

## Proposed direction

Add a **core helper set** of six functions at package-global scope (with
the `ledgr_` prefix matching `ledgr_run`, `ledgr_sweep`,
`ledgr_indicator`, etc.) plus a **tier-2 helper set** of 5-7 additional
functions covering common-but-less-central patterns.

### Surface sketch

```r
# Selection helpers
ledgr_top_n(scores, n, decreasing = TRUE)        # returns integer indices
ledgr_filter(mask, na_value = FALSE)             # logical → indices, NA-safe

# Weighting helpers
ledgr_equal_weight(selected_idx, universe_n)     # universe-aligned weight vec
ledgr_score_weight(scores, normalize = TRUE)     # proportional, NAs → 0

# Target construction
ledgr_dollar_targets(weights, prices, budget)    # weights + prices + budget → quantities
ledgr_rebalance_when(current, target, threshold) # logical mask of rebalance positions
```

The composition pattern:

```r
strategy_momentum_topn <- function(ctx, params) {
  mom      <- ctx$vec$feature("return_12m")
  selected <- ledgr_top_n(mom, params$top_n)
  weights  <- ledgr_equal_weight(selected, length(mom))
  list(targets = ledgr_dollar_targets(weights, ctx$vec$close, ctx$cash))
}
```

Four function calls. Each call name says what the call does. NA handling
and edge cases (zero or negative prices, all-NA selection, empty mask)
live inside the helpers, not in the strategy.

### Tier-2 helpers (scope decision per Q4 below)

```r
# Additional selection
ledgr_bottom_n(scores, n)                       # symmetric to top_n
ledgr_percentile_band(scores, lo, hi)           # in a percentile range

# Additional weighting
ledgr_inverse_vol_weight(vols)                  # risk parity
ledgr_softmax_weight(scores, temperature)       # softmax

# Cross-sectional aggregates
ledgr_cross_section_rank(values)                # universe rank
ledgr_cross_section_zscore(values)              # z-score
ledgr_cross_section_dispersion(values, method)  # sd / iqr / mad
```

### Behavior guarantees

For the core set:

1. **Universe alignment is preserved.** All weighting and sizing helpers
   take universe-aligned numeric vectors (from `ctx$vec`) and produce
   universe-aligned outputs.
2. **NA values flow predictably.** Selection helpers treat NA scores
   as "rank-last by default" with an explicit `na.last` argument.
   Weighting helpers treat NA inputs as zero weight. Target-sizing
   helpers treat NA or non-positive prices as zero quantity, no error.
3. **No silent infinities.** `ledgr_dollar_targets` guards against
   division-by-zero on zero or NA prices.
4. **Composable.** Helper outputs are the inputs other helpers expect.
   `ledgr_top_n` returns integer indices; `ledgr_equal_weight` takes
   integer indices and universe size; `ledgr_dollar_targets` takes a
   weight vector and a price vector.

For Tier 2: same guarantees apply once scope is decided.

## Backward compatibility

Pre-CRAN with zero known external users. Per `rfc_cycle.md`
§"Pre-CRAN-no-users framing", no external migration cost. Internal
coherence considerations:

- **`ctx$flat()` and `ctx$hold()` continue to work unchanged.** They are
  ctx-bound shortcuts; the new helpers are package-global functions for
  patterns the ctx-bound shortcuts don't cover.
- **`ledgr_target(...)` continues to work unchanged.** The new
  `ledgr_dollar_targets()` returns either a bare named numeric vector
  (Q2 option A) or a `ledgr_target` object (Q2 option B). Either way,
  `ledgr_target(...)` stays available for strategies that want to
  construct targets manually.
- **All existing strategy patterns continue to work.** Strategies that
  don't use the helpers are unaffected. The new helpers are purely
  additive.
- **Documentation policy**: strategy guide vignette gets a "Common
  strategy patterns" section showing the four-step composition for the
  motivating strategy types. Scalar helpers and named patterns stay
  documented at their current layer.

## Dependencies

This RFC is gated on the strategy callback contract addendum RFC
closing (`rfc_strategy_callback_contract_addendum_v0_1_8_10_seed_v2.md`,
or whichever shape its synthesis takes). The helpers consume
`ctx$vec$close`, `ctx$vec$positions`, `ctx$vec$feature(id)` etc.; until
those exist, the helpers can't be implemented cleanly.

Once the addendum closes, this RFC has no further substrate dependencies.
The helpers are pure functions over numeric vectors; they don't need
substrate measurement (Spike 5) results to be designed.

## Open questions

Six questions need maintainer decision before any implementation ticket
is cut.

### Q1: Namespace placement

Three candidate patterns:

- **Global package functions with `ledgr_` prefix** (`ledgr_top_n`,
  `ledgr_equal_weight`, etc.). Matches existing `ledgr_run`,
  `ledgr_sweep`, `ledgr_indicator`, `ledgr_target` convention.
  Discoverable via package autocomplete (`ledgr_<TAB>` enumerates
  authoring helpers alongside engine functions). Composable.
  **Recommended.**
- **ctx-bound helpers under a sub-namespace** (`ctx$select$top_n`,
  `ctx$weight$equal`, `ctx$size$dollar`). More obvious to strategy
  authors that the helpers belong to the strategy callback. But forces
  every helper to be implicitly parameterized by ctx, which most aren't
  — `ledgr_top_n(scores, n)` doesn't need ctx at all.
- **Pure-function `ledgr$<namespace>$<helper>`** style
  (`ledgr$select$top_n`). Cleaner separation but introduces a new
  ledgr-the-namespace concept that doesn't exist today.

The argument against ctx-bound is that most helpers don't need ctx
state — they're pure functions over vectors. The argument against a
namespace object is that R idioms favor package-level functions with
prefixes.

**Recommended: global package functions with `ledgr_` prefix.**
Maintainer decision: confirm or pick alternative.

### Q2: Return type of `ledgr_dollar_targets()`

Two options:

- **Return bare named numeric vector** (`setNames(qty_vec,
  ctx$universe)`). Simplest. The fold engine already accepts this shape
  as a valid target. Composable with existing `list(targets = ...)`
  return idiom.
- **Return `ledgr_target` object.** Type-safe. The fold engine
  recognizes it natively. Gives a place to attach validation metadata.
  Lets future helpers chain (e.g., `targets |>
  ledgr_apply_risk_cap(0.1) |> ledgr_apply_lot_size(100)`).

**Recommended: return `ledgr_target` object.** Pre-CRAN window for type
safety on the target surface; downstream helpers (target risk, cost
model, lot sizing) will benefit from the type contract; minimal cost
because `ledgr_target(...)` already exists. Strategies that prefer the
bare-vector idiom can call `unclass()` or use the bare-vector
`list(targets = ...)` shape directly.

### Q3: NA-handling and edge-case policy

The helpers need consistent NA policy across the set. Without it,
strategy authors trip on inconsistencies (`ledgr_top_n` puts NAs last
but `ledgr_score_weight` errors on NA, etc.). Three policy candidates:

- **Permissive default with explicit override**: NAs flow as zeros or
  rank-last by default; helpers accept an `na.rm`, `na.last`, or
  `na_value` argument to override. Matches base R `mean(na.rm = TRUE)`
  and `rank(na.last = TRUE)` idioms.
- **Strict default with explicit `na_ok = TRUE` opt-in**: helpers
  error on any NA input unless explicitly allowed. Safer but
  more verbose strategy code.
- **Mixed by helper category**: selection helpers default permissive
  (NA = rank-last); weighting helpers default permissive (NA = zero
  weight); target-sizing helpers default permissive (NA price = zero
  quantity); aggregate helpers default strict (NA inputs error unless
  `na.rm = TRUE`).

**Recommended: permissive default with explicit override.** Matches base
R idioms; minimizes strategy boilerplate; the override path is
documented for authors who want strict behavior.

### Q4: Tier-2 scope

Six core helpers ship as the v0.1.8.x scope. Tier-2 has 5-7 more. Which
of them ship in v0.1.8.x and which defer to a later cycle?

Candidates for v0.1.8.x inclusion:

- `ledgr_bottom_n`: trivial (sugar over `ledgr_top_n(scores,
  decreasing = FALSE)` or `ledgr_top_n(-scores)`). Could be a
  documented idiom rather than a helper.
- `ledgr_percentile_band`: covers a common pattern (long bottom
  quintile, short top quintile). Distinct enough from `ledgr_top_n` to
  warrant its own helper.
- `ledgr_inverse_vol_weight`: requires a volatility input (typically a
  feature). Useful but specialized to risk-parity strategies.
- `ledgr_softmax_weight`: specialized to ML-driven strategies.
- `ledgr_cross_section_rank`, `ledgr_cross_section_zscore`,
  `ledgr_cross_section_dispersion`: cross-sectional aggregates that
  compose with the selection / weighting helpers.

**Recommended for v0.1.8.x**: core six + `ledgr_percentile_band` +
`ledgr_cross_section_rank` + `ledgr_cross_section_zscore`. The
percentile band and the two rank/zscore helpers compose naturally with
the core set and cover the next layer of common cross-sectional
patterns. The other four (`bottom_n`, `inverse_vol`, `softmax`,
`dispersion`) defer to a later ergonomics cycle.

Maintainer decision: confirm or modify the v0.1.8.x scope.

### Q5: Documentation policy

The helpers' value is only fully realized if strategy authors can find
them and understand the composition pattern. Three documentation
surfaces:

- **Per-helper roxygen documentation** with examples. Required minimum.
- **Strategy guide vignette section** titled something like "Common
  strategy patterns" with the four-step composition demonstrated for
  each of the motivating strategy types (top-N momentum, equal-weight
  basket, mean reversion, regime-conditional). Recipe-style.
- **Cross-references between scalar helpers and pattern helpers**:
  `?ctx$close` should mention `ledgr_dollar_targets` in See Also;
  `?ledgr_top_n` should mention `ctx$vec$feature` in See Also.

**Recommended: all three.** Roxygen is required; vignette section is
the load-bearing teaching tool; cross-references make discovery
work in both directions.

### Q6: Composition with future target-risk / cost-model layers

The target-risk chain RFC (`rfc_chainable_risk_oms_policy_boundary_synthesis.md`,
v0.1.9 promotion candidate) and the public transaction-cost API RFC
(accepted, v0.1.9.x scope) both introduce additional layers between
"compute targets" and "execute trades." The helpers should compose
cleanly with those layers without baking assumptions.

The composition pattern under those future RFCs is something like:

```r
strategy <- function(ctx, params) {
  signal   <- ctx$vec$feature("return_12m")
  selected <- ledgr_top_n(signal, params$n)
  weights  <- ledgr_equal_weight(selected, length(signal))
  targets  <- ledgr_dollar_targets(weights, ctx$vec$close, ctx$cash)
  
  # Future: target-risk and cost-aware sizing
  # targets  <- targets |> ledgr_apply_position_cap(params$max_pos)
  # targets  <- targets |> ledgr_apply_cost_aware_sizing(ctx, params)
  
  list(targets = targets)
}
```

The helpers in this RFC should NOT embed target-risk or cost-model
logic. They should produce raw quantity targets that downstream layers
can adjust. This means `ledgr_dollar_targets()` takes a `budget`
argument (not implicitly using `ctx$equity` or `ctx$cash`); the
strategy author or a target-risk helper decides how much budget is
available.

**Recommended: helpers stay pure; target-risk and cost-aware layers
chain on top.** Pre-CRAN window for getting the boundary right;
post-CRAN the composition pattern is harder to refactor.

## Scope and non-scope

### In scope (v0.1.8.x)

- Six core helpers as listed in "Surface sketch."
- Three tier-2 helpers per Q4 recommendation: `ledgr_percentile_band`,
  `ledgr_cross_section_rank`, `ledgr_cross_section_zscore`.
- Roxygen documentation for all helpers with worked examples.
- Strategy guide vignette section "Common strategy patterns" showing
  the four-step composition for top-N momentum, equal-weight basket,
  mean reversion, regime-conditional allocation, pair trade (pair
  shown as the case where helpers don't help — honesty matters).
- Tests covering: NA handling per Q3 policy; composition parity (a
  strategy written with helpers produces byte-identical fills/equity
  vs the same strategy written with raw vector code); type-safety of
  `ledgr_dollar_targets()` returning `ledgr_target` per Q2.
- Cross-references between scalar helpers and pattern helpers per Q5.

### Out of scope

- The four tier-2 helpers not selected in Q4 (`ledgr_bottom_n`,
  `ledgr_inverse_vol_weight`, `ledgr_softmax_weight`,
  `ledgr_cross_section_dispersion`). Defer to a later ergonomics
  cycle.
- Helpers that touch order routing, execution semantics, or cost
  models (target-risk RFC scope, public transaction-cost API RFC
  scope).
- Indicator-engine extensions (separate feature-engine RFC).
- Migration of existing strategies to use the helpers. Existing
  strategies continue to work.
- Pipe-friendly chaining infrastructure (`%>%` or `|>` composition
  patterns). The helpers ARE pipe-friendly by virtue of being pure
  functions, but no dedicated pipeline infrastructure is built.

## Implementation sketch

If the RFC closes with "accept," v0.1.8.x implementation work is
roughly:

1. **New file `R/strategy-helpers.R`** holding the nine helper
   functions (six core + three tier-2 per Q4). Pure functions, no
   ctx state, no side effects.
2. **`R/strategy-helpers.R` companion tests** at
   `tests/testthat/test-strategy-helpers.R`: unit tests per helper
   (correctness, NA handling, edge cases); composition parity tests
   (helper-composed strategy vs raw-vector strategy produce
   byte-identical results).
3. **Strategy guide vignette update** at
   `vignettes/strategy-development.qmd`: add "Common strategy
   patterns" section after the "Three access patterns" section the
   v0.1.8.10 addendum implementation adds. Show four recipes
   (momentum top-N, equal-weight basket, mean reversion,
   regime-conditional) plus the pair-trade example as the "helpers
   don't help here" honesty case.
4. **Cross-references**: roxygen `@seealso` tags wiring scalar
   helpers to pattern helpers in both directions.
5. **NAMESPACE export updates** for the nine new functions.
6. **DESCRIPTION update**: no new dependencies (helpers use base R
   `rank`, `order`, `setNames`, etc.).

Estimated effort: ~1-2 weeks of focused work. Most of the work is in
test coverage (each helper needs NA-handling, edge-case, and
composition tests) and the vignette recipes.

## Decision needed

For implementation ticket cut, the maintainer (with optional response
input from Codex) needs to decide:

1. **Q1 namespace**: confirm global `ledgr_` prefix or pick alternative.
2. **Q2 return type**: confirm `ledgr_target` object or accept bare
   named numeric.
3. **Q3 NA policy**: confirm permissive default with explicit
   override or pick alternative.
4. **Q4 tier-2 scope**: confirm v0.1.8.x set or modify.
5. **Q5 documentation policy**: confirm all three surfaces or scope
   down.
6. **Q6 boundary with target-risk / cost-model**: confirm helpers
   stay pure or open a different composition pattern.
7. **Promotion window**: v0.1.8.10 alongside the accessor addendum, or
   v0.1.9 as a follow-up ergonomics release. v0.1.8.10 ships the helpers
   close to when authors will be encountering the accessor surface for
   the first time; v0.1.9 keeps v0.1.8.10 scope tight on the
   single-core arc's optimization theme. Maintainer judgment.

After those decisions, the synthesis document closes the RFC and the
implementation ticket can be cut.

## Sources

- `rfc_strategy_callback_contract_addendum_v0_1_8_10_seed_v2.md` (the
  accessor surface this helper library consumes).
- `inst/design/horizon.md` 2026-06-01 substrate framing entry.
- `R/pulse-context.R:375-412` (existing ctx-bound helpers).
- `R/indicator-builtins.R` (existing indicator helpers as the naming
  convention precedent).
- `R/backtest-runner.R:539-541` (`ledgr_apply_target_risk_noop`
  placeholder for future target-risk chain).
- `inst/design/contracts.md:380-385` (current ctx$feature contract).
- `inst/design/rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md`
  (accepted target-risk chain RFC; helpers must compose cleanly with
  this layer per Q6).
- `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md`
  (accepted walk-forward synthesis; helpers should compose with WF
  candidate-sweep wrappers).
- Backtrader, vectorbt, zipline-reloaded prior art: all three converged
  on first-class authoring helpers for common patterns. ledgr's
  precedent is the existing `ctx$flat()` / `ctx$hold()` shortcuts.
