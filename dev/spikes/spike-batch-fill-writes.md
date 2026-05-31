# Spike Log: Per-Row vs Batched DuckDB Fill Writes

**Date:** 2026-05-31 - **Host:** local development host - R 4.5.2,
duckdb 1.x, DBI - **Status:** v0.1.8.9 optimization-round input (Batch B,
Spike 4).

> **ROUND 2 CORRECTION (2026-05-31):** Codex peer review of the round
> identified that this spike measures the LIVE-MODE per-row INSERT path
> (`R/ledger-writer.R:ledgr_write_fill_events` called via
> `use_transaction = TRUE`), NOT the default-buffered durable path used
> by `density_high_xlarge_durable` and the LDG-2479 workload grid. The
> default durable path uses `ledgr_persistent_output_handler` at
> `R/backtest-runner.R:288-437`, which already batches via
> `state$pending_cols` and `DBI::dbAppendTable`. Spike 4's "headline
> v0.1.8.9 lane" framing is **superseded**.
>
> The default-durable equivalent is **Spike 11 / LDG-2490
> (`dev/spikes/spike-persistent-handler-buffer.md`)**, which measured
> the persistent handler's per-row column-buffer writes — a different
> mechanism (R copy-on-modify on the pending_cols env, not DBI
> per-call overhead) with the same `collapse::setv` fix shape.
>
> **Spike 4's current scope:** applies ONLY to live mode
> (`use_transaction = TRUE` per-fill INSERT path). The measurements,
> mechanism, and per-fill knee are correct for that path. The
> wall-translation paragraph below extrapolates to xlarge durable;
> that extrapolation does NOT apply to default-buffered durable runs.
>
> Treat Spike 4's content below as live-mode evidence. For default
> durable see Spike 11.

**Script:** `dev/spikes/spike-batch-fill-writes.R`. Raw CSV (gitignored):
`dev/bench/results/spike_batch_fill_writes.csv`.

**Relates to:** `dev/bench/notes/single_core_optimization_inventory.md`
(B1), LDG-2483. **Round 2 supersession:** Spike 11 (LDG-2490) for the
default durable path.

## Question

`R/ledger-writer.R:ledgr_write_fill_events()` is called once per fill from
`R/fold-engine.R:336-340`. At 68k fills it sends 68k `DBI::dbExecute`
INSERT calls to DuckDB, each with per-call DBI dispatch overhead. The
v0.1.8.9 inventory's B1 lane proposes batching N fills into one insert. How
much does batching save, and where does the per-fill cost knee sit?

## Method

In-memory DuckDB connection. Pre-built ledger_events table matching the
production schema (11 columns from `R/ledger-writer.R`). A fixed row
payload is reused so the spike times the DB WRITE PATH only — not
canonical_json, ts conversion, or fill_intent validation (those are
separate lanes).

Six variants:

- `per_row`: production pattern (one `DBI::dbExecute` INSERT per row,
  default DuckDB commit behavior).
- `per_row_tx`: same INSERTs wrapped in a single `dbWithTransaction`.
- `batched_10`, `batched_100`, `batched_1000`, `batched_10000`:
  `DBI::dbAppendTable` with chunks of N rows.

Tested at two scales matching LDG-2479 grid cells: 13,355 fills
(density_high_medium / density_low_large) and 68,324 fills
(density_high_large).

## Results

### 13,355 fills (medium / low-large)

```
variant         |    wall_s  us_per_row
per_row         |    11.720      877.6
per_row_tx      |    10.720      802.7
batched_10      |     4.620      345.9
batched_100     |     0.470       35.2
batched_1000    |     0.070        5.2
batched_10000   |     0.020        1.5
```

### 68,324 fills (high-large)

```
variant         |    wall_s  us_per_row
per_row         |    60.010      878.3
per_row_tx      |    54.820      802.4
batched_10      |    23.840      348.9
batched_100     |     2.490       36.4
batched_1000    |     0.300        4.4
batched_10000   |     0.090        1.3
```

All row counts verified PARITY.

## Findings

**Mechanism confirmed, with a clear knee at batches of 100-1000.** Per-row
cost drops from ~878 us/row (per_row) to ~36 us/row (batched_100) to
~4-5 us/row (batched_1000). That is a **24x speedup at batches of 100** and
**~200x speedup at batches of 1000** vs the current per-row pattern.

**Transaction wrapping alone is a weak fix.** `per_row_tx` (one
transaction around all the per-row INSERTs) only recovers ~9% — the per-row
DBI dispatch overhead (driver round-trip, parameter binding,
statement-handle management) is the dominant cost, not the per-row commit.
This is important because a tempting half-fix (wrap the existing per-fill
loop in one transaction) would not unlock the win. The win requires
sending fewer DB round-trips, not just merging the commits.

**Per-row cost scales with n_fills as expected:** at per_row the
per-row cost is ~878 us at both 13k and 68k — flat per-row. At higher
batch sizes it's also roughly flat per row. The mechanism is per-call
overhead, not per-fill accumulation cost.

**Per-fill cost knee:**

| Batch size | us/row at 68k | Ratio vs per_row |
|---:|---:|---:|
| 1 (per_row) | 878 | 1.0x (baseline) |
| 10 | 349 | 2.5x faster |
| 100 | 36 | **24x faster** |
| 1,000 | 4.4 | 200x faster |
| 10,000 | 1.3 | 670x faster |

Diminishing returns past batches of 1,000. The architectural sweet spot is
**batches of 100-1,000**: small enough to flush frequently within a fold
(bounding memory and giving timely durability), large enough to capture
~95% of the achievable per-fill savings.

## Wall translation

Reference workload: `density_high_xlarge_durable` runs in 445.02s wall,
413.47s loop, ~133k fills. The per-fill write cost at production is some
fraction of `t_loop_sec` plus some fraction of `results_sec` depending on
how DuckDB amortizes durability work.

If production per-row writes are ~30% slower than this in-memory spike
(disk-backed durability), the per_row cost at xlarge scales to ~120-150s
of write overhead. Batching to chunks of 100 would recover roughly:

- 60s × (133k / 68k) × (1 - 36/878) = ~112s saved at chunks of 100
- 60s × (133k / 68k) × (1 - 4.4/878) = ~117s saved at chunks of 1000

Even halving these to account for in-memory-DuckDB overestimate, the
recovery is on the order of **50-60s of wall on the xlarge cell**. That is
the largest single-lane wall recovery in the Batch B candidates.

Amdahl bound:

- If write cost is 60s of 445s wall: p = 0.135, batches of 100 give
  max wall speedup = 1.13x (~57s of 445s wall recovered).
- If write cost is 100s of 445s wall: p = 0.225, batches of 100 give
  max wall speedup = 1.26x (~95s of 445s wall recovered).

**For live mode this would be the headline v0.1.8.9 lane.** Larger than
any single per-pulse fix for the live-INSERT path. **See Round 2
correction header**: the default durable path used by the LDG-2479
workload grid does NOT take this code path — the default-buffered
persistent handler already uses `DBI::dbAppendTable`. Spike 11
(LDG-2490) is the corresponding lane for that path.

## Caveats

- **In-memory DuckDB underestimates absolute cost vs production.**
  Production uses a disk-backed `.duckdb` file with WAL durability. Per
  v0.1.8.7 spike discipline, in-memory spikes typically overestimate
  by ~3x vs production for compute-bound tasks but UNDERestimate for
  I/O-bound ones. DBI/DuckDB writes are likely slower on disk; the
  RELATIVE knee should hold but the absolute seconds will be higher.
- **Parity gate for batched writes is non-trivial.** Batched fill writes
  must preserve: event ordering, ts_utc monotonicity within instrument,
  event_seq integer continuity, transaction atomicity (a batch either
  fully lands or fully rolls back). The grow-by-doubling B0 buffer pattern
  is the architectural model: small initial buffer, double on growth,
  flush on capacity or pulse boundary. The v0.1.8.7 B0 helper at
  `R/fold-event-buffer.R` is already in production for the durable handler.
- **The output handler contract changes.** Today `write_fill_events()`
  writes immediately. With batching it buffers and flushes at chunk
  boundaries. Downstream readers (replay, telemetry, observability)
  expecting per-fill durable visibility need to account for the new
  buffering semantics. This is a real contract change — not just a
  performance change.
- **Real-run re-profile is the verdict.** Apply chunked writes in the
  durable output handler with chunks of 100-1000 (settle on the smaller
  end for durability latency; 100 is the recommended starting point),
  re-run `density_high_xlarge_durable` and `density_high_large_durable`,
  confirm `t_loop_sec` drops materially and the durable event log replays
  byte-identically through `ledgr_results()`.

## Recommendation

**Round 2 reclassification: live-mode only.** This spike is no longer the
lead lane of the v0.1.8.9 optimization round; the default-buffered
durable path covered by the LDG-2479 workload grid uses a different
write mechanism (already batched via `dbAppendTable`) and is addressed
by Spike 11 (LDG-2490).

For the live-mode INSERT path (`use_transaction = TRUE`), the
mechanism and knee at batches of 100-1000 are cleanly confirmed and
the fix is still mechanically correct if the live-mode path becomes a
scoped optimization target in a future round.

Implementation sketch:

- Add a chunk buffer to `ledgr_durable_output_handler` that collects fill
  events in memory.
- Flush at: pulse boundary (the natural transaction unit in ledgr's
  contract), or when buffer hits chunk size (recommend 100), or at
  end-of-fold.
- Use `DBI::dbAppendTable` for chunk inserts. Inside one
  `dbWithTransaction` per chunk so atomicity is preserved.
- Update `write_fill_events()` to enqueue rather than immediately INSERT.
- Add `flush_pending()` calls at pulse boundaries.
- Verify the durable event log byte-identical after the change against
  existing run fixtures (Tier 1 parity gate).

Sequencing in v0.1.8.9: this is independent of the Batch A per-pulse fixes
(A1, A2) and can land in parallel with them. Recommend B1 land first or
in parallel because the wall recovery is largest. The per-pulse fixes
flatten the scaling curve; B1 reduces the absolute write cost. Both are
needed.

Expected real-run signature: `t_loop_sec` on `density_high_xlarge_durable`
drops by 50-100s. Per-fill cost in the engine phase drops
proportionally. Tier 1 parity (equity/cash/positions) byte-identical.
Event log replay byte-identical.
