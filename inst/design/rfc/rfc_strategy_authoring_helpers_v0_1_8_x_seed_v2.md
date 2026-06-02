# RFC Seed v2: Strategy Authoring Helpers (v0.1.8.x)

**Status:** Seed v2. Not accepted. Not authorized implementation scope.
**Cycle:** v0.1.8.x ergonomics. Promotion candidate: v0.1.8.10
(internal optimization + minimal extensions) or v0.1.9 (broader pipeline
extension).
**Supersedes:** `rfc_strategy_authoring_helpers_v0_1_8_x_seed.md` (v1,
immutable per `rfc_cycle.md` §"File naming conventions").
**Incorporates:** `rfc_strategy_authoring_helpers_v0_1_8_x_response.md`
(Codex response stage).
**Relates to:**
`rfc_strategy_callback_contract_addendum_v0_1_8_10_synthesis.md` and its
final review — the binding accessor substrate this RFC consumes.
**Authored:** Claude (seed v2; same author as v1 per `rfc_cycle.md`
§"Role rotation").
**Next stage:** synthesis by Codex (different author from v2).

## Revision note

This v2 is a substantial reframing of v1, not a refinement. v1's
load-bearing premise was wrong: ledgr already has a public, exported,
tested, documented strategy helper pipeline that v1 ignored. v2 rebases
the RFC on that pipeline. Most of v1's six core + three tier-2 proposals
collapse because their equivalents already exist as exported helpers.

**Major changes from v1:**

- **Framing flipped from greenfield to extension.** v1 proposed
  `ledgr_top_n`, `ledgr_equal_weight`, `ledgr_dollar_targets`, etc. as
  new helpers. v2 acknowledges that `select_top_n`, `weight_equal`,
  `target_rebalance` already exist at `R/strategy-helpers.R:117`,
  `:163`, `:211`, are exported by `NAMESPACE:142-145`, tested at
  `tests/testthat/test-strategy-reference.R:1-178`, and documented at
  `vignettes/strategy-development.qmd:456-559`. The RFC is about
  extending this pipeline, not introducing a parallel one.
- **Q1 naming reframed.** The existing pattern is split: value types
  use `ledgr_` prefix (`ledgr_signal`, `ledgr_selection`,
  `ledgr_weights`, `ledgr_target` at `R/strategy-types.R:108`, `:143`,
  `:180`, `:216`); pipeline verbs are unprefixed (`signal_return`,
  `select_top_n`, `weight_equal`, `target_rebalance`). Real question
  is policy for NEW helpers given this existing split. v2 recommends
  preserving the split.
- **Q2 sharper.** `ledgr_target()` exists at
  `R/strategy-types.R:216-228` with signature
  `function(x, universe = NULL, origin = NULL)`. Q2 still recommends
  returning `ledgr_target` from sizing helpers, but v2 adds the
  partial-selection problem: `ledgr_target()` rejects length-zero
  vectors and requires names matching universe when `universe` is
  supplied. New sizing helpers need ctx-awareness OR full-universe
  vectors OR explicit `universe` argument, AND explicit
  empty-selection behavior (zero target, not length-zero).
- **Q3 stage-aligned NA policy.** v1 recommended uniform "permissive
  with override." Codex correctly identified that existing helpers
  have **stage-specific** NA semantics: signal stage allows NA
  (warmup); selection stage handles NA explicitly with classed empty
  selection on all-NA inputs (`R/strategy-helpers.R:117-145`); weights
  and target stage reject non-finite values
  (`R/strategy-types.R:180-228`). v2 binds the stage-specific rule.
- **Q4 scope reframed.** v1 proposed nine new helpers. v2 reframes
  scope around **which extensions to the existing pipeline**, anchored
  on the horizon entry at `inst/design/horizon.md:1225-1243` which
  already names the queue: rank-weight, inverse-volatility weights,
  explicit normalization, rebalance bands / no-trade zones, and
  diagnostics. v2 proposes a per-stage extension set.
- **Q5 docs updated, not duplicated.** v1 proposed a parallel "Common
  strategy patterns" vignette section. v2 proposes updating the
  existing pipeline section at
  `vignettes/strategy-development.qmd:456-559` plus the troubleshooting
  section at `:762-790`, plus the contract at
  `inst/design/contracts.md:240-272`.
- **Q6 confirmed.** Response F2 Q6 verified the "stays pure" boundary
  is consistent with chainable-risk, walk-forward, and cost-API
  syntheses. Recorded as bound without changes.

**Minor changes from v1:**

- Citation `R/backtest-runner.R:539-541` corrected to `:542-544` per
  response F1.
- `ctx$vec$feature(feature_id)` parameter naming per accessor
  synthesis binding (matches the addendum cycle's correction).
- `targets` and `current_targets` listed in `R/pulse-context.R:385-396`
  are removal stubs (raise `ledgr_context_helper_removed`), not active
  helpers — per accessor RFC final-review informational item #2.

**New (added per response findings):**

- **Naming policy decision** as an explicit question (was implicit in
  v1 Q1).
- **Partial-selection contract** for sizing helpers (was missing in
  v1).
- **Per-stage extension table** replacing v1's "core + tier-2" split
  (matches existing contract shape).
- **Hold / no-trade-zone pattern recognition** per response F3:
  realistic strategies often "hold unless trigger fires." Connects
  `ctx$hold()` (already exists at `R/pulse-context.R:384`) with new
  rebalance-band helpers from the horizon entry.
- **Long-short / hedged deferral** per response F3:
  `target_rebalance` at `R/strategy-helpers.R:226-230` rejects
  negative and levered weights. Long-short helpers require
  shorting/leverage contract semantics not in v0.1.8.x scope.
- **Diagnostics as first-class category** per response F3: horizon
  entry calls out diagnostics; v1 gave them zero visibility. v2
  records as one of the per-stage extension categories.

**What stayed from v1:**

- Architectural intent: declarative pipeline composition is the UX
  north star; common patterns deserve first-class authoring support.
- Q6 boundary: helpers stay pure; downstream target-risk and
  cost-model layers chain on top (response F2 Q6 confirmed).
- Pre-CRAN-no-external-users framing per `rfc_cycle.md`
  §"Pre-CRAN-no-users framing": no external migration burden but
  internal coherence (existing contract text, tests, vignette
  examples) still matters.

## Problem (revised)

ledgr's existing strategy helper pipeline gives authors a typed,
four-stage composition: `signal_return()` → `select_top_n()` →
`weight_equal()` → `target_rebalance()`, with value types
(`ledgr_signal`, `ledgr_selection`, `ledgr_weights`, `ledgr_target`)
enforcing that only the final stage produces executable targets. This
pipeline is exported, tested, documented, and pinned by contract at
`inst/design/contracts.md:240-272`.

Two gaps remain:

1. **The pipeline doesn't yet consume the v0.1.8.10 accessor surface.**
   `signal_return()` iterates over `ctx$universe` calling scalar
   `ctx$feature()` per instrument (`R/strategy-helpers.R:76-87`);
   `target_rebalance()` calls `ctx$close(id)` per selected instrument
   (`R/strategy-helpers.R:211-251`). Both could consume `ctx$vec$close`,
   `ctx$vec$feature(feature_id)`, and `ctx$vec$positions` internally
   for performance — at xlarge universe scale, the loop-based access
   pattern leaves measurable speed on the table that the accessor RFC
   was designed to recover.
2. **The pipeline has a documented future-extension queue that
   hasn't been scoped.** The horizon entry at
   `inst/design/horizon.md:1225-1243` lists pipeline extensions
   already on the roadmap: rank-weight helpers, inverse-volatility
   weights, explicit normalization, rebalance bands / no-trade zones,
   and diagnostics. These extensions cover common strategy patterns
   (volatility-weighted baskets, threshold-triggered rebalancing,
   ranked-momentum strategies) that authors currently write inline.

Both gaps are real ergonomics + performance lanes that fit the
v0.1.8.x single-core arc plus its ergonomics tail. Neither requires
introducing new pipeline architecture; both extend what's already
there.

## Background / current state (corrected per response F1)

The existing strategy helper layer:

**Value types** (`R/strategy-types.R`):
- `ledgr_signal(x, universe = NULL, origin = NULL)` at line 108. Allows
  `NA` (warmup); rejects infinite values.
- `ledgr_selection(x, universe = NULL, origin = NULL)` at line 143.
  Classed selection result; rejects missing/non-finite executable
  values.
- `ledgr_weights(x, universe = NULL, origin = NULL)` at line 180.
  Classed weight result; rejects missing/non-finite.
- `ledgr_target(x, universe = NULL, origin = NULL)` at line 216. Thin
  numeric wrapper around full named target quantities; rejects
  length-zero; requires names matching universe when `universe`
  supplied.

**Pipeline verbs** (`R/strategy-helpers.R`):
- `signal_return(ctx, lookback = 20L)` at line 76. Computes per-universe
  trailing returns via scalar `ctx$feature()`.
- `select_top_n(signal, n)` at line 117. Returns classed selection;
  ignores NA signal values; classed empty selection on all-NA; warns
  on partial selection.
- `weight_equal(selection)` at line 163. Equal weights over selection.
- `target_rebalance(weights, ctx, equity_fraction = 1.0)` at line 211.
  Sizes targets to `ctx$equity * equity_fraction`, validating
  `ctx$universe`, building full zero vector, filling selected names;
  rejects negative/levered weights at line 226-230; warns and targets
  zero for selected instruments with invalid current close prices.

**Strategy contract acceptance** (`R/fold-engine.R:248-268`,
`R/strategy-contracts.R:24-31`, `R/strategy-contracts.R:95`):
- Rejects intermediate helper types as strategy outputs.
- Wraps bare numeric returns as `list(targets = result)`.
- Requires lists to contain `targets`; unwraps `ledgr_target` before
  validation; reorders to universe order.

**Signal-wrapper compatibility** (`R/signal-strategy.R` and
`vignettes/strategy-development.qmd:843-846`):
- `ledgr_signal_strategy()` wraps tutorial-style signal functions.
- Contracts list it as part of strategy semantics around helper
  outputs (`inst/design/contracts.md:286`).

**Naming exports** (`NAMESPACE`):
- Value types: `ledgr_signal` (118), `ledgr_selection` (117),
  `ledgr_weights` (140), `ledgr_target` exported elsewhere.
- Verbs: `select_top_n` (142), `signal_return` (143),
  `target_rebalance` (144), `weight_equal` (145).
- Compatibility: `ledgr_signal_strategy` (119).
- S3 print methods: `print.ledgr_selection` (38), `print.ledgr_signal`
  (39), `print.ledgr_weights` (45).

**Tests** (`tests/testthat/`):
- `test-strategy-types.R:1-65` tests value types and invalid direct
  outputs.
- `test-strategy-reference.R:1-90, 106-151, 153-178` tests the
  helper pipeline and execution.

**Documentation** (`vignettes/strategy-development.qmd`):
- `:456-559` teaches the four-stage pipeline, sizing formula, warmup
  behavior, and a full strategy example.
- `:762-790` covers troubleshooting for invalid helper outputs.
- `:843-846` documents the compatibility wrapper.

**Contract pin** (`inst/design/contracts.md:240-272`):
- Defines the helper pipeline contract authoritatively.

**Horizon extension queue** (`inst/design/horizon.md:1225-1243`):
- States the public helper pipeline already exists.
- Lists future additions: rank-weight, inverse-volatility weights,
  normalization, rebalance bands / no-trade zones, and diagnostics.

## Proposed direction

Extend the existing pipeline in two passes:

**Pass 1 — Internal optimization, no public surface change
(v0.1.8.10 candidate).** Update `signal_return()` and
`target_rebalance()` implementations to consume the accessor RFC's
`ctx$vec` surface where it speeds them up: `signal_return()` reads
through `ctx$vec$feature(feature_id)` instead of scalar
`ctx$feature(id, feature_id)` per universe member; `target_rebalance()`
reads through `ctx$vec$close` and `ctx$vec$positions` instead of scalar
helpers per selected instrument. This is implementation work, not RFC
work — no contract change, no user-visible behavior change. **The RFC
records this as an expected implementation deliverable** alongside the
accessor RFC tickets, not as a separate authoring-surface decision.

**Pass 2 — Pipeline extensions, new public helpers per stage
(v0.1.8.10 or v0.1.9 candidate).** Add new helpers from the horizon
entry's queue. Scope is per-stage: each stage gets zero-to-three
extensions. v2 proposes a candidate set; final scope is Q4 below.

### Candidate per-stage extension set

| Stage | Existing | Candidate additions |
|---|---|---|
| Signal | `signal_return` | `signal_zscore(signal)`, `signal_rank(signal)` — cross-sectional transforms; produce `ledgr_signal` |
| Selection | `select_top_n` | `select_bottom_n(signal, n)`, `select_percentile_band(signal, lo, hi)` — symmetric and ranged selection variants; produce `ledgr_selection` |
| Weighting | `weight_equal` | `weight_score(selection, signal)`, `weight_inverse_vol(selection, vol)` — proportional and risk-parity weighting; produce `ledgr_weights` |
| Target | `target_rebalance` | `target_dollar(weights, ctx, budget)` — alternative sizing that takes explicit budget instead of computing from `ctx$equity * equity_fraction`; produces `ledgr_target` |
| Trigger | — (none) | `rebalance_when_drift(current, target, threshold)`, `rebalance_band(weights, band)` — explicit rebalance triggers; produce logical masks consumed by `target_rebalance` and friends |
| Diagnostics | — (none) | `helper_diagnostics(stage_result)`, `pipeline_summary(...)` — explain what a pipeline run did (which instruments were selected, why, what weights they got, what the final dollar targets are) |

### Naming policy (per Q1)

Preserve the existing split:

- **New value-type constructors get `ledgr_` prefix** (no current value
  types are added; this is for consistency if any future RFC adds
  them).
- **New pipeline verbs stay unprefixed**: `signal_zscore`,
  `select_bottom_n`, `weight_score`, `target_dollar`,
  `rebalance_when_drift`, `helper_diagnostics`, etc.

This matches the existing pattern at NAMESPACE lines 117-145, the
contract at `inst/design/contracts.md:240-272`, and the vignette
teaching at `vignettes/strategy-development.qmd:456-559`. No
deprecation, no aliases, no rename. Pre-CRAN window for naming change
exists but isn't being used because the existing pattern is coherent.

## Backward compatibility

Pre-CRAN with zero known external users. Per `rfc_cycle.md`
§"Pre-CRAN-no-users framing", no external migration cost. Internal
coherence considerations:

- **All existing exported helpers continue to work unchanged.**
  Signature, behavior, and validation rules at
  `R/strategy-helpers.R:76-251` and `R/strategy-types.R:108-228`
  remain stable.
- **Pass 1 internal optimization is contract-preserving.** The
  pipeline verbs' inputs, outputs, and value types stay the same; only
  the internal `ctx` access pattern changes. Existing tests at
  `tests/testthat/test-strategy-reference.R` continue to pass without
  modification.
- **Pass 2 additions are purely additive.** New helpers don't replace
  existing ones; existing strategy fixtures continue to work; new
  helpers fit the existing stage classification.
- **Contract pin at `inst/design/contracts.md:240-272`** extends, does
  not replace. Existing language about the four-stage pipeline is
  preserved; new helpers are added alongside.
- **Vignette at `vignettes/strategy-development.qmd:456-559`** updates
  in place to (a) note `ctx$vec` consumption in Pass 1 implementation,
  (b) document new helpers in their stage sections, (c) update the
  troubleshooting at `:762-790` for new helper error classes.

## Dependencies

This RFC depends on the accessor RFC closing:
`rfc_strategy_callback_contract_addendum_v0_1_8_10_synthesis.md`
(closed; final review approved). The Pass 1 internal optimization
consumes `ctx$vec$close`, `ctx$vec$positions`, and
`ctx$vec$feature(feature_id)` per the accessor synthesis's bindings.

Pass 2 additions don't depend on the accessor RFC structurally —
they're pure functions over value-type objects and existing ctx
helpers — but Pass 1 optimization benefits compound with the accessor
RFC. Implementing Pass 1 ahead of or alongside the accessor RFC
implementation keeps the optimization lane's per-lane attribution
clean.

No other RFC blocks this one.

## Open questions

Six questions need maintainer decision before any implementation
ticket is cut. Q1, Q4 are reframed from v1; Q3, Q5 are refined per
response findings; Q2 sharpens v1; Q6 is verified-correct from
response F2.

### Q1: Naming policy for new helpers

Per response F1 + F2 Q1 findings: the existing naming split is
`ledgr_` prefix for value types, unprefixed verbs for pipeline
operations. v2 recommends preserving this split (new verbs unprefixed,
new value types `ledgr_`-prefixed if any are added).

Three candidates:

- **Preserve existing split** (recommended). New verbs:
  `signal_zscore`, `select_bottom_n`, `weight_score`, `target_dollar`,
  `rebalance_when_drift`, `helper_diagnostics`. Matches current
  exports.
- **Add `ledgr_` aliases for all new and existing verbs, keep
  existing verbs as accepted examples.** Doubles the export surface
  but makes the family more discoverable. Pre-CRAN window permits.
- **Rename pre-CRAN to `ledgr_` prefix everywhere.** Cleanest
  long-term but requires updating
  `inst/design/contracts.md:240-272`, the vignette,
  `tests/testthat/test-strategy-reference.R`, NAMESPACE, and any
  accepted examples in a single coordinated change.

**Recommended: preserve existing split.** Maintainer decision: confirm
or pick alternative.

### Q2: Sizing-helper signature and partial-selection contract

`ledgr_target()` exists at `R/strategy-types.R:216-228` with signature
`function(x, universe = NULL, origin = NULL)`. New sizing helpers
(`target_dollar` candidate above) must return `ledgr_target` per Q2
v1 recommendation, but face the partial-selection problem because
`ledgr_target()` rejects length-zero and requires names matching
universe.

Three candidate signatures:

- **ctx-aware**, matching existing `target_rebalance(weights, ctx,
  equity_fraction)`: `target_dollar(weights, ctx, budget)` takes ctx,
  reads `ctx$universe`, builds full zero vector, fills selected
  names, returns `ledgr_target`. Empty selection produces a
  full-zero `ledgr_target`. **Recommended** — matches existing
  contract.
- **Universe-arg**, no ctx: `target_dollar(weights, prices, budget,
  universe)`. More functional but requires the strategy author to
  pass `ctx$universe` explicitly every call.
- **Full-universe-required**, no expansion: takes
  full-length-named-universe-aligned `weights` and `prices` vectors;
  errors if length doesn't match. Composes naturally with
  `ctx$vec$close` but breaks composition with selection helpers that
  produce sparse selections.

**Recommended: ctx-aware signature, matching `target_rebalance`.**
Empty-selection behavior: produce zero `ledgr_target`, not error.

### Q3: NA-handling policy (stage-aligned per response F2 Q3)

v1 recommended uniform "permissive with override." Response F2 Q3
correctly identified that the existing pipeline is more precise:

- **Signal stage**: allow `NA` (warmup). `ledgr_signal()` rejects
  infinite values but accepts `NA`
  (`R/strategy-types.R:108-122`).
- **Selection stage**: explicit NA handling. `select_top_n()` ignores
  NA signal values, returns classed empty selection on all-NA,
  warns on partial selection (`R/strategy-helpers.R:117-145`).
- **Weights stage**: reject missing/non-finite executable values
  (`R/strategy-types.R:180-197`).
- **Target stage**: reject missing/non-finite
  (`R/strategy-types.R:216-228`). `target_rebalance()` warns and
  targets zero for selected instruments with invalid close prices
  (`R/strategy-helpers.R:238-249`).

**Recommended: bind the stage-specific rule.** New helpers must match
the stage's existing semantics. Specifically:

- `signal_zscore`, `signal_rank` accept NA inputs (consistent with
  signal stage), produce NA-allowing `ledgr_signal`.
- `select_bottom_n`, `select_percentile_band` ignore NA signal
  values (matching `select_top_n`), produce classed empty selection
  on all-NA.
- `weight_score`, `weight_inverse_vol` reject NA inputs; if a
  weighting input has NA, the helper either errors with a useful
  message or excludes that instrument from selection.
- `target_dollar` matches `target_rebalance` semantics for invalid
  prices (warn + zero, not error).
- `rebalance_when_drift`, `rebalance_band`, diagnostics: NA-safe;
  document explicit policy per helper.

No uniform "permissive with override." Stage rules win.

### Q4: Per-stage extension scope for v0.1.8.10 vs v0.1.9

The candidate per-stage extension table proposes 11 new helpers.
Question is which subset ships in v0.1.8.10 alongside the accessor RFC
implementation versus deferring to v0.1.9.

Three candidate scopes:

- **Pass 1 only in v0.1.8.10 (internal optimization), Pass 2 in
  v0.1.9.** Smallest. Keeps v0.1.8.10 focused on the single-core
  arc's optimization theme. Helpers RFC promotes to v0.1.9 ergonomics
  release. **Recommended** for v0.1.8.10 scope discipline.
- **Pass 1 + minimal Pass 2 in v0.1.8.10.** Add `target_dollar` and
  `rebalance_when_drift` plus `select_bottom_n` (low-risk, high-fit
  with the accessor RFC's cross-sectional vector pattern). Defer
  `weight_score`, `weight_inverse_vol`, `signal_zscore`,
  `signal_rank`, `select_percentile_band`, and diagnostics to v0.1.9.
- **Pass 1 + full Pass 2 in v0.1.8.10.** All 11 candidate helpers.
  Broadest scope; v0.1.8.10 becomes both single-core closeout AND a
  helpers release. High coordination cost.

**Recommended: Pass 1 only in v0.1.8.10, Pass 2 in v0.1.9.** The
v0.1.8.10 round closes the single-core arc and benefits from staying
disciplined. The helpers RFC promotes to v0.1.9 ergonomics release.
Maintainer decision: confirm or pick alternative.

### Q5: Documentation policy

Existing documentation surfaces:
- `vignettes/strategy-development.qmd:456-559` teaches the four-stage
  pipeline.
- `vignettes/strategy-development.qmd:762-790` troubleshoots invalid
  helper outputs.
- `inst/design/contracts.md:240-272` is the authoritative helper
  pipeline contract.
- `vignettes/strategy-development.qmd:843-846` documents the signal
  wrapper.

v2 proposes:

- **Update the existing pipeline section** at
  `vignettes/strategy-development.qmd:456-559` for Pass 1 — note that
  `signal_return` and `target_rebalance` consume `ctx$vec` internally
  for performance at xlarge universe sizes; no user-facing API
  change.
- **Add new helpers to the existing stage sections** for Pass 2 —
  each new helper documented in its stage's section, not as a
  separate "common patterns" recipe page.
- **Update the troubleshooting section** at `:762-790` for new helper
  error classes from Q3 stage-aligned NA policy.
- **Update the contract** at `inst/design/contracts.md:240-272` to
  list new helpers under their respective stages.
- **Cross-references via roxygen `@seealso`** between scalar helpers
  and pipeline helpers in both directions.

No parallel "common strategy patterns" vignette page. No duplication
of existing teaching.

**Recommended.** Maintainer decision: confirm or modify.

### Q6: Composition with target-risk, walk-forward, and cost-API
(verified-correct per response F2 Q6)

Response F2 Q6 verified the "stays pure" boundary against:
- Chainable-risk synthesis lines 21-63 and 249-258.
- Walk-forward synthesis line 35.
- Cost-API synthesis lines 105-108.

All three accepted RFCs constrain composition consistent with helpers
staying pure. Helpers don't embed target-risk or cost-model logic;
downstream layers chain on top.

Caveat per response F2 Q6: any future "cost-aware sizing" helper must
stay out of this RFC unless it only consumes explicit user-provided
prices/budget and does not know ledgr's fill-time cost model. v2
records this caveat under "Out of scope."

**Recommended: helpers stay pure, downstream layers chain on top.**
Closed by response F2 verification.

## Scope and non-scope

### In scope

**Pass 1 (v0.1.8.10 candidate):**
- Internal optimization of `signal_return` and `target_rebalance` to
  consume `ctx$vec$close`, `ctx$vec$positions`,
  `ctx$vec$feature(feature_id)` where appropriate. No public surface
  change.
- Vignette note that the pipeline now uses the accessor RFC's vector
  surface for performance at xlarge universe sizes.
- Tests demonstrating byte-identical strategy results vs the
  pre-optimization pipeline (parity gate).

**Pass 2 (v0.1.8.10 or v0.1.9 candidate per Q4):**
- New helpers per the candidate set above, at the per-stage scope
  decided in Q4.
- Per-helper roxygen documentation with worked examples.
- Vignette section updates inline at each stage's existing teaching.
- Contract updates at `inst/design/contracts.md:240-272`.
- Tests: per-helper correctness; NA handling per Q3 stage-aligned
  policy; composition parity (helper-composed strategy produces
  byte-identical results vs the same strategy written without the
  new helper).
- Cross-references via roxygen `@seealso`.

### Out of scope

- Removing or deprecating any existing exported helper. `ledgr_signal`,
  `ledgr_selection`, `ledgr_weights`, `ledgr_target`, `signal_return`,
  `select_top_n`, `weight_equal`, `target_rebalance`, and
  `ledgr_signal_strategy` all continue to work unchanged.
- Renaming existing helpers (Q1 recommendation is to preserve the
  split).
- Long-short, hedged, or levered helpers — `target_rebalance` rejects
  negative/levered weights at `R/strategy-helpers.R:226-230`; new
  shorting/leverage semantics require a separate RFC with their own
  contract decisions.
- Cost-aware sizing — per Q6 and the cost-API synthesis at
  `:105-108`, strategies do not receive cost-related state.
- Helpers that touch order routing, execution semantics, or
  fill-timing — target-risk RFC scope, cost-API RFC scope, OMS
  future scope.
- A declarative `ledgr_strategy()` constructor — possible long-horizon
  shape per response F5; not v0.1.8.x scope.
- Compiled-strategy callback boundary — `ledgrcore-spike` repo per
  2026-06-01 horizon K1 update.

## Implementation sketch

**Pass 1 (v0.1.8.10 implementation alongside accessor RFC tickets):**

1. **`R/strategy-helpers.R:76-87`**: update `signal_return()` to read
   from `ctx$vec$feature(feature_id)` where the input feature is
   universe-aligned, falling back to scalar `ctx$feature()` when the
   feature input pattern requires it. Add tests demonstrating
   byte-identical results vs pre-optimization.
2. **`R/strategy-helpers.R:211-251`**: update `target_rebalance()` to
   read from `ctx$vec$close` and `ctx$vec$positions` for the universe-
   alignment step, preserving the existing per-selected-instrument
   validation logic. Add tests demonstrating byte-identical results.
3. **`vignettes/strategy-development.qmd:456-559`**: add a sidebar
   noting Pass 1 consumes `ctx$vec` internally; no API change.

**Pass 2 (v0.1.8.10 or v0.1.9 per Q4 decision):**

1. **New file `R/strategy-helpers-extensions.R`** holding the new
   helpers per the Q4 scope decision. Or extend
   `R/strategy-helpers.R` directly — maintainer call on file
   organization.
2. **Per-helper roxygen** with worked examples.
3. **NAMESPACE exports** for the new helpers.
4. **`tests/testthat/test-strategy-helpers-extensions.R`**: per-helper
   unit tests; Q3 stage-aligned NA tests; composition parity tests.
5. **Vignette updates** inline at each stage section in
   `vignettes/strategy-development.qmd:456-559`.
6. **Troubleshooting updates** at
   `vignettes/strategy-development.qmd:762-790`.
7. **Contract updates** at `inst/design/contracts.md:240-272`.
8. **Cross-references** via roxygen `@seealso`.

Estimated effort: Pass 1 is ~3-5 days alongside the accessor RFC
implementation. Pass 2 is ~1-2 weeks depending on Q4 scope.

## Decision needed

For implementation ticket cut, the maintainer (with optional synthesis
input from Codex) needs to decide:

1. **Q1 naming policy**: confirm "preserve existing split" or pick
   alternative.
2. **Q2 sizing-helper signature**: confirm ctx-aware
   `target_dollar(weights, ctx, budget)` or pick alternative.
3. **Q3 NA policy**: confirm stage-aligned binding.
4. **Q4 v0.1.8.10 vs v0.1.9 scope**: confirm "Pass 1 only in
   v0.1.8.10, Pass 2 in v0.1.9" or pick alternative.
5. **Q5 documentation policy**: confirm "update existing surfaces in
   place" or scope down.
6. **Q6 boundary with target-risk / cost-model**: verified-correct;
   no decision needed.

After those decisions, the synthesis closes the RFC and the
implementation ticket can be cut.

## Sources

- `rfc_strategy_authoring_helpers_v0_1_8_x_seed.md` (v1, superseded).
- `rfc_strategy_authoring_helpers_v0_1_8_x_response.md` (Codex
  response stage; load-bearing findings absorbed into this v2).
- `rfc_strategy_callback_contract_addendum_v0_1_8_10_synthesis.md`
  (accessor substrate; binding).
- `rfc_strategy_callback_contract_addendum_v0_1_8_10_final_review.md`
  (informational items #2-#4 absorbed).
- `R/strategy-helpers.R:76-251` (existing pipeline verbs).
- `R/strategy-types.R:108-228` (existing value types).
- `R/strategy-contracts.R:24-31, 95` (strategy-output validation and
  universe reordering).
- `R/fold-engine.R:248-268` (fold-engine acceptance of strategy
  results).
- `R/pulse-context.R:375-412` (existing ctx-bound helpers; note
  `targets` and `current_targets` are removal stubs).
- `R/signal-strategy.R` (signal-wrapper compatibility).
- `R/backtest-runner.R:542-544` (target-risk noop placeholder; line
  range corrected from v1).
- `NAMESPACE:117-145` (exports for value types, verbs, and
  compatibility wrapper).
- `inst/design/contracts.md:240-272` (helper pipeline contract).
- `inst/design/contracts.md:286` (signal-wrapper contract).
- `inst/design/contracts.md:380-385` (current ctx$feature scalar
  contract).
- `inst/design/horizon.md:1225-1243` (future helper additions queue —
  rank-weight, inverse-vol, normalization, rebalance bands,
  diagnostics).
- `inst/design/horizon.md` 2026-06-01 substrate framing entry (UX
  north star).
- `vignettes/strategy-development.qmd:456-559` (pipeline teaching).
- `vignettes/strategy-development.qmd:762-790` (troubleshooting).
- `vignettes/strategy-development.qmd:843-846` (signal wrapper docs).
- `tests/testthat/test-strategy-types.R:1-65` (value-type tests).
- `tests/testthat/test-strategy-reference.R:1-178` (pipeline tests
  including parameterized helper strategies at lines 169-174).
- `inst/design/rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md`
  lines 21-63 and 249-258 (chainable-risk boundary verification).
- `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md`
  line 35 (walk-forward strategy-contract preservation).
- `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md`
  lines 105-108 (cost-API strategy boundary).
