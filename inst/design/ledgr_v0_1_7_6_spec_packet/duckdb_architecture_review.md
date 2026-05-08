# DuckDB Persistence Architecture Review Notes

**Status:** Seed review notes for v0.1.7.6.

**Purpose:** Park post-v0.1.7.5 DuckDB architecture findings before the formal
v0.1.7.6 tickets are cut. These notes are review evidence and starting context,
not the final architecture decision record.

## Background

v0.1.7.5 exposed another Ubuntu-only release-gate failure around DuckDB-backed
schema validation and pkgdown execution. Windows checks passed earlier, but
Ubuntu/pkgdown revealed that constraint-violating schema probes could pollute
DuckDB connection state under Linux execution paths.

The immediate fix made runtime schema validation metadata-only and moved
constraint-enforcement checks into isolated tests. A follow-up review concluded
that this direction is architecturally sound, but the broader DuckDB posture
should be reviewed deliberately in v0.1.7.6 rather than through release-gate
surgery.

## External Review Summary

The external review concluded that ledgr's current DuckDB architecture is sound
and that the prior Ubuntu failures represented three distinct issue classes, now
structurally addressed.

### 1. Cross-Connection Write Visibility

**Classification:** Resolved.

Runner-owned and user-facing write paths now checkpoint before later fresh
connections are expected to observe durable state.

Observed checkpoint sites:

- Runner cleanup in `R/backtest-runner.R` uses a non-strict checkpoint before
  disconnect.
- `ledgr_run_label()` and `ledgr_run_archive()` in `R/run-store.R` use
  `strict = TRUE` immediately after metadata updates.
- `ledgr_run_store_close()` checkpoints before closing run-store connections.

The review judged the strict/non-strict split defensible: explicit user-facing
metadata writes should fail loudly if checkpointing fails, while cleanup paths
may use best-effort checkpointing because DuckDB shutdown also flushes WAL state.

### 2. Mutating Constraint Probes

**Classification:** Resolved.

Runtime schema validation no longer proves constraints by writing invalid rows.
This is now a contract and playbook rule:

- runtime schema creation/validation is read-only with respect to ledgr data
  rows, except deliberate schema migration or DDL;
- constraint enforcement belongs in isolated tests with disposable DuckDB
  connections.

The review framed the earlier failure as a conceptual design error, not an
Ubuntu platform quirk: validation and constraint enforcement testing are
different responsibilities.

### 3. Complex SQL In DuckDB Metadata Reads

**Classification:** Resolved.

The prior Ubuntu native-code failure from complex metadata SQL has been handled
by simplifying query shape and performing enrichment in R. The playbook now
records the general rule: prefer simple DuckDB metadata reads plus R-side
enrichment over release-blocking complex metadata queries.

## Connection Contention Assessment

The review did not find in-process connection contention to be a fundamental
architecture problem. DuckDB's R binding deduplicates connections to the same
database path within the same R process. In this model, a snapshot's long-lived
connection and a per-operation run-store connection are not inherently competing
writers.

`ledgr_open_duckdb_with_retry()` remains useful for the short window where a
previous driver has not been fully released. The `gc()` call inside the retry
loop is appropriate because it gives pending finalizers a chance to release
stale DuckDB instances.

## Transaction Discipline Assessment

The review found transaction discipline broadly consistent:

- multi-statement write operations use `DBI::dbWithTransaction()` where
  appropriate;
- experiment-store schema migration writes its version marker last, so failed
  migration does not leave a store marked as upgraded;
- snapshot sealing uses an explicit transaction around the seal transition and
  checkpointing after commit.

The review also noted that `DBI::dbWithTransaction(con, do_write())` is valid in
the fill writer because R lazy evaluation evaluates `do_write()` inside
`dbWithTransaction()`, after `dbBegin()`.

## Residual Decisions For v0.1.7.6

These are not release blockers, but should be explicitly decided during the
v0.1.7.6 architecture review.

### Runner Checkpoint Strictness

The runner uses non-strict checkpointing on cleanup. This is probably acceptable
because `dbDisconnect(..., shutdown = TRUE)` should flush WAL state too, but
`strict = TRUE` would provide an earlier, clearer error signal if checkpointing
fails.

Decision needed:

- keep runner cleanup checkpointing non-strict and document why; or
- make runner checkpointing strict where a completed run's durability is part of
  the return contract.

### Shutdown Ownership

Some paths call both `DBI::dbDisconnect(con, shutdown = TRUE)` and
`duckdb::duckdb_shutdown(drv)`. The second shutdown is usually redundant and is
suppressed, so it is harmless, but the ownership model is noisy.

Decision needed:

- simplify shutdown ownership; or
- document the double-shutdown pattern as defensive cleanup.

### DuckDB Metadata Format Dependency

`duckdb_constraints()` is an official DuckDB metadata table function, but ledgr
currently parses the textual `expression` column to inspect allowed status
values. This depends on DuckDB continuing to render `CHECK (... IN (...))`
constraints in a compatible SQL text form.

Decision needed:

- add a DuckDB-upgrade checklist item that verifies `duckdb_constraints()`
  expression output for ledgr's status constraints; and
- keep tests that fail loudly if the metadata format no longer matches.

## Proposed v0.1.7.6 Review Deliverables

- Connection-lifecycle map for all public DuckDB entry points.
- Mutating-API checkpoint matrix.
- Transaction ownership audit.
- Runtime schema-validation contract audit.
- WSL/Ubuntu parity gate covering the historically fragile flows.
- Decision record for runner checkpoint strictness, shutdown ownership, and
  DuckDB metadata-format upgrade checks.

