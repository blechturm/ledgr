# Spike Log: Persistent Durable Handler pending_cols Buffer

**Date:** 2026-05-31 - **Host:** local development host - R 4.5.2,
collapse 2.x - **Status:** v0.1.8.9 optimization-round Round 2 input
(LDG-2490, Spike 11). Closes Codex peer-review Finding 1.

**Script:** `dev/spikes/spike-persistent-handler-buffer.R`. Raw CSV
(gitignored): `dev/bench/results/spike_persistent_handler_buffer.csv`.

**Relates to:**
- `dev/bench/notes/single_core_optimization_inventory.md` (B1 lane,
  now reclassified per Codex Finding 1)
- `dev/spikes/spike-memory-output-handler-growth.{R,md}` (LDG-2485,
  Spike 6 — methodological template for this spike)
- `dev/spikes/spike-batch-fill-writes.{R,md}` (LDG-2483, Spike 4 — this
  spike supersedes for the default durable path)
- `R/backtest-runner.R:288-437` (the persistent output handler)

## Question

Codex peer review Finding 1 showed that Spike 4 (LDG-2483, per-row DBI
INSERT) is not faithful to the default durable production path. Default
durable runs use audit_log mode through
`ledgr_persistent_output_handler` which buffers events into a
`state$pending_cols` list of typed vectors at
`R/backtest-runner.R:425-435` and flushes via `DBI::dbAppendTable`. The
per-row column-buffer writes look IDENTICAL to the memory output
handler pattern that Spike 6 (LDG-2485) confirmed as O(N^2). Does the
persistent handler exhibit the same O(N^2) growth, and does
`collapse::setv` recover the same magnitude as Spike 6?

## Method

Faithful replica of the persistent handler from
`R/backtest-runner.R:288-437`. 11 columns matching the production
schema. Uses the production `ledgr_event_buffer_next_capacity`
grow-by-doubling logic from `R/fold-event-buffer.R`. Fixed payload is
reused so the spike times the BUFFER WRITE only — not payload
construction or write_res unpacking.

Two variants:

- `handler_baser`: replica of the current handler (base-R `[[<-` column
  writes, identical to `R/backtest-runner.R:425-435`).
- `handler_setv`: same column writes via
  `collapse::setv(col, i, v, vind1=TRUE)`.

Per-event cost measured at intervals of 5,000 from 5k to 130k events,
matching xlarge fill count (~133k).

Column-value parity verified: 100 events written through both variants
with varied payload; all 11 columns byte-identical between variants.

## Results

### handler_baser (current persistent handler replica)

```
accumulated  | interval_s us_per_event
5000         |    0.4200s        84.00
10000        |    1.0300s       206.00
15000        |    1.3100s       262.00
20000        |    2.0300s       406.00
25000        |    2.3400s       468.00
30000        |    2.3300s       466.00
35000        |    3.5200s       704.00
40000        |    4.6800s       936.00
45000        |    4.6700s       934.00
50000        |    4.6800s       936.00
55000        |    4.7500s       950.00
60000        |    4.6800s       936.00
65000        |    4.7200s       944.00
70000        |    9.3200s      1864.00
75000        |    9.9700s      1994.00
80000        |    9.9100s      1982.00
85000        |    9.8400s      1968.00
...
130000       |    9.8600s      1972.00
```

Step-wise growth pattern matching capacity-doubling boundaries
(8192, 16384, 32768, 65536, 131072). Per-event cost ~doubles at each
capacity step.

### handler_setv (collapse::setv writes)

```
accumulated  | interval_s us_per_event
5000         |    0.0700s        14.00
10000        |    0.0800s        16.00
15000        |    0.0600s        12.00
...
130000       |    0.0700s        14.00
```

**Cost is essentially FLAT at ~14 us/event across all scales. No
growth signature at all.**

### Summary

- handler_baser: 84 -> 1972 us/event = **23.48x growth** from 5k to 130k.
- handler_setv: 14 -> 14 us/event = **1.00x growth** (no growth).
- **At 130k events, setv is 140.86x faster** (14 vs 1972 us/event).
- **Cumulative recovery on 130k events: 167.30s** (169.08s baser -
  1.78s setv).

## Findings

**O(N^2) mechanism confirmed for the persistent durable handler.** Same
step-wise capacity-doubling pattern as Spike 6's memory output handler.
The persistent durable path that production uses for the LDG-2479 grid
xlarge cell carries the same O(N^2) buffer-write cost.

**setv is essentially flat — no growth signature at all.** This is
better than Spike 6's measured 11.5x growth on the setv variant. The
difference: Spike 6's memory handler has a `meta` LIST column whose
writes (`state$event_cols$meta[i] <- list(meta)`) cannot be replaced
with `setv` because setv operates on atomic vectors, not lists. That
list-column write is the residual O(N^2) source Spike 6 measured.
Spike 11's persistent handler does NOT have a list column — all 11
columns are atomic (character, POSIXct, numeric, integer) — so every
write can use setv and the per-event cost is truly bounded.

**140x setv speedup is much larger than Spike 6's 6.45x.** Two
contributing factors:

1. 11 columns vs 14 columns (~1.3x of the difference).
2. The list-column escape hatch in Spike 6's setv variant (the rest of
   the difference, ~17x).

This is an important architectural observation: **`collapse::setv` is
only as fast as its slowest writable column.** If a buffer mixes atomic
and list columns, setv on the atomic columns delivers partial wins
bounded by the list-column copy cost. The persistent handler's
all-atomic design is incidentally optimal for the setv fix.

**Spike 4 (LDG-2483) is REPLACED, not supplemented, for the default
durable path.** Spike 4 measured per-row DBI INSERT at 60s for 68k
fills (878 us/row). That measurement is correct for the live-mode
production path (`use_transaction = TRUE` at
`R/backtest-runner.R:457-468`), but live mode is not the default and
the LDG-2479 grid xlarge cell does not exercise it. The default
buffered path goes through the `pending_cols` write loop Spike 11
measured. **For the v0.1.8.9 spec packet, the lead durable write lane
is Spike 11's setv fix, not Spike 4's chunked write.**

## Wall translation

Reference workload: `density_high_xlarge_durable` runs in 445.02s wall,
with the durable path active throughout. Spike 11 measures 169.08s
cumulative cost for 130k events isolated. Production fill count is
133,070.

Linear scaling to 133k: ~173s isolated. Standard v0.1.8.7 spike
discipline assumes isolated micro-benchmarks overestimate production
by ~3x (synthetic payload, idealized cache, no surrounding fold
machinery). So realistic production cost from this mechanism: ~57s.

With setv recovering essentially all of that cost (1.78s cumulative on
130k events), expected production recovery on the xlarge cell is in
the range **50-80s of wall**, depending on the actual overestimate
factor.

Amdahl bound on `density_high_xlarge_durable` (445s wall):

- If buffer-write cost is 60s of 445s wall: p = 0.135, setv at 140x
  gives max wall speedup = 1.16x (~60s of 445s wall recovered).
- If buffer-write cost is 80s of 445s wall: p = 0.180, setv gives
  max wall speedup = 1.22x (~80s of 445s wall recovered).

**This is a credible 50-80s wall recovery on the durable xlarge cell**,
matching Codex's expectation that "Spike 4's 75s claim" be replaced by
a faithful production-path measurement.

## Caveats

- **The handler replica is faithful but isolated.** Production
  `ledgr_persistent_output_handler` is invoked from the fold engine
  through `buffer_event(write_res)` which unpacks `write_res$row`
  before the column writes. The spike skips that unpacking but uses
  the same column-write pattern. Real-run gate is the LDG-2479 grid
  xlarge cell re-run after the production handler is patched.
- **Spike 6's findings remain valid for the ephemeral path.** Memory
  output handler has the list-column residual; setv gives 6.45x
  there. Persistent durable handler has no list column; setv gives
  140x. Two different handlers, two different magnitudes, same
  underlying mechanism.
- **The flush phase is NOT measured by this spike.** The persistent
  handler's `flush_pending` (not shown in the timed loop) calls
  `DBI::dbAppendTable` on the accumulated columns. That flush cost
  is bounded by Spike 4's batched results
  (`batched_100`: 2.49s at 68k fills) and is small relative to the
  buffer-write cost recovered here. The flush is not a v0.1.8.9 lane.
- **setv requires collapse to be loaded.** collapse is already in
  ledgr Imports (ADR 0004), so no new dependency. setv is
  value-neutral, so no `ledgr_with_collapse_deterministic()` wrapper
  is needed per the optimization map.

## Recommendation

**Proceed to v0.1.8.9 implementation ticket. This is the LEAD durable
write lane for the v0.1.8.9 round, REPLACING Spike 4's (LDG-2483)
position.**

Implementation sketch — replace the 11 column writes at
`R/backtest-runner.R:425-435`:

```r
collapse::setv(state$pending_cols$event_id, i, write_res$row$event_id, vind1 = TRUE)
collapse::setv(state$pending_cols$run_id, i, write_res$row$run_id, vind1 = TRUE)
collapse::setv(state$pending_cols$ts_utc, i, write_res$row$ts_utc, vind1 = TRUE)
collapse::setv(state$pending_cols$event_type, i, write_res$row$event_type, vind1 = TRUE)
collapse::setv(state$pending_cols$instrument_id, i, write_res$row$instrument_id, vind1 = TRUE)
collapse::setv(state$pending_cols$side, i, write_res$row$side, vind1 = TRUE)
collapse::setv(state$pending_cols$qty, i, as.numeric(write_res$row$qty), vind1 = TRUE)
collapse::setv(state$pending_cols$price, i, as.numeric(write_res$row$price), vind1 = TRUE)
collapse::setv(state$pending_cols$fee, i, as.numeric(write_res$row$fee), vind1 = TRUE)
collapse::setv(state$pending_cols$meta_json, i, write_res$row$meta_json, vind1 = TRUE)
collapse::setv(state$pending_cols$event_seq, i, as.integer(write_res$row$event_seq), vind1 = TRUE)
```

Sequencing in v0.1.8.9: this lane is independent of Spikes 1, 2, 6, 7.
Recommend landing FIRST among the write-side fixes because:

1. Largest measured durable-path recovery (50-80s vs Spike 7's now-uncertain
   estimate, Spike 6's ephemeral-only ~75s).
2. Smallest blast radius (11-line mechanical replacement).
3. Faithfulness gate is clean — Spike 11 directly measures the
   production handler structure with byte-identical column parity.

Expected real-run signature: `t_loop_sec` on
`density_high_xlarge_durable` drops by 50-80s. `mus_per_fill_engine`
drops proportionally. Sweep regression tests byte-identical (the
fix is in the durable output handler, not in any user-visible
contract surface).

## Architectural lesson

This spike validates the v0.1.8.9 round's coding rule for the FOURTH
time in different surfaces:

1. v0.1.8.7 B0 event buffer (`R/fold-event-buffer.R`).
2. Spike 6 (LDG-2485): memory output handler
   (`R/sweep.R:1016-1029`).
3. Spike 7 (LDG-2486): fills reconstruction buffer
   (`R/fold-reconstruction.R:219-227`).
4. **Spike 11 (LDG-2490): persistent durable handler
   (`R/backtest-runner.R:425-435`).**

The coding rule stands: **per-row writes into preallocated column
buffers must use `collapse::setv`, not base-R `[[<-`**, with the
scale caveat (apply to growing buffers; leave fixed-small vectors
alone).

The new architectural sub-lesson from this spike: **`collapse::setv`
delivers true O(N) total work when all buffer columns are atomic.**
When a buffer mixes atomic and list/expression columns, setv's win
is bounded by the slowest writable column. Future buffer designs
should prefer atomic columns where the data permits (e.g., serialize
list metadata to canonical_json once and store the character vector
rather than a list column).

This sub-lesson explains the 140x vs 6.45x gap between Spike 11 and
Spike 6 cleanly. Same mechanism, different column shapes, predictably
different magnitudes. The synthesis L2 / L3 should incorporate this
nuance when revised under LDG-2492.
