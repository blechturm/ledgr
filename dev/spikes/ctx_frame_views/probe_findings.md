# Context frame views: memory share and on-demand cost

**2026-10-04 / Claude, for the maintainer.** Stage-1 probe. Binds no design.

**Question:** Do the fold's precomputed per-pulse frame views (`ctx$bars`,
`ctx$feature_table`, `ctx$features_wide`) hold a material share of
product-path peak memory, and can they be built on demand from the prepared
primitives exactly and cheaply?

**Gate:** before the probe, the agent proposed to the maintainer that the work
be pulled into v0.2.2 if the views hold at least 20% of peak. The agent's own
stop line was 10%: below it, no paired fork is built.

**Tree:** `ff04a32`, a clean clone. R 4.6.1, collapse 2.1.8, duckdb 1.5.6.9000.
**Shape:** 757 pulses, 600 instruments, three returns features (the Workstream
11 orientation shape).
- **Availability run:** 500 members, monthly top-10 momentum read through
  `ctx$vec`.
- **Dense run:** the same bars; the strategy reads `ctx$features_wide` on every
  pulse.

**Scripts:** `probe.R` (share, identity, cost) and `probe_attribution.R`
(heap by phase plus the largest objects).

## Results

| Measure | Availability | Dense, wide reader |
| --- | ---: | ---: |
| R-heap peak during run (`gc()` max used) | 596 MiB | 795 MiB |
| Prebuilt bar views (`gc()` allocation delta) | 30.3 MiB | 30.1 MiB |
| Prebuilt feature views | 14.3 MiB | 14.5 MiB |
| Views' share of R-heap peak | **7.5%** | **5.6%** |
| On-demand frames `identical()` to prebuilt, every pulse | yes | yes |
| On-demand bars + wide frame | 41 µs/pulse, 31 ms/run | 43 µs/pulse, 32 ms/run |

**The long table isn't stored in runs.** The fold calls
`ledgr_projection_pulse_views()` in "schema" mode, so every pulse shares one
empty long-table frame. The in-run views are `bars` and `features_wide` only.
An earlier `object.size()` estimate (215 KiB per pulse) overstated them by
about 2.5×: it counted repeated strings once per element and included the
long table.

**Attribution** (availability run, live heap after full `gc()`):

| Point | Live heap | Max used |
| --- | ---: | ---: |
| Before run | 112 MiB | 112 MiB |
| Fold entry | 361 MiB | 530 MiB |
| Fold exit | 379 MiB | 634 MiB |
| After run | 210 MiB | 634 MiB |

At fold entry, the largest reachable objects by `object.size()` are:
- the dead hydration intermediates LDG-2951 targets: `raw_bars_by_id` 33,
  `bars_by_id` 31, `bars_all` 30, `bars_cols_by_id` 30 (shares columns),
  `run_feature_series` 11 and `run_feature_matrix` 10 MiB;
- prebuilt bar views 55 by `object.size()`, 30 by allocation;
- `bars_mat` 22, projection 11 and feature cache 11 MiB.

## What was learned

1. **Red on memory.** The views hold 6–8% of peak, below both the 20% pull-in gate and the 10% stop line.
   Linear extrapolation gives about 0.5–0.8 GB at EXP-0003 scale. That's real
   but not the main block, and on memory grounds alone it doesn't justify
   retiring them.
2. **Green on cost and exactness.** Bare-constructor builders over `bars_mat`
   and the projection reproduce every prebuilt frame bit for bit, at about
   0.2% of run time. The v0.1.8.3 pulse-view spike's reason for prebuilding (slow
   per-pulse construction, amortized over a 4-instrument sweep) no longer
   holds at realistic width.
3. **Peak is dominated by preparation churn.** About 40% of peak is
   transient allocation, not live state: max used is 634 MiB against at most
   379 MiB live. Hydration alone reaches 530 MiB. Cut 5's dead-object release
   and staged release at each object's last read (LDG-2951 review P6) target
   this directly; the views do not.
4. **The pattern is sound for history panels.** Slicing prepared matrices into
   frames on demand costs about 20 µs per 600-wide frame, so one prepared
   representation with on-demand views is cheap.

## Builder micro-benchmark (`frame_builder_bench.R`)

Synthetic matrices, 600 instruments, three features, one pulse, 2,000
repetitions. These are not fold measurements.

| Construction | Median per pulse |
| --- | ---: |
| Prebuilt-list lookup (today) | 0.4 µs |
| One `ctx$vec`-style column read | 1.3 µs |
| Wide frame via base `data.frame()` | 138 µs |
| Wide frame via `collapse::qDF()` | 13.9 µs |
| Wide frame via bare constructor (`ledgr_fast_data_frame()` shape) | 11.5 µs |
| Long table via bare constructor | 27.9 µs |
| Bars frame via bare constructor | 14.2 µs |

`collapse::qDF()` and the bare constructor avoid `data.frame()`'s roughly 10×
overhead. The column slice is the remaining cost.

## Surface census at `ff04a32` (grep, not a call graph)

- Articles (`vignettes/*.qmd`): 0 uses of `ctx$bars`, `ctx$feature_table` or
  `ctx$features_wide`, against 48 uses of `ctx$vec$`.
- Tests: 21, 17 and 18 uses respectively.
- `dev/bench`: 10 uses of `ctx$features_wide` (peer benchmark).
- Internals: availability runs build their accessors from these frames
  (`R/pulse-context.R:260`, `:344`, `:480`), because the fast context is
  dense-only (`R/backtest-runner.R:907`).

## What the spec may consume

- On-demand frame construction is exact and cheap. Treat retiring or demoting
  the frames as a surface and UX decision for the inspection-boundary seed,
  not as a memory lever.
- Memory work should target hydration churn and dead intermediates first.

## Open

- These are R-heap measurements. Process RSS also includes DuckDB, so the
  views' RSS share is lower still.
- The paired fork was not built because the 10% stop line fired.
- Which allocations make up the 255 MiB of transient churn has not been
  attributed. That is the recharter question.

## Maintainer disposition (2026-10-04)

Not pulled into v0.2.2. The next version retires the precomputed per-pulse
frame representations from `ctx` and replaces them with explicit strategy
helpers that build long and wide frames from the `ctx$vec` primitives, using
the collapse/bare-constructor pattern measured here. Routing:
[RFC pipeline `ctx-frame-retirement`](../../../inst/design/rfc/README.md#ctx-frame-retirement).
