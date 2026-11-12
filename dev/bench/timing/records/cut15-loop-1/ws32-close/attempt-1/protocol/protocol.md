# Protocol cut15-loop-1

The Cut 15 timing record of LDG-3225: the tuned compact-state lean loop
(workstream 32: LDG-3222 to LDG-3224) against the pin on the published
peer-benchmark shapes, the same method as `cut13-loop-1` with 500 x 1,260
added. Both arms install the pin `d5b3a151`; the runner is launched with
`--candidate-overlay=dev/lean_core`, so the candidate arm also sources
`fifo.R`, `plan.R`, `loop.R` and `loop_harness.R` from the committed tree
(debug off, every function `cmpfun`-compiled, as the installed pin is
byte-compiled) and installs the lean loop with `lean_loop_install()`. Lean
preparation (`prepare.R`) is not installed: preparation stays the pin's
(Section 19.1). Eight alternating pairs per cell (the harness floor). The
record reports; each cell's bound is 1.0 (the lean arm no slower than the
pin).

## Workloads

Each slot builds a sealed store in its work directory, outside both clocks,
opens it with `verify = TRUE` and runs one committed run of the published
rule (SMA 5/10 transitions, quantity 0 or 1, cash 1e7, zero cost, no risk;
`dev/spikes/r_floor/fixture.R`) on simulated bars:

| shape | pulses | published PMwR (s) |
| --- | ---: | ---: |
| `crossover_10x7200` | 7,200 | 0.14 |
| `crossover_20x23400` | 23,400 | 0.57 |
| `crossover_500x1260` | 1,260 | none |
| `crossover_1166x252` | 252 | 0.27 |

The PMwR figures are the warm medians of the published peer benchmark
(blechturm.com, 2026-10-31, ledgr build `891c23c8`, PMwR 1.3-0), on that
benchmark's own data, not on these simulated bars; they are a reference
scale, not a paired comparison. The benchmark has no 500 x 1,260 cell.

## Clock endpoints

- `run`: wall time of the `ledgr_run()` call (preparation, the fold,
  run-store writes and finalisation).
- `fold`: wall time inside `ledgr_fold_envelope`, the pinned binding or the
  lean loop bound over it; divided by the pulse count it gives the fold's
  microseconds per pulse, including the terminal store writes.

The work string pins fills, final equity (`%.17g`) and a digest of the
fills table; both arms of a record must return the same string, and the
candidate slot fails unless exactly one fold ran lean.
