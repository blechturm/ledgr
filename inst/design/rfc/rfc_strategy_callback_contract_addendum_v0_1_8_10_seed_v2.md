# RFC Seed v2: Strategy Callback Contract Addendum (v0.1.8.10)

**Status:** Seed v2. Not accepted. Not authorized implementation scope.
**Cycle:** v0.1.8.10 single-core optimization round (the closing round of
the v0.1.8.x single-core arc).
**Supersedes:** `rfc_strategy_callback_contract_addendum_v0_1_8_10_seed.md`
(v1, immutable per `rfc_cycle.md` §"File naming conventions").
**Incorporates:** `rfc_strategy_callback_contract_addendum_v0_1_8_10_response.md`
(Codex response stage).
**Authored:** Claude (seed v2; same author as v1 per `rfc_cycle.md`
§"Role rotation").
**Next stage:** synthesis by Codex (different author from v2).

## Revision note

This v2 incorporates the response-stage findings while preserving the
architectural intent of v1. Three of the response's findings invalidated
load-bearing claims in v1; three more surfaced missed dimensions; the
remainder were citation precision fixes. v2 absorbs all of them.

**Major changes from v1:**

- **Q1 (naming) reframed.** v1 proposed direct top-level slots
  (`ctx$close`, `ctx$open`). The response correctly identified that
  `ctx$close`, `ctx$open`, `ctx$high`, `ctx$low`, `ctx$volume`,
  `ctx$position`, `ctx$flat`, `ctx$hold` are already installed as scalar
  **helper functions** on the pulse context
  (`R/pulse-context.R:375-412`), pinned by tests
  (`tests/testthat/test-pulse-context-accessors.R:25-43`) and documented
  in the strategy guide (`vignettes/strategy-development.qmd:174`).
  Direct top-level slots would COLLIDE, not be additive. v2 proposes a
  `ctx$vec` namespace instead.
- **Q4 (feature accessor) reframed.** v1 claimed
  `ctx$feature("sma_20")` is already vector-returning. The response
  correctly identified the current contract as
  `ctx$feature(instrument_id, feature_id)` returning a scalar
  (`R/pulse-context.R:54-96`, `inst/design/contracts.md:380-385`,
  `vignettes/strategy-development.qmd:583-643`). v2 acknowledges
  any vector-feature accessor is **new contract**, not extension; opens
  it as an explicit decision.
- **Positions distinction added.** v1 claimed `ctx$positions` was named
  numeric and integer-indexable. The response correctly identified that
  `ctx$positions` is **sparse named numeric** today, with no universe-
  alignment guarantee (`tests/testthat/test-pulse-context-accessors.R:14`,
  `tests/testthat/test-execution-spec.R:151-170`). v2 keeps
  `ctx$positions` sparse named (no contract shift) and adds
  `ctx$vec$positions` as a separate universe-aligned view.
- **Q6 added (unknown-id semantics).** v1 said `ctx$idx("BAD")` returns
  `NA`. The response correctly identified that existing scalar helpers
  fail loudly with `ctx$universe` in the error message
  (`R/pulse-context.R:511-529`). v2 opens this as a real decision with
  "error by default, `missing = NA` opt-in" as the recommendation.
- **Q7 added (snapshot/retention semantics).** v1 recommended
  "documented convention only" for read-only enforcement. The response
  correctly identified that reusable env-backed slots plus in-place
  vector mutation create state-aliasing risk via `state_update`
  (`R/fold-engine.R` retains `state_prev_mem <- result$state_update`).
  v2 closes this with a deliberate decision: **public ctx stays list
  with fresh slots per pulse; reusable-env optimization is internal-only
  (not exposed via public ctx).** Maintainer-confirmed at v2 authoring.

**Minor changes from v1:**

- Citation: v0.1.8.9 closeout residual is **#1** (R-side substrate),
  not #2 (which is ephemeral phase visibility).
- Line range: `R/fold-engine.R:181-220` for the strategy-visible pulse
  context surface (constructor at 181-194 plus helper attachment at
  197-220), not just 180-194.
- Slot count: "12-slot base list plus helper-added slots" per code-
  citation precision, not "12+ slots".
- Horizon version language: the 2026-06-01 substrate entry uses "v0.1.9"
  generically for substrate work; this RFC targets the v0.1.8.10 round
  specifically. A small horizon-language clarification belongs in the
  v0.1.8.10 closeout, not this RFC.

**What stayed from v1:**

- Architectural intent: integer-indexed accessor pattern matching
  Backtrader's `array.array('d')` + integer-cursor data structure
  choice, as motivated by the 2026-06-01 horizon substrate entry.
- Q2: 1-based indexing.
- Q3: per-backtest caching for the universe→idx map (with refined
  data-structure decision).
- Pre-CRAN no-external-users framing per `rfc_cycle.md` §"Pre-CRAN-no-
  users framing": no external migration cost, but internal coherence
  (accepted vignettes, tests, code citations) still matters.
- Substrate dependency on Spikes 3, 4, 5 in the v0.1.8.10 spike round
  (with refined dependency mapping per response F3).
- Full addendum scope (positions vector + feature vector) per
  maintainer call at v2 authoring.
- Implementation sketch shape.

**"v" disclaimer** (per `rfc_cycle.md` §"v1 / first implementation"):
this RFC uses "v0.1.8.10" as a real roadmap window per
`inst/design/ledgr_roadmap.md`. "seed v2" refers to RFC seed iteration,
not a feature version. No confusion expected.

## Problem (unchanged from v1)

ledgr's current strategy callback contract gives strategy authors a
named-list pulse context with three documented access patterns
(`vignettes/strategy-development.qmd:174-175, 583-643`):

```r
strategy_fn <- function(ctx, params) {
  # Pattern 1: scalar helper functions (current canonical contract)
  close_aaa <- ctx$close("AAA")
  pos_aaa   <- ctx$position("AAA")
  feat_aaa  <- ctx$feature("AAA", "sma_20")

  # Pattern 2: data.frame / named-list direct access (some examples still
  # use this; tests pin both shapes)
  close_aaa <- ctx$bars$close[ctx$bars$instrument_id == "AAA"]
  pos_aaa   <- ctx$positions[["AAA"]]
  # ...
}
```

Both patterns are documented and pinned. Both are O(n_inst) per call at
production scale because every accessor pays one of:

- **Character-equality scan** for filtered data.frame access.
- **Named-list linear lookup** for `[[id]]` access.
- **Scalar helper dispatch** for `ctx$close(id)` (more bounded but still
  per-call function dispatch + per-call instrument lookup).

The v0.1.8.9 round vectorized ledgr's INTERNAL per-pulse loops
(`R/fold-engine.R` position valuation, target-delta scan, output handler
buffer writes). It did not touch the EXTERNAL strategy callback shape
because the shape is a public contract requiring RFC discussion.

The Backtrader source-code analysis recorded in the 2026-06-01 horizon
entry on R-side substrate framing is the comparison point. Backtrader
strategies access bars and indicators via integer-cursor offsets into
C-contiguous `array.array('d')` storage — single integer-offset reads,
no character-equality cost. That is the architectural pattern that gives
Backtrader its lead at the engine level, and the horizon's substrate
framing argues ledgr can match it in R via data-structure choice.

The v0.1.8.9 closeout's residual #1 (R-side substrate) and the horizon's
substrate framing treat ledgr matching this access pattern in R as the
load-bearing v0.1.8.10 lane. The substrate spike batch (Spikes 3, 4, 5
in the v0.1.8.10 round) measures the internal data-structure changes
needed to support the pattern. **What's missing is a public contract
decision about the user-facing accessor surface itself.** That is what
this RFC proposes.

## Background / current state (corrected per F1)

Five accessor patterns documented or in use in v0.1.8.x:

| Pattern | Example | Status |
|---|---|---|
| Scalar helper functions | `ctx$close("AAA")`, `ctx$position("AAA")`, `ctx$feature("AAA", "sma_20")` | **Canonical**, documented in the strategy guide (`vignettes/strategy-development.qmd:174-175`), pinned by tests (`tests/testthat/test-pulse-context-accessors.R:25-43`). These are FUNCTIONS attached at `R/pulse-context.R:375-412`. |
| Sparse named-list lookup | `ctx$positions[["AAA"]]` | Works today. `ctx$positions` is named numeric over held instruments (`tests/testthat/test-pulse-context-accessors.R:14` uses `setNames(c(3), "B")`). NOT guaranteed universe-aligned. |
| Filtered data.frame | `ctx$bars$close[ctx$bars$instrument_id == "AAA"]` | Works today. Some older tests / examples still use this. |
| Wide-feature view | `ctx$features_wide` | Data-frame-shaped view, used in some paths (`R/pulse-context.R:253-281`, `tests/testthat/test-pulse-context-accessors.R:203-204`). |
| Internal scalar feature-at | `ledgr_projection_feature_at(...)` | Internal only (`R/runtime-projection.R:130-167`). No public `ctx$feature_at` exists today. |

ledgr's INTERNAL machinery (post-v0.1.8.9) is faster than the public
contract lets strategies take advantage of. The fold engine uses
primitive numeric vectors aligned to instrument order
(`bars_mat$close[, i]`, `state$positions`) but exposes them through the
slower public patterns above. Strategies that don't care about per-pulse
cost (research workflows, low-frequency strategies) won't notice.
Strategies that DO care (high-frequency cross-sectional, multi-asset
rebalancing on every pulse, sweep candidates at xlarge) are blocked by
the contract.

## Proposed direction (revised)

Add **a high-throughput accessor surface under a `ctx$vec` namespace**
alongside the existing scalar helpers and named/filtered patterns. All
three layers stay first-class; strategy authors choose based on their
throughput needs.

### Surface sketch

```r
strategy_fn <- function(ctx, params) {
  # NEW (v0.1.8.10): high-throughput universe-aligned vector access
  close_vec <- ctx$vec$close              # universe-aligned numeric vector
  open_vec  <- ctx$vec$open               # same shape
  pos_vec   <- ctx$vec$positions          # universe-aligned numeric vector
                                          # (sparse positions filled to 0)
  sma_vec   <- ctx$vec$feature("sma_20")  # universe-aligned numeric vector
                                          # NEW contract — see Q4

  # NEW (v0.1.8.10): universe-index resolver
  idx_aaa   <- ctx$idx("AAA")             # scalar integer
  close_aaa <- close_vec[idx_aaa]
  pos_aaa   <- pos_vec[idx_aaa]

  # CANONICAL (unchanged): scalar helper functions
  close_aaa <- ctx$close("AAA")
  pos_aaa   <- ctx$position("AAA")
  feat_aaa  <- ctx$feature("AAA", "sma_20")

  # EXISTING (unchanged): named-list / filtered patterns
  pos_aaa   <- ctx$positions[["AAA"]]    # sparse named lookup
  close_aaa <- ctx$bars$close[ctx$bars$instrument_id == "AAA"]
  # ...
}
```

The new surface elements:

- **`ctx$vec`**: a sub-namespace (list or env) holding universe-aligned
  numeric vectors. Length of each vector = `length(ctx$universe)`. Order
  matches `ctx$universe`.
- **`ctx$vec$close`**, **`ctx$vec$open`**, **`ctx$vec$high`**,
  **`ctx$vec$low`**, **`ctx$vec$volume`**: universe-aligned numeric
  vectors from `bars_mat`. Read-only by documented convention.
- **`ctx$vec$positions`**: universe-aligned numeric vector. Instruments
  without a position read as `0`. (`ctx$positions` stays sparse named
  numeric per F1 finding; `ctx$vec$positions` is a separate view.)
- **`ctx$vec$feature(feature_id)`**: NEW contract. Returns
  universe-aligned numeric vector for the named feature.
  Length = `length(ctx$universe)`. Warmup positions read as `NA_real_`.
  Unknown `feature_id` errors loudly (consistent with scalar
  `ctx$feature(id, feature_id)`).
- **`ctx$idx(instrument_id)`**: scalar character → scalar integer.
  Universe position of the instrument. Unknown-instrument behavior is
  Q6.

### Behavior guarantees

For any strategy author opting into the `ctx$vec` path:

1. **Universe-aligned ordering is stable across pulses.**
   `ctx$vec$close[i]` refers to the same instrument throughout the
   backtest.
2. **All `ctx$vec$<accessor>` vectors have length `length(ctx$universe)`.**
   Missing/sparse data is `0` for positions, `NA_real_` for unobserved
   feature values, `NA_real_` for bars data outside an instrument's
   trading window if such windows exist.
3. **`ctx$idx()` resolution is O(1) per call** after one-time map
   construction at execution-spec time.
4. **Vectors are read-only by documented convention.** Strategy code
   that mutates a `ctx$vec$<accessor>` vector or any other ctx slot has
   undefined behavior at the next pulse. Q7 closes the
   snapshot/retention semantics that make this safe.

For strategies continuing to use scalar helpers or named patterns:

5. **All v0.1.8.x patterns continue to work unchanged.** Scalar helpers
   (`ctx$close(id)`, `ctx$feature(id, feature_id)`, etc.) stay
   canonical. Sparse `ctx$positions` stays sparse named numeric.
   Filtered data.frame access keeps working. No removal, no rename, no
   deprecation in v0.1.8.10.

## Backward compatibility (revised)

Pre-CRAN with zero known external users. The compatibility consideration
is documentation, accepted-example, and test coherence — not user
breakage. Per `rfc_cycle.md` §"Pre-CRAN-no-users framing", that does NOT
rule out internal-coherence cost.

- **No existing accessor is removed or renamed.** All v0.1.8.x patterns
  continue to work. The new `ctx$vec` namespace and `ctx$idx()` are
  purely additive.
- **`ctx$close`, `ctx$open`, `ctx$high`, `ctx$low`, `ctx$volume`,
  `ctx$position`, `ctx$flat`, `ctx$hold` stay as scalar helper
  functions.** No collision risk because the new vector slots live under
  `ctx$vec`.
- **`ctx$positions` stays sparse named numeric.** Tests that observe
  sparse positions (`tests/testthat/test-pulse-context-accessors.R:14`,
  `tests/testthat/test-execution-spec.R:151-170`) continue to pass
  unchanged.
- **`ctx$feature(id, feature_id)` stays the canonical scalar feature
  accessor.** `ctx$vec$feature(feature_id)` is genuinely new contract,
  not an extension. v0.1.8.10 documentation must say so.
- **Documentation policy**: present the three layers as first-class.
  Recommend scalar helpers for prototyping; recommend `ctx$vec` access
  for production at scale or for any sweep candidate that runs at
  xlarge. Spike 5 measurements set the threshold guidance. The
  strategy guide vignette gets a "Three access patterns: ergonomic /
  canonical / high-throughput" section.

## Substrate dependencies (revised per F3)

This addendum depends on internal substrate decisions that are
themselves v0.1.8.10 spike-round candidates. The dependency mapping is
refined from v1 per the response's F3 findings.

| Substrate spike | Provides | This addendum needs |
|---|---|---|
| Spike 3 / LDG-2507 (state$positions primitive) | Universe-aligned numeric `state$positions` with `id_to_idx` map | `ctx$vec$positions` view; `ctx$idx()` resolver. NOTE: `ctx$positions` (the public sparse named slot) stays unchanged regardless of Spike 3's internal representation choice. Internal primitive state can power both the existing sparse view and the new universe-aligned vector view. |
| Spike 4 / LDG-2508 (reusable pulse-context env) | Internal-only optimization (per Q7 decision below) | Faster internal helper resolution, lower per-pulse allocation. Does NOT expose env to public ctx — see Q7. Spike 4 still has value as an internal optimization but does not gate the public contract addendum. |
| Spike 5 / LDG-2509 (integer-indexed accessors) | Measured per-pulse cost across access patterns | Quantitative threshold for documenting "high-throughput path" vs "scalar helpers" guidance. Load-bearing for whether the documentation guidance recommends `ctx$vec` over scalar helpers above a specific universe-size threshold. |

**Additional substrate dependencies identified in response F3**:

- **Feature engine / runtime projection**. `ctx$vec$feature(feature_id)`
  needs a universe-aligned bulk-feature read path. The internal
  precedent at `R/runtime-projection.R:130-167` is scalar
  (`ledgr_projection_feature_at(projection, instrument_id, feature_id,
  pulse_idx, ...)`). v0.1.8.10 implementation needs a vector form,
  either by changing the projection contract or by adding a wrapper
  that calls scalar `feature_at` for every universe member. Whether
  this is bundled into v0.1.8.10 or deferred to a feature-engine RFC
  is one of the decisions in Q4.
- **Documentation contract tests.**
  `tests/testthat/test-documentation-contracts.R:220` expects
  `ctx$feature(id, feature_id)` in help output; adding
  `ctx$vec$feature(feature_id)` requires updating these tests AND
  adding new ones for the vector form.
- **Existing strategy guide.**
  `vignettes/strategy-development.qmd:174-175, 583-643` pins scalar
  helpers; v0.1.8.10 adds a new section without removing or rewriting
  the existing ones.

**If Spike 3 fails** (primitive state doesn't deliver): the addendum
still works because `ctx$vec$positions` can be built from `bars_mat`-
aligned `state$positions` regardless of internal representation. The
performance case for `ctx$vec$positions` weakens but the ergonomic case
holds.

**If Spike 4 fails** (reusable env doesn't move the needle): the
addendum is unaffected because Q7 keeps public ctx as a fresh list per
pulse regardless. Spike 4's failure means an internal optimization
doesn't land, but the public contract is identical.

**If Spike 5 fails** (integer-indexed accessor doesn't beat scalar
helpers at production scale): the addendum's documentation guidance
changes — `ctx$vec` becomes "available for advanced users" rather than
"recommended for production." The contract still ships because the
ergonomic case for universe-aligned vector access is real even if the
per-pulse cost is comparable.

## Open questions

Seven questions need maintainer decision before any v0.1.8.10
implementation ticket is cut. Q1-Q5 were in v1 (Q1 and Q4 reframed); Q6
and Q7 are new per response findings.

### Q1: Namespace for vector accessors (REFRAMED)

The v1 proposal for direct top-level slots (`ctx$close`, `ctx$open`,
etc.) collides with existing scalar helper functions. Three candidate
namespacing patterns:

- **`ctx$vec$close`, `ctx$vec$open`, `ctx$vec$positions`,
  `ctx$vec$feature(id)`**: sub-namespace under a single `vec` slot.
  Clean, explicit purpose, single entry point for "vector access" pattern.
  No collision with existing helpers. **Recommended.**
- **`ctx$prices$close`, `ctx$prices$open` + `ctx$state_vec$positions` +
  `ctx$feature_vec(id)`**: semantically named sub-namespaces. More
  discoverable per data type but multiplies entry points and creates
  asymmetry (prices namespace, state_vec namespace, feature_vec function
  — three different shapes).
- **Suffixed top-level slots**: `ctx$close_vec`, `ctx$positions_vec`,
  `ctx$feature_vec(id)`. Discoverable, no collision, but inflates the
  top-level ctx surface and exposes a sprawl of similar names that R's
  partial matching could confuse (`ctx$close_v` autocompletes to
  `ctx$close_vec` in some interactive contexts).
- **Rename existing helpers to free top-level slot names**:
  `ctx$close(id)` → `ctx$close_at(id)`, free `ctx$close` for the vector.
  Deliberately rejected: this is a more disruptive contract break than
  namespace-prefixing for marginal naming clarity benefit. Pre-CRAN
  permits it but doesn't justify it.

**Recommended: `ctx$vec` namespace.** Single entry point, no collision,
clear purpose. Maintainer decision: confirm or pick a different
namespace.

### Q2: Universe indexing convention (unchanged from v1)

1-based per R convention. `ctx$idx("AAA")` returns 1 for the first
universe member, etc. Backtrader is 0-based (Python convention); R is
1-based and the surface should match. Per response F2 Q2: agreed.

### Q3: `ctx$idx()` map data structure (refined from v1)

The universe→idx map is built once at execution-spec construction
(`R/execution-spec.R:41-100` is the natural home; add an `id_to_idx`
field alongside the existing `instrument_ids`). Three candidate
implementations:

- **Immutable named integer vector**: `id_to_idx <- setNames(seq_along(universe), universe)`.
  Then `ctx$idx(id) = id_to_idx[[id]]`. Simplest, immutable, safe for
  worker serialization. Lookup is O(n_inst) named-vector scan (same
  cost as current `ctx$position(id)`). The substrate motivation
  argued this is O(n_inst) and we want O(1); named-vector lookup
  doesn't deliver O(1).
- **Environment-backed map**: `id_to_idx_env <- new.env(parent = emptyenv())`
  with `id_to_idx_env[[id]] <- i`. Then `ctx$idx(id) = id_to_idx_env[[id]]`.
  O(1) hash lookup. Worker serialization concerns because envs serialize
  awkwardly; needs explicit handling at execution-spec construction
  for parallel sweep.
- **Sorted character vector + `match()`**: pre-sort the universe at
  execution-spec construction; `ctx$idx(id) = fmatch(id, sorted_universe)`
  using `collapse::fmatch` for fast hash-table matching. Faster than
  base R `match()` per the documented collapse doctrine
  (`inst/design/collapse_optimization_map.md`). Serializes cleanly.

**Recommendation: prototype both env-backed and `collapse::fmatch`
options in Spike 5; pick the winner based on measured per-call cost AND
worker-serialization friendliness.** Per response F3 — Spike 5 is the
right venue for this measurement.

### Q4: Vector-feature accessor (REFRAMED)

v1 claimed `ctx$feature("sma_20")` already returned a vector. This is
wrong: the current contract is scalar `ctx$feature(instrument_id,
feature_id)` (`R/pulse-context.R:54-96`,
`inst/design/contracts.md:380-385`).

Real decision: does v0.1.8.10 introduce a vector-feature accessor at
all? Three options:

- **Yes, include `ctx$vec$feature(feature_id)` in v0.1.8.10.** Adds new
  contract. Implementation requires either (a) extending the runtime
  projection to support bulk feature reads or (b) a wrapper that calls
  `feature_at` for every universe member. Same no-lookahead,
  unknown-feature-errors-loudly, warmup-NA semantics as the scalar
  accessor. Documented as the high-throughput path for cross-sectional
  strategies. **Recommended per maintainer call at v2 authoring (full
  addendum scope).**
- **No, defer vector-feature accessor to a feature-engine RFC.**
  v0.1.8.10 ships `ctx$vec$close`/`ctx$vec$open` etc. plus
  `ctx$vec$positions` plus `ctx$idx()`. Feature vector access stays
  scalar. Cleaner v0.1.8.10 scope but leaves high-throughput
  feature-using strategies without the high-throughput path.
- **Yes but minimal: scalar `ctx$feature_at(feature_id, idx)`.** Adds a
  scalar accessor that takes pre-computed `idx` instead of `id`.
  Faster than `ctx$feature(id, feature_id)` because it skips the
  character lookup. Doesn't require bulk-feature read path. Smaller
  scope than full vector accessor but only marginally faster.

**Maintainer recommendation per v2 authoring call: full vector accessor
(option 1).** Scope decision recorded; implementation needs the bulk-
feature read path or a wrapper.

### Q5: Read-only enforcement (refined; supersedes some of Q5 by Q7)

Documented convention only for ordinary mutation of `ctx$vec$close`,
`ctx$vec$positions`, etc. R has no clean way to enforce read-only
without active locking, and locking adds overhead with no real safety
win.

The reusable-env retention concern that v1 missed is resolved by Q7
(public ctx stays list with fresh slots per pulse), not by enforcement
on the public slots.

**Recommended: documented convention. Document explicitly that strategy
code retaining ctx slot references across pulses has undefined behavior;
copy with `as.numeric()` if a strategy needs to hold a snapshot.**

### Q6: Unknown-id behavior for `ctx$idx()` (NEW)

Existing scalar helpers fail loudly on unknown instruments
(`R/pulse-context.R:511-529` produces an error message listing
`ctx$universe`; pinned by
`tests/testthat/test-pulse-context-accessors.R:255-256`). v1 said
`ctx$idx("BAD")` returns NA silently, which is inconsistent.

Three candidates:

- **Error by default with `missing = "na"` opt-in**:
  `ctx$idx(id)` errors loudly with `ctx$universe` in the message;
  `ctx$idx(id, missing = "na")` returns NA. Matches the existing helper
  contract. **Recommended.**
- **Return NA silently always**: simpler API but breaks strategy
  contract consistency. Strategies that pass user-supplied instrument
  ids could silently get NA-indexed reads.
- **Both signatures via `try_idx()`**: `ctx$idx(id)` errors;
  `ctx$try_idx(id)` returns NA. Two top-level functions for two
  behaviors. Slightly more API surface but very explicit.

**Recommended: error by default, `missing = "na"` opt-in.** Maintainer
decision: confirm or pick alternative.

### Q7: Snapshot/retention semantics for reusable-env optimization (NEW)

Response F2 Q5 identified that reusable env-backed ctx slots plus
in-place vector mutation can cause `state_update` aliasing — strategies
legally retain values in `state_update`; `R/fold-engine.R` keeps
`state_prev_mem <- result$state_update`; if subsequent pulses mutate
the SAME vector object in place, prior-pulse `state_prev` observes the
NEW values. Current fresh-list / fresh-data-frame behavior avoids this.

Maintainer-confirmed at v2 authoring: **public ctx stays list with
fresh slots per pulse. Reusable-env optimization (Spike 4) is
internal-only and not exposed via public ctx.**

Mechanical implications:

- `R/pulse-context.R:654-656` list validation stays unchanged.
- The pulse-context constructor at `R/fold-engine.R:181-194` still
  allocates a fresh list per pulse.
- `ctx$vec` and its slots are built fresh per pulse from `bars_mat`
  columns and `state$positions` reads. The vectors themselves can
  share storage with internal primitive state where safe (e.g.,
  `ctx$vec$close` can be `bars_mat$close[, i]` directly if that's
  immutable — verify in implementation).
- Strategies that retain `ctx$vec$close` references across pulses get
  undefined behavior, documented as "copy with `as.numeric()` if you
  need a snapshot."
- Spike 4's measured benefit becomes "internal helper closure reuse"
  rather than "public ctx env reuse." Spike 4's ROI narrows but the
  public contract is preserved.

**Recommended (and maintainer-confirmed at v2 authoring): public-list,
internal-env split.** Eliminates state_update aliasing risk; preserves
existing validation; weakens Spike 4 ROI but doesn't kill it.

## Scope and non-scope

### In scope (v0.1.8.10)

- Add `ctx$vec` sub-namespace with `close`, `open`, `high`, `low`,
  `volume`, `positions` universe-aligned numeric vectors.
- Add `ctx$idx(instrument_id)` resolver with per-backtest map built at
  execution-spec construction.
- Add `ctx$vec$feature(feature_id)` returning universe-aligned numeric
  vector with same no-lookahead / unknown-feature-errors-loudly /
  warmup-NA semantics as the scalar accessor.
- Update `R/pulse-context.R` list validation to acknowledge the new
  `vec` slot (still a list, still has class).
- Update strategy guide vignette with "Three access patterns:
  ergonomic / canonical / high-throughput" section. Include measured
  threshold guidance from Spike 5.
- Tests: integer-indexed accessor parity with scalar helpers; `ctx$idx()`
  correctness for known and unknown instruments; universe-alignment
  invariant across pulses; vector-feature accessor parity with scalar
  `ctx$feature(id, feature_id)` across full universe; `ctx$vec`
  documentation contract test.

### Out of scope

- Removing or deprecating scalar helpers (`ctx$close(id)`,
  `ctx$feature(id, feature_id)`, etc.) at any horizon. They stay
  first-class.
- Removing or deprecating sparse named `ctx$positions`. Stays
  unchanged.
- Removing or deprecating filtered data.frame access
  (`ctx$bars$close[ctx$bars$instrument_id == "AAA"]`). Stays working.
- Read-only enforcement beyond documented convention.
- Migration of existing strategies to `ctx$vec` patterns. Strategies
  that work today continue to work; migration is the user's call,
  guided by the documented threshold from Spike 5.
- Reusable env exposure via public ctx (per Q7 decision).
- Compiled-core boundary contract (separate `ledgrcore-spike` repo per
  2026-06-01 horizon K1 repo-split decision).
- Feature-engine surface beyond `ctx$vec$feature(feature_id)` — wide
  multi-feature views, lookback windows, alias-map interactions stay
  with the existing accessors.

## Implementation sketch (revised)

If the RFC closes with "accept," v0.1.8.10 implementation work is
roughly:

1. **`R/execution-spec.R`**: add `id_to_idx` field at execution-spec
   construction (~line 72 alongside `instrument_ids`). Implementation
   per Q3 (env-backed or `collapse::fmatch`-backed, measured by Spike 5).
   Update validation if needed.
2. **`R/pulse-context.R`**: add `vec` sub-namespace constructor
   (function that takes `bars_mat`, `state`, `instrument_ids`,
   `pulse_idx`, runtime projection) and builds the `ctx$vec` slot per
   pulse. Add `ctx$idx()` accessor wrapping the execution-spec map.
   Update list validation at lines 654-656 to acknowledge the new
   slot.
3. **`R/runtime-projection.R`**: add bulk vector-feature read path for
   `ctx$vec$feature(feature_id)`. Either extend
   `ledgr_projection_feature_at` to vector form or add a sibling
   function `ledgr_projection_feature_vec`. Internal API; not a public
   contract change.
4. **`R/fold-engine.R`**: update pulse-context constructor at lines
   181-220 to call the new `vec` constructor and `idx` accessor.
   Constructor still allocates a fresh list per Q7. Helpers
   (`ctx$close(id)`, `ctx$feature(id, feature_id)`, etc.) attached
   unchanged.
5. **Strategy guide vignette**: add "Three access patterns" section
   with measured threshold guidance from Spike 5. Update FAQ if needed.
6. **Documentation contract tests** at
   `tests/testthat/test-documentation-contracts.R`: add expectations
   for `ctx$vec` and `ctx$idx` documentation.
7. **Accessor parity tests**: new tests under
   `tests/testthat/test-pulse-context-vec-accessors.R` covering
   `ctx$vec$close[idx]` vs `ctx$close(id)` parity, `ctx$idx()` known
   and unknown id behavior, `ctx$vec$positions` universe alignment,
   `ctx$vec$feature(id)` parity with scalar form.

Estimated effort: ~2-3 weeks of focused work after Spikes 3, 4, 5
complete. Not a major refactor; mostly additive surface. The vector
feature accessor is the largest piece because it requires the bulk-
feature read path.

## Decision needed

For the v0.1.8.10 spec packet to cut a ticket from this RFC, the
maintainer (with optional synthesis input from Codex) needs to decide:

1. **Q1 namespace**: confirm `ctx$vec` or pick alternative.
2. **Q3 map data structure**: env-backed, `collapse::fmatch`-backed, or
   spike-measured pick.
3. **Q4 vector-feature accessor**: confirmed maintainer call at v2
   authoring = full vector accessor (`ctx$vec$feature(id)`) in
   v0.1.8.10 scope.
4. **Q6 unknown-id semantics**: confirm "error by default,
   `missing = na` opt-in" or pick alternative.
5. **Q7 public-list / internal-env split**: confirmed maintainer call
   at v2 authoring = public ctx stays list, reusable-env optimization
   internal-only.
6. **Spike 5 contingency**: if Spike 5 shows `ctx$vec` patterns don't
   beat scalar helpers at production scale, does the addendum still
   proceed for ergonomics alone? Recommended answer: yes — the
   universe-aligned vector view is real ergonomic value for
   cross-sectional strategies even if the per-pulse cost is comparable
   to scalar helpers, AND the substrate work (Spikes 3, 4) still pays
   off via internal optimization regardless of how Spike 5 lands.

After those decisions, the synthesis document closes the RFC and the
v0.1.8.10 ticket for the strategy callback contract addendum can be
cut.

## Sources

- `inst/design/horizon.md` 2026-06-01 entry: R-side data structures as
  shared substrate for compiled-core path. Backtrader source analysis
  and substrate framing. NOTE: horizon language uses "v0.1.9"
  generically for substrate work; this RFC targets v0.1.8.10
  specifically.
- `inst/design/ledgr_v0_1_8_9_spec_packet/v0_1_8_9_release_closeout.md`
  **residual #1**: R-side substrate.
- `inst/design/spikes/ledgr_v0_1_8_10_optimization_round_spike/README.md`:
  v0.1.8.10 spike round, especially Batch B (substrate) and Spike 5
  (LDG-2509, integer-indexed accessors).
- `dev/bench/notes/single_core_optimization_inventory.md` items A3, A5,
  A6.
- `R/fold-engine.R:181-220` (pulse-context constructor + helper
  attachment, the strategy-visible context surface).
- `R/pulse-context.R:375-412` (scalar helpers like `ctx$close(id)`).
- `R/pulse-context.R:54-96` (scalar `ctx$feature(id, feature_id)`).
- `R/pulse-context.R:654-656` (list+class validation).
- `R/execution-spec.R:41-100` (execution-spec construction, natural
  home for `id_to_idx` map).
- `R/runtime-projection.R:130-167` (internal scalar feature-at; bulk
  vector form needs implementation).
- `inst/design/contracts.md:380-385` (current `ctx$feature(id,
  feature_id)` contract pin).
- `vignettes/strategy-development.qmd:174-175, 583-643` (strategy
  guide pins for scalar helpers).
- `tests/testthat/test-pulse-context-accessors.R` (pinned helper
  shapes).
- `tests/testthat/test-execution-spec.R:151-170` (sparse positions
  observable).
- `tests/testthat/test-documentation-contracts.R:220` (pinned doc
  shape).
- `rfc_strategy_callback_contract_addendum_v0_1_8_10_seed.md` (v1,
  superseded).
- `rfc_strategy_callback_contract_addendum_v0_1_8_10_response.md`
  (Codex response stage; load-bearing findings absorbed into this v2).
- Backtrader source: `mementum/backtrader` on GitHub,
  `backtrader/linebuffer.py` — integer-cursor data structure pattern
  this RFC mirrors at the strategy contract layer.
