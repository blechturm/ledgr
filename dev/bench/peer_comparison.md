# Three-Way Peer Comparison: ledgr vs quantstrat vs backtrader

**Status:** Same-host orientation benchmark; v0.1.8.7 optimization-round input.
Not a v0.1.8.6 deliverable and not event/accounting parity. Run while the
v0.1.8.6 release gate was in progress; deliberately kept out of the release
packet.

**Historical note:** this document records the pre-Lane-B peer-comparison input.
The current v0.1.8.7 closeout is
`inst/design/ledgr_v0_1_8_7_spec_packet/benchmark_attribution_closeout.md`.
The current `peer_three_way.R` harness canonicalizes the ledgr peer row to the
quick TTR-backed indicator path.

**Date:** 2026-05-29 · **Host:** Intel Core i9-12900K, Windows 11 ·
**R** 4.5.2 (ledgr 0.1.8.5 source) · **Python** 3.13.2, backtrader 1.9.78.123,
pandas 3.0.3, numpy 2.4.6.

## Method

One seeded `ledgr_sim_bars()` set per width, written to a shared CSV so all
three engines see identical data. Matched SMA(20/50) crossover: long 1 unit
while fast > slow, flat otherwise.

- ledgr runs its built-in `ledgr_demo_sma_crossover_strategy()` (threshold = 0).
- quantstrat runs `SMA`/`sigCrossover`/`ruleSignal` matched to it.
- backtrader runs `bt.ind.CrossOver` of two `SMA`s.

Timing boundary is execution only (data generation + engine/instrument setup
excluded): ledgr `ledgr_run()`; quantstrat `applyStrategy()` +
`updatePortf/updateAcct/updateEndEq`; backtrader `cerebro.run(runonce=True,
preload=True)` (the LDG-2457 boundary). Headline unit:
`security_bars_sec = n_inst * n_pulses / wall`.

Harness: `dev/bench/peer_three_way.R` then `dev/bench/peer_three_way_backtrader.py`.

## Results (bars/sec; wall in parentheses)

| Width (×1260) | ledgr | quantstrat | backtrader |
| --- | --- | --- | --- |
| 10 | 1,453 (8.67s) | 3,119 (4.04s) | 4,914 (2.56s) |
| 50 | 2,248 (28.03s) | 3,133 (20.11s) | 4,915 (12.82s) |
| 100 | 2,162 (58.28s) | 3,148 (40.02s) | 4,893 (25.75s) |
| 250 | 1,904 (165.42s) | 3,116 (101.10s) | 4,843 (65.04s) |

Fill counts (ledgr / quantstrat) confirm a fair strategy match at every width:
277/267, 1384/1338, 2746/2650, 6784/6534.

## Findings

- **quantstrat is NOT ≈ backtrader.** backtrader is consistently ~1.56× faster
  than quantstrat at every width. Both are **width-invariant** (backtrader
  ~4,900 b/s, quantstrat ~3,120 b/s, flat — at their asymptote even at width 10).
- **ledgr is slowest at every width** (pre-optimization). Best showing is width
  50: 1.39× behind quantstrat, 2.19× behind backtrader.
- **ledgr is the only engine whose rate is not flat:** it rises 10→50
  (1,453 → 2,248, fixed cost amortizing) then *degrades* 50→250
  (2,248 → 1,904). The degradation tracks the fill count (1,384 → 6,784) — i.e.
  the per-event emission/buffer cost (~72% of loop in the LDG-2456/2457 profile;
  see `inst/design/audits/fold_path_hotpath_audit.md`). The curve independently
  confirms that diagnosis and pinpoints where Lane B should flatten ledgr's rate.

## Caveats / scope

- Single-run only. The regime ledgr is architecturally built for — **parameter
  sweeps** (amortized precompute vs the peers' full per-run setup) — is **not**
  measured here. That comparison (ledgr_sweep vs quantstrat `apply.paramset` vs
  backtrader optstrategy) is the open follow-up.
- All numbers are **pre-Lane-B** (the event-emission/buffer rewrite is the
  v0.1.8.7 optimization round; ADR 0004, `ledgr_roadmap.md` v0.1.8.7).
- ledgr persists a durable, replayable `ledger_events` + `equity_curve` to
  DuckDB; quantstrat and backtrader keep results in memory. Part of ledgr's gap
  is durable audit work the peers do not do.
- Same-host orientation; not event/accounting parity. SMA conventions differ
  slightly across engines (hence close-not-identical fill counts).
