# LDG-2476 Follow-Up Three-Phase Decomposition Results

Created: 2026-05-31

Record prefix:

```text
dev/bench/results/peer_benchmark_record_20260531T114451Z
```

Shape:

```text
500 instruments x 1260 daily bars = 630,000 bars
SMA crossover fast=5 slow=10
seed=42
```

## Phase Table

| Engine | Status | Ingestion s | Engine s | Results s | Total s | Bars/sec | us/bar |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| ledgr_ttr_canonical | DONE | 20.710 | 138.370 | 83.000 | 242.080 | 2,602 | 384.3 |
| ledgr_ttr_canonical_ephemeral | DONE | 10.970 | 154.750 | 123.900 | 289.620 | 2,175 | 459.7 |
| ledgr_builtin_sma | DONE | 19.690 | 151.970 | 80.560 | 252.220 | 2,498 | 400.3 |
| quantstrat | DONE | 12.440 | 490.750 | 1.360 | 504.550 | 1,249 | 800.9 |
| backtrader | DONE | 0.655 | 79.704 | 0.153 | 80.512 | 7,825 | 127.8 |
| zipline-reloaded-full | DONE | 14.149 | 279.278 | 0.451 | 293.879 | 2,144 | 466.5 |
| LEAN | UNAVAILABLE | NA | NA | NA | NA | NA | NA |

LEAN unavailable reason:

```text
old Lean CLI root folder; local lean init organization setup is required
```

## Parity Table

| Peer | Status | Equity corr | Max div | Return corr | Trade count diff | Attribution |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| ledgr_ttr_canonical_ephemeral | DONE | 1.000000 | 0.000000000001857% | 1.000000 | 0 | passes Tier 1 tolerance |
| ledgr_builtin_sma | DONE | 1.000000 | 0% | 1.000000 | 0 | passes Tier 1 tolerance |
| quantstrat | DONE | 0.999820 | 0.236447% | 0.984103 | 33621 | passes Tier 1 tolerance |
| backtrader | DONE | 0.999997 | 0.076047% | 0.996982 | -332 | passes Tier 1 tolerance |
| zipline-reloaded-full | DONE | 0.999708 | 0.307153% | 0.185355 | -625 | passes Tier 1 tolerance |
| LEAN | UNAVAILABLE | NA | NA | NA | NA | unavailable peer surface |

## Divergence Summary

| Peer | Total abs divergence | Diverging bars | First divergence | Fill timing | Position size | Float rounding |
| --- | ---: | ---: | --- | ---: | ---: | ---: |
| ledgr_ttr_canonical_ephemeral | 0.000044 | 1232 | 2018-01-15T00:00:00Z | 0.000% | 0.000% | 100.000% |
| ledgr_builtin_sma | 0.000000 | 0 | NA | 0.000% | 0.000% | 100.000% |
| quantstrat | 7,123,941.311 | 1250 | 2018-01-15T00:00:00Z | 98.526% | 1.474% | 0.000% |
| backtrader | 1,767,729.521 | 1250 | 2018-01-15T00:00:00Z | 0.173% | 99.827% | 0.000% |
| zipline-reloaded-full | 4,910,987.646 | 1000 | 2018-01-16T00:00:00Z | 25.760% | 74.240% | 0.000% |

## Read

The three-phase split shows that ledgr durable cost is not only the fold loop:
at this shape, durable canonical spends 20.710s in ingestion, 138.370s in
engine execution, and 83.000s in results reconstruction/materialization.

The ephemeral ledgr row removes DuckDB snapshot/event-log persistence but is not
faster in this current harness. It spends less time in ingestion than durable
ledgr, but more in engine and results. That points to the in-memory output
handler and memory event reconstruction as their own optimization surfaces; the
ephemeral row is a measurement tool, not currently a fast path.

Backtrader remains much faster on the engine phase for this high-turnover
crossover shape. Quantstrat remains slower mostly in engine time. Zipline's
bundle ingest is now visible separately from `run_algorithm()`.

The ledgr durable versus ephemeral parity gate passed before the peer rows were
accepted. Fills match exactly after stripping result-only attributes. Equity
matches within 1e-8; the residual 0.000044 total absolute divergence is
sub-1e-8-per-bar accumulation-method noise from Kahan compensated summation in
durable lot accounting versus naive `cumsum()` in in-memory reconstruction.
Spike 10 later rejected DuckDB double round-trip drift as the source.
