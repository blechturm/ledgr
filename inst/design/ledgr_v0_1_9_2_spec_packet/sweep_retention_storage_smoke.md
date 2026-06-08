# v0.1.9.2 Sweep Retention Storage Smoke

**Status:** Batch 7 measurement evidence.
**Date:** 2026-06-07.
**Purpose:** release-gate storage sanity check for retained sweep return rows.

This is not a public benchmark. It is a storage guardrail for the
`sweep_returns` table only.

## Method

Fixture:

- `ledgr_demo_bars`;
- instruments `DEMO_01` and `DEMO_02`;
- first 1,260 distinct `ts_utc` values available for those instruments;
- `vignettes/sweeps.qmd` SMA alias example grid;
- 16 sweep candidates;
- all candidates completed;
- first save with `retain = ledgr_sweep_retention("none")`;
- second save with `retain = ledgr_sweep_retention("completed")`;
- both saves in the same temporary DuckDB-backed snapshot store.

Formula from the accepted synthesis:

```text
expected_bytes = n_completed * n_pulses * 64
ratio = retained_db_delta_bytes / expected_bytes
```

`retained_db_delta_bytes` is limited to the `sweep_returns` table. In this
DuckDB build, `PRAGMA storage_info('sweep_returns')` exposes persistent block
ids, not per-segment compressed byte counts. The measurement therefore counts
unique persistent block ids for `sweep_returns` and multiplies by
`PRAGMA database_size` `block_size`.

This is intentionally conservative at table-block granularity.

## Result

```text
n_candidates = 16
n_completed = 16
n_pulses = 1,260
n_return_rows = 20,160
expected_bytes = 1,290,240
baseline_sweep_returns_bytes = 0
retained_sweep_returns_bytes = 786,432
retained_db_delta_bytes = 786,432
ratio = 0.609524
```

Gate: **pass** (`0.609524 <= 2.0`).

## DuckDB Storage Evidence

`PRAGMA database_size` reported:

```text
block_size = 262,144
total_blocks = 37
used_blocks = 27
free_blocks = 10
wal_size = 0 bytes
```

`PRAGMA storage_info('sweep_returns')` after the retained save reported one row
group with 20,160 rows. Persistent blocks used by `sweep_returns` in this run:

| Block | Column family | Compression |
| --- | --- | --- |
| 29 | `sweep_id`, `candidate_row`, `pulse_index`, `ts_utc`, `period_return` validity | Dictionary, RLE, BitPacking, Uncompressed validity |
| 30 | `equity` | ALPRD |
| 31 | `period_return` | ALPRD |

The scalar-only baseline had no `sweep_returns` rows and no persistent
`sweep_returns` blocks.

Block ids are environment-specific evidence from this smoke run. The stable
release-gate value is the table-scoped block-count byte estimate and ratio, not
the literal block numbers.

## Interpretation

The retained return table stayed below the accepted `2.0` ratio using the
conservative table-block method. The result is only a storage smoke check for
the v0.1.9.2 retained-series representation; it does not make a performance,
capacity, or public benchmark claim.
