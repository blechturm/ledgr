# Sweep Mode Code Review

Pre-implementation readiness review of the current codebase against the sweep
mode execution requirements. Written before the sweep spec is opened. Intended
as a technical input to the planning cycle that scopes sweep execution.

## Scope

The review covers the R/ source files most relevant to sweep execution:
`backtest-runner.R`, `backtest.R`, `feature-cache.R`, `strategy-fn.R`,
`features-engine.R`, `pulse-context.R`, `experiment.R`, `run-store.R`,
`derived-state.R`, `ledger-writer.R`, `param-grid.R`.

Files reviewed as clean (no sweep concerns): `run-store.R`, `derived-state.R`,
`ledger-writer.R`, `pulse-context.R`, `experiment.R`, `features-engine.R`,
`param-grid.R`.

## Package-Level Shared Mutable Environments

Five environments are created at package load time and shared across all calls
in a session. In sequential sweep they are mostly harmless. In parallel sweep
they range from a correctness blocker to a performance consideration.

| File | Line | Name | Sweep risk |
|---|---|---|---|
| `backtest-runner.R` | 29 | `.ledgr_telemetry_registry` | **Blocker** — concurrent workers writing the same `run_id` corrupt each other's telemetry |
| `backtest-runner.R` | 30 | `.ledgr_preflight_registry` | Medium — start-time timestamps get crossed; affects timing metrics only |
| `feature-cache.R` | 1 | `.ledgr_feature_cache_registry` | Desirable but unsafe for concurrent writes — see feature cache section |
| `strategy-fn.R` | 2 | `ledgr_strategy_registry` | Low — written once at experiment build, read-only during runs |
| `backtest.R` | 365 | `.ledgr_backtest_lifecycle_registry` | Negligible — rate-limits one console message |

The telemetry registry is the sharpest edge. `ledgr_store_run_telemetry()`
stores into `.ledgr_telemetry_registry` keyed by `run_id`. The paired
`write_persistent_telemetry` closure reads it back out at fold end. Two
parallel workers hitting finalization concurrently will read each other's
telemetry. The stored telemetry for both runs will be wrong.

The fix is to route telemetry through the existing return path rather than a
side-channel registry. The registry exists because `write_persistent_telemetry`
is a closure that does not have a return channel back to the caller; removing
the registry requires refactoring that closure.

## Global RNG Mutation

`backtest-runner.R` line 403: `set.seed(runtime_seed)` mutates the global R
RNG state. In sequential sweep this is deterministic and correct. In fork-based
parallel (`parallel::mclapply`), each forked child has its own RNG copy and the
call is safe. In thread-based parallel (`future` with `multisession`), the call
races across workers.

Since `ledgr_run()` currently rejects non-NULL `seed` at the public boundary,
`runtime_seed` is effectively always NULL for new experiment-first runs and the
`set.seed()` call is a no-op in practice. This should be verified before any
parallelism work touches the runner.

## Fold / Output Handler Coupling

Two closures inside `ledgr_backtest_run_internal` write directly to DuckDB
over the same connection used by the fold loop:

- `write_persistent_telemetry` -- writes run telemetry at fold end
- `fail_run` -- writes FAILED status mid-fold on error

Both capture `con` from the outer runner frame. There is no fold-only code path
that does not write to DuckDB. This means:

1. You cannot run the fold in-memory and flush at the end without refactoring
   these two closures.
2. Parallel workers writing to the same `.duckdb` file will hit DuckDB write
   contention. `ledgr_open_duckdb_with_retry` was designed for sequential
   contention, not concurrent multi-process writes.

The `audit_log` execution mode already accumulates events in memory and flushes
in batches. Directing that flush to a per-worker temp database rather than the
shared snapshot database is mechanically feasible and would isolate writers.

## Feature Cache

`feature-cache.R` builds a session-global cache keyed by
`(snapshot_hash, instrument_id, indicator_fingerprint, engine_version,
start_ts, end_ts)`. For sweep mode this is a meaningful performance win: all
parameter variants in a sweep share the same snapshot and the same feature
definitions, so features are computed once and reused on every subsequent run.

The constraint: concurrent writes from live parallel workers are not
thread-safe. R environments have no locking primitives.

The correct parallel pattern is pre-fork population. Compute all feature series
before spawning workers, populate the cache, then fork. Workers read from their
copy-on-write cache page and never write to it (cache hits only). This requires
ensuring that every indicator/instrument combination the workers will request is
already cached before the fork point.

## Sequential Sweep: Unblocked Today

Sequential sweep -- looping `ledgr_run()` over a `ledgr_param_grid()` -- has
no correctness issues with the current code. The five shared environments behave
correctly when only one run executes at a time. The feature cache provides
automatic memoization across runs with no additional work. `param-grid.R` is
already a clean data structure ready to drive a loop.

Sequential sweep execution needs only an orchestration layer on top of the
existing machinery. No R/ source changes are required for correctness.

## Parallel Sweep: Two Prerequisites

Before parallel sweep is safe, two things need to change:

1. **Telemetry side-channel**: Extract `.ledgr_telemetry_registry` out of the
   shared environment. Route telemetry through return values or an argument
   passed to `write_persistent_telemetry`, not a keyed global store. This is
   the only correctness blocker for parallel execution.

2. **DuckDB write isolation**: Choose one of:
   - Each worker writes to a per-run `tempfile()` database; an orchestrator
     merges completed artifacts into the snapshot database after all workers
     finish.
   - Workers are serialized at the DuckDB write boundary with a queue; the fold
     runs in parallel but writes are funnelled single-file.

   The per-worker temp database approach is more tractable given the current
   fold/output coupling and requires no changes to the fold core.

## What This Review Does Not Cover

- Benchmarking: actual sweep throughput has not been measured.
- The `db_live` execution mode: only `audit_log` was analysed for the sweep
  path. `db_live` writes to DuckDB on every pulse and is probably not the right
  mode for sweep.
- Memory scaling: the audit_log batch buffers grow with `total_pulses * n_instruments`.
  At large sweep widths with long date ranges this may need attention.
