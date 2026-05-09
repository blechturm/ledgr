# DuckDB Persistence Architecture Review

**Status:** Final LDG-1602 architecture review artifact.

**Purpose:** Record ledgr's DuckDB connection, checkpoint, transaction,
shutdown, and metadata-inspection contracts after the v0.1.7.5 Ubuntu release
gate exposed persistence design pressure.

This document is deliberately a review and decision record. It does not create
a second execution path and does not justify speculative persistence rewrites.

## Background

v0.1.7.5 exposed another Ubuntu-only release-gate failure around DuckDB-backed
schema validation and pkgdown execution. Windows checks had passed, but
Ubuntu/pkgdown showed that caught constraint-violating schema probes could leave
DuckDB connections in a dirty transaction state under Linux/covr execution
paths.

The immediate fix made runtime schema validation metadata-only and moved
constraint-enforcement checks into isolated tests. External review agreed that
this direction is architecturally sound: validators inspect schema shape;
isolated tests prove database enforcement.

v0.1.7.6 keeps that lesson deliberate. The goal is not to chase Ubuntu CI from
the release gate. The goal is to make persistence ownership clear enough that
future Ubuntu failures become narrow bugs, not broad surgery.

## Summary Verdict

The current architecture is sound with three documented residual decisions:

1. Runner cleanup checkpointing remains best-effort, with strict checkpointing
   available through explicit close paths.
2. Double-shutdown cleanup remains a defensive ownership pattern where ledgr
   owns both a DBI connection and DuckDB driver handle.
3. `duckdb_constraints()` expression parsing remains an accepted
   DuckDB-version-sensitive dependency, protected by loud failures and upgrade
   checks rather than invalid-row probes.

No broad production rewrite is warranted from LDG-1602.

## Historical Failure Classes

### Cross-Connection Write Visibility

**Classification:** Resolved, with contract coverage required.

Runner-owned and user-facing write paths checkpoint before later fresh
connections are expected to observe durable state. The strictness varies by
call site:

- cleanup paths use best-effort checkpoints because DuckDB shutdown also flushes
  WAL state;
- explicit user-facing metadata writes use `strict = TRUE` because the mutation
  return contract promises immediate durable visibility.

### Mutating Constraint Probes

**Classification:** Resolved.

Runtime schema validation no longer proves constraints by writing invalid rows.
That pattern was conceptually wrong: schema validation and database enforcement
testing are different responsibilities.

Final rule:

- runtime schema creation/validation may inspect DuckDB metadata;
- runtime validators must not write invalid probe rows into ledgr tables;
- constraint enforcement belongs in isolated tests with disposable DuckDB
  connections.

### Complex DuckDB Metadata SQL

**Classification:** Resolved.

Prior Ubuntu native-code instability came from complex metadata SQL. The
current direction is to keep metadata reads simple and perform enrichment in R
when practical. This is a release-gate safety rule, not a ban on ordinary SQL.

## Connection Lifecycle Map

| Surface | Connection owner | Lifetime | Close/shutdown behavior | Notes |
| --- | --- | --- | --- | --- |
| `ledgr_db_init(db_path)` | Caller receives DBI connection | Long-lived caller-managed | Caller disconnects | Low-level compatibility API. Opens through `ledgr_open_duckdb_with_retry()`, then creates and validates schema. |
| `ledgr_snapshot_from_df()` / `ledgr_snapshot_from_csv()` / `ledgr_snapshot_from_yahoo()` | Adapter owns construction connection, returns `ledgr_snapshot` handle | Operation-scoped during ingest; later snapshot opens lazily | Construction connection disconnects/shuts down on exit | Direct `DBI::dbConnect()` is allowed when creating a brand-new or `:memory:` DB before `ledgr_db_init()` can validate it. Existing files go through `ledgr_db_init()`. |
| `ledgr_snapshot_create()` / import helpers / `ledgr_snapshot_seal()` with DBI connection | Caller owns connection | Caller-managed | Caller disconnects | Low-level APIs operate on supplied connection. Sealing checkpoints strictly after commit. |
| `ledgr_snapshot_load(db_path, snapshot_id)` | Returns `ledgr_snapshot` handle | Lazy long-lived snapshot object | `ledgr_snapshot_close()` or finalizer disconnects/shuts down | Load verifies metadata and optionally hash, then returns a handle whose connection opens lazily through `ledgr_snapshot_open()`. |
| `ledgr_snapshot_open()` / `get_connection(snapshot)` | Snapshot object | Long-lived within snapshot handle | `ledgr_snapshot_close()` or finalizer | Reuses valid open connection; otherwise opens through `ledgr_open_duckdb_with_retry()`. |
| `ledgr_snapshot_list()` path input | Function | Operation-scoped | `on.exit(dbDisconnect(..., shutdown = TRUE))` | Read-style discovery. DBI connection input remains caller-owned. |
| `ledgr_run(exp)` / `ledgr_backtest_run_internal()` | Runner | Operation-scoped run connection | `on.exit()` best-effort checkpoint, disconnect `shutdown = TRUE`, defensive `duckdb_shutdown()` | Canonical execution path. Completed artifacts must be visible after return; LDG-1604 owns fresh-connection tests. |
| `ledgr_backtest` lazy read surfaces | Backtest handle or operation-scoped read connection | Lazy and read-scoped | `ledgr_backtest_read_connection()` closes temporary read connections | Result inspection should not leave writer-blocking connections open when a per-operation read is sufficient. |
| `close.ledgr_backtest()` | Backtest handle | Explicit resource cleanup | Strict checkpoint, then disconnect/shutdown | Explicit close is the loud durability/resource-management surface for a returned backtest handle. |
| `ledgr_run_store_open()` / run discovery APIs | Run-store helper | Operation-scoped | `ledgr_run_store_close()` best-effort checkpoint, disconnect `shutdown = FALSE`, then `duckdb_shutdown()` | Used by `ledgr_run_list()`, `ledgr_run_info()`, `ledgr_compare_runs()`, `ledgr_run_open()`, label/archive/tag APIs. |
| `ledgr_run_label()` / `ledgr_run_archive()` / tag mutation APIs | Run-store helper | Operation-scoped | Strict checkpoint after mutation; run-store close cleanup after | User-facing metadata mutations must be fresh-connection visible. |
| `ledgr_experiment_store_check_schema(write = TRUE)` | Supplied connection | Caller-managed | Caller closes | May migrate legacy stores inside transaction. Read checks do not migrate. |
| pkgdown/vignette examples | Example code | Usually temporary file DBs | Examples close snapshot/backtest handles where taught | Executable docs are release-gate sensitive because they exercise real DuckDB paths. |

## Direct Connection Exceptions

The preferred production open helper is `ledgr_open_duckdb_with_retry()`.
Direct `DBI::dbConnect()` is still acceptable in these cases:

- tests that own disposable `:memory:` databases;
- examples that intentionally teach raw DBI connection ownership;
- `ledgr_snapshot_from_df()` creating a brand-new database or `:memory:`
  snapshot before `ledgr_db_init()` can validate an existing schema;
- roxygen examples showing caller-managed low-level connections.

Any new production direct connection should justify why the retry helper is not
appropriate.

## Checkpoint Matrix

| Write path | Durable state written | Checkpoint behavior | Decision |
| --- | --- | --- | --- |
| `ledgr_backtest_run_internal()` cleanup | runs, ledger events, features, equity, telemetry, strategy state | Best-effort `ledgr_checkpoint_duckdb(con)` in `on.exit()`, followed by `dbDisconnect(..., shutdown = TRUE)` and defensive `duckdb_shutdown()` | Keep best-effort. The runner should not mask the original run error with cleanup checkpoint failure. Successful completed-run visibility is proven by tests, not by making cleanup throw late. |
| `close.ledgr_backtest()` | No new artifacts; flushes returned durable handle | `ledgr_backtest_checkpoint_state(strict = TRUE)` | Keep strict. Explicit close is user-invoked and should fail loudly if a durable run cannot checkpoint. |
| `ledgr_backtest` finalizer auto-checkpoint | Returned durable handle cleanup | Best-effort auto-checkpoint, then disconnect | Keep best-effort. Finalizers must not throw user-visible errors. |
| `ledgr_snapshot_seal()` | snapshot status, hash, sealed timestamp, seal metadata | Strict checkpoint after successful commit | Keep strict. Seal is a durable state transition and hash publication point. |
| `ledgr_snapshot_from_df()` metadata update and seal | snapshot rows, metadata, seal transition | Relies on `ledgr_snapshot_seal()` strict checkpoint, then construction connection cleanup | Keep. The seal owns the durable publication point. |
| `ledgr_run_label()` | mutable run label | Strict checkpoint immediately after update | Keep strict. User-facing metadata mutation promises immediate read-back. |
| `ledgr_run_archive()` | archive metadata | Strict checkpoint immediately after update | Keep strict. User-facing metadata mutation promises immediate read-back. |
| `ledgr_run_tag()` / `ledgr_run_untag()` | run tag rows | Strict checkpoint after mutation | Keep strict. Tags are mutable metadata and must be fresh-connection visible. |
| `ledgr_run_store_close()` | cleanup after read/write run-store helper | Best-effort checkpoint, disconnect `shutdown = FALSE`, then `duckdb_shutdown()` | Keep. It is defensive cleanup; explicit mutation paths checkpoint strictly before close. |
| Experiment-store migration | schema metadata and migrated support tables | Transactional DDL/DML; caller-owned connection cleanup | Keep. Version marker is written last inside transaction. |
| Feature/equity/fill persistence internals | run artifacts | Transactional writes on runner connection; runner cleanup checkpoints | Keep. Transaction boundaries protect atomicity; runner cleanup publishes durability. |

## Transaction Audit

The scan found the expected transaction boundaries:

- resume cleanup in `R/backtest-runner.R` deletes tail artifacts inside
  `DBI::dbWithTransaction()`;
- audit-log pulse batches in `R/backtest-runner.R` use
  `DBI::dbWithTransaction()`;
- feature persistence in `R/backtest-runner.R` and `R/features-engine.R` uses
  `DBI::dbWithTransaction()`;
- equity curve replacement in `R/derived-state.R` uses
  `DBI::dbWithTransaction()`;
- fill event writes in `R/ledger-writer.R` use
  `DBI::dbWithTransaction(con, do_write())`; R lazy evaluation means
  `do_write()` is evaluated inside the transaction;
- experiment-store migration in `R/experiment-store-schema.R` uses a
  transaction and writes the schema version marker last;
- snapshot adapter bulk ingestion uses a transaction around instrument and bar
  copy;
- snapshot sealing uses explicit `BEGIN TRANSACTION` / `COMMIT` because it has
  custom failure handling that can mark a created snapshot as `FAILED`.

No transaction-boundary rewrite is required from LDG-1602.

## Temporary Views And Registered Data Frames

Temporary objects are intentional query conveniences:

- `ledgr_prepare_snapshot_source_tables()` attaches a separate snapshot DB
  read-only and creates temp views over snapshot tables;
- `ledgr_prepare_snapshot_runtime_views()` creates temp `instruments` and
  `bars` views that let legacy v0.1.0 query paths operate over sealed snapshot
  data;
- `ledgr_snapshot_from_df()` uses `duckdb_register()` and temp parquet copy for
  bulk ingest, then unregisters via `on.exit()`;
- adapter hashing creates temporary `bars` views scoped to the construction
  connection.

These temp objects do not alter durable snapshot/run semantics and are
connection-scoped. They are allowed under the existing snapshot contract.

## Residual Decisions

### Runner Checkpoint Strictness

**Decision:** Keep runner cleanup checkpointing best-effort.

Reasoning:

- The runner cleanup path runs from `on.exit()` and should not mask an original
  strategy, validation, or persistence error with a secondary checkpoint error.
- Successful completed-run durability is still a public contract. It should be
  proven by fresh-connection tests in LDG-1604.
- Explicit `close(bt)` remains strict, so users who want an immediate loud
  resource-management checkpoint have that surface.
- `dbDisconnect(..., shutdown = TRUE)` and DuckDB driver shutdown provide a
  second WAL-flush path after the best-effort checkpoint.

Guard:

- Fresh-connection completed-run visibility tests.
- Release playbook warning to inspect checkpoint placement when Ubuntu fresh
  reads miss writes.

### Shutdown Ownership

**Decision:** Keep the current defensive double-shutdown pattern.

Reasoning:

- ledgr often owns both a DBI connection and the DuckDB driver object returned
  by `duckdb::duckdb()`.
- Some paths call `DBI::dbDisconnect(..., shutdown = TRUE)` and then
  `duckdb::duckdb_shutdown(drv)`. The second call is usually redundant, but it
  is wrapped in suppressed `try()` and is harmless.
- `ledgr_run_store_close()` uses `shutdown = FALSE` followed by
  `duckdb_shutdown(drv)` because the helper owns the driver and wants explicit
  cleanup after a best-effort checkpoint.

Guard:

- Keep shutdown calls suppressed in cleanup/finalizer paths.
- Do not add unsuppressed double-shutdown calls.
- New connection-owner helpers should state whether DBI disconnect or driver
  shutdown owns final cleanup.

### DuckDB Constraint Metadata Format

**Decision:** Keep `duckdb_constraints()` expression parsing, but treat it as a
DuckDB-version-sensitive metadata contract.

Reasoning:

- ledgr is intentionally DuckDB-backed, so DuckDB metadata table functions are
  acceptable dependencies.
- Runtime validators must not fall back to invalid-row DML probes.
- The current `CHECK (... IN (...))` parsing is clear and compact, but depends
  on DuckDB continuing to expose compatible SQL expression text.

Guard:

- Validator-side metadata mismatch fails loudly.
- Create-side `runs.status` metadata inspection also fails loudly if
  `duckdb_constraints()` cannot be queried.
- DuckDB upgrades must verify `duckdb_constraints()` expression output for
  `runs.status` and `snapshots.status`.
- Isolated DML tests prove enforcement separately.

## Follow-Up Tickets

LDG-1602 does not require production code changes. It creates the review
baseline for:

- LDG-1603: schema validation side-effect and isolated constraint-enforcement
  tests, including `snapshots.status` invalid-value coverage;
- LDG-1604: fresh-connection persistence tests and local Ubuntu gate;
- LDG-1605: contract, NEWS, roadmap, and playbook alignment.

## Static Review Commands

The LDG-1602 review used static scans rather than broad tests:

```sh
rg -n "ledgr_open_duckdb_with_retry|dbConnect|dbDisconnect|duckdb_shutdown|ledgr_checkpoint_duckdb|CHECKPOINT|dbWithTransaction|duckdb_register|duckdb_unregister|CREATE OR REPLACE TEMP|CREATE TEMP|TEMP VIEW|TEMP TABLE|duckdb_constraints|dbBegin|dbCommit|dbRollback" R
```

The scan confirmed the expected hotspots:

- `R/public-api.R`
- `R/backtest-runner.R`
- `R/backtest.R`
- `R/run-store.R`
- `R/run-tags.R`
- `R/snapshot.R`
- `R/snapshot-source.R`
- `R/snapshot_adapters.R`
- `R/snapshots-seal.R`
- `R/db-schema-create.R`
- `R/db-schema-validate.R`
- `R/experiment-store-schema.R`
- `R/derived-state.R`
- `R/features-engine.R`
- `R/ledger-writer.R`

No full test suite was run for LDG-1602 because this ticket changes only design
artifacts and ticket state.
