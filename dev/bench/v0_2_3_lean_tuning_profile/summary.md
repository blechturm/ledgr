# Whole-run cost map, lean loop and pin (LDG-3221, Cut 14)

Measurement only: no design and no threshold. Runners `cost_map.R`,
`cost_rank.R` and `features_h1.R` in this directory; outputs in
`results/cost_map/` and `results/features_h1.csv`; `summary_check.R`
rebuilds every table row below from them. Restructured loop at the
LDG-3220 head (state-view method deleted), pin d5b3a151, byte-compiled,
debug off, inert hooks, High performance plan, P-core affinity; 5 clock
reps per arm and shape, arms alternated, a fresh snapshot copy per run;
profile runs per shape 3, 1, 10 and 40 so each loop gets enough samples.
Fills and equity are identical between the arms on every shape. Rprof
cells are estimates (a sample share times a measured clock); clocks are
measured. A required cell without samples is unresolved, not zero.

## Measured clocks (seconds, medians)

| shape | lean run | lean loop | lean us/pulse | pin run | pin loop | snapshot open |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 10 x 7,200 | 3.40 | 2.15 | 299 | 20.25 | 19.45 | 0.13 |
| 20 x 23,400 | 12.48 | 8.58 | 367 | 73.71 | 71.65 | 0.56 |
| 500 x 1,260 | 3.80 | 0.76 | 603 | 7.81 | 6.57 | 0.60 |
| 1,166 x 252 | 2.58 | 0.21 | 833 | 3.51 | 2.11 | 0.29 |

The pin's loop clock (its t_loop) also holds its per-pulse store writes;
the lean loop clock holds the pulses only. The snapshot open (verification
included) is outside the committed-run clock and reusable across runs.
Loop attribution reconciles to the loop clock within 0.89-1.08 (sample
estimate over clock); the loop body's own time goes to its direct named
callees (the pin's diagnostic drain and flushes, for example) and only
base code stays residual: 0.4-1.0 percent of the lean loop, 0.4-0.9
percent of the pin's (results/cost_map/reconcile.csv).

## Where the lean run goes, ranked by owner (estimated seconds per run)

| owner | 10 x 7,200 | 20 x 23,400 | 500 x 1,260 | 1,166 x 252 |
| --- | ---: | ---: | ---: | ---: |
| Cut 15, loop tuning (P1-P5, E, ledgr's strategy work, expansion) | 2.29 | 8.96 | 0.90 | 0.28 |
| store-write RFC (terminal write, envelope setup and commit) | 0.51 | 1.78 | 1.74 | 0.95 |
| feature-engine RFC (features, projection) | 0.26 | 0.96 | 0.78 | 1.04 |
| none (bars substrate, registration, guard, finalise) | 0.26 | 0.46 | 0.35 | 0.30 |
| none, the strategy's own code | 0.08 | 0.32 | 0.03 | 0.01 |

Narrow long runs are loop-bound (Cut 15's cells 67-72 percent of the
run); wide runs are bound by the terminal write and features (66-77
percent). Per-cell ranking: `results/cost_map/rank.csv`.

## Loop cells, lean, estimated us per pulse

| cell | 10 x 7,200 | 20 x 23,400 | 500 x 1,260 | 1,166 x 252 |
| --- | ---: | ---: | ---: | ---: |
| P3 plan | 53 | 94 | 148 | 162 |
| strategy: ledgr callees | 38 | 29 | 70 | 83 |
| P2 context build | 35 | 38 | 41 | 66 |
| P4 FIFO | 44 | 65 | 118 | 194 |
| P4 other (fill records, position facts) | 30 | 38 | 89 | 96 |
| P5 commit | 39 | 42 | 49 | 93 |
| P2 other (output checks) | 27 | 24 | 37 | 59 |
| strategy: own work | 11 | 13 | 19 | 42 |
| strategy: call wrapper | 11 | 11 | 13 | 7 |
| P1 valuation | 8 | 11 | 11 | 26 |
| E advance | 1 | unresolved | 2 | unresolved |
| loop body, base code (residual) | 2 | 1 | 6 | 4 |

E advance (about 1-2 us per pulse) drew no sample on two shapes. Many
cells hold time in the pin's helpers the lean loop reuses (P5's
reconciliation check and state functions, P4's position facts, the
strategy result and context helpers among the ledgr callees). R-floor
stage 2's trace-difference layer (historical cumulative lower bound:
0d6c0b11 oracle, its own fixture run, system.time, no durable store) is
26, 29 and 103 us per pulse on the first three shapes; it is not a matched
stage comparison. PMwR (historical reference, published 2026-10-31: 0.14,
0.57 and 0.27 s on 10 x 7,200, 20 x 23,400 and 1,166 x 252, its own run
boundary) is not a controlled ratio either.

## The strategy call (matched replay, us per call, median)

| shape | real lean context | plain list | context premium per instrument |
| --- | ---: | ---: | ---: |
| 10 x 7,200 | 55 | 13 | 4.20 |
| 20 x 23,400 | 59 | 14 | 2.25 |
| 500 x 1,260 | 85 | 27 | 0.12 |
| 1,166 x 252 | 115 | 46 | 0.06 |

Same strategy, same values, identical returns on every pulse. The call's
growth with the universe is the strategy's own vector work (13 to 46 us)
plus a ledgr premium of about 42-69 us per pulse that grows slowly; the
profile puts most of the premium in ledgr callees (context and state reads,
hold(), result construction), not the wrapper (7-13 us). The pin's premium
is about twice the lean one (83 against 42 us on 10 x 7,200).

## Features on private H1 (aggregates only)

1166 instruments, 7,213 sessions; 582 (50 percent) have the simple shape
(one feature range, one input run, no terminal, no carried input), none
with a run shorter than 10 sessions; 527 are excluded for a terminal and
57 for a carried input. On the simple rows bare TTR reproduces the pin's
SMA5/SMA10 values and NA placement exactly. The pin's per-instrument path
on those rows takes 4.55 s against 0.17 s for bare TTR (7.8 ms against 0.29
ms per instrument); full-H1 pin feature time is 9.27 s. Bare TTR omits
input treatment, the expected-session mask, segment, carry and reason
evidence, the causality probe and certification; this is not a claim of
feature-surface equivalence. Input: the H1 store of LDG-3215-prep (the W1
build of 953338df refuses under the pin with `ledgr_store_rebuild_required`).
