# LDG-2476 Follow-Up Three-Phase Decomposition Design

Created: 2026-05-31

This note records the phase definitions used by the v0.1.9-prep peer benchmark
follow-up. The goal is to separate data preparation, engine execution, and
result materialization instead of reporting one bundled `wall_sec`.

## Phase Definitions

`ingestion_sec`: from timed-window start until the engine has its native data
structures ready to iterate.

`engine_sec`: from ready-to-iterate until strategy execution completes and
engine state is final.

`results_sec`: from final engine state until canonical equity, fills, and trades
exist for this harness.

For each DONE row, the harness requires:

```text
abs((ingestion_sec + engine_sec + results_sec) - wall_sec) <= 0.5
```

LEAN is the explicit exception while unavailable locally. Its CLI boundary is
not phase-separable from outside the CLI, so unavailable LEAN metadata records
NA phases and a single wall time.

## Per-Engine Boundaries

| Engine | Ingestion | Engine | Results |
| --- | --- | --- | --- |
| `ledgr_ttr_canonical` | `ledgr_snapshot_from_csv()` (bars CSV read, timestamp normalization, DuckDB snapshot creation) and experiment construction | `ledgr_run()` | `ledgr_results(bt, "equity")`, `ledgr_results(bt, "fills")`, canonical materialization |
| `ledgr_ttr_canonical_ephemeral` | shared bars CSV read, timestamp normalization, in-memory bars matrix, feature matrix, runtime projection, pulse views | `ledgr_execute_fold()` with `ledgr_memory_output_handler()` | event-stream equity/fills reconstruction, canonical materialization |
| `ledgr_builtin_sma` | same durable ledgr boundary, with built-in SMA feature definitions | `ledgr_run()` | `ledgr_results()` plus canonical materialization |
| `quantstrat` | shared bars CSV read, xts objects, globalenv symbol assignment, `initPortf`, `initAcct`, `initOrders`, strategy setup | `applyStrategy`, `updatePortf`, `updateAcct`, `updateEndEq` | account/transaction extraction and canonical materialization |
| `backtrader` | shared bars CSV read, `PandasData` feed construction, `cerebro.adddata` loop | `cerebro.run()` | CSV writes from strategy-captured equity and fill rows |
| `zipline-reloaded-full` | shared bars CSV read, temporary csvdir write, bundle registration, bundle ingest | `run_algorithm()` | performance-frame equity/transaction extraction and CSV writes |
| `LEAN` | not separable from outside the CLI | whole real CLI subprocess when available | not separable from outside the CLI |

## Ephemeral Ledgr Entry Point

The ephemeral row uses internal fold plumbing only from the benchmark harness:

1. Build `bars_by_id`, `bars_mat`, pulse views, feature matrices, and
   `ledgr_runtime_projection` in memory from the shared bars CSV.
2. Construct a `ledgr_execution_spec()` equivalent to the sweep candidate path.
3. Execute `ledgr_execute_fold()` with `ledgr_memory_output_handler()`.
4. Reconstruct equity and fills from the memory event stream with
   `ledgr_equity_from_events()` and `ledgr_fills_from_events()`.

This is not a second engine. It is the same fold core with a non-durable output
handler, matching the sweep candidate execution shape.

## Parity Gate

The benchmark aborts unless durable and ephemeral ledgr agree before peer rows
are accepted.

Fills are compared exactly after stripping result-only attributes. Equity is
compared with `all.equal(..., tolerance = 1e-8)` because durable lot accounting
uses Kahan compensated summation while the in-memory reconstruction uses naive
`cumsum()` over the event stream. The observed smoke difference was around
8e-9 in positions value, with identical fill rows. Spike 10 later verified that
DuckDB DBI double round-trips are byte-identical, so this tolerance is an
accumulation-method tolerance, not a DuckDB precision caveat.

## Boundary Ambiguity Decisions

Quantstrat portfolio/account/order initialization is ingestion, not engine time,
because it builds native state before strategy iteration.

Zipline csvdir bundle registration and ingest are ingestion. They are the native
data loading path required before `run_algorithm()`.

Backtrader fill capture happens live inside `cerebro.run()`. Results time is
therefore mostly canonical CSV writing.

LEAN CLI phases are not separable from outside the subprocess. The honest local
row remains UNAVAILABLE until the CLI/project setup runs a real backtest.

## Amendment, 2026-09-22 (LDG-2790)

The durable ledgr engines' ingestion phase changed definition. It previously
timed a hand-rolled `utils::read.csv()` plus `as.POSIXct()` sequence feeding
`ledgr_snapshot_from_df()`, which is a path no user writes. It now times
`ledgr_snapshot_from_csv()`, the exported entry point a user calls, so
`snapshot_prepare_sec` reports what the public surface costs. Any record
produced after this change is therefore not comparable with an earlier record
on that phase, and the difference is partly a change of definition rather than
a speedup. `engine_sec` and `results_sec` are unaffected, and no promoted
record is edited.

Two sites were changed, `peer_run_ledgr()` and `peer_run_ledgr_sweep()`. Two
other `read.csv()` calls stay as they are. The ephemeral path
(`peer_ledgr_ephemeral_snapshot_prepare()`) builds in-memory bars and pulse
views and never seals a snapshot, so the file surface does not apply to it.
`peer_run_quantstrat()` prepares a peer engine's own xts objects, and speeding
that up with ledgr code would improve a published peer number without
improving ledgr, which stays declined.

No fixture regeneration was required: `ledgr_snapshot_from_csv()` accepts the
existing date-only bars fixture.

Verified on that fixture, `peer_benchmark_shared_bars_record.csv`, 630,000
rows over 500 instruments from 2018-01-01 to 2022-10-28, R 4.6.1:

| ingestion phase | seconds | snapshot hash |
| --- | ---: | --- |
| old: `read.csv()` + `as.POSIXct()` + `from_df()` | 15.94 | `89ce4285...afdc` |
| new: `from_csv()` | 11.36 | `89ce4285...afdc` |

The sealed artifact is byte-identical, so the caveat above is about what the
phase measures, not about a different snapshot. Part of the 4.6-second drop is
the LDG-2789 timestamp work, which the old path would also have received; the
rest is not doing the conversion twice. The figure is orientation for this
amendment, not a promoted record.
