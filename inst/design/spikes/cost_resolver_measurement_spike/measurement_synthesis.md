# Cost Resolver Measurement Spike

**Status:** Completed for LDG-2575.
**Date:** 2026-06-05.
**Verdict:** `ship-with-known-overhead`.
**Record bundle:** `dev/bench/results/v0.1.9.1_record/`.

This spike measures the per-fill cost-resolver overhead introduced by the
v0.1.9.1 Batch 2 cost-API migration. The question is narrow: does the public
cost resolver add enough engine-phase wall time on the peer-shaped workload to
require NEWS disclosure or reopen one of the parked post-LDG-2522 optimization
slices?

It does not reopen the parked optimization slices. The single record run shows
a 5.26s engine-phase difference
between the zero-cost row and the realistic public-chain row. That absolute
delta is large enough that it should not be waved away. A focused resolver-only
loop over the same 68,201 fill count, however, puts the public-chain resolver
delta at 0.26s total, or about 3.8 microseconds per fill. The 5.26s record-row
delta is therefore best treated as a noisy single-run engine-row observation,
not as measured resolver overhead.

The public chain is also slightly faster than the retained legacy internal
resolver proxy in the record run. The release should ship with the overhead
acknowledged in NEWS, but no horizon status update is required.

## Method

Command:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/bench/peer_benchmark/peer_benchmark.R --preset record --engine-set ledgr-cost --release v0.1.9.1 --n-inst 500 --n-days 1260 --out-dir dev/bench/results/v0.1.9.1_record
```

Fixture:

- 500 instruments.
- 1260 daily bars per instrument.
- Seed `20260530`.
- TTR-backed SMA crossover with `fast = 5`, `slow = 10`.
- Shared bars CSV:
  `dev/bench/results/v0.1.9.1_record/peer_benchmark_shared_bars_record.csv`.
- Compact performance table:
  `dev/bench/results/v0.1.9.1_record/peer_benchmark_record_20260605T130147Z_performance.csv`.
- Status table:
  `dev/bench/results/v0.1.9.1_record/peer_benchmark_record_20260605T130147Z_status.csv`.
- Focused resolver-only loop: five repeats over 68,201 proposals and fill
  contexts constructed from the record bundle's zero-cost fill table.

The harness uses `--engine-set ledgr-cost` so the record bundle measures only
the ledgr rows needed for this spike. This avoids rerunning quantstrat,
Backtrader, Zipline, and LEAN; those peer rows are not part of the
cost-resolver question and already have the v0.1.8.10/v0.1.8.11 peer record
baseline in `dev/bench/peer_benchmark/peer_benchmark.md`.

The legacy `fill_model` public path cannot be rerun on the v0.1.9.1 branch
because Batch 2 deliberately rejects it. The legacy baseline row therefore uses
the retained internal legacy resolver
`ledgr:::ledgr_cost_spread_commission_internal(spread_bps = 5, commission_fixed = 1)`.
That is the equivalent resolver shape for measuring overhead, not a reopened
public API path.

## Measurements

| Measurement | Row | Ingestion s | Engine s | Results s | Total s |
| --- | --- | ---: | ---: | ---: | ---: |
| 1. `cost_zero` floor | `ledgr_ttr_canonical_ephemeral` | 16.25 | 81.13 | 10.00 | 107.38 |
| 2. Realistic public chain | `ledgr_ttr_canonical_ephemeral_with_costs` | 11.32 | 86.39 | 9.27 | 106.98 |
| 3. Legacy resolver proxy | `ledgr_ttr_canonical_ephemeral_legacy_costs` | 9.98 | 87.39 | 9.00 | 106.37 |

Durable zero-cost context row:

| Row | Ingestion s | Engine s | Results s | Total s |
| --- | ---: | ---: | ---: | ---: |
| `ledgr_ttr_canonical` | 20.47 | 86.69 | 9.69 | 116.85 |

## Delta

Engine-phase comparison is the decision metric because ingestion and result
materialization are independent of the resolver. The single record-row engine
delta is:

| Comparison | Engine delta s | Engine delta pct |
| --- | ---: | ---: |
| Realistic public chain vs `cost_zero` | 5.26 | 6.5% |
| Legacy resolver proxy vs `cost_zero` | 6.26 | 7.7% |
| Realistic public chain vs legacy resolver proxy | -1.00 | -1.1% |

This is the number that prompted the follow-up check. It is not small in
absolute terms, but the record run is one timing per row. The focused
resolver-only loop gives the more direct attribution:

| Resolver | Median s for 68,201 fills | Microseconds per fill |
| --- | ---: | ---: |
| `ledgr_cost_zero()` | 0.54 | 7.9 |
| Public realistic chain | 0.80 | 11.7 |
| Legacy resolver proxy | 0.55 | 8.1 |

Resolver-only public-chain delta versus `ledgr_cost_zero()` is 0.26s total,
or about 3.8 microseconds per fill. Against the 81.13s zero-cost engine phase,
that direct resolver delta is about 0.3% of engine wall. The realistic public
chain therefore does not exceed the LDG-2575 decomposition trigger, and the
5.26s row delta should not be reported as resolver overhead.

## Verdict

`ship-with-known-overhead`.

No material resolver overhead was measured for the Batch 2 public cost resolver
on the peer-shaped workload. The v0.1.9.1 release should still acknowledge the
single-run 5.26s / 6.5% engine-phase observation in NEWS because it is
user-facing wall time when moving from `ledgr_cost_zero()` to a realistic
public cost chain at the xlarge peer fixture.

NEWS language should be precise: this is not a measured regression versus the
legacy resolver proxy, and the focused loop does not support blaming resolver
dispatch itself for the full 5.26s row delta. The direct resolver-only delta was
0.26s total over 68,201 fills. The 2026-06-05 post-LDG-2522 horizon entry does
not need a status update.

## Follow-Up

- Keep the `ledgr_ttr_canonical_ephemeral_with_costs` row available for the
  v0.1.9.1 release bundle.
- LDG-2570 NEWS should name the observed 5.26s / 6.5% xlarge engine-row delta
  with the attribution caveat above.
- Do not reopen the parked post-LDG-2522 optimization options from this spike.
- Do not add a cost-resolver dispatch optimization horizon entry from this
  spike alone; the focused resolver-only loop does not support that attribution.
- The retained legacy internal resolver is still test/benchmark scaffolding.
  Its broader cleanup remains the Batch 3 or follow-on hygiene item identified
  by the Batch 2 code review.
