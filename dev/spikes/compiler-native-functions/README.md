# Native Compilation Spike

This isolated spike asks one question:

> Can currently maintained R-to-native compilers reproduce representative
> numerical, stateful, and batched kernels correctly while approaching a
> handwritten Rcpp reference closely enough to justify further experiments?

It does not implement a second ledgr engine and makes no public performance
claim. The kernels deliberately omit ledgr's fill, point-in-time availability,
corporate-action, accounting, persistence, and identity semantics.

The prerequisite was that each primary compiler could compile and run a typed
numeric loop on Windows with R 4.6.1. quickr and ast2ast passed. The kill
condition for a candidate was failure of that prerequisite or a supported
correctness case. nCompiler was stopped after its generated C++ failed to build
on this host; it did not delay the two primary candidates.

## Layout

- `R/`: authoritative R kernels and compiler source functions.
- `src/reference.cpp`: handwritten Rcpp reference for the same algorithms.
- `tests/test-correctness.R`: ten correctness cases.
- `benchmarks/run-benchmarks.R`: warm execution and allocation measurements.
- `results/windows-r4.6.1/`: the recorded local result.
- `COMPILERS.md`: current capability and integration survey.
- `REPORT.md`: findings and recommendation.
- `spike_runner.R`: evidence runner.
- `spike_checker.R`: scope guard, rerun, CSV diff, and gutted-path check.

All generated shared libraries are built in R temporary directories. Nothing
under this spike is required to install or use ledgr.

## Installation

The recorded run used an isolated library outside the ledgr worktree:

```powershell
New-Item -ItemType Directory -Force `
  C:\Users\maxth\ledgr-research\.compiler-lib

& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" -e `
  "install.packages(c('bench','quickr','ast2ast'), lib='C:/Users/maxth/ledgr-research/.compiler-lib', repos='https://cloud.r-project.org', type='binary')"
```

The optional nCompiler feasibility attempt used source commit
`bf9ae45012c03a6603f1c0e2ff158b10c2a2bdca` and these isolated dependencies:

```powershell
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" -e `
  "install.packages(c('pkgKitten','Rcereal','RcppEigen','RcppParallel','inline'), lib='C:/Users/maxth/ledgr-research/.compiler-lib', repos='https://cloud.r-project.org', type='binary')"

& "C:\Program Files\R\R-4.6.1\bin\x64\R.exe" CMD INSTALL `
  --library="C:/Users/maxth/ledgr-research/.compiler-lib" `
  C:/path/to/nCompiler/nCompiler
```

`inline` was needed by `nCompile()` but was not declared in nCompiler's
DESCRIPTION at the surveyed commit.

## Reproduction

From the ledgr repository root:

```powershell
$env:LEDGR_COMPILER_SPIKE_LIB = `
  "C:\Users\maxth\ledgr-research\.compiler-lib"

& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" `
  dev/spikes/compiler-native-functions/spike_runner.R `
  --preset smoke `
  --output C:/tmp/ledgr-compiler-spike-smoke `
  --verify-gut
```

Full recorded grid:

```powershell
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" `
  dev/spikes/compiler-native-functions/spike_runner.R `
  --preset record `
  --output C:/tmp/ledgr-compiler-spike-record `
  --verify-gut
```

Evidence checker:

```powershell
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" `
  dev/spikes/compiler-native-functions/spike_checker.R
```

Set `LEDGR_COMPILER_SPIKE_NCOMPILER=1` only to retry the secondary compiler.
It is off by default because the recorded Windows attempt already reached a
toolchain-specific generated-C++ failure.

## Measurement boundaries

The runner records three distinct quantities:

1. compilation plus the first invocation;
2. warm execution after compilation and initialization;
3. a component sum of measured compilation, deterministic input preparation,
   and warm execution.

The component sum is named `compile_prepare_median_sec`; it is not passed off
as a single wall-clock measurement. Native argument conversion and result
materialization are inside warm execution. Synthetic data generation is not.

The OpenMP batch variant uses four threads across independent configurations.
No dependent time step is parallelized.

## Scope and interpretation

The recorded data are local maintainer evidence. Hardware, power state,
compiler version, and package versions are part of the result. Read
`REPORT.md` before quoting any ratio. In particular, compilation takes seconds
while many warm calls take microseconds, so a warm speedup alone is not an
integration recommendation.
