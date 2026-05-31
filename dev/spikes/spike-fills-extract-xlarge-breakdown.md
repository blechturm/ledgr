# Spike Log: Fills Extract Xlarge Row-Count Fallback Breakdown

**Date:** 2026-05-31 - **Host:** local development host - R 4.5.2,
duckdb - **Status:** v0.1.8.9 optimization-round input (Batch D, Spike 9).

**Script:** `dev/spikes/spike-fills-extract-xlarge-breakdown.R`. Raw CSV
(gitignored):
`dev/bench/results/spike_fills_extract_xlarge_breakdown.csv`.

**Relates to:** `dev/bench/notes/single_core_optimization_inventory.md`
(D2, L1), `dev/bench/notes/workload_grid_baseline_closeout.md`, LDG-2488.

## Question

At `density_high_xlarge_durable` (~133k fills), the LDG-2479 grid
harness's `ledgr_results(bt, "fills")` returned no row count, forcing the
benchmark to fall back to `ledger_events` row count. The closeout flagged
this as a robustness gap. Which stage of the fills extraction fails at
xlarge: DuckDB query layer, R-level conversion, or the higher-level bt
wrapper?

## Method

Synthetic ledger_events DuckDB table at four scales {13.5k, 30k, 68.5k,
133k}. Each stage timed independently:

1. `setup_db`: insert N rows into a fresh in-memory DuckDB.
2. `COUNT(*) query`: simple aggregation query.
3. `Full-table SELECT`: read all rows into an R data.frame.
4. `ledgr_fills_from_events`: call the reconstruction (skipped at large
   scales because Spike 7 already measured this).

If any stage returns NULL row count or errors, that's the fallback
trigger.

## Results

```
n_rows  setup_s  count_s  read_s  n_read
13500    0.08     0.00    0.00    13500
30000    0.06     0.02    0.01    30000
68500    0.06     0.00    0.03    68500
133000   0.07     0.00    0.06    133000
```

All DuckDB stages return CORRECT row counts at all scales. Full-table
SELECT at 133k completes in 0.06s. COUNT(*) is essentially free.

## Findings

**The DuckDB query layer is NOT the source of the xlarge fallback.** At
133k rows, both `COUNT(*)` and the full-table SELECT return correct row
counts in under 0.1 seconds. The DuckDB driver and R DBI layer handle
this scale without issue.

**The LDG-2479 grid fallback was triggered downstream.** The bug must be
in one of:

1. **`ledgr_extract_fills_impl`'s integration with the production bt
   object.** The function receives a `bt` argument containing a
   connection and run_id. If something specific about how the grid run
   constructs bt (or how it handles concurrency, transactions, or
   connection lifecycle) causes a query to return NULL, that's
   different from a direct DBI query.
2. **The harness's `nrow(ledgr_results(bt, "fills"))` call timing.** If
   `ledgr_results` returns a lazy DuckDB cursor at xlarge and the
   subsequent `nrow()` materializes it incorrectly, that's a
   ledgr_results contract bug, not a DuckDB layer bug.
3. **The handler's chunked reader.** `R/backtest.R:1021-1276` includes
   a `stream_threshold` parameter defaulting to 100,000. At 133k fills,
   the chunked reader path activates. If the chunked path has a bug
   that returns no row count when the chunks exceed the threshold,
   that's the fallback trigger.

**Spike 9 is a NEGATIVE confirmation of one hypothesis and a NARROWING
of the investigation.** The remaining investigation requires running an
actual ledgr_run at xlarge to materialize bt, then stepping through
`ledgr_extract_fills_impl`'s chunked-reader path with the stream
threshold engaged. That's a debugging task, not a spike.

## Wall translation

N/A — this is a robustness diagnostic, not a performance simulation.

## Caveats

- **The spike does not reproduce the LDG-2479 grid failure.** The grid
  failure was observed when calling `nrow(ledgr_results(bt, "fills"))`
  on a real bt object at xlarge. The spike sets up only the DuckDB
  table and tests the layer separately. Reproducing the actual
  failure requires a real bt object at xlarge scale, which takes
  hours of fold work (per Spike 7's 10-minute reconstruction at 130k).
- **stream_threshold is the prime suspect.** Default value is 100,000
  per `R/backtest.R:1017`. At 133k fills the streaming path activates.
  Code review of `ledgr_extract_fills_impl` around stream-threshold
  handling is the next investigation step.
- **The fallback workaround in LDG-2479 was correct.** Using
  ledger_events row count as fallback when fills row count is NULL is
  a defensible robustness measure. The fix is at the
  `ledgr_extract_fills_impl` chunked-reader path, not at the harness.

## Recommendation

**Park as a narrowed-investigation result.** The DuckDB layer is
exonerated. The actual failure location is one of: stream_threshold
chunked-reader path, ledgr_extract_fills_impl bt integration, or the
harness's lazy-cursor materialization.

For v0.1.8.9: file a focused robustness ticket that runs an instrumented
`ledgr_extract_fills_impl` against a real xlarge bt object. Step
through stream-threshold activation. Identify whether the chunked
reader returns NULL row count, errors, or silently drops rows.

The fix scope is bounded but cannot be specified without the real
diagnostic. Estimated effort: S-M for the diagnostic, S for the fix
once the cause is known.

**Note:** if Spike 7's setv fix lands first and reduces
`ledgr_fills_from_events` from 10 minutes to ~1 minute at 130k, running
the diagnostic becomes much more tractable. Sequencing:
Spike 7 fix lands -> production xlarge grid run completes -> diagnostic
ticket runs on the real bt.

## Architectural lesson

This spike demonstrates the limits of isolated reproduction. The
LDG-2479 failure was observed in production but cannot be reproduced
in isolation without rebuilding the full pipeline. The v0.1.8.7 spike
discipline ("isolated micro-benchmarks lie") applies in the other
direction too: not every production bug can be reproduced in a spike.
For robustness investigations like this, the right next step is
instrumented production runs, not synthetic reproducers.
