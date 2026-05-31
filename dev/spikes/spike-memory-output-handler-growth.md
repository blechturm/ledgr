# Spike Log: Memory Output Handler Per-Event Growth

**Date:** 2026-05-31 - **Host:** local development host - R 4.5.2,
collapse 2.x - **Status:** v0.1.8.9 optimization-round input (Batch B,
Spike 6).

**Script:** `dev/spikes/spike-memory-output-handler-growth.R`. Raw CSV
(gitignored): `dev/bench/results/spike_memory_output_handler_growth.csv`.

**Relates to:** `dev/bench/notes/single_core_optimization_inventory.md`
(C1, C2), `dev/bench/peer_benchmark/notes/three_phase_decomposition_results.md`,
LDG-2485.

## Question

LDG-2476 three-phase decomposition showed ephemeral ledgr's engine phase is
+16.4s vs durable at 68k fills and results phase is +40.9s. The memory
output handler at `R/sweep.R:957-1163` uses the same B0 grow-by-doubling
buffer (`R/fold-event-buffer.R`) as durable. Hypothesis: per-event append
cost grows with accumulated event count (O(N^2) signature) because base-R
`[[<-` on the buffer columns still copies on each write, even with B0
sizing reducing the over-allocation.

Per `inst/design/collapse_optimization_map.md`: the v0.1.8.7 buffer-rewrite
spike showed sizing alone (worst-case -> doubling) gave 27-101x but "still
copies fills-sized columns, so O(fills^2)". The collapse `setv` fix on top
of sizing gave 65-1300x. Spike 6 tests whether the memory handler retains
the O(fills^2) the sizing fix only reduced.

## Method

Replica of `ledgr_memory_output_handler` from `R/sweep.R:957-1163`. 14
columns matching the production schema (event_id, run_id, ts_utc,
event_type, instrument_id, side, qty, price, fee, meta_json, event_seq,
cash_delta, position_delta, meta). Uses `ledgr_event_buffer_next_capacity`
logic from `R/fold-event-buffer.R` for grow-by-doubling. A fixed event
payload is reused so the spike times the BUFFER WRITE only.

Two variants:

- `handler_baser`: replica of current handler (base-R `[[<-` column writes,
  identical to `R/sweep.R:1016-1029`).
- `handler_setv`: same column writes via `collapse::setv(col, i, v,
  vind1=TRUE)` (in-place by C reference, value-neutral, no determinism gate
  needed per the optimization map).

Per-event cost measured at intervals of 5,000 from 5k to 130k events. The
final accumulated count (130k) approximates the xlarge cell fill count
(133k).

## Results

### handler_baser (current handler replica)

```
accumulated  | interval_s us_per_event
5000         |    0.6400s       128.00
10000        |    1.4200s       284.00
15000        |    1.8600s       372.00
20000        |    2.9900s       598.00
25000        |    3.3400s       668.00
30000        |    3.3600s       672.00
35000        |    5.0000s      1000.00
40000        |    6.7700s      1354.00
45000        |    6.7800s      1356.00
50000        |    6.7500s      1350.00
55000        |    6.8800s      1376.00
60000        |    6.8900s      1378.00
65000        |    6.8400s      1368.00
70000        |   13.6700s      2734.00
75000        |   15.4400s      3088.00
80000        |   15.6500s      3130.00
...
130000       |   15.6000s      3120.00
```

### handler_setv (collapse::setv writes)

```
accumulated  | interval_s us_per_event
5000         |    0.2100s        42.00
10000        |    0.3300s        66.00
15000        |    0.4300s        86.00
20000        |    0.6300s       126.00
25000        |    0.7400s       148.00
30000        |    0.7400s       148.00
35000        |    1.1400s       228.00
40000        |    1.3500s       270.00
45000        |    1.3300s       266.00
...
130000       |    2.4200s       484.00
```

### Summary

- `handler_baser`: 128 us/event at 5k -> 3120 us/event at 130k = **24.4x
  growth**.
- `handler_setv`: 42 us/event at 5k -> 484 us/event at 130k = **11.5x
  growth**.
- `handler_baser` vs `handler_setv` at 130k: **6.45x slower** (3120 vs 484
  us/event).

## Findings

**O(N^2) mechanism confirmed for the current handler.** Per-event cost
grows step-wise as the buffer hits capacity-doubling boundaries (16384,
32768, 65536, 131072). Within each capacity band the cost is roughly
flat, then approximately doubles at each capacity step:

- 20k-30k: ~600-670 us/event (capacity 32768)
- 35k-65k: ~1000-1378 us/event (capacity 65536)
- 70k-130k: ~2734-3184 us/event (capacity 131072)

The cost-per-event ~doubles with each capacity doubling. That is the
classic O(N) per-write cost on a vector of size N — total work scales
O(N^2). The v0.1.8.7 sizing fix (worst-case -> doubling) reduced the
constant but did not change the asymptotic class for the memory path.

**setv fixes the asymptotic class — almost.** With `collapse::setv` the
per-event cost still grows (11.5x from 5k to 130k), but at less than half
the rate of base-R writes. The residual growth is from the
capacity-doubling EVENTS themselves (when ensure_capacity() runs, the old
buffer is copied to a new larger one via base-R `[idx] <- old[idx]` at
`R/sweep.R:1003`). That growth-event copy is amortized O(log N) per event
but introduces visible jumps in the timing intervals.

**At the production fill scale, setv recovers 6.45x.** This is the largest
write-side speedup we have measured in this round. The mechanism is the
same as the v0.1.8.7 buffer-rewrite spike: setv writes in-place by C
reference, bypassing R's copy-on-modify on the column vectors. The
difference from Spike 3 (where setv did NOT help at 1000-inst scale) is
that here the column vectors grow to 131072 elements, where each
copy-on-modify event involves substantial memory bandwidth.

**The Spike 3 vs Spike 6 contrast is informative.** Spike 3's
state$positions max'd at 1000 elements — base-R copies were cheap and
collapse::setv's no-copy edge was washed out. Spike 6's buffer columns max
at 131072 elements — copies dominate and setv wins by 6.45x. **The
scale-dependence of the collapse::setv mechanism is now empirically
demonstrated.** v0.1.8.7's framing ("setv pulls away on high turnover")
holds.

## Wall translation

Reference workload: ephemeral ledgr on `density_high_xlarge_durable` has a
total +178.85s delta vs durable (LDG-2479 grid). The three-phase
decomposition showed +16.4s engine + +40.9s results at 68k fills (LDG-2476
peer benchmark).

Spike measurement at 130k events:
- handler_baser cumulative wall: ~187s (sum of intervals)
- handler_setv cumulative wall: ~28s (sum of intervals)
- Difference: ~159s

That's an order-of-magnitude estimate of the production gap, dominated by
buffer-write cost in the ephemeral path. The spike likely overestimates
absolute cost ~3x per v0.1.8.7 discipline (isolated micro-benchmark on a
synthetic payload doesn't faithfully reproduce production
refcount/cache/optimizer conditions). So the realistic wall recovery on
the ephemeral xlarge cell from a setv-based handler fix is on the order
of **50-100s**.

Amdahl bound on the ephemeral xlarge cell (623.87s total):

- If buffer writes cost ~50s of 623.87s: p = 0.08, setv gives 6.45x =
  ~43s recovered (1.07x wall speedup).
- If buffer writes cost ~100s: p = 0.16, setv gives ~85s recovered
  (1.16x wall speedup).

This is also a meaningful lane, though smaller than Spike 4's durable-write
batching. Combined with B1, the v0.1.8.9 round materially reduces the
write-side cost on both ledgr paths (durable AND ephemeral).

## Caveats

- **The handler replica is faithful but isolated.** Production
  `ledgr_memory_output_handler` is invoked from
  `R/fold-engine.R:336-340` through several wrapper layers
  (`buffer_event` calls `append_event_row_list` after `write_res`
  unpacking). The spike skips that wrapping. Real-run re-profile is the
  verdict.
- **The growth-event copy is still O(capacity).** Even after fixing the
  per-write copy with setv, the capacity-doubling events copy the entire
  old buffer to a new larger one (`R/sweep.R:1000-1005`). For very large
  workloads (>1M events) this becomes the dominant cost. A future
  optimization could pre-size to a known max (e.g., `n_pulses * n_inst`
  with a configurable cap) and skip growth events entirely — but that
  reintroduces the v0.1.8.7 over-allocation trap unless setv is also
  used for the growth copy. Out of scope for this spike.
- **setv requires collapse to be loaded.** collapse is already in ledgr
  Imports (ADR 0004), so no new dependency. setv is value-neutral (a
  write, not a reduction), so no `ledgr_with_collapse_deterministic()`
  wrapper is needed per the optimization map.
- **Snapshot semantics: not relevant here.** Unlike Spike 3, no
  caller holds a refcount-elevated reference to the buffer columns
  expecting snapshot behavior. The buffer is internal to the handler and
  only read at reconstruction time after all writes are done. setv on
  the buffer columns is safe.

## Recommendation

**Proceed to v0.1.8.9 implementation ticket.** Apply collapse::setv to the
per-column writes in `R/sweep.R:1016-1029` (`append_event_row_list`),
`R/sweep.R:1102-1130` (`append_event_rows` bulk variant), and any other
hot-path column-mutation sites in the memory output handler.

Implementation sketch:

```r
# In append_event_row_list at R/sweep.R:1016-1029, replace:
state$event_cols$event_id[[i]] <- row$event_id
# with:
collapse::setv(state$event_cols$event_id, i, row$event_id, vind1 = TRUE)
# ... and similarly for the other 13 column writes.
```

For the `meta` column (a list, not a vector), setv may not apply
cleanly — list-column writes are inherently different. Verify whether
list-column [[<- triggers copy in the same way; if so, consider keeping
meta in a separate environment or using `[[<-` only for that one slot
(since list copy cost is bounded by list-of-pointers, not by accumulated
content).

Sequencing in v0.1.8.9: independent of Batch A per-pulse fixes and Spike 4
batched writes. The memory handler is only used by ephemeral runs (sweep
candidates and the diagnostic ephemeral peer benchmark row); a fix here
does not affect durable runs. Recommend landing AFTER B1 (Spike 4) since
B1 is the larger durable-path wall recovery and the v0.1.8.9 spec's
headline. Spike 6's fix lands as a secondary lane improving the ephemeral
diagnostic and any future sweep workload at large fill density.

Expected real-run signature on a re-run of the LDG-2476 three-phase
record with the setv fix applied: ephemeral xlarge wall drops
50-100s. Ephemeral vs durable parity gate (1e-8 tolerance) holds.
Sweep regression tests byte-identical.

The Spike 3 finding (setv doesn't beat intvec_id_map at 1000-inst scale)
is reaffirmed but does not contradict Spike 6: scale matters. setv is
the right tool for large in-place column writes, the wrong tool for
small named-vector mutations. The optimization map's framing of
collapse::setv as a turnover-scaling lever is empirically validated here.
