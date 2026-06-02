# Spike Log: Reusable Pulse-Context Env Across Pulses

**Date:** 2026-06-01 - **Host:** local development host (Windows, R 4.5.2,
collapse 2.1.7) - **Status:** v0.1.8.10 spike-round Batch B input
(LDG-2508, Spike 4).

**Script:** `dev/spikes/spike-pulse-context-env-reuse.R`. Raw CSV:
`dev/bench/results/spike_pulse_context_env_reuse.csv`.

**Relates to:**
- `R/fold-engine.R:180-194` (production per-pulse ctx constructor)
- `R/pulse-context.R` (helper functions attached to ctx)
- `dev/bench/notes/single_core_optimization_inventory.md` (A5, A6 —
  never previously spiked)

## Question

Does converting the per-pulse pulse-context constructor at
R/fold-engine.R:180-194 from fresh-list-per-pulse to reusable-env-with-
slot-mutation save wall time?

Mechanism hypothesis: fresh list with 12+ slots allocated per pulse. At
1260 pulses xlarge that's 1260 list allocations + per-slot binding work.
Reusable env mutated slot-by-slot avoids allocation.

## Method

Four variants of the ctx-construction pattern, driven by a synthetic
strategy that touches representative ctx slots per pulse (universe,
bars, cash, equity, state_prev, ts_utc, safety_state).

Variant A: fresh list per pulse (production shape).
Variant B: reusable env, named slots, no class attribute.
Variant C: reusable env, class attribute reset per pulse.
Variant D: reusable env with helper closures (close, feature) cached.

Scales: 1260 pulses x {100, 1000} inst, plus 5000 pulses x 1000 inst.

Parity gate: strategy-observable results vector identical across
variants.

## Results

```
scale            n_inst   VarA_s   VarB_s   VarC_s   VarD_s
100inst_1260p       100   0.0000   0.0000   0.0200   0.0100
1000inst_1260p     1000   0.0000   0.0000   0.0100   0.0100
1000inst_5000p     1000   0.0300   0.0000   0.0300   0.0300
```

**Parity A==B / A==C / A==D: PASS at all three scales.**

Note: VarA, VarB, VarD often land below the proc.time() resolution
(~10ms on Windows), so reported zero values mean "under timer floor",
not literal zero. The 1000 inst x 5000 pulses cell gives the cleanest
signal: VarA = 30ms total (6 us/pulse), all reusable-env variants
under the timer floor.

### Per-pulse cost (1000 inst x 5000 pulses)

| Variant            | Total | us/pulse |
|:-------------------|------:|---------:|
| A (fresh list)     | 30ms  | 6.0      |
| B (reusable env)   | <10ms | <2.0     |
| C (env + class)    | 30ms  | 6.0      |
| D (env + helpers)  | 30ms  | 6.0      |

The reusable-env without class attribute (Variant B) is the only
variant under floor. Variants C/D pay the `class(ctx) <- "..."`
attribute restoration cost per pulse, which approximately matches the
list-allocation cost in A.

## Findings

**Pulse-context list allocation alone is not a meaningful cost lever
at the measured shape.** 6 us/pulse x 1260 pulses = 7.5ms; at 5000
pulses = 30ms. Below the proc.time() resolution on the small fixture
and below 0.05% of the 199s production xlarge loop time.

**The production cost attribution names ctx_construction at ~0.9%**
of fold-loop time per the v0.1.8.8 Batch 2 telemetry (horizon line
140, 2026-05-30 entry). On a 199s xlarge loop that's ~1.8s in ctx
construction. My measurement captures only the bare `list()` allocation
cost; the production 1.8s must be in
`ledgr_update_fast_pulse_context_helpers` / `ledgr_update_pulse_context_helpers`
(R/fold-engine.R:196-221), not in the `list()` call itself.

**Class attribute restoration is the cost-equal sub-step to list
allocation.** Variants C and D (env + `class(ctx) <- "..."`) match
Variant A's wall, indicating the class-attribute work is comparable in
cost to the list allocation work. A reusable-env design that drops
the class attribute (or pre-classifies the env and never resets) is
the only env variant that wins; that change requires re-evaluating
every site that checks `inherits(ctx, "ledgr_pulse_context")`.

## Disposition

**PARK Spike 4 standalone as not in v0.1.8.10 scope.** The standalone
recovery from reusable-env is below 30ms at the production shape;
even the optimistic class-free variant saves at most ~7ms/pulse x 1260
pulses = under timer floor on production.

**The real ctx construction cost lives in the helper attachment**
(`ledgr_update_fast_pulse_context_helpers`), not in the bare list/env
allocation. A v0.1.8.10 spike for that surface would be a different
ticket — call it Spike 4b if revived — measuring helper-attachment
cost directly. Not in scope for this round.

**Substrate-emulated R baseline note for Spike 12.** Even though
Spike 4's R-side win is invisible, the env representation maps cleanly
to a struct-style layout for compiled-core consumption. Variant B
(reusable env, slot mutation) is the right substrate shape for any
future K1 measurement that needs to capture the ctx-construction
boundary cost; the comparison just isn't decisive at the v0.1.8.10
R-side budget.

## Implementation notes (deferred, not v0.1.8.10 scope)

If revived later, the ticket would:

1. Profile `ledgr_update_fast_pulse_context_helpers` directly to
   identify which helper-attachment slot is the dominant per-pulse
   cost on production xlarge.
2. Evaluate whether the helpers can be pre-bound at fold-setup time
   rather than per-pulse.
3. Re-evaluate the class-attribute necessity: every dispatch site that
   reads `inherits(ctx, "ledgr_pulse_context")` would need to be
   audited.
4. The reusable-env representation is the structural enabler but the
   measurable win is in the helpers, not the env itself.

## Source references

- `R/fold-engine.R:180-194` (ctx list constructor)
- `R/fold-engine.R:196-221` (helpers attachment — the actual cost
  surface)
- `R/pulse-context.R` (helper functions)
- `dev/bench/notes/single_core_optimization_inventory.md` (A5, A6)
- v0.1.8.8 Batch 2 telemetry (horizon 2026-05-30 entry) for
  production ctx-construction attribution
