# The lean loop after Cut 15 (LDG-3225)

Measurement only; this page proposes no design. Every number in the two
tables is rebuilt by `summary_check.R`.

Sources:
- Cut 14 and Cut 15 loops: `results/cost_map/` and `results/cost_map_cut15/`
  (see summary.md, "Cut 15 close"). These are the lean loop clocks,
  medians of 5 reps, divided by pulses.
- The skeleton floor: `dev/spikes/skeleton_floor/evidence/timings.csv`,
  variant `skeleton`. This is the lean loop's own structure at 1a420b31:
  its state containers, stage functions, hand-offs, recording, hooks and
  `tryCatch`. Each stage does only the R floor's work, and the fills are
  bit-identical to the floor's.
- R-floor stage 2: `dev/spikes/r_floor/README.md`, the trace-difference
  row. It is a historical cumulative lower bound: oracle 0d6c0b11, its own
  fixture run, `system.time`, no durable store.

## The loop, us per pulse

| shape | Cut 14 final | Cut 15 final | skeleton floor | R-floor stage 2 | Cut 15 / skeleton | Cut 15 / R-floor |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 10 x 7,200 | 299 | 274 | 39 | 26 | 7.0 | 10.5 |
| 20 x 23,400 | 367 | 332 | 45 | 29 | 7.4 | 11.4 |
| 500 x 1,260 | 603 | 556 | 114 | 103 | 4.9 | 5.4 |

Workstream 32 took 8 to 10 percent off the loop. The paired comparison
against Cut 14's final code (`loop_shortcuts.R --mode=compare`, 7
rounds) gives medians of 9.2, 9.4 and 8.0 percent. The loop is still 4.9
to 7.4 times the skeleton floor. The skeleton keeps the loop's structure,
so the gap is the stages' own work beyond the floor's: the checks and
records ledgr's stages do and the floor does not. The cost map's cells
(summary.md) show where that work sits. P3 plan is one of the two
largest loop cells on every shape. P4 FIFO is the other on the two wide
shapes, and the ledgr callees under the strategy and P4's other work
are the other on the narrow ones.

## Whole run, seconds (PMwR historical)

| shape | Cut 15 lean run | PMwR |
| --- | ---: | ---: |
| 10 x 7,200 | 3.22 | 0.14 |
| 20 x 23,400 | 11.68 | 0.57 |
| 1,166 x 252 | 2.52 | 0.27 |

PMwR is the historical reference published 2026-10-31. It has its own
run boundary and does not write a durable store, so this is not a
controlled ratio. The lean run here is the committed run with its
terminal store write. The snapshot open is excluded.
