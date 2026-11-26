# Protocol cut24-feature-1

The Cut 24 timing record (decision 3, cut review 24 R1 and R2): the feature
path, base against candidate, each arm its own installed package (`--base`
and `--candidate` are immutable commits, no candidate overlay). One protocol
serves every comparison of the cut: the base A/A record, lazy candidate
construction (LDG-3260, certification cells) and stage-3 retention
(LDG-3265, feature and admission cells). The pin `d5b3a151` is the semantic
oracle only (dev/feature_parity/), never a timing arm. Eight alternating
fresh-process pairs per cell (base first in odd pairs). Production timings
run with `debug=0`; each workload sets the arm's internal debug flag
explicitly (decision 6; the cut base has no flag and runs only `debug=0`).

## Cells

| cell | workload | clock | what | reps |
| --- | --- | --- | --- | ---: |
| `run_10x7200` | `cut24_feature` | feature | Cut 22 cell, run sequence | 21 |
| `sweep_10x7200` | `cut24_feature` | feature | Cut 22 cell, sweep sequence | 12 |
| `run_500x1260` | `cut24_feature` | feature | Cut 22 cell | 10 |
| `sweep_500x1260` | `cut24_feature` | feature | Cut 22 cell | 5 |
| `run_1166x252` | `cut24_feature` | feature | Cut 22 cell | 7 |
| `sweep_1166x252` | `cut24_feature` | feature | Cut 22 cell | 3 |
| `certify_run` | `cut24_certify` | certify | certification of the run set | 100 |
| `certify_sweep` | `cut24_certify` | certify | certification of the sweep set | 37 |
| `adm_custom_run` / `_sweep` | `cut24_admission` | feature | (a) custom only, 500 x 1,260 | 13 / 13 |
| `adm_zero_run` / `_sweep` | `cut24_admission` | feature | (b) certified zero admission | 10 / 5 |
| `adm_low_run` / `_sweep` | `cut24_admission` | feature | (c) certified low admission (5/500) | 10 / 5 |
| `adm_pit_run` / `_sweep` | `cut24_admission` | feature | (d) simulated PIT panel | 17 / 8 |

Fixtures and definitions are in `workloads.R`. Feature cells: the r_floor
shape (`ledgr_sim_bars()`, seed 20260530, closes at 21:00 UTC, rounded to 8
digits), sealed and reopened with `verify = TRUE`, bar-native; run
definitions TTR SMA 5 and 10, sweep TTR SMA 3, 5, 8, 12, 20 and 40.
Admission (b) and (c): the same 500 x 1,260 bars with declared sessions and
`price_carry = 2`; the bar of session 630 is removed from every instrument
(b) or from all but the first five (c), the session staying expected.
Admission (d): `ledgr_sim_pit_inputs()` exactly as
`dev/spikes/feature_stage23_probe/gate_count.R` (200 instruments, 2019-01-01
to 2020-12-31, seed 20261118, `price_carry = 2`, `output_carry = 2`).
Expected admission counts and fixture digests were established before stage
3, independently of the product, by
`dev/bench/v0_2_3_cut24_feature/admission_counts.R` (results/
admission_expected.csv): custom 0, zero 0/500, low 5/500 and PIT 197/200 per
definition. The hostile corpus substrates stay semantic and small-overhead
controls in dev/feature_parity/, not timing cells.

## Clocks

`feature`: from the first call of a preparation to the return of its
projection, `reps` preparations back to back, `Sys.time()`; the package's own
sequence with the engine version inside the clock (run:
`ledgr_feature_engine_version()`, `ledgr_history_compute_feature_series()`,
`ledgr_projection_from_feature_matrix()`; sweep:
`ledgr_history_precompute_payload()`, `ledgr_projection_from_payload()` with
the engine version). `certify`: `reps` back-to-back `lapply(defs,
ledgr_feature_certify)`. Outside the clock: process start, library load,
fixture, sealing, substrate and definition construction, one untimed
warm-up preparation, then `gc()`.

## Calibration and repetitions

Frozen before the base A/A record. `dev/bench/v0_2_3_cut24_feature/
calibrate.R` ran every cell once with two preparations on the cut base
(results/calibration.csv); `reps = ceiling(target / seconds per
preparation)` with target 6 s for the wide feature cells and every admission
cell (a stage-3 saving of up to half leaves about 3 s) and 3 s for the 10 x
7,200 and certification cells.

## Decision statistics

Computed by `dev/bench/v0_2_3_cut24_feature/exchange.R`, not by the shared
checker's PASS. For each cell, all 256 within-pair label exchanges of the
base A/A record of the statistic median(candidate) / median(base); their
central 95% interval [L, U] (quantile type 7) is committed with its raw
observations. A comparison ratio below L resolves a saving; above U is a
regression; otherwise no saving is established. After the A/A record,
`thresholds.csv` holds each cell's U as its no-regression bound (the A/A
record itself ran under the provisional bound 1.02, which only labels its
noise). A record that is valid but fails a bound is valid negative
evidence; an invalid or inconclusive record establishes no saving; no pair
is dropped and no attempt is retried without the harness's recorded
disposition.

Peak R heap is measured outside this harness by
`dev/bench/v0_2_3_cut24_feature/memory.R` (fresh children, gc maxima, the
8 MiB sensitivity check, label-exchange noise), with its own verdict file.

## Host

High performance power plan, launched through the P-core launcher; the
record names its host state. The machine may be busy with other work; such
records are labelled busy, and an inconclusive record establishes no saving.

## Work string

The workload, its arguments, reps, the definition count, debug and a digest
of the logical result (the projection without its engine marker, or the
certification outcomes). Both arms must report the same work string.
