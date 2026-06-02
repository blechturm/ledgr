# Spike Log: state$positions Primitive Representation Re-Spike

**Date:** 2026-06-01 - **Host:** local development host (Windows, R 4.5.2,
collapse 2.1.7) - **Status:** v0.1.8.10 spike-round Batch B input
(LDG-2507, Spike 3). Re-spike of v0.1.8.9 LDG-2482.

**Script:** `dev/spikes/spike-state-positions-primitive.R`. Raw CSV:
`dev/bench/results/spike_state_positions_primitive.csv`.

**Relates to:**
- `R/fold-engine.R:354-360` (production write site:
  `state$positions[[instrument_id]] <- cur_qty + qty`)
- `dev/spikes/spike-state-positions-representation.{R,md}` (v0.1.8.9
  prior measurement; this spike's re-measurement compares directly)
- `dev/bench/notes/single_core_optimization_inventory.md` (A3)
- LDG-2502 / per-lane attribution (v0.1.8.9 deferral disposition)
- LDG-2515 / Spike 11 (substrate-emulated R baseline note feeds
  Spike 12 K1 measurement in the `ledgrcore-spike` external repo)

## Question

Re-measure `state$positions` write variants at post-v0.1.8.9 production
shape. Two questions:

1. Does it deliver measurable R-side wins at the post-v0.1.8.9 shape?
2. Does it serve as substrate for compiled-core boundary cost reduction
   (the Spike 12 K1 spike needs a substrate-emulated R baseline; the
   contiguous-numeric representation maps directly to compiled memory)?

## Method

Four variants of the production write pattern. Each mimics the
production ctx-capture refcount-elevation pattern:

    ctx <- list(positions = state$positions, ...)  # refcount += 1
    state$positions[[id]] <- new_value             # potential copy

Variant A: current named-vector `state$positions` (production baseline).
Variant B: integer-indexed `numeric()` + one-time `id_to_idx` map.
Variant C: `state$positions` as `new.env(parent = emptyenv())`.
Variant D: integer-indexed `numeric()` + `collapse::setv(...)` writes.

Scales: 100k writes at {500, 1000, 2000} instruments. 100k writes
approximates xlarge fill count (130k).

Parity gate: final positions vector byte-identical across all variants.

## Results

```
n_inst   VarA_s   VarB_s   VarC_s   VarD_s   B_sp   C_sp   D_sp
   500    0.370    0.230    0.060    0.270   1.6x   6.2x   1.4x
  1000    0.660    0.390    0.060    0.390   1.7x  11.0x   1.7x
  2000    0.970    0.600    0.060    0.570   1.6x  16.2x   1.7x
```

**Parity A==B / A==C / A==D: PASS at all three scales.**

### Comparison with v0.1.8.9 Spike 3 (LDG-2482)

v0.1.8.9 measurement at 1000 inst x 100k mutations:

| Variant     | v0.1.8.9 | v0.1.8.10 re-spike | Direction |
|------------:|---------:|-------------------:|-----------|
| current     |   0.78s  |   0.66s            | -15%      |
| intvec      |   0.40s  |   0.39s            | flat      |
| env_pos     |   0.17s  |   0.06s            | -65%      |
| setv        |   0.41s  |   0.39s            | flat      |

env_positions improved 65% from v0.1.8.9 — likely the post-Batches 4/5
vectorize work reduced surrounding loop overhead so the env-slot
advantage shows up more cleanly. The current pattern improved 15% from
the same vectorize work.

### Per-write cost growth with universe size (current variant)

- 500 inst:  3.7 us/write
- 1000 inst: 6.6 us/write
- 2000 inst: 4.85 us/write (sub-linear; named-vector copy amortizes)

env_positions stays flat at ~0.6 us/write across all universe sizes —
the env-slot mutation is O(1) regardless of universe size.

## Findings

**env_positions is the R-side optimal variant (6-16x speedup, scales
with universe size).** At 2000 inst x 100k mutations it's 16x over
current. The mechanism is reference semantics: env slots mutate
without triggering copy-on-write because `ctx$positions` capturing the
env captures a reference, not a value.

**intvec_id_map is the substrate-emulated R baseline (1.6-1.7x R-side
speedup; cleanest compiled-core mapping).** The contiguous numeric
representation with an integer-indexed `id_to_idx` map is exactly the
shape a compiled fold core would consume across the FFI boundary. The
R-side win is modest (1.7x at xlarge), but the substrate value is the
load-bearing reason to ship it: post-Spike-12 K1 measurement against
substrate-emulated R uses this exact shape as its baseline.

**collapse::setv is tied with intvec (1.7x).** Per the v0.1.8.9 spike
finding, setv's no-copy edge does not materialize at this universe
scale because the surrounding loop overhead (id lookup, idx lookup,
ctx-list construction) dominates. setv stays a write-side option but
is not preferred over plain `numeric()[idx] <- value`.

**Snapshot-semantics risk for Variant C (env_positions).** PRESERVED
from v0.1.8.9: env_positions mutates underlying memory in place, so
`ctx$positions` captured at pulse start sees subsequent mutations
within the pulse. The current named-vector pattern captures a value
snapshot. This changes strategy-observable semantics if a strategy
holds `ctx$positions` across multiple operations within a single
callback invocation. The v0.1.8.10 implementation ticket MUST treat
this as a contract change requiring explicit strategy-context surface
review.

### Wall translation to production

Production reference: `density_high_xlarge_durable` 232s wall, 199s
loop, ~130k fills at 1000 inst (post-v0.1.8.9 Batch 8 closeout
numbers).

Per-fill state-update cost at 1000 inst current variant: 6.6 us.
At 130k fills production: 6.6 * 130000 = **0.86s production wall**.

env_positions recovery (16x): saves ~0.81s.
intvec_id_map recovery (1.7x): saves ~0.36s.

Amdahl bound: 0.81s / 199s loop = 0.4% wall improvement standalone.
Small in absolute terms but the substrate value (load-bearing for
Spike 12) elevates the priority.

## Disposition

**PROCEED for v0.1.8.10 substrate ticket, but pair with the strategy
callback contract addendum implementation.** The intvec_id_map shape
(Variant B) is the substrate-emulated R baseline that:

- The accessor RFC's `ctx$vec` namespace can be implemented on top of
  (`ctx$vec$id` IS the universe character vector; `state$positions`
  becomes a numeric() aligned with it; `ctx$idx(id)` resolves via the
  same `id_to_idx` map).
- The helpers RFC's Pass 1 internal optimization consumes (helpers
  reading `ctx$vec$positions` get integer-indexed access at no
  semantic cost change).
- The Spike 12 K1 measurement baseline requires (substrate-emulated R
  vs compiled core comparison).

**Variant C (env_positions) NOT recommended despite 16x speedup**:
the snapshot-semantics change is a strategy-context contract change
not in scope for v0.1.8.10. Re-evaluate post-v0.1.9 target-risk if
in-pulse position-mutation observability becomes a documented contract.

## Implementation notes for the v0.1.8.10 ticket

1. Change `state$positions` from `stats::setNames(numeric(n), univ)` to
   bare `numeric(n)`; build `id_to_idx <- stats::setNames(seq_len(n),
   univ)` once at fold setup.
2. Per-fill write at R/fold-engine.R:360 becomes
   `state$positions[id_to_idx[[instrument_id]]] <- cur_qty + qty`.
3. ctx$vec$positions = state$positions (numeric, universe-aligned).
4. ctx$vec$id = universe (character vector).
5. ctx$idx(id) = id_to_idx[[id]] (single-arg resolver per the accessor
   RFC synthesis).
6. Strategy helpers (signal_return, select_top_n, weight_equal,
   target_rebalance) consume ctx$vec$positions where useful — Pass 1
   internal optimization per the helpers RFC.
7. Backward-compat: maintain a named-vector view via accessor for any
   legacy callsite; deprecate in v0.1.9 spec packet review.
8. Parity test: existing fold-engine state output (named-vector with
   per-fill writes) vs new shape (bare numeric + id_to_idx) on every
   existing fixture; final state byte-identical.

## Source references

- `R/fold-engine.R:354-360` (write site)
- `dev/spikes/spike-state-positions-representation.{R,md}` (v0.1.8.9
  prior measurement)
- `dev/bench/notes/single_core_optimization_inventory.md` (A3)
- `inst/design/rfc/rfc_strategy_callback_contract_addendum_v0_1_8_10_synthesis.md`
- `inst/design/rfc/rfc_strategy_authoring_helpers_v0_1_8_x_synthesis.md`
