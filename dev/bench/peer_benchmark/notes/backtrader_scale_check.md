# Backtrader Scale Check

Created: 2026-05-31  
Scope: LDG-2476 follow-up scale check for the 500 x 1260 peer workload

This is an internal same-host benchmark note, not a public speed ranking.

## Record

Record prefix:

```text
dev/bench/results/peer_benchmark_record_20260531T053230Z
```

Run shape and controls:

- Instruments: 500
- Daily bars: 1260
- Total bars: 630,000
- Strategy: SMA(5/10) crossover-event semantics
- Synthetic input seed: 42
- Threading environment set before run: `OMP_NUM_THREADS=1`, `OPENBLAS_NUM_THREADS=1`, `MKL_NUM_THREADS=1`, `NUMEXPR_NUM_THREADS=1`

The Python engine gates were run before the timed record:

- Backtrader: `bt.Cerebro` callable, version-only gate passed
- zipline-reloaded-full: `zipline.run_algorithm` callable, version-only gate passed
- LEAN: CLI subprocess reachable, version-only gate passed

## Results

`Reported core` is the declared boundary for DONE rows: raw bars CSV path in,
engine ingestion/feed construction, engine run, canonical equity output, fills
output, and trades output. `Full row` includes wrapper/process overhead around
that core. LEAN is unavailable because `lean backtest` rejects the temporary
project root as an old Lean CLI root and requires local `lean init`
organization setup.

| Engine | Status | Full row s | Reported core s | Core bars/sec | Core us/bar | Parity status |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| ledgr_ttr_canonical | DONE | 240.680 | 240.640 | 2,618.0 | 382.0 | reference |
| ledgr_builtin_sma | DONE | 250.740 | 250.720 | 2,512.8 | 398.0 | pass |
| quantstrat | DONE | 508.070 | 507.500 | 1,241.4 | 805.6 | pass |
| backtrader | DONE | 87.030 | 80.302 | 7,845.4 | 127.5 | pass |
| zipline-reloaded-full | DONE | 315.870 | 298.398 | 2,111.3 | 473.6 | pass |
| LEAN | UNAVAILABLE | 10.070 | NA | NA | NA | unavailable |

## Scale Comparison

The fixed-cost decomposition hypothesis was that ledgr carried roughly 6s of
per-run overhead that dominated the 100 x 252 shape but amortized at 500 x
1260. This run does not support that hypothesis under the current
apples-to-apples crossover harness. At 100 x 252, the v0.1.8.8 record showed
ledgr_ttr_canonical at 7.380s and Backtrader at 2.805s, or about 293 us/bar
vs 111 us/bar. At 500 x 1260, this record shows ledgr_ttr_canonical at
240.640s and Backtrader at 80.302s, or about 382 us/bar vs 127 us/bar.
Backtrader remains about 3.0x faster on the larger current-harness workload.
That differs sharply from the v0.1.8.7 closeout row at the same 500 x 1260
shape, which reported ledgr at 25.910s and Backtrader at 64.400s, or about
41 us/bar vs 102 us/bar. The actionable result is therefore not a simple
fixed-cost amortization story; the current crossover parity harness exposes a
large ledgr per-bar cost relative to both the v0.1.8.7 historical row and the
current Backtrader row.

## Divergence Summary

The per-bar divergence diagnostics were written for every DONE non-reference
peer. Attribution percentages sum to 100% for each row.

| Peer | Total abs divergence | Diverging bars | First divergence | Fill timing | Position size | Float rounding |
| --- | ---: | ---: | --- | ---: | ---: | ---: |
| ledgr_builtin_sma | 0.000 | 0 | NA | 0.00% | 0.00% | 100.00% |
| quantstrat | 7,123,941.311 | 1250 | 2018-01-15T00:00:00Z | 98.53% | 1.47% | 0.00% |
| backtrader | 1,767,729.521 | 1250 | 2018-01-15T00:00:00Z | 0.17% | 99.83% | 0.00% |
| zipline-reloaded-full | 4,910,987.646 | 1000 | 2018-01-16T00:00:00Z | 25.76% | 74.24% | 0.00% |

