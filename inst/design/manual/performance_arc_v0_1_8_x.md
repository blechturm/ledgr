# Performance Arc v0.1.8.7 To v0.1.8.10


**Status:** Reviewable maintainer-manual article for LDG-2534.

**Authority:** Synthesis only. Binding scope remains in the versioned
spec packets, release closeouts, benchmark records, RFCs, ADRs, and
contracts linked below.

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
- `../horizon.md` (2026-06-02 `[architecture]` B2 spot-FIFO accelerator scope guard)
- `../rfc/rfc_compiled_hot_frame_b2_v0_1_9_x_maintainer_decisions.md` (Decision 2 narrowing)
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
- `../horizon.md` (2026-06-02 `[architecture]` B2 spot-FIFO accelerator scope guard)
- `../rfc/rfc_compiled_hot_frame_b2_v0_1_9_x_maintainer_decisions.md` (Decision 2 narrowing)

## Where Next

- For execution boundaries, see `execution_fold_core.qmd`.
- For current peer harness details, see
  `../../../dev/bench/peer_benchmark/peer_benchmark.md`.
- For binding B2 scope, see `../horizon.md` (2026-06-02 `[architecture]` B2 spot-FIFO accelerator scope guard) and `../contracts.md`.
