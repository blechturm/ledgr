# Performance Arc v0.1.8.7 To v0.1.8.10


**Status:** Reviewable maintainer-manual article for LDG-2534.

**Authority:** Synthesis plus implementation trace. Binding scope
remains in the versioned spec packets, release closeouts, benchmark
records, RFCs, ADRs, and contracts linked below.

You need to explain what changed across the v0.1.8.7 to v0.1.8.10
performance arc without overstating a benchmark. This article gives you
the maintainer version of that story: what was measured, what each
release actually changed, which comparisons are apples-to-apples, and
which claims must stay internal.

By the end, you should be able to route a performance question to the
right artifact and avoid mixing default R execution, memory-backed sweep
execution, B2 spot-FIFO opt-in measurements, and peer benchmark rows.

> [!WARNING]
>
> **Synthesis, not a benchmark page**
>
> This article is internal maintainer prose. It is not pkgdown content,
> not a release-note speed claim, and not a hosted benchmark. If it
> disagrees with a closeout, packet, RFC, ADR, or benchmark record, fix
> this article.

## Scope Window

This article covers the v0.1.8.7 through v0.1.8.10 performance arc:

- v0.1.8.7: single-core optimization and attribution discipline;
- v0.1.8.8: diagnostics, parallel sweep setup, and peer-benchmark
  phase-splitting;
- v0.1.8.9: single-core R hot-path cleanup and round-level closeout;
- v0.1.8.10: substrate work, fold-owned FIFO accounting, and scoped B2
  spot-FIFO opt-in.

It does not authorize new performance work. It also does not make a
public claim that ledgr has a general peer-speed advantage. The evidence
is local, current-source, same-host, workload-specific, and often
phase-specific.

## The Arc In One Table

| Release | Primary performance job | Load-bearing artifact | What not to claim |
|----|----|----|----|
| v0.1.8.7 | Remove the worst durable event-buffer and materialization costs, then attribute the result by lane. | `../ledgr_v0_1_8_7_spec_packet/benchmark_attribution_closeout.md` | Do not divide across old and new power profiles or claim universal peer superiority. |
| v0.1.8.8 | Make benchmark boundaries clearer: parallel sweep smoke, discard-all interrupt contract, and phase-separated peer benchmarking. | `../ledgr_v0_1_8_8_spec_packet/peer_benchmark_parity_closeout.md` | Do not treat the early ephemeral row as automatically cheaper or as a public benchmark result. |
| v0.1.8.9 | Clean measured R hot paths: buffer writes, fill extraction, target/position scans, and canonical JSON overhead. | `../ledgr_v0_1_8_9_spec_packet/v0_1_8_9_release_closeout.md` | Do not reduce the round to one wall-time number. Per-lane and per-fill evidence matter. |
| v0.1.8.10 | Make the substrate/accounting boundary compilable and expose B2 only as scoped memory-backed spot-FIFO opt-in. | `../ledgr_v0_1_8_10_spec_packet/v0_1_8_10_release_closeout.md` | Do not imply default compiled execution, durable compiled integration, non-spot accounting, or a general compiled fold core. |

## Evidence Rules

The benchmark record is useful only when the comparison boundary is
explicit. Before quoting a number internally, ask four questions:

1.  Which surface is being measured: durable run, memory-backed sweep,
    canonical R, or B2 spot-FIFO opt-in?
2.  Which phase is being measured: ingestion, engine, results, or total?
3.  Which fixture is being measured: workload-grid stress cell or peer
    SMA crossover fixture?
4.  Which host and source state produced the row?

Raw generated benchmark files live under `../../../dev/bench/results/`
and are ignored by git. Tracked harnesses, reports, and notes live under
`../../../dev/bench/`. Packet closeouts link to the local record
prefixes that produced their conclusions.

> [!NOTE]
>
> **Local means local**
>
> The v0.1.8.7 to v0.1.8.10 measurements are same-host, current-source
> records. They are valid for maintainer attribution and release gating.
> They are not portable speed rankings across operating systems,
> hardware, package versions, or workloads.

## v0.1.8.7: Attribution Before Headlines

The v0.1.8.7 closeout established the discipline that later rounds
followed: record the workload shape, timing boundary, host context, and
lane attribution before summarizing wall time.

The important v0.1.8.7 lessons were:

- event buffering removed the old high-turnover durable bottleneck;
- representation/setup cleanup helped, but was not the main story;
- reconstruction/read-back improvement was a materialization win, not a
  primary run-wall claim;
- sweep artifact policy was proven as a fast/evaluation boundary;
- same-host peer rows were useful only with timing-boundary caveats.

The closeout explicitly allowed careful local language and rejected
broad claims such as unqualified peer-ranking language without
one-workload, same-host, and timing-boundary caveats.

Source:
`../ledgr_v0_1_8_7_spec_packet/benchmark_attribution_closeout.md`.

## Dependency Posture

The retired ADR-0004 decision also explains why the v0.1.8.7
optimization round treated dependency shape as part of performance
posture rather than as cosmetic package minimalism.

The dependency decisions were:

- **Drop `cli`.** The package had a stale import but no active `cli_*`
  call surface. Removing it reduced dependency noise without changing
  behavior.
- **Drop `R6`.** The old object-strategy experiment survived mainly as a
  legacy strategy surface. Removing it supported the function-only
  strategy interface described in `execution_fold_core.qmd` and removed
  an original-vs- replay divergence risk.
- **Keep `tibble`.** Results remain tibble-classed deliberately. That
  public shape is part of ledgr’s R-native quant audience fit and should
  not be removed just to minimize Imports.
- **Add `collapse` behind deterministic gates.** The measured hot path
  needed in-place buffer writes and reconstruction help. `collapse` has
  no transitive dependencies, but ledgr uses it only through
  deterministic wrappers so caller `collapse` option state cannot alter
  ledgr outputs.

The important performance lesson is not “few dependencies are always
better.” It is that dependency changes must map to a measured production
surface or to a clear interface simplification. `cli` and `R6` were
removed because they no longer served the modern execution surface.
`tibble` stayed because it serves the public result surface. `collapse`
was added because it targeted measured buffer and reconstruction lanes,
with determinism guards.

This is why later performance discussions should separate dependency
posture from benchmark headlines. A dependency can be worth keeping for
public shape, or worth adding for a narrow measured lane, as long as the
release packet and contracts preserve determinism and scope.

## v0.1.8.8: Make The Measurement Shape Honest

v0.1.8.8 did not mainly chase a new wall-time headline. It made future
performance work easier to reason about.

The parallel sweep closeout recorded two constraints:

- worker-backed candidate dispatch must preserve equality;
- interrupted parallel sweeps discard partial results instead of
  returning a partially promotable candidate table.

The peer benchmark closeout made a more important measurement change: it
split one large wall-time number into ingestion, engine, and results
phases. That showed that engine-loop cost and result-materialization
cost are different questions. It also showed that the then-current
ephemeral path was not automatically cheaper than durable execution on
the high-turnover peer shape.

Source:

- `../ledgr_v0_1_8_8_spec_packet/parallel_sweep_measurement_closeout.md`
- `../ledgr_v0_1_8_8_spec_packet/peer_benchmark_parity_closeout.md`
- `../../../dev/bench/peer_benchmark/notes/three_phase_decomposition_results.md`

## v0.1.8.9: R Hot-Path Cleanup

v0.1.8.9 removed large R-idiom costs that were already measured. The
round did not create a second engine and did not move ledgr to compiled
execution.

The release closeout attributes the round through named lanes:

- fill extraction switched away from row-wise construction costs;
- durable and memory output handlers reduced avoidable per-row overhead;
- target and position scans became more vectorized;
- canonical JSON moved to byte-format v2 and a stronger dependency
  posture;
- small optional cleanup items were triaged instead of bundled into
  vague optimization work.

The load-bearing result is not “v0.1.8.9 was faster” in the abstract.
The useful reading is: high-density large and xlarge rows recovered
substantial wall time, engine per-fill cost fell, and fills-extraction
per-fill cost fell. The peer record also showed ledgr moving much closer
to Backtrader on the engine phase for the local SMA 5/10 shape. Those
statements remain tied to the fixture, phase definitions, and same-host
record.

Source:

- `../ledgr_v0_1_8_9_spec_packet/per_lane_attribution.md`
- `../ledgr_v0_1_8_9_spec_packet/v0_1_8_9_release_closeout.md`
- `../../../dev/bench/peer_benchmark/peer_benchmark.md`
- `../../../dev/bench/peer_benchmark/peer_benchmark.R`

## v0.1.8.10: Substrate First, B2 Narrowly

v0.1.8.10 has two surfaces that must stay separate.

The canonical R default path gained better substrate and accounting
ownership:

- ephemeral subphase telemetry made memory-backed rows phase-visible;
- `ctx$idx()`, `ctx$vec`, primitive internal positions, and
  matrix-backed next-bar lookup landed as substrate;
- FIFO accounting moved into the fold so accounting facts became
  fold-owned and compilable;
- yyjsonr options were hoisted for helper/read/replay surfaces.

That substrate made the fold more honest and more measurable, but it did
not make the canonical R default path a headline speed release. The
xlarge durable stress cell regressed because R now pays fold-owned FIFO
work inside the loop. Large and low-density cells were roughly flat or
modestly improved.

The B2 spot-FIFO row is different. It is an explicit opt-in for
memory-backed sweep execution:

``` r
ledgr_sweep(..., compiled_accounting_model = "spot_fifo")
```

The B2 gate measured a scoped spot-asset FIFO fill-batch hot frame. It
passed its parity and wall-recovery gates on the measured xlarge
ephemeral cell, then LDG-2526 exposed it as a public sweep opt-in. It
did not authorize default compiled execution, durable `ledgr_run()`
integration, non-spot accounting, or a general compiled fold core.

Source:

- `../ledgr_v0_1_8_10_spec_packet/per_lane_attribution.md`
- `../ledgr_v0_1_8_10_spec_packet/v0_1_8_10_release_closeout.md`
- `../horizon.md` (2026-06-02 `[architecture]` B2 spot-FIFO accelerator
  scope guard)
- `../rfc/rfc_compiled_hot_frame_b2_v0_1_9_x_maintainer_decisions.md`
  (Decision 2 narrowing)
- Migrated on 2026-06-04 from the retired v0.1.8.7 optimization
  maintainer workbook into this article’s Implementation Trace.
- `../../../dev/bench/shared/run_benchmarks.R`

## Peer Comparison Discipline

The current peer benchmark report is useful because it separates parity
from performance and separates phases inside performance. It is also
easy to misread.

Apples-to-apples within the report means:

- same shared bars CSV;
- same preset and seed;
- same SMA fast/slow settings;
- same broad next-open, no-final-fill event semantics where the peer
  surface can express them;
- explicit phase definitions for ingestion, engine, and results;
- unavailable peer rows reported as unavailable instead of substituted.

Even then, peer rows do not have identical boundaries. ledgr durable
includes DuckDB snapshot and artifact surfaces. ledgr ephemeral removes
durable persistence but still materializes canonical equity/fills/trades
for the harness. Backtrader, zipline, quantstrat, and LEAN have
different native setup, calendar, result, and trade-surface behavior.

The B2 row in the peer report can be compared to Backtrader only inside
that report’s fixture and phase definitions. It should never be
rewritten as a broad peer ranking without the opt-in, memory-backed,
spot-FIFO, same-host, same fixture, and phase-boundary caveats.

Source:

- `../../../dev/bench/peer_benchmark/peer_benchmark.md`
- `../../../dev/bench/peer_benchmark/README.md`
- `../../../dev/bench/peer_benchmark/notes/ledgr_regression_source_analysis.md`
- `../../../dev/bench/peer_benchmark/notes/backtrader_scale_check.md`

## Safe Internal Language

Safe internal summaries:

- “v0.1.8.7 established lane-level attribution and same-host peer
  caveats.”
- “v0.1.8.8 made peer timing phase-explicit and kept parallel sweep
  dispatch deterministic with discard-all interruption.”
- “v0.1.8.9 removed measured R hot-path costs and materially improved
  the high-density workload-grid rows under same-host records.”
- “v0.1.8.10 split the story: canonical R gained substrate and phase
  visibility, while B2 passed as a scoped memory-backed spot-FIFO
  opt-in.”
- “The current peer report includes a B2 sidecar row with lower measured
  wall and engine time than the local Backtrader row on that fixture,
  but only under its explicit opt-in, same-host, phase-defined
  boundary.”

Avoid:

- Unqualified peer-ranking language.
- “B2 is the new ledgr engine.”
- “compiled ledgr is the default.”
- “durable runs use B2.”
- “spot-FIFO covers derivatives, margin, options, or shorts.”
- “v0.1.8.10 made all ledgr paths faster.”
- “The peer benchmark proves general engine superiority.”

## Implementation Trace

This trace gives maintainers the code-level map behind the performance
narrative. It does not authorize new optimization work; it identifies
where the current local records are produced, how phase columns are
derived, and which production mechanisms explain the v0.1.8.7 to
v0.1.8.10 arc.

### Data Structures

The self-profiling harness writes row-level and summary data under
`dev/bench/results/` by default. `dev/bench/shared/run_benchmarks.R:16`
defines the argument shape, including `preset`, `out_dir`, repeat
counts, scenario filters, seed, and optional
`compiled_accounting_model`. The output record stem is built at
`dev/bench/shared/run_benchmarks.R:695`; the harness writes `_raw.csv`,
`_summary.csv`, `_environment.json`, `_results.json`, `_summary.md`, and
optional `_lean_side_by_side.csv` at
`dev/bench/shared/run_benchmarks.R:699`.

The row schema for committed-run benchmark cells is assembled at
`dev/bench/shared/run_benchmarks.R:432`. The load-bearing columns are
`snapshot_sec`, `t_pre_sec`, `t_loop_sec`, `engine_sec`, `results_sec`,
`t_wall_sec`, extraction timings, event/fill counts, and per-fill rates
such as `mus_per_fill_engine` and `mus_per_fill_extract`. Sweep cells
use the same shape at `dev/bench/shared/run_benchmarks.R:538`, but
source phase data from candidate telemetry: `t_engine`, `t_results`, and
`t_fills_extract` are summed at `dev/bench/shared/run_benchmarks.R:533`.

The peer harness uses a separate result model.
`dev/bench/peer_benchmark/peer_benchmark.R:12` defines the peer
arguments, and `dev/bench/peer_benchmark/peer_benchmark.R:1071` writes
per-engine metadata, equity, fills, trades, divergence, status, parity,
performance, environment, history, and markdown artifacts. The peer
performance row shape is at
`dev/bench/peer_benchmark/peer_benchmark.R:798`: it records
`full_row_sec`, `reported_core_sec`, `ingestion_sec`, `engine_sec`,
`results_sec`, harness overhead, bars/sec, and the declared boundary
string.

### Code Anchors

| Boundary | Code anchor |
|----|----|
| Self-profiling argument and record destination | `dev/bench/shared/run_benchmarks.R:16` |
| Committed-run phase extraction | `dev/bench/shared/run_benchmarks.R:311` reads run telemetry; `dev/bench/shared/run_benchmarks.R:425` splits wall into pre, loop, and residual. |
| Committed-run per-fill rates | `dev/bench/shared/run_benchmarks.R:462` computes engine microseconds per fill; `dev/bench/shared/run_benchmarks.R:467` computes fill-extraction microseconds per fill. |
| Sweep phase extraction | `dev/bench/shared/run_benchmarks.R:533` sums `t_engine`, `t_results`, and `t_fills_extract`. |
| Self-profiling record writes | `dev/bench/shared/run_benchmarks.R:695` through `dev/bench/shared/run_benchmarks.R:724`. |
| Peer phase definitions | `dev/bench/peer_benchmark/peer_benchmark.R:783` names the timing boundary per engine. |
| Peer performance rows | `dev/bench/peer_benchmark/peer_benchmark.R:798` through `dev/bench/peer_benchmark/peer_benchmark.R:824`. |
| Peer parity and divergence attribution | `dev/bench/peer_benchmark/peer_benchmark.R:827` and `dev/bench/peer_benchmark/peer_benchmark.R:1038`. |
| Peer record writes | `dev/bench/peer_benchmark/peer_benchmark.R:1071` through `dev/bench/peer_benchmark/peer_benchmark.R:1126`. |
| Durable event buffering | `R/backtest-runner.R:290` creates pending buffers; `R/backtest-runner.R:511` flushes pending event and strategy-state rows. |
| Shared event-buffer growth | `R/fold-event-buffer.R:7` doubles capacity up to the run maximum. |
| Fill reconstruction primitive buffer | `R/fold-reconstruction.R:155` creates typed fill buffers; `R/fold-reconstruction.R:205` appends with `collapse::setv()`. |
| Memory handler typed events | `R/sweep.R:999` allocates typed columns; `R/sweep.R:1117` materializes rows only when needed. |
| Canonical JSON byte-format v2 | `R/config-canonical-json.R:21` hoists yyjsonr write options; `R/config-canonical-json.R:72` canonicalizes and caches values. |
| Deterministic collapse wrapper | `R/collapse-determinism.R:1` defines the deterministic option state; `R/collapse-determinism.R:15` wraps collapse calls. |
| B2 spot-FIFO opt-in path | `R/sweep.R:94` normalizes the public argument; `R/compiled-spot-fifo.R:62` enforces buffered memory-handler dispatch. |

### Lookup And Dispatch Mechanisms

The self-profiling harness deliberately separates durable committed runs
from sweep rows. `bench_run_scenario_once()` creates a snapshot,
experiment, durable run, and result extraction at
`dev/bench/shared/run_benchmarks.R:355`. Its engine phase is the fold
loop telemetry, not the whole wall-clock row. `bench_run_sweep_once()`
starts at `dev/bench/shared/run_benchmarks.R:479`; it calls
`ledgr_sweep()` at `dev/bench/shared/run_benchmarks.R:520`, then reads
candidate `t_engine`, `t_results`, and `t_fills_extract` columns.

The peer harness dispatches one shared bars CSV into multiple surfaces.
It writes the shared bars at
`dev/bench/peer_benchmark/peer_benchmark.R:1252`, runs durable ledgr at
`dev/bench/peer_benchmark/peer_benchmark.R:1261`, runs the memory-backed
ledgr row at `dev/bench/peer_benchmark/peer_benchmark.R:1268`,
optionally runs the B2 sidecar at
`dev/bench/peer_benchmark/peer_benchmark.R:1277`, and then runs built-in
SMA, quantstrat, Backtrader, zipline, and LEAN rows at
`dev/bench/peer_benchmark/peer_benchmark.R:1288`.

The lane-attribution mechanism is not a hidden profiler. It is a release
discipline: packet closeouts tie measured deltas to named code lanes,
and the harness records keep enough phase columns to check those claims.
The current manual should therefore point to `per_lane_attribution.md`,
release closeouts, and the harness code rather than restating old
headline numbers.

### Edge Cases

Benchmark rows are local evidence. The harness says this directly in
`dev/bench/shared/run_benchmarks.R:5` and
`dev/bench/peer_benchmark/peer_benchmark.R:3`. Do not promote ignored
`dev/bench/results/` records into package artifacts without new release
scope.

Phase columns are not interchangeable across engines. Peer boundaries
are declared per engine at
`dev/bench/peer_benchmark/peer_benchmark.R:783`; ledgr durable, ledgr
ephemeral, Backtrader, zipline, quantstrat, and LEAN include different
native setup and materialization work. Missing peer surfaces are
reported as unavailable, not imputed, through the metadata and boundary
checks around `dev/bench/peer_benchmark/peer_benchmark.R:700`.

B2 is opt-in and scope-guarded. A benchmark row with
`compiled_accounting_model = "spot_fifo"` does not change default
execution. Unsupported B2 requests fail in `R/compiled-spot-fifo.R:1` or
`R/compiled-spot-fifo.R:47`; they do not silently convert durable runs
into a compiled path.

Per-fill costs decompose into engine cost and materialization cost. A
decrease in `mus_per_fill_extract` is evidence about result extraction;
it is not automatically evidence that the fold loop became cheaper.
Conversely, a lower `engine_sec` for B2 says something about the scoped
memory-backed spot-FIFO hot frame, not about durable `ledgr_run()`.

### Hot And Cold Paths

Cold benchmark work includes bars generation, CSV reads, snapshot
creation, feature setup, experiment construction, peer engine setup,
metadata writing, and markdown rendering. Self-profiling rows keep
snapshot and extraction columns so these costs can be separated from the
fold.

The hot ledgr engine path is the fold loop described in
`execution_fold_core.qmd`. The v0.1.8.7 to v0.1.8.10 mechanisms that
matter for hot-path interpretation are:

- event-buffer growth and pending flushes, anchored in
  `R/fold-event-buffer.R:7` and `R/backtest-runner.R:511`;
- primitive fill reconstruction and collapse-assisted writes, anchored
  in `R/fold-reconstruction.R:155` and `R/fold-reconstruction.R:205`;
- memory-handler typed columns and deferred JSON materialization,
  anchored in `R/sweep.R:999` and `R/sweep.R:1117`;
- canonical JSON byte-format v2 and option hoisting, anchored in
  `R/config-canonical-json.R:21` and `R/config-canonical-json.R:72`;
- collapse determinism, anchored in `R/collapse-determinism.R:1`;
- B2 spot-FIFO batch dispatch, anchored in `R/compiled-spot-fifo.R:139`.

Warm result paths sit between engine and reporting. For sweeps, the
result phase starts at `R/sweep.R:941`; for durable runs,
`ledgr_results()` extraction is measured by `bench_extract_result()` at
`dev/bench/shared/run_benchmarks.R:335`.

### Concrete Examples

A self-profiling raw row has this conceptual shape:

``` r
data.frame(
  scenario = "density_xlarge_high_durable",
  kind = "run",
  n_inst = 500L,
  n_pulses = 1260L,
  compiled_accounting_model = "NULL",
  snapshot_sec = 0.42,
  engine_sec = 12.3,
  results_sec = 1.8,
  t_wall_sec = 14.9,
  fills = 133000,
  mus_per_fill_engine = 92.5,
  mus_per_fill_extract = 13.5
)
```

A peer performance row has a different shape and boundary:

``` r
data.frame(
  engine = "backtrader",
  full_row_sec = 8.4,
  ingestion_sec = 1.2,
  engine_sec = 6.7,
  results_sec = 0.5,
  boundary = "ingestion=bars CSV read, PandasData feed construction..."
)
```

Those rows can support a careful internal comparison only after the
article states which fixture, phase, surface, and host produced them.

## Maintainer Checklist

Before using a performance number in docs, tickets, or release text:

- Link the packet closeout or benchmark report that owns the number.
- State whether the row is canonical R, memory-backed, durable, or B2
  opt-in.
- State whether the number is wall, engine, results, or per-fill.
- Keep workload-grid and peer-benchmark shapes separate.
- Keep default behavior separate from opt-in behavior.
- Preserve same-host/current-source/machine-specific caveats.
- Confirm parity or explain the comparison surface.
- Avoid public speed ranking language unless a future packet explicitly
  scopes a public benchmark artifact.

## Source Links

- `../../../dev/bench/README.md`
- `../../../dev/bench/peer_benchmark/peer_benchmark.md`
- `../ledgr_v0_1_8_7_spec_packet/benchmark_attribution_closeout.md`
- `../ledgr_v0_1_8_8_spec_packet/parallel_sweep_measurement_closeout.md`
- `../ledgr_v0_1_8_8_spec_packet/peer_benchmark_parity_closeout.md`
- `../ledgr_v0_1_8_9_spec_packet/per_lane_attribution.md`
- `../ledgr_v0_1_8_9_spec_packet/v0_1_8_9_release_closeout.md`
- `../ledgr_v0_1_8_10_spec_packet/per_lane_attribution.md`
- `../ledgr_v0_1_8_10_spec_packet/v0_1_8_10_release_closeout.md`
- `../horizon.md` (2026-06-02 `[architecture]` B2 spot-FIFO accelerator
  scope guard)
- `../rfc/rfc_compiled_hot_frame_b2_v0_1_9_x_maintainer_decisions.md`
  (Decision 2 narrowing)

## Where Next

- For execution boundaries, see `execution_fold_core.qmd`.
- For current peer harness details, see
  `../../../dev/bench/peer_benchmark/peer_benchmark.md`.
- For binding B2 scope, see `../horizon.md` (2026-06-02 `[architecture]`
  B2 spot-FIFO accelerator scope guard) and `../contracts.md`.
