# Protocol ws16-p3-1

The quick timing run of the P3 family (macro WS16 family method, point 3):
lean P3 (`dev/lean_core/plan.R`) swapped into the pinned run. Both arms
install the pin `d5b3a151`; the candidate arm also binds lean P3 from
`--candidate-overlay=dev/lean_core`. Eight alternating pairs per cell (the harness floor; the family method asks for about five). The
family method asks for the whole-run ratio and the stage's own microseconds
per pulse; each cell's bound is 1.0 (lean P3 no slower than the pin).

## Workloads

Each slot builds a sealed store in its work directory, outside both clocks,
opens it with `verify = TRUE` and runs one committed run. These are the
three workloads of the per-stage profile
(`dev/bench/v0_2_3_ws16_stage_profile/`):

| shape | run |
| --- | --- |
| `crossover_10x7200` | the published peer-benchmark rule (SMA 5/10 transitions, quantity 0 or 1, cash 1e7, zero cost, no risk) on 10 simulated instruments x 7,200 daily bars (`dev/spikes/r_floor/fixture.R`); about one fill per pulse |
| `crossover_500x1260` | the same rule on 500 x 1,260; about 54 fills per pulse |
| `momentum_40x504` | monthly top-10 momentum on a 63-session returns feature, 40 x 504 on declared sessions (`dev/bench/v0_2_3_ws16_entry/workloads.R`); 23 decided pulses |

## Clock endpoints

- `run`: wall time of the `ledgr_run()` call (preparation, the fold and
  run-store writes).
- `p3`: wall time inside `ledgr_fold_stage_plan`, the pinned binding or
  lean P3 bound over it; the wrapper adds a few microseconds per call to
  both arms.

The work string pins P3 calls, fills, final equity (`%.17g`) and a digest
of the fills table; both arms of a record must return the same string.
