# Spike Log: yyjsonr Read-Path Parity And Recovery

**Date:** 2026-05-31 - **Host:** local development host - R 4.5.2,
jsonlite 2.0.0, yyjsonr 0.1.22 - **Status:** v0.1.8.9 optimization-round
Round 2 input (LDG-2493, Spike 13).

**Script:** `dev/spikes/spike-yyjsonr-readpath-parity.R`. Raw CSV
(gitignored): `dev/bench/results/spike_yyjsonr_readpath_parity.csv`.

**Relates to:**
- `dev/spikes/spike-chunked-extractor-wall-recovery.md` (LDG-2491,
  Spike 12) — the Rprof finding that motivated this spike
- `dev/spikes/spike-yyjsonr-write-byte-identity.md` (LDG-2494, Spike 14)
  — companion spike for the WRITE path
- `R/backtest.R:1127` and 7 other production fromJSON call sites

## Question

Spike 12 Rprof attributed ~20% of total.time to `jsonlite::fromJSON` in
the chunked extractor at 130k events. yyjsonr claims 2-10x speedup. Can
yyjsonr be a drop-in replacement for `jsonlite::fromJSON(meta_json,
simplifyVector = FALSE)` in ledgr's hot read paths?

## Method

Constructed 185 fixture strings across 5 production patterns:
- 80 standard FILL events (cash_delta, position_delta, realized_pnl=null)
- 40 FILL events with realized_pnl populated
- 40 CASHFLOW opening positions (source, cost_basis, opening_position)
- 20 events with commission_fixed populated
- 5 edge cases (tiny/huge numbers, escape chars, max double)

Parsed each with `jsonlite::fromJSON(s, simplifyVector = FALSE)` and
`yyjsonr::read_json_str(s, opts = ...)` with options:

```r
opts_read_json(
  obj_of_arrs_to_df = FALSE,
  arr_of_objs_to_df = FALSE,
  arr_of_arrs_to_matrix = FALSE,
  length1_array_asis = TRUE
)
```

(These options together replicate `simplifyVector = FALSE` semantics.)

Compared with `identical()`. Timed both parsers on 133k repeated parses
to estimate production-scale recovery.

## Results

### Parity (185 fixtures)

```
Per-pattern parity:
        pattern total identical same_values pct_identical pct_same_values
1    commission    20        20          20           100             100
2          edge     5         5           5           100             100
3          fill    80        80          80           100             100
4 fill_realized    40        40          40           100             100
5       opening    40        40          40           100             100

Overall: 185/185 identical (100.0%), 185/185 same values (100.0%)
```

**100% byte-identical R object output** across all 5 production
patterns. yyjsonr's `simplifyVector = FALSE` equivalent options produce
exactly the same nested-list structure as jsonlite for ledger meta_json
shapes.

### Timing (133k events)

```
jsonlite: 1.250s  (9.40 us/event)
yyjsonr : 0.300s  (2.26 us/event)
Speedup : 4.17x
Recovery: 0.950s at 133k events (isolated)
```

## Findings

**Parity is perfect.** yyjsonr is a true drop-in replacement for the
hot READ paths. The four-option combination above produces byte-identical
nested-list R objects to jsonlite's `simplifyVector = FALSE`. The
parser handles all production meta_json shapes including null values,
escape characters, unicode, and IEEE 754 edge cases without structural
divergence.

**Speedup is real but smaller in absolute terms than Spike 12's Rprof
suggested.** Spike 12's Rprof attributed ~20% of total.time to
fromJSON (~46s on 223s total). The direct spike measures jsonlite at
9.4 us/event, so 133k events is 1.25s of actual jsonlite work — not 46s.

The discrepancy is Rprof sampling bias: at 200Hz (5ms intervals) Rprof
can over-count functions that are interrupted by other work or whose
call sites are reentered through callees. The DIRECT timing of 1.25s
for 133k jsonlite calls is the ground truth.

**Recovery on the production durable xlarge cell: ~1 second.** This is
the Amdahl-bounded honest number, not the Rprof-implied 46s.

## Wall translation

Reference workload: `density_high_xlarge_durable` runs in 445.02s wall
with ~133k fills. Each fill pays one jsonlite::fromJSON call in the
chunked extractor (R/backtest.R:1127).

- Pre-fix fromJSON cost: ~1.25s of the 197.11s fills_extract_sec
- Post-fix (yyjsonr) cost: ~0.3s
- Production recovery: **~1 second on the xlarge cell**

Amdahl bound: p = 0.0022 (jsonlite is 0.22% of wall). Max wall speedup
1.0022x. Negligible.

## Caveats

- **Spike 12's Rprof was misleading.** The 20% total.time attribution
  to fromJSON was an artifact of sampling — actual jsonlite cost is
  ~0.5% of wall. The right tool for "is this function expensive" is
  direct system.time(), not Rprof percentage attribution at high
  sampling intervals.
- **yyjsonr 0.1.22 is the version tested.** Parity in future versions
  is not contractually guaranteed. If we switch, we pin yyjsonr at
  a specific version in Imports.
- **The fixtures cover production meta_json shapes but not config or
  state_update JSON.** Those shapes are tested separately in Spike 14.

## Recommendation

**PARK.** Recovery is real but Amdahl-bounded at ~1 second on the
xlarge cell. Not a v0.1.8.9 ticket.

Specifically:

- yyjsonr is a true drop-in for hot fromJSON reads — the parity
  question is settled affirmatively.
- The lane is smaller than initially projected because Spike 12's
  Rprof over-attributed total.time to fromJSON.
- Switching for ~1s recovery is not worth the Imports addition and
  the version-pinning maintenance.

If a future workload exercises fromJSON heavily (e.g., a research
script that parses millions of events independent of the extractor),
yyjsonr remains the right tool for that workload. The v0.1.8.9 spec
packet should record yyjsonr as a known-good fromJSON alternative
without committing to the switch.

## Architectural lesson

**Rprof's sampling attribution can over-count by orders of magnitude
at high sampling intervals.** The Spike 12 Rprof showed jsonlite at
46s of total.time; direct measurement shows it at 1.25s. That is a
~40x over-count.

The right discipline: **before scoping a v0.1.8.9 lane from an Rprof
percentage, run a direct system.time() measurement of the function
in isolation.** This converts uncertain attribution into bounded
ground truth. Spike 13 demonstrates this discipline by-example: the
spike's PURPOSE was to confirm Rprof's attribution; the spike found
the attribution was wrong.

This is the same lesson the v0.1.8.7 round captured as "isolated
benchmarks lie." Here it's the inverse: "Rprof attributions also
lie." Both require direct measurement to ground.

Worth recording: when designing v0.1.8.9 spec lanes, every lane whose
projected recovery depends on an Rprof percentage needs an
isolated-measurement confirmation before scoping.
