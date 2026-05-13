# Response: Parallelism Spike Architecture Consequences RFC

**Status:** Reviewer response; architecture input for v0.1.8 spec.
**Respondent:** Claude
**Date:** 2026-05-13
**Responds to:** `inst/design/rfc/rfc_parallelism_spike_architecture_consequences.md`

---

## Summary Verdict

The RFC draws the right conservative conclusion from solid empirical results.
All five proposed consequences are accepted, three with refinements. The
findings justify unblocking the v0.1.8 spec.

Changes from the RFC:

- Accept `mirai` in `Suggests`, with a required failure-mode specification
  when `workers > 1` but `mirai` is absent.
- Accept explicit precomputed payload shipping, with an added constraint:
  precomputed features must be sent via `everywhere()` at daemon startup, not
  serialized per candidate. The SPIKE-2 and SPIKE-6 data make this a
  structural requirement, not a style preference.
- Accept the cache-warming conclusion, with an added symmetry requirement:
  identical candidate inputs must produce identical results regardless of
  daemon assignment and execution order.
- Accept sequential-first, with a clarification of where the parallelism
  boundary sits: the candidate dispatch loop, not inside the fold core.
- Carry one open question into the spec: mori's zero-copy benefit is confirmed
  to cross the process boundary but has not been measured against plain
  serialization. The spec should treat mori as a viable future path, not a
  proven high-performance one.

---

## Findings Review

### Empirical data quality

The platform data is internally consistent. Payload sizes are identical across
platforms (as expected for the same R objects), and transfer times are
plausible (Windows slightly faster on some measures, Ubuntu/WSL on others).
The data supports the conclusions drawn.

### SPIKE-2 and SPIKE-6: the everywhere() constraint

The RFC correctly observes that large payloads are "already large enough to
become significant when multiplied by walk-forward folds, CSCV blocks, or
larger universes." The data makes the mechanism concrete.

For the largest tested shape (300 MB, intraday-like):

- per-task send: 0.64-0.65s (Windows)
- `everywhere()` send: 1.58-1.63s (Windows)

If precomputed features are serialized per candidate at this scale, 1,000
candidates cost ~650s in transport overhead alone before a single fold
executes. If the same payload is sent once via `everywhere()`, the cost is
~1.6s regardless of candidate count.

This is not a performance preference — it is a correctness concern at scale.
A design that serializes features per-task will appear to work in small tests
and fail silently in large sweeps. The v0.1.8 spec should not "allow"
`everywhere()` as an option; it should require it as the transport mechanism
when precomputed features are used.

### SPIKE-3: mori viability vs. mori performance

The RFC states that mori "is viable as an optional high-performance transport
path." Viability is confirmed: mori objects crossed the mirai process boundary
without a custom serializer on both platforms. High-performance is not yet
confirmed: neither SPIKE-3 nor SPIKE-6 reported a measured zero-copy read time
inside a worker against a plain-serialization baseline.

SPIKE-6 states that "lookup probes returned immediately at timer resolution,"
but this applies to the list-of-feature-matrices payload, not specifically to a
mori-backed object. If the SPIKE-6 mori path was not executed (SPIKE-6 tasks 5
asks "If mori is viable from SPIKE-3, repeat..."), that gap should be noted.

The spec should treat mori as: "known to cross the process boundary; zero-copy
benefit not yet measured; viable for a future optimization pass."

### SPIKE-4: WAL artifact behavior not recorded

SPIKE-4's recording requirements included whether WAL file artifacts were
created and cleaned up correctly under concurrent read-only access. The RFC
and summary report do not address this. For a sealed snapshot that is opened
in read-only mode across multiple workers, WAL creation should not happen. If
it does, it indicates that DuckDB is treating the file as writable somewhere
in the open path, which would be a problem on read-only or network-mounted
storage.

This does not block v0.1.8, but the spec should note that worker-local
DuckDB reads must use a verified read-only open that does not create WAL
artifacts before that transport path ships.

---

## Responses to Proposed Consequences

### Consequence 1: `mirai` in `Suggests` — Accepted with addition

`Suggests` is correct. The spike established viability on both tested
platforms, and `Suggests` is the standard R pattern for optional parallel
backends.

Required addition for the spec: define what happens when a user sets
`workers > 1` (or equivalent) and `mirai` is not installed. The failure mode
must be a loud error, not a silent fallback to sequential execution. "Strict
contracts beat silent convenience" applies here. A user who expects parallel
execution and gets sequential behavior without warning may interpret sweep
timing results incorrectly.

The `cmake` prerequisite for source installs of `nanonext` on Ubuntu/WSL
belongs in the package installation documentation, not the DESCRIPTION file.

### Consequence 2: Transport Constraint — Accepted with strengthened `everywhere()` language

The RFC proposes that "the first v0.1.8 implementation may ship explicit
precomputed payloads to workers." This is accepted. The RFC also states "v0.1.8
must not define a pre-fetch-only architecture." This is also accepted.

Strengthened constraint from the SPIKE-2/SPIKE-6 data:

> When a precomputed feature payload is used, it must be sent to workers once
> via `everywhere()` at daemon startup, not serialized individually per
> candidate dispatch. The v0.1.8 spec must make this explicit, not leave it as
> an implementation detail.

This distinction should also be preserved for future transport paths: mori
shared-memory objects would also be registered once, not passed per-task.
Worker-local DuckDB reads open once per daemon, not once per candidate. The
pattern is consistent: one-time setup at the transport layer, then cheap
per-candidate execution.

### Consequence 3: Cache Constraint — Accepted with symmetry requirement

"Package-level worker cache persistence may be used as an optimization only"
and "no candidate should rely on daemon affinity or warmed worker state to be
reproducible" are both accepted verbatim.

Added symmetry requirement for the spec:

> Two candidate evaluations with identical experiment identity, params, feature
> identities, snapshot identity, seed, and precomputed feature payload (or
> snapshot-backed lookup) must produce identical results regardless of which
> daemon processes them and regardless of execution order within the sweep.

This is stricter than "no daemon affinity" alone. It makes explicit that the
result must not depend on any ambient state: prior task residue, cache warmth,
or parallel dispatch ordering. This is the parallel analog of the existing
determinism contract for `ledgr_run()`.

### Consequence 4: Scale Constraint — Accepted

The list of what was not tested (intraday snapshot schema, pulse calendar at
intraday scale, fill timing, memory pressure, event ledger growth, metrics
over intraday event volume, warmup/scoring boundaries) is comprehensive and
should appear in the spec as a non-goals statement, not only in the RFC.

One additional untested dimension: the current snapshot model is structured
around daily bars. Intraday support would require changes to snapshot schema,
feature engine warmup semantics (bars-per-period vs. periods), and potentially
fill model assumptions. The spec should be explicit that EOD-focus means the
snapshot and fill model are not designed for sub-day bar frequencies.

### Consequence 5: Sequential-First — Accepted with boundary clarification

"Sequential sweep can ship first" and "parallel execution can be added behind
the same candidate-evaluation boundary" are both accepted.

Clarification required for "candidate-evaluation boundary": the parallelism
entry point is the candidate dispatch loop — the iteration over parameter grid
rows that produces one fold execution per candidate. Parallelism applies at
this level. Inside a single candidate's fold execution, the core remains
sequential. The spec should state this explicitly so the architecture is not
ambiguous about where worker handoff occurs.

The spec should also require that for a deterministic strategy:

> `ledgr_sweep()` in sequential mode and `ledgr_sweep()` with parallel workers
> must produce identical candidate results for the same params, features,
> snapshot, and seed.

This is the sweep analog of the existing parity contract between `ledgr_run()`
and `ledgr_sweep()` in the roadmap and contracts.

---

## Responses to Review Questions

**Q1: Is `mirai` in `Suggests` the right dependency classification?**

Yes. The spike results justify `Suggests`. Required addition: the failure
mode when `workers > 1` and `mirai` is absent must be a loud error.

**Q2: Is explicit payload shipping acceptable as the first transport path?**

Yes, with the constraint that precomputed payloads are sent via `everywhere()`
at daemon startup, not per-candidate. The SPIKE-2 and SPIKE-6 data make
per-candidate serialization of large payloads a latent performance defect.

**Q3: Are worker-local DuckDB reads and `mori` shared-memory payloads the
right future transport paths to preserve?**

Yes. Both are viable from the spikes. Worker-local reads should carry the WAL
behavior caveat above. `mori` should be described as boundary-viable rather
than zero-copy-proven until read performance inside a worker is measured.

**Q4: Should the v0.1.8 spec require parallel execution, or only require that
the candidate-evaluation boundary is parallel-ready?**

Parallel-ready boundary only. The fold-core split is the dominant risk and the
prerequisite for parallelism being correct. Requiring parallel execution in
v0.1.8 would couple the two changes and increase the risk surface. Sequential
first, parallel-ready internals is the right sequencing.

**Q5: Is the cache-warming conclusion strong enough?**

Yes, but add the symmetry requirement from Consequence 3 above. "Optimization
yes, correctness no" is the right framing. The spec should make the equivalence
guarantee explicit: same inputs, same result, regardless of daemon assignment.

---

## Additional Constraints for the v0.1.8 Spec

These are not in the RFC but fall directly from the findings.

### A. Seed and RNG contract for parallel sweep

If a strategy uses a random draw (e.g., for random selection among equal
signals), seeds must be passed explicitly as part of the candidate evaluation
inputs, not inherited from daemon global RNG state. Two candidates evaluated on
the same daemon should not share RNG state across evaluations. The spec should
specify how per-candidate seeds are managed.

### B. Output aggregation is orchestrator responsibility

Worker tasks should return structured candidate result objects. Aggregation
into the sweep result table is the responsibility of the orchestrator (the
dispatch loop), not the workers. Workers must not write to shared state,
shared files, or shared databases during evaluation. This keeps the design
correct for both sequential and parallel execution.

### C. Sequential/parallel equivalence is a contract, not a goal

The roadmap and contracts already state that `ledgr_run()` and
`ledgr_sweep()` must agree on feature values, fill prices, and equity where
retained. The spec should add:

> Sequential `ledgr_sweep()` and parallel `ledgr_sweep()` must agree on all
> candidate results for the same params, features, snapshot, and seed. Parallel
> execution is not permitted to change candidate results, only scheduling.

This closes the loop on the cache-warming constraint: if results must be
execution-order-independent, then any cache warming that produces a different
result is by definition a bug, not an optimization.

---

## Proposed Spec Text

Replacing the RFC's proposed paragraph with a more precise version incorporating
all spike findings including SPIKE-7 and SPIKE-8:

> `mirai` is the preferred optional backend for parallel sweep execution and
> belongs in `Suggests`. Sequential sweep must work without `mirai`; requesting
> `workers > 1` without `mirai` installed is an error, not a silent fallback.
>
> When precomputed feature payloads are used, they must be sent to workers once
> via `everywhere()` at daemon startup, not serialized per candidate. Worker-local
> read-only DuckDB access remains a valid future transport path. `mori::share()`
> objects are boundary-compatible with mirai workers and reduce `everywhere()`
> transport cost; worker-side lookup is slower than plain in-process matrices for
> the tested access patterns, so `mori` is suited to transport-bandwidth scenarios,
> not high-frequency per-pulse access. v0.1.8 must not bake in a pre-fetch-only
> architecture.
>
> Parallel sweep must include a worker setup phase before candidate dispatch. The
> setup phase attaches declared package dependencies and sets runtime options. It
> must not transmit arbitrary helper objects via `.GlobalEnv` assignment; helper
> objects that are not package functions must be explicit task payloads or
> deliberate package-registry entries. Tier 3 ambient state is not made available
> to workers.
>
> Package-level worker caches may be used as optimizations only. Reproducibility
> comes exclusively from explicit inputs: experiment identity, params, strategy
> and feature identities, snapshot identity, precomputed feature payload or
> snapshot-backed lookup, and seed where applicable. Two candidate evaluations
> with the same inputs must produce the same result regardless of which daemon
> processes them or in what order.
>
> Sequential and parallel sweep must produce identical candidate results for the
> same inputs. Parallelism applies at the candidate dispatch loop, not inside the
> fold core.
>
> v0.1.8 remains EOD-focused. Intraday-like payload measurements confirm that
> transport is not immediately infeasible at larger scales; they do not constitute
> intraday support. The snapshot schema, pulse calendar, fill model, and warmup
> semantics are not designed for sub-day bar frequencies.

---

## Open Items for the Spike Record

Two gaps in the spike findings that should be closed before or during v0.1.8
spec work:

1. **SPIKE-3 / SPIKE-6 mori read performance**: Confirm whether mori worker
   access is measurably faster than equivalent plain-serialized access for a
   large payload. This is needed before promoting mori as a "high-performance"
   path in user documentation.

2. **SPIKE-4 WAL behavior**: Confirm that concurrent read-only opens of a
   sealed DuckDB snapshot do not create WAL files. This guards the
   worker-local transport path on read-only or shared-storage environments.

These do not block the v0.1.8 spec from opening but should be resolved before
the worker-local DuckDB transport path is exposed to users.

---

## Addendum: SPIKE-7 And SPIKE-8 Findings

**Date:** 2026-05-13

SPIKE-7 and SPIKE-8 were executed as follow-ups from the review items above.
SPIKE-7 resolves open item 1. SPIKE-8 adds a new binding constraint not
covered by the original RFC. Open item 2 (WAL behavior) remains open.

### SPIKE-7: mori Transport vs. Access Performance

SPIKE-7 measured mori setup time and worker lookup time against a plain
serialization baseline for two large shapes (EOD 250 instruments × 2520 bars
× 50 features, ~241 MB; intraday-like 100 instruments × 7800 bars × 50
features, ~298 MB).

| Platform | Shape | Plain setup | Plain lookup | mori setup | mori lookup |
|---|---|---:|---:|---:|---:|
| Windows | EOD moderate / many features | 1.050s | 0.200s | 0.700s | 0.570s |
| Windows | Intraday feature-width stress | 1.200s | 0.210s | 0.700s | 0.670s |
| Ubuntu/WSL | EOD moderate / many features | 1.278s | 0.179s | 1.063s | 0.465s |
| Ubuntu/WSL | Intraday feature-width stress | 1.294s | 0.186s | 1.193s | 0.606s |

mori serialized payload size: ~0.19 MB (EOD) and ~0.08 MB (intraday), versus
240-298 MB for plain serialization. Checksums matched between paths.

**What the data shows:**

The 1,200-3,700x reduction in serialized size is the dominant mori benefit. It
comes from shipping a shared-memory handle rather than the data. One-time
`everywhere()` setup is modestly faster with mori because it sends a tiny
handle instead of hundreds of megabytes.

Worker lookup is 2.6-3.3x slower with mori than with plain matrices on both
platforms. The mechanism is likely indirection: plain matrices deserialized
into worker process memory are accessed with cache-local pointer arithmetic;
mori shared-memory access goes through handle resolution, which adds latency
per read. Under fold-core execution, feature lookups happen once per pulse per
feature per candidate — exactly the high-frequency case where this overhead
compounds.

**Resolution of open item 1:**

mori is not a high-performance transport path for per-access lookups. It is a
transport-bandwidth path: beneficial when `everywhere()` payload size dominates
(first-time worker setup for very large feature payloads, or frequent
re-setup), suboptimal when per-pulse lookup frequency dominates (fold core
execution against a feature cache already in process memory).

The spec text for mori should reflect this distinction:

> `mori::share()` objects are boundary-compatible with `mirai` workers and
> reduce one-time `everywhere()` transport cost by serializing handles rather
> than data. Worker-side access is slower than plain in-process matrices for
> tested lookup patterns. `mori` is therefore suited to scenarios where
> transport bandwidth or memory pressure dominates, not to high-frequency
> per-pulse feature access. It remains an optional future transport path, not a
> required or recommended default for v0.1.8.

### SPIKE-8: Tier 2 Worker Environment Initialization

SPIKE-8 tested how `mirai::everywhere()` prepares worker environments for
Tier 2 strategy and feature code that depends on external packages, options,
and helper objects. Results were identical on Windows and Ubuntu/WSL.

| Pattern | Without setup | After `everywhere(library(pkg))` |
|---|---|---|
| Package-qualified calls (`jsonlite::toJSON()`, `dplyr::mutate()`) | pass | n/a |
| Unqualified calls (`mutate()`, `SMA()`) | fail | pass |
| Runtime options set in setup block | n/a | persists to later tasks |
| Helper function assigned in setup block | n/a | does not persist (cleanup = TRUE) |

**What the data shows:**

The `cleanup = TRUE` default structurally enforces the tier boundary. Helper
objects assigned in `everywhere()` setup blocks do not persist to later tasks.
Package functions and options persist. This means:

- Tier 2 code using package-qualified calls (`pkg::fn()`) works without
  explicit setup if the package is installed on the worker library path.
- Tier 2 code using unqualified calls requires an explicit `everywhere({
  library(pkg) })` step before candidate dispatch.
- Tier 2 code relying on arbitrary helper objects assigned outside a package
  will fail in parallel workers unless those objects are transmitted explicitly
  as candidate task payloads or registered in a deliberate package-level
  registry.
- Tier 3 patterns (closures capturing ambient objects that are not package
  functions and not explicit payloads) fail naturally, without ledgr needing to
  detect them in preflight. The mirai cleanup default does this enforcement for
  free.

**New binding constraint for the v0.1.8 spec:**

Parallel sweep must include an explicit worker setup phase executed before
candidate dispatch. The setup phase attaches package dependencies and sets
runtime options. It must not rely on `.GlobalEnv` assignment for helper
objects.

Tier 2 preflight, when run before a parallel sweep, should surface a package
dependency list sufficient to construct the worker setup phase. The current
preflight tier classification is a runtime check; for parallel sweep it may
need to become a dependency declaration. Whether that declaration is explicit
(a `packages` argument to `ledgr_sweep()`) or inferred (from a preflight dry
run in the main session) is a spec decision, but the information must be
available before workers are dispatched.

The following language should be added to the v0.1.8 spec:

> Parallel sweep must include a worker setup phase before candidate dispatch.
> The setup phase must: (a) attach declared package dependencies via
> `everywhere({ library(pkg) })`; (b) set any runtime options required by
> Tier 2 code. The setup phase must not transmit arbitrary helper objects via
> `.GlobalEnv` assignment; helper objects that are not package functions must
> be transmitted as explicit task payloads or registered through deliberate
> package-level mechanisms. Tier 3 ambient state is not made available to
> workers and must not be papered over by expanding the setup phase.

### Updated Open Items

Open item 1 (mori read performance) is resolved by SPIKE-7.

Open item 2 (DuckDB WAL behavior) is resolved by a targeted SPIKE-4 rerun
with an explicit side-file probe. Before and after concurrent read-only access
from 8 workers, only `snapshot.duckdb` was present on disk — no `.wal`, temp,
lock, or other side files were created on either Windows or Ubuntu/WSL. Query
results remained consistent across all worker tasks.

Architecture consequence: worker-local read-only DuckDB connections do not
violate sealed-snapshot expectations. The transport path remains valid for
v0.1.8+. The only remaining caveat is connection lifecycle: a per-daemon
connection opened once at setup via `everywhere()` is preferable to a fresh
open per candidate task, as noted in the original constraint discussion.

All spike record open items are now closed.
