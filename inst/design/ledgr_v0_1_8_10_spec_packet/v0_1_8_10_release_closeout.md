# v0.1.8.10 Measurement Closeout

Status: Completed
Created: 2026-06-02
Scope: v0.1.8.9 to v0.1.8.10 local benchmark comparison

This closeout records the local, current-source measurement verdict for the
v0.1.8.10 substrate/accounting round. It is not a public benchmark claim and
should not be quoted as a hosted or cross-machine speed ranking. Within-run
phase shares and same-shape parity are the load-bearing evidence; wall-to-wall
deltas are same-host sanity checks.

The v0.1.8.10 speed story has two different surfaces that must not be mixed:

- **Canonical R default path:** the public/default path remains the R fold.
  Fold-owned FIFO accounting moved work into the fold engine and made the
  fresh ephemeral path phase-visible, but canonical R is not the headline speed
  win.
- **B2 spot-FIFO public opt-in:** `compiled_accounting_model = "spot_fifo"`
  is a scoped, explicit opt-in for the memory-backed sweep / ephemeral
  spot-asset FIFO fill-batch accelerator. It is not default compiled execution,
  not durable compiled integration, not derivatives-capable accounting, and not
  a general compiled fold core.

## Source Records

v0.1.8.9 closeout baseline:

- Workload grid:
  `dev/bench/results/ledgr_bench_record_20260601T065635Z_summary.csv`
- Peer benchmark:
  `dev/bench/results/peer_benchmark_record_20260601T073325Z_*`
- Prior closeout:
  `inst/design/ledgr_v0_1_8_9_spec_packet/v0_1_8_9_release_closeout.md`

v0.1.8.10 closeout records:

- Canonical workload grid:
  `dev/bench/results/ledgr_bench_record_20260602T155628Z_summary.csv`
- Seed-matched B2 xlarge ephemeral gate:
  `dev/bench/results/ledgr_bench_record_20260602T162911Z_summary.csv`
- Peer benchmark:
  `dev/bench/results/peer_benchmark_record_20260602T162318Z_*`
- Per-lane attribution:
  `inst/design/ledgr_v0_1_8_10_spec_packet/per_lane_attribution.md`

The Batch 5 B2 review record
`dev/bench/results/ledgr_bench_record_20260602T134953Z_summary.csv` measured
the same B2 surface at seed `20260528` and passed the RFC threshold matrix. The
closeout reran the single B2 xlarge ephemeral cell at seed `20260531` so the B2
comparison aligns with the v0.1.8.9 and v0.1.8.10 workload-grid closeout
records.

## Per-Lane Attribution Summary

| Ticket | Lane | Load-bearing measured result | Closeout disposition |
| --- | --- | --- | --- |
| `LDG-2518` | Ephemeral subphase telemetry | Ephemeral workload-grid rows now expose `engine_sec`, `results_sec`, and `fills_extract_sec`; xlarge ephemeral canonical closeout shows 375.14s wall / 342.25s engine / 0.00s results | Delivered as measurement infrastructure; not a wall-recovery lane |
| `LDG-2519` | Matrix-canonical substrate and strategy accessors | `ctx$idx()`, `ctx$vec`, primitive internal positions, and matrix-backed next-bar lookup landed with scalar compatibility preserved | Delivered as substrate/contract lane; wall recovery folded into later lanes |
| `LDG-2520` | Fold-owned FIFO accounting and inline state capture | Fresh ephemeral summaries can bypass reconstruction; canonical R xlarge durable shows FIFO work moved into engine (199.06s -> 319.22s engine on xlarge durable) | Delivered as accounting-ownership substrate; canonical R xlarge durable regression is expected and recorded |
| `LDG-2521` | yyjsonr options hoist | 50k `meta_json` helper benchmark improved 22.00 -> 2.40 us/payload (9.17x) | Delivered; helper/read/replay surface, not fresh-fold wall claim |
| `LDG-2522` | B2 spot-FIFO fill-batch gate | Seed-matched xlarge ephemeral wall 375.14s -> 67.32s with same 66,419 fills and zero failures; engine 342.25s -> 32.66s | Pass for scoped spot-asset FIFO accelerator gate |
| `LDG-2523` | Parked spike disposition | Split bucket, reusable ctx env, pulse-seed mixer, and alias-map normalization dispositions recorded | No code lane; small spikes parked, routed, or covered by landed accessors |
| `LDG-2526` | B2 public opt-in promotion | Public `ledgr_sweep(..., compiled_accounting_model = "spot_fifo")` routes to the scoped memory-backed spot-FIFO path; durable `ledgr_run(..., "spot_fifo")` fails closed | Completed; public opt-in only, default remains canonical R |

The final closeout workload run differs from individual per-lane records because
it was run as a full record preset after the lanes landed. It should be read as
the round-level same-host comparison, not as a replacement for lane-by-lane
attribution.

## Workload Grid: Canonical R Default Path

The canonical workload-grid record uses the public/default R path
(`compiled_accounting_model = NULL`). It is the right comparison for public
default behavior.

| Scenario | v0.1.8.9 wall s | v0.1.8.10 canonical wall s | Delta s | Delta % | v0.1.8.9 engine s | v0.1.8.10 engine s | v0.1.8.9 results s | v0.1.8.10 results s |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `density_high_xlarge_durable` | 232.03 | 362.37 | +130.34 | +56.2% | 199.06 | 319.22 | 30.72 | 40.94 |
| `density_high_xlarge_ephemeral` | 372.55 | 375.14 | +2.59 | +0.7% | NA | 342.25 | NA | 0.00 |
| `density_high_large_durable` | 85.12 | 82.27 | -2.85 | -3.3% | 68.88 | 68.38 | 14.95 | 13.25 |
| `density_high_large_ephemeral` | 101.58 | 102.97 | +1.39 | +1.4% | NA | 86.73 | NA | 0.02 |
| `density_low_xlarge_durable` | 35.73 | 35.81 | +0.08 | +0.2% | 15.13 | 16.29 | 17.98 | 17.74 |
| `density_low_xlarge_ephemeral` | 48.11 | 49.05 | +0.94 | +2.0% | NA | 17.92 | NA | 0.02 |

Per-fill costs for durable headline cells:

| Scenario | Engine us/fill v0.1.8.9 | Engine us/fill v0.1.8.10 | Extract us/fill v0.1.8.9 | Extract us/fill v0.1.8.10 |
| --- | ---: | ---: | ---: | ---: |
| `density_high_xlarge_durable` | 1494.95 | 2397.36 | 175.43 | 309.55 |
| `density_high_large_durable` | 1011.48 | 1004.14 | 149.49 | 113.07 |
| `density_low_xlarge_durable` | 625.98 | 673.98 | 164.67 | 129.09 |

Interpretation:

- The xlarge durable canonical R regression is real and expected. `LDG-2520`
  moved FIFO accounting into the fold engine so accounting becomes fold-owned
  and compilable, but R now pays that FIFO cost inside the loop.
- The xlarge ephemeral canonical path is essentially flat versus v0.1.8.9
  (+0.7%) while now exposing a load-bearing engine phase. The results phase is
  near zero because fresh ephemeral summaries use inline facts instead of the
  old reconstruction path.
- Large and low-density cells remain roughly flat or slightly improved. The
  regression is concentrated in the high-density xlarge durable stress cell.

## B2 Spot-FIFO Public Opt-In Gate

The B2 row is not default behavior. It is the explicit
`compiled_accounting_model = "spot_fifo"` opt-in for the memory-backed
spot-asset FIFO fill-batch hot frame. Committed durable runs still use the
canonical R path and fail closed for `"spot_fifo"` until a separate durable
compiled-integration gate lands.

Seed-matched xlarge ephemeral record, `density_high_xlarge_ephemeral`,
seed `20260531`:

| Model | Record | Wall s | Engine s | Results s | Fills | Engine us/fill | Failures |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Canonical R (`NULL`) | `dev/bench/results/ledgr_bench_record_20260602T155628Z_summary.csv` | 375.14 | 342.25 | 0.00 | 66,419 | 5152.89 | 0 |
| B2 spot-FIFO opt-in (`"spot_fifo"`) | `dev/bench/results/ledgr_bench_record_20260602T162911Z_summary.csv` | 67.32 | 32.66 | 0.02 | 66,419 | 491.73 | 0 |

Outcome:

- Wall fell 375.14s -> 67.32s: B2 wall is 17.9% of canonical R, an 82.1%
  reduction.
- Engine fell 342.25s -> 32.66s: B2 engine is 9.5% of canonical R, a 90.5%
  reduction.
- Fill count and failure count match exactly on the seed-matched record.
- This is a pass for the scoped spot-asset FIFO accelerator gate and supports
  the LDG-2526 memory-backed sweep opt-in. It does not authorize default
  compiled promotion, durable compiled integration, derivatives/margin/options
  accounting, CRAN readiness, or a general compiled fold core.

## Peer Benchmark Comparison

Peer benchmark shape: 500 instruments, 1260 bars, SMA 5/10, local same-host
current source. The table uses `phase_total_sec` as the comparable total
(ingestion + engine + results), matching the v0.1.8.9 closeout method.

| Engine | v0.1.8.9 total s | v0.1.8.10 total s | v0.1.8.9 engine s | v0.1.8.10 engine s | v0.1.8.9 results s | v0.1.8.10 results s |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `ledgr_ttr_canonical` | 118.79 | 115.09 | 88.00 | 86.58 | 10.64 | 8.73 |
| `ledgr_ttr_canonical_ephemeral` | 92.61 | 99.92 | 71.62 | 79.39 | 9.63 | 9.46 |
| `ledgr_builtin_sma` | 110.80 | 107.44 | 81.95 | 80.96 | 9.71 | 7.48 |
| `backtrader` | 79.34 | 79.36 | 78.53 | 78.54 | 0.15 | 0.15 |
| `zipline-reloaded-full` | 298.84 | 302.35 | 281.46 | 284.63 | 0.45 | 0.46 |
| `quantstrat` | 511.80 | 815.36 | 499.82 | 801.03 | 1.35 | 1.37 |
| `LEAN` | UNAVAILABLE | UNAVAILABLE | NA | NA | NA | NA |

For ledgr durable, total wall improved 118.79s -> 115.09s and engine-only time
improved 88.00s -> 86.58s on the peer shape. Backtrader was effectively flat:
79.34s -> 79.36s total and 78.53s -> 78.54s engine. On this local
phase-separated record, ledgr durable engine-only is 1.10x Backtrader; total
wall is 1.45x Backtrader.

The peer ephemeral ledgr row regressed modestly, 92.61s -> 99.92s total and
71.62s -> 79.39s engine. The separate B2 peer-shaped row in the rewritten peer
report uses `compiled_accounting_model = "spot_fifo"` and measured 37.09s core
wall / 15.77s engine with exact canonical ledgr parity on parsed equity, cash,
and position proxy outputs. Do not mix this peer B2 row with the workload-grid
B2 gate: they are different shapes and different execution-surface questions.

Quantstrat was materially slower in this rerun while Backtrader and zipline
were essentially flat. Treat that as local comparator drift for this record,
not as a ledgr release claim.

## Parity And Availability

Peer parity retained the expected shape:

- `ledgr_ttr_canonical_ephemeral` matched durable with
  `equity_cor = 1.000000`, `return_cor = 1.000000`, and max single-bar
  divergence at floating-noise scale.
- `ledgr_builtin_sma` matched the canonical ledgr row exactly.
- Backtrader, zipline, and quantstrat retained the known peer-level parity
  profile and remain comparator rows, not source-of-truth rows.
- LEAN remained unavailable. The current local error is an old Lean CLI root
  folder requiring `lean init`; this is an availability boundary, not a ledgr
  parity result.

The workload-grid closeout records report zero failures on the headline
large/xlarge durable, ephemeral, and B2 cells.

## Parked Spikes And Deferred Work

`LDG-2523` closed the four parked spike outputs:

1. Split/gsplit reconstruction bucket: parked as fallback-only
   collapse-doctrine cleanup if reconstruction becomes hot again.
2. Reusable pulse-context env: parked; future work should profile helper
   attachment directly, not public ctx env reuse.
3. Pulse-seed mixer: parked below threshold; future implementation needs
   explicit cross-platform determinism parity.
4. Alias-map normalization: no standalone ticket. `ctx$vec$feature(feature_id)`
   covers the hot cross-sectional pattern, while legacy `ctx$features()` alias
   behavior remains supported and alias-map vector interactions remain future
   feature-engine extension work.

Future routing:

- Default compiled promotion and durable compiled integration require separate
  future gates. v0.1.8.10 ships only the scoped memory-backed sweep opt-in.
- Derivatives, margin, options, or non-spot accounting require separate
  accounting-model values, RFC scope, and parity gates. The spot-FIFO kernel
  must not be extended into those models.
- Ephemeral wall attribution remains useful for the non-B2 residual wall:
  strategy callback, ctx helper attachment, feature engine, output-handler
  residual, and other non-FIFO subframes are still the unexplained share.
- Documentation and architecture synthesis work is planned separately; it is
  not part of the v0.1.8.10 release gate.

## Closeout Verdict

v0.1.8.10 succeeds as a substrate/accounting and scoped B2 opt-in round, not as
a public default-speed release:

- The canonical R default path is more honest and more measurable after
  fold-owned FIFO accounting, but high-density xlarge durable regressed because
  R now pays FIFO inside the fold.
- Fresh ephemeral canonical wall is roughly flat versus v0.1.8.9 and now
  phase-visible.
- The B2 spot-FIFO opt-in is the major speed result: 375.14s -> 67.32s on
  seed-matched xlarge ephemeral, with identical fill count and zero failures.
- The peer benchmark remains local-host/current-source only. It confirms ledgr
  durable is roughly flat-to-slightly-faster on the peer shape and stays near
  Backtrader engine time, but it is not a public ranking.

The release gate (`LDG-2525`) should verify this closeout, run the final
test/check surface, update NEWS with scoped B2 opt-in language, and confirm
generated benchmark/build artifacts are not committed.
