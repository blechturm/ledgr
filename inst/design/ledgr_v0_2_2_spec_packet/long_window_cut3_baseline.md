# Long-Window Baseline After Cut 3

**Status:** Accepted-tree measurement input for the v0.2.2 internal
regression-suite chore; not a public performance claim.

**Measured tree:** `d08c8f4` (`v0.2.2`; package development version
`0.2.1.0`).

**Date:** 2026-10-04.

## Purpose And Method

The macro plan requires a new long-window baseline after Cut 3 because the
dense peer benchmark does not exercise most availability-path improvements.
This record reruns the 2026-10-02 synthetic, vendor-neutral drivers in
`dev/bench/long_window/` on the accepted Cut 3 tree.

Runs used R 4.6.1, DuckDB 1.5.6.9000 and collapse 2.1.8 on Windows 11.
Only one measurement process ran at a time. Each shape ran cold and then warm
in one R process. Existing sealed synthetic snapshots were copied before each
run; snapshot construction and sealing are therefore not in the clocks.

Primary generated records are committed in the sibling ledgr-research
repository at `e95a581`, under `long-window-cut3/`. The measuring checkout
also has them at `C:/Users/maxth/ledgr-research/long-window-cut3/`. Their
SHA-256 digests are:

| File | SHA-256 |
| --- | --- |
| `results.csv` | `1daabeb41d92865428e9a0df7f52e8e1d61999f6a235da779d503db73308e21c` |
| `cut3_baseline.csv` | `aa5fa58a09f0c0c17b5b37a5f54ed16df4e4b4467c145bac826b57d5ce09b40f` |
| `comparison.csv` | `fac8bd9a02c04b4e2411948e6f6a2a3c99d4722364cb11785e011000ecccfb49` |
| `cut3_sweepwf.json` | `550c7f9753f7dafae511abc9c944e351537820e4b1e63ea35063a854c3b13c54` |
| `profile_summary.csv` | `627ce56935bb941589feb598b16e6788947445c8df95f777d7a6a8f726423e90` |

`results.csv` deliberately retains two failed startup attempts. The labels
`cut3_pulses_252` and `cut3_pulses_252_valid` have no run measurements and are
excluded from every comparison. Their child processes inherited a user
profile that moved DuckDB 1.5.2 ahead of the requested library. All measured
labels end in `_r461`; those children ran with `R_PROFILE_USER=NUL` and the
declared R 4.6.1 library order. No failed row was overwritten.

## Baseline Result

The cold strict-feature pathology is gone. Cold momentum runs are 2.76x to
11.67x faster than the 2026-10-02 record as the history grows, while warm runs
are unchanged within normal run-to-run spread.

| Pulses | Cold old | Cold new | Saving | Warm old | Warm new | Peak MiB |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 252 | 27.0 s | 9.8 s | 63.7% | 8.7 s | 8.6 s | 512 |
| 757 | 136.4 s | 17.9 s | 86.9% | 16.9 s | 16.2 s | 843 |
| 1,514 | 296.1 s | 30.4 s | 89.7% | 29.0 s | 28.9 s | 1,306 |
| 3,028 | 606.4 s | 56.0 s | 90.8% | 56.8 s | 55.5 s | 2,133 |
| 6,056 | 1,319.9 s | 113.1 s | 91.4% | 111.9 s | 109.9 s | 3,832 |

The flat-strategy controls also improved or stayed within ordinary spread:

| Shape | Cold old | Cold new | Warm old | Warm new |
| --- | ---: | ---: | ---: | ---: |
| 1,514 pulses; 6,000 membership rows | 28.7 s | 27.9 s | 28.3 s | 28.0 s |
| 1,514 pulses; 300,000 membership rows | 34.5 s | 32.2 s | 33.8 s | 31.7 s |
| 1,514 pulses; 500 terminals | 26.7 s | 25.4 s | 26.5 s | 24.7 s |
| 1,514 pulses; 600 instruments | 20.7 s | 20.6 s | 21.6 s | 20.7 s |
| 1,514 pulses; 2,300 instruments | 44.3 s | 43.1 s | 43.4 s | 42.5 s |

At 757 pulses and four candidates, the first sweep fell from 156.25 to
39.35 seconds and the second from 156.07 to 38.22 seconds. Three-fold walk
forward fell from 313.30 to 110.22 seconds. All candidates were `DONE`; save
and reopen remained below 0.2 seconds.

## Phase Movement

At 3,028 pulses the old profile attributed 458.85 of 503.85 sampled seconds
(91.07%) to `ledgr_compute_feature_series_strict()`. The new profile attributes
20.85 of 45.00 seconds (46.33%) to fold execution, 12.05 seconds (26.78%) to
snapshot hashing, 9.35 seconds (20.78%) to `DBI::dbAppendTable()` and 8.05
seconds (17.89%) to finalization. Inclusive profile shares overlap and must not
be added.

The 300,000-membership-row flat profile divides almost equally between
snapshot hashing and fold execution at 11.70 seconds each out of 25.90 sampled
seconds. Numeric token formatting accounts for 7.55 seconds inclusively, and
the diagnostic append block for 2.55 seconds.

Feature persistence remains material. At 1,514 pulses, disabling it changes
the accepted-tree cold run from 30.4 to 23.6 seconds and the warm run from 28.9
to 21.8 seconds; finalization falls from about seven seconds to below half a
second, and peak working set falls from 1,306 to 1,052 MiB. This is an artifact
policy question already assigned to macro-plan WS5, not authority to change it
as an internal optimization.

## Consequence

The accepted optimizations removed the dominant cold cost without transferring
it into another superlinear phase. The next implementation work is the macro
plan's one-ticket internal regression suite: fixed availability shapes that
exercise sessions, churn, terminals, gaps, returns and SMA; paired comparison
to this accepted record with a 10% flag; structural counters in CI; and one
large release-only run. Snapshot verification, feature-persistence policy and
the residual profile leaders remain with their existing macro-plan routes.
