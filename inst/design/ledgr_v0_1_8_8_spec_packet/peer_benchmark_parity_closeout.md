# Peer Benchmark Closeout

Status: LDG-2476 follow-up record closeout  
Created: 2026-05-30  
Updated: 2026-05-31  
Scope: v0.1.8.8 LDG-2476 follow-up note for the v0.1.9 peer-benchmark track

This is an internal maintainer artifact. It is not package documentation, not
pkgdown content, and not a public speed-ranking claim.

## Headline Findings

The three-phase decomposition is the main v0.1.9 input from this follow-up. The
single wall-time number hid two different questions: engine-loop cost and result
materialization cost.

On the 500 x 1260 SMA 5/10 crossover shape, the engine-only comparison is:

| Engine | Engine s | us/bar | Ratio to Backtrader |
| --- | ---: | ---: | ---: |
| backtrader | 79.704 | 127 | 1.00x |
| ledgr_ttr_canonical | 138.370 | 220 | 1.74x |
| ledgr_builtin_sma | 151.970 | 241 | 1.91x |
| ledgr_ttr_canonical_ephemeral | 154.750 | 246 | 1.94x |
| zipline-reloaded-full | 279.278 | 443 | 3.50x |
| quantstrat | 490.750 | 779 | 6.16x |

The headline wall-time gap to Backtrader decomposes into two roughly separate
surfaces: ledgr durable engine execution is 1.74x slower than Backtrader on this
high-turnover shape, and ledgr durable result materialization adds 83.000s while
Backtrader result writing adds 0.153s because Backtrader captures fills inline.

The ephemeral ledgr path is not currently a fast path. It is 47.540s, or 19.6%,
slower than durable ledgr on this workload:

| Phase | Durable s | Ephemeral s | Delta s |
| --- | ---: | ---: | ---: |
| Ingestion | 20.710 | 10.970 | -9.740 |
| Engine | 138.370 | 154.750 | +16.380 |
| Results | 83.000 | 123.900 | +40.900 |
| Total | 242.080 | 289.620 | +47.540 |

That invalidates the working assumption that skipping durable ledgr persistence
would automatically expose a faster engine path. On this high-fill-density
workload, the durable DuckDB-backed path is the more efficient ledgr path. The
v0.1.9 optimization stack therefore needs two explicit lanes in addition to the
existing fills read-back and fill-throughput targets: memory output-handler
per-fill cost and in-memory event-stream reconstruction.

## Artifacts

Tracked harness/report files:

- `dev/bench/peer_benchmark/peer_benchmark.R`
- `dev/bench/peer_benchmark/peer_benchmark.qmd`
- `dev/bench/peer_benchmark/peer_benchmark.md`
- `dev/bench/peer_benchmark/README.md`
- `dev/bench/peer_benchmark/python/backtrader/`
- `dev/bench/peer_benchmark/python/lean/`
- `dev/bench/peer_benchmark/python/zipline/`
- `dev/bench/peer_benchmark/notes/three_phase_decomposition_design.md`
- `dev/bench/peer_benchmark/notes/three_phase_decomposition_results.md`

Primary ignored local record output prefix:

```text
dev/bench/results/peer_benchmark_record_20260531T114451Z
```

Earlier harness-verification records:

```text
dev/bench/results/peer_benchmark_record_20260530T204838Z
dev/bench/results/peer_benchmark_record_20260530T193515Z
dev/bench/results/peer_benchmark_record_20260530T195754Z
dev/bench/results/peer_benchmark_record_20260530T200716Z
dev/bench/results/peer_benchmark_record_20260530T203420Z
```

Matched historical-shape rerun:

```text
dev/bench/results/ledgr_bench_record_20260530T193039Z
```

Generated local files include status, parity, performance, surface-status,
environment, summary Markdown, canonical per-engine equity/fills/trade files
where available, and:

```text
dev/bench/results/parity_history/v0.1.8.8_record.json
```

## Strategy Semantics

All same-host engines use SMA crossover-event semantics:

- compute fast and slow SMA from the current close;
- enter long on transition from `fast <= slow` to `fast > slow`;
- close on transition from `fast > slow` to `fast <= slow`;
- fill market orders at the next bar open;
- do not fill final-bar target changes.

This replaced the earlier ledgr continuous-condition strategy because continuous
holding and crossover-event strategies answer different questions. Aligning the
event semantics makes parity rows meaningful.

The ledgr crossover strategy in the final record uses vector operations over
`ctx$features_wide`; an earlier per-instrument R loop was removed before the
final record rerun.

## Parity Result

The current record preset uses 500 instruments, 1260 daily bars, and 630,000
total bars.
Parity is computed against `ledgr_ttr_canonical`.

| Peer | Tier 1 | Surface | Equity corr | Max div | Return corr | Trade count diff |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| ledgr_ttr_canonical_ephemeral | pass | equity + fills + realized trades | 1.000000 | 0.000000000001857% | 1.000000 | 0 |
| ledgr_builtin_sma | pass | equity + fills + realized trades | 1.000000 | 0% | 1.000000 | 0 |
| quantstrat | pass | partial: equity + trade count only | 0.999820 | 0.236447% | 0.984103 | 33621 |
| backtrader | pass | equity + fills + realized trades | 0.999997 | 0.076047% | 0.996982 | -332 |
| zipline-reloaded-full | pass | equity + fills + realized trades | 0.999708 | 0.307153% | 0.185355 | -625 |
| LEAN | unavailable | none | NA | NA | NA | NA |

Interpretation:

- ledgr built-in SMA matches the TTR-backed canonical row exactly on this shape.
- ledgr ephemeral uses the same fold core through `ledgr_memory_output_handler`
  and passes the ledgr-to-ledgr gate. Fills match exactly after stripping
  result attributes; equity differs only by sub-1e-8 floating round-trip noise
  from the durable DuckDB path.
- quantstrat passes Tier 1 tolerance, but its surface remains partial because
  this harness currently has account equity and transaction count, not comparable
  realized trade P&L. It is not full trade-level parity.
- Backtrader passes Tier 1 and now emits a canonical fills surface captured from
  `notify_order`.
- LEAN is unavailable in this local run. The harness invokes the real LEAN CLI,
  and `lean --version` verifies the CLI subprocess is reachable, but
  `lean backtest` fails before engine startup because the CLI rejects the
  temporary project root as an old Lean CLI root folder and requires `lean init`
  organization setup. No pandas or version-stamp substitute row is emitted.
- `zipline-reloaded-full` writes a temporary csvdir bundle, ingests it, and runs
  `zipline.run_algorithm()` on a 24/5 calendar. It is a review row because the
  full zipline calendar/history/order boundary diverges from the ledgr canonical
  row on this synthetic daily shape.

## Performance Result

The same record run writes `*_performance.csv` with a three-phase decomposition.
For every DONE row:

```text
Total = ingestion + engine + results
```

The harness aborts if phases do not reconcile to total within 0.5 seconds.

| Engine | Status | Ingestion s | Engine s | Results s | Total s | Bars/sec | us/bar |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| ledgr_ttr_canonical | DONE | 20.710 | 138.370 | 83.000 | 242.080 | 2,602 | 384.3 |
| ledgr_ttr_canonical_ephemeral | DONE | 10.970 | 154.750 | 123.900 | 289.620 | 2,175 | 459.7 |
| ledgr_builtin_sma | DONE | 19.690 | 151.970 | 80.560 | 252.220 | 2,498 | 400.3 |
| quantstrat | DONE | 12.440 | 490.750 | 1.360 | 504.550 | 1,249 | 800.9 |
| backtrader | DONE | 0.655 | 79.704 | 0.153 | 80.512 | 7,825 | 127.8 |
| zipline-reloaded-full | DONE | 14.149 | 279.278 | 0.451 | 293.879 | 2,144 | 466.5 |
| LEAN | UNAVAILABLE | NA | NA | NA | NA | NA | NA |

Phase definitions:

- Ingestion: from timed-window start until the engine has native data structures
  ready to iterate.
- Engine: from ready-to-iterate until strategy execution completes and engine
  state is final.
- Results: from final engine state until canonical equity/fills/trades are
  materialized for this harness.

This is a real local performance benchmark under declared boundaries. It is not
a global engine ranking because the rows intentionally expose different
surfaces. The comparison is now phase-explicit: every DONE engine reports
ingestion, engine, and results separately. LEAN is unavailable rather than
substituted.

Ledgr now appears in two rows. The durable row includes DuckDB snapshot/event-log
surfaces; the ephemeral row removes those persistent ledgr surfaces while using
the same fold core. The durability and materialization surface is therefore
visible as a measured delta between the ledgr rows rather than hidden in one
number. In this current harness, the ephemeral row is not a fast path: it saves
ingestion time but spends more time in the memory output-handler fold and
event-stream result reconstruction.

## Divergence Attribution

Every DONE peer row writes a per-bar divergence file and a summary. Attribution
is derived from per-bar equity divergence and same-timestamp fill/transaction
comparison against `ledgr_ttr_canonical`.

| Peer | Total abs divergence | Diverging bars | First divergence | Indicator warmup | Fill timing | Calendar | Position size | Float rounding | Other |
| --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| ledgr_ttr_canonical_ephemeral | 0.000044 | 1232 | 2018-01-15T00:00:00Z | 0% | 0% | 0% | 0% | 100% | 0% |
| ledgr_builtin_sma | 0 | 0 | NA | 0% | 0% | 0% | 0% | 100% | 0% |
| quantstrat | 7,123,941.311 | 1250 | 2018-01-15T00:00:00Z | 0% | 98.526% | 0% | 1.474% | 0% | 0% |
| backtrader | 1,767,729.521 | 1250 | 2018-01-15T00:00:00Z | 0% | 0.173% | 0% | 99.827% | 0% | 0% |
| zipline-reloaded-full | 4,910,987.646 | 1000 | 2018-01-16T00:00:00Z | 0% | 25.760% | 0% | 74.240% | 0% | 0% |

## Historical Shape Context

The v0.1.8.7 closeout row was 500 x 1260 with continuous target semantics and
about 13k fills. This record is 500 x 1260 with crossover-event semantics and
about 68k ledgr fills. The three-phase table is therefore the useful artifact:
it shows ingestion, engine, and result materialization separately instead of
collapsing a high-turnover workload into one headline number.

## Attribution Discipline

When a parity check fails, the candidate explanations remain:

1. ledgr is wrong;
2. the peer is wrong;
3. the harness is wrong.

Residual divergences are attributed to one of:

- indicator initialization window;
- fill-timing edges;
- cost/margin defaults;
- position-sizing rounding;
- timestamp alignment;
- float-ordering rounding.

## Reorganization

The `dev/bench/` tree now separates current peer work, parallel-sweep
measurement, fold-loop diagnostics, references, shared utilities, and archived
v0.1.8.7-era harnesses. The zipline peer result now uses the full csvdir
bundle/`run_algorithm()` harness. The current report is the Markdown artifact
at:

```text
dev/bench/peer_benchmark/peer_benchmark.md
```
