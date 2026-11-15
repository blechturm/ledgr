# Protocol cut18-loop-1

The Cut 18 timing record of LDG-3236: the simplified lean loop with the
lean-owned checks (workstream 36) against the pin, the method of
`cut16-loop-1` unchanged (Cut 18 decision 7). Both arms install the pin
`d5b3a151`; the runner is launched with

    --candidate-overlay=dev/lean_core,dev/bench/v0_2_3_lean_tuning_profile/descriptors.R,dev/spikes/r_floor/fixture.R

so both arms read the workload definitions from the same exported files
(`descriptors.R`, shared with the cost map and the paired comparisons), and
the candidate arm also sources the lean execution sources `checks.R`, `fifo.R`,
`plan.R`, `loop.R` and `loop_harness.R` from the committed tree (debug off,
every function `cmpfun`-compiled, as the installed pin is byte-compiled)
and installs the lean loop with `lean_loop_install()`. A lean source other
than these, `load.R` and `prepare.R` refuses the slot, so a file extracted
(Cut 18's checks.R) cannot be left out. Lean preparation (`prepare.R`) is not
installed: preparation stays the pin's (Section 19.1). Eight alternating
pairs per cell (the harness floor). The record reports; each cell's bound
is 1.0 (the lean arm no slower than the pin).

## Workloads

Each slot builds a sealed store in its work directory, outside both clocks,
opens it with `verify = TRUE` and runs one committed run of a workload
descriptor (`descriptors.R`) on simulated bars (`dev/spikes/r_floor/fixture.R`):

| descriptor | instruments | pulses | workload | published PMwR (s) |
| --- | ---: | ---: | --- | ---: |
| `10x7200` | 10 | 7,200 | crossover | 0.14 |
| `20x23400` | 20 | 23,400 | crossover | 0.57 |
| `500x1260` | 500 | 1,260 | crossover | none |
| `1166x252` | 1,166 | 252 | crossover | 0.27 |
| `slice2_10x7200` | 10 | 7,200 | slice 2 | none |

The crossover is the published rule (SMA 5/10 transitions, quantity 0 or 1,
cash 1e7, zero cost, no risk). `slice2_10x7200` uses the same 10 x 7,200
bars: cash 1e7; `spread_bps(10)`, `fixed_fee(1)`, `notional_bps_fee(5)`;
`max_weight(0.05)`; `ledgr_target_rebalance()` at weight 0.08 per instrument
and `invest_fraction` 0.9 on the first and every third pulse, hold
otherwise, the pulse counted in declared portfolio state. Its reach on the
pin (sizing rows, strict `max_weight` reductions, priced fills with fees) is
asserted by `cost_map.R` (LDG-3229, `results/cost_map_cut16_pin/reach.csv`).

The PMwR figures are the warm medians of the published peer benchmark
(blechturm.com, 2026-10-31, ledgr build `891c23c8`, PMwR 1.3-0), on that
benchmark's own data, not on these simulated bars; they are a reference
scale, not a paired comparison.

## Clock endpoints

- `run`: wall time of the `ledgr_run()` call (preparation, the fold,
  run-store writes and finalisation).
- `fold`: wall time inside `ledgr_fold_envelope`, the pinned binding or the
  lean loop bound over it; divided by the pulse count it gives the fold's
  microseconds per pulse, including the terminal store writes.

The work string pins fills, final equity (`%.17g`) and a digest of the
fills table; both arms of a record must return the same string, and the
candidate slot fails unless exactly one fold ran lean.
