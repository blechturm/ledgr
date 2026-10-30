# WS4a typed-carrier probe findings

**Original verdict unchanged: INCONCLUSIVE, 42.23 us/fill.** GREEN requires
<=40 us/fill and exact identity; RED is >80 or a required semantic change.
Codex, 2026-10-30; archive `145cc93b`,
R 4.6.1. Nonbinding probe.

Complete facts enable availability with identical economics/equity. Its execution
stamps precede dense's bar stamps by 6.5 hours. Base/fork timestamps stay exact.

Five alternating fresh-process own-floor/wide pairs per cell; 500 x 1260 bars,
SMA 5/10, 67,725 fills, zero costs, USD 10M, vector strategy state. Marginals
are medians of paired differences. Dense baseline: 148.54 us/fill.

| Availability arm | Sweep us/fill | Lot s | Allocated GB | Durable run/floor s |
| --- | ---: | ---: | ---: | ---: |
| Base R | 226.50 | 2.78 | 7.33 | 25.12 / 8.16 |
| Original native + copying | **42.23** | 0.15 | 10.99 | 12.60 / 8.86 |
| Added R + copying | **69.25** | 2.31 | 12.31 | 14.27 / 8.59 |
| Added native + indexed | **26.73** | 0.08 | 6.14 | 12.16 / 8.60 |
| Added combined R + indexed | **56.70** | **1.99** | **7.46** | **14.37 / 8.68** |

Only native + indexed is GREEN among added arms; both R arms are inconclusive.
Combined is measured directly. R arms load no probe C++, using the per-fill
canonical oracle and R affordability; this is not an optimized-R limit. Indexed
publication writes fixed columns into the existing typed buffer/capacity policy.

Instrumented component seconds, separate from paired clocks:

| Component | Base | Original | R | Native indexed | Combined |
| --- | ---: | ---: | ---: | ---: | ---: |
| Plan | 7.87 | 0.50 | 0.51 | 0.47 | 0.43 |
| Payload/meta, sweep | 2.35 | 0.14 | 0.17 | 0.11 | 0.15 |
| Event batch, excluding payload | 3.14 | 1.69 | 1.65 | 0.23 | 0.42 |
| Payload/JSON, quiet durable | 5.04 | 1.78 | 1.80 | 1.88 | 1.83 |

Sweeps defer JSON encoding; base payload also includes validation/IDs. Durable
clocks are qualified replacements; earlier overlapped attempts remain excluded.
Durable marginals are reported separately, without applying the sweep verdict.
Partial warm call clocks: constructor and snapshot ingest/seal excluded;
internal preparation and retained sweep outputs included.

Allocations are Rprofmem explicit-size cumulative bytes, excluding unpriced pages
and native malloc/RSS; page counts and bytes/pulse/fill are in CSVs. Indexing
removes copying in `ledgr_fill_row_buffer_add_many()`. Combined allocation remains
slightly above baseline. The original pulse floor includes context 0.68 s,
validation 0.42 s, remaining decide 1.14 s, commit 2.86 s / 1,260 pulses.

All arms preserve exact ledger/JSON, equity, strategy state and final lots/cash/
positions/P&L across the same nine cases, including five availability A0 workloads.
Only generated memory-equity `sweep_id` is excluded. Reorder/dropped-fee guts fail;
strict floating-point and protected-path checks pass. Host monitor: 97 qualified,
5 excluded attempts (`additional_host.csv`). Fixtures/oracles and product paths stay unchanged. RFC inputs are these bounded costs/parities, not a native-default
decision. See `RUN.md`; reviewer Max Thomasberger, review pending.
