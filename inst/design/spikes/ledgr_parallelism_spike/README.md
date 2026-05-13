# ledgr Parallelism Spike

**Status:** Pre-spec investigation. Results feed the v0.1.8 parallel sweep
design before the spec packet is opened.
**Scope:** Platform viability, serialization behavior, and scale-shape limits
of mirai and mori as the intended parallel backend for `ledgr_sweep()`.
**Non-scope:** ledgr implementation work, fold-core refactor, v0.1.8 API
design.

The first six spikes below answer concrete unknowns identified during a focused mirai
analysis. Each spike is a short, self-contained investigation - not a feature
implementation. Results are recorded in the "Findings" section at the bottom of
this document.

SPIKE-7 and SPIKE-8 are follow-ups from review. The first pass confirmed that
`mori::share()` crosses the `mirai` worker boundary, but it did not measure
whether `mori` is actually more efficient than plain serialized payloads. It
also did not test how `mirai` worker initialization should handle Tier 2
strategy or feature code that depends on external packages.

A concise decision-oriented summary is available in `summary_report.md`.

SPIKE-6 is deliberately not a promise of intraday support. It measures whether
v0.1.8 sweep data-movement choices leave a plausible future path for intraday
workloads and wide feature maps.

Platform matrix for all spikes: **Windows 11 (native R)** and **Ubuntu/WSL**.
Spikes that fail on one platform should record the failure mode, not be
abandoned.

---

## SPIKE-1: mirai Daemon Lifecycle on Windows and Ubuntu/WSL

**Effort:** 0.5 day
**Blocking:** All other spikes; dependency classification decision.

**Question:** Can mirai daemons start, receive tasks, and exit cleanly on both
platforms without manual PATH or network configuration?

**Tasks:**
1. Install mirai. Verify it installs from CRAN without compilation errors on
   Windows (native) and Ubuntu/WSL.
2. Run `daemons(4)`. Confirm four background Rscript processes start and are
   visible in the process list.
3. Submit a trivial `mirai(1 + 1)` and collect the result. Confirm `$data == 2`.
4. Run `everywhere(library(ledgr))`. Confirm ledgr loads on all daemons without
   error.
5. Run `daemons(0)`. Confirm all daemon processes terminate cleanly.
6. Repeat with `daemons(4, dispatcher = FALSE)` (no dispatcher). Note any
   behavioral differences.

**Acceptance criteria:**
- `daemons(4)` and `daemons(0)` cycle cleanly at least three consecutive times
  without orphaned processes or socket errors.
- `everywhere(library(ledgr))` completes without error on both platforms.
- No manual Rscript PATH configuration is required on Windows.

**Decision gate:** If daemon lifecycle is unreliable on Windows, mirai cannot
be `Suggests`. Document the failure mode and record the dependency
classification as user-managed only.

---

## SPIKE-2: Serialization Cost for ledgr-Sized Payloads

**Effort:** 0.5 day
**Blocking:** Decision on pre-fetch vs. mori for feature sharing; whether
`everywhere()` is viable for large feature payloads.

**Question:** What are the actual serialization size and round-trip time for
the objects ledgr would send to mirai workers at realistic sweep scale?

**Tasks:**
1. Construct a synthetic precomputed feature payload at two scales:
   - Small: 20 instruments x 504 daily bars (2 years) x 3 indicators
   - Medium: 100 instruments x 2520 daily bars (10 years) x 5 indicators
2. Measure serialized size: `length(serialize(obj, NULL))` for both.
3. Send the small payload to a single daemon via `mirai(..., features = obj)`.
   Measure wall time from dispatch to `m$data` being available.
4. Send via `everywhere(shared_features <<- obj)` (once to all 4 daemons).
   Measure wall time for the `everywhere()` synchronization point.
5. Repeat steps 3-4 for the medium payload.
6. Send a bar data matrix at realistic scale: 100 instruments x 2520 bars x
   5 OHLCV columns (plain numeric matrix). Measure size and round-trip time.

**Record:**
- Serialized size in MB for each payload
- Round-trip time in seconds for per-task send and for `everywhere()` send
- Whether `everywhere()` is fast enough for a one-time pre-dispatch setup step

**Decision gate:** If medium-scale payloads take more than ~5 seconds to send
via `everywhere()`, the pre-fetch pattern is viable but the mori zero-copy path
becomes important for performance. Record the threshold and feed into the
SPIKE-3 decision.

---

## SPIKE-3: mori::share() Cross-Process Semantics with mirai

**Effort:** 0.5-1 day
**Blocking:** mori dependency classification; zero-copy pattern in UX doc.

**Question:** Does a `mori::share()` object survive mirai's NNG serialization
boundary and arrive usable in a worker process?

**Context:** The UX doc states that mori objects are "indistinguishable from
plain R objects at the API boundary." This is true at the ledgr API surface.
Whether it is true at mirai's NNG serialization layer is unknown. mori objects
backed by external shared-memory pointers may require `register_serial()`
registration in mirai to cross the process boundary.

**Tasks:**
1. Install mori. Verify it installs on Windows (native) and Ubuntu/WSL. Record
   any failure.
2. Create a `mori::share()` object from a plain numeric matrix.
3. Attempt to send it to a mirai worker via `mirai(..., x = shared_obj)`.
4. In the worker, attempt to read from `x` (e.g., `x[1, 1]`). Check whether
   the result is correct or an error.
5. If step 4 errors with a serialization or external-pointer error, attempt to
   register a custom serializer:
   ```r
   mirai::register_serial(
     class = <mori class name>,
     sfunc = <serialize to raw>,
     ufunc = <reconstruct from raw>
   )
   ```
   and repeat steps 3-4.
6. If step 5 is not possible (mori does not expose a serializable handle),
   record that the zero-copy pattern is not supported via standard mirai
   dispatch.
7. Measure read performance inside the worker: is access to the mori object
   zero-copy (constant time) or does it materialize a copy?

**Acceptance criteria:**
- The mori object is readable in the worker with correct values.
- Read performance is faster than round-trip serialization (i.e., there is
  an actual zero-copy benefit).
- Result is confirmed on both platforms.

**Decision gate:**
- If mori works out of the box: document the mechanism and add mori to
  `Suggests`, contingent on CRAN availability.
- If mori requires `register_serial()`: write the shim, confirm it works, and
  document the registration requirement for users.
- If mori cannot cross the process boundary on either platform: remove the
  zero-copy pattern from the UX doc. Fall back to `everywhere()` with plain
  serialization and accept the SPIKE-2 overhead cost.

---

## SPIKE-4: DuckDB Concurrent Read-Only Access from Multiple mirai Workers

**Effort:** 0.5 day
**Blocking:** Worker bar-data access design (pre-fetch vs. per-worker
read-only connection).

**Question:** Can multiple mirai worker processes simultaneously open the same
sealed snapshot `.duckdb` file in `read_only = TRUE` mode without locking
errors, WAL contention, or data corruption?

**Context:** DuckDB allows concurrent readers on the same file, but its
behavior under multi-process concurrent access on Windows (which uses different
file locking semantics than Linux) is the unknown.

**Tasks:**
1. Create a small test DuckDB file with a bars table (~10k rows).
2. Spawn 4 mirai daemons.
3. Submit 8 tasks simultaneously, each opening the same DuckDB file with
   `read_only = TRUE` and running a simple aggregation query.
4. Collect results. Verify all 8 tasks complete without error and return
   correct values.
5. Repeat with 8 workers hitting the file concurrently.
6. Test on both platforms.

**Record:**
- Whether concurrent read-only access succeeds without errors.
- Any contention-related delays or warnings.
- Whether WAL file artifacts are created and cleaned up correctly.

**Decision gate:** If concurrent read-only access is unreliable on Windows,
the per-worker connection approach is not viable on that platform and pre-fetching
all bar data before dispatch is the only correct design. Record the platform
behavior and update the architecture doc accordingly.

---

## SPIKE-5: Package-Level Environment Survival Across mirai Tasks

**Effort:** 0.5 day
**Blocking:** Feature cache cross-task sharing design; whether daemon cache
warming is a real optimization.

**Question:** Does mirai's `cleanup = TRUE` (default) restore package-level
environments between tasks on the same daemon, or do they persist across tasks?

**Context:** `.ledgr_feature_cache_registry` is a package-level environment
created at load time (`new.env(parent = emptyenv())` stored in a package
binding). If it persists between tasks on the same daemon, features computed
during task N are available without resending during task N+1 on the same
daemon. If cleanup wipes it, the optimization does not exist.

**Tasks:**
1. Create a minimal test package (or use ledgr directly) with a package-level
   environment `test_env <- new.env(parent = emptyenv())`.
2. Submit task 1 to a daemon: `mirai({ test_env$x <- 42; TRUE })`.
3. Submit task 2 to the **same** daemon: `mirai({ test_env$x })`.
4. Collect result of task 2. If it returns `42`, the environment persists.
   If it returns `NULL`, cleanup wiped it.
5. Repeat with `cleanup = FALSE` as a control.
6. Verify that `everywhere(library(ledgr))` + subsequent tasks preserves
   `.ledgr_feature_cache_registry` entries written during a prior task.

**Acceptance criteria:**
- A definitive answer: package-level environments either do or do not persist
  across tasks under `cleanup = TRUE`.

**Decision gate:**
- If they persist: document the daemon cache-warming optimization as confirmed.
  Design the precomputed feature sharing strategy to exploit it.
- If they do not persist: remove the optimization from the design. The
  precomputed feature payload must be pre-loaded via `everywhere()` at daemon
  startup, or resent with each task (accepting the SPIKE-2 overhead).

---

## SPIKE-6: Scale-Shape Probe for Sweep Data Movement

**Effort:** 0.5-1 day
**Blocking:** v0.1.8 precompute/transport shape; future intraday feasibility
assessment.

**Question:** Do the v0.1.8 sweep data-movement assumptions leave a plausible
path for larger feature maps and future intraday workloads, or do they imply a
different transport strategy before the fold-core spec is cut?

**Context:** EOD scale and intraday scale stress different parts of the
architecture. Testing only a small number of simulated instruments with a few
features does not represent the width created by feature maps and indicator
parameter sweeps. Intraday is not a v0.1.8 feature commitment, but v0.1.8 should
not accidentally choose a payload or cache shape that makes future intraday work
implausible.

**Non-goal:** This spike does not add intraday support. It only measures
synthetic payload shapes that approximate future pressure points.

**Synthetic shapes:**
1. EOD, many instruments, few features:
   - 1000 instruments x 2520 daily bars x 5 features
2. EOD, moderate instruments, many features:
   - 250 instruments x 2520 daily bars x 50 features
3. Intraday, moderate instruments, realistic features:
   - 100 instruments x 100 trading days x 390 one-minute bars/day x 10 features
4. Intraday, feature-width stress:
   - 100 instruments x 20 trading days x 390 one-minute bars/day x 50 features

**Tasks:**
1. Build plain-R synthetic payloads representing the four shapes above. Use a
   simple long or nested-list representation close to the current feature
   precompute discussion, and record the chosen representation.
2. Measure object size with `object.size()` and serialized size with
   `length(serialize(obj, NULL))`.
3. Send each payload to one mirai worker and measure dispatch-to-result wall
   time.
4. Send each payload with `everywhere()` to four workers and measure the
   synchronization time.
5. If mori is viable from SPIKE-3, repeat the largest feasible shape with
   `mori::share()` and measure whether worker access avoids a copy.
6. Measure a simple lookup loop inside a worker: read all features for one
   instrument at one timestamp, and read one feature across all instruments at
   one timestamp.
7. Record memory growth and any failure modes, including allocation errors,
   slow serialization, or worker crashes.

**Record:**
- Chosen payload representation
- Object size and serialized size for each shape
- Per-task send time and `everywhere()` send time
- Lookup timings for row-like and column-like access patterns
- Whether the shape suggests pre-fetch, worker-local DuckDB reads, shared
  memory, or a hybrid strategy

**Decision gate:** If large feature-width or intraday-like payloads are too
large or slow to ship with plain serialization, v0.1.8 should avoid baking in a
pre-fetch-only design and should keep worker-local DuckDB reads or shared-memory
transport available as future architecture paths.

---

## SPIKE-7: mori Shared-Memory Efficiency Probe

**Effort:** 0.5-1 day
**Blocking:** Whether `mori` can be called a high-performance transport path in
the v0.1.8 spec or public-facing design language.

**Question:** Does `mori::share()` provide a measurable worker-side efficiency
benefit over plain serialized payloads for ledgr-scale feature payloads, or is
it only boundary-viable?

**Context:** SPIKE-3 confirmed that `mori::share()` objects can cross the
`mirai` process boundary on Windows and Ubuntu/WSL without a custom serializer.
That proves compatibility, not performance. Claude review correctly noted that
the current record does not measure `mori` read performance against a
plain-serialization baseline.

**Tasks:**
1. Reuse the SPIKE-6 synthetic payload representation for at least two shapes:
   - EOD moderate instruments / many features;
   - intraday feature-width stress.
2. Construct equivalent plain-R and `mori::share()` payloads. Record object
   size, shared-object metadata, and setup time for each.
3. Send the plain payload to workers via the same path used in SPIKE-6 and run
   repeated lookup loops inside the worker:
   - all features for one instrument at one timestamp;
   - one feature across all instruments at one timestamp;
   - a small contiguous time window for one instrument across all features.
4. Send or register the `mori::share()` payload with workers and run the same
   lookup loops.
5. Measure wall time and memory growth for setup and lookup phases separately.
6. Confirm results on Windows native R and Ubuntu/WSL.

**Record:**
- Plain payload setup time and lookup timings
- `mori::share()` setup time and lookup timings
- Worker memory growth for both paths if measurable
- Whether `mori` avoids a material copy or merely passes through the boundary
- Any API constraints needed to use `mori` safely from sweep workers

**Decision gate:** If `mori` is materially faster or lower-memory for the tested
payloads, keep it as the preferred future shared-memory transport path. If it
is only boundary-compatible but not faster, keep it optional and avoid calling
it a high-performance path until a stronger benchmark justifies that language.

---

## SPIKE-8: Tier 2 Worker Environment Initialization

**Effort:** 0.5-1 day
**Blocking:** v0.1.8 parallel sweep worker setup contract for Tier 2 strategies
and feature providers.

**Question:** Can `mirai::everywhere()` or a related worker setup pattern
reliably prepare worker environments for Tier 2 strategy and feature code that
depends on external packages, package-qualified calls, S3/S4 method
registration, options, or helper objects?

**Context:** Legacy parallel backends often fail because worker namespaces do
not match the main session. A package may be installed locally but not loaded
on the worker; unqualified calls may fail; S3/S4 methods may not be registered;
closure environments may point at helper objects that were never exported.

For ledgr, this matters because v0.1.8 sweep must preserve the reproducibility
tier boundary:

- Tier 1 should need only base/recommended R and ledgr worker setup.
- Tier 2 should have explicit worker setup for declared package dependencies.
- Tier 3 unresolved ambient state should remain rejected, not papered over by
  exporting arbitrary objects to workers.

**Tasks:**
1. Build minimal Tier 2 examples that exercise:
   - package-qualified calls, e.g. `jsonlite::toJSON()`;
   - attached-package calls after `library(TTR)` or `library(dplyr)`;
   - S3 method dispatch from a non-base package;
   - a package option or runtime setting needed by a worker;
   - an explicitly provided helper object or helper function.
2. Run each example on workers with no setup. Record which fail and how.
3. Run each example after `mirai::everywhere(library(pkg))` setup. Record which
   succeed.
4. Run a stricter setup block:
   ```r
   mirai::everywhere({
     library(ledgr)
     library(jsonlite)
     library(TTR)
     options(...)
     helper <- ...
     TRUE
   })
   ```
   Record whether functions, methods, options, and helper objects are visible to
   later candidate tasks.
5. Test whether package-qualified calls like `jsonlite::toJSON()` work without
   `library(jsonlite)` when the package is installed in the worker library path.
6. Test on Windows native R and Ubuntu/WSL.

**Record:**
- Which Tier 2 shapes work without setup
- Which shapes require `everywhere(library(pkg))`
- Whether S3/S4 methods require package attachment or only namespace loading
- Whether options and helper objects persist across later tasks
- Whether setup behavior differs by platform
- Recommended v0.1.8 worker setup contract

**Decision gate:** If `everywhere()` reliably prepares worker environments, the
v0.1.8 spec should define an explicit worker setup phase before candidate
dispatch. Tier 2 preflight should expose enough dependency information for that
setup phase. If setup is unreliable, parallel sweep should either restrict Tier
2 support or require a stricter user-provided worker setup contract.

---

## Decision Gates Summary

| Spike | Primary decision |
|---|---|
| SPIKE-1 | mirai dependency classification: `Suggests` vs. user-managed only |
| SPIKE-2 | Pre-fetch payload size budget; whether `everywhere()` is fast enough |
| SPIKE-3 | mori dependency classification and zero-copy pattern validity |
| SPIKE-4 | Per-worker read-only DuckDB connection vs. pre-fetch-only design |
| SPIKE-5 | Daemon cache-warming optimization: confirmed or removed from design |
| SPIKE-6 | Scale-shape limits for feature-width and future intraday payloads |
| SPIKE-7 | Whether mori is high-performance, or only boundary-compatible |
| SPIKE-8 | Worker setup contract for Tier 2 package-dependent code |

The first six spikes must complete before the v0.1.8 spec packet is opened and
the parallel sweep design is finalized. SPIKE-7 is a follow-up performance
probe from Claude review. It should complete before v0.1.8 describes `mori` as
a high-performance transport path, but it does not block treating `mori` as
boundary-compatible and optional. SPIKE-8 is a follow-up worker-environment
probe. It should complete before the v0.1.8 spec finalizes parallel Tier 2
support, but it does not reopen the first-six-spike completion criteria.

---

## Findings

Spike episode scripts live under
`dev/spikes/ledgr_parallelism_spike/`. Raw `.rds` result artifacts are local
scratch output and are not committed.

Runs completed on Windows native R and Ubuntu/WSL after installing `cmake` in
the Ubuntu distribution. WSL package state for the completed run: `mirai` 2.7.0,
`mori` 0.2.0, DBI 1.3.0, duckdb 1.5.2, ledgr 0.1.7.9.

### SPIKE-1

| Platform | Result | Notes |
|---|---|---|
| Windows native R | pass | Three `daemons(4)` / `daemons(0)` cycles completed; `everywhere(library(ledgr))` succeeded; `dispatcher = FALSE` trivial task returned 2. |
| Ubuntu/WSL | pass | Three `daemons(4)` / `daemons(0)` cycles completed; `dispatcher = FALSE` trivial task returned 2. Requires `cmake` for the `nanonext` source build. |

**Dependency decision:** `mirai` can be a `Suggests` dependency for Windows
native R and Ubuntu/WSL. WSL setup should document `cmake` as a system
prerequisite when installing from source.

### SPIKE-2

| Platform | Payload | Object size (MB) | Serialized size (MB) | Per-task send (s) | everywhere() send (s) |
|---|---|---:|---:|---:|---:|
| Windows | Small (20 instr x 504 bars x 3 features) | 0.238 | 0.232 | 0.00 | 0.00 |
| Windows | Medium (100 instr x 2520 bars x 5 features) | 9.654 | 9.622 | 0.01 | 0.04 |
| Windows | Bar matrix proxy (100 instr x 2520 bars x 5 columns) | 9.654 | 9.622 | 0.01 | 0.03 |
| Ubuntu/WSL | Small (20 instr x 504 bars x 3 features) | 0.238 | 0.232 | 0.002 | 0.003 |
| Ubuntu/WSL | Medium (100 instr x 2520 bars x 5 features) | 9.654 | 9.622 | 0.030 | 0.048 |
| Ubuntu/WSL | Bar matrix proxy (100 instr x 2520 bars x 5 columns) | 9.654 | 9.622 | 0.018 | 0.032 |

**Decision:** Plain serialization is not a bottleneck at these EOD-sized
payloads on either tested platform. `everywhere()` is viable for one-time setup
at this scale.

### SPIKE-3

| Platform | Works out of the box | Requires register_serial | Cannot cross boundary |
|---|---|---|---|
| Windows native R | yes | no | no |
| Ubuntu/WSL | yes | no | no |

**mori dependency decision:** Keep `mori` as an optional boundary-compatible
transport candidate, not a hard prerequisite.

**Zero-copy pattern in UX doc:** The Windows result supports the pattern:
`mori::share()` objects are readable by `mirai` workers without a registration
shim. Ubuntu/WSL confirms the same behavior.

### SPIKE-4

| Platform | Concurrent reads succeed | Notes |
|---|---|---|
| Windows native R | yes | Eight concurrent worker tasks opened the same DuckDB file read-only and returned consistent counts and volume sums. No WAL, temp, or lock side files were created; before and after artifact lists were both `snapshot.duckdb`. |
| Ubuntu/WSL | yes | Eight concurrent worker tasks opened the same DuckDB file read-only and returned consistent counts and volume sums. No WAL, temp, or lock side files were created; before and after artifact lists were both `snapshot.duckdb`. |

**Worker bar-data design:** Concurrent read-only DuckDB access is viable on
both tested platforms for the tested shape. The v0.1.8 design should not rule out
worker-local read-only connections.

### SPIKE-5

| Platform | Global env persists across tasks | `.ledgr_feature_cache_registry` persists |
|---|---|---|
| Windows | no | yes |
| Ubuntu/WSL | no | yes |

**Cache-warming optimization:** Package namespace registries can survive across
tasks on the same daemon even when global environment state is cleaned.
Daemon cache warming remains a plausible optimization, but the v0.1.8 design
should not depend on it for correctness.

### SPIKE-6

| Platform | Shape | Representation | Object size (MB) | Serialized size (MB) | Per-task send (s) | everywhere() send (s) | Lookup notes |
|---|---|---|---:|---:|---:|---:|---|
| Windows | EOD many instruments / few features | list of feature matrices | 96.500 | 96.217 | 0.19 | 0.40 | Lookup probe returned immediately at timer resolution. |
| Windows | EOD moderate instruments / many features | list of feature matrices | 241.133 | 240.513 | 0.52 | 1.19 | Lookup probe returned immediately at timer resolution. |
| Windows | Intraday moderate instruments / realistic features | list of feature matrices | 297.620 | 297.563 | 0.65 | 1.58 | Lookup probe returned immediately at timer resolution. |
| Windows | Intraday feature-width stress | list of feature matrices | 297.887 | 297.624 | 0.64 | 1.63 | Lookup probe returned immediately at timer resolution. |
| Ubuntu/WSL | EOD many instruments / few features | list of feature matrices | 96.500 | 96.217 | 0.163 | 0.304 | Lookup probe returned immediately at timer resolution. |
| Ubuntu/WSL | EOD moderate instruments / many features | list of feature matrices | 241.133 | 240.513 | 0.428 | 0.762 | Lookup probe returned immediately at timer resolution. |
| Ubuntu/WSL | Intraday moderate instruments / realistic features | list of feature matrices | 297.620 | 297.563 | 0.426 | 1.066 | Lookup probe returned immediately at timer resolution. |
| Ubuntu/WSL | Intraday feature-width stress | list of feature matrices | 297.887 | 297.624 | 0.575 | 1.091 | Lookup probe returned immediately at timer resolution. |

**Scale-shape recommendation:** Plain serialization remains feasible for the
tested Windows and Ubuntu/WSL shapes, including roughly 300 MB intraday-like
synthetic payloads, but these sizes are large enough that v0.1.8 should keep
worker-local DuckDB reads and shared-memory transport open as future
architecture paths. Do not bake in a pre-fetch-only design.

### SPIKE-7

Payloads were preloaded into ledgr's package-level worker registry before
lookup so the benchmark does not rely on `.GlobalEnv` persistence.

| Platform | Shape | Plain serialized MB | Plain setup (s) | Plain lookup (s) | mori serialized MB | mori share + setup (s) | mori lookup (s) |
|---|---|---:|---:|---:|---:|---:|---:|
| Windows | EOD moderate / many features | 240.513 | 1.050 | 0.200 | 0.190 | 0.700 | 0.570 |
| Windows | Intraday feature-width stress | 297.624 | 1.200 | 0.210 | 0.081 | 0.700 | 0.670 |
| Ubuntu/WSL | EOD moderate / many features | 240.513 | 1.278 | 0.179 | 0.190 | 1.063 | 0.465 |
| Ubuntu/WSL | Intraday feature-width stress | 297.624 | 1.294 | 0.186 | 0.081 | 1.193 | 0.606 |

Checksums matched between plain and `mori` paths for all measured shapes.

**mori performance decision:** `mori` is boundary-compatible and greatly reduces
serialized payload size. It modestly reduces one-time setup cost in this probe,
but worker lookup was slower than plain matrices for the tested access pattern.
Do not describe `mori` as a proven high-performance path yet. Keep it optional
and reserve it for future transport work where setup cost or memory pressure,
not lookup speed, dominates.

### SPIKE-8

| Platform | Package-qualified calls without setup | Unqualified package calls without setup | After `everywhere(library(pkg))` | Options from strict setup | Helper object from strict setup |
|---|---|---|---|---|---|
| Windows native R | pass | fail | pass | persists | does not persist |
| Ubuntu/WSL | pass | fail | pass | persists | does not persist |

Package-qualified calls such as `jsonlite::toJSON()` and `dplyr::mutate()`
worked without attaching packages, assuming the package is installed on the
worker library path. Unqualified calls such as `mutate()` and `SMA()` failed
without setup and succeeded after `everywhere({ library(dplyr); library(TTR) })`.
S3 tibble class behavior was available after setup. Runtime options set in the
strict setup block persisted to later tasks. A helper function assigned in the
strict setup block did not persist to later tasks under default cleanup.

**Tier 2 worker setup decision:** Parallel Tier 2 support should include an
explicit worker setup phase for attached package dependencies and runtime
options. Package-qualified calls can work without attachment if the package is
installed, but unqualified Tier 2 calls require setup. Arbitrary helper objects
should not be smuggled through `.GlobalEnv`; they must be package functions,
explicit task payloads, or deliberate package-registry entries. Tier 3 ambient
state should remain rejected.
