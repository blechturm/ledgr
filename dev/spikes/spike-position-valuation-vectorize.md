# Spike Log: Per-Pulse Position Valuation Loop (current vs vectorized)

**Date:** 2026-05-31 - **Host:** local development host - R 4.5.2 - **Status:**
v0.1.8.9 optimization-round input (Batch A, Spike 1).

**Script:** `dev/spikes/spike-position-valuation-vectorize.R`. Raw CSV
(gitignored): `dev/bench/results/spike_position_valuation_vectorize.csv`.

**Relates to:** `dev/bench/notes/per_pulse_complexity_findings.md` (Suspect 1),
`dev/bench/notes/single_core_optimization_inventory.md` (A1), LDG-2480.

## Question

The per-pulse position valuation loop at `R/fold-engine.R:164-170` iterates
`seq_along(instrument_ids)` per pulse to mark positions to market for the
pulse-context `equity` field. The loop is O(n_inst) per pulse regardless of
fill activity. How much does replacing it with
`sum(as.numeric(state$positions) * bars_mat$close[, i])` save, and does the
early-skip on `qty == 0` matter?

## Method

Faithful replica of the fold-engine pattern: `state$positions` as a named
numeric vector aligned to `instrument_ids`, `bars_mat$close` as a matrix of
shape [n_inst, n_pulses]. The current-loop body matches `R/fold-engine.R`
line-for-line including the `qty == 0` early-skip. The `vec` variant tests
the suggested fix. The `vec_ord` variant tests the alignment-risk hedge:
index by `instrument_ids` before `as.numeric()`.

Five shapes timed: {100, 500, 1000} instruments x 1260 pulses at density
0.5, plus 1000 x 1260 at densities {0.1, 0.9} to test whether early-skip
benefits the current loop on sparse positions.

## Results

```
inst   pulses  density |   current       vec   vec_ord |   cur/vec   cur/ord
100    1260    0.50    |    0.090s    0.000s    0.020s |      Inf       4.5x
500    1260    0.50    |    0.970s    0.000s    0.000s |      Inf       Inf
1000   1260    0.50    |    3.290s    0.000s    0.000s |      Inf       Inf
1000   1260    0.10    |    3.230s    0.000s    0.000s |      Inf       Inf
1000   1260    0.90    |    3.290s    0.000s    0.000s |      Inf       Inf
```

Parity check PASS: all three variants return identical `positions_value`.

## Findings

**Mechanism confirmed.** The current R-interpreted loop is O(n_inst x
n_pulses) and the vectorized replacement collapses to a single `sum()` call
that R measures as zero on these shapes. Speedup is effectively infinite on
the isolated benchmark.

**Early-skip does not help the current loop.** Wall times at density 0.1,
0.5, 0.9 are 3.23s, 3.29s, 3.29s — essentially identical. The per-iteration
overhead (the `instrument_ids[[j]]` lookup plus the
`state$positions[[inst]] %||% 0` named-list lookup) dominates the
multiplication work. Even when 90% of positions are zero, R still pays the
loop iteration cost for every instrument.

This matters for the fix decision: there is no "sparse production workload"
where the current loop wins. The vectorized replacement is uniformly faster.

**The vec_ord variant is also essentially free.** Indexing
`state$positions[instrument_ids]` before `as.numeric()` is a single subset
operation that R handles in compiled C. The alignment-risk hedge is cheap
enough to include unconditionally.

## Wall translation

Reference workload: `density_high_xlarge_durable` (1000 inst x 1260 pulses,
SMA 5/10 crossover, durable) runs in 445.02s wall, 413.47s loop.

The spike measures 3.29s for the current loop on 1000 x 1260 in isolation.
Production cost is between this lower bound and the inventory's ~9s upper
estimate. The difference is per-instrument fold-engine context cost
(accessing `state`, the `%||%` operator, the matrix index) that the spike
captures but the production also pays around the loop, in surrounding
machinery the spike does not exercise.

Amdahl bound:

- If production cost is 3.3s of 413.5s loop: p = 0.008, max wall speedup
  = 1.008x (~3.3s of 445s wall).
- If production cost is 9s of 413.5s loop: p = 0.022, max wall speedup =
  1.022x (~9s of 445s wall).

**The architectural win is bigger than the wall win.** Eliminating an
O(n_inst) per-pulse component flattens the per-fill scaling curve. The
visible direct wall improvement is modest (1-2%), but the per-fill cost
curve `mus_per_fill_engine` should drop more on xlarge than on large after
the fix because xlarge spends 4x more iterations on this loop. That
scaling-curve flattening is the load-bearing outcome.

## Caveats

- **Isolated overestimate not observed.** v0.1.8.7 buffer spike overestimated
  production cost ~3x. This spike measures the loop overhead directly, with
  no surrounding fold machinery, so it likely UNDERESTIMATES production cost
  rather than overestimating. The production loop also pays
  `bars_mat$close[j, i]` (which is fine — same in spike) plus the
  surrounding ctx-build machinery the spike skips.
- **The real-run re-profile is the verdict.** Apply the vectorize fix to
  `R/fold-engine.R:164-170`, re-run `density_high_xlarge_durable` and
  `density_high_large_durable` on the workload grid, and confirm
  `t_loop_sec` drops on both cells while `mus_per_fill_engine` flattens
  between them.
- **Alignment risk.** `as.numeric(state$positions)` returns values in the
  order they are stored in the named vector, which under current production
  setup should match `instrument_ids` order. The `vec_ord` variant indexes
  by `instrument_ids` first; it is the safe choice when the order
  contract is not guaranteed. Since both are essentially free, use the
  `vec_ord` form in production.

## Recommendation

**Proceed to v0.1.8.9 implementation ticket.** Use the `vec_ord` variant in
the fix to remove the alignment risk:

```r
positions_value <- sum(as.numeric(state$positions[instrument_ids]) *
                       bars_mat$close[, i])
```

Implementation lane: smallest blast radius of the three Batch A spikes,
single function change, no contract change, immediate before/after gate via
the workload grid. Recommend Spike 1's fix lands first in the v0.1.8.9
implementation order.

Expected real-run signature: `t_loop_sec` on `density_high_xlarge_durable`
drops by 3-9s; `mus_per_fill_engine` flattens between large and xlarge
relative to the LDG-2479 baseline.
