# LDG-2479 Workload Grid Baseline Closeout

Status: Completed local baseline  
Created: 2026-05-31  
Scope: v0.1.8.8 self-profiling workload grid for v0.1.9 optimization scoping

This is a local-host, current-source development benchmark. It is not a public
performance claim, not a peer benchmark, and not a release ranking. The grid is
ledgr-only and exists to expose how cost surfaces move across fill density,
universe size, history length, and persistence mode.

## Artifacts

Primary record prefix:

```text
dev/bench/results/ledgr_bench_record_20260531T132910Z
```

Files:

- `dev/bench/results/ledgr_bench_record_20260531T132910Z_raw.csv`
- `dev/bench/results/ledgr_bench_record_20260531T132910Z_summary.csv`
- `dev/bench/results/ledgr_bench_record_20260531T132910Z_environment.json`
- `dev/bench/results/ledgr_bench_record_20260531T132910Z_results.json`
- `dev/bench/results/ledgr_bench_record_20260531T132910Z_summary.md`

Smoke verification prefix:

```text
dev/bench/results/ledgr_bench_smoke_20260531T121325Z
```

The smoke run executed the existing ten benchmark scenarios plus all sixteen
new density-by-universe-by-persistence cells.

## Grid Shape

Density:

- `low`: SMA 20/50 continuous target semantics
- `high`: SMA 5/10 continuous target semantics

Universe size and history:

- `small`: 50 instruments x 252 pulses
- `medium`: 100 instruments x 1260 pulses
- `large`: 500 instruments x 1260 pulses
- `xlarge`: 1000 instruments x 1260 pulses

Persistence:

- `durable`: `ledgr_run()` with DuckDB-backed run artifacts
- `ephemeral`: one-candidate `ledgr_sweep()` path

The smoke preset uses the same sixteen scenario names at reduced shapes so the
grid can be validated quickly before launching the record preset.

## Record Summary

| Scenario | Mode | Inst | Pulses | Wall s | Loop s | Fills extract s | Engine us/fill | Extract us/fill |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| density_low_small_durable | durable | 50 | 252 | 4.78 | 0.51 | 0.16 | 1917 | 602 |
| density_low_small_ephemeral | ephemeral | 50 | 252 | 0.89 | NA | NA | NA | NA |
| density_low_medium_durable | durable | 100 | 1260 | 6.05 | 2.89 | 0.61 | 1052 | 222 |
| density_low_medium_ephemeral | ephemeral | 100 | 1260 | 5.91 | NA | NA | NA | NA |
| density_low_large_durable | durable | 500 | 1260 | 27.11 | 16.58 | 6.63 | 1241 | 496 |
| density_low_large_ephemeral | ephemeral | 500 | 1260 | 28.19 | NA | NA | NA | NA |
| density_low_xlarge_durable | durable | 1000 | 1260 | 56.76 | 37.04 | 18.06 | 1539 | 750 |
| density_low_xlarge_ephemeral | ephemeral | 1000 | 1260 | 64.77 | NA | NA | NA | NA |
| density_high_small_durable | durable | 50 | 252 | 1.83 | 1.08 | 0.32 | 802 | 238 |
| density_high_small_ephemeral | ephemeral | 50 | 252 | 1.16 | NA | NA | NA | NA |
| density_high_medium_durable | durable | 100 | 1260 | 15.94 | 12.80 | 6.61 | 931 | 481 |
| density_high_medium_ephemeral | ephemeral | 100 | 1260 | 13.82 | NA | NA | NA | NA |
| density_high_large_durable | durable | 500 | 1260 | 153.76 | 138.86 | 82.67 | 2040 | 1215 |
| density_high_large_ephemeral | ephemeral | 500 | 1260 | 171.81 | NA | NA | NA | NA |
| density_high_xlarge_durable | durable | 1000 | 1260 | 445.02 | 413.47 | 197.11 | 3107 | 1481 |
| density_high_xlarge_ephemeral | ephemeral | 1000 | 1260 | 623.87 | NA | NA | NA | NA |

The `density_high_xlarge_durable` fills count used the ledger row count as a
fallback denominator because `ledgr_results(bt, "fills")` did not return a row
count on that largest cell, while the ledger count remained available. Smaller
durable cells had `events == fills`, so this fallback is a measurement bridge,
not a product contract.

## Scaling Findings

High-density workloads dominate the observed cost surface. At 1000 x 1260,
moving from SMA 20/50 to SMA 5/10 increased durable wall time from 56.76s to
445.02s and loop time from 37.04s to 413.47s. The fill-density surface is the
lead v0.1.9 input.

Fills extraction remains a first-order post-run cost. On durable rows,
`fills_extract_sec` rose from 6.63s at low-density large to 82.67s at
high-density large, and from 18.06s at low-density xlarge to 197.11s at
high-density xlarge. Extract microseconds per fill also worsened with the
largest cells.

Ephemeral is not uniformly faster. At small and medium high-density shapes it
was faster than durable, but at large and xlarge it became slower:

| Base cell | Durable s | Ephemeral s | Ephemeral delta s |
| --- | ---: | ---: | ---: |
| density_low_small | 4.78 | 0.89 | -3.89 |
| density_low_medium | 6.05 | 5.91 | -0.14 |
| density_low_large | 27.11 | 28.19 | +1.08 |
| density_low_xlarge | 56.76 | 64.77 | +8.01 |
| density_high_small | 1.83 | 1.16 | -0.67 |
| density_high_medium | 15.94 | 13.82 | -2.12 |
| density_high_large | 153.76 | 171.81 | +18.05 |
| density_high_xlarge | 445.02 | 623.87 | +178.85 |

This confirms the LDG-2476 three-phase finding: the memory-backed path is not a
guaranteed fast path at high fill density. Persistence mode has a crossover
surface that must be measured by workload shape, not inferred from storage
semantics.

## v0.1.9 Target Stack

The grid reinforces this target order:

1. Fill/event throughput inside the fold loop, especially high-density xlarge
   cells where durable loop time reached 413.47s.
2. Fills read-back reconstruction, where durable extraction reached 197.11s on
   the high-density xlarge cell.
3. Memory output-handler and ephemeral reconstruction cost, because ephemeral
   became 178.85s slower than durable on the high-density xlarge cell.
4. Target/state vector scanning and delta construction, which should be
   profiled against the high-density cells before a rewrite.
5. Snapshot/data ingestion, still visible but no longer the lead cost surface
   on these SMA scenarios.

Per-pulse decomposition on the ephemeral sweep path remains deferred. The
current sweep rows expose `snapshot_sec` and `t_wall_sec`; durable rows expose
`t_loop_sec`, `t_pre_sec`, and individual result-extraction timings.

## Verification

Commands run:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/bench/shared/run_benchmarks.R --preset smoke --repeats 1 --warmup 0
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/bench/shared/run_benchmarks.R --preset record --repeats 1 --warmup 0 --scenarios density_low_small_durable,density_low_small_ephemeral,density_low_medium_durable,density_low_medium_ephemeral,density_low_large_durable,density_low_large_ephemeral,density_low_xlarge_durable,density_low_xlarge_ephemeral,density_high_small_durable,density_high_small_ephemeral,density_high_medium_durable,density_high_medium_ephemeral,density_high_large_durable,density_high_large_ephemeral,density_high_xlarge_durable,density_high_xlarge_ephemeral
```

The record run produced sixteen rows, one per grid cell, with zero failures.
Warnings are final-bar no-fill warnings from the strategy target surface and
scale with the number of instruments that still signal on the terminal pulse.
