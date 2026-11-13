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

## Cut 15 close (LDG-3225): lean cells before and after

The lean arm alone, rerun on the final workstream 32 code with
`cost_map.R --arms=lean`, under the same method as above. Every shape
reproduces the pin's recorded result signatures. Cut 14's CSVs are
unchanged. Sources:

- Cut 14: `dev/bench/v0_2_3_lean_tuning_profile/results/cost_map`, head 718b49c9, dev/lean_core changes against head 7
- Cut 15: `dev/bench/v0_2_3_lean_tuning_profile/results/cost_map_cut15`, head 4cdc01da, dev/lean_core changes against head 0

Cut 14's seven uncommitted changes are the LDG-3220 head (LDG-3221's
evidence). Medians of 5 clock reps; samples are Rprof loop samples.

| shape | Cut 14 run | Cut 15 run | Cut 14 loop | Cut 15 loop | Cut 14 us/pulse | Cut 15 us/pulse | Cut 14 loop samples | Cut 15 loop samples |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 10 x 7,200 | 3.40 | 3.22 | 2.15 | 1.97 | 299 | 274 | 426 | 389 |
| 20 x 23,400 | 12.48 | 11.68 | 8.58 | 7.77 | 367 | 332 | 558 | 517 |
| 500 x 1,260 | 3.80 | 3.73 | 0.76 | 0.70 | 603 | 556 | 502 | 460 |
| 1,166 x 252 | 2.58 | 2.52 | 0.21 | 0.19 | 833 | 754 | 580 | 535 |

Loop cells, estimated us per pulse, with samples and resolution:

| shape | cell | Cut 14 us | samples | resolution | Cut 15 us | samples | resolution |
| --- | --- | ---: | ---: | --- | ---: | ---: | --- |
| 10 x 7,200 | P3 plan | 53 | 75 | measured | 53 | 76 | measured |
| 10 x 7,200 | strategy: ledgr callees | 38 | 54 | measured | 49 | 69 | measured |
| 10 x 7,200 | P2 context build | 35 | 50 | measured | 28 | 40 | measured |
| 10 x 7,200 | P4 FIFO | 44 | 63 | measured | 25 | 36 | measured |
| 10 x 7,200 | P4 other (fill records, position facts) | 30 | 43 | measured | 34 | 48 | measured |
| 10 x 7,200 | P5 commit | 39 | 56 | measured | 32 | 46 | measured |
| 10 x 7,200 | P2 other (output checks) | 27 | 38 | measured | 18 | 25 | measured |
| 10 x 7,200 | strategy: own work | 11 | 15 | measured | 17 | 24 | measured |
| 10 x 7,200 | strategy: call wrapper | 11 | 16 | measured | 4 | 6 | rough |
| 10 x 7,200 | P1 valuation | 8 | 11 | measured | 10 | 14 | measured |
| 10 x 7,200 | E advance | 1 | 2 | rough | unresolved | 0 | unresolved |
| 10 x 7,200 | loop body, base code (residual) | 2 | 3 | rough | 4 | 5 | rough |
| 20 x 23,400 | P3 plan | 94 | 143 | measured | 88 | 137 | measured |
| 20 x 23,400 | strategy: ledgr callees | 29 | 44 | measured | 40 | 62 | measured |
| 20 x 23,400 | P2 context build | 38 | 58 | measured | 35 | 55 | measured |
| 20 x 23,400 | P4 FIFO | 65 | 99 | measured | 43 | 67 | measured |
| 20 x 23,400 | P4 other (fill records, position facts) | 38 | 58 | measured | 47 | 73 | measured |
| 20 x 23,400 | P5 commit | 42 | 64 | measured | 30 | 46 | measured |
| 20 x 23,400 | P2 other (output checks) | 24 | 37 | measured | 15 | 24 | measured |
| 20 x 23,400 | strategy: own work | 13 | 20 | measured | 13 | 20 | measured |
| 20 x 23,400 | strategy: call wrapper | 11 | 17 | measured | 8 | 12 | measured |
| 20 x 23,400 | P1 valuation | 11 | 16 | measured | 10 | 15 | measured |
| 20 x 23,400 | E advance | unresolved | 0 | unresolved | 1 | 2 | rough |
| 20 x 23,400 | loop body, base code (residual) | 1 | 2 | rough | 3 | 4 | rough |
| 500 x 1,260 | P3 plan | 148 | 123 | measured | 155 | 128 | measured |
| 500 x 1,260 | strategy: ledgr callees | 70 | 58 | measured | 60 | 50 | measured |
| 500 x 1,260 | P2 context build | 41 | 34 | measured | 33 | 27 | measured |
| 500 x 1,260 | P4 FIFO | 118 | 98 | measured | 93 | 77 | measured |
| 500 x 1,260 | P4 other (fill records, position facts) | 89 | 74 | measured | 77 | 64 | measured |
| 500 x 1,260 | P5 commit | 49 | 41 | measured | 36 | 30 | measured |
| 500 x 1,260 | P2 other (output checks) | 37 | 31 | measured | 27 | 22 | measured |
| 500 x 1,260 | strategy: own work | 19 | 16 | measured | 37 | 31 | measured |
| 500 x 1,260 | strategy: call wrapper | 13 | 11 | measured | 11 | 9 | rough |
| 500 x 1,260 | P1 valuation | 11 | 9 | rough | 19 | 16 | measured |
| 500 x 1,260 | E advance | 2 | 2 | rough | 1 | 1 | rough |
| 500 x 1,260 | loop body, base code (residual) | 6 | 5 | rough | 6 | 5 | rough |
| 1,166 x 252 | P3 plan | 162 | 113 | measured | 163 | 116 | measured |
| 1,166 x 252 | strategy: ledgr callees | 83 | 58 | measured | 66 | 47 | measured |
| 1,166 x 252 | P2 context build | 66 | 46 | measured | 47 | 33 | measured |
| 1,166 x 252 | P4 FIFO | 194 | 135 | measured | 182 | 129 | measured |
| 1,166 x 252 | P4 other (fill records, position facts) | 96 | 67 | measured | 99 | 70 | measured |
| 1,166 x 252 | P5 commit | 93 | 65 | measured | 54 | 38 | measured |
| 1,166 x 252 | P2 other (output checks) | 59 | 41 | measured | 47 | 33 | measured |
| 1,166 x 252 | strategy: own work | 42 | 29 | measured | 52 | 37 | measured |
| 1,166 x 252 | strategy: call wrapper | 7 | 5 | rough | 13 | 9 | rough |
| 1,166 x 252 | P1 valuation | 26 | 18 | measured | 30 | 21 | measured |
| 1,166 x 252 | E advance | unresolved | 0 | unresolved | unresolved | 0 | unresolved |
| 1,166 x 252 | loop body, base code (residual) | 4 | 3 | rough | 3 | 2 | rough |

The loop clocks are measured; the cells are sample estimates. Moves of
about 10 us or less are within sampling noise: the strategy's own work is
the same code in both runs and still moves by 0 to 18 us. The FIFO's drop
on the three narrower shapes (19 to 25 us) matches LDG-3223's paired
saving. The pin's arm was not rerun; its cells above are Cut 14's.

## Cut 16 (LDG-3229): the slice-2 loop's cost map

The lean arm alone on workstream 33's final code, five workload descriptors
(`descriptors.R`, shared with `loop_shortcuts.R` and the cut16-loop-1
protocol): Cut 15's four crossover shapes, unchanged, and `slice2_10x7200`, a
different workload on the same 10 x 7,200 bars (cash 1e7; spread_bps(10),
fixed_fee(1), notional_bps_fee(5); max_weight(0.05); ledgr_target_rebalance()
at weight 0.08 per instrument and invest_fraction 0.9 on the first and every
third pulse, hold otherwise, a declared pulse counter). Same method as above:
5 clock reps, profile runs 3, 1, 10, 40 and 3. Every shape reproduces the
pin's signatures: Cut 14's pin rows for the crossover shapes and an
independent pin capture for slice2_10x7200 (`results/cost_map_cut16_pin`, 3
clock reps, `--arms=pin --clock-only=1`), whose reach on the pin was
asserted before any clock. P2 risk holds the pin's risk plan and its
post-risk checks; P2 sizing the pin's sizing-evidence validator and the lean
sizing record. High performance plan and P-core affinity (`pcore.ps1`); a first
run under the Balanced plan without affinity was discarded. Sources:

- Cut 16 base: `dev/bench/v0_2_3_lean_tuning_profile/results/cost_map_cut16_base`, head 844ea1db, dev/lean_core changes against head 0, lean sources of bec26da9

| run | shape | run | loop | us/pulse | loop samples |
| --- | --- | ---: | ---: | ---: | ---: |
| Cut 16 base | 10 x 7,200 | 3.27 | 2.01 | 279 | 389 |
| Cut 16 base | 20 x 23,400 | 11.89 | 7.95 | 340 | 512 |
| Cut 16 base | 500 x 1,260 | 3.75 | 0.70 | 556 | 472 |
| Cut 16 base | 1,166 x 252 | 2.57 | 0.21 | 833 | 528 |
| Cut 16 base | slice2 10 x 7,200 | 5.80 | 4.33 | 601 | 854 |

The pin on slice2_10x7200 (medians of 3 reps, seconds, with the reach counts):

| workload | pin run | pin loop | pin us/pulse | reach on the pin |
| --- | ---: | ---: | ---: | --- |
| slice2 10 x 7,200, pin | 26.41 | 25.79 | 3582 | sizing_rows 24001, risk_reductions 45193, priced_fills_with_fees 45189 |

Loop cells, estimated us per pulse, share of the loop in percent, samples
and resolution:

| run | shape | cell | us | share of loop | samples | resolution |
| --- | --- | --- | ---: | ---: | ---: | --- |
| Cut 16 base | 10 x 7,200 | P3 plan | 62 | 22.1 | 86 | measured |
| Cut 16 base | 10 x 7,200 | strategy: ledgr callees | 40 | 14.4 | 56 | measured |
| Cut 16 base | 10 x 7,200 | P2 context build | 24 | 8.5 | 33 | measured |
| Cut 16 base | 10 x 7,200 | P4 FIFO | 34 | 12.3 | 48 | measured |
| Cut 16 base | 10 x 7,200 | P4 other (fill records, position facts) | 32 | 11.6 | 45 | measured |
| Cut 16 base | 10 x 7,200 | P5 commit | 29 | 10.3 | 40 | measured |
| Cut 16 base | 10 x 7,200 | P2 other (output checks) | 23 | 8.2 | 32 | measured |
| Cut 16 base | 10 x 7,200 | strategy: own work | 12 | 4.4 | 17 | measured |
| Cut 16 base | 10 x 7,200 | strategy: call wrapper | 7 | 2.6 | 10 | measured |
| Cut 16 base | 10 x 7,200 | P1 valuation | 11 | 3.9 | 15 | measured |
| Cut 16 base | 10 x 7,200 | E advance | 1 | 0.3 | 1 | rough |
| Cut 16 base | 10 x 7,200 | loop body, base code (residual) | 4 | 1.3 | 5 | rough |
| Cut 16 base | 20 x 23,400 | P3 plan | 91 | 26.8 | 137 | measured |
| Cut 16 base | 20 x 23,400 | strategy: ledgr callees | 43 | 12.7 | 65 | measured |
| Cut 16 base | 20 x 23,400 | P2 context build | 32 | 9.4 | 48 | measured |
| Cut 16 base | 20 x 23,400 | P4 FIFO | 44 | 13.1 | 67 | measured |
| Cut 16 base | 20 x 23,400 | P4 other (fill records, position facts) | 38 | 11.1 | 57 | measured |
| Cut 16 base | 20 x 23,400 | P5 commit | 39 | 11.5 | 59 | measured |
| Cut 16 base | 20 x 23,400 | P2 other (output checks) | 20 | 5.9 | 30 | measured |
| Cut 16 base | 20 x 23,400 | strategy: own work | 12 | 3.5 | 18 | measured |
| Cut 16 base | 20 x 23,400 | strategy: call wrapper | 7 | 2.0 | 10 | measured |
| Cut 16 base | 20 x 23,400 | P1 valuation | 10 | 2.9 | 15 | measured |
| Cut 16 base | 20 x 23,400 | E advance | 1 | 0.2 | 1 | rough |
| Cut 16 base | 20 x 23,400 | loop body, base code (residual) | 3 | 1.0 | 5 | rough |
| Cut 16 base | 500 x 1,260 | P3 plan | 122 | 22.0 | 104 | measured |
| Cut 16 base | 500 x 1,260 | strategy: ledgr callees | 61 | 11.0 | 52 | measured |
| Cut 16 base | 500 x 1,260 | P2 context build | 44 | 7.8 | 37 | measured |
| Cut 16 base | 500 x 1,260 | P4 FIFO | 91 | 16.3 | 77 | measured |
| Cut 16 base | 500 x 1,260 | P4 other (fill records, position facts) | 93 | 16.7 | 79 | measured |
| Cut 16 base | 500 x 1,260 | P5 commit | 55 | 10.0 | 47 | measured |
| Cut 16 base | 500 x 1,260 | P2 other (output checks) | 32 | 5.7 | 27 | measured |
| Cut 16 base | 500 x 1,260 | strategy: own work | 28 | 5.1 | 24 | measured |
| Cut 16 base | 500 x 1,260 | strategy: call wrapper | 8 | 1.5 | 7 | rough |
| Cut 16 base | 500 x 1,260 | P1 valuation | 19 | 3.4 | 16 | measured |
| Cut 16 base | 500 x 1,260 | E advance | 1 | 0.2 | 1 | rough |
| Cut 16 base | 500 x 1,260 | loop body, base code (residual) | 1 | 0.2 | 1 | rough |
| Cut 16 base | 1,166 x 252 | P3 plan | 177 | 21.2 | 112 | measured |
| Cut 16 base | 1,166 x 252 | strategy: ledgr callees | 71 | 8.5 | 45 | measured |
| Cut 16 base | 1,166 x 252 | P2 context build | 38 | 4.5 | 24 | measured |
| Cut 16 base | 1,166 x 252 | P4 FIFO | 208 | 25.0 | 132 | measured |
| Cut 16 base | 1,166 x 252 | P4 other (fill records, position facts) | 156 | 18.8 | 99 | measured |
| Cut 16 base | 1,166 x 252 | P5 commit | 73 | 8.7 | 46 | measured |
| Cut 16 base | 1,166 x 252 | P2 other (output checks) | 38 | 4.5 | 24 | measured |
| Cut 16 base | 1,166 x 252 | strategy: own work | 51 | 6.1 | 32 | measured |
| Cut 16 base | 1,166 x 252 | strategy: call wrapper | unresolved | unresolved | 0 | unresolved |
| Cut 16 base | 1,166 x 252 | P1 valuation | 17 | 2.1 | 11 | measured |
| Cut 16 base | 1,166 x 252 | E advance | unresolved | unresolved | 0 | unresolved |
| Cut 16 base | 1,166 x 252 | loop body, base code (residual) | 5 | 0.6 | 3 | rough |
| Cut 16 base | slice2 10 x 7,200 | P3 plan | 126 | 21.0 | 179 | measured |
| Cut 16 base | slice2 10 x 7,200 | strategy: ledgr callees | 123 | 20.5 | 175 | measured |
| Cut 16 base | slice2 10 x 7,200 | P2 context build | 32 | 5.4 | 46 | measured |
| Cut 16 base | slice2 10 x 7,200 | P4 FIFO | 120 | 20.0 | 171 | measured |
| Cut 16 base | slice2 10 x 7,200 | P4 other (fill records, position facts) | 56 | 9.4 | 80 | measured |
| Cut 16 base | slice2 10 x 7,200 | P5 commit | 37 | 6.2 | 53 | measured |
| Cut 16 base | slice2 10 x 7,200 | P2 other (output checks) | 35 | 5.7 | 49 | measured |
| Cut 16 base | slice2 10 x 7,200 | strategy: own work | 6 | 1.1 | 9 | rough |
| Cut 16 base | slice2 10 x 7,200 | strategy: call wrapper | 6 | 1.1 | 9 | rough |
| Cut 16 base | slice2 10 x 7,200 | P1 valuation | 9 | 1.5 | 13 | measured |
| Cut 16 base | slice2 10 x 7,200 | E advance | unresolved | unresolved | 0 | unresolved |
| Cut 16 base | slice2 10 x 7,200 | loop body, base code (residual) | 4 | 0.7 | 6 | rough |
| Cut 16 base | slice2 10 x 7,200 | P2 risk | 28 | 4.7 | 40 | measured |
| Cut 16 base | slice2 10 x 7,200 | P2 sizing | 17 | 2.8 | 24 | measured |

## Cut 16 final (LDG-3231): the cost map on the closing code

The lean arm rerun on the closing code of workstream 34 with the method,
descriptors and profile runs of the LDG-3229 baseline above. LDG-3230 kept
no change, so the lean execution sources equal the baseline's; this rerun
is checked against the checked-out tree (a lean edit after it stales it)
and reproduces the pin's signatures on all five descriptors. High
performance plan and P-core affinity (`pcore.ps1`). Source:

- Cut 16 final: `dev/bench/v0_2_3_lean_tuning_profile/results/cost_map_cut16`, head 09bebb73, dev/lean_core changes against head 0, lean sources of 3998dd58

| run | shape | run | loop | us/pulse | loop samples |
| --- | --- | ---: | ---: | ---: | ---: |
| Cut 16 final | 10 x 7,200 | 3.29 | 2.02 | 281 | 407 |
| Cut 16 final | 20 x 23,400 | 11.83 | 7.99 | 341 | 534 |
| Cut 16 final | 500 x 1,260 | 3.75 | 0.72 | 571 | 467 |
| Cut 16 final | 1,166 x 252 | 2.57 | 0.20 | 794 | 532 |
| Cut 16 final | slice2 10 x 7,200 | 5.91 | 4.38 | 608 | 856 |

Required cells, estimated us per pulse, share of the loop in percent,
samples and resolution:

| run | shape | cell | us | share of loop | samples | resolution |
| --- | --- | --- | ---: | ---: | ---: | --- |
| Cut 16 final | 10 x 7,200 | P3 plan | 50 | 17.9 | 73 | measured |
| Cut 16 final | 10 x 7,200 | strategy: ledgr callees | 37 | 13.0 | 53 | measured |
| Cut 16 final | 10 x 7,200 | P2 context build | 36 | 12.8 | 52 | measured |
| Cut 16 final | 10 x 7,200 | P4 FIFO | 32 | 11.3 | 46 | measured |
| Cut 16 final | 10 x 7,200 | P4 other (fill records, position facts) | 36 | 12.8 | 52 | measured |
| Cut 16 final | 10 x 7,200 | P5 commit | 34 | 12.0 | 49 | measured |
| Cut 16 final | 10 x 7,200 | P2 other (output checks) | 21 | 7.6 | 31 | measured |
| Cut 16 final | 10 x 7,200 | strategy: own work | 15 | 5.4 | 22 | measured |
| Cut 16 final | 10 x 7,200 | strategy: call wrapper | 10 | 3.7 | 15 | measured |
| Cut 16 final | 10 x 7,200 | P1 valuation | 9 | 3.2 | 13 | measured |
| Cut 16 final | 10 x 7,200 | E advance | unresolved | unresolved | 0 | unresolved |
| Cut 16 final | 10 x 7,200 | loop body, base code (residual) | 1 | 0.2 | 1 | rough |
| Cut 16 final | 20 x 23,400 | P3 plan | 98 | 28.8 | 154 | measured |
| Cut 16 final | 20 x 23,400 | strategy: ledgr callees | 43 | 12.7 | 68 | measured |
| Cut 16 final | 20 x 23,400 | P2 context build | 33 | 9.7 | 52 | measured |
| Cut 16 final | 20 x 23,400 | P4 FIFO | 47 | 13.9 | 74 | measured |
| Cut 16 final | 20 x 23,400 | P4 other (fill records, position facts) | 43 | 12.5 | 67 | measured |
| Cut 16 final | 20 x 23,400 | P5 commit | 35 | 10.3 | 55 | measured |
| Cut 16 final | 20 x 23,400 | P2 other (output checks) | 17 | 4.9 | 26 | measured |
| Cut 16 final | 20 x 23,400 | strategy: own work | 10 | 2.8 | 15 | measured |
| Cut 16 final | 20 x 23,400 | strategy: call wrapper | 6 | 1.7 | 9 | rough |
| Cut 16 final | 20 x 23,400 | P1 valuation | 8 | 2.2 | 12 | measured |
| Cut 16 final | 20 x 23,400 | E advance | unresolved | unresolved | 0 | unresolved |
| Cut 16 final | 20 x 23,400 | loop body, base code (residual) | 1 | 0.4 | 2 | rough |
| Cut 16 final | 500 x 1,260 | P3 plan | 130 | 22.7 | 106 | measured |
| Cut 16 final | 500 x 1,260 | strategy: ledgr callees | 53 | 9.2 | 43 | measured |
| Cut 16 final | 500 x 1,260 | P2 context build | 44 | 7.7 | 36 | measured |
| Cut 16 final | 500 x 1,260 | P4 FIFO | 95 | 16.7 | 78 | measured |
| Cut 16 final | 500 x 1,260 | P4 other (fill records, position facts) | 88 | 15.4 | 72 | measured |
| Cut 16 final | 500 x 1,260 | P5 commit | 67 | 11.8 | 55 | measured |
| Cut 16 final | 500 x 1,260 | P2 other (output checks) | 33 | 5.8 | 27 | measured |
| Cut 16 final | 500 x 1,260 | strategy: own work | 33 | 5.8 | 27 | measured |
| Cut 16 final | 500 x 1,260 | strategy: call wrapper | 10 | 1.7 | 8 | rough |
| Cut 16 final | 500 x 1,260 | P1 valuation | 12 | 2.1 | 10 | measured |
| Cut 16 final | 500 x 1,260 | E advance | 2 | 0.4 | 2 | rough |
| Cut 16 final | 500 x 1,260 | loop body, base code (residual) | 2 | 0.4 | 2 | rough |
| Cut 16 final | 1,166 x 252 | P3 plan | 161 | 20.3 | 108 | measured |
| Cut 16 final | 1,166 x 252 | strategy: ledgr callees | 75 | 9.4 | 50 | measured |
| Cut 16 final | 1,166 x 252 | P2 context build | 42 | 5.3 | 28 | measured |
| Cut 16 final | 1,166 x 252 | P4 FIFO | 172 | 21.6 | 115 | measured |
| Cut 16 final | 1,166 x 252 | P4 other (fill records, position facts) | 113 | 14.3 | 76 | measured |
| Cut 16 final | 1,166 x 252 | P5 commit | 91 | 11.5 | 61 | measured |
| Cut 16 final | 1,166 x 252 | P2 other (output checks) | 55 | 7.0 | 37 | measured |
| Cut 16 final | 1,166 x 252 | strategy: own work | 37 | 4.7 | 25 | measured |
| Cut 16 final | 1,166 x 252 | strategy: call wrapper | 9 | 1.1 | 6 | rough |
| Cut 16 final | 1,166 x 252 | P1 valuation | 33 | 4.1 | 22 | measured |
| Cut 16 final | 1,166 x 252 | E advance | unresolved | unresolved | 0 | unresolved |
| Cut 16 final | 1,166 x 252 | loop body, base code (residual) | 6 | 0.8 | 4 | rough |
| Cut 16 final | slice2 10 x 7,200 | P3 plan | 149 | 24.5 | 210 | measured |
| Cut 16 final | slice2 10 x 7,200 | strategy: ledgr callees | 113 | 18.6 | 159 | measured |
| Cut 16 final | slice2 10 x 7,200 | P2 context build | 29 | 4.8 | 41 | measured |
| Cut 16 final | slice2 10 x 7,200 | P4 FIFO | 114 | 18.8 | 161 | measured |
| Cut 16 final | slice2 10 x 7,200 | P4 other (fill records, position facts) | 57 | 9.3 | 80 | measured |
| Cut 16 final | slice2 10 x 7,200 | P5 commit | 33 | 5.5 | 47 | measured |
| Cut 16 final | slice2 10 x 7,200 | P2 other (output checks) | 37 | 6.1 | 52 | measured |
| Cut 16 final | slice2 10 x 7,200 | strategy: own work | 5 | 0.8 | 7 | rough |
| Cut 16 final | slice2 10 x 7,200 | strategy: call wrapper | 11 | 1.8 | 15 | measured |
| Cut 16 final | slice2 10 x 7,200 | P1 valuation | 9 | 1.4 | 12 | measured |
| Cut 16 final | slice2 10 x 7,200 | E advance | 1 | 0.1 | 1 | rough |
| Cut 16 final | slice2 10 x 7,200 | loop body, base code (residual) | 6 | 0.9 | 8 | rough |
| Cut 16 final | slice2 10 x 7,200 | P2 risk | 33 | 5.4 | 46 | measured |
| Cut 16 final | slice2 10 x 7,200 | P2 sizing | 12 | 2.0 | 17 | measured |
