# ledgr Local Benchmark Suite

This directory contains local development benchmark harnesses. They are
maintainer artifacts, not package documentation, not pkgdown content, and not
public release-note performance claims.

## Layout

- `peer_benchmark/` - current v0.1.8.8 peer benchmark and parity report.
- `parallel_sweep/` - Batch 7 parallel sweep attribution harness.
- `fold_loop/` - fold-loop diagnostic profiler.
- `references/` - published context-only reference data and fetchers.
- `shared/` - cross-harness benchmark runner material.
- `archive/` - superseded v0.1.8.7-era orientation harnesses.
- `results/` - local-only generated artifacts, ignored by git.

## Current Peer Benchmark

Run from the package root:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/bench/peer_benchmark/peer_benchmark.R --preset smoke
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/bench/peer_benchmark/peer_benchmark.R --preset record
```

The peer benchmark has two explicitly separated outputs:

- parity: canonical equity/trade-surface checks against the ledgr TTR-backed SMA
  row;
- performance: same-host timing under declared per-engine boundaries.

The primary zipline row is `zipline-reloaded-full`, which exercises
zipline-reloaded csvdir bundle ingestion plus `run_algorithm()`.

It writes canonical equity, fills, trade-summary, status, parity, performance,
environment, and parity-history artifacts under `dev/bench/results/`. See
`peer_benchmark/README.md`.

## Other Harnesses

Parallel sweep attribution:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/bench/parallel_sweep/parallel_sweep_measurement.R --preset smoke --repeats 1 --warmup 0
```

Fold-loop diagnostics:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/bench/fold_loop/fold_loop_diagnostic.R --preset smoke --repeats 1
```

Shared structured benchmark runner:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/bench/shared/run_benchmarks.R --preset smoke --repeats 1 --warmup 1
```

## Reference Data

Published LEAN/Ziplime rows under `references/` are context-only. They are not
mixed into same-host ratios or parity checks.

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" -e 'source("dev/bench/references/fetch_ziplime_reference.R"); fetch_ziplime_reference()'
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" -e 'source("dev/bench/references/fetch_lean_reference.R"); fetch_lean_reference()'
```

## Archived Material

`archive/` keeps older timing-only peer scripts and width sweeps for provenance.
They do not replace the current peer benchmark because they do not emit the
canonical per-engine equity curves, parity tiers, status rows, and parity
history required by v0.1.8.8.
