# RFC Seed: Strategy Callback Contract Addendum (v0.1.8.10)

**Status:** Seed. Not accepted. Not authorized implementation scope.
**Cycle:** v0.1.8.10 single-core optimization round (the closing round of
the v0.1.8.x single-core arc).
**Promotion candidate:** v0.1.8.10 substrate batch (Batch B of the
v0.1.8.10 spike round at
`inst/design/spikes/ledgr_v0_1_8_10_optimization_round_spike/`), specifically
gated on Spike 5 / LDG-2509 results.
**Relates to:** the 2026-06-01 horizon entry "R-side data structures as
shared substrate for compiled-core path"; v0.1.8.9 closeout residual #2
(R-side substrate); the Backtrader source-code analysis in the same
horizon entry.

## Problem

ledgr's current strategy callback contract gives strategy authors a
named-list pulse context with data.frame accessors:

```r
strategy_fn <- function(ctx, params) {
  close_aaa <- ctx$bars$close[ctx$bars$instrument_id == "AAA"]
  pos_aaa   <- ctx$positions[["AAA"]]
  feat_aaa  <- ctx$feature("sma_20")[ctx$bars$instrument_id == "AAA"]
  # ...
}
```

This shape is ergonomic for small universes and prototypical strategies.
It is **structurally slow** at production scale because every accessor
pays one of:

- **Character-vector equality scan** (`ctx$bars$instrument_id == "AAA"`):
  O(n_inst) per call. At 1000 instruments x 1260 pulses x several
  accessors per pulse, that is millions of character-equality comparisons
  per backtest.
- **Named-list `[[id]]` lookup** (`ctx$positions[["AAA"]]`): O(n_inst)
  linear scan over named-vector names. Same scaling.
- **Per-pulse data.frame construction**: `ctx$bars` is currently a
  per-pulse data.frame view, allocated fresh. At 1000 instruments and
  the post-v0.1.8.9 baseline of 232.03s wall on xlarge durable, ctx
  construction is a measurable share of per-pulse work that the rest of
  the v0.1.8.9 round didn't touch because it's a public-surface change
  requiring RFC discussion.

The v0.1.8.9 round vectorized ledgr's INTERNAL per-pulse loops
(`R/fold-engine.R` position valuation, target-delta scan, output handler
buffer writes). It did not touch the EXTERNAL strategy callback shape
because the shape is a public contract.

The Backtrader source-code analysis recorded in the 2026-06-01 horizon
entry on R-side substrate framing is the comparison point. Backtrader
strategies access bars and indicators via integer-cursor offsets:

```python
def next(self):
    close_now = self.data.close[0]       # integer-indexed
    sma_now   = self.sma[0]              # same shape
    pos       = self.position.size       # direct attribute, not a lookup
```

Each of those accessors is a single integer-offset read into a
C-contiguous `array.array('d')`. That is the architectural pattern that
gives Backtrader its lead — not compilation, just data-structure choice.

The v0.1.8.9 closeout's residual #2 (R-side substrate) and the horizon's
substrate framing both treat ledgr matching this access pattern in R as
the load-bearing v0.1.8.10 lane. The substrate spike batch (Spikes 3, 4,
5 in the v0.1.8.10 round) measures the internal data-structure changes
needed to support this access pattern. **What's missing is a public
contract decision about the user-facing accessor surface itself.** That
is what this RFC seed proposes.

## Background / current state

Three current accessor patterns documented in the v0.1.8.x strategy
guides:

| Pattern | Example | Per-call cost at 1000-inst universe |
|---|---|---|
| Filtered data.frame | `ctx$bars$close[ctx$bars$instrument_id == "AAA"]` | O(n_inst) char scan + O(n_inst) subset |
| Named-list lookup | `ctx$positions[["AAA"]]` | O(n_inst) linear name scan |
| Aliased feature | `ctx$feature("sma_20")` | O(features) dispatch + O(n_inst) for value |

ledgr's INTERNAL machinery (post-v0.1.8.9) is already faster than the
strategy can take advantage of: the fold engine uses primitive numeric
vectors aligned to instrument order, but it exposes them to strategies
through the slow patterns above. Strategies that don't care about
per-pulse cost (research workflows, low-frequency strategies) won't
notice. Strategies that DO care (high-frequency cross-sectional,
multi-asset rebalancing on every pulse, sweep candidates at xlarge) are
blocked by the contract.

## Proposed direction

Add **integer-indexed accessors as a first-class strategy API** alongside
the existing named/filtered patterns. Both shapes stay documented;
strategy authors choose based on their throughput needs.

### Surface sketch

```r
strategy_fn <- function(ctx, params) {
  # NEW: integer-indexed accessors (high-throughput path)
  close_vec <- ctx$close              # full universe-aligned numeric vector
  pos_vec   <- ctx$positions          # full universe-aligned numeric vector
  sma_vec   <- ctx$feature("sma_20")  # already vector-returning; promote to first-class

  # idx is the universe index for an instrument
  idx_aaa   <- ctx$idx("AAA")         # one-time character->integer resolution
  close_aaa <- close_vec[idx_aaa]
  pos_aaa   <- pos_vec[idx_aaa]

  # EXISTING: named/filtered patterns (ergonomic path, unchanged)
  close_aaa <- ctx$bars$close[ctx$bars$instrument_id == "AAA"]
  pos_aaa   <- ctx$positions[["AAA"]]
  # ...
}
```

The new surface elements:

- `ctx$close` (and `ctx$open`, `ctx$high`, `ctx$low`, `ctx$volume`):
  universe-aligned numeric vectors. Length = `length(ctx$universe)`.
  Order matches `ctx$universe`.
- `ctx$positions`: this name already exists. The proposal **changes its
  type from named-vector to universe-aligned numeric vector** (still
  named for backward compatibility but treated as integer-indexed in the
  high-throughput path). See "Compatibility" below.
- `ctx$idx(id)`: scalar character → scalar integer mapping. Universe
  position of the instrument. Returns NA for unknown instruments.
- `ctx$feature(id)` and `ctx$feature_at(id, idx)`: the value-returning
  accessor stays vector-shaped; a new scalar accessor `feature_at` is
  added for single-instrument scalar reads without subset overhead.

### Behavior guarantees

For any strategy author opting into the integer-indexed path:

1. **Universe-aligned ordering is stable across pulses.** `ctx$close[i]`
   refers to the same instrument throughout the backtest.
2. **`ctx$idx()` resolution is O(1)** after the first call per pulse (or
   cached at execution-spec construction).
3. **All universe-aligned vectors have the same length** as
   `length(ctx$universe)`. Missing data is `NA`, not absent.
4. **Vectors are read-only.** Strategy code cannot mutate `ctx$close`
   etc. and have the mutation observable outside the strategy. This
   matches the existing implicit contract on `ctx$bars`.

For strategies continuing to use the named/filtered patterns:

5. **All v0.1.8.x patterns continue to work.** No deprecation, no
   removal in v0.1.8.10.
6. **`ctx$positions[["AAA"]]` returns the same value as
   `ctx$positions[ctx$idx("AAA")]`.** The named-list semantics are
   preserved on `ctx$positions` because it remains named even when
   accessed by integer index.

## Backward compatibility

Pre-CRAN with zero known external users. The compatibility consideration
is documentation and teaching surface, not user breakage.

- **No existing accessor is removed.** All v0.1.8.x patterns work
  unchanged.
- **Type of `ctx$positions` stays named numeric**, indexable by both
  name and integer.
- **New accessors are additive.** `ctx$close`, `ctx$open`,
  `ctx$idx()`, `ctx$feature_at()` are new slots that didn't exist in
  v0.1.8.x.
- **Documentation policy**: present both patterns as first-class.
  Recommend the named patterns for prototyping and low-frequency
  strategies; recommend the integer-indexed patterns for production at
  scale or for any sweep candidate that runs at xlarge. Spike 5
  measurements set the threshold (probably "high-frequency or sweep at
  xlarge" but the spike confirms).

## Substrate dependencies

This addendum is a public-contract change. It depends on internal
substrate decisions that are themselves v0.1.8.10 spike-round candidates:

| Substrate spike | Provides | This addendum needs |
|---|---|---|
| Spike 3 / LDG-2507 (state$positions primitive) | Universe-aligned numeric `state$positions` with `id_to_idx` map | `ctx$positions` exposed as universe-aligned vector + `ctx$idx()` resolver |
| Spike 4 / LDG-2508 (reusable pulse-context env) | Mutable env-backed ctx slots updated per pulse | Stable slot identity for `ctx$close`, `ctx$open` etc. across pulses |
| Spike 5 / LDG-2509 (integer-indexed accessors) | Measured per-pulse cost across access patterns | Quantitative basis for documenting "high-throughput path" vs "ergonomic path" |

If any of Spikes 3, 4, or 5 returns a negative result, the addendum
scope adjusts. Specifically: if Spike 4 shows reusable-env doesn't move
the needle, integer-indexed accessors on a per-pulse-fresh-list ctx
still work but lose some of their advantage; if Spike 3 shows primitive
state$positions doesn't deliver, the substrate framing weakens but the
contract addendum is still a real ergonomic improvement.

## Open questions

Five questions need maintainer decision before any v0.1.8.10
implementation ticket is cut. Listed roughly in decreasing impact on the
final surface shape.

### Q1: Naming convention

Three candidate shapes:

- **Direct slots** (proposed above): `ctx$close`, `ctx$open`,
  `ctx$positions`. Mirrors Backtrader's `self.data.close[0]` pattern.
  Concise. Slight risk of collisions with future feature names.
- **Namespaced slots**: `ctx$prices$close`, `ctx$prices$open`. Avoids
  collision risk. More keystrokes.
- **Function accessors**: `ctx$close_at(idx)`, `ctx$open_at(idx)`. No
  collision risk; gives a place to attach validation. Loses
  vector-return ergonomic.

Recommended: direct slots. Backtrader-style is teachable and matches the
ergonomic target the horizon framing called out.

### Q2: Universe indexing convention (1-based vs 0-based)

R-natural is 1-based. Backtrader is 0-based (Python convention).
Consistent with R's convention: 1-based. `ctx$idx("AAA")` returns 1 for
the first universe member, etc.

Recommended: 1-based. No good reason to break R convention.

### Q3: `ctx$idx()` caching policy

The character-to-integer resolution is the load-bearing one-time cost.
Three options:

- **Per-call, no cache**: simplest. Pays O(n_inst) per call. Probably
  cheap enough but defeats the purpose of integer-indexed accessors if
  strategies call `ctx$idx()` repeatedly.
- **Per-pulse cache**: warmed on first call per pulse, dropped on next
  pulse. Loses warmth if strategy resolves indices in a different order.
- **Per-backtest cache**: built at execution-spec construction time,
  reused across all pulses. O(1) lookups after warmup. Memory cost is
  one integer-keyed env.

Recommended: per-backtest cache, built at execution-spec construction
time. Universe doesn't change mid-backtest, so caching is safe.
Per-call resolution and per-pulse resolution are both worse for no
upside.

### Q4: Feature accessor shape

Existing: `ctx$feature("sma_20")` returns a universe-aligned numeric
vector. That already matches the integer-indexed pattern's needs.

Open: should we add `ctx$feature_at("sma_20", idx)` for scalar reads, or
require strategies to do `ctx$feature("sma_20")[idx]`? The first form
allows internal short-circuiting (compute only the requested instrument's
value if the feature engine supports it); the second form is consistent
with the rest of the surface.

Recommended: keep `ctx$feature("sma_20")[idx]` as the canonical pattern;
defer `feature_at` to a future RFC if a feature-engine spike shows the
short-circuit opportunity is real.

### Q5: Read-only enforcement

R doesn't have a clean way to make slots read-only without active
locking. Three options:

- **Documented convention only**: tell strategy authors not to mutate
  ctx slots. Enforced by social contract.
- **Locked binding via `lockBinding`**: prevents reassignment but not
  in-place mutation. Some teeth, not full enforcement.
- **Copy-on-access**: every accessor returns a fresh copy. Defeats the
  whole performance argument.

Recommended: documented convention only. The substrate already ensures
strategies can't observe their own mutations breaking ledgr internals
(the fold engine reads from its own primitive vectors, not from ctx).
Locking would add overhead with no real safety win.

## Scope and non-scope

### In scope

- Add `ctx$close`, `ctx$open`, `ctx$high`, `ctx$low`, `ctx$volume` as
  universe-aligned numeric vectors.
- Add `ctx$idx(id)` resolver with per-backtest caching.
- Promote `ctx$positions` to documented first-class universe-aligned
  vector (already named numeric in v0.1.8.x; documentation change plus
  substrate consistency).
- Documentation: strategy guide section "Two access patterns: ergonomic
  vs high-throughput" with measured threshold guidance from Spike 5.
- Tests covering: integer-indexed accessor parity with named patterns,
  `ctx$idx()` correctness for known and unknown instruments,
  universe-alignment invariant across pulses.

### Out of scope

- `feature_at()` scalar feature accessor (deferred to feature-engine RFC).
- Read-only enforcement beyond documented convention.
- Migration of existing strategies to integer-indexed patterns
  (strategies that work today continue to work; migration is the user's
  call).
- Removing or deprecating named patterns at any horizon. The named
  patterns are the ergonomic default and stay first-class.
- Compiled-core boundary contract (separate `ledgrcore-spike` repo per
  the 2026-06-01 horizon K1 repo-split decision).

## Implementation sketch

If the RFC closes with "accept," v0.1.8.10 implementation work is
roughly:

1. **`R/pulse-context.R` additions**: populate `ctx$close`, `ctx$open`,
   etc. from `bars_mat` matrix columns at pulse-context construction.
   These already exist internally as `bars_mat$close[, i]` etc.; the
   change is exposing them as ctx slots.
2. **`R/execution-spec.R` additions**: build `id_to_idx` map at
   execution-spec construction; expose as `ctx$idx()` closure or env
   binding.
3. **`R/fold-engine.R`**: update pulse-context constructor at
   `R/fold-engine.R:180-194` to include the new slots. If Spike 4
   (reusable env) wins, the constructor becomes a slot-mutation pass on
   a reused env; if not, it stays a fresh-list constructor with extra
   slots.
4. **Strategy guide update**: add the "Two access patterns" section
   with measured threshold guidance.
5. **Test suite additions**: parity tests for integer-indexed vs named
   patterns; `ctx$idx()` tests for known and unknown instruments;
   universe-alignment invariant tests.

Estimated effort: ~1-2 weeks of focused work assuming Spikes 3-5 confirm
the substrate. Not a major refactor; mostly additive surface.

## Decision needed

For the v0.1.8.10 spec packet to cut a ticket from this RFC, the
maintainer needs to decide:

1. **Accept the proposed direction?** (direct slots, 1-based, per-backtest
   cache, documented convention) Yes / no / modified.
2. **Q1 naming convention.** Direct slots / namespaced / function
   accessors.
3. **Q3 caching policy.** Per-call / per-pulse / per-backtest.
4. **In-scope set.** Confirm or modify the list above.
5. **Spike 5 contingency.** If Spike 5 shows the integer-indexed pattern
   doesn't actually save time at production scale, does the RFC still
   proceed for ergonomics alone, or does it park?

After those decisions, the synthesis document closes the RFC and the
v0.1.8.10 ticket for the strategy callback contract addendum can be cut.

## Sources

- `inst/design/horizon.md` 2026-06-01 entry: R-side data structures as
  shared substrate for compiled-core path. Backtrader source analysis
  and substrate framing.
- `inst/design/ledgr_v0_1_8_9_spec_packet/v0_1_8_9_release_closeout.md`
  residual #2: R-side substrate.
- `inst/design/spikes/ledgr_v0_1_8_10_optimization_round_spike/README.md`:
  v0.1.8.10 spike round, especially Batch B (substrate) and Spike 5
  (LDG-2509, integer-indexed accessors).
- `dev/bench/notes/single_core_optimization_inventory.md` items A3, A5,
  A6.
- `R/fold-engine.R:180-194` (pulse context constructor).
- `R/pulse-context.R` (helper functions for ctx accessors).
- Backtrader source: `mementum/backtrader` on GitHub, specifically
  `backtrader/linebuffer.py` for the integer-cursor data structure
  pattern this RFC mirrors at the strategy contract layer.
