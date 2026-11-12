# Whole-run cost map, lean loop and pin (LDG-3221, Cut 14)

Measurement only: no design and no threshold. Runners `cost_map.R`,
`cost_rank.R` and `features_h1.R` in this directory; outputs in
`results/cost_map/` and `results/features_h1.csv`. Restructured loop at the
LDG-3220 head, pin d5b3a151, byte-compiled, debug off, inert hooks, High
performance plan, P-core affinity, 5 clock reps and 2 profile reps per arm
and shape, arms alternated, a fresh snapshot copy per run. Fills and equity
are identical between the arms on every shape. Rprof cells are estimates
(a sample share times a measured clock); clocks are measured.

## Measured clocks (seconds, medians)

| shape | lean run | lean loop | lean us/pulse | pin run | pin loop | snapshot open |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 10 x 7,200 | 3.42 | 2.12 | 294 | 20.12 | 19.31 | 0.13 |
| 20 x 23,400 | 12.38 | 8.62 | 368 | 73.89 | 71.86 | 0.50 |
| 500 x 1,260 | 3.84 | 0.77 | 611 | 7.82 | 6.58 | 0.55 |
| 1,166 x 252 | 2.57 | 0.20 | 794 | 3.50 | 2.10 | 0.30 |

The pin's loop clock (its t_loop) also holds its per-pulse store writes;
the lean loop clock holds the pulses only. The snapshot open (verification
included) is outside the committed-run clock and is reusable across runs.
Loop attribution reconciles to the loop clock within 0.89-1.09 (sample
estimate over clock); the lean loop residual is 0-2.1 percent, the pin's
0-17 percent (its 1,166 x 252 loop body, not split further). Lean cells on
1,166 x 252 rest on 26 loop samples and are rough.

## Where the lean run goes, ranked by owner (estimated seconds per run)

| owner | 10 x 7,200 | 20 x 23,400 | 500 x 1,260 | 1,166 x 252 |
| --- | ---: | ---: | ---: | ---: |
| Cut 15, loop tuning (P1-P5, E, ledgr's strategy work, expansion) | 2.24 | 8.77 | 0.92 | 0.28 |
| store-write RFC (terminal write, envelope setup and commit) | 0.50 | 1.91 | 1.77 | 0.92 |
| feature-engine RFC (features, projection) | 0.24 | 0.95 | 0.75 | 1.03 |
| none (bars substrate, registration, guard, finalise) | 0.30 | 0.45 | 0.37 | 0.32 |
| none, the strategy's own code | 0.14 | 0.30 | 0.03 | 0.02 |

Narrow long runs are loop-bound (65-71 percent of the run in Cut 15's
cells); wide runs are bound by the store write and features (66-76
percent). Per-cell ranking: `results/cost_map/rank.csv`.

## Loop cells, lean, estimated us per pulse

| cell | 10 x 7,200 | 20 x 23,400 | 500 x 1,260 | 1,166 x 252 |
| --- | ---: | ---: | ---: | ---: |
| P3 plan | 52 | 70 | 143 | 153 |
| strategy: ledgr callees | 44 | 42 | 87 | 92 |
| P2 context build | 38 | 46 | 31 | 122 |
| P4 FIFO | 36 | 69 | 87 | 61 |
| P4 other (fill records, position facts) | 36 | 47 | 69 | 214 |
| P5 commit | 29 | 35 | 94 | 61 |
| P2 other (output checks) | 19 | 26 | 50 | 31 |
| strategy: own work | 18 | 12 | 25 | 61 |
| strategy: call wrapper | 7 | 6 | 12 | 0 |
| P1, E, residual | 15 | 15 | 12 | 0 |

R-floor stage 2's trace-difference layer (historical cumulative lower
bound: 0d6c0b11 oracle, its own fixture run, system.time, no durable
store) is 26, 29 and 103 us per pulse on the first three shapes; it is not
a matched stage comparison. PMwR (historical reference, published
2026-10-31: 0.14, 0.57 and 0.27 s on 10 x 7,200, 20 x 23,400 and
1,166 x 252, its own run boundary) is not a controlled ratio either.

## The strategy call (matched replay, us per call, median)

| shape | real lean context | plain list | context premium per instrument |
| --- | ---: | ---: | ---: |
| 10 x 7,200 | 54 | 13 | 4.10 |
| 20 x 23,400 | 58 | 14 | 2.22 |
| 500 x 1,260 | 84 | 27 | 0.11 |
| 1,166 x 252 | 117 | 45 | 0.06 |

Same strategy, same values, identical returns on every pulse. The call's
growth with the universe is the strategy's own vector work (13 to 45 us)
plus a ledgr premium of about 41-72 us per pulse that grows slowly; the
profile puts most of the premium in ledgr callees (context and state reads,
hold(), result construction), not in the wrapper (0-12 us). The pin's
premium is about twice the lean one (82 against 41 us on 10 x 7,200).

## Features on private H1 (aggregates only)

1,166 instruments, 7,213 sessions; 582 (50 percent) have the simple shape
(one feature range, one input run, no terminal, no carried input); 527 are
excluded for a terminal and 57 for a carried input. On the simple rows bare
TTR reproduces the pin's SMA5/SMA10 values and NA placement exactly. The
pin's per-instrument path on those rows takes 4.54 s against 0.17 s for
bare TTR (7.8 ms against 0.29 ms per instrument); full-H1 pin feature time
is 9.33 s. Bare TTR omits input treatment, the expected-session mask,
segment, carry and reason evidence, the causality probe and certification;
this is not a claim of feature-surface equivalence. Input: the H1 store of
LDG-3215-prep (the W1 build of 953338df refuses under the pin with
`ledgr_store_rebuild_required`).
