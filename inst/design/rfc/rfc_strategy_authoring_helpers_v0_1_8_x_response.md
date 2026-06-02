# RFC Response: Strategy Authoring Helpers (v0.1.8.x)

**Status:** Response-stage adversarial review. Not accepted. Not
authorized implementation scope.
**Cycle:** v0.1.8.x ergonomics.
**Relates to:** `rfc_strategy_authoring_helpers_v0_1_8_x_seed.md`;
consumes
`rfc_strategy_callback_contract_addendum_v0_1_8_10_synthesis.md` as
binding substrate.
**Authored:** Codex (response stage; seed author was Claude per
`rfc_cycle.md` section "Role rotation").

## Summary verdict

Support the direction, but push to seed v2 before synthesis. The seed's
load-bearing premise is stale: ledgr already has a public, exported,
tested, documented strategy helper pipeline (`ledgr_signal`,
`ledgr_selection`, `ledgr_weights`, `ledgr_target`, `signal_return`,
`select_top_n`, `weight_equal`, `target_rebalance`). The next seed should
reframe this RFC as an extension and possible naming consolidation over that
existing contract, not as a greenfield helper library. Q2's use of
`ledgr_target` is verified and directionally right, and Q6's pure-helper
boundary is consistent with the accepted risk, walk-forward, and cost RFCs.
But Q1, Q3, Q4, and Q5 need revision around the existing pipeline,
existing documentation, and the accessor RFC's bound `feature_id` naming.

## Code-citation findings (F1)

| Claim | Verification | Finding |
|---|---|---|
| Existing ctx-bound helpers live at `R/pulse-context.R:375-412`. | Verified: `R/pulse-context.R:375-412` defines `bar`, scalar OHLCV helpers, `position`, `flat`, `hold`, and removed-helper stubs for `targets` and `current_targets`. | Accurate. Note that `targets` and `current_targets` are stubs that abort, not active helpers. |
| Indicator builtins establish a `ledgr_` naming convention. | Verified: `R/indicator-builtins.R:15-31`, `51-68`, `95-112`, and `142-159` define `ledgr_ind_sma`, `ledgr_ind_ema`, `ledgr_ind_rsi`, and `ledgr_ind_returns`. | Accurate but incomplete. The existing strategy helper verbs are exported without a `ledgr_` prefix, while strategy value-type constructors use `ledgr_`. Q1 must reconcile both precedents. |
| Target-risk placeholder is `ledgr_apply_target_risk_noop`. | Verified: `R/backtest-runner.R:542-544` returns `targets` unchanged. `R/fold-engine.R:268` applies it after target validation. | Accurate; line range differs slightly from the seed's `539-541`. |
| Current feature contract is scalar `ctx$feature(instrument_id, feature_id)`. | Verified: `inst/design/contracts.md:380-385` pins scalar `ctx$feature(instrument_id, feature_id)` and warmup `NA` behavior. `R/pulse-context.R:56-96` implements the helper with internal parameter name `feature_name`. | Contract citation is accurate. Seed examples must use the accessor synthesis's bound `feature_id` naming for new public vector helpers. |
| `ledgr_target()` exists and is compatible with Q2 option B. | Verified: `R/strategy-types.R:199-228` defines `ledgr_target(x, universe = NULL, origin = NULL)` as a thin numeric wrapper around full named target quantities. `R/strategy-contracts.R:24-31` unwraps it before validation. | Accurate and load-bearing. Q2 can recommend `ledgr_target`, but the seed should cite the exact signature and the fact that it is a thin wrapper, not a rich target object. |
| Fold engine accepts `list(targets = ...)` and bare numeric vectors. | Verified: `R/fold-engine.R:248-268` rejects intermediate helper types, wraps numeric returns as `list(targets = result)`, requires lists to contain `targets`, validates, then applies target risk. | Accurate. Because `ledgr_target` inherits numeric, bare `ledgr_target` returns work through this numeric path and are unwrapped by validation. |
| Strategy helper layer is missing. | Not verified. The code already has `R/strategy-helpers.R:76-251`, `R/strategy-types.R:108-228`, tests, contracts, exports, vignette sections, and a horizon entry. | Major finding. This invalidates the seed's greenfield framing and requires seed v2. |
| Existing helper pipeline is documented. | Verified: `inst/design/contracts.md:240-272` defines the helper pipeline contract; `vignettes/strategy-development.qmd:456-559` teaches the four-stage pipeline; `vignettes/strategy-development.qmd:762-790` explains troubleshooting. | The seed should not propose creating this documentation from scratch. It should propose extending and updating it. |
| Existing helper pipeline is tested. | Verified: `tests/testthat/test-strategy-types.R:1-65` tests value types and invalid direct outputs; `tests/testthat/test-strategy-reference.R:1-90`, `106-151`, and `153-178` test the helper pipeline and execution. | The RFC must treat these tests as pinned internal examples, even pre-CRAN. |
| Horizon already records helper-extension work. | Verified: `inst/design/horizon.md:1225-1243` states the public helper pipeline already exists and lists future additions: rank weights, inverse-vol weights, normalization, rebalance bands/no-trade zones, and diagnostics. | The seed missed the best roadmap anchor for this RFC. |

## Question-by-question review (F2)

### Q1: Namespace policy

Seed recommendation: global `ledgr_` prefix for helpers.

Response read: support global helpers in principle, but disagree with closing
on `ledgr_` names without a migration/alias decision. Current public exports
already include unprefixed helper verbs: `signal_return`, `select_top_n`,
`weight_equal`, and `target_rebalance` (`NAMESPACE:142-145`). Their value-type
constructors are prefixed (`ledgr_signal`, `ledgr_selection`,
`ledgr_weights`, `ledgr_target`; `NAMESPACE:117-118`, `136`, `140`). The code
therefore has a real split: `ledgr_` for constructors and indicator factories,
plain verbs for pipeline operations.

Seed v2 should decide one of these explicitly:

- keep existing plain verbs and add new helpers in the same style;
- add `ledgr_` aliases while keeping the existing verbs as accepted examples;
- rename the public helper family pre-CRAN and update contracts, vignettes,
  NAMESPACE, and tests together.

Pre-CRAN/no-users makes a rename possible, but not free: accepted examples and
contract text are already coherent around the current names.

### Q2: Return type for sizing helpers

Seed recommendation: `ledgr_dollar_targets()` should return a `ledgr_target`.

Response read: support with a sharper contract. `ledgr_target()` exists at
`R/strategy-types.R:216-228`, requires a non-empty named numeric vector, and
when `universe` is supplied, names must exactly match the universe. The fold
engine accepts it because numeric strategy results are wrapped at
`R/fold-engine.R:251-252`, then `ledgr_validate_strategy_targets()` unwraps
`ledgr_target` at `R/strategy-contracts.R:24-31` and reorders to universe at
`R/strategy-contracts.R:95`.

Hidden dimension: `ledgr_dollar_targets(weights, prices, budget)` cannot return
a valid `ledgr_target` from a partial selection unless it knows the full
universe or receives full-universe named `weights` and `prices`. The existing
`target_rebalance()` solves this by taking `ctx`, validating `ctx$universe`,
creating a full zero vector, then filling selected names
(`R/strategy-helpers.R:211-251`). Seed v2 must either keep that ctx-aware shape, add a `universe`
argument, or require full-universe named vectors. It also needs explicit empty
selection behavior: `ledgr_target()` rejects length-zero targets, so empty
selection must become a full zero target.

### Q3: NA policy

Seed recommendation: permissive default with explicit override.

Response read: support the goal, but the current contract is more precise than
"permissive." Existing helper types allow missingness at the signal stage but
not after it:

- `ledgr_signal()` allows `NA` but rejects infinite values
  (`R/strategy-types.R:108-122`).
- `select_top_n()` ignores missing signal values, returns a classed empty
  selection for all-NA signals, and warns on partial selection
  (`R/strategy-helpers.R:117-145`).
- `ledgr_selection()`, `ledgr_weights()`, and `ledgr_target()` reject missing
  or non-finite executable values (`R/strategy-types.R:143-160`, `180-197`,
  `216-228`).
- `target_rebalance()` warns and targets zero for selected instruments with
  invalid current close prices (`R/strategy-helpers.R:238-249`).

Seed v2 should bind this stage-specific rule: warmup `NA` is normal in signal
inputs; selection helpers must make NA handling explicit; weights and targets
must be finite. Do not generalize to "NA becomes zero" outside the stages that
already make that safe.

### Q4: Tier-2 helper scope

Seed recommendation: six core helpers plus three tier-2 helpers in v0.1.8.x.

Response read: support adding helpers, but the proposed count and names are not
ready because they are not reconciled with the existing pipeline. The current
core already covers top-N selection, equal weights, and target construction:
`signal_return()`, `select_top_n()`, `weight_equal()`, and
`target_rebalance()` (`R/strategy-helpers.R:76-251`). The horizon extension
entry names likely additions: rank-weight helpers, inverse-volatility weights,
explicit normalization helpers, rebalance bands/no-trade zones, and diagnostics
(`inst/design/horizon.md:1225-1243`).

Seed v2 should re-scope Q4 around "which extensions to the existing pipeline,"
not "which nine helpers to introduce." A smaller v0.1.8.10-compatible scope
could be a vectorized update to `signal_return()` or a small set of rank/weight
extensions. A broader helper family can be promoted to v0.1.9 if it needs a
larger documentation and naming pass.

### Q5: Documentation policy

Seed recommendation: roxygen, strategy-development vignette, and
cross-references.

Response read: support, but the seed should update existing docs rather than
create them as new surfaces. `vignettes/strategy-development.qmd:456-559`
already teaches the four-stage helper pipeline, the sizing formula, warmup
behavior, and a full strategy. `vignettes/strategy-development.qmd:762-790`
already has troubleshooting for invalid helper outputs. The contract section at
`inst/design/contracts.md:240-272` is already authoritative for helper
semantics.

Seed v2 should propose:

- updates to the existing helper-pipeline section for `ctx$vec` consumption;
- a naming/migration note if helper names change or aliases are introduced;
- one or two new recipes only if they cover genuinely new patterns;
- doc-test updates for the existing examples rather than a separate parallel
  "common patterns" page by default.

### Q6: Composition with target-risk, walk-forward, and cost layers

Seed recommendation: helpers stay pure; downstream layers chain on top.

Response read: support. The chainable-risk synthesis binds the order as
strategy targets -> target validation -> risk chain -> target validation ->
fill timing -> cost resolution, and risk steps are
`risk_step(targets, ctx, params) -> targets` (chainable-risk synthesis
lines 21-63). It also says public v0.1.9 target risk includes target
transforms, not sizing, cost, liquidity, ranking, or OMS (chainable-risk
synthesis lines 249-258). The walk-forward synthesis preserves the strategy
contract as `function(ctx, params) -> full named numeric target vector`
(`rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md:35`). The cost-API
synthesis keeps cost as experiment-level engine work and says strategies do not
receive cost-related state
(`rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:105-108`).

The seed's "stay pure" boundary is therefore right. The caveat is that any
"cost-aware sizing" helper must stay out of this RFC unless it only consumes
explicit user-provided prices/budget and does not know ledgr's fill-time cost
model. Cost-estimation or cost-sensitive alpha filtering belongs to a separate
future read-only estimator surface.

## Patterns the seed missed (F3)

### Existing helper pipeline

This is not just a pattern; it is a public contract. The seed's four-step
"signal, select, weight, size" model already exists in code, tests, contracts,
and the strategy-development vignette. Seed v2 should explicitly build on:

- value types: `ledgr_signal`, `ledgr_selection`, `ledgr_weights`,
  `ledgr_target`;
- pipeline helpers: `signal_return`, `select_top_n`, `weight_equal`,
  `target_rebalance`;
- rule that intermediate types are invalid strategy outputs and only
  `ledgr_target` unwraps to executable quantities.

### Signal-wrapper and preflight patterns

`ledgr_signal_strategy()` is a documented compatibility wrapper for
tutorial-style signal functions (`vignettes/strategy-development.qmd:843-846`),
and contracts list it as part of strategy semantics around helper outputs
(`inst/design/contracts.md:286`). Helper extensions should avoid duplicating
that wrapper or confusing it with the typed helper pipeline.

### Hold/current-position strategies

Existing ctx helpers include `ctx$flat()` and `ctx$hold()`
(`R/pulse-context.R:383-384`). Many realistic strategies are "hold unless a
trigger fires" rather than "recompute full weights every pulse." The seed's
`ledgr_rebalance_when()` points at this space but does not connect it to
`ctx$hold()`, no-trade zones, or the horizon's rebalance-band entry.

### Long-short, hedged, and multi-leg patterns

The current helper pipeline is explicitly long-only:
`target_rebalance()` rejects negative and levered weights
(`R/strategy-helpers.R:226-230`). The seed acknowledges pair strategies only as
low-benefit cases. A future helper RFC should explicitly defer long-short,
hedge-ratio, and market-neutral helpers until shorting/leverage semantics are
specified, or define a narrow non-levered long-short shape if the maintainer
wants that earlier.

### Sweep and walk-forward strategy templates

Existing helper examples already treat helper parameters as ordinary
`params` (`tests/testthat/test-strategy-reference.R:169-174`). Walk-forward does
not need helper-specific semantics because it preserves the strategy function
contract. A helper RFC can add recipes for parameterized helper strategies, but
it should not introduce a separate sweep/walk-forward template layer.

### Normalization and diagnostics

The horizon entry calls out explicit normalization helpers and diagnostics
(`inst/design/horizon.md:1234-1239`). The seed includes score weighting and
cross-sectional transforms but does not give diagnostics equal visibility.
Diagnostics may be more valuable than another weighting function for
maintainer/debug workflows because they explain how a selected set became
target quantities.

## Composition with accessor RFC (F4)

The seed mostly consumes the accessor RFC correctly, but it needs three
corrections.

First, feature naming must follow the accessor synthesis and contract:
`ctx$vec$feature(feature_id)`, not `ctx$vec$feature(id)`. The scalar contract is
`ctx$feature(instrument_id, feature_id)` at `inst/design/contracts.md:380-385`,
and the accessor synthesis bound `feature_id` for the vector helper.

Second, Q3's open `ctx$idx()` map representation does not block this helper
RFC if helpers operate on named vectors or typed pipeline objects. None of the
existing helpers require `ctx$idx()`: `signal_return()` iterates over
`ctx$universe` and scalar `ctx$feature()` (`R/strategy-helpers.R:76-87`), while
`target_rebalance()` uses `ctx$close(id)` and `ctx$equity`
(`R/strategy-helpers.R:211-251`). A future vectorized helper can consume
`ctx$vec$close` and names directly without choosing the `ctx$idx()` map
implementation.

Third, `ledgr_dollar_targets(weights, prices, budget)` composes naturally with
`ctx$vec$close`, but it must preserve the existing target-construction
contract: full named target quantities, finite values, no silent missing target
names, no short/leverage unless explicitly authorized, and whole-share flooring
if it is intended as a replacement for `target_rebalance()`.

## Decision space the seed didn't open (F5)

### Smaller scope

The smallest useful v0.1.8.10 scope is not six or nine new helpers. It is:
vectorize/adapt the existing helper pipeline to the new `ctx$vec` accessor
surface, then add at most one or two extensions that are already horizon-backed
and low-risk. That would keep v0.1.8.10 close to the accessor addendum without
turning the closing single-core round into a broad UX release.

### Pipeline-stage partition

The seed's "core vs tier-2" split is less natural than the existing
stage-based partition:

- signal constructors and transforms;
- selection helpers;
- weighting helpers;
- target construction;
- trigger/no-trade-zone helpers;
- diagnostics.

Seed v2 should use this partition because it matches the current contracts and
vignette diagrams.

### Hybrid global/ctx-consuming helpers

The seed frames the namespace question as global vs ctx-bound. The current code
already uses a hybrid: all helpers are global functions, but some consume `ctx`
(`signal_return(ctx, ...)`, `target_rebalance(weights, ctx, ...)`) while others
are pure value transforms (`select_top_n(signal, ...)`, `weight_equal(selection)`).
This is a better local precedent than either "all ctx-bound" or "all pure raw
vector functions."

### Naming migration/alias strategy

The seed does not open the question of what happens to existing exported names.
Because the repo already exports `signal_return`, `select_top_n`,
`weight_equal`, and `target_rebalance`, seed v2 must decide whether new
`ledgr_` names are aliases, replacements, or a separate family. This is the
main design decision the current seed misses.

### Declarative `ledgr_strategy()` constructor

A larger future direction is a declarative strategy constructor that composes
signal, selection, weighting, sizing, and triggers as named arguments. That is
larger than this RFC and not needed for v0.1.8.x, but it is the natural
long-horizon alternative if the helper family grows into a mini DSL.

## Recommendation on next step (F6)

Push to seed v2. Direct synthesis would be premature because the seed's primary
framing is wrong against the current codebase. The next seed should:

1. Rebase the RFC on the existing helper pipeline and the 2026-05-25 horizon
   entry.
2. Decide the naming/alias/migration policy for existing unprefixed helpers
   versus proposed `ledgr_` names.
3. Re-scope helper additions as extensions by pipeline stage, not as a
   greenfield six-core-plus-tier list.
4. Align NA policy to the current typed-stage invariant.
5. Correct `ctx$vec$feature(feature_id)` naming and preserve the accessor
   synthesis as binding substrate.

I do not recommend parking the RFC wholesale. The design direction is useful,
and the accessor RFC gives it a stable substrate. I also do not recommend
promoting the whole thing to v0.1.9 yet: a small v0.1.8.10-compatible extension
may still be viable after seed v2 narrows scope. The broad helper-library
expansion, if retained, should be a maintainer window decision after v2.

## Process notes

Role rotation is correct: Claude authored the seed, Codex authored this
response. File naming follows the RFC cycle convention:
`rfc_strategy_authoring_helpers_v0_1_8_x_response.md`.

The main process gap in the seed is context inventory. It read the accessor RFC
but did not anchor on the existing helper pipeline in code, contracts,
vignettes, tests, exports, and horizon. Future seeds for UX/helper work should
start by grepping exported helpers and accepted vignette examples before
proposing new public surface.
