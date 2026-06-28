# Closed-Trade Retention Storage Smoke

Status: Passed on 2026-06-28 for LDG-2661.

Scope: internal storage-smoke evidence for the opt-in retained closed-trade
table added in v0.1.9.7 Batch 2. This smoke does not authorize any objective
criterion by itself.

## Fixture

- one instrument (`AAA`);
- six daily pulses;
- two completed sweep candidates (`qty = 1`, `qty = 2`);
- strategy opens, closes, reverses, then closes again;
- retention: `ledgr_sweep_retention(returns = "completed", trades = "closed")`;
- saved as a compact sweep artifact and reopened from the experiment store.

## Command Shape

```r
pkgload::load_all(".", quiet = TRUE)

sweep <- ledgr_sweep(
  exp,
  ledgr_param_grid(a = list(qty = 1), b = list(qty = 2)),
  seed = 123L,
  retain = ledgr_sweep_retention(returns = "completed", trades = "closed")
)
ledgr_sweep_save(sweep, snapshot, sweep_id = "trade_smoke")

DBI::dbGetQuery(
  con,
  "SELECT
     (SELECT COUNT(*) FROM sweep_returns) AS returns_rows,
     (SELECT COUNT(*) FROM sweep_trades) AS trade_rows"
)
ledgr_sweep_trades(ledgr_sweep_open(snapshot, "trade_smoke"))
```

## Observed Result

```text
returns_rows: 12
trade_rows:    4
```

Reopened retained-trade evidence:

| candidate_id | candidate_row | trade_seq | close_ts_utc        | realized_pnl | win_loss |
| --- | ---: | ---: | --- | ---: | --- |
| a | 1 | 1 | 2020-01-03T00:00:00Z | 1 | WIN |
| a | 1 | 2 | 2020-01-06T00:00:00Z | -1 | LOSS |
| b | 2 | 1 | 2020-01-03T00:00:00Z | 2 | WIN |
| b | 2 | 2 | 2020-01-06T00:00:00Z | -2 | LOSS |

## Ratio Gate

The smoke fixture records a retained-trade row ratio of:

```text
trade_rows / returns_rows = 4 / 12 = 0.3334
```

Batch 2 acceptance threshold: retained closed-trade rows must stay below a
`0.50` row ratio against retained return rows on this fixture. The table is
sparse by design: one row per closed trade, not one row per pulse.

DuckDB block-level storage accounting is intentionally not used for this tiny
fixture because block allocation is coarser than the four-row `sweep_trades`
table. The row-ratio gate is the stable storage-smoke signal for this extension;
full storage sizing belongs with larger workload-grid measurement if closed
trade retention becomes a heavy production surface.
