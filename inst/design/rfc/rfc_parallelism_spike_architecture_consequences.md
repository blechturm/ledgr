# RFC: Parallelism Spike Architecture Consequences

**Status:** Draft for Claude review
**Date:** 2026-05-13
**Related ticket:** LDG-2007
**Source episode:** `inst/design/spikes/ledgr_parallelism_spike/`

## Purpose

This RFC asks for review of the architectural consequences we should draw from
the LDG-2007 parallelism and scale-shape spike before writing the v0.1.8 sweep
spec.

The spike tested whether the planned `mirai` / `mori` direction is viable on
the local development platforms, and whether feature payload movement looks
reasonable for EOD sweep workloads and future larger shapes.

The proposed conclusion is deliberately conservative:

> Use `mirai` as the preferred optional parallel backend, allow plain
> serialization for the first v0.1.8 sweep implementation, keep `mori` and
> worker-local DuckDB reads available as future transport paths, and do not
> confuse synthetic intraday payload success with actual intraday support.

## Test Setup

The spike episode used exploratory scripts under:

```text
dev/spikes/ledgr_parallelism_spike/
```

The design record lives under:

```text
inst/design/spikes/ledgr_parallelism_spike/
```

The runner executed six probes:

1. `mirai` daemon lifecycle on Windows native R and Ubuntu/WSL.
2. Serialization cost for ledgr-sized EOD payloads.
3. `mori::share()` cross-process behavior through `mirai`.
4. DuckDB concurrent read-only access from multiple workers.
5. Package-level environment survival across `mirai` tasks.
6. Larger feature-width and intraday-like synthetic payload movement.

Raw `.rds` result artifacts are local scratch output and are not committed.
Findings are recorded in the spike README and summarized in
`summary_report.md`.

## Platform Results

### Windows Native R

Windows native R completed all six spike probes.

Package versions:

- `mirai` 2.7.0
- `mori` 0.2.0
- DBI 1.2.3
- duckdb 1.4.3
- ledgr 0.1.7.9

### Ubuntu/WSL

Ubuntu/WSL also completed all six spike probes after installing `cmake`.

Package versions:

- `mirai` 2.7.0
- `mori` 0.2.0
- DBI 1.3.0
- duckdb 1.5.2
- ledgr 0.1.7.9

The relevant setup note is that `nanonext`, the `mirai` dependency, may compile
native libraries from source and needs `cmake` in the tested WSL image.

## Findings

### 1. `mirai` Daemon Lifecycle

Both Windows native R and Ubuntu/WSL passed the daemon lifecycle probe.

Observed behavior:

- three `daemons(4)` / `daemons(0)` cycles completed;
- trivial worker tasks returned expected values;
- `everywhere(library(ledgr))` completed;
- `dispatcher = FALSE` worked.

**Finding:** `mirai` is viable on both tested local platforms.

### 2. EOD Payload Serialization

Small and medium EOD payloads were cheap to send.

| Platform | Payload | Object MB | Serialized MB | Per-task send | `everywhere()` send |
| --- | --- | ---: | ---: | ---: | ---: |
| Windows | 20 instruments, 504 bars, 3 features | 0.238 | 0.232 | 0.00s | 0.00s |
| Windows | 100 instruments, 2520 bars, 5 features | 9.654 | 9.622 | 0.01s | 0.04s |
| Windows | Bar matrix proxy, 100 instruments, 2520 bars, 5 columns | 9.654 | 9.622 | 0.01s | 0.03s |
| Ubuntu/WSL | 20 instruments, 504 bars, 3 features | 0.238 | 0.232 | 0.002s | 0.003s |
| Ubuntu/WSL | 100 instruments, 2520 bars, 5 features | 9.654 | 9.622 | 0.030s | 0.048s |
| Ubuntu/WSL | Bar matrix proxy, 100 instruments, 2520 bars, 5 columns | 9.654 | 9.622 | 0.018s | 0.032s |

**Finding:** Plain serialization is acceptable for normal EOD-sized v0.1.8
sweep payloads.

### 3. `mori::share()` Cross-Process Behavior

`mori::share()` objects were readable inside `mirai` workers on both platforms
without a custom `register_serial()` shim.

**Finding:** `mori` is boundary-compatible as an optional transport path. Its
performance benefit over plain serialization has not yet been measured, so it
should not be described as high-performance until a follow-up benchmark proves
that. It should not be required for v0.1.8 correctness.

### 4. DuckDB Read-Only Fanout

Eight concurrent worker tasks opened the same DuckDB file in read-only mode and
returned consistent aggregate results on both platforms.

**Finding:** Worker-local read-only DuckDB access is viable for the tested
shape. The v0.1.8 architecture should not rule it out.

### 5. Package-Level Cache Survival

Global worker state did not persist across tasks, but the package-level
`.ledgr_feature_cache_registry` did persist across tasks on the same daemon.

| Platform | Global env persists | Package registry persists |
| --- | --- | --- |
| Windows | no | yes |
| Ubuntu/WSL | no | yes |

**Finding:** Daemon cache warming is a plausible optimization. It must not be a
correctness requirement.

### 6. Large Feature-Width And Intraday-Like Payloads

Large synthetic payloads remained feasible.

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

The lookup probes returned immediately at timer resolution for the synthetic
list-of-feature-matrices representation.

**Finding:** These results do not force an immediate shared-memory or
worker-local read design. They do show that the transport boundary should stay
modular because payloads are already large enough to become significant when
multiplied by walk-forward folds, CSCV blocks, or larger universes.

## Proposed v0.1.8 Consequences

### 1. Backend Constraint

`mirai` should be the preferred optional parallel backend.

Spec implication:

- `ledgr_sweep()` must work without `mirai`.
- Parallel sweep may require `mirai`.
- `mirai` belongs in `Suggests`, not `Imports`.
- WSL setup notes should mention `cmake` as a possible system prerequisite for
  source installs.

### 2. Transport Constraint

The first v0.1.8 implementation may ship explicit precomputed payloads to
workers, because plain serialization is acceptable for the measured EOD and
moderate scale-shape payloads.

However, v0.1.8 must not define a pre-fetch-only architecture.

The sweep/fold boundary should keep these future transports possible:

- explicit precomputed payload shipping;
- worker-local read-only DuckDB access;
- shared-memory payloads through `mori` or a similar mechanism.

### 3. Cache Constraint

Package-level worker cache persistence may be used as an optimization only.

Correctness must come from explicit inputs:

- experiment identity;
- params;
- strategy and feature identities;
- snapshot identity;
- precomputed feature payload or snapshot-backed lookup;
- seed / RNG contract where applicable.

No candidate should rely on daemon affinity or warmed worker state to be
reproducible.

### 4. Scale Constraint

v0.1.8 should remain explicitly EOD-focused.

The intraday-like spike results only show that synthetic payload movement is
not immediately impossible. They do not test:

- intraday snapshot creation;
- pulse calendar semantics;
- fill timing at intraday scale;
- full runner memory pressure;
- event ledger growth;
- metrics over intraday event volume;
- warmup/scoring boundaries at intraday scale.

Spec implication:

> v0.1.8 should avoid making future intraday work impossible, but it should not
> claim intraday support.

### 5. Sequential-First Remains Acceptable

The spike unblocks the parallel design, but it does not require v0.1.8 to ship
parallel sweep if the fold-core split is the dominant risk.

Spec implication:

- sequential sweep can ship first;
- the sweep internals should still be parallel-ready;
- parallel execution can be added behind the same candidate-evaluation boundary.

## Proposed Spec Text

The v0.1.8 spec should include language equivalent to:

> `mirai` is the preferred optional backend for parallel sweep execution. The
> first implementation may move precomputed feature payloads to workers by
> plain serialization, but the internal transport boundary must not assume that
> pre-fetch is the only valid path. Worker-local read-only DuckDB access and
> shared-memory payloads remain valid future transports. Package-level worker
> caches may be used as optimizations, but reproducibility must come from
> explicit experiment, params, feature, snapshot, and seed inputs. v0.1.8
> remains EOD-focused; intraday-like payload measurements are architecture
> guidance only, not a product commitment.

## Questions For Review

1. Is `mirai` in `Suggests` the right dependency classification, or should it
   remain entirely user-managed for v0.1.8?
2. Is explicit payload shipping acceptable as the first transport path, given
   the measured results?
3. Are worker-local DuckDB reads and `mori` shared-memory payloads the right
   future transport paths to preserve?
4. Should the v0.1.8 spec require parallel execution, or only require that the
   candidate-evaluation boundary is parallel-ready?
5. Is the cache-warming conclusion strong enough: optimization yes,
   correctness no?
