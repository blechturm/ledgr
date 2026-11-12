# Skeleton-floor spike, 2026-11-12

**Question** (macro plan WS16 compact-state point 6, Cut 15's first
measuring step). What does the lean loop's skeleton cost on its own: its
state containers, stage functions and hand-offs, recording and hooks, with
each stage's work cut to the R floor's? And what do the suspect mechanisms
(`<<-` column writes, list hand-offs, per-pulse hook calls) cost alone?
Prerequisite: the R floor reproduces ledgr exactly (`dev/spikes/r_floor`,
its checker). Kill condition: a skeleton variant counts only if its fills,
equity and cash are bit-identical to the floor's.

**Outcome: green.** All seven variants are identical to the floor on all
three shapes (`evidence/parity.csv`). The skeleton costs 26 to 63 us per
pulse above the floor. With the floor included, it is 12 to 19 percent of
the lean loop's per-pulse time. The other 81 to 88 percent is the stages'
work.

## What ran

- `probe.R` times each mechanism alone at three vector lengths
  (`evidence/mechanisms.csv`).
- `skeleton.R`, `skel_fold()`: the loop of `dev/lean_core/loop.R` at
  1a420b31, kept as it is, with the floor's work in each stage. It keeps
  the envelope-frame state written by `<<-` from `p1_value` to
  `p5_commit` and `e_advance`, the `v1`/`v2`/`v3` hand-off lists, the
  `live` stage writes, the 21 fill columns with doubling capacity, the
  per-pulse headers, the decision residuals, the reconciliation row, the
  hooks, the `tryCatch` and the `hooks$publish` transfer. Switches remove
  one mechanism each. `skel_fold_flat()` keeps the containers and the
  lean recording but runs the body in one frame, with no stage functions.
- `run.R` checks parity against the floor, then runs 7 alternating
  rounds with the variant order rotated each round. Cost above the floor
  is the median of same-round paired differences
  (`evidence/timings*.csv`).
- `check.R` reruns into a scratch directory, diffs parity, checks the
  timing rows, requires the gutted path to fail and guards package scope.

Host: Windows 11, R 4.6.1, P-core affinity, High performance plan; pin
library d5b3a151.

## Result (us per pulse; above-floor values are paired medians)

| | 10 x 7,200 | 20 x 23,400 | 500 x 1,260 |
| --- | ---: | ---: | ---: |
| R floor (with the strategy call) | 12.7 | 14.3 | 52.0 |
| full skeleton | 38.7 | 45.2 | 113.7 |
| above the floor | 26.1 | 31.0 | 62.8 |
| of which `tryCatch` around the strategy | 4.0 | 4.2 | 5.9 |
| of which the per-pulse hook call | 0.9 | 0.7 | 5.4 |
| of which the lean recording (21 columns, headers, residuals) | 10.4 | 13.5 | 27.6 |
| of which stage functions, hand-offs, `<<-` (floor recording) | 11.0 | 12.6 | 29.4 |
| one-frame body, lean recording, `tryCatch` and hook | 13.3 | 16.5 | 41.7 |
| lean loop, for scale (cost map, LDG-3221) | 299 | 367 | 603 |
| PMwR, published, for scale | 19 | 24 | n/a |

On the narrow shapes the four parts add up to the full skeleton within 0.3
us. On 500 instruments they overshoot it by 5 us, and the hook's 5.4 us
there is within noise: alone the call costs 0.4 us. Paired ranges are 1 to
5 us wide on the narrow shapes and up to 15 us wide on 500 instruments
(`timings.csv`).

Mechanisms alone (ns per operation, the same at 1,000, 10,000 and 100,000
elements): `<<-` element or column write 300 to 400; `<<-` matrix-row
write 600; local write 50; empty call 50 to 100; list hand-off 400; hook
call 400; `tryCatch` 3,450. A subset write into a vector held in an
environment, `e$x[[j]] <- v`, copies the vector: 1.4, 18 and 118 us at
those lengths. The lean loop does not use that form.

`tryCatch` costs its 3.4 us itself, whatever the handler: 3,350 ns with a
prebuilt handler and 1,100 with none, because it runs as several nested R
calls. `withCallingHandlers` with the same handler costs 950 ns. One
`tryCatch` around the whole loop costs about 100 ns per iteration. The
lean handler aborts in every case, so either cheaper form would keep its
behaviour. One handler around the loop would also need to know the pulse
was inside the strategy call and which context to report (`live$cur_stage`
already records the stage).

## What was learned

- `<<-` writes do not copy. Each one costs a flat 0.3 to 0.4 us whatever
  the column length, so the loop's cost does not grow with run length
  through its containers.
- The skeleton is a small part of the lean loop: 39 of 299, 45 of 367 and
  114 of 603 us per pulse. Cut 15's gains have to come from the stages'
  work (planner, FIFO, context build, commit, output checks).
- The skeleton alone is still 2.0 times PMwR's whole narrow pulse (39
  against 19 us). A lean loop at PMwR's narrow speed would therefore need
  its skeleton changed as well, not only its stages.
- The cheapest pieces to remove are the per-pulse `tryCatch`, at 4 to 6
  us, and the recording, at about 0.35 us per `<<-` column write (about 28
  writes on a fill pulse).
- Running the body in one frame saves 12.7, 14.5 and 21.2 us at the same
  recording. Named stage functions are required (skeleton synthesis
  Section 2). The one-frame result is the price of that requirement, not a
  proposal to drop it.

## What Cut 15 may use

The skeleton costs (above), the mechanism prices, and the
finding that the stages' work is 81 to 88 percent of the loop. Not
measured: the cost of a skeleton redesigned to avoid these mechanisms
(for example one handler around the whole loop, or recording written by
local accumulation and a single `<<-`). That design is for Cut 15 to
choose.

## Gutted path

`run.R <lib> <out> 3x40 1 same_bar_fill` fills the full skeleton at the
decision bar. Its fills, equity and cash all stop matching the floor while
every intact variant stays identical, and `check.R` requires both.
Nothing in the package was changed. Harness: 582 lines of R.
