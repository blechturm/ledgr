# Peer Parity And Performance Benchmark

This is the current v0.1.8.8 LDG-2476 peer benchmark. It has two separate
outputs:

- a parity benchmark: do peer engines agree with the ledgr canonical row?
- a performance benchmark: how long did each local same-host row take under its
  declared timing boundary?

It is an internal maintainer artifact, not package documentation and not a
public release-note performance claim.

Run from the package root:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/bench/peer_benchmark/peer_benchmark.R --preset smoke
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/bench/peer_benchmark/peer_benchmark.R --preset record
```

The record preset is the primary artifact for closeout. It uses 100 instruments
and 252 daily bars. The smoke preset is only a harness verification.

Render the Markdown report from the package root:

```powershell
& "C:\Program Files\RStudio\resources\app\bin\quarto\bin\quarto.exe" render dev/bench/peer_benchmark/peer_benchmark.qmd -P run_harness:false -P results_preset:record
```

## Strategy Semantics

All engines use SMA crossover-event semantics:

- compute fast and slow SMA from the current close;
- enter long on a transition from `fast <= slow` to `fast > slow`;
- close on a transition from `fast > slow` to `fast <= slow`;
- market fills occur at the next bar open;
- final-bar target changes are not fillable.

The ledgr row stores the previous `fast > slow` relation in `state_update` and
reads it from `ctx$state_prev` on the next pulse. This matches the event-style
Backtrader `CrossOver`, quantstrat `sigCrossover`, the full zipline
`run_algorithm` row, and a real LEAN CLI row when that CLI is locally usable.

## Engine Rows

- `ledgr_ttr_canonical`: canonical ledgr row using TTR-backed SMA features.
- `ledgr_builtin_sma`: ledgr diagnostic row using built-in SMA indicators.
- `quantstrat`: R quantstrat crossover strategy when local packages exist.
- `backtrader`: uv-managed Backtrader row.
- `zipline-reloaded-full`: uv-managed zipline-reloaded row that writes a
  temporary csvdir bundle, ingests it, and runs `zipline.run_algorithm()`.
- `LEAN`: uv-managed real LEAN CLI subprocess row. If the local CLI is not
  configured, the row is `UNAVAILABLE` with the CLI failure reason.

Python peers live under `python/<engine>/`. Runtime uv cache, Python install,
and virtualenv paths are placed under `LEDGR_PEER_UV_HOME` when set, otherwise
under a temporary directory, so generated environments do not live under the
package tree.

## Outputs

Outputs are local-only under `dev/bench/results/`:

- shared bars CSV and input hash;
- per-engine canonical equity CSV;
- per-engine fills/trade tables where available;
- engine status and surface-status CSVs;
- Tier 1/Tier 2/Tier 3 parity CSV;
- performance timing CSV;
- environment JSON;
- compact Markdown summary;
- parity history JSON under `dev/bench/results/parity_history/`.

Parity failures keep the three-source attribution rule: ledgr, peer, or harness.
Residual divergences are attributed to indicator initialization, fill timing,
cost/margin defaults, position-sizing rounding, timestamp alignment, or float
ordering.

## Performance Boundaries

The performance CSV reports both:

- `full_row_sec`: elapsed time around the whole harness call for that engine row;
- `reported_core_sec`: the timing reported from inside the engine row.

The boundaries are intentionally explicit. ledgr's core timing is `ledgr_run()`
over the snapshot-backed fold with feature plumbing and durable ledgr surfaces.
Backtrader's core timing includes CSV read, feed construction, `cerebro.run()`,
and canonical output writes. LEAN is a real CLI subprocess boundary when
locally configured; no substitute loop is emitted. `zipline-reloaded-full` is
the full zipline row for this harness: it includes temporary csvdir bundle
construction, bundle ingestion, and `zipline.run_algorithm()`.
