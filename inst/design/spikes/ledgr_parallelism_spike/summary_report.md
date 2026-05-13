# LDG-2007 Parallelism Spike Summary Report

**Date:** 2026-05-13
**Source:** `inst/design/spikes/ledgr_parallelism_spike/README.md`
**Scope:** Windows native R and Ubuntu/WSL results, with v0.1.8 architecture
implications.

## Executive Summary

The Windows native R and Ubuntu/WSL spike results support the planned v0.1.8
parallel sweep direction. `mirai` can start and stop workers reliably,
`mori::share()` crosses the worker boundary without a custom serializer, DuckDB
read-only fanout works for the tested shape, and plain serialization remains
feasible up to roughly 300 MB synthetic feature payloads.

The result does not justify a pre-fetch-only architecture. Large payloads are
feasible, but they are already large enough that v0.1.8 should preserve future
options for worker-local DuckDB reads and shared-memory transport.

Ubuntu/WSL required one system prerequisite: `cmake` must be installed so
`nanonext`, the `mirai` dependency, can build from source. After `cmake` was
installed, the Ubuntu run completed all six spikes.

## Platform Findings

### SPIKE-1: mirai Daemon Lifecycle

Windows native R and Ubuntu/WSL passed the daemon lifecycle test.

- Three `daemons(4)` / `daemons(0)` cycles completed.
- A trivial worker task returned the expected result.
- `everywhere(library(ledgr))` completed successfully.
- `dispatcher = FALSE` also worked.

**Implication:** `mirai` is viable as an optional backend for v0.1.8 sweep
planning on both tested local platforms. WSL setup should document `cmake` as a
system prerequisite when installing from source.

### SPIKE-2: EOD Payload Serialization

Plain serialization was fast at small and medium EOD scales.

| Platform | Payload | Object MB | Serialized MB | Per-task send | `everywhere()` send |
| --- | --- | ---: | ---: | ---: | ---: |
| Windows | 20 instruments, 504 bars, 3 features | 0.238 | 0.232 | 0.00s | 0.00s |
| Windows | 100 instruments, 2520 bars, 5 features | 9.654 | 9.622 | 0.01s | 0.04s |
| Windows | Bar matrix proxy, 100 instruments, 2520 bars, 5 columns | 9.654 | 9.622 | 0.01s | 0.03s |
| Ubuntu/WSL | 20 instruments, 504 bars, 3 features | 0.238 | 0.232 | 0.002s | 0.003s |
| Ubuntu/WSL | 100 instruments, 2520 bars, 5 features | 9.654 | 9.622 | 0.030s | 0.048s |
| Ubuntu/WSL | Bar matrix proxy, 100 instruments, 2520 bars, 5 columns | 9.654 | 9.622 | 0.018s | 0.032s |

**Implication:** For normal EOD-sized sweep payloads, plain serialization is not
a blocking cost on either tested platform. One-time `everywhere()` setup remains
viable.

### SPIKE-3: mori Cross-Process Behavior

`mori::share()` objects were readable inside `mirai` workers on both tested
platforms without custom serialization registration.

**Implication:** `mori` is boundary-compatible and should remain optional. It
should not be required for v0.1.8 correctness. SPIKE-7 measured its setup and
lookup behavior against a plain-serialization baseline and did not show a lookup
speed advantage for the tested access pattern.

### SPIKE-4: DuckDB Read-Only Fanout

Eight concurrent worker tasks opened the same DuckDB file in read-only mode and
returned consistent aggregate results on both tested platforms.

The WAL artifact follow-up also passed on both platforms. The probe recorded
the DuckDB artifact list before and after concurrent read-only worker access.
On Windows and Ubuntu/WSL, the artifact list remained exactly:

```text
snapshot.duckdb
```

No `.wal`, temp, lock, or other side files were created by read-only worker
access.

**Implication:** Worker-local read-only DuckDB access is viable for the tested
shape. v0.1.8 should not rule it out by baking in a pre-fetch-only
transport contract.

### SPIKE-5: Worker State And Feature Cache Survival

Global worker state was cleaned between tasks, but the `ledgr` package-level
feature-cache registry persisted across tasks on the same daemon on both tested
platforms.

| State location | Result |
| --- | --- |
| `.GlobalEnv` test environment | Did not persist |
| `.ledgr_feature_cache_registry` package registry | Persisted |

**Implication:** Daemon cache warming is plausible as an optimization, but
correctness must not depend on it. The sweep architecture should remain correct
if workers receive precomputed payloads explicitly.

### SPIKE-6: Large Feature-Width And Intraday-Like Shapes

Large synthetic payloads remained feasible on both tested platforms.

| Platform | Shape | Object MB | Serialized MB | Per-task send | `everywhere()` send |
| --- | --- | ---: | ---: | ---: | ---: |
| Windows | EOD, 1000 instruments, 2520 bars, 5 features | 96.500 | 96.217 | 0.19s | 0.40s |
| Windows | EOD, 250 instruments, 2520 bars, 50 features | 241.133 | 240.513 | 0.52s | 1.19s |
| Windows | Intraday-like, 100 instruments, 39000 bars, 10 features | 297.620 | 297.563 | 0.65s | 1.58s |
| Windows | Intraday feature-width stress, 100 instruments, 7800 bars, 50 features | 297.887 | 297.624 | 0.64s | 1.63s |
| Ubuntu/WSL | EOD, 1000 instruments, 2520 bars, 5 features | 96.500 | 96.217 | 0.163s | 0.304s |
| Ubuntu/WSL | EOD, 250 instruments, 2520 bars, 50 features | 241.133 | 240.513 | 0.428s | 0.762s |
| Ubuntu/WSL | Intraday-like, 100 instruments, 39000 bars, 10 features | 297.620 | 297.563 | 0.426s | 1.066s |
| Ubuntu/WSL | Intraday feature-width stress, 100 instruments, 7800 bars, 50 features | 297.887 | 297.624 | 0.575s | 1.091s |

Lookup probes returned immediately at timer resolution for the synthetic
list-of-feature-matrices representation.

**Implication:** The tested payload sizes do not force an immediate architecture
change, but they are large enough that v0.1.8 should keep the transport layer
modular. Future intraday support should not inherit a design that assumes all
workers always receive full precomputed feature payloads by serialization.

## WSL Prerequisite

Ubuntu/WSL was accessible and had R 4.5.2. After installing `cmake`, package
availability was:

- `mori` 0.2.0 available;
- `mirai` 2.7.0 available;
- DBI 1.3.0 available;
- duckdb 1.5.2 available;
- ledgr 0.1.7.9 installed into `lib-wsl`.

**Implication:** WSL can be used as a local spike platform once `cmake` is
available. The setup note matters because `nanonext` may compile bundled native
libraries from source.

## Design Decisions Unblocked

1. `mirai` is viable for Windows-native and Ubuntu/WSL local parallel sweep
   experiments.
2. `mori` should remain optional, not required; it is boundary-compatible and
   reduces serialized payload size, but the follow-up lookup benchmark did not
   show a speed advantage over plain matrices.
3. Plain serialization is acceptable for v0.1.8 EOD-scale sweep payloads.
4. Worker-local DuckDB read-only access remains a valid architecture option.
5. Feature-cache warming can be considered an optimization, not a contract.
6. v0.1.8 should preserve transport modularity for future intraday and
   feature-width growth.

## Recommended v0.1.8 Constraint

The sweep architecture should use a modular transport boundary:

- allow explicit precomputed payload shipping for the first implementation;
- do not prevent worker-local DuckDB reads;
- do not prevent future shared-memory payloads;
- do not make daemon cache persistence part of correctness.

This keeps sequential sweep, parallel sweep, walk-forward, and future
intraday-like workloads on the same architectural path.

## Follow-Up Spike

Claude review correctly noted that the first pass did not sufficiently measure
`mori` efficiency. SPIKE-7 compared plain serialized payloads with
`mori::share()` payloads on worker-side lookup and setup time.

| Platform | Shape | Plain setup | Plain lookup | mori share + setup | mori lookup |
| --- | --- | ---: | ---: | ---: | ---: |
| Windows | EOD moderate / many features | 1.050s | 0.200s | 0.700s | 0.570s |
| Windows | Intraday feature-width stress | 1.200s | 0.210s | 0.700s | 0.670s |
| Ubuntu/WSL | EOD moderate / many features | 1.278s | 0.179s | 1.063s | 0.465s |
| Ubuntu/WSL | Intraday feature-width stress | 1.294s | 0.186s | 1.193s | 0.606s |

`mori` reduced serialized payload size dramatically, from roughly 240-298 MB
to less than 0.2 MB for the tested shared-object handles. It also reduced
one-time setup time modestly. It did not improve the tested lookup loop; plain
matrices were faster. v0.1.8 should therefore keep `mori` as an optional future
transport path, but should not describe it as proven high-performance.

SPIKE-8 tested worker environment initialization for Tier 2 package-dependent
strategy and feature code. The result was identical on Windows and Ubuntu/WSL:

- package-qualified calls such as `jsonlite::toJSON()` and `dplyr::mutate()`
  worked without attaching packages, assuming the package is installed;
- unqualified calls such as `mutate()` and `SMA()` failed without setup;
- `everywhere({ library(dplyr); library(TTR) })` made those unqualified calls
  work in later tasks;
- package options set during setup persisted to later tasks;
- helper functions assigned in setup did not persist under default cleanup.

v0.1.8 parallel Tier 2 support should therefore include an explicit worker setup
phase for attached package dependencies and options. Arbitrary helper objects
should not be smuggled through `.GlobalEnv`; they should be package functions,
explicit task payloads, or deliberate package-registry entries. Tier 3 ambient
state remains rejected.
