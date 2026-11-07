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

Filled from the LDG-3215 A/A record before LDG-3216 code: per cell, the
pinned median clock, its microseconds per call (requests) or per run
(`prep`) and the A/A noise.
