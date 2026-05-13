# ledgr Parallelism Spike

**Status:** Pre-spec investigation. Results feed the v0.1.8 parallel sweep
design before the spec packet is opened.
**Scope:** Platform viability and serialization behavior of mirai and mori as
the intended parallel backend for `ledgr_sweep()`.
**Non-scope:** ledgr implementation work, fold-core refactor, v0.1.8 API
design.

The five spikes below answer concrete unknowns identified during a focused mirai
analysis. Each spike is a short, self-contained investigation — not a feature
implementation. Results are recorded in the "Findings" section at the bottom of
this document.

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
   - Small: 20 instruments × 504 daily bars (2 years) × 3 indicators
   - Medium: 100 instruments × 2520 daily bars (10 years) × 5 indicators
2. Measure serialized size: `length(serialize(obj, NULL))` for both.
3. Send the small payload to a single daemon via `mirai(..., features = obj)`.
   Measure wall time from dispatch to `m$data` being available.
4. Send via `everywhere(shared_features <<- obj)` (once to all 4 daemons).
   Measure wall time for the `everywhere()` synchronization point.
5. Repeat steps 3–4 for the medium payload.
6. Send a bar data matrix at realistic scale: 100 instruments × 2520 bars ×
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

**Effort:** 0.5–1 day
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
   and repeat steps 3–4.
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

## Decision Gates Summary

| Spike | Primary decision |
|---|---|
| SPIKE-1 | mirai dependency classification: `Suggests` vs. user-managed only |
| SPIKE-2 | Pre-fetch payload size budget; whether `everywhere()` is fast enough |
| SPIKE-3 | mori dependency classification and zero-copy pattern validity |
| SPIKE-4 | Per-worker read-only DuckDB connection vs. pre-fetch-only design |
| SPIKE-5 | Daemon cache-warming optimization: confirmed or removed from design |

All five spikes must complete before the v0.1.8 spec packet is opened and the
parallel sweep design is finalized.

---

## Findings

*Record results here as spikes are completed.*

### SPIKE-1

| Platform | Result | Notes |
|---|---|---|
| Windows 11 (native) | pending | |
| Ubuntu/WSL | pending | |

**Dependency decision:** pending

### SPIKE-2

| Payload | Size (MB) | Per-task send (s) | everywhere() send (s) |
|---|---|---|---|
| Small (20 instr × 2yr × 3 ind) | pending | pending | pending |
| Medium (100 instr × 10yr × 5 ind) | pending | pending | pending |
| Bar matrix (100 instr × 2520 bars) | pending | pending | pending |

**Decision:** pending

### SPIKE-3

| Platform | Works out of the box | Requires register_serial | Cannot cross boundary |
|---|---|---|---|
| Windows 11 (native) | pending | pending | pending |
| Ubuntu/WSL | pending | pending | pending |

**mori dependency decision:** pending
**Zero-copy pattern in UX doc:** pending

### SPIKE-4

| Platform | Concurrent reads succeed | Notes |
|---|---|---|
| Windows 11 (native) | pending | |
| Ubuntu/WSL | pending | |

**Worker bar-data design:** pending

### SPIKE-5

| Behavior | Result |
|---|---|
| Package-level env persists across tasks (cleanup = TRUE) | pending |
| Confirmed with .ledgr_feature_cache_registry | pending |

**Cache-warming optimization:** pending
