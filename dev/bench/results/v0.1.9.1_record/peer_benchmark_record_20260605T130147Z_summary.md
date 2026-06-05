# Peer Benchmark Summary

- Created: `2026-06-05T13:01:47Z`
- Release: `v0.1.9.1`
- Input hash: `0b183457b3fe720d63b02a90fe552e1202fdb31b4e967a75e91304f9d3e416fc`
- Shared bars: `dev/bench/results/v0.1.9.1_record/peer_benchmark_shared_bars_record.csv`
- Parity history: `dev/bench/results/v0.1.9.1_record/parity_history/v0.1.9.1_record.json`

This is an internal same-host parity and performance benchmark under declared boundaries.

## Engine Status

| Engine | Status | Wall s | Reason |
| --- | --- | ---: | --- |
| `ledgr_ttr_canonical` | `DONE` | 116.8500 | NA |
| `ledgr_ttr_canonical_ephemeral` | `DONE` | 107.3800 | NA |
| `ledgr_ttr_canonical_ephemeral_with_costs` | `DONE` | 106.9800 | NA |
| `ledgr_ttr_canonical_ephemeral_legacy_costs` | `DONE` | 106.3700 | NA |

## Parity

| Peer | Status | Equity cor | Max div pct | Return cor | Attribution |
| --- | --- | ---: | ---: | ---: | --- |
| `ledgr_ttr_canonical_ephemeral` | `DONE` | 1.000000 | 0.000000 | 1.000000 | passes Tier 1 tolerance |
| `ledgr_ttr_canonical_ephemeral_with_costs` | `DONE` | 0.999736 | 0.009952 | 0.999972 | passes Tier 1 tolerance |
| `ledgr_ttr_canonical_ephemeral_legacy_costs` | `DONE` | 0.999536 | 0.013550 | 0.999932 | indicator initialization, fill timing, cost/margin defaults, position-sizing rounding, timestamp alignment, or float ordering |

## Performance

| Engine | Full row s | Ingestion s | Engine s | Results s | Total s | Core bars/sec | Boundary |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `ledgr_ttr_canonical` | 116.8700 | 20.4700 | 86.6900 | 9.6900 | 116.8500 | 5391.5 | durable ledgr: ingestion=bars CSV read plus DuckDB snapshot plus experiment construction; engine=ledgr_run; results=ledgr_results equity/fills plus canonical materialization |
| `ledgr_ttr_canonical_ephemeral` | 107.4000 | 16.2500 | 81.1300 | 10.0000 | 107.3800 | 5867.0 | ephemeral ledgr: ingestion=bars CSV read plus in-memory bars/features/projection; engine=ledgr_execute_fold with memory output handler; results=event-stream equity/fills reconstruction plus canonical materialization |
| `ledgr_ttr_canonical_ephemeral_with_costs` | 106.9800 | 11.3200 | 86.3900 | 9.2700 | 106.9800 | 5889.0 | ephemeral ledgr with realistic public cost chain: same bars/projection/strategy surface as canonical ephemeral; engine uses ledgr_cost_chain(spread_bps=5, fixed_fee=1) |
| `ledgr_ttr_canonical_ephemeral_legacy_costs` | 106.3700 | 9.9800 | 87.3900 | 9.0000 | 106.3700 | 5922.7 | ephemeral ledgr with legacy internal fill-model resolver: same bars/projection/strategy surface as canonical ephemeral; engine uses spread_bps=5 and commission_fixed=1 baseline resolver |

## Surface Availability

| Engine | Equity | Fills | Trades |
| --- | --- | --- | --- |
| `ledgr_ttr_canonical` | `available` | `available` | `available_realized_pnl` |
| `ledgr_ttr_canonical_ephemeral` | `available` | `available` | `available_realized_pnl` |
| `ledgr_ttr_canonical_ephemeral_with_costs` | `available` | `available` | `available_realized_pnl` |
| `ledgr_ttr_canonical_ephemeral_legacy_costs` | `available` | `available` | `available_realized_pnl` |
