# Sweep Performance Measurement

**Date:** 2026-05-14  
**Ticket:** LDG-2108A  
**Branch:** v0.1.8  
**Script:** `dev/spikes/ledgr_sweep_performance/run_benchmark.R`

## Purpose

Measure the runtime effect of the LDG-2108 memory-backed sequential
`ledgr_sweep()` implementation before result/provenance polish continues.

This is not a semantic parity test. It is a local performance measurement of the
new memory-backed sweep path against the practical baseline users would have had
without sweep mode: a loop that calls `ledgr_run()` once per candidate against
the same sealed snapshot.

## Environment

- OS: Windows 10 x64
- R: R version 4.5.2 (2025-10-31 ucrt)
- Logical CPU cores: 24
- Benchmark timing: base `proc.time()[["elapsed"]]`
- Warnings: suppressed inside timed sections so console warning overhead is not
  counted as engine runtime.
- Artifacts: benchmark DuckDB files are created under `tempfile()` directories
  and deleted at script exit.

## Workload

The benchmark uses public ledgr APIs only.

- Synthetic EOD bars from `ledgr_sim_bars()`
- 4 instruments
- 252 business-day bars per instrument
- 1,008 total bars
- Feature-consuming strategy using `ctx$feature()`
- Parameter-aware feature factory:
  - each candidate selects `ledgr_ind_returns(params$lookback)`
  - lookback varies across `5`, `10`, `20`, `40`, and `80`
  - this exercises indicator-parameter sweep behavior, not only strategy
    threshold changes
- Opening cash: `100000`
- Seed: `2108`

Measured paths:

1. `ledgr_sweep(exp, grid)` with ordinary candidate feature materialization.
2. `ledgr_precompute_features(exp, grid)` followed by
   `ledgr_sweep(exp, grid, precomputed_features = precomputed)`.
3. Persistent baseline loop:
   `for each candidate: ledgr_run(exp, params, run_id, seed); close(bt)`.

## Results

| Scenario | Candidates | Plain sweep | Precompute | Sweep with precomputed | Precomputed total | `ledgr_run()` loop |
|---|---:|---:|---:|---:|---:|---:|
| `small_5_candidates` | 5 | 2.97s | 0.06s | 2.82s | 2.88s | 5.13s |
| `local_50_candidates` | 50 | 26.67s | 0.26s | 27.96s | 28.22s | 45.25s |

| Scenario | Plain sweep speedup | Precomputed sweep speedup | Precomputed total speedup |
|---|---:|---:|---:|
| `small_5_candidates` | 1.73x | 1.82x | 1.78x |
| `local_50_candidates` | 1.70x | 1.62x | 1.60x |

Throughput:

| Scenario | Plain sweep candidates/sec | Precomputed sweep candidates/sec | Run-loop candidates/sec |
|---|---:|---:|---:|
| `small_5_candidates` | 1.68 | 1.77 | 0.97 |
| `local_50_candidates` | 1.87 | 1.79 | 1.10 |

## Interpretation

The memory-backed sweep path is meaningfully faster than looping over
`ledgr_run()`, but it is not an order-of-magnitude change on this workload.

The measured gain is about **1.7x** for a feature-consuming EOD strategy over 4
instruments and 252 bars. That is the expected direction: sweep avoids durable
run registration, persistent ledger/equity/features writes, telemetry writes,
and repeated committed-run object construction. It still runs the same fold
semantics candidate by candidate, so the execution engine itself remains the
dominant cost.

Precomputed features did not improve the 50-candidate case in this benchmark.
That is not evidence against precompute as an architecture feature. The tested
features are cheap vectorized native return indicators and only five unique
lookback definitions are reused across 50 candidates. For this local EOD shape,
the overhead of validating and reading the precomputed payload is comparable to
or slightly higher than recomputing these cheap features inside the candidate
path. Precompute remains important for heavier indicators, larger universes,
larger feature sets, and future parallel transport.

## Design Consequences

- LDG-2108's memory-handler direction is justified. It removes hidden
  persistence and provides a clear speedup over the old "loop committed runs"
  baseline.
- v0.1.8 should not market sweep as a massive performance feature. The honest
  claim is: same semantics, cleaner candidate output, no persistent run spam,
  and a measured local speedup around 1.6x-1.8x on this benchmark.
- Further speedups likely require work outside LDG-2109:
  - reduce per-candidate setup overhead inside the fold;
  - avoid recomputing or rebuilding feature matrices when many candidates share
    identical feature sets;
  - broaden precompute benchmarks to heavier indicators and larger universes;
  - eventually dispatch candidates in parallel after the sequential contract is
    stable.

## Caveats

- Single local run, not a statistically rigorous benchmark suite.
- Windows filesystem and DuckDB write costs are part of the baseline result.
- The persistent loop baseline is intentionally practical rather than minimal:
  it uses public `ledgr_run()` and closes each returned `ledgr_backtest`.
- Warnings are suppressed inside timed sections to avoid measuring console
  output overhead. The underlying warnings are expected final-bar no-fill
  warnings and the large-grid precompute warning.
- The benchmark does not compare against a hypothetical optimized persistent
  batch runner; no such public runner exists.

## Raw Output

```text
            scenario n_candidates n_instruments n_days n_bars sweep_plain_sec
  small_5_candidates            5             4    252   1008            2.97
 local_50_candidates           50             4    252   1008           26.67
 precompute_sec sweep_precomputed_sec sweep_precomputed_total_sec run_loop_sec
           0.06                  2.82                        2.88         5.13
           0.26                 27.96                       28.22        45.25
 sweep_plain_candidates_per_sec sweep_precomputed_candidates_per_sec
                       1.683502                             1.773050
                       1.874766                             1.788269
 run_loop_candidates_per_sec sweep_plain_speedup_vs_run_loop
                   0.9746589                        1.727273
                   1.1049724                        1.696663
 sweep_precomputed_speedup_vs_run_loop precomputed_total_speedup_vs_run_loop
                              1.819149                              1.781250
                              1.618383                              1.603473
```
