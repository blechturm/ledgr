# Parallel Sweep Measurement Closeout

Status: LDG-2475 smoke closeout  
Created: 2026-05-30  
Scope: v0.1.8.8 local current-source parallel sweep attribution

## Interrupt Contract

Parallel sweep interruption is discard-all for v0.1.8.8. If worker-backed
candidate dispatch is interrupted before every candidate result has returned,
ledgr stops the worker backend where possible and throws
`ledgr_parallel_sweep_interrupted`. No partial `ledgr_sweep_results` table is
returned, and no partially promotable candidate surface is exposed.
Partial-result recovery remains deferred to a future explicit contract.

Verification:

- `tests/testthat/test-sweep-parallel.R` simulates an interrupt during parallel
  task collection and asserts the structured interrupt class, cleanup callback,
  and discard-all message.
- `ledgr_sweep()` help and `inst/design/contracts.md` document the same
  behavior.

## Measurement Harness

Added `dev/bench/parallel_sweep_measurement.R`.

The harness records:

- worker setup overhead;
- full `ledgr_sweep()` wall time;
- candidate count;
- worker count;
- workload dimensions;
- per-candidate timing;
- sequential/parallel equality status;
- local R, package, backend, and git metadata.

The result files are written under `dev/bench/results/`, which remains ignored
by git for local benchmark artifacts.

Smoke command:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/bench/parallel_sweep_measurement.R --preset smoke --repeats 1 --warmup 0 --candidate-counts 1,2 --workers 1,2
```

Smoke output prefix:

```text
dev/bench/results/parallel_sweep_smoke_20260530T171611Z
```

Files produced:

- `parallel_sweep_smoke_20260530T171611Z_raw.csv`
- `parallel_sweep_smoke_20260530T171611Z_summary.csv`
- `parallel_sweep_smoke_20260530T171611Z_environment.json`
- `parallel_sweep_smoke_20260530T171611Z_results.json`
- `parallel_sweep_smoke_20260530T171611Z_summary.md`

Environment:

- R: `R version 4.5.2 (2025-10-31 ucrt)`
- Platform: `x86_64-w64-mingw32`
- Branch: `v0.1.8.8`
- Git SHA: `bb7a28e8df4b097a465f034f134b312c447ebf37`
- mirai: `2.7.0`
- TTR installed: `TRUE`

## Smoke Results

| Workload | Candidates | Workers | Setup s | Wall s | Candidate s | Speedup vs 1 | Equality |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| cheap_sma | 1 | 1 | 0.0000 | 0.6900 | 0.6900 | 1.000 | TRUE |
| cheap_sma | 1 | 2 | 0.3900 | 1.9700 | 1.9700 | 0.350 | TRUE |
| cheap_sma | 2 | 1 | 0.0000 | 0.3100 | 0.1550 | 1.000 | TRUE |
| cheap_sma | 2 | 2 | 0.8200 | 2.0200 | 1.0100 | 0.153 | TRUE |
| feature_heavy | 1 | 1 | 0.0000 | 0.1900 | 0.1900 | 1.000 | TRUE |
| feature_heavy | 1 | 2 | 0.8300 | 1.5300 | 1.5300 | 0.124 | TRUE |
| feature_heavy | 2 | 1 | 0.0000 | 0.2300 | 0.1150 | 1.000 | TRUE |
| feature_heavy | 2 | 2 | 0.4300 | 1.5500 | 0.7750 | 0.148 | TRUE |

Interpretation:

- Equality held for every worker-backed smoke row.
- Startup/setup overhead dominated these small smoke shapes.
- No crossover point was observed for candidate counts 1 or 2 on this local
  smoke run.
- These rows are local-host current-source evidence only. They are not a public
  speedup claim and should not be generalized beyond the measured shapes.

## Follow-Up

Use the record preset with larger candidate counts before making any release
note claim about useful parallel speedup:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/bench/parallel_sweep_measurement.R --preset record --repeats 3 --warmup 1
```
