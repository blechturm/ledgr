# v0.1.8.9 Measurement Closeout

Status: Batch 8 review candidate
Created: 2026-06-01
Scope: v0.1.8.8 to v0.1.8.9 local benchmark comparison

This closeout records the local, current-source measurement verdict for the
v0.1.8.9 optimization round. It is not a public benchmark claim and should not
be quoted as a hosted or cross-machine speed ranking. Within-run phase shares
and per-fill costs are the load-bearing evidence; wall-to-wall deltas are a
same-host sanity check.

## Source Records

Baseline records:

- Workload grid: `dev/bench/results/ledgr_bench_record_20260531T132910Z_summary.csv`
- Peer benchmark: `dev/bench/results/peer_benchmark_record_20260531T114451Z_*`
- Per-lane attribution: `inst/design/ledgr_v0_1_8_9_spec_packet/per_lane_attribution.md`

v0.1.8.9 closeout records:

- Workload grid: `dev/bench/results/ledgr_bench_record_20260601T065635Z_summary.csv`
- Peer benchmark: `dev/bench/results/peer_benchmark_record_20260601T073325Z_*`

The first closeout peer-benchmark attempt,
`peer_benchmark_record_20260601T071132Z`, ran without network escalation and
left Backtrader, zipline, and LEAN unavailable through `uv`. It is superseded by
`peer_benchmark_record_20260601T073325Z`, which restored Backtrader and zipline.
LEAN remained unavailable in both records for the existing LEAN initialization
reason.

## Per-Lane Attribution Summary

| Ticket | Lane | Load-bearing measured result | Closeout disposition |
| --- | --- | --- | --- |
| `LDG-2496` | Fills extractor `setv` | xlarge durable fills extraction 197.11s -> 21.00s during lane attribution; extraction cost 1481.33 -> 157.71 us/fill | Delivered; row-count fallback resolved |
| `LDG-2497` | Persistent durable handler `setv` | xlarge durable wall 410.39s -> 311.85s; loop 377.73s -> 278.07s | Delivered; partial `setv` retained for safe non-character columns |
| `LDG-2498` | Memory output handler `setv` plus routed sweep-summary buffer | xlarge ephemeral wall 508.08s -> 346.63s | Delivered; no public ephemeral API added |
| `LDG-2499` | Position valuation vectorize | xlarge durable loop 278.07s -> 276.18s; alignment fixture passed | Delivered as correctness-preserving scaling cleanup, not a headline wall lane |
| `LDG-2500` | Target-delta vectorize | xlarge durable wall 309.44s -> 287.16s; loop 276.18s -> 253.29s | Delivered; strongest per-pulse vectorization lane |
| `LDG-2501` | yyjsonr and canonical JSON v2 | xlarge durable wall 287.16s -> 267.84s; fills extraction regressed 21.19s -> 25.04s | Delivered; durable write win with read-path caveat |
| `LDG-2502` | Optional cleanup triage | Spike 5 and Spike 3 deferred; fills fallback resolved; Kahan-vs-cumsum attribution corrected | No new code lane; dispositions recorded |

The final closeout workload run differs from individual per-lane records because
it was run as a full record preset after all lanes landed. It should be read as
the round-level comparison, not as a replacement for the lane-by-lane
attribution rows above.

## Workload Grid Comparison

Headline cells:

| Scenario | v0.1.8.8 wall s | v0.1.8.9 wall s | Delta s | Delta % | v0.1.8.8 loop s | v0.1.8.9 loop s | v0.1.8.8 fills extract s | v0.1.8.9 fills extract s |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `density_high_xlarge_durable` | 445.02 | 232.03 | -212.99 | -47.9% | 413.47 | 199.06 | 197.11 | 23.36 |
| `density_high_large_durable` | 153.76 | 85.12 | -68.64 | -44.6% | 138.86 | 68.88 | 82.67 | 10.18 |
| `density_high_xlarge_ephemeral` | 623.87 | 372.55 | -251.32 | -40.3% | NA | NA | NA | NA |
| `density_high_large_ephemeral` | 171.81 | 101.58 | -70.23 | -40.9% | NA | NA | NA | NA |

Per-fill cost:

| Scenario | Engine us/fill v0.1.8.8 | Engine us/fill v0.1.8.9 | Extract us/fill v0.1.8.8 | Extract us/fill v0.1.8.9 |
| --- | ---: | ---: | ---: | ---: |
| `density_high_xlarge_durable` | 3107.33 | 1494.95 | 1481.33 | 175.43 |
| `density_high_large_durable` | 2040.23 | 1011.48 | 1214.65 | 149.49 |
| `density_low_xlarge_durable` | 1538.59 | 625.98 | 750.19 | 164.67 |

Low-density regression cells:

| Scenario | v0.1.8.8 wall s | v0.1.8.9 wall s | Delta s | Delta % | Failures |
| --- | ---: | ---: | ---: | ---: | ---: |
| `density_low_xlarge_durable` | 56.76 | 35.73 | -21.03 | -37.1% | 0 |
| `density_low_xlarge_ephemeral` | 64.77 | 48.11 | -16.66 | -25.7% | 0 |
| `density_low_small_durable` | 4.78 | 0.90 | -3.88 | -81.2% | 0 |
| `density_low_small_ephemeral` | 0.89 | 0.65 | -0.24 | -27.0% | 0 |

The durable xlarge high-density result is the load-bearing release number:
wall fell 212.99s, loop fell 214.41s, and fills extraction fell 173.75s.
The per-fill engine cost fell by 51.9%, from 3107.33 to 1494.95 us/fill.
The per-fill extraction cost fell by 88.2%, from 1481.33 to 175.43 us/fill.

The ephemeral path also improved materially, but the workload-grid harness still
does not expose sweep-row loop/results subphases. Its wall deltas are therefore
honest but less attributable than durable phase metrics. The xlarge ephemeral
row remains slower than durable in the workload grid because the high-density
xlarge sweep path still pays memory-path and reconstruction costs that are not
fully phase-split.

## Peer Benchmark Comparison

Peer benchmark shape: 500 instruments, 1260 bars, SMA 5/10, `set.seed(42L)`,
`nthreads=1L`.

| Engine | v0.1.8.8 wall s | v0.1.8.9 wall s | v0.1.8.8 engine s | v0.1.8.9 engine s | v0.1.8.8 results s | v0.1.8.9 results s | v0.1.8.9 bars/sec |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `ledgr_ttr_canonical` | 242.08 | 118.79 | 138.37 | 88.00 | 83.00 | 10.64 | 5303 |
| `ledgr_ttr_canonical_ephemeral` | 289.62 | 92.61 | 154.75 | 71.62 | 123.90 | 9.63 | 6803 |
| `ledgr_builtin_sma` | 252.22 | 110.80 | 151.97 | 81.95 | 80.56 | 9.71 | 5686 |
| `backtrader` | 80.51 | 79.34 | 79.70 | 78.53 | 0.15 | 0.15 | 7940 |
| `zipline-reloaded-full` | 293.88 | 298.84 | 279.28 | 281.46 | 0.45 | 0.45 | 2108 |
| `quantstrat` | 504.55 | 511.80 | 490.75 | 499.82 | 1.36 | 1.35 | 1231 |
| `LEAN` | UNAVAILABLE | UNAVAILABLE | NA | NA | NA | NA | NA |

For ledgr durable, total wall improved 242.08s -> 118.79s and engine-only time
improved 138.37s -> 88.00s. Backtrader was essentially unchanged at the same
shape, 80.51s -> 79.34s total and 79.70s -> 78.53s engine. On this local
phase-separated record, ledgr durable engine-only moved from 1.74x Backtrader to
1.12x Backtrader. The total wall ratio moved from 3.01x to 1.50x because the
results phase no longer dominates ledgr.

The ephemeral peer row changed direction relative to the v0.1.8.8 closeout: it
is now faster than the durable peer row on this 68k-fill peer shape. That does
not contradict the workload-grid xlarge result. The peer row has a smaller fill
count and a different phase profile; the workload-grid high-density xlarge row
still shows durable as the faster path at the largest stress cell.

## Parity And Availability

The peer benchmark parity gates retained their expected shape:

- `ledgr_ttr_canonical_ephemeral` matched durable structurally with
  `equity_cor = 1.000000`, `return_cor = 1.000000`, and max divergence at
  floating accumulation noise scale.
- `ledgr_builtin_sma` matched the canonical ledgr row exactly.
- Backtrader, zipline, and quantstrat retained the known peer-level parity
  profile and remain comparator rows, not source-of-truth rows.
- LEAN remains unavailable for the known LEAN initialization boundary and is not
  part of the measured comparison.

The workload-grid closeout record reported zero failures on the headline large
and xlarge durable and ephemeral cells.

## Residual Targets

v0.1.8.9 removed the large pure-R per-row buffer-write pathologies and flattened
the per-pulse target/position scan costs enough that the remaining question is
not "optimize the same bug again." The residual targets are different:

1. R-side substrate and data structures: typed `state$positions`, matrix-shaped
   next-bar access, and reusable pulse-context surfaces should be considered
   before a compiled core.
2. Ephemeral phase visibility: the workload-grid sweep rows need better phase
   telemetry if future ephemeral work is going to be attributed as cleanly as
   durable work.
3. yyjsonr read-path regression: canonical JSON v2 was worthwhile for durable
   writes and dependency consolidation, but nested metadata reads regressed in
   the measured shapes.
4. `ledgrcore` remains a future decision behind a measurement spike. The peer
   benchmark engine gap is now narrow enough that a compiled core should be
   justified by post-substrate measurements, not assumed.

The next release gate (`LDG-2504`) should verify this closeout, run the required
test/check surface, and ensure no generated benchmark artifacts are committed.
