# Prepared fast-context feature accessors: findings and inventory

**Outcome: green on the charter.** Building the `ctx$feature()` / `ctx$features()` lookups once
per run saves about 7 s in every warm workflow at 500 × 1,260 (SMA 5/10, 68,201 fills):

- `ledgr_run`: 10.3%;
- one-candidate `ledgr_sweep`: 18.6%;
- compiled `spot_fifo` sweep: 24.6%.

Results and accessor errors are identical, and all three workflows clear the RFC's 5% gate. The
change is plain R, not collapse. Findings bind no design.

A supplementary probe found a larger cost that this change does not reach. The explicit-map idiom,
`ctx$features(id, feature_map)`, costs about 165 µs per call because the map is validated twice per
call. See "Paths the seam does not reach".

**Question.** Does preparing the fast-context accessors' per-call lookups once per run cut warm
wall time by more than 5%, with identical results and identical accessor errors? The prepared
lookups are hashed instrument, universe and feature-id lookups, plus the active alias map
normalized once. The arms are the production accessors ("base") and the in-memory seam ("prepared").

**Baseline.** A detached worktree at `b14579f`, on R 4.6.1 (Windows) with collapse 2.1.8. The seamed
factories are `ledgr_projection_feature_accessor_state()` and
`ledgr_projection_feature_bundle_accessor_state()`, both in `R/runtime-projection.R`. The blob ids
are in `evidence/environment.csv`.

## What ran

`probe.R` came first. It captured the real accessor inputs from a small run, and every one of its
21 call-and-pulse combinations matched. `seam.R` replaces the two factories in memory only:

- `%in% universe` and named-vector index subsetting become hashed environment lookups;
- the active alias map is normalized once, and if that would fail, calls take the production path
  and raise the production error;
- an explicit `feature_map` argument keeps the production lookup;
- validation, error classes and messages are unchanged and raised at call time.

The strategy is `ledgr_demo_sma_crossover_strategy()`, which calls `ctx$features(id)` once per
instrument per pulse, 630,000 calls per run. That is the documented quickstart idiom.

## Parity

- `parity.csv`: 48 rows, all identical. Runs were compared on ledger events, fills, equity and
  trades; sweeps and compiled sweeps on columns, retained returns and trades, and attributes.
  Cases:
  - f1: active alias map;
  - f2: explicit feature map;
  - f3: scalar `ctx$feature()`;
  - f4: availability path, uneven history;
  - s1: release shape.
- `conformance.csv`: 33 rows, all identical. On inputs captured from a real run, the value, or the
  error class and message, of 11 calls at 3 pulses. The calls cover members, unknown, numeric and
  NA instruments, a parameterized map, a concrete map, and known and unknown features and defaults.

## Measurements

Warm clocks start from a reused sealed snapshot; each run gets a fresh store copy made outside the
timer. There were 7 alternating repetitions after warm-up. Each pair ran under the load rule (see
hygiene); 3 of the 21 pairs were re-measured.

| Workflow | base s | prepared s | paired saving s (IQR) | saving | GC base → prepared |
|---|---|---|---|---|---|
| `ledgr_run` | 66.74 | 59.47 | 6.87 (6.58–7.53) | 10.3% | 9.7 → 8.7 s |
| `ledgr_sweep` | 44.35 | 36.14 | 8.25 (7.18–10.75) | 18.6% | 6.8 → 5.5 s |
| `ledgr_sweep` `spot_fifo` | 28.75 | 22.26 | 7.08 (6.47–8.42) | 24.6% | 4.5 → 3.7 s |

Relative IQR is at most 0.28 (the compiled sweep's prepared arm). The previous kept recording, made
on a quieter day, gave 7.43, 7.37 and 7.06 s; the absolute saving reproduces.

The absolute saving is about the same in every workflow because it is per strategy call. Each
workflow's other costs set the percentage. From `allocation.csv`: about 10 µs saved per call, times
630,000 calls, is about 6.4 s. The GC drop makes up the rest.

**Per call and by width** (`allocation_probe.R` → `allocation.csv`, 10 pulses per width, captured
inputs; `Rprofmem` covers the R heap only and is not peak memory):

| Instruments | base µs per `ctx$features()` call | prepared µs | base bytes per call | prepared bytes |
|---|---|---|---|---|
| 50 | 15.0 | 7.1 | 448 | 0 |
| 150 | 16.7 | 7.5 | 1,248 | 0 |
| 500 | 17.6 | 7.4 | 4,048 | 0 |

- The base cost grows with the universe: an O(universe) `%in%` scan, plus one allocation per call
  that scales with the universe. At release shape that is about 2.5 GB of short-lived allocation
  per run.
- The prepared cost is flat. Its one-time build is 7–42 KB (50–500 instruments).
- Scalar `ctx$feature()` goes from 3.7 to 2.1 µs.
- The 10-instrument rows ran first, include warm-up, and are not used.

Width in workflow terms follows from calls per run. At 10 instruments (12,600 calls) the saving is
about 0.1 s. At 50 it is about 0.5 s of a 9 s run, roughly 5%, and it rises with width.

**Width clocks** (`width_scaling.csv`, 3 alternating repetitions) did not resolve these savings.
Even load-free pairs at 50 instruments varied by ±15%, and the checker's load gate fails on one
kept 10-instrument pair: every attempt of that pair ran next to 1.2 to 2.8 other busy cores. Use
the per-call table above for width; the clock file stays as recorded.

**Attribution** (`attribution.csv`, one 10 ms `Rprof` per arm):

| Workflow | `ctx$features`, base → prepared | alias-map lookup and normalization | `%in%` | sampled total |
|---|---|---|---|---|
| `ledgr_run` | 12.7 → 6.1 s | 3.0 → 0 s | 3.0 → 1.5 s | 62.3 → 56.5 s |
| `ledgr_sweep` | 12.8 → 6.5 s | 2.9 → 0 s | 2.7 → 0.8 s | 42.5 → 37.9 s |

What remains inside `ctx$features` is the per-alias scalar call and its validation.

## Paths the seam does not reach (`uncovered_paths_probe.R`)

This probe writes `uncovered_calls.csv` (per call, on captured release-shape inputs) and
`uncovered_profiles.csv` (one production profile per workload at 500 × 1,260).

| Call (500 instruments) | base µs | prepared µs | base bytes | prepared bytes |
|---|---|---|---|---|
| `ctx$features(id)`, active alias map | 18.9 | 8.0 | 4,048 | about 0 |
| `ctx$features(id, feature_map)`, explicit concrete map | 165.4 | 140.6 | 4,048 | 0 |
| availability path: build the three per-pulse accessors | 50.4 per pulse | n/a | 2,721 per pulse | n/a |
| availability path: build, then call `ctx$features(id)` for the universe | 16.8 per call | n/a | 4,052 | n/a |

- **Explicit maps.** `ctx$features(id, feature_map)` is the idiom the indicators vignette teaches.
  (At `b14579f` the strategy-authoring vignette taught it too; it now uses `ctx$vec$feature()`.)
  `ledgr_feature_lookup_map()` validates the map with
  `ledgr_validate_feature_map_object()`, then calls `ledgr_feature_id(feature_map)`, which
  validates it again. Each validation re-derives the ids through `ledgr_feature_id(indicators)`
  and a flatten, although the object already holds `feature_ids`. A run of the explicit-map
  strategy at release shape took 216 s of wall time under the profiler; `ctx$features` took 94 of
  139 sampled seconds, and the lookup 83 of them. The prepared seam removes only the universe
  check.
- **Availability path.** Its accessors are rebuilt each pulse through
  `ledgr_attach_feature_helpers()`, but the build costs about 50 µs per pulse, about 63 ms per run.
  Its per-call cost matches the fast path's base. The availability run itself spent only 44 of 175
  sampled seconds inside `ledgr_execute_fold()`; `ctx$features` was 9 s.

**Explicit-map alternatives** (`explicit_map_probe.R`). Both run on top of the prepared seam, and
every function they bind is compiled. It writes `explicit_map_conformance.csv`,
`explicit_map_calls.csv` and `explicit_map_runs.csv`.

| Lookup | per call | explicit-map `ledgr_run`, release shape |
|---|---|---|
| production | 165 µs | 155.7 s |
| prepared accessors, today's lookup | 145 µs | 152.8 s |
| validate once (drop the second validation, read `feature_ids`) | 71 µs | 124.7 s |
| memo (validate once; reuse the last lookup when the map is `identical()`) | 11 µs | 58.8 s |

Fills and equity were identical in every run. In the 15-call conformance sequence, the values, or
the error classes and messages, were identical in all arms. It covered repeats, a rebuilt equal map,
a reordered map, a parameterized map, tampered ids, swapped aliases, an unknown feature, a character
map and a non-map.

An earlier execution of this probe bound the alternatives only while building the accessor. Its
calls therefore ran the production lookup, and its per-call and conformance rows were void. The run
rows were valid, because there the binding covered the whole run. It was rerun with each arm bound
around its calls.

**Availability attribution** (`availability_attribution_probe.R` → `availability_attribution.csv`).
A cold availability run at release shape took 283 s under the profiler; the dense run took 68 s.
Sampled time on the availability run split as follows:
- `ledgr_compute_feature_series_strict()`: 58%. For every bar of every instrument and feature, it
  slices a window, calls `fn` and `series_fn`, and compares them with `all.equal()`
  (`R/features-engine.R:286`).
- the fold: 25%;
- `ledgr_results()`: 12%, mostly `ledgr_fill_recording_pulses_from_evidence()`.

The in-session feature cache hides the feature cost after the first run.

## Measurement hygiene

This is the fourth recording, and the only one kept:

- The first was stopped because another session's `R CMD check` ran concurrently and base runs
  varied by 20%.
- The second showed a mid-series level shift on the compiled sweep, and two width observations
  overlapped another R process.
- The third used a summed-CPU meter that went negative when processes exited, and it had no
  re-measurement rule. It failed the load gate on 3 of 78 observations.

For every timed observation, the runner records:

- `other_cpu_cores`: the CPU all other processes used in the interval, from per-process CPU
  deltas sampled outside the timer, as average busy cores;
- `other_r_processes`: how many other R processes were present at the end.

The load rule was declared in the runner before this recording. A pair is re-measured, in the same
arm order, when either observation saw one or more other busy cores or another R process. Up to 3
extra attempts are allowed; every attempt stays in the CSV, and only the final one is kept. The
checker gates the kept pairs.

Release shape: 6 of 48 observations were re-measured, and the kept load was at most 0.94 cores
(median 0.38). Width: 18 of 54, and one kept pair failed (above).

Compilation (found 2026-09-27 in `combined-writer-accessor`): R 4.6.1's JIT byte-compiles a
closure created in a local environment only for the first instance of its body in a session. A
second seam instance stays interpreted, and so do the accessors it returns, at about 17 µs per call
instead of about 8.

This runner builds exactly one seam instance, so its prepared arm ran compiled. The per-call
figures above (7.1–7.5 µs) are in the compiled range, and the run savings match them. The
combined runner now compiles every seam function explicitly and records it.

## Detector sensitivity

`spike_checker.R --gut shifted` maps every instrument to its neighbour's feature row.
`conformance.csv` and `parity.csv` then fail. The ungutted checker passes every check except the
width load gate, including the package-scope guard.

## Learned, demoted, deleted

- **Learned:**
  - The 2026-09-18 horizon accessor defect, the full JSON-and-SHA identity path per call, is gone.
    What remained was per-call validation, an O(universe) `%in%` and named-index scan, and
    per-call allocation.
  - The peer benchmark strategy reads `ctx$features_wide`, which the dense path already builds
    once before the loop. Neither accessor change moves peer records.
  - The explicit-map idiom pays two full map validations per call.
- **Demoted:**
  - three recordings (see hygiene);
  - the process-count gate;
  - the width clocks, in favour of per-call measurement.
- **Deleted:** a `sub()` backreference process parser that silently matched nothing; it was
  replaced by `read.csv()` on `tasklist` output.

## Limitations

- One Windows machine, shared with other sessions; one `Rprof` sample per arm.
- Not measured: walk-forward.
- The alias map is normalized once per accessor build. That is sound only while the active alias
  map is fixed for a run. It is, but a production change should state it.

## Recommendation

This evidence supports taking the change forward. It needs no contract change: errors, messages
and results are unchanged. The prepared factories could replace the two production factories
directly.

The explicit-map double validation is a separate and larger per-call cost on a taught idiom. It
needs its own decision (see the follow-up probe). Additivity with the block write is measured in
`dev/spikes/combined-writer-accessor/`.

Rerun from the worktree root:
- `Rscript dev/spikes/feature-accessor-lookup/spike_runner.R --phase all`
- `spike_checker.R` (add `--gut shifted` to see it fail)
- the four probes, which are supplementary and not checked
