# v0.1.8.7 Benchmark And Attribution Closeout

Date: 2026-05-30

Scope: LDG-2466 / Batch 8. This is a local development closeout, not a public
benchmark page. Numbers are machine-specific and use the current source tree on
the local i9-12900K Windows host after the power-profile change.

Machine-readable companion: `benchmark_attribution_table.csv`.

Raw local outputs:

- `dev/bench/results/ledgr_bench_record_20260529T221513Z_raw.csv`
- `dev/bench/results/ledgr_bench_record_20260529T221513Z_summary.csv`
- `dev/bench/results/ledgr_bench_record_20260529T221513Z_environment.json`
- `dev/bench/results/peer_three_way_results.csv`
- `dev/bench/results/peer_sweep_three_way_ledgr.csv`

The benchmark runner printed `benchmarking ledgr 0.1.8.6 from current source
guard`. That is the `DESCRIPTION` version label, not an installed-package
measurement: the runner used `pkgload::load_all(".")` from the source tree.

## Current-Source Record Subset

| Scenario | Shape | Wall | Pre | Loop | Residual | Bars/sec | Feature cells/sec | Events/fills |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| feature_read_score | 100 x 252 x 20 | 3.81s | 0.33s | 0.48s | 3.00s | 6,614 | 132,283 | 0 / 0 |
| feature_turnover | 100 x 252 x 20 | 3.22s | 0.18s | 0.27s | 2.77s | 7,826 | 156,522 | 47 / 47 |
| peer_sma_crossover | 500 x 1260 x 2 | 25.91s | 1.22s | 15.70s | 8.99s | 24,315 | 48,630 | 13,355 / 13,355 |
| peer_sma_crossover_sweep | 500 x 1260 x 2, N=1 | 30.75s | NA | NA | NA | 20,488 | 40,976 | NA / 6,585 |

`peer_sma_crossover` uses the quick TTR-backed SMA feature path and
`persist_features = FALSE`. It is still a durable ledgr run, so the wall time
includes durable ledger/equity materialization to DuckDB. The one-candidate
sweep row is an ephemeral sweep path and does not expose run phase timings.

## Same-Host Peer Rows

The peer driver is canonicalized to use the quick ledgr path: TTR-backed SMA
features plus the feature-wide strategy surface. Quantstrat also uses TTR SMA;
Backtrader uses its native SMA implementation.
The ledgr peer row also exercises the cross-sectional vectorized strategy
surface via `features_wide`, while the Backtrader and quantstrat rows iterate
per-feed/per-symbol in their idiomatic APIs. Some of the wall gap therefore
reflects the strategy surface and indicator precompute model, not only raw fold
loop speed.

| Engine | Wall | Bars/sec | Fills | Timing boundary |
| --- | ---: | ---: | ---: | --- |
| ledgr | 31.21s | 20,186 | 13,355 | `ledgr_run()`, durable ledger/equity to DuckDB |
| Backtrader | 64.40s | 9,782 | NA | `cerebro.run(runonce=True, preload=True)`, in memory |
| quantstrat | 114.59s | 5,498 | 12,787 | `applyStrategy()` + account/portfolio updates, in memory |

Interpretation: on this one same-host SMA workload, ledgr's quick TTR-backed
path is faster than the local Backtrader and quantstrat rows. This is not a
general peer-superiority claim: it is one workload, one host, one data shape, and
different timing boundaries. Release notes may say the local matched benchmark
now has a fast ledgr row; they should not market a public benchmark ranking.

Published LEAN and Ziplime rows remain orientation-only. They are not locally
matched rows and must not be folded into the same-host ratios.

## Sweep Amortization

`peer_sweep_three_way.R` currently measures ledgr only. It does not include
same-host Backtrader or quantstrat optimization/sweep rows, so no sweep
crossover claim is supported.

| Workload | Candidates | Wall | Per candidate | Fitted one-time intercept | Fitted per-candidate slope | Amortization note |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| SMA, 2 features | 50 | 70.35s | 1.407s | 0.69s | 1.392s | about 1.5x vs naive repeated single-candidate equivalent |
| Heavy, 40 features | 50 | 257.81s | 5.156s | 1.58s | 5.135s | about 1.3x vs naive repeated single-candidate equivalent |

The result stays consistent with the RFC: sweep amortizes feature setup, but the
per-candidate fold remains the dominant slope for these shapes. Keep sweep
crossover as an open benchmark track.

## Lane Attribution

| Lane | Evidence | Closeout |
| --- | --- | --- |
| B0 event buffer | Batch 3 profile share dropped from 72.43% to 3.49% of sampled R time; current peer run is now in the 25-31s class instead of the pre-B0 300s-class historical number. | Expected high-turnover range was met by mechanism/profile evidence. Do not cite old-power wall ratios as direct speedup. |
| R/A representation and setup | Batch 5 same-power comparison: post-B0 32.91s to post-Batch-5 31.25s on peer shape; pre phase 1.50s to 1.11s. | Landed at the low end of the expected 1.05x-1.15x turnover band. Larger R wins remain expected for low-turnover/wide formatting-heavy shapes. |
| C reconstruction/read-back | Synthetic read-back materialization improved 8.27s to 4.92s for 13,355 fill events. | Report only as materialization/read-back improvement, not as primary run-wall speed. |
| Artifact policy | Batch 7 probe: sweep left heavy table counts at zero; promotion wrote `runs=1`, `ledger_events=1`, `equity_curve=6`, `features=6`, `run_telemetry=1`. | Fast/slow artifact boundary is proven; not a peer-speed claim. |

## Remaining Buckets

| Bucket | Current evidence | Owner |
| --- | --- | --- |
| Turnover fold loop | `peer_sma_crossover` loop is 15.70s of 25.91s wall with 13,355 events. | Accepted pure-R fold cost for this cycle; future compiled core is the decisive lever. |
| Durable materialization / residual | `peer_sma_crossover` residual is 8.99s. This includes durable run finalization, DB writes/read-back, and wrapper overhead that peers do not all share. | Accepted timing-boundary cost; artifact policy keeps sweep/evaluation paths explicit. |
| Feature setup | `peer_sma_crossover` pre phase is 1.22s after the cache-key/setup cleanup. | Accepted; no release-blocking setup gap remains. |
| Sweep crossover | ledgr-only amortization exists but is modest on the measured shapes; no peer sweep rows were run. | Open benchmark track; no v0.1.8.7 claim. |
| Built-in pure-R SMA indicator path | Not the canonical peer row. TTR-backed indicators are the benchmark path. | Future UX/performance decision if default built-in indicators should delegate to faster backends. |

## Release-Language Guidance

Safe:

- "The local v0.1.8.7 benchmark suite records a same-host TTR-backed SMA row at
  31.21s for 500 x 1260 bars."
- "Sweep remains a fast/evaluation path; promotion explicitly materializes
  durable artifacts."
- "LEAN and Ziplime references are orientation-only unless locally matched."

Avoid:

- "ledgr is faster than Backtrader" without the one-workload/same-host/timing
  boundary caveat.
- "sweeps beat peer optimizers" because same-host peer sweep rows were not run.
- Any speedup ratio that divides across the old and new power profiles.
