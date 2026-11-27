# Protocol cut26-loop-1

The Cut 26 timing record of LDG-3274 (decision 10, cut review 26 R8): the
WS16 quick paired timing record of the slice-5 lean loop against the pin.
The method is `cut21-loop-1` unchanged but for two points. The candidate's
lean sources also include `loop_workers.R`: the harness sweep-worker
channel that `lean_loop_install()` opens, inert on a committed run. And the
identifiers change. No new optimization or full milestone benchmark is
added.

Both arms install the pin `d5b3a151`; the runner is launched with

    --candidate-overlay=dev/lean_core,dev/bench/v0_2_3_lean_tuning_profile/descriptors.R,dev/spikes/r_floor/fixture.R

The candidate arm sources the lean execution sources `checks.R`, `fifo.R`,
`plan.R`, `loop.R`, `loop_harness.R`, `marks.R`, `facts.R` and
`loop_workers.R` from the committed tree (debug off, every function
`cmpfun`-compiled) and installs the lean loop with `lean_loop_install()`. A
lean source other than these, `load.R` and `prepare.R` refuses the slot.
Eight alternating pairs per cell (the harness floor).

## Bounds (stated before measurement)

- Every cell's bound is 1.0: the lean arm no slower than the pin (the
  inherited WS16 floor rule; `thresholds.csv`). `facts_10x7200` is
  descriptive, as in Cut 21.
- No regression against the accepted slice-4 lean baseline: the paired
  comparison of `dev/lean_core/parity/loop_shortcuts.R --mode=compare`
  between the slice-4 lean loop (base `2bd1a33e`, the cut's base) and the
  final commit, on the comparison shapes 10x7200, 20x23400, 500x1260 and
  slice2_10x7200. It runs under Cut 15's 5 percent rule: a shape whose
  median is more than 5 percent slower is a miss.
- A miss is fixed, or disposed of under WS16's rule (macro plan), before
  the cut closes.

## Workloads

The shapes of `cut21-loop-1` (see its protocol):

| descriptor | instruments | pulses | workload |
| --- | ---: | ---: | --- |
| `10x7200` | 10 | 7,200 | crossover |
| `20x23400` | 20 | 23,400 | crossover |
| `500x1260` | 500 | 1,260 | crossover |
| `1166x252` | 1,166 | 252 | crossover |
| `slice2_10x7200` | 10 | 7,200 | slice 2 |
| `facts_10x7200` | 10 | 7,200 | crossover on a membership universe (descriptive) |

## Clock endpoints

- `run`: wall time of the `ledgr_run()` call.
- `fold`: wall time inside `ledgr_fold_envelope`.

The work string pins fills, final equity and a digest of the fills table;
both arms must return the same string, and the candidate slot fails unless
exactly one fold ran lean.

## Descriptive: a selected sweep and a worker sweep

Reported beside the record, not gated (decision 10):
`dev/lean_core/parity/evidence/ldg3274/timing_descriptive.R` times one
sweep selecting `compiled_accounting_model = "spot_fifo"` and one
two-worker sweep, pin against lean. The worker sweep's harness
worker-loading cost (each worker sourcing the lean core) is timed
separately and reported beside the sweep's time.
