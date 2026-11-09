# Protocol cut12-prep-1

The Cut 12 preparation and history-request clocks (Cut 12 decision (5)).
LDG-3215 runs it pinned against pinned (`d5b3a151` on both arms, an A/A
record) to freeze the pinned clocks, microsecond budgets and noise before any
LDG-3216 code. LDG-3217 then gates lean preparation against the same cells
with `--candidate-overlay=dev/lean_core`; each cell's bound is 1.0.

## Workload

Each slot, in a fresh process, prepares a sealed store in its work
directory, outside both clocks:

| shape | store |
| --- | --- |
| `500x5040` | the WS16 entry momentum snapshot, 500 simulated instruments on 5,040 declared sessions, built in the slot |
| `h1` | the private H1 store of `build-state.json` (WS25 rebuild `cad309f4`, product code identical to the pin), copied into the slot |
| `intraday_5x100k`, `intraday_20x50k` | long and thin: 5 instruments x 100,620 and 20 x 50,310 rectangular 5-minute bars on the bar-native clock, built in the slot (`lc_prep_intraday_snapshot`); the request set reads once a day at the 21:00 close with lookbacks of 2,340, 390 and 78 bars and holds |

It opens the store with `verify = TRUE` and runs the registered request set
(`dev/lean_core/parity/prep_fixture.R`, `lc_prep_strategy`, copied into
`workloads.R` so the folder is self-contained) as monthly top-20 momentum on
one 252-session returns feature, with H1's membership universe on `h1`. On
each decided pulse the strategy issues, in order:

| clock | request |
| --- | --- |
| `r1` | `ledgr_history_matrix(ctx, bar = "close", lookback = 252)` |
| `r2` | `ledgr_history_matrix(ctx, feature = "ret", lookback = 252)`: the 252-session x 500-instrument feature window |
| `r3` | `ledgr_history_frame(ctx, bar = "close", lookback = 63, instruments = "decision_axis", layout = "long")` |
| `r4` | `ledgr_history_frame(ctx, feature = "ret", lookback = 63, layout = "wide")` |
| `r5` | `ledgr_history_matrix(ctx, bar = "close", lookback = 21, min_observations = 15)` |
| `r6` | `ledgr_history_frame(ctx, bar = "close", lookback = 21, instruments = <the store's first instrument>, layout = "long")` |

## Clock endpoints

Wrappers on the pinned namespace time two endpoints in the same run:

- `prep`: wall time inside the outermost calls of
  `ledgr_history_substrate_for_experiment` (provider data, bar hydration,
  substrate), `ledgr_history_compute_feature_series`,
  `ledgr_projection_from_feature_matrix`,
  `ledgr_history_substrate_bind_features`,
  `ledgr_availability_provider_from_substrate`,
  `ledgr_history_substrate_fold_reader` (including the read service) and the
  fold's `ledgr_availability_valuation_state`, plus the history mask planes
  the pin builds lazily on first read (`ledgr_history_prepare_masks`,
  `ledgr_history_prepare_positions`). The mask planes are built twice per run
  and are preparation in any design; per-request barrier lookups stay in the
  request clocks.
- `r1`-`r6`: wall time inside each public request call, summed over the
  run's decided pulses, minus any mask-plane time inside it.

A lean candidate must report the same endpoints: everything that turns the
verified snapshot handle into the prepared reader, valuation input and mask
planes is `prep`; each public request call is its clock.

Work string: shape, decided pulses, fills, final equity and, per request, a
12-character prefix of the SHA-256 over its result digests (format-2
serialization), so both arms return identical values on every request.
Private runs report counts and digests only.

## Cells

Sixteen cells: `prep`, `r1`-`r6` on `500x5040` and on `h1` (Cut 12
decision (5)), and `prep` on the two intraday shapes (`prep_i5`,
`prep_i20`, added at the maintainer's request for long, thin data). Eight
alternating pairs, the harness minimum. A/A bound 1.0 marks a noise observation; in LDG-3217's
gate a cell passes at a median ratio of at most 1.0.

## Frozen pinned values

From the LDG-3215 A/A record `records/cut12-prep-1/ldg3215-aa/attempt-1`
(kept private, not committed: its `h1` work string carried final equity,
which `workloads.R` now reports as a digest prefix; `raw.csv` SHA-256
`2df2c23b5be48d727d817765aaa39259f3f225a9f104a5ee4e77860c131676e6`;
2026-11-07, `d5b3a151` on both arms, High performance plan, affinity
0xFFFF, 256 slots, all ok, `check.R --aa` VALID). Pinned median is over all
16 runs of a cell; microseconds are per run (`prep`) or per request call
(231 decided pulses on `500x5040`, 344 on `h1`). A/A ratio is median
candidate over median base; pair range is the eight per-pair ratios;
CV is the mean within-arm coefficient of variation.

| cell | pinned median s | us | A/A ratio | pair range | CV % |
| --- | ---: | ---: | ---: | --- | ---: |
| `prep_5040` | 2.860 | 2,860,274 per run | 1.015 | 0.99-1.05 | 1.1 |
| `r1_5040` | 0.1878 | 812.8 | 0.997 | 0.97-1.01 | 2.0 |
| `r2_5040` | 2.516 | 10,890.9 | 1.003 | 0.98-1.02 | 1.0 |
| `r3_5040` | 1.280 | 5,541.6 | 0.993 | 0.94-1.02 | 1.9 |
| `r4_5040` | 0.9365 | 4,054.0 | 0.995 | 0.95-1.03 | 1.9 |
| `r5_5040` | 0.1023 | 442.8 | 1.045 | 0.96-1.09 | 6.0 |
| `r6_5040` | 0.1758 | 761.0 | 1.004 | 0.91-1.17 | 7.7 |
| `prep_h1` | 10.71 | 10,705,856 per run | 1.011 | 0.98-1.03 | 1.5 |
| `r1_h1` | 0.4892 | 1,421.9 | 0.998 | 0.96-1.07 | 2.8 |
| `r2_h1` | 4.298 | 12,494.1 | 0.996 | 0.98-1.01 | 1.2 |
| `r3_h1` | 2.017 | 5,864.2 | 0.998 | 0.99-1.01 | 0.7 |
| `r4_h1` | 1.478 | 4,295.1 | 1.004 | 0.97-1.03 | 1.1 |
| `r5_h1` | 0.1722 | 500.5 | 1.033 | 0.92-1.26 | 7.3 |
| `r6_h1` | 0.2630 | 764.5 | 0.973 | 0.92-1.14 | 5.4 |
| `prep_i5` | 3.187 | 3,186,596 per run | 1.001 | 0.97-1.02 | 1.1 |
| `prep_i20` | 2.089 | 2,088,829 per run | 1.007 | 0.98-1.02 | 1.3 |

Noise reading. Cells of a second or more hold the pin to within 1.5% at
the median and 5% per pair. The four short request cells (`r5`, `r6`, both
shapes; 0.1-0.3 s summed per run) move up to 4.5% at the median and 26% per
pair on identical code, so a lean candidate that merely matches the pin can
miss a 1.0 bound there by noise alone. With bound 1.0, `check.R --aa` labels
every cell "beyond bound margin" (the margin is zero); the label carries no
information in this record.
