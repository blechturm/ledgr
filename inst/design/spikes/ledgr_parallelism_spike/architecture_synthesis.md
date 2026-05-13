# Parallelism Spike Architecture Synthesis

**Status:** Draft synthesis for final review before updating sweep design docs.
**Date:** 2026-05-13
**Sources:**
- `README.md`
- `summary_report.md`
- `inst/design/rfc/rfc_parallelism_spike_architecture_consequences.md`
- `inst/design/rfc/rfc_parallelism_spike_architecture_consequences_response.md`

## Purpose

This document synthesizes the LDG-2007 spike episode, the parallelism RFC,
Claude's response, and follow-up discussion into proposed architecture
constraints for v0.1.8 sweep design.

It is not itself the authoritative sweep architecture document. It is the
review buffer before patching:

- `inst/design/architecture/ledgr_v0_1_8_sweep_architecture.md`
- `inst/design/architecture/ledgr_sweep_mode_ux.md`
- `inst/design/ledgr_roadmap.md` where needed

## Bottom Line

The spike results unblock v0.1.8 sweep design.

`mirai` is viable on Windows native R and Ubuntu/WSL. Plain serialized feature
payloads are acceptable for the first EOD sweep implementation. Worker-local
read-only DuckDB access is also viable and did not create WAL, temp, lock, or
other side files in the tested read-only fanout. `mori` crosses the worker
boundary and reduces transport size sharply, but it is slower than plain
in-process matrices for the tested feature lookup pattern. Parallel Tier 2 code
requires an explicit worker setup phase for attached packages and runtime
options.

The v0.1.8 architecture should therefore be **sequential-first but
parallel-ready**, with parallelism located at the candidate dispatch loop, not
inside the fold core.

## Evidence Summary

### mirai Viability

Both platforms completed the daemon lifecycle probe:

- Windows native R
- Ubuntu/WSL after installing `cmake` for the `nanonext` source build

Observed behavior:

- repeated daemon start/stop cycles succeeded;
- trivial worker tasks returned expected values;
- `everywhere(library(ledgr))` completed;
- `dispatcher = FALSE` worked.

**Architecture consequence:** `mirai` is a viable optional parallel backend.
It should be a `Suggests` dependency, not an `Imports` dependency. Sequential
sweep must work without `mirai`.

If a user requests `workers > 1` and `mirai` is not installed, the failure mode
should be a loud error, not a silent fallback to sequential execution.

## Transport And Feature Payloads

### Plain Serialization Is Good Enough For v0.1.8 EOD Sweep

Plain payload transport was fast for normal EOD-sized objects and remained
acceptable for the larger synthetic shapes.

Representative large-shape timings:

| Platform | Shape | Serialized size | Per-task send | `everywhere()` send |
| --- | --- | ---: | ---: | ---: |
| Windows | EOD 250 instruments x 2520 bars x 50 features | 240.513 MB | 0.52s | 1.19s |
| Windows | Intraday-like 100 instruments x 7800 bars x 50 features | 297.624 MB | 0.64s | 1.63s |
| Ubuntu/WSL | EOD 250 instruments x 2520 bars x 50 features | 240.513 MB | 0.428s | 0.762s |
| Ubuntu/WSL | Intraday-like 100 instruments x 7800 bars x 50 features | 297.624 MB | 0.575s | 1.091s |

**Architecture consequence:** v0.1.8 can use plain serialized precomputed
feature payloads for the first implementation.

### Precomputed Payloads Should Be Sent Once, Not Per Candidate

The difference between per-candidate send and one-time setup matters at grid
scale. A 300 MB payload sent per candidate is acceptable for one candidate but
not for hundreds or thousands. The spike data supports a one-time worker setup
pattern:

```text
start workers
  -> worker setup via everywhere()
  -> install/preload feature payloads or feature lookup state
  -> dispatch cheap candidate tasks
```

**Architecture consequence:** when precomputed feature payloads are used in
parallel sweep, they should be sent once during worker setup, not serialized
with every candidate task.

This is true regardless of the concrete transport:

- plain R payload: preload once with `everywhere()`;
- `mori` payload: register/share once;
- worker-local DuckDB: open/read-only connection or initialize lookup state once
  per daemon where possible.

### Do Not Bake In Pre-Fetch Only

Plain serialization is sufficient for v0.1.8 EOD sweep, but the measured
payload sizes are already large enough that future workloads can exceed it:

- walk-forward multiplies payloads across folds;
- CSCV/PBO multiplies payloads across block partitions;
- larger universes multiply payload width;
- intraday-like workloads multiply pulse count;
- indicator parameter sweeps multiply feature width.

**Architecture consequence:** v0.1.8 should not define a pre-fetch-only design.
The internal transport boundary should preserve:

- explicit precomputed payload shipping;
- worker-local read-only DuckDB access;
- future shared-memory payloads.

## mori

### What mori Proved

`mori::share()` objects crossed the `mirai` worker boundary on Windows and
Ubuntu/WSL without a custom serializer.

For the tested large payloads, serialized handles were tiny:

| Shape | Plain serialized size | mori serialized handle |
| --- | ---: | ---: |
| EOD moderate / many features | 240.513 MB | 0.190 MB |
| Intraday feature-width stress | 297.624 MB | 0.081 MB |

**Architecture consequence:** `mori` is boundary-compatible and can remain an
optional future transport path.

### What mori Did Not Prove

`mori` was slower for the tested lookup loops:

| Platform | Shape | Plain lookup | mori lookup |
| --- | --- | ---: | ---: |
| Windows | EOD moderate / many features | 0.200s | 0.570s |
| Windows | Intraday feature-width stress | 0.210s | 0.670s |
| Ubuntu/WSL | EOD moderate / many features | 0.179s | 0.465s |
| Ubuntu/WSL | Intraday feature-width stress | 0.186s | 0.606s |

The likely mechanism is indirection. Plain deserialized matrices sit in worker
process memory and are accessed with local pointer arithmetic. `mori` access
goes through a shared-memory handle. In fold-core execution, feature lookup is
hot: it happens repeatedly across pulses, instruments, and features.

**Architecture consequence:** `mori` should not be the default feature lookup
representation for v0.1.8 fold execution. It is a transport-bandwidth tool, not
a proven per-pulse feature-access optimization.

`mori` becomes relevant when re-transmission frequency or memory pressure
dominates lookup cost. Examples:

- walk-forward folds where each fold has a different date-range slice and
  workers would otherwise receive new large payloads repeatedly;
- CSCV/PBO partitions that repeatedly redistribute block-specific payloads;
- very large worker counts where `workers x payload_size` creates unacceptable
  memory pressure;
- remote or slow transport environments where sending hundreds of MB per setup
  is materially expensive.

At v0.1.8 EOD scale, where `everywhere()` setup is paid once and then amortized
across a large grid, the measured `mori` transport saving is small per
candidate while the lookup penalty is paid repeatedly inside each fold.

Recommended language:

> `mori` is boundary-compatible and may be useful where transport bandwidth or
> memory pressure dominates. Plain in-process matrices remain the preferred
> representation for hot fold-core feature lookup unless future benchmarks show
> otherwise.

## Worker-Local DuckDB Reads

Concurrent read-only DuckDB access succeeded on both platforms. Eight worker
tasks opened the same DuckDB file in `read_only = TRUE` mode and returned
consistent aggregate results.

A targeted WAL probe confirmed that read-only worker access did not create side
files:

```text
before: snapshot.duckdb
after:  snapshot.duckdb
```

No `.wal`, temp, lock, or other side files were created on Windows or
Ubuntu/WSL.

**Architecture consequence:** worker-local read-only DuckDB access remains a
valid future transport path and does not violate sealed-snapshot expectations
in the tested scenario.

The preferred pattern, if this transport is implemented later, is likely:

```text
worker setup
  -> open/read-only snapshot lookup state per daemon where possible
candidate task
  -> evaluate candidate using worker-local lookup
```

The fold core must still not accept a live DBI connection from the orchestrator,
because external pointers cannot cross the `mirai` boundary.

That has a direct interface consequence: the fold-core input abstraction should
be designed to accommodate both of these shapes from the start:

- a precomputed in-memory R payload;
- a sealed snapshot path plus enough metadata for the worker to open a
  read-only local connection and build lookup state.

v0.1.8 can default to the in-memory payload path and defer worker-local snapshot
reads as an implementation. But if the fold-core interface is designed as
payload-only, adding worker-local DuckDB transport later will require an
interface refactor after the parity contract is already established. The cheap
design choice now is to model the input as an abstract feature/bar lookup
source, with payload as the first concrete source and snapshot-path as a future
source.

## Cache And Worker State

### What Persists

Package-level ledgr registry state persisted across later tasks on the same
daemon:

- `.ledgr_feature_cache_registry` entries survived;
- runtime options set during setup survived.

### What Does Not Persist

Plain `.GlobalEnv` helper objects assigned during setup did not persist under
`mirai`'s default `cleanup = TRUE`.

**Architecture consequence:** worker setup can use package-level registries and
options deliberately, but must not rely on arbitrary `.GlobalEnv` state.

Cache warming is an optimization only. Correctness must come from explicit
inputs:

- experiment identity;
- params;
- strategy and feature identities;
- snapshot identity;
- precomputed feature payload or snapshot-backed lookup;
- seed / RNG contract.

Two candidate evaluations with identical inputs must produce identical results
regardless of daemon assignment, execution order, or cache warmth.

For sweep mode specifically, feature lookup inside the fold must be able to
route to a precomputed payload supplied as an explicit input. It must not
silently fall back to live feature computation or ambient session registry state
when a precomputed payload was supplied. Cache warming can accelerate lookup,
but the payload or snapshot-backed lookup source is the authority.

## Tier 2 Worker Setup

SPIKE-8 tested package-dependent Tier 2 shapes.

Findings were identical on Windows and Ubuntu/WSL:

- package-qualified calls such as `jsonlite::toJSON()` and `dplyr::mutate()`
  worked without package attachment, provided the package is installed on the
  worker library path;
- unqualified calls such as `mutate()` and `SMA()` failed without setup;
- `everywhere({ library(dplyr); library(TTR) })` made unqualified calls work in
  later tasks;
- S3 tibble class behavior was available after package setup;
- runtime options set in setup persisted;
- helper functions assigned in setup did not persist under default cleanup.

**Architecture consequence:** parallel Tier 2 support requires an explicit
worker setup phase before candidate dispatch.

The setup phase should handle:

- attaching declared package dependencies;
- setting runtime options required by Tier 2 code;
- loading ledgr and any required namespaces.

The setup phase must not paper over Tier 3 by exporting arbitrary helper
objects into `.GlobalEnv`. Helper objects must be:

- package functions;
- explicit task payloads;
- or deliberate package-registry entries with a clear identity contract.

Tier 3 ambient state remains rejected.

### New v0.1.8 Design Question

Parallel sweep needs package dependency information before worker setup begins.
The v0.1.8 spec must decide where that comes from:

1. explicit API, e.g. `ledgr_sweep(..., worker_packages = c("dplyr", "TTR"))`;
2. strategy preflight output;
3. inferred package-qualified namespace detection;
4. some combination.

Conservative recommendation for v0.1.8:

- keep the worker package list explicit for unqualified Tier 2 calls;
- allow preflight to report discovered package-qualified namespaces;
- do not silently attach packages based only on inference if doing so would
  hide ambiguity from the user.

This is a concrete extension to the preflight contract. A tier label alone is
not enough for parallel Tier 2 sweep. The preflight result, or a companion
pre-sweep dependency check, must surface package dependency information before
worker setup begins.

## Parallelism Boundary

Parallelism belongs at the candidate dispatch loop:

```text
param grid row -> candidate evaluation -> candidate result
```

It does not belong inside a single candidate's fold execution. The fold core
remains sequential for one candidate.

**Architecture consequence:** v0.1.8 may ship sequential sweep first, provided
the candidate-evaluation boundary is parallel-ready.

Sequential and parallel sweep must produce identical candidate results for the
same:

- experiment;
- params;
- snapshot;
- features;
- seed;
- execution assumptions.

Parallelism may change scheduling, not results.

## RNG Constraint

`mirai` supports per-daemon RNG streams, but ledgr should not inherit candidate
randomness from daemon global state.

**Architecture consequence:** the fold core should receive a per-candidate seed
derived from explicit sweep inputs. Two identical candidate evaluations must
produce identical results regardless of which worker executes them.

This is part of the same symmetry contract as cache independence.

## Output And Persistence

Workers should return structured candidate result objects to the orchestrator.
Workers should not write to shared DuckDB files or shared host-side state.

Output aggregation is orchestrator-owned:

```text
worker candidate result(s)
  -> orchestrator collection
  -> ledgr_sweep_results
```

**Architecture consequence:** v0.1.8 sweep output should remain summary-first
and in-memory. Durable DuckDB writes remain the responsibility of `ledgr_run()`,
not parallel candidate workers.

## Non-Conclusions

The spike does not prove intraday support.

The intraday-like payload shapes only tested synthetic data movement. They did
not test:

- intraday snapshot schema;
- pulse calendar semantics;
- fill timing at sub-day frequency;
- full runner memory pressure;
- event ledger growth;
- metrics over intraday event volume;
- warmup/scoring boundaries at intraday scale.

**Architecture consequence:** v0.1.8 remains EOD-focused. The spike only says
the transport design should not make future intraday work impossible.

## Proposed Updates To Sweep Design Docs

### `ledgr_v0_1_8_sweep_architecture.md`

Patch the mirai section to state:

- `mirai` is viable and belongs in `Suggests`;
- `workers > 1` without `mirai` is a loud error;
- parallelism is at candidate dispatch, not inside fold core;
- precomputed payloads are preloaded once with `everywhere()`, not sent per
  candidate;
- `mori` is boundary-compatible but not lookup-fast;
- worker-local DuckDB read-only fanout is viable and did not create WAL side
  files in the spike;
- package-level cache warming is optimization only;
- Tier 2 parallel support requires explicit worker setup;
- helper objects must not be smuggled through `.GlobalEnv`;
- sequential and parallel sweep must be result-equivalent.

### `ledgr_sweep_mode_ux.md`

Patch the advanced parallelism section:

- remove the current "zero-copy shared features" example as recommended user
  guidance;
- replace with a cautious future-transport note;
- document that the first design path is explicit precompute plus worker setup;
- mention `worker_packages` or an equivalent open design question for Tier 2
  setup;
- say `mori` is optional and boundary-compatible, not a proven default.

### `ledgr_roadmap.md`

Patch only lightly:

- replace "mirai/mori viability must be decided from the spike findings" with
  the actual decision;
- keep the detailed evidence in this spike episode, not in the roadmap.

## Review Questions

1. Should v0.1.8 include an explicit `worker_packages` argument, or should that
   wait until parallel sweep is actually implemented?
2. Should the worker setup phase be part of `ledgr_sweep()` internals only, or
   should advanced users have a documented hook?
3. Is it acceptable to treat `mori` as future-only even though it reduces setup
   payload size sharply?
4. Should worker-local DuckDB read-only access remain future-only for v0.1.8,
   or should the fold-core input abstraction be designed around both payloads
   and snapshot paths immediately?
5. Should v0.1.8 commit to partial sweep results on interrupt, or explicitly
   choose discard-all semantics for the first implementation?

## Recommendations On Open Design Questions

1. **`worker_packages`:** If v0.1.8 ships only sequential sweep, defer the
   public argument. If it ships parallel sweep, use an explicit
   `worker_packages`-style contract for unqualified Tier 2 calls. Do not try to
   infer and attach packages silently in the first parallel implementation.

2. **Worker setup hook:** Keep it internal for v0.1.8. The setup contract is not
   stable enough to expose as user API.

3. **`mori`:** Treat as future-only. It is boundary-compatible and useful for
   transport/memory-pressure scenarios, but not a near-term default for
   fold-core feature lookup.

4. **Fold-core input abstraction:** Design for both payload and snapshot-path
   lookup sources from the start. Implement payload first. Defer worker-local
   snapshot reads as an opt-in transport, but do not make the fold-core
   interface payload-only.

5. **Interrupt semantics:** Choose discard-all for v0.1.8. Partial result
   return requires checkpoint, cancellation, and atomicity semantics that would
   expand the first sweep implementation. The first implementation should be
   explicit: interrupted sweeps do not produce a valid `ledgr_sweep_results`
   object.
