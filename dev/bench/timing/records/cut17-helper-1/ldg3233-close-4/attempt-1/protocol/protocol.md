# Protocol cut17-helper-1

The Cut 17 timing record (decision 6): the sizing helpers
`ledgr_target_rebalance()` and `ledgr_target_adjust()` per call, base
against candidate, and one descriptive whole run. Each arm is its own
installed package (`--base` and `--candidate` are immutable commits; neither
arm installs the lean core). The runner is launched with

    --candidate-overlay=dev/bench/v0_2_3_helper/views.R,dev/bench/v0_2_3_lean_tuning_profile/descriptors.R,dev/spikes/r_floor/fixture.R

so both arms read the view capture, the helper arguments, the slice2
descriptor and the bars from the same exported files. Eight alternating
fresh-process pairs per cell (the harness floor).

## Cells

| cell | call | instruments | clock | bound |
| --- | --- | ---: | --- | ---: |
| `reb_10`, `reb_500`, `reb_1166` | `ledgr_target_rebalance()` | 10 / 500 / 1,166 | `call` | 1.02 |
| `adj_10`, `adj_500`, `adj_1166` | `ledgr_target_adjust()` | 10 / 500 / 1,166 | `call` | 1.02 |
| `run_slice2_10x7200` | `ledgr_run()` on `slice2_10x7200` | 10 | `run` | descriptive |

Helper cells: the slot captures a genuine pulse view from an 8-pulse run of
the arm's package (`helper_capture_views()`, pulse 4, positions bought on
pulse 1 with plain quantity targets, outside the clock), builds the frozen
representative arguments of `helper_view_args()` (rebalance: weights on
every other instrument in reversed order, keep for the first held
instrument, `capital_base = "total_equity"`; adjust: weights, `add_value`
in reversed order and an exit mask on disjoint subsets), makes one warm-up
call (which reads the view's columns), runs `gc()`, then times `reps` calls
with `Sys.time()` (about 1.5 us resolution here; `proc.time()` ticks in 20 ms
steps on this host). This is a cached-context measurement: it does
not include the first read of a fresh pulse's columns and is not a
decomposition of a whole run. `reps` is frozen in `matrix.csv` before any
comparison so the faster arm's batch lasts about three seconds or more. The
first counts were calibrated on the base in LDG-3232 (records
ldg3232-base-base and ldg3232-base-base-2, ldg3233-match-vs-gated and
ldg3233-close ran under them); the close review of workstream 35 (round 1,
finding 7) found the candidate's batches at 1.4-1.8 s, so the counts were
raised to give the candidate about 3.2 s (from ldg3233-close's candidate
medians); the base's batches then last about 6-7 s. The installed package
is byte-compiled; the workload adds no compilation.

The descriptive cell runs `slice2_10x7200` (Cut 16 decision 6) from a sealed
store opened with `verify = TRUE`, through the ordinary package path, and
times the `ledgr_run()` call. Its work string carries the reach counts
(sizing rows, strict `max_weight` reductions, priced fills with fees), which
must all be positive, so sizing, binding risk and priced fills are verified
on both arms before any timing is read. Its bound is 1,000,000: the shared
checker still applies every validity check (protocol, plan, slots, host,
identity, alternation, invariant work) to the cell, and the bound only lets
its ratio verdict through, as decision (6) allows for the descriptive cell.
The ratio is reported, not gated.

The work strings pin the helper's result (a digest of the serialized value
and of the view's inputs) and, for the run, fills, final equity, the fills
digest, the sizing-diagnostics digest and the reach counts; both arms of a
record must return the same string.
