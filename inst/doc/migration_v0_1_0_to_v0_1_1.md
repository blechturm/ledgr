# Migration Guide: v0.1.0 → v0.1.1 (Snapshots)

This guide describes how to migrate a v0.1.0 workflow (runner reads `bars`/`instruments`) to the v0.1.1 snapshot-based workflow (runner reads from sealed snapshots with tamper detection). v0.1.1 remains backward compatible: v0.1.0 configs still work, but snapshots are the recommended default for reproducibility.

## What Changed in v0.1.1?

### Schema additions
New tables (normative names):
- `snapshots`
- `snapshot_instruments`
- `snapshot_bars`

Modified tables:
- `runs`: adds `snapshot_id` (nullable) to link a run to its sealed data source.

### Automatic database migration behavior
On first initialization against an existing database, `ledgr_create_schema()` performs best-effort, non-destructive migrations, including:
- Ensuring `runs.snapshot_id` exists and is nullable.
- Migrating legacy `runs.status = 'COMPLETED'` to `runs.status = 'DONE'` where applicable.

### Config change (recommended)
v0.1.0 (still supported):
```r
cfg <- list(
  db_path = "backtest.duckdb",
  universe = list(instrument_ids = c("AAA", "BBB")),
  # Data implicit: runner reads `bars` and `instruments`
  ...
)
```

v0.1.1 (recommended):
```r
cfg <- list(
  db_path = "backtest.duckdb",
  data = list(source = "snapshot", snapshot_id = "snapshot_YYYYmmdd_HHMMSS_abcd"),
  universe = list(instrument_ids = c("AAA", "BBB")),
  ...
)
```

## Migration Steps (Recommended Path)

### 1) Upgrade and initialize
Open your existing DuckDB database with ledgr v0.1.1 and run schema initialization once:
- `ledgr_create_schema(con)`
- `ledgr_validate_schema(con)`

This ensures required tables/columns exist and applies any automatic migrations.

### 2) Export your existing v0.1.0 data to CSV
Your v0.1.0 backtests typically source from:
- `instruments`
- `bars`

Export these tables to CSV (example using DuckDB SQL):
```sql
COPY (SELECT * FROM instruments ORDER BY instrument_id) TO 'instruments.csv' (HEADER, DELIMITER ',');
COPY (SELECT * FROM bars ORDER BY instrument_id, ts_utc) TO 'bars.csv' (HEADER, DELIMITER ',');
```

### 3) Create a new snapshot and import
Create a snapshot and import the exported CSVs:
```r
snap_id <- ledgr_snapshot_create(con, meta = list(source = "v0.1.0 migration"))
ledgr_snapshot_import_instruments_csv(con, snap_id, "instruments.csv")
ledgr_snapshot_import_bars_csv(
  con,
  snapshot_id = snap_id,
  bars_csv_path = "bars.csv",
  instruments_csv_path = NULL,
  auto_generate_instruments = FALSE,
  validate = "fail_fast"
)
```

### 4) Seal the snapshot (immutability + hash)
```r
hash <- ledgr_snapshot_seal(con, snap_id)
```

After sealing, the snapshot becomes immutable and is verified by the runner prior to execution.

### 5) Update configs to reference the snapshot
Update your backtest configuration to use:
- `data = list(source = "snapshot", snapshot_id = snap_id)`

### 6) Re-run and verify reproducibility
Re-run a representative backtest using the snapshot. For auditing workflows, record:
- `snapshot_id`
- `snapshot_hash` (returned by `ledgr_snapshot_seal()`)
- `run_id` and `config_hash`

## Common Migration Issues

### Snapshot coverage errors
If you see `LEDGR_SNAPSHOT_COVERAGE_ERROR`, the requested universe/time range is not fully covered for one or more instruments. Fix by:
- importing complete data for all instruments in the backtest range, or
- narrowing the backtest date range, or
- reducing the universe to instruments present in the snapshot.

### Attempting to modify sealed snapshots
Sealed snapshots are immutable by design. To correct data, create a new snapshot and seal it.

### Hash mismatch / corruption detection
If the runner errors with `LEDGR_SNAPSHOT_CORRUPTED`, the database contents do not match the stored `snapshot_hash`. Typical recovery is to restore the database from a trusted backup or re-import/re-seal from source CSVs.
