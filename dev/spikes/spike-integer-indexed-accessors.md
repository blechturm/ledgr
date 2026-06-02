# Spike Log: Integer-Indexed Strategy Callback Accessors

**Date:** 2026-06-01 - **Host:** local development host (Windows, R 4.5.2,
collapse 2.1.7) - **Status:** v0.1.8.10 spike-round Batch B input
(LDG-2509, Spike 5).

**Script:** `dev/spikes/spike-integer-indexed-accessors.R`. Raw CSV:
`dev/bench/results/spike_integer_indexed_accessors.csv`.

**Relates to:**
- `R/fold-engine.R:181-220` (ctx construction and helper attachments)
- `R/pulse-context.R` (helper functions for ctx accessors)
- `inst/design/rfc/rfc_strategy_callback_contract_addendum_v0_1_8_10_synthesis.md`
  (the bound contract surface: `ctx$vec` namespace, `ctx$idx()`
  resolver, bulk `ctx$vec$feature(feature_id)`)
- `inst/design/rfc/rfc_strategy_authoring_helpers_v0_1_8_x_synthesis.md`
  (Pass 1: existing helpers consume `ctx$vec`)
- `dev/bench/notes/single_core_optimization_inventory.md` (related to
  A5/A6 but new item — accessor cost not previously inventoried)

## Question

Measure per-pulse strategy-callback cost across four access patterns to
inform the implementation ticket for the bound `ctx$vec` contract
addendum. Specifically:

- How much does the worst-case data-frame char-equality access pattern
  cost a strategy callback today?
- Does the `ctx$vec$close` namespace pay an extra deref over a flat
  `ctx$close` atomic vector?
- Does env-slot access (`ctx$env$close`) beat list-element access?

## Method

A representative cross-sectional strategy (read close prices for the
full universe, pick top-3 by rank, return target qty for picks)
implemented four ways:

Variant A: char-equality DF access:
`ctx$bars$close[ctx$bars$instrument_id == id]` via `vapply` over the
universe. This is the worst-case strategy author pattern — O(n_inst^2)
per pulse because each ID lookup scans the whole bars vector.
Variant B: flat atomic vector `ctx$close[idx]` (universe-aligned).
Variant C: `ctx$vec$close` namespace per the RFC synthesis (one extra
list-dereference vs Variant B).
Variant D: env-slot `ctx$env$close` access.

Driver: 1260 pulses x {100, 500, 1000} instruments, ctx rebuilt per
pulse with fresh close prices.

Parity gate: target vectors byte-identical across all variants.

## Results

```
scale       n_inst   VarA_s    VarB_s    VarC_s    VarD_s   B_sp    C_sp    D_sp
100inst        100   0.3900    0.0200    0.0100    0.0200  19.5x   39.0x   19.5x
500inst        500   2.1300    0.0300    0.0300    0.0300  71.0x   71.0x   71.0x
1000inst      1000   5.7500    0.0400    0.0500    0.0400 143.8x  115.0x  143.8x
```

**Parity A==B / A==C / A==D: PASS at all three scales.**

### Per-pulse callback cost

| Scale     | VarA us/pulse | VarB us/pulse | VarC us/pulse | VarD us/pulse |
|----------:|--------------:|--------------:|--------------:|--------------:|
| 100 inst  |          309  |           16  |            8  |           16  |
| 500 inst  |         1690  |           24  |           24  |           24  |
| 1000 inst |         4563  |           32  |           40  |           32  |

VarA's per-pulse cost grows as O(n_inst^2). VarB/C/D grow linearly
with n_inst — the per-pulse `order()` cost on the close vector.

## Findings

**The `ctx$vec` namespace is essentially free vs flat atomic access.**
At 1000 inst the namespace deref adds ~8 us/pulse vs flat
(`ctx$vec$close` is 40 us/pulse vs `ctx$close` 32 us/pulse). Across
1260 pulses that's 10ms total. The namespace is structurally cleaner
(`ctx$vec$id`, `ctx$vec$close`, `ctx$vec$feature(feature_id)`
co-located) and the cost is invisible in production wall.

**Worst-case char-equality patterns are ~144x slower than vec access.**
At 1000 inst x 1260 pulses, a strategy that writes
`ctx$bars$close[ctx$bars$instrument_id == id]` per ID burns 5.75s in
the callback alone. Most production strategies do not write this
pattern (they call `ctx$bars$close` once and index by position), but
the contract addendum's value here is foot-gun elimination: with
`ctx$vec$close`, the only syntactically natural pattern is the O(1)
indexed access; the char-equality scan becomes both ugly to type and
explicitly wrong.

**Honest caveat on VarA representativeness.** The 144x speedup is the
worst-case author pattern, not the average production pattern.
Strategies that already use `bars$close` (full vector) plus
`stats::setNames(..., bars$instrument_id)` for target assembly pay
O(n_inst), not O(n_inst^2). The accessor RFC's contribution to those
strategies is structural (one canonical surface) plus the bulk
`ctx$vec$feature(feature_id)` read path which Spike 5 does not measure
in isolation.

**Env-slot access (VarD) is tied with flat atomic (VarB).** No
measurable difference at any scale. Env-slot access does NOT add value
over the namespace; the namespace's list-deref cost is below
measurement noise.

## Disposition

**SHIP `ctx$vec` namespace as bound by the RFC synthesis.** Spike 5
confirms the namespace cost is negligible (under 10ms/run at xlarge)
and the worst-case foot-gun elimination is meaningful.

**The accessor RFC's `ctx$vec` namespace IS the contract addendum
bound for v0.1.8.10**; this spike's contribution is concrete cost
evidence for the implementation ticket. Specifically:

- `ctx$vec$close` over `ctx$close` (no flat atomic at top level): the
  ~10ms cost over 1260 pulses is invisible and the namespace
  cohesion is the RFC's stated preference.
- `ctx$vec$id` (the universe character vector) is universe-aligned
  with `ctx$vec$close`, `ctx$vec$open`, etc. by construction; the
  `ctx$idx(id)` resolver maps id → integer position.
- `ctx$vec$feature(feature_id)` returns a universe-aligned numeric
  vector for one feature; the bulk read path is the RFC's load-bearing
  performance lever for feature-heavy strategies (not measured
  standalone in Spike 5; production implementation will time this
  directly against an alias-map read).

**Substrate-emulated R baseline value for Spike 12.** The flat-atomic
representation (Variant B) backing `ctx$vec` is the substrate-emulated
R baseline that a compiled fold core would consume across the FFI
boundary; ledgr_v0.1.8.10's accessor implementation produces this
substrate as a side-effect.

## Implementation notes for the v0.1.8.10 ticket

1. Add `ctx$vec` namespace at ctx-construction time
   (R/fold-engine.R:181-194):
   ```r
   ctx$vec <- list(
     id = instrument_ids,            # universe character vector
     close = bars_current$close,     # universe-aligned numeric
     open = bars_current$open,
     high = bars_current$high,
     low = bars_current$low,
     volume = bars_current$volume,
     positions = state$positions,    # numeric, aligned (per Spike 3)
     feature = function(feature_id) ... # bulk feature read
   )
   ```
2. Add `ctx$idx(id)` as single-arg resolver returning integer position.
3. Existing `ctx$bars`, `ctx$positions`, `ctx$close`/`ctx$feature`
   (scalar helper) etc. preserved as-is for backward compat. Vignette
   examples may move to `ctx$vec` patterns over time but no break.
4. Pass 1 internal optimization (helpers RFC): `signal_return`,
   `select_top_n`, `weight_equal`, `target_rebalance` consume
   `ctx$vec` where it reduces per-instrument scanning.
5. Parity gate: existing strategy fixtures produce byte-identical
   target vectors via both the old surface and the new `ctx$vec`
   surface.
6. Documentation: vignettes/strategy-authoring teaches `ctx$vec` as
   the preferred surface for cross-sectional strategies; scalar
   `ctx$close(id)` / `ctx$feature(id, fid)` remain documented for
   one-instrument-at-a-time strategies.

## Source references

- `R/fold-engine.R:181-220` (ctx construction)
- `R/pulse-context.R` (helper functions)
- `inst/design/rfc/rfc_strategy_callback_contract_addendum_v0_1_8_10_synthesis.md`
  (canonical contract)
- `inst/design/rfc/rfc_strategy_authoring_helpers_v0_1_8_x_synthesis.md`
  (Pass 1 internal helpers consume `ctx$vec`)
- LDG-2507 / Spike 3 (paired: state$positions numeric becomes
  ctx$vec$positions)
