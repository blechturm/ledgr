# ledgr Local Benchmark Suite

This directory contains local development benchmark harnesses. They are
maintainer artifacts, not package documentation, not pkgdown content, and not
public release-note performance claims.

## Index

**Live** means a current ticket, CI, the benchmark manual, the release
playbook, a test or tool, or another live harness uses the directory.
**History-only** means only closed packets cite it: keep it as evidence, do
not edit its records, and do not build new work on it. Classification as of
v0.2.3 (2026-10-29), from the timing-harness inventory for LDG-3155.

| Path | Status | What it is |
| --- | --- | --- |
| `timing/` | live | shared paired timing harness for before/after regression gates (LDG-3155); per-cut protocol folders under `timing/protocols/` |
| `peer_benchmark/` | live | peer benchmark and parity driver (manual; `test-peer-benchmark-boundary.R`, `test-param-grid.R`) |
| `shared/` | live | self-profiling workload grid `run_benchmarks.R` (manual) |
| `results/` | live, local | generated artifacts, ignored by git |
| `v0_2_3_ws1_timing/` | live | v0.2.3 cut 1 timing protocol and records (cut 1 release evidence; re-checkable only while its bytes are unchanged) |
| `v0_2_3_output_freeze/` | live | A0 output oracle; its fixtures are WS1 protocol files |
| `v0_2_3_rng_baseline/` | live | RNG baseline probe, cut 4 authority evidence |
| `v0_2_3_install_floor/` | live | M4 dependency-floor measurement |
| `v0_2_2_long_window_regression/` | live | terminal release fixture (`release_ci_playbook.md`, `test-long-window-regression-control.R`); `helpers.R` is sourced by other harnesses; its timing suite is no longer a gate |
| `v0_2_2_real_data_scale/` | live | recorder manifests pinned by `test-scale-recorder-contract.R` |
| `v0_2_2_pre_cran_removal/` | live | census read by `tools/check-codebase-contracts.R`, `tools/run-advisory-lint.R` and `test-codebase-contracts.R` |
| `v0_2_2_real_data_continuity/`, `v0_2_2_scoring_boundary/` | history-only | correctness records, cited as overlapping evidence in `tests/claims.yml` |
| `notes/` | history-only | findings notes from the v0.1.8-v0.2.0 performance work |
| `archive/` | history-only | superseded v0.1.8.7-era orientation harnesses |
| `availability_closeout/` | history-only | v0.2.0.1 warm/cold closeout runner |
| `fold_loop/` | history-only | v0.1.8.8 fold-loop diagnostic profiler |
| `long_window/` | history-only | v0.2.2-era long-window scaling reproducers |
| `parallel_sweep/` | history-only | v0.1.8.8 parallel sweep attribution (its `run_benchmarks.R` source path is stale) |
| `references/` | history-only | published LEAN/Ziplime context rows and fetchers |
| `workstream14_fact_scaling.R` | history-only | v0.2.0.2 WS14 fact-scaling clock |
| `v0_2_0_1_stage_l/`, `_m/`, `_n/`, `_o/` | history-only | v0.2.0.1 batch 11-14 gates |
| `v0_2_0_2_ingestion/`, `v0_2_0_2_workstream8/`, `_workstream30/`, `_workstream31/` | history-only | v0.2.0.2 clocks and peer records |
| every other `v0_2_2_*` directory | history-only | v0.2.2 workstream evidence and clocks |

## Before/After Regression Gates

Paired before/after timing gates use the shared harness in `timing/`. A cut
adds only a protocol folder (`timing/protocols/<protocol id>/`: `matrix.csv`,
`thresholds.csv`, `workloads.R`, `protocol.md`); it does not copy or fork the
runner or checker. The rules are in the benchmark manual,
`inst/design/manual/benchmark_methodology.qmd`, section "Before/After
Regression Gates". Run from the package root:

```powershell
[System.Diagnostics.Process]::GetCurrentProcess().ProcessorAffinity = [IntPtr]0xFFFF; `
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/bench/timing/runner.R `
  --protocol=dev/bench/timing/protocols/<id> --base=<commit> --candidate=<commit> --label=<name>
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/bench/timing/check.R `
  --protocol=dev/bench/timing/protocols/<id> --record=dev/bench/timing/records/<id>/<name>/attempt-1
```

## Current Peer Benchmark

Run from the package root:

```powershell
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/bench/peer_benchmark/peer_benchmark.R --preset smoke
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/bench/peer_benchmark/peer_benchmark.R --preset record
```

The peer benchmark has two explicitly separated outputs:

- parity: canonical equity/trade-surface checks against the ledgr TTR-backed SMA
  row;
- performance: same-host timing under declared per-engine boundaries.

Performance has two interpretations. Cold end-to-end time remains the primary
apples-to-apples peer boundary when input preparation and required outputs are
comparable. Warm research-iteration time is the ledgr workflow boundary over an
existing unchanged, verified snapshot. It includes experiment-specific setup,
execution, and required results, while one-time snapshot preparation is
reported separately and paid again whenever the data or facts change. The
current harness records those boundaries as `snapshot_prepare_sec`,
`experiment_setup_sec`, `engine_sec`, and `results_sec`.

The primary zipline row is `zipline-reloaded-full`, which exercises
zipline-reloaded csvdir bundle ingestion plus `run_algorithm()`.

It writes canonical equity, fills, trade-summary, status, parity, performance,
environment, and parity-history artifacts under `dev/bench/results/`. See
`peer_benchmark/README.md`.

## Other Harnesses

Parallel sweep attribution:

```powershell
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/bench/parallel_sweep/parallel_sweep_measurement.R --preset smoke --repeats 1 --warmup 0
```

Fold-loop diagnostics:

```powershell
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/bench/fold_loop/fold_loop_diagnostic.R --preset smoke --repeats 1
```

Shared structured benchmark runner:

```powershell
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/bench/shared/run_benchmarks.R --preset smoke --repeats 1 --warmup 1
```

## Reference Data

Published LEAN/Ziplime rows under `references/` are context-only. They are not
mixed into same-host ratios or parity checks.

```powershell
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" -e 'source("dev/bench/references/fetch_ziplime_reference.R"); fetch_ziplime_reference()'
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" -e 'source("dev/bench/references/fetch_lean_reference.R"); fetch_lean_reference()'
```

## Archived Material

`archive/` keeps older timing-only peer scripts and width sweeps for provenance.
They do not replace the current peer benchmark because they do not emit the
canonical per-engine equity curves, parity tiers, status rows, and parity
history required by the peer methodology.
