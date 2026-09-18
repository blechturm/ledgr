# Peer Parity And Performance Benchmark

This is the current ledgr peer benchmark. It has two separate
outputs:

- a parity benchmark: do peer engines agree with the ledgr canonical row?
- a performance benchmark: how long did each local same-host row take under its
  declared timing boundary?

It is an internal maintainer artifact, not package documentation and not a
public release-note performance claim.

Run from the package root:

```powershell
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/bench/peer_benchmark/peer_benchmark.R --preset smoke
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/bench/peer_benchmark/peer_benchmark.R --preset record
```

The record preset is the primary artifact for closeout. It uses 100 instruments
and 252 daily bars. The smoke preset is only a harness verification.

## v0.2.0.1 Closeout Record

The v0.2.0.1 closeout deliberately overrides the unchanged record-preset shape
with this exact command:

```powershell
$env:R_PROFILE_USER = "C:\tmp\ledgr-batch10-profile.R"
$env:LEDGR_BATCH10_LIB = "C:\tmp\ledgr-quantstrat-batch10-lib"
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/bench/peer_benchmark/peer_benchmark.R --preset record --release v0.2.0.1-boundary-correction --engine-set all --n-inst 500 --n-days 1260 --fast 5 --slow 10 --seed 20260530 --compiled-accounting-model spot_fifo
```

The exact ignored local record prefix is
`dev/bench/results/peer_benchmark_record_20260917T231851Z`. It was produced by
the public-sweep boundary correction from a working tree based on source commit
`400a3e56ae49cc61256d0e7aaca66281626d4fe3`; the exact harness SHA-256 is
`3ef4a31831a16bc8cb06cc2647bd68e1f3e9f5d13268806523ec62edb22b579e`.
The same method must be rerun after commit before it becomes immutable release
closeout evidence. The prior `20260917T212008Z` bundle remains the historical
private-fold record and is not rewritten. The correction ran under R 4.6.1
ucrt on Windows build 26200. Quantstrat completed from
`C:/tmp/ledgr-quantstrat-batch10-lib` with quantstrat 0.25 at
`1114e4a1a8a3b68d2fb7a62b52d743cbc5e4b39f`, blotter 0.17.0 at
`dddb448f7a5d6eb63dfbe421ba80779e820a3601`, FinancialInstrument 1.3.0 at
`98bcf09fc80e25611897404dcd59321ef67850ac`, xts 0.14.2, and TTR 0.24.4.
Backtrader and zipline-reloaded completed through their pinned `uv`
environments. Local LEAN was unavailable because the configured CLI root uses
an obsolete organization layout; no hosted service was used.

Parity is interpreted before timing. The compiled spot-FIFO and canonical
public-sweep ledgr rows are exactly identical across canonical equity, fills,
and trades after normalizing only the engine label. The timed public surface is
the complete one-candidate `ledgr_sweep()` call plus retained-result accessors;
richer cash, position and fill surfaces come from a disclosed untimed internal
oracle. Durable ledgr differs from the canonical sweep by at most `4.01e-7` in
equity and is exact on fills. Backtrader and quantstrat pass the registered
equity-level tolerance
with classified residuals. Zipline meets that numerical threshold but has only
0.146 daily-return correlation, so the report labels it a weak-tolerance review
result rather than full parity. This is an internal same-host method record,
not a public ranking or a claim that the engines expose identical lifecycle
boundaries.

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
- `ledgr_ttr_canonical_sweep`: public one-candidate sweep using the same
  TTR-backed features, with retained returns and trades inside the clock.
- `ledgr_ttr_compiled_spot_fifo_sweep`: the same public sweep with the explicit
  compiled spot-FIFO selector.
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
- benchmark method and exact harness SHA-256 in the environment JSON;
- compact Markdown summary;
- parity history JSON under `dev/bench/results/parity_history/`.

Parity failures keep the three-source attribution rule: ledgr, peer, or harness.
Residual divergences are attributed to indicator initialization, fill timing,
cost/margin defaults, position-sizing rounding, timestamp alignment, or float
ordering.

## Performance Boundaries

The performance CSV reports:

- `full_row_sec`: elapsed time around the whole harness call for that engine row;
- `snapshot_prepare_sec`: reusable native data preparation;
- `experiment_setup_sec`: per-experiment setup and public-workflow orchestration;
- `engine_sec`: the declared engine execution boundary; and
- `results_sec`: required canonical result materialization.

The boundaries are intentionally explicit. Durable ledgr timing is
`ledgr_run()` over the snapshot-backed fold with feature plumbing and durable
ledgr surfaces. Memory-backed ledgr timing is the public one-candidate
`ledgr_sweep()` workflow; its internal candidate engine/results clocks are
reconciled to the complete public call, and its untimed parity oracle is not
part of any reported phase.
For those sweep rows, `experiment_setup_sec` is the residual public-call wall
outside the candidate fold and inline-results clocks, plus experiment/grid
construction. It includes warm snapshot reads, matrix/view preparation and
retention assembly. Durable ledgr exposes no matching subclock: analogous work
inside `ledgr_run()` remains in that row's engine phase. Compare cold and warm
totals across those rows; the components explain each row's declared boundary.
Backtrader's core timing includes CSV read, feed construction, `cerebro.run()`,
and canonical output writes. LEAN is a real CLI subprocess boundary when
locally configured; no substitute loop is emitted. `zipline-reloaded-full` is
the full zipline row for this harness: it includes temporary csvdir bundle
construction, bundle ingestion, and `zipline.run_algorithm()`.

`cold_end_to_end` sums all four phases. `warm_research_iteration` excludes only
reusable snapshot preparation. Use those clocks across engines only when input,
output, and lifecycle boundaries are meaningfully comparable. Data or fact
changes invalidate snapshot reuse and incur preparation again.
An unavailable engine has `NULL` performance clocks in the report. Any elapsed
time for its failed wrapper attempt remains diagnostic metadata, not a benchmark
result.

The tracked report uses `ggplot2` for every figure. Base-R plotting is not part
of the report path.
