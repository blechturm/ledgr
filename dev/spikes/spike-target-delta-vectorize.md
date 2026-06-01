# Spike Log: Per-Target Early-Skip Loop (current vs vectorized delta)

**Date:** 2026-05-31 - **Host:** local development host - R 4.5.2 - **Status:**
v0.1.8.9 optimization-round input (Batch A, Spike 2).

**Script:** `dev/spikes/spike-target-delta-vectorize.R`. Raw CSV (gitignored):
`dev/bench/results/spike_target_delta_vectorize.csv`.

**Relates to:** `dev/bench/notes/per_pulse_complexity_findings.md` (Suspect 2),
`dev/bench/notes/single_core_optimization_inventory.md` (A2), LDG-2481.

## Question

The per-target loop at `R/fold-engine.R:277-359` iterates `names(targets)` per
pulse, doing per-instrument `[[id]]` lookups against both `targets` and
`state$positions`, a subtraction, and an abs comparison. At 1000 instruments
with ~135 fills per instrument over 1260 pulses, the loop body runs 1.26M
times to do ~133k real fills (~90% of iterations are skip). How much does
replacing the loop with a vectorized `delta_vec` + `which()` recover?

## Method

Replicates `targets` as a length-`n_inst` named numeric vector (because
`ctx$flat()` returns a zero-vector of length `n_inst`), `state$positions` as
named numeric vector. The spike measures only the skip-or-not overhead — the
heavy fill work after the skip check is unchanged between variants. A dummy
`fills <- fills + 1L` counter replaces the heavy work so the spike isolates
the cost difference, not the absolute fill cost.

Three shapes timed: {100, 500, 1000} instruments x 1260 pulses, each with
~135 fills per instrument (matching the LDG-2479 xlarge cell fill density).

## Results

```
inst   pulses  fpi  skip_ratio |   current       vec |   cur/vec
100    1260    135    0.893    |    0.140s    0.010s |     14.0x
500    1260    135    0.893    |    1.750s    0.050s |     35.0x
1000   1260    135    0.893    |    6.160s    0.060s |    102.7x
```

Parity check PASS: 11 fills in both variants on the 100-inst pulse fixture.

## Findings

**Mechanism confirmed.** The current R-interpreted loop pays per-instrument
`[[id]]` lookup overhead on every iteration, regardless of whether the
iteration will fire a fill. The vectorized variant computes the full delta
vector in one C call and iterates only over the indices where work is
needed, dropping ~1.26M cheap iterations to ~133k real ones at the xlarge
scale.

**Speedup scales with universe size.** 14.0x at 100 inst, 35.0x at 500 inst,
102.7x at 1000 inst. This is the architectural-flattening signature: the
larger the universe, the more cheap iterations the current loop pays, and
the more the vectorized variant wins. This is exactly the scaling fix the
per-fill cost curve needs.

**The skip ratio holds at 0.893 across all shapes** because fills per
instrument is fixed at 135 and pulses at 1260. So `fills_per_pulse ~=
0.107 * n_inst` is constant across the shapes. The current loop's wall grows
nearly linearly with `n_inst` (100 -> 500 = 12.5x; 500 -> 1000 = 3.5x;
extra-linear at small scale, sublinear at large scale because of cache
behavior and warmup). The vec wall is essentially flat (10ms -> 50ms ->
60ms).

## Wall translation

Reference workload: `density_high_xlarge_durable` runs in 445.02s wall,
413.47s loop.

Spike measures 6.16s on 1000 x 1260 at the production fill density.
Production likely scales similarly. The per_pulse_complexity_findings.md
estimate is ~12s of 413.5s loop on xlarge; the spike at 6.16s suggests the
inventory estimate is close (within a factor of 2) but possibly on the high
side.

Amdahl bound:

- If production cost is 6.2s of 413.5s loop: p = 0.015, max wall speedup
  = 1.015x (~6.2s of 445s wall).
- If production cost is 12s of 413.5s loop: p = 0.029, max wall speedup
  = 1.029x (~12s of 445s wall).

Combined with Spike 1: roughly 9-21s of 445s wall recoverable on xlarge.
Both fixes share the same architectural-flattening payoff: per-fill cost
curve flattens between large and xlarge after they land.

## Caveats

- **Isolated underestimate likely.** The spike replaces the heavy fill work
  with a counter. Production fill work includes `bars_by_id[[id]]` lookup,
  `next_bar` row subset, fill proposal/resolution, event emit, and state
  mutation. None of those are in the spike, but they are also unchanged
  between variants — so the SPIKE measures the cost difference correctly,
  even though the absolute seconds are not directly the production wall.
- **Alignment risk.** `names(targets)` may not match `state$positions`
  ordering in the general case. The vec variant uses
  `state$positions[names(targets)]` (subset by name) to stay safe; the
  spike confirms this returns correct values.
- **Real-run re-profile is the verdict.** Apply the vec fix to
  `R/fold-engine.R:277-359`, re-run xlarge and large cells, confirm
  `t_loop_sec` drops and `mus_per_fill_engine` flattens between scales.

## Recommendation

**Proceed to v0.1.8.9 implementation ticket.** The fix is mechanical:

```r
desired_vec <- as.numeric(targets)
positions_vec <- as.numeric(state$positions[names(targets)])
delta_vec <- desired_vec - positions_vec
fill_idx <- which(abs(delta_vec) > sqrt(.Machine$double.eps))
for (j in fill_idx) {
  instrument_id <- names(targets)[[j]]
  delta <- delta_vec[[j]]
  cur_qty <- positions_vec[[j]]
  # ... existing heavy fill work ...
}
```

Sequencing: implement after Spike 1's fix (smaller blast radius, easier to
validate). The two fixes are independent and can be merged separately or
together; sequencing them lets the workload grid attribute the wall delta to
each cleanly.

Expected real-run signature: combined with Spike 1, `t_loop_sec` on
xlarge drops by 10-20s, and `mus_per_fill_engine` should fall meaningfully
between large and xlarge.
