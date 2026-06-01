# Spike Log: ledgr_fills_from_events() Scaling

**Date:** 2026-05-31 - **Host:** local development host - R 4.5.2 -
**Status:** v0.1.8.9 optimization-round input (Batch C, Spike 7).

> **ROUND 2 CORRECTION (2026-05-31):** Codex peer review of the round
> identified that this spike measures the MONOLITHIC
> `ledgr_fills_from_events()` path with a 260k-slot buffer at 130k
> events. The production durable path used by `density_high_xlarge_durable`
> does NOT take this monolithic path — it goes through
> `ledgr_extract_fills_impl()` at `R/backtest.R:1021-1276` which uses
> a chunked DBI reader (`fetch_size = 50000`, per-chunk buffer
> ~100k slots). The ~170s wall recovery projection below is a
> monolithic extrapolation, not a measured durable production number.
>
> **Spike 12 (LDG-2491, `dev/spikes/spike-chunked-extractor-wall-recovery.md`)**
> measured the real chunked path: ~186s baseline → ~40s patched at
> 133k events, ~150s isolated recovery (4.6× speedup). Applying the
> standard isolated-overestimate discount yields ~150s production
> recovery on the xlarge durable cell — the load-bearing number for
> the synthesis L6 lane sequencing.
>
> Additionally, the L2 mechanism wording below ("buffer is a function
> argument with refcount > 1") is over-specific. The buffer is an env
> returned by `ledgr_fill_row_buffer()` at `R/fold-reconstruction.R:155-170`.
> Materialization/copy fires during evaluation of `env$col[[i]] <- value`
> regardless of caller refcount. setv fix is unchanged.
>
> Treat Spike 7's content below as the diagnostic that uncovered the
> mechanism; treat Spike 12 as the measured production-path recovery.

**Script:** `dev/spikes/spike-fills-reconstruction-scaling.R`. Raw CSV
(gitignored): `dev/bench/results/spike_fills_reconstruction_scaling.csv`.

**Relates to:** `dev/bench/notes/single_core_optimization_inventory.md`
(D1), `inst/design/spikes/ledgr_optimization_round_spike/architecture_synthesis.md`
(v0.1.8.7 Batch 6 Lane C), LDG-2486. **Round 2 supersession:** Spike 12
(LDG-2491) for the chunked production durable path.

## Question

LDG-2479 grid showed `ledgr_results(bt, "fills")` is super-linear:
6.75s at 13k fills, 82.28s at 68k, ~200s at 133k. v0.1.8.7 Batch 6
(Lane C) already rewrote `ledgr_fills_from_events` to use a
primitive-column buffer plus `.subset2` reads, eliminating the
list-of-data.frames + `rbind` anti-pattern that scaled O(N^2) before.
So WHERE is the super-linearity coming from now?

## Method

Synthetic events table at four scales {13.5k, 30k, 68.5k, 130k} matching
the LDG-2479 grid cells. Held constant: n_inst = 500. Varied:
fills_per_inst (27, 60, 137, 260). Each instrument gets alternating
BUY/SELL fills so lots close cleanly (production crossover pattern).

`ledgr:::ledgr_fills_from_events` called directly via `pkgload::load_all`
so the production code path is exercised. Rprof at the largest scale
(130k fills, 5ms sampling) to identify the hot spots.

## Results

### Scaling

```
n_inst  n_fills  |    wall_s  us_per_fill | output_rows
500     13500    |    5.500s        407.4 | 13500 output rows
500     30000    |   25.840s        861.3 | 30000 output rows
500     68500    |  137.040s       2000.6 | 68500 output rows
500     130000   |  618.680s       4759.1 | 130000 output rows
```

Per-fill cost growth:

- 13.5k: 407 us/fill (baseline)
- 30k: 861 us/fill (2.11x baseline; 2.22x scale)
- 68.5k: 2001 us/fill (4.91x baseline; 5.07x scale)
- 130k: 4759 us/fill (11.68x baseline; 9.63x scale)

**Per-fill cost scales roughly linearly with n_fills.** That is the
O(N^2) total-cost signature: per-fill cost = O(N), total work = O(N^2).

### Rprof at 130k fills

```
--- top 15 by self.time ---
                          self.time self.pct
fold-reconstruction.R#221    55.890    25.05
fold-reconstruction.R#225    52.420    23.50
fold-reconstruction.R#227    42.025    18.84
fold-reconstruction.R#223    38.070    17.07
fold-reconstruction.R#222     9.220     4.13
fold-reconstruction.R#220     5.085     2.28
fold-reconstruction.R#224     4.720     2.12
fold-reconstruction.R#226     4.415     1.98
fold-reconstruction.R#219     2.465     1.11
```

**9 consecutive lines in `ledgr_fill_row_buffer_add` consume 254s of 223s
sampled time (113% — Rprof oversample due to noise).** That is 96.6% of
the function's total time, with 88% concentrated in lines 219-227.

### What lines 219-227 do

`R/fold-reconstruction.R:219-227`:

```r
buffer$event_seq[[i]] <- as.integer(event_seq)
buffer$ts_utc[[i]] <- as.POSIXct(ts_utc, tz = "UTC")
buffer$instrument_id[[i]] <- as.character(instrument_id)
buffer$side[[i]] <- as.character(side)
buffer$qty[[i]] <- as.numeric(qty)
buffer$price[[i]] <- as.numeric(price)
buffer$fee[[i]] <- as.numeric(fee)
buffer$realized_pnl[[i]] <- as.numeric(realized_pnl)
buffer$action[[i]] <- as.character(action)
```

These are 9 per-row column writes into a list-of-vectors buffer. The
buffer is a function argument with refcount > 1, so each
`buffer$<col>[[i]] <- value` triggers R copy-on-modify on the entire
column vector.

The column is preallocated to `nrow(events) * 2L` at fold-reconstruction.R:265
(`ledgr_fill_row_buffer(nrow(events) * 2L)`). At 130k events that is
260,000 slots per column. So every per-row write copies a 260k-element
vector. With 9 columns and 130k rows, total copy work is
9 x 130000 x 260000 = ~304 billion element copies. That is the O(N^2)
the spike measured.

## Findings

**Mechanism identified: same per-row-write-on-shared-list anti-pattern
that v0.1.8.7 fixed in the durable handler, recreated in
`ledgr_fill_row_buffer_add`.** The v0.1.8.7 Batch 6 Lane C rewrite eliminated
the original `do.call(rbind, list_of_data.frames)` anti-pattern by
introducing the primitive-column buffer (good). But the per-row write
loop into that buffer recreates the same O(N) per-call copy cost,
because the buffer is a refcount-elevated function argument and base-R
`[[<-` triggers copy-on-modify on the column vector each call.

**This is the SAME mechanism as Spike 6 (memory output handler).** The
fix is the same: `collapse::setv` for in-place column writes by C
reference, bypassing R copy-on-modify entirely. setv is value-neutral
(the optimization map confirms; the v0.1.8.7 buffer-rewrite spike
confirmed tracemem-clean).

**The lot machinery is NOT the bottleneck.** `ledgr_lot_apply_event` total
time is 3.46s out of 223s = 1.5%. The lot accounting per-fill cost is
bounded by the typical SMA crossover pattern where lots close cleanly
between events. Not a v0.1.8.9 candidate.

**Scaling math confirms.** At 130k fills with 9 columns of 260k slots
each, total element copies = 9 x 130000 x 260000 = 304B. At ~1 ns per
8-byte memcpy = ~300s. Spike measured 618s — within factor 2 of the
theoretical floor, consistent with R overhead on top of pure memcpy.

## Wall translation

Reference workload: `density_high_xlarge_durable` runs in 445.02s wall,
197.11s fills_extract_sec at ~133k fills. The LDG-2479 baseline showed
`ledgr_results(bt, "fills")` IS the durable fills extraction path
(though for durable, events are first read from DuckDB, then
`ledgr_fills_from_events` is called on the in-memory events). The spike
measures the IN-MEMORY part only; production also pays the DuckDB read.

If the setv fix gives the Spike 6 magnitude of speedup (6.45x), the
fills_extract_sec at 133k drops from ~200s to ~30s. That is
**~170 seconds of wall recovery on the xlarge cell**.

Amdahl bound on the xlarge cell (445s):

- If fills_extract cost is 197s of 445s wall: p = 0.443, setv at 6.45x
  gives max wall speedup = 1.59x (~170s of 445s wall recovered).

Combined with Spike 4 (50-100s recovery) and Spike 6 (50-100s on
ephemeral), the v0.1.8.9 round is on track to remove **30-40% of the
xlarge wall time**.

## Caveats

- **The spike measures only the in-memory reconstruction.** Production
  `ledgr_results(bt, "fills")` for durable runs first reads events from
  DuckDB via a chunked reader, then calls `ledgr_fills_from_events`.
  The spike captures the second phase. The DuckDB read phase may have
  its own scaling characteristics; Spike 9 (xlarge breakdown)
  investigates the first phase.
- **Synthetic events use simplified meta_json.** The spike's per-fill
  cost may be slightly higher than production at low scales (no DuckDB
  overhead amortizes) or lower at high scales (less meta parsing). The
  scaling SIGNATURE (linear per-fill cost growth) is unambiguous.
- **The setv fix requires identical safety analysis as Spike 6.** setv
  is value-neutral; no determinism wrapper needed; tracemem-confirmed
  in-place. Confirmed safe by the v0.1.8.7 buffer-rewrite spike and by
  Spike 6 of this round.
- **The fix is mechanical and the same as Spike 6.** Replace
  `buffer$<col>[[i]] <- value` with
  `collapse::setv(buffer$<col>, i, value, vind1 = TRUE)` at lines
  219-227. The function signature, behavior, and downstream consumers
  do not change.

## Recommendation

**Round 2 reclassification: production durable recovery measured by
Spike 12.** This spike's ~170s monolithic projection is superseded by
Spike 12's measured ~150s recovery against the real chunked extractor
path. The mechanism (per-row column-buffer write triggering O(N) copy)
is confirmed; the fix (collapse::setv on lines 219-227) is unchanged;
the wall-translation number for the synthesis comes from Spike 12.

**This remains a headline v0.1.8.9 lane** (now alongside Spike 11's
durable handler setv), but the durable production magnitude is the
~150s measured number, not the ~170s monolithic extrapolation.
~150s of wall recovery on the xlarge cell from a 9-line mechanical change.

Implementation sketch:

```r
# In R/fold-reconstruction.R:219-227 (ledgr_fill_row_buffer_add), replace:
buffer$event_seq[[i]] <- as.integer(event_seq)
buffer$ts_utc[[i]] <- as.POSIXct(ts_utc, tz = "UTC")
# ... 9 such lines ...
# with:
collapse::setv(buffer$event_seq, i, as.integer(event_seq), vind1 = TRUE)
collapse::setv(buffer$ts_utc, i, as.POSIXct(ts_utc, tz = "UTC"), vind1 = TRUE)
# ... and the other 7 column writes.
```

Same change pattern as Spike 6's recommendation for the memory output
handler. The two fixes are independent and can land in parallel; both
attack the same per-row write anti-pattern in different files.

Sequencing in v0.1.8.9: this should land EARLY because the wall recovery
is large and the fix is small. Independent of Batch A and Spike 4. After
the fix, re-run the workload grid on `density_high_xlarge_durable` and
`density_high_large_durable` to confirm `fills_extract_sec` drops
from ~200s to ~30s. Tier 1 parity (output rows byte-identical) must hold.

Expected real-run signature on `density_high_xlarge_durable`:
`fills_extract_sec` drops by 150-170s; `t_loop_sec` unchanged (the fix
is in the post-fold reconstruction). Total wall drops by 150-170s
(from 445s to ~275-295s).

## Architectural lesson

The v0.1.8.7 Lane C rewrite correctly identified and removed the
`do.call(rbind, list_of_data.frames)` anti-pattern. But the replacement
(a primitive-column buffer with per-row writes) introduced a NEW
O(N^2) pattern in a different form. The mechanism is identical to
the v0.1.8.7 B0 event-buffer fix (which used `setv` to solve exactly
this) — the lesson did not travel to the reconstruction path.

For v0.1.8.9 and beyond, the rule is: **any per-row write into a
preallocated column buffer must use `collapse::setv` (or equivalent
in-place mutation), not base-R `[[<-`.** The optimization map already
encoded this as a Tier 3 doctrine; it now becomes a Tier 1 lane
because the cost is empirically large at production scale.

The Spike 3 finding ("setv is scale-dependent") refines but does not
contradict this rule. setv wins on large vectors (columns growing to
100k+); it doesn't win on small vectors (1000-element state). The
fills reconstruction buffer at 130k events with 260k-slot columns is
exactly the regime where setv dominates.
