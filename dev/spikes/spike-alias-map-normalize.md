# Spike Log: active_alias_map One-Time Normalization

**Date:** 2026-06-01 - **Host:** local development host (Windows, R 4.5.2,
collapse 2.1.7) - **Status:** v0.1.8.10 spike-round Batch C input
(LDG-2513, Spike 9).

**Script:** `dev/spikes/spike-alias-map-normalize.R`. Raw CSV:
`dev/bench/results/spike_alias_map_normalize.csv`.

**Relates to:**
- `R/fold-engine.R:61` (one-time normalize at fold entry, BEFORE the
  pulse loop — this is the production reality the spike spec misframed)
- `R/fold-engine.R:196-221` (per-pulse pulse-context-helpers update;
  passes the already-normalized map through)
- `R/feature-alias-map.R:90-104` (`ledgr_feature_lookup_map` — calls
  `ledgr_alias_map_storage` per accessor invocation, which
  re-normalizes)
- `R/feature-alias-map.R:11-24` (`ledgr_normalize_alias_map` — the
  function being measured)
- `dev/bench/notes/single_core_optimization_inventory.md` (A7)
- `inst/design/rfc/rfc_strategy_callback_contract_addendum_v0_1_8_10_synthesis.md`
  (the accessor RFC bound for v0.1.8.10; subsumes this spike's lever)

## Question

Measure the per-pulse cost of `active_alias_map` normalization and
decide whether lifting it outside the loop saves wall time.

## Mechanism re-framing

The spike spec hypothesises that the alias_map "is currently
re-normalized per pulse inside R/fold-engine.R:61, 204-218." Production
code review shows this is partly inaccurate:

- `R/fold-engine.R:61` normalizes the alias map ONCE before the pulse
  loop:
  ```r
  active_alias_map <- ledgr_normalize_alias_map(execution$active_alias_map)
  ```
- The per-pulse pulse-context-helpers update (lines 196-221) passes
  the already-normalized map through to
  `ledgr_update_fast_pulse_context_helpers` /
  `ledgr_update_pulse_context_helpers`.
- INSIDE those helpers, the strategy-facing accessor
  `ledgr_feature_lookup_map` (`R/feature-alias-map.R:90`) calls
  `ledgr_alias_map_storage(active_alias_map)`, which re-normalizes per
  accessor invocation. If a strategy callback invokes `ctx$features(id)`
  N times per pulse, the normalize fires N times per pulse.

So the real cost lever is "cache the normalized output inside the
accessor", not "lift outside the fold loop" — it's already lifted at
the fold-engine entry, just not at the accessor cache.

## Method

Three variants of the per-call work:

Variant A: per-call normalize (production accessor shape — what the
strategy callback pays today through `ledgr_feature_lookup_map`).
Variant B: one-time normalize cached at fold entry; per-call cost is
just a list lookup.
Variant C: pre-resolved alias-to-index map built at execution-spec
construction; per-call cost is a single integer lookup. This is the
natural shape if the strategy callback accesses features via the
`ctx$vec$feature(feature_id)` bulk-read path bound by the accessor
RFC synthesis.

Scales (sweep across plausible accessor-call patterns):

| Label                       | n_aliases | n_calls    | Scenario |
|:----------------------------|----------:|-----------:|:---------|
| 10alias_1260p               |        10 |       1260 | Small alias map, 1 accessor call/pulse |
| 100alias_1260p              |       100 |       1260 | Big alias map, 1 accessor call/pulse |
| 100alias_100kcalls          |       100 |     100000 | 100k accessor calls (e.g. 100 inst x 1000 calls) |
| 100alias_1.26Mcalls         |       100 |    1260000 | 1000 inst x 1260 pulses (per-inst feature lookup) |

## Results

```
scale                  n_alias  n_calls    VarA_s    VarB_s    VarC_s   A_us/call    B_sp    C_sp
10alias_1260p              10     1260    0.0100    0.0000    0.0000       7.937   huge    huge
100alias_1260p            100     1260    0.0100    0.0000    0.0000       7.937   huge    huge
100alias_100kcalls        100   100000    0.4200    0.0000    0.0000       4.200   huge    huge
100alias_1.26Mcalls       100  1260000    5.4300    0.0900    0.0300       4.310  60.3x  181.0x
```

VarA per-call cost is ~4-8 us/call depending on scale; flat under
batched conditions.

### At the spike spec's literal decision threshold

```
Decision rule: if VarA at 1260 calls x 100 aliases < 0.5s => park
VarA at that shape: 0.0100s => PARK (below threshold)
```

By the spike spec's literal reading (treating "1260 calls" as one
accessor invocation per pulse), this entry parks.

### At the realistic worst-case shape

```
1000 inst x 1260 pulses, accessor called per inst per pulse:
  VarA: 5.43s standalone
  VarB: 0.09s   (60x)
  VarC: 0.03s   (180x)
```

If a feature-heavy cross-sectional strategy calls
`ctx$features(instrument_id)` per instrument per pulse, the
production cost is **5.4s on xlarge** — well above the threshold,
and the recovery is meaningful.

## Findings

**Decision rule is shape-dependent.** Per literal reading
(1260 calls / 100 aliases), the cost is 0.01s and we park. Per realistic
worst case (1.26M calls — strategy calls accessor per inst per pulse),
the cost is 5.4s and we ticket.

**The accessor RFC subsumes this spike.** The bound `ctx$vec` namespace
introduces `ctx$vec$feature(feature_id)` — a BULK read that returns a
universe-aligned numeric vector for one feature in one call. With
the bulk read path, the worst-case scenario becomes
`1260 pulses x n_features` calls, not
`1260 pulses x n_instruments x n_features` calls. At
1260 pulses x ~10 features (typical alias map size) that's 12.6k calls
→ ~0.1s standalone. Below threshold.

**The pre-resolved index (Variant C) is the natural cache shape for
the bulk-read implementation.** When `ctx$vec$feature(feature_id)`
resolves the feature_id to its concrete feature_id (alias resolution),
the work happens via a pre-built index: O(1) lookup, no normalize
call. This is the inherent shape the accessor RFC implementation
produces.

## Disposition

**PARK Spike 9 as a standalone ticket.** The fix happens incidentally
as part of the accessor RFC implementation:

- `ctx$vec$feature(feature_id)` resolves the alias via a pre-built
  index map; no per-call normalize.
- The fold engine's one-time normalize at `R/fold-engine.R:61`
  remains correct.
- The legacy `ctx$features(id, feature_map)` / `ctx$features(id)`
  accessor surface stays as-is; its per-call normalize is an
  acceptable cost for the use cases that still depend on it
  (single-instrument feature lookups).

**Cross-reference note for the v0.1.8.10 accessor implementation
ticket.** When implementing `ctx$vec$feature(feature_id)`, the
production code should:

1. Build a `feature_id_to_concrete_id` index at fold-engine entry
   (one alias-map normalize, then `match()` from alias names to
   concrete ids).
2. The accessor's per-call work is a single integer lookup in that
   index plus a vector slice from the projection.
3. No `ledgr_normalize_alias_map` or `ledgr_alias_map_storage` call
   inside the per-call path.

## Source references

- `R/fold-engine.R:61` (production one-time normalize before loop)
- `R/feature-alias-map.R:11-24` (normalize function being measured)
- `R/feature-alias-map.R:90-104` (per-accessor lookup that triggers
  the re-normalize today)
- `dev/bench/notes/single_core_optimization_inventory.md` (A7)
- `inst/design/rfc/rfc_strategy_callback_contract_addendum_v0_1_8_10_synthesis.md`
  (the v0.1.8.10 implementation ticket that subsumes this spike)
